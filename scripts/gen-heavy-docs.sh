#!/usr/bin/env sh
# gen-heavy-docs.sh — rewrite the YAML snippets in docs/HEAVY_HOOKS.md from
# pctl_heavy_snippet so the doc and `install.sh --with` cannot drift.
#
#   sh scripts/gen-heavy-docs.sh            # rewrite the doc in place
#   sh scripts/gen-heavy-docs.sh --check    # exit 1 if the doc is stale
#
# Each snippet sits between `<!-- heavy:NAME -->` and `<!-- /heavy:NAME -->`;
# everything between the markers is replaced, prose outside is left alone.
set -eu

# CDPATH= neutralises a user CDPATH so cd stays predictable (intentional).
# shellcheck disable=SC1007
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)"
DOC="$ROOT/docs/HEAVY_HOOKS.md"
LIB="$ROOT/lib/common.sh"

render() {
	awk -v lib="$LIB" '
	/^<!-- heavy:[a-z]+ -->$/ {
		print
		name = $0
		sub(/^<!-- heavy:/, "", name)
		sub(/ -->$/, "", name)
		print "```yaml"
		cmd = "sh -c '\''. \"$1\" && pctl_heavy_snippet \"$2\"'\'' _ \"" lib "\" " name
		n = 0
		while ((cmd | getline line) > 0) { print line; n++ }
		if (close(cmd) != 0 || n == 0) { print "no snippet for " name > "/dev/stderr"; exit 2 }
		print "```"
		skip = 1
		next
	}
	/^<!-- \/heavy:[a-z]+ -->$/ { skip = 0 }
	!skip { print }
	' "$DOC"
}

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
render >"$tmp"

if [ "${1:-}" = "--check" ]; then
	if ! diff -u "$DOC" "$tmp"; then
		printf 'docs/HEAVY_HOOKS.md is stale: run sh scripts/gen-heavy-docs.sh\n' >&2
		exit 1
	fi
	exit 0
fi
cat "$tmp" >"$DOC"
