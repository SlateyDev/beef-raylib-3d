$WebSourcePath = ".\build\Release_wasm32\beef-raylib-3d-game"
$WebDestinationPath = ".\build\web-release"

$WebFilesToZip = @(
    "beef-raylib-3d-game.js",
    "beef-raylib-3d-game.data",
    "beef-raylib-3d-game.wasm"
)

$WinSourcePath = ".\build\Release_win64\beef-raylib-3d-game"
$WinAssetspath = ".\assets"
$WinDestinationPath = ".\build\win-release"
$WinFilesToZip = @(
    "beef-raylib-3d-game.exe",
    "raylib.dll"
)

foreach ($file in $WebFilesToZip) {
    Copy-Item -Path "$WebSourcePath\$file" -Destination $WebDestinationPath -Force
}

./butler.exe push $WebDestinationPath SlateyDev/plague-doctor-survivor:web

if (-not (Test-Path -Path $WinDestinationPath)) {
    New-Item -ItemType Directory -Path $WinDestinationPath | Out-Null
}

$destAssets = Join-Path $WinDestinationPath "assets"
if (-not (Test-Path -Path $destAssets)) {
    New-Item -ItemType Directory -Path $destAssets | Out-Null
}

foreach ($file in $WinFilesToZip) {
    Copy-Item -Path "$WinSourcePath\$file" -Destination $WinDestinationPath -Force
}
Copy-Item -Path "$WinAssetspath\*" -Destination $destAssets -Recurse -Force

./butler.exe push $WinDestinationPath SlateyDev/plague-doctor-survivor:win