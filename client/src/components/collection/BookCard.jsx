import { useState, useEffect } from 'react'
import { api } from '../../lib/api'
import { useToast } from '../../hooks/useToast'

const STATUS_LABELS = { unread: 'Non lu', reading: 'En cours', read: 'Lu' }
const STATUS_CLASS  = { unread: 'status-unread', reading: 'status-reading', read: 'status-read' }
const STATUS_COLORS = { unread: 'var(--text3)', reading: 'var(--accent)', read: 'var(--green)' }
const STATUS_BG     = { unread: 'rgba(94,90,84,0.15)', reading: 'rgba(232,201,122,0.12)', read: 'rgba(92,186,138,0.12)' }
const STATUS_BORDER = { unread: 'rgba(94,90,84,0.3)', reading: 'rgba(232,201,122,0.3)', read: 'rgba(92,186,138,0.3)' }

export function BookCardGrid({ book, onClick }) {
  return (
    <div className="book-card" onClick={() => onClick(book)}>
      {book.cover_url
        ? <img src={book.cover_url} alt={book.title} loading="lazy" />
        : <div className="book-card-placeholder">{book.title}</div>}
      <div className="book-card-overlay">
        <div className="book-card-title">{book.title}</div>
      </div>
      <div className={`book-card-status ${STATUS_CLASS[book.read_status]}`} />
    </div>
  )
}

export function BookCardRow({ book, onClick }) {
  return (
    <div className="book-row" onClick={() => onClick(book)}>
      {book.cover_url
        ? <img className="book-row-cover" src={book.cover_url} alt={book.title} loading="lazy" />
        : <div className="book-row-cover" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>📖</div>}
      <div className="book-row-info">
        <div className="book-row-title">{book.title}</div>
        <div className="book-row-meta">
          {[book.series && `${book.series}${book.tome ? ` T${book.tome}` : ''}`, book.author, book.year].filter(Boolean).join(' · ')}
        </div>
      </div>
      <div className={`book-row-status ${STATUS_CLASS[book.read_status]}`} />
      <span style={{ fontSize: '0.75rem', color: 'var(--text3)', flexShrink: 0 }}>{STATUS_LABELS[book.read_status]}</span>
    </div>
  )
}

