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
  source  = "terraform.registry.launch.nttdata.com/module_library/resource_name/launch"
  version = "~> 2.0"

  for_each = var.resource_names_map

  logical_product_family  = var.product_family
  logical_product_service = var.product_service
  region                  = join("", split("-", var.region))
  class_env               = var.environment
  cloud_resource_type     = each.value.name
  instance_env            = var.environment_number
  instance_resource       = var.resource_number
  maximum_length          = each.value.max_length
  use_azure_region_abbr   = true

}

module "resource_group" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/resource_group/azurerm"
  version = "~> 1.0"

  count = var.resource_group_name != null ? 0 : 1

  location = var.region
  name     = module.resource_names["resource_group"].standard

  tags = merge(local.tags, { resource_name = module.resource_names["resource_group"].standard })
}

module "key_vault" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/key_vault/azurerm"
  version = "~> 1.0"

  count = var.create_key_vault ? 1 : 0

  resource_group = {
    name     = var.resource_group_name != null ? var.resource_group_name : module.resource_group[0].name
    location = var.region
  }
  key_vault_name             = var.key_vault_name != null ? var.key_vault_name : module.resource_names["key_vault"].minimal
  enable_rbac_authorization  = var.enable_rbac_authorization
  soft_delete_retention_days = var.kv_soft_delete_retention_days
  sku_name                   = var.kv_sku
  access_policies            = var.kv_access_policies
  certificates               = var.certificates
  secrets                    = var.secrets
  keys                       = var.keys

  custom_tags = merge(local.tags, { resource_name = module.resource_names["key_vault"].standard })

  depends_on = [module.resource_group]
}

# Assigns the Key Vault MSI Admin role on the Key Vault created above. This is required for the AKS nodes to access the Key Vault.
module "key_vault_role_assignment" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/role_assignment/azurerm"
  version = "~> 1.0"

  count = var.create_key_vault ? 1 : 0

  principal_id         = module.aks.key_vault_secrets_provider.secret_identity[0].object_id
  role_definition_name = var.key_vault_role_definition
  scope                = module.key_vault[0].key_vault_id

  depends_on = [module.aks, module.key_vault]
}

# The Key Vault MSI must be assigned Role to access the Key Vault from which AKS will retrieve the secrets.
module "additional_key_vaults_role_assignment" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/role_assignment/azurerm"
  version = "~> 1.0"

  for_each = toset(var.additional_key_vault_ids)

  principal_id         = module.aks.key_vault_secrets_provider.secret_identity[0].object_id
  role_definition_name = var.key_vault_role_definition
  scope                = each.key

  depends_on = [module.aks, module.key_vault]
}

# Create a user-assigned managed identity for the AKS cluster
module "cluster_identity" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/user_managed_identity/azurerm"
  version = "~> 1.0"

  count = var.identity_type == "UserAssigned" ? 1 : 0

  resource_group_name         = var.resource_group_name != null ? var.resource_group_name : module.resource_group[0].name
  location                    = var.region
  user_assigned_identity_name = module.resource_names["cluster_identity"].standard

  depends_on = [module.resource_group]
}

module "cluster_identity_roles" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/role_assignment/azurerm"
  version = "~> 1.0"

  for_each = var.identity_type == "UserAssigned" ? var.cluster_identity_role_assignments : {}

  principal_id         = module.cluster_identity[0].principal_id
  role_definition_name = each.value[0]
  scope                = each.value[1]

  depends_on = [module.cluster_identity, module.resource_group]
}

module "private_cluster_dns_zone" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/private_dns_zone/azurerm"
  version = "~> 1.0"

  count = var.private_cluster_enabled ? 1 : 0

  zone_name           = "${var.product_family}-${var.product_service}.private.${var.region}.${var.dns_zone_suffix}"
  resource_group_name = var.resource_group_name != null ? var.resource_group_name : module.resource_group[0].name

  tags = local.tags

  depends_on = [module.resource_group]
}

