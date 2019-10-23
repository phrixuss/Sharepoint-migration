# Get the ID and security principal of the current user account
$myWindowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent();
$myWindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($myWindowsID);

# Get the security principal for the administrator role
$adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator;

# Check to see if we are currently running as an administrator
if ($myWindowsPrincipal.IsInRole($adminRole))
{
    # We are running as an administrator, so change the title and background colour to indicate this
    $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)";
    $Host.UI.RawUI.BackgroundColor = "DarkBlue";
    Clear-Host;
}
else {
    # We are not running as an administrator, so relaunch as administrator

    # Create a new process object that starts PowerShell
    $newProcess = New-Object System.Diagnostics.ProcessStartInfo "PowerShell";

    # Specify the current script path and name as a parameter with added scope and support for scripts with spaces in it's path
    $newProcess.Arguments = "& '" + $script:MyInvocation.MyCommand.Path + "'"

    # Indicate that the process should be elevated
    $newProcess.Verb = "runas";

    # Start the new process
    [System.Diagnostics.Process]::Start($newProcess);

    # Exit from the current, unelevated, process
    Exit;
}
<#
if(Test-Path C:\One Drive Migrations\Script\usermigrationlist.csv){
    Remove-Item C:\One Drive Migrations\Script\usermigrationlist.csv
}
#>
Import-Module Microsoft.SharePoint.MigrationTool.PowerShell

