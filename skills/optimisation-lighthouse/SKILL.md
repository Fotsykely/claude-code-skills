---
name: optimisation-lighthouse
description: Améliorer les scores Lighthouse (Performance ≥ 97 mobile et desktop, Accessibilité / Bonnes pratiques / SEO à 100) d'un site Next.js App Router. Méthode de mesure (médiane de 5 runs), checklist par métrique (TBT, LCP, FCP, CLS), chargement différé de GTM sans perdre le gclid, pièges déjà testés. À utiliser pour « score lighthouse », « pagespeed », « LCP », « TBT », « optimiser les performances d'une page ».
---

# Optimisation Lighthouse (Next.js App Router)

Objectif par défaut : **Performance ≥ 97 en mobile et en desktop**, 100 si possible ; Accessibilité, Bonnes pratiques et SEO à 100.

## 1. Les chiffres qui comptent (Lighthouse 13)

Poids : **TBT 30 · LCP 25 · CLS 25 · FCP 10 · SI 10**. L'INP ne compte pas. Les « insights » (legacy JavaScript, render blocking, image delivery…) ne sont **pas notés** : ne les corriger que s'ils font bouger une métrique.

Valeurs à tenir pour un score de 0,97 :

| Métrique | Mobile | Desktop |
|---|---|---|
| FCP | ≤ 1,42 s | ≤ 0,73 s |
| SI | ≤ 2,63 s | ≤ 1,01 s |
| LCP | ≤ 2,0 s | ≤ 0,87 s |
| TBT | ≤ 120 ms | ≤ 100 ms |
| CLS | ≤ 0,065 | ≤ 0,065 |

Le TBT pèse le plus : avec GTM et Google Ads, c'est presque toujours lui qui sépare 90 de 97 en mobile, puis le LCP.

## 2. Méthode

1. **Mesurer avant** (voir §3). Un seul run ne veut rien dire : médiane de 5.
2. **Diagnostiquer par métrique** dans le JSON du run médian : `bootup-time`, `mainthread-work-breakdown`, `third-party-summary`, `largest-contentful-paint-element`, `layout-shifts`, `unused-javascript`.
3. **Corriger par ordre d'impact** (§4), un commit par sujet.
4. **Re-mesurer** après chaque groupe de commits ; garder une optimisation seulement si la médiane s'améliore.

## 3. Mesurer correctement

