# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' porperty is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

# Write an information log with the current time.
Write-Host "PowerShell timer trigger function ran! TIME: $currentUTCtime"

Write-Verbose "Connecting to Azure..."
Connect-AzAccount -Identity

Write-Verbose "Import the PSElectricityMaps module..."
Import-Module PSElectricityMaps

Write-Verbose "Load Application Insights .dll assembly into PowerShell session"
[Reflection.Assembly]::LoadFile("$PSScriptRoot\Microsoft.ApplicationInsights.dll")

Write-Verbose "Instanciate a new TelemetryClient"
$TelemetryClient = [Microsoft.ApplicationInsights.TelemetryClient]::new()

Write-Verbose "Set the Application Insights Instrumentation Key"
# TODO: Set the Application Insights Instrumentation Key
$TelemetryClient.InstrumentationKey = $env:APPINSIGHTS_INSTRUMENTATIONKEY

Write-Verbose "Parse the JSON payload of the REGIONS environment variable"
$regions = $env:REGIONS | ConvertFrom-Json

Write-Verbose "Loop through the regions"
foreach ($region in $regions) {
    Write-Verbose "Get the current carbon intensity for $region"
    $carbonIntensity = Get-ElectricityMapsForAzureRegion -Region $region -AuthToken $env:EMTOKEN

    Write-Verbose "Set a new app insights sample for the carbon intensity"
    $sample = New-Object Microsoft.ApplicationInsights.DataContracts.MetricTelemetry
    $sample.Name = "$($region)CarbonIntensity"
    $sample.Sum = $carbonIntensity.CarbonIntensity

    Write-Verbose "Send the sample to Application Insights"
    $TelemetryClient.TrackMetric($sample)
}
