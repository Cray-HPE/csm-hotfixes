# CASMCMS-9175 - Add inotify-tools to console services images

Add the `inotify-tools` package to the `cray-console-operator` and `cray-console-node`
images. This does not use them, but makes these tools available for others.

## Prerequisites

- CSM versions 1.5.0 to 1.5.2

## JIRA(s)

This hotfix covers the following JIRA(s):

* [CASMCMS-9175](https://jira-pro.it.hpe.com:8443/browse/CASMCMS-9175)

## Usage

```bash
./install-hotfix.sh
```

**NOTE** If the size of the PVC attached to the `cray-console-operator` service has been increased to accommodate
large system console log requirements, there will be a failure during the deployment of the hotfix when it tries
to decrease the size of the PVC to the original size. The error message will look something like:

```text
Encountered errors during the manifest release:

2024-10-28T20:36:57Z ERR Error releasing chart cray-console-operator v1.8.2: Shell error: Error:
UPGRADE FAILED: cannot patch "cray-console-operator-data-claim" with kind PersistentVolumeClaim: PersistentVolumeClaim
"cray-console-operator-data-claim" is invalid: spec.resources.requests.storage: Forbidden: field can not be less than
previous value chart=cray-console-operator command=ship namespace=services version=1.8.2

2024-10-28T20:36:57Z ERR  error="Some charts did not release successfully, see above and/or the output log file for more info" command=ship
```

This is just noting the failure to resize the PVC, but this is ok. It will leave the original PVC in place with the increased
size and the rest of the services will update to the hotfix.

This may be verified by checking the `helm` history.

```bash
helm -n services history cray-console-operator
```

Expected result:

```text
REVISION	UPDATED                 	STATUS  	CHART                      	APP VERSION	DESCRIPTION                                                                                                                                                                                                                                                                        
1       	Thu Jul 18 19:43:50 2024	deployed	cray-console-operator-1.8.0	1.8.0      	Install complete                                                                                                                                                                                                                                                                   
2       	Mon Oct 28 20:20:48 2024	failed  	cray-console-operator-1.8.2	1.8.2      	Upgrade "cray-console-operator" failed:
cannot patch "cray-console-operator-data-claim" with kind PersistentVolumeClaim: PersistentVolumeClaim "cray-console-operator-data-claim"
is invalid: spec.resources.requests.storage: Forbidden: field can not be less than previous value
```

To get a clean install modify the file the manifest to override the default value of the PVC.

Find the current value of the PVC:

```bash
kubectl -n services get pvc | grep cray-console-operator
```

Expected output will be something like:

```text
cray-console-operator-data-claim  Bound  pvc-199a9667-be7a-4f91-aa58-536ef07cf45f  150Gi  RWX  ceph-cephfs-external  102d
```

In the above example, the current PVC size is 150Gi.

Modify the manifest contained in the file `install-hotfix.sh` to include a helm chart value override to that value:

```text
  - name: cray-console-operator
    source: nexus
    version: 1.8.2
    namespace: services
    values:
      cray-service:
        persistentVolumeClaims:
          data-claim:
            resources:
              requests:
                storage: 150Gi
```

Now, when executing the `install-hotfix.sh` script, the default value will be overridden with the existing
value of the PVC and the chart will update cleanly.
