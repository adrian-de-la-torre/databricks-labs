#!/usr/bin/env bash
#
# Creates the Terraform remote state store.
#
# This is the only thing in this repository that is not managed by Terraform,
# and the only legitimate laptop apply. The reason is genuine circularity: the
# storage account that holds Terraform state cannot hold its own state.
#
# Idempotent. Running it twice changes nothing.
#
# Usage:  az login && ./state-store.sh
#
set -euo pipefail

LOCATION="${LOCATION:-northeurope}"
RESOURCE_GROUP="rg-terraform-state"

SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
# Deterministic, globally unique, one state account per subscription.
SUFFIX="$(printf '%s' "$SUBSCRIPTION_ID" | shasum -a 256 | cut -c1-8)"
STORAGE_ACCOUNT="sttfstate${SUFFIX}"

echo "Subscription : ${SUBSCRIPTION_ID}"
echo "Storage      : ${STORAGE_ACCOUNT}"
echo

az group create \
  --name "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --tags workload=databricks-labs purpose=terraform-state managed_by=script \
  --output none

az storage account create \
  --name "${STORAGE_ACCOUNT}" \
  --resource-group "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --https-only true \
  --allow-blob-public-access false \
  --allow-shared-key-access false \
  --tags workload=databricks-labs purpose=terraform-state managed_by=script \
  --output none

# Versioning protects against a bad write. Soft delete protects against a
# deletion. State needs both: a lost state file is worse than lost infrastructure,
# because the infrastructure still exists but nothing owns it any more.
az storage account blob-service-properties update \
  --account-name "${STORAGE_ACCOUNT}" \
  --resource-group "${RESOURCE_GROUP}" \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 30 \
  --enable-container-delete-retention true \
  --container-delete-retention-days 30 \
  --enable-change-feed true \
  --output none

# Owner at subscription scope does NOT grant data-plane access, and shared keys
# are disabled above, so the operator needs an explicit data role.
OPERATOR_ID="$(az ad signed-in-user show --query id -o tsv)"
SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Storage/storageAccounts/${STORAGE_ACCOUNT}"

az role assignment create \
  --role "Storage Blob Data Owner" \
  --assignee-object-id "${OPERATOR_ID}" \
  --assignee-principal-type User \
  --scope "${SCOPE}" \
  --output none 2>/dev/null || true

echo "Waiting for RBAC propagation..."
for _ in $(seq 1 12); do
  if az storage container list --account-name "${STORAGE_ACCOUNT}" --auth-mode login --output none 2>/dev/null; then
    break
  fi
  sleep 10
done

# Two containers, deliberately. CI identities get no role on tfstate-bootstrap,
# so a compromised pipeline identity cannot rewrite the definitions of the
# identities themselves.
for container in tfstate tfstate-bootstrap; do
  az storage container create \
    --name "${container}" \
    --account-name "${STORAGE_ACCOUNT}" \
    --auth-mode login \
    --output none
done

cat <<EOF

Done. Backend configuration for envs/*.tfbackend:

  resource_group_name  = "${RESOURCE_GROUP}"
  storage_account_name = "${STORAGE_ACCOUNT}"
  container_name       = "tfstate"
  use_azuread_auth     = true
EOF
