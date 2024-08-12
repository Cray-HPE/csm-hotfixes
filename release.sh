#!/usr/bin/env bash
#
#  MIT License
#
#  (C) Copyright 2022-2024 Hewlett Packard Enterprise Development LP
#
#  Permission is hereby granted, free of charge, to any person obtaining a
#  copy of this software and associated documentation files (the "Software"),
#  to deal in the Software without restriction, including without limitation
#  the rights to use, copy, modify, merge, publish, distribute, sublicense,
#  and/or sell copies of the Software, and to permit persons to whom the
#  Software is furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included
#  in all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
#  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
#  OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
#  ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
#  OTHER DEALINGS IN THE SOFTWARE.
#

set -o errexit
set -o pipefail

[[ $# -gt 0 ]] || {
  echo >&2 "usage: ${0##*/} DIR ..."
  exit 1
}

set -o xtrace

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"

# Override tools images
export PACKAGING_TOOLS_IMAGE=${PACKAGING_TOOLS_IMAGE:-artifactory.algol60.net/dst-docker-mirror/internal-docker-stable-local/packaging-tools:0.14.0}
export RPM_TOOLS_IMAGE=${RPM_TOOLS_IMAGE:-artifactory.algol60.net/dst-docker-mirror/internal-docker-stable-local/rpm-tools:1.0.0}
export SKOPEO_IMAGE=${SKOPEO_IMAGE:-artifactory.algol60.net/dst-docker-mirror/quay-remote/skopeo/stable:v1.13.2}
export CRAY_NEXUS_SETUP_IMAGE=${CRAY_NEXUS_SETUP_IMAGE:-artifactory.algol60.net/csm-docker/stable/cray-nexus-setup:0.7.1}
export CFS_CONFIG_UTIL_IMAGE=${CFS_CONFIG_UTIL_IMAGE:-arti.hpc.amslabs.hpecorp.net/csm-docker-remote/stable/cfs-config-util:5.0.0}

# code to store credentials in environment variable
if [ ! -z "$ARTIFACTORY_USER" ] && [ ! -z "$ARTIFACTORY_TOKEN" ]; then
  export REPOCREDSVARNAME="REPOCREDSVAR"
  export REPOCREDSVAR=$(jq --null-input --arg url "https://artifactory.algol60.net/artifactory/" --arg realm "Artifactory Realm" --arg user "$ARTIFACTORY_USER"   --arg password "$ARTIFACTORY_TOKEN"   '{($url): {"realm": $realm, "user": $user, "password": $password}}')
fi

# Import release utilities
source "${ROOTDIR}/vendor/github.hpe.com/hpe/hpc-shastarelm-release/lib/release.sh"
requires cp sed

while [[ $# -gt 0 ]]; do

  if [[ -d "$1" ]]; then
    HOTFIXDIR="$(realpath -e --relative-to="$(pwd)" "$1")"
  elif [[ -d "${ROOTDIR}/${1}" ]]; then
    HOTFIXDIR="$(realpath -e --relative-to="$(pwd)" "${ROOTDIR}/${1}")"
  else
    echo >&2 "error: no such directory: $1"
    exit 1
  fi

  shift
  HOTFIX="$(basename "$HOTFIXDIR")"

  if [[ ! -x "${HOTFIXDIR}/lib/version.sh" ]]; then
    echo >&2 "error: missing version script or is not executable: ${HOTFIXDIR}/lib/version.sh"
    exit 2
  fi

  source "${HOTFIXDIR}/lib/version.sh"
  echo "Building release $RELEASE"

  BUILDDIR="$(realpath -m "$ROOTDIR/dist/$RELEASE")"
  [[ -d "$BUILDDIR" ]] && rm -fr "$BUILDDIR"
  mkdir -p "$BUILDDIR"

  # Copy contents to distribution
  cp -LRpT "${HOTFIXDIR}/" "${BUILDDIR}/"

  # Make sure the old .version file is gone!
  rm -f "${BUILDDIR}/.version"

  # Remove index files from distribution
  rm -f "${BUILDDIR}/docker/index.yaml" "${BUILDDIR}/docker/transform.sh" "${BUILDDIR}/helm/index.yaml"

  # Sync RPMs (not supported)
  if [[ -d "${HOTFIXDIR}/rpm" ]]; then
    # Done in a sub-shell to avoid changing the global shopts
    (
      cd "${HOTFIXDIR}"
      shopt -s globstar nullglob dotglob
      for indexfile in rpm/**/index.yaml ; do
        echo "Syncing RPM index ${indexfile}"
        reldir=$(dirname "$indexfile")
        rpm-sync "${indexfile}" "${BUILDDIR}/${reldir}"
      done

      for repofile in rpm/**/.createrepo ; do
        reldir=$(dirname "$repofile")
        echo "Running createrepo on RPMs in ${reldir}"
        rm -f "${repofile}"
        createrepo "${BUILDDIR}/${reldir}"
      done
    )
  fi

  # Sync container images
  if [[ -f "${HOTFIXDIR}/docker/index.yaml" ]]; then
    echo "Syncing container images"
    skopeo-sync "${HOTFIXDIR}/docker/index.yaml" "${BUILDDIR}/docker"
    # Restructure container images as appropriate
    [[ -x "${HOTFIXDIR}/docker/transform.sh" ]] && "${HOTFIXDIR}/docker/transform.sh" "${BUILDDIR}/docker"
  fi

  # Sync helm charts
  if [[ -f "${HOTFIXDIR}/helm/index.yaml" ]]; then
    echo "Syncing Helm charts"
    helm-sync "${HOTFIXDIR}/helm/index.yaml" "${BUILDDIR}/helm"
  fi

  # Remove empty directories
  find "$BUILDDIR" -empty -type d -delete

  # Vendor skopeo image to upload container images
  if [[ -d "${BUILDDIR}/docker" ]]; then
    echo "Vendoring skopeo image in distribution"
    vendor-install-deps --no-cray-nexus-setup "$(basename "$BUILDDIR")" "${BUILDDIR}/vendor"
  fi

  # Vendor cray-nexus-setup image for Nexus clients
  if [[ -f "${BUILDDIR}/lib/setup-nexus.sh" || -d "${BUILDDIR}/helm" ]]; then
    echo "Vendoring cray-nexus-setup image in distribution"
    vendor-install-deps --no-skopeo "$(basename "$BUILDDIR")" "${BUILDDIR}/vendor"
  fi

  # Vendor rpmtools image to recalculate metadata for RPM repos
  if [[ -d "${BUILDDIR}/rpm" ]]; then
    echo "Vendoring rpmtools image in distribution"
    vendor-install-deps --no-skopeo --no-cray-nexus-setup --include-rpm-tools "$(basename "$BUILDDIR")" "${BUILDDIR}/vendor"
  fi

  # Vendor cfs-config-util image to update CFS configurations
  echo "Vendoring cfs-config-util image in distribution"
  vendor-install-deps --no-skopeo --no-cray-nexus-setup --include-cfs-config-util "$(basename "$BUILDDIR")" "${BUILDDIR}/vendor"

  # Package the distribution into an archive
  echo "Generating distribution tarball"
  tar -C "${BUILDDIR}/.." -cvhzf "${BUILDDIR}/../$(basename "$BUILDDIR").tar.gz" "$(basename "$BUILDDIR")/" --remove-files
done
