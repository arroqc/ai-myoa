resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name = "ai-myoa-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "ai-myoa-public-subnet"
    Type = "Public"
  }
}

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name = "ai-myoa-private-subnet"
    Type = "Private"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "ai-myoa-private-rt"
    Type = "Private"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Security group for Lambda functions
resource "aws_security_group" "lambda" {
  name        = "ai-myoa-lambda-sg"
  description = "Security group for Lambda functions in private subnet"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ai-myoa-lambda-sg"
  }
}

# Security group for Bedrock VPC endpoint
resource "aws_security_group" "bedrock_endpoint" {
  name        = "ai-myoa-bedrock-endpoint-sg"
  description = "Security group for Bedrock interface endpoint"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ai-myoa-bedrock-endpoint-sg"
  }
}

# Gateway endpoint for S3 (free, no security group needed)
resource "aws_vpc_endpoint" "s3" {
  vpc_id          = aws_vpc.main.id
  service_name    = "com.amazonaws.${var.aws_region}.s3"
  route_table_ids = [aws_route_table.private.id]

  tags = {
    Name = "ai-myoa-s3-endpoint"
  }
}

# Interface endpoint for Bedrock runtime
resource "aws_vpc_endpoint" "bedrock" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.bedrock-runtime"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private.id]
  security_group_ids  = [aws_security_group.bedrock_endpoint.id]
  private_dns_enabled = true

  tags = {
    Name = "ai-myoa-bedrock-endpoint"
  }
}
