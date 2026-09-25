local HttpService = game:GetService("HttpService")

local SERVICES = {
    ReplicatedFirst = "src/ReplicatedFirst",
    ReplicatedStorage = "src/ReplicatedStorage",
    ServerScriptService = "src/ServerScriptService",
    ServerStorage = "src/ServerStorage",
    ["StarterPlayer.StarterPlayerScripts"] = "src/StarterPlayer/StarterPlayerScripts",
    ["StarterPlayer.StarterCharacterScripts"] = "src/StarterPlayer/StarterCharacterScripts"
}

local MAX_PAYLOAD_SIZE = 800000 -- 800 KB to stay safely under 1 MB limit

local batch = {}
local batchSize = 0

local function flushBatch()
    if #batch > 0 then
        HttpService:PostAsync("http://localhost:8080", HttpService:JSONEncode({
            type = "Batch",
            items = batch
        }))
        table.clear(batch)
        batchSize = 0
    end
end

local function queueData(data)
    local json = HttpService:JSONEncode(data)
    if batchSize + #json > MAX_PAYLOAD_SIZE then
        flushBatch()
    end
    table.insert(batch, data)
    batchSize = batchSize + #json + 2 -- plus 2 for commas
end

local function send(path, obj)
    if obj:IsA("Folder") then
        queueData({
            type = "Folder",
            path = path .. "/" .. obj.Name
        })
        for _, child in ipairs(obj:GetChildren()) do
            send(path .. "/" .. obj.Name, child)
        end
    elseif obj:IsA("LuaSourceContainer") then
        local runContext = "Legacy"
        pcall(function() runContext = tostring(obj.RunContext):match("%.([^.]+)$") or "Legacy" end)
        
        local source = obj.Source
        local sizeKB = math.floor(#source / 1024)
        
        -- WARN FOR BIG FILES
        if sizeKB > 500 then
            warn("⚠️ SKIPPED MASSIVE SCRIPT: " .. obj:GetFullName() .. " (" .. sizeKB .. " KB) - Raw database file.")
            for _, child in ipairs(obj:GetChildren()) do
                send(path .. "/" .. obj.Name, child)
            end
            return
        end
        
        queueData({
            type = "Script",
            path = path,
            name = obj.Name,
            className = obj.ClassName,
            source = source,
            disabled = obj:IsA("BaseScript") and obj.Disabled or false,
            runContext = runContext
        })
        
        for _, child in ipairs(obj:GetChildren()) do
            send(path .. "/" .. obj.Name, child)
        end
    end
end

for servicePath, exportPath in pairs(SERVICES) do
    local parts = string.split(servicePath, ".")
    local obj = game:GetService(parts[1])
    if obj and parts[2] then obj = obj:FindFirstChild(parts[2]) end
    
    if obj then
        for _, child in ipairs(obj:GetChildren()) do
            send(exportPath, child)
        end
    end
end
flushBatch()
print("✅ Export complete!")
