#!/usr/bin/env bats
# Behavioural tests for install.sh. These stay hermetic: no network, no real
# tool installs — we only exercise the config-writing and CLI surface, which is
# what the acceptance criteria hinge on.

setup() {
	REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
	INSTALL="$REPO_ROOT/install.sh"
	WORK="$(mktemp -d)"
}

teardown() {
	rm -rf "$WORK"
}

@test "--version prints the semver" {
	run sh "$INSTALL" --version
	[ "$status" -eq 0 ]
	[ "$output" = "0.1.0" ]
}

@test "--help documents the flags" {
	run sh "$INSTALL" --help
	[ "$status" -eq 0 ]
	[[ "$output" == *"--config-only"* ]]
	[[ "$output" == *"--print"* ]]
}

@test "--print emits a valid-looking config and touches nothing" {
	run sh "$INSTALL" --print
	[ "$status" -eq 0 ]
	[[ "$output" == *"repos:"* ]]
	[[ "$output" == *"terraform_fmt"* ]]
}

@test "--config-only writes the config into --dir" {
	run sh "$INSTALL" --config-only --dir "$WORK"
	[ "$status" -eq 0 ]
	[ -f "$WORK/.pre-commit-config.yaml" ]
	grep -q "antonbabenko/pre-commit-terraform" "$WORK/.pre-commit-config.yaml"
}

@test "existing config is preserved without --force" {
	printf 'keep me\n' >"$WORK/.pre-commit-config.yaml"
	run sh "$INSTALL" --config-only --dir "$WORK"
	[ "$status" -eq 0 ]
	[ "$(cat "$WORK/.pre-commit-config.yaml")" = "keep me" ]
}

@test "--force overwrites an existing config" {
	printf 'old\n' >"$WORK/.pre-commit-config.yaml"
	run sh "$INSTALL" --config-only --dir "$WORK" --force
	[ "$status" -eq 0 ]
	grep -q "terraform_docs" "$WORK/.pre-commit-config.yaml"
}

@test "--dry-run does not create the config" {
	run sh "$INSTALL" --config-only --dir "$WORK" --dry-run
	[ "$status" -eq 0 ]
	[ ! -f "$WORK/.pre-commit-config.yaml" ]
	[[ "$output" == *"dry-run"* ]]
}

@test "unknown flag exits non-zero" {
	run sh "$INSTALL" --nope
	[ "$status" -ne 0 ]
	[[ "$output" == *"unknown option"* ]]
}

@test "missing target dir fails cleanly" {
	run sh "$INSTALL" --config-only --dir "$WORK/does-not-exist"
	[ "$status" -ne 0 ]
	[[ "$output" == *"not found"* ]]
}
