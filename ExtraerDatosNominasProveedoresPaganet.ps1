#variables de entorno
$Server   = "BND-BKP2.ni.lafise.corp"
$Database = "Tailored_ICBanking"
$OutputFile = "G:\My Drive\Proyectos\Nominas-paganet\Reporte_Nominas.csv"

$Query = @"
WITH DatosClasificados AS (
    SELECT 
        CASE
            WHEN FeatureId = 40 THEN 'Pago de salarios - Nómina'
            ELSE 'Pago de proveedores - Modulo de Pagos' 
        END AS Titulo, 
        CAST(ExecutedDate AS date) AS Fecha,
        DATEPART(HOUR, ExecutedDate) AS HoraMilitar,
        TaskBatchId
    FROM Tailored_ICBanking.dbo.Tasks
    WHERE FeatureId IN (40, 50)
        AND TaskAction IN ('Bulk_SalaryPayments_ExecuteBusiness', 'Bulk_SuppliersPayments_ExecuteBusiness')
        AND CAST(ExecutedDate AS date) = '2026-08-14' -- Ojo aquí para el futuro
    UNION ALL
    SELECT 
        CASE 
            WHEN R.FeatureId = 38 THEN 'Pago de salarios - Desde archivo por lotes'
            WHEN R.FeatureId = 78 THEN 'Transferencias múltiples'
            WHEN R.FeatureId = 1005 THEN 'Pago de nómina'
            WHEN R.FeatureId = 1006 THEN 'Pago de proveedores' 
            ELSE 'Paganet' 
        END AS Titulo, 
        CAST(R.ExecutedDate AS date) AS Fecha,
        DATEPART(HOUR, R.ExecutedDate) AS HoraMilitar,
        R.TaskBatchId
    FROM Tailored_ICBanking.dbo.Tasks R 
    INNER JOIN Tailored_ICBanking.dbo.TaskStatus K ON R.StatusId = K.TaskStatusId
    WHERE K.TaskStatusId = 4 
        AND R.FeatureId IN (38, 78, 1005, 1006, 1510, 1513)
        AND CAST(R.ExecutedDate AS date) = '2026-08-14' -- Ojo aquí para el futuro
)
SELECT 
    Titulo,
    Fecha,
    RIGHT('0' + CAST(HoraMilitar AS VARCHAR(2)), 2) + ':00' AS HoraTexto,
    HoraMilitar,
    COUNT(DISTINCT TaskBatchId) AS TotalNominas
FROM DatosClasificados
GROUP BY 
    Titulo,
    Fecha,
    HoraMilitar
ORDER BY 
    Fecha DESC, 
    HoraMilitar ASC, 
    Titulo ASC;
"@



try {
    
    # conexion con la bd

    #$ConnectionString = "Server=$Server;Database=$Database;User Id=$User;Password=$Password;"
    $connectionString = "Server=$Server;Database=$Database;Integrated Security=True;TrustServerCertificate=True;"
    
    Write-Host "Conectando a la base de datos..." -ForegroundColor Cyan
    
    # Crear conexión con la bd
    $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
    $Connection.Open()

    # hacer comando sql
    $Command = $Connection.CreateCommand()
    $Command.CommandText = $Query
    $Command.CommandTimeout = 120 # Segundos antes de que marque error por tardar mucho

    # ejecutar la consulta y cargarla en memoria
    $Reader = $Command.ExecuteReader()
    $DataTable = New-Object System.Data.DataTable
    $DataTable.Load($Reader)

    # cerrar la conexión
    $Connection.Close()

    Write-Host "Consulta ejecutada. Filas obtenidas: $($DataTable.Rows.Count)" -ForegroundColor Cyan

    # exportar los datos a archivo csv
    $DataTable | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
    Write-Host "Datos exportados correctamente a: $OutputFile" -ForegroundColor Green

} catch {
    
    Write-Host "Error al conectar o ejecutar la consulta:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    
    # cerrar la conexión
    if ($Connection -and $Connection.State -eq "Open") { $Connection.Close() }
}