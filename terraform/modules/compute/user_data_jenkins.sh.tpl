#!/bin/bash
set -euo pipefail

# Jenkins CI only (t3.micro) — nginx reverse-proxies :80 -> Jenkins on loopback :8080.

exec > >(tee /var/log/md-bootstrap.log | logger -t md-bootstrap -s 2>/dev/console) 2>&1

echo "==> swap"
if [[ ! -f /swapfile ]]; then
  dd if=/dev/zero of=/swapfile bs=1M count=1024 status=progress
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
fi

echo "==> packages"
dnf update -y
dnf install -y docker git jq nginx

systemctl enable --now docker
usermod -aG docker ec2-user || true

echo "==> Jenkins LTS (Docker, bound to loopback; nginx fronts :80)"
docker volume create jenkins_home >/dev/null

if docker ps -a --format '{{.Names}}' | grep -qx jenkins; then
  docker rm -f jenkins || true
fi

docker run -d \
  --name jenkins \
  --restart unless-stopped \
  -p 127.0.0.1:${jenkins_http_port}:8080 \
  -p 127.0.0.1:50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e AWS_DEFAULT_REGION=${aws_region} \
  -e AWS_REGION=${aws_region} \
  -e MD_PROJECT=${project} \
  -e MD_ENVIRONMENT=${environment} \
  -e MD_ACCOUNT_ID=${aws_account_id} \
  -e JAVA_OPTS="-Xmx384m -Xms128m -Dhudson.model.DirectoryBrowserSupport.CSP= -Djenkins.install.runSetupWizard=true" \
  jenkins/jenkins:lts-jdk17

echo "==> nginx reverse proxy (HTTP :80 -> 127.0.0.1:${jenkins_http_port})"
cat >/etc/nginx/conf.d/jenkins.conf <<'NGINX'
upstream jenkins {
  server 127.0.0.1:JENKINS_PORT fail_timeout=0;
}

server {
  listen 80 default_server;
  listen [::]:80 default_server;
  server_name _;

  # Jenkins serves large payloads / plugin uploads
  client_max_body_size 50m;

  location / {
    proxy_pass http://jenkins;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Connection "";
    proxy_redirect off;
    proxy_request_buffering off;
    proxy_buffering off;
    proxy_read_timeout 90s;
  }
}
NGINX
sed -i "s/JENKINS_PORT/${jenkins_http_port}/g" /etc/nginx/conf.d/jenkins.conf

# Drop the default welcome site so only Jenkins is served.
rm -f /etc/nginx/conf.d/default.conf || true
# AL2023 nginx may ship a default server in nginx.conf; disable conflicting default if present.
if [[ -f /usr/share/nginx/html/index.html ]]; then
  echo "ok" >/usr/share/nginx/html/index.html
fi

nginx -t
systemctl enable --now nginx
systemctl reload nginx

cat >/etc/profile.d/md-env.sh <<EOF
export AWS_DEFAULT_REGION=${aws_region}
export AWS_REGION=${aws_region}
export MD_PROJECT=${project}
export MD_ENVIRONMENT=${environment}
export MD_ACCOUNT_ID=${aws_account_id}
export MD_ROLE=ci
EOF

echo "==> jenkins + nginx bootstrap complete"
