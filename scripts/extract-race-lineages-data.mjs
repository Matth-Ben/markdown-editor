// Étape 1/2 de génération de supabase/migrations/
// 20260910110000_create_race_lineages_and_racial_innate_spells.sql (lot 3, contenu D&D).
//
// Lit les fichiers source externes `race_lineages.json` / `racial_innate_spells.json`
// (scraping croisé Aidedd / 5e-bits / Open5e, non versionnés dans ce dépôt) et produit
// `lineage_rows.json` / `spell_rows.json` (dans le répertoire courant), consommés
// ensuite par generate-race-lineages-migration.mjs pour produire le SQL final.
// Encode le classement lineage_group + résolution ability_bonuses/damage_type des
// lignées, et la résolution race/subrace/lineage/spell des sorts innés raciaux
// (avec alias de noms de sorts et liste des sorts non trouvés dans public.spells au
// moment de cette migration — voir le rapport de tâche pour le détail).
//
// Usage : node extract-race-lineages-data.mjs (chemins sources en dur ci-dessous,
// adapter si les fichiers sont déplacés).

import fs from 'node:fs';

const lineages = JSON.parse(fs.readFileSync('C:\\Users\\Matth\\Downloads\\race_lineages.json', 'utf-8'))
  .filter((e) => e.id_temp); // drop the trailing _recommendation_schema object

const innateSpells = JSON.parse(fs.readFileSync('C:\\Users\\Matth\\Downloads\\racial_innate_spells.json', 'utf-8'));

function lit(s) {
  if (s === null || s === undefined) return 'null';
  return '$q$' + String(s).split('$q$').join('') + '$q$';
}

// --- Lineages ---
const GAP_SKIP = new Set(['lineage_dragonborn_fizban_chromatic_GAP', 'lineage_dragonborn_fizban_gem_GAP']);

const DRAGON_COLOR_DAMAGE = {
  Noir: 'acide', Bleu: 'foudre', Airain: 'feu', Bronze: 'foudre', Cuivre: 'acide',
  Or: 'feu', Vert: 'poison', Rouge: 'feu', Argent: 'froid', Blanc: 'froid',
};

function classifyLineage(e) {
  let lineage_group;
  let grants_ability_bonus = false;
  let ability_bonuses = null;
  let damage_type = null;
  let resistance_damage_type = null;
  let subrace_name = null; // resolved later to subrace_id via SQL lookup

  if (e.id_temp.startsWith('lineage_dragonborn_phb_')) {
    lineage_group = 'phb_ancestry';
    const color = e.lineage_name_fr.split(':')[1].trim();
    damage_type = DRAGON_COLOR_DAMAGE[color];
    resistance_damage_type = damage_type;
  } else if (e.id_temp.startsWith('lineage_dragonborn_fizban_metallic_')) {
    lineage_group = 'fizban_metallic';
    const color = e.lineage_name_fr.split(':')[1].trim();
    damage_type = DRAGON_COLOR_DAMAGE[color];
    resistance_damage_type = damage_type;
  } else if (e.id_temp.startsWith('lineage_dragonborn_2024_')) {
    lineage_group = '2024_lineage';
    const color = e.lineage_name_fr.split(':')[1].trim();
    damage_type = DRAGON_COLOR_DAMAGE[color];
    resistance_damage_type = damage_type;
  } else if (e.id_temp.startsWith('lineage_genasi_')) {
    lineage_group = 'genasi_elemental_type';
    grants_ability_bonus = true;
    subrace_name = e.lineage_name_fr; // "Génasi de l'air" etc. -- matches subrace name exactly
    const abilityMatch = e.effet_mecanique.match(/\+1 (Dex|Force|Intelligence|Sagesse)/);
    const map = { Dex: 'dex', Force: 'str', Intelligence: 'int', Sagesse: 'wis' };
    if (abilityMatch) ability_bonuses = { [map[abilityMatch[1]]]: 1 };
  } else {
    // all remaining entries are 2024 lineages (elf, gnome, goliath, tiefling) — no ability bonus in 2024 rules
    lineage_group = '2024_lineage';
  }

  return { lineage_group, grants_ability_bonus, ability_bonuses, damage_type, resistance_damage_type, subrace_name };
}

const lineageRows = lineages
  .filter((e) => !GAP_SKIP.has(e.id_temp))
  .map((e) => {
    const c = classifyLineage(e);
    return {
      id_temp: e.id_temp,
      race_name: e.race_name,
      subrace_name: c.subrace_name,
      lineage_group: c.lineage_group,
      grants_ability_bonus: c.grants_ability_bonus,
      ability_bonuses: c.ability_bonuses,
      damage_type: c.damage_type,
      resistance_damage_type: c.resistance_damage_type,
      source_book: e.source_book,
      name_fr: e.lineage_name_fr,
      mechanical_effect: e.effet_mecanique,
    };
  });

