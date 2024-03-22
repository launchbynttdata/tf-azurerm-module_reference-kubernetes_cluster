# Overview

LinkerD is a Service Mesh implemented we are planning to use in our project. It is super easy to install and get it integrated with k8s applications. It provides a dashboard for a visualization of the workload.

It comes with a cli, that is easy to use and can be used to interact with the linkerD control plane

## Install the CLI
The below-mentioned approach can be used to install LinkerD cli on linux and OSX platform
```shell
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install | sh
export PATH="$PATH:$HOME/.linkerd2/bin"
# check the version
linkerd version
```

## Install LinkerD control plane on Azure using CLI
Before installing, make sure the `KUBE_CONFIG` environment var is set pointing to your desired k8s cluster (AKS)
In case you use terraform for your AKS use the below command
```shell
terraform output -raw kube_config_raw > aks_kubeconfig
export KUBECONFIG=aks_kubeconfig
```

Now, it's time to install the LinkerD control plane with the below commands
```shell
linkerd check --pre
# If it says to upgrade the CLI, you can do that by re-installing the CLI as shown above
linkerd install --crds | kubectl apply -f -
linkerd install | kubectl apply -f -

linkerd check
```

## Install LinkerD using Helm

### Add the helm repos
```shell
# To add the repo for Linkerd stable releases:
helm repo add linkerd https://helm.linkerd.io/stable

# To add the repo for Linkerd edge releases:
helm repo add linkerd-edge https://helm.linkerd.io/edge
```

### Install CRDs
```shell
helm install linkerd-crds linkerd/linkerd-crds \
  -n linkerd --create-namespace
```

### Create Certs
To do automatic mutual TLS, Linkerd requires trust anchor certificate and an issuer certificate and key pair. When you’re using linkerd install, we can generate these for you. However, for Helm, you will need to generate these yourself.

There are 2 type of certificates used here
- **Trust Anchor**: This pair acts as the root CA and signs the Issuer cert (Private CA). This cert should be issued for a long duration like 10 years. As they cannot be auto renewed. User has to manually renew them
- **Issuer Certificate**: This is the Private CA that Linkerd uses to sign the TLS certificates for proxies. These certs, when created manually with tools like `openssl or step` are not automatically renewable. However, there is an option to get these certs provisioned by the `cert-manager`. In that case, they are auto renewed

Certs can be installed either using `openssl` or tools like `step`. We will be using the later

```shell
asdf plugin add step
asdf install step 0.25.0
# Add to the ~/.tool-versions unless you add it to the project
asdf global step 0.25.0

## Generate the certs
# Trust Anchor certs (used to sign the CA)
step certificate create root.linkerd.cluster.local ca.crt ca.key \
--profile root-ca --no-password --insecure

# Cert the CA key/crt pair. The cert is signed by Trust Anchor
step certificate create identity.linkerd.cluster.local issuer.crt issuer.key \
--profile intermediate-ca --not-after 8760h --no-password --insecure \
--ca ca.crt --ca-key ca.key

helm install linkerd-control-plane \
  -n linkerd \
  --create-namespace \
  --set-file identityTrustAnchorsPEM=ca.crt \
  --set-file identity.issuer.tls.crtPEM=issuer.crt \
  --set-file identity.issuer.tls.keyPEM=issuer.key \
  linkerd/linkerd-control-plane

```

