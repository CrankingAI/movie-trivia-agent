#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# setup-oidc.sh — Set up GitHub Actions OIDC authentication for Azure
#
# Creates:
#   1. Azure AD app registration (sp-movie-trivia-agent-github)
#   2. Service principal
#   3. Contributor role assignment on the resource group
#   4. Federated credentials (main branch + environment:dev)
#   5. GitHub repo secrets (AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID)
#
# Prerequisites: az CLI (logged in), gh CLI (authenticated)
# ---------------------------------------------------------------------------
set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────────
APP_NAME="sp-movie-trivia-agent-github"
RESOURCE_GROUP="rg-movie-trivia-agent-dev"

# Derive the GitHub repo (owner/name) from the local clone
GITHUB_REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
echo "GitHub repo: ${GITHUB_REPO}"

# Current subscription & tenant
SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"

# ── 1. Create Azure AD app registration ───────────────────────────────────
echo "==> Creating Azure AD app registration: ${APP_NAME}..."
CLIENT_ID="$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)"
echo "    App (client) ID: ${CLIENT_ID}"

# ── 2. Create service principal ────────────────────────────────────────────
echo "==> Creating service principal..."
# --idempotent: if the SP already exists, az returns it without error
az ad sp create --id "$CLIENT_ID" --output none 2>/dev/null || true
OBJECT_ID="$(az ad sp show --id "$CLIENT_ID" --query id -o tsv)"
echo "    Service principal object ID: ${OBJECT_ID}"

# ── 3. Assign Contributor role on the resource group ───────────────────────
echo "==> Assigning Contributor role on ${RESOURCE_GROUP}..."
az role assignment create \
  --assignee "$CLIENT_ID" \
  --role Contributor \
  --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}" \
  --output none
echo "    Role assignment complete."

# ── 4. Create federated credentials ───────────────────────────────────────
# 4a. Credential for pushes / PRs to the main branch
echo "==> Creating federated credential for branch:main..."
az ad app federated-credential create \
  --id "$CLIENT_ID" \
  --parameters "{
    \"name\": \"github-main-branch\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GITHUB_REPO}:ref:refs/heads/main\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }" \
  --output none

# 4b. Credential for the "dev" environment
echo "==> Creating federated credential for environment:dev..."
az ad app federated-credential create \
  --id "$CLIENT_ID" \
  --parameters "{
    \"name\": \"github-env-dev\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GITHUB_REPO}:environment:dev\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }" \
  --output none

# ── 5. Set GitHub secrets ──────────────────────────────────────────────────
echo "==> Setting GitHub repository secrets..."
gh secret set AZURE_CLIENT_ID        --body "$CLIENT_ID"
gh secret set AZURE_TENANT_ID        --body "$TENANT_ID"
gh secret set AZURE_SUBSCRIPTION_ID  --body "$SUBSCRIPTION_ID"
echo "    Secrets set."

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
echo "============================== SUMMARY =============================="
echo "  App registration:   ${APP_NAME}"
echo "  Client ID:          ${CLIENT_ID}"
echo "  Tenant ID:          ${TENANT_ID}"
echo "  Subscription ID:    ${SUBSCRIPTION_ID}"
echo "  Resource group:     ${RESOURCE_GROUP}"
echo "  GitHub repo:        ${GITHUB_REPO}"
echo ""
echo "  Federated credentials:"
echo "    - repo:${GITHUB_REPO}:ref:refs/heads/main"
echo "    - repo:${GITHUB_REPO}:environment:dev"
echo ""
echo "  GitHub secrets configured:"
echo "    - AZURE_CLIENT_ID"
echo "    - AZURE_TENANT_ID"
echo "    - AZURE_SUBSCRIPTION_ID"
echo "====================================================================="
