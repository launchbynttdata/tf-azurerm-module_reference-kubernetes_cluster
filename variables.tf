// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

variable "product_family" {
  description = <<EOF
    (Required) Name of the product family for which the resource is created.
    Example: org_name, department_name.
  EOF
  type        = string
  default     = "dso"
}

variable "product_service" {
  description = <<EOF
    (Required) Name of the product service for which the resource is created.
    For example, backend, frontend, middleware etc.
  EOF
  type        = string
  default     = "kube"
}

variable "environment" {
  description = "Environment in which the resource should be provisioned like dev, qa, prod etc."
  type        = string
  default     = "dev"
}

variable "environment_number" {
  description = "The environment count for the respective environment. Defaults to 000. Increments in value of 1"
  type        = string
  default     = "000"
}

variable "resource_number" {
  description = "The resource count for the respective resource. Defaults to 000. Increments in value of 1"
  type        = string
  default     = "000"
}

variable "region" {
  description = "AWS Region in which the infra needs to be provisioned"
  type        = string
  default     = "eastus"
}

variable "resource_names_map" {
  description = "A map of key to resource_name that will be used by tf-launch-module_library-resource_name to generate resource names"
  type = map(object(
    {
      name       = string
      max_length = optional(number, 60)
    }
  ))
  default = {
    aks = {
      name       = "aks"
      max_length = 60
    }
    acr = {
      name       = "acr"
      max_length = 60
    }
    resource_group = {
      name       = "rg"
      max_length = 60
    }
    application_gateway = {
      name       = "appgtw"
      max_length = 60
    }
    key_vault = {
      name       = "kv"
      max_length = 24
    }
    cluster_identity = {
      name       = "msi"
      max_length = 60
    }
    route_table = {
      name       = "rt"
      max_length = 60
    }
    application_insights = {
      name       = "appins"
      max_length = 60
    }
    monitor_private_link_scope = {
      name       = "ampls"
      max_length = 60
    }
    monitor_private_link_scope_endpoint = {
      name       = "amplspe"
      max_length = 60
    }
    monitor_private_link_scope_service_connection = {
      name       = "amplspesc"
      max_length = 60
    }
    prometheus_monitor_workspace = {
      name       = "promamw"
      max_length = 60
    }
    prometheus_endpoint = {
      name       = "prompe"
      max_length = 60
    }
    prometheus_service_connection = {
      name       = "prompesc"
      max_length = 60
    }
    prometheus_data_collection_endpoint = {
      name       = "promdce"
      max_length = 60
    }
    prometheus_data_collection_rule = {
      name       = "promdcr"
      max_length = 60
    }
  }
}

variable "resource_group_name" {
  description = "Name of the resource group in which the AKS cluster will be created. If not provided, this module will create one"
  type        = string
  default     = null
}

## AKS related variables

variable "kubernetes_version" {
  type        = string
  default     = "1.28"
  description = <<EOT
    Specify which Kubernetes release to use. The default used is the latest Kubernetes version available in the region
    Use `az aks get-versions --location <region>` to find the available versions in the region
  EOT
}

variable "network_plugin" {
  type        = string
  default     = "azure"
  description = "Network plugin to use for networking. Default is azure."
  nullable    = false
}

variable "network_plugin_mode" {
  type        = string
  default     = null
  description = "(Optional) Specifies the network plugin mode used for building the Kubernetes network. Possible value is `Overlay`. Changing this forces a new resource to be created."
}

variable "network_policy" {
  type        = string
  default     = null
  description = " (Optional) Sets up network policy to be used with Azure CNI. Network policy allows us to control the traffic flow between pods. Currently supported values are calico and azure. Changing this forces a new resource to be created."
}

variable "private_cluster_enabled" {
  type        = bool
  default     = false
  description = "If true cluster API server will be exposed only on internal IP address and available only in cluster vnet."
}

variable "private_cluster_public_fqdn_enabled" {
  type        = bool
  default     = false
  description = "(Optional) Specifies whether a Public FQDN for this Private Cluster should be added. Defaults to `false`."
}

variable "additional_vnet_links" {
  description = "A list of VNET IDs for which vnet links to be created with the private AKS cluster DNS Zone. Applicable only when private_cluster_enabled is true."
  type        = map(string)
  default     = {}
}

variable "cluster_identity_role_assignments" {
  description = <<EOT
    A map of role assignments to be associated with the cluster identity
    Should be of the format
    {
      private-dns = ["Private DNS Zone Contributor", "<private-dns-zone-id>"]
      dns = ["DNS Zone Contributor", "<dns-zone-id>"]
    }
  EOT
  type        = map(list(string))
  default     = {}
}

variable "node_pool_identity_role_assignments" {
  description = <<EOT
    A map of role assignments to be associated with the node-pool identity
    Should be of the format
    {
      private-dns = ["Private DNS Zone Contributor", "<private-dns-zone-id>"]
      dns = ["DNS Zone Contributor", "<dns-zone-id>"]
    }
  EOT
  type        = map(list(string))
  default     = {}
}


variable "dns_zone_suffix" {
  description = <<EOT
    The DNS Zone suffix for AKS Cluster private DNS Zone. Default is `azmk8s.io` for Public Cloud
    For gov cloud it is `cx.aks.containerservice.azure.us`
  EOT
  type        = string
  default     = "azmk8s.io"
}

variable "vnet_subnet_id" {
  type        = string
  default     = null
  description = "(Optional) The ID of a Subnet where the Kubernetes Node Pool should exist. Changing this forces a new resource to be created."
}

variable "net_profile_dns_service_ip" {
  type        = string
  default     = null
  description = "(Optional) IP address within the Kubernetes service address range that will be used by cluster service discovery (kube-dns). Changing this forces a new resource to be created."
}

variable "net_profile_outbound_type" {
  type        = string
  default     = "loadBalancer"
  description = <<EOT
    (Optional) The outbound (egress) routing method which should be used for this Kubernetes Cluster. Possible values are
    loadBalancer and userDefinedRouting. Defaults to loadBalancer.
    if `userDefinedRouting` is selected, `user_defined_routing` variable is required.
  EOT
}

variable "user_defined_routing" {
  description = <<EOT
    This variable is required only when net_profile_outbound_type is set to `userDefinedRouting`
    The private IP address of the Azure Firewall instance is needed to create route in custom Route table
  EOT
  type = object({
    azure_firewall_private_ip_address = string
  })
  default = null
}

variable "net_profile_pod_cidr" {
  type        = string
  default     = null
  description = " (Optional) The CIDR to use for pod IP addresses. This field can only be set when network_plugin is set to kubenet. Changing this forces a new resource to be created."
}

variable "net_profile_service_cidr" {
  type        = string
  default     = null
  description = "(Optional) The Network Range used by the Kubernetes service. Changing this forces a new resource to be created."
}

variable "agents_availability_zones" {
  type        = list(string)
  default     = null
  description = "(Optional) A list of Availability Zones across which the Node Pool should be spread. Changing this forces a new resource to be created."
}

variable "agents_count" {
  type        = number
  default     = 2
  description = "The number of Agents that should exist in the Agent Pool. Please set `agents_count` `null` while `enable_auto_scaling` is `true` to avoid possible `agents_count` changes."
}

variable "agents_labels" {
  type        = map(string)
  default     = {}
  description = "(Optional) A map of Kubernetes labels which should be applied to nodes in the Default Node Pool. Changing this forces a new resource to be created."
}

variable "agents_max_count" {
  type        = number
  default     = null
  description = "Maximum number of nodes in a pool"
}

variable "agents_max_pods" {
  type        = number
  default     = null
  description = "(Optional) The maximum number of pods that can run on each agent. Changing this forces a new resource to be created."
}

variable "agents_min_count" {
  type        = number
  default     = null
  description = "Minimum number of nodes in a pool"
}

