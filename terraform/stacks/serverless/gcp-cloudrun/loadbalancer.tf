# External HTTPS load balancer in front of the frontend, created when `domain`
# is set. The frontend's ingress then accepts the load balancer only, so its
# run.app URL stops answering from the internet. One hostname is enough: the
# frontend proxies the API and the webhook receivers under its own paths.

resource "google_compute_global_address" "ingress" {
  count = local.use_load_balancer ? 1 : 0

  name = "${local.prefix}-ingress"

  depends_on = [google_project_service.enabled]
}

resource "google_compute_managed_ssl_certificate" "main" {
  count = local.use_load_balancer ? 1 : 0

  name = "${local.prefix}-cert"

  managed {
    domains = [var.domain]
  }

  depends_on = [google_project_service.enabled]
}

resource "google_compute_ssl_policy" "main" {
  count = local.use_load_balancer ? 1 : 0

  name            = "${local.prefix}-tls"
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"

  depends_on = [google_project_service.enabled]
}

resource "google_compute_region_network_endpoint_group" "frontend" {
  count = local.use_load_balancer ? 1 : 0

  name                  = "${local.prefix}-frontend"
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.frontend.name
  }
}

resource "google_compute_backend_service" "frontend" {
  count = local.use_load_balancer ? 1 : 0

  name                  = "${local.prefix}-frontend"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTPS"

  backend {
    group = google_compute_region_network_endpoint_group.frontend[0].id
  }

  log_config {
    enable      = true
    sample_rate = 1
  }
}

resource "google_compute_url_map" "https" {
  count = local.use_load_balancer ? 1 : 0

  name            = "${local.prefix}-https"
  default_service = google_compute_backend_service.frontend[0].id
}

resource "google_compute_target_https_proxy" "main" {
  count = local.use_load_balancer ? 1 : 0

  name             = "${local.prefix}-https"
  url_map          = google_compute_url_map.https[0].id
  ssl_certificates = [google_compute_managed_ssl_certificate.main[0].id]
  ssl_policy       = google_compute_ssl_policy.main[0].id
}

resource "google_compute_global_forwarding_rule" "https" {
  count = local.use_load_balancer ? 1 : 0

  name                  = "${local.prefix}-https"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_protocol           = "TCP"
  port_range            = "443"
  ip_address            = google_compute_global_address.ingress[0].id
  target                = google_compute_target_https_proxy.main[0].id
}

# Port 80 only redirects to HTTPS.
resource "google_compute_url_map" "http_redirect" {
  count = local.use_load_balancer ? 1 : 0

  name = "${local.prefix}-http-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "redirect" {
  count = local.use_load_balancer ? 1 : 0

  name    = "${local.prefix}-http-redirect"
  url_map = google_compute_url_map.http_redirect[0].id
}

resource "google_compute_global_forwarding_rule" "http" {
  count = local.use_load_balancer ? 1 : 0

  name                  = "${local.prefix}-http"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_protocol           = "TCP"
  port_range            = "80"
  ip_address            = google_compute_global_address.ingress[0].id
  target                = google_compute_target_http_proxy.redirect[0].id
}

resource "google_dns_record_set" "ingress" {
  count = local.use_load_balancer && var.dns_managed_zone != "" ? 1 : 0

  name         = "${var.domain}."
  managed_zone = var.dns_managed_zone
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.ingress[0].address]

  depends_on = [google_project_service.enabled]
}
