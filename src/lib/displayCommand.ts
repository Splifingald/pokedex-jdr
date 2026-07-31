import type { ReferenceIndex } from '../hooks/useReferenceIndex'
import type { DisplayAsset, DisplayState } from '../types'
import { addReferenceToDisplay, clearAllLayers, clearLayer, normalizeName, setBackgroundAsset, type DisplayLayer, type UpdateDisplayState } from './displayActions'
import { addToLayer } from './displayLayers'

export type DisplayCommandRefType = 'pokemon' | 'player' | 'background' | 'item'

export type DisplayCommand =
  | { kind: 'add'; refType: DisplayCommandRefType; name: string }
  | { kind: 'clearLayer'; layer: DisplayLayer }
  | { kind: 'clearAll' }

// Libellés français utilisés dans le texte des commandes ("Reference : Pokémon-Pikachu").
export const ADD_TYPE_LABEL: Record<DisplayCommandRefType, string> = {
  pokemon: 'Pokémon',
  player: 'PNJ',
  background: 'Fond',
  item: 'Objet',
}

export const CLEAR_LAYER_LABEL: Record<DisplayLayer, string> = {
  npc: 'PNJ',
  pokemon: 'Pokémon',
  item: 'Objet',
  background: 'Fond',
}

export const CLEAR_ALL_LABEL = 'Tout Effacer'

const ADD_TYPE_TO_REF: Record<string, DisplayCommandRefType> = {
  pokemon: 'pokemon',
  pnj: 'player',
  fond: 'background',
  objet: 'item',
}

const CLEAR_TYPE_TO_LAYER: Record<string, DisplayLayer> = {
  pnj: 'npc',
  pokemon: 'pokemon',
  objet: 'item',
  fond: 'background',
}

// Insensible aux accents pour comparer un jeton capturé ("Pokemon"/"Pokémon") à ses clés.
function tokenKey(s: string): string {
  return s.trim().toLowerCase().replace(/é/g, 'e')
}

