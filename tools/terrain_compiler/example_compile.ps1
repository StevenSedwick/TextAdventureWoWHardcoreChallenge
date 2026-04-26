param(
  [Parameter(Mandatory=$true)][string]$InputRoot,
  [Parameter(Mandatory=$true)][string]$Map,
  [Parameter(Mandatory=$true)][string]$ZoneKey,
  [string]$Output = "..\..\release\DFMode_TerrainData.lua",
  [int]$SampleStride = 4
)

python -m terrain_compiler --input-root $InputRoot --map $Map --zone-key $ZoneKey --output $Output --sample-stride $SampleStride
