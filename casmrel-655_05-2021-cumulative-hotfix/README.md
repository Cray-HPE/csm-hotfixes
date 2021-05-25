# CASMREL-655 May 2021 Cumulative Hotfix
This hotfix only applies to the CSM 0.9.3 release.

Changes:
* CFS sessions stuck with no job. A race condition sometimes caused CFS sessions to never start a job, which could in turn block other sessions targeting the same nodes from starting. The fix is an updated cfs-operator image which will retry when this race
condition is hit.
* Configure NTP and DNS for HPE NCN BMCs. 
* Unbound no longer forwards requests to Shasta zones to site DNS.
* Add static entries for `registry.local` and `packages.local` to the `/etc/hosts` files on the worker nodes.
* Prometheus is can now to scrape kubelet/kube-proxy for metrics.
* Install node-exporter on storage nodes.

## Install

1. Run the `install.sh` script in this hotfix to deploy an updated cfs-operator and unbound. This also deploys a script to `/opt/cray/ncn/set-bmc-ntp-dns.sh` on the current node.
   ```bash
   ncn-m001# ./install.sh
   ```

2. Remove old stuck sessions.

   This fix only applies to new sessions and will not correct sessions that are
   already in the stuck state.  Run the following command to delete all sessions
   that are in this stuck state.

   ```bash
   ncn-m001# \
   cray cfs sessions list --format json | jq -r '.[] | select(.status.session.startTime==null) | .name' | while read name ; do cray cfs sessions delete $name; done
   ```

3. Copy the script `set-bmc-ntp-dns.sh` to each of the NCNs:
   ```bash
   ncn-m001# \
   for h in $( grep ncn /etc/hosts | grep nmn | grep -v m001 | awk '{print $2}' ); do
      pdsh -w $h "mkdir -p /opt/cray/ncn"
      scp ./set-bmc-ntp-dns.sh root@$h:/opt/cray/ncn/set-bmc-ntp-dns.sh
      pdsh -w $h "chmod 755 /opt/cray/ncn/set-bmc-ntp-dns.sh"
   done
   ```

4. Run the NTP DNS BMC script (`/opt/cray/ncn/set-bmc-ntp-dns.sh`) on HPE NCNs. For Gigabyte or Intel NCNs this **step can be skipped**.

   > Pass `-h` to see some examples and use the information below to run the script.

   > The following process can restoring NTP and DNS server values after a firmware is update to HPE NCNs. If you update the System ROM of a NCN, you will lose NTP and DNS server values. Correctly setting these also allows FAS to function properly.

   1. Determine HMN IP address for m001:
      ```bash
      ncn# M001_HMN_IP=$(cat /etc/hosts | grep m001.hmn | awk '{print $1}')
      ncn# echo $M001_HMN_IP
      10.254.1.4
      ```
   2. Specify the credentials for the BMC:
      ```bash
      ncn# export USERNAME=root 
      ncn# export IPMI_PASSWORD=changeme
      ````
   3. View the existing DNS and NTP settings on the BMC:
      ```bash
      ncn# /opt/cray/ncn/set-bmc-ntp-dns.sh ilo -s
      ```
   4. Set the NTP servers to point toward time-hmn and ncn-m001. 
      ```bash
      ncn# /opt/cray/ncn/set-bmc-ntp-dns.sh ilo -N "time-hmn,$M001_HMN_IP" -n
      ```
   5. Set the DNS server to point toward Unbound and ncn-m001.
      ```bash
      ncn# /opt/cray/ncn/set-bmc-ntp-dns.sh ilo -D "10.94.100.225,$M001_HMN_IP" -d
      ```

5. Fix the kubelet and kube-proxy target down prometheus alerts.

   > **NOTE**: These scripts should be run from a kubernetes node (master or worker).  ***Also note it can take several minutes for the target down alerts to clear after the scripts have been executed.***

   1. Run the `fix-kube-proxy-target-down-alert.sh` script in this hotfix to fix the kube-proxy alert.
      ```bash
      ncn-m001# ./fix-kube-proxy-target-down-alert.sh
      ```

   2. Then run the `fix-kubelet-target-down-alert.sh` script in this hotfix to fix the kube-proxy alert.
      ```bash
      ncn-m001# ./fix-kubelet-target-down-alert.sh
      ```

6. Install the prometheus node-exporter onto the Utility Storage nodes

   1. Copy the `install-node_exporter-storage.sh` script out to the storage nodes.
      ```bash
      ncn-m001# \
      for h in $( cat /etc/hosts | grep ncn-s | grep nmn | awk '{print $2}' ); do
         scp ./install-node_exporter-storage.sh root@$h:/tmp
      done
      ```

   2. Run the `install-node_exporter-storage.sh` script on **each** of the storage nodes to enable the node-exporter:
      > **NOTE**: This script should be run on each storage node.
      ```bash
      ncn-s# /tmp/install-node_exporter-storage.sh
      ```