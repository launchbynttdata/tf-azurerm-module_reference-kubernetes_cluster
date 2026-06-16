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

  tags = merge(local.default_tags, var.tags)

  # Backward-compatible merge of singular and plural public DNS zone inputs.
  public_dns_zone_names = distinct(concat(
    var.public_dns_zone_name != null ? [var.public_dns_zone_name] : [],
    var.public_dns_zone_names,
  ))

  public_dns_zone_ids = length(module.public_dns_zone) > 0 ? zipmap(
    sort(local.public_dns_zone_names),
    module.public_dns_zone[0].ids,
  ) : {}

  public_dns_zone_name_servers = length(module.public_dns_zone) > 0 ? zipmap(
    sort(local.public_dns_zone_names),
    module.public_dns_zone[0].name_servers,
  ) : {}

  public_dns_ns_records = {
    for child_zone_name, delegation in var.public_dns_zone_delegations :
    child_zone_name => {
      name                = trimsuffix(child_zone_name, ".${delegation.parent_zone_name}")
      resource_group_name = delegation.parent_zone_resource_group_name
      zone_name           = delegation.parent_zone_name
      ttl                 = delegation.ttl
      records             = local.public_dns_zone_name_servers[child_zone_name]
      tags                = var.tags
    }
    if contains(local.public_dns_zone_names, child_zone_name)
  }

  public_dns_a_records = {
    for zone_name, record in var.public_dns_zone_root_a_records :
    zone_name => {
      name                = record.record_name
      resource_group_name = record.resource_group_name
      zone_name           = zone_name
      ttl                 = record.ttl
      records             = record.records
      tags                = var.tags
    }
    if contains(local.public_dns_zone_names, zone_name)
  }
}
