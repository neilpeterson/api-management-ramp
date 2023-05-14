$CertificatesUri = 'https://fitsignedmodules.blob.core.windows.net/dscsigncert-pub-key/sign-certs.zip?sp=r&st=2023-05-12T18:44:42Z&se=2023-05-13T02:44:42Z&spr=https&sv=2022-11-02&sr=b&sig=d22uW5SmxDw8a4zDitNoTJXrxacTGg87aAvkwBSInc0%3D'

$InstallPath = "C:\temp\dsc-pub-key\"
$ExpandPath = "C:\temp\dsc-pub-key\dsc-sign-certs\"

# Get installed certs from TrustedPublishers
$InstalledCerts = (Get-ChildItem Cert:\LocalMachine\TrustedPublisher\).Thumbprint

# Create temp directory
if (!(Test-Path -Path $InstallPath)) {
    New-Item -Path $InstallPath -ItemType Directory   
} else {
    Remove-Item -Path $InstallPath -Recurse -Force
    New-Item -Path $InstallPath -ItemType Directory  
}

Invoke-WebRequest -UseBasicParsing -Uri $CertificatesUri -OutFile $InstallPath\cer.zip
Expand-Archive -LiteralPath $InstallPath\cer.zip -DestinationPath $ExpandPath
$Files = Get-ChildItem -Recurse $ExpandPath

# Install any missing certificates
foreach ($Item in $Files) {        
    if ($Item.name.split('.')[0] -notin $InstalledCerts) {
        Write-Output("Installing Certificate: {0}" -f $Item.name)
        Import-Certificate -FilePath $Item.FullName -CertStoreLocation Cert:\\LocalMachine\\TrustedPublisher\\ | Out-Null
    }
}

# Clean up the temp path
Remove-Item -Path $InstallPath -Recurse -Force