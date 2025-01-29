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

# Make sure that patch_services and patch_rpms variables are each set to Y or N
# These should have been set and exported by the calling script
if [[ ${patch_rpms} != Y && ${patch_rpms} != N ]]; then
    echo >&2 "$0: PROGRAMMING LOGIC ERROR: patch_rpms variable not set or set to an illegal value"
    exit 1
fi

ROOTDIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")
source "${ROOTDIR}/lib/install.sh"

load-install-deps

# Deletes any given nexus repository by name.
function nexus-delete-repo() {
    local name error
    nexus-get-credential
    name="${1:-}"
    printf >&2 "Deleting %s ..." "$name"
    if ! curl -fLs \
              -u "${NEXUS_USERNAME}":"${NEXUS_PASSWORD}" \
              -X DELETE \
              "${NEXUS_URL}/service/rest/v1/repositories/${name}"
    then
        echo >&2 'Errors found.'
        return 1
    fi
    echo 'Done'
}

# Returns the member repository of the specified CSM repository group.
function get-repo-group-member {
    local group
    group="$1"    
    if [[ -z $group ]]; then
        echo >&2 "$0: PROGRAMMING LOGIC ERROR: Blank repo group specified"
        return 1
    fi
    nexus-get-credential
    local repo_name
    repo_name=$(curl -fLs -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" -X GET "${NEXUS_URL}/service/rest/v1/repositories/raw/group/${group}" | jq -r '.group.memberNames[0]')
    if [[ $repo_name == null || -z $repo_name ]]; then
        echo >&2 "Could not resolve a member repository for repo group ${group}!"
        return 1
    fi
    echo "$repo_name"
}

# Returns a JSON payload of all the artifacts within a given repository.
function get-artifact-list {
    nexus-get-credential
    local repo_name
    repo_name="$1"
    if [[ -z $repo_name ]]; then
        echo >&2 'Can not get artifacts, no repository name was resolved.'
        return 1
    fi

    local items
    local continuationToken
    response="$(curl -fLs -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" -X GET "${NEXUS_URL}/service/rest/v1/components?repository=${repo_name}")"
    continuationToken="$(jq -n --argjson response "$response" -r '$response.continuationToken')"
    items="$(jq -n --argjson response "$response" -r '$response.items')"
    while [[ $continuationToken != null ]]; do
        response="$(curl -fLs -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" -X GET "${NEXUS_URL}/service/rest/v1/components?repository=${repo_name}&continuationToken=${continuationToken}")"
        continuationToken="$(jq -n --argjson response "$response" -r '$response.continuationToken')"
        items="$(jq -n --argjson items "$items" --argjson response "$response" '$items + $response.items')"
    done
    echo "$items"
}

# Downloads items based on the Nexus components payload structure and returns their download location.
function download-items {
    nexus-get-credential
    local items decoded dir artifact_path download_url workdir
    items="$1"
    if [[ -z $items ]]; then
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

function process_repo_group {
    local repository artifacts downloads group
    group="$1"
    if [[ -z $group ]]; then
        echo >&2 "$0: PROGRAMMING LOGIC ERROR: Blank repo group specified"
        return 1
    fi

    printf "Looking up repository group member for repo group ${group} ..."
    repository=$(get-repo-group-member "${group}")
    echo 'Done'

    echo "Working on repository: $repository"

    if [[ -d "${ROOTDIR}/${repository}" ]]; then
        printf "Found [%s] in hotfix directory from previous run. Renaming it ..." "$repository"
        mv -v "${ROOTDIR}/${repository}" "${ROOTDIR}/${repository}.$(date +%Y%m%d%H%M%S)"
        echo 'Done'
    fi

    printf "Resolving artifacts ... "
    artifacts=$(get-artifact-list "$repository")
    if [[ -z $artifacts ]]; then
        echo >&2 'Failed!'
        return 1
    fi
    echo 'Done'

    printf 'Downloading resolved artifacts ... '
    downloads="$(download-items "$artifacts")"
    if [[ -z $downloads || ! -d $downloads ]]; then
        echo >&2 'Failed!'
        return 1
    fi
    echo 'Done'

    mv -v "$downloads" "${ROOTDIR}/${repository}"

    printf 'Copying hotfix RPMs into downloaded repository %s ... ' "$repository"
    if ! rsync -rltDq --exclude index.yaml --exclude index.yml "${ROOTDIR}/rpm/${group}/" "${ROOTDIR}/${repository}/"; then
        echo 'Failed!'
        return 1
    fi
    echo 'Done'

    createrepo "${ROOTDIR}/${repository}"

    nexus-delete-repo "${group}"
    nexus-delete-repo "$repository"

    export repository
    export group
    # shellcheck disable=SC2016
    envsubst '$group $repository' < "${ROOTDIR}/nexus-repositories.template.yaml" > "${ROOTDIR}/nexus-repositories-${repository}.yaml"

    echo "Creating repository [$repository] and repository group [$group] ... "
    nexus-setup repositories "${ROOTDIR}/nexus-repositories-${repository}.yaml"

    echo "Uploading artifacts ... "
    nexus-upload raw "${ROOTDIR}/${repository}/" "$repository"
    nexus-wait-for-rpm-repomd "$repository"

    echo "Successfully completed processing ${repository}"
}

# Upload assets to existing repositories

if [[ ${patch_rpms} == Y ]]; then
    # Upload RPMs to repositories
    pushd "${ROOTDIR}/rpm"
    for group in * ; do
        process_repo_group "${group}"
    done
    popd
fi

clean-install-deps

set +x
cat >&2 <<EOF
+ Nexus setup complete
setup-nexus.sh: OK
EOF
