import { useState } from 'react'
import { ALL_TYPES, TYPE_SUPER_EFFECTIVE, isTypeSuperEffective, isTypeNoEffect } from '../lib/typeChart'
import { TypeBadge } from './TypeBadge'
import { PixelIcon } from './icons/PixelIcon'
import { STAT_ICON } from '../lib/icons'
import { PANEL } from '../lib/panelStyles'

// Axe sélectionné dans la matrice : une COLONNE (type de capacité, lecture
// offensive) ou une LIGNE (type de pokémon, lecture défensive). Un seul à la
// fois — recliquer le même en-tête désélectionne.
type Selection = { axis: 'offense' | 'defense'; type: string }

// Couleurs des cases : seules les deux issues qui existent dans cette table
// sont marquées (pas de x1/2 dans ce jeu, voir typeChart.ts) — tout le reste
// est neutre.
const CELL_SUPER = 'bg-[#b7e4a8]'
const CELL_NONE = 'bg-[#cfcfcf]'
const CELL_NEUTRAL = 'bg-[#fbf8dc]'

// Matrice récapitulative de la table des types (onglet admin uniquement) : une
// COLONNE par type de CAPACITÉ (lecture offensive, en haut) et une LIGNE par
// type de POKÉMON DÉFENSEUR (lecture défensive, à gauche). Lue directement
// depuis src/lib/typeChart.ts — la même table que celle qu'appliquent les
// badges des écrans de combat, et le miroir exact des fonctions SQL
// type_super_effective/type_no_effect qui, elles, tranchent réellement le
// combat.
export function TypeChartTab() {
  const [selected, setSelected] = useState<Selection | null>(null)

  const toggle = (axis: Selection['axis'], type: string) => {
    setSelected((prev) => (prev?.axis === axis && prev.type === type ? null : { axis, type }))
  }

  // Phrase affichée au clic sur un en-tête. Offensif : ce que CETTE capacité
  // écrase (et ce qu'elle ne peut pas toucher). Défensif : ce à quoi CE
  // pokémon est faible (et ce à quoi il est insensible).
  const strongAgainst = selected ? ALL_TYPES.filter((t) => isTypeSuperEffective(selected.type, t)) : []
  const noEffectOn = selected ? ALL_TYPES.filter((t) => isTypeNoEffect(selected.type, t)) : []
  const weakTo = selected ? ALL_TYPES.filter((atk) => isTypeSuperEffective(atk, selected.type)) : []
  const immuneTo = selected ? ALL_TYPES.filter((atk) => isTypeNoEffect(atk, selected.type)) : []
  const listed = selected?.axis === 'offense' ? strongAgainst : weakTo
  const listedNone = selected?.axis === 'offense' ? noEffectOn : immuneTo

  return (
    // La matrice est plus large que l'écran sur mobile : c'est LA PAGE qui
    // défile horizontalement (overflow-x ici, sur le conteneur d'onglet), pas
    // un cadre à scroll séparé autour du tableau — un seul geste de défilement
    // pour tout le contenu.
    <div className="flex-1 overflow-y-auto overflow-x-auto p-4 flex flex-col gap-4">
      <div className={`${PANEL} p-3 flex flex-col gap-1.5`}>
        <h2 className="flex items-center gap-2 text-ink text-base font-bold">
          <PixelIcon src={STAT_ICON.supereffective} size={22} />
          Table des types
        </h2>
        <p className="text-ink-muted-2 text-xs leading-relaxed">
          L'efficacité dépend du type de la <b>capacité utilisée</b> (en haut) face au type du{' '}
          <b>pokémon défenseur</b> (à gauche) — jamais du type de l'attaquant. Une capacité super efficace{' '}
          <b>double les dégâts de base</b> du pokémon qui l'utilise. Une capacité sans effet ne peut pas être
          jouée contre le type concerné (sauf si elle ne vise pas l'adversaire : soin ou bonus sur soi, météo).
        </p>
        <div className="flex items-center gap-3 flex-wrap mt-1">
          <span className="flex items-center gap-1.5">
            <span className={`w-4 h-4 rounded border-2 border-ink/20 ${CELL_SUPER}`} />
            <span className="text-ink-muted-2 text-xs">Super efficace (×2)</span>
          </span>
          <span className="flex items-center gap-1.5">
            <span className={`w-4 h-4 rounded border-2 border-ink/20 ${CELL_NONE}`} />
            <span className="text-ink-muted-2 text-xs">Aucun effet (×0)</span>
          </span>
          <span className="text-ink-muted-2 text-xs">Cliquez un type en haut ou à gauche pour le détail.</span>
        </div>
      </div>

      {/* Phrase du type sélectionné : au-dessus du tableau pour rester visible
          sans avoir à remonter après un clic en bas de la matrice. */}
      {selected && (
        <div className={`${PANEL} p-3 flex flex-col gap-2`}>
          <div className="flex items-center gap-2 flex-wrap">
            <TypeBadge type={selected.type} small />
            <span className="text-ink text-xs font-bold">
              {selected.axis === 'offense' ? 'capacité de ce type' : 'pokémon de ce type'}
            </span>
          </div>
          <p className="text-ink text-xs leading-relaxed">
            {selected.axis === 'offense'
              ? (listed.length > 0
                ? <>Super efficace (×2) contre <b>{listed.join(', ')}</b>.</>
                : <>Super efficace contre <b>aucun type</b>.</>)
              : (listed.length > 0
                ? <>Faible (×2) aux capacités <b>{listed.join(', ')}</b>.</>
                : <>Faible à <b>aucune capacité</b>.</>)}
          </p>
          {listedNone.length > 0 && (
            <p className="text-ink-muted-2 text-xs leading-relaxed">
              {selected.axis === 'offense'
                ? <>Aucun effet sur <b>{listedNone.join(', ')}</b>.</>
                : <>Insensible aux capacités <b>{listedNone.join(', ')}</b>.</>}
            </p>
          )}
        </div>
      )}

      {/* w-max min-w-full : le panneau épouse la largeur du tableau (il
          dépasse alors l'écran, la page défile — voir le conteneur ci-dessus)
          sans jamais être plus étroit que l'écran quand tout tient. La colonne
          des types défenseurs reste collée à gauche pour ne pas perdre la
          ligne qu'on est en train de lire pendant ce défilement. */}
      <div className={`${PANEL} w-max min-w-full`}>
        <table className="border-collapse">
          <thead>
            <tr>
              <th className="sticky left-0 z-20 bg-white p-1 text-ink text-[10px] font-bold text-right align-bottom">
                Défenseur ↓ / Capacité →
              </th>
              {ALL_TYPES.map((atk) => (
                <th key={atk} className="p-1 align-bottom">
                  <button
                    type="button"
                    onClick={() => toggle('offense', atk)}
                    title={`Capacités ${atk} : voir contre quoi elles sont super efficaces`}
                    className={`block ${selected?.axis === 'offense' && selected.type === atk ? 'ring-4 ring-[#f0c419] rounded' : ''}`}
                  >
                    {/* Écriture verticale : 18 colonnes de badges horizontaux
                        rendraient le tableau illisible sur mobile. */}
                    <span className="[writing-mode:vertical-rl] rotate-180 inline-block">
                      <TypeBadge type={atk} small />
                    </span>
                  </button>
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {ALL_TYPES.map((def) => {
              const rowSelected = selected?.axis === 'defense' && selected.type === def
              return (
                <tr key={def}>
                  <th className="sticky left-0 z-10 bg-white p-1 text-left">
                    <button
                      type="button"
                      onClick={() => toggle('defense', def)}
                      title={`Pokémon ${def} : voir à quoi il est faible`}
                      className={`block w-full text-left ${rowSelected ? 'ring-4 ring-[#f0c419] rounded' : ''}`}
                    >
                      <TypeBadge type={def} small />
                    </button>
                  </th>
                  {ALL_TYPES.map((atk) => {
                    const superEffective = isTypeSuperEffective(atk, def)
                    const noEffect = isTypeNoEffect(atk, def)
                    const colSelected = selected?.axis === 'offense' && selected.type === atk
                    return (
                      <td
                        key={atk}
                        className={`border border-white/70 p-1 text-center text-ink text-[10px] font-bold min-w-[2.2rem] ${
                          superEffective ? CELL_SUPER : noEffect ? CELL_NONE : CELL_NEUTRAL
                        } ${colSelected || rowSelected ? 'outline outline-2 -outline-offset-2 outline-[#f0c419]/60' : ''}`}
                      >
                        {superEffective ? '×2' : noEffect ? '×0' : ''}
                      </td>
                    )
                  })}
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>

      {/* Rappel : la table est un doublon assumé entre le client et le SQL. */}
      <p className="text-ink-muted-2 text-[11px] leading-relaxed">
        Table définie dans <code>src/lib/typeChart.ts</code> (affichage) et dupliquée à l'identique dans les
        fonctions SQL <code>type_super_effective</code> / <code>type_no_effect</code> (qui tranchent le combat) :
        toute modification doit être faite aux deux endroits.
        {' '}Les {ALL_TYPES.length} types couvrent{' '}
        {ALL_TYPES.reduce((n, t) => n + (TYPE_SUPER_EFFECTIVE[t]?.length ?? 0), 0)} relations « super efficace ».
      </p>
    </div>
  )
}
