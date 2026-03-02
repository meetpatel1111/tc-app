# Role Management Guide

This guide covers how to manage user access to client-specific routes (`/Client1`, `/Client2`, etc.) on the Azure Static Web App.

## How It Works

| Route | Required Role | Example |
|---|---|---|
| `/Client1/*` | `client1` | Client 1 terms page |
| `/Client2/*` | `client2` | Client 2 terms page |

- **Unauthenticated** users → redirected to Azure AD login
- **Authenticated without role** → see "Access Denied" page
- **Authenticated with correct role** → can access the route

---

## Role Creation

Roles in SWA Simple mode are **just strings** — they don't need to be pre-registered anywhere. You "create" a role simply by using it in two places:

### 1. Define the route rule in `app/staticwebapp.config.json`

This file maps routes to required roles:

```json
{
  "routes": [
    { "route": "/Client1/*", "allowedRoles": ["client1"] },
    { "route": "/Client2/*", "allowedRoles": ["client2"] }
  ]
}
```

### 2. Assign the role to users

Either via the workflow (`scripts/users.json`) or manually in the Azure Portal.

### Adding a New Client Role

To add a new client (e.g., `Client3`):

1. **Create the page:** Add `app/Client3/index.html`
2. **Add route rule** in `app/staticwebapp.config.json`:
   ```json
   { "route": "/Client3/*", "allowedRoles": ["client3"] }
   ```
3. **Add users** in `scripts/users.json`:
   ```json
   "newuser@example.com": ["client3"]
   ```
4. **Deploy** the app (push to main) and **run the workflow** to assign roles

### Terraform (Azure AD App Roles)

The `infra/main.tf` file also creates Azure AD app roles via Terraform using the `clients` variable:

```hcl
variable "clients" {
  default = {
    client1 = "Client 1 Access"
    client2 = "Client 2 Access"
  }
}
```

These are created in the `tc-swa-dev-auth` Azure AD App Registration. They are relevant **only if** you switch the SWA to **Custom authentication mode**. In the current **Simple mode**, the Terraform-created AD roles are not used — the SWA manages roles directly.

---

## Option A — Automated (GitHub Actions Workflow)

### Step 1: Add Users to `scripts/users.json`

```json
{
  "userAssignments": {
    "user@example.com": ["client1"],
    "another@company.com": ["client1", "client2"]
  }
}
```

- Use the **exact email** the user will log in with
- Assign one or more roles per user
- Commit and push the changes

### Step 2: Run the Workflow

1. Go to **GitHub → Actions → "Assign SWA User Roles"**
2. Click **"Run workflow"**
3. Select:
   - **Environment:** `dev`
   - **Action:** `assign-all`
4. Click **"Run workflow"**

### Step 3: Check Results

The workflow handles two scenarios automatically:

| Scenario | What Happens |
|---|---|
| **Existing user** (has logged in before) | Roles updated directly — no action needed ✅ |
| **New user** (never logged in) | One-time invite link generated in CSV |

For new users:
1. Go to the **workflow run page** → scroll to **Artifacts**
2. Download `invite-links-dev-{run_id}.csv`
3. Send the invite link to the user — they click it **once** to activate access
4. After activation, future role changes are automatic (no new invite needed)

### Step 4: Update Roles Later

To change a user's roles:
1. Edit `scripts/users.json` — add/remove roles
2. Commit, push, and re-run the workflow
3. Existing users get roles updated automatically

### List Current Assignments

Run the workflow with **Action: `list`** to see all current SWA user-role assignments.

---

## Option B — Manual (Azure Portal)

### For New Users (First-Time Access)

1. Go to [Azure Portal](https://portal.azure.com) → **Static Web Apps** → **tc-swa-dev**
2. Click **Settings → Role management**
3. Click **Invite**
4. Fill in:
   - **Authentication provider:** `Azure Active Directory`
   - **Email address:** user's email
   - **Role:** `client1` (or `client1,client2` for multiple)
   - **Invitation expiration:** `168` (7 days)
5. Click **Generate** → copy the invite link
6. **Send the link** to the user → they click it in an **Incognito window**

> **Important:** Open the invite link in a clean Incognito window. Invite links are single-use — if it fails, generate a new one.

### For Existing Users (Update Roles)

1. Go to **Static Web Apps** → **tc-swa-dev** → **Role management**
2. Find the user in the list
3. Select the user → update their roles
4. User must **sign out and sign back in** for new roles to take effect

### Remove Access

1. Go to **Role management** → find the user
2. Select → **Delete**
3. The user will see "Access Denied" on their next login

---

## Troubleshooting

| Issue | Solution |
|---|---|
| User sees "Access Denied" after role assignment | User must **sign out** and **sign back in** to get a fresh token |
| Invite link shows "400: Bad Request" | The link was already used or expired — generate a new one |
| Invite link fails in browser | Open in a **new Incognito window** with no prior Microsoft login |
| Workflow says "User not in SWA yet" | User hasn't logged in before — send them the invite link from the CSV |
| Workflow shows 0 existing users | The `az staticwebapp users list` CLI only lists users who accepted invites |

---

## Architecture

```
users.json → GitHub Actions Workflow → Azure SWA Role Management
                    ↓                          ↓
            Existing users:             New users:
            roles updated               invite link in CSV
            automatically               (one-time click)
```

**Config files:**
- `app/staticwebapp.config.json` — defines which routes require which roles
- `scripts/users.json` — maps emails to roles (used by the workflow)
- `.github/workflows/assign-roles.yml` — automation workflow
