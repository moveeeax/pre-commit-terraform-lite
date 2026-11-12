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
	[ "$output" = "v1.109.4" ]
}

@test "pctl_pin returns the pinned pre-commit-hooks rev" {
	run pctl_pin precommit-hooks
	[ "$status" -eq 0 ]
	[ "$output" = "v6.0.0" ]
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
	[[ "$output" == *"rev: v1.109.4"* ]]
	[[ "$output" == *"rev: v6.0.0"* ]]
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

@test "pctl_heavy_snippet prints the upstream hook id for each heavy hook" {
	run pctl_heavy_snippet checkov
	[ "$status" -eq 0 ]
	[[ "$output" == *"- id: terraform_checkov"* ]]
	run pctl_heavy_snippet tfsec
	[[ "$output" == *"- id: terraform_tfsec"* ]]
	run pctl_heavy_snippet infracost
	[[ "$output" == *"- id: infracost_breakdown"* ]]
	run pctl_heavy_snippet terrascan
	[[ "$output" == *"- id: terrascan"* ]]
}

@test "pctl_heavy_snippet fails on an unknown hook" {
	run pctl_heavy_snippet bogus
	[ "$status" -ne 0 ]
	[[ "$output" == *"unknown hook"* ]]
}

@test "pctl_heavy_list normalises order and drops duplicates" {
	run pctl_heavy_list "terrascan, checkov,terrascan"
	[ "$status" -eq 0 ]
	[ "$output" = "$(printf 'checkov\nterrascan')" ]
}

@test "pctl_heavy_list accepts an empty list" {
	run pctl_heavy_list ""
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "pctl_heavy_list exits 2 with the valid names on an unknown entry" {
	run pctl_heavy_list "checkov,kics"
	[ "$status" -eq 2 ]
	[[ "$output" == *"kics"* ]]
	[[ "$output" == *"checkov,tfsec,infracost,terrascan"* ]]
}

@test "rendered config appends opted-in heavy hooks after the bundle" {
	run pctl_render_config "infracost,checkov"
	[ "$status" -eq 0 ]
	[[ "$output" == *"terraform_checkov"* ]]
	[[ "$output" == *"infracost_breakdown"* ]]
	[[ "$output" != *"terraform_tfsec"* ]]
	[[ "$output" != *"- id: terrascan"* ]]
	# Snippets land at the end of the terraform hooks list, in canonical order.
	[ "$(printf '%s\n' "$output" | grep -- '- id:' | tail -3 | tr -d ' ')" = \
		"$(printf -- '-id:terraform_trivy\n-id:terraform_checkov\n-id:infracost_breakdown')" ]
	[[ "$output" == *"Regenerate: install.sh --with checkov,infracost --print"* ]]
}

@test "rendered config with heavy hooks is the default plus the snippets" {
	expected="$(pctl_render_config | sed 's/install.sh --print/install.sh --with tfsec --print/'; pctl_heavy_snippet tfsec)"
	[ "$(pctl_render_config tfsec)" = "$expected" ]
}

@test "pctl_render_config exits 2 on an unknown heavy hook" {
	run pctl_render_config "nope"
	[ "$status" -eq 2 ]
}

@test "pctl_config_tools adds the tools of opted-in heavy hooks" {
	run pctl_config_tools "checkov,terrascan"
	[ "$status" -eq 0 ]
	[[ "$output" == *"trivy"* ]]
	[[ "$output" == *"checkov"* ]]
	[[ "$output" == *"terrascan"* ]]
	[[ "$output" != *"infracost"* ]]
}

@test "heavy hook docs match the renderer (no drift)" {
	run sh "$REPO_ROOT/scripts/gen-heavy-docs.sh" --check
	[ "$status" -eq 0 ]
}
