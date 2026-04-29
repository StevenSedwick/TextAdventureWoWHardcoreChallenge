# WoW Classic Map Extraction Guide

This guide walks you through extracting WDT and ADT terrain files from World of Warcraft Classic Era using publicly available tools.

## Prerequisites

- World of Warcraft Classic Era client installed
- Python 3.12+ (already installed at `C:\Users\kayla\AppData\Local\Programs\Python\Python312`)
- The terrain_compiler tool (already installed via editable pip install)
- 2-5 GB of free disk space (for extracted maps)

## Step 1: Download wow.export

**wow.export** is the primary tool for extracting WoW map data.

1. Navigate to: https://wow.export/
2. Click **"Download"** button (usually in top-right or center of page)
3. Select the **Windows (.exe)** version
4. Save to a folder like `C:\wow-tools\` (create the folder if needed)
5. Extract the ZIP if it comes compressed

This gives you `wow-export.exe` or similar executable.

## Step 2: Configure wow.export for WoW Classic Era

1. **Launch wow.export.exe**
2. Look for a **"Settings"** or **"Config"** button/menu
3. Configure:
   - **WoW Path**: Point to `C:\Program Files (x86)\World of Warcraft\_classic_era_\`
   - **Output Path**: Choose an extraction folder like `C:\wow-extracted\` (create it)
   - **Build/Version**: Select **"Classic Era"** or **"WoW Classic 1.13.x"** (NOT Retail)

4. Save settings and close

## Step 3: Select Maps to Extract

1. Re-launch wow-export.exe
2. In the main interface, you should see a **map/zone list** or **file browser**
3. Look for the **"File Types"** or **"Export Options"** section
4. **Enable only these file types** (uncheck others to save space):
   - ✅ **WDT** (world definition tiles - list of which tiles exist)
   - ✅ **ADT** (actual terrain data - heights, textures, objects)
   - ❌ Uncheck: WMO, M2, Textures, Doodads, etc. (not needed for terrain-compiler)

5. In the zone/map list, select which maps you want:
   - **Azeroth** (Elwynn Forest, Westfall, Loch Modan, etc.)
   - **Kalimdor** (Teldrassil, Mulgore, etc.)
   - **Maelstrom** (or any other Classic maps)

   *Pro tip: Start with a single small zone (like Teldrassil) to test*

## Step 4: Extract Files

1. Click **"Export"** or **"Start Extract"** button
2. Wait for the progress bar to complete (5-30 minutes depending on size)
3. You should see: **✓ Done** or similar message
4. Do **NOT** close the window until fully complete

## Step 5: Verify Extraction Structure

After extraction completes, check your output folder:

```
C:\wow-extracted\
├── Azeroth\
│   ├── world.wdt
│   ├── world_0_0.adt
│   ├── world_0_1.adt
│   ├── world_1_0.adt
│   └── ... (many more ADT files)
├── Kalimdor\
│   ├── world.wdt
│   ├── world_0_0.adt
│   └── ... (many more ADT files)
```

**Key files to verify:**
- Each map folder has exactly **1 WDT file** named `world.wdt`
- Each map folder has **many ADT files** named `world_X_Y.adt` (where X,Y are tile coordinates, 0-31)
- No ADT files should be missing if the extraction worked (typically 256-1024 per large map)

## Step 6: Handle Split Variants (if present)

Some maps have "split variants" like:
- `world_0_0.adt` (base tile)
- `world_0_0_obj0.adt` (split variant for objects)
- `world_0_0_tex0.adt` (split variant for textures)

**These are automatically merged by terrain_compiler** — you don't need to do anything. Just leave them all in the same folder.

## Step 7: Run the Terrain Compiler

Once you have extracted maps, compile them to Lua format:

### For a single zone:

```powershell
cd "c:\Program Files (x86)\World of Warcraft\_classic_era_\Interface\AddOns\TextAdventurer\tools\terrain_compiler"

$pyRoot = "$env:LocalAppData\Programs\Python\Python312"
$env:Path = "$pyRoot;$pyRoot\Scripts;$env:Path"

python -m terrain_compiler `
  --input-root "C:\wow-extracted" `
  --map "Azeroth" `
  --zone-key "elwynn_forest" `
  --output "C:\wow-extracted\DFMode_Azeroth.lua"
```

**Parameters explained:**
- `--input-root`: Parent folder containing extracted map folders
- `--map`: Exact folder name (case-sensitive) like `Azeroth` or `Kalimdor`
- `--zone-key`: Identifier for your output (e.g., `elwynn_forest`, `teldrassil`, `mulgore`)
- `--output`: Where to save the compiled Lua file
- `--sample-stride`: (optional) Default 4; use 8 or 16 to reduce output file size

### Example batch compilation:

```powershell
$pyRoot = "$env:LocalAppData\Programs\Python\Python312"
$env:Path = "$pyRoot;$pyRoot\Scripts;$env:Path"

