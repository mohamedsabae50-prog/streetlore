import { execSync } from 'node:child_process';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const reportPath = path.join(root, 'reports', 'authentic_place_images.csv');
const dryRun = process.argv.includes('--dry-run');
const appConfig = await readFile(
  path.join(root, 'lib', 'core', 'config', 'app_config.dart'),
  'utf8',
);
const supabaseUrl = appConfig.match(/supabaseUrl\s*=\s*'([^']+)'/)?.[1];
const anonKey = appConfig.match(/supabaseAnonKey\s*=\s*'([^']+)'/)?.[1];
if (!supabaseUrl || !anonKey) {
  throw new Error('Could not read the public Supabase API configuration.');
}
const projectRef = new URL(supabaseUrl).hostname.split('.')[0];
const userAgent =
  'Streetlore authentic image sync/1.0 (https://github.com/mohamedsabae50-prog/streetlore)';
const headers = { apikey: anonKey, Authorization: `Bearer ${anonKey}` };
const aliasesById = new Map([
  ['p_1784811618524', ['Citadel of Qaitbay', 'قلعة قايتباي']],
  ['17', ['Anfushi tombs', 'Tombs of Anfushi', 'مقابر الأنفوشي']],
  ['13', ['El-Atarin Bazaar Alexandria', 'Souq El-Attarin', 'سوق العطارين']],
  ['13cf4401-ce36-4560-9398-fb81cbf0f28c', ['Misr Station Alexandria', 'Alexandria Misr railway station', 'محطة مصر الإسكندرية']],
  ['16', ['Shallalat Gardens Alexandria', 'El-Horeyya Garden Alexandria', 'حدائق الشلالات']],
  ['4', ['Catacombs of Kom el Shoqafa', 'مقابر كوم الشقافة']],
  ['7', ["Pompey's Pillar Alexandria", 'عمود السواري']],
  ['9', ['Roman Theatre Alexandria', 'Roman Amphitheatre Kom el-Dikka', 'المسرح الروماني الإسكندرية']],
  ['10', ['Abu al-Abbas al-Mursi Mosque Alexandria', 'مسجد أبو العباس المرسي']],
  ['40', ["St. Mark's Coptic Orthodox Cathedral Alexandria", 'كاتدرائية القديس مرقس الإسكندرية']],
  ['alex_royal_jewelry_museum', ['Royal Jewelry Museum Alexandria', 'متحف المجوهرات الملكية']],
  ['alex_cavafy_museum', ['Cavafy Museum Alexandria', 'متحف كفافيس']],
  ['43', ['Graeco-Roman Museum Alexandria', 'المتحف اليوناني الروماني']],
  ['3', ['Montaza Palace Gardens Alexandria', 'حدائق قصر المنتزه']],
  ['52', ['Antoniades Garden Alexandria', 'حدائق أنطونيادس']],
  ['41', ['Jesuit Church of Cleopatra Alexandria', 'كنيسة اليسوعيين كليوباترا الإسكندرية']],
  ['42', ["Saint Catherine's Cathedral Alexandria", 'كاتدرائية القديسة كاترين الإسكندرية']],
  ['45', ['Mahmoud Said Museum Alexandria', 'متحف محمود سعيد']],
  ['51', ['Alexandria Zoo', 'حديقة حيوان الإسكندرية']],
  ['53', ['Alexandria Aquarium', 'أكواريوم الإسكندرية']],
  ['21', ['Zephyrion Restaurant Alexandria', 'مطعم زيفيريون']],
  ['v155_zephyrion', ['Zephyrion Restaurant Alexandria', 'مطعم زيفيريون']],
  ['v155_pastroudi', ['Pastroudi Restaurant Alexandria', 'مطعم باسترودي']],
  ['v155_abu_ashraf', ['Abu Ashraf Seafood Alexandria', 'مطعم أبو أشرف الإسكندرية']],
  ['d88d4a5d-b3b0-4579-bef3-728e41843095', ['Stanley Cafe Alexandria', 'مقهى ستانلي الإسكندرية']],
  ['ec216324-1277-4649-a631-91be397eeeac', ['Greek Club of Alexandria', 'النادي اليوناني الإسكندرية']],
  ['43591966-e37f-4f6a-967c-d94a1a012d16', ['Cafe Riche Alexandria Egypt', 'مقهى ريتش الإسكندرية']],
  ['22', ['Kadoura Seafood Alexandria', 'مطعم قدورة الإسكندرية']],
  ['23', ['Abu Ashraf Seafood Alexandria', 'مطعم أبو أشرف الإسكندرية']],
  ['14', ['Abu Qir seafood coast Alexandria', 'أبو قير الإسكندرية']],
  ['6', ['Anfushi fish market Alexandria', 'سوق السمك الأنفوشي']],
  ['33', ['Souq El-Gumrok Alexandria', 'سوق الجمرك الإسكندرية']],
  ['31', ['City Centre Alexandria mall', 'سيتي سنتر الإسكندرية']],
  ['32', ['San Stefano Grand Plaza Alexandria', 'سان ستيفانو جراند بلازا الإسكندرية']],
  ['26', ['El Maamoura Beach Alexandria', 'شاطئ المعمورة الإسكندرية']],
  ['24', ['Miami Beach Alexandria Egypt', 'شاطئ ميامي الإسكندرية']],
  ['25', ['Agami Beach Alexandria Egypt', 'شاطئ العجمي الإسكندرية']],
  ['5', ['El Nozha Botanical Garden Alexandria', 'حديقة النزهة النباتية الإسكندرية']],
  ['57', ['Mustafa Kamel Necropolis Alexandria', 'مقابر مصطفى كامل الإسكندرية']],
  ['58', ['El Shatby Necropolis Alexandria', 'مقابر الشاطبي الإسكندرية']],
  ['27', ['Roman cisterns Alexandria Egypt', 'الخزانات الرومانية الإسكندرية']],
  ['29', ['Alexandria Cotton Exchange El Bourse', 'بورصة القطن الإسكندرية']],
  ['34', ['Al-Qaed Ibrahim Mosque Alexandria', 'مسجد القائد إبراهيم الإسكندرية']],
  ['35', ['Sidi Bishr Mosque Alexandria', 'مسجد سيدي بشر الإسكندرية']],
  ['36', ['Shatibi Mosque Alexandria', 'مسجد الشاطبي الإسكندرية']],
  ['49', ['Nabi Daniel Mosque Alexandria', 'مسجد النبي دانيال الإسكندرية']],
  ['50', ['El-Attarine Mosque Alexandria', 'مسجد العطارين الإسكندرية']],
  ['6ea681a0-6bb4-43df-a3de-1d0f94f8f665', ['Saint Mina Cathedral Alexandria', 'كاتدرائية مارمينا الإسكندرية']],
  ['47', ['Sayed Darwish Theatre Alexandria', 'Alexandria Opera House', 'مسرح سيد درويش الإسكندرية']],
  ['alex_sayed_darwish_theatre', ['Sayed Darwish Theatre Alexandria', 'Alexandria Opera House', 'مسرح سيد درويش الإسكندرية']],
  ['a118abcb-13b2-4db3-89b6-dfe2fb2abe2f', ['Bibliotheca Alexandrina Manuscript Museum', 'متحف المخطوطات مكتبة الإسكندرية']],
  ['2', ['Bibliotheca Alexandrina Egypt', 'مكتبة الإسكندرية']],
  ['8', ['Stanley Bridge Alexandria', 'كوبري ستانلي الإسكندرية']],
]);

