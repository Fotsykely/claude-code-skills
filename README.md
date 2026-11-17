# claude-code-skills

Skills personnels pour [Claude Code](https://claude.com/claude-code) : règles de code, architecture, SEO, performance et commits. Les skills sont rédigés en français.

*Personal Claude Code skills: code quality, architecture, SEO, performance and commit hygiene. Written in French.*

## Contenu

| Skill | Rôle |
|---|---|
| [`clean-code`](skills/clean-code) | Règles de Clean Code, indépendantes du langage : noms, fonctions, erreurs, tests, odeurs de code |
| [`clean-architecture`](skills/clean-architecture) | Dependency Rule, ports et adapters, use cases, composition root, DTO, tests sans framework |
| [`nextjs-clean-architecture`](skills/nextjs-clean-architecture) | Clean Architecture appliquée à Next.js (App Router) : Server Components, Server Actions, sécurité des données |
| [`seo`](skills/seo) | SEO technique : métadonnées, sitemap, robots, noindex, JSON-LD, Open Graph |
| [`optimisation-lighthouse`](skills/optimisation-lighthouse) | Scores Lighthouse sur Next.js : méthode de mesure (médiane de 5 runs), checklist par métrique |
| [`commit-rules`](skills/commit-rules) | Commits sûrs : vérifie la branche, Conventional Commits, petits commits, jamais de push |
| [`cv-project-breakdown`](skills/cv-project-breakdown) | Analyser un projet tech pour en tirer des puces de CV défendables |

`clean-code` et `clean-architecture` se complètent : le premier traite l'écriture du code, le second la structure en couches. `nextjs-clean-architecture` s'ajoute aux deux sur un projet Next.js.

## Installation

Cloner le dépôt, puis copier (ou lier) les skills voulus dans le dossier des skills utilisateur, disponibles ensuite dans tous les projets :

```bash
git clone https://github.com/Fotsykely/claude-code-skills.git
cd claude-code-skills

# tous les skills
cp -R skills/* ~/.claude/skills/

# ou un seul
cp -R skills/clean-code ~/.claude/skills/
```

Pour qu'un skill ne s'applique qu'à un projet, le copier dans `<projet>/.claude/skills/` et le committer.

Pour suivre les mises à jour du dépôt, utiliser des liens symboliques plutôt qu'une copie :

```bash
ln -s "$PWD/skills/clean-code" ~/.claude/skills/clean-code
```

## Utilisation

Claude charge un skill quand sa description correspond à la demande (« refactorer cette fonction », « où mettre ce fichier »…). On peut aussi l'appeler à la main : `/clean-code`, `/clean-architecture`, etc.

## Priorité des règles

Dans chaque skill, le `CLAUDE.md` / `AGENTS.md` du projet passe avant le skill : si un projet a déjà une convention, la suivre.

## Licence

MIT, voir [LICENSE](LICENSE).
