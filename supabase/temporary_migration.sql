-- ============================================================
-- Migration à coller dans le Supabase SQL Editor
-- ------------------------------------------------------------
-- Un seul changement : publier admin_parameters en temps réel.
--
-- Symptôme : le bouton « Afficher l'écran » de l'accueil (et, en réalité,
-- TOUS les interrupteurs « Mode En ligne », « Chat », « Mini-Jeux »,
-- « Pension », « Safari »… de Admin → Paramètres) n'apparaissait ou ne
-- disparaissait chez les joueurs qu'après un rechargement de page.
--
-- Cause : src/hooks/useAdminParameters.ts s'abonne bien aux UPDATE de
-- admin_parameters, mais la table n'a jamais été ajoutée à la publication
-- `supabase_realtime` — Postgres n'émettait donc rien et l'abonnement
-- attendait dans le vide, sans la moindre erreur visible. Vérifié en direct :
-- une modification de online_state se propage instantanément à la page
-- ouverte, la même modification sur admin_parameters n'arrive jamais.
--
-- Rien d'autre à changer : la table est déjà lisible par `anon` (les clients
-- la chargent au démarrage), et la ligne diffusée est exactement celle qu'ils
-- récupèrent déjà — aucune donnée nouvelle n'est exposée.
--
-- Le bloc teste avant d'ajouter : il peut être rejoué sans erreur.
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'admin_parameters'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE admin_parameters;
  END IF;
END $$;
