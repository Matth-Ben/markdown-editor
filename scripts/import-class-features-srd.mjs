// Génère supabase/migrations/20260910100000_seed_class_features_srd_progression.sql
// à partir d'un fichier source externe `class_features.json` (scraping croisé
// Aidedd / 5e-bits (dnd5eapi.co, SRD 5.1) / Open5e, 537 entrées, non versionné
// dans ce dépôt — voir la tâche "peuplement contenu D&D lot 2" pour l'origine).
//
// Ne traite QUE les entrées license_status === 'srd_cc_by' (313 sur 537) :
//   - 210 aptitudes de classe cœur (subclass_name null)
//   - 103 aptitudes de sous-classe des 12 sous-classes du socle SRD (une par
//     classe : Voie du berserker, Collège du savoir, Domaine de la vie, Cercle
//     de la terre, Lignée draconique, Champion, École de l'évocation, Voie de
//     la Main Ouverte (= "Voie de la paume" dans le fichier), Protecteur
//     Fiélon (= "Le Fiélon"), Serment de dévotion, Chasseur, Voleur).
// Les 224 entrées non-SRD (license_status official_needs_verification) sont
// traitées séparément dans scripts/class_features_non_srd_draft.json (brouillon
// de reformulation à relire avant migration, PAS traité ici).
//
// Déduplication : la base contenait déjà 148 lignes (45 cœur + 103 signature,
// Phase 1/5) écrites indépendamment de ce fichier, avec des noms parfois
// traduits différemment du fichier (ex. "Attaque impétueuse" pour "Attaque
// téméraire", "Explorateur né" pour "Explorateur-né"...). Un dédoublonnage
// automatique par égalité stricte de nom aurait donc réinséré ~176 doublons.
// Les listes CORE_SKIP / SUB_SKIP ci-dessous encodent la correspondance
// vérifiée manuellement (classe/sous-classe + niveau + nom fichier) pour ne
// pas dupliquer une aptitude déjà en base sous un autre nom. Deux écarts non
// tranchés unilatéralement (signalés dans le rapport de tâche, pas "réparés"
// ici) :
//   - Ensorceleur "Métamagie" (niveau 2, en base) chevauche en fait deux
//     aptitudes distinctes du SRD : "Source de magie" (Font of Magic, niveau
//     2) et "Métamagie" (Metamagic, niveau 3) — les deux sont insérées
//     telles quelles, la ligne existante n'est pas modifiée.
//   - Paladin "Arme sacrée" (niveau 3, en base) ne couvre qu'une des deux
//     options de "Conduit divin" du Serment de dévotion — le "Conduit divin"
//     complet du SRD est inséré sans supprimer "Arme sacrée".
//
// Usage : node scripts/import-class-features-srd.mjs <chemin vers class_features.json>
// Écrit le SQL sur stdout (redirigez vers un nouveau fichier de migration
// horodaté après le dernier existant dans supabase/migrations/).

import fs from 'node:fs';

const srcPath = process.argv[2];
if (!srcPath) {
  console.error('Usage: node import-class-features-srd.mjs <class_features.json>');
  process.exit(1);
}
const data = JSON.parse(fs.readFileSync(srcPath, 'utf-8'));

const coreSrd = data.filter((e) => !e.subclass_name && e.license_status === 'srd_cc_by');
const subSrd = data.filter((e) => e.subclass_name && e.license_status === 'srd_cc_by');

const CORE_SKIP = new Set([
  'Barbare|1|Rage', 'Barbare|1|Défense sans armure', 'Barbare|2|Attaque téméraire', 'Barbare|3|Voie primitive',
  'Barde|1|Incantation', 'Barde|1|Inspiration bardique (d6)', 'Barde|3|Collège bardique',
  'Clerc|1|Incantation', 'Clerc|1|Domaine divin', 'Clerc|2|Conduit divin (1/repos)',
  'Druide|1|Druidique', 'Druide|1|Incantation', 'Druide|2|Forme sauvage', 'Druide|2|Cercle druidique',
  'Ensorceleur|1|Incantation', 'Ensorceleur|1|Origine magique',
  'Guerrier|1|Style de combat', 'Guerrier|1|Second souffle', 'Guerrier|2|Fougue (1)', 'Guerrier|3|Archétype martial',
  'Magicien|1|Incantation', 'Magicien|1|Restauration arcanique', 'Magicien|2|Tradition arcanique',
  'Moine|1|Défense sans armure', 'Moine|1|Arts martiaux', 'Moine|2|Ki', 'Moine|3|Tradition monastique',
  "Occultiste|1|Patron d'Outremonde", 'Occultiste|1|Magie de pacte', 'Occultiste|2|Manifestations occultes',
  'Paladin|1|Sens divin', 'Paladin|1|Imposition des mains', 'Paladin|2|Style de combat', 'Paladin|2|Incantation', 'Paladin|3|Serment sacré',
  'Rôdeur|1|Ennemi juré', 'Rôdeur|1|Explorateur-né', 'Rôdeur|2|Style de combat', 'Rôdeur|2|Incantation', 'Rôdeur|3|Archétype de rôdeur',
  'Roublard|1|Expertise', 'Roublard|1|Attaque sournoise', 'Roublard|1|Jargon des voleurs', 'Roublard|3|Archétype de roublard',
]);

const SUB_SKIP = new Set([
  'Voie du berserker|3|Frénésie',
  'Collège du savoir|3|Mots cinglants',
  'Domaine de la vie|1|Disciple de la vie',
  'Lignée draconique|1|Résistance draconique',
  'Champion|3|Critique amélioré',
  "École d'évocation|2|Façonneur de sorts",
  'Voie de la paume|3|Technique de la paume',
  'Le Fiélon|1|Bénédiction du ténébreux',
  'Chasseur|3|Proie du chasseur',
  'Voleur|3|Mains lestes',
]);

