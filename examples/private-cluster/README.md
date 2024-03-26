# private-cluster

This example creates a private AKS cluster with a custom subnet passed in as input. Below are the list of considerations to be made
- A user defined Managed identity must be used. So create an identity beforehand and pass it as inputs `identity_ids=[<user_defined_identity_id]` and set `identity_type = "UserAssigned"`.
- The above identity must be assigned `Contributor` role on the `kube-resource-group` for any internal Load Balancers (used for ingresses)
 to assign an IP Address in the AKS cluster VNet
- In case of Hub and Spoke architecture, to access the cluster from a VM created in the `Hub` vnet, the Hub Vnet must be linked to the `Private DNS Zone` of the AKS cluster API Server.
- By default, even for private AKS clusters, the nodes have unrestricted outbound route to the internet. Azure achieves that through a public Load Balancer (`net_profile_outbound_type=LoadBalancer`) that routes traffic to the internet.
  Few scenarios where the outbound traffic route is required is to sync time on the Node pool, interact with Azure AD Server, access public container registries to pull images etc.
- In case you want to restrict the outbound traffic, this can be done by setting `net_profile_outbound_type=UserDefinedRouting`.
  In such case an Azure firewall must be used to control outbound traffic. Mandatory outbound traffic must be whitelisted on the Firewall. For example, to ensure linkerd is working, one needs to whitelist `cr.l5d.ioghcr.io, pkg-containers.githubusercontent.com, docker.l5d.io`

## What is a private cluster?

In a private cluster, the control plane or API server has internal IP addresses. By using a private cluster, you can ensure network traffic between your API server and your node pools remains on the private network only.

The control plane or API server is in an Azure Kubernetes Service (AKS)-managed Azure resource group. Your cluster or node pool is in your resource group. The server and the cluster or node pool can communicate with each other through the Azure Private Link service in the API server virtual network and a private endpoint that's exposed on the subnet of your AKS cluster.

When you provision a private AKS cluster, AKS by default creates a private FQDN with a private DNS zone and an additional public FQDN with a corresponding A record in Azure public DNS. The agent nodes continue to use the A record in the private DNS zone to resolve the private IP address of the private endpoint for communication to the API server.

## Limitations

- There's no support for Azure DevOps Microsoft-hosted Agents with private clusters. Consider using Self-hosted Agents.
- If you need to enable Azure Container Registry to work with a private AKS cluster, set up a private link for the container registry in the cluster virtual network or set up peering between the Container Registry virtual network and the private cluster's virtual network.

## Integrate API Server with custom private DNS

Unless specified, Azure will create a managed Private DNS zone and assign it to the API Server. To use a custom private DNS zone,
a private DNS zone must be created, the cluster Identity (user assigned MSI in this case) must be given permission to the private DNS zone
and the Private DNS Zone ID must be passed in as an input to terraform `private_dns_zone_id`.

The custom DNS Zone must be of the format `<sub_zone>.private.<region>.azmk8s.io`

Below command shows how to assign the Cluster Identity with permissions to the private DNS zone. However, this may not be
required if the AKS is provisioned through terraform with the input variable `private_dns_zone_id=<private_dns_zone_id>`. Azure will
automatically assign `Contributor` role on the AKS Resource Group which will have the same effect.

```shell
PRIVATE_ZONE_ID=$(az network private-dns zone show --name $privateDnsHostedZoneName --resource-group $privateDnsResourceGroupName --query "id" -o tsv)

# Assign role to the k8s user assigned MSI "Private DNS Zone Contributor" and "Network Contributor"

# MSI_PRINCIPAL_ID=$(az aks show -n $CLUSTER_NAME -g $CLUSTER_RG --query "identity.userAssignedIdentities | keys(@)[0]" -o tsv)
MSI_PRINCIPAL_ID=$(terraform output -json cluster_identity | jq -r ".identity_ids[0]")
az role assignment create --role "Private DNS Zone Contributor" --assignee $MSI_PRINCIPAL_ID --scope $PRIVATE_ZONE_ID
az role assignment create --role "Network Contributor" --assignee $MSI_PRINCIPAL_ID --scope $PRIVATE_ZONE_ID
```

**Note:** In the event your VMs are in a different VNet than the AKS, you need to link the VM VNet to the private DNS zone as well.


