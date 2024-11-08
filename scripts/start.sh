#!/usr/bin/env bash
HOME=$(pwd)

docker build -t tmichalak/canary-demo:v1 -f canary-demo/Dockerfile canary-demo
docker build -t tmichalak/canary-demo:v2 -f canary-demo/Dockerfile canary-demo
docker build -t tmichalak/canary-demo:v3 -f canary-demo/Dockerfile canary-demo

kind create cluster --config="$HOME"/.github/kind.yaml
kind load docker-image tmichalak/canary-demo:v1
kind load docker-image tmichalak/canary-demo:v2
kind load docker-image tmichalak/canary-demo:v3

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl -n ingress-nginx rollout status deployment ingress-nginx-controller

kubectl create ns monitoring
kubectl create configmap upcommerce-grafana-dashboard --from-file=prometheus/dashboards/upcommerce.json -n monitoring --dry-run=client -o json | jq '.metadata += {"labels":{"grafana_dashboard":"1"}}' | kubectl apply -f -

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack -f ./prometheus/values.yaml -n monitoring
kubectl -n monitoring rollout status deployment prometheus-kube-prometheus-stack-prometheus

kubectl create ns canary-demo
helm install canary-demo ./canary-demo/canary-demo -n canary-demo
kubectl -n canary-demo rollout status deployment canary-demo

sleep 5

URL=http://canary-demo-127-0-0-1.nip.io
EXPECTED_RESPONSE='Welcome to Upcommerce.com!'

response=$(curl -s "$URL")

if [[ "$response" =~ "$EXPECTED_RESPONSE" ]]; then
    echo "Response matches the expected text: $response"
else
    echo "Response does not match the expected text: $response"
    exit 1
fi

export KUBECONFIG=".kube/config"