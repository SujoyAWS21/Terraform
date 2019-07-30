# Read stdin as string
$jsonpayload = [Console]::In.ReadLine() #values passed in json format

# Convert to JSON
$json = ConvertFrom-Json $jsonpayload

# Access JSON values 
$workspace = $json.workspace
$projectcode = $json.projectcode
$url = $json.url

#Configure the query
$headers = @{}
$headers.Add("querytext","$workspace-$projectcode")# that value will be used to query DynamoDB table
$response = Invoke-WebRequest -uri $url -Method Get -Headers $headers #making web requests to the URL we've passed, using method GET with headers we created

#Return response to stdout in json format
Write-Output $response.content