# Create VPC
resource "aws_vpc" "zodh_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "zodh-vpc"
  }
}

# Create Security Group
resource "aws_security_group" "vpc_sg" {
  name        = "SG-${var.project_name}"
  description = "Security group for EKS node group"
  vpc_id      = aws_vpc.zodh_vpc.id

  ingress {
    from_port = 8080
    to_port   = 8080
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 587
    to_port     = 587
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  depends_on = [
    aws_vpc.zodh_vpc
  ]
}

# Cognito Configuration

resource "aws_cognito_user_pool" "zodh_video_user_pool" {
  name              = "zodh_video_user_pool"
  mfa_configuration = "OFF"

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  account_recovery_setting {

    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  username_attributes = ["email"]
  auto_verified_attributes = ["email"]

  schema {
    name                = "given_name"
    attribute_data_type = "String"
    required            = true
    mutable             = true
  }

  schema {
    name                = "family_name"
    attribute_data_type = "String"
    required            = true
    mutable             = true
  }

  password_policy {
    minimum_length    = 8
    require_lowercase = false
    require_numbers   = false
    require_symbols   = false
    require_uppercase = false
  }

}

resource "aws_cognito_user_pool_client" "zodh_video_user_pool_client" {
  name         = "zodh_video_user_client"
  user_pool_id = aws_cognito_user_pool.zodh_video_user_pool.id

  explicit_auth_flows = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]

  token_validity_units {
    access_token  = "hours"
    refresh_token = "hours"
  }
  access_token_validity  = 2
  refresh_token_validity = 48

  depends_on = [
    aws_cognito_user_pool.zodh_video_user_pool
  ]
}

# API Gateway && Lambda Configuration

## Lambda Configuration

resource "aws_lambda_function" "zodh_authorizer_sign_up" {
  function_name = "zodh-authorizer-sign-up"
  filename      = "zodh-authorizer.zip"
  handler       = "index.signUp"
  runtime       = "nodejs20.x"
  architectures = ["arm64"]
  role          = data.aws_iam_role.labrole.arn
  environment {
    variables = {
      "COGNITO_CLIENT_ID" = aws_cognito_user_pool_client.zodh_video_user_pool_client.id
    }
  }

  depends_on = [
    aws_cognito_user_pool.zodh_video_user_pool
  ]
}

resource "aws_lambda_function" "zodh_authorizer_confirmer" {
  function_name = "zodh-authorizer-confirmer"
  filename      = "zodh-authorizer.zip"
  handler       = "index.confirm"
  runtime       = "nodejs20.x"
  architectures = ["arm64"]
  role          = data.aws_iam_role.labrole.arn
  environment {
    variables = {
      "COGNITO_CLIENT_ID" = aws_cognito_user_pool_client.zodh_video_user_pool_client.id
    }
  }

  depends_on = [
    aws_cognito_user_pool.zodh_video_user_pool
  ]
}

resource "aws_lambda_function" "zodh_authorizer_sign_in" {
  function_name = "zodh-authorizer-sign-in"
  filename      = "zodh-authorizer.zip"
  handler       = "index.signIn"
  runtime       = "nodejs20.x"
  architectures = ["arm64"]
  role          = data.aws_iam_role.labrole.arn
  environment {
    variables = {
      "COGNITO_CLIENT_ID" = aws_cognito_user_pool_client.zodh_video_user_pool_client.id
    }
  }

  depends_on = [
    aws_cognito_user_pool.zodh_video_user_pool
  ]
}

resource "aws_lambda_function" "zodh_authorizer_profiler" {
  function_name = "zodh-authorizer-profiler"
  filename      = "zodh-authorizer.zip"
  handler       = "index.getProfile"
  runtime       = "nodejs20.x"
  architectures = ["arm64"]
  ## In a production environment, it is very probably that the user must have a role with the right actions allowed.
  ## To this lambda, user must have cognito-idp:AdminGetUser
  role          = data.aws_iam_role.labrole.arn

  vpc_config {
    security_group_ids = [aws_security_group.vpc_sg.id]
    subnet_ids = [aws_subnet.zodh_sub_1.id, aws_subnet.zodh_sub_2.id]
  }

  environment {
    variables = {
      "USER_POOL_ID" = aws_cognito_user_pool.zodh_video_user_pool.id
    }
  }

  depends_on = [
    aws_security_group.vpc_sg,
    aws_subnet.zodh_sub_1,
    aws_subnet.zodh_sub_2,
    aws_cognito_user_pool.zodh_video_user_pool
  ]
}

## API Gateway Configuration

resource "aws_apigatewayv2_api" "auth_api" {
  name          = "auth-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.auth_api.id
  name        = "$default"
  auto_deploy = true

  depends_on = [
    aws_apigatewayv2_api.auth_api
  ]
}

## Route Configuration

resource "aws_apigatewayv2_route" "sign_up_route" {
  api_id    = aws_apigatewayv2_api.auth_api.id
  route_key = "POST /auth/sign-up"
  target    = "integrations/${aws_apigatewayv2_integration.sign_up_lambda_integration.id}"

  depends_on = [
    aws_apigatewayv2_integration.sign_up_lambda_integration
  ]
}

resource "aws_apigatewayv2_route" "confirm_route" {
  api_id    = aws_apigatewayv2_api.auth_api.id
  route_key = "POST /auth/confirm"
  target    = "integrations/${aws_apigatewayv2_integration.confirmer_lambda_integration.id}"

  depends_on = [
    aws_apigatewayv2_integration.confirmer_lambda_integration
  ]
}

resource "aws_apigatewayv2_route" "sign_in_route" {
  api_id    = aws_apigatewayv2_api.auth_api.id
  route_key = "POST /auth/sign-in"
  target    = "integrations/${aws_apigatewayv2_integration.sign_in_lambda_integration.id}"

  depends_on = [
    aws_apigatewayv2_integration.sign_in_lambda_integration
  ]
}

resource "aws_apigatewayv2_route" "get_profile_route" {
  api_id             = aws_apigatewayv2_api.auth_api.id
  route_key          = "GET /profile"
  target = "integrations/${aws_apigatewayv2_integration.profiler_lambda_integration.id}"
  ### The profile must be protected
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.zodh_default_authorizer.id

  depends_on = [
    aws_apigatewayv2_integration.profiler_lambda_integration,
    aws_apigatewayv2_authorizer.zodh_default_authorizer
  ]
}

## API Gateway & Lambda Integration

resource "aws_apigatewayv2_integration" "sign_up_lambda_integration" {
  api_id           = aws_apigatewayv2_api.auth_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.zodh_authorizer_sign_up.invoke_arn

  depends_on = [
    aws_apigatewayv2_api.auth_api,
    aws_lambda_function.zodh_authorizer_sign_up
  ]
}

resource "aws_apigatewayv2_integration" "confirmer_lambda_integration" {
  api_id           = aws_apigatewayv2_api.auth_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.zodh_authorizer_confirmer.invoke_arn

  depends_on = [
    aws_apigatewayv2_api.auth_api,
    aws_lambda_function.zodh_authorizer_confirmer
  ]
}

resource "aws_apigatewayv2_integration" "sign_in_lambda_integration" {
  api_id           = aws_apigatewayv2_api.auth_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.zodh_authorizer_sign_in.invoke_arn

  depends_on = [
    aws_apigatewayv2_api.auth_api,
    aws_lambda_function.zodh_authorizer_sign_in
  ]
}

resource "aws_apigatewayv2_integration" "profiler_lambda_integration" {
  api_id           = aws_apigatewayv2_api.auth_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.zodh_authorizer_profiler.invoke_arn

  depends_on = [
    aws_apigatewayv2_api.auth_api,
    aws_lambda_function.zodh_authorizer_profiler
  ]
}

## Allowing API Gateway to Invoke Lambda

resource "aws_lambda_permission" "signup_apigateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.zodh_authorizer_sign_up.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.auth_api.execution_arn}/*/*"

  depends_on = [
    aws_apigatewayv2_api.auth_api,
    aws_lambda_function.zodh_authorizer_sign_up
  ]
}

