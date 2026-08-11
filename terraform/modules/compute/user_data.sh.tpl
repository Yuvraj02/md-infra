#!/bin/bash
set -euo pipefail

# Marketing Digest bootstrap — swap, Docker, k3s, Jenkins (memory-capped).
# Runs on Amazon Linux 2023 t2.micro (1 GiB RAM).

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
dnf install -y docker git jq postgresql15

systemctl enable --now docker
usermod -aG docker ec2-user || true

echo "==> k3s (single-node, Traefik off to save RAM)"
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik --write-kubeconfig-mode 644" sh -

mkdir -p /home/ec2-user/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ec2-user/.kube/config
chown -R ec2-user:ec2-user /home/ec2-user/.kube
chmod 600 /home/ec2-user/.kube/config

# Convenience for root/SSM sessions
mkdir -p /root/.kube
cp /etc/rancher/k3s/k3s.yaml /root/.kube/config

echo "==> Jenkins LTS (Docker, memory-capped)"
docker volume create jenkins_home >/dev/null

# Avoid clobbering an existing container on reboot re-runs
if ! docker ps -a --format '{{.Names}}' | grep -qx jenkins; then
  docker run -d \
    --name jenkins \
    --restart unless-stopped \
    -p ${jenkins_http_port}:8080 \
    -p 50000:50000 \
    -v jenkins_home:/var/jenkins_home \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /usr/local/bin/kubectl:/usr/local/bin/kubectl:ro \
    -e JAVA_OPTS="-Xmx256m -Xms128m -Dhudson.model.DirectoryBrowserSupport.CSP=" \
    jenkins/jenkins:lts-jdk17
else
  docker start jenkins || true
fi

# kubectl for Jenkins container (k3s ships kubectl)
if [[ ! -e /usr/local/bin/kubectl ]]; then
  ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl || \
    ln -sf /usr/bin/k3s /usr/local/bin/kubectl || true
fi

cat >/etc/profile.d/md-env.sh <<EOF
export AWS_DEFAULT_REGION=${aws_region}
export MD_PROJECT=${project}
export MD_ENVIRONMENT=${environment}
export MD_ACCOUNT_ID=${aws_account_id}
EOF

echo "==> bootstrap complete"
