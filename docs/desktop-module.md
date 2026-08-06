# Desktop module

Prebuilt **casst** archives for FinDesk desktop bundles (no Docker image).

## Release tag

Module assets use a dedicated GitHub Release tag so they do not collide with
docs-only or appliance-image tags:

- **`casst-v<version>`** — e.g. `casst-v0.1.0`

Published by the private `Geeksfino/code2wiki` workflow
`release-desktop-module.yml` (manual `workflow_dispatch`).

## Assets

Pattern:

```text
casst-<version>-<triple>.tar.zst
```

Examples for `0.1.0`:

| Triple | Archive |
|--------|---------|
| `aarch64-apple-darwin` | `casst-0.1.0-aarch64-apple-darwin.tar.zst` |
| `x86_64-apple-darwin` | `casst-0.1.0-x86_64-apple-darwin.tar.zst` |
| `x86_64-unknown-linux-gnu` | `casst-0.1.0-x86_64-unknown-linux-gnu.tar.zst` |
| `x86_64-pc-windows-msvc` | `casst-0.1.0-x86_64-pc-windows-msvc.tar.zst` |

Download from:

https://github.com/finogeeks/code2wiki/releases

(filter by tag `casst-v<version>`).

## FinDesk prepare contract

FinDesk `prepare` should:

1. Pin `code2wikiVersion` (e.g. `0.1.0`) in the distribution lock / stack profile.
2. Resolve the Rust triple for the desktop build target (same names as FinClaw /
   aioncore prepare `archMap`).
3. Download
   `https://github.com/finogeeks/code2wiki/releases/download/casst-v<version>/casst-<version>-<triple>.tar.zst`
4. Extract into `resources/bundled-code2wiki/<platform-arch>/` (layout:
   `bin/casst-ctl`, `bin/casst-facade`, `bin/anydoc`, `share/…`, `MANIFEST.json`).

The module does **not** bundle FinClaw, Bun, Hermes, Git, or Node — the desktop
host provides the agent runtime. Its compiled `bin/casst-ctl`,
`bin/casst-facade`, and `bin/anydoc` support serve, extract, and grounded asks;
host `python3` is not required. Office/PDF vault text is produced by the bundled
native `bin/anydoc` via `casst-ctl extract` (no `npx`).

After importing files into `$CODE2WIKI_DATA/vault/<source-id>/`:

```bash
export CODE2WIKI_HOME=/path/to/bundled-code2wiki/...
export CODE2WIKI_DATA=...
"$CODE2WIKI_HOME/bin/casst-ctl" extract
```

## Local smoke (maintainers)

From a `Geeksfino/code2wiki` checkout:

```bash
./scripts/package-casst-module.sh
ls dist/casst-$(tr -d '[:space:]' <VERSION)-*.tar.zst
```

Optional `TRIPLE=…` overrides auto-detect (normalized Rust triples only; see
`scripts/lib/casst-triples.sh`).
