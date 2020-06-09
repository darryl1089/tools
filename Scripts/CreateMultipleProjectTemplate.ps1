param (
    [Parameter(Mandatory=$true)]
    [string]$RootTemplateDirectory,
    [Parameter(Mandatory=$true)]
    [string]$ParentTemplateFileName,
    [Parameter(Mandatory=$true)]
    [string]$WebTemplateDirectory,
    [Parameter(Mandatory=$true)]
    [string]$WebProjectDirectory,
    [Parameter(Mandatory=$true)]
    [string]$WebProjectNamespace,
    [Parameter(Mandatory=$true)]
    [string]$TestTemplateDirectory,
    [Parameter(Mandatory=$true)]
    [string]$TestProjectDirectory,
    [Parameter(Mandatory=$true)]
    [string]$TestProjectNamespace,
    [Parameter(Mandatory=$true)]
    [string]$ZipFolderName

)
#The script will need to be run in the root of the VS Soultion
#Global Vars
$CurrentLocaction = Get-Location

#Create Multiple Project Template Directory
Write-Host "Creating Multiple Project Template Root Directory" -ForegroundColor Green
mkdir $RootTemplateDirectory

#Copy TemplateIcon to RootTemplateDirectory

Write-Host "Copying TemplateIcon.png to $CurrentLocaction\$RootTemplateDirectory" -ForegroundColor Green
Copy-Item "TemplateIcon.png" -Destination "$CurrentLocaction\$RootTemplateDirectory"

#Copy Parent Template to RootTemplateDirectory
Write-Host "Copying $ParentTemplateFileName to $CurrentLocaction\$RootTemplateDirectory" -ForegroundColor Green
Copy-Item "$ParentTemplateFileName" -Destination "$CurrentLocaction\$RootTemplateDirectory"

#Copy Web project files and folders to $WebTemplateDirectory 
Write-Host "Copying files and folders from $WebProjectDirectory to $RootTemplateDirectory\$WebTemplateDirectory" -ForegroundColor Green
Copy-Item -Path $WebProjectDirectory -Destination $RootTemplateDirectory\$WebTemplateDirectory -Recurse

#Copy Test project files and folders to $TestTemplateDirectory 
Write-Host "Copying files and folders from $TestProjectDirectory to $RootTemplateDirectory\$TestTemplateDirectory" -ForegroundColor Green
Copy-Item -Path $TestProjectDirectory -Destination $RootTemplateDirectory\$TestTemplateDirectory -Recurse

#Perform Namespace Tempalte Variable Replacments For Web Project
Write-Host "Replacing $WebProjectNamespace with template variable `$safeprojectname$ in $WebTemplateDirectory" -ForegroundColor Green
cd $RootTemplateDirectory\$WebTemplateDirectory
$files = Get-ChildItem . -File -Recurse -Exclude *.vstemplate
foreach ($file in $files)
{
    (Get-Content $file.PSPath) |
    ForEach-Object {$_ -replace $WebProjectNamespace, "`$safeprojectname$" } |
    Set-Content $file.PSPath
}

#Perform Namespace Tempalte Variable Replacments For Test Project
Write-Host "Replacing $TestProjectNamespace with template variable `$safeprojectname$ in $TestTemplateDirectory" -ForegroundColor Green
cd $CurrentLocaction\$RootTemplateDirectory\$TestTemplateDirectory
$files = Get-ChildItem . -File -Recurse -Exclude *.vstemplate
foreach ($file in $files)
{
    (Get-Content $file.PSPath) |
    ForEach-Object {$_ -replace $TestProjectNamespace, "`$safeprojectname$" } |
    Set-Content $file.PSPath
}

#Perform Namespace Tempalte Variable Replacments For Test Project For Web Project Refrences
Write-Host "Replacing $WebProjectNamespace with template variable `$ext_safeprojectname$.Web in $TestTemplateDirectory" -ForegroundColor Green
$files = Get-ChildItem . -File -Recurse -Exclude *.vstemplate
foreach ($file in $files)
{
    (Get-Content $file.PSPath) |
    ForEach-Object {$_ -replace $WebProjectNamespace, "`$ext_safeprojectname$.Web" } |
    Set-Content $file.PSPath
}

#Create Zip Archive For Template
Write-Host "Archiving $RootTemplateDirectory to $ZipFolderName.zip" -ForegroundColor Green
cd $CurrentLocaction
Compress-Archive -Path $CurrentLocaction\$RootTemplateDirectory\* -DestinationPath $CurrentLocaction\$ZipFolderName.zip