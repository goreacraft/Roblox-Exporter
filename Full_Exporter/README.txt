FULL ROBLOX SCRIPT EXPORTER

Purpose
-------
Export every saved Script, LocalScript, and ModuleScript in the open Studio place,
recursively across all saved top-level services. Scripts inside Models, Parts, and
other instances keep their Studio ancestry through generated Rojo class anchors.
The result is a script overlay suitable for source control and Rojo live sync.

This does not export terrain, geometry, models' properties, meshes, or other assets.
Keep the Roblox place as the source of truth for those. In Rojo, the generated
class anchors and $ignoreUnknownInstances:false are intended to keep untracked
Studio children in anchored models while syncing tracked scripts.

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
2. Run Start_Full_Export_Server.cmd from this folder. It chooses
   ..\..\Export_FTT\FullScriptExport_Staging, then adds _1, _2, and so on if
   that folder already exists. Existing exports are left untouched.
3. In Studio, enable HTTP requests for the place if required by Studio settings.
   Open View > Command Bar, paste all of ConsoleCommand_full.lua, and run it.
4. Wait for the receiver to report EXPORT COMPLETE. If it reports INCOMPLETE, read
   server_log_full.txt and export_manifest.json. Do not treat partial output as a
   complete Git snapshot.
5. Review the manifest and compare the discovered service/script counts against
   Explorer. The manifest records every exported script, anchor, exclusion, and
   unreadable Source failure.

Generated layout
----------------
The receiver creates default.project.json and src/ only after all discovered
scripts arrive successfully. Script source files are represented as
init.server.lua, init.client.lua, or init.lua. Non-folder ancestors that contain
scripts receive init.meta.json className anchors, preserving their instance type
without trying to recreate geometry or arbitrary properties.

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
- The exporter never clears an existing output directory. Export to a new staging
  directory each time, inspect it, then promote/copy the reviewed snapshot into
  your Git working tree deliberately.

Operational details
-------------------
- Requires Lune on PATH (`lune run ...`) and local HTTP access on port 8080.
- This script communicates with localhost. Do not expose the receiver port to the
  public internet.
- Windows-incompatible or duplicate instance-name paths stop the Studio export
  before any data is sent; rename those instances or adapt the path mapping first.
