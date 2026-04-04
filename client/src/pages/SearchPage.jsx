import { useState, useRef, useCallback } from 'react'
import { api } from '../lib/api'
import { useToast } from '../hooks/useToast'

function SearchResultItem({ result }) {
  const toast = useToast()
  const [inCol,  setInCol]  = useState(result.in_collection)
  const [inWish, setInWish] = useState(result.in_wishlist)
  const [addingCol,  setAddingCol]  = useState(false)
  const [addingWish, setAddingWish] = useState(false)

  async function fetchDetails() {
    if (!result.bdgest_id) return result
    try { return { ...result, ...await api.get(`/search/album/${result.bdgest_id}`) } }
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
  const [query,    setQuery]    = useState('')
  const [results,  setResults]  = useState([])
  const [loading,  setLoading]  = useState(false)
  const [searched, setSearched] = useState(false)
  const inputRef   = useRef(null)
  const debounceRef = useRef(null)

  const doSearch = useCallback(async (q) => {
    if (!q.trim() || q.trim().length < 2) { setResults([]); setSearched(false); return }
    setLoading(true); setSearched(true)
    try { setResults(await api.get(`/search?q=${encodeURIComponent(q.trim())}`)) }
    catch (e) { toast(e.message, 'error'); setResults([]) }
    finally { setLoading(false) }
  }, [])

  function handleChange(e) {
    const val = e.target.value; setQuery(val)
    clearTimeout(debounceRef.current)
    debounceRef.current = setTimeout(() => doSearch(val), 600)
  }

  function handleSubmit(e) { e.preventDefault(); clearTimeout(debounceRef.current); doSearch(query) }

  return (
    <>
      <div className="section-header"><h1 className="section-title">Rechercher une BD</h1></div>

      <form onSubmit={handleSubmit} style={{ marginBottom: '24px' }}>
        <div className="search-bar">
          <span className="search-bar-icon">⌕</span>
          <input ref={inputRef} className="input" placeholder="Titre, série, auteur… (source : BDGest)" value={query} onChange={handleChange} autoFocus />
          {query && <button type="button" className="search-bar-clear" onClick={() => { setQuery(''); setResults([]); setSearched(false); inputRef.current?.focus() }}>✕</button>}
        </div>
      </form>

      {loading && (
        <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text3)' }}>
          <div className="spinner" />
          <p style={{ marginTop: '12px', fontSize: '0.85rem' }}>Recherche sur BDGest…</p>
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
            {results.length} résultat{results.length !== 1 ? 's' : ''} depuis BDGest
          </p>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
            {results.map((r, i) => <SearchResultItem key={r.bdgest_id || i} result={r} />)}
          </div>
        </>
      )}

      {!searched && (
        <div className="empty-state" style={{ paddingTop: '40px' }}>
          <div className="empty-state-icon">📖</div>
          <h3>Trouvez vos bandes dessinées</h3>
          <p>Tapez un titre, le nom d'une série ou d'un auteur.<br />Les résultats viennent de BDGest.com.</p>
        </div>
      )}
    </>
  )
}
