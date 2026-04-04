import { useState, useEffect, useMemo } from 'react'
import { api } from '../lib/api'
import { useToast } from '../hooks/useToast'
import { BookCardGrid, BookCardRow, BookModal } from '../components/collection/BookCard'

const FILTERS = [
  { key: 'all',     label: 'Tout'     },
  { key: 'unread',  label: 'Non lus'  },
  { key: 'reading', label: 'En cours' },
  { key: 'read',    label: 'Lus'      },
]

function SeriesHeader({ name, count }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: '10px', margin: '28px 0 12px', borderBottom: '1px solid var(--border)', paddingBottom: '10px' }}>
      <h2 style={{ fontFamily: 'var(--font-serif)', fontSize: '1.1rem', fontWeight: 400, color: 'var(--text)' }}>
        {name}
      </h2>
      <span style={{ fontSize: '0.7rem', padding: '2px 9px', borderRadius: '20px', background: 'var(--accent-bg)', color: 'var(--accent)', fontFamily: 'var(--font-sans)', flexShrink: 0 }}>
        {count} album{count !== 1 ? 's' : ''}
      </span>
    </div>
  )
}

export default function CollectionPage() {
  const toast = useToast()
  const [books,          setBooks]          = useState([])
  const [loading,        setLoading]        = useState(true)
  const [view,           setView]           = useState('grid')
  const [filter,         setFilter]         = useState('all')
  const [search,         setSearch]         = useState('')
  const [selected,       setSelected]       = useState(null)
  const [groupBySeries,  setGroupBySeries]  = useState(true)

  useEffect(() => {
    api.get('/books').then(setBooks).catch(e => toast(e.message, 'error')).finally(() => setLoading(false))
  }, [])

  const filtered = useMemo(() => books.filter(b => {
    const matchStatus = filter === 'all' || b.read_status === filter
    const q = search.toLowerCase()
    const matchSearch = !q || b.title?.toLowerCase().includes(q) || b.series?.toLowerCase().includes(q) || b.author?.toLowerCase().includes(q)
    return matchStatus && matchSearch
  }), [books, filter, search])

  const grouped = useMemo(() => {
    if (!groupBySeries) return null
    const map = {}
    for (const book of filtered) {
      const key = book.series?.trim() || '—'
      if (!map[key]) map[key] = []
      map[key].push(book)
    }
    return Object.entries(map).sort(([a], [b]) => {
      if (a === '—') return 1
      if (b === '—') return -1
      return a.localeCompare(b, 'fr', { sensitivity: 'base' })
    })
  }, [filtered, groupBySeries])

  function handleUpdate(updated) { setBooks(bs => bs.map(b => b.id === updated.id ? updated : b)); setSelected(updated) }
  function handleDelete(id)      { setBooks(bs => bs.filter(b => b.id !== id)) }

  const renderBooks = (list) => view === 'grid'
    ? <div className="books-grid">{list.map(b => <BookCardGrid key={b.id} book={b} onClick={setSelected} />)}</div>
    : <div className="books-list">{list.map(b => <BookCardRow key={b.id} book={b} onClick={setSelected} />)}</div>

  return (
    <>
      <div className="section-header">
        <div style={{ display: 'flex', alignItems: 'baseline', gap: '12px' }}>
          <h1 className="section-title">Ma collection</h1>
          <span style={{ fontSize: '0.85rem', color: 'var(--text3)' }}>{books.length} album{books.length !== 1 ? 's' : ''}</span>
        </div>
        <div className="section-actions">
          <div className="view-toggle">
            <button
              className={`view-toggle-btn${groupBySeries ? ' active' : ''}`}
              onClick={() => setGroupBySeries(g => !g)}
              title="Regrouper par série"
            >
              ⊟ Séries
            </button>
          </div>
          <div className="view-toggle">
            <button className={`view-toggle-btn${view === 'grid' ? ' active' : ''}`} onClick={() => setView('grid')}>⊞ Grille</button>
            <button className={`view-toggle-btn${view === 'list' ? ' active' : ''}`} onClick={() => setView('list')}>≡ Liste</button>
          </div>
        </div>
      </div>

      <div className="search-bar" style={{ marginBottom: '16px' }}>
        <span className="search-bar-icon">⌕</span>
        <input className="input" placeholder="Rechercher dans ma collection…" value={search} onChange={e => setSearch(e.target.value)} />
        {search && <button className="search-bar-clear" onClick={() => setSearch('')}>✕</button>}
      </div>

      <div className="filter-bar">
        {FILTERS.map(f => (
          <button key={f.key} className={`filter-chip${filter === f.key ? ' active' : ''}`} onClick={() => setFilter(f.key)}>
            {f.label}
            {f.key !== 'all' && <span style={{ opacity: 0.6, marginLeft: '4px' }}>{books.filter(b => b.read_status === f.key).length}</span>}
          </button>
        ))}
      </div>

      {loading ? (
        <div style={{ textAlign: 'center', padding: '60px' }}><div className="spinner" /></div>
      ) : filtered.length === 0 ? (
        <div className="empty-state">
          <div className="empty-state-icon">📚</div>
          <h3>{books.length === 0 ? 'Collection vide' : 'Aucun résultat'}</h3>
          <p>{books.length === 0 ? 'Commencez par rechercher des albums à ajouter.' : 'Modifiez votre recherche ou vos filtres.'}</p>
        </div>
      ) : grouped ? (
        grouped.map(([seriesName, seriesBooks]) => (
          <div key={seriesName}>
            <SeriesHeader name={seriesName === '—' ? 'Albums sans série' : seriesName} count={seriesBooks.length} />
            {renderBooks(seriesBooks)}
          </div>
        ))
      ) : renderBooks(filtered)}

      {selected && <BookModal book={selected} onClose={() => setSelected(null)} onUpdate={handleUpdate} onDelete={handleDelete} />}
    </>
  )
}
