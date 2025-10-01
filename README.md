# Cluster Message Board Lab

This Vagrant project spins up a tiny Kubernetes cluster and deploys a three-tier "message board" application. It is designed as an approachable sandbox for anyone who wants to see how ingress, services, probes, ConfigMaps, Secrets, and a stateful workload fit together.

## What Gets Deployed

When you run `vagrant up` the provisioning scripts install Kubernetes (via kubeadm) and create four virtual machines:

| VM | Role | Notes |
| --- | --- | --- |
| `k8s-master` | Control plane | Hosts the API server and bootstrap scripts |
| `k8s-frontend` | Worker | Runs the nginx frontend pods |
| `k8s-backend` | Worker | Runs the Python/Flask API pods |
| `k8s-database` | Worker | Runs the MySQL database pod |

The app itself consists of:

- **Frontend** – static HTML/JS served by nginx. Lives in namespace `frontend`.
- **Backend API** – Flask service that timestamps messages and stores them in MySQL. Namespace `backend`.
- **MySQL** – single-instance database that keeps the messages. Namespace `database`.
- **Ingress** – nginx ingress controller exposed on NodePort `30080` with host-based routes:
  - `frontend.192.168.57.11.nip.io`
  - `backend.192.168.57.11.nip.io`
  - `public.192.168.57.11.nip.io`

`nip.io` automatically resolves those hostnames to `192.168.57.11`, letting you reach the cluster from the host machine without editing `/etc/hosts`.

## Repository Layout

```
apps/
  frontend/index.html     # UI and form logic
  backend/app.py          # Flask API that talks to MySQL
  backend/requirements.txt
app-configmaps.yaml       # Packages the HTML and Python source into ConfigMaps
backend-secret.yaml       # Stores DB credentials for the API pods
node-affinity-deployments.yaml
                         # Deployments for frontend, backend, database (pinned to specific nodes)
database/mysql-service.yaml
                         # ClusterIP service exposing MySQL to other namespaces
ingress/services.yaml     # Frontend and backend services targeted by ingress rules
ingress/ingress-routes.yaml
                         # Host-based ingress definitions
scripts/setup-master.sh   # kubeadm init + cluster bootstrap automation
scripts/post-setup.sh     # Waits for ingress and applies routes once workers join
README.md                 # This guide
```

## Using The Lab

1. **Bring the cluster up**
   ```bash
   cd ~/general-adam/OSC/kubernetes_certification/local-cloud-sim/vagrant-test/exam_prep/cka
   vagrant up
   ```
   The first run may take several minutes while images download.

2. **Point kubectl at the generated kubeconfig**
   ```bash
   export KUBECONFIG=$PWD/kubeconfig
   kubectl get nodes
   ```
   You should see `k8s-master`, `k8s-frontend`, `k8s-backend`, and `k8s-database` in `Ready` state.

3. **Explore the application**
   - Browser UI: `http://frontend.192.168.57.11.nip.io:30080/`
   - Backend API: `curl -H 'Host: backend.192.168.57.11.nip.io' http://192.168.57.11:30080/entries`
   - Submit a message: `curl -H 'Host: backend.192.168.57.11.nip.io' -H 'Content-Type: application/json' -X POST -d '{"message":"hello"}' http://192.168.57.11:30080/entries`
   - Check the database: `kubectl exec -n database deploy/database-server -- mysql -uroot -ppassword123 -e "SELECT submitted_at,message FROM messages ORDER BY submitted_at DESC LIMIT 10;"`

4. **Tear down**
   ```bash
   vagrant destroy -f
   ```

## How The Pieces Talk

1. The frontend page calls the backend API hosted at `backend.192.168.57.11.nip.io`.
2. Ingress-nginx receives the request on NodePort `30080`, matches the host name, and forwards traffic to the `backend-svc` service in the `backend` namespace.
3. `backend-svc` load-balances across the Flask pods. Each pod installs its Python dependencies on startup (via ConfigMap) and exposes `/entries`, `/readyz`, and `/healthz` endpoints.
4. The Flask code connects to MySQL using the service DNS name `mysql.database.svc.cluster.local`, stores the message with a UTC timestamp, and returns the ten newest entries.
5. The frontend refreshes its list and renders the messages on screen.

## Why This Project Helps Beginners

- Demonstrates ingress, services, ConfigMaps, Secrets, probes, and stateful workloads with minimal complexity.
- Everything is reproducible with `vagrant up`—no manual kubectl choreography required.
- The source code is mounted from ConfigMaps, making it easy to experiment without building images.
- Readiness/liveness probes and namespace separation mirror real-world best practices.

Feel free to modify the HTML or backend Python in `apps/` and rerun `kubectl apply -f app-configmaps.yaml` plus `kubectl rollout restart deploy/backend-api -n backend` to see changes live.
