#!/bin/bash
export PATH=/snap/bin:/usr/local/bin:$PATH
IMG=kindest/node:v1.35.8@sha256:07b2536e30b803ed61d1677a79df6115f798ce64c80f9e22f6ed45afd09323c0
kind create cluster --name k3 --image "$IMG" >/dev/null 2>&1
kubectl wait --for=condition=Ready nodes --all --timeout=120s | tail -1
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml >/dev/null
echo "### helm crds"
helm install linkerd-crds linkerd-edge/linkerd-crds -n linkerd --create-namespace --version 2026.11.1 2>&1 | head -2
echo "### helm upgrade ohne -n (alte Buchfassung)"
helm upgrade linkerd-crds linkerd-edge/linkerd-crds 2>&1 | head -3; echo "rc=${PIPESTATUS[0]}"
linkerd install | kubectl apply -f - >/dev/null
linkerd check 2>&1 | tail -1
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/emojivoto.yml | linkerd inject - 2>/dev/null | kubectl apply -f - >/dev/null
kubectl -n emojivoto rollout status deploy/voting --timeout=180s | tail -1
echo "### pod struktur"
kubectl -n emojivoto get po -o json | jq -r '.items[]|select(.metadata.name|startswith("voting"))|"init: \([.spec.initContainers[]|.name+"(restart="+(.restartPolicy//"-")+")"]|join(", "))\ncontainers: \([.spec.containers[].name]|join(", "))"'
