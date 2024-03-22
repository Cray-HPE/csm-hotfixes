#!/bin/bash

set -exo pipefail

function check_unbound_records() {

host_record_gz_check=$(kubectl get cm -n services cray-dns-unbound -o json| jq .binaryData|jq '."records.json.gz"')
host_record_gz_empty="H4sICLQ/Z2AAA3JlY29yZHMuanNvbgCLjuUCAETSaHADAAAA"

if [[ $host_record_gz_check != $host_record_gz_empty ]] && [[ "$host_record_gz_check" != "null" ]]; then
    echo "preserving gzip of DNS records for cray-dns-unbound chart deploy"
    echo "updating core-services.yaml manifest"
    yq w -i "${workdir}/core-services.yaml" 'spec.charts.(name==cray-dns-unbound).values.binaryData."records.json.gz"' $host_record_gz_check
else
    echo "No gzip DNS records found to preserve."
    host_record_gz_check=$host_record_gz_empty
fi

}

function size_of_host_record_import() {
host_record_gz_in_bytes=$(echo $host_record_gz_check| wc -c)
echo "bytes size of host_records $host_record_gz_in_bytes"

if [ "$host_record_gz_in_bytes"  -gt "200000" ]; then
   echo "large host record import"
   wipe_annotations=true
else
   echo "small host record import"
   wipe_annotations=false
fi
}

function annotation_cleanup() {

if $wipe_annotations; then
        yq w -i "${workdir}/core-services.yaml" 'metadata.annotations."loftsman.io/previous-data"' '{"loftsman.log": "wiped from large host import"}'
        echo "Wiped annotation log to prevent future errors."
        kubectl -n loftsman get cm loftsman-core-services  -o yaml > "${workdir}/core-services.yaml"
        cp "${workdir}/core-services.yaml" "${workdir}/core-services.yaml.bak"
        yq w -i "${workdir}/core-services.yaml" 'metadata.annotations."loftsman.io/previous-data"' '{"loftsman.log": "wiped from large host import"}'
        kubectl apply -f "${workdir}/core-services.yaml"
else
    echo "No annotation cleanup needed."
fi
}