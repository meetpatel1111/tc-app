terraform {
  required_version = ">= 1.14.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.117"
    }

    # Not required for current SWA built-in auth implementation
    # Can be enabled later if Entra ID admin access is available
    #
    # azuread = {
    #   source  = "hashicorp/azuread"
    #   version = "~> 3.0"
    # }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

# Not required for Azure Static Web Apps built-in authentication
# provider "azuread" {}

# -----------------------------
# Resource Group
# -----------------------------

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# -----------------------------
# Static Web App
# -----------------------------

resource "azurerm_static_web_app" "swa" {
  name                = var.static_web_app_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku_tier = "Standard"
  sku_size = "Standard"

  identity {
    type = "SystemAssigned"
  }
}

# -----------------------------
# Azure AD App Registration
# -----------------------------
# Not required for current implementation.
# Azure Static Web Apps built-in authentication is being used:
#   /.auth/login/aad
#
# Can be enabled later if:
# - custom Entra ID integration is needed
# - custom claims/groups are required
# - enterprise app registration access is available
#
# resource "azuread_application" "swa_app" {
#   display_name = "${var.static_web_app_name}-auth"
#
#   dynamic "app_role" {
#     for_each = var.clients
#     content {
#       allowed_member_types = ["User"]
#       description          = "Access to ${app_role.key}"
#       display_name         = app_role.key
#       enabled              = true
#       id                   = uuidv5("dns", app_role.key)
#       value                = app_role.key
#     }
#   }
# }
#
# resource "azuread_service_principal" "swa_sp" {
#   client_id = azuread_application.swa_app.client_id
# }

# -----------------------------
# Outputs
# -----------------------------

output "static_web_app_hostname" {
  value = azurerm_static_web_app.swa.default_host_name
}

output "static_web_app_identity_principal_id" {
  value = azurerm_static_web_app.swa.identity[0].principal_id
}

# Not required for current implementation
#
# output "app_registration_client_id" {
#   value = azuread_application.swa_app.client_id
# }
#
# output "app_registration_object_id" {
#   value = azuread_application.swa_app.object_id
# }

output "static_web_app_identity_tenant_id" {
  value = azurerm_static_web_app.swa.identity[0].tenant_id
}