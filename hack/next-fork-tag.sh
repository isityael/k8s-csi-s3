#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
commit="${1:-HEAD}"
upstream_version="$(sed -n 's/^ARG GEESEFS_VERSION=\(v[0-9][0-9.]*\)$/\1/p' "${repo_root}/Dockerfile" | head -n 1)"

[[ "${upstream_version}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  printf 'invalid GEESEFS_VERSION: %s\n' "${upstream_version:-<missing>}" >&2
  exit 1
}

target_commit="$(git rev-parse --verify "${commit}^{commit}")"
max_revision=0
existing_tag=""

while IFS= read -r tag; do
  revision=""
  case "${tag}" in
    "${upstream_version}-ym") revision=1 ;;
    "${upstream_version}-ym"[0-9]*) revision="${tag#"${upstream_version}-ym"}" ;;
    "${upstream_version}-ym."[0-9]*) revision="${tag#"${upstream_version}-ym."}" ;;
  esac
  [[ "${revision}" =~ ^[1-9][0-9]*$ ]] || continue
  ((revision > max_revision)) && max_revision="${revision}"
  if [[ "$(git rev-list -n 1 "${tag}")" == "${target_commit}" ]]; then
    existing_tag="${tag}"
  fi
done < <(git tag --list "${upstream_version}-ym*")

if [[ -n "${existing_tag}" ]]; then
  printf 'tag=%s\ncreate=false\n' "${existing_tag}"
else
  printf 'tag=%s-ym.%d\ncreate=true\n' "${upstream_version}" "$((max_revision + 1))"
fi
