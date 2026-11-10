#!/bin/bash
export PATH=/snap/bin:/usr/local/bin:$PATH
h(){ echo; echo "##### $*"; }
mkdir -p ~/mc && cd ~/mc
IMG=kindest/node:v1.35.8@sha256:07b2536e30b803ed61d1677a79df6115f798ce64c80f9e22f6ed45afd09323c0
step certificate create root.linkerd.cluster.local ca.crt ca.key --profile root-ca --no-password --insecure >/dev/null 2>&1
for c in west east; do
  kind create cluster --name $c --image "$IMG" 2>&1 | tail -1 >/dev/null
  kubectl config rename-context kind-$c $c >/dev/null
  kubectl --context=$c wait --for=condition=Ready nodes --all --timeout=120s | tail -1
  kubectl --context=$c apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml >/dev/null
  step certificate create identity.linkerd.cluster.local $c-issuer.crt $c-issuer.key --profile intermediate-ca --not-after 8760h --no-password --insecure --ca ca.crt --ca-key ca.key >/dev/null 2>&1
  linkerd --context=$c install --crds 2>/dev/null | kubectl --context=$c apply -f - >/dev/null
  linkerd --context=$c install --identity-trust-anchors-file ca.crt --identity-issuer-certificate-file $c-issuer.crt --identity-issuer-key-file $c-issuer.key | kubectl --context=$c apply -f - >/dev/null
  linkerd --context=$c check 2>&1 | tail -1
done
linkerd --context=west multicluster install | kubectl --context=west apply -f - >/dev/null
linkerd --context=east multicluster install --set gateway.serviceType=NodePort | kubectl --context=east apply -f - >/dev/null
printf 'controllers:\n- link:\n    ref:\n      name: east\n' > values.yaml
linkerd --context=west multicluster install -f values.yaml | kubectl --context=west apply -f - >/dev/null
kubectl --context=east -n linkerd-multicluster rollout status deploy/linkerd-gateway --timeout=150s | tail -1
EASTIP=$(docker inspect east-control-plane -f '{{.NetworkSettings.Networks.kind.IPAddress}}')
GWPORT=$(kubectl --context=east -n linkerd-multicluster get svc linkerd-gateway -o jsonpath='{.spec.ports[?(@.name=="mc-gateway")].nodePort}')
PRPORT=$(kubectl --context=east -n linkerd-multicluster get svc linkerd-gateway -o jsonpath='{.spec.ports[?(@.name=="mc-probe")].nodePort}')
echo "east=$EASTIP gw=$GWPORT probe=$PRPORT"
h link-gen
linkerd --context=east multicluster link-gen --cluster-name east --api-server-address https://$EASTIP:6443 --gateway-addresses $EASTIP --gateway-port $GWPORT > link.yaml 2>link.err; echo "rc=$?"; head -3 link.err | cut -c1-200
grep -E '^kind:' link.yaml | sort | uniq -c
grep -n -A6 -E 'probeSpec' link.yaml | cut -c1-80
sed -i "s/^\( *port: \)\"\?4191\"\?$/\1\"$PRPORT\"/" link.yaml
grep -n -A6 -E 'probeSpec' link.yaml | cut -c1-80
kubectl --context=west apply -f link.yaml 2>&1 | tail -5
sleep 30
kubectl --context=west -n linkerd-multicluster get pods,links.multicluster.linkerd.io 2>&1 | cut -c1-110
h checks
linkerd --context=west multicluster check 2>&1 | grep -v '√' | tail -14; echo "mc_check_rc=${PIPESTATUS[0]}"
linkerd --context=west multicluster gateways 2>&1 | cut -c1-110
h spiegeln
kubectl --context=east create ns test >/dev/null
kubectl --context=east annotate ns test linkerd.io/inject=enabled >/dev/null
kubectl --context=east -n test create deploy podinfo --image=nginx:alpine >/dev/null
kubectl --context=east -n test expose deploy podinfo --port=80 >/dev/null
kubectl --context=east -n test rollout status deploy/podinfo --timeout=120s | tail -1
kubectl --context=west create ns test >/dev/null
kubectl --context=west annotate ns test linkerd.io/inject=enabled >/dev/null
kubectl --context=east label svc -n test podinfo mirror.linkerd.io/exported=true
sleep 15
kubectl --context=west -n test get svc,endpointslices 2>&1 | cut -c1-100
kubectl --context=west -n test run c --image=curlimages/curl:8.23.0 --command -- sleep 3600 >/dev/null
kubectl --context=west -n test wait --for=condition=Ready pod/c --timeout=120s | tail -1
sleep 5
for i in 1 2 3 4; do kubectl --context=west -n test exec c -c c -- curl -s -m 8 -o /dev/null -w '%{http_code} %{time_total}\n' http://podinfo-east.test:80/; done
linkerd --context=west multicluster gateways 2>&1 | cut -c1-110
kubectl --context=east -n test logs deploy/podinfo -c podinfo --tail=2 2>&1 | cut -c1-110
h aufraeumen
kind delete cluster --name west 2>&1 | tail -1
kind delete cluster --name east 2>&1 | tail -1
rm -rf ~/mc
echo ENDE
