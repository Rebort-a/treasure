param(
    [string]$SourceDirectory = ([IO.Path]::Combine($PSScriptRoot, '../temp')),
    [string]$Ffmpeg = 'ffmpeg'
)

$ErrorActionPreference = 'Stop'
# 原生程序的诊断输出单独保存，由退出码判断转换是否成功。
$PSNativeCommandUseErrorActionPreference = $false
$source = [IO.Path]::GetFullPath($SourceDirectory)
$output = [IO.Path]::GetFullPath(
    [IO.Path]::Combine($PSScriptRoot, '../assets/audio/match_praise')
)
$names = @('good', 'great', 'excellent', 'amazing', 'unbelievable', 'bonus')
$encoder = (Get-Command $Ffmpeg -ErrorAction Stop).Source
foreach ($name in $names) {
    if (-not [IO.File]::Exists([IO.Path]::Combine($source, "$name.mp3"))) {
        throw "Missing source recording: $name.mp3"
    }
}

# 只处理首尾静音，不删除词间停顿，也不改变原配音的音高和语速。
$filters = @(
    'aformat=channel_layouts=mono',
    'silenceremove=start_periods=1:start_duration=0.01:start_threshold=-50dB:start_silence=0.02',
    'areverse',
    'silenceremove=start_periods=1:start_duration=0.01:start_threshold=-50dB:start_silence=0.08',
    'afade=t=in:d=0.005',
    'areverse',
    'afade=t=in:d=0.002',
    'loudnorm=I=-18:TP=-1:LRA=9'
) -join ','
$staging = [IO.Path]::Combine(
    [IO.Path]::GetTempPath(), "treasure-match-voice-$([Guid]::NewGuid().ToString('N'))"
)
[IO.Directory]::CreateDirectory($staging) | Out-Null
try {
    $sources = @()
    foreach ($name in $names) {
        $inputFile = [IO.Path]::Combine($source, "$name.mp3")
        $outputFile = [IO.Path]::Combine($staging, "$name.wav")
        $log = [IO.Path]::Combine($staging, "$name.log")
        # 先完成全部转换，失败时不覆盖现有资源。
        # Windows PowerShell 5.1 会将 FFmpeg 的普通诊断输出包装成错误记录。
        try {
            $ErrorActionPreference = 'Continue'
            & $encoder -hide_banner -nostdin -y -i $inputFile `
                -map_metadata -1 -af $filters -ar 44100 -ac 1 -c:a pcm_s16le `
                -fflags +bitexact -flags:a +bitexact $outputFile 2> $log
            $exitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = 'Stop'
        }
        if ($exitCode -ne 0 -or
            -not [IO.File]::Exists($outputFile) -or
            ([IO.FileInfo]$outputFile).Length -le 44) {
            throw "Audio conversion failed for ${name}: $([IO.File]::ReadAllText($log))"
        }
        $sources += [ordered]@{
            source = "$name.mp3"
            sha256 = (Get-FileHash -LiteralPath $inputFile -Algorithm SHA256).Hash.ToLowerInvariant()
            asset = "$name.wav"
        }
        Write-Output "$name.wav"
    }
    $manifest = [ordered]@{
        sourcePage = 'https://www.aigei.com/sound/class/kai_xin_xi_23/'
        format = '44100 Hz / mono / PCM signed 16-bit WAV'
        filters = $filters
        recordings = $sources
    } | ConvertTo-Json -Depth 4
    [IO.File]::WriteAllText(
        [IO.Path]::Combine($staging, 'sources.json'), ($manifest.Replace("`r`n", "`n") + "`n"),
        [Text.UTF8Encoding]::new($false)
    )
    [IO.Directory]::CreateDirectory($output) | Out-Null
    foreach ($file in @($names | ForEach-Object { "$_.wav" }) + @('sources.json')) {
        [IO.File]::Copy(
            [IO.Path]::Combine($staging, $file),
            [IO.Path]::Combine($output, $file), $true
        )
    }
} finally {
    # 仅清理本脚本创建的唯一临时目录中的文件，不递归删除计算路径。
    Get-ChildItem -LiteralPath $staging -File |
        ForEach-Object { Remove-Item -LiteralPath $_.FullName }
    Remove-Item -LiteralPath $staging
}
