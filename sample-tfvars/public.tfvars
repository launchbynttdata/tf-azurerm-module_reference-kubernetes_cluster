product_family     = "ref"
product_service    = "k8s"
environment_number = "000"

region = "eastus"
# az aks get-versions --location eastus
kubernetes_version = "1.28"
#agents_count              = 2
agents_size = "Standard_D2_v2"

enable_auto_scaling       = true
agents_max_count          = 5
agents_min_count          = 2
agents_availability_zones = [1, 2]

# kubenet or azure
network_plugin = "kubenet"

private_cluster_enabled = false

# System Assigned managed Identity is not supported with custom network. User Assigned ID is must
# UserAssigned or SystemAssigned
identity_type = "SystemAssigned"


node_pools = {
  lin1 = {
    name       = "linpool1"
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

# Below properties needs to be set to enable AAD integration
# k8s-admin-ad-group: kube-admin-sandbox-subscription
# rbac_aad_admin_group_object_ids = ["e61e36e5-7fdc-4d47-9e64-9ab3628140a7"]
# This must be set to true to enable AAD integration
rbac_aad = false
# this is recommended to be set to true
rbac_aad_managed = false
# whether Azure RBAC or k8s RBAC will be enabled
rbac_aad_azure_rbac_enabled = false
# this is true by default. no need to set explicitly
role_based_access_control_enabled = true
local_account_disabled            = false

key_vault_secrets_provider_enabled = true
secret_rotation_interval           = "2m" # pragma: allowlist secret
secret_rotation_enabled            = true
additional_key_vault_ids           = []

monitor_metrics = {}

dns_zone_suffix = "azmk8s.io"

tags = {
  owner       = "Alan"
  purpose     = "K8s Cluster for Gov cloud"
  environment = "sandbox"
}
