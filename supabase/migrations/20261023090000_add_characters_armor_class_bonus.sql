alter table public.characters
  add column armor_class_bonus integer not null default 0;

comment on column public.characters.armor_class_bonus is
  'Ajustement manuel de Classe d''Armure saisi par le joueur (app mobile), persistant jusqu''a suppression manuelle. '
  'Distinct du calcul a la volee de la CA (ArmorClassCalculator, jamais stocke) : ce champ est additionne au resultat '
  'calcule pour l''affichage. Peut etre negatif (ex. malediction narree par le MJ comme Bestow Curse) : ce n''est pas '
  'un simple bonus, malgre le nom retenu pour la fonctionnalite. Aucune contrainte de plage : note libre du joueur, '
  'sans limite RAW claire a imposer ici.';
