const { createClient } = require('@supabase/supabase-js');
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY);

module.exports = async function authMiddleware(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth || !auth.startsWith('Bearer ')) return res.status(401).json({ error: 'Token manquant' });
  const token = auth.split(' ')[1];
  try {
    const { data: { user }, error } = await supabase.auth.getUser(token);
    if (error || !user) return res.status(401).json({ error: 'Token invalide' });
    const { data: profile } = await supabase.from('bdme_users').select('id,email,display_name,role').eq('id', user.id).single();
    if (!profile) return res.status(401).json({ error: 'Profil introuvable' });
    req.user = profile;
    next();
  } catch {
    res.status(401).json({ error: 'Erreur authentification' });
  }
};
