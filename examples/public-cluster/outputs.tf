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

output "cluster_name" {
  value = module.aks.cluster_name
}

output "resource_group_name" {
  value = module.aks.resource_group_name
}

output "application_gateway_id" {
  value = module.aks.application_gateway_id
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
  description = "The RG of the default node pool"
  value       = module.aks.node_resource_group
}
