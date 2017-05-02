##################################################
# Determines the 'Dominate User' of the computer #
##################################################
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

##############################################
# Gets the user object from Active Directory #
##############################################

$strName = $DominateUser

$strFilter = "(&(objectCategory=User)(samAccountName=$strName))"
$objSearcher = New-Object System.DirectoryServices.DirectorySearcher 
$objSearcher.Filter = $strFilter

$objPath = $objSearcher.FindOne() 
$objUser = $objPath.GetDirectoryEntry()

$strLoggedInUser = $objUser.DistinguishedName

#################################################
# Get the computer object from Active Directory #
#################################################

$strComputer = $env:computername

$strFilter = "(&(objectCategory=Computer)(cn=$strComputer))"
$objSearcher = New-Object System.DirectoryServices.DirectorySearcher 
$objSearcher.Filter = $strFilter

$objPath = $objSearcher.FindOne() 
$objComputer = $objPath.GetDirectoryEntry()

###################################################
# Set ManagedBy attribute of the computer object. #
###################################################

$objComputer.ManagedBy = $strLoggedInUser
$objComputer.CommitChanges()
