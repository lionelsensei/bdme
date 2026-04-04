import { useState, useRef, useEffect, useCallback } from 'react'
import { api } from '../../lib/api'
import { useToast } from '../../hooks/useToast'

export default function ScanButton() {
  const toast = useToast()
  const [open,      setOpen]      = useState(false)
  const [mode,      setMode]      = useState('scan')
  const [scanning,  setScanning]  = useState(false)
  const [manualEan, setManualEan] = useState('')
  const [loading,   setLoading]   = useState(false)
  const [result,    setResult]    = useState(null)
  const [error,     setError]     = useState('')
  const [adding,    setAdding]    = useState(false)

  const videoRef  = useRef(null)
  const readerRef = useRef(null)
  const zxingRef  = useRef(null)

  // Charger ZXing quand le mode scan est ouvert
  useEffect(() => {
    if (!open || mode !== 'scan') return
    if (zxingRef.current) { startScan(); return }

    const script = document.createElement('script')
    script.src = 'https://unpkg.com/@zxing/library@0.19.1/umd/index.min.js'
    script.onload = () => { zxingRef.current = window.ZXing; startScan() }
    script.onerror = () => setError('Impossible de charger le scanner')
    document.head.appendChild(script)

    return () => stopScan()
  }, [open, mode])

  const startScan = useCallback(async () => {
    if (!zxingRef.current || !videoRef.current) return
    setScanning(true); setError(''); setResult(null)
    try {
      const ZXing = zxingRef.current
      const hints = new Map()
      hints.set(ZXing.DecodeHintType.POSSIBLE_FORMATS, [
        ZXing.BarcodeFormat.EAN_13,
        ZXing.BarcodeFormat.EAN_8,
        ZXing.BarcodeFormat.UPC_A,
      ])
      const reader = new ZXing.BrowserMultiFormatReader(hints)
      readerRef.current = reader
      await reader.decodeFromVideoDevice(null, videoRef.current, (res) => {
        if (res) { stopScan(); searchByEAN(res.getText()) }
      })
    } catch {
      setError('Caméra inaccessible. Vérifiez les permissions.')
      setScanning(false)
    }
  }, [])

  const stopScan = useCallback(() => {
    readerRef.current?.reset()
    readerRef.current = null
    setScanning(false)
  }, [])

  function handleClose() {
    stopScan(); setOpen(false); setResult(null); setError(''); setManualEan('')
  }

  async function searchByEAN(ean) {
    const clean = ean.replace(/\D/g, '')
    if (!clean) return
    setLoading(true); setError(''); setResult(null)
    try {
      setResult(await api.get(`/search/isbn/${clean}`))
    } catch (e) {
      setError(e.message === 'Album introuvable pour cet EAN' ? `Aucun album trouvé pour l'EAN ${clean}` : e.message)
    } finally { setLoading(false) }
  }

  async function addToCollection() {
    if (!result) return
    setAdding(true)
    try {
      await api.post('/books', { bdgest_id: result.bdgest_id, title: result.title, series: result.series, tome: result.tome, author: result.author, illustrator: result.illustrator, publisher: result.publisher, year: result.year, cover_url: result.cover_url, ean: result.ean, read_status: 'unread' })
      toast(`"${result.title}" ajouté à la collection`)
      setResult(r => ({ ...r, in_collection: true }))
    } catch (e) { toast(e.message, 'error') }
    finally { setAdding(false) }
  }

  async function addToWishlist() {
    if (!result) return
    setAdding(true)
    try {
      await api.post('/wishlist', { bdgest_id: result.bdgest_id, title: result.title, series: result.series, tome: result.tome, author: result.author, cover_url: result.cover_url, year: result.year })
      toast(`"${result.title}" ajouté aux souhaits`)
      setResult(r => ({ ...r, in_wishlist: true }))
    } catch (e) { toast(e.message, 'error') }
    finally { setAdding(false) }
  }

  function switchMode(m) { stopScan(); setMode(m); setResult(null); setError('') }

  return (
    <>
      <button className="fab" onClick={() => setOpen(true)} aria-label="Scanner un album">⊡</button>

      {open && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.75)', backdropFilter: 'blur(6px)', zIndex: 200, display: 'flex', alignItems: 'flex-end', justifyContent: 'center' }}
          onClick={e => e.target === e.currentTarget && handleClose()}>
          <div className="scan-sheet">
            <div className="scan-handle" />

            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px' }}>
              <h3 style={{ fontFamily: 'var(--font-serif)', fontSize: '1.15rem', fontWeight: 400 }}>Ajouter par scan</h3>
              <button className="btn btn-icon" onClick={handleClose} style={{ fontSize: '1.1rem' }}>✕</button>
            </div>

            <div className="scan-tabs">
              <button className={`scan-tab${mode === 'scan' ? ' active' : ''}`} onClick={() => switchMode('scan')}>📷 Scanner</button>
              <button className={`scan-tab${mode === 'manual' ? ' active' : ''}`} onClick={() => switchMode('manual')}>⌨ Saisir EAN</button>
            </div>

            {/* Scan camera */}
            {mode === 'scan' && (
              <div>
                <div className="scan-overlay">
                  <video ref={videoRef} className="scan-video" playsInline muted />
                  {scanning && <div className="scan-line" />}
                </div>
                <p style={{ fontSize: '0.8rem', color: 'var(--text3)', textAlign: 'center', marginBottom: '8px' }}>
                  Pointez la caméra vers le code-barres EAN de la BD
                </p>
                {!scanning && !loading && (
                  <button className="btn btn-primary" style={{ width: '100%', justifyContent: 'center' }} onClick={startScan}>
                    Démarrer la caméra
                  </button>
                )}
              </div>
            )}

            {/* Saisie manuelle */}
            {mode === 'manual' && (
              <form onSubmit={e => { e.preventDefault(); if (manualEan.trim()) searchByEAN(manualEan.trim()) }}
                style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                <div className="form-group">
                  <label className="form-label">Code EAN / ISBN</label>
                  <input className="input" type="text" inputMode="numeric" placeholder="9782344012345"
                    value={manualEan} onChange={e => setManualEan(e.target.value.replace(/\D/g, ''))}
                    maxLength={14} autoFocus />
                </div>
                <button className="btn btn-primary" type="submit" disabled={loading || !manualEan}
                  style={{ justifyContent: 'center' }}>
                  {loading ? <span className="spinner" style={{ width: 14, height: 14, borderWidth: 1.5 }} /> : 'Rechercher'}
                </button>
              </form>
            )}

            {/* Loader */}
            {loading && mode === 'scan' && (
              <div style={{ textAlign: 'center', padding: '20px', color: 'var(--text3)' }}>
                <div className="spinner" />
                <p style={{ marginTop: '10px', fontSize: '0.85rem' }}>Recherche en cours…</p>
              </div>
            )}

            {/* Erreur */}
            {error && (
              <div style={{ marginTop: '16px', padding: '12px 14px', background: 'rgba(224,92,92,0.1)', border: '1px solid rgba(224,92,92,0.25)', borderRadius: '8px', fontSize: '0.85rem', color: 'var(--red)' }}>
                {error}
              </div>
            )}

            {/* Résultat */}
            {result && (
              <div className="scan-result-card">
                {result.cover_url
                  ? <img src={result.cover_url} alt={result.title} style={{ width: 70, height: 105, objectFit: 'cover', borderRadius: 6, flexShrink: 0 }} />
                  : <div style={{ width: 70, height: 105, background: 'var(--bg4)', borderRadius: 6, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '1.5rem' }}>📖</div>
                }
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap', marginBottom: '4px' }}>
                    {result.in_collection && <span className="badge badge-collection">✓ Collection</span>}
                    {result.in_wishlist   && <span className="badge badge-wishlist">♥ Souhaits</span>}
                  </div>
                  <div style={{ fontSize: '0.95rem', color: 'var(--text)', lineHeight: 1.3, marginBottom: '4px' }}>{result.title}</div>
                  <div style={{ fontSize: '0.78rem', color: 'var(--text3)', lineHeight: 1.6 }}>
                    {result.series && <span>{result.series}{result.tome ? ` T${result.tome}` : ''}</span>}
                    {result.author && <span> · {result.author}</span>}
                    {result.year   && <span> · {result.year}</span>}
                  </div>
                  <div style={{ display: 'flex', gap: '6px', marginTop: '10px', flexWrap: 'wrap' }}>
                    {!result.in_collection && (
                      <button className="btn btn-primary btn-sm" onClick={addToCollection} disabled={adding}>
                        {adding ? <span className="spinner" style={{ width: 12, height: 12, borderWidth: 1.5 }} /> : '+ Collection'}
                      </button>
                    )}
                    {!result.in_wishlist && !result.in_collection && (
                      <button className="btn btn-ghost btn-sm" onClick={addToWishlist} disabled={adding}>♥ Souhaits</button>
                    )}
                    {result.in_collection && <span style={{ fontSize: '0.8rem', color: 'var(--green)', alignSelf: 'center' }}>Déjà dans votre collection</span>}
                  </div>
                  <button style={{ marginTop: '10px', fontSize: '0.75rem', color: 'var(--text3)', background: 'none', border: 'none', cursor: 'pointer', padding: 0 }}
                    onClick={() => { setResult(null); setError(''); setManualEan(''); if (mode === 'scan') startScan() }}>
                    ↩ Scanner un autre
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </>
  )
}
