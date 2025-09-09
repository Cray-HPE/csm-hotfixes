#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

set -exo pipefail

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."
source "${ROOTDIR}/lib/install.sh"

load-install-deps

# Upload assets to existing repositories
skopeo-sync "${ROOTDIR}/docker"
nexus-upload helm "${ROOTDIR}/helm" "${CHARTS_REPO:-"charts"}"

clean-install-deps

set +x
cat >&2 <<EOF
+ Nexus setup complete
setup-nexus.sh: OK
EOF
