#!/usr/bin/env bash
set -euo pipefail

if (($# != 2)); then
  printf 'usage: %s <release-tag> <commit-sha>\n' "$0" >&2
  exit 2
fi

tag="$1"
commit="$2"
: "${FORGEJO_API_URL:?FORGEJO_API_URL is required}"
: "${FORGEJO_REPOSITORY:?FORGEJO_REPOSITORY is required}"
: "${FORGEJO_TOKEN:?FORGEJO_TOKEN is required}"

[[ "${tag}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+-ym\.[1-9][0-9]*$ ]] || {
  printf 'refusing non-canonical release tag: %s\n' "${tag}" >&2
  exit 2
}
[[ "${commit}" =~ ^[0-9a-f]{40}$ ]] || {
  printf 'refusing invalid commit SHA: %s\n' "${commit}" >&2
  exit 2
}

response_file="$(mktemp)"
trap 'rm -f "${response_file}"' EXIT
status="$(curl --silent --show-error --output "${response_file}" --write-out '%{http_code}' \
  --request POST --header "Authorization: token ${FORGEJO_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data "$(printf '{\"tag_name\":\"%s\",\"target\":\"%s\"}' "${tag}" "${commit}")" \
  "${FORGEJO_API_URL}/repos/${FORGEJO_REPOSITORY}/tags")"

[[ "${status}" == 201 ]] || {
  printf 'Forgejo tag creation failed with HTTP %s\n' "${status}" >&2
  exit 1
}
