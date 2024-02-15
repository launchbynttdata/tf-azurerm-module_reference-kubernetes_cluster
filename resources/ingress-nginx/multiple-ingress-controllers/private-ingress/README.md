# Overview

Create a private `ingress-nginx` controller in the `private-ingress` namespace using Helm

## Private Ingress

By Private Ingress we mean the `nginx controller` will be assigned a private IP address picked from the VNET associated
with the DNS Zone (passed as input while creating the `ingress-nginx` helm release).
This private IP will be assigned to an internal load balancer (created automatically and managed by AKS
named `kubernetes-internal`).
When an `ingress` resource is created, that would refer to this private ingress (done by annotation
`ingress.class` on the ingress metadata), an A-record would be created in
the associated private DNS zone.

## Pre-requisites
- A k8s cluster already exists
- `kubectl` is configured with AKS credentials
- A private DNS zone already exists in a resource group.
- A VNET already exists and is associated with the Private DNS zone. This is required for `external-dns` to map ip-address to DNS records (A record). In case you are using custom Vnet for k8s cluster, the DNS Zone can be linked with the same Vnet instead of a separate one.
- A `Role Assignment` is already created in Kubelet MSI to provider `Private DNS Zone Contributer` role on the Private zone created above
- A `Role Assignment` of `Reader` on the DNS Zone RG
   ```
  RG_ID="/subscriptions/e71eb3cd-83f2-46eb-8f47-3b779e27672f/resourceGroups/ext-dns-rg"
  PRIVATE_ZONE_ID="/subscriptions/e71eb3cd-83f2-46eb-8f47-3b779e27672f/resourceGroups/ext-dns-rg/providers/Microsoft.Network/privateDnsZones/sandbox.launch.dresdencraft.com"
  MSI_PRINCIPAL_ID="7d9dd4a5-6a3e-4791-9dce-1b41d5bd86ac"
  az role assignment create \
    --role "Private DNS Zone Contributor" \
    --assignee $MSI_PRINCIPAL_ID \
    --scope $PRIVATE_ZONE_ID

  az role assignment create \
    --role "Reader" \
    --assignee $MSI_PRINCIPAL_ID \
    --scope $RG_ID
  ```

## Install private ingress

1. Create a `azure.json` file and fill up all the necessary details. `userAssignedIdentityID` should be the Kubenet MSI client ID
   ```shell
      cat <<-EOF > azure.json
      {
        "tenantId": "$(az account show --query tenantId -o tsv)",
        "subscriptionId": "$(az account show --query id -o tsv)",
        "resourceGroup": "$AZURE_DNS_ZONE_RESOURCE_GROUP",
        "useManagedIdentityExtension": true,
        "userAssignedIdentityID": "$IDENTITY_CLIENT_ID"
      }
      EOF
   ```
2. Create a secret using the above `azure.json`. This secret is consumed by `external-dns` module defined in step [3]
    ```
   kubectl create secret generic azure-config-file-private \
     --from-file="../common/ingress-nginx/multiple-ingress-controllers/private-ingress/azure.json"
   ```
3. Deploy the `external_dns` manifest file

   This module is responsible to create a DNS record with the associated private DNS Zone. the [external-dns.yaml](external-dns.yaml) file contains details regarding the private DNS zone and resource group.

   ```
   kube apply -f ../common/ingress-nginx/multiple-ingress-controllers/private-ingress/external-dns.yaml
   ```
4. Find an available ip-address in the k8s subnet to assign to the internal Load Balancer. Then create a `values.yaml` file

   Doing this will ensure that the IP address associated with the ingress controller is static and wouldn't change if the ingress controller is deleted and recreated
   ```shell
   az network vnet subnet list-available-ips \
     --resource-group MC_ex-k8s-7265-eastus-dev-000-rg-000_ex-k8s-7265-dev-000-aks_eastus \
     --vnet-name aks-vnet-40873077 \
     -n aks-subnet

   # 10.224.0.63
   ```
5. Deploy ingress-nginx
   The file [private-ingress-values.yaml](private-ingress-values.yaml) contains values (complex object not suitable to pass through the `--set` command) to be passed to the helm release

   ```shell
      helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
      helm repo update
      helm install private-ingress-nginx ingress-nginx/ingress-nginx \
        --namespace private-ingress \
        --create-namespace \
        -f ../common/ingress-nginx/multiple-ingress-controllers/private-ingress/private-ingress-values.yaml  \
        --set controller.ingressClassResource.controllerValue=k8s.io/private-ingress-nginx \
        --set controller.ingressClass=private-ingress \
        --set controller.ingressClassResource.name=private-ingress \
        --set controller.replicaCount=1 \
        --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux  \
        --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux \
        --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz
   ```
Once the deployment is successful, you can check the helm release using the command
```shell
$ helm list -n private-ingress
NAME                    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
private-ingress-nginx    private-ingress  2               2024-01-10 16:22:51.914314 -0500 EST    deployed        ingress-nginx-4.9.0     1.9.5
```

Check the controller service for the assigned IP Address
```shell
$ kube get svc -n private-ingress
NAME                                        TYPE           CLUSTER-IP     EXTERNAL-IP    PORT(S)                      AGE
private-ingress-nginx-controller             LoadBalancer   10.0.181.211   10.0.0.8   80:30506/TCP,443:32157/TCP   22h
private-ingress-nginx-controller-admission   ClusterIP      10.0.253.64    <none>         443/TCP                      22h

```

## Testing
At this point, the ingress controller is ready to serve requests to create ingress objects. You need to deploy a sample  [application](../sample-app) and create an ingress resource as provided in [ingress-resources](./ingress-resources)

### Verify the sample app
Since, this is a private DNS, we cannot `curl` the app.k8s.com from our local laptop. We can test it in couple of ways
- Create a VM in the VNET(any subnets) that is associated with the K8s Cluster (the load-balancer ip is routable from the VM IP). The `Private DNS zone` must be linked with this `Vnet` to resolve DNS queries. SSH into that vm and Curl and nslookup from in there
- If AKS network plugin is `Azure CNI` (also works for `kubenet` not sure how), that means each pod will be assigned an IP address from the associated VNet. In that case, create a Virtual Network Link from the DNS Zone to the AKS Vnet. Then create a pod as shown below for testing
    ```shell
  kubectl run -it --rm aks-ingress-test \
      --image=mcr.microsoft.com/dotnet/runtime-deps:6.0

  # Once you get the command prompt
  apt update && apt install curl dnsutils -y

  $ nslookup app.k8s.com
    Server:         10.0.0.10
    Address:        10.0.0.10#53

    Non-authoritative answer:
    Name:   app.k8s.com
    Address: 10.224.0.62

  curl app.k8s.com
  ```
