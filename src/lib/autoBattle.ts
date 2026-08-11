import type { Attack, Item, PlayerPokemon, AutoBattleLevelReward, AutoBattleStatusEffect, AutoBattleAbilityRule } from '../types'
import { getStatusInfo, type StatusId } from './status'

// Libellés propres à Combat Auto (alignés sur les libellés du CSV des
// attaques), mais couleur et icône RÉUTILISÉES du système de statut déjà
// affiché sur la fiche Pokémon (src/lib/status.ts, StatusSelect,
// PokemonOwnedCard) plutôt que redéfinies ici, pour rester visuellement
// cohérent entre les deux écrans.
export const STATUS_EFFECT_LABEL: Record<AutoBattleStatusEffect, string> = {
  paralysis: 'Paralysie',
  fear: 'Peur',
  confusion: 'Confusion',
  sleep: 'Sommeil',
  burn: 'Brûlure',
  poison: 'Poison',
  frozen: 'Gel',
}

const STATUS_ID_BY_EFFECT: Record<AutoBattleStatusEffect, StatusId> = {
  paralysis: 'paralysie',
  fear: 'apeure',
  confusion: 'confusion',
  sleep: 'endormi',
  burn: 'brule',
  poison: 'empoisonne',
  frozen: 'gele',
}

// Couleur + icône pixel-art (iconSrc) du statut équivalent sur la fiche
// Pokémon — voir getStatusInfo. `label` reste celui du CSV Combat Auto
// (STATUS_EFFECT_LABEL ci-dessus), pas celui de la fiche Pokémon. iconSrc
// est optionnel dans StatusInfo (le statut 'aucun' n'en a pas) mais toujours
// défini pour les 7 statuts mappés ici, d'où le non-null assertion.
export function getStatusEffectDisplay(status: AutoBattleStatusEffect) {
  const info = getStatusInfo(STATUS_ID_BY_EFFECT[status])
  return { label: STATUS_EFFECT_LABEL[status], color: info.color, iconSrc: info.iconSrc! }
}

// CSV des attaques (colonne "Mini-game status") → valeur interne. Casse et
// accents doivent correspondre exactement aux libellés du CSV.
const STATUS_EFFECT_BY_CSV_LABEL: Record<string, AutoBattleStatusEffect> = {
  'Paralysie': 'paralysis',
  'Peur': 'fear',
  'Confusion': 'confusion',
  'Sommeil': 'sleep',
  'Brûlure': 'burn',
  'Poison': 'poison',
  'Gel': 'frozen',
}
export function parseStatusEffectCsvLabel(label: string | undefined | null): AutoBattleStatusEffect | null {
  const trimmed = label?.trim()
  if (!trimmed) return null
  return STATUS_EFFECT_BY_CSV_LABEL[trimmed] ?? null
}

// Une capacité "offensive" est une capacité qui inflige quelque chose : soit
// des dégâts de base, soit un dé (voire les deux) — une capacité à 0 dégâts
// de base mais avec un dé reste utilisable, seule une capacité totalement
// sans dégâts (case vide/0 partout en CSV, capacité de statut/effet pur) est
// exclue.
export function isDamagingAbility(attack: Attack): boolean {
  const hasBase = attack.degats_base != null && attack.degats_base > 0
  const hasDice = attack.degats_de != null && attack.degats_de > 0
  return hasBase || hasDice
}

// Capacités effectivement apprises par cette instance (playerPokemon.moves),
// hors capacités bannies (trop puissantes pour ce mode, voir
// autobattle_banned_attacks / AdminAutoBattleBannedAttacksPanel) — seules
// celles-ci sont sélectionnables en Combat Auto (voir
// AutoBattleAbilityPicker). Plus de restriction aux capacités offensives : le
// système de ban gère désormais toutes les limitations manuellement. Note :
// moves n'est PAS restreint au pool attaque_1..10 de l'espèce (voir
// PokemonDetailSheet.tsx où addableMoves propose tout le catalogue
// d'attaques, pas seulement celles de l'espèce) — il ne faut donc jamais
// recroiser avec ce pool ici.
export function getEligibleAbilities(
  playerMoves: string[],
  attacksByName: Map<string, Attack>,
  bannedAttacks: Set<string> = new Set()
): Attack[] {
  return playerMoves
    .map((nom) => attacksByName.get(nom))
    .filter((a): a is Attack => a != null && !bannedAttacks.has(a.nom))
}

