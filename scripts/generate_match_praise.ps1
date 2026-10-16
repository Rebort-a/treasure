param(
    [string]$VoiceName = 'Microsoft Zira Desktop'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
$output = [IO.Path]::GetFullPath(
    [IO.Path]::Combine($PSScriptRoot, '../assets/audio/match_praise')
)
[IO.Directory]::CreateDirectory($output) | Out-Null
$speaker = [System.Speech.Synthesis.SpeechSynthesizer]::new()
try {
    # 只接受英文音色，确保切换界面语言后仍播放英文赞美。
    $voice = $speaker.GetInstalledVoices() |
        Where-Object { $_.Enabled -and $_.VoiceInfo.Name -eq $VoiceName -and
            $_.VoiceInfo.Culture.TwoLetterISOLanguageName -eq 'en' } |
        Select-Object -First 1
    if (-not $voice) {
        throw "An English Windows speech voice is required: $VoiceName"
    }
    $speaker.SelectVoice($voice.VoiceInfo.Name)
    $format = [System.Speech.AudioFormat.SpeechAudioFormatInfo]::new(
        22050,
        [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen,
        [System.Speech.AudioFormat.AudioChannel]::Mono
    )
    $phrases = @(
        @{ Name = 'good'; Text = 'Good!'; Pitch = '+7%'; Rate = '+5%' },
        @{ Name = 'great'; Text = 'Great!'; Pitch = '+10%'; Rate = '+3%' },
        @{ Name = 'excellent'; Text = 'Excellent!'; Pitch = '+12%'; Rate = '+5%' },
        @{ Name = 'amazing'; Text = 'Amazing!'; Pitch = '+15%'; Rate = '+3%' },
        @{ Name = 'unbelievable'; Text = 'Unbelievable!'; Pitch = '+18%'; Rate = '+7%' }
    )
    foreach ($phrase in $phrases) {
        $stream = [IO.MemoryStream]::new()
        try {
            $speaker.SetOutputToAudioStream($stream, $format)
            $speaker.SpeakSsml(@"
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US">
  <prosody pitch="$($phrase.Pitch)" rate="$($phrase.Rate)" volume="x-loud">
    <emphasis level="strong">$($phrase.Text)</emphasis>
  </prosody>
</speak>
"@)
            $speaker.SetOutputToNull()
            $raw = $stream.ToArray()
        } finally {
            $stream.Dispose()
        }

        # 裁去合成器首尾静音，输出统一的标准 PCM 文件。
        if ($raw.Length -lt 2) { throw 'Missing PCM data' }
        $samples = [Int16[]]::new($raw.Length / 2)
        [Buffer]::BlockCopy($raw, 0, $samples, 0, $raw.Length)
        $first = 0
        $last = $samples.Length - 1
        while ($first -lt $last -and [Math]::Abs([int]$samples[$first]) -lt 180) {
            $first++
        }
        while ($last -gt $first -and [Math]::Abs([int]$samples[$last]) -lt 180) {
            $last--
        }
        $first = [Math]::Max(0, $first - 220)
        $last = [Math]::Min($samples.Length - 1, $last + 1102)
        $pcm = [byte[]]::new(($last - $first + 1) * 2)
        [Buffer]::BlockCopy($samples, $first * 2, $pcm, 0, $pcm.Length)
        $file = [IO.File]::Create([IO.Path]::Combine($output, "$($phrase.Name).wav"))
        $writer = [IO.BinaryWriter]::new($file)
        try {
            $writer.Write([Text.Encoding]::ASCII.GetBytes('RIFF'))
            $writer.Write([int](36 + $pcm.Length))
            $writer.Write([Text.Encoding]::ASCII.GetBytes('WAVEfmt '))
            $writer.Write([int]16)
            $writer.Write([Int16]1)
            $writer.Write([Int16]1)
            $writer.Write([int]22050)
            $writer.Write([int]44100)
            $writer.Write([Int16]2)
            $writer.Write([Int16]16)
            $writer.Write([Text.Encoding]::ASCII.GetBytes('data'))
            $writer.Write([int]$pcm.Length)
            $writer.Write($pcm)
        } finally {
            $writer.Dispose()
        }
        Write-Output "$($phrase.Name): $([Math]::Round($pcm.Length / 44100, 2)) s"
    }
} finally {
    $speaker.Dispose()
}