**Note:** These `Issuer certs` above, however are not automatically renewed. We could use `cert-manager` to provision certificates that are automatically renewed. More details can be found at https://linkerd.io/2.14/tasks/automatically-rotating-control-plane-tls-credentials/
### Install Linkerd using Helm
Use the certs from the previous step
```shell
helm install linkerd-control-plane \
  -n linkerd \
  --set-file identityTrustAnchorsPEM=ca.crt \
  --set-file identity.issuer.tls.crtPEM=issuer.crt \
  --set-file identity.issuer.tls.keyPEM=issuer.key \
  linkerd/linkerd-control-plane

#× proxy-init container runs as root user if docker container runtime is used
#    there are nodes using the docker container runtime and proxy-init container must run as root user.
#try installing linkerd via --set proxyInit.runAsRoot=true
#    see https://linkerd.io/2.14/checks/#l5d-proxy-init-run-as-root for hints

helm upgrade linkerd-control-plane linkerd/linkerd-control-plane -n linkerd \
  --reuse-values \
  --set proxyInit.runAsRoot=true
```
## Install LinkerD Dashboard
The dashboard is a good thing to have to see the visualization of your Kubernetes workload along with default metrics provided by Linkerd
```
# services will be installed in linkerd-viz namespace
linkerd viz install | kubectl apply -f -
linkerd check
# open the dashboard default is: http://localhost:50750
linkerd viz dashboard &
```
### Expose Dashboard to the outside world
This installation is good for development and testing in the local system. In order to expose the dashboard to the outside world, we need to set un an [Ingress resource](linkerd-dashboard-ingress.yaml).
The below command will create an ingress resource for the dashboard

Basic authentication is used to secure the dashboard.

```shell
kube apply -f linkerd-dashboard-ingress.yaml
````
This ingress is set up with basic credentials (admin/admin). You can change the credentials by updating the secret `linkerd-dashboard-basic-auth` and updating the ingress resource.
## Test with a sample app
I have already downloaded a sample app into the `sample-apps` directory.

The application will be deployed by default in the `emojivoto namespace`
```shell
# Install the app
kube apply -f ./sample-apps
```

Currently, the app is not associated with LinkerD. We need to inject an annotation that will indicate the control plane to pick up the app's
associated pod and inject the linkerd proxy in them.

This will inject the annotation `"linkerd.io/inject=enabled"` to deployment `spec.template.metadata.annotations`
```shell
kubectl get deploy -n emojivoto -o yaml \
  | linkerd inject - \
  | kubectl apply -f -
```

## LinkerD scoped to namespace
We have the ability to apply linkerD on a namespace level. Once we do that, any deployments that are installed
in the annotated namespace will be automatically injected with linkerd envoy proxy.

```shell
# Create a namespace
kube create ns linkerd-apps
# Annotate the namespace
kubectl annotate ns/linkerd-apps "linkerd.io/inject=enabled"
```

Now, deploy a sample app and observe linkerd proxy getting auto-injected.
```shell
kube apply -n linkerd-apps -f ./linkerd-apps
```
## Expose Linkerd Metrics

The official documents provides multiple ways to export the metrics [expose metrics](https://linkerd.io/2.15/tasks/exporting-metrics/).

However, none of the ways specified were found suitable for otel collector to scrape the metrics. The approach we used was
to create a service [linkerd-dst-http](./linkerd-dst-http-service.yaml) which will expose the port `4191` for the linkerd-destination deployment. The otel collector can then
use this service endpoint to scrape metrics `http://linkerd-dst-http.linkerd.svc.cluster.local:4191/metrics`

The prometheus instance provided by `linkerd-viz` is throwing `403` while trying to scrape from the otel pod. May be some authorization policy is blocking the scrape. The above approach is a workaround to get the metrics.

## Uninstall Linkerd

Removing Linkerd from a Kubernetes cluster requires a few steps: removing any data plane proxies, removing all the extensions and then removing the core control plane.

### Removing Linkerd data plane proxies
```shell
kubectl get deploy -o yaml -n emojivoto  | linkerd uninject - | kubectl apply -f -
```

### Removing extensions
```shell
# To remove Linkerd Viz
linkerd viz uninstall | kubectl delete -f -

# To remove Linkerd Jaeger
linkerd jaeger uninstall | kubectl delete -f -

# To remove Linkerd Multicluster
linkerd multicluster uninstall | kubectl delete -f -
```

### Removing the control plane
```shell
linkerd uninstall | kubectl delete -f -
```

# Important Links
- [LinkerD Official](https://linkerd.io/2.14/getting-started/)
- [Auto rotate control plane TLS certs](https://linkerd.io/2.14/tasks/automatically-rotating-control-plane-tls-credentials/)
- [Exposing Linkerd Dashboard](https://linkerd.io/2.14/tasks/exposing-dashboard/)
- [Observability Linkerd](https://isitobservable.io/observability/service-mesh/what-is-linkerd-and-can-you-observe-it)
