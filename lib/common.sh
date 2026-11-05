#!/usr/bin/env sh
# common.sh — shared, side-effect-free helpers for pre-commit-terraform-lite.
#
# Everything that decides *what* the bundle is (pinned revisions, the rendered
# .pre-commit-config.yaml, OS detection) lives here so it can be unit-tested
# without touching the network or the host. install.sh is a thin CLI on top.
#
# POSIX sh only: no bashisms, so the same code runs under dash, ash and bash.

# --- pinned, tested-together revisions -------------------------------------
# One place to bump. CI verifies the checked-in config matches what these
# render, so the two can never drift.
PCTL_REV_PRECOMMIT_HOOKS="v6.0.0"
PCTL_REV_TERRAFORM="v1.109.4"   # antonbabenko/pre-commit-terraform

# pctl_pin <key> -> prints the pinned revision, exits non-zero on unknown key.
pctl_pin() {
	case "$1" in
	precommit-hooks) printf '%s\n' "$PCTL_REV_PRECOMMIT_HOOKS" ;;
	terraform) printf '%s\n' "$PCTL_REV_TERRAFORM" ;;
	*)
		printf 'pctl_pin: unknown key: %s\n' "$1" >&2
		return 1
		;;
	esac
}

# pctl_have <cmd> -> true if cmd is on PATH.
pctl_have() {
	command -v "$1" >/dev/null 2>&1
}

# pctl_detect_os -> one of: linux, macos, windows, unknown.
pctl_detect_os() {
	case "$(uname -s 2>/dev/null)" in
	Linux) printf 'linux\n' ;;
	Darwin) printf 'macos\n' ;;
	MINGW* | MSYS* | CYGWIN*) printf 'windows\n' ;;
	*) printf 'unknown\n' ;;
	esac
}

# pctl_render_config -> prints the curated .pre-commit-config.yaml on stdout.
# The light bundle: generic hygiene hooks + fmt / validate / tflint / docs /
# trivy from antonbabenko/pre-commit-terraform. Heavier scanners are opt-in
# and documented in docs/HEAVY_HOOKS.md, not wired in by default.
pctl_render_config() {
	tf_rev="$(pctl_pin terraform)"
	hooks_rev="$(pctl_pin precommit-hooks)"
	cat <<YAML
# Managed by pre-commit-terraform-lite — https://github.com/moveeeax/pre-commit-terraform-lite
# Curated, pinned Terraform hooks. Regenerate: install.sh --print > .pre-commit-config.yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: ${hooks_rev}
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-merge-conflict
      - id: check-yaml
        args: [--allow-multiple-documents]

  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: ${tf_rev}
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_tflint
        args:
          - --args=--only=terraform_deprecated_interpolation
          - --args=--only=terraform_unused_declarations
      - id: terraform_docs
        args:
          - --hook-config=--path-to-file=README.md
          - --hook-config=--add-to-existing-file=true
          - --hook-config=--create-file-if-not-exist=true
      - id: terraform_trivy
        args:
          - --args=--severity=HIGH,CRITICAL
YAML
}

# pctl_config_tools -> lists the external tools the config's hooks shell out to,
# one per line. Used by install.sh to know what to install and by tests.
pctl_config_tools() {
	printf 'pre-commit\nterraform\ntflint\nterraform-docs\ntrivy\n'
}
