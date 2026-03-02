# Complete Setup Guide

End-to-end guide to deploy and configure the Terms & Conditions Enterprise portal from scratch.

---

## Prerequisites

### 1. GitHub Secrets

Add these secrets in **GitHub → Settings → Secrets and variables → Actions**:

| Secret | Description |
|---|---|
| `AZURE_CREDENTIALS` | Service Principal JSON (`az ad sp create-for-rbac --sdk-auth`) |
| `AZURE_STATIC_WEB_APPS_API_TOKEN` | SWA deployment token (from Azure Portal after Step 2) |

### 2. Azure Permissions

The service principal needs:
- **Contributor** on the Azure subscription (for resource creation)
- **Application Administrator** in Azure AD (for app registrations)

---

## Step 1 — Deploy Infrastructure (Terraform)

Creates: Resource Group, Static Web App, Azure AD App Registration + Service Principal.

1. Go to **GitHub → Actions → "Infrastructure Deployment"**
2. Click **"Run workflow"**
   - **Environment:** `dev`
   - **Action:** `plan` *(review first)*
3. Review the plan output
4. Run again with **Action:** `apply`

**What it creates:**
- Resource Group: `tc-swa-dev-rg`
- Static Web App: `tc-swa-dev` (Standard tier, East US 2)
- Azure AD App: `tc-swa-dev-auth` with app roles from `infra/dev.tfvars`

### Configuration

Edit `infra/dev.tfvars` to add/remove clients:

```hcl
clients = {
  client1 = {}
  client2 = {}
  client3 = {}   # Add new clients here
}
```

---

## Step 2 — Get SWA Deployment Token (⚠️ Manual)

After Terraform creates the SWA, you need the deployment token for the SWA deploy workflow.

1. Go to **Azure Portal → Static Web Apps → tc-swa-dev**
2. Click **Overview → Manage deployment token**
3. Copy the token
4. Add it as GitHub secret: **`AZURE_STATIC_WEB_APPS_API_TOKEN`**

> This is a one-time step per environment.

---

## Step 3 — Deploy the Static Web App

Deploys the `app/` folder (HTML pages, config, access-denied page) to the SWA.

1. Go to **GitHub → Actions → "Static Web App Deployment"**
2. Click **"Run workflow"** → **Environment:** `dev`
3. Wait for deployment to complete

**SWA URL:** `https://blue-smoke-087c3fd0f.6.azurestaticapps.net`

### What gets deployed:

| File | Purpose |
|---|---|
| `app/index.html` | Landing page |
| `app/Client1/index.html` | Client 1 terms page (requires `client1` role) |
| `app/Client2/index.html` | Client 2 terms page (requires `client2` role) |
| `app/access-denied.html` | Shown when user lacks required role (403) |
| `app/staticwebapp.config.json` | Route rules, auth config, response overrides |

---

## Step 4 — Configure SWA Authentication (⚠️ Manual)

The SWA uses **Simple mode** authentication. This needs to be configured once in the Azure Portal.

1. Go to **Azure Portal → Static Web Apps → tc-swa-dev**
2. Click **Settings → Authentication**
3. Ensure **Mode** is set to **Simple**
4. Verify **Azure Active Directory** is listed as a provider
5. Click **Apply**

> Authentication is pre-configured via `staticwebapp.config.json`. Unauthenticated users hitting `/Client1/*` or `/Client2/*` are automatically redirected to `/.auth/login/aad`.

---

## Step 5 — Add Users to `scripts/users.json`

Define which users get which roles:

```json
{
  "userAssignments": {
    "user@example.com": ["client1"],
    "another@company.com": ["client1", "client2"]
  }
}
```

Commit and push the changes.

---

## Step 6 — Assign User Roles (Automated)

1. Go to **GitHub → Actions → "Assign SWA User Roles"**
2. Click **"Run workflow"**
   - **Environment:** `dev`
   - **Action:** `assign-all`

### Results

