// Permet de savoir si un pixel affiché d'un sprite PNG (fond transparent) est
// opaque ou non, pour un hit-test précis au pixel plutôt que sur tout le
// rectangle du bouton. Même limite que CarteTab (lecture de pixels via
// canvas) : les URLs d'images sont saisies librement par l'admin (import
// CSV), sans garantie d'en-têtes CORS permissifs — `getImageData` échoue
// alors avec un canvas « taché ». On dégrade silencieusement vers l'ancien
// comportement (rectangle plein) plutôt que d'afficher une erreur : ceci est
// un raffinement du hit-test, pas une fonctionnalité critique.
type AlphaEntry = { canvas: HTMLCanvasElement; width: number; height: number } | 'loading' | 'error'

const cache = new Map<string, AlphaEntry>()

export function warmSpriteAlpha(src: string): void {
  if (!src || cache.has(src)) return
  cache.set(src, 'loading')
  const img = new Image()
  img.crossOrigin = 'anonymous'
  img.onload = () => {
    const canvas = document.createElement('canvas')
    canvas.width = img.naturalWidth
    canvas.height = img.naturalHeight
    const ctx = canvas.getContext('2d')
    if (!ctx) {
      cache.set(src, 'error')
      return
    }
    ctx.drawImage(img, 0, 0)
    try {
      ctx.getImageData(0, 0, 1, 1) // déclenche l'exception « canvas taché » si CORS bloque la lecture
      cache.set(src, { canvas, width: canvas.width, height: canvas.height })
    } catch {
      cache.set(src, 'error')
    }
  }
  img.onerror = () => cache.set(src, 'error')
  img.src = src
}

const TRANSPARENT_ALPHA_THRESHOLD = 10

/**
 * `imgRect` est la boîte affichée (`object-contain`) de l'image, potentiellement
 * plus grande que son contenu réel si le ratio diffère — on calcule d'abord le
 * rectangle réellement occupé par l'image avant de convertir en coordonnées pixel.
 * Retourne `true` (considéré comme un impact) dès qu'on n'a pas encore les
 * données d'alpha en cache, pour ne jamais régresser par rapport à l'ancien
 * hit-test plein rectangle.
 */
export function isOpaqueAt(
  src: string,
  imgRect: DOMRect,
  naturalWidth: number,
  naturalHeight: number,
  clientX: number,
  clientY: number,
): boolean {
  const entry = cache.get(src)
  if (!entry || entry === 'loading' || entry === 'error') return true
  if (!naturalWidth || !naturalHeight || !imgRect.width || !imgRect.height) return true

  const scale = Math.min(imgRect.width / naturalWidth, imgRect.height / naturalHeight)
  const renderedW = naturalWidth * scale
  const renderedH = naturalHeight * scale
  const padX = (imgRect.width - renderedW) / 2
  const padY = (imgRect.height - renderedH) / 2

  const localX = clientX - imgRect.left - padX
  const localY = clientY - imgRect.top - padY
  const px = Math.floor(localX / scale)
  const py = Math.floor(localY / scale)
  if (px < 0 || py < 0 || px >= entry.width || py >= entry.height) return false

  const ctx = entry.canvas.getContext('2d')
  if (!ctx) return true
  const alpha = ctx.getImageData(px, py, 1, 1).data[3]
  return alpha >= TRANSPARENT_ALPHA_THRESHOLD
}
