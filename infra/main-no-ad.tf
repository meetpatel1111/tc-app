terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

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
# Outputs
# -----------------------------

output "static_web_app_hostname" {
  value = azurerm_static_web_app.swa.default_host_name
}

output "static_web_app_identity_principal_id" {
  value = azurerm_static_web_app.swa.identity[0].principal_id
}

output "static_web_app_identity_tenant_id" {
  value = azurerm_static_web_app.swa.identity[0].tenant_id
}