variable "agents_pool_max_surge" {
  type        = string
  default     = null
  description = "The maximum number or percentage of nodes which will be added to the Default Node Pool size during an upgrade."
}

variable "agents_pool_linux_os_configs" {
  type = list(object({
    sysctl_configs = optional(list(object({
      fs_aio_max_nr                      = optional(number)
      fs_file_max                        = optional(number)
      fs_inotify_max_user_watches        = optional(number)
      fs_nr_open                         = optional(number)
      kernel_threads_max                 = optional(number)
      net_core_netdev_max_backlog        = optional(number)
      net_core_optmem_max                = optional(number)
      net_core_rmem_default              = optional(number)
      net_core_rmem_max                  = optional(number)
      net_core_somaxconn                 = optional(number)
      net_core_wmem_default              = optional(number)
      net_core_wmem_max                  = optional(number)
      net_ipv4_ip_local_port_range_min   = optional(number)
      net_ipv4_ip_local_port_range_max   = optional(number)
      net_ipv4_neigh_default_gc_thresh1  = optional(number)
      net_ipv4_neigh_default_gc_thresh2  = optional(number)
      net_ipv4_neigh_default_gc_thresh3  = optional(number)
      net_ipv4_tcp_fin_timeout           = optional(number)
      net_ipv4_tcp_keepalive_intvl       = optional(number)
      net_ipv4_tcp_keepalive_probes      = optional(number)
      net_ipv4_tcp_keepalive_time        = optional(number)
      net_ipv4_tcp_max_syn_backlog       = optional(number)
      net_ipv4_tcp_max_tw_buckets        = optional(number)
      net_ipv4_tcp_tw_reuse              = optional(bool)
      net_netfilter_nf_conntrack_buckets = optional(number)
      net_netfilter_nf_conntrack_max     = optional(number)
      vm_max_map_count                   = optional(number)
      vm_swappiness                      = optional(number)
      vm_vfs_cache_pressure              = optional(number)
    })), [])
    transparent_huge_page_enabled = optional(string)
    transparent_huge_page_defrag  = optional(string)
    swap_file_size_mb             = optional(number)
  }))
  default     = []
  description = <<-EOT
  list(object({
    sysctl_configs = optional(list(object({
      fs_aio_max_nr                      = (Optional) The sysctl setting fs.aio-max-nr. Must be between `65536` and `6553500`. Changing this forces a new resource to be created.
      fs_file_max                        = (Optional) The sysctl setting fs.file-max. Must be between `8192` and `12000500`. Changing this forces a new resource to be created.
      fs_inotify_max_user_watches        = (Optional) The sysctl setting fs.inotify.max_user_watches. Must be between `781250` and `2097152`. Changing this forces a new resource to be created.
      fs_nr_open                         = (Optional) The sysctl setting fs.nr_open. Must be between `8192` and `20000500`. Changing this forces a new resource to be created.
      kernel_threads_max                 = (Optional) The sysctl setting kernel.threads-max. Must be between `20` and `513785`. Changing this forces a new resource to be created.
      net_core_netdev_max_backlog        = (Optional) The sysctl setting net.core.netdev_max_backlog. Must be between `1000` and `3240000`. Changing this forces a new resource to be created.
      net_core_optmem_max                = (Optional) The sysctl setting net.core.optmem_max. Must be between `20480` and `4194304`. Changing this forces a new resource to be created.
      net_core_rmem_default              = (Optional) The sysctl setting net.core.rmem_default. Must be between `212992` and `134217728`. Changing this forces a new resource to be created.
      net_core_rmem_max                  = (Optional) The sysctl setting net.core.rmem_max. Must be between `212992` and `134217728`. Changing this forces a new resource to be created.
      net_core_somaxconn                 = (Optional) The sysctl setting net.core.somaxconn. Must be between `4096` and `3240000`. Changing this forces a new resource to be created.
      net_core_wmem_default              = (Optional) The sysctl setting net.core.wmem_default. Must be between `212992` and `134217728`. Changing this forces a new resource to be created.
      net_core_wmem_max                  = (Optional) The sysctl setting net.core.wmem_max. Must be between `212992` and `134217728`. Changing this forces a new resource to be created.
      net_ipv4_ip_local_port_range_min   = (Optional) The sysctl setting net.ipv4.ip_local_port_range max value. Must be between `1024` and `60999`. Changing this forces a new resource to be created.
      net_ipv4_ip_local_port_range_max   = (Optional) The sysctl setting net.ipv4.ip_local_port_range min value. Must be between `1024` and `60999`. Changing this forces a new resource to be created.
      net_ipv4_neigh_default_gc_thresh1  = (Optional) The sysctl setting net.ipv4.neigh.default.gc_thresh1. Must be between `128` and `80000`. Changing this forces a new resource to be created.
      net_ipv4_neigh_default_gc_thresh2  = (Optional) The sysctl setting net.ipv4.neigh.default.gc_thresh2. Must be between `512` and `90000`. Changing this forces a new resource to be created.
      net_ipv4_neigh_default_gc_thresh3  = (Optional) The sysctl setting net.ipv4.neigh.default.gc_thresh3. Must be between `1024` and `100000`. Changing this forces a new resource to be created.
      net_ipv4_tcp_fin_timeout           = (Optional) The sysctl setting net.ipv4.tcp_fin_timeout. Must be between `5` and `120`. Changing this forces a new resource to be created.
      net_ipv4_tcp_keepalive_intvl       = (Optional) The sysctl setting net.ipv4.tcp_keepalive_intvl. Must be between `10` and `75`. Changing this forces a new resource to be created.
      net_ipv4_tcp_keepalive_probes      = (Optional) The sysctl setting net.ipv4.tcp_keepalive_probes. Must be between `1` and `15`. Changing this forces a new resource to be created.
      net_ipv4_tcp_keepalive_time        = (Optional) The sysctl setting net.ipv4.tcp_keepalive_time. Must be between `30` and `432000`. Changing this forces a new resource to be created.
      net_ipv4_tcp_max_syn_backlog       = (Optional) The sysctl setting net.ipv4.tcp_max_syn_backlog. Must be between `128` and `3240000`. Changing this forces a new resource to be created.
      net_ipv4_tcp_max_tw_buckets        = (Optional) The sysctl setting net.ipv4.tcp_max_tw_buckets. Must be between `8000` and `1440000`. Changing this forces a new resource to be created.
      net_ipv4_tcp_tw_reuse              = (Optional) The sysctl setting net.ipv4.tcp_tw_reuse. Changing this forces a new resource to be created.
      net_netfilter_nf_conntrack_buckets = (Optional) The sysctl setting net.netfilter.nf_conntrack_buckets. Must be between `65536` and `147456`. Changing this forces a new resource to be created.
      net_netfilter_nf_conntrack_max     = (Optional) The sysctl setting net.netfilter.nf_conntrack_max. Must be between `131072` and `1048576`. Changing this forces a new resource to be created.
      vm_max_map_count                   = (Optional) The sysctl setting vm.max_map_count. Must be between `65530` and `262144`. Changing this forces a new resource to be created.
      vm_swappiness                      = (Optional) The sysctl setting vm.swappiness. Must be between `0` and `100`. Changing this forces a new resource to be created.
      vm_vfs_cache_pressure              = (Optional) The sysctl setting vm.vfs_cache_pressure. Must be between `0` and `100`. Changing this forces a new resource to be created.
    })), [])
    transparent_huge_page_enabled = (Optional) Specifies the Transparent Huge Page enabled configuration. Possible values are `always`, `madvise` and `never`. Changing this forces a new resource to be created.
    transparent_huge_page_defrag  = (Optional) specifies the defrag configuration for Transparent Huge Page. Possible values are `always`, `defer`, `defer+madvise`, `madvise` and `never`. Changing this forces a new resource to be created.
    swap_file_size_mb             = (Optional) Specifies the size of the swap file on each node in MB. Changing this forces a new resource to be created.
  }))
EOT
  nullable    = false
}

