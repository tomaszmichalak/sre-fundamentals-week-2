# Week 2 Project

I decided to use the `kind` tool to create a Kubernetes cluster and deploy the `canary-demo` application. It allows me to test the week 2 project in a local environment and in CI (GitHub Actions).

## Requirements
- Install `Docker Desktop`
- Install `kubectl`
- Install `Helm`
- Install `kind`

## Local Development

To start the local development environment, run the following command:

```bash
cd scripts
./start.sh
```

This script will create a Kubernetes cluster using `kind`, deploy the Ingress Controller, Prometheus Monitoring Stack, and the `canary-demo` application.

To stop the local development environment, run the following command:

```bash
cd scripts
./stop.sh
```

This script will delete the Kubernetes cluster.

## Manual Steps

### Build the image

Build the image for the `canary-demo` application (change the tag to `v2` for the second image):
```bash
docker build -t tmichalak/canary-demo:v1 -f canary-demo/Dockerfile canary-demo
docker build -t tmichalak/canary-demo:v2 -f canary-demo/Dockerfile canary-demo
```

### Run Kubernetes cluster

Create a Kubernetes cluster using `kind`:
```bash
kind create cluster --config .github/kind.yaml
```

Check the cluster is running and your `kubectl` is pointing to the right cluster:

```bash
kubectl cluster-info
kubectl get nodes
```

### Deploy Ingress Controller

Deploy the Ingress Controller using the following command:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl -n ingress-nginx rollout status deployment ingress-nginx-controller
```

Ingress is available at `localhost:80`, `localhost:443`. These ports are configured in the `.github/kind.yaml` file.

### Deploy the Prometheus Monitoring Stack

Deploy the Prometheus Monitoring Stack using the following command:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack -f ./prometheus/values.yaml -n monitoring --create-namespace
```

Please note that I install the Prometheus Monitoring Stack in the `monitoring` namespace so I need to configure scanning all namespaces in the Prometheus configuration (`./prometheus/values.yaml`).

### Deploy the application

```bash
kind load docker-image tmichalak/canary-demo:v1
kind load docker-image tmichalak/canary-demo:v2
helm install canary-demo ./canary-demo/canary-demo -n canary-demo --create-namespace
```

### Test the application

```bash
curl http://canary-demo-127-0-0-1.nip.io/

for i in {1..20}; do curl -H "Host: canary-demo-127-0-0-1.nip.io" canary-demo-127-0-0-1.nip.io; done

pip3 install requests
python3 ./canary-demo/tests/test_app.py
```

### Check Metrics

```bash
kubectl port-forward svc/canary-demo 8080:80 -n canary-demo & kubectl port-forward svc/canary-demo-canary 8081:80 -n canary-demo & kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring & kubectl port-forward svc/prometheus-operated 9090:9090 -n monitoring &
```

Login to Grafana with `localhost:3000` using the following credentials: `admin` /`prom-operator`.
