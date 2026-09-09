"""Génère supabase/migrations/20260910130000_seed_class_features_non_srd_progression.sql
à partir de scripts/class_features_non_srd_draft.json (lot 4, contenu D&D hors SRD,
progression multi-niveaux des 33 sous-classes rédigée par dev-backend-supabase puis
relue et corrigée par le chef de projet -- voir le commentaire en tête de la migration
générée pour le détail des 8 corrections factuelles).

Conservé pour traçabilité/reproductibilité (même principe que les scripts .mjs des lots
précédents) : si class_features_non_srd_draft.json est de nouveau corrigé, relancer ce
script régénère la migration à l'identique plutôt que de la retoucher à la main.

Usage : python scripts/generate-class-features-non-srd-migration.py
(depuis la racine du dépôt web H:\\Projets\\Labo\\markdown-editor)
"""

import json

DRAFT_PATH = "scripts/class_features_non_srd_draft.json"
OUTPUT_PATH = "supabase/migrations/20260910130000_seed_class_features_non_srd_progression.sql"

# Résolution class_name/subclass_name (du fichier source) -> id(s) réel(s) de
# public.subclasses, obtenus par requête directe sur le projet distant
# (npx supabase db query --linked) avant de lancer ce script -- les noms du
# fichier source diffèrent souvent de la base (ex. "Voie du guerrier totem" ==
# "Guerrier totem" en base), d'où cette table plutôt qu'un matching par nom.
SUBCLASS_MAP = {
    ("Barbare", "Voie du guerrier totem"): [13],
    ("Barbare", "Voie de la magie sauvage"): [18],
    ("Barde", "Collège de la vaillance"): [20],
    ("Clerc", "Domaine de la duperie"): [27],
    ("Clerc", "Domaine de la forge"): [34],
    ("Clerc", "Domaine de la guerre"): [28],
    ("Clerc", "Domaine de la lumière"): [29],
    ("Clerc", "Domaine de la nature"): [30],
    ("Clerc", "Domaine de la tempête"): [32],
    ("Clerc", "Domaine du savoir"): [31],
    ("Druide", "Cercle de la lune"): [36],
    ("Ensorceleur", "Magie sauvage"): [42],
    ("Guerrier", "Maître de guerre"): [48],
    ("Guerrier", "Chevalier occulte"): [49],
    ("Magicien", "École d'abjuration"): [55],
    ("Magicien", "École de divination"): [56],
    ("Magicien", "École d'enchantement"): [57],
    ("Magicien", "École d'illusion"): [58],
    ("Magicien", "École d'invocation"): [59],
    ("Magicien", "École de nécromancie"): [60],
    ("Magicien", "École de transmutation"): [61],
    ("Moine", "Voie de l'ombre"): [65],
    ("Moine", "Voie des quatre éléments"): [66],
    ("Occultiste", "L'Archifée"): [73],
    ("Occultiste", "Le Grand Ancien"): [74],
    # Le fichier source ne détaille pas les 4 variantes de génie séparément
    # (mécanique de patron partagée) -- dupliqué sur les 4 sous-classes déjà
    # en base (Génie - Dao/Djinn/Éfrit/Maride).
    ("Occultiste", "Le Génie"): [76, 77, 78, 79],
    # subclass_id=7 est la sous-classe "iconique" posée en Phase 1 pour ce
    # serment (PAS le Serment de dévotion SRD, id=83, déjà complet au lot 2).
    ("Paladin", "Serment des anciens"): [7],
    ("Paladin", "Serment de vengeance"): [84],
    ("Roublard", "Assassin"): [96],
    ("Roublard", "Escroc arcanique"): [97],
    ("Roublard", "Conspirateur"): [100],
    ("Rôdeur", "Gardien de drake"): [91],
    ("Rôdeur", "Maître des bêtes"): [89],
}


def esc(value):
    if value is None:
        return "null"
    return "$q$" + value.replace("$q$", "$$") + "$q$"


