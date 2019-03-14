```powershell
# .Synopsis Provision new VDIs to a given delivery group in XenDesktop site. .Syntax Update machine catalog name, delivery group name and run it. You can run it from posh console or add it to scheduled task. .Description This script checks for free VDIs in a delivery group. If free VDI count is less than 8, it would provision difference machines from 8, to get the free VDI count to 8. Ex, If there are 6 free VDIs, it would provision 2 more machines so that free VDI count is 8. Similarly if there is only 1 free VDI, it creates 7 new VDIs to match free VDI count to 8.You can change this value as per your new user requests for VDI. .Example .\New-XenDesktop VM.ps1 .Outputs Creates new VDIs based on free VDI count. You can also have a log at c:\PoshTemp folder. Each and every step is logged here. .Notes Connects to next available server in your xendesktop controller servers set. If first server fails, this script runs failed commands on second server. Checks for only two servers in this fashion. .Link If it doesnt provision VDIs or if there are any errors, Check if you have orphan AD accounts in your delivery group and remove them. Check more info here:http://knowcitrix.com/cannot-bind-argument-to-parameter-adaccountname-because-it-is-an-empty-string-error-when-creating-new-machines-in-machine-catalog/ #&gt;
$Time = Get-Date -Format yyyyMMdd-HHmm
 
#Record all the steps in the script.
Start-Transcript -Path C:\PoshTemp\NewXenDesktopVM-$Time.txt -Append
 
#Import Citrix snapins
Add-PSSnapin citrix*
 
#Import vmware snapins
Import-Module VMware.VimAutomation.Core
connect-viserver VCENTER SERVER NAME
 
#Get XenDesktop controller site name
$ControllerName = (Get-BrokerController -AdminAddress "XENDESKTOP CONTROLLER NAME").DNSName
$XenDesktopController = $ControllerName[0]
 
#Get Machine catalog and number of machines details
$MachineCatalog = "Machine catalog name"
$DeliveryGroup = "Delivery group name"
 
#Get identity pool uid of first xendesktop server, if it fails connect to second server
Try { $IdentityPoolUid = (Get-AcctIdentityPool -AdminAddress $XenDesktopController -IdentityPoolName $MachineCatalog -MaxRecordCount 2147483647).IdentityPoolUid.Guid}
catch { Write-Output "$XenDesktopController has an issue, trying with other xendesktop controller"
$XenDesktopController = $ControllerName[1]
$IdentityPoolUid = (Get-AcctIdentityPool -AdminAddress $XenDesktopController -IdentityPoolName $MachineCatalog -MaxRecordCount 2147483647).IdentityPoolUid.Guid
}
 
#Get free VDI count from first xendesktop server, if it fails connect to second server, Email citrix admin if both servers fail.
Try {$FreeVDICount = (Get-BrokerDesktop -adminaddress $XenDesktopController -DesktopGroupName $DeliveryGroup -MaxRecordCount 2000000 | ? {!($_.AssociatedUserNames) -and ($_.RegistrationState -eq "Registered")}).count}
catch {
Try {
Write-Output "$XenDesktopController has an issue, trying with other xendesktop controller"
$XenDesktopController = $ControllerName[1]
$FreeVDICount = (Get-BrokerDesktop -adminaddress $XenDesktopController -DesktopGroupName $DeliveryGroup -MaxRecordCount 2000000 | ? {!($_.AssociatedUserNames) -and ($_.RegistrationState -eq "Registered")}).count
}
catch {
#If FreeVDICount doesnt get a value, which means above commands didnt work, exit script.
Write-Output "Citrix servers has an issue, not able to pull free VDI count. Exiting.. "
$Body = "Hi, " + " 
 
" + "Not able to pull free vdi count from $DeliveryGroup. Please check the servers." + " 
 
" + "Thanks, 
 Automated Script.
 
"
Send-MailMessage -From "From email address" -To "To email address" -Subject "Free VDI count failed in $DeliveryGroup. Please check" -BodyAsHtml $Body -SmtpServer "smtp server name"
break
}
}
 
Write-Output **************
Write-Output "Currently there are $FreeVDICount free VDIs in $DeliveryGroup group"
Write-Output **************
 
#Provisioning Starts from here:
 
if ($FreeVDICount -le "8") {
 
$NumMachines = 8 - $FreeVDICount
for ($i=1; $i -le $NumMachines; $i++) {
 
#create new AD accounts
Write-Output "Creating AD Account"
Try {
New-AcctADAccount -count 1 -IdentityPoolUid $IdentityPoolUid
} catch {
$XenDesktopController = $ControllerName[1]
$IdentityPoolUid = (Get-AcctIdentityPool -AdminAddress $XenDesktopController -IdentityPoolName $MachineCatalog -MaxRecordCount 2147483647).IdentityPoolUid.Guid
}
$NewAdAccount = (Get-AcctADAccount -IdentityPoolUid $IdentityPoolUid -State Available -AdminAddress $XenDesktopController).ADAccountName
 
#create new VM
Write-Output "Creating VM in vcenter"
Try {
New-ProvVM -ProvisioningSchemeName $MachineCatalog -ADAccountName $NewAdAccount -RunAsynchronously -AdminAddress $XenDesktopController
}
catch {
Write-Output "$XenDesktopController has an issue, trying with other xendesktop controller"
$XenDesktopController = $ControllerName[1]
New-ProvVM -ProvisioningSchemeName $MachineCatalog -ADAccountName $NewAdAccount -RunAsynchronously -AdminAddress $XenDesktopController
}
 
#Wait for 40 seconds to create VM in vcenter
Write-Output "Waiting for the VM to create in vcenter"
Start-Sleep -Seconds 40
 
#checking if the machine is created successfully in vcenter. Sometimes citrix would delete this new vms for some reason. so checking if vm is present in vcenter. Trim domain name from the vmname to search in vmware.
$vmcheck = ($NewAdAccount.Trim("Domain\").TrimEnd(" $"))
if (!(get-vm $vmcheck -ErrorAction SilentlyContinue)) {
#for some reason, if new machine is not available in vcenter, try to provision it again after 2 mins.
Start-Sleep -Seconds 120
Try {
New-ProvVM -ProvisioningSchemeName $MachineCatalog -ADAccountName $NewAdAccount -RunAsynchronously -AdminAddress $XenDesktopController
}
catch {
Write-Output "$XenDesktopController has an issue, trying with other xendesktop controller"
$XenDesktopController = $ControllerName[1]
New-ProvVM -ProvisioningSchemeName $MachineCatalog -ADAccountName $NewAdAccount -RunAsynchronously -AdminAddress $XenDesktopController
}
}
 
#waiting for 3 mins for vm to settle
Write-Output "waiting 3 mins for new vm to settle in vcenter"
Start-Sleep -Seconds 180
#Add new vm to machine catalog
Write-Output "Adding machine to machine catalog"
Try {
$CatalogUID = (Get-BrokerCatalog $MachineCatalog -AdminAddress $XenDesktopController).uid
New-BrokerMachine -AdminAddress $XenDesktopController -CatalogUid $CatalogUID -MachineName $NewAdAccount
} catch {
$XenDesktopController = $ControllerName[1]
$CatalogUID = (Get-BrokerCatalog $MachineCatalog -AdminAddress $XenDesktopController).uid
New-BrokerMachine -AdminAddress $XenDesktopController -CatalogUid $CatalogUID -MachineName $NewAdAccount
}
 
#Wait for 40 seconds before adding this new VDI to delivery group.
Start-Sleep -Seconds 40
 
#Add machine to Delivery group
Write-Output "Adding machine to delivery group"
Try {
Add-BrokerMachinesToDesktopGroup -AdminAddress $XenDesktopController -Catalog $MachineCatalog -DesktopGroup $DeliveryGroup -Count 1
} catch {
$XenDesktopController = $ControllerName[1]
Add-BrokerMachinesToDesktopGroup -AdminAddress $XenDesktopController -Catalog $MachineCatalog -DesktopGroup $DeliveryGroup -Count 1
}
 
}
 
#wait for some time to add new machine to delivery group, and power on, and register. Using below command check for registered and unassigned machines.
Start-Sleep -Seconds 180
 
#Get free VDI count from first xendesktop server, if it fails connect to second server
Try {$NewFreeVDICount = (Get-BrokerDesktop -adminaddress $XenDesktopController -DesktopGroupName $DeliveryGroup -MaxRecordCount 2000000 | ? {!($_.AssociatedUserNames) -and ($_.RegistrationState -eq "Registered")}).count}
catch { Write-Output "$XenDesktopController has an issue, trying with other xendesktop controller"
$XenDesktopController = $ControllerName[1]
$NewFreeVDICount = (Get-BrokerDesktop -adminaddress $XenDesktopController -DesktopGroupName $DeliveryGroup -MaxRecordCount 2000000 | ? {!($_.AssociatedUserNames) -and ($_.RegistrationState -eq "Registered")}).count
}
 
$EmailTo = "To email address"
$Body = "Hi Team, " + " 
 
" + "Provisioned New VDIs to $DeliveryGroup group. There are overall $NewFreeVDICount free machines in $DeliveryGroup now." + " 
 
" + "Thanks, 
 Automated script.
 
"
 
Send-MailMessage -From "From email address" -To $EmailTo -Subject "New VDIs provisioned on: $Time" -BodyAsHtml "$Body" -SmtpServer smtp server name
 
}
else {
Write-Output "There are more than 8 Free VDI in $DeliveryGroup. Exiting.. "
break
}
Stop-Transcript
