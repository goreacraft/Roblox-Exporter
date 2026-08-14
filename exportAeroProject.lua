-- remodel run exportAeroProject.lua "./Main_MapPlace.rbxl" "Main_MapPlace"

-- Documentation: https://github.com/rojo-rbx/remodel

--[[ for i = 1, select("#", ...) do
	print("Arg", i, (select(i, ...)))
end ]]
local inputFile = select(1, ...)
if not inputFile then
    print("Usage: remodel run exportAeroProject.lua <input-file.rbxl[x]> [output-directory]")
    return
end

-- Try to find the file if no extension is provided
if not pcall(remodel.isFile, inputFile) or not remodel.isFile(inputFile) then
    if pcall(remodel.isFile, inputFile .. ".rbxlx") and remodel.isFile(inputFile .. ".rbxlx") then
        inputFile = inputFile .. ".rbxlx"
    elseif pcall(remodel.isFile, inputFile .. ".rbxl") and remodel.isFile(inputFile .. ".rbxl") then
        inputFile = inputFile .. ".rbxl"
    else
        print("Error: No Roblox file found at path: " .. inputFile)
        return
    end
end

-- Determine the output directory
local outputDir = select(2, ...)
if not outputDir then
    -- Default to the file name without extension
    outputDir = inputFile:match("(.+)[.][^.]+$") or inputFile
end

print("Exporting " .. inputFile .. " to folder " .. outputDir)

local game = remodel.readPlaceFile(inputFile)

-- A map to convert script ClassNames to their correct file extensions for Rojo.
local SCRIPT_EXTENSIONS = {
	ModuleScript = ".lua",
	Script = ".server.lua",
	LocalScript = ".client.lua",
}

-- A map to convert the integer value of RunContext to its string representation.
local RUN_CONTEXT_MAP = {
	[0] = "Legacy",
	[2] = "Client",
	[3] = "Server",
}

local function outputChildren(value, pathFolder)
    for _, child in ipairs(value:GetChildren()) do
		local clasName = child.ClassName
        if clasName == "ModuleScript" or clasName == "Script" or clasName == "LocalScript" then
            local source = remodel.getRawProperty(child, "Source")
            local isScript = false
			local extension = SCRIPT_EXTENSIONS[clasName] or ".lua"

			if clasName == "Script" then
                isScript = true
			end		
            local success, isFolder = true, false
            if #child:GetChildren() > 0 then
                isFolder = true
                remodel.createDirAll(pathFolder..child.Name)
                outputChildren(child, pathFolder.. child.Name.."/")
            else
				success, err = pcall(function()
					remodel.writeFile(pathFolder.. child.Name..extension, source)
				end)
                if not success then
					print("SKIP file", pathFolder..child.Name, err)
				end
            end
            if isScript and success then
                -- Correctly get the 'Disabled' property. This will be 'true' if the script is disabled.
                local isDisabled = false
                local runContext = "Legacy" -- Default value

                -- Directly access properties
                isDisabled = remodel.getRawProperty(child, "Disabled") or false -- Ensure a boolean value
                -- For Enums, remodel throws an error, so we must wrap it in a pcall
                local success, rawRunContext = pcall(remodel.getRawProperty, child, "RunContext")
                if success and rawRunContext ~= nil then
                    runContext = RUN_CONTEXT_MAP[rawRunContext] or "Legacy"
                else
                    runContext = "Legacy"
                end
                -- This is how you set 'Disabled' on the new file:
                -- If the script is disabled, write a.meta.json file for it.
                local metaFileName
                if isFolder then
                    metaFileName = pathFolder.. child.Name.. "/init.meta.json"                        
                else
                    metaFileName = pathFolder.. child.Name ..".meta.json"
                end

                if isDisabled == true or (runContext and runContext ~= "Legacy") then
                    local properties = {}
                    if isDisabled == true then
                        print("Found Disabled File, creating meta file for: ".. child.Name)
                        table.insert(properties, '    "Disabled": true')
                    end

                    if runContext and runContext ~= "Legacy" then
                        print("Found RunContext File, creating meta file for: ".. child.Name)
                        table.insert(properties, '    "RunContext": "'..runContext..'"')
                    end

                    local metaContent = '{\n  "properties": {\n' .. table.concat(properties, ",\n") .. '\n  }\n}'
                    -- Write the meta file to the disk.
                    remodel.writeFile(metaFileName, metaContent)
                end
            end
        elseif child.ClassName == "Folder" then
            remodel.createDirAll(pathFolder..child.Name)
            outputChildren(child, pathFolder.. child.Name.."/")
        end
    end
end

-- Define the services and their paths to be exported in a configuration table.
local SERVICES_TO_EXPORT = {
    { Service = "ReplicatedFirst", Path = "/src/ReplicatedFirst" },
    { Service = "ReplicatedStorage", Path = "/src/ReplicatedStorage" },
    { Service = "ServerScriptService", Path = "/src/ServerScriptService" },
    { Service = "ServerStorage", Path = "/src/ServerStorage" },
    { Service = "StarterPlayer.StarterPlayerScripts", Path = "/src/StarterPlayer/StarterPlayerScripts" },
    { Service = "StarterPlayer.StarterCharacterScripts", Path = "/src/StarterPlayer/StarterCharacterScripts" },
}

for _, config in ipairs(SERVICES_TO_EXPORT) do
    local service = game:FindFirstChild(config.Service, true)
    if service then
        local targetPath = outputDir .. config.Path .. "/"
        remodel.createDirAll(targetPath)
        outputChildren(service, targetPath)
    else
        print("Warning: Could not find service '" .. config.Service .. "' to export.")
    end
end