// Pokémon du joueur pouvant participer à un combat : ni en pension, ni sans
// capacité apprise non-bannie (voir requirement #6/#9 du cahier des charges).
export function getEligiblePlayerPokemon(
  roster: PlayerPokemon[],
  attacksByName: Map<string, Attack>,
  bannedAttacks: Set<string> = new Set()
): PlayerPokemon[] {
  return roster.filter((pp) => !pp.in_daycare && getEligibleAbilities(pp.moves, attacksByName, bannedAttacks).length > 0)
}

// Récompense à prévisualiser sous un niveau donné de la bannière de
// progression (voir requirement #31) : s'il y a un ou plusieurs objets
// (item/badge — mécaniquement identiques, voir types.ts), on affiche celui
// de plus haute valeur (prix d'achat) ; sinon on retombe sur la récompense XP.
export function pickLevelBannerReward(
  rewards: AutoBattleLevelReward[],
  itemsByName: Map<string, Item>
): AutoBattleLevelReward | null {
  const itemRewards = rewards.filter((r) => r.reward_type === 'item' || r.reward_type === 'badge')
  if (itemRewards.length > 0) {
    return [...itemRewards].sort((a, b) => {
      const va = itemsByName.get(a.item_nom ?? '')?.achat ?? 0
      const vb = itemsByName.get(b.item_nom ?? '')?.achat ?? 0
      return vb - va
    })[0]
  }
  return rewards.find((r) => r.reward_type === 'xp') ?? null
}

