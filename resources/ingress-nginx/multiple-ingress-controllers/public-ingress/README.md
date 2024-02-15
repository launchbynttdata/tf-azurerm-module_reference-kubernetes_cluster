# Public Ingress Nginx

## Overview

Create a public `ingress-nginx` controller in the `public-ingress` namespace using Helm

## Public Ingress

What we mean by a public ingress is that the `nginx controller` will be
assigned a public IP on the default public load balancer (named kubernetes)
that is automatically created by AKS. This public ingress will be associated
with a Public DNS Zone (external_dns module). When an `ingress` resource is
created, that would refer to this public ingress (done by annotation
`ingress.class` on the ingress metadata), an A-record would be created in
the associated public DNS zone.


## Install public ingress

1. Create a `azure.json` file and fill up all the necessary details. The `userAssignedIdentityID` should be the Kubenet MSI client ID
2. Create a secret using the above `azure.json`. This secret is consumed by the `external-dns` module
    ```
   kubectl create secret generic azure-config-file-public \
     --from-file="../common/ingress-nginx/multiple-ingress-controllers/public-ingress/azure.json"
   ```
3. Deploy the `external_dns` manifest file
    ```
   kube apply -f ../common/ingress-nginx/multiple-ingress-controllers/public-ingress/external-dns.yaml
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
      --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz

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
At this point, the ingress controller is ready to serve requests to create ingress objects. You need to deploy a sample  [application](../sample-app) and create an ingress resource as provided in [ingress-resources](./ingress-resources)
