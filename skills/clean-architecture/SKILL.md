---
name: clean-architecture
description: Clean Architecture indépendante du framework et du langage — Dependency Rule, couches domain / application / infrastructure / présentation, ports et adapters, use cases, composition root, DTO aux frontières, tester sans framework, faire respecter les frontières par l'outillage. À utiliser pour « clean architecture », « architecture hexagonale », « ports and adapters », « où mettre ce code », « structurer le projet », « ajouter une feature », « séparer la logique métier », « inversion de dépendance », « use case », « repository », ou avant de créer un module avec accès BDD/API tierce. Pour les règles d'écriture du code (noms, fonctions, erreurs) utiliser clean-code ; pour les spécificités Next.js utiliser nextjs-clean-architecture.
---

# Clean Architecture

Organiser le code pour que la **logique métier ne dépende ni du framework, ni de la base de données, ni d'un service tiers**. Valable pour TypeScript, PHP, Python, Java, Go… Exemples en TypeScript.

**Priorité** : `CLAUDE.md` / `AGENTS.md` du projet > ce skill. Si le projet a déjà une structure, la suivre et l'étendre ; ne pas en introduire une seconde.

Périmètre : découpage en couches et sens des dépendances. Pour le style du code à l'intérieur d'un fichier → `clean-code`. Pour Next.js (Server Components, Server Actions, `server-only`) → `nextjs-clean-architecture`.

## 1. La Dependency Rule

> « Les dépendances de code source ne peuvent pointer que vers l'intérieur. Rien dans un cercle intérieur ne peut connaître quoi que ce soit d'un cercle extérieur. » — R. C. Martin

```
 présentation   (HTTP, UI, CLI, jobs)            ─┐
 infrastructure (BDD, API tierce, e-mail, fichiers) ├──►  application ──► domain
 composition root (instancie et câble)           ─┘     (use cases)     (règles, ports)
```

| Couche | Contient | Peut importer | Interdit |
|---|---|---|---|
| **Domaine** | entités, value objects, règles pures, **interfaces (ports)**, erreurs métier | rien d'externe | framework, ORM, HTTP, variables d'environnement, horloge système |
| **Application** | use cases : une intention = une classe/fonction | domaine | framework, ORM, infrastructure, objets requête/réponse |
| **Infrastructure** | **adapters** qui implémentent les ports (SQL, HTTP, e-mail, cache) | domaine, application, libs externes | présentation |
| **Présentation** | contrôleurs, routes, pages, composants, commandes CLI | use cases (via la composition root), types du domaine | accès BDD/API directs, règles métier |
| **Composition root** | un seul endroit qui instancie adapters + use cases | tout | — |

Les cercles sont schématiques (3 ou 4 couches, peu importe) ; **la règle de dépendance, elle, s'applique toujours**.

## 2. Les trois mécanismes

