const express = require('express');
const router  = express.Router();
const adminMiddleware = require('../middleware/admin');
const supabase = require('../services/supabase');
const { encrypt } = require('../services/crypto');
const { invalidateSession } = require('../services/bdgest');

router.use(adminMiddleware);

router.get('/', async (req, res) => {
  const { data, error } = await supabase.from('bdme_api_keys').select('id,service,label,created_at,updated_at').order('created_at', { ascending: false });
  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

router.post('/', async (req, res) => {
  const { service, label, login, password } = req.body;
  if (!login || !password || !label) return res.status(400).json({ error: 'label, login et password requis' });
  const { data, error } = await supabase.from('bdme_api_keys').insert({
    service: service || 'bdgest', label,
    encrypted_login: encrypt(login), encrypted_password: encrypt(password),
    created_by: req.user.id,
  }).select('id,service,label,created_at').single();
  if (error) return res.status(500).json({ error: error.message });
  invalidateSession();
  res.status(201).json(data);
});

router.put('/:id', async (req, res) => {
  const { label, login, password } = req.body;
  const updates = {};
  if (label)    updates.label            = label;
  if (login)    updates.encrypted_login  = encrypt(login);
  if (password) updates.encrypted_password = encrypt(password);
  const { data, error } = await supabase.from('bdme_api_keys').update(updates).eq('id', req.params.id).select('id,service,label,updated_at').single();
  if (error) return res.status(500).json({ error: error.message });
  invalidateSession();
  res.json(data);
});

router.delete('/:id', async (req, res) => {
  const { error } = await supabase.from('bdme_api_keys').delete().eq('id', req.params.id);
  if (error) return res.status(500).json({ error: error.message });
  invalidateSession();
  res.json({ success: true });
});

module.exports = router;
