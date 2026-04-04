import { useState } from 'react'
import { NavLink, useNavigate } from 'react-router-dom'
import { useAuth } from '../../hooks/useAuth'

export default function Nav() {
  const { profile, isAdmin, signOut } = useAuth()
  const [menuOpen, setMenuOpen] = useState(false)
  const [showUser, setShowUser] = useState(false)
  const navigate = useNavigate()

  const links = [
    { to: '/',          label: 'Collection' },
    { to: '/recherche', label: 'Recherche'  },
    { to: '/souhaits',  label: 'Souhaits'   },
    ...(isAdmin ? [{ to: '/admin', label: 'Admin' }] : []),
  ]

  const initials = (profile?.display_name || profile?.email || '?').slice(0, 2).toUpperCase()

  async function handleSignOut() {
    await signOut()
    navigate('/login')
  }

  return (
    <nav className="nav">
      <span className="nav-logo">BDme</span>

      <div className={`nav-links${menuOpen ? ' open' : ''}`}>
        {links.map(l => (
          <NavLink key={l.to} to={l.to} end={l.to === '/'}
            className={({ isActive }) => `nav-link${isActive ? ' active' : ''}`}
            onClick={() => setMenuOpen(false)}>
            {l.label}
          </NavLink>
        ))}
      </div>

      <div style={{ position: 'relative' }}>
        <button className="nav-avatar" onClick={() => setShowUser(v => !v)}>{initials}</button>
        {showUser && (
          <div style={{ position: 'absolute', top: 'calc(100% + 8px)', right: 0, background: 'var(--bg2)', border: '1px solid var(--border2)', borderRadius: 'var(--radius)', padding: '8px', minWidth: '180px', zIndex: 300, boxShadow: 'var(--shadow)' }}>
            <div style={{ padding: '8px 12px 12px', borderBottom: '1px solid var(--border)', marginBottom: '6px' }}>
              <div style={{ fontSize: '0.85rem', color: 'var(--text)' }}>{profile?.display_name}</div>
              <div style={{ fontSize: '0.75rem', color: 'var(--text3)', marginTop: '2px' }}>{profile?.email}</div>
              {isAdmin && <div style={{ fontSize: '0.7rem', color: 'var(--accent)', marginTop: '4px' }}>Administrateur</div>}
            </div>
            <button className="btn btn-ghost btn-sm" style={{ width: '100%' }} onClick={handleSignOut}>
              Se déconnecter
            </button>
          </div>
        )}
      </div>

      <button className="nav-burger" onClick={() => setMenuOpen(v => !v)} aria-label="Menu">
        <span style={menuOpen ? { transform: 'rotate(45deg) translate(4px, 4px)' } : {}} />
        <span style={menuOpen ? { opacity: 0 } : {}} />
        <span style={menuOpen ? { transform: 'rotate(-45deg) translate(4px, -4px)' } : {}} />
      </button>
    </nav>
  )
}
