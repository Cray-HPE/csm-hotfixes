# CASMTRIAGE-6698 - cray-hms-rts-snmp pod stuck in CLBO

## Prerequisites

- CSM versions 1.5.0
  - This fix is included in CSM versions 1.5.1 and up

## Changelog

This hotfix contains the following fixes and enhancements.

- CASMTRIAGE-6698 - cray-hms-rts-snmp pod stuck in CLBO
  - Fixed concurrency issue associated with RedisActivePipeline
- CASMHMS-6099 - Add TTL setting to cray-hms-rts-init job

## Installation

The `install-hotfix.sh` script may be run on any Master or Worker Non-Compute Node.

Example:

```bash
./install-hotfix.sh
```

## Rollback

To revert `cray-hms-rts` and `cray-hms-rts-snmp` to the previous revisions, select revision numbers to rollback to, for both charts:

```bash
helm -n services history cray-hms-rts
helm -n services history cray-hms-rts-snmp
```

Then perform rollback:

```bash
helm -n services rollback cray-hms-rts <revision>
helm -n services rollback cray-hms-rts-snmp <revision>
```
