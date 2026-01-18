output "invoke_url" {
  value = "https://${aws_api_gateway_rest_api.api.id}.execute-api.ap-south-1.amazonaws.com/${aws_api_gateway_stage.prod.stage_name}/secure"
}


