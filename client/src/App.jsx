import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { AuthProvider, useAuth } from './hooks/useAuth'
import { ToastProvider } from './hooks/useToast'
import Nav from './components/ui/Nav'
import ScanButton from './components/ui/ScanButton'
import VersionFooter from './components/ui/VersionFooter'
import LoginPage from './pages/LoginPage'
import CollectionPage from './pages/CollectionPage'
import SearchPage from './pages/SearchPage'
import WishlistPage from './pages/WishlistPage'
import AdminPage from './pages/AdminPage'

function ProtectedRoute({ children, adminOnly = false }) {
  const { user, profile, loading } = useAuth()
  if (loading) return (
    <div className="loading-page">
      <div className="logo">BDme</div>
      <div className="spinner" />
    </div>
  )
  if (!user) return <Navigate to="/login" replace />
  if (adminOnly && profile?.role !== 'admin') return <Navigate to="/" replace />
  return children
}

function AppRoutes() {
  const { user } = useAuth()
  return (
    <div className="app-shell">
      {user && <Nav />}
      {user && <ScanButton />}
      <main className="main-content">
        <Routes>
          <Route path="/login" element={user ? <Navigate to="/" replace /> : <LoginPage />} />
          <Route path="/" element={<ProtectedRoute><CollectionPage /></ProtectedRoute>} />
          <Route path="/recherche" element={<ProtectedRoute><SearchPage /></ProtectedRoute>} />
          <Route path="/souhaits" element={<ProtectedRoute><WishlistPage /></ProtectedRoute>} />
          <Route path="/admin" element={<ProtectedRoute adminOnly><AdminPage /></ProtectedRoute>} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
        {user && <VersionFooter />}
      </main>
    </div>
  )
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <ToastProvider>
          <AppRoutes />
        </ToastProvider>
      </AuthProvider>
    </BrowserRouter>
  )
}
