# CRAY-DNS-UNBOUND - Warm Reload Hotfix

This cray-dns-unbound hotfix enables warm reloading of DNS records and configuration files.  Warm reloads are now used instead of pod restarts when adding, deleting, or updating DNS records, or making configuration changes via ConfigMap.

## prerequisites:
- Shasta 1.4 or newer
- Kubernetes administrative access


## Changelog:
- cray-dhcp-unbound pod does not need to be restarted when loading new configs or DNS records.
- cray-dns-unbound will not start or load empty DNS record list.  This includes resetting DNS records via configmap
- deploying cray-dns-unbound chart can pass DNS host record list.


## Usage:
        
     
install-hotfix.sh `version of shasta or csm` `increase-resources(optional)`
        

Version of Shasta or CSM can be shasta-[1.4-1.5] or csm-[0.9-1.0].

Increase-resources is helpful for systems with more than 3000 computes.  The cray-dhcp-unbound pod resources go from 2CPU -> 4CPU and memory from 2GB -> 4GB.

Examples:
	
	
```
    ./install-hotfix.sh shasta-1.4
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
- rolling back cray-dns-unbound
```
	helm rollback -n services cray-dns-unbound
```
