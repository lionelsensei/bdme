import { useState, useEffect } from 'react'
import { api } from '../lib/api'
import { useToast } from '../hooks/useToast'

function WishlistItem({ item, onDelete, onMove }) {
  const [moving,   setMoving]   = useState(false)
  const [deleting, setDeleting] = useState(false)

  async function handleMove()   { setMoving(true);   try { await onMove(item.id)   } finally { setMoving(false)   } }
  async function handleDelete() { setDeleting(true); try { await onDelete(item.id) } finally { setDeleting(false) } }

  return (
    <div className="wishlist-item">
      {item.cover_url
        ? <img className="wishlist-cover" src={item.cover_url} alt={item.title} loading="lazy" />
        : <div className="wishlist-cover" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'var(--bg4)', borderRadius: 3 }}>📖</div>}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: '0.9rem', color: 'var(--text)' }}>{item.title}</div>
        <div style={{ fontSize: '0.75rem', color: 'var(--text3)', marginTop: '2px' }}>
          {[item.series && `${item.series}${item.tome ? ` T${item.tome}` : ''}`, item.author, item.year].filter(Boolean).join(' · ')}
        </div>
        <div style={{ display: 'flex', gap: '6px', marginTop: '8px' }}>
          <button className="btn btn-primary btn-sm" onClick={handleMove} disabled={moving}>
            {moving ? <span className="spinner" style={{ width: 12, height: 12, borderWidth: 1.5 }} /> : '→ Collection'}
          </button>
          <button className="btn btn-icon btn-sm" onClick={handleDelete} disabled={deleting} style={{ color: 'var(--red)' }}>✕</button>
        </div>
      </div>
    </div>
  )
}

export default function WishlistPage() {
  const toast = useToast()
  const [items,   setItems]   = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    api.get('/wishlist').then(setItems).catch(e => toast(e.message, 'error')).finally(() => setLoading(false))
  }, [])

  async function handleDelete(id) {
    try { await api.delete(`/wishlist/${id}`); setItems(i => i.filter(x => x.id !== id)); toast('Supprimé de la liste de souhaits') }
    catch (e) { toast(e.message, 'error') }
  }

  async function handleMove(id) {
    try { await api.post(`/wishlist/${id}/move-to-collection`, {}); setItems(i => i.filter(x => x.id !== id)); toast('Ajouté à votre collection !') }
    catch (e) { toast(e.message, 'error') }
  }

  return (
    <>
      <div className="section-header">
        <div style={{ display: 'flex', alignItems: 'baseline', gap: '12px' }}>
          <h1 className="section-title">Liste de souhaits</h1>
          <span style={{ fontSize: '0.85rem', color: 'var(--text3)' }}>{items.length} album{items.length !== 1 ? 's' : ''}</span>
        </div>
      </div>

      {loading ? (
        <div style={{ textAlign: 'center', padding: '60px' }}><div className="spinner" /></div>
      ) : items.length === 0 ? (
        <div className="empty-state">
          <div className="empty-state-icon">♥</div>
          <h3>Aucun souhait</h3>
          <p>Ajoutez des albums depuis la recherche pour les retrouver ici.</p>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
          {items.map(item => <WishlistItem key={item.id} item={item} onDelete={handleDelete} onMove={handleMove} />)}
        </div>
      )}
    </>
  )
}
