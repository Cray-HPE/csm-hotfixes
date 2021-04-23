# Missing multus image

The image for Multus should have been loaded into Nexus but was not.

This causes the Multus Pod(s) to get stuck in ImagePullBackOff if the
pre-loaded multus image is ever evicted from an NCN, and sometimes happens when
an NCN is rebooted.

This is what the problem looks like on a system; in this case the Multus Pod on ncn-m001 is in ImagePullBackOff:

```
ncn-m001:~ # kubectl get pod -A -o wide | grep multus
kube-system      kube-multus-ds-amd64-4zcn4                                        1/1     Running            0          8m11s   10.252.1.4      ncn-w001   <none>           <none>
kube-system      kube-multus-ds-amd64-7rtrv                                        1/1     Running            3          23d     10.252.1.10     ncn-w007   <none>           <none>
kube-system      kube-multus-ds-amd64-c27lz                                        1/1     Running            0          19m     10.252.1.7      ncn-w004   <none>           <none>
kube-system      kube-multus-ds-amd64-cmwtl                                        1/1     Running            0          23s     10.252.1.13     ncn-m003   <none>           <none>
kube-system      kube-multus-ds-amd64-jn2m7                                        1/1     Running            0          22h     10.252.1.9      ncn-w006   <none>           <none>
kube-system      kube-multus-ds-amd64-nt7vr                                        1/1     Running            0          23d     10.252.1.6      ncn-w003   <none>           <none>
kube-system      kube-multus-ds-amd64-wwkvk                                        1/1     Running            0          23d     10.252.1.12     ncn-m002   <none>           <none>
kube-system      kube-multus-ds-amd64-x4xf9                                        1/1     Running            4          23d     10.252.1.5      ncn-w002   <none>           <none>
kube-system      kube-multus-ds-amd64-xfx5b                                        1/1     Running            0          23h     10.252.1.8      ncn-w005   <none>           <none>
kube-system      kube-multus-ds-amd64-xppmh                                        0/1     ImagePullBackOff   0          77s     10.252.1.11     ncn-m001   <none>           <none>
```

The fix is to load the Multus image into Nexus.

## How to install

Run `install.sh`
