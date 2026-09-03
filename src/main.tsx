import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.tsx'
import { OnlinePage } from './pages/OnlinePage.tsx'
import { PlayerProvider } from './context/PlayerContext.tsx'
import { ToastProvider } from './context/ToastContext.tsx'
import { UnsavedChangesProvider } from './context/UnsavedChangesContext.tsx'
import { initSafeArea } from './lib/safeArea.ts'

initSafeArea()

const route = window.location.pathname.replace(/\/$/, '')
// /display et /battle rendent le MÊME écran partagé : les joueurs y arrivent en
// mode affichage et basculent en bataille quand le MJ le décide. /battle reste
// accepté pour ne pas casser les liens existants.
// Cet écran est rendu DANS les providers : il doit savoir quel personnage joue.
const isOnlineRoute = route === '/display' || route === '/battle'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <PlayerProvider>
      <ToastProvider>
        <UnsavedChangesProvider>
          {isOnlineRoute ? <OnlinePage /> : <App />}
        </UnsavedChangesProvider>
      </ToastProvider>
    </PlayerProvider>
  </StrictMode>,
)
