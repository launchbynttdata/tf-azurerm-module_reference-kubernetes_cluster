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

locals {
  default_tags = {
    provisioner = "Terraform"
  }

  # A route is mandatory for all outbound traffic to a next hop type of VirtualAppliance to an Azure Firewall in this case
  udr_outbound_route = var.net_profile_outbound_type == "userDefinedRouting" ? {
    name                   = "all-traffic"
    resource_group_name    = var.resource_group_name != null ? var.resource_group_name : module.resource_group[0].name
    route_table_name       = module.route_table[0].name
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = try(var.user_defined_routing.azure_firewall_private_ip_address, null)
  } : {}

  monitor_private_link_scoped_resources = merge(
    {
      aks_log_analytics_workspace = {
        id   = module.aks.azurerm_log_analytics_workspace_id
        name = module.aks.azurerm_log_analytics_workspace_name
      }
    },
    length(module.application_insights) > 0 ? {
      application_insights = {
        id   = module.application_insights[0].id
        name = module.application_insights[0].name
      }
    } : {},
    length(module.prometheus_monitor_workspace) > 0 ? {
      prometheus_monitor_workspace = {
        id   = module.prometheus_monitor_workspace[0].default_data_collection_endpoint_id
        name = module.prometheus_monitor_workspace[0].name
      }
    } : {},
    length(module.prometheus_monitor_data_collection) > 0 ? {
      prometheus_monitor_data_collection = {
        id   = module.prometheus_monitor_data_collection[0].data_collection_endpoint_id
        name = module.prometheus_monitor_data_collection[0].data_collection_endpoint_name
      }
    } : {}
  )

  udr_routes = {
    all-traffic = local.udr_outbound_route
  }

  # The same route table needs to be associated with all subnets associated with node pools
  node_pool_subnet_ids = [for pool in keys(var.node_pools) : var.node_pools[pool].vnet_subnet_id]
  all_subnet_ids       = toset(concat([var.vnet_subnet_id], local.node_pool_subnet_ids))

  # Backward-compatible role model: prefer explicit multiple roles, else fallback to single role input.
  key_vault_role_definitions_effective = distinct(
    length(var.key_vault_role_definitions) > 0 ? var.key_vault_role_definitions : [var.key_vault_role_definition]
  )

  # Preserve legacy state addresses for the first role to avoid destroy/recreate on upgrade.
  key_vault_primary_role_definition     = local.key_vault_role_definitions_effective[0]
  key_vault_additional_role_definitions = slice(local.key_vault_role_definitions_effective, 1, length(local.key_vault_role_definitions_effective))

  additional_key_vault_role_assignments_effective = merge(
    {
      for key_vault_id in var.additional_key_vault_ids : key_vault_id => {
        scope                = key_vault_id
        role_definition_name = local.key_vault_primary_role_definition
      }
    },
    {
      for pair in setproduct(var.additional_key_vault_ids, local.key_vault_additional_role_definitions) :
      "${pair[0]}|${pair[1]}" => {
        scope                = pair[0]
        role_definition_name = pair[1]
      }
    }
  )

  tags = merge(local.default_tags, var.tags)
}
