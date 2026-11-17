# Next.js App Router — bonnes pratiques front-end

Basé sur la documentation officielle (project structure, data security, Next 16). Pour toute API dont la signature a pu changer, **la doc embarquée `node_modules/next/dist/docs/` fait foi**.

## 1. Conventions de fichiers (dans un segment de route)

| Fichier | Rôle |
|---|---|
| `layout.tsx` | UI partagée, persistante à la navigation (header, nav, footer) |
| `page.tsx` | rend la route ; une route n'est publique que si `page` ou `route` existe |
| `loading.tsx` | squelette (frontière Suspense) |
| `error.tsx` | frontière d'erreur (Client Component) ; `global-error.tsx` pour le layout racine |
| `not-found.tsx` | UI 404 ; déclenchée par `notFound()` |
| `route.ts` | endpoint HTTP (pas de `page` dans le même segment) |
| `template.tsx` | comme `layout` mais remonté à chaque navigation |
| `default.tsx` | repli d'une parallel route ; obligatoire pour chaque slot `@x` en Next 16 |

Ordre d'imbrication : `layout` → `template` → `error` → `loading` → `not-found` → `page`.

Segments : `[slug]`, `[...slug]`, `[[...slug]]`. Dossiers spéciaux : `(groupe)` (hors URL), `_prive` (hors routage), `@slot` (parallel routes), `(.)x` / `(..)x` (intercepting routes, ex. modale).

Fichiers de métadonnées : `sitemap.ts`, `robots.ts`, `icon`, `apple-icon`, `opengraph-image`, `twitter-image`.

Fichiers racine : `next.config.ts`, `proxy.ts` (ex-`middleware.ts`), `instrumentation.ts`, `.env*` (jamais versionnés avec des secrets), `public/`, `src/` optionnel.

## 2. Server ou Client ? Arbre de décision

Le composant a-t-il besoin de…
- `useState` / `useReducer` / `useEffect` / `useRef` sur le DOM ? → **Client**
- `onClick`, `onChange`, `onSubmit` côté navigateur ? → **Client** (mais un `<form action={serverAction}>` fonctionne sans JS client)
- `window`, `localStorage`, `IntersectionObserver` ? → **Client**
- une lib qui utilise ces API (carrousel, carte, éditeur) ? → **Client**, isolé dans un wrapper
- seulement afficher des données, lire cookies/headers, appeler un use case ? → **Server**

Patterns :
- **Îlot interactif** : la page (serveur) charge les données et passe des props sérialisables simples à un petit composant client.
- **`children` en slot** : un `<ClientProvider>` ou `<Modal>` client reçoit des Server Components en `children` ; ils restent rendus côté serveur.
- **Provider au plus bas** : un `ThemeProvider` / `QueryClientProvider` se met dans un composant client dédié, monté dans le layout, pas autour de toute la logique.
- **Props sérialisables** : pas de fonctions (sauf Server Actions), pas de classes, pas de `Date` non voulue ; les données sensibles ne sont jamais passées.
- Après `'use client'`, tout ce qui est importé dans ce fichier devient bundle client : surveiller le poids des imports.

## 3. Charger les données

```tsx
export default async function Page({ params }: { params: Promise<{ dept: string }> }) {
  const { dept } = await params;

  // indépendantes → en parallèle, pas en cascade
  const [departement, stats] = await Promise.all([
    getDepartementUseCase.execute(dept),
    getMairieCountsUseCase.execute(),
  ]);
  // …
}
```

- **Cascade (waterfall)** : deux `await` successifs sans dépendance = latence doublée. `Promise.all`.
- **Streaming** : isoler la partie lente dans un composant async enveloppé de `<Suspense fallback={…}>` ; le reste s'affiche tout de suite.
- **Dédoublonnage par requête** : `React.cache(fn)` pour une lecture utilisée à plusieurs endroits du même rendu (`getCurrentUser`). `fetch` identique est dédoublonné automatiquement.
- **Statique vs dynamique** : lire `cookies()`/`headers()`/`searchParams` rend le segment dynamique. Garder les pages SEO statiques ou en cache quand le contenu le permet ; isoler la partie dynamique.
- **`generateStaticParams`** pour pré-rendre les routes dynamiques connues (communes, départements).
- Pas de `useEffect` + `fetch` pour les données initiales. Côté client, réserver cela aux données déclenchées par l'utilisateur (recherche au clavier, auto-complétion) ; utiliser un `route.ts` mince ou une Server Action.

