#!/usr/bin/env node
// Chantier "Personnages" (app mobile) — Phase 5, lot 1 — Extension du contenu D&D.
//
// Génère une migration SQL (à copier/committer dans supabase/migrations/) qui
// étoffe la table public.spells très au-delà du socle Phase 1 (~57 sorts,
// cantrips + niveau 1 seulement — voir 20260825090900_seed_spells_core.sql),
// en fusionnant 3 sources externes :
//   1. Table HTML aidedd (miroir GitHub) : nom FR + nom VO + résumé
//      mécanique FR + méta (niveau, école, temps, concentration, rituel,
//      source) — ~477 sorts.
//   2. JSON mécanique complet en anglais (dnd5e-card-generator) : temps,
//      portée, durée, composantes structurés + description anglaise
//      complète. Le champ meta.translations.fr de cette source est
//      documenté comme corrompu (mojibake) — NE JAMAIS l'utiliser, même si
//      un contrôle ponctuel ne montre rien d'anormal (voir rapport de fin
//      de tâche du lot qui a introduit ce script).
//   3. JSON sort → classes pouvant l'apprendre, par livre source (5etools).
//
// La clé de rapprochement entre (1) et (2)/(3) est le nom ANGLAIS (colonne
// VO de la table aidedd), normalisé (spellNorm) — jamais une correspondance
// approximative sur le nom français.
//
// Ce script ne pousse rien vers aucune base : il écrit uniquement un
// fichier .sql. Il interroge en lecture seule la base Supabase LOCALE (via
// `psql`, déjà présent sur ce poste, pas de dépendance npm supplémentaire)
// pour lister les sorts déjà peuplés et éviter d'émettre des INSERT
// redondants dans le fichier généré — mais la migration produite reste
// elle-même idempotente indépendamment de cette pré-liste (garde
// `if not exists` par sort, voir plus bas), donc ce script reste correct
// même exécuté hors ligne ou contre une base non initialisée.
//
// Usage :
//   node scripts/import-spells.mjs [--out <chemin.sql>] [--db <postgres-url>]
//
// Par défaut, écrit dans supabase/migrations/<timestamp>_seed_spells_extended.sql
// et interroge postgresql://postgres:postgres@127.0.0.1:54322/postgres (stack
// Supabase locale par défaut de `supabase start`).
//
// Gardé dans le dépôt (voir consigne de la tâche) : la Phase 5 est un
// chantier de contenu continu, un futur lot (autres suppléments, objets,
// dons...) pourra réutiliser tout ou partie de ce pipeline fetch+fusion.

import { execFileSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, isAbsolute, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(__dirname, '..');

// Les 3 sources sont epinglees a un commit precis (pas 'main'/HEAD) : une
// reexecution future de ce script doit fusionner exactement les memes
// donnees que celles verifiees lors de la generation de la migration qui
// accompagne ce script, jamais un etat plus recent et non revu.
const SOURCES = {
  aideddHtml:
    'https://raw.githubusercontent.com/dinde451/Tapouweb/0366bc3d1984b0033f84a270e9cc84694ab718e8/src/dnd-filters/sorts.html',
  mechanicsJson:
    'https://raw.githubusercontent.com/brouberol/dnd5e-card-generator/6dc325d7e6e4a04adc1f99f801d37751adc1cc0d/data/spells.json',
  classesJson:
    'https://raw.githubusercontent.com/5etools-mirror-3/5etools-2014-src/50fe7eb80dadfb9d7bafec5d12471570872fa567/data/spells/sources.json',
};

const DEFAULT_DB_URL = 'postgresql://postgres:postgres@127.0.0.1:54322/postgres';

// ---------------------------------------------------------------------------
// Petites tables de traduction (reprises telles quelles de la logique de
// fusion déjà éprouvée — voir consigne de la tâche).
// ---------------------------------------------------------------------------

const SPELL_SCHOOL_FR = {
  abjuration: 'Abjuration',
  conjuration: 'Invocation',
  divination: 'Divination',
  enchantment: 'Enchantement',
  evocation: 'Évocation',
  illusion: 'Illusion',
  necromancy: 'Nécromancie',
  transmutation: 'Transmutation',
};

const CLASS_EN_TO_FR = {
  Bard: 'Barde',
  Cleric: 'Clerc',
  Druid: 'Druide',
  Sorcerer: 'Ensorceleur',
  Wizard: 'Magicien',
  Warlock: 'Occultiste',
  Paladin: 'Paladin',
  Ranger: 'Rôdeur',
  Artificer: 'Artificier', // filtré plus bas si la classe n'existe pas en base
};

// Titres FR courts, communément utilisés par la communauté française pour
// ces suppléments (aucune norme éditoriale unique retrouvée avec certitude
// pour XGE/TCE — voir rapport de fin de tâche). PHB reprend le libellé déjà
// utilisé par le socle Phase 1 ('Manuel des Joueurs').
const SOURCE_BOOK_LABEL_FR = {
  PHB: 'Manuel des Joueurs',
  XGE: 'Guide de Xanathar',
  TCE: 'Chaudron de Tasha',
};

const CASTING_TIME_UNIT_FR = {
  action: 'action',
  bonus: 'action bonus',
  reaction: 'réaction',
  round: 'round',
  minute: 'minute',
  hour: 'heure',
  day: 'jour',
};

const DURATION_UNIT_FR = {
  round: 'round',
  minute: 'minute',
  hour: 'heure',
  day: 'jour',
  week: 'semaine',
  year: 'an',
};

const AREA_SHAPE_LABEL_FR = {
  radius: 'rayon',
  sphere: 'sphère',
  cone: 'cône',
  line: 'ligne',
  cube: 'cube',
  hemisphere: 'hémisphère',
  cylinder: 'cylindre',
};

// ---------------------------------------------------------------------------
// Utilitaires texte
// ---------------------------------------------------------------------------

function spellNorm(value) {
  return String(value || '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[’']/g, "'")
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

// Decodeur d'entites HTML generique (pas de dependance npm additionnelle).
// Plutot qu'une liste blanche etoffee au cas par cas (fragile : ne couvre
// que les entites deja rencontrees), on gere :
//  - les references numeriques decimales (&#60;) et hexadecimales (&#x3C;),
//    qui couvrent en theorie N'IMPORTE QUEL caractere Unicode ;
//  - une table des entites nommees du coeur HTML4/Latin-1 + quelques
//    symboles typographiques usuels (suffisante pour du contenu D&D en
//    francais et en anglais, sans pretendre a l'exhaustivite HTML5 des
//    ~2000 entites nommees, non necessaire ici).
const NAMED_HTML_ENTITIES = {
  amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ',
  eacute: 'é', egrave: 'è', ecirc: 'ê', euml: 'ë',
  agrave: 'à', acirc: 'â', auml: 'ä',
  icirc: 'î', iuml: 'ï',
  ocirc: 'ô', ouml: 'ö',
  ucirc: 'û', ugrave: 'ù', uuml: 'ü',
  ccedil: 'ç', ntilde: 'ñ',
  Eacute: 'É', Egrave: 'È', Agrave: 'À', Ccedil: 'Ç',
  oelig: 'œ', OElig: 'Œ', aelig: 'æ', AElig: 'Æ',
  rsquo: '’', lsquo: '‘', rdquo: '”', ldquo: '“',
  hellip: '…', mdash: '—', ndash: '–',
  times: '×', divide: '÷', deg: '°', middot: '·',
  laquo: '«', raquo: '»', copy: '©', reg: '®', trade: '™',
};

function decodeHtmlEntities(text) {
  return String(text || '').replace(/&(#x?[0-9a-fA-F]+|[a-zA-Z]+);/g, (match, entity) => {
    if (entity[0] === '#') {
      const codePoint =
        entity[1] === 'x' || entity[1] === 'X' ? parseInt(entity.slice(2), 16) : parseInt(entity.slice(1), 10);
      return Number.isFinite(codePoint) ? String.fromCodePoint(codePoint) : match;
    }
    return Object.prototype.hasOwnProperty.call(NAMED_HTML_ENTITIES, entity) ? NAMED_HTML_ENTITIES[entity] : match;
  });
}

function stripFiveEToolsTags(text) {
  if (!text) return '';
  let result = String(text);
  let previous;
  const tagRe = /\{@(\w+)\s+([^{}]*)\}/g;
  do {
    previous = result;
    result = result.replace(tagRe, (_match, _tag, body) => body.split('|')[0].trim());
  } while (result !== previous);
  return result;
}

function collapseWhitespace(text) {
  return String(text || '')
    .replace(/\s+/g, ' ')
    .trim();
}

function normalizeParagraphs(text) {
  return String(text || '')
    .replace(/\r\n/g, '\n')
    .split('\n')
    .map((line) => collapseWhitespace(line))
    .filter((line, index, arr) => !(line === '' && arr[index - 1] === ''))
    .join('\n')
    .trim();
}

function capitalizeFirst(text) {
  if (!text) return text;
  return text.charAt(0).toUpperCase() + text.slice(1);
}

// Format officiel des livres FR (BBE) : 1 pied = 0,3 mètre exactement (pas
// la conversion physique 0,3048) — vérifié en reproduisant les valeurs déjà
// présentes dans 20260825090900_seed_spells_core.sql (60 ft -> '18 mètres',
// 30 ft -> '9 mètres', 15 ft -> '4,50 mètres', 5 ft -> '1,50 mètre'...).
function feetToMetersLabel(feet) {
  const meters = Math.round(feet * 0.3 * 2) / 2;
  const isInt = Number.isInteger(meters);
  const numStr = isInt ? String(meters) : meters.toFixed(2).replace('.', ',');
  // Règle grammaticale FR : pluriel à partir de 2 (inclus), singulier
  // en-dessous (couvre le cas '1,50 mètre', déjà présent dans le socle).
  const unit = meters >= 2 ? 'mètres' : 'mètre';
  return `${numStr} ${unit}`;
}

function milesToKmLabel(miles) {
  const km = Math.round(miles * 1.6 * 10) / 10;
  const isInt = Number.isInteger(km);
  const numStr = isInt ? String(km) : String(km).replace('.', ',');
  const unit = km >= 2 ? 'kilomètres' : 'kilomètre';
  return `${numStr} ${unit}`;
}

// ---------------------------------------------------------------------------
// Formatage des champs mécaniques structurés (source 2) vers le format FR
// déjà utilisé par le socle Phase 1.
// ---------------------------------------------------------------------------

function formatCastingTime(rawTime, aideddFallback) {
  const item = Array.isArray(rawTime) ? rawTime[0] : null;
  if (!item) return aideddFallback || null;
  const n = item.number || 1;
  const unit = CASTING_TIME_UNIT_FR[item.unit] || item.unit || 'action';
  const plural = n > 1 && !unit.endsWith('s') ? `${unit}s` : unit;
  return `${n} ${plural}`;
}

function formatDistance(distance) {
  if (!distance) return null;
  switch (distance.type) {
    case 'self':
      return 'personnelle';
    case 'touch':
      return 'contact';
    case 'sight':
      return 'vue';
    case 'unlimited':
      return 'illimitée';
    case 'feet':
      return feetToMetersLabel(distance.amount || 0);
    case 'miles':
      return milesToKmLabel(distance.amount || 0);
    default:
      return distance.amount ? `${distance.amount} ${distance.type}` : distance.type || null;
  }
}

function formatRange(rawRange) {
  if (!rawRange) return null;
  if (rawRange.type === 'special') return 'Spéciale';
  const distance = formatDistance(rawRange.distance);
  if (!distance) return null;
  if (rawRange.type === 'point') return capitalizeFirst(distance);
  const shapeLabel = AREA_SHAPE_LABEL_FR[rawRange.type];
  if (shapeLabel) {
    // Les portees a forme (rayon/cone/ligne/cube/sphere/cylindre) sont, dans
    // ce jeu de donnees, toujours centrees sur le lanceur ("Range: Self" en
    // VO) : la valeur numerique represente la taille de la zone, pas une
    // distance jusqu'a un point cible. Convention deja utilisee par le socle
    // Phase 1 (ex. Vague tonnerre : "Personnelle (cube de 4,50 metres)").
    return 'Personnelle (' + shapeLabel + ' de ' + distance + ')';
  }
  return capitalizeFirst(distance);
}

function formatDurationCore(rawDuration) {
  const item = Array.isArray(rawDuration) ? rawDuration[0] : null;
  if (!item) return null;
  if (item.type === 'instant') return 'Instantanée';
  if (item.type === 'special') return 'Spéciale';
  if (item.type === 'permanent') return "Jusqu'à dissipation";
  if (item.type === 'timed') {
    const n = item.amount || 1;
    const unit = DURATION_UNIT_FR[item.unit] || item.unit || 'round';
    const plural = n > 1 && !unit.endsWith('s') ? `${unit}s` : unit;
    return `${n} ${plural}`;
  }
  return null;
}

function formatDuration(rawDuration, concentration) {
  const core = formatDurationCore(rawDuration);
  if (!core) return null;
  if (concentration) {
    const lowered = core.charAt(0).toLowerCase() + core.slice(1);
    return `Concentration, jusqu'à ${lowered}`;
  }
  return core;
}

function formatComponents(rawCasting) {
  return {
    verbal: Boolean(rawCasting && rawCasting.verbal),
    somatic: Boolean(rawCasting && rawCasting.somatic),
    material: Boolean(rawCasting && rawCasting.material),
  };
}

function resolveSchool(rawSchool, aideddEcole) {
  if (rawSchool && SPELL_SCHOOL_FR[rawSchool]) return SPELL_SCHOOL_FR[rawSchool];
  if (aideddEcole) return capitalizeFirst(aideddEcole);
  return null;
}

// ---------------------------------------------------------------------------
// Source 1 : table aidedd (HTML)
// ---------------------------------------------------------------------------

function extractCell(rowHtml, cssClass) {
  const re = new RegExp(`<td class="${cssClass}"[^>]*>([\\s\\S]*?)<\\/td>`);
  const match = rowHtml.match(re);
  if (!match) return '';
  return collapseWhitespace(decodeHtmlEntities(match[1].replace(/<[^>]+>/g, '')));
}

function parseAideddSpellTable(html) {
  const bodyStart = html.indexOf('<tbody>');
  if (bodyStart === -1) throw new Error('Table aidedd introuvable (pas de <tbody>)');
  const tbody = html.slice(bodyStart);
  const rowsHtml = [...tbody.matchAll(/<tr>[\s\S]*?<\/tr>/g)].map((m) => m[0]);
  const rows = rowsHtml
    .map((rowHtml) => {
      const nom = extractCell(rowHtml, 'item');
      const nomVO = extractCell(rowHtml, 'colVO');
      const niveauRaw = extractCell(rowHtml, 'center');
      const niveau = parseInt(niveauRaw, 10);
      return {
        nom,
        nomVO,
        niveau,
        ecole: extractCell(rowHtml, 'colE'),
        temps: extractCell(rowHtml, 'colI'),
        concentration: extractCell(rowHtml, 'colC').length > 0,
        rituel: extractCell(rowHtml, 'colR').length > 0,
        resumeMecanique: extractCell(rowHtml, 'colD'),
        source: extractCell(rowHtml, 'colS'),
      };
    })
    .filter((row) => row.nom && row.nomVO && Number.isFinite(row.niveau));
  return rows;
}

function spellBookKey(sourceRaw) {
  const normalized = spellNorm(sourceRaw);
  if (normalized.includes('xanathar')) return 'XGE';
  if (normalized.includes('tasha')) return 'TCE';
  return 'PHB';
}

// ---------------------------------------------------------------------------
// Source 3 : classes pouvant apprendre le sort, par livre
// ---------------------------------------------------------------------------

function buildClassIndex(sourceLookup) {
  const direct = new Map();
  const fallback = new Map();
  for (const [book, group] of Object.entries(sourceLookup || {})) {
    for (const [englishName, meta] of Object.entries(group || {})) {
      const key = spellNorm(englishName);
      // La source 3 stocke la liste de classes tantot sous meta.class,
      // tantot sous meta.classVariant (meme forme {name, source,
      // definedInSource}) -- constate en pratique : 95/95 sorts du Guide de
      // Xanathar et 14/21 sorts du Chaudron de Tasha n'ont AUCUNE entree
      // sous meta.class, uniquement sous meta.classVariant. Certains sorts
      // du Manuel des Joueurs ont les deux (classes de base + classes
      // etendues via les regles optionnelles de Tasha). On fusionne donc
      // les deux tableaux plutot que de ne lire que meta.class, sous peine
      // de sorts sans aucune classe associee (spell_classes vide) alors
      // qu'ils sont bien apprenables par au moins une classe du jeu.
      const rawClassEntries = [...(meta.class || []), ...(meta.classVariant || [])];
      const classes = [...new Set(rawClassEntries.map((item) => CLASS_EN_TO_FR[item.name]).filter(Boolean))];
      if (classes.length) {
        direct.set(`${book}:${key}`, classes);
        if (!fallback.has(key)) fallback.set(key, classes);
      }
    }
  }
  return { direct, fallback };
}

// ---------------------------------------------------------------------------
// Fusion
// ---------------------------------------------------------------------------

function mergeSpells(aideddRows, mechanicsByEnglishName, classIndex, availableClassNamesFr) {
  const merged = [];
  const mismatches = [];

  for (const row of aideddRows) {
    const key = spellNorm(row.nomVO);
    const raw = mechanicsByEnglishName.get(key);
    if (!raw) {
      mismatches.push({ nom: row.nom, nomVO: row.nomVO, niveau: row.niveau, source: row.source });
      continue;
    }

    const book = spellBookKey(row.source);
    const classesFr = (classIndex.direct.get(`${book}:${key}`) || classIndex.fallback.get(key) || []).filter(
      (className) => availableClassNamesFr.has(className),
    );

    const level = Number.isFinite(row.niveau) ? row.niveau : raw.level;
    const concentration = Boolean((raw.casting && raw.casting.concentration) || row.concentration);
    const ritual = Boolean((raw.casting && raw.casting.ritual) || row.rituel);
    const bookLabel = SOURCE_BOOK_LABEL_FR[book] || row.source;

    const descriptionFr = collapseWhitespace(row.resumeMecanique);
    const descriptionEn = normalizeParagraphs(stripFiveEToolsTags(raw.meta && raw.meta.description));

    merged.push({
      nameFr: row.nom,
      nameEn: row.nomVO,
      level,
      school: resolveSchool(raw.school, row.ecole),
      castingTime: formatCastingTime(raw.time, row.temps),
      range: formatRange(raw.range),
      components: formatComponents(raw.casting),
      duration: formatDuration(raw.duration, concentration),
      concentration,
      ritual,
      descriptionFr,
      descriptionEn,
      source: bookLabel,
      classesFr,
    });
  }

  return { merged, mismatches };
}

// ---------------------------------------------------------------------------
// Lecture (facultative) des sorts déjà peuplés en base locale, pour ne pas
// émettre d'INSERT redondants dans le fichier généré. Best-effort : si la
// base n'est pas joignable, on part d'un ensemble vide (la migration reste
// idempotente grâce à la garde SQL par sort, voir generateSql()).
// ---------------------------------------------------------------------------

// Le socle Phase 1 (20260825090900_seed_spells_core.sql) est une traduction
// FR maison de premier jet, explicitement documentée comme telle (pas une
// reprise garantie de la terminologie officielle). Conséquence concrète
// vérifiée en générant ce lot : sur les 57 sorts du socle, 24 portent un nom
// FR différent de celui utilisé par la table aidedd pour le MÊME sort
// anglais (ex. socle "Acide fusant" vs aidedd "Aspersion d'acide" pour
// "Acid Splash" ; socle "Aide" vs aidedd "Assistance" pour "Guidance" — à ne
// pas confondre avec le sort "Aid", niveau 2, qu'aidedd traduit lui aussi
// par "Aide", collision de traduction distincte). Une garde anti-doublon
// fondée uniquement sur (nom FR, niveau) laisserait passer ces 24 comme
// "nouveaux" et créerait de vrais doublons de contenu (même sort D&D, deux
// lignes public.spells). La table ci-dessous fait donc autorité pour
// résoudre le nom anglais réel de ces 24 exceptions ; pour les 33 autres
// sorts du socle, le nom anglais est retrouvé automatiquement via la table
// aidedd elle-même (le nom FR y coïncide déjà avec le socle). Voir le
// rapport de fin de tâche du lot qui a introduit ce script pour le détail
// de la vérification (lecture des descriptions du socle contre la
// description mécanique anglaise correspondante).
const EXISTING_TRANSLATION_OVERRIDES_EN = {
  'Acide fusant|0': 'Acid Splash',
  'Aide|0': 'Guidance',
  'Aspersion empoisonnée|0': 'Poison Spray',
  'Avertissement occulte|0': 'True Strike',
  "Baguette d'illusion|0": 'Minor Illusion',
  'Création de flamme|0': 'Produce Flame',
  'Défense féerique|0': 'Blade Ward',
  'Épargner les mourants|0': 'Spare the Dying',
  "Fouet d'épines|0": 'Thorn Whip',
  'Lame acérée|0': 'Shocking Grasp',
  'Lueurs dansantes|0': 'Dancing Lights',
  'Main du mage|0': 'Mage Hand',
  'Mot moqueur|0': 'Vicious Mockery',
  'Trique noueuse|0': 'Shillelagh',
  'Feu follet|1': 'Faerie Fire',
  'Flétrissure|1': 'Bane',
  'Chute plume|1': 'Feather Fall',
  'Parole avec les animaux|1': 'Speak with Animals',
  'Rire hideux de Tasha|1': "Tasha's Hideous Laughter",
  'Vague tonnerre|1': 'Thunderwave',
  'Vaillance|1': 'Heroism',
  'Vitesse supérieure|1': 'Longstrider',
  'Écriture illusoire|1': 'Illusory Script',
  'Bond|1': 'Jump',
};

function loadExistingSpells(dbUrl) {
  try {
    const query =
      "select t.value, s.level from public.translations t " +
      'join public.spells s on s.id::text = t.entity_id ' +
      "where t.entity_type = 'spell' and t.field_name = 'name' and t.locale = 'fr';";
    const output = execFileSync('psql', [dbUrl, '-t', '-A', '-F', '|', '-c', query], {
      encoding: 'utf8',
    });
    const spells = [];
    for (const line of output.split('\n')) {
      const trimmed = line.trim();
      if (!trimmed) continue;
      const [name, levelRaw] = trimmed.split('|');
      spells.push({ name, level: Number(levelRaw) });
    }
    return spells;
  } catch (error) {
    console.warn(
      `[import-spells] Impossible d'interroger la base locale (${error.message}). ` +
        'Poursuite avec une liste de doublons vide côté script — la migration reste ' +
        'idempotente grâce à sa garde SQL par sort.',
    );
    return [];
  }
}

// Resout, pour chaque sort deja en base, son nom anglais (VO) reel - via la
// table de correction ci-dessus pour les 24 exceptions connues, sinon via
// une recherche dans les lignes aidedd elles-memes (nom FR + niveau
// identiques). Retourne :
//  - `voLevelKeys` : Set de cles `norm(vo)|level` pour detecter qu'un sort
//    de ce lot est en realite deja present en base (meme sort D&D,
//    independamment d'une eventuelle divergence de traduction FR) ;
//  - `existingByVoLevel` : Map de cette meme cle vers { name, level } de
//    l'entree EXISTANTE en base, pour cibler correctement le backfill EN
//    (la jointure SQL doit utiliser le nom deja en base, pas celui d'aidedd).
function resolveExistingSpellIdentities(existingSpells, aideddRows) {
  const voByFrNameLevel = new Map();
  for (const row of aideddRows) {
    const mapKey = row.nom + '|' + row.niveau;
    voByFrNameLevel.set(mapKey, row.nomVO);
  }

  const voLevelKeys = new Set();
  const existingByVoLevel = new Map();
  const unresolved = [];

  for (const spell of existingSpells) {
    const overrideKey = spell.name + '|' + spell.level;
    const vo = EXISTING_TRANSLATION_OVERRIDES_EN[overrideKey] || voByFrNameLevel.get(overrideKey);
    if (!vo) {
      unresolved.push(spell);
      continue;
    }
    const key = spellNorm(vo) + '|' + spell.level;
    voLevelKeys.add(key);
    existingByVoLevel.set(key, spell);
  }

  if (unresolved.length) {
    console.warn(
      '[import-spells] ' + unresolved.length + ' sort(s) deja en base sans nom anglais resolu ' +
        "(ni override connu, ni correspondance aidedd par nom+niveau) - ces sorts ne " +
        'participeront pas a la detection de doublons de ce lot :',
    );
    for (const s of unresolved) console.warn('  - "' + s.name + '" (niveau ' + s.level + ')');
  }

  return { voLevelKeys, existingByVoLevel };
}

function loadExistingClassNamesFr(dbUrl) {
  try {
    const query =
      "select value from public.translations where entity_type = 'class' and field_name = 'name' and locale = 'fr';";
    const output = execFileSync('psql', [dbUrl, '-t', '-A', '-c', query], { encoding: 'utf8' });
    return new Set(output.split('\n').map((l) => l.trim()).filter(Boolean));
  } catch (error) {
    console.warn(
      `[import-spells] Impossible de lister les classes en base locale (${error.message}). ` +
        "Repli sur les 12 classes connues du socle Phase 1 (pas d'Artificier).",
    );
    return new Set([
      'Barbare',
      'Barde',
      'Clerc',
      'Druide',
      'Ensorceleur',
      'Guerrier',
      'Magicien',
      'Moine',
      'Occultiste',
      'Paladin',
      'Rôdeur',
      'Roublard',
    ]);
  }
}

// ---------------------------------------------------------------------------
// Génération SQL
// ---------------------------------------------------------------------------

function sqlQuote(text) {
  return `$sp$${String(text ?? '')}$sp$`;
}

function sqlQuoteNullable(text) {
  if (text === null || text === undefined || text === '') return 'null';
  return sqlQuote(text);
}

function generateSql({ toInsert, enBackfill }) {
  const lines = [];
  lines.push('-- Chantier "Personnages" (app mobile) — Phase 5, lot 1 — Extension du contenu D&D.');
  lines.push('-- Étoffe public.spells très au-delà du socle Phase 1 (20260825090900_seed_spells_core.sql,');
  lines.push('-- ~57 sorts, cantrips + niveau 1 seulement) avec les sorts de niveau 0 à 9 du Manuel des');
  lines.push('-- Joueurs et de deux suppléments (Guide de Xanathar, Chaudron de Tasha), fusionnés à partir');
  lines.push('-- de 3 sources externes (table aidedd FR/VO, mécaniques JSON EN, classes JSON EN) — voir');
  lines.push('-- scripts/import-spells.mjs pour le détail du pipeline et le rapport de génération.');
  lines.push('--');
  lines.push('-- Idempotence : contrairement à 20260825090900 (qui se contente de vérifier que la table');
  lines.push("-- est vide), cette migration s'exécute sur une table déjà peuplée. Chaque sort est donc");
  lines.push('-- inséré sous une garde `if not exists (...)`.');
  lines.push('--');
  lines.push("-- Anti-doublon en deux temps :");
  lines.push("--  1. A la generation (scripts/import-spells.mjs), un sort de la table aidedd est");
  lines.push("--     considere deja present si son nom ANGLAIS (VO) + niveau correspond a un sort deja");
  lines.push("--     en base -- table de correction pour 24 sorts du socle Phase 1 dont la traduction");
  lines.push("--     FR maison differe du nom retenu par aidedd (ex. socle « Acide fusant » vs aidedd");
  lines.push("--     « Aspersion d'acide » pour « Acid Splash ») -- une comparaison sur le seul nom FR");
  lines.push("--     aurait manque ces 24 correspondances et duplique le contenu.");
  lines.push("--  2. Au niveau SQL ci-dessous (garde `if not exists`), la comparaison se fait sur");
  lines.push("--     (nom FR, niveau) tel que deja present en base au moment ou la migration s'execute --");
  lines.push("--     l'anglais n'est stocke nulle part dans le schema. Cette garde est un filet de");
  lines.push("--     securite pour les re-executions (ex. re-application de cette migration), pas le");
  lines.push("--     mecanisme principal de deduplication (deja effectue en amont, voir point 1).");
  lines.push("--     Sans elle, un sort deja insere par CE lot serait revu comme nouveau si la migration");
  lines.push("--     etait rejouee sur une base ou elle a deja tourne.");
  lines.push("--");
  lines.push("-- Cas particulier « Aide » : aidedd traduit « Aid » (niveau 2) par « Aide », alors que le socle");
  lines.push("-- Phase 1 avait deja traduit « Guidance » (cantrip) par « Aide » -- collision de traduction");
  lines.push("-- entre deux sorts differents, distingues ici par leur niveau. Nettoyage de cette collision");
  lines.push("-- (renommer l'« Aide » existante en quelque chose comme « Assistance ») laisse hors perimetre :");
  lines.push("-- cette migration ne touche a aucun des sorts du socle Phase 1 (voir rapport de fin de");
  lines.push("-- tache du lot qui a introduit ce script).");
  lines.push("--");
  lines.push('-- name/description vivent dans public.translations (migration 20260825090050), locale');
  lines.push("-- 'fr' pour le résumé mécanique de la table aidedd, locale 'en' pour la description");
  lines.push('-- mécanique complète du JSON source (nettoyée des tags 5etools type {@damage ...}) —');
  lines.push("-- première vraie donnée locale 'en' de la base, anticipée par le commentaire de");
  lines.push('-- 20260825090050.');
  lines.push('');
  // Rien a inserer (ex. lot ou tous les sorts sont deja en base) : ne pas
  // generer de bloc do $$ ... end $$ avec un VALUES vide (SQL invalide).
  if (toInsert.length) {
    lines.push('do $$');
    lines.push('declare');
    lines.push('  rec record;');
    lines.push('  v_id int;');
    lines.push('begin');
    lines.push('  for rec in');
    lines.push('    select * from (values');

    const rowsSql = toInsert.map((spell, index) => {
      const componentsJson = JSON.stringify(spell.components);
      const comma = index === toInsert.length - 1 ? '' : ',';
      return (
        `    (${sqlQuote(spell.nameFr)}, ${spell.level}, ${sqlQuoteNullable(spell.school)}, ` +
        `${sqlQuoteNullable(spell.castingTime)}, ${sqlQuoteNullable(spell.range)}, ` +
        `'${componentsJson}'::jsonb, ${sqlQuoteNullable(spell.duration)}, ${spell.concentration}, ` +
        `${spell.ritual}, ${sqlQuote(spell.descriptionFr)}, ${sqlQuoteNullable(spell.descriptionEn)}, ` +
        `${sqlQuote(spell.source)})${comma}`
      );
    });
    lines.push(...rowsSql);

    lines.push(
      '    ) as t(name, level, school, casting_time, range, components, duration, concentration, ritual, description, description_en, source)',
    );
    lines.push('  loop');
    lines.push('    if not exists (');
    lines.push('      select 1');
    lines.push('      from public.spells sp');
    lines.push('      join public.translations tr');
    lines.push("        on tr.entity_type = 'spell' and tr.entity_id = sp.id::text");
    lines.push("        and tr.field_name = 'name' and tr.locale = 'fr'");
    lines.push('      where tr.value = rec.name and sp.level = rec.level');
    lines.push('    ) then');
    lines.push(
      '      insert into public.spells (level, school, casting_time, range, components, duration, concentration, ritual, source)',
    );
    lines.push(
      '        values (rec.level, rec.school, rec.casting_time, rec.range, rec.components, rec.duration, rec.concentration, rec.ritual, rec.source)',
    );
    lines.push('        returning id into v_id;');
    lines.push('      insert into public.translations (entity_type, entity_id, field_name, locale, value) values');
    lines.push("        ('spell', v_id::text, 'name', 'fr', rec.name),");
    lines.push("        ('spell', v_id::text, 'description', 'fr', rec.description);");
    lines.push('      if rec.description_en is not null then');
    lines.push('        insert into public.translations (entity_type, entity_id, field_name, locale, value) values');
    lines.push("          ('spell', v_id::text, 'description', 'en', rec.description_en);");
    lines.push('      end if;');
    lines.push('    end if;');
    lines.push('  end loop;');
    lines.push('end $$;');
  }
  lines.push('');

  // Liaison spell_classes pour les sorts fraîchement insérés.
  const linkRows = [];
  for (const spell of toInsert) {
    for (const className of spell.classesFr) {
      linkRows.push(`  (${sqlQuote(spell.nameFr)}, ${spell.level}, ${sqlQuote(className)})`);
    }
  }
  if (linkRows.length) {
    lines.push('-- Association sorts <-> classes pouvant les apprendre/préparer (sorts de ce lot).');
    lines.push('insert into public.spell_classes (spell_id, class_id)');
    lines.push('select sp.id, c.id');
    lines.push('from (values');
    lines.push(linkRows.join(',\n'));
    lines.push(') as link(spell_name, spell_level, class_name)');
    lines.push('join public.translations spt');
    lines.push("  on spt.entity_type = 'spell' and spt.field_name = 'name' and spt.locale = 'fr'");
    lines.push('  and spt.value = link.spell_name');
    lines.push('join public.spells sp on sp.id::text = spt.entity_id and sp.level = link.spell_level');
    lines.push('join public.translations ct');
    lines.push("  on ct.entity_type = 'class' and ct.field_name = 'name' and ct.locale = 'fr'");
    lines.push('  and ct.value = link.class_name');
    lines.push('join public.classes c on c.id::text = ct.entity_id');
    lines.push('where not exists (');
    lines.push('  select 1 from public.spell_classes existing');
    lines.push('  where existing.spell_id = sp.id and existing.class_id = c.id');
    lines.push(');');
    lines.push('');
  }

  if (enBackfill.length) {
    lines.push('-- Backfill optionnel : traduction EN pour les sorts du socle Phase 1 (déjà présents,');
    lines.push('-- non réinsérés) quand ce lot a pu leur associer une description mécanique anglaise.');
    lines.push('-- Ne modifie ni le nom ni la description FR de ces sorts.');
    lines.push('insert into public.translations (entity_type, entity_id, field_name, locale, value)');
    lines.push('select ' + "'spell', sp.id::text, 'description', 'en', link.description_en");
    lines.push('from (values');
    const backfillRows = enBackfill.map((spell, index) => {
      const comma = index === enBackfill.length - 1 ? '' : ',';
      return `  (${sqlQuote(spell.nameFr)}, ${spell.level}, ${sqlQuote(spell.descriptionEn)})${comma}`;
    });
    lines.push(...backfillRows);
    lines.push(') as link(spell_name, spell_level, description_en)');
    lines.push('join public.translations spt');
    lines.push("  on spt.entity_type = 'spell' and spt.field_name = 'name' and spt.locale = 'fr'");
    lines.push('  and spt.value = link.spell_name');
    lines.push('join public.spells sp on sp.id::text = spt.entity_id and sp.level = link.spell_level');
    lines.push('where not exists (');
    lines.push('  select 1 from public.translations existing_en');
    lines.push("  where existing_en.entity_type = 'spell' and existing_en.entity_id = sp.id::text");
    lines.push("    and existing_en.field_name = 'description' and existing_en.locale = 'en'");
    lines.push(');');
    lines.push('');
  }

  return lines.join('\n');
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

async function fetchText(url) {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`HTTP ${response.status} pour ${url}`);
  return response.text();
}

async function fetchJson(url) {
  return JSON.parse(await fetchText(url));
}

function parseArgs(argv) {
  const args = { out: null, db: DEFAULT_DB_URL };
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === '--out') args.out = argv[++i];
    else if (argv[i] === '--db') args.db = argv[++i];
  }
  return args;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  console.log('[import-spells] Téléchargement des 3 sources externes...');
  const [aideddHtml, mechanicsDb, sourcesDb] = await Promise.all([
    fetchText(SOURCES.aideddHtml),
    fetchJson(SOURCES.mechanicsJson),
    fetchJson(SOURCES.classesJson),
  ]);

  const aideddRows = parseAideddSpellTable(aideddHtml);
  console.log(`[import-spells] Table aidedd : ${aideddRows.length} lignes de sorts parsées.`);

  const mechanicsByEnglishName = new Map();
  for (const raw of Object.values(mechanicsDb)) {
    if (raw && raw.name) mechanicsByEnglishName.set(spellNorm(raw.name), raw);
  }
  console.log(`[import-spells] JSON mécanique : ${mechanicsByEnglishName.size} sorts (clés EN normalisées).`);

  const classIndex = buildClassIndex(sourcesDb);

  const availableClassNamesFr = loadExistingClassNamesFr(args.db);
  console.log(`[import-spells] Classes disponibles en base : ${[...availableClassNamesFr].sort().join(', ')}`);

  const { merged, mismatches } = mergeSpells(aideddRows, mechanicsByEnglishName, classIndex, availableClassNamesFr);
  console.log(`[import-spells] Fusion réussie : ${merged.length} sorts. Mismatchs (nom VO introuvable dans le JSON mécanique) : ${mismatches.length}.`);
  if (mismatches.length) {
    console.log('[import-spells] Sorts ignorés (mismatch nom VO) :');
    for (const m of mismatches) {
      console.log(`  - "${m.nom}" (VO: "${m.nomVO}", niveau ${m.niveau}, source: ${m.source})`);
    }
  }

  const existingSpells = loadExistingSpells(args.db);
  console.log('[import-spells] Sorts deja en base : ' + existingSpells.length + '.');

  const { voLevelKeys, existingByVoLevel } = resolveExistingSpellIdentities(existingSpells, aideddRows);

  const toInsert = [];
  const enBackfill = [];
  let duplicateCount = 0;
  for (const spell of merged) {
    const voKey = spellNorm(spell.nameEn) + '|' + spell.level;
    const existingMatch = voLevelKeys.has(voKey) ? existingByVoLevel.get(voKey) : null;
    if (existingMatch) {
      duplicateCount += 1;
      if (spell.descriptionEn) {
        enBackfill.push({
          nameFr: existingMatch.name,
          level: existingMatch.level,
          descriptionEn: spell.descriptionEn,
        });
      }
      continue;
    }
    toInsert.push(spell);
  }

  console.log(`[import-spells] Sorts à insérer : ${toInsert.length}. Doublons évités (déjà en base) : ${duplicateCount}.`);
  console.log(`[import-spells] Backfill EN candidat pour sorts déjà en base : ${enBackfill.length}.`);

  // Contrôle anti-mojibake : le texte FR généré ne doit provenir que de la
  // table aidedd (source 1) — jamais de meta.translations.fr (source 2,
  // documentée comme corrompue). On vérifie ici l'absence de caractères de
  // substitution/mojibake dans le texte FR produit, quelle que soit son
  // origine réelle.
  const mojibakePattern = /�|Ã[-¿]|â€/;
  const suspects = toInsert.filter((s) => mojibakePattern.test(s.nameFr) || mojibakePattern.test(s.descriptionFr));
  if (suspects.length) {
    console.warn(`[import-spells] ATTENTION : ${suspects.length} sorts avec un texte FR suspect (mojibake) :`);
    for (const s of suspects.slice(0, 10)) console.warn(`  - ${s.nameFr}`);
  } else {
    console.log('[import-spells] Contrôle anti-mojibake FR : OK, aucun caractère de substitution détecté.');
  }

  const sql = generateSql({ toInsert, enBackfill });

  const timestamp = new Date()
    .toISOString()
    .replace(/[-:]/g, '')
    .replace(/T/, '')
    .slice(0, 14);
  const defaultOut = join(REPO_ROOT, 'supabase', 'migrations', `${timestamp}_seed_spells_extended.sql`);
  const outPath = args.out ? (isAbsolute(args.out) ? args.out : join(REPO_ROOT, args.out)) : defaultOut;
  mkdirSync(dirname(outPath), { recursive: true });
  writeFileSync(outPath, sql, 'utf8');
  console.log(`[import-spells] Migration écrite : ${outPath}`);
}

main().catch((error) => {
  console.error('[import-spells] Échec :', error);
  process.exitCode = 1;
});