// crypto.randomUUID() n'existe que dans un contexte sécurisé (HTTPS ou
// localhost) — indisponible si l'app est ouverte via l'IP locale du réseau
// en HTTP simple (cas courant pour cette PWA auto-hébergée). Repli sur un
// générateur RFC4122 v4 manuel (via crypto.getRandomValues si dispo, sinon
// Math.random) pour que la clé d'idempotence du combat reste disponible
// dans tous les contextes.
export function generateIdempotencyKey(): string {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID()
  }
  const bytes = new Uint8Array(16)
  if (typeof crypto !== 'undefined' && typeof crypto.getRandomValues === 'function') {
    crypto.getRandomValues(bytes)
  } else {
    for (let i = 0; i < bytes.length; i++) bytes[i] = Math.floor(Math.random() * 256)
  }
  bytes[6] = (bytes[6] & 0x0f) | 0x40
  bytes[8] = (bytes[8] & 0x3f) | 0x80
  const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('')
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`
}

// Résumé textuel court des effets spéciaux d'une capacité (voir
// autobattle_ability_rules) — une ligne par effet configuré, utilisé par les
// écrans de sélection de capacité en Combat Auto (AutoBattleAbilityPicker,
// avant le combat) ET Combat Manuel (ManualBattleAbilityGrid, pendant le
// combat) pour afficher "ce que fait" une capacité au-delà de dégâts/dé/
// précision/statut déjà montrés séparément ailleurs. turn_effect (rythme des
// tours) pleinement actif dans les deux modes (voir autobattle_resolve_battle
// et autobattle_resolve_manual_round) — inclus ci-dessous.
export function describeAbilityRule(rule: AutoBattleAbilityRule | undefined, ability: Attack): string[] {
  if (!rule) return []
  const lines: string[] = []
  if (rule.turn_effect === 'skip') {
    lines.push('Passe son tour un coup sur deux')
  } else if (rule.turn_effect === 'play_twice') {
    lines.push('Attaque deux fois de suite')
  } else if (rule.turn_effect === 'play_three') {
    lines.push('Attaque trois fois de suite')
  } else if (rule.turn_effect === 'play_random') {
    lines.push(`Attaque entre ${rule.turn_random_min} et ${rule.turn_random_max} fois de suite`)
  } else if (rule.turn_effect === 'repeat_until_fail') {
    lines.push(`Attaque en rafale jusqu'au premier échec (max ${rule.repeat_max_iterations} fois)`)
  } else if (rule.turn_effect === 'prepare_release') {
    lines.push('Nécessite un tour de préparation avant de frapper')
  }
  if (rule.heal_type === 'static' && rule.heal_amount) {
    lines.push(`Soigne ${rule.heal_amount} PV`)
  } else if (rule.heal_type === 'percent_damage' && rule.heal_percent) {
    lines.push(`Soigne ${rule.heal_percent}% des dégâts infligés`)
  } else if (rule.heal_type === 'use_stats') {
    lines.push('Soigne selon ses propres dégâts')
  }
  if (rule.heal_dot_amount && rule.heal_dot_duration_turns) {
    lines.push(`Soigne ${rule.heal_dot_amount} PV/tour pendant ${rule.heal_dot_duration_turns} tours`)
  }
  if (rule.cancel_heal_duration_turns) {
    lines.push(`Annule les soins adverses pendant ${rule.cancel_heal_duration_turns} tours`)
  }
  if (rule.stat_mod_target && rule.stat_mod_stat) {
    const statLabel = rule.stat_mod_stat === 'damage' ? 'dégâts' : 'précision'
    const targetLabel = rule.stat_mod_target === 'opponent' ? "de l'adversaire" : 'de son utilisateur'
    const verb = rule.stat_mod_target === 'opponent' ? 'Réduit' : 'Augmente'
    const amount = rule.stat_mod_value_type === 'flat' ? `${rule.stat_mod_flat}`
      : rule.stat_mod_value_type === 'range' ? `${rule.stat_mod_min}-${rule.stat_mod_max}`
      : `${rule.stat_mod_percent}%`
    const duration = rule.stat_mod_duration_type === 'battle_end' ? "jusqu'à la fin du combat" : `pendant ${rule.stat_mod_duration_turns} tours`
    const usesSuffix = rule.stat_mod_max_uses ? ` (max ${rule.stat_mod_max_uses}×)` : ''
    lines.push(`${verb} les ${statLabel} ${targetLabel} de ${amount} ${duration}${usesSuffix}`)
  }
  if (rule.percent_hp_damage_percent) {
    lines.push(`Inflige ${rule.percent_hp_damage_percent}% des PV restants de la cible (remplace les dégâts habituels)`)
  }
  if (rule.recoil_type === 'range' && rule.recoil_min != null && rule.recoil_max != null) {
    lines.push(rule.recoil_min === rule.recoil_max ? `Contre-coup de ${rule.recoil_min} PV` : `Contre-coup de ${rule.recoil_min}-${rule.recoil_max} PV`)
  } else if (rule.recoil_type === 'percent_damage' && rule.recoil_percent) {
    lines.push(`Contre-coup de ${rule.recoil_percent}% des dégâts infligés`)
  }
  if (rule.bonus_damage_type) {
    const conditionLabel = rule.bonus_damage_condition === 'took_damage_last_turn' ? "s'il a subi des dégâts au tour adverse précédent"
      : rule.bonus_damage_condition === 'first_use' ? "à la 1ère utilisation"
      : rule.bonus_damage_condition === 'dice_equals' ? `si le dé tombe sur ${rule.bonus_damage_condition_dice_value}`
      : rule.bonus_damage_condition === 'has_status'
        ? (rule.bonus_damage_status_filter ? `s'il est ${STATUS_EFFECT_LABEL[rule.bonus_damage_status_filter].toLowerCase()}` : "s'il est affecté par un statut (n'importe lequel)")
      : ''
    const bonusLabel = rule.bonus_damage_type === 'multiply' ? `dégâts ×${rule.bonus_damage_multiplier}`
      : rule.bonus_damage_type === 'flat' ? `+${rule.bonus_damage_flat} dégâts`
      : `+${rule.bonus_damage_min}-${rule.bonus_damage_max} dégâts`
    lines.push(`Bonus : ${bonusLabel} ${conditionLabel}`)
  }
  if (rule.invulnerable_next_turn) {
    lines.push('Rend invulnérable au prochain tour adverse')
  }
  if (ability.status_effect && rule.status_reversed) {
    lines.push('Le statut affecte son utilisateur, pas l\'adversaire')
  }
  return lines
}
