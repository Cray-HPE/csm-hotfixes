#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

set -exo pipefail

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."
source "${ROOTDIR}/lib/install.sh"

load-install-deps

# Upload assets to existing repositories
cat > /tmp/casmrel-755-repo.yaml << EOF
---
cleanup: null
type: hosted
format: yum
yum:
  repodataDepth: 0
  deployPolicy: STRICT
name: casmrel-776
online: true
storage:
  blobStoreName: default
  strictContentTypeValidation: false
  writePolicy: ALLOW_ONCE
EOF

nexus-repositories-create "/tmp" "/tmp/casmrel-776-repo.yaml"
nexus-upload yum "${ROOTDIR}/rpm" "casmrel-776"

clean-install-deps

set +x
cat >&2 <<EOF
+ Nexus setup complete
setup-nexus.sh: OK
EOF
