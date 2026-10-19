param(
    [Parameter(Mandatory)][string]$App,
    [Parameter(Mandatory)][string]$Hap,
    [Parameter(Mandatory)][string]$Java,
    [Parameter(Mandatory)][string]$SignTool,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [Parameter(Mandatory)][string]$ExpectedVersion,
    [Parameter(Mandatory)][int]$ExpectedBuild,
    [string]$ExpectedBundle = 'cn.saydian.ring.hm',
    [string]$ExpectedCertificateSha256 = 'C4F4B2AF305C338728D7172B845B4455D7CE1896EA0D40A28579FC1E56C28A3C'
)

# Read-only with respect to input packages. No credentials, signing or upload.
# An inner HAP signature is NOT evidence that its containing APP is signed.
$ErrorActionPreference = 'Stop'
foreach ($inputPath in @($App, $Hap, $Java, $SignTool)) {
    if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf)) {
        throw "Required input missing: $inputPath"
    }
}
New-Item -ItemType Directory -Path $OutputDirectory -ErrorAction Stop | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Security.Cryptography.Pkcs

function Assert-Signature([string]$Package, [string]$Label) {
    $verifyLog = Join-Path $OutputDirectory "$Label-verify.log"
    & $Java -jar $SignTool verify-app -inFile $Package `
        -outCertChain (Join-Path $OutputDirectory "$Label-chain.cer") `
        -outProfile (Join-Path $OutputDirectory "$Label-profile.p7b") *> $verifyLog
    if ($LASTEXITCODE -ne 0) {
        throw "$Label signature verification failed; see $verifyLog"
    }
    # SDK output orders the root before the leaf; never take the first digest.
    $chainText = Get-Content -Raw -LiteralPath (Join-Path $OutputDirectory "$Label-chain.cer")
    $leafCertificates = @(
        foreach ($pem in [regex]::Matches($chainText, '(?s)-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----')) {
            $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromPem($pem.Value)
            $constraints = $certificate.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.19' }
            $isCa = $false
            if ($null -ne $constraints) {
                $isCa = [System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]::new($constraints, $constraints.Critical).CertificateAuthority
            }
            if (-not $isCa) { $certificate }
        }
    )
    if ($leafCertificates.Count -ne 1 -or
        $leafCertificates[0].GetCertHashString([System.Security.Cryptography.HashAlgorithmName]::SHA256) -ne $ExpectedCertificateSha256.ToUpperInvariant()) {
        throw "$Label is not signed by the expected release certificate"
    }
    if ([DateTime]::UtcNow -lt $leafCertificates[0].NotBefore.ToUniversalTime() -or
        [DateTime]::UtcNow -ge $leafCertificates[0].NotAfter.ToUniversalTime()) {
        throw "$Label release certificate is not currently valid"
    }
    $cms = [System.Security.Cryptography.Pkcs.SignedCms]::new()
    $cms.Decode([System.IO.File]::ReadAllBytes((Join-Path $OutputDirectory "$Label-profile.p7b")))
    $profile = [System.Text.Encoding]::UTF8.GetString($cms.ContentInfo.Content) | ConvertFrom-Json
    if ($profile.type -ne 'release' -or $profile.'app-distribution-type' -ne 'app_gallery' -or
        $profile.'bundle-info'.'bundle-name' -ne $ExpectedBundle) {
        throw "$Label release Profile does not match this AppGallery application"
    }
    $profileCertificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromPem($profile.'bundle-info'.'distribution-certificate')
    if ($profileCertificate.GetCertHashString([System.Security.Cryptography.HashAlgorithmName]::SHA256) -ne $ExpectedCertificateSha256.ToUpperInvariant()) {
        throw "$Label Profile certificate differs from the actual signing certificate"
    }
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if ($now -lt $profile.validity.'not-before' -or $now -ge $profile.validity.'not-after') {
        throw "$Label release Profile is not currently valid"
    }
}

# Fail here before inspecting inner signatures: this prevents the 991 regression.
Assert-Signature $App 'outer-app'
$archive = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $App).Path)
$embedded = Join-Path $OutputDirectory 'embedded-entry.hap'
try {
    $entry = $archive.GetEntry('entry-default.hap')
    $packEntry = $archive.GetEntry('pack.info')
    if ($null -eq $entry -or $null -eq $packEntry -or $null -eq $archive.GetEntry('pac.json')) {
        throw 'Final APP must retain entry-default.hap, project pack.info and pac.json'
    }
    $reader = [System.IO.StreamReader]::new($packEntry.Open())
    try { $pack = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
    if ($pack.summary.app.bundleName -ne $ExpectedBundle -or
        $pack.summary.app.version.name -ne $ExpectedVersion -or
        $pack.summary.app.version.code -ne $ExpectedBuild -or
        @($pack.packages).Count -ne 1 -or $pack.packages[0].name -ne 'entry-default') {
        throw 'Final APP pack.info identity or module list mismatch'
    }
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $embedded)
} finally { $archive.Dispose() }
if ((Get-FileHash -LiteralPath $embedded).Hash -ne (Get-FileHash -LiteralPath $Hap).Hash) {
    throw 'APP packing or outer signing changed the signed inner HAP'
}
Assert-Signature $embedded 'inner-hap'
$archive = [System.IO.Compression.ZipFile]::OpenRead($embedded)
try {
    $reader = [System.IO.StreamReader]::new($archive.GetEntry('module.json').Open())
    try { $module = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
    if ($module.app.bundleName -ne $ExpectedBundle -or
        $module.app.versionName -ne $ExpectedVersion -or
        $module.app.versionCode -ne $ExpectedBuild -or $module.app.debug -ne $false) {
        throw 'Embedded release module identity mismatch'
    }
} finally { $archive.Dispose() }
Write-Output 'Harmony outer APP + inner HAP signatures, release identity and byte preservation passed.'