console.log('lineage rows to insert:', lineageRows.length);
fs.writeFileSync('lineage_rows.json', JSON.stringify(lineageRows, null, 2));

// --- Innate spells ---
const SPELL_ALIASES = {
  'Communication avec les animaux': 'Parole avec les animaux',
  'Bouffée de poison': 'Aspersion empoisonnée',
  'Pas brumeux': 'Foulée brumeuse',
};
const UNRESOLVED_SPELLS = new Set(['Lumières dansantes', 'Lueurs féeriques', 'Illusion mineure', 'Flammes', 'Grande foulée']);

// subrace_name -> lineage id_temp mapping for the "(lignée 2024)"/"(héritage 2024)" pseudo-subraces
const SUBRACE_TO_LINEAGE_ID_TEMP = {
  'Drow (lignée 2024)': 'lineage_elf_2024_drow',
  'Haut-elfe (lignée 2024)': 'lineage_elf_2024_high_elf',
  'Elfe des bois (lignée 2024)': 'lineage_elf_2024_wood_elf',
  'Gnome des forêts (lignée 2024)': 'lineage_gnome_2024_forest_gnome',
  'Gnome des roches (lignée 2024)': 'lineage_gnome_2024_rock_gnome',
  'Abyssal (héritage 2024)': 'lineage_tiefling_2024_abyssal',
  'Chtonien (héritage 2024)': 'lineage_tiefling_2024_chthonic',
  'Infernal (héritage 2024)': 'lineage_tiefling_2024_infernal',
};

// real subraces already in DB (classic, non-2024) referenced by exact name
const REAL_SUBRACE_NAMES = new Set([
  'Elfe noir (Drow)', // note case difference vs file's "Elfe noir (drow)"
  'Haut-elfe',
  'Gnome des forêts',
  "Génasi de l'air",
  'Génasi de la terre',
  'Génasi du feu',
  "Génasi de l'eau",
]);
const SUBRACE_NAME_ALIASES = {
  'Elfe noir (drow)': 'Elfe noir (Drow)',
};

const skippedForMissingRace = [];
const spellRows = innateSpells
  .filter((e) => {
    if (e.race_name === 'Aasimar') {
      skippedForMissingRace.push(e);
      return false;
    }
    return true;
  })
  .map((e) => {
    let subrace_name = null;
    let lineage_id_temp = null;
    if (e.subrace_name) {
      if (SUBRACE_TO_LINEAGE_ID_TEMP[e.subrace_name]) {
        lineage_id_temp = SUBRACE_TO_LINEAGE_ID_TEMP[e.subrace_name];
      } else {
        const aliased = SUBRACE_NAME_ALIASES[e.subrace_name] || e.subrace_name;
        if (!REAL_SUBRACE_NAMES.has(aliased)) throw new Error('Unmapped subrace_name: ' + e.subrace_name);
        subrace_name = aliased;
      }
    }
    const isChoice = e.spell_name_fr.startsWith('Sort mineur au choix');
    let spell_name = null;
    let unresolvedNote = null;
    if (isChoice) {
      unresolvedNote = 'Choix libre du joueur parmi les sorts mineurs de la liste de Magicien (trait "Cantrip elfique" du Haut-elfe) — pas un sort fixe, aucune ligne spells associée.';
    } else if (UNRESOLVED_SPELLS.has(e.spell_name_fr)) {
      unresolvedNote = `Sort "${e.spell_name_fr}" (${e.spell_name_en}) non trouvé dans public.spells au moment de cette migration — à ajouter au catalogue de sorts puis relier ultérieurement.`;
    } else {
      spell_name = SPELL_ALIASES[e.spell_name_fr] || e.spell_name_fr;
    }
    return {
      race_name: e.race_name,
      subrace_name,
      lineage_id_temp,
      spell_name,
      unresolved_note: unresolvedNote,
      character_level: e.character_level,
      ability_used_for_dc: e.ability_used_for_dc,
    };
  });

console.log('spell rows to insert:', spellRows.length, '(skipped for missing race Aasimar:', skippedForMissingRace.length, ')');
fs.writeFileSync('spell_rows.json', JSON.stringify(spellRows, null, 2));
console.log('unresolved spell rows:', spellRows.filter((r) => r.unresolved_note).length);
