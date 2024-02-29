# Overview

Sample applications to demonstrate the use of k8s service and ingress using nginx-ingress.

```shell
kube create ns demo-apps
kube apply -n demo-apps -f demo-apps
```

Annotation for internal service
```shell
# internal service
service.beta.kubernetes.io/azure-load-balancer-internal: "true"
```
