# CASMREL-755

This procedure covers applying the hotfix for the following:

* Update cray-sysmgmt-health helm chart to address multiple alerts
* Install/Update node_exporter on storage nodes
* Update cray-hms-hmnfd helm chart

## Prerequisites

* The cray cli is used during the application of this hotfix, and therefore must be configured and operational.

## Setup

1. Copy the tar file to a master node
2. on that master node, untar the file
3. cd into the casmrel-755* folder

## Execute the install-hotfix.sh script

This hotfix is applied by applying the following script:

```bash
ncn-m001# ./install-hotfix.sh
```

## Validation

Node exporter:

1. Confrim node-exporter is running on each storage node

   ```bash
   curl -s http://ncn-s001:9100/metrics |grep go_goroutines|grep -v "#"
   go_goroutines 8
   ```

2. 