# CASMNET-2176 - Unbound resiliency

## Prerequisites

- CSM 1.4.0 or higher

## Changelog

This hotfix contains the following fixes and enhancements.

- CASMNET-2176 - Unbound resiliency fixes.
  - The cray-dns-unbound reload loop will fail gracefully if records.json.gz cannot be read from the cray-dns-unbound ConfigMap preventing the Pod from entering a CrashLoopBackOff state.
  - The cray-dns-unbound-manager CronJob will automatically regenerate all records if the records.json.gz key is missing from the cray-dns-unbound ConfigMap.
  - The cray-dns-unbound-manager CronJob will retry the `kubectl replace --force` command used to update the cray-dns-unbound ConfigMap if it fails.
- CASMNET-2175 - Make interface used for NID alias configurable.
  - cray-dns-unbound-manager will now only use the first HSN interface for the node "nid" aliases.
  - This behaviour is configurable, see [Manage the DNS Unbound Resolver](https://github.com/Cray-HPE/docs-csm/blob/release/1.6/operations/network/dns/Manage_the_DNS_Unbound_Resolver.md#change-which-hsn-nic-is-used-for-the-node-alias) for more information.

## Installation

The `install-hotfix.sh` script may be run on any Master or Worker Non-Compute Node.

Example:

```bash
./install-hotfix.sh
```

This hotfix is included in CSM 1.4.4, 1.5.0, and 1.6.0. It will need to be re-applied if upgrading to an earlier release.

## Rollback

To revert `cray-dns-unbound` to the previous version:

```bash
helm -n services rollback cray-dns-unbound
```
