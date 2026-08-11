require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

const authMiddleware = require('./middleware/auth');
const searchRouter = require('./routes/search');

const app = express();
app.set('trust proxy', 1);

app.use(helmet());
app.use(express.json());

app.use(rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 200,
  standardHeaders: true,
  legacyHeaders: false,
  validate: { xForwardedForHeader: false },
}));

const searchLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  message: { error: 'Trop de requêtes, veuillez patienter.' },
  validate: { xForwardedForHeader: false },
});

app.get('/health', (req, res) => res.json({ status: 'ok', app: 'BDme proxy BDGest' }));

app.use('/api/search', authMiddleware, searchLimiter, searchRouter);

app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(err.status || 500).json({ error: err.message || 'Erreur serveur' });
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log(`BDme BDGest proxy running on port ${PORT}`));
