#!/bin/bash

echo "Setting the metricsBindAddress in kube-proxy configmap"
kubectl get cm/kube-proxy -n kube-system -o yaml | sed 's/metricsBindAddress.*/metricsBindAddress: 0.0.0.0:10249/' > /tmp/kube-proxy.yaml
kubectl apply -f /tmp/kube-proxy.yaml

echo "Restarting kube-proxy pods in kube-system namespace"
for pod in $(kubectl get po -n kube-system | grep kube-proxy | awk '{print $1}'); do
  kubectl -n kube-system delete pod $pod;
done
