# CASMCMS-9044 - Fixes and improvements for large scale CSM systems

## Prerequisites

- CSM versions 1.4.0 to 1.4.4

## Changelog

The list of changes depends on the CSM version on top of which this hotfix is being applied.

### CSM 1.4.3 or 1.4.4

If applying this hotfix on CSM 1.4.3 or 1.4.4, it contains the following fixes and enhancements:

- BOS
  - v1 and v2
    - CASMCMS-9015: Instantiate S3 client in a thread-safe manner
      - Prevents a race condition that can cause some BOS operations to fail soon after full system bringup
    - CASMTRIAGE-6993: Improve BOS server resiliency and prevent OOM kill issues
  - v2
    - CASMCMS-9225: Improve performance of large GET components requests
    - CASMCMS-9162/CASMCMS-9242: Add BOS options: bss_read_timeout, capmc_read_timeout, cfs_read_timeout, hsm_read_timeout
      - These options are each at 10 seconds by default. This is the same value that was used before this became an option that could be set.
      - This value should be raised higher when BOS requests to the particular service are timing out.
    - CASMCMS-9165: Fix per-bootset CFS option
      - Without this fix, a CFS configuration set at the boot set level is ignored.
    - CASMCMS-9143: Fix bug in validate session template endpoint that caused severe errors to be overlooked in some cases.
    - CASMCMS-9067: Add session_limit_required option
      - This option is disabled by default. If enabled, BOS v2 sessions cannot be created without specifying a limit
      - This can be used to avoid accidentally creating sessions with no limits specified, if desired
    - CASMTRIAGE-7147: Create max_component_batch_size option
      - This option limits the number of components BOS v2 will include when making API requests
      - If no limit is in place, then on systems with several thousand nodes, in some cases BOS can generate API
        requests too large for other services to handle
      - The default value for this option should be sufficient to avoid this problem
    - CASMCMS-9051: Harden operators against read hangs
      - This fixes a problem where BOS v2 operators could end up hung indefinitely
    - CASMCMS-9052/CASMCMS-9081: Add request timeouts to BOS reporter
      - This avoids potential hangs by the BOS state reporter, which is used to report to BOS when a node has booted
    - CASMCMS-8996: Improve scalability of how BOS v2 handles vague CAPMC operation failures
    - CASMCMS-8949/CASMCMS-8997: Improve logging
    - CASMCMS-8952/CASMCMS-8998: Optimize operator performance by bypassing unnecessary logic
    - CASMCMS-8995: Fix bug causing some CAPMC failures to be incompletely interpreted by BOS
    - CASMCMS-8954: Make BOS more efficient when patching CFS components
    - CASMCMS-8835: Do not prematurely filter out disabled nodes
      - Necessary in order to allow the include_disabled nodes capability to work
    - CASMCMS-8830: Fix bug preventing session status from being properly updated in cases when it has no nodes to act on
    - CASMCMS-8614: Remove on_hold components from session status phases
    - CASMCMS-8617: Remove failed nodes from session status phases
    - CASMCMS-8946: Fix bugs in operator logic
    - CASMCMS-8944: Reduce superfluous S3 calls during v2 session creation
    - CASMCMS-8941: Break up large CFS component queries to avoid failures
  - v1
    - CASMCMS-8274: Gracefully handle CAPMC locked node error
- CFS
  - CASMTRIAGE-6865/CASMCMS-8962/CASMCMS-8978: Fix bugs causing failures for some component patch requests
  - CASMCMS-8964: Prevent false schema errors being logged
- CLI
  - Add support for new BOS v2 options described above

### CSM 1.4.2

If applying this hotfix on CSM 1.4.2, it contains all of the fixes and enhancements listed above, as well as the following:

- BOS v2
  - CASMCMS-8754: Make BOS V2 status operator resilient to power errors
  - CASMTRIAGE-5820: Fix bug with HSM query handling
- CFS
  - CASMCMS-8809/CAST-34044: Fix bug that can causing cfs-hwsync-agent to hang

### CSM 1.4.0 or CSM 1.4.1

If applying this hotfix on CSM 1.4.0 or CSM 1.4.1, it contains all of the fixes and enhancements listed above, as well as the following:

- CLI
  - CASMCMS-8599: Add CLI support for --include_disabled option on BOS v2 session creation

## Installation

### Apply hotfix

The `install-hotfix.sh` script may be run on any Master or Worker Non-Compute Node.
By default, it will update the BOS, CFS, and cfs-hwsync-agent services, but it will prompt the user about whether or not it
should patch the Nexus RPM repositories to include the updated Cray CLI and BOS reporter RPMs. This is because in order to
include the additional content, the patch script must recreate these repositories, and that is irreversible.

In order to run the script in non-interactive mode (that is, to avoid being prompted for input), it accepts the following
mutually exclusive flags:

- `--include-rpms`
  - Patch the BOS, CFS, and cfs-hwsync-agent services.
  - Recreate the csm-sle-15sp2-compute, csm-sle-15sp3-compute, csm-sle-15sp4-compute, and csm-sle-15sp4 Nexus repos to include
    the updated BOS reporter and Cray CLI RPMs.
- `--no-rpms`
  - Only patch the BOS, CFS, and cfs-hwsync-agent services.
  - Do not add the updated Cray CLI and BOS reporter RPMs to Nexus.
- `--rpms-only`
  - Do not patch the BOS, CFS, and cfs-hwsync-agent services. (The relevant charts and images will also not be uploaded to Nexus)
  - Recreate the csm-sle-15sp2-compute, csm-sle-15sp3-compute, csm-sle-15sp4-compute, and csm-sle-15sp4 Nexus repos to include
    the updated BOS reporter and Cray CLI RPMs.

Example:

```bash
./install-hotfix.sh
```

### Update RPMs

The script above copies the updates BOS reporter and Cray CLI RPMs into the Nexus repositories, but it does not install
them on any nodes or images. After running the script above, it is recommended to perform the following steps in order to
begin using the updated RPMs. These steps can be performed on any Kubernetes master or worker NCN where the Cray CLI
has been authenticated.

These steps are not required, but until they are done, the updated RPMs will not be in use.

1. Install the new version of the Cray CLI by re-running CFS node personalization on the management NCNs.

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
    - [Create an Image Management Customization CFS Session](https://github.com/Cray-HPE/docs-csm/blob/release/1.4/operations/configuration_management/Create_an_Image_Customization_CFS_Session.md]
    - [Create UAN Boot Images](https://github.com/Cray-HPE/docs-csm/blob/release/1.4/operations/image_management/Create_UAN_Boot_Images.md)

## Rollback

- To revert BOS to its previous version:

    ```bash
    helm -n services rollback cray-bos
    ```

- To revert CFS to its previous version:

    ```bash
    helm -n services rollback cray-cfs-api
    ```

- To revert `cfs-hwsync-agent` to its previous version:

    ```bash
    helm -n services rollback cfs-hwsync-agent
    ```
