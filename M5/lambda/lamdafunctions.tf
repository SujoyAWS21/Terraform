##################################################################################
# VARIABLES
##################################################################################

variable "aws_access_key" {
}

variable "aws_secret_key" {
}

#We're specifying table that will hold all of it together 
variable "aws_dynamodb_table" {
  default = "ddt-datasource"
}

variable "accountId" {
}

#your account associated with aws
//https://www.terraform.io/docs/providers/aws/d/caller_identity.html

##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = "us-west-2"
}

data "aws_iam_group" "ec2admin" {
  group_name = "EC2Admin"
}

data "aws_region" "current" {}

##################################################################################
# RESOURCES
##################################################################################
resource "aws_dynamodb_table" "terraform_datasource" {
  name           = var.aws_dynamodb_table
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "ProjectEnvironment"

  #hashkey pr key for this table has to be unique

  attribute {
    name = "ProjectEnvironment"
    type = "S"
  }
}

#allowing access to DB table 
#allowed Get and query
resource "aws_iam_policy" "dynamodb-access" {
  name = "dynamodb-access"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:Get*", 
                "dynamodb:query"
            ],
            "Resource": "${aws_dynamodb_table.terraform_datasource.arn}"
        }
    ]
}
EOF

}

#setting up a role for lambda that it will assum when running 
resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

#attaching a policy that allows access to DynamoDb to the Role that Lambda will assume
#so it will get access to run queries and get items 
resource "aws_iam_role_policy_attachment" "dynamodb-access" {
role       = aws_iam_role.iam_for_lambda.name
policy_arn = aws_iam_policy.dynamodb-access.arn
}

#lambda function creation 
resource "aws_lambda_function" "data_source_ddb" {
filename      = "index.zip"                     # specifying file that we'll upload to lambda to create a function
function_name = "tdd_ddb_query"                 # functiions name
role          = aws_iam_role.iam_for_lambda.arn # role for lambda to get access to dynamoDB
handler       = "index.handler"
runtime       = "nodejs10.x"
}

#Constructing API gateway. 
#Creating resting Api type for it
resource "aws_api_gateway_rest_api" "tddapi" {
name = "TDDDataSourceService" //

description = "Query a DynamoDB Table for values"
}

#Creating API resource itself
resource "aws_api_gateway_resource" "tddresource" {
rest_api_id = aws_api_gateway_rest_api.tddapi.id //
parent_id   = aws_api_gateway_rest_api.tddapi.root_resource_id
path_part   = "tdd_ddb_query"
}

#Creating a method for rest API
resource "aws_api_gateway_method" "tddget" {
rest_api_id   = aws_api_gateway_rest_api.tddapi.id
resource_id   = aws_api_gateway_resource.tddresource.id
http_method   = "GET" # GET REQUEST to API GW
authorization = "NONE"
}

#What API does with a request is defyined here
#
resource "aws_api_gateway_integration" "integration" {
rest_api_id             = aws_api_gateway_rest_api.tddapi.id # It takes API
resource_id             = aws_api_gateway_resource.tddresource.id
http_method             = aws_api_gateway_method.tddget.http_method                                                                                                    # It takes http method we described earlier
integration_http_method = "POST"                                                                                                                                       # it converts it to POST REQUEST
type                    = "AWS_PROXY"                                                                                                                                  # it proxy the request to Lambda 
uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${aws_lambda_function.data_source_ddb.arn}/invocations" #URI of lambda
}

#Giving permission to invoke that function 
resource "aws_lambda_permission" "apigw_lambda" {
statement_id  = "AllowExecutionFromAPIGateway"
action        = "lambda:InvokeFunction"                 #Invoke
function_name = aws_lambda_function.data_source_ddb.arn # what action to do 
principal     = "apigateway.amazonaws.com"

# More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
source_arn = "arn:aws:execute-api:${data.aws_region.current.name}:${var.accountId}:${aws_api_gateway_rest_api.tddapi.id}/*/${aws_api_gateway_method.tddget.http_method}${aws_api_gateway_resource.tddresource.path}"
#that's why WE NEED ACCOUNT ID!
#MAYBE IT WILL BE FIXED IN THE FUTURE
}

#Deplying APIGW and making it accessible externally and ready 
resource "aws_api_gateway_deployment" "ddtdeployment" {
depends_on = [aws_api_gateway_integration.integration] # explisit dependency on integration piece

rest_api_id = aws_api_gateway_rest_api.tddapi.id //handing rest api id
stage_name  = "prod"
}

output "invoke-url" {
value = "https://${aws_api_gateway_deployment.ddtdeployment.rest_api_id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_deployment.ddtdeployment.stage_name}/${aws_lambda_function.data_source_ddb.function_name}"
#actual URL you call to invoke the lambda function to get information you need 
}