1. **Port** : interface déclarée dans le domaine, exprimant un *besoin métier* (`findBySlug`), pas la forme de la table ou de l'API.
2. **Adapter** : classe d'infrastructure qui l'implémente et **traduit** (ligne SQL / JSON d'API → type du domaine). Les types de la lib ne sortent jamais de l'adapter.
3. **Injection par le constructeur** : un use case reçoit ses ports, ne fait jamais `new` d'un adapter. Seule la composition root connaît les implémentations.

```ts
// domain — port + erreur métier
export interface MairieRepository {
  search(query: string, limit: number): Promise<MairieSearchResult[]>;
}
export class MairieNotFoundError extends Error {}

// application — use case
export class SearchMairiesUseCase {
  constructor(private readonly mairies: MairieRepository) {}
  async execute(query: string, limit: number) {
    const cleaned = query.trim();
    if (cleaned.length < 2) return [];
    return this.mairies.search(cleaned, Math.min(Math.max(limit, 1), MAX_LIMIT));
  }
}

// infrastructure — adapter
export class SqlMairieRepository implements MairieRepository {
  async search(query: string, limit: number) {
    const rows = await db.query(/* … */);
    return rows.map(toMairieSearchResult);          // mapping ligne → domaine
  }
}

// composition root — le seul endroit qui connaît les deux
export const searchMairies = new SearchMairiesUseCase(new SqlMairieRepository());
```

## 3. Ajouter une feature (procédure)

1. **Domaine** : entité, port, erreurs métier. Règles pures testables seules.
2. **Application** : un use case par intention, petit, une méthode `execute()`.
3. **Infrastructure** : l'adapter, puis câblage dans la composition root (un fichier par contexte métier, pas un « god container »).
4. **Présentation** : appelle le use case, **traduit** l'erreur métier (404, 401, message de formulaire) en **un seul endroit**.
5. **Tests** : use case + faux repository en mémoire ; l'adapter se teste à part (intégration).
6. Lancer lint, types, tests, build.

## 4. Frontières de données

- Ce qui franchit une frontière est une **structure simple** (DTO / view model), jamais une ligne de BDD ni une entité portant des champs sensibles (hash de mot de passe, téléphone…).
- La présentation n'envoie pas son objet requête/réponse au use case : elle **extrait des valeurs** et passe des primitives ou un DTO.
- **Valider à l'entrée** (présentation) ; le domaine garantit ses **invariants**.
- Les secrets et la configuration (`process.env`, `.env`) sont lus **uniquement dans l'infrastructure**.
- Le temps et l'aléa sont des dépendances : si une règle en dépend (expiration, jeton), injecter un port `Clock` / `TokenGenerator` plutôt qu'appeler `Date.now()` ou `random` dans le use case.

## 5. Tester

```ts
class InMemoryMairieRepository implements MairieRepository {
  search = async (q: string, limit: number) => /* filtre sur un tableau */ [];
}

it('ignore les requêtes trop courtes', async () => {
  const useCase = new SearchMairiesUseCase(new InMemoryMairieRepository());
  expect(await useCase.execute('l', 10)).toEqual([]);
});
```

Pas de mock de module, pas de BDD, pas de framework : c'est le bénéfice mesurable de la Dependency Rule. Si un test de règle métier exige une base de données, une dépendance pointe dans le mauvais sens.

## 6. Faire respecter la règle par l'outillage

Une convention non vérifiée se dégrade. Interdire les imports par couche avec le linter du projet :

- TypeScript : ESLint `no-restricted-imports` par dossier, ou `dependency-cruiser` / `eslint-plugin-boundaries` si le besoin est réel.
- PHP : `deptrac`. Python : `import-linter`. Java : `ArchUnit`. Go : `depguard`.

Règles minimales : `domain/` n'importe rien d'externe ; `application/` n'importe que `domain/` ; la présentation n'importe l'infrastructure que via la composition root.

**Toujours tester une règle sur un import volontairement fautif** avant de s'y fier : une règle mal écrite (glob invalide, négation non supportée) ne bloque rien, **sans message d'erreur**.

## 7. Anti-patterns → correction

| Anti-pattern | Correction |
|---|---|
| contrôleur / page qui appelle la BDD ou une API tierce | port dans le domaine, adapter dans l'infrastructure, use case |
| use case qui fait `new SqlXxxRepository()` | injection par constructeur ; instanciation dans la composition root |
| domaine qui importe le framework, l'ORM, une lib de validation | types purs ; le mapping se fait dans l'adapter |
| port qui copie le schéma de table | port = besoin métier (`findBySlug`) |
| type de l'ORM exposé hors de l'adapter | mapper vers un type du domaine |
| règle métier (calcul de prix) dans l'adapter ou le contrôleur | la remonter dans le domaine |
| entité complète renvoyée à l'UI / à une API publique | DTO étroit |
| objet requête passé au use case | extraire des primitives dans la présentation |
| container unique de 500 lignes | un fichier par contexte |
| erreur inattendue renvoyée telle quelle au client | log serveur + message générique |
| une interface par classe « au cas où » | port seulement s'il y a une frontière à inverser |

## 8. Pragmatisme : quand NE PAS tout appliquer

- Une couche se justifie quand elle protège une **frontière qui change** (BDD, paiement, API tierce, e-mail) ou une **règle métier à tester isolément**. Sinon, ne pas fabriquer 4 couches pour rien.
- Contenu statique, CRUD trivial, script jetable : pas de use case sans règle métier ni I/O. Un use case anémique (pure délégation) est acceptable pour une lecture simple, mais pas à multiplier.
- Projet existant sans couches : **ne pas tout réécrire**. Appliquer la structure aux nouvelles features, migrer au fil des modifications.
- Application surtout visuelle : un découpage par feature (`features/x/{components,hooks,api}`) peut suffire ; il peut coexister avec les couches métier.
- Pas de conteneur DI à décorateurs ni de framework d'architecture : des singletons de module suffisent.

## 9. Checklist de revue

- [ ] Aucun import sortant depuis le domaine ni l'application (grep framework, ORM, `infrastructure`).
- [ ] Aucun accès BDD / API tierce hors de l'infrastructure ; aucun `process.env` hors de l'infrastructure.
- [ ] Nouveau use case : dépendances par constructeur, câblé dans la composition root.
- [ ] Ports exprimés en besoin métier ; types externes mappés dans l'adapter.
- [ ] Erreurs métier typées, traduites en un seul endroit.
- [ ] Aucun champ sensible n'atteint le client ; DTO étroits aux frontières.
- [ ] Règle métier couverte par un test sans BDD ni framework.
- [ ] Règles de frontière vérifiées par le linter.

## Sources

- R. C. Martin, [The Clean Architecture (2012)](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html) ; livre *Clean Architecture* (2017).
- A. Cockburn, *Hexagonal Architecture* (ports & adapters) ; J. Palermo, *Onion Architecture*.