| User Status | What Happens |
|---|---|
| **Existing** (has logged in before) | Roles updated automatically ✅ |
| **New** (never logged in) | One-time invite link generated in CSV artifact |

### For New Users

1. Go to **workflow run** → **Artifacts** section
2. Download `invite-links-dev-{run_id}.csv`
3. Send the invite link to the user
4. User opens the link in an **Incognito window** → signs in → access granted
5. Future role changes are automatic (no new invite needed)

---

## Step 7 — First-Time User Invite (⚠️ Manual if not using workflow)

If you prefer to invite users manually via the Azure Portal:

1. Go to **Azure Portal → Static Web Apps → tc-swa-dev → Role management**
2. Click **Invite**
3. Fill in:
   - **Authentication provider:** `Azure Active Directory`
   - **Email address:** user's email
   - **Role:** `client1` or `client1,client2`
   - **Invitation expiration:** `168` (7 days)
4. Click **Generate** → copy the invite link
5. Send to user → they click it in an **Incognito window**

> **Important:** Invite links are single-use. If one fails, generate a new one.

---

## Step 8 — Verify Access

1. Open **Incognito window**
2. Go to `https://blue-smoke-087c3fd0f.6.azurestaticapps.net/Client1`
3. You'll be redirected to Microsoft login
4. Sign in with the invited email
5. You should see the Client 1 Terms Page ✅

| Test | Expected Result |
|---|---|
| `/Client1` with `client1` role | ✅ Client 1 Terms Page |
| `/Client2` with `client2` role | ✅ Client 2 Terms Page |
| `/Client1` without `client1` role | ❌ Access Denied page |
| `/Client1` not logged in | 🔄 Redirect to AAD login |

---

## Adding a New Client

1. **Create page:** `app/Client3/index.html`
2. **Add route** in `app/staticwebapp.config.json`:
   ```json
   { "route": "/Client3/*", "allowedRoles": ["client3"] }
   ```
3. **Add client to Terraform** in `infra/dev.tfvars`:
   ```hcl
   clients = { client1 = {}, client2 = {}, client3 = {} }
   ```
4. **Run workflows** in order:
   - Infrastructure Deployment (`apply`)
   - Static Web App Deployment
5. **Add users** to `scripts/users.json` → run Assign Roles workflow

---

## Troubleshooting

| Issue | Solution |
|---|---|
| "Access Denied" after role assignment | **Sign out** and **sign back in** to get a fresh token |
| Invite link shows "400: Bad Request" | Link was used or expired — generate a new one |
| Invite link fails | Open in a **new Incognito window** with no prior login |
| Workflow says "User not in SWA" | User never logged in before — send them the invite link |
| `az staticwebapp users list` returns 0 | Only lists users who have accepted invites |
| SWA deploy fails | Check that `AZURE_STATIC_WEB_APPS_API_TOKEN` secret is set |
| Terraform fails | Check that `AZURE_CREDENTIALS` secret has correct permissions |

---

## Project Structure

```
├── app/                          # Static web app content
│   ├── index.html                # Landing page
│   ├── access-denied.html        # 403 error page
│   ├── staticwebapp.config.json  # Routes, auth, response overrides
│   ├── Client1/index.html        # Client 1 terms
│   └── Client2/index.html        # Client 2 terms
├── infra/                        # Terraform IaC
│   ├── main.tf                   # Resources (RG, SWA, AAD App)
│   ├── variables.tf              # Input variables
│   ├── dev.tfvars                # Dev environment config
│   └── backend.tf                # Remote state config
├── scripts/
│   └── users.json                # User-to-role mapping
├── .github/workflows/
│   ├── infra-deploy.yml          # Terraform deploy workflow
│   ├── static-web-app-deploy.yml # SWA content deploy workflow
│   └── assign-roles.yml          # User role assignment workflow
├── docs/
│   └── ROLE-MANAGEMENT.md        # Role management guide
└── prebootstrap.sh               # Terraform backend bootstrap
```
