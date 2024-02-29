# Emissary (Ambassador)
Emissary, formerly known as Ambassador, is a Kubernetes-native API Gateway built on the Envoy Proxy. It is designed for microservices and provides a rich set of features for traffic management, security, and observability.
It is a popular choice for Kubernetes users who need an ingress controller that can handle complex routing and traffic management.

A microservices API gateway is an API gateway designed to accelerate the development workflow of independent services teams.
A microservices API gateway provides all the functionality for a team to independently publish, monitor, and update a microservice.

Emissary Ingress is a `Self-service publishing` API gateway. A team needs to be able to publish a new service to customers without requiring an operations
or API management team. This ability to self-service for deployment and publication enables the team to keep the feature release velocity high.
While a traditional enterprise API gateway may provide a simple mechanism (e.g., REST API) for publishing a new service, in practice,
the usage is often limited to the use of a dedicated team that is responsible for the gateway. The primary reason for limiting publication to a single team
is to provide an additional (human) safety mechanism: an errant API call could have potentially disastrous effects on production.

Microservices API gateways utilize mechanisms that enable service teams to easily and safely publish new services, with the inherent understanding that the producing
team are responsible for their service, and will fix an issue if one occurs. A microservices gateway provides configurable monitoring for issue detection,
and provides hooks for debugging, such as inspecting traffic or traffic shifting/duplication.

## Installation

```shell
# Add the Repo:
helm repo add datawire https://app.getambassador.io
helm repo update

# Create Namespace and Install:
kubectl create namespace emissary && \
kubectl apply -f https://app.getambassador.io/yaml/emissary/3.9.1/emissary-crds.yaml

# May use an optional values.yaml should you want to override any default values
helm install emissary-ingress --namespace emissary datawire/emissary-ingress -f ./values.yaml
```

### Upgrade with custom values (optional)

Upgrade the above release to use private load balancer and few more configurations.

```shell
helm upgrade emissary-ingress --namespace emissary datawire/emissary-ingress -f values.yaml
````

At this point, the Emissary is configured as a private ingress. The `emissary` service is of type LoadBalancer with annotation `service.beta.kubernetes.io/azure-load-balancer-internal: "true"`. So, a `private IP` address is assigned to the Emissary Service.
In case, you have a Private DNS zone, an A record can be created to point to the private IP address of the Emissary Service. Azure uses layer 4 Load Balancer that doesn't support TLS termination,
for us to enable TLS, we need to do so at the Emissary layer.


### Configure TLS

1. Create a https listener if not already created.
    ```shell
    kubectl apply -f listeners/https-listener.yaml
    ```
2. Assign a host-name to the private Load Balancer IP for Emissary by creating an A-record on the Private DNS zone that you own. Currently, Emissary doesn't support `external-dns` for automatic creation of A-records.
    ```shell
    # Create a host-name for the private IP address of the Emissary Service
    kubectl apply -f hosts/emissary-tls-host.yaml
    ```
   The `emissary-tls-host.yaml` file contains the host-name and the service to which the traffic should be routed to.
3. If `cert-manager` is installed on the AKS cluster, use it to create a public certificate for the host-name created in step 1. Using public certificate would allow the clients to trust the certificate without having to add the root certificate to the trust store.
    ```shell
    kubectl apply -f listeners/certificate.yaml
    ```
   When the certificate is created successfully, it will create a secret in the same namespace as the certificate. This secret will be used by the emissary to terminate TLS.

4. Create a host object for the host-name created in step 2. This is used to route traffic to the correct service.
    ```shell
   # Host will use the secret created by cert-manager certificate resource
    kubectl apply -f hosts/emissary-tls-host.yaml
    ```

At this point, emissary ingress is configured with TLS termination. The traffic is routed to the correct service based on the host-name.


### Linkerd integration

Assuming that Linkerd is already installed on the cluster, the below steps can be followed to integrate Emissary with Linkerd. By skipping the inbound ports, we are basically
instructing Linkerd to not intercept traffic coming on those ports and apply iptables rules to redirect traffic to the Linkerd proxy. These are the ports on which external traffic enters the Emissary ingress
```shell
kubectl -n $namespace get deploy $deployment -o yaml | \
   linkerd inject \
   --skip-inbound-ports 80,443 - | \
   kubectl apply -f -
