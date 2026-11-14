#!/usr/bin/env python3
"""Génère rls_matrix.sql : matrice « qui voit / modifie / supprime / insère quoi », par profil.

Usage (Postgres jetable, schéma rejoué) :
  python gen_rls_matrix.py > rls_matrix.sql
  psql -X -d <base_avant> -f rls_matrix.sql > avant.txt 2>&1   # puis idem sur <base_apres>
  diff avant.txt apres.txt   -> doit être vide : mêmes lignes visibles/modifiables avant et après.
Tout est exécuté dans une transaction annulée (rollback) : aucune donnée ne persiste.
"""
U = {
    "A": "a0000000-0000-4000-8000-00000000000a",  # propriétaire de cA, membre du groupe g1
    "B": "a0000000-0000-4000-8000-00000000000b",  # membre du groupe g1 (équipier de A)
    "C": "a0000000-0000-4000-8000-00000000000c",  # MJ propriétaire de g1 (sans personnage)
    "D": "a0000000-0000-4000-8000-00000000000d",  # tiers : propriétaire de g2, sans lien avec g1
    "E": "a0000000-0000-4000-8000-00000000000e",  # connecté sans aucune donnée
}
G1 = "b0000000-0000-4000-8000-000000000001"
G2 = "b0000000-0000-4000-8000-000000000002"
CA, CB, CD = ("c0000000-0000-4000-8000-00000000000%s" % x for x in "abd")

out = []
w = out.append
w("\\set ON_ERROR_STOP off")
w("begin;")
for k, v in U.items():
    w("insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at) values "
      "('%s', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'matrix-%s@test.local', now(), now());" % (v, k.lower()))
w("insert into public.characters (id, owner_id, name) values ('%s', '%s', 'cA'), ('%s', '%s', 'cB'), ('%s', '%s', 'cD');" % (CA, U["A"], CB, U["B"], CD, U["D"]))
w("insert into public.groups (id, name, owner_id, invite_code) values ('%s', 'g1', '%s', 'MATRIX01'), ('%s', 'g2', '%s', 'MATRIX02');" % (G1, U["C"], G2, U["D"]))
w("insert into public.group_members (group_id, user_id, character_id, role) values ('%s', '%s', '%s', 'membre'), ('%s', '%s', '%s', 'membre'), ('%s', '%s', '%s', 'membre') on conflict do nothing;"
  % (G1, U["A"], CA, G1, U["B"], CB, G2, U["D"], CD))
w("insert into public.group_treasure (group_id) values ('%s'), ('%s') on conflict do nothing;" % (G1, G2))
w("insert into public.group_notes (group_id, user_id, character_id, body) values ('%s', '%s', '%s', 'na'), ('%s', '%s', '%s', 'nb'), ('%s', '%s', '%s', 'nd');"
  % (G1, U["A"], CA, G1, U["B"], CB, G2, U["D"], CD))
w("insert into public.group_journal_entries (group_id, user_id, body) values ('%s', '%s', 'ja'), ('%s', '%s', 'jb'), ('%s', '%s', 'jd');"
  % (G1, U["A"], G1, U["B"], G2, U["D"]))
w("insert into public.bug_reports (reporter_id, title, description, severity) values ('%s', 'ta', 'da', 'mineur'), ('%s', 'td', 'dd', 'mineur');" % (U["A"], U["D"]))
w("insert into public.notification_preferences (user_id) values ('%s'), ('%s');" % (U["A"], U["D"]))
w("insert into public.user_push_tokens (token, user_id, platform) values ('tok-a', '%s', 'android'), ('tok-d', '%s', 'ios');" % (U["A"], U["D"]))
w("insert into public.character_inventory (character_id, custom_name) values ('%s', 'ia'), ('%s', 'ib'), ('%s', 'id');" % (CA, CB, CD))
w("insert into public.character_spells (character_id, spell_id, status) select '%s'::uuid, min(id), 'connu' from public.spells union all select '%s'::uuid, min(id), 'connu' from public.spells;" % (CA, CD))
w("")

