const axios     = require('axios');
const NodeCache = require('node-cache');

const cache = new NodeCache({ stdTTL: 3600 });
const BASE  = 'https://openlibrary.org';

function mapDoc(doc) {
  return {
    bdgest_id:  doc.key?.replace('/works/', 'ol:') || null,
    title:      doc.title || null,
    series:     null,
    tome:       null,
    author:     doc.author_name?.[0]  || null,
    illustrator:doc.author_name?.[1]  || null,
    publisher:  doc.publisher?.[0]    || null,
    year:       doc.first_publish_year?.toString() || null,
    genre:      doc.subject?.[0]      || null,
    ean:        doc.isbn?.[0]         || null,
    cover_url:  doc.cover_i ? `https://covers.openlibrary.org/b/id/${doc.cover_i}-M.jpg` : null,
    synopsis:   null,
  };
}

async function search(query, startIndex = 0) {
  const cacheKey = `ol:search:${query}:${startIndex}`;
  const cached   = cache.get(cacheKey);
  if (cached) return cached;

  try {
    const { data } = await axios.get(`${BASE}/search.json`, {
      params: { q: query, subject: 'comics', limit: 40, offset: startIndex, lang: 'fre' },
      timeout: 10000,
    });
    const results    = (data.docs || []).map(mapDoc).filter(d => d.title);
    const totalItems = data.numFound || 0;
    console.log('[OpenLibrary] Recherche "' + query + '" (offset=' + startIndex + ') -> ' + results.length + '/' + totalItems);
    const response = { results, totalItems };
    cache.set(cacheKey, response);
    return response;
  } catch (err) {
    console.error('[OpenLibrary] Erreur recherche:', err.message);
    throw new Error('Erreur lors de la recherche Open Library.');
  }
}

module.exports = { search };
