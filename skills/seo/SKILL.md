---
name: seo
description: SEO technique d'un site web, quelle que soit la stack (Next.js aujourd'hui, PHP possible demain) — métadonnées par page (title, description, canonical, Open Graph, Twitter card), sitemap.xml, robots.txt, pages non listées / noindex, JSON-LD (WebSite, Organization, BreadcrumbList, FAQPage), images OG. À utiliser pour « SEO », « sitemap », « robots.txt », « noindex », « JSON-LD », « données structurées », « Open Graph », « twitter card », « canonical », « ajouter une page indexable », ou avant de créer/modifier une page publique.
---

# SEO technique

**Priorité** : `CLAUDE.md` / `AGENTS.md` du projet > ce skill. Les principes ci-dessous valent pour toute stack ; l'implémentation est dans `references/`.

## Choisir la référence

| Stack du projet | Lire |
|---|---|
| Next.js (App Router) : `next` dans `package.json`, dossier `app/` | `references/nextjs.md` |
| PHP | `references/php.md` (à écrire au premier projet PHP, à partir des principes ci-dessous) |

Une stack sans référence : appliquer les principes, puis créer `references/<stack>.md` avec ce qui a été fait.

## Principes (toutes stacks)

1. **Une source de vérité par sujet** : un seul helper produit les métadonnées de chaque page, une seule liste de chemins exclus alimente à la fois le sitemap, robots.txt et les `noindex`. Jamais de chemin en dur à trois endroits.
2. **Métadonnées par page** : `title`, `description`, URL canonique (absolue, sans paramètres), `og:title`, `og:description`, `og:type`, `twitter:card`. La base du site (`https://…`) est définie une seule fois.
3. **Sitemap** : uniquement les URL indexables et qui répondent 200 ; dérivé du contenu réel (jamais une liste recopiée à la main pour les pages dynamiques) ; pas de `lastmod` inventé (`now()` ment aux crawlers) ; `changefreq` et `priority` sont ignorés par Google. Référencé dans robots.txt (`Sitemap: …`).
4. **Exclure une page** (légale, privée, merci, non listée) : la retirer du sitemap, mettre `noindex, nofollow` dans ses métadonnées, la lister dans la liste d'exclusion. Ce n'est jamais un contrôle d'accès.
   - Piège : un `Disallow` dans robots.txt empêche Google de lire le `noindex`. L'URL peut alors rester listée, sans extrait, si elle est liée ailleurs. Pour qu'une page disparaisse vraiment : `noindex` seul, sans `Disallow`.
5. **Open Graph / Twitter** : sans `og:image` / `twitter:image`, `summary_large_image` s'affiche vide ou dégradé. Image 1200×630. Penser aussi à `og:url`, `og:site_name`, `og:locale`. X reprend `og:*` en repli : `twitter:title` explicite est facultatif.
6. **JSON-LD** : `<script type="application/ld+json">` rendu côté serveur, `<` échappé en `<` dans le JSON (XSS). Le balisage doit refléter exactement le contenu visible. Contenu bilingue : la langue servie par défaut (français).
   - Valeur réelle : `WebSite` + `Organization` (accueil), `BreadcrumbList` (pages profondes), `Article` / `TouristDestination` (fiches).
   - `FAQPage` : valide, mais depuis 2023 Google ne montre le rich result FAQ que pour les sites gouvernementaux et de santé. À ajouter pour les autres moteurs et l'IA, sans en attendre d'effet dans Google.
7. **Vérifier le résultat réel, pas le code** : ouvrir `/sitemap.xml` et `/robots.txt` générés, inspecter le `<head>` d'une page, valider le JSON-LD (Rich Results Test, validator.schema.org).

## Ajouter une page publique (checklist)

- Métadonnées via le helper du projet, canonique correcte.
- Ajoutée au sitemap (ou dérivée du contenu si dynamique).
- Slug inconnu : 404 réelle, y compris dans la génération des métadonnées.
- Si elle ne doit pas être indexée : liste d'exclusion + `noindex`.
- Tests du sitemap et de robots verts.
