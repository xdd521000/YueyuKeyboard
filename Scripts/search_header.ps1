param(
    [Parameter(Mandatory = $true)][string]$Keyword,
    [string]$ZipPath = "D:\gpt.ggit\QQ9.3.35版本头文件-20260819-2154.zip",
    [int]$Top = 50
)
# 在 QQ 头文件压缩包里按关键字搜索类名（不解压，快）
$ErrorActionPreference = "Stop"
if (-not (Test-Path $ZipPath)) { Write-Error "压缩包不存在: $ZipPath"; exit 1 }
$list = tar -tf $ZipPath
$list | Where-Object { $_ -match $Keyword -and $_ -notmatch '^__Tt|^_Tt' } | Select-Object -First $Top