import { useState, useRef, useCallback } from 'react'
import { api } from '../lib/api'
import { useToast } from '../hooks/useToast'

const SOURCES = [
  { value: 'googlebooks',  label: 'Google Books',  external: false },
  { value: 'openlibrary',  label: 'Open Library',  external: false },
  { value: 'bdgest',       label: 'BDGest',         external: false },
  { value: 'amazon',       label: 'Amazon',         external: true,  url: q => `https://www.amazon.fr/s?k=${encodeURIComponent(q)}&i=stripbooks` },
]

function SearchResultItem({ result }) {
  const toast = useToast()
  const [inCol,  setInCol]  = useState(result.in_collection)
  const [inWish, setInWish] = useState(result.in_wishlist)
  const [addingCol,  setAddingCol]  = useState(false)
  const [addingWish, setAddingWish] = useState(false)

  async function fetchDetails() {
    if (!result.bdgest_id || result.bdgest_id.startsWith('ol:')) return result
    try { return { ...result, ...await api.get(`/search/album/${encodeURIComponent(result.bdgest_id)}`) } }
    catch { return result }
  }

  async function addToCollection() {
    setAddingCol(true)
    try {
      const d = await fetchDetails()
      await api.post('/books', { bdgest_id: d.bdgest_id, title: d.title, series: d.series, tome: d.tome, author: d.author, illustrator: d.illustrator, publisher: d.publisher, year: d.year, genre: d.genre, ean: d.ean, cover_url: d.cover_url, synopsis: d.synopsis })
      setInCol(true); toast(`"${result.title}" ajouté à la collection`)
    } catch (e) { toast(e.message === 'Cet album est déjà dans votre collection' ? 'Déjà dans votre collection' : e.message, 'error') }
    finally { setAddingCol(false) }
  }

  async function addToWishlist() {
    setAddingWish(true)
    try {
      const d = await fetchDetails()
      await api.post('/wishlist', { bdgest_id: d.bdgest_id, title: d.title, series: d.series, tome: d.tome, author: d.author, publisher: d.publisher, year: d.year, cover_url: d.cover_url })
      setInWish(true); toast(`"${result.title}" ajouté aux souhaits`)
    } catch (e) { toast(e.message, 'error') }
    finally { setAddingWish(false) }
  }

  return (
    <div className="search-result">
      {result.cover_url
        ? <img className="search-result-cover" src={result.cover_url} alt={result.title} loading="lazy" />
        : <div className="search-result-cover" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '1.5rem' }}>📖</div>}
      <div className="search-result-body">
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: '8px', flexWrap: 'wrap' }}>
          <span className="search-result-title">{result.title}</span>
          {inCol  && <span className="badge badge-collection">✓ Collection</span>}
          {inWish && <span className="badge badge-wishlist">♥ Souhaits</span>}
        </div>
        <div className="search-result-meta">
          {result.series && <span>{result.series}{result.tome ? ` T${result.tome}` : ''}</span>}
          {result.author && <span> · {result.author}</span>}
          {result.year   && <span> · {result.year}</span>}
        </div>
        <div className="search-result-actions">
          {!inCol && (
            <button className="btn btn-primary btn-sm" onClick={addToCollection} disabled={addingCol}>
              {addingCol ? <span className="spinner" style={{ width: 12, height: 12, borderWidth: 1.5 }} /> : '+ Collection'}
            </button>
          )}
          {!inWish && !inCol && (
            <button className="btn btn-ghost btn-sm" onClick={addToWishlist} disabled={addingWish}>
              {addingWish ? <span className="spinner" style={{ width: 12, height: 12, borderWidth: 1.5 }} /> : '♥ Souhaits'}
            </button>
          )}
        </div>
      </div>
    </div>
  )
}