def main():
    with open(DRAFT_PATH, encoding="utf-8") as f:
        data = json.load(f)

    rows = []
    missing = set()
    for entry in data:
        key = (entry["class_name"], entry.get("subclass_name"))
        ids = SUBCLASS_MAP.get(key)
        if not ids:
            missing.add(key)
            continue
        for subclass_id in ids:
            rows.append(
                (
                    subclass_id,
                    entry["level"],
                    entry["name_fr"],
                    entry["description_originale_proposee"],
                    entry.get("choice_type"),
                    entry.get("uses_per_rest"),
                )
            )

    if missing:
        raise SystemExit(f"Sous-classes non mappées dans SUBCLASS_MAP : {missing}")

    values_lines = []
    for subclass_id, level, name, description, choice_type, uses_per_rest in rows:
        choice_sql = esc(choice_type)
        if uses_per_rest:
            uses_sql = "'" + json.dumps(uses_per_rest, ensure_ascii=False).replace("'", "''") + "'::jsonb"
        else:
            uses_sql = "null::jsonb"
        values_lines.append(
            f"      ({subclass_id}, {level}, {esc(name)}, {esc(description)}, {choice_sql}, {uses_sql})"
        )
    values_block = ",\n".join(values_lines)

    sql = f"""-- Chantier "Personnages" (app mobile) -- contenu D&D, lot 4 (relu par le chef de projet).
-- Complete public.class_features avec la progression multi-niveaux des sous-classes
-- hors SRD (license_status official_needs_verification dans class_features.json),
-- reformulee en texte original (jamais copie du livre) -- voir
-- scripts/class_features_non_srd_draft.json pour la trace complete, y compris les
-- 8 corrections factuelles faites en relecture par le chef de projet avant cette
-- migration (ex. "Aspect de la bete" Aigle confondait niveau 6 et niveau 14 ;
-- "Benediction de l'escroc"/"Linceul d'ombre"/"Pretre de guerre" du Clerc
-- decrivaient un effet mecaniquement different du RAW ; "Esprit eveille" de
-- l'Occultiste inventait un prerequis de langue commune qui n'existe pas RAW ;
-- type de degats de "Frappe divine" corrige pour Guerre/Duperie).
--
-- Occultiste "Le Genie" : le fichier source ne detaille pas les 4 variantes
-- (Dao/Djinn/Efrit/Maride) separement (mecanique de patron partagee, seul le
-- talent elementaire differe, deja hors perimetre de ce lot) -- les 10 lignes
-- du fichier pour "Le Genie" sont donc dupliquees sur les 4 sous-classes deja
-- en base (Genie - Dao/Djinn/Efrit/Maride, ids 76-79).
--
-- Paladin "Serment des anciens" (subclass_id=7) : c'est la sous-classe
-- "iconique" posee en Phase 1 pour ce serment (PAS le Serment de devotion
-- SRD, id=83, deja complete au lot 2) -- non-SRD comme les autres de ce lot.
--
-- Dedoublonnage par subclass_id + niveau + nom (idempotent, comme le lot 2).

do $$
declare
  rec record;
  v_id int;
begin
  for rec in
    select * from (values
{values_block}
    ) as t(subclass_id, level, name, description, choice_type, uses_per_rest)
  loop
    if not exists (
      select 1 from public.class_features cf
      join public.translations n on n.entity_type = 'class_feature' and n.entity_id = cf.id::text and n.field_name = 'name' and n.locale = 'fr'
      where cf.subclass_id = rec.subclass_id and cf.level = rec.level and n.value = rec.name
    ) then
      insert into public.class_features (class_id, subclass_id, level, choice_type, uses_per_rest)
        values (null, rec.subclass_id, rec.level, rec.choice_type, rec.uses_per_rest)
        returning id into v_id;
      insert into public.translations (entity_type, entity_id, field_name, locale, value) values
        ('class_feature', v_id::text, 'name', 'fr', rec.name),
        ('class_feature', v_id::text, 'description', 'fr', rec.description);
    end if;
  end loop;
end $$;
"""

    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        f.write(sql)
    print(f"Wrote {OUTPUT_PATH} ({len(rows)} lignes, dont expansion x4 Genie)")


if __name__ == "__main__":
    main()