resource "aws_lambda_permission" "confirmer_apigateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.zodh_authorizer_confirmer.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.auth_api.execution_arn}/*/*"

  depends_on = [
    aws_apigatewayv2_api.auth_api,
    aws_lambda_function.zodh_authorizer_confirmer
  ]
}

resource "aws_lambda_permission" "signin_apigateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.zodh_authorizer_sign_in.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.auth_api.execution_arn}/*/*"

  depends_on = [
    aws_apigatewayv2_api.auth_api,
    aws_lambda_function.zodh_authorizer_sign_in
  ]
}

resource "aws_lambda_permission" "profile_apigateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.zodh_authorizer_profiler.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.auth_api.execution_arn}/*/*"

  depends_on = [
    aws_apigatewayv2_api.auth_api,
    aws_lambda_function.zodh_authorizer_profiler
  ]
}

## API Gateway Authorizer

resource "aws_apigatewayv2_authorizer" "zodh_default_authorizer" {
  api_id          = aws_apigatewayv2_api.auth_api.id
  name            = "zodh-default-authorizer"
  authorizer_type = "JWT"
  identity_sources = ["$request.header.Authorization"]
  jwt_configuration {
    audience = [aws_cognito_user_pool_client.zodh_video_user_pool_client.id]
    issuer = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.zodh_video_user_pool.id}"
  }

  depends_on = [
    aws_apigatewayv2_api.auth_api,
    aws_cognito_user_pool.zodh_video_user_pool,
    aws_cognito_user_pool_client.zodh_video_user_pool_client
  ]
}

