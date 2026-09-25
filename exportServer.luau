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
        
        -- Process a single item
        local function processItem(item)
            -- Check for ignore flag
            if (item.name and item.name:find("_%?")) or (item.path and item.path:find("_%?")) then
                log("Ignored (contains _?): " .. (item.name or item.path))
                return
            end
            
            -- Create directory path
            local currentPath = outputDir
            for part in item.path:gmatch("[^/]+") do
                part = part:gsub('[<>:"\\|?*]', '_')
                currentPath = currentPath .. "/" .. part
                if not fs.isDir(currentPath) then
                    fs.writeDir(currentPath)
                end
            end
            
            if item.type == "Folder" then return end
            
            local ext = ".lua"
            if item.className == "Script" then ext = ".server.lua" end
            if item.className == "LocalScript" then ext = ".client.lua" end
            local safeName = item.name:gsub('[<>:"/\\|?*]', '_')
            local filePath = currentPath .. "/" .. safeName .. ext
            
            -- Write script
            fs.writeFile(filePath, item.source)
            log("Exported: " .. item.path .. "/" .. safeName .. ext)
            
            -- Write meta.json if needed
            if item.disabled or (item.runContext and item.runContext ~= "Legacy") then
                local metaPath = currentPath .. "/" .. safeName .. ".meta.json"
                local props = {}
                if item.disabled then table.insert(props, '    "Disabled": true') end
                if item.runContext and item.runContext ~= "Legacy" then table.insert(props, '    "RunContext": "' .. item.runContext .. '"') end
                fs.writeFile(metaPath, '{\n  "properties": {\n' .. table.concat(props, ",\n") .. '\n  }\n}')
            end
        end

        if data.type == "Batch" then
            for _, item in ipairs(data.items) do
                processItem(item)
            end
        else
            processItem(data)
        end
        
        return { status = 200, body = "OK" }
    end
    
    return { status = 404, body = "Not Found" }
end)
