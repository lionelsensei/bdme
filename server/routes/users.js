const express = require('express');
const router  = express.Router();
const adminMiddleware = require('../middleware/admin');
const supabase = require('../services/supabase');
const { createClient } = require('@supabase/supabase-js');

const adminClient = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
});

router.get('/me', async (req, res) => res.json(req.user));

router.get('/', adminMiddleware, async (req, res) => {
  const { data, error } = await supabase.from('bdme_users').select('id,email,display_name,role,created_at').order('created_at', { ascending: false });
  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

router.post('/', adminMiddleware, async (req, res) => {
  const { email, password, display_name, role } = req.body;
  if (!email || !password) return res.status(400).json({ error: 'Email et mot de passe requis' });
  if (!['user','admin'].includes(role)) return res.status(400).json({ error: 'Rôle invalide' });
  const { data, error } = await adminClient.auth.admin.createUser({
    email, password, user_metadata: { display_name, role }, email_confirm: true,
  });
  if (error) return res.status(400).json({ error: error.message });
  res.status(201).json({ id: data.user.id, email, display_name, role });
});

router.patch('/:id', adminMiddleware, async (req, res) => {
  const { role, display_name } = req.body;
  const updates = {};
  if (role && ['user','admin'].includes(role)) updates.role = role;
  if (display_name) updates.display_name = display_name;
  const { data, error } = await supabase.from('bdme_users').update(updates).eq('id', req.params.id).select().single();
  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

router.delete('/:id', adminMiddleware, async (req, res) => {
  if (req.params.id === req.user.id) return res.status(400).json({ error: 'Impossible de supprimer votre propre compte' });
  const { error } = await adminClient.auth.admin.deleteUser(req.params.id);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ success: true });
});

module.exports = router;
