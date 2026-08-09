import { useState } from 'react'
import type { Player } from '../types'
import { useFullscreen } from '../hooks/useFullscreen'
import { usePushNotifications } from '../hooks/usePushNotifications'
import { ConfirmPopup } from './ConfirmPopup'
import { AddToHomeScreenModal } from './AddToHomeScreenModal'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PANEL_LG } from '../lib/panelStyles'

const ADMIN_PASSWORD = 'Rioluxray171216'

async function hardRefresh() {
  try {
    if ('serviceWorker' in navigator) {
      const registrations = await navigator.serviceWorker.getRegistrations()
      await Promise.all(registrations.map((reg) => reg.unregister()))
    }
    if ('caches' in window) {
      const keys = await caches.keys()
      await Promise.all(keys.map((key) => caches.delete(key)))
    }
  } finally {
    window.location.reload()
  }
}

interface Props {
  player: Player | null
  isAdmin: boolean
  notificationsAvailable: boolean
  onRequestLogin: () => void
  onLogout: () => void
  onAdminSuccess: () => void
  onAdminLogout: () => void
  onClose: () => void
}

export function SettingsPopup({ player, isAdmin, notificationsAvailable, onRequestLogin, onLogout, onAdminSuccess, onAdminLogout, onClose }: Props) {
  const { isFullscreen, toggle } = useFullscreen()
  const { supported, needsInstall, permission, subscribed, loading, enable, disable } = usePushNotifications(player?.id ?? null)
  const [showInstallPrompt, setShowInstallPrompt] = useState(false)
  const [adminPassword, setAdminPassword] = useState('')
  const [adminMsg, setAdminMsg] = useState<{ text: string; error: boolean } | null>(null)
  const [showAdminLogoutConfirm, setShowAdminLogoutConfirm] = useState(false)
  const [refreshing, setRefreshing] = useState(false)

  const handleToggleNotifications = async () => {
    if (subscribed) {
      await disable()
      return
    }
    if (needsInstall) {
      setShowInstallPrompt(true)
      return
    }
    await enable()
  }

  const handleAdminSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (adminPassword === ADMIN_PASSWORD) {
      sessionStorage.setItem('adminMode', 'true')
      setAdminMsg({ text: 'Mode admin activé !', error: false })
      setAdminPassword('')
      onAdminSuccess()
    } else {
      setAdminMsg({ text: 'Mot de passe incorrect.', error: true })
      setAdminPassword('')
    }
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/55 p-4"
      onClick={(e) => { if (e.target === e.currentTarget) onClose() }}
    >
      <div className={`${PANEL_LG} w-full max-w-xs max-h-[85%] overflow-y-auto p-5 text-ink`}>
        <div className="text-lg text-center mb-4 tracking-wide">PARAMÈTRES</div>

        {/* Identité joueur */}
        <div className="flex items-center gap-3 mb-4">
          <div
            className="w-10 h-10 rounded-full overflow-hidden shrink-0 border-[3px] border-ink"
            style={{ backgroundColor: player?.color ?? '#8a8362' }}
          >
            {player?.image_url && (
              <img src={player.image_url} alt={player.name} className="w-full h-full object-cover" />
            )}
          </div>
          <div className="text-[15px]">{player ? player.name : 'Non connecté'}</div>
        </div>

        {/* Plein écran */}
        <div className="flex items-center justify-between mb-3">
          <span className="text-sm">⛶ Plein écran</span>
          <button
            onClick={toggle}
            className={`text-xs px-2.5 py-1.5 rounded-md font-bold ${isFullscreen ? BUTTON_STYLE.green : BUTTON_STYLE.gray}`}
          >
            {isFullscreen ? 'Activé' : 'Désactivé'}
          </button>
        </div>

        {/* Rafraîchissement complet */}
        <div className="flex items-center justify-between mb-3">
          <span className="text-sm">🔄 Rafraîchir l'appli</span>
          <button
            onClick={() => { setRefreshing(true); void hardRefresh() }}
            disabled={refreshing}
            className={`text-xs px-2.5 py-1.5 rounded-md font-bold ${BUTTON_STYLE.gray}`}
          >
            {refreshing ? '...' : 'Actualiser'}
          </button>
        </div>

        {/* Notifications */}
        {player && supported && (notificationsAvailable || subscribed) && (
          <div className="flex items-center justify-between mb-3">
            <span className="text-sm">🔔 Notifications</span>
            {permission === 'denied' ? (
              <span className="text-xs text-ink-muted-2">Bloquées (réglages du navigateur)</span>
            ) : (
              <button
                onClick={handleToggleNotifications}
                disabled={loading}
                className={`text-xs px-2.5 py-1.5 rounded-md font-bold ${subscribed ? BUTTON_STYLE.green : BUTTON_STYLE.gray}`}
              >
                {subscribed ? 'Activées' : 'Désactivées'}
              </button>
            )}
          </div>
        )}

        {/* Connexion / déconnexion */}
        {player ? (
          <button
            onClick={() => { onLogout(); onClose() }}
            className={`w-full py-2 rounded-lg text-sm font-bold mb-4 ${BUTTON_STYLE.red}`}
          >
            Se déconnecter
          </button>
        ) : (
          <button
            onClick={onRequestLogin}
            className={`w-full py-2 rounded-lg text-sm font-bold mb-4 ${BUTTON_STYLE.green}`}
          >
            👤 Se connecter
          </button>
        )}

        {/* Mode admin */}
        <div className="border-t-2 border-[#cfc7a8] pt-3 mb-4">
          <span className="text-[11px] text-ink-muted-2 tracking-widest">MODE ADMIN</span>
          {isAdmin ? (
            <button
              onClick={() => setShowAdminLogoutConfirm(true)}
              className={`w-full py-2 rounded-lg text-sm font-bold mt-2 ${BUTTON_STYLE.yellow}`}
            >
              🛠️ Quitter le mode admin
            </button>
          ) : (
            <>
              <form onSubmit={handleAdminSubmit} className="flex gap-1.5 mt-2">
                <input
                  type="password"
                  value={adminPassword}
                  onChange={(e) => setAdminPassword(e.target.value)}
                  placeholder="Mot de passe"
                  className="flex-1 min-w-0 px-2.5 py-1.5 rounded-md border-2 border-ink bg-white text-ink text-sm outline-none"
                />
                <button type="submit" className={`px-3 py-1.5 rounded-md text-sm font-bold ${BUTTON_STYLE.gray}`}>
                  OK
                </button>
              </form>
              {adminMsg && (
                <p className={`text-xs mt-1.5 ${adminMsg.error ? 'text-hp-red' : 'text-[#5c8f6a]'}`}>{adminMsg.text}</p>
              )}
            </>
          )}
        </div>

        <button
          onClick={onClose}
          className={`w-full py-2 rounded-lg text-sm font-bold ${BUTTON_STYLE.gray}`}
        >
          Fermer
        </button>
      </div>

      {showAdminLogoutConfirm && (
        <ConfirmPopup
          title="Quitter le mode admin ?"
          confirmLabel="Quitter"
          onConfirm={() => { onAdminLogout(); setShowAdminLogoutConfirm(false) }}
          onCancel={() => setShowAdminLogoutConfirm(false)}
        />
      )}

      {showInstallPrompt && (
        <AddToHomeScreenModal onClose={() => setShowInstallPrompt(false)} />
      )}
    </div>
  )
}
