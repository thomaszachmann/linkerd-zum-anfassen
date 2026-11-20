# Linkerd hands-on – Companion Code

Companion code for the book **Linkerd hands-on** (German edition: *Linkerd zum Anfassen*) – a
service mesh on a real cluster: mTLS, traffic and multicluster. Part of Thomas Zachmann's IT
Drills series.

Book page: https://it-trainingslager.de/buecher/linkerd ·
English edition: https://itdrills.com/books/linkerd

The book is free, as a course in the browser and as PDF and EPUB.

## Contents

- `manifests/tagNN/` – the manifests and values files exactly as they ran in the lab for the
  respective chapter (Day 0 to 18), `manifests/pruefung/` for Appendix B.

In the book you type everything yourself – that is the training. The files here help you
compare when something doesn't look the way it does in the book. Generated manifests
(`linkerd install`, `linkerd viz install`) and files with private keys or
credentials are deliberately not included.

All passwords and keys in the book (e.g. `lab-db-123`, `lab-key-123`,
`lab-grafana-123`) are lab values – never use them in production.

Tested with Linkerd `edge-26.11.2` on kubeadm/Kubernetes 1.37.2 with Cilium 1.20.5
and k3s v1.37.2, amd64 (the commands in the book are architecture-neutral).

The first version of this repo (kind lab, as of 6 November 2026) is in the
Git history.

## Disclaimer

Linkerd is a CNCF project and a trademark of the Linux Foundation. This project is
independent and not affiliated with the Linux Foundation, the CNCF or
vendors of Linkerd distributions.
