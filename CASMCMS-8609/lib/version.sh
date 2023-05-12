#!/usr/bin/env bash

# Copyright 2023 Hewlett Packard Enterprise Development LP

: "${RELEASE:="${RELEASE_NAME:="CASMCMS-8609"}-${RELEASE_VERSION:="2.0.12"}"}"

# return if sourced
return 0 2>/dev/null

# otherwise print release information
if [[ $# -eq 0 ]]; then
    echo "$RELEASE"
else
    case "$1" in
    -n|--name) echo "$RELEASE_NAME" ;;
    -v|--version) echo "$RELEASE_VERSION" ;;
    *)
        echo >&2 "error: unsupported argumented: $1"
        echo >&2 "usage: ${0##*/} [--name|--version]"
        ;;
    esac
fi
