#!/usr/bin/env pwsh
param(
    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [string]$UserEmail,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("client1", "client2")]
    [string]$Client,
    
    [Parameter(Mandatory=$false)]
    [switch]$ListUsers,
    
    [Parameter(Mandatory=$false)]
    [switch]$AssignAll
)

# Connect to Azure AD
Connect-AzureAD

# Get app details
$appName = if ($Environment -eq "dev") { "tc-swa-dev-auth" } else { "tc-swa-test-auth" }
$app = Get-AzureADApplication -DisplayName $appName
$sp = Get-AzureADServicePrincipal -Filter "displayName eq '$appName'"

Write-Host "=== Azure AD App: $appName ===" -ForegroundColor Green
Write-Host "Available Roles:"
$app.AppRoles | Format-Table DisplayName, Description

if ($ListUsers) {
    Write-Host "`n=== Current Role Assignments ===" -ForegroundColor Yellow
    $assignments = Get-AzureADServicePrincipalAppRoleAssignment -ObjectId $sp.ObjectId
    foreach ($assignment in $assignments) {
        $user = Get-AzureADUser -ObjectId $assignment.PrincipalId
        $role = $app.AppRoles | Where-Object { $_.Id -eq $assignment.Id }
        Write-Host "$($user.UserPrincipalName) - $($role.DisplayName)"
    }
    return
}

if ($AssignAll) {
    # Define your users here
    $userAssignments = @{
        "user1@company.com" = @("client1")
        "user2@company.com" = @("client1", "client2")
        "user3@company.com" = @("client2")
        "meetkumar.patel@pmeet464gmail.onmicrosoft.com" = @("client1", "client2")
    }
    
    Write-Host "`n=== Assigning roles ===" -ForegroundColor Green
    foreach ($email in $userAssignments.Keys) {
        $roles = $userAssignments[$email]
        Write-Host "Processing user: $email"
        $user = Get-AzureADUser -Filter "UserPrincipalName eq '$email'"
        
        if ($user) {
            foreach ($roleName in $roles) {
                $role = $app.AppRoles | Where-Object { $_.DisplayName -eq $roleName }
                if ($role) {
                    try {
                        New-AzureADUserAppRoleAssignment -ObjectId $user.ObjectId -PrincipalId $user.ObjectId -ResourceId $app.ObjectId -Id $role.Id -ErrorAction SilentlyContinue
                        Write-Host "  ✓ Assigned role: $roleName" -ForegroundColor Green
                    } catch {
                        Write-Host "  ✗ Failed to assign role: $roleName (may already exist)" -ForegroundColor Yellow
                    }
                }
            }
        } else {
            Write-Host "  ✗ User not found: $email" -ForegroundColor Red
        }
    }
    return
}

if ($UserEmail -and $Client) {
    Write-Host "`n=== Assigning single role ===" -ForegroundColor Green
    
    $user = Get-AzureADUser -Filter "UserPrincipalName eq '$UserEmail'"
    if (!$user) {
        Write-Host "User not found: $UserEmail" -ForegroundColor Red
        return
    }
    
    $role = $app.AppRoles | Where-Object { $_.DisplayName -eq $Client }
    if (!$role) {
        Write-Host "Role not found: $Client" -ForegroundColor Red
        return
    }
    
    try {
        New-AzureADUserAppRoleAssignment -ObjectId $user.ObjectId -PrincipalId $user.ObjectId -ResourceId $app.ObjectId -Id $role.Id
        Write-Host "✓ Successfully assigned $Client role to $UserEmail" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to assign role (may already exist): $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "`nUsage examples:" -ForegroundColor Cyan
    Write-Host "Assign single role:"
    Write-Host "  .\assign-roles.ps1 -UserEmail 'user@company.com' -Client 'client1'"
    Write-Host ""
    Write-Host "Assign all predefined users:"
    Write-Host "  .\assign-roles.ps1 -AssignAll"
    Write-Host ""
    Write-Host "List current assignments:"
    Write-Host "  .\assign-roles.ps1 -ListUsers"
}
