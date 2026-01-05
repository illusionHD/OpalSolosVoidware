local vape = shared.vape
local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then 
		vape:CreateNotification('OSVPrivate', 'Failed to load : '..err, 30, 'alert') 
	end
	return res
end
local isfile = isfile or function(file)
	local suc, res = pcall(function() 
		return readfile(file) 
	end)
	return suc and res ~= nil and res ~= ''
end
local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function() 
			return game:HttpGet('https://raw.githubusercontent.com/illusionHD/OpalSolosVoidware/'..readfile('OSVPrivate/profiles/commit.txt')..'/'..select(1, path:gsub('OSVPrivate/', '')), true) 
		end)
		if not suc or res == '404: Not Found' then 
			error(res) 
		end
		if path:find('.lua') then 
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res 
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

vape.Place = 6872274481
if isfile('OSVPrivate/games/'..vape.Place..'.lua') then
	loadstring(readfile('OSVPrivate/games/'..vape.Place..'.lua'), 'bedwars')()
else
	if not shared.VapeDeveloper then
		local suc, res = pcall(function() 
			return game:HttpGet('https://raw.githubusercontent.com/illusionHD/OpalSolosVoidware/'..readfile('OSVPrivate/profiles/commit.txt')..'/games/'..vape.Place..'.lua', true) 
		end)
		if suc and res ~= '404: Not Found' then
			loadstring(downloadFile('OSVPrivate/games/'..vape.Place..'.lua'), 'bedwars')()
		end
	end
end
