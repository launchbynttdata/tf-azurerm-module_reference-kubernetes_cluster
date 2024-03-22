# Flask Rest API

This example demonstrates how to instrument a simple python Flask application using OpenTelemetry SDK's flask auto instrumentation
and send traces to Otel collectors. The Otel collector is configured to export traces to Azure Application Insights

Using Otel SDKs allows the application to be agnostic to be used with any backend Trace/Metrics system.

## Build Docker image

```yaml
# Login to ACR
TOKEN=$(az acr login --name launchbuildagent --expose-token | jq -r ".accessToken")
docker login launchbuildagent.azurecr.io -u 00000000-0000-0000-0000-000000000000 -p $TOKEN

# Buiild the image and push to ACR
docker buildx build --platform linux/arm64,linux/amd64 -t launchbuildagent.azurecr.io/python-rest:v1 . --push
```

## Deploy to Kubernetes

The deployment assumes that the Otel collector is already installed in the cluster. The traces can be sent to otel
using GRPC at `otel-collector-opentelemetry-collector.default.svc.cluster.local:4317`

The [app.yaml](./app.yaml) will create a deployment and a service of type `ClusterIP` for the application.

## Create Emissary mapping

The [emissary-mapping.yaml](./emissary-mapping.yaml) will create a mapping for the application and onboard it on Emissary
which is our in-cluster API gateway. The mapping will be used to route the incoming requests to the application.

# Conclusion

At this point, the application is ready to serve requests. The traces will be sent to the otel collector and can be visualized in Application Insights.
Assuming the Emissary controller is running at https://emissary.sandbox.launch.dresdencraft.com, we can send a request to the application using the following command

```shell
curl https://emissary.sandbox.launch.dresdencraft.com/python/
curl https://emissary.sandbox.launch.dresdencraft.com/python/example
curl https://emissary.sandbox.launch.dresdencraft.com/python/user/<username>
```

# References

1. [Python Otel Exporters](https://opentelemetry-python.readthedocs.io/en/latest/exporter/otlp/otlp.html)
2. [Flask Auto Instrumentation](https://opentelemetry-python.readthedocs.io/en/latest/exporter/otlp/otlp.html)
