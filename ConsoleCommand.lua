local HttpService = game:GetService("HttpService")

local SERVICES = {
    ReplicatedFirst = "src/ReplicatedFirst",
    ReplicatedStorage = "src/ReplicatedStorage",
    ServerScriptService = "src/ServerScriptService",
    ServerStorage = "src/ServerStorage",
    ["StarterPlayer.StarterPlayerScripts"] = "src/StarterPlayer/StarterPlayerScripts",
    ["StarterPlayer.StarterCharacterScripts"] = "src/StarterPlayer/StarterCharacterScripts"
}

local MAX_CHUNK_SIZE = 800000 -- 800 KB to stay safely under 1 MB limit

local function send(path, obj)
    if obj:IsA("Folder") then
        HttpService:PostAsync("http://localhost:8080", HttpService:JSONEncode({
            type = "Folder",
            path = path .. "/" .. obj.Name
        }))
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
        
        if #source <= MAX_CHUNK_SIZE then
            HttpService:PostAsync("http://localhost:8080", HttpService:JSONEncode({
                type = "Script",
                path = path,
                name = obj.Name,
                className = obj.ClassName,
                source = source,
                disabled = obj:IsA("BaseScript") and obj.Disabled or false,
                runContext = runContext
            }))
        else
            local totalChunks = math.ceil(#source / MAX_CHUNK_SIZE)
            for i = 1, totalChunks do
                local chunk = source:sub((i-1)*MAX_CHUNK_SIZE + 1, i*MAX_CHUNK_SIZE)
                HttpService:PostAsync("http://localhost:8080", HttpService:JSONEncode({
                    type = "ScriptChunk",
                    path = path,
                    name = obj.Name,
                    className = obj.ClassName,
                    chunkIndex = i,
                    totalChunks = totalChunks,
                    source = chunk,
                    disabled = obj:IsA("BaseScript") and obj.Disabled or false,
                    runContext = runContext
                }))
            end
        end
        
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
print("✅ Export complete!")