export function BookModal({ book, onClose, onUpdate, onDelete, allSeries = [] }) {
  const toast = useToast()
  const [status,        setStatus]        = useState(book.read_status)
  const [saving,        setSaving]        = useState(false)
  const [confirmDelete, setConfirmDelete] = useState(false)
  const [data,          setData]          = useState(book)
  const [editingSeries, setEditingSeries] = useState(false)
  const [seriesInput,   setSeriesInput]   = useState(book.series || '')

  useEffect(() => {
    if (!book.bdgest_id || (book.author && book.cover_url)) return

    async function enrich() {
      const fields = ['author', 'illustrator', 'publisher', 'genre', 'synopsis', 'ean', 'cover_url']
      let details = null
      try { details = await api.get(`/search/album/${encodeURIComponent(book.bdgest_id)}`) } catch {}
      if (!details) return

      const enriched = {}
      for (const f of fields) { if (details[f]) enriched[f] = details[f] }
      if (Object.keys(enriched).length === 0) return

      setData(d => ({ ...d, ...enriched }))

      const patch = {}
      for (const f of fields) { if (details[f] && !book[f]) patch[f] = details[f] }
      if (Object.keys(patch).length === 0) return
      const updated = await api.patch(`/books/${book.id}`, patch)
      onUpdate(updated)
    }

    enrich().catch(() => {})
  }, [book.bdgest_id])

  async function saveStatus(val) {
    setStatus(val); setSaving(true)
    try {
      onUpdate(await api.patch(`/books/${book.id}`, { read_status: val }))
      toast('Statut mis à jour')
    } catch (e) { toast(e.message, 'error') }
    finally { setSaving(false) }
  }

  async function saveSeries() {
    const newSeries = seriesInput.trim() || null
    try {
      const updated = await api.patch(`/books/${book.id}`, { series: newSeries })
      setData(d => ({ ...d, series: newSeries }))
      onUpdate({ ...updated, series: newSeries })
      setEditingSeries(false)
      toast('Série mise à jour')
    } catch (e) { toast(e.message, 'error') }
  }

  async function handleDelete() {
    try {
      await api.delete(`/books/${book.id}`)
      onDelete(book.id); onClose()
      toast('Album supprimé de la collection')
    } catch (e) { toast(e.message, 'error') }
  }

  return (
    <div className="modal-backdrop" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal">
        <div className="modal-header">
          <div style={{ flex: 1, minWidth: 0 }}>
            <h2 className="modal-title">{data.title}</h2>
            {!editingSeries ? (
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: '4px' }}>
                <span style={{ fontSize: '0.85rem', color: 'var(--text3)' }}>
                  {data.series ? `${data.series}${data.tome ? ` — Tome ${data.tome}` : ''}` : <em style={{ opacity: 0.5 }}>Sans série</em>}
                </span>
                <button onClick={() => { setSeriesInput(data.series || ''); setEditingSeries(true) }} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text3)', fontSize: '0.75rem', padding: '0 4px', opacity: 0.6 }} title="Modifier la série">✎</button>
              </div>
            ) : (
              <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginTop: '6px' }}>
                <input
                  list="series-list"
                  className="input"
                  value={seriesInput}
                  onChange={e => setSeriesInput(e.target.value)}
                  placeholder="Nom de la série…"
                  style={{ fontSize: '0.85rem', padding: '4px 8px', height: 'auto' }}
                  autoFocus
                />
                <datalist id="series-list">
                  {allSeries.map(s => <option key={s} value={s} />)}
                </datalist>
                <button className="btn btn-primary btn-sm" onClick={saveSeries}>OK</button>
                <button className="btn btn-ghost btn-sm" onClick={() => setEditingSeries(false)}>✕</button>
              </div>
            )}
          </div>
          <button className="btn btn-icon" onClick={onClose} style={{ fontSize: '1.2rem', color: 'var(--text2)' }}>✕</button>
        </div>

        <div style={{ display: 'flex', gap: '16px', marginBottom: '20px' }}>
          {data.cover_url && <img src={data.cover_url} alt={data.title} style={{ width: 90, height: 135, objectFit: 'cover', borderRadius: 6, flexShrink: 0 }} />}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
            {data.tome != null && (
              <div>
                <span style={{ fontSize: '0.72rem', color: 'var(--text3)' }}>Tome</span>
                <div style={{ fontSize: '1.1rem', fontFamily: 'var(--font-serif)', color: 'var(--text)' }}>#{data.tome}</div>
              </div>
            )}
            {(data.author || data.illustrator) && (
              <div>
                <span style={{ fontSize: '0.72rem', color: 'var(--text3)' }}>Auteur{data.author && data.illustrator && data.author !== data.illustrator ? 's' : ''}</span>
                {data.author && <div style={{ fontSize: '0.875rem', color: 'var(--text2)' }}>{data.author} <span style={{ fontSize: '0.72rem', color: 'var(--text3)' }}>(scénario)</span></div>}
                {data.illustrator && data.illustrator !== data.author && <div style={{ fontSize: '0.875rem', color: 'var(--text2)' }}>{data.illustrator} <span style={{ fontSize: '0.72rem', color: 'var(--text3)' }}>(dessin)</span></div>}
              </div>
            )}
            {[['Éditeur', data.publisher], ['Année', data.year], ['Genre', data.genre]].filter(([, v]) => v).map(([k, v]) => (
              <div key={k}>
                <span style={{ fontSize: '0.72rem', color: 'var(--text3)' }}>{k}</span>
                <div style={{ fontSize: '0.875rem', color: 'var(--text2)' }}>{v}</div>
              </div>
            ))}
          </div>
        </div>

        {data.synopsis && <p style={{ fontSize: '0.85rem', color: 'var(--text2)', marginBottom: '20px', lineHeight: 1.6 }} dangerouslySetInnerHTML={{ __html: data.synopsis }} />}

        <div style={{ marginBottom: '20px' }}>
          <span className="form-label" style={{ display: 'block', marginBottom: '10px' }}>Statut de lecture</span>
          <div style={{ display: 'flex', gap: '8px' }}>
            {(['unread', 'reading', 'read']).map(s => (
              <button
                key={s}
                onClick={() => status !== s && saveStatus(s)}
                disabled={saving}
                style={{
                  flex: 1,
                  padding: '10px 8px',
                  borderRadius: 'var(--radius-sm)',
                  border: `1px solid ${status === s ? STATUS_BORDER[s] : 'var(--border)'}`,
                  background: status === s ? STATUS_BG[s] : 'transparent',
                  color: status === s ? STATUS_COLORS[s] : 'var(--text3)',
                  fontFamily: 'var(--font-sans)',
                  fontSize: '0.82rem',
                  cursor: status === s ? 'default' : 'pointer',
                  transition: 'all 0.15s',
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                  gap: '6px',
                }}
              >
                <span style={{ width: 8, height: 8, borderRadius: '50%', background: STATUS_COLORS[s], display: 'block', opacity: status === s ? 1 : 0.4 }} />
                {STATUS_LABELS[s]}
              </button>
            ))}
          </div>
        </div>

        <div style={{ borderTop: '1px solid var(--border)', paddingTop: '16px' }}>
          {!confirmDelete
            ? <button className="btn btn-danger btn-sm" onClick={() => setConfirmDelete(true)}>Supprimer de ma collection</button>
            : <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                <span style={{ fontSize: '0.85rem', color: 'var(--text2)' }}>Confirmer ?</span>
                <button className="btn btn-danger btn-sm" onClick={handleDelete}>Oui, supprimer</button>
                <button className="btn btn-ghost btn-sm" onClick={() => setConfirmDelete(false)}>Annuler</button>
              </div>}
        </div>
      </div>
    </div>
  )
}
