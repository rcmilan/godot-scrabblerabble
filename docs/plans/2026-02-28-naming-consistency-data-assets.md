# Naming Consistency: Data and Assets Directories Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rename Data and Assets directories and all subdirectories/files to snake_case convention, then update all 10 files that reference them.

**Architecture:** This is a three-phase refactoring:
1. Rename all PascalCase directories to snake_case (Data→data, Assets→assets, BagDistribution→bag_distribution, etc.)
2. Update all code references in 8 .gd files and 2 .tscn files that load assets
3. Verify Godot can find all resources and commit

**Tech Stack:** Godot 4.5, GDScript, git with workaround for case-insensitive filesystems

---

## Current State

**Directories to rename:**
- `Data/` → `data/`
  - `BagDistribution/` → `bag_distribution/`
  - `Dictionaries/` → `dictionaries/`
  - `Progression/` → `progression/`
  - `TileData/` → `tile_data/`
    - `tiles/` (already lowercase, no change)
- `Assets/` → `assets/`
  - `Tiles/` → `tiles/`

**Files with references to update (10 total):**

**GDScript files (8):**
1. `autoload/run_manager.gd` - 1 reference
2. `autoload/tile_bag.gd` - 1 reference
3. `scenes/debug/debug_manager.gd` - 1 reference
4. `scripts/controllers/gameplay_controller.gd` - 1 reference
5. `scripts/domain/decks/cursed_deck.gd` - 1 reference
6. `scripts/domain/decks/equal_deck.gd` - 1 reference
7. `scripts/domain/decks/standard_deck.gd` - 1 reference
8. `scripts/domain/run_builder.gd` - 2 references

**Tscn files (2):**
9. `scenes/board/board_cell.tscn` - 1 reference
10. `scenes/tile/tile.tscn` - 1 reference

---

## Task 1: Rename Data directory and subdirectories

**Files:**
- Rename: `Data/` → `data/`
- Rename: `Data/BagDistribution/` → `data/bag_distribution/`
- Rename: `Data/Dictionaries/` → `data/dictionaries/`
- Rename: `Data/Progression/` → `data/progression/`
- Rename: `Data/TileData/` → `data/tile_data/`

**Step 1: Rename Data → data (via temporary)**

```bash
cd C:\Users\suporte\Documents\dev
git mv Data data_temp
git mv data_temp data
```

Expected: Data directory renamed to data

**Step 2: Rename BagDistribution → bag_distribution**

```bash
cd C:\Users\suporte\Documents\dev\data
git mv BagDistribution bag_distribution_temp
git mv bag_distribution_temp bag_distribution
```

Expected: BagDistribution renamed to bag_distribution

**Step 3: Rename Dictionaries → dictionaries**

```bash
cd C:\Users\suporte\Documents\dev\data
git mv Dictionaries dictionaries_temp
git mv dictionaries_temp dictionaries
```

Expected: Dictionaries renamed to dictionaries

**Step 4: Rename Progression → progression**

```bash
cd C:\Users\suporte\Documents\dev\data
git mv Progression progression_temp
git mv progression_temp progression
```

Expected: Progression renamed to progression

**Step 5: Rename TileData → tile_data**

```bash
cd C:\Users\suporte\Documents\dev\data
git mv TileData tile_data_temp
git mv tile_data_temp tile_data
```

Expected: TileData renamed to tile_data

**Step 6: Commit directory renames**

```bash
cd C:\Users\suporte\Documents\dev
git commit -m "chore: rename Data directory and subdirectories to snake_case"
```

---

## Task 2: Rename Assets directory and subdirectories

**Files:**
- Rename: `Assets/` → `assets/`
- Rename: `Assets/Tiles/` → `assets/tiles/`

**Step 1: Rename Assets → assets**

```bash
cd C:\Users\suporte\Documents\dev
git mv Assets assets_temp
git mv assets_temp assets
```

Expected: Assets directory renamed to assets

**Step 2: Rename Tiles → tiles**

```bash
cd C:\Users\suporte\Documents\dev\assets
git mv Tiles tiles_temp
git mv tiles_temp tiles
```

Expected: Tiles directory renamed to tiles

**Step 3: Commit directory renames**

