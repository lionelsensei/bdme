/**
 * Service Bedetheque / BDGest
 * Scraping HTML de bedetheque.com (base de données BDGest).
 * Nécessite un compte BDGest (identifiants stockés dans bdme_api_keys, service='bdgest').
 */

const axios     = require('axios');
const { wrapper } = require('axios-cookiejar-support');
const { CookieJar } = require('tough-cookie');
const cheerio   = require('cheerio');
const NodeCache = require('node-cache');

const cache = new NodeCache({ stdTTL: 3600 });
const BASE  = 'https://www.bedetheque.com';

let _client  = null;
let _expiry  = 0;

// ── Client HTTP avec gestion des cookies ──────────────────────
function createClient() {
  const jar = new CookieJar();
  return wrapper(axios.create({
    jar,
    timeout: 15000,
    withCredentials: true,
    maxRedirects: 10,
    headers: {
      'User-Agent':      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.8',
      'Accept':          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    },
  }));
}

// ── Authentification ──────────────────────────────────────────
async function getClient(login, password) {
  if (_client && Date.now() < _expiry) return _client;

  _client  = null;
  _expiry  = 0;

  const client = createClient();

  try {
    // 1. Charger la page de login pour récupérer le token CSRF
    const loginPage = await client.get(`${BASE}/connect/login`);
    const $l = cheerio.load(loginPage.data);
    const csrf = $l('input[name="csrf_token_bel"]').first().val() || '';

    // 2. Soumettre le formulaire de connexion
    const form = new URLSearchParams();
    form.append('pseudo',          login);
    form.append('password',        password);
    form.append('csrf_token_bel',  csrf);
    form.append('auto_connect',    '1');
    form.append('page_source',     BASE + '/');

    const resp = await client.post(`${BASE}/connect/login`, form.toString(), {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Referer': `${BASE}/connect/login` },
    });

    // Vérifier que la connexion a réussi (si le champ pseudo est encore visible → échec)
    const $c = cheerio.load(resp.data);
    if ($c('input[name="pseudo"]').length > 0) {
      throw new Error('Identifiants BDGest incorrects — vérifiez dans l\'admin.');
    }

    _client = client;
    _expiry = Date.now() + 55 * 60 * 1000; // 55 min
    console.log('[BDGest] Connexion OK');
    return client;

  } catch (err) {
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

  const client = await getClient(credentials.login, credentials.password);

  try {
    const { data } = await client.get(`${BASE}/search/albums`, {
      params: {
        RechIdSerie: '', RechIdAuteur: '',
        RechSerie:   query, RechTitre: '',
        RechEditeur: '', RechCollection: '',
        RechStyle:   '', RechAuteur: '', RechISBN: '',
        RechParution:'', RechOrigine: '', RechLangue: '',
        RechMotCle:  '', RechDLDeb:   '', RechDLFin:  '',
        RechCoteMin: '', RechCoteMax: '', RechEO: '0',
      },
      headers: { Referer: `${BASE}/search` },
    });

    const $ = cheerio.load(data);
    const results = parseResults($);
    console.log(`[BDGest] Recherche "${query}" → ${results.length} résultats`);

    const response = { results, totalItems: results.length };
    cache.set(cacheKey, response);
    return response;

  } catch (err) {
    console.error('[BDGest] Erreur recherche:', err.message);
    throw new Error('Erreur lors de la recherche BDGest.');
  }
}

// ── Recherche par ISBN/EAN ────────────────────────────────────
async function searchByISBN(ean, credentials) {
  const cacheKey = `bdg:isbn:${ean}`;
  const cached   = cache.get(cacheKey);
  if (cached) return cached;

  const client = await getClient(credentials.login, credentials.password);

  try {
    const { data } = await client.get(`${BASE}/search/albums`, {
      params: {
        RechIdSerie: '', RechIdAuteur: '',
        RechSerie:   '', RechTitre:    '', RechEditeur: '', RechCollection: '',
        RechStyle:   '', RechAuteur:   '', RechISBN:    ean,
        RechParution:'', RechOrigine:  '', RechLangue:  '',
        RechMotCle:  '', RechDLDeb:    '', RechDLFin:   '',
        RechCoteMin: '', RechCoteMax:  '', RechEO:      '0',
      },
      headers: { Referer: `${BASE}/search` },
    });

    const $ = cheerio.load(data);
    const results = parseResults($);
    const result  = results.length > 0 ? { ...results[0], ean } : null;
    if (result) cache.set(cacheKey, result);
    return result;

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

  const client = await getClient(credentials.login, credentials.password);

  try {
    const { data } = await client.get(albumUrl);
    const $ = cheerio.load(data);

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
    const series    = $('a[href*="/serie-"]').first().attr('title') || null;
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
      return null;
    }

    console.log(`[BDGest] Fiche OK: ${title} (${author})`);
    const details = { title, series, tome, author, illustrator, publisher, year, ean, genre, cover_url, synopsis };
    cache.set(cacheKey, details);
    return details;

  } catch (err) {
    console.error('[BDGest] Erreur fiche:', albumUrl, err.message);
    return null;
  }
}

function invalidateSession() {
  _client = null;
  _expiry = 0;
}

module.exports = { search, searchByISBN, getAlbumDetails, invalidateSession };
