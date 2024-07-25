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

output "kube_config_raw" {
  description = <<EOT
    The `azurerm_kubernetes_cluster`'s `kube_config_raw` argument. Raw Kubernetes config to be used by
    [kubectl](https://kubernetes.io/docs/reference/kubectl/overview/) and other compatible tools.
  EOT
  value       = module.aks.kube_config_raw
  sensitive   = true
}

output "kube_admin_config_raw" {
  description = <<EOT
    The `azurerm_kubernetes_cluster`'s `kube_admin_config_raw` argument. Raw Kubernetes config for the admin account to
    be used by [kubectl](https://kubernetes.io/docs/reference/kubectl/overview/) and other compatible tools.
    This is only available when Role Based Access Control with Azure Active Directory is enabled and local accounts enabled.
  EOT
  value       = module.aks.kube_admin_config_raw
  sensitive   = true
}

output "admin_host" {
  description = "The `host` in the `azurerm_kubernetes_cluster`'s `kube_admin_config` block. The Kubernetes cluster server host."
  sensitive   = true
  value       = module.aks.admin_host
}

output "admin_password" {
  description = "The `password` in the `azurerm_kubernetes_cluster`'s `kube_admin_config` block. A password or token used to authenticate to the Kubernetes cluster."
  sensitive   = true
  value       = module.aks.admin_password
}

output "admin_username" {
  description = "The `username` in the `azurerm_kubernetes_cluster`'s `kube_admin_config` block. A username used to authenticate to the Kubernetes cluster."
  sensitive   = true
  value       = module.aks.admin_username
}

output "azure_policy_enabled" {
  description = "The `azurerm_kubernetes_cluster`'s `azure_policy_enabled` argument. Should the Azure Policy Add-On be enabled? For more details please visit [Understand Azure Policy for Azure Kubernetes Service](https://docs.microsoft.com/en-ie/azure/governance/policy/concepts/rego-for-aks)"
  value       = module.aks.azure_policy_enabled
}

output "azurerm_log_analytics_workspace_id" {
  description = "The id of the created Log Analytics workspace"
  value       = module.aks.azurerm_log_analytics_workspace_id
}

output "azurerm_log_analytics_workspace_name" {
  description = "The name of the created Log Analytics workspace"
  value       = module.aks.azurerm_log_analytics_workspace_name
}

output "azurerm_log_analytics_workspace_primary_shared_key" {
  description = "Specifies the workspace key of the log analytics workspace"
  sensitive   = true
  value       = module.aks.azurerm_log_analytics_workspace_primary_shared_key
}

output "client_certificate" {
  description = "The `client_certificate` in the `azurerm_kubernetes_cluster`'s `kube_config` block. Base64 encoded public certificate used by clients to authenticate to the Kubernetes cluster."
  sensitive   = true
  value       = module.aks.client_certificate
}

output "client_key" {
  description = "The `client_key` in the `azurerm_kubernetes_cluster`'s `kube_config` block. Base64 encoded private key used by clients to authenticate to the Kubernetes cluster."
  sensitive   = true
  value       = module.aks.client_key
}

output "cluster_ca_certificate" {
  description = "The `cluster_ca_certificate` in the `azurerm_kubernetes_cluster`'s `kube_config` block. Base64 encoded public CA certificate used as the root of trust for the Kubernetes cluster."
  sensitive   = true
  value       = module.aks.cluster_ca_certificate
}

output "cluster_fqdn" {
  description = "The FQDN of the Azure Kubernetes Managed Cluster."
  value       = module.aks.cluster_fqdn
}

output "cluster_portal_fqdn" {
  description = "The FQDN for the Azure Portal resources when private link has been enabled, which is only resolvable inside the Virtual Network used by the Kubernetes Cluster."
  value       = module.aks.cluster_portal_fqdn
}

output "cluster_private_fqdn" {
  description = "The FQDN for the Kubernetes Cluster when private link has been enabled, which is only resolvable inside the Virtual Network used by the Kubernetes Cluster."
  value       = module.aks.cluster_private_fqdn
}

output "generated_cluster_private_ssh_key" {
  description = "The cluster will use this generated private key as ssh key when `var.public_ssh_key` is empty or null. Private key data in [PEM (RFC 1421)](https://datatracker.ietf.org/doc/html/rfc1421) format."
  sensitive   = true
  value       = module.aks.generated_cluster_private_ssh_key
}

output "generated_cluster_public_ssh_key" {
  description = "The cluster will use this generated public key as ssh key when `var.public_ssh_key` is empty or null. The fingerprint of the public key data in OpenSSH MD5 hash format, e.g. `aa:bb:cc:....` Only available if the selected private key format is compatible, similarly to `public_key_openssh` and the [ECDSA P224 limitations](https://registry.terraform.io/providers/hashicorp/tls/latest/docs#limitations)."
  value       = module.aks.generated_cluster_public_ssh_key
}

output "host" {
  description = "The `host` in the `azurerm_kubernetes_cluster`'s `kube_config` block. The Kubernetes cluster server host."
  sensitive   = true
  value       = module.aks.host
}

output "cluster_name" {
  description = "Name of the AKS cluster"
  value       = module.aks.aks_name
}

output "cluster_id" {
  description = "ID of the AKS cluster"
  value       = module.aks.aks_id
}

output "resource_group_name" {
  description = "Name of the Resource Group for the AKS Cluster. Node RG is separate that is created automatically by Azure"
  value       = var.resource_group_name != null ? var.resource_group_name : module.resource_group[0].name
}

output "application_gateway_id" {
  description = "Application Gateway ID when application"
  value       = module.aks.ingress_application_gateway
}

output "key_vault_secrets_provider" {
  description = "The `azurerm_kubernetes_cluster`'s `key_vault_secrets_provider` block."
  value       = module.aks.key_vault_secrets_provider
}

output "key_vault_secrets_provider_enabled" {
  description = "Has the `azurerm_kubernetes_cluster` turned on `key_vault_secrets_provider` block?"
  value       = module.aks.key_vault_secrets_provider_enabled
}

output "cluster_identity" {
  description = "The `azurerm_kubernetes_cluster`'s `identity` block."
  value       = module.aks.cluster_identity
}

output "kubelet_identity" {
  description = "The `azurerm_kubernetes_cluster`'s `kubelet_identity` block."
  value       = module.aks.kubelet_identity
}

output "key_vault_id" {
  description = "Custom Key Vault ID"
  value       = try(module.key_vault[0].key_vault_id, "")
}

output "node_resource_group" {
  description = "The auto-generated Resource Group which contains the resources for this Managed Kubernetes Cluster."
  value       = module.aks.node_resource_group
}

output "location" {
  description = "The `azurerm_kubernetes_cluster`'s `location` argument. (Required) The location where the Managed Kubernetes Cluster should be created."
  value       = module.aks.location
}

output "network_profile" {
  description = "The `azurerm_kubernetes_cluster`'s `network_profile` block"
  value       = module.aks.network_profile
}

output "password" {
  description = "The `password` in the `azurerm_kubernetes_cluster`'s `kube_config` block. A password or token used to authenticate to the Kubernetes cluster."
  sensitive   = true
  value       = module.aks.password
}

output "username" {
  description = "The `username` in the `azurerm_kubernetes_cluster`'s `kube_config` block. A username used to authenticate to the Kubernetes cluster."
  sensitive   = true
  value       = module.aks.username
}

output "oidc_issuer_url" {
  description = "The OIDC issuer URL of the AKS cluster."
  value       = module.aks.oidc_issuer_url
}

output "private_cluster_dns_zone_id" {
  description = "ID of the private DNS zone for the private cluster. Created only for private cluster"
  value       = try(module.private_cluster_dns_zone[0].id, "")
}

output "private_cluster_dns_zone_name" {
  description = "Name of the private DNS zone for the private cluster. Created only for private cluster"
  value       = try(module.private_cluster_dns_zone[0].zone_name, "")
}

output "user_assigned_msi_object_id" {
  description = "The object ID of the user assigned managed identity."
  value       = try(module.cluster_identity[0].principal_id, "")
}

output "user_assigned_msi_client_id" {
  description = "The client ID of the user assigned managed identity."
  value       = try(module.cluster_identity[0].client_id, "")
}

output "additional_vnet_links" {
  description = "The additional VNet links on the DNS zone of private AKS cluster."
  value       = { for name, id in var.additional_vnet_links : name => module.vnet_links[name].id }
}

output "application_insights_id" {
  description = "Resource ID of the app insights instance"
  value       = length(module.application_insights) > 0 ? module.application_insights[0].id : null
}

output "monitor_private_link_scope_id" {
  description = "Resource ID of the monitor private link scope"
  value       = length(module.monitor_private_link_scope) > 0 ? module.monitor_private_link_scope[0].private_link_scope_id : null
}

output "monitor_private_link_scope_dns_zone_ids" {
  description = "Map of Resource IDs of the monitor private link scope DNS zones"
  value       = { for key, zone in module.monitor_private_link_scope_dns_zone : key => zone.id }
}

output "monitor_private_link_scope_private_endpoint_id" {
  description = "Resource ID of the monitor private link scope private endpoint"
  value       = length(module.monitor_private_link_scope_private_endpoint) > 0 ? module.monitor_private_link_scope_private_endpoint[0].id : null
}

output "prometheus_workspace_id" {
  description = "Resource ID of the Prometheus Monitor workspace"
  value       = length(module.prometheus_monitor_workspace) > 0 ? module.prometheus_monitor_workspace[0].id : null
}

output "prometheus_workspace_dns_zone_id" {
  description = "Resource ID of the Prometheus Monitor workspace DNS zone"
  value       = length(module.prometheus_monitor_workspace_private_dns_zone) > 0 ? module.prometheus_monitor_workspace_private_dns_zone[0].id : null
}

output "prometheus_workspace_private_endpoint_id" {
  description = "Resource ID of the Prometheus Monitor workspace private endpoint"
  value       = length(module.prometheus_monitor_workspace_private_endpoint) > 0 ? module.prometheus_monitor_workspace_private_endpoint[0].id : null
}

output "prometheus_data_collection_endpoint_id" {
  description = "Resource ID of the Prometheus Monitor data collection endpoint"
  value       = length(module.prometheus_monitor_data_collection) > 0 ? module.prometheus_monitor_data_collection[0].data_collection_endpoint_id : null
}

output "prometheus_data_collection_rule_id" {
  description = "Resource ID of the Prometheus Monitor data collection rule"
  value       = length(module.prometheus_monitor_data_collection) > 0 ? module.prometheus_monitor_data_collection[0].data_collection_rule_id : null
}
