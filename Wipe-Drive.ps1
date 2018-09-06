<#
.SYNOPSIS
Wipe all data on a drive
.DESCRIPTION
Wipe all data ona drive by writting over each bit of the drive, zeroing the drive
.PARAMETER DiskNumber
Number of the disk that is to wipped
.PARAMETER NumberOfPasses
The number of times the disk is to be zeroed. 3 passes is considred to be secure
.PARAMETER Force
Forces the drive to be wipped with out conformation of the action
.EXAMPLE 
Wipe-Drive -DiskNumber 1 -NumberOfPasses 3 -force
Forecs the drive to be wiped 3 times
.NOTES
Written by Kris Grss (contact@mosaicmk.com)
Contact: Contact@MosaicMK.com
Version 1.0.0.0
.LINK
https://www.mosaicmk.com
#>

[CmdletBinding()]
PARAM(
    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName)]
    [Alias("Disk","DriveNumber","Drive")]
    [String]$DiskNumber,
    [Parameter(Mandatory=$true)]
    [int]$NumberOfPasses,
    [switch]$Force
)

If (!($Force)) {
    $Con = Read-Host "Are you sure you want to wipe all data off disk $DiskNumber. (Y,N)"
    If ($Con -like "N") {Exit 0}
}

If (!((Get-WmiObject win32_DiskDrive | Where-Object -Property Index -eq $DiskNumber).Model -eq "Microsoft Virtual Disk")) {Clear-Disk -Number $DiskNumber -RemoveData -RemoveOEM -Confirm:$false | Out-Null}Else {
    $NumberOFParts = (Get-Partition -DiskNumber $DiskNumber).PartitionNumber
    foreach ($Item in $NumberOFParts){
        Remove-Partition -DiskNumber $DiskNumber -PartitionNumber $Item -Confirm:$False
    }
}

$CDROM = (Get-Volume | Where-Object -Property DriveType -eq "CD-ROM").DriveLetter
$CDROM = $CDROM + ":"
$TempLetter = Get-ChildItem function:[d-z]: -n | Where-Object{ !(test-path $_) -and ($_ -ne $CDROM)} | Random
$TempLetterTemp = $TempLetter.Trim(":"," ")
$TempLetterPath = $TempLetter + "\"
New-Partition -DiskNumber $DiskNumber -UseMaximumSize -DriveLetter $TempLetterTemp | Out-Null
Format-Volume -DriveLetter $TempLetterTemp -FileSystem NTFS -NewFileSystemLabel "CleanedDisk" -Force -Confirm:$False | Out-Null
$FilePath = $TempLetterPath + "ZeroFile.tmp"
$Volume = Get-WmiObject win32_volume | Where-Object -Property Name -EQ $TempLetterPath

$PassCount = 0

Function Zero-Disk{
    if($Volume) {
        $PassCount++
        IF (Test-Path $FilePath) {Remove-Item $FilePath -Force}
        $ArraySize = 64kb
        $SpaceToLeave = $Volume.Capacity * 0.05
        $FileSize = $Volume.FreeSpace - $SpacetoLeave
        $ZeroArray = new-object byte[]($ArraySize)
        $Stream = [io.File]::OpenWrite($FilePath)
        $FileInGB = $([math]::Round($FileSize/1GB,3))
        try {
            $CurFileSize = 0
            while($CurFileSize -lt $FileSize) 
            {
                $Stream.Write($ZeroArray,0, $ZeroArray.Length)
                $CurFileSize += $ZeroArray.Length
                $CurFileSizeInGb = $([math]::Round($CurFileSize/1GB,3))
                # start-sleep -Milliseconds 25
                Write-Progress "Wiping Disk $DiskNumber at $TempLetterPath, Pass Number $Passcount of $NumberOFPasses" -Status "$CurFileSizeInGB GB of $FileInGB GB" -PercentComplete ($CurFileSize / $FileSize*100)
            }
        } finally {
            Check_Count
            if($Stream) {$Stream.Close()}
            Start-Sleep -Seconds 10
            if((Test-Path $FilePath)) {Remove-Item $FilePath -Force}
            Remove-PartitionAccessPath -DiskNumber $DiskNumber -PartitionNumber 1 -AccessPath $TempLetterPath -Confirm:$false | Out-Null
        }
    } 
}

Function Check_Count{IF ($PassCount -le $NumberOfPasses) {Zero-Disk} else {Write-Host "Complete"}}
Check_Count