variable "agents_pool_name" {
  type        = string
  default     = "nodepool"
  description = "The default Azure AKS agentpool (nodepool) name."
  nullable    = false
}

variable "agents_proximity_placement_group_id" {
  type        = string
  default     = null
  description = "(Optional) The ID of the Proximity Placement Group of the default Azure AKS agentpool (nodepool). Changing this forces a new resource to be created."
}

variable "agents_size" {
  type        = string
  default     = "Standard_D2_v2"
  description = "The default virtual machine size for the Kubernetes agents. Changing this without specifying `var.temporary_name_for_rotation` forces a new resource to be created."
}

variable "agents_tags" {
  type        = map(string)
  default     = {}
  description = "(Optional) A mapping of tags to assign to the Node Pool."
}

variable "agents_taints" {
  type        = list(string)
  default     = null
  description = "(Optional) A list of the taints added to new nodes during node pool create and scale. Changing this forces a new resource to be created."
}

variable "agents_type" {
  type        = string
  default     = "VirtualMachineScaleSets"
  description = "(Optional) The type of Node Pool which should be created. Possible values are AvailabilitySet and VirtualMachineScaleSets. Defaults to VirtualMachineScaleSets."
}

variable "api_server_authorized_ip_ranges" {
  type        = set(string)
  default     = null
  description = "(Optional) The IP ranges to allow for incoming traffic to the server nodes."
}

variable "api_server_subnet_id" {
  type        = string
  default     = null
  description = "(Optional) The ID of the Subnet where the API server endpoint is delegated to."
}

variable "attached_acr_id_map" {
  type        = map(string)
  default     = {}
  description = "Azure Container Registry ids that need an authentication mechanism with Azure Kubernetes Service (AKS). Map key must be static string as acr's name, the value is acr's resource id. Changing this forces some new resources to be created."
  nullable    = false
}

variable "enable_auto_scaling" {
  type        = bool
  default     = false
  description = "Enable node pool autoscaling. Please set `agents_count` `null` while `enable_auto_scaling` is `true` to avoid possible `agents_count` changes."
}

variable "auto_scaler_profile_balance_similar_node_groups" {
  type        = bool
  default     = false
  description = "Detect similar node groups and balance the number of nodes between them. Defaults to `false`."
}

variable "auto_scaler_profile_empty_bulk_delete_max" {
  type        = number
  default     = 10
  description = "Maximum number of empty nodes that can be deleted at the same time. Defaults to `10`."
}

variable "auto_scaler_profile_enabled" {
  type        = bool
  default     = false
  description = "Enable configuring the auto scaler profile"
  nullable    = false
}

variable "auto_scaler_profile_expander" {
  type        = string
  default     = "random"
  description = "Expander to use. Possible values are `least-waste`, `priority`, `most-pods` and `random`. Defaults to `random`."

  validation {
    condition     = contains(["least-waste", "most-pods", "priority", "random"], var.auto_scaler_profile_expander)
    error_message = "Must be either `least-waste`, `most-pods`, `priority` or `random`."
  }
}

variable "auto_scaler_profile_max_graceful_termination_sec" {
  type        = string
  default     = "600"
  description = "Maximum number of seconds the cluster autoscaler waits for pod termination when trying to scale down a node. Defaults to `600`."
}

variable "auto_scaler_profile_max_node_provisioning_time" {
  type        = string
  default     = "15m"
  description = "Maximum time the autoscaler waits for a node to be provisioned. Defaults to `15m`."
}

variable "auto_scaler_profile_max_unready_nodes" {
  type        = number
  default     = 3
  description = "Maximum Number of allowed unready nodes. Defaults to `3`."
}

variable "auto_scaler_profile_max_unready_percentage" {
  type        = number
  default     = 45
  description = "Maximum percentage of unready nodes the cluster autoscaler will stop if the percentage is exceeded. Defaults to `45`."
}

variable "auto_scaler_profile_new_pod_scale_up_delay" {
  type        = string
  default     = "10s"
  description = "For scenarios like burst/batch scale where you don't want CA to act before the kubernetes scheduler could schedule all the pods, you can tell CA to ignore unscheduled pods before they're a certain age. Defaults to `10s`."
}

variable "auto_scaler_profile_scale_down_delay_after_add" {
  type        = string
  default     = "10m"
  description = "How long after the scale up of AKS nodes the scale down evaluation resumes. Defaults to `10m`."
}

variable "auto_scaler_profile_scale_down_delay_after_delete" {
  type        = string
  default     = null
  description = "How long after node deletion that scale down evaluation resumes. Defaults to the value used for `scan_interval`."
}

variable "auto_scaler_profile_scale_down_delay_after_failure" {
  type        = string
  default     = "3m"
  description = "How long after scale down failure that scale down evaluation resumes. Defaults to `3m`."
}

variable "auto_scaler_profile_scale_down_unneeded" {
  type        = string
  default     = "10m"
  description = "How long a node should be unneeded before it is eligible for scale down. Defaults to `10m`."
}

variable "auto_scaler_profile_scale_down_unready" {
  type        = string
  default     = "20m"
  description = "How long an unready node should be unneeded before it is eligible for scale down. Defaults to `20m`."
}

variable "auto_scaler_profile_scale_down_utilization_threshold" {
  type        = string
  default     = "0.5"
  description = "Node utilization level, defined as sum of requested resources divided by capacity, below which a node can be considered for scale down. Defaults to `0.5`."
}

variable "auto_scaler_profile_scan_interval" {
  type        = string
  default     = "10s"
  description = "How often the AKS Cluster should be re-evaluated for scale up/down. Defaults to `10s`."
}

variable "auto_scaler_profile_skip_nodes_with_local_storage" {
  type        = bool
  default     = true
  description = "If `true` cluster autoscaler will never delete nodes with pods with local storage, for example, EmptyDir or HostPath. Defaults to `true`."
}

variable "auto_scaler_profile_skip_nodes_with_system_pods" {
  type        = bool
  default     = true
  description = "If `true` cluster autoscaler will never delete nodes with pods from kube-system (except for DaemonSet or mirror pods). Defaults to `true`."
}

variable "os_disk_size_gb" {
  type        = number
  default     = 50
  description = "Disk size of nodes in GBs."
}

variable "os_disk_type" {
  type        = string
  default     = "Managed"
  description = "The type of disk which should be used for the Operating System. Possible values are `Ephemeral` and `Managed`. Defaults to `Managed`. Changing this forces a new resource to be created."
  nullable    = false
}

variable "os_sku" {
  type        = string
  default     = null
  description = "(Optional) Specifies the OS SKU used by the agent pool. Possible values include: `Ubuntu`, `CBLMariner`, `Mariner`, `Windows2019`, `Windows2022`. If not specified, the default is `Ubuntu` if OSType=Linux or `Windows2019` if OSType=Windows. And the default Windows OSSKU will be changed to `Windows2022` after Windows2019 is deprecated. Changing this forces a new resource to be created."
}

variable "pod_subnet_id" {
  type        = string
  default     = null
  description = "(Optional) The ID of the Subnet where the pods in the default Node Pool should exist. Changing this forces a new resource to be created."
}

# RBAC related
variable "rbac_aad" {
  type        = bool
  default     = false
  description = "(Optional) Is Azure Active Directory integration enabled?"
  nullable    = false
}

variable "rbac_aad_admin_group_object_ids" {
  type        = list(string)
  default     = null
  description = "Object ID of groups with admin access."
}

variable "rbac_aad_azure_rbac_enabled" {
  type        = bool
  default     = null
  description = "(Optional) Is Role Based Access Control based on Azure AD enabled?"
}

variable "rbac_aad_client_app_id" {
  type        = string
  default     = null
  description = "The Client ID of an Azure Active Directory Application."
}

