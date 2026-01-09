product_family  = "dso"
product_service = "akspvt"

kubernetes_version        = "1.32"
agents_count              = 2
agents_availability_zones = [1, 2]

# default service cidr is 10.0.0.0/16
net_profile_service_cidr   = "10.2.0.0/16"
net_profile_dns_service_ip = "10.2.0.10"
net_profile_pod_cidr       = "10.3.0.0/16"

network_plugin = "kubenet"

private_cluster_enabled = true

enable_prometheus_monitoring_private_endpoint = true

# User Assigned Managed Identity will be automatically created
identity_type = "UserAssigned"

prometheus_rule_groups = {
  "MultiplePodAlertingRuleGroup" = {
    enabled     = true
    description = "Cluster contains more than one pod"
    interval    = "PT1M"

    recording_rules = []

    alert_rules = [
      {
        name       = "pod_count_gt_1"
        enabled    = true
        expression = "count(kube_pod_info) > 1"
        for        = "PT1M"
        severity   = 3

        labels = {
          severity = "info"
        }
      }
    ]
  }
}
oidc_issuer_enabled       = true
workload_identity_enabled = true
# Create one additional User Assigned Identity
workload_user_assigned_identities = {
  testidentity = {
    name_override = "akstest-uai-test"
  }
}

# Create a federated credential for a test service account
workload_federated_credentials = {
  testcred = {
    user_assigned_identity_key = "testidentity"
    name                       = "aks-test-workload-fic"

    namespace            = "default"
    service_account_name = "test-app"

    # Optional, but good to include explicitly
    audience = ["api://AzureADTokenExchange"]
  }
}
