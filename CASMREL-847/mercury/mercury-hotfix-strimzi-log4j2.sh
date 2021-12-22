#! /bin/bash
#
# Copyright 2021 Hewlett Packard Enterprise Development LP

#Notes on getting, applying, and using the casmrel-847 hotfix.

# Step 1
curl -O https://storage.googleapis.com/csm-release-public/hotfix/casmrel-847-1.0.1.tar.gz
# That can be done from an external networked system but the tarball needs to be placed on each of the hypervisors.
# takes about 10-30s to download in the U.S. and is roughly 409M.

# Explode the tarball
tar zxvf casmrel-847-1.0.1.tar.gz
# At this point, I just rsync the untarred to the other two nodes in my Mercury cluster
rsync -Pauv casmrel-847-1.0.1 "$HYPERVISOR2":
rsync -Pauv casmrel-847-1.0.1 "$HYPERVISOR3":

# You can list the contents of casmrel-847-0.9.29999 (but you should have also seen them as they were exploded and rsynced).
ls -lR casmrel-847-1.0.1
# output omitted here

# Step 2
# Place the new chart in the proper location for Mercury
rsync -auv casmrel-847-1.0.1/helm/cray-kafka-operator-0.4.2.tgz  /opt/cray/helm_charts/

# If you list that directory in chronological order you should see the cray-kafka-operator-0.4.2 at the bottom
ls -alFhtr /opt/cray/helm_charts/
# lines omitted at the bottom
# -rw-rw-r--  1 10000 10000  23K Dec 20 15:18 cray-kafka-operator-0.4.2.tgz

# Step 3
# Place the new image with the patched version of strimzi-operator in the proper place
rsync -auv casmrel-847-1.0.1/docker/dtr.dev.cray.com/strimzi/operator\:0.15.0-noJndiLookupClass /opt/cray/registry-images/docker/dtr.dev.cray.com/strimzi/

# Step 4
# Update the image registry
/opt/cray/bin/registry/upload_images

# Step 5
# Modify the manifest in use
#
# There is a patchfile for this. You need to place it on the systems.
patch /opt/cray/shasta-cfg-src/manifests/platform.yaml release-mercury-1.0.3-cray-kafka-operator-0.4.2.patch
# You will have to provide this path to the file: /opt/cray/shasta-cfg-src/manifests/platform.yaml

echo Make sure you did the preceding 5 steps on all 3 nodes in the cluster

# Step 6
# Run the manifest
# You want to use the same invocation initially used when bringing up the Mercury manifests with one environment variable added.
# This is done on a single node (typically the first hypervisor where you began this work)
#
# Typically, the execution is like this:
only_manifests=platform /opt/cray/terraform/bin/mercury manifest --with-ssm --with-sma --tld="$YOUR_TLD"
# $YOUR_TLD is likely $MERCURY_DOMAIN or $TF_VAR_domain and they are typically set the same.
# This is a per site customization and is more or less the cluster system name
# The only manifest modified in this hotfix is the platform manifest so we are limiting the manifest run to solely that.