module "cluster_identity_private_dns_contributor" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/role_assignment/azurerm"
  version = "~> 1.0"

  count = var.identity_type == "UserAssigned" && var.private_cluster_enabled ? 1 : 0

  principal_id         = module.cluster_identity[0].principal_id
  role_definition_name = "Private DNS Zone Contributor"
  scope                = module.private_cluster_dns_zone[0].id

  depends_on = [module.cluster_identity, module.private_cluster_dns_zone]
}

module "vnet_links" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/private_dns_vnet_link/azurerm"
  version = "~> 1.0"

  for_each = var.private_cluster_enabled && length(var.additional_vnet_links) > 0 ? var.additional_vnet_links : {}

  link_name             = each.key
  resource_group_name   = var.resource_group_name != null ? var.resource_group_name : module.resource_group[0].name
  private_dns_zone_name = module.private_cluster_dns_zone[0].zone_name
  virtual_network_id    = each.value
  registration_enabled  = false

  tags = local.tags

  depends_on = [module.private_cluster_dns_zone, module.resource_group]
}

# Route table creation is required for user-defined routing
module "route_table" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/route_table/azurerm"
  version = "~> 1.0"

  count = var.net_profile_outbound_type == "userDefinedRouting" ? 1 : 0

  name                          = module.resource_names["route_table"].standard
  location                      = var.region
  disable_bgp_route_propagation = var.disable_bgp_route_propagation
  resource_group_name           = var.resource_group_name != null ? var.resource_group_name : module.resource_group[0].name
  tags = merge(local.tags, {
    resource_name = module.resource_names["route_table"].standard
  })

  depends_on = [module.resource_group]
}

# This is mandatory in case of `kubenet` network plugin
module "udr_route_table_role_assignment" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/role_assignment/azurerm"
  version = "~> 1.0"

  count = var.net_profile_outbound_type == "userDefinedRouting" ? 1 : 0
  # cluster identity
  principal_id         = module.cluster_identity[0].principal_id
  role_definition_name = "Contributor"
  scope                = module.route_table[0].id

  depends_on = [module.cluster_identity, module.route_table]
}

module "routes" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/route/azurerm"
  version = "~> 1.0"

  count = var.net_profile_outbound_type == "userDefinedRouting" ? 1 : 0

  routes = local.udr_routes

  depends_on = [module.route_table]
}

module "subnet_route_table_assoc" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/routetable_subnet_association/azurerm"
  version = "~> 1.0"

  for_each = var.net_profile_outbound_type == "userDefinedRouting" ? local.all_subnet_ids : []

  subnet_id      = each.value
  route_table_id = module.route_table[0].id
}

