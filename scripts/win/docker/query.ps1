# Powershell script to immediate query on a database without the use of management.
# This I will use only when I need to query something simple just to have a glance at it.
param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
    [string]$query
)

. "$env:BORG_ROOT\config\globalfn.ps1"

# Connection string
$connectionString = "Server=$SqlInstance;Database=$SqlUseDatabase;User ID=$SqlUser;Password=$SqlPassword;"
$connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)

try {
    $connection.Open()
    Write-Host "Connection opened successfully." -ForegroundColor Green

    $command = $connection.CreateCommand()
    $command.CommandText = $query

    $reader = $command.ExecuteReader()

    # Fetch column names
    $columns = @()
    for ($i = 0; $i -lt $reader.FieldCount; $i++) {
        $columns += $reader.GetName($i)
    }

    # Fetch data rows
    $data = @()
    while ($reader.Read()) {
        $row = @{}
        for ($i = 0; $i -lt $reader.FieldCount; $i++) {
            $row[$columns[$i]] = $reader.GetValue($i)
        }
        $data += [PSCustomObject]$row
    }

    $reader.Close()

    if ($data.Count -eq 0) {
        Write-Host "Query executed successfully but returned no results." -ForegroundColor Yellow
    }
    else {
        $data | Format-Table -AutoSize | Out-String | Write-Host
    }
}
catch {
    Write-Host "Error executing query: $_" -ForegroundColor Red
}
finally {
    $connection.Close()
    Write-Host "Connection closed." -ForegroundColor Green
}
