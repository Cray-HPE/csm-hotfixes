# CASMINST-6799: Race condition causes IUF to not automatically proceed to next stage or partial workflow

## Problem Description

In CSM 1.5.0, there is a critical bug in IUF which prevents certain stages like `deliver-product` stage to hang. This is a race condition that has surfaced after upgrading K8S.

**You only need to apply this workaround if you are on CSM 1.5.0.** All CSM versions from 1.5.1 onwards have this fix already.

## How to install

To apply the workaround:

Run the contained script `install-hotfix.sh`.