- Toujours `next build && next start`, jamais `next dev`.
- Les variables `NEXT_PUBLIC_*` sont figées **au build** : les passer au `next build` (sinon GTM ne charge pas et les scores sont trop beaux). Ne pas lire `.env.local`.
- Réchauffer une fois avec `curl` (optimiseur d'images, encodage AVIF) avant le premier run.
- Script fourni : `~/.claude/skills/optimisation-lighthouse/scripts/lh-median.sh <url> [<url>…]` lance Lighthouse 13 cinq fois en mobile et en desktop et affiche la **médiane** par catégorie et par métrique. Les JSON restent dans `LH_OUT` (défaut : `./lh-results`).
- Un Mac rapide sous-estime le TBT par rapport à PageSpeed Insights : regarder `environment.benchmarkIndex` ; en cas de doute, vérifier la prod avec l'API PSI (`strategy=MOBILE` et `DESKTOP`, une catégorie par paramètre `category`).
- Isoler le coût de GTM : relancer avec `LH_EXTRA='--blocked-url-patterns=*googletagmanager.com*'`.

## 4. Checklist par métrique

### TBT (30 %)

- **Analytics différés** : GTM, gtag, Clarity ne se chargent qu'à la première interaction (`pointerdown`, `keydown`, `touchstart` — **pas `scroll`** : Lighthouse fait défiler la page) ou après un délai de secours (5 s). `dataLayer` et `gtag()` sont définis tout de suite, les événements sont mis en file.
- **Garde Google Ads** : si l'URL d'arrivée porte `gclid`, `gbraid` ou `wbraid`, charger GTM **immédiatement** (le Conversion Linker lit l'identifiant dans l'URL ; chargé après une navigation, l'attribution est perdue). Ne jamais différer un tag de conversion déclenché explicitement : le mettre en file.
- **Ne pas utiliser** `@next/third-parties` ni `strategy="lazyOnload"` pour ça : ils se déclenchent au chargement ou à l'hydratation, Lighthouse les voit.
- **`'use client'` aux feuilles** : une page statique sans interactivité ne doit pas être un composant client. Un composant serveur qui importe un composant client en `next/dynamic` ne le découpe pas : passer par un petit wrapper client.
- **Charger les SDK lourds (Stripe, Rapyd, libphonenumber…) uniquement sur les routes qui les utilisent**, jamais depuis le layout racine ni via un import statique transitif.
- **Dictionnaires i18n par langue** : le français en statique, les autres par `import()` au changement de langue. Quatre JSON importés dans un provider racine = ~90 Ko gzip sur chaque page.
- **Vérifier le contenu réel des bundles** : lister les chunks de `.next/static/chunks`, repérer les gros, retrouver qui les importe (`grep` sur le nom d'un module du chunk). Les imports de **valeur** là où un `import type` suffit entraînent des bibliothèques entières.

### LCP (25 %)

- **Une seule image LCP**, `fetchPriority="high"` (Next 16 : `priority` est déprécié au profit de `preload` ; `fetchPriority="high"` ou `loading="eager"` suffit le plus souvent). Jamais `preload` si l'image change selon la largeur d'écran.
- **`sizes` exact** sur chaque image : sans lui le navigateur suppose 100vw et télécharge trop gros.
- **Dimensions `width`/`height` conformes au vrai ratio** du fichier.
- **Direction artistique mobile/desktop** : `getImageProps` + `<picture>`, pas deux `<Image priority>` (les deux seraient préchargées).
- **Aucun préchargement concurrent** avant l'image LCP : polices inutilisées, logo en double, drapeaux d'un sélecteur fermé (`loading="lazy"`).
- Pas de `priority` sur une image sous la ligne de flottaison.
- Un LCP texte (`<h1>`) bat toujours un LCP image ; une illustration en SVG inline aussi.
- Ne pas convertir les sources en WebP à la main : `next/image` sert déjà du WebP/AVIF. Régler `images.formats: ['image/avif','image/webp']` ; chaque `quality` utilisée doit figurer dans `images.qualities` (Next 16 arrondit sinon).

### FCP / SI (10 % + 10 %)

- **`experimental.inlineCss: true`** (Tailwind 4 produit peu de CSS) : supprime la requête CSS bloquante. À **mesurer avec et sans** ; surveiller la taille du HTML.
- **Polices** : pile système (`Arial`/`system-ui`) quand le design le permet ; sinon une seule police variable via `next/font`, sous-ensemble `latin`. Ne jamais précharger une police que le corps n'utilise pas.
- **Rester statique** : pas de `cookies()`, `headers()` ni `searchParams` dans un layout ou une page de contenu ; lire la query côté client (`useSyncExternalStore`) et `<Suspense>` autour de `useSearchParams`, jamais autour de l'élément LCP.
- Peu d'effets coûteux à la peinture : `filter: blur()` large, `mix-blend-mode`, animations en boucle au chargement.

### CLS (25 %)

- Dimensions réelles sur les images, polices de secours calibrées (`next/font` le fait), pas de CSS injecté à l'exécution (FontAwesome sans `autoAddCss: false`), pas de contenu qui apparaît après hydratation au-dessus de la ligne de flottaison (`HydratedOnly`, bascule de langue).

### HTML / RSC

- Pas de grosse `key` React (ne jamais construire une clé avec les données d'un tracé SVG), icônes en SVG inline plutôt qu'en bibliothèque.
- Regarder le poids du flux RSC (`.next/server/app/**/*.rsc`) : une page qui sérialise toutes les langues double son poids.

## 5. Accessibilité (100)

Poids : 10 = bloquant (`button-name`, `label`, `select-name`, `image-alt`, ARIA invalide) ; 7 = `color-contrast`, `link-name`, `link-in-text-block`, `target-size`, `html-has-lang`, `list` ; 3 = `heading-order`, `landmark-one-main`.

Pièges fréquents :
- **Contraste** : 4,5:1 (texte normal), 3:1 (grand texte). `gray-400`/`slate-400` sur blanc échouent ; blanc sur rouge clair (`#F81216` = 4,13:1) aussi ; texte `xs` sur fond teinté. Vérifier avec un calcul de ratio, pas à l'œil.
- **Un seul `<main>`** par page : si le shell en pose un, les pages utilisent un `<div>`.
- Pas de `<button>` dans un `role="option"` ; pas de `role="table"` sans `cell` ; pas d'`aria-label` sur un `<div>` sans rôle.
- Un sélecteur personnalisé doit être atteignable au clavier : trigger `<button>`, `<label>` relié, champ de recherche avec `aria-label`.
- Cibles tactiles ≥ 24×24 px (liens de pied de page en `text-sm` avec peu d'espace).
- Titres sans saut de niveau ; `lang` correct (bloc anglais dans une page française : `lang="en"`).

## 6. Bonnes pratiques (100)

- `third-party-cookies` (poids 5) : cookies Google Ads / doubleclick ; si l'audit échoue, charger les tags Ads après consentement ou interaction.
- `errors-in-console` : toute `console.error` (hydratation, 404 favicon, fetch) fait échouer l'audit.
- `deprecations` : écouteurs `unload`, scripts tiers.
- `paste-preventing-inputs` : ne jamais bloquer le collage (confirmation d'e-mail).
- `image-aspect-ratio` / `image-size-responsive` : dimensions au bon ratio, assez de pixels pour DPR 1,75.
- CSP, HSTS, COOP ne sont pas notés ; utiles mais sans effet sur le score.

## 7. SEO (100)

- Métadonnées dans le `<head>` : sur une route dynamique, `generateMetadata` peut être streamé dans le `<body>` et Lighthouse ne le voit pas. Garder les pages de contenu statiques.
- Canonical absolu (`metadataBase`), hreflang valides, `robots.txt` valide, aucune page de test en `noindex`.
- `link-text` : pas de « en savoir plus », « ici », « more », « click here » (texte visible, `aria-label` ignoré ; les pages anglaises sont vérifiées).
- `crawlable-anchors` : pas de `javascript:void(0)`, `href=""` ni `<a onClick>` sans `href`.
- Une page d'entrée qui répond par une redirection 307 : utiliser `permanentRedirect` (308) et ne pas la lister dans le sitemap.

## 8. Pièges déjà testés (ne pas refaire)

- **CSS asynchrone** (`media="print" onload`) : CLS 0,105 → garder la feuille bloquante.
- **`rel=preload as=style`** : FCP +266 ms.
- **Partytown** dans l'App Router : fragile, dernier recours.
- **`@next/third-parties`** : ne diffère rien, ne règle pas le TBT de GTM.
- **Changer `browserslist`** : n'enlève pas le `polyfill-module` de Next (≈ 1,4 Ko) ; l'insight « Legacy JavaScript » n'est pas noté, l'ignorer.
- **`decoding="async"`** sur l'image LCP : à retirer.
- **`reactCompiler`** : améliore l'INP, pas le TBT d'hydratation ; build plus lent.

## 8 bis. Ce que les mesures ont appris (form-admin)

- **Un fichier « baril » qui importe un gros JSON ou un registre embarque tout chez chaque importeur**, même pour une seule constante. `i18n/index.ts` importait le dictionnaire français : `LanguageProvider` (layout racine) le tirait dans toutes les pages pour lire `LANG_URL_PARAM`. Séparer les petites choses pures (types, constantes, helpers d'URL) dans leur propre fichier. Vérifier avec le manifeste `.next/server/app/<route>/page_client-reference-manifest.js` (quel module arrive dans quel chunk) et un `grep` d'une chaîne du dictionnaire dans les chunks de la page.
- **Le LCP simulé de Lighthouse compte les octets chargés avant lui** (≈ 370 Ko, dont ≈ 190 Ko de JS, donnent ≈ 2,8 s en mobile ; 50 Ko de JS ≈ 250 ms). Il bascule entre deux valeurs (≈ 1,9 s et ≈ 3,0 s) pour un contenu identique : comparer les octets, pas un seul run, et confirmer sur PageSpeed après déploiement (localhost est en HTTP/1.1, optimiste).
- **Les cookies tiers de Clarity et de doubleclick faisaient seuls passer Bonnes pratiques de 100 à 77** ; les différer à l'interaction les enlève du rapport.
- **Favicon `.ico` en BMP 32 bits** : 15 Ko, demandé à chaque page. Le réenregistrer en entrées PNG (Pillow : `save(..., format="ICO", bitmap_format="png")`) donne ≈ 6 Ko, mêmes tailles.
- Un score de Bonnes pratiques qui tombe sur un seul run (77 puis 100) est un accident de mesure : refaire 3 runs avant de chercher une cause.
- `sed` sur macOS n'a pas `\b` : utiliser Python ou un motif sans bornes de mot. `python3 -I` n'a pas Pillow : lancer un script sans `-I` depuis le dossier temporaire.
- Garder les JSON de mesure dans un dossier qui ne se nettoie pas : le dossier temporaire de la session peut être vidé.