Import-Module ActiveDirectory
function Show-Menu
{
     param (
           [string]$Title = 'User Migration Sharepoint'
     )
     cls
     Write-Host "================ $Title ================"
    
     Write-Host "1: Press '1' Add user to migration."
     Write-Host "2: Press '2' Migrate user's."
     Write-Host "Q: Press 'Q' to quit."
}
do
{
     Show-Menu
     $input = Read-Host "Please make a selection"
     switch ($input)
     {
           '1' {
                cls
                $userinput = Read-Host "enter user name(logonname)"
                $userfound = $(try {Get-ADUser $userinput} catch {$null})
                if ($userfound -eq $Null) {
                    Write-Warning -Message "User not found"
                    
                }elseif($input -like $userfound.samaccountname){
                    Write-Warning -Message "Please enter the logon name"
                    
                }else{
                
                    if (Test-Path "C:\One Drive Migrations\Script\usermigrationlist.csv"){
                        $file = Import-Csv -path "C:\One Drive Migrations\Script\usermigrationlist.csv"
                        $check = ($file).username
                        
                        if ($check -contains $userinput) {
                            Write-Host "user already exist in the csv"
                        }else{
                            Add-Content -path "C:\One Drive Migrations\Script\usermigrationlist.csv" -Value $userinput
                        }
                    }else{
                        Add-Content -Path "C:\One Drive Migrations\Script\usermigrationlist.csv" -Value 'username'
                        Add-Content -path "C:\One Drive Migrations\Script\usermigrationlist.csv" -Value $userinput
                    }

                }
 

           } '2' {
                cls
                     
  
                    if(Test-Path "C:\One Drive Migrations\Script\usermigrationlist.csv"){                      
                        $users = Import-Csv "C:\One Drive Migrations\Script\usermigrationlist.csv"
                        Register-SPMTMigration

                        foreach ($user in $users) {

                            $email = get-aduser -identity $user.username -Properties * | Select-Object userprincipalname
                            $canonicalname = get-aduser -identity $user.username -properties CanonicalName
                            $usernameprofile = get-aduser -identity $user.username -Properties * | Select-Object samaccountname
                            $distinguishednameuser = get-aduser -identity $user.username -Properties * | Select-Object distinguishedname
    
                            Write-Host "migrating user"$email.userprincipalname    

                            #$profilelocation = ("E:\userprofile\"+$oulocation+"\"+$servernamecalling+"\"+$usernameprofile.samaccountname).ToLower()

                            $profilelocation = @(Get-ChildItem E:\UsersProfile\ -recurse -Depth 2 | Where-Object {$_.PSIsContainer -eq $true -and $_.Name -match $usernameprofile.samaccountname } | Select-Object fullname)

                        if ($profilelocation.length -eq 0){
                            Write-Host "Directory not found" $usernameprofile.samaccountname
                        }else{

                            foreach ($profilelocationresult in $profilelocation){

                                $profilelocationresultcheck = $profilelocationresult + "\Desktop"
                                $profilelocationresultcheck2 = $profilelocationresult + "\My Documents"

                                    if ((Test-Path $profilelocationresultcheck) -and (Test-Path $profilelocationresultcheck2)){
                                        

                                        $profilelocationdesktop = "_OD_"+$profilelocation.fullname+"\Desktop"
                                        $profilelocationdocuments = "_OD_"+$profilelocation.fullname+"\My Documents"
                                        $emailconverted = $email.userprincipalname.Replace(",","_").Replace(".","_").Replace("@","_")
                                        $weblocationsharepoint = "https://thefrankgroup-my.sharepoint.com/personal/"+$emailconverted

                                        $propertiesdesktop = '' | SELECT Source,SourceDocLib,SourceSubFolder,TargetWeb,TargetDocLib,TargetSubFolder
                                        $propertiesdesktop.Source = $profilelocationdesktop #c1
                                        $propertiesdesktop.SourceDocLib = '' #c2
                                        $propertiesdesktop.SourceSubFolder = '' #c3
                                        $propertiesdesktop.TargetWeb = $weblocationsharepoint #c4
                                        $propertiesdesktop.TargetDocLib = 'Documents' #c5
                                        $propertiesdesktop.TargetSubFolder = 'Desktop' #c6                                           write-host "Generating CSV for migration"
                                        $propertiesdesktop | Export-Csv -NoTypeInformation "C:\One Drive Migrations\Script\usermigrationindividual.csv"                         
                                            Write-Warning "Sending to queue Desktop"

                                        $csvItems = import-csv "C:\One Drive Migrations\Script\usermigrationindividual.csv" 
                                        Add-SPMTTask -FileShareSource $csvItems.Source -TargetSiteUrl $csvItems.TargetWeb -TargetList $csvItems.TargetDocLib -TargetListRelativePath $csvItems.TargetSubFolder




                                        $propertiesdocuments = '' | SELECT Source,SourceDocLib,SourceSubFolder,TargetWeb,TargetDocLib,TargetSubFolder
                                        $propertiesdocuments.Source = $profilelocationdocuments
                                        $propertiesdocuments.SourceDocLib = ''
                                        $propertiesdocuments.SourceSubFolder = ''
                                        $propertiesdocuments.TargetWeb = $weblocationsharepoint
                                        $propertiesdocuments.TargetDocLib = 'Documents'
                                        $propertiesdocuments.TargetSubFolder = 'Documents'                                            write-host "Generating CSV for migration"
                                        $propertiesdocuments | Export-Csv -NoTypeInformation "C:\One Drive Migrations\Script\usermigrationindividual.csv"                         
                                            Write-Warning "Sending to queue My Documents"

                                        $csvItems = import-csv "C:\One Drive Migrations\Script\usermigrationindividual.csv" 
                                        Add-SPMTTask -FileShareSource $csvItems.Source -TargetSiteUrl $csvItems.TargetWeb -TargetList $csvItems.TargetDocLib -TargetListRelativePath $csvItems.TargetSubFolder


                                        Write-Host "changing user profile locations to _OD_"$profilelocationresult
                                        Rename-Item -Path $profilelocationresult -NewName ("_OD_"+$usernameprofile.samaccountname)
                                        
                                        Write-Host "Moving user object to OU=Users,OU=Company (Build)"
                                        move-adobject -identity $distinguishednameuser.distinguishedname -targetpath "OU=Users,OU=Company (Build),DC=nigelfrank,DC=local"
                                        
                                        
                                        $passwordchange = $usernameprofile.samaccountname+(Get-Date).Day+"*"
                                        Write-Warning "Changing password for user "$usernameprofile.samaccountname" to: "$passwordchange
                                        Set-ADAccountPassword -Identity $usernameprofile.samaccountname -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $passwordchange -Force) 


                                        }else{
                                        
                                            Write-Warning "User profile data empty"
                                        
                                        } #else
                            
                            
                            
                            } #foreach
                            
                            
                            
                            } #else



                        } #foreach


           
               
                        
                       Start-SPMTMigration

                       Remove-Item "C:\One Drive Migrations\Script\usermigrationlist.csv" -ErrorAction 'silentlycontinue'
                       #Remove-Item "C:\One Drive Migrations\Script\usermigrationlist.csv" -ErrorAction 'silentlycontinue'
                    }else{

                        Write-Warning "User migration list not found, to input user select 1 on the menu"

                    }


               

           } 'q' {
                Remove-Item "C:\One Drive Migrations\Script\usermigrationlist.csv" -ErrorAction 'silentlycontinue'
                return
           }
     }
     pause
}
until ($input -eq 'q')