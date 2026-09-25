FULL ROBLOX SCRIPT EXPORTER

Purpose
-------
Export saved Script, LocalScript, and ModuleScript instances from the open Studio
place. Scripts inside models and other instances keep their Studio ancestry through
filesystem paths and generated metadata. This is a script overlay for source control
and live sync.

Sources follow their Studio hierarchy under Export_FTT/src. Each script has a
named directory containing init.server.lua, init.client.lua, or init.lua. Studio
objects with Windows-incompatible names stop the export with clickable Output
warnings so you can rename them before rerunning.

The export does not include terrain, geometry, model properties, meshes, or other
assets. Keep the Roblox place as the source of truth for those. Every mapped node
uses $ignoreUnknownInstances:true or init.meta.json to preserve other Studio
children.

Excluded by design
------------------
- The TEST_PLOTS subtree.
- Any subtree with an instance name containing the literal text "_?".
- Runtime/internal roots: Players, CoreGui, CorePackages, NetworkClient,
  NetworkServer, and Stats.

How to export
-------------
1. Open the intended saved place in Roblox Studio.
2. Run Start_Full_Export_Server.cmd from this folder. It targets the existing
   ..\..\Export_FTT project.
3. In Studio, enable HTTP requests if required. Paste ConsoleCommand_full.lua
   into the Command Bar and run it.
4. Wait for the receiver to report EXPORT COMPLETE. Studio's submitted message
   confirms transfer only; the receiver confirms installation.
5. Review Export_FTT/export_manifest.json. It records scripts, ancestors,
   exclusions, and any unreadable Source failures.

The receiver stages a complete snapshot before replacing Export_FTT/src and
its project file. A failed scan leaves the previous export intact. If Windows
blocks promotion, the complete staged snapshot remains for a retry when the
receiver restarts. The receiver uses Promote_Full_Export.ps1 on Windows.

Rojo live sync
--------------
The generated default.project.json maps each service to its src folder. Generated
init.meta.json files mark Model, Part, GUI, and other non-Folder ancestors with
their original classes, preserve unknown Studio children, and carry script
properties. Inspect Rojo's initial sync preview in a copy of the place before
accepting any changes.

This is not a full place backup. A new empty place cannot be reconstructed from
it because terrain, models, and other asset properties are absent.

Operational details
-------------------
- Requires Lune on PATH and local HTTP access on port 8080.
- Duplicate sibling names or Windows-incompatible ancestry names stop the
  Studio export before sending data. Rename the clickable instances in Studio.