```bash
cd C:\Users\suporte\Documents\dev
git commit -m "chore: rename Assets directory and subdirectories to snake_case"
```

---

## Task 3: Update reference in autoload/run_manager.gd

**Files:**
- Modify: `autoload/run_manager.gd:48`

**Current code (line ~48):**
```gdscript
prog_config = load("res://Data/Progression/progression_default.tres")
```

**Step 1: Read the file**

```bash
# Review around line 48
```

**Step 2: Update reference to new path**

Replace:
```gdscript
prog_config = load("res://Data/Progression/progression_default.tres")
```

With:
```gdscript
prog_config = load("res://data/progression/progression_default.tres")
```

**Step 3: Verify file loads correctly**

```bash
cd C:\Users\suporte\Documents\dev
# No syntax check needed, reference will be verified when game runs
```

**Step 4: Commit**

```bash
git add autoload/run_manager.gd
git commit -m "fix: update Data/Progression path to data/progression in run_manager"
```

---

## Task 4: Update reference in autoload/tile_bag.gd

**Files:**
- Modify: `autoload/tile_bag.gd:5`

**Current code (line ~5):**
```gdscript
const TILE_DATA_PATH: String = "res://Data/TileData/tiles/tile_%s.tres"
```

**Step 1: Update path constant**

Replace:
```gdscript
const TILE_DATA_PATH: String = "res://Data/TileData/tiles/tile_%s.tres"
```

With:
```gdscript
const TILE_DATA_PATH: String = "res://data/tile_data/tiles/tile_%s.tres"
```

**Step 2: Commit**

```bash
git add autoload/tile_bag.gd
git commit -m "fix: update Data/TileData path to data/tile_data in tile_bag"
```

---

## Task 5: Update reference in scenes/debug/debug_manager.gd

**Files:**
- Modify: `scenes/debug/debug_manager.gd:line with tile path`

**Current code:**
```gdscript
var data_path = "res://Data/TileData/tiles/tile_%s.tres" % letter_lower
```

**Step 1: Update path string**

Replace:
```gdscript
var data_path = "res://Data/TileData/tiles/tile_%s.tres" % letter_lower
```

With:
```gdscript
var data_path = "res://data/tile_data/tiles/tile_%s.tres" % letter_lower
```

**Step 2: Commit**

```bash
git add scenes/debug/debug_manager.gd
git commit -m "fix: update Data/TileData path to data/tile_data in debug_manager"
```

---

## Task 6: Update reference in scripts/controllers/gameplay_controller.gd

**Files:**
- Modify: `scripts/controllers/gameplay_controller.gd:line with word list`

**Current code:**
```gdscript
_word_validator.load_word_list("res://Data/Dictionaries/english_words.txt")
```

**Step 1: Update path string**

Replace:
```gdscript
_word_validator.load_word_list("res://Data/Dictionaries/english_words.txt")
```

With:
```gdscript
_word_validator.load_word_list("res://data/dictionaries/english_words.txt")
```

**Step 2: Commit**

```bash
git add scripts/controllers/gameplay_controller.gd
git commit -m "fix: update Data/Dictionaries path to data/dictionaries in gameplay_controller"
```

---

## Task 7: Update references in scripts/domain/decks files (3 files)

**Files:**
- Modify: `scripts/domain/decks/cursed_deck.gd`
- Modify: `scripts/domain/decks/equal_deck.gd`
- Modify: `scripts/domain/decks/standard_deck.gd`

**Current code in each file:**
```gdscript
return load("res://Data/BagDistribution/bag_default.tres") as BagDistribution  # or bag_equal.tres for equal_deck
```

**Step 1: Update cursed_deck.gd**

Replace:
```gdscript
return load("res://Data/BagDistribution/bag_default.tres") as BagDistribution
```

With:
```gdscript
return load("res://data/bag_distribution/bag_default.tres") as BagDistribution
```

**Step 2: Update equal_deck.gd**

Replace:
```gdscript
return load("res://Data/BagDistribution/bag_equal.tres") as BagDistribution
```

With:
```gdscript
return load("res://data/bag_distribution/bag_equal.tres") as BagDistribution
```

**Step 3: Update standard_deck.gd**

Replace:
```gdscript
return load("res://Data/BagDistribution/bag_default.tres") as BagDistribution
```

