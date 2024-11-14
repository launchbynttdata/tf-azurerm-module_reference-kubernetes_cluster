# private-complete

This example creates a private AKS cluster with a custom subnet passed in as input. Below are the list of considerations to be made
- A user defined Managed identity must be used. So create an identity beforehand and pass it as inputs `identity_ids=[<user_defined_identity_id]` and set `identity_type = "UserAssigned"`.
- The above identity must be assigned `Contributor` role on the `kube-resource-group` for any internal Load Balancers (used for ingresses)
 to assign an IP Address in the AKS cluster VNet
- In case of Hub and Spoke architecture, to access the cluster from a VM created in the `Hub` vnet, the Hub Vnet must be linked to the `Private DNS Zone` of the AKS cluster API Server.
- By default, even for private AKS clusters, the nodes have unrestricted outbound route to the internet. Azure achieves that through a public Load Balancer (`net_profile_outbound_type=LoadBalancer`) that routes traffic to the internet.
  Few scenarios where the outbound traffic route is required is to sync time on the Node pool, interact with Azure AD Server, access public container registries to pull images etc.
- In case you want to restrict the outbound traffic, this can be done by setting `net_profile_outbound_type=UserDefinedRouting`.
  In such case an Azure firewall must be used to control outbound traffic. Mandatory outbound traffic must be whitelisted on the Firewall.
  For example, to ensure linkerd is working, one needs to whitelist `cr.l5d.ioghcr.io, pkg-containers.githubusercontent.com, docker.l5d.io`
- More information on UDR can be found at [UserDefinedRouting.md](UserDefinedRouting.md)

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

We may also need to add additional roles to the MSI for it to be able to create a Vnet Link on the k8s VNet
```bash
# This step was not provided in the documentation but I got failure while creating AKS cluster
VNET_ID=$(az network vnet show -g $VNET_RG -n $VNET_NAME --query "id" -o tsv)
az role assignment create --role "Network Contributor" --assignee $MSI_PRINCIPAL_ID --scope $VNET_ID
```

**Note:** In the event your VMs are in a different VNet than the AKS, you need to link the VM VNet to the private DNS zone as well.


## How to connect to a private cluster?

The API server doesn't have a public IP. hence, you cannot connect to it over the internet from your laptop
Some solutions
- create a VM in the same vnet, login into that vm using ssh and access the k8s cluster from there
- Create VNet peering between the Vnet containing the VM and k8s Vnet. Make sure to link the Private DNS zone to the VM Vnet in addition to the peering connection.

## Public Ingress

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

## Multi AZ Node pool

If we want to ensure that the node pools spread across multiple availability zones, we can set the input variable `agents_availability_zones` to a list of availability zones.
For example, `agents_availability_zones = [1,2]`

```shell
kubectl describe nodes | grep -e "Name:" -e "topology.kubernetes.io/zone"
Name:               aks-default-41892607-vmss000000
                    topology.kubernetes.io/zone=eastus-2
Name:               aks-default-41892607-vmss000001
                    topology.kubernetes.io/zone=eastus-1
```

# Deploy Private AKS cluster from scratch

This section describes how to deploy a private AKS cluster in a custom VNet and a custom DNS Zone for the API server.

We need to set up the following infrastructure in the chronological order

1. Create a Resource Group. In a Hub & Spoke architecture, this would be the `Spoke` resource group. This resource group
    will contain the AKS cluster, VNET, Subnets, MSI and other resources. AKS anyways will create a separate resource group
    automatically for the node pools.
2. Create a VNet. This Vnet will be passed in as input the AKS cluster. The VNet is where the node pools will be associated with.
    Currently, the AKS API server will be created in a VNet managed by Azure. However, Azure will create a private endpoint for the AKS
    server in this VNet. In the future versions of AKS, there will be provision the AKS API server in a custom VNet (this is a beta feature now)

    Create multiple subnets in the VNet. One subnet for each application node pool and one for the system node pool
    - Subnet for System Node pool
    - Subnet for App Node pool 1
    - Subnet for App Node pool 2
    - Subnet for App Node pool N
    - Subnet for ACR (Optional): This is required if you want to have a private ACR for this k8s cluster. A separate subnet is required
        to create a private endpoint for the ACR as per the official documentation. Note: You can have a common ACR in the hub
        VNet and can be peered with this spoke VNet also.
    - Subnet for Bastion Hosts (Optional): You can have a dedicated subnet for Bastion hosts to access the private AKS cluster.
