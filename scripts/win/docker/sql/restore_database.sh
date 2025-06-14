#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🗃️ Robust SQL Server .bak restore script (inside container)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

BACKUP_FILE="$1"
SA_PASSWORD="$2"
PROPOSED_DATABASE_NAME="$3"

SQLCMD="/opt/mssql-tools18/bin/sqlcmd"
BACKUP_PATH="/var/opt/mssql/backup/$BACKUP_FILE"
DATA_PATH="/var/opt/mssql/data"
SQL_FILE="/tmp/restore_script.sql"

if [[ -z "$BACKUP_FILE" || -z "$SA_PASSWORD" ]]; then
    echo "Usage: $0 <backup_file> <sa_password> [proposed_database_name]"
    exit 1
fi

if [[ ! -f "$BACKUP_PATH" ]]; then
    echo "  Backup file not found: $BACKUP_PATH"
    exit 1
fi

# Determine final database name
DB_NAME="${PROPOSED_DATABASE_NAME:-${BACKUP_FILE%%.*}}"

echo "  Preparing SQL restore script for database: $DB_NAME"

# Generate the restore SQL script
cat >"$SQL_FILE" <<EOF
-- 🛑 Kill existing connections
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = N'$DB_NAME')
BEGIN
    EXEC('ALTER DATABASE [$DB_NAME] SET SINGLE_USER WITH ROLLBACK IMMEDIATE');
END

DECLARE @backupFile NVARCHAR(MAX) = N'$BACKUP_PATH';
DECLARE @dbName NVARCHAR(MAX) = N'$DB_NAME';
DECLARE @dataPath NVARCHAR(MAX) = N'$DATA_PATH';
DECLARE @sql NVARCHAR(MAX) = N'RESTORE DATABASE [' + @dbName + N'] FROM DISK = ''' + @backupFile + N''' WITH ';

DECLARE @files TABLE (
    LogicalName NVARCHAR(128),
    PhysicalName NVARCHAR(260),
    Type CHAR(1),
    FileGroupName NVARCHAR(128),
    Size BIGINT,
    MaxSize BIGINT,
    FileId INT,
    CreateLSN NUMERIC(25,0),
    DropLSN NUMERIC(25,0),
    UniqueId UNIQUEIDENTIFIER,
    ReadOnlyLSN NUMERIC(25,0),
    ReadWriteLSN NUMERIC(25,0),
    BackupSizeInBytes BIGINT,
    SourceBlockSize INT,
    FileGroupId INT,
    LogGroupGUID UNIQUEIDENTIFIER,
    DifferentialBaseLSN NUMERIC(25,0),
    DifferentialBaseGUID UNIQUEIDENTIFIER,
    IsReadOnly BIT,
    IsPresent BIT,
    TDEThumbprint VARBINARY(32),
    SnapshotUrl NVARCHAR(360)
);

INSERT INTO @files
EXEC('RESTORE FILELISTONLY FROM DISK = ''' + @backupFile + '''');

SELECT @sql += STRING_AGG(
    'MOVE N''' + LogicalName + ''' TO N''' + @dataPath + '/' +
    REPLACE(LogicalName, ' ', '_') + 
    CASE WHEN Type = 'D' THEN '.mdf' ELSE '.ldf' END + '''', ', ')
FROM @files;

SET @sql += ', RECOVERY, REPLACE, NOUNLOAD, STATS = 5';

PRINT '  Executing SQL:';
PRINT @sql;
EXEC (@sql);

--   Revert to multi-user
EXEC('ALTER DATABASE [' + @dbName + '] SET MULTI_USER');
EOF

# Execute the SQL script using encryption trust override
echo "  Restoring database..."
$SQLCMD -S localhost -U sa -P "$SA_PASSWORD" -C -N -i "$SQL_FILE"

if [[ $? -eq 0 ]]; then
    echo "  Database '$DB_NAME' restored successfully."
    exit 0
else
    echo "  Restore failed."
    exit 1
fi
