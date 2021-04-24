#!/usr/bin/env bash

# Copyright 2020 Hewlett Packard Enterprise Development LP

set -e
set -o pipefail

: "${RELEASE:="${RELEASE_NAME:="csm"}-${RELEASE_VERSION:="0.0.0"}"}"

# import release utilities
ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOTDIR}/vendor/stash.us.cray.com/scm/shastarelm/release/lib/release.sh"

requires curl git perl rsync sed

HOTFIX="$1"

BUILDDIR=$(realpath -m "$ROOTDIR/dist/${HOTFIX}")
HOTFIXDIR=$(realpath -m "$ROOTDIR/${HOTFIX}")
if [[ -z "$HOTFIX" || ! -d "${HOTFIXDIR}" ]]; then
  echo >&2 "error: First argument must be name of hotfix directory to package"
  exit 1
fi

VERSION="0.0.1"
if [[ -f "$HOTFIXDIR/.version" ]]; then
  VERSION="$(cat "$HOTFIXDIR/.version" | tr -d '\n')"
  echo "Using version $VERSION"
fi

[[ -d "$BUILDDIR" ]] && rm -fr "$BUILDDIR"
mkdir -p "$BUILDDIR"

# copy local files
rsync -aq "${HOTFIXDIR}/" "${BUILDDIR}/"

# copy install scripts
mkdir -p "${BUILDDIR}/lib"
rsync -aq "${ROOTDIR}/vendor/stash.us.cray.com/scm/shastarelm/release/lib/" "${BUILDDIR}/lib/"

# sync helm charts
if [[ -f "${BUILDDIR}/helm/index.yaml" ]]; then
  echo "Syncing Helm ${BUILDDIR}/helm/index.yaml"
  helm-sync "${BUILDDIR}/helm/index.yaml" "${BUILDDIR}/helm"
fi

if [[ -f "${BUILDDIR}/docker/index.yaml" ]]; then
  echo "Syncing Docker ${BUILDDIR}/docker/index.yaml"
  skopeo-sync "${BUILDDIR}/docker/index.yaml" "${BUILDDIR}/docker"

  # save quay.io/skopeo/stable images for use in install.sh
  echo "Copying skopeo image to distribution"
  vendor-install-deps --no-cray-nexus-setup "$(basename "$BUILDDIR")" "${BUILDDIR}/vendor"
fi

if [[ -f "${BUILDDIR}/rpm/index.yaml" ]]; then
  echo "Syncing RPM ${BUILDDIR}/rpm/index.yaml"
  rpm-sync "${BUILDDIR}/rpm/index.yaml" "${BUILDDIR}/rpm"
fi

# Run hotfix/release.sh
if [[ -f "${BUILDDIR}/release.sh" ]]; then
  echo "Running ${BUILDDIR}/release.sh"
  (
    cd "${BUILDDIR}"
    chmod +x ./release.sh
    ./release.sh
  )
fi


# Package the distribution into an archive
echo "Generating distribution tarball"
tar -C "${BUILDDIR}/.." -cvzf "${BUILDDIR}/../$(basename "$BUILDDIR")-${VERSION}.tar.gz" "$(basename "$BUILDDIR")/" --remove-files
