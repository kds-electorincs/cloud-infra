$profileName = "kds-client"
$bucketImages = "kds-electronics-13062026-images"
$bucketStaging = "kds-electronics-13062026-staging"

function Remove-AllVersionsOrMarkers($bucketName, $queryPath) {
    $jsonText = aws s3api list-object-versions --bucket $bucketName --profile $profileName --output json --query $queryPath 2>$null
    if (-not $jsonText -or $jsonText.Trim() -eq "[]" -or $jsonText.Trim() -eq "null") {
        Write-Host "Nothing to delete for $bucketName - $queryPath"
        return
    }

    $items = $jsonText | ConvertFrom-Json
    if ($items -isnot [System.Array]) { $items = @($items) }

    for ($i = 0; $i -lt $items.Count; $i += 1000) {
        $batch = $items[$i..([Math]::Min($i + 999, $items.Count - 1))]
        $objects = $batch | ForEach-Object { @{ Key = $_.Key; VersionId = $_.VersionId } }
        $payload = @{ Objects = @($objects); Quiet = $true } | ConvertTo-Json -Depth 5 -Compress

        $tmpFile = [System.IO.Path]::Combine($PWD, "delete-batch-$i.json")
        [System.IO.File]::WriteAllText($tmpFile, $payload, [System.Text.Encoding]::ASCII)

        aws s3api delete-objects --bucket $bucketName --delete "file://$tmpFile" --profile $profileName
        Remove-Item $tmpFile
    }
}

function Remove-BucketCompletely($bucketName) {
    # Confirm the bucket actually exists before doing anything
    aws s3api head-bucket --bucket $bucketName --profile $profileName 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Bucket '$bucketName' does not exist or is not accessible under profile '$profileName' - skipping." -ForegroundColor Yellow
        return
    }

    Remove-AllVersionsOrMarkers $bucketName "Versions[].{Key:Key,VersionId:VersionId}"
    Remove-AllVersionsOrMarkers $bucketName "DeleteMarkers[].{Key:Key,VersionId:VersionId}"

    aws s3 rb "s3://$bucketName" --profile $profileName --force
    Write-Host "Deleted bucket: $bucketName" -ForegroundColor Green
}

# --- Confirmation gate: this is destructive and irreversible ---
Write-Host "This will PERMANENTLY delete all objects and versions in:" -ForegroundColor Red
Write-Host "  - $bucketImages"
Write-Host "  - $bucketStaging"
Write-Host "Then delete both buckets."
$confirmation = Read-Host "Type the exact text 'DELETE BOTH BUCKETS' to proceed"

if ($confirmation -ne "DELETE BOTH BUCKETS") {
    Write-Host "Confirmation text did not match. Aborting - nothing was deleted." -ForegroundColor Yellow
    exit
}

Remove-BucketCompletely $bucketImages
Remove-BucketCompletely $bucketStaging