-- Full saved-place script inventory/export for the local Full_Exporter server.
-- Paste this script into Roblox Studio's Command Bar while the intended place is open.

local HttpService = game:GetService("HttpService")

local SERVER_URL = "http://localhost:8080"
local MAX_BATCH_BYTES = 650000
local SOURCE_CHUNK_BYTES = 60000

-- These are runtime-only or Roblox-internal roots, not saved game content.
local EXCLUDED_ROOTS = {
	Players = true,
	CoreGui = true,
	CorePackages = true,
	NetworkClient = true,
	NetworkServer = true,
}

local function shouldExcludeName(name)
	return name == "TEST_PLOTS" or string.find(name, "_?", 1, true) ~= nil
end

local function validSegment(name)
	if name == "" or name == "." or name == ".." then
		return false, "empty or relative path segment"
	end
	if string.find(name, '[<>:"/\\|?*]') or string.match(name, "[%. ]$") then
		return false, "Windows-incompatible name"
	end
	local upper = string.upper(string.gsub(name, "%..*$", ""))
	if upper == "CON" or upper == "PRN" or upper == "AUX" or upper == "NUL"
		or string.match(upper, "^COM[1-9]$") or string.match(upper, "^LPT[1-9]$") then
		return false, "reserved Windows name"
	end
	return true
end

