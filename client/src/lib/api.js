import { supabase } from './supabase'

const BASE = import.meta.env.VITE_API_URL || ''

let _token = null
supabase.auth.getSession().then(({ data }) => { _token = data.session?.access_token ?? null })
supabase.auth.onAuthStateChange((_e, session) => { _token = session?.access_token ?? null })

async function getToken() {
  if (_token) return _token
  const { data } = await supabase.auth.getSession()
  _token = data.session?.access_token ?? null
  return _token
}

async function req(method, path, body) {
  const token = await getToken()
  const res = await fetch(`${BASE}/api${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
  })
  const data = await res.json().catch(() => ({}))
  if (!res.ok) throw new Error(data.error || `Erreur ${res.status}`)
  return data
}

export const api = {
  get:    (path)       => req('GET',    path),
  post:   (path, body) => req('POST',   path, body),
  patch:  (path, body) => req('PATCH',  path, body),
  put:    (path, body) => req('PUT',    path, body),
  delete: (path)       => req('DELETE', path),
}
