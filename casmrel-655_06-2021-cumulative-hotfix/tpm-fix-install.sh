#!/bin/sh
set -ox
set -o pipefail

echo 'loading repair script onto each NCN..'
for ncn in $(grep -oP 'ncn-\w\d+' /etc/hosts | sort -u | tr -t '\n' ' '); do
    scp $(dirname $0)/tpm-fix-repair.sh $ncn:/tmp/cast-26421.sh
done
echo 'running repair script..'
pdsh -b -w $(grep -oP 'ncn-\w\d+' /etc/hosts | sort -u | tr -t '\n' ',') '/tmp/cast-26421.sh'
