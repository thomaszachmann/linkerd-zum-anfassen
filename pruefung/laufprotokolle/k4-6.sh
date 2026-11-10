#!/bin/bash
# Spielt Kapitel 4-6 unveraendert nach. Bricht bewusst nicht ab.
export PATH=/snap/bin:/usr/local/bin:$PATH
cd ~/buch
h(){ echo; echo "##### $*"; }
h K4 emojivoto ohne mesh
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/emojivoto.yml | kubectl apply -f - | tail -3
kubectl -n emojivoto rollout status deploy/web --timeout=180s
h K4 inject
kubectl get -n emojivoto deploy -o yaml | linkerd inject - | kubectl apply -f -
for d in web emoji voting vote-bot; do kubectl -n emojivoto rollout status deploy/$d --timeout=180s; done
linkerd check -n emojivoto --proxy -o short; echo "proxy_check_exit=$?"
kubectl -n emojivoto get pod -l app=web-svc -o jsonpath='{.items[0].spec.initContainers[*].name}'; echo
kubectl -n emojivoto get pod -o wide | head -8
sleep 60
h K4 stat
linkerd viz -n emojivoto stat deploy
h K4 top
timeout 20 linkerd viz -n emojivoto top deploy/web </dev/null 2>&1 | tail -12
h K4 tap
timeout 10 linkerd viz -n emojivoto tap deploy/web 2>&1 | head -6
h K5 edges
linkerd viz -n emojivoto edges deployment
h K5 tap voting
timeout 10 linkerd viz -n emojivoto tap deploy/voting 2>&1 | head -8
timeout 15 linkerd viz -n emojivoto tap deploy/voting 2>&1 | grep -o 'tls=[a-z_]*' | sort | uniq -c
h K5 debug sidecar
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/emojivoto.yml | linkerd inject --enable-debug-sidecar - | kubectl apply -f - | tail -2
kubectl -n emojivoto rollout status deploy/voting --timeout=180s
P=$(kubectl -n emojivoto get po -o name | grep voting)
echo "pod=$P"
kubectl -n emojivoto exec $P -c linkerd-debug -- timeout 15 tshark -i any -d tcp.port==8080,ssl 2>&1 | grep -v 127.0.0.1 | tail -12
echo "--- klartext-suche:"; kubectl -n emojivoto exec $P -c linkerd-debug -- timeout 15 tshark -i any -Y 'tcp.port==8080' -T fields -e data.text -o data.show_as_text:TRUE 2>/dev/null | grep -c -i vote
h K5 rueckbau debug
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/emojivoto.yml | linkerd inject - | kubectl apply -f - | tail -2
kubectl -n emojivoto rollout status deploy/voting --timeout=180s
kubectl -n emojivoto get po -o jsonpath='{range .items[*]}{.metadata.name}{" "}{range .spec.containers[*]}{.name}{","}{end}{"\n"}{end}'
h K5 ungemesht
kubectl run ungemesht --rm -i --image=curlimages/curl:8.23.0 --restart=Never -- curl -s -o /dev/null -w '%{http_code}\n' http://web-svc.emojivoto/
h K6 client
kubectl apply -f labs/00-cluster/lab-client.yaml
kubectl -n emojivoto rollout status deploy/lab-client --timeout=180s
h K6 s1 audit
kubectl apply -f labs/06-autorisierung/01-server-audit.yaml
sleep 30
linkerd viz authz -n emojivoto deploy/voting
kubectl -n emojivoto logs deploy/voting -c linkerd-proxy --tail=200 | grep -c 'authz.name=audit'
h K6 s2 regeln
kubectl apply -f labs/06-autorisierung/02-voting-erlauben.yaml
sleep 45
linkerd viz authz -n emojivoto deploy/voting
h K6 s3 erzwingen
kubectl apply -f labs/06-autorisierung/03-server-erzwingen.yaml
sleep 10
kubectl -n emojivoto exec deploy/lab-client -c curl -- curl -sv --http2-prior-knowledge -X POST -H 'content-type: application/grpc' http://voting-svc.emojivoto:8080/emojivoto.v1.VotingService/VoteDog 2>&1 | grep -i -E 'grpc-status|HTTP/2|< '
echo "--- app laeuft weiter?"; sleep 30; linkerd viz -n emojivoto stat deploy
h K6 route
kubectl apply -f labs/06-autorisierung/04-web-pro-route.yaml
sleep 10
web() { kubectl -n emojivoto exec deploy/lab-client -c curl -- curl -s -o /dev/null -w '%{http_code}\n' "http://web-svc.emojivoto$1"; }
echo -n "/api/list: "; web /api/list
echo -n "/api/vote: "; web '/api/vote?choice=:cat:'
echo -n "/: "; web /
echo -n "/nope: "; web /nope
linkerd viz stat -n emojivoto deploy 2>&1 | tail -7
kubectl -n emojivoto exec deploy/web -c linkerd-proxy -- /bin/true 2>&1 | head -1
linkerd diagnostics proxy-metrics -n emojivoto deploy/web 2>/dev/null | grep -E 'inbound_http_route_not_found_total' | head -5
echo; echo ENDE