## 4. Cache (Next 16, mode Cache Components)

- Activation : `cacheComponents: true` dans `next.config.ts`. **Tout est dynamique par défaut ; le cache est opt-in** via la directive `'use cache'` (page, composant ou fonction).
- Invalidation :
  - `revalidateTag(tag, 'max')` — le 2ᵉ argument (profil `cacheLife`) est maintenant attendu ; la forme à un seul argument est dépréciée.
  - `updateTag(tag)` — **Server Actions uniquement** : « read-your-writes », la donnée est fraîche dans la même requête.
  - `refresh()` — Server Actions uniquement : rafraîchit les données **non cachées**, ne touche pas au cache.
- Les détails (`cacheLife`, `cacheTag`, profils) : lire la doc embarquée avant d'écrire, ne pas les deviner.
- Si `cacheComponents` n'est pas activé, le projet suit les règles de cache de sa version : vérifier dans `next.config.ts` avant de supposer.

## 5. Formulaires et Server Actions

Pattern recommandé : action **mince**, use case pour le métier, état renvoyé via `useActionState` (React 19).

```ts
// app/contact/actions.ts
'use server';

import { getCurrentUser } from '@/lib/auth/current-user';
import { sendContactMessageUseCase } from '@/infrastructure/container/contact';

export type ContactState =
  | { status: 'idle' }
  | { status: 'error'; fieldErrors?: Record<string, string>; message?: string }
  | { status: 'success' };

export async function sendContactMessage(_prev: ContactState, formData: FormData): Promise<ContactState> {
  // 1. valider les entrées (Zod si présent dans le projet, sinon validation typée manuelle)
  const email = String(formData.get('email') ?? '').trim();
  const message = String(formData.get('message') ?? '').trim();
  if (!email.includes('@')) return { status: 'error', fieldErrors: { email: 'E-mail invalide' } };
  if (message.length < 10) return { status: 'error', fieldErrors: { message: 'Message trop court' } };

  // 2. (si la ressource est protégée) ré-authentifier + vérifier la propriété
  // const user = await getCurrentUser(); if (!user) return { status: 'error', message: 'Non connecté' };

  // 3. use case
  await sendContactMessageUseCase.execute({ email, message });

  // 4. retour minimal
  return { status: 'success' };
}
```

```tsx
// app/contact/ContactForm.tsx
'use client';
import { useActionState } from 'react';
import { sendContactMessage, type ContactState } from './actions';

const initialState: ContactState = { status: 'idle' };

export function ContactForm() {
  const [state, formAction, pending] = useActionState(sendContactMessage, initialState);
  return (
    <form action={formAction}>
      {/* champs avec <label htmlFor>, aria-invalid et aria-describedby sur les erreurs */}
      <button type="submit" disabled={pending}>{pending ? 'Envoi…' : 'Envoyer'}</button>
      {state.status === 'error' && state.message && <p role="alert">{state.message}</p>}
    </form>
  );
}
```

Points de sécurité (doc officielle) :
- Les actions exportées sont **atteignables par POST direct** même si aucune UI ne les appelle ; un check dans la page ne couvre pas l'action.
- Les variables capturées par une closure sont chiffrées par Next.js, mais la doc déconseille de s'y fier : ne pas capturer de valeur sensible.
- Protection CSRF : POST uniquement, cookies `SameSite`, comparaison `Origin`/`Host` ; derrière un proxy, configurer `serverActions.allowedOrigins`.
- Un fichier `'use server'` n'exporte que des fonctions asynchrones.
- Rate limiting sur login, e-mails, paiement.

## 6. Structure d'un projet (3 stratégies officielles)

1. **Code hors de `app/`** : `app/` = routage seul, tout le reste dans des dossiers racine (`components/`, `lib/`, `domain/`…).
2. **Code dans des dossiers de premier niveau de `app/`** : `app/_components`, `app/_lib`.
3. **Découpage par feature/route** : le partagé à la racine d'`app/`, le spécifique dans le segment qui l'utilise (`_components/` privé).

