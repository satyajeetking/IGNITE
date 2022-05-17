Write-Host ""
Write-Host "Hello !! starting the execution"

# Ignore SSL issues

add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
            return true;
        }
 }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

$client_id = '5BxXAq4rcFCHJ8sid6Zyom74Ufwa'
$client_secret = 'CNK5zmyqLVioyqSCkcxXLkolAcUa'

$wso2_userName = 'AbcamAdmin'
$wso2_userPassword = 'AbcamAdmin123'

$wso2_server_ip = 'ignite-wso-ignite-prod.mig-cluster-01-7e2996fc95fd6eb4a4c7a63aa3e73699-0000.us-south.containers.appdomain.cloud'
$igniteplatform_server_ip = 'ignite-platform-ignite-prod.mig-cluster-01-7e2996fc95fd6eb4a4c7a63aa3e73699-0000.us-south.containers.appdomain.cloud'
$otfa_server_ip = 'otfa-ignite-prod.mig-cluster-01-7e2996fc95fd6eb4a4c7a63aa3e73699-0000.us-south.containers.appdomain.cloud'

$applicationName = $args[0]
$WebEnv = $args[1]
$ScenarioGroupName = $args[2]
$Mode = $args[3]
$Browser = $args[4]

$AUTH_URL = "https://$($wso2_server_ip)/oauth2/token"

$userpass = "$($client_id):$($client_secret)"

$BasicAuthvalue = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($userpass))

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Basic $BasicAuthvalue")
$headers.Add("Content-Type", "application/x-www-form-urlencoded")

$body = "grant_type=password&username=$($wso2_userName)&password=$($wso2_userPassword)&scope=openid"

Write-Host "Sending request to extract token"

$response = Invoke-RestMethod $AUTH_URL -Method 'POST' -Headers $headers -Body $body 

$responseJSONTokenData = $response | ConvertTo-Json -Compress
$objectResponseTokenData = ConvertFrom-JSON -InputObject $responseJSONTokenData

$token = $objectResponseTokenData.access_token
Write-Host "Access token is : $($token)"

Write-Host "Sending request to get the environment URLs"
$environmentDetailsURL = "https://$($igniteplatform_server_ip)/ignitePlatform/ignite/webapi/applications/$($applicationName)?requester=otfa"
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Token", "$token")

$response = Invoke-RestMethod $environmentDetailsURL -Method 'GET' -Headers $headers

$responseJSONEnvironmentData = $response | ConvertTo-Json -Depth 10 -Compress
$objectResponseEnvironmentData = ConvertFrom-JSON -InputObject $responseJSONEnvironmentData

foreach ($item in $objectResponseEnvironmentData.testTool[0].toolConfiguration[0].configurationDetails) {
    if ( $item.applicationEnvironment -eq $WebEnv )
	{
		$environmentURL = $item.applicationUrl
	}	
}

Write-Host "Web environment URL is : $($environmentURL)"

Write-Host "Checking if the scenario group name provided is correct or not"

$listOfScenarioGroupURL = "https://$($otfa_server_ip)/otfa/scenarioexe/group/$($applicationName)"
$response = Invoke-RestMethod $listOfScenarioGroupURL -Method 'GET' -Headers $headers

$responseJSONScenarioGroupData = $response | ConvertTo-Json -Depth 10 -Compress

$objectResponseScenarioGroupData = ConvertFrom-JSON -InputObject $responseJSONScenarioGroupData

$groupExists = 'False'

ForEach ($group in $objectResponseScenarioGroupData){	

    if ( $group.name -eq $ScenarioGroupName ){
		$groupExists = 'True'
		break
	}else{
		$groupExists = 'False'
	}
}

if ( $groupExists -eq 'True' ){
	Write-Host "Group name found in the list, starting the execution"
}else{
	throw "Unable to find the group name in IQP"
}

$jsonContent = '{
    "webParam": {
		"applicationUrl": "'+$environmentURL+'",
        "baseUrl": "NONE",
        "enableSchemaValidation": "false",
        "authentication": "no",
        "useProxy": "false",
        "skipCustomDesiredCapabilities": "No",
        "clearCookies": '+$false.ToString().ToLower()+',
        "sendNotification": '+$false.ToString().ToLower()+',
        "scenarioTagRun": "true",
        "executionLevel": "'+$Mode+'",
        "scenarioGroupName": "'+$ScenarioGroupName+'",
        "skipPolicy": '+$true.ToString().ToLower()+',
        "wsdlUrl": "NONE",
        "dryRun": "false",
        "objectLocatorsIteration": "ALL",
        "skipLogToDefectTool": "Not Applicable",
        "reloadTestCases": "Not Applicable",
        "skipCustomHeader": "Yes",
        "zaleniumServer": "DefaultDocker",
        "executionPlatform": "zalenium",
        "browserName": [
            "'+$Browser+'"
        ],
        "zaleniumServerHost": "zalenium"
    }
}'

$URLOTFA = "https://$($otfa_server_ip)/otfa/scenarioexe/$($applicationName)/$($ScenarioGroupName)"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Token", "$token")
$headers.Add("Content-Type", "application/json")

$response = Invoke-RestMethod $URLOTFA -Method 'POST' -Headers $headers -Body $jsonContent
Write-Host "Scenario Group execution completed successfully"
