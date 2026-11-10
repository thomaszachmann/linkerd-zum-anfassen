#!/bin/bash
export PATH=/snap/bin:/usr/local/bin:$PATH
export TERM=xterm
h(){ echo; echo "##### $*"; }
mkdir -p ~/mc && cd ~/mc
IMG=kindest/node:v1.35.8@sha256:07b2536e30b803ed61d1677a79df6115f798ce64c80f9e22f6ed45afd09323c0
step certificate create root.linkerd.cluster.local ca.crt ca.key --profile root-ca --no-password --insecure >/dev/null 2>&1
for c in west east; do
  kind create cluster --name $c --image "$IMG" 2>&1 | tail -1
  kubectl config rename-context kind-$c $c
  kubectl --context=$c wait --for=condition=Ready nodes --all --timeout=120s | tail -1
  kubectl --context=$c apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml | tail -1
  step certificate create identity.linkerd.cluster.local $c-issuer.crt $c-issuer.key --profile intermediate-ca --not-after 8760h --no-password --insecure --ca ca.crt --ca-key ca.key >/dev/null 2>&1
  linkerd --context=$c install --crds | kubectl --context=$c apply -f - | tail -1
  linkerd --context=$c install --identity-trust-anchors-file ca.crt --identity-issuer-certificate-file $c-issuer.crt --identity-issuer-key-file $c-issuer.key | kubectl --context=$c apply -f - | tail -1
  linkerd --context=$c check 2>&1 | tail -1
done
h K13 buch schritt 1 install beide
for ctx in west east; do
  linkerd --context=${ctx} multicluster install | kubectl --context=${ctx} apply -f - 2>&1 | tail -2
done
kubectl --context=east -n linkerd-multicluster get svc,pods 2>&1 | cut -c1-110
h K13 buch schritt 2 controller
cat <<EOV > values.yaml
controllers:
- link:
    ref:
      name: east
EOV
linkerd --context=west multicluster install -f values.yaml | kubectl --context=west apply -f - 2>&1 | tail -3
h K13 link-gen hilfe
linkerd multicluster link-gen --help 2>&1 | grep -E -- '--(api-server-address|gateway|set|cluster-name|service-account|log)' | cut -c1-110
h K13 buch link-gen unveraendert
linkerd --context=east multicluster link-gen --cluster-name east > link-buch.yaml 2>link-buch.err; echo "linkgen_rc=$?"; head -5 link-buch.err | cut -c1-200; grep -E '^kind:' link-buch.yaml | sort | uniq -c
h K13 gateway NodePort fuer kind
linkerd --context=east multicluster install --set gateway.serviceType=NodePort | kubectl --context=east apply -f - 2>&1 | tail -1
kubectl --context=east -n linkerd-multicluster rollout status deploy/linkerd-gateway --timeout=120s | tail -1
kubectl --context=east -n linkerd-multicluster get svc linkerd-gateway -o wide | cut -c1-120
EASTIP=$(docker inspect east-control-plane -f '{{.NetworkSettings.Networks.kind.IPAddress}}')
GWPORT=$(kubectl --context=east -n linkerd-multicluster get svc linkerd-gateway -o jsonpath='{.spec.ports[?(@.name=="mc-gateway")].nodePort}')
PRPORT=$(kubectl --context=east -n linkerd-multicluster get svc linkerd-gateway -o jsonpath='{.spec.ports[?(@.name=="mc-probe")].nodePort}')
echo "east=$EASTIP gw=$GWPORT probe=$PRPORT"
linkerd --context=east multicluster link-gen --cluster-name east --api-server-address https://$EASTIP:6443 --gateway-addresses $EASTIP --gateway-port $GWPORT --set gateway.probe.port=$PRPORT > link.yaml 2>link.err; echo "linkgen2_rc=$?"; head -5 link.err | cut -c1-220
grep -E '^kind:' link.yaml | sort | uniq -c
kubectl --context=west apply -f link.yaml 2>&1 | tail -4
sleep 25
kubectl --context=west -n linkerd-multicluster get pods,links.multicluster.linkerd.io 2>&1 | cut -c1-110
h K13 checks
linkerd --context=west multicluster check 2>&1 | grep -v '√' | tail -14; echo "mc_check_rc=${PIPESTATUS[0]}"
linkerd --context=west multicluster gateways 2>&1 | cut -c1-110
h K13 service spiegeln
kubectl --context=east create ns test
kubectl --context=east annotate ns test linkerd.io/inject=enabled
kubectl --context=east -n test create deploy podinfo --image=nginx:alpine
kubectl --context=east -n test expose deploy podinfo --port=80
kubectl --context=east -n test rollout status deploy/podinfo --timeout=120s | tail -1
kubectl --context=west create ns test
kubectl --context=east label svc -n test podinfo mirror.linkerd.io/exported=true
sleep 15
kubectl --context=west -n test get svc,endpoints 2>&1 | cut -c1-100
kubectl --context=west annotate ns test linkerd.io/inject=enabled
kubectl --context=west -n test run c --image=curlimages/curl:8.23.0 --command -- sleep 3600 >/dev/null
kubectl --context=west -n test wait --for=condition=Ready pod/c --timeout=120s | tail -1
sleep 5
for i in 1 2 3; do kubectl --context=west -n test exec c -c c -- curl -s -m 8 -o /dev/null -w '%{http_code} %{time_total}\n' http://podinfo-east.test:80/; done
linkerd --context=west multicluster gateways 2>&1 | cut -c1-110
h top test
linkerd --context=west viz install 2>/dev/null | kubectl --context=west apply -f - | tail -1
linkerd --context=west viz check 2>&1 | tail -1
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/emojivoto.yml | linkerd --context=west inject - | kubectl --context=west apply -f - | tail -1
kubectl --context=west -n emojivoto rollout status deploy/web --timeout=180s | tail -1
kubectl config use-context west
sleep 20
timeout -s INT 12 script -qfc "linkerd viz -n emojivoto top deploy/web" /tmp/top.txt >/dev/null </dev/null 2>&1
ls -la /tmp/top.txt; sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g; s/\x1b(B//g' /tmp/top.txt | tr -d '\r' | grep -a -i -E 'source|/api|Vote|error' | tail -6 | cut -c1-110
head -c 300 /tmp/top.txt | cat -v | cut -c1-200 | head -4
h ressourcen
free -h | sed -n 2p; df -h / | tail -1
h aufraeumen
kind delete cluster --name west 2>&1 | tail -1
kind delete cluster --name east 2>&1 | tail -1
rm -rf ~/mc ~/linkerd-pki-lab
echo ENDE
