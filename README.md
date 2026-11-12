# pre-commit-terraform-lite

[![ci](https://github.com/moveeeax/pre-commit-terraform-lite/actions/workflows/ci.yml/badge.svg)](https://github.com/moveeeax/pre-commit-terraform-lite/actions/workflows/ci.yml)
![shell](https://img.shields.io/badge/shell-POSIX-89e051)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

> Sane Terraform pre-commit hooks, curated and installable in one line.

Every Terraform repo ends up copy-pasting the same `.pre-commit-config.yaml`,
then discovering three months later that the hook revs drifted and `tflint` no
longer agrees with `terraform_docs`. This bundles a **pinned, tested-together**
set of hooks and a bootstrap script so a new repo is protected in one command.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/moveeeax/pre-commit-terraform-lite/main/install.sh | sh
```

That drops a pinned `.pre-commit-config.yaml` into the current repo, installs the
`pre-commit` framework, checks for the Terraform tools the hooks call, and
registers the git hook.

Just want the config, no installs?

```sh
curl -fsSL .../install.sh | sh -s -- --config-only
# or print it and redirect yourself:
curl -fsSL .../install.sh | sh -s -- --print > .pre-commit-config.yaml
```

Want a heavier scanner too? Name it with `--with` and it is rendered into the
config instead of being pasted by hand:

```sh
curl -fsSL .../install.sh | sh -s -- --with checkov,infracost --print > .pre-commit-config.yaml
```

## What's in the bundle

Pinned so the hooks actually agree with each other:

| Hook | Source | Rev |
| --- | --- | --- |
| `trailing-whitespace`, `end-of-file-fixer`, `check-merge-conflict`, `check-yaml` | [pre-commit/pre-commit-hooks](https://github.com/pre-commit/pre-commit-hooks) | `v6.0.0` |
| `terraform_fmt`, `terraform_validate`, `terraform_tflint`, `terraform_docs`, `terraform_trivy` | [antonbabenko/pre-commit-terraform](https://github.com/antonbabenko/pre-commit-terraform) | `v1.109.4` |

The default stays fast (a `trivy` scan scoped to `HIGH,CRITICAL`, `tflint` on a
tight rule set). Heavier scanners — `checkov`, `tfsec`, `infracost`, `terrascan`
— are **opt-in**: add them with `--with checkov,tfsec,infracost,terrascan` (any
subset). An unknown name exits with status 2. Details and per-tool caveats are in
[`docs/HEAVY_HOOKS.md`](docs/HEAVY_HOOKS.md).

## How it works

`lib/common.sh` is the single source of truth: the pinned revisions and the
rendered YAML live there as pure, testable functions. `install.sh` is a thin
POSIX-`sh` CLI over it, and the checked-in `hooks/.pre-commit-config.yaml` is
generated from the same renderer — CI fails if the two ever drift. The heavy
hook snippets in `docs/HEAVY_HOOKS.md` come from the same functions via
`scripts/gen-heavy-docs.sh`, and CI checks those too.

## Usage

```console
$ ./install.sh --help
install.sh v0.1.0 — curated Terraform pre-commit hooks, installed in one line.
...
$ ./install.sh --config-only --dir ./my-tf-repo
==> install.sh v0.1.0
==> writing ./my-tf-repo/.pre-commit-config.yaml
==> done (config only)
```

Flags: `--dir`, `--config-only`, `--print`, `--with`, `--dry-run`, `--force`,
`--no-install`, `--version`, `--help`.

## Example

[`examples/terraform`](examples/terraform) is a minimal, valid module that ships
the curated config so you can watch the hooks run:

```sh
cd examples/terraform
pre-commit run --all-files
```

## Develop

```sh
shellcheck -s sh install.sh lib/common.sh scripts/gen-heavy-docs.sh
bats test/
sh scripts/gen-heavy-docs.sh   # after changing a heavy hook snippet
```

Prerequisites for real hook runs: `terraform`, `tflint`, `terraform-docs`,
`trivy` on `PATH`. The bundle degrades gracefully — install.sh warns about
missing tools rather than failing.

## License

MIT — see [LICENSE](LICENSE).
