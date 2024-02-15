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
provider "random" {
}

resource "random_integer" "random_int" {
  max = 9999
  min = 1000
}

resource "random_password" "password" {
  length = 10
}

module "resource_names" {
  source = "git::https://github.com/nexient-llc/tf-module-resource_name.git?ref=1.1.0"

  for_each = var.resource_names_map

  logical_product_family  = var.product_family
  logical_product_service = var.product_service
  region                  = var.region
  class_env               = var.environment
  cloud_resource_type     = each.value.name
  instance_env            = var.environment_number
  maximum_length          = each.value.max_length
}

module "resource_group" {
  source = "git::https://github.com/nexient-llc/tf-azurerm-module_primitive-resource_group.git?ref=0.2.0"

  name     = module.resource_names["rg"].standard
  location = var.region

  tags = merge(var.tags, { resource_name = module.resource_names["rg"].standard })

}

module "user_identity" {
  source = "git::https://github.com/nexient-llc/tf-azurerm-module_primitive-user_managed_identity.git?ref=0.1.0"

  resource_group_name         = module.resource_group.name
  location                    = var.region
  user_assigned_identity_name = module.resource_names["msi"].standard

  depends_on = [module.resource_group]
}

# This role assignment is required for AKS to access the VNet network
module "rg_role_assignment" {
  source = "git::https://github.com/nexient-llc/tf-azurerm-module_primitive-role_assignment.git?ref=0.1.0"

  scope                = module.resource_group.id
  role_definition_name = "Contributor"
  principal_id         = module.user_identity.principal_id

  depends_on = [module.resource_group, module.user_identity]
}

module "vnet" {
  source = "git::https://github.com/nexient-llc/tf-azurerm-module_primitive-virtual_network.git?ref=0.1.0"

  resource_group_name                                   = module.resource_group.name
  vnet_name                                             = module.resource_names["vnet"].standard
  vnet_location                                         = var.region
  address_space                                         = var.address_space
  subnet_names                                          = var.subnet_names
  subnet_prefixes                                       = var.subnet_prefixes
  bgp_community                                         = null
  ddos_protection_plan                                  = null
  dns_servers                                           = []
  nsg_ids                                               = {}
  route_tables_ids                                      = {}
  subnet_delegation                                     = {}
  subnet_enforce_private_link_endpoint_network_policies = {}
  subnet_enforce_private_link_service_network_policies  = {}
  subnet_service_endpoints                              = {}
  tags                                                  = merge(var.tags, { resource_name = module.resource_names["vnet"].standard })
  tracing_tags_enabled                                  = false
  tracing_tags_prefix                                   = ""
  use_for_each                                          = true


  depends_on = [module.resource_group]
}

module "aks" {
  source = "../.."

  product_family     = var.product_family
  product_service    = var.product_service
  environment        = var.environment
  environment_number = var.environment_number

  region = var.region

  resource_group_name = module.resource_group.name

  private_cluster_enabled = var.private_cluster_enabled
  # Private DNS is managed by Azure
  private_dns_zone_id = var.private_dns_zone_id

  kubernetes_version        = var.kubernetes_version
  network_plugin            = var.network_plugin
  agents_count              = var.agents_count
  agents_availability_zones = var.agents_availability_zones
  agents_size               = var.agents_size
  agents_pool_name          = var.agents_pool_name
  os_disk_size_gb           = var.os_disk_size_gb

  key_vault_secrets_provider_enabled = var.key_vault_secrets_provider_enabled
  secret_rotation_enabled            = var.secret_rotation_enabled
  secret_rotation_interval           = var.secret_rotation_interval
  node_pools = {
    apppool1 = {
      name       = "apppool1"
      node_count = 1
      tags = {
        application = "App1"
      }
      vm_size = "Standard_D2_v2"
      mode    = "User"
      node_labels = {
        application = "App1"
      }
      os_sku         = "Ubuntu"
      os_type        = "Linux"
      vnet_subnet_id = module.vnet.vnet_subnets_name_id["subnet-app-pool-1"]
    }
  }

  secrets = {
    username = "test102"
    password = random_password.password.result
  }

  # The below is currently on preview EnableAPIServerVnetIntegrationPreview
  # api_server_subnet_id = module.vnet.vnet_subnets_name_id["subnet-api-server"]
  vnet_subnet_id             = module.vnet.vnet_subnets_name_id["subnet-default-pool"]
  net_profile_outbound_type  = var.net_profile_outbound_type
  net_profile_dns_service_ip = var.net_profile_dns_service_ip
  net_profile_service_cidr   = var.net_profile_service_cidr
  net_profile_pod_cidr       = var.net_profile_pod_cidr

  identity_type = var.identity_type
  identity_ids  = [module.user_identity.id]

  tags = var.tags

  depends_on = [module.vnet, module.user_identity]

}
