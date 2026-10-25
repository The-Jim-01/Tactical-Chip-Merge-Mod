TACTICAL CHIP MERGING
Version 1.0.1 | RoboCop: Rogue City | GOG 1.0.2.1 | Windows x64

FEATURES
Place three chips into Chip Merger to see the possible output percentage range
automatically. Click the output silhouette's sides to choose its connectors.
Bright means enabled; dim means disabled. A side must exist on at least one
selected input chip to be available. At least one output side must stay enabled.

The game rolls the final percentage when Merge is pressed. Changing inputs
recalculates the possible range without drawing or exposing a future roll.
Side toggles do not affect the percentage. Range endpoints are not equal odds.
Accept the chip and use it on a PCB normally. The UI uses the game's native
artwork, CRT styling and font. Long range text shrinks only enough to fit.

UPDATE FROM 1.0.0, RC4 OR AN INSTALLED BETA
1. Close the game completely.
2. Extract over the SAME installer folder used for the current installation.
   Preserve InstalledMerge.json and Recovery; overwrite package files only.
3. Run Update-Mod.cmd, then restart the game.
Do not run Setup-Runtime.cmd on an already working runtime.
The beta-only End chip generator is absent from this release. Already generated
and accepted chips remain in inventory/saves normally.

CLEAN MOD INSTALL WITH AN EXISTING VERIFIED RUNTIME
Close the game. Run the old package's Uninstall-Mod.cmd; retain UE4SS. Extract
this release to a separate permanent folder and run Install-Mod.cmd, supplying
Game\Content\Paks. Empty/log-only leftovers are accepted and logs preserved.
The internal RCRC_ChipMerge folder/entry remains for installer compatibility.

FRESH INSTALLATION
1. Close the game and extract this package to a permanent folder.
2. Run Setup-Runtime.cmd. Provide the full Game\Content\Paks path. It downloads
   the verified official UE4SS 3.0.1 release and installs the runtime into
   Game\Binaries\Win64. An internet connection is required for this step.
3. Run Install-Mod.cmd and provide the same Paks path.
4. Start the game and open Chip Merger.
Setup accepts an existing Mods directory and preserves all other mod files
and mods.txt bytes. It reuses the verified UE4SS 3.0.1 loader when available.
Other loader versions/conflicting DLLs or unsupported game archives are refused.
For an existing runtime, bUseUObjectArrayCache must already be false in
UE4SS-settings.ini; setup reports the required change instead of replacing settings.
The mod installer accepts the empty/log-only folder left by its uninstaller;
leftover scripts or other files still block installation. Preserved logs remain.
Keep this folder: its installation records and backups are needed for removal.
The fresh setup is checked locally; in-game testing used the existing runtime.

EXISTING RUNTIME / OTHER MODS
Run Setup-Runtime.cmd then Install-Mod.cmd. With the verified UE4SS 3.0.1
runtime and bUseUObjectArrayCache = false, setup reuses the loader/settings.
Install appends only RCRC_ChipMerge : 1, preserving other entries, comments,
encoding and files. A preexisting Tactical Chip Merging entry requires Update
or removal of that old entry; it is not silently duplicated or overwritten.
If mods.txt is absent, the installer creates it. No previous beta is required.
The verified legacy diagnostic-only installation remains supported.

Installing alongside other mods does not establish gameplay compatibility.
Other chip/inventory/UI/merge overrides may conflict. Different UE4SS versions
are untested; their DLLs and settings are preserved when installation is refused.
Manual installation remains possible by copying RCRC_ChipMerge to Mods and
adding RCRC_ChipMerge : 1 yourself; manual installs have no ownership record.

REMOVAL
For automated installs, close the game and run Uninstall-Mod.cmd from the same
installer folder. It removes unchanged owned mod scripts and restores the
original mods.txt when unchanged. Edited files/configuration and logs are kept.
The loader remains. If this package installed it, Uninstall-Runtime.cmd can
remove unchanged owned loader files AFTER removing the mod. It refuses removal
when it finds additional mod files. Do not use the old probe uninstaller while
this mod is installed; it owns the loader needed by the mod.
Accepted chips are ordinary game inventory items. Removing the mod does not
undo completed merges or recover consumed input chips.

SUPPORT / COMPATIBILITY
Verified target: GOG 1.0.2.1 only. Steam, other patches and Unfinished Business
are untested. The automated installer verifies the supplied archive fingerprint.
If a problem occurs, close the game, run Collect-Report.cmd and share its ZIP
with steps to reproduce and your game/mod versions. It includes available
engine/crash text, not memory dumps. Review report contents before sharing.

RELEASE VALIDATION
RC4's four recorded merges had matching selected/result sides and percentages
within their preview ranges, with no new mod errors. The tester performed
several merges and switched PCB boards twice without problems. Earlier testing
confirmed native font fit, Accept, PCB placement/stat updates and chip persistence
following checkpoint save, return to menu and save reload.

Release gameplay is identical to RC4, apart from the version string.
Version 1.0.1 changes installation to support existing Mods folders/configuration.
Coexistence fixtures cover new/reused runtimes, UTF-8/UTF-16 configuration,
missing mods.txt, preservation of other mods and exact config restoration. Local
checks cover presentation restoration, stable display without repeated repaint,
side restrictions, range calculations, native result preservation, lifecycle
cleanup, update ownership and installation/removal. The game's first launch
with a newly downloaded runtime has not been tested here; game testing used
the established verified runtime. Other platforms/patches/mods are untested.
Historical crashes are not claimed fully resolved by the release.

No game archives, artwork or fonts are distributed. Installed game assets are
used at runtime. Four readable Lua source files are included. The archive does
not include UE4SS binaries; Setup-Runtime.cmd downloads the verified prerequisite.
UE4SS is a separate third-party prerequisite:
https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/v3.0.1
