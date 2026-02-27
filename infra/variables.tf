variable "resource_group_name" {
  type        = string
  description = "Resource Group Name"
}

variable "location" {
  type        = string
  description = "Azure Region"
  default     = "eastus2"
}

variable "static_web_app_name" {
  type        = string
  description = "Static Web App Name"
}

variable "clients" {
  description = "Map of clients (used to generate app roles)"
  type        = map(any)
}