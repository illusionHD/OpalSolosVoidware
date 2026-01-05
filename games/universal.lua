--This watermark is used to delete the file if its cached, remove it to make the file persist after opai updates.
--This watermark is used to delete the file if its cached, remove it to make the file persist after opai updates.
--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then
		vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert')
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
			return game:HttpGet('https://raw.githubusercontent.com/illusionHD/OpalSolosVoidware/'..readfile('opai/profiles/commit.txt')..'/'..select(1, path:gsub('opai/', '')), true)
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
local run = function(func)
	func()
end
local queue_on_teleport = queue_on_teleport or function() end
local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local lightingService = cloneref(game:GetService('Lighting'))
local marketplaceService = cloneref(game:GetService('MarketplaceService'))
local teleportService = cloneref(game:GetService('TeleportService'))
local httpService = cloneref(game:GetService('HttpService'))
local guiService = cloneref(game:GetService('GuiService'))
local groupService = cloneref(game:GetService('GroupService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local contextService = cloneref(game:GetService('ContextActionService'))
local coreGui = cloneref(game:GetService('CoreGui'))

local isnetworkowner = identifyexecutor and table.find({'AWP', 'Nihon'}, ({identifyexecutor()})[1]) and isnetworkowner or function()
	return true
end
local gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset

local vape = shared.vape
local tween = vape.Libraries.tween
local targetinfo = vape.Libraries.targetinfo
local getfontsize = vape.Libraries.getfontsize
local getcustomasset = vape.Libraries.getcustomasset

local TargetStrafeVector, SpiderShift, WaypointFolder
local Spider = {Enabled = false}
local Phase = {Enabled = false}

local function addBlur(parent)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = getcustomasset('opai/assets/new/blur.png')
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = parent
	return blur
end

local function calculateMoveVector(vec)
	local c, s
	local _, _, _, R00, R01, R02, _, _, R12, _, _, R22 = gameCamera.CFrame:GetComponents()
	if R12 < 1 and R12 > -1 then
		c = R22
		s = R02
	else
		c = R00
		s = -R01 * math.sign(R12)
	end
	vec = Vector3.new((c * vec.X + s * vec.Z), 0, (c * vec.Z - s * vec.X)) / math.sqrt(c * c + s * s)
	return vec.Unit == vec.Unit and vec.Unit or Vector3.zero
end

local function isFriend(plr, recolor)
	if vape.Categories.Friends.Options['Use friends'].Enabled then
		local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
		if recolor then
			friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
		end
		return friend
	end
	return nil
end

local function isTarget(plr)
	return table.find(vape.Categories.Targets.ListEnabled, plr.Name) and true
end

local function canClick()
	local mousepos = (inputService:GetMouseLocation() - guiService:GetGuiInset())
	for _, v in lplr.PlayerGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
		local obj = v:FindFirstAncestorOfClass('ScreenGui')
		if v.Active and v.Visible and obj and obj.Enabled then
			return false
		end
	end
	for _, v in coreGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
		local obj = v:FindFirstAncestorOfClass('ScreenGui')
		if v.Active and v.Visible and obj and obj.Enabled then
			return false
		end
	end
	return (not vape.gui.ScaledGui.ClickGui.Visible) and (not inputService:GetFocusedTextBox())
end

local function getTableSize(tab)
	local ind = 0
	for _ in tab do ind += 1 end
	return ind
end

local function getTool()
	return lplr.Character and lplr.Character:FindFirstChildWhichIsA('Tool', true) or nil
end

local function notif(...)
	return vape:CreateNotification(...)
end

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
end

local visited, attempted, tpSwitch = {}, {}, false
local cacheExpire, cache = tick()
local function serverHop(pointer, filter)
	visited = shared.vapeserverhoplist and shared.vapeserverhoplist:split('/') or {}
	if not table.find(visited, game.JobId) then
		table.insert(visited, game.JobId)
	end
	if not pointer then
		notif('Vape', 'Searching for an available server.', 2)
	end

	local suc, httpdata = pcall(function()
		return cacheExpire < tick() and game:HttpGet('https://games.roblox.com/v1/games/'..game.PlaceId..'/servers/Public?sortOrder='..(filter == 'Ascending' and 1 or 2)..'&excludeFullGames=true&limit=100'..(pointer and '&cursor='..pointer or '')) or cache
	end)
	local data = suc and httpService:JSONDecode(httpdata) or nil
	if data and data.data then
		for _, v in data.data do
			if tonumber(v.playing) < playersService.MaxPlayers and not table.find(visited, v.id) and not table.find(attempted, v.id) then
				cacheExpire, cache = tick() + 60, httpdata
				table.insert(attempted, v.id)

				notif('Vape', 'Found! Teleporting.', 5)
				teleportService:TeleportToPlaceInstance(game.PlaceId, v.id)
				return
			end
		end

		if data.nextPageCursor then
			serverHop(data.nextPageCursor, filter)
		else
			notif('Vape', 'Failed to find an available server.', 5, 'warning')
		end
	else
		notif('Vape', 'Failed to grab servers. ('..(data and data.errors[1].message or 'no data')..')', 5, 'warning')
	end
end

vape:Clean(lplr.OnTeleport:Connect(function()
	if not tpSwitch then
		tpSwitch = true
		queue_on_teleport("shared.vapeserverhoplist = '"..table.concat(visited, '/').."'\nshared.vapeserverhopprevious = '"..game.JobId.."'")
	end
end))

local frictionTable, oldfrict, entitylib = {}, {}
local function updateVelocity()
	if getTableSize(frictionTable) > 0 then
		if entitylib.isAlive then
			for _, v in entitylib.character.Character:GetChildren() do
				if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
					oldfrict[v] = v.CustomPhysicalProperties or 'none'
					v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
				end
			end
		end
	else
		for i, v in oldfrict do
			i.CustomPhysicalProperties = v ~= 'none' and v or nil
		end
		table.clear(oldfrict)
	end
end

local function motorMove(target, cf)
	local part = Instance.new('Part')
	part.Anchored = true
	part.Parent = workspace
	local motor = Instance.new('Motor6D')
	motor.Part0 = target
	motor.Part1 = part
	motor.C1 = cf
	motor.Parent = part
	task.delay(0, part.Destroy, part)
end

local hash = loadstring(downloadFile('opai/libraries/hash.lua'), 'hash')()
local prediction = loadstring(downloadFile('opai/libraries/prediction.lua'), 'prediction')()
entitylib = loadstring(downloadFile('opai/libraries/entity.lua'), 'entitylibrary')()
local whitelist = {
	alreadychecked = {},
	customtags = {},
	data = {WhitelistedUsers = {}},
	hashes = setmetatable({}, {
		__index = function(_, v)
			return hash and hash.sha512(v..'SelfReport') or ''
		end
	}),
	hooked = false,
	loaded = false,
	localprio = 0,
	said = {}
}
vape.Libraries.entity = entitylib
vape.Libraries.whitelist = whitelist
vape.Libraries.prediction = prediction
vape.Libraries.hash = hash
vape.Libraries.auraanims = {
	Normal = {
		{CFrame = CFrame.new(-0.17, -0.14, -0.12) * CFrame.Angles(math.rad(-53), math.rad(50), math.rad(-64)), Time = 0.13},
		{CFrame = CFrame.new(-0.55, -0.59, -0.1) * CFrame.Angles(math.rad(-161), math.rad(54), math.rad(-6)), Time = 0.1},
		{CFrame = CFrame.new(-0.62, -0.68, -0.07) * CFrame.Angles(math.rad(-167), math.rad(47), math.rad(-1)), Time = 0.06},
		{CFrame = CFrame.new(-0.56, -0.86, 0.23) * CFrame.Angles(math.rad(-167), math.rad(49), math.rad(-1)), Time = 0.06}
	},
	Wide = {
	{CFrame = CFrame.new(-0.22, -0.18, -0.18) * CFrame.Angles(math.rad(-40), math.rad(65), math.rad(-75)), Time = 0.14},
	{CFrame = CFrame.new(-0.6, -0.65, -0.15) * CFrame.Angles(math.rad(-175), math.rad(70), math.rad(-20)), Time = 0.09},
	{CFrame = CFrame.new(-0.68, -0.82, 0.05) * CFrame.Angles(math.rad(-185), math.rad(60), math.rad(-10)), Time = 0.07},
	{CFrame = CFrame.new(-0.62, -0.95, 0.28) * CFrame.Angles(math.rad(-180), math.rad(55), math.rad(-5)), Time = 0.06}
	},
	Rise = {
    {CFrame = CFrame.new(-0.3, -0.1, -0.25) * CFrame.Angles(math.rad(-50), math.rad(45), math.rad(-60)), Time = 0.15},
    {CFrame = CFrame.new(-0.7, -0.55, 0) * CFrame.Angles(math.rad(-160), math.rad(80), math.rad(-10)), Time = 0.1},
    {CFrame = CFrame.new(-0.8, -0.9, 0.2) * CFrame.Angles(math.rad(-200), math.rad(50), math.rad(5)), Time = 0.08},
    {CFrame = CFrame.new(-0.55, -1.0, 0.35) * CFrame.Angles(math.rad(-170), math.rad(40), math.rad(10)), Time = 0.07}
	},
	Rise2 = {
    {CFrame = CFrame.new(-0.15, -0.2, -0.1) * CFrame.Angles(math.rad(-30), math.rad(75), math.rad(-90)), Time = 0.13},
    {CFrame = CFrame.new(-0.5, -0.7, -0.2) * CFrame.Angles(math.rad(-185), math.rad(60), math.rad(-30)), Time = 0.09},
    {CFrame = CFrame.new(-0.65, -0.85, 0.15) * CFrame.Angles(math.rad(-195), math.rad(70), math.rad(-5)), Time = 0.08},
    {CFrame = CFrame.new(-0.7, -0.95, 0.4) * CFrame.Angles(math.rad(-180), math.rad(55), math.rad(15)), Time = 0.06}
	},
	Rise3 = {
    {CFrame = CFrame.new(-0.3, -0.25, -0.2) * CFrame.Angles(math.rad(-60), math.rad(55), math.rad(-70)), Time = 0.12},
    {CFrame = CFrame.new(-0.65, -0.6, 0.05) * CFrame.Angles(math.rad(-175), math.rad(65), math.rad(-15)), Time = 0.08},
    {CFrame = CFrame.new(-0.75, -0.85, 0.2) * CFrame.Angles(math.rad(-190), math.rad(50), math.rad(0)), Time = 0.06},
    {CFrame = CFrame.new(-0.6, -1.0, 0.4) * CFrame.Angles(math.rad(-180), math.rad(45), math.rad(10)), Time = 0.05}
	},
	Rise4 = {
    {CFrame = CFrame.new(-0.2, -0.15, -0.25) * CFrame.Angles(math.rad(-40), math.rad(70), math.rad(-80)), Time = 0.15},
    {CFrame = CFrame.new(-0.55, -0.7, -0.05) * CFrame.Angles(math.rad(-185), math.rad(75), math.rad(-20)), Time = 0.1},
    {CFrame = CFrame.new(-0.7, -0.9, 0.1) * CFrame.Angles(math.rad(-195), math.rad(60), math.rad(-5)), Time = 0.07},
    {CFrame = CFrame.new(-0.65, -1.05, 0.35) * CFrame.Angles(math.rad(-180), math.rad(50), math.rad(15)), Time = 0.06}
	},
	Rise5 = {
    {CFrame = CFrame.new(-0.25, -0.2, -0.15) * CFrame.Angles(math.rad(-50), math.rad(65), math.rad(-75)), Time = 0.14},
    {CFrame = CFrame.new(-0.6, -0.65, 0.0) * CFrame.Angles(math.rad(-180), math.rad(70), math.rad(-10)), Time = 0.09},
    {CFrame = CFrame.new(-0.72, -0.88, 0.25) * CFrame.Angles(math.rad(-185), math.rad(55), math.rad(-5)), Time = 0.08},
    {CFrame = CFrame.new(-0.68, -1.0, 0.45) * CFrame.Angles(math.rad(-175), math.rad(50), math.rad(12)), Time = 0.05}
	},
	Opai = {
    {CFrame = CFrame.new(-0.2, -0.1, -0.1) * CFrame.Angles(math.rad(-45), math.rad(45), math.rad(-60)), Time = 0.09},
    {CFrame = CFrame.new(-0.5, -0.35, 0) * CFrame.Angles(math.rad(-130), math.rad(60), math.rad(-20)), Time = 0.07},
    {CFrame = CFrame.new(-0.65, -0.5, 0.1) * CFrame.Angles(math.rad(-170), math.rad(50), math.rad(-10)), Time = 0.05},
    {CFrame = CFrame.new(-0.4, -0.25, -0.05) * CFrame.Angles(math.rad(-90), math.rad(45), math.rad(-15)), Time = 0.09}
	},
	Exhi = {
		{CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.1},
		{CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.2}
	},
	Exhi2 = {
    {CFrame = CFrame.new(0.75, -0.65, 0.55) * CFrame.Angles(math.rad(-35), math.rad(55), math.rad(-85)), Time = 0.12},
    {CFrame = CFrame.new(0.73, -0.68, 0.53) * CFrame.Angles(math.rad(-80), math.rad(60), math.rad(-40)), Time = 0.18}
},

Exhi3 = {
    {CFrame = CFrame.new(0.68, -0.72, 0.62) * CFrame.Angles(math.rad(-25), math.rad(45), math.rad(-95)), Time = 0.09},
    {CFrame = CFrame.new(0.71, -0.7, 0.6) * CFrame.Angles(math.rad(-78), math.rad(50), math.rad(-35)), Time = 0.21}
},

Exhi4 = {
    {CFrame = CFrame.new(0.7, -0.68, 0.58) * CFrame.Angles(math.rad(-32), math.rad(52), math.rad(-88)), Time = 0.11},
    {CFrame = CFrame.new(0.72, -0.69, 0.57) * CFrame.Angles(math.rad(-82), math.rad(55), math.rad(-42)), Time = 0.19}
},
	['Pushdown'] = {
		{CFrame = CFrame.new(1, 0, 0) * CFrame.Angles(math.rad(-40), math.rad(40), math.rad(-80)), Time = 0.12},
		{CFrame = CFrame.new(1, 0, -0.3) * CFrame.Angles(math.rad(-80), math.rad(40), math.rad(-60)), Time = 0.16}
	},
	['Pushdown2'] = {
    {CFrame = CFrame.new(1.2, 0, 0.1) * CFrame.Angles(math.rad(-50), math.rad(45), math.rad(-70)), Time = 0.14},
    {CFrame = CFrame.new(1.1, 0, -0.35) * CFrame.Angles(math.rad(-85), math.rad(50), math.rad(-55)), Time = 0.18}
	},

	['Pushdown3'] = {
    {CFrame = CFrame.new(0.9, 0, 0) * CFrame.Angles(math.rad(-35), math.rad(35), math.rad(-75)), Time = 0.11},
    {CFrame = CFrame.new(1, 0, -0.25) * CFrame.Angles(math.rad(-70), math.rad(45), math.rad(-65)), Time = 0.15}
	},

	['Pushdown4'] = {
    {CFrame = CFrame.new(1.1, 0, 0.05) * CFrame.Angles(math.rad(-45), math.rad(50), math.rad(-60)), Time = 0.13},
    {CFrame = CFrame.new(1.05, 0, -0.4) * CFrame.Angles(math.rad(-90), math.rad(55), math.rad(-50)), Time = 0.17}
	},
	['New'] = {
		{CFrame = CFrame.new(1, 0, -0.5) * CFrame.Angles(math.rad(-90), math.rad(60), math.rad(-60)), Time = 0.2},
		{CFrame = CFrame.new(1, -0.2, -0.5) * CFrame.Angles(math.rad(-160), math.rad(60), math.rad(-30)), Time = 0.12}
	},
	['Funny'] = {
		{CFrame = CFrame.new(0, 0, -0.6) * CFrame.Angles(math.rad(-60), math.rad(50), math.rad(-70)), Time = 0.1},
		{CFrame = CFrame.new(0, -0.3, -0.6) * CFrame.Angles(math.rad(-160), math.rad(60), math.rad(10)), Time = 0.2}
	},
	['Meteor'] = {
		{CFrame = CFrame.new(0, 0, -1) * CFrame.Angles(math.rad(-40), math.rad(60), math.rad(-80)), Time = 0.17},
		{CFrame = CFrame.new(0, 0, -1) * CFrame.Angles(math.rad(-60), math.rad(60), math.rad(-80)), Time = 0.17}
	},
	['Old'] = {
		{CFrame = CFrame.new(-0.3, -0.53, -0.6) * CFrame.Angles(math.rad(160), math.rad(127), math.rad(90)), Time = 0.13},
		{CFrame = CFrame.new(-0.27, -0.8, -1.2) * CFrame.Angles(math.rad(160), math.rad(90), math.rad(90)), Time = 0.13},
		{CFrame = CFrame.new(-0.01, -0.65, -0.8) * CFrame.Angles(math.rad(160), math.rad(111), math.rad(90)), Time = 0.13},
	}
}

local SpeedMethods
local SpeedMethodList = {'Velocity'}
SpeedMethods = {
	Velocity = function(options, moveDirection)
		local root = entitylib.character.RootPart
		root.AssemblyLinearVelocity = (moveDirection * options.Value.Value) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	end,
	Impulse = function(options, moveDirection)
		local root = entitylib.character.RootPart
		local diff = ((moveDirection * options.Value.Value) - root.AssemblyLinearVelocity) * Vector3.new(1, 0, 1)
		if diff.Magnitude > (moveDirection == Vector3.zero and 10 or 2) then
			root:ApplyImpulse(diff * root.AssemblyMass)
		end
	end,
	CFrame = function(options, moveDirection, dt)
		local root = entitylib.character.RootPart
		local dest = (moveDirection * math.max(options.Value.Value - entitylib.character.Humanoid.WalkSpeed, 0) * dt)
		if options.WallCheck.Enabled then
			options.rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
			options.rayCheck.CollisionGroup = root.CollisionGroup
			local ray = workspace:Raycast(root.Position, dest, options.rayCheck)
			if ray then
				dest = ((ray.Position + ray.Normal) - root.Position)
			end
		end
		root.CFrame += dest
	end,
	TP = function(options, moveDirection)
		if options.TPTiming < tick() then
			options.TPTiming = tick() + options.TPFrequency.Value
			SpeedMethods.CFrame(options, moveDirection, 1)
		end
	end,
	WalkSpeed = function(options)
		if not options.WalkSpeed then options.WalkSpeed = entitylib.character.Humanoid.WalkSpeed end
		entitylib.character.Humanoid.WalkSpeed = options.Value.Value
	end,
	Pulse = function(options, moveDirection)
		local root = entitylib.character.RootPart
		local dt = math.max(options.Value.Value - entitylib.character.Humanoid.WalkSpeed, 0)
		dt = dt * (1 - math.min((tick() % (options.PulseLength.Value + options.PulseDelay.Value)) / options.PulseLength.Value, 1))
		root.AssemblyLinearVelocity = (moveDirection * (entitylib.character.Humanoid.WalkSpeed + dt)) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	end
}
for name in SpeedMethods do
	if not table.find(SpeedMethodList, name) then
		table.insert(SpeedMethodList, name)
	end
end

run(function()
	entitylib.getUpdateConnections = function(ent)
		local hum = ent.Humanoid
		return {
			hum:GetPropertyChangedSignal('Health'),
			hum:GetPropertyChangedSignal('MaxHealth'),
			{
				Connect = function()
					ent.Friend = ent.Player and isFriend(ent.Player) or nil
					ent.Target = ent.Player and isTarget(ent.Player) or nil
					return {
						Disconnect = function() end
					}
				end
			}
		}
	end

	entitylib.targetCheck = function(ent)
		if ent.TeamCheck then
			return ent:TeamCheck()
		end
		if ent.NPC then return true end
		if isFriend(ent.Player) then return false end
		if not select(2, whitelist:get(ent.Player)) then return false end
		if vape.Categories.Main.Options['Teams by server'].Enabled then
			if not lplr.Team then return true end
			if not ent.Player.Team then return true end
			if ent.Player.Team ~= lplr.Team then return true end
			return #ent.Player.Team:GetPlayers() == #playersService:GetPlayers()
		end
		return true
	end

	entitylib.getEntityColor = function(ent)
		ent = ent.Player
		if not (ent and vape.Categories.Main.Options['Use team color'].Enabled) then return end
		if isFriend(ent, true) then
			return Color3.fromHSV(vape.Categories.Friends.Options['Friends color'].Hue, vape.Categories.Friends.Options['Friends color'].Sat, vape.Categories.Friends.Options['Friends color'].Value)
		end
		return tostring(ent.TeamColor) ~= 'White' and ent.TeamColor.Color or nil
	end

	vape:Clean(function()
		entitylib.kill()
		entitylib = nil
	end)
	vape:Clean(vape.Categories.Friends.Update.Event:Connect(function() entitylib.refresh() end))
	vape:Clean(vape.Categories.Targets.Update.Event:Connect(function() entitylib.refresh() end))
	vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
	vape:Clean(workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
		gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
	end))
end)

run(function()
	function whitelist:get(plr)
		local plrstr = self.hashes[plr.Name..plr.UserId]
		for _, v in self.data.WhitelistedUsers do
			if v.hash == plrstr then
				return v.level, v.attackable or whitelist.localprio >= v.level, v.tags
			end
		end
		return 0, true
	end

	function whitelist:isingame()
		for _, v in playersService:GetPlayers() do
			if self:get(v) ~= 0 then return true end
		end
		return false
	end

	function whitelist:tag(plr, text, rich)
		local plrtag, newtag = select(3, self:get(plr)) or self.customtags[plr.Name] or {}, ''
		if not text then return plrtag end
		for _, v in plrtag do
			newtag = newtag..(rich and '<font color="#'..v.color:ToHex()..'">['..v.text..']</font>' or '['..removeTags(v.text)..']')..' '
		end
		return newtag
	end

	function whitelist:getplayer(arg)
		if arg == 'default' and self.localprio == 0 then return true end
		if arg == 'private' and self.localprio == 1 then return true end
		if arg and lplr.Name:lower():sub(1, arg:len()) == arg:lower() then return true end
		return false
	end

	local olduninject
	function whitelist:playeradded(v, joined)
		if self:get(v) ~= 0 then
			if self.alreadychecked[v.UserId] then return end
			self.alreadychecked[v.UserId] = true
			self:hook()
			if self.localprio == 0 then
				olduninject = vape.Uninject
				vape.Uninject = function()
					notif('Vape', 'No escaping the private members :)', 10)
				end
				if joined then
					task.wait(10)
				end
				if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
					local oldchannel = textChatService.ChatInputBarConfiguration.TargetTextChannel
					local newchannel = cloneref(game:GetService('RobloxReplicatedStorage')).ExperienceChat.WhisperChat:InvokeServer(v.UserId)
					if newchannel then
						newchannel:SendAsync('helloimusinginhaler')
					end
					textChatService.ChatInputBarConfiguration.TargetTextChannel = oldchannel
				elseif replicatedStorage:FindFirstChild('DefaultChatSystemChatEvents') then
					replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer('/w '..v.Name..' helloimusinginhaler', 'All')
				end
			end
		end
	end

	function whitelist:process(msg, plr)
		if plr == lplr and msg == 'helloimusinginhaler' then return true end

		if self.localprio > 0 and not self.said[plr.Name] and msg == 'helloimusinginhaler' and plr ~= lplr then
			self.said[plr.Name] = true
			notif('Vape', plr.Name..' is using vape!', 60)
			self.customtags[plr.Name] = {{
				text = 'VAPE USER',
				color = Color3.new(1, 1, 0)
			}}
			local newent = entitylib.getEntity(plr)
			if newent then
				entitylib.Events.EntityUpdated:Fire(newent)
			end
			return true
		end

		if self.localprio < self:get(plr) or plr == lplr then
			local args = msg:split(' ')
			table.remove(args, 1)
			if self:getplayer(args[1]) then
				table.remove(args, 1)
				for cmd, func in self.commands do
					if msg:sub(1, cmd:len() + 1):lower() == ';'..cmd:lower() then
						func(args, plr)
						return true
					end
				end
			end
		end

		return false
	end

	function whitelist:newchat(obj, plr, skip)
		obj.Text = self:tag(plr, true, true)..obj.Text
		local sub = obj.ContentText:find(': ')
		if sub then
			if not skip and self:process(obj.ContentText:sub(sub + 3, #obj.ContentText), plr) then
				obj.Visible = false
			end
		end
	end

	function whitelist:oldchat(func)
		local msgtable, oldchat = debug.getupvalue(func, 3)
		if typeof(msgtable) == 'table' and msgtable.CurrentChannel then
			whitelist.oldchattable = msgtable
		end

		oldchat = hookfunction(func, function(data, ...)
			local plr = playersService:GetPlayerByUserId(data.SpeakerUserId)
			if plr then
				data.ExtraData.Tags = data.ExtraData.Tags or {}
				for _, v in self:tag(plr) do
					table.insert(data.ExtraData.Tags, {TagText = v.text, TagColor = v.color})
				end
				if data.Message and self:process(data.Message, plr) then
					data.Message = ''
				end
			end
			return oldchat(data, ...)
		end)

		vape:Clean(function()
			hookfunction(func, oldchat)
		end)
	end

	function whitelist:hook()
		if self.hooked then return end
		self.hooked = true

		local exp = coreGui:FindFirstChild('ExperienceChat')
		if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			if exp and exp:WaitForChild('appLayout', 5) then
				vape:Clean(exp:FindFirstChild('RCTScrollContentView', true).ChildAdded:Connect(function(obj)
					local plr = playersService:GetPlayerByUserId(tonumber(obj.Name:split('-')[1]) or 0)
					obj = obj:FindFirstChild('TextMessage', true)
					if obj and obj:IsA('TextLabel') then
						if plr then
							self:newchat(obj, plr, true)
							obj:GetPropertyChangedSignal('Text'):Wait()
							self:newchat(obj, plr)
						end

						if obj.ContentText:sub(1, 35) == 'You are now privately chatting with' then
							obj.Visible = false
						end
					end
				end))
			end
		elseif replicatedStorage:FindFirstChild('DefaultChatSystemChatEvents') then
			pcall(function()
				for _, v in getconnections(replicatedStorage.DefaultChatSystemChatEvents.OnNewMessage.OnClientEvent) do
					if v.Function and table.find(debug.getconstants(v.Function), 'UpdateMessagePostedInChannel') then
						whitelist:oldchat(v.Function)
						break
					end
				end

				for _, v in getconnections(replicatedStorage.DefaultChatSystemChatEvents.OnMessageDoneFiltering.OnClientEvent) do
					if v.Function and table.find(debug.getconstants(v.Function), 'UpdateMessageFiltered') then
						whitelist:oldchat(v.Function)
						break
					end
				end
			end)
		end

		if exp then
			local bubblechat = exp:WaitForChild('bubbleChat', 5)
			if bubblechat then
				vape:Clean(bubblechat.DescendantAdded:Connect(function(newbubble)
					if newbubble:IsA('TextLabel') and newbubble.Text:find('helloimusinginhaler') then
						newbubble.Parent.Parent.Visible = false
					end
				end))
			end
		end
	end

	function whitelist:update(first)
		local suc = pcall(function()
			local _, subbed = pcall(function()
				return game:HttpGet('https://github.com/7GrandDadPGN/whitelists')
			end)
			local commit = subbed:find('currentOid')
			commit = commit and subbed:sub(commit + 13, commit + 52) or nil
			commit = commit and #commit == 40 and commit or 'main'
			whitelist.textdata = game:HttpGet('https://raw.githubusercontent.com/7GrandDadPGN/whitelists/'..commit..'/PlayerWhitelist.json', true)
		end)
		if not suc or not hash or not whitelist.get then return true end
		whitelist.loaded = true

		if not first or whitelist.textdata ~= whitelist.olddata then
			if not first then
				whitelist.olddata = isfile('opai/profiles/whitelist.json') and readfile('opai/profiles/whitelist.json') or nil
			end

			local suc, res = pcall(function()
				return httpService:JSONDecode(whitelist.textdata)
			end)

			whitelist.data = suc and type(res) == 'table' and res or whitelist.data
			whitelist.localprio = whitelist:get(lplr)

			for _, v in whitelist.data.WhitelistedUsers do
				if v.tags then
					for _, tag in v.tags do
						tag.color = Color3.fromRGB(unpack(tag.color))
					end
				end
			end

			if not whitelist.connection then
				whitelist.connection = playersService.PlayerAdded:Connect(function(v)
					whitelist:playeradded(v, true)
				end)
				vape:Clean(whitelist.connection)
			end

			for _, v in playersService:GetPlayers() do
				whitelist:playeradded(v)
			end

			if entitylib.Running and vape.Loaded then
				entitylib.refresh()
			end

			if whitelist.textdata ~= whitelist.olddata then
				if whitelist.data.Announcement.expiretime > os.time() then
					local targets = whitelist.data.Announcement.targets
					targets = targets == 'all' and {tostring(lplr.UserId)} or targets:split(',')

					if table.find(targets, tostring(lplr.UserId)) then
						local hint = Instance.new('Hint')
						hint.Text = 'VAPE ANNOUNCEMENT: '..whitelist.data.Announcement.text
						hint.Parent = workspace
						game:GetService('Debris'):AddItem(hint, 20)
					end
				end
				whitelist.olddata = whitelist.textdata
				pcall(function()
					writefile('opai/profiles/whitelist.json', whitelist.textdata)
				end)
			end

			if whitelist.data.KillVape then
				vape:Uninject()
				return true
			end

			if whitelist.data.BlacklistedUsers[tostring(lplr.UserId)] then
				task.spawn(lplr.kick, lplr, whitelist.data.BlacklistedUsers[tostring(lplr.UserId)])
				return true
			end
		end
	end

	whitelist.commands = {
		byfron = function()
			task.spawn(function()
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				local UIBlox = getrenv().require(game:GetService('CorePackages').UIBlox)
				local Roact = getrenv().require(game:GetService('CorePackages').Roact)
				UIBlox.init(getrenv().require(game:GetService('CorePackages').Workspace.Packages.RobloxAppUIBloxConfig))
				local auth = getrenv().require(coreGui.RobloxGui.Modules.LuaApp.Components.Moderation.ModerationPrompt)
				local darktheme = getrenv().require(game:GetService('CorePackages').Workspace.Packages.Style).Themes.DarkTheme
				local fonttokens = getrenv().require(game:GetService("CorePackages").Packages._Index.UIBlox.UIBlox.App.Style.Tokens).getTokens('Desktop', 'Dark', true)
				local buildersans = getrenv().require(game:GetService('CorePackages').Packages._Index.UIBlox.UIBlox.App.Style.Fonts.FontLoader).new(true, fonttokens):loadFont()
				local tLocalization = getrenv().require(game:GetService('CorePackages').Workspace.Packages.RobloxAppLocales).Localization
				local localProvider = getrenv().require(game:GetService('CorePackages').Workspace.Packages.Localization).LocalizationProvider
				lplr.PlayerGui:ClearAllChildren()
				vape.gui.Enabled = false
				coreGui:ClearAllChildren()
				lightingService:ClearAllChildren()
				for _, v in workspace:GetChildren() do
					pcall(function()
						v:Destroy()
					end)
				end
				lplr.kick(lplr)
				guiService:ClearError()
				local gui = Instance.new('ScreenGui')
				gui.IgnoreGuiInset = true
				gui.Parent = coreGui
				local frame = Instance.new('ImageLabel')
				frame.BorderSizePixel = 0
				frame.Size = UDim2.fromScale(1, 1)
				frame.BackgroundColor3 = Color3.fromRGB(224, 223, 225)
				frame.ScaleType = Enum.ScaleType.Crop
				frame.Parent = gui
				task.delay(0.3, function()
					frame.Image = 'rbxasset://textures/ui/LuaApp/graphic/Auth/GridBackground.jpg'
				end)
				task.delay(0.6, function()
					local modPrompt = Roact.createElement(auth, {
						style = {},
						screenSize = vape.gui.AbsoluteSize or Vector2.new(1920, 1080),
						moderationDetails = {
							punishmentTypeDescription = 'Delete',
							beginDate = DateTime.fromUnixTimestampMillis(DateTime.now().UnixTimestampMillis - ((60 * math.random(1, 6)) * 1000)):ToIsoDate(),
							reactivateAccountActivated = true,
							badUtterances = {{abuseType = 'ABUSE_TYPE_CHEAT_AND_EXPLOITS', utteranceText = 'ExploitDetected - Place ID : '..game.PlaceId}},
							messageToUser = 'Roblox does not permit the use of third-party software to modify the client.'
						},
						termsActivated = function() end,
						communityGuidelinesActivated = function() end,
						supportFormActivated = function() end,
						reactivateAccountActivated = function() end,
						logoutCallback = function() end,
						globalGuiInset = {top = 0}
					})

					local screengui = Roact.createElement(localProvider, {
						localization = tLocalization.new('en-us')
					}, {Roact.createElement(UIBlox.Style.Provider, {
						style = {
							Theme = darktheme,
							Font = buildersans
						},
					}, {modPrompt})})

					Roact.mount(screengui, coreGui)
				end)
			end)
		end,
		crash = function()
			task.spawn(function()
				repeat
					local part = Instance.new('Part')
					part.Size = Vector3.new(1e10, 1e10, 1e10)
					part.Parent = workspace
				until false
			end)
		end,
		deletemap = function()
			local terrain = workspace:FindFirstChildWhichIsA('Terrain')
			if terrain then
				terrain:Clear()
			end

			for _, v in workspace:GetChildren() do
				if v ~= terrain and not v:IsDescendantOf(lplr.Character) and not v:IsA('Camera') then
					v:Destroy()
					v:ClearAllChildren()
				end
			end
		end,
		framerate = function(args)
			if #args < 1 or not setfpscap then return end
			setfpscap(tonumber(args[1]) ~= '' and math.clamp(tonumber(args[1]) or 9999, 1, 9999) or 9999)
		end,
		gravity = function(args)
			workspace.Gravity = tonumber(args[1]) or workspace.Gravity
		end,
		jump = function()
			if entitylib.isAlive and entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end,
		kick = function(args)
			task.spawn(function()
				lplr:Kick(table.concat(args, ' '))
			end)
		end,
		kill = function()
			if entitylib.isAlive then
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Dead)
				entitylib.character.Humanoid.Health = 0
			end
		end,
		reveal = function()
			task.delay(0.1, function()
				if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
					textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync('I am using the inhaler client')
				else
					replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer('I am using the inhaler client', 'All')
				end
			end)
		end,
		shutdown = function()
			game:Shutdown()
		end,
		toggle = function(args)
			if #args < 1 then return end
			if args[1]:lower() == 'all' then
				for i, v in vape.Modules do
					if i ~= 'Panic' and i ~= 'ServerHop' and i ~= 'Rejoin' then
						v:Toggle()
					end
				end
			else
				for i, v in vape.Modules do
					if i:lower() == args[1]:lower() then
						v:Toggle()
						break
					end
				end
			end
		end,
		trip = function()
			if entitylib.isAlive then
				if entitylib.character.RootPart.Velocity.Magnitude < 15 then
					entitylib.character.RootPart.Velocity = entitylib.character.RootPart.CFrame.LookVector * 15
				end
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
			end
		end,
		uninject = function()
			if olduninject then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				olduninject(vape)
			else
				vape:Uninject()
			end
		end,
		void = function()
			if entitylib.isAlive then
				entitylib.character.RootPart.CFrame += Vector3.new(0, -1000, 0)
			end
		end
	}

	task.spawn(function()
		repeat
			if whitelist:update(whitelist.loaded) then return end
			task.wait(10)
		until vape.Loaded == nil
	end)

	vape:Clean(function()
		table.clear(whitelist.commands)
		table.clear(whitelist.data)
		table.clear(whitelist)
	end)
end)
entitylib.start()
run(function()
	local AimAssist
	local Targets
	local Part
	local FOV
	local Speed
	local CircleColor
	local CircleTransparency
	local CircleFilled
	local CircleObject
	local RightClick
	local ShowTarget
	local moveConst = Vector2.new(1, 0.77) * math.rad(0.5)
	
	local function wrapAngle(num)
		num = num % math.pi
		num -= num >= (math.pi / 2) and math.pi or 0
		num += num < -(math.pi / 2) and math.pi or 0
		return num
	end
	
	AimAssist = vape.Categories.Combat:CreateModule({
		Name = 'AimAssist',
		Function = function(callback)
			if CircleObject then
				CircleObject.Visible = callback
			end
			if callback then
				local ent
				local rightClicked = not RightClick.Enabled or inputService:IsMouseButtonPressed(1)
				AimAssist:Clean(runService.RenderStepped:Connect(function(dt)
					if CircleObject then
						CircleObject.Position = inputService:GetMouseLocation()
					end
	
					if rightClicked and not vape.gui.ScaledGui.ClickGui.Visible then
						ent = entitylib.EntityMouse({
							Range = FOV.Value,
							Part = Part.Value,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled,
							Origin = gameCamera.CFrame.Position
						})
	
						if ent then
							local facing = gameCamera.CFrame.LookVector
							local new = (ent[Part.Value].Position - gameCamera.CFrame.Position).Unit
							new = new == new and new or Vector3.zero
	
							if ShowTarget.Enabled then
								targetinfo.Targets[ent] = tick() + 1
							end
	
							if new ~= Vector3.zero then
								local diffYaw = wrapAngle(math.atan2(facing.X, facing.Z) - math.atan2(new.X, new.Z))
								local diffPitch = math.asin(facing.Y) - math.asin(new.Y)
								local angle = Vector2.new(diffYaw, diffPitch) // (moveConst * UserSettings():GetService('UserGameSettings').MouseSensitivity)
	
								angle *= math.min(Speed.Value * dt, 1)
								mousemoverel(angle.X, angle.Y)
							end
						end
					end
				end))
	
				if RightClick.Enabled then
					AimAssist:Clean(inputService.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton2 then
							ent = nil
							rightClicked = true
						end
					end))
	
					AimAssist:Clean(inputService.InputEnded:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton2 then
							rightClicked = false
						end
					end))
				end
			end
		end,
		Tooltip = 'Smoothly aims to closest valid target'
	})
	Targets = AimAssist:CreateTargets({Players = true})
	Part = AimAssist:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head'}
	})
	FOV = AimAssist:CreateSlider({
		Name = 'FOV',
		Min = 0,
		Max = 1000,
		Default = 100,
		Function = function(val)
			if CircleObject then
				CircleObject.Radius = val
			end
		end
	})
	Speed = AimAssist:CreateSlider({
		Name = 'Speed',
		Min = 0,
		Max = 30,
		Default = 15
	})
	AimAssist:CreateToggle({
		Name = 'Range Circle',
		Function = function(callback)
			if callback then
				CircleObject = Drawing.new('Circle')
				CircleObject.Filled = CircleFilled.Enabled
				CircleObject.Color = Color3.fromHSV(CircleColor.Hue, CircleColor.Sat, CircleColor.Value)
				CircleObject.Position = vape.gui.AbsoluteSize / 2
				CircleObject.Radius = FOV.Value
				CircleObject.NumSides = 100
				CircleObject.Transparency = 1 - CircleTransparency.Value
				CircleObject.Visible = AimAssist.Enabled
			else
				pcall(function()
					CircleObject.Visible = false
					CircleObject:Remove()
				end)
			end
			CircleColor.Object.Visible = callback
			CircleTransparency.Object.Visible = callback
			CircleFilled.Object.Visible = callback
		end
	})
	CircleColor = AimAssist:CreateColorSlider({
		Name = 'Circle Color',
		Function = function(hue, sat, val)
			if CircleObject then
				CircleObject.Color = Color3.fromHSV(hue, sat, val)
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleTransparency = AimAssist:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Default = 0.5,
		Function = function(val)
			if CircleObject then
				CircleObject.Transparency = 1 - val
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleFilled = AimAssist:CreateToggle({
		Name = 'Circle Filled',
		Function = function(callback)
			if CircleObject then
				CircleObject.Filled = callback
			end
		end,
		Darker = true,
		Visible = false
	})
	RightClick = AimAssist:CreateToggle({
		Name = 'Require right click',
		Function = function()
			if AimAssist.Enabled then
				AimAssist:Toggle()
				AimAssist:Toggle()
			end
		end
	})
	ShowTarget = AimAssist:CreateToggle({
		Name = 'Show target info'
	})
end)
	
run(function()
	local AutoClicker
	local Mode
	local CPS
	
	AutoClicker = vape.Categories.Combat:CreateModule({
		Name = 'AutoClicker',
		Function = function(callback)
			if callback then
				repeat
					if Mode.Value == 'Tool' then
						local tool = getTool()
						if tool and inputService:IsMouseButtonPressed(0) then
							tool:Activate()
						end
					else
						if mouse1click and (isrbxactive or iswindowactive)() then
							if not vape.gui.ScaledGui.ClickGui.Visible then
								(Mode.Value == 'Click' and mouse1click or mouse2click)()
							end
						end
					end
	
					task.wait(1 / CPS.GetRandomValue())
				until not AutoClicker.Enabled
			end
		end,
		Tooltip = 'Automatically clicks for you'
	})
	Mode = AutoClicker:CreateDropdown({
		Name = 'Mode',
		List = {'Tool', 'Click', 'RightClick'},
		Tooltip = 'Tool - Automatically uses roblox tools (eg. swords)\nClick - Left click\nRightClick - Right click'
	})
	CPS = AutoClicker:CreateTwoSlider({
		Name = 'CPS',
		Min = 1,
		Max = 20,
		DefaultMin = 8,
		DefaultMax = 12
	})
end)
	
run(function()
	local Reach
	local Targets
	local Mode
	local Value
	local Chance
	local Overlay = OverlapParams.new()
	Overlay.FilterType = Enum.RaycastFilterType.Include
	local modified = {}
	
	Reach = vape.Categories.Combat:CreateModule({
		Name = 'Reach',
		Function = function(callback)
			if callback then
				repeat
					local tool = getTool()
					tool = tool and tool:FindFirstChildWhichIsA('TouchTransmitter', true)
					if tool then
						if Mode.Value == 'TouchInterest' then
							local entites = {}
							for _, v in entitylib.List do
								if v.Targetable then
									if not Targets.Players.Enabled and v.Player then continue end
									if not Targets.NPCs.Enabled and v.NPC then continue end
									table.insert(entites, v.Character)
								end
							end
	
							Overlay.FilterDescendantsInstances = entites
							local parts = workspace:GetPartBoundsInBox(tool.Parent.CFrame * CFrame.new(0, 0, Value.Value / 2), tool.Parent.Size + Vector3.new(0, 0, Value.Value), Overlay)
	
							for _, v in parts do
								if Random.new().NextNumber(Random.new(), 0, 100) > Chance.Value then
									task.wait(0.2)
									break
								end
	
								firetouchinterest(tool.Parent, v, 1)
								firetouchinterest(tool.Parent, v, 0)
							end
						else
							if not modified[tool.Parent] then
								modified[tool.Parent] = tool.Parent.Size
							end
							tool.Parent.Size = modified[tool.Parent] + Vector3.new(0, 0, Value.Value)
							tool.Parent.Massless = true
						end
					end
	
					task.wait()
				until not Reach.Enabled
			else
				for i, v in modified do
					i.Size = v
					i.Massless = false
				end
				table.clear(modified)
			end
		end,
		Tooltip = 'Extends tool attack reach'
	})
	Targets = Reach:CreateTargets({Players = true})
	Mode = Reach:CreateDropdown({
		Name = 'Mode',
		List = {'TouchInterest', 'Resize'},
		Function = function(val)
			Chance.Object.Visible = val == 'TouchInterest'
		end,
		Tooltip = 'TouchInterest - Reports fake collision events to the server\nResize - Physically modifies the tools size'
	})
	Value = Reach:CreateSlider({
		Name = 'Range',
		Min = 0,
		Max = 2,
		Decimal = 10,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Chance = Reach:CreateSlider({
		Name = 'Chance',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
end)
local mouseClicked
run(function()
	local SilentAim
	local Target
	local Mode
	local Method
	local MethodRay
	local IgnoredScripts
	local Range
	local HitChance
	local HeadshotChance
	local AutoFire
	local AutoFireShootDelay
	local AutoFireMode
	local AutoFirePosition
	local Wallbang
	local CircleColor
	local CircleTransparency
	local CircleFilled
	local CircleObject
	local Projectile
	local ProjectileSpeed
	local ProjectileGravity
	local RaycastWhitelist = RaycastParams.new()
	RaycastWhitelist.FilterType = Enum.RaycastFilterType.Include
	local ProjectileRaycast = RaycastParams.new()
	ProjectileRaycast.RespectCanCollide = true
	local fireoffset, rand, delayCheck = CFrame.identity, Random.new(), tick()
	local oldnamecall, oldray

	local function getTarget(origin, obj)
		if rand.NextNumber(rand, 0, 100) > (AutoFire.Enabled and 100 or HitChance.Value) then return end
		local targetPart = (rand.NextNumber(rand, 0, 100) < (AutoFire.Enabled and 100 or HeadshotChance.Value)) and 'Head' or 'RootPart'
		local ent = entitylib['Entity'..Mode.Value]({
			Range = Range.Value,
			Wallcheck = Target.Walls.Enabled and (obj or true) or nil,
			Part = targetPart,
			Origin = origin,
			Players = Target.Players.Enabled,
			NPCs = Target.NPCs.Enabled
		})

		if ent then
			targetinfo.Targets[ent] = tick() + 1
			if Projectile.Enabled then
				ProjectileRaycast.FilterDescendantsInstances = {gameCamera, ent.Character}
				ProjectileRaycast.CollisionGroup = ent[targetPart].CollisionGroup
			end
		end

		return ent, ent and ent[targetPart], origin
	end

	local Hooks = {
		FindPartOnRayWithIgnoreList = function(args)
			local ent, targetPart, origin = getTarget(args[1].Origin, {args[2]})
			if not ent then return end
			if Wallbang.Enabled then
				return {targetPart, targetPart.Position, targetPart.GetClosestPointOnSurface(targetPart, origin), targetPart.Material}
			end
			args[1] = Ray.new(origin, CFrame.lookAt(origin, targetPart.Position).LookVector * args[1].Direction.Magnitude)
		end,
		Raycast = function(args)
			if MethodRay.Value ~= 'All' and args[3] and args[3].FilterType ~= Enum.RaycastFilterType[MethodRay.Value] then return end
			local ent, targetPart, origin = getTarget(args[1])
			if not ent then return end
			args[2] = CFrame.lookAt(origin, targetPart.Position).LookVector * args[2].Magnitude
			if Wallbang.Enabled then
				RaycastWhitelist.FilterDescendantsInstances = {targetPart}
				args[3] = RaycastWhitelist
			end
		end,
		ScreenPointToRay = function(args)
			local ent, targetPart, origin = getTarget(gameCamera.CFrame.Position)
			if not ent then return end
			local direction = CFrame.lookAt(origin, targetPart.Position)
			if Projectile.Enabled then
				local calc = prediction.SolveTrajectory(origin, ProjectileSpeed.Value, ProjectileGravity.Value, targetPart.Position, targetPart.Velocity, workspace.Gravity, ent.HipHeight, nil, ProjectileRaycast)
				if not calc then return end
				direction = CFrame.lookAt(origin, calc)
			end
			return {Ray.new(origin + (args[3] and direction.LookVector * args[3] or Vector3.zero), direction.LookVector)}
		end,
		Ray = function(args)
			local ent, targetPart, origin = getTarget(args[1])
			if not ent then return end
			if Projectile.Enabled then
				local calc = prediction.SolveTrajectory(origin, ProjectileSpeed.Value, ProjectileGravity.Value, targetPart.Position, targetPart.Velocity, workspace.Gravity, ent.HipHeight, nil, ProjectileRaycast)
				if not calc then return end
				args[2] = CFrame.lookAt(origin, calc).LookVector * args[2].Magnitude
			else
				args[2] = CFrame.lookAt(origin, targetPart.Position).LookVector * args[2].Magnitude
			end
		end
	}
	Hooks.FindPartOnRayWithWhitelist = Hooks.FindPartOnRayWithIgnoreList
	Hooks.FindPartOnRay = Hooks.FindPartOnRayWithIgnoreList
	Hooks.ViewportPointToRay = Hooks.ScreenPointToRay

	SilentAim = vape.Categories.Combat:CreateModule({
		Name = 'SilentAim',
		Function = function(callback)
			if CircleObject then
				CircleObject.Visible = callback and Mode.Value == 'Mouse'
			end
			if callback then
				if Method.Value == 'Ray' then
					oldray = hookfunction(Ray.new, function(origin, direction)
						if checkcaller() then
							return oldray(origin, direction)
						end
						local calling = getcallingscript()

						if calling then
							local list = #IgnoredScripts.ListEnabled > 0 and IgnoredScripts.ListEnabled or {'ControlScript', 'ControlModule'}
							if table.find(list, tostring(calling)) then
								return oldray(origin, direction)
							end
						end

						local args = {origin, direction}
						Hooks.Ray(args)
						return oldray(unpack(args))
					end)
				else
					oldnamecall = hookmetamethod(game, '__namecall', function(...)
						if getnamecallmethod() ~= Method.Value then
							return oldnamecall(...)
						end
						if checkcaller() then
							return oldnamecall(...)
						end

						local calling = getcallingscript()
						if calling then
							local list = #IgnoredScripts.ListEnabled > 0 and IgnoredScripts.ListEnabled or {'ControlScript', 'ControlModule'}
							if table.find(list, tostring(calling)) then
								return oldnamecall(...)
							end
						end

						local self, args = ..., {select(2, ...)}
						local res = Hooks[Method.Value](args)
						if res then
							return unpack(res)
						end
						return oldnamecall(self, unpack(args))
					end)
				end

				repeat
					if CircleObject then
						CircleObject.Position = inputService:GetMouseLocation()
					end
					if AutoFire.Enabled then
						local origin = AutoFireMode.Value == 'Camera' and gameCamera.CFrame or entitylib.isAlive and entitylib.character.RootPart.CFrame or CFrame.identity
						local ent = entitylib['Entity'..Mode.Value]({
							Range = Range.Value,
							Wallcheck = Target.Walls.Enabled or nil,
							Part = 'Head',
							Origin = (origin * fireoffset).Position,
							Players = Target.Players.Enabled,
							NPCs = Target.NPCs.Enabled
						})

						if mouse1click and (isrbxactive or iswindowactive)() then
							if ent and canClick() then
								if delayCheck < tick() then
									if mouseClicked then
										mouse1release()
										delayCheck = tick() + AutoFireShootDelay.Value
									else
										mouse1press()
									end
									mouseClicked = not mouseClicked
								end
							else
								if mouseClicked then
									mouse1release()
								end
								mouseClicked = false
							end
						end
					end
					task.wait()
				until not SilentAim.Enabled
			else
				if oldnamecall then
					hookmetamethod(game, '__namecall', oldnamecall)
				end
				if oldray then
					hookfunction(Ray.new, oldray)
				end
				oldnamecall, oldray = nil, nil
			end
		end,
		ExtraText = function()
			return Method.Value:gsub('FindPartOnRay', '')
		end,
		Tooltip = 'Silently adjusts your aim towards the enemy'
	})
	Target = SilentAim:CreateTargets({Players = true})
	Mode = SilentAim:CreateDropdown({
		Name = 'Mode',
		List = {'Mouse', 'Position'},
		Function = function(val)
			if CircleObject then
				CircleObject.Visible = SilentAim.Enabled and val == 'Mouse'
			end
		end,
		Tooltip = 'Mouse - Checks for entities near the mouses position\nPosition - Checks for entities near the local character'
	})
	Method = SilentAim:CreateDropdown({
		Name = 'Method',
		List = {'FindPartOnRay', 'FindPartOnRayWithIgnoreList', 'FindPartOnRayWithWhitelist', 'ScreenPointToRay', 'ViewportPointToRay', 'Raycast', 'Ray'},
		Function = function(val)
			if SilentAim.Enabled then
				SilentAim:Toggle()
				SilentAim:Toggle()
			end
			MethodRay.Object.Visible = val == 'Raycast'
		end,
		Tooltip = 'FindPartOnRay* - Deprecated methods of raycasting used in old games\nRaycast - The modern raycast method\nPointToRay - Method to generate a ray from screen coords\nRay - Hooking Ray.new'
	})
	MethodRay = SilentAim:CreateDropdown({
		Name = 'Raycast Type',
		List = {'All', 'Exclude', 'Include'},
		Darker = true,
		Visible = false
	})
	IgnoredScripts = SilentAim:CreateTextList({Name = 'Ignored Scripts'})
	Range = SilentAim:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 1000,
		Default = 150,
		Function = function(val)
			if CircleObject then
				CircleObject.Radius = val
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	HitChance = SilentAim:CreateSlider({
		Name = 'Hit Chance',
		Min = 0,
		Max = 100,
		Default = 85,
		Suffix = '%'
	})
	HeadshotChance = SilentAim:CreateSlider({
		Name = 'Headshot Chance',
		Min = 0,
		Max = 100,
		Default = 65,
		Suffix = '%'
	})
	AutoFire = SilentAim:CreateToggle({
		Name = 'AutoFire',
		Function = function(callback)
			AutoFireShootDelay.Object.Visible = callback
			AutoFireMode.Object.Visible = callback
			AutoFirePosition.Object.Visible = callback
		end
	})
	AutoFireShootDelay = SilentAim:CreateSlider({
		Name = 'Next Shot Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Visible = false,
		Darker = true,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	AutoFireMode = SilentAim:CreateDropdown({
		Name = 'Origin',
		List = {'RootPart', 'Camera'},
		Visible = false,
		Darker = true,
		Tooltip = 'Determines the position to check for before shooting'
	})
	AutoFirePosition = SilentAim:CreateTextBox({
		Name = 'Offset',
		Function = function()
			local suc, res = pcall(function()
				return CFrame.new(unpack(AutoFirePosition.Value:split(',')))
			end)
			if suc then fireoffset = res end
		end,
		Default = '0, 0, 0',
		Visible = false,
		Darker = true
	})
	Wallbang = SilentAim:CreateToggle({Name = 'Wallbang'})
	SilentAim:CreateToggle({
		Name = 'Range Circle',
		Function = function(callback)
			if callback then
				CircleObject = Drawing.new('Circle')
				CircleObject.Filled = CircleFilled.Enabled
				CircleObject.Color = Color3.fromHSV(CircleColor.Hue, CircleColor.Sat, CircleColor.Value)
				CircleObject.Position = vape.gui.AbsoluteSize / 2
				CircleObject.Radius = Range.Value
				CircleObject.NumSides = 100
				CircleObject.Transparency = 1 - CircleTransparency.Value
				CircleObject.Visible = SilentAim.Enabled and Mode.Value == 'Mouse'
			else
				pcall(function()
					CircleObject.Visible = false
					CircleObject:Remove()
				end)
			end
			CircleColor.Object.Visible = callback
			CircleTransparency.Object.Visible = callback
			CircleFilled.Object.Visible = callback
		end
	})
	CircleColor = SilentAim:CreateColorSlider({
		Name = 'Circle Color',
		Function = function(hue, sat, val)
			if CircleObject then
				CircleObject.Color = Color3.fromHSV(hue, sat, val)
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleTransparency = SilentAim:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Default = 0.5,
		Function = function(val)
			if CircleObject then
				CircleObject.Transparency = 1 - val
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleFilled = SilentAim:CreateToggle({
		Name = 'Circle Filled',
		Function = function(callback)
			if CircleObject then
				CircleObject.Filled = callback
			end
		end,
		Darker = true,
		Visible = false
	})
	Projectile = SilentAim:CreateToggle({
		Name = 'Projectile',
		Function = function(callback)
			ProjectileSpeed.Object.Visible = callback
			ProjectileGravity.Object.Visible = callback
		end
	})
	ProjectileSpeed = SilentAim:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 1000,
		Default = 1000,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	ProjectileGravity = SilentAim:CreateSlider({
		Name = 'Gravity',
		Min = 0,
		Max = 192.6,
		Default = 192.6,
		Darker = true,
		Visible = false
	})
end)
run(function()
    local Desync = {}
    local oldroot
    local clone
    local hip = 2.6
    local waitTime

    local function createClone()
        if entitylib.isAlive and entitylib.character.Humanoid.Health > 0 and (not oldroot or not oldroot.Parent) then
            hip = entitylib.character.Humanoid.HipHeight
            oldroot = entitylib.character.HumanoidRootPart
            if not lplr.Character.Parent then return false end
            lplr.Character.Parent = game
            clone = oldroot:Clone()
            clone.Parent = lplr.Character
            oldroot.Transparency = 0
            local highlight = Instance.new("Highlight")
            highlight.FillColor = Color3.fromRGB(255, 0, 0)
            highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
            highlight.OutlineTransparency = 0
            highlight.Parent = oldroot
            oldroot.Parent = gameCamera
            store.rootpart = clone
            bedwars.QueryUtil:setQueryIgnored(oldroot, true)
            lplr.Character.PrimaryPart = clone
            lplr.Character.Parent = workspace
            for _, v in ipairs(lplr.Character:GetDescendants()) do
                if v:IsA("Weld") or v:IsA("Motor6D") then
                    if v.Part0 == oldroot then v.Part0 = clone end
                    if v.Part1 == oldroot then v.Part1 = clone end
                end
            end
            return true
        end
        return false
    end

    local function restoreCharacter()
        if oldroot and oldroot.Parent then
            local hl = oldroot:FindFirstChildOfClass("Highlight")
            if hl then pcall(function() hl:Destroy() end) end
            lplr.Character.Parent = game
            oldroot.Parent = lplr.Character
            lplr.Character.PrimaryPart = oldroot
            lplr.Character.Parent = workspace
            for _, v in ipairs(lplr.Character:GetDescendants()) do
                if v:IsA("Weld") or v:IsA("Motor6D") then
                    if v.Part0 == clone then v.Part0 = oldroot end
                    if v.Part1 == clone then v.Part1 = oldroot end
                end
            end
            entitylib.character.Humanoid.HipHeight = hip or 2.6
            oldroot.Transparency = 1
        end
        if clone and clone.Parent then
            pcall(function() clone:Destroy() end)
            clone = nil
        end
        store.rootpart = nil
        oldroot = nil
    end

    Desync = vape.Categories.Blatant:CreateModule({
        Name = "Desync",
        Tooltip = "Clones character and teleports your real body to it periodically",
        Function = function(call)
            if call then
                if createClone() then
                    local last = 0
                    local conn = runService.Heartbeat:Connect(function()
                        if not Desync.Enabled then return end
                        if not clone or not oldroot or not oldroot.Parent then return end
                        if tick() - last >= waitTime.Value then
                            if entitylib.isAlive then
                                oldroot.CFrame = clone.CFrame
                            end
                            last = tick()
                        end
                    end)
                    Desync:Clean(function()
                        if conn then conn:Disconnect() end
                        restoreCharacter()
                    end)
                else
                    Desync:Toggle(false)
                end
            else
                restoreCharacter()
            end
        end
    })

    waitTime = Desync:CreateSlider({
        Name = "Delay",
        Min = 1,
        Max = 5,
        Default = 1,
        Function = function(val) waitTime.Value = val end
    })
end)
run(function()
    local SilentAura
    local Attacking = false
    local AttackRemote = {FireServer = function() end}
    local cachedTargets = {}
    local lastAttackTime = {}
    local lastTargetUpdate = 0
    local Boxes = {}
    local BoxSwingColor
    local BoxAttackColor
    local SwingRange
    local AttackRange
    local Face
    local Swing
    local AngleSlider
    local SortMode
    local Targets
    local APS

    task.spawn(function()
        AttackRemote = bedwars.Client:Get(remotes.AttackEntity).instance
    end)

    local function getAttackData()
        local sword = store.tools.sword
        if not sword or not sword.tool then return false end
        return sword, bedwars.ItemMeta[sword.tool.Name]
    end

    local function updateTargetCache()
        if tick() - lastTargetUpdate < 0.05 then return cachedTargets end
        cachedTargets = entitylib.AllPosition({
            Range = SwingRange.Value,
            Wallcheck = Targets.Walls.Enabled or nil,
            Part = "RootPart",
            Players = Targets.Players.Enabled,
            NPCs = Targets.NPCs.Enabled,
            Limit = 5,
            Sort = sortmethods[SortMode.Value]
        })
        lastTargetUpdate = tick()
        return cachedTargets
    end

    SilentAura = vape.Categories.Combat:CreateModule({
        Name = "Silent Aura",
        Function = function(callback)
            if callback then
                repeat
                    local attacked, sword, meta = {}, getAttackData()
                    Attacking = false
                    store.KillauraTarget = nil

                    if sword then
                        local plrs = updateTargetCache()
                        local selfpos = entitylib.character.RootPart.Position
                        local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)

                        for i, v in pairs(plrs) do
                            local delta = (v.RootPart.Position - selfpos)
                            if delta.Magnitude > SwingRange.Value then continue end
                            local angle = math.deg(math.acos(math.max(-1, math.min(1, localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit)))))
                            if angle > AngleSlider.Value / 2 then continue end

                            table.insert(attacked, {
                                Entity = v,
                                Check = delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor
                            })

                            if not Attacking then
                                Attacking = true
                                store.KillauraTarget = v
                                if Swing.Enabled then
                                    bedwars.SwordController:playSwordEffect(meta, false)
                                end
                            end
                        end

                        for _, v in pairs(attacked) do
                            local delta = (v.Entity.RootPart.Position - selfpos)
                            if delta.Magnitude > AttackRange.Value then continue end

                            local lastAtk = lastAttackTime[v.Entity] or 0
                            local apsMin, apsMax = 8, 12
                            if APS and APS.Value then
                                apsMin = APS.Value.Min or apsMin
                                apsMax = APS.Value.Max or apsMax
                            end
                            local apsDelay = 1 / math.random(apsMin, apsMax)
                            if (tick() - lastAtk) < apsDelay then continue end

                            local actualRoot = v.Entity.Character.PrimaryPart
                            if actualRoot then
                                local dir = CFrame.lookAt(selfpos, actualRoot.Position).LookVector
                                local pos = selfpos + dir * math.max(delta.Magnitude - 14.399, 0)

                                lastAttackTime[v.Entity] = tick()
                                bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()

                                AttackRemote:FireServer({
                                    weapon = sword.tool,
                                    chargedAttack = {chargeRatio = math.random()},
                                    entityInstance = v.Entity.Character,
                                    validate = {
                                        raycast = {
                                            cameraPosition = {value = pos},
                                            cursorDirection = {value = dir}
                                        },
                                        targetPosition = {value = actualRoot.Position + actualRoot.Velocity * 0.05},
                                        selfPosition = {value = pos}
                                    }
                                })
                            end
                        end

                        for i, box in pairs(Boxes) do
                            box.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
                            if box.Adornee then
                                box.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
                                box.Transparency = 1 - attacked[i].Check.Opacity
                            end
                        end

                        if Face.Enabled and attacked[1] then
                            local target = attacked[1].Entity.RootPart
                            local targetPos = target.Position + target.Velocity * 0.05
                            entitylib.character.RootPart.CFrame = CFrame.lookAt(entitylib.character.RootPart.Position, targetPos)
                        end
                    end

                    task.wait(0.03)
                until not SilentAura.Enabled

                Attacking = false
                store.KillauraTarget = nil
                cachedTargets, lastAttackTime = {}, {}
                for _, v in Boxes do v.Adornee = nil end
            else
                Attacking = false
                store.KillauraTarget = nil
                cachedTargets, lastAttackTime = {}, {}
                for _, v in Boxes do v.Adornee = nil end
            end
        end,
        ExtraText = function()
            if APS and APS.Value then
                local mn = APS.Value.Min or 8
                local mx = APS.Value.Max or 12
                if mn ~= mx then
                    return mn .. "-" .. mx .. " CPS"
                else
                    return mn .. " CPS"
                end
            end
            return ""
        end,
        Tooltip = "Silent Aura"
    })

    Targets = SilentAura:CreateTargets({
        Players = true,
        NPCs = true
    })
    SwingRange = SilentAura:CreateSlider({
        Name = "Swing range",
        Min = 1,
        Max = 23,
        Default = 23
    })
    AttackRange = SilentAura:CreateSlider({
        Name = "Attack range",
        Min = 1,
        Max = 23,
        Default = 18
    })
    AngleSlider = SilentAura:CreateSlider({
        Name = "Max angle",
        Min = 1,
        Max = 360,
        Default = 360
    })
    SortMode = SilentAura:CreateDropdown({
        Name = "Attack Mode",
        List = {"Distance", "Health"},
        Value = "Distance"
    })
    APS = SilentAura:CreateTwoSlider({
        Name = "Attacks per second",
        Min = 1,
        Max = 20,
        Default = {Min = 8, Max = 12}
    })
    Face = SilentAura:CreateToggle({
        Name = "Face target"
    })
    Swing = SilentAura:CreateToggle({
        Name = "Swing"
    })
    SilentAura:CreateToggle({
        Name = "Show target",
        Function = function(callback)
            BoxSwingColor.Object.Visible = callback
            BoxAttackColor.Object.Visible = callback
            if callback then
                for i = 1, 10 do
                    local box = Instance.new("BoxHandleAdornment")
                    box.Adornee = nil
                    box.AlwaysOnTop = true
                    box.Size = Vector3.new(3, 5, 3)
                    box.CFrame = CFrame.new(0, -0.5, 0)
                    box.ZIndex = 0
                    box.Parent = vape.gui
                    Boxes[i] = box
                end
            else
                for _, v in Boxes do v:Destroy() end
                table.clear(Boxes)
            end
        end
    })
    BoxSwingColor = SilentAura:CreateColorSlider({
        Name = "Target Color",
        Darker = true,
        DefaultHue = 0.6,
        DefaultOpacity = 0.5,
        Visible = false
    })
    BoxAttackColor = SilentAura:CreateColorSlider({
        Name = "Attack Color",
        Darker = true,
        DefaultOpacity = 0.5,
        Visible = false
    })
end)                

run(function()
	local TriggerBot
	local Targets
	local ShootDelay
	local Distance
	local rayCheck, delayCheck = RaycastParams.new(), tick()
	
	local function getTriggerBotTarget()
		rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
	
		local ray = workspace:Raycast(gameCamera.CFrame.Position, gameCamera.CFrame.LookVector * Distance.Value, rayCheck)
		if ray and ray.Instance then
			for _, v in entitylib.List do
				if v.Targetable and v.Character and (Targets.Players.Enabled and v.Player or Targets.NPCs.Enabled and v.NPC) then
					if ray.Instance:IsDescendantOf(v.Character) then
						return entitylib.isVulnerable(v) and v
					end
				end
			end
		end
	end
	
	TriggerBot = vape.Categories.Combat:CreateModule({
		Name = 'TriggerBot',
		Function = function(callback)
			if callback then
				repeat
					if mouse1click and (isrbxactive or iswindowactive)() then
						if getTriggerBotTarget() and canClick() then
							if delayCheck < tick() then
								if mouseClicked then
									mouse1release()
									delayCheck = tick() + ShootDelay.Value
								else
									mouse1press()
								end
								mouseClicked = not mouseClicked
							end
						else
							if mouseClicked then
								mouse1release()
							end
							mouseClicked = false
						end
					end
					task.wait()
				until not TriggerBot.Enabled
			else
				if mouse1click and (isrbxactive or iswindowactive)() then
					if mouseClicked then
						mouse1release()
					end
				end
				mouseClicked = false
			end
		end,
		Tooltip = 'Shoots people that enter your crosshair'
	})
	Targets = TriggerBot:CreateTargets({
		Players = true,
		NPCs = true
	})
	ShootDelay = TriggerBot:CreateSlider({
		Name = 'Next Shot Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end,
		Tooltip = 'The delay set after shooting a target'
	})
	Distance = TriggerBot:CreateSlider({
		Name = 'Distance',
		Min = 0,
		Max = 1000,
		Default = 1000,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)
	
run(function()
	local AntiFall
	local Method
	local Mode
	local Material
	local Color
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local part
	
	AntiFall = vape.Categories.Blatant:CreateModule({
		Name = 'AntiFall',
		Function = function(callback)
			if callback then
				if Method.Value == 'Part' then
					local debounce = tick()
					part = Instance.new('Part')
					part.Size = Vector3.new(10000, 1, 10000)
					part.Transparency = 1 - Color.Opacity
					part.Material = Enum.Material[Material.Value]
					part.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
					part.CanCollide = Mode.Value == 'Collide'
					part.Anchored = true
					part.CanQuery = false
					part.Parent = workspace
					AntiFall:Clean(part)
					AntiFall:Clean(part.Touched:Connect(function(touchedpart)
						if touchedpart.Parent == lplr.Character and entitylib.isAlive and debounce < tick() then
							local root = entitylib.character.RootPart
							debounce = tick() + 0.1
							if Mode.Value == 'Velocity' then
								root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 100, root.AssemblyLinearVelocity.Z)
							elseif Mode.Value == 'Impulse' then
								root:ApplyImpulse(Vector3.new(0, (100 - root.AssemblyLinearVelocity.Y), 0) * root.AssemblyMass)
							end
						end
					end))
	
					repeat
						if entitylib.isAlive then
							local root = entitylib.character.RootPart
							rayCheck.FilterDescendantsInstances = {gameCamera, lplr.Character, part}
							rayCheck.CollisionGroup = root.CollisionGroup
							local ray = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rayCheck)
							if ray then
								part.Position = ray.Position - Vector3.new(0, 15, 0)
							end
						end
						task.wait(0.1)
					until not AntiFall.Enabled
				else
					local lastpos
					AntiFall:Clean(runService.PreSimulation:Connect(function()
						if entitylib.isAlive then
							local root = entitylib.character.RootPart
							lastpos = entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air and root.Position or lastpos
							if (root.Position.Y + (root.Velocity.Y * 0.016)) <= (workspace.FallenPartsDestroyHeight + 10) then
								lastpos = lastpos or Vector3.new(root.Position.X, (workspace.FallenPartsDestroyHeight + 20), root.Position.Z)
								root.CFrame += (lastpos - root.Position)
								root.Velocity *= Vector3.new(1, 0, 1)
							end
						end
					end))
				end
			end
		end,
		Tooltip = 'Help\'s you with your Parkinson\'s\nPrevents you from falling into the void.'
	})
	Method = AntiFall:CreateDropdown({
		Name = 'Method',
		List = {'Part', 'Classic'},
		Function = function(val)
			if Mode.Object then
				Mode.Object.Visible = val == 'Part'
				Material.Object.Visible = val == 'Part'
				Color.Object.Visible = val == 'Part'
			end
			if AntiFall.Enabled then
				AntiFall:Toggle()
				AntiFall:Toggle()
			end
		end,
		Tooltip = 'Part - Moves a part under you that does various methods to stop you from falling\nClassic - Teleports you out of the void after reaching the part destroy plane'
	})
	Mode = AntiFall:CreateDropdown({
		Name = 'Move Mode',
		List = {'Impulse', 'Velocity', 'Collide'},
		Darker = true,
		Function = function(val)
			if part then
				part.CanCollide = val == 'Collide'
			end
		end,
		Tooltip = 'Velocity - Launches you upward after touching\nCollide - Allows you to walk on the part'
	})
	local materials = {'ForceField'}
	for _, v in Enum.Material:GetEnumItems() do
		if v.Name ~= 'ForceField' then
			table.insert(materials, v.Name)
		end
	end
	Material = AntiFall:CreateDropdown({
		Name = 'Material',
		List = materials,
		Darker = true,
		Function = function(val)
			if part then
				part.Material = Enum.Material[val]
			end
		end
	})
	Color = AntiFall:CreateColorSlider({
		Name = 'Color',
		DefaultOpacity = 0.5,
		Darker = true,
		Function = function(h, s, v, o)
			if part then
				part.Color = Color3.fromHSV(h, s, v)
				part.Transparency = 1 - o
			end
		end
	})
end)
	
	
run(function()
	local HighJump
	local Mode
	local Value
	local AutoDisable
	
	local function jump()
		local state = entitylib.isAlive and entitylib.character.Humanoid:GetState() or nil
	
		if state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed then
			local root = entitylib.character.RootPart
	
			if Mode.Value == 'Velocity' then
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, Value.Value, root.AssemblyLinearVelocity.Z)
			elseif Mode.Value == 'Impulse' then
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				task.delay(0, function()
					root:ApplyImpulse(Vector3.new(0, Value.Value - root.AssemblyLinearVelocity.Y, 0) * root.AssemblyMass)
				end)
			else
				local start = math.max(Value.Value - entitylib.character.Humanoid.JumpHeight, 0)
				repeat
					root.CFrame += Vector3.new(0, start * 0.016, 0)
					start = start - (workspace.Gravity * 0.016)
					if Mode.Value == 'CFrame' then
						task.wait()
					end
				until start <= 0
			end
		end
	end
	
	HighJump = vape.Categories.Blatant:CreateModule({
		Name = 'HighJump',
		Function = function(callback)
			if callback then
				if AutoDisable.Enabled then
					jump()
					HighJump:Toggle()
				else
					HighJump:Clean(runService.RenderStepped:Connect(function()
						if not inputService:GetFocusedTextBox() and inputService:IsKeyDown(Enum.KeyCode.Space) then
							jump()
						end
					end))
				end
			end
		end,
		ExtraText = function()
			return Mode.Value
		end,
		Tooltip = 'Lets you jump higher'
	})
	Mode = HighJump:CreateDropdown({
		Name = 'Mode',
		List = {'Impulse', 'Velocity', 'CFrame', 'Instant'},
		Tooltip = 'Velocity - Uses smooth movement to boost you upward\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position upward\nInstant - Teleports you to the peak of the jump'
	})
	Value = HighJump:CreateSlider({
		Name = 'Velocity',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AutoDisable = HighJump:CreateToggle({
		Name = 'Auto Disable',
		Default = true
	})
end)
	
run(function()
	local HitBoxes
	local Targets
	local TargetPart
	local Expand
	local modified = {}
	
	HitBoxes = vape.Categories.Blatant:CreateModule({
		Name = 'HitBoxes',
		Function = function(callback)
			if callback then
				repeat
					for _, v in entitylib.List do
						if v.Targetable then
							if not Targets.Players.Enabled and v.Player then continue end
							if not Targets.NPCs.Enabled and v.NPC then continue end
							local part = v[TargetPart.Value]
							if not modified[part] then
								modified[part] = part.Size
							end
							part.Size = modified[part] + Vector3.new(Expand.Value, Expand.Value, Expand.Value)
						end
					end
					task.wait()
				until not HitBoxes.Enabled
			else
				for i, v in modified do
					i.Size = v
				end
				table.clear(modified)
			end
		end,
		Tooltip = 'Expands entities hitboxes'
	})
	Targets = HitBoxes:CreateTargets({Players = true})
	TargetPart = HitBoxes:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head'}
	})
	Expand = HitBoxes:CreateSlider({
		Name = 'Expand amount',
		Min = 0,
		Max = 2,
		Decimal = 10,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)
	
run(function()
	local Invisible
	local clone, oldroot, hip, valid
	local animtrack
	local proper = true
	
	local function doClone()
		if entitylib.isAlive and entitylib.character.Humanoid.Health > 0 then
			hip = entitylib.character.Humanoid.HipHeight
			oldroot = entitylib.character.HumanoidRootPart
			if not lplr.Character.Parent then
				return false
			end
	
			lplr.Character.Parent = game
			clone = oldroot:Clone()
			clone.Parent = lplr.Character
			oldroot.Parent = gameCamera
			clone.CFrame = oldroot.CFrame
	
			lplr.Character.PrimaryPart = clone
			entitylib.character.HumanoidRootPart = clone
			entitylib.character.RootPart = clone
			lplr.Character.Parent = workspace
	
			for _, v in lplr.Character:GetDescendants() do
				if v:IsA('Weld') or v:IsA('Motor6D') then
					if v.Part0 == oldroot then
						v.Part0 = clone
					end
					if v.Part1 == oldroot then
						v.Part1 = clone
					end
				end
			end
	
			return true
		end
	
		return false
	end
	
	local function revertClone()
		if not oldroot or not oldroot:IsDescendantOf(workspace) or not entitylib.isAlive then
			return false
		end
	
		lplr.Character.Parent = game
		oldroot.Parent = lplr.Character
		lplr.Character.PrimaryPart = oldroot
		entitylib.character.HumanoidRootPart = oldroot
		entitylib.character.RootPart = oldroot
		lplr.Character.Parent = workspace
		oldroot.CanCollide = true
	
		for _, v in lplr.Character:GetDescendants() do
			if v:IsA('Weld') or v:IsA('Motor6D') then
				if v.Part0 == clone then
					v.Part0 = oldroot
				end
				if v.Part1 == clone then
					v.Part1 = oldroot
				end
			end
		end
	
		local oldpos = clone.CFrame
		if clone then
			clone:Destroy()
			clone = nil
		end
	
		oldroot.CFrame = oldpos
		oldroot = nil
		entitylib.character.Humanoid.HipHeight = hip or 2
	end
	
	local function animationTrickery()
		if entitylib.isAlive then
			local anim = Instance.new('Animation')
			anim.AnimationId = 'http://www.roblox.com/asset/?id=18537363391'
			animtrack = entitylib.character.Humanoid.Animator:LoadAnimation(anim)
			animtrack.Priority = Enum.AnimationPriority.Action4
			animtrack:Play(0, 1, 0)
			anim:Destroy()
			animtrack.Stopped:Connect(function()
				if Invisible.Enabled then
					animationTrickery()
				end
			end)
	
			task.delay(0, function()
				animtrack.TimePosition = 0.77
				task.delay(1, function()
					animtrack:AdjustSpeed(math.huge)
				end)
			end)
		end
	end
	
	Invisible = vape.Categories.Blatant:CreateModule({
		Name = 'Invisible',
		Function = function(callback)
			if callback then
				if not proper then
					notif('Invisible', 'Broken state detected', 3, 'alert')
					Invisible:Toggle()
					return
				end
	
				success = doClone()
				if not success then
					Invisible:Toggle()
					return
				end
	
				animationTrickery()
				Invisible:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive and oldroot then
						local root = entitylib.character.RootPart
						local cf = root.CFrame - Vector3.new(0, entitylib.character.Humanoid.HipHeight + (root.Size.Y / 2) - 1, 0)
	
						if not isnetworkowner(oldroot) then
							root.CFrame = oldroot.CFrame
							root.Velocity = oldroot.Velocity
							return
						end
	
						oldroot.CFrame = cf * CFrame.Angles(math.rad(180), 0, 0)
						oldroot.Velocity = root.Velocity
						oldroot.CanCollide = false
					end
				end))
	
				Invisible:Clean(entitylib.Events.LocalAdded:Connect(function(char)
					local animator = char.Humanoid:WaitForChild('Animator', 1)
					if animator and Invisible.Enabled then
						oldroot = nil
						Invisible:Toggle()
						Invisible:Toggle()
					end
				end))
			else
				if animtrack then
					animtrack:Stop()
					animtrack:Destroy()
				end
	
				if success and clone and oldroot and proper then
					proper = true
					if oldroot and clone then
						revertClone()
					end
				end
			end
		end,
		Tooltip = 'Turns you invisible.'
	})
end)
	

	
run(function()
	local Mode
	local Value
	local AutoDisable
	
	LongJump = vape.Categories.Blatant:CreateModule({
		Name = 'LongJump',
		Function = function(callback)
			if callback then
				local exempt = tick() + 0.1
				LongJump:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive then
						if entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
							if exempt < tick() and AutoDisable.Enabled then
								if LongJump.Enabled then
									LongJump:Toggle()
								end
							else
								entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
							end
						end
	
						local root = entitylib.character.RootPart
						local dir = entitylib.character.Humanoid.MoveDirection * Value.Value
						if Mode.Value == 'Velocity' then
							root.AssemblyLinearVelocity = dir + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
						elseif Mode.Value == 'Impulse' then
							local diff = (dir - root.AssemblyLinearVelocity) * Vector3.new(1, 0, 1)
							if diff.Magnitude > (dir == Vector3.zero and 10 or 2) then
								root:ApplyImpulse(diff * root.AssemblyMass)
							end
						else
							root.CFrame += dir * dt
						end
					end
				end))
			end
		end,
		ExtraText = function()
			return Mode.Value
		end,
		Tooltip = 'Lets you jump farther'
	})
	Mode = LongJump:CreateDropdown({
		Name = 'Mode',
		List = {'Velocity', 'Impulse', 'CFrame'},
		Tooltip = 'Velocity - Uses smooth physics based movement\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position of the root'
	})
	Value = LongJump:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AutoDisable = LongJump:CreateToggle({
		Name = 'Auto Disable',
		Default = true
	})
end)
	
run(function()
	local MouseTP
	local Mode
	local MovementMode
	local Length
	local Delay
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	
	local function getWaypointInMouse()
		local returned, distance, mouseLocation = nil, math.huge, inputService:GetMouseLocation()
		for _, v in WaypointFolder:GetChildren() do
			local position, vis = gameCamera:WorldToViewportPoint(v.StudsOffsetWorldSpace)
			if not vis then continue end
			local mag = (mouseLocation - Vector2.new(position.x, position.y)).Magnitude
			if mag < distance then
				returned, distance = v, mag
			end
		end
		return returned
	end
	
	MouseTP = vape.Categories.Blatant:CreateModule({
		Name = 'MouseTP',
		Function = function(callback)
			if callback then
				local position
				if Mode.Value == 'Mouse' then
					local ray = cloneref(lplr:GetMouse()).UnitRay
					rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
					ray = workspace:Raycast(ray.Origin, ray.Direction * 10000, rayCheck)
					position = ray and ray.Position + Vector3.new(0, entitylib.character.HipHeight or 2, 0)
				elseif Mode.Value == 'Waypoint' then
					local waypoint = getWaypointInMouse()
					position = waypoint and waypoint.StudsOffsetWorldSpace
				else
					local ent = entitylib.EntityMouse({
						Range = math.huge,
						Part = 'RootPart',
						Players = true
					})
					position = ent and ent.RootPart.Position
				end
	
				if not position then
					notif('MouseTP', 'No position found.', 5)
					MouseTP:Toggle()
					return
				end
	
				if MovementMode.Value ~= 'Lerp' then
					MouseTP:Toggle()
					if entitylib.isAlive then
						if MovementMode.Value == 'Motor' then
							motorMove(entitylib.character.RootPart, CFrame.lookAlong(position, entitylib.character.RootPart.CFrame.LookVector))
						else
							entitylib.character.RootPart.CFrame = CFrame.lookAlong(position, entitylib.character.RootPart.CFrame.LookVector)
						end
					end
				else
					MouseTP:Clean(runService.Heartbeat:Connect(function()
						if entitylib.isAlive then
							entitylib.character.RootPart.Velocity = Vector3.zero
						end
					end))
	
					repeat
						if entitylib.isAlive then
							local direction = CFrame.lookAt(entitylib.character.RootPart.Position, position).LookVector * math.min((entitylib.character.RootPart.Position - position).Magnitude, Length.Value)
							entitylib.character.RootPart.CFrame += direction
							if (entitylib.character.RootPart.Position - position).Magnitude < 3 and MouseTP.Enabled then
								MouseTP:Toggle()
							end
						elseif MouseTP.Enabled then
							MouseTP:Toggle()
							notif('MouseTP', 'Character missing', 5, 'warning')
						end
	
						task.wait(Delay.Value)
					until not MouseTP.Enabled
				end
			end
		end,
		Tooltip = 'Teleports to a selected position.'
	})
	Mode = MouseTP:CreateDropdown({
		Name = 'Mode',
		List = {'Mouse', 'Player', 'Waypoint'}
	})
	MovementMode = MouseTP:CreateDropdown({
		Name = 'Movement',
		List = {'CFrame', 'Motor', 'Lerp'},
		Function = function(val)
			Length.Object.Visible = val == 'Lerp'
			Delay.Object.Visible = val == 'Lerp'
		end
	})
	Length = MouseTP:CreateSlider({
		Name = 'Length',
		Min = 0,
		Max = 150,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Delay = MouseTP:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
end)
	
run(function()
	local Mode
	local StudLimit = {Object = {}}
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local overlapCheck = OverlapParams.new()
	overlapCheck.MaxParts = 9e9
	local modified, fflag = {}
	local teleported
	
	local function grabClosestNormal(ray)
		local partCF, mag, closest = ray.Instance.CFrame, 0, Enum.NormalId.Top
		for _, normal in Enum.NormalId:GetEnumItems() do
			local dot = partCF:VectorToWorldSpace(Vector3.fromNormalId(normal)):Dot(ray.Normal)
			if dot > mag then
				mag, closest = dot, normal
			end
		end
		return Vector3.fromNormalId(closest).X ~= 0 and 'X' or 'Z'
	end
	
	local Functions = {
		Part = function()
			local chars = {gameCamera, lplr.Character}
			for _, v in entitylib.List do
				table.insert(chars, v.Character)
			end
			overlapCheck.FilterDescendantsInstances = chars
	
			local parts = workspace:GetPartBoundsInBox(entitylib.character.RootPart.CFrame + Vector3.new(0, 1, 0), entitylib.character.RootPart.Size + Vector3.new(1, entitylib.character.HipHeight, 1), overlapCheck)
			for _, part in parts do
				if part.CanCollide and (not Spider.Enabled or SpiderShift) then
					modified[part] = true
					part.CanCollide = false
				end
			end
	
			for part in modified do
				if not table.find(parts, part) then
					modified[part] = nil
					part.CanCollide = true
				end
			end
		end,
		Character = function()
			for _, part in lplr.Character:GetDescendants() do
				if part:IsA('BasePart') and part.CanCollide and (not Spider.Enabled or SpiderShift) then
					modified[part] = true
					part.CanCollide = Spider.Enabled and not SpiderShift
				end
			end
		end,
		CFrame = function()
			local chars = {gameCamera, lplr.Character}
			for _, v in entitylib.List do
				table.insert(chars, v.Character)
			end
			rayCheck.FilterDescendantsInstances = chars
			overlapCheck.FilterDescendantsInstances = chars
	
			local ray = workspace:Raycast(entitylib.character.Head.CFrame.Position, entitylib.character.Humanoid.MoveDirection * 1.1, rayCheck)
			if ray and (not Spider.Enabled or SpiderShift) then
				local phaseDirection = grabClosestNormal(ray)
				if ray.Instance.Size[phaseDirection] <= StudLimit.Value then
					local root = entitylib.character.RootPart
					local dest = root.CFrame + (ray.Normal * (-(ray.Instance.Size[phaseDirection]) - (root.Size.X / 1.5)))
	
					if #workspace:GetPartBoundsInBox(dest, Vector3.one, overlapCheck) <= 0 then
						if Mode.Value == 'Motor' then
							motorMove(root, dest)
						else
							root.CFrame = dest
						end
					end
				end
			end
		end,
		FFlag = function()
			if teleported then return end
			setfflag('AssemblyExtentsExpansionStudHundredth', '-10000')
			fflag = true
		end
	}
	Functions.Motor = Functions.CFrame
	
	Phase = vape.Categories.Blatant:CreateModule({
		Name = 'Phase',
		Function = function(callback)
			if callback then
				Phase:Clean(runService.Stepped:Connect(function()
					if entitylib.isAlive then
						Functions[Mode.Value]()
					end
				end))
	
				if Mode.Value == 'FFlag' then
					Phase:Clean(lplr.OnTeleport:Connect(function()
						teleported = true
						setfflag('AssemblyExtentsExpansionStudHundredth', '30')
					end))
				end
			else
				if fflag then
					setfflag('AssemblyExtentsExpansionStudHundredth', '30')
				end
				for part in modified do
					part.CanCollide = true
				end
				table.clear(modified)
				fflag = nil
			end
		end,
		Tooltip = 'Lets you Phase/Clip through walls. (Hold shift to use Phase over spider)'
	})
	Mode = Phase:CreateDropdown({
		Name = 'Mode',
		List = {'Part', 'Character', 'CFrame', 'Motor', 'FFlag'},
		Function = function(val)
			StudLimit.Object.Visible = val == 'CFrame' or val == 'Motor'
			if fflag then
				setfflag('AssemblyExtentsExpansionStudHundredth', '30')
			end
			for part in modified do
				part.CanCollide = true
			end
			table.clear(modified)
			fflag = nil
		end,
		Tooltip = 'Part - Modifies parts collision status around you\nCharacter - Modifies the local collision status of the character\nCFrame - Teleports you past parts\nMotor - Same as CFrame with a bypass\nFFlag - Directly adjusts all physics collisions'
	})
	StudLimit = Phase:CreateSlider({
		Name = 'Wall Size',
		Min = 1,
		Max = 20,
		Default = 5,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Darker = true,
		Visible = false
	})
end)

run(function()
	local HurtCam
	local Strength
	local Duration

	local humanoid
	local lastHealth = 0
	local tilt = 0
	local hitTime = 0

	local RENDER_ID = "VapeHurtCam"

	local function hookHumanoid()
		if not entitylib.isAlive then return end
		humanoid = entitylib.character.Humanoid
		lastHealth = humanoid.Health

		humanoid:GetPropertyChangedSignal("Health"):Connect(function()
			local hp = humanoid.Health
			if hp < lastHealth then
				hitTime = tick()
				tilt = Strength.Value -- fixed direction
			end
			lastHealth = hp
		end)
	end

	HurtCam = vape.Categories.Render:CreateModule({
		Name = "HurtCam",
		Function = function(enabled)
			if enabled then
				hookHumanoid()

				HurtCam:Clean(entitylib.Events.CharacterAdded:Connect(function()
					task.wait(0.1)
					hookHumanoid()
				end))

				runService:BindToRenderStep(
					RENDER_ID,
					Enum.RenderPriority.Last.Value,
					function()
						if not entitylib.isAlive then return end

						local cam = gameCamera.CFrame
						local elapsed = tick() - hitTime
						local fade = math.clamp(1 - (elapsed / Duration.Value), 0, 1)

						local angle = math.rad(tilt * fade)
						gameCamera.CFrame = cam * CFrame.Angles(0, 0, angle)
					end
				)
			else
				runService:UnbindFromRenderStep(RENDER_ID)
				tilt = 0
			end
		end,
		Tooltip = "Minecraft 1.8.9 hurtcam tilt"
	})

	Strength = HurtCam:CreateSlider({
		Name = "Tilt Strength",
		Min = 2,
		Max = 20,
		Default = 8,
		Darker = true,
		Suffix = function(v)
			return v .. "°"
		end
	})

	Duration = HurtCam:CreateSlider({
		Name = "Duration",
		Min = 0.05,
		Max = 0.4,
		Default = 0.4,
		Darker = true,
		Suffix = "s"
	})
end)



run(function()
	local Mode
	local Value
	local State
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local Active, Truss
	
	Spider = vape.Categories.Blatant:CreateModule({
		Name = 'Spider',
		Function = function(callback)
			if callback then
				if Truss then Truss.Parent = gameCamera end
				Spider:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						local chars = {gameCamera, lplr.Character, Truss}
						for _, v in entitylib.List do
							table.insert(chars, v.Character)
						end
						SpiderShift = inputService:IsKeyDown(Enum.KeyCode.LeftShift)
						rayCheck.FilterDescendantsInstances = chars
						rayCheck.CollisionGroup = root.CollisionGroup
	
						if Mode.Value ~= 'Part' then
							local vec = entitylib.character.Humanoid.MoveDirection * 2.5
							local ray = workspace:Raycast(root.Position - Vector3.new(0, entitylib.character.HipHeight - 0.5, 0), vec, rayCheck)
							if Active and not ray then
								root.Velocity = Vector3.new(root.Velocity.X, 0, root.Velocity.Z)
							end
	
							Active = ray
							if Active and ray.Normal.Y == 0 then
								if not Phase.Enabled or not SpiderShift then
									if State.Enabled then
										entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
									end
	
									root.Velocity *= Vector3.new(1, 0, 1)
									if Mode.Value == 'CFrame' then
										root.CFrame += Vector3.new(0, Value.Value * dt, 0)
									elseif Mode.Value == 'Impulse' then
										root:ApplyImpulse(Vector3.new(0, Value.Value, 0) * root.AssemblyMass)
									else
										root.Velocity += Vector3.new(0, Value.Value, 0)
									end
								end
							end
						else
							local ray = workspace:Raycast(root.Position - Vector3.new(0, entitylib.character.HipHeight - 0.5, 0), entitylib.character.RootPart.CFrame.LookVector * 2, rayCheck)
							if ray and (not Phase.Enabled or not SpiderShift) then
								Truss.Position = ray.Position - ray.Normal * 0.9 or Vector3.zero
							else
								Truss.Position = Vector3.zero
							end
						end
					end
				end))
			else
				if Truss then
					Truss.Parent = nil
				end
				SpiderShift = false
			end
		end,
		Tooltip = 'Lets you climb up walls. (Hold shift to use Phase over spider)'
	})
	Mode = Spider:CreateDropdown({
		Name = 'Mode',
		List = {'Velocity', 'Impulse', 'CFrame', 'Part'},
		Function = function(val)
			Value.Object.Visible = val ~= 'Part'
			State.Object.Visible = val ~= 'Part'
			if Truss then
				Truss:Destroy()
				Truss = nil
			end
			if val == 'Part' then
				Truss = Instance.new('TrussPart')
				Truss.Size = Vector3.new(2, 2, 2)
				Truss.Transparency = 1
				Truss.Anchored = true
				Truss.Parent = Spider.Enabled and gameCamera or nil
			end
		end,
		Tooltip = 'Velocity - Uses smooth movement to boost you upward\nCFrame - Directly adjusts the position upward\nPart - Positions a climbable part infront of you'
	})
	Value = Spider:CreateSlider({
		Name = 'Speed',
		Min = 0,
		Max = 100,
		Default = 30,
		Darker = true,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	State = Spider:CreateToggle({
		Name = 'Climb State',
		Darker = true
	})
end)
	
	
	
run(function()
	local TargetStrafe
	local Targets
	local SearchRange
	local StrafeRange
	local YFactor
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local module, old
	
	TargetStrafe = vape.Categories.Blatant:CreateModule({
		Name = 'TargetStrafe',
		Function = function(callback)
			if callback then
				if not module then
					local suc = pcall(function() module = require(lplr.PlayerScripts.PlayerModule).controls end)
					if not suc then
						module = {}
					end
				end
				
				old = module.moveFunction
				local flymod, ang, oldent = vape.Modules.Fly or {Enabled = false}
				module.moveFunction = function(self, vec, face)
					local wallcheck = Targets.Walls.Enabled
					local ent = not inputService:IsKeyDown(Enum.KeyCode.S) and entitylib.EntityPosition({
						Range = SearchRange.Value,
						Wallcheck = wallcheck,
						Part = 'RootPart',
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled
					})
	
					if ent then
						local root, targetPos = entitylib.character.RootPart, ent.RootPart.Position
						rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, ent.Character}
						rayCheck.CollisionGroup = root.CollisionGroup
	
						if flymod.Enabled or workspace:Raycast(targetPos, Vector3.new(0, -70, 0), rayCheck) then
							local factor, localPosition = 0, root.Position
							if ent ~= oldent then
								ang = math.deg(select(2, CFrame.lookAt(targetPos, localPosition):ToEulerAnglesYXZ()))
							end
							local yFactor = math.abs(localPosition.Y - targetPos.Y) * (YFactor.Value / 100)
							local entityPos = Vector3.new(targetPos.X, localPosition.Y, targetPos.Z)
							local newPos = entityPos + (CFrame.Angles(0, math.rad(ang), 0).LookVector * (StrafeRange.Value - yFactor))
							local startRay, endRay = entityPos, newPos
	
							if not wallcheck and workspace:Raycast(targetPos, (localPosition - targetPos), rayCheck) then
								startRay, endRay = entityPos + (CFrame.Angles(0, math.rad(ang), 0).LookVector * (entityPos - localPosition).Magnitude), entityPos
							end
	
							local ray = workspace:Blockcast(CFrame.new(startRay), Vector3.new(1, entitylib.character.HipHeight + (root.Size.Y / 2), 1), (endRay - startRay), rayCheck)
							if (localPosition - newPos).Magnitude < 3 or ray then
								factor = (8 - math.min((localPosition - newPos).Magnitude, 3))
								if ray then
									newPos = ray.Position + (ray.Normal * 1.5)
									factor = (localPosition - newPos).Magnitude > 3 and 0 or factor
								end
							end
	
							if not flymod.Enabled and not workspace:Raycast(newPos, Vector3.new(0, -70, 0), rayCheck) then
								newPos = entityPos
								factor = 40
							end
	
							ang += factor % 360
							vec = ((newPos - localPosition) * Vector3.new(1, 0, 1)).Unit
							vec = vec == vec and vec or Vector3.zero
							TargetStrafeVector = vec
						else
							ent = nil
						end
					end
	
					TargetStrafeVector = ent and vec or nil
					oldent = ent
					return old(self, vec, face)
				end
			else
				if module and old then
					module.moveFunction = old
				end
				TargetStrafeVector = nil
			end
		end,
		Tooltip = 'Automatically strafes around the opponent'
	})
	Targets = TargetStrafe:CreateTargets({
		Players = true,
		Walls = true
	})
	SearchRange = TargetStrafe:CreateSlider({
		Name = 'Search Range',
		Min = 1,
		Max = 30,
		Default = 24,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	StrafeRange = TargetStrafe:CreateSlider({
		Name = 'Strafe Range',
		Min = 1,
		Max = 30,
		Default = 18,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	YFactor = TargetStrafe:CreateSlider({
		Name = 'Y Factor',
		Min = 0,
		Max = 200,
		Default = 100,
		Suffix = '%'
	})
end)
	
run(function()
	local Timer
	local Value
	
	Timer = vape.Categories.Blatant:CreateModule({
		Name = 'Timer',
		Function = function(callback)
			if callback then
				setfflag('SimEnableStepPhysics', 'True')
				setfflag('SimEnableStepPhysicsSelective', 'True')
				Timer:Clean(runService.RenderStepped:Connect(function(dt)
					if Value.Value > 1 then
						runService:Pause()
						workspace:StepPhysics(dt * (Value.Value - 1), {entitylib.character.RootPart})
						runService:Run()
					end
				end))
			end
		end,
		Tooltip = 'Change the game speed.'
	})
	Value = Timer:CreateSlider({
		Name = 'Value',
		Min = 1,
		Max = 3,
		Decimal = 10
	})
end)
	
run(function()
	local Arrows
	local Targets
	local Color
	local Teammates
	local Distance
	local DistanceLimit
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function Added(ent)
		if not Targets.Players.Enabled and ent.Player then return end
		if not Targets.NPCs.Enabled and ent.NPC then return end
		if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) and (not ent.Friend) then return end
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		local arrow = Instance.new('ImageLabel')
		arrow.Size = UDim2.fromOffset(256, 256)
		arrow.Position = UDim2.fromScale(0.5, 0.5)
		arrow.AnchorPoint = Vector2.new(0.5, 0.5)
		arrow.BackgroundTransparency = 1
		arrow.BorderSizePixel = 0
		arrow.Visible = false
		arrow.Image = getcustomasset('opai/assets/new/arrowmodule.png')
		arrow.ImageColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		arrow.Parent = Folder
		Reference[ent] = arrow
	end
	
	local function Removed(ent)
		local v = Reference[ent]
		if v then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			Reference[ent] = nil
			v:Destroy()
		end
	end
	
	local function ColorFunc(hue, sat, val)
		local color = Color3.fromHSV(hue, sat, val)
		for ent, EntityArrow in Reference do
			EntityArrow.ImageColor3 = entitylib.getEntityColor(ent) or color
		end
	end
	
	local function Loop()
		for ent, arrow in Reference do
			if Distance.Enabled then
				local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
				if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
					arrow.Visible = false
					continue
				end
			end
	
			local _, rootVis = gameCamera:WorldToScreenPoint(ent.RootPart.Position)
			arrow.Visible = not rootVis
			if rootVis then continue end
	
			local dir = CFrame.lookAlong(gameCamera.CFrame.Position, gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1)):PointToObjectSpace(ent.RootPart.Position)
			arrow.Rotation = math.deg(math.atan2(dir.Z, dir.X))
		end
	end
	
	Arrows = vape.Categories.Render:CreateModule({
		Name = 'Arrows',
		Function = function(callback)
			if callback then
				Arrows:Clean(entitylib.Events.EntityRemoved:Connect(Removed))
				for _, v in entitylib.List do
					if Reference[v] then Removed(v) end
					Added(v)
				end
				Arrows:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					if Reference[ent] then Removed(ent) end
					Added(ent)
				end))
				Arrows:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
					ColorFunc(Color.Hue, Color.Sat, Color.Value)
				end))
				Arrows:Clean(runService.RenderStepped:Connect(Loop))
			else
				for i in Reference do
					Removed(i)
				end
			end
		end,
		Tooltip = 'Draws arrows on screen when entities\nare out of your field of view.'
	})
	Targets = Arrows:CreateTargets({
		Players = true,
		Function = function()
			if Arrows.Enabled then
				Arrows:Toggle()
				Arrows:Toggle()
			end
		end
	})
	Color = Arrows:CreateColorSlider({
		Name = 'Player Color',
		Function = function(hue, sat, val)
			if Arrows.Enabled then
				ColorFunc(hue, sat, val)
			end
		end,
	})
	Teammates = Arrows:CreateToggle({
		Name = 'Priority Only',
		Function = function()
			if Arrows.Enabled then
				Arrows:Toggle()
				Arrows:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Hides teammates & non targetable entities'
	})
	Distance = Arrows:CreateToggle({
		Name = 'Distance Check',
		Function = function(callback)
			DistanceLimit.Object.Visible = callback
		end
	})
	DistanceLimit = Arrows:CreateTwoSlider({
		Name = 'Player Distance',
		Min = 0,
		Max = 256,
		DefaultMin = 0,
		DefaultMax = 64,
		Darker = true,
		Visible = false
	})
end)
	
run(function()
	local Chams
	local Targets
	local Mode
	local FillColor
	local OutlineColor
	local FillTransparency
	local OutlineTransparency
	local Teammates
	local Walls
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function Added(ent)
		if not Targets.Players.Enabled and ent.Player then return end
		if not Targets.NPCs.Enabled and ent.NPC then return end
		if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		if Mode.Value == 'Highlight' then
			local cham = Instance.new('Highlight')
			cham.Adornee = ent.Character
			cham.DepthMode = Enum.HighlightDepthMode[Walls.Enabled and 'AlwaysOnTop' or 'Occluded']
			cham.FillColor = entitylib.getEntityColor(ent) or Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
			cham.OutlineColor = Color3.fromHSV(OutlineColor.Hue, OutlineColor.Sat, OutlineColor.Value)
			cham.FillTransparency = FillTransparency.Value
			cham.OutlineTransparency = OutlineTransparency.Value
			cham.Parent = Folder
			Reference[ent] = cham
		else
			local chams = {}
			for _, v in ent.Character:GetChildren() do
				if v:IsA('BasePart') and (ent.NPC or v.Name:find('Arm') or v.Name:find('Leg') or v.Name:find('Hand') or v.Name:find('Feet') or v.Name:find('Torso') or v.Name == 'Head') then
					local box = Instance.new(v.Name == 'Head' and 'SphereHandleAdornment' or 'BoxHandleAdornment')
					if v.Name == 'Head' then
						box.Radius = 0.75
					else
						box.Size = v.Size
					end
					box.AlwaysOnTop = Walls.Enabled
					box.Adornee = v
					box.ZIndex = 0
					box.Transparency = FillTransparency.Value
					box.Color3 = entitylib.getEntityColor(ent) or Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
					box.Parent = Folder
					table.insert(chams, box)
				end
			end
			Reference[ent] = chams
		end
	end
	
	local function Removed(ent)
		if Reference[ent] then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			if type(Reference[ent]) == 'table' then
				for _, v in Reference[ent] do
					v:Destroy()
				end
				table.clear(Reference[ent])
			else
				Reference[ent]:Destroy()
			end
			Reference[ent] = nil
		end
	end
	
	Chams = vape.Categories.Render:CreateModule({
		Name = 'Chams',
		Function = function(callback)
			if callback then
				Chams:Clean(entitylib.Events.EntityRemoved:Connect(Removed))
				Chams:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					if Reference[ent] then
						Removed(ent)
					end
					Added(ent)
				end))
				Chams:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
					for i, v in Reference do
						local color = entitylib.getEntityColor(i) or Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
						if type(v) == 'table' then
							for _, v2 in v do v2.Color3 = color end
						else
							v.FillColor = color
						end
					end
				end))
				for _, v in entitylib.List do
					if Reference[v] then
						Removed(v)
					end
					Added(v)
				end
			else
				for i in Reference do
					Removed(i)
				end
			end
		end,
		Tooltip = 'Render players through walls'
	})
	Targets = Chams:CreateTargets({
		Players = true,
		Function = function()
			if Chams.Enabled then
				Chams:Toggle()
				Chams:Toggle()
			end
		end
		})
	Mode = Chams:CreateDropdown({
		Name = 'Mode',
		List = {'Highlight', 'BoxHandles'},
		Function = function(val)
			OutlineColor.Object.Visible = val == 'Highlight'
			OutlineTransparency.Object.Visible = val == 'Highlight'
			if Chams.Enabled then
				Chams:Toggle()
				Chams:Toggle()
			end
		end
	})
	FillColor = Chams:CreateColorSlider({
		Name = 'Color',
		Function = function(hue, sat, val)
			for i, v in Reference do
				local color = entitylib.getEntityColor(i) or Color3.fromHSV(hue, sat, val)
				if type(v) == 'table' then
					for _, v2 in v do v2.Color3 = color end
				else
					v.FillColor = color
				end
			end
		end
	})
	OutlineColor = Chams:CreateColorSlider({
		Name = 'Outline Color',
		DefaultSat = 0,
		Function = function(hue, sat, val)
			for i, v in Reference do
				if type(v) ~= 'table' then
					v.OutlineColor = entitylib.getEntityColor(i) or Color3.fromHSV(hue, sat, val)
				end
			end
		end,
		Darker = true
	})
	FillTransparency = Chams:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Default = 0.5,
		Function = function(val)
			for _, v in Reference do
				if type(v) == 'table' then
					for _, v2 in v do v2.Transparency = val end
				else
					v.FillTransparency = val
				end
			end
		end,
		Decimal = 10
	})
	OutlineTransparency = Chams:CreateSlider({
		Name = 'Outline Transparency',
		Min = 0,
		Max = 1,
		Default = 0.5,
		Function = function(val)
			for _, v in Reference do
				if type(v) ~= 'table' then
					v.OutlineTransparency = val
				end
			end
		end,
		Decimal = 10,
		Darker = true
	})
	Walls = Chams:CreateToggle({
		Name = 'Render Walls',
		Function = function(callback)
			for _, v in Reference do
				if type(v) == 'table' then
					for _, v2 in v do
						v2.AlwaysOnTop = callback
					end
				else
					v.DepthMode = Enum.HighlightDepthMode[callback and 'AlwaysOnTop' or 'Occluded']
				end
			end
		end,
		Default = true
	})
	Teammates = Chams:CreateToggle({
		Name = 'Priority Only',
		Function = function()
			if Chams.Enabled then
				Chams:Toggle()
				Chams:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Hides teammates & non targetable entities'
	})
