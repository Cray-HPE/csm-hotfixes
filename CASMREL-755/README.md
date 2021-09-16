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

### Node exporter:

1. Confirm node-exporter is running on each storage node. This command can be run from a master node.  Validate that the result contains `go_goroutines` (replace ncn-s001 below with each storage node):

   ```bash
   curl -s http://ncn-s001:9100/metrics |grep go_goroutines|grep -v "#"
   go_goroutines 8
   ```

1. Confirm manifests were updated on each master node (repeat on each master node):

   ```bash
   ncn-m# grep bind /etc/kubernetes/manifests/*
   kube-controller-manager.yaml:    - --bind-address=0.0.0.0
   kube-scheduler.yaml:    - --bind-address=0.0.0.0
   ```

1. Confirm updated sysmgmt-health chart was deployed.  This command can be executed on a master node -- confirm the `cray-sysmgmt-health-0.12.6` chart version:

   ```bash
   ncn-m# helm ls -n sysmgmt-health
   NAME               	NAMESPACE     	REVISION	UPDATED                               	STATUS  	CHART                     	APP VERSION
   cray-sysmgmt-health	sysmgmt-health	2       	2021-09-10 16:45:12.00113666 +0000 UTC	deployed	cray-sysmgmt-health-0.12.6      8.15.4
   ```

1. Confirm updates to BSS for cloud-init runcmd

   **`IMPORTANT:`** Ensure you replace `XNAME` with the correct xname in the below examples (executing the `/opt/cray/platform-utils/getXnames.sh` script on a master node will display xnames):

   Example for a master node -- this should be checked for each master node.  Validate the three `sed` commands are returned in the output.

   ```bash
   ncn-m# cray bss bootparameters list --name XNAME --format=json | jq '.[]|."cloud-init"."user-data"'
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

   Example for a storage node -- this should be checked for each storage node.  Validate the `zypper` command is returned in the output.

   ```bash
   ncn-m001:~ # cray bss bootparameters list --name XNAME --format=json | jq '.[]|."cloud-init"."user-data"'
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
       "zypper --no-gpg-checks in -y https://packages.local/repository/casmrel-755/cray-node-exporter-1.2.2.1-1.x86_64.rpm"
     ]
   }
   ```

### HMNFD:

Once hot fix is installed the missing timestamp fix can be validated by taking the following steps:

1. Find an instance of a cluster-kafka pod:

```
   kubectl -n sma get pods | grep kafka
   cluster-kafka-0               2/2     Running     1          30d
   cluster-kafka-1               2/2     Running     1          26d
   cluster-kafka-2               2/2     Running     0          73d
```

2. Exec into one of those pods:

```
   kubectl -n sma exec -it <pod_id> /bin/bash
```

3. cd to the 'bin' directory in the kafka pod.

4. Execute the following command in the kafka pod to run a kafka consumer app:

```
   ./kafka-console-consumer.sh --bootstrap-server=localhost:9092 --topic=cray-hmsstatechange-notifications
```

5. Find a compute node that is booted on the system:

```
   sat status | grep Compute | grep Ready
   ...
   | x1003c7s7b1n1  | Node | 2023     | Ready   | OK   | True    | X86  | Mountain | Compute     | Sling    |
```

NOTE: All examples below will use the node seen in the above example.

6. Send an SCN to HMNFD for that node indicating that it is in the Ready state.  Note that this won't affect anything since the node is already Ready.

```
   TOKEN=`curl -k -s -S -d grant_type=client_credentials -d client_id=admin-client -d client_secret=\`kubectl get secrets admin-client-auth -o jsonpath='{.data.client-secret}' | base64 -d\` https://api-gw-service-nmn.local/keycloak/realms/shasta/protocol/openid-connect/token | jq -r '.access_token'`

   curl -s -k -H "Authorization: Bearer ${TOKEN}" -X POST -d '{"Components":["x1003c7s7b1n1"],"State":"Ready"}' https://api_gw_service.local/apis/hmnfd/hmi/v1/scn
```

7. In the kafka-console-consumer.sh window there should be an SCN sent by HMNFD, which should include a Timestamp field:

```
   {"Components":["x1003c7s7b1n1"],"Flag":"OK","State":"Ready","Timestamp":"2021-09-13T13:00:00"}
```

## Notes:

1. If a storage node is rebuilt (due to hardware failure or otherwise) after this hotfix is installed, the changes related to installing the node-exporter on the storage node will persist.  However, after rebuilding a storage node, the `CephMonVersionMismatch` may start alerting in prometheus.  If so, restarting the active Ceph mgr process may be necessary in order to clear the alert.  The following command will restart the active mgr process, and can be executed on any storage node:

   ```
   ncn-s00(1/2/3): ceph mgr fail $(ceph mgr dump | jq -r .active_name)
   ```

   The `CephMonVersionMismatch` prometheus alert should clear within ten minutes after restarting active Ceph mgr process.
