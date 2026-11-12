# Opt-in heavy hooks

The default bundle stays fast: formatting, validation, `tflint`, docs and a
`trivy` scan scoped to `HIGH,CRITICAL`. Anything below is slower, noisier, or
needs extra config, so it is **opt-in**. Render the ones you want with
`--with` (comma-separated names: `checkov`, `tfsec`, `infracost`, `terrascan`):

```sh
install.sh --with checkov,infracost --print > .pre-commit-config.yaml
# or write it straight into the repo, overwriting the current config:
install.sh --with checkov,infracost --config-only --force
```

The snippets are appended under the `antonbabenko/pre-commit-terraform` repo
block, and the config header records the `--with` list so the file can be
regenerated with the same command. install.sh also checks that the matching
tools are on `PATH`. An unknown name exits with status 2 and prints the valid
list.

Copying a snippet by hand still works, but the next `--print` without `--with`
drops it.

All hook ids come from
[`antonbabenko/pre-commit-terraform`](https://github.com/antonbabenko/pre-commit-terraform);
keep the same pinned `rev` the bundle uses so versions stay compatible. The
snippets below are generated from `pctl_heavy_snippet` in `lib/common.sh`
(`sh scripts/gen-heavy-docs.sh`); CI fails if they drift.

## Checkov (policy-as-code)

<!-- heavy:checkov -->
```yaml
      - id: terraform_checkov
        args:
          - --args=--quiet
          - --args=--compact
```
<!-- /heavy:checkov -->

Install: `pip install checkov`. Expect false positives on greenfield modules;
tune with a `.checkov.yaml` skip list.

## tfsec (superseded by trivy, still common)

<!-- heavy:tfsec -->
```yaml
      - id: terraform_tfsec
        args:
          - --args=--minimum-severity=HIGH
```
<!-- /heavy:tfsec -->

`tfsec` is in maintenance mode in favour of `trivy` — only add it if a downstream
system still expects tfsec output.

## infracost (cost diff on changed modules)

<!-- heavy:infracost -->
```yaml
      - id: infracost_breakdown
        args:
          - --args=--path=.
```
<!-- /heavy:infracost -->

Needs `INFRACOST_API_KEY` in the environment; skip it in CI forks where the
secret is unavailable.

## Terrascan

<!-- heavy:terrascan -->
```yaml
      - id: terrascan
        args:
          - --args=--non-recursive
```
<!-- /heavy:terrascan -->

Heavier policy engine; useful for compliance frameworks (CIS, PCI) but slow on
large repos — reserve it for a scheduled job rather than every commit.
