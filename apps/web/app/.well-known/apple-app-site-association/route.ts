// Vérification iOS Universal Links pour le deep link nexus-jdr.app/join/{code}
// (app mobile Flutter, dépôt nexus-jdr-app-mobile). Voir
// apps/web/DEEP_LINKING_SETUP.md pour le contexte complet et les étapes
// restantes.
//
// Servi comme une route plutôt qu'un fichier statique de `public/` : Apple
// attend `Content-Type: application/json` même si l'URL n'a pas
// d'extension `.json`, ce que la résolution de type MIME par extension de
// Next.js ne garantit pas pour un fichier statique sans suffixe.
//
// TODO : remplacer "TEAMID" par le Team ID du compte Apple Developer
// Program une fois créé (developer.apple.com/account) — pas encore fait.
const APP_ID = "TEAMID.com.nexusjdr.personnages";

export function GET() {
  const body = {
    applinks: {
      apps: [] as string[],
      details: [
        {
          appID: APP_ID,
          paths: ["/join/*"],
        },
      ],
    },
  };

  return Response.json(body);
}
