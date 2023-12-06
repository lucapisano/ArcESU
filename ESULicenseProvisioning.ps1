#The aim of this script is to provide an automatic way of provisioning ESU licenses querying eligible VMs
#The logic is to provision 1 license per each VM and writing the VM hostname inside the license name. Therefore you can easily associate a license with the corresponding VM.
#After provisioning, you can use the ESULink script to associate each license to the corresponding VM
#For info, please contact: luca@lucapisano.it

Install-Module Az.ResourceGraph -Force -Scope CurrentUser
#Connect-AzAccount #needed if the current user has not yet logged on or the token has expired
$dryRun=$true #replace it with $false
$region = "westeurope"
$targetLicenseState = "Deactivated" #replace it with Activated
$targetLicenseSKU = "Windows Server 2012"
$targetLicenseNamePrefix = "ESU_2012_"

Function Provision-License {
     param (
         [string]$subscriptionId,
         [string]$resourceGroupName,
         [string]$licenseName,
         [string]$edition,
         [string]$type="vCore",
         [int]$processorCores=8
     )
    Write-Information ("Provisioning "+$targetLicenseState+" license: "+$licenseName+"; Edition: "+$edition+"; Cores: "+$processorCores) -InformationAction Continue
    if($dryRun)
    {Write-Information "Dry RUN, returning" -InformationAction Continue; return}
    $URI = "https://management.azure.com/subscriptions/" + $subscriptionId + "/resourceGroups/" + $resourceGroupName + "/providers/Microsoft.HybridCompute/licenses/" + $licenseName + "?api-version=2023-06-20-preview"
    if(!$accessToken){
        $accessToken = (Get-AzAccessToken -ResourceUrl https://management.azure.com).Token
    }
    $headers = [ordered]@{"Content-Type"="application/json"; "Authorization"="Bearer $accessToken"} 
    $method = "PUT"
    $jsonObject = @{
        location = $region
        properties = @{
            licenseDetails = @{
                state = $targetLicenseState
                target = $targetLicenseSKU
                Edition = $edition
                Type = $type
                Processors = [int]$processorCores
            }
        }
    }
    $jsonBody = $jsonObject | ConvertTo-Json
    $response = Invoke-WebRequest -URI $URI -Method $method -Headers $headers -Body $jsonBody
 }
 Function Remove-License {
     param (
         [string]$licenseResourceId
     )
    Write-Information ("Deleting "+$licenseResourceId) -InformationAction Continue
    if($dryRun)
    {Write-Information "Dry RUN, returning" -InformationAction Continue; return}
    $URI = "https://management.azure.com/"+$licenseResourceId+"?api-version=2023-06-20-preview"
    if(!$accessToken){
        $accessToken = (Get-AzAccessToken -ResourceUrl https://management.azure.com).Token
    }
    $headers = [ordered]@{"Content-Type"="application/json"; "Authorization"="Bearer $accessToken"} 
    $method = "DELETE"
    $response = Invoke-WebRequest -URI $URI -Method $method -Headers $headers
 }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 
Import-Module Az.ResourceGraph -Scope Local
$searchResult = Search-AzGraph -First 1000 -Query "resources | where type =~ 'microsoft.hybridcompute/machines' | extend esuEligibility = properties.licenseProfile.esuProfile.esuEligibility | extend os = properties.osSku | extend status = properties.licenseProfile.esuProfile.licenseAssignmentState | extend cores = properties.detectedProperties.logicalCoreCount | where esuEligibility =~ 'Eligible' |project name, status, os, id, subscriptionId, resourceGroup, esuEligibility, cores"
foreach($vm in $searchResult)
{
    $vmName =  $vm | Select -ExpandProperty name
    $vmId =  $vm | Select -ExpandProperty id
    $vmOs = $vm | Select -ExpandProperty os
    $vmCores = $vm | Select -ExpandProperty cores
    $licenseName = $targetLicenseNamePrefix+$vmName
    $licenseEdition = $null
    $subId = $vm | Select -ExpandProperty subscriptionId
    $rg = $vm | Select -ExpandProperty resourceGroup
    switch -Wildcard ($vmOs)
    {
        "*Standard" {$licenseEdition="Standard"}
        "*Datacenter" {$licenseEdition="Datacenter"}
        Default { 
            Write-Warning ("Cannot provision a license for VM "+$vmName+" because no eligible OS was detected: "+$vmOs) -WarningAction Continue
            continue
        }
    }
    if($vmCores -lt 8)
    {
        $vmCores=8
    }
    if($licenseEdition -ne $null){
        Provision-License -subscriptionId $subId -resourceGroupName $rg -licenseName $licenseName -edition $licenseEdition -processorCores $vmCores
    }
}
