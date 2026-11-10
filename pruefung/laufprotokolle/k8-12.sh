#!/bin/bash
export PATH=/snap/bin:/usr/local/bin:$PATH
cd ~/buch
h(){ echo; echo "##### $*"; }
h K8 stat-inbound/outbound
linkerd viz -n emojivoto stat-inbound deploy/web
linkerd viz -n emojivoto stat-outbound deploy/web
h K8 viz check mit strengen Servern
linkerd viz check 2>&1 | grep -v '√' | head -8; linkerd viz check --proxy -n emojivoto 2>&1 | grep -v '√' | head -8
h K8 allow-scrapes
linkerd viz allow-scrapes --namespace emojivoto 2>&1 | grep -E '^kind:|^  name:|Error' | head -12
h K8 metriken
linkerd diagnostics proxy-metrics -n emojivoto deploy/web > /tmp/m.txt
for m in request_total response_total response_latency_ms inbound_http_authz_allow_total inbound_http_authz_deny_total outbound_http_route_request_statuses_total outbound_http_route_backend_requests_total outbound_http_balancer_endpoints identity_cert_expiration_timestamp_seconds; do printf "%s: " $m; grep -c "^$m" /tmp/m.txt; done
h K8 promql
kubectl -n linkerd-viz port-forward deploy/prometheus 19090:9090 >/dev/null 2>&1 & PF=$!
sleep 4
curl -s --get localhost:19090/api/v1/query --data-urlencode 'query=min(identity_cert_expiration_timestamp_seconds) - time()' | jq -c '.status,.data.result'
curl -s --get localhost:19090/api/v1/query --data-urlencode 'query=min(identity_cert_expiration_timestamp_seconds) - time() < 3600 * 6' | jq -c '.status,.data.result'
kill $PF
h K9 demo
kubectl apply -f labs/09-resilienz/demo.yaml
kubectl -n resilienz rollout status deploy/flaky --timeout=180s
kubectl -n resilienz get deploy
sleep 75
linkerd viz -n resilienz stat-outbound deploy/last-flaky
linkerd viz -n resilienz stat deploy
h K9 retry
kubectl apply -f labs/09-resilienz/retry-route.yaml
sleep 80
linkerd viz -n resilienz stat-outbound deploy/last-flaky
h K9 timeout
kubectl apply -f labs/09-resilienz/timeout-route.yaml
sleep 75
linkerd viz -n resilienz stat-outbound deploy/last-slow
kubectl -n resilienz logs deploy/last-slow -c slow-cooker --tail=6 2>&1 | cut -c1-140
timeout 6 linkerd viz -n resilienz tap deploy/last-slow 2>&1 | grep -E '^(rsp|end)' | head -5
h K9 timeout 2s
kubectl -n resilienz annotate --overwrite httproutes.gateway.networking.k8s.io slow-timeout timeout.linkerd.io/request=2s
sleep 75
linkerd viz -n resilienz stat-outbound deploy/last-slow
h K9 httproute mehrdeutig
kubectl -n resilienz get httproute 2>&1 | head -4
h K10 cb demo
kubectl apply -f labs/10-circuit-breaker/demo.yaml
kubectl -n circuit-breaking-demo rollout status deploy/slow-cooker --timeout=180s
sleep 70
linkerd viz -n circuit-breaking-demo stat deploy
linkerd viz -n circuit-breaking-demo stat deploy/slow-cooker --to svc/bb
h K10 cb an
kubectl annotate -n circuit-breaking-demo svc/bb balancer.linkerd.io/failure-accrual=consecutive
linkerd diagnostics policy -n circuit-breaking-demo svc/bb 8080 -o json | jq '.protocol.Kind.Detect.http1.failure_accrual'
sleep 75
linkerd viz -n circuit-breaking-demo stat deploy
linkerd viz -n circuit-breaking-demo stat deploy/slow-cooker --to svc/bb
h K10 rate limit
kubectl delete --ignore-not-found -f labs/06-autorisierung/ | tail -9
kubectl -n emojivoto scale --replicas 0 deploy/vote-bot
kubectl apply -f labs/10-rate-limit/server-und-limit.yaml
sleep 8
for r in 1 2 3 4 5; do
kubectl -n emojivoto exec deploy/lab-client -c curl -- sh -c '
  for i in $(seq 10); do
    curl -s -o /dev/null -w "%{http_code} " http://web-svc.emojivoto/ &
  done
  wait; echo'
