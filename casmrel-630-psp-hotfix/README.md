# Shasta CSM 1.4 Security Regression

The Shasta 1.4 contains a security regression related to container access controls relative to the underlying host. Specifically, this regression has resulted in the removal of one of the components used to enforce these access controls: Pod Security Policies. The risk related to this regression is the potential for privileged access to the underlying host in the event of a user breaking out of a given container running on the kubernetes worker, or a service running in the management plane having operationally dangerous dimensions that would otherwise be blocked by the Pod Security Policies. This regression is the result of a combination of events related to two changes as laid out below:

1. Going into the 1.4 cycle we added Gatekeeper OPA into the mix as the replacement for PSP’s. This work predated a large set of changes to the installer that arrived with 1.4. At that time we were still also running PSP’s in parallel. This was planned to be a transitional process, with PSP’s deprecated as Gatekeeper policies were added.
2. Fast forward into the 1.4 installer work. When that got down the track we ran into an issue with the way the Loftsman tooling was handling timeouts (basically a universal value, not chart specific) and so deployment of Gatekeeper was taking longer than the timeout would allow and subsequently failing. The remediation at the time was to pull gatekeeper out of the 1.4 release for the time being, falling back on the PSP’s.
3. This is where the regression comes in: Because it was assumed Gatekeeper was in the mix the Ansible play that applies the PSP’s was not transitioned into the new installer tooling.
4. So we find ourselves without either OPA policies or PSP’s in place. The good news is that testing of the PSP fix is nearly complete, and will be packaged with the 1.4.2 release. Additionally, the Loftsman fix should land very soon in the upstream OSS repo, and so should facilitate rolling gatekeeper back into the platform in the 1.5 time frame.

# Install instructions

## Run Validation Checks (Pre-Upgrade)

It is important to first verify a healthy starting state. To do this, run the CSM validation checks located in /usr/share/doc/metal/008-CSM-VALIDATION.md. If this file is missing then please use zypper to install the docs-csm-install rpm. If any problems are found, correct them and verify the appropriate validation checks before proceeding.

## To install the PSP you need to perform the following:

1. run the `install.sh` script in this directory
2. Perform a rolling restart of all NCN Kubernetes Workers and Masters. This process is documented in the System Administration Guide 1.4 under Section 4, Page 74.

## Roll any pods that are still missing PSPs

1. run the script `list-missing-psp-pods.sh`
2. run `kubectl rollout restart -n [NAMESPACE] [DEPLOYMENT/STATEFULSET/DAEMONSET] [NAME]` for any pods associated with a deployment/statefulset/daemonset that do not have PSPs assigned to it
3. Some pods may show here that are not in a deployment/statefulset/daemonset and need to be deleted one at a time. Wait for the deleted pod to come back and show as running before moving to the next one.

## Run Validation Checks (Post-Upgrade)

> **`IMPORTANT:`** Wait at least 15 minutes after
> [`upgrade.sh`](#deploy-manifests) completes to let the various Kubernetes
> resources get initialized and started.

Run the following validation checks to ensure that everything is still working
properly after the upgrade:

1. Platform health checks from /usr/share/doc/metal/008-CSM-VALIDATION.md
2. Network health checks from /usr/share/doc/metal/008-CSM-VALIDATION.md

Other health checks may be run as desired.

> **`CAUTION:`** The following HMS functional tests may fail due to locked
> components in HSM:
>
> 1. `test_bss_bootscript_ncn-functional_remote-functional.tavern.yaml`
> 2. `test_smd_components_ncn-functional_remote-functional.tavern.yaml`
>
> ```bash
>         Traceback (most recent call last):
>           File "/usr/lib/python3.8/site-packages/tavern/schemas/files.py", line 106, in verify_generic
>             verifier.validate()
>           File "/usr/lib/python3.8/site-packages/pykwalify/core.py", line 166, in validate
>             raise SchemaError(u"Schema validation failed:\n - {error_msg}.".format(
>         pykwalify.errors.SchemaError: <SchemaError: error code 2: Schema validation failed:
>          - Key 'Locked' was not defined. Path: '/Components/0'.
>          - Key 'Locked' was not defined. Path: '/Components/5'.
>          - Key 'Locked' was not defined. Path: '/Components/6'.
>          - Key 'Locked' was not defined. Path: '/Components/7'.
>          - Key 'Locked' was not defined. Path: '/Components/8'.
>          - Key 'Locked' was not defined. Path: '/Components/9'.
>          - Key 'Locked' was not defined. Path: '/Components/10'.
>          - Key 'Locked' was not defined. Path: '/Components/11'.
>          - Key 'Locked' was not defined. Path: '/Components/12'.: Path: '/'>
> ```
>
> Failures of these tests due to locked components as shown above can be safely
> ignored.

## Rollback instructions

To Rollback the PSP hotfix you need to perform the following:

1. run the `rollback.sh` script in this directory
2. Perform a rolling restart of all NCN Kubernetes Workers and Masters. This process is documented in the System Administration Guide 1.4 under Section 4, Page 74.
