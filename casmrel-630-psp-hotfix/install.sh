#!/usr/bin/env bash
set -ex
set -o pipefail

echo "* Upgrading spire chart"
kubectl delete job -n spire spire-update-bss
helm upgrade -n spire spire ./spire-0.8.17.tgz

echo "* Upgrading spire-intermediate chart"
helm upgrade -n vault spire-intermediate ./spire-intermediate-0.2.1.tgz

echo "* Installing cray-psp WAR chart"
helm install -n services cray-psp ./cray-psp-0.1.1.tgz

for master in $(kubectl get nodes | grep 'master' | awk '{print $1}'); do
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
  echo "Install completed. Please follow admin guide instructions on rebooting all NCNs."
else
  echo "One or more kube-apiservers failed to enable PodSecurityPolicy. Please manually fix before restarting NCNs"
fi
