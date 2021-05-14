# CFS sessions stuck with no job

This hotfix only applies to the CSM 0.9.3 release.

A race condition sometimes caused CFS sessions to never start a job, which could
in turn block other sessions targeting the same nodes from starting.

The fix is an updated cfs-operator image which will retry when this race
condition is hit.

## How to install

1. Install the new cfs-operator image

    Run the `install.sh` script in this hotfix to pull the new image and deploy it.

2. Remove old stuck sessions

   This fix only applies to new sessions and will not correct sessions that are
   already in the stuck state.  Run the following command to delete all sessions
   that are in this stuck state.
   
   ```
        cray cfs sessions list --format json | jq -r '.[] | select(.status.session.startTime==null) | .name' | while read name ; do cray cfs sessions delete $name; done
   ```
# Restoring NTP and DNS server values after a Firmware Update to HPE NCNs

If you update the System ROM of a NCN, you will lose NTP and DNS server values.  Those must be restored using the `set-bmc-ntp-dns.sh` (located in `/opt/cray`).  Use the `-h` to get a list of command line options to restore NTP and DNS values.