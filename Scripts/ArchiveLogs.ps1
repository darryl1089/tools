param(
    [Parameter(Mandatory=$true)]
    [string]
    $ArchiveLocation,
    [Parameter(Mandatory=$true)]
    [int]
    $NumberOfDaysToArchive,
    [Parameter(Mandatory=$true)]
    [string[]]
    $LogLocations,
    [Parameter(Mandatory=$true)]
    [string]
    $LogFileTypes,
    [Parameter(Mandatory=$false)]
    [bool]
    $WhatIfEnabled = $false
)

try{
    $WhatIfPreference = $WhatIfEnabled

    $today = Get-Date
    $archiveStartDate = $today.AddDays(-$NumberOfDaysToArchive)
    $archiveEndDate = $today.AddDays(-1)

    $archiveFolderName = $archiveStartDate.ToString("yyyy-MM-dd") + "_" + $archiveEndDate.ToString("yyyy-MM-dd")

    If (!(Test-Path -Path (Join-Path $ArchiveLocation $archiveFolderName))) 
    {
        Write-Host "Creating archive folder $archiveFolderName at $ArchiveLocation"
        New-Item -Path $ArchiveLocation -Name $archiveFolderName -ItemType "directory"
    }

    Foreach ($path in $LogLocations)
    {
        Set-Location $path

        Write-Host "Archiving log files in $path older than $NumberOfDaysToArchive days with file types $LogFileTypes" 
        $logFiles = Get-ChildItem -Attributes !Directory $path | Where-Object { $_.LastWriteTime -gt $archiveStartDate -and $_.LastWriteTime -lt $archiveEndDate `
            -and $_.Extension -in $LogFileTypes }
        
        if($null -ne $logFiles)
        {
            Write-Host "Log files to archive:"
            $logFiles | ForEach-Object {Write-Host $_.Name}

            $zipFolderName = (Split-Path $path -Leaf) + ".zip"
            $zipFolderPath = Join-Path $ArchiveLocation -ChildPath $archiveFolderName | Join-Path -ChildPath $zipFolderName

            if($WhatIfPreference -eq $true){
                Write-Host "WhatIf: Compress-Archive will either create or update a .zip with the following files $logFiles"
            }
            else 
            {
                If(Test-Path $zipFolderPath)
                {
                    Write-Host "Archive $zipFolderPath already exists. Updating archive"
                    Compress-Archive $logFiles -DestinationPath $zipFolderPath -Update
                    Write-Host "Archive update completed"
                }
                else
                {   Write-Host "Creating archive $zipFolderPath"
                    Compress-Archive $logFiles -DestinationPath $zipFolderPath
                    Write-Host "Archive created"
                } 
            }

            Write-Host "Deleting archived log files"
            Remove-Item -Path $logFiles -Verbose
        }
        else
        {
            Write-Host "No log files found!" -ForegroundColor Red
        }
    }
}
catch{
    Write-Error "An error occurred. Please see the error below:"
    Write-Error $_.Exception
    Write-Error $_.ScriptStackTrace
}