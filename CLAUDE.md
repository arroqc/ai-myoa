# ai-myoa — Make Your Own Adventure with AI

A serverless MYOA game using AWS Bedrock (Llama 3 for text, Titan Image Generator for images) with a React frontend.

## Project Structure

```
ai-myoa/
├── terraform/          # All infrastructure (single flat directory, no modules)
│   ├── providers.tf    # AWS provider + version lock
│   ├── variables.tf    # All input variables
│   ├── data.tf         # Data sources + archive_file packaging
│   ├── network.tf      # VPC, subnets, security groups, VPC endpoints
│   ├── storage.tf      # S3 buckets + DynamoDB table
│   ├── lambdas.tf      # IAM roles/policies + Lambda functions + layers
│   └── api.tf          # API Gateway, Lambda permissions, outputs
├── lambdas/            # Lambda function source code
│   └── <function>/     # One directory per function
└── frontend/           # React + Vite app (built output deploys to S3)
```

## Terraform Conventions

### Provider & Versioning
- AWS provider pinned to an exact version (currently `6.39.0`)
- Region and environment driven by variables, never hardcoded
- All resources get `default_tags` via the provider block:

```hcl
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = var.environment
      Project     = "ai-myoa"
      ManagedBy   = "terraform"
    }
  }
}
```

### File Layout Rules
- `providers.tf` — only `terraform {}` block and `provider` blocks
- `variables.tf` — all variables with description, type, and default
- `data.tf` — all `data` sources (availability zones, archive_file packaging, etc.)
- `network.tf` — VPC, subnets, route tables, security groups, VPC endpoints
- `storage.tf` — S3 buckets and all their sub-resources (policies, encryption, CORS, public access blocks), DynamoDB tables
- `lambdas.tf` — IAM roles, IAM policies (inline with `jsonencode`), Lambda functions, Lambda layers
- `api.tf` — API Gateway resources, Lambda invoke permissions, `local_file` template rendering, `aws_s3_object` website uploads, all `output` blocks

### Naming
- Resource names use the project prefix: `ai-myoa-<purpose>` (e.g., `ai-myoa-images`, `ai-myoa-sessions`)
- Terraform resource identifiers mirror the AWS name using underscores (e.g., `aws_s3_bucket.ai_myoa_images`)

### S3 Buckets
Every S3 bucket gets all four companion resources — no exceptions:
1. `aws_s3_bucket_public_access_block` — private buckets block everything; website bucket opens ACLs/policy
2. `aws_s3_bucket_server_side_encryption_configuration` — always AES256
3. `aws_s3_bucket_policy` — least-privilege; grant only the principals that need access
4. CORS config only where browser-direct access is required

### Lambda
- Runtime: `python3.11`
- IAM role uses `assume_role_policy` with `jsonencode`; attach `AWSLambdaBasicExecutionRole` managed policy
- Custom permissions (Bedrock, S3, DynamoDB) go in a single inline `aws_iam_role_policy` using `jsonencode` — one policy per Lambda role, listing all required actions
- Dependencies packaged as a `aws_lambda_layer_version`; source zip built outside Terraform (Makefile/Dockerfile in `lambda_layer/`)
- Lambda code zipped via `data.archive_file` in `data.tf` with `source_dir` pointing to the function directory
- `source_code_hash = data.archive_file.<name>.output_md5` on every function for automatic redeploy on code change
- Lambda placed in private subnet with a security group allowing only egress on 443

### Networking
- VPC with one public subnet and one private subnet (single AZ is fine for dev)
- Lambda runs in the private subnet
- S3 accessed via a Gateway VPC endpoint (free, no security group needed)
- Bedrock accessed via an Interface VPC endpoint (`bedrock-runtime`) with `private_dns_enabled = true`
- Security groups: Lambda SG (egress 443 only) → Bedrock endpoint SG (ingress from Lambda SG on 443)

### API Gateway
- Use HTTP API (`protocol_type = "HTTP"`) — not REST API
- CORS configured on the API resource itself (not at the route level)
- Single `$default` stage with `auto_deploy = true`
- One integration per Lambda (`AWS_PROXY`, `payload_format_version = "2.0"`)
- `aws_lambda_permission` with `source_arn = "${api.execution_arn}/*/*"` for each function

### Frontend Deployment
- React app built with Vite; output is plain static files
- API endpoint injected at deploy time using `templatefile()` + `local_file` → `aws_s3_object`
- Website bucket: public access unblocked, public `GetObject` bucket policy, S3 website configuration enabled
- Note: S3 website endpoint is HTTP only; add CloudFront for HTTPS in production

### Outputs
All outputs live in `api.tf`:
- `api_gateway_endpoint` — invoke URL
- `website_url` — S3 website endpoint
- Any bucket names the frontend or CI needs

## Bedrock Models

| Purpose | Model ID |
|---|---|
| Text / narrative | `meta.llama3-...` (confirm exact ID from Bedrock console) |
| Image generation | `amazon.titan-image-generator-v1` |

Lambda IAM policy must allow `bedrock:InvokeModel` on these model ARNs: `arn:aws:bedrock:*::foundation-model/<model-id>`.

## Game API

| Method | Path | Lambda | Description |
|---|---|---|---|
| POST | `/game/start` | `start_game` | Create session, generate opening scene + image |
| POST | `/game/turn` | `game_turn` | Accept choice, generate next scene + image |
| GET | `/game/session/{id}` | `get_session` | Fetch current session state |

## DynamoDB Session Schema

Table name: `ai-myoa-sessions`
- Partition key: `session_id` (String)
- Attributes: `story_history` (List), `current_scene` (Map), `metadata` (Map — genre, protagonist, tone)
- TTL attribute: `expires_at` (sessions expire after 24h)

## Development Workflow

1. Edit Lambda code in `lambdas/<function>/handler.py`
2. If dependencies changed, rebuild the layer: `cd lambda_layer && make`
3. `cd terraform && terraform plan` — review changes
4. `cd terraform && terraform apply`
5. Build and deploy frontend: `cd frontend && npm run build` then upload to S3
