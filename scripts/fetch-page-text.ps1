param([Parameter(Mandatory=$true)][string]$Url, [int]$Max = 3000)
$edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
if (-not (Test-Path $edge)) { $edge = "C:\Program Files\Microsoft\Edge\Application\msedge.exe" }
$out = Join-Path $env:TEMP ("page-" + [guid]::NewGuid().ToString("n") + ".html")
& $edge --headless=new --disable-gpu --no-sandbox `
  --user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36 Edg/139.0.0.0" `
  --dump-dom --virtual-time-budget=9000 $Url 2>$null | Out-File -FilePath $out -Encoding utf8
$html = Get-Content $out -Raw
Remove-Item $out -ErrorAction SilentlyContinue
if ([string]::IsNullOrWhiteSpace($html)) { Write-Output "EMPTY"; exit 1 }
$t = $html -replace '(?s)<script[\s\S]*?</script>', ' '
$t = $t -replace '(?s)<style[\s\S]*?</style>', ' '
$t = $t -replace '<[^>]+>', ' '
$t = [System.Net.WebUtility]::HtmlDecode($t)
$t = $t -replace '\s+', ' '
if ($t.Length -gt $Max) { $t.Substring(0, $Max) } else { $t }
