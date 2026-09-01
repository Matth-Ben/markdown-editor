import { type NextRequest } from "next/server";
import { updateSession } from "@/lib/supabase/middleware";

export async function proxy(request: NextRequest) {
  return updateSession(request);
}

export const config = {
  // .well-known exclu : liens universels app mobile (assetlinks.json,
  // apple-app-site-association), doivent rester accessibles publiquement,
  // sans passer par la vérification de session — voir DEEP_LINKING_SETUP.md.
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|\\.well-known|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
