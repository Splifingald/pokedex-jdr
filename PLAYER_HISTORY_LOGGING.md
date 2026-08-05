# Journal des actions joueurs (Historique)

L'onglet **Admin → Historique** affiche un journal chronologique de ce que
font les joueurs : inventaire, Pokédex, équipe/PC, combat, mini-jeux. C'est enregistré
en base (table `history_events`) et lu en temps réel via Supabase Realtime,
comme le reste de l'app.

Ce document explique ce qui est enregistré aujourd'hui et comment brancher
une future fonctionnalité joueur sur ce même système plutôt que d'en
réinventer un.

## Ce qui est enregistré aujourd'hui

| Catégorie | action_type | Exemple de phrase |
|---|---|---|
| `inventory` | `item_add` | "Joueur 1 a ajouté 100 Pokédollar à son inventaire depuis le Sac (total : 250)" |
| `inventory` | `item_remove` | "Joueur 2 a retiré 100 Pokédollar à son inventaire depuis le Sac (total : 150)" |
| `inventory` | `item_sale` | "Joueur 4 a ajouté 125 Pokédollar à son inventaire depuis la vente de : Filet Ball (total : ...)" |
| `inventory` | `item_gift` | "Joueur 1 a reçu 1 Baie Sitrus de la part de Salamèche en cadeau (total : 3)" |
| `inventory` | `item_casino_win` | "Joueur 2 a gagné 35 Pokédollar au jeu de Casino Dé Métamorph (total : 1035)" |
| `inventory` | `item_casino_spend` | "Joueur 1 a dépensé 1 Ticket Casino au jeu de Casino Dé Métamorph (total : 2)" |
| `inventory` | `item_minigame_spend` | "Joueur 1 a dépensé 1 Ticket Trempette au jeu Magikarp (total : 2)" |
| `pokedex` | `pokedex_add` | "Joueur 1 a ajouté Carapuce au Pokédex (total : 55)" |
| `team` | `pokemon_new` | "Joueur 2 a obtenu Carapuce, ajouté à son équipe" |
| `team` | `pokemon_move` | "Joueur 1 a placé Carapuce dans son PC" |
| `combat` | `ko` | "Joueur 1 : Pikachu est K.O." / "...n'est plus K.O." |
| `combat` | `status_change` | "Joueur 2 : Raichu est empoisonné" / "...n'est plus empoisonné" |
| `minigame` | `minigame_xp_gain` | "Joueur 1 : Magicarpe a gagné 10 XP au jeu Magikarp (score : 32, 2 étoiles)" |

**Volontairement exclu** : le "un-discover" Pokédex (bouton correctif
admin-only dans `PokemonDetailSheet`) n'est pas loggé — ce n'est pas une
action joueur.

## Schéma — table `history_events`

Voir `supabase/schema.sql`. Colonnes : `id`, `player_id`, `category`
(`inventory`|`pokedex`|`team`|`combat`|`minigame`), `action_type`, `payload` (jsonb,
forme spécifique à chaque `(category, action_type)` — voir `src/types.ts`),
`created_at`. Table append-only côté client (lecture + insertion publiques,
pas d'update/delete).

**Convention de signe** : sur une ligne brute en base, `HistoryInventoryPayload.delta`
est **signé** (négatif pour un retrait). Le regroupement à la lecture
(`src/lib/historyGrouping.ts`) le normalise en valeur positive une fois le
sens net résolu.

## Le contrat `logHistoryEvent()`

```ts
import { logHistoryEvent } from './lib/historyLog'

void logHistoryEvent(category, actionType, playerId, payload)
```

- Fonction simple (pas un hook) dans `src/lib/historyLog.ts` — appelable
  depuis n'importe quel gestionnaire d'événement.
- **Fire-and-forget** : toujours appelée avec `void`, jamais `await`ée. Le
  journal est un bonus, pas une donnée critique — un échec d'écriture ne
  doit jamais bloquer ou casser la mutation réelle qu'il accompagne.
- **Toujours appelée au site d'appel UI (composant), jamais à l'intérieur
  des hooks mutateurs partagés** (`usePlayerItems`, `usePlayerPokemon`,
  `usePokemon`, etc.) — ces hooks sont utilisés par plusieurs appelants avec
  des contextes différents (ex : `setQuantity` sert à la fois le Sac et la
  vente), et seul le site d'appel connaît le bon libellé de `source` et le
  bon `action_type`.

## Le regroupement à la lecture (coalescing)

Les événements d'inventaire proches dans le temps (même joueur, même objet,
même source, moins de 10 secondes d'écart) sont fusionnés en une seule ligne
d'affichage par `groupHistoryEvents()` (`src/lib/historyGrouping.ts`), au
moment de la lecture — **pas** à l'écriture. Si le delta net d'un groupe est
nul (ex : +100 puis −100), la ligne est purement et simplement masquée.

Ce choix (regroupement en lecture plutôt qu'à l'écriture) évite d'avoir à
gérer des timers/debounce côté client et évite toute perte d'événement si
l'onglet se ferme avant la fin d'une fenêtre de regroupement — chaque
mutation est toujours écrite immédiatement en base.

## Comment ajouter une nouvelle action à logger

1. Si besoin, étendre `HistoryCategory`/`HistoryActionType` et ajouter le
   type de payload correspondant dans `src/types.ts`.
2. Appeler `logHistoryEvent(...)` juste après la mutation réelle réussie, au
   plus près du site d'appel UI (jamais dans un hook générique partagé).
3. Ajouter le gabarit de phrase correspondant dans `src/lib/historySentences.ts`
   (`buildSentenceParts`) — les noms de joueur/Pokémon/objet doivent rester
   les noms canoniques du catalogue (`player.name`, `pokemon.nom`,
   `item.nom`) pour que les liens cliquables (`ReferenceDispatcher`) les
   résolvent correctement ; utiliser le champ `label` de `SentencePart` si le
   texte affiché doit différer (ex : pluriel).
4. Si l'action doit un jour apparaître dans une fonctionnalité côté joueur
   (pas seulement Admin) : `useHistoryEvents()` (`src/hooks/useHistoryEvents.ts`)
   n'est pas admin-only, il suffit de filtrer côté composant sur `player_id`.

**Toute nouvelle fonctionnalité joueur ajoutée par Claude devrait suivre ce
même système** plutôt que d'introduire son propre mécanisme de log.