$maps = @(
    @{mapFolder="Azeroth"; zoneKey="azeroth"}
    @{mapFolder="Kalimdor"; zoneKey="kalimdor"}
)

foreach ($map in $maps) {
    python -m terrain_compiler `
      --input-root "C:\wow-extracted" `
      --map $map.mapFolder `
      --zone-key $map.zoneKey `
      --output "C:\wow-extracted\DFMode_$($map.mapFolder).lua"
    Write-Output "Compiled $($map.mapFolder)"
}
```

## Step 8: Verify Compilation Output

After compilation completes, check the output Lua file:

```powershell
# View first 50 lines
Get-Content "C:\wow-extracted\DFMode_Azeroth.lua" -Head 50

# Check file size (should be 1-50 MB depending on map and stride)
Get-Item "C:\wow-extracted\DFMode_Azeroth.lua" | Format-List Length
```

**Expected Lua structure:**
```lua
return {
  zoneKey = "azeroth",
  mapName = "Azeroth",
  mapBounds = {
    minX = -12800.0,
    maxX = 12800.0,
    minY = -12800.0,
    maxY = 12800.0
  },
  tilesPresent = {
    [0] = {[0] = true, [1] = true, ... },
    ...
  },
  chunks = {
    {
      tile_x = 0,
      tile_y = 0,
      chunk_x = 0,
      chunk_y = 0,
      world_x = -12800.0,
      world_y = 12480.0,
      sampled_heights = {9000.5, 9001.2, ... },
      sampled_slope = {0.1, 0.15, ... },
      ...
    },
    ...
  },
  markers = { ... }
}
```

## Troubleshooting

### "WDT file not found"
- **Cause**: Extraction folder structure incorrect or extraction failed
- **Fix**: Verify folder contains `world.wdt` in root of map folder
- **Check**: `Test-Path "C:\wow-extracted\Azeroth\world.wdt"`

### "No ADT files found" / "0 tiles present"
- **Cause**: ADT files didn't extract or are in wrong location
- **Fix**: Run extraction again; check that ADT files have format `world_X_Y.adt` where X,Y are 0-31
- **Check**: `Get-ChildItem "C:\wow-extracted\Azeroth\*.adt" | Measure-Object`

### Python not found
- **Cause**: PATH not set correctly
- **Fix**: Use full path: `& "C:\Users\kayla\AppData\Local\Programs\Python\Python312\python.exe" -m terrain_compiler ...`

### "Invalid ADT file" error
- **Cause**: WoW client version mismatch (e.g., extracting from Retail instead of Classic Era)
- **Fix**: Verify wow.export is configured for **Classic Era**, not Retail
- **Check**: Re-extract a single small tile and verify manually

### Compilation runs but output file is tiny (< 1 MB)
- **Cause**: Likely all ADTs were split variants with no base tiles, OR very sparse map
- **Fix**: Verify folder has `world_X_Y.adt` base files, not just `world_X_Y_obj0.adt`
- **Check**: `Get-ChildItem "C:\wow-extracted\Azeroth\world_*.adt" | Sort-Object Name | Select-Object -First 10`

## Next Steps After Compilation

1. **Test the Lua output**: Load into WoW addon environment or Lua interpreter to verify validity
2. **Copy to addon**: Move compiled `.lua` files to TextAdventurer addon folder for use
3. **Extract more maps**: Repeat for each zone you want terrain data for

## Alternative Tools

If **wow.export** doesn't work or is unavailable:

1. **WoW Model Viewer (WMV)**
   - https://github.com/wowdev/modelviewer
   - More complex setup; primarily for M2/WMO models but can export terrain

2. **Casclib** (command-line CASC reader)
   - Lower-level tool; requires manual CASC archive navigation
   - Steeper learning curve

3. **Manual Extraction via GameTools** (legacy)
   - Older tool; may not work with current WoW patches
   - Not recommended

**Recommendation**: Stick with wow.export for ease of use.

## Support

If you encounter errors:
1. Check that `C:\Program Files (x86)\World of Warcraft\_classic_era_\` exists and has `Data\` folder
2. Verify extraction shows "100% Complete" or similar before closing
3. Run compiler with `--sample-stride 8` or `16` if output is very large
4. Post exact error message if compilation fails

---

**Estimated Total Time**: 30-60 minutes (including ~20-40 min extraction time)
