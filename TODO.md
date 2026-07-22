# Nexus JDR — Feuille de route

Basé sur le périmètre MVP de [claude.md](claude.md). À compléter librement.

## Authentification
- [x] Inscription / connexion (email + mot de passe)
- [x] Réinitialisation du mot de passe
- [ ]

## Bibliothèque
- [x] Grille de cartes (campagnes/scénarios)
- [x] Upload de couverture (Supabase Storage)
- [ ] Suppression / modification d'une histoire
- [ ] Ajouter un clique droit sur la bibliothèque pour avoir Éditer/Modifier/Supprimer/Etc.

## Éditeur & Gestion des médias
- [x] Zone de saisie Markdown + prévisualisation (vue scindée / onglets)
- [x] Bloc de déclenchement `:::ambiance{...}`
- [x] Barre d'outils façon WYSIWYG (titres H1-H3, gras, italique, barré, lien, image, citation, listes, code, ligne horizontale) — éditeur d'histoire + notes du Codex
- [ ] Glisser-déposer d'images dans le texte
- [ ]

## Paramètres de l'application
- [ ] Configuration Philips Hue (IP du pont + appairage)
- [ ] Ressources locales (chemin du dossier musiques/bruitages)
- [ ]

## Le Codex (base de données du lore)
- [x] Fiches (PNJ, Bestiaire, Joueurs, Lieux, Autre — champs par catégorie)
- [x] Infobulles dynamiques dans l'éditeur (mention `[[Nom]]`)
- [x] Barre latérale Codex dans l'éditeur (liste, bouton ajouter, bouton gestion modifier/supprimer)
- [x] Affichage fiche (vue / édition) dans une popin (modale accessible, glassmorphism)
- [x] Autocomplétion `[[` pendant la rédaction (suggestions, Tab/Entrée pour compléter)
- [x] Import de fiche personnage (.xml, format "builder" D&D 5e) → pré-remplit une fiche Joueur
- [x] Affichage à onglets granulaire pour les fiches Joueur (Info globale avec caractéristiques séparées, Identité/Apparence, Personnalité par champ, Historique, Sorts & équipement en listes), popin plus large (xl)
- [x] Filtre par catégorie (dropdown avec compteur), recherche par nom, tri (A→Z, Z→A, récent) dans la sidebar
- [x] Sélection multiple + actions en masse (déplacer vers une catégorie, supprimer)
- [x] Intégration API Open5e (creatures/spells/magicitems) : recherche + aperçu au survol à la création (PNJ, Bestiaire, sorts/objets du Joueur), popin de détail au clic sur une fiche déjà liée
- [x] Recherche/pré-remplissage Open5e (species/classes) pour Race, Classe et Voie/Sous-classe sur la fiche Joueur, avec navigation clavier et aperçu au survol (comme PNJ/Bestiaire)
- [ ] Étendre l'intégration Open5e à d'autres endpoints (backgrounds, feats, conditions...)
- [ ] Étendre l'import à d'autres formats/outils de fiche perso
- [ ]

## La Feuille de Route (Mode Session)
- [ ] Vue lecture seule synchronisée en temps réel
- [ ] Boutons d'ambiance interactifs (déclenchement réel audio + Hue)
- [ ] Raccourcis clavier personnalisables (ex: Alt+1)
- [ ]

## Electron / Desktop
- [x] Shell Electron (fenêtre + chargement de l'app web)
- [ ] IPC audio (lecture de fichiers locaux)
- [ ] IPC filesystem (sélection du dossier musiques/bruitages)
- [ ] Packaging (electron-builder, installeurs Win/Mac/Linux)
- [ ]

## Déploiement
- [ ] Déploiement Vercel (apps/web)
- [ ] Bascule Site URL Supabase (dev → prod) — voir note dans le suivi de session
- [ ]