# table, clé de tri, UPDATE inoffensif, INSERT (placeholders {u} = utilisateur, {ch} = personnage) ou None
T = [
    ("characters", "id", "name = name || '!'",
     "insert into public.characters (owner_id, name) values ('{u}', 'nouveau')"),
    ("character_inventory", "custom_name", "custom_name = custom_name || '!'",
     "insert into public.character_inventory (character_id, custom_name) values ('{ch}', 'nouveau')"),
    ("character_spells", "character_id", "is_favorite = not is_favorite", None),
    ("groups", "name", "name = name || '!'",
     "insert into public.groups (name, owner_id, invite_code) values ('nouveau', '{u}', 'MX' || substr(md5(random()::text), 1, 6))"),
    ("group_members", "user_id", "role = role",
     "insert into public.group_members (group_id, user_id, role) values ('%s', '{u}', 'membre')" % G1),
    ("group_treasure", "group_id", "currency_gp = currency_gp + 1", None),
    ("group_notes", "body", "body = body || '!'",
     "insert into public.group_notes (group_id, user_id, body) values ('%s', '{u}', 'nouveau')" % G1),
    ("group_journal_entries", "body", "body = body || '!'",
     "insert into public.group_journal_entries (group_id, user_id, body) values ('%s', '{u}', 'nouveau')" % G1),
    ("bug_reports", "title", "title = title || '!'",
     "insert into public.bug_reports (reporter_id, title, description, severity) values ('{u}', 'n', 'n', 'mineur')"),
    ("notification_preferences", "user_id", "push_enabled = push_enabled",
     "insert into public.notification_preferences (user_id) values ('{u}')"),
    ("user_push_tokens", "token", "platform = platform",
     "insert into public.user_push_tokens (token, user_id, platform) values ('tok-' || md5(random()::text), '{u}', 'ios')"),
]
# colonne « propriétaire » de chaque table, pour les UPDATE de transfert de propriété (set <col> = <autre utilisateur>)
OWNER_COL = {"characters": "owner_id", "groups": "owner_id", "group_members": "user_id", "group_notes": "user_id",
             "group_journal_entries": "user_id", "bug_reports": "reporter_id", "user_push_tokens": "user_id",
             "notification_preferences": "user_id"}
OWN_CHAR = {"A": CA, "B": CB, "D": CD}  # personnage du profil (les autres n'en ont pas : on tente celui de A)
profiles = [("anon", None, "anon")] + [(k, v, "authenticated") for k, v in U.items()]
for name, uid, role in profiles:
    w("\\echo ##### profil %s" % name)
    w("set local role %s;" % role)
    if uid:
        w("select set_config('request.jwt.claims', '{\"sub\":\"%s\",\"role\":\"authenticated\"}', true) as claims \\gset" % uid)
    else:
        w("select set_config('request.jwt.claims', '', true) as claims \\gset")
    for tbl, key, upd, ins in T:
        w("\\echo -- %s" % tbl)
        w("select '%s' as t, count(*) as lignes, md5(coalesce(string_agg(%s::text, ',' order by %s::text), '')) as empreinte from public.%s;" % (tbl, key, key, tbl))
        w("savepoint s;"); w("update public.%s set %s;" % (tbl, upd)); w("rollback to savepoint s;")
        w("savepoint s;"); w("delete from public.%s;" % tbl); w("rollback to savepoint s;")
        if tbl in OWNER_COL:
            tgt = U["D"] if name != "D" else U["A"]
            w("\\echo transfert %s" % tbl)
            w("savepoint s;"); w("update public.%s set %s = '%s';" % (tbl, OWNER_COL[tbl], tgt)); w("rollback to savepoint s;")
        if ins:
            me = uid or "00000000-0000-0000-0000-000000000000"
            other = U["D"] if name != "D" else U["A"]
            for who, u, ch in (("soi", me, OWN_CHAR.get(name, CA)), ("autre", other, CD if name != "D" else CA)):
                w("\\echo insert %s pour %s" % (tbl, who))
                w("savepoint s;")
                w(ins.format(u=u, ch=ch) + ";")
                w("rollback to savepoint s;")
    w("reset role;")
w("rollback;")
print("\n".join(out))
