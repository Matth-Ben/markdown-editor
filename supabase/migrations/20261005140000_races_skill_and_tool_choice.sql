-- Structure les choix de competence(s)/outil(s) accordes par certains traits
-- raciaux, actuellement uniquement en texte libre dans races.traits (jsonb).
-- Permet a l'app mobile "Personnages" de proposer ces choix a la creation.
--
-- Conventions (alignees sur classes.skill_choices / backgrounds.skill_proficiencies) :
--   skill_choice jsonb        {"count": N, "choices": [...] | null}
--     choices: null => n'importe quelle competence du catalogue (choix libre)
--   tool_choice jsonb         {"count": N, "choices": [...]} OU {"count": N, "categories": [...]}
--     choices: null et categories absent => n'importe quel outil du catalogue (choix libre)
--   skill_proficiencies text[]  competences accordees automatiquement (pas un choix)
--
-- Ne touche pas a codex_entries ni a aucune autre table. N'affecte que les 10
-- races listees ci-dessous ; aucune autre race n'a de trait equivalent a
-- structurer dans cette passe.

alter table public.races
  add column if not exists skill_choice jsonb,
  add column if not exists tool_choice jsonb,
  add column if not exists skill_proficiencies text[];

-- Centaure (id 30) — trait "Affinite naturelle"
update public.races
set skill_choice = '{"count":1,"choices":["Dressage","Médecine","Nature","Survie"]}'::jsonb
where id = 30;

-- Changelin (id 31) — trait "Instincts de changelin"
-- NB: le texte du trait en base cite "Intuition", qui ne correspond a aucune
-- entree de translations (entity_type='skill'). Le catalogue de competences
-- utilise "Perspicacité" pour cette capacite (cf. classes.skill_choices /
-- backgrounds.skill_proficiencies) : confirme comme la meme competence sous
-- une traduction anterieure differente, ajoutee aux 5 choix possibles (count
-- reste a 2).
update public.races
set skill_choice = '{"count":2,"choices":["Intimidation","Perspicacité","Persuasion","Représentation","Tromperie"]}'::jsonb
where id = 31;

-- Changeforme (id 48) — trait "Sens bestiaux" (hors perimetre : "Transformation")
update public.races
set skill_choice = '{"count":1,"choices":["Acrobaties","Athlétisme","Intimidation","Survie"]}'::jsonb
where id = 48;

-- Homme-lezard (id 40) — trait "Instincts du chasseur"
update public.races
set skill_choice = '{"count":2,"choices":["Dressage","Médecine","Nature","Perception","Discrétion","Survie"]}'::jsonb
where id = 40;

-- Tortue (id 44) — trait "Instinct de survie"
update public.races
set skill_choice = '{"count":1,"choices":["Dressage","Médecine","Nature","Perception","Discrétion","Survie"]}'::jsonb
where id = 44;

-- Demi-elfe (id 7) — trait "Polyvalence en competences" (choix libre)
update public.races
set skill_choice = '{"count":2,"choices":null}'::jsonb
where id = 7;

-- Forgelier (id 49) — trait "Conception specialisee" (1 competence libre + 1 outil libre)
update public.races
set skill_choice = '{"count":1,"choices":null}'::jsonb,
    tool_choice = '{"count":1,"choices":null}'::jsonb
where id = 49;

-- Nain (id 3) — trait "Maitrise des outils" (3 outils d'artisan nains exacts)
update public.races
set tool_choice = '{"count":1,"choices":["Outils de forgeron","Outils de brasseur","Outils de maçon"]}'::jsonb
where id = 3;

-- Satyre (id 42) — trait "Fetard" (instrument au choix + 2 competences automatiques)
update public.races
set tool_choice = '{"count":1,"categories":["instrument"]}'::jsonb,
    skill_proficiencies = array['Persuasion','Représentation']
where id = 42;

-- Kenku (id 38) — trait "Memoire kenku" (choix libre ; capacite "avantage 1x/repos long" hors perimetre)
update public.races
set skill_choice = '{"count":2,"choices":null}'::jsonb
where id = 38;
