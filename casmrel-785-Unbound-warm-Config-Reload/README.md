# CRAY-DNS-UNBOUND - Warm Reload Hotfix

This cray-dns-unbound hotfix enables warm reloading of DNS records and configuration files.  Warm reload removes the requirement of restarting cray-dns-unbound pods to update DNS records and/or configurations changes.


## prerequisites:
- Shasta 1.4 or newer
- Kubernetes administrative access
- Cray CLI access

## Changelog:
- cray-dhcp-unbound pod does not need to be restarted when loading new configs or DNS records.
- cray-dns-unbound will not start or load empty DNS record list.  This includes resetting DNS records via configmap


## Usage:
        
     
install-hotfix.sh `version of shasta or csm` `large-system(optional)`
        

Version of Shasta or CSM can be shasta-[1.4-1.5] or csm-[0.9-1.0].
Large systems are systems with more than 3000 computes.
Examples:
	
	
```
    ./install-hotfix.sh shasta-1.3
```

or
	
```
    ./install-hotfix.sh csm-1.0 large-system
```
       
       
       
## Troubleshooting:
- Check cray-dns-unbound pod logs to verify the mounted folder `/configmap` identifier matches the configmap version.  Use the following command to retrieve the configmap version.
```
    kubectl get cm -n services cray-dns-unbound -o json |jq .metadata.resourceVersion
```

## Rollback

```
	helm rollback -n services cray-dns-unbound

```
