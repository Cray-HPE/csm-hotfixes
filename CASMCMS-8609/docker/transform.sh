#!/usr/bin/env bash

# Copyright 2023 Hewlett Packard Enterprise Development LP

# Moves docker directories to locations where helm charts will be expecting them

set -e

DISTDIR=$1

# Transform images to 1.4 dtr.dev.cray.com structure
(
    cd "${DISTDIR}"
    mkdir dtr.dev.cray.com
    mv -v artifactory.algol60.net/csm-docker/stable/ dtr.dev.cray.com/cray/
)
