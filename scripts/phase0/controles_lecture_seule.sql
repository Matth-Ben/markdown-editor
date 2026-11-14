-- Phase 0 : requêtes de contrôle EN LECTURE SEULE (aucun INSERT/UPDATE/DELETE/DDL).
-- À lancer par Matthias dans l'éditeur SQL du projet de production (vérifier la cible avant), AVANT puis APRÈS chaque
-- migration (sections indiquées). Les résultats sont des noms d'objets et des agrégats : aucune donnée personnelle.
-- Si un classificateur bloque une requête, la lancer seul. Coller les résultats dans la PR.

-- ============================== AVANT (état réel, objets ajoutés hors migrations D58/D72) ==============================

-- C1. Volumétrie des tables concernées (estimation + taille) : à lire avant les migrations d'index (verrou SHARE de create index).
select c.relname as table_name, c.reltuples::bigint as lignes_estimees,
       pg_size_pretty(pg_total_relation_size(c.oid)) as taille_totale
  from pg_class c
 where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
   and c.relname in ('characters', 'character_ability_increases', 'character_class_options', 'character_classes',
                     'character_inventory', 'character_journal_entries', 'character_level_hp', 'character_photos',
                     'character_race_choices', 'character_spells', 'character_tool_proficiencies', 'group_members',
                     'groups', 'group_journal_entries', 'group_notes', 'combat_participants', 'combats',
                     'bug_reports', 'character_campaigns', 'class_features', 'spell_classes', 'group_treasure')
 order by pg_total_relation_size(c.oid) desc;

