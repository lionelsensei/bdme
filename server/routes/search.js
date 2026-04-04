const express       = require('express');
const router        = express.Router();
const books         = require('../services/googlebooks');
const openLibrary   = require('../services/openlibrary');
const { decrypt }   = require('../services/crypto');
const supabase      = require('../services/supabase');

async function getApiKey() {
  const { data } = await supabase
    .from('bdme_api_keys')
    .select('encrypted_password')
    .eq('service', 'googlebooks')
    .order('created_at', { ascending: false })
    .limit(1)
    .single();
  if (data?.encrypted_password) return decrypt(data.encrypted_password);
  return process.env.GOOGLE_BOOKS_API_KEY || null;
}

// GET /api/search?q=...
router.get('/', async (req, res) => {
  const query      = (req.query.q || '').trim();
  const startIndex = parseInt(req.query.startIndex, 10) || 0;
  const source     = req.query.source || 'googlebooks';
  if (!query || query.length < 2) return res.status(400).json({ error: 'Minimum 2 caractères' });
  try {
    let results, totalItems;
    if (source === 'openlibrary') {
      ({ results, totalItems } = await openLibrary.search(query, startIndex));
    } else {
      const apiKey = await getApiKey();
      ({ results, totalItems } = await books.search(query, apiKey, startIndex));
    }

    const volumeIds = results.map(r => r.bdgest_id).filter(Boolean);
    let inCollection = new Set();
    let inWishlist   = new Set();

    if (volumeIds.length > 0) {
      const [{ data: col }, { data: wis }] = await Promise.all([
        supabase.from('bdme_books').select('bdgest_id').eq('user_id', req.user.id).in('bdgest_id', volumeIds),
        supabase.from('bdme_wishlist').select('bdgest_id').eq('user_id', req.user.id).in('bdgest_id', volumeIds),
      ]);
      inCollection = new Set((col || []).map(b => b.bdgest_id));
      inWishlist   = new Set((wis || []).map(b => b.bdgest_id));
    }

    res.json({
      totalItems,
      results: results.map(r => ({
        ...r,
        in_collection: r.bdgest_id ? inCollection.has(r.bdgest_id) : false,
        in_wishlist:   r.bdgest_id ? inWishlist.has(r.bdgest_id)   : false,
      })),
    });
  } catch (err) {
    res.status(502).json({ error: err.message });
  }
});

// GET /api/search/isbn/:ean
router.get('/isbn/:ean', async (req, res) => {
  const ean = req.params.ean.replace(/\D/g, '');
  if (!ean || ean.length < 8) return res.status(400).json({ error: 'EAN invalide' });
  try {
    const apiKey = await getApiKey();
    const result = await books.searchByISBN(ean, apiKey);
    if (!result) return res.status(404).json({ error: 'Album introuvable pour cet EAN' });

    let inCollection = false, inWishlist = false;
    if (result.bdgest_id) {
      const [{ data: c }, { data: w }] = await Promise.all([
        supabase.from('bdme_books').select('id').eq('user_id', req.user.id).eq('bdgest_id', result.bdgest_id).maybeSingle(),
        supabase.from('bdme_wishlist').select('id').eq('user_id', req.user.id).eq('bdgest_id', result.bdgest_id).maybeSingle(),
      ]);
      inCollection = !!c;
      inWishlist   = !!w;
    }
    res.json({ ...result, in_collection: inCollection, in_wishlist: inWishlist });
  } catch (err) {
    res.status(502).json({ error: err.message });
  }
});

// GET /api/search/album/:id
router.get('/album/:id', async (req, res) => {
  try {
    const apiKey  = await getApiKey();
    const details = await books.getAlbumDetails(req.params.id, apiKey);
    if (!details) return res.status(404).json({ error: 'Fiche introuvable' });
    res.json(details);
  } catch (err) {
    res.status(502).json({ error: err.message });
  }
});

module.exports = router;
