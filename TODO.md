# Nexus JDR — Feuille de route

Basé sur le périmètre MVP de [claude.md](claude.md). À compléter librement.

## Authentification
- [x] Inscription / connexion (email + mot de passe)
- [x] Réinitialisation du mot de passe
- [ ]

## Bibliothèque
- [x] Grille de cartes (campagnes/scénarios)
- [x] Upload de couverture (Supabase Storage)
- [x] Modification d'une histoire (titre en édition inline, couverture via popin avec aperçu — depuis l'éditeur)
- [x] Suppression d'une histoire (fiches Codex + images de contenu + couverture nettoyées)
- [x] Clic droit (ou bouton ⋮) sur une carte de la bibliothèque : Ouvrir / Supprimer (avec confirmation)

## Éditeur & Gestion des médias
- [x] Zone de saisie Markdown + prévisualisation (vue scindée / onglets)
- [x] Bloc de déclenchement `:::ambiance{...}`
- [x] Barre d'outils façon WYSIWYG (titres H1-H3, gras, italique, barré, lien, image, citation, listes, code, ligne horizontale) — éditeur d'histoire + notes du Codex
- [x] Image : lien externe (URL) ou import direct depuis l'ordinateur (upload Supabase Storage, bucket `story-content-images`)
- [x] Nettoyage automatique des images orphelines (Storage) quand elles sont retirées du texte à l'enregistrement, ou quand la fiche/l'histoire qui les contient est supprimée
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
- [x] Route dédiée `/story/[id]/session` (vue épurée en lecture seule) + bouton de bascule Édition ↔ Feuille de route
- [x] Sidebar droite : sommaire (ancres vers les titres H1-H3) + liste Codex par catégorie (ouverture d'une fiche en modale avec toutes les infos)
- [ ] Synchronisation temps réel (Supabase Realtime) — pour l'instant la vue se recharge manuellement
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
