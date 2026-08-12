import type { Attack } from '../../types'
import { ReferencePopupShell } from './ReferencePopupShell'
import { AttackDetailCard } from '../AttackDetailCard'
import { TypeBadge } from '../TypeBadge'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { useToast } from '../../context/ToastContext'

interface AddToPokemonAction {
  pokemonName: string
  /** true si le Pokémon a déjà atteint son nombre max de capacités */
  atCap: boolean
  /** Message affiché en toast si on clique alors que atCap est vrai */
  atCapMessage: string
  onAdd: () => void
}

interface Props {
  attack: Attack
  onClose: () => void
  elevated?: boolean
  /** Fourni uniquement depuis la fiche d'un Pokémon possédé, pour une capacité qu'il ne connaît pas encore */
  addToPokemon?: AddToPokemonAction
}

export function AbilityReferencePopup({ attack, onClose, elevated, addToPokemon }: Props) {
  const { showToast } = useToast()

  const handleAddClick = () => {
    if (!addToPokemon) return
    if (addToPokemon.atCap) {
      showToast(addToPokemon.atCapMessage)
      return
    }
    addToPokemon.onAdd()
  }

  return (
    <ReferencePopupShell icon="🥊" title={attack.nom} onClose={onClose} elevated={elevated}>
      <div className="mb-3">
        <TypeBadge type={attack.type} small />
      </div>
      <AttackDetailCard attack={attack} />

      {addToPokemon && (
        <button
          onClick={handleAddClick}
          className={`w-full mt-4 py-2.5 rounded-lg text-sm font-bold ${
            addToPokemon.atCap ? 'bg-[#3a3c58] text-[#7a7c9a] border-2 border-[#6a6a6a]' : BUTTON_STYLE.green
          }`}
        >
          + Ajouter à {addToPokemon.pokemonName}
        </button>
      )}
    </ReferencePopupShell>
  )
}