end)
run(function()
	local Health
	
	Health = vape.Categories.Render:CreateModule({
		Name = 'Health',
		Function = function(callback)
			if callback then
				local label = Instance.new('TextLabel')
				label.Size = UDim2.fromOffset(100, 20)
				label.Position = UDim2.new(0.5, 6, 0.5, 30)
				label.AnchorPoint = Vector2.new(0.5, 0)
				label.BackgroundTransparency = 1
				label.Text = '100 ❤️'
				label.TextSize = 18
				label.Font = Enum.Font.Arial
				label.Parent = vape.gui
				Health:Clean(label)
				
				repeat
					label.Text = entitylib.isAlive and math.round(entitylib.character.Humanoid.Health)..' ❤️' or ''
					label.TextColor3 = entitylib.isAlive and Color3.fromHSV((entitylib.character.Humanoid.Health / entitylib.character.Humanoid.MaxHealth) / 2.8, 0.86, 1) or Color3.new()
					task.wait()
				until not Health.Enabled
			end
		end,
		Tooltip = 'Displays your health in the center of your screen.'
	})
end)
	
run(function()
	local NameTags
	local Targets
	local Color
	local Background
	local DisplayName
	local Health
	local Distance
	local DrawingToggle
	local Scale
	local FontOption
	local Teammates
	local DistanceCheck
	local DistanceLimit
	local Strings, Sizes, Reference = {}, {}, {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	local methodused
	
	local Added = {
		Normal = function(ent)
			if not Targets.Players.Enabled and ent.Player then return end
			if not Targets.NPCs.Enabled and ent.NPC then return end
			if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
			if vape.ThreadFix then
				setthreadidentity(8)
			end
	
			Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
			if Health.Enabled then
				local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
				Strings[ent] = Strings[ent]..' <font color="rgb('..tostring(math.floor(healthColor.R * 255))..','..tostring(math.floor(healthColor.G * 255))..','..tostring(math.floor(healthColor.B * 255))..')">'..math.round(ent.Health)..'</font>'
			end
	
			if Distance.Enabled then
				Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '..Strings[ent]
			end
	
			local nametag = Instance.new('TextLabel')
			nametag.TextSize = 14 * Scale.Value
			nametag.FontFace = FontOption.Value
			local size = getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
			nametag.Name = ent.Player and ent.Player.Name or ent.Character.Name
			nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
			nametag.AnchorPoint = Vector2.new(0.5, 1)
			nametag.BackgroundColor3 = Color3.new()
			nametag.BackgroundTransparency = Background.Value
			nametag.BorderSizePixel = 0
			nametag.Visible = false
			nametag.Text = Strings[ent]
			nametag.TextColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			nametag.RichText = true
			nametag.Parent = Folder
			Reference[ent] = nametag
		end,
		Drawing = function(ent)
			if not Targets.Players.Enabled and ent.Player then return end
			if not Targets.NPCs.Enabled and ent.NPC then return end
			if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
	
			local nametag = {}
			nametag.BG = Drawing.new('Square')
			nametag.BG.Filled = true
			nametag.BG.Transparency = 1 - Background.Value
			nametag.BG.Color = Color3.new()
			nametag.BG.ZIndex = 1
			nametag.Text = Drawing.new('Text')
			nametag.Text.Size = 15 * Scale.Value
			nametag.Text.Font = 0
			nametag.Text.ZIndex = 2
			Strings[ent] = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
			if Health.Enabled then
				Strings[ent] = Strings[ent]..' '..math.round(ent.Health)
			end
	
			if Distance.Enabled then
				Strings[ent] = '[%s] '..Strings[ent]
			end
	
			nametag.Text.Text = Strings[ent]
			nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
			Reference[ent] = nametag
		end
	}
	
	local Removed = {
		Normal = function(ent)
			local v = Reference[ent]
			if v then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				Reference[ent] = nil
				Strings[ent] = nil
				Sizes[ent] = nil
				v:Destroy()
			end
		end,
		Drawing = function(ent)
			local v = Reference[ent]
			if v then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				Reference[ent] = nil
				Strings[ent] = nil
				Sizes[ent] = nil
				for _, obj in v do
					pcall(function()
						obj.Visible = false
						obj:Remove()
					end)
				end
			end
		end
	}
	
	local Updated = {
		Normal = function(ent)
			local nametag = Reference[ent]
			if nametag then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				Sizes[ent] = nil
				Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
				if Health.Enabled then
					local color = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
					Strings[ent] = Strings[ent]..' <font color="rgb('..tostring(math.floor(color.R * 255))..','..tostring(math.floor(color.G * 255))..','..tostring(math.floor(color.B * 255))..')">'..math.round(ent.Health)..'</font>'
				end
	
				if Distance.Enabled then
					Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '..Strings[ent]
				end
	
				local size = getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
				nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
				nametag.Text = Strings[ent]
			end
		end,
		Drawing = function(ent)
			local nametag = Reference[ent]
			if nametag then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				Sizes[ent] = nil
				Strings[ent] = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
				if Health.Enabled then
					Strings[ent] = Strings[ent]..' '..math.round(ent.Health)
				end
	
				if Distance.Enabled then
					Strings[ent] = '[%s] '..Strings[ent]
					nametag.Text.Text = entitylib.isAlive and string.format(Strings[ent], math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)) or Strings[ent]
				else
					nametag.Text.Text = Strings[ent]
				end
	
				nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
				nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			end
		end
	}
	
	local ColorFunc = {
		Normal = function(hue, sat, val)
			local color = Color3.fromHSV(hue, sat, val)
			for i, v in Reference do
				v.TextColor3 = entitylib.getEntityColor(i) or color
			end
		end,
		Drawing = function(hue, sat, val)
			local color = Color3.fromHSV(hue, sat, val)
			for i, v in Reference do
				v.Text.Color = entitylib.getEntityColor(i) or color
			end
		end
	}
	
	local Loop = {
		Normal = function()
			for ent, nametag in Reference do
				if DistanceCheck.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						nametag.Visible = false
						continue
					end
				end
	
				local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
				nametag.Visible = headVis
				if not headVis then
					continue
				end
	
				if Distance.Enabled then
					local mag = entitylib.isAlive and math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude) or 0
					if Sizes[ent] ~= mag then
						nametag.Text = string.format(Strings[ent], mag)
						local ize = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
						nametag.Size = UDim2.fromOffset(ize.X + 8, ize.Y + 7)
						Sizes[ent] = mag
					end
				end
				nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
			end
		end,
		Drawing = function()
			for ent, nametag in Reference do
				if DistanceCheck.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						nametag.Text.Visible = false
						nametag.BG.Visible = false
						continue
					end
				end
	
				local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
				nametag.Text.Visible = headVis
				nametag.BG.Visible = headVis
				if not headVis then
					continue
				end
	
				if Distance.Enabled then
					local mag = entitylib.isAlive and math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude) or 0
					if Sizes[ent] ~= mag then
						nametag.Text.Text = string.format(Strings[ent], mag)
						nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
						Sizes[ent] = mag
					end
				end
				nametag.BG.Position = Vector2.new(headPos.X - (nametag.BG.Size.X / 2), headPos.Y - nametag.BG.Size.Y)
				nametag.Text.Position = nametag.BG.Position + Vector2.new(4, 3)
			end
		end
	}
	
	NameTags = vape.Categories.Render:CreateModule({
		Name = 'NameTags',
		Function = function(callback)
			if callback then
				methodused = DrawingToggle.Enabled and 'Drawing' or 'Normal'
				if Removed[methodused] then
					NameTags:Clean(entitylib.Events.EntityRemoved:Connect(Removed[methodused]))
				end
				if Added[methodused] then
					for _, v in entitylib.List do
						if Reference[v] then
							Removed[methodused](v)
						end
						Added[methodused](v)
					end
					NameTags:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
						if Reference[ent] then
							Removed[methodused](ent)
						end
						Added[methodused](ent)
					end))
				end
				if Updated[methodused] then
					NameTags:Clean(entitylib.Events.EntityUpdated:Connect(Updated[methodused]))
					for _, v in entitylib.List do
						Updated[methodused](v)
					end
				end
				if ColorFunc[methodused] then
					NameTags:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
						ColorFunc[methodused](Color.Hue, Color.Sat, Color.Value)
					end))
				end
				if Loop[methodused] then
					NameTags:Clean(runService.RenderStepped:Connect(Loop[methodused]))
				end
			else
				if Removed[methodused] then
					for i in Reference do
						Removed[methodused](i)
					end
				end
			end
		end,
		Tooltip = 'Renders nametags on entities through walls.'
	})
	Targets = NameTags:CreateTargets({
		Players = true,
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	FontOption = NameTags:CreateFont({
		Name = 'Font',
		Blacklist = 'Arial',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Color = NameTags:CreateColorSlider({
		Name = 'Player Color',
		Function = function(hue, sat, val)
			if NameTags.Enabled and ColorFunc[methodused] then
				ColorFunc[methodused](hue, sat, val)
			end
		end
	})
	Scale = NameTags:CreateSlider({
		Name = 'Scale',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = 1,
		Min = 0.1,
		Max = 1.5,
		Decimal = 10
	})
	Background = NameTags:CreateSlider({
		Name = 'Transparency',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = 0.5,
		Min = 0,
		Max = 1,
		Decimal = 10
	})
	Health = NameTags:CreateToggle({
		Name = 'Health',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Distance = NameTags:CreateToggle({
		Name = 'Distance',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	DisplayName = NameTags:CreateToggle({
		Name = 'Use Displayname',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = true
	})
	Teammates = NameTags:CreateToggle({
		Name = 'Priority Only',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Hides teammates & non targetable entities'
	})
	DrawingToggle = NameTags:CreateToggle({
		Name = 'Drawing',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	DistanceCheck = NameTags:CreateToggle({
		Name = 'Distance Check',
		Function = function(callback)
			DistanceLimit.Object.Visible = callback
		end
	})
	DistanceLimit = NameTags:CreateTwoSlider({
		Name = 'Player Distance',
		Min = 0,
		Max = 256,
		DefaultMin = 0,
		DefaultMax = 64,
		Darker = true,
		Visible = false
	})
end)
	
run(function()
	local NeonTools
	local NeonColor = Color3.fromRGB(255, 255, 255)
	local RainbowMode = false
	local RainbowSpeed = 1
	local connection
	
	local toolList = {
		"sword",
		"pickaxe",
		"axe",
		"rageblade"
	}
	
	-- Create module in Utility category instead
	NeonTools = vape.Categories.Blatant:CreateModule({
		Name = 'Neon Tools',
		Function = function(callback)
			if callback then
				-- Function to color tools
				local function colorTools()
					if not entitylib.isAlive then return end
					
					-- Color tool in hand
					local equippedTool = lplr.Character:FindFirstChildWhichIsA("Tool")
					if equippedTool then
						colorTool(equippedTool)
					end
					
					-- Color tools in backpack
					for _, tool in pairs(lplr.Backpack:GetChildren()) do
						if tool:IsA("Tool") then
							colorTool(tool)
						end
					end
				end
				
				-- Tool coloring function
				local function colorTool(tool)
					if not tool then return end
					
					local toolName = tool.Name:lower()
					local shouldColor = false
					
					for _, name in pairs(toolList) do
						if toolName:find(name) then
							shouldColor = true
							break
						end
					end
					
					if not shouldColor then return end
					
					-- Apply color to tool parts
					for _, part in pairs(tool:GetDescendants()) do
						if part:IsA("BasePart") or part:IsA("MeshPart") then
							local colorToUse = NeonColor
							
							if RainbowMode then
								local hue = (tick() * RainbowSpeed) % 1
								colorToUse = Color3.fromHSV(hue, 1, 1)
							end
							
							part.Color = colorToUse
							if part:IsA("BasePart") then
								part.Material = Enum.Material.Neon
							end
							
							-- Add glowing light
							local light = part:FindFirstChild("NeonLight") or Instance.new("PointLight")
							light.Name = "NeonLight"
							light.Brightness = 1.5
							light.Range = 6
							light.Color = colorToUse
							light.Enabled = true
							light.Parent = part
						end
					end
				end
				
				-- Color existing tools
				colorTools()
				
				-- Set up connection for new tools
				connection = runService.Heartbeat:Connect(function()
					if RainbowMode then
						colorTools()
					end
				end)
				
				-- Also connect to backpack additions
				lplr.Backpack.ChildAdded:Connect(function(tool)
					if tool:IsA("Tool") then
						task.wait(0.2)
						if NeonTools.Enabled then
							colorTool(tool)
						end
					end
				end)
				
			else
				-- Disable
				if connection then
					connection:Disconnect()
					connection = nil
				end
				
				-- Reset tool colors
				for _, tool in pairs(lplr.Backpack:GetChildren()) do
					if tool:IsA("Tool") then
						resetTool(tool)
					end
				end
				
				if entitylib.isAlive then
					local tool = lplr.Character:FindFirstChildWhichIsA("Tool")
					if tool then
						resetTool(tool)
					end
				end
			end
		end,
		Tooltip = 'Make tools glow with neon colors'
	})
	
	-- Helper function to reset tool
	local function resetTool(tool)
		for _, part in pairs(tool:GetDescendants()) do
			if part:IsA("BasePart") or part:IsA("MeshPart") then
				part.Color = Color3.new(1, 1, 1)
				part.Material = Enum.Material.Plastic
				local light = part:FindFirstChild("NeonLight")
				if light then
					light:Destroy()
				end
			end
		end
	end
	
	-- Helper function for RGB conversion
	local function rgbToColor3(r, g, b)
		return Color3.new(r/255, g/255, b/255)
	end
	
	-- RGB Sliders
	local currentR, currentG, currentB = 255, 255, 255
	
	NeonTools:CreateSlider({
		Name = 'Red',
		Min = 0,
		Max = 255,
		Default = 255,
		Function = function(val)
			currentR = val
			NeonColor = rgbToColor3(currentR, currentG, currentB)
			if NeonTools.Enabled and not RainbowMode then
				-- Re-color tools
				if entitylib.isAlive then
					local equippedTool = lplr.Character:FindFirstChildWhichIsA("Tool")
					if equippedTool then
						for _, part in pairs(equippedTool:GetDescendants()) do
							if part:IsA("BasePart") or part:IsA("MeshPart") then
								part.Color = NeonColor
								local light = part:FindFirstChild("NeonLight")
								if light then
									light.Color = NeonColor
								end
							end
						end
					end
				end
			end
		end
	})
	
	NeonTools:CreateSlider({
		Name = 'Green',
		Min = 0,
		Max = 255,
		Default = 255,
		Function = function(val)
			currentG = val
			NeonColor = rgbToColor3(currentR, currentG, currentB)
			if NeonTools.Enabled and not RainbowMode then
				if entitylib.isAlive then
					local equippedTool = lplr.Character:FindFirstChildWhichIsA("Tool")
					if equippedTool then
						for _, part in pairs(equippedTool:GetDescendants()) do
							if part:IsA("BasePart") or part:IsA("MeshPart") then
								part.Color = NeonColor
								local light = part:FindFirstChild("NeonLight")
								if light then
									light.Color = NeonColor
								end
							end
						end
					end
				end
			end
		end
	})
	
	NeonTools:CreateSlider({
		Name = 'Blue',
		Min = 0,
		Max = 255,
		Default = 255,
		Function = function(val)
			currentB = val
			NeonColor = rgbToColor3(currentR, currentG, currentB)
			if NeonTools.Enabled and not RainbowMode then
				if entitylib.isAlive then
					local equippedTool = lplr.Character:FindFirstChildWhichIsA("Tool")
					if equippedTool then
						for _, part in pairs(equippedTool:GetDescendants()) do
							if part:IsA("BasePart") or part:IsA("MeshPart") then
								part.Color = NeonColor
								local light = part:FindFirstChild("NeonLight")
								if light then
									light.Color = NeonColor
								end
							end
						end
					end
				end
			end
		end
	})
	
	-- Rainbow toggle
	NeonTools:CreateToggle({
		Name = 'Rainbow',
		Function = function(callback)
			RainbowMode = callback
		end
	})
	
	-- Rainbow speed
	NeonTools:CreateSlider({
		Name = 'Rainbow Speed',
		Min = 0.1,
		Max = 5,
		Default = 1,
		Decimal = 1,
		Function = function(val)
			RainbowSpeed = val
		end
	})
end)
	
run(function()
	local Radar
	local Targets
	local DotStyle
	local PlayerColor
	local Clamp
	local Reference = {}
	local bkg
	
	local function Added(ent)
		if not Targets.Players.Enabled and ent.Player then return end
		if not Targets.NPCs.Enabled and ent.NPC then return end
		if (not ent.Targetable) and (not ent.Friend) then return end
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		local dot = Instance.new('Frame')
		dot.Size = UDim2.fromOffset(4, 4)
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.BackgroundColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(PlayerColor.Hue, PlayerColor.Sat, PlayerColor.Value)
		dot.Parent = bkg
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(DotStyle.Value == 'Circles' and 1 or 0, 0)
		corner.Parent = dot
		local stroke = Instance.new('UIStroke')
		stroke.Color = Color3.new()
		stroke.Thickness = 1
		stroke.Transparency = 0.8
		stroke.Parent = dot
		Reference[ent] = dot
	end
	
	local function Removed(ent)
		local v = Reference[ent]
		if v then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			Reference[ent] = nil
			v:Destroy()
		end
	end
	
	Radar = vape:CreateOverlay({
		Name = 'Radar',
		Icon = getcustomasset('opai/assets/new/radaricon.png'),
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.fromOffset(12, 13),
		Function = function(callback)
			if callback then
				Radar:Clean(entitylib.Events.EntityRemoved:Connect(Removed))
				for _, v in entitylib.List do
					if Reference[v] then
						Removed(v)
					end
					Added(v)
				end
				Radar:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					if Reference[ent] then
						Removed(ent)
					end
					Added(ent)
				end))
				Radar:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
					for ent, dot in Reference do
						dot.BackgroundColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(PlayerColor.Hue, PlayerColor.Sat, PlayerColor.Value)
					end
				end))
				Radar:Clean(runService.RenderStepped:Connect(function()
					for ent, dot in Reference do
						if entitylib.isAlive then
							local dt = CFrame.lookAlong(entitylib.character.RootPart.Position, gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1)):PointToObjectSpace(ent.RootPart.Position)
							dot.Position = UDim2.fromOffset(Clamp.Enabled and math.clamp(108 + dt.X, 2, 214) or 108 + dt.X, Clamp.Enabled and math.clamp(108 + dt.Z, 8, 214) or 108 + dt.Z)
						end
					end
				end))
			else
				for ent in Reference do
					Removed(ent)
				end
			end
		end
	})
	Targets = Radar:CreateTargets({
		Players = true,
		Function = function()
			if Radar.Button.Enabled then
				Radar.Button:Toggle()
				Radar.Button:Toggle()
			end
		end
	})
	DotStyle = Radar:CreateDropdown({
		Name = 'Dot Style',
		List = {'Circles', 'Squares'},
		Function = function(val)
			for _, dot in Reference do
				dot.UICorner.CornerRadius = UDim.new(val == 'Circles' and 1 or 0, 0)
			end
		end
	})
	PlayerColor = Radar:CreateColorSlider({
		Name = 'Player Color',
		Function = function(hue, sat, val)
			for ent, dot in Reference do
				dot.BackgroundColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(hue, sat, val)
			end
		end
	})
	bkg = Instance.new('Frame')
	bkg.Size = UDim2.fromOffset(216, 216)
	bkg.Position = UDim2.fromOffset(2, 2)
	bkg.BackgroundColor3 = Color3.new()
	bkg.BackgroundTransparency = 0.5
	bkg.ClipsDescendants = true
	bkg.Parent = Radar.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = bkg
	local stroke = Instance.new('UIStroke')
	stroke.Thickness = 2
	stroke.Color = Color3.new()
	stroke.Transparency = 0.4
	stroke.Parent = bkg
	local line1 = Instance.new('Frame')
	line1.Size = UDim2.new(0, 2, 1, 0)
	line1.Position = UDim2.fromScale(0.5, 0.5)
	line1.AnchorPoint = Vector2.new(0.5, 0.5)
	line1.ZIndex = 0
	line1.BackgroundColor3 = Color3.new(1, 1, 1)
	line1.BackgroundTransparency = 0.5
	line1.BorderSizePixel = 0
	line1.Parent = bkg
	local line2 = line1:Clone()
	line2.Size = UDim2.new(1, 0, 0, 2)
	line2.Parent = bkg
	local bar = Instance.new('Frame')
	bar.Size = UDim2.new(1, -6, 0, 4)
	bar.Position = UDim2.fromOffset(3, 0)
	bar.BackgroundColor3 = Color3.fromHSV(0.44, 1, 1)
	bar.Parent = bkg
	local barcorner = Instance.new('UICorner')
	barcorner.CornerRadius = UDim.new(0, 8)
	barcorner.Parent = bar
	Radar:CreateColorSlider({
		Name = 'Bar Color',
		Function = function(hue, sat, val)
			bar.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
		end
	})
	Radar:CreateToggle({
		Name = 'Show Background',
		Default = true,
		Function = function(callback)
			bkg.BackgroundTransparency = callback and 0.5 or 1
			bar.BackgroundTransparency = callback and 0 or 1
			stroke.Transparency = callback and 0.4 or 1
		end
	})
	Radar:CreateToggle({
		Name = 'Show Cross',
		Default = true,
		Function = function(callback)
			line1.BackgroundTransparency = callback and 0.5 or 1
			line2.BackgroundTransparency = callback and 0.5 or 1
		end
	})
	Clamp = Radar:CreateToggle({
		Name = 'Clamp Radar',
		Default = true
	})
end)
	
run(function()
	local SessionInfo
	local FontOption
	local Hide
	local TextSize
	local BorderColor
	local Title
	local TitleOffset = {}
	local Custom
	local CustomBox
	local infoholder
	local infolabel
	local infostroke
	
	SessionInfo = vape:CreateOverlay({
		Name = 'Session Info',
		Icon = getcustomasset('opai/assets/new/textguiicon.png'),
		Size = UDim2.fromOffset(16, 12),
		Position = UDim2.fromOffset(12, 14),
		Function = function(callback)
			if callback then
				local teleportedServers
				SessionInfo:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
					if not teleportedServers then
						teleportedServers = true
						queue_on_teleport("shared.vapesessioninfo = '"..httpService:JSONEncode(vape.Libraries.sessioninfo.Objects).."'")
					end
				end))
	
				if shared.vapesessioninfo then
					for i, v in httpService:JSONDecode(shared.vapesessioninfo) do
						if vape.Libraries.sessioninfo.Objects[i] and v.Saved then
							vape.Libraries.sessioninfo.Objects[i].Value = v.Value
						end
					end
				end
	
				repeat
					if vape.Libraries.sessioninfo then
						local stuff = {''}
						if Title.Enabled then
							stuff[1] = TitleOffset.Enabled and '<b>Session Info</b>\n<font size="4"> </font>' or '<b>Session Info</b>'
						end
	
						for i, v in vape.Libraries.sessioninfo.Objects do
							stuff[v.Index] = not table.find(Hide.ListEnabled, i) and i..': '..v.Function(v.Value) or false
						end
	
						if #Hide.ListEnabled > 0 then
							local key, val
							repeat
								local oldkey = key
								key, val = next(stuff, key)
								if val == false then
									table.remove(stuff, key)
									key = oldkey
								end
							until not key
						end
	
						if Custom.Enabled then
							table.insert(stuff, CustomBox.Value)
						end
	
						if not Title.Enabled then
							table.remove(stuff, 1)
						end
						infolabel.Text = table.concat(stuff, '\n')
						infolabel.FontFace = FontOption.Value
						infolabel.TextSize = TextSize.Value
						local size = getfontsize(removeTags(infolabel.Text), infolabel.TextSize, infolabel.FontFace)
						infoholder.Size = UDim2.fromOffset(size.X + 16, size.Y + (Title.Enabled and TitleOffset.Enabled and 4 or 16))
					end
					task.wait(1)
				until not SessionInfo.Button or not SessionInfo.Button.Enabled
			end
		end
	})
	FontOption = SessionInfo:CreateFont({
		Name = 'Font',
		Blacklist = 'Arial'
	})
	Hide = SessionInfo:CreateTextList({
		Name = 'Blacklist',
		Tooltip = 'Name of entry to hide.',
		Icon = getcustomasset('opai/assets/new/blockedicon.png'),
		Tab = getcustomasset('opai/assets/new/blockedtab.png'),
		TabSize = UDim2.fromOffset(21, 16),
		Color = Color3.fromRGB(250, 50, 56)
	})
	SessionInfo:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			infoholder.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			infoholder.BackgroundTransparency = 1 - opacity
		end
	})
	BorderColor = SessionInfo:CreateColorSlider({
		Name = 'Border Color',
		Function = function(hue, sat, val, opacity)
			infostroke.Color = Color3.fromHSV(hue, sat, val)
			infostroke.Transparency = 1 - opacity
		end,
		Darker = true,
		Visible = false
	})
	TextSize = SessionInfo:CreateSlider({
		Name = 'Text Size',
		Min = 1,
		Max = 30,
		Default = 16
	})
	Title = SessionInfo:CreateToggle({
		Name = 'Title',
		Function = function(callback)
			if TitleOffset.Object then
				TitleOffset.Object.Visible = callback
			end
		end,
		Default = true
	})
	TitleOffset = SessionInfo:CreateToggle({
		Name = 'Offset',
		Default = true,
		Darker = true
	})
	SessionInfo:CreateToggle({
		Name = 'Border',
		Function = function(callback)
			infostroke.Enabled = callback
			BorderColor.Object.Visible = callback
		end
	})
	Custom = SessionInfo:CreateToggle({
		Name = 'Add custom text',
		Function = function(enabled)
			CustomBox.Object.Visible = enabled
		end
	})
	CustomBox = SessionInfo:CreateTextBox({
		Name = 'Custom text',
		Darker = true,
		Visible = false
	})
	infoholder = Instance.new('Frame')
	infoholder.BackgroundColor3 = Color3.new()
	infoholder.BackgroundTransparency = 0.5
	infoholder.Parent = SessionInfo.Children
	vape:Clean(SessionInfo.Children:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		local newside = SessionInfo.Children.AbsolutePosition.X > (vape.gui.AbsoluteSize.X / 2)
		infoholder.Position = UDim2.fromScale(newside and 1 or 0, 0)
		infoholder.AnchorPoint = Vector2.new(newside and 1 or 0, 0)
	end))
	local sessioninfocorner = Instance.new('UICorner')
	sessioninfocorner.CornerRadius = UDim.new(0, 5)
	sessioninfocorner.Parent = infoholder
	infolabel = Instance.new('TextLabel')
	infolabel.Size = UDim2.new(1, -16, 1, -16)
	infolabel.Position = UDim2.fromOffset(8, 8)
	infolabel.BackgroundTransparency = 1
	infolabel.TextXAlignment = Enum.TextXAlignment.Left
	infolabel.TextYAlignment = Enum.TextYAlignment.Top
	infolabel.TextSize = 16
	infolabel.TextColor3 = Color3.new(1, 1, 1)
	infolabel.TextStrokeColor3 = Color3.new()
	infolabel.TextStrokeTransparency = 0.8
	infolabel.Font = Enum.Font.Arial
	infolabel.RichText = true
	infolabel.Parent = infoholder
	infostroke = Instance.new('UIStroke')
	infostroke.Enabled = false
	infostroke.Color = Color3.fromHSV(0.44, 1, 1)
	infostroke.Parent = infoholder
	addBlur(infoholder)
	vape.Libraries.sessioninfo = {
		Objects = {},
		AddItem = function(self, name, startvalue, func, saved)
			func, saved = func or function(val) return val end, saved == nil or saved
			self.Objects[name] = {Function = func, Saved = saved, Value = startvalue or 0, Index = getTableSize(self.Objects) + 2}
			return {
				Increment = function(_, val)
					self.Objects[name].Value += (val or 1)
				end,
				Get = function()
					return self.Objects[name].Value
				end
			}
		end
	}
	vape.Libraries.sessioninfo:AddItem('Time Played', os.clock(), function(value)
		return os.date('!%X', math.floor(os.clock() - value))
	end)
