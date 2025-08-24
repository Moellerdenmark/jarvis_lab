Set-StrictMode -Version Latest
try { [void][System.Numerics.Complex]::Zero } catch { Add-Type -AssemblyName System.Numerics }

function Get-TempWavPath([string]$Stem) {
  $dir = Join-Path $PSScriptRoot "..\out\listen"
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  return (Join-Path $dir ("{0}_{1:yyyyMMdd_HHmmssfff}.wav" -f $Stem, (Get-Date)))
}

function Convert-To16kMono([string]$InWav, [string]$OutWav) {
  & ffmpeg -hide_banner -loglevel warning -y -i $InWav -ac 1 -ar 16000 -acodec pcm_s16le $OutWav 2>$null
}

function Read-WavSamples16kMono([string]$Path) {
  $tmp = $Path
  try {
    [byte[]]$bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 44) { throw "WAV for kort" }
    $channels   = [BitConverter]::ToInt16($bytes, 22)
    $samplerate = [BitConverter]::ToInt32($bytes, 24)
    $bits       = [BitConverter]::ToInt16($bytes, 34)
    if ($channels -ne 1 -or $samplerate -ne 16000 -or $bits -ne 16) {
      $tmpConv = Get-TempWavPath "conv"
      Convert-To16kMono $Path $tmpConv
      $bytes      = [IO.File]::ReadAllBytes($tmpConv)
      $channels   = [BitConverter]::ToInt16($bytes, 22)
      $samplerate = [BitConverter]::ToInt32($bytes, 24)
      $bits       = [BitConverter]::ToInt16($bytes, 34)
      if ($channels -ne 1 -or $samplerate -ne 16000 -or $bits -ne 16) {
        throw "Kunne ikke sikre 16k/mono/16bit via ffmpeg"
      }
      $tmp = $tmpConv
    }
    # find data-chunk
    $pos = 12; $dataStart = $null
    while ($pos + 8 -le $bytes.Length) {
      $tag = [Text.Encoding]::ASCII.GetString($bytes, $pos, 4)
      $sz  = [BitConverter]::ToInt32($bytes, $pos+4)
      if ($tag -eq 'data') { $dataStart = $pos + 8; break }
      $pos += 8 + $sz
    }
    if (-not $dataStart) { throw "WAV mangler data-chunk" }
    $count = ($bytes.Length - $dataStart) / 2
    [double[]]$samples = New-Object double[] $count
    $j = 0
    for ($i = $dataStart; $i -lt $bytes.Length; $i += 2) {
      $s = [BitConverter]::ToInt16($bytes, $i)
      $samples[$j] = $s / 32768.0
      $j++
    }
    $tempOut = $null
    if ($tmp -ne $Path) { $tempOut = $tmp }
    return @{ Fs = 16000; Samples = $samples; Temp = $tempOut }
  } catch {
    throw "Read-WavSamples16kMono fejl: $($_.Exception.Message)"
  }
}

function New-Hamming([int]$N) {
  [double[]]$w = New-Object double[] $N
  for ($n=0;$n -lt $N;$n++){ $w[$n] = 0.54 - 0.46 * [Math]::Cos((2*[Math]::PI*$n)/($N-1)) }
  return $w
}

function NextPow2([int]$n) { $p=1; while($p -lt $n){$p*=2}; return $p }

function Invoke-FFT([System.Numerics.Complex[]]$x) {
  $N = $x.Length
  $bits = [Math]::Log($N, 2)
  if ($bits -ne [Math]::Floor($bits)) { throw "FFT: N er ikke en 2-potes ($N)" }
  function Rev([int]$v, [int]$bits){ $r=0; for($i=0;$i -lt $bits;$i++){ $r = ($r -shl 1) -bor ($v -band 1); $v = $v -shr 1 }; return $r }
  for ($i=0; $i -lt $N; $i++){ $j = Rev $i $bits; if ($j -gt $i) { $tmp=$x[$i]; $x[$i]=$x[$j]; $x[$j]=$tmp } }
  $len = 2
  while ($len -le $N) {
    $ang = -2.0 * [Math]::PI / $len
    $wlen = [System.Numerics.Complex]::new([Math]::Cos($ang), [Math]::Sin($ang))
    for ($i=0; $i -lt $N; $i += $len) {
      $w = [System.Numerics.Complex]::One
      for ($j=0; $j -lt $len/2; $j++) {
        $u = $x[$i+$j]
        $v = $x[$i+$j+$len/2] * $w
        $x[$i+$j] = $u + $v
        $x[$i+$j+$len/2] = $u - $v
        $w = $w * $wlen
      }
    }
    $len *= 2
  }
  return $x
}

