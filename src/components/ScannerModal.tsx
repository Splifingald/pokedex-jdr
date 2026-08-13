import { useState, useEffect, useRef, useCallback } from 'react'
import type { Pokemon } from '../types'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { CloseIcon } from './icons/CloseIcon'

interface Props {
  pokemon: Pokemon[]
  discovered: Set<string>
  onDiscover: (p: Pokemon) => void
  onClose: () => void
}

type Phase = 'camera' | 'scanning' | 'result' | 'nomatch' | 'error'

// ── Helpers ───────────────────────────────────────────────────────────────────

function levenshtein(a: string, b: string): number {
  const n = b.length
  let row = Array.from({ length: n + 1 }, (_, i) => i)
  for (let i = 0; i < a.length; i++) {
    const next = [i + 1]
    for (let j = 0; j < n; j++) {
      next[j + 1] =
        a[i] === b[j] ? row[j] : 1 + Math.min(row[j], row[j + 1], next[j])
    }
    row = next
  }
  return row[n]
}

/** Normalise : minuscules, sans accents, non-alphanum → espace */
function norm(s: string): string {
  return s
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim()
}

function findMatch(ocrText: string, list: Pokemon[]): Pokemon | null {
  const t = norm(ocrText)

  // Pass 1 — correspondance exacte (le nom apparaît tel quel dans le texte)
  for (const p of list) {
    const n = norm(p.nom)
    if (n.length >= 3 && t.includes(n)) return p
  }

  // Pass 2 — Levenshtein mot par mot (tolère les erreurs OCR)
  const words = t.split(' ').filter((w) => w.length >= 3)
  let best: { p: Pokemon; d: number } | null = null

  for (const p of list) {
    const n = norm(p.nom)
    const threshold = Math.max(1, Math.floor(n.length / 5)) // 1 pour noms courts, 2 pour longs
    for (const w of words) {
      if (Math.abs(w.length - n.length) > threshold + 1) continue
      const d = levenshtein(w, n)
      if (d <= threshold && (!best || d < best.d)) best = { p, d }
    }
  }

  return best?.p ?? null
}

/** Pré-traitement image : niveaux de gris + contraste accru → meilleur OCR */
async function preprocessImage(dataUrl: string): Promise<string> {
  return new Promise((resolve) => {
    const img = new Image()
    img.onload = () => {
      const canvas = document.createElement('canvas')
      canvas.width = img.naturalWidth
      canvas.height = img.naturalHeight
      const ctx = canvas.getContext('2d')!
      ctx.drawImage(img, 0, 0)

      const imgData = ctx.getImageData(0, 0, canvas.width, canvas.height)
      const d = imgData.data
      const factor = (259 * (1.4 * 255 + 255)) / (255 * (259 - 1.4 * 255))

      for (let i = 0; i < d.length; i += 4) {
        const gray = 0.299 * d[i] + 0.587 * d[i + 1] + 0.114 * d[i + 2]
        const val = Math.min(255, Math.max(0, Math.round(factor * (gray - 128) + 128)))
        d[i] = d[i + 1] = d[i + 2] = val
      }
      ctx.putImageData(imgData, 0, 0)
      resolve(canvas.toDataURL('image/jpeg', 0.95))
    }
    img.src = dataUrl
  })
}

// ── Composant ─────────────────────────────────────────────────────────────────

