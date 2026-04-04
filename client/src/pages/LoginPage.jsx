import { useState } from 'react'
import { useAuth } from '../hooks/useAuth'

export default function LoginPage() {
  const { signIn } = useAuth()
  const [email,    setEmail]    = useState('')
  const [password, setPassword] = useState('')
  const [error,    setError]    = useState('')
  const [loading,  setLoading]  = useState(false)

  async function handleSubmit(e) {
    e.preventDefault(); setError(''); setLoading(true)
    try { await signIn(email, password) }
    catch (err) { setError(err.message === 'Invalid login credentials' ? 'Identifiants incorrects' : err.message) }
    finally { setLoading(false) }
  }

  return (
    <div style={{ minHeight: '100dvh', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '24px' }}>
      <div style={{ width: '100%', maxWidth: '380px' }}>
        <div style={{ textAlign: 'center', marginBottom: '40px' }}>
          <h1 style={{ fontFamily: 'var(--font-serif)', fontSize: '2.8rem', color: 'var(--accent)', letterSpacing: '-0.02em', lineHeight: 1 }}>BDme</h1>
          <p style={{ marginTop: '8px', fontSize: '0.875rem', color: 'var(--text3)' }}>Votre bibliothèque de bandes dessinées</p>
        </div>
        <div className="card">
          <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <div className="form-group">
              <label className="form-label">Adresse e-mail</label>
              <input className="input" type="email" value={email} onChange={e => setEmail(e.target.value)} placeholder="vous@exemple.com" autoComplete="email" required />
            </div>
            <div className="form-group">
              <label className="form-label">Mot de passe</label>
              <input className="input" type="password" value={password} onChange={e => setPassword(e.target.value)} placeholder="••••••••" autoComplete="current-password" required />
            </div>
            {error && <p className="form-error">{error}</p>}
            <button className="btn btn-primary" type="submit" disabled={loading} style={{ width: '100%', justifyContent: 'center', marginTop: '4px' }}>
              {loading ? <span className="spinner" style={{ width: 16, height: 16, borderWidth: 1.5 }} /> : 'Se connecter'}
            </button>
          </form>
        </div>
        <p style={{ textAlign: 'center', marginTop: '20px', fontSize: '0.8rem', color: 'var(--text3)' }}>
          L'accès est sur invitation uniquement.<br />Contactez un administrateur pour obtenir un compte.
        </p>
        <p style={{ textAlign: 'center', marginTop: '32px', fontSize: '0.7rem', color: 'var(--text3)', opacity: 0.7 }}>v1.1.0</p>
      </div>
    </div>
  )
}
