const express  = require('express');
const router   = express.Router();
const bdgest   = require('../services/bdgest');
const { decrypt } = require('../services/crypto');
const supabase = require('../services/supabase');

async function getBdgestCredentials() {
  const { data } = await supabase
    .from('bdme_api_keys')
    .select('encrypted_login, encrypted_password')
    .eq('service', 'bdgest')
    .order('created_at', { ascending: false })
    .limit(1)
    .single();
  if (!data?.encrypted_login) return null;
  return { login: decrypt(data.encrypted_login), password: decrypt(data.encrypted_password) };
}

// GET /api/search?q=...
router.get('/', async (req, res) => {
  const query = (req.query.q || '').trim();
  if (!query || query.length < 2) return res.status(400).json({ error: 'Minimum 2 caractères' });
  try {
    const credentials = await getBdgestCredentials();
    const results     = await bdgest.search(query, credentials);

    const bdgestIds = results.map(r => r.bdgest_id).filter(Boolean);
    let inCollection = new Set();
    let inWishlist   = new Set();

    if (bdgestIds.length > 0) {
      const [{ data: col }, { data: wis }] = await Promise.all([
        supabase.from('bdme_books').select('bdgest_id').eq('user_id', req.user.id).in('bdgest_id', bdgestIds),
        supabase.from('bdme_wishlist').select('bdgest_id').eq('user_id', req.user.id).in('bdgest_id', bdgestIds),
      ]);
      inCollection = new Set((col || []).map(b => b.bdgest_id));
      inWishlist   = new Set((wis || []).map(b => b.bdgest_id));
    }

    res.json(results.map(r => ({
      ...r,
      in_collection: r.bdgest_id ? inCollection.has(r.bdgest_id) : false,
      in_wishlist:   r.bdgest_id ? inWishlist.has(r.bdgest_id)   : false,
    })));
  } catch (err) {
    res.status(502).json({ error: err.message });
  }
});

// GET /api/search/isbn/:ean
router.get('/isbn/:ean', async (req, res) => {
  const ean = req.params.ean.replace(/\D/g, '');
  if (!ean || ean.length < 8) return res.status(400).json({ error: 'EAN invalide' });
  try {
    const credentials = await getBdgestCredentials();
    const result      = await bdgest.searchByISBN(ean, credentials);
    if (!result) return res.status(404).json({ error: 'Album introuvable pour cet EAN' });

    let inCollection = false;
    let inWishlist   = false;
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

// GET /api/search/album/:id?url=...
router.get('/album/:id', async (req, res) => {
  try {
    const credentials = await getBdgestCredentials();
    const details     = await bdgest.getAlbumDetails(req.params.id, credentials, req.query.url || null);
    if (!details) return res.status(404).json({ error: 'Fiche introuvable' });
    res.json(details);
  } catch (err) {
    res.status(502).json({ error: err.message });
  }
});

module.exports = router;
