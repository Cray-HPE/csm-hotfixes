# CFS sessions stuck with no job

This hotfix only applies to the CSM 0.9.3 release.

A race condition sometimes caused CFS sessions to never start a job, which could
in turn block other sessions targeting the same nodes from starting.

The fix is an updated cfs-operator image which will retry when this race
condition is hit.

## How to install

1. Install the new cfs-operator image

    Run the `install.sh` script in this hotfix to pull the new image and deploy it.  This also deploys a script to `/opt/cray/ncn/set-bmc-ntp-dns.sh`.

2. Remove old stuck sessions

   This fix only applies to new sessions and will not correct sessions that are
   already in the stuck state.  Run the following command to delete all sessions
   that are in this stuck state.

   ```
        cray cfs sessions list --format json | jq -r '.[] | select(.status.session.startTime==null) | .name' | while read name ; do cray cfs sessions delete $name; done
   ```

3. Run the NTP DNS BMC script (`/opt/cray/ncn/set-bmc-ntp-dns.sh`)

  Pass `-h` to see some examples and use the information below to run the script.

# Restoring NTP and DNS server values after a Firmware Update to HPE NCNs

If you update the System ROM of a NCN, you will lose NTP and DNS server values.  Correctly setting these also allows FAS to function properly.

## Instructions for 1.4.x systems

The script mentioned below should be run on each NCN.

There is new metadata for NTP in 1.5, so for 1.4 systems, it's recommended that you use the `-N server1,server2 -n` flags and the `-D server1,server2 -d` to set the NTP and DNS servers, respectively using custom values you pass in:

```bash
# show existing settings
/opt/cray/ncn/set-bmc-ntp-dns.sh -s
# Set NTP servers with manually defined servers
/opt/cray/ncn/set-bmc-ntp-dns.sh -N time-hmn,ncn-m001 -n
# Set DNS servers with manually defined servers
/opt/cray/ncn/set-bmc-ntp-dns.sh -D ncn-m001,time.nist.gov -d
```

# Instructions to fix the kubelet and kube-proxy target down prometheus alerts

   > **NOTE**: These scripts should be run from a kubernetes node (master or worker).  ***Also note it can take several minutes for the target down alerts to clear after the scripts have been executed.***

   1. Run the `fix-kube-proxy-target-down-alert.sh` script in this hotfix to fix the kube-proxy alert.
   2. Run the `fix-kubelet-target-down-alert.sh` script in this hotfix to fix the kube-proxy alert.

# Instructions for installing node-exporter on Utility Storage nodes

   > **NOTE**: This script should be run on each storage node.

   1. Run the `install-node_exporter-storage.sh` script in this hotfix to enable the node-exporter.
