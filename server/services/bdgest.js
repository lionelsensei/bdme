const axios = require('axios');
const { wrapper } = require('axios-cookiejar-support');
const { CookieJar } = require('tough-cookie');
const cheerio = require('cheerio');
const NodeCache = require('node-cache');

const cache = new NodeCache({ stdTTL: 3600, checkperiod: 600 });

const BDT_BASE      = 'https://www.bedetheque.com';
const LOGIN_FORUM   = 'https://www.bdgest.com/forum/ucp.php?mode=login';
const LOGIN_BDT     = 'https://www.bedetheque.com/connect/login';
const SEARCH_ALBUMS = 'https://www.bedetheque.com/search/albums';

let sessionClient = null;
let sessionJar    = null;
let sessionExpiry = 0;

// ── Création du client HTTP avec gestion des cookies ──────────
function createClient() {
  const jar = new CookieJar();
  const client = wrapper(axios.create({
    jar,
    timeout: 15000,
    headers: {
      'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept-Language': 'fr-FR,fr;q=0.9',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    },
    maxRedirects: 10,
    withCredentials: true,
  }));
  return { client, jar };
}

// ── Authentification (forum BDGest + Bedetheque) ─────────────
async function getAuthenticatedClient(login, password) {
  const now = Date.now();
  if (sessionClient && now < sessionExpiry) {
    return { client: sessionClient, jar: sessionJar };
  }

  const { client, jar } = createClient();

  try {
    // Étape 1 : login forum BDGest (pour obtenir les cookies de session)
    const forumPage = await client.get(LOGIN_FORUM);
    const $f = cheerio.load(forumPage.data);
    let sid = '';
    $f('form[action*="ucp.php"]').each((i, form) => {
      const s = $f(form).find('input[name="sid"]').val();
      if (s) sid = s;
    });

    const fp = new URLSearchParams();
    fp.append('username', login);
    fp.append('password', password);
    fp.append('autologin', 'on');
    fp.append('viewonline', 'on');
    fp.append('redirect', 'index.php');
    fp.append('login', 'Connexion');
    if (sid) fp.append('sid', sid);

    await client.post(LOGIN_FORUM, fp.toString(), {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Referer': LOGIN_FORUM },
    });
    console.log('[BDGest] Login forum OK');

    // Étape 2 : login Bedetheque
    const bdtPage = await client.get(BDT_BASE + '/search');
    const $b = cheerio.load(bdtPage.data);
    const csrf = $b('input[name="csrf_token_bel"]').first().val() || '';

    const bp = new URLSearchParams();
    bp.append('page_source', BDT_BASE + '/search');
    bp.append('csrf_token_bel', csrf);
    bp.append('pseudo', login);
    bp.append('password', password);
    bp.append('auto_connect', '1');

    const bdtResp = await client.post(LOGIN_BDT, bp.toString(), {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Referer': BDT_BASE + '/search' },
    });

    const $check = cheerio.load(bdtResp.data);
    if ($check('input[name="pseudo"]').length > 0) {
      throw new Error('Identifiants incorrects sur Bedetheque');
    }

    sessionClient = client;
    sessionJar    = jar;
    sessionExpiry = now + 3600 * 1000;
    console.log('[BDGest] Login Bedetheque OK');
    return { client, jar };

  } catch (err) {
    sessionClient = null;
    sessionJar    = null;
    sessionExpiry = 0;
    console.error('[BDGest] Echec connexion:', err.message);
    throw new Error('Connexion BDGest echouee. Verifiez vos identifiants dans admin.');
  }
}

// ── Extraction des résultats depuis le HTML Bedetheque ────────
// Structure HTML d'un résultat :
// <a rel="https://...cache/thb_couv/Couv_XXXX.jpg" href="/BD-Serie-Tome-N-Titre-ID.html">
//   <span class="serie">Série</span>
//   <span class="num">#1</span>
//   <span class="titre">Titre album</span>
//   <span class="dl">07/1961</span>
// </a>
function parseResults(data, limit) {
  const $ = cheerio.load(data);
  const results = [];

  $('a[href*="bedetheque.com/BD-"]').each((i, el) => {
    if (results.length >= limit) return false;
    const $el   = $(el);
    const href  = $el.attr('href') || '';

    // Couverture = attribut rel du lien (thumbnail)
    const coverUrl  = $el.attr('rel') || '';

    // Métadonnées dans les spans
    const series    = $el.find('.serie').text().trim();
    const title     = $el.find('.titre').text().trim();
    const tomeStr   = $el.find('.num').text().replace('#', '').trim();
    const tome      = tomeStr ? parseInt(tomeStr) : null;
    const dlStr     = $el.find('.dl').text().trim();
    const yearMatch = dlStr.match(/\d{4}/);
    const year      = yearMatch ? parseInt(yearMatch[0]) : null;

    // ID BDGest depuis l'URL : /BD-Serie-Tome-N-Titre-ID.html
    const idMatch  = href.match(/-(\d+)\.html$/);
    const bdgestId = idMatch ? idMatch[1] : null;

    // Fallback titre/série depuis l'URL
    const urlMatch = href.match(/\/BD-(.+)-Tome-\d+-(.+)-\d+\.html/);

    if (title || series || href) {
      results.push({
        bdgest_id:   bdgestId,
        bdgest_url:  href || null,
        title:       title  || (urlMatch ? urlMatch[2].replace(/-/g, ' ') : ''),
        series:      series || (urlMatch ? urlMatch[1].replace(/-/g, ' ') : null),
        tome,
        author:      null,
        illustrator: null,
        publisher:   null,
        year,
        cover_url:   coverUrl || null,
      });
    }
  });

  return results;
}

