_This project is open source and developed alongside other projects or during free time. Contributions are greatly appreciated!_

Check out the contribution guidelines [here.](https://abap2ui5.github.io/docs/resources/contribution.html)

## Working in this repository

Everything specific to it — the package scheme, what each package needs from
the system, the generated one-package branches, and the conventions a sample
follows — is in **[AGENTS.md](AGENTS.md)**. It is written for agents and for
people; read it before changing anything under `src/`.

The short version:

```sh
npm ci
npm run check        # abaplint + abap2UI5-linter + the overview check
```

`npm run check` is what CI runs. Work on `main`; the ten package branches are
generated and force-pushed from it, so anything committed there is lost at the
next build.
