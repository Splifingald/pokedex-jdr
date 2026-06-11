# Guide de déploiement — Pokédex RPG

## Étape 1 — Créer un projet Supabase

1. Va sur [supabase.com](https://supabase.com) et crée un compte gratuit
2. Clique **New project**, donne-lui un nom (ex: `pokedex-rpg`) et note le mot de passe de base de données
3. Attends ~2 minutes que le projet démarre

### Configurer la base de données

1. Dans le menu gauche, va dans **SQL Editor**
2. Clique **New query**
3. Copie-colle tout le contenu du fichier `supabase/schema.sql` de ce projet
4. Clique **Run** — tu dois voir "Success"

### Récupérer les clés API

1. Va dans **Settings > API**
2. Copie **Project URL** (ex: `https://abcdefgh.supabase.co`)
3. Copie **anon public** key (longue chaîne JWT)

---

## Étape 2 — Déployer l'Edge Function

L'Edge Function gère l'import CSV de façon sécurisée.

### Installer Supabase CLI

```bash
npm install -g supabase
```

### Connexion et déploiement

```bash
supabase login
supabase link --project-ref TON_PROJECT_REF
# (le project ref est dans l'URL de ton projet Supabase, ex: abcdefghijklmnop)

supabase functions deploy import-pokemon
```

### Configurer le secret admin

1. Dans Supabase Dashboard → **Edge Functions** → **import-pokemon** → **Secrets**
2. Ajoute un secret : **Key** = `ADMIN_SECRET`, **Value** = `Rioluxray171216`

---

## Étape 3 — Créer un compte Netlify et déployer

### Préparer le dépôt GitHub

1. Va sur [github.com](https://github.com), crée un compte
2. Crée un nouveau dépôt public ou privé (ex: `pokedex-rpg`)
3. Dans le dossier du projet, ouvre un terminal et lance :

```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/TON_USERNAME/pokedex-rpg.git
git push -u origin main
```

### Déployer sur Netlify

1. Va sur [netlify.com](https://netlify.com), crée un compte gratuit
2. Clique **Add new site > Import an existing project > GitHub**
3. Autorise Netlify à accéder à GitHub, sélectionne ton dépôt
4. Paramètres de build :
   - **Build command** : `npm run build`
   - **Publish directory** : `dist`
5. Clique **Show advanced** puis **New variable** et ajoute :
   - `VITE_SUPABASE_URL` = l'URL de ton projet Supabase
   - `VITE_SUPABASE_ANON_KEY` = la clé anon de ton projet Supabase
   - `VITE_ADMIN_SECRET` = `Rioluxray171216`
6. Clique **Deploy site** — le déploiement prend ~1 minute

---

## Étape 4 — Première utilisation

1. Ouvre l'URL Netlify de ton site (ex: `https://awesome-name-123.netlify.app`)
2. **Clique sur le coin supérieur gauche** (zone invisible de 50×50px) pour ouvrir le mode admin
3. Entre le mot de passe admin
4. Clique **Importer CSV** et sélectionne ton fichier pokémon
5. Attends la confirmation — le pokédex se remplit !

---

## Étape 5 — Installer comme application (PWA)

### Sur Android (Chrome)
1. Ouvre le site dans Chrome
2. Tape le menu ⋮ → **Ajouter à l'écran d'accueil**
3. L'icône apparaît sur ton écran d'accueil, le site s'ouvre en plein écran

### Sur iPhone (Safari uniquement)
1. Ouvre le site dans **Safari** (pas Chrome)
2. Tape l'icône **Partager** (rectangle avec flèche)
3. Sélectionne **Sur l'écran d'accueil**

---

## Format du fichier CSV

Ton fichier CSV doit avoir **exactement ces colonnes** (en-têtes avec accents) :

| Colonne | Type | Exemple |
|---------|------|---------|
| Numéro | Texte | 001 |
| Nom | Texte | Bulbizarre |
| Type | Texte | Plante |
| Dégâts de base | Nombre | 12 |
| PV de base | Nombre | 45 |
| Super Efficace 1 | Texte | Feu |
| Super Efficace 2 | Texte | Glace |
| Super Efficace 3 | Texte (optionnel) | |
| Super Efficace 4 | Texte (optionnel) | |
| Distance de déplacement en combat | Nombre | 3 |
| Image miniature | URL | https://... |
| Image illustrée | URL | https://... |
| Nom du talent | Texte (optionnel) | Engrais |
| Description du talent | Texte (optionnel) | Soigne 5 PV par tour |
| Chances de capture | Texte (optionnel) | 45% |
| Localisation 1 | Texte (optionnel) | Forêt de Jade |
| Localisation 2 | Texte (optionnel) | Route 2 |
| Localisation 3 | Texte (optionnel) | |

> **Conseil** : Crée ton CSV dans Google Sheets et exporte en *Fichier > Télécharger > CSV*.  
> Pour les images, héberge-les sur [Imgur](https://imgur.com) ou [Google Drive](https://drive.google.com) (lien direct).

---

## Notes de sécurité

- Le mot de passe admin est stocké dans le code JavaScript compilé. Pour une utilisation entre amis, c'est acceptable.
- Ne partagez pas l'URL du site publiquement si vous souhaitez garder le pokédex secret avant la session.
- La clé `VITE_SUPABASE_ANON_KEY` est publique par design (c'est la clé anonyme). Les politiques RLS Supabase protègent les données.
