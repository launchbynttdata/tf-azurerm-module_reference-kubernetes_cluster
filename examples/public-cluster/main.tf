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

resource "random_password" "password" {
  length = 10
}

module "aks" {
  source = "../.."

  product_family     = var.product_family
  product_service    = var.product_service
  environment        = var.environment
  environment_number = var.environment_number
  region             = var.region

  identity_type = var.identity_type

  node_pools = var.node_pools

  kubernetes_version = var.kubernetes_version
  agents_count       = var.agents_count
  agents_size        = var.agents_size
  agents_pool_name   = var.agents_pool_name
  os_disk_size_gb    = var.os_disk_size_gb

  key_vault_secrets_provider_enabled = true
  secret_rotation_enabled            = true

  public_dns_zone_name = var.public_dns_zone_name

  log_analytics_workspace_daily_quota_gb = var.log_analytics_workspace_daily_quota_gb

  secrets = {
    username = "test102"
    password = random_password.password.result
  }

  tags = var.tags

}