With:
```gdscript
return load("res://data/bag_distribution/bag_default.tres") as BagDistribution
```

**Step 4: Commit**

```bash
git add scripts/domain/decks/cursed_deck.gd scripts/domain/decks/equal_deck.gd scripts/domain/decks/standard_deck.gd
git commit -m "fix: update Data/BagDistribution path to data/bag_distribution in deck files"
```

---

## Task 8: Update references in scripts/domain/run_builder.gd (2 references)

**Files:**
- Modify: `scripts/domain/run_builder.gd`

**Current code (2 references):**
```gdscript
var default_bag := load("res://Data/BagDistribution/bag_default.tres") as BagDistribution
var default_prog := load("res://Data/Progression/progression_default.tres") as ProgressionConfig
```

**Step 1: Update both path strings**

Replace:
```gdscript
var default_bag := load("res://Data/BagDistribution/bag_default.tres") as BagDistribution
```

With:
```gdscript
var default_bag := load("res://data/bag_distribution/bag_default.tres") as BagDistribution
```

Replace:
```gdscript
var default_prog := load("res://Data/Progression/progression_default.tres") as ProgressionConfig
```

With:
```gdscript
var default_prog := load("res://data/progression/progression_default.tres") as ProgressionConfig
```

**Step 2: Commit**

```bash
git commit -m "fix: update Data paths to data/ paths in run_builder"
```

---

## Task 9: Update reference in scenes/board/board_cell.tscn

**Files:**
- Modify: `scenes/board/board_cell.tscn:line 3`

**Current code (line 3):**
```
[ext_resource type="Texture2D" uid="uid://waorkaoff3cs" path="res://Assets/blank_tile.png" id="1_6yrkg"]
```

**Step 1: Update scene file path**

Replace:
```
path="res://Assets/blank_tile.png"
```

With:
```
path="res://assets/blank_tile.png"
```

Full line becomes:
```
[ext_resource type="Texture2D" uid="uid://waorkaoff3cs" path="res://assets/blank_tile.png" id="1_6yrkg"]
```

**Step 2: Commit**

```bash
git add scenes/board/board_cell.tscn
git commit -m "fix: update Assets path to assets in board_cell scene"
```

---

## Task 10: Update reference in scenes/tile/tile.tscn

**Files:**
- Modify: `scenes/tile/tile.tscn:line 3`

**Current code (line 3):**
```
[ext_resource type="Texture2D" uid="uid://cbdqjfwfeyp16" path="res://Assets/letter.png" id="1_5kclj"]
```

**Step 1: Update scene file path**

Replace:
```
path="res://Assets/letter.png"
```

With:
```
path="res://assets/letter.png"
```

Full line becomes:
```
[ext_resource type="Texture2D" uid="uid://cbdqjfwfeyp16" path="res://assets/letter.png" id="1_5kclj"]
```

**Step 2: Commit**

```bash
git add scenes/tile/tile.tscn
git commit -m "fix: update Assets path to assets in tile scene"
```

---

## Task 11: Final verification

**Files:**
- Verify: All files load correctly in Godot
- Verify: No remaining PascalCase directory references

**Step 1: Clear Godot cache**

```bash
cd C:\Users\suporte\Documents\dev
rm -rf .godot
```

Expected: .godot cache directory deleted

**Step 2: Verify no broken references remain**

```bash
grep -r "res://Data/" . --include="*.gd" --include="*.tscn" 2>/dev/null | grep -v ".godot"
grep -r "res://Assets/" . --include="*.gd" --include="*.tscn" 2>/dev/null | grep -v ".godot"
```

Expected: No output (no old references found)

**Step 3: Create final verification commit**

```bash
git status
# Should show clean working tree
```

Expected: No uncommitted changes

**Step 4: Verify in Godot**

- Open Godot editor
- Play the game (F5)
- Verify no resource loading errors
- Check that all tiles load correctly
- Test game flow from title screen through gameplay

**Step 5: Final summary**

All 10 files updated, all directories renamed, all references fixed. Ready for production.

---

## Summary

- **Total directories to rename:** 7
- **Total files to update:** 10
- **Total path references to fix:** 13
- **Total commits:** 13 (one per task for easy tracking/revert)

