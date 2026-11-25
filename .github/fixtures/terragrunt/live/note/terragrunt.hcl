# Planned on the pull request, applied at its merge.
include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../modules//note"
}

inputs = {
  text = "planned on the pull request, applied at its merge"
}
