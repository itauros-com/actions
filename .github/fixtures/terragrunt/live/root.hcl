# The fixture's root configuration: each unit's state on local disk, next to it. Its only
# resource is OpenTofu's built-in terraform_data: no provider, no cloud, no credentials.
remote_state {
  backend = "local"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    path = "${get_terragrunt_dir()}/terraform.tfstate"
  }
}
