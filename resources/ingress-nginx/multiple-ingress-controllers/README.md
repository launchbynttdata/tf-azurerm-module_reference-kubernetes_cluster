# Overview

Our solution here is to have multiple `ingress-nginx` controllers for our cluster. In the simplest use-case, we may need 2 controllers, one for public facing applications and the other for private applications.

Our plan is to deploy multiple releases of `ingress-nginx` controllers in different namespace with all its dependencies like - external-dns, cert-manager etc. in such a way that they don't compete with each other.

Ingress Controllers should be completely isolated and make sure that they strictly provision resources on the dns, certificate etc. on their configured tools/servers. For e.g. when we provision a private ingress endpoint,
we want it to create a DNS record in the private DNS and not make any changes on the public DNS server and vice versa.

## Public Ingress

By public ingress we mean that the `nginx controller` will be
assigned a public IP on the default public load balancer (named kubernetes)
that is automatically created by AKS.

This public ingress will be associated
with a Public DNS Zone (external_dns module). When an `ingress` resource is
created, that would refer to this public ingress (done by annotation
`ingress.class` on the ingress metadata), an A-record would be created in
the associated public DNS zone.

## Private Ingress

By Private Ingress we mean the `nginx controller` will be assigned a private IP address picked from the VNET associated
with the DNS Zone (passed as input while creating the `ingress-nginx` helm release).

This private IP will be assigned to an internal load balancer (created automatically and managed by AKS
named `kubernetes-internal`).
When an `ingress` resource is created, that would refer to this private ingress (done by annotation
`ingress.class` on the ingress metadata), an A-record would be created in
the associated private DNS zone.

## Implementation
In order to have both private and public ingress in the same AKS cluster, we would do it by having them
as separate `Helm releases` in separate `namespaces`. There would be a few metadata that would be different in
these release that would separate them from each other.

When an ingress manifest is created, we can choose which ingress controller to use by the field `ingressClassName: private-ingress`

The below code shows the configuration metadata that differentiates one ingress from another.
```shell
  # Below are the arguments that must be passed to ingress controller while creation and must be different on both
  --namespace <namespace>
  --set controller.ingressClassResource.controllerValue=k8s.io/internal-ingress-nginx \
  --set controller.ingressClass=internal-ingress \
  --set controller.ingressClassResource.name=internal-ingress
```

## Installations

### Private Ingress
[Installation docs](./private-ingress/README.md)

### Public Ingress
[Installation docs](./public-ingress/README.md)
