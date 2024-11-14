# CASMCMS-9097 - Fixes and improvements for large scale CSM systems

## Prerequisites

- CSM versions 1.5.0 to 1.5.2

## Changelog

The list of changes depends on the CSM version on top of which this hotfix is being applied.

(Some of the fixes below are not directly related to the scale issues that are target of this hotfix, but are
pulled in along with other scale-related fixes)

### CSM 1.5.2

If applying this hotfix on CSM 1.5.2, it contains the following fixes and enhancements:

- BOS
  - v2
    - CASMCMS-9162: Add cfs_read_timeout option
      - This option is at 10 seconds by default. This is the same value that was used before this became an option that could be set.
      - This value should be raised higher when BOS requests to CFS are timing out.
    - CASMCMS-9165: Fix per-bootset CFS option
      - Without this fix, a CFS configuration set at the boot set level is ignored.
    - CASMCMS-9067: Add session_limit_required option
      - This option is disabled by default. If enabled, BOS v2 sessions cannot be created without specifying a limit
      - This can be used to avoid accidentally creating sessions with no limits specified, if desired
    - CASMCMS-9052/CASMCMS-9081: Add request timeouts to BOS reporter
      - This avoids potential hangs by the BOS state reporter, which is used to report to BOS when a node has booted
    - CASMTRIAGE-7147: Create max_component_batch_size option
      - This option limits the number of components BOS v2 will include when making API requests
      - If no limit is in place, then on systems with several thousand nodes, in some cases BOS can generate API
        requests too large for other services to handle
      - The default value for this option should be sufficient to avoid this problem
    - CASMCMS-9039: Fix applystage action
    - CASMCMS-9164: Fix runtime error in base operator bad path
    - CASMCMS-9143: When validating boot sets, check all boot sets for severe errors before returning only warnings
- CFS
  - CASMCMS-9196: Prevent failure when creating source without specifying authentication method
  - CASMCMS-9197: Significantly improve speed of some queries on large scale systems
  - CASMCMS-9198: Prevent invalid option values causing CFS to enter CrashLoopBackOff
  - CASMCMS-9200: Fix bug causing excessive redundant database and network activity
  - CASMCMS-9202: Add API action to enable restore of CFS v3 sources from backup
- CLI
  - Add support for new BOS v2 options described above
- Tests
  - CASMCMS-9029: cmsdev: More securely deal with credentials

### CSM 1.5.1

If applying this hotfix on CSM 1.5.1, it contains all of the fixes and enhancements listed above, as well as the following:

- BOS
  - v1 and v2
    - CASMCMS-9015: Instantiate S3 client in a thread-safe manner
      - Prevents a race condition that can cause some BOS operations to fail soon after full system bringup
    - CASMTRIAGE-6993: Improve BOS server resiliency and prevent OOM kill issues
  - v2
    - CASMCMS-8997: Improve logging
    - CASMCMS-8998: Optimize operator performance by bypassing unnecessary logic
    - CASMCMS-9164: Fix runtime error in base operator bad path
    - CASMCMS-9143: When validating boot sets, check all boot sets for severe errors before returning only warnings
- CFS
  - CASMCMS-8978: Fix bugs causing failures for some component patch requests
- PCS
  - CASMHMS-6148: Parse PowerConsumedWatts for any data type and intialize powercap min/max appropriately
- Tests
  - CASMCMS-9017: Do not fail BOS test if etcd snapshotter pods are running

### CSM 1.5.0

If applying this hotfix on CSM 1.5.0, it contains all of the fixes and enhancements listed above, as well as the following:

- PCS
  - CASMHMS-6156: Add POST option to get power states to avoid size limitations with GET parameters
  - CASMHMS-6146: Generate correct PowerCapURI for Olympus hardware
