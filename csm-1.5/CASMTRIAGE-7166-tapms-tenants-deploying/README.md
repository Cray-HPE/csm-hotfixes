# CASMTRIAGE-7166 - Fix for the status field in tenant deployments

Fixes an issue with TAPMS where it will try to add nodes to the tenants HSM node group more than once, causing the tenant to get stuck in a "deploying" state.

## Prerequisites

- CSM versions 1.5.0 to 1.5.2

## JIRA(s)

This hotfix covers the following JIRA(s):

* [CASMTRIAGE-7166](https://jira-pro.it.hpe.com:8443/browse/CASMTRIAGE-7166)

## Usage

```bash
./install-hotfix.sh
```
