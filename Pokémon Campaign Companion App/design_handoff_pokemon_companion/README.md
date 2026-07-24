# Handoff: Pokémon TTRPG Companion App — Mobile Redesign

## Overview
A mobile-first redesign of the existing "Pokedex" React/Vite/Tailwind campaign-companion app, in a vintage-Pokédex pixel-art style (Jersey 25 font). Covers 5 screens: Accueil (Home), Pokémon (owned roster), Pokédex (shared party discovery log), Sac (bag/inventory), Carte (region map). Reuses the existing app's data model (French field names, type system, French copy) but introduces new interaction patterns (roaming animated team on Home, camera-scan discovery flow, unified sortable roster list, search-to-add inventory).

## About the Design Files
The bundled file (`Pokemon Companion App.dc.html`) is a **design reference built in HTML/React-like pseudocode for prototyping purposes only** — it is not production code and must not be copied verbatim. It runs on a proprietary internal component runtime (custom template syntax, inline styles only, a fake "iOS device frame" wrapper) that does not exist in a real codebase. **Recreate this design inside the existing `Pokedex` React + TypeScript + Vite + Tailwind codebase**, reusing its real components (`TypeBadge`, `HpGauge`, `XpGauge`, `PokemonOwnedCard`, `TabBar`, hooks like `usePlayerPokemon`/`useItems`/`useCarteLocations`, Supabase data layer, etc.) wherever they already cover the same need. Only introduce new components for things that are genuinely new (the Home roaming diorama, the camera-scan flow, the unified sortable roster list, search-to-add inventory, sort chips).

## Fidelity
**High-fidelity.** Colors, spacing, typography, and copy in the mockup are intentional — recreate them pixel-precisely using Tailwind utilities/config (add the custom hex values below to the Tailwind theme rather than hardcoding), not the codebase's current dark-gray/Tailwind-default palette. All Pokémon/item sprite art in the mockup is a **striped placeholder** (diagonal stripe pattern in the type color, with a monospace name label) — do not ship these as final art; wire up the real `image_miniature` / `image_url` fields from Supabase in their place, sized/positioned identically to the placeholders.

## Screens / Views

### 1. Accueil (Home)
- **Purpose**: At-a-glance view of the player's active team (up to 3 Pokémon), plus a "scan a Pokémon" entry point to grow the shared Pokédex.
- **Layout**: Full-bleed scene, no scrolling. Background is a two-tone "prairie" gradient: top ~30% light green sky/field (`#cdeed0`), bottom ~70% darker grass (`#6fbd5a` → `#4f9a41`), overlaid with a subtle 8px vertical stripe texture (`rgba(255,255,255,0.07)`) for a pixel-grass feel.
- **Header overlay** (position: absolute, top, full width, padding 12–14px, background `linear-gradient(to bottom, rgba(20,50,15,0.35), transparent)`): title "MON ÉQUIPE", 18px, `#f2ecd6`, 1px letter-spacing, 2px black text-shadow. No action buttons here (no "heal all" button — removed per latest revision).
- **Team sprites**: each team Pokémon renders as a button containing (a) a 76×76px sprite box (border-radius 8px, 2px solid `#201c14`, box-shadow `3px 3px 0 rgba(0,0,0,0.3)`) and (b) a small pill below showing `"{hp}/{maxHp} PV"` (12px text, `#14320f`, background `rgba(242,236,214,0.9)`). No Pokémon name is shown on Home (removed per latest revision — name only appears in the detail sheet).
- **Positioning & movement**: Pokémon are scattered at different depths (not on one baseline) and **slowly drift** to new random positions within safe bounds (roughly left 18–82%, bottom 14–44% of the scene) on a loop. Movement speed is driven by each Pokémon's `speed` stat (1–5): drift duration in seconds ≈ `12 / speed` (so speed 5 ≈ 2.4s per hop, speed 1 ≈ 12s). Position changes are CSS-transitioned (`transition: left {d}s linear, bottom {d}s linear`) so movement reads as a slow glide, not a snap. Independently, each Pokémon also **idle-bobs** continuously (±4px vertical, 2.2–3s ease-in-out loop, staggered start delay) and **randomly jumps** (one team member at a time, picked at random every 5–10s, hops up ~24px over ~0.55s) — this bob/jump is a separate `transform` animation layered on top of the drift position so both can run simultaneously.
- **Camera / scan widget**: a 56×56px circular button pinned to the right edge, vertically centered (`position: absolute; right: 12px; top: 50%`), cream background, 3px black border, 📷 icon. Tapping it: (1) button icon becomes ⏳ and a centered "📷 Analyse en cours…" overlay appears (~900ms), (2) a random **undiscovered** Pokédex entry is marked discovered and a celebratory overlay pops in (✨ bounce/scale-in, "Nouveau Pokémon découvert !" + the name, ~1.3s), (3) the app automatically switches to the Pokédex tab, opens that Pokémon's detail sheet, and scrolls the grid so the newly-discovered entry is in view.
- **Empty state**: if the team is empty, a centered pill reads "Aucun Pokémon dans l'équipe."

