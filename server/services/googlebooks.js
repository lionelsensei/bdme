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
  const m = (str || '').match(/\bT(?:ome)?\s*\.?\s*(\d+)\b/i);
  return m ? parseInt(m[1]) : null;
}

function mapVolume(item) {
  if (!item?.volumeInfo) return null;
  const info    = item.volumeInfo;
  const authors = info.authors || [];
  const isbn13  = info.industryIdentifiers?.find(i => i.type === 'ISBN_13')?.identifier || null;
  const isbn10  = info.industryIdentifiers?.find(i => i.type === 'ISBN_10')?.identifier || null;
  const tome    = parseTome(info.title) || parseTome(info.subtitle) || null;

  return {
    bdgest_id:   item.id,
    title:       info.title        || '',
    series:      info.subtitle     || null,
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

  const params = { q: query, maxResults: 20, printType: 'books', langRestrict: 'fr' };
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
