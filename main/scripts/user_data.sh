#!/bin/bash
set -e

# --- Java 25 via Amazon Corretto ---------------------------------------
rpm --import https://yum.corretto.aws/corretto.key
curl -L -o /etc/yum.repos.d/corretto.repo https://yum.corretto.aws/corretto.repo
dnf install -y java-25-amazon-corretto-devel

# --- nginx ---------------------------------------------------------------
dnf install -y nginx

# Disable the RPM-packaged default server block (competes with our reverse
# proxy on port 80) by commenting it out in-place via sed, then add our
# own reverse-proxy config in conf.d/.
sed -i '/^    server {$/,/^    }$/ s/^/#/' /etc/nginx/nginx.conf

cat > /etc/nginx/conf.d/kds-backend.conf <<'NGINXCONF'
server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINXCONF

systemctl enable nginx
systemctl start nginx

# --- Docker + Meilisearch (containerized) --------
dnf install -y docker
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

mkdir -p /opt/meilisearch/data

# --- Deploy script ---
mkdir -p /opt/kds/scripts
cat > /opt/kds/scripts/deploy.sh <<'DEPLOYSCRIPT_EOF'
${deploy_script}
DEPLOYSCRIPT_EOF
chmod +x /opt/kds/scripts/deploy.sh

# --- systemd unit for the backend jar ---
mkdir -p /opt/kds/backend
cat > /etc/systemd/system/kds-backend.service <<'UNIT'
[Unit]
Description=KDS backend Spring Boot service
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/kds/backend
ExecStart=/usr/bin/java -jar /opt/kds/backend/app.jar
Restart=always
User=ec2-user
StandardOutput=append:/var/log/kds-backend.log
StandardError=append:/var/log/kds-backend.log

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
# Not starting kds-backend yet — jar isn't deployed until a manual step.

# --- CloudWatch Agent (logs: nginx, kds-backend, meilisearch) -----------
dnf install -y amazon-cloudwatch-agent

cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWAGENTCONF'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "/kds/prod/nginx-access",
            "log_stream_name": "{instance_id}",
            "retention_in_days": 14
          },
          {
            "file_path": "/var/log/nginx/error.log",
            "log_group_name": "/kds/prod/nginx-error",
            "log_stream_name": "{instance_id}",
            "retention_in_days": 14
          },
          {
            "file_path": "/var/lib/docker/containers/*/*-json.log",
            "log_group_name": "/kds/prod/meilisearch",
            "log_stream_name": "{instance_id}",
            "retention_in_days": 14
          },
          {
            "file_path": "/var/log/kds-backend.log",
            "log_group_name": "/kds/prod/kds-backend",
            "log_stream_name": "{instance_id}",
            "retention_in_days": 14
          }
        ]
      }
    }
  }
}
CWAGENTCONF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json