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




4. In case you want the public IP attached to the load balancer `kubernetes` that is associated with the public ingress controller to be static, we need to reserve a static IP
5. Deploy public ingress-nginx

   ```shell
      helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
      helm repo update
      # The azure-load-balancer-health-probe-request-path is very important for public ingress
      helm install public-ingress-nginx ingress-nginx/ingress-nginx \
      --namespace public-ingress \
      --create-namespace \
      --set controller.replicaCount=1 \
      --set controller.ingressClassResource.controllerValue=k8s.io/public-ingress-nginx \
      --set controller.ingressClass=public-ingress \
      --set controller.ingressClassResource.name=public-ingress \
      --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz \
      --set controller.allowSnippetAnnotations=true

   ```

Once the deployment is successful, you can check the helm release using the command

```shell
$ helm list -n public-ingress
NAME                    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
public-ingress-nginx    public-ingress  2               2024-01-10 16:22:51.914314 -0500 EST    deployed        ingress-nginx-4.9.0     1.9.5
```

Check the controller service for the assigned IP Address

```shell
$ kube get svc -n public-ingress
NAME                                        TYPE           CLUSTER-IP     EXTERNAL-IP    PORT(S)                      AGE
public-ingress-nginx-controller             LoadBalancer   10.0.181.211   4.156.171.98   80:30506/TCP,443:32157/TCP   22h
public-ingress-nginx-controller-admission   ClusterIP      10.0.253.64    <none>         443/TCP                      22h

```

## Testing

At this point, the ingress controller is ready to serve requests to create ingress objects. You need to deploy a sample  [application](../../sample-app/) and create an ingress resource as provided in [ingress-resources](./ingress-resources/)
