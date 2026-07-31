output "cluster_name" {
  description = "Cluster name."
  value       = azurerm_kubernetes_cluster.this.name
}

output "cluster_id" {
  description = "Resource ID of the cluster."
  value       = azurerm_kubernetes_cluster.this.id
}

output "host" {
  description = "Kubernetes API endpoint."
  value       = azurerm_kubernetes_cluster.this.kube_config[0].host
  sensitive   = true
}

output "client_certificate" {
  description = "Client certificate from the admin kubeconfig."
  value       = azurerm_kubernetes_cluster.this.kube_config[0].client_certificate
  sensitive   = true
}

output "client_key" {
  description = "Client key from the admin kubeconfig."
  value       = azurerm_kubernetes_cluster.this.kube_config[0].client_key
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Cluster CA bundle."
  value       = azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate
  sensitive   = true
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL, used as the issuer in federated identity credentials."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "kubelet_identity_object_id" {
  description = "Object ID of the kubelet identity, for granting ACR pull or other node-level access."
  value       = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

output "platform_identity_client_id" {
  description = "Client ID of the platform workload identity, or empty when not created."
  value       = var.create_workload_identity ? azurerm_user_assigned_identity.platform[0].client_id : ""
}

output "helm_service_account_annotation" {
  description = "Set as serviceAccount.annotations in the noxus-platform values so pods can exchange their token for Azure credentials."
  value = var.create_workload_identity ? {
    "azure.workload.identity/client-id" = azurerm_user_assigned_identity.platform[0].client_id
  } : {}
}