module "aks" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/kubernetes_cluster/azurerm"
  version = "~> 2.0"

  resource_group_name             = var.resource_group_name != null ? var.resource_group_name : module.resource_group[0].name
  location                        = var.region
  prefix                          = module.resource_names["aks"].dns_compliant_minimal
  network_plugin                  = var.network_plugin
  network_plugin_mode             = var.network_plugin_mode
  network_policy                  = var.network_policy
  open_service_mesh_enabled       = var.open_service_mesh_enabled
  identity_type                   = var.identity_type
  identity_ids                    = var.identity_type == "UserAssigned" ? concat([module.cluster_identity[0].id], var.identity_ids) : null
  kubernetes_version              = var.kubernetes_version
  cluster_name                    = module.resource_names["aks"].dns_compliant_minimal
  api_server_subnet_id            = var.api_server_subnet_id
  api_server_authorized_ip_ranges = var.api_server_authorized_ip_ranges
  azure_policy_enabled            = var.azure_policy_enabled

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
  private_dns_zone_id                 = var.private_cluster_enabled ? module.private_cluster_dns_zone[0].id : null
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

  green_field_application_gateway_for_ingress = var.green_field_application_gateway_for_ingress != null ? merge(
    {
      name = module.resource_names["application_gateway"].dns_compliant_minimal
    },
    var.green_field_application_gateway_for_ingress,
  ) : null
  brown_field_application_gateway_for_ingress = var.brown_field_application_gateway_for_ingress

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

  # Log analytics
  cluster_log_analytics_workspace_name                            = var.cluster_log_analytics_workspace_name
  log_analytics_workspace                                         = var.log_analytics_workspace
  log_analytics_workspace_allow_resource_only_permissions         = var.log_analytics_workspace_allow_resource_only_permissions
  log_analytics_workspace_cmk_for_query_forced                    = var.log_analytics_workspace_cmk_for_query_forced
  log_analytics_workspace_daily_quota_gb                          = var.log_analytics_workspace_daily_quota_gb
  log_analytics_workspace_data_collection_rule_id                 = var.log_analytics_workspace_data_collection_rule_id
  log_analytics_workspace_enabled                                 = var.log_analytics_workspace_enabled
  log_analytics_workspace_resource_group_name                     = var.log_analytics_workspace_resource_group_name
  log_analytics_workspace_sku                                     = var.log_analytics_workspace_sku
  log_analytics_workspace_identity                                = var.log_analytics_workspace_identity
  log_analytics_workspace_immediate_data_purge_on_30_days_enabled = var.log_analytics_workspace_immediate_data_purge_on_30_days_enabled
  log_analytics_workspace_internet_ingestion_enabled              = var.log_analytics_workspace_internet_ingestion_enabled
  log_analytics_workspace_internet_query_enabled                  = var.log_analytics_workspace_internet_query_enabled
  log_analytics_workspace_local_authentication_disabled           = var.log_analytics_workspace_local_authentication_disabled
  log_analytics_workspace_reservation_capacity_in_gb_per_day      = var.log_analytics_workspace_reservation_capacity_in_gb_per_day

  log_retention_in_days = var.log_retention_in_days

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

  depends_on = [module.resource_group, module.subnet_route_table_assoc, module.cluster_identity_private_dns_contributor]
}

module "node_pool_identity_roles" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/role_assignment/azurerm"
  version = "~> 1.0"

  for_each = var.node_pool_identity_role_assignments

  principal_id         = module.aks.kubelet_identity[0].object_id
  role_definition_name = each.value[0]
  scope                = each.value[1]

  depends_on = [module.aks, module.resource_group]
}

module "additional_acr_role_assignments" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/role_assignment/azurerm"
  version = "~> 1.0"

  for_each = toset(var.container_registry_ids)

  principal_id         = module.aks.kubelet_identity[0].object_id
  role_definition_name = "AcrPull"
  scope                = each.key
}

module "public_dns_zone" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/dns_zone/azurerm"
  version = "~> 1.0"

  count = var.public_dns_zone_name != null ? 1 : 0

  domain_names        = [var.public_dns_zone_name]
  resource_group_name = var.resource_group_name != null ? var.resource_group_name : module.resource_group[0].name
  resource_name_tag   = module.resource_names["public_dns_zone"].standard
  tags                = local.tags

  depends_on = [module.resource_group]
}

module "cluster_identity_public_dns_contributor" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/role_assignment/azurerm"
  version = "~> 1.0"

  count = (var.identity_type == "UserAssigned" && var.public_dns_zone_name != null) ? 1 : 0

  principal_id         = module.cluster_identity[0].principal_id
  role_definition_name = "DNS Zone Contributor"
  scope                = module.public_dns_zone[0].ids[0]

  depends_on = [module.cluster_identity, module.public_dns_zone]
}

module "application_insights" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/application_insights/azurerm"
  version = "~> 1.0"

  count = var.create_application_insights ? 1 : 0

  name                                  = module.resource_names["application_insights"].standard
  resource_group_name                   = var.resource_group_name != null ? var.resource_group_name : module.resource_group[0].name
  location                              = var.region
  application_type                      = var.application_insights.application_type
  retention_in_days                     = var.application_insights.retention_in_days
  daily_data_cap_in_gb                  = var.application_insights.daily_data_cap_in_gb
  daily_data_cap_notifications_disabled = var.application_insights.daily_data_cap_notifications_disabled
  sampling_percentage                   = var.application_insights.sampling_percentage
  disable_ip_masking                    = var.application_insights.disabling_ip_masking
  workspace_id                          = module.aks.azurerm_log_analytics_workspace_id
  local_authentication_disabled         = var.application_insights.local_authentication_disabled
  internet_ingestion_enabled            = var.application_insights.internet_ingestion_enabled
  internet_query_enabled                = var.application_insights.internet_query_enabled
  force_customer_storage_for_profiler   = var.application_insights.force_customer_storage_for_profiler

  tags = merge(local.tags, {
    resource_name = module.resource_names["application_insights"].standard
  })
}

