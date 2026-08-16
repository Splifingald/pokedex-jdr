import { useEffect, useMemo, useState } from 'react'
import { createPortal } from 'react-dom'
import type { Pokemon, PlayerPokemon, Attack, AutoBattleTalent } from '../../types'
import { ownedPokemonName } from '../../types'
import { getEligiblePlayerPokemon, describeTalent } from '../../lib/autoBattle'
import { isTypeSuperEffective } from '../../lib/typeChart'
import { getHpBreakdown, getDamageBreakdown } from '../../lib/xpBonuses'
import { normalizeSearch } from '../../lib/normalizeSearch'
import { PANEL, PIXEL_BORDER_SM } from '../../lib/panelStyles'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { STAT_ICON } from '../../lib/icons'
import { PixelIcon } from '../icons/PixelIcon'
import { TypeBadge } from '../TypeBadge'
import { Chip } from '../Chip'
import { AutoBattleLaunchBar } from './AutoBattleLaunchBar'

interface Props {
  roster: PlayerPokemon[]
  pokemonByName: Map<string, Pokemon>
  attacksByName: Map<string, Attack>
  bannedAttacks: Set<string>
  /** Espèce adverse du niveau en cours — undefined si pas encore résolue (ne devrait pas arriver en pratique, voir AutoBattlePopup). */
  opponentSpecies?: Pokemon
  /** Ce niveau a-t-il déjà été joué au moins une fois (autobattle_player_level_state.discovered) — le badge "Super Efficace" ne doit apparaître qu'une fois l'adversaire réellement découvert, jamais en avant-première sur un niveau jamais tenté. */
  opponentDiscovered: boolean
  /** Talents d'espèce (voir autobattle_talents), indexés par nom d'espèce — affichés sur la ligne du milieu. Omis quand la bascule globale du mode est désactivée (autobattle_config/pvp_config.talents_enabled), auquel cas la ligne disparaît plutôt que d'annoncer un effet qui ne se produira pas. */
  talentsByPokemon?: Map<string, AutoBattleTalent[]>
  /** Choix en deux temps (Combat Manuel) : le tap ne fait que sélectionner le pokémon, onSelect n'est appelée qu'au bouton "Lancer" — c'est là que le ticket est débité (voir handleStartManualBattle). Sans ce drapeau (Combat Auto, PvP), le tap appelle onSelect directement : l'écran suivant ne coûte rien. */
  requireLaunch?: boolean
  /** Avec requireLaunch : plus aucun ticket, "Lancer" reste visible mais désactivé. */
  noTicket?: boolean
  onSelect: (pp: PlayerPokemon) => void
  onBack: () => void
}

type SortKey = 'default' | 'type' | 'damage' | 'hp'

/** Bulle de description d'un talent : position en coordonnées FENÊTRE (rendue
 *  dans un portal sur <body>, donc insensible aux ancêtres transformés — la
 *  carte sélectionnée porte un translate qui casserait un simple `fixed`). */
type TalentTip = {
  key: string
  lines: string[]
  left: number
  width: number
  /** Un seul des deux est défini : ancrage sous (top) ou au-dessus (bottom) de la pastille. */
  top?: number
  bottom?: number
  maxHeight: number
}

/** Marge minimale conservée entre la bulle et les bords de l'écran. */
const TIP_MARGIN = 8
/** Écart entre la pastille et sa bulle. */
const TIP_GAP = 4
/** Durée d'affichage automatique de la bulle (ms). */
const TIP_DURATION = 3000

const SORT_LABELS: Record<SortKey, string> = {
  default: 'Équipe',
  type: 'Type & efficacité',
  damage: 'Dégâts',
  hp: 'PV',
}

