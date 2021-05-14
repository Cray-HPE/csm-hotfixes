# Shasta 1.4 Weave MTU Regression

Shasta 1.4 has a change to the weave-net daemonset that sets the MTU to a value that is too high for the underlying management network.  This change causes the Weave CNI to go into a slower packet forwarding mode called "sleeve".   This mode can cause significant slowness in the overlay network which affects all pod-to-pod communication.   To fix this we need to change the weave MTU in the weave-net daemonset.   Because we have deployed hundreds of pods on the weave overlay network, we need to restart all of those pods to allow their interfaces pick up the new MTU.  The safest way to do this is to perform a clean restart of the k8s cluster by following the documented shutdown and startup procedures.

# Install instructions

This hotfix requires CSM 0.9.0 or later that is shipped with Shasta 1.4.0 or later.

## To determine if this hotfix is needed, execute the following command on ncn-m001:

`weave --local status connections`

If you see "sleeve" in the output as follows, you DO need to perform this hotfix.

```
ncn-m001:~ # weave --local status connections
<- 10.252.1.12:52577     established sleeve 9a:68:96:e5:f9:ea(ncn-w003) mtu=1438
<- 10.252.1.8:53231      established sleeve 72:d5:3d:2c:5a:cd(ncn-m002) mtu=1438
<- 10.252.1.9:39519      established sleeve ce:c0:ba:62:e3:59(ncn-m003) mtu=1438
<- 10.252.1.11:43385     established sleeve 7e:0f:44:0e:ac:a8(ncn-w002) mtu=1438
<- 10.252.1.14:52583     established sleeve 1a:72:41:ae:10:4b(ncn-w005) mtu=1438
<- 10.252.1.13:41137     established sleeve ce:ff:ce:3f:2e:7d(ncn-w004) mtu=1438
<- 10.252.1.10:43771     established sleeve 3e:62:44:16:89:45(ncn-w001) mtu=1438
```

If you see "fastdp" instead of "sleeve", you DO NOT need to perform this hotfix.

## Other documents needed

To perform this hotfix you will need to reference the following documents:

1. *HPE Cray EX Hardware Management Administration Guide 1.4 S-8015*
2. *HPE Cray EX System Administration Guide 1.4 S-8001*

## To change the Weave MTU you need to perform the following steps:

1. Download and install the latest csm-install-workarounds rpm from https://storage.googleapis.com/csm-release-public/shasta-1.4/csm-install-workarounds/csm-install-workarounds-latest.noarch.rpm on ncn-m001.
1. Run the CASMINST-1612 workaround located in /opt/cray/csm/workarounds/livecd-post-reboot/CASMINST-1612.
1. Perform section "Prepare the System for Power Off" in *HPE Cray EX Hardware Management Administration Guide 1.4 S-8015*.
1. Skip sections "Shut Down and Power Off Compute and User Access Nodes", "Save Management Network Switch Configuration Settings", and "Power Off Compute and IO Cabinets" in *HPE Cray EX Hardware Management Administration Guide 1.4 S-8015*.
1. BEFORE doing the next section, change WEAVE_MTU value in the weave-net daemon set to **1376**.

   `kubectl -n kube-system edit ds weave-net`

   ```
       spec:
         containers:
         - command:
           - /home/weave/launch.sh
           env:
           - name: HOSTNAME
             valueFrom:
               fieldRef:
                 apiVersion: v1
                 fieldPath: spec.nodeName
           - name: IPALLOC_RANGE
             value: 10.32.0.0/12
           - name: WEAVE_MTU
             value: "1376"
           - name: INIT_CONTAINER
             value: "true"
   ```

1. After this edit, the weave-net daemon set will automatically do a rolling restart.   Wait for this rollout to complete.

   You can use the following command to monitor this rollout.

   `kubectl -n kube-system rollout status ds weave-net`


1. Perform section "Shut Down and Power Off the Management Kubernetes Cluster" in *HPE Cray EX Hardware Management Administration Guide 1.4 S-8015*.

1. Skip section "Power Off the External Lustre File System" in *HPE Cray EX Hardware Management Administration Guide 1.4 S-8015*.

1. Perform section "Power On and Start the Management Kubernetes Cluster" in *HPE Cray EX Hardware Management Administration Guide 1.4 S-8015*.

1. Run the following test **on all master and worker NCNs** to check the spire-agent services on the NCNs

   `goss -g /opt/cray/tests/install/ncn/tests/goss-spire-agent-service-running.yaml validate`

    If the test shows that the spire-agent is not running on any of those NCNs, refer to section "Troubleshoot SPIRE Failing to Start on NCNs" in *HPE Cray EX System Administration Guide 1.4 S-8001* to resolve those issues.

1. Skip section "Power On the External Lustre File System" and "Power On Compute and IO Cabinets" in *HPE Cray EX Hardware Management Administration Guide 1.4 S-8015*.

1. Perform section "Bring Up the Slingshot Fabric" in *HPE Cray EX Hardware Management Administration Guide 1.4 S-8015*.

1. Skip sections "Power On and Boot Compute and User Access Nodes" and "Recover from a Liquid Cooled Cabinet EPO Event" in *HPE Cray EX Hardware Management Administration Guide 1.4 S-8015*.

1. Verify that weave is now in `fastdp` mode by performing the following command again on ncn-m001.

   `weave --local status connections`

   Output should look similar to the following:

   ```
   ncn-m001:~ # weave --local status connections
   <- 10.252.1.12:52577     established fastdp 9a:68:96:e5:f9:ea(ncn-w003) mtu=1376
   <- 10.252.1.8:53231      established fastdp 72:d5:3d:2c:5a:cd(ncn-m002) mtu=1376
   <- 10.252.1.9:39519      established fastdp ce:c0:ba:62:e3:59(ncn-m003) mtu=1376
   <- 10.252.1.11:43385     established fastdp 7e:0f:44:0e:ac:a8(ncn-w002) mtu=1376
   <- 10.252.1.14:52583     established fastdp 1a:72:41:ae:10:4b(ncn-w005) mtu=1376
   <- 10.252.1.13:41137     established fastdp ce:ff:ce:3f:2e:7d(ncn-w004) mtu=1376
   <- 10.252.1.10:43771     established fastdp 3e:62:44:16:89:45(ncn-w001) mtu=1376
   ```

## Rollback instructions

To rollback the Weave MTU hotfix you need to perform the same set of instructions above using MTU of 1460 instead of 1376.

