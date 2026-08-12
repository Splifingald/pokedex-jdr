-- ============================================================
-- Migration à exécuter dans Supabase SQL Editor
-- Ajoute les policies RLS de suppression manquantes sur pvp_challenges et
-- pvp_challenge_attempts : sans elles, DELETE FROM ... échoue silencieusement
-- (RLS filtre les lignes, aucune erreur), ce qui rendait déjà inopérant le
-- bouton "Supprimer tous les défis passés" de l'admin PvP. Nécessaires pour
-- les nouveaux boutons "Supprimer le défi" / suppression d'une ligne du
-- tableau des scores dans AdminPvpPanel (voir supabase/schema.sql, source de
-- vérité complète et idempotente, et CLAUDE.md pour la convention de ce
-- fichier).
-- ============================================================

DROP POLICY IF EXISTS "Public delete pvp_challenges" ON pvp_challenges;
CREATE POLICY "Public delete pvp_challenges" ON pvp_challenges FOR DELETE TO anon USING (true);

DROP POLICY IF EXISTS "Public delete pvp_challenge_attempts" ON pvp_challenge_attempts;
CREATE POLICY "Public delete pvp_challenge_attempts" ON pvp_challenge_attempts FOR DELETE TO anon USING (true);
