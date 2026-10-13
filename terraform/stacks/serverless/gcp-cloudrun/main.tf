data "google_project" "this" {
  project_id = var.project_id
}

resource "random_id" "suffix" {
  byte_length = 3
}

locals {
  prefix = var.name_prefix
  labels = merge({ app = "noxus", deployment = var.name_prefix }, var.labels)

  use_load_balancer = var.domain != ""
  create_network    = var.network == ""
  create_registry   = var.image_registry == ""

  network_id    = local.create_network ? google_compute_network.main[0].id : var.network
  subnetwork_id = local.create_network ? google_compute_subnetwork.main[0].id : var.subnetwork

  services = {
    backend  = "${local.prefix}-backend"
    frontend = "${local.prefix}-frontend"
    worker   = "${local.prefix}-worker"
    relay    = "${local.prefix}-relay"
    sandbox  = "${local.prefix}-sandbox"
  }

  # Cloud Run's deterministic URLs. Computing them instead of reading `.uri`
  # lets services reference each other, including themselves, without a cycle.
  internal_url = {
    for key, name in local.services :
    key => "https://${name}-${data.google_project.this.number}.${var.region}.run.app"
  }

  public_url = local.use_load_balancer ? "https://${var.domain}" : local.internal_url.frontend

  # The browser only ever talks to the frontend. It proxies /api/backend/* to
  # the backend and /api/relay/* to the relay, so one hostname serves the app,
  # the API and inbound webhooks.
  backend_public_url = "${local.public_url}/api/backend"
  relay_public_url   = "${local.public_url}/api/relay"

  image_prefix = (
    local.create_registry
    ? "${var.region}-docker.pkg.dev/${var.project_id}/${local.prefix}-images/noxusai"
    : trimsuffix(var.image_registry, "/")
  )

  sandbox_network_tag = "${local.prefix}-sandbox"
}
