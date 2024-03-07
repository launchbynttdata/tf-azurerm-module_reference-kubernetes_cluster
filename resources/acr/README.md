# ACR

Azure Container Registry (ACR) is the Azure's offering of container registry to store and manage container images. ACR can be integrated with AKS to pull images from the registry. By default, ACR is public and can be accessed over the internet.
But ACR can be made private and can be integrated with AKS over private network with the help of Private endpoints.

## Integrate with Public ACR
It is very simple to integrate an AKS node pool with a Public ACR. In order for the Nodes in the pool to be able to pull images from the public ACR,
one needs to attach a role to the Node pool (kubelet) MSI as shown below

```shell
# Assigns an AcrPull policy to the MSI
az role assignment create --role "AcrPull" --assignee $MSI_PRINCIPAL_ID --scope $ACR_ID
```
## Integrate with Private ACR
Belows steps needs to be followed to integrate ACR privately with AKS.

An example to provision a Private ACR using terraform is provided [here](https://github.com/nexient-llc/tf-azurerm-module_primitive-private_endpoint/blob/main/examples/acr-private-endpoint/main.tf)

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

The ACR is now integrated to AKS over private network.

### Testing
- Push an image to ACR. When admin user is not enabled on ACR, you must assign IAM RBAC for either your SSO user or Service Principal. Then you can login to ACR using `docker login`. You also need to be inside a VM in the same VNet as AKS or ACR to abe able to reach the ACR instance.
- Modify your `deployment.yaml` to refer to this repository. You should see the image is pulled from the ACR.
