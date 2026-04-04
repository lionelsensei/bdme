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

function SeriesFolderCard({ seriesName, books, onClick }) {
  const covers = books.map(b => b.cover_url).filter(Boolean).slice(0, 3)
  const label  = seriesName === '—' ? 'Sans série' : seriesName

  return (
    <div className="book-card" onClick={onClick}>
      {/* Effet empilement */}
      {covers[2] && (
        <img src={covers[2]} alt="" aria-hidden style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover', transform: 'rotate(4deg) scale(0.91)', transformOrigin: 'bottom center', borderRadius: 'var(--radius-sm)', opacity: 0.6 }} />
      )}
      {covers[1] && (
        <img src={covers[1]} alt="" aria-hidden style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover', transform: 'rotate(2deg) scale(0.95)', transformOrigin: 'bottom center', borderRadius: 'var(--radius-sm)', opacity: 0.8 }} />
      )}
      {covers[0]
        ? <img src={covers[0]} alt={label} style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }} />
        : <div className="book-card-placeholder">{label}</div>
      }
      <div className="book-card-overlay">
        <div className="book-card-title">{label}</div>
      </div>
      {/* Pastille nombre d'albums */}
      <div style={{ position: 'absolute', top: 8, left: 8, background: 'var(--accent)', color: '#0f0f11', fontSize: '0.62rem', fontWeight: 700, borderRadius: '20px', padding: '2px 7px', fontFamily: 'var(--font-sans)', lineHeight: 1.6 }}>
        {books.length}
      </div>
    </div>
  )
}

function SeriesFolderRow({ seriesName, books, onClick }) {
  const cover = books.find(b => b.cover_url)?.cover_url
  const label = seriesName === '—' ? 'Albums sans série' : seriesName

  return (
    <div className="book-row" onClick={onClick}>
      {cover
        ? <img className="book-row-cover" src={cover} alt={label} />
        : <div className="book-row-cover" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '1.2rem' }}>📚</div>
      }
      <div className="book-row-info">
        <div className="book-row-title">{label}</div>
        <div className="book-row-meta">{books.length} album{books.length !== 1 ? 's' : ''}</div>
      </div>
      <span style={{ fontSize: '1rem', color: 'var(--text3)', flexShrink: 0 }}>›</span>
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
  const [openSeries,     setOpenSeries]     = useState(null)  // clé de la série ouverte

  useEffect(() => {
    api.get('/books').then(setBooks).catch(e => toast(e.message, 'error')).finally(() => setLoading(false))
  }, [])

  // Quand on désactive le groupement ou qu'on filtre, on ferme le dossier ouvert
  useEffect(() => { setOpenSeries(null) }, [groupBySeries, filter, search])

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

  const openSeriesBooks = useMemo(() => {
    const list = grouped?.find(([key]) => key === openSeries)?.[1] ?? []
    return [...list].sort((a, b) => {
      const ta = a.tome != null ? Number(a.tome) : Infinity
      const tb = b.tome != null ? Number(b.tome) : Infinity
      return ta - tb
    })
  }, [grouped, openSeries])

  function handleUpdate(updated) { setBooks(bs => bs.map(b => b.id === updated.id ? updated : b)); setSelected(updated) }
  function handleDelete(id)      { setBooks(bs => bs.filter(b => b.id !== id)); setSelected(null) }

  const renderBooks = (list) => view === 'grid'
    ? <div className="books-grid">{list.map(b => <BookCardGrid key={b.id} book={b} onClick={setSelected} />)}</div>
    : <div className="books-list">{list.map(b => <BookCardRow key={b.id} book={b} onClick={setSelected} />)}</div>

  const renderFolders = () => view === 'grid'
    ? <div className="books-grid">{grouped.map(([key, books]) => <SeriesFolderCard key={key} seriesName={key} books={books} onClick={() => setOpenSeries(key)} />)}</div>
    : <div className="books-list">{grouped.map(([key, books]) => <SeriesFolderRow key={key} seriesName={key} books={books} onClick={() => setOpenSeries(key)} />)}</div>

  return (
    <>
      <div className="section-header">
        <div style={{ display: 'flex', alignItems: 'baseline', gap: '12px' }}>
          <h1 className="section-title">Ma collection</h1>
          <span style={{ fontSize: '0.85rem', color: 'var(--text3)' }}>{books.length} album{books.length !== 1 ? 's' : ''}</span>
        </div>
        <div className="section-actions">
          <div className="view-toggle">
            <button className={`view-toggle-btn${groupBySeries ? ' active' : ''}`} onClick={() => setGroupBySeries(g => !g)} title="Regrouper par série">
              ⊟ Séries
            </button>
          </div>
          <div className="view-toggle">
            <button className={`view-toggle-btn${view === 'grid' ? ' active' : ''}`} onClick={() => setView('grid')}>⊞ Grille</button>
            <button className={`view-toggle-btn${view === 'list' ? ' active' : ''}`} onClick={() => setView('list')}>≡ Liste</button>
          </div>
        </div>
      </div>

      {/* Fil d'ariane quand un dossier est ouvert */}
      {openSeries && (
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '16px' }}>
          <button className="btn btn-ghost btn-sm" onClick={() => setOpenSeries(null)}>← Séries</button>
          <span style={{ fontSize: '0.85rem', color: 'var(--text2)', fontFamily: 'var(--font-serif)' }}>
            {openSeries === '—' ? 'Albums sans série' : openSeries}
          </span>
          <span style={{ fontSize: '0.8rem', color: 'var(--text3)' }}>{openSeriesBooks.length} album{openSeriesBooks.length !== 1 ? 's' : ''}</span>
        </div>
      )}

      {!openSeries && (
        <>
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
        </>
      )}

      {loading ? (
        <div style={{ textAlign: 'center', padding: '60px' }}><div className="spinner" /></div>
      ) : openSeries ? (
        renderBooks(openSeriesBooks)
      ) : filtered.length === 0 ? (
        <div className="empty-state">
          <div className="empty-state-icon">📚</div>
          <h3>{books.length === 0 ? 'Collection vide' : 'Aucun résultat'}</h3>
          <p>{books.length === 0 ? 'Commencez par rechercher des albums à ajouter.' : 'Modifiez votre recherche ou vos filtres.'}</p>
        </div>
      ) : grouped ? renderFolders() : renderBooks(filtered)}

      {selected && <BookModal book={selected} onClose={() => setSelected(null)} onUpdate={handleUpdate} onDelete={handleDelete} allSeries={[...new Set(books.map(b => b.series).filter(Boolean))].sort((a, b) => a.localeCompare(b, 'fr', { sensitivity: 'base' }))} />}
    </>
  )
}
