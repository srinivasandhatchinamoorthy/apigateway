data "archive_file" "backend_zip" {
  type        = "zip"
  source_file = "lambda/backend.py"
  output_path = "backend.zip"
}

data "archive_file" "authorizer_zip" {
  type        = "zip"
  source_file = "lambda/authorizer.py"
  output_path = "authorizer.zip"
}

# IAM role
resource "aws_iam_role" "lambda_role" {
  name = "lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Backend Lambda
resource "aws_lambda_function" "backend" {
  function_name = "backend-fn"
  role          = aws_iam_role.lambda_role.arn
  handler       = "backend.lambda_handler"
  runtime       = "python3.10"

  filename         = data.archive_file.backend_zip.output_path
  source_code_hash = data.archive_file.backend_zip.output_base64sha256
}

# Authorizer Lambda
resource "aws_lambda_function" "authorizer" {
  function_name = "authorizer-fn"
  role          = aws_iam_role.lambda_role.arn
  handler       = "authorizer.lambda_handler"
  runtime       = "python3.10"

  filename         = data.archive_file.authorizer_zip.output_path
  source_code_hash = data.archive_file.authorizer_zip.output_base64sha256
}

# REST API
resource "aws_api_gateway_rest_api" "api" {
  name = "auth-practice-api"
}

resource "aws_api_gateway_resource" "secure" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "secure"
}

# Authorizer
resource "aws_api_gateway_authorizer" "auth" {
  name            = "lambda-authorizer"
  rest_api_id     = aws_api_gateway_rest_api.api.id
  type            = "TOKEN"
  identity_source = "method.request.header.Authorization"
  authorizer_uri  = "arn:aws:apigateway:ap-south-1:lambda:path/2015-03-31/functions/${aws_lambda_function.authorizer.arn}/invocations"
}

# Method
resource "aws_api_gateway_method" "get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.secure.id
  http_method   = "GET"

  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.auth.id
}

# Integration
resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.secure.id
  http_method = aws_api_gateway_method.get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.backend.invoke_arn
}

# Permissions
resource "aws_lambda_permission" "backend" {
  statement_id  = "AllowInvokeBackend"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backend.function_name
  principal     = "apigateway.amazonaws.com"
}

resource "aws_lambda_permission" "authorizer" {
  statement_id  = "AllowInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authorizer.function_name
  principal     = "apigateway.amazonaws.com"
}

# Deploy
resource "aws_api_gateway_deployment" "deploy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  depends_on  = [aws_api_gateway_integration.lambda]
}

resource "aws_api_gateway_stage" "prod" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.deploy.id
  stage_name    = "prod"
}

