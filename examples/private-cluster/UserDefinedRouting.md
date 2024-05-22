# User Defined Routing (UDR)

By default, the AKS cluster uses a public Standard Load Balancer for its outbound traffic. Whenever its not suitable for clients to provision a public Load Balancer, Azure provides an option for UDR using custom route table and Azure Firewall

## Create Resource Group
Create a resource group from VNet and Azure Firewall

## Create Vnet
Create a VNet with atleast 2 subnets
- Subnet for AKS
- Subnet for Azure Firewall

## Create an Azure Firewall

Rules for Azure Firewall

- Create a standard Public IP address for the Azure Firewall
- A Resource group to host both the Vnet and the Azure Firewall
  - They must be in the same resource group
- **Note**: Now the AKS and the Firewall may be in different Vnets and Resource Groups. If that is the case, the Vnet must be peered with the Vnet that hosts the AKS
- Create a Vnet and a subnet for the Azure Firewall
  - The subnet must be named `AzureFirewallSubnet`
  - The subnet must be a `/26`
- Create an Azure Firewall
  - Enable DNS Proxying


Currently, I created the Azure Firewall using the portal. But, it can be created using Azure CLI as well.

```bash
# Create Public IP
az network public-ip create --resource-group $RG -n $FWPUBLICIP_NAME --location $LOC --sku "Standard"
# Add the firewall extension to Azure CLI
az extension add --name azure-firewall
# Create Azure Firewall (--enable-dns-proxy is required)
az network firewall create --resource-group $RG --name $FWNAME --location $LOC --enable-dns-proxy true
# Assign Public IP with the Firewall
az network firewall ip-config create --resource-group $RG --firewall-name $FWNAME --name $FWIPCONFIG_NAME \
  --public-ip-address $FWPUBLICIP_NAME --vnet-name $VNET_NAME

# Capture the public and private IPs for later use
FWPUBLIC_IP=$(az network public-ip show --resource-group $RG --name $FWPUBLICIP_NAME --query "ipAddress" -o tsv)
FWPRIVATE_IP=$(az network firewall show --resource-group $RG --name $FWNAME --query "ipConfigurations[0].privateIPAddress" -o tsv)
```

### Firewall Rules
Set the below rules for the Azure Firewall
```bash
RG="dso-net-eus-sandbox-000-rg-000"
FWNAME="fdc-fw-000"
LOC="eastus"
FWROUTE_TABLE_NAME="k8s-udr-route-table"
````

#### Network Rules

```bash
# The options --action allow --priority 100 are required to create the collection
# Not required for private cluster
# az network firewall network-rule create --resource-group $RG --firewall-name $FWNAME --collection-name 'aksfwnr' --name 'apiudp' --protocols 'UDP' --source-addresses '*' --destination-addresses "AzureCloud.$LOC" --destination-ports 1194 --action allow --priority 100
# Not required for private cluster
# az network firewall network-rule create --resource-group $RG --firewall-name $FWNAME --collection-name 'aksfwnr' --name 'apitcp' --protocols 'TCP' --source-addresses '*' --destination-addresses "AzureCloud.$LOC" --destination-ports 9000

az network firewall network-rule create --resource-group $RG --firewall-name $FWNAME --collection-name 'aksfwnr' --name 'time' --protocols 'UDP' --source-addresses '*' --destination-fqdns 'ntp.ubuntu.com' --destination-ports 123 --action allow --priority 100

az network firewall network-rule create --resource-group $RG --firewall-name $FWNAME --collection-name 'aksfwnr' --name 'ghcr' --protocols 'TCP' --source-addresses '*' --destination-fqdns ghcr.io pkg-containers.githubusercontent.com --destination-ports '443'

az network firewall network-rule create --resource-group $RG --firewall-name $FWNAME --collection-name 'aksfwnr' --name 'docker' --protocols 'TCP' --source-addresses '*' --destination-fqdns docker.io registry-1.docker.io production.cloudflare.docker.com --destination-ports '443'
```

#### Application Rule

```bash
az network firewall application-rule create --resource-group $RG --firewall-name $FWNAME --collection-name 'aksfwar' \
  --name 'fqdn' --source-addresses '*' --protocols 'http=80' 'https=443' --fqdn-tags "AzureKubernetesService" \
  --action allow --priority 100

```

## Route Table

Rules for route table
- Route table must be associated with the Subnet before creating the AKS cluster
- The associated route table cannot be updated after the AKS cluster is created
- Each AKS cluster must use a single, unique route table for all subnets associated with the cluster
- Using the same route table with multiple AKS clusters isn't supported because of the potential for conflicting routes
- The AKS cluster MSI must have write permissions to the route table in case of `kubenet` network plugin to create the routes between pods and nodes
- the route table must have a route for `0.0.0.0/0` to a Virtual Appliance as next hop. AKS verifies the existence of this route before creating the cluster

Create a route table and associate it with the AKS subnet

```bash

az network route-table create --resource-group $RG --location $LOC --name $FWROUTE_TABLE_NAME
```

### Create Routes

```bash
# Get the private and public IP address of the firewall

FWPUBLIC_IP=$(az network public-ip show --resource-group $RG --name $FWPUBLICIP_NAME --query "ipAddress" -o tsv)
FWPRIVATE_IP=$(az network firewall show --resource-group $RG --name $FWNAME --query "ipConfigurations[0].privateIPAddress" -o tsv)


az network route-table route create --resource-group $RG --name $FWROUTE_NAME --route-table-name $FWROUTE_TABLE_NAME \
  --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address $FWPRIVATE_IP
# This seemed to be redundant after testing
#az network route-table route create --resource-group $RG --name $FWROUTE_NAME_INTERNET --route-table-name $FWROUTE_TABLE_NAME \
#  --address-prefix $FWPUBLIC_IP/32 --next-hop-type Internet
```

## Assign Route table to AKS Subnet

```bash
az network vnet subnet update --resource-group $RG --vnet-name $VNET_NAME --name $AKSSUBNET_NAME --route-table $FWROUTE_TABLE_NAME
```

## Provision AKS (using Terraform)

Rules for AKS
- Must create a User Managed Identity for the cluster using `kubenet` and UDR. It must have permissions on the subnet and the route table
- The route table must exist with the route for `0.0.0.0/0`
- The Firewall must exist with the firewall rules to allow traffic to pull images and sync time, also have application rule set to communicate with AKS
- In case of private cluster, specific network rules to communicate with AKS API server is not required.


AKS using terraform would need the following input parameters

A sample tfvars file can be found at [udf.tfvars](../../sample-tfvars/udr.tfvars)

```hcl
net_profile_outbound_type  = "userDefinedRouting"

vnet_subnet_id = "<subnet_id>"
# kubenet or azure
network_plugin = "kubenet"

# private cluster
private_cluster_enabled = true

# UserAssigned or SystemAssigned
# In either case, the MSI will be created by this module
identity_type = "UserAssigned"
```

# References

1. [AKS UDR](https://learn.microsoft.com/en-us/azure/aks/limit-egress-traffic?tabs=aks-with-user-assigned-identities)
2. [Fully Private AKS - Medium blog](https://denniszielke.medium.com/fully-private-aks-clusters-without-any-public-ips-finally-7f5688411184)
3. [AKS Outbound Traffic Rules](https://learn.microsoft.com/en-us/azure/aks/outbound-rules-control-egress)
4. [Kubenet Routing with BYO Vnet](https://learn.microsoft.com/en-us/azure/aks/configure-kubenet#bring-your-own-subnet-and-route-table-with-kubenet)
5. [Vnet UDR](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-udr-overview)
