import { mkdir, readFile, readdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const output = path.join(root, 'build', 'image-url-audit.json');
async function walkSqlFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...await walkSqlFiles(fullPath));
    else if (entry.isFile() && entry.name.endsWith('.sql')) files.push(fullPath);
  }
  return files;
}

const candidates = new Map();
function add(url, source) {
  const value = url.trim().replace(/[),;]+$/, '');
  if (!value) return;
  const sources = candidates.get(value) ?? new Set();
  sources.add(source);
  candidates.set(value, sources);
}

function isImageUrl(url) {
  const pathname = new URL(url).pathname.toLowerCase();
  return /\.(apng|avif|gif|jpe?g|png|webp)$/.test(pathname) ||
    pathname.includes('/storage/v1/object/');
}

const seedFiles = [
  path.join(root, 'lib', 'data', 'mock_data.dart'),
  path.join(root, 'lib', 'data', 'models', 'map_seed.dart'),
];
for (const file of seedFiles) {
  const content = await readFile(file, 'utf8');
  for (const match of content.matchAll(/https?:\/\/[^\s'"]+/g)) {
    if (isImageUrl(match[0])) add(match[0], path.relative(root, file));
  }
}

const migrationFiles = await walkSqlFiles(
  path.join(root, 'supabase', 'migrations'),
);
migrationFiles.sort();
const latestMigration = path.relative(root, migrationFiles.at(-1));
for (const file of migrationFiles) {
  const content = await readFile(file, 'utf8');
  for (const match of content.matchAll(/https?:\/\/[^\s'"]+/g)) {
    if (isImageUrl(match[0])) add(match[0], path.relative(root, file));
  }
}

const config = await readFile(
  path.join(root, 'lib', 'core', 'config', 'app_config.dart'),
  'utf8',
);
const supabaseUrl = config.match(/supabaseUrl\s*=\s*'([^']+)'/)?.[1];
const anonKey = config.match(/supabaseAnonKey\s*=\s*'([^']+)'/)?.[1];
if (!supabaseUrl || !anonKey || anonKey.length < 40) {
  throw new Error('Could not read the public Supabase API configuration.');
}
const headers = { apikey: anonKey, Authorization: `Bearer ${anonKey}` };
const [placesResponse, toursResponse] = await Promise.all([
  fetch(
    `${supabaseUrl}/rest/v1/places?select=id,name_en,name,image_url,image_urls&limit=1000`,
    { headers, signal: AbortSignal.timeout(30000) },
  ),
  fetch(
    `${supabaseUrl}/rest/v1/tours?select=id,title,image_url&limit=1000`,
    { headers, signal: AbortSignal.timeout(30000) },
  ),
]);
if (!placesResponse.ok || !toursResponse.ok) {
  throw new Error(
    `Supabase REST image query failed: places=${placesResponse.status}, tours=${toursResponse.status}`,
  );
}
const liveRows = [
  ...(await placesResponse.json()).map((row) => ({
    ...row,
    kind: 'place',
    name: row.name_en || row.name,
  })),
  ...(await toursResponse.json()).map((row) => ({
    ...row,
    kind: 'tour',
    name: row.title,
    image_urls: [],
  })),
];
const missingImageRows = liveRows
  .filter((row) => ![row.image_url, ...(row.image_urls ?? [])]
    .some((url) => typeof url === 'string' && url.trim() !== ''));
for (const row of liveRows) {
  for (const url of [row.image_url, ...(row.image_urls ?? [])]) {
    if (url) add(url, `supabase:${row.kind}:${row.id}:${row.name}`);
  }
}

async function checkUrl(url) {
  let response;
  let error;
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      response = await fetch(url, {
        method: 'HEAD',
        redirect: 'follow',
        signal: AbortSignal.timeout(15000),
        headers: {
          'User-Agent':
            'Streetlore/2.1 (https://github.com/mohamedsabae50-prog/streetlore; contact: support@streetlore.app)',
        },
      });
      if (response.status === 405 || response.status === 403) {
        response = await fetch(url, {
          method: 'GET',
          redirect: 'follow',
          signal: AbortSignal.timeout(15000),
          headers: {
            Range: 'bytes=0-0',
            'User-Agent':
              'Streetlore/2.1 (https://github.com/mohamedsabae50-prog/streetlore; contact: support@streetlore.app)',
          },
        });
      }
      if (response.status !== 429 && response.status < 500) break;
      error = `HTTP ${response.status}`;
    } catch (caught) {
      error = String(caught);
    }
    await delay(1000 * (attempt + 1));
  }
  return {
    url,
    status: response?.status ?? null,
    contentType: response?.headers.get('content-type') ?? null,
    ok: Boolean(response?.ok) &&
      (response.headers.get('content-type') ?? '').toLowerCase().startsWith('image/'),
    error: error ?? null,
    sources: [...candidates.get(url)],
  };
}

const urls = [...candidates.keys()];
const results = [];
for (let offset = 0; offset < urls.length; offset++) {
  results.push(await checkUrl(urls[offset]));
  if ((offset + 1) % 20 === 0) {
    console.log(`Checked ${offset + 1}/${urls.length} image URLs`);
  }
  await delay(150);
}

const failedChecks = results.filter((result) => !result.ok);
const broken = failedChecks.filter((result) =>
  result.sources.some((source) =>
    source.startsWith('lib' + path.sep) ||
    source.startsWith('supabase:') ||
    source === latestMigration,
  ),
);
const historicalFailures = failedChecks.filter(
  (result) => !broken.includes(result),
);

await mkdir(path.dirname(output), { recursive: true });
await writeFile(output, `${JSON.stringify({
  checkedAt: new Date().toISOString(),
  livePlaceAndTourRows: liveRows.length,
  liveRowsMissingImages: missingImageRows,
  uniqueImageUrls: results.length,
  broken,
  historicalFailures,
  results,
}, null, 2)}\n`);
console.log(`Checked ${results.length} URLs from ${liveRows.length} live rows.`);
console.log(`Live rows without any image: ${missingImageRows.length}.`);
console.log(
  `Broken active image URLs: ${broken.length}; ` +
  `historical migration references: ${historicalFailures.length}. ` +
  `Report: ${output}`,
);
for (const result of broken) {
  console.log(`${result.status ?? result.error ?? 'invalid'} ${result.url}`);
  for (const source of result.sources) console.log(`  ${source}`);
}
for (const result of historicalFailures) {
  console.log(
    `Historical migration URL is no longer active: ${result.status ?? result.error} ${result.url}`,
  );
}
if (broken.length > 0) process.exitCode = 1;
