import { useState, useEffect } from 'react'

const VERSION = 'v1.4.0'
const BASE    = import.meta.env.VITE_API_URL || ''

function renderChangelog(text) {
  return text.split('\n').map((line, i) => {
    if (line.startsWith('## '))  return <h2 key={i} style={{ fontFamily: 'var(--font-serif)', fontSize: '1rem', color: 'var(--accent)', margin: '20px 0 6px' }}>{line.replace(/^## /, '')}</h2>
    if (line.startsWith('### ')) return <h3 key={i} style={{ fontSize: '0.72rem', color: 'var(--text3)', fontWeight: 600, margin: '12px 0 4px', textTransform: 'uppercase', letterSpacing: '0.06em' }}>{line.replace(/^### /, '')}</h3>
    if (line.startsWith('- '))   return <p  key={i} style={{ fontSize: '0.82rem', color: 'var(--text2)', paddingLeft: '12px', marginBottom: '3px', lineHeight: 1.5 }}>· {line.replace(/^- /, '')}</p>
    if (/^---+$/.test(line.trim())) return <hr key={i} style={{ border: 'none', borderTop: '1px solid var(--border)', margin: '16px 0' }} />
    return null
  }).filter(Boolean)
}

function ChangelogModal({ onClose }) {
  const [content, setContent] = useState('')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetch(`${BASE}/changelog`)
      .then(r => r.text())
      .then(t => { setContent(t); setLoading(false) })
      .catch(() => setLoading(false))
  }, [])

  return (
    <div className="modal-backdrop" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal" style={{ maxWidth: '600px' }}>
        <div className="modal-header">
          <h2 className="modal-title">Changelog</h2>
          <button className="btn btn-icon" onClick={onClose} style={{ fontSize: '1.2rem', color: 'var(--text2)' }}>✕</button>
        </div>
        <div style={{ maxHeight: '65dvh', overflowY: 'auto', paddingRight: '4px' }}>
          {loading
            ? <div style={{ textAlign: 'center', padding: '40px' }}><div className="spinner" /></div>
            : renderChangelog(content)}
        </div>
      </div>
    </div>
  )
}

export default function VersionFooter() {
  const [open, setOpen] = useState(false)

  const linkStyle = {
    background: 'none', border: 'none', cursor: 'pointer',
    color: 'var(--text3)', fontSize: '0.7rem', fontFamily: 'var(--font-sans)',
    padding: 0, textDecoration: 'underline', textUnderlineOffset: '2px',
    opacity: 0.7,
  }

  return (
    <>
      <div style={{ textAlign: 'center', marginTop: '40px', fontSize: '0.7rem', color: 'var(--text3)', opacity: 0.7, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px' }}>
        <span>{VERSION}</span>
        <span style={{ opacity: 0.5 }}>·</span>
        <button style={linkStyle} onClick={() => setOpen(true)}>changelog</button>
      </div>
      {open && <ChangelogModal onClose={() => setOpen(false)} />}
    </>
  )
}