// subclass_id fixes, vérifiés par requête sur le projet nexus-jdr (voir rapport
// de tâche) : les 12 sous-classes "iconiques" du socle Phase 1 portent les id
// 1 à 12 (une par classe, dans l'ordre de classes.id), SAUF Paladin dont
// l'iconique du socle est "Serment des Anciens" (id 7, hors SRD) tandis que la
// sous-classe SRD réelle "Serment de dévotion" a été ajoutée en Phase 5 (id 83).
const SUBCLASS_ID_MAP = {
  'Voie du berserker': 1,
  'Collège du savoir': 2,
  'Domaine de la vie': 3,
  'Cercle de la terre': 4,
  'Lignée draconique': 12,
  Champion: 5,
  "École d'évocation": 11,
  'Voie de la paume': 6,
  'Le Fiélon': 10,
  'Serment de dévotion': 83,
  Chasseur: 8,
  Voleur: 9,
};

function lit(s) {
  if (s === null || s === undefined) return 'null';
  return '$q$' + String(s).split('$q$').join('') + '$q$';
}

const coreToInsert = coreSrd.filter((f) => !CORE_SKIP.has(`${f.class_name}|${f.level}|${f.name_fr}`));
const subToInsert = subSrd.filter((f) => !SUB_SKIP.has(`${f.subclass_name}|${f.level}|${f.name_fr}`));

const lines = [];
lines.push('do $$');
lines.push('declare');
lines.push('  rec record;');
lines.push('  v_id int;');
lines.push('  v_class_id int;');
lines.push('begin');
lines.push('  for rec in');
lines.push('    select * from (values');
lines.push(
  coreToInsert
    .map((f, i) => {
      const uses = f.uses_per_rest ? lit(JSON.stringify(f.uses_per_rest)) + '::jsonb' : 'null::jsonb';
      const choice = f.choice_type ? lit(f.choice_type) : 'null';
      return `      (${lit(f.class_name)}, ${f.level}, ${lit(f.name_fr)}, ${lit(f.description || '')}, ${choice}, ${uses})${i < coreToInsert.length - 1 ? ',' : ''}`;
    })
    .join('\n'),
);
lines.push('    ) as t(class_name, level, name, description, choice_type, uses_per_rest)');
lines.push('  loop');
lines.push('    select c.id into v_class_id from public.translations ct join public.classes c on c.id::text = ct.entity_id');
lines.push("    where ct.entity_type = 'class' and ct.field_name = 'name' and ct.locale = 'fr' and ct.value = rec.class_name;");
lines.push('    if v_class_id is null then');
lines.push("      raise exception 'Classe introuvable: %', rec.class_name;");
lines.push('    end if;');
lines.push('    if not exists (select 1 from public.class_features cf');
lines.push("      join public.translations n on n.entity_type = 'class_feature' and n.entity_id = cf.id::text and n.field_name = 'name' and n.locale = 'fr'");
lines.push('      where cf.class_id = v_class_id and cf.subclass_id is null and cf.level = rec.level and n.value = rec.name) then');
lines.push('      insert into public.class_features (class_id, subclass_id, level, choice_type, uses_per_rest)');
lines.push('        values (v_class_id, null, rec.level, rec.choice_type, rec.uses_per_rest) returning id into v_id;');
lines.push("      insert into public.translations (entity_type, entity_id, field_name, locale, value) values");
lines.push("        ('class_feature', v_id::text, 'name', 'fr', rec.name), ('class_feature', v_id::text, 'description', 'fr', rec.description);");
lines.push('    end if;');
lines.push('  end loop;');
lines.push('  for rec in');
lines.push('    select * from (values');
lines.push(
  subToInsert
    .map((f, i) => {
      const uses = f.uses_per_rest ? lit(JSON.stringify(f.uses_per_rest)) + '::jsonb' : 'null::jsonb';
      const choice = f.choice_type ? lit(f.choice_type) : 'null';
      const scid = SUBCLASS_ID_MAP[f.subclass_name];
      if (!scid) throw new Error('no subclass_id mapping for ' + f.subclass_name);
      return `      (${scid}, ${f.level}, ${lit(f.name_fr)}, ${lit(f.description || '')}, ${choice}, ${uses})${i < subToInsert.length - 1 ? ',' : ''}`;
    })
    .join('\n'),
);
lines.push('    ) as t(subclass_id, level, name, description, choice_type, uses_per_rest)');
lines.push('  loop');
lines.push('    if not exists (select 1 from public.class_features cf');
lines.push("      join public.translations n on n.entity_type = 'class_feature' and n.entity_id = cf.id::text and n.field_name = 'name' and n.locale = 'fr'");
lines.push('      where cf.subclass_id = rec.subclass_id and cf.level = rec.level and n.value = rec.name) then');
lines.push('      insert into public.class_features (class_id, subclass_id, level, choice_type, uses_per_rest)');
lines.push('        values (null, rec.subclass_id, rec.level, rec.choice_type, rec.uses_per_rest) returning id into v_id;');
lines.push("      insert into public.translations (entity_type, entity_id, field_name, locale, value) values");
lines.push("        ('class_feature', v_id::text, 'name', 'fr', rec.name), ('class_feature', v_id::text, 'description', 'fr', rec.description);");
lines.push('    end if;');
lines.push('  end loop;');
lines.push('end $$;');

console.log(lines.join('\n'));
console.error(`core: ${coreToInsert.length} lignes à insérer / sous-classe: ${subToInsert.length} lignes à insérer`);
