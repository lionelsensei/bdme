require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const cookieParser = require('cookie-parser');
const rateLimit = require('express-rate-limit');
const fs   = require('fs');
const path = require('path');

const authMiddleware = require('./middleware/auth');
const booksRouter    = require('./routes/books');
const wishlistRouter = require('./routes/wishlist');
const searchRouter   = require('./routes/search');
const usersRouter    = require('./routes/users');
const apiKeysRouter  = require('./routes/apiKeys');

const app = express();
app.set('trust proxy', 1);

app.use(helmet());
app.use(cors({ origin: process.env.CLIENT_ORIGIN || 'http://localhost:5173', credentials: true }));
app.use(cookieParser());
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

app.get('/health',    (req, res) => res.json({ status: 'ok', app: 'BDme' }));
app.get('/changelog', (req, res) => {
  try {
    const content = fs.readFileSync(path.join(__dirname, '../CHANGELOG.md'), 'utf8');
    res.type('text/plain; charset=utf-8').send(content);
  } catch { res.status(404).send('') }
});

app.use('/api/books',    authMiddleware, booksRouter);
app.use('/api/wishlist', authMiddleware, wishlistRouter);
app.use('/api/search',   authMiddleware, searchLimiter, searchRouter);
app.use('/api/users',    authMiddleware, usersRouter);
app.use('/api/api-keys', authMiddleware, apiKeysRouter);

app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(err.status || 500).json({ error: err.message || 'Erreur serveur' });
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log(`BDme server running on port ${PORT}`));
