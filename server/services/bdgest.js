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
  const cacheKey = `bdg:album:${albumUrl}`;
  const cached   = cache.get(cacheKey);
  if (cached) return cached;

  const client = await getClient(credentials.login, credentials.password);
  const url    = albumUrl.startsWith('http') ? albumUrl : BASE + albumUrl;

  try {
    const { data } = await client.get(url);
    const $ = cheerio.load(data);

    const author      = $('.scenariste a').first().text().trim() || $('.auteur-scenariste a').first().text().trim();
    const illustrator = $('.dessinateur a').first().text().trim() || $('.auteur-dessinateur a').first().text().trim();
    const title       = $('h1.titre').first().text().trim() || $('h1').first().text().trim();
    const series      = $('.serie a').first().text().trim() || $('[itemprop="isPartOf"]').text().trim();
    const tomeText    = $('.numero-tome, .num-tome').first().text().trim();
    const tome        = tomeText ? parseInt(tomeText.replace(/[^0-9]/g, ''), 10) || null : null;
    const publisher   = $('.editeur a').first().text().trim() || null;
    const parution    = $('.parution').first().text().trim();
    const yearM       = parution.match(/(\d{4})/);
    const year        = yearM ? yearM[1] : null;
    const genre       = $('.style a').first().text().trim() || null;
    const eanText     = $('.ean').first().text().trim();
    const ean         = eanText.replace(/\D/g, '') || null;
    const coverSrc    = $('img.couverture, .couverture img, [itemprop="image"]').first().attr('src');
    const cover_url   = coverSrc ? (coverSrc.startsWith('http') ? coverSrc : BASE + coverSrc) : null;
    const synopsis    = $('.synopsis p').text().trim() || $('.resume').text().trim() || null;

    if (!title && !author && !series) {
      console.warn('[BDGest] Fiche vide pour', url);
      return null;
    }

    const details = { title, series: series || null, tome, author: author || null, illustrator: illustrator || null, publisher, year, genre, ean, cover_url, synopsis };
    cache.set(cacheKey, details);
    return details;

  } catch (err) {
    console.error('[BDGest] Erreur fiche:', url, err.message);
    return null;
  }
}

function invalidateSession() {
  _client = null;
  _expiry = 0;
}

module.exports = { search, searchByISBN, getAlbumDetails, invalidateSession };