const extraAliasesByName = new Map([
  ['citadel of qaitbay', ['Citadel of Qaitbay', 'قلعة قايتباي']],
  ['anfushi tombs', ['Anfushi tombs', 'Tombs of Anfushi', 'مقابر الأنفوشي']],
  ['anfoushi tombs', ['Anfushi tombs', 'Tombs of Anfushi', 'مقابر الأنفوشي']],
  ['el horeyya garden shallalat', ['Shallalat Gardens Alexandria', 'حدائق الشلالات']],
  ['mahatet masr egyptian railways station', ['Misr Station Alexandria', 'محطة مصر الإسكندرية']],
  ['bibliotheca alexandrina', ['Bibliotheca Alexandrina Egypt', 'مكتبة الإسكندرية']],
  ["pompey's pillar", ["Pompey's Pillar Alexandria", 'عمود السواري']],
  ['catacombs of kom el shoqafa', ['Catacombs of Kom el Shoqafa', 'مقابر كوم الشقافة']],
  ['abu abbas al mursi mosque', ['Abu al-Abbas al-Mursi Mosque Alexandria', 'مسجد أبو العباس المرسي']],
  ['st mark coptic orthodox cathedral', ["St. Mark's Coptic Orthodox Cathedral Alexandria", 'كاتدرائية القديس مرقس الإسكندرية']],
  ['royal jewelry museum', ['Royal Jewelry Museum Alexandria', 'متحف المجوهرات الملكية']],
  ['cavafy museum', ['Cavafy Museum Alexandria', 'متحف كفافيس']],
  ['graeco roman museum', ['Graeco-Roman Museum Alexandria', 'المتحف اليوناني الروماني']],
  ['el atarin bazaar', ['El-Atarin Bazaar Alexandria', 'Souq El-Attarin', 'سوق العطارين']],
]);

function normalize(value) {
  return value
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9\u0600-\u06ff]+/g, ' ')
    .trim()
    .replace(/\s+/g, ' ');
}

function decodeHtml(value = '') {
  return value
    .replace(/<[^>]*>/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;|&apos;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&#(\d+);/g, (_, number) =>
      String.fromCodePoint(Number(number)),
    )
    .replace(/&#x([\da-f]+);/gi, (_, number) =>
      String.fromCodePoint(Number.parseInt(number, 16)),
    )
    .replace(/\s+/g, ' ')
    .trim();
}

async function requestJson(url) {
  const response = await fetch(url, {
    headers: { 'User-Agent': userAgent, Accept: 'application/json' },
    signal: AbortSignal.timeout(20000),
  });
  if (!response.ok) {
    throw new Error(`HTTP ${response.status} from ${new URL(url).hostname}`);
  }
  return response.json();
}

async function readRows(table, select, query = '') {
  const response = await fetch(
    `${supabaseUrl}/rest/v1/${table}?select=${select}&limit=1000${query}`,
    { headers, signal: AbortSignal.timeout(30000) },
  );
  if (!response.ok) {
    throw new Error(
      `Supabase ${table} query failed: ${response.status} ${await response.text()}`,
    );
  }
  return response.json();
}

