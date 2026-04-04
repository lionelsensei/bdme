const express = require('express');
const router  = express.Router();
const supabase = require('../services/supabase');

router.get('/', async (req, res) => {
  const { data, error } = await supabase.from('bdme_books').select('*').eq('user_id', req.user.id).order('added_at', { ascending: false });
  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

router.post('/', async (req, res) => {
  const { bdgest_id, title, series, tome, author, illustrator, publisher, year, genre, ean, cover_url, synopsis, read_status } = req.body;
  if (!title) return res.status(400).json({ error: 'Le titre est obligatoire' });
  if (bdgest_id) {
    const { data: existing } = await supabase.from('bdme_books').select('id').eq('user_id', req.user.id).eq('bdgest_id', bdgest_id).single();
    if (existing) return res.status(409).json({ error: 'Cet album est déjà dans votre collection' });
  }
  const { data, error } = await supabase.from('bdme_books').insert({
    user_id: req.user.id, bdgest_id, title, series, tome, author, illustrator,
    publisher, year, genre, ean, cover_url, synopsis, read_status: read_status || 'unread',
  }).select().single();
  if (error) return res.status(500).json({ error: error.message });
  res.status(201).json(data);
});

router.patch('/:id', async (req, res) => {
  const allowed = ['read_status','title','series','tome','author','illustrator','publisher','year','genre','synopsis'];
  const updates = {};
  for (const key of allowed) { if (req.body[key] !== undefined) updates[key] = req.body[key]; }
  const { data, error } = await supabase.from('bdme_books').update(updates).eq('id', req.params.id).eq('user_id', req.user.id).select().single();
  if (error) return res.status(500).json({ error: error.message });
  if (!data) return res.status(404).json({ error: 'Album introuvable' });
  res.json(data);
});

router.delete('/:id', async (req, res) => {
  const { error } = await supabase.from('bdme_books').delete().eq('id', req.params.id).eq('user_id', req.user.id);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ success: true });
});

module.exports = router;
