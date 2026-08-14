import { useEffect, useState } from 'react'
import type { Player } from '../../types'

// Face adverse de la pièce. Trois provenances possibles, toutes résolues par
// l'appelant (voir PvpPopup / AutoBattlePopup) :
//   • JcJ  : l'avatar du joueur qui défend le défi ;
//   • JcE  : l'avatar du PNJ rattaché à la variante (autobattle_variants.npc_player_id) ;
//   • JcE sans PNJ : la miniature de l'espèce affrontée.
// Absente (ou sans image), la face retombe sur l'ancien texte "VS".
export interface CoinTossOpponent {
  imageUrl: string
  name: string
  /** Couleur de fond de la face — la couleur du joueur/PNJ ; les espèces n'en ont pas. */
  color?: string
  /** 'cover' pour un avatar (photo cadrée plein), 'contain' pour une miniature de pokémon (sprite sur fond uni). */
  fit: 'cover' | 'contain'
}

interface Props {
  player: Player
  opponent?: CoinTossOpponent | null
  firstAttacker: 'player' | 'opponent'
  onDone: () => void
}

const SPIN_MS = 1800
const HOLD_MS = 1400

// Tirage au sort visuel — le résultat est déjà décidé côté serveur
// (autobattle_resolve_battle), ce composant se contente de l'animer puis
// d'annoncer le vainqueur (jamais de tirage côté client, voir requirement #12).
// La pièce a deux faces empilées en 3D (adversaire / avatar du joueur) et
// pivote réellement sur l'axe X (rotateX) via une transition CSS, plutôt qu'un
// simple tremblement — elle s'arrête sur la face du résultat.
export function AutoBattleCoinToss({ player, opponent, firstAttacker, onDone }: Props) {
  const [spinning, setSpinning] = useState(false)
  const [revealed, setRevealed] = useState(false)

  useEffect(() => {
    const startTimer = window.setTimeout(() => setSpinning(true), 30)
    const revealTimer = window.setTimeout(() => setRevealed(true), SPIN_MS)
    const doneTimer = window.setTimeout(onDone, SPIN_MS + HOLD_MS)
    return () => { clearTimeout(startTimer); clearTimeout(revealTimer); clearTimeout(doneTimer) }
    // eslint-disable-next-line react-hooks/exhaustive-deps -- ne doit s'exécuter qu'au montage
  }, [])

  // La pièce atterrit sur la face joueur si le joueur attaque en premier,
  // sur la face adverse sinon (nombre de tours entiers arbitraire pour l'effet visuel).
  const targetDeg = 360 * 4 + (firstAttacker === 'player' ? 180 : 0)

  return (
    <div className="flex flex-col items-center justify-center gap-5 py-10">
      <div style={{ perspective: 800 }}>
        <div
          className="relative w-28 h-28"
          style={{
            transformStyle: 'preserve-3d',
            transition: `transform ${SPIN_MS}ms cubic-bezier(0.2, 0.75, 0.25, 1)`,
            transform: spinning ? `rotateX(${targetDeg}deg)` : 'rotateX(0deg)',
          }}
        >
          <div
            className="absolute inset-0 rounded-full border-[3px] border-ink shadow-[var(--shadow-pixel)] overflow-hidden flex items-center justify-center"
            style={{
              backfaceVisibility: 'hidden',
              // Une miniature de pokémon (fit 'contain') est un sprite détouré :
              // elle a besoin d'un fond clair, pas de la couleur d'un joueur.
              backgroundColor: opponent
                ? (opponent.color ?? 'var(--color-cream-secondary)')
                : '#e0293f',
            }}
          >
            {opponent?.imageUrl ? (
              <img
                src={opponent.imageUrl}
                alt={opponent.name}
                className={opponent.fit === 'contain' ? 'pixelated w-4/5 h-4/5 object-contain' : 'w-full h-full object-cover'}
              />
            ) : (
              <span className="text-white text-2xl font-bold">VS</span>
            )}
          </div>
          <div
            className="absolute inset-0 rounded-full border-[3px] border-ink shadow-[var(--shadow-pixel)] overflow-hidden flex items-center justify-center"
            style={{ backfaceVisibility: 'hidden', transform: 'rotateX(180deg)', backgroundColor: player.color }}
          >
            {player.image_url ? (
              <img src={player.image_url} alt={player.name} className="w-full h-full object-cover" />
            ) : (
              <span className="text-white text-3xl">?</span>
            )}
          </div>
        </div>
      </div>
      <p className="text-ink text-base font-bold text-center animate-[celebrate-pop_0.4s_ease-out]">
        {!revealed
          ? 'Qui attaque en premier ?'
          : firstAttacker === 'player'
            ? `${player.name} attaque en premier !`
            : opponent
              ? `${opponent.name} attaque en premier !`
              : "L'adversaire attaque en premier !"}
      </p>
    </div>
  )
}
