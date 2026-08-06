function To-Kebab([string]$name) {
    $name = $name -replace '<T>', ''
    $name = $name -replace 'Grid3D', 'Grid3d'
    $name = $name -replace 'LineCast', 'Linecast'

    if ($name -match '^I[A-Z]') {
        $rest = $name.Substring(1)
        $result = [regex]::Replace($rest, '([a-z0-9])([A-Z])', '$1-$2')
        $result = [regex]::Replace($result, '([A-Z]+)([A-Z][a-z])', '$1-$2')
        return ('i' + $result).ToLower()
    }

    $result = [regex]::Replace($name, '([a-z0-9])([A-Z])', '$1-$2')
    $result = [regex]::Replace($result, '([A-Z]+)([A-Z][a-z])', '$1-$2')
    return $result.ToLower()
}

function Write-DocPage([string]$Path, [hashtable]$Fm) {
    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $lines = @('---')
    foreach ($key in @('title', 'layout', 'nav_order', 'parent', 'grand_parent', 'has_children', 'permalink', 'description', 'tags')) {
        if ($Fm.ContainsKey($key) -and $null -ne $Fm[$key]) {
            $val = $Fm[$key]
            if ($val -is [int]) {
                $lines += "${key}: $val"
            }
            elseif ($val -is [array]) {
                $lines += "${key}: [$($val -join ', ')]"
            }
            else {
                $lines += "${key}: $val"
            }
        }
    }
    $lines += '---'
    $lines += ''
    [System.IO.File]::WriteAllText((Join-Path (Get-Location) $Path), ($lines -join "`n") + "`n")
}

$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $root

Write-DocPage 'index.md' @{
    title       = 'Home'
    layout      = 'default'
    nav_order   = 1
    permalink   = '/'
    description = 'Documentation home for Little Physics.'
}

Write-DocPage 'docs/getting-started.md' @{
    title       = 'Getting Started'
    layout      = 'default'
    nav_order   = 2
    description = 'Install and set up Little Physics in a Unity 6 project.'
}

Write-DocPage 'docs/how-it-works.md' @{
    title       = 'How it works'
    layout      = 'default'
    nav_order   = 3
    description = 'ECS workflow, bootstrap, import, fixed-step loop, and export.'
}

Write-DocPage 'docs/pipeline.md' @{
    title       = 'Pipeline'
    layout      = 'default'
    nav_order   = 4
    description = 'System groups, execution order, and public extension points.'
}

Write-DocPage 'docs/guides/types-of-bodies/index.md' @{
    title       = 'Types of bodies'
    layout      = 'default'
    nav_order   = 5
    has_children = 'true'
    permalink   = '/docs/guides/types-of-bodies/'
    description = 'Dynamic, kinematic, static, surface, and trigger body types.'
}

$bodyTypes = @(
    @{ slug = 'dynamic'; title = 'Dynamic' }
    @{ slug = 'kinematic-rigid'; title = 'Kinematic rigid' }
    @{ slug = 'kinematic-trigger'; title = 'Kinematic trigger' }
    @{ slug = 'static-rigid'; title = 'Static rigid' }
    @{ slug = 'static-trigger'; title = 'Static trigger' }
    @{ slug = 'surface'; title = 'Surface' }
    @{ slug = 'comparison'; title = 'Body type comparison' }
)

$bodyOrder = 1
foreach ($b in $bodyTypes) {
    Write-DocPage "docs/guides/types-of-bodies/$($b.slug).md" @{
        title       = $b.title
        layout      = 'default'
        parent      = 'Types of bodies'
        nav_order   = $bodyOrder
        description = "TODO: $($b.title) body type."
    }
    $bodyOrder++
}

Write-DocPage 'docs/guides/physics-singleton/index.md' @{
    title       = 'Physics singleton'
    layout      = 'default'
    nav_order   = 6
    has_children = 'true'
    permalink   = '/docs/guides/physics-singleton/'
    description = 'Public singleton components and native simulation structures.'
}

# Guide titles must be unique site-wide (Just the Docs matches parent by title).
# Keep exact C# names on API pages; give guide pages distinct titles.
$singletonPages = @(
    @{ slug = 'physics-ready-tag'; title = 'PhysicsReadyTag' }
    @{ slug = 'physics-fixed-settings-component'; title = 'PhysicsFixedSettingsComponent' }
    @{ slug = 'physics-variable-settings-component'; title = 'PhysicsVariableSettingsComponent' }
    @{ slug = 'simulation-data-component'; title = 'SimulationDataComponent' }
    @{ slug = 'little-physics-time-component'; title = 'LittlePhysicsTimeComponent' }
    @{ slug = 'physics-structures-component'; title = 'PhysicsStructuresComponent' }
    @{ slug = 'bodies-list'; title = 'BodiesList' }
    @{ slug = 'randoms'; title = 'Randoms' }
    @{ slug = 'entities-map'; title = 'EntitiesMap' }
    @{ slug = 'collision-map-singleton'; title = 'CollisionMapSingleton' }
    @{ slug = 'collisions-singleton'; title = 'CollisionsSingleton' }
    @{ slug = 'physics-body-data'; title = 'PhysicsBodyData' }
    @{ slug = 'supporting-body-collision-structs'; title = 'Supporting body and collision structs' }
    @{ slug = 'other-public-ecs-components'; title = 'Other public ECS components' }
    @{ slug = 'spatial-map'; title = 'Spatial map' }
    @{ slug = 'physics-settings-and-lod'; title = 'Physics settings and LOD' }
    @{ slug = 'gravity'; title = 'Gravity' }
)