export function ScannerModal({ pokemon, discovered, onDiscover, onClose }: Props) {
  const videoRef = useRef<HTMLVideoElement>(null)
  const streamRef = useRef<MediaStream | null>(null)
  const fileRef = useRef<HTMLInputElement>(null)

  const [phase, setPhase] = useState<Phase>('camera')
  const [cameraOk, setCameraOk] = useState(true)
  const [capturedUrl, setCapturedUrl] = useState<string | null>(null)
  const [found, setFound] = useState<Pokemon | null>(null)
  const [progress, setProgress] = useState(0)
  const [alreadyDiscovered, setAlreadyDiscovered] = useState(false)

  // Touche Échap
  useEffect(() => {
    const h = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', h)
    return () => window.removeEventListener('keydown', h)
  }, [onClose])

  // Démarrage caméra
  useEffect(() => {
    if (!navigator.mediaDevices?.getUserMedia) { setCameraOk(false); return }
    let active = true

    navigator.mediaDevices
      .getUserMedia({
        video: { facingMode: 'environment', width: { ideal: 1280 }, height: { ideal: 960 } },
      })
      .then((stream) => {
        if (!active) { stream.getTracks().forEach((t) => t.stop()); return }
        streamRef.current = stream
        if (videoRef.current) videoRef.current.srcObject = stream
      })
      .catch(() => { if (active) setCameraOk(false) })

    return () => {
      active = false
      streamRef.current?.getTracks().forEach((t) => t.stop())
    }
  }, [])

  const stopCamera = useCallback(() => {
    streamRef.current?.getTracks().forEach((t) => t.stop())
    streamRef.current = null
  }, [])

  const runOCR = useCallback(
    async (imageUrl: string) => {
      setPhase('scanning')
      setProgress(0)
      try {
        const processed = await preprocessImage(imageUrl)
        const { createWorker } = await import('tesseract.js')
        const worker = await createWorker('eng', 1, {
          logger: (m: { status: string; progress: number }) => {
            if (m.status === 'recognizing text')
              setProgress(Math.round(m.progress * 100))
          },
        })
        const {
          data: { text },
        } = await worker.recognize(processed)
        await worker.terminate()

        const match = findMatch(text, pokemon)
        if (match) {
          setFound(match)
          setAlreadyDiscovered(discovered.has(match.nom))
          setPhase('result')
        } else {
          setPhase('nomatch')
        }
      } catch (e) {
        console.error('OCR error', e)
        setPhase('error')
      }
    },
    [pokemon, discovered],
  )

  const capture = useCallback(() => {
    const v = videoRef.current
    if (!v) return
    const canvas = document.createElement('canvas')
    canvas.width = v.videoWidth
    canvas.height = v.videoHeight
    canvas.getContext('2d')!.drawImage(v, 0, 0)
    const url = canvas.toDataURL('image/jpeg', 0.92)
    stopCamera()
    setCapturedUrl(url)
    runOCR(url) // démarre l'analyse immédiatement
  }, [stopCamera, runOCR])

  const handleFileChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const file = e.target.files?.[0]
      if (!file) return
      const reader = new FileReader()
      reader.onload = (ev) => {
        const url = ev.target?.result as string
        setCapturedUrl(url)
        runOCR(url)
      }
      reader.readAsDataURL(file)
    },
    [runOCR],
  )

  const retry = useCallback(() => {
    setCapturedUrl(null)
    setFound(null)
    setProgress(0)
    setPhase('camera')
    if (cameraOk) {
      navigator.mediaDevices
        .getUserMedia({ video: { facingMode: 'environment' } })
        .then((stream) => {
          streamRef.current = stream
          if (videoRef.current) videoRef.current.srcObject = stream
        })
        .catch(() => setCameraOk(false))
    }
  }, [cameraOk])

  const confirm = () => {
    if (found) { onDiscover(found); onClose() }
  }

  return (
    <div
      className="fixed inset-0 z-50 bg-black flex flex-col"
      onClick={(e) => e.stopPropagation()}
    >
      {/* Barre du haut */}
      <div className="absolute top-0 left-0 right-0 z-20 flex items-center px-4 py-3 bg-gradient-to-b from-black/70 to-transparent pointer-events-none">
        <button
          onClick={onClose}
          className="text-white text-2xl leading-none p-1 pointer-events-auto"
        >
          <CloseIcon className="w-5 h-5" />
        </button>
        <span className="flex-1 text-center text-white/70 text-sm tracking-widest">
          SCANNER
        </span>
        <div className="w-8" />
      </div>

      {/* ── CAMÉRA ───────────────────────────────────────────────── */}
      {phase === 'camera' && (
        <>
          {cameraOk ? (
            <video
              ref={videoRef}
              autoPlay
              playsInline
              muted
              className="absolute inset-0 w-full h-full object-cover"
            />
          ) : (
            <div className="absolute inset-0 bg-gray-900" />
          )}

          {/* Cadre de guidage */}
          <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
            <div
              className="relative"
              style={{ width: 'min(65vw, 240px)', height: 'min(91vw, 336px)' }}
            >
              {/* Coins colorés */}
              {(
                [
                  'top-0 left-0 border-t-[3px] border-l-[3px] rounded-tl-lg',
                  'top-0 right-0 border-t-[3px] border-r-[3px] rounded-tr-lg',
                  'bottom-0 left-0 border-b-[3px] border-l-[3px] rounded-bl-lg',
                  'bottom-0 right-0 border-b-[3px] border-r-[3px] rounded-br-lg',
                ] as const
              ).map((cls, i) => (
                <div key={i} className={`absolute w-8 h-8 border-shell ${cls}`} />
              ))}
            </div>
            <p className="mt-5 text-white/60 text-xs tracking-wide">
              Cadrez la carte · nom bien visible
            </p>
          </div>

          {/* Boutons bas : capture + upload */}
          <div className="absolute bottom-0 left-0 right-0 flex flex-col items-center gap-3 pb-10 pt-6 bg-gradient-to-t from-black/70 to-transparent">
            {cameraOk ? (
              <>
                {/* Bouton capture rond — style appareil photo */}
                <button
                  onClick={capture}
                  className="w-20 h-20 rounded-full border-4 border-white bg-white/10 hover:bg-white/25 active:scale-95 transition-transform flex items-center justify-center"
                >
                  <div className="w-14 h-14 rounded-full bg-white" />
                </button>
                {/* Upload discret dessous */}
                <button
                  onClick={() => fileRef.current?.click()}
                  className="text-white/50 text-sm hover:text-white/80 transition-colors py-1"
                >
                  📂 ou téléverser une image
                </button>
              </>
            ) : (
              <>
                <p className="text-white/60 text-sm mb-1">Caméra non disponible</p>
                <button
                  onClick={() => fileRef.current?.click()}
                  className={`px-6 py-3 rounded-xl font-bold ${BUTTON_STYLE.gray}`}
                >
                  📂 Choisir une image
                </button>
              </>
            )}
          </div>
        </>
      )}


      {/* ── ANALYSE ──────────────────────────────────────────────── */}
      {phase === 'scanning' && (
        <div className="flex-1 flex flex-col items-center justify-center gap-6 bg-black p-8">
          {capturedUrl && (
            <img
              src={capturedUrl}
              alt=""
              className="w-32 h-44 object-cover rounded-xl opacity-40"
            />
          )}
          <div className="text-center">
            <p className="text-white text-xl mb-1">Analyse en cours…</p>
            <p className="text-gray-500 text-sm mb-5">Lecture OCR de l'image</p>
            <div className="w-56 h-2 bg-gray-800 rounded-full overflow-hidden mx-auto">
              <div
                className="h-full bg-shell rounded-full transition-all duration-200"
                style={{ width: `${progress}%` }}
              />
            </div>
            <p className="text-gray-600 text-xs mt-2">{progress}%</p>
          </div>
        </div>
      )}

      {/* ── RÉSULTAT TROUVÉ ───────────────────────────────────────── */}
      {phase === 'result' && found && (
        <div className="flex-1 flex flex-col items-center justify-center gap-5 bg-app-bg p-8">
          <p className="text-hp-green text-sm tracking-widest uppercase">
            Pokémon identifié !
          </p>

          {found.image_illustree && (
            <img
              src={found.image_illustree}
              alt={found.nom}
              className="w-44 h-44 object-contain"
            />
          )}

          <div className="text-center">
            <p className="text-[#9a9cba] text-sm">#{found.numero}</p>
            <h2 className="text-cream text-3xl">{found.nom}</h2>
          </div>

          {alreadyDiscovered ? (
            <div className="text-center mt-2">
              <p className="text-[#ffd75e] text-sm mb-4">
                Ce Pokémon a déjà été découvert !
              </p>
              <button
                onClick={onClose}
                className={`px-6 py-3 rounded-xl ${BUTTON_STYLE.gray}`}
              >
                Fermer
              </button>
            </div>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mt-2">
              <button
                onClick={retry}
                className={`px-5 py-3 rounded-xl text-sm ${BUTTON_STYLE.gray}`}
              >
                Réessayer
              </button>
              <button
                onClick={confirm}
                className={`px-7 py-3 rounded-xl font-bold ${BUTTON_STYLE.green}`}
              >
                Découvrir !
              </button>
            </div>
          )}
        </div>
      )}

      {/* ── PAS DE RÉSULTAT / ERREUR ──────────────────────────────── */}
      {(phase === 'nomatch' || phase === 'error') && (
        <div className="flex-1 flex flex-col items-center justify-center gap-5 bg-app-bg p-8 text-center">
          <div className="text-6xl">{phase === 'nomatch' ? '🔍' : '⚠️'}</div>
          <div>
            <p className="text-hp-red text-xl mb-2">
              {phase === 'nomatch' ? 'Aucun Pokémon trouvé' : "Erreur d'analyse"}
            </p>
            <p className="text-gray-500 text-sm leading-relaxed max-w-xs">
              {phase === 'nomatch'
                ? 'Assure-toi que le nom est bien net et visible sur la photo.'
                : "Une erreur est survenue lors de l'analyse OCR."}
            </p>
          </div>
          <button
            onClick={retry}
            className={`mt-2 px-6 py-3 rounded-xl font-bold ${BUTTON_STYLE.gray}`}
          >
            Réessayer
          </button>
        </div>
      )}

      {/* Input fichier (fallback caméra indisponible) */}
      {/* Pas de capture="environment" : sur mobile → galerie, sur PC → explorateur de fichiers */}
      <input
        ref={fileRef}
        type="file"
        accept="image/*"
        className="hidden"
        onChange={handleFileChange}
      />
    </div>
  )
}
