terraform {
  required_version = ">= 1.3"
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

# A trivially valid resource so `terraform validate` and the hooks have
# something real to chew on without needing cloud credentials.
resource "random_pet" "this" {
  length    = var.name_length
  separator = "-"
}
