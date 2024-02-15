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
  value     = module.aks.kube_config_raw
  sensitive = true
}

output "kube_admin_config_raw" {
  value     = module.aks.kube_admin_config_raw
  sensitive = true
}

output "cluster_name" {
  value = module.aks.cluster_name
}

output "cluster_id" {
  value = module.aks.cluster_id
}

output "cluster_fqdn" {
  value = module.aks.cluster_fqdn
}

output "cluster_portal_fqdn" {
  value = module.aks.cluster_portal_fqdn
}

output "cluster_private_fqdn" {
  value = module.aks.cluster_private_fqdn
}

output "host" {
  value     = module.aks.host
  sensitive = true
}

output "username" {
  value     = module.aks.username
  sensitive = true
}

output "password" {
  value     = module.aks.password
  sensitive = true
}

output "admin_host" {
  value     = module.aks.admin_host
  sensitive = true
}

output "admin_username" {
  value     = module.aks.admin_username
  sensitive = true
}

output "admin_password" {
  value     = module.aks.admin_password
  sensitive = true
}

output "resource_group_name" {
  value = module.aks.resource_group_name
}

output "key_vault_secrets_provider" {
  description = "The `azurerm_kubernetes_cluster`'s `key_vault_secrets_provider` block."
  value       = module.aks.key_vault_secrets_provider
}

output "key_vault_id" {
  description = "Key Vault ID"
  value       = module.aks.key_vault_id
}

output "cluster_identity" {
  value = module.aks.cluster_identity
}

output "kubelet_identity" {
  description = "The `azurerm_kubernetes_cluster`'s `kubelet_identity` block."
  value       = module.aks.kubelet_identity
}

output "node_resource_group" {
  description = "The auto-generated Resource Group which contains the resources for this Managed Kubernetes Cluster."
  value       = module.aks.node_resource_group
}
