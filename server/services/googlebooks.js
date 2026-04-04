const axios    = require('axios');
const NodeCache = require('node-cache');

const cache = new NodeCache({ stdTTL: 3600, checkperiod: 600 });
const BASE  = 'https://www.googleapis.com/books/v1';

function buildCoverUrl(item) {
  const links = item.volumeInfo?.imageLinks;
  if (!links) return null;
  const raw = links.thumbnail || links.smallThumbnail;
  if (!raw) return null;
  // Meilleure qualité + HTTPS + pas de coin corné
  return raw.replace('zoom=1', 'zoom=0').replace('http://', 'https://').replace('&edge=curl', '');
}

function parseYear(str) {
  const m = (str || '').match(/\d{4}/);
  return m ? parseInt(m[0]) : null;
}

function parseTome(str) {
  const m = (str || '').match(/\b(?:T(?:ome)?\s*\.?\s*|n°\s*)(\d+)\b/i);
  return m ? parseInt(m[1]) : null;
}

// Tente de décomposer le titre Google Books en { series, title, tome }
// Formats courants : "Série - Titre - n°N" / "Série - Titre T.N" / "Série - Titre"
function parseGoogleTitle(rawTitle, subtitle) {
  const t = (rawTitle || '').trim();

  // Format 3 parties : "Série - Titre - n°N" ou "Série - Titre - Tome N"
  const m3 = t.match(/^(.+?)\s*-\s*(.+?)\s*-\s*(?:n°|t(?:ome)?\s*\.?\s*)(\d+)\s*$/i);
  if (m3) return { series: m3[1].trim(), title: m3[2].trim(), tome: parseInt(m3[3]) };

  // Format 2 parties avec tome dans la 2e : "Série - Titre T.N" ou "Série (T.N) - Titre"
  const m2t = t.match(/^(.+?)\s*-\s*(.+?)\s*(?:n°|t(?:ome)?\s*\.?\s*)(\d+)\s*$/i);
  if (m2t) return { series: m2t[1].trim(), title: m2t[2].trim(), tome: parseInt(m2t[3]) };

  // Format 2 parties sans tome : "Série - Titre"
  const m2 = t.match(/^([^-]{3,}?)\s*-\s*(.{3,})$/);
  if (m2) {
    const tome = parseTome(m2[2]) || parseTome(subtitle);
    return { series: m2[1].trim(), title: m2[2].trim(), tome };
  }

  // Titre seul — subtitle comme série éventuelle
  return { series: subtitle?.trim() || null, title: t, tome: parseTome(t) || parseTome(subtitle) };
}

function mapVolume(item) {
  if (!item?.volumeInfo) return null;
  const info    = item.volumeInfo;
  const authors = info.authors || [];
  const isbn13  = info.industryIdentifiers?.find(i => i.type === 'ISBN_13')?.identifier || null;
  const isbn10  = info.industryIdentifiers?.find(i => i.type === 'ISBN_10')?.identifier || null;

  const { series, title, tome } = parseGoogleTitle(info.title, info.subtitle);

  return {
    bdgest_id:   item.id,
    title:       title             || info.title || '',
    series:      series            || null,
    tome,
    author:      authors[0]        || null,
    illustrator: authors[1]        || null,
    publisher:   info.publisher    || null,
    year:        parseYear(info.publishedDate),
    genre:       info.categories?.[0] || null,
    ean:         isbn13 || isbn10  || null,
    cover_url:   buildCoverUrl(item),
    synopsis:    info.description  || null,
  };
}

// ── Recherche par texte ───────────────────────────────────────
async function search(query, apiKey) {
  const cacheKey = 'search:' + query;
  const cached   = cache.get(cacheKey);
  if (cached) return cached;

  const params = { q: query, maxResults: 40, printType: 'books', langRestrict: 'fr' };
  if (apiKey) params.key = apiKey;

  try {
    const { data } = await axios.get(`${BASE}/volumes`, { params, timeout: 10000 });
    const results  = (data.items || []).map(mapVolume).filter(Boolean);
    console.log('[GoogleBooks] Recherche "' + query + '" -> ' + results.length + ' résultats');
    cache.set(cacheKey, results);
    return results;
  } catch (err) {
    console.error('[GoogleBooks] Erreur recherche:', err.message);
    throw new Error('Erreur lors de la recherche Google Books.');
  }
}

// ── Recherche par ISBN/EAN ────────────────────────────────────
async function searchByISBN(ean, apiKey) {
  const cacheKey = 'isbn:' + ean;
  const cached   = cache.get(cacheKey);
  if (cached) return cached;

  const params = { q: `isbn:${ean}` };
  if (apiKey) params.key = apiKey;

  try {
    const { data } = await axios.get(`${BASE}/volumes`, { params, timeout: 10000 });
    const item     = data.items?.[0] || null;
    const result   = item ? { ...mapVolume(item), ean } : null;
    if (result) cache.set(cacheKey, result);
    console.log('[GoogleBooks] ISBN "' + ean + '" -> ' + (result ? result.title : 'non trouvé'));
    return result;
  } catch (err) {
    console.error('[GoogleBooks] Erreur ISBN:', err.message);
    throw new Error('Erreur lors de la recherche par ISBN.');
  }
}

// ── Fiche détaillée par volumeId ─────────────────────────────
async function getAlbumDetails(volumeId, apiKey) {
  const cacheKey = 'album:' + volumeId;
  const cached   = cache.get(cacheKey);
  if (cached) return cached;

  const params = {};
  if (apiKey) params.key = apiKey;

  try {
    const { data } = await axios.get(`${BASE}/volumes/${volumeId}`, { params, timeout: 10000 });
    const details  = mapVolume(data);
    if (details) cache.set(cacheKey, details);
    console.log('[GoogleBooks] Fiche "' + volumeId + '" -> ' + (details?.title || 'non trouvé'));
    return details;
  } catch (err) {
    console.error('[GoogleBooks] Erreur fiche:', err.message);
    return null;
  }
}

module.exports = { search, searchByISBN, getAlbumDetails };