// ── Recherche par titre/série ─────────────────────────────────
async function search(query, credentials) {
  const cacheKey = 'search:' + query;
  const cached = cache.get(cacheKey);
  if (cached) return cached;

  let client, jar;
  if (credentials) {
    ({ client, jar } = await getAuthenticatedClient(credentials.login, credentials.password));
  } else {
    ({ client, jar } = createClient());
  }

  try {
    // Le csrf doit venir du cookie (pas du formulaire)
    const cookies    = await jar.getCookies(BDT_BASE);
    const csrfCookie = cookies.find(c => c.key === 'csrf_cookie_bel');
    const csrf       = csrfCookie ? csrfCookie.value : '';

    const { data } = await client.get(SEARCH_ALBUMS, {
      params: {
        RechIdSerie: '', RechIdAuteur: '',
        csrf_token_bel: csrf,
        RechSerie:      query,
        RechTitre:      '',
        RechEditeur:    '', RechCollection: '',
        RechStyle:      '', RechAuteur:     '', RechISBN:  '',
        RechParution:   '', RechOrigine:    '', RechLangue: '',
        RechMotCle:     '', RechDLDeb:      '', RechDLFin: '',
        RechCoteMin:    '', RechCoteMax:    '', RechEO:    '0',
      },
      headers: { 'Referer': BDT_BASE + '/search' },
    });

    const results = parseResults(data, 20);
    console.log('[BDGest] Recherche "' + query + '" -> ' + results.length + ' resultats');
    cache.set(cacheKey, results);
    return results;

  } catch (err) {
    console.error('[BDGest] Erreur recherche:', err.message);
    throw new Error('Erreur lors de la recherche sur Bedetheque.');
  }
}

// ── Recherche par EAN/ISBN ────────────────────────────────────
async function searchByISBN(ean, credentials) {
  const cacheKey = 'isbn:' + ean;
  const cached = cache.get(cacheKey);
  if (cached) return cached;

  let client, jar;
  if (credentials) {
    ({ client, jar } = await getAuthenticatedClient(credentials.login, credentials.password));
  } else {
    ({ client, jar } = createClient());
  }

  try {
    const cookies    = await jar.getCookies(BDT_BASE);
    const csrfCookie = cookies.find(c => c.key === 'csrf_cookie_bel');
    const csrf       = csrfCookie ? csrfCookie.value : '';

    const { data } = await client.get(SEARCH_ALBUMS, {
      params: {
        RechIdSerie: '', RechIdAuteur: '',
        csrf_token_bel: csrf,
        RechSerie:    '', RechTitre:   '', RechEditeur: '', RechCollection: '',
        RechStyle:    '', RechAuteur:  '', RechISBN:    ean,
        RechParution: '', RechOrigine: '', RechLangue:  '',
        RechMotCle:   '', RechDLDeb:   '', RechDLFin:   '',
        RechCoteMin:  '', RechCoteMax: '', RechEO:      '0',
      },
      headers: { 'Referer': BDT_BASE + '/search' },
    });

    const results = parseResults(data, 1);
    const result  = results.length > 0 ? { ...results[0], ean } : null;

    if (result) cache.set(cacheKey, result);
    console.log('[BDGest] ISBN "' + ean + '" -> ' + (result ? result.title : 'non trouve'));
    return result;

  } catch (err) {
    console.error('[BDGest] Erreur ISBN:', err.message);
    throw new Error('Erreur lors de la recherche par ISBN.');
  }
}

// ── Fiche complète ────────────────────────────────────────────
async function getAlbumDetails(bdgestId, credentials, albumUrl) {
  const cacheKey = 'album:' + bdgestId;
  const cached = cache.get(cacheKey);
  if (cached) return cached;

  let client;
  if (credentials) {
    ({ client } = await getAuthenticatedClient(credentials.login, credentials.password));
  } else {
    ({ client } = createClient());
  }

  const url = albumUrl
    ? (albumUrl.startsWith('http') ? albumUrl : BDT_BASE + albumUrl)
    : BDT_BASE + '/album-' + bdgestId + '.html';

  try {
    const { data } = await client.get(url);
    const $ = cheerio.load(data);

    const author      = $('.scenariste a').first().text().trim();
    const illustrator = $('.dessinateur a').first().text().trim();
    const title       = $('h1, .titre-album').first().text().trim();

    // Si la page ne contient aucune donnée utile (URL invalide / page 404 HTML)
    if (!author && !illustrator && !title) {
      console.warn('[BDGest] Fiche vide pour', url, '— URL invalide ou accès refusé');
      return null;
    }

    const coverSrc = $('.couverture img, .album-cover img').first().attr('src');
    const details = {
      bdgest_id:   bdgestId,
      title,
      series:      $('.serie a, .titre-serie a').first().text().trim() || null,
      tome:        parseInt($('.num-tome, .tome').first().text().trim()) || null,
      author:      author || null,
      illustrator: illustrator || null,
      publisher:   $('.editeur a, .editeur').first().text().trim() || null,
      year:        parseInt($('.parution, .annee').first().text().trim().match(/\d{4}/)?.[0]) || null,
      genre:       $('.style a, .genre a').first().text().trim() || null,
      ean:         $('.ean, .isbn').first().text().trim().replace(/\D/g, '') || null,
      cover_url:   coverSrc ? (coverSrc.startsWith('http') ? coverSrc : BDT_BASE + coverSrc) : null,
      synopsis:    $('.synopsis, .resume').first().text().trim() || null,
    };

    cache.set(cacheKey, details);
    return details;
  } catch (err) {
    console.error('[BDGest] Erreur fiche:', url, err.message);
    return null;
  }
}

function invalidateSession() {
  sessionClient = null;
  sessionJar    = null;
  sessionExpiry = 0;
}

module.exports = { search, searchByISBN, getAlbumDetails, invalidateSession };
