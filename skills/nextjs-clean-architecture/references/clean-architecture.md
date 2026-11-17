# Clean Architecture dans Next.js — exemples de code

Toutes les couches pour une feature « mairies ». Style du projet : alias `@/`, une classe = un fichier, un use case = `execute()`.

## 1. Domaine (`domain/service/`) — TypeScript pur

```ts
// domain/service/MairieSearchResult.ts
export interface MairieSearchResult {
  slug: string;
  nom: string;
  departementSlug: string;
}

// domain/service/MairieRepository.ts   ← le PORT
import type { MairieSearchResult } from './MairieSearchResult';

export interface MairieRepository {
  search(query: string, limit: number): Promise<MairieSearchResult[]>;
  countByDepartement(deptCode: string): Promise<number>;
}

// domain/service/errors/MairieNotFoundError.ts   ← erreur métier typée
export class MairieNotFoundError extends Error {
  constructor(public readonly slug: string) {
    super(`Mairie introuvable : ${slug}`);
    this.name = 'MairieNotFoundError';
  }
}
```

Règles : zéro import externe ; une règle métier pure (prix, statut, validation d'e-mail) devient une fonction ou une méthode du domaine, testable sans rien d'autre.

## 2. Application (`application/service/`) — orchestration

```ts
// application/service/SearchMairiesUseCase.ts
import type { MairieRepository } from '@/domain/service/MairieRepository';
import type { MairieSearchResult } from '@/domain/service/MairieSearchResult';

const MAX_LIMIT = 50;

export class SearchMairiesUseCase {
  constructor(private readonly mairies: MairieRepository) {}

  async execute(query: string, limit: number): Promise<MairieSearchResult[]> {
    const cleaned = query.trim();
    if (cleaned.length < 2) return [];
    return this.mairies.search(cleaned, Math.min(Math.max(limit, 1), MAX_LIMIT));
  }
}
```

Un use case : dépend d'**interfaces**, jamais d'une classe concrète ; pas de `Request`, `NextResponse`, `cookies()` ; retourne des données simples ou lève une erreur du domaine. Les bornes (`MAX_LIMIT`) sont une règle applicative : elles vivent ici, pas dans le route handler.

Si le temps ou l'aléa comptent (expiration de session, génération de token), injecter un port `Clock` / `TokenGenerator` plutôt que d'appeler `Date.now()` ou `crypto` dans le use case — c'est ce que font `SystemClock` et `WebCryptoSessionTokenGenerator`.

## 3. Infrastructure (`infrastructure/service/`) — l'ADAPTER

```ts
// infrastructure/service/PrismaMairieRepository.ts
import 'server-only';
import { prisma } from '@/lib/db';
import type { MairieRepository } from '@/domain/service/MairieRepository';
import type { MairieSearchResult } from '@/domain/service/MairieSearchResult';

export class PrismaMairieRepository implements MairieRepository {
  async search(query: string, limit: number): Promise<MairieSearchResult[]> {
    const rows = await prisma.mairie.findMany({
      where: { nom: { contains: query } },
      take: limit,
      select: { slug: true, nom: true, departement: { select: { slug: true } } },
    });
    return rows.map((row) => ({            // mapping ligne BDD → type du domaine
      slug: row.slug,
      nom: row.nom,
      departementSlug: row.departement.slug,
    }));
  }

  async countByDepartement(deptCode: string): Promise<number> {
    return prisma.mairie.count({ where: { departement: { code: deptCode } } });
  }
}
```

L'adapter **traduit** : les types Prisma/HTTP ne sortent jamais de ce fichier. `select` explicite → on ne ramène que les colonnes nécessaires. Un `HttpXxxRepository` (API externe) suit le même principe : le JSON de l'API est mappé vers le type du domaine (cf. `infrastructure/demande/apiMappings/`).

## 4. Composition root (`infrastructure/container/service.ts`)

```ts
import 'server-only';
import { SearchMairiesUseCase } from '@/application/service/SearchMairiesUseCase';
import { PrismaMairieRepository } from '@/infrastructure/service/PrismaMairieRepository';

const mairieRepository = new PrismaMairieRepository();

export const searchMairiesUseCase = new SearchMairiesUseCase(mairieRepository);
```

- **Seul endroit** qui connaît à la fois les use cases et les implémentations.
- Un fichier par contexte (`auth`, `payment`, `geographie`…) ; module-level singleton = simple et suffisant dans Next. Pas de conteneur DI à décorateurs.
- Pour changer de fournisseur (Mailjet → autre), on ne touche que l'adapter et cette ligne. `CompositeEmailSender` / `ConsoleEmailSender` montrent la valeur du port : l'e-mail est console en dev, réel en prod.

## 5. Présentation

**Page (Server Component)** — appelle le use case, pas la BDD :

```tsx
// app/annuaire-mairies/[dept]/page.tsx
import { notFound } from 'next/navigation';
import { findDepartementBySlugUseCase } from '@/infrastructure/container/geographie';

type Props = { params: Promise<{ dept: string }> };   // Next 15+ : params asynchrone

export default async function DepartementPage({ params }: Props) {
  const { dept } = await params;
  const departement = await findDepartementBySlugUseCase.execute(dept);
  if (!departement) notFound();
  return <DepartementView departement={departement} />;
}
```

**Route Handler** — mince : parse → use case → réponse. Rien d'autre.

```ts
// app/api/mairies/search/route.ts
import { NextResponse, type NextRequest } from 'next/server';
import { searchMairiesUseCase } from '@/infrastructure/container/service';

export async function GET(request: NextRequest) {
  const query = request.nextUrl.searchParams.get('q') ?? '';
  const limit = Number(request.nextUrl.searchParams.get('limit') ?? '10');

  const results = await searchMairiesUseCase.execute(query, limit);
  return NextResponse.json({ results }, { headers: { 'Cache-Control': 'no-store' } });
}
```

**Server Action** — mince aussi, et c'est un endpoint public (voir `nextjs-frontend.md` § Formulaires).

**Traduction des erreurs** — un seul module de présentation :

```ts
// lib/http/toErrorResponse.ts
import { NextResponse } from 'next/server';
import { MairieNotFoundError } from '@/domain/service/errors/MairieNotFoundError';
import { InvalidCredentialsError } from '@/domain/auth/errors/InvalidCredentialsError';

export function toErrorResponse(error: unknown): NextResponse {
  if (error instanceof MairieNotFoundError) return NextResponse.json({ error: 'not_found' }, { status: 404 });
  if (error instanceof InvalidCredentialsError) return NextResponse.json({ error: 'invalid_credentials' }, { status: 401 });
  console.error(error);                                     // inattendu : log serveur, message générique
  return NextResponse.json({ error: 'internal_error' }, { status: 500 });
}
```

Ne jamais renvoyer `error.message` brut d'une erreur inattendue (fuite d'information).

