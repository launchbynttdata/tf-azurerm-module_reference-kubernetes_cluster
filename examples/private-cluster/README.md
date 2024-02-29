# private-cluster
Creates a private k8s cluster with a custom subnet passed in as input. Below are the list of considerations to be made
- A user defined Managed identity must be used. Create an identity beforehand and pass it as inputs.
- That above identity must be assigned `Contributor` role on the `kube-resource-group`
- Internal Load balancer cannot assign an IP address in the custom VNet provided as input, until the user assigned Managed Identity is given permission on that Vnet or the RG. The above `Contributor` role would suffice.
- To access the k8s cluster from a VM created in the `Hub` vnet, the Hub Vnet must be linked to the Private `DNS Zone` created by the AKS cluster
- In case you are using public registries for docker images, you need to create custom rules in Azure firewall to whitelist all those fqdns. For example, to ensure linkerd is working, one needs to whitelist `cr.l5d.ioghcr.io, pkg-containers.githubusercontent.com, docker.l5d.io`

## What is a private cluster?
In a private cluster, the control plane or API server has internal IP addresses. By using a private cluster, you can ensure network traffic between your API server and your node pools remains on the private network only.

The control plane or API server is in an Azure Kubernetes Service (AKS)-managed Azure resource group. Your cluster or node pool is in your resource group. The server and the cluster or node pool can communicate with each other through the Azure Private Link service in the API server virtual network and a private endpoint that's exposed on the subnet of your AKS cluster.

When you provision a private AKS cluster, AKS by default creates a private FQDN with a private DNS zone and an additional public FQDN with a corresponding A record in Azure public DNS. The agent nodes continue to use the A record in the private DNS zone to resolve the private IP address of the private endpoint for communication to the API server.

## Limitations
- There's no support for Azure DevOps Microsoft-hosted Agents with private clusters. Consider using Self-hosted Agents.
- If you need to enable Azure Container Registry to work with a private AKS cluster, set up a private link for the container registry in the cluster virtual network or set up peering between the Container Registry virtual network and the private cluster's virtual network.

## Integrate API Server with custom private DNS
Unless specified, Azure will create a managed Private DNS zone and assign it to the API Server
The terraform input `private_dns_zone_id` should be populated with a private DNS zone id.
```shell
# Create a private DNS zone in the format <sub-zone>.private.<region>.azmk8s.io
# Copy the resource_id
# PRIVATE_ZONE_ID=$(az network private-dns zone show --name $privateDnsHostedZoneName --resource-group $privateDnsResourceGroupName --query "id" -o tsv)
PRIVATE_ZONE_ID="/subscriptions/e71eb3cd-83f2-46eb-8f47-3b779e27672f/resourceGroups/deb-k8s-rg/providers/Microsoft.Network/privateDnsZones/launch.private.eastus.azmk8s.io"
# Assign role to the k8s user assigned MSI "Private DNS Zone Contributor" and "Network Contributor"
# MSI_PRINCIPAL_ID=$(az aks show -n $aksCluster -g $aksResourceGroup --query "identityProfile.kubeletidentity.objectId" -o tsv)
MSI_PRINCIPAL_ID="9a520834-eac1-48f0-9c04-5e22b8c1d2c7";
az role assignment create --role "Private DNS Zone Contributor" --assignee $MSI_PRINCIPAL_ID --scope $PRIVATE_ZONE_ID
az role assignment create --role "Network Contributor" --assignee $MSI_PRINCIPAL_ID --scope $PRIVATE_ZONE_ID
# Link the k8s VNet to this private zone (so DNS resolution can work)

```
## Integrate with Public ACR
It is very simple to integrate an AKS node pool with a Public ACR. In order for the Nodes in the pool to be able to pull images from the public ACR,
one needs to attach a role to the Node pool (kubelet) MSI as shown below

```shell
# Assigns an AcrPull policy to the MSI
az role assignment create --role "AcrPull" --assignee $MSI_PRINCIPAL --scope $ACR_ID
```
## Integrate with Private ACR
Belows steps needs to be followed to integrate ACR privately with AKS

### Provision an ACR
Create an ACR with an `sku=Premium`. Private networking is only available in Premium tier

### Create a Private endpoint
For the ACR to be private, a Private endpoint needs to be created and attached to a subnet of a VNet.

