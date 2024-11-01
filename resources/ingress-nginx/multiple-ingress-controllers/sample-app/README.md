# Running the Sample App
To run the sample app, you will need to create a Docker registry secret in your Kubernetes cluster. Follow the steps below to create the secret:

1. Open a terminal or command prompt.

2. Run the following command to log in to Docker using your ECR credentials:

```shell
aws ecr get-login-password --region <your-region> | docker login --username AWS --password-stdin <your-ecr-registry-url>
```

3. Run the following command to create the Docker registry secret:

```shell
kubectl create secret docker-registry docker-secret \
--docker-server=<your-ecr-registry-url> \
--docker-username=AWS \
--docker-password=$(aws ecr get-login-password --region <your-region>) \
--docker-email=$MY_EMAIL
```

4. Once the secret is created, you can use it in your Kubernetes deployments or pods to pull images from the specified Docker registry.

That's it! You have successfully created the Docker registry secret and can now use it to run the sample app.