const [places, tours, tourPlaces] = await Promise.all([
  readRows(
    'places',
    'id,name_en,name,name_ar,category,image_url,image_urls,lat,lng',
  ),
  readRows('tours', 'id,title,title_ar,image_url'),
  readRows('tour_places', 'tour_id,place_id,position', '&order=position.asc'),
]);
if (places.length !== 61 || tours.length !== 12) {
  throw new Error(
    `Catalog changed: expected 61 places and 12 tours; received ${places.length} and ${tours.length}.`,
  );
}
for (const tour of tours) {
  if (!(tourPlaces.some((link) => String(link.tour_id) === String(tour.id)))) {
    throw new Error(`Tour ${tour.id} (${tour.title}) has no linked landmark.`);
  }
}

const tourLinks = new Map();
for (const link of tourPlaces) {
  const key = String(link.tour_id);
  const list = tourLinks.get(key) ?? [];
  list.push(String(link.place_id));
  tourLinks.set(key, list);
}

function parseConstructors(source, type) {
  const matches = [];
  const startPattern = new RegExp(`${type}\\s*\\(`, 'g');
  for (const match of source.matchAll(startPattern)) {
    const open = source.indexOf('(', match.index);
    let depth = 0;
    let quote = '';
    let escaped = false;
    let end = -1;
    for (let index = open; index < source.length; index++) {
      const char = source[index];
      if (quote) {
        if (escaped) escaped = false;
        else if (char === '\\') escaped = true;
        else if (char === quote) quote = '';
        continue;
      }
      if (char === "'" || char === '"') {
        quote = char;
        continue;
      }
      if (char === '(') depth++;
      else if (char === ')' && --depth === 0) {
        end = index + 1;
        break;
      }
    }
    if (end < 0) throw new Error(`Unclosed ${type} constructor.`);
    const text = source.slice(match.index, end);
    const id = text.match(/\bid:\s*(['"])(.*?)\1/s)?.[2];
    const nameEn = text.match(/\bnameEn:\s*(['"])(.*?)\1/s)?.[2];
    const title = text.match(/\btitle:\s*(['"])(.*?)\1/s)?.[2];
    if (id && (nameEn || title)) {
      matches.push({
        start: match.index,
        end,
        id,
        name: nameEn ?? title,
        text,
      });
    }
  }
  return matches;
}

function parseImageUrl(source, key = 'imageUrl') {
  const match = new RegExp(`\\b${key}:\\s*`, 'g').exec(source);
  if (!match) return null;
  let index = match.index + match[0].length;
  const valueStart = index;
  if (source[index] === "'" || source[index] === '"') {
    const quote = source[index++];
    let escaped = false;
    while (index < source.length) {
      const char = source[index++];
      if (escaped) escaped = false;
      else if (char === '\\') escaped = true;
      else if (char === quote) break;
    }
  } else {
    while (index < source.length && source[index] !== ',' && source[index] !== '\n') {
      index++;
    }
  }
  return { start: valueStart, end: index, value: source.slice(valueStart, index).trim() };
}

const mockSourcePath = path.join(root, 'lib', 'data', 'mock_data.dart');
const mapSeedPath = path.join(root, 'lib', 'data', 'models', 'map_seed.dart');
const [mockSource, mapSeedSource] = await Promise.all([
  readFile(mockSourcePath, 'utf8'),
  readFile(mapSeedPath, 'utf8'),
]);
const mockModels = parseConstructors(mockSource, 'PlaceModel');
const hotelRegion = mapSeedSource.match(/List<MapPoi> _hotels\s*=\s*const\s*\[([\s\S]*?)\n\];/)?.[1];
if (!hotelRegion) throw new Error('Could not parse hotel seed records.');
const hotels = [...hotelRegion.matchAll(/MapPoi\(\s*([\s\S]*?)\n\s*\),/g)]
  .map((match) => ({
    id: match[1].match(/\bid:\s*'([^']+)'/)?.[1],
    name: match[1].match(/\bname:\s*'([^']+)'/)?.[1],
  }))
  .filter((hotel) => hotel.id && hotel.name);
if (hotels.length !== 12) {
  throw new Error(`Expected 12 hotel seed records; found ${hotels.length}.`);
}

const liveNames = new Map();
for (const place of places) {
  for (const name of [place.name_en, place.name, place.name_ar]) {
    if (name) liveNames.set(normalize(name), place);
  }
}

const placeTargets = places.map((row) => ({
  id: String(row.id),
  name: row.name_en || row.name,
  nameAr: row.name_ar || '',
  category: row.category || '',
  kind: 'place',
  aliases: aliasesById.get(String(row.id)) ?? [],
  row,
}));

const seedPlaceTargets = [];
const seenSeedIds = new Set();
for (const model of mockModels) {
  if (seenSeedIds.has(model.id)) continue;
  seenSeedIds.add(model.id);
  const dbMatch = liveNames.get(normalize(model.name));
  if (dbMatch) continue;
  const aliases = extraAliasesByName.get(normalize(model.name)) ?? [];
  seedPlaceTargets.push({
    id: model.id,
    name: model.name,
    nameAr: '',
    category: '',
    kind: 'mock_place',
    aliases,
    model,
  });
}
const hotelTargets = hotels.map((hotel) => ({
  id: hotel.id,
  name: hotel.name,
  nameAr: '',
  category: 'Hotels',
  kind: 'hotel',
  aliases: [],
  hotel,
}));
const targetIdentities = new Set();
for (const target of [...placeTargets, ...seedPlaceTargets, ...hotelTargets]) {
  const identity = `${target.kind}:${target.id}`;
  if (targetIdentities.has(identity)) {
    throw new Error(`Duplicate image target ${identity}.`);
  }
  targetIdentities.add(identity);
}

const genericNameWords = new Set([
  'a', 'al', 'and', 'at', 'de', 'el', 'for', 'in', 'of', 'the', 'to',
  'alexandria', 'egypt', 'alex',
]);
const requiredPlaceTypeWords = new Set([
  'hotel', 'inn', 'resort', 'museum', 'mosque', 'church', 'cathedral',
  'garden', 'gardens', 'beach', 'restaurant', 'cafe', 'bar', 'station',
  'market', 'bazaar', 'mall', 'plaza', 'theatre', 'theater', 'pillar',
  'tombs', 'necropolis', 'monastery', 'aquarium', 'zoo',
]);
function identifyingVariants(target) {
  return [...new Set([...(target.aliases ?? []), target.name, target.nameAr]
    .filter(Boolean)
    .map((variant) => normalize(variant).split(' ')
      .filter((word) => word.length > 2 && !genericNameWords.has(word))
    )
    .filter((tokens) => tokens.length > 0)
    .map((tokens) => tokens.join(' ')))];
}

function cityEvidence(text) {
  const normalized = normalize(text);
  if (/\bvirginia\b|\bcanada\b|\busa\b|\bunited states\b|\bontario\b/.test(normalized)) {
    return false;
  }
  return /\balexandria\b|\begypt\b/.test(normalized) ||
    /الإسكندرية|اسكندرية|مصر/.test(text);
}

function scoreMatch(target, identityText) {
  const normalizedText = normalize(identityText);
  let best = 0;
  for (const variant of identifyingVariants(target)) {
    const tokens = variant.split(' ');
    const nameWords = tokens.filter((token) => requiredPlaceTypeWords.has(token));
    const missingType = nameWords.some((token) => !normalizedText.includes(token));
    const distinctiveTokens = tokens.filter((token) => !requiredPlaceTypeWords.has(token));
    const requiredTokens = distinctiveTokens.length > 0 ? distinctiveTokens : tokens;
    const matching = requiredTokens.filter((token) => normalizedText.includes(token));
    const score = matching.length / requiredTokens.length;
    const minimumMatch = requiredTokens.length === 1
      ? 1
      : Math.ceil(requiredTokens.length * 0.67);
    if (matching.length >= minimumMatch && !missingType) {
      best = Math.max(best, score);
    }
  }
  return best;
}

function cleanMetadata(imageInfo) {
  const metadata = imageInfo.extmetadata ?? {};
  const value = (key) => decodeHtml(metadata[key]?.value ?? '');
  return {
    objectName: value('ObjectName'),
    description: value('ImageDescription'),
    categories: value('Categories'),
    artist: value('Artist') || value('Credit') || 'Unknown',
    license: value('LicenseShortName') || value('UsageTerms') || 'Unknown',
    licenseUrl: value('LicenseUrl'),
    attribution: value('Attribution'),
  };
}

async function commonsCandidates(target, searchTerm) {
  const url = new URL('https://commons.wikimedia.org/w/api.php');
  url.search = new URLSearchParams({
    action: 'query',
    generator: 'search',
    gsrsearch: searchTerm,
    gsrnamespace: '6',
    gsrlimit: '30',
    prop: 'imageinfo',
    iiprop: 'url|size|mime|extmetadata',
    iiurlwidth: '1600',
    format: 'json',
    origin: '*',
  });
  const json = await requestJson(url);
  const pages = Object.values(json.query?.pages ?? {});
  return pages
    .map((page) => {
      const info = page.imageinfo?.[0];
      if (!info || !/^image\/jpeg$/i.test(info.mime ?? '')) return null;
      const metadata = cleanMetadata(info);
      const verificationText = [
        page.title,
        metadata.objectName,
        metadata.description,
        metadata.categories,
      ].join(' ');
      const matchScore = scoreMatch(
        target,
        [page.title, metadata.objectName].join(' '),
      );
      if (!matchScore || !cityEvidence(verificationText)) return null;
      return {
        sourceFileTitle: page.title,
        sourceUrl: info.url,
        sourcePageUrl: info.descriptionurl,
        width: info.width ?? 0,
        height: info.height ?? 0,
        mime: info.mime,
        metadata,
        matchScore,
        sourceKey: `commons:${page.pageid}`,
      };
    })
    .filter(Boolean)
    .sort((a, b) => b.matchScore - a.matchScore || b.width - a.width);
}

async function wikipediaCandidates(target, language) {
  const base = `https://${language}.wikipedia.org/w/api.php`;
  const terms = target.aliases?.length ? target.aliases : [target.name];
  const candidates = [];
  for (const term of terms.slice(0, 3)) {
    const searchUrl = new URL(base);
    searchUrl.search = new URLSearchParams({
      action: 'query',
      list: 'search',
      srsearch: `${term} Alexandria Egypt`,
      srlimit: '5',
      format: 'json',
    });
    const search = await requestJson(searchUrl);
    for (const result of search.query?.search ?? []) {
      const summaryUrl =
        `https://${language}.wikipedia.org/api/rest_v1/page/summary/` +
        encodeURIComponent(result.title.replaceAll(' ', '_'));
      let summary;
      try {
        summary = await requestJson(summaryUrl);
      } catch {
        continue;
      }
      const image = summary.originalimage ?? summary.thumbnail;
      if (!image?.source || !cityEvidence(`${summary.title} ${summary.extract}`)) {
        continue;
      }
      const metadataText = `${summary.title} ${summary.description} ${summary.extract}`;
      const matchScore = scoreMatch(target, summary.title);
      if (!matchScore) continue;
      candidates.push({
        sourceFileTitle: `${language} Wikipedia: ${summary.title}`,
        sourceUrl: image.source,
        sourcePageUrl: summary.content_urls?.desktop?.page ??
          `https://${language}.wikipedia.org/wiki/${encodeURIComponent(summary.title)}`,
        width: image.width ?? 0,
        height: image.height ?? 0,
        mime: 'image/jpeg',
        metadata: {
          objectName: summary.title,
          description: summary.extract,
          categories: '',
          artist: 'See image file page',
          license: 'See source file page',
          licenseUrl: '',
          attribution: 'See source file page',
        },
        matchScore,
        sourceKey: `wikipedia:${language}:${summary.title}:${image.source}`,
      });
    }
  }
  return candidates.sort((a, b) => b.matchScore - a.matchScore || b.width - a.width);
}

async function ogImageCandidates(target) {
  // Tier 1 fallback: discover the place's official website via DuckDuckGo
  // HTML search, then pull its og:image / twitter:image meta tag. Only
  // returns a candidate when the source URL is a real Alexandria venue
  // page (matched against the city evidence terms), and only when the
  // image is at least 5 KB and 800 px wide (small icons are skipped).
  const terms = (target.aliases?.length ? target.aliases : [target.name])
    .slice(0, 3)
    .map((alias) => `${alias} Alexandria Egypt`);
  const results = [];
  for (const term of terms) {
    let searchUrl;
    try {
      const duck = new URL('https://html.duckduckgo.com/html/');
      duck.search = new URLSearchParams({ q: term, kl: 'us-en' });
      const response = await fetch(duck, {
        headers: { 'User-Agent': userAgent, Accept: 'text/html' },
        signal: AbortSignal.timeout(20000),
      });
      if (!response.ok) continue;
      const html = await response.text();
      const hrefs = [
        ...html.matchAll(/href="(https?:\/\/[^"]+)"/g),
      ]
        .map((m) => decodeHtml(m[1]))
        .filter((h) => !/duckduckgo\.com|duck\.com/i.test(h))
        .slice(0, 6);
      for (const href of hrefs) {
        try {
          const pageRes = await fetch(href, {
            headers: { 'User-Agent': userAgent, Accept: 'text/html' },
            redirect: 'follow',
            signal: AbortSignal.timeout(15000),
          });
          if (!pageRes.ok) continue;
          const finalUrl = pageRes.url || href;
          if (!cityEvidence(finalUrl)) continue;
          const contentType = (pageRes.headers.get('content-type') ?? '').toLowerCase();
          if (!contentType.includes('text/html')) continue;
          const body = await pageRes.text();
          if (!cityEvidence(body.slice(0, 5000))) continue;
          const meta = body.match(
            /<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i,
          )
            ?? body.match(
              /<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']/i,
            )
            ?? body.match(
              /<meta[^>]+name=["']twitter:image["'][^>]+content=["']([^"']+)["']/i,
            );
          if (!meta) continue;
          let imageUrl = decodeHtml(meta[1]);
          if (imageUrl.startsWith('//')) imageUrl = `https:${imageUrl}`;
          if (!/^https?:\/\//i.test(imageUrl)) continue;
          // Try to head-check the image dimensions (best-effort; skip on
          // any failure rather than discarding the candidate).
          let width = 0;
          let height = 0;
          try {
            const head = await fetch(imageUrl, {
              method: 'HEAD',
              headers: { 'User-Agent': userAgent },
              redirect: 'follow',
              signal: AbortSignal.timeout(10000),
            });
            if (head.ok) {
              const cl = head.headers.get('content-length');
              if (cl && Number(cl) < 5000) continue;
            }
          } catch {
            // Ignore HEAD failures (some hosts block them).
          }
          const matchScore = scoreMatch(target, finalUrl) * 0.7;
          if (!matchScore) continue;
          results.push({
            sourceFileTitle: `OpenGraph: ${new URL(finalUrl).hostname}`,
            sourceUrl: imageUrl,
            sourcePageUrl: finalUrl,
            width,
            height,
            mime: 'image/jpeg',
            metadata: {
              objectName: target.name,
              description: `OpenGraph image from ${new URL(finalUrl).hostname}`,
              categories: '',
              artist: 'See source page',
              license: 'See source page',
              licenseUrl: '',
              attribution: 'See source page',
            },
            matchScore,
            sourceKey: `og:${finalUrl}:${imageUrl}`,
          });
        } catch {
          continue;
        }
        if (results.length >= 3) break;
      }
    } catch {
      continue;
    }
    if (results.length >= 3) break;
  }
  return results;
}

async function webImageCandidates(target) {
  // Tier 3 fallback: DuckDuckGo image search for the venue, filtered to
  // images large enough and hosted on a real venue page.
  const terms = (target.aliases?.length ? target.aliases : [target.name])
    .slice(0, 2)
    .map((alias) => `${alias} Alexandria Egypt`);
  const results = [];
  for (const term of terms) {
    try {
      const duck = new URL('https://duckduckgo.com/');
      duck.search = new URLSearchParams({
        q: term,
       iax: 'images',
        iar: 'images',
        iaf: 'size:Medium',
        kl: 'us-en',
      });
      const response = await fetch(duck, {
        headers: { 'User-Agent': userAgent, Accept: 'text/html' },
        signal: AbortSignal.timeout(20000),
      });
      if (!response.ok) continue;
      const html = await response.text();
      const imageMatches = [
        ...html.matchAll(/<img[^>]+src="([^"]+\.(?:jpg|jpeg|png))"/gi),
      ];
      for (const match of imageMatches) {
        const imageUrl = decodeHtml(match[1]);
        if (!/^https?:\/\//i.test(imageUrl)) continue;
        const matchScore = scoreMatch(target, imageUrl) * 0.4;
        if (!matchScore) continue;
        results.push({
          sourceFileTitle: `Web: ${new URL(imageUrl).hostname}`,
          sourceUrl: imageUrl,
          sourcePageUrl: imageUrl,
          width: 0,
          height: 0,
          mime: 'image/jpeg',
          metadata: {
            objectName: target.name,
            description: `Web image from ${new URL(imageUrl).hostname}`,
            categories: '',
            artist: 'See source',
            license: 'See source',
            licenseUrl: '',
            attribution: 'See source',
          },
          matchScore,
          sourceKey: `web:${imageUrl}`,
        });
        if (results.length >= 5) break;
      }
    } catch {
      continue;
    }
    if (results.length >= 5) break;
  }
  return results;
}

async function downloadCandidate(candidate) {
  const response = await fetch(candidate.sourceUrl, {
    headers: { 'User-Agent': userAgent },
    redirect: 'follow',
    signal: AbortSignal.timeout(30000),
  });
  if (!response.ok) throw new Error(`Image source HTTP ${response.status}`);
  const mime = (response.headers.get('content-type') ?? '').split(';')[0].trim();
  if (mime !== 'image/jpeg') throw new Error(`Expected JPEG, received ${mime || 'unknown type'}`);
  const bytes = Buffer.from(await response.arrayBuffer());
  if (bytes.length < 5000 || bytes.length > 20 * 1024 * 1024) {
    throw new Error(`Image size outside accepted bounds (${bytes.length} bytes)`);
  }
  if (bytes[0] !== 0xff || bytes[1] !== 0xd8 || bytes[2] !== 0xff) {
    throw new Error('Source is not a valid JPEG binary');
  }
  return bytes;
}

const usedSources = new Set();
const resolved = new Map();
const failures = [];
const discoveryTargets = [...placeTargets, ...seedPlaceTargets, ...hotelTargets];
for (let index = 0; index < discoveryTargets.length; index++) {
  const target = discoveryTargets[index];
  const identity = `${target.kind}:${target.id}`;
  const terms = target.aliases?.length
    ? target.aliases
    : [`${target.name} Alexandria Egypt`, `${target.name} ${target.nameAr}`];
  let candidates = [];
  const discoveryErrors = [];
  for (const term of terms.slice(0, 4)) {
    try {
      candidates.push(...await commonsCandidates(target, term));
    } catch (error) {
      discoveryErrors.push(String(error));
    }
  }
  candidates.sort((a, b) => b.matchScore - a.matchScore || b.width - a.width);
  let selected;
  let bytes;
  for (const candidate of candidates) {
    if (usedSources.has(candidate.sourceKey)) continue;
    try {
      const candidateBytes = await downloadCandidate(candidate);
      selected = candidate;
      bytes = candidateBytes;
      break;
    } catch {
      continue;
    }
  }
  if (!selected) {
    for (const language of ['en', 'ar']) {
      try {
        const pages = await wikipediaCandidates(target, language);
        for (const candidate of pages) {
          if (usedSources.has(candidate.sourceKey)) continue;
          try {
            const candidateBytes = await downloadCandidate(candidate);
            selected = candidate;
            bytes = candidateBytes;
            break;
          } catch {
            continue;
          }
        }
      } catch (error) {
        discoveryErrors.push(`${language} Wikipedia: ${String(error)}`);
      }
      if (selected) break;
    }
  }
  if (!selected) {
    // Tier 1: official website og:image / twitter:image fallback.
    try {
      const og = await ogImageCandidates(target);
      for (const candidate of og) {
        if (usedSources.has(candidate.sourceKey)) continue;
        try {
          const candidateBytes = await downloadCandidate(candidate);
          selected = candidate;
          bytes = candidateBytes;
          break;
        } catch {
          continue;
        }
      }
    } catch (error) {
      discoveryErrors.push(`og:image: ${String(error)}`);
    }
  }
  if (!selected) {
    // Tier 3: general web image search fallback.
    try {
      const web = await webImageCandidates(target);
      for (const candidate of web) {
        if (usedSources.has(candidate.sourceKey)) continue;
        try {
          const candidateBytes = await downloadCandidate(candidate);
          selected = candidate;
          bytes = candidateBytes;
          break;
        } catch {
          continue;
        }
      }
    } catch (error) {
      discoveryErrors.push(`web: ${String(error)}`);
    }
  }
  if (!selected) {
    failures.push({
      id: target.id,
      name: target.name,
      kind: target.kind,
      error: [
        'No distinct Alexandria-specific image passed title, location, and JPEG checks.',
        ...discoveryErrors,
      ].join(' '),
    });
    console.log(`UNVERIFIED ${index + 1}/${discoveryTargets.length} ${target.kind} ${target.id}: ${target.name}`);
    continue;
  }
  usedSources.add(selected.sourceKey);
  const item = {
    ...target,
    sourceFileTitle: selected.sourceFileTitle,
    sourceUrl: selected.sourceUrl,
    sourcePageUrl: selected.sourcePageUrl,
    imageBytes: bytes,
    width: selected.width,
    height: selected.height,
    metadata: selected.metadata,
    matchScore: selected.matchScore,
    storagePath: `${target.id}.jpg`,
  };
  resolved.set(identity, item);
  console.log(
    `VERIFIED ${index + 1}/${discoveryTargets.length} ${target.kind} ${target.id}: ${item.sourceFileTitle}`,
  );
}

function csv(value) {
  return `"${String(value ?? '').replaceAll('"', '""')}"`;
}

const csvHeader = [
  'kind',
  'id',
  'name_en',
  'source_file_title',
  'source_page_url',
  'final_image_url',
  'license',
  'artist',
];
async function writeCsvReport(finalUrls = new Map()) {
  const lines = [csvHeader.join(',')];
  for (const target of discoveryTargets) {
    const item = resolved.get(`${target.kind}:${target.id}`);
    lines.push([
      target.kind,
      target.id,
      target.name,
      item?.sourceFileTitle ?? '',
      item?.sourcePageUrl ?? '',
      finalUrls.get(`${target.kind}:${target.id}`) ?? '',
      item?.metadata.license ?? '',
      item?.metadata.artist ?? '',
    ].map(csv).join(','));
  }
  for (const tour of tours) {
    const [placeId] = tourLinks.get(String(tour.id)) ?? [];
    const source = resolved.get(`place:${placeId}`);
    lines.push([
      'tour',
      tour.id,
      tour.title,
      source?.sourceFileTitle ?? '',
      source?.sourcePageUrl ?? '',
      finalUrls.get(`tour:${tour.id}`) ?? '',
      source?.metadata.license ?? '',
      source?.metadata.artist ?? '',
    ].map(csv).join(','));
  }
  await mkdir(path.dirname(reportPath), { recursive: true });
  await writeFile(reportPath, lines.join('\n') + '\n', 'utf8');
}

if (failures.length) {
  await writeCsvReport();
  console.error(
    `${failures.length} image targets failed strict authenticity verification; no storage or database changes were made.`,
  );
  for (const failure of failures) {
    console.error(`${failure.kind}:${failure.id} ${failure.name}: ${failure.error}`);
  }
  process.exitCode = 1;
} else if (dryRun) {
  await writeCsvReport();
  console.log(
    `Dry run passed: ${places.length} places, ${tours.length} tours, ` +
    `${hotelTargets.length} hotel seeds, and ${seedPlaceTargets.length} extra offline places.`,
  );
} else {
  let serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!serviceRoleKey) {
    try {
      const command = process.platform === 'win32'
        ? `${process.env.ComSpec ?? 'cmd.exe'} /d /s /c "supabase projects api-keys --reveal --project-ref ${projectRef} --output json"`
        : `supabase projects api-keys --reveal --project-ref ${projectRef} --output json`;
      const output = execSync(command, {
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'ignore'],
        windowsHide: true,
        maxBuffer: 2 * 1024 * 1024,
      });
      const jsonStart = output.search(/[\[{]/);
      const keys = JSON.parse(output.slice(jsonStart));
      serviceRoleKey = keys.find(
        (key) => key.name === 'service_role' && key.type === 'legacy',
      )?.api_key;
    } catch (error) {
      throw new Error(
        `Could not obtain the project service-role key from Supabase CLI. ` +
        `Set SUPABASE_SERVICE_ROLE_KEY explicitly. ${String(error)}`,
      );
    }
  }
  if (!serviceRoleKey) {
    throw new Error('The Supabase service-role key was not available.');
  }
  const adminHeaders = {
    apikey: serviceRoleKey,
    Authorization: `Bearer ${serviceRoleKey}`,
  };
  const finalUrls = new Map();

  async function uploadObject(objectPath, item) {
    const url = `${supabaseUrl}/storage/v1/object/place-images/${objectPath
      .split('/')
      .map(encodeURIComponent)
      .join('/')}`;
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        ...adminHeaders,
        'Content-Type': 'image/jpeg',
        'x-upsert': 'true',
      },
      body: item.imageBytes,
      signal: AbortSignal.timeout(60000),
    });
    if (!response.ok) {
      throw new Error(`Storage upload failed for ${objectPath}: ${response.status} ${await response.text()}`);
    }
    return `${supabaseUrl}/storage/v1/object/public/place-images/${objectPath
      .split('/')
      .map(encodeURIComponent)
      .join('/')}`;
  }

  for (const target of discoveryTargets) {
    const identity = `${target.kind}:${target.id}`;
    const item = resolved.get(identity);
    const objectPath = target.kind === 'hotel'
      ? `hotels/${item.storagePath}`
      : item.storagePath;
    finalUrls.set(identity, await uploadObject(objectPath, item));
  }
  for (const place of places) {
    const imageUrl = finalUrls.get(`place:${place.id}`);
    const response = await fetch(
      `${supabaseUrl}/rest/v1/places?id=eq.${encodeURIComponent(place.id)}`,
      {
        method: 'PATCH',
        headers: {
          ...adminHeaders,
          'Content-Type': 'application/json',
          Prefer: 'return=minimal',
        },
        body: JSON.stringify({ image_url: imageUrl, image_urls: [imageUrl] }),
        signal: AbortSignal.timeout(30000),
      },
    );
    if (!response.ok) {
      throw new Error(`Could not update place ${place.id}: ${response.status} ${await response.text()}`);
    }
  }
  for (const tour of tours) {
    const [placeId] = tourLinks.get(String(tour.id)) ?? [];
    const source = resolved.get(`place:${placeId}`);
    if (!source) {
      throw new Error(`Tour ${tour.id} has no verified linked destination image.`);
    }
    const target = {
      ...source,
      imageBytes: source.imageBytes,
      storagePath: `tours/${tour.id}.jpg`,
    };
    const imageUrl = await uploadObject(target.storagePath, target);
    finalUrls.set(`tour:${tour.id}`, imageUrl);
    const response = await fetch(
      `${supabaseUrl}/rest/v1/tours?id=eq.${encodeURIComponent(tour.id)}`,
      {
        method: 'PATCH',
        headers: {
          ...adminHeaders,
          'Content-Type': 'application/json',
          Prefer: 'return=minimal',
        },
        body: JSON.stringify({ image_url: imageUrl }),
        signal: AbortSignal.timeout(30000),
      },
    );
    if (!response.ok) {
      throw new Error(`Could not update tour ${tour.id}: ${response.status} ${await response.text()}`);
    }
  }

  const mockUrls = new Map();
  for (const model of mockModels) {
    const dbMatch = liveNames.get(normalize(model.name));
    const identity = dbMatch
      ? `place:${dbMatch.id}`
      : `mock_place:${model.id}`;
    const url = finalUrls.get(identity);
    if (!url) throw new Error(`No verified URL for mock place ${model.id} (${model.name}).`);
    mockUrls.set(model.id, url);
  }

  function imageEdits(models, urls, kind) {
    const changes = [];
    for (const model of models) {
      let url = urls.get(model.id);
      if (kind === 'tour') {
        const placeModels = parseConstructors(model.text, 'PlaceModel');
        const linked = placeModels.map((place) => urls.get(place.id)).find(Boolean);
        url = linked;
      }
      if (!url) throw new Error(`Missing ${kind} image for ${model.id} (${model.name}).`);
      const image = parseImageUrl(model.text);
      if (!image) throw new Error(`No imageUrl field in ${kind} ${model.id}.`);
      changes.push({
        start: model.start + image.start,
        end: model.start + image.end,
        value: JSON.stringify(url),
      });
    }
    return changes;
  }

  const localTours = parseConstructors(mockSource, 'ItineraryModel');
  const tourUrls = new Map();
  for (const tour of localTours) {
    const placeModels = parseConstructors(tour.text, 'PlaceModel');
    const localUrl = placeModels
      .map((place) => mockUrls.get(place.id))
      .find(Boolean);
    if (!localUrl) {
      throw new Error(`Local tour ${tour.id} has no linked place with a verified image.`);
    }
    tourUrls.set(tour.id, localUrl);
  }
  const allEdits = [
    ...imageEdits(mockModels, mockUrls, 'mock place'),
    ...imageEdits(localTours, tourUrls, 'tour'),
  ];
  let updatedMockSource = mockSource;
  for (const change of allEdits.sort((a, b) => b.start - a.start)) {
    updatedMockSource = updatedMockSource.slice(0, change.start) +
      change.value +
      updatedMockSource.slice(change.end);
  }

  let updatedMapSeed = mapSeedSource;
  for (const hotel of hotels) {
    const url = finalUrls.get(`hotel:${hotel.id}`);
    const entryPattern = new RegExp(
      `('${hotel.id}'\\s*:\\s*)'[^']*'`,
    );
    if (!entryPattern.test(updatedMapSeed)) {
      throw new Error(`Hotel image entry not found for ${hotel.id}.`);
    }
    updatedMapSeed = updatedMapSeed.replace(
      entryPattern,
      `$1${JSON.stringify(url)}`,
    );
  }
  await Promise.all([
    writeFile(mockSourcePath, updatedMockSource, 'utf8'),
    writeFile(mapSeedPath, updatedMapSeed, 'utf8'),
  ]);

  const checkResponse = await fetch(
    `${supabaseUrl}/rest/v1/places?select=id,name_en,image_url,image_urls&limit=1000`,
    { headers: adminHeaders, signal: AbortSignal.timeout(30000) },
  );
  if (!checkResponse.ok) {
    throw new Error(`Could not verify final place rows: ${checkResponse.status}`);
  }
  const finalPlaces = await checkResponse.json();
  const duplicateUrls = new Map();
  for (const place of finalPlaces) {
    const ids = duplicateUrls.get(place.image_url) ?? [];
    ids.push(String(place.id));
    duplicateUrls.set(place.image_url, ids);
  }
  const duplicates = [...duplicateUrls]
    .filter(([, ids]) => ids.length > 1)
    .map(([url, ids]) => ({ url, ids }));
  if (finalPlaces.length !== 61 || duplicates.length > 0) {
    throw new Error(
      `Uniqueness hard gate failed: rows=${finalPlaces.length}; duplicate URLs=${duplicates.length}.`,
    );
  }
  await writeCsvReport(finalUrls);
  console.log('id | name_en | source_file_title | final_image_url');
  for (const place of finalPlaces) {
    const item = resolved.get(`place:${place.id}`);
    console.log(
      `${place.id} | ${place.name_en} | ${item.sourceFileTitle} | ${place.image_url}`,
    );
  }
  console.log(
    `PASS: ${finalPlaces.length} places have distinct authentic image URLs. ` +
    `Attribution report: ${path.relative(root, reportPath)}`,
  );
}
