# Opt-in heavy hooks

The default bundle stays fast: formatting, validation, `tflint`, docs and a
`trivy` scan scoped to `HIGH,CRITICAL`. Anything below is slower, noisier, or
needs extra config, so it is **opt-in** — copy the snippet under the
`antonbabenko/pre-commit-terraform` repo block in your `.pre-commit-config.yaml`.

All hook ids come from
[`antonbabenko/pre-commit-terraform`](https://github.com/antonbabenko/pre-commit-terraform);
keep the same pinned `rev` the bundle uses so versions stay compatible.

## Checkov (policy-as-code)

```yaml
      - id: terraform_checkov
        args:
          - --args=--quiet
          - --args=--compact
```

Install: `pip install checkov`. Expect false positives on greenfield modules;
tune with a `.checkov.yaml` skip list.

## tfsec (superseded by trivy, still common)

```yaml
      - id: terraform_tfsec
        args:
          - --args=--minimum-severity=HIGH
```

`tfsec` is in maintenance mode in favour of `trivy` — only add it if a downstream
system still expects tfsec output.

## infracost (cost diff on changed modules)

```yaml
      - id: infracost_breakdown
        args:
          - --args=--path=.
```

Needs `INFRACOST_API_KEY` in the environment; skip it in CI forks where the
secret is unavailable.

## Terrascan

```yaml
      - id: terrascan
        args:
          - --args=--non-recursive
```

Heavier policy engine; useful for compliance frameworks (CIS, PCI) but slow on
large repos — reserve it for a scheduled job rather than every commit.