sleep 2; done
kubectl delete -f labs/10-rate-limit/server-und-limit.yaml
kubectl -n emojivoto scale --replicas 1 deploy/vote-bot
sleep 10
h K5-nachtrag ungemesht ohne policy im tap
(timeout 20 linkerd viz -n emojivoto tap deploy/web 2>&1 | grep -v 'tls=true' | head -4) &
sleep 4
kubectl run ungemesht3 --rm -i --image=curlimages/curl:8.23.0 --restart=Never -- curl -s -o /dev/null -w '%{http_code}\n' http://web-svc.emojivoto/
wait
h K5-nachtrag tshark 4143 vs 8080
kubectl -n emojivoto get deploy voting -o yaml | linkerd inject --enable-debug-sidecar - | kubectl apply -f - | tail -1
kubectl -n emojivoto rollout status deploy/voting --timeout=120s
sleep 6
echo "--- buch-kommando ueber deploy/voting:"
kubectl -n emojivoto exec deploy/voting -c linkerd-debug -- timeout 12 tshark -i any -d tcp.port==8080,ssl 2>/dev/null | grep -v 127.0.0.1 | awk '{print $6,$7,$8,$9}' | sort | uniq -c | sort -rn | head -8
echo "--- ports:"
kubectl -n emojivoto exec deploy/voting -c linkerd-debug -- timeout 12 tshark -i any -T fields -e ip.src -e ip.dst -e tcp.dstport -e _ws.col.Protocol 2>/dev/null | sort | uniq -c | sort -rn | head -10
echo "--- klartext 4143 (fremdverkehr):"
kubectl -n emojivoto exec deploy/voting -c linkerd-debug -- timeout 12 tshark -i any -f 'tcp port 4143' -x 2>/dev/null | grep -c -E 'Vote|emojivoto'
echo "--- klartext 8080 (loopback proxy-app):"
kubectl -n emojivoto exec deploy/voting -c linkerd-debug -- timeout 12 tshark -i any -f 'tcp port 8080' -x 2>/dev/null | grep -c -E 'Vote|voting|emojivoto'
kubectl -n emojivoto exec deploy/voting -c linkerd-debug -- timeout 12 tshark -i any -f 'tcp port 8080' -d tcp.port==8080,http2 -T fields -e http2.headers.path 2>/dev/null | grep -v '^$' | head -3
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/emojivoto.yml | linkerd inject - | kubectl apply -f - | tail -1
h K11 demo
kubectl apply -f labs/11-traffic/demo.yaml
kubectl -n traffic-shift-demo rollout status deploy/slow-cooker --timeout=180s
sleep 60
linkerd viz -n traffic-shift-demo stat --from deploy/slow-cooker deploy
h K11 90-10
kubectl apply -f labs/11-traffic/route-90-10.yaml
sleep 75
linkerd viz -n traffic-shift-demo stat --from deploy/slow-cooker deploy
h K11 100
kubectl apply -f labs/11-traffic/route-100.yaml
sleep 70
linkerd viz -n traffic-shift-demo stat --from deploy/slow-cooker deploy
h K11 header
kubectl apply -f labs/11-traffic/route-header.yaml
kubectl -n traffic-shift-demo run tester --image=curlimages/curl:8.23.0 --annotations=linkerd.io/inject=enabled --command -- sleep 3600
kubectl -n traffic-shift-demo wait --for=condition=Ready pod/tester --timeout=120s
sleep 5
for i in 1 2 3; do kubectl -n traffic-shift-demo exec tester -c tester -- curl -s http://bb:8080 ; echo; done
for i in 1 2 3; do kubectl -n traffic-shift-demo exec tester -c tester -- curl -s -H 'x-canary: true' http://bb:8080; echo; done
h K11 cleanup
kubectl delete -f labs/11-traffic/demo.yaml | tail -1
kubectl delete -f labs/10-circuit-breaker/demo.yaml | tail -1
kubectl delete -f labs/09-resilienz/demo.yaml | tail -1
h K12 egress
kubectl apply -f labs/12-egress/egress-allow.yaml
kubectl -n egress-test wait --for=condition=Ready pod/client --timeout=120s
sw(){ for i in 1 2 3 4 5; do kubectl -n egress-test exec client -c client -- curl -s -m 8 -o /dev/null -w "%{http_code} " "http://httpbin.org$1"; done; echo; }
echo -n "allow /get: "; sw /get
linkerd dg proxy-metrics -n egress-test po/client | grep outbound_http_route_request_statuses_total | head -3 | cut -c1-420
h K12 deny
kubectl patch egressnetwork -n egress-test all-egress-traffic -p '{"spec":{"trafficPolicy": "Deny"}}' --type=merge
sleep 12
echo -n "deny /get: "; sw /get
linkerd dg proxy-metrics -n egress-test po/client | grep outbound_http_route_request_statuses_total | grep -o 'route_name="[^"]*"' | sort | uniq -c
h K12 route frei
kubectl apply -f labs/12-egress/httpbin-get.yaml
sleep 12
echo -n "/get: "; sw /get
echo -n "/headers: "; sw /headers
h K12 tls
echo -n "tls vorher: "; kubectl -n egress-test exec client -c client -- curl -s -m 10 -o /dev/null -w '%{http_code}\n' https://httpbin.org/get; echo "rc=$?"
kubectl apply -f labs/12-egress/tls-egress.yaml
sleep 12
kubectl -n egress-test exec client -c client -- curl -s -m 10 -o /dev/null -w '%{http_code}\n' https://httpbin.org/get; echo "rc=$?"
kubectl -n egress-test get tlsroute.gateway.networking.k8s.io -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.parents[*].conditions[*].type}={.status.parents[*].conditions[*].status}{"\n"}{end}'
h K12 cleanup
kubectl delete -f labs/12-egress/egress-allow.yaml | tail -2
echo ENDE
