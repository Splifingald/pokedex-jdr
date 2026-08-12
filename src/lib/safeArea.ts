/**
 * Zones sûres (safe areas) — repli pour iOS Safari hors mode standalone.
 *
 * Avec `viewport-fit=cover`, la page s'affiche bord à bord et `env(safe-area-inset-top)`
 * suffit... en mode PWA installée. Mais dans Safari (impossible de passer en plein écran
 * sur iPhone), le contenu peut passer sous la barre d'état (heure / batterie / réseau)
 * alors que `env(safe-area-inset-top)` renvoie 0 → l'en-tête de l'app se retrouve caché
 * derrière ces éléments système.
 *
 * On mesure donc la valeur réelle de `env()` et, si elle vaut 0 sur iOS alors que la
 * fenêtre occupe toute la hauteur de l'écran (donc bien sous la barre d'état), on force
 * une valeur de repli correspondant à la hauteur de la barre d'état iOS.
 */

/** Hauteur de la barre d'état iOS : ~50px sur les modèles à encoche, 20px sinon. */
const NOTCH_STATUS_BAR_PX = 50
const LEGACY_STATUS_BAR_PX = 20

function measureEnvInset(side: 'top' | 'bottom'): number {
  const probe = document.createElement('div')
  probe.style.cssText = `position:fixed;left:0;top:0;width:0;visibility:hidden;pointer-events:none;height:env(safe-area-inset-${side}, 0px)`
  document.body.appendChild(probe)
  const height = probe.getBoundingClientRect().height
  probe.remove()
  return height
}

function isIOS(): boolean {
  const ua = navigator.userAgent
  // iPadOS 13+ se présente comme un Mac : on le distingue via le multi-touch.
  return /iPad|iPhone|iPod/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1)
}

/** Vrai si la fenêtre couvre (quasiment) tout l'écran, donc s'étend sous la barre d'état. */
function isEdgeToEdge(): boolean {
  const screenHeight = window.screen.height
  if (!screenHeight) return false
  return window.innerHeight >= screenHeight - 24
}

export function applySafeAreaFallback(): void {
  if (!isIOS()) return

  const root = document.documentElement
  const top = measureEnvInset('top')

  if (top === 0 && isEdgeToEdge()) {
    const statusBar = window.screen.height >= 780 ? NOTCH_STATUS_BAR_PX : LEGACY_STATUS_BAR_PX
    root.style.setProperty('--safe-top', `${statusBar}px`)
  } else {
    root.style.removeProperty('--safe-top')
  }
}

/** À appeler une fois au démarrage ; réévalue aussi aux rotations / changements de taille. */
export function initSafeArea(): void {
  applySafeAreaFallback()
  window.addEventListener('resize', applySafeAreaFallback)
  window.addEventListener('orientationchange', applySafeAreaFallback)
}
