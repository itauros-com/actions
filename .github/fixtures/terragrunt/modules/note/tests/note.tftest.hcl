variables {
  text = "hello"
}

run "keeps_the_text" {
  command = plan

  assert {
    condition     = terraform_data.note.input == "hello"
    error_message = "The note does not keep its input."
  }
}
