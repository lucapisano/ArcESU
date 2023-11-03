# ArcESU
The aim of this repo is to provide an automatic way of provisioning ESU licenses querying eligible VMs on Azure ARC.
# Steps
1. Onboard your VMs on Azure ARC. Follow [the documentation]([https://link-url-here.org](https://learn.microsoft.com/en-us/azure/azure-arc/servers/onboard-service-principal)https://learn.microsoft.com/en-us/azure/azure-arc/servers/onboard-service-principal) for at-scale onboarding.
2. Download Azure Powershell modules on your PC and use the Connect-AzAccount cmdlet or use Azure Cloud Shell to upload the following files.
3. Review and run ESULicenseProvisioning.ps1 to provision 1 license for each eligible VM. Make sure to change $dryRun to $false and $targetLicenseState to "Activated" before running the script.
4. Review and run ESULicenseLink.ps1 to associate each license to the corresponding VM. Make sure to change the $subscriptionId and $resourceGroupName before running the script.

Now you can enjoy Extended Security Updates on Windows Server 2012 VMs!
