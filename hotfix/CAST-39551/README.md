# CAST-39551 - Prevent duplicate Kubernetes jobs for CFS sessions

## Problem description

Resolved an issue where Kafka errors could result in multiple Kubernetes
jobs being created for the same CFS session.

## Hotfix description

This hotfix modifies CFS and cfs-operator to prevent a second Kubernetes job
from being created for a CFS session, if one has already been created.
It also adds additional debug logging statements to CFS, cfs-batcher,
and cfs-operator.

## Hotfix chart versions

| *Chart*             | *Namespace* | *Version* |
| `cray-cfs-api`      | `services`  | `1.23.8`  |
| `cray-cfs-batcher`  | `services`  | `1.12.1`  |
| `cray-cfs-operator` | `services`  | `1.27.4`  |

## Prerequisites

- CSM versions 1.6.0 to 1.6.2

## Installation

The `install-hotfix.sh` script may be run on any Master or Worker Non-Compute Node.

Example:

```bash
./install-hotfix.sh
```

## Rollback

To revert to the previous versions:

```bash
function rollback-chart-cast-39551
{
    # Usage: rollback-chart-cast-39551 <chart-name> <hotfix-version>
    local hotfix current name
    name="$1"
    hotfix="${name}-$2"
    current=$(kubectl get deployments -n services "${name}" -o jsonpath='{.metadata.labels.helm\.sh/chart}')
    if [[ ${current} != ${hotfix} ]]; then
        echo "Current chart (${current}) does not match CAST-39551 hotfix chart (${hotfix})"
        echo "Skipping rollback of ${name}"
        return
    fi
    echo "Rolling back from ${current}"
    helm -n services rollback "${name}"
}

# Rollback CFS
rollback-chart-cast-39551 cray-cfs-api 1.23.8

# Rollback cfs-batcher
rollback-chart-cast-39551 cray-cfs-batcher 1.12.1

# Rollback cfs-operator
rollback-chart-cast-39551 cray-cfs-operator 1.27.4
```
