import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.tsx'
import { DisplayPage } from './pages/DisplayPage.tsx'
import { PlayerProvider } from './context/PlayerContext.tsx'
import { ToastProvider } from './context/ToastContext.tsx'
import { UnsavedChangesProvider } from './context/UnsavedChangesContext.tsx'

const isDisplayRoute = window.location.pathname.replace(/\/$/, '') === '/display'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    {isDisplayRoute ? (
      <DisplayPage />
    ) : (
      <PlayerProvider>
        <ToastProvider>
          <UnsavedChangesProvider>
            <App />
          </UnsavedChangesProvider>
        </ToastProvider>
      </PlayerProvider>
    )}
  </StrictMode>,
)