## 6. Frontières de données : entité ≠ DTO

Ne pas exposer l'entité telle quelle quand elle porte des champs sensibles.

```ts
// domain/auth/User.ts : entité complète (inclut passwordHash, phone, birthDate…)
// application/auth/UserProfile.ts : ce que l'UI a le droit de voir
export interface UserProfile {
  id: string;
  firstName: string;
  lastName: string;
  email: string;
}

export function toUserProfile(user: User): UserProfile {
  return { id: user.id, firstName: user.firstName, lastName: user.lastName, email: user.email };
}
```

Le use case consommé par la présentation (surtout via Server Action ou props de Client Component) renvoie `UserProfile`, pas `User`. Règle de Martin : à la frontière, la donnée a *« la forme la plus pratique pour le cercle intérieur »*, mais jamais une ligne de BDD brute.

## 7. Tester sans framework

```ts
// application/service/SearchMairiesUseCase.test.ts
import { SearchMairiesUseCase } from './SearchMairiesUseCase';
import type { MairieRepository } from '@/domain/service/MairieRepository';

class InMemoryMairieRepository implements MairieRepository {
  constructor(private readonly items = [{ slug: 'lyon', nom: 'Lyon', departementSlug: 'rhone' }]) {}
  search = async (q: string, limit: number) =>
    this.items.filter((m) => m.nom.toLowerCase().includes(q.toLowerCase())).slice(0, limit);
  countByDepartement = async () => this.items.length;
}

it('ignore les requêtes trop courtes', async () => {
  const useCase = new SearchMairiesUseCase(new InMemoryMairieRepository());
  expect(await useCase.execute('l', 10)).toEqual([]);
});
```

Pas de mock de module, pas de BDD, pas de Next : c'est le bénéfice mesurable de la Dependency Rule. (Runner au choix : Vitest ou Jest — utiliser celui du projet.)

