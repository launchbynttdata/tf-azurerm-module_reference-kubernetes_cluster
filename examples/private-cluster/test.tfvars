product_family  = "dso"
product_service = "pvt"

kubernetes_version        = "1.28"
agents_count              = 2
agents_availability_zones = [1, 2]
# default service cidr is 10.0.0.0/16
net_profile_service_cidr   = "10.2.0.0/16"
net_profile_dns_service_ip = "10.2.0.10"
net_profile_pod_cidr       = "10.3.0.0/16"

network_plugin = "kubenet"

private_cluster_enabled = true

# User Assigned Managed Identity will be automatically created
identity_type = "UserAssigned"
