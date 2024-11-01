README
## Creating a Kubernetes Secret for AWS Credentials

This guide explains how to create a Kubernetes secret for AWS credentials using the `kubectl` command.

#### Prerequisites
- Kubernetes cluster
- `kubectl` command-line tool installed and configured to interact with your cluster
- AWS CLI installed and configured
- AWS credentials file located at `resources/ingress-nginx/multiple-ingress-controllers/public-ingress/aws/aws-credentials.ini`

### Steps

1. **Obtain AWS credentials:**

    Ensure you have your AWS credentials. You can configure them using the AWS CLI:

    ```shell
    aws configure
    ```

    Follow the prompts to enter your AWS Access Key ID, Secret Access Key, region, and output format.

2. Navigate to the directory containing your AWS credentials file:

```shell
cd resources/ingress-nginx/multiple-ingress-controllers/public-ingress/aws/
```

3. Create the Kubernetes secret:

Run the following command to create a secret named `aws-config-file-public` from the AWS credentials file:

```shell
kubectl create secret generic aws-config-file-public --from-file=aws-credentials.ini
```

This command will create a secret in your Kubernetes cluster that contains the AWS credentials.


3. Deploy the `external_dns` manifest file

    ```
   kube apply -f ../common/ingress-nginx/multiple-ingress-controllers/public-ingress/aws/aws-external-dns.yaml
   ```


4. Refers from step 4 until the end of file [azure readme](../azure/README.md)

### Verifying the Secret
To verify that the secret has been created successfully, you can use the following command:

```shell
kubectl get secret aws-config-file-public
```

This will display information about the secret, confirming its creation.

### Usage
You can now use this secret in your Kubernetes deployments, pods, or other resources that require access to AWS credentials.

### Cleanup
If you need to delete the secret, you can use the following command:

```shell
kubectl delete secret aws-config-file-public
```

This will remove the secret from your Kubernetes cluster.

By following these steps, you can securely manage your AWS credentials within your Kubernetes environment.
