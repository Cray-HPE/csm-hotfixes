#!/usr/bin/env bash

# Copyright 2020 Hewlett Packard Enterprise Development LP

function update_kea_traffic_policy() {
    echo "Updating cray-dhcp-kea externalTrafficPolicy from Cluster to Local"
    kubectl -n services patch service cray-dhcp-kea-tcp-hmn --type merge -p '{"spec":{"externalTrafficPolicy":"Local"}}'
    kubectl -n services patch service cray-dhcp-kea-tcp-nmn --type merge -p '{"spec":{"externalTrafficPolicy":"Local"}}'
    kubectl -n services patch service cray-dhcp-kea-udp-hmn --type merge -p '{"spec":{"externalTrafficPolicy":"Local"}}'
    kubectl -n services patch service cray-dhcp-kea-udp-nmn --type merge -p '{"spec":{"externalTrafficPolicy":"Local"}}'
}