function Get-MelFilterBank([int]$fs,[int]$nfft,[int]$nFilters=26,[int]$fmin=0,[int]$fmax=8000){
  function HzToMel([double]$hz){ 2595.0 * [Math]::Log10(1.0 + $hz/700.0) }
  function MelToHz([double]$mel){ 700.0 * ( [Math]::Pow(10.0, $mel/2595.0) - 1.0 ) }
  $lowMel = HzToMel $fmin; $highMel = HzToMel $fmax
  [double[]]$mel = New-Object double[] ($nFilters+2)
  for($i=0;$i -lt $mel.Length;$i++){ $mel[$i] = $lowMel + ($highMel-$lowMel)*$i/($nFilters+1) }
  [int[]]$bins = New-Object int[] $mel.Length
  for($i=0;$i -lt $bins.Length;$i++){ $hz = MelToHz $mel[$i]; $bins[$i] = [int][Math]::Floor(($nfft+1)*$hz/$fs) }
  $bank = @()
  for($m=1;$m -le $nFilters;$m++){
    [double[]]$f = New-Object double[] ($nfft/2+1)
    for($k=0;$k -le $nfft/2;$k++){
      $val = 0.0
      if($k -ge $bins[$m-1] -and $k -le $bins[$m]){
        $val = ($k - $bins[$m-1]) / [double]($bins[$m] - $bins[$m-1] + 1e-12)
      } elseif($k -ge $bins[$m] -and $k -le $bins[$m+1]){
        $val = ($bins[$m+1] - $k) / [double]($bins[$m+1] - $bins[$m] + 1e-12)
      }
      $f[$k] = [Math]::Max(0.0, $val)
    }
    $bank += ,$f
  }
  return ,$bank
}

function Get-DCTMatrix([int]$N,[int]$M){
  $mat = @()
  for($i=0;$i -lt $M;$i++){
    [double[]]$row = New-Object double[] $N
    for($j=0;$j -lt $N;$j++){
      $row[$j] = [Math]::Cos([Math]::PI * $i * (2*$j+1) / (2*$N))
    }
    $mat += ,$row
  }
  return ,$mat
}

function Compute-Embedding([string[]]$Wavs){
  $fs = 16000; $frameMs=25; $stepMs=10
  $frameLen = [int]($fs*$frameMs/1000.0)   # 400
  $frameStep= [int]($fs*$stepMs/1000.0)    # 160
  $nfft = NextPow2 ($frameLen)             # 512
  $hamm = New-Hamming $frameLen
  $bank = Get-MelFilterBank $fs $nfft 26 0 8000
  $dct  = Get-DCTMatrix 26 13

  $allCoeffs = @()

  foreach($wav in $Wavs){
    $r = Read-WavSamples16kMono $wav
    $x = $r.Samples
    if(-not $x -or $x.Length -lt $frameLen){ continue }
    for($start=0; $start+$frameLen -le $x.Length; $start += $frameStep){
      [System.Numerics.Complex[]]$cx = New-Object 'System.Numerics.Complex[]' $nfft
      for($i=0;$i -lt $frameLen;$i++){ $cx[$i] = [System.Numerics.Complex]::new($x[$start+$i]*$hamm[$i],0) }
      for($i=$frameLen;$i -lt $nfft;$i++){ $cx[$i] = [System.Numerics.Complex]::Zero }
      $X = Invoke-FFT $cx
      [double[]]$P = New-Object double[] ($nfft/2+1)
      for($k=0;$k -le $nfft/2;$k++){
        $re = $X[$k].Real; $im = $X[$k].Imaginary
        $P[$k] = ($re*$re + $im*$im) / $nfft
      }
      [double[]]$E = New-Object double[] 26
      for($m=0;$m -lt 26;$m++){
        $sum = 0.0; $f = $bank[$m]
        for($k=0;$k -lt $f.Length;$k++){ $sum += $P[$k]*$f[$k] }
        $E[$m] = [Math]::Log([Math]::Max($sum,1e-12))
      }
      [double[]]$C = New-Object double[] 13
      for($i=0;$i -lt 13;$i++){
        $s = 0.0; $row = $dct[$i]
        for($j=0;$j -lt 26;$j++){ $s += $row[$j]*$E[$j] }
        $C[$i] = $s
      }
      $allCoeffs += ,$C
    }
  }

  if($allCoeffs.Count -eq 0){ throw "Ingen frames i input" }

  [double[]]$mean = New-Object double[] 13
  [double[]]$std  = New-Object double[] 13
  foreach($c in $allCoeffs){ for($i=0;$i -lt 13;$i++){ $mean[$i] += $c[$i] } }
  for($i=0;$i -lt 13;$i++){ $mean[$i] /= $allCoeffs.Count }
  foreach($c in $allCoeffs){ for($i=0;$i -lt 13;$i++){ $std[$i] += [Math]::Pow($c[$i]-$mean[$i],2) } }
  for($i=0;$i -lt 13;$i++){ $std[$i] = [Math]::Sqrt($std[$i]/[double]$allCoeffs.Count) }

  [double[]]$emb = New-Object double[] 26
  for($i=0;$i -lt 13;$i++){ $emb[$i] = $mean[$i]; $emb[13+$i] = $std[$i] }

  $nrm = 0.0; for($i=0;$i -lt $emb.Length;$i++){ $nrm += $emb[$i]*$emb[$i] }
  $nrm = [Math]::Sqrt([Math]::Max($nrm,1e-12))
  for($i=0;$i -lt $emb.Length;$i++){ $emb[$i] /= $nrm }
  return $emb
}

function CosSim([double[]]$a,[double[]]$b){
  if($a.Length -ne $b.Length){ throw "CosSim dims mismatch" }
  $dot=0.0;$na=0.0;$nb=0.0
  for($i=0;$i -lt $a.Length;$i++){ $dot += $a[$i]*$b[$i]; $na += $a[$i]*$a[$i]; $nb += $b[$i]*$b[$i] }
  if($na -le 0 -or $nb -le 0){ return 0.0 }
  return $dot / ([Math]::Sqrt($na)*[Math]::Sqrt($nb))
}
