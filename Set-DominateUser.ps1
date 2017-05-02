<#
.SYNOPSIS
Determines the Dominate User on the computer and writes that value to the ManagedBy property in Active Directory.

.DESCRIPTION
The Dominate User is determined by taking the greatest difference between the LastAccessTimeUTC and the CreationTimeUTC. The user and computer objects are pulled from Active Directory by using ADSI. 
#>
[CmdletBinding()]
Param()

function Get-MBDominateUser {
    [CmdletBinding()]
    Param()

    Write-Verbose "Get array of local users. Determine Dominate User based on largest TimeInterval."
    $UserArray = @()
    Get-ChildItem -Path (Get-Item -Path $env:USERPROFILE).PSParentPath -Exclude Default*, Public | 
    Select-Object -Property Name, CreationTimeUtc, LastAccessTimeUtc |
                ForEach-Object {
                $NewObj = New-Object -TypeName PSObject
                $TimeInterval = New-TimeSpan -Start $_.CreationTimeUtc -End $_.LastAccessTimeUtc 
                $NewObj | Add-Member -Type NoteProperty -Name User -Value $_.Name
                $NewObj | Add-Member -Type NoteProperty -Name Interval -Value $TimeInterval
                $UserArray += $NewObj
                }
    $DominateUser = ($UserArray | Sort Interval -Descending | Select-Object -First 1).User

    Write-Verbose "Use ADSI to determine user DN"
    $strName = $DominateUser

    $strFilter = "(&(objectCategory=User)(samAccountName=$strName))"
    $objSearcher = New-Object System.DirectoryServices.DirectorySearcher 
    $objSearcher.Filter = $strFilter

    $objPath = $objSearcher.FindOne() 
    $objUser = $objPath.GetDirectoryEntry()

    Write-Output $objUser
}

function Get-MBComputer {
    [CmdletBinding()]
    Param()

    Write-Verbose "Use ADSI to determine computer DN"
    $strComputer = $env:computername

    $strFilter = "(&(objectCategory=Computer)(cn=$strComputer))"
    $objSearcher = New-Object System.DirectoryServices.DirectorySearcher 
    $objSearcher.Filter = $strFilter

    $objPath = $objSearcher.FindOne() 
    $objComputer = $objPath.GetDirectoryEntry()
    Write-Output $objComputer
}

Write-Verbose "Writing Dominate User value to Active Directory"
$DominateUserDN = (Get-MBDominateUser).distinguishedName
$MBComputer = Get-MBComputer
$MBComputer.managedBy = $DominateUserDN
$MBComputer.CommitChanges()