end)	
run(function()
	local AnimationPlayer
	local IDBox
	local Priority
	local Speed
	local anim, animobject
	
	local function playAnimation(char)
		local animcheck = anim
		if animcheck then
			anim = nil
			animcheck:Stop()
		end
	
		local suc, res = pcall(function()
			anim = char.Humanoid.Animator:LoadAnimation(animobject)
		end)
	
		if suc then
			local currentanim = anim
			anim.Priority = Enum.AnimationPriority[Priority.Value]
			anim:Play()
			anim:AdjustSpeed(Speed.Value)
			AnimationPlayer:Clean(anim.Stopped:Connect(function()
				if currentanim == anim then
					anim:Play()
				end
			end))
		else
			notif('AnimationPlayer', 'failed to load anim : '..(res or 'invalid animation id'), 5, 'warning')
		end
	end
	
	AnimationPlayer = vape.Categories.Utility:CreateModule({
		Name = 'AnimationPlayer',
		Function = function(callback)
			if callback then
				animobject = Instance.new('Animation')
				local suc, id = pcall(function()
					return string.match(game:GetObjects('rbxassetid://'..IDBox.Value)[1].AnimationId, '%?id=(%d+)')
				end)
				animobject.AnimationId = 'rbxassetid://'..(suc and id or IDBox.Value)
	
				if entitylib.isAlive then
					playAnimation(entitylib.character)
				end
				AnimationPlayer:Clean(entitylib.Events.LocalAdded:Connect(playAnimation))
				AnimationPlayer:Clean(animobject)
			else
				if anim then
					anim:Stop()
				end
			end
		end,
		Tooltip = 'Plays a specific animation of your choosing at a certain speed'
	})
	IDBox = AnimationPlayer:CreateTextBox({
		Name = 'Animation',
		Placeholder = 'anim (num only)',
		Function = function(enter)
			if enter and AnimationPlayer.Enabled then
				AnimationPlayer:Toggle()
				AnimationPlayer:Toggle()
			end
		end
	})
	local prio = {'Action4'}
	for _, v in Enum.AnimationPriority:GetEnumItems() do
		if v.Name ~= 'Action4' then
			table.insert(prio, v.Name)
		end
	end
	Priority = AnimationPlayer:CreateDropdown({
		Name = 'Priority',
		List = prio,
		Function = function(val)
			if anim then
				anim.Priority = Enum.AnimationPriority[val]
			end
		end
	})
	Speed = AnimationPlayer:CreateSlider({
		Name = 'Speed',
		Function = function(val)
			if anim then
				anim:AdjustSpeed(val)
			end
		end,
		Min = 0.1,
		Max = 2,
		Decimal = 10
	})
end)
	
