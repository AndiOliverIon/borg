# PowerShell script to download SQL Server Docker images based on input versions and create a container
param()

. "$env:BORG_ROOT\config\globalfn.ps1"

# Image used for sql server, for now always 2022


# Function to create a Docker container
function CreateSqlDockerContainer {
    param (
        [string]$ImageTag,
        [string]$ContainerName,
        [int]$HostPort
    )

    Write-Host "Creating Docker container: $ContainerName on port $HostPort from image: $ImageTag..." -ForegroundColor Cyan
    try {
        docker run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=$SqlPassword" -p "2022:$HostPort" --name "$ContainerName" --user root -d $ImageTag  
        Write-Host "Successfully created container: $ContainerName on port $HostPort" -ForegroundColor Green    
    }
    catch {
        Write-Host "Failed to create container: $ContainerName. Error: $_" -ForegroundColor Red
    }
}

CreateSqlDockerContainer -ImageTag $ImageTag -ContainerName $ContainerName -HostPort $HostPort

Write-Host("Create backup folder on $ContainerName")
docker exec $ContainerName mkdir -p $dockerBackupPath

Write-Host("Upload needed files")
docker cp "$dockerSqlFilesFolder\restore_database.sh" "$($dockerContainerName):$dockerBackupPath"
# docker cp "$dockerSqlFilesFolder\restore_database_mdf.sh" "$($dockerContainerName):$dockerBackupPath"
# docker cp "$dockerSqlFilesFolder\optimize_database.sh" "$($dockerContainerName):$dockerBackupPath"

# Giving rights to executables
$chmodCommand = "chmod +x $dockerBackupPath/restore_database.sh"
Write-Host "Making the script executable: $chmodCommand" -ForegroundColor Yellow
docker exec $ContainerName bash -c $chmodCommand