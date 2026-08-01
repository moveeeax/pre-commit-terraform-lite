#!/usr/bin/env bats
# Unit tests for the pure library functions in lib/common.sh.

setup() {
	REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
	# shellcheck source=../lib/common.sh
	. "$REPO_ROOT/lib/common.sh"
}

@test "pctl_pin returns the pinned terraform rev" {
	run pctl_pin terraform
	[ "$status" -eq 0 ]
	[ "$output" = "v1.96.1" ]
}

@test "pctl_pin returns the pinned pre-commit-hooks rev" {
	run pctl_pin precommit-hooks
	[ "$status" -eq 0 ]
	[ "$output" = "v5.0.0" ]
}

@test "pctl_pin fails loudly on an unknown key" {
	run pctl_pin bogus
	[ "$status" -ne 0 ]
	[[ "$output" == *"unknown key"* ]]
}

@test "pctl_detect_os returns a known token" {
	run pctl_detect_os
	[ "$status" -eq 0 ]
	case "$output" in
	linux | macos | windows | unknown) : ;;
	*) false ;;
	esac
}

@test "rendered config contains the terraform hooks repo pinned by rev" {
	run pctl_render_config
	[ "$status" -eq 0 ]
	[[ "$output" == *"antonbabenko/pre-commit-terraform"* ]]
	[[ "$output" == *"rev: v1.96.1"* ]]
	[[ "$output" == *"rev: v5.0.0"* ]]
}

@test "rendered config wires the five MVP hooks" {
	run pctl_render_config
	for hook in terraform_fmt terraform_validate terraform_tflint terraform_docs terraform_trivy; do
		[[ "$output" == *"$hook"* ]] || {
			echo "missing $hook" >&2
			false
		}
	done
}

@test "rendered config keeps heavy scanners out of the default bundle" {
	run pctl_render_config
	[[ "$output" != *"terraform_checkov"* ]]
	[[ "$output" != *"terraform_tfsec"* ]]
}

@test "pctl_config_tools lists the external dependencies" {
	run pctl_config_tools
	[[ "$output" == *"pre-commit"* ]]
	[[ "$output" == *"tflint"* ]]
	[[ "$output" == *"terraform-docs"* ]]
	[[ "$output" == *"trivy"* ]]
}

@test "checked-in config matches the renderer (no drift)" {
	diff <(pctl_render_config) "$REPO_ROOT/hooks/.pre-commit-config.yaml"
}
