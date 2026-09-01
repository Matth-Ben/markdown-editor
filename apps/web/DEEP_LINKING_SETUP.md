# Configuration des liens universels — app mobile "Personnages"

Fichiers requis pour que `https://nexus-jdr.app/join/{code}` ouvre
directement l'app mobile Flutter (dépôt `nexus-jdr-app-mobile`) plutôt qu'un
navigateur — voir `docs/cahier-des-charges/04-fonctionnalites-app-mobile.md`
section 7.1, `12-partage-et-groupes.md` section 5.3 et
`13-depot-versioning-publication.md` section 4 du dépôt mobile.

Les deux fichiers ci-dessous sont déjà en place, avec des valeurs
placeholder à remplacer une fois les prérequis externes réunis (aucun des
trois n'existe encore au 2026-08-31 : domaine `nexus-jdr.app` pas hébergé,
keystore Android release pas généré, compte Apple Developer pas créé).

## `public/.well-known/assetlinks.json` (Android App Links)

**Placeholder à remplacer** : `TODO_REMPLACER_PAR_EMPREINTE_SHA256_KEYSTORE_RELEASE`.

Une fois le keystore de production Android généré (voir
`13-depot-versioning-publication.md` section 4 du dépôt mobile), extraire
l'empreinte SHA-256 du certificat avec :

```bash
keytool -list -v -keystore <chemin-du-keystore-release>.jks -alias <alias>
```

Copier la valeur `SHA256:` (garder les deux-points) dans le tableau
`sha256_cert_fingerprints`. Ajouter une deuxième entrée dans ce même tableau
pour l'empreinte du keystore **debug** (`~/.android/debug.keystore`, mot de
passe `android`) si on veut aussi tester les liens universels sur des builds
de développement, pas seulement en production.

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

1. Acheter/pointer le domaine `nexus-jdr.app` vers l'hébergement de cette
   app web (Vercel ou équivalent — voir `output: "standalone"` dans
   `next.config.ts`).
2. Générer le keystore Android de production (`13-depot-versioning-publication.md`
   section 4 du dépôt mobile) et remplacer le placeholder ci-dessus.
3. Créer le compte Apple Developer Program et remplacer le placeholder
   `TEAMID` ci-dessus.
4. Dans Xcode (`ios/Runner.xcworkspace` du dépôt mobile), onglet "Signing &
   Capabilities" du target "Runner" → "+ Capability" → "Associated Domains"
   → référencer `ios/Runner/Runner.entitlements` (déjà présent dans le dépôt,
   contient `applinks:nexus-jdr.app`) — ne peut pas être fait par édition de
   fichier seule, Xcode requis (macOS).
5. Vérifier les deux plateformes avec les commandes ci-dessus avant la
   première soumission aux stores.