# S3 & SNS and SQS Configuration

## Bucket Configuration

resource "aws_s3_bucket" "zodh_video_files" {
  bucket = var.video_bucket_name
}

resource "aws_s3_bucket_notification" "zodh_video_files_notification" {
  bucket = aws_s3_bucket.zodh_video_files.id

  topic {
    topic_arn = aws_sns_topic.pending_video_topic.arn
    events = ["s3:ObjectCreated:Put"]
  }

  depends_on = [
    aws_sns_topic.pending_video_topic,
    aws_s3_bucket.zodh_video_files
  ]
}

resource "aws_s3_bucket" "zodh_lambda_bucket" {
  bucket = var.lambda_bucket_name
}

resource "aws_s3_bucket" "zodh_processed_images_bucket" {
  bucket = var.processed_images_bucket_name
}

resource "aws_s3_bucket_ownership_controls" "zodh_processed_images_bucket_ownership" {
  bucket = aws_s3_bucket.zodh_processed_images_bucket.id
  rule {
    ## Means that all bucket objects are of the owner of the bucket.
    object_ownership = "BucketOwnerPreferred"
  }

  depends_on = [
    aws_s3_bucket.zodh_processed_images_bucket
  ]
}

resource "aws_s3_bucket_public_access_block" "zodh_processed_images_bucket_public_access_block" {
  bucket = aws_s3_bucket.zodh_processed_images_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

  depends_on = [
    aws_s3_bucket.zodh_processed_images_bucket
  ]
}

resource "aws_s3_bucket_acl" "zodh_processed_images_bucket_public_acl" {
  bucket = aws_s3_bucket.zodh_processed_images_bucket.id
  acl    = "public-read"

  depends_on = [
    aws_s3_bucket.zodh_processed_images_bucket,
    aws_s3_bucket_ownership_controls.zodh_processed_images_bucket_ownership,
    aws_s3_bucket_public_access_block.zodh_processed_images_bucket_public_access_block,
  ]
}

## SNS Configuration

resource "aws_sns_topic" "pending_video_topic" {
  name = var.pending_video_topic_name
}

resource "aws_sns_topic_policy" "pending_video_topic_policy" {
  arn = aws_sns_topic.pending_video_topic.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.pending_video_topic.arn
      }
    ]
  })

  depends_on = [
    aws_sns_topic.pending_video_topic
  ]
}

## Queue Configuration

resource "aws_sqs_queue" "video_status_update_queue" {
  name = var.video_status_update_queue_name
}

