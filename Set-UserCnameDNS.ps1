<#
.SYNOPSIS
Script creates DNS CNAME entries for client computers based on the mangedBy property in AD.

.DESCRIPTION
Script queries AD and gets computers in the Computers OU that are not members of the "COMP_Multiuser"
security group. For each computer the managedBy property is selected to create CNAME entries in DNS. 

Example Outcome: jdoe.laptop.contoso.com is an alias for LAP-4D34D3A.contoso.com

This will be utilzied to help users RDP into their workstations when not at work. 

Script also, cleans any orphaned entries that are no longer valid if computers have been removed from AD.
#>

[CmdletBinding()]
Param()

#Check if DnsServer Module is loaded 
if (-not (Get-Module DnsServer)){
    Write-Verbose -Message "Importing DnsServer Module"
    Import-Module DnsServer
}

$ADForestName = Get-ADForest | Select-Object -ExpandProperty Name
Write-Verbose -Message "AD Forest Name is set to $ADForestName"

$DNSZoneName = Get-DnsServerZone -Name $ADForestName | 
               Select-Object -ExpandProperty ZoneName
Write-Verbose -Message "DNS Zone Name is set to $DNSZoneName"

$ComputersSearchOUDN = (Get-ADOrganizationalUnit -Filter 'Name -like "Computers"' | 
                       Select-Object -Property DistinguishedName | 
                       Write-Output).DistinguishedName
Write-Verbose -Message "Computer Search OU is set to $ComputersSearchOUDN"

# All Computers in AD that are not members of the COMP_Multiuser group.
$Computers = Get-ADComputer -Filter * -SearchBase $ComputersSearchOUDN -Properties * | 
             Where-Object {($_.MemberOf | 
             Get-ADGroup).Name -notlike "COMP_Multiuser"}

# Loops through all Computers in AD and adds CNAME entry in DNS
# Checks if there is stale or existing entries
foreach ($Computer in $Computers){
    $User = (Get-ADUser $Computer.ManagedBy | 
            Select-Object -ExpandProperty SamAccountName).toLower()
    $ComputerHN = $Computer.DNSHostName
    $SubName = $Computer | Select-Object -ExpandProperty DistinguishedName
    $SubName = $SubName.split(",",2)[1]
    $SubName = $SubName.split(",")[0]
    $SubName = ($SubName.trim("OU'=")).toLower()
    $MatchDNSEntries = Get-DnsServerResourceRecord -ZoneName $DNSZoneName -ErrorAction SilentlyContinue |
                       Where-Object {$_.HostName -match "$User.$Subname" -and $_.RecordData.HostNameAlias -eq "$ComputerHN."}
    $StaleDNSEntries = Get-DnsServerResourceRecord -ZoneName $DNSZoneName -ErrorAction SilentlyContinue | 
                       Where-Object {$_.HostName -notmatch "$User.$Subname" -and $_.RecordData.HostNameAlias -eq "$ComputerHN."}
    
    if ([bool]$MatchDNSEntries -eq $true -and [bool]$StaleDNSEntries -eq $true){
        Write-Verbose -Message "Stale CNAME entries exist for $ComputerHN"
            foreach ($StaleDNSEntry in $StaleDNSEntries){
                $StaleUser = $StaleDNSEntry.Hostname
                Write-Verbose -Message "Removing alias $StaleUser for $ComputerHN"
                Remove-DnsServerResourceRecord -ZoneName $DNSZoneName -InputObject $StaleDNSEntry -Force
            }
        Write-Verbose -Message "CNAME entry exists: $User.$SubName.$DNSZoneName is an alias for $ComputerHN"
        }
    elseif ([bool]$MatchDNSEntries -eq $true -and [bool]$StaleDNSEntries -eq $false){
        Write-Verbose -Message "CNAME entry exists: $User.$SubName.$DNSZoneName is an alias for $ComputerHN"
        }
    elseif ([bool]$MatchDNSEntries -eq $false -and [bool]$StaleDNSEntries -eq $true){
            foreach ($StaleDNSEntry in $StaleDNSEntries){
                $StaleUser = $StaleDNSEntry.Hostname
                Write-Verbose -Message "Removing alias $StaleUser for $ComputerHN"
                Remove-DnsServerResourceRecord -ZoneName $DNSZoneName -InputObject $StaleDNSEntry -Force
            }
        Write-Verbose -Message "CNAME entry created: $User.$SubName.$DNSZoneName is an alias for $ComputerHN"
        Add-DnsServerResourceRecordCName -Name "$User.$SubName" -HostNameAlias "$ComputerHN." -ZoneName "$DNSZoneName"
        }
    else {
        Write-Verbose -Message "CNAME entry created: $User.$SubName.$DNSZoneName is an alias $ComputerHN"
        Add-DnsServerResourceRecordCName -Name "$User.$SubName" -HostNameAlias "$ComputerHN." -ZoneName "$DNSZoneName"
        }
    }

# Remove any orphaned CNAME entries that are no longer in AD
$ComputersHN = $Computers.DNSHostName
$FQDNTarget = $ComputersHN | ForEach-Object {$_ + "."} | Out-String

$OrphanedDNSEntries = Get-DnsServerResourceRecord -ZoneName $DNSZoneName -RRType CName -ErrorAction SilentlyContinue |
                      Where-Object {
                        $FQDNTarget -notmatch $_.RecordData.HostNameAlias.ToString() -and (
                        $_.HostName -like "*.workstation" -or
                        $_.HostName -like "*.laptop"
                        )
                      } 

if ([bool]$OrphanedDNSEntries -eq $true) {
    foreach ($OrphanedEntry in $OrphanedDNSEntries){
    $OrphanedHN = $OrphanedEntry.HostName
    $OrphanedRD = $OrphanedEntry.RecordData.HostNameAlias.ToString()
    Write-Verbose -Message "Removing Orphaned Entry: $OrphanedHN for $OrphanedRD"
    Remove-DnsServerResourceRecord -ZoneName $DNSZoneName -InputObject $OrphanedEntry -Force
    }
}
else {
    Write-Verbose -Message "No Orphaned entries detected at this time."
}