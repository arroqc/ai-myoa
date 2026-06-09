# ── generate_image ────────────────────────────────────────────────────────────

resource "aws_iam_role" "generate_image" {
  name = "ai-myoa-generate-image-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "generate_image_basic_execution" {
  role       = aws_iam_role.generate_image.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "generate_image_vpc_access" {
  role       = aws_iam_role.generate_image.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "generate_image" {
  name = "ai-myoa-generate-image-policy-${var.environment}"
  role = aws_iam_role.generate_image.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Bedrock"
        Effect = "Allow"
        Action = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:*::foundation-model/amazon.titan-image-generator-v1"
      },
      {
        Sid    = "S3Images"
        Effect = "Allow"
        Action = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.images.arn}/*"
      }
    ]
  })
}

resource "aws_lambda_function" "generate_image" {
  function_name    = "ai-myoa-generate-image-${var.environment}"
  role             = aws_iam_role.generate_image.arn
  runtime          = "python3.11"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.generate_image.output_path
  source_code_hash = data.archive_file.generate_image.output_md5
  timeout          = 60

  environment {
    variables = {
      IMAGES_BUCKET = aws_s3_bucket.images.bucket
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.private.id]
    security_group_ids = [aws_security_group.lambda.id]
  }
}

# ── generate_text ─────────────────────────────────────────────────────────────

resource "aws_iam_role" "generate_text" {
  name = "ai-myoa-generate-text-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "generate_text_basic_execution" {
  role       = aws_iam_role.generate_text.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "generate_text_vpc_access" {
  role       = aws_iam_role.generate_text.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "generate_text" {
  name = "ai-myoa-generate-text-policy-${var.environment}"
  role = aws_iam_role.generate_text.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "Bedrock"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:*::foundation-model/meta.llama3-70b-instruct-v1:0"
      }
    ]
  })
}

resource "aws_lambda_function" "generate_text" {
  function_name    = "ai-myoa-generate-text-${var.environment}"
  role             = aws_iam_role.generate_text.arn
  runtime          = "python3.11"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.generate_text.output_path
  source_code_hash = data.archive_file.generate_text.output_md5
  timeout          = 60

  vpc_config {
    subnet_ids         = [aws_subnet.private.id]
    security_group_ids = [aws_security_group.lambda.id]
  }
}
