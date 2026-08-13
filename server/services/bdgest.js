/**
 * Service Bedetheque / BDGest
 * Scraping HTML de bedetheque.com (base de données BDGest).
 * Nécessite un compte BDGest (identifiants stockés dans bdme_api_keys, service='bdgest').
 *
 * bedetheque.com est protégé par Cloudflare (Bot Fight Mode). Un cookie
 * cf_clearance obtenu par un navigateur headless (FlareSolverr) ne suffit
 * pas s'il est ensuite réutilisé par un client HTTP classique (axios) :
 * Cloudflare semble aussi vérifier la cohérence de l'empreinte TLS du
 * client, pas seulement le cookie — observé empiriquement (403 malgré un
 * cf_clearance valide). Toutes les requêtes passent donc par FlareSolverr
 * (même navigateur headless du début à la fin d'une session), via une
 * session persistante pour ne pas re-résoudre le challenge à chaque appel.
 */

const axios     = require('axios');
const cheerio   = require('cheerio');
const NodeCache = require('node-cache');

const cache = new NodeCache({ stdTTL: 3600 });
const BASE  = 'https://www.bedetheque.com';
const FLARESOLVERR_URL = process.env.FLARESOLVERR_URL || 'http://127.0.0.1:8191/v1';

let _session = null;
let _expiry  = 0;

function sleep(ms) { return new Promise(resolve => setTimeout(resolve, ms)); }

// ── Circuit breaker ─────────────────────────────────────────────
// Un blocage anti-bot/TLS de bedetheque.com (Cloudflare) ne se répare pas
// en insistant — retenter dans la foulée ne fait qu'aggraver le blocage.
// Une fois le circuit ouvert, on refuse immédiatement les nouvelles
// requêtes (sans toucher le réseau) pendant un temps de repos croissant,
// jusqu'à ce qu'une requête réussisse à nouveau.
const CIRCUIT_BASE_COOLDOWN_MS = 5 * 60 * 1000;      // 5 min
const CIRCUIT_MAX_COOLDOWN_MS  = 2 * 60 * 60 * 1000; // 2h

let _circuitOpenUntil   = 0;
let _consecutiveTrips   = 0;

function isCircuitOpen() {
  return Date.now() < _circuitOpenUntil;
}

function circuitRemainingMinutes() {
  return Math.max(1, Math.ceil((_circuitOpenUntil - Date.now()) / 60000));
}

function tripCircuit() {
  _consecutiveTrips++;
  const cooldown = Math.min(CIRCUIT_BASE_COOLDOWN_MS * Math.pow(2, _consecutiveTrips - 1), CIRCUIT_MAX_COOLDOWN_MS);
  _circuitOpenUntil = Date.now() + cooldown;
  console.warn(`[BDGest] Circuit ouvert ${Math.round(cooldown / 60000)} min (échec #${_consecutiveTrips})`);
}

function resetCircuit() {
  if (_consecutiveTrips > 0) console.log('[BDGest] Circuit refermé — connexion rétablie');
  _consecutiveTrips = 0;
  _circuitOpenUntil = 0;
}

// ── Retry avec backoff exponentiel ─────────────────────────────
async function withRetry(fn, { attempts = 3, baseDelayMs = 800 } = {}) {
  if (isCircuitOpen()) {
    throw new Error(`Bedetheque temporairement indisponible (blocage réseau détecté) — réessayez dans ~${circuitRemainingMinutes()} min.`);
  }

  let lastErr;
  for (let i = 0; i < attempts; i++) {
    try {
      const result = await fn();
      resetCircuit();
      return result;
    } catch (err) {
      lastErr = err;
      console.warn(`[BDGest] Tentative ${i + 1}/${attempts} échouée: ${err.message}`);
      if (i < attempts - 1) {
        invalidateSession();
        await sleep(baseDelayMs * Math.pow(2, i));
      }
    }
  }
  tripCircuit();
  throw lastErr;
}

// ── FlareSolverr : toutes les requêtes bedetheque passent par ici ─
async function fsRequest(cmd, params = {}) {
  const { data } = await axios.post(FLARESOLVERR_URL, {
    cmd,
    maxTimeout: 45000,
    ...params,
  }, { timeout: 50000 });

  if (data.status !== 'ok') {
    throw new Error(`FlareSolverr: ${data.message || 'échec de résolution'}`);
  }
  return data;
}