export default function SearchPage() {
  const toast = useToast()
  const [query,       setQuery]       = useState('')
  const [source,      setSource]      = useState('bdgest')
  const [results,     setResults]     = useState([])
  const [loading,     setLoading]     = useState(false)
  const [loadingMore, setLoadingMore] = useState(false)
  const [searched,    setSearched]    = useState(false)
  const [startIndex,  setStartIndex]  = useState(0)
  const [hasMore,     setHasMore]     = useState(false)
  const inputRef    = useRef(null)
  const debounceRef = useRef(null)

  const currentSource = SOURCES.find(s => s.value === source)

  const doSearch = useCallback(async (q, src) => {
    if (!q.trim() || q.trim().length < 2) { setResults([]); setSearched(false); setStartIndex(0); setHasMore(false); return }
    const sourceDef = SOURCES.find(s => s.value === src)
    if (sourceDef?.external) {
      window.open(sourceDef.url(q.trim()), '_blank', 'noopener')
      return
    }
    setLoading(true); setSearched(true); setStartIndex(0)
    try {
      const { results: res, totalItems } = await api.get(`/search?q=${encodeURIComponent(q.trim())}&source=${src}`)
      setResults(res)
      setHasMore(res.length > 0 && res.length < totalItems)
    }
    catch (e) { toast(e.message, 'error'); setResults([]) }
    finally { setLoading(false) }
  }, [])

  async function loadMore() {
    const next = startIndex + 40
    setLoadingMore(true)
    try {
      const { results: res, totalItems } = await api.get(`/search?q=${encodeURIComponent(query.trim())}&source=${source}&startIndex=${next}`)
      setResults(prev => [...prev, ...res])
      setStartIndex(next)
      setHasMore(res.length > 0 && (next + res.length) < totalItems)
    }
    catch (e) { toast(e.message, 'error') }
    finally { setLoadingMore(false) }
  }

  function handleChange(e) {
    const val = e.target.value; setQuery(val)
    clearTimeout(debounceRef.current)
    if (!currentSource?.external)
      debounceRef.current = setTimeout(() => doSearch(val, source), 600)
  }

  function handleSourceChange(e) {
    const val = e.target.value
    setSource(val)
    setResults([]); setSearched(false); setStartIndex(0); setHasMore(false)
  }

  function handleSubmit(e) { e.preventDefault(); clearTimeout(debounceRef.current); doSearch(query, source) }

  return (
    <>
      <div className="section-header"><h1 className="section-title">Rechercher une BD</h1></div>

      <form onSubmit={handleSubmit} style={{ marginBottom: '24px' }}>
        <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
          <div className="search-bar" style={{ flex: 1 }}>
            <span className="search-bar-icon">⌕</span>
            <input ref={inputRef} className="input" placeholder="Titre, série, auteur…" value={query} onChange={handleChange} autoFocus />
            {query && <button type="button" className="search-bar-clear" onClick={() => { setQuery(''); setResults([]); setSearched(false); inputRef.current?.focus() }}>✕</button>}
          </div>
          <select
            value={source}
            onChange={handleSourceChange}
            className="input"
            style={{ width: 'auto', flexShrink: 0, fontSize: '0.85rem', paddingRight: '28px' }}
          >
            {SOURCES.map(s => <option key={s.value} value={s.value}>{s.label}</option>)}
          </select>
        </div>
        {currentSource?.external && query.trim().length >= 2 && (
          <p style={{ fontSize: '0.8rem', color: 'var(--text3)', marginTop: '8px' }}>
            {currentSource.label} ne dispose pas d'API publique — la recherche ouvrira un nouvel onglet.
          </p>
        )}
      </form>

      {loading && (
        <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text3)' }}>
          <div className="spinner" />
          <p style={{ marginTop: '12px', fontSize: '0.85rem' }}>Recherche en cours…</p>
        </div>
      )}

      {!loading && searched && results.length === 0 && (
        <div className="empty-state">
          <div className="empty-state-icon">🔍</div>
          <h3>Aucun résultat</h3>
          <p>Essayez d'autres termes ou vérifiez l'orthographe.</p>
        </div>
      )}

      {!loading && results.length > 0 && (
        <>
          <p style={{ fontSize: '0.8rem', color: 'var(--text3)', marginBottom: '12px' }}>
            {results.length} résultat{results.length !== 1 ? 's' : ''} affiché{results.length !== 1 ? 's' : ''} — {currentSource?.label}
          </p>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
            {results.map((r, i) => <SearchResultItem key={r.bdgest_id || i} result={r} />)}
          </div>
          {hasMore && (
            <div style={{ textAlign: 'center', marginTop: '20px' }}>
              <button className="btn btn-ghost" onClick={loadMore} disabled={loadingMore}>
                {loadingMore ? <span className="spinner" style={{ width: 14, height: 14, borderWidth: 1.5 }} /> : 'Voir plus'}
              </button>
            </div>
          )}
        </>
      )}

      {!searched && (
        <div className="empty-state" style={{ paddingTop: '40px' }}>
          <div className="empty-state-icon">📖</div>
          <h3>Trouvez vos bandes dessinées</h3>
          <p>Tapez un titre, le nom d'une série ou d'un auteur.</p>
        </div>
      )}
    </>
  )
}
