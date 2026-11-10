# Linkerd zum Anfassen – Begleitcode

Begleitcode zum Buch **Linkerd zum Anfassen** – Service Mesh in der Praxis: vom ersten Sidecar bis zum Betrieb. Teil der Reihe IT-Trainingslager von Thomas Zachmann.

Das Buch ist kostenlos als PDF und EPUB:

- Buchseite: https://it-trainingslager.de/buecher/linkerd
- Hands-On-Reihe: https://nyrvex.de/hands-on

Der Code begleitet das Buch; Erklärungen und Übungen stehen im Buch.

## Inhalt

- `labs/00-cluster/` – kind-Cluster mit gepinntem Node-Image (Kubernetes 1.35.8) und gemeshter Test-Client (Kapitel 2, 6)
- `labs/06-autorisierung/` – Server, MeshTLSAuthentication, AuthorizationPolicy, Autorisierung pro Route (Kapitel 6)
- `labs/09-resilienz/` – Retries und Timeouts mit absichtlich schlechten Backends (Kapitel 9)
- `labs/10-circuit-breaker/` – ein gesunder und ein kaputter Pod hinter einem Service (Kapitel 10)
- `labs/10-rate-limit/` – HTTPLocalRateLimitPolicy (Kapitel 10)
- `labs/11-traffic/` – Traffic Shifting 90/10, 100 Prozent und per Header (Kapitel 11)
- `labs/12-egress/` – EgressNetwork, HTTPRoute und TLSRoute für ausgehenden Verkehr (Kapitel 12)
- `pruefung/` – Schemaprüfung der Manifeste (`pruefe-labs.rb`) und die Laufprotokolle des Prüfstands (Anhang B)

## Schnellstart

```bash
git clone https://github.com/thomaszachmann/linkerd-zum-anfassen.git
cd linkerd-zum-anfassen
kind create cluster --config labs/00-cluster/kind-config.yaml
```

Alle Befehle im Buch gehen davon aus, dass du in diesem Ordner stehst. Details stehen in Kapitel 2.

## Versionen

Linkerd `edge-26.11.1` (Linie 2.20), Kubernetes 1.35, Gateway API 1.5.1 (Standard-Kanal), kind 0.33. Die Labs liefen am 6. November 2026 in kind-Clustern; was offen ist, steht in Anhang B des Buchs.

## Lizenz

Code: MIT (siehe LICENSE). Das Buch selbst ist kostenlos unter CC BY-ND 4.0 und nicht Teil dieses Repos.
