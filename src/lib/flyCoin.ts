const COIN_SIZE = 40
const COIN_PER_VALUE = 10
const MAX_COINS = 20
const SPAWN_INTERVAL_MS = 100
const FLIGHT_DURATION_MS = 600

function spawnCoin(fromRect: DOMRect, imageUrl?: string | null) {
  const target = document.getElementById('pokedollar-chip')
  if (!target) return
  const to = target.getBoundingClientRect()

  // Léger décalage aléatoire pour que les pièces ne se superposent pas parfaitement
  const startX = fromRect.left + fromRect.width / 2 + (Math.random() - 0.5) * fromRect.width * 0.6
  const startY = fromRect.top + fromRect.height / 2 + (Math.random() - 0.5) * fromRect.height * 0.6

  const coin = document.createElement(imageUrl ? 'img' : 'div')
  if (imageUrl) {
    (coin as HTMLImageElement).src = imageUrl
  } else {
    coin.textContent = '💰'
  }
  coin.style.cssText =
    `position:fixed;left:${startX}px;top:${startY}px;z-index:100;` +
    `pointer-events:none;font-size:${COIN_SIZE}px;width:${COIN_SIZE}px;height:${COIN_SIZE}px;object-fit:contain;` +
    `transform:translate(-50%,-50%);`
  document.body.appendChild(coin)

  const dx = to.left + to.width / 2 - startX
  const dy = to.top + to.height / 2 - startY

  const anim = coin.animate(
    [
      { transform: 'translate(-50%,-50%) scale(1)', opacity: 1 },
      { transform: `translate(calc(-50% + ${dx}px), calc(-50% + ${dy}px)) scale(0.4)`, opacity: 0.3 },
    ],
    { duration: FLIGHT_DURATION_MS, easing: 'cubic-bezier(0.4, 0, 0.2, 1)' }
  )
  anim.onfinish = () => coin.remove()
}

// Anime des pièces depuis le rect d'origine (bouton SELL) jusqu'au chip Pokédollar du header.
// Une pièce par tranche de 10 pokédollars vendus (max 20), lancées une par une toutes les 100ms.
// DOM impératif (Web Animations API) plutôt qu'un état React : animation ponctuelle sans
// besoin de re-render, et n'importe quel appelant peut la déclencher sans prop-drilling de ref.
export function flyCoin(fromRect: DOMRect, value: number, imageUrl?: string | null) {
  const count = Math.min(MAX_COINS, Math.max(1, Math.round(value / COIN_PER_VALUE)))
  for (let i = 0; i < count; i++) {
    setTimeout(() => spawnCoin(fromRect, imageUrl), i * SPAWN_INTERVAL_MS)
  }
}