resource "aws_sqs_queue_policy" "video_status_update_queue_policy" {
  queue_url = aws_sqs_queue.video_status_update_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Principal = { Service = "sns.amazonaws.com" }
        Action   = "SQS:SendMessage"
        Resource = aws_sqs_queue.video_status_update_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.pending_video_topic.arn
          }
        }
      }
    ]
  })

  depends_on = [
    aws_sns_topic.pending_video_topic,
    aws_sqs_queue.video_status_update_queue
  ]
}

resource "aws_sns_topic_subscription" "zodh_video_processor_subscriber" {
  topic_arn = aws_sns_topic.pending_video_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.video_status_update_queue.arn

  depends_on = [
    aws_sns_topic.pending_video_topic,
    aws_sqs_queue.video_status_update_queue
  ]
}

resource "aws_sqs_queue" "video_awaiting_processing_queue" {
  name = var.video_awaiting_processing_queue_name
}

resource "aws_sqs_queue_policy" "video_awaiting_processing_queue_policy" {
  queue_url = aws_sqs_queue.video_awaiting_processing_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Principal = { Service = "sns.amazonaws.com" }
        Action   = "SQS:SendMessage"
        Resource = aws_sqs_queue.video_awaiting_processing_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.pending_video_topic.arn
          }
        }
      }
    ]
  })

  depends_on = [
    aws_sns_topic.pending_video_topic,
    aws_sqs_queue.video_awaiting_processing_queue
  ]
}

resource "aws_sns_topic_subscription" "zodh_video_processor_awaiting_processing_subscriber" {
  topic_arn = aws_sns_topic.pending_video_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.video_awaiting_processing_queue.arn

  depends_on = [
    aws_sns_topic.pending_video_topic,
    aws_sqs_queue.video_awaiting_processing_queue
  ]
}

# Secret Manager Configuration

resource "random_string" "db_user" {
  length  = 10
  special = false
}

resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%^&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "zodh_db_user" {
  name = "zodh-db-user-secret6"
}

resource "aws_secretsmanager_secret_version" "db_user_value" {
  secret_id = aws_secretsmanager_secret.zodh_db_user.id
  secret_string = jsonencode({ "username" = random_string.db_user.result })

  depends_on = [
    aws_secretsmanager_secret.zodh_db_user,
    random_string.db_user
  ]
}

resource "aws_secretsmanager_secret" "zodh_db_password" {
  name = "zodh-db-password-secret6"
}

resource "aws_secretsmanager_secret_version" "db_password_value" {
  secret_id = aws_secretsmanager_secret.zodh_db_password.id
  secret_string = jsonencode({ "password" = random_password.db_password.result })

  depends_on = [
    aws_secretsmanager_secret.zodh_db_password,
    random_password.db_password
  ]
}

# RDS Configuration

resource "aws_db_instance" "zodh_video_database" {
  identifier          = "zodh-video-database"
  engine              = "postgres"
  instance_class      = "db.t3.micro"
  allocated_storage   = 10
  db_name             = "postgres"
  username            = random_string.db_user.result
  password            = random_password.db_password.result
  publicly_accessible = true
  skip_final_snapshot = true
  vpc_security_group_ids = [aws_security_group.video_db_sg.id]
  tags = {
    Name = "postgre-instance"
  }

  depends_on = [
    aws_security_group.video_db_sg,
    aws_secretsmanager_secret_version.db_user_value,
    aws_secretsmanager_secret_version.db_password_value
  ]
}

