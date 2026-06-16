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

public_dns_zone_name  = "terratest.example-1.com"
public_dns_zone_names = ["terratest.example-2.com"]

public_dns_zone_root_a_records = {
  "terratest.example-1.com" = {
    resource_group_name = "dso-kube-eus-dev-000-rg-test"
    record_name         = "@"
    ttl                 = 300
    records             = ["1.1.1.1"]
  }
}

log_analytics_workspace_daily_quota_gb = 5

# Enable OIDC issuer and Workload Identity for this example
oidc_issuer_enabled       = true
workload_identity_enabled = true

test_resource_group_name = "dso-kube-eus-dev-000-rg-test"

# Workload identity configuration for testing
workload_user_assigned_identities = {
  test_workload_identity = {}
}

workload_federated_credentials = {
  test_workload_identity_fic = {
    user_assigned_identity_key = "test_workload_identity"
    name                       = "test-workload-identity-fic"
    namespace                  = "default"
    service_account_name       = "test-workload-identity-sa"
  }
}

# Role assignments are controlled by create_test_role_assignment flag
# When true, main.tf locals will create a test role assignment on the example resource group
workload_identity_role_assignments = {}

# Enable test role assignment on the example resource group
create_test_role_assignment = true