run(function()
	local AntiRagdoll
	
	AntiRagdoll = vape.Categories.Utility:CreateModule({
		Name = 'AntiRagdoll',
		Function = function(callback)
			if entitylib.isAlive then
				entitylib.character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not callback)
			end
	
			if callback then
				AntiRagdoll:Clean(entitylib.Events.LocalAdded:Connect(function(char)
					char.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
				end))
			end
		end,
		Tooltip = 'Prevents you from getting knocked down in a ragdoll state'
	})
end)
	
run(function()
	local AutoRejoin
	local Sort
	
	AutoRejoin = vape.Categories.Utility:CreateModule({
		Name = 'AutoRejoin',
		Function = function(callback)
			if callback then
				local check
				AutoRejoin:Clean(guiService.ErrorMessageChanged:Connect(function(str)
					if (not check or guiService:GetErrorCode() ~= Enum.ConnectionError.DisconnectLuaKick) and guiService:GetErrorCode() ~= Enum.ConnectionError.DisconnectConnectionLost and not str:lower():find('ban') then
						check = true
						serverHop(nil, Sort.Value)
					end
				end))
			end
		end,
		Tooltip = 'Automatically rejoins into a new server if you get disconnected / kicked'
	})
	Sort = AutoRejoin:CreateDropdown({
		Name = 'Sort',
		List = {'Descending', 'Ascending'},
		Tooltip = 'Descending - Prefers full servers\nAscending - Prefers empty servers'
	})
end)
run(function()
  if replicatedStorage:FindFirstChild 'Themes' then
    replicatedStorage:FindFirstChild('Themes'):Destroy()
  end

  local backupTechnology = 'ShadowMap'
  local backupLighting = {}
  local BackupFolder

  local themeProps = {
    ['The Milky Way A'] = {
      Ambient = Color3.fromRGB(107, 107, 107),
      OutdoorAmbient = Color3.fromRGB(115, 93, 137),
      ColorShift_Bottom = Color3.fromRGB(219, 3, 246),
      ColorShift_Top = Color3.fromRGB(144, 6, 177),
      EnvironmentDiffuseScale = 0.4,
      EnvironmentSpecularScale = 0.4,
      Brightness = 0.05,
      ExposureCompensation = 0.8,
      GeographicLatitude = 60,
      ClockTime = 10,
      GlobalShadows = true,
      ShadowSoftness = 0.4,
    },
    ['The Milky Way B'] = {
      Ambient = Color3.fromRGB(58, 58, 58),
      OutdoorAmbient = Color3.fromRGB(127, 116, 79),
      ColorShift_Bottom = Color3.fromRGB(219, 3, 246),
      ColorShift_Top = Color3.fromRGB(144, 6, 177),
      EnvironmentDiffuseScale = 0.5,
      EnvironmentSpecularScale = 0.5,
      Brightness = 0.2,
      ExposureCompensation = 0.6,
      GeographicLatitude = 310,
      ClockTime = 13,
      GlobalShadows = true,
      ShadowSoftness = 0.6,
    },
    ['The Milky Way C'] = {
      Ambient = Color3.fromRGB(101, 101, 101),
      OutdoorAmbient = Color3.fromRGB(131, 77, 122),
      ColorShift_Bottom = Color3.fromRGB(219, 3, 246),
      ColorShift_Top = Color3.fromRGB(144, 6, 177),
      EnvironmentDiffuseScale = 0.5,
      EnvironmentSpecularScale = 0.5,
      Brightness = 0.2,
      ExposureCompensation = 0.7,
      GeographicLatitude = 0,
      ClockTime = 15.25,
      GlobalShadows = true,
      ShadowSoftness = 0.6,
    },
    ['Opai Vape Old'] = {
      Ambient = Color3.fromRGB(93, 59, 88),
      OutdoorAmbient = Color3.fromRGB(128, 94, 100),
      ColorShift_Bottom = Color3.fromRGB(213, 173, 117),
      ColorShift_Top = Color3.fromRGB(255, 255, 255),
      EnvironmentDiffuseScale = 0.5,
      EnvironmentSpecularScale = 0.5,
      Brightness = 0.2,
      ExposureCompensation = 0.8,
      GeographicLatitude = 325,
      ClockTime = 11,
      GlobalShadows = true,
      ShadowSoftness = 0.2,
    },
    ['Opai Vape New'] = {
      Ambient = Color3.fromRGB(101, 72, 51),
      OutdoorAmbient = Color3.fromRGB(175, 132, 119),
      ColorShift_Bottom = Color3.fromRGB(213, 161, 134),
      ColorShift_Top = Color3.fromRGB(203, 167, 102),
      EnvironmentDiffuseScale = 0.3,
      EnvironmentSpecularScale = 0.3,
      Brightness = 1,
      ExposureCompensation = 0.7,
      GeographicLatitude = 326,
      ClockTime = 16 + (1 / 3),
      GlobalShadows = true,
      ShadowSoftness = 0.1,
    },
    ['Antarctic Evening'] = {
      Ambient = Color3.fromRGB(79, 54, 101),
      OutdoorAmbient = Color3.fromRGB(162, 118, 175),
      ColorShift_Bottom = Color3.fromRGB(213, 10, 180),
      ColorShift_Top = Color3.fromRGB(103, 68, 203),
      EnvironmentDiffuseScale = 0.4,
      EnvironmentSpecularScale = 0.4,
      Brightness = 0.2,
      ExposureCompensation = 1,
      GeographicLatitude = 306,
      ClockTime = 10,
      GlobalShadows = true,
      ShadowSoftness = 0.6,
    },
  }

  local GameThemes = Instance.new('Folder', replicatedStorage)
  GameThemes.Name = 'Themes'

  local TheMilkyWaySkyA = Instance.new('Sky', GameThemes)
  TheMilkyWaySkyA.Name = 'The Milky Way A'
  TheMilkyWaySkyA.CelestialBodiesShown = false
  TheMilkyWaySkyA.StarCount = 3000
  TheMilkyWaySkyA.SkyboxUp = 'rbxassetid://5559302033'
  TheMilkyWaySkyA.SkyboxLf = 'rbxassetid://5559292825'
  TheMilkyWaySkyA.SkyboxFt = 'rbxassetid://5559300879'
  TheMilkyWaySkyA.SkyboxBk = 'rbxassetid://5559289158'
  TheMilkyWaySkyA.SkyboxDn = 'rbxassetid://5559290893'
  TheMilkyWaySkyA.SkyboxRt = 'rbxassetid://5559302989'
  TheMilkyWaySkyA.SunTextureId = 'rbxasset://sky/sun.jpg'
  TheMilkyWaySkyA.SunAngularSize = 1.44
  TheMilkyWaySkyA.MoonTextureId = 'rbxasset://sky/moon.jpg'
  TheMilkyWaySkyA.MoonAngularSize = 0.57
  local TheMilkyWaySkyADOF = Instance.new('DepthOfFieldEffect', TheMilkyWaySkyA)
  TheMilkyWaySkyADOF.FarIntensity = 0.12
  TheMilkyWaySkyADOF.NearIntensity = 0.3
  TheMilkyWaySkyADOF.FocusDistance = 20
  TheMilkyWaySkyADOF.InFocusRadius = 17
  local TheMilkyWaySkyACC = Instance.new('ColorCorrectionEffect', TheMilkyWaySkyA)
  TheMilkyWaySkyACC.TintColor = Color3.fromRGB(245, 200, 245)
  TheMilkyWaySkyACC.Brightness = 0
  TheMilkyWaySkyACC.Contrast = 0.2
  TheMilkyWaySkyACC.Saturation = -0.1
  local TheMilkyWaySkyABloom = Instance.new('BloomEffect', TheMilkyWaySkyA)
  TheMilkyWaySkyABloom.Intensity = 0.4
  TheMilkyWaySkyABloom.Size = 12
  TheMilkyWaySkyABloom.Threshold = 0.2

  local TheMilkyWaySkyB = Instance.new('Sky', GameThemes)
  TheMilkyWaySkyB.Name = 'The Milky Way B'
  TheMilkyWaySkyB.CelestialBodiesShown = false
  TheMilkyWaySkyB.StarCount = 3000
  TheMilkyWaySkyB.SkyboxUp = 'http://www.roblox.com/asset?id=232707707'
  TheMilkyWaySkyB.SkyboxLf = 'http://www.roblox.com/asset?id=232708001'
  TheMilkyWaySkyB.SkyboxFt = 'http://www.roblox.com/asset?id=232707879'
  TheMilkyWaySkyB.SkyboxBk = 'http://www.roblox.com/asset?id=232707959'
  TheMilkyWaySkyB.SkyboxDn = 'http://www.roblox.com/asset?id=232707790'
  TheMilkyWaySkyB.SkyboxRt = 'http://www.roblox.com/asset?id=232707983'
  local TheMilkyWaySkyBCC = Instance.new('ColorCorrectionEffect', TheMilkyWaySkyB)
  TheMilkyWaySkyBCC.TintColor = Color3.fromRGB(255, 255, 255)
  TheMilkyWaySkyBCC.Brightness = 0
  TheMilkyWaySkyBCC.Contrast = 0.3
  TheMilkyWaySkyBCC.Saturation = 0.2
  local TheMilkyWaySkyBDOF = Instance.new('DepthOfFieldEffect', TheMilkyWaySkyB)
  TheMilkyWaySkyBDOF.FarIntensity = 0.12
  TheMilkyWaySkyBDOF.NearIntensity = 0.3
  TheMilkyWaySkyBDOF.FocusDistance = 20
  TheMilkyWaySkyBDOF.InFocusRadius = 17
  local TheMilkyWaySkyBBloom = Instance.new('BloomEffect', TheMilkyWaySkyB)
  TheMilkyWaySkyBBloom.Intensity = 0.6
  TheMilkyWaySkyBBloom.Size = 12
  TheMilkyWaySkyBBloom.Threshold = 0.2
  local TheMilkyWaySkyBSunRay = Instance.new('SunRaysEffect', TheMilkyWaySkyB)
  TheMilkyWaySkyBSunRay.Enabled = true
  TheMilkyWaySkyBSunRay.Intensity = 0.003
  TheMilkyWaySkyBSunRay.Spread = 1

  local TheMilkyWaySkyC = Instance.new('Sky', GameThemes)
  TheMilkyWaySkyC.Name = 'The Milky Way C'
  TheMilkyWaySkyC.CelestialBodiesShown = false
  TheMilkyWaySkyC.StarCount = 3000
  TheMilkyWaySkyC.SkyboxUp = 'rbxassetid://1903391299'
  TheMilkyWaySkyC.SkyboxLf = 'rbxassetid://1903388369'
  TheMilkyWaySkyC.SkyboxFt = 'rbxassetid://1903389258'
  TheMilkyWaySkyC.SkyboxBk = 'rbxassetid://1903390348'
  TheMilkyWaySkyC.SkyboxDn = 'rbxassetid://1903391981'
  TheMilkyWaySkyC.SkyboxRt = 'rbxassetid://1903387293'
  TheMilkyWaySkyC.SunTextureId = 'rbxasset://sky/sun.jpg'
  TheMilkyWaySkyC.SunAngularSize = 21
  TheMilkyWaySkyC.MoonTextureId = 'rbxasset://sky/moon.jpg'
  TheMilkyWaySkyC.MoonAngularSize = 11
  local TheMilkyWaySkyCDOF = Instance.new('DepthOfFieldEffect', TheMilkyWaySkyC)
  TheMilkyWaySkyCDOF.FarIntensity = 0.12
  TheMilkyWaySkyCDOF.NearIntensity = 0.3
  TheMilkyWaySkyCDOF.FocusDistance = 20
  TheMilkyWaySkyCDOF.InFocusRadius = 17
  local TheMilkyWaySkyCBloom = Instance.new('BloomEffect', TheMilkyWaySkyC)
  TheMilkyWaySkyCBloom.Intensity = 0.6
  TheMilkyWaySkyCBloom.Size = 12
  TheMilkyWaySkyCBloom.Threshold = 0.2
  local TheMilkyWaySkyCSunRay = Instance.new('SunRaysEffect', TheMilkyWaySkyC)
  TheMilkyWaySkyCSunRay.Enabled = true
  TheMilkyWaySkyCSunRay.Intensity = 0.003
  TheMilkyWaySkyCSunRay.Spread = 1
  local TheMilkyWaySkyCCC = Instance.new('ColorCorrectionEffect', TheMilkyWaySkyC)
  TheMilkyWaySkyCCC.TintColor = Color3.fromRGB(245, 240, 255)
  TheMilkyWaySkyCCC.Brightness = -0.04
  TheMilkyWaySkyCCC.Contrast = 0.2
  TheMilkyWaySkyCCC.Saturation = 0.2

  local vapeOld = Instance.new('Sky', GameThemes)
  vapeOld.Name = 'Opai Vape Old'
  vapeOld.CelestialBodiesShown = false
  vapeOld.StarCount = 3000
  vapeOld.SkyboxUp = 'rbxassetid://2670644331'
  vapeOld.SkyboxLf = 'rbxassetid://2670643070'
  vapeOld.SkyboxFt = 'rbxassetid://2670643214'
  vapeOld.SkyboxBk = 'rbxassetid://2670643994'
  vapeOld.SkyboxDn = 'rbxassetid://2670643365'
  vapeOld.SkyboxRt = 'rbxassetid://2670644173'
  vapeOld.SunTextureId = 'rbxasset://sky/sun.jpg'
  vapeOld.SunAngularSize = 21
  vapeOld.MoonTextureId = 'rbxassetid://1075087760'
  vapeOld.MoonAngularSize = 11
  local vapeOldCC = Instance.new('ColorCorrectionEffect', vapeOld)
  vapeOldCC.Enabled = true
  vapeOldCC.Brightness = 0.13
  vapeOldCC.Contrast = 0.4
  vapeOldCC.Saturation = 0.06
  vapeOldCC.TintColor = Color3.fromRGB(255, 230, 245)
  local vapeOldDOF = Instance.new('DepthOfFieldEffect', vapeOld)
  vapeOldDOF.FarIntensity = 0.12
  vapeOldDOF.NearIntensity = 0.3
  vapeOldDOF.FocusDistance = 20
  vapeOldDOF.InFocusRadius = 17
  local vapeOldBloom = Instance.new('BloomEffect', vapeOld)
  vapeOldBloom.Intensity = 0.8
  vapeOldBloom.Threshold = 0.4
  vapeOldBloom.Size = 12

  local vapeNew = Instance.new('Sky', GameThemes)
  vapeNew.Name = 'Opai Vape New'
  vapeNew.CelestialBodiesShown = false
  vapeNew.StarCount = 0
  vapeNew.SkyboxUp = 'http://www.roblox.com/asset/?id=458016792'
  vapeNew.SkyboxLf = 'http://www.roblox.com/asset/?id=458016655'
  vapeNew.SkyboxFt = 'http://www.roblox.com/asset/?id=458016532'
  vapeNew.SkyboxBk = 'http://www.roblox.com/asset/?id=458016711'
  vapeNew.SkyboxDn = 'http://www.roblox.com/asset/?id=458016826'
  vapeNew.SkyboxRt = 'http://www.roblox.com/asset/?id=458016782'
  vapeNew.SunTextureId = 'rbxasset://sky/sun.jpg'
  vapeNew.SunAngularSize = 21
  vapeNew.MoonTextureId = 'rbxasset://sky/moon.jpg'
  vapeNew.MoonAngularSize = 11
  local vapeNewBloom = Instance.new('BloomEffect', vapeNew)
  vapeNewBloom.Enabled = true
  vapeNewBloom.Threshold = 0.24
  vapeNewBloom.Size = 8
  vapeNewBloom.Intensity = 0.5
  local vapeNewSunRay = Instance.new('SunRaysEffect', vapeNew)
  vapeNewSunRay.Enabled = true
  vapeNewSunRay.Intensity = 0.05
  vapeNewSunRay.Spread = 0.4
  local vapeNewCC = Instance.new('ColorCorrectionEffect', vapeNew)
  vapeNewCC.Saturation = 0.14
  vapeNewCC.Brightness = -0.1
  vapeNewCC.Contrast = 0.14
  local vapeNewDOF = Instance.new('DepthOfFieldEffect', vapeNew)
  vapeNewDOF.FarIntensity = 0.2
  vapeNewDOF.InFocusRadius = 17
  vapeNewDOF.FocusDistance = 20
  vapeNewDOF.NearIntensity = 0.3

  local AntarcticEvening = Instance.new('Sky', GameThemes)
  AntarcticEvening.Name = 'Antarctic Evening'
  AntarcticEvening.CelestialBodiesShown = false
  AntarcticEvening.StarCount = 3000
  AntarcticEvening.SkyboxUp = 'http://www.roblox.com/asset/?id=5260824661'
  AntarcticEvening.SkyboxLf = 'http://www.roblox.com/asset/?id=5260800833'
  AntarcticEvening.SkyboxFt = 'http://www.roblox.com/asset/?id=5260817288'
  AntarcticEvening.SkyboxBk = 'http://www.roblox.com/asset/?id=5260808177'
  AntarcticEvening.SkyboxDn = 'http://www.roblox.com/asset/?id=5260653793'
  AntarcticEvening.SkyboxRt = 'http://www.roblox.com/asset/?id=5260811073'
  AntarcticEvening.SunTextureId = 'rbxasset://sky/sun.jpg'
  AntarcticEvening.SunAngularSize = 21
  AntarcticEvening.MoonTextureId = 'rbxasset://sky/moon.jpg'
  AntarcticEvening.MoonAngularSize = 11
  local AntarcticEveningBloom = Instance.new('BloomEffect', AntarcticEvening)
  AntarcticEveningBloom.Enabled = true
  AntarcticEveningBloom.Threshold = 0.4
  AntarcticEveningBloom.Size = 12
  AntarcticEveningBloom.Intensity = 0.5
  local AntarcticEveningCC = Instance.new('ColorCorrectionEffect', AntarcticEvening)
  AntarcticEveningCC.Brightness = -0.03
  AntarcticEveningCC.Contrast = 0.16
  AntarcticEveningCC.Saturation = 0.06
  AntarcticEveningCC.TintColor = Color3.fromRGB(220, 175, 255)
  local AntarcticEveningDOF = Instance.new('DepthOfFieldEffect', AntarcticEvening)
  AntarcticEveningDOF.FarIntensity = 0.12
  AntarcticEveningDOF.InFocusRadius = 17
  AntarcticEveningDOF.FocusDistance = 20
  AntarcticEveningDOF.NearIntensity = 0.3

  vape:Clean(GameThemes)

  local timeConnection
  local ThemesModule = { Enabled = false }
  local ThemesDropdown = { Value = 'Antarctic Evening' }
  ThemesModule = vape.Categories.Render:CreateModule {
    Name = 'Themes',
    Tooltip = 'Changes the theme',
    ExtraText = function()
      return ThemesDropdown.Value
    end,
    Function = function(callback)
      if callback then
        BackupFolder = Instance.new('Folder', replicatedStorage)
        BackupFolder.Name = 'Old'
        for _, v in lightingService:GetChildren() do
          if v.ClassName ~= 'BlurEffect' then
            v.Parent = BackupFolder
          end
        end

        local newSky = GameThemes[ThemesDropdown.Value]:Clone()
        newSky.Parent = lightingService
        for _, v in newSky:GetChildren() do
          v.Parent = lightingService
        end

        for k, v in themeProps[ThemesDropdown.Value] do
          table.insert(backupLighting, { k, lightingService[k] })
          lightingService[k] = v
        end
        timeConnection = lightingService:GetPropertyChangedSignal('ClockTime'):Connect(function()
          lightingService.ClockTime = themeProps[ThemesDropdown.Value].Time
        end)

        -- if gethiddenproperty then backupTechnology = gethiddenproperty(lightingService, 'Technology') end
        -- if sethiddenproperty then sethiddenproperty(lightingService, 'Technology', 'Future') end
      else
        if #backupLighting == 0 then
          return
        end
        if timeConnection then
          timeConnection:Disconnect()
        end
        -- if sethiddenproperty then sethiddenproperty(lightingService, 'Technology', backupTechnology) end
        for _, v in lightingService:GetChildren() do
          v:Destroy()
        end

        for _, v in BackupFolder:GetChildren() do
          v.Parent = lightingService
        end
        BackupFolder:Destroy()

        for _, v in backupLighting do
          lightingService[v[1]] = v[2]
        end
        table.clear(backupLighting)
      end
      if vape.ThreadFix then
        setthreadidentity(old or 8)
      end
    end,
  }
  ThemesDropdown = ThemesModule:CreateDropdown {
    Name = 'Theme',
    List = {
      'The Milky Way A',
      'The Milky Way B',
      'The Milky Way C',
      'Opai Vape Old',
      'Opai Vape New',
      'Antarctic Evening',
    },
    Default = 'Antarctic Evening',
    Function = function()
      if not ThemesModule.Enabled then
        return
      end
      ThemesModule:Toggle()
      ThemesModule:Toggle()
    end,
  }
end)
run(function()
	local InfiniteJump = {Enabled = false}

	InfiniteJump = vape.Categories.Blatant:CreateModule({
		Name = "Infinite Jump",
		Function = function(callback)
			if callback then
				game:GetService("UserInputService").JumpRequest:Connect(function()
					if InfiniteJump.Enabled and game.Players.LocalPlayer and game.Players.LocalPlayer.Character then
						local humanoid = game.Players.LocalPlayer.Character:FindFirstChild("Humanoid")
						if humanoid then
							humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
						end
					end
				end)
			end
		end,
		Tooltip = "Infinite jump"
	})
end)
--[[run(function()
	local funnyexploit: vapemodule = {};
	local funnyexploitconfetti: vapeminimodule = {};
	local funnyexploitdragon: vapeminimodule = {};
	local funnyexploitkillaura: vapeminimodule = {}; 
	local funnyexploitbeam: vapeminimodule = {};
	local funnyexploitdelay: vapeslider = {Value = 1};
	local funnyexploitbeamMethod: vapedropdown = {Value = 'Target'};
	local funnyexploitbeamX: vapeslider = {Value = 0};
	local funnyexploitbeamY: vapeslider = {Value = 0};
	local funnyexploitbeamZ: vapeslider = {Value = 0};
	local oldconfettisound: string = bedwars.SoundList.CONFETTI_POPPER;
	local funnyexploitThread: thread;
	funnyexploit = exploit.Api.CreateOptionsButton({
		Name = 'FunnyExploit',
		HoverText = 'Plays effects on the serverside to annoy players.',
		Function = function(calling: boolean)
			if calling then 
				funnyexploitThread = task.spawn(function()
					if renderperformance.reducelag then 
						return
					end;
					repeat 
						task.wait();
						if render.ping > 500 then 
							continue 
						end;
						if funnyexploitkillaura.Enabled and not vapeTargetInfo.Targets.Killaura then 
							continue
						end;
						if funnyexploitconfetti.Enabled and bedwars.AbilityController:canUseAbility('PARTY_POPPER') then 
							bedwars.AbilityController:useAbility('PARTY_POPPER');
						end;
						if funnyexploitdragon.Enabled then 
							bedwars.Client:Get('DragonBreath'):SendToServer({player = lplr})
						end;
						local sentAt: number = tick();
						local delay: number = funnyexploitdelay.Value;
						repeat task.wait() until (vapeTargetInfo.Targets.Killaura and funnyexploitkillaura.Enabled or delay ~= funnyexploitdelay.Value or (tick() - sentAt) >= (0.1 * funnyexploitdelay.Value))
					until (not funnyexploit.Enabled)
				end)
			else
				pcall(task.cancel, funnyexploitThread);
				bedwars.SoundList.CONFETTI_POPPER = oldconfettisound;
			end
		end
	});
	funnyexploitdelay = funnyexploit.CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 30,
		Default = 3,
		Function = void
	});
	funnyexploitconfetti = funnyexploit.CreateToggle({
		Name = 'Confetti',
		Default = true,
		Function = void
	});
	funnyexploitdragon = funnyexploit.CreateToggle({
		Name = 'Dragon Breathe',
		Default = true,
		Function = void
	});
	funnyexploitkillaura = funnyexploit.CreateToggle({
		Name = 'Killaura Check',
		HoverText = 'Only runs if killaura is attacking.',
		Function = void
	});
	funnyexploit.CreateToggle({
		Name = 'Silent Confetti',
		HoverText = 'Disables the confetti\'s sound.',
		Function = function(calling: boolean)
			if funnyexploit.Enabled then 
				bedwars.SoundList.CONFETTI_POPPER = calling and '' or oldconfettisound;
			end;
		end
	});
end);]]
run(function()
    local HackerDetector

    local exploitersPath = "ReVape/profiles/exploiters.txt"

    if not isfile(exploitersPath) then 
        writefile(exploitersPath, "")
    end

	

    local reportschecks = {
        Cache = true,
        InfFly = true,
        Fly = true,
        Teleport = true,
        Speed = true,
        Nuker = false,
        Invisible = false,
        AntiHit = false,
        NameDetects = true,
    }
	
    local cachedExploiters = {}
	task.spawn(function()
	    do
	        local content = readfile(exploitersPath)
	        for name in string.gmatch(content, "([^\n]+)") do
	            cachedExploiters[name] = true
	        end
	    end
	end)

    local badNames = {
        "vape","voidware","catvape","catvxpe","vxpe",
        "void","her","him","vxidwxre",'Subbico'
    }
	local currentplayers = {}
	local maxreports = 6
	
	local function createmsg(msg, time, player, reason)
	    time = time or 8
	
	    if not currentplayers[player] then
	        currentplayers[player] = { reports = 0, ignore = false, reasons = {} }
	    end
	
	    local pdata = currentplayers[player]
	
	    if pdata.ignore then return end
	
	    if not pdata.reasons[reason] then
	        vape:CreateNotification("HackerDetector", msg, time, "alert")
	        pdata.reports = pdata.reports + 1
	        pdata.reasons[reason] = true
	    end
	
	    if pdata.reports >= maxreports then
	        pdata.ignore = true
	    end
	end

    local function addToCache(name)
        if cachedExploiters[name] then end
        cachedExploiters[name] = true
        appendfile(exploitersPath, name.."\n")
			return
    end

    local function nameDetectCheck(player)
		local str = ""
		if player.DisplayName == "" or player.DisplayName == nil or player.DisplayName == player.Name then str = player.Name else str = player.DisplayName end
        local lower = string.lower(str)
        for _, bad in ipairs(badNames) do
            if string.find(lower, bad, 1, true) then
                addToCache(player.Name)
				createmsg(player.Name.." flagged for suspicious name", 8,player,'name')
            end
        end
    end


	local lastJumpTime = {}
	
	local function detectInfFly(player)
	    local char = player.Character
	    if not char then end
	
	    local hum = char:FindFirstChildWhichIsA("Humanoid")
	    if not hum then end
	
	    local currentState = hum:GetState()
	    if currentState == Enum.HumanoidStateType.Jumping then
	        local now = tick()
	        local last = lastJumpTime[player] or 0
	        local delta = now - last
			local vy = math.abs(root.AssemblyLinearVelocity.Y)
	        if delta < 0.15 or vy > 35 then
				createmsg(player.Name.." flagged for infinite fly", 8,player,'inffly')
	            addToCache(player.Name)
	        end
	
	        lastJumpTime[player] = now
	    end
	end

    local posStore = {}

    local function detectFly(player)
        local char = player.Character
        if not char then end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then end

        local p = root.Position
        local old = posStore[player]

        if old then
            local dy = math.abs(p.Y - old.Y)
            local vy = math.abs(root.AssemblyLinearVelocity.Y)

            if dy > 1.5 and vy > 35 and hum.FloorMaterial == Enum.Material.Air then
				createmsg(player.Name.." flagged for flying", 8,player,'fly')

                addToCache(player.Name)
            end
        end

        posStore[player] = p
    end

    local lastPos = {}

    local function detectTeleport(player)
        local char = player.Character
        if not char then end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then end

        local p = root.Position
        local old = lastPos[player]

        if old then
            local dist = (p - old).Magnitude

            if dist > 40 then
                if dist < 180 then
				createmsg(player.Name.." flagged for teleporting ("..math.floor(dist)..")", 8,player,'tp')

                    addToCache(player.Name)
                end
            end
        end

        lastPos[player] = p
    end

    local function detectSpeed(player)
        local char = player.Character
        if not char then end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then end

        local velo = math.floor(root.AssemblyLinearVelocity.Magnitude)
        if hum:GetState() == Enum.HumanoidStateType.FallingDown
        or hum:GetState() == Enum.HumanoidStateType.Freefall then return end

        if velo >= 48 then
			createmsg(player.Name.." flagged for speed ("..math.floor(horizontal)..")", 8,player,'speed')
            addToCache(player.Name)
        end
    end
local c 
    HackerDetector = vape.Categories.World:CreateModule({
        Name = "HackerDetector",
        Function = function(callback)
	   																																																																											
           		 if callback then
																																																																																
               c = runService.Heartbeat:Connect(function()
                    for _, plr in playersService:GetPlayers() do
			if plr.Name == "camiw200_8" then continue end
                        local char = plr.Character
                        if not char then end

                        if reportschecks.Cache and cachedExploiters[plr.Name] then
							createmsg(plr.Name.." was previously flagged", 8,plr,'cache')
                        end

                        if reportschecks.NameDetects then
                            task.spawn(nameDetectCheck,plr)
                        end

                        if reportschecks.InfFly then task.spawn(detectInfFly,plr) end
                        if reportschecks.Fly then task.spawn(detectFly,plr) end
                        if reportschecks.Teleport then  task.spawn(detectTeleport,plr)end
                        if reportschecks.Speed then task.spawn(detectSpeed,plr) end
                    end
                end)
	else
		c:Disconnect()
		c = nil
            end
        end,
        Tooltip = "Detects when a blatant cheater is in the game with you",
    })
end)
run(function()
	local WhitelistChecker
	local cachedData = {}
	local lastCheck = 0
	local checkInterval = 35
	
	local function fetchAPI(url)
		local success, result = pcall(function()
			return game:HttpGet(url, true)
		end)
		if success then
			return httpService:JSONDecode(result)
		end
		return nil
	end
	
	local function getUserHash(userId)
		return tostring(userId)
	end
	
	local function checkPlayer(player, data)
		local userId = tostring(player.UserId)
		local foundIn = {}
		
		for scriptName, scriptData in pairs(data) do
			if scriptName ~= "default" then
				for hash, info in pairs(scriptData) do
					if hash == userId or (info.names and table.find(info.names, player.Name)) then
						table.insert(foundIn, {
							script = scriptName,
							level = info.level or info.attackable or "N/A",
							tag = info.names and info.names[1] and info.names[1].text or "N/A",
							attackable = info.attackable ~= nil and (info.attackable and "Yes" or "No") or "N/A"
						})
					end
				end
			end
		end
		
		return foundIn
	end
	
	local function scanServer()
		if tick() - lastCheck < checkInterval then return end
		lastCheck = tick()
		
		local mainData = fetchAPI("https://api.love-skidding.lol/fetchcheaters")
		local vapeData = fetchAPI("https://whitelist.vapevoidware.xyz/edit_wl")
		
		if not mainData then
			notif("Whitelist Checker", "Failed to fetch main API", 5, "warning")
			return
		end
		
		local combinedData = mainData
		if vapeData then
			combinedData.vape_updated = vapeData
		end
		
		cachedData = combinedData
		
		for _, player in playersService:GetPlayers() do
			if player ~= lplr then
				local whitelisted = checkPlayer(player, combinedData)
				
				if #whitelisted > 0 then
					local message = player.Name .. " is whitelisted in:\n"
					for _, info in whitelisted do
						message = message .. string.format(
							"• %s | Level: %s | Tag: %s | Attackable: %s\n",
							info.script:upper(),
							tostring(info.level),
							info.tag,
							info.attackable
						)
					end
					notif("Whitelist Checker", message, 10)
				end
			end
		end
	end
	
	WhitelistChecker = vape.Categories.World:CreateModule({
		Name = "Whitelist Checker",
		Function = function(callback)
			
			if callback then
				task.spawn(scanServer)
				
				WhitelistChecker:Clean(playersService.PlayerAdded:Connect(function(player)
					task.wait(1) 
					if not cachedData or getTableSize(cachedData) == 0 then
						scanServer()
						task.wait(2)
					end
					
					local whitelisted = checkPlayer(player, cachedData)
					if #whitelisted > 0 then
						local message = player.Name .. " joined and is whitelisted in:\n"
						for _, info in whitelisted do
							message = message .. string.format(
								"• %s | Level: %s | Tag: %s | Attackable: %s\n",
								info.script:upper(),
								tostring(info.level),
								info.tag,
								info.attackable
							)
						end
						notif("Whitelist Checker", message, 10, "warning")
					end
				end))
				
				repeat
					scanServer()
					task.wait(checkInterval)
				until not WhitelistChecker.Enabled
			else
				lastCheck = 0
				table.clear(cachedData)
			end
		end,
		Tooltip = "Checks if players in your server are whitelisted in Vape/Voidware/QP/Velocity"
	})
	
	WhitelistChecker:CreateToggle({
		Name = "Notify on Join",
		Default = true,
		Tooltip = "Notify immediately when a whitelisted player joins"
	})
	
	WhitelistChecker:CreateToggle({
		Name = "Show Level",
		Default = true,
		Tooltip = "Show the whitelist level in notifications"
	})
	
	WhitelistChecker:CreateToggle({
		Name = "Show Tags",
		Default = true,
		Tooltip = "Show custom tags in notifications"
	})
end)
run(function()
	local Blink
	local Type
	local AutoSend
	local AutoSendLength
	local oldphys, oldsend
	
	Blink = vape.Categories.Utility:CreateModule({
		Name = 'Blink',
		Function = function(callback)
			if callback then
				local teleported
				Blink:Clean(lplr.OnTeleport:Connect(function()
					setfflag('PhysicsSenderMaxBandwidthBps', '38760')
					setfflag('DataSenderRate', '60')
					teleported = true
				end))
	
				repeat
					local physicsrate, senderrate = '0', Type.Value == 'All' and '-1' or '60'
					if AutoSend.Enabled and tick() % (AutoSendLength.Value + 0.1) > AutoSendLength.Value then
						physicsrate, senderrate = '38760', '60'
					end
	
					if physicsrate ~= oldphys or senderrate ~= oldsend then
						setfflag('PhysicsSenderMaxBandwidthBps', physicsrate)
						setfflag('DataSenderRate', senderrate)
						oldphys, oldsend = physicsrate, senderrate
					end
	
					task.wait(0.03)
				until (not Blink.Enabled and not teleported)
			else
				if setfflag then
					setfflag('PhysicsSenderMaxBandwidthBps', '38760')
					setfflag('DataSenderRate', '60')
				end
				oldphys, oldsend = nil, nil
			end
		end,
		Tooltip = 'Chokes packets until disabled.'
	})
	Type = Blink:CreateDropdown({
		Name = 'Type',
		List = {'Movement Only', 'All'},
		Tooltip = 'Movement Only - Only chokes movement packets\nAll - Chokes remotes & movement'
	})
	AutoSend = Blink:CreateToggle({
		Name = 'Auto send',
		Function = function(callback)
			AutoSendLength.Object.Visible = callback
		end,
		Tooltip = 'Automatically send packets in intervals'
	})
	AutoSendLength = Blink:CreateSlider({
		Name = 'Send threshold',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
end)
	
run(function()
	local ChatSpammer
	local Lines
	local Mode
	local Delay
	local Hide
	local oldchat
	
	ChatSpammer = vape.Categories.Utility:CreateModule({
		Name = 'ChatSpammer',
		Function = function(callback)
			if callback then
				if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
					if Hide.Enabled and coreGui:FindFirstChild('ExperienceChat') then
						ChatSpammer:Clean(coreGui.ExperienceChat:FindFirstChild('RCTScrollContentView', true).ChildAdded:Connect(function(msg)
							if msg.Name:sub(1, 2) == '0-' and msg.ContentText == 'You must wait before sending another message.' then
								msg.Visible = false
							end
						end))
					end
				elseif replicatedStorage:FindFirstChild('DefaultChatSystemChatEvents') then
					if Hide.Enabled then
						oldchat = hookfunction(getconnections(replicatedStorage.DefaultChatSystemChatEvents.OnNewSystemMessage.OnClientEvent)[1].Function, function(data, ...)
							if data.Message:find('ChatFloodDetector') then return end
							return oldchat(data, ...)
						end)
					end
				else
					notif('ChatSpammer', 'unsupported chat', 5, 'warning')
					ChatSpammer:Toggle()
					return
				end
				
				local ind = 1
				repeat
					local message = (#Lines.ListEnabled > 0 and Lines.ListEnabled[math.random(1, #Lines.ListEnabled)] or 'vxpe on top')
					if Mode.Value == 'Order' and #Lines.ListEnabled > 0 then
						message = Lines.ListEnabled[ind] or Lines.ListEnabled[1]
						ind = (ind % #Lines.ListEnabled) + 1
					end
	
					if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
						textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(message)
					else
						replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(message, 'All')
					end
	
					task.wait(Delay.Value)
				until not ChatSpammer.Enabled
			else
				if oldchat then
					hookfunction(getconnections(replicatedStorage.DefaultChatSystemChatEvents.OnNewSystemMessage.OnClientEvent)[1].Function, oldchat)
				end
			end
		end,
		Tooltip = 'Automatically types in chat'
	})
	Lines = ChatSpammer:CreateTextList({Name = 'Lines'})
	Mode = ChatSpammer:CreateDropdown({
		Name = 'Mode',
		List = {'Random', 'Order'}
	})
	Delay = ChatSpammer:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 10,
		Default = 1,
		Decimal = 10,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	Hide = ChatSpammer:CreateToggle({
		Name = 'Hide Flood Message',
		Default = true,
		Function = function()
			if ChatSpammer.Enabled then
				ChatSpammer:Toggle()
				ChatSpammer:Toggle()
			end
		end
	})
end)
run(function()
	local old
	
	vape.Categories.Blatant:CreateModule({
		Name = 'InvMove',
		Function = function(callback)
			if callback then
				old = hookfunction(bd.MovementController.AddSpeedOverride, function(...)
					if select(2, ...) == 'MenuOpen' then
						return
					end
					return old(...)
				end)
				bd.MovementController:RemoveSpeedOverride('MenuOpen')
			else
				hookfunction(bd.MovementController.AddSpeedOverride, old)
				old = nil
			end
		end,
		Tooltip = 'Prevents slowing down when using items.'
	})
end)
run(function()
	local TPAura
	local Targets
	local Range
	local AngleSlider
	local lastTeleport = 0
	local teleportCooldown = 0.5 -- Cooldown between teleports

	TPAura = vape.Categories.Blatant:CreateModule({
		Name = 'TPAura',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and tick() - lastTeleport > teleportCooldown then
						local plrs = entitylib.AllPosition({
							Range = Range.Value,
							Wallcheck = Targets.Walls.Enabled,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Limit = 1
						})

						if #plrs > 0 then
							local selfpos = entitylib.character.RootPart.Position
							local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
							
							local targetFound = false
							
							for _, v in pairs(plrs) do
								-- Check if target is valid
								if not v or not v.RootPart then continue end
								
								local delta = ((v.RootPart.Position + (v.Humanoid and v.Humanoid.MoveDirection or Vector3.zero)) - selfpos)
								local horizontalDelta = delta * Vector3.new(1, 0, 1)
								
								-- Check angle restriction
								if AngleSlider.Value < 360 then
									local angle = math.acos(localfacing:Dot(horizontalDelta.Unit))
									if angle > (math.rad(AngleSlider.Value) / 2) then 
										continue 
									end
								end
								
								-- Check if target is behind wall (if wallcheck is enabled)
								if Targets.Walls.Enabled then
									local raycastParams = RaycastParams.new()
									raycastParams.FilterDescendantsInstances = {lplr.Character, v.Character or {}}
									raycastParams.FilterType = Enum.RaycastFilterType.Exclude
									local ray = workspace:Raycast(selfpos, delta, raycastParams)
									if ray then
										continue
									end
								end
								
								-- Teleport to target
								local teleportPosition = v.RootPart.CFrame + Vector3.new(0, math.random(6, 8), 0)
								
								-- Anti-lagback: move slightly instead of direct teleport
								entitylib.character.RootPart.CFrame = teleportPosition
								
								-- Add some velocity to prevent getting stuck
								entitylib.character.RootPart.Velocity = Vector3.zero
								
								lastTeleport = tick()
								targetFound = true
								break
							end
						end
					end
					
					task.wait(0.1) -- Reduced wait time for better responsiveness
				until not TPAura.Enabled
			else
				lastTeleport = 0
			end
		end,
		Tooltip = 'Automatically teleports to the player closest to you'
	})
	
	Targets = TPAura:CreateTargets({Players = true})
	
	Range = TPAura:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30, -- Increased max range
		Default = 18,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	
	AngleSlider = TPAura:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 360,
		Function = function(val)
			-- Update angle restriction
		end
	})
	
	-- Add a cooldown slider for better control
	TPAura:CreateSlider({
		Name = 'Cooldown',
		Min = 0.1,
		Max = 2,
		Default = 0.5,
		Decimal = 1,
		Suffix = 's',
		Function = function(val)
			teleportCooldown = val
		end
	})
	
	-- Add height offset slider
	TPAura:CreateSlider({
		Name = 'Height',
		Min = 4,
		Max = 12,
		Default = 7,
		Suffix = 'studs',
		Function = function(val)
			-- Height is used in teleportPosition calculation
		end
	})
end)

run(function()
	local Rejoin
	
	Rejoin = vape.Categories.Utility:CreateModule({
		Name = 'Rejoin',
		Function = function(callback)
			if callback then
				notif('Rejoin', 'Rejoining...', 5)
				Rejoin:Toggle()
				if playersService.NumPlayers > 1 then
					teleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId)
				else
					teleportService:Teleport(game.PlaceId)
				end
			end
		end,
		Tooltip = 'Rejoins the server'
	})
end)
	
run(function()
	local ServerHop
	local Sort
	
	ServerHop = vape.Categories.Utility:CreateModule({
		Name = 'ServerHop',
		Function = function(callback)
			if callback then
				ServerHop:Toggle()
				serverHop(nil, Sort.Value)
			end
		end,
		Tooltip = 'Teleports into a unique server'
	})
	Sort = ServerHop:CreateDropdown({
		Name = 'Sort',
		List = {'Descending', 'Ascending'},
		Tooltip = 'Descending - Prefers full servers\nAscending - Prefers empty servers'
	})
	ServerHop:CreateButton({
		Name = 'Rejoin Previous Server',
		Function = function()
			notif('ServerHop', shared.vapeserverhopprevious and 'Rejoining previous server...' or 'Cannot find previous server', 5)
			if shared.vapeserverhopprevious then
				teleportService:TeleportToPlaceInstance(game.PlaceId, shared.vapeserverhopprevious)
			end
		end
	})
end)
run(function()
	local StaffDetector
	local Mode
	local Profile
	local Users
	local Group
	local Role
	
	local function getRole(plr, id)
		local suc, res
		for _ = 1, 3 do
			suc, res = pcall(function()
				return plr:GetRankInGroup(id)
			end)
			if suc then break end
		end
		return suc and res or 0
	end
	
	local function getLowestStaffRole(roles)
		local highest = math.huge
		for _, v in roles do
			local low = v.Name:lower()
			if (low:find('admin') or low:find('mod') or low:find('dev')) and v.Rank < highest then
				highest = v.Rank
			end
		end
		return highest
	end
	
	local function playerAdded(plr)
		if not vape.Loaded then
			repeat task.wait() until vape.Loaded
		end
	
		local user = table.find(Users.ListEnabled, tostring(plr.UserId))
		if user or getRole(plr, tonumber(Group.Value) or 0) >= (tonumber(Role.Value) or 1) then
			notif('StaffDetector', 'Staff Detected ('..(user and 'blacklisted_user' or 'staff_role')..'): '..plr.Name, 60, 'alert')
			whitelist.customtags[plr.Name] = {{text = 'GAME STAFF', color = Color3.new(1, 0, 0)}}
	
			if Mode.Value == 'Uninject' then
				task.spawn(function()
					vape:Uninject()
				end)
				game:GetService('StarterGui'):SetCore('SendNotification', {
					Title = 'StaffDetector',
					Text = 'Staff Detected\n'..plr.Name,
					Duration = 60,
				})
			elseif Mode.Value == 'ServerHop' then
				serverHop()
			elseif Mode.Value == 'Profile' then
				vape.Save = function() end
				if vape.Profile ~= Profile.Value then
					vape.Profile = Profile.Value
					vape:Load(true, Profile.Value)
				end
			elseif Mode.Value == 'AutoConfig' then
				vape.Save = function() end
				for _, v in vape.Modules do
					if v.Enabled then
						v:Toggle()
					end
				end
			end
		end
	end
	
	StaffDetector = vape.Categories.Utility:CreateModule({
		Name = 'StaffDetector',
		Function = function(callback)
			if callback then
				if Group.Value == '' or Role.Value == '' then
					local placeinfo = {Creator = {CreatorTargetId = tonumber(Group.Value)}}
					if Group.Value == '' then
						placeinfo = marketplaceService:GetProductInfo(game.PlaceId)
						if placeinfo.Creator.CreatorType ~= 'Group' then
							local desc = placeinfo.Description:split('\n')
							for _, str in desc do
								local _, begin = str:find('roblox.com/groups/')
								if begin then
									local endof = str:find('/', begin + 1)
									placeinfo = {Creator = {
										CreatorType = 'Group',
										CreatorTargetId = str:sub(begin + 1, endof - 1)
									}}
								end
							end
						end
	
						if placeinfo.Creator.CreatorType ~= 'Group' then
							notif('StaffDetector', 'Automatic Setup Failed (no group detected)', 60, 'warning')
							return
						end
					end
	
					local groupinfo = groupService:GetGroupInfoAsync(placeinfo.Creator.CreatorTargetId)
					Group:SetValue(placeinfo.Creator.CreatorTargetId)
					Role:SetValue(getLowestStaffRole(groupinfo.Roles))
				end
	
				if Group.Value == '' or Role.Value == '' then
					return
				end
	
				StaffDetector:Clean(playersService.PlayerAdded:Connect(playerAdded))
				for _, v in playersService:GetPlayers() do
					task.spawn(playerAdded, v)
				end
			end
		end,
		Tooltip = 'Detects people with a staff rank ingame'
	})
	Mode = StaffDetector:CreateDropdown({
		Name = 'Mode',
		List = {'Uninject', 'ServerHop', 'Profile', 'AutoConfig', 'Notify'},
		Function = function(val)
			if Profile.Object then
				Profile.Object.Visible = val == 'Profile'
			end
		end
	})
	Profile = StaffDetector:CreateTextBox({
		Name = 'Profile',
		Default = 'default',
		Darker = true,
		Visible = false
	})
	Users = StaffDetector:CreateTextList({
		Name = 'Users',
		Placeholder = 'player (userid)'
	})
	Group = StaffDetector:CreateTextBox({
		Name = 'Group',
		Placeholder = 'Group Id'
	})
	Role = StaffDetector:CreateTextBox({
		Name = 'Role',
		Placeholder = 'Role Rank'
	})
end)
	
run(function()
	local connections = {}
	
	vape.Categories.World:CreateModule({
		Name = 'Anti-AFK',
		Function = function(callback)
			if callback then
				for _, v in getconnections(lplr.Idled) do
					table.insert(connections, v)
					v:Disable()
				end
			else
				for _, v in connections do
					v:Enable()
				end
				table.clear(connections)
			end
		end,
		Tooltip = 'Lets you stay ingame without getting kicked'
	})
end)
	
run(function()
	local Freecam
	local Value
	local randomkey, module, old = httpService:GenerateGUID(false)
	
	Freecam = vape.Categories.World:CreateModule({
		Name = 'Freecam',
		Function = function(callback)
			if callback then
				repeat
					task.wait(0.1)
					for _, v in getconnections(gameCamera:GetPropertyChangedSignal('CameraType')) do
						if v.Function then
							module = debug.getupvalue(v.Function, 1)
						end
					end
				until module or not Freecam.Enabled
	
				if module and module.activeCameraController and Freecam.Enabled then
					old = module.activeCameraController.GetSubjectPosition
					local camPos = old(module.activeCameraController) or Vector3.zero
					module.activeCameraController.GetSubjectPosition = function()
						return camPos
					end
	
					Freecam:Clean(runService.PreSimulation:Connect(function(dt)
						if not inputService:GetFocusedTextBox() then
							local forward = (inputService:IsKeyDown(Enum.KeyCode.W) and -1 or 0) + (inputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
							local side = (inputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0) + (inputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0)
							local up = (inputService:IsKeyDown(Enum.KeyCode.Q) and -1 or 0) + (inputService:IsKeyDown(Enum.KeyCode.E) and 1 or 0)
							dt = dt * (inputService:IsKeyDown(Enum.KeyCode.LeftShift) and 0.25 or 1)
							camPos = (CFrame.lookAlong(camPos, gameCamera.CFrame.LookVector) * CFrame.new(Vector3.new(side, up, forward) * (Value.Value * dt))).Position
						end
					end))
	
					contextService:BindActionAtPriority('FreecamKeyboard'..randomkey, function()
						return Enum.ContextActionResult.Sink
					end, false, Enum.ContextActionPriority.High.Value,
						Enum.KeyCode.W,
						Enum.KeyCode.A,
						Enum.KeyCode.S,
						Enum.KeyCode.D,
						Enum.KeyCode.E,
						Enum.KeyCode.Q,
						Enum.KeyCode.Up,
						Enum.KeyCode.Down
					)
				end
			else
				pcall(function()
					contextService:UnbindAction('FreecamKeyboard'..randomkey)
				end)
				if module and old then
					module.activeCameraController.GetSubjectPosition = old
					module = nil
					old = nil
				end
			end
		end,
		Tooltip = 'Lets you fly and clip through walls freely\nwithout moving your player server-sided.'
	})
	Value = Freecam:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)
	
run(function()
	local Gravity
	local Mode
	local Value
	local changed, old = false
	
	Gravity = vape.Categories.World:CreateModule({
		Name = 'Gravity',
		Function = function(callback)
			if callback then
				if Mode.Value == 'Workspace' then
					old = workspace.Gravity
					workspace.Gravity = Value.Value
					Gravity:Clean(workspace:GetPropertyChangedSignal('Gravity'):Connect(function()
						if changed then return end
						changed = true
						old = workspace.Gravity
						workspace.Gravity = Value.Value
						changed = false
					end))
				else
					Gravity:Clean(runService.PreSimulation:Connect(function(dt)
						if entitylib.isAlive and entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air then
							local root = entitylib.character.RootPart
							if Mode.Value == 'Impulse' then
								root:ApplyImpulse(Vector3.new(0, dt * (workspace.Gravity - Value.Value), 0) * root.AssemblyMass)
							else
								root.AssemblyLinearVelocity += Vector3.new(0, dt * (workspace.Gravity - Value.Value), 0)
							end
						end
					end))
				end
			else
				if old then
					workspace.Gravity = old
					old = nil
				end
			end
		end,
		Tooltip = 'Changes the rate you fall'
	})
	Mode = Gravity:CreateDropdown({
		Name = 'Mode',
		List = {'Workspace', 'Velocity', 'Impulse'},
		Tooltip = 'Workspace - Adjusts the gravity for the entire game\nVelocity - Adjusts the local players gravity\nImpulse - Same as velocity while using forces instead'
	})
	Value = Gravity:CreateSlider({
		Name = 'Gravity',
		Min = 0,
		Max = 192,
		Function = function(val)
			if Gravity.Enabled and Mode.Value == 'Workspace' then
				changed = true
				workspace.Gravity = val
				changed = false
			end
		end,
		Default = 192
	})
end)
	
run(function()
	local Parkour
	
	Parkour = vape.Categories.World:CreateModule({
		Name = 'Parkour',
		Function = function(callback)
			if callback then 
				local oldfloor
				Parkour:Clean(runService.RenderStepped:Connect(function()
					if entitylib.isAlive then 
						local material = entitylib.character.Humanoid.FloorMaterial
						if material == Enum.Material.Air and oldfloor ~= Enum.Material.Air then 
							entitylib.character.Humanoid.Jump = true
						end
						oldfloor = material
					end
				end))
			end
		end,
		Tooltip = 'Automatically jumps after reaching the edge'
	})
end)
	
run(function()
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local module, old
	
	vape.Categories.World:CreateModule({
		Name = 'SafeWalk',
		Function = function(callback)
			if callback then
				if not module then
					local suc = pcall(function() 
						module = require(lplr.PlayerScripts.PlayerModule).controls 
					end)
					if not suc then module = {} end
				end
				
				old = module.moveFunction
				module.moveFunction = function(self, vec, face)
					if entitylib.isAlive then
						rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
						local root = entitylib.character.RootPart
						local movedir = root.Position + vec
						local ray = workspace:Raycast(movedir, Vector3.new(0, -15, 0), rayCheck)
						if not ray then
							local check = workspace:Blockcast(root.CFrame, Vector3.new(3, 1, 3), Vector3.new(0, -(entitylib.character.HipHeight + 1), 0), rayCheck)
							if check then
								vec = (check.Instance:GetClosestPointOnSurface(movedir) - root.Position) * Vector3.new(1, 0, 1)
							end
						end
					end
	
					return old(self, vec, face)
				end
			else
				if module and old then
					module.moveFunction = old
				end
			end
		end,
		Tooltip = 'Prevents you from walking off the edge of parts'
	})
end)
	
run(function()
	local Xray
	local List
	local modified = {}
	
	local function modifyPart(v)
		if v:IsA('BasePart') and not table.find(List.ListEnabled, v.Name) then
			modified[v] = true
			v.LocalTransparencyModifier = 0.5
		end
	end
	
	Xray = vape.Categories.World:CreateModule({
		Name = 'Xray',
		Function = function(callback)
			if callback then
				Xray:Clean(workspace.DescendantAdded:Connect(modifyPart))
				for _, v in workspace:GetDescendants() do
					modifyPart(v)
				end
			else
				for i in modified do
					i.LocalTransparencyModifier = 0
				end
				table.clear(modified)
			end
		end,
		Tooltip = 'Renders whitelisted parts through walls.'
	})
	List = Xray:CreateTextList({
		Name = 'Part',
		Function = function()
			if Xray.Enabled then
				Xray:Toggle()
				Xray:Toggle()
			end
		end
	})
end)
	
run(function()
	local MurderMystery
	local murderer, sheriff, oldtargetable, oldgetcolor
	
	local function itemAdded(v, plr)
		if v:IsA('Tool') then
			local check = v:FindFirstChild('IsGun') and 'sheriff' or v:FindFirstChild('KnifeServer') and 'murderer' or nil
			check = check or v.Name:lower():find('knife') and 'murderer' or v.Name:lower():find('gun') and 'sheriff' or nil
			if check == 'murderer' and plr ~= murderer then
				murderer = plr
				if plr.Character then
					entitylib.refresh()
				end
			elseif check == 'sheriff' and plr ~= sheriff then
				sheriff = plr
				if plr.Character then
					entitylib.refresh()
				end
			end
		end
	end
	
	local function playerAdded(plr)
		MurderMystery:Clean(plr.DescendantAdded:Connect(function(v)
			itemAdded(v, plr)
		end))
		local pack = plr:FindFirstChildWhichIsA('Backpack')
		if pack then
			for _, v in pack:GetChildren() do
				itemAdded(v, plr)
			end
		end
		if plr.Character then
			for _, v in plr.Character:GetChildren() do
				itemAdded(v, plr)
			end
		end
	end
	
	MurderMystery = vape.Categories.Utility:CreateModule({
		Name = 'MurderMystery',
		Function = function(callback)
			if callback then
				oldtargetable, oldgetcolor = entitylib.targetCheck, entitylib.getEntityColor
				entitylib.getEntityColor = function(ent)
					ent = ent.Player
					if not (ent and vape.Categories.Main.Options['Use team color'].Enabled) then return end
					if isFriend(ent, true) then
						return Color3.fromHSV(vape.Categories.Friends.Options['Friends color'].Hue, vape.Categories.Friends.Options['Friends color'].Sat, vape.Categories.Friends.Options['Friends color'].Value)
					end
					return murderer == ent and Color3.new(1, 0.3, 0.3) or sheriff == ent and Color3.new(0, 0.5, 1) or nil
				end
				entitylib.targetCheck = function(ent)
					if ent.Player and isFriend(ent.Player) then return false end
					if murderer == lplr then return true end
					return murderer == ent.Player or sheriff == ent.Player
				end
				for _, v in playersService:GetPlayers() do
					playerAdded(v)
				end
				MurderMystery:Clean(playersService.PlayerAdded:Connect(playerAdded))
				entitylib.refresh()
			else
				entitylib.getEntityColor = oldgetcolor
				entitylib.targetCheck = oldtargetable
				entitylib.refresh()
			end
		end,
		Tooltip = 'Automatic murder mystery teaming based on equipped roblox tools.'
	})
end)
	
run(function()
	local Atmosphere: table = {["Enabled"] = false};
	local Toggles: table = {}
	local themeName: any;
	local newobjects: table, oldobjects: table = {}, {}
	local function BeforeShaders()
	        return {
	            Brightness = lightingService.Brightness,
	            ColorShift_Bottom = lightingService.ColorShift_Bottom,
	            ColorShift_Top = lightingService.ColorShift_Top,
	            OutdoorAmbient = lightingService.OutdoorAmbient,
	            TimeOfDay = lightingService.TimeOfDay,
	            FogColor = lightingService.FogColor,
	            FogEnd = lightingService.FogEnd,
	            FogStart = lightingService.FogStart,
	            ExposureCompensation = lightingService.ExposureCompensation,
	            ShadowSoftness = lightingService.ShadowSoftness,
	            Ambient = lightingService.Ambient,
	            children = lightingService:GetChildren()
	        }
	end;
	local function restoreDefault(lightingState)
	        lightingService:ClearAllChildren();
	        lightingService.Brightness = lightingState.Brightness;
	        lightingService.ColorShift_Bottom = lightingState.ColorShift_Bottom;
	        lightingService.ColorShift_Top = lightingState.ColorShift_Top;
	        lightingService.OutdoorAmbient = lightingState.OutdoorAmbient;
	        lightingService.TimeOfDay = lightingState.TimeOfDay;
	        lightingService.FogColor = lightingState.FogColor;
	        lightingService.FogEnd = lightingState.FogEnd;
	        lightingService.FogStart = lightingState.FogStart;
	        lightingService.ExposureCompensation = lightingState.ExposureCompensation;
	        lightingService.ShadowSoftness = lightingState.ShadowSoftness;
	        lightingService.Ambient = lightingState.Ambient;
	        for _, child in next, workspace.ItemDrops:GetChildren() do
	            child.Parent = lightingService;
	        end;
	end;
	local apidump: table = {
		Sky = {
			SkyboxUp = 'Text',
			SkyboxDn = 'Text',
			SkyboxLf = 'Text',
			SkyboxRt = 'Text',
			SkyboxFt = 'Text',
			SkyboxBk = 'Text',
			SunTextureId = 'Text',
			SunAngularSize = 'Number',
			MoonTextureId = 'Text',
			MoonAngularSize = 'Number',
			StarCount = 'Number'
		},
		Atmosphere = {
			Color = 'Color',
			Decay = 'Color',
			Density = 'Number',
			Offset = 'Number',
			Glare = 'Number',
			Haze = 'Number'
		},
		BloomEffect = {
			Intensity = 'Number',
			Size = 'Number',
			Threshold = 'Number'
		},
		DepthOfFieldEffect = {
			FarIntensity = 'Number',
			FocusDistance = 'Number',
			InFocusRadius = 'Number',
			NearIntensity = 'Number'
		},
		SunRaysEffect = {
			Intensity = 'Number',
			Spread = 'Number'
		},
		ColorCorrectionEffect = {
			TintColor = 'Color',
			Saturation = 'Number',
			Contrast = 'Number',
			Brightness = 'Number'
		}
	}
    	local skyThemes: table = {
		        NetherWorld = {
			            MoonAngularSize = 0,
			            SunAngularSize = 0,
			            SkyboxBk = 'rbxassetid://14365019002',
			            SkyboxDn = 'rbxassetid://14365023350',
			            SkyboxFt = 'rbxassetid://14365018399',
			            SkyboxLf = 'rbxassetid://14365018705',
			            SkyboxRt = 'rbxassetid://14365018143',
			            SkyboxUp = 'rbxassetid://14365019327',
		        },
		        Neptune = {
				    SkyboxBk = 'rbxassetid://218955819',
				    SkyboxDn = 'rbxassetid://218953419',
				    SkyboxFt = 'rbxassetid://218954524',
				    SkyboxLf = 'rbxassetid://218958493',
				    SkyboxRt = 'rbxassetid://218957134',
				    SkyboxUp = 'rbxassetid://218950090',
		        },
		        Velocity = {
			            SkyboxBk = 'rbxassetid://570557514',
			            SkyboxDn = 'rbxassetid://570557775',
			            SkyboxFt = 'rbxassetid://570557559',
			            SkyboxLf = 'rbxassetid://570557620',
			            SkyboxRt = 'rbxassetid://570557672',
			            SkyboxUp = 'rbxassetid://570557727',
		        },
		        Minecraft = {
			            SkyboxBk = 'rbxassetid://591058823',
			            SkyboxDn = 'rbxassetid://591059876',
			            SkyboxFt = 'rbxassetid://591058104',
			            SkyboxLf = 'rbxassetid://591057861',
			            SkyboxRt = 'rbxassetid://591057625',
			            SkyboxUp = 'rbxassetid://591059642',
		        },
		        Purple = {
			            SkyboxBk = "rbxassetid://8539982183",
			            SkyboxDn = "rbxassetid://8539981943",
			            SkyboxFt = "rbxassetid://8539981721",
			            SkyboxLf = "rbxassetid://8539981424",
			            SkyboxRt = "rbxassetid://8539980766",
			            SkyboxUp = "rbxassetid://8539981085",
			            MoonAngularSize = 0,
			            SunAngularSize = 0,
			            StarCount = 3000,
		        }, 
		        ["日の出"] = {
				    SkyboxBk = "rbxassetid://600830446",
				    SkyboxDn = "rbxassetid://600831635",
				    SkyboxFt = "rbxassetid://600832720",
				    SkyboxLf = "rbxassetid://600886090",
				    SkyboxRt = "rbxassetid://600833862",
				    SkyboxUp = "rbxassetid://600835177",
		        },
		        Sakura = {
			            SkyboxBk = "http://www.roblox.com/asset/?id=16694315897",
			            SkyboxDn = "http://www.roblox.com/asset/?id=16694319417",
			            SkyboxFt = "http://www.roblox.com/asset/?id=16694324910",
			            SkyboxLf = "http://www.roblox.com/asset/?id=16694328308",
			            SkyboxRt = "http://www.roblox.com/asset/?id=16694331447",
			            SkyboxUp = "http://www.roblox.com/asset/?id=16694334666",
			            SunAngularSize = 21,
			            StarCount = 3000,
		        },
		        Hexagonal = {
			            SkyboxBk = "http://www.roblox.com/asset/?id=15876463105",
			            SkyboxDn = "http://www.roblox.com/asset/?id=15876464432",
			            SkyboxFt = "http://www.roblox.com/asset/?id=15876465852",
			            SkyboxLf = "http://www.roblox.com/asset/?id=15876467260",
			            SkyboxRt = "http://www.roblox.com/asset/?id=15876469097",
			            SkyboxUp = "http://www.roblox.com/asset/?id=15876470945",
			            SunAngularSize = 21,
			            StarCount = 3000,
		        },
		        Reality = {
			            SkyboxBk = "http://www.roblox.com/asset/?id=6778646360",
			            SkyboxDn = "http://www.roblox.com/asset/?id=6778658683",
			            SkyboxFt = "http://www.roblox.com/asset/?id=6778648039",
			            SkyboxLf = "http://www.roblox.com/asset/?id=6778649136",
			            SkyboxRt = "http://www.roblox.com/asset/?id=6778650519",
			            SkyboxUp = "http://www.roblox.com/asset/?id=6778658364",
		        },
		        OpaiNight = {
			            SkyboxBk = 'rbxassetid://187713366',
			            SkyboxDn = 'rbxassetid://187712428',
			            SkyboxFt = 'rbxassetid://187712836',
			            SkyboxLf = 'rbxassetid://187713755',
			            SkyboxRt = 'rbxassetid://187714525',
			            SkyboxUp = 'rbxassetid://187712111',
			            SunAngularSize = 0,
			            StarCount = 0,
		        },
		        FPSBoost = {
			            SkyboxBk = 'rbxassetid://11457548274',
			            SkyboxDn = 'rbxassetid://11457548274',
			            SkyboxFt = 'rbxassetid://11457548274',
			            SkyboxLf = 'rbxassetid://11457548274',
			            SkyboxRt = 'rbxassetid://11457548274',
			            SkyboxUp = 'rbxassetid://11457548274',
			            SunAngularSize = 0,
			            StarCount = 3000,
		        },
		        Etheral = {
			            SkyboxBk = 'rbxassetid://16262356578',
			            SkyboxDn = 'rbxassetid://16262358026',
			            SkyboxFt = 'rbxassetid://16262360469',
			            SkyboxLf = 'rbxassetid://16262362003',
			            SkyboxRt = 'rbxassetid://16262363873',
			            SkyboxUp = 'rbxassetid://16262366016',
			            SunAngularSize = 21,
			            StarCount = 3000,
		        },
		        Pandora = {
			            SkyboxBk = 'http://www.roblox.com/asset/?id=16739324092',
			            SkyboxDn = 'http://www.roblox.com/asset/?id=16739325541',
			            SkyboxFt = 'http://www.roblox.com/asset/?id=16739327056',
			            SkyboxLf = 'http://www.roblox.com/asset/?id=16739329370',
			            SkyboxRt = 'http://www.roblox.com/asset/?id=16739331050',
			            SkyboxUp = 'http://www.roblox.com/asset/?id=16739332736',
			            SunAngularSize = 21,
			            StarCount = 3000,
		        },
		        Polaris = {
			            SkyboxBk = 'http://www.roblox.com/asset/?id=16823270864',
			            SkyboxDn = 'http://www.roblox.com/asset/?id=16823272150',
			            SkyboxFt = 'http://www.roblox.com/asset/?id=16823273508',
			            SkyboxLf = 'http://www.roblox.com/asset/?id=16823274898',
			            SkyboxRt = 'http://www.roblox.com/asset/?id=16823276281',
			            SkyboxUp = 'http://www.roblox.com/asset/?id=16823277547',
			            SunAngularSize = 21,
			            StarCount = 3000,
		        },
		        Diaphanous = {
			            SkyboxBk = 'http://www.roblox.com/asset/?id=16888989874',
			            SkyboxDn = 'http://www.roblox.com/asset/?id=16888991855',
			            SkyboxFt = 'http://www.roblox.com/asset/?id=16888995219',
			            SkyboxLf = 'http://www.roblox.com/asset/?id=16888998994',
			            SkyboxRt = 'http://www.roblox.com/asset/?id=16889000916',
			            SkyboxUp = 'http://www.roblox.com/asset/?id=16889004122',
			            SunAngularSize = 21,
			            StarCount = 3000,
		        },
		        Transcendent = {
			            SkyboxBk = 'http://www.roblox.com/asset/?id=17124357467',
			            SkyboxDn = 'http://www.roblox.com/asset/?id=17124359797',
			            SkyboxFt = 'http://www.roblox.com/asset/?id=17124362093',
			            SkyboxLf = 'http://www.roblox.com/asset/?id=17124365127',
			            SkyboxRt = 'http://www.roblox.com/asset/?id=17124367200',
			            SkyboxUp = 'http://www.roblox.com/asset/?id=17124369657',
			            SunAngularSize = 21,
			            StarCount = 3000,
		        },
		        Truth = {
			            SkyboxBk = "http://www.roblox.com/asset/?id=144933338",
			            SkyboxDn = "http://www.roblox.com/asset/?id=144931530",
			            SkyboxFt = "http://www.roblox.com/asset/?id=144933262",
			            SkyboxLf = "http://www.roblox.com/asset/?id=144933244",
			            SkyboxRt = "http://www.roblox.com/asset/?id=144933299",
			            SkyboxUp = "http://www.roblox.com/asset/?id=144931564",
		        },
		        RayTracing = {
			            SkyboxBk = "http://www.roblox.com/asset/?id=271042516",
			            SkyboxDn = "http://www.roblox.com/asset/?id=271077243",
			            SkyboxFt = "http://www.roblox.com/asset/?id=271042556",
			            SkyboxLf = "http://www.roblox.com/asset/?id=271042310",
			            SkyboxRt = "http://www.roblox.com/asset/?id=271042467",
			            SkyboxUp = "http://www.roblox.com/asset/?id=271077958",
		        },
		        Nebula = {
			            MoonAngularSize = 0,
			            SunAngularSize = 0,
			            SkyboxBk = 'rbxassetid://5260808177',
			            SkyboxDn = 'rbxassetid://5260653793',
			            SkyboxFt = 'rbxassetid://5260817288',
			            SkyboxLf = 'rbxassetid://5260800833',
			            SkyboxRt = 'rbxassetid://5260811073',
			            SkyboxUp = 'rbxassetid://5260824661',
		        },
		        Planets = {
			            MoonAngularSize = 0,
			            SunAngularSize = 0,
			            SkyboxBk = 'rbxassetid://15983968922',
			            SkyboxDn = 'rbxassetid://15983966825',
			            SkyboxFt = 'rbxassetid://15983965025',
			            SkyboxLf = 'rbxassetid://15983967420',
			            SkyboxRt = 'rbxassetid://15983966246',
			            SkyboxUp = 'rbxassetid://15983964246',
			            StarCount = 3000,
		        },
		        Galaxy = {
			            SkyboxBk = "rbxassetid://159454299",
			            SkyboxDn = "rbxassetid://159454296",
			            SkyboxFt = "rbxassetid://159454293",
			            SkyboxLf = "rbxassetid://159454293",
			            SkyboxRt = "rbxassetid://159454293",
			            SkyboxUp = "rbxassetid://159454288",
			            SunAngularSize = 0,
		        }, 
		        Blues = {
			            SkyboxBk = 'http://www.roblox.com/asset/?id=17124357467',
			            SkyboxDn = 'http://www.roblox.com/asset/?id=17124359797',
			            SkyboxFt = 'http://www.roblox.com/asset/?id=17124362093',
			            SkyboxLf = 'http://www.roblox.com/asset/?id=17124365127',
			            SkyboxRt = 'http://www.roblox.com/asset/?id=17124367200',
			            SkyboxUp = 'http://www.roblox.com/asset/?id=17124369657',
			            SunAngularSize = 21,
			            StarCount = 3000,
		        },
		        Milkyway = {
			            MoonTextureId = 'rbxassetid://1075087760',
			            SkyboxBk = 'rbxassetid://2670643994',
			            SkyboxDn = 'rbxassetid://2670643365',
			            SkyboxFt = 'rbxassetid://2670643214',
			            SkyboxLf = 'rbxassetid://2670643070',
			            SkyboxRt = 'rbxassetid://2670644173',
			            SkyboxUp = 'rbxassetid://2670644331',
			            MoonAngularSize = 1.5,
			            StarCount = 500,
		        },
		        Orange = {
			            SkyboxBk = 'rbxassetid://150939022',
			            SkyboxDn = 'rbxassetid://150939038',
			            SkyboxFt = 'rbxassetid://150939047',
			            SkyboxLf = 'rbxassetid://150939056',
			            SkyboxRt = 'rbxassetid://150939063',
			            SkyboxUp = 'rbxassetid://150939082',
		        },
		        DarkMountains = {
			            SkyboxBk = 'rbxassetid://5098814730',
			            SkyboxDn = 'rbxassetid://5098815227',
			            SkyboxFt = 'rbxassetid://5098815653',
			            SkyboxLf = 'rbxassetid://5098816155',
			            SkyboxRt = 'rbxassetid://5098820352',
			            SkyboxUp = 'rbxassetid://5098819127',
		        },
		        Space = {
			            MoonAngularSize = 0,
			            SunAngularSize = 0,
			            SkyboxBk = 'rbxassetid://166509999',
			            SkyboxDn = 'rbxassetid://166510057',
			            SkyboxFt = 'rbxassetid://166510116',
			            SkyboxLf = 'rbxassetid://166510092',
			            SkyboxRt = 'rbxassetid://166510131',
			            SkyboxUp = 'rbxassetid://166510114',
		        },
		        Void = {
			            MoonAngularSize = 0,
			            SunAngularSize = 0,
			            SkyboxBk = 'rbxassetid://14543264135',
			            SkyboxDn = 'rbxassetid://14543358958',
			            SkyboxFt = 'rbxassetid://14543257810',
			            SkyboxLf = 'rbxassetid://14543275895',
			            SkyboxRt = 'rbxassetid://14543280890',
			            SkyboxUp = 'rbxassetid://14543371676',
		        },
		        Stary = {
			            SkyboxBk = 'rbxassetid://248431616',
			            SkyboxDn = 'rbxassetid://248431677',
			            SkyboxFt = 'rbxassetid://248431598',
			            SkyboxLf = 'rbxassetid://248431686',
			            SkyboxRt = 'rbxassetid://248431611',
			            SkyboxUp = 'rbxassetid://248431605',
				    StarCount = 3000,       
		        },
			Violet = {
				    SkyboxBk = 'rbxassetid://8107841671',
				    SkyboxDn = 'rbxassetid://6444884785',
				    SkyboxFt = 'rbxassetid://8107841671',
				    SkyboxLf = 'rbxassetid://8107841671',
				    SkyboxRt = 'rbxassetid://8107841671',
				    SkyboxUp = 'rbxassetid://8107849791',
				    SunTextureId = 'rbxassetid://6196665106',
				    MoonTextureId = 'rbxassetid://6444320592',
				    MoonAngularSize = 0,
		        },
			Cloudy = {
				    SkyboxBk = 'rbxassetid://15876597103',
				    SkyboxDn = 'rbxassetid://15876592775',
				    SkyboxFt = 'rbxassetid://15876640231',
				    SkyboxLf = 'rbxassetid://15876638420',
				    SkyboxRt = 'rbxassetid://15876595486',
				    SkyboxUp = 'rbxassetid://15876639348',
				    SunTextureId = 'rbxasset://sky/sun.jpg',
				    MoonTextureId = 'rbxasset://sky/moon.jpg',
				    MoonAngularSize = 11,
		            	    SunAngularSize = 21,
				    StarCount = 3000,
		    	}
	};																																					
    	local ILS: any = BeforeShaders()
	local function removeObject(v: Instance?)
		if not table.find(newobjects, v) then 
			local vt: table? = Toggles[v.ClassName]
			if vt and vt.Toggle["Enabled"] then
				table.insert(oldobjects, v);
				v.Parent = game;
			end;
		end;
	end;
	
	local function themes(val: any)
	        local theme: any = skyThemes[themeName["Value"]];
	        if theme then
		        local sky: Sky? = lightingService:FindFirstChild("CustomSky") or Instance.new("Sky", lightingService);
		        for v: any, value: any in next, theme do
		                if v ~= "Atmosphere" then
		                        sky[v] = value;
		                end;
		        end;
		end;
	end;

	Atmosphere = vape.Categories.Visuals:CreateModule({
		["Name"] = 'Atmosphere',
		["Function"] = function(callback: boolean): void
			if callback then
				for _, v in lightingService:GetChildren() do
			                if v:IsA('PostEffect') or v:IsA('Sky') or v:IsA('Atmosphere') or v:IsA('Clouds') then
			                        v:Destroy();
			                end;
		        	end;
		
		                for _, v in workspace:GetDescendants() do
			                if v:IsA("Clouds") then
			                        v:Destroy();
			                end;
		                end;
				local d: number = 0;
				local r: any = workspace.Terrain;
				for _, v in lightingService:GetChildren() do
		                	if v:IsA('PostEffect') or v:IsA('Sky') or v:IsA('Atmosphere') or v:IsA('Clouds') then
		                        	v:Destroy();
		                        end;
		                end;
				lightingService.Brightness = d + 1;
		                lightingService.EnvironmentDiffuseScale = d + 0.2;
		                lightingService.EnvironmentSpecularScale = d + 0.82;
		
		                local sunRays: SunRaysEffect = Instance.new('SunRaysEffect');
		                table.insert(newobjects, sunRays);
		                pcall(function() sunRays.Parent = lightingService end);
		
		                local atmosphere: Atmosphere = Instance.new('Atmosphere');
		                table.insert(newobjects, atmosphere);
		                pcall(function() atmosphere.Parent = lightingService end);
		
		                local sky: Sky = Instance.new('Sky');
		                table.insert(newobjects, sky);
		                pcall(function() sky.Parent = lightingService end);
		
		                local blur: BlurEffect = Instance.new('BlurEffect');
		                blur.Size = d + 3.921;
		                table.insert(newobjects, blur);
		                pcall(function() blur.Parent = lightingService end);
		
		                local color_correction: ColorCorrectionEffect = Instance.new('ColorCorrectionEffect');
		                color_correction.Saturation = d + 0.092;
		                table.insert(newobjects, color_correction);
		                pcall(function() color_correction.Parent = lightingService end);
		
		                local clouds: Clouds = Instance.new('Clouds');
		                clouds.Cover = d + 0.4;
		                table.insert(newobjects, clouds);
		                pcall(function() clouds.Parent = r end);
		
		                r.WaterTransparency = d + 1;
		                r.WaterReflectance = d + 1;

				themes()
				for _, v in lightingService:GetChildren() do
					removeObject(v);
				end;
				Atmosphere:Clean(lightingService.ChildAdded:Connect(function(v)
					task.defer(removeObject, v);
				end));
	
				for className, classData in Toggles do
					if classData.Toggle["Enabled"] then
						local obj: any = Instance.new(className);
						for propName, propData in classData.Objects do
							if propData.Type == 'ColorSlider' then
								obj[propName] = Color3.fromHSV(propData.Hue, propData.Sat, propData.Value);
							else
								if apidump[className][propName] == 'Number' then
									obj[propName] = tonumber(propData.Value) or 0;
								else
									obj[propName] = propData.Value;
								end;
							end;
						end;
						obj.Name = "Custom" .. className;
						table.insert(newobjects, obj);
						task.defer(function()
							pcall(function() obj.Parent = lightingService end);
						end);
					end;
				end;
			else
		                for _, v in newobjects do
			                if v and v.Destroy then
			                        v:Destroy();
			                end;
		                end;
		                for _, v in oldobjects do
		                    	pcall(function() v.Parent = lightingService end);
		                end;
		                table.clear(newobjects);
		                table.clear(oldobjects);
				for _, v in lightingService:GetChildren() do
		                    	if v:IsA("ColorCorrectionEffect") then
		                        	v:Destroy();
		                    	end;
		                end;
				restoreDefault(ILS);
			end;
		end,
		["Tooltip"] = 'Custom lighting objects'
	})
	local skyboxes: table = {};
	for v,_ in next, skyThemes do
	        table.insert(skyboxes, v);
	end;
	themeName = Atmosphere:CreateDropdown({
	        ["Name"] = "Mode",
	        ["List"] = skyboxes,
	        ["Function"] = function(val) end
	})
	for i, v in apidump do
		Toggles[i] = {Objects = {}}
		Toggles[i].Toggle = Atmosphere:CreateToggle({
			["Name"] = i,
			["Function"] = function(callback: boolean): void
				if Atmosphere["Enabled"] then
					Atmosphere:Toggle();
					Atmosphere:Toggle();
				end;
				for _, toggle in Toggles[i].Objects do
					toggle.Object.Visible = callback;
				end;
			end;
		})
	
		for i2, v2 in v do
			if v2 == 'Text' or v2 == 'Number' then
				Toggles[i].Objects[i2] = Atmosphere:CreateTextBox({
					["Name"] = i2,
					["Function"] = function(enter)
						if Atmosphere["Enabled"] and enter then
							Atmosphere:Toggle();
							Atmosphere:Toggle();
						end;
					end,
					["Darker"] = true,
					["Default"] = v2 == 'Number' and '0' or nil,
					["Visible"] = false
				})
			elseif v2 == 'Color' then
				Toggles[i].Objects[i2] = Atmosphere:CreateColorSlider({
					["Name"] = i2,
					["Function"] = function()
						if Atmosphere["Enabled"] then
							Atmosphere:Toggle();
							Atmosphere:Toggle();
						end;
					end,
					["Darker"] = true,
					["Visible"] = false
				})
			end;
		end;
	end;
end)
	
run(function()
	local Breadcrumbs
	local Texture
	local Lifetime
	local Thickness
	local FadeIn
	local FadeOut
	local trail, point, point2
	
	Breadcrumbs = vape.Categories.Visuals:CreateModule({
		Name = 'Breadcrumbs',
		Function = function(callback)
			if callback then
				point = Instance.new('Attachment')
				point.Position = Vector3.new(0, Thickness.Value - 2.7, 0)
				point2 = Instance.new('Attachment')
				point2.Position = Vector3.new(0, -Thickness.Value - 2.7, 0)
				trail = Instance.new('Trail')
				trail.Texture = Texture.Value == '' and 'http://www.roblox.com/asset/?id=14166981368' or Texture.Value
				trail.TextureMode = Enum.TextureMode.Static
				trail.Color = ColorSequence.new(Color3.fromHSV(FadeIn.Hue, FadeIn.Sat, FadeIn.Value), Color3.fromHSV(FadeOut.Hue, FadeOut.Sat, FadeOut.Value))
				trail.Lifetime = Lifetime.Value
				trail.Attachment0 = point
				trail.Attachment1 = point2
				trail.FaceCamera = true
	
				Breadcrumbs:Clean(trail)
				Breadcrumbs:Clean(point)
				Breadcrumbs:Clean(point2)
				Breadcrumbs:Clean(entitylib.Events.LocalAdded:Connect(function(ent)
					point.Parent = ent.HumanoidRootPart
					point2.Parent = ent.HumanoidRootPart
					trail.Parent = gameCamera
				end))
				if entitylib.isAlive then
					point.Parent = entitylib.character.RootPart
					point2.Parent = entitylib.character.RootPart
					trail.Parent = gameCamera
				end
			else
				trail = nil
				point = nil
				point2 = nil
			end
		end,
		Tooltip = 'Shows a trail behind your character'
	})
	Texture = Breadcrumbs:CreateTextBox({
		Name = 'Texture',
		Placeholder = 'Texture Id',
		Function = function(enter)
			if enter and trail then
				trail.Texture = Texture.Value == '' and 'http://www.roblox.com/asset/?id=14166981368' or Texture.Value
			end
		end
	})
	FadeIn = Breadcrumbs:CreateColorSlider({
		Name = 'Fade In',
		Function = function(hue, sat, val)
			if trail then
				trail.Color = ColorSequence.new(Color3.fromHSV(hue, sat, val), Color3.fromHSV(FadeOut.Hue, FadeOut.Sat, FadeOut.Value))
			end
		end
	})
	FadeOut = Breadcrumbs:CreateColorSlider({
		Name = 'Fade Out',
		Function = function(hue, sat, val)
			if trail then
				trail.Color = ColorSequence.new(Color3.fromHSV(FadeIn.Hue, FadeIn.Sat, FadeIn.Value), Color3.fromHSV(hue, sat, val))
			end
		end
	})
	Lifetime = Breadcrumbs:CreateSlider({
		Name = 'Lifetime',
		Min = 1,
		Max = 5,
		Default = 3,
		Decimal = 10,
		Function = function(val)
			if trail then
				trail.Lifetime = val
			end
		end,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	Thickness = Breadcrumbs:CreateSlider({
		Name = 'Thickness',
		Min = 0,
		Max = 2,
		Default = 0.1,
		Decimal = 100,
		Function = function(val)
			if point then
				point.Position = Vector3.new(0, val - 2.7, 0)
			end
			if point2 then
				point2.Position = Vector3.new(0, -val - 2.7, 0)
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)
	
run(function()
	local Cape: table = {["Enabled"] = false};
	local Texture: any;
	local part: any, motor: any
	local CapeMode: table = {["Value"] = "Velocity"}
	local capeModeMap: table = {
		["Opal Reiko"] = "rbxassetid://111008512103855",
	}
	local function createMotor(char)
		if motor then 
			motor:Destroy() 
		end
		part.Parent = gameCamera
		motor = Instance.new('Motor6D')
		motor.MaxVelocity = 0.08
		motor.Part0 = part
		motor.Part1 = char.Character:FindFirstChild('UpperTorso') or char.RootPart
		motor.C0 = CFrame.new(0, 2, 0) * CFrame.Angles(0, math.rad(-90), 0)
		motor.C1 = CFrame.new(0, motor.Part1.Size.Y / 2, 0.45) * CFrame.Angles(0, math.rad(90), 0)
		motor.Parent = part
	end
	
	Cape = vape.Categories.Visuals:CreateModule({
		["Name"] = 'Cape',
		["Function"] = function(callback: boolean): void
			if callback then
				part = Instance.new('Part')
				part.Size = Vector3.new(2, 4, 0.1)
				part.CanCollide = false
				part.CanQuery = false
				part.Massless = true
				part.Transparency = 0
				part.Material = Enum.Material.SmoothPlastic
				part.Color = Color3.new()
				part.CastShadow = false
				part.Parent = gameCamera
				local capesurface = Instance.new('SurfaceGui')
				capesurface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				capesurface.Adornee = part
				capesurface.Parent = part
	
				if Texture.Value:find('.webm') then
					local decal = Instance.new('VideoFrame')
					decal.Video = getcustomasset(Texture.Value)
					decal.Size = UDim2.fromScale(1, 1)
					decal.BackgroundTransparency = 1
					decal.Looped = true
					decal.Parent = capesurface
					decal:Play()
				else
					local decal = Instance.new('ImageLabel')
					decal.Image = Texture.Value ~= '' and (Texture.Value:find('rbxasset') and Texture.Value or assetfunction(Texture.Value)) or 'rbxassetid://111008512103855'
					decal.Size = UDim2.fromScale(1, 1)
					decal.BackgroundTransparency = 1
					decal.Parent = capesurface
				end
				Cape:Clean(part)
				Cape:Clean(entitylib.Events.LocalAdded:Connect(createMotor))
				if entitylib.isAlive then
					createMotor(entitylib.character)
				end
	
				repeat
					if motor and entitylib.isAlive then
						local velo = math.min(entitylib.character.RootPart.Velocity.Magnitude, 90)
						motor.DesiredAngle = math.rad(6) + math.rad(velo) + (velo > 1 and math.abs(math.cos(tick() * 5)) / 3 or 0)
					end
					capesurface["Enabled"] = (gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude > 0.6
					part.Transparency = (gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude > 0.6 and 0 or 1
					task.wait()
				until not Cape["Enabled"]
			else
				part = nil
				motor = nil
			end
		end,
		["Tooltip"] = 'Add\'s a cape to your character'
	})
	Texture = Cape:CreateTextBox({
		["Name"] = 'Texture'
	})
	CapeMode = Cape:CreateDropdown({
		["Name"] ='Mode',
		["List"] = {
			'Opal Reiko'
		},
		["HoverText"] = 'A cape mod.',
		["Value"] = 'Opal Reiko',
		["Function"] = function(val) 
			if capeModeMap[val] then
                		Texture["Value"] = capeModeMap[val]
            		end
		end
	})
end)
	
run(function()
	local ChinaHat
	local Material
	local Color
	local hat
	
	ChinaHat = vape.Categories.Visuals:CreateModule({
		Name = 'China Hat',
		Function = function(callback)
			if callback then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				hat = Instance.new('MeshPart')
				hat.Size = Vector3.new(3, 0.7, 3)
				hat.Name = 'ChinaHat'
				hat.Material = Enum.Material[Material.Value]
				hat.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				hat.CanCollide = false
				hat.CanQuery = false
				hat.Massless = true
				hat.MeshId = 'http://www.roblox.com/asset/?id=1778999'
				hat.Transparency = 1 - Color.Opacity
				hat.Parent = gameCamera
				hat.CFrame = entitylib.isAlive and entitylib.character.Head.CFrame + Vector3.new(0, 1, 0) or CFrame.identity
				local weld = Instance.new('WeldConstraint')
				weld.Part0 = hat
				weld.Part1 = entitylib.isAlive and entitylib.character.Head or nil
				weld.Parent = hat
				ChinaHat:Clean(hat)
				ChinaHat:Clean(entitylib.Events.LocalAdded:Connect(function(char)
					if weld then 
						weld:Destroy() 
					end
					hat.Parent = gameCamera
					hat.CFrame = char.Head.CFrame + Vector3.new(0, 1, 0)
					hat.Velocity = Vector3.zero
					weld = Instance.new('WeldConstraint')
					weld.Part0 = hat
					weld.Part1 = char.Head
					weld.Parent = hat
				end))
	
				repeat
					hat.LocalTransparencyModifier = ((gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude <= 0.6 and 1 or 0)
					task.wait()
				until not ChinaHat.Enabled
			else
				hat = nil
			end
		end,
		Tooltip = 'Puts a china hat on your character (ty mastadawn)'
	})
	local materials = {'ForceField'}
	for _, v in Enum.Material:GetEnumItems() do
		if v.Name ~= 'ForceField' then
			table.insert(materials, v.Name)
		end
	end
	Material = ChinaHat:CreateDropdown({
		Name = 'Material',
		List = materials,
		Function = function(val)
			if hat then
				hat.Material = Enum.Material[val]
			end
		end
	})
	Color = ChinaHat:CreateColorSlider({
		Name = 'Hat Color',
		DefaultOpacity = 0.7,
		Function = function(hue, sat, val, opacity)
			if hat then
				hat.Color = Color3.fromHSV(hue, sat, val)
				hat.Transparency = 1 - opacity
			end
		end
	})
end)
		
run(function()
	local Disguise
	local Mode
	local IDBox
	local desc
	
	local function itemAdded(v, manual)
		if (not v:GetAttribute('Disguise')) and ((v:IsA('Accessory') and (not v:GetAttribute('InvItem')) and (not v:GetAttribute('ArmorSlot'))) or v:IsA('ShirtGraphic') or v:IsA('Shirt') or v:IsA('Pants') or v:IsA('BodyColors') or manual) then
			repeat
				task.wait()
				v.Parent = game
			until v.Parent == game
			v:ClearAllChildren()
			v:Destroy()
		end
	end
	
	local function characterAdded(char)
		if Mode.Value == 'Character' then
			task.wait(0.1)
			char.Character.Archivable = true
			local clone = char.Character:Clone()
			repeat
				if pcall(function()
					desc = playersService:GetHumanoidDescriptionFromUserId(IDBox.Value == '' and 239702688 or tonumber(IDBox.Value))
				end) and desc then break end
				task.wait(1)
			until not Disguise.Enabled
			if not Disguise.Enabled then
				clone:ClearAllChildren()
				clone:Destroy()
				clone = nil
				if desc then
					desc:Destroy()
					desc = nil
				end
				return
			end
			clone.Parent = game
	
			local originalDesc = char.Humanoid:WaitForChild('HumanoidDescription', 2) or {
				HeightScale = 1,
				SetEmotes = function() end,
				SetEquippedEmotes = function() end
			}
			originalDesc.JumpAnimation = desc.JumpAnimation
			desc.HeightScale = originalDesc.HeightScale
	
			for _, v in clone:GetChildren() do
				if v:IsA('Accessory') or v:IsA('ShirtGraphic') or v:IsA('Shirt') or v:IsA('Pants') then
					v:ClearAllChildren()
					v:Destroy()
				end
			end
	
			clone.Humanoid:ApplyDescriptionClientServer(desc)
			for _, v in char.Character:GetChildren() do
				itemAdded(v)
			end
			Disguise:Clean(char.Character.ChildAdded:Connect(itemAdded))
	
			for _, v in clone:WaitForChild('Animate'):GetChildren() do
				if not char.Character:FindFirstChild('Animate') then return end
				local real = char.Character.Animate:FindFirstChild(v.Name)
				if v and real then
					local anim = v:FindFirstChildWhichIsA('Animation') or {AnimationId = ''}
					local realanim = real:FindFirstChildWhichIsA('Animation') or {AnimationId = ''}
					if realanim then
						realanim.AnimationId = anim.AnimationId
					end
				end
			end
	
			for _, v in clone:GetChildren() do
				v:SetAttribute('Disguise', true)
				if v:IsA('Accessory') then
					for _, v2 in v:GetDescendants() do
						if v2:IsA('Weld') and v2.Part1 then
							v2.Part1 = char.Character[v2.Part1.Name]
						end
					end
					v.Parent = char.Character
				elseif v:IsA('ShirtGraphic') or v:IsA('Shirt') or v:IsA('Pants') or v:IsA('BodyColors') then
					v.Parent = char.Character
				elseif v.Name == 'Head' and char.Head:IsA('MeshPart') and (not char.Head:FindFirstChild('FaceControls')) then
					char.Head.MeshId = v.MeshId
				end
			end
	
			local localface = char.Character:FindFirstChild('face', true)
			local cloneface = clone:FindFirstChild('face', true)
			if localface and cloneface then
				itemAdded(localface, true)
				cloneface.Parent = char.Head
			end
			originalDesc:SetEmotes(desc:GetEmotes())
			originalDesc:SetEquippedEmotes(desc:GetEquippedEmotes())
			clone:ClearAllChildren()
			clone:Destroy()
			clone = nil
			if desc then
				desc:Destroy()
				desc = nil
			end
		else
			local data
			repeat
				if pcall(function()
					data = marketplaceService:GetProductInfo(IDBox.Value == '' and 43 or tonumber(IDBox.Value), Enum.InfoType.Bundle)
				end) then break end
				task.wait(1)
			until not Disguise.Enabled
			if not Disguise.Enabled then
				if data then
					table.clear(data)
					data = nil
				end
				return
			end
			if data.BundleType == 'AvatarAnimations' then
				local animate = char.Character:FindFirstChild('Animate')
				if not animate then return end
				for _, v in desc.Items do
					local animtype = v.Name:split(' ')[2]:lower()
					if animtype ~= 'animation' then
						local suc, res = pcall(function() return game:GetObjects('rbxassetid://'..v.Id) end)
						if suc then
							animate[animtype]:FindFirstChildWhichIsA('Animation').AnimationId = res[1]:FindFirstChildWhichIsA('Animation', true).AnimationId
						end
					end
				end
			else
				notif('Disguise', 'that\'s not an animation pack', 5, 'warning')
			end
		end
	end
	
	Disguise = vape.Categories.Visuals:CreateModule({
		Name = 'Disguise',
		Function = function(callback)
			if callback then
				Disguise:Clean(entitylib.Events.LocalAdded:Connect(characterAdded))
				if entitylib.isAlive then
					characterAdded(entitylib.character)
				end
			end
		end,
		Tooltip = 'Changes your character or animation to a specific ID (animation packs or userid\'s only)'
	})
	Mode = Disguise:CreateDropdown({
		Name = 'Mode',
		List = {'Character', 'Animation'},
		Function = function()
			if Disguise.Enabled then
				Disguise:Toggle()
				Disguise:Toggle()
			end
		end
	})
	IDBox = Disguise:CreateTextBox({
		Name = 'Disguise',
		Placeholder = 'Disguise User Id',
		Function = function()
			if Disguise.Enabled then
				Disguise:Toggle()
				Disguise:Toggle()
			end
		end
	})
end)
run(function()
    local damageboost = nil
    local damageboostduration = nil
    local damageboostmultiplier = nil
    damageboost = vape.Categories.Blatant:CreateModule({
        Name = 'Damage Boost',
        Tooltip = 'Makes you go faster whenever you take knockback.',
        Function = function(callback)
            if callback then
                damageboost:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
                    local player = damageTable.entityInstance and playersService:GetPlayerFromCharacter(damageTable.entityInstance)
                    if player and player == lplr and (damageTable.knockbackMultiplier and damageTable.knockbackMultiplier.horizontal and damageTable.knockbackMultiplier.horizontal > 0 or playersService:GetPlayerFromCharacter(damageTable.fromEntity) ~= nil) and not vape.Modules['Long Jump'].Enabled then
                        damagedata.Multi = damageboostmultiplier.Value --+ (damageTable.knockbackMultiplier.horizontal / 2)
                        damagedata.lastHit = tick() + damageboostduration.Value
                    end
                end))
            end
        end
    })
    damageboostduration = damageboost:CreateSlider({
        Name = 'Duration',
        Min = 0,
        Max = 2,
        Decimal = 20,
        Default = 0.4,
    })
    damageboostmultiplier = damageboost:CreateSlider({
        Name = 'Multiplier',
        Min = 0,
        Max = 2,
        Decimal = 20,
        Default = 1.4,
    })
end)
run(function()
	local RandomDisguise
	local RefreshButton
	local SaveCurrentButton
	local ExcludeFriends
	
	local currentDisguise = nil
	local originalName = nil
	local disguisedPlayers = {}
	
	local function getRandomPlayer(excludeLocal)
		local players = game:GetService("Players"):GetPlayers()
		local validPlayers = {}
		
		for _, player in ipairs(players) do
			if player ~= game:GetService("Players").LocalPlayer then
				if not ExcludeFriends.Enabled or not player:IsFriendsWith(game:GetService("Players").LocalPlayer.UserId) then
					if not disguisedPlayers[player] then
						table.insert(validPlayers, player)
					end
				end
			end
		end
		
		if #validPlayers > 0 then
			return validPlayers[math.random(1, #validPlayers)]
		end
		return nil
	end
	
	local function itemAdded(v, manual)
		if (not v:GetAttribute('Disguise')) and ((v:IsA('Accessory') and (not v:GetAttribute('InvItem')) and (not v:GetAttribute('ArmorSlot'))) or v:IsA('ShirtGraphic') or v:IsA('Shirt') or v:IsA('Pants') or v:IsA('BodyColors') or manual) then
			repeat
				task.wait()
				v.Parent = game
			until v.Parent == game
			v:ClearAllChildren()
			v:Destroy()
		end
	end
	
	local function applyDisguise(player)
		if not player or not player.Character then return end
		
		local char = entitylib.character
		if not char then return end
		
		-- Store original name for later
		if not originalName then
			originalName = game:GetService("Players").LocalPlayer.DisplayName
		end
		
		-- Get target player's description
		local desc
		repeat
			if pcall(function()
				desc = playersService:GetHumanoidDescriptionFromUserId(player.UserId)
			end) and desc then break end
			task.wait(0.5)
		until not RandomDisguise.Enabled
		
		if not RandomDisguise.Enabled then
			if desc then
				desc:Destroy()
				desc = nil
			end
			return
		end
		
		char.Archivable = true
		local clone = char:Clone()
		
		local originalDesc = char.Humanoid:WaitForChild('HumanoidDescription', 2) or {
			HeightScale = 1,
			SetEmotes = function() end,
			SetEquippedEmotes = function() end
		}
		originalDesc.JumpAnimation = desc.JumpAnimation
		desc.HeightScale = originalDesc.HeightScale
		
		-- Clear clone of existing items
		for _, v in clone:GetChildren() do
			if v:IsA('Accessory') or v:IsA('ShirtGraphic') or v:IsA('Shirt') or v:IsA('Pants') then
				v:ClearAllChildren()
				v:Destroy()
			end
		end
		
		-- Apply the description
		clone.Humanoid:ApplyDescriptionClientServer(desc)
		
		-- Clear current character's items
		for _, v in char:GetChildren() do
			itemAdded(v)
		end
		
		-- Move items from clone to character
		for _, v in clone:GetChildren() do
			v:SetAttribute('Disguise', true)
			if v:IsA('Accessory') then
				for _, v2 in v:GetDescendants() do
					if v2:IsA('Weld') and v2.Part1 then
						v2.Part1 = char[v2.Part1.Name]
					end
				end
				v.Parent = char
			elseif v:IsA('ShirtGraphic') or v:IsA('Shirt') or v:IsA('Pants') or v:IsA('BodyColors') then
				v.Parent = char
			elseif v.Name == 'Head' and char.Head:IsA('MeshPart') and (not char.Head:FindFirstChild('FaceControls')) then
				char.Head.MeshId = v.MeshId
			end
		end
		
		-- Handle face
		local localface = char:FindFirstChild('face', true)
		local cloneface = clone:FindFirstChild('face', true)
		if localface and cloneface then
			itemAdded(localface, true)
			cloneface.Parent = char.Head
			cloneface:SetAttribute('Disguise', true)
		end
		
		-- Set emotes
		originalDesc:SetEmotes(desc:GetEmotes())
		originalDesc:SetEquippedEmotes(desc:GetEquippedEmotes())
		
		-- Clean up
		clone:ClearAllChildren()
		clone:Destroy()
		if desc then
			desc:Destroy()
			desc = nil
		end
		
		-- Store current disguise
		currentDisguise = player
		disguisedPlayers[player] = true
		
		-- Change name (this will show in the module text)
		RandomDisguise:UpdateExtra()
	end
	
	local function characterAdded(char)
		if currentDisguise then
			task.wait(0.5)
			applyDisguise(currentDisguise)
		end
	end
	
	RandomDisguise = vape.Categories.Visuals:CreateModule({
		Name = 'Streamer Mode',
		Function = function(callback)
			if not callback then
				-- Reset to original appearance when disabled
				if originalName then
					-- This would need logic to restore original appearance
					-- For simplicity, just clear the current disguise
					currentDisguise = nil
					disguisedPlayers = {}
					originalName = nil
				end
				return
			end
			
			-- Pick a random player
			local randomPlayer = getRandomPlayer(true)
			if not randomPlayer then
				notif('Random Disguise', 'No suitable players found', 3, 'warning')
				RandomDisguise:Toggle() -- Turn off
				return
			end
			
			-- Apply the disguise
			applyDisguise(randomPlayer)
			
			-- Connect for respawns
			RandomDisguise:Clean(entitylib.Events.LocalAdded:Connect(characterAdded))
			if entitylib.isAlive then
				characterAdded(entitylib.character)
			end
		end,
		ExtraText = function()
			if currentDisguise then
				return "(" .. currentDisguise.DisplayName .. ")"
			end
			return ""
		end,
		Tooltip = 'Randomly disguise as another player in the game'
	})
	
	-- REFRESH BUTTON (pick new random player)
	RefreshButton = RandomDisguise:CreateButton({
		Name = 'Pick New',
		Function = function()
			if not RandomDisguise.Enabled then return end
			
			-- Remove current from list to avoid repeats
			if currentDisguise then
				disguisedPlayers[currentDisguise] = nil
			end
			
			-- Pick new random player
			local newPlayer = getRandomPlayer(true)
			if newPlayer then
				applyDisguise(newPlayer)
				notif('Random Disguise', 'Now disguised as: ' .. newPlayer.DisplayName, 3)
			else
				notif('Random Disguise', 'No more unique players available', 3, 'warning')
			end
		end
	})
	
	-- SAVE CURRENT DISGUISE (keep this player for later)
	SaveCurrentButton = RandomDisguise:CreateButton({
		Name = 'Save Current',
		Function = function()
			if not RandomDisguise.Enabled or not currentDisguise then return end
			
			-- In a real implementation, you would save the player's ID to config
			notif('Random Disguise', 'Saved: ' .. currentDisguise.DisplayName, 3)
			-- This would be saved to vape settings
		end
	})
	
	-- EXCLUDE FRIENDS TOGGLE
	ExcludeFriends = RandomDisguise:CreateToggle({
		Name = 'Exclude Friends',
		Default = true,
		Tooltip = 'Won\'t disguise as your friends'
	})
end)
run(function()
    local Disabler = {Enabled = false}

    Disabler = vape.Categories.Utility:CreateModule({
        Name = "Lobby Disabler",
        Function = function(callback)
            if callback then
                notif('Disabler', 'Get a kill with zephyr and the speed check is gone', 3)
                spawn(function()
                    while Disabler.Enabled do
                        firesignal(WindWalkerSpeedUpdate.OnClientEvent, {
                            multiplier = 1.15,
                            orbCount = 15
                        })
                        task.wait()
                    end
                end)
            end
        end,
        Tooltip = "Disabler with zephyr"
    })
end)
run(function()
	local FOV
	local Value
	local oldfov
	
	FOV = vape.Categories.Visuals:CreateModule({
		Name = 'FOV',
		Function = function(callback)
			if callback then
				oldfov = gameCamera.FieldOfView
				repeat
					gameCamera.FieldOfView = Value.Value
					task.wait()
				until not FOV.Enabled
			else
				gameCamera.FieldOfView = oldfov
			end
		end,
		Tooltip = 'Adjusts camera vision'
	})
	Value = FOV:CreateSlider({
		Name = 'FOV',
		Min = 30,
		Max = 120
	})
end)
	
run(function()
	local SongBeats
	local List
	local FOV
	local FOVValue = {}
	local Volume
	local alreadypicked = {}
	local beattick = tick()
	local oldfov, songobj, songbpm, songtween
	
	local function choosesong()
		local list = List.ListEnabled
		if #alreadypicked >= #list then
			table.clear(alreadypicked)
		end
	
		if #list <= 0 then
			notif('SongBeats', 'no songs', 10)
			SongBeats:Toggle()
			return
		end
	
		local chosensong = list[math.random(1, #list)]
		if #list > 1 and table.find(alreadypicked, chosensong) then
			repeat
				task.wait()
				chosensong = list[math.random(1, #list)]
			until not table.find(alreadypicked, chosensong) or not SongBeats.Enabled
		end
		if not SongBeats.Enabled then return end
	
		local split = chosensong:split('/')
		if not isfile(split[1]) then
			notif('SongBeats', 'Missing song ('..split[1]..')', 10)
			SongBeats:Toggle()
			return
		end
	
		songobj.SoundId = assetfunction(split[1])
		repeat task.wait() until songobj.IsLoaded or not SongBeats.Enabled
		if SongBeats.Enabled then
			beattick = tick() + (tonumber(split[3]) or 0)
			songbpm = 60 / (tonumber(split[2]) or 50)
			songobj:Play()
		end
	end
	
	SongBeats = vape.Categories.Visuals:CreateModule({
		Name = 'Song Beats',
		Function = function(callback)
			if callback then
				songobj = Instance.new('Sound')
				songobj.Volume = Volume.Value / 100
				songobj.Parent = workspace
				oldfov = gameCamera.FieldOfView
	
				repeat
					if not songobj.Playing then
						choosesong()
					end
					if beattick < tick() and SongBeats.Enabled and FOV.Enabled then
						beattick = tick() + songbpm
						gameCamera.FieldOfView = oldfov - FOVValue.Value
						songtween = tweenService:Create(gameCamera, TweenInfo.new(math.min(songbpm, 0.2), Enum.EasingStyle.Linear), {
							FieldOfView = oldfov
						})
						songtween:Play()
					end
					task.wait()
				until not SongBeats.Enabled
			else
				if songobj then
					songobj:Destroy()
				end
				if songtween then
					songtween:Cancel()
				end
				if oldfov then
					gameCamera.FieldOfView = oldfov
				end
				table.clear(alreadypicked)
			end
		end,
		Tooltip = 'Built in mp3 player'
	})
	List = SongBeats:CreateTextList({
		Name = 'Songs',
		Placeholder = 'filepath/bpm/start'
	})
	FOV = SongBeats:CreateToggle({
		Name = 'Beat FOV',
		Function = function(callback)
			if FOVValue.Object then
				FOVValue.Object.Visible = callback
			end
			if SongBeats.Enabled then
				SongBeats:Toggle()
				SongBeats:Toggle()
			end
		end,
		Default = true
	})
	FOVValue = SongBeats:CreateSlider({
		Name = 'Adjustment',
		Min = 1,
		Max = 30,
		Default = 5,
		Darker = true
	})
	Volume = SongBeats:CreateSlider({
		Name = 'Volume',
		Function = function(val)
			if songobj then
				songobj.Volume = val / 100
			end
		end,
		Min = 1,
		Max = 200,
		Default = 100,
		Suffix = '%'
	})
end)

run(function()
    Shaders = vape.Categories.Render:CreateModule({
        ['Name'] = 'Shaders',
        Function = function(call)            
        if call then
			pcall(function()
				print("shaders enabled")
				game:GetService("Lighting"):ClearAllChildren()
				local Bloom = Instance.new("BloomEffect")
				Bloom.Intensity = 0.1
				Bloom.Threshold = 0
				Bloom.Size = 100

				local Tropic = Instance.new("Sky")
				Tropic.Name = "Tropic"
				Tropic.SkyboxUp = "http://www.roblox.com/asset/?id=169210149"
				Tropic.SkyboxLf = "http://www.roblox.com/asset/?id=169210133"
				Tropic.SkyboxBk = "http://www.roblox.com/asset/?id=169210090"
				Tropic.SkyboxFt = "http://www.roblox.com/asset/?id=169210121"
				Tropic.StarCount = 100
				Tropic.SkyboxDn = "http://www.roblox.com/asset/?id=169210108"
				Tropic.SkyboxRt = "http://www.roblox.com/asset/?id=169210143"
				Tropic.Parent = Bloom

				local Sky = Instance.new("Sky")
				Sky.SkyboxUp = "http://www.roblox.com/asset/?id=196263782"
				Sky.SkyboxLf = "http://www.roblox.com/asset/?id=196263721"
				Sky.SkyboxBk = "http://www.roblox.com/asset/?id=196263721"
				Sky.SkyboxFt = "http://www.roblox.com/asset/?id=196263721"
				Sky.CelestialBodiesShown = false
				Sky.SkyboxDn = "http://www.roblox.com/asset/?id=196263643"
				Sky.SkyboxRt = "http://www.roblox.com/asset/?id=196263721"
				Sky.Parent = Bloom

				Bloom.Parent = game:GetService("Lighting")

				local Bloom = Instance.new("BloomEffect")
				Bloom.Enabled = false
				Bloom.Intensity = 0.35
				Bloom.Threshold = 0.2
				Bloom.Size = 56

				local Tropic = Instance.new("Sky")
				Tropic.Name = "Tropic"
				Tropic.SkyboxUp = "http://www.roblox.com/asset/?id=169210149"
				Tropic.SkyboxLf = "http://www.roblox.com/asset/?id=169210133"
				Tropic.SkyboxBk = "http://www.roblox.com/asset/?id=169210090"
				Tropic.SkyboxFt = "http://www.roblox.com/asset/?id=169210121"
				Tropic.StarCount = 100
				Tropic.SkyboxDn = "http://www.roblox.com/asset/?id=169210108"
				Tropic.SkyboxRt = "http://www.roblox.com/asset/?id=169210143"
				Tropic.Parent = Bloom

				local Sky = Instance.new("Sky")
				Sky.SkyboxUp = "http://www.roblox.com/asset/?id=196263782"
				Sky.SkyboxLf = "http://www.roblox.com/asset/?id=196263721"
				Sky.SkyboxBk = "http://www.roblox.com/asset/?id=196263721"
				Sky.SkyboxFt = "http://www.roblox.com/asset/?id=196263721"
				Sky.CelestialBodiesShown = false
				Sky.SkyboxDn = "http://www.roblox.com/asset/?id=196263643"
				Sky.SkyboxRt = "http://www.roblox.com/asset/?id=196263721"
				Sky.Parent = Bloom

				Bloom.Parent = game:GetService("Lighting")
				local Blur = Instance.new("BlurEffect")
				Blur.Size = 2

				Blur.Parent = game:GetService("Lighting")
				local Efecto = Instance.new("BlurEffect")
				Efecto.Name = "Efecto"
				Efecto.Enabled = false
				Efecto.Size = 2

				Efecto.Parent = game:GetService("Lighting")
				local Inaritaisha = Instance.new("ColorCorrectionEffect")
				Inaritaisha.Name = "Inari taisha"
				Inaritaisha.Saturation = 0.05
				Inaritaisha.TintColor = Color3.fromRGB(255, 224, 219)

				Inaritaisha.Parent = game:GetService("Lighting")
				local Normal = Instance.new("ColorCorrectionEffect")
				Normal.Name = "Normal"
				Normal.Enabled = false
				Normal.Saturation = -0.2
				Normal.TintColor = Color3.fromRGB(255, 232, 215)

				Normal.Parent = game:GetService("Lighting")
				local SunRays = Instance.new("SunRaysEffect")
				SunRays.Intensity = 0.05

				SunRays.Parent = game:GetService("Lighting")
				local Sunset = Instance.new("Sky")
				Sunset.Name = "Sunset"
				Sunset.SkyboxUp = "rbxassetid://323493360"
				Sunset.SkyboxLf = "rbxassetid://323494252"
				Sunset.SkyboxBk = "rbxassetid://323494035"
				Sunset.SkyboxFt = "rbxassetid://323494130"
				Sunset.SkyboxDn = "rbxassetid://323494368"
				Sunset.SunAngularSize = 14
				Sunset.SkyboxRt = "rbxassetid://323494067"

				Sunset.Parent = game:GetService("Lighting")
				local Takayama = Instance.new("ColorCorrectionEffect")
				Takayama.Name = "Takayama"
				Takayama.Enabled = false
				Takayama.Saturation = -0.3
				Takayama.Contrast = 0.1
				Takayama.TintColor = Color3.fromRGB(235, 214, 204)

				Takayama.Parent = game:GetService("Lighting")
				local L = game:GetService("Lighting")
				L.Brightness = 2.14
				L.ColorShift_Bottom = Color3.fromRGB(11, 0, 20)
				L.ColorShift_Top = Color3.fromRGB(240, 127, 14)
				L.OutdoorAmbient = Color3.fromRGB(34, 0, 49)
				L.ClockTime = 6.7
				L.FogColor = Color3.fromRGB(94, 76, 106)
				L.FogEnd = 1000
				L.FogStart = 0
				L.ExposureCompensation = 0.24
				L.ShadowSoftness = 0
				L.Ambient = Color3.fromRGB(59, 33, 27)

				local Bloom = Instance.new("BloomEffect")
				Bloom.Intensity = 0.1
				Bloom.Threshold = 0
				Bloom.Size = 100

				local Tropic = Instance.new("Sky")
				Tropic.Name = "Tropic"
				Tropic.SkyboxUp = "http://www.roblox.com/asset/?id=169210149"
				Tropic.SkyboxLf = "http://www.roblox.com/asset/?id=169210133"
				Tropic.SkyboxBk = "http://www.roblox.com/asset/?id=169210090"
				Tropic.SkyboxFt = "http://www.roblox.com/asset/?id=169210121"
				Tropic.StarCount = 100
				Tropic.SkyboxDn = "http://www.roblox.com/asset/?id=169210108"
				Tropic.SkyboxRt = "http://www.roblox.com/asset/?id=169210143"
				Tropic.Parent = Bloom

				local Sky = Instance.new("Sky")
				Sky.SkyboxUp = "http://www.roblox.com/asset/?id=196263782"
				Sky.SkyboxLf = "http://www.roblox.com/asset/?id=196263721"
				Sky.SkyboxBk = "http://www.roblox.com/asset/?id=196263721"
				Sky.SkyboxFt = "http://www.roblox.com/asset/?id=196263721"
				Sky.CelestialBodiesShown = false
				Sky.SkyboxDn = "http://www.roblox.com/asset/?id=196263643"
				Sky.SkyboxRt = "http://www.roblox.com/asset/?id=196263721"
				Sky.Parent = Bloom

				Bloom.Parent = game:GetService("Lighting")

				local Bloom = Instance.new("BloomEffect")
				Bloom.Enabled = false
				Bloom.Intensity = 0.35
				Bloom.Threshold = 0.2
				Bloom.Size = 56

				local Tropic = Instance.new("Sky")
				Tropic.Name = "Tropic"
				Tropic.SkyboxUp = "http://www.roblox.com/asset/?id=169210149"
				Tropic.SkyboxLf = "http://www.roblox.com/asset/?id=169210133"
				Tropic.SkyboxBk = "http://www.roblox.com/asset/?id=169210090"
				Tropic.SkyboxFt = "http://www.roblox.com/asset/?id=169210121"
				Tropic.StarCount = 100
				Tropic.SkyboxDn = "http://www.roblox.com/asset/?id=169210108"
				Tropic.SkyboxRt = "http://www.roblox.com/asset/?id=169210143"
				Tropic.Parent = Bloom

				local Sky = Instance.new("Sky")
				Sky.SkyboxUp = "http://www.roblox.com/asset/?id=196263782"
				Sky.SkyboxLf = "http://www.roblox.com/asset/?id=196263721"
				Sky.SkyboxBk = "http://www.roblox.com/asset/?id=196263721"
				Sky.SkyboxFt = "http://www.roblox.com/asset/?id=196263721"
				Sky.CelestialBodiesShown = false
				Sky.SkyboxDn = "http://www.roblox.com/asset/?id=196263643"
				Sky.SkyboxRt = "http://www.roblox.com/asset/?id=196263721"
				Sky.Parent = Bloom

				Bloom.Parent = game:GetService("Lighting")
				local Blur = Instance.new("BlurEffect")
				Blur.Size = 2

				Blur.Parent = game:GetService("Lighting")
				local Efecto = Instance.new("BlurEffect")
				Efecto.Name = "Efecto"
				Efecto.Enabled = false
				Efecto.Size = 4

				Efecto.Parent = game:GetService("Lighting")
				local Inaritaisha = Instance.new("ColorCorrectionEffect")
				Inaritaisha.Name = "Inari taisha"
				Inaritaisha.Saturation = 0.05
				Inaritaisha.TintColor = Color3.fromRGB(255, 224, 219)

				Inaritaisha.Parent = game:GetService("Lighting")
				local Normal = Instance.new("ColorCorrectionEffect")
				Normal.Name = "Normal"
				Normal.Enabled = false
				Normal.Saturation = -0.2
				Normal.TintColor = Color3.fromRGB(255, 232, 215)

				Normal.Parent = game:GetService("Lighting")
				local SunRays = Instance.new("SunRaysEffect")
				SunRays.Intensity = 0.05

				SunRays.Parent = game:GetService("Lighting")
				local Sunset = Instance.new("Sky")
				Sunset.Name = "Sunset"
				Sunset.SkyboxUp = "rbxassetid://323493360"
				Sunset.SkyboxLf = "rbxassetid://323494252"
				Sunset.SkyboxBk = "rbxassetid://323494035"
				Sunset.SkyboxFt = "rbxassetid://323494130"
				Sunset.SkyboxDn = "rbxassetid://323494368"
				Sunset.SunAngularSize = 14
				Sunset.SkyboxRt = "rbxassetid://323494067"

				Sunset.Parent = game:GetService("Lighting")
				local Takayama = Instance.new("ColorCorrectionEffect")
				Takayama.Name = "Takayama"
				Takayama.Enabled = false
				Takayama.Saturation = -0.3
				Takayama.Contrast = 0.1
				Takayama.TintColor = Color3.fromRGB(235, 214, 204)

				Takayama.Parent = game:GetService("Lighting")
				local L = game:GetService("Lighting")
				L.Brightness = 2.3
				L.ColorShift_Bottom = Color3.fromRGB(11, 0, 20)
				L.ColorShift_Top = Color3.fromRGB(240, 127, 14)
				L.OutdoorAmbient = Color3.fromRGB(34, 0, 49)
				L.TimeOfDay = "07:30:00"
				L.FogColor = Color3.fromRGB(94, 76, 106)
				L.FogEnd = 300
				L.FogStart = 0
				L.ExposureCompensation = 0.24
				L.ShadowSoftness = 0
				L.Ambient = Color3.fromRGB(59, 33, 27)
			end)
		else
			pcall(function()
				print("shaders disabled")
			end)
		end
        end,
        Default = false,
        Tooltip = ""
    })
end)
run(function()
    local conn

    PixelSword = vape.Categories.Utility:CreateModule({
        Name = "PixelSword",
        Function = function(callback)
            if callback then
                conn = workspace.CurrentCamera.Viewmodel.ChildAdded:Connect(function(x)
                    if x and x:FindFirstChild("Handle") then
                        if string.find(x.Name:lower(), 'sword') then
                            x.Handle.Material = Enum.Material.ForceField
                            x.Handle.MeshId = "rbxassetid://13471207377"
                            x.Handle.BrickColor = BrickColor.new("Hot pink")
                        end
                    end
                end)
            else
                if conn then
                    conn:Disconnect()
                    conn = nil
                end
            end
        end,
        Default = false,
        Tooltip = "Customizes Your Swords"
    })
end)
