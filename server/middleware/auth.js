/**
 * Le backend n'est plus qu'un proxy de recherche BDGest pour l'app iOS
 * personnelle — pas de multi-utilisateur, juste un jeton d'accès partagé
 * entre l'app et le serveur (Réglages > Proxy BDGest côté app).
 */
module.exports = function authMiddleware(req, res, next) {
  const auth = req.headers.authorization;
  const token = auth && auth.startsWith('Bearer ') ? auth.slice(7) : null;
  if (!process.env.PROXY_TOKEN || token !== process.env.PROXY_TOKEN) {
    return res.status(401).json({ error: 'Jeton invalide' });
  }
  next();
};
