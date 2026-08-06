$root = 'c:\Work\LittlePhysicsDocs'
$titles = @{}
$parents = @()

Get-ChildItem $root -Recurse -Filter '*.md' | Where-Object { $_.FullName -notmatch '\\\.cursor\\|\\_site\\' } | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    if ($content -match '(?ms)^---\r?\n(.*?)\r?\n---') {
        $fm = $Matches[1]
        $title = $null
        $parent = $null
        if ($fm -match '(?m)^title:\s*(.+)$') { $title = $Matches[1].Trim() }
        if ($fm -match '(?m)^parent:\s*(.+)$') { $parent = $Matches[1].Trim() }
        if ($title) {
            if (-not $titles.ContainsKey($title)) { $titles[$title] = @() }
            $titles[$title] += $_.FullName.Substring($root.Length + 1)
        }
        if ($parent) {
            $parents += [PSCustomObject]@{ File = $_.FullName.Substring($root.Length + 1); Parent = $parent }
        }
    }
}

Write-Output 'DUPLICATE TITLES:'
$titles.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 } | Sort-Object Name | ForEach-Object {
    Write-Output "  $($_.Name):"
    $_.Value | ForEach-Object { Write-Output "    - $_" }
}

Write-Output ''
Write-Output 'ORPHAN PARENT REFERENCES:'
$parents | Where-Object { -not $titles.ContainsKey($_.Parent) } | ForEach-Object {
    Write-Output "  $($_.File) -> parent '$($_.Parent)' (missing)"
}

Write-Output ''
Write-Output 'TOP-LEVEL NAV:'
Get-ChildItem $root -Recurse -Filter '*.md' | Where-Object { $_.FullName -notmatch '\\\.cursor\\|\\_site\\' } | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    if ($content -match '(?ms)^---\r?\n(.*?)\r?\n---') {
        $fm = $Matches[1]
        if ($fm -match '(?m)^parent:') { return }
        $title = if ($fm -match '(?m)^title:\s*(.+)$') { $Matches[1].Trim() } else { $null }
        $nav = if ($fm -match '(?m)^nav_order:\s*(\d+)') { $Matches[1] } else { '-' }
        if ($title) { Write-Output "  nav_order=$nav  $title  ($($_.FullName.Substring($root.Length + 1)))" }
    }
} | Sort-Object
