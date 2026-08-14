local net = require("@lune/net")
local fs = require("@lune/fs")
local process = require("@lune/process")

local outputDir = process.args[1] or "../Export_FTT"

-- Clear the log file from the previous run
fs.writeFile("server_log.txt", "")

print("==================================================")
print("Starting extraction server on http://localhost:8080")
print("Exporting all files to: " .. outputDir)
print("==================================================")
print("Waiting for Roblox Studio to send data...")

local function log(msg)
    print(msg)
    fs.writeFile("server_log.txt", (fs.isFile("server_log.txt") and fs.readFile("server_log.txt") or "") .. msg .. "\n")
end

net.serve(8080, function(request)
    if request.method == "OPTIONS" then
        return { status = 200, headers = { ["Access-Control-Allow-Origin"] = "*", ["Access-Control-Allow-Headers"] = "*" } }
    end
    
    if request.method == "POST" then
        local bodyType = type(request.body)
        local bodyStr = bodyType == "buffer" and buffer.tostring(request.body) or tostring(request.body)
        
        local success, data = pcall(function() return require("@lune/serde").decode("json", bodyStr) end)
        if not success or type(data) ~= "table" then 
            log("ERROR: Failed to decode JSON! Body type: " .. bodyType .. ", Body length: " .. #bodyStr)
            log("Body snippet: " .. bodyStr:sub(1, 100))
            return { status = 200, body = "OK, but failed to parse" } 
        end
        
        -- Check for ignore flag
        if (data.name and data.name:find("_%?")) or (data.path and data.path:find("_%?")) then
            log("Ignored (contains _?): " .. (data.name or data.path))
            return { status = 200, body = "Ignored" }
        end
        
        -- Create directory path
        local currentPath = outputDir
        for part in data.path:gmatch("[^/]+") do
            part = part:gsub('[<>:"\\|?*]', '_') -- sanitize folder name
            currentPath = currentPath .. "/" .. part
            if not fs.isDir(currentPath) then
                fs.writeDir(currentPath)
            end
        end
        
        if data.type == "Folder" then
            return { status = 200, body = "OK" }
        end
        
        local ext = ".lua"
        if data.className == "Script" then ext = ".server.lua" end
        if data.className == "LocalScript" then ext = ".client.lua" end
        local safeName = data.name:gsub('[<>:"/\\|?*]', '_')
        local filePath = currentPath .. "/" .. safeName .. ext
        
        if data.type == "ScriptChunk" then
            if data.chunkIndex == 1 then
                fs.writeFile(filePath, data.source)
            else
                fs.writeFile(filePath, fs.readFile(filePath) .. data.source)
            end
            
            if data.chunkIndex == data.totalChunks then
                log("Exported Chunked: " .. data.path .. "/" .. safeName .. ext)
                if data.disabled or (data.runContext and data.runContext ~= "Legacy") then
                    local metaPath = currentPath .. "/" .. safeName .. ".meta.json"
                    local props = {}
                    if data.disabled then table.insert(props, '    "Disabled": true') end
                    if data.runContext and data.runContext ~= "Legacy" then table.insert(props, '    "RunContext": "' .. data.runContext .. '"') end
                    fs.writeFile(metaPath, '{\n  "properties": {\n' .. table.concat(props, ",\n") .. '\n  }\n}')
                end
            end
            return { status = 200, body = "OK" }
        end
        
        -- Write normal script
        fs.writeFile(filePath, data.source)
        log("Exported: " .. data.path .. "/" .. safeName .. ext)
        
        -- Write meta.json if needed
        if data.disabled or (data.runContext and data.runContext ~= "Legacy") then
            local metaPath = currentPath .. "/" .. safeName .. ".meta.json"
            local props = {}
            if data.disabled then table.insert(props, '    "Disabled": true') end
            if data.runContext and data.runContext ~= "Legacy" then table.insert(props, '    "RunContext": "' .. data.runContext .. '"') end
            fs.writeFile(metaPath, '{\n  "properties": {\n' .. table.concat(props, ",\n") .. '\n  }\n}')
        end
        
        return { status = 200, body = "OK" }
    end
    
    return { status = 404, body = "Not Found" }
end)
