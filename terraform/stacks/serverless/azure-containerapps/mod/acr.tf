resource "azurerm_container_registry" "acr" {
  name                = replace("${var.deployment_name}acr", "-", "")
  location            = local.location
  resource_group_name = local.resource_group_name
  sku                 = "Standard"
  # Admin credentials are only needed when the container apps authenticate to
  # ACR with a username/password instead of the managed identity.
  admin_enabled = !var.use_managed_identity
  tags          = var.tags
}

locals {
  acr_images = {
    backend  = "noxusai/noxus-backend:${var.vm_version}"
    frontend = "noxusai/noxus-frontend:${var.vm_version}"
    worker   = "noxusai/noxus-worker:${var.vm_version}"
    relay    = "noxusai/noxus-relays:${var.vm_version}"
  }
}

# Container Apps cannot pull from Docker Hub with a rate limit low enough to
# survive a scale-out, so every image is mirrored into ACR first. Replacing this
# resource (which a vm_version change does) re-runs the import.
resource "terraform_data" "acr_import" {
  for_each = local.acr_images

  input = each.value

  provisioner "local-exec" {
    environment = {
      DOCKER_HUB_USERNAME = var.docker_hub_username
      DOCKER_HUB_TOKEN    = var.docker_hub_token
    }
    command = <<-EOT
      set -euo pipefail
      echo "Importing ${each.value} into ${azurerm_container_registry.acr.name}..."
      az acr import \
        --name ${azurerm_container_registry.acr.name} \
        --source docker.io/${each.value} \
        --image ${each.value} \
        --username "$DOCKER_HUB_USERNAME" \
        --password "$DOCKER_HUB_TOKEN" \
        --only-show-errors \
        --force
      echo "Imported ${each.value}"
    EOT
  }
}
