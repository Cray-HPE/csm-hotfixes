# Shasta 1.4 Security Regression

The Shasta 1.4 contains a security regression related to container access controls relative to the underlying host. Specifically, this regression has resulted in the removal of one of the components used to enforce these access controls: Pod Security Policies. The risk related to this regression is the potential for privileged access to the underlying host in the event of a user breaking out of a given container running on the kubernetes worker, or a service running in the management plane having operationally dangerous dimensions that would otherwise be blocked by the Pod Security Policies. This regression is the result of a combination of events related to two changes as laid out below:

1. Going into the 1.4 cycle we added Gatekeeper OPA into the mix as the replacement for PSP’s. This work predated a large set of changes to the installer that arrived with 1.4. At that time we were still also running PSP’s in parallel. This was planned to be a transitional process, with PSP’s deprecated as Gatekeeper policies were added.
2. Fast forward into the 1.4 installer work. When that got down the track we ran into an issue with the way the Loftsman tooling was handling timeouts (basically a universal value, not chart specific) and so deployment of Gatekeeper was taking longer than the timeout would allow and subsequently failing. The remediation at the time was to pull gatekeeper out of the 1.4 release for the time being, falling back on the PSP’s.
3. This is where the regression comes in: Because it was assumed Gatekeeper was in the mix the Ansible play that applies the PSP’s was not transitioned into the new installer tooling.
4. So we find ourselves without either OPA policies or PSP’s in place. The good news is that testing of the PSP fix is nearly complete, and will be packaged with the 1.4.2 release. Additionally, the Loftsman fix should land very soon in the upstream OSS repo, and so should facilitate rolling gatekeeper back into the platform in the 1.5 time frame.

# Install instructions

This hotfix requires CSM 0.9.2 that is shipped with Shasta 1.4.1. If CSM 0.9.2 is not installed then the spire pods will fail to come up due to a missing image.

## To install the PSP you need to perform the following:

1. run the `install.sh` script in this directory
2. If you have a spire-wait-for-postgres pod stuck in ImagePullBackOff then you can safely delete the pod by running `kubectl delete jobs -n spire -l 'app.kubernetes.io/name=spire-wait-for-postgres'`. This job is not needed for spire. If you have this issue on other wait-for-postgres pods then do not delete it unless directed by support.

## Rollback instructions

To Rollback the PSP hotfix you need to perform the following:

1. run the `rollback.sh` script in this directory
