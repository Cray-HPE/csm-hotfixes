# CASMINST-6799: Race condition causes IUF to not automatically proceed to next stage or partial workflow

## Problem Description

In CSM 1.5.0, there is a critical bug in IUF which prevents certain stages like `deliver-product` stage to hang. This is a race condition that has surfaced after upgrading K8S.

**You only need to apply this workaround if you are on CSM 1.5.0.** All CSM versions from 1.5.1 onwards have this fix already.

## When to install

You will need to install this hotfix either:

1. Before upgrading products: You will need to install this hotfix after upgrading to CSM 1.5.0, but before beginning any product upgrades with IUF.
2. After fresh install of CSM 1.5.0: You will need to install this hotfix after fresh install of CSM 1.5.0 and before installation of any other product.

## How to install

To apply the workaround:

Run the contained script `install-hotfix.sh`.
