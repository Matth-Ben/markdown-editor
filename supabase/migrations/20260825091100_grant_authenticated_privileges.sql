-- Chantier "Personnages" (app mobile) — Phase 1 — Socle de données.
-- GRANTs explicites sur les tables créées par les migrations précédentes.
--
-- Constat fait en testant les migrations sur un stack Supabase local frais
-- (`supabase db reset`) : sans GRANT explicite, PostgREST/psql renvoient
-- "permission denied for table ..." au rôle authenticated, avant même que
-- RLS n'intervienne — y compris sur `public.stories`/`public.codex_entries`
-- (tables existantes, sans GRANT explicite dans leurs migrations). Cela
-- suggère que le projet Supabase distant `nexus-jdr` a été initialisé avec
-- des privilèges par défaut accordés à `authenticated`/`anon` sur le schéma
-- `public` (comportement historique de la plateforme, avant la dépréciation
-- de `auto_expose_new_tables` mentionnée dans supabase/config.toml). Pour ne
-- pas dépendre de cette hypothèse sur l'environnement distant, cette
-- migration accorde explicitement les privilèges nécessaires : cela ne
-- casse rien si le projet les avait déjà (GRANT est idempotent), et
-- sécurise le cas où ce ne serait pas le cas.
--
-- Seul le rôle `authenticated` reçoit des privilèges (pas `anon`), cohérent
-- avec "lecture publique authentifiée" de 01-architecture-technique.md :
-- toutes les données de ce chantier nécessitent une session authentifiée,
-- même en lecture. RLS (déjà en place) continue de restreindre les lignes
-- réellement visibles/modifiables au sein de ces privilèges de table.

grant usage on schema public to authenticated;

-- Tables de référence : select/insert/update/delete accordés à
-- `authenticated`, la restriction réelle (lecture pour tous, écriture
-- admin uniquement) étant portée par les policies RLS déjà en place.
grant select, insert, update, delete on table
  public.abilities,
  public.skills,
  public.alignments,
  public.languages,
  public.tools,
  public.races,
  public.subraces,
  public.classes,
  public.subclasses,
  public.class_features,
  public.backgrounds,
  public.feats,
  public.spells,
  public.spell_classes,
  public.invocations,
  public.items,
  public.weapon_properties,
  public.armor_properties,
  public.equipment_packs,
  public.translations
to authenticated;

-- Tables personnage : select/insert/update/delete accordés à
-- `authenticated`, la restriction au propriétaire étant portée par les
-- policies RLS déjà en place (auth.uid() = owner_id / public.owns_character()).
grant select, insert, update, delete on table
  public.characters,
  public.character_classes,
  public.character_level_hp,
  public.character_ability_scores,
  public.character_ability_increases,
  public.character_skill_proficiencies,
  public.character_tool_proficiencies,
  public.character_languages,
  public.character_feats,
  public.character_spells,
  public.character_spell_slots,
  public.character_invocations,
  public.character_feature_uses,
  public.character_inventory,
  public.character_class_options
to authenticated;

-- public.app_admins reste volontairement sans GRANT pour authenticated : ni
-- la policy RLS (using (false)) ni le privilège de table ne doivent
-- permettre le moindre accès client à cette table d'allow-list.
