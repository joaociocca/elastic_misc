$MGdir = "$env:HOMEDRIVE$env:HOMEPATH\MonitorGEDEC"

New-Item -Path $MGdir -ItemType directory -ErrorAction Ignore 

Set-Location $MGdir
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$7zURI = "https://www.7-zip.org/download.html"
$7z_HTML = Invoke-WebRequest -Uri $7zURI
$7z_downloadLink = ($7z_HTML.ParsedHtml.getElementsByTagName('a') | Where-Object { $_.href -match '7z\d+-x64\.exe$' } | Select-Object -First 1).href -replace "about:","https://www.7-zip.org/"
$7z_exe = ($7z_HTML.ParsedHtml.getElementsByTagName('a') | Where-Object { $_.href -match '7z\d+-x64\.exe$' } | Select-Object -First 1).href -replace "about:a/",""
Invoke-WebRequest -Uri $7z_downloadLink -OutFile $MGdir\$7z_exe
& "$MGdir\$7z_exe" /S /D=$MGdir\7zip-
$7z_dir = "$MGdir\7zip"

Write-Output "Baixando Kibana..."
$Kuri = "https://www.elastic.co/downloads/kibana"
$K_HTML = Invoke-WebRequest -Uri $Kuri
$K_downloadLink = ($K_HTML.ParsedHtml.getElementsByTagName('a') | Where-Object { $_.href -match '\.zip$' }).href
Invoke-WebRequest -Uri $K_downloadLink -OutFile $MGdir\kibana.zip
Write-Output "Instalando Kibana..."
& "$7z_dir\7z.exe" x kibana.zip
Write-Output "Kibana instalado!"

Write-Output "Baixando Elasticsearch..."
$ESuri = "https://www.elastic.co/downloads/elasticsearch"
$ES_HTML = Invoke-WebRequest -Uri $ESuri
$ES_downloadLink = ($ES_HTML.ParsedHtml.getElementsByTagName('a') | Where-Object { $_.href -match '\.zip$' }).href
Invoke-WebRequest -Uri $ES_downloadLink -OutFile $MGdir\elasticsearch.zip
Write-Output "Instalando Elasticsearch..."
& "$7z_dir\7z.exe" x elasticsearch.zip
Write-Output "Elasticsearch instalado!"

Write-Output "Baixando Metricbeat..."
$MBuri = "https://www.elastic.co/downloads/beats/metricbeat"
$MB_HTML = Invoke-WebRequest -Uri $MBuri
$MB_downloadLink = ($MB_HTML.ParsedHtml.getElementsByTagName('a') | Where-Object { $_.href -match '64\.zip$' }).href
Invoke-WebRequest -Uri $MB_downloadLink -OutFile $MGdir\metricbeat.zip
Write-Output "Instalando Metricbeat..."
& "$7z_dir\7z.exe" x metricbeat.zip
Write-Output "Metricbeat instalado!"

Remove-Item -Path $MGdir\*.zip
Remove-Item -Path $MGdir\*.exe
Remove-Item -Path $MGDir\7zip -Recurse -Force

Get-Childitem -Directory | ForEach-Object {
  $a=$_.Name
  $b=$a -replace "-.*$",""
  If ($a -ne $b) { Rename-Item $a $b }
}

Write-Output "Iniciando o Elasticsearch..."
Start-Process -WindowStyle Hidden $MGDir\elasticsearch\bin\elasticsearch.bat

$KibanaConfig = "$MGDir\kibana\config\kibana.yml"
(Get-Content $KibanaConfig).replace('#elasticsearch.url','elasticsearch.url') | Set-Content $KibanaConfig
Write-Output "Iniciando o Kibana..."
Start-Process -WindowStyle Hidden $MGDir\kibana\bin\kibana.bat

$MetricbeatConfig = "$MGDir\metricbeat\metricbeat.yml"
(Get-Content $MetricbeatConfig).replace('#setup.dashboards.enabled: false','setup.dashboards.enabled: true') | Set-Content $MetricbeatConfig
(Get-Content $MetricbeatConfig).replace('#host: "localhost:5601"','host: "localhost:5601"') | Set-Content $MetricbeatConfig
(Get-Content $MetricbeatConfig).replace('#hosts: "localhost:9200"','hosts: "localhost:9200"') | Set-Content $MetricbeatConfig

$AddConfig = @'
metricbeat.modules:
  - module: system
    metricsets:
      - cpu             # CPU usage
      - filesystem      # File system usage for each mountpoint
      - fsstat          # File system summary metrics
      #- load            # CPU load averages
      - memory          # Memory usage
      - network         # Network IO
      - process         # Per process metrics
      - process_summary # Process summary
      - uptime          # System Uptime
      #- core           # Per CPU core usage
      #- diskio         # Disk IO
      #- raid           # Raid
      #- socket         # Sockets and connection info (linux only)
    enabled: true
    period: 10s
    processes: ['.*']

    # Configure the metric types that are included by these metricsets.
    cpu.metrics:  ["percentages"]  # The other available options are normalized_percentages and ticks.
    core.metrics: ["percentages"]  # The other available option is ticks.
'@

Add-Content $MetricbeatConfig $AddConfig

Write-Output "Iniciando o Metricbeat..."
  Start-Process -WindowStyle Hidden $MGDir\metricbeat\metricbeat.exe -WorkingDirectory $MGDir\metricbeat

@'
Get-Process | Where-Object { $_.Name -eq "metricbeat" } | Stop-Process
Get-Process | Where-Object { $_.Name -eq "java" } | Stop-Process
Get-Process | Where-Object { $_.Name -eq "node" } | Stop-Process
'@
