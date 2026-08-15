#!/usr/bin/env bash
# Idempotently ensure Postgres databases exist on Marketing Digest RDS.
#
# Creates:
#   - marketing_digest          (platform / shared)
#   - marketing_digest_auth     (auth-service)
#   - marketing_digest_blog     (blog-service)
#
# Prerequisites:
#   - Run from a host that can reach RDS (Jenkins or cluster EC2 in the VPC)
#   - AWS CLI + instance role (or profile) that can read the RDS secret
#   - docker available (uses postgres:16-alpine client)
#
# Usage:
#   export AWS_PROFILE=marketing-digest   # optional on EC2 with instance role
#   export AWS_REGION=ap-south-1
#   export NAME_PREFIX=marketing-digest-production   # optional
#   ./create_database.sh
#
# Or pass the Secrets Manager secret id/arn explicitly:
#   SECRET_ID=arn:aws:secretsmanager:... ./create_database.sh

set -euo pipefail

AWS_REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-ap-south-1}}"
NAME_PREFIX="${NAME_PREFIX:-marketing-digest-production}"
SECRET_ID="${SECRET_ID:-${NAME_PREFIX}/rds/master}"

DATABASES=(
  marketing_digest
  marketing_digest_auth
  marketing_digest_blog
)

echo "==> region=${AWS_REGION} secret=${SECRET_ID}"

SECRET_JSON="$(aws secretsmanager get-secret-value \
  --secret-id "${SECRET_ID}" \
  --region "${AWS_REGION}" \
  --query SecretString \
  --output text)"

HOST="$(echo "${SECRET_JSON}" | jq -r '.host')"
PORT="$(echo "${SECRET_JSON}" | jq -r '.port // 5432')"
USER="$(echo "${SECRET_JSON}" | jq -r '.username')"
PASS="$(echo "${SECRET_JSON}" | jq -r '.password')"

if [[ -z "${HOST}" || "${HOST}" == "null" ]]; then
  echo "error: could not resolve RDS host from secret ${SECRET_ID}" >&2
  exit 1
fi

echo "==> connecting to ${HOST}:${PORT} as ${USER}"

psql_admin() {
  docker run --rm \
    -e PGPASSWORD="${PASS}" \
    postgres:16-alpine \
    psql "host=${HOST} port=${PORT} user=${USER} dbname=postgres sslmode=require" \
    -v ON_ERROR_STOP=1 \
    "$@"
}

for DB in "${DATABASES[@]}"; do
  EXISTS="$(psql_admin -tAc "SELECT 1 FROM pg_database WHERE datname='${DB}'" | tr -d '[:space:]')"
  if [[ "${EXISTS}" == "1" ]]; then
    echo "==> database already exists: ${DB}"
  else
    echo "==> creating database: ${DB}"
    psql_admin -c "CREATE DATABASE ${DB}"
  fi
done

echo "==> done"
