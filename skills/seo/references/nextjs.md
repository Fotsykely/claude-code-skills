# SEO — implémentation Next.js (App Router)

Les principes sont dans `../SKILL.md`. Next.js évolue : relire `node_modules/next/dist/docs/01-app/` avant d'écrire (`03-api-reference/03-file-conventions/01-metadata/sitemap.md` et `robots.md`, `02-guides/json-ld.md`, `04-functions/generate-metadata.md`).

## Les quatre sources de vérité

| Besoin | Où | Règle |
|---|---|---|
| Métadonnées d'une page | `lib/seo/pageMetadata.ts` → `pageMetadata({ path, title, description, ogTitle, ogDescription, ogType?, noIndex? })` | Toute page exporte `metadata` ou `generateMetadata` via ce helper, jamais un objet à la main. `metadataBase` n'est défini qu'une fois, dans `app/layout.tsx`. |
| Pages exclues | `lib/seo/unlistedPaths.ts` (`UNLISTED_PATHS`) | Une page exclue = `noIndex: true` **et** présente dans `UNLISTED_PATHS`. |
| `app/sitemap.ts` | Pages statiques + contenu (`content/`) filtrés par `UNLISTED_PATHS` | `MetadataRoute.Sitemap`, sans `lastModified` inventé. |
| `app/robots.ts` | `UNLISTED_PATHS` dans `disallow` + `sitemap: ${SITE_URL}/sitemap.xml` | Rien en dur : tout vient de `unlistedPaths.ts`. |

`pageMetadata` avec `noIndex: true` produit `noindex, nofollow, noarchive` pour tous les robots.

## Ajouter une page publique

1. Exporter les métadonnées via `pageMetadata` (`path` = chemin canonique, commence par `/`).
2. L'ajouter à `STATIC_PATHS` dans `app/sitemap.ts`, ou la dériver de `content/` si dynamique (`generateStaticParams` et sitemap lisent la même source).
3. Page dynamique : `notFound()` si le slug est inconnu, y compris dans `generateMetadata`.
4. `app/sitemap.test.ts` et `app/robots.test.ts` restent verts.

## Open Graph / Twitter

- Image : fichier `opengraph-image.(png|jpg|tsx)` dans le segment de route (hérité par les enfants). Ne pas mettre d'image par défaut dans le layout racine si les pages n'ont pas la leur : toutes l'hériteraient.

## JSON-LD

- Composant serveur `<JsonLd data={…} />` qui rend `<script type="application/ld+json">` avec `JSON.stringify(data).replace(/</g, "\\u003c")`. Balise `<script>` native, pas `next/script`.
- Pages rendues en français côté serveur : utiliser le `.fr` des `Localized`.

## Vérifier

```
npm run lint && npm run typecheck && npm test && npm run build
```

Puis lire `.next/server/app/sitemap.xml.body` et `.next/server/app/robots.txt.body`.
