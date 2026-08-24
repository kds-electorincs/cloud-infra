$profileName = "kds-client"
$bucket = "kds-electronics-13062026-images"

function Remove-AllVersionsOrMarkers($queryPath) {
    $jsonText = aws s3api list-object-versions --bucket $bucket --profile $profileName --output json --query $queryPath
    if (-not $jsonText -or $jsonText.Trim() -eq "[]" -or $jsonText.Trim() -eq "null") {
        Write-Host "Nothing to delete for $queryPath"
        return
    }

    $items = $jsonText | ConvertFrom-Json
    if ($items -isnot [System.Array]) { $items = @($items) }

    # Process in batches of 1000 (S3 API limit per delete-objects call)
    for ($i = 0; $i -lt $items.Count; $i += 1000) {
        $batch = $items[$i..([Math]::Min($i + 999, $items.Count - 1))]
        $objects = $batch | ForEach-Object { @{ Key = $_.Key; VersionId = $_.VersionId } }
        $payload = @{ Objects = @($objects); Quiet = $true } | ConvertTo-Json -Depth 5 -Compress

        $tmpFile = [System.IO.Path]::Combine($PWD, "delete-batch-$i.json")
        [System.IO.File]::WriteAllText($tmpFile, $payload, [System.Text.Encoding]::ASCII)

        aws s3api delete-objects --bucket $bucket --delete "file://$tmpFile" --profile $profileName
        Remove-Item $tmpFile
    }
}

Remove-AllVersionsOrMarkers "Versions[].{Key:Key,VersionId:VersionId}"
Remove-AllVersionsOrMarkers "DeleteMarkers[].{Key:Key,VersionId:VersionId}"

aws s3 rb "s3://$bucket" --profile $profileName --force