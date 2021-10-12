# CRAY-DNS-UNBOUND - Warm Reload Hotfix

This `cray-dns-unbound` hotfix enables warm reloading of DNS records and configuration files. Warm reloads are now used instead of pod restarts when adding, deleting, or updating DNS records, or making configuration changes via ConfigMap.

## Prerequisites

- Shasta 1.4 or newer
- Kubernetes administrative access

## Changelog

- `cray-dhcp-unbound` pod does not need to be restarted when loading new configs or DNS records.
- `cray-dns-unbound` will not start or load empty DNS record list. This includes resetting DNS records via configmap.
- Deploying `cray-dns-unbound` chart can pass DNS host record list.
- `/srv/unbound` is mounted from configmap instead of being copied into the container build.

## Usage

The `install-hotfix.sh` may be run on any node with access to the Kubernetes cluster. The usage is:

```bash
ncn# install-hotfix.sh <version of shasta or csm> [increase-resources]
```

The version of Shasta or CSM can be shasta-[1.4-1.5] or csm-[0.9-1.0].

Specifying the `increase-resources` argument is helpful for systems with more than 3000 compute nodes. The `cray-dhcp-unbound` pod resources go from 2CPU to 4CPU and memory from 2GB to 4GB.

Examples:

```bash
ncn# ./install-hotfix.sh shasta-1.4
```

or

```bash
ncn# ./install-hotfix.sh csm-1.0 large-system
```

## Troubleshooting

Check `cray-dns-unbound` pod logs to verify the mounted folder `/configmap` identifier matches the configmap version. Use the following command to retrieve the configmap version.

```bash
ncn# kubectl get cm -n services cray-dns-unbound -o json |jq .metadata.resourceVersion
```

## Rollback

Rolling back `cray-dns-unbound`:
```bash
ncn# helm rollback -n services cray-dns-unbound
```