## 8. Faire respecter la règle par l'outillage

Une convention non vérifiée se dégrade. Sans dépendance supplémentaire (ESLint flat config, `eslint.config.mjs`) :

```js
export default [
  // ...config Next existante
  {
    files: ['domain/**/*.{ts,tsx}'],
    rules: {
      'no-restricted-imports': ['error', {
        patterns: [{
          group: ['next', 'next/*', 'react', 'react-dom', '@prisma/*', '@/application/*', '@/infrastructure/*', '@/app/*', '@/components/*', '@/lib/*'],
          message: 'domain/ doit rester du TypeScript pur.',
        }],
      }],
    },
  },
  {
    files: ['application/**/*.{ts,tsx}'],
    rules: {
      'no-restricted-imports': ['error', {
        patterns: [{
          group: ['next', 'next/*', 'react', 'react-dom', '@prisma/*', '@/infrastructure/*', '@/app/*', '@/components/*'],
          message: 'application/ ne dépend que de domain/.',
        }],
      }],
    },
  },
  {
    files: ['components/**/*.{ts,tsx}', 'app/**/*.{ts,tsx}'],
    rules: {
      'no-restricted-imports': ['error', {
        patterns: [
          { group: ['@prisma/*', '@/lib/db'], message: 'Pas d\'accès BDD en présentation : passer par un use case.' },
          // tout @/infrastructure/... SAUF @/infrastructure/container/...
          { regex: '^@/infrastructure/(?!container/)', message: 'Passer par infrastructure/container.' },
        ],
      }],
    },
  },
];
```

**Testé** avec ESLint 9.39 : ce jeu de règles bloque `@/infrastructure/auth/PrismaUserRepository`, `@/lib/db` et `@prisma/client` dans `app/` et `components/`, accepte `@/infrastructure/container/auth`, et bloque `next`, `react` et `@/infrastructure/*` dans `domain/`.

Pièges :
- **Ne pas utiliser de négation extglob dans `group`** (ex. `'@/infrastructure/!(container)/**'`) : ce n'est pas de la syntaxe gitignore valide, la règle ne bloque alors **rien**, sans aucun message d'erreur. C'est pour ça que l'exclusion du `container` passe par `regex` (lookahead).
- Si un `route.ts` ou un fichier de `lib/` (ex. `lib/auth/current-user.ts`) a une raison légitime d'importer autre chose que le container, ne pas affaiblir la règle : déplacer cette logique dans un use case.
- Toujours tester une règle de frontière sur un import volontairement fautif avant de s'y fier. Pour un contrôle plus fin (cycles, graphe de dépendances), `dependency-cruiser` ou `eslint-plugin-boundaries` sont des options, à n'ajouter que si le besoin est réel.

## 9. Erreurs fréquentes

1. **Use case anémique qui ne fait que déléguer.** Acceptable pour une lecture simple (`CountMairiesByDepartementUseCase`) : il garde un point d'entrée unique et testable. Mais ne pas multiplier les couches de passe-plat au-delà.
2. **Interface qui copie la forme de Prisma.** Le port exprime un besoin métier (`findBySlug`), pas le schéma de table.
3. **Type Prisma généré importé dans `domain/`.** Le mapper dans l'adapter.
4. **Logique métier dans l'adapter** (calcul de prix dans le repository). Elle remonte dans le domaine.
5. **God container** : un `container/index.ts` unique de 500 lignes. Un fichier par contexte.
6. **Passer le `Request` / `NextRequest` à un use case.** Extraire les valeurs dans la présentation, passer des primitives.
7. **Mélanger deux approches d'accès aux données** dans un même projet (guide Next.js : en choisir une).

## Alternative plus légère : découpage par feature

Pour une application surtout visuelle avec peu de métier, un découpage par feature (inspiré de Feature-Sliced Design) peut suffire :

```
features/checkout/
  components/  hooks/  api.ts  types.ts  index.ts   ← API publique de la feature
shared/ui  shared/lib
app/                                                  ← routage, assemble les features
```

Règles : une feature n'importe pas une autre feature ; `shared/` n'importe ni `features/` ni `app/` ; on n'importe une feature que par son `index.ts`. Source : consensus de guides communautaires, **pas** une préconisation officielle Next.js. Les deux approches peuvent coexister : features côté UI, `domain/application/infrastructure` côté métier.
