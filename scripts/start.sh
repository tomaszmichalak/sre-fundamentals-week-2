#!/usr/bin/env bash
cd ..
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

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack -f ./prometheus/values.yaml -n monitoring --create-namespace
kubectl -n monitoring rollout status deployment prometheus-kube-prometheus-stack-prometheus

helm install canary-demo ./canary-demo/canary-demo -n canary-demo --create-namespace
kubectl -n canary-demo rollout status deployment canary-demo

URL=http://canary-demo-127-0-0-1.nip.io
EXPECTED_RESPONSE='Welcome to Upcommerce.com!'

response=$(curl -s "$URL")

if [[ "$response" =~ "$EXPECTED_RESPONSE" ]]; then
    echo "Response matches the expected text: $response"
else
    echo "Response does not match the expected text: $response"
    exit 1
fi
