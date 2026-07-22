import type { NextConfig } from "next";
import path from "node:path";

const supabaseHostname = process.env.NEXT_PUBLIC_SUPABASE_URL
  ? new URL(process.env.NEXT_PUBLIC_SUPABASE_URL).hostname
  : undefined;

const nextConfig: NextConfig = {
  // "standalone" est réutilisé tel quel par apps/desktop pour packager le serveur Next en prod.
  output: "standalone",
  transpilePackages: ["@nexus/ui", "@nexus/core", "@nexus/supabase-client"],
  turbopack: {
    root: path.join(__dirname, "..", ".."),
  },
  experimental: {
    // Les Server Actions plafonnent à 1 Mo par défaut — trop peu pour l'import d'images
    // (barre d'outils Markdown), qui uploade le fichier via une Server Action.
    serverActions: {
      bodySizeLimit: "10mb",
    },
  },
  images: {
    remotePatterns: supabaseHostname
      ? [
          {
            protocol: "https",
            hostname: supabaseHostname,
            pathname: "/storage/v1/object/public/**",
          },
        ]
      : [],
  },
};

export default nextConfig;
