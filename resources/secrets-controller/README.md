# Key Vault integration with k8s secrets

### Enable CSI secret addon in AKS
When provisioning through terraform select `var.key_vault_secrets_provider_enabled=true`. This will add a Managed Identity (MSI) for key vault in the nodes RG.
The terraform will also create a key vault

### Create a keyvault
This AKS module creates a key vault automatically when `var.key_vault_secrets_provider_enabled=true` which can be retrieved using output `key_vault_id`

### Assign role to AKS Keyvault MSI

```shell
IDENTITY_OBJECT_ID=$(terraform  output -json key_vault_secrets_provider | jq -r ".[].object_id")
KEYVAULT_SCOPE=$(terraform output key_vault_id)
az role assignment create --role "Key Vault Administrator" --assignee $IDENTITY_OBJECT_ID --scope $KEYVAULT_SCOPE

```

### Create secret-provider-class
Create a `CRD` [secret-provider-class](./secret-provider-class.yaml) that would refer the key vault created above and point to various secret/cert/key created in that vault

### Test the key vault
Create a pod/deployment that would refer to the `secret-provider-class` and either mount the secrets as volume or assign them to environment variables

**Note**: The kubernetes secrets are automatically created when a pod is created for the first time. If there are no pods refering to those secrets, the secrets are automatically deleted.
## Important Links
1. [csi-secrets-store-driver](https://learn.microsoft.com/en-us/azure/aks/csi-secrets-store-driver)
