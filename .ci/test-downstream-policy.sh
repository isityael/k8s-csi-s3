#!/bin/sh

set -eu

repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
dockerfile="$repo_root/Dockerfile"
gomod="$repo_root/go.mod"
renovate="$repo_root/renovate.json"
actions="$repo_root/.forgejo/workflows/validate.yaml"
woodpecker="$repo_root/.woodpecker/release.yaml"
woodpecker_validate="$repo_root/.woodpecker/validate.yaml"

passed=0
failed=0

pass() {
  passed=$((passed + 1))
  printf 'PASS: %s\n' "$1"
}

fail() {
  failed=$((failed + 1))
  printf 'FAIL: %s\n' "$1" >&2
}

assert_file() {
  file="$1"
  description="$2"

  if [ -f "$file" ]; then
    pass "$description"
  else
    fail "$description (missing $file)"
  fi
}

assert_contains() {
  file="$1"
  pattern="$2"
  description="$3"

  if [ -f "$file" ] && grep -Eq "$pattern" "$file"; then
    pass "$description"
  else
    fail "$description"
  fi
}

assert_not_contains() {
  file="$1"
  pattern="$2"
  description="$3"

  if [ -f "$file" ] && ! grep -Eq "$pattern" "$file"; then
    pass "$description"
  else
    fail "$description"
  fi
}

# Unit checks: deterministic image inputs.
assert_contains "$dockerfile" '^ARG GO_BASE=dhi\.io/golang:1\.26\.5-alpine3\.24-dev@sha256:[a-f0-9]{64}$' \
  'builder uses a digest-pinned DHI Go 1.26.5 Alpine 3.24 dev image'
assert_contains "$dockerfile" '^ARG RUNTIME_BASE=dhi\.io/alpine-base:3\.24-dev@sha256:[a-f0-9]{64}$' \
  'runtime uses a digest-pinned DHI Alpine 3.24 dev image'
assert_contains "$dockerfile" '^ARG GEESEFS_VERSION=v[0-9]+\.[0-9]+\.[0-9]+$' \
  'GeeseFS uses an explicit release'
assert_contains "$dockerfile" '^ARG GEESEFS_SHA256=[a-f0-9]{64}$' \
  'GeeseFS has an explicit SHA-256'
assert_contains "$dockerfile" '^ARG RCLONE_VERSION=[0-9]+\.[0-9]+\.[0-9]+-r[0-9]+$' \
  'rclone package version is pinned'
assert_contains "$dockerfile" '^ARG S3FS_FUSE_VERSION=[0-9]+\.[0-9]+-r[0-9]+$' \
  's3fs-fuse package version is pinned'

# Edge checks: known non-deterministic upstream patterns stay absent.
assert_not_contains "$dockerfile" '(:latest|/latest/|alpine/edge)' \
  'Dockerfile contains no latest tag, latest download, or Alpine edge repository'
assert_not_contains "$dockerfile" '^[[:space:]]*ADD[[:space:]]+https?://' \
  'Dockerfile does not use an unverified remote ADD'
assert_not_contains "$dockerfile" 'github\.com/yandex-cloud/k8s-csi-s3' \
  'Dockerfile links version metadata into the downstream module'

# Ownership checks: local packages must resolve to this fork, never the upstream
# module as an external dependency.
assert_contains "$gomod" '^module github\.com/isityael/k8s-csi-s3$' \
  'Go module belongs to the downstream fork'
if grep -R -E --include='*.go' 'github\.com/yandex-cloud/k8s-csi-s3' \
  "$repo_root/cmd" "$repo_root/pkg" >/dev/null; then
  fail 'Go source imports the upstream module path'
else
  pass 'Go source imports only the downstream module path'
fi

# Integration checks: dependency automation and CI ownership are explicit.
assert_file "$renovate" 'Renovate configuration exists'
assert_contains "$renovate" '"gomod"' 'Renovate enables the gomod manager for go.mod and go.sum'
assert_contains "$renovate" '"dockerfile"' 'Renovate enables Dockerfile dependency updates'
assert_file "$actions" 'Forgejo Actions validation workflow exists'
assert_contains "$actions" 'go mod verify' 'Forgejo Actions verifies Go module content'
assert_contains "$actions" 'go test ./\.\.\. -run' 'Forgejo Actions compiles the complete Go test suite'
assert_file "$woodpecker_validate" 'Woodpecker validation pipeline exists'
assert_contains "$woodpecker_validate" 'make test' 'Woodpecker runs the complete privileged CSI suite'
assert_file "$woodpecker" 'Woodpecker release pipeline exists'
assert_contains "$woodpecker" 'linux/amd64' 'Woodpecker publishes only linux/amd64'
assert_contains "$woodpecker" 'ghcr\.io/isityael/csi-s3-driver' 'Woodpecker publishes the owned GHCR image'

printf '\nPolicy checks: %s passed, %s failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
