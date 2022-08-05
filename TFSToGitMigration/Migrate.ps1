param (
    [Parameter(Mandatory=$true)]
    [uri]
    $AzureDevOpsBaseUrl,
    [Parameter(Mandatory=$true)]
    [uri]
    $AzureDevOpsBaseGitUrl,
    [Parameter(Mandatory=$true)]
    [uri]
    $GitIgnoreUrl,
    [Parameter(Mandatory=$true)]
    [string]
    $LocalTfsWorkspacePath,
    [Parameter(Mandatory=$true)]
    [string]
    $MigrationFolder,
    [Parameter(Mandatory=$true)]
    [string]
    $TFSRepoPath,
    [Parameter(Mandatory=$true)]
    [string]
    $GitRepoName
)
#region Functions
function EnsurePrerequisitesInstalled {
    Write-Host "Ensuring prerequisites are installed"

    #Check if chocalety is installed, install if not
    if (!(Test-Path -Path "$env:ProgramData\Chocolatey"))
    {
        Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    }
    
    #Check if gittfs is installed, install if not
    $gitTfsChocPackage = choco list -lo | Where-object { $_.ToLower().StartsWith("gittfs".ToLower()) }
    if( $null -eq $gitTfsChocPackage)
    {
        choco install gittfs -y
    }

    #Check if azure-cli is installed, install if not
    $azureCliChocPackage = choco list -lo | Where-object { $_.ToLower().StartsWith("azure-cli".ToLower()) }
    if( $null -eq $azureCliChocPackage)
    {
        choco install azure-cli -y
    }

    # Make `refreshenv` available right away, by defining the $env:ChocolateyInstall
    # variable and importing the Chocolatey profile module.
    $env:ChocolateyInstall = Convert-Path "$((Get-Command choco).Path)\..\.."   
    Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"

    # refreshenv is now an alias for Update-SessionEnvironment
    refreshenv

    #Check AzureDevOps extension for cli, install if not
    $azureDevOpsExtension = az extension list --query "[?name=='azure-devops']"
    if(!($azureDevOpsExtension))
    {
        az extension add --name azure-devops
    }
 
    #Need to check for VS2019 Enterprise throw if not and add to docs.
    if (!(Test-Path -Path "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Enterprise\Common7\Tools\VsDevCmd.bat")){
        throw "Visual Studio 2019 is not installed, please install it and try running the migration again"
    }

    Write-Host "Prerequisites check completed. All prerequisites installed"
}

function PrepareTFSRepoForMigration {
    param(
        [string] $MigrationFolder,
        [string] $AzureDevOpsBaseUrl,
        [string] $TfsRepoPath,
        [string] $GitIgnoreUrl
    )

    Write-Host "Preparing TFS Repo $TfsRepoPath for migration"

    $tfsRepoName = $TfsRepoPath.Split('/')[-1]
    
    Write-Host "Checking $MigrationFolder exists"
    if(!(Test-Path -Path $MigrationFolder))
    {
        Write-Host "Creating $MigrationFolder folder"
        mkdir $MigrationFolder
    }
    else
    {
        Write-Host "$MigrationFolder exists"
    }
    
    #Change to the migration folder
    Set-Location $MigrationFolder

    Write-Host "Cloning TFS repo $TfsRepoPath to $MigrationFolder\$tfsRepoName"

    git tfs clone $AzureDevOpsBaseUrl $TfsRepoPath
    
    Write-Host "Cloning complete"

    if(!(Test-Path -Path "$MigrationFolder\$tfsRepoName"))
    {
        throw "$MigrationFolder\$tfsRepoName does not exist"
    }

    #Change to the cloned TFS repo location
    Set-Location $MigrationFolder\$tfsRepoName

    #Remove TFS specific files
    Write-Host "Removing TFS specific files"
    Get-ChildItem * -include *.vssscc, *.vspscc , .tfignore -Recurse | Remove-Item

    #Clean commits for git
    Write-Host "Cleaning commits"
    git filter-branch -f --msg-filter "sed 's/^git-tfs-id:.*;C\([0-9]*\)$/Changeset:\1/g'" -- --all

    #Add VS git ignore file
    Write-Host "Adding .gitignore file"
    Invoke-WebRequest $GitIgnoreUrl -OutFile .gitignore

    Write-Host "Appling .gitignore"
    git ls-files -ci --exclude-standard | ForEach-Object { git rm --cached "$_" }
}

function MigrateToGit{
    param(
        [string] $AzureDevOpsBaseUrl,
        [string] $AzureDevOpsBaseGitUrl,
        [string] $GitRepoName
    )

    Write-Host "Logging into AzureDevOps"
    az login

    #Set default organization  and project
    az devops configure --defaults organization=$AzureDevOpsBaseUrl project=IT

    Write-Host "Creating Git repo $GitRepoName in AzureDevOps"
    az repos create --name $GitRepoName

    $gitRemoteUrl = $AzureDevOpsBaseGitUrl + $GitRepoName
    Write-Host "Adding git origin remote $gitRemoteUrl"
    git remote add origin $gitRemoteUrl

    Write-Host "Creating intial commit"
    git add .
    git commit -m "Migration from tfs to git"

    Write-Host "Pushing repo to AzureDevOps"
    git push origin master
}

function MarkTFSRepoAsMigrated {
    param (
        [string] $TfsRepoPath,
        [string] $LocalTfsWorkspacePath
    )

    $splitTfsRepoPath = $TfsRepoPath.Split('/')

    #Get the sub path from the tfsRepo i.e. get /DSD/DaveTest from  $/IT/DSD/DaveTest/ConsoleApplication1
    [System.Collections.ArrayList]$subTfsRepoPath = ($splitTfsRepoPath | Where-Object { $_ -notmatch '\$|IT'})
    $subTfsRepoPath.RemoveAt($subTfsRepoPath.Count -1)

    $tfsWorkspaceParentFolderPath = Join-Path $LocalTfsWorkspacePath ($subTfsRepoPath -join "/")

    $currentTfsRepoName = $TfsRepoPath.Split('/')[-1]
    $currentTfsRepoPath = Join-Path $tfsWorkspaceParentFolderPath $currentTfsRepoName

    $migratedTfsRepoName = $currentTfsRepoName + "(Migrated)"
    $migratedTfsRepoPath = Join-Path $tfsWorkspaceParentFolderPath $migratedTfsRepoName

    Write-Host "Renaming $currentTfsRepoName folder to $migratedTfsRepoName"
    
    #Make call to bat file to rename the folder in TFS
    cmd.exe /C "$PSScriptRoot\TFSFolderRename.bat $currentTfsRepoPath $migratedTfsRepoPath $LocalTfsWorkspacePath" 
}

#endregion Functions
try{
    Write-Host "Migration Started"

    EnsurePrerequisitesInstalled
    PrepareTFSRepoForMigration $MigrationFolder $AzureDevOpsBaseUrl $TFSRepoPath $GitIgnoreUrl
    MigrateToGit $AzureDevOpsBaseUrl $AzureDevOpsBaseGitUrl $GitRepoName
    MarkTFSRepoAsMigrated $TFSRepoPath $LocalTfsWorkspacePath

    Write-Host "Migration Complete"

}
catch{
    Write-Error "An error occurred whilst preforming the migration. Please see the error below:"
    Write-Error $_ 
    throw
}