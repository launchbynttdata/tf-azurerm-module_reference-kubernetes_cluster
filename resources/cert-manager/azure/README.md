# Cert-Manager for ingress-nginx

What we know is for cert-manager to be able to successfully provision certificates, it needs to validate the domain name (which we should control). The DNS zone should be `Public`. Currently, private DNS zones are not supported for cert-manager

## Installation (using helm)

- Install cert-manager using helm. Use `--installCRDs=true` to install CRDs with helm installation.
    ```shell

    helm repo add jetstack https://charts.jetstack.io
    helm repo update

    helm install \
      cert-manager jetstack/cert-manager \
      --namespace cert-manager \
      --create-namespace \
      --version v1.13.3 \
      --set installCRDs=true \
      --set extraArgs='{--dns01-recursive-nameservers-only,--dns01-recursive-nameservers=8.8.8.8:53\,1.1.1.1:53}'

    # https://stackoverflow.com/questions/60989753/cert-manager-is-failing-with-waiting-for-dns-01-challenge-propagation-could-not
     helm upgrade cert-manager jetstack/cert-manager \
        -n cert-manager --reuse-values \
        --set extraArgs='{--dns01-recursive-nameservers-only,--dns01-recursive-nameservers=8.8.8.8:53\,1.1.1.1:53}'

    ```
- Add `Role Assignments` to agentpool (kubenet) MSI for the public hosted zone
  ```shell
  # Get AKS Kubelet Identity
  PRINCIPAL_ID=$(az aks show -n $CLUSTERNAME -g $CLUSTER_GROUP --query "identityProfile.kubeletidentity.objectId" -o tsv)
  MSI_PRINCIPAL_ID="63babdcc-a0e7-4cac-a305-784df0ab41e2"
  # Get existing DNS Zone Id
  ZONE_ID=$(az network dns zone show --name $ZONE_NAME --resource-group $ZONE_GROUP --query "id" -o tsv)
  PUBLIC_ZONE_ID="/subscriptions/e71eb3cd-83f2-46eb-8f47-3b779e27672f/resourceGroups/public-dns-eastus-rg-000/providers/Microsoft.Network/dnszones/sandbox.launch.dresdencraft.com"
  PUBLIC_ZONE_ID="/subscriptions/e71eb3cd-83f2-46eb-8f47-3b779e27672f/resourceGroups/public-dns-eastus-rg-000/providers/Microsoft.Network/dnszones/launch.dresdencraft.com"
  # Create role assignment
  az role assignment create --role "DNS Zone Contributor" --assignee $MSI_PRINCIPAL_ID --scope $PUBLIC_ZONE_ID
  ```
- Create Issuers
  - Issues must be created after installing `cert-manager` as the CRDs required for Issuers are installed with cert-manager
  - We are creating `ClusterIssuer` which is applicable for the entire cluster. The normal `Issuer` is per namespace. We have to make sure that the certs are provisioned in the same namespace as the Issuer.
  - In the Issuer CRD `spec.acme.server`, we can have `staging` or `prod` URL. The difference is that when using `staging` url, the client will give a certificate error. As the staging CA is not included as a trusted CA in browsers and clients.
  - Looks like we have to use `DNS01` solver with Cluster Issue for our use case, since we are trying to generate public certs that would need changelles to be accepted by a Public DNS zone and the service endpoints are associated with private DNS records (private DNS has the same name as public dns zone)
  - DNS solver is provided access to the Public dns zone by using kubenet MSI. MSI must have `"DNS Zone Contributor"` role on the DNS zone. Other methods can also be used as shown in https://cert-manager.io/docs/configuration/acme/dns01/azuredns/
    ```shell
    kube apply -f ../common/ingress-nginx/cert-manager/issuers

    ```

