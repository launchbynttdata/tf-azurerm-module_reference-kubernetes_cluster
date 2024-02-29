# Azure AD Integration with AKS

This guide will walk you through the process of integrating Azure AD with AKS. Once enabled, the users of an organization
can use their AD credentials or Single-sign-on (SSO) to login to the AKS cluster using `kubectl`. The access of the users and groups can be
controlled using RBAC types supported by Azure.

Note that `Azure AD integration` is different from [Pod managed Identities](https://learn.microsoft.com/en-us/azure/aks/use-azure-ad-pod-identity). The former is used to authenticate/authorize users to the cluster,
while the latter is used to authenticate the pods to the Azure resources and comes under Application Security.

## Prerequisites

1. Access to Azure AD (Microsoft Entra ID) to create users, groups and service principals

2. Must have at least 1 Azure AD group and one AD user/service-principal assigned to that AD group.

3. The AKS mandates that for AD integration, the `object_id` of at least 1 AD group be passed as parameter to `rbac_aad_admin_group_object_ids` in the terraform configuration.

In absence of any local accounts ( when `local_account_disabled = true`), only users from this AD group can login to `kubectl`.
Some user from this group needs to first login to `kubectl` and create k8s RBAC roles/rolebindings to provide other users access to the cluster.


## AKS Credentials
AKS by default provide 2 set of users to interact with the cluster via `kubectl`

- **Admin Credentials (terraform output: `kube_admin_config_raw`):** When Azure AD integration is enabled (`rbac_aad = true`) and `local_account_disabled = false`, this credential is available to login to the cluster. It has full admin access to the cluster
- **User Credentials (terraform output: `kube_config_raw`):** This credential is used to login using the AD user credentials (For the users who are added to the groups passed in as inputs `rbac_aad_admin_group_object_ids`)

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
### Kubernetes RBAC (our preferred method)

- Kubernetes RBAC is enabled by default during AKS cluster creation. `rbac_aad_azure_rbac_enabled = false` will disable Azure RBAC.
- Kubernetes RBAC can be configured using `kubectl` commands
- This is our preferred method of RBAC as the other method requires the Azure AD to be in the same tenant as the AKS, which may not be the case always.

Examples of RBAC roles and bindings can be found as shown below
- Read only access to the cluster [read-only-role](./read-only-role.yaml)
- Complete access to a specific namespace [dev1-user-role](./dev1-user-role.yaml)


### Local accounts

When you deploy an AKS cluster, local accounts are enabled by default. Even when you enable RBAC or Microsoft Entra integration,
`--admin` access still exists as a non-auditable backdoor option.


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

With AD enabled, its mandatory to install `kubelogin` binary to be able to login to `kubectl` using your SSO credentials. [Kube Login](https://azure.github.io/kubelogin/concepts/login-modes/sp.html)

`kubelogin` can be installed using asdf

```
echo "kubelogin 0.1.0" >> ~/.tool-versions
asdf plugin add kubelogin
asdf install
```

**Note:**  `kubelogin` modifies the $KUBECONFIG file to add the user credentials. So, its essential to have a backup of the original kubeconfig file.
Or fetch it using `terraform output` or `az aks get-credentials` command when you want to use `kubelogin` again for a different login.

### Using SSO user (interactive login)

To login to the `kubectl` using your SSO, you can  do `kubelogin convert-kubeconfig`. This defaults to the type `devicecode`, meaning this command will display
a device code in the console and ask you to open an URL in the browser to confirm this device code and then redirect you to login using your SSO.

You can also skip the above step and just run any kubectl command like `kube get nodes`. This will also take you through the same process as described above.

When executing this command for the first time, a device code will be displayed in the console, and it will prompt to open a link in the browser https://microsoft.com/devicelogin.
User needs to paste the device code in the browser upon which will be redirected to enter the `sso credentials`.
If the user is authorized (part of the admin AD group), then they will be authenticated else an authentication error will be thrown.

Upon successful login, the token is cached at `~/.kube/cache/kubelogin/` and the `KUBECONFIG` file is modified to add the user credentials.

### Using service principal (non-interactive login)

This mode is very useful while running the kubectl commands in a CI/CD pipeline or authenticating inside the code where
user interaction is not permitted

```shell

export AZURE_CLIENT_ID=<spn client id>
export AZURE_CLIENT_SECRET=<spn secret>
kubelogin convert-kubeconfig -l spn

## Or
kubelogin convert-kubeconfig -l spn   \
  --client-id=<client_id>  \
  --client-secret=<client_secret>
```
No tokens are cached in case of service principal login

There is no straight forward way to verify if the user is logged in using this service principal.
Check the `KUBECONFIG` file to see if `--login=spn` is added.


### Using az cli login

If you are already logged into azure using `az login`, and you want to use the same credentials to login to the AKS, then use the below command
```
kubelogin convert-kubeconfig -l azurecli
```

**Note:** It is often tricky when you try to test out things by login in using different methods - device_code, service-principal, azcli etc.
Remember to fetch the credentials each time using `terraform output` or `az aks get-credentials` before trying a different mode of login.

## References
1. [kubelogin](https://azure.github.io/kubelogin/concepts/login-modes.html)
2. [Readonly user AKS](https://stacksimplify.com/azure-aks/kubernetes-clusterrole-rolebinding-with-azure-aks/)
3. [Disable local accounts](https://learn.microsoft.com/en-us/azure/aks/manage-local-accounts-managed-azure-ad)
4. [Azure RBAC with AD](https://learn.microsoft.com/en-us/azure/aks/manage-azure-rbac)
5. [Kubernetes RBAC with AD](https://learn.microsoft.com/en-us/azure/aks/azure-ad-rbac?tabs=portal)
