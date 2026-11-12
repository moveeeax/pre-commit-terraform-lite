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

# --- opt-in heavy hooks ------------------------------------------------------
# Names accepted by install.sh --with, in the order they are rendered.
PCTL_HEAVY_HOOKS="checkov tfsec infracost terrascan"

# pctl_heavy_snippet <name> -> prints the hook entry for one heavy scanner,
# indented to sit under the antonbabenko/pre-commit-terraform hooks list.
# docs/HEAVY_HOOKS.md is regenerated from this (scripts/gen-heavy-docs.sh).
pctl_heavy_snippet() {
	case "$1" in
	checkov)
		cat <<'YAML'
      - id: terraform_checkov
        args:
          - --args=--quiet
          - --args=--compact
YAML
		;;
	tfsec)
		cat <<'YAML'
      - id: terraform_tfsec
        args:
          - --args=--minimum-severity=HIGH
YAML
		;;
	infracost)
		cat <<'YAML'
      - id: infracost_breakdown
        args:
          - --args=--path=.
YAML
		;;
	terrascan)
		cat <<'YAML'
      - id: terrascan
        args:
          - --args=--non-recursive
YAML
		;;
	*)
		printf 'pctl_heavy_snippet: unknown hook: %s\n' "$1" >&2
		return 1
		;;
	esac
}

# pctl_heavy_list <csv> -> normalises a --with value: prints the known names
# it contains in canonical order, one per line, duplicates dropped. Returns 2
# and prints the valid names on stderr if any entry is unknown.
pctl_heavy_list() {
	_req=" $(printf '%s' "$1" | tr ',' ' ') "
	for _n in $_req; do
		case " $PCTL_HEAVY_HOOKS " in
		*" $_n "*) : ;;
		*)
			printf 'unknown heavy hook: %s (valid: %s)\n' "$_n" \
				"$(printf '%s' "$PCTL_HEAVY_HOOKS" | tr ' ' ',')" >&2
			return 2
			;;
		esac
	done
	for _n in $PCTL_HEAVY_HOOKS; do
		case "$_req" in
		*" $_n "*) printf '%s\n' "$_n" ;;
		esac
	done
}

# pctl_heavy_tool <name> -> the binary a heavy hook shells out to.
pctl_heavy_tool() {
	case "$1" in
	checkov | tfsec | infracost | terrascan) printf '%s\n' "$1" ;;
	*)
		printf 'pctl_heavy_tool: unknown hook: %s\n' "$1" >&2
		return 1
		;;
	esac
}

# pctl_render_config [csv] -> prints the curated .pre-commit-config.yaml on
# stdout. The light bundle: generic hygiene hooks + fmt / validate / tflint /
# docs / trivy from antonbabenko/pre-commit-terraform. Heavier scanners are
# opt-in: pass their names (comma-separated, see PCTL_HEAVY_HOOKS) and they are
# appended to the terraform hooks list. Returns 2 on an unknown name.
pctl_render_config() {
	tf_rev="$(pctl_pin terraform)"
	hooks_rev="$(pctl_pin precommit-hooks)"
	heavy="$(pctl_heavy_list "${1:-}")" || return 2
	regen="install.sh --print"
	if [ -n "$heavy" ]; then
		regen="install.sh --with $(printf '%s\n' "$heavy" | paste -sd, -) --print"
	fi
	cat <<YAML
# Managed by pre-commit-terraform-lite — https://github.com/moveeeax/pre-commit-terraform-lite
# Curated, pinned Terraform hooks. Regenerate: ${regen} > .pre-commit-config.yaml
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
	for _h in $heavy; do
		pctl_heavy_snippet "$_h"
	done
}

# pctl_config_tools [csv] -> lists the external tools the config's hooks shell
# out to, one per line, including any opted-in heavy hooks. Used by install.sh
# to know what to check for and by tests. Returns 2 on an unknown name.
pctl_config_tools() {
	heavy="$(pctl_heavy_list "${1:-}")" || return 2
	printf 'pre-commit\nterraform\ntflint\nterraform-docs\ntrivy\n'
	for _h in $heavy; do
		pctl_heavy_tool "$_h"
	done
}
