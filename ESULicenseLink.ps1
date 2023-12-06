#The aim of this script is to provide an automatic way of linking an existing ESU license with the corresponding VM
#To perform license provisioning, you can use the ESULicenseProvisioning script
#For info, please contact: luca@lucapisano.it

Install-Module Az.ResourceGraph -Force -Scope CurrentUser
#Connect-AzAccount #only needed if the current user has not yet logged on or the token has expired
$dryRun=$true #replace it with $false
$region = "westeurope"
$subscriptionId = "..."
$resourceGroupName = "..."
$targetLicenseNamePrefix = "ESU_2012_"
$licensePrefixResourceId = "/subscriptions/"+$subscriptionId+"/resourceGroups/"+$resourceGroupName+"/providers/Microsoft.HybridCompute/licenses/"+$targetLicenseNamePrefix

Function Perform-LicenseOperation {
    param (
         [string]$licenseId,
         [string]$vmId,
         [Hashtable]$body
     )
    if($dryRun)
    {Write-Information "Dry RUN, returning" -InformationAction Continue; return}
    $URI = "https://management.azure.com/"+ $vmId + "/licenseProfiles/default?api-version=2023-06-20-preview"
    if(!$accessToken){
        $accessToken = (Get-AzAccessToken -ResourceUrl https://management.azure.com).Token
    }
    $headers = [ordered]@{"Content-Type"="application/json"; "Authorization"="Bearer $accessToken"} 
    $method = "PUT"
    $jsonBody = $body | ConvertTo-Json
    $response = Invoke-WebRequest -URI $URI -Method $method -Headers $headers -Body $jsonBody
}
Function Link-License {
     param (
         [string]$licenseId,
         [string]$vmId
     )
    Write-Information ("Linking license: "+$licenseId+" with VM: "+$vmId) -InformationAction Continue
    $jsonObject = @{
        location = $region
        properties = @{
            esuProfile = @{
                assignedLicense = $licenseId
            }
        }
    }
    Perform-LicenseOperation -licenseId $licenseId -vmId $vmId -body $jsonObject
 }

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 
Import-Module Az.ResourceGraph -Scope Local
$searchResult = Search-AzGraph -First 1000 -Query "resources | where type =~ 'microsoft.hybridcompute/machines' | extend esuEligibility = properties.licenseProfile.esuProfile.esuEligibility | extend os = properties.osSku | extend status = properties.licenseProfile.esuProfile.licenseAssignmentState | extend cores = properties.detectedProperties.logicalCoreCount | where status =~ 'NotAssigned' |project name, status, os, id, subscriptionId, resourceGroup, esuEligibility, cores"
foreach($vm in $searchResult)
{
    $vmName =  $vm | Select -ExpandProperty name
    $vmId =  $vm | Select -ExpandProperty id
    $licenseId = $licensePrefixResourceId+$vmName
    
    if($licenseId.Length -gt 2){
        Link-License -licenseId $licenseId -vmId $vmId
    }
}
