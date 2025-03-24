# Cognito Configuration

resource "aws_cognito_user_pool" "zodh_video_user_pool" {
  name = "zodh_video_user_pool"
  mfa_configuration          = "OFF"

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  account_recovery_setting {

    recovery_mechanism {
      name = "verified_email"
      priority = 1
    }
  }

  username_attributes = [ "email" ]
  auto_verified_attributes = ["email"]

  schema {
    name                     = "given_name"
    attribute_data_type      = "String"
    required                 = true
    mutable                  = true
  }

  schema {
    name                     = "family_name"
    attribute_data_type      = "String"
    required                 = true
    mutable                  = true
  }

  password_policy {
    minimum_length = 8
    require_lowercase = false
    require_numbers = false
    require_symbols = false
    require_uppercase = false
  }
  
}

resource "aws_cognito_user_pool_client" "zodh_video_user_pool_client" {
  name = "zodh_video_user_client"
  user_pool_id = aws_cognito_user_pool.zodh_video_user_pool.id

  explicit_auth_flows = [ "ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH" ]

  token_validity_units {
    access_token = "hours" 
    refresh_token = "hours"
  }
  access_token_validity = 2
  refresh_token_validity = 48

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
  environment {
    variables = {
      "USER_POOL_ID" = aws_cognito_user_pool.zodh_video_user_pool.id
    }
  }
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
}

## Route Configuration

resource "aws_apigatewayv2_route" "sign_up_route" {
  api_id    = aws_apigatewayv2_api.auth_api.id
  route_key = "POST /auth/sign-up"
  target    = "integrations/${aws_apigatewayv2_integration.sign_up_lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "confirm_route" {
  api_id    = aws_apigatewayv2_api.auth_api.id
  route_key = "POST /auth/confirm"
  target    = "integrations/${aws_apigatewayv2_integration.confirmer_lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "sign_in_route" {
  api_id    = aws_apigatewayv2_api.auth_api.id
  route_key = "POST /auth/sign-in"
  target    = "integrations/${aws_apigatewayv2_integration.sign_in_lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "get_profile_route" {
  api_id    = aws_apigatewayv2_api.auth_api.id
  route_key = "GET /profile"
  target    = "integrations/${aws_apigatewayv2_integration.profiler_lambda_integration.id}"
  ### The profile must be protected
  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.zodh_default_authorizer.id
}

## API Gateway & Lambda Integration

resource "aws_apigatewayv2_integration" "sign_up_lambda_integration" {
  api_id           = aws_apigatewayv2_api.auth_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.zodh_authorizer_sign_up.invoke_arn
}

resource "aws_apigatewayv2_integration" "confirmer_lambda_integration" {
  api_id           = aws_apigatewayv2_api.auth_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.zodh_authorizer_confirmer.invoke_arn
}

resource "aws_apigatewayv2_integration" "sign_in_lambda_integration" {
  api_id           = aws_apigatewayv2_api.auth_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.zodh_authorizer_sign_in.invoke_arn
}

resource "aws_apigatewayv2_integration" "profiler_lambda_integration" {
  api_id           = aws_apigatewayv2_api.auth_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.zodh_authorizer_profiler.invoke_arn
}

## Allowing API Gateway to Invoke Lambda

resource "aws_lambda_permission" "signup_apigateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.zodh_authorizer_sign_up.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.auth_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "confirmer_apigateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.zodh_authorizer_confirmer.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.auth_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "signin_apigateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.zodh_authorizer_sign_in.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.auth_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "profile_apigateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.zodh_authorizer_profiler.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.auth_api.execution_arn}/*/*"
}

## API Gateway Authorizer

resource "aws_apigatewayv2_authorizer" "zodh_default_authorizer" {
  api_id = aws_apigatewayv2_api.auth_api.id
  name = "zodh-default-authorizer"
  authorizer_type = "JWT"
  identity_sources = [ "$request.header.Authorization" ]
  jwt_configuration {
    audience = [ aws_cognito_user_pool_client.zodh_video_user_pool_client.id ]
    issuer   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.zodh_video_user_pool.id}"
  }
}

# S3 Configuration

resource "aws_s3_bucket" "zodh_video_files" {
  bucket = var.video_bucket_name
}

# Execution Output

output "api_url" {
  value = aws_apigatewayv2_api.auth_api.api_endpoint
}
