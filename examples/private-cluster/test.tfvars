product_family  = "dso"
product_service = "pvt"

kubernetes_version        = "1.26"
agents_count              = 2
agents_availability_zones = [1, 2]
#net_profile_outbound_type  = "userDefinedRouting"
#vnet_subnet_id = "/subscriptions/e71eb3cd-83f2-46eb-8f47-3b779e27672f/resourceGroups/deb-k8s-rg/providers/Microsoft.Network/virtualNetworks/deb-k8s-vnet/subnets/subnet-1"
# default service cidr is 10.0.0.0/16
net_profile_service_cidr   = "10.2.0.0/16"
net_profile_dns_service_ip = "10.2.0.10"
net_profile_pod_cidr       = "10.3.0.0/16"

#resource_group_name = "deb-k8s-rg"
network_plugin = "kubenet"

private_cluster_enabled = true
# actual id if custom dns zone is used, System if Azure managed
private_dns_zone_id = "System"
#private_dns_zone_id = "/subscriptions/e71eb3cd-83f2-46eb-8f47-3b779e27672f/resourceGroups/deb-k8s-rg/providers/Microsoft.Network/privateDnsZones/launch.private.eastus.azmk8s.io"
# System Assigned managed Identity is not supported with custom network
identity_type = "UserAssigned"
# There is a typo in the ID of MSI (resourcegroup should be resourceGroup)
#identity_ids = ["/subscriptions/e71eb3cd-83f2-46eb-8f47-3b779e27672f/resourceGroups/deb-k8s-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/deb-k8s-msi"]
