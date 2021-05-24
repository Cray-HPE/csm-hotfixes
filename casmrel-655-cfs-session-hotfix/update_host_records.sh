#!/usr/bin/env bash

# Copyright 2020 Hewlett Packard Enterprise Development LP

function update_host_records() {

    # get list of ncn workers
    ncn_workers=$(kubectl get nodes|grep "ncn-w"|awk '{ print $1 }')

    # get ip of nmn istio ingress
    ip=$(dig api-gw-service-nmn.local +short)

    # create entry for /etc/hosts
    entry="$ip packages.local registry.local"

    # check for existing records and remove entries

    for host in $ncn_workers; do
        # check for existing records and remove entries
        packages_count=$(pdsh -w $host cat /etc/hosts|grep packages.local|wc -l)
        registry_count=$(pdsh -w $host cat /etc/hosts|grep registry.local|wc -l)
        if [[ "$packages_count" -gt "0" ]];then
            pdsh -w $host "sed -i '/packages.local/d' /etc/hosts"
        fi
        if [[ "$registry_count" -gt "0" ]]; then
            pdsh -w $host "sed -i '/registry.local/d' /etc/hosts"
        fi
        # add host record
        pdsh -w $host "echo $entry >> /etc/hosts"
    done
}