def lambda_handler(event, context):
    headers = event.get("headers") or {}
    token = headers.get("X-Auth-Token")

    if token == "allow-token":
        return {
            "principalId": "user",
            "policyDocument": {
                "Version": "2012-10-17",
                "Statement": [
                    {
                        "Action": "execute-api:Invoke",
                        "Effect": "Allow",
                        "Resource": "*"
                    }
                ]
            }
        }

    raise Exception("Unauthorized")

