repeat task.wait() until game:IsLoaded()
if shared.vape then shared.vape:Uninject() end

-- why do exploits fail to implement anything correctly? Is it really that hard?
if identifyexecutor then
	if table.find({'Argon', 'Wave'}, ({identifyexecutor()})[1]) then
		getgenv().setthreadidentity = nil
	end
end

local vape
local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then
		vape:CreateNotification('shoreline', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end
local queue_on_teleport = queue_on_teleport or function() end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local cloneref = cloneref or function(obj)
	return obj
end
local playersService = cloneref(game:GetService('Players'))

local function downloadFile(path, func)
	if not isfile(path) then
		-- Check if commit.txt exists
		local commitFile = 'shoreline/profiles/commit.txt'
		if not isfile(commitFile) then
			error("commit.txt file is missing! Please make sure shoreline is properly installed.")
		end
		
		local commit = readfile(commitFile)
		if not commit or commit == '' then
			error("commit.txt is empty! Please check the commit hash.")
		end
		
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/illusionHD/OpalSolosVoidware/'..commit..'/'..select(1, path:gsub('shoreline/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error("Failed to download file: " .. (res or "Unknown error"))
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after shoreline updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function finishLoading()
	vape.Init = nil
	vape:Load()
	task.spawn(function()
		repeat
			vape:Save()
			task.wait(10)
		until not vape.Loaded
	end)

	local teleportedServers
	vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
		if (not teleportedServers) and (not shared.VapeIndependent) then
			teleportedServers = true
			local teleportScript = [[
				shared.vapereload = true
				if shared.VapeDeveloper then
					loadstring(readfile('shoreline/loader.lua'), 'loader')()
				else
					loadstring(game:HttpGet('https://raw.githubusercontent.com/illusionHD/OpalSolosVoidware/'..readfile('shoreline/profiles/commit.txt')..'/loader.lua', true), 'loader')()
				end
			]]
			if shared.VapeDeveloper then
				teleportScript = 'shared.VapeDeveloper = true\n'..teleportScript
			end
			if shared.VapeCustomProfile then
				teleportScript = 'shared.VapeCustomProfile = "'..shared.VapeCustomProfile..'"\n'..teleportScript
			end
			vape:Save()
			queue_on_teleport(teleportScript)
		end
	end))

	if not shared.vapereload then
		if not vape.Categories then return end
		if vape.Categories.Main.Options['GUI bind indicator'].Enabled then
			vape:CreateNotification('Finished Loading', vape.VapeButton and 'Press the button in the top right to open GUI' or 'Press '..table.concat(vape.Keybind, ' + '):upper()..' to open GUI', 5)
		end
	end
end

-- Check if shoreline folder structure exists
if not isfolder('shoreline') then
	makefolder('shoreline')
end
if not isfolder('shoreline/profiles') then
	makefolder('shoreline/profiles')
end
if not isfolder('shoreline/guis') then
	makefolder('shoreline/guis')
end
if not isfolder('shoreline/assets') then
	makefolder('shoreline/assets')
end
if not isfolder('shoreline/Configs') then
	makefolder('shoreline/Configs')
end

if not isfile('shoreline/profiles/gui.txt') then
	writefile('shoreline/profiles/gui.txt', 'new')
end

-- Create default commit.txt if it doesn't exist
if not isfile('shoreline/profiles/commit.txt') then
	-- You need to put your actual commit hash here
	writefile('shoreline/profiles/commit.txt', 'main') -- Change 'main' to your actual commit hash
	warn("Please update shoreline/profiles/commit.txt with the correct commit hash!")
end

local gui = readfile('shoreline/profiles/gui.txt')

if not isfolder('shoreline/assets/'..gui) then
	makefolder('shoreline/assets/'..gui)
end
if not isfolder('shoreline/Configs/'..gui) then
	makefolder('shoreline/Configs/'..gui)
end

-- Try to load the GUI with error handling
local success, err = pcall(function()
	vape = loadstring(downloadFile('shoreline/guis/'..gui..'.lua'), 'gui')()
end)

if not success then
	error("Failed to load GUI '" .. gui .. "': " .. tostring(err))
end

if not vape then
	error("GUI script '" .. gui .. "' did not return a vape object!")
end

shared.vape = vape

if not shared.VapeIndependent then
	-- Load universal scripts
	local uniSuccess, uniErr = pcall(function()
		loadstring(downloadFile('shoreline/games/universal.lua'), 'universal')()
	end)
	
	if not uniSuccess then
		warn("Failed to load universal script: " .. tostring(uniErr))
	end
	
	-- Try to load game-specific script
	local gameFile = 'shoreline/games/'..game.PlaceId..'.lua'
	if isfile(gameFile) then
		local gameSuccess, gameErr = pcall(function()
			loadstring(readfile(gameFile), tostring(game.PlaceId))()
		end)
		
		if not gameSuccess then
			warn("Failed to load game-specific script: " .. tostring(gameErr))
		end
	else
		-- Try to download if not exists
		if not shared.VapeDeveloper then
			local suc, res = pcall(function()
				return game:HttpGet('https://raw.githubusercontent.com/illusionHD/OpalSolosVoidware/'..readfile('shoreline/profiles/commit.txt')..'/games/'..game.PlaceId..'.lua', true)
			end)
			if suc and res ~= '404: Not Found' then
				local downloadSuccess, downloadErr = pcall(function()
					loadstring(downloadFile(gameFile), tostring(game.PlaceId))()
				end)
				
				if not downloadSuccess then
					warn("Failed to load downloaded game script: " .. tostring(downloadErr))
				end
			end
		end
	end
	
	-- Finish loading
	local finishSuccess, finishErr = pcall(finishLoading)
	if not finishSuccess then
		error("Failed to finish loading: " .. tostring(finishErr))
	end
else
	vape.Init = finishLoading
	return vape
end