### 2. Pokémon (owned roster)
- **Purpose**: Browse everything the player owns (team + PC box combined — no more separate sections, since the team already has its own home).
- **Layout**: Scrollable, 16px padding.
- **Sort control**: row of pill chips at the top — "#" (by Pokédex number), "Type", "A-Z" (alphabetical). Active chip: filled with the shell/accent color, white bold text. Inactive: `#2a2c48` background, `#c9cbe8` text. 20px border-radius pill, 2px solid `#201c14` border, 12px font.
- **List**: two layout variants (toggleable, see Tweaks): **Grid** (2 columns) or **List** (single column, compact rows). Each card: cream background (`#f2ecd6`), 2–3px solid `#201c14` border, small hard drop-shadow (no blur), sprite placeholder, name, type badge, HP bar. Cards for Pokémon **not** currently in the active team show a small "💻" badge in the top-right corner (grid) or inline before the type badge (list) to indicate "in PC / not in active team".
- **Empty state**: "Aucun Pokémon possédé."

### 3. Pokédex (shared discovery log)
- **Purpose**: Party-wide log of every species encountered in the campaign.
- **Layout**: Fixed (non-scrolling) header area + independently scrolling grid + a floating action button pinned to the bottom.
- **Header**: title "POKÉDEX" + "{discovered} / {total} découverts" counter, a full-width search input (placeholder "Rechercher un Pokémon…", 9px vertical / 12px horizontal padding, 2px solid border, 8px radius), then the same 3 sort chips as the Pokémon tab.
- **Grid**: 3 columns, each cell a square sprite placeholder + `#{numero}` below. Undiscovered entries render as a dark silhouette square (`#2a2c48`) with a large "?" and are not clickable (opacity 0.75, `cursor: default`); discovered entries are clickable and open the shared detail sheet.
- **Floating "scan" button**: pinned bottom, 16px inset from left/right/bottom, full-width, shell-colored background, white bold text, "📷 Ajouter un Pokémon" — triggers the same camera-scan flow described under Home.

