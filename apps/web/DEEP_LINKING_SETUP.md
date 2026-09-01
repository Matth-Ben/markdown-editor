# Configuration des liens universels — app mobile "Personnages"

Fichiers requis pour que `https://nexus-jdr.app/join/{code}` ouvre
directement l'app mobile Flutter (dépôt `nexus-jdr-app-mobile`) plutôt qu'un
navigateur — voir `docs/cahier-des-charges/04-fonctionnalites-app-mobile.md`
section 7.1, `12-partage-et-groupes.md` section 5.3 et
`13-depot-versioning-publication.md` section 4 du dépôt mobile.

État au 2026-09-01 : **Android entièrement fonctionnel** — keystore de
production généré et câblé (signature des builds release configurée dans
`android/app/build.gradle.kts` du dépôt mobile), domaine `nexus-jdr.app`
hébergé sur Vercel avec `nexus-jdr.app` (sans www) comme domaine canonique
(pas de redirection, requis pour la vérification), `assetlinks.json`
accessible publiquement (le middleware d'authentification l'excluait par
erreur au départ, corrigé — voir `proxy.ts`). Vérifié via l'API officielle
Google Digital Asset Links : le statement est bien validé. Il ne reste que
le compte Apple Developer pour finir le côté iOS.

## `public/.well-known/assetlinks.json` (Android App Links)

**Fait** — empreinte SHA-256 du keystore de production renseignée. Pour
aussi tester les liens universels sur des builds de développement (pas
seulement en production), ajouter une deuxième entrée dans
`sha256_cert_fingerprints` avec l'empreinte du keystore **debug**
(`keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey`,
mot de passe `android`).

## `app/.well-known/apple-app-site-association/route.ts` (iOS Universal Links)

Servi par une route plutôt qu'un fichier statique — Apple attend
`Content-Type: application/json` même si l'URL n'a pas d'extension `.json`.

**Placeholder à remplacer** : `TEAMID` dans `appID` (constante en tête du
fichier `route.ts`). Remplacer par le Team ID du compte Apple Developer
Program utilisé pour signer les builds distribués (visible dans
[developer.apple.com/account](https://developer.apple.com/account) une fois
le compte créé), format `TEAMID.com.nexusjdr.personnages`.

## Vérification une fois les deux placeholders remplacés et le domaine déployé

- **Android** : `https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://nexus-jdr.app&relation=delegate_permission/common.handle_all_urls`
  doit retourner le statement du fichier. Test réel :
  `adb shell am start -a android.intent.action.VIEW -d "https://nexus-jdr.app/join/ABC123"`
  doit ouvrir l'app directement, pas un sélecteur d'app.
- **iOS** : [Apple's AASA validator](https://search.developer.apple.com/appsearch-validation-tool/)
  avec l'URL du domaine. Test réel : envoyer le lien par Messages/Notes sur
  un appareil avec l'app installée (build signé avec le même Team ID) et
  taper dessus doit ouvrir l'app directement.

## Ce qui reste à faire côté infra (hors périmètre code)

1. ~~Acheter/pointer le domaine `nexus-jdr.app`~~ — fait le 2026-09-01,
   hébergé sur Vercel, `nexus-jdr.app` (sans www) confirmé comme domaine
   canonique, `assetlinks.json` vérifié valide via l'API Google.
2. ~~Générer le keystore Android de production~~ — fait le 2026-09-01,
   empreinte renseignée dans `assetlinks.json`.
3. Créer le compte Apple Developer Program et remplacer le placeholder
   `TEAMID` ci-dessus.
4. Dans Xcode (`ios/Runner.xcworkspace` du dépôt mobile), onglet "Signing &
   Capabilities" du target "Runner" → "+ Capability" → "Associated Domains"
   → référencer `ios/Runner/Runner.entitlements` (déjà présent dans le dépôt,
   contient `applinks:nexus-jdr.app`) — ne peut pas être fait par édition de
   fichier seule, Xcode requis (macOS).
5. Vérifier iOS avec la commande ci-dessus avant la première soumission aux
   stores (Android est déjà vérifié et fonctionnel).
