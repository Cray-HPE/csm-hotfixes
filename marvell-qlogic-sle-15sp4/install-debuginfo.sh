#!/usr/bin/env bash
#
#  MIT License
#
#  (C) Copyright 2023 Hewlett Packard Enterprise Development LP
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
KVER=5.14.21-150400.24.92.1.27088.1.PTF.1215587
function usage {
cat << EOF
Installs debuginfo for "$KVER"
usage:

./install-debuginfo.sh

EOF
}
while getopts ":" o; do
    case "${o}" in
        *)
            usage
            exit 0
            ;;
    esac
done

# MUST USE SINGLE QUOTES, or hardcode sp4 into the path.
zypper --no-gpg-checks --plus-repo 'https://packages.local/repository/qlogic-hotfix-sle-${releasever_major}sp${releasever_minor}' in -y kernel-default-debuginfo="$KVER"