- BOS
  - v2
    - CASMCMS-8953: Use CFS v3 instead of v2
    - CASMCMS-8954: Make BOS more efficient when patching CFS components
    - CASMCMS-8951: Use POST instead of GET when querying PCS for node power status
    - CASMCMS-8946/CASMCMS-8952: Bypass unnecessary steps in BOS operators; Improve error handling
    - CASMCMS-8949: Improve logging
    - CASMCMS-8944: Reduce superfluous S3 calls during v2 session creation
    - CASMCMS-8941: Break up large CFS component queries to avoid failures
    - CASMCMS-8916: BOS v2 components patch/put: Fix bug, validate inputs
    - CASMCMS-8905: Removed unintended ability to update v2 session fields other than status and components
    - CASMCMS-9164: Fix runtime error in base operator bad path
    - CASMCMS-9143: When validating boot sets, check all boot sets for severe errors before returning only warnings
  - v1
    - CASMCMS-8274: Gracefully handle CAPMC locked node error
- CFS
  - CASMCMS-8966: CFSv3: Fix bug preventing creation of configurations with layers that contain special_parameters
  - CASMCMS-8964: Prevent false schema errors being logged
  - CASMCMS-8962: Fix bugs causing failures for some component patch requests
  - CASMCMS-8920: Fix ARA link for sessions
- CLI
  - CASMHMS-6154: Added workaround for setting hostname in HSM
  - CASMCMS-8905: Remove mistakenly-included BOS v2 sessions update commands
- Tests
  - CASMCMS-8958: cmsdev: Add CFS v3 coverage; make v2 testing aware of v3 pagination changes
- Utilities
  - CASMTRIAGE-6578: Updated cray-tftp-upload script to handle more than one ipxe pod

## Installation

### Apply hotfix

The `install-hotfix.sh` script may be run on any Master or Worker Non-Compute Node.
By default, it will update the BOS, CFS, and PCS services, but it will prompt the user about whether or not it
should patch the csm-noos Nexus RPM repository to include the updated Cray CLI, CMS test, and BOS reporter RPMs.
This is because in order to include the additional content, the patch script must recreate this repository,
and that is irreversible.

In order to run the script in non-interactive mode (that is, to avoid being prompted for input), it accepts the following
mutually exclusive flags:

- `--include-rpms`
  - Patch the services.
  - Recreate the Nexus RPM repo to include the updated RPMs.
- `--no-rpms`
  - Only patch the services.
  - Do not add the updated RPMs to Nexus.
- `--rpms-only`
  - Do not patch the services. (The relevant charts and images will also not be uploaded to Nexus)
  - Recreate the Nexus RPM repo to include the updated RPMs.

Example:

```bash
./install-hotfix.sh
```

### Update RPMs

The script above copies the updated RPMs into Nexus, but it does not install them on any nodes or images.
After running the script above, it is recommended to perform the following steps in order to
begin using the updated RPMs. These steps can be performed on any Kubernetes master or worker NCN where the Cray CLI
has been authenticated.

These steps are not required, but until they are done, the updated RPMs will not be in use.

1. Install the new version of the Cray CLI and CMS tests by re-running CFS node personalization on the management NCNs.

    For each management NCN, the following will clear its current state in CFS, enable it in CFS, and set its CFS
    error count to 0. This will cause CFS to re-run on these nodes.

    ```bash
    cray hsm state components list --role Management --type Node --format json | jq -r '.Components | map(.ID) | join(" ")' |
        xargs -n 1 cray cfs components update --state '[]' --enabled true --error-count 0 --format json
    ```

2. Re-customize any images that will be booted using BOS v2.

    > This generally means any images except for management NCN images.

    No changes need to be made to the CFS configurations being used. The CSM layer of the configuration will install the
    updated BOS reporter RPM when it runs.

    For more information, see
    - [Create an Image Management Customization CFS Session](https://github.com/Cray-HPE/docs-csm/blob/release/1.5/operations/configuration_management/Create_an_Image_Customization_CFS_Session.md]
    - [Create UAN Boot Images](https://github.com/Cray-HPE/docs-csm/blob/release/1.5/operations/image_management/Create_UAN_Boot_Images.md)

## Rollback

- To revert BOS to its previous version:

    ```bash
    helm -n services rollback cray-bos
    ```

- To revert CFS to its previous version:

    ```bash
    helm -n services rollback cray-cfs-api
    ```

- To revert PCS to its previous version:

    ```bash
    helm -n services rollback cray-power-control
    ```
