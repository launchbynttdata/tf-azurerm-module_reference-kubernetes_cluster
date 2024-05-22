
# This file sets up a private cluster with user defined routing
# Dependencies that users must update in this file
#   - azure_firewall_private_ip_address
#   - vnet_subnet_id
#   - node_pools.lin1.vnet_subnet_id

product_family     = "dso"
product_service    = "aks"
environment        = "sandbox"
environment_number = "000"
region             = "eastus"

# az aks get-versions --location eastus
kubernetes_version = "1.28"
#agents_count              = 2
agents_size = "Standard_D2_v2"

enable_auto_scaling       = true
agents_max_count          = 5
agents_min_count          = 1
agents_availability_zones = [1, 2]

# Default is standard Load Balancer
# In case of userDefinedRouting, the subnet must already be configured with the route table.
# Also, role assignment `Contributor` or anything with Write must be done on the cluster MSI for the route table (already configured by this module)
net_profile_outbound_type = "userDefinedRouting"

user_defined_routing = {
  azure_firewall_private_ip_address = "10.16.4.4"
}

vnet_subnet_id = "<vnet_subnet_id>"

# default service cidr is 10.0.0.0/16
# Only supported when network_plugin is kubenet
net_profile_service_cidr   = "10.2.0.0/16"
net_profile_dns_service_ip = "10.2.0.10"
net_profile_pod_cidr       = "10.3.0.0/16"

# The MSI must have "Contributor" role on the resource group
# If not specified, the resource group will be created by this module
# resource_group_name = "govt-k8s-rg-000"

# kubenet or azure
network_plugin = "kubenet"

# private cluster
private_cluster_enabled = true

# Additional VNET links
additional_vnet_links = {
  bastion-vnet-link = "/subscriptions/4554e249-e00f-4668-9be3-da31ed200163/resourceGroups/dso-k8s-001/providers/Microsoft.Network/virtualNetworks/dso-k8s-ado-vnet-001"
}

# Can be SystemAssigned or UserAssigned. For UDR, this must be UserAssigned
# In either case, the MSI will be created by this module
identity_type = "UserAssigned"

# Node pools if required
# The key of the node-pool must be <= 5 characters
node_pools = {
  lin1 = {
    name = "linpool1"
    # node_count = 1
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 5
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
    vnet_subnet_id = "<vnet_subnet_id>"
  }
}

# Fill in the below details to enable AAD integration

# This must be set to true to enable AAD integration
rbac_aad = false
# this is recommended to be set to true
rbac_aad_managed = false
# this is true by default. no need to set explicitly
role_based_access_control_enabled = true

# Uncomment below for AAD integration
# rbac_aad_admin_group_object_ids = ["e61e36e5-7fdc-4d47-9e64-9ab3628140a7"]
# whether Azure RBAC or k8s RBAC will be enabled
rbac_aad_azure_rbac_enabled = false

# Enable/disable the admin user
local_account_disabled = false

key_vault_secrets_provider_enabled = true
secret_rotation_interval           = "2m" # pragma: allowlist secret
secret_rotation_enabled            = true
additional_key_vault_ids           = []

# Workload identity related variables

# oidc_issuer_enabled       = true
# workload_identity_enabled = true
# enable_rbac_authorization = true

monitor_metrics = {}

cluster_identity_role_assignments = {
  # This is not required any more as the module takes care of it
  #route-table = ["Contributor", "/subscriptions/4554e249-e00f-4668-9be3-da31ed200163/resourceGroups/dso-test-rg-001/providers/Microsoft.Network/routeTables/k8s-udr-route-table"]
}
node_pool_identity_role_assignments = {}
# Must be changed for gov cloud
dns_zone_suffix = "azmk8s.io"

tags = {
  owner       = "Launch DSO"
  purpose     = "Private cluster using Terragrunt"
  environment = "sandbox"
}