### 4. Sac (Bag)
- **Purpose**: View and manage consumable/key items, and discover+add new ones.
- **Layout**: Scrollable, 16px padding.
- **Currency row**: cream card, 💰 icon, "Pokédollars" label, −/+ stepper buttons around the numeric value (steps of 10).
- **Add-item search** (replaces the old "+ Ajouter un objet" button): a text input ("Rechercher un objet…") with a **live autocomplete dropdown** underneath (absolute-positioned, appears only while there's a query, max 6 results, max-height 220px scrollable). Each result row: small sprite swatch, item name, and a right-aligned label — "Ajouter" if the player doesn't own it yet, or "{n} en sac" if they do. Clicking a result adds it (qty 1) or increments existing qty by 1, then clears the search field.
- **Category filter chips**: Tous / Soin / Balls / Combat / Unique / Évolution — same pill styling as the sort chips.
- **Item list**: filtered by category, each row shows sprite swatch, name, and a −/qty/+ stepper.
- **Empty state**: "Aucun objet dans cette catégorie."

### 5. Carte (Map)
- **Purpose**: Browse the region ("Ékaï") and tap points of interest.
- **Layout**: Full-bleed placeholder map background (diagonal-striped green, standing in for the real region art — swap for the real map image/asset), a top banner reading "CARTE DE LA RÉGION D'ÉKAÏ — image à venir" (remove once real art is wired up).
- **Pins**: 📍 emoji markers absolutely positioned by `x%`/`y%` coordinates. Tapping a pin opens a bottom info sheet (location type, name, description) with a close button; tapping elsewhere / the close button dismisses it.

## Shared: Pokémon Detail Sheet
Used from Home, Pokémon, and Pokédex (three call sites, one component). Bottom sheet, slides up over a dim scrim, max-height ~85% of screen, cream background, rounded top corners, drag-handle affordance at top.
- **Header**: 76×76px sprite, `#{numero}`, name (22px), type badge.
- **If opened from Home or Pokémon tab (an owned Pokémon)**: shows live HP bar and XP bar (with numeric values) above the stat grid.
- **Stat grid**: 2-column cards — "PV DE BASE" and "DÉGÂTS BASE".
- **Always shown, regardless of source**: Distance (in "cases"), Super Efficace (type badges the Pokémon is strong against, or "—" if none), Localisation (list of place names where it's found).
- **Abilities section — behavior differs by context**:
  - **Home**: "🥊 Capacités" section, **abilities open by default**, with a Afficher/Masquer toggle. Lists the Pokémon's **known** moves as detailed cards.
  - **Pokémon tab**: identical section/toggle, but **collapsed by default**.
  - **Pokédex tab**: "🥊 Capacités apprenables" — **no toggle**, always visible, and only shows **name chips** (no stats) for the moves this species **can learn**, not moves a specific owned instance currently knows.
  - **Detailed ability card fields** (for the Home/Pokémon full view — see reference icon layout image provided by the user): type badge + name header, then two icon-labeled columns: left = ↔️ Distance, 🔶 Dégâts de base, 🎲 Dégâts (dé), right = 👤 Cible, 🎯 Précision; an optional effect description line below if present.
- **Footer action** (context-dependent):
  - Owned Pokémon: a toggle button — "📦 Mettre au PC" (if currently in team) or "⚔️ Ajouter à l'équipe" (if not, and team has room) or a disabled "Équipe pleine (3/3)" state.
  - Pokédex, not yet owned: "+ Ajouter à mon équipe" button (adds a new instance to the roster, into the team if there's room, otherwise the PC).
  - Pokédex, already owned: a small "✓ Déjà dans votre roster" note, no button.

## Settings Popup
Opened via the ⚙️ button in the persistent top header (present on every screen). Centered modal card:
- Player identity row (avatar + name, or "Non connecté").
- "Plein écran" row with a toggle button (calls the Fullscreen API; label reflects state).
- "Se connecter" / "Se déconnecter" full-width button.
- "MODE ADMIN" section: password input + "OK" submit button, with inline feedback text.
- "Fermer" button.

## Interactions & Behavior Summary
- Bottom tab bar: 5 icon-only buttons (order: Pokédex 📖, Pokémon 🐾, Accueil 🏠, Sac 🎒, Carte 🗺️), taller than a standard tab bar (~16px vertical padding), active tab gets a 3px top border + subtle background tint in the shell/accent color.
- Top header persists across all tabs: small "signal light" dot, screen title, Pokédollars chip, ⚙️ settings button.
- Every list empty-state, search box, and stat display should be driven by real data, not hardcoded.
- No page reloads/navigation — this is a single persistent app shell with tab + sheet/modal state.

## State Management
Needed state (React or equivalent): active tab; roster (id, species ref, hp/maxHp, xp/maxXp, inTeam); pokédex discovery map; bag inventory (item ref + qty); currency amount; open detail sheet (id + source: roster/pokédex + abilities-open flag); settings modal open/closed + fullscreen/connected/admin-password fields; bag category filter + search text; pokédex search text + sort key; pokémon-tab sort key; map selected pin; Home roam/idle/jump animation state (per-Pokémon position + jump flag); scan flow state (idle/scanning/celebrate + result).

## Design Tokens
- **Font**: "Jersey 25" (Google Fonts) everywhere, fallback `system-ui, sans-serif`.
- **Colors**:
  - App background: `#14162a`
  - Cream panel/sheet background: `#f2ecd6`; secondary/PC-card cream: `#e4dcc2`; button cream: `#e0d8bd`
  - Ink (text on cream): `#201c14`; muted ink: `#5c5540` / `#8a8362`
  - Shell/accent (tweakable): `#DC0A2D` (red, default) / `#2f6fb8` (blue) / `#3f8f5c` (green)
  - HP colors: green `#4caf6b` (≥50%), orange `#e8933d` (20–50%), red `#d64545` (<20%)
  - XP bar: `#4a7fd6`
  - Tab bar background: `#1c1e38`; inactive tab icon `#7a7c9a`
  - Type colors: standard type-color mapping (Normal `#A8A878`, Feu `#F08030`, Eau `#6890F0`, Plante `#78C850`, Electrik `#F8D030`, Glace `#98D8D8`, Combat `#C03028`, Poison `#A040A0`, Sol `#E0C068`, Vol `#A890F0`, Psy `#F85888`, Insecte `#A8B820`, Roche `#B8A038`, Spectre `#705898`, Dragon `#7038F8`, Ténèbres `#705848`, Acier `#B8B8D0`, Fée `#EE99AC`) — matches the existing `TypeBadge` component's palette; reuse it as-is.
- **Borders/shadows**: chunky pixel look — 2–3px solid `#201c14` borders, hard (non-blurred) drop shadows like `3px 3px 0 rgba(0,0,0,0.35)`, 6–10px border-radius (not fully square, not fully rounded).
- **Spacing**: 16px screen padding; 8–14px gaps between list items/cards.

## Assets
No real image assets were used — every Pokémon/item "sprite" in the mockup is a generated placeholder (CSS diagonal stripe pattern tinted to the entry's type color, plus a small monospace name label). **Do not ship these placeholders** — replace with the real `image_miniature` / `image_illustree` (Pokémon) and `image_url` (items) fields already present in the existing app's Supabase schema (`Pokedex/src/types.ts`), sized/masked identically to where the placeholders sit. The user separately supplied official Pokémon sprite reference images during this session; those are copyrighted assets and were intentionally **not** incorporated into the design or this handoff — do not use them as production art either without the appropriate license.

## Files
- `Pokemon Companion App.dc.html` — the full interactive mockup (all 5 screens + shared detail sheet + settings modal), for visual/behavioral reference only (see "About the Design Files" above). Open in a browser to click through it.
