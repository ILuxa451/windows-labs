param(
    [string]$ComputerName = "localhost",
    [string]$ReportPath = "C:\health-report-$(Get-Date -Format 'yyyy-MM-dd').html"
)

if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Скрипт запущен без прав администратора. Некоторые данные могут быть недоступны."
}

Write-Host "Начинаю аудит сервера: $ComputerName..." -ForegroundColor Cyan

$StoppedServices = Get-Service -ComputerName $ComputerName -ErrorAction SilentlyContinue | 
    Where-Object { $_.Status -eq 'Stopped' -and $_.StartType -eq 'Automatic' } | 
    Select-Object Name, DisplayName, Status, StartType

$TopProcesses = Get-Process -ComputerName $ComputerName -ErrorAction SilentlyContinue | 
    Sort-Object WS -Descending | 
    Select-Object -First 5 Name, @{Name="Memory(MB)";Expression={[math]::Round($_.WS / 1MB, 2)}}, CPU

$CriticalEvents = Get-WinEvent -ComputerName $ComputerName -FilterHashtable @{LogName='System'; Level=1} -MaxEvents 10 -ErrorAction SilentlyContinue | 
    Select-Object TimeCreated, ProviderName, Message

$DiskSpace = Get-WmiObject -Class Win32_LogicalDisk -ComputerName $ComputerName -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue | 
    Select-Object DeviceID, @{Name="FreeSpace(GB)";Expression={[math]::Round($_.FreeSpace / 1GB, 2)}}, @{Name="TotalSpace(GB)";Expression={[math]::Round($_.Size / 1GB, 2)}}

$HTML = @"
<html>
<head>
<style>
    body { font-family: Arial, sans-serif; background-color: #f4f4f4; padding: 20px; }
    h1 { color: #333; }
    h2 { color: #005a9e; border-bottom: 1px solid #ccc; padding-bottom: 5px; }
    table { border-collapse: collapse; width: 100%; margin-bottom: 20px; background: #fff; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
    th { background-color: #005a9e; color: white; }
    tr:nth-child(even) { background-color: #f2f2f2; }
</style>
</head>
<body>
    <h1>Отчет о состоянии сервера: $ComputerName</h1>
    <p>Дата формирования: $(Get-Date)</p>
    
    <h2>1. Остановленные службы (с автозапуском)</h2>
    $(if ($StoppedServices) { $StoppedServices | ConvertTo-Html -Fragment } else { "<p style='color:green'>Все службы работают штатно.</p>" })
    
    <h2>2. Топ-5 процессов по памяти</h2>
    $(if ($TopProcesses) { $TopProcesses | ConvertTo-Html -Fragment } else { "<p>Нет данных.</p>" })
    
    <h2>3. Последние 10 критических ошибок (System)</h2>
    $(if ($CriticalEvents) { $CriticalEvents | ConvertTo-Html -Fragment } else { "<p style='color:green'>Критических ошибок не найдено.</p>" })
    
    <h2>4. Место на диске C:</h2>
    $(if ($DiskSpace) { $DiskSpace | ConvertTo-Html -Fragment } else { "<p>Не удалось получить данные.</p>" })
</body>
</html>
"@

Write-Host "`n--- РЕЗУЛЬТАТЫ АУДИТА ---" -ForegroundColor Green
$StoppedServices | Format-Table -AutoSize
$TopProcesses | Format-Table -AutoSize
$DiskSpace | Format-Table -AutoSize

$HTML | Out-File -FilePath $ReportPath -Encoding UTF8
Write-Host "HTML-отчет успешно сохранен по пути: $ReportPath" -ForegroundColor Green