$singletonOrder = 1
foreach ($p in $singletonPages) {
    Write-DocPage "docs/guides/physics-singleton/$($p.slug).md" @{
        title       = $p.title
        layout      = 'default'
        parent      = 'Physics singleton'
        nav_order   = $singletonOrder
        description = "TODO: $($p.title)."
    }
    $singletonOrder++
}

Write-DocPage 'docs/guides/pairs-debug-window.md' @{
    title       = 'Pairs debug window'
    layout      = 'default'
    nav_order   = 7
    description = 'Runtime debug table for entity pairs and collision data.'
}

Write-DocPage 'docs/guides/custom-jobs/index.md' @{
    title       = 'Custom jobs'
    layout      = 'default'
    nav_order   = 8
    has_children = 'true'
    permalink   = '/docs/guides/custom-jobs/'
    description = 'Custom job groups, interfaces, and import/export workflows.'
}

$customJobPages = @(
    @{ slug = 'custom-job-groups'; title = 'Custom job groups' }
    @{ slug = 'ibodies-job'; title = 'Using IBodiesJob' }
    @{ slug = 'icollision-job'; title = 'Using ICollisionJob' }
    @{ slug = 'isurface-job'; title = 'Using ISurfaceJob' }
    @{ slug = 'ilinecast-job'; title = 'Using ILineCastJob' }
    @{ slug = 'using-custom-job-interfaces'; title = 'Using custom job interfaces' }
    @{ slug = 'import-workflow'; title = 'Import workflow' }
    @{ slug = 'export-workflow'; title = 'Export workflow' }
    @{ slug = 'inside-the-pipeline'; title = 'Inside the pipeline' }
)

$customJobOrder = 1
foreach ($p in $customJobPages) {
    Write-DocPage "docs/guides/custom-jobs/$($p.slug).md" @{
        title       = $p.title
        layout      = 'default'
        parent      = 'Custom jobs'
        nav_order   = $customJobOrder
        description = "TODO: $($p.title)."
    }
    $customJobOrder++
}

Write-DocPage 'docs/guides/builders/index.md' @{
    title       = 'Using builders'
    layout      = 'default'
    nav_order   = 9
    has_children = 'true'
    permalink   = '/docs/guides/builders/'
    description = 'Runtime helpers for spawning physics bodies.'
}

$builderOrder = 1
foreach ($builder in @('DynamicBodyBuilder', 'KinematicBodyBuilder', 'StaticBodyBuilder')) {
    $slug = To-Kebab $builder
    Write-DocPage "docs/guides/builders/$slug.md" @{
        title       = "Using $builder"
        layout      = 'default'
        parent      = 'Using builders'
        nav_order   = $builderOrder
        description = "TODO: $builder guide."
    }
    $builderOrder++
}

Write-DocPage 'docs/api-reference/index.md' @{
    title       = 'API Reference'
    layout      = 'default'
    nav_order   = 10
    has_children = 'true'
    permalink   = '/docs/api-reference/'
    description = 'Public API for com.ivancodes.littlephysics.'
}

