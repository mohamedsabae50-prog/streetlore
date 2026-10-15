import { execSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const reportPath = path.join(root, 'reports', 'authentic_place_images.csv');
const dryRun = process.argv.includes('--dry-run');
function parseCsvRow(line) {
  const values = [];
  let value = '';
  let quoted = false;
  for (let index = 0; index < line.length; index++) {
    const char = line[index];
    if (char === '"' && quoted && line[index + 1] === '"') {
      value += '"';
      index++;
    } else if (char === '"') {
      quoted = !quoted;
    } else if (char === ',' && !quoted) {
      values.push(value);
      value = '';
    } else {
      value += char;
    }
  }
  values.push(value);
  return values;
}
const priorReportText = await readFile(reportPath, 'utf8').catch((error) => {
  if (error.code === 'ENOENT') return '';
  throw error;
});
const priorAttributions = new Map();
if (priorReportText) {
  const [headerLine, ...reportLines] = priorReportText.trimEnd().split(/\r?\n/);
  const header = parseCsvRow(headerLine);
  for (const line of reportLines) {
    const values = parseCsvRow(line);
    const record = Object.fromEntries(header.map((key, index) =>
      [key, values[index] ?? ''],
    ));
    if (record.kind && record.id) {
      priorAttributions.set(`${record.kind}:${record.id}`, record);
    }
  }
}
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
  ['26', ['El Maamoura Beach Alexandria', 'Maamoura Beach Alexandria', 'شاطئ المعمورة الإسكندرية']],
  ['25', ['Agami Beach Alexandria', 'Agamy Beach Alexandria', 'شاطئ العجمي الإسكندرية']],
  ['27', ['Roman Cisterns Alexandria', 'Roman cisterns Kom el-Dikka', 'الخزانات الرومانية الإسكندرية']],
  ['29', ['Alexandria Cotton Exchange', 'Bourse d Alexandria', 'بورصة القطن الإسكندرية']],
  ['36', ['Shatby Mosque Alexandria', 'Shatibi Mosque', 'مسجد الشاطبي الإسكندرية']],
  ['41', ['Jesuit Church Alexandria Egypt', 'Jesuit Church Cleopatra Alexandria', 'كنيسة اليسوعيين الإسكندرية']],
  ['6ea681a0-6bb4-43df-a3de-1d0f94f8f665', ['Saint Mina Cathedral Alexandria', 'Saint Mina Church Mariout Alexandria', 'كاتدرائية مارمينا الإسكندرية']],
  ['14', ['Abu Qir Alexandria beach', 'Abu Qir waterfront Alexandria', 'أبو قير الإسكندرية']],
  ['d88d4a5d-b3b0-4579-bef3-728e41843095', ['Stanley Cafe Alexandria', 'Stanley Café Alexandria Egypt', 'مقهى ستانلي الإسكندرية']],
  ['f54cbabc-3bd6-4af2-96d8-542544dde62e', ['Lighthouse of Alexandria underwater ruins', 'Pharos of Alexandria submerged ruins', 'منارة الإسكندرية الغارقة']],
  ['22', ['Kadoura Seafood Restaurant Alexandria', 'Kadoura Fish Restaurant Alexandria', 'مطعم قدورة الإسكندرية']],
  ['43591966-e37f-4f6a-967c-d94a1a012d16', ['Cafe Riche Alexandria Egypt', 'Café Riche Alexandria Egypt', 'مقهى ريش الإسكندرية']],
  ['33', ['Souq El Gumrok Alexandria', 'El Gomrok market Alexandria', 'سوق الجمرك الإسكندرية']],
  ['5', ['El Nozha Botanical Garden Alexandria', 'Nozha Garden Alexandria', 'حديقة النزهة النباتية الإسكندرية']],
  ['21', ['Zephyrion Restaurant Alexandria', 'Zephyrium Restaurant Alexandria', 'مطعم زيفريون الإسكندرية']],
  ['13', ['El Attarin Bazaar Alexandria', 'Attarine Souq Alexandria', 'سوق العطارين الإسكندرية']],
  ['45', ['Mahmoud Said Museum Alexandria', 'Villa Ambron museum Mahmoud Said Alexandria', 'متحف محمود سعيد الإسكندرية']],
  ['19', ['Trianon Cafe Alexandria', 'Trianon Café Alexandria Egypt', 'مقهى تريانون الإسكندرية']],
  ['58', ['Shatby Necropolis Alexandria', 'Shatby tombs Alexandria', 'جبانة الشاطبي الإسكندرية']],
  ['6', ['Anfushi Fish Market Alexandria', 'Anfushi market Alexandria', 'سوق السمك الأنفوشي الإسكندرية']],
  ['hotel-sofitel-alex', ['Sofitel Cecil Alexandria', 'Cecil Hotel Alexandria Egypt', 'فندق سيسيل الإسكندرية']],
  ['hotel-steigenberger-cerine', ['Steigenberger Cecil Alexandria', 'Cecil Hotel Alexandria', 'فندق سيسيل الإسكندرية']],
  ['hotel-tolip-alex', ['Tolip Hotel Alexandria Egypt', 'Tolip Alexandria Hotel', 'فندق توليب الإسكندرية']],
  ['hotel-paradise', ['Paradise Inn Windsor Palace Alexandria', 'Windsor Palace Hotel Alexandria', 'فندق ويندسور بالاس الإسكندرية']],
  ['hotel-romance-alex', ['Romance Alexandria Hotel', 'Romance Hotel Montazah Alexandria', 'فندق رومانس الإسكندرية']],
  ['hotel-plaza-alex', ['Plaza Hotel Alexandria Egypt', 'Plaza Hotel Alexandria Egypt Stanley', 'فندق بلازا الإسكندرية']],
  ['hotel-king-mariout', ['King Mariout Hotel Alexandria Egypt', 'King Mariout resort Alexandria', 'فندق كينج مريوط الإسكندرية']],
  ['hotel-san-stefano', ['San Stefano Grand Plaza Alexandria Egypt', 'San Stefano Hotel Alexandria Egypt', 'فندق سان ستيفانو الإسكندرية']],
  ['hotel-borg-al-arab', ['Borg El Arab Airport Hotel Alexandria', 'Borg El Arab Hotel Alexandria Egypt', 'فندق برج العرب مطار الإسكندرية']],
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
const EXPLICIT_COMMONS_QUERIES = new Map([
  ['23', ['Abou Ashraf International Fish Alexandria', 'Abu Ashraf Seafood Alexandria Egypt', 'أبو أشرف للمأكولات البحرية الإسكندرية']],
  ['6', ['Anfushi Fish Market Alexandria Egypt', 'Anfoushi fish market Alexandria', 'سوق السمك الأنفوشي الإسكندرية']],
  ['43591966-e37f-4f6a-967c-d94a1a012d16', ['Cafe Riche Alexandria Egypt', 'Café Riche Alexandria restaurant', 'مقهى ريتش الإسكندرية']],
  ['58', ['Chatby Tombs Alexandria Egypt', 'Shatbi Necropolis Alexandria', 'جبانة الشاطبي الإسكندرية']],
  ['13', ['Attarine district Alexandria Egypt', 'Hay al Attarin Alexandria', 'سوق العطارين الإسكندرية']],
  ['29', ['Alexandria Cotton Exchange building Egypt', 'Alexandria Bourse building', 'بورصة القطن الإسكندرية']],
  ['26', ['El Maamoura beach Alexandria Egypt', 'Maamoura Beach Egypt', 'شاطئ المعمورة الإسكندرية']],
  ['5', ['Nozha Botanical Garden Alexandria Egypt', 'El Nozha Garden Alexandria', 'حدائق النزهة الإسكندرية']],
  ['20', ['Elite restaurant Safeya Zaghloul Street Alexandria', 'Elite Cafe Alexandria Egypt', 'إيليت كافيه الإسكندرية']],
  ['41', ['Jesuit Church Cleopatra Alexandria Egypt', 'Sacred Heart Church Alexandria Egypt', 'كنيسة اليسوعيين كليوباترا الإسكندرية']],
  ['22', ['Kadoura Seafood Restaurant Alexandria Egypt', 'Kadoura fish restaurant Alexandria', 'مطعم قدورة الإسكندرية']],
  ['f54cbabc-3bd6-4af2-96d8-542544dde62e', ['Pharos of Alexandria submerged ruins Egypt', 'underwater Lighthouse of Alexandria ruins', 'منارة الإسكندرية الغارقة']],
  ['45', ['Mahmoud Said Museum Villa Ambron Alexandria Egypt', 'Mahmoud Said Museum Alexandria', 'متحف محمود سعيد الإسكندرية']],
  ['v155_pastroudi', ['Pastroudi Restaurant Alexandria Egypt', 'Pastroudi cafe Alexandria', 'مطعم باسترودي الإسكندرية']],
  ['27', ['Roman cisterns Kom el Dikka Alexandria Egypt', 'Roman Cisterns Alexandria', 'الخزانات الرومانية كوم الدكة الإسكندرية']],
  ['36', ['Shatibi Mosque Alexandria Egypt', 'Shatby Mosque Alexandria', 'مسجد الشاطبي الإسكندرية']],
  ['33', ['Gomrok market Alexandria Egypt', 'El Gomrok souq Alexandria', 'سوق الجمرك الإسكندرية']],
  ['d88d4a5d-b3b0-4579-bef3-728e41843095', ['Stanley Cafe Alexandria Egypt', 'Stanley Espresso Bar Alexandria', 'مقهى ستانلي الإسكندرية']],
  ['19', ['Trianon restaurant Alexandria Egypt', 'Trianon Cafe Alexandria Egypt', 'تريانون كافيه الإسكندرية']],
  ['v155_zephyrion', ['Zephyrion Restaurant Alexandria Egypt', 'Zephyrium Restaurant Alexandria', 'مطعم زيفيريون الإسكندرية']],
  ['hotel-king-mariout', ['King Mariout Hotel Alexandria Egypt', 'King Mariout resort Alexandria Egypt', 'فندق كينج مريوط الإسكندرية']],
  ['hotel-borg-al-arab', ['Borg El Arab Airport Hotel Alexandria Egypt', 'Borg El Arab Hotel Egypt', 'فندق برج العرب مطار الإسكندرية']],
]);
const EXPLICIT_COMMONS_SCENE_QUERIES = new Map([
  ['14', ['Seafood restaurants in Alexandria Egypt', 'Abu Qir coast Alexandria Egypt']],
  ['19', ['Cafes in Alexandria Egypt', 'Restaurants in Alexandria Egypt']],
  ['21', ['Seafood restaurants in Alexandria Egypt', 'Abu Qir coast Alexandria Egypt']],
  ['22', ['Seafood restaurants in Alexandria Egypt', 'Fish restaurants in Alexandria Egypt']],
  ['23', ['Seafood restaurants in Alexandria Egypt', 'Fish restaurants in Alexandria Egypt']],
  ['25', ['Beaches of Alexandria Egypt', 'Agami beach Alexandria Egypt']],
  ['26', ['Beaches of Alexandria Egypt', 'Maamoura beach Alexandria Egypt']],
  ['27', ['Roman ruins in Alexandria Egypt', 'Roman cisterns Alexandria Egypt']],
  ['33', ['Markets in Alexandria Egypt', 'Souqs in Alexandria Egypt']],
  ['36', ['Mosques in Alexandria Egypt', 'Shatby mosque Alexandria Egypt']],
  ['40', ['Coptic churches in Alexandria Egypt', 'Cathedrals in Alexandria Egypt']],
  ['41', ['Churches in Alexandria Egypt', 'Cleopatra church Alexandria Egypt']],
  ['43591966-e37f-4f6a-967c-d94a1a012d16', ['Cafes in Alexandria Egypt', 'Restaurants in Alexandria Egypt']],
  ['45', ['Mahmoud Said Museum Alexandria Egypt', 'Museums in Alexandria Egypt']],
  ['5', ['Gardens in Alexandria Egypt', 'Botanical gardens Alexandria Egypt']],
  ['6', ['Fish market in Alexandria Egypt', 'Anfushi market Alexandria Egypt']],
  ['6ea681a0-6bb4-43df-a3de-1d0f94f8f665', ['Churches in Mariout Alexandria Egypt', 'Saint Mina Cathedral Alexandria Egypt']],
  ['d88d4a5d-b3b0-4579-bef3-728e41843095', ['Cafes in Alexandria Egypt', 'Stanley Alexandria Egypt']],
  ['f54cbabc-3bd6-4af2-96d8-542544dde62e', ['Pharos of Alexandria Egypt', 'Lighthouse of Alexandria Egypt']],
  ['v155_abu_ashraf', ['Seafood restaurants in Alexandria Egypt', 'Fish restaurants in Alexandria Egypt']],
  ['v155_pastroudi', ['Cafes in Alexandria Egypt', 'Restaurants in Alexandria Egypt']],
  ['v155_zephyrion', ['Seafood restaurants in Alexandria Egypt', 'Abu Qir coast Alexandria Egypt']],
  ['hotel-romance-alex', ['Hotels in Montaza Alexandria Egypt', 'Hotels in Alexandria Egypt']],
  ['hotel-plaza-alex', ['Hotels in Sporting Alexandria Egypt', 'Hotels in Alexandria Egypt']],
  ['hotel-king-mariout', ['Hotels in King Mariout Egypt', 'Hotels in Alexandria Egypt']],
  ['hotel-downtown', ['Hotels in Roushdy Alexandria Egypt', 'Hotels in Alexandria Egypt']],
  ['hotel-borg-al-arab', [
    'Hotels in Borg El Arab Egypt',
    'Hotels in Alexandria Egypt',
    'Borg El Arab International Airport Egypt',
    'Alexandria International Airport Egypt',
  ]],
  ['t3', ['Food in Alexandria Egypt', 'Restaurants in Alexandria Egypt']],
  ['t5', ['Beaches of Alexandria Egypt', 'Alexandria coast Egypt']],
]);
const EXPLICIT_GEO_EVIDENCE = new Map([
  ['14', ['seafood', 'fish', 'restaurant', 'coast', 'beach']],
  ['19', ['cafe', 'coffee', 'restaurant']],
  ['21', ['seafood', 'fish', 'restaurant', 'coast', 'beach']],
  ['22', ['seafood', 'fish', 'restaurant']],
  ['23', ['seafood', 'fish', 'restaurant']],
  ['25', ['beach', 'coast', 'shore']],
  ['26', ['beach', 'coast', 'shore']],
  ['27', ['cistern', 'roman', 'archaeological', 'ruins']],
  ['33', ['market', 'bazaar', 'souq']],
  ['36', ['mosque', 'masjid']],
  ['40', ['church', 'cathedral', 'coptic']],
  ['41', ['church', 'jesuit', 'sacred heart']],
  ['43591966-e37f-4f6a-967c-d94a1a012d16', ['cafe', 'coffee', 'restaurant']],
  ['45', ['museum', 'villa', 'mahmoud said']],
  ['5', ['garden', 'botanical', 'plants']],
  ['6', ['market', 'fish']],
  ['6ea681a0-6bb4-43df-a3de-1d0f94f8f665', ['church', 'cathedral', 'coptic']],
  ['58', ['tomb', 'necropolis', 'archaeological']],
  ['13', ['market', 'bazaar', 'attarin', 'attarine']],
  ['29', ['exchange', 'bourse', 'cotton']],
  ['20', ['cafe', 'coffee', 'restaurant']],
  ['f54cbabc-3bd6-4af2-96d8-542544dde62e', ['underwater', 'submerged', 'pharos', 'lighthouse', 'ruins']],
  ['v155_pastroudi', ['cafe', 'coffee', 'restaurant']],
  ['d88d4a5d-b3b0-4579-bef3-728e41843095', ['cafe', 'coffee', 'restaurant']],
  ['v155_zephyrion', ['seafood', 'fish', 'restaurant']],
  ['v155_abu_ashraf', ['seafood', 'fish', 'restaurant']],
  ['hotel-romance-alex', ['hotel', 'resort', 'accommodation']],
  ['hotel-plaza-alex', ['hotel', 'accommodation']],
  ['hotel-king-mariout', ['hotel', 'resort', 'accommodation']],
  ['hotel-downtown', ['hotel', 'accommodation']],
  ['hotel-borg-al-arab', ['hotel', 'resort', 'airport']],
  ['t3', ['food', 'restaurant', 'market']],
  ['t5', ['beach', 'coast', 'sea']],
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
    .replace(/([a-z])([A-Z])/g, '$1 $2')
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

let commonsQueue = Promise.resolve();
let lastCommonsRequestAt = 0;
async function requestJson(url) {
  const parsedUrl = new URL(url);
  const isWikimedia = /(?:^|\.)wikipedia\.org$|(?:^|\.)wikimedia\.org$/.test(
    parsedUrl.hostname,
  );
  let releaseQueue;
  if (isWikimedia) {
    const previous = commonsQueue;
    commonsQueue = new Promise((resolve) => {
      releaseQueue = resolve;
    });
    await previous;
    const waitMs = 500 - (Date.now() - lastCommonsRequestAt);
    if (waitMs > 0) await new Promise((resolve) => setTimeout(resolve, waitMs));
  }
  try {
    for (let attempt = 1; attempt <= 4; attempt++) {
      const response = await fetch(parsedUrl, {
        headers: { 'User-Agent': userAgent, Accept: 'application/json' },
        signal: AbortSignal.timeout(20000),
      });
      if (response.ok) {
        if (isWikimedia) lastCommonsRequestAt = Date.now();
        return response.json();
      }
      const retryable = response.status === 429 || response.status >= 500;
      if (!retryable || attempt === 4) {
        throw new Error(
          `HTTP ${response.status} from ${parsedUrl.hostname}`,
        );
      }
      const retryAfter = Number(response.headers.get('retry-after'));
      const waitMs = Number.isFinite(retryAfter) && retryAfter > 0
        ? retryAfter * 1000
        : attempt * 2000;
      await new Promise((resolve) => setTimeout(resolve, waitMs));
    }
    throw new Error(`Request retries exhausted for ${parsedUrl.hostname}.`);
  } finally {
    if (isWikimedia) {
      lastCommonsRequestAt = Date.now();
      releaseQueue();
    }
  }
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
const mockTours = parseConstructors(mockSource, 'ItineraryModel');
const hotelRegion = mapSeedSource.match(/List<MapPoi> _hotels\s*=\s*const\s*\[([\s\S]*?)\n\];/)?.[1];
if (!hotelRegion) throw new Error('Could not parse hotel seed records.');
const hotels = [...hotelRegion.matchAll(/MapPoi\(\s*([\s\S]*?)\n\s*\),/g)]
  .map((match) => ({
    id: match[1].match(/\bid:\s*'([^']+)'/)?.[1],
    name: match[1].match(/\bname:\s*'([^']+)'/)?.[1],
    lat: Number(match[1].match(/\blat:\s*([\d.]+)/)?.[1]),
    lng: Number(match[1].match(/\blng:\s*([\d.]+)/)?.[1]),
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
  aliases: [
    ...(EXPLICIT_COMMONS_QUERIES.get(String(row.id)) ?? []),
    ...(aliasesById.get(String(row.id)) ?? []),
  ],
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
  aliases: [
    ...(EXPLICIT_COMMONS_QUERIES.get(hotel.id) ?? []),
    ...(aliasesById.get(hotel.id) ?? []),
  ],
  lat: hotel.lat,
  lng: hotel.lng,
  hotel,
}));
const tourTargets = tours.map((tour) => {
  const linkedPlaces = (tourLinks.get(String(tour.id)) ?? [])
    .map((id) => places.find((place) => String(place.id) === id))
    .filter(Boolean);
  return {
    id: String(tour.id),
    name: tour.title,
    nameAr: tour.title_ar || '',
    category: tour.category || '',
    kind: 'tour',
    aliases: [
      `${tour.title} Alexandria Egypt`,
      ...linkedPlaces.flatMap((place) => [
        place.name_en || place.name,
        place.name_ar,
      ].filter(Boolean)),
    ],
    row: tour,
    linkedPlaces,
  };
});
const mockTourTargets = mockTours
  .filter((tour) => !tours.some((row) =>
    String(row.id) === tour.id ||
    normalize(row.title) === normalize(tour.name),
  ))
  .map((tour) => {
    const linkedPlaces = parseConstructors(tour.text, 'PlaceModel');
    return {
      id: tour.id,
      name: tour.name,
      nameAr: '',
      category: '',
      kind: 'mock_tour',
      aliases: [
        `${tour.name} Alexandria Egypt`,
        ...linkedPlaces.map((place) => place.name),
      ],
      linkedPlaces,
      model: tour,
    };
  });
const targetIdentities = new Set();
for (const target of [
  ...placeTargets,
  ...seedPlaceTargets,
  ...hotelTargets,
  ...tourTargets,
  ...mockTourTargets,
]) {
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

function hasForeignLocationEvidence(text) {
  const normalized = normalize(text);
  return /\bvirginia\b|\bcanada\b|\busa\b|\bunited states\b|\bontario\b|\blos angeles\b|\bcalifornia\b|\bbarcelona\b|\bspain\b|\btunisia\b|\btunis\b/.test(normalized);
}

function cityEvidence(text) {
  if (hasForeignLocationEvidence(text)) return false;
  const normalized = normalize(text);
  return /\balexandria\b|\begypt\b/.test(normalized) ||
    /الإسكندرية|اسكندرية|مصر/.test(text);
}

function scoreMatch(target, identityText, evidenceText = identityText) {
  const normalizedText = normalize(identityText);
  const normalizedEvidence = normalize(evidenceText);
  let best = 0;
  for (const variant of identifyingVariants(target)) {
    const tokens = variant.split(' ');
    const nameWords = tokens.filter((token) => requiredPlaceTypeWords.has(token));
    const missingType = nameWords.some((token) =>
      !normalizedEvidence.includes(token),
    );
    const distinctiveTokens = tokens.filter((token) => !requiredPlaceTypeWords.has(token));
    const requiredTokens = distinctiveTokens.length > 0 ? distinctiveTokens : tokens;
    const matching = requiredTokens.filter((token) => normalizedText.includes(token));
    const score = matching.length / requiredTokens.length;
    const minimumMatch = requiredTokens.length;
    if (matching.length >= minimumMatch && !missingType) {
      best = Math.max(best, score);
    }
  }
  return best;
}

function candidateHasKnownMismatch(target, identityText, evidenceText = identityText) {
  const normalized = normalize(`${identityText} ${evidenceText}`);
  if (hasForeignLocationEvidence(normalized)) return true;
  if (target.id === 'hotel-plaza-alex' &&
      /\bfour seasons\b|\bsan stefano\b|\bsanstefano\b/.test(normalized)) {
    return true;
  }
  if (target.id === 'hotel-king-mariout' &&
      /\bcecil\b|\ble metropole\b/.test(normalized)) {
    return true;
  }
  if (target.id === 'hotel-borg-al-arab' &&
      /\bsea sandwich\b/.test(normalized)) {
    return true;
  }
  if (target.kind === 'tour' && target.id === 't3' &&
      /\bzoo\b|\bmonkey\b|\bmacaque\b|\banimal\b|\bwildlife\b/.test(normalized)) {
    return true;
  }
  return false;
}

function candidateIdentityMatches(target, identityText, evidenceText) {
  const normalizedIdentity = normalize(identityText);
  if (candidateHasKnownMismatch(target, identityText, evidenceText)) {
    return false;
  }
  if (target.id === '29' &&
      /\bcherif pacha street\b.*\bexchange\b/.test(normalizedIdentity)) {
    return 0.75;
  }
  if (target.id === 'hotel-tolip-alex' &&
      /\bsunset at alex\b/.test(normalizedIdentity) &&
      /\btolip hotel on stanley beach\b/.test(normalize(evidenceText))) {
    return 0.75;
  }
  if (target.id === 'hotel-plaza-alex' &&
      /\bfour seasons\b|\bsan stefano\b|\bsanstefano\b/.test(normalizedIdentity)) {
    return false;
  }
  if (target.id === 'hotel-downtown' &&
      !/\bdowntown hotel\b|\bhotel downtown\b/.test(normalize(evidenceText))) {
    return false;
  }
  if (target.id === 'hotel-san-stefano' &&
      !/\bsan stefano\b|\bsanstefano\b|\bgrand plaza\b/.test(normalizedIdentity)) {
    return false;
  }
  if (target.id === 'hotel-borg-al-arab' &&
      /\bsea sandwich\b/.test(normalizedIdentity)) {
    return false;
  }
  return scoreMatch(target, identityText, evidenceText);
}

function cleanMetadata(imageInfo) {
  const metadata = imageInfo.extmetadata ?? {};
  const value = (key) => decodeHtml(metadata[key]?.value ?? '');
  const coordinate = (key) => {
    const raw = value(key).trim();
    if (!raw) return null;
    const parsed = Number(raw);
    return Number.isFinite(parsed) ? parsed : null;
  };
  return {
    objectName: value('ObjectName'),
    description: value('ImageDescription'),
    categories: value('Categories'),
    latitude: coordinate('GPSLatitude'),
    longitude: coordinate('GPSLongitude'),
    artist: value('Artist') || value('Credit') || 'Unknown',
    license: value('LicenseShortName') || value('UsageTerms') || 'Unknown',
    licenseUrl: value('LicenseUrl'),
    attribution: value('Attribution'),
  };
}

function distanceMeters(lat1, lng1, lat2, lng2) {
  const radians = (degrees) => degrees * Math.PI / 180;
  const deltaLat = radians(lat2 - lat1);
  const deltaLng = radians(lng2 - lng1);
  const a = Math.sin(deltaLat / 2) ** 2 +
    Math.cos(radians(lat1)) * Math.cos(radians(lat2)) *
    Math.sin(deltaLng / 2) ** 2;
  return 6371000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function hasRedistributableLicense(license) {
  return /^(?:public domain(?:\b|$)|pd(?:[-\s]|$)|cc0(?:\b|$)|cc by(?:-sa)?(?:\s|$))/i
    .test(license.trim());
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
      if (!hasRedistributableLicense(metadata.license)) return null;
      const verificationText = [
        page.title,
        metadata.objectName,
        metadata.description,
        metadata.categories,
      ].join(' ');
      if (candidateHasKnownMismatch(
        target,
        [page.title, metadata.objectName].join(' '),
        verificationText,
      )) {
        return null;
      }
      if (target.id === 'hotel-san-stefano' &&
          /\bfour seasons\b/i.test(verificationText)) {
        return null;
      }
      const matchScore = candidateIdentityMatches(
        target,
        [page.title, metadata.objectName].join(' '),
        verificationText,
      );
      const sceneTerms = EXPLICIT_GEO_EVIDENCE.get(String(target.id)) ?? [];
      const sceneMatch = sceneTerms.some((term) =>
        normalize(verificationText).includes(normalize(term)),
      );
      const targetLat = Number(target.row?.lat ?? target.lat);
      const targetLng = Number(target.row?.lng ?? target.lng);
      const nearbyHotelMatch = target.kind === 'hotel' &&
        Number.isFinite(targetLat) && Number.isFinite(targetLng) &&
        Number.isFinite(metadata.latitude) &&
        Number.isFinite(metadata.longitude) &&
        distanceMeters(targetLat, targetLng, metadata.latitude, metadata.longitude) <= 10000 &&
        /\bhotel\b/.test(normalize(verificationText));
      if ((!matchScore && !(sceneMatch && (target.kind !== 'hotel' || nearbyHotelMatch))) ||
          !cityEvidence(verificationText)) {
        return null;
      }
      const verifiedScore = matchScore || 0.4;
      return {
        sourceFileTitle: page.title,
        sourceUrl: info.thumburl ?? info.url,
        sourcePageUrl: info.descriptionurl,
        width: info.width ?? 0,
        height: info.height ?? 0,
        mime: info.mime,
        metadata,
        matchScore: verifiedScore,
        sourceKey: `commons:${page.pageid}`,
      };
    })
    .filter(Boolean)
    .sort((a, b) => b.matchScore - a.matchScore || b.width - a.width);
}

const run3FileTitles = new Map([
  ['49', 'File:Nabi Daniel Mosque Tomb II.jpg'],
  ['52', 'File:Alexandria - Antoniades Garden - btv1b10114345n (1 of 2).jpg'],
  ['47', 'File:Sayed Darwish Theatre in Alexandria,.JPG'],
  ['7', "File:Alexandria, Pompey's pillar, 19th century pictures, 1870, photo 1 of 2 - Archivio fotografico Museo Egizio, Turin Album1 050.jpg"],
  ['8', 'File:Stanley Bridge in the city of Alexandria , Egypt . 6.JPG'],
  ['9', 'File:المسرح الروماني. منطقة كوم الدكة. الإسكندرية.jpg'],
  ['a118abcb-13b2-4db3-89b6-dfe2fb2abe2f', 'File:Bibliotheca Alexandrina – Manuscript Museum 28.jpg'],
  ['ec216324-1277-4649-a631-91be397eeeac', 'File:Greek Club, Shatby, Alexandria 02.jpg'],
  ['2', 'File:مكتبة الإسكندرية الجديدة.jpg'],
  ['3', 'File:حدائق قصر المنتزه الاسكندرية.jpg'],
  ['34', 'File:Qaed Ibrahim Mosque in Alexandria in 2021 from north-east.jpg'],
  ['42', "File:St. Catherine's Cathedral, Alexandria 18 relics of Saint Sabina.jpg"],
  ['43', 'File:من مقتنيات المتحف اليوناني الروماني بالإسكندرية.jpg'],
  ['10', 'File:من داخل مسجد المرسي أبو العباس.jpg'],
  ['40', "en Wikipedia: Saint Mark's Coptic Orthodox Cathedral"],
  ['17', 'File:AlexAnfushiTombs.jpg'],
  ['50', 'File:75 Alexandria. - Attarine Mosque. - btv1b10114850q (1 of 2).jpg'],
  ['51', 'File:Macaca radiata in Alexandria Zoo, 2015.jpg'],
  ['16', 'File:Shallalat gardens 2.JPG'],
  ['18', 'File:Eliyahu Hanavi Synagogue (Alexandria) 02.jpg'],
  ['hotel-four-seasons', 'File:Alexandria sea and the four seasons hotel.jpg'],
  ['hotel-sofitel-alex', 'File:Sofitel Alexandria.JPG'],
  ['hotel-steigenberger-cerine', 'File:Cecil Hotel - Alexandria 02.jpg'],
  ['hotel-tolip-alex', 'File:Sunset at Alex.jpg'],
  ['hotel-paradise', 'File:Windsor Palace Hotel.jpg'],
  ['hotel-cherry', 'File:Cherry Maryski Hotel lobby.jpg'],
  ['hotel-san-stefano', 'File:Sanstefano-1.jpg'],
  ['hotel-downtown', 'File:Hotels-Downtown Alexandria.jpg'],
  ['hotel-borg-al-arab', 'File:Alexandria International Airport (Egypt).jpg'],
]);

async function commonsFileCandidate(target, fileTitle) {
  const url = new URL('https://commons.wikimedia.org/w/api.php');
  url.search = new URLSearchParams({
    action: 'query',
    titles: fileTitle,
    prop: 'imageinfo',
    iiprop: 'url|size|mime|extmetadata',
    iiurlwidth: '1600',
    format: 'json',
  });
  const json = await requestJson(url);
  const page = Object.values(json.query?.pages ?? {})[0];
  const info = page?.imageinfo?.[0];
  if (!page || !info || !/^image\/jpeg$/i.test(info.mime ?? '')) return null;
  const metadata = cleanMetadata(info);
  if (!hasRedistributableLicense(metadata.license)) return null;
  const verificationText = [
    page.title,
    metadata.objectName,
    metadata.description,
    metadata.categories,
  ].join(' ');
  const matchScore = candidateIdentityMatches(
    target,
    [page.title, metadata.objectName].join(' '),
    verificationText,
  );
  const sceneTerms = EXPLICIT_GEO_EVIDENCE.get(String(target.id)) ?? [];
  const sceneMatch = sceneTerms.some((term) =>
    normalize(verificationText).includes(normalize(term)),
  );
  if ((!matchScore && !sceneMatch) || !cityEvidence(verificationText)) return null;
  return {
    sourceFileTitle: page.title,
    sourceUrl: info.thumburl ?? info.url,
    sourcePageUrl: info.descriptionurl,
    width: info.width ?? 0,
    height: info.height ?? 0,
    mime: info.mime,
    metadata,
    matchScore: matchScore || 0.4,
    sourceKey: `commons:${page.pageid}`,
  };
}

async function commonsGeoCandidates(target) {
  const linkedPlace = target.linkedPlaces?.find((place) =>
    Number.isFinite(Number(place.lat)) &&
    Number.isFinite(Number(place.lng)),
  );
  const lat = Number(target.row?.lat ?? target.lat ?? linkedPlace?.lat);
  const lng = Number(target.row?.lng ?? target.lng ?? linkedPlace?.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return [];
  const maxDistance = target.kind === 'hotel' ? 10000 : 500;
  const url = new URL('https://commons.wikimedia.org/w/api.php');
  url.search = new URLSearchParams({
    action: 'query',
    generator: 'geosearch',
    ggscoord: `${lat}|${lng}`,
    ggsradius: String(maxDistance),
    ggslimit: '50',
    ggsnamespace: '6',
    prop: 'imageinfo|coordinates',
    iiprop: 'url|size|mime|extmetadata',
    iiurlwidth: '1600',
    coprop: 'type|name',
    format: 'json',
  });
  const json = await requestJson(url);
  return Object.values(json.query?.pages ?? {})
    .map((page) => {
      const info = page.imageinfo?.[0];
      const coordinates = page.coordinates?.[0];
      const distance = coordinates
        ? distanceMeters(lat, lng, coordinates.lat, coordinates.lon)
        : null;
      if (!info || !/^image\/jpeg$/i.test(info.mime ?? '') ||
          !Number.isFinite(distance) || distance > maxDistance) {
        return null;
      }
      const metadata = cleanMetadata(info);
      if (!hasRedistributableLicense(metadata.license)) return null;
      const verificationText = [
        page.title,
        metadata.objectName,
        metadata.description,
        metadata.categories,
      ].join(' ');
      if (candidateHasKnownMismatch(
        target,
        [page.title, metadata.objectName].join(' '),
        verificationText,
      )) {
        return null;
      }
      const identityScore = candidateIdentityMatches(
        target,
        [page.title, metadata.objectName].join(' '),
        verificationText,
      );
      const sceneEvidence = EXPLICIT_GEO_EVIDENCE.get(String(target.id));
      const normalizedEvidence = normalize(verificationText);
      const locallyVerified = distance <= 500 &&
        sceneEvidence?.some((term) =>
          normalizedEvidence.includes(normalize(term)),
        );
      const nearbyHotelVerified = target.kind === 'hotel' &&
        distance <= maxDistance && /\bhotel\b/.test(normalizedEvidence);
      if (hasForeignLocationEvidence(verificationText)) return null;
      if ((!identityScore || !cityEvidence(verificationText)) &&
          !locallyVerified && !nearbyHotelVerified) {
        return null;
      }
      const matchScore = identityScore ||
        (nearbyHotelVerified ? 0.5 : locallyVerified ? 0.5 : 0);
      return {
        sourceFileTitle: page.title,
        sourceUrl: info.thumburl ?? info.url,
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
      const matchScore = candidateIdentityMatches(
        target,
        summary.title,
        metadataText,
      );
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
          const pageTitle =
            body.match(/<title[^>]*>([\s\S]*?)<\/title>/i)?.[1] ?? '';
          const pageDescription = body.match(
            /<meta[^>]+(?:property|name)=["'](?:og:title|og:description|description)["'][^>]+content=["']([^"']*)["']/i,
          )?.[1] ?? '';
          const pageIdentity = `${finalUrl} ${pageTitle}`;
          const pageEvidence = `${pageIdentity} ${pageDescription} ${body.slice(0, 5000)}`;
          const matchScore =
            candidateIdentityMatches(target, pageIdentity, pageEvidence) *
            0.7;
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
  const response = await fetchWithRetry(
    candidate.sourceUrl,
    {
      headers: { 'User-Agent': userAgent },
      redirect: 'follow',
    },
    `Download ${candidate.sourceFileTitle}`,
  );
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
const usedImageHashes = new Map();
const resolved = new Map();
const failures = [];
const discoveryTargets = [
  ...placeTargets,
  ...seedPlaceTargets,
  ...hotelTargets,
  ...tourTargets,
  ...mockTourTargets,
];
const finalUrls = new Map();
let adminHeaders;

function imageSha256(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

async function downloadUniqueCandidate(candidate) {
  if (!hasRedistributableLicense(candidate.metadata?.license ?? '')) {
    throw new Error(
      `Source license does not permit redistribution: ${candidate.sourceFileTitle}`,
    );
  }
  const bytes = await downloadCandidate(candidate);
  const hash = imageSha256(bytes);
  if (usedImageHashes.has(hash)) {
    throw new Error(`Duplicate image binary already assigned to ${usedImageHashes.get(hash)}.`);
  }
  return bytes;
}

if (!dryRun) {
  let serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!serviceRoleKey) {
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
  }
  if (!serviceRoleKey) {
    throw new Error('The Supabase service-role key was not available.');
  }
  adminHeaders = {
    apikey: serviceRoleKey,
    Authorization: 'Bearer ' + serviceRoleKey,
  };
}

async function fetchWithRetry(url, options, label, attempts = 4) {
  let lastError;
  for (let attempt = 1; attempt <= attempts; attempt++) {
    try {
      const response = await fetch(url, {
        ...options,
        signal: AbortSignal.timeout(15000),
      });
      if (response.ok) return response;
      lastError = new Error(`${label}: HTTP ${response.status}`);
    } catch (error) {
      lastError = error;
    }
    if (attempt < attempts) {
      await new Promise((resolve) => setTimeout(resolve, attempt * 1000));
    }
  }
  throw new Error(`${label} failed after ${attempts} attempts: ${String(lastError)}`);
}

function publicStorageUrl(objectPath) {
  return `${supabaseUrl}/storage/v1/object/public/place-images/${objectPath
    .split('/')
    .map(encodeURIComponent)
    .join('/')}`;
}

async function uploadAndSaveTarget(target, item) {
  const objectPath = target.kind === 'hotel'
    ? `hotels/${target.id}.jpg`
    : target.kind === 'tour' || target.kind === 'mock_tour'
      ? `tours/${target.id}.jpg`
      : `${target.id}.jpg`;
  const storageUrl = `${supabaseUrl}/storage/v1/object/place-images/${objectPath
    .split('/')
    .map(encodeURIComponent)
    .join('/')}`;
  const imageUrl = publicStorageUrl(objectPath);
  try {
    const upload = await fetchWithRetry(
      storageUrl,
      {
        method: 'POST',
        headers: {
          ...adminHeaders,
          'Content-Type': 'image/jpeg',
          'x-upsert': 'true',
        },
        body: item.imageBytes,
      },
      `Upload ${objectPath}`,
    );
    await upload.arrayBuffer();
  } catch (uploadError) {
    let head;
    try {
      head = await fetch(imageUrl, {
        method: 'HEAD',
        signal: AbortSignal.timeout(15000),
      });
    } catch (probeError) {
      throw new Error(
        `Upload failed and stored object could not be checked: ` +
        `${String(uploadError)}; ${String(probeError)}`,
      );
    }
    if (!head.ok || head.headers.get('content-type') !== 'image/jpeg') {
      throw new Error(
        `Upload failed and ${objectPath} was not confirmed in Storage: ` +
        `${String(uploadError)}.`,
      );
    }
    const stored = await fetchWithRetry(
      imageUrl,
      {},
      `Verify uploaded ${objectPath}`,
    );
    const storedBytes = Buffer.from(await stored.arrayBuffer());
    if (imageSha256(storedBytes) !== imageSha256(item.imageBytes)) {
      throw new Error(
        `Uploaded ${objectPath} does not match the source image binary.`,
      );
    }
  }

  if (target.kind === 'place') {
    const update = await fetchWithRetry(
      `${supabaseUrl}/rest/v1/places?id=eq.${encodeURIComponent(target.id)}`,
      {
        method: 'PATCH',
        headers: {
          ...adminHeaders,
          'Content-Type': 'application/json',
          Prefer: 'return=representation',
        },
        body: JSON.stringify({ image_url: imageUrl, image_urls: [imageUrl] }),
      },
      `Update place ${target.id}`,
    );
    const rows = await update.json();
    if (rows.length !== 1 || rows[0].image_url !== imageUrl) {
      throw new Error(`Place ${target.id} update was not confirmed.`);
    }
    target.row.image_url = imageUrl;
    target.row.image_urls = [imageUrl];
    await updateMockPlaceImages(target, imageUrl);
  } else if (target.kind === 'tour') {
    const update = await fetchWithRetry(
      `${supabaseUrl}/rest/v1/tours?id=eq.${encodeURIComponent(target.id)}`,
      {
        method: 'PATCH',
        headers: {
          ...adminHeaders,
          'Content-Type': 'application/json',
          Prefer: 'return=representation',
        },
        body: JSON.stringify({ image_url: imageUrl }),
      },
      `Update tour ${target.id}`,
    );
    const rows = await update.json();
    if (rows.length !== 1 || rows[0].image_url !== imageUrl) {
      throw new Error(`Tour ${target.id} update was not confirmed.`);
    }
  } else if (target.kind === 'hotel') {
    await updateHotelImage(target.id, imageUrl);
  } else if (target.kind === 'mock_place') {
    await updateMockPlaceImages(target, imageUrl);
  } else if (target.kind === 'mock_tour') {
    await updateMockTourImage(target, imageUrl);
  }
  finalUrls.set(`${target.kind}:${target.id}`, imageUrl);
  console.log(`SAVED ${target.kind}:${target.id} ${imageUrl}`);
}

async function updateMockTourImage(target, imageUrl) {
  let source = await readFile(mockSourcePath, 'utf8');
  const currentTours = parseConstructors(source, 'ItineraryModel');
  const matching = currentTours.filter((tour) =>
    normalize(tour.name) === normalize(target.name),
  );
  for (const tour of matching.sort((a, b) => b.start - a.start)) {
    const image = parseImageUrl(tour.text);
    if (!image) continue;
    const start = tour.start + image.start;
    const end = tour.start + image.end;
    source = source.slice(0, start) + JSON.stringify(imageUrl) +
      source.slice(end);
  }
  if (matching.length) await writeFile(mockSourcePath, source, 'utf8');
}

async function updateMockPlaceImages(target, imageUrl) {
  let source = await readFile(mockSourcePath, 'utf8');
  const currentModels = parseConstructors(source, 'PlaceModel');
  const matching = currentModels.filter((model) =>
    normalize(model.name) === normalize(target.name),
  );
  for (const model of matching.sort((a, b) => b.start - a.start)) {
    const image = parseImageUrl(model.text);
    const edits = [];
    if (image) {
      edits.push({
        start: model.start + image.start,
        end: model.start + image.end,
        value: JSON.stringify(imageUrl),
      });
    }
    const imageUrls = /\bimageUrls:\s*\[[\s\S]*?\]/.exec(model.text);
    if (imageUrls) {
      const open = imageUrls[0].indexOf('[');
      edits.push({
        start: model.start + imageUrls.index + open,
        end: model.start + imageUrls.index + imageUrls[0].length,
        value: imageUrl ? `[${JSON.stringify(imageUrl)}]` : '[]',
      });
    }
    for (const edit of edits.sort((a, b) => b.start - a.start)) {
      source = source.slice(0, edit.start) + edit.value + source.slice(edit.end);
    }
  }
  if (matching.length) await writeFile(mockSourcePath, source, 'utf8');
}

async function updateHotelImage(hotelId, imageUrl) {
  const source = await readFile(mapSeedPath, 'utf8');
  const entryPattern = new RegExp(
    `('${hotelId}'\\s*:\\s*)(?:'[^']*'|"[^"]*")`,
  );
  if (!entryPattern.test(source)) {
    throw new Error(`Hotel image entry not found for ${hotelId}.`);
  }
  await writeFile(
    mapSeedPath,
    source.replace(entryPattern, `$1${JSON.stringify(imageUrl)}`),
    'utf8',
  );
}

async function clearUnverifiedImage(target, expectedUrl, objectPath, existing) {
  const storageImageIsInvalid = Boolean(
    existing?.ok || existing?.status === 400 || existing?.status === 404,
  );
  if (target.kind === 'place' &&
      (target.row.image_url !== expectedUrl || storageImageIsInvalid)) {
    const update = await fetchWithRetry(
      `${supabaseUrl}/rest/v1/places?id=eq.${encodeURIComponent(target.id)}`,
      {
        method: 'PATCH',
        headers: {
          ...adminHeaders,
          'Content-Type': 'application/json',
          Prefer: 'return=representation',
        },
        body: JSON.stringify({ image_url: '', image_urls: [] }),
      },
      `Clear unverifiable place image ${target.id}`,
    );
    const rows = await update.json();
    if (rows.length !== 1 || rows[0].image_url !== '') {
      throw new Error(`Place ${target.id} image clear was not confirmed.`);
    }
    target.row.image_url = '';
    target.row.image_urls = [];
  } else if (target.kind === 'tour' &&
      (target.row.image_url !== expectedUrl || storageImageIsInvalid)) {
    const update = await fetchWithRetry(
      `${supabaseUrl}/rest/v1/tours?id=eq.${encodeURIComponent(target.id)}`,
      {
        method: 'PATCH',
        headers: {
          ...adminHeaders,
          'Content-Type': 'application/json',
          Prefer: 'return=representation',
        },
        body: JSON.stringify({ image_url: '' }),
      },
      `Clear unverifiable tour image ${target.id}`,
    );
    const rows = await update.json();
    if (rows.length !== 1 || rows[0].image_url !== '') {
      throw new Error(`Tour ${target.id} image clear was not confirmed.`);
    }
    target.row.image_url = '';
  }

  if (target.kind === 'place' || target.kind === 'mock_place') {
    await updateMockPlaceImages(target, '');
  } else if (target.kind === 'tour' || target.kind === 'mock_tour') {
    await updateMockTourImage(target, '');
  } else if (target.kind === 'hotel') {
    await updateHotelImage(target.id, '');
  }

  if (existing?.ok) {
    const removal = await fetchWithRetry(
      `${supabaseUrl}/storage/v1/object/place-images`,
      {
        method: 'DELETE',
        headers: {
          ...adminHeaders,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ prefixes: [objectPath] }),
      },
      `Remove unverifiable image ${objectPath}`,
    );
    if (!removal.ok) {
      throw new Error(
        `Could not remove unverifiable image ${objectPath}: HTTP ${removal.status}.`,
      );
    }
  }
}

for (let index = 0; index < discoveryTargets.length; index++) {
  const target = discoveryTargets[index];
  const identity = `${target.kind}:${target.id}`;
  const objectPath = target.kind === 'hotel'
    ? `hotels/${target.id}.jpg`
    : target.kind === 'tour'
      ? `tours/${target.id}.jpg`
      : `${target.id}.jpg`;
  const expectedUrl = publicStorageUrl(objectPath);
  const discoveryErrors = [];
  let existing;
  let reusedExisting = false;
  try {
    if (!dryRun) {
      try {
        existing = await fetch(expectedUrl, {
          method: 'HEAD',
          signal: AbortSignal.timeout(15000),
        });
      } catch (error) {
        discoveryErrors.push(`Storage resume check: ${String(error)}`);
      }
      if (existing?.ok) {
        const contentType = existing.headers.get('content-type') ?? '';
        const contentLength = Number(existing.headers.get('content-length') ?? 0);
        if (contentType === 'image/jpeg' && contentLength >= 5000) {
          const image = await fetchWithRetry(
            expectedUrl,
            {},
            `Read existing ${objectPath}`,
          );
          const bytes = Buffer.from(await image.arrayBuffer());
          if (bytes.length >= 5000 && bytes.length <= 20 * 1024 * 1024 &&
              bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
            const hash = imageSha256(bytes);
            const prior = priorAttributions.get(identity);
            const priorTitle = prior?.source_file_title ?? '';
            const priorLicense = prior?.license ?? '';
            const priorSourceMatches = Boolean(
              priorTitle &&
              priorTitle !== 'Previously uploaded verified image' &&
              hasRedistributableLicense(priorLicense) &&
              !(target.id === 'hotel-san-stefano' &&
                /\bfour seasons\b/i.test(priorTitle)) &&
              candidateIdentityMatches(target, priorTitle, priorTitle),
            );
            if (!usedImageHashes.has(hash) && priorSourceMatches) {
              if (target.kind === 'place' &&
                  (target.row.image_url !== expectedUrl ||
                   JSON.stringify(target.row.image_urls ?? []) !==
                     JSON.stringify([expectedUrl]))) {
                const update = await fetchWithRetry(
                  `${supabaseUrl}/rest/v1/places?id=eq.${encodeURIComponent(target.id)}`,
                  {
                    method: 'PATCH',
                    headers: {
                      ...adminHeaders,
                      'Content-Type': 'application/json',
                      Prefer: 'return=representation',
                    },
                    body: JSON.stringify({
                      image_url: expectedUrl,
                      image_urls: [expectedUrl],
                    }),
                  },
                  `Resume place ${target.id}`,
                );
                const rows = await update.json();
                if (rows.length !== 1 || rows[0].image_url !== expectedUrl) {
                  throw new Error(`Place ${target.id} resume update was not confirmed.`);
                }
                target.row.image_url = expectedUrl;
                target.row.image_urls = [expectedUrl];
              } else if (target.kind === 'tour' &&
                  target.row.image_url !== expectedUrl) {
                const update = await fetchWithRetry(
                  `${supabaseUrl}/rest/v1/tours?id=eq.${encodeURIComponent(target.id)}`,
                  {
                    method: 'PATCH',
                    headers: {
                      ...adminHeaders,
                      'Content-Type': 'application/json',
                      Prefer: 'return=representation',
                    },
                    body: JSON.stringify({ image_url: expectedUrl }),
                  },
                  `Resume tour ${target.id}`,
                );
                const rows = await update.json();
                if (rows.length !== 1 || rows[0].image_url !== expectedUrl) {
                  throw new Error(`Tour ${target.id} resume update was not confirmed.`);
                }
              }
              if (target.kind === 'place' || target.kind === 'mock_place') {
                await updateMockPlaceImages(target, expectedUrl);
              } else if (target.kind === 'hotel' &&
                  !(await readFile(mapSeedPath, 'utf8')).includes(expectedUrl)) {
                await updateHotelImage(target.id, expectedUrl);
              } else if (target.kind === 'tour' || target.kind === 'mock_tour') {
                await updateMockTourImage(target, expectedUrl);
              }
              usedImageHashes.set(hash, identity);
              resolved.set(identity, {
                ...target,
                sourceFileTitle: priorTitle,
                sourceUrl: expectedUrl,
                sourcePageUrl: prior?.source_page_url || expectedUrl,
                imageBytes: bytes,
                width: 0,
                height: 0,
                metadata: {
                  objectName: target.name,
                  description: 'Previously uploaded image in the project Storage bucket.',
                  categories: '',
                  artist: prior?.artist || '',
                  license: prior?.license || '',
                  licenseUrl: '',
                  attribution: '',
                },
                storagePath: objectPath,
              });
              finalUrls.set(identity, expectedUrl);
              usedSources.add(expectedUrl);
              reusedExisting = true;
              console.log(`RESUME ${index + 1}/${discoveryTargets.length} ${identity}`);
              continue;
            }
            console.log(
              `REPLACING EXISTING ${identity}; ` +
              `${usedImageHashes.has(hash) ? 'duplicate binary' : 'source verification failed'}.`,
            );
          }
        }
      } else if (existing && existing.status !== 400 && existing.status !== 404) {
        discoveryErrors.push(
          `Storage resume check returned HTTP ${existing.status}.`,
        );
      }
      if (!reusedExisting) {
        await clearUnverifiedImage(target, expectedUrl, objectPath, existing);
      }
    }
  const terms = target.aliases?.length
    ? target.aliases
    : [`${target.name} Alexandria Egypt`, `${target.name} ${target.nameAr}`];
  let candidates = [];
  const run3Title = run3FileTitles.get(String(target.id));
  if (run3Title?.startsWith('File:')) {
    try {
      const candidate = await commonsFileCandidate(target, run3Title);
      if (candidate) candidates.push(candidate);
      else discoveryErrors.push(`Run 3 source did not pass exact-title verification: ${run3Title}`);
    } catch (error) {
      discoveryErrors.push(`Run 3 source lookup: ${String(error)}`);
    }
  }
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
      const candidateBytes = await downloadUniqueCandidate(candidate);
      selected = candidate;
      bytes = candidateBytes;
      break;
    } catch {
      continue;
    }
  }
  if (!selected) {
    try {
      const geo = await commonsGeoCandidates(target);
      for (const candidate of geo) {
        if (usedSources.has(candidate.sourceKey)) continue;
        try {
          const candidateBytes = await downloadUniqueCandidate(candidate);
          selected = candidate;
          bytes = candidateBytes;
          break;
        } catch {
          continue;
        }
      }
    } catch (error) {
      discoveryErrors.push(`Commons nearby geotagged files: ${String(error)}`);
    }
  }
  if (!selected) {
    const sceneQueries =
      EXPLICIT_COMMONS_SCENE_QUERIES.get(String(target.id)) ?? [];
    for (const term of sceneQueries) {
      try {
        const sceneCandidates = await commonsCandidates(target, term);
        for (const candidate of sceneCandidates) {
          if (usedSources.has(candidate.sourceKey)) continue;
          try {
            const candidateBytes = await downloadUniqueCandidate(candidate);
            selected = candidate;
            bytes = candidateBytes;
            break;
          } catch {
            continue;
          }
        }
      } catch (error) {
        discoveryErrors.push(`Commons scene search (${term}): ${String(error)}`);
      }
      if (selected) break;
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
  const hash = imageSha256(bytes);
  if (usedImageHashes.has(hash)) {
    throw new Error(
      `Duplicate image binary already assigned to ${usedImageHashes.get(hash)}.`,
    );
  }
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
    storagePath: target.kind === 'hotel'
      ? `hotels/${target.id}.jpg`
      : target.kind === 'tour' || target.kind === 'mock_tour'
        ? `tours/${target.id}.jpg`
        : `${target.id}.jpg`,
  };
  if (!dryRun) await uploadAndSaveTarget(target, item);
  usedImageHashes.set(hash, identity);
  usedSources.add(selected.sourceKey);
  resolved.set(identity, item);
  console.log(
    `VERIFIED ${index + 1}/${discoveryTargets.length} ${target.kind} ${target.id}: ${item.sourceFileTitle}`,
  );
  } catch (error) {
    failures.push({
      id: target.id,
      name: target.name,
      kind: target.kind,
      error: String(error),
    });
    console.error(
      `FAILED ${index + 1}/${discoveryTargets.length} ${identity}: ${String(error)}`,
    );
  }
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
  await mkdir(path.dirname(reportPath), { recursive: true });
  await writeFile(reportPath, lines.join('\n') + '\n', 'utf8');
}

if (failures.length) {
  await writeCsvReport();
  console.error(
    `${failures.length} image targets failed strict authenticity verification. ` +
    `The ${resolved.size} successful targets were saved incrementally.`,
  );
  for (const failure of failures) {
    console.error(`${failure.kind}:${failure.id} ${failure.name}: ${failure.error}`);
  }
  process.exitCode = 1;
}
if (dryRun) {
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
  async function uploadObject(objectPath, item) {
    const url = `${supabaseUrl}/storage/v1/object/place-images/${objectPath
      .split('/')
      .map(encodeURIComponent)
      .join('/')}`;
    const response = await fetchWithRetry(
      url,
      {
        method: 'POST',
        headers: {
          ...adminHeaders,
          'Content-Type': 'image/jpeg',
          'x-upsert': 'true',
        },
        body: item.imageBytes,
      },
      `Upload ${objectPath}`,
    );
    await response.arrayBuffer();
    return publicStorageUrl(objectPath);
  }

  for (const target of discoveryTargets) {
    const identity = `${target.kind}:${target.id}`;
    const item = resolved.get(identity);
    if (!item) continue; // skip UNVERIFIED targets so we can still upload the rest
    if (finalUrls.has(identity)) continue;
    const objectPath = target.kind === 'hotel'
      ? `hotels/${item.storagePath}`
      : item.storagePath;
    finalUrls.set(identity, await uploadObject(objectPath, item));
  }
  for (const place of places) {
    const imageUrl = finalUrls.get(`place:${place.id}`);
    if (!imageUrl ||
        (place.image_url === imageUrl &&
         JSON.stringify(place.image_urls ?? []) === JSON.stringify([imageUrl]))) {
      continue;
    }
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
    if (!finalUrls.has(`tour:${tour.id}`) &&
        !failures.some((failure) =>
          failure.kind === 'tour' && failure.id === String(tour.id),
        )) {
      failures.push({
        id: String(tour.id),
        name: tour.title,
        kind: 'tour',
        error: 'No distinct, verified tour image was uploaded.',
      });
    }
  }

  let updatedMockSource = await readFile(mockSourcePath, 'utf8');
  const localTours = parseConstructors(updatedMockSource, 'ItineraryModel');
  const tourImageEdits = [];
  for (const tour of localTours) {
    const databaseTour = tours.find((row) =>
      String(row.id) === tour.id ||
      normalize(row.title) === normalize(tour.name),
    );
    const imageUrl = databaseTour
      ? finalUrls.get(`tour:${databaseTour.id}`)
      : finalUrls.get(`mock_tour:${tour.id}`);
    if (!imageUrl) continue;
    const image = parseImageUrl(tour.text);
    if (!image) continue;
    tourImageEdits.push({
      start: tour.start + image.start,
      end: tour.start + image.end,
      value: JSON.stringify(imageUrl),
    });
  }
  for (const edit of tourImageEdits.sort((a, b) => b.start - a.start)) {
    updatedMockSource = updatedMockSource.slice(0, edit.start) +
      edit.value +
      updatedMockSource.slice(edit.end);
  }
  if (tourImageEdits.length) {
    await writeFile(mockSourcePath, updatedMockSource, 'utf8');
  }

  const [placesResponse, toursResponse] = await Promise.all([
    fetch(
      `${supabaseUrl}/rest/v1/places?select=id,name_en,image_url,image_urls&limit=1000`,
      { headers: adminHeaders, signal: AbortSignal.timeout(30000) },
    ),
    fetch(
      `${supabaseUrl}/rest/v1/tours?select=id,title,image_url&limit=1000`,
      { headers: adminHeaders, signal: AbortSignal.timeout(30000) },
    ),
  ]);
  if (!placesResponse.ok || !toursResponse.ok) {
    throw new Error(
      `Could not verify final rows: places=${placesResponse.status}, tours=${toursResponse.status}.`,
    );
  }
  const [finalPlaces, finalTours] = await Promise.all([
    placesResponse.json(),
    toursResponse.json(),
  ]);
  const storagePrefix =
    `${supabaseUrl}/storage/v1/object/public/place-images/`;
  const rowsMissingStorageImages = [...finalPlaces, ...finalTours]
    .filter((row) =>
      typeof row.image_url !== 'string' ||
      !row.image_url.startsWith(storagePrefix),
    );
  const duplicateUrls = new Map();
  for (const row of [...finalPlaces, ...finalTours]) {
    const ids = duplicateUrls.get(row.image_url) ?? [];
    ids.push(String(row.id));
    duplicateUrls.set(row.image_url, ids);
  }
  const duplicates = [...duplicateUrls]
    .filter(([, ids]) => ids.length > 1)
    .map(([url, ids]) => ({ url, ids }));
  const assignedUrls = [...finalUrls.values()];
  const duplicateAssignedUrls =
    assignedUrls.length !== new Set(assignedUrls).size;
  const expectedTargets = discoveryTargets.length;
  const gateFailed =
    finalPlaces.length !== 61 ||
    finalTours.length !== 12 ||
    rowsMissingStorageImages.length > 0 ||
    duplicates.length > 0 ||
    duplicateAssignedUrls ||
    usedImageHashes.size !== expectedTargets ||
    resolved.size !== expectedTargets ||
    failures.length > 0;
  if (gateFailed) {
    console.error(
      `Image sync gates failed: places=${finalPlaces.length}/61, ` +
      `tours=${finalTours.length}/12, missingStorage=${rowsMissingStorageImages.length}, ` +
      `duplicateUrls=${duplicates.length}, ` +
      `uniqueHashes=${usedImageHashes.size}/${expectedTargets}, ` +
      `resolved=${resolved.size}/${expectedTargets}, failures=${failures.length}.`,
    );
    process.exitCode = 1;
  }
  await writeCsvReport(finalUrls);
  if (!gateFailed) {
    console.log(
      `PASS: ${finalPlaces.length} places and ${finalTours.length} tours use ` +
      `${usedImageHashes.size} distinct image binaries; ${hotelTargets.length} ` +
      `hotel seeds and ${mockTourTargets.length} local tours are included. ` +
      `Attribution report: ${path.relative(root, reportPath)}`,
    );
  }
}