## Concepts
1. Issuer: In `cert-manager` terms, `Issuer` is the Certificate Authority (CA) that signs the certificates that are provisioned for application ingresses. Cert-Manager supports various kinds of Issuer like `ACME, CA, Vault, Self-signed` etc.
2. Solver: For Issue of type `ACME`, there are 2 ways that the domain ownership can be verified as shown below
   - HTTP Solver: In this type, cert-manager performs a HTTP call to verify domain ownership.
   - DNS Solver: Cert-manager creates a `txt record` in the configured DNS Zone as a `challenge` and if successful, the domain ownership is verified
   ```yaml
      - dns01:
          azureDNS:
            subscriptionID: e71eb3cd-83f2-46eb-8f47-3b779e27672f
            resourceGroupName: public-dns-eastus-rg-000
            hostedZoneName: sandbox.launch.dresdencraft.com
            # Azure Cloud Environment, default to AzurePublicCloud
            environment: AzurePublicCloud
            # optional, only required if node pools have more than 1 managed identity assigned
            managedIdentity:
              # client id of the node pool managed identity (can not be set at the same time as resourceID)
              clientID: 3a8999ad-2d96-4002-b52b-5ca1b26f4f42
              # resource id of the managed identity (can not be set at the same time as clientID)
              # resourceID: YOUR_MANAGED_IDENTITY_RESOURCE_ID
    ```
2. When an ingress is created, with a `tls` block defined, cert-manager picks up and requests a cert from Let's Encrypt
   - A certificate request is created `kube get certificaterequest`
   - A challenge is created, which will try to create a txt record in the provided public DNS. `kube get challenge`. This record will disapper when the challenge is approved. Till then, the record can be found in `Pending` state
   - A certificate resource is created which can be fetched using `kube get certificate`. The certificate is provisioned when `Ready=True`. Until then, the certificate is not provisioned.
   - A secret is created by the same name provided in the `Ingress` manifest `SecretName`. Use `kube get secret` to find the secret. This secret will contain the private key and the cert.
    ```
    kube get secret <secret_name> -o jsonpath='{.data}' | jq
   ```
3. Logs can be seen in the cert-manager pod in the `cert-manager` namespace. `kube logs -f <cert_manager_pod_name> -n cert_manager

## Troubleshooting
1.  If the below logs are found
    ```
    time="2024-01-11T03:20:17Z" level=info msg="Ignoring changes to 'extdnspublic-public-app.launch.dresdencraft.com' because a suitable Azure DNS zone was not found."`
    ```
    Make sure the Role assignment for the DNS zone is provided for the kubenet MSI
2. If the external-dns pod doesn't pick up the recent addition of `Role Assignment`, refresh the credentials. Kill the pod and recreate
3. In case there are multiple public DNS zones to be used for certificate provisioning, there is no way to create 1 cluster-issuer for all public DNS zones. 1 issuer per dns zone has to be configured. And the same issuer needs to be provided as annotation in the `ingress` resource as `cert-manager.io/cluster-issuer: "letsencrypt-launch-cluster"`
4. Logs for issued certificate
    ```
   I0111 04:02:10.556135       1 acme.go:233] "cert-manager/certificaterequests-issuer-acme/sign: certificate issued" resource_name="hello-world-ingress-public-2-tls-1" resource_namespace="default" resource_kind="CertificateRequest" resource_version="v1" related_resource_name="hello-world-ingress-public-2-tls-1-2083363015" related_resource_namespace="default" related_resource_kind="Order" related_resource_version="v1"
    I0111 04:02:10.556249       1 conditions.go:252] Found status change for CertificateRequest "hello-world-ingress-public-2-tls-1" condition "Ready": "False" -> "True"; setting lastTransitionTime to 2024-01-11 04:02:10.556242816 +0000 UTC m=+1140.367254680
    I0111 04:02:10.609948       1 conditions.go:192] Found status change for Certificate "hello-world-ingress-public-2-tls" condition "Ready": "False" -> "True"; setting lastTransitionTime to 2024-01-11 04:02:10.609940956 +0000 UTC m=+1140.420952920
   ```
## Important Links
- https://cert-manager.io/docs/tutorials/acme/nginx-ingress/
- https://stackoverflow.com/questions/60989753/cert-manager-is-failing-with-waiting-for-dns-01-challenge-propagation-could-not
- https://community.letsencrypt.org/t/lets-encrypt-and-azure-private-dns-zones/187678