In case you want to have this ACR as a shared service, that is this ACR can be used with multiple AKS clusters and other services, you would like to have this ACR associated with a VNet of its own
- Create or use an existing Resource Group
- Create a VNet with at least one subnet.
- Make sure this subnet is dedicated for the ACR, since the NSG will be disabled as part of Private endpoint creation
- Create a Private DNS Zone `privatelink.azurecr.io`. Note the private DNS zone must be named the same.
- Create a VNET link in the above DNS zone for your VNet.
- Create a Private Endpoint and select the subnet and dns_zone created above. Select the `subresource_names=["registry"]`

At this point, the ACR is ready to be connected privately with your AKS cluster

### Link ACR with AKS
If the ACR is provisioned in a VNet separate from the Vnet containing the Node-pools (as is the case above), we need to link both the Vnets

- Create Vnet Peering between AKS and ACR Vnets
- Create a VNET Link for the AKS Vnet in the private DNS zone `privatelink.azurecr.io`
- Lastly, create a role `AcrPull` in the Node-pool MSI
    ```shell
    # Assigns an AcrPull policy to the MSI
    az role assignment create --role "AcrPull" --assignee $MSI_PRINCIPAL --scope $ACR_ID
    ```
**Note:** Since, the above role is assigned to k8s node pull, we dont have to feed docker credentials to our deployment to access private ACR.

The ACR is not integrated to AKS over private network.

### Testing
- Push an image to ACR. When admin user is not enabled on ACR, you must assign IAM RBAC for either your SSO user or Service Principal. Then you can login to ACR using `docker login`. You also need to be inside a VM in the same VNet as AKS or ACR to abe able to reach the ACR instance.
- Modify your `deployment.yaml` to refer to this repository. You should see the image is pulled from the ACR.


## How to connect to a private cluster?
The API server doesn't have a public IP. hence, you cannot connect to it over the internet from your laptop
Some solutions
- create a VM in the same vnet, login into that vm using ssh and access the k8s cluster from there
- Create VPC peering between the Vnet containing the VM and k8s Vnet. Make sure to link the Private DNS zone to the VM Vnet.

# Private Ingress
By default, an AKS creates a public load balancer named `kubernetes` that is used as an entry point for any kubernetes service that has a `type=LoadBalancer`.
Whenever a new k8s service of type=LoadBalancer is provisioned, AKS creates a new public IP and attaches it to the LoadBalancer by which the service can be referred.

If we need to have a private ingress, then we must add the below annotation to the service `metadata`

```shell
# This will create a private loadbalancer named `kubernetes-internal` if not already exists and assign it a private ip
# from the below subnet
service.beta.kubernetes.io/azure-load-balancer-internal: "true"
# If you want the ingress to use a separate subnet for ip assignment
service.beta.kubernetes.io/azure-load-balancer-internal-subnet: ing-1-subnet
```

# Multi AZ Node pool
Set the input variable `agents_availability_zones = [1,2]`

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
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | <= 1.5.5 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >=3.67.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.5 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_random"></a> [random](#provider\_random) | 3.5.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_resource_names"></a> [resource\_names](#module\_resource\_names) | git::https://github.com/nexient-llc/tf-module-resource_name.git | 1.1.0 |
| <a name="module_resource_group"></a> [resource\_group](#module\_resource\_group) | git::https://github.com/nexient-llc/tf-azurerm-module_primitive-resource_group.git | 0.2.0 |
| <a name="module_user_identity"></a> [user\_identity](#module\_user\_identity) | git::https://github.com/nexient-llc/tf-azurerm-module_primitive-user_managed_identity.git | 0.1.0 |
| <a name="module_rg_role_assignment"></a> [rg\_role\_assignment](#module\_rg\_role\_assignment) | git::https://github.com/nexient-llc/tf-azurerm-module_primitive-role_assignment.git | 0.1.0 |
| <a name="module_vnet"></a> [vnet](#module\_vnet) | git::https://github.com/nexient-llc/tf-azurerm-module_primitive-virtual_network.git | 0.1.0 |
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
| <a name="input_resource_names_map"></a> [resource\_names\_map](#input\_resource\_names\_map) | A map of key to resource\_name that will be used by tf-module-resource\_name to generate resource names | <pre>map(object(<br>    {<br>      name       = string<br>      max_length = optional(number, 60)<br>    }<br>  ))</pre> | <pre>{<br>  "msi": {<br>    "max_length": 60,<br>    "name": "msi"<br>  },<br>  "rg": {<br>    "max_length": 60,<br>    "name": "rg"<br>  },<br>  "vnet": {<br>    "max_length": 60,<br>    "name": "vnet"<br>  }<br>}</pre> | no |
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
