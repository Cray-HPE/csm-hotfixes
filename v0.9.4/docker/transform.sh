#!/usr/bin/env bash

# Copyright 2020 Hewlett Packard Enterprise Development LP

# Moves docker directories to locations where helm charts will be expecting them

set -e

DISTDIR=$1

# Transform images to 1.4 dtr.dev.cray.com structure
(
    cd "${DISTDIR}"
    mkdir dtr.dev.cray.com
    mv arti.dev.cray.com/csm-docker-stable-local/ dtr.dev.cray.com/cray/
)
