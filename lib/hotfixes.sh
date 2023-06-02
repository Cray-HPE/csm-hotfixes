#
# MIT License
#
# (C) Copyright 2023 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#

# Bash functions used in hotfix installers
set -o pipefail

function err_echo
{
    echo "ERROR: $*" >&2
}

function make_hotfix_label
{
    # This label is used for the manifest, and we append a 15 character timestamp string.
    # The result must adhere to K8s naming restrictions:
    # * Length <= 253 characters
    # * Legal characters: lowercase alphanumeric, -, .
    # * Start and end with alphanumeric
    #
    # Thus HOTFIX_LABEL must be <= 238 characters long, consist of the legal characters
    # above, and start with a lowercase alphanumeric.
    local HOTFIX_LABEL

    if [[ $# -gt 1 ]]; then
        err_echo "$0 function requires exactly 0 or 1 argument but received $#: $*"
        return 1
    elif [[ $# -eq 0 ]]; then
        HOTFIX_LABEL="hotfix"
    else
        HOTFIX_LABEL="$1"
        # Replace _ or whitespace with -
        HOTFIX_LABEL=${HOTFIX_LABEL//[_[:space:]]/-}
        # Strip any illegal characters
        HOTFIX_LABEL=${HOTFIX_LABEL//[^-.a-z0-9]/}
        # Strip illegal starting characters from front
        HOTFIX_LABEL=${HOTFIX_LABEL##[^a-z0-9]}
        # For readability, replace repeated - with a single -
        HOTFIX_LABEL=${HOTFIX_LABEL//+(-)/-}
        # And similarly for repeated .
        HOTFIX_LABEL=${HOTFIX_LABEL//+(.)/.}
        # And truncate to 238
        HOTFIX_LABEL=${HOTFIX_LABEL::238}
        # If after all of this it ends up being blank, then default to the generic "hotfix"
        [[ -n ${HOTFIX_LABEL} ]] || HOTFIX_LABEL=hotfix
    fi

    # Finally, append the timestamp
    echo "${HOTFIX_LABEL}-$(date +%Y%m%d%H%M%S)"
}

function get_deployed_manifest_config_maps
{
    # Looks up all loftsman manifest CMs that have associated -ship-log configmaps showing that they deployed successfully.
    # Creates an array of their names, sorted from most recently deployed to least recently deployed.
    # Stores result in array named manifest_cms_sorted

    # Find all loftsman CMs with label app.kubernetes.io/managed-by=loftsman, excluding those with name suffix -ship-log.
    # Convert the list to a regular expression of the form 'name1|name2|name3|..."namen'
    local manifest_cms_regex manifest_cms_chrono cm
    manifest_cms_regex=$(\
        kubectl get cm -n loftsman -l app.kubernetes.io/managed-by=loftsman -o custom-columns=':.metadata.name' --no-headers |
        grep -v "[-]ship-log$" | tr '\n' '|' | sed 's/|$//' )

    # Create array of corresponding manifest -ship-log CM names in chronological order, from most recent to least recent, then strip off the -ship-log suffixes.
    readarray -t manifest_cms_chrono < <(
        kubectl get cm -n loftsman -l app.kubernetes.io/managed-by=loftsman --sort-by='.metadata.creationTimestamp' \
            -o custom-columns=':.metadata.name' --no-headers |
        grep -E "^(${manifest_cms_regex})-ship-log$" | tac | sed 's/-ship-log$//')

    manifest_cms_sorted=( )
    for cm in "${manifest_cms_chrono[@]}" ; do
        # Did it deploy successfully?
        kubectl get cm -n loftsman "${cm}-ship-log" -o jsonpath='{.data.loftsman\.log}' | 
            jq -r 'select(.message?) | select(.message | startswith("Ship status: success")) | .message' |
            grep -q "^Ship status: success" || continue
        manifest_cms_sorted+=( "${cm}" )
    done
}

function get_latest_charts
{
    # Usage: get_latest_charts
    # Assumes $workdir has been set to working directory
    # Assumes CHART_NAMES has been set to list of desired chart names
    # Writes charts to $workdir/<chart name 1>.yaml $workdir/<chart name 2>.yaml ...
    local manifest_cms_sorted charts_not_found new_charts_not_found cm chart chart_file

    if [[ $# -ne 0 ]]; then
        err_echo "$0 function accepts no arguments but received $#: $*"
        return 1
    elif [[ ${#CHART_NAMES[@]} -eq 0 ]]; then
        err_echo "$0: CHART_NAMES array variable is empty"
        return 1
    elif [[ -z ${workdir} ]]; then
        err_echo "$0: workdir variable not set"
        return 1
    elif [[ ! -e ${workdir} ]]; then
        err_echo "$0: workdir directory does not exist: '${workdir}'"
        return 1
    elif [[ ! -d ${workdir} ]]; then
        err_echo "$0: workdir exists but is not a directory: '${workdir}'"
        return 1
    fi
    
    charts_not_found=("${CHART_NAMES[@]}")
    # Make sure all chart names are valid
    for chart in "${charts_not_found[@]}"; do
        if [[ "${chart}" =~ ^[^a-z0-9] ]]; then
            err_echo "$0: Invalid starting character in chart name: '${chart}'"
            return 1
        elif [[ "${chart}" =~ [^a-z0-9]$ ]]; then
            err_echo "$0: Invalid final character in chart name: '${chart}'"
            return 1
        elif [[ "${chart}" =~ [^-a-z0-9] ]]; then
            err_echo "$0: Invalid characters in chart name: '${chart}'"
            return 1
        fi
    done
    
    get_deployed_manifest_config_maps
    # If no deployed manifests were found, then there is nothing to do
    [[ ${#manifest_cms_sorted[@]} -eq 0 ]] && return

    for cm in "${manifest_cms_sorted[@]}" ; do
        new_charts_not_found=( )
        for chart in "${charts_not_found[@]}" ; do
            chart_file="${workdir}/${chart}.yaml"
            if ! kubectl get cm -n loftsman ${cm} -o jsonpath='{.data.manifest\.yaml}' | yq r -j - | jq -r ".spec?.charts?[] | select(.name? == \"${chart}\")" 2>/dev/null | yq r -P - > "${chart_file}" 2>/dev/null ; then
                # This chart was not found
                [[ -e ${chart_file} ]] && rm "${chart_file}"
                new_charts_not_found+=( "${chart}" )
                continue
            elif [[ ! -s ${chart_file} ]]; then
                # This also means the chart was not found
                [[ -e ${chart_file} ]] && rm "${chart_file}"
                new_charts_not_found+=( "${chart}" )
                continue                
            fi
            echo "Getting chart manifest for '${chart}' from ${cm}"
            # For all hotfix charts, we set the source to csm-algol60
            yq w -i "${chart_file}" 'source' "csm-algol60"
        done
        # Stop if we have found them all
        charts_not_found=("${new_charts_not_found[@]}")
        [[ ${#charts_not_found[@]} -eq 0 ]] && break
    done
    return
}

function merge_charts_into_manifest
{
    # Usage: get_latest_charts
    # Assumes $workdir has been set to working directory
    # Assumes CHART_NAMES has been set to list of desired chart names
    # Assumes YAML files exist for each chart in the target directory
    # Assumes HOTFIX_LABEL has been set
    # Stores resulting file location in $manifest_file
    local chart_file chart_files chart

    if [[ $# -ne 0 ]]; then
        err_echo "$0 function accepts no arguments but received $#: $*"
        return 1
    elif [[ ${#CHART_NAMES[@]} -eq 0 ]]; then
        err_echo "$0: CHART_NAMES array variable is empty"
        return 1
    elif [[ -z ${workdir} ]]; then
        err_echo "$0: workdir variable not set"
        return 1
    elif [[ ! -e ${workdir} ]]; then
        err_echo "$0: workdir directory does not exist: '${workdir}'"
        return 1
    elif [[ ! -d ${workdir} ]]; then
        err_echo "$0: workdir exists but is not a directory: '${workdir}'"
        return 1
    fi
    
    chart_files=()
    # Make sure all chart names are valid and the files exist
    for chart in "${CHART_NAMES[@]}"; do
        if [[ "${chart}" =~ ^[^a-z0-9] ]]; then
            err_echo "$0: Invalid starting character in chart name: '${chart}'"
            return 1
        elif [[ "${chart}" =~ [^a-z0-9]$ ]]; then
            err_echo "$0: Invalid final character in chart name: '${chart}'"
            return 1
        elif [[ "${chart}" =~ [^-a-z0-9] ]]; then
            err_echo "$0: Invalid characters in chart name: '${chart}'"
            return 1
        fi
        chart_file="${workdir}/${chart}.yaml"
        if [[ ! -e ${chart_file} ]]; then
            err_echo "$0: Chart file does not exist: '${chart_file}'"
            return 1
        elif [[ ! -f ${chart_file} ]]; then
            err_echo "$0: Chart file exists but is not a regular file: '${chart_file}'"
            return 1
        elif [[ ! -r ${chart_file} ]]; then
            err_echo "$0: Chart file not readable: '${chart_file}'"
            return 1
        elif [[ ! -w ${chart_file} ]]; then
            err_echo "$0: Chart file not writable: '${chart_file}'"
            return 1
        fi
        chart_files+=( "${chart_file}" )
    done

    # Create hotfix manifest_outline
manifest_file="${workdir}/hotfix_manifest.yaml"
cat <<EOF > "${manifest_file}"
apiVersion: manifests/v1beta1
metadata:
  name: ${HOTFIX_LABEL}
spec:
  sources:
    charts:
      - location: https://packages.local/repository/charts
        name: csm-algol60
        type: repo
EOF

    # For each chart file, move it into manifest format.
    # Hacky to do this with sed, but it's a very simple text modification.
    #
    # Basically convert it from:
    # name: whatever
    # version: whatever
    # ...
    #
    # to:
    #spec:
    #  charts:
    #    - name: whatever
    #      version: whatever
    #      ...
    sed -i -e '1s/^/spec:\n  charts:\n    - /' -e '2,$s/^/      /' "${chart_files[@]}"
    
    # Merge them all into manifest.yaml
    # --arrays=append will merge the "charts:" lists from the different chart files, instead of having them overrwrite each other
    yq m -i --arrays=append "${manifest_file}" "${chart_files[@]}"
}
