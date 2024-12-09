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
  source  = "terraform.registry.launch.nttdata.com/module_library/resource_name/launch"
  version = "~> 1.0"

  for_each = var.resource_names_map

  logical_product_family  = var.product_family
  logical_product_service = var.product_service
  region                  = var.region
  class_env               = var.environment
  cloud_resource_type     = each.value.name
  instance_env            = var.environment_number
  maximum_length          = each.value.max_length
  use_azure_region_abbr   = true
}

module "resource_group" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/resource_group/azurerm"
  version = "~> 1.0"

  name     = module.resource_names["rg"].standard
  location = var.region

  tags = merge(var.tags, { resource_name = module.resource_names["rg"].standard })

}

module "vnet" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/virtual_network/azurerm"
  version = "~> 1.0"

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

# wait some time before cleaning up the vnet
resource "time_sleep" "wait_after_destroy" {
  destroy_duration = var.time_to_wait_after_destroy

  depends_on = [module.vnet]
}

module "aks" {
  source = "../.."

  product_family     = var.product_family
  product_service    = var.product_service
  environment        = var.environment
  environment_number = var.environment_number
  region             = var.region

  resource_group_name = module.resource_group.name

  private_cluster_enabled = var.private_cluster_enabled

  kubernetes_version        = var.kubernetes_version
  network_plugin            = var.network_plugin
  agents_count              = var.agents_count
  agents_availability_zones = var.agents_availability_zones
  agents_size               = var.agents_size
  agents_pool_name          = var.agents_pool_name
  os_disk_size_gb           = var.os_disk_size_gb

  monitor_metrics = var.monitor_metrics

  log_analytics_workspace_internet_ingestion_enabled = var.log_analytics_workspace_internet_ingestion_enabled
  log_analytics_workspace_internet_query_enabled     = var.log_analytics_workspace_internet_query_enabled

  key_vault_secrets_provider_enabled = var.key_vault_secrets_provider_enabled
  secret_rotation_enabled            = var.secret_rotation_enabled
  secret_rotation_interval           = var.secret_rotation_interval

  cluster_identity_role_assignments = {
    "vnet" = ["Network Contributor", module.vnet.vnet_id]
  }

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

  create_application_insights = var.create_application_insights
  application_insights        = var.application_insights

  create_monitor_private_link_scope = var.create_monitor_private_link_scope

  monitor_private_link_scope_dns_zone_suffixes = var.monitor_private_link_scope_dns_zone_suffixes
  monitor_private_link_scope_subnet_id         = module.vnet.vnet_subnets_name_id["subnet-private-endpoint"]

  enable_prometheus_monitoring                     = var.enable_prometheus_monitoring
  prometheus_enable_default_rule_groups            = var.prometheus_enable_default_rule_groups
  prometheus_default_rule_group_naming             = var.prometheus_default_rule_group_naming
  prometheus_default_rule_group_interval           = var.prometheus_default_rule_group_interval
  prometheus_workspace_public_access_enabled       = var.prometheus_workspace_public_access_enabled
  enable_prometheus_monitoring_private_endpoint    = var.enable_prometheus_monitoring_private_endpoint
  prometheus_monitoring_private_endpoint_subnet_id = module.vnet.vnet_subnets_name_id["subnet-private-endpoint"]

  prometheus_rule_groups = var.prometheus_rule_groups

  tags = var.tags

  depends_on = [module.vnet, time_sleep.wait_after_destroy]
}
