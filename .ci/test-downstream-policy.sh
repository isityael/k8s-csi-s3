#!/bin/sh

set -eu

repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
dockerfile="$repo_root/Dockerfile"
gomod="$repo_root/go.mod"
renovate="$repo_root/renovate.json"
actions="$repo_root/.forgejo/workflows/validate.yaml"
woodpecker="$repo_root/.woodpecker/release.yaml"
woodpecker_validate="$repo_root/.woodpecker/validate.yaml"
release_actions="$repo_root/.forgejo/workflows/release-tag.yaml"
tag_resolver="$repo_root/hack/next-fork-tag.sh"
tag_creator="$repo_root/hack/create-forgejo-tag.sh"

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
go_series="$(awk -F'[ .]' '$1 == "go" { print $2 "\\." $3; exit }' "$gomod")"
assert_contains "$dockerfile" "^ARG GO_BASE=dhi\\.io/golang:${go_series}\\.[0-9]+-alpine3\\.24-dev@sha256:[a-f0-9]{64}$" \
  'builder uses a digest-pinned DHI Go image matching go.mod on Alpine 3.24'
assert_contains "$dockerfile" '^ARG RUNTIME_BASE=dhi\.io/alpine-base:3\.24-dev@sha256:[a-f0-9]{64}$' \
  'runtime uses a digest-pinned DHI Alpine 3.24 dev image'
assert_contains "$dockerfile" '^ARG GEESEFS_VERSION=v[0-9]+\.[0-9]+\.[0-9]+$' \
  'GeeseFS uses an explicit release'
assert_contains "$dockerfile" '^ARG GEESEFS_SOURCE_SHA256=[a-f0-9]{64}$' \
  'GeeseFS source has an explicit SHA-256'
assert_contains "$dockerfile" '^ARG GEESEFS_X_CRYPTO_VERSION=v[0-9]+\.[0-9]+\.[0-9]+$' \
  'GeeseFS x/crypto security override is pinned'
assert_contains "$dockerfile" '^ARG GEESEFS_X_NET_VERSION=v[0-9]+\.[0-9]+\.[0-9]+$' \
  'GeeseFS x/net security override is pinned'
assert_contains "$dockerfile" '^ARG GEESEFS_GRPC_VERSION=v[0-9]+\.[0-9]+\.[0-9]+$' \
  'GeeseFS gRPC security override is pinned'
assert_contains "$dockerfile" '^ARG GEESEFS_X_TEXT_VERSION=v[0-9]+\.[0-9]+\.[0-9]+$' \
  'GeeseFS x/text security override is pinned'
assert_contains "$dockerfile" '-require=google\.golang\.org/grpc@\$\{GEESEFS_GRPC_VERSION\}' \
  'GeeseFS build applies the gRPC security override'
assert_contains "$dockerfile" '-require=golang\.org/x/text@\$\{GEESEFS_X_TEXT_VERSION\}' \
  'GeeseFS build applies the x/text security override'
assert_contains "$dockerfile" 'CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build' \
  'GeeseFS is built from verified source'
assert_contains "$dockerfile" 'main\.Version=\$\{GEESEFS_VERSION\}-ym2' \
  'GeeseFS embeds the maintained source version'
assert_contains "$dockerfile" '^ARG RCLONE_VERSION=[0-9]+\.[0-9]+\.[0-9]+-r[0-9]+$' \
  'rclone package version is pinned'
assert_contains "$dockerfile" '^ARG S3FS_FUSE_VERSION=[0-9]+\.[0-9]+-r[0-9]+$' \
  's3fs-fuse package version is pinned'

# Edge checks: known non-deterministic upstream patterns stay absent.
assert_not_contains "$dockerfile" '(:latest|/latest/|alpine/edge)' \
  'Dockerfile contains no latest tag, latest download, or Alpine edge repository'
assert_not_contains "$dockerfile" '^[[:space:]]*ADD[[:space:]]+https?://' \
  'Dockerfile does not use an unverified remote ADD'
assert_not_contains "$dockerfile" 'releases/download/.*/geesefs-linux-amd64' \
  'Dockerfile does not consume the vulnerable upstream GeeseFS binary'
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
assert_contains "$renovate" 'google\\\\\.golang\\\\\.org/grpc' \
  'Renovate tracks the GeeseFS gRPC security override'
assert_contains "$renovate" 'golang\\\\\.org/x/text' \
  'Renovate tracks the GeeseFS x/text security override'
assert_file "$actions" 'Forgejo Actions validation workflow exists'
assert_contains "$actions" 'go mod verify' 'Forgejo Actions verifies Go module content'
assert_contains "$actions" 'go test ./\.\.\. -run' 'Forgejo Actions compiles the complete Go test suite'
assert_file "$woodpecker_validate" 'Woodpecker validation pipeline exists'
assert_contains "$woodpecker_validate" 'make test' 'Woodpecker runs the complete privileged CSI suite'
assert_file "$woodpecker" 'Woodpecker release pipeline exists'
assert_file "$release_actions" 'Forgejo automatic release-tag workflow exists'
assert_file "$tag_resolver" 'deterministic fork-tag resolver exists'
assert_file "$tag_creator" 'immutable Forgejo tag creator exists'
assert_contains "$release_actions" 'isityael/dhi-hardening' \
  'automatic release targets the maintained branch'
assert_contains "$release_actions" 'github\.server_url.*/api/v1' \
  'automatic release uses the canonical Forgejo API'
assert_contains "$release_actions" 'Dockerfile' \
  'runtime Dockerfile changes trigger automatic release'
assert_contains "$woodpecker" 'linux/amd64' 'Woodpecker publishes only linux/amd64'
assert_contains "$woodpecker" 'ghcr\.io/isityael/csi-s3-driver' 'Woodpecker publishes the owned GHCR image'
assert_contains "$woodpecker" 'COSIGN_EXPERIMENTAL: "1"' 'Woodpecker enables OCI 1.1 Cosign referrers'
assert_contains "$woodpecker" 'cosign verify .*--experimental-oci11' \
  'Woodpecker verifies the candidate signature through OCI 1.1 referrers'
sign_line="$(grep -n -- 'name: sign-candidate' "$woodpecker" | cut -d: -f1)"
promote_line="$(grep -n -- 'name: promote-release' "$woodpecker" | cut -d: -f1)"
if [ -n "$sign_line" ] && [ -n "$promote_line" ] && [ "$sign_line" -lt "$promote_line" ]; then
  pass 'Woodpecker signs before publishing release tags'
else
  fail 'Woodpecker signs before publishing release tags'
fi

printf '\nPolicy checks: %s passed, %s failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
