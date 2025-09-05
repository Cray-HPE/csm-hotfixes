# CASMNET-2366 - cray-dns-unbound-manager should not remove records if Kea response is empty

## Problem Description

Resolved an issue in cray-dns-unbound-manager where the active configuration could be unnecessarily updated. 
The hotfix ensures that the active configuration remains unchanged if the Kea API returns an empty response and the number of generated records is fewer than those already present.

## Prerequisites

- CSM versions 1.6.0 to 1.6.2

## Installation

The `install-hotfix.sh` script may be run on any Master or Worker Non-Compute Node.

Example:

```bash
./install-hotfix.sh
```

## Rollback

To revert `cray-dns-unbound` to the previous version:

```bash
helm -n services rollback cray-dns-unbound
```
