import { useState, useEffect, useCallback } from 'react'
import type { RealtimeChannel } from '@supabase/supabase-js'
import { supabase } from '../lib/supabase'
import { cellKey } from '../lib/onlineBoard'

// Pings de case : cliquer une case la fait pulser chez tout le monde pendant
// deux secondes, avec le nom de qui a pointé. C'est le remplaçant, bien plus
// économe, d'un curseur diffusé en continu — un ping par clic au lieu d'une
// vingtaine de messages par seconde et par participant.
//
// Seule partie du mode En ligne qui NE passe PAS par Postgres : ce sont des
// messages éphémères sur un canal Realtime « broadcast », API que le reste du
// projet n'utilise pas encore (tous les autres canaux sont des
// postgres_changes). Deux points d'attention :
//  - le nom du canal doit être FIXE, sans le suffixe aléatoire des canaux
//    postgres_changes, sinon chacun diffuse dans son propre salon ;
//  - `send()` avant l'état SUBSCRIBED est silencieusement ignoré.

const CHANNEL = 'online-board-pings'
/** Délai avant de vraiment quitter le salon quand plus personne ne l'écoute. */
const CLOSE_DELAY_MS = 1500
/** Durée pleinement visible, avant l'effacement en fondu. */
const PING_MS = 2000
/** Fondu de sortie : le ping s'efface au lieu de disparaître d'un coup.
 *  Doit rester aligné sur l'animation ping-fade-out de index.css. */
const FADE_MS = 1000

export interface BoardPing {
  cid: string
  col: number
  row: number
  name: string
  color: string
  /** Sert de clé de rendu : un nouveau ping du même client doit repartir du
   *  début de l'animation, donc produire un élément neuf. */
  startedAt: number
  expiresAt: number
}

interface PingPayload {
  cid: string
  col: number
  row: number
  name: string
  color: string
}

// ── Canal partagé ────────────────────────────────────────────
// Le salon porte un nom FIXE (c'est ce qui met tout le monde en relation), donc
// un même client ne doit le rejoindre qu'une fois. Sans ça, deux instances du
// hook — ou simplement le double montage des effets de React en développement —
// rejoignent le même salon puis le quittent : le serveur cesse alors de router
// les messages vers cette socket, et le client émet sans plus rien recevoir.
// Un canal unique à compteur de références, fermé avec un léger différé, évite
// à la fois le doublon et le battement montage/démontage.
type PingHandler = (p: PingPayload) => void
const handlers = new Set<PingHandler>()
let sharedChannel: RealtimeChannel | null = null
let sharedRefs = 0
let sharedSubscribed = false
let closeTimer: ReturnType<typeof setTimeout> | null = null

function acquirePingChannel(): RealtimeChannel {
  if (closeTimer) {
    clearTimeout(closeTimer)
    closeTimer = null
  }
  sharedRefs += 1
  if (!sharedChannel) {
    sharedSubscribed = false
    const ch = supabase.channel(CHANNEL, { config: { broadcast: { self: false } } })
    ch.on('broadcast', { event: 'ping' }, ({ payload }) => {
      handlers.forEach((h) => h(payload as PingPayload))
    }).subscribe((status) => {
      sharedSubscribed = status === 'SUBSCRIBED'
    })
    sharedChannel = ch
  }
  return sharedChannel
}

function releasePingChannel(): void {
  sharedRefs = Math.max(0, sharedRefs - 1)
  if (sharedRefs > 0) return
  closeTimer = setTimeout(() => {
    closeTimer = null
    if (sharedRefs > 0 || !sharedChannel) return
    const ch = sharedChannel
    sharedChannel = null
    sharedSubscribed = false
    void supabase.removeChannel(ch)
  }, CLOSE_DELAY_MS)
}

interface Options {
  enabled: boolean
  playerName: string
  playerColor: string
  /** false pour l'écran /display : il regarde les pings sans jamais en émettre. */
  canSend: boolean
}

export function useOnlinePings({ enabled, playerName, playerColor, canSend }: Options) {
  const [pings, setPings] = useState<BoardPing[]>([])
  // Identité du client, pas du joueur : deux onglets ouverts sur le même
  // personnage doivent pouvoir pinger chacun de leur côté. Initialiseur
  // paresseux : évalué une seule fois, à la différence d'un appel direct
  // pendant le rendu.
  const [cid] = useState(() => Math.random().toString(36).slice(2))

  const push = useCallback((p: PingPayload) => {
    // Un ping par personne à la fois : re-cliquer déplace le sien.
    const now = Date.now()
    setPings((prev) => [...prev.filter((x) => x.cid !== p.cid), { ...p, startedAt: now, expiresAt: now + PING_MS + FADE_MS }])
  }, [])

  useEffect(() => {
    // Rien à nettoyer ici : le nettoyage de l'exécution précédente a déjà vidé
    // la liste quand `enabled` retombe à false.
    if (!enabled) return
    const handler: PingHandler = (p) => {
      if (p?.cid && p.cid !== cid) push(p)
    }
    handlers.add(handler)
    acquirePingChannel()

    // Une seule minuterie pour tout le monde : on purge ce qui a expiré.
    const sweep = setInterval(() => {
      const now = Date.now()
      setPings((prev) => (prev.some((p) => p.expiresAt <= now) ? prev.filter((p) => p.expiresAt > now) : prev))
    }, 250)

    return () => {
      clearInterval(sweep)
      handlers.delete(handler)
      releasePingChannel()
      setPings([])
    }
  }, [enabled, cid, push])

  /** Pinge une case. L'émetteur voit son propre ping immédiatement : le canal
   *  est configuré avec `self: false`, il ne se reçoit donc pas lui-même. */
  const sendPing = useCallback((col: number, row: number) => {
    if (!canSend) return
    const payload: PingPayload = { cid, col, row, name: playerName, color: playerColor }
    push(payload)
    if (!sharedChannel || !sharedSubscribed) return
    void sharedChannel.send({ type: 'broadcast', event: 'ping', payload })
  }, [cid, canSend, playerName, playerColor, push])

  /** Ping le plus récent par case, pour le rendu. */
  const pingByCell = new Map<string, BoardPing>()
  for (const p of pings) pingByCell.set(cellKey(p.col, p.row), p)

  return { pings, pingByCell, sendPing }
}
