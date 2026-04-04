import { useState, useEffect } from 'react'
import { api } from '../lib/api'
import { useToast } from '../hooks/useToast'
import { useAuth } from '../hooks/useAuth'

function CreateUserModal({ onClose, onCreated }) {
  const toast = useToast()
  const [form, setForm] = useState({ email: '', password: '', display_name: '', role: 'user' })
  const [loading, setLoading] = useState(false)
  const [error,   setError]   = useState('')
  const set = k => e => setForm(f => ({ ...f, [k]: e.target.value }))

  async function handleSubmit(e) {
    e.preventDefault(); setError('')
    if (form.password.length < 8) { setError('Mot de passe : 8 caractères minimum'); return }
    setLoading(true)
    try { onCreated(await api.post('/users', form)); toast(`Compte créé pour ${form.email}`); onClose() }
    catch (e) { setError(e.message) }
    finally { setLoading(false) }
  }

  return (
    <div className="modal-backdrop" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal">
        <div className="modal-header"><h2 className="modal-title">Créer un compte</h2><button className="btn btn-icon" onClick={onClose}>✕</button></div>
        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
          <div className="form-group"><label className="form-label">E-mail *</label><input className="input" type="email" value={form.email} onChange={set('email')} required /></div>
          <div className="form-group"><label className="form-label">Nom d'affichage</label><input className="input" type="text" value={form.display_name} onChange={set('display_name')} /></div>
          <div className="form-group"><label className="form-label">Mot de passe *</label><input className="input" type="password" value={form.password} onChange={set('password')} required minLength={8} /></div>
          <div className="form-group">
            <label className="form-label">Rôle</label>
            <select className="status-select input" value={form.role} onChange={set('role')}>
              <option value="user">Utilisateur</option>
              <option value="admin">Administrateur</option>
            </select>
          </div>
          {error && <p className="form-error">{error}</p>}
          <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
            <button type="button" className="btn btn-ghost" onClick={onClose}>Annuler</button>
            <button type="submit" className="btn btn-primary" disabled={loading}>
              {loading ? <span className="spinner" style={{ width: 14, height: 14, borderWidth: 1.5 }} /> : 'Créer'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

function GoogleBooksKeyModal({ existing, onClose, onSaved }) {
  const toast = useToast()
  const [form, setForm] = useState({ label: existing?.label || 'Clé Google Books', password: '' })
  const [loading, setLoading] = useState(false)
  const [error,   setError]   = useState('')
  const set = k => e => setForm(f => ({ ...f, [k]: e.target.value }))

  async function handleSubmit(e) {
    e.preventDefault(); setError(''); setLoading(true)
    try {
      const saved = existing
        ? await api.put(`/api-keys/${existing.id}`, form)
        : await api.post('/api-keys', { ...form, service: 'googlebooks' })
      onSaved(saved); toast(existing ? 'Clé mise à jour' : 'Clé enregistrée'); onClose()
    } catch (e) { setError(e.message) }
    finally { setLoading(false) }
  }

  return (
    <div className="modal-backdrop" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal">
        <div className="modal-header">
          <div><h2 className="modal-title">Clé API Google Books</h2><p style={{ fontSize: '0.8rem', color: 'var(--text3)', marginTop: '4px' }}>Chiffrée en AES-256 avant stockage</p></div>
          <button className="btn btn-icon" onClick={onClose}>✕</button>
        </div>
        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
          <div className="form-group"><label className="form-label">Libellé</label><input className="input" type="text" value={form.label} onChange={set('label')} required /></div>
          <div className="form-group">
            <label className="form-label">Clé API *</label>
            <input className="input" type="password" value={form.password} onChange={set('password')} placeholder={existing ? '(laisser vide pour conserver)' : 'AIza...'} {...(!existing ? { required: true } : {})} />
            <span style={{ fontSize: '0.72rem', color: 'var(--text3)', marginTop: '4px' }}>Obtenez votre clé sur console.cloud.google.com → API &amp; Services → Google Books API</span>
          </div>
          {error && <p className="form-error">{error}</p>}
          <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
            <button type="button" className="btn btn-ghost" onClick={onClose}>Annuler</button>
            <button type="submit" className="btn btn-primary" disabled={loading}>
              {loading ? <span className="spinner" style={{ width: 14, height: 14, borderWidth: 1.5 }} /> : 'Enregistrer'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

export default function AdminPage() {
  const { profile } = useAuth()
  const toast = useToast()
  const [tab, setTab] = useState('users')
  const [users, setUsers] = useState([])
  const [usersLoading, setUsersLoading] = useState(true)
  const [showCreateUser, setShowCreateUser] = useState(false)
  const [apiKeys, setApiKeys] = useState([])
  const [keysLoading, setKeysLoading] = useState(true)
  const [showKeyModal, setShowKeyModal] = useState(false)
  const [editingKey,   setEditingKey]   = useState(null)

  useEffect(() => {
    api.get('/users').then(setUsers).catch(e => toast(e.message, 'error')).finally(() => setUsersLoading(false))
    api.get('/api-keys').then(setApiKeys).catch(e => toast(e.message, 'error')).finally(() => setKeysLoading(false))
  }, [])

  async function deleteUser(id) {
    if (!confirm('Supprimer cet utilisateur ?')) return
    try { await api.delete(`/users/${id}`); setUsers(u => u.filter(x => x.id !== id)); toast('Utilisateur supprimé') }
    catch (e) { toast(e.message, 'error') }
  }

  async function toggleRole(user) {
    const newRole = user.role === 'admin' ? 'user' : 'admin'
    try { const updated = await api.patch(`/users/${user.id}`, { role: newRole }); setUsers(u => u.map(x => x.id === user.id ? { ...x, ...updated } : x)); toast(`Rôle mis à jour : ${newRole}`) }
    catch (e) { toast(e.message, 'error') }
  }

  async function deleteKey(id) {
    if (!confirm('Supprimer ces identifiants ?')) return
    try { await api.delete(`/api-keys/${id}`); setApiKeys(k => k.filter(x => x.id !== id)); toast('Identifiants supprimés') }
    catch (e) { toast(e.message, 'error') }
  }

  return (
    <>
      <div className="section-header"><h1 className="section-title">Administration</h1></div>

      <div className="tabs">
        <button className={`tab${tab === 'users' ? ' active' : ''}`} onClick={() => setTab('users')}>Utilisateurs</button>
        <button className={`tab${tab === 'keys'  ? ' active' : ''}`} onClick={() => setTab('keys')}>Sources externes</button>
      </div>

      {tab === 'users' && (
        <>
          <div className="section-header" style={{ marginBottom: '16px' }}>
            <span style={{ fontSize: '0.85rem', color: 'var(--text3)' }}>{users.length} compte{users.length !== 1 ? 's' : ''}</span>
            <button className="btn btn-primary btn-sm" onClick={() => setShowCreateUser(true)}>+ Créer un compte</button>
          </div>
          {usersLoading ? <div style={{ textAlign: 'center', padding: '40px' }}><div className="spinner" /></div> : (
            <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
              <table className="admin-table">
                <thead><tr><th>Nom</th><th>Email</th><th>Rôle</th><th>Créé le</th><th></th></tr></thead>
                <tbody>
                  {users.map(u => (
                    <tr key={u.id}>
                      <td style={{ color: 'var(--text)' }}>{u.display_name || '—'}</td>
                      <td>{u.email}</td>
                      <td><span style={{ fontSize: '0.72rem', padding: '2px 8px', borderRadius: '20px', background: u.role === 'admin' ? 'var(--accent-bg)' : 'var(--bg4)', color: u.role === 'admin' ? 'var(--accent)' : 'var(--text3)' }}>{u.role}</span></td>
                      <td style={{ fontSize: '0.78rem' }}>{new Date(u.created_at).toLocaleDateString('fr-FR')}</td>
                      <td>
                        {u.id !== profile?.id ? (
                          <div style={{ display: 'flex', gap: '6px', justifyContent: 'flex-end' }}>
                            <button className="btn btn-ghost btn-sm" onClick={() => toggleRole(u)}>{u.role === 'admin' ? '→ user' : '→ admin'}</button>
                            <button className="btn btn-danger btn-sm" onClick={() => deleteUser(u.id)}>Supprimer</button>
                          </div>
                        ) : <span style={{ fontSize: '0.75rem', color: 'var(--text3)' }}>vous</span>}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </>
      )}

      {tab === 'keys' && (
        <>
          <div className="section-header" style={{ marginBottom: '16px' }}>
            <p style={{ fontSize: '0.875rem', color: 'var(--text2)', margin: 0 }}>Clé API Google Books pour la recherche et les fiches albums.</p>
            {apiKeys.length === 0 && <button className="btn btn-primary btn-sm" onClick={() => { setEditingKey(null); setShowKeyModal(true) }}>+ Ajouter</button>}
          </div>
          {keysLoading ? <div style={{ textAlign: 'center', padding: '40px' }}><div className="spinner" /></div>
          : apiKeys.length === 0 ? (
            <div className="empty-state" style={{ padding: '40px' }}>
              <div className="empty-state-icon">🔑</div>
              <h3>Aucune clé configurée</h3>
              <p>Ajoutez votre clé API Google Books pour activer la recherche.<br />Sans clé, la recherche fonctionne mais avec des limites de quota.</p>
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
              {apiKeys.map(k => (
                <div key={k.id} className="card" style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: '0.95rem', color: 'var(--text)' }}>{k.label}</div>
                    <div style={{ fontSize: '0.75rem', color: 'var(--text3)', marginTop: '2px' }}>Service : {k.service} · Ajouté le {new Date(k.created_at).toLocaleDateString('fr-FR')}</div>
                  </div>
                  <div style={{ display: 'flex', gap: '8px' }}>
                    <button className="btn btn-ghost btn-sm" onClick={() => { setEditingKey(k); setShowKeyModal(true) }}>Modifier</button>
                    <button className="btn btn-danger btn-sm" onClick={() => deleteKey(k.id)}>Supprimer</button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </>
      )}

      {showCreateUser && <CreateUserModal onClose={() => setShowCreateUser(false)} onCreated={u => setUsers(p => [u, ...p])} />}
      {showKeyModal && (
        <GoogleBooksKeyModal
          existing={editingKey}
          onClose={() => { setShowKeyModal(false); setEditingKey(null) }}
          onSaved={saved => setApiKeys(prev => editingKey ? prev.map(k => k.id === saved.id ? saved : k) : [saved, ...prev])}
        />
      )}
    </>
  )
}