module "prometheus_monitor_workspace" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/monitor_workspace/azurerm"
  version = "~> 1.0"

  count = var.enable_prometheus_monitoring && var.brown_field_prometheus_monitor_workspace_id == null ? 1 : 0

  name                = module.resource_names["prometheus_monitor_workspace"].standard
  resource_group_name = var.resource_group_name != null ? var.resource_group_name : module.resource_group[0].name
  location            = var.region

  public_network_access_enabled = var.prometheus_workspace_public_access_enabled

  tags = merge(var.tags, { resource_name = module.resource_names["prometheus_monitor_workspace"].standard })
}

module "prometheus_monitor_data_collection" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/monitor_prometheus/azurerm"
  version = "~> 1.0"

  count = var.enable_prometheus_monitoring ? 1 : 0

  resource_group_name = var.resource_group_name != null ? var.resource_group_name : module.resource_group[0].name
  location            = var.region

  enable_default_rule_groups  = var.prometheus_enable_default_rule_groups
  default_rule_group_naming   = var.prometheus_default_rule_group_naming
  default_rule_group_interval = var.prometheus_default_rule_group_interval
  rule_groups                 = var.prometheus_rule_groups

  monitor_workspace_id = var.brown_field_prometheus_monitor_workspace_id != null ? var.brown_field_prometheus_monitor_workspace_id : module.prometheus_monitor_workspace[0].id

  aks_cluster_id = module.aks.aks_id

  data_collection_endpoint_name = module.resource_names["prometheus_data_collection_endpoint"].standard
  data_collection_rule_name     = module.resource_names["prometheus_data_collection_rule"].standard
}

module "prometheus_monitor_workspace_private_dns_zone" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/private_dns_zone/azurerm"
  version = "~> 1.0"

  count = var.enable_prometheus_monitoring && var.enable_prometheus_monitoring_private_endpoint ? 1 : 0

  zone_name           = replace(module.prometheus_monitor_workspace[0].query_endpoint, "/https:\\/\\/.*?\\.(.*)/", "privatelink.$1")
  resource_group_name = var.resource_group_name != null ? var.resource_group_name : module.resource_group[0].name

  tags = local.tags

  depends_on = [module.resource_group, module.prometheus_monitor_workspace]
}

module "prometheus_monitor_workspace_vnet_link" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/private_dns_vnet_link/azurerm"
  version = "~> 1.0"

  count = var.enable_prometheus_monitoring && var.enable_prometheus_monitoring_private_endpoint ? 1 : 0

  link_name             = module.prometheus_monitor_workspace[0].name
  resource_group_name   = var.resource_group_name != null ? var.resource_group_name : module.resource_group[0].name
  private_dns_zone_name = module.prometheus_monitor_workspace_private_dns_zone[0].zone_name
  virtual_network_id    = join("/", slice(split("/", var.vnet_subnet_id), 0, 9))
  registration_enabled  = false

  tags = local.tags

  depends_on = [module.resource_group, module.prometheus_monitor_workspace_private_dns_zone]
}

