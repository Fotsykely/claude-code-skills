---
name: nextjs-clean-architecture
description: Architecture et qualité de code pour un front-end Next.js (App Router) — Clean Architecture (domain / application / infrastructure / présentation, Dependency Rule), organisation des dossiers, Server vs Client Components, accès aux données et sécurité (Server Actions, server-only, DTO), Clean Code TypeScript/React. À utiliser pour « architecture Next.js », « clean architecture », « clean code », « structurer le projet », « où mettre ce fichier », « ajouter une feature », « refactorer », « revue de code », ou avant de créer un use case, un repository, un route handler, une server action ou un composant.
---

# Next.js — Clean Architecture & Clean Code

Synthèse de la recherche (sources en bas) adaptée à une convention en couches : `domain/ → application/ → infrastructure/ (+ container/) → app/`.

**Priorité des règles** : `CLAUDE.md` / `AGENTS.md` du projet > ce skill > habitudes générales. Si le projet a déjà une convention, la suivre ; la doc Next.js le dit elle-même : *« choose a strategy that works for you and your team and be consistent »*.

Détails et exemples de code : `references/clean-architecture.md`, `references/nextjs-frontend.md`, `references/clean-code.md`. Les lire seulement quand le sujet est concerné.

## 0. Avant d'écrire du code

1. Lire `package.json` (versions de `next`, `react`) et le `CLAUDE.md` du projet.
2. Si `AGENTS.md` demande de lire `node_modules/next/dist/docs/` : le faire. C'est la source de vérité pour la version installée, plus fiable que la mémoire.
3. `ls` les dossiers existants et copier la structure en place (nommage, alias `@/`, un fichier = un use case).
4. Rappels Next 16 (à confirmer dans la doc embarquée) :
   - `params`, `searchParams`, `cookies()`, `headers()`, `draftMode()` sont **asynchrones** : `await`.
   - `middleware.ts` → `proxy.ts` (fonction exportée `proxy`, runtime Node.js).
   - Cache opt-in : `cacheComponents: true` + directive `'use cache'` ; `revalidateTag(tag, profile)` prend un 2ᵉ argument ; `updateTag()` / `refresh()` réservés aux Server Actions.
   - `next lint` supprimé → ESLint ou Biome directement. Node ≥ 20.9, TypeScript ≥ 5.1.

## 1. Le modèle : la Dependency Rule

> « Les dépendances de code source ne peuvent pointer que vers l'intérieur. Rien dans un cercle intérieur ne peut connaître quoi que ce soit d'un cercle extérieur. » — R. C. Martin

```
 app/ components/        présentation (pages, route handlers, server actions, UI)
        │
        ▼
 infrastructure/container   composition root : instancie adapters + use cases
        │            │
        ▼            ▼
 infrastructure/   application/   ──►  domain/
 (Prisma, HTTP,    (use cases)         (entités, ports, erreurs, règles pures)
  Argon2, mail)        └────────────────►
```

| Couche | Dossier | Contient | Peut importer | Interdit |
|---|---|---|---|---|
| Domaine | `domain/` | entités, value objects, **interfaces de repository (ports)**, erreurs métier, règles pures | rien d'externe (TS pur) | `next/*`, `react`, Prisma, `fetch`, `process.env` |
| Application | `application/` | use cases (`XxxUseCase` : constructeur + `execute()`) | `domain/` | `next/*`, ORM, `infrastructure/`, `react` |
| Infrastructure | `infrastructure/` | adapters qui **implémentent** les ports, `container/` | `domain/`, `application/`, libs externes | `app/`, `components/` |
| Présentation | `app/`, `components/` | pages, layouts, `route.ts`, server actions, composants | use cases via `container`, types du domaine | accès BDD/API directs, logique métier |