$apiSections = @(
    @{
        dir   = 'systems-and-system-groups'
        title = 'Systems and system groups'
        types = @(
            'LittlePhysicsBootstrapSystem'
            'PairsDebugSystem'
            'LittlePhysicsUserSystemGroup'
            'LittlePhysicsImportGroup'
            'LittlePhysicsExportGroup'
        )
    }
    @{
        dir   = 'authoring'
        title = 'Authoring'
        types = @(
            'DynamicBodyAuthoring'
            'KinematicBodyAuthoring'
            'StaticBodyAuthoring'
            'SurfaceBodyAuthoring'
            'GravitySourceAuthoring'
            'PhysicsSettingsAuthoring'
            'PhysicsVelocityAuthoring'
            'SpacialMapAuthoring'
        )
    }
    @{
        dir   = 'components'
        title = 'Components and ECS data'
        types = @(
            'PhysicsBodyComponent'
            'PhysicsBodyUpdateComponent'
            'PhysicsVelocityComponent'
            'PhysicsReadyTag'
            'PhysicsFixedSettingsComponent'
            'PhysicsVariableSettingsComponent'
            'PhysicsSettingsBlobAsset'
            'EnvironmentSettings'
            'CollisionCheckSettings'
            'SpacialMapSettingsComponent'
            'PhysicsMapRandomComponent'
            'CollisionSurfaceComponent'
            'SphericalGravitySourceComponent'
            'DirectionalGravitySourceComponent'
            'PhysicsLodData'
            'PhysicsLodElement'
            'LittlePhysicsTimeComponent'
            'SimulationDataComponent'
            'PhysicsStructuresComponent'
            'CollisionMapSingleton'
            'CollisionsSingleton'
            'CameraData'
        )
    }
    @{
        dir   = 'body-data'
        title = 'Body data and collision results'
        types = @(
            'PhysicsBodyData'
            'RigidbodyData'
            'VelocityData'
            'PositionData'
            'CollisionData'
            'SurfaceCollisionData'
            'BodyCollisionResult'
            'IntersectionData'
            'LineCastResult'
            'CastFilter'
            'LinecastIterator'
            'TraverseLineIterator'
            'AABBTraverseIterator'
        )
    }
    @{
        dir   = 'builders'
        title = 'Builders'
        types = @('DynamicBodyBuilder', 'KinematicBodyBuilder', 'StaticBodyBuilder')
    }
    @{
        dir   = 'shapes'
        title = 'Shapes and geometry'
        types = @(
            'Sphere'
            'Capsule'
            'SimpleBox'
            'SimplePlane'
            'InverseSphere'
            'SphericalCone'
            'Line'
            'AABB'
            'Grid3D'
            'SpacialMap'
            'Rectangle'
            'ListsArray<T>'
        )
    }
    @{
        dir   = 'job-interfaces'
        title = 'Job interfaces'
        types = @('IBodiesJob', 'ICollisionJob', 'ISurfaceJob', 'ILineCastJob')
    }
    @{
        dir   = 'enums'
        title = 'Enums'
        types = @('BodyType', 'ColliderType', 'ShapeType', 'GravitySourceType', 'PushOutType')
    }
    @{
        dir   = 'utilities'
        title = 'Utility classes'
        types = @(
            'CollisionMethods'
            'PhysicsCastExtensions'
            'SpacialMapExtensions'
            'MapExtensions'
            'Grid3DExtensions'
            'PhysicsSettingsExtensions'
            'PhysicsDebug'
            'LittlePhysicsPerformance'
            'PhysicsLodDataList'
            'IBodiesReadExtensions'
            'IBodiesWriteExtensions'
            'IBodiesReadIndexExtensions'
            'IBodiesWriteIndexExtensions'
            'ICollisionJobExtensions'
            'ICollisionReadBodyExtensions'
            'ICollisionWriteBodyExtensions'
            'ICollisionReadExtensions'
            'ICollisionWriteExtensions'
            'ICollisionEntitiesExtensions'
            'ISurfaceJobExtensions'
            'ISurfaceReadExtensions'
            'ISurfaceWriteExtensions'
            'ISurfaceEntityExtensions'
            'ILineCastJobExtensions'
            'ILineCastReadBodyExtensions'
            'ILineCastWriteBodyExtensions'
            'ClearBodiesJob'
            'ImportPhysicsDataJob'
        )
    }
    @{
        dir   = 'editor'
        title = 'Editor'
        types = @(
            'DynamicBodyEditor'
            'KinematicBodyEditor'
            'StaticBodyEditor'
            'SurfaceBodyEditor'
            'GravitySourceEditor'
            'SpacialMapEditor'
            'PhysicsSettingsAuthoringEditor'
            'PhysicsLodDataDrawer'
            'PhysicsLodDataListDrawer'
            'PhysicsLodDataDrawHelper'
            'LodDrawConfig'
            'EditorShapeDrawer'
        )
    }
)

$nav = 1
foreach ($section in $apiSections) {
    Write-DocPage "docs/api-reference/$($section.dir)/index.md" @{
        title        = $section.title
        layout       = 'default'
        parent       = 'API Reference'
        nav_order    = $nav
        has_children = 'true'
        permalink    = "/docs/api-reference/$($section.dir)/"
        description  = "TODO: $($section.title) API reference."
    }
    $nav++

    $typeOrder = 1
    foreach ($type in $section.types) {
        $slug = To-Kebab $type
        Write-DocPage "docs/api-reference/$($section.dir)/$slug.md" @{
            title        = $type
            layout       = 'default'
            parent       = $section.title
            nav_order    = $typeOrder
            grand_parent = 'API Reference'
            description  = "TODO: $type API reference."
        }
        $typeOrder++
    }
}

Remove-Item -Force -ErrorAction SilentlyContinue `
    'docs/api-reference/rigidbody-component.md', `
    'docs/api-reference/collider-component.md'

$count = (Get-ChildItem -Recurse -Filter '*.md' | Measure-Object).Count
Write-Output "Created/updated markdown files: $count"
