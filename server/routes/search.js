const express = require('express');
const router  = express.Router();
const bdgest  = require('../services/bdgest');

function credentials() {
  const { BDGEST_LOGIN, BDGEST_PASSWORD } = process.env;
  if (!BDGEST_LOGIN || !BDGEST_PASSWORD) return null;
  return { login: BDGEST_LOGIN, password: BDGEST_PASSWORD };
}

// GET /api/search?q=&startIndex=&source=bdgest
router.get('/', async (req, res) => {
  const query = (req.query.q || '').trim();
  if (!query || query.length < 2) return res.status(400).json({ error: 'Minimum 2 caractères' });

  const creds = credentials();
  if (!creds) return res.status(503).json({ error: 'Identifiants BDGest non configurés (.env).' });

  try {
    const { results, totalItems } = await bdgest.search(query, creds);
    res.json({ results, totalItems });
  } catch (err) {
    res.status(502).json({ error: err.message });
  }
});

// GET /api/search/album/:id  (id = "bdg:<url complète>")
router.get('/album/:id', async (req, res) => {
  const id = req.params.id;
  if (!id.startsWith('bdg:')) return res.status(400).json({ error: 'Identifiant invalide' });

  const creds = credentials();
  if (!creds) return res.status(503).json({ error: 'Identifiants BDGest non configurés (.env).' });

  try {
    const details = await bdgest.getAlbumDetails(id.slice(4), creds);
    if (!details) return res.status(404).json({ error: 'Fiche introuvable' });
    res.json(details);
  } catch (err) {
    res.status(502).json({ error: err.message });
  }
});

module.exports = router;
