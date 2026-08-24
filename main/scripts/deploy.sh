#!/bin/bash
set -e
REGION="ap-south-1"
STAGING_BUCKET="kds-electronics-13062026-staging"
JAR_KEY="app.jar"
aws s3 cp "s3://${STAGING_BUCKET}/${JAR_KEY}" /opt/kds/backend/app.jar --region "$REGION"
aws ssm get-parameters-by-path \
  --path "/kds/prod/" \
  --with-decryption \
  --region "$REGION" \
  --query "Parameters[].{Name:Name,Value:Value}" \
  --output json > /tmp/params.json
python3 -c "
import json
with open('/tmp/params.json') as f:
    params = json.load(f)
with open('/etc/kds-backend.env', 'w') as out:
    for p in params:
        key = p['Name'].split('/')[-1]
        out.write(f'KDS_{key}={p[\"Value\"]}\n')
"
chmod 600 /etc/kds-backend.env
MEILI_KEY=$(aws ssm get-parameter --name "/kds/prod/MEILI_MASTER_KEY" --with-decryption --region "$REGION" --query "Parameter.Value" --output text)
echo "MEILI_MASTER_KEY=${MEILI_KEY}" > /etc/meilisearch.env
chmod 600 /etc/meilisearch.env
if ! grep -q "EnvironmentFile=/etc/kds-backend.env" /etc/systemd/system/kds-backend.service; then
  sed -i '/\[Service\]/a EnvironmentFile=/etc/kds-backend.env' /etc/systemd/system/kds-backend.service
  systemctl daemon-reload
fi
docker stop meilisearch 2>/dev/null || true
docker rm meilisearch 2>/dev/null || true
docker run -d --name meilisearch --restart unless-stopped \
  -p 7700:7700 -v /opt/meilisearch/data:/meili_data \
  -e MEILI_ENV=production --env-file /etc/meilisearch.env \
  getmeili/meilisearch:v1.53.1
sleep 2
systemctl restart kds-backend
sleep 5
docker inspect -f '{{.State.Running}}' meilisearch
systemctl is-active kds-backend
rm -f /tmp/params.json
