output "release_name" {
  description = "Helm release name."
  value       = helm_release.noxus.name
}

output "namespace" {
  description = "Namespace the platform was installed into."
  value       = var.namespace
}

output "frontend_url" {
  description = "Public URL of the web app."
  value       = local.urls.FRONTEND_URL
}

output "backend_url" {
  description = "Public URL of the API. The MCP server is served from <frontend_url>/mcp."
  value       = local.urls.BACKEND_URL
}

output "relay_url" {
  description = "Public URL of the relay. Only reachable when relay.enabled is set through extra_values."
  value       = local.urls.RELAY_URL
}

output "auth0_session_secret" {
  description = "Session secret in use. Generated when auth0.session_secret was null — capture it if you ever need to reproduce the release outside terraform."
  value       = local.base_secrets.AUTH0_SECRET
  sensitive   = true
}

output "computed_values" {
  description = "The values document this module renders, before extra_values are layered on. Useful for debugging a release that did not come out as expected."
  value       = local.computed_values
  sensitive   = true
}
