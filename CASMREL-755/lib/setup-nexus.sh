#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

set -exo pipefail

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."
source "${ROOTDIR}/lib/install.sh"

load-install-deps

# Upload assets to existing repositories
skopeo-sync "${ROOTDIR}/docker"
nexus-upload helm "${ROOTDIR}/helm" "${CHARTS_REPO:-"charts"}"

nexus-setup repositories "${ROOTDIR}/nexus-repositories.yaml"
nexus-wait-for-rpm-repomd casmrel-755
nexus-upload yum "${ROOTDIR}/rpm" casmrel-755

clean-install-deps

set +x
cat >&2 <<EOF
+ Nexus setup complete
setup-nexus.sh: OK
EOF