Recommandation pour un site avec backend et couches : **1 + 3** (voir `SKILL.md` § 3). Avec `src/` : tout le code applicatif sous `src/`, config à la racine ; choisir une fois, ne pas mélanger.

## 7. Métadonnées et SEO

- `export const metadata` (statique) ou `generateMetadata({ params })` (dynamique, `await params`).
- Toujours : `title`, `description`, `alternates.canonical` (+ `languages` pour hreflang), `openGraph`.
- JSON-LD : un `<script type="application/ld+json">` rendu côté serveur, objet typé construit par une fonction pure.
- `sitemap.ts` et `robots.ts` générés ; `notFound()` pour les slugs inconnus (vrai 404, pas une page vide en 200).
- Pages utilitaires à ne pas indexer : `robots: { index: false }` dans les métadonnées de la page **et** exclusion dans `robots.ts` (ce n'est pas un contrôle d'accès).
- Un seul `<h1>` par page, hiérarchie de titres continue.

## 8. Performance (sans dupliquer le skill Lighthouse)

- `next/image` avec `width`/`height` (ou `fill` + `sizes`) ; `priority` uniquement sur l'image LCP. `images.remotePatterns` (et non `domains`, déprécié).
- `next/font` : polices auto-hébergées, `display: 'swap'`, sous-ensembles limités.
- `next/dynamic` / `React.lazy` pour les gros composants clients non critiques (carte, éditeur, modale).
- `next/script` avec `strategy="lazyOnload"` ou `afterInteractive` pour tiers ; jamais de `<script>` bloquant.
- Éviter les gros imports côté client (dates, icônes complètes) : imports nommés ciblés.
- Pour les scores Lighthouse / TBT / LCP, utiliser le skill `optimisation-lighthouse`.

## 9. Accessibilité

- Éléments sémantiques (`<button>`, `<nav>`, `<main>`, `<label>`), pas de `div onClick`.
- Chaque champ a un `<label>` associé ; erreurs liées via `aria-describedby`, annoncées (`role="alert"`).
- Focus visible, navigation clavier complète, ordre de tabulation logique, piège de focus dans les modales.
- `alt` pertinent (ou `alt=""` si décoratif). Contraste ≥ 4,5:1.
- Respecter `prefers-reduced-motion`.

## 10. Variables d'environnement

- Serveur par défaut. Seules les variables `NEXT_PUBLIC_*` sont inlinées dans le bundle navigateur → aucune clé secrète là.
- Lire les secrets dans `infrastructure/` uniquement ; valider au démarrage (variable manquante = erreur claire).
- `.env.local` jamais committé ; fournir un `.env.example` sans valeurs.
- `serverRuntimeConfig` / `publicRuntimeConfig` sont supprimés en Next 16 : utiliser les variables d'environnement.

## 11. Gestion des erreurs côté UI

- `error.tsx` (Client Component, reçoit `error` et `reset`) par section critique ; message utilisateur sobre, pas de stack.
- `not-found.tsx` + `notFound()` pour les ressources absentes.
- Erreurs **attendues** (validation, conflit) : valeur de retour typée de l'action, pas d'exception. Erreurs **inattendues** : exception → `error.tsx` + log serveur.

## 12. Ce que Next 16 change (rappel)

Fait (source : notes de version Next.js 16) : Turbopack par défaut ; `proxy.ts` remplace `middleware.ts` ; API de requête asynchrones (`params`, `searchParams`, `cookies()`, `headers()`, `draftMode()`) ; `cacheComponents` remplace `experimental.ppr`/`dynamicIO` ; React Compiler stable mais **non activé par défaut** (`reactCompiler: true` + `babel-plugin-react-compiler`) ; `next lint` supprimé ; support AMP supprimé ; `next/legacy/image` déprécié ; `images.domains` déprécié ; Node ≥ 20.9, TypeScript ≥ 5.1.

Si le projet est sur une version antérieure (14/15), certaines API diffèrent (ex. `params` synchrone en 14) : toujours confirmer la version dans `package.json`.
