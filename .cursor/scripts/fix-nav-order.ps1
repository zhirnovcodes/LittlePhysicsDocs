$root = 'c:\Work\LittlePhysicsDocs'

$orderedGroups = @{
    'docs/guides/types-of-bodies' = @(
        'dynamic.md', 'kinematic-rigid.md', 'kinematic-trigger.md', 'static-rigid.md',
        'static-trigger.md', 'surface.md', 'comparison.md'
    )
    'docs/guides/physics-singleton' = @(
        'physics-ready-tag.md', 'physics-fixed-settings-component.md', 'physics-variable-settings-component.md',
        'simulation-data-component.md', 'little-physics-time-component.md', 'physics-structures-component.md',
        'bodies-list.md', 'randoms.md', 'entities-map.md', 'collision-map-singleton.md',
        'collisions-singleton.md', 'physics-body-data.md', 'supporting-body-collision-structs.md',
        'other-public-ecs-components.md', 'spatial-map.md', 'physics-settings-and-lod.md', 'gravity.md'
    )
    'docs/guides/custom-jobs' = @(
        'custom-job-groups.md', 'ibodies-job.md', 'icollision-job.md', 'isurface-job.md', 'ilinecast-job.md',
        'using-custom-job-interfaces.md', 'import-workflow.md', 'export-workflow.md', 'inside-the-pipeline.md'
    )
    'docs/guides/builders' = @(
        'dynamic-body-builder.md', 'kinematic-body-builder.md', 'static-body-builder.md'
    )
}

function Set-NavOrder([string]$Path, [int]$Order, [string]$GrandParent) {
    if (-not (Test-Path $Path)) { return }
    $content = Get-Content $Path -Raw
    if ($content -notmatch '(?ms)^---\r?\n(.*?)\r?\n---') { return }

    $fm = $Matches[1]
    if ($fm -match '(?m)^nav_order:\s*\d+') {
        $fm = [regex]::Replace($fm, '(?m)^nav_order:\s*\d+\r?\n?', '')
    }
    if ($GrandParent) {
        if ($fm -match '(?m)^grand_parent:') {
            $fm = [regex]::Replace($fm, '(?m)^grand_parent:.*$', "grand_parent: $GrandParent")
        }
        else {
            $fm = $fm.TrimEnd() + "`ngrand_parent: $GrandParent"
        }
    }

    $lines = $fm -split "`r?`n"
    $inserted = $false
    $newLines = foreach ($line in $lines) {
        if (-not $inserted -and $line -match '^parent:') {
            $line
            "nav_order: $Order"
            $inserted = $true
        }
        else {
            $line
        }
    }
    if (-not $inserted) {
        $newLines = @("nav_order: $Order") + $lines
    }

    $newFm = ($newLines -join "`n").TrimEnd()
    $newContent = "---`n$newFm`n---" + ($content.Substring($content.IndexOf('---', 3) + 3))
    [System.IO.File]::WriteAllText($Path, $newContent)
}

foreach ($group in $orderedGroups.GetEnumerator()) {
    $order = 1
    foreach ($file in $group.Value) {
        Set-NavOrder (Join-Path $root "$($group.Key)/$file") $order $null
        $order++
    }
}

$apiSections = @(
    'systems-and-system-groups', 'authoring', 'components', 'body-data', 'builders',
    'shapes', 'job-interfaces', 'enums', 'utilities', 'editor'
)

foreach ($section in $apiSections) {
    $dir = Join-Path $root "docs/api-reference/$section"
    if (-not (Test-Path $dir)) { continue }
    $order = 1
    Get-ChildItem $dir -Filter '*.md' | Where-Object { $_.Name -ne 'index.md' } | Sort-Object Name | ForEach-Object {
        Set-NavOrder $_.FullName $order 'API Reference'
        $order++
    }
}

Write-Output 'nav_order and grand_parent updated.'
