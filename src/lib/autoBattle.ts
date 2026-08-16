import type {
  Attack, Item, PlayerPokemon, AutoBattleLevelReward, AutoBattleStatusEffect, AutoBattleAbilityRule,
  AutoBattleTalent, AutoBattleTalentKind, AutoBattleTalentTrigger,
  AutoBattleWeatherEffect, AutoBattleWeatherEffectKind, AutoBattleWeatherTargetScope,
  AutoBattleWeatherCondition, AutoBattleTurn,
} from '../types'
import { getStatusInfo, type StatusId } from './status'
import { isAbsolutePrecision } from './precisionColor'

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

/**
 * Sens d'un modificateur de stat : la cible et le sens sont deux réglages
 * indépendants (une capacité peut se baisser une stat à elle-même). Les règles
 * écrites avant l'ajout de stat_mod_direction n'ont pas de sens explicite : on
 * retombe alors sur l'ancienne convention (adversaire = baisse, soi = hausse),
 * exactement comme autobattle_stat_mod_signed côté SQL.
 */
export function isStatModDebuff(rule: Pick<AutoBattleAbilityRule, 'stat_mod_target' | 'stat_mod_direction'>): boolean {
  return (rule.stat_mod_direction ?? (rule.stat_mod_target === 'opponent' ? 'debuff' : 'buff')) === 'debuff'
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
// moves n'est PAS restreint au pool attaque_1..15 de l'espèce (voir
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

// Libellé de la condition de dégâts additionnels 'weight_ratio' (comparaison
// des POIDS des deux espèces, voir AutoBattleAbilityRule.bonus_damage_weight_*
// et son miroir SQL autobattle_weight_condition). Le « 100 % » se dit
// simplement « plus lourd / plus léger que », les autres pourcentages
// s'écrivent tels quels.
export function describeWeightCondition(rule: AutoBattleAbilityRule): string {
  const percent = rule.bonus_damage_weight_percent ?? 100
  const heavier = rule.bonus_damage_weight_comparison !== 'lower'
  const subject = rule.bonus_damage_weight_target === 'opponent' ? "si l'adversaire pèse" : "s'il pèse"
  const other = rule.bonus_damage_weight_target === 'opponent' ? 'son poids' : 'le poids de l’adversaire'
  if (percent === 100) {
    return `${subject} ${heavier ? 'plus' : 'moins'} que ${other}`
  }
  return `${subject} ${heavier ? 'plus' : 'moins'} de ${percent}% de ${other}`
}

// Résumé textuel court des effets spéciaux d'une capacité (voir
// autobattle_ability_rules) — une ligne par effet configuré, utilisé par les
// écrans de sélection de capacité en Combat Auto (AutoBattleAbilityPicker,
// avant le combat) ET Combat Manuel (ManualBattleAbilityGrid, pendant le
// combat) pour afficher "ce que fait" une capacité au-delà de dégâts/dé/
// précision/statut déjà montrés séparément ailleurs. turn_effect (rythme des
// tours) pleinement actif dans les deux modes (voir autobattle_resolve_battle
// et autobattle_resolve_manual_round) — inclus ci-dessous.
// `weatherNames` : noms des météos par id (la règle ne stocke qu'un id) — absent,
// les lignes météo restent correctes mais parlent d'« une météo ».
export function describeAbilityRule(
  rule: AutoBattleAbilityRule | undefined,
  ability: Attack,
  weatherNames?: Map<number, string>,
): string[] {
  if (!rule) return []
  const lines: string[] = []
  const weatherNom = (id: number | null) => (id != null ? weatherNames?.get(id) ?? null : null)
  if (rule.turn_effect === 'skip') {
    lines.push('Passe son tour 1 fois sur 2')
  } else if (rule.turn_effect === 'play_twice') {
    lines.push('Attaque 2 fois')
  } else if (rule.turn_effect === 'play_three') {
    lines.push('Attaque 3 fois')
  } else if (rule.turn_effect === 'play_random') {
    lines.push(`Attaque ${rule.turn_random_min} à ${rule.turn_random_max} fois`)
  } else if (rule.turn_effect === 'repeat_until_fail') {
    lines.push(`Rafale jusqu'au 1er échec (max ${rule.repeat_max_iterations})`)
  } else if (rule.turn_effect === 'prepare_release') {
    lines.push('1 tour de préparation')
  } else if (rule.turn_effect === 'charge_double_next') {
    lines.push('Rien ce tour, joue 2 fois au suivant')
  } else if (rule.turn_effect === 'first_and_replay') {
    lines.push('Rejoue aussitôt et passe premier')
  }
  if (rule.keep_going_turns || rule.keep_going_until_fail) {
    lines.push(rule.keep_going_until_fail
      ? "Se rejoue seul jusqu'au 1er raté"
      : `Se rejoue seul ${rule.keep_going_turns} tour${(rule.keep_going_turns ?? 0) > 1 ? 's' : ''} de plus (stop au 1er raté)`)
    if (rule.keep_going_bonus_type === 'flat' && rule.keep_going_bonus_flat) {
      lines.push(`+${rule.keep_going_bonus_flat} dégâts cumulés par réutilisation`)
    } else if (rule.keep_going_bonus_type === 'percent_damage' && rule.keep_going_bonus_percent) {
      lines.push(`+${rule.keep_going_bonus_percent}% des dégâts de base cumulés par réutilisation`)
    }
  }
  if (rule.heal_type === 'static' && rule.heal_amount) {
    lines.push(`Soigne ${rule.heal_amount} PV`)
  } else if (rule.heal_type === 'percent_damage' && rule.heal_percent) {
    lines.push(`Soigne ${rule.heal_percent}% des dégâts infligés`)
  } else if (rule.heal_type === 'use_stats') {
    lines.push('Soigne selon ses propres dégâts')
  }
  // Le soin passif dure soit un nombre de tours, soit "jusqu'au réveil"
  // (heal_dot_until_awake, heal_dot_duration_turns alors nul) — seul le
  // suffixe de durée change, le montant se décrit pareil dans les deux cas.
  const healDotDuration = rule.heal_dot_until_awake
    ? "tant qu'il dort"
    : rule.heal_dot_duration_turns ? `pendant ${rule.heal_dot_duration_turns} tours` : null
  if (healDotDuration && rule.heal_dot_type === 'percent_max_hp' && rule.heal_dot_percent) {
    lines.push(`Soigne ${rule.heal_dot_percent}% de ses PV max/tour ${healDotDuration}`)
  } else if (healDotDuration && rule.heal_dot_type === 'percent_damage' && rule.heal_dot_percent) {
    lines.push(`Soigne ${rule.heal_dot_percent}% des dégâts infligés/tour ${healDotDuration}`)
  } else if (healDotDuration && rule.heal_dot_amount) {
    lines.push(`Soigne ${rule.heal_dot_amount} PV/tour ${healDotDuration}`)
  }
  if (rule.cancel_heal_duration_turns) {
    lines.push(`Bloque les soins adverses ${rule.cancel_heal_duration_turns} tours`)
  }
  // Effets persistants OFFENSIFS : posés sur l'adversaire, un pourcentage se
  // comptant toujours sur SES PV max (voir AutoBattleAbilityRule.damage_dot_*).
  if (rule.damage_dot_duration_turns) {
    const amount = rule.damage_dot_type === 'percent_max_hp'
      ? `${rule.damage_dot_percent}% de ses PV max`
      : `${rule.damage_dot_amount} PV`
    lines.push(`Ronge l'adversaire de ${amount}/tour pendant ${rule.damage_dot_duration_turns} tours`)
  }
  if (rule.leech_dot_duration_turns) {
    const amount = rule.leech_dot_type === 'percent_max_hp'
      ? `${rule.leech_dot_percent}% de ses PV max`
      : `${rule.leech_dot_amount} PV`
    lines.push(`Vole ${amount}/tour à l'adversaire pendant ${rule.leech_dot_duration_turns} tours`)
  }
  if (rule.status_dot_duration_turns && rule.status_dot_status) {
    lines.push(`${rule.status_dot_chance}% par tour d'infliger ${STATUS_EFFECT_LABEL[rule.status_dot_status]} pendant ${rule.status_dot_duration_turns} tours`)
  }
  if (rule.clear_damage_dot) {
    lines.push('Dissipe les effets persistants qu\'il subit')
  }
  if (rule.cure_status) {
    lines.push('Guérit son statut')
  }
  if (rule.clear_weather) {
    lines.push('Dissipe la météo en cours')
  }
  if (rule.pierce_immunity_type && rule.pierce_immunity_turns) {
    lines.push(`Ignore l'immunité des ${rule.pierce_immunity_type} pendant ${rule.pierce_immunity_turns} tours`)
  }
  if (rule.requires_target_status) {
    lines.push(`Ne marche que sur une cible sous ${STATUS_EFFECT_LABEL[rule.requires_target_status]}`)
  }
  if (rule.stat_mod_target && rule.stat_mod_stat) {
    // Forme télégraphique « Dégâts adverses -5 (3 tours) » plutôt qu'une phrase
    // complète : c'est la ligne la plus longue du lot, et elle tombe sur des
    // cartes larges d'une demi-colonne en Combat Manuel.
    const statLabel = rule.stat_mod_stat === 'damage' ? 'Dégâts' : 'Précision'
    const targetLabel = rule.stat_mod_target === 'opponent'
      ? (rule.stat_mod_stat === 'damage' ? 'adverses' : 'adverse')
      : (rule.stat_mod_stat === 'damage' ? 'alliés' : 'alliée')
    const sign = isStatModDebuff(rule) ? '-' : '+'
    const amount = rule.stat_mod_value_type === 'flat' ? `${rule.stat_mod_flat}`
      : rule.stat_mod_value_type === 'range' ? `${rule.stat_mod_min}-${rule.stat_mod_max}`
      : `${rule.stat_mod_percent}%`
    const duration = rule.stat_mod_duration_type === 'battle_end' ? '(tout le combat)' : `(${rule.stat_mod_duration_turns} tours)`
    const usesSuffix = rule.stat_mod_max_uses ? ` max ${rule.stat_mod_max_uses}×` : ''
    const typeSuffix = rule.stat_mod_type_filter ? ` — ${rule.stat_mod_type_filter} uniquement` : ''
    const weatherCond = describeWeatherCondition(rule.stat_mod_weather_condition, weatherNom(rule.stat_mod_weather_id))
    const weatherSuffix = weatherCond ? ` — ${weatherCond}` : ''
    lines.push(`${statLabel} ${targetLabel} ${sign}${amount} ${duration}${usesSuffix}${typeSuffix}${weatherSuffix}`)
  }
  if (rule.percent_hp_damage_percent) {
    lines.push(rule.percent_hp_damage_basis === 'max'
      ? `Inflige ${rule.percent_hp_damage_percent}% des PV max de la cible (au lieu des dégâts)`
      : `Inflige ${rule.percent_hp_damage_percent}% des PV restants (au lieu des dégâts)`)
  }
  if (rule.recoil_type === 'range' && rule.recoil_min != null && rule.recoil_max != null) {
    lines.push(rule.recoil_min === rule.recoil_max ? `Contre-coup ${rule.recoil_min} PV` : `Contre-coup ${rule.recoil_min}-${rule.recoil_max} PV`)
  } else if (rule.recoil_type === 'percent_damage' && rule.recoil_percent) {
    lines.push(`Contre-coup ${rule.recoil_percent}% des dégâts`)
  }
  if (rule.bonus_damage_type) {
    const conditionLabel = rule.bonus_damage_condition === 'took_damage_last_turn' ? 'si touché au tour précédent'
      : rule.bonus_damage_condition === 'first_use' ? 'à la 1ère utilisation'
      : rule.bonus_damage_condition === 'dice_equals' ? `si le dé fait ${rule.bonus_damage_condition_dice_value}`
      : rule.bonus_damage_condition === 'has_status'
        ? (rule.bonus_damage_status_filter ? `si l'adversaire est ${STATUS_EFFECT_LABEL[rule.bonus_damage_status_filter].toLowerCase()}` : "si l'adversaire a un statut")
      : rule.bonus_damage_condition === 'self_has_status'
        ? (rule.bonus_damage_status_filter ? `si lui-même ${STATUS_EFFECT_LABEL[rule.bonus_damage_status_filter].toLowerCase()}` : "s'il a un statut")
      : rule.bonus_damage_condition === 'weight_ratio' ? describeWeightCondition(rule)
      : ''
    const bonusLabel = rule.bonus_damage_type === 'multiply' ? `Dégâts ×${rule.bonus_damage_multiplier}`
      : rule.bonus_damage_type === 'flat' ? `+${rule.bonus_damage_flat} dégâts`
      : `+${rule.bonus_damage_min}-${rule.bonus_damage_max} dégâts`
    lines.push(`${bonusLabel} ${conditionLabel}`.trim())
  }
  if (rule.prevention_duration_turns) {
    lines.push(`Bloque le bonus "super efficace" ${rule.prevention_duration_turns} tours`)
  }
  if (rule.ignore_status_block) {
    lines.push(`Utilisable même sous ${STATUS_EFFECT_LABEL[rule.ignore_status_block].toLowerCase()}`)
  }
  if (rule.invulnerable_next_turn) {
    lines.push('Invulnérable pour 1 tour')
  }
  if (rule.weather_id != null) {
    lines.push(`${rule.weather_chance ?? 0} % de lever ${weatherNom(rule.weather_id) ?? 'une météo'} en touchant`)
  }
  if (ability.status_effect && rule.status_reversed) {
    lines.push('Le statut le touche lui, pas l\'adversaire')
  }
  return lines
}

// ── Talents d'espèce ────────────────────────────────────────────────────────

export const TALENT_KIND_LABEL: Record<AutoBattleTalentKind, string> = {
  stat_boost: 'Bonus de statistique',
  absorb_first_damage: 'Absorbe les premiers dégâts',
  endure_ko: 'Encaisse le K.O.',
  poison_damage_boost: 'Dégâts de poison augmentés',
  burn_damage_boost: 'Dégâts de brûlure augmentés',
  priority: "Priorité d'initiative",
  inflict_status: 'Inflige un statut',
  status_immunity: 'Immunité à des statuts',
  type_immunity: 'Immunité à des types',
  type_damage_to_heal: 'Dégâts d’un type convertis en soin',
  no_recoil: 'Immunité au contre-coup',
  dice_bonus_damage: 'Bonus de dégâts sur un dé',
  auto_cure_first_status: 'Guérit le premier statut subi',
  invulnerable_until_hit: 'Invulnérable jusqu’à son premier coup',
  heal_below_hp: 'Soin sous un seuil de PV',
  transform: 'Transformation (copie l’adversaire)',
  heavy_sleeper: 'Somnolent (réveil sur un 6)',
  set_weather: 'Déclenche une météo',
  cancel_talents: 'Annule tous les talents du combat',
}

// ── Météo (effets de terrain) ───────────────────────────────────────────────

export const WEATHER_EFFECT_KIND_LABEL: Record<AutoBattleWeatherEffectKind, string> = {
  stat_mod: 'Bonus / malus de statistique',
  inflict_status: 'Inflige un statut chaque tour',
  damage: 'Inflige des dégâts chaque tour',
}

export const WEATHER_TARGET_SCOPE_LABEL: Record<AutoBattleWeatherTargetScope, string> = {
  pokemon_type: 'du type du pokémon',
  ability_type: 'du type de la capacité jouée',
}

// Libellé d'une condition « météo en cours », partagé par les talents et les
// capacités. `nom` = celui de la météo visée quand la condition vaut 'this'.
export function describeWeatherCondition(
  condition: AutoBattleWeatherCondition | null,
  nom: string | null | undefined,
): string | null {
  switch (condition) {
    case 'any': return 'par n’importe quelle météo'
    case 'none': return 'hors météo'
    case 'this': return `par ${nom ?? 'une météo supprimée'}`
    default: return null
  }
}

export const TALENT_TRIGGER_LABEL: Record<AutoBattleTalentTrigger, string> = {
  battle_start: 'À l’entrée en combat',
  each_turn: 'À chaque tour (avant sa capacité)',
  // Ne se déclenche que sur un coup DIRECT qui a porté — voir le commentaire de
  // autobattle_talents.kind dans supabase/schema.sql.
  on_ability_type: 'En touchant avec une capacité offensive d’un type donné',
}

const formatSigned = (n: number) => (n >= 0 ? `+${n}` : String(n))
const listOrAll = (list: string[] | null) => (list && list.length > 0 ? list.join(', ') : 'tous')

// Résumé lisible d'un talent, pour l'UI admin. Volontairement aligné sur
// autobattle_talent_detail (SQL), qui produit la phrase affichée en combat —
// les deux doivent rester cohérents.
// `weatherNames` : noms des météos par id (le talent ne stocke qu'un id). Absent
// = la phrase reste correcte, elle nomme juste « une météo » à la place.
export function describeTalent(talent: AutoBattleTalent, weatherNames?: Map<number, string>): string {
  const weatherNom = (id: number | null) => (id != null ? weatherNames?.get(id) ?? null : null)
  switch (talent.kind) {
    case 'stat_boost': {
      const stat = talent.stat === 'precision' ? 'précision' : 'dégâts'
      const parts = [`${formatSigned(talent.amount ?? 0)} ${stat}`]
      if (talent.type_filter && talent.type_filter.length > 0) parts.push(`capacités ${talent.type_filter.join(', ')}`)
      if (talent.require_damage_taken) {
        parts.push(talent.max_uses != null
          ? `par coup direct encaissé (max ${talent.max_uses})`
          : 'par coup direct encaissé')
      }
      if (talent.hp_condition === 'below') parts.push(`PV ≤ ${talent.hp_percent} %`)
      if (talent.hp_condition === 'above') parts.push(`PV ≥ ${talent.hp_percent} %`)
      if (talent.opponent_status) {
        parts.push(talent.opponent_status === 'any'
          ? 'adversaire affecté par un statut'
          : `adversaire sous ${STATUS_EFFECT_LABEL[talent.opponent_status].toLowerCase()}`)
      }
      if (talent.self_status) {
        parts.push(talent.self_status === 'any'
          ? 'lui-même affecté par un statut'
          : `lui-même sous ${STATUS_EFFECT_LABEL[talent.self_status].toLowerCase()}`)
      }
      const weather = describeWeatherCondition(talent.weather_condition, weatherNom(talent.weather_condition_id))
      if (weather) parts.push(weather)
      return parts.join(' — ')
    }
    case 'absorb_first_damage':
      return 'Le premier coup direct encaissé du combat inflige 0'
    case 'endure_ko':
      return 'Survit à 1 PV la première fois qu’il devrait tomber K.O.'
    case 'poison_damage_boost':
      return `Tous les dégâts de poison du combat : ${formatSigned(talent.amount ?? 0)}`
    case 'burn_damage_boost':
      return `Tous les dégâts de brûlure du combat : ${formatSigned(talent.amount ?? 0)}`
    case 'priority':
      return `Initiative ${talent.amount ?? 0} — joue en premier face à une priorité plus basse`
    case 'inflict_status': {
      const status = talent.status_filter?.[0]
      const label = status ? STATUS_EFFECT_LABEL[status].toLowerCase() : 'un statut'
      const trigger = talent.trigger ? TALENT_TRIGGER_LABEL[talent.trigger].toLowerCase() : ''
      const types = talent.trigger === 'on_ability_type' ? ` (${listOrAll(talent.type_filter)})` : ''
      return `${talent.percent ?? 0} % d’infliger ${label} — ${trigger}${types}`
    }
    case 'status_immunity':
      return `Insensible à : ${(talent.status_filter ?? []).map((s) => STATUS_EFFECT_LABEL[s]).join(', ') || '—'}`
    case 'type_immunity':
      return `Insensible aux dégâts de type : ${listOrAll(talent.type_filter)}`
    case 'type_damage_to_heal':
      return `Les dégâts de type ${listOrAll(talent.type_filter)} le soignent`
    case 'no_recoil':
      return 'Ne subit jamais le contre-coup de ses propres capacités'
    case 'dice_bonus_damage':
      return `Dé de dégâts à ${talent.dice_value ?? '?'} : ${formatSigned(talent.amount ?? 0)} dégâts`
    case 'auto_cure_first_status':
      return 'Guérit immédiatement le premier statut subi du combat'
    case 'invulnerable_until_hit':
      return 'Invulnérable tant qu’il n’a pas lui-même infligé de dégâts'
    case 'heal_below_hp': {
      const amount = talent.value_type === 'percent_max_hp'
        ? `${talent.percent ?? 0} % des PV max`
        : talent.value_type === 'range'
          ? `${talent.amount ?? 0} à ${talent.amount_max ?? 0} PV`
          : `${talent.amount ?? 0} PV`
      return `Récupère ${amount} en passant sous ${talent.hp_percent ?? 0} % de ses PV (une fois par combat)`
    }
    case 'transform':
      return 'Copie l’apparence, le type et les capacités de son adversaire (jamais ses PV) — sans effet en PvP'
    case 'heavy_sleeper':
      return 'Endormi, il lui faut un 6 exact au dé pour se réveiller (au lieu de 4, 5 ou 6)'
    case 'set_weather': {
      const nom = weatherNom(talent.weather_id)
      const trigger = talent.trigger ? TALENT_TRIGGER_LABEL[talent.trigger].toLowerCase() : ''
      const types = talent.trigger === 'on_ability_type' ? ` (${listOrAll(talent.type_filter)})` : ''
      if (!nom) return 'Aucune météo sélectionnée — ce talent ne fait rien'
      return `${talent.percent ?? 0} % de déclencher ${nom} — ${trigger}${types}`
    }
    case 'cancel_talents':
      return 'Annule tous les talents du combat, des deux côtés — le sien compris'
  }
}

/**
 * Filtre de types d'un effet météo, mis en toutes lettres — renvoie la fin de
 * phrase complète (« … pokémon de » + ce qui suit) :
 *   • liste vide            → « tous types »
 *   • tous les types cochés → « tous types »
 *   • majorité cochée       → « tous types sauf Sol, Roche »
 *   • sinon                 → « type Feu, Glace »
 * La forme négative dès que les types cochés sont PLUS NOMBREUX que les autres :
 * une tempête de sable se configure en cochant 16 types sur 18, et « tous types
 * sauf Sol, Roche » est la seule formulation lisible.
 * `allTypes` = univers des types (celui des pastilles de l'UI admin) ; absent,
 * on se rabat sur la liste positive.
 * Pendant SQL : autobattle_weather_type_list, à garder aligné.
 */
function weatherTypeList(list: string[] | null, allTypes?: string[]): string {
  const selected = list ?? []
  if (selected.length === 0) return 'tous types'
  if (!allTypes || allTypes.length === 0) return `type ${selected.join(', ')}`
  const norm = (t: string) => t.trim().toLowerCase()
  const missing = allTypes.filter((t) => !selected.some((s) => norm(s) === norm(t)))
  if (missing.length === 0) return 'tous types'
  if (selected.length > missing.length) return `tous types sauf ${missing.join(', ')}`
  return `type ${selected.join(', ')}`
}

/**
 * Météo active à un instant donné du journal : la DERNIÈRE levée (`weather_set`)
 * l'emporte, puisqu'une météo en remplace toujours une autre et qu'aucune ne
 * s'éteint d'elle-même. Renvoie null tant qu'aucune ne s'est levée.
 *
 * Sert aux écrans qui ont les tours sous la main mais ne rejouent pas
 * l'animation (ManualBattleScreen, pour la grille de capacités) —
 * AutoBattleScreen, lui, suit la météo au fil de la relecture animée, ce qui
 * peut la faire apparaître une fraction de seconde plus tard à l'écran.
 */
export function getActiveWeather(turns: AutoBattleTurn[]): AutoBattleTurn | null {
  for (let i = turns.length - 1; i >= 0; i--) {
    // Une dissipation (voir AutoBattleAbilityRule.clear_weather) rencontrée
    // avant toute levée signifie qu'il n'y a plus de météo du tout.
    if (turns[i].weather_cleared) return null
    if (turns[i].weather_set) return turns[i]
  }
  return null
}

/**
 * Cette capacité est-elle concernée par la météo en cours ? Seuls les effets
 * 'stat_mod' ciblant le type de la CAPACITÉ comptent : ceux qui ciblent le type
 * du POKÉMON (comme les dégâts et statuts de terrain) ne disent rien de la
 * capacité choisie.
 *
 * Un buff de dégâts ne concerne que les capacités OFFENSIVES, et un buff de
 * précision que celles qui peuvent rater — annoncer une pastille sur une
 * capacité de soutien à précision absolue serait un mensonge.
 */
export function weatherAffectsAbility(
  effects: AutoBattleWeatherEffect[] | undefined,
  ability: Attack,
  precisionEnabled: boolean,
): boolean {
  if (!effects || effects.length === 0) return false
  const abilityType = ability.type.trim().toLowerCase()
  return effects.some((e) => {
    if (e.kind !== 'stat_mod' || e.target_scope !== 'ability_type') return false
    // Liste d'INCLUSION : vide = tous les types (voir weatherTypeList).
    const filter = e.type_filter ?? []
    if (filter.length > 0 && !filter.some((t) => t.trim().toLowerCase() === abilityType)) return false
    if (e.stat === 'damage') return ability.deals_damage
    if (e.stat === 'precision') return precisionEnabled && !isAbsolutePrecision(ability.precision)
    return false
  })
}

// Résumé lisible d'un effet de météo, pour l'UI admin (voir describeTalent :
// même rôle, même style de phrase). `allTypes` : voir weatherTypeList.
export function describeWeatherEffect(effect: AutoBattleWeatherEffect, allTypes?: string[]): string {
  switch (effect.kind) {
    case 'stat_mod': {
      const stat = effect.stat === 'precision' ? 'précision' : 'dégâts'
      const scope = effect.target_scope === 'ability_type' ? 'capacités' : 'pokémon'
      return `${formatSigned(effect.amount ?? 0)} ${stat} — ${scope} de ${weatherTypeList(effect.type_filter, allTypes)}`
    }
    case 'inflict_status': {
      const label = effect.status ? STATUS_EFFECT_LABEL[effect.status].toLowerCase() : 'un statut'
      return `${effect.percent ?? 0} % par tour d’infliger ${label} — pokémon de ${weatherTypeList(effect.type_filter, allTypes)}`
    }
    case 'damage':
      return `${effect.percent ?? 0} % par tour d’infliger ${effect.damage_amount ?? 0} dégâts — pokémon de ${weatherTypeList(effect.type_filter, allTypes)}`
  }
}

// Vocabulaire du champ `first_attacker` renvoyé par les RPC de démarrage de
// combat : côté client c'est TOUJOURS 'player'/'opponent' (celui de
// AutoBattleCoinToss et du badge "(1er)"/"(2ème)" de ManualBattleScreen).
// Les tables PvP stockent, elles, 'attacker'/'defender' — pvp_start_battle et
// pvp_trial_start renvoyaient cette valeur interne telle quelle, ce qui faisait
// échouer tous les tests `=== 'player'` (pile ou face et badge toujours
// affichés comme si l'adversaire commençait). Corrigé côté SQL, mais normalisé
// ici aussi pour rester juste face à une base pas encore migrée.
export function normalizeFirstAttacker(value: string): 'player' | 'opponent' {
  return value === 'player' || value === 'attacker' ? 'player' : 'opponent'
}
