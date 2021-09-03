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

cat > /tmp/casmrel-655-repo.yaml << EOF
---
cleanup: null
type: hosted
format: yum
yum:
  repodataDepth: 0
  deployPolicy: STRICT
name: casmrel-655
online: true
storage:
  blobStoreName: default
  strictContentTypeValidation: false
  writePolicy: ALLOW_ONCE
EOF

nexus-repositories-create "/tmp" "/tmp/casmrel-655-repo.yaml"
nexus-upload yum "${ROOTDIR}/rpm" "casmrel-655"

set +x
cat >&2 <<EOF
+ Nexus setup complete
setup-nexus.sh: OK
EOF
