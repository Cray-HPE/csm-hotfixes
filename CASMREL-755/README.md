# CASMREL-755

This procedure covers applying the hotfix for the following:

* Update cray-sysmgmt-health helm chart to address multiple alerts
* Install/Update node_exporter on storage nodes
* Update cray-hms-hmnfd helm chart

## Prerequisites

* The cray cli is used during the application of this hotfix, and therefore must be configured and operational.

## Execute the install-hotfix.sh script

This hotfix is applied by applying the following script:

```bash
ncn-m001# ./install-hotfix.sh
```