-- C2. Index déjà présents sur ces tables (les migrations d'index sautent un index équivalent déjà là, même sous un autre nom).
select t.relname as table_name, i.relname as index_name, pg_get_indexdef(x.indexrelid) as definition, x.indisvalid
  from pg_index x
  join pg_class t on t.oid = x.indrelid
  join pg_class i on i.oid = x.indexrelid
 where t.relnamespace = 'public'::regnamespace
   and t.relname in ('characters', 'character_ability_increases', 'character_class_options', 'character_classes',
                     'character_inventory', 'character_journal_entries', 'character_level_hp', 'character_photos',
                     'character_race_choices', 'character_spells', 'character_tool_proficiencies', 'group_members',
                     'groups', 'group_journal_entries', 'group_notes', 'combat_participants', 'combats',
                     'bug_reports', 'character_campaigns', 'class_features', 'spell_classes')
 order by 1, 2;

-- C3. Politiques RLS des 8 tables de la migration RLS : toutes doivent être `to authenticated`, 30 attendues ;
--     « auth_uid_nu » = nombre attendu de 26 AVANT, 0 APRÈS.
select tablename, policyname, cmd, roles::text,
       ((coalesce(qual, '') || coalesce(with_check, '')) ~ '(?<!SELECT )auth\.uid\(\)') as auth_uid_nu
  from pg_policies
 where schemaname = 'public'
   and tablename in ('bug_reports', 'characters', 'group_journal_entries', 'group_members', 'group_notes', 'groups',
                     'notification_preferences', 'user_push_tokens')
 order by 1, 2;

-- C4. Nombre de politiques par table, tout le schéma public (détecte une politique ajoutée hors migrations : comparer au dépôt).
select tablename, count(*) as politiques, string_agg(distinct roles::text, ' ; ') as roles
  from pg_policies where schemaname = 'public' group by 1 order by 1;

-- C5. Contraintes CHECK déjà présentes sur les tables de la migration CHECK (aucune des 10 ne doit déjà exister sous ce nom ; la migration détecte aussi les équivalents).
select conrelid::regclass::text as table_name, conname, convalidated, pg_get_constraintdef(oid) as definition
  from pg_constraint
 where contype = 'c' and connamespace = 'public'::regnamespace
   and conrelid::regclass::text in ('characters', 'group_treasure', 'character_inventory', 'character_classes',
                                    'character_spell_slots', 'character_pact_slots', 'character_feature_uses')
 order by 1, 2;

-- C6. VIOLATIONS des 10 contraintes (doit renvoyer 0 partout, à lancer AVANT la migration CHECK (6/6) ; elle est aussi exécutée dans la migration, qui échoue s'il y en a : une ligne fautive ferait
--     échouer tout UPDATE de cette ligne dès l'ajout de la contrainte NOT VALID ; et avant la validation différée).
select 'characters_hp_nonnegative' as contrainte, count(*) as violations from public.characters where not (current_hp >= 0 and temporary_hp >= 0)
union all select 'characters_xp_nonnegative', count(*) from public.characters where not (xp >= 0)
union all select 'characters_currency_nonnegative', count(*) from public.characters
           where not (currency_gp >= 0 and currency_pp >= 0 and currency_ep >= 0 and currency_sp >= 0 and currency_cp >= 0)
union all select 'group_treasure_currency_nonnegative', count(*) from public.group_treasure
           where not (currency_gp >= 0 and currency_pp >= 0 and currency_ep >= 0 and currency_sp >= 0 and currency_cp >= 0)
union all select 'group_treasure_items_is_array', count(*) from public.group_treasure where not (jsonb_typeof(items) = 'array')
union all select 'character_inventory_quantity_nonnegative', count(*) from public.character_inventory where not (quantity >= 0)
union all select 'character_classes_level_positive', count(*) from public.character_classes where not (level >= 1)
union all select 'character_spell_slots_counts_nonnegative', count(*) from public.character_spell_slots where not (slots_total >= 0 and slots_used >= 0)
union all select 'character_pact_slots_counts_nonnegative', count(*) from public.character_pact_slots where not (slots_total >= 0 and slots_used >= 0)
union all select 'character_feature_uses_remaining_nonnegative', count(*) from public.character_feature_uses where not (uses_remaining >= 0);

-- C7. Droits et réglages des fonctions de la migration droits (acl vide = droits par défaut ; 'anon=X' ou '=X' = exécutable par anon/PUBLIC).
select p.proname, pg_get_function_identity_arguments(p.oid) as arguments,
       case when p.prosecdef then 'definer' else 'invoker' end as securite,
       p.proconfig::text as reglages, p.proacl::text as acl
  from pg_proc p
 where p.pronamespace = 'public'::regnamespace and p.prokind = 'f'
   and p.proname in ('owns_character', 'is_group_member', 'is_admin', 'group_member_can_read_character',
                     'story_owner_can_read_character', 'character_owner_can_read_joined_story', 'claim_push_token',
                     'release_push_token', 'claim_group_treasure_currency', 'get_group_member_character',
                     'refresh_proposal_counts', 'notify_character_campaign_access_revoked', 'notify_new_app_version',
                     'on_group_created', 'trg_content_proposals_review', 'trg_refresh_proposal_counts')
 order by 1;

-- C8. Fonctions publiques exécutables par anon (Q-SQL-24 ; attendu APRÈS : get_shared_character + les 5 fonctions de colonne calculée).
select p.proname, p.prosecdef as definer
  from pg_proc p
 where p.pronamespace = 'public'::regnamespace and has_function_privilege('anon', p.oid, 'execute')
 order by 1;

-- C9. Triggers existants sur characters (un BEFORE UPDATE gérant updated_at fait échouer la migration trigger) et collision de fonction.
select tgname, tgenabled from pg_trigger where tgrelid = 'public.characters'::regclass and not tgisinternal;
select proname, md5(prosrc) as empreinte_corps from pg_proc where pronamespace = 'public'::regnamespace and proname in ('characters_touch_updated_at', 'set_updated_at');   -- attendu AVANT : 0 ligne
select t.tgname, p.proname, (p.prosrc ~* 'updated_at') as mentionne_updated_at from pg_trigger t join pg_proc p on p.oid = t.tgfoid
 where t.tgrelid = 'public.characters'::regclass and not t.tgisinternal and (t.tgtype & 2) = 2 and (t.tgtype & 16) = 16;   -- BEFORE UPDATE

-- C10. État de characters.updated_at avant le trigger (preuve qu'elle ne bouge jamais).
select count(*) as personnages, count(*) filter (where updated_at = created_at) as updated_at_egal_created_at,
       min(updated_at) as plus_ancienne, max(updated_at) as plus_recente
  from public.characters;

-- C11. APPELANTS anonymes/publics des 16 fonctions dont EXECUTE sera retiré (migration droits) : doit renvoyer 0 ligne. C'est le
--      garde-fou de la migration, en lecture seule : politiques de TOUS les schémas (storage inclus) dont les rôles incluent public/anon
--      (ou sans clause TO), vues, vues matérialisées, défauts de colonne, contraintes CHECK, fonctions non security definer exécutables par anon.
with f(name) as (values ('owns_character'), ('is_group_member'), ('is_admin'), ('group_member_can_read_character'),
  ('story_owner_can_read_character'), ('character_owner_can_read_joined_story'), ('claim_push_token'), ('release_push_token'),
  ('claim_group_treasure_currency'), ('get_group_member_character'), ('refresh_proposal_counts'),
  ('notify_character_campaign_access_revoked'), ('notify_new_app_version'), ('on_group_created'),
  ('trg_content_proposals_review'), ('trg_refresh_proposal_counts')),
re(r) as (select '\m(' || string_agg(name, '|') || ')\M' from f)
select 'politique' as type_objet, schemaname || '.' || tablename || ' : ' || policyname || ' ' || roles::text as objet
  from pg_policies, re
 where (roles && array['public', 'anon']::name[]) and (coalesce(qual, '') || ' ' || coalesce(with_check, '')) ~ re.r
union all select 'vue', schemaname || '.' || viewname from pg_views, re
 where schemaname not in ('pg_catalog', 'information_schema') and definition ~ re.r
union all select 'vue matérialisée', schemaname || '.' || matviewname from pg_matviews, re
 where schemaname not in ('pg_catalog', 'information_schema') and definition ~ re.r
union all select 'défaut de colonne', c.oid::regclass::text || '.' || a.attname
  from pg_attrdef d join pg_class c on c.oid = d.adrelid join pg_attribute a on a.attrelid = d.adrelid and a.attnum = d.adnum, re
 where c.relnamespace not in ('pg_catalog'::regnamespace, 'information_schema'::regnamespace) and pg_get_expr(d.adbin, d.adrelid) ~ re.r
union all select 'contrainte CHECK', conrelid::regclass::text || '.' || conname from pg_constraint, re
 where contype = 'c' and pg_get_constraintdef(oid) ~ re.r
union all select 'fonction invoker exécutable par anon', p.oid::regprocedure::text from pg_proc p, re
 where p.prokind = 'f' and not p.prosecdef and p.pronamespace not in ('pg_catalog'::regnamespace, 'information_schema'::regnamespace)
   and p.prosrc ~ re.r and p.proname not in (select name from f) and has_function_privilege('anon', p.oid, 'execute');

-- C12. Collision éventuelle de fonctions/triggers de la migration trigger : voir C9 (attendu AVANT : aucune ligne `characters_touch_updated_at`).

-- ============================== APRÈS (à relancer après chaque migration, comparer à AVANT) ==============================

-- A1. Migrations index (3/6) : les index créés sont valides.
select t.relname as table_name, c.relname as index_name, x.indisvalid
  from pg_index x
  join pg_class c on c.oid = x.indexrelid
  join pg_class t on t.oid = x.indrelid
 where c.relnamespace = 'public'::regnamespace and c.relname ~ '_idx$' and c.relname in (
   'characters_owner_id_idx', 'character_ability_increases_character_id_idx', 'character_class_options_character_id_idx',
   'character_classes_character_id_idx', 'character_inventory_character_id_idx', 'character_journal_entries_character_id_idx',
   'character_level_hp_character_id_idx', 'character_photos_character_id_idx', 'character_race_choices_character_id_idx',
   'character_spells_character_id_idx', 'character_tool_proficiencies_character_id_idx', 'group_members_user_id_idx',
   'group_members_character_id_idx', 'groups_owner_id_idx', 'group_journal_entries_group_id_user_id_idx',
   'group_journal_entries_user_id_idx', 'group_notes_user_id_idx', 'group_notes_character_id_idx',
   'combat_participants_character_id_idx', 'combat_participants_user_id_idx', 'combats_started_by_idx',
   'bug_reports_reporter_id_idx', 'bug_reports_character_id_idx', 'character_campaigns_story_id_idx',
   'class_features_class_id_idx', 'class_features_subclass_id_idx', 'spell_classes_class_id_idx')
 order by 1, 2;   -- attendu : 27 lignes, indisvalid = true
select indexrelid::regclass::text as index_invalide from pg_index where not indisvalid;   -- attendu : 0 ligne

-- A2. Migration RLS (2/6) : relancer C3 (attendu : 30 politiques, auth_uid_nu = false partout).
-- A3. Migration CHECK (6/6) : les 10 contraintes sont NOT VALID (convalidated = false) ; après la validation différée, true.
select conrelid::regclass::text as table_name, conname, convalidated
  from pg_constraint
 where contype = 'c' and connamespace = 'public'::regnamespace
   and conname in ('characters_hp_nonnegative', 'characters_xp_nonnegative', 'characters_currency_nonnegative',
                   'group_treasure_currency_nonnegative', 'group_treasure_items_is_array',
                   'character_inventory_quantity_nonnegative', 'character_classes_level_positive',
                   'character_spell_slots_counts_nonnegative', 'character_pact_slots_counts_nonnegative',
                   'character_feature_uses_remaining_nonnegative')
 order by 1, 2;
-- A4. Migration droits (5/6) : relancer C7 et C8.
-- A5. Migration trigger (1/6) : relancer C9 (attendu : characters_set_updated_at, enabled = 'O') ; puis, après quelques jours d'usage, C10
--     (updated_at_egal_created_at doit diminuer au fil des modifications des joueurs).
