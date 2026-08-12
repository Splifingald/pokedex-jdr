# Instructions pour agents IA — Pokédex RPG

## Migrations SQL Supabase

Ce projet n'a **aucun accès CLI/DB direct** (pas de `SUPABASE_ACCESS_TOKEN` ni de connection string Postgres dans `.env.local`, seulement les clés REST anon/service-role) : toute modification du schéma (nouvelles tables/colonnes/contraintes/fonctions) doit être appliquée **manuellement par l'utilisateur** via le Supabase SQL Editor.

**Convention obligatoire — à suivre à chaque fois qu'une tâche nécessite que l'utilisateur exécute du SQL :**

1. Écrire ce SQL — **et uniquement lui, jamais tout `schema.sql`** — dans un fichier séparé nommé **toujours pareil** : `supabase/temporary_migration.sql`. Écraser son contenu précédent à chaque nouvelle tâche (ne pas empiler, ne pas versionner son historique).
2. Mettre à jour `supabase/schema.sql` en parallèle avec les mêmes changements — il reste la source de vérité du schéma complet, toujours écrit de façon idempotente (`CREATE TABLE IF NOT EXISTS`, `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`, etc.) pour pouvoir être rejoué intégralement sur une base déjà à jour sans erreur.
3. Prévenir explicitement l'utilisateur, à la fin de la tâche, qu'il doit copier/coller **le contenu de `supabase/temporary_migration.sql`** (pas un extrait du chat, pas une partie de `schema.sql`) dans le Supabase SQL Editor.
4. Ne jamais lui demander de repérer/extraire lui-même un morceau de `schema.sql` — c'est le travail de l'agent de préparer le fichier prêt à coller.

`supabase/temporary_migration.sql` est un fichier de **travail, jetable, régénéré à chaque tâche** — ne pas s'appuyer sur son contenu d'une session à l'autre. C'est différent des anciens fichiers `supabase/*.sql` du type `battle_fixes_batchN.sql` / `manual_battle_and_combat_effects.sql`, qui documentent chacun un correctif précis et peuvent rester comme changelog historique (voir leurs en-têtes).

## Piège vécu : BOM (byte order mark)

Lors de la création du mode PvP, un script PowerShell utilisant `Set-Content -Encoding UTF8` a inséré un BOM (`EF BB BF`) en tête d'un fichier temporaire ; ce BOM s'est ensuite retrouvé **au milieu** de `schema.sql` après un `cat fichier >> schema.sql`, provoquant une erreur `syntax error at or near "﻿"` à l'exécution dans Supabase — invisible à l'oeil dans un éditeur de texte normal.

**Pour l'écrire/l'éditer, `schema.sql` (et tout fichier destiné à être exécuté tel quel par Postgres) doit toujours rester UTF-8 SANS BOM :**
- Outils `Write`/`Edit` : sans risque, n'ajoutent pas de BOM.
- PowerShell `Set-Content`/`Out-File -Encoding UTF8` : **ajoute un BOM par défaut**, à éviter sur ces fichiers (préférer `-Encoding utf8NoBOM` si PowerShell 7+, sinon repasser par `Write`/`Edit`, ou nettoyer après coup).
- Si un doute existe après une manipulation de fichier volumineuse (découpage/fusion via script), vérifier avant de livrer :
  ```bash
  python3 -c "
  with open('supabase/schema.sql','rb') as f: data = f.read()
  print('BOM count:', data.count(b'\xef\xbb\xbf'))
  data.decode('utf-8')  # lève une erreur si l'encodage est cassé
  "
  ```

## Autres notes

- `SETUP.md` est le guide de déploiement destiné à l'utilisateur (Supabase/Netlify/PWA) — ne pas y mélanger des instructions pour agents IA, celles-ci vont dans ce fichier (`CLAUDE.md`).