variable "rbac_aad_managed" {
  type        = bool
  default     = false
  description = "Is the Azure Active Directory integration Managed, meaning that Azure will create/manage the Service Principal used for integration."
  nullable    = false
}

variable "rbac_aad_server_app_id" {
  type        = string
  default     = null
  description = "The Server ID of an Azure Active Directory Application."
}

variable "rbac_aad_server_app_secret" {
  type        = string
  default     = null
  description = "The Server Secret of an Azure Active Directory Application."
}

variable "rbac_aad_tenant_id" {
  type        = string
  default     = null
  description = "(Optional) The Tenant ID used for Azure Active Directory Application. If this isn't specified the Tenant ID of the current Subscription is used."
}

variable "role_based_access_control_enabled" {
  type        = bool
  default     = false
  description = "Enable Role Based Access Control. If this is disabled, then identity_type='SystemAssigned' by default"
  nullable    = false
}

variable "local_account_disabled" {
  type        = bool
  default     = null
  description = "(Optional) - If `true` local accounts will be disabled. Defaults to `false`. See [the documentation](https://docs.microsoft.com/azure/aks/managed-aad#disable-local-accounts) for more information."
}

# Workload Identity

variable "oidc_issuer_enabled" {
  type        = bool
  default     = false
  description = "Enable or Disable the OIDC issuer URL. Defaults to false."
}

variable "workload_identity_enabled" {
  type        = bool
  default     = false
  description = "Enable or Disable Workload Identity. If enabled, oidc_issuer_enabled must be true. Defaults to false."
}

# Options for log analytics
variable "cluster_log_analytics_workspace_name" {
  type        = string
  default     = null
  description = "(Optional) The name of the Analytics workspace to create"
}

variable "log_analytics_workspace" {
  type = object({
    id                  = string
    name                = string
    location            = optional(string)
    resource_group_name = optional(string)
  })
  default     = null
  description = "(Optional) Existing azurerm_log_analytics_workspace to attach azurerm_log_analytics_solution. Providing the config disables creation of azurerm_log_analytics_workspace."
}

variable "log_analytics_workspace_allow_resource_only_permissions" {
  type        = bool
  default     = null
  description = "(Optional) Specifies if the log Analytics Workspace allow users accessing to data associated with resources they have permission to view, without permission to workspace. Defaults to `true`."
}

variable "log_analytics_workspace_cmk_for_query_forced" {
  type        = bool
  default     = null
  description = "(Optional) Is Customer Managed Storage mandatory for query management?"
}

variable "log_analytics_workspace_daily_quota_gb" {
  type        = number
  default     = null
  description = "(Optional) The workspace daily quota for ingestion in GB. Defaults to -1 (unlimited) if omitted."
}

variable "log_analytics_workspace_data_collection_rule_id" {
  type        = string
  default     = null
  description = "(Optional) The ID of the Data Collection Rule to use for this workspace."
}

variable "log_analytics_workspace_enabled" {
  type        = bool
  default     = true
  description = "Enable the integration of azurerm_log_analytics_workspace and azurerm_log_analytics_solution: https://docs.microsoft.com/en-us/azure/azure-monitor/containers/container-insights-onboard"
  nullable    = false
}

variable "log_analytics_workspace_resource_group_name" {
  type        = string
  default     = null
  description = "(Optional) Resource group name to create azurerm_log_analytics_solution."
}

variable "log_analytics_workspace_sku" {
  type        = string
  default     = "PerGB2018"
  description = "The SKU (pricing level) of the Log Analytics workspace. For new subscriptions the SKU should be set to PerGB2018"
}

variable "log_analytics_workspace_identity" {
  type = object({
    identity_ids = optional(set(string))
    type         = string
  })
  default     = null
  description = <<-EOT
 - `identity_ids` - (Optional) Specifies a list of user managed identity ids to be assigned. Required if `type` is `UserAssigned`.
 - `type` - (Required) Specifies the identity type of the Log Analytics Workspace. Possible values are `SystemAssigned` (where Azure will generate a Service Principal for you) and `UserAssigned` where you can specify the Service Principal IDs in the `identity_ids` field.
EOT
}

variable "log_analytics_workspace_immediate_data_purge_on_30_days_enabled" {
  type        = bool
  default     = null
  description = "(Optional) Whether to remove the data in the Log Analytics Workspace immediately after 30 days."
}

variable "log_analytics_workspace_internet_ingestion_enabled" {
  type        = bool
  default     = null
  description = "(Optional) Should the Log Analytics Workspace support ingestion over the Public Internet? Defaults to `true`."
}

variable "log_analytics_workspace_internet_query_enabled" {
  type        = bool
  default     = null
  description = "(Optional) Should the Log Analytics Workspace support querying over the Public Internet? Defaults to `true`."
}

variable "log_analytics_workspace_local_authentication_disabled" {
  type        = bool
  default     = null
  description = "(Optional) Specifies if the log Analytics workspace should enforce authentication using Azure AD. Defaults to `false`."
}

variable "log_analytics_workspace_reservation_capacity_in_gb_per_day" {
  type        = number
  default     = null
  description = "(Optional) The capacity reservation level in GB for this workspace. Possible values are `100`, `200`, `300`, `400`, `500`, `1000`, `2000` and `5000`."
}

variable "log_retention_in_days" {
  type        = number
  default     = 30
  description = "The retention period for the logs in days"
}

