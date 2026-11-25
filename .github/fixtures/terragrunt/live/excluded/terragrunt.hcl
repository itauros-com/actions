# Left out by the caller's filter (!./excluded): its module does not exist, so a run that
# reached it would fail.
include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../modules//missing"
}