3. Private DNS Zone for the AKS API Server: This is required to resolve the private IP of the AKS API server. The private DNS zone
    must be of the format `<sub_zone>.private.<region>.azmk8s.io`. The private DNS zone must be linked to the VNet where the AKS API server
    is provisioned and any other VNets which would access this zone. The VNet must be peered with the VNet where the bastion VMs are provisioned.
4. Create a User Assigned Managed Identity. This identity will be used by the AKS cluster to manage the resources in the VNet.
    The identity must be assigned `Contributor` role on the VNet and the private DNS zone. See the above sections for more details
5. Private AKS (Optional): This must have a private endpoint for the AKS VNet.
6. Microsoft Entra ID AD Group (Optional): When AD integration is enabled, the AKS cluster must be associated with at least one
    AD Group which will have admin access on the AKS cluster
7. AKS Cluster: Private AKS cluster with the above resources passed in as inputs. The AKS cluster must be associated with the VNet
    and the custom DNS Zone. The AKS cluster must be associated with the User Assigned Managed Identity. The AKS cluster must be associated
    with the AD Group for AD integration.

## Access the private AKS cluster
In absence of VPN connection, you must have a VM (acting as bastion) either in the same VNet as the AKS or in a peered VNet.
In case of peered Vnet, the VNet must be linked with the Private DNS Zone of the AKS cluster (API Server).

- Download the kubeconfig file from the AKS cluster
  ```bash
    RG_NAME="dso-k8s-001"
    AKS_CLUSTER_NAME="dso-ado-k8s-dev-001-aks"
    az aks get-credentials --resource-group $RG_NAME --name $AKS_CLUSTER_NAME -f > ~/aks-config
  ```
- Copy to the bastion host
    ```bash
        scp ~/aks-config azureuser@<bastion-host>:~/aks-config
    ```
- Install `kubectl` on the bastion host
- Set the `KUBECONFIG` environment variable to the kubeconfig file
  ```bash
      export KUBECONFIG=~/aks-config
  ```
- Run `kubectl get nodes` to see the nodes in the cluster

