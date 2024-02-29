# Overview

Reloader helms to perform automatic rolling restarts of pods when the secrets or config-maps attached to the
deployment/sts/deamon-sets etc. are updated in the k8s cluster.

Reloader is compatible with `Kubernetes >= 1.19`

## Installation
Many different installations are supported by the reloader but we would be using the `Helm` installation method.

```shell

helm repo add stakater https://stakater.github.io/stakater-charts

helm repo update

helm upgrade --install reloader stakater/reloader # For helm3 add --generate-name flag or set the release name explicitly

```

By default Reloader watches in all namespaces. To watch in single namespace, please run following command. It will install
Reloader in test namespace which will only watch Deployments, Daemonsets Statefulsets and Rollouts in test namespace.

```shell
helm upgrade --install reloader stakater/reloader --reuse-values --set reloader.watchGlobally=false --namespace test
```

## Usage

Reloader watches for changes in ConfigMap and Secret and then performs a rolling upgrade on the Deployment, StatefulSet, DaemonSet, and DeploymentConfig which uses the ConfigMap or Secret.

### Listen to changes in ConfigMap and Secret with annotations
The `match` annotation is required to be set to `true` in the ConfigMap or Secret to be watched by Reloader.
```yaml
kind: ConfigMap
metadata:
  annotations:
    reloader.stakater.com/match: "true"
data:
  key: value
```
The `reloader.stakater.com/search` annotation is required to be set to `true` in the Deployment, StatefulSet, DaemonSet, and DeploymentConfig to be watched by Reloader.

Deployment
```yaml
kind: Deployment
metadata:
  annotations:
    reloader.stakater.com/search: "true"
spec:
  template:
```
 If both the above annotations are present, then Reloader will watch for changes in the ConfigMap and Secret and then perform a rolling upgrade on the Deployment, StatefulSet, DaemonSet, and DeploymentConfig which uses the ConfigMap or Secret.


Logs when change is detected
```shell
time="2024-02-23T19:25:38Z" level=info msg="Changes detected in 'testsecret' of type 'SECRET' in namespace 'default', Updated 'csi-secret-test-app' of type 'Deployment' in namespace 'default'"
```
Events in the deployment
```shell

Events:
  Type    Reason             Age                 From                    Message
  ----    ------             ----                ----                    -------
  Normal  ScalingReplicaSet  59m                 deployment-controller   Scaled up replica set csi-secret-test-app-56c556f6 to 1
  Normal  InjectionSkipped   3m1s (x3 over 59m)  linkerd-proxy-injector  Linkerd sidecar proxy injection skipped: neither the namespace nor the pod have the annotation "linkerd.io/inject:enabled"
  Normal  Reloaded           3m1s                reloader-secrets        Changes detected in 'testsecret' of type 'SECRET' in namespace 'default', Updated 'csi-secret-test-app' of type 'Deployment' in namespace 'default'
  Normal  ScalingReplicaSet  3m1s                deployment-controller   Scaled up replica set csi-secret-test-app-85f7f6cf to 1
  Normal  ScalingReplicaSet  3m                  deployment-controller   Scaled down replica set csi-secret-test-app-56c556f6 to 0 from 1
```

# Reference
1. [Reloader](https://github.com/stakater/Reloader)
