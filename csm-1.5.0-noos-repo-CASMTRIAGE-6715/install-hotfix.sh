#!/usr/bin/env bash
#
#  MIT License
#
#  (C) Copyright 2024 Hewlett Packard Enterprise Development LP
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
set -e
ROOT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOT_DIR}/lib/version.sh"

function usage {

  cat << EOF
usage:

./install-hotfix.sh [-y]

Flags:
-y      Respond with "yes" to any and all prompts; performs a non-interactive run of this script.
EOF
}

interactive=1
while getopts ":y" o; do
  case "${o}" in
    y)
      interactive=0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done
shift $((OPTIND - 1))

if [ "$interactive" -eq 1 ]; then
    read -r -p "This hotfix will modify the csm-noos repository by destroying and recreating it with additional content added. This is irreversible. Proceed? [y/n]:" response
    case "$response" in
        [yY][eE][sS]|[yY])
            :
            ;;
        *)
            echo 'Exiting cleanly ...'
            exit 0
            ;;
    esac
else
    echo 'non-interactive was specified.'
fi

# Load artifacts into nexus
"${ROOT_DIR}/lib/setup-nexus.sh"

cat >&2 <<EOF
+ Hotfix installed
${0##*/}: OK
EOF