async function fetchPage(url, session) {
  const data = await fsRequest('request.get', { url, session });
  return data.solution.response;
}

// ── Authentification (session FlareSolverr persistante) ────────
async function getSession(login, password) {
  if (_session && Date.now() < _expiry) return _session;

  _session = null;
  _expiry  = 0;

  const { session } = await fsRequest('sessions.create');

  try {
    // 1. Charger la page de login pour récupérer le token CSRF
    const loginHtml = await fetchPage(`${BASE}/connect/login`, session);
    const $l = cheerio.load(loginHtml);
    const csrf = $l('input[name="csrf_token_bel"]').first().val() || '';

    // 2. Soumettre le formulaire de connexion (via le même navigateur headless)
    const form = new URLSearchParams();
    form.append('pseudo',          login);
    form.append('password',        password);
    form.append('csrf_token_bel',  csrf);
    form.append('auto_connect',    '1');
    form.append('page_source',     BASE + '/');

    const resp = await fsRequest('request.post', {
      url: `${BASE}/connect/login`,
      session,
      postData: form.toString(),
    });

    // Vérifier que la connexion a réussi (si le champ pseudo est encore visible → échec)
    const $c = cheerio.load(resp.solution.response);
    if ($c('input[name="pseudo"]').length > 0) {
      throw new Error('Identifiants BDGest incorrects — vérifiez dans l\'admin.');
    }

    _session = session;
    _expiry  = Date.now() + 30 * 60 * 1000; // 30 min
    console.log(`[BDGest] Connexion OK (FlareSolverr, session ${session})`);
    return session;

  } catch (err) {
    fsRequest('sessions.destroy', { session }).catch(() => {});
    console.error('[BDGest] Échec connexion:', err.message);
    throw new Error(err.message.startsWith('Identifiants') ? err.message : 'Connexion à Bedetheque échouée.');
  }
}

// ── Parsing des résultats de recherche ────────────────────────
function parseResults($) {
  const results = [];

  $('ul.search-list > li, .album-list li').each((_, el) => {
    const $el      = $(el);
    const $link    = $el.find('a[href*="/BD-"]').first();
    if (!$link.length) return;

    const href     = $link.attr('href') || '';
    const fullUrl  = href.startsWith('http') ? href : BASE + href;

    // Couverture : attribut rel ou data-src de l'image
    const coverRel = $link.attr('rel') || '';
    const coverImg = $el.find('img').first().attr('data-src') || $el.find('img').first().attr('src') || '';
    const cover    = coverRel || coverImg || null;

    const series   = $el.find('.serie').text().trim()  || $el.find('[class*="serie"]').text().trim();
    const title    = $el.find('.titre').text().trim()  || $el.find('[class*="titre"]').text().trim();
    const tomeStr  = $el.find('.num').text().replace(/[^0-9]/g, '').trim();
    const tome     = tomeStr ? parseInt(tomeStr, 10) : null;
    const dlText   = $el.find('.dl').text().trim();
    const yearM    = dlText.match(/(\d{4})/);
    const year     = yearM ? yearM[1] : null;

    // On stocke l'URL complète dans bdgest_id pour pouvoir récupérer la fiche plus tard
    const bdgestId = fullUrl ? `bdg:${fullUrl}` : null;

    if (title || series) {
      results.push({
        bdgest_id:   bdgestId,
        bdgest_url:  fullUrl,
        title:       title  || series,
        series:      series || null,
        tome,
        author:      null,
        illustrator: null,
        publisher:   null,
        year,
        genre:       null,
        ean:         null,
        cover_url:   cover ? (cover.startsWith('http') ? cover : BASE + cover) : null,
        synopsis:    null,
      });
    }
  });

  return results;
}