# Additional Node pools
variable "node_pools" {
  type = map(object({
    name                          = string
    node_count                    = optional(number)
    tags                          = optional(map(string))
    vm_size                       = string
    host_group_id                 = optional(string)
    capacity_reservation_group_id = optional(string)
    custom_ca_trust_enabled       = optional(bool)
    enable_auto_scaling           = optional(bool)
    enable_host_encryption        = optional(bool)
    enable_node_public_ip         = optional(bool)
    eviction_policy               = optional(string)
    gpu_instance                  = optional(string)
    kubelet_config = optional(object({
      cpu_manager_policy        = optional(string)
      cpu_cfs_quota_enabled     = optional(bool)
      cpu_cfs_quota_period      = optional(string)
      image_gc_high_threshold   = optional(number)
      image_gc_low_threshold    = optional(number)
      topology_manager_policy   = optional(string)
      allowed_unsafe_sysctls    = optional(set(string))
      container_log_max_size_mb = optional(number)
      container_log_max_files   = optional(number)
      pod_max_pid               = optional(number)
    }))
    linux_os_config = optional(object({
      sysctl_config = optional(object({
        fs_aio_max_nr                      = optional(number)
        fs_file_max                        = optional(number)
        fs_inotify_max_user_watches        = optional(number)
        fs_nr_open                         = optional(number)
        kernel_threads_max                 = optional(number)
        net_core_netdev_max_backlog        = optional(number)
        net_core_optmem_max                = optional(number)
        net_core_rmem_default              = optional(number)
        net_core_rmem_max                  = optional(number)
        net_core_somaxconn                 = optional(number)
        net_core_wmem_default              = optional(number)
        net_core_wmem_max                  = optional(number)
        net_ipv4_ip_local_port_range_min   = optional(number)
        net_ipv4_ip_local_port_range_max   = optional(number)
        net_ipv4_neigh_default_gc_thresh1  = optional(number)
        net_ipv4_neigh_default_gc_thresh2  = optional(number)
        net_ipv4_neigh_default_gc_thresh3  = optional(number)
        net_ipv4_tcp_fin_timeout           = optional(number)
        net_ipv4_tcp_keepalive_intvl       = optional(number)
        net_ipv4_tcp_keepalive_probes      = optional(number)
        net_ipv4_tcp_keepalive_time        = optional(number)
        net_ipv4_tcp_max_syn_backlog       = optional(number)
        net_ipv4_tcp_max_tw_buckets        = optional(number)
        net_ipv4_tcp_tw_reuse              = optional(bool)
        net_netfilter_nf_conntrack_buckets = optional(number)
        net_netfilter_nf_conntrack_max     = optional(number)
        vm_max_map_count                   = optional(number)
        vm_swappiness                      = optional(number)
        vm_vfs_cache_pressure              = optional(number)
      }))
      transparent_huge_page_enabled = optional(string)
      transparent_huge_page_defrag  = optional(string)
      swap_file_size_mb             = optional(number)
    }))
    fips_enabled       = optional(bool)
    kubelet_disk_type  = optional(string)
    max_count          = optional(number)
    max_pods           = optional(number)
    message_of_the_day = optional(string)
    mode               = optional(string, "User")
    min_count          = optional(number)
    node_network_profile = optional(object({
      node_public_ip_tags = optional(map(string))
    }))
    node_labels                  = optional(map(string))
    node_public_ip_prefix_id     = optional(string)
    node_taints                  = optional(list(string))
    orchestrator_version         = optional(string)
    os_disk_size_gb              = optional(number)
    os_disk_type                 = optional(string, "Managed")
    os_sku                       = optional(string)
    os_type                      = optional(string, "Linux")
    pod_subnet_id                = optional(string)
    priority                     = optional(string, "Regular")
    proximity_placement_group_id = optional(string)
    spot_max_price               = optional(number)
    scale_down_mode              = optional(string, "Delete")
    snapshot_id                  = optional(string)
    ultra_ssd_enabled            = optional(bool)
    vnet_subnet_id               = optional(string)
    upgrade_settings = optional(object({
      drain_timeout_in_minutes      = number
      node_soak_duration_in_minutes = number
      max_surge                     = string
    }))
    windows_profile = optional(object({
      outbound_nat_enabled = optional(bool, true)
    }))
    workload_runtime      = optional(string)
    zones                 = optional(set(string))
    create_before_destroy = optional(bool, true)
  }))
  default     = {}
  description = <<-EOT
  A map of node pools that need to be created and attached on the Kubernetes cluster. The key of the map can be the name of the node pool, and the key must be static string. The value of the map is a `node_pool` block as defined below:
  map(object({
    name                          = (Required) The name of the Node Pool which should be created within the Kubernetes Cluster. Changing this forces a new resource to be created. A Windows Node Pool cannot have a `name` longer than 6 characters. A random suffix of 4 characters is always added to the name to avoid clashes during recreates.
    node_count                    = (Optional) The initial number of nodes which should exist within this Node Pool. Valid values are between `0` and `1000` (inclusive) for user pools and between `1` and `1000` (inclusive) for system pools and must be a value in the range `min_count` - `max_count`.
    tags                          = (Optional) A mapping of tags to assign to the resource. At this time there's a bug in the AKS API where Tags for a Node Pool are not stored in the correct case - you [may wish to use Terraform's `ignore_changes` functionality to ignore changes to the casing](https://www.terraform.io/language/meta-arguments/lifecycle#ignore_changess) until this is fixed in the AKS API.
    vm_size                       = (Required) The SKU which should be used for the Virtual Machines used in this Node Pool. Changing this forces a new resource to be created.
    host_group_id                 = (Optional) The fully qualified resource ID of the Dedicated Host Group to provision virtual machines from. Changing this forces a new resource to be created.
    capacity_reservation_group_id = (Optional) Specifies the ID of the Capacity Reservation Group where this Node Pool should exist. Changing this forces a new resource to be created.
    custom_ca_trust_enabled       = (Optional) Specifies whether to trust a Custom CA. This requires that the Preview Feature `Microsoft.ContainerService/CustomCATrustPreview` is enabled and the Resource Provider is re-registered, see [the documentation](https://learn.microsoft.com/en-us/azure/aks/custom-certificate-authority) for more information.
    enable_auto_scaling           = (Optional) Whether to enable [auto-scaler](https://docs.microsoft.com/azure/aks/cluster-autoscaler).
    enable_host_encryption        = (Optional) Should the nodes in this Node Pool have host encryption enabled? Changing this forces a new resource to be created.
    enable_node_public_ip         = (Optional) Should each node have a Public IP Address? Changing this forces a new resource to be created.
    eviction_policy               = (Optional) The Eviction Policy which should be used for Virtual Machines within the Virtual Machine Scale Set powering this Node Pool. Possible values are `Deallocate` and `Delete`. Changing this forces a new resource to be created. An Eviction Policy can only be configured when `priority` is set to `Spot` and will default to `Delete` unless otherwise specified.
    gpu_instance                  = (Optional) Specifies the GPU MIG instance profile for supported GPU VM SKU. The allowed values are `MIG1g`, `MIG2g`, `MIG3g`, `MIG4g` and `MIG7g`. Changing this forces a new resource to be created.
    kubelet_config = optional(object({
      cpu_manager_policy        = (Optional) Specifies the CPU Manager policy to use. Possible values are `none` and `static`, Changing this forces a new resource to be created.
      cpu_cfs_quota_enabled     = (Optional) Is CPU CFS quota enforcement for containers enabled? Changing this forces a new resource to be created.
      cpu_cfs_quota_period      = (Optional) Specifies the CPU CFS quota period value. Changing this forces a new resource to be created.
      image_gc_high_threshold   = (Optional) Specifies the percent of disk usage above which image garbage collection is always run. Must be between `0` and `100`. Changing this forces a new resource to be created.
      image_gc_low_threshold    = (Optional) Specifies the percent of disk usage lower than which image garbage collection is never run. Must be between `0` and `100`. Changing this forces a new resource to be created.
      topology_manager_policy   = (Optional) Specifies the Topology Manager policy to use. Possible values are `none`, `best-effort`, `restricted` or `single-numa-node`. Changing this forces a new resource to be created.
      allowed_unsafe_sysctls    = (Optional) Specifies the allow list of unsafe sysctls command or patterns (ending in `*`). Changing this forces a new resource to be created.
      container_log_max_size_mb = (Optional) Specifies the maximum size (e.g. 10MB) of container log file before it is rotated. Changing this forces a new resource to be created.
      container_log_max_files   = (Optional) Specifies the maximum number of container log files that can be present for a container. must be at least 2. Changing this forces a new resource to be created.
      pod_max_pid               = (Optional) Specifies the maximum number of processes per pod. Changing this forces a new resource to be created.
    }))
    linux_os_config = optional(object({
      sysctl_config = optional(object({
        fs_aio_max_nr                      = (Optional) The sysctl setting fs.aio-max-nr. Must be between `65536` and `6553500`. Changing this forces a new resource to be created.
        fs_file_max                        = (Optional) The sysctl setting fs.file-max. Must be between `8192` and `12000500`. Changing this forces a new resource to be created.
        fs_inotify_max_user_watches        = (Optional) The sysctl setting fs.inotify.max_user_watches. Must be between `781250` and `2097152`. Changing this forces a new resource to be created.
        fs_nr_open                         = (Optional) The sysctl setting fs.nr_open. Must be between `8192` and `20000500`. Changing this forces a new resource to be created.
        kernel_threads_max                 = (Optional) The sysctl setting kernel.threads-max. Must be between `20` and `513785`. Changing this forces a new resource to be created.
        net_core_netdev_max_backlog        = (Optional) The sysctl setting net.core.netdev_max_backlog. Must be between `1000` and `3240000`. Changing this forces a new resource to be created.
        net_core_optmem_max                = (Optional) The sysctl setting net.core.optmem_max. Must be between `20480` and `4194304`. Changing this forces a new resource to be created.
        net_core_rmem_default              = (Optional) The sysctl setting net.core.rmem_default. Must be between `212992` and `134217728`. Changing this forces a new resource to be created.
        net_core_rmem_max                  = (Optional) The sysctl setting net.core.rmem_max. Must be between `212992` and `134217728`. Changing this forces a new resource to be created.
        net_core_somaxconn                 = (Optional) The sysctl setting net.core.somaxconn. Must be between `4096` and `3240000`. Changing this forces a new resource to be created.
        net_core_wmem_default              = (Optional) The sysctl setting net.core.wmem_default. Must be between `212992` and `134217728`. Changing this forces a new resource to be created.
        net_core_wmem_max                  = (Optional) The sysctl setting net.core.wmem_max. Must be between `212992` and `134217728`. Changing this forces a new resource to be created.
        net_ipv4_ip_local_port_range_min   = (Optional) The sysctl setting net.ipv4.ip_local_port_range min value. Must be between `1024` and `60999`. Changing this forces a new resource to be created.
        net_ipv4_ip_local_port_range_max   = (Optional) The sysctl setting net.ipv4.ip_local_port_range max value. Must be between `1024` and `60999`. Changing this forces a new resource to be created.
        net_ipv4_neigh_default_gc_thresh1  = (Optional) The sysctl setting net.ipv4.neigh.default.gc_thresh1. Must be between `128` and `80000`. Changing this forces a new resource to be created.
        net_ipv4_neigh_default_gc_thresh2  = (Optional) The sysctl setting net.ipv4.neigh.default.gc_thresh2. Must be between `512` and `90000`. Changing this forces a new resource to be created.
        net_ipv4_neigh_default_gc_thresh3  = (Optional) The sysctl setting net.ipv4.neigh.default.gc_thresh3. Must be between `1024` and `100000`. Changing this forces a new resource to be created.
        net_ipv4_tcp_fin_timeout           = (Optional) The sysctl setting net.ipv4.tcp_fin_timeout. Must be between `5` and `120`. Changing this forces a new resource to be created.
        net_ipv4_tcp_keepalive_intvl       = (Optional) The sysctl setting net.ipv4.tcp_keepalive_intvl. Must be between `10` and `75`. Changing this forces a new resource to be created.
        net_ipv4_tcp_keepalive_probes      = (Optional) The sysctl setting net.ipv4.tcp_keepalive_probes. Must be between `1` and `15`. Changing this forces a new resource to be created.
        net_ipv4_tcp_keepalive_time        = (Optional) The sysctl setting net.ipv4.tcp_keepalive_time. Must be between `30` and `432000`. Changing this forces a new resource to be created.
        net_ipv4_tcp_max_syn_backlog       = (Optional) The sysctl setting net.ipv4.tcp_max_syn_backlog. Must be between `128` and `3240000`. Changing this forces a new resource to be created.
        net_ipv4_tcp_max_tw_buckets        = (Optional) The sysctl setting net.ipv4.tcp_max_tw_buckets. Must be between `8000` and `1440000`. Changing this forces a new resource to be created.
        net_ipv4_tcp_tw_reuse              = (Optional) Is sysctl setting net.ipv4.tcp_tw_reuse enabled? Changing this forces a new resource to be created.
        net_netfilter_nf_conntrack_buckets = (Optional) The sysctl setting net.netfilter.nf_conntrack_buckets. Must be between `65536` and `147456`. Changing this forces a new resource to be created.
        net_netfilter_nf_conntrack_max     = (Optional) The sysctl setting net.netfilter.nf_conntrack_max. Must be between `131072` and `1048576`. Changing this forces a new resource to be created.
        vm_max_map_count                   = (Optional) The sysctl setting vm.max_map_count. Must be between `65530` and `262144`. Changing this forces a new resource to be created.
        vm_swappiness                      = (Optional) The sysctl setting vm.swappiness. Must be between `0` and `100`. Changing this forces a new resource to be created.
        vm_vfs_cache_pressure              = (Optional) The sysctl setting vm.vfs_cache_pressure. Must be between `0` and `100`. Changing this forces a new resource to be created.
      }))
      transparent_huge_page_enabled = (Optional) Specifies the Transparent Huge Page enabled configuration. Possible values are `always`, `madvise` and `never`. Changing this forces a new resource to be created.
      transparent_huge_page_defrag  = (Optional) specifies the defrag configuration for Transparent Huge Page. Possible values are `always`, `defer`, `defer+madvise`, `madvise` and `never`. Changing this forces a new resource to be created.
      swap_file_size_mb             = (Optional) Specifies the size of swap file on each node in MB. Changing this forces a new resource to be created.
    }))
    fips_enabled       = (Optional) Should the nodes in this Node Pool have Federal Information Processing Standard enabled? Changing this forces a new resource to be created. FIPS support is in Public Preview - more information and details on how to opt into the Preview can be found in [this article](https://docs.microsoft.com/azure/aks/use-multiple-node-pools#add-a-fips-enabled-node-pool-preview).
    kubelet_disk_type  = (Optional) The type of disk used by kubelet. Possible values are `OS` and `Temporary`.
    max_count          = (Optional) The maximum number of nodes which should exist within this Node Pool. Valid values are between `0` and `1000` and must be greater than or equal to `min_count`.
    max_pods           = (Optional) The minimum number of nodes which should exist within this Node Pool. Valid values are between `0` and `1000` and must be less than or equal to `max_count`.
    message_of_the_day = (Optional) A base64-encoded string which will be written to /etc/motd after decoding. This allows customization of the message of the day for Linux nodes. It cannot be specified for Windows nodes and must be a static string (i.e. will be printed raw and not executed as a script). Changing this forces a new resource to be created.
    mode               = (Optional) Should this Node Pool be used for System or User resources? Possible values are `System` and `User`. Defaults to `User`.
    min_count          = (Optional) The minimum number of nodes which should exist within this Node Pool. Valid values are between `0` and `1000` and must be less than or equal to `max_count`.
    node_network_profile = optional(object({
      node_public_ip_tags = (Optional) Specifies a mapping of tags to the instance-level public IPs. Changing this forces a new resource to be created.
    }))
    node_labels                  = (Optional) A map of Kubernetes labels which should be applied to nodes in this Node Pool.
    node_public_ip_prefix_id     = (Optional) Resource ID for the Public IP Addresses Prefix for the nodes in this Node Pool. `enable_node_public_ip` should be `true`. Changing this forces a new resource to be created.
    node_taints                  = (Optional) A list of Kubernetes taints which should be applied to nodes in the agent pool (e.g `key=value:NoSchedule`). Changing this forces a new resource to be created.
    orchestrator_version         = (Optional) Version of Kubernetes used for the Agents. If not specified, the latest recommended version will be used at provisioning time (but won't auto-upgrade). AKS does not require an exact patch version to be specified, minor version aliases such as `1.22` are also supported. - The minor version's latest GA patch is automatically chosen in that case. More details can be found in [the documentation](https://docs.microsoft.com/en-us/azure/aks/supported-kubernetes-versions?tabs=azure-cli#alias-minor-version). This version must be supported by the Kubernetes Cluster - as such the version of Kubernetes used on the Cluster/Control Plane may need to be upgraded first.
    os_disk_size_gb              = (Optional) The Agent Operating System disk size in GB. Changing this forces a new resource to be created.
    os_disk_type                 = (Optional) The type of disk which should be used for the Operating System. Possible values are `Ephemeral` and `Managed`. Defaults to `Managed`. Changing this forces a new resource to be created.
    os_sku                       = (Optional) Specifies the OS SKU used by the agent pool. Possible values include: `Ubuntu`, `CBLMariner`, `Mariner`, `Windows2019`, `Windows2022`. If not specified, the default is `Ubuntu` if OSType=Linux or `Windows2019` if OSType=Windows. And the default Windows OSSKU will be changed to `Windows2022` after Windows2019 is deprecated. Changing this forces a new resource to be created.
    os_type                      = (Optional) The Operating System which should be used for this Node Pool. Changing this forces a new resource to be created. Possible values are `Linux` and `Windows`. Defaults to `Linux`.
    pod_subnet_id                = (Optional) The ID of the Subnet where the pods in the Node Pool should exist. Changing this forces a new resource to be created.
    priority                     = (Optional) The Priority for Virtual Machines within the Virtual Machine Scale Set that powers this Node Pool. Possible values are `Regular` and `Spot`. Defaults to `Regular`. Changing this forces a new resource to be created.
    proximity_placement_group_id = (Optional) The ID of the Proximity Placement Group where the Virtual Machine Scale Set that powers this Node Pool will be placed. Changing this forces a new resource to be created. When setting `priority` to Spot - you must configure an `eviction_policy`, `spot_max_price` and add the applicable `node_labels` and `node_taints` [as per the Azure Documentation](https://docs.microsoft.com/azure/aks/spot-node-pool).
    spot_max_price               = (Optional) The maximum price you're willing to pay in USD per Virtual Machine. Valid values are `-1` (the current on-demand price for a Virtual Machine) or a positive value with up to five decimal places. Changing this forces a new resource to be created. This field can only be configured when `priority` is set to `Spot`.
    scale_down_mode              = (Optional) Specifies how the node pool should deal with scaled-down nodes. Allowed values are `Delete` and `Deallocate`. Defaults to `Delete`.
    snapshot_id                  = (Optional) The ID of the Snapshot which should be used to create this Node Pool. Changing this forces a new resource to be created.
    ultra_ssd_enabled            = (Optional) Used to specify whether the UltraSSD is enabled in the Node Pool. Defaults to `false`. See [the documentation](https://docs.microsoft.com/azure/aks/use-ultra-disks) for more information. Changing this forces a new resource to be created.
    vnet_subnet_id               = (Optional) The ID of the Subnet where this Node Pool should exist. Changing this forces a new resource to be created. A route table must be configured on this Subnet.
    upgrade_settings = optional(object({
      drain_timeout_in_minutes      = number
      node_soak_duration_in_minutes = number
      max_surge                     = string
    }))
    windows_profile = optional(object({
      outbound_nat_enabled = optional(bool, true)
    }))
    workload_runtime = (Optional) Used to specify the workload runtime. Allowed values are `OCIContainer` and `WasmWasi`. WebAssembly System Interface node pools are in Public Preview - more information and details on how to opt into the preview can be found in [this article](https://docs.microsoft.com/azure/aks/use-wasi-node-pools)
    zones            = (Optional) Specifies a list of Availability Zones in which this Kubernetes Cluster Node Pool should be located. Changing this forces a new Kubernetes Cluster Node Pool to be created.
    create_before_destroy = (Optional) Create a new node pool before destroy the old one when Terraform must update an argument that cannot be updated in-place. Set this argument to `true` will add add a random suffix to pool's name to avoid conflict. Default to `true`.
  }))
  EOT
  nullable    = false
}

# Open Service Mesh
variable "open_service_mesh_enabled" {
  type        = bool
  default     = null
  description = "Is Open Service Mesh enabled? For more details, please visit [Open Service Mesh for AKS](https://docs.microsoft.com/azure/aks/open-service-mesh-about)."
}

# Key Vault
variable "key_vault_secrets_provider_enabled" {
  type        = bool
  default     = false
  description = <<EOF
    (Optional) Whether to use the Azure Key Vault Provider for Secrets Store CSI Driver in an AKS cluster.
    If enabled, it creates an MSI for key vault, assigns it to the VMSS identity for key vault and assigns necessary
    permissions to the key vault. For more details: https://docs.microsoft.com/en-us/azure/aks/csi-secrets-store-driver
  EOF
  nullable    = false
}

variable "secret_rotation_enabled" {
  type        = bool
  default     = false
  description = "Is secret rotation enabled? This variable is only used when `key_vault_secrets_provider_enabled` is `true` and defaults to `false`"
  nullable    = false
}

variable "secret_rotation_interval" {
  type        = string
  default     = "2m"
  description = "The interval to poll for secret rotation. This attribute is only set when `secret_rotation` is `true` and defaults to `2m`"
  nullable    = false
}

variable "create_key_vault" {
  description = "Create a new Key Vault to be associated with the AKS cluster"
  type        = bool
  default     = false
}

variable "key_vault_role_definition" {
  description = "Permission assigned to the key vault MSI on the key vault. Default is `Key Vault Administrator`"
  type        = string
  default     = "Key Vault Administrator"
}

variable "additional_key_vault_ids" {
  description = <<EOT
    IDs of the additional key vaults to be associated with the AKS cluster. The key vault MSI will be assigned
    the role defined in `key_vault_role_definition` on these key vaults.
  EOT
  type        = list(string)
  default     = []
}

variable "enable_rbac_authorization" {
  type        = bool
  default     = false
  description = "Enable Kubernetes Role-Based Access Control on the Key Vault"
  nullable    = false
}

variable "sku_tier" {
  type        = string
  default     = "Free"
  description = "The SKU Tier that should be used for this Kubernetes Cluster. Possible values are `Free` and `Standard`"

  validation {
    condition     = contains(["Free", "Standard"], var.sku_tier)
    error_message = "The SKU Tier must be either `Free` or `Standard`. `Paid` is no longer supported since AzureRM provider v3.51.0."
  }
}

variable "node_resource_group" {
  type        = string
  default     = null
  description = "The auto-generated Resource Group which contains the resources for this Managed Kubernetes Cluster. Changing this forces a new resource to be created."
}

# Ingress Application gateway related variables
variable "brown_field_application_gateway_for_ingress" {
  type = object({
    id        = string
    subnet_id = string
  })
  default     = null
  description = <<-EOT
    [Definition of `brown_field`](https://learn.microsoft.com/en-us/azure/application-gateway/tutorial-ingress-controller-add-on-existing)
    * `id` - (Required) The ID of the Application Gateway that be used as cluster ingress.
    * `subnet_id` - (Required) The ID of the Subnet which the Application Gateway is connected to. Must be set when `create_role_assignments` is `true`.
  EOT
}

variable "green_field_application_gateway_for_ingress" {
  type = object({
    name        = optional(string)
    subnet_cidr = optional(string)
    subnet_id   = optional(string)
  })
  default     = null
  description = <<-EOT
  [Definition of `green_field`](https://learn.microsoft.com/en-us/azure/application-gateway/tutorial-ingress-controller-add-on-new)
  * `name` - (Optional) The name of the Application Gateway to be used or created in the Nodepool Resource Group, which in turn will be integrated with the ingress controller of this Kubernetes Cluster.
  * `subnet_cidr` - (Optional) The subnet CIDR to be used to create an Application Gateway, which in turn will be integrated with the ingress controller of this Kubernetes Cluster.
  * `subnet_id` - (Optional) The ID of the subnet on which to create an Application Gateway, which in turn will be integrated with the ingress controller of this Kubernetes Cluster.
EOT

  validation {
    condition     = var.green_field_application_gateway_for_ingress == null ? true : (can(coalesce(var.green_field_application_gateway_for_ingress.subnet_id, var.green_field_application_gateway_for_ingress.subnet_cidr)))
    error_message = "One of `subnet_cidr` and `subnet_id` must be specified."
  }
}

## Web app routing ingress
variable "web_app_routing" {
  type = object({
    dns_zone_id = string
  })
  default     = null
  description = <<-EOT
  object({
    dns_zone_id = "(Required) Specifies the ID of the DNS Zone in which DNS entries are created for applications deployed to the cluster when Web App Routing is enabled."
  })
EOT
}

variable "identity_ids" {
  type        = list(string)
  default     = []
  description = "(Optional) Specifies a list of User Assigned Managed Identity IDs to be assigned to this Kubernetes Cluster."
}

variable "identity_type" {
  type        = string
  default     = "SystemAssigned"
  description = "(Optional) The type of identity used for the managed cluster. Conflicts with `client_id` and `client_secret`. Possible values are `SystemAssigned` and `UserAssigned`. If `UserAssigned` is set, an `identity_ids` must be set as well."

  validation {
    condition     = var.identity_type == "SystemAssigned" || var.identity_type == "UserAssigned"
    error_message = "`identity_type`'s possible values are `SystemAssigned` and `UserAssigned`"
  }
}

variable "client_id" {
  type        = string
  default     = ""
  description = "(Optional) The Client ID (appId) for the Service Principal used for the AKS deployment"
  nullable    = false
}

variable "client_secret" {
  type        = string
  default     = ""
  description = "(Optional) The Client Secret (password) for the Service Principal used for the AKS deployment"
  nullable    = false
}

variable "monitor_metrics" {
  type = object({
    annotations_allowed = optional(string)
    labels_allowed      = optional(string)
  })
  default     = null
  description = <<-EOT
  (Optional) Specifies a Prometheus add-on profile for the Kubernetes Cluster
  object({
    annotations_allowed = "(Optional) Specifies a comma-separated list of Kubernetes annotation keys that will be used in the resource's labels metric."
    labels_allowed      = "(Optional) Specifies a Comma-separated list of additional Kubernetes label keys that will be used in the resource's labels metric."
  })
EOT
}

## Container Registry related variables
variable "container_registry_ids" {
  description = "List of container registry IDs to associate with AKS. This module will assign role `AcrPull` to AKS for these registries"
  type        = list(string)
  default     = []
}

## Key Vault related variables
variable "kv_soft_delete_retention_days" {
  description = "Number of retention days for soft delete for key vault"
  type        = number
  default     = 7
}

variable "kv_sku" {
  description = "SKU for the key vault - standard or premium"
  type        = string
  default     = "standard"
  validation {
    condition     = (contains(["standard", "premium"], var.kv_sku))
    error_message = "The kv_sku must be either \"standard\" or \"premium\"."
  }
}

variable "kv_access_policies" {
  description = "Additional Access policies for the vault except the current user which are added by default"
  type = map(object({
    object_id               = string
    tenant_id               = string
    key_permissions         = list(string)
    certificate_permissions = list(string)
    secret_permissions      = list(string)
    storage_permissions     = list(string)
  }))

  default = {}
}

# Variables to import pre existing certificates to the key vault
variable "certificates" {
  description = "List of certificates to be imported. The pfx files should be present in the root of the module (path.root) and its name denoted as certificate_name"
  type = map(object({
    certificate_name = string
    password         = string
  }))

  default = {}
}

# Variables to import secrets
variable "secrets" {
  description = "List of secrets (name and value)"
  type        = map(string)
  default     = {}
}

# Variables to import Keys
variable "keys" {
  description = "List of keys to be created in key vault. Name of the key is the key of the map"
  type = map(object({
    key_type = string
    key_size = number
    key_opts = list(string)
  }))
  default = {}
}

variable "disable_bgp_route_propagation" {
  description = "Disable BGP route propagation on the routing table that AKS manages."
  default     = false
  type        = bool
}

## Application Insights

variable "create_application_insights" {
  description = "Ff true, create a new Application Insights resource to be associated with the AKS cluster"
  type        = bool
  default     = false
}

variable "application_insights" {
  description = "Details for the Application Insights resource to be associated with the AKS cluster. Required only when create_application_insights=true"
  type = object({
    application_type                      = optional(string, "web")
    retention_in_days                     = optional(number, 30)
    daily_data_cap_in_gb                  = optional(number, 1)
    daily_data_cap_notifications_disabled = optional(bool, false)
    sampling_percentage                   = optional(number, 100)
    disabling_ip_masking                  = optional(bool, false)
    local_authentication_disabled         = optional(bool, false)
    internet_ingestion_enabled            = optional(bool, false)
    internet_query_enabled                = optional(bool, true)
    force_customer_storage_for_profiler   = optional(bool, false)
  })

  default = {}
}

## Private Link Scope

variable "create_monitor_private_link_scope" {
  description = <<EOF
    If true, create a new Private Link Scope for Azure Monitor.
    NOTE: This will cause all azure monitor / log analytics traffic to go through private link.
  EOF
  type        = bool
  default     = false
}

variable "monitor_private_link_scope_subnet_id" {
  description = "The ID of the subnet to associate with the Azure Monitor private link scope"
  type        = string
  default     = null
}

# https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns#management-and-governance
variable "monitor_private_link_scope_dns_zone_suffixes" {
  description = "The DNS zone suffixes for the private link scope"
  type        = set(string)
  default = [
    "privatelink.monitor.azure.com",
    "privatelink.oms.opinsights.azure.com",
    "privatelink.ods.opinsights.azure.com",
    "privatelink.agentsvc.azure-automation.net",
    "privatelink.blob.core.windows.net"
  ]
}

## Prometheus
variable "enable_prometheus_monitoring" {
  description = "Deploy Prometheus monitoring resources with the AKS cluster"
  type        = bool
  default     = false
}

variable "prometheus_workspace_public_access_enabled" {
  description = "Enable public access to the Azure Monitor workspace for prometheus"
  type        = bool
  default     = true
}

variable "prometheus_monitoring_private_endpoint_subnet_id" {
  description = "The ID of a subnet to create a private endpoint for Prometheus monitoring"
  type        = string
  default     = null
}

variable "prometheus_enable_default_rule_groups" {
  description = "Enable default recording rules for prometheus"
  type        = bool
  default     = true
}

variable "prometheus_default_rule_group_naming" {
  description = "Resource names for the default recording rules"
  type        = map(string)
  default = {
    node_recording       = "DefaultNodeRecordingRuleGroup"
    kubernetes_recording = "DefaultKubernetesRecordingRuleGroup"
  }
}

variable "prometheus_default_rule_group_interval" {
  description = "Interval to run default recording rules in ISO 8601 format (between PT1M and PT15M)"
  type        = string
  default     = "PT1M"
}

variable "prometheus_rule_groups" {
  description = <<-EOF
    map(object({
      enabled     = Whether or not the rule group is enabled
      description = Description of the rule group
      interval    = Interval to run the rule group in ISO 8601 format (between PT1M and PT15M)

      recording_rules = list(object({
        name       = Name of the recording rule
        enabled    = Whether or not the recording rule is enabled
        expression = PromQL expression for the time series value
        labels     = Labels to add to the time series
      }))

      alert_rules = list(object({
        name = Name of the alerting rule
        action = optional(object({
          action_group_id = ID of the action group to send alerts to
        }))
        enabled    = Whether or not the alert rule is enabled
        expression = PromQL expression to evaluate
        for        = Amount of time the alert must be active before firing, represented in ISO 8601 duration format (i.e. PT5M)
        labels     = Labels to add to the alerts fired by this rule
        alert_resolution = optional(object({
          auto_resolved   = Whether or not to auto-resolve the alert after the condition is no longer true
          time_to_resolve = Amount of time to wait before auto-resolving the alert, represented in ISO 8601 duration format (i.e. PT5M)
        }))
        severity    = Severity of the alert, between 0 and 4
        annotations = Annotations to add to the alerts fired by this rule
      }))
  EOF
  type = map(object({
    enabled     = bool
    description = string
    interval    = string

    recording_rules = list(object({
      name       = string
      enabled    = bool
      expression = string
      labels     = map(string)
    }))

    alert_rules = list(object({
      name = string
      action = optional(object({
        action_group_id = string
      }))
      enabled    = bool
      expression = string
      for        = string
      labels     = map(string)
      alert_resolution = optional(object({
        auto_resolved   = optional(bool)
        time_to_resolve = optional(string)
      }))
      severity    = optional(number)
      annotations = optional(map(string))
    }))

    tags = optional(map(string), {})
  }))
  default = {}
}

variable "tags" {
  description = "A map of custom tags to be attached to this module resources"
  type        = map(string)
  default     = {}
}
