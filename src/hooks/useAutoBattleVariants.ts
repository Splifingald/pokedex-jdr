import { useState, useEffect, useCallback, useRef, useMemo } from 'react'
import { supabase } from '../lib/supabase'
import type { AutoBattleVariant, AutoBattleLevel, AutoBattleLevelReward } from '../types'

// CRUD complet des variantes de Combat Auto (créées en admin, pas d'import
// CSV) : variantes + leurs niveaux + les récompenses de chaque niveau —
// même structure que useSafariGroups (groupes + pokémon pondérés + zones).
export function useAutoBattleVariants() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [variants, setVariants] = useState<AutoBattleVariant[]>([])
  const [levels, setLevels] = useState<AutoBattleLevel[]>([])
  const [rewards, setRewards] = useState<AutoBattleLevelReward[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchAll = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [variantsRes, levelsRes, rewardsRes] = await Promise.all([
        supabase.from('autobattle_variants').select('*').order('sort_order'),
        supabase.from('autobattle_levels').select('*').order('level_index'),
        supabase.from('autobattle_level_rewards').select('*').order('sort_order'),
      ])
      if (variantsRes.error) throw variantsRes.error
      if (levelsRes.error) throw levelsRes.error
      if (rewardsRes.error) throw rewardsRes.error
      setVariants(variantsRes.data ?? [])
      setLevels(levelsRes.data ?? [])
      setRewards(rewardsRes.data ?? [])
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erreur de chargement')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  useEffect(() => {
    const channel = supabase
      .channel(`autobattle-variants-changes-${channelId.current}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'autobattle_variants' }, (payload) => {
        const row = payload.new as AutoBattleVariant
        setVariants((prev) => (prev.some((r) => r.id === row.id) ? prev : [...prev, row]))
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'autobattle_variants' }, (payload) => {
        const row = payload.new as AutoBattleVariant
        setVariants((prev) => prev.map((r) => (r.id === row.id ? row : r)))
      })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'autobattle_variants' }, (payload) => {
        const id = (payload.old as { id: number }).id
        setVariants((prev) => prev.filter((r) => r.id !== id))
      })
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'autobattle_levels' }, (payload) => {
        const row = payload.new as AutoBattleLevel
        setLevels((prev) => (prev.some((r) => r.id === row.id) ? prev : [...prev, row]))
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'autobattle_levels' }, (payload) => {
        const row = payload.new as AutoBattleLevel
        setLevels((prev) => prev.map((r) => (r.id === row.id ? row : r)))
      })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'autobattle_levels' }, (payload) => {
        const id = (payload.old as { id: number }).id
        setLevels((prev) => prev.filter((r) => r.id !== id))
      })
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'autobattle_level_rewards' }, (payload) => {
        const row = payload.new as AutoBattleLevelReward
        setRewards((prev) => (prev.some((r) => r.id === row.id) ? prev : [...prev, row]))
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'autobattle_level_rewards' }, (payload) => {
        const row = payload.new as AutoBattleLevelReward
        setRewards((prev) => prev.map((r) => (r.id === row.id ? row : r)))
      })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'autobattle_level_rewards' }, (payload) => {
        const id = (payload.old as { id: number }).id
        setRewards((prev) => prev.filter((r) => r.id !== id))
      })
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  // Vue triée par sort_order pour l'affichage — le state brut `variants` peut
  // se retrouver dans un ordre différent après un swap (l'event realtime
  // UPDATE remplace juste l'objet à sa position existante sans retrier, voir
  // le handler .on('UPDATE'...) ci-dessus), donc AUCUN composant ne doit lire
  // `variants` directement : c'est ce qui rendait le réordonnancement muet
  // tant que la page n'était pas rechargée (schema.sql sort_order recalculé
  // au fetch seulement). Même principe que levelsByVariant pour les niveaux.
  // Départage par id à sort_order égal : la base contient des doublons
  // historiques (voir swapVariantOrder) et sans ce critère l'ordre affiché
  // dépendait de l'ordre de fetch, donc pouvait changer d'un chargement à
  // l'autre.
  const sortedVariants = useMemo(
    () => [...variants].sort((a, b) => a.sort_order - b.sort_order || a.id - b.id),
    [variants]
  )

  const levelsByVariant = useMemo(() => {
    const map = new Map<number, AutoBattleLevel[]>()
    for (const row of levels) {
      const list = map.get(row.variant_id)
      if (list) list.push(row)
      else map.set(row.variant_id, [row])
    }
    for (const list of map.values()) list.sort((a, b) => a.level_index - b.level_index)
    return map
  }, [levels])

  const rewardsByLevel = useMemo(() => {
    const map = new Map<number, AutoBattleLevelReward[]>()
    for (const row of rewards) {
      const list = map.get(row.level_id)
      if (list) list.push(row)
      else map.set(row.level_id, [row])
    }
    return map
  }, [rewards])

  // Prochain sort_order libre : max + 1, JAMAIS variants.length — après une
  // suppression, length retombe sur un sort_order déjà pris et crée un doublon
  // qui casse le réordonnancement (voir swapVariantOrder).
  const nextSortOrder = useMemo(
    () => variants.reduce((max, v) => Math.max(max, v.sort_order), -1) + 1,
    [variants]
  )

  const addVariant = useCallback(async (nom: string) => {
    const { data, error } = await supabase
      .from('autobattle_variants')
      .insert({ nom, sort_order: nextSortOrder })
      .select()
      .single()
    if (error) {
      console.error("Erreur lors de la création de la variante Combat Auto :", error)
      return null
    }
    const row = data as AutoBattleVariant
    setVariants((prev) => [...prev, row])
    return row
  }, [nextSortOrder])

  const updateVariant = useCallback(async (id: number, patch: Partial<Omit<AutoBattleVariant, 'id' | 'created_at'>>) => {
    setVariants((prev) => prev.map((v) => (v.id === id ? { ...v, ...patch } : v)))
    const { error } = await supabase.from('autobattle_variants').update(patch).eq('id', id)
    if (error) {
      console.error('Erreur lors de la mise à jour de la variante Combat Auto :', error)
      await fetchAll()
    }
  }, [fetchAll])

  // Échange deux variantes adjacentes puis RENUMÉROTE toute la liste sur
  // 0..n-1, au lieu d'échanger simplement les deux valeurs de sort_order comme
  // le faisait la version précédente : la base contient des sort_order en
  // double (héritage de addVariant/duplicateVariant qui utilisaient
  // variants.length comme prochain ordre — après une suppression, length
  // retombe sur une valeur déjà prise). Échanger deux valeurs identiques est un
  // no-op, ce qui rendait les flèches ▲▼ totalement muettes sur ces paires.
  // La renumérotation répare les doublons existants au premier réordonnancement.
  const swapVariantOrder = useCallback(async (variantA: AutoBattleVariant, variantB: AutoBattleVariant) => {
    if (!variantA || !variantB) return
    // On raisonne en POSITIONS dans la liste triée affichée, pas en valeurs de
    // sort_order — seules les positions sont non ambiguës quand il y a doublon.
    const reordered = [...sortedVariants]
    const i = reordered.findIndex((v) => v.id === variantA.id)
    const j = reordered.findIndex((v) => v.id === variantB.id)
    if (i < 0 || j < 0) return
    ;[reordered[i], reordered[j]] = [reordered[j], reordered[i]]

    const nextOrder = new Map(reordered.map((v, index) => [v.id, index]))
    const changed = reordered.filter((v) => v.sort_order !== nextOrder.get(v.id))
    if (changed.length === 0) return

    setVariants((prev) => prev.map((v) => {
      const order = nextOrder.get(v.id)
      return order === undefined || order === v.sort_order ? v : { ...v, sort_order: order }
    }))
    const results = await Promise.all(changed.map((v) =>
      supabase.from('autobattle_variants').update({ sort_order: nextOrder.get(v.id)! }).eq('id', v.id)
    ))
    const failed = results.find((r) => r.error)
    if (failed) {
      console.error('Erreur lors du réordonnancement des variantes Combat Auto :', failed.error)
      await fetchAll()
    }
  }, [sortedVariants, fetchAll])

  const deleteVariant = useCallback(async (id: number) => {
    setVariants((prev) => prev.filter((v) => v.id !== id))
    const { error } = await supabase.from('autobattle_variants').delete().eq('id', id)
    if (error) {
      console.error('Erreur lors de la suppression de la variante Combat Auto :', error)
      await fetchAll()
    }
  }, [fetchAll])

  const addLevel = useCallback(async (variantId: number) => {
    const nextIndex = (levelsByVariant.get(variantId)?.length ?? 0)
    const { data, error } = await supabase
      .from('autobattle_levels')
      .insert({ variant_id: variantId, level_index: nextIndex, opponent_pokemon_nom: '', opponent_ability_nom: '' })
      .select()
      .single()
    if (error) {
      console.error("Erreur lors de la création du niveau Combat Auto :", error)
      return null
    }
    const row = data as AutoBattleLevel
    setLevels((prev) => [...prev, row])
    return row
  }, [levelsByVariant])

  const updateLevel = useCallback(async (id: number, patch: Partial<Omit<AutoBattleLevel, 'id' | 'variant_id' | 'created_at'>>) => {
    setLevels((prev) => prev.map((l) => (l.id === id ? { ...l, ...patch } : l)))
    const { error } = await supabase.from('autobattle_levels').update(patch).eq('id', id)
    if (error) {
      console.error('Erreur lors de la mise à jour du niveau Combat Auto :', error)
      await fetchAll()
    }
  }, [fetchAll])

  // Échange l'ordre de deux niveaux adjacents — seule façon de réordonner
  // (pas de glisser-déposer dans ce codebase, voir AdminSafariGroupsPanel) :
  // garantit par construction que level_index reste 0..n-1 sans trou/doublon.
  //
  // En TROIS écritures séquentielles, en passant par un index temporaire
  // négatif : autobattle_levels porte UNIQUE (variant_id, level_index), donc
  // écrire directement l'index de B sur A (les 2 UPDATE en parallèle, comme
  // avant) violait la contrainte — l'échange échouait toujours, et le
  // fetchAll() de secours donnait l'impression que la page se rechargeait.
  // Les index réels étant tous >= 0, un index négatif ne peut entrer en
  // collision avec aucune ligne existante.
  const swapLevelOrder = useCallback(async (levelA: AutoBattleLevel, levelB: AutoBattleLevel) => {
    if (levelA.id === levelB.id) return
    setLevels((prev) => prev.map((l) => {
      if (l.id === levelA.id) return { ...l, level_index: levelB.level_index }
      if (l.id === levelB.id) return { ...l, level_index: levelA.level_index }
      return l
    }))
    const tempIndex = -1 - levelA.level_index
    const steps = [
      { id: levelA.id, level_index: tempIndex },
      { id: levelB.id, level_index: levelA.level_index },
      { id: levelA.id, level_index: levelB.level_index },
    ]
    for (const step of steps) {
      const { error } = await supabase
        .from('autobattle_levels')
        .update({ level_index: step.level_index })
        .eq('id', step.id)
      if (error) {
        console.error('Erreur lors du réordonnancement des niveaux Combat Auto :', error)
        await fetchAll()
        return
      }
    }
  }, [fetchAll])

  const deleteLevel = useCallback(async (id: number) => {
    setLevels((prev) => prev.filter((l) => l.id !== id))
    const { error } = await supabase.from('autobattle_levels').delete().eq('id', id)
    if (error) {
      console.error('Erreur lors de la suppression du niveau Combat Auto :', error)
      await fetchAll()
    }
  }, [fetchAll])

  const addReward = useCallback(async (levelId: number, patch: Omit<AutoBattleLevelReward, 'id' | 'level_id' | 'created_at'>) => {
    const { data, error } = await supabase
      .from('autobattle_level_rewards')
      .insert({ level_id: levelId, ...patch })
      .select()
      .single()
    if (error) {
      console.error("Erreur lors de l'ajout de la récompense Combat Auto :", error)
      return
    }
    setRewards((prev) => [...prev, data as AutoBattleLevelReward])
  }, [])

  const updateReward = useCallback(async (id: number, patch: Partial<Omit<AutoBattleLevelReward, 'id' | 'level_id' | 'created_at'>>) => {
    setRewards((prev) => prev.map((r) => (r.id === id ? { ...r, ...patch } : r)))
    const { error } = await supabase.from('autobattle_level_rewards').update(patch).eq('id', id)
    if (error) {
      console.error('Erreur lors de la mise à jour de la récompense Combat Auto :', error)
      await fetchAll()
    }
  }, [fetchAll])

  const removeReward = useCallback(async (id: number) => {
    setRewards((prev) => prev.filter((r) => r.id !== id))
    const { error } = await supabase.from('autobattle_level_rewards').delete().eq('id', id)
    if (error) {
      console.error('Erreur lors du retrait de la récompense Combat Auto :', error)
      await fetchAll()
    }
  }, [fetchAll])

  // Remet une variante à zéro pour TOUS les joueurs (pas seulement l'admin) :
  // supprime la ligne de progression (le prochain combat en recrée une avec
  // current_level_index=0/variant_completed=false, voir autobattle_resolve_battle)
  // et les lignes d'état par niveau (adversaires redeviennent non découverts).
  const resetVariantProgress = useCallback(async (variantId: number) => {
    const levelIds = levels.filter((l) => l.variant_id === variantId).map((l) => l.id)
    const [progressRes, stateRes] = await Promise.all([
      supabase.from('autobattle_player_variant_progress').delete().eq('variant_id', variantId),
      levelIds.length > 0
        ? supabase.from('autobattle_player_level_state').delete().in('level_id', levelIds)
        : Promise.resolve({ error: null }),
    ])
    if (progressRes.error || stateRes.error) {
      console.error('Erreur lors de la réinitialisation de la progression Combat Auto :', progressRes.error ?? stateRes.error)
    }
  }, [levels])

  // Copie une variante (nom + " (copie)"), tous ses niveaux et leurs
  // récompenses — jamais la progression des joueurs. Désactivée par défaut
  // (comme une nouvelle variante) pour laisser l'admin la relire avant
  // publication. Séquentiel (pas Promise.all) pour rattacher chaque niveau/
  // récompense au bon id nouvellement créé sans course.
  const duplicateVariant = useCallback(async (variantId: number) => {
    const source = variants.find((v) => v.id === variantId)
    if (!source) return null
    const sourceLevels = levelsByVariant.get(variantId) ?? []
    try {
      const { data: newVariant, error: variantError } = await supabase
        .from('autobattle_variants')
        .insert({
          nom: `${source.nom} (copie)`,
          enabled: false,
          icon_url: source.icon_url,
          banner_url: source.banner_url,
          sort_order: nextSortOrder,
        })
        .select()
        .single()
      if (variantError || !newVariant) throw variantError
      const newVariantRow = newVariant as AutoBattleVariant

      for (const level of sourceLevels) {
        const { data: newLevel, error: levelError } = await supabase
          .from('autobattle_levels')
          .insert({
            variant_id: newVariantRow.id,
            level_index: level.level_index,
            opponent_pokemon_nom: level.opponent_pokemon_nom,
            opponent_hp: level.opponent_hp,
            opponent_base_damage: level.opponent_base_damage,
            opponent_ability_nom: level.opponent_ability_nom,
          })
          .select()
          .single()
        if (levelError || !newLevel) throw levelError
        const newLevelRow = newLevel as AutoBattleLevel

        const sourceRewards = rewardsByLevel.get(level.id) ?? []
        if (sourceRewards.length > 0) {
          const { error: rewardsError } = await supabase.from('autobattle_level_rewards').insert(
            sourceRewards.map((r) => ({
              level_id: newLevelRow.id,
              reward_type: r.reward_type,
              xp_amount: r.xp_amount,
              item_nom: r.item_nom,
              item_quantity: r.item_quantity,
              sort_order: r.sort_order,
            }))
          )
          if (rewardsError) throw rewardsError
        }
      }

      await fetchAll()
      return newVariantRow
    } catch (err) {
      console.error('Erreur lors de la duplication de la variante Combat Auto :', err)
      await fetchAll()
      return null
    }
  }, [variants, nextSortOrder, levelsByVariant, rewardsByLevel, fetchAll])

  return {
    variants: sortedVariants, levels, rewards, levelsByVariant, rewardsByLevel, loading, error,
    addVariant, updateVariant, deleteVariant, swapVariantOrder,
    addLevel, updateLevel, swapLevelOrder, deleteLevel,
    addReward, updateReward, removeReward,
    resetVariantProgress, duplicateVariant,
    refetch: fetchAll,
  }
}
