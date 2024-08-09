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

The `install-hotfix.sh` script may be run on any Master or Worker Non-Compute Node.
By default, it will update the BOS, CFS, and cfs-hwsync-agent services, but it will prompt the user about whether or not it
should patch the Nexus RPM repositories to include the updated Cray CLI and BOS reporter RPMs. This is because in order to
include the additional content, the patch script must recreate these repositories, and that is irreversible.

In order to run the script in non-interactive mode (that is, to avoid being prompted for input), it accepts the following
mutually exclusive flags:

- `--include-rpms`
  - Patch the BOS, CFS, and cfs-hwsync-agent services.
  - Recreate the csm-noos, csm-sle-15sp2, csm-sle-15sp3, and csm-sle-15sp4 Nexus repos to include the updated BOS reporter and Cray CLI RPMs.
- `--no-rpms`
  - Only patch the BOS, CFS, and cfs-hwsync-agent services.
  - Do not add the updated Cray CLI and BOS reporter RPMs to Nexus.
- `--rpms-only`
  - Do not patch the BOS, CFS, and cfs-hwsync-agent services. (The relevant charts and images will also not be uploaded to Nexus)
  - Recreate the csm-noos, csm-sle-15sp2, csm-sle-15sp3, and csm-sle-15sp4 Nexus repos to include the updated BOS reporter and Cray CLI RPMs.

Example:

```bash
./install-hotfix.sh
```

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
