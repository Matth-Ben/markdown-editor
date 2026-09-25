import type { Metadata } from "next";

/**
 * Demande de suppression de compte — URL exigée par Google Play (formulaire
 * « Sécurité des données ») : doit permettre de demander la suppression du
 * compte et des données associées SANS l'application installée, et préciser
 * ce qui est supprimé ou conservé. Page statique publique (voir PUBLIC_PATHS
 * dans lib/supabase/middleware.ts).
 *
 * Apostrophes typographiques (’) plutôt que `&apos;` : voir la note de la PR
 * de /confidentialite (espace perdu après </strong> en rendu de dev).
 */
export const metadata: Metadata = {
  title: "Supprimer mon compte — Nexus JDR",
  description:
    "Comment supprimer ton compte Nexus JDR et toutes les données associées, avec ou sans l’application.",
};

const CONTACT_EMAIL = "support@nexus-jdr.app";
const MAIL_SUBJECT = "Suppression de mon compte Nexus JDR";

export default function AccountDeletionPage() {
  return (
    <main className="mx-auto w-full max-w-3xl flex-1 px-4 py-12 sm:px-6">
      <article className="prose prose-invert max-w-none prose-a:text-violet-300 prose-a:underline-offset-2">
        <h1>Supprimer mon compte Nexus JDR</h1>
        <p>
          Cette page concerne l’application{" "}
          <strong>Nexus JDR — Personnages</strong> (Android) et l’application
          web <strong>Nexus JDR « Histoires »</strong>, éditées par Matthias
          Benoit. Elles partagent le même compte : le supprimer efface tes
          données dans les deux.
        </p>

        <h2 id="depuis-l-app">Option 1 — Depuis l’application (immédiat)</h2>
        <ol>
          <li>Ouvre l’application Nexus JDR — Personnages et connecte-toi.</li>
          <li>
            Va dans{" "}
            <strong>
              Profil › Confidentialité et données › Supprimer mon compte
            </strong>
            .
          </li>
          <li>Confirme avec ton mot de passe.</li>
        </ol>
        <p>La suppression est immédiate et définitive.</p>

        <h2 id="sans-l-app">Option 2 — Sans l’application (par e-mail)</h2>
        <ol>
          <li>
            Écris à{" "}
            <a
              href={`mailto:${CONTACT_EMAIL}?subject=${encodeURIComponent(MAIL_SUBJECT)}`}
            >
              {CONTACT_EMAIL}
            </a>{" "}
            <strong>depuis l’adresse e-mail de ton compte</strong>, avec pour
            objet « {MAIL_SUBJECT} ».
          </li>
          <li>
            Nous pouvons te demander de confirmer ta demande afin de vérifier
            qu’elle vient bien du titulaire du compte.
          </li>
          <li>
            Ton compte et tes données sont supprimés sous 30 jours au plus tard,
            et tu reçois une confirmation par e-mail.
          </li>
        </ol>

        <h2 id="donnees-supprimees">Données supprimées</h2>
        <ul>
          <li>ton compte (adresse e-mail, mot de passe, pseudo) ;</li>
          <li>
            tous tes personnages et leur contenu (caractéristiques, sorts,
            inventaire, histoire, journal), tes notes et ta participation aux
            groupes et histoires ;
          </li>
          <li>tes photos : portraits, galerie et avatar ;</li>
          <li>tes préférences et jetons de notification ;</li>
          <li>tes signalements de bug enregistrés sur nos serveurs.</li>
        </ul>

        <h2 id="donnees-conservees">Données conservées</h2>
        <ul>
          <li>
            <strong>Statistiques d’utilisation</strong> : pseudonymes et sans
            lien avec ton compte, elles restent dans nos outils de mesure
            (Firebase Analytics, PostHog) pendant leur durée de conservation.
          </li>
          <li>
            <strong>Tickets de bug publiés sur GitHub</strong> : ils ne
            contiennent ni ton adresse e-mail ni ton nom, seulement le texte du
            signalement. Tu peux demander leur retrait à la même adresse.
          </li>
        </ul>
        <p>
          Aucune autre donnée n’est conservée après la suppression. Pour en
          savoir plus, consulte notre{" "}
          <a href="/confidentialite">politique de confidentialité</a>.
        </p>
      </article>
    </main>
  );
}