// Sélection du pokémon combattant — liste (une ligne par pokémon, voir
// requirement dédié) sur le roster Équipe + PC (pension exclue), filtrée aux
// pokémon ayant au moins une capacité apprise non-bannie (voir requirement
// #6/#9). Partagée telle quelle entre Combat Auto (auto ET manuel) et PvP
// (AutoBattlePopup / PvpPopup) — aucune différence d'affichage entre modes.
export function AutoBattlePokemonPicker({ roster, pokemonByName, attacksByName, bannedAttacks, opponentSpecies, opponentDiscovered, talentsByPokemon, requireLaunch, noTicket, onSelect, onBack }: Props) {
  const [sortKey, setSortKey] = useState<SortKey>('default')
  const [query, setQuery] = useState('')
  const [selected, setSelected] = useState<PlayerPokemon | null>(null)
  // Description de talent ouverte (une seule à la fois). Position calculée à
  // l'ouverture et bornée à la fenêtre (horizontalement ET verticalement) pour
  // qu'elle reste entièrement visible, y compris sur mobile et sur les
  // dernières lignes de la liste.
  const [talentTip, setTalentTip] = useState<TalentTip | null>(null)

  // Affichage éphémère : la bulle se ferme d'elle-même au bout de 3 s, ou dès
  // que l'utilisateur fait autre chose (clic n'importe où, scroll, resize) —
  // pas de bascule on/off au reclic, qui la ré-affiche simplement.
  useEffect(() => {
    if (!talentTip) return
    const close = () => setTalentTip(null)
    const timer = window.setTimeout(close, TIP_DURATION)
    // Capture sur `document` et pas `window` : le scroll d'un conteneur interne
    // (le corps de la popup, qui est la seule zone qui défile ici) ne remonte
    // pas jusqu'à window, même en phase de capture.
    document.addEventListener('pointerdown', close, true)
    document.addEventListener('scroll', close, true)
    window.addEventListener('resize', close)
    return () => {
      window.clearTimeout(timer)
      document.removeEventListener('pointerdown', close, true)
      document.removeEventListener('scroll', close, true)
      window.removeEventListener('resize', close)
    }
  }, [talentTip])

  const showTalentInfo = (key: string, lines: string[], anchor: HTMLElement) => {
    const rect = anchor.getBoundingClientRect()
    const width = Math.min(256, window.innerWidth - TIP_MARGIN * 2)
    // Alignée sur la pastille, puis recalée dans l'écran si elle déborde.
    const left = Math.max(TIP_MARGIN, Math.min(rect.left, window.innerWidth - TIP_MARGIN - width))
    const below = window.innerHeight - rect.bottom - TIP_GAP - TIP_MARGIN
    const above = rect.top - TIP_GAP - TIP_MARGIN
    setTalentTip(
      below >= 120 || below >= above
        ? { key, lines, left, width, top: rect.bottom + TIP_GAP, maxHeight: below }
        : { key, lines, left, width, bottom: window.innerHeight - rect.top + TIP_GAP, maxHeight: above }
    )
  }

  const eligible = useMemo(
    () => getEligiblePlayerPokemon(roster, attacksByName, bannedAttacks),
    [roster, attacksByName, bannedAttacks]
  )

  // L'efficacité se joue désormais au niveau de la CAPACITÉ (voir
  // src/lib/typeChart.ts) : un pokémon est annoncé "Super Efficace" dès qu'au
  // moins une de ses capacités apprises (non bannie) est avantageuse contre le
  // type adverse — c'est bien ce que le joueur pourra jouer à l'écran suivant.
  const isSuperEffective = (pp: PlayerPokemon) => {
    if (!opponentDiscovered || opponentSpecies == null) return false
    return pp.moves.some((nom) => {
      const attack = attacksByName.get(nom)
      return attack != null && !bannedAttacks.has(nom) && isTypeSuperEffective(attack.type, opponentSpecies.type)
    })
  }

  const sortedAndFiltered = useMemo(() => {
    const q = normalizeSearch(query.trim())
    const filtered = q ? eligible.filter((pp) => normalizeSearch(ownedPokemonName(pp)).includes(q)) : [...eligible]

    const numeroOf = (pp: PlayerPokemon) => pp.pokemon_numero ?? pokemonByName.get(pp.pokemon_nom)?.numero ?? ''
    const byNumero = (a: PlayerPokemon, b: PlayerPokemon) =>
      numeroOf(a).localeCompare(numeroOf(b), undefined, { numeric: true })

    if (sortKey === 'type') {
      filtered.sort((a, b) => {
        const seA = isSuperEffective(a) ? 0 : 1
        const seB = isSuperEffective(b) ? 0 : 1
        if (seA !== seB) return seA - seB
        const typeA = pokemonByName.get(a.pokemon_nom)?.type ?? ''
        const typeB = pokemonByName.get(b.pokemon_nom)?.type ?? ''
        return typeA.localeCompare(typeB, 'fr') || byNumero(a, b)
      })
    } else if (sortKey === 'damage') {
      filtered.sort((a, b) => {
        const dmgA = getDamageBreakdown(pokemonByName.get(a.pokemon_nom), a.xp).total
        const dmgB = getDamageBreakdown(pokemonByName.get(b.pokemon_nom), b.xp).total
        return dmgB - dmgA || byNumero(a, b)
      })
    } else if (sortKey === 'hp') {
      filtered.sort((a, b) => {
        const hpA = getHpBreakdown(pokemonByName.get(a.pokemon_nom), a.xp).total
        const hpB = getHpBreakdown(pokemonByName.get(b.pokemon_nom), b.xp).total
        return hpB - hpA || byNumero(a, b)
      })
    } else {
      filtered.sort((a, b) => (b.in_team ? 1 : 0) - (a.in_team ? 1 : 0) || byNumero(a, b))
    }
    return filtered
    // eslint-disable-next-line react-hooks/exhaustive-deps -- isSuperEffective ferme sur opponentSpecies/opponentDiscovered/attacksByName/bannedAttacks, déjà dans les deps
  }, [eligible, sortKey, query, pokemonByName, opponentSpecies, opponentDiscovered, attacksByName, bannedAttacks])

  if (eligible.length === 0) {
    return (
      <div className="flex flex-col items-center gap-3 py-6">
        <p className="text-ink-muted-2 text-sm text-center">
          Aucun pokémon avec une capacité apprise (et hors pension) n'est disponible pour combattre.
        </p>
        <button onClick={onBack} className={`text-xs px-3 py-1.5 rounded font-bold ${BUTTON_STYLE.gray}`}>← Retour</button>
      </div>
    )
  }

  return (
    <>
    <div className="flex flex-col gap-3">
      <div className="flex items-center gap-2">
        <button onClick={onBack} className={`text-xs px-2 py-1 rounded font-bold ${BUTTON_STYLE.gray}`}>← Retour</button>
        <h4 className="text-ink text-base font-bold">Choisis ton pokémon</h4>
      </div>

      <input
        type="text"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder="Rechercher un pokémon…"
        className="w-full bg-cream border-2 border-ink rounded-lg px-3 py-2 text-ink text-sm placeholder-ink-muted-2 outline-none"
      />

      <div className="flex items-center gap-1.5 flex-wrap">
        {(Object.keys(SORT_LABELS) as SortKey[]).map((k) => (
          <Chip key={k} label={SORT_LABELS[k]} active={sortKey === k} onClick={() => setSortKey(k)} />
        ))}
      </div>

      {sortedAndFiltered.length === 0 ? (
        <p className="text-ink-muted-2 text-sm text-center py-4">Aucun pokémon ne correspond à cette recherche.</p>
      ) : (
        <div className="flex flex-col gap-2">
          {sortedAndFiltered.map((pp) => {
            const species = pokemonByName.get(pp.pokemon_nom)
            const superEffective = isSuperEffective(pp)
            const damage = getDamageBreakdown(species, pp.xp).total
            const hp = getHpBreakdown(species, pp.xp).total
            // Talents regroupés par NOM : une espèce peut en cumuler plusieurs
            // sous le même libellé (trois bonus conditionnels « Colère », par
            // exemple) — une seule pastille alors, dont le panneau liste toutes
            // les descriptions.
            const talentGroups = [...(talentsByPokemon?.get(pp.pokemon_nom) ?? [])
              .reduce((map, t) => {
                const label = t.nom || 'Talent'
                const list = map.get(label)
                if (list) list.push(t)
                else map.set(label, [t])
                return map
              }, new Map<string, AutoBattleTalent[]>())]
            const wins = pp.battles_won ?? 0
            return (
              <button
                key={pp.id}
                onClick={() => (requireLaunch ? setSelected(pp) : onSelect(pp))}
                className={`${PANEL} flex items-stretch gap-2.5 p-2 text-left ${
                  selected?.id === pp.id
                    ? 'border-2 border-ink bg-[#f0e08f] shadow-none translate-x-[2px] translate-y-[2px] transition-all'
                    : BUTTON_STYLE.gray
                }`}
              >
                <div className="w-16 h-16 shrink-0 rounded-md border-2 border-ink bg-cream-secondary flex items-center justify-center overflow-hidden">
                  {species?.image_miniature ? (
                    <img src={species.image_miniature} alt="" className="pixelated w-full h-full object-contain" />
                  ) : (
                    <span className="text-ink-muted-2 text-2xl">?</span>
                  )}
                </div>
                <div className="flex-1 min-w-0 flex flex-col justify-center gap-1">
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-ink text-sm font-bold truncate">{ownedPokemonName(pp)}</span>
                    <span className="flex items-center gap-2 shrink-0 text-ink text-xs font-bold">
                      <span className="flex items-center gap-0.5">
                        <PixelIcon src={STAT_ICON.damage} size={14} colored />
                        {damage}
                      </span>
                      <span className="flex items-center gap-0.5">
                        <PixelIcon src={STAT_ICON.hp} size={14} colored />
                        {hp}
                      </span>
                    </span>
                  </div>
                  {/* Ligne du milieu : talents à gauche, efficacité et type à
                      droite. Seul le NOM du talent est affiché — la place est
                      comptée, et l'EFFET s'obtient au clic. */}
                  <div className="flex items-center justify-between gap-2">
                    {/* Pastille = icône talent + nom, la description s'ouvre au
                        clic dans une bulle éphémère (voir showTalentInfo). Des
                        <span role="button"> plutôt que des <button> : toute la
                        carte est déjà un <button>, imbriquer serait invalide. */}
                    <span className="flex items-center gap-1 flex-1 min-w-0 flex-wrap">
                      {talentGroups.map(([label, group]) => {
                        const key = `${pp.id}:${label}`
                        const lines = group.map((t) => describeTalent(t))
                        return (
                          <span
                            key={key}
                            role="button"
                            tabIndex={0}
                            onClick={(e) => { e.stopPropagation(); showTalentInfo(key, lines, e.currentTarget) }}
                            onKeyDown={(e) => {
                              if (e.key !== 'Enter' && e.key !== ' ') return
                              e.preventDefault(); e.stopPropagation(); showTalentInfo(key, lines, e.currentTarget)
                            }}
                            className={`inline-flex items-center gap-1 max-w-full px-1.5 py-0.5 rounded text-xs font-bold cursor-pointer ${PIXEL_BORDER_SM} ${
                              talentTip?.key === key ? 'bg-[#f0e08f]' : 'bg-cream'
                            } text-ink`}
                          >
                            <PixelIcon src={STAT_ICON.talent} size={12} colored />
                            <span className="truncate">{label}</span>
                          </span>
                        )
                      })}
                    </span>
                    <span className="flex items-center gap-1.5 shrink-0">
                      {superEffective && (
                        <span className="text-xs font-bold px-1.5 py-0.5 rounded-full text-white bg-[#d9761e] whitespace-nowrap">
                          Super Efficace
                        </span>
                      )}
                      {species && <TypeBadge type={species.type} small />}
                    </span>
                  </div>
                  <div className="text-ink-muted-2 text-xs">
                    🏆 {wins} combat{wins > 1 ? 's' : ''} gagné{wins > 1 ? 's' : ''}
                  </div>
                </div>
              </button>
            )
          })}
        </div>
      )}

      {requireLaunch && selected && (
        <AutoBattleLaunchBar
          label={ownedPokemonName(selected)}
          iconSrc={pokemonByName.get(selected.pokemon_nom)?.image_miniature}
          disabled={noTicket}
          onLaunch={() => onSelect(selected)}
        />
      )}
    </div>

    {/* Bulle de talent : portal sur <body> pour passer au-dessus de toute
        l'UI (popup de combat, barre de lancement…) sans dépendre des
        z-index/overflow locaux, et pour ignorer les ancêtres transformés. */}
    {talentTip && createPortal(
      <div
        role="tooltip"
        style={{
          left: talentTip.left,
          width: talentTip.width,
          top: talentTip.top,
          bottom: talentTip.bottom,
          maxHeight: talentTip.maxHeight,
        }}
        className={`fixed z-[9999] overflow-y-auto p-2 rounded bg-white text-ink text-xs leading-snug font-normal normal-case flex flex-col gap-1 ${PIXEL_BORDER_SM} shadow-[var(--shadow-pixel)]`}
      >
        {talentTip.lines.map((line, i) => <span key={i}>{line}</span>)}
      </div>,
      document.body
    )}
    </>
  )
}
