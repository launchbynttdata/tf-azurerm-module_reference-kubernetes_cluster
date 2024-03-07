# Workload Identity

Workloads deployed on an Azure Kubernetes Services (AKS) cluster require Microsoft Entra application credentials or managed identities to access Microsoft Entra protected resources, such as Azure Key Vault and Microsoft Graph. Microsoft Entra Workload ID integrates with the capabilities native to Kubernetes to federate with external identity providers.

A Kubernetes token is issued and OIDC federation enables Kubernetes applications to access Azure resources securely with Microsoft Entra ID based on annotated service accounts.

Microsoft Entra Workload ID works especially well with the [Azure Identity client libraries](https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview?tabs=dotnet#azure-identity-client-libraries)
and the [Microsoft Authentication Library (MSAL)](https://learn.microsoft.com/en-us/azure/active-directory/develop/msal-overview) collection if you're using application registration.

## Using Azure Identity client libraries
The workload identity injects environment variables inside the pods that are running on the AKS cluster. The environment variables are used to authenticate with Azure services. The following example demonstrates how to use the Azure Identity client libraries to authenticate with Azure Key Vault.
The `NewDefaultAzureCredential()` function uses the environment variables to authenticate with Azure services.
```go
package main

import (
	"context"
	"os"

	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/Azure/azure-sdk-for-go/sdk/security/keyvault/azsecrets"
	"k8s.io/klog/v2"
)

func main() {
	keyVaultUrl := os.Getenv("KEYVAULT_URL")
	secretName := os.Getenv("SECRET_NAME")

	credential, err := azidentity.NewDefaultAzureCredential(nil)
	if err != nil {
		klog.Fatal(err)
	}

	client, err := azsecrets.NewClient(keyVaultUrl, credential, nil)
	if err != nil {
		klog.Fatal(err)
	}

	secret, err := client.GetSecret(context.Background(), secretName, "", nil)
	if err != nil {
		klog.ErrorS(err, "failed to get secret", "keyvault", keyVaultUrl, "secretName", secretName)
		os.Exit(1)
	}
}
```

The following environment variables are injected into the pods by the workload identity:

```shell
AZURE_TENANT_ID="<tenant_id>"
AZURE_SUBSCRIPTION_ID="<subscription_id>"
AZURE_FEDERATED_TOKEN_FILE=/var/run/secrets/azure/tokens/azure-identity-token
AZURE_AUTHORITY_HOST=https://login.microsoftonline.com/
AZURE_CLIENT_ID="<client_id_of_msi_associated_with_workload_identity>"
```

## Limitations
- You can only have 20 federated identity credentials per managed identity.
- It takes a few seconds for the federated identity credential to be propagated after being initially added.
- Virtual nodes add on, based on the open source project Virtual Kubelet, isn't supported.
- Creation of federated identity credentials is not supported on user-assigned managed identities in these regions.

## Enable on AKS cluster
While using terraform, the following inputs variables must be enabled to use the workload identity feature on the AKS cluster.
```hcl
  # OIDC must be enable for workload identity
  oidc_issuer_enabled = true
  enable_workload_identity = true
```

## Configure AKS to use Workload Identity

Once Workload Identity is enabled on the AKS cluster as shown in the previous step,
you need to follow the below steps to use it in your application.

### Retrieve the OIDC issuer URL
```
terraform output oidc_issuer
```
### Create Managed Identity
Create a Managed Identity using either the Azure portal or the Azure CLI or terraform.
```shell
USER_ASSIGNED_IDENTITY_NAME="k8s-workload-identity"
LOCATION="eastus"
RESOURCE_GROUP="fdoc-k8s-eastus-dev-001-rg-001"
az identity create --name "${USER_ASSIGNED_IDENTITY_NAME}" \
  --resource-group "${RESOURCE_GROUP}" --location "${LOCATION}"
```

### Create Kubernetes Service Account
Service account is namespace scoped, so you need to create a service account in the same namespace as your application.

```yaml
# USER_ASSIGNED_CLIENT_ID=$(az identity show --name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --query clientId -o tsv)
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: "${USER_ASSIGNED_CLIENT_ID}"
  name: "${SERVICE_ACCOUNT_NAME}"
  namespace: "${SERVICE_ACCOUNT_NAMESPACE}"
```
### Establish Federated identity Credentials
Use the az identity federated-credential create command to create the federated identity credential between the managed identity, the service account issuer, and the subject.

```shell
FEDERATED_IDENTITY_CREDENTIAL_NAME="k8s-workload-identity-credential"
USER_ASSIGNED_IDENTITY_NAME="k8s-workload-identity"
RESOURCE_GROUP="fdoc-k8s-eastus-dev-001-rg-001"
SERVICE_ACCOUNT_NAMESPACE="default"
SERVICE_ACCOUNT_NAME="workload-identity-sa"
# AKS_OIDC_ISSUER=$(terraform output oidc_issuer)
AKS_OIDC_ISSUER="https://eastus.oic.prod-aks.azure.com/c5836784-c046-4f73-9e7e-9c370262e295/5496bbb4-5c8a-4064-94a5-127193eace1f/"
az identity federated-credential create --name ${FEDERATED_IDENTITY_CREDENTIAL_NAME} \
  --identity-name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" \
  --issuer "${AKS_OIDC_ISSUER}" --subject system:serviceaccount:"${SERVICE_ACCOUNT_NAMESPACE}":"${SERVICE_ACCOUNT_NAME}" \
  --audience api://AzureADTokenExchange


az role assignment create --role "Contributor" --scope "/subscriptions/e71eb3cd-83f2-46eb-8f47-3b779e27672f" \
  --assignee $(az identity show --name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --query principalId -o tsv)
```
**Note:** It takes a few seconds for the federated identity credential to be propagated after being initially added. If a token request is made
immediately after adding the federated identity credential, it might lead to failure for a couple of minutes as the cache is populated
in the directory with old data. To avoid this issue, you can add a slight delay after adding the federated identity credential.

### Deploy your application

Now the workload Identity can be referred to in the pods to authenticate to Azure services. The following example demonstrates how to use the workload identity in the pod.


```yaml
apiVersion: v1
kind: Pod
metadata:
  name: your-pod
  namespace: "${SERVICE_ACCOUNT_NAMESPACE}"
  labels:
    azure.workload.identity/use: "true"  # Required, only the pods with this label can use workload identity
spec:
  serviceAccountName: "${SERVICE_ACCOUNT_NAME}"
  containers:
    - image: <your image>
      name: <containerName>
```