// ── Recherche par texte ───────────────────────────────────────
async function search(query, credentials) {
  const cacheKey = `bdg:search:${query}`;
  const cached   = cache.get(cacheKey);
  if (cached) return cached;

  return withRetry(async () => {
    const session = await getSession(credentials.login, credentials.password);

    const params = new URLSearchParams({
      RechIdSerie: '', RechIdAuteur: '',
      RechSerie:   query, RechTitre: '',
      RechEditeur: '', RechCollection: '',
      RechStyle:   '', RechAuteur: '', RechISBN: '',
      RechParution:'', RechOrigine: '', RechLangue: '',
      RechMotCle:  '', RechDLDeb:   '', RechDLFin:  '',
      RechCoteMin: '', RechCoteMax: '', RechEO: '0',
    });

    try {
      const html = await fetchPage(`${BASE}/search/albums?${params.toString()}`, session);
      const $ = cheerio.load(html);
      const results = parseResults($);
      console.log(`[BDGest] Recherche "${query}" → ${results.length} résultats`);

      const response = { results, totalItems: results.length };
      cache.set(cacheKey, response);
      return response;

    } catch (err) {
      console.error('[BDGest] Erreur recherche:', err.message);
      throw new Error('Erreur lors de la recherche BDGest.');
    }
  });
}

// ── Recherche par ISBN/EAN ────────────────────────────────────
async function searchByISBN(ean, credentials) {
  const cacheKey = `bdg:isbn:${ean}`;
  const cached   = cache.get(cacheKey);
  if (cached) return cached;

  try {
    return await withRetry(async () => {
      const session = await getSession(credentials.login, credentials.password);

      const params = new URLSearchParams({
        RechIdSerie: '', RechIdAuteur: '',
        RechSerie:   '', RechTitre:    '', RechEditeur: '', RechCollection: '',
        RechStyle:   '', RechAuteur:   '', RechISBN:    ean,
        RechParution:'', RechOrigine:  '', RechLangue:  '',
        RechMotCle:  '', RechDLDeb:    '', RechDLFin:   '',
        RechCoteMin: '', RechCoteMax:  '', RechEO:      '0',
      });

      const html = await fetchPage(`${BASE}/search/albums?${params.toString()}`, session);
      const $ = cheerio.load(html);
      const results = parseResults($);
      const result  = results.length > 0 ? { ...results[0], ean } : null;
      if (result) cache.set(cacheKey, result);
      return result;
    });
  } catch (err) {
    console.error('[BDGest] Erreur ISBN:', err.message);
    return null;
  }
}

// ── Fiche album complète ──────────────────────────────────────
async function getAlbumDetails(albumUrl, credentials) {
  if (!albumUrl || !albumUrl.startsWith('http')) {
    console.warn('[BDGest] URL invalide:', albumUrl);
    return null;
  }

  const cacheKey = `bdg:album:${albumUrl}`;
  const cached   = cache.get(cacheKey);
  if (cached) return cached;

  try {
    return await withRetry(async () => {
      const session = await getSession(credentials.login, credentials.password);
      const html = await fetchPage(albumUrl, session);
      const $ = cheerio.load(html);

      // Bedetheque utilise Schema.org microdata (itemprop)
      // Auteurs : premier itemprop="author" hors des avis (dans .liste-auteurs)
      const authors = [];
      $('.liste-auteurs [itemprop="author"], a[href*="/auteur-"]').each((_, el) => {
        const name = $(el).text().trim();
        if (name && !authors.includes(name)) authors.push(name);
      });
      // Fallback : itemprop="author" span (hors avis lecteurs)
      if (authors.length === 0) {
        $('[itemprop="author"]').each((_, el) => {
          const name = $(el).text().trim();
          if (name && !authors.includes(name) && name.length < 60) authors.push(name);
        });
      }
      const author      = authors[0] || null;
      const illustrator = authors[1] && authors[1] !== author ? authors[1] : null;

      // Titre : itemprop="name" ou h3.titre
      const fullName  = $('meta[itemprop="name"]').attr('content') || $('h3.titre').text().trim();
      // Série : premier lien /serie- dans la page
      const seriesLink = $('a[href*="/serie-"]').first();
      const series      = seriesLink.attr('title') || null;
      const seriesUrl   = seriesLink.attr('href') || null;
      // Titre album : supprimer le préfixe "Série - " si présent
      const title     = series && fullName.startsWith(series + ' - ')
        ? fullName.slice(series.length + 3).trim()
        : fullName || null;

      // Tome : depuis l'URL
      const tomeM     = albumUrl.match(/Tome-(\d+)-/i);
      const tome      = tomeM ? parseInt(tomeM[1], 10) : null;

      // Éditeur, date, EAN, genre
      const publisher = $('[itemprop="publisher"]').first().text().trim() || null;
      const yearM     = $('meta[itemprop="datePublished"]').first().attr('content')?.match(/^(\d{4})/);
      const year      = yearM ? yearM[1] : null;
      const eanRaw    = $('[itemprop="isbn"]').first().text().replace(/\D/g, '');
      const ean       = eanRaw || null;
      const genre     = $('meta[itemprop="genre"]').attr('content') || null;

      // Couverture
      const coverSrc  = $('[itemprop="image"]').first().attr('src');
      const cover_url = coverSrc ? (coverSrc.startsWith('http') ? coverSrc : BASE + coverSrc) : null;

      // Synopsis : #p-serie ou premier paragraphe significatif
      const synopsis  = $('#p-serie').text().trim() || null;

      if (!title && !author) {
        console.warn('[BDGest] Fiche vide pour', albumUrl);
        throw new Error('Fiche vide — page inattendue ou temporairement bloquée.');
      }

      console.log(`[BDGest] Fiche OK: ${title} (${author})`);
      const details = {
        title, series, seriesUrl: seriesUrl ? (seriesUrl.startsWith('http') ? seriesUrl : BASE + seriesUrl) : null,
        tome, author, illustrator, publisher, year, ean, genre, cover_url, synopsis,
      };
      cache.set(cacheKey, details);
      return details;
    });
  } catch (err) {
    console.error('[BDGest] Erreur fiche:', albumUrl, err.message);
    return null;
  }
}

