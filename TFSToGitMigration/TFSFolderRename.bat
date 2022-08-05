echo arg1: %1
echo arg2: %2
echo arg3: %3
set CurrentTfsRepoFolderPath=%1
set MigratedTfsRepoFolderPath=%2
set LocalTfsWorkspacePath=%3

cd "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\"

cmd.exe /C ""C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\Common7\Tools\VsDevCmd.bat" && tf vc rename %CurrentTfsRepoFolderPath% %MigratedtfsRepoFolderPath%  & cd /d %LocalTfsWorkspacePath% & tf checkin /comment:"Marked Folder As Migrated To Git""