resource "aws_security_group" "video_db_sg" {
  name = "rds-public-sg"

  ingress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Kubernetes secret configuration

resource "kubernetes_secret" "zodh_secret" {
  metadata {
    name = "zodh-secret"
  }

  data = {
    VIDEO_DATABASE_USER                  = jsondecode(aws_secretsmanager_secret_version.db_user_value.secret_string)["username"]
    VIDEO_DATABASE_PASSWORD              = jsondecode(aws_secretsmanager_secret_version.db_password_value.secret_string)["password"]
    VIDEO_DATABASE_URL                   = "jdbc:postgresql://${aws_db_instance.zodh_video_database.endpoint}/${aws_db_instance.zodh_video_database.db_name}"
    VIDEO_BUCKET_NAME                    = var.video_bucket_name
    VIDEO_STATUS_UPDATE_QUEUE_NAME       = var.video_status_update_queue_name
    VIDEO_STATUS_UPDATE_QUEUE_URL        = aws_sqs_queue.video_status_update_queue.url
    VIDEO_BUCKET_ZIP_NAME                = var.processed_images_bucket_name
    VIDEO_AWAITING_PROCESSING_QUEUE_NAME = var.video_awaiting_processing_queue_name
  }

  type = "Opaque"
  depends_on = [
    aws_secretsmanager_secret_version.db_user_value,
    aws_secretsmanager_secret_version.db_password_value,
    aws_db_instance.zodh_video_database,
    aws_sqs_queue.video_status_update_queue
  ]
}

# Subnet config

## Create 2 subnets
resource "aws_subnet" "zodh_sub_1" {
  vpc_id                  = aws_vpc.zodh_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  depends_on = [aws_vpc.zodh_vpc]
}
resource "aws_subnet" "zodh_sub_2" {
  vpc_id                  = aws_vpc.zodh_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  depends_on = [aws_vpc.zodh_vpc]
}

## Create Internet Gateway
resource "aws_internet_gateway" "zodh_igw" {
  vpc_id = aws_vpc.zodh_vpc.id

  depends_on = [aws_vpc.zodh_vpc]
}

## Create Route Table
resource "aws_route_table" "zodh_route_table" {
  vpc_id = aws_vpc.zodh_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.zodh_igw.id
  }

  depends_on = [
    aws_vpc.zodh_vpc,
    aws_internet_gateway.zodh_igw
  ]
}

## Create Route Table Association
resource "aws_route_table_association" "zodh_subnet_association_1" {
  subnet_id      = aws_subnet.zodh_sub_1.id
  route_table_id = aws_route_table.zodh_route_table.id

  depends_on = [
    aws_subnet.zodh_sub_1,
    aws_route_table.zodh_route_table
  ]
}
resource "aws_route_table_association" "zodh_subnet_association_2" {
  subnet_id      = aws_subnet.zodh_sub_2.id
  route_table_id = aws_route_table.zodh_route_table.id

  depends_on = [
    aws_subnet.zodh_sub_2,
    aws_route_table.zodh_route_table
  ]
}

# EKS

## Create Cluster
resource "aws_eks_cluster" "zodh_cluster" {
  name     = "${var.project_name}-eks-cluster"
  role_arn = data.aws_iam_role.labrole.arn

  vpc_config {
    subnet_ids = [aws_subnet.zodh_sub_1.id, aws_subnet.zodh_sub_2.id]
    security_group_ids = [aws_security_group.vpc_sg.id]
  }

  depends_on = [
    aws_vpc.zodh_vpc,
    aws_subnet.zodh_sub_1,
    aws_subnet.zodh_sub_2
  ]
}

## Create Node Group
resource "aws_eks_node_group" "zodh_node_group" {
  cluster_name    = aws_eks_cluster.zodh_cluster.name
  node_group_name = "${var.project_name}-eks-node-group"
  node_role_arn   = data.aws_iam_role.labrole.arn
  subnet_ids = [aws_subnet.zodh_sub_1.id, aws_subnet.zodh_sub_2.id]
  disk_size       = 10
  instance_types = ["t3.medium"]
  ami_type        = "AL2_x86_64"

  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 3
  }

  depends_on = [
    aws_eks_cluster.zodh_cluster,
    aws_subnet.zodh_sub_1,
    aws_subnet.zodh_sub_2
  ]
}

# Execution Output

output "api_url" {
  value = aws_apigatewayv2_api.auth_api.api_endpoint
}

output "video_status_update_queue_url" {
  value = aws_sqs_queue.video_status_update_queue.url
}

output "video_awaiting_processing_queue_url" {
  value = aws_sqs_queue.video_awaiting_processing_queue.url
}