// ── Tomes d'une série (pour détecter les tomes manquants) ──────
async function getSeriesTomes(seriesUrl, credentials) {
  if (!seriesUrl || !seriesUrl.startsWith('http')) {
    console.warn('[BDGest] URL de série invalide:', seriesUrl);
    return null;
  }

  const cacheKey = `bdg:series:${seriesUrl}`;
  const cached   = cache.get(cacheKey);
  if (cached) return cached;

  try {
    return await withRetry(async () => {
      const session = await getSession(credentials.login, credentials.password);
      // "__10000.html" affiche tous les tomes de la série sur une seule page
      // (pagination bedetheque désactivée au-delà de ce seuil).
      const allUrl = seriesUrl.replace(/\.html$/, '__10000.html');
      const html = await fetchPage(allUrl, session);
      const $ = cheerio.load(html);

      const tomes = [];
      $('ul.liste-albums > li[itemscope]').each((_, el) => {
        const $el   = $(el);
        const $link = $el.find('h3 a.titre').first();
        const href  = $link.attr('href');
        if (!href) return;

        const nameText = $el.find('h3 [itemprop="name"]').first().text().replace(/\s+/g, ' ').trim();
        const numM     = nameText.match(/^(\d+)/);
        const tome     = numM ? parseInt(numM[1], 10) : null;
        const title    = nameText.replace(/^\d+\s*\.?\s*/, '').trim();
        const coverSrc = $el.find('.couv img').first().attr('src');

        tomes.push({
          bdgest_id: `bdg:${href}`,
          tome,
          title: title || null,
          cover_url: coverSrc ? (coverSrc.startsWith('http') ? coverSrc : BASE + coverSrc) : null,
        });
      });

      tomes.sort((a, b) => (a.tome ?? 999) - (b.tome ?? 999));
      console.log(`[BDGest] Série ${seriesUrl} → ${tomes.length} tomes`);
      cache.set(cacheKey, tomes);
      return tomes;
    });
  } catch (err) {
    console.error('[BDGest] Erreur tomes série:', seriesUrl, err.message);
    return null;
  }
}

function invalidateSession() {
  if (_session) {
    fsRequest('sessions.destroy', { session: _session }).catch(() => {});
  }
  _session = null;
  _expiry  = 0;
}

module.exports = { search, searchByISBN, getAlbumDetails, getSeriesTomes, invalidateSession };
