# Portfolio Microservices on Kubernetes — Full Setup Documentation

This documents the complete build-out of [syedasif27.online](https://www.syedasif27.online) as a GitOps-managed microservices deployment — first prototyped on a self-hosted kubeadm cluster, then migrated to GKE with a real load balancer and TLS.

Repo: `github.com/syedasif27/argo-k8s`

---

## 1. Architecture

Two independently deployable services behind a single Ingress:

```
                    Internet
                        │
              https://k8s.syedasif27.online
                        │
              ┌─────────▼─────────┐
              │  ingress-nginx      │
              │  (TLS via cert-mgr) │
              └─────────┬───────────┘
                        │
          ┌─────────────┴─────────────┐
          │                           │
     path: /                    path: /api/*
          │                           │
┌─────────▼─────────┐      ┌─────────▼──────────┐
│  portfolio-web      │      │  portfolio-api       │
│  nginx : static site │      │  Node/Express         │
│  2 replicas          │      │  2 replicas            │
└──────────────────────┘      └───────────┬────────────┘
                                            │
                                 GMAIL_USER / GMAIL_PASS
                                 (k8s Secret, not in git)
                                            │
                                    Gmail SMTP (nodemailer)
```

| Service | Role | Base image | Routes |
|---|---|---|---|
| `portfolio-web` | Static portfolio site | `nginx:1.27-alpine` | `/` |
| `portfolio-api` | Contact form → email relay | `node:20-alpine` | `/api/contact`, `/healthz` |

---

## 2. Repo layout

```
argo-k8s/
├── api/                          # portfolio-api source
│   ├── contact.js                # mail-sending logic (Vercel-style handler)
│   ├── server.js                 # Express wrapper — exposes /api/contact, /healthz
│   ├── package.json
│   └── Dockerfile
├── web/                          # portfolio-web source
│   ├── index.html
│   ├── favicon.ico / favicon.png / syedasif.jpg
│   ├── nginx.conf
│   └── Dockerfile
├── portfolio/                    # k8s manifests — this is what ArgoCD syncs
│   ├── 00-namespace.yaml
│   ├── ingress.yaml
│   ├── cert-issuer.yaml          # cert-manager ClusterIssuer (GKE only)
│   ├── api/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── secret.yaml           # TEMPLATE ONLY — real values never committed
│   └── web/
│       ├── deployment.yaml
│       └── service.yaml
└── argocd/
    └── portfolio-app.yaml        # ArgoCD Application definition
```

---

## 3. Application code

### `api/contact.js` (unchanged from original Vercel-style handler)
Handles `POST` requests, validates fields, sends mail via `nodemailer` using Gmail SMTP with credentials from environment variables.

### `api/server.js` (new — makes it run as a standalone server instead of a serverless function)
```js
const express = require('express');
const cors = require('cors');
const contactHandler = require('./contact');

const app = express();
app.use(cors());
app.use(express.json());

app.get('/healthz', (req, res) => res.status(200).json({ ok: true }));
app.post('/api/contact', contactHandler);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`portfolio-api listening on ${PORT}`));
```

### `api/package.json`
```json
{
  "name": "portfolio-api",
  "version": "1.0.0",
  "private": true,
  "main": "server.js",
  "scripts": { "start": "node server.js" },
  "dependencies": {
    "express": "^4.19.2",
    "cors": "^2.8.5",
    "nodemailer": "^6.9.13"
  }
}
```

### `api/Dockerfile`
```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev
COPY . .
EXPOSE 3000
USER node
CMD ["node", "server.js"]
```

### `web/Dockerfile`
```dockerfile
FROM nginx:1.27-alpine
RUN rm -rf /usr/share/nginx/html/*
COPY index.html /usr/share/nginx/html/
COPY favicon.ico /usr/share/nginx/html/
COPY favicon.png /usr/share/nginx/html/
COPY syedasif.jpg /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
```

### `web/nginx.conf`
```nginx
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
    location = /healthz {
        return 200 'ok';
        add_header Content-Type text/plain;
    }

    gzip on;
    gzip_types text/css application/javascript image/svg+xml;
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
}
```

**Build & push both images manually (before CI exists):**
```bash
cd api && docker build -t syedasif27/portfolio-api:v1 . && docker push syedasif27/portfolio-api:v1
cd ../web && docker build -t syedasif27/portfolio-web:v1 . && docker push syedasif27/portfolio-web:v1
```

---

## 4. Kubernetes manifests

### `portfolio/00-namespace.yaml`
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: portfolio
  labels:
    app.kubernetes.io/part-of: portfolio-app
```

### `portfolio/api/deployment.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: portfolio-api
  namespace: portfolio
  labels:
    app: portfolio-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: portfolio-api
  template:
    metadata:
      labels:
        app: portfolio-api
    spec:
      containers:
        - name: portfolio-api
          image: docker.io/syedasif27/portfolio-api:v1
          ports:
            - containerPort: 3000
          envFrom:
            - secretRef:
                name: portfolio-api-secret
          resources:
            requests: { cpu: 50m, memory: 64Mi }
            limits: { cpu: 200m, memory: 128Mi }
          readinessProbe:
            httpGet: { path: /healthz, port: 3000 }
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet: { path: /healthz, port: 3000 }
            initialDelaySeconds: 10
            periodSeconds: 20
```

### `portfolio/api/service.yaml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: portfolio-api
  namespace: portfolio
spec:
  selector:
    app: portfolio-api
  ports:
    - port: 80
      targetPort: 3000
  type: ClusterIP
```

### `portfolio/api/secret.yaml` (template only — placeholder values, safe for a public repo)
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: portfolio-api-secret
  namespace: portfolio
type: Opaque
stringData:
  GMAIL_USER: "your-gmail-address@gmail.com"
  GMAIL_PASS: "your-gmail-app-password"
```
Real secret is applied manually (never committed):
```bash
kubectl create secret generic portfolio-api-secret \
  -n portfolio \
  --from-literal=GMAIL_USER='<real-gmail>' \
  --from-literal=GMAIL_PASS='<real-app-password>'
```

### `portfolio/web/deployment.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: portfolio-web
  namespace: portfolio
  labels:
    app: portfolio-web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: portfolio-web
  template:
    metadata:
      labels:
        app: portfolio-web
    spec:
      containers:
        - name: portfolio-web
          image: docker.io/syedasif27/portfolio-web:v1
          ports:
            - containerPort: 80
          resources:
            requests: { cpu: 25m, memory: 32Mi }
            limits: { cpu: 100m, memory: 64Mi }
          readinessProbe:
            httpGet: { path: /healthz, port: 80 }
            initialDelaySeconds: 3
            periodSeconds: 10
          livenessProbe:
            httpGet: { path: /healthz, port: 80 }
            initialDelaySeconds: 5
            periodSeconds: 20
```

### `portfolio/web/service.yaml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: portfolio-web
  namespace: portfolio
spec:
  selector:
    app: portfolio-web
  ports:
    - port: 80
      targetPort: 80
  type: ClusterIP
```

### `portfolio/cert-issuer.yaml` (GKE only — cert-manager ClusterIssuer)
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
      - http01:
          ingress:
            ingressClassName: nginx
```

### `portfolio/ingress.yaml` (GKE version, with TLS)
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: portfolio-ingress
  namespace: portfolio
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - k8s.syedasif27.online
      secretName: portfolio-tls
  rules:
    - host: k8s.syedasif27.online
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: portfolio-api
                port: { number: 80 }
          - path: /
            pathType: Prefix
            backend:
              service:
                name: portfolio-web
                port: { number: 80 }
```

> **Bare-metal (VirtualBox/kubeadm) version** of this file used `host: portfolio.local`, no `tls:` block, and a `rewrite-target` annotation instead — swap back if reusing on a NodePort-only cluster.

### `argocd/portfolio-app.yaml`
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: portfolio
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/syedasif27/argo-k8s.git
    targetRevision: main
    path: portfolio
    directory:
      recurse: true          # REQUIRED — without this, ArgoCD ignores subfolders like portfolio/api/
  destination:
    server: https://kubernetes.default.svc
    namespace: portfolio
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

---

## 5. GitOps flow

ArgoCD never reads from a laptop or the cluster's local disk — only from the git repo.

1. Edit a manifest or app code → rebuild/push image if needed → commit → `git push`
2. ArgoCD polls the repo (~3 min default, or manual Refresh) and diffs git vs. cluster state
3. ArgoCD applies the diff — `prune: true` + `selfHeal: true` means drift is corrected and removed resources are pruned automatically
4. `directory.recurse: true` ensures nested manifests are picked up

The **only** manual `kubectl apply` in the whole workflow is the one-time bootstrap:
```bash
kubectl apply -f argocd/portfolio-app.yaml
```
Everything after that is git push → auto-sync.

---

## 6. Environment history — two clusters

### A) Bare-metal kubeadm on VirtualBox (initial prototype)
- 1 control-plane (`cplane`) + 2 workers, Flannel CNI
- `ingress-nginx` exposed as `NodePort` (no cloud LB available)
- VirtualBox **NAT Network** meant the host machine couldn't reach VM IPs directly — required a port-forward rule (host `127.0.0.1:<nodePort>` → VM `<nodePort>`) plus `/etc/hosts` entry: `127.0.0.1 portfolio.local`
- No TLS — HTTP only, local testing

### B) GKE (`portfolio-cluster`, asia-south1-a) — production-style setup
```bash
gcloud container clusters create portfolio-cluster \
  --zone asia-south1-a --machine-type e2-medium \
  --num-nodes 2 --disk-size=30G --release-channel=regular \
  --enable-ip-alias

gcloud container clusters get-credentials portfolio-cluster --zone asia-south1-a
```
- ArgoCD installed fresh:
  ```bash
  kubectl create namespace argocd
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  ```
- `ingress-nginx` installed via cloud provider manifest (gets a real `LoadBalancer` external IP, no NodePort workaround needed):
  ```bash
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.2/deploy/static/provider/cloud/deploy.yaml
  ```
- DNS: A record `k8s.syedasif27.online` → ingress-nginx external IP
- `cert-manager` installed:
  ```bash
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.3/cert-manager.yaml
  ```
- `ClusterIssuer` (Let's Encrypt prod) + `Ingress` TLS block → cert issued automatically via HTTP-01 challenge
- Secret recreated manually on the new cluster (secrets don't migrate between clusters)

---

## 7. Testing

```bash
# Bare-metal (HTTP, NodePort)
curl http://portfolio.local:<nodePort>/healthz

# GKE (HTTPS)
curl https://k8s.syedasif27.online/healthz
curl -X POST https://k8s.syedasif27.online/api/contact \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","email":"test@test.com","subject":"Hi","message":"Hello"}'
```
Or open the URL directly in a browser to confirm the full site + contact form.

---

## 8. Incidents & fixes encountered

| Issue | Cause | Fix |
|---|---|---|
| ArgoCD synced only top-level files (namespace, ingress) — `api`/`web` deployments never appeared | `directory.recurse` not set on Application; ArgoCD doesn't recurse subfolders by default | Added `directory: { recurse: true }` to `portfolio-app.yaml` |
| `portfolio-api` pods stuck `CreateContainerConfigError` | `portfolio-api-secret` missing — likely lost on a namespace recreate | Recreated secret manually with `kubectl create secret` |
| `git push -f` wiped manifests from the remote | Force-pushed over unmerged remote commits instead of pulling/merging first | Recovered from local working directory (files still existed uncommitted locally); going forward: always `git pull` before push, never `-f` unless certain |
| VirtualBox NAT Network — host couldn't reach VM/NodePort | NAT Network isolates VMs from host by default | Added a port-forward rule in VirtualBox network settings (or use Host-Only adapter as a cleaner long-term fix) |

---

## 9. Roadmap

- [ ] GitHub Actions CI: build + push `portfolio-api` / `portfolio-web` images to Docker Hub on push to `main`, with automated tag bumping (or Argo Image Updater) so ArgoCD picks up new versions without manual manifest edits
- [ ] Sealed Secrets (bitnami-labs) — move `portfolio-api-secret` into GitOps-managed, encrypted form instead of the manual `kubectl create secret` step
- [ ] Move `argo-k8s` repo back to private once CI has its own scoped git credentials (PAT or SSH deploy key)
- [ ] HorizontalPodAutoscaler for `portfolio-api` if contact-form traffic ever spikes
- [ ] Argo CD `sync-waves` if resource ordering ever becomes an issue (e.g. ClusterIssuer before Ingress)
