local net = require("@lune/net")
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local outputDir = (process.args[1] or "../Export_FTT/FullScriptExport_Staging"):gsub("\\", "/")
local logPath = "server_log_full.txt"
local pendingScripts = {}
local exportedScripts = {}
local exportedAnchors = {}
local treeRoots = {}
local scriptFileOwners = {}
local exportFailures = {}
local roots = {}
local expectedScripts = 0
local excludedSubtrees = {}
local exportStarted = false
local exportFinished = false

fs.writeFile(logPath, "")

local function log(message)
	print(message)
	fs.writeFile(logPath, (fs.isFile(logPath) and fs.readFile(logPath) or "") .. message .. "\n")
end

local function ensureDir(path)
	if not fs.isDir(path) then fs.writeDir(path) end
end

local function pathFor(segments)
	return table.concat(segments, "/")
end

local function pathKey(segments)
	local parts = {}
	for _, segment in ipairs(segments) do
		parts[#parts + 1] = tostring(#segment) .. ":" .. segment
	end
	return table.concat(parts, "|")
end


local function scriptFilePath(segments, className)
	local key = pathKey(segments)
	local hash = 2166136261
	for i = 1, #key do
		hash = (hash * 31 + string.byte(key, i)) % 4294967296
	end
	local ext = className == "Script" and ".server.lua"
		or className == "LocalScript" and ".client.lua"
		or ".lua"
	local filename = string.format("src/scripts/%08x%s", hash, ext)
	local previous = scriptFileOwners[filename]
	if previous and previous ~= key then
		return nil, "script source path hash collision between " .. previous .. " and " .. key
	end
	scriptFileOwners[filename] = key
	return filename
end

local function ensureTreeNode(segments, className)
	local rootName = segments[2]
	local node = treeRoots[rootName]
	if not node then
		node = { className = nil, children = {} }
		treeRoots[rootName] = node
	end
	for i = 3, #segments do
		local name = segments[i]
		local child = node.children[name]
		if not child then
			child = { className = "Folder", children = {} }
			node.children[name] = child
		end
		node = child
	end
	if className then node.className = className end
	return node
end

local function writeAnchor(item)
	local node = ensureTreeNode(item.segments, item.className)
	local key = pathKey(item.segments)
	exportedAnchors[key] = { path = pathFor(item.segments), segments = item.segments, className = item.className }
	return node ~= nil
end

local function scriptExtension(className)
	if className == "Script" then return "server" end
	if className == "LocalScript" then return "client" end
	if className == "ModuleScript" then return "module" end
	return nil
end

local function finishScript(key, pending)
	local item = pending.item
	local ext = scriptExtension(item.className)
	if not ext then
		log("ERROR: unsupported LuaSourceContainer class " .. tostring(item.className) .. " at " .. key)
		return false
	end
	local properties = {}
	if item.disabled then properties.Disabled = true end
	if item.runContext and item.runContext ~= "Legacy" then properties.RunContext = item.runContext end
	local filePath, pathError = scriptFilePath(item.segments, item.className)
	if not filePath then
		log("ERROR: " .. pathError)
		return false
	end
	ensureDir(outputDir .. "/src/scripts")
	fs.writeFile(outputDir .. "/" .. filePath, table.concat(pending.chunks))
	local node = ensureTreeNode(item.segments, item.className)
	node.sourcePath = filePath
	node.properties = properties
	exportedScripts[key] = {
		path = pathFor(item.segments),
		segments = item.segments,
		filePath = filePath,
		className = item.className,
		disabled = item.disabled,
		runContext = item.runContext,
		sourceBytes = item.sourceBytes,
	}
	return true
end

local function processItem(item)
	if item.kind == "Anchor" then
		return writeAnchor(item)
	elseif item.kind == "SkippedScript" then
		exportFailures[#exportFailures + 1] = {
			path = pathFor(item.segments),
			segments = item.segments,
			className = item.className,
			reason = item.reason or "Source unavailable",
		}
		log("ERROR: skipped unreadable script " .. pathFor(item.segments) .. ": " .. tostring(item.reason))
		return true
	elseif item.kind == "ScriptChunk" then
		local key = pathKey(item.segments)
		local pending = pendingScripts[key]
		if not pending then
			pending = { item = item, chunks = table.create(item.totalChunks), received = 0 }
			pendingScripts[key] = pending
		end
		if pending.item.totalChunks ~= item.totalChunks or pending.chunks[item.chunkIndex] ~= nil then
			log("ERROR: duplicate or inconsistent source chunk for " .. key)
			return false
		end
		pending.chunks[item.chunkIndex] = item.sourcePart
		pending.received = pending.received + 1
		if pending.received == item.totalChunks then
			for i = 1, item.totalChunks do
				if pending.chunks[i] == nil then return true end
			end
			pending.item = item
			return finishScript(key, pending)
		end
	end
	return true
end

local function writeProjectAndManifest(complete)
	table.sort(roots, function(a, b) return a.name < b.name end)
	local tree = {
		["$className"] = "DataModel",
		["$ignoreUnknownInstances"] = false,
	}
	local function serializeNode(node)
		local description = {
			["$className"] = node.className or "Folder",
			["$ignoreUnknownInstances"] = false,
		}
		if node.sourcePath then description["$path"] = node.sourcePath end
		if node.properties and next(node.properties) then description["$properties"] = node.properties end
		for childName, child in pairs(node.children) do
			description[childName] = serializeNode(child)
		end
		return description
	end
	local rootManifest = {}
	for _, root in ipairs(roots) do
		local node = treeRoots[root.name] or { children = {} }
		node.className = root.className
		tree[root.name] = serializeNode(node)
		rootManifest[#rootManifest + 1] = { name = root.name, className = root.className }
	end
	if complete then
		fs.writeFile(outputDir .. "/default.project.json", serde.encode("json", {
			name = "Full script overlay export",
			emitLegacyScripts = true,
			tree = tree,
		}))
	end

	local scriptManifest = {}
	for path, data in pairs(exportedScripts) do
		scriptManifest[#scriptManifest + 1] = {
			path = data.path,
			segments = data.segments,
			filePath = data.filePath,
			className = data.className,
			disabled = data.disabled,
			runContext = data.runContext,
			sourceBytes = data.sourceBytes,
			status = "exported",
		}
	end
	table.sort(scriptManifest, function(a, b) return a.path < b.path end)

	local anchorManifest = {}
	for _, data in pairs(exportedAnchors) do
		anchorManifest[#anchorManifest + 1] = data
	end
	table.sort(anchorManifest, function(a, b) return a.path < b.path end)

	local manifest = {
		status = complete and "COMPLETE" or "INCOMPLETE",
		generatedBy = "Full_Exporter",
		expectedScriptCount = expectedScripts,
		exportedScriptCount = #scriptManifest,
		unassembledScriptCount = expectedScripts - #scriptManifest,
		failedScriptCount = #exportFailures,
		failedScripts = exportFailures,
		roots = rootManifest,
		excludedSubtrees = excludedSubtrees,
		anchors = anchorManifest,
		scripts = scriptManifest,
		limitations = {
			"This is a script overlay. Non-script geometry and properties are not exported.",
			"Model and other non-folder parents are class anchors; unknown Studio children are preserved when live-synced.",
		},
	}
	fs.writeFile(outputDir .. "/export_manifest.json", serde.encode("json", manifest))
end

if fs.isDir(outputDir) or fs.isFile(outputDir) then
	error("Export target already exists: " .. outputDir .. ". Rename it or choose a new staging path; this exporter never clears an existing target.")
end
ensureDir(outputDir)
log("Full script export server listening on http://localhost:8080")
log("Staging output: " .. outputDir)
log("Waiting for Studio inventory...")

net.serve(8080, function(request)
	local cors = {
		["Access-Control-Allow-Origin"] = "*",
		["Access-Control-Allow-Headers"] = "*",
		["Access-Control-Allow-Methods"] = "POST, OPTIONS",
	}
	if request.method == "OPTIONS" then return { status = 200, headers = cors } end
	if request.method ~= "POST" then return { status = 404, body = "Not Found" } end
	if exportFinished then
		return { status = 409, body = "Export already finished; restart with a new staging directory" }
	end
	local bodyType = type(request.body)
	local body = bodyType == "buffer" and buffer.tostring(request.body) or tostring(request.body)
	local ok, data = pcall(function() return serde.decode("json", body) end)
	if not ok or type(data) ~= "table" then
		log("ERROR: failed to decode JSON request")
		return { status = 400, headers = cors, body = "Invalid JSON" }
	end
	if data.type == "Begin" then
		if exportStarted then return { status = 409, headers = cors, body = "Export already started" } end
		exportStarted = true
		expectedScripts = data.scriptCount or 0
		roots = data.roots or {}
		excludedSubtrees = data.excludedSubtrees or {}
		log("Inventory received: " .. expectedScripts .. " scripts; " .. #excludedSubtrees .. " excluded subtrees")
	elseif data.type == "Batch" then
		if not exportStarted then return { status = 409, headers = cors, body = "Send Begin first" } end
		for _, item in ipairs(data.items or {}) do processItem(item) end
	elseif data.type == "End" then
		local missing = 0
		for key, pending in pairs(pendingScripts) do
			if not exportedScripts[key] then
				missing = missing + 1
				log("ERROR: incomplete source chunks for " .. key .. " (" .. pending.received .. "/" .. pending.item.totalChunks .. ")")
			end
		end
		local complete = data.scriptCount == expectedScripts and missing == 0 and #exportFailures == 0 and (function()
			local count = 0
			for _ in pairs(exportedScripts) do count = count + 1 end
			return count == expectedScripts
		end)()
		writeProjectAndManifest(complete)
		exportFinished = true
		if complete then
			log("EXPORT COMPLETE: " .. expectedScripts .. " scripts in " .. outputDir)
			log("Review export_manifest.json, then build with: rojo build default.project.json -o preview.rbxlx")
		else
			log("EXPORT INCOMPLETE: expected " .. expectedScripts .. " scripts, received " .. tostring(data.scriptCount) .. "; " .. #exportFailures .. " source failures; see export_manifest.json")
		end
	else
		return { status = 400, headers = cors, body = "Unknown message type" }
	end
	return { status = 200, headers = cors, body = "OK" }
end)
