# CASMREL-755

This procedure covers applying the hotfix for the following:

* Update cray-sysmgmt-health helm chart to address multiple alerts
* Install/Update node_exporter on storage nodes
* Update cray-hms-hmnfd helm chart

## Prerequisites

* The cray cli is used during the application of this hotfix, and therefore must be configured and operational.

## Setup

1. Copy the tar file to a master node
2. on that master node untar the file
3. cd into the casmrel-755* folder

## Execute the install-hotfix.sh script

This hotfix is applied by applying the following script:

```bash
ncn-m001# ./install-hotfix.sh
```

## Validation

Node exporter:

1. Confirm node-exporter is running on each storage node

   ```bash
   curl -s http://ncn-s001:9100/metrics |grep go_goroutines|grep -v "#"
   go_goroutines 8
   ```

1. Confirm manifests were updated on each master node

   ```bash
   ncn-m# grep bind *
   kube-controller-manager.yaml:    - --bind-address=0.0.0.0
   kube-scheduler.yaml:    - --bind-address=0.0.0.0
   ```

1. Confirm updated sysmgmt-health chart was deployed

   ```bash
   ncn-m#/etc/kubernetes/manifests # helm ls -n sysmgmt-health
   NAME               	NAMESPACE     	REVISION	UPDATED                               	STATUS  	CHART                     	APP VERSION
   cray-sysmgmt-health	sysmgmt-health	2       	2021-09-10 16:45:12.00113666 +0000 UTC	deployed	cray-sysmgmt-health-0.12.6
   ```

1. Confirm updates to BSS for cloud-init runcmd

   **`IMPORTANT:`** The xnames below may not reflect the xnames in the environment where the hotfix is being applied.  Please ensure you replace the xnames with the correct xnames in the below examples.

   Example for a master node.  This should be checked on each master node.

   ```bash
   ncn-m# cray bss bootparameters list --name x3000c0s1b0n0 --format=json | jq '.[]|."cloud-init"."user-data"'
   {
     "hostname": "ncn-m001",
     "local_hostname": "ncn-m001",
     "mac0": {
       "gateway": "10.252.0.1",
       "ip": "",
       "mask": "10.252.2.0/23"
     },
     "runcmd": [
       "/srv/cray/scripts/metal/install-bootloader.sh",
       "/srv/cray/scripts/metal/set-host-records.sh",
       "/srv/cray/scripts/metal/set-dhcp-to-static.sh",
       "/srv/cray/scripts/metal/set-dns-config.sh",
       "/srv/cray/scripts/metal/set-ntp-config.sh",
       "/srv/cray/scripts/metal/set-bmc-bbs.sh",
       "/srv/cray/scripts/metal/disable-cloud-init.sh",
       "/srv/cray/scripts/common/update_ca_certs.py",
       "/srv/cray/scripts/common/kubernetes-cloudinit.sh",
       "sed -i 's/--bind-address=127.0.0.1/--bind-address=0.0.0.0/' /etc/kubernetes/manifests/kube-controller-manager.yaml",
       "sed -i '/--port=0/d' /etc/kubernetes/manifests/kube-scheduler.yaml",
       "sed -i 's/--bind-address=127.0.0.1/--bind-address=0.0.0.0/' /etc/kubernetes/manifests/kube-scheduler.yaml"
     ]
   }
   ```

   Example for a storage node.  This should be checked on each storage node.

   ```bash
   ncn-m001:~ # cray bss bootparameters list --name x3000c0s13b0n0 --format=json | jq '.[]|."cloud-init"."user-data"'
   {
     "hostname": "ncn-s001",
     "local_hostname": "ncn-s001",
     "mac0": {
       "gateway": "10.252.0.1",
       "ip": "",
       "mask": "10.252.2.0/23"
     },
     "runcmd": [
       "/srv/cray/scripts/metal/install-bootloader.sh",
       "/srv/cray/scripts/metal/set-host-records.sh",
       "/srv/cray/scripts/metal/set-dhcp-to-static.sh",
       "/srv/cray/scripts/metal/set-dns-config.sh",
       "/srv/cray/scripts/metal/set-ntp-config.sh",
       "/srv/cray/scripts/metal/set-bmc-bbs.sh",
       "/srv/cray/scripts/metal/disable-cloud-init.sh",
       "/srv/cray/scripts/common/update_ca_certs.py",
       "zypper --no-gpg-checks in -y https://packages.local/repository/casmrel-755/cray-node-exporter-1.2.2-1.x86_64.rpm"
     ]
   }
   ```
