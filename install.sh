#!/usr/bin/env sh
# install.sh — one-line setup for a curated Terraform pre-commit stack.
#
#   curl -fsSL https://raw.githubusercontent.com/moveeeax/pre-commit-terraform-lite/main/install.sh | sh
#
# It drops a pinned .pre-commit-config.yaml into the target repo, installs the
# pre-commit framework and the Terraform tools the hooks need, and registers the
# git hook. Every step is opt-out-able so it stays friendly in CI and dry runs.
set -eu

VERSION="0.1.0"
SELF="$(basename "$0")"

# Locate lib/common.sh whether run from a checkout or piped through `sh`.
# When piped, there is no $0 directory, so fall back to fetching from main.
_find_lib() {
	# CDPATH= neutralises a user CDPATH so cd stays predictable (intentional).
	# shellcheck disable=SC1007
	_dir="$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P || true)"
	if [ -n "${_dir:-}" ] && [ -f "$_dir/lib/common.sh" ]; then
		printf '%s\n' "$_dir/lib/common.sh"
		return 0
	fi
	return 1
}

RAW_BASE="https://raw.githubusercontent.com/moveeeax/pre-commit-terraform-lite/main"

# shellcheck source=lib/common.sh disable=SC1090
if _lib="$(_find_lib)"; then
	. "$_lib"
else
	# Piped install: pull the library next to us.
	_tmp="$(mktemp)"
	if command -v curl >/dev/null 2>&1; then
		curl -fsSL "$RAW_BASE/lib/common.sh" >"$_tmp"
	else
		wget -qO- "$RAW_BASE/lib/common.sh" >"$_tmp"
	fi
	. "$_tmp"
	rm -f "$_tmp"
fi

usage() {
	cat <<USAGE
$SELF v$VERSION — curated Terraform pre-commit hooks, installed in one line.

Usage: $SELF [options]

Options:
  --dir DIR        Target repository directory (default: .)
  --config-only    Write .pre-commit-config.yaml, skip installing tools/hooks
  --print          Print the rendered config to stdout and exit
  --dry-run        Show what would happen without changing anything
  --force          Overwrite an existing .pre-commit-config.yaml
  --no-install     Do not run 'pre-commit install' (just deps + config)
  -h, --help       Show this help
  -V, --version    Show version

Examples:
  $SELF                    # config + tools + git hook in the current repo
  $SELF --config-only      # only drop the config file
  $SELF --print > .pre-commit-config.yaml
USAGE
}

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*" >&2; }
die() {
	printf '\033[1;31merror:\033[0m %s\n' "$*" >&2
	exit 1
}

DIR="."
CONFIG_ONLY=0
DRY_RUN=0
FORCE=0
DO_INSTALL=1

while [ $# -gt 0 ]; do
	case "$1" in
	--dir)
		DIR="${2:?--dir needs a value}"
		shift 2
		;;
	--config-only)
		CONFIG_ONLY=1
		shift
		;;
	--print)
		pctl_render_config
		exit 0
		;;
	--dry-run)
		DRY_RUN=1
		shift
		;;
	--force)
		FORCE=1
		shift
		;;
	--no-install)
		DO_INSTALL=0
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	-V | --version)
		printf '%s\n' "$VERSION"
		exit 0
		;;
	*) die "unknown option: $1 (see --help)" ;;
	esac
done

run() {
	if [ "$DRY_RUN" -eq 1 ]; then
		printf '  [dry-run] %s\n' "$*"
	else
		"$@"
	fi
}

# --- 1. write the config ----------------------------------------------------
write_config() {
	cfg="$DIR/.pre-commit-config.yaml"
	if [ -e "$cfg" ] && [ "$FORCE" -eq 0 ]; then
		warn "$cfg exists — keeping it (use --force to overwrite)"
		return 0
	fi
	[ -d "$DIR" ] || die "target dir not found: $DIR"
	log "writing $cfg"
	if [ "$DRY_RUN" -eq 1 ]; then
		printf '  [dry-run] render config -> %s\n' "$cfg"
	else
		pctl_render_config >"$cfg"
	fi
}

# --- 2. install the pre-commit framework ------------------------------------
install_precommit() {
	if pctl_have pre-commit; then
		log "pre-commit already installed ($(pre-commit --version 2>/dev/null || echo present))"
		return 0
	fi
	log "installing pre-commit"
	if pctl_have pipx; then
		run pipx install pre-commit
	elif pctl_have pip3; then
		run pip3 install --user pre-commit
	elif pctl_have pip; then
		run pip install --user pre-commit
	elif pctl_have brew; then
		run brew install pre-commit
	else
		die "no pipx/pip/brew found — install pre-commit manually: https://pre-commit.com"
	fi
}

# --- 3. install the terraform tooling the hooks call ------------------------
install_tools() {
	os="$(pctl_detect_os)"
	log "detected OS: $os"
	for tool in terraform tflint terraform-docs trivy; do
		if pctl_have "$tool"; then
			log "$tool present"
			continue
		fi
		warn "$tool not found — install it for full hook coverage (see README)"
	done
}

# --- 4. register the git hook ----------------------------------------------
register_hook() {
	[ "$DO_INSTALL" -eq 1 ] || return 0
	if ! pctl_have pre-commit; then
		warn "pre-commit not on PATH yet; skipping 'pre-commit install'"
		return 0
	fi
	log "registering git pre-commit hook"
	( cd "$DIR" && run pre-commit install )
}

main() {
	log "$SELF v$VERSION"
	write_config
	if [ "$CONFIG_ONLY" -eq 1 ]; then
		log "done (config only)"
		return 0
	fi
	install_precommit
	install_tools
	register_hook
	log "done — run 'pre-commit run --all-files' to try it"
}

main
