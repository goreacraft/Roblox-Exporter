FULL ROBLOX SCRIPT EXPORTER

Purpose
-------
Export every saved Script, LocalScript, and ModuleScript in the open Studio place,
recursively across all saved top-level services. Scripts inside Models, Parts, and
other instances keep their Studio ancestry through the generated Rojo project tree.
The result is a script overlay suitable for source control and Rojo live sync.

Script files follow their Studio hierarchy under src. Each script gets a named
directory containing init.server.lua, init.client.lua, or init.lua. Windows-
incompatible names stop the export with a clickable Studio Output warning.
Rename those instances in Studio, then rerun the export. The generated Rojo
project maps each source file to its original Roblox path.

This does not export terrain, geometry, models' properties, meshes, or other assets.
Keep the Roblox place as the source of truth for those. In Rojo, the generated
project hierarchy and $ignoreUnknownInstances:false settings are intended to keep
untracked Studio children in mapped instances while syncing tracked scripts.

Excluded by design
------------------
- The TEST_PLOTS subtree.
- Any subtree with an instance name containing the literal text "_?".
- Runtime/internal roots: Players, CoreGui, CorePackages, NetworkClient,
  NetworkServer.

How to export
-------------
1. Open the intended saved place in Roblox Studio. Ensure scripts are saved and
   that you can read their Source properties.
2. Run Start_Full_Export_Server.cmd from this folder. It always targets the existing
   ..\..\Export_FTT project. It does not create numbered export folders.
3. In Studio, enable HTTP requests for the place if required by Studio settings.
   Open View > Command Bar, paste all of ConsoleCommand_full.lua, and run it.
4. Wait for the receiver to report EXPORT COMPLETE. If it reports INCOMPLETE, read
   server_log_full.txt. The current Export_FTT/src and default.project.json remain
   unchanged on an incomplete export.
5. Review the manifest and compare the discovered service/script counts against
   Explorer. The manifest records every exported script, anchor, exclusion, and
   unreadable Source failure.

On Windows the receiver uses Promote_Full_Export.ps1 to install a complete staged
export. If promotion reports Access is denied, close views holding Export_FTT/src
and restart the receiver. The complete staged export is kept for that retry.

Generated layout
----------------
The receiver stages files in a temporary folder inside Export_FTT. Only after all
discovered scripts arrive successfully, it replaces Export_FTT/src and
default.project.json, then removes old numbered FullScriptExport_Staging folders.
Every script is stored under its service, ancestor, and script name. The project
tree maps that source file back to its original script name, class, and parent path. Ancestors are represented in the project tree with their
class names and ignoreUnknownInstances:false; geometry and other properties are
not reconstructed.

Rojo limitations and safe use
-----------------------------
- This is an overlay for script source, not a full place backup/rebuild. A fresh
  empty place cannot be reconstructed from it because terrain, models, and their
  properties are deliberately absent.
- Use the place that already contains the world when connecting Rojo. Check the
  Rojo sync details for how unmatched instances and $ignoreUnknownInstances work.
- Never use a destructive sync mode or an empty project mapping against the live
  place. First inspect the generated project and manifest and test against a copy
  of the place. Keep a Studio version history/backup before initial sync.
- On a COMPLETE result, the exporter replaces the whole generated Export_FTT/src
  tree. This removes files left by older partial exports and files no longer in the
  place. It keeps the previous src and project file until the new export completes.
ULL ROBLOX SCRIPT EXPORTER

Purpose
-------
Export every saved Script, LocalScript, and ModuleScript in the open Studio place,
recursively across all saved top-level services. Scripts inside Models, Parts, and
other instances keep their Studio ancestry through the generated Rojo project tree.
The result is a script overlay suitable for source control and Rojo live sync.

Script files follow their Studio hierarchy under src. Each script gets a named
directory containing init.server.lua, init.client.lua, or init.lua. Windows-
incompatible names stop the export with a clickable Studio Output warning.
Rename those instances in Studio, then rerun the export. The generated Rojo
project maps each source file to its original Roblox path.

This does not export terrain, geometry, models' properties, meshes, or other assets.
Keep the Roblox place as the source of truth for those. In Rojo, the generated
project hierarchy and $ignoreUnknownInstances:false settings are intended to keep
untracked Studio children in mapped instances while syncing tracked scripts.

Excluded by design
------------------
- The TEST_PLOTS subtree.
- Any subtree with an instance name containing the literal text "_?".
- Runtime/internal roots: Players, CoreGui, CorePackages, NetworkClient,
  NetworkServer.

How to export
-------------
1. Open the intended saved place in Roblox Studio. Ensure scripts are saved and
   that you can read their Source properties.
2. Run Start_Full_Export_Server.cmd from this folder. It always targets the existing
   ..\..\Export_FTT project. It does not create numbered export folders.
3. In Studio, enable HTTP requests for the place if required by Studio settings.
   Open View > Command Bar, paste all of ConsoleCommand_full.lua, and run it.
4. Wait for the receiver to report EXPORT COMPLETE. If it reports INCOMPLETE, read
   server_log_full.txt. The current Export_FTT/src and default.project.json remain
   unchanged on an incomplete export.
5. Review the manifest and compare the discovered service/script counts against
   Explorer. The manifest records every exported script, anchor, exclusion, and
   unreadable Source failure.

On Windows the receiver uses Promote_Full_Export.ps1 to install a complete staged
export. If promotion reports Access is denied, close views holding Export_FTT/src
and restart the receiver. The complete staged export is kept for that retry.

Generated layout
----------------
The receiver stages files in a temporary folder inside Export_FTT. Only after all
discovered scripts arrive successfully, it replaces Export_FTT/src and
default.project.json, then removes old numbered FullScriptExport_Staging folders.
Every script is stored under its service, ancestor, and script name. The project
tree maps that source file back to its original script name, class, and parent path. Ancestors are represented in the project tree with their
class names and ignoreUnknownInstances:false; geometry and other properties are
not reconstructed.

Rojo limitations and safe use
-----------------------------
- This is an overlay for script source, not a full place backup/rebuild. A fresh
  empty place cannot be reconstructed from it because terrain, models, and their
  properties are deliberately absent.
- Use the place that already contains the world when connecting Rojo. Check the
  Rojo sync details for how unmatched instances and $ignoreUnknownInstances work.
- Never use a destructive sync mode or an empty project mapping against the live
  place. First inspect the generated project and manifest and test against a copy
  of the place. Keep a Studio version history/backup before initial sync.
- On a COMPLETE result, the exporter replaces the whole generated Export_FTT/src tree. This removes files left by older partial exports and files no longer in the place. It keeps the previous src and project file until the new export completes.

Operational details
-------------------
- Requires Lune on PATH (`lune run ...`) and local HTTP access on port 8080.
- This script communicates with localhost. Do not expose the receiver port to the
  public internet.
- Duplicate instance-name paths stop the Studio export before any data is sent;
  rename those instances in Studio first.
