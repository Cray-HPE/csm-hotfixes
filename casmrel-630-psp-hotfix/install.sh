#!/usr/bin/env bash
set -e
set -o pipefail

spireVersion="spire-0.8.17"
spireIntermediateVersion="spire-intermediate-0.2.2"
crayPspVersion="cray-psp-0.1.2"

installedSpireVersion=$(helm ls -n spire -o json | jq -r '.[] | select(.name | contains("spire")) | .chart')
installedSpireIntermediateVersion=$(helm ls -n vault -o json | jq -r '.[] | select(.name | contains("spire-intermediate")) | .chart')

if [ "$spireVersion" != "$installedSpireVersion" ]; then
  echo "* Upgrading spire chart"
  kubectl delete job -n spire spire-update-bss || true
  helm upgrade -n spire spire ./helm/${spireVersion}.tgz
fi

if [ "$spireIntermediateVersion" != "$installedSpireIntermediateVersion" ]; then
  echo "* Upgrading spire-intermediate chart"
  helm upgrade -n vault spire-intermediate ./helm/${spireIntermediateVersion}.tgz
fi

if ! helm get values -n services cray-psp >/dev/null 2>/dev/null; then
  echo "* Installing cray-psp WAR chart"
  helm install -n services cray-psp ./helm/${crayPspVersion}.tgz
fi

for master in $(kubectl get nodes | grep 'master' | awk '{print $1}'); do
  if ! kubectl describe pod -n kube-system "kube-apiserver-${master}" | grep -q 'enable-admission-plugins=NodeRestriction,PodSecurityPolicy'; then
	echo "* Enabling PodSecurityPolicy on kube-apiserver node ${master}"
	  ssh "$master" "sed -i 's/--enable-admission-plugins=NodeRestriction$/--enable-admission-plugins=NodeRestriction,PodSecurityPolicy/' /etc/kubernetes/manifests/kube-apiserver.yaml"

	for i in 1 2 3 4 5; do
	  if kubectl describe pod -n kube-system "kube-apiserver-${master}" | grep -q 'enable-admission-plugins=NodeRestriction,PodSecurityPolicy'; then
	    sleep 5
	    break
	  fi
	  sleep 10
	done

	  if ! kubectl describe pod -n kube-system "kube-apiserver-${master}" | grep -q 'enable-admission-plugins=NodeRestriction,PodSecurityPolicy'; then
	    echo "kube-apiserver-${master} pod did not restart on it's own. Forcing recreation."
	    echo kubectl rm pod -n kube-system "kube-apiserver-${master}"
	    sleep 10
	  fi
  else
    echo "* PodSecurityPolicy already enabled on kube-apiserver node ${master}"
  fi
done

echo "* Validating kube-apiserver pods all have PodSecurityPolicy enabled"

fail=0
for master in $(kubectl get nodes | grep 'master' | awk '{print $1}'); do
  if ! kubectl describe pod -n kube-system "kube-apiserver-${master}" | grep -q 'enable-admission-plugins=NodeRestriction,PodSecurityPolicy'; then
    echo "PodSecurityPolicy failed to enable on kube-apiserver-${master}"
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "Install completed."
else
  echo "One or more kube-apiservers failed to enable PodSecurityPolicy. Please manually enable the PodSecurityPolicy on the failed nodes by making sure the enable-admissions-plugins line in /etc/kubernetes/manifests/kube-apiserver.yaml looks like --enable-admission-plugins=NodeRestriction,PodSecurityPolicy"
fi