## How to connect to a private cluster?

The API server doesn't have a public IP. hence, you cannot connect to it over the internet from your laptop
Some solutions
- create a VM in the same vnet, login into that vm using ssh and access the k8s cluster from there
- Create VNet peering between the Vnet containing the VM and k8s Vnet. Make sure to link the Private DNS zone to the VM Vnet in addition to the peering connection.

# Public Ingress

By default, an AKS creates a public load balancer named `kubernetes` that is used as an entry point for any kubernetes service that has a `net_profile_outbound_type=LoadBalancer`. Azure creates
this load balancer for the purpose of egress traffic going out of the cluster. But the same LoadBalancer gets used for Ingress purposes as well.
Whenever a new k8s service of `type=LoadBalancer` is provisioned, AKS creates a new public IP and attaches it to the LoadBalancer by which the service can be referred.

In case the AKS is provision with `net_profile_outbound_type=UserDefinedRouting`, the public Load Balancer won't exist ahead of time but would be created when a service of type=LoadBalancer is created.

## Private Ingress

If we need to have a private ingress, then we must add the below annotation to the service `metadata`

```shell
# This will create a private load balancer named `kubernetes-internal` if not already exists and assign it a private ip
# from the below subnet
service.beta.kubernetes.io/azure-load-balancer-internal: "true"
# If you want the ingress to use a separate subnet for ip assignment
service.beta.kubernetes.io/azure-load-balancer-internal-subnet: ing-1-subnet
```

# Multi AZ Node pool

If we want to ensure that the node pools spread across multiple availability zones, we can set the input variable `agents_availability_zones` to a list of availability zones.
For example, `agents_availability_zones = [1,2]`

