param(
    [Parameter(Mandatory = $true)][string]$Keyword,
    [string]$ZipPath = "D:\gpt.ggit\QQ9.3.35版本头文件-20260819-2154.zip",
    [string]$OutDir = "References\QQ9.3.35-extracted"
)
# 把匹配关键字的所有头文件从压缩包解压到 OutDir
$ErrorActionPreference = "Stop"
if (-not (Test-Path $ZipPath)) { Write-Error "压缩包不存在: $ZipPath"; exit 1 }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$names = @(tar -tf $ZipPath | Where-Object { $_ -match $Keyword })
if ($names.Count -eq 0) { Write-Output "未找到匹配 '$Keyword' 的头文件"; exit 0 }
$names | ForEach-Object { tar -xf $ZipPath -C $OutDir $_ }
Write-Output "已解压 $($names.Count) 个文件到 $OutDir"