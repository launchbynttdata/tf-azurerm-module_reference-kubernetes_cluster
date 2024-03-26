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

module "resource_names" {
  source = "git::https://github.com/launchbynttdata/tf-launch-module_library-resource_name.git?ref=1.0.0"

  for_each = var.resource_names_map

  logical_product_family  = var.product_family
  logical_product_service = var.product_service
  region                  = join("", split("-", var.region))
  class_env               = var.environment
  cloud_resource_type     = each.value.name
  instance_env            = var.environment_number
  instance_resource       = var.resource_number
  maximum_length          = each.value.max_length
}

module "resource_group" {
  source = "git::https://github.com/launchbynttdata/tf-azurerm-module_primitive-resource_group.git?ref=1.0.0"

  count = var.resource_group_name != null ? 0 : 1

  location = var.region
  name     = module.resource_names["resource_group"].standard

  tags = merge(local.tags, { resource_name = module.resource_names["resource_group"].standard })
}

module "key_vault" {
  source = "git::https://github.com/launchbynttdata/tf-azurerm-module_primitive-key_vault.git?ref=1.0.0"

  count = var.key_vault_secrets_provider_enabled ? 1 : 0

  resource_group = {
    name     = var.resource_group_name != null ? var.resource_group_name : module.resource_group[0].name
    location = var.region
  }
  key_vault_name             = module.resource_names["key_vault"].minimal_random_suffix
  enable_rbac_authorization  = var.enable_rbac_authorization
  soft_delete_retention_days = var.kv_soft_delete_retention_days
  sku_name                   = var.kv_sku
  access_policies            = var.kv_access_policies
  certificates               = var.certificates
  secrets                    = var.secrets
  keys                       = var.keys

  custom_tags = local.tags

  depends_on = [module.resource_group]
}

# Assigns the Key Vault MSI Admin role on the Key Vault created above. This is required for the AKS nodes to access the Key Vault.
module "key_vault_role_assignment" {
  source = "git::https://github.com/launchbynttdata/tf-azurerm-module_primitive-role_assignment.git?ref=1.0.0"

  count = var.key_vault_secrets_provider_enabled ? 1 : 0

  principal_id         = module.aks.key_vault_secrets_provider.secret_identity[0].object_id
  role_definition_name = var.key_vault_role_definition
  scope                = module.key_vault[0].key_vault_id

  depends_on = [module.aks, module.key_vault]
}

module "aks" {
  source = "git::https://github.com/launchbynttdata/tf-azurerm-module_primitive-kubernetes_cluster.git?ref=1.0.0"

  resource_group_name             = var.resource_group_name != null ? var.resource_group_name : module.resource_group[0].name
  location                        = var.region
  prefix                          = module.resource_names["aks"].dns_compliant_minimal
  network_plugin                  = var.network_plugin
  network_plugin_mode             = var.network_plugin_mode
  network_policy                  = var.network_policy
  open_service_mesh_enabled       = var.open_service_mesh_enabled
  identity_type                   = var.identity_type
  identity_ids                    = var.identity_ids
  kubernetes_version              = var.kubernetes_version
  cluster_name                    = module.resource_names["aks"].dns_compliant_minimal
  api_server_subnet_id            = var.api_server_subnet_id
  api_server_authorized_ip_ranges = var.api_server_authorized_ip_ranges

  # Auto scaling
  enable_auto_scaling                                  = var.enable_auto_scaling
  auto_scaler_profile_enabled                          = var.auto_scaler_profile_enabled
  auto_scaler_profile_balance_similar_node_groups      = var.auto_scaler_profile_balance_similar_node_groups
  auto_scaler_profile_empty_bulk_delete_max            = var.auto_scaler_profile_empty_bulk_delete_max
  auto_scaler_profile_expander                         = var.auto_scaler_profile_expander
  auto_scaler_profile_max_graceful_termination_sec     = var.auto_scaler_profile_max_graceful_termination_sec
  auto_scaler_profile_max_node_provisioning_time       = var.auto_scaler_profile_max_node_provisioning_time
  auto_scaler_profile_max_unready_nodes                = var.auto_scaler_profile_max_unready_nodes
  auto_scaler_profile_max_unready_percentage           = var.auto_scaler_profile_max_unready_percentage
  auto_scaler_profile_new_pod_scale_up_delay           = var.auto_scaler_profile_new_pod_scale_up_delay
  auto_scaler_profile_scale_down_delay_after_add       = var.auto_scaler_profile_scale_down_delay_after_add
  auto_scaler_profile_scale_down_delay_after_delete    = var.auto_scaler_profile_scale_down_delay_after_delete
  auto_scaler_profile_scale_down_delay_after_failure   = var.auto_scaler_profile_scale_down_delay_after_failure
  auto_scaler_profile_scale_down_unneeded              = var.auto_scaler_profile_scale_down_unneeded
  auto_scaler_profile_scale_down_unready               = var.auto_scaler_profile_scale_down_unready
  auto_scaler_profile_scale_down_utilization_threshold = var.auto_scaler_profile_scale_down_utilization_threshold
  auto_scaler_profile_scan_interval                    = var.auto_scaler_profile_scan_interval
  auto_scaler_profile_skip_nodes_with_local_storage    = var.auto_scaler_profile_skip_nodes_with_local_storage
  auto_scaler_profile_skip_nodes_with_system_pods      = var.auto_scaler_profile_skip_nodes_with_system_pods