module "prometheus_monitor_workspace_private_endpoint" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/private_endpoint/azurerm"
  version = "~> 1.0"

  count = var.enable_prometheus_monitoring && var.enable_prometheus_monitoring_private_endpoint ? 1 : 0

  region                          = var.region
  endpoint_name                   = module.resource_names["prometheus_endpoint"].standard
  is_manual_connection            = false
  resource_group_name             = var.resource_group_name != null ? var.resource_group_name : module.resource_group[0].name
  private_service_connection_name = module.resource_names["prometheus_service_connection"].standard
  private_connection_resource_id  = module.prometheus_monitor_workspace[0].id
  subresource_names               = ["prometheusMetrics"]
  subnet_id                       = var.prometheus_monitoring_private_endpoint_subnet_id
  private_dns_zone_ids            = [module.prometheus_monitor_workspace_private_dns_zone[0].id]
  private_dns_zone_group_name     = "prometheusMetrics"

  tags = merge(var.tags, { resource_name = module.resource_names["prometheus_endpoint"].standard })

  depends_on = [module.resource_group, module.prometheus_monitor_workspace, module.prometheus_monitor_workspace_private_dns_zone]
}

module "monitor_private_link_scope" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/azure_monitor_private_link_scope/azurerm"
  version = "~> 1.0"

  count = var.create_monitor_private_link_scope ? 1 : 0

  name                = module.resource_names["monitor_private_link_scope"].standard
  resource_group_name = var.resource_group_name != null ? var.resource_group_name : module.resource_group[0].name

  tags = merge(local.tags, {
    resource_name = module.resource_names["monitor_private_link_scope"].standard
  })

  linked_resource_ids = { for key, resource in local.monitor_private_link_scoped_resources : resource.name => resource.id }

  depends_on = [module.resource_group, module.aks, module.application_insights, module.prometheus_monitor_workspace, module.prometheus_monitor_data_collection]
}

module "monitor_private_link_scope_dns_zone" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/private_dns_zone/azurerm"
  version = "~> 1.0"

  for_each = var.create_monitor_private_link_scope ? var.monitor_private_link_scope_dns_zone_suffixes : toset([])

  zone_name           = each.key
  resource_group_name = var.resource_group_name != null ? var.resource_group_name : module.resource_group[0].name

  tags = local.tags

  depends_on = [module.resource_group]
}

module "monitor_private_link_scope_vnet_link" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/private_dns_vnet_link/azurerm"
  version = "~> 1.0"

  for_each = var.create_monitor_private_link_scope ? var.monitor_private_link_scope_dns_zone_suffixes : toset([])

  link_name             = replace(each.key, ".", "-")
  resource_group_name   = var.resource_group_name != null ? var.resource_group_name : module.resource_group[0].name
  private_dns_zone_name = module.monitor_private_link_scope_dns_zone[each.key].zone_name
  virtual_network_id    = join("/", slice(split("/", var.vnet_subnet_id), 0, 9))
  registration_enabled  = false

  tags = local.tags

  depends_on = [module.resource_group, module.monitor_private_link_scope_dns_zone]
}

module "monitor_private_link_scope_private_endpoint" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/private_endpoint/azurerm"
  version = "~> 1.0"

  count = var.create_monitor_private_link_scope ? 1 : 0

  region                          = var.region
  endpoint_name                   = module.resource_names["monitor_private_link_scope_endpoint"].standard
  is_manual_connection            = false
  resource_group_name             = var.resource_group_name != null ? var.resource_group_name : module.resource_group[0].name
  private_service_connection_name = module.resource_names["monitor_private_link_scope_service_connection"].standard
  private_connection_resource_id  = module.monitor_private_link_scope[0].private_link_scope_id
  subresource_names               = ["azuremonitor"]
  subnet_id                       = var.monitor_private_link_scope_subnet_id
  private_dns_zone_ids            = [for zone in module.monitor_private_link_scope_dns_zone : zone.id]
  private_dns_zone_group_name     = "azuremonitor"

  tags = merge(var.tags, { resource_name = module.resource_names["monitor_private_link_scope_endpoint"].standard })

  depends_on = [module.resource_group, module.monitor_private_link_scope, module.monitor_private_link_scope_dns_zone]
}

module "monitor_private_link_scoped_service" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/monitor_private_link_scoped_service/azurerm"
  version = "~> 1.0"

  for_each = var.brown_field_monitor_private_link_scope_id != null ? local.monitor_private_link_scoped_resources : {}

  monitor_private_link_scope_id = var.brown_field_monitor_private_link_scope_id

  name        = each.value.name
  resource_id = each.value.id
}
