#!/bin/bash
export PATH=/snap/bin:/usr/local/bin:$PATH
cd ~/buch
h(){ echo; echo "##### $*"; }
h metrik-namen
linkerd diagnostics proxy-metrics -n emojivoto deploy/web > /tmp/m.txt
grep -i -E '^[a-z_]*(cert|identity|expir)[a-z_]*' /tmp/m.txt | cut -c1-150 | head -10
grep -E '^# (HELP|TYPE) .*(cert|expir)' /tmp/m.txt | cut -c1-140
h api-resources httproute
kubectl api-resources | grep -i -E 'httproute|^NAME'
h K12 hostname
grep -c . /tmp/m.txt
h K4 top mit tty
script -qec "timeout 8 linkerd viz -n emojivoto top deploy/web" /tmp/top.txt >/dev/null 2>&1
sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' /tmp/top.txt | tr -d '\r' | grep -E 'Source|web|vote' | tail -6 | cut -c1-120
h K10 cb nochmal, vor annotation policy
kubectl delete ns circuit-breaking-demo --ignore-not-found --wait=true | tail -1
kubectl apply -f labs/10-circuit-breaker/demo.yaml | tail -1
kubectl -n circuit-breaking-demo rollout status deploy/slow-cooker --timeout=180s | tail -1
kubectl -n circuit-breaking-demo rollout status deploy/bad --timeout=180s | tail -1
kubectl -n circuit-breaking-demo get deploy,pods -o wide | cut -c1-120
linkerd diagnostics policy -n circuit-breaking-demo svc/bb 8080 -o json | jq -c '.protocol.Kind.Detect.http1.failure_accrual, .protocol.Kind.Detect.http1.routes[0].rules[0].backends'
sleep 70
linkerd viz -n circuit-breaking-demo stat deploy
linkerd viz -n circuit-breaking-demo stat-outbound deploy/slow-cooker
kubectl -n circuit-breaking-demo logs deploy/slow-cooker -c slow-cooker --tail=4 | cut -c1-110
kubectl -n circuit-breaking-demo exec deploy/slow-cooker -c linkerd-proxy -- /bin/true 2>/dev/null
linkerd diagnostics proxy-metrics -n circuit-breaking-demo deploy/slow-cooker | grep -E '^outbound_http_balancer_endpoints|^outbound_http_route_request_statuses_total' | cut -c1-260 | head -6
linkerd diagnostics proxy-metrics -n circuit-breaking-demo deploy/bad | grep -E '^response_total.*direction="inbound"' | cut -c1-220 | head -6
kubectl -n circuit-breaking-demo logs deploy/bad -c bad --tail=3 2>&1 | cut -c1-140
h K9 retries ausgeruht + timeout code + serviceprofile
kubectl delete ns resilienz --ignore-not-found --wait=true | tail -1
kubectl apply -f labs/09-resilienz/demo.yaml | tail -1
kubectl -n resilienz rollout status deploy/flaky --timeout=180s | tail -1
kubectl -n resilienz rollout status deploy/slow --timeout=180s | tail -1
kubectl apply -f labs/09-resilienz/retry-route.yaml
sleep 150
linkerd viz -n resilienz stat-outbound deploy/last-flaky
sleep 60
linkerd viz -n resilienz stat-outbound deploy/last-flaky
kubectl apply -f labs/09-resilienz/timeout-route.yaml
sleep 8
kubectl -n resilienz run t1 --image=curlimages/curl:8.23.0 --annotations=linkerd.io/inject=enabled --command -- sleep 3600 >/dev/null
kubectl -n resilienz wait --for=condition=Ready pod/t1 --timeout=120s >/dev/null
sleep 4
for i in 1 2 3; do kubectl -n resilienz exec t1 -c t1 -- curl -s -o /dev/null -w '%{http_code} %{time_total}\n' http://slow:8080/; done
kubectl -n resilienz exec t1 -c t1 -- curl -si http://slow:8080/ | head -8
echo "--- ServiceProfile uebersteuert Retries?"
linkerd diagnostics policy -n resilienz svc/flaky 8080 -o json | jq -c '.protocol.Kind.Detect.http1.routes[]?.metadata' | head -3
cat <<SP | kubectl apply -f -
apiVersion: linkerd.io/v1alpha2
kind: ServiceProfile
metadata:
  name: flaky.resilienz.svc.cluster.local
  namespace: resilienz
spec:
  routes: []
SP
sleep 80
linkerd viz -n resilienz stat-outbound deploy/last-flaky
kubectl -n resilienz delete sp flaky.resilienz.svc.cluster.local
h K8 deny-policy prometheus
kubectl create ns dtest
kubectl -n dtest annotate ns dtest linkerd.io/inject=enabled config.linkerd.io/default-inbound-policy=deny
kubectl -n dtest create deploy nginx --image=nginx:alpine
kubectl -n dtest rollout status deploy/nginx --timeout=120s | tail -1
sleep 45
linkerd viz check --proxy -n dtest 2>&1 | grep -v '√' | head -14; echo "viz_check_rc=${PIPESTATUS[0]}"
linkerd viz -n dtest stat deploy
linkerd viz allow-scrapes --namespace dtest | kubectl apply -f - | tail -5
sleep 45
linkerd viz -n dtest stat deploy
linkerd viz check --proxy -n dtest 2>&1 | tail -3
kubectl delete ns dtest --wait=false
echo ENDE
