param(
  [Parameter(Mandatory = $true)][string]$Query,
  [string]$OutFile = "$env:TEMP\serp.html",
  [string]$Engine = "bing"
)
$ErrorActionPreference = "Continue"
$edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
$q = [uri]::EscapeDataString($Query)
switch ($Engine) {
  "bing"   { $url = "https://www.bing.com/search?q=$q&ensearch=1&mkt=en-US" }
  "baidu"  { $url = "https://www.baidu.com/s?wd=$q" }
  default  { $url = "https://www.bing.com/search?q=$q" }
}
& $edge --headless=new --disable-gpu --no-sandbox --user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36 Edg/139.0.0.0" --dump-dom --virtual-time-budget=10000 $url 2>$null | Out-File -FilePath $OutFile -Encoding utf8
$html = Get-Content $OutFile -Raw
if ([string]::IsNullOrWhiteSpace($html)) { Write-Output "EMPTY_RESPONSE"; exit 1 }

function Decode-BingUrl([string]$u) {
  $u = [System.Net.WebUtility]::HtmlDecode($u)
  if ($u -match 'u=a1([A-Za-z0-9+/=_-]+)') {
    $b = $matches[1].Replace('-', '+').Replace('_', '/')
    while ($b.Length % 4) { $b += '=' }
    try { return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b)) } catch {}
  }
  return $u
}

if ($Engine -eq "baidu") {
  $ms = [regex]::Matches($html, '<h3[^>]*>\s*<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>')
} else {
  $ms = [regex]::Matches($html, '<h2[^>]*><a[^>]*href="([^"]+)"[^>]*>(.*?)</a></h2>')
}
$n = 0
foreach ($m in $ms) {
  $t = [System.Net.WebUtility]::HtmlDecode(($m.Groups[2].Value -replace '<[^>]+>', ''))
  $u = if ($Engine -eq "bing") { Decode-BingUrl $m.Groups[1].Value } else { [System.Net.WebUtility]::HtmlDecode($m.Groups[1].Value) }
  Write-Output ("[" + $n + "] " + $t)
  Write-Output ("     " + $u)
  $n++
}
# 摘要文本
$sns = [regex]::Matches($html, 'class="b_caption"[^>]*>.*?<p[^>]*>(.*?)</p>', 'Singleline')
$i = 0
foreach ($s in $sns) {
  $txt = [System.Net.WebUtility]::HtmlDecode(($s.Groups[1].Value -replace '<[^>]+>', ''))
  Write-Output ("SNIP[$i]: " + $txt)
  $i++
}