```

## Custom Resources

Emissary provides a set of custom resources that can be used to configure the ingress. Some of the important ones are
- Mapping: The core resource used to support application development teams who need to manage the edge with Emissary-ingress is the Mapping resource.
  At its core the `mapping` resource maps a `resource` to a `service`. More details can be found at [mapping](https://www.getambassador.io/docs/emissary/latest/topics/using/intro-mappings)
- Host: This CRD handles the hostname mappings allowed by the Emissary-ingress. It is used to route traffic to the correct service based on the host-name. More details can be found at [host](https://www.getambassador.io/docs/emissary/latest/topics/running/host-crd)
- Module: This is an optional CRD which if present defines system-wide configuration for Emissary-ingress. These configurations can be further overridden in other CRDs like `mapping`. More details can be found at [module](https://www.getambassador.io/docs/emissary/latest/topics/running/ambassador)
- Listener: The Listener CRD defines where, and how, Emissary-ingress should listen for requests from the network, and which Host definitions should be used to process those requests. More details can be found at [listener](https://www.getambassador.io/docs/emissary/latest/topics/running/listener)


## Emissary capabilities

### Load Balancing And Ingress
1. [Auth Services](#auth-services)
2. [Automatic retries](#retries)
3. [Circuit breaking](#circuit-breaking)
4. [Canary releases](#canary-releases)
5. [CORS](#cors)
6. [Ingress Controller](#ingress-controller)
7. [Load Balancing](#load-balancing)
8. [Service Discovery and Resolvers](#service-discovery-and-resolvers)

### Auth Services

Emissary-ingress provides a highly flexible mechanism for authentication, via the `AuthService` crd resource. An AuthService configures Emissary-ingress to use an external service to check authentication and authorization for incoming requests. Each incoming request is authenticated before routing to its destination.

More details can be found at [Auth Services](https://www.getambassador.io/docs/emissary/latest/topics/running/services/auth-service)

### Retries
Sometimes requests fail. When these requests fail for transient issues, Emissary-ingress can automatically retry the request.

Retry policy can be set for all Emissary-ingress mappings in the ambassador Module, or set per Mapping. Generally speaking, you should set retry_policy on a per mapping basis. Global retries can easily result in unexpected cascade failures.
More details can be found at [Automatic Retries](https://www.getambassador.io/docs/emissary/latest/topics/using/retries)

```yaml
apiVersion: getambassador.io/v3alpha1
kind:  Mapping
metadata:
   name:  quote-backend
spec:
   hostname: '*'
   prefix: /backend/
   service: quote
   retry_policy:
      retry_on: "5xx"
      num_retries: 10
      per_try_timeout: 0.5s

```

### Service Discovery and Resolvers
Service discovery is how cloud applications and their microservices are located on the network. In a cloud environment,
services are ephemeral, existing only as long as they are needed and in use, so a real-time service discovery mechanism is required.
Emissary-ingress uses information from service discovery to determine where to route incoming requests.

Emissary-ingress supports different mechanisms for service discovery. These mechanisms are:

- Kubernetes service-level discovery (default).
- Kubernetes endpoint-level discovery.
- Consul endpoint-level discovery.

More details can be found at [Service Discovery and Resolvers](https://www.getambassador.io/docs/emissary/latest/topics/running/resolvers)

### Canary Releases
Canary releasing is a deployment pattern where a small percentage of traffic is diverted to an early ("canary") release of a particular service. This technique lets you test a release on a small subset of users, mitigating the impact of any given bug.

Kubernetes supports a basic canary release workflow using its core objects. In this workflow, a service owner can create a Kubernetes service. This service can then be pointed to multiple deployments. Each deployment can be a different version. By specifying the number of replicas in a given deployment, you can control how much traffic goes between different versions. For example, you could set replicas: 3 for v1, and replicas: 1 for v2, to ensure that 25% of traffic goes to v2.
This approach works but is fairly coarse-grained unless you have lots of replicas. Moreover, auto-scaling doesn't work well with this strategy.

Emissary-ingress supports fine-grained canary releases. Emissary-ingress uses a weighted round-robin scheme to route traffic between multiple services.
Full metrics are collected for all services, making it easy to compare the relative performance of the canary and production.

The below example shows that the API is routed to path `/backend/` and the traffic is split between two services `quote` and `quotev2` with a weight of 10.

```yaml
apiVersion: getambassador.io/v3alpha1
kind:  Mapping
metadata:
  name:  quote-backend
spec:
  prefix: /backend/
  service: quote
---
apiVersion: getambassador.io/v3alpha1
kind:  Mapping
metadata:
  name:  quote-backend2
spec:
  prefix: /backend/
  service: quotev2
  weight: 10
```

### Circuit Breaking
Circuit breakers are a powerful technique to improve resilience. By preventing additional connections or requests to an overloaded service, circuit breakers limit the "blast radius" of an overloaded service. By design, Emissary-ingress circuit breakers are distributed, i.e., different Emissary-ingress instances do not coordinate circuit breaker information.

A default circuit breaking configuration can be set for all Emissary-ingress resources in the ambassador Module, or set to a different value on a per-resource basis for Mappings, TCPMappings, and AuthServices.
They can be best used with `Automatic retries`.

```yaml
# Circuit breaking configuration with default values
circuit_breakers:
  - priority: default
    max_connections: 1024
    max_pending_requests: 1024
    max_requests: 1024
    max_retries: 3
```
The below example shows how circuit breaking can be configured for a `mapping`.
```yaml
apiVersion: getambassador.io/v3alpha1
kind:  Mapping
metadata:
  name:  quote-backend
spec:
  prefix: /backend/
  service: quote
  circuit_breakers:
  - max_connections: 2048
    max_pending_requests: 2048
