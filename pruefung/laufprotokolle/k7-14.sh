#!/bin/bash
export PATH=/snap/bin:/usr/local/bin:$PATH
export TERM=xterm
cd ~/buch
h(){ echo; echo "##### $*"; }
h K12 hostname aus log
grep -m1 'parent_kind="EgressNetwork"' ~/k8-12.log | grep -o -E '(route_name|hostname|parent_kind)="[^"]*"'
h K4 top tty
timeout 10 script -qec "linkerd viz -n emojivoto top deploy/web" /tmp/top.txt >/dev/null 2>&1
sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' /tmp/top.txt | tr -d '\r' | grep -a -E 'Source|/api|Vote|ListAll|rror' | tail -6 | cut -c1-110
h K8 promql korrigiert
kubectl -n linkerd-viz port-forward deploy/prometheus 19090:9090 >/dev/null 2>&1 & PF=$!
sleep 4
curl -s --get localhost:19090/api/v1/query --data-urlencode 'query=min(control_identity_cert_expiration_timestamp_seconds) - time()' | jq -c '.status,.data.result[0].value'
curl -s --get localhost:19090/api/v1/query --data-urlencode 'query=count(identity_cert_expiration_timestamp_seconds)' | jq -c '.data.result'
kill $PF
h K9 serviceprofile mit route
cat <<SP | kubectl apply -f -
apiVersion: linkerd.io/v1alpha2
kind: ServiceProfile
metadata:
  name: flaky.resilienz.svc.cluster.local
  namespace: resilienz
spec:
  routes:
    - name: alles
      condition:
        pathRegex: /.*
SP
sleep 85
linkerd viz -n resilienz stat-outbound deploy/last-flaky
linkerd viz -n resilienz stat deploy/flaky
kubectl delete ns resilienz circuit-breaking-demo traffic-shift-demo egress-test --ignore-not-found --wait=false | tail -4
h K14 upgrade gleiche version
linkerd check 2>&1 | tail -1
linkerd check --proxy 2>&1 | tail -1
linkerd upgrade --crds | kubectl apply -f - 2>&1 | tail -2
linkerd upgrade | kubectl apply -f - 2>&1 | tail -2
echo "--- prune:"; linkerd prune | kubectl delete -f -; echo "prune_rc=${PIPESTATUS[1]}"
linkerd check 2>&1 | tail -1
linkerd viz install | kubectl apply -f - 2>&1 | tail -1
echo "--- viz prune:"; linkerd viz prune | kubectl delete -f -; echo "viz_prune_rc=${PIPESTATUS[1]}"
kubectl -n emojivoto rollout restart deploy
kubectl -n emojivoto rollout status deploy/web --timeout=120s | tail -1
linkerd check --proxy 2>&1 | tail -1
h K7 step installieren
cd /tmp/dl
curl -fsSLO https://github.com/smallstep/cli/releases/download/v0.31.0/step_linux_0.31.0_arm64.tar.gz
echo "9937964c7d47de47a511cd775bd07101b8ee9854db210abd402c69093f0a6fd4  step_linux_0.31.0_arm64.tar.gz" | sha256sum -c -
tar xzf step_linux_0.31.0_arm64.tar.gz && sudo install -m 755 step_0.31.0/bin/step /usr/local/bin/step
step version | head -1
cd ~/buch
h K7 lab-cluster weg, pki-cluster
kind delete cluster --name linkerd-lab 2>&1 | tail -1
kind create cluster --config labs/00-cluster/kind-config.yaml --name linkerd-pki 2>&1 | tail -3
kubectl config current-context
kubectl wait --for=condition=Ready nodes --all --timeout=120s | tail -1
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml | tail -1
mkdir -p ~/linkerd-pki-lab && cd ~/linkerd-pki-lab
step certificate create root.linkerd.cluster.local ca.crt ca.key --profile root-ca --no-password --insecure
step certificate create identity.linkerd.cluster.local issuer.crt issuer.key --profile intermediate-ca --not-after 8760h --no-password --insecure --ca ca.crt --ca-key ca.key
helm repo add linkerd-edge https://helm.linkerd.io/edge
helm repo update | tail -1
helm install linkerd-crds linkerd-edge/linkerd-crds -n linkerd --create-namespace --version 2026.11.1 2>&1 | tail -3
helm install linkerd-control-plane -n linkerd --set-file identityTrustAnchorsPEM=ca.crt --set-file identity.issuer.tls.crtPEM=issuer.crt --set-file identity.issuer.tls.keyPEM=issuer.key --version 2026.11.1 linkerd-edge/linkerd-control-plane 2>&1 | tail -4
linkerd check 2>&1 | grep -v '√' | tail -12; echo "check_rc=${PIPESTATUS[0]}"
h K7 fingerprint
step certificate fingerprint ca.crt
kubectl -n linkerd get cm linkerd-identity-trust-roots -o jsonpath='{.data.ca-bundle\.crt}' | step certificate fingerprint; echo "fp_rc=${PIPESTATUS[1]}"
kubectl -n linkerd get cm linkerd-identity-trust-roots -o json | jq -c '.data|keys'
h K14 helm ha
helm fetch --untar linkerd-edge/linkerd-control-plane --version 2026.11.1; echo "fetch_rc=$?"; ls linkerd-control-plane/values-ha.yaml
helm get values linkerd-control-plane -n linkerd > values.yaml
timeout 150 helm upgrade linkerd-control-plane -n linkerd --set-file identityTrustAnchorsPEM=ca.crt --set-file identity.issuer.tls.crtPEM=issuer.crt --set-file identity.issuer.tls.keyPEM=issuer.key -f linkerd-control-plane/values-ha.yaml --version 2026.11.1 linkerd-edge/linkerd-control-plane 2>&1 | tail -3
sleep 30
kubectl -n linkerd get pods -o wide | cut -c1-95
kubectl get nodes
kubectl -n linkerd get pods | grep -c Pending
kubectl -n linkerd describe pod $(kubectl -n linkerd get pods | awk '/Pending/{print $1;exit}') 2>/dev/null | grep -A4 Events | cut -c1-170
h K14 helm upgrade atomic
timeout 120 helm upgrade linkerd-crds linkerd-edge/linkerd-crds -n linkerd --version 2026.11.1 2>&1 | tail -2; echo "rc=${PIPESTATUS[0]}"
timeout 200 helm upgrade linkerd-control-plane linkerd-edge/linkerd-control-plane -n linkerd --version 2026.11.1 --reset-values -f values.yaml --atomic 2>&1 | tail -3; echo "atomic_rc=${PIPESTATUS[0]}"
helm upgrade --help | grep -E -- '--atomic|--rollback-on-failure|--reset-values' | cut -c1-100
kubectl -n linkerd get pods --no-headers | wc -l
h K7 aufraeumen
kind delete cluster --name linkerd-pki 2>&1 | tail -1
echo "context nachher: [$(kubectl config current-context 2>&1)]"
kubectl get nodes 2>&1 | head -2
echo ENDE
