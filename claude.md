# Contexte du Projet : Carnet de Worldbuilding & Assistant MJ

## 1. Vision Globale
L'objectif est de développer un outil "zéro friction" destiné aux écrivains et Meneurs de Jeu (MJ) de jeux de rôle sur table. 
L'application possède deux facettes :
- **Mode Création (Desktop) :** Un éditeur de texte basé sur une syntaxe Markdown étendue. Le MJ rédige ses campagnes, gère son univers, et peut lier des déclencheurs d'ambiance (audio local et contrôle de lumières connectées Philips Hue) directement dans son texte.
- **Mode Session (Mobile/Tablette/Desktop) :** Une "Feuille de Route" épurée générée à partir des notes. Les balises d'ambiance deviennent des boutons interactifs permettant de déclencher instantanément des scènes sonores et lumineuses en pleine partie physique, sans briser l'immersion.

## 2. Stack Technologique
- **Core / Front-end :** Next.js (React) avec TypeScript.
- **Client Desktop :** Electron (encapsule l'app Next.js pour permettre l'accès au système de fichiers local pour l'audio lourd, et contourner les restrictions CORS pour l'API locale Philips Hue).
- **Synchronisation / Backend :** Supabase (PostgreSQL, Authentification, Storage pour les images, et Realtime pour synchroniser les notes entre les appareils).
- **Styling :** Tailwind CSS.
- **Animations :** Framer Motion (pour des transitions fluides et un rendu visuel haut de gamme).
- **Parsing Markdown :** React-Markdown (ou un parseur AST personnalisé) configuré pour gérer nos balises d'ambiance spécifiques (ex: `::: ambiance combat :::`).

## 3. Directives UI / UX ("Épuré mais immersif")
- **Thème :** Dark Mode first. L'interface doit être sombre, avec des contrastes profonds (fonds gris très sombres/noirs, textes clairs). 
- **Couleurs d'accentuation :** Utiliser des touches subtiles et vibrantes (ex: un liseré néon violet ou cyan) uniquement pour les éléments interactifs.
- **Minimalisme :** Pendant l'écriture et la lecture, l'interface doit s'effacer. Le texte et l'histoire sont rois.
- **Glassmorphism :** Les menus ou modales doivent utiliser de légers effets de transparence et de flou (backdrop-blur).
- **Accessibilité (Conformité RGAA 4) :** L'interface doit être intégralement navigable au clavier. Les contrastes doivent être optimisés pour une lecture dans la pénombre derrière un écran de MJ, et les focus d'éléments interactifs doivent être évidents.

## 4. Règles de Développement pour l'IA (Claude)
- **Modulaire & Scalable :** Découpe le code en petits composants réutilisables. Ne génère pas des fichiers monolithes.
- **Communication Proactive :** Si une demande est ambiguë (notamment concernant l'intégration Philips Hue ou la logique de parsing Markdown), **pose des questions avant d'écrire le code**. Ne fais pas de suppositions.
- **Gestion d'État :** Utilise Zustand ou le Context API de React pour gérer l'état global (ex: la piste audio en cours, l'état de connexion des lumières, les raccourcis clavier actifs).
- **Performances & Local :** Priorise le stockage local pour les assets lourds (musique, bruitages) via Electron. Supabase Storage sert uniquement aux images légères (couvertures, illustrations du Codex).
- **Documentation :** Commente systématiquement les fonctions complexes.

## 5. Périmètre Fonctionnel (MVP)

*   **Authentification (via Supabase Auth) :** 
    *   Inscription et Connexion (Email/Mot de passe).
    *   Réinitialisation du mot de passe.
*   **La Bibliothèque (Dashboard) :**
    *   Liste des campagnes et scénarios sous forme de grille de cartes minimalistes.
    *   Possibilité d'uploader une image de couverture pour chaque histoire (via Supabase Storage).
*   **Paramètres de l'Application :**
    *   Configuration Philips Hue : Champ de saisie pour l'adresse IP du pont local et bouton d'appairage.
    *   Ressources Locales : Définition du chemin d'accès au dossier racine contenant les musiques et bruitages.
*   **L'Éditeur & Gestion des Médias (Mode Création) :**
    *   Zone de saisie Markdown avec prévisualisation.
    *   Interface permettant d'injecter facilement le bloc de déclenchement `::: ambiance :::`.
    *   Support du glisser-déposer pour insérer des images directement au cœur du texte.
*   **Le Codex (Base de données du Lore) :**
    *   Création de fiches liées à l'univers (PNJ, Bestiaire, Joueurs, Lieux, etc.).
    *   Système d'infobulles dynamiques dans l'éditeur : mentionner une entité du Codex dans le texte affiche un résumé de ses statistiques au survol.
*   **La Feuille de Route (Mode Session) :**
    *   Vue épurée en lecture seule, synchronisée en temps réel.
    *   Les blocs d'ambiance deviennent des boutons interactifs.
    *   **Raccourcis Clavier :** Le MJ doit pouvoir déclencher les ambiances de la page ou naviguer dans le texte à l'aveugle via des raccourcis personnalisables (ex: `Alt + 1` pour la première ambiance de la scène).
