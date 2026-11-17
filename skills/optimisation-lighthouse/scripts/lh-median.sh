#!/usr/bin/env bash
# Lighthouse 13 : 5 runs par URL en mobile et en desktop, médiane par catégorie et par métrique.
# Usage : lh-median.sh <url> [<url>…]
# Variables : LH_RUNS (défaut 5), LH_OUT (défaut ./lh-results), LH_EXTRA (options Lighthouse supplémentaires).
# Prérequis : l'application tourne (next build && next start), Node ≥ 22.19, Chrome installé.
set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "Usage : $0 <url> [<url>…]" >&2
  exit 1
fi

RUNS="${LH_RUNS:-5}"
OUT="${LH_OUT:-./lh-results}"
EXTRA="${LH_EXTRA:-}"
mkdir -p "$OUT"

summarize() {
  node -e '
    const fs = require("fs");
    const files = process.argv.slice(1);
    const runs = files.map((f) => JSON.parse(fs.readFileSync(f, "utf8")));
    const perf = (r) => r.categories.performance.score;
    const sorted = [...runs].sort((a, b) => perf(a) - perf(b));
    const med = sorted[Math.floor(sorted.length / 2)];
    const pct = (s) => Math.round(s * 100);
    const cats = ["performance", "accessibility", "best-practices", "seo"]
      .map((c) => c.slice(0, 4) + " " + pct(med.categories[c].score)).join(" | ");
    const m = (id) => med.audits[id].displayValue || "-";
    const all = runs.map((r) => pct(perf(r))).join(",");
    console.log("  " + cats);
    console.log("  FCP " + m("first-contentful-paint") + " | LCP " + m("largest-contentful-paint")
      + " | TBT " + m("total-blocking-time") + " | CLS " + m("cumulative-layout-shift")
      + " | SI " + m("speed-index"));
    console.log("  perf des " + runs.length + " runs : " + all);
  ' "$@"
}

for url in "$@"; do
  slug="$(echo "$url" | sed -E 's#https?://##; s#[^A-Za-z0-9]+#_#g')"
  curl -s -o /dev/null "$url" || true # réchauffe l'optimiseur d'images
  for mode in mobile desktop; do
    preset=()
    [ "$mode" = "desktop" ] && preset=(--preset=desktop)
    files=()
    for i in $(seq 1 "$RUNS"); do
      f="$OUT/${slug}-${mode}-${i}.json"
      # shellcheck disable=SC2086
      npx --yes lighthouse@13 "$url" ${preset[@]+"${preset[@]}"} --quiet \
        --chrome-flags="--headless=new" \
        --only-categories=performance,accessibility,best-practices,seo \
        --output=json --output-path="$f" $EXTRA >/dev/null 2>&1
      files+=("$f")
    done
    echo "$url [$mode]"
    summarize "${files[@]}"
  done
done