```

### CORS
Cross-Origin resource sharing lets users request resources (e.g., images, fonts, videos) from domains outside the original domain.

CORS configuration can be set for all Emissary-ingress mappings in the ambassador Module, or set per Mapping.

When the CORS attribute is set at either the Mapping or Module level, Emissary-ingress will intercept the pre-flight OPTIONS request and respond with the appropriate
CORS headers. This means you will not need to implement any logic in your upstreams to handle these CORS OPTIONS requests.

```yaml
apiVersion: getambassador.io/v3alpha1
kind:  Mapping
metadata:
  name:  cors
spec:
  prefix: /cors/
  service: cors-example
  cors:
    origins: http://foo.example,http://bar.example
    methods: POST, GET, OPTIONS
    headers: Content-Type
    credentials: true
    exposed_headers: X-Custom-Header
    max_age: "86400"
```

More details can be found at [CORS in Emissary](https://www.getambassador.io/docs/emissary/latest/topics/using/cors)

### Ingress Controller
Emissary can be used as an Ingress Controller. It can be used to route traffic to services in the cluster. It can also be used to route traffic to services outside the cluster.
The set up is pretty similar to that of `ingress-nginx` where you need to configure an `IngressClass` and then use it to route traffic to services by making use of `Ingress` objects.

However, in my experience, I found that `ingress-nginx` is more popular and has more support and documentation than `emissary-ingress`. For example the external-dns module (to configure with custom DNS zones) is not supported directly with emissary. The `cert-manager` is supported but the automatic creation of certificates via annotations is not supported.

### Load Balancing
Load balancing configuration can be set for all Emissary-ingress mappings in the ambassador Module, or set per Mapping. If nothing is set, simple round robin balancing is used via Kubernetes services.

Supported load balancer policies:

- round_robin
- least_request
- ring_hash
- maglev


Below example shows how to configure load balancing for a mapping using `round_robin` policy.

```yaml
apiVersion: getambassador.io/v3alpha1
kind:  Mapping
metadata:
  name:  quote-backend
spec:
  prefix: /backend/
  service: quote
  resolver: my-resolver
  hostname: '*'
  load_balancer:
    policy: round_robin
```

Sticky sessions and session affinity can also be configured using `load_balancer` attribute. For more details, refer to [Load Balancing](https://www.getambassador.io/docs/emissary/latest/topics/running/load-balancer)

## Headers

Emissary supports header operations as below
- Add/remove request headers
- Add/remove response headers
- Host header rewriting

## Traffic management

### Custom error responses

Custom error responses can be set either in `module` or `mapping` level. Below example shows how to set custom error responses in a module.
If the `error_response_overrides` block is set in both module and mapping, the mapping level error response will take precedence. All rules in
the module will be ignored.

If you want to bypass all the module level rules (if any) to be applied to the mapping, they can be ignored by this flag in the `spec` section `bypass_error_response_overrides: true`


**NOTE:**: The module should always be named `ambassador` for a given namespace, else it will be ignored. To use multiple modules,
you can use the `ambassador_id` attribute to differentiate between them. More details can be found in `modules` section

```yaml
apiVersion: getambassador.io/v3alpha1
kind: Module
metadata:
  name: ambassador
  namespace: default
spec:
  config:
    error_response_overrides:
      - on_status_code: 404
        body:
          text_format: "File not found"
      - on_status_code: 500
        body:
          json_format:
            error: "Application error"
            status: "%RESPONSE_CODE%"
            cluster: "%UPSTREAM_CLUSTER%"
```

For more details visit [Custom Error Responses](https://www.getambassador.io/docs/emissary/latest/topics/running/custom-error-responses)
### Gzip compression

When the gzip filter is enabled, request and response headers are inspected to determine whether the content should be compressed.
If so, and the request and response headers allow, the content is compressed and then sent to the client with the appropriate headers.
It also uses the zlib module, which provides Deflate compression and decompression code.

Minimal configuration is shown below. It can only be applied on `module` level. For more details visit [gzip](https://www.getambassador.io/docs/emissary/latest/topics/running/gzip)

```yaml
apiVersion: getambassador.io/v3alpha1
kind:  Module
metadata:
  name:  ambassador
spec:
  config:
    gzip:
      enabled: true

```

## Rate limiting

Rate limiting is a powerful technique to improve the availability and resilience of your services. In Emissary-ingress,
each request can have one or more labels. These labels are exposed to a third-party service via a gRPC API.
The third-party service can then rate limit requests based on the request labels.

For more details visit [Rate Limiting](https://www.getambassador.io/docs/emissary/latest/topics/running/services/rate-limit-service)

## Routing

Emissary supports many types of routing and traffic management features. Some of them are
- Method based routing
- Query parameter based routing
- Prefix regex
- Redirects
- Rewrites
- Timeouts
- Keepalive
- Traffic Shadowing


# References

1. [Emissary Ingress](https://www.getambassador.io/docs/emissary/latest/tutorials/getting-started)