  # Private cluster configuration
  private_cluster_enabled             = var.private_cluster_enabled
  private_cluster_public_fqdn_enabled = var.private_cluster_public_fqdn_enabled
  private_dns_zone_id                 = var.private_dns_zone_id
  vnet_subnet_id                      = var.vnet_subnet_id
  pod_subnet_id                       = var.pod_subnet_id
  net_profile_outbound_type           = var.net_profile_outbound_type
  net_profile_dns_service_ip          = var.net_profile_dns_service_ip
  net_profile_service_cidr            = var.net_profile_service_cidr
  net_profile_pod_cidr                = var.net_profile_pod_cidr

  agents_pool_name             = var.agents_pool_name
  agents_count                 = var.agents_count
  agents_availability_zones    = var.agents_availability_zones
  agents_size                  = var.agents_size
  agents_labels                = var.agents_labels
  agents_tags                  = var.agents_tags
  agents_type                  = var.agents_type
  agents_taints                = var.agents_taints
  agents_pool_max_surge        = var.agents_pool_max_surge
  agents_max_count             = var.agents_max_count
  agents_min_count             = var.agents_min_count
  agents_max_pods              = var.agents_max_pods
  agents_pool_linux_os_configs = var.agents_pool_linux_os_configs

  os_disk_size_gb = var.os_disk_size_gb
  os_disk_type    = var.os_disk_type
  os_sku          = var.os_sku
  sku_tier        = var.sku_tier

  node_pools          = var.node_pools
  node_resource_group = var.node_resource_group

  ingress_application_gateway_enabled     = var.ingress_application_gateway_enabled
  ingress_application_gateway_name        = var.ingress_application_gateway_enabled ? module.resource_names["application_gateway"].dns_compliant_minimal : null
  ingress_application_gateway_subnet_cidr = var.ingress_application_gateway_subnet_cidr
  ingress_application_gateway_id          = var.ingress_application_gateway_id
  ingress_application_gateway_subnet_id   = var.ingress_application_gateway_subnet_id

  web_app_routing     = var.web_app_routing
  attached_acr_id_map = var.attached_acr_id_map

  key_vault_secrets_provider_enabled = var.key_vault_secrets_provider_enabled
  secret_rotation_enabled            = var.secret_rotation_enabled
  secret_rotation_interval           = var.secret_rotation_interval

  # Azure AD integration
  role_based_access_control_enabled = var.role_based_access_control_enabled
  rbac_aad                          = var.rbac_aad
  rbac_aad_managed                  = var.rbac_aad_managed
  rbac_aad_azure_rbac_enabled       = var.rbac_aad_azure_rbac_enabled
  rbac_aad_tenant_id                = var.rbac_aad_tenant_id
  rbac_aad_admin_group_object_ids   = var.rbac_aad_admin_group_object_ids
  rbac_aad_client_app_id            = var.rbac_aad_client_app_id
  rbac_aad_server_app_id            = var.rbac_aad_server_app_id
  rbac_aad_server_app_secret        = var.rbac_aad_server_app_secret
  local_account_disabled            = var.local_account_disabled

  oidc_issuer_enabled       = var.oidc_issuer_enabled
  workload_identity_enabled = var.workload_identity_enabled

  # Service Principal
  client_id     = var.client_id
  client_secret = var.client_secret

  monitor_metrics = var.monitor_metrics

  agents_proximity_placement_group_id = var.agents_proximity_placement_group_id

  tags = merge(local.tags, {
    resource_name = module.resource_names["aks"].standard
  })

  depends_on = [module.resource_group]
}

module "acr" {
  source = "git::https://github.com/launchbynttdata/tf-azurerm-module_primitive-container_registry.git?ref=1.0.0"

  count = var.container_registry != null ? 1 : 0

  resource_group_name     = var.resource_group_name != null ? var.resource_group_name : module.resource_group[0].name
  location                = var.region
  container_registry_name = length(var.container_registry.name) > 0 ? var.container_registry.name : module.resource_names["acr"].lower_case
  container_registry = {
    sku           = lookup(var.container_registry, "sku", "Basic")
    admin_enabled = lookup(var.container_registry, "admin_enabled", false)
  }
  retention_policy = var.container_registry.retention_policy_days == 0 ? null : {
    days    = var.container_registry.retention_policy_days
    enabled = true
  }

  tags = merge(local.tags, { resource_name = module.resource_names["acr"].standard })
}

module "acr_role_assignment" {
  source = "git::https://github.com/launchbynttdata/tf-azurerm-module_primitive-role_assignment.git?ref=1.0.0"

  count = var.container_registry != null ? 1 : 0

  principal_id         = module.aks.kubelet_identity[0].object_id
  role_definition_name = "AcrPull"
  scope                = module.acr[0].container_registry_id
}

module "additional_acr_role_assignments" {
  source = "git::https://github.com/launchbynttdata/tf-azurerm-module_primitive-role_assignment.git?ref=1.0.0"

  for_each = toset(var.container_registry_ids)

  principal_id         = module.aks.kubelet_identity[0].object_id
  role_definition_name = "AcrPull"
  scope                = each.key
}