function escapeRegExp(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

export function buildAddCommandText(refType: DisplayCommandRefType, name: string): string {
  return `Reference : ${ADD_TYPE_LABEL[refType]}-${name}`
}

export function buildClearLayerCommandText(layer: DisplayLayer): string {
  return `Reference : Effacer ${CLEAR_LAYER_LABEL[layer]}`
}

export const CLEAR_ALL_COMMAND_TEXT = `Reference : ${CLEAR_ALL_LABEL}`

const INTRO_SRC = 'R[ée]f[ée]rence\\s*:\\s*'
const ADD_TYPE_SRC = '(?<addType>Pok[ée]mon|PNJ|Fond|Objet)'
const CLEAR_TYPE_SRC = '(?<clearType>PNJ|Pok[ée]mon|Objet|Fond)'

// Ne capture QUE l'intro + le type + le tiret — le nom qui suit n'a pas de terminateur fiable
// dans du texte libre (pas forcément suivi de ponctuation ou d'un saut de ligne s'il est inséré
// au milieu d'un paragraphe), donc il est résolu séparément via le dictionnaire de noms connus.
const ADD_PREFIX_MATCHER = new RegExp(`${INTRO_SRC}${ADD_TYPE_SRC}-`, 'giu')

const CLEAR_MATCHER = new RegExp(`${INTRO_SRC}(?:(?<clearAll>Tout\\s+Effacer)|Effacer\\s+${CLEAR_TYPE_SRC})`, 'giu')

// Dictionnaire de noms connus pour délimiter le nom d'une commande "add" : les entités du
// journal (Pokémon/PNJ/lieux/capacités/objets) ET les display_assets (PNJ/fonds), puisqu'une
// commande peut désormais cibler un fond ou un PNJ qui n'existe que comme image d'affichage,
// sans entrée correspondante dans le référencement classique.
function buildKnownNameMatcher(index: ReferenceIndex, displayAssets: DisplayAsset[]): RegExp {
  const names = new Set<string>()
  for (const e of index.entries) if (e.name?.trim()) names.add(e.name)
  for (const a of displayAssets) if (a.nom?.trim()) names.add(a.nom)
  if (names.size === 0) return /(?!)/
  const pattern = [...names]
    .sort((a, b) => b.length - a.length)
    .map(escapeRegExp)
    .join('|')
  return new RegExp(`^(?<![\\p{L}\\p{N}_])(?:${pattern})(?![\\p{L}\\p{N}_])`, 'iu')
}

function resolveKnownNameAt(remainder: string, knownNameMatcher: RegExp): string | null {
  const m = knownNameMatcher.exec(remainder)
  return m ? m[0] : null
}

export interface DisplayCommandMatch {
  from: number
  to: number
  text: string
}

// Scanne un texte pour toutes les commandes d'affichage qu'il contient, en résolvant le nom
// des commandes "add" via le dictionnaire de noms connus (repli sur le premier mot si le nom
// n'est reconnu nulle part, pour que la commande reste visible/cliquable même en cas de typo).
export function scanDisplayCommands(text: string, index: ReferenceIndex, displayAssets: DisplayAsset[]): DisplayCommandMatch[] {
  const matches: DisplayCommandMatch[] = []

  CLEAR_MATCHER.lastIndex = 0
  let m: RegExpExecArray | null
  while ((m = CLEAR_MATCHER.exec(text))) {
    matches.push({ from: m.index, to: m.index + m[0].length, text: m[0] })
    if (m.index === CLEAR_MATCHER.lastIndex) CLEAR_MATCHER.lastIndex++
  }

  const knownNameMatcher = buildKnownNameMatcher(index, displayAssets)
  ADD_PREFIX_MATCHER.lastIndex = 0
  while ((m = ADD_PREFIX_MATCHER.exec(text))) {
    const prefixEnd = m.index + m[0].length
    const remainder = text.slice(prefixEnd)
    const name = resolveKnownNameAt(remainder, knownNameMatcher) ?? remainder.match(/^\S+/)?.[0]
    if (name) {
      matches.push({ from: m.index, to: prefixEnd + name.length, text: text.slice(m.index, prefixEnd + name.length) })
    }
    if (m.index === ADD_PREFIX_MATCHER.lastIndex) ADD_PREFIX_MATCHER.lastIndex++
  }

  return matches.sort((a, b) => a.from - b.from)
}

export function findCommandRanges(text: string, index: ReferenceIndex, displayAssets: DisplayAsset[]): Array<{ from: number; to: number }> {
  return scanDisplayCommands(text, index, displayAssets).map(({ from, to }) => ({ from, to }))
}

// Résout un nom de commande "Fond" vers le display_asset correspondant — partagé entre
// l'exécution de la commande (push vers l'Affichage) et son rendu en bannière inline dans
// l'éditeur/la vue du chapitre.
export function resolveBackgroundAsset(name: string, displayAssets: DisplayAsset[]): DisplayAsset | null {
  return displayAssets.find((a) => a.type === 'Background' && normalizeName(a.nom) === normalizeName(name)) ?? null
}

const PARSE_MATCHER = new RegExp(
  `^${INTRO_SRC}(?:(?<clearAll>Tout\\s+Effacer)|Effacer\\s+${CLEAR_TYPE_SRC}|${ADD_TYPE_SRC}-(?<addName>.+))$`,
  'iu'
)

// Reçoit exactement le texte d'un DisplayCommandMatch (déjà borné par scanDisplayCommands) —
// pas besoin de re-délimiter le nom ici, juste d'en extraire les groupes nommés.
export function parseDisplayCommandMatch(matchText: string): DisplayCommand | null {
  const m = PARSE_MATCHER.exec(matchText)
  if (!m || !m.groups) return null
  if (m.groups.clearAll) return { kind: 'clearAll' }
  if (m.groups.clearType) {
    const layer = CLEAR_TYPE_TO_LAYER[tokenKey(m.groups.clearType)]
    if (!layer) return null
    return { kind: 'clearLayer', layer }
  }
  if (m.groups.addType && m.groups.addName) {
    const refType = ADD_TYPE_TO_REF[tokenKey(m.groups.addType)]
    if (!refType) return null
    return { kind: 'add', refType, name: m.groups.addName.trim() }
  }
  return null
}

interface ExecuteDisplayCommandContext {
  referenceIndex: ReferenceIndex
  displayState: DisplayState
  displayAssets: DisplayAsset[]
  updateDisplayState: UpdateDisplayState
  showToast: (message: string) => void
}

export function executeDisplayCommand(cmd: DisplayCommand, ctx: ExecuteDisplayCommandContext): void {
  if (cmd.kind === 'clearAll') {
    clearAllLayers(ctx.updateDisplayState)
    return
  }
  if (cmd.kind === 'clearLayer') {
    clearLayer(cmd.layer, ctx.updateDisplayState)
    return
  }

  // Fond : cible directement les display_assets de type Background, indépendamment de la
  // carte/des lieux référencés (un fond peut ne correspondre à aucun lieu réel).
  if (cmd.refType === 'background') {
    const asset = resolveBackgroundAsset(cmd.name, ctx.displayAssets)
    if (!asset) {
      ctx.showToast(`Aucun fond d'écran trouvé pour ${cmd.name}`)
      return
    }
    setBackgroundAsset(asset.id, ctx.updateDisplayState)
    return
  }

  // PNJ : d'abord un vrai Joueur/PNJ référencé (résolu comme dans les popups, par nom vers
  // display_assets), sinon une figure PNJ qui n'existe que comme image d'affichage.
  if (cmd.refType === 'player') {
    const entry = ctx.referenceIndex.lookup.get(cmd.name.toLowerCase())
    if (entry && entry.type === 'player') {
      const ok = addReferenceToDisplay(entry, ctx.displayState, ctx.displayAssets, ctx.updateDisplayState)
      if (!ok) ctx.showToast(`Aucune image d'affichage trouvée pour ${cmd.name}`)
      return
    }
    const asset = ctx.displayAssets.find((a) => a.type === 'NPC' && normalizeName(a.nom) === normalizeName(cmd.name))
    if (!asset) {
      ctx.showToast(`Référence introuvable : ${cmd.name}`)
      return
    }
    ctx.updateDisplayState({ npc_ids: addToLayer(ctx.displayState.npc_ids, asset.id) })
    return
  }

  // Pokémon / Objet : toujours une entité réelle du référencement.
  const entry = ctx.referenceIndex.lookup.get(cmd.name.toLowerCase())
  if (!entry || entry.type !== cmd.refType) {
    ctx.showToast(`Référence introuvable : ${cmd.name}`)
    return
  }
  const ok = addReferenceToDisplay(entry, ctx.displayState, ctx.displayAssets, ctx.updateDisplayState)
  if (!ok) {
    ctx.showToast(`Aucune image d'affichage trouvée pour ${cmd.name}`)
  }
}