# References
1. [Mandatory outbound access](https://learn.microsoft.com/en-us/azure/aks/outbound-rules-control-egress)
2. [Restrict Egress with Azure Firewall](https://learn.microsoft.com/en-us/azure/aks/limit-egress-traffic?tabs=aks-with-system-assigned-identities)
3. [Kubenet with BYO subnet and route table](https://learn.microsoft.com/en-us/azure/aks/configure-kubenet#bring-your-own-subnet-and-route-table-with-kubenet)
4. [Required Service Tags for Outbound traffic](https://learn.microsoft.com/en-us/azure/aks/outbound-rules-control-egress#azure-global-required-network-rules)
# Terraform Details
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.0 |
| <a name="requirement_azapi"></a> [azapi](#requirement\_azapi) | >= 1.4.0, < 2.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~>3.117 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.5 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_random"></a> [random](#provider\_random) | 3.6.3 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_resource_names"></a> [resource\_names](#module\_resource\_names) | terraform.registry.launch.nttdata.com/module_library/resource_name/launch | ~> 1.0 |
| <a name="module_resource_group"></a> [resource\_group](#module\_resource\_group) | terraform.registry.launch.nttdata.com/module_primitive/resource_group/azurerm | ~> 1.0 |
| <a name="module_vnet"></a> [vnet](#module\_vnet) | terraform.registry.launch.nttdata.com/module_primitive/virtual_network/azurerm | ~> 1.0 |
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
| <a name="input_subnet_names"></a> [subnet\_names](#input\_subnet\_names) | Name of the subnets to be created | `list(string)` | <pre>[<br>  "subnet-api-server",<br>  "subnet-default-pool",<br>  "subnet-app-pool-1",<br>  "subnet-private-aks",<br>  "subnet-private-endpoint"<br>]</pre> | no |
| <a name="input_subnet_prefixes"></a> [subnet\_prefixes](#input\_subnet\_prefixes) | The CIDR blocks of the subnets whose names are specified in `subnet_names` | `list(string)` | <pre>[<br>  "10.50.0.0/24",<br>  "10.50.1.0/24",<br>  "10.50.2.0/24",<br>  "10.50.3.0/24",<br>  "10.50.4.0/24"<br>]</pre> | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Specify which Kubernetes release to use. The default used is the latest Kubernetes version available in the region | `string` | `"1.27"` | no |
| <a name="input_network_plugin"></a> [network\_plugin](#input\_network\_plugin) | Network plugin to use for networking. Default is azure. | `string` | `"azure"` | no |
| <a name="input_monitor_metrics"></a> [monitor\_metrics](#input\_monitor\_metrics) | (Optional) Specifies a Prometheus add-on profile for the Kubernetes Cluster<br>object({<br>  annotations\_allowed = "(Optional) Specifies a comma-separated list of Kubernetes annotation keys that will be used in the resource's labels metric."<br>  labels\_allowed      = "(Optional) Specifies a Comma-separated list of additional Kubernetes label keys that will be used in the resource's labels metric."<br>}) | <pre>object({<br>    annotations_allowed = optional(string)<br>    labels_allowed      = optional(string)<br>  })</pre> | `{}` | no |
| <a name="input_agents_count"></a> [agents\_count](#input\_agents\_count) | The number of Agents that should exist in the Agent Pool. Please set `agents_count` `null` while `enable_auto_scaling` is `true` to avoid possible `agents_count` changes. | `number` | `2` | no |
| <a name="input_agents_availability_zones"></a> [agents\_availability\_zones](#input\_agents\_availability\_zones) | (Optional) A list of Availability Zones across which the Node Pool should be spread. Changing this forces a new resource to be created. | `list(string)` | `null` | no |
| <a name="input_agents_pool_name"></a> [agents\_pool\_name](#input\_agents\_pool\_name) | The default Azure AKS agentpool (nodepool) name. | `string` | `"default"` | no |
| <a name="input_agents_size"></a> [agents\_size](#input\_agents\_size) | The default virtual machine size for the Kubernetes agents. Changing this without specifying `var.temporary_name_for_rotation` forces a new resource to be created. | `string` | `"Standard_D2_v2"` | no |
| <a name="input_os_disk_size_gb"></a> [os\_disk\_size\_gb](#input\_os\_disk\_size\_gb) | Disk size of nodes in GBs. | `number` | `30` | no |
| <a name="input_identity_type"></a> [identity\_type](#input\_identity\_type) | (Optional) The type of identity used for the managed cluster. Conflicts with `client_id` and `client_secret`. Possible values are `SystemAssigned` and `UserAssigned`. If `UserAssigned` is set, an `identity_ids` must be set as well. | `string` | `"SystemAssigned"` | no |
| <a name="input_private_cluster_enabled"></a> [private\_cluster\_enabled](#input\_private\_cluster\_enabled) | If true cluster API server will be exposed only on internal IP address and available only in cluster vnet. | `bool` | `false` | no |
| <a name="input_net_profile_dns_service_ip"></a> [net\_profile\_dns\_service\_ip](#input\_net\_profile\_dns\_service\_ip) | (Optional) IP address within the Kubernetes service address range that will be used by cluster service discovery (kube-dns). Changing this forces a new resource to be created. | `string` | `null` | no |
| <a name="input_net_profile_outbound_type"></a> [net\_profile\_outbound\_type](#input\_net\_profile\_outbound\_type) | (Optional) The outbound (egress) routing method which should be used for this Kubernetes Cluster. Possible values are loadBalancer and userDefinedRouting. Defaults to loadBalancer. | `string` | `"loadBalancer"` | no |
| <a name="input_net_profile_pod_cidr"></a> [net\_profile\_pod\_cidr](#input\_net\_profile\_pod\_cidr) | (Optional) The CIDR to use for pod IP addresses. This field can only be set when network\_plugin is set to kubenet. Changing this forces a new resource to be created. | `string` | `null` | no |
| <a name="input_net_profile_service_cidr"></a> [net\_profile\_service\_cidr](#input\_net\_profile\_service\_cidr) | (Optional) The Network Range used by the Kubernetes service. Changing this forces a new resource to be created. | `string` | `null` | no |
| <a name="input_key_vault_secrets_provider_enabled"></a> [key\_vault\_secrets\_provider\_enabled](#input\_key\_vault\_secrets\_provider\_enabled) | (Optional) Whether to use the Azure Key Vault Provider for Secrets Store CSI Driver in an AKS cluster. For more details: https://docs.microsoft.com/en-us/azure/aks/csi-secrets-store-driver | `bool` | `false` | no |
| <a name="input_secret_rotation_enabled"></a> [secret\_rotation\_enabled](#input\_secret\_rotation\_enabled) | Is secret rotation enabled? This variable is only used when `key_vault_secrets_provider_enabled` is `true` and defaults to `false` | `bool` | `false` | no |
| <a name="input_secret_rotation_interval"></a> [secret\_rotation\_interval](#input\_secret\_rotation\_interval) | The interval to poll for secret rotation. This attribute is only set when `secret_rotation` is `true` and defaults to `2m` | `string` | `"2m"` | no |
| <a name="input_create_application_insights"></a> [create\_application\_insights](#input\_create\_application\_insights) | Ff true, create a new Application Insights resource to be associated with the AKS cluster | `bool` | `true` | no |
| <a name="input_application_insights"></a> [application\_insights](#input\_application\_insights) | Details for the Application Insights resource to be associated with the AKS cluster. Required only when create\_application\_insights=true | <pre>object({<br>    application_type                      = optional(string, "web")<br>    retention_in_days                     = optional(number, 30)<br>    daily_data_cap_in_gb                  = optional(number, 1)<br>    daily_data_cap_notifications_disabled = optional(bool, false)<br>    sampling_percentage                   = optional(number, 100)<br>    disabling_ip_masking                  = optional(bool, false)<br>    local_authentication_disabled         = optional(bool, false)<br>    internet_ingestion_enabled            = optional(bool, false)<br>    internet_query_enabled                = optional(bool, true)<br>    force_customer_storage_for_profiler   = optional(bool, false)<br>  })</pre> | `{}` | no |
| <a name="input_log_analytics_workspace_internet_ingestion_enabled"></a> [log\_analytics\_workspace\_internet\_ingestion\_enabled](#input\_log\_analytics\_workspace\_internet\_ingestion\_enabled) | (Optional) Should the Log Analytics Workspace support ingestion over the Public Internet? | `bool` | `false` | no |
| <a name="input_log_analytics_workspace_internet_query_enabled"></a> [log\_analytics\_workspace\_internet\_query\_enabled](#input\_log\_analytics\_workspace\_internet\_query\_enabled) | (Optional) Should the Log Analytics Workspace support querying over the Public Internet? | `bool` | `false` | no |
| <a name="input_create_monitor_private_link_scope"></a> [create\_monitor\_private\_link\_scope](#input\_create\_monitor\_private\_link\_scope) | If true, create a new Private Link Scope for Azure Monitor.<br>    NOTE: This will cause all azure monitor / log analytics traffic to go through private link. | `bool` | `true` | no |
| <a name="input_monitor_private_link_scope_dns_zone_suffixes"></a> [monitor\_private\_link\_scope\_dns\_zone\_suffixes](#input\_monitor\_private\_link\_scope\_dns\_zone\_suffixes) | The DNS zone suffixes for the private link scope | `set(string)` | <pre>[<br>  "privatelink.monitor.azure.com",<br>  "privatelink.oms.opinsights.azure.com",<br>  "privatelink.ods.opinsights.azure.com",<br>  "privatelink.agentsvc.azure-automation.net",<br>  "privatelink.blob.core.windows.net"<br>]</pre> | no |
| <a name="input_enable_prometheus_monitoring"></a> [enable\_prometheus\_monitoring](#input\_enable\_prometheus\_monitoring) | Deploy Prometheus monitoring resources with the AKS cluster | `bool` | `true` | no |
| <a name="input_enable_prometheus_monitoring_private_endpoint"></a> [enable\_prometheus\_monitoring\_private\_endpoint](#input\_enable\_prometheus\_monitoring\_private\_endpoint) | Enable private endpoint for Prometheus monitoring | `bool` | `false` | no |
| <a name="input_prometheus_workspace_public_access_enabled"></a> [prometheus\_workspace\_public\_access\_enabled](#input\_prometheus\_workspace\_public\_access\_enabled) | Enable public access to the Azure Monitor workspace for prometheus | `bool` | `true` | no |
| <a name="input_prometheus_enable_default_rule_groups"></a> [prometheus\_enable\_default\_rule\_groups](#input\_prometheus\_enable\_default\_rule\_groups) | Enable default recording rules for prometheus | `bool` | `true` | no |
| <a name="input_prometheus_default_rule_group_naming"></a> [prometheus\_default\_rule\_group\_naming](#input\_prometheus\_default\_rule\_group\_naming) | Resource names for the default recording rules | `map(string)` | <pre>{<br>  "kubernetes_recording": "DefaultKubernetesRecordingRuleGroup",<br>  "node_recording": "DefaultNodeRecordingRuleGroup"<br>}</pre> | no |
| <a name="input_prometheus_default_rule_group_interval"></a> [prometheus\_default\_rule\_group\_interval](#input\_prometheus\_default\_rule\_group\_interval) | Interval to run default recording rules in ISO 8601 format (between PT1M and PT15M) | `string` | `"PT1M"` | no |
| <a name="input_prometheus_rule_groups"></a> [prometheus\_rule\_groups](#input\_prometheus\_rule\_groups) | map(object({<br>  enabled     = Whether or not the rule group is enabled<br>  description = Description of the rule group<br>  interval    = Interval to run the rule group in ISO 8601 format (between PT1M and PT15M)<br><br>  recording\_rules = list(object({<br>    name       = Name of the recording rule<br>    enabled    = Whether or not the recording rule is enabled<br>    expression = PromQL expression for the time series value<br>    labels     = Labels to add to the time series<br>  }))<br><br>  alert\_rules = list(object({<br>    name = Name of the alerting rule<br>    action = optional(object({<br>      action\_group\_id = ID of the action group to send alerts to<br>    }))<br>    enabled    = Whether or not the alert rule is enabled<br>    expression = PromQL expression to evaluate<br>    for        = Amount of time the alert must be active before firing, represented in ISO 8601 duration format (i.e. PT5M)<br>    labels     = Labels to add to the alerts fired by this rule<br>    alert\_resolution = optional(object({<br>      auto\_resolved   = Whether or not to auto-resolve the alert after the condition is no longer true<br>      time\_to\_resolve = Amount of time to wait before auto-resolving the alert, represented in ISO 8601 duration format (i.e. PT5M)<br>    }))<br>    severity    = Severity of the alert, between 0 and 4<br>    annotations = Annotations to add to the alerts fired by this rule<br>  })) | <pre>map(object({<br>    enabled     = bool<br>    description = string<br>    interval    = string<br><br>    recording_rules = list(object({<br>      name       = string<br>      enabled    = bool<br>      expression = string<br>      labels     = map(string)<br>    }))<br><br>    alert_rules = list(object({<br>      name = string<br>      action = optional(object({<br>        action_group_id = string<br>      }))<br>      enabled    = bool<br>      expression = string<br>      for        = string<br>      labels     = map(string)<br>      alert_resolution = optional(object({<br>        auto_resolved   = optional(bool)<br>        time_to_resolve = optional(string)<br>      }))<br>      severity    = optional(number)<br>      annotations = optional(map(string))<br>    }))<br><br>    tags = optional(map(string), {})<br>  }))</pre> | `{}` | no |
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
