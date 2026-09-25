import type { Metadata } from "next";

/**
 * Politique de confidentialité publique de Nexus JDR — URL exigée par
 * Google Play (fiche store) et liée depuis l'app mobile. Page statique,
 * accessible sans connexion (voir PUBLIC_PATHS dans
 * lib/supabase/middleware.ts).
 *
 * Reprend et complète l'écran « Politique de confidentialité » de l'app
 * mobile (dépôt nexus-jdr-app-mobile) : à garder alignés.
 */
export const metadata: Metadata = {
  title: "Politique de confidentialité — Nexus JDR",
  description:
    "Quelles données Nexus JDR collecte, pourquoi, avec qui elles sont partagées et comment exercer tes droits.",
};

const LAST_UPDATED = "25 septembre 2026";
const CONTACT_EMAIL = "support@nexus-jdr.app";

type Section = { id: string; title: string; body: React.ReactNode };

const sections: Section[] = [
  {
    id: "responsable",
    title: "1. Qui est responsable de tes données",
    body: (
      <>
        <p>
          Cette politique s’applique à l’application mobile{" "}
          <strong>Nexus JDR — Personnages</strong> (Android) et à l’application
          web <strong>Nexus JDR « Histoires »</strong> (nexus-jdr.app), qui
          partagent le même compte.
        </p>
        <p>
          Responsable du traitement : <strong>Matthias Benoit</strong>, éditeur
          de Nexus JDR. Contact :{" "}
          <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a>.
        </p>
      </>
    ),
  },
  {
    id: "donnees",
    title: "2. Données collectées",
    body: (
      <ul>
        <li>
          <strong>Compte</strong> : adresse e-mail et mot de passe (le mot de
          passe est stocké chiffré par notre service d’authentification, nous ne
          le voyons jamais), pseudo affiché et avatar facultatif.
        </li>
        <li>
          <strong>Contenu de jeu</strong> : tout ce que tu crées — personnages
          (caractéristiques, compétences, sorts, inventaire, apparence,
          histoire), journal, notes de groupe, groupes et histoires rejoints,
          fichiers de personnage que tu importes.
        </li>
        <li>
          <strong>Photos</strong> : portrait de personnage, galerie et avatar,
          uniquement les images que tu choisis de prendre avec l’appareil photo,
          d’importer depuis ta galerie ou depuis une adresse web.
        </li>
        <li>
          <strong>Dictée vocale</strong> (notes de groupe, facultative) : le
          micro n’est utilisé que pendant que tu dictes. La reconnaissance
          vocale est assurée par le service de ton téléphone (par exemple Google
          sur Android) ; nous ne recevons que le texte obtenu, jamais
          l’enregistrement audio.
        </li>
        <li>
          <strong>Notifications</strong> : un identifiant technique de ton
          appareil (jeton de notification) et tes préférences de notification,
          pour t’envoyer les rappels et nouvelles de tes groupes.
        </li>
        <li>
          <strong>Statistiques d’utilisation</strong> : écrans consultés et
          actions réalisées dans l’app, accompagnés d’informations techniques
          (modèle d’appareil, système, version de l’app) et d’un identifiant
          pseudonyme généré par l’outil de mesure. Ces statistiques ne sont pas
          rattachées à ton compte ni à ton adresse e-mail.
        </li>
        <li>
          <strong>Signalements de bug</strong> : titre, description et gravité
          que tu saisis, version de l’app, plateforme et, si tu le choisis, le
          personnage concerné.
        </li>
      </ul>
    ),
  },
  {
    id: "non-collecte",
    title: "3. Ce que nous ne collectons pas",
    body: (
      <p>
        Aucune donnée de localisation, aucun contact, aucune donnée de paiement.
        Aucune publicité n’est affichée et aucune donnée n’est vendue.
      </p>
    ),
  },
  {
    id: "finalites",
    title: "4. Pourquoi nous utilisons ces données",
    body: (
      <ul>
        <li>
          <strong>Fournir le service</strong> (compte, fiches, groupes,
          synchronisation avec ton MJ, photos, notifications que tu actives) :
          c’est nécessaire à l’exécution du service que tu utilises.
        </li>
        <li>
          <strong>Améliorer l’app</strong> (statistiques d’utilisation) :
          intérêt légitime à comprendre quelles fonctionnalités sont utilisées.
          Tu peux t’y opposer à tout moment dans{" "}
          <em>
            Profil › Confidentialité et données › Partager mes données d’usage
          </em>
          .
        </li>
        <li>
          <strong>Corriger les bugs</strong> que tu nous signales.
        </li>
      </ul>
    ),
  },
  {
    id: "partage",
    title: "5. Avec qui tes données sont partagées",
    body: (
      <>
        <p>
          <strong>
            Avec d’autres utilisateurs, uniquement à ton initiative
          </strong>{" "}
          : le MJ et les membres des histoires ou groupes que tu rejoins voient
          les personnages que tu y rattaches ; si tu crées un lien de partage de
          fiche, toute personne disposant de ce lien peut consulter la fiche en
          lecture seule, jusqu’à ce que tu le désactives.
        </p>
        <p>
          <strong>Avec nos prestataires techniques</strong>, qui traitent les
          données pour notre compte :
        </p>
        <ul>
          <li>
            <strong>Supabase</strong> — hébergement de la base de données, de
            l’authentification et des photos.
          </li>
          <li>
            <strong>Google Firebase</strong> — envoi des notifications (Firebase
            Cloud Messaging) et statistiques d’utilisation (Firebase Analytics).
          </li>
          <li>
            <strong>PostHog</strong> (hébergement dans l’Union européenne) —
            statistiques d’utilisation.
          </li>
          <li>
            <strong>GitHub</strong> — suivi des bugs signalés : le contenu d’un
            signalement (titre, description, gravité, version, plateforme) est
            publié comme ticket dans un dépôt public, sans ton adresse e-mail ni
            ton nom. N’y indique donc aucune information personnelle.
          </li>
          <li>
            <strong>Vercel</strong> — hébergement du site nexus-jdr.app.
          </li>
        </ul>
        <p>
          Certains de ces prestataires peuvent traiter des données hors de
          l’Union européenne ; ces transferts sont encadrés par les garanties
          prévues par le RGPD (clauses contractuelles types de la Commission
          européenne ou cadre de protection des données UE–États-Unis).
        </p>
      </>
    ),
  },
  {
    id: "conservation",
    title: "6. Durée de conservation",
    body: (
      <ul>
        <li>
          Compte, contenu de jeu et photos : tant que ton compte existe. Ils
          sont supprimés définitivement dès que tu supprimes ton compte.
        </li>
        <li>
          Statistiques d’utilisation : conservées sous forme pseudonyme, sans
          lien avec ton compte, pendant la durée de conservation paramétrée dans
          les outils de mesure.
        </li>
        <li>Signalements de bug : le temps nécessaire à leur traitement.</li>
      </ul>
    ),
  },
  {
    id: "droits",
    title: "7. Tes droits",
    body: (
      <>
        <p>
          Conformément au RGPD, tu disposes d’un droit d’accès, de
          rectification, d’effacement, de portabilité, d’opposition et de
          limitation du traitement. Directement depuis l’app :
        </p>
        <ul>
          <li>
            <strong>Exporter tes données</strong> :{" "}
            <em>Profil › Confidentialité et données › Exporter mes données</em>.
          </li>
          <li>
            <strong>Supprimer ton compte et toutes tes données</strong> :{" "}
            <em>Profil › Confidentialité et données › Supprimer mon compte</em>,
            ou sans l’application en suivant{" "}
            <a href="/suppression-compte">cette procédure</a>.
          </li>
          <li>
            <strong>Désactiver les statistiques d’utilisation</strong> :{" "}
            <em>Profil › Confidentialité et données</em>.
          </li>
          <li>
            <strong>Désactiver les notifications</strong> : dans les réglages de
            notification de l’app ou de ton téléphone.
          </li>
        </ul>
        <p>
          Pour toute autre demande, écris à{" "}
          <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a>. Tu peux aussi
          introduire une réclamation auprès de la CNIL (
          <a href="https://www.cnil.fr" rel="noopener noreferrer">
            www.cnil.fr
          </a>
          ).
        </p>
      </>
    ),
  },
  {
    id: "securite",
    title: "8. Sécurité",
    body: (
      <p>
        Les échanges avec nos serveurs sont chiffrés (HTTPS). L’accès à tes
        données est protégé par l’authentification de ton compte et par des
        règles d’accès qui empêchent tout autre utilisateur de lire ou modifier
        ce que tu ne partages pas.
      </p>
    ),
  },
  {
    id: "modifications",
    title: "9. Modifications de cette politique",
    body: (
      <p>
        Cette politique peut évoluer avec l’application. La date de dernière
        mise à jour figure en haut de cette page ; en cas de changement
        important, tu en seras informé dans l’app.
      </p>
    ),
  },
];

export default function PrivacyPolicyPage() {
  return (
    <main className="mx-auto w-full max-w-3xl flex-1 px-4 py-12 sm:px-6">
      <article className="prose prose-invert max-w-none prose-a:text-violet-300 prose-a:underline-offset-2">
        <h1>Politique de confidentialité</h1>
        <p className="text-sm text-white/60">
          Nexus JDR — Dernière mise à jour : {LAST_UPDATED}
        </p>
        <p>
          Cette page explique quelles données Nexus JDR collecte, pourquoi, avec
          qui elles sont partagées, et comment tu peux y accéder, les exporter
          ou les supprimer.
        </p>
        <nav aria-label="Sommaire">
          <ul>
            {sections.map((section) => (
              <li key={section.id}>
                <a href={`#${section.id}`}>{section.title}</a>
              </li>
            ))}
          </ul>
        </nav>
        {sections.map((section) => (
          <section key={section.id} aria-labelledby={section.id}>
            <h2 id={section.id} className="scroll-mt-8">
              {section.title}
            </h2>
            {section.body}
          </section>
        ))}
      </article>
    </main>
  );
}
