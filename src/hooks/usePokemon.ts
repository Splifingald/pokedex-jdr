import { useState, useEffect, useCallback } from 'react'
import { supabase } from '../lib/supabase'
import type { Pokemon } from '../types'

export function usePokemon() {
  const [pokemon, setPokemon] = useState<Pokemon[]>([])
  const [discovered, setDiscovered] = useState<Set<string>>(new Set())
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchAll = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [pokemonRes, discoveredRes] = await Promise.all([
        supabase.from('pokemon').select('*').order('numero'),
        supabase.from('discovered_pokemon').select('pokemon_nom'),
      ])

      if (pokemonRes.error) throw pokemonRes.error
      if (discoveredRes.error) throw discoveredRes.error

      const sorted = (pokemonRes.data ?? []).sort((a, b) =>
        a.numero.localeCompare(b.numero, undefined, { numeric: true })
      )
      setPokemon(sorted)
      setDiscovered(new Set((discoveredRes.data ?? []).map((d) => d.pokemon_nom)))
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erreur de chargement')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  // Abonnement temps réel : synchro INSERT et DELETE entre appareils
  useEffect(() => {
    const channel = supabase
      .channel('discovered-pokemon-changes')
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'discovered_pokemon' },
        (payload) => {
          const nom = (payload.new as { pokemon_nom: string }).pokemon_nom
          setDiscovered((prev) => new Set([...prev, nom]))
        }
      )
      .on(
        'postgres_changes',
        { event: 'DELETE', schema: 'public', table: 'discovered_pokemon' },
        (payload) => {
          const nom = (payload.old as { pokemon_nom: string }).pokemon_nom
          setDiscovered((prev) => {
            const next = new Set(prev)
            next.delete(nom)
            return next
          })
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  const discoverPokemon = useCallback(async (nom: string) => {
    setDiscovered((prev) => new Set([...prev, nom]))

    const { error } = await supabase
      .from('discovered_pokemon')
      .insert({ pokemon_nom: nom })
      .select()
      .single()

    if (error && error.code !== '23505') {
      console.error('Erreur lors de la découverte :', error)
    }
  }, [])

  const undiscoverPokemon = useCallback(async (nom: string) => {
    // Mise à jour optimiste
    setDiscovered((prev) => {
      const next = new Set(prev)
      next.delete(nom)
      return next
    })

    const { error } = await supabase
      .from('discovered_pokemon')
      .delete()
      .eq('pokemon_nom', nom)

    if (error) {
      // Rollback en cas d'erreur
      setDiscovered((prev) => new Set([...prev, nom]))
      console.error('Erreur lors de la suppression :', error)
    }
  }, [])

  const isDiscovered = useCallback(
    (nom: string) => discovered.has(nom),
    [discovered]
  )

  return { pokemon, discovered, loading, error, discoverPokemon, undiscoverPokemon, isDiscovered, refetch: fetchAll }
}
