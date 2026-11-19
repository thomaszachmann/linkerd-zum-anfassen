# Linkerd zum Anfassen – Begleitcode

Begleitcode zum Buch **Linkerd zum Anfassen** – Service Mesh im echten Cluster: mTLS,
Traffic und Multicluster. Teil der Reihe IT-Trainingslager von Thomas Zachmann.

Buchseite: https://it-trainingslager.de/buecher/linkerd ·
English edition: https://itdrills.com/books/linkerd

Das Buch ist kostenlos, als Kurs im Browser sowie als PDF und EPUB.

## Inhalt

- `manifests/tagNN/` – die Manifeste und Values-Dateien so, wie sie im Labor für das
  jeweilige Kapitel liefen (Tag 0 bis 18), `manifests/pruefung/` für Anhang B.

Im Buch tippst du alles selbst – das ist das Training. Die Dateien hier helfen beim
Vergleichen, wenn etwas nicht so aussieht wie im Buch. Generierte Manifeste
(`linkerd install`, `linkerd viz install`) und Dateien mit privaten Schlüsseln oder
Zugangsdaten sind bewusst nicht enthalten.

Alle Passwörter und Schlüssel im Buch (z. B. `lab-db-123`, `lab-key-123`,
`lab-grafana-123`) sind Laborwerte – nie in Produktion verwenden.

Getestet mit Linkerd `edge-26.11.2` auf kubeadm/Kubernetes 1.37.2 mit Cilium 1.20.5
und k3s v1.37.2, amd64 (Befehle im Buch sind architekturneutral).

Die erste Fassung dieses Repos (kind-Labor, Stand 6. November 2026) liegt in der
Git-Historie.

## Hinweis

Linkerd ist ein CNCF-Projekt und eine Marke der Linux Foundation. Dieses Projekt ist
unabhängig und steht in keiner Verbindung zur Linux Foundation, zur CNCF oder zu
Anbietern von Linkerd-Distributionen.
