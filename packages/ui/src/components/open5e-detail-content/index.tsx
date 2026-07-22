"use client";

import { useEffect, useState } from "react";
import {
  getOpen5eDetail,
  type Open5eClassDetail,
  type Open5eCreatureDetail,
  type Open5eDetail,
  type Open5eItemDetail,
  type Open5eKind,
  type Open5eSpeciesDetail,
  type Open5eSpellDetail,
} from "@nexus/core";

export function Open5eDetailContent({ kind, entryKey }: { kind: Open5eKind; entryKey: string }) {
  const [detail, setDetail] = useState<Open5eDetail | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);
    setDetail(null);

    getOpen5eDetail<Open5eDetail>(kind, entryKey)
      .then((data) => {
        if (!cancelled) setDetail(data);
      })
      .catch(() => {
        if (!cancelled) setError("Impossible de récupérer les informations Open5e.");
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, [kind, entryKey]);

  if (loading) return <p className="text-xs text-muted">Chargement…</p>;
  if (error || !detail) return <p className="text-xs text-red-400">{error ?? "Aucune donnée."}</p>;

  switch (kind) {
    case "creatures":
      return <CreatureDetail detail={detail as Open5eCreatureDetail} />;
    case "spells":
      return <SpellDetail detail={detail as Open5eSpellDetail} />;
    case "classes":
      return <ClassDetail detail={detail as Open5eClassDetail} />;
    case "species":
      return <SpeciesDetail detail={detail as Open5eSpeciesDetail} />;
    default:
      return <ItemDetail detail={detail as Open5eItemDetail} />;
  }
}

function nameOf(value: { name: string } | string | undefined): string | undefined {
  return typeof value === "string" ? value : value?.name;
}

function Stat({ label, value }: { label: string; value: number | undefined }) {
  if (value === undefined) return null;
  return (
    <div className="rounded border border-white/10 bg-background p-1 text-center">
      <div className="text-[9px] uppercase text-muted">{label}</div>
      <div className="font-semibold text-foreground">{value}</div>
    </div>
  );
}

function CreatureDetail({ detail }: { detail: Open5eCreatureDetail }) {
  const type = nameOf(detail.type);
  const size = nameOf(detail.size);

  return (
    <div className="space-y-2 text-xs">
      <p className="text-sm font-semibold text-foreground">{detail.name}</p>
      <p className="text-muted">
        {[size, type].filter(Boolean).join(" ")}
        {detail.alignment ? ` · ${detail.alignment}` : ""}
      </p>

      <div className="grid grid-cols-3 gap-2">
        <Stat label="CA" value={detail.armor_class} />
        <Stat label="PV" value={detail.hit_points} />
        <Stat label="FP" value={detail.challenge_rating} />
      </div>

      {detail.ability_scores ? (
        <div className="grid grid-cols-6 gap-1">
          {Object.entries(detail.ability_scores).map(([key, value]) => (
            <div key={key} className="rounded border border-white/10 bg-background p-1 text-center">
              <div className="text-[9px] uppercase text-muted">{key.slice(0, 3)}</div>
              <div className="font-semibold text-foreground">{value}</div>
            </div>
          ))}
        </div>
      ) : null}

      {detail.traits && detail.traits.length > 0 ? (
        <div className="space-y-1">
          {detail.traits.map((trait) => (
            <p key={trait.name}>
              <span className="font-semibold text-foreground">{trait.name}.</span>{" "}
              <span className="text-muted">{trait.desc}</span>
            </p>
          ))}
        </div>
      ) : null}

      {detail.actions && detail.actions.length > 0 ? (
        <div className="space-y-1">
          <p className="font-semibold text-foreground">Actions</p>
          {detail.actions.map((action) => (
            <p key={action.name}>
              <span className="font-semibold text-foreground">{action.name}.</span>{" "}
              <span className="text-muted">{action.desc}</span>
            </p>
          ))}
        </div>
      ) : null}
    </div>
  );
}

function SpellDetail({ detail }: { detail: Open5eSpellDetail }) {
  const school = nameOf(detail.school);

  return (
    <div className="space-y-2 text-xs">
      <p className="text-sm font-semibold text-foreground">{detail.name}</p>
      <p className="text-muted">
        Niveau {detail.level ?? 0}
        {school ? ` · ${school}` : ""}
        {detail.ritual ? " · rituel" : ""}
      </p>
      <p className="text-muted">
        {[
          detail.casting_time ? `Incantation : ${detail.casting_time}` : null,
          detail.range_text ? `Portée : ${detail.range_text}` : null,
          detail.duration
            ? `Durée : ${detail.duration}${detail.concentration ? " (concentration)" : ""}`
            : null,
        ]
          .filter(Boolean)
          .join(" · ")}
      </p>
      {detail.desc ? <p className="text-foreground">{detail.desc}</p> : null}
      {detail.higher_level ? (
        <p className="text-muted">
          <span className="font-semibold">Aux niveaux supérieurs.</span> {detail.higher_level}
        </p>
      ) : null}
    </div>
  );
}

function ClassDetail({ detail }: { detail: Open5eClassDetail }) {
  return (
    <div className="space-y-2 text-xs">
      <p className="text-sm font-semibold text-foreground">{detail.name}</p>
      <p className="text-muted">
        {detail.subclass_of ? `Voie de ${detail.subclass_of.name}` : "Classe de base"}
        {detail.hit_dice ? ` · Dé de vie ${detail.hit_dice}` : ""}
        {detail.caster_type && detail.caster_type !== "NONE" ? ` · ${detail.caster_type}` : ""}
      </p>
      {detail.desc ? <p className="text-foreground">{detail.desc}</p> : null}
    </div>
  );
}

function SpeciesDetail({ detail }: { detail: Open5eSpeciesDetail }) {
  return (
    <div className="space-y-2 text-xs">
      <p className="text-sm font-semibold text-foreground">{detail.name}</p>
      {detail.is_subspecies ? <p className="text-muted">Sous-race</p> : null}
      {detail.desc ? <p className="text-foreground">{detail.desc}</p> : null}
      {detail.traits && detail.traits.length > 0 ? (
        <div className="space-y-1">
          {detail.traits.map((trait) => (
            <p key={trait.name}>
              <span className="font-semibold text-foreground">{trait.name}.</span>{" "}
              <span className="text-muted">{trait.desc}</span>
            </p>
          ))}
        </div>
      ) : null}
    </div>
  );
}

function ItemDetail({ detail }: { detail: Open5eItemDetail }) {
  const category = nameOf(detail.category);
  const rarity = nameOf(detail.rarity);

  return (
    <div className="space-y-2 text-xs">
      <p className="text-sm font-semibold text-foreground">{detail.name}</p>
      <p className="text-muted">
        {[category, rarity].filter(Boolean).join(" · ")}
        {detail.requires_attunement ? " · attunement requis" : ""}
      </p>
      {detail.desc ? <p className="text-foreground">{detail.desc}</p> : null}
    </div>
  );
}
