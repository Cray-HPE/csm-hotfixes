#!/usr/bin/env bash
#
# MIT License
#
# (C) Copyright 2024 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
set -eo pipefail

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."
source "${ROOTDIR}/lib/install.sh"
REPO_GROUPS=(
  'csm-sle-15sp3'
  'csm-sle-15sp4'
)

load-install-deps

# Deletes any given nexus repository by name.
function nexus-delete-repo() {
  nexus-get-credential
  local name="${1:-}"
  local error=0
  printf >&2 "Deleting %s ..." "$name"
  if ! curl \
    -fLs \
    -u "${NEXUS_USERNAME}":"${NEXUS_PASSWORD}" \
    -X DELETE \
    "${NEXUS_URL}/service/rest/v1/repositories/${name}"; then
    error=1
  fi
  if [ "$error" -ne 0 ]; then
    echo >&2 'Errors found.'
  else
    echo 'Done'
  fi
  return "$error"
}

# Returns the member repository of the CSM noos repository group.
function get-repo-members {
  local repository_group_type
  local repository_group_name
  local repositories

  repository_group_name="${1:-}"
  repository_group_type="${2:-raw}"
  nexus-get-credential
  repositories=$(curl -fLs -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" -X GET "${NEXUS_URL}/service/rest/v1/repositories/${repository_group_type}/group/${repository_group_name}" | jq -r '.group.memberNames')
  if [ "$repositories" = 'null' ] || [ -z "$repositories" ] || [ "$repositories" = '[]' ]; then
    echo >&2 "Could not resolve a member repository for $repository_group_name (type: $repository_group_type)!"
    return 1
  fi
  echo "$repositories"
}

# Returns a JSON payload of all the artifacts within a given repository.
function get-artifact-list {
  nexus-get-credential
  local repo_name
  repo_name="$1"
  if [ -z "$repo_name" ]; then
    echo >&2 'Can not get artifacts, no repository name was resolved.'
    return 1
  fi

  local items
  local continuationToken
  response="$(curl -fLs -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" -X GET "${NEXUS_URL}/service/rest/v1/components?repository=${repo_name}")"
  continuationToken="$(jq -n --argjson response "$response" -r '$response.continuationToken')"
  items="$(jq -n --argjson response "$response" -r '$response.items')"
  while [ "$continuationToken" != 'null' ]; do
    response="$(curl -fLs -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" -X GET "${NEXUS_URL}/service/rest/v1/components?repository=${repo_name}&continuationToken=${continuationToken}")"
    continuationToken="$(jq -n --argjson response "$response" -r '$response.continuationToken')"
    items="$(jq -n --argjson items "$items" --argjson response "$response" '$items + $response.items')"
  done
  echo "$items"
}

# Downloads items based on the Nexus components payload structure and returns their download location.
function download-items {
  nexus-get-credential
  local items
  local decoded
  local artifact_path
  local download_url
  items="$1"
  if [ -z "$items" ]; then
    echo >&2 'No items to download!'
    return 1
  fi
  workdir="$ROOTDIR/$(mktemp -d .rpm-XXXXXXX)"
  for item in $(jq -r '.[] | @base64' <(echo "$items")); do
    decoded="$(echo "$item" | base64 --decode | jq -r)"
    dir="${workdir}$(jq -r '.group' <(echo "$decoded"))"
    mkdir -p "$dir"
    download_url="$(jq -r '.assets[0].downloadUrl' <(echo "$decoded"))"
    artifact_path="$(jq -r '.assets[0].path' <(echo "$decoded"))"
    curl -fLs -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" -o "${workdir}/${artifact_path}" "${download_url}" || return "$?"
  done
  echo "$workdir"
}

error=0
for repository_group in "${REPO_GROUPS[@]}"; do
  printf "Resolving repository member(s) for %s ... " "${repository_group}"
  repositories="$(if ! get-repo-members "${repository_group}"; then echo "" ; fi)"
  if [ -n "$repositories" ]; then
    echo 'Done'
  else
    echo >&2 'Failed!'
    error=1
    break
  fi
  yq4 eval '.name="'"$repository_group"'"' "${ROOTDIR}/nexus-repositories-group.template.yaml" > "${ROOTDIR}/nexus-${repository_group}-repository-group.yaml"
  nexus-delete-repo "$repository_group"
  for encoded_repository in $(jq -r '.[] | @base64' <(echo "$repositories")); do
    repository="$(echo "$encoded_repository" | base64 --decode)"
    echo "Working on repository: $repository"

    if [ -d "${ROOTDIR}/$repository" ]; then
      printf "Found [%s] in hotfix directory from previous run. Cleaning ... " "$repository"
      rm -rf "${ROOTDIR:?}/${repository:?}"
      echo 'Done'
    fi

    printf "Resolving artifacts ... "
    artifacts=$(get-artifact-list "$repository")
    if [ -n "$artifacts" ]; then
      echo 'Done'
    else
      echo >&2 'Failed!'
      error=1
      break
    fi

    printf 'Downloading resolved artifacts ... '
    downloads="$(download-items "$artifacts")"
    if [ ! -d "$downloads" ]; then
      echo >&2 'Failed!'
      error=1
      break
    else
      mv "$downloads" "$repository"
      echo 'Done'
    fi

    printf 'Copying hotfix RPMs into downloaded repository %s ... ' "$repository"
    if rsync -rltDq --exclude index.yaml --exclude index.yml "${ROOTDIR}/rpm/" "${ROOTDIR}/${repository}/"; then
      echo 'Done'
    else
      echo >&2 'Failed!'
      error=1
      break
    fi

    createrepo "$repository"

    nexus-delete-repo "$repository"

    export repository
    # shellcheck disable=SC2016

    yq4 eval -i '.group.memberNames +="'"$repository"'"' "${ROOTDIR}/nexus-${repository_group}-repository-group.yaml"
    yq4 eval '.name="'"$repository"'"' "${ROOTDIR}/nexus-repository.template.yaml" > "${ROOTDIR}/nexus-${repository}-repository.yaml"

    echo "Creating repository [$repository] ... "
    nexus-setup repositories "${ROOTDIR}/nexus-${repository}-repository.yaml"

    echo "Uploading artifacts ... "
    nexus-upload raw "$repository/" "$repository"
    nexus-wait-for-rpm-repomd "$repository"

  done
  echo "Creating repository group [$repository_group] ... "
  nexus-setup repositories "${ROOTDIR}/nexus-${repository_group}-repository-group.yaml"
done
if [ "$error" -ne 0 ]; then
  exit 1
fi

# Upload assets to existing repositories
skopeo-sync "${ROOTDIR}/docker"
nexus-upload helm "${ROOTDIR}/helm" "${CHARTS_REPO:-"charts"}"

clean-install-deps

cat >&2 << EOF
+ Nexus setup complete
setup-nexus.sh: OK
EOF
