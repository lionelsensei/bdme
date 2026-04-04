const express = require('express');
const router  = express.Router();
const supabase = require('../services/supabase');

router.get('/', async (req, res) => {
  const { data, error } = await supabase.from('bdme_wishlist').select('*').eq('user_id', req.user.id).order('added_at', { ascending: false });
  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

router.post('/', async (req, res) => {
  const { bdgest_id, title, series, tome, author, illustrator, publisher, year, cover_url } = req.body;
  if (!title) return res.status(400).json({ error: 'Le titre est obligatoire' });
  const { data, error } = await supabase.from('bdme_wishlist').insert({
    user_id: req.user.id, bdgest_id, title, series, tome, author, illustrator, publisher, year, cover_url,
  }).select().single();
  if (error) return res.status(500).json({ error: error.message });
  res.status(201).json(data);
});

router.delete('/:id', async (req, res) => {
  const { error } = await supabase.from('bdme_wishlist').delete().eq('id', req.params.id).eq('user_id', req.user.id);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ success: true });
});

router.post('/:id/move-to-collection', async (req, res) => {
  const { data: item, error: fetchErr } = await supabase.from('bdme_wishlist').select('*').eq('id', req.params.id).eq('user_id', req.user.id).single();
  if (fetchErr || !item) return res.status(404).json({ error: 'Élément wishlist introuvable' });
  const { data: book, error: insertErr } = await supabase.from('bdme_books').insert({
    user_id: req.user.id, bdgest_id: item.bdgest_id, title: item.title, series: item.series,
    tome: item.tome, author: item.author, illustrator: item.illustrator, publisher: item.publisher,
    year: item.year, cover_url: item.cover_url, read_status: 'unread',
  }).select().single();
  if (insertErr) return res.status(500).json({ error: insertErr.message });
  await supabase.from('bdme_wishlist').delete().eq('id', item.id);
  res.status(201).json(book);
});

module.exports = router;