Conséquences concrètes :
- Un **port** (interface) vit dans `domain/`, son **adapter** dans `infrastructure/` (`MairieRepository` → `PrismaMairieRepository`).
- Un use case reçoit ses dépendances **par le constructeur** (inversion de dépendance) → testable avec un faux repository en mémoire, sans BDD ni Next.
- Les données qui franchissent une frontière sont des **structures simples** (DTO / view models), jamais des lignes de BDD ni des entités avec des champs sensibles (« We don't want to cheat and pass Entities or Database rows »).
- Les **quatre cercles sont schématiques** : la règle de dépendance, elle, s'applique toujours.

## 2. Ajouter une feature (procédure)

1. **Domaine** : entité + interface repository + erreurs métier (`domain/<contexte>/`).
2. **Application** : un use case par intention (`GetMairieDetailUseCase`), petit, une méthode `execute()`.
3. **Infrastructure** : l'adapter (`PrismaXxxRepository`, `HttpXxxRepository`), puis câblage dans `infrastructure/container/<contexte>.ts`.
4. **Présentation** : page / route handler / server action qui appelle le use case exporté par le container.
5. **Erreurs** : le domaine lève une erreur typée ; la présentation la traduit (404, 401, message de formulaire).
6. **Test** : use case + faux repository ; pas de test qui exige une BDD pour vérifier une règle métier.
7. **Vérifier** : `npm run lint`, `npx tsc --noEmit`, `npm run build`.

Pas de feature backend ? (page statique, contenu éditorial) → section 8, ne pas fabriquer 4 couches pour rien.

## 3. Organisation des dossiers

Stratégie recommandée (la doc Next.js en propose trois ; celle-ci combine « code hors de `app/` » et « split par route ») :

```
app/                      routage uniquement + code propre à une route
  (marketing)/            route group : organise sans changer l'URL
  annuaire/
    page.tsx  layout.tsx  loading.tsx  error.tsx
    _components/          private folder : composants utilisés par cette route seule
  api/**/route.ts         présentation HTTP : parse → use case → réponse
components/               UI partagée entre routes (ui/, layout/, sections/)
domain/  application/  infrastructure/ (+ container/)
lib/                      utilitaires techniques transverses (slug, date, cookies de session)
public/                   assets statiques
```

Règles :
- Un dossier n'est routable que s'il contient `page` ou `route` : on peut colocaliser sans risque. `_dossier` = exclu du routage.
- `app/` ne contient pas de logique métier. `components/` n'importe jamais `infrastructure/`.
- Le code partagé n'importe jamais depuis `app/` (dépendance inversée = couplage circulaire).
- Un composant utilisé par 2+ routes remonte dans `components/` ; sinon il reste dans `_components/` de sa route.
- Alias `@/` unique, pas de `../../..` qui franchit une couche.

## 4. Server vs Client Components

- **Server Component par défaut.** `'use client'` seulement pour : état local, effets, handlers d'événements, API navigateur, hooks de lib client.
- Placer `'use client'` **le plus bas possible** (la feuille interactive : bouton, formulaire, carrousel), jamais sur une page entière pour un seul `onClick`.
- Un Server Component peut être passé en `children` / props d'un Client Component : garder la composition côté serveur.
- Les données se chargent **dans les Server Components** (appel direct d'un use case), pas dans un `useEffect` client. Requêtes indépendantes en parallèle (`Promise.all`), flux progressif via `loading.tsx` / `<Suspense>`.
- Props d'un Client Component = **type étroit** avec seulement les champs affichés, jamais l'entité complète.
- Pas de `useMemo` / `useCallback` par réflexe : mesurer d'abord ; avec React Compiler activé (`reactCompiler: true`), c'est largement inutile.

## 5. Données et sécurité (guide officiel Next.js « data security »)

La doc recommande, pour un nouveau projet, une **Data Access Layer** : bibliothèque interne, **server-only**, qui vérifie l'autorisation et renvoie des DTO minimaux. Dans cette architecture, ce rôle est tenu par `application/` + `container/`.

- `import 'server-only'` en tête des modules qui touchent secrets/BDD (`container/*`, adapters) : erreur de build si importés côté client.
- `process.env` des secrets lu **uniquement dans `infrastructure/`**. Seules les variables `NEXT_PUBLIC_*` atteignent le navigateur : n'y mettre aucun secret.
- **Toute Server Action exportée est un endpoint public** (POST direct possible, même sans bouton). Dans chaque action : (1) valider les entrées (`FormData`, params, `searchParams`), (2) **ré-authentifier**, (3) vérifier la **propriété** de la ressource (anti-IDOR), (4) appeler un use case, (5) ne renvoyer que ce que l'UI affiche.
- Garder `'use server'` **mince** : pas de logique métier dans l'action. Un fichier `'use server'` n'exporte que des fonctions async.
- Ne pas muter pendant le rendu (supprimer un cookie, écrire en BDD depuis un `page.tsx`) : passer par une Server Action.
- Traiter `[param]` et `searchParams` comme de l'**entrée utilisateur non fiable**.
- `route.ts` et `proxy.ts` : relire avec le plus d'attention (surface d'attaque directe).
- Limiter le débit des opérations coûteuses ou sensibles (login, envoi d'e-mail, paiement).

## 6. Clean Code — règles essentielles

(Exemples et contre-exemples : `references/clean-code.md`.)

- **Noms qui révèlent l'intention** : `findMairiesProches`, pas `getData2`. Prononçables, cherchables, une seule langue par couche (domaine en français métier si le projet le fait, code technique en anglais : rester cohérent).
- **Fonctions courtes, un seul niveau d'abstraction, une raison de changer.** Si on ne peut la nommer sans « et », la couper. ≤ 3 paramètres, sinon un objet typé.
- **Retours anticipés** (guard clauses) plutôt que `if` imbriqués.
- **Pas de nombre/chaîne magique** : constante nommée.
- **Commentaires** : uniquement pour un *pourquoi* non évident. Un commentaire qui explique le *quoi* = un nom à améliorer.
- **TypeScript strict** : pas de `any` (utiliser `unknown` + garde de type), pas de `as` pour faire taire le compilateur, unions discriminées pour les états (`{status:'loading'} | {status:'error', error} | …`), types dérivés (`Pick`, `z.infer`).
- **Valider aux frontières** (entrée HTTP, formulaire, réponse d'API externe), puis travailler avec des types fiables à l'intérieur.
- **Erreurs** : classes d'erreur métier typées, jamais `catch {}` muet, jamais de `null` renvoyé quand l'absence est une erreur ; un seul endroit traduit erreur → HTTP.
- **Immuabilité** et fonctions pures par défaut ; effets de bord isolés à la périphérie.
- **Composition plutôt qu'héritage** ; hooks custom (`useXxx`) pour extraire la logique d'un composant client ; composant = affichage.
- **Pas d'abstraction prématurée** : on code ce dont on a besoin. Dupliquer deux fois est acceptable, factoriser à la troisième (règle de trois). Une mauvaise abstraction coûte plus cher que la duplication.
- **Boy-scout** : laisser le fichier touché un peu plus propre, sans élargir le périmètre du changement.

## 7. Anti-patterns → correction

| Anti-pattern | Correction |
|---|---|
| `route.ts` / page qui appelle Prisma ou `fetch` vers une API externe | Port dans `domain/`, adapter dans `infrastructure/`, use case dans `application/` |
| Use case qui fait `new PrismaXxxRepository()` | Injection par constructeur ; instanciation seulement dans `container/` |
| `domain/` qui importe `next`, `@prisma/client`, `zod`, une lib | Retirer ; types TS purs, le mapping se fait dans l'adapter |
| Entité complète (avec `passwordHash`, téléphone…) renvoyée par une Server Action ou passée en props client | DTO / view model étroit ; mapper dans le use case ou la présentation |
| `'use client'` en haut d'une page entière | Descendre à la feuille interactive ; garder la page en Server Component |
| `useEffect` + `fetch` pour charger des données initiales | Charger dans le Server Component (use case) |
| Server Action avec logique métier et sans contrôle d'accès | Action mince : valider → authentifier → autoriser → use case |
| Secret lu dans un composant ou `NEXT_PUBLIC_SECRET…` | Lire dans `infrastructure/` uniquement, module `server-only` |
| Dossier `utils/` fourre-tout | Nommer par intention ; placer dans la couche concernée |
| Barrel `index.ts` partout | Imports directs ; un barrel ne se justifie qu'à une frontière publique de module |
| Une interface par classe « au cas où » | Port uniquement quand il y a une frontière à inverser (BDD, API, horloge, e-mail) |

## 8. Pragmatisme : quand NE PAS appliquer toute la structure

- Page 100 % statique ou éditoriale (FAQ, mentions légales, contenus SEO) : composants + données statiques typées (`lib/` ou `content/`). Aucun use case si aucune règle métier ni I/O.
- Prototype jetable : colocaliser, mais garder `server-only` et la validation des entrées.
- Projet existant sans couches : ne pas tout réécrire. Appliquer la structure aux **nouvelles** features et migrer au fil des modifications (boy-scout).
- Règle de décision : une couche se justifie quand elle protège une **frontière qui change** (BDD, fournisseur de paiement, API tierce) ou une **règle métier** à tester isolément.

## 9. Checklist de revue

Architecture
- [ ] Aucune dépendance sortante depuis `domain/` ni `application/` (grep `from 'next`, `@prisma`, `infrastructure`).
- [ ] Aucun accès BDD / API externe hors de `infrastructure/`.
- [ ] Nouveau use case câblé dans `container/`, dépendances par constructeur.
- [ ] Erreurs métier typées, traduites en un seul endroit.

Next.js
- [ ] `'use client'` seulement aux feuilles ; pas de données chargées côté client sans raison.
- [ ] Props client étroites ; aucun champ sensible sérialisé vers le navigateur.
- [ ] Server Actions : validation + ré-authentification + autorisation + retour minimal.
- [ ] `await params` / `await searchParams` / `await cookies()` (Next 15+).
- [ ] `loading.tsx` / `error.tsx` / `not-found.tsx` présents sur les routes qui chargent des données.
- [ ] Métadonnées (`metadata` / `generateMetadata`), `sitemap.ts`, `robots.ts` cohérents.

Code
- [ ] Noms explicites, fonctions courtes, retours anticipés, pas de `any`.
- [ ] Pas de code mort, de `console.log`, de TODO sans ticket.
- [ ] Lint, `tsc --noEmit` et build passent.

## Sources

- R. C. Martin, [The Clean Architecture (2012)](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html) ; livres *Clean Code* (2008) et *Clean Architecture* (2017).
- Next.js, [Project structure](https://nextjs.org/docs/app/getting-started/project-structure) (organisation « unopinionated », colocation, route groups, private folders).
- Next.js, [Data security](https://nextjs.org/docs/app/guides/data-security) (Data Access Layer, `server-only`, DTO, Server Actions).
- Next.js, [Next.js 16](https://nextjs.org/blog/next-16) (Cache Components, `proxy.ts`, API asynchrones, Turbopack, React Compiler).
