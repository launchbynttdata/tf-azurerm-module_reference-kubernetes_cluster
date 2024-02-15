# Azure AD Integration with AKS

This guide will walk you through the process of integrating Azure AD with AKS.

In order to integrate AKS with Azure AD, the pre-requisite is to have a Azure AD group and at least one user assigned to that group.
The `object_id` of the group needs to be passed as parameter to `rbac_aad_admin_group_object_ids` in the terraform configuration.
It is important to have at least one group assigned to the AKS as some use needs to first log in to the AKS in order to create other roles and
role bindings to enable RBAC on the cluster. In absence of any local accounts (`local_account_disabled = true`),
user from the admin group will be used for the initial login to `kubectl`

Once the AKS cluster is provisioned using the below configuration, there are 2 types of credentials that can be fetched from the AKS cluster (while using terraform)

- Admin Credentials (`kube_admin_config_raw`): When Azure AD integration is enabled, this field is NOT EMPTY only when `local_account_disabled = false`
- User Credentials (`kube_config_raw`): This credential is used to login using the AD user credentials (For the users who are added to the groups passed in as inputs `rbac_aad_admin_group_object_ids`)

Using `az cli`

```shell
# -f - will print to stdout instead of merging to ~/.kube/config
# To fetch admin context credentials
$ az aks get-credentials -n <aks-name> -g <rg-name> -f - -a
# To fetch user context credentials
$ az aks get-credentials -n <aks-name> -g <rg-name> -f -
```
## Terraform inputs for Azure AD Integration

Below properties needs to be set to enable AAD integration
```hcl
rbac_aad_admin_group_object_ids = ["b12abc6e-6d8c-4810-87e9-386e3b6de04d"]
# Must be true to enable AAD integration
rbac_aad = true
# if false, then need to provide app_client_id and app_server_id (not recommended)
rbac_aad_managed = true
# is azure based rbac enabled. Equivalent to --enable-azure-rbac. it lets to use Azure AD user, groups in cluster role binding subjects
rbac_aad_azure_rbac_enabled = true
# default is always true
role_based_access_control_enabled = true
# If false, this lets you do this : terraform output -raw kube_admin_config_raw > aks_kubeconfig
local_account_disabled = false
```

## Types of supported RBAC

### Azure RBAC
- You need managed Microsoft Entra integration enabled on your cluster before you can add Azure RBAC `rbac_aad_azure_rbac_enabled = true`.
- Azure RBAC for Kubernetes Authorization requires that the Microsoft Entra tenant configured for authentication is same as the tenant for the subscription that holds your AKS cluster.
- Azure RBAC can be configured either in the `IAM` section of the AKS cluster or using Azure CLI `az role assignment create --role "Azure Kubernetes Service RBAC Reader" --assignee <user/group-id> --scope <aks_id>`
- Azure provides a list of built-in roles that can be assigned to the users or groups. The built-in roles are
  - `Azure Kubernetes Service RBAC Reader`
  - `Azure Kubernetes Service RBAC Writer`
  - `Azure Kubernetes Service RBAC Admin`
  - `Azure Kubernetes Service RBAC Cluster Admin`
  - Additional roles can be created using `az role definition create --role-definition <json-file>`
  ```
    {
      "Name": "AKS Deployment Reader",
      "Description": "Lets you view all deployments in cluster/namespace.",
      "Actions": [],
      "NotActions": [],
      "DataActions": [
          "Microsoft.ContainerService/managedClusters/apps/deployments/read"
      ],
      "NotDataActions": [],
      "assignableScopes": [
          "/subscriptions/<YOUR SUBSCRIPTION ID>"
      ]
    }
  ```
### Kubernetes RBAC
- Kubernetes RBAC is enabled by default during AKS cluster creation. `rbac_aad_azure_rbac_enabled = false` will disable Azure RBAC.
- Kubernetes RBAC can be configured using `kubectl` commands


### Local accounts
When you deploy an AKS cluster, local accounts are enabled by default. Even when you enable RBAC or Microsoft Entra integration, `--admin` access still exists as a non-auditable backdoor option.


If `local_account_disabled` is set to `true`, then the `kube_admin_config_raw` output will not be available.
Running the `az` command to fetch admin credentials will result in error
```shell
$ az aks get-credentials -n <aks-name> -g <rg-name> -f - -a
The behavior of this command has been altered by the following extension: aks-preview
(BadRequest) Getting static credential is not allowed because this cluster is set to disable local accounts.
Code: BadRequest
Message: Getting static credential is not allowed because this cluster is set to disable local accounts.
```

The Azure AD credentials can be fetched using

```shell
# -f - is used to fetch the credentials to standard output instead of merging to ~/.kube/config
# an optional --format=azure can be used to fetch the credentials in azure format
$ az aks get-credentials -n <aks-name> -g <rg-name> -f -
```


## Login to kubectl

In order to login using the user credentials, its essential to install `kubelogin` binary. [Kube Login](https://azure.github.io/kubelogin/concepts/login-modes/sp.html)
`kubelogin` can be installed using asdf

```
echo "kubelogin 0.1.0" >> ~/.tool-versions
asdf plugin add kubelogin
asdf install
```

**Note:**  `kubelogin` modifies the $KUBECONFIG file to add the user credentials. So, its essential to have a backup of the original kubeconfig file. Or fetch it using `terraform output` or `az aks get-credentials` command when you want to use `kubelogin` again for a different login.

### Using SSO user (interactive login)

Now once the above set up is done, if you want to run any kube command like `kube get nodes`
then just run the kubectl command. When executing this command for the first time,
it will prompt to open a link in the browser https://microsoft.com/devicelogin and then login using your `sso credentials`.
If the admin group attached to the AKS cluster contains your user, then you will be authenticated else an authentication error will be thrown.


When you run the `kube` command for the first time, it will ask you to open a browser and authenticate before you can run any other kubectl commands.
If the login is successful, the token in stored at `.kube/cache/kubelogin/`

### Using service principal (non-interactive login)
```
export AZURE_CLIENT_ID=<spn client id>
export AZURE_CLIENT_SECRET=<spn secret>
kubelogin convert-kubeconfig -l spn
```
No tokens are cached in case of service principal login

There is no straight forward way to verify if the user is logged in using this service principal. Check the `KUBECONFIG` file to see if `--login=spn` is added.


### Using az cli login
If you are already logged into azure using `az login`, and you want to use the same credentials to login to the AKS, then use the below command
```
kubelogin convert-kubeconfig -l azurecli
```

## References
1. [kubelogin](https://azure.github.io/kubelogin/concepts/login-modes.html)
2. [Readonly user AKS](https://stacksimplify.com/azure-aks/kubernetes-clusterrole-rolebinding-with-azure-aks/)
3. [Disable local accounts](https://learn.microsoft.com/en-us/azure/aks/manage-local-accounts-managed-azure-ad)
4. [Azure RBAC with AD](https://learn.microsoft.com/en-us/azure/aks/manage-azure-rbac)
5. [Kubernetes RBAC with AD](https://learn.microsoft.com/en-us/azure/aks/azure-ad-rbac?tabs=portal)
