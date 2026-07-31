terraform {
  required_version = ">= 1.5.7"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.11.2"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~>4"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
    }
  }
}
