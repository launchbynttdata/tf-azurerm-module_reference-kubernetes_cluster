// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

variable "product_family" {
  description = <<EOF
    (Required) Name of the product family for which the resource is created.
    Example: org_name, department_name.
  EOF
  type        = string
  default     = "dso"
}

variable "product_service" {
  description = <<EOF
    (Required) Name of the product service for which the resource is created.
    For example, backend, frontend, middleware etc.
  EOF
  type        = string
  default     = "kube"
}

variable "environment" {
  description = "Environment in which the resource should be provisioned like dev, qa, prod etc."
  type        = string
  default     = "dev"
}

variable "environment_number" {
  description = "The environment count for the respective environment. Defaults to 000. Increments in value of 1"
  type        = string
  default     = "000"
}

variable "region" {
  description = "AWS Region in which the infra needs to be provisioned"
  type        = string
  default     = "eastus"
}

variable "resource_names_map" {
  description = "A map of key to resource_name that will be used by tf-launch-module_library-resource_name to generate resource names"
  type = map(object(
    {
      name       = string
      max_length = optional(number, 60)
    }
  ))
  default = {
    rg = {
      name       = "rg"
      max_length = 60
    }
    vnet = {
      name       = "vnet"
      max_length = 60
    }
    msi = {
      name       = "msi"
      max_length = 60
    }
  }
}

# VNet related variables
variable "address_space" {
  description = "Address space of the Vnet"
  type        = list(string)
  default     = ["10.50.0.0/16"]
}

variable "subnet_names" {
  description = "Name of the subnets to be created"
  type        = list(string)
  default     = ["subnet-api-server", "subnet-default-pool", "subnet-app-pool-1", "subnet-private-aks", "subnet-private-endpoint"]
}

variable "subnet_prefixes" {
  description = "The CIDR blocks of the subnets whose names are specified in `subnet_names`"
  type        = list(string)
  default     = ["10.50.0.0/24", "10.50.1.0/24", "10.50.2.0/24", "10.50.3.0/24", "10.50.4.0/24"]
}

variable "kubernetes_version" {
  type        = string
  default     = "1.26.3"
  description = "Specify which Kubernetes release to use. The default used is the latest Kubernetes version available in the region"
}

variable "network_plugin" {
  type        = string
  default     = "azure"
  description = "Network plugin to use for networking. Default is azure."
  nullable    = false
}

variable "agents_count" {
  type        = number
  default     = 2
  description = "The number of Agents that should exist in the Agent Pool. Please set `agents_count` `null` while `enable_auto_scaling` is `true` to avoid possible `agents_count` changes."
}

variable "agents_availability_zones" {
  type        = list(string)
  default     = null
  description = "(Optional) A list of Availability Zones across which the Node Pool should be spread. Changing this forces a new resource to be created."
}

variable "agents_pool_name" {
  type        = string
  default     = "default"
  description = "The default Azure AKS agentpool (nodepool) name."
  nullable    = false
}

variable "agents_size" {
  type        = string
  default     = "Standard_D2_v2"
  description = "The default virtual machine size for the Kubernetes agents. Changing this without specifying `var.temporary_name_for_rotation` forces a new resource to be created."
}

variable "os_disk_size_gb" {
  type        = number
  default     = 30
  description = "Disk size of nodes in GBs."
}

variable "identity_type" {
  type        = string
  default     = "SystemAssigned"
  description = "(Optional) The type of identity used for the managed cluster. Conflicts with `client_id` and `client_secret`. Possible values are `SystemAssigned` and `UserAssigned`. If `UserAssigned` is set, an `identity_ids` must be set as well."

  validation {
    condition     = var.identity_type == "SystemAssigned" || var.identity_type == "UserAssigned"
    error_message = "`identity_type`'s possible values are `SystemAssigned` and `UserAssigned`"
  }
}

variable "private_cluster_enabled" {
  type        = bool
  default     = false
  description = "If true cluster API server will be exposed only on internal IP address and available only in cluster vnet."
}

variable "net_profile_dns_service_ip" {
  type        = string
  default     = null
  description = "(Optional) IP address within the Kubernetes service address range that will be used by cluster service discovery (kube-dns). Changing this forces a new resource to be created."
}

variable "net_profile_outbound_type" {
  type        = string
  default     = "loadBalancer"
  description = "(Optional) The outbound (egress) routing method which should be used for this Kubernetes Cluster. Possible values are loadBalancer and userDefinedRouting. Defaults to loadBalancer."
}

variable "net_profile_pod_cidr" {
  type        = string
  default     = null
  description = " (Optional) The CIDR to use for pod IP addresses. This field can only be set when network_plugin is set to kubenet. Changing this forces a new resource to be created."
}

variable "net_profile_service_cidr" {
  type        = string
  default     = null
  description = "(Optional) The Network Range used by the Kubernetes service. Changing this forces a new resource to be created."
}

# Key Vault
variable "key_vault_secrets_provider_enabled" {
  type        = bool
  default     = false
  description = "(Optional) Whether to use the Azure Key Vault Provider for Secrets Store CSI Driver in an AKS cluster. For more details: https://docs.microsoft.com/en-us/azure/aks/csi-secrets-store-driver"
  nullable    = false
}

variable "secret_rotation_enabled" {
  type        = bool
  default     = false
  description = "Is secret rotation enabled? This variable is only used when `key_vault_secrets_provider_enabled` is `true` and defaults to `false`"
  nullable    = false
}

variable "secret_rotation_interval" {
  type        = string
  default     = "2m"
  description = "The interval to poll for secret rotation. This attribute is only set when `secret_rotation` is `true` and defaults to `2m`"
  nullable    = false
}

## App insights

variable "create_application_insights" {
  description = "Ff true, create a new Application Insights resource to be associated with the AKS cluster"
  type        = bool
  default     = true
}

variable "application_insights" {
  description = "Details for the Application Insights resource to be associated with the AKS cluster. Required only when create_application_insights=true"
  type = object({
    application_type                      = optional(string, "web")
    retention_in_days                     = optional(number, 30)
    daily_data_cap_in_gb                  = optional(number, 1)
    daily_data_cap_notifications_disabled = optional(bool, false)
    sampling_percentage                   = optional(number, 100)
    disabling_ip_masking                  = optional(bool, false)
    local_authentication_disabled         = optional(bool, false)
    internet_ingestion_enabled            = optional(bool, false)
    internet_query_enabled                = optional(bool, true)
    force_customer_storage_for_profiler   = optional(bool, false)
  })

  default = {}
}

## Private Link Scope

variable "create_monitor_private_link_scope" {
  description = <<EOF
    If true, create a new Private Link Scope for Azure Monitor.
    NOTE: This will cause all azure monitor / log analytics traffic to go through private link.
  EOF
  type        = bool
  default     = true
}

# https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns#management-and-governance
variable "monitor_private_link_scope_dns_zone_suffixes" {
  description = "The DNS zone suffixes for the private link scope"
  type        = set(string)
  default = [
    "privatelink.monitor.azure.com",
    "privatelink.oms.opinsights.azure.com",
    "privatelink.ods.opinsights.azure.com",
    "privatelink.agentsvc.azure-automation.net",
    "privatelink.blob.core.windows.net"
  ]
}

variable "tags" {
  description = "A map of custom tags to be attached to this module resources"
  type        = map(string)
  default     = {}
}
