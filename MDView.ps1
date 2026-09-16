using namespace System.Windows.Forms;
param(
    [Parameter(ParameterSetName = 'Default', Position = 0)]
    [Parameter(ParameterSetName = 'PreviewMode', Mandatory, Position = 0)]
    [string] $File,
    [Parameter(ParameterSetName = 'PreviewMode', Mandatory)]
    [switch] $Preview
)
$ErrorActionPreference = 'Stop';
Add-Type -AssemblyName System.Windows.Forms;
Add-Type -AssemblyName System.Drawing;
Add-Type -Path $PSScriptRoot\libs\Microsoft.Web.WebView2.Core.dll
Add-Type -Path $PSScriptRoot\libs\Microsoft.Web.WebView2.WinForms.dll

. (Join-Path $PSScriptRoot MDView.class.ps1)

@(
    '--------------------'
    'File: {0}' -f $File
    'Preview: {0}' -f $Preview
    '--------------------'
) | Write-Host

$appContext = [MDViewContext]::new($File, $Preview)
[Application]::Run($appContext)