```shell
kubectl describe nodes | grep -e "Name:" -e "topology.kubernetes.io/zone"
Name:               aks-default-41892607-vmss000000
                    topology.kubernetes.io/zone=eastus-2
Name:               aks-default-41892607-vmss000001
                    topology.kubernetes.io/zone=eastus-1
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0, <= 1.5.5 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~>3.67 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.5 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_random"></a> [random](#provider\_random) | 3.6.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_resource_names"></a> [resource\_names](#module\_resource\_names) | git::https://github.com/launchbynttdata/tf-launch-module_library-resource_name.git | 1.0.0 |
| <a name="module_resource_group"></a> [resource\_group](#module\_resource\_group) | git::https://github.com/launchbynttdata/tf-azurerm-module_primitive-resource_group.git | 1.0.0 |
| <a name="module_user_identity"></a> [user\_identity](#module\_user\_identity) | git::https://github.com/launchbynttdata/tf-azurerm-module_primitive-user_managed_identity.git | 1.0.0 |
| <a name="module_rg_role_assignment"></a> [rg\_role\_assignment](#module\_rg\_role\_assignment) | git::https://github.com/launchbynttdata/tf-azurerm-module_primitive-role_assignment.git | 1.0.0 |
| <a name="module_vnet"></a> [vnet](#module\_vnet) | git::https://github.com/launchbynttdata/tf-azurerm-module_primitive-virtual_network.git | 1.0.0 |
| <a name="module_aks"></a> [aks](#module\_aks) | ../.. | n/a |

## Resources

| Name | Type |
|------|------|
| [random_integer.random_int](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/integer) | resource |
| [random_password.password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_product_family"></a> [product\_family](#input\_product\_family) | (Required) Name of the product family for which the resource is created.<br>    Example: org\_name, department\_name. | `string` | `"dso"` | no |
| <a name="input_product_service"></a> [product\_service](#input\_product\_service) | (Required) Name of the product service for which the resource is created.<br>    For example, backend, frontend, middleware etc. | `string` | `"kube"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment in which the resource should be provisioned like dev, qa, prod etc. | `string` | `"dev"` | no |
| <a name="input_environment_number"></a> [environment\_number](#input\_environment\_number) | The environment count for the respective environment. Defaults to 000. Increments in value of 1 | `string` | `"000"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS Region in which the infra needs to be provisioned | `string` | `"eastus"` | no |
| <a name="input_resource_names_map"></a> [resource\_names\_map](#input\_resource\_names\_map) | A map of key to resource\_name that will be used by tf-launch-module\_library-resource\_name to generate resource names | <pre>map(object(<br>    {<br>      name       = string<br>      max_length = optional(number, 60)<br>    }<br>  ))</pre> | <pre>{<br>  "msi": {<br>    "max_length": 60,<br>    "name": "msi"<br>  },<br>  "rg": {<br>    "max_length": 60,<br>    "name": "rg"<br>  },<br>  "vnet": {<br>    "max_length": 60,<br>    "name": "vnet"<br>  }<br>}</pre> | no |
| <a name="input_address_space"></a> [address\_space](#input\_address\_space) | Address space of the Vnet | `list(string)` | <pre>[<br>  "10.50.0.0/16"<br>]</pre> | no |
| <a name="input_subnet_names"></a> [subnet\_names](#input\_subnet\_names) | Name of the subnets to be created | `list(string)` | <pre>[<br>  "subnet-api-server",<br>  "subnet-default-pool",<br>  "subnet-app-pool-1",<br>  "subnet-private-aks"<br>]</pre> | no |
| <a name="input_subnet_prefixes"></a> [subnet\_prefixes](#input\_subnet\_prefixes) | The CIDR blocks of the subnets whose names are specified in `subnet_names` | `list(string)` | <pre>[<br>  "10.50.0.0/24",<br>  "10.50.1.0/24",<br>  "10.50.2.0/24",<br>  "10.50.3.0/24"<br>]</pre> | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Specify which Kubernetes release to use. The default used is the latest Kubernetes version available in the region | `string` | `"1.26.3"` | no |
| <a name="input_network_plugin"></a> [network\_plugin](#input\_network\_plugin) | Network plugin to use for networking. Default is azure. | `string` | `"azure"` | no |
| <a name="input_agents_count"></a> [agents\_count](#input\_agents\_count) | The number of Agents that should exist in the Agent Pool. Please set `agents_count` `null` while `enable_auto_scaling` is `true` to avoid possible `agents_count` changes. | `number` | `2` | no |
| <a name="input_agents_availability_zones"></a> [agents\_availability\_zones](#input\_agents\_availability\_zones) | (Optional) A list of Availability Zones across which the Node Pool should be spread. Changing this forces a new resource to be created. | `list(string)` | `null` | no |
| <a name="input_agents_pool_name"></a> [agents\_pool\_name](#input\_agents\_pool\_name) | The default Azure AKS agentpool (nodepool) name. | `string` | `"default"` | no |
| <a name="input_agents_size"></a> [agents\_size](#input\_agents\_size) | The default virtual machine size for the Kubernetes agents. Changing this without specifying `var.temporary_name_for_rotation` forces a new resource to be created. | `string` | `"Standard_D2_v2"` | no |
| <a name="input_os_disk_size_gb"></a> [os\_disk\_size\_gb](#input\_os\_disk\_size\_gb) | Disk size of nodes in GBs. | `number` | `30` | no |
| <a name="input_identity_type"></a> [identity\_type](#input\_identity\_type) | (Optional) The type of identity used for the managed cluster. Conflicts with `client_id` and `client_secret`. Possible values are `SystemAssigned` and `UserAssigned`. If `UserAssigned` is set, an `identity_ids` must be set as well. | `string` | `"SystemAssigned"` | no |
| <a name="input_private_cluster_enabled"></a> [private\_cluster\_enabled](#input\_private\_cluster\_enabled) | If true cluster API server will be exposed only on internal IP address and available only in cluster vnet. | `bool` | `false` | no |
| <a name="input_private_dns_zone_id"></a> [private\_dns\_zone\_id](#input\_private\_dns\_zone\_id) | (Optional) Either the ID of Private DNS Zone which should be delegated to this Cluster, `System` to have AKS manage this or `None`. In case of `None` you will need to bring your own DNS server and set up resolving, otherwise cluster will have issues after provisioning. Changing this forces a new resource to be created. | `string` | `null` | no |
| <a name="input_net_profile_dns_service_ip"></a> [net\_profile\_dns\_service\_ip](#input\_net\_profile\_dns\_service\_ip) | (Optional) IP address within the Kubernetes service address range that will be used by cluster service discovery (kube-dns). Changing this forces a new resource to be created. | `string` | `null` | no |
| <a name="input_net_profile_outbound_type"></a> [net\_profile\_outbound\_type](#input\_net\_profile\_outbound\_type) | (Optional) The outbound (egress) routing method which should be used for this Kubernetes Cluster. Possible values are loadBalancer and userDefinedRouting. Defaults to loadBalancer. | `string` | `"loadBalancer"` | no |
| <a name="input_net_profile_pod_cidr"></a> [net\_profile\_pod\_cidr](#input\_net\_profile\_pod\_cidr) | (Optional) The CIDR to use for pod IP addresses. This field can only be set when network\_plugin is set to kubenet. Changing this forces a new resource to be created. | `string` | `null` | no |
| <a name="input_net_profile_service_cidr"></a> [net\_profile\_service\_cidr](#input\_net\_profile\_service\_cidr) | (Optional) The Network Range used by the Kubernetes service. Changing this forces a new resource to be created. | `string` | `null` | no |
| <a name="input_key_vault_secrets_provider_enabled"></a> [key\_vault\_secrets\_provider\_enabled](#input\_key\_vault\_secrets\_provider\_enabled) | (Optional) Whether to use the Azure Key Vault Provider for Secrets Store CSI Driver in an AKS cluster. For more details: https://docs.microsoft.com/en-us/azure/aks/csi-secrets-store-driver | `bool` | `false` | no |
| <a name="input_secret_rotation_enabled"></a> [secret\_rotation\_enabled](#input\_secret\_rotation\_enabled) | Is secret rotation enabled? This variable is only used when `key_vault_secrets_provider_enabled` is `true` and defaults to `false` | `bool` | `false` | no |
| <a name="input_secret_rotation_interval"></a> [secret\_rotation\_interval](#input\_secret\_rotation\_interval) | The interval to poll for secret rotation. This attribute is only set when `secret_rotation` is `true` and defaults to `2m` | `string` | `"2m"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of custom tags to be attached to this module resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_kube_config_raw"></a> [kube\_config\_raw](#output\_kube\_config\_raw) | n/a |
| <a name="output_kube_admin_config_raw"></a> [kube\_admin\_config\_raw](#output\_kube\_admin\_config\_raw) | n/a |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | n/a |
| <a name="output_cluster_id"></a> [cluster\_id](#output\_cluster\_id) | n/a |
| <a name="output_cluster_fqdn"></a> [cluster\_fqdn](#output\_cluster\_fqdn) | n/a |
| <a name="output_cluster_portal_fqdn"></a> [cluster\_portal\_fqdn](#output\_cluster\_portal\_fqdn) | n/a |
| <a name="output_cluster_private_fqdn"></a> [cluster\_private\_fqdn](#output\_cluster\_private\_fqdn) | n/a |
| <a name="output_host"></a> [host](#output\_host) | n/a |
| <a name="output_username"></a> [username](#output\_username) | n/a |
| <a name="output_password"></a> [password](#output\_password) | n/a |
| <a name="output_admin_host"></a> [admin\_host](#output\_admin\_host) | n/a |
| <a name="output_admin_username"></a> [admin\_username](#output\_admin\_username) | n/a |
| <a name="output_admin_password"></a> [admin\_password](#output\_admin\_password) | n/a |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | n/a |
| <a name="output_key_vault_secrets_provider"></a> [key\_vault\_secrets\_provider](#output\_key\_vault\_secrets\_provider) | The `azurerm_kubernetes_cluster`'s `key_vault_secrets_provider` block. |
| <a name="output_key_vault_id"></a> [key\_vault\_id](#output\_key\_vault\_id) | Key Vault ID |
| <a name="output_cluster_identity"></a> [cluster\_identity](#output\_cluster\_identity) | n/a |
| <a name="output_kubelet_identity"></a> [kubelet\_identity](#output\_kubelet\_identity) | The `azurerm_kubernetes_cluster`'s `kubelet_identity` block. |
| <a name="output_node_resource_group"></a> [node\_resource\_group](#output\_node\_resource\_group) | The auto-generated Resource Group which contains the resources for this Managed Kubernetes Cluster. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

# References
1. [Private ACR Integration](https://techcommunity.microsoft.com/t5/core-infrastructure-and-security/private-aks-and-acr-using-private-endpoint-part-2-2/ba-p/3122281)
