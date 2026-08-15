#!/bin/bash
set -euo pipefail

# k3s + Argo CD (t3.medium) — application / GitOps host.

exec > >(tee /var/log/md-bootstrap.log | logger -t md-bootstrap -s 2>/dev/console) 2>&1

echo "==> swap"
if [[ ! -f /swapfile ]]; then
  dd if=/dev/zero of=/swapfile bs=1M count=2048 status=progress
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
fi

echo "==> packages"
dnf update -y
dnf install -y git jq postgresql15

echo "==> k3s (single-node, Traefik disabled; use your own ingress later)"
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik --write-kubeconfig-mode 644" sh -

mkdir -p /home/ec2-user/.kube /root/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ec2-user/.kube/config
cp /etc/rancher/k3s/k3s.yaml /root/.kube/config
chown -R ec2-user:ec2-user /home/ec2-user/.kube
chmod 600 /home/ec2-user/.kube/config /root/.kube/config

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Wait for API
for i in $(seq 1 60); do
  if kubectl get nodes >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

echo "==> Argo CD"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Give controllers a moment; do not fail bootstrap if still Pending
kubectl -n argocd wait --for=condition=available deployment/argocd-server --timeout=300s || true

cat >/etc/profile.d/md-env.sh <<EOF
export AWS_DEFAULT_REGION=${aws_region}
export MD_PROJECT=${project}
export MD_ENVIRONMENT=${environment}
export MD_ACCOUNT_ID=${aws_account_id}
export MD_ROLE=k3s
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
EOF

echo "==> cluster bootstrap complete"
echo "Argo CD initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true
echo
