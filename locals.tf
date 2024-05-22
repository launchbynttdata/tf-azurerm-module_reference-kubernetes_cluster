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

  vnet_id           = var.vnet_subnet_id != null ? join("/", slice(split("/", var.vnet_subnet_id), 0, 9)) : null
  resource_group_id = var.resource_group_name != null ? data.azurerm_resource_group.rg[0].id : module.resource_group[0].id

  vnet_role_assignment = local.vnet_id != null ? {
    "vnet" = ["Network Contributor", local.vnet_id]
  } : {}

  cluster_identity_role_assignments = var.identity_type == "UserAssigned" ? merge({
    "rg" = ["Contributor", local.resource_group_id]
  }, local.vnet_role_assignment, var.cluster_identity_role_assignments) : var.cluster_identity_role_assignments

  # A route is mandatory for all outbound traffic to a next hop type of VirtualAppliance to an Azure Firewall in this case
  udr_outbound_route = var.net_profile_outbound_type == "userDefinedRouting" ? {
    name                   = "all-traffic"
    resource_group_name    = var.resource_group_name != null ? var.resource_group_name : module.resource_group[0].name
    route_table_name       = module.route_table[0].name
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = try(var.user_defined_routing.azure_firewall_private_ip_address, null)
  } : {}

  udr_routes = {
    all-traffic = local.udr_outbound_route
  }

  # The same route table needs to be associated with all subnets associated with node pools
  node_pool_subnet_ids = [for pool in keys(var.node_pools) : var.node_pools[pool].vnet_subnet_id]
  all_subnet_ids       = toset(concat([var.vnet_subnet_id], local.node_pool_subnet_ids))

  tags = merge(local.default_tags, var.tags)
}
