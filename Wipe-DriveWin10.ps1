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
Wipe-DriveWin10 -DiskNumber 1 -NumberOfPasses 3 -force
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

If ((Get-WmiObject -class Win32_OperatingSystem).Caption -like "Microsoft Windows 7*") {Write-Error "This Script is not compatable with Windows 7" ; Exit 1}

If (!($Force)) {
    $Con = Read-Host "Are you sure you want to wipe all data off disk $DiskNumber. (Y,N)"
    If ($Con -notlike "Y*") {Exit 0}
}

$CDROM = (Get-Volume | Where-Object -Property DriveType -eq "CD-ROM").DriveLetter
$CDROM = $CDROM + ":"
$TempLetter = Get-ChildItem function:[d-z]: -n | Where-Object{ !(test-path $_) -and ($_ -ne $CDROM)} | Get-Random
$TempLetterPath = $TempLetter + "\"
try {
    Clear-Disk -Number $DiskNum -RemoveData -RemoveOEM -Confirm:$false -ErrorAction Stop
    New-Partition -DiskNumber $DiskNum -UseMaximumSize -DriveLetter $Disk -ErrorAction Stop 
    Format-Volume -DriveLetter $Disk -FileSystem NTFS -NewFileSystemLabel "CleanedDisk" -Force -Confirm:$False -InformationAction SilentlyContinue -ErrorAction Stop
} catch {Write-Error "$_" ; exit 1}


$FilePath = $TempLetterPath + "ZeroFile.tmp"
$Volume = Get-Volume -DriveLetter $TempLetterPath -InformationAction SilentlyContinue

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
