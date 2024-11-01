# AWS Credentials Secret

This README provides instructions on how to create a Kubernetes secret named `aws-credentials` using `kubectl`. The secret will contain AWS access key and secret access key.

## Prerequisites

Before proceeding, make sure you have the following:

- `kubectl` installed and configured to connect to your Kubernetes cluster.
- AWS access key and secret access key.

## Steps

1. Open a terminal or command prompt.

2. Run the following command to create the secret:

```shell
kubectl create secret generic aws-credentials \
 --from-literal=access-key-id=$ACCESS_KEY \
 --from-literal=secret-access-key=$SECRET_ACCESS_KEY \
  -n cert-manager
```

Replace `$ACCESS_KEY` and `$SECRET_ACCESS_KEY` with your actual AWS access key and secret access key.

3. Verify that the secret has been created successfully by running:

```shell
kubectl get secret aws-credentials
```

You should see the `aws-credentials` secret listed.

That's it! You have successfully created the `aws-credentials` secret in your Kubernetes cluster.