local function append(array, value)
	if type(value) ~= "string" then
		error(string.format("Cannot append path value of type %s", typeof(value)))
	end
	local result = table.create(#array + 1)
	for i, item in ipairs(array) do
		if type(item) ~= "string" then
			error(string.format("Path segment %d is %s instead of a string", i, typeof(item)))
		end
		result[i] = item
	end
	result[#result + 1] = value
	return result
end

local function withRoot(rootName, segments)
	local result = { "src", rootName }
	for _, segment in ipairs(segments) do
		if type(segment) ~= "string" then
			error(string.format("Invalid ancestor path segment (%s): %s", typeof(segment), tostring(segment)))
		end
		result[#result + 1] = segment
	end
	return result
end

local function pathKey(segments)
	for i, segment in ipairs(segments) do
		if type(segment) ~= "string" then
			error(string.format("Invalid path segment %d (%s): %s", i, typeof(segment), tostring(segment)))
		end
	end
	return table.concat(segments, "/")
end

local function safeUtf8End(source, startIndex, maxBytes)
	local finish = math.min(#source, startIndex + maxBytes - 1)
	while finish < #source do
		local nextByte = string.byte(source, finish + 1)
		if not nextByte or nextByte < 128 or nextByte > 191 then break end
		finish = finish - 1
	end
	return finish
end

local scripts = {}
local anchors = {}
local excludedSubtrees = {}
local pathOwners = {}
local errors = {}
local roots = {}

local function walk(instance, ancestors, rootName)
	if shouldExcludeName(instance.Name) then
		excludedSubtrees[#excludedSubtrees + 1] = {
			path = instance:GetFullName(),
			reason = instance.Name == "TEST_PLOTS" and "TEST_PLOTS data export excluded" or "name contains _?",
		}
		return false
	end

	local segments = append(ancestors, instance.Name)
	local nameOk, nameReason = validSegment(instance.Name)
	if not nameOk then
		errors[#errors + 1] = instance:GetFullName() .. " cannot be represented as a Windows path: " .. nameReason
	end

	local isSource = instance:IsA("LuaSourceContainer")
	local supportedSource = instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ModuleScript")
	local containsScripts = false

	if isSource then
		if not supportedSource then
			errors[#errors + 1] = "Unsupported LuaSourceContainer class " .. instance.ClassName .. " at " .. instance:GetFullName()
		else
			local allSegments = withRoot(rootName, segments)
			scripts[#scripts + 1] = {
				instance = instance,
				segments = allSegments,
				className = instance.ClassName,
				fullName = instance:GetFullName(),
			}
			containsScripts = true
		end
	end

	for _, child in ipairs(instance:GetChildren()) do
		if walk(child, append(ancestors, instance.Name), rootName) then
			containsScripts = true
		end
	end

	if containsScripts then
		local allSegments = withRoot(rootName, segments)
		if not instance:IsA("Folder") and not isSource then
			local key = pathKey(allSegments)
			anchors[key] = { segments = allSegments, className = instance.ClassName }
		end
	end

	return containsScripts
end

for _, root in ipairs(game:GetChildren()) do
	if not EXCLUDED_ROOTS[root.Name] then
		local rootContainsScripts = false
		for _, child in ipairs(root:GetChildren()) do
			if walk(child, {}, root.Name) then rootContainsScripts = true end
		end
		if rootContainsScripts then
			local rootOk, rootReason = validSegment(root.Name)
			if not rootOk then
				errors[#errors + 1] = "Service root " .. root.Name .. " cannot be represented: " .. rootReason
			else
				roots[#roots + 1] = { name = root.Name, className = root.ClassName }
			end
		end
	end
end
if #errors > 0 then
	warn("❌ Full export stopped before sending data. Fix or rename the following unsupported paths:")
	for i = 1, math.min(#errors, 40) do warn(errors[i]) end
	if #errors > 40 then warn((#errors - 40) .. " additional path errors omitted") end
	return
end

table.sort(scripts, function(a, b) return pathKey(a.segments) < pathKey(b.segments) end)
local orderedAnchors = {}
for _, anchor in pairs(anchors) do orderedAnchors[#orderedAnchors + 1] = anchor end
table.sort(orderedAnchors, function(a, b) return pathKey(a.segments) < pathKey(b.segments) end)
table.sort(roots, function(a, b) return a.name < b.name end)

-- Folder and anchor descendants share directory prefixes, which are expected.
-- Only two different Studio instances targeting exactly the same segment path collide.
local function registerOwner(segments, description)
	local key = pathKey(segments)
	local previous = pathOwners[key]
	if previous then
		errors[#errors + 1] = "Duplicate Studio names collapse to the same file path " .. key .. " (" .. previous .. " and " .. description .. ")"
	else
		pathOwners[key] = description
	end
end

for _, anchor in ipairs(orderedAnchors) do
	registerOwner(anchor.segments, "ancestor " .. anchor.className)
end
for _, record in ipairs(scripts) do
	registerOwner(record.segments, "script " .. record.className)
end
if #errors > 0 then
	warn("❌ Full export stopped: generated paths collide after filesystem normalization.")
	for i = 1, math.min(#errors, 40) do warn(errors[i]) end
	if #errors > 40 then warn((#errors - 40) .. " additional path errors omitted") end
	return
end

local batch = {}
local batchBytes = 0
local sentScripts = 0
local function flushBatch()
	if #batch == 0 then return end
	HttpService:PostAsync(SERVER_URL, HttpService:JSONEncode({ type = "Batch", items = batch }))
	table.clear(batch)
	batchBytes = 0
end

local function queue(item)
	local encoded = HttpService:JSONEncode(item)
	if batchBytes + #encoded + 2 > MAX_BATCH_BYTES then flushBatch() end
	if #encoded + 2 > MAX_BATCH_BYTES then error("One export item exceeds the safe HTTP payload size") end
	table.insert(batch, item)
	batchBytes = batchBytes + #encoded + 2
end

HttpService:PostAsync(SERVER_URL, HttpService:JSONEncode({
	type = "Begin",
	scriptCount = #scripts,
	roots = roots,
	excludedSubtrees = excludedSubtrees,
}))

for _, anchor in ipairs(orderedAnchors) do
	queue({ kind = "Anchor", segments = anchor.segments, className = anchor.className })
end

for scriptIndex, record in ipairs(scripts) do
	local instance = record.instance
	local sourceOk, source = pcall(function() return instance.Source end)
	if not sourceOk then
		queue({
			kind = "SkippedScript",
			segments = record.segments,
			className = record.className,
			reason = tostring(source),
		})
	else
		local runContext = "Legacy"
		pcall(function()
			runContext = tostring(instance.RunContext):match("%.([^.]+)$") or "Legacy"
		end)
		local disabled = false
		pcall(function()
			disabled = instance:IsA("BaseScript") and instance.Disabled or false
		end)
		local totalChunks = math.max(1, math.ceil(#source / SOURCE_CHUNK_BYTES))
		local sourceOffset = 1
		for chunkIndex = 1, totalChunks do
			local sourceEnd = safeUtf8End(source, sourceOffset, SOURCE_CHUNK_BYTES)
			local sourcePart = sourceOffset <= #source and string.sub(source, sourceOffset, sourceEnd) or ""
			queue({
				kind = "ScriptChunk",
				segments = record.segments,
				className = record.className,
				disabled = disabled,
				runContext = runContext,
				sourceBytes = #source,
				chunkIndex = chunkIndex,
				totalChunks = totalChunks,
				sourcePart = sourcePart,
			})
			sourceOffset = sourceEnd + 1
		end
		sentScripts = sentScripts + 1
	end
	if scriptIndex % 100 == 0 or scriptIndex == #scripts then
		print(string.format("Processed %d / %d scripts (%d readable)", scriptIndex, #scripts, sentScripts))
	end
end

flushBatch()
HttpService:PostAsync(SERVER_URL, HttpService:JSONEncode({ type = "End", scriptCount = #scripts }))
print(string.format(
	"✅ Full script export submitted: %d / %d scripts readable, %d class anchors, %d excluded subtrees. Check the export server for COMPLETE status.",
	sentScripts,
	#scripts,
	#orderedAnchors,
	#excludedSubtrees
))
