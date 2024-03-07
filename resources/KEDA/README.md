# Kubernetes Event Driven Autoscaling (KEDA)

Kubernetes Event-driven Autoscaling (KEDA) is a single-purpose and lightweight component that strives to make application autoscaling simple and is a CNCF Graduate project.

It applies event-driven autoscaling to scale your application to meet demand in a sustainable and cost-efficient manner with scale-to-zero.

The KEDA add-on makes it even easier by deploying a managed KEDA installation, providing you with a rich catalog of Azure KEDA scalers that you can scale your applications with on your Azure Kubernetes Services (AKS) cluster.

## Installation
KEDA can be enabled on AKS by an addon when using Azure CLI . Currently this terraform module doesn't support enabling KEDA on AKS.
But in the future, we can add the support to enable KEDA on AKS using this terraform module.

# References
1. [KEDA Auto Scalers](https://keda.sh/docs/2.13/scalers/)
