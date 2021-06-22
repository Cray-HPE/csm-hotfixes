#!/usr/bin/env bash

# Copyright 2020 Hewlett Packard Enterprise Development LP

set -o errexit
set -o pipefail

[[ $# -gt 0 ]] || {
  echo >&2 "usage: ${0##*/} DIR ..."
  exit 1
}

set -o xtrace

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"

# Import release utilities
source "${ROOTDIR}/vendor/stash.us.cray.com/scm/shastarelm/release/lib/release.sh"
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

  if [[ "$HOTFIX" =~ ^v.*$ ]]; then
    # Assume the name of the hotfix directory is the version number
    RELEASE_NAME="csm-${HOTFIX##v}-hotfix"
  else
    RELEASE_NAME="$HOTFIX"
  fi

  RELEASE_VERSION="0.0.1"
  if [[ -f "$HOTFIXDIR/.version" ]]; then
    RELEASE_VERSION="$(cat "$HOTFIXDIR/.version" | tr -d '\n')"
  fi

  RELEASE="${RELEASE_NAME}-${RELEASE_VERSION}"
  echo "Building release $RELEASE"

  BUILDDIR="$(realpath -m "$ROOTDIR/dist/$RELEASE")"
  [[ -d "$BUILDDIR" ]] && rm -fr "$BUILDDIR"
  mkdir -p "$BUILDDIR"

  # Copy contents to distribution
  cp -LRpT "${HOTFIXDIR}/" "${BUILDDIR}/"

  # Remove index files from distribution
  rm -f "${BUILDDIR}/docker/index.yaml" "${BUILDDIR}/docker/transform.sh" "${BUILDDIR}/helm/index.yaml"

  # Add version.sh
  mkdir -p "${BUILDDIR}/lib"
  gen-version-sh "$RELEASE_NAME" "$RELEASE_VERSION" >"${BUILDDIR}/lib/version.sh"
  chmod +x "${BUILDDIR}/lib/version.sh"

  # Sync RPMs (not supported)
  if [[ -f "${HOTFIXDIR}/rpm/index.yaml" ]]; then
    echo "Syncing RPM index"
    rm -f "${BUILDDIR}/rpm/index.yaml"
    echo >&2 "Error: Not supported"
    exit 2
    #rpm-sync "${HOTFIXDIR}/rpm/index.yaml" "${BUILDDIR}/rpm"
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

  # Vendor install tools for container images
  [[ -d "${BUILDDIR}/docker" ]]; then
    echo "Vendoring skopeo image in distribution"
    vendor-install-deps --no-cray-nexus-setup "$(basename "$BUILDDIR")" "${BUILDDIR}/vendor"
  fi

  # Vendor install tools for helm charts
  if [[ -d "${BUILDDIR}/helm" ]]; then
    echo "Vendoring cray-nexus-setup image in distribution"
    vendor-install-deps --no-skopeo "$(basename "$BUILDDIR")" "${BUILDDIR}/vendor"
  fi

  # Package the distribution into an archive
  echo "Generating distribution tarball"
  tar -C "${BUILDDIR}/.." -cvhzf "${BUILDDIR}/../$(basename "$BUILDDIR").tar.gz" "$(basename "$BUILDDIR")/" --remove-files
done
