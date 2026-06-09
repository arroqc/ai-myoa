data "aws_availability_zones" "available" {
  state = "available"
}

data "archive_file" "generate_image" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/generate_image"
  output_path = "${path.module}/../lambdas/generate_image.zip"
}

data "archive_file" "generate_text" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/generate_text"
  output_path = "${path.module}/../lambdas/generate_text.zip"
}
