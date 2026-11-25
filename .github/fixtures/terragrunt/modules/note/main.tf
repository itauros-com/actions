# A value kept in the state: OpenTofu's built-in terraform_data, so no provider.
variable "text" {
  description = "The value to keep."
  type        = string
}

resource "terraform_data" "note" {
  input = var.text
}

output "text" {
  description = "The value kept."
  value       = terraform_data.note.output
}
