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
product_family  = "dso"
product_service = "kube"
agents_size     = "Standard_D2_v2"

identity_type = "UserAssigned"

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
    os_sku  = "Ubuntu"
    os_type = "Linux"
  }
}

public_dns_zone_name = "terratest.example-1.com"

log_analytics_workspace_daily_quota_gb = 5

workload_user_assigned_identities = {
  external_dns = {}
}

workload_federated_credentials = {
  external_dns_fic = {
    user_assigned_identity_key = "external_dns"
    name                       = "external-dns-fic"
    namespace                  = "external-dns"
    service_account_name       = "external-dns"
  }
}

workload_identity_role_assignments = {}
