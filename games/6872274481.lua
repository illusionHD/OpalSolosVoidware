--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end
local vapeEvents = setmetatable({}, {
	__index = function(self, index)
		self[index] = Instance.new('BindableEvent')
		return self[index]
	end
})

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local httpService = cloneref(game:GetService('HttpService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local collectionService = cloneref(game:GetService('CollectionService'))
local contextActionService = cloneref(game:GetService('ContextActionService'))
local guiService = cloneref(game:GetService('GuiService'))
local coreGui = cloneref(game:GetService('CoreGui'))
local starterGui = cloneref(game:GetService('StarterGui'))

local isnetworkowner = identifyexecutor and table.find({'AWP', 'Nihon', 'Volcano'}, ({identifyexecutor()})[1]) and isnetworkowner or function()
	return true
end
local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset

local vape = shared.vape
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo
local uipallet = vape.Libraries.uipallet
local tween = vape.Libraries.tween
local color = vape.Libraries.color
local whitelist = vape.Libraries.whitelist
local prediction = vape.Libraries.prediction
local getfontsize = vape.Libraries.getfontsize
local getcustomasset = vape.Libraries.getcustomasset

local store = {
	attackReach = 0,
	attackReachUpdate = tick(),
	damageBlockFail = tick(),
	hand = {},
	inventory = {
		inventory = {
			items = {},
			armor = {}
		},
		hotbar = {}
	},
	inventories = {},
	matchState = 0,
	queueType = 'bedwars_test',
	tools = {}
}
shared.CRYSTALVAPE_STORE = store
local RemotesInstance = replicatedStorage:WaitForChild("rbxts_include").node_modules["@rbxts"].net.out._NetManaged
local Reach = {}
local HitBoxes = {}
local InfiniteFly = {}
local TrapDisabler
local AntiFallPart
local bedwars, remotes, sides, oldinvrender, oldSwing = {}, {}, {}

local function addBlur(parent)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = getcustomasset('OSVPrivate/assets/new/blur.png')
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = parent
	return blur
end

local function collection(tags, module, customadd, customremove)
	tags = typeof(tags) ~= 'table' and {tags} or tags
	local objs, connections = {}, {}

	for _, tag in tags do
		table.insert(connections, collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
			if customadd then
				customadd(objs, v, tag)
				return
			end
			table.insert(objs, v)
		end))
		table.insert(connections, collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
			if customremove then
				customremove(objs, v, tag)
				return
			end
			v = table.find(objs, v)
			if v then
				table.remove(objs, v)
			end
		end))

		for _, v in collectionService:GetTagged(tag) do
			if customadd then
				customadd(objs, v, tag)
				continue
			end
			table.insert(objs, v)
		end
	end

	local cleanFunc = function(self)
		for _, v in connections do
			v:Disconnect()
		end
		table.clear(connections)
		table.clear(objs)
		table.clear(self)
	end
	if module then
		module:Clean(cleanFunc)
	end
	return objs, cleanFunc
end

local function getBestArmor(slot)
	local closest, mag = nil, 0

	for _, item in store.inventory.inventory.items do
		local meta = item and bedwars.ItemMeta[item.itemType] or {}

		if meta.armor and meta.armor.slot == slot then
			local newmag = (meta.armor.damageReductionMultiplier or 0)

			if newmag > mag then
				closest, mag = item, newmag
			end
		end
	end

	return closest
end

local function getBow()
	local bestBow, bestBowSlot, bestBowDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local bowMeta = bedwars.ItemMeta[item.itemType].projectileSource
		if bowMeta and table.find(bowMeta.ammoItemTypes, 'arrow') then
			local bowDamage = bedwars.ProjectileMeta[bowMeta.projectileType('arrow')].combat.damage or 0
			if bowDamage > bestBowDamage then
				bestBow, bestBowSlot, bestBowDamage = item, slot, bowDamage
			end
		end
	end
	return bestBow, bestBowSlot
end

local function getItem(itemName, inv)
	if itemName == "rocket_belt" or itemName == "flying_backpack" and not inv then
		inv = store.inventory.inventory.backpack

		for slot, item in (inv or store.inventory.inventory.items) do
			if slot == "tool" and item.Name == itemName then
				return {
					tool = item,
					amount = 1,
					toolType = item.Name
				}
			end
		end
	else
		for slot, item in (inv or store.inventory.inventory.items) do
			if item.itemType == itemName then
				return item, slot
			end
		end
	end
	return nil
end

local function getRoactRender(func)
	return debug.getupvalue(debug.getupvalue(debug.getupvalue(func, 3).render, 2).render, 1)
end

local function getSword()
	local bestSword, bestSwordSlot, bestSwordDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local swordMeta = bedwars.ItemMeta[item.itemType].sword
		if swordMeta then
			local swordDamage = swordMeta.damage or 0
			if swordDamage > bestSwordDamage then
				bestSword, bestSwordSlot, bestSwordDamage = item, slot, swordDamage
			end
		end
	end
	return bestSword, bestSwordSlot
end

local function getTool(breakType)
	local bestTool, bestToolSlot, bestToolDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local toolMeta = bedwars.ItemMeta[item.itemType].breakBlock
		if toolMeta then
			local toolDamage = toolMeta[breakType] or 0
			if toolDamage > bestToolDamage then
				bestTool, bestToolSlot, bestToolDamage = item, slot, toolDamage
			end
		end
	end
	return bestTool, bestToolSlot
end

local function getWool()
	for _, wool in (inv or store.inventory.inventory.items) do
		if wool.itemType:find('wool') then
			return wool and wool.itemType, wool and wool.amount
		end
	end
end

local function getStrength(plr)
	if not plr.Player then
		return 0
	end

	local strength = 0
	for _, v in (store.inventories[plr.Player] or {items = {}}).items do
		local itemmeta = bedwars.ItemMeta[v.itemType]
		if itemmeta and itemmeta.sword and itemmeta.sword.damage > strength then
			strength = itemmeta.sword.damage
		end
	end

	return strength
end

local function getPlacedBlock(pos)
	if not pos then
		return
	end
	local roundedPosition = bedwars.BlockController:getBlockPosition(pos)
	return bedwars.BlockController:getStore():getBlockAt(roundedPosition), roundedPosition
end

local function getBlocksInPoints(s, e)
	local blocks, list = bedwars.BlockController:getStore(), {}
	for x = s.X, e.X do
		for y = s.Y, e.Y do
			for z = s.Z, e.Z do
				local vec = Vector3.new(x, y, z)
				if blocks:getBlockAt(vec) then
					table.insert(list, vec * 3)
				end
			end
		end
	end
	return list
end

local function getNearGround(range)
	range = Vector3.new(3, 3, 3) * (range or 10)
	local localPosition, mag, closest = entitylib.character.RootPart.Position, 60
	local blocks = getBlocksInPoints(bedwars.BlockController:getBlockPosition(localPosition - range), bedwars.BlockController:getBlockPosition(localPosition + range))

	for _, v in blocks do
		if not getPlacedBlock(v + Vector3.new(0, 3, 0)) then
			local newmag = (localPosition - v).Magnitude
			if newmag < mag then
				mag, closest = newmag, v + Vector3.new(0, 3, 0)
			end
		end
	end

	table.clear(blocks)
	return closest
end

local function getShieldAttribute(char)
	local returned = 0
	for name, val in char:GetAttributes() do
		if name:find('Shield') and type(val) == 'number' and val > 0 then
			returned += val
		end
	end
	return returned
end

local function getSpeed()
	local multi, increase, modifiers = 0, true, bedwars.SprintController:getMovementStatusModifier():getModifiers()

	for v in modifiers do
		local val = v.constantSpeedMultiplier and v.constantSpeedMultiplier or 0
		if val and val > math.max(multi, 1) then
			increase = false
			multi = val - (0.06 * math.round(val))
		end
	end

	for v in modifiers do
		multi += math.max((v.moveSpeedMultiplier or 0) - 1, 0)
	end

	if multi > 0 and increase then
		multi += 0.16 + (0.02 * math.round(multi))
	end

	return 20 * (multi + 1)
end

local function getTableSize(tab)
	local ind = 0
	for _ in tab do
		ind += 1
	end
	return ind
end

local function hotbarSwitch(slot)
	if slot and store.inventory.hotbarSlot ~= slot then
		bedwars.Store:dispatch({
			type = 'InventorySelectHotbarSlot',
			slot = slot
		})
		vapeEvents.InventoryChanged.Event:Wait()
		return true
	end
	return false
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

local function notif(...) return
	vape:CreateNotification(...)
end

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
end

local function roundPos(vec)
	return Vector3.new(math.round(vec.X / 3) * 3, math.round(vec.Y / 3) * 3, math.round(vec.Z / 3) * 3)
end

local function switchItem(tool, delayTime)
	delayTime = delayTime or 0.05
	local check = lplr.Character and lplr.Character:FindFirstChild('HandInvItem') or nil
	if check and check.Value ~= tool and tool.Parent ~= nil then
		task.spawn(function()
			bedwars.Client:Get(remotes.EquipItem):CallServerAsync({hand = tool})
		end)
		check.Value = tool
		if delayTime > 0 then
			task.wait(delayTime)
		end
		return true
	end
end

local function waitForChildOfType(obj, name, timeout, prop)
	local check, returned = tick() + timeout
	repeat
		returned = prop and obj[name] or obj:FindFirstChildOfClass(name)
		if returned and returned.Name ~= 'UpperTorso' or check < tick() then
			break
		end
		task.wait()
	until false
	return returned
end

local frictionTable, oldfrict = {}, {}
local frictionConnection
local frictionState

local function modifyVelocity(v)
	if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
		oldfrict[v] = v.CustomPhysicalProperties or 'none'
		v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
	end
end

local function updateVelocity(force)
	local newState = getTableSize(frictionTable) > 0
	if frictionState ~= newState or force then
		if frictionConnection then
			frictionConnection:Disconnect()
		end
		if newState then
			if entitylib.isAlive then
				for _, v in entitylib.character.Character:GetDescendants() do
					modifyVelocity(v)
				end
				frictionConnection = entitylib.character.Character.DescendantAdded:Connect(modifyVelocity)
			end
		else
			for i, v in oldfrict do
				i.CustomPhysicalProperties = v ~= 'none' and v or nil
			end
			table.clear(oldfrict)
		end
	end
	frictionState = newState
end

local kitorder = {
	hannah = 5,
	spirit_assassin = 4,
	dasher = 3,
	jade = 2,
	regent = 1
}

local sortmethods = {
	Damage = function(a, b)
		return a.Entity.Character:GetAttribute('LastDamageTakenTime') < b.Entity.Character:GetAttribute('LastDamageTakenTime')
	end,
	Threat = function(a, b)
		return getStrength(a.Entity) > getStrength(b.Entity)
	end,
	Kit = function(a, b)
		return (a.Entity.Player and kitorder[a.Entity.Player:GetAttribute('PlayingAsKit')] or 0) > (b.Entity.Player and kitorder[b.Entity.Player:GetAttribute('PlayingAsKit')] or 0)
	end,
	Health = function(a, b)
		return a.Entity.Health < b.Entity.Health
	end,
	Angle = function(a, b)
		local selfrootpos = entitylib.character.RootPart.Position
		local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
		local angle = math.acos(localfacing:Dot(((a.Entity.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)).Unit))
		local angle2 = math.acos(localfacing:Dot(((b.Entity.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)).Unit))
		return angle < angle2
	end
}

run(function()
	local oldstart = entitylib.start
	local function customEntity(ent)
		if ent:HasTag('inventory-entity') and not ent:HasTag('Monster') then
			return
		end

		entitylib.addEntity(ent, nil, ent:HasTag('Drone') and function(self)
			local droneplr = playersService:GetPlayerByUserId(self.Character:GetAttribute('PlayerUserId'))
			return not droneplr or lplr:GetAttribute('Team') ~= droneplr:GetAttribute('Team')
		end or function(self)
			return lplr:GetAttribute('Team') ~= self.Character:GetAttribute('Team')
		end)
	end

	entitylib.start = function()
		oldstart()
		if entitylib.Running then
			for _, ent in collectionService:GetTagged('entity') do
				customEntity(ent)
			end
			table.insert(entitylib.Connections, collectionService:GetInstanceAddedSignal('entity'):Connect(customEntity))
			table.insert(entitylib.Connections, collectionService:GetInstanceRemovedSignal('entity'):Connect(function(ent)
				entitylib.removeEntity(ent)
			end))
		end
	end

	entitylib.addPlayer = function(plr)
		if plr.Character then
			entitylib.refreshEntity(plr.Character, plr)
		end
		entitylib.PlayerConnections[plr] = {
			plr.CharacterAdded:Connect(function(char)
				entitylib.refreshEntity(char, plr)
			end),
			plr.CharacterRemoving:Connect(function(char)
				entitylib.removeEntity(char, plr == lplr)
			end),
			plr:GetAttributeChangedSignal('Team'):Connect(function()
				for _, v in entitylib.List do
					if v.Targetable ~= entitylib.targetCheck(v) then
						entitylib.refreshEntity(v.Character, v.Player)
					end
				end

				if plr == lplr then
					entitylib.start()
				else
					entitylib.refreshEntity(plr.Character, plr)
				end
			end)
		}
	end

	entitylib.addEntity = function(char, plr, teamfunc)
		if not char then return end
		entitylib.EntityThreads[char] = task.spawn(function()
			local hum, humrootpart, head
			if plr then
				hum = waitForChildOfType(char, 'Humanoid', 10)
				humrootpart = hum and waitForChildOfType(hum, 'RootPart', workspace.StreamingEnabled and 9e9 or 10, true)
				head = char:WaitForChild('Head', 10) or humrootpart
			else
				hum = {HipHeight = 0.5}
				humrootpart = waitForChildOfType(char, 'PrimaryPart', 10, true)
				head = humrootpart
			end
			local updateobjects = plr and plr ~= lplr and {
				char:WaitForChild('ArmorInvItem_0', 5),
				char:WaitForChild('ArmorInvItem_1', 5),
				char:WaitForChild('ArmorInvItem_2', 5),
				char:WaitForChild('HandInvItem', 5)
			} or {}

			if hum and humrootpart then
				local entity = {
					Connections = {},
					Character = char,
					Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char),
					Head = head,
					Humanoid = hum,
					HumanoidRootPart = humrootpart,
					HipHeight = hum.HipHeight + (humrootpart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
					Jumps = 0,
					JumpTick = tick(),
					Jumping = false,
					LandTick = tick(),
					MaxHealth = char:GetAttribute('MaxHealth') or 100,
					NPC = plr == nil,
					Player = plr,
					RootPart = humrootpart,
					TeamCheck = teamfunc
				}

				if plr == lplr then
					entity.AirTime = tick()
					entitylib.character = entity
					entitylib.isAlive = true
					entitylib.Events.LocalAdded:Fire(entity)
					table.insert(entitylib.Connections, char.AttributeChanged:Connect(function(attr)
						vapeEvents.AttributeChanged:Fire(attr)
					end))
				else
					entity.Targetable = entitylib.targetCheck(entity)

					for _, v in entitylib.getUpdateConnections(entity) do
						table.insert(entity.Connections, v:Connect(function()
							entity.Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char)
							entity.MaxHealth = char:GetAttribute('MaxHealth') or 100
							entitylib.Events.EntityUpdated:Fire(entity)
						end))
					end

					for _, v in updateobjects do
						table.insert(entity.Connections, v:GetPropertyChangedSignal('Value'):Connect(function()
							task.delay(0.1, function()
								if bedwars.getInventory then
									store.inventories[plr] = bedwars.getInventory(plr)
									entitylib.Events.EntityUpdated:Fire(entity)
								end
							end)
						end))
					end

					if plr then
						local anim = char:FindFirstChild('Animate')
						if anim then
							pcall(function()
								anim = anim.jump:FindFirstChildWhichIsA('Animation').AnimationId
								table.insert(entity.Connections, hum.Animator.AnimationPlayed:Connect(function(playedanim)
									if playedanim.Animation.AnimationId == anim then
										entity.JumpTick = tick()
										entity.Jumps += 1
										entity.LandTick = tick() + 1
										entity.Jumping = entity.Jumps > 1
									end
								end))
							end)
						end

						task.delay(0.1, function()
							if bedwars.getInventory then
								store.inventories[plr] = bedwars.getInventory(plr)
							end
						end)
					end
					table.insert(entitylib.List, entity)
					entitylib.Events.EntityAdded:Fire(entity)
				end

				table.insert(entity.Connections, char.ChildRemoved:Connect(function(part)
					if part == humrootpart or part == hum or part == head then
						if part == humrootpart and hum.RootPart then
							humrootpart = hum.RootPart
							entity.RootPart = hum.RootPart
							entity.HumanoidRootPart = hum.RootPart
							return
						end
						entitylib.removeEntity(char, plr == lplr)
					end
				end))
			end
			entitylib.EntityThreads[char] = nil
		end)
	end

	entitylib.getUpdateConnections = function(ent)
		local char = ent.Character
		local tab = {
			char:GetAttributeChangedSignal('Health'),
			char:GetAttributeChangedSignal('MaxHealth'),
			{
				Connect = function()
					ent.Friend = ent.Player and isFriend(ent.Player) or nil
					ent.Target = ent.Player and isTarget(ent.Player) or nil
					return {Disconnect = function() end}
				end
			}
		}

		if ent.Player then
			table.insert(tab, ent.Player:GetAttributeChangedSignal('PlayingAsKit'))
		end

		for name, val in char:GetAttributes() do
			if name:find('Shield') and type(val) == 'number' then
				table.insert(tab, char:GetAttributeChangedSignal(name))
			end
		end

		return tab
	end

	entitylib.targetCheck = function(ent)
		if ent.TeamCheck then
			return ent:TeamCheck()
		end
		if ent.NPC then return true end
		if isFriend(ent.Player) then return false end
		if not select(2, whitelist:get(ent.Player)) then return false end
		return lplr:GetAttribute('Team') ~= ent.Player:GetAttribute('Team')
	end
	vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
end)
entitylib.start()

run(function()
	local KnitInit, Knit
	repeat
		KnitInit, Knit = pcall(function()
			return debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 9)
		end)
		if KnitInit then break end
		task.wait()
	until KnitInit

	if not debug.getupvalue(Knit.Start, 1) then
		repeat task.wait() until debug.getupvalue(Knit.Start, 1)
	end

	local Flamework = require(replicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out).Flamework
	local InventoryUtil = require(replicatedStorage.TS.inventory['inventory-util']).InventoryUtil
	local Client = require(replicatedStorage.TS.remotes).default.Client
	local OldGet, OldBreak = Client.Get

	bedwars = setmetatable({
		AbilityController = Flamework.resolveDependency('@easy-games/game-core:client/controllers/ability/ability-controller@AbilityController'),
		AnimationType = require(replicatedStorage.TS.animation['animation-type']).AnimationType,
		AnimationUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out['shared'].util['animation-util']).AnimationUtil,
		AppController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.controllers['app-controller']).AppController,
		BedBreakEffectMeta = require(replicatedStorage.TS.locker['bed-break-effect']['bed-break-effect-meta']).BedBreakEffectMeta,
		BedwarsKitMeta = require(replicatedStorage.TS.games.bedwars.kit['bedwars-kit-meta']).BedwarsKitMeta,
		BlockBreaker = Knit.Controllers.BlockBreakController.blockBreaker,
		BlockController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out).BlockEngine,
		BlockEngine = require(lplr.PlayerScripts.TS.lib['block-engine']['client-block-engine']).ClientBlockEngine,
		BlockPlacer = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.client.placement['block-placer']).BlockPlacer,
		BowConstantsTable = debug.getupvalue(Knit.Controllers.ProjectileController.enableBeam, 8),
		ClickHold = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.ui.lib.util['click-hold']).ClickHold,
		Client = Client,
		ClientConstructor = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts'].net.out.client),
		ClientDamageBlock = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.shared.remotes).BlockEngineRemotes.Client,
		CombatConstant = require(replicatedStorage.TS.combat['combat-constant']).CombatConstant,
		DamageIndicator = Knit.Controllers.DamageIndicatorController.spawnDamageIndicator,
		DefaultKillEffect = require(lplr.PlayerScripts.TS.controllers.global.locker['kill-effect'].effects['default-kill-effect']),
		EmoteType = require(replicatedStorage.TS.locker.emote['emote-type']).EmoteType,
		GameAnimationUtil = require(replicatedStorage.TS.animation['animation-util']).GameAnimationUtil,
		getIcon = function(item, showinv)
			local itemmeta = bedwars.ItemMeta[item.itemType]
			return itemmeta and showinv and itemmeta.image or ''
		end,
		getInventory = function(plr)
			local suc, res = pcall(function()
				return InventoryUtil.getInventory(plr)
			end)
			return suc and res or {
				items = {},
				armor = {}
			}
		end,
		HudAliveCount = require(lplr.PlayerScripts.TS.controllers.global['top-bar'].ui.game['hud-alive-player-counts']).HudAlivePlayerCounts,
		ItemMeta = debug.getupvalue(require(replicatedStorage.TS.item['item-meta']).getItemMeta, 1),
		KillEffectMeta = require(replicatedStorage.TS.locker['kill-effect']['kill-effect-meta']).KillEffectMeta,
		KillFeedController = Flamework.resolveDependency('client/controllers/game/kill-feed/kill-feed-controller@KillFeedController'),
		Knit = Knit,
		KnockbackUtil = require(replicatedStorage.TS.damage['knockback-util']).KnockbackUtil,
		MageKitUtil = require(replicatedStorage.TS.games.bedwars.kit.kits.mage['mage-kit-util']).MageKitUtil,
		NametagController = Knit.Controllers.NametagController,
		PartyController = Flamework.resolveDependency('@easy-games/lobby:client/controllers/party-controller@PartyController'),
		ProjectileMeta = require(replicatedStorage.TS.projectile['projectile-meta']).ProjectileMeta,
		QueryUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).GameQueryUtil,
		QueueCard = require(lplr.PlayerScripts.TS.controllers.global.queue.ui['queue-card']).QueueCard,
		QueueMeta = require(replicatedStorage.TS.game['queue-meta']).QueueMeta,
		Roact = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts']['roact'].src),
		RuntimeLib = require(replicatedStorage['rbxts_include'].RuntimeLib),
		SoundList = require(replicatedStorage.TS.sound['game-sound']).GameSound,
		SoundManager = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).SoundManager,
		Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore,
		TeamUpgradeMeta = debug.getupvalue(require(replicatedStorage.TS.games.bedwars['team-upgrade']['team-upgrade-meta']).getTeamUpgradeMetaForQueue, 6),
		UILayers = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).UILayers,
		VisualizerUtils = require(lplr.PlayerScripts.TS.lib.visualizer['visualizer-utils']).VisualizerUtils,
		WeldTable = require(replicatedStorage.TS.util['weld-util']).WeldUtil,
		WinEffectMeta = require(replicatedStorage.TS.locker['win-effect']['win-effect-meta']).WinEffectMeta,
		ZapNetworking = require(lplr.PlayerScripts.TS.lib.network)
	}, {
		__index = function(self, ind)
			rawset(self, ind, Knit.Controllers[ind])
			return rawget(self, ind)
		end
	})

	local remoteNames = {
		AfkStatus = debug.getproto(Knit.Controllers.AfkController.KnitStart, 1),
		AttackEntity = Knit.Controllers.SwordController.sendServerRequest,
		BeePickup = Knit.Controllers.BeeNetController.trigger,
		CannonAim = debug.getproto(Knit.Controllers.CannonController.startAiming, 5),
		CannonLaunch = Knit.Controllers.CannonHandController.launchSelf,
		ConsumeBattery = debug.getproto(Knit.Controllers.BatteryController.onKitLocalActivated, 1),
		ConsumeItem = debug.getproto(Knit.Controllers.ConsumeController.onEnable, 1),
		ConsumeSoul = Knit.Controllers.GrimReaperController.consumeSoul,
		ConsumeTreeOrb = debug.getproto(Knit.Controllers.EldertreeController.createTreeOrbInteraction, 1),
		DepositPinata = debug.getproto(debug.getproto(Knit.Controllers.PiggyBankController.KnitStart, 2), 5),
		DragonBreath = debug.getproto(Knit.Controllers.VoidDragonController.onKitLocalActivated, 5),
		DragonEndFly = debug.getproto(Knit.Controllers.VoidDragonController.flapWings, 1),
		DragonFly = Knit.Controllers.VoidDragonController.flapWings,
		DropItem = Knit.Controllers.ItemDropController.dropItemInHand,
		EquipItem = debug.getproto(require(replicatedStorage.TS.entity.entities['inventory-entity']).InventoryEntity.equipItem, 4),
		FireProjectile = debug.getupvalue(Knit.Controllers.ProjectileController.launchProjectileWithValues, 2),
		GroundHit = Knit.Controllers.FallDamageController.KnitStart,
		GuitarHeal = Knit.Controllers.GuitarController.performHeal,
		HannahKill = debug.getproto(Knit.Controllers.HannahController.registerExecuteInteractions, 1),
		HarvestCrop = debug.getproto(debug.getproto(Knit.Controllers.CropController.KnitStart, 4), 1),
		KaliyahPunch = debug.getproto(Knit.Controllers.DragonSlayerController.onKitLocalActivated, 1),
		MageSelect = debug.getproto(Knit.Controllers.MageController.registerTomeInteraction, 1),
		MinerDig = debug.getproto(Knit.Controllers.MinerController.setupMinerPrompts, 1),
		PickupItem = Knit.Controllers.ItemDropController.checkForPickup,
		PickupMetal = debug.getproto(Knit.Controllers.HiddenMetalController.onKitLocalActivated, 4),
		ReportPlayer = require(lplr.PlayerScripts.TS.controllers.global.report['report-controller']).default.reportPlayer,
		ResetCharacter = debug.getproto(Knit.Controllers.ResetController.createBindable, 1),
		SpawnRaven = debug.getproto(Knit.Controllers.RavenController.KnitStart, 1),
		SummonerClawAttack = Knit.Controllers.SummonerClawHandController.attack,
		WarlockTarget = debug.getproto(Knit.Controllers.WarlockStaffController.KnitStart, 2)
	}

	local function dumpRemote(tab)
		local ind
		for i, v in tab do
			if v == 'Client' then
				ind = i
				break
			end
		end
		return ind and tab[ind + 1] or ''
	end

	for i, v in remoteNames do
		local remote = dumpRemote(debug.getconstants(v))
		if remote == '' then
			notif('Vape', 'Failed to grab remote ('..i..')', 10, 'alert')
		end
		remotes[i] = remote
	end

	OldBreak = bedwars.BlockController.isBlockBreakable

	Client.Get = function(self, remoteName)
		local call = OldGet(self, remoteName)

		if remoteName == remotes.AttackEntity then
			return {
				instance = call.instance,
				SendToServer = function(_, attackTable, ...)
					local suc, plr = pcall(function()
						return playersService:GetPlayerFromCharacter(attackTable.entityInstance)
					end)

					local selfpos = attackTable.validate.selfPosition.value
					local targetpos = attackTable.validate.targetPosition.value
					store.attackReach = ((selfpos - targetpos).Magnitude * 100) // 1 / 100
					store.attackReachUpdate = tick() + 1

					if Reach.Enabled or HitBoxes.Enabled then
						attackTable.validate.raycast = attackTable.validate.raycast or {}
						attackTable.validate.selfPosition.value += CFrame.lookAt(selfpos, targetpos).LookVector * math.max((selfpos - targetpos).Magnitude - 14.399, 0)
					end

					if suc and plr then
						if not select(2, whitelist:get(plr)) then return end
					end

					return call:SendToServer(attackTable, ...)
				end
			}
		elseif remoteName == 'StepOnSnapTrap' and TrapDisabler.Enabled then
			return {SendToServer = function() end}
		end

		return call
	end

	bedwars.BlockController.isBlockBreakable = function(self, breakTable, plr)
		local obj = bedwars.BlockController:getStore():getBlockAt(breakTable.blockPosition)

		if obj and obj.Name == 'bed' then
			for _, plr in playersService:GetPlayers() do
				if obj:GetAttribute('Team'..(plr:GetAttribute('Team') or 0)..'NoBreak') and not select(2, whitelist:get(plr)) then
					return false
				end
			end
		end

		return OldBreak(self, breakTable, plr)
	end

	local cache, blockhealthbar = {}, {blockHealth = -1, breakingBlockPosition = Vector3.zero}
	store.blockPlacer = bedwars.BlockPlacer.new(bedwars.BlockEngine, 'wool_white')

	local function getBlockHealth(block, blockpos)
		local blockdata = bedwars.BlockController:getStore():getBlockData(blockpos)
		return (blockdata and (blockdata:GetAttribute('1') or blockdata:GetAttribute('Health')) or block:GetAttribute('Health'))
	end

	local function getBlockHits(block, blockpos)
		if not block then return 0 end
		local breaktype = bedwars.ItemMeta[block.Name].block.breakType
		local tool = store.tools[breaktype]
		tool = tool and bedwars.ItemMeta[tool.itemType].breakBlock[breaktype] or 2
		return getBlockHealth(block, bedwars.BlockController:getBlockPosition(blockpos)) / tool
	end

	--[[
		Pathfinding using a luau version of dijkstra's algorithm
		Source: https://stackoverflow.com/questions/39355587/speeding-up-dijkstras-algorithm-to-solve-a-3d-maze
	]]
	local function calculatePath(target, blockpos)
		if cache[blockpos] then
			return unpack(cache[blockpos])
		end
		local visited, unvisited, distances, air, path = {}, {{0, blockpos}}, {[blockpos] = 0}, {}, {}

		for _ = 1, 10000 do
			local _, node = next(unvisited)
			if not node then break end
			table.remove(unvisited, 1)
			visited[node[2]] = true

			for _, side in sides do
				side = node[2] + side
				if visited[side] then continue end

				local block = getPlacedBlock(side)
				if not block or block:GetAttribute('NoBreak') or block == target then
					if not block then
						air[node[2]] = true
					end
					continue
				end

				local curdist = getBlockHits(block, side) + node[1]
				if curdist < (distances[side] or math.huge) then
					table.insert(unvisited, {curdist, side})
					distances[side] = curdist
					path[side] = node[2]
				end
			end
		end

		local pos, cost = nil, math.huge
		for node in air do
			if distances[node] < cost then
				pos, cost = node, distances[node]
			end
		end

		if pos then
			cache[blockpos] = {
				pos,
				cost,
				path
			}
			return pos, cost, path
		end
	end

	bedwars.placeBlock = function(pos, item)
		if getItem(item) then
			store.blockPlacer.blockType = item
			return store.blockPlacer:placeBlock(bedwars.BlockController:getBlockPosition(pos))
		end
	end

	bedwars.breakBlock = function(block, effects, anim, customHealthbar)
		if lplr:GetAttribute('DenyBlockBreak') or not entitylib.isAlive or InfiniteFly.Enabled then return end
		local handler = bedwars.BlockController:getHandlerRegistry():getHandler(block.Name)
		local cost, pos, target, path = math.huge

		for _, v in (handler and handler:getContainedPositions(block) or {block.Position / 3}) do
			local dpos, dcost, dpath = calculatePath(block, v * 3)
			if dpos and dcost < cost then
				cost, pos, target, path = dcost, dpos, v * 3, dpath
			end
		end

		if pos then
			if (entitylib.character.RootPart.Position - pos).Magnitude > 30 then return end
			local dblock, dpos = getPlacedBlock(pos)
			if not dblock then return end

			if (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 0.4 then
				local breaktype = bedwars.ItemMeta[dblock.Name].block.breakType
				local tool = store.tools[breaktype]
				if tool then
					switchItem(tool.tool)
				end
			end

			if blockhealthbar.blockHealth == -1 or dpos ~= blockhealthbar.breakingBlockPosition then
				blockhealthbar.blockHealth = getBlockHealth(dblock, dpos)
				blockhealthbar.breakingBlockPosition = dpos
			end

			bedwars.ClientDamageBlock:Get('DamageBlock'):CallServerAsync({
				blockRef = {blockPosition = dpos},
				hitPosition = pos,
				hitNormal = Vector3.FromNormalId(Enum.NormalId.Top)
			}):andThen(function(result)
				if result then
					if result == 'cancelled' then
						store.damageBlockFail = tick() + 1
						return
					end

					if effects then
						local blockdmg = (blockhealthbar.blockHealth - (result == 'destroyed' and 0 or getBlockHealth(dblock, dpos)))
						customHealthbar = customHealthbar or bedwars.BlockBreaker.updateHealthbar
						customHealthbar(bedwars.BlockBreaker, {blockPosition = dpos}, blockhealthbar.blockHealth, dblock:GetAttribute('MaxHealth'), blockdmg, dblock)
						blockhealthbar.blockHealth = math.max(blockhealthbar.blockHealth - blockdmg, 0)

						if blockhealthbar.blockHealth <= 0 then
							bedwars.BlockBreaker.breakEffect:playBreak(dblock.Name, dpos, lplr)
							bedwars.BlockBreaker.healthbarMaid:DoCleaning()
							blockhealthbar.breakingBlockPosition = Vector3.zero
						else
							bedwars.BlockBreaker.breakEffect:playHit(dblock.Name, dpos, lplr)
						end
					end

					if anim then
						local animation = bedwars.AnimationUtil:playAnimation(lplr, bedwars.BlockController:getAnimationController():getAssetId(1))
						bedwars.ViewmodelController:playAnimation(15)
						task.wait(0.3)
						animation:Stop()
						animation:Destroy()
					end
				end
			end)

			if effects then
				return pos, path, target
			end
		end
	end

	for _, v in Enum.NormalId:GetEnumItems() do
		table.insert(sides, Vector3.FromNormalId(v) * 3)
	end

	local function updateStore(new, old)
		if new.Bedwars ~= old.Bedwars then
			store.equippedKit = new.Bedwars.kit ~= 'none' and new.Bedwars.kit or ''
		end

		if new.Game ~= old.Game then
			store.matchState = new.Game.matchState
			store.queueType = new.Game.queueType or 'bedwars_test'
		end

		if new.Inventory ~= old.Inventory then
			local newinv = (new.Inventory and new.Inventory.observedInventory or {inventory = {}})
			local oldinv = (old.Inventory and old.Inventory.observedInventory or {inventory = {}})
			store.inventory = newinv

			if newinv ~= oldinv then
				vapeEvents.InventoryChanged:Fire()
			end

			if newinv.inventory.items ~= oldinv.inventory.items then
				vapeEvents.InventoryAmountChanged:Fire()
				store.tools.sword = getSword()
				for _, v in {'stone', 'wood', 'wool'} do
					store.tools[v] = getTool(v)
				end
			end

			if newinv.inventory.hand ~= oldinv.inventory.hand then
				local currentHand, toolType = new.Inventory.observedInventory.inventory.hand, ''
				if currentHand then
					local handData = bedwars.ItemMeta[currentHand.itemType]
					toolType = handData.sword and 'sword' or handData.block and 'block' or currentHand.itemType:find('bow') and 'bow'
				end

				store.hand = {
					tool = currentHand and currentHand.tool,
					amount = currentHand and currentHand.amount or 0,
					toolType = toolType
				}
			end
		end
	end

	local storeChanged = bedwars.Store.changed:connect(updateStore)
	updateStore(bedwars.Store:getState(), {})

	for _, event in {'MatchEndEvent', 'EntityDeathEvent', 'BedwarsBedBreak', 'BalloonPopped', 'AngelProgress', 'GrapplingHookFunctions'} do
		if not vape.Connections then return end
		bedwars.Client:WaitFor(event):andThen(function(connection)
			vape:Clean(connection:Connect(function(...)
				vapeEvents[event]:Fire(...)
			end))
		end)
	end

	vape:Clean(bedwars.ZapNetworking.EntityDamageEventZap.On(function(...)
		vapeEvents.EntityDamageEvent:Fire({
			entityInstance = ...,
			damage = select(2, ...),
			damageType = select(3, ...),
			fromPosition = select(4, ...),
			fromEntity = select(5, ...),
			knockbackMultiplier = select(6, ...),
			knockbackId = select(7, ...),
			disableDamageHighlight = select(13, ...)
		})
	end))

	for _, event in {'PlaceBlockEvent', 'BreakBlockEvent'} do
		vape:Clean(bedwars.ZapNetworking[event..'Zap'].On(function(...)
			local data = {
				blockRef = {
					blockPosition = ...,
				},
				player = select(5, ...)
			}
			for i, v in cache do
				if ((data.blockRef.blockPosition * 3) - v[1]).Magnitude <= 30 then
					table.clear(v[3])
					table.clear(v)
					cache[i] = nil
				end
			end
			vapeEvents[event]:Fire(data)
		end))
	end

	store.blocks = collection('block', gui)
	store.shop = collection({'BedwarsItemShop', 'TeamUpgradeShopkeeper'}, gui, function(tab, obj)
		table.insert(tab, {
			Id = obj.Name,
			RootPart = obj,
			Shop = obj:HasTag('BedwarsItemShop'),
			Upgrades = obj:HasTag('TeamUpgradeShopkeeper')
		})
	end)
	store.enchant = collection({'enchant-table', 'broken-enchant-table'}, gui, nil, function(tab, obj, tag)
		if obj:HasTag('enchant-table') and tag == 'broken-enchant-table' then return end
		obj = table.find(tab, obj)
		if obj then
			table.remove(tab, obj)
		end
	end)

	local kills = sessioninfo:AddItem('Kills')
	local beds = sessioninfo:AddItem('Beds')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')

	local mapname = 'Unknown'
	sessioninfo:AddItem('Map', 0, function()
		return mapname
	end, false)

	task.delay(1, function()
		games:Increment()
	end)

	task.spawn(function()
		pcall(function()
			repeat task.wait() until store.matchState ~= 0 or vape.Loaded == nil
			if vape.Loaded == nil then return end
			mapname = workspace:WaitForChild('Map', 5):WaitForChild('Worlds', 5):GetChildren()[1].Name
			mapname = string.gsub(string.split(mapname, '_')[2] or mapname, '-', '') or 'Blank'
		end)
	end)

	vape:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
		if bedTable.player and bedTable.player.UserId == lplr.UserId then
			beds:Increment()
		end
	end))

	vape:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winTable)
		if (bedwars.Store:getState().Game.myTeam or {}).id == winTable.winningTeamId or lplr.Neutral then
			wins:Increment()
		end
	end))

	vape:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
		local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
		local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
		if not killed or not killer then return end

		if killed ~= lplr and killer == lplr then
			kills:Increment()
		end
	end))

	task.spawn(function()
		repeat
			if entitylib.isAlive then
				entitylib.character.AirTime = entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air and tick() or entitylib.character.AirTime
			end

			for _, v in entitylib.List do
				v.LandTick = math.abs(v.RootPart.Velocity.Y) < 0.1 and v.LandTick or tick()
				if (tick() - v.LandTick) > 0.2 and v.Jumps ~= 0 then
					v.Jumps = 0
					v.Jumping = false
				end
			end
			task.wait()
		until vape.Loaded == nil
	end)

	pcall(function()
		if getthreadidentity and setthreadidentity then
			local old = getthreadidentity()
			setthreadidentity(2)

			bedwars.Shop = require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
			bedwars.ShopItems = debug.getupvalue(debug.getupvalue(bedwars.Shop.getShopItem, 1), 2)
			bedwars.Shop.getShopItem('iron_sword', lplr)

			setthreadidentity(old)
			store.shopLoaded = true
		else
			task.spawn(function()
				repeat
					task.wait(0.1)
				until vape.Loaded == nil or bedwars.AppController:isAppOpen('BedwarsItemShopApp')

				bedwars.Shop = require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
				bedwars.ShopItems = debug.getupvalue(debug.getupvalue(bedwars.Shop.getShopItem, 1), 2)
				store.shopLoaded = true
			end)
		end
	end)

	vape:Clean(function()
		Client.Get = OldGet
		bedwars.BlockController.isBlockBreakable = OldBreak
		store.blockPlacer:disable()
		for _, v in vapeEvents do
			v:Destroy()
		end
		for _, v in cache do
			table.clear(v[3])
			table.clear(v)
		end
		table.clear(store.blockPlacer)
		table.clear(vapeEvents)
		table.clear(bedwars)
		table.clear(store)
		table.clear(cache)
		table.clear(sides)
		table.clear(remotes)
		storeChanged:disconnect()
		storeChanged = nil
	end)
end)

for _, v in {'AntiRagdoll', 'TriggerBot', 'SilentAim', 'AutoRejoin', 'Rejoin', 'Disabler', 'Timer', 'ServerHop', 'MouseTP', 'MurderMystery'} do
	vape:Remove(v)
end
run(function()
	local AimAssist
	local Targets
	local Sort
	local AimSpeed
	local Distance
	local AngleSlider
	local StrafeIncrease
	local KillauraTarget
	local ClickAim
	
	AimAssist = vape.Categories.Combat:CreateModule({
		Name = 'AimAssist',
		Function = function(callback)
			if callback then
				AimAssist:Clean(runService.Heartbeat:Connect(function(dt)
					if entitylib.isAlive and store.hand.toolType == 'sword' and ((not ClickAim.Enabled) or (tick() - bedwars.SwordController.lastSwing) < 0.4) then
						local ent = not KillauraTarget.Enabled and entitylib.EntityPosition({
							Range = Distance.Value,
							Part = 'RootPart',
							Wallcheck = Targets.Walls.Enabled,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Sort = sortmethods[Sort.Value]
						}) or store.KillauraTarget
	
						if ent then
							local delta = (ent.RootPart.Position - entitylib.character.RootPart.Position)
							local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
							local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
							if angle >= (math.rad(AngleSlider.Value) / 2) then return end
							targetinfo.Targets[ent] = tick() + 1
							gameCamera.CFrame = gameCamera.CFrame:Lerp(CFrame.lookAt(gameCamera.CFrame.p, ent.RootPart.Position), (AimSpeed.Value + (StrafeIncrease.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) and 10 or 0)) * dt)
						end
					end
				end))
			end
		end,
		Tooltip = 'Smoothly aims to closest valid target with sword'
	})
	Targets = AimAssist:CreateTargets({
		Players = true,
		Walls = true
	})
	local methods = {'Damage', 'Distance'}
	for i in sortmethods do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	Sort = AimAssist:CreateDropdown({
		Name = 'Target Mode',
		List = methods
	})
	AimSpeed = AimAssist:CreateSlider({
		Name = 'Aim Speed',
		Min = 5,
		Max = 40,
		Default = 8.407515
	})
	Distance = AimAssist:CreateSlider({
		Name = 'Distance',
		Min = 16,
		Max = 35,
		Default = 30,
		Suffx = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AngleSlider = AimAssist:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 360
	})
	ClickAim = AimAssist:CreateToggle({
		Name = 'Click Aim',
		Default = true
	})
	KillauraTarget = AimAssist:CreateToggle({
		Name = 'Use killaura target'
	})
	StrafeIncrease = AimAssist:CreateToggle({Name = 'Strafe increase'})
end)
	
run(function()
	local AutoClicker
	local CPS
	local BlockCPS = {}
	local Thread
	
	local function AutoClick()
		if Thread then
			task.cancel(Thread)
		end
	
		Thread = task.delay(1 / 7, function()
			repeat
				if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
					local blockPlacer = bedwars.BlockPlacementController.blockPlacer
					if store.hand.toolType == 'block' and blockPlacer then
						if (workspace:GetServerTimeNow() - bedwars.BlockCpsController.lastPlaceTimestamp) >= ((1 / 12) * 0.5) then
							local mouseinfo = blockPlacer.clientManager:getBlockSelector():getMouseInfo(0)
							if mouseinfo and mouseinfo.placementPosition == mouseinfo.placementPosition then
								task.spawn(blockPlacer.placeBlock, blockPlacer, mouseinfo.placementPosition)
							end
						end
					elseif store.hand.toolType == 'sword' then
						bedwars.SwordController:swingSwordAtMouse(0.39)
					end
				end
	
				task.wait(1 / (store.hand.toolType == 'block' and BlockCPS or CPS).GetRandomValue())
			until not AutoClicker.Enabled
		end)
	end
	
	AutoClicker = vape.Categories.Combat:CreateModule({
		Name = 'AutoClicker',
		Function = function(callback)
			if callback then
				AutoClicker:Clean(inputService.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						AutoClick()
					end
				end))
	
				AutoClicker:Clean(inputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 and Thread then
						task.cancel(Thread)
						Thread = nil
					end
				end))
	
				if inputService.TouchEnabled then
					pcall(function()
						AutoClicker:Clean(lplr.PlayerGui.MobileUI['2'].MouseButton1Down:Connect(AutoClick))
						AutoClicker:Clean(lplr.PlayerGui.MobileUI['2'].MouseButton1Up:Connect(function()
							if Thread then
								task.cancel(Thread)
								Thread = nil
							end
						end))
					end)
				end
			else
				if Thread then
					task.cancel(Thread)
					Thread = nil
				end
			end
		end,
		Tooltip = 'Hold attack button to automatically click'
	})
	CPS = AutoClicker:CreateTwoSlider({
		Name = 'CPS',
		Min = 6,
		Max = 9000000,
		DefaultMin = 10,
		DefaultMax = 15
	})
	AutoClicker:CreateToggle({
		Name = 'Place Blocks',
		Default = true,
		Function = function(callback)
			if BlockCPS.Object then
				BlockCPS.Object.Visible = callback
			end
		end
	})
	BlockCPS = AutoClicker:CreateTwoSlider({
		Name = 'Block CPS',
		Min = 1,
		Max = 12000000,
		DefaultMin = 12,
		DefaultMax = 12,
		Darker = true
	})
end)
	
run(function()
	local old
	
	vape.Categories.Combat:CreateModule({
		Name = 'NoClickDelay',
		Function = function(callback)
			if callback then
				old = bedwars.SwordController.isClickingTooFast
				bedwars.SwordController.isClickingTooFast = function(self)
					self.lastSwing = os.clock()
					return false
				end
			else
				bedwars.SwordController.isClickingTooFast = old
			end
		end,
		Tooltip = 'Remove the CPS cap'
	})
end)
	
run(function()
	local Value
	
	Reach = vape.Categories.Combat:CreateModule({
		Name = 'Reach',
		Function = function(callback)
			bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = callback and Value.Value + 2 or 14.4
		end,
		Tooltip = 'Extends attack reach'
	})
	Value = Reach:CreateSlider({
		Name = 'Range',
		Min = 0,
		Max = 28.563,
		Default = 28.563,
		Function = function(val)
			if Reach.Enabled then
				bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = val + 2
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)
	
run(function()
	local Sprint
	local old
	
	Sprint = vape.Categories.Combat:CreateModule({
		Name = 'Sprint',
		Function = function(callback)
			if callback then
				if inputService.TouchEnabled then 
					pcall(function() 
						lplr.PlayerGui.MobileUI['4'].Visible = false 
					end) 
				end
				old = bedwars.SprintController.stopSprinting
				bedwars.SprintController.stopSprinting = function(...)
					local call = old(...)
					bedwars.SprintController:startSprinting()
					return call
				end
				Sprint:Clean(entitylib.Events.LocalAdded:Connect(function() 
					task.delay(0.1, function() 
						bedwars.SprintController:stopSprinting() 
					end) 
				end))
				bedwars.SprintController:stopSprinting()
			else
				if inputService.TouchEnabled then 
					pcall(function() 
						lplr.PlayerGui.MobileUI['4'].Visible = true 
					end) 
				end
				bedwars.SprintController.stopSprinting = old
				bedwars.SprintController:stopSprinting()
			end
		end,
		Tooltip = 'Sets your sprinting to true.'
	})
end)

	
run(function()
	local Velocity
	local Horizontal
	local Vertical
	local Chance
	local TargetCheck
	local rand, old = Random.new()
	
	Velocity = vape.Categories.Combat:CreateModule({
		Name = 'Velocity',
		Function = function(callback)
			if callback then
				old = bedwars.KnockbackUtil.applyKnockback
				bedwars.KnockbackUtil.applyKnockback = function(root, mass, dir, knockback, ...)
					if rand:NextNumber(0, 100) > Chance.Value then return end
					local check = (not TargetCheck.Enabled) or entitylib.EntityPosition({
						Range = 50,
						Part = 'RootPart',
						Players = true
					})
	
					if check then
						knockback = knockback or {}
						if Horizontal.Value == 0 and Vertical.Value == 0 then return end
						knockback.horizontal = (knockback.horizontal or 1) * (Horizontal.Value / 100)
						knockback.vertical = (knockback.vertical or 1) * (Vertical.Value / 100)
					end
					
					return old(root, mass, dir, knockback, ...)
				end
			else
				bedwars.KnockbackUtil.applyKnockback = old
			end
		end,
		Tooltip = 'Reduces knockback taken'
	})
	Horizontal = Velocity:CreateSlider({
		Name = 'Horizontal',
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = '%'
	})
	Vertical = Velocity:CreateSlider({
		Name = 'Vertical',
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = '%'
	})
	Chance = Velocity:CreateSlider({
		Name = 'Chance',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
	TargetCheck = Velocity:CreateToggle({Name = 'Only when targeting'})
end)
	
local AntiFallDirection
run(function()
	local AntiFall
	local Mode
	local Material
	local Color
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true

	local function getLowGround()
		local mag = math.huge
		for _, pos in bedwars.BlockController:getStore():getAllBlockPositions() do
			pos = pos * 3
			if pos.Y < mag and not getPlacedBlock(pos + Vector3.new(0, 3, 0)) then
				mag = pos.Y
			end
		end
		return mag
	end

	AntiFall = vape.Categories.Blatant:CreateModule({
		Name = 'AntiFall',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.matchState ~= 0 or (not AntiFall.Enabled)
				if not AntiFall.Enabled then return end

				local pos, debounce = getLowGround(), tick()
				if pos ~= math.huge then
					AntiFallPart = Instance.new('Part')
					AntiFallPart.Size = Vector3.new(10000, 1, 10000)
					AntiFallPart.Transparency = 1 - Color.Opacity
					AntiFallPart.Material = Enum.Material[Material.Value]
					AntiFallPart.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
					AntiFallPart.Position = Vector3.new(0, pos - 2, 0)
					AntiFallPart.CanCollide = Mode.Value == 'Collide'
					AntiFallPart.Anchored = true
					AntiFallPart.CanQuery = false
					AntiFallPart.Parent = workspace
					AntiFall:Clean(AntiFallPart)
					AntiFall:Clean(AntiFallPart.Touched:Connect(function(touched)
						if touched.Parent == lplr.Character and entitylib.isAlive and debounce < tick() then
							debounce = tick() + 0.1
							if Mode.Value == 'Normal' then
								local top = getNearGround()
								if top then
									local lastTeleport = lplr:GetAttribute('LastTeleported')
									local connection
									connection = runService.PreSimulation:Connect(function()
										if vape.Modules.Fly.Enabled or (vape.Modules.InfiniteFly and vape.Modules.InfiniteFly).Enabled or vape.Modules.LongJump.Enabled then
											connection:Disconnect()
											AntiFallDirection = nil
											return
										end

										if entitylib.isAlive and lplr:GetAttribute('LastTeleported') == lastTeleport then
											local delta = ((top - entitylib.character.RootPart.Position) * Vector3.new(1, 0, 1))
											local root = entitylib.character.RootPart
											AntiFallDirection = delta.Unit == delta.Unit and delta.Unit or Vector3.zero
											root.Velocity *= Vector3.new(1, 0, 1)
											rayCheck.FilterDescendantsInstances = {gameCamera, lplr.Character}
											rayCheck.CollisionGroup = root.CollisionGroup

											local ray = workspace:Raycast(root.Position, AntiFallDirection, rayCheck)
											if ray then
												for _ = 1, 10 do
													local dpos = roundPos(ray.Position + ray.Normal * 1.5) + Vector3.new(0, 3, 0)
													if not getPlacedBlock(dpos) then
														top = Vector3.new(top.X, pos.Y, top.Z)
														break
													end
												end
											end

											root.CFrame += Vector3.new(0, top.Y - root.Position.Y, 0)
											if not frictionTable.Speed then
												root.AssemblyLinearVelocity = (AntiFallDirection * getSpeed()) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
											end

											if delta.Magnitude < 1 then
												connection:Disconnect()
												AntiFallDirection = nil
											end
										else
											connection:Disconnect()
											AntiFallDirection = nil
										end
									end)
									AntiFall:Clean(connection)
								end
							elseif Mode.Value == 'Velocity' then
								entitylib.character.RootPart.Velocity = Vector3.new(entitylib.character.RootPart.Velocity.X, 100, entitylib.character.RootPart.Velocity.Z)
							end
						end
					end))
				end
			else
				AntiFallDirection = nil
			end
		end,
		Tooltip = 'Help\'s you with your Parkinson\'s\nPrevents you from falling into the void.'
	})
	Mode = AntiFall:CreateDropdown({
		Name = 'Move Mode',
		List = {'Normal', 'Collide', 'Velocity'},
		Function = function(val)
			if AntiFallPart then
				AntiFallPart.CanCollide = val == 'Collide'
			end
		end,
	Tooltip = 'Normal - Smoothly moves you towards the nearest safe point\nVelocity - Launches you upward after touching\nCollide - Allows you to walk on the part'
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
		Function = function(val)
			if AntiFallPart then
				AntiFallPart.Material = Enum.Material[val]
			end
		end
	})
	Color = AntiFall:CreateColorSlider({
		Name = 'Color',
		DefaultOpacity = 0.5,
		Function = function(h, s, v, o)
			if AntiFallPart then
				AntiFallPart.Color = Color3.fromHSV(h, s, v)
				AntiFallPart.Transparency = 1 - o
			end
		end
	})
end)
	
run(function()
	local FastBreak
	local Time
	
	FastBreak = vape.Categories.Blatant:CreateModule({
		Name = 'FastBreak',
		Function = function(callback)
			if callback then
				repeat
					bedwars.BlockBreakController.blockBreaker:setCooldown(Time.Value)
					task.wait(0.1)
				until not FastBreak.Enabled
			else
				bedwars.BlockBreakController.blockBreaker:setCooldown(0.3)
			end
		end,
		Tooltip = 'Decreases block hit cooldown'
	})
	Time = FastBreak:CreateSlider({
		Name = 'Break speed',
		Min = 0,
		Max = 0.3,
		Default = 0.25,
		Decimal = 100,
		Suffix = 'seconds'
	})
end)
run(function()
    local Skybox
    GameThemeV2 = vape.Categories.Render:CreateModule({
        Name = 'Skybox',
        Tooltip = '',
        Function = function(call)
            if call then
                if Skybox.Value == "NebulaSky" then
					local Vignette = true

					local Lighting = game:GetService("Lighting")
					local ColorCor = Instance.new("ColorCorrectionEffect")
					local Sky = Instance.new("Sky")
					local Atm = Instance.new("Atmosphere")
					
					for i, v in pairs(Lighting:GetChildren()) do
						if v then
							v:Destroy()
						end
					end
					
					ColorCor.Parent = Lighting
					Sky.Parent = Lighting
					Atm.Parent = Lighting
					
					if Vignette == true then
						local Gui = Instance.new("ScreenGui")
						Gui.Parent = game:GetService("StarterGui")
						Gui.IgnoreGuiInset = true
					
						local ShadowFrame = Instance.new("ImageLabel")
						ShadowFrame.Parent = Gui
						ShadowFrame.AnchorPoint = Vector2.new(0, 1)
						ShadowFrame.Position = UDim2.new(0, 0, 0, 0)
						ShadowFrame.Size = UDim2.new(0, 0, 0, 0)
						ShadowFrame.BackgroundTransparency = 1
						ShadowFrame.Image = ""
						ShadowFrame.ImageTransparency = 1
						ShadowFrame.ZIndex = 0
					end
					
					ColorCor.Brightness = 0
					ColorCor.Contrast = 0.5
					ColorCor.Saturation = -0.3
					ColorCor.TintColor = Color3.fromRGB(255, 235, 203)
					
					Sky.SkyboxBk = "rbxassetid://13581437029"
					Sky.SkyboxDn = "rbxassetid://13581439832"
					Sky.SkyboxFt = "rbxassetid://13581447312"
					Sky.SkyboxLf = "rbxassetid://13581443463"
					Sky.SkyboxRt = "rbxassetid://13581452875"
					Sky.SkyboxUp = "rbxassetid://13581450222"
					Sky.SunAngularSize = 0
					
					Lighting.Ambient = Color3.fromRGB(2, 2, 2)
					Lighting.Brightness = 1
					Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
					Lighting.ColorShift_Top = Color3.fromRGB(0, 0, 0)
					Lighting.EnvironmentDiffuseScale = 0.2
					Lighting.EnvironmentSpecularScale = 0.2
					Lighting.GlobalShadows = true
					Lighting.OutdoorAmbient = Color3.fromRGB(0, 0, 0)
					Lighting.ShadowSoftness = 0.2
					Lighting.ClockTime = 8
					Lighting.GeographicLatitude = 45
					Lighting.ExposureCompensation = 0.5
					
					Atm.Density = 0.364
					Atm.Offset = 0.556
					Atm.Color = Color3.fromRGB(172, 120, 186)
					Atm.Decay = Color3.fromRGB(155, 212, 255)
					Atm.Glare = 0.36
					Atm.Haze = 1.72					
                elseif Skybox.Value == "PinkMountainSky" then
					game.Lighting.Sky.SkyboxBk = "http://www.roblox.com/asset/?id=160188495"
					game.Lighting.Sky.SkyboxDn = "http://www.roblox.com/asset/?id=160188614"
					game.Lighting.Sky.SkyboxFt = "http://www.roblox.com/asset/?id=160188609"
					game.Lighting.Sky.SkyboxLf = "http://www.roblox.com/asset/?id=160188589"
					game.Lighting.Sky.SkyboxRt = "http://www.roblox.com/asset/?id=160188597"
					game.Lighting.Sky.SkyboxUp = "http://www.roblox.com/asset/?id=160188588"
                elseif Skybox.Value == "CitySky" then

					local Vignette = true

					local Lighting = game:GetService("Lighting")
					local ColorCor = Instance.new("ColorCorrectionEffect")
					local Sky = Instance.new("Sky")
					local Atm = Instance.new("Atmosphere")

					game.Lighting.Sky.SkyboxBk = "rbxassetid://11263062161"
					game.Lighting.Sky.SkyboxDn = "rbxassetid://11263065295"
					game.Lighting.Sky.SkyboxFt = "rbxassetid://11263066644"
					game.Lighting.Sky.SkyboxLf = "rbxassetid://11263068413"
					game.Lighting.Sky.SkyboxRt = "rbxassetid://11263069782"
					game.Lighting.Sky.SkyboxUp = "rbxassetid://11263070890"

					Atm.Density = 0.364
					Atm.Offset = 0.556
					Atm.Color = Color3.fromRGB(172, 120, 186)
					Atm.Decay = Color3.fromRGB(155, 212, 255)
					Atm.Glare = 0.36
					Atm.Haze = 1.72		
                elseif Skybox.Value == "PinkSky" then
					game.Lighting.Sky.SkyboxBk = "http://www.roblox.com/asset/?id=271042516"
					game.Lighting.Sky.SkyboxDn = "http://www.roblox.com/asset/?id=271077243"
					game.Lighting.Sky.SkyboxFt = "http://www.roblox.com/asset/?id=271042556"
					game.Lighting.Sky.SkyboxLf = "http://www.roblox.com/asset/?id=271042310"
					game.Lighting.Sky.SkyboxRt = "http://www.roblox.com/asset/?id=271042467"
					game.Lighting.Sky.SkyboxUp = "http://www.roblox.com/asset/?id=271077958"
                elseif Skybox.Value == "EgirlSky" then
					game.Lighting.Sky.SkyboxBk = "rbxassetid://2128458653"
					game.Lighting.Sky.SkyboxDn = "rbxassetid://2128462480"
					game.Lighting.Sky.SkyboxFt = "rbxassetid://2128458653"
					game.Lighting.Sky.SkyboxLf = "rbxassetid://2128462027"
					game.Lighting.Sky.SkyboxRt = "rbxassetid://2128462027"
					game.Lighting.Sky.SkyboxUp = "rbxassetid://2128462236"
					game.Lighting.sky.SunAngularSize = 4
					game.Lighting.sky.MoonTextureId = "rbxassetid://8139665943"
					game.Lighting.sky.MoonAngularSize = 11
					lightingService.Atmosphere.Color = Color3.fromRGB(255, 214, 172)
					lightingService.Atmosphere.Decay = Color3.fromRGB(255, 202, 175)
                elseif Skybox.Value == "SpaceSky" then
					game.Lighting.Sky.SkyboxBk = "rbxassetid://1735468027"
					game.Lighting.Sky.SkyboxDn = "rbxassetid://1735500192"
					game.Lighting.Sky.SkyboxFt = "rbxassetid://1735467260"
					game.Lighting.Sky.SkyboxLf = "rbxassetid://1735467682"
					game.Lighting.Sky.SkyboxRt = "rbxassetid://1735466772"
					game.Lighting.Sky.SkyboxUp = "rbxassetid://1735500898"
				elseif Skybox.Value == "WhiteMountains" then 
					local Vignette = true
					local Lighting = game:GetService("Lighting")
					local ColorCor = Instance.new("ColorCorrectionEffect")
					local SunRays = Instance.new("SunRaysEffect")
					local Sky = Instance.new("Sky")
					local Atm = Instance.new("Atmosphere")
					game.Lighting.Sky.SkyboxBk = "http://www.roblox.com/asset/?id=14365017479"
					game.Lighting.Sky.SkyboxDn = "http://www.roblox.com/asset/?id=14365021997"
					game.Lighting.Sky.SkyboxFt = "http://www.roblox.com/asset/?id=14365016611"
					game.Lighting.Sky.SkyboxLf = "http://www.roblox.com/asset/?id=14365016884"
					game.Lighting.Sky.SkyboxRt = "http://www.roblox.com/asset/?id=14365016261"
					game.Lighting.Sky.SkyboxUp = "http://www.roblox.com/asset/?id=14365017884"
					

					Lighting.Ambient = Color3.fromRGB(2,2,2)
					Lighting.Brightness = 0.3
					Lighting.EnvironmentDiffuseScale = 0.2
					Lighting.EnvironmentSpecularScale = 0.2
					Lighting.GlobalShadows = true
					Lighting.ShadowSoftness = 0.2
					Lighting.ClockTime = 15
					Lighting.GeographicLatitude = 45
					Lighting.ExposureCompensation = 0.5
					Atm.Density = 0.364
					Atm.Offset = 0.556
					Atm.Glare = 0.36
					Atm.Haze = 1.72
                elseif Skybox.Value == "Infinite" then
					game.Lighting.Sky.SkyboxBk = "rbxassetid://14358449723"
					game.Lighting.Sky.SkyboxDn = "rbxassetid://14358455642"
					game.Lighting.Sky.SkyboxFt = "rbxassetid://14358452362"
					game.Lighting.Sky.SkyboxLf = "rbxassetid://14358784700"
					game.Lighting.Sky.SkyboxRt = "rbxassetid://14358454172"
					game.Lighting.Sky.SkyboxUp = "rbxassetid://14358455112"
                end
            end
        end
    })
    Skybox = GameThemeV2:CreateDropdown({
        Name = 'Themes',
        List = {'NebulaSky', "PinkMountainSky", 
		"CitySky", "PinkSky", 
		"EgirlSky", "SpaceSky", "WhiteMountains",
		"Infinite"},
        ["Function"] = function() end
    })
end)
run(function()
	local HotbarVisuals: table = {}
	local HotbarRounding: table  = {}
	local HotbarHighlight: table  = {}
	local HotbarColorToggle: table  = {}
	local HotbarHideSlotIcons: table  = {}
	local HotbarSlotNumberColorToggle: table  = {}
	local HotbarSpacing: table  = {Value = 0}
	local HotbarInvisibility: table  = {Value = 4}
	local HotbarRoundRadius: table  = {Value = 8}
	local HotbarColor: table  = {}
	local HotbarHighlightColor: table  = {}
	local HotbarSlotNumberColor: table  = {}
	local hotbarcoloricons: table  = {}
	local hotbarsloticons: table  = {}
	local hotbarobjects: table  = {}
	local hotbarslotgradients: table  = {}
	local inventoryiconobj: any = nil

	local function hotbarFunction(): (any, any)
		local icons: any = ({pcall(function() return lplr.PlayerGui.hotbar["1"].ItemsHotbar end)})[2];
		if not (icons and typeof(icons) == "Instance") then return end;

		inventoryiconobj = icons;
		pcall(function()
			local layout: UIListLayout? = icons:FindFirstChildOfClass("UIListLayout");
			if layout then layout.Padding = UDim.new(0, HotbarSpacing.Value); end
		end);

		for _, v: Instance in pairs(icons:GetChildren()) do
			local sloticon: TextLabel? = ({pcall(function() return v:FindFirstChildWhichIsA("ImageButton"):FindFirstChildWhichIsA("TextLabel") end)})[2];
			if typeof(sloticon) ~= "Instance" then continue end;

			local parent: GuiObject = sloticon.Parent;
			table.insert(hotbarcoloricons, parent);
			sloticon.Parent.Transparency = 0.1 * HotbarInvisibility.Value;

			if HotbarColorToggle.Enabled and not HotbarVisualsGradient.Enabled then
				parent.BackgroundColor3 = Color3.fromHSV(HotbarColor.Hue, HotbarColor.Sat, HotbarColor.Value);
			elseif HotbarVisualsGradient.Enabled and not parent:FindFirstChildWhichIsA("UIGradient") then
				parent.BackgroundColor3 = Color3.fromRGB(255, 255, 255);
				local g: UIGradient = Instance.new("UIGradient");
				g.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(HotbarVisualsGradientColor.Hue, HotbarVisualsGradientColor.Sat, HotbarVisualsGradientColor.Value)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(HotbarVisualsGradientColor2.Hue, HotbarVisualsGradientColor2.Sat, HotbarVisualsGradientColor2.Value))
				});
				g.Parent = parent;
				table.insert(hotbarslotgradients, g);
			end;

			if HotbarRounding.Enabled then
				local r: UICorner = Instance.new("UICorner"); r.CornerRadius = UDim.new(0, HotbarRoundRadius.Value);
				r.Parent = parent; table.insert(hotbarobjects, r);
			end;

			if HotbarHighlight.Enabled then
				local hl: UIStroke = Instance.new("UIStroke");
				hl.Color = Color3.fromHSV(HotbarHighlightColor.Hue, HotbarHighlightColor.Sat, HotbarHighlightColor.Value);
				hl.Thickness = 1.3; hl.Parent = parent;
				table.insert(hotbarobjects, hl);
			end;

			if HotbarHideSlotIcons.Enabled then sloticon.Visible = false; end;
			table.insert(hotbarsloticons, sloticon);
		end;
	end;

	HotbarVisuals = vape.Categories.Render:CreateModule({
		["Name"] = 'HotbarMods',
		["HoverText"] = 'Add customization to your hotbar.',
		["Function"] = function(callback: boolean): void
			if callback then 
				task.spawn(function()
					table.insert(HotbarVisuals.Connections, lplr.PlayerGui.DescendantAdded:Connect(function(v)
						if v.Name == "hotbar" then hotbarFunction(); end
					end));
					hotbarFunction();
				end);
				table.insert(HotbarVisuals.Connections, runService.RenderStepped:Connect(function()
					for _, v in hotbarcoloricons do pcall(function() v.Transparency = 0.1 * HotbarInvisibility["Value"]; end); end
				end));
			else
				for _: any, v: any in hotbarsloticons do pcall(function() v.Visible = true; end); end
				for _: any, v: any in hotbarcoloricons do pcall(function() v.BackgroundColor3 = Color3.fromRGB(29, 36, 46); end); end
				for _: any, v: any in hotbarobjects do pcall(function() v:Destroy(); end); end
				for _: any, v: any in hotbarslotgradients do pcall(function() v:Destroy(); end); end
				table.clear(hotbarobjects); table.clear(hotbarsloticons); table.clear(hotbarcoloricons);
			end;
		end;
	})
	local function forceRefresh()
		if HotbarVisuals["Enabled"] then HotbarVisuals:Toggle(); HotbarVisuals:Toggle(); end;
	end;
	HotbarColorToggle = HotbarVisuals:CreateToggle({
		["Name"] = "Slot Color",
		["Function"] = function(callback: boolean): void pcall(function() HotbarColor.Object.Visible = callback; end); forceRefresh(); end
	});
	HotbarVisualsGradient = HotbarVisuals:CreateToggle({
		["Name"] = "Gradient Slot Color",
		["Function"] = function(callback: boolean): void
			pcall(function()
				HotbarVisualsGradientColor.Object.Visible = callback;
				HotbarVisualsGradientColor2.Object.Visible = callback;
			end);
			forceRefresh();
		end;
	});
	HotbarVisualsGradientColor = HotbarVisuals:CreateColorSlider({
		["Name"] = 'Gradient Color',
		["Function"] = function(h, s, v)
			for i: any, v: any in hotbarslotgradients do 
				pcall(function() v.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromHSV(HotbarVisualsGradientColor.Hue, HotbarVisualsGradientColor.Sat, HotbarVisualsGradientColor.Value)), ColorSequenceKeypoint.new(1, Color3.fromHSV(HotbarVisualsGradientColor2.Hue, HotbarVisualsGradientColor2.Sat, HotbarVisualsGradientColor2.Value))}) end)
			end;
		end;
	})
	HotbarVisualsGradientColor2 = HotbarVisuals:CreateColorSlider({
		["Name"] = 'Gradient Color 2',
		["Function"] = function(h, s, v)
			for i: any,v: any in hotbarslotgradients do 
				pcall(function() v.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromHSV(HotbarVisualsGradientColor.Hue, HotbarVisualsGradientColor.Sat, HotbarVisualsGradientColor.Value)), ColorSequenceKeypoint.new(1, Color3.fromHSV(HotbarVisualsGradientColor2.Hue, HotbarVisualsGradientColor2.Sat, HotbarVisualsGradientColor2.Value))}) end)
			end;
		end;
	})
	HotbarColor = HotbarVisuals:CreateColorSlider({
		["Name"] = 'Slot Color',
		["Function"] = function(h, s, v)
			for i: any,v: any in hotbarcoloricons do
				if HotbarColorToggle["Enabled"] then
					pcall(function() v.BackgroundColor3 = Color3.fromHSV(HotbarColor.Hue, HotbarColor.Sat, HotbarColor.Value) end) 
				end;
			end;
		end;
	})
	HotbarRounding = HotbarVisuals:CreateToggle({
		["Name"] = 'Rounding',
		["Function"] = function(callback: boolean): void pcall(function() HotbarRoundRadius.Object.Visible = callback; end); forceRefresh(); end
	})
	HotbarRoundRadius = HotbarVisuals:CreateSlider({
		["Name"] = 'Corner Radius',
		["Min"] = 1,
		["Max"] = 20,
		["Function"] = function(callback: boolean): void
			for i,v in hotbarobjects do 
				pcall(function() v.CornerRadius = UDim.new(0, callback) end);
			end;
		end;
	})
	HotbarHighlight = HotbarVisuals:CreateToggle({
		["Name"] = 'Outline Highlight',
		["Function"] = function(callback: boolean): void pcall(function() HotbarHighlightColor.Object.Visible = callback; end); forceRefresh(); end
	})
	HotbarHighlightColor = HotbarVisuals:CreateColorSlider({
		["Name"] = 'Highlight Color',
		["Function"] = function(h, s, v)
			for i,v in hotbarobjects do 
				if v:IsA('UIStroke') and HotbarHighlight.Enabled then 
					pcall(function() v.Color = Color3.fromHSV(HotbarHighlightColor.Hue, HotbarHighlightColor.Sat, HotbarHighlightColor.Value) end)
				end;
			end;
		end;
	})
	HotbarHideSlotIcons = HotbarVisuals:CreateToggle({
		["Name"] = "No Slot Numbers", ["Function"] = forceRefresh
	});
	HotbarInvisibility = HotbarVisuals:CreateSlider({
		["Name"] = 'Invisibility',
		["Min"] = 0,
		["Max"] = 10,
		["Default"] = 4,
		["Function"] = function(value)
			for i,v in hotbarcoloricons do 
				pcall(function() v.Transparency = (0.1 * value) end); 
			end;
		end;
	})
	HotbarSpacing = HotbarVisuals:CreateSlider({
		["Name"] = 'Spacing',
		["Min"] = 0,
		["Max"] = 5,
		["Function"] = function(value)
			if HotbarVisuals["Enabled"] then 
				pcall(function() inventoryiconobj:FindFirstChildOfClass('UIListLayout').Padding = UDim.new(0, value) end);
			end;
		end;
	})
	HotbarColor.Object.Visible = false;
	HotbarRoundRadius.Object.Visible = false;
	HotbarHighlightColor.Object.Visible = false;
end);
local Fly
run(function()
	local Value
	local VerticalValue
	local WallCheck
	local PopBalloons
	local TP
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local up, down, old = 0, 0
	local damaged = false
	local DamageAnimValue = Instance.new("IntValue")
	local damageTween
	local damageCamConn

	-- ===== DAMAGE CAMERA (clean classic style) =====
	local DamageCam
	local function playDamageCam()
		if not DamageCam.Enabled then return end
		if damageTween then damageTween:Cancel() end

		-- Animate the value from 1000 -> 0
		DamageAnimValue.Value = 1000
		damageTween = tweenService:Create(DamageAnimValue, TweenInfo.new(0.5), {Value = 0})
		damageTween:Play()

		-- Remove any previous connection
		if damageCamConn then damageCamConn:Disconnect() end
		damageCamConn = runService.RenderStepped:Connect(function()
			if not DamageCam.Enabled then
				damageCamConn:Disconnect()
				return
			end
			local angle = math.rad(DamageAnimValue.Value / 100)
			gameCamera.CFrame = gameCamera.CFrame * CFrame.Angles(0, 0, angle)
		end)
	end

	Fly = vape.Categories.Combat:CreateModule({
		Name = 'Fly',
		Function = function(callback)
			frictionTable.Fly = callback or nil
			updateVelocity()

			if callback then
				-- Reset state
				damaged = false
				if damageCamConn then damageCamConn:Disconnect() end
				up, down, old = 0, 0, bedwars.BalloonController.deflateBalloon
				bedwars.BalloonController.deflateBalloon = function() end
				local tpTick, tpToggle, oldy = tick(), true

				if lplr.Character and (lplr.Character:GetAttribute('InflatedBalloons') or 0) == 0 and getItem('balloon') then
					bedwars.BalloonController:inflateBalloon()
				end

				Fly:Clean(vapeEvents.AttributeChanged.Event:Connect(function(changed)
					if changed == 'InflatedBalloons' and (lplr.Character:GetAttribute('InflatedBalloons') or 0) == 0 and getItem('balloon') then
						bedwars.BalloonController:inflateBalloon()
					end
				end))

				Fly:Clean(vapeEvents.BalloonPopped.Event:Connect(function(data)
					if DamageCam.Enabled
					and data.inflatedBalloon
					and data.inflatedBalloon:GetAttribute('BalloonOwner') == lplr.UserId then
						playDamageCam()
					end
				end))

				Fly:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive and not InfiniteFly.Enabled and isnetworkowner(entitylib.character.RootPart) then
						local flyAllowed = (lplr.Character:GetAttribute('InflatedBalloons') and lplr.Character:GetAttribute('InflatedBalloons') > 0) or store.matchState == 2

						if not flyAllowed and not damaged then
							damaged = true
							playDamageCam()
						elseif flyAllowed then
							damaged = false
						end

						local mass = (1.5 + (flyAllowed and 6 or 0) * (tick() % 0.4 < 0.2 and -1 or 1)) + ((up + down) * VerticalValue.Value)
						local root, moveDirection = entitylib.character.RootPart, entitylib.character.Humanoid.MoveDirection
						local velo = getSpeed()
						local destination = (moveDirection * math.max(Value.Value - velo, 0) * dt)
						rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiFallPart}
						rayCheck.CollisionGroup = root.CollisionGroup

						if WallCheck.Enabled then
							local ray = workspace:Raycast(root.Position, destination, rayCheck)
							if ray then
								destination = ((ray.Position + ray.Normal) - root.Position)
							end
						end

						if not flyAllowed then
							if tpToggle then
								local airleft = (tick() - entitylib.character.AirTime)
								if airleft > 2 then
									if not oldy then
										local ray = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rayCheck)
										if ray and TP.Enabled then
											tpToggle = false
											oldy = root.Position.Y
											tpTick = tick() + 0.11
											root.CFrame = CFrame.lookAlong(Vector3.new(root.Position.X, ray.Position.Y + entitylib.character.HipHeight, root.Position.Z), root.CFrame.LookVector)
										end
									end
								end
							else
								if oldy then
									if tpTick < tick() then
										local newpos = Vector3.new(root.Position.X, oldy, root.Position.Z)
										root.CFrame = CFrame.lookAlong(newpos, root.CFrame.LookVector)
										tpToggle = true
										oldy = nil
									else
										mass = 0
									end
								end
							end
						end

						root.CFrame += destination
						root.AssemblyLinearVelocity = (moveDirection * velo) + Vector3.new(0, mass, 0)
					end
				end))

				Fly:Clean(inputService.InputBegan:Connect(function(input)
					if not inputService:GetFocusedTextBox() then
						if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
							up = 1
						elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
							down = -1
						end
					end
				end))

				Fly:Clean(inputService.InputEnded:Connect(function(input)
					if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
						up = 0
					elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
						down = 0
					end
				end))

				if inputService.TouchEnabled then
					pcall(function()
						local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
						Fly:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
							up = jumpButton.ImageRectOffset.X == 146 and 1 or 0
						end))
					end)
				end
			else
				-- Reset state on disable
				bedwars.BalloonController.deflateBalloon = old
				damaged = false
				if damageCamConn then
					damageCamConn:Disconnect()
					damageCamConn = nil
				end
				if PopBalloons.Enabled and entitylib.isAlive and (lplr.Character:GetAttribute('InflatedBalloons') or 0) > 0 then
					for _ = 1, 3 do
						bedwars.BalloonController:deflateBalloon()
					end
				end
			end
		end,
		ExtraText = function() return 'Heatseeker' end,
		Tooltip = 'Makes you go zoom.'
	})

	-- Sliders and toggles
	Value = Fly:CreateSlider({Name='Speed', Min=1, Max=23, Default=23, Suffix=function(val) return val==1 and 'stud' or 'studs' end})
	VerticalValue = Fly:CreateSlider({Name='Vertical Speed', Min=1, Max=150, Default=50, Suffix=function(val) return val==1 and 'stud' or 'studs' end})
	WallCheck = Fly:CreateToggle({Name='Wall Check', Default=true})
	PopBalloons = Fly:CreateToggle({Name='Pop Balloons', Default=true})
	TP = Fly:CreateToggle({Name='TP Down', Default=true})
	DamageCam = Fly:CreateToggle({Name='Damage Camera', Default=true, Tooltip='Classic balloon pop camera animation'})
end)

local FlyLandTick = tick()
local InfiniteFly = {}
local performanceStats = game:GetService('Stats'):FindFirstChild('PerformanceStats')
run(function()
	local FlySpeed
	local VerticalSpeed
	local SafeMode

	local rayCheck = RaycastParams.new()
	local oldroot
	local clone

	local hip = 2.6

	local function createClone()
		if entitylib.isAlive and entitylib.character.Humanoid.Health > 0 and (not oldroot or not oldroot.Parent) then
			hip = entitylib.character.Humanoid.HipHeight
			oldroot = entitylib.character.HumanoidRootPart
			if not lplr.Character.Parent then return false end
			lplr.Character.Parent = game
			clone = oldroot:Clone()
			clone.Parent = lplr.Character
			--oldroot.CanCollide = false
			oldroot.Transparency = 0
			Instance.new('Highlight', oldroot)
			oldroot.Parent = gameCamera
			store.rootpart = clone
			bedwars.QueryUtil:setQueryIgnored(oldroot, true)
			lplr.Character.PrimaryPart = clone
			lplr.Character.Parent = workspace
			for _, v in lplr.Character:GetDescendants() do
				if v:IsA('Weld') or v:IsA('Motor6D') then
					if v.Part0 == oldroot then v.Part0 = clone end
					if v.Part1 == oldroot then v.Part1 = clone end
				end
			end
			return true
		end
		return false
	end

	local function destroyClone()
		if not oldroot or not oldroot.Parent or not entitylib.isAlive then return false end
		lplr.Character.Parent = game
		oldroot.Parent = lplr.Character
		lplr.Character.PrimaryPart = oldroot
		lplr.Character.Parent = workspace
		for _, v in lplr.Character:GetDescendants() do
			if v:IsA('Weld') or v:IsA('Motor6D') then
				if v.Part0 == clone then v.Part0 = oldroot end
				if v.Part1 == clone then v.Part1 = oldroot end
			end
		end
		oldroot.CanCollide = true
		if clone then
			clone:Destroy()
			clone = nil
		end
		entitylib.character.Humanoid.HipHeight = hip or 2.6
		oldroot.Transparency = 1
		oldroot = nil
		store.rootpart = nil
		FlyLandTick = tick() + 0.01
	end

	local up = 0
	local down = 0
	local startTick = tick()

	InfiniteFly = vape.Categories.Blatant:CreateModule({
		Name = 'InfiniteFly',
		Tooltip = 'Makes you go zoom.',
		Function = function(callback)
			if callback then
				task.wait()
				startTick = tick()
				if not entitylib.isAlive or FlyLandTick > tick() or not isnetworkowner(entitylib.character.RootPart) then
					return InfiniteFly:Toggle()
				end
				local a, b = pcall(createClone)
				if not a then
					return InfiniteFly:Toggle()
				end
				rayCheck.FilterDescendantsInstances = {lplr.Character, oldroot, clone, gameCamera}
				InfiniteFly:Clean(inputService.InputBegan:Connect(function(input)
					if not inputService:GetFocusedTextBox() then
						if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
							up = 1
						elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
							down = -1
						end
					end
				end))
				InfiniteFly:Clean(inputService.InputEnded:Connect(function(input)
					if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
						up = 0
					elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
						down = 0
					end
				end))

				local lastY = entitylib.character.RootPart.Position.Y
				local lastVelo = 0
				local cancelThread = false
				InfiniteFly:Clean(runService.PreSimulation:Connect(function(delta)
					if not entitylib.isAlive or not clone or not clone.Parent or not isnetworkowner(oldroot) or (workspace:GetServerTimeNow() - lplr:GetAttribute('LastTeleported')) < 2 then
						if not isnetworkowner(oldroot) then
							notif('InfiniteFly', 'Flag detected, Landing', 1.1, 'alert')
						end
						return InfiniteFly:Toggle()
					end
					FlyLandTick = tick() + 0.1
					local mass = 1.3 + ((up + down) * VerticalSpeed.Value)
					local moveDir = entitylib.character.Humanoid.MoveDirection
					local velo = getSpeed()
					local destination = (moveDir * math.max(FlySpeed.Value - velo, 0) * delta)
					clone.CFrame = clone.CFrame + destination
					clone.AssemblyLinearVelocity = (moveDir * velo) + Vector3.new(0, mass, 0)

					rayCheck.FilterDescendantsInstances = {lplr.Character, oldroot, clone, gameCamera}

					local raycast = workspace:Blockcast(oldroot.CFrame + Vector3.new(0, 250, 0), Vector3.new(3, 3, 3), Vector3.new(0, -500, 0), rayCheck)
					local groundcast = workspace:Blockcast(clone.CFrame, Vector3.new(3, 3, 3), Vector3.new(0, -3, 0), rayCheck)
					local upperRay = not workspace:Blockcast(oldroot.CFrame + (oldroot.CFrame.LookVector * 17), Vector3.new(3, 3, 3), Vector3.new(0, -150, 0), rayCheck) and workspace:Blockcast(oldroot.CFrame + (oldroot.CFrame.LookVector * 17), Vector3.new(3, 3, 3), Vector3.new(0, 150, 0), rayCheck)

					local changeYLevel = 300
					local yLevel = 0

					if lastVelo - oldroot.AssemblyLinearVelocity.Y > 1200 then
						oldroot.CFrame = oldroot.CFrame + Vector3.new(0, 200, 0)
					end

					for i,v in {50, 1000, 2000, 3000, 4000, 5000, 6000, 7000} do
						if oldroot.AssemblyLinearVelocity.Y < -v then
							changeYLevel = changeYLevel + 100
							yLevel = yLevel - 15
						end
					end

					lastVelo = oldroot.AssemblyLinearVelocity.Y

					if raycast then
						oldroot.AssemblyLinearVelocity = Vector3.zero
						oldroot.CFrame = groundcast and clone.CFrame or CFrame.lookAlong(Vector3.new(clone.Position.X, raycast.Position.Y + hip, clone.Position.Z), clone.CFrame.LookVector)
					elseif (oldroot.Position.Y < (lastY - (200 + yLevel))) and not cancelThread and (oldroot.AssemblyLinearVelocity.Y < -200 or not upperRay) then
						if upperRay then
							oldroot.CFrame = CFrame.lookAlong(Vector3.new(oldroot.CFrame.X, upperRay.Position.Y, oldroot.CFrame.Z), clone.CFrame.LookVector)
						else
							oldroot.CFrame = oldroot.CFrame + Vector3.new(0, changeYLevel, 0)
						end
						if oldroot.AssemblyLinearVelocity.Y < -800 then
							oldroot.AssemblyLinearVelocity = oldroot.AssemblyLinearVelocity + Vector3.new(0, 1, 0)
						end
					end

					oldroot.CFrame = CFrame.lookAlong(Vector3.new(clone.Position.X, oldroot.Position.Y, clone.Position.Z), clone.CFrame.LookVector)
				end))
			else
				notif('InfiniteFly', tostring(tick() - startTick):sub(1, 4).. 's', 4, 'alert')
				if (SafeMode.Enabled and (tick() - startTick) > 3) or performanceStats.Ping:GetValue() > 180 then
					oldroot.CFrame = CFrame.new(-9e9, 0, -9e9)
					clone.CFrame = CFrame.new(-9e9, 0, -9e9)
				end
				destroyClone()
			end
		end,
		ExtraText = function()
			return 'Heatseeker'
		end
	})
	FlySpeed = InfiniteFly:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 23,
		Default = 23
	})
	VerticalSpeed = InfiniteFly:CreateSlider({
		Name = 'Vertical Speed',
		Min = 1,
		Max = 150,
		Default = 70
	})
	SafeMode = InfiniteFly:CreateToggle({
		Name = 'Safe Mode'
	})
end)
run(function()
	local Mode
	local Expand
	local objects, set = {}
	
	local function createHitbox(ent)
		if ent.Targetable and ent.Player then
			local hitbox = Instance.new('Part')
			hitbox.Size = Vector3.new(3, 6, 3) + Vector3.one * (Expand.Value / 5)
			hitbox.Position = ent.RootPart.Position
			hitbox.CanCollide = false
			hitbox.Massless = true
			hitbox.Transparency = 1
			hitbox.Parent = ent.Character
			local weld = Instance.new('Motor6D')
			weld.Part0 = hitbox
			weld.Part1 = ent.RootPart
			weld.Parent = hitbox
			objects[ent] = hitbox
		end
	end
	
	HitBoxes = vape.Categories.Blatant:CreateModule({
		Name = 'HitBoxes',
		Function = function(callback)
			if callback then
				if Mode.Value == 'Sword' then
					debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (Expand.Value / 3))
					set = true
				else
					HitBoxes:Clean(entitylib.Events.EntityAdded:Connect(createHitbox))
					HitBoxes:Clean(entitylib.Events.EntityRemoving:Connect(function(ent)
						if objects[ent] then
							objects[ent]:Destroy()
							objects[ent] = nil
						end
					end))
					for _, ent in entitylib.List do
						createHitbox(ent)
					end
				end
			else
				if set then
					debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, 3.8)
					set = nil
				end
				for _, part in objects do
					part:Destroy()
				end
				table.clear(objects)
			end
		end,
		Tooltip = 'Expands attack hitbox'
	})
	Mode = HitBoxes:CreateDropdown({
		Name = 'Mode',
		List = {'Sword', 'Player'},
		Function = function()
			if HitBoxes.Enabled then
				HitBoxes:Toggle()
				HitBoxes:Toggle()
			end
		end,
		Tooltip = 'Sword - Increases the range around you to hit entities\nPlayer - Increases the players hitbox'
	})
	Expand = HitBoxes:CreateSlider({
		Name = 'Expand amount',
		Min = 0,
		Max = 14.4,
		Default = 14.4,
		Decimal = 10,
		Function = function(val)
			if HitBoxes.Enabled then
				if Mode.Value == 'Sword' then
					debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (val / 3))
				else
					for _, part in objects do
						part.Size = Vector3.new(3, 6, 3) + Vector3.one * (val / 5)
					end
				end
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)
	
run(function()
	vape.Categories.Blatant:CreateModule({
		Name = 'KeepSprint',
		Function = function(callback)
			debug.setconstant(bedwars.SprintController.startSprinting, 5, callback and 'blockSprinting' or 'blockSprint')
			bedwars.SprintController:stopSprinting()
		end,
		Tooltip = 'Lets you sprint with a speed potion.'
	})
end)
run(function()
		local KeepInventory = {Enabled = false}
		local KeepInventoryLagback = {Enabled = false}

		local enderchest
		local function getEnderchest()
			enderchest = enderchest or replicatedStorageService.Inventories[lplr.Name.."_personal"]
			return enderchest
		end

		--local GetItem = bedwars.ClientHandler:GetNamespace("Inventory"):Get("ChestGetItem")
		--local GiveItem = bedwars.ClientHandler:GetNamespace("Inventory"):Get("ChestGiveItem")
		--local ResetRemote = bedwars.ClientHandler:Get(bedwars.ResetRemote)
		local deposited = false

		local function collectEnderchest()
			if deposited then
				deposited = false
				repeat task.wait() until entityLibrary.isAlive
				lplr.Character:WaitForChild("InventoryFolder", 999999)
				repeat task.wait() until lplr.Character.InventoryFolder.Value ~= nil
				local enderchest = getEnderchest()
				for _, item in next, enderchest:GetChildren() do
					GetItem:CallServerAsync(enderchest, item)
				end
			end
		end

		local function depositAndWaitForRespawn(yield)
			if not deposited then
				deposited = true
				local inventory = lplr.Character:FindFirstChild("InventoryFolder")
				if inventory then 
					inventory = inventory.Value
					local enderchest = getEnderchest()
					local count = 0
					for _, item in next, inventory:GetChildren() do
						task.spawn(function()
							GiveItem:CallServer(enderchest, item)
							count -= 1
						end)
						count += 1
					end
					if yield then
						repeat task.wait() until count <= 0
					end
					lplr.CharacterAdded:Once(collectEnderchest)
				end
			end
		end

		local resetCallback = Instance.new("BindableEvent")
		resetCallback.Event:Connect(function()
			--warningNotification("KeepInventory", "Resetting, storing items", 5)
			depositAndWaitForRespawn(true)
			ResetRemote:SendToServer()
		end)

		KeepInventory = vape.Categories.Utility:CreateModule({
			Name = "KeepInventory",
			Function = function(callback)
				if callback then
					starterGui:SetCore("ResetButtonCallback", resetCallback)
					if KeepInventoryLagback.Enabled then
						task.spawn(function()
							repeat
								task.wait(0.1)
								if entityLibrary.isAlive then
									if not isnetworkowner(entityLibrary.character.HumanoidRootPart) and bedwarsStore.queueType:find("skywars") == nil then
										if not deposited then
											--warningNotification("KeepInventory", "Lagback detected, storing items", 5)
											task.spawn(function()
												local suc, res = pcall(function() return lplr.leaderstats.Bed.Value == "✅"  end)
												repeat task.wait() until not KeepInventory.Enabled or (isnetworkowner(entityLibrary.character.HumanoidRootPart) and suc and res) or (suc and res == nil)
												if entityLibrary.isAlive then
													collectEnderchest()
												end
											end)
										end
										depositAndWaitForRespawn(true)
									end
								end
							until not (KeepInventory and KeepInventoryLagback.Enabled)
						end)
					end
					table.insert(KeepInventory.Connections, vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
						if damageTable.entityInstance == lplr.Character and damageTable.fromEntity and damageTable.damage and bedwarsStore.queueType:find("skywars") == nil then
							local plr = playersService:GetPlayerFromCharacter(damageTable.fromEntity)
							local health = lplr.Character:GetAttribute("Health") or 150
							local stash = (health / damageTable.damage) <= 2
							if plr then
								local winning, hits, _hits = calculateHits(plr, false)
								stash = (_hits - hits) <= 2
							end
							if stash then
								if not deposited then
									--warningNotification("KeepInventory", "Possible death imminent, storing items", 5)
									task.delay(2, function()
										local suc, res = pcall(function() return lplr.leaderstats.Bed.Value == "✅"  end)
										repeat task.wait() until not KeepInventory.Enabled or (suc and res and (workspace:GetServerTimeNow() - lplr.Character:GetAttribute("LastDamageTakenTime")) > 2) or (suc and res == nil)
										if entityLibrary.isAlive then
											collectEnderchest()
										end
									end)
								end
								depositAndWaitForRespawn(true)
							end
						end
					end))
				else
					oldCallback = oldCallback or bedwars.ResetController:createBindable()
					starterGui:SetCore("ResetButtonCallback", oldCallback)
				end
			end
		})
		KeepInventoryLagback = KeepInventory:CreateToggle({
			Name = "Lagback",
			Function = blankFunction
		})
	end)
run(function()
	local RunService = game:GetService("RunService") --defined again idc
	local TweenService = game:GetService("TweenService")

	local AuraEnabled = false
	local animPlaying = false

	local KillauraAnimations = {
		MC = {
			{CFrame = CFrame.new(1.2, -0.9, 0.1) * CFrame.Angles(math.rad(-45), math.rad(100), math.rad(60)), Timer = 0.12},
			{CFrame = CFrame.new(1.3, -0.85, 0.25) * CFrame.Angles(math.rad(-30), math.rad(80), math.rad(40)), Timer = 0.12},
			{CFrame = CFrame.new(1.25, -0.88, 0.15) * CFrame.Angles(math.rad(-40), math.rad(90), math.rad(50)), Timer = 0.12},
		},
		Smooth = {
			{CFrame = CFrame.new(1, -0.8, 0.2) * CFrame.Angles(math.rad(-30), math.rad(80), math.rad(50)), Timer = 0.15},
			{CFrame = CFrame.new(1.1, -0.85, 0.1) * CFrame.Angles(math.rad(-35), math.rad(85), math.rad(55)), Timer = 0.15},
		},
		Wide = {
			{CFrame = CFrame.new(1.5, -1, 0.3) * CFrame.Angles(math.rad(-50), math.rad(120), math.rad(70)), Timer = 0.1},
			{CFrame = CFrame.new(1.4, -0.95, 0.25) * CFrame.Angles(math.rad(-40), math.rad(110), math.rad(65)), Timer = 0.1},
		}
	}

	local AttackRange
	local FaceTarget
	local SwingTarget
	local CustomAnimations
	local AnimationDropdown
	local SelectedAnimation = "MC"
	local Aura

	Aura = vape.Categories.Blatant:CreateModule({
		Name = "CustomAura",
		Function = function(call)
			AuraEnabled = call
			if call then
				Aura:Clean(RunService.Stepped:Connect(function()
					local Nearest = getNearestEntity(AttackRange.Value, Aura.Targets)
					if Nearest and isAlive(lplr) and isAlive(Nearest.plr) then
						local Sword = getBestSword()
						if Sword then
							if FaceTarget.Enabled then
								local selfPos = lplr.Character.PrimaryPart.Position
								local targetPos = Nearest.plr.Character.PrimaryPart.Position
								lplr.Character.PrimaryPart.CFrame = CFrame.lookAt(selfPos, Vector3.new(targetPos.X, selfPos.Y, targetPos.Z))
							end
							if SwingTarget.Enabled and CustomAnimations.Enabled and not animPlaying then
								animPlaying = true
								task.spawn(function()
									while animPlaying and Aura.Enabled do
										Nearest = getNearestEntity(AttackRange.Value, Aura.Targets)
										if not Nearest or not isAlive(lplr) or not isAlive(Nearest.plr) then break end
										for _, v in next, KillauraAnimations[SelectedAnimation] do
											Nearest = getNearestEntity(AttackRange.Value, Aura.Targets)
											if not Nearest or not isAlive(lplr) or not isAlive(Nearest.plr) then
												animPlaying = false
												break
											end
											local wrist = viewmodel and viewmodel:FindFirstChild("RightHand") and viewmodel.RightHand:FindFirstChild("RightWrist")
											if wrist then
												local tween = TweenService:Create(
													wrist,
													TweenInfo.new(v.Timer, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
													{C0 = C0 * v.CFrame}
												)
												tween:Play()
											end
											task.wait(v.Timer)
										end
									end
									local wrist = viewmodel and viewmodel:FindFirstChild("RightHand") and viewmodel.RightHand:FindFirstChild("RightWrist")
									if wrist then wrist.C0 = C0 end
									animPlaying = false
								end)
							end
							bedwars.SwordHit:FireServer({
								weapon = Sword,
								chargedAttack = {chargeRatio = 0},
								lastSwingServerTimeDelta = 0.01,
								entityInstance = Nearest.plr.Character,
								validate = {
									raycast = {
										cameraPosition = {value = lplr.Character.PrimaryPart.Position},
										rayDirection = {value = (Nearest.plr.Character.PrimaryPart.Position - lplr.Character.PrimaryPart.Position).Unit}
									},
									targetPosition = {value = Nearest.plr.Character.PrimaryPart.Position},
									selfPosition = {value = lplr.Character.PrimaryPart.Position}
								}
							})
						end
					else
						if animPlaying then
							animPlaying = false
							local wrist = viewmodel and viewmodel:FindFirstChild("RightHand") and viewmodel.RightHand:FindFirstChild("RightWrist")
							if wrist then wrist.C0 = C0 end
						end
					end
				end))
			else
				animPlaying = false
				local wrist = viewmodel and viewmodel:FindFirstChild("RightHand") and viewmodel.RightHand:FindFirstChild("RightWrist")
				if wrist then wrist.C0 = C0 end
			end
		end
	})

	Aura:CreateTargets({
		Players = true,
		NPCs = false
	})

	AttackRange = Aura:CreateSlider({
		Name = "Attack Range",
		Min = 1,
		Max = 23,
		Default = 23,
		Suffix = function(val) return val == 1 and "stud" or "studs" end
	})

	FaceTarget = Aura:CreateToggle({
		Name = "Face Target"
	})

	SwingTarget = Aura:CreateToggle({
		Name = "Swing Target"
	})

	CustomAnimations = Aura:CreateToggle({
		Name = "Custom Animations",
		Function = function(state)
			AnimationDropdown.Object.Visible = state
		end
	})

	AnimationDropdown = Aura:CreateDropdown({
		Name = "Animation Type",
		List = {"MC", "Smooth", "Wide"},
		Value = "MC",
		Function = function(opt)
			SelectedAnimation = opt
		end
	})

	AnimationDropdown.Object.Visible = false
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

	local SyncHit
	local Targets
	local Sort
	local SwingRange
	local AttackRange
	local AfterSwing
	local UpdateRate
	local AngleSlider
	local MaxTargets
	local Mouse
	local Swing
	local GUI
	local BoxSwingColor
	local BoxAttackColor
	local ParticleTexture
	local ParticleColor1
	local ParticleColor2
	local ParticleSize
	local Face
	local Animation
	local AnimationMode
	local AnimationSpeed
	local AnimationTween
	local Limit
	local SC = {Enabled = true}
	local RV
	local HR
	local FastHits
	local HitsDelay
	local HRTR = {
		[1] = 0.042,
		[2] = 0.0042,
	}
	local LegitAura = {}
	local Particles, Boxes = {}, {}
	local anims, AnimDelay, AnimTween, armC0 = vape.Libraries.auraanims, tick()
	local AttackRemote = {FireServer = function() end}
	task.spawn(function()
		AttackRemote = bedwars.Client:Get(remotes.AttackEntity).instance
	end)

	local function getAttackData()
		if Mouse.Enabled then
			if not inputService:IsMouseButtonPressed(0) then return false end
		end

		if GUI.Enabled then
			if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then return false end
		end

		local sword = Limit.Enabled and store.hand or store.tools.sword
		if not sword or not sword.tool then return false end

		local meta = bedwars.ItemMeta[sword.tool.Name]
		if Limit.Enabled then
			if store.hand.toolType ~= 'sword' or bedwars.DaoController.chargingMaid then return false end
		end

		if LegitAura.Enabled then
			if (tick() - bedwars.SwordController.lastSwing) > 0.15 then return false end
		end

		return sword, meta
	end

	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'Killaura',
		Function = function(callback)
			if callback then
				if inputService.TouchEnabled then
					pcall(function()
						lplr.PlayerGui.MobileUI['2'].Visible = Limit.Enabled
					end)
				end

				if Animation.Enabled and not (identifyexecutor and table.find({'Argon', 'Delta','Codex'}, ({identifyexecutor()})[1])) then
					local fake = {
						Controllers = {
							ViewmodelController = {
								isVisible = function()
									return not Attacking
								end,
								playAnimation = function(...)
									if not Attacking then
										bedwars.ViewmodelController:playAnimation(select(2, ...))
									end
								end
							}
						}
					}
					debug.setupvalue(oldSwing or bedwars.SwordController.playSwordEffect, 6, fake)
					debug.setupvalue(bedwars.ScytheController.playLocalAnimation, 3, fake)

					task.spawn(function()
						local started = false
						repeat
							if Attacking then
								if not armC0 then
									armC0 = gameCamera.Viewmodel.RightHand.RightWrist.C0
								end
								local first = not started
								started = true

								if AnimationMode.Value == 'Random' then
									anims.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}}
								end

								for _, v in anims[AnimationMode.Value] do
									AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(first and (AnimationTween.Enabled and 0.001 or 0.1) or v.Time / AnimationSpeed.Value, Enum.EasingStyle.Linear), {
										C0 = armC0 * v.CFrame
									})
									AnimTween:Play()
									AnimTween.Completed:Wait()
									first = false
									if (not Killaura.Enabled) or (not Attacking) then break end
								end
							elseif started then
								started = false
								AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
									C0 = armC0
								})
								AnimTween:Play()
							end

							if not started then
								task.wait(1 / UpdateRate.Value)
							end
						until (not Killaura.Enabled) or (not Animation.Enabled)
					end)
				end

				local swingCooldown = 0
				repeat
					local attacked, sword, meta = {}, getAttackData()
					Attacking = false
					store.KillauraTarget = nil
					if sword then
						if SC.Enabled and entitylib.isAlive and lplr.Character:FindFirstChild("elk") then return end
						local isClaw = string.find(string.lower(tostring(sword and sword.itemType or "")), "summoner_claw")	
						local plrs = entitylib.AllPosition({
							Range = SwingRange.Value,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Limit = MaxTargets.Value,
							Sort = sortmethods[Sort.Value]
						})

						if #plrs > 0 then
							if store.equippedKit == "ember" and sword.itemType == "infernal_saber" then
								bedwars.Client:Get('HellBladeRelease'):FireServer({chargeTime = 1, player = lplr, weapon = sword.tool})
							end
							local selfpos = entitylib.character.RootPart.Position
							local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)

							for _, v in plrs do
								local delta = (v.RootPart.Position - selfpos)
								local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
								if angle > (math.rad(AngleSlider.Value) / 2) then continue end

								table.insert(attacked, {
									Entity = v,
									Check = delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor
								})
								targetinfo.Targets[v] = tick() + 1

								if not Attacking then
									Attacking = true
									store.KillauraTarget = v
									if not Swing.Enabled and AnimDelay < tick() and not LegitAura.Enabled then
										AnimDelay = tick() + (meta.sword.respectAttackSpeedForEffects and meta.sword.attackSpeed or math.max(ChargeTime.Value, 0.11))
										bedwars.SwordController:playSwordEffect(meta, false)
										if meta.displayName:find(' Scythe') then
											bedwars.ScytheController:playLocalAnimation()
										end

										if vape.ThreadFix then
											setthreadidentity(8)
										end
									end
								end

								if delta.Magnitude > AttackRange.Value then continue end
								if delta.Magnitude < 14.4 and (tick() - swingCooldown) < math.max(ChargeTime.Value, 0.02) then continue end

								local actualRoot = v.Character.PrimaryPart
								if actualRoot then
									local dir = CFrame.lookAt(selfpos, actualRoot.Position).LookVector
									local pos = selfpos + dir * math.max(delta.Magnitude - 14.399, 0)
									swingCooldown = SyncHit.Enabled and (tick() - HRTR[1]) or tick()
									bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
									store.attackReach = SyncHit.Enabled and ((delta.Magnitude * 100) // 1 / 100 - HRTR[1] - 0.055) or (delta.Magnitude * 100) // 1 / 100 - 0.055
									store.attackReachUpdate = SyncHit.Enabled and (tick() + 1 - HRTR[2]) or tick() + 1


									if delta.Magnitude < 14.4 and ChargeTime.Value > 0.11 then
										AnimDelay =  tick()
									end

									local Q = 0.5
									if SyncHit.Enabled  then Q = 0.35 else Q = 0.5 end
										if isClaw then
											KaidaController:request(v.Character)
										else
													AttackRemote:FireServer({
														weapon = sword.tool,
														chargedAttack = {chargeRatio = 0},
														entityInstance = v.Character,
														validate = {
															raycast = {},
															targetPosition = {value = actualRoot.Position},
															selfPosition = {value = pos}
														}
													})
										if not v.Character then
											print("player is dead")
										end
									end
								end
							end
						end
					end

					for i, v in Boxes do
						v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
						if v.Adornee then
							v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
							v.Transparency = 1 - attacked[i].Check.Opacity
						end
					end

					for i, v in Particles do
						v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
						v.Parent = attacked[i] and gameCamera or nil
					end

					if Face.Enabled and attacked[1] then
						local vec = attacked[1].Entity.RootPart.Position * Vector3.new(1, 0, 1)
						entitylib.character.RootPart.CFrame = CFrame.lookAt(entitylib.character.RootPart.Position, Vector3.new(vec.X, entitylib.character.RootPart.Position.Y + 0.001, vec.Z))
					end

					task.wait(1 / UpdateRate.Value)
				until not Killaura.Enabled
			else
				store.KillauraTarget = nil
				for _, v in Boxes do
					v.Adornee = nil
				end
				for _, v in Particles do
					v.Parent = nil
				end
				if inputService.TouchEnabled then
					pcall(function()
						lplr.PlayerGui.MobileUI['2'].Visible = true
					end)
				end
				debug.setupvalue(oldSwing or bedwars.SwordController.playSwordEffect, 6, bedwars.Knit)
				debug.setupvalue(bedwars.ScytheController.playLocalAnimation, 3, bedwars.Knit)
				Attacking = false
				if armC0 then
					AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
						C0 = armC0
					})
					AnimTween:Play()
				end
			end
		end,
		Tooltip = 'Attack players around you\nwithout aiming at them.'
	})
	Targets = Killaura:CreateTargets({
		Players = true,
		NPCs = true
	})
	local methods = {'Damage', 'Distance'}
	for i in sortmethods do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end

	HR = Killaura:CreateSlider({
		Name = 'Hit Registration',
		Min = 1,
		Max = 36,
		Default = 36.5,
		Function = function(val)
			local function RegMath(sliderValue)
				local minValue1 = 0.042
				local maxValue1 = 0.045

				local minValue2 = 0.0042
				local maxValue2 = 0.0045

				local steps = 35 

				local value1 = minValue1 + ((sliderValue - 1) * ((maxValue1 - minValue1) / steps))
				local value2 = minValue2 + ((sliderValue - 1) * ((maxValue2 - minValue2) / steps))

				return math.abs(value1), math.abs(value2)
			end

			if Killaura.Enabled then
				local v1,v2 = RegMath(val)
				HRTR[1] = v1
				HRTR[2] = v2
			end
		end
	})

	local MaxRange = 0
	local CE = false
	if role ~= "owner" and role ~= "coowner" and role ~= "admin" and role ~= "friend" and role ~= "premium" and role ~= "user"  then
		MaxRange = 32
		CE = true
		SyncHit = {Enabled = false}
	elseif role == "user" then
		MaxRange = 18
		CE = true
		SyncHit = Killaura:CreateToggle({
			Name = 'Sync Hit-Time',
			Tooltip = "Synchronize's ur hit time",
			Default = false,
		})
	elseif role == "premium" then
		MaxRange = 32
		CE = true
		SyncHit = Killaura:CreateToggle({
			Name = 'Sync Hit-Time',
			Tooltip = "Synchronize's ur hit time",
			Default = false,
		})
	elseif role == "friend" or role == "admin" or role == "coowner" or role == "owner" then
		MaxRange = 32
		CE = true
		SyncHit = Killaura:CreateToggle({
			Name = 'Sync Hit-Time',
			Tooltip = "Synchronize's ur hit time",
			Default = false,
		})
	else
		MaxRange = 32
		SyncHit = {Enabled = false}
	end

	SwingRange = Killaura:CreateSlider({
		Name = 'Swing range',
		Min = 1,
		Edit = CE,
		Max = MaxRange,
		Default = 18,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = MaxRange,
		Edit = CE,
		Default = 18,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	ChargeTime = Killaura:CreateSlider({
		Name = 'Swing time',
		Min = 0,
		Max = 1,
		Default = 0.3,
		Decimal = 100
	})
	AngleSlider = Killaura:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 360
	})
	UpdateRate = Killaura:CreateSlider({
		Name = 'Update rate',
		Min = 1,
		Max = 360,
		Default = 60,
		Suffix = 'hz'
	})
	MaxTargets = Killaura:CreateSlider({
		Name = 'Max targets',
		Min = 1,
		Max = 8,
		Default = 5
	})
	Sort = Killaura:CreateDropdown({
		Name = 'Target Mode',
		List = methods
	})
	Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
	Swing = Killaura:CreateToggle({Name = 'No Swing'})
	GUI = Killaura:CreateToggle({Name = 'GUI check'})
	Killaura:CreateToggle({
		Name = 'Show target',
		Function = function(callback)
			BoxSwingColor.Object.Visible = callback
			BoxAttackColor.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local box = Instance.new('BoxHandleAdornment')
					box.Adornee = nil
					box.AlwaysOnTop = true
					box.Size = Vector3.new(3, 5, 3)
					box.CFrame = CFrame.new(0, -0.5, 0)
					box.ZIndex = 0
					box.Parent = vape.gui
					Boxes[i] = box
				end
			else
				for _, v in Boxes do
					v:Destroy()
				end
				table.clear(Boxes)
			end
		end
	})
	BoxSwingColor = Killaura:CreateColorSlider({
		Name = 'Target Color',
		Darker = true,
		DefaultHue = 0.6,
		DefaultOpacity = 0.5,
		Visible = false
	})
	BoxAttackColor = Killaura:CreateColorSlider({
		Name = 'Attack Color',
		Darker = true,
		DefaultOpacity = 0.5,
		Visible = false
	})
	Killaura:CreateToggle({
		Name = 'Target particles',
		Function = function(callback)
			ParticleTexture.Object.Visible = callback
			ParticleColor1.Object.Visible = callback
			ParticleColor2.Object.Visible = callback
			ParticleSize.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local part = Instance.new('Part')
					part.Size = Vector3.new(2, 4, 2)
					part.Anchored = true
					part.CanCollide = false
					part.Transparency = 1
					part.CanQuery = false
					part.Parent = Killaura.Enabled and gameCamera or nil
					local particles = Instance.new('ParticleEmitter')
					particles.Brightness = 1.5
					particles.Size = NumberSequence.new(ParticleSize.Value)
					particles.Shape = Enum.ParticleEmitterShape.Sphere
					particles.Texture = ParticleTexture.Value
					particles.Transparency = NumberSequence.new(0)
					particles.Lifetime = NumberRange.new(0.4)
					particles.Speed = NumberRange.new(16)
					particles.Rate = 128
					particles.Drag = 16
					particles.ShapePartial = 1
					particles.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
					})
					particles.Parent = part
					Particles[i] = part
				end
			else
				for _, v in Particles do
					v:Destroy()
				end
				table.clear(Particles)
			end
		end
	})
	ParticleTexture = Killaura:CreateTextBox({
		Name = 'Texture',
		Default = 'rbxassetid://14736249347',
		Function = function()
			for _, v in Particles do
				v.ParticleEmitter.Texture = ParticleTexture.Value
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor1 = Killaura:CreateColorSlider({
		Name = 'Color Begin',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor2 = Killaura:CreateColorSlider({
		Name = 'Color End',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleSize = Killaura:CreateSlider({
		Name = 'Size',
		Min = 0,
		Max = 1,
		Default = 0.2,
		Decimal = 100,
		Function = function(val)
			for _, v in Particles do
				v.ParticleEmitter.Size = NumberSequence.new(val)
			end
		end,
		Darker = true,
		Visible = false
	})
	Face = Killaura:CreateToggle({Name = 'Face target'})
	Animation = Killaura:CreateToggle({
		Name = 'Custom Animation',
		Function = function(callback)
			AnimationMode.Object.Visible = callback
			AnimationTween.Object.Visible = callback
			AnimationSpeed.Object.Visible = callback
			if Killaura.Enabled then
				Killaura:Toggle()
				Killaura:Toggle()
			end
		end
	})
	local animnames = {}
	for i in anims do
		table.insert(animnames, i)
	end
	AnimationMode = Killaura:CreateDropdown({
		Name = 'Animation Mode',
		List = animnames,
		Darker = true,
		Visible = false
	})
	AnimationSpeed = Killaura:CreateSlider({
		Name = 'Animation Speed',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 10,
		Darker = true,
		Visible = false
	})
	AnimationTween = Killaura:CreateToggle({
		Name = 'No Tween',
		Darker = true,
		Visible = false
	})
	Limit = Killaura:CreateToggle({
		Name = 'Limit to items',
		Function = function(callback)
			if inputService.TouchEnabled and Killaura.Enabled then
				pcall(function()
					lplr.PlayerGui.MobileUI['2'].Visible = callback
				end)
			end
		end,
		Tooltip = 'Only attacks when the sword is held'
	})

	LegitAura = Killaura:CreateToggle({
		Name = 'Legit Aura',
		Tooltip = 'Only attacks when the mouse is clicking'
	})
end)

run(function()
local AutoReport = {Enabled = false}
local Mode
	 AutoReport = vape.Categories.Exploits:CreateModule({
		Name = "AutoReport",
		Function = function(callback)
			if callback then

				for _, v in ipairs(game:GetService("Players"):GetPlayers()) do
					if v ~= game.Players.LocalPlayer then
						TryToReport(v,Mode.Value)
					end
				end
			end
		end,
		Tooltip = "Automatically reports everyone in the game",
	})
 	Mode = AutoReport:CreateDropdown({
		Name = "Mode",
		List= {"VapeNotify", "BedwarsNotify", "Hidden"}
	})
	AutoReport:Toggle(false)
end)


run(function()
	local AutoQueue
	

	
	AutoQueue = vape.Categories.Exploits:CreateModule({
		Name = 'AutoQueue',
		Function = function(callback)    
			if callback then
				AutoQueue:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
					if deathTable.finalKill and deathTable.entityInstance == lplr.Character and isEveryoneDead() and store.matchState ~= 2 then
						joinQueue()
					end
				end))
				AutoQueue:Clean(vapeEvents.MatchEndEvent.Event:Connect(joinQueue))
			end
		end,
		Tooltip = 'Automatically queues for the next match (for bad execs)'
	})

end)
			
run(function()
    local QueueDisplayConfig = {
        ActiveState = false,
        GradientControl = {Enabled = true},
        ColorSettings = {
            Gradient1 = {Hue = 0, Saturation = 0, Brightness = 1},
            Gradient2 = {Hue = 0, Saturation = 0, Brightness = 0.8}
        },
        Animation = {Speed = 0.5, Progress = 0}
    }

    local DisplayUtils = {
        createGradient = function(parent)
            local gradient = parent:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
            gradient.Parent = parent
            return gradient
        end,
        updateColor = function(gradient, config)
            local time = tick() * config.Animation.Speed
            local interp = (math.sin(time) + 1) / 2
            local h = config.ColorSettings.Gradient1.Hue + (config.ColorSettings.Gradient2.Hue - config.ColorSettings.Gradient1.Hue) * interp
            local s = config.ColorSettings.Gradient1.Saturation + (config.ColorSettings.Gradient2.Saturation - config.ColorSettings.Gradient1.Saturation) * interp
            local b = config.ColorSettings.Gradient1.Brightness + (config.ColorSettings.Gradient2.Brightness - config.ColorSettings.Gradient1.Brightness) * interp
            gradient.Color = ColorSequence.new(Color3.fromHSV(h, s, b))
        end
    }

	local CoreConnection

    local function enhanceQueueDisplay()
		pcall(function() 
			CoreConnection:Disconnect()
		end)
        local success, err = pcall(function()
            if not lplr.PlayerGui:FindFirstChild('QueueApp') then return end
            
            for attempt = 1, 3 do
                if QueueDisplayConfig.GradientControl.Enabled then
                    local queueFrame = lplr.PlayerGui.QueueApp['1']
                    queueFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    
                    local gradient = DisplayUtils.createGradient(queueFrame)
                    gradient.Rotation = 180
                    
                    local displayInterface = {
                        module = vape.watermark,
                        gradient = gradient,
                        GetEnabled = function()
                            return QueueDisplayConfig.ActiveState
                        end,
                        SetGradientEnabled = function(state)
                            QueueDisplayConfig.GradientControl.Enabled = state
                            gradient.Enabled = state
                        end
                    }
                    CoreConnection = game:GetService("RunService").RenderStepped:Connect(function()
                        if QueueDisplayConfig.ActiveState and QueueDisplayConfig.GradientControl.Enabled then
                            DisplayUtils.updateColor(gradient, QueueDisplayConfig)
                        end
                    end)
                end
                task.wait(0.1)
            end
        end)
        
        if not success then
            warn("Queue display enhancement failed: " .. tostring(err))
        end
    end

    local QueueDisplayEnhancer
    QueueDisplayEnhancer = vape.Categories.Exploits:CreateModule({
        Name = 'QueueMods',
        Tooltip = 'non-skidded queuecard',
        Function = function(enabled)     
            QueueDisplayConfig.ActiveState = enabled
            if enabled then
                enhanceQueueDisplay()
                QueueDisplayEnhancer:Clean(lplr.PlayerGui.ChildAdded:Connect(enhanceQueueDisplay))
			else
				pcall(function() 
					CoreConnection:Disconnect()
				end)
			end
        end
    })

   	QueueDisplayEnhancer:CreateSlider({
        Name = "Animation Speed",
        Function = function(speed)
            QueueDisplayConfig.Animation.Speed = math.clamp(speed, 0.1, 5)
        end,
        Min = 1,
        Max = 8,
        Default = 5
    })

    QueueDisplayEnhancer:CreateColorSlider({
        Name = "Color 1",
        Function = function(h, s, v)
            QueueDisplayConfig.ColorSettings.Gradient1 = {Hue = h, Saturation = s, Brightness = v}
        end
    })

    QueueDisplayEnhancer:CreateColorSlider({
        Name = "Color 2",
        Function = function(h, s, v)
            QueueDisplayConfig.ColorSettings.Gradient2 = {Hue = h, Saturation = s, Brightness = v}
        end
    })
end)
run(function()
    local Value
    local CameraDir
    local JumpTick, JumpSpeed, Direction = tick(), 0
    local Speds

    LongJump = vape.Categories.Blatant:CreateModule({
        Name = 'LongJump',
        Function = function(callback)
            if callback then
                LongJump:Clean(runService.PreSimulation:Connect(function(dt)
                    local root = entitylib.isAlive and entitylib.character.RootPart or nil
                    if root and isnetworkowner(root) then
                        local humanoid = entitylib.character.Humanoid
                        local moveDir = humanoid.MoveDirection
                        
                        -- Longjump logic when active
                        if JumpTick > tick() then
                            local horizontalSpeed = Direction * (getSpeed() + ((JumpTick - tick()) > 1.1 and JumpSpeed or 0))
                            root.AssemblyLinearVelocity = horizontalSpeed + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
                            
                            -- Anti-fall when in air
                            if humanoid.FloorMaterial == Enum.Material.Air then
                                root.AssemblyLinearVelocity += Vector3.new(0, dt * (workspace.Gravity - 23), 0)
                            else
                                root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 15, root.AssemblyLinearVelocity.Z)
                            end
                        else
                            -- Normal movement with speed boost
                            if moveDir.Magnitude > 0 then
                                root.AssemblyLinearVelocity = moveDir.Unit * Speds.Value + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
                            else
                                root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
                            end
                        end
                    end
                end))
                
                -- Clean up on damage (for knockback boost)
                LongJump:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
                    if damageTable.entityInstance == lplr.Character and damageTable.fromEntity == lplr.Character then
                        local knockbackBoost = 25 -- Fixed knockback boost
                        local pos = damageTable.fromPosition and Vector3.new(damageTable.fromPosition.X, damageTable.fromPosition.Y, damageTable.fromPosition.Z) or damageTable.fromEntity and damageTable.fromEntity.PrimaryPart.Position
                        if pos then
                            local vec = (entitylib.character.RootPart.Position - pos)
                            JumpSpeed = knockbackBoost * Value.Value / 36
                            JumpTick = tick() + 2.5
                            Direction = Vector3.new(vec.X, 0, vec.Z).Unit
                        end
                    end
                end))
                
                -- Manual trigger on keybind (space + forward)
                LongJump:Clean(runService.Heartbeat:Connect(function()
                    if entitylib.isAlive and lplr.Character.Humanoid.Jump then
                        local root = entitylib.character.RootPart
                        local moveDir = lplr.Character.Humanoid.MoveDirection
                        
                        if moveDir.Magnitude > 0 then
                            JumpSpeed = 5.25 * Value.Value / 36 -- Normalized speed
                            JumpTick = tick() + 2.3
                            Direction = (CameraDir.Enabled and workspace.CurrentCamera.CFrame or root.CFrame).LookVector
                            Direction = Vector3.new(Direction.X, 0, Direction.Z).Unit
                        end
                    end
                end))
                
            else
                JumpTick = tick()
                Direction = nil
                JumpSpeed = 0
            end
        end,
        ExtraText = function()
            return 'Itemless'
        end,
        Tooltip = 'Jump far without needing any items'
    })

    Value = LongJump:CreateSlider({
        Name = 'Jump Speed',
        Min = 22,
        Max = 60,
        Default = 36,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    
    CameraDir = LongJump:CreateToggle({
        Name = 'Camera Direction',
        Default = true
    })
    
    Speds = LongJump:CreateSlider({
        Name = 'Walk Speed',
        Min = 16,
        Max = 50,
        Default = 21,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
end)


	
run(function()
	local NoFall
	local Mode
	local rayParams = RaycastParams.new()
	local groundHit
	task.spawn(function()
		groundHit = bedwars.Client:Get(remotes.GroundHit).instance
	end)
	
	NoFall = vape.Categories.Blatant:CreateModule({
		Name = 'NoFall',
		Function = function(callback)
			if callback then
				local tracked = 0
				if Mode.Value == 'Gravity' then
					local extraGravity = 0
					NoFall:Clean(runService.PreSimulation:Connect(function(dt)
						if entitylib.isAlive then
							local root = entitylib.character.RootPart
							if root.AssemblyLinearVelocity.Y < -85 then
								rayParams.FilterDescendantsInstances = {lplr.Character, gameCamera}
								rayParams.CollisionGroup = root.CollisionGroup
	
								local rootSize = root.Size.Y / 2 + entitylib.character.HipHeight
								local ray = workspace:Blockcast(root.CFrame, Vector3.new(3, 3, 3), Vector3.new(0, (tracked * 0.1) - rootSize, 0), rayParams)
								if not ray then
									root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, -86, root.AssemblyLinearVelocity.Z)
									root.CFrame += Vector3.new(0, extraGravity * dt, 0)
									extraGravity += -workspace.Gravity * dt
								end
							else
								extraGravity = 0
							end
						end
					end))
				else
					repeat
						if entitylib.isAlive then
							local root = entitylib.character.RootPart
							tracked = entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air and math.min(tracked, root.AssemblyLinearVelocity.Y) or 0
	
							if tracked < -85 then
								if Mode.Value == 'Packet' then
									groundHit:FireServer(nil, Vector3.new(0, tracked, 0), workspace:GetServerTimeNow())
								else
									rayParams.FilterDescendantsInstances = {lplr.Character, gameCamera}
									rayParams.CollisionGroup = root.CollisionGroup
	
									local rootSize = root.Size.Y / 2 + entitylib.character.HipHeight
									if Mode.Value == 'Teleport' then
										local ray = workspace:Blockcast(root.CFrame, Vector3.new(3, 3, 3), Vector3.new(0, -1000, 0), rayParams)
										if ray then
											root.CFrame -= Vector3.new(0, root.Position.Y - (ray.Position.Y + rootSize), 0)
										end
									else
										local ray = workspace:Blockcast(root.CFrame, Vector3.new(3, 3, 3), Vector3.new(0, (tracked * 0.1) - rootSize, 0), rayParams)
										if ray then
											tracked = 0
											root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, -80, root.AssemblyLinearVelocity.Z)
										end
									end
								end
							end
						end
	
						task.wait(0.03)
					until not NoFall.Enabled
				end
			end
		end,
		Tooltip = 'Prevents taking fall damage.'
	})
	Mode = NoFall:CreateDropdown({
		Name = 'Mode',
		List = {'Packet', 'Gravity', 'Teleport', 'Bounce'},
		Function = function()
			if NoFall.Enabled then
				NoFall:Toggle()
				NoFall:Toggle()
			end
		end
	})
end)
	
run(function()
	local old
	
	vape.Categories.Blatant:CreateModule({
		Name = 'NoSlowdown',
		Function = function(callback)
			local modifier = bedwars.SprintController:getMovementStatusModifier()
			if callback then
				old = modifier.addModifier
				modifier.addModifier = function(self, tab)
					if tab.moveSpeedMultiplier then
						tab.moveSpeedMultiplier = math.max(tab.moveSpeedMultiplier, 1)
					end
					return old(self, tab)
				end
	
				for i in modifier.modifiers do
					if (i.moveSpeedMultiplier or 1) < 1 then
						modifier:removeModifier(i)
					end
				end
			else
				modifier.addModifier = old
				old = nil
			end
		end,
		Tooltip = 'Prevents slowing down when using items.'
	})
end)
	
run(function()
	local TargetPart
	local Targets
	local FOV
	local OtherProjectiles
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Include
	rayCheck.FilterDescendantsInstances = {workspace:FindFirstChild('Map')}
	local old
	
	local ProjectileAimbot = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileAimbot',
		Function = function(callback)
			if callback then
				old = bedwars.ProjectileController.calculateImportantLaunchValues
				bedwars.ProjectileController.calculateImportantLaunchValues = function(...)
					local self, projmeta, worldmeta, origin, shootpos = ...
					local plr = entitylib.EntityMouse({
						Part = 'RootPart',
						Range = FOV.Value,
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Wallcheck = Targets.Walls.Enabled,
						Origin = entitylib.isAlive and (shootpos or entitylib.character.RootPart.Position) or Vector3.zero
					})
	
					if plr then
						local pos = shootpos or self:getLaunchPosition(origin)
						if not pos then
							return old(...)
						end
	
						if (not OtherProjectiles.Enabled) and not projmeta.projectile:find('arrow') then
							return old(...)
						end
	
						local meta = projmeta:getProjectileMeta()
						local lifetime = (worldmeta and meta.predictionLifetimeSec or meta.lifetimeSec or 3)
						local gravity = (meta.gravitationalAcceleration or 196.2) * projmeta.gravityMultiplier
						local projSpeed = (meta.launchVelocity or 100)
						local offsetpos = pos + (projmeta.projectile == 'owl_projectile' and Vector3.zero or projmeta.fromPositionOffset)
						local balloons = plr.Character:GetAttribute('InflatedBalloons')
						local playerGravity = workspace.Gravity
	
						if balloons and balloons > 0 then
							playerGravity = (workspace.Gravity * (1 - ((balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))))
						end
	
						if plr.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
							playerGravity = 6
						end
	
						if plr.Player:GetAttribute('IsOwlTarget') then
							for _, owl in collectionService:GetTagged('Owl') do
								if owl:GetAttribute('Target') == plr.Player.UserId and owl:GetAttribute('Status') == 2 then
									playerGravity = 0
								end
							end
						end
	
						local newlook = CFrame.new(offsetpos, plr[TargetPart.Value].Position) * CFrame.new(projmeta.projectile == 'owl_projectile' and Vector3.zero or Vector3.new(bedwars.BowConstantsTable.RelX, bedwars.BowConstantsTable.RelY, bedwars.BowConstantsTable.RelZ))
						local calc = prediction.SolveTrajectory(newlook.p, projSpeed, gravity, plr[TargetPart.Value].Position, projmeta.projectile == 'telepearl' and Vector3.zero or plr[TargetPart.Value].Velocity, playerGravity, plr.HipHeight, plr.Jumping and 42.6 or nil, rayCheck)
						if calc then
							targetinfo.Targets[plr] = tick() + 1
							return {
								initialVelocity = CFrame.new(newlook.Position, calc).LookVector * projSpeed,
								positionFrom = offsetpos,
								deltaT = lifetime,
								gravitationalAcceleration = gravity,
								drawDurationSeconds = 5
							}
						end
					end
	
					return old(...)
				end
			else
				bedwars.ProjectileController.calculateImportantLaunchValues = old
			end
		end,
		Tooltip = 'Silently adjusts your aim towards the enemy'
	})
	Targets = ProjectileAimbot:CreateTargets({
		Players = true,
		Walls = true
	})
	TargetPart = ProjectileAimbot:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head'}
	})
	FOV = ProjectileAimbot:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 1000
	})
	OtherProjectiles = ProjectileAimbot:CreateToggle({
		Name = 'Other Projectiles',
		Default = true
	})
end)

run(function()
	local ProjectileAura
	local Targets
	local Range
	local List
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Include
	local projectileRemote = {InvokeServer = function() end}
	local FireDelays = {}
	task.spawn(function()
		projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
	end)
	
	local function getAmmo(check)
		for _, item in store.inventory.inventory.items do
			if check.ammoItemTypes and table.find(check.ammoItemTypes, item.itemType) then
				return item.itemType
			end
		end
	end
	
	local function getProjectiles()
		local items = {}
		for _, item in store.inventory.inventory.items do
			local proj = bedwars.ItemMeta[item.itemType].projectileSource
			local ammo = proj and getAmmo(proj)
			if ammo and table.find(List.ListEnabled, ammo) then
				table.insert(items, {
					item,
					ammo,
					proj.projectileType(ammo),
					proj
				})
			end
		end
		return items
	end
	
	ProjectileAura = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileAura',
		Function = function(callback)
			if callback then
				repeat
					if true then
						local ent = entitylib.EntityPosition({
							Part = 'RootPart',
							Range = Range.Value,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled
						})
	
						if ent then
							local pos = entitylib.character.RootPart.Position
							for _, data in getProjectiles() do
								local item, ammo, projectile, itemMeta = unpack(data)
								if (FireDelays[item.itemType] or 0) < tick() then
									rayCheck.FilterDescendantsInstances = {workspace.Map}
									local meta = bedwars.ProjectileMeta[projectile]
									local projSpeed, gravity = meta.launchVelocity, meta.gravitationalAcceleration or 196.2
									local calc = prediction.SolveTrajectory(pos, projSpeed, gravity, ent.RootPart.Position, ent.RootPart.Velocity, workspace.Gravity, ent.HipHeight, ent.Jumping and 42.6 or nil, rayCheck)
									if calc then
										targetinfo.Targets[ent] = tick() + 1
										local switched = switchItem(item.tool)
	
										task.spawn(function()
											local dir, id = CFrame.lookAt(pos, calc).LookVector, httpService:GenerateGUID(true)
											local shootPosition = (CFrame.new(pos, calc) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))).Position
											bedwars.ProjectileController:createLocalProjectile(meta, ammo, projectile, shootPosition, id, dir * projSpeed, {drawDurationSeconds = 1})
											local res = projectileRemote:InvokeServer(item.tool, ammo, projectile, shootPosition, pos, dir * projSpeed, id, {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - 0.045)
											if not res then
												FireDelays[item.itemType] = tick()
											else
												local shoot = itemMeta.launchSound
												shoot = shoot and shoot[math.random(1, #shoot)] or nil
												if shoot then
													bedwars.SoundManager:playSound(shoot)
												end
											end
										end)
	
										FireDelays[item.itemType] = tick() + itemMeta.fireDelaySec
										if switched then
											task.wait(0.05)
										end
									end
								end
							end
						end
					end
					task.wait(0.1)
				until not ProjectileAura.Enabled
			end
		end,
		Tooltip = 'Shoots people around you'
	})
	Targets = ProjectileAura:CreateTargets({
		Players = true,
		Walls = true
	})
	List = ProjectileAura:CreateTextList({
		Name = 'Projectiles',
		Default = {'arrow', 'snowball'}
	})
	Range = ProjectileAura:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 50,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)

	
run(function()
    local Speed
    local SpeedValue
    local WallCheck
    local AutoJump
    local JumpHeight
    local AlwaysJump
    local JumpSound
    local VanillaJump
    local SlowdownAnim

    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true

    Speed = vape.Categories.Blatant:CreateModule({
        Name = 'Speed',
        Function = function(callback)
            frictionTable.Speed = callback or nil
            updateVelocity()
            pcall(function()
                debug.setconstant(bedwars.WindWalkerController.updateSpeed, 7, callback and 'constantSpeedMultiplier' or 'moveSpeedMultiplier')
            end)

            if callback then
                Speed:Clean(runService.PreSimulation:Connect(function(dt)
                    bedwars.StatefulEntityKnockbackController.lastImpulseTime = callback and math.huge or time()
                    if entitylib.isAlive and not Fly.Enabled and not InfiniteFly.Enabled and not LongJump.Enabled and isnetworkowner(entitylib.character.RootPart) then
                        local state = entitylib.character.Humanoid:GetState()
                        if state == Enum.HumanoidStateType.Climbing then return end

                        local root = entitylib.character.RootPart
                        local velo = getSpeed()
                        local moveDirection = AntiFallDirection or entitylib.character.Humanoid.MoveDirection
                        local destination = (moveDirection * math.max(SpeedValue.Value - velo, 0) * dt)

                        if WallCheck.Enabled then
                            rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
                            rayCheck.CollisionGroup = root.CollisionGroup
                            local ray = workspace:Raycast(root.Position, destination, rayCheck)
                            if ray then
                                destination = ((ray.Position + ray.Normal) - root.Position)
                            end
                        end

                        root.CFrame += destination
                        root.AssemblyLinearVelocity = (moveDirection * velo) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)

                        if SlowdownAnim.Enabled then
                            for _, anim in pairs(entitylib.character.Humanoid:GetPlayingAnimationTracks()) do
                                if anim.Name == "WalkAnim" or anim.Name == "RunAnim" then
                                    anim:AdjustSpeed(entitylib.character.Humanoid.WalkSpeed / 16)
                                end
                            end
                        end

                        if AutoJump.Enabled and (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed) 
                           and moveDirection ~= Vector3.zero and (Attacking or AlwaysJump.Enabled) then
                            if VanillaJump.Enabled then
                                entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                            else
                                local v = entitylib.character.HumanoidRootPart.Velocity
                                entitylib.character.HumanoidRootPart.Velocity = Vector3.new(v.X, JumpHeight.Value, v.Z)
                                if JumpSound.Enabled then
                                    pcall(function() entitylib.character.HumanoidRootPart.Jumping:Play() end)
                                end
                            end
                        end
                    end
                end))
            end
        end,
        ExtraText = function()
            return 'Heatseeker'
        end,
        Tooltip = 'Increases your movement'
    })

    SpeedValue = Speed:CreateSlider({
        Name = 'Speed',
        Min = 1,
        Max = 23,
        Default = 23,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })

    WallCheck = Speed:CreateToggle({
        Name = 'Wall Check',
        Default = true
    })

    JumpHeight = Speed:CreateSlider({
        Name = 'Jump Height',
        Min = 0,
        Max = 30,
        Default = 25
    })

    AlwaysJump = Speed:CreateToggle({
        Name = 'Always Jump',
        Default = false,
        Visible = false,
        Darker = true
    })

    JumpSound = Speed:CreateToggle({
        Name = 'Jump Sound',
        Default = false,
        Visible = false,
        Darker = true
    })

    VanillaJump = Speed:CreateToggle({
        Name = 'Real Jump',
        Default = false,
        Visible = false,
        Darker = true
    })

    AutoJump = Speed:CreateToggle({
        Name = 'AutoJump',
        Default = true,
        Function = function(callback)
            JumpHeight.Object.Visible = callback
            AlwaysJump.Object.Visible = callback
            JumpSound.Object.Visible = callback
            VanillaJump.Object.Visible = callback
        end
    })

    SlowdownAnim = Speed:CreateToggle({
        Name = 'Slowdown Anim',
        Default = false
    })
end)
run(function()
	local AutoKit
	local Legit
	local Toggles = {}
	local function kitCollection(id, func, range, specific)
		local objs = type(id) == 'table' and id or collection(id, AutoKit)
		repeat
			if entitylib.isAlive then
				local localPosition = entitylib.character.RootPart.Position
				for _, v in objs do
					if InfiniteFly.Enabled or not AutoKit.Enabled then break end
					local part = not v:IsA('Model') and v or v.PrimaryPart
					if part and (part.Position - localPosition).Magnitude <= (range) then
						func(v)
					end
				end
			end
			task.wait(0.1)
		until not AutoKit.Enabled
	end
	
	
		
	local AutoKitFunctions = {
		paladin = function()
			local t = 0
			if Legit.Enabled then
				t = 1.33
			else
				t = .85
			end
			local function getLowestHPPlayer()
				local lowestPlayer
				local lowestHP = math.huge

				for _, plr in ipairs(playersService:GetPlayers()) do
					if plr ~= lplr then
						local char = plr.Character
						local hum = char and char:FindFirstChildOfClass("Humanoid")

						if hum and hum.Health > 0 then
							if hum.Health < lowestHP then
								lowestPlayer = plr
							end
						end
					end
				end

				return lowestPlayer
			end
			AutoKit:Clean(lplr:GetAttributeChangedSignal("PaladinStartTime"):Connect(function()
				task.wait(t)
				if bedwars.AbilityController:canUseAbility('PALADIN_ABILITY') then
					local plr = getLowestHPPlayer()
					if plr.Character then
						bedwars.Client:Get("PaladinAbilityRequest"):SendToServer({target = plr})
					else
						bedwars.Client:Get("PaladinAbilityRequest"):SendToServer({})
					end	
					task.wait(0.022)
					bedwars.AbilityController:useAbility('PALADIN_ABILITY')
				end
			end))
		end,
		cyber = function()
			local notified = false
			local Dr = nil
			math.randomseed(os.time() * 1e9)
			local RNG = math.random(0,100)
			local ChanceEm = 0
			local ChanceDim = 0
			if Legit.Enabled then
				ChanceEm = 30
				ChanceDim = 15
			else
				ChanceEm = 51
				ChanceDim = 49
			end
			repeat
				if not entitylib.isAlive then
					task.wait(0.1)
					continue
				end
				local droneItem = getItem("drone")
				if not droneItem then
					notified = false
					task.wait(0.1)
					continue
				end
				if not workspace:FindFirstChild("drone") then
					if not notified then
						vape:CreateNotification("AutoKit", "Spawning drone...", 4)
						local DroneSlot = getObjSlot('drone')[1]
						local OGSlot = store.inventory.hotbarSlot
						local switched = hotbarSwitch(DroneSlot)
						if switched then
							task.wait(0.5)
							swithced = hotbarSwitch(OGSlot)
						end
						notified = true
					end
				else
					notified = false
				end
				AutoKit:Clean(workspace.ChildAdded:Connect(function(obj)
					if obj.Name == 'drone' then
						if obj:GetAttribute("PlayerUserId") == lplr.UserId then
							Dr = obj
						end
					end
				end))
				AutoKit:Clean(workspace.ItemDrops.ChildAdded:Connect(function(obj)
					if RNG >= ChanceEm then
						if obj.Name == 'emerald' then
							if Dr then
								RNG = math.random(0,100)
								Dr.HumanoidRootPart.CFrame = obj.CFrame + Vector3.new(0,5,0)
								task.wait(0.95)
								Dr.HumanoidRootPart.CFrame = entitylib.character.RootPart.CFrame + Vector3.new(2,3,0)
								bedwars.Client:Get("DropDroneItem"):SendToServer({
									position = entitylib.character.RootPart.CFrame + Vector3.new(0,5,0),
									direction = gameCamera.CFrame.LookVector
								})
							end
						end
					elseif RNG <= ChanceDim then
						if obj.Name == 'diamond' then
							if Dr then
								RNG = math.random(0,100)
								Dr.HumanoidRootPart.CFrame = obj.CFrame + Vector3.new(0,5,0)
								task.wait(0.95)
								Dr.HumanoidRootPart.CFrame = entitylib.character.RootPart.CFrame + Vector3.new(2,3,0)
								bedwars.Client:Get("DropDroneItem"):SendToServer({
									position = entitylib.character.RootPart.CFrame + Vector3.new(0,5,0),
									direction = gameCamera.CFrame.LookVector
								})
							end
						end
					else
						if obj.Name == 'emerald' then
							if Dr then
								RNG = math.random(0,100)
								Dr.HumanoidRootPart.CFrame = obj.CFrame + Vector3.new(0,5,0)
								task.wait(0.95)
								Dr.HumanoidRootPart.CFrame = entitylib.character.RootPart.CFrame + Vector3.new(2,3,0)
								bedwars.Client:Get("DropDroneItem"):SendToServer({
									position = entitylib.character.RootPart.CFrame + Vector3.new(0,5,0),
									direction = gameCamera.CFrame.LookVector
								})
							end
						end
					end
				end))
				AutoKit:Clean(workspace.ChildRemoved:Connect(function(obj)
					if obj.Name == 'drone' then
						if obj:GetAttribute("PlayerUserId") == lplr.UserId then
							if Dr then
								Dr = nil
							end
						end
					end
				end))
				task.wait(0.025)
			until not AutoKit.Enabled
			Dr = nil
		end,
		spearman = function()
			local function fireSpear(pos, spot, item)
				local projectileRemote = {InvokeServer = function() end}
				task.spawn(function()
					projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
				end)
				if item then		
					local spear = getObjSlot('spear')
					switchHotbar(spear)
					local meta = bedwars.ProjectileMeta.spear
					local calc = prediction.SolveTrajectory(pos, meta.launchVelocity, meta.gravitationalAcceleration, spot, Vector3.zero, workspace.Gravity, 0, 0)
					if calc then
						local dir = CFrame.lookAt(pos, calc).LookVector * meta.launchVelocity
						bedwars.ProjectileController:createLocalProjectile(meta, 'spear', 'spear', pos, nil, dir, {drawDurationSeconds = 1})
						projectileRemote:InvokeServer(item.tool, 'spear', 'spear', pos, pos, dir, httpService:GenerateGUID(true), {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - 0.045)
					end
				end
			end
			repeat
				if not entitylib.isAlive then task.wait(0.1); continue end
				local spearTool = getItem("spear")


				if not spearTool then task.wait(0.1) continue end

				local plr = entitylib.EntityPosition({
					Range = Legit.Enabled and 15 or (15*2),
					Part = "RootPart",
					Players = true,
					Sort = sortmethods.Health
				})

				if plr and (lplr.Character:GetAttribute("Health") or 0) > 0 then
					local pos = plr.RootPart.Position
					local spot = plr.RootPart.Velocity
					if spearTool then
						fireSpear(pos,spot,spearTool)
					end
		        end
				
				task.wait(.025)
		    until not AutoKit.Enabled
		end,
		owl = function()
			local isWhispering = false
			AutoKit:Clean(bedwars.Client:Get("OwlSummoned"):Connect(function(data)
				if data ~= lplr then
				local target = playersService:GetPlayerFromUserID(workspace:WaitForChild("ServerOwl"):GetAttribute("Target"))
				local chr = target.Character
				local hum = chr:FindFirstChild('Humanoid')
				local root = chr:FindFirstChild('HumanoidRootPart')
				isWhispering = true
				repeat
					local plr = entitylib.EntityPosition({
						Range = Legit.Enabled and (23/1.215) or 32,
						Part = "RootPart",
						Players = true,
						Sort = sortmethods.Health
					})
					rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiVoidPart}
					rayCheck.CollisionGroup = root.CollisionGroup
					task.spawn(function()
						if root.Velocity.Y <= Legit.Enabled and -130 or -90 and not workspace:Raycast(root.Position, Vector3.new(0, -100, 0), rayCheck) then
							WhisperController:request("Fly")
						end
					end)
					task.spawn(function()
						if (hum.MaxHealth - hum.Health) >= Legit.Enabled and 45 or 85 then
							WhisperController:request("Heal")
						end
					end)
					task.spawn(function()
						if plr then
							WhisperController:request("Shoot",workspace:FindFirstChild("ClientOwl").Handle,plr,lplr)
						end
					end)	
					task.wait(0.05)
				until not isWhispering or not AutoKit.Enabled
				end
			end))
			AutoKit:Clean(bedwars.Client:Get("OwlDeattached"):Connect(function(data)
				if data ~= lplr then
					isWhispering = false
				end
			end))
		end,
		winter_lady = function()
			local projectileRemote = {InvokeServer = function() end}
			task.spawn(function()
				projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
			end)
			local function fireStaff(pos, spot, item,staff)
				if item then
					local meta = bedwars.ProjectileMeta[staff]
					local calc = prediction.SolveTrajectory(pos, meta.launchVelocity, meta.gravitationalAcceleration, spot, Vector3.zero, workspace.Gravity, 0, 0)
					if calc then
						local dir = CFrame.lookAt(pos, calc).LookVector * meta.launchVelocity
						bedwars.ProjectileController:createLocalProjectile(meta, staff, staff, pos, nil, dir, {drawDurationSeconds = 1})
						projectileRemote:InvokeServer(item.tool, staff, staff, pos, pos, dir, httpService:GenerateGUID(true), {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - 0.045)
					end
				end
			end

			local function Shoot(plr)
				if plr == nil then return end
				local str = "frost_staff"
				local fireStaffStr = ""
				local fullstr = ""
				for i, v in replicatedStorage.Inventories[lplr.Name]:GetChildren() do
					if string.find(v.Name, str) then
						fullstr = v.Name
					end
				end
				if fullstr == "frost_staff_1" then
					FireStaffStr = "frosty_snowball_1"
				elseif fullstr == "frost_staff_2" then
					FireStaffStr = "frosty_snowball_2"
				elseif fullstr == "frost_staff_3" then
					FireStaffStr = "frosty_snowball_3"
				else
					FireStaffStr = "frosty_snowball_1" -- fallback if im retarded
				end
				fireStaff(plr.RootPart.Position,plr.RootPart.Velocity,getItem(fullstr),fireStaffStr)
			end
			local holding = false
			local function Hold(plr)
				if plr == nil then
					if holding then
						holding = false
						bedwars.Client:Get("FrostyGunFireActionRequest"):SendToServer({ keyHold = false })
					end
					return
				end

				if holding then return end

				holding = true
				bedwars.Client:Get("FrostyGunFireActionRequest"):SendToServer({ keyHold = true })
				task.wait(0.00456) -- math fucking sucks istg
				bedwars.Client:Get("FrostyGunFire"):SendToServer({
					userPosition = entitylib.character.RootPart.Position,
					direction = gameCamera.CFrame
				})
			end                      
			repeat
				if not entitylib.isAlive then task.wait(0.1); continue end

				local plr = entitylib.EntityPosition({
					Range = Legit.Enabled and (23/1.18) or 32,
					Part = "RootPart",
					Players = true,
					Sort = sortmethods.Health
				})
				local gui = lplr.PlayerGui:FindFirstChild("FrostyGunGUI")
				if not gui then continue end

				for _, v in gui:GetChildren() do
					if v:IsA("ImageLabel") and v.Name == "AbilityIcon" then
						if v.Image == "rbxassetid://11611911951" then
							if plr and (lplr.Character:GetAttribute("Health") or 0) > 0 then
								Hold(plr)
							else
								Hold(nil)
							end
						elseif v.Image == "rbxassetid://139613766654382" then
							if plr and (lplr.Character:GetAttribute("Health") or 0) > 0 then
								Shoot(plr)
							else
								Shoot(nil)
							end
						else
							if plr and (lplr.Character:GetAttribute("Health") or 0) > 0 then
								Hold(plr) -- another fallback if im retarded
							else
								Hold(nil)
							end
						end
					end
				end

				task.wait(.4533)
		    until not AutoKit.Enabled
		end,
		void_walker = function()
			repeat
				if not entitylib.isAlive then task.wait(0.1); continue end

				local plr = entitylib.EntityPosition({
					Range = Legit.Enabled and (23/2.125) or 23,
					Part = "RootPart",
					Players = true,
					Sort = sortmethods.Health
				})

				if plr and (lplr.Character:GetAttribute("Health") or 0) > 0 then
					if bedwars.AbilityController:canUseAbility('void_walker_warp') then
						bedwars.AbilityController:useAbility('void_walker_warp')
					end
		        end
				
				if lplr.Character:GetAttribute('Health') <= Legit.Enabled and 56 or 64 then
					if bedwars.AbilityController:canUseAbility('void_walker_rewind') then
						bedwars.AbilityController:useAbility('void_walker_rewind')
					end
				end

				task.wait(.233)
		    until not AutoKit.Enabled
		end,
		falconer = function()
			local canRecall = true
			repeat
				if not entitylib.isAlive then task.wait(0.1); continue end

				local plr = entitylib.EntityPosition({
					Range = Legit.Enabled and 32 or 100,
					Part = "RootPart",
					Players = true,
					Sort = sortmethods.Health,
					WallCheck = Legit.Enabled
				})

				if plr and (lplr.Character:GetAttribute("Health") or 0) > 0 then
					if plr.RootPart:FindFirstChild("BillboardGui") then continue end
					if bedwars.AbilityController:canUseAbility('SEND_FALCON') then
						canRecall = true
						bedwars.AbilityController:useAbility('SEND_FALCON',newproxy(true),{
							target = plr.RootPart.Position
						})
					end
				else
					if bedwars.AbilityController:canUseAbility('RECALL_FALCON') and canRecall then
						canRecall = false
						bedwars.AbilityController:useAbility('RECALL_FALCON')
					end													
		        end
				
				task.wait(.233)
		    until not AutoKit.Enabled
		end,
		styx = function()
			local r = 0
			if Legit.Enabled then
				r = 6
			else
				r = 12
			end
			local uuid  = ""
			bedwars.Client:Get("StyxOpenExitPortalFromServer"):Connect(function(v1)
				uuid = v1.exitPortalData.connectedEntrancePortalUUID
			end)
			kitCollection(lplr.Name..":styx_entrance_portal", function(v)
				bedwars.Client:Get("UseStyxPortalFromClient"):SendToServer({
					entrancePortalData = {
						proximityPrompt = v:WaitForChild('ProximityPrompt'),
						uuid = uuid,
						blockPosition = bedwars.BlockController:getBlockPosition(v.Position),
						whirpoolSpinHeartbeatConnection = (nil --[[ RBXScriptConnection | IsConnected: true ]]),
						blockUUID = v:GetAttribute("BlockUUID"),
						beam = workspace:WaitForChild("StyxPortalBeam"),
						worldPosition = bedwars.BlockController:getWorldPosition(v.Position),
						teamId = entitylib.character:GetAttribute("Team")					
					}
				})
			end, r, false)
			AutoKit:Clean(workspace.ChildAdded:Connect(function(obj)
				if obj.Name == "StyxPortal" then
					local MaxStuds = Legit.Enabled and 8 or 16
					local NewDis = (obj.Pivot.Position - entitylib.character.RootPart.Position).Magnitude
					if NewDis <= MaxStuds then
						local args = {uuid}
						replicatedStorage:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("StyxTryOpenExitPortalFromClient"):InvokeServer(unpack(args))
					end
				end
			end))
		end,
		elektra = function()
			repeat
				if not entitylib.isAlive then task.wait(0.1); continue end

				local plr = entitylib.EntityPosition({
					Range = Legit.Enabled and 5 or 10,
					Part = "RootPart",
					Players = true,
					Sort = sortmethods.Health
				})

				if plr and (lplr.Character:GetAttribute("Health") or 0) > 0 then
					if bedwars.AbilityController:canUseAbility('ELECTRIC_DASH') then
						bedwars.AbilityController:useAbility('ELECTRIC_DASH')
					end																		
		        end
				
				task.wait(.833)
		    until not AutoKit.Enabled
		end,
		taliyah = function()
			local r = 0
			if Legit.Enabled then
				r = 5
			else
				r = 10
			end
			kitCollection('entity', function(v)
				if bedwars.Client:Get('CropHarvest'):CallServer({position = bedwars.BlockController:getBlockPosition(v.Position)}) then
					if Legit.Enabled then
						bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.PUNCH)
						bedwars.SoundManager:playSound(bedwars.SoundList.CROP_HARVEST)
					end
				end
			end, r, false)
		end,
		black_market_trader = function()
			local r = 0
			if Legit.Enabled then
				r = 8
			else
				r = 16
			end
			kitCollection('shadow_coin', function(v)
			    bedwars.Client:Get("CollectCollectableEntity"):SendToServer({id = v:GetAttribute("Id"),collectableName = 'shadow_coin'})
			end, r, false)
		end,
		oasis = function()
			repeat
				if not entitylib.isAlive then task.wait(0.1); continue end

				local plr = entitylib.EntityPosition({
					Range = Legit.Enabled and 8 or 18,
					Part = "RootPart",
					Players = true,
					Sort = sortmethods.Health
				})

				if plr and (lplr.Character:GetAttribute("Health") or 0) > 0 then
					if bedwars.AbilityController:canUseAbility('oasis_swap_staff') then
						local str = "oasis"
						local fullstr = ""
						for i, v in replicatedStorage.Inventories[lplr.Name]:GetChildren() do
							if string.find(v.Name, str) then
								fullstr = v.Name
							end
						end
						local slot = getObjSlot(fullstr)
						local ogslot = GetOriginalSlot()
						switchHotbar(slot)
						bedwars.AbilityController:useAbility('oasis_swap_staff')
						task.wait(0.225)
						switchHotbar(ogslot)
					end																		
		        end

				if lplr.Character:GetAttribute('Health') <= Legit.Enabled and 32 or 50 then
					if bedwars.AbilityController:canUseAbility('oasis_heal_veil') then
						bedwars.AbilityController:useAbility('oasis_heal_veil')
					end
				end
				
				task.wait(.223)
		    until not AutoKit.Enabled
		end,
		spirit_summoner = function()
			local projectileRemote = {InvokeServer = function() end}
			task.spawn(function()
				projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
			end)
			local function fireStaff(pos, spot, item,slot)
				if item then
					local staff = 'spirit_staff'	
					local originalSlot = store.inventory.hotbarSlot
					switchHotbar(slot)
					local meta = bedwars.ProjectileMeta[staff]
					local calc = prediction.SolveTrajectory(pos, meta.launchVelocity, meta.gravitationalAcceleration, spot, Vector3.zero, workspace.Gravity, 0, 0)
					if calc then
						local dir = CFrame.lookAt(pos, calc).LookVector * meta.launchVelocity
						bedwars.ProjectileController:createLocalProjectile(meta, staff, staff, pos, nil, dir, {drawDurationSeconds = 1})
						projectileRemote:InvokeServer(item.tool, staff, staff, pos, pos, dir, httpService:GenerateGUID(true), {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - 0.045)
					end
				end
			end
			repeat
				if not entitylib.isAlive then task.wait(0.1); continue end
				local stone = getItem("summon_stone")
				local staff = getItem("spirit_staff")
				if not stone or not staff then task.wait(0.1) continue end
				local gen = GetNearGen(Legit.Enabled,entitylib.character.RootPart.Position)
				local pos = gen
				if gen then
					if bedwars.AbilityController:canUseAbility('summon_attack_spirit') then
						bedwars.AbilityController:useAbility('summon_attack_spirit')
					end
					task.wait(0.1)
					fireStaff(pos,entitylib.character.RootPart.Velocity,staff,getObjSlot('spirit_staff'))
				end
				if lplr.Character:GetAttribute('Health') <= Legit.Enabled and 40 or 56 then
					if bedwars.AbilityController:canUseAbility('summon_heal_spirit') then
						bedwars.AbilityController:useAbility('summon_heal_spirit')
					end
				end
				task.wait(.45)
		    until not AutoKit.Enabled
		end,
		rebellion_leader = function()
			repeat
				if not entitylib.isAlive then task.wait(0.1); continue end

				local plr = entitylib.EntityPosition({
					Range = Legit.Enabled and 15 or 25,
					Part = "RootPart",
					Players = true,
					Sort = sortmethods.Health
				})

				if plr and (lplr.Character:GetAttribute("Health") or 0) > 0 then
					if bedwars.AbilityController:canUseAbility('rebellion_aura_swap') then
						bedwars.AbilityController:useAbility('rebellion_aura_swap')
					end																		
		        end
				local t = 0
				t = Legit.Enabled and 45 or 65
				if lplr.Character:GetAttribute('Health') <= t then
					if bedwars.AbilityController:canUseAbility('rebellion_shield') then
						bedwars.AbilityController:useAbility('rebellion_shield')
					end
				end
				
				task.wait(.45)
		    until not AutoKit.Enabled
		end,
		ninja = function()
			local projectileRemote = {InvokeServer = function() end}
			task.spawn(function()
				projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
			end)
			local function fireUmeko(pos, spot, item,slot,charm)
				if item then		
					local originalSlot = store.inventory.hotbarSlot
					switchHotbar(slot)
					local meta = bedwars.ProjectileMeta[charm]
					local calc = prediction.SolveTrajectory(pos, meta.launchVelocity, meta.gravitationalAcceleration, spot, Vector3.zero, workspace.Gravity, 0, 0)
					if calc then
						local dir = CFrame.lookAt(pos, calc).LookVector * meta.launchVelocity
						bedwars.ProjectileController:createLocalProjectile(meta, charm, charm, pos, nil, dir, {drawDurationSeconds = 1})
						projectileRemote:InvokeServer(item.tool, charm, charm, pos, pos, dir, httpService:GenerateGUID(true), {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - 0.045)
					end
				end
			end
			local function getCharm()
				local items = inv or store.inventory.inventory.items
				if not items then return end

				for _, item in pairs(items) do
					if item.itemType and item.itemType:lower():find("chakram") then
						return item.itemType
					end
				end
			end
			local function getCharmSlot(charmType)
				if not charmType then return end
				return getObjSlot(charmType)
			end
			repeat
				if not entitylib.isAlive then
					task.wait(0.1)
					continue
				end

				local charm = getCharm()
				local charmSlot = getCharmSlot(charm)

				if not charm then
					task.wait(0.1)
					continue
				end

				local plr = entitylib.EntityPosition({
					Range = Legit.Enabled and 23 or 32,
					Part = "RootPart",
					Players = true,
					Sort = sortmethods.Health
				})

				if plr and (lplr.Character:GetAttribute("Health") or 0) > 0 then
					fireUmeko(plr.RootPart.Position,plr.RootPart.Velocity,item,charmSlot,charm)
				end

				task.wait(0.025)
			until not AutoKit.Enabled
		end,
		frosty = function()
			local function fireball(pos, spot, item)
				local projectileRemote = {InvokeServer = function() end}
				task.spawn(function()
					projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
				end)
				if item then		
					local snowball = getObjSlot('frosted_snowball')
					local originalSlot = store.inventory.hotbarSlot
					switchHotbar(snowball)
					local meta = bedwars.ProjectileMeta.frosted_snowball
					local calc = prediction.SolveTrajectory(pos, meta.launchVelocity, meta.gravitationalAcceleration, spot, Vector3.zero, workspace.Gravity, 0, 0)
					if calc then
						local dir = CFrame.lookAt(pos, calc).LookVector * meta.launchVelocity
						bedwars.ProjectileController:createLocalProjectile(meta, 'frosted_snowball', 'frosted_snowball', pos, nil, dir, {drawDurationSeconds = 1})
						projectileRemote:InvokeServer(item.tool, 'frosted_snowball', 'frosted_snowball', pos, pos, dir, httpService:GenerateGUID(true), {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - 0.045)
					end
				end
			end
			repeat
				if not entitylib.isAlive then task.wait(0.1); continue end
				local SnowBallTool = getItem("frosted_snowball")


				if not SnowBallTool then task.wait(0.1) continue end

				local plr = entitylib.EntityPosition({
					Range = Legit.Enabled and 10 or 15,
					Part = "RootPart",
					Players = true,
					Sort = sortmethods.Health
				})

				if plr and (lplr.Character:GetAttribute("Health") or 0) > 0 then
					local pos = plr.RootPart.Position
					local spot = plr.RootPart.Velocity
					if SnowBallTool then
						fireball(pos,spot,SnowBallTool)
					end
		        end
				
				task.wait(.025)
		    until not AutoKit.Enabled
		end,
		cowgirl = function()
			local projectileRemote = {InvokeServer = function() end}
			task.spawn(function()
				projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
			end)
			local function fireLasso(pos, spot, item)
				if item then		
					local lasso = getObjSlot('lasso')
					local originalSlot = store.inventory.hotbarSlot
					switchHotbar(lasso)
					local meta = bedwars.ProjectileMeta.lasso
					local calc = prediction.SolveTrajectory(pos, meta.launchVelocity, meta.gravitationalAcceleration, spot, Vector3.zero, workspace.Gravity, 0, 0)
					if calc then
						local dir = CFrame.lookAt(pos, calc).LookVector * meta.launchVelocity
						bedwars.ProjectileController:createLocalProjectile(meta, 'lasso', 'lasso', pos, nil, dir, {drawDurationSeconds = 1})
						projectileRemote:InvokeServer(item.tool, 'lasso', 'lasso', pos, pos, dir, httpService:GenerateGUID(true), {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - 0.045)     
					end
				end
			end
			repeat
				if not entitylib.isAlive then task.wait(0.1); continue end
				local lassoTool = getItem("lasso")


				if not lassoTool then task.wait(0.1) continue end

				local plr = entitylib.EntityPosition({
					Range = Legit.Enabled and 15 or 25,
					Part = "RootPart",
					Players = true,
					Sort = sortmethods.Health
				})

				if plr and (lplr.Character:GetAttribute("Health") or 0) > 0 then
					local pos = plr.RootPart.Position
					local spot = plr.RootPart.Velocity
					if lassoTool then
						fireLasso(pos,spot,lassoTool)
					end
		        end
				
				task.wait(.45)
		    until not AutoKit.Enabled
		end,
		sheep_herder = function()
			local r = 0
			if Legit.Enabled then
				r = 8
			else
				r = 16
			end
			kitCollection('sheep', function(v)
				local args = {[1] = v}
				replicatedStorage:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild('@rbxts'):WaitForChild('net'):WaitForChild('out'):WaitForChild('_NetManaged'):WaitForChild('SheepHerder/TameSheep'):FireServer(unpack(args))
			end, r, false)
		end,
		regent = function()
			repeat
				if not entitylib.isAlive then task.wait(0.1); continue end
				local axe = getItem("void_axe")

				if not axe then task.wait(0.1) continue end

				local Sword = getSwordSlot()
				local Axe = getObjSlot('void_axe')
				local originalSlot = store.inventory.hotbarSlot

				local plr = entitylib.EntityPosition({
					Range = Legit.Enabled and 15 or 25,
					Part = "RootPart",
					Players = true,
					Sort = sortmethods.Health
				})

				if plr and (lplr.Character:GetAttribute("Health") or 0) > 0 then
					if bedwars.AbilityController:canUseAbility('void_axe_jump') then
						switchHotbar(Axe)
						bedwars.AbilityController:useAbility('void_axe_jump')
						task.wait(0.23)
						switchHotbar(originalSlot)
					end																		
		        end
				
				task.wait(.45)
		    until not AutoKit.Enabled
		end,
		jade = function()

			repeat
				if not entitylib.isAlive then task.wait(0.1); continue end
				local ham = getItem("jade_hammer")
				local originalSlot = store.inventory.hotbarSlot
				if not ham then task.wait(0.1) continue end

				local Sword = getSwordSlot()
				local Ham = getObjSlot('jade_hammer')

				local plr = entitylib.EntityPosition({
					Range = Legit.Enabled and 13 or 18,
					Part = "RootPart",
					Players = true,
					Sort = sortmethods.Health
				})

				if plr and (lplr.Character:GetAttribute("Health") or 0) > 0 then
					if bedwars.AbilityController:canUseAbility('jade_hammer_jump') then
						switchHotbar(Ham)
						bedwars.AbilityController:useAbility('jade_hammer_jump')
						task.wait(0.23)
						switchHotbar(originalSlot)
					end																		
		        end
				
				task.wait(.45)
		    until not AutoKit.Enabled
		end,
		yeti = function()
			local function getBedNear()
				local localPosition = entitylib.isAlive and entitylib.character.RootPart.Position or Vector3.zero
				for _, v in collectionService:GetTagged("bed") do
					if (localPosition - v.Position).Magnitude < Legit.Enabled and (15/1.95) or 15 then
						if v:GetAttribute("Team" .. (lplr:GetAttribute("Team") or -1) .. "NoBreak") then 
							return nil 
						end
						return v
					end
				end
			end
			repeat
				if not entitylib.isAlive then task.wait(0.1); continue end
				local bed = getBedNear()

				if bed then
					if bedwars.AbilityController:canUseAbility('yeti_glacial_roar') then
						bedwars.AbilityController:useAbility('yeti_glacial_roar')
					end	
				end
				task.wait(.45)
		    until not AutoKit.Enabled
		end,
		dragon_sword = function()
		    repeat
			    if not entitylib.isAlive then task.wait(0.1); continue end
				local plr = entitylib.EntityPosition({
					Range = Legit.Enabled and 5 or 10,
					Part = "RootPart",
					Players = true,
					Sort = sortmethods.Health
				})
				local plr2 = entitylib.EntityPosition({
					Range = Legit.Enabled and 15 or 30,
					Part = "RootPart",
					Players = true,
					Sort = sortmethods.Health
				})
				if plr and (lplr.Character:GetAttribute("Health") or 0) > 0 then
					if bedwars.AbilityController:canUseAbility('dragon_sword') then
						bedwars.AbilityController:useAbility('dragon_sword')
					end																		
		        end
				
				if plr2 and (lplr.Character:GetAttribute("Health") or 0) > 0 then
					if bedwars.AbilityController:canUseAbility('dragon_sword_ult') then
						bedwars.AbilityController:useAbility('dragon_sword_ult')
					end																		
		        end
		        task.wait(.45)
		    until not AutoKit.Enabled
		end,
		defender = function()
		    repeat
			    if not entitylib.isAlive then task.wait(0.1); continue end
				local handItem = lplr.Character:FindFirstChild('HandInvItem')
				local hasScanner = false
				if handItem and handItem.Value then
					local itemType = handItem.Value.Name
					hasScanner = itemType:find('defense_scanner')
				end
				
				if not hasScanner then
					task.wait(0.1)
					continue
				end

				for i, v in workspace:GetChildren() do
					if v:IsA("BasePart") then
						if v.Name == "DefenderSchematicBlock" then
							v.Transparency = 0.85
							v.Grid.Transparency = 1
							local BP = bedwars.BlockController:getBlockPosition(v.Position)
							bedwars.Client:Get("DefenderRequestPlaceBlock"):CallServer({["blockPos"] = BP})
							pcall(function()
								local sounds = {
									bedwars.SoundList.DEFENDER_UPGRADE_DEFENSE_04,
									bedwars.SoundList.DEFENDER_UPGRADE_DEFENSE_03,
									bedwars.SoundList.DEFENDER_UPGRADE_DEFENSE_02,
									bedwars.SoundList.DEFENDER_UPGRADE_DEFENSE_01
								}

								for i = 4, 1, -1 do
									bedwars.SoundManager:playSound(sounds[i], {
										position = BP,
										playbackSpeedMultiplier = 0.8
									})
									task.wait(0.082)
								end
							end)
							
							task.wait(Legit.Enabled and math.random(1,2) - math.random() or (0.5 - math.random()))
						end
					end
				end

				AutoKit:Clean(workspace.ChildAdded:Connect(function(v)
					if v:IsA("BasePart") then
						if v.Name == "DefenderSchematicBlock" then
							v.Transparency = 0.85
							v.Grid.Transparency = 1
							local BP = bedwars.BlockController:getBlockPosition(v.Position)
							bedwars.Client:Get("DefenderRequestPlaceBlock"):SendToServer({["blockPos"] = BP})
							pcall(function()
								local sounds = {
									bedwars.SoundList.DEFENDER_UPGRADE_DEFENSE_04,
									bedwars.SoundList.DEFENDER_UPGRADE_DEFENSE_03,
									bedwars.SoundList.DEFENDER_UPGRADE_DEFENSE_02,
									bedwars.SoundList.DEFENDER_UPGRADE_DEFENSE_01
								}

								for i = 4, 1, -1 do
									bedwars.SoundManager:playSound(sounds[i], {
										position = BP,
										playbackSpeedMultiplier = 0.8
									})
									task.wait(0.082)
								end
							end)
							
							task.wait(math.random(1,2) - math.random())
						end
					end
				end))
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		shielder = function()
			local Distance = 0
			if Legit.Enabled then
				Distance = 32 / 2
			else
				Distance = 32
			end
			AutoKit:Clean(workspace.DescendantAdded:Connect(function(arrow)
				if not AutoKit.Enabled then return end
				if (arrow.Name == "crossbow_arrow" or arrow.Name == "arrow" or arrow.Name == "headhunter_arrow") and arrow:IsA("Model") then
					if arrow:GetAttribute("ProjectileShooter") == lplr.UserId then return end
					local root = arrow:FindFirstChildWhichIsA("BasePart")
					if not root then return end
					local NewDis = (lplr.Character.HumanoidRootPart.Position - root.Position).Magnitude
					while root and root.Parent do
						NewDis = (lplr.Character.HumanoidRootPart.Position - root.Position).Magnitude
						if NewDis <= Distance then
							local shield = getObjSlot('infernal_shield')
							local originalSlot = store.inventory.hotbarSlot
							switchHotbar(shield)
							task.wait(0.125)
							switchHotbar(originalSlot)
						end
						task.wait(0.05)
					end
				end
			end))
		end,
        alchemist = function()
			local r= 0
						if Legit.Enabled then
				r = 8
			else
				r = 16
			end
			kitCollection('alchemist_ingedients', function(v)
			    bedwars.Client:Get("CollectCollectableEntity"):SendToServer({id = v:GetAttribute("Id"),collectableName = v.Name})
			end, r, false)
        end,
        midnight = function()
			local old = nil
		    repeat
			    if not entitylib.isAlive then task.wait(0.1); continue end
				local root = entitylib.character.RootPart
				if not root then continue end
				
				local plr = entitylib.EntityPosition({
					Range = Legit.Enabled and (18/(1.995 + math.random())) or 18,
					Part = "RootPart",
					Players = true,
					Sort = sortmethods.Health
				})
				if plr and (not Legit.Enabled or (lplr.Character:GetAttribute("Health") or 0) > 0) then
					if bedwars.AbilityController:canUseAbility('midnight') then
						bedwars.AbilityController:useAbility('midnight')
						old = bedwars.SwordController.isClickingTooFast
						bedwars.SwordController.isClickingTooFast = function(self)
							self.lastSwing = 45.812 / 1.25
							return false
						end
						local T = Legit.Enabled and 4.5 or 6.45
                        Speed:Toggle(true)
                        task.wait(T)
                        Speed:Toggle(false)
						task.wait(11)
						bedwars.SwordController.isClickingTooFast = old
						old = nil
					end																		
		        end
		
		        task.wait(.45)
		    until not AutoKit.Enabled
        end,
		sorcerer = function()
			local r = 0
						if Legit.Enabled then
				r = 8
			else
				r = 16
			end
			kitCollection('alchemy_crystal', function(v)
			    bedwars.Client:Get("CollectCollectableEntity"):SendToServer({id = v:GetAttribute("Id"),collectableName = v.Name})
			end, r, false)
		end,
		berserker = function()
			local mapCFrames = workspace:FindFirstChild("MapCFrames")
			local teamid = lplr.Character:GetAttribute("Team")
		
			if mapCFrames then
					for _, obj in pairs(mapCFrames:GetChildren()) do
						if obj:IsA("CFrameValue") and string.match(obj.Name, "_bed") then
							if not string.match(obj.Name, teamid .. "_bed") then
								local part = Instance.new("Part")
								part.Transparency = 1
								part.CanCollide = false
								part.Anchored = true
								part.Size = Legit.Enabled and Vector3.new(48, 48, 48) or Vector3.new(72, 72, 72)
								part.CFrame = obj.Value
								part.Parent = workspace
								part.Name = "AutoKitRagnarPart"
								part.Touched:Connect(function(v)
									if v.Parent.Name == lplr.Name then
										if bedwars.AbilityController:canUseAbility('berserker_rage') then
											bedwars.AbilityController:useAbility('berserker_rage')
											if not Legit.Enabled and not FastBreak.Enabled then
												repeat
													bedwars.BlockBreakController.blockBreaker:setCooldown(0.185)
													task.wait(0.1)
												until not bedwars.AbilityController:canUseAbility('berserker_rage')
												task.wait(0.0125)
												bedwars.BlockBreakController.blockBreaker:setCooldown(0.3)
											end
										end																																
									end
								end)
							end
						end
					end
			end

			AutoKit:Clean(function()
				for i,v in workspace:GetChildren() do
					if v:IsA("BasePart") and v.Name == "AutoKitRagnarPart" then
					v:Destory()
					end
				end
			end)
		
		end,																																																								
		glacial_skater = function()
		    repeat
			    if not entitylib.isAlive then task.wait(0.1); continue end
				if Legit.Enabled then
					bedwars.Client:Get("MomentumUpdate"):SendToServer({['momentumValue'] = 100})
				else
					bedwars.Client:Get("MomentumUpdate"):SendToServer({['momentumValue'] = 9e9})
				end
		        task.wait(0.1)
		    until not AutoKit.Enabled
		end,
		cactus = function()
		    repeat
			    if not entitylib.isAlive then task.wait(0.1); continue end
				local root = entitylib.character.RootPart
				if not root then continue end
				
				local plr = entitylib.EntityPosition({
					Range = Legit.Enabled and (16/1.54) or 16,
					Part = "RootPart",
					Players = true,
					Sort = sortmethods.Health
				})
				if plr then
					if bedwars.AbilityController:canUseAbility('cactus_fire') then
						bedwars.AbilityController:useAbility('cactus_fire')
					end																		
		        end
		
		        task.wait(1)
		    until not AutoKit.Enabled
		end,
		card = function()
		    repeat
			    if not entitylib.isAlive then task.wait(0.1); continue end
				local root = entitylib.character.RootPart
				if not root then continue end
				
				local plr = entitylib.EntityPosition({
					Range = Legit.Enabled and (20/3.2) or 20,
					Part = "RootPart",
					Players = true,
					Sort = sortmethods.Health
				})
				if plr then
		          bedwars.Client:Get("AttemptCardThrow"):SendToServer({
		                ["targetEntityInstance"] = plr.Character
		            })
		        end
		
		        task.wait(0.5)
		    until not AutoKit.Enabled
		end,																																																					
		void_hunter = function()
		    repeat
			    if not entitylib.isAlive then task.wait(0.1); continue end
				local plr = entitylib.EntityPosition({
					Range = Legit.Enabled and (20/2.8) or 20,
					Part = "RootPart",
					Players = true,
					Sort = sortmethods.Health
				})
				
				if plr and (not Legit.Enabled or (lplr.Character:GetAttribute("Health") or 0) > 0) then
		        	bedwars.Client:Get("VoidHunter_MarkAbilityRequest"):SendToServer({
		            	["originPosition"] = lplr.Character.PrimaryPart.Position,
		            	["direction"] = workspace.CurrentCamera.CFrame.LookVector
		        	})
		        	Speed:Toggle(true)
					task.wait(3)
					Speed:Toggle(false)
			end
			task.wait(0.5)
			until not AutoKit.Enabled	
		end,																																																									
		skeleton = function()
		    repeat
			    if not entitylib.isAlive then task.wait(0.1); continue end
				local plr = entitylib.EntityPosition({
					Range = Legit.Enabled and 5.235 or 10,
					Part = "RootPart",
					Players = true,
					Sort = sortmethods.Health
				})
			
				if plr and (not Legit.Enabled or (lplr.Character:GetAttribute("Health") or 0) > 0) then
						if bedwars.AbilityController:canUseAbility('skeleton_ability') then
							bedwars.AbilityController:useAbility('skeleton_ability')
						end																																
					Speed:Toggle(true)
					task.wait(3)
					Speed:Toggle(false)
				end
				task.wait(0.5)
	    	until not AutoKit.Enabled		
		end,
		drill = function()
			repeat
				if not entitylib.isAlive then task.wait(0.1); continue end
				local root = entitylib.character.RootPart
				local drills = {}
				
				for _, obj in ipairs(workspace:GetDescendants()) do
					if obj.Name == "Drill" then
						table.insert(drills, obj)
					end
				end
			
				if #drills == 0 then
					continue
				end
			
				for _, drillObj in ipairs(drills) do
					if Legit.Enabled then
						if drillObj:FindFirstChild("RootPart") then
							local drillRoot = drillObj.RootPart
							if (drillRoot.Position - root.Position).Magnitude <= 15 then
								bedwars.Client:Get('ExtractFromDrill'):SendToServer({
									drill = drillObj
								})
							end
						end
					else
						bedwars.Client:Get('ExtractFromDrill'):SendToServer({
							drill = drillObj
						})
					end
				end
		
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		airbender = function()
			repeat
				if not entitylib.isAlive then task.wait(0.1); continue end
				local root = entitylib.character.RootPart
				if not root then continue end
			
					local plr = entitylib.EntityPosition({
						Range = Legit.Enabled and 14 and 25,
						Part = "RootPart",
						Players = true,
						Sort = sortmethods.Health
					})
			
					local plr2 = entitylib.EntityPosition({
						Range = Legit.Enabled and 23 and 31,
						Part = "RootPart",
						Players = true,
						Sort = sortmethods.Health
					})
			
					if plr and (not Legit.Enabled or (lplr.Character:GetAttribute("Health") or 0) > 0) then
						if bedwars.AbilityController:canUseAbility('airbender_tornado') then
							bedwars.AbilityController:useAbility('airbender_tornado')
						end
					end
			
					if plr2 and (not Legit.Enabled or (lplr.Character:GetAttribute("Health") or 0) > 0) then
						local direction = (plr2.RootPart.Position - root.Position).Unit
						if bedwars.AbilityController:canUseAbility('airbender_moving_tornado') then
							bedwars.AbilityController:useAbility('airbender_moving_tornado')
						end
					end
				task.wait(0.5)

				until not AutoKit.Enabled
		end,
		nazar = function()
			local empoweredMode = false
			local lastHitTime = 0
			local hitTimeout = 3
			local LowHealthThreshold = 0
			LowHealthThreshold = Legit.Enabled and 50 or 75
			AutoKit:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
				if not entitylib.isAlive then return end
					
				local attacker = playersService:GetPlayerFromCharacter(damageTable.fromEntity)
				local victim = playersService:GetPlayerFromCharacter(damageTable.entityInstance)
					
				if attacker == lplr and victim and victim ~= lplr then
					lastHitTime = workspace:GetServerTimeNow()
					NazarController:request('enabled')
				end
			end))
				
			AutoKit:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
				if not entitylib.isAlive then return end
					
				local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
				local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
					
				if killer == lplr and killed and killed ~= lplr then
					NazarController:request('disabled')
				end
			end))
				
			repeat
				if entitylib.isAlive then
					local currentTime = workspace:GetServerTimeNow()
						
					if empoweredMode and (currentTime - lastHitTime) >= hitTimeout then
						NazarController:request('disabled')
					end
				else
					if empoweredMode then
						NazarController:request('disabled')
					end
				end

				if lplr.Character:GetAttribute('Health') <= LowHealthThreshold then
					NazarController:request('heal')
				end

				task.wait(0.1)
			until not AutoKit.Enabled
				
			AutoKit:Clean(function()
				if empoweredMode then
					NazarController:request('disabled')
				end
			end)
		end,
		void_knight = function()
			repeat
				if not entitylib.isAlive then
					task.wait(0.1)
					continue
				end
					
				local currentTier = lplr:GetAttribute('VoidKnightTier') or 0
				local currentProgress = lplr:GetAttribute('VoidKnightProgress') or 0
				local currentKills = lplr:GetAttribute('VoidKnightKills') or 0
				local haltedProgress = lplr:GetAttribute('VoidKnightHaltedProgress')
					
				if haltedProgress then
					task.wait(0.5)
					continue
				end
					
				if currentTier < 4 then
					if currentTier < 3 then
						local ironAmount = getItem('iron')
						ironAmount = ironAmount and ironAmount.amount or 0
							
						if ironAmount >= 10 and bedwars.AbilityController:canUseAbility('void_knight_consume_iron') then
							bedwars.AbilityController:useAbility('void_knight_consume_iron')
							task.wait(0.5)
						end
					end
						
					if currentTier >= 2 and currentTier < 4 then
						local emeraldAmount = getItem('emerald')
						emeraldAmount = emeraldAmount and emeraldAmount.amount or 0
							
						if emeraldAmount >= 1 and bedwars.AbilityController:canUseAbility('void_knight_consume_emerald') then
							bedwars.AbilityController:useAbility('void_knight_consume_emerald')
							task.wait(0.5)
						end
					end
				end
					
				if currentTier >= 4 and bedwars.AbilityController:canUseAbility('void_knight_ascend') then
					local shouldAscend = false
						
					local health = lplr.Character:GetAttribute('Health') or 100
					local maxHealth = lplr.Character:GetAttribute('MaxHealth') or 100
					if health < (maxHealth * 0.5) then
						shouldAscend = true
					end
						
					if not shouldAscend then
						local plr = entitylib.EntityPosition({
							Range = Legit.Enabled and 30 or 50,
							Part = 'RootPart',
							Players = true,
							Sort = sortmethods.Health
						})
						if plr then
							shouldAscend = true
						end
					end
						
					if shouldAscend then
						bedwars.AbilityController:useAbility('void_knight_ascend')
						task.wait(16)
					end
				end
					
					task.wait(0.5)
				until not AutoKit.Enabled
		end,
		hatter = function()
			repeat
				for _, text in pairs(lplr.PlayerGui.NotificationApp:GetDescendants()) do
					if text:IsA("TextLabel") then
						local txt = string.lower(text.Text)
						if string.find(txt, "teleport") then
							if bedwars.AbilityController:canUseAbility('HATTER_TELEPORT') then
								bedwars.AbilityController:useAbility('HATTER_TELEPORT')
							end																																		
						end
					end
				end
				task.wait(0.34)
			until not AutoKit.Enabled
		end,
		mage = function()
			local r = 0
			if Legit.Enabled then
				r = 10
			else
				r = math.huge or (2^1024-1)
			end
			kitCollection('ElementTome', function(v)
				if Legit.Enabled then bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.PUNCH); bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM) end
				bedwars.Client:Get("LearnElementTome"):SendToServer({secret = v:GetAttribute('TomeSecret')})
				v:Destroy()
				task.wait(0.5)
			end, r, false)
		end,
		pyro = function()
			repeat																																																										
				local plr = entitylib.EntityPosition({
					Range = Legit.Enabled and 10 or 25,
					Part = "RootPart",
					Players = true,
					Sort = sortmethods.Health
				})

				if plr and (not Legit.Enabled or (lplr.Character:GetAttribute("Health") or 0) > 0) then
					game:GetService("ReplicatedStorage").rbxts_include.node_modules:FindFirstChild("@rbxts").net.out._NetManaged.UseFlamethrower:InvokeServer()
					Speed:Toggle(true)
					task.wait(1.85)
					Speed:Toggle(false)
				end
				task.wait(0.1)
			until not AutoKit.Enabled																																																						
		end,
		frost_hammer_kit = function()
			repeat																																																		
				local frost, slot = getItem('frost_crystal')
				local UFH = game:GetService("ReplicatedStorage").rbxts_include.node_modules:FindFirstChild("@rbxts").net.out._NetManaged.UpgradeFrostyHammer

				local attributes = { "shield", "strength", "speed" }
				local slots = { [0] = 2, [1] = 5, [2] = 12 }

				for _, attr in ipairs(attributes) do
					local value = lplr:GetAttribute(attr)
					if slots[value] == slot then
						UFH:InvokeServer(attr)
					end
				end
				task.wait(0.1)
			until not AutoKit.Enabled																																																						
		end,
		battery = function()
			repeat
				if entitylib.isAlive then
					local localPosition = entitylib.character.RootPart.Position
					for i, v in bedwars.BatteryEffectsController.liveBatteries do
						if (v.position - localPosition).Magnitude <= Legit.Enabled and 4 or 10 then
							local BatteryInfo = bedwars.BatteryEffectsController:getBatteryInfo(i)
							if not BatteryInfo or BatteryInfo.activateTime >= workspace:GetServerTimeNow() or BatteryInfo.consumeTime + 0.1 >= workspace:GetServerTimeNow() then continue end
							BatteryInfo.consumeTime = workspace:GetServerTimeNow()
							bedwars.Client:Get(remotes.ConsumeBattery):SendToServer({batteryId = i})
						end
					end
				end
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		beekeeper = function()
			local r =  0
						if Legit.Enabled then
				r = 8
			else
				r = 16
			end
			kitCollection('bee', function(v)
				bedwars.Client:Get(remotes.BeePickup):SendToServer({beeId = v:GetAttribute('BeeId')})
			end,r, false)
		end,
		bigman = function()
			local r = 0
						if Legit.Enabled then
				r = 8
			else
				r = 12
			end
			kitCollection('treeOrb', function(v)
				if Legit.Enabled then
					if bedwars.Client:Get(remotes.ConsumeTreeOrb):CallServer({treeOrbSecret = v:GetAttribute('TreeOrbSecret')}) then
						bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.PUNCH)
						bedwars.SoundManager:playSound(bedwars.SoundList.CROP_HARVEST)
						v:Destroy()
					end
				else
					if bedwars.Client:Get(remotes.ConsumeTreeOrb):CallServer({treeOrbSecret = v:GetAttribute('TreeOrbSecret')}) then
						v:Destroy()
					end
				end
			end, r, false)
		end,
		block_kicker = function()
			local old = bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition
			bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition = function(...)
				local origin, dir = select(2, ...)
				local plr = entitylib.EntityMouse({
					Part = 'RootPart',
					Range = Legit.Enabled and 50 or 250,
					Origin = origin,
					Players = true,
					Wallcheck = Legit.Enabled
				})
		
				if plr then
					local calc = prediction.SolveTrajectory(origin, 100, 20, plr.RootPart.Position, plr.RootPart.Velocity, workspace.Gravity, plr.HipHeight, plr.Jumping and 42.6 or nil)
		
					if calc then
						for i, v in debug.getstack(2) do
							if v == dir then
								debug.setstack(2, i, CFrame.lookAt(origin, calc).LookVector)
							end
						end
					end
				end
		
				return old(...)
			end
		
			AutoKit:Clean(function()
				bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition = old
			end)
		end,
		cat = function()
			local old = bedwars.CatController.leap
			bedwars.CatController.leap = function(...)
				vapeEvents.CatPounce:Fire()
				return old(...)
			end
		
			AutoKit:Clean(function()
				bedwars.CatController.leap = old
			end)
		end,
		davey = function()
			local old = bedwars.CannonHandController.launchSelf
			bedwars.CannonHandController.launchSelf = function(...)
				local res = {old(...)}
				local self, block = ...
		
				if block:GetAttribute('PlacedByUserId') == lplr.UserId and (block.Position - entitylib.character.RootPart.Position).Magnitude < 30 then
					if Legit.Enabled then
						local str = "pickaxe"
						local fullstr = ""
						for i, v in replicatedStorage.Inventories[lplr.Name]:GetChildren() do
							if string.find(v.Name, str) then
								fullstr = v.Name
							end
						end
						local pickaxe = getObjSlot(fullstr)
						local OgSlot = GetOriginalSlot()
						switchHotbar(pickaxe)
						task.spawn(bedwars.breakBlock, block, false, nil, true)
						task.spawn(bedwars.breakBlock, block, false, nil, true)
						task.wait(0.15)
						switchHotbar(OgSlot)
					else
						task.spawn(bedwars.breakBlock, block, false, nil, true)
						task.spawn(bedwars.breakBlock, block, false, nil, true)
					end
				end
		
				return unpack(res)
			end
		
			AutoKit:Clean(function()
				bedwars.CannonHandController.launchSelf = old
			end)
		end,
		dragon_slayer = function()
			local r = 0
						if Legit.Enabled then
				r = 18 / 2
			else
				r = 18
			end
			kitCollection('KaliyahPunchInteraction', function(v)
				if Legit.Enabled then
					bedwars.DragonSlayerController:deleteEmblem(v)
					bedwars.DragonSlayerController:playPunchAnimation(Vector3.zero)
					bedwars.Client:Get(remotes.KaliyahPunch):SendToServer({
						target = v
					})
				else
					bedwars.Client:Get(remotes.KaliyahPunch):SendToServer({
						target = v
					})
				end
			end, r, true)
		end,
		farmer_cletus = function()
			local r = 0
					if Legit.Enabled then
				r = 5
			else
				r = 10
			end
			kitCollection('HarvestableCrop', function(v)
				bedwars.Client:Get('CropHarvest'):CallServer({position = bedwars.BlockController:getBlockPosition(v.Position)})
				if Legit.Enabled then
					bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.PUNCH)
					if lplr.Character:GetAttribute('CropKitSkin') == bedwars.BedwarsKitSkin.FARMER_CLETUS_VALETINE then
						bedwars.SoundManager:playSound(bedwars.SoundList.VALETINE_CROP_HARVEST)
					else
						bedwars.SoundManager:playSound(bedwars.SoundList.CROP_HARVEST)
					end
				end
			end, r, false)
		end,
		fisherman = function()
			local old = bedwars.FishingMinigameController.startMinigame
			bedwars.FishingMinigameController.startMinigame = function(_, _, result)
				if Legit.Enabled then
					local Chance = 50
					local rng = (math.random((Chance/3),(Chance/2))) - math.random()
					if rng >= 20 then
						task.wait(math.random(4,6) - math.random())
						result({win = true})
					else
						result({win = false})
					end
				else
					result({win = true})
				end
			end
		
			AutoKit:Clean(function()
				bedwars.FishingMinigameController.startMinigame = old
			end)
		end,
		gingerbread_man = function()
			local old = bedwars.LaunchPadController.attemptLaunch
			bedwars.LaunchPadController.attemptLaunch = function(...)
				local res = {old(...)}
				local self, block = ...
		
				if (workspace:GetServerTimeNow() - self.lastLaunch) < 0.4 then
					if block:GetAttribute('PlacedByUserId') == lplr.UserId and (block.Position - entitylib.character.RootPart.Position).Magnitude < 30 then
						if Legit.Enabled then
							local str = "pickaxe"
							local fullstr = ""
							for i, v in replicatedStorage.Inventories[lplr.Name]:GetChildren() do
								if string.find(v.Name, str) then
									fullstr = v.Name
								end
							end
							local pickaxe = getObjSlot(fullstr)
							local OgSlot = GetOriginalSlot()
							switchHotbar(pickaxe)
							task.spawn(bedwars.breakBlock, block, false, nil, true)
							task.wait(0.15)
							switchHotbar(OgSlot)
						else
							task.spawn(bedwars.breakBlock, block, false, nil, true)
						end
					end
				end
		
				return unpack(res)
			end
		
			AutoKit:Clean(function()
				bedwars.LaunchPadController.attemptLaunch = old
			end)
		end,
		hannah = function()
			local r = 0
					if Legit.Enabled then
				r = 15
			else
				r = 30
			end
			kitCollection('HannahExecuteInteraction', function(v)
				local billboard = bedwars.Client:Get(remotes.HannahKill):CallServer({
					user = lplr,
					victimEntity = v
				}) and v:FindFirstChild('Hannah Execution Icon')
		
				if billboard then
					billboard:Destroy()
				end
			end, r, true)
		end,
		jailor = function()
			local r = 0
			if Legit.Enabled then
				r = 9
			else
				r = 20
			end
			kitCollection('jailor_soul', function(v)
				bedwars.JailorController:collectEntity(lplr, v, 'JailorSoul')
			end, r, false)
		end,
		grim_reaper = function()
			local r = 0
			if Legit.Enabled then
				r = 35
			else
				r = 120
			end
			kitCollection(bedwars.GrimReaperController.soulsByPosition, function(v)
				if entitylib.isAlive and lplr.Character:GetAttribute('Health') <= (lplr.Character:GetAttribute('MaxHealth') / 4) and (not lplr.Character:GetAttribute('GrimReaperChannel')) then
					bedwars.Client:Get(remotes.ConsumeSoul):CallServer({
						secret = v:GetAttribute('GrimReaperSoulSecret')
					})
				end
			end,  r, false)
		end,
		melody = function()
				local r = 0
			if Legit.Enabled then
				r = 15
			else
				r = 45
			end
			repeat

				local mag, hp, ent = r, math.huge
				if entitylib.isAlive then
					local localPosition = entitylib.character.RootPart.Position
					for _, v in entitylib.List do
						if v.Player and v.Player:GetAttribute('Team') == lplr:GetAttribute('Team') then
							local newmag = (localPosition - v.RootPart.Position).Magnitude
							if newmag <= mag and v.Health < hp and v.Health < v.MaxHealth then
								mag, hp, ent = newmag, v.Health, v
							end
						end
					end
				end
		
				if ent and getItem('guitar') then
					bedwars.Client:Get(remotes.GuitarHeal):SendToServer({
						healTarget = ent.Character
					})
				end
		
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		metal_detector = function()
			local r = 0
					if Legit.Enabled then
				r = 8
			else
				r = 10
			end
			kitCollection('hidden-metal', function(v)
				if Legit.Enabled then
					bedwars.GameAnimationUtil:playAnimation(lplr,bedwars.AnimationType.SHOVEL_DIG)
					bedwars.SoundManager:playSound(bedwars.SoundList.SNAP_TRAP_CONSUME_MARK)
					bedwars.Client:Get('CollectCollectableEntity'):SendToServer({
						id = v:GetAttribute('Id')
					})
				else
					bedwars.Client:Get('CollectCollectableEntity'):SendToServer({
						id = v:GetAttribute('Id')
					})
				end
			end, r, false)
		end,
		miner = function()
			local r = 0
						if Legit.Enabled then
				r = 8
			else
				r = 16
			end
			kitCollection('petrified-player', function(v)
				bedwars.Client:Get(remotes.MinerDig):SendToServer({
					petrifyId = v:GetAttribute('PetrifyId')
				})
			end, r, true)
		end,
		pinata = function()
			local r = 0
					if Legit.Enabled then
				r = 8
			else
				r =18
			end
			kitCollection(lplr.Name..':pinata', function(v)
				if getItem('candy') then
					bedwars.Client:Get('DepositCoins'):CallServer(v)
				end
			end,  r, true)
		end,
		spirit_assassin = function()
			local r = Legit.Enabled and 35 or 120
					if Legit.Enabled then
				r = 35
			else
				r = 120
			end
			kitCollection('EvelynnSoul', function(v)
				bedwars.SpiritAssassinController:useSpirit(lplr, v)
			end, r , true)
		end,
		star_collector = function()
			local r =  Legit.Enabled and 10 or 20
					if Legit.Enabled then
				r = 10
			else
				r = 20
			end
			kitCollection('stars', function(v)
				bedwars.StarCollectorController:collectEntity(lplr, v, v.Name)
			end, r, false)
		end,
		summoner = function()
			local lastAttackTime = 0
			local attackCooldown = 0.65
				
			repeat
				if not entitylib.isAlive then
					task.wait(0.1)
					continue
				end
					
				local isCasting = false
				if Legit.Enabled then
					if lplr.Character:GetAttribute("Casting") or 
					lplr.Character:GetAttribute("UsingAbility") or
					lplr.Character:GetAttribute("SummonerCasting") then
						isCasting = true
					end
						
					local humanoid = lplr.Character:FindFirstChildOfClass("Humanoid")
					if humanoid and humanoid:GetState() == Enum.HumanoidStateType.Freefall then
						isCasting = true
					end
				end
					
				if Legit.Enabled and isCasting then
					task.wait(0.1)
					continue
				end
					
				if (workspace:GetServerTimeNow() - lastAttackTime) < attackCooldown then
					task.wait(0.1)
					continue
				end
					
				local handItem = lplr.Character:FindFirstChild('HandInvItem')
				local hasClaw = false
				if handItem and handItem.Value then
					local itemType = handItem.Value.Name
					hasClaw = itemType:find('summoner_claw')
				end
					
				if not hasClaw then
					task.wait(0.1)
					continue
				end
					
				local range = Legit.Enabled and 23 or 35
				local plr = entitylib.EntityPosition({
					Range = range, 
					Part = 'RootPart',
					Players = true,
					NPCs = true,
					Sort = sortmethods.Health
				})

				if plr then
					local distance = (entitylib.character.RootPart.Position - plr.RootPart.Position).Magnitude
					if Legit.Enabled and distance > 23 then
						plr = nil 
					end
				end

				if plr and (not Legit.Enabled or (lplr.Character:GetAttribute('Health') or 0) > 0) then
					local localPosition = entitylib.character.RootPart.Position
					local shootDir = CFrame.lookAt(localPosition, plr.RootPart.Position).LookVector
					localPosition += shootDir * math.max((localPosition - plr.RootPart.Position).Magnitude - 16, 0)

					lastAttackTime = workspace:GetServerTimeNow()

					pcall(function()
						bedwars.AnimationUtil:playAnimation(lplr, bedwars.GameAnimationUtil:getAssetId(bedwars.AnimationType.SUMMONER_CHARACTER_SWIPE), {
							looped = false
						})
					end)

					task.spawn(function()
						pcall(function()
							local clawModel = replicatedStorage.Assets.Misc.Kaida.Summoner_DragonClaw:Clone()
									
							clawModel.Parent = workspace
								
							if gameCamera.CFrame.Position and (gameCamera.CFrame.Position - entitylib.character.RootPart.Position).Magnitude < 1 then
								for _, part in clawModel:GetDescendants() do
									if part:IsA('MeshPart') then
										part.Transparency = 0.6
									end
								end
							end
								
							local rootPart = entitylib.character.RootPart
							local Unit = Vector3.new(shootDir.X, 0, shootDir.Z).Unit
							local startPos = rootPart.Position + Unit:Cross(Vector3.new(0, 1, 0)).Unit * -1 * 5 + Unit * 6
							local direction = (startPos + shootDir * 13 - startPos).Unit
							local cframe = CFrame.new(startPos, startPos + direction)
							
							clawModel:PivotTo(cframe)
							clawModel.PrimaryPart.Anchored = true
							
							if clawModel:FindFirstChild('AnimationController') then
								local animator = clawModel.AnimationController:FindFirstChildOfClass('Animator')
								if animator then
									bedwars.AnimationUtil:playAnimation(animator, bedwars.GameAnimationUtil:getAssetId(bedwars.AnimationType.SUMMONER_CLAW_ATTACK), {
										looped = false,
										speed = 1
									})
								end
							end
								
							pcall(function()
								local sounds = {
									bedwars.SoundList.SUMMONER_CLAW_ATTACK_1,
									bedwars.SoundList.SUMMONER_CLAW_ATTACK_2,
									bedwars.SoundList.SUMMONER_CLAW_ATTACK_3,
									bedwars.SoundList.SUMMONER_CLAW_ATTACK_4
								}
								bedwars.SoundManager:playSound(sounds[math.random(1, #sounds)], {
									position = rootPart.Position
								})
							end)
								
							task.wait(0.75)
							clawModel:Destroy()
						end)
					end)

					bedwars.Client:Get(remotes.SummonerClawAttack):SendToServer({
						position = localPosition,
						direction = shootDir,
						clientTime = workspace:GetServerTimeNow()
					})
				end

				task.wait(0.1)
				until not AutoKit.Enabled
		end,
		void_dragon = function()
			local oldflap = bedwars.VoidDragonController.flapWings
			local flapped
		
			bedwars.VoidDragonController.flapWings = function(self)
				if not flapped and bedwars.Client:Get(remotes.DragonFly):CallServer() then
					local modifier = bedwars.SprintController:getMovementStatusModifier():addModifier({
						blockSprint = true,
						constantSpeedMultiplier = 2
					})
					self.SpeedMaid:GiveTask(modifier)
					self.SpeedMaid:GiveTask(function()
						flapped = false
					end)
					flapped = true
				end
			end
		
			AutoKit:Clean(function()
				bedwars.VoidDragonController.flapWings = oldflap
			end)
		
			repeat
				if bedwars.VoidDragonController.inDragonForm then
					local plr = entitylib.EntityPosition({
						Range =  Legit.Enabled and 15 or 30,
						Part = 'RootPart',
						Players = true
					})
		
					if plr then
						bedwars.Client:Get(remotes.DragonBreath):SendToServer({
							player = lplr,
							targetPoint = plr.RootPart.Position
						})
					end
				end
				task.wait(0.1)
				until not AutoKit.Enabled
		end,
		warlock = function()
				local lastTarget
				repeat
					if store.hand.tool and store.hand.tool.Name == 'warlock_staff' then
						local plr = entitylib.EntityPosition({
							Range =  Legit.Enabled and (30/2.245) or 30,
							Part = 'RootPart',
							Players = true,
							NPCs = true
						})
		
						if plr and plr.Character ~= lastTarget then
							if not bedwars.Client:Get(remotes.WarlockTarget):CallServer({
								target = plr.Character
							}) then
								plr = nil
							end
						end
		
						lastTarget = plr and plr.Character
					else
						lastTarget = nil
					end
		
					task.wait(0.1)
				until not AutoKit.Enabled
		end,
		spider_queen = function()
				local isAiming = false
				local aimingTarget = nil
				
				repeat
					if entitylib.isAlive and bedwars.AbilityController then
						local plr = entitylib.EntityPosition({
							Range = not Legit.Enabled and 80 or 50,
							Part = 'RootPart',
							Players = true,
							Sort = sortmethods.Health
						})
						
						if plr and not isAiming and bedwars.AbilityController:canUseAbility('spider_queen_web_bridge_aim') then
							bedwars.AbilityController:useAbility('spider_queen_web_bridge_aim')
							isAiming = true
							aimingTarget = plr
							task.wait(0.1)
						end
						
						if isAiming and aimingTarget and aimingTarget.RootPart then
							local localPosition = entitylib.character.RootPart.Position
							local targetPosition = aimingTarget.RootPart.Position
							
							local direction
							if Legit.Enabled then
								direction = (targetPosition - localPosition).Unit
							else
								direction = (targetPosition - localPosition).Unit
							end
							
							if bedwars.AbilityController:canUseAbility('spider_queen_web_bridge_fire') then
								bedwars.AbilityController:useAbility('spider_queen_web_bridge_fire', newproxy(true), {
									direction = direction
								})
								isAiming = false
								aimingTarget = nil
								task.wait(0.3)
							end
						end
						
						if isAiming and (not aimingTarget or not aimingTarget.RootPart) then
							isAiming = false
							aimingTarget = nil
						end
						
						local summonAbility = 'spider_queen_summon_spiders'
						if bedwars.AbilityController:canUseAbility(summonAbility) then
							bedwars.AbilityController:useAbility(summonAbility)
						end
					end
					
					task.wait(0.05)
				until not AutoKit.Enabled
		end,
		blood_assassin = function()
				local hitPlayers = {} 
				
				AutoKit:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
					if not entitylib.isAlive then return end
					
					local attacker = playersService:GetPlayerFromCharacter(damageTable.fromEntity)
					local victim = playersService:GetPlayerFromCharacter(damageTable.entityInstance)
				
					if attacker == lplr and victim and victim ~= lplr then
						hitPlayers[victim] = true
						
						local storeState = bedwars.Store:getState()
						local activeContract = storeState.Kit.activeContract
						local availableContracts = storeState.Kit.availableContracts or {}
						
						if not activeContract then
							for _, contract in availableContracts do
								if contract.target == victim then
									bedwars.Client:Get('BloodAssassinSelectContract'):SendToServer({
										contractId = contract.id
									})
									break
								end
							end
						end
					end
				end))
				
				repeat
					if entitylib.isAlive then
						local storeState = bedwars.Store:getState()
						local activeContract = storeState.Kit.activeContract
						local availableContracts = storeState.Kit.availableContracts or {}
						
						if not activeContract and #availableContracts > 0 then
							local bestContract = nil
							local highestDifficulty = 0
							
							for _, contract in availableContracts do
								if hitPlayers[contract.target] then
									if contract.difficulty > highestDifficulty then
										bestContract = contract
										highestDifficulty = contract.difficulty
									end
								end
							end
							
							if bestContract then
								bedwars.Client:Get('BloodAssassinSelectContract'):SendToServer({
									contractId = bestContract.id
								})
								task.wait(0.5)
							end
						end
					end
					task.wait(1)
				until not AutoKit.Enabled
				
				table.clear(hitPlayers)
		end,
		mimic = function()
			repeat
				if not entitylib.isAlive then
					task.wait(0.1)
						continue
					end
					
					local localPosition = entitylib.character.RootPart.Position
					for _, v in entitylib.List do
						if v.Targetable and v.Character and v.Player then
							local distance = (v.RootPart.Position - localPosition).Magnitude
							if distance <= (Legit.Enabled and 12 or 30) then
								if collectionService:HasTag(v.Character, "MimicBLockPickPocketPlayer") then
									pcall(function()
										local success = replicatedStorage:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("MimicBlockPickPocketPlayer"):InvokeServer(v.Player)
									end)
									task.wait(0.5)
								end
							end
						end
					end
					
					task.wait(0.1)
				until not AutoKit.Enabled
		end,
		gun_blade = function()
			repeat
				if bedwars.AbilityController:canUseAbility('hand_gun') then
					local plr = entitylib.EntityPosition({
						Range = Legit.Enabled and 10 or 20,
						Part = 'RootPart',
						Players = true,
						Sort = sortmethods.Health
					})
			
					if plr then
						bedwars.AbilityController:useAbility('hand_gun')
					end
				end
			
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		wizard = function()
			math.randomseed(os.clock() * 1e6)
			local roll = math.random(0,100)
			repeat
				local ability = lplr:GetAttribute("WizardAbility")
				if not ability then
					task.wait(0.85)
					continue
				end
				local plr = entitylib.EntityPosition({
					Range = Legit.Enabled and 32 or 50,
					Part = "RootPart",
					Players = true,
					Sort = sortmethods.Health
				})
				if not plr or not store.hand.tool then
					task.wait(0.85)
					continue
				end
				local itemType = store.hand.tool.Name.itemType
				local targetPos = plr.RootPart.Position
				if bedwars.AbilityController:canUseAbility(ability) then
					bedwars.AbilityController:useAbility(ability,newproxy(true),{target = targetPos})
				end
				if itemType == "wizard_staff_2" or itemType == "wizard_staff_3" then
					local plr2 = entitylib.EntityPosition({
						Range = Legit.Enabled and 13 or 20,
						Part = "RootPart",
						Players = true,
						Sort = sortmethods.Health
					})

					if plr2 then
						if roll <= 50 then
							if bedwars.AbilityController:canUseAbility("SHOCKWAVE") then
								bedwars.AbilityController:useAbility("SHOCKWAVE",newproxy(true),{target = Vector3.zero})
								 roll = math.random(0,100)
							end
						else
							if bedwars.AbilityController:canUseAbility(ability) then
								bedwars.AbilityController:useAbility(ability,newproxy(true),{target = targetPos})
								 roll = math.random(0,100)
							end
						end
					end
				end
				if itemType == "wizard_staff_3" then
					local plr3 = entitylib.EntityPosition({
						Range = Legit.Enabled and 12 or 18,
						Part = "RootPart",
						Players = true,
						Sort = sortmethods.Health
					})
					if plr3 then
						if roll <= 40 then
							if bedwars.AbilityController:canUseAbility(ability) then
								bedwars.AbilityController:useAbility(ability,newproxy(true),{target = targetPos})
								 roll = math.random(0,100)
							end
						elseif roll <= 70 then
							if bedwars.AbilityController:canUseAbility("SHOCKWAVE") then
								bedwars.AbilityController:useAbility("SHOCKWAVE",newproxy(true),{target = Vector3.zero})
								 roll = math.random(0,100)
							end
						else
							if bedwars.AbilityController:canUseAbility("LIGHTNING_STORM") then
								bedwars.AbilityController:useAbility("LIGHTNING_STORM",newproxy(true),{target = targetPos})
								 roll = math.random(0,100)
							end
						end
					end
				end
				task.wait(0.85)
			until not AutoKit.Enabled
		end,
		--[[wizard = function()
			repeat
				local ability = lplr:GetAttribute('WizardAbility')
				if ability and bedwars.AbilityController:canUseAbility(ability) then
					local plr = entitylib.EntityPosition({
						Range = Legit.Enabled and 32 or 50,
						Part = 'RootPart',
						Players = true,
						Sort = sortmethods.Health
					})
		
					if plr then
						bedwars.AbilityController:useAbility(ability, newproxy(true), {target = plr.RootPart.Position})
					end
				end
		
				task.wait(0.1)
			until not AutoKit.Enabled
		end,--]]
	}
	
	AutoKit = vape.Categories.Exploits:CreateModule({
		Name = 'AutoKit',
		Function = function(callback)

			if callback then
				repeat task.wait(0.1) until store.equippedKit ~= '' and store.matchState ~= 0 or (not AutoKit.Enabled)
				if AutoKit.Enabled and AutoKitFunctions[store.equippedKit] then
					AutoKitFunctions[store.equippedKit]()
				else
					vape:CreateNotification("AutoKit", "Your current kit is not supported yet!", 4, "warning")
					return
				end
			end
		end,
		Tooltip = 'Automatically uses kit abilities.'
	})
	Legit = AutoKit:CreateToggle({Name = 'Legit'})
end)
run(function()
    local OGTags
    local function create(Name,Values)
        local Obj = Instance.new(Name)
        for i, v in Values do
            Obj[i] = v
        end
        return Obj
    end
    local function CreateNameTag(plr)
		if plr.Character.Head:FindFirstChild("OldNameTags") then return end
			local OppositeTeamColor = Color3.fromRGB(255, 82, 82)
			local SameTeamColor = Color3.fromRGB(111, 255, 101)
			local billui = create("BillboardGui",{Name='OldNameTags',AlwaysOnTop=true,MaxDistance=150,Parent=plr.Character.Head,ResetOnSpawn=false,Size=UDim2.fromScale(5,0.65),StudsOffsetWorldSpace=Vector3.new(0,1.6,0),ZIndexBehavior='Global',Adornee=plr.Character.Head})
			local MainContainer = create("Frame",{Parent=billui,BackgroundTransparency=1,Position=UDim2.fromScale(-0.005,0),Size=UDim2.fromScale(1,1),Name='1'})
			local TeamCircle = create("Frame",{Name='2',Parent=MainContainer,BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=0.15,BorderSizePixel=0,Position=UDim2.fromScale(0.11,0.16),Size=UDim2.fromScale(0.09,0.7)})
			create("UICorner",{Name='1',Parent=TeamCircle,CornerRadius=UDim.new(0, 25555)})
			local NameBG = create("Frame",{Name='1',Parent=MainContainer,BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=0.7,Position=UDim2.fromScale(0.25,0.1),Size=UDim2.fromScale(0.7,0.8)})
			local stroke = create('UIStroke',{Name='1',Parent=NameBG,Color=Color3.new(1,1,1),Thickness=1.5})
			local Txt = create("TextLabel",{Name='2',Parent=NameBG,BackgroundTransparency=1,AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(0.95,0.9),FontFace=Font.new('rbxasset://fonts/families/Arimo.json',Enum.FontWeight.SemiBold),Text='',TextColor3=Color3.new(1,1,1),TextScaled=true,TextWrapped=true})
			local NewName = ""
			if plr.DisplayName == "" or plr.DisplayName == plr.Name then
				NewName = plr.Name
			else
				NewName = plr.DisplayName
			end
			Txt.Text = NewName
			if plr.Character:GetAttribute('Team') == lplr.Character:GetAttribute('Team') then
				stroke.Color = SameTeamColor
				Txt.TextColor3 = SameTeamColor
			else
				stroke.Color = OppositeTeamColor
				Txt.TextColor3 = OppositeTeamColor
			end
			TeamCircle.BackgroundColor3 = Color3.new(plr.TeamColor.r,plr.TeamColor.g,plr.TeamColor.b)
		

    end
	local function RemoveTag(plr)
		if plr.Character.Head:FindFirstChild("OldNameTags") then
			plr.Character.Head:FindFirstChild("OldNameTags"):Destroy()
		else
			return
		end
	end
	local old = nil
	local old2 = nil
    OGTags = vape.Categories.Render:CreateModule({
        Name = "OgNameTags",
        Tooltip = 'changes everyones nametag to the OG(season 7 and before)(ty kolifyz for the idea)\nCLIENT ONLY',
        Function = function(callback)
            if callback then
				old = bedwars.NametagController.addGameNametag
				old2 = bedwars.NametagController.removeGameNametag
				for _, v in bedwars.AppController:getOpenApps() do
					if tostring(v):find('Nametag') then
						bedwars.AppController:closeApp(tostring(v))
					end
				end
				for i, v in playersService:GetPlayers() do
					CreateNameTag(v)
				end
				bedwars.NametagController.addGameNametag = function(v1,plr)
				for _, v in bedwars.AppController:getOpenApps() do
					if tostring(v):find('Nametag') then
						bedwars.AppController:closeApp(tostring(v))
					end
				end
					CreateNameTag(plr)
				end
				bedwars.NametagController.removeGameNametag = function(v1,plr)
					RemoveTag(plr)
				end
            else
				vape:CreateNotification("OgNameTags","Disabled next game!",5,"warning")
            end
        end
    })
end)
run(function()
    local HitFix
	local PingBased
	local Options
    HitFix = vape.Categories.Blatant:CreateModule({
        Name = 'KA HitFix',
        Function = function(callback)

            local function getPing()
                local stats = game:GetService("Stats")
                local ping = stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
                return tonumber(ping:match("%d+")) or 50
            end

            local function getDelay()
                local ping = getPing()

                if PingBased.Enabled then
                    if Options.Value == "Blatant" then
                        return math.clamp(0.08 + (ping / 1000), 0.08, 0.14)
                    else
                        return math.clamp(0.11 + (ping / 1200), 0.11, 0.15)
                    end
                end

                return Options.Value == "Blatant" and 0.1 or 0.13
            end

            if callback then
                pcall(function()
                    if bedwars.SwordController and bedwars.SwordController.swingSwordAtMouse then
                        local func = bedwars.SwordController.swingSwordAtMouse

                        if Options.Value == "Blatant" then
                            debug.setconstant(func, 23, "raycast")
                            debug.setupvalue(func, 4, bedwars.QueryUtil)
                        end

                        for i, v in ipairs(debug.getconstants(func)) do
                            if typeof(v) == "number" and (v == 0.15 or v == 0.1) then
                                debug.setconstant(func, i, getDelay())
                            end
                        end
                    end
                end)
            else
                pcall(function()
                    if bedwars.SwordController and bedwars.SwordController.swingSwordAtMouse then
                        local func = bedwars.SwordController.swingSwordAtMouse

                        debug.setconstant(func, 23, "Raycast")
                        debug.setupvalue(func, 4, workspace)

                        for i, v in ipairs(debug.getconstants(func)) do
                            if typeof(v) == "number" then
                                if v < 0.15 then
                                    debug.setconstant(func, i, 0.15)
                                end
                            end
                        end
                    end
                end)
            end
        end,
        Tooltip = 'Improves hit registration and decreases the chances of a ghost hit'
    })

    Options = HitFix:CreateDropdown({
        Name = "Mode",
        List = {"Blatant", "Legit"},
    })

    PingBased = HitFix:CreateToggle({
        Name = "Ping Based",
        Default = false,
    })
end)

run(function()
	local BedESP
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function Added(bed)
		if not BedESP.Enabled then return end
		local BedFolder = Instance.new('Folder')
		BedFolder.Parent = Folder
		Reference[bed] = BedFolder
		local parts = bed:GetChildren()
		table.sort(parts, function(a, b)
			return a.Name > b.Name
		end)
	
		for _, part in parts do
			if part:IsA('BasePart') and part.Name ~= 'Blanket' then
				local handle = Instance.new('BoxHandleAdornment')
				handle.Size = part.Size + Vector3.new(.01, .01, .01)
				handle.AlwaysOnTop = true
				handle.ZIndex = 2
				handle.Visible = true
				handle.Adornee = part
				handle.Color3 = part.Color
				if part.Name == 'Legs' then
					handle.Color3 = Color3.fromRGB(167, 112, 64)
					handle.Size = part.Size + Vector3.new(.01, -1, .01)
					handle.CFrame = CFrame.new(0, -0.4, 0)
					handle.ZIndex = 0
				end
				handle.Parent = BedFolder
			end
		end
	
		table.clear(parts)
	end
	
	BedESP = vape.Categories.Render:CreateModule({
		Name = 'BedESP',
		Function = function(callback)
			if callback then
				BedESP:Clean(collectionService:GetInstanceAddedSignal('bed'):Connect(function(bed)
					task.delay(0.2, Added, bed)
				end))
				BedESP:Clean(collectionService:GetInstanceRemovedSignal('bed'):Connect(function(bed)
					if Reference[bed] then
						Reference[bed]:Destroy()
						Reference[bed] = nil
					end
				end))
				for _, bed in collectionService:GetTagged('bed') do
					Added(bed)
				end
			else
				Folder:ClearAllChildren()
				table.clear(Reference)
			end
		end,
		Tooltip = 'Render Beds through walls'
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
				label.BackgroundTransparency = 1
				label.AnchorPoint = Vector2.new(0.5, 0)
				label.Text = entitylib.isAlive and math.round(lplr.Character:GetAttribute('Health'))..' ❤️' or ''
				label.TextColor3 = entitylib.isAlive and Color3.fromHSV((lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) / 2.8, 0.86, 1) or Color3.new()
				label.TextSize = 18
				label.Font = Enum.Font.Arial
				label.Parent = vape.gui
				Health:Clean(label)
				Health:Clean(vapeEvents.AttributeChanged.Event:Connect(function()
					label.Text = entitylib.isAlive and math.round(lplr.Character:GetAttribute('Health'))..' ❤️' or ''
					label.TextColor3 = entitylib.isAlive and Color3.fromHSV((lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) / 2.8, 0.86, 1) or Color3.new()
				end))
			end
		end,
		Tooltip = 'Displays your health in the center of your screen.'
	})
end)
	
run(function()
	local KitESP
	local Background
	local Color = {}
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local ESPKits = {
		alchemist = {'alchemist_ingedients', 'wild_flower'},
		beekeeper = {'bee', 'bee'},
		bigman = {'treeOrb', 'natures_essence_1'},
		ghost_catcher = {'ghost', 'ghost_orb'},
		metal_detector = {'hidden-metal', 'iron'},
		sheep_herder = {'SheepModel', 'purple_hay_bale'},
		sorcerer = {'alchemy_crystal', 'wild_flower'},
		star_collector = {'stars', 'crit_star'}
	}
	
	local function Added(v, icon)
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = icon
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = v
		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled
		local image = Instance.new('ImageLabel')
		image.Size = UDim2.fromOffset(36, 36)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		image.BorderSizePixel = 0
		image.Image = bedwars.getIcon({itemType = icon}, true)
		image.Parent = billboard
		local uicorner = Instance.new('UICorner')
		uicorner.CornerRadius = UDim.new(0, 4)
		uicorner.Parent = image
		Reference[v] = billboard
	end
	
	local function addKit(tag, icon)
		KitESP:Clean(collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
			Added(v.PrimaryPart, icon)
		end))
		KitESP:Clean(collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
			if Reference[v.PrimaryPart] then
				Reference[v.PrimaryPart]:Destroy()
				Reference[v.PrimaryPart] = nil
			end
		end))
		for _, v in collectionService:GetTagged(tag) do
			Added(v.PrimaryPart, icon)
		end
	end
	
	KitESP = vape.Categories.Render:CreateModule({
		Name = 'KitESP',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.equippedKit ~= '' or (not KitESP.Enabled)
				local kit = KitESP.Enabled and ESPKits[store.equippedKit] or nil
				if kit then
					addKit(kit[1], kit[2])
				end
			else
				Folder:ClearAllChildren()
				table.clear(Reference)
			end
		end,
		Tooltip = 'ESP for certain kit related objects'
	})
	Background = KitESP:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color.Object then Color.Object.Visible = callback end
			for _, v in Reference do
				v.ImageLabel.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
				v.Blur.Visible = callback
			end
		end,
		Default = true
	})
	Color = KitESP:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			for _, v in Reference do
				v.ImageLabel.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				v.ImageLabel.BackgroundTransparency = 1 - opacity
			end
		end,
		Darker = true
	})
end)
run(function()
    local Disabler = {Enabled = false}

    Disabler = vape.Categories.Combat:CreateModule({
        Name = "Zephyr Disabler",
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
	local NameTags
	local Targets
	local Color
	local Background
	local DisplayName
	local Health
	local Distance
	local Equipment
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
	
			local nametag = Instance.new('TextLabel')
			Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
			if Health.Enabled then
				local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
				Strings[ent] = Strings[ent]..' <font color="rgb('..tostring(math.floor(healthColor.R * 255))..','..tostring(math.floor(healthColor.G * 255))..','..tostring(math.floor(healthColor.B * 255))..')">'..math.round(ent.Health)..'</font>'
			end
	
			if Distance.Enabled then
				Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '..Strings[ent]
			end
	
			if Equipment.Enabled then
				for i, v in {'Hand', 'Helmet', 'Chestplate', 'Boots', 'Kit'} do
					local Icon = Instance.new('ImageLabel')
					Icon.Name = v
					Icon.Size = UDim2.fromOffset(30, 30)
					Icon.Position = UDim2.fromOffset(-60 + (i * 30), -30)
					Icon.BackgroundTransparency = 1
					Icon.Image = ''
					Icon.Parent = nametag
				end
			end
	
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
				Reference[ent] = nil
				Strings[ent] = nil
				Sizes[ent] = nil
				v:Destroy()
			end
		end,
		Drawing = function(ent)
			local v = Reference[ent]
			if v then
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
				Sizes[ent] = nil
				Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
				if Health.Enabled then
					local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
					Strings[ent] = Strings[ent]..' <font color="rgb('..tostring(math.floor(healthColor.R * 255))..','..tostring(math.floor(healthColor.G * 255))..','..tostring(math.floor(healthColor.B * 255))..')">'..math.round(ent.Health)..'</font>'
				end
	
				if Distance.Enabled then
					Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '..Strings[ent]
				end
	
				if Equipment.Enabled and store.inventories[ent.Player] then
					local kit = ent.Player:GetAttribute('PlayingAsKit')
					local inventory = store.inventories[ent.Player]
					nametag.Hand.Image = bedwars.getIcon(inventory.hand or {itemType = ''}, true)
					nametag.Helmet.Image = bedwars.getIcon(inventory.armor[4] or {itemType = ''}, true)
					nametag.Chestplate.Image = bedwars.getIcon(inventory.armor[5] or {itemType = ''}, true)
					nametag.Boots.Image = bedwars.getIcon(inventory.armor[6] or {itemType = ''}, true)
					nametag.Kit.Image = kit and kit ~= 'none' and bedwars.BedwarsKitMeta[kit].renderImage or ''
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
	Equipment = NameTags:CreateToggle({
		Name = 'Equipment',
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
		Default = true
	})
	DrawingToggle = NameTags:CreateToggle({
		Name = 'Drawing',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
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
	local Viewmodel
	local Depth
	local Horizontal
	local Vertical
	local NoBob
	local Rots = {}
	local old, oldc1
	
	Viewmodel = vape.Legit:CreateModule({
		Name = 'Viewmodel',
		Function = function(callback)
			local viewmodel = gameCamera:FindFirstChild('Viewmodel')
			if callback then
				old = bedwars.ViewmodelController.playAnimation
				oldc1 = viewmodel and viewmodel.RightHand.RightWrist.C1 or CFrame.identity
				if NoBob.Enabled then
					bedwars.ViewmodelController.playAnimation = function(self, animtype, ...)
						if bedwars.AnimationType and animtype == bedwars.AnimationType.FP_WALK then return end
						return old(self, animtype, ...)
					end
				end
	
				bedwars.InventoryViewmodelController:handleStore(bedwars.Store:getState())
				if viewmodel then
					gameCamera.Viewmodel.RightHand.RightWrist.C1 = oldc1 * CFrame.Angles(math.rad(Rots[1].Value), math.rad(Rots[2].Value), math.rad(Rots[3].Value))
				end
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_DEPTH_OFFSET', -Depth.Value)
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_HORIZONTAL_OFFSET', Horizontal.Value)
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_VERTICAL_OFFSET', Vertical.Value)
			else
				bedwars.ViewmodelController.playAnimation = old
				if viewmodel then
					viewmodel.RightHand.RightWrist.C1 = oldc1
				end
	
				bedwars.InventoryViewmodelController:handleStore(bedwars.Store:getState())
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_DEPTH_OFFSET', 0)
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_HORIZONTAL_OFFSET', 0)
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_VERTICAL_OFFSET', 0)
				old = nil
			end
		end,
		Tooltip = 'Changes the viewmodel animations'
	})
	Depth = Viewmodel:CreateSlider({
		Name = 'Depth',
		Min = 0,
		Max = 2,
		Default = 0.8,
		Decimal = 10,
		Function = function(val)
			if Viewmodel.Enabled then
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_DEPTH_OFFSET', -val)
			end
		end
	})
	Horizontal = Viewmodel:CreateSlider({
		Name = 'Horizontal',
		Min = 0,
		Max = 2,
		Default = 0.8,
		Decimal = 10,
		Function = function(val)
			if Viewmodel.Enabled then
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_HORIZONTAL_OFFSET', val)
			end
		end
	})
	Vertical = Viewmodel:CreateSlider({
		Name = 'Vertical',
		Min = -0.2,
		Max = 2,
		Default = -0.2,
		Decimal = 10,
		Function = function(val)
			if Viewmodel.Enabled then
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_VERTICAL_OFFSET', val)
			end
		end
	})
	for _, name in {'Rotation X', 'Rotation Y', 'Rotation Z'} do
		table.insert(Rots, Viewmodel:CreateSlider({
			Name = name,
			Min = 0,
			Max = 360,
			Function = function(val)
				if Viewmodel.Enabled then
					gameCamera.Viewmodel.RightHand.RightWrist.C1 = oldc1 * CFrame.Angles(math.rad(Rots[1].Value), math.rad(Rots[2].Value), math.rad(Rots[3].Value))
				end
			end
		}))
	end
	NoBob = Viewmodel:CreateToggle({
		Name = 'No Bobbing',
		Default = true,
		Function = function()
			if Viewmodel.Enabled then
				Viewmodel:Toggle()
				Viewmodel:Toggle()
			end
		end
	})
end)
	
run(function()
	local AutoPlay
	local Random
	
	local function isEveryoneDead()
		return #bedwars.Store:getState().Party.members <= 0
	end
	
	local function joinQueue()
		--if not bedwars.Store:getState().Game.customMatch and bedwars.Store:getState().Party.leader.userId == lplr.UserId and bedwars.Store:getState().Party.queueState == 0 then
			if Random.Enabled then
				local listofmodes = {}
				for i, v in bedwars.QueueMeta do
					if not v.disabled and not v.voiceChatOnly and not v.rankCategory then 
						table.insert(listofmodes, i) 
					end
				end
				bedwars.QueueController:joinQueue(listofmodes[math.random(1, #listofmodes)])
			else
				bedwars.QueueController:joinQueue(store.queueType)
			end
		--end
	end
	
	AutoPlay = vape.Categories.Utility:CreateModule({
		Name = 'AutoPlay',
		Function = function(callback)
			if callback then
				AutoPlay:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
					if deathTable.finalKill and deathTable.entityInstance == lplr.Character and isEveryoneDead() and store.matchState ~= 2 then
						joinQueue()
					end
				end))
				AutoPlay:Clean(vapeEvents.MatchEndEvent.Event:Connect(joinQueue))
			end
		end,
		Tooltip = 'Automatically queues after the match ends.'
	})
	Random = AutoPlay:CreateToggle({
		Name = 'Random',
		Tooltip = 'Chooses a random mode'
	})
end)
	
run(function()
	local shooting, old = false
	
	local function getCrossbows()
		local crossbows = {}
		for i, v in store.inventory.hotbar do
			if v.item and v.item.itemType:find('crossbow') and i ~= (store.inventory.hotbarSlot + 1) then table.insert(crossbows, i - 1) end
		end
		return crossbows
	end
	
	vape.Categories.Utility:CreateModule({
		Name = 'AutoShoot',
		Function = function(callback)
			if callback then
				old = bedwars.ProjectileController.createLocalProjectile
				bedwars.ProjectileController.createLocalProjectile = function(...)
					local source, data, proj = ...
					if source and (proj == 'arrow' or proj == 'fireball') and not shooting then
						task.spawn(function()
							local bows = getCrossbows()
							if #bows > 0 then
								shooting = true
								task.wait(0.15)
								local selected = store.inventory.hotbarSlot
								for _, v in getCrossbows() do
									if hotbarSwitch(v) then
										task.wait(0.05)
										mouse1click()
										task.wait(0.05)
									end
								end
								hotbarSwitch(selected)
								shooting = false
							end
						end)
					end
					return old(...)
				end
			else
				bedwars.ProjectileController.createLocalProjectile = old
			end
		end,
		Tooltip = 'Automatically crossbow macro\'s'
	})
	
end)
	
	
	
run(function()
	local Scaffold
	local Expand
	local Tower
	local Downwards
	local Diagonal
	local LimitItem
	local Mouse
	local adjacent, lastpos, label = {}, Vector3.zero
	
	for x = -3, 3, 3 do
		for y = -3, 3, 3 do
			for z = -3, 3, 3 do
				local vec = Vector3.new(x, y, z)
				if vec ~= Vector3.zero then
					table.insert(adjacent, vec)
				end
			end
		end
	end
	
	local function nearCorner(poscheck, pos)
		local startpos = poscheck - Vector3.new(3, 3, 3)
		local endpos = poscheck + Vector3.new(3, 3, 3)
		local check = poscheck + (pos - poscheck).Unit * 100
		return Vector3.new(math.clamp(check.X, startpos.X, endpos.X), math.clamp(check.Y, startpos.Y, endpos.Y), math.clamp(check.Z, startpos.Z, endpos.Z))
	end
	
	local function blockProximity(pos)
		local mag, returned = 60
		local tab = getBlocksInPoints(bedwars.BlockController:getBlockPosition(pos - Vector3.new(21, 21, 21)), bedwars.BlockController:getBlockPosition(pos + Vector3.new(21, 21, 21)))
		for _, v in tab do
			local blockpos = nearCorner(v, pos)
			local newmag = (pos - blockpos).Magnitude
			if newmag < mag then
				mag, returned = newmag, blockpos
			end
		end
		table.clear(tab)
		return returned
	end
	
	local function checkAdjacent(pos)
		for _, v in adjacent do
			if getPlacedBlock(pos + v) then
				return true
			end
		end
		return false
	end
	
	local function getScaffoldBlock()
		if store.hand.toolType == 'block' then
			return store.hand.tool.Name, store.hand.amount
		elseif (not LimitItem.Enabled) then
			local wool, amount = getWool()
			if wool then
				return wool, amount
			else
				for _, item in store.inventory.inventory.items do
					if bedwars.ItemMeta[item.itemType].block then
						return item.itemType, item.amount
					end
				end
			end
		end
	
		return nil, 0
	end
	
	Scaffold = vape.Categories.Utility:CreateModule({
		Name = 'Scaffold',
		Function = function(callback)
			if label then
				label.Visible = callback
			end
	
			if callback then
				repeat
					if entitylib.isAlive then
						local wool, amount = getScaffoldBlock()
	
						if Mouse.Enabled then
							if not inputService:IsMouseButtonPressed(0) then
								wool = nil
							end
						end
	
						if label then
							amount = amount or 0
							label.Text = amount..' <font color="rgb(170, 170, 170)">(Scaffold)</font>'
							label.TextColor3 = Color3.fromHSV((amount / 128) / 2.8, 0.86, 1)
						end
	
						if wool then
							local root = entitylib.character.RootPart
							if Tower.Enabled and inputService:IsKeyDown(Enum.KeyCode.Space) and (not inputService:GetFocusedTextBox()) then
								root.Velocity = Vector3.new(root.Velocity.X, 38, root.Velocity.Z)
							end
	
							for i = Expand.Value, 1, -1 do
								local currentpos = roundPos(root.Position - Vector3.new(0, entitylib.character.HipHeight + (Downwards.Enabled and inputService:IsKeyDown(Enum.KeyCode.LeftShift) and 4.5 or 1.5), 0) + entitylib.character.Humanoid.MoveDirection * (i * 3))
								if Diagonal.Enabled then
									if math.abs(math.round(math.deg(math.atan2(-entitylib.character.Humanoid.MoveDirection.X, -entitylib.character.Humanoid.MoveDirection.Z)) / 45) * 45) % 90 == 45 then
										local dt = (lastpos - currentpos)
										if ((dt.X == 0 and dt.Z ~= 0) or (dt.X ~= 0 and dt.Z == 0)) and ((lastpos - root.Position) * Vector3.new(1, 0, 1)).Magnitude < 2.5 then
											currentpos = lastpos
										end
									end
								end
	
								local block, blockpos = getPlacedBlock(currentpos)
								if not block then
									blockpos = checkAdjacent(blockpos * 3) and blockpos * 3 or blockProximity(currentpos)
									if blockpos then
										task.spawn(bedwars.placeBlock, blockpos, wool, false)
									end
								end
								lastpos = currentpos
							end
						end
					end
	
					task.wait(0.03)
				until not Scaffold.Enabled
			else
				Label = nil
			end
		end,
		Tooltip = 'Helps you make bridges/scaffold walk.'
	})
	Expand = Scaffold:CreateSlider({
		Name = 'Expand',
		Min = 1,
		Max = 2
	})
	Tower = Scaffold:CreateToggle({
		Name = 'Tower',
		Default = true
	})
	Downwards = Scaffold:CreateToggle({
		Name = 'Downwards',
		Default = true
	})
	Diagonal = Scaffold:CreateToggle({
		Name = 'Diagonal',
		Default = true
	})
	LimitItem = Scaffold:CreateToggle({Name = 'Limit to items'})
	Mouse = Scaffold:CreateToggle({Name = 'Require mouse down'})
	Count = Scaffold:CreateToggle({
		Name = 'Block Count',
		Function = function(callback)
			if callback then
				label = Instance.new('TextLabel')
				label.Size = UDim2.fromOffset(100, 20)
				label.Position = UDim2.new(0.5, 6, 0.5, 60)
				label.BackgroundTransparency = 1
				label.AnchorPoint = Vector2.new(0.5, 0)
				label.Text = '0'
				label.TextColor3 = Color3.new(0, 1, 0)
				label.TextSize = 18
				label.RichText = true
				label.Font = Enum.Font.Arial
				label.Visible = Scaffold.Enabled
				label.Parent = vape.gui
			else
				label:Destroy()
				label = nil
			end
		end
	})
end)

run(function()
	local ShopTierBypass
	local tiered, nexttier = {}, {}
	
	ShopTierBypass = vape.Categories.Utility:CreateModule({
		Name = 'ShopTierBypass',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.shopLoaded or not ShopTierBypass.Enabled
				if ShopTierBypass.Enabled then
					for _, v in bedwars.Shop.ShopItems do
						tiered[v] = v.tiered
						nexttier[v] = v.nextTier
						v.nextTier = nil
						v.tiered = nil
					end
				end
			else
				for i, v in tiered do
					i.tiered = v
				end
				for i, v in nexttier do
					i.nextTier = v
				end
				table.clear(nexttier)
				table.clear(tiered)
			end
		end,
		Tooltip = 'Lets you buy things like armor early.'
	})
end)
	
run(function()
	local StaffDetector
	local Mode
	local Clans
	local Party
	local Profile
	local Users
	local blacklistedclans = {'gg', 'gg2', 'DV', 'DV2'}
	local blacklisteduserids = {1502104539, 3826146717, 4531785383, 1049767300, 4926350670, 653085195, 184655415, 2752307430, 5087196317, 5744061325, 1536265275}
	local joined = {}
	
	local function getRole(plr, id)
		local suc, res = pcall(function()
			return plr:GetRankInGroup(id)
		end)
		if not suc then
			notif('StaffDetector', res, 30, 'alert')
		end
		return suc and res or 0
	end
	
	local function staffFunction(plr, checktype)
		if not vape.Loaded then
			repeat task.wait() until vape.Loaded
		end
	
		notif('StaffDetector', 'Staff Detected ('..checktype..'): '..plr.Name..' ('..plr.UserId..')', 60, 'alert')
		whitelist.customtags[plr.Name] = {{text = 'GAME STAFF', color = Color3.new(1, 0, 0)}}
	
		if Party.Enabled and not checktype:find('clan') then
			bedwars.PartyController:leaveParty()
		end
	
		if Mode.Value == 'Uninject' then
			task.spawn(function()
				vape:Uninject()
			end)
			game:GetService('StarterGui'):SetCore('SendNotification', {
				Title = 'StaffDetector',
				Text = 'Staff Detected ('..checktype..')\n'..plr.Name..' ('..plr.UserId..')',
				Duration = 60,
			})
		elseif Mode.Value == 'Requeue' then
			bedwars.QueueController:joinQueue(store.queueType)
		elseif Mode.Value == 'Profile' then
			vape.Save = function() end
			if vape.Profile ~= Profile.Value then
				vape:Load(true, Profile.Value)
			end
		elseif Mode.Value == 'AutoConfig' then
			local safe = {'AutoClicker', 'Reach', 'Sprint', 'HitFix', 'StaffDetector'}
			vape.Save = function() end
			for i, v in vape.Modules do
				if not (table.find(safe, i) or v.Category == 'Render') then
					if v.Enabled then
						v:Toggle()
					end
					v:SetBind('')
				end
			end
		end
	end
	
	local function checkFriends(list)
		for _, v in list do
			if joined[v] then
				return joined[v]
			end
		end
		return nil
	end
	
	local function checkJoin(plr, connection)
		if not plr:GetAttribute('Team') and plr:GetAttribute('Spectator') and not bedwars.Store:getState().Game.customMatch then
			connection:Disconnect()
			local tab, pages = {}, playersService:GetFriendsAsync(plr.UserId)
			for _ = 1, 4 do
				for _, v in pages:GetCurrentPage() do
					table.insert(tab, v.Id)
				end
				if pages.IsFinished then break end
				pages:AdvanceToNextPageAsync()
			end
	
			local friend = checkFriends(tab)
			if not friend then
				staffFunction(plr, 'impossible_join')
				return true
			else
				notif('StaffDetector', string.format('Spectator %s joined from %s', plr.Name, friend), 20, 'warning')
			end
		end
	end
	
	local function playerAdded(plr)
		joined[plr.UserId] = plr.Name
		if plr == lplr then return end
	
		if table.find(blacklisteduserids, plr.UserId) or table.find(Users.ListEnabled, tostring(plr.UserId)) then
			staffFunction(plr, 'blacklisted_user')
		elseif getRole(plr, 5774246) >= 100 then
			staffFunction(plr, 'staff_role')
		else
			local connection
			connection = plr:GetAttributeChangedSignal('Spectator'):Connect(function()
				checkJoin(plr, connection)
			end)
			StaffDetector:Clean(connection)
			if checkJoin(plr, connection) then
				return
			end
	
			if not plr:GetAttribute('ClanTag') then
				plr:GetAttributeChangedSignal('ClanTag'):Wait()
			end
	
			if table.find(blacklistedclans, plr:GetAttribute('ClanTag')) and vape.Loaded and Clans.Enabled then
				connection:Disconnect()
				staffFunction(plr, 'blacklisted_clan_'..plr:GetAttribute('ClanTag'):lower())
			end
		end
	end
	
	StaffDetector = vape.Categories.Utility:CreateModule({
		Name = 'StaffDetector',
		Function = function(callback)
			if callback then
				StaffDetector:Clean(playersService.PlayerAdded:Connect(playerAdded))
				for _, v in playersService:GetPlayers() do
					task.spawn(playerAdded, v)
				end
			else
				table.clear(joined)
			end
		end,
		Tooltip = 'Detects people with a staff rank ingame'
	})
	Mode = StaffDetector:CreateDropdown({
		Name = 'Mode',
		List = {'Uninject', 'Profile', 'Requeue', 'AutoConfig', 'Notify'},
		Function = function(val)
			if Profile.Object then
				Profile.Object.Visible = val == 'Profile'
			end
		end
	})
	Clans = StaffDetector:CreateToggle({
		Name = 'Blacklist clans',
		Default = true
	})
	Party = StaffDetector:CreateToggle({
		Name = 'Leave party'
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
	
	task.spawn(function()
		repeat task.wait(1) until vape.Loaded or vape.Loaded == nil
		if vape.Loaded and not StaffDetector.Enabled then
			StaffDetector:Toggle()
		end
	end)
end)
run(function()
    local RepelLag
    local Delay
    local TransmissionOffset
    local originalRemotes = {}
    local queuedCalls = {}
    local isProcessing = false
    local callInterception = {}
    
    local function backupRemoteMethods()
        if not bedwars or not bedwars.Client then return end
        
        local oldGet = bedwars.Client.Get
        callInterception.oldGet = oldGet
        
        for name, path in pairs(remotes) do
            local remote = oldGet(bedwars.Client, path)
            if remote and remote.SendToServer then
                originalRemotes[path] = remote.SendToServer
            end
        end
    end
    
    local function processDelayedCalls()
        if isProcessing then return end
        isProcessing = true
        
        task.spawn(function()
            while RepelLag.Enabled and #queuedCalls > 0 do
                local currentTime = tick()
                local toExecute = {}
                
                for i = #queuedCalls, 1, -1 do
                    local call = queuedCalls[i]
                    if currentTime >= call.executeTime then
                        table.insert(toExecute, 1, call)
                        table.remove(queuedCalls, i)
                    end
                end
                
                for _, call in ipairs(toExecute) do
                    pcall(function()
                        if call.remote and call.method == "FireServer" then
                            call.remote:FireServer(unpack(call.args))
                        elseif call.remote and call.method == "InvokeServer" then
                            call.remote:InvokeServer(unpack(call.args))
                        elseif call.originalFunc then
                            call.originalFunc(call.remote, unpack(call.args))
                        end
                    end)
                end
                
                task.wait(0.001)
            end
            isProcessing = false
        end)
    end
    
    local function queueRemoteCall(remote, method, originalFunc, ...)
        local currentDelay = Delay.Value
            if entitylib.isAlive then
                local nearestDist = math.huge
                for _, entity in ipairs(entitylib.List) do
                    if entity.Targetable and entity.Player and entity.Player ~= lplr then
                        local dist = (entity.RootPart.Position - entitylib.character.RootPart.Position).Magnitude
                        if dist < nearestDist then
                            nearestDist = dist
                        end
                    end
                end
                
                if nearestDist < 15 then
                    local repelFactor = (15 - nearestDist) / 15
                    currentDelay = currentDelay * (1 + (repelFactor * 2))
                end
            end
        
        if TransmissionOffset.Value > 0 then
            local jitter = math.random(-TransmissionOffset.Value, TransmissionOffset.Value)
            currentDelay = math.max(0, currentDelay + jitter)
        end
        
        table.insert(queuedCalls, {
            remote = remote,
            method = method,
            originalFunc = originalFunc,
            args = {...},
            executeTime = tick() + (currentDelay / 1000)
        })
        
        processDelayedCalls()
    end
    
    local function interceptRemotes()
        if not bedwars or not bedwars.Client then return end
        
        local oldGet = callInterception.oldGet
        bedwars.Client.Get = function(self, remotePath)
            local remote = oldGet(self, remotePath)
            
            if remote and remote.SendToServer then
                local originalSend = remote.SendToServer
                remote.SendToServer = function(self, ...)
                    if RepelLag.Enabled and Delay.Value > 0 then
                        queueRemoteCall(self, "SendToServer", originalSend, ...)
                        return
                    end
                    return originalSend(self, ...)
                end
            end
            
            return remote
        end
        
        local function interceptSpecificRemote(path)
            local remote = oldGet(bedwars.Client, path)
            if remote and remote.FireServer then
                local originalFire = remote.FireServer
                remote.FireServer = function(self, ...)
                    if RepelLag.Enabled and Delay.Value > 0 then
                        queueRemoteCall(self, "FireServer", originalFire, ...)
                        return
                    end
                    return originalFire(self, ...)
                end
            end
        end
        
        if remotes.AttackEntity then interceptSpecificRemote(remotes.AttackEntity) end
        if remotes.PlaceBlockEvent then interceptSpecificRemote(remotes.PlaceBlockEvent) end
        if remotes.BreakBlockEvent then interceptSpecificRemote(remotes.BreakBlockEvent) end
    end
    
    RepelLag = vape.Categories.World:CreateModule({
        Name = 'RepelLag',
        Function = function(callback)
            if callback then
                backupRemoteMethods()
                interceptRemotes()
                
            else
                if bedwars and bedwars.Client and callInterception.oldGet then
                    bedwars.Client.Get = callInterception.oldGet
                end
                
                for _, call in ipairs(queuedCalls) do
                    pcall(function()
                        if call.originalFunc then
                            call.originalFunc(call.remote, unpack(call.args))
                        end
                    end)
                end
                table.clear(queuedCalls)
            end
        end,
        Tooltip = 'Desync but sync\'s with the current world making you look fakelag and alittle with backtrack'

    })
    TransmissionOffset = RepelLag:CreateSlider({
		Name = "Transmission",
		Min = 0,
		Max = 5,
		Default = 2,
		Tooltip = 'jitteries ur movement'
	})
	Delay = RepelLag:CreateSlider({
		Name = "Delay",
		Suffix = "ms",
		Min = 5,
		Max = 1000,
		Default = math.floor(math.random(100,250) - math.random(1,5) - math.random())
	})
    
end)
run(function()
    local AutoWin
	local function Duels()
		if Speed.Enabled and Fly.Enabled then
			Fly:Toggle(false)
			task.wait(0.025)
			Speed:Toggle(false)
		elseif Speed.Enabled then
			Speed:Toggle(false)
		elseif Fly.Enabled then
			Fly:Toggle(false)
		end

		if not Scaffold.Enabled and not Breaker.Enabled then
			Breaker:Toggle(true)
			task.wait(0.025)
			Scaffold:Toggle(true)
		elseif not Scaffold.Enabled then
			Scaffold:Toggle(true)
		elseif not Breaker.Enabled then
			Breaker:Toggle(true)
		end

                    local T = 50
                    if #playersService:GetChildren() > 1 then
                        vape:CreateNotification("AutoWin", "Teleporting to Empty Game!", 6)
                        task.wait((6 / 3.335))
                        local data = TeleportService:GetLocalPlayerTeleportData()
                        AutoWin:Clean(TeleportService:Teleport(game.PlaceId, lplr, data))
                    end
                    if lplr.Team.Name ~= "Orange" and lplr.Team.Name ~= "Blue" then
                        vape:CreateNotification("AutoWin","Waiting for an assigned team! (this may take a while if early loaded)", 6)
                        task.wait(15)
                    end
                    local ID = lplr:GetAttribute("Team")
                    local GeneratorName = "cframe-" .. ID .. "_generator"
                    local ItemShopName = ID .. "_item_shop"
					if ID == "2" then
						ItemShopName = ID .. "_item_shop_1"
					else
						ItemShopName = ItemShopName
					end
                    local CurrentGen = workspace:FindFirstChild(GeneratorName)
                    local CurrentItemShop = workspace:FindFirstChild(ItemShopName)
                    local id = "0"
                	local oppTeamName = "nil"
                    if ID == "1" then
                        id = "2"
                        oppTeamName = "Orange"
                    else
                        id = "1"
                        oppTeamName = "Blue"
                    end
                    local OppBedName = id .. "_bed"
                    local OppositeTeamBedPos = workspace:FindFirstChild("MapCFrames"):FindFirstChild(OppBedName).Value.Position

					local function PurchaseWool()
					    replicatedStorage.rbxts_include.node_modules["@rbxts"].net.out._NetManaged.BedwarsPurchaseItem:InvokeServer({
					        shopItem = {
					            currency = "iron",
					            itemType = "wool_white",
					            amount = 16,
					            price = 8,
					            category = "Blocks",
					            disabledInQueue = {"mine_wars"}
					        },
					        shopId = "1_item_shop"
					    })
					end
					
					local function fly()
					    task.spawn(function()
					        while task.wait() do
					            if entitylib and entitylib.isAlive then
					                local char = lplr.Character
					                local root = char and char.PrimaryPart
					                if root then
					                    local v = root.Velocity
					                    root.Velocity = Vector3.new(v.X, 0, v.Z)
					                end
					            end
					        end
					    end)
					end
					
					local function Speed()
					    task.spawn(function()
					        while task.wait() do
					            if entitylib and entitylib.isAlive then
					                local hum = lplr.Character and lplr.Character:FindFirstChildOfClass("Humanoid")
					                if hum then
					                    hum.WalkSpeed = 23.05
					                end
					            end
					        end
					    end)
					end
					
					local function checkWallClimb()
					    if not (entitylib and entitylib.isAlive) then
					        return false
					    end
					
					    local character = lplr.Character
					    local root = character and character.PrimaryPart
					    if not root then
					        return false
					    end
					
					    local raycastParams = RaycastParams.new()
					    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
					    raycastParams.FilterDescendantsInstances = {
					        character,
					        camera and camera:FindFirstChild("Viewmodel"),
					        Workspace:FindFirstChild("ItemDrops")
					    }
					
					    local origin = root.Position - Vector3.new(0, 1, 0)
					    local direction = root.CFrame.LookVector * 1.5
					
					    local result = Workspace:Raycast(origin, direction, raycastParams)
					    if result and result.Instance and result.Instance.Transparency < 1 then
					        root.Velocity = Vector3.new(root.Velocity.X, 100, root.Velocity.Z)
					    end
					
					    return true
					end
					
					local function climbwalls()
					    task.spawn(function()
					        while task.wait() do
					            if entitylib and entitylib.isAlive then
					                pcall(checkWallClimb)
					            else
					                break
					            end
					        end
					    end)
					end
                        local function MapLayoutBLUE()
                            if workspace.Map.Worlds:FindFirstChild("duels_Swamp") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.15)
                                local pos = {
                                    [1] = Vector3.new(54.42063522338867, 22.4999942779541, 99.56651306152344),
                                    [2] = Vector3.new(119.33378601074219, 22.4999942779541, 99.06503295898438),
                                    [3] = Vector3.new(231.82752990722656, 19.4999942779541, 98.30278015136719),
                                    [4] = Vector3.new(230.23426818847656, 19.4999942779541, 142.17169189453125),
                                    [5] = Vector3.new(237.4776153564453, 22.4999942779541, 142.03660583496094)
                                }
                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    if i == 5 then
                                        lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                    end
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Blossom") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(153.83029174804688, 37.4999885559082, 146.81619262695312),
                                    [2] = Vector3.new(172.6735382080078, 37.4999885559082, 120.15453338623047),
                                    [3] = Vector3.new(172.6735382080078, 37.4999885559082, 120.15453338623047),
                                    [4] = Vector3.new(284.78765869140625, 37.4999885559082, 124.80931854248047),
                                    [5] = Vector3.new(293.6907958984375, 37.4999885559082, 143.09649658203125)
                                }
                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Darkholm") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(56.4425163269043, 70.4999771118164, 196.7547607421875),
                                    [2] = Vector3.new(188.90316772460938, 70.4999771118164, 198.4145050048828),
                                    [3] = Vector3.new(194.74700927734375, 73.4999771118164, 198.49697875976562),
                                    [4] = Vector3.new(198.50704956054688, 76.4999771118164, 198.38743591308594),
                                    [5] = Vector3.new(201.18421936035156, 79.4999771118164, 198.30943298339844),
                                    [6] = Vector3.new(340.8443603515625, 70.4999771118164, 197.34677124023438)
                                }
                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    if i == 3 or i == 4 or i == 5 or i == 6 then
                                        lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                    end
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Christmas") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(143.5197296142578, 40.4999885559082, 410.59930419921875),
                                    [2] = Vector3.new(143.98350524902344, 40.4999885559082, 328.6651306152344),
                                    [3] = Vector3.new(133.665771484375, 40.4999885559082, 328.6337585449219),
                                    [4] = Vector3.new(134.53382873535156, 40.4999885559082, 253.40147399902344),
                                    [5] = Vector3.new(106.36888122558594, 40.4999885559082, 253.07655334472656),
                                    [6] = Vector3.new(108.05854797363281, 40.4999885559082, 162.84751892089844),
                                    [7] = Vector3.new(150.0508575439453, 40.4999885559082, 139.75106811523438)
                                }
                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Crystalmount") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(56.529605865478516, 31.4999942779541, 117.44342803955078),
                                    [2] = Vector3.new(243.1451873779297, 28.4999942779541, 117.13523864746094),
                                    [3] = Vector3.new(243.86920166015625, 28.4999942779541, 132.01922607421875),
                                    [4] = Vector3.new(284.8253173828125, 28.4999942779541, 131.13760375976562),
                                    [5] = Vector3.new(284.3399963378906, 28.4999942779541, 197.74057006835938),
                                    [6] = Vector3.new(336.2626953125, 28.4999942779541, 197.87362670898438),
                                    [7] = Vector3.new(336.4390563964844, 28.4999942779541, 212.56610107421875)
                                }
                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Desert-Shrine") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(160.9988250732422, 37.4999885559082, 104.86061096191406),
                                    [2] = Vector3.new(211.70367431640625, 37.4999885559082, 104.84205627441406),
                                    [3] = Vector3.new(225.6957244873047, 40.4999885559082, 105.22856140136719),
                                    [4] = Vector3.new(231.78103637695312, 43.4999885559082, 105.20640563964844),
                                    [5] = Vector3.new(240.7913360595703, 46.4999885559082, 105.17339324951172),
                                    [6] = Vector3.new(261.78643798828125, 46.4999885559082, 105.35729217529297),
                                    [7] = Vector3.new(260.72406005859375, 37.4999885559082, 147.41888427734375)
                                }

                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    if i == 4 or i == 5 then
                                        lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                    end
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Canyon") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(106.2856216430664, 22.4999942779541, 167.7103271484375),
                                    [2] = Vector3.new(205.44677734375, 22.4999942779541, 168.1051483154297),
                                    [3] = Vector3.new(206.19129943847656, 22.4999942779541, 122.0677261352539),
                                    [4] = Vector3.new(246.20388793945312, 22.4999942779541, 122.23123931884766),
                                    [5] = Vector3.new(246.25616455078125, 22.4999942779541, 117.90743255615234),
                                    [6] = Vector3.new(340.50830078125, 22.4999942779541, 119.04676818847656),
                                    [7] = Vector3.new(408.0753479003906, 22.4999942779541, 119.86353302001953),
                                    [8] = Vector3.new(408.1478576660156, 25.4999942779541, 147.79750061035156),
                                    [9] = Vector3.new(408.3157958984375, 28.4999942779541, 152.88963317871094),
                                    [10] = Vector3.new(408.40478515625, 31.4999942779541, 156.04873657226562),
                                    [11] = Vector3.new(416.6556396484375, 31.4999942779541, 156.042724609375)
                                }

                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    if i == 3 or i == 9 or i == 10 then
                                        lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                    end
                                    if i == 8 then
                                        task.wait(0.85)
                                        lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                    end
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Fountain-Peaks") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(197.8756103515625, 55.4999885559082, 146.2112274169922),
                                    [2] = Vector3.new(197.74893188476562, 55.4999885559082, 203.87440490722656),
                                    [3] = Vector3.new(197.7208709716797, 55.4999885559082, 216.67771911621094),
                                    [4] = Vector3.new(197.707763671875, 58.4999885559082, 222.7259063720703),
                                    [5] = Vector3.new(197.6983184814453, 61.4999885559082, 228.9031219482422),
                                    [6] = Vector3.new(197.71287536621094, 64.4999771118164, 234.8250732421875),
                                    [7] = Vector3.new(197.7032470703125, 67.4999771118164, 240.8802947998047),
                                    [8] = Vector3.new(197.7696990966797, 70.4999771118164, 242.91575622558594),
                                    [9] = Vector3.new(216.24256896972656, 70.4999771118164, 257.28955078125),
                                    [10] = Vector3.new(216.3074188232422, 70.4999771118164, 278.1252746582031),
                                    [11] = Vector3.new(198.38975524902344, 70.4999771118164, 278.18292236328125),
                                    [12] = Vector3.new(197.85623168945312, 55.4999885559082, 325.6739196777344)
                                }

                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    if i == 4 or i == 5 or i == 6 or i == 7 or i == 8 or i == 9 then
                                        lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                    end
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Glacier") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(170.14671325683594, 28.4999942779541, 101.89541625976562),
                                    [2] = Vector3.new(170.22109985351562, 28.4999942779541, 84.97834777832031),
                                    [3] = Vector3.new(175.1810760498047, 31.4999942779541, 85.0855484008789),
                                    [4] = Vector3.new(183.48684692382812, 34.4999885559082, 85.162353515625),
                                    [5] = Vector3.new(251.9368896484375, 34.4999885559082, 85.79531860351562),
                                    [6] = Vector3.new(251.87530517578125, 34.4999885559082, 123.78746032714844),
                                    [7] = Vector3.new(312.71527099609375, 28.4999942779541, 124.30342864990234),
                                    [8] = Vector3.new(372.5546875, 28.4999942779541, 124.64036560058594)
                                }

                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    if i == 3 or i == 4 then
                                        lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                    end
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Enchanted-Forest") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(150.46469116210938, 16.4999942779541, 86.60432434082031),
                                    [2] = Vector3.new(210.5728759765625, 16.4999942779541, 87.79756164550781),
                                    [3] = Vector3.new(216.8912811279297, 19.4999942779541, 87.77125549316406),
                                    [4] = Vector3.new(222.78244018554688, 22.4999942779541, 87.67369842529297),
                                    [5] = Vector3.new(227.1719512939453, 25.4999942779541, 87.5146484375),
                                    [6] = Vector3.new(226.99400329589844, 25.4999942779541, 130.34024047851562)
                                }

                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    if i == 3 or i == 4 or i == 5 then
                                        lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                    end
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Glade") then
                                vape:CreateNotification("AutoWin", "Teleporting to lobby, incorrect map!", 4, "warning")
                                task.wait(2.25)
                                lobby()
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Mystic") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(220.50648498535156, 61.4999885559082, 56.93876647949219),
                                    [2] = Vector3.new(220.04396057128906, 49.4999885559082, 120.4498519897461),
                                    [3] = Vector3.new(219.68345642089844, 49.4999885559082, 206.69497680664062),
                                    [4] = Vector3.new(186.8123779296875, 49.4999885559082, 206.58248901367188),
                                    [5] = Vector3.new(186.54818725585938, 49.4999885559082, 218.91282653808594),
                                    [6] = Vector3.new(141.8109588623047, 40.4999885559082, 217.94798278808594),
                                    [7] = Vector3.new(141.24285888671875, 40.4999885559082, 236.9816131591797),
                                    [8] = Vector3.new(140.99461364746094, 43.4999885559082, 243.62637329101562),
                                    [9] = Vector3.new(140.87582397460938, 46.4999885559082, 249.68634033203125),
                                    [10] = Vector3.new(140.93898010253906, 49.4999885559082, 256.1976013183594),
                                    [11] = Vector3.new(129.94161987304688, 49.4999885559082, 282.0950012207031),
                                    [12] = Vector3.new(129.7279815673828, 49.4999885559082, 341.5072326660156),
                                    [13] = Vector3.new(137.8108367919922, 49.4999885559082, 341.5338134765625),
                                    [14] = Vector3.new(137.6667022705078, 40.4999885559082, 382.5955810546875),
                                    [15] = Vector3.new(153.81500244140625, 40.4999885559082, 381.9942321777344),
                                    [16] = Vector3.new(159.4097442626953, 43.4999885559082, 381.96942138671875),
                                    [17] = Vector3.new(165.2544708251953, 46.4999885559082, 381.9435119628906),
                                    [18] = Vector3.new(172.84909057617188, 49.4999885559082, 381.909912109375),
                                    [19] = Vector3.new(181.5446319580078, 49.4999885559082, 383.2634582519531),
                                    [20] = Vector3.new(181.60052490234375, 49.4999885559082, 391.0975646972656),
                                    [21] = Vector3.new(218.74085998535156, 49.4999885559082, 391.41815185546875)
                                }

                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    if i == 8 or i == 9 or i == 10 or i == 11 or i == 16 or i == 17 or i == 18 then
                                        lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                    end
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Nordic") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(149.74044799804688, 55.4999885559082, 128.84291076660156),
                                    [2] = Vector3.new(149.46397399902344, 52.4999885559082, 119.18580627441406),
                                    [3] = Vector3.new(194.9976806640625, 49.4999885559082, 118.41926574707031),
                                    [4] = Vector3.new(194.60174560546875, 49.4999885559082, 80.95228576660156),
                                    [5] = Vector3.new(251.18060302734375, 49.4999885559082, 81.73896789550781),
                                    [6] = Vector3.new(250.67430114746094, 49.4999885559082, 117.65328979492188),
                                    [7] = Vector3.new(277.3354797363281, 49.4999885559082, 118.02685546875),
                                    [8] = Vector3.new(301.5650634765625, 52.4999885559082, 119.07581329345703)
                                }

                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    if i == 8 then
                                        lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                    end
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Nordic-Snowy") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(149.74044799804688, 55.4999885559082, 128.84291076660156),
                                    [2] = Vector3.new(149.46397399902344, 52.4999885559082, 119.18580627441406),
                                    [3] = Vector3.new(194.9976806640625, 49.4999885559082, 118.41926574707031),
                                    [4] = Vector3.new(194.60174560546875, 49.4999885559082, 80.95228576660156),
                                    [5] = Vector3.new(251.18060302734375, 49.4999885559082, 81.73896789550781),
                                    [6] = Vector3.new(250.67430114746094, 49.4999885559082, 117.65328979492188),
                                    [7] = Vector3.new(277.3354797363281, 49.4999885559082, 118.02685546875),
                                    [8] = Vector3.new(301.5650634765625, 52.4999885559082, 119.07581329345703)
                                }

                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    if i == 8 then
                                        lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                    end
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Pinewood") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(129.2021026611328, 28.4999942779541, 135.2041473388672),
                                    [2] = Vector3.new(153.8468475341797, 28.4999942779541, 136.81089782714844),
                                    [3] = Vector3.new(167.808837890625, 25.4999942779541, 204.21250915527344),
                                    [4] = Vector3.new(167.5161590576172, 25.4999942779541, 225.06863403320312),
                                    [5] = Vector3.new(167.30459594726562, 28.4999942779541, 250.10618591308594),
                                    [6] = Vector3.new(126.89143371582031, 28.4999942779541, 249.57664489746094)
                                }

                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    if i == 5 then
                                        lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                    end
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Seasonal") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(124.22999572753906, 22.4999942779541, 50.354896545410156),
                                    [2] = Vector3.new(124.38113403320312, 25.4999942779541, 77.86675262451172),
                                    [3] = Vector3.new(132.7975616455078, 25.4999942779541, 77.82051849365234),
                                    [4] = Vector3.new(132.92849731445312, 25.4999942779541, 101.65450286865234),
                                    [5] = Vector3.new(133.16488647460938, 25.4999942779541, 193.8179931640625),
                                    [6] = Vector3.new(133.18614196777344, 28.4999942779541, 202.04595947265625),
                                    [7] = Vector3.new(133.21290588378906, 31.4999942779541, 212.46200561523438),
                                    [8] = Vector3.new(133.52256774902344, 25.4999942779541, 297.04766845703125)
                                }

                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    if i == 2 or i == 6 or i == 7 or i == 8 then
                                        lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                    end
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Snowman-Park") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(161.58139038085938, 16.4999942779541, 171.4049530029297),
                                    [2] = Vector3.new(205.41207885742188, 16.4999942779541, 171.3085174560547),
                                    [3] = Vector3.new(205.36370849609375, 16.4999942779541, 149.45138549804688)
                                }

                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_SteamPunk") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(160.793701171875, 82.4999771118164, 180.54180908203125),
                                    [2] = Vector3.new(218.45816040039062, 82.4999771118164, 179.80137634277344),
                                    [3] = Vector3.new(260.0395202636719, 82.4999771118164, 180.11831665039062),
                                    [4] = Vector3.new(265.80975341796875, 85.4999771118164, 180.09951782226562),
                                    [5] = Vector3.new(272.1552429199219, 88.4999771118164, 180.07870483398438),
                                    [6] = Vector3.new(292.67315673828125, 91.4999771118164, 179.76800537109375),
                                    [7] = Vector3.new(292.5359191894531, 91.4999771118164, 212.19924926757812),
                                    [8] = Vector3.new(292.81573486328125, 94.4999771118164, 216.00205993652344),
                                    [9] = Vector3.new(292.77001953125, 97.4999771118164, 219.78807067871094),
                                    [10] = Vector3.new(292.73516845703125, 100.4999771118164, 222.6680145263672),
                                    [11] = Vector3.new(292.6996154785156, 103.4999771118164, 225.60629272460938),
                                    [12] = Vector3.new(292.6380920410156, 106.4999771118164, 230.70294189453125),
                                    [13] = Vector3.new(339.04364013671875, 106.4999771118164, 231.263916015625),
                                    [14] = Vector3.new(336.16845703125, 106.4999771118164, 204.35227966308594),
                                    [15] = Vector3.new(344.0719299316406, 109.4999771118164, 204.4552001953125),
                                    [16] = Vector3.new(381.0630798339844, 91.4999771118164, 204.93626403808594),
                                    [17] = Vector3.new(381.4077453613281, 91.4999771118164, 178.77200317382812)
                                }

                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    if i == 4 or i == 5 or i == 6 then
                                        lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                    end
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Volatile") then
                                vape:CreateNotification("AutoWin", "Teleporting to lobby, incorrect map!", 4, "warning")
                                task.wait(2.25)
                                lobby()
                            else
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(3)
                            end
                        end

                        local function MapLayoutORANGE()
                            if workspace.Map.Worlds:FindFirstChild("duels_Swamp") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.15)
                                local pos = {
                                    [1] = Vector3.new(354.59832763671875, 22.4999942779541, 141.19931030273438),
                                    [2] = Vector3.new(288.35980224609375, 22.4999942779541, 140.82131958007812),
                                    [3] = Vector3.new(178.31858825683594, 19.4999942779541, 140.5794677734375),
                                    [4] = Vector3.new(178.41314697265625, 19.4999942779541, 97.60221862792969),
                                    [5] = Vector3.new(167.98536682128906, 22.4999942779541, 97.5783920288086)
                                }
                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    if i == 5 then
                                        lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                    end
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Blossom") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(305.7127685546875, 37.4999885559082, 143.80267333984375),
                                    [2] = Vector3.new(294.0784912109375, 37.4999885559082, 166.19984436035156),
                                    [3] = Vector3.new(172.51058959960938, 37.4999885559082, 166.019287109375),
                                    [4] = Vector3.new(172.54029846191406, 37.4999885559082, 142.85401916503906),
                                    [5] = Vector3.new(153.874755859375, 37.4999885559082, 142.830078125)
                                }
                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Darkholm") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(459.380615234375, 70.4999771118164, 185.4072265625),
                                    [2] = Vector3.new(327.0589599609375, 70.4999771118164, 185.53668212890625),
                                    [3] = Vector3.new(321.13018798828125, 73.4999771118164, 185.5518341064453),
                                    [4] = Vector3.new(318.7851867675781, 76.4999771118164, 185.55780029296875),
                                    [5] = Vector3.new(315.27337646484375, 79.4999771118164, 185.56675720214844),
                                    [6] = Vector3.new(173.04278564453125, 70.4999771118164, 185.9304962158203)
                                }
                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    if i == 3 or i == 4 or i == 5 or i == 6 then
                                        lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                    end
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Christmas") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(138.04017639160156, 40.4999885559082, 140.58433532714844),
                                    [2] = Vector3.new(115.14994049072266, 40.4999885559082, 140.646240234375),
                                    [3] = Vector3.new(115.0350341796875, 40.4999885559082, 192.96180725097656),
                                    [4] = Vector3.new(107.36815643310547, 40.4999885559082, 192.94497680664062),
                                    [5] = Vector3.new(107.2378158569336, 40.4999885559082, 252.27471923828125),
                                    [6] = Vector3.new(115.74702453613281, 40.4999885559082, 326.864990234375),
                                    [7] = Vector3.new(145.2953338623047, 40.4999885559082, 326.3784484863281),
                                    [8] = Vector3.new(146.02037048339844, 40.4999885559082, 419.9883117675781),
                                    [9] = Vector3.new(121.12679290771484, 40.4999885559082, 420.07379150390625),
                                    [10] = Vector3.new(120.96660614013672, 40.4999885559082, 431.7377624511719),
                                    [11] = Vector3.new(102.22850036621094, 40.4999885559082, 432.4336242675781)
                                }
                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Crystalmount") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(523.8486328125, 31.4999942779541, 212.9307861328125),
                                    [2] = Vector3.new(404.15264892578125, 28.4999942779541, 212.3941650390625),
                                    [3] = Vector3.new(339.4782409667969, 28.4999942779541, 212.12184143066406),
                                    [4] = Vector3.new(339.5323181152344, 28.4999942779541, 193.957763671875),
                                    [5] = Vector3.new(315.8712158203125, 28.4999942779541, 193.65440368652344),
                                    [6] = Vector3.new(316.3773498535156, 28.4999942779541, 164.9138641357422),
                                    [7] = Vector3.new(268.30816650390625, 28.4999942779541, 165.28636169433594),
                                    [8] = Vector3.new(268.2789306640625, 28.4999942779541, 132.95947265625),
                                    [9] = Vector3.new(248.2838897705078, 28.4999942779541, 132.472412109375),
                                    [10] = Vector3.new(248.64834594726562, 28.4999942779541, 117.51133728027344)
                                }
                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Desert-Shrine") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(408.21319580078125, 43.4999885559082, 147.07444763183594),
                                    [2] = Vector3.new(319.3170166015625, 37.4999885559082, 146.8579864501953),
                                    [3] = Vector3.new(258.67718505859375, 37.4999885559082, 146.6586151123047),
                                    [4] = Vector3.new(251.12399291992188, 40.4999885559082, 146.63404846191406),
                                    [5] = Vector3.new(244.779296875, 43.4999885559082, 146.6132354736328),
                                    [6] = Vector3.new(233.6015625, 46.4999885559082, 146.5764923095703),
                                    [7] = Vector3.new(211.4630889892578, 46.4999885559082, 146.4730224609375),
                                    [8] = Vector3.new(210.13014221191406, 37.4999885559082, 105.5939712524414)
                                }

                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    if i == 4 or i == 5 then
                                        lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                    end
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Canyon") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(409.8771667480469, 22.49999237060547, 116.0271224975586),
                                    [2] = Vector3.new(327.4731750488281, 22.4999942779541, 122.96821594238281),
                                    [3] = Vector3.new(327.6976013183594, 25.4999942779541, 130.06983947753906),
                                    [4] = Vector3.new(326.8793029785156, 25.4999942779541, 165.20481872558594),
                                    [5] = Vector3.new(271.6249084472656, 22.4999942779541, 165.552978515625),
                                    [6] = Vector3.new(271.6521911621094, 22.49999237060547, 169.8865509033203),
                                    [7] = Vector3.new(107.6816177368164, 22.49999237060547, 171.72158813476562),
                                    [8] = Vector3.new(108.24556732177734, 22.49999237060547, 154.60629272460938),
                                    [9] = Vector3.new(108.06343841552734, 25.4999942779541, 141.64547729492188),
                                    [10] = Vector3.new(107.85572814941406, 28.4999942779541, 135.289306640625),
                                    [11] = Vector3.new(106.55116271972656, 31.4999942779541, 122.169677734375)
                                }

                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    if i == 3 or i == 9 or i == 10 or i == 11 then
                                        lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                    end
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Fountain-Peaks") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(197.80709838867188, 55.4999885559082, 380.91845703125),
                                    [2] = Vector3.new(198.08798217773438, 55.4999885559082, 330.4879150390625),
                                    [3] = Vector3.new(198.1407470703125, 55.4999885559082, 319.4066162109375),
                                    [4] = Vector3.new(198.16429138183594, 58.4999885559082, 314.4744873046875),
                                    [5] = Vector3.new(198.19857788085938, 61.4999885559082, 307.2679443359375),
                                    [6] = Vector3.new(198.23214721679688, 64.4999771118164, 300.2276306152344),
                                    [7] = Vector3.new(198.2572784423828, 67.4999771118164, 294.9621276855469),
                                    [8] = Vector3.new(198.0744171142578, 70.4999771118164, 277.3271484375),
                                    [9] = Vector3.new(198.19863891601562, 73.4999771118164, 261.74713134765625),
                                    [10] = Vector3.new(198.17916870117188, 55.4999885559082, 208.74942016601562),
                                    [11] = Vector3.new(198.27981567382812, 55.4999885559082, 154.0118865966797)
                                }

                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    if i == 4 or i == 5 or i == 6 or i == 7 or i == 8 or i == 9 then
                                        lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                    end
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Glacier") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(307.63275146484375, 28.4999942779541, 107.5975570678711),
                                    [2] = Vector3.new(308.0843811035156, 28.4999942779541, 123.1988296508789),
                                    [3] = Vector3.new(302.8423156738281, 31.4999942779541, 123.20875549316406),
                                    [4] = Vector3.new(224.78607177734375, 34.4999885559082, 123.57905578613281),
                                    [5] = Vector3.new(224.7245635986328, 34.4999885559082, 85.76427459716797),
                                    [6] = Vector3.new(166.7411651611328, 28.4999942779541, 85.52276611328125)
                                }

                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    if i == 3 or i == 4 then
                                        lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                    end
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Enchanted-Forest") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(297.86676025390625, 16.4999942779541, 128.88902282714844),
                                    [2] = Vector3.new(248.98641967773438, 16.4999942779541, 128.79608154296875),
                                    [3] = Vector3.new(239.7410430908203, 19.4999942779541, 128.74380493164062),
                                    [4] = Vector3.new(233.1702117919922, 22.4999942779541, 128.7002716064453),
                                    [5] = Vector3.new(229.46270751953125, 25.4999942779541, 128.67581176757812),
                                    [6] = Vector3.new(229.83551025390625, 25.4999942779541, 82.51109313964844)
                                }

                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    if i == 3 or i == 4 or i == 5 then
                                        lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                    end
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Glade") then
                                vape:CreateNotification("AutoWin", "Teleporting to lobby, incorrect map!", 4, "warning")
                                task.wait(2.25)
                                lobby()
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Mystic") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(221.40838623046875, 49.4999885559082, 398.5241394042969),
                                    [2] = Vector3.new(254.4637451171875, 49.4999885559082, 397.211669921875),
                                    [3] = Vector3.new(254.8128204345703, 49.4999885559082, 386.21221923828125),
                                    [4] = Vector3.new(298.4759216308594, 40.4999885559082, 386.5443420410156),
                                    [5] = Vector3.new(298.58660888671875, 40.4999885559082, 370.09735107421875),
                                    [6] = Vector3.new(298.7728271484375, 43.4999885559082, 362.7982177734375),
                                    [7] = Vector3.new(298.9396667480469, 46.4999885559082, 357.5649108886719),
                                    [8] = Vector3.new(298.80377197265625, 49.4999885559082, 349.3194580078125),
                                    [9] = Vector3.new(298.58892822265625, 49.4999885559082, 339.3221740722656),
                                    [10] = Vector3.new(310.25390625, 49.4999885559082, 339.0869140625),
                                    [11] = Vector3.new(310.1837463378906, 49.4999885559082, 262.0010681152344),
                                    [12] = Vector3.new(300.18365478515625, 49.4999885559082, 261.933349609375),
                                    [13] = Vector3.new(300.37420654296875, 40.4999885559082, 223.8512725830078),
                                    [14] = Vector3.new(285.1274719238281, 40.4999885559082, 223.8217315673828),
                                    [15] = Vector3.new(279.4645690917969, 43.4999885559082, 223.8112335205078),
                                    [16] = Vector3.new(272.19329833984375, 46.4999885559082, 223.79776000976562),
                                    [17] = Vector3.new(266.0102844238281, 49.4999885559082, 223.78663635253906),
                                    [18] = Vector3.new(252.8553924560547, 49.4999885559082, 223.3814239501953),
                                    [19] = Vector3.new(252.7893829345703, 49.4999885559082, 211.234130859375),
                                    [20] = Vector3.new(219.3946075439453, 49.4999885559082, 211.3135223388672)
                                }

                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    if i == 6 or i == 7 or i == 8 or i == 15 or i == 16 or i == 17 then
                                        lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                    end
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Nordic-Snowy") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(292.3473815917969, 37.4999885559082, 128.8502960205078),
                                    [2] = Vector3.new(292.2837829589844, 37.4999885559082, 103.8826904296875),
                                    [3] = Vector3.new(246.86444091796875, 34.4999885559082, 103.998046875),
                                    [4] = Vector3.new(246.81077575683594, 34.4999885559082, 82.9254379272461),
                                    [5] = Vector3.new(198.99082946777344, 34.4999885559082, 83.04700469970703),
                                    [6] = Vector3.new(200.015625, 34.4999885559082, 139.6517333984375),
                                    [7] = Vector3.new(173.64576721191406, 34.4999885559082, 139.46446228027344),
                                    [8] = Vector3.new(150.15530395507812, 37.4999885559082, 139.02587890625)
                                }

                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    if i == 8 then
                                        lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                    end
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Nordic") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(292.3473815917969, 37.4999885559082, 128.8502960205078),
                                    [2] = Vector3.new(292.2837829589844, 37.4999885559082, 103.8826904296875),
                                    [3] = Vector3.new(246.86444091796875, 34.4999885559082, 103.998046875),
                                    [4] = Vector3.new(246.81077575683594, 34.4999885559082, 82.9254379272461),
                                    [5] = Vector3.new(198.99082946777344, 34.4999885559082, 83.04700469970703),
                                    [6] = Vector3.new(200.015625, 34.4999885559082, 139.6517333984375),
                                    [7] = Vector3.new(173.64576721191406, 34.4999885559082, 139.46446228027344),
                                    [8] = Vector3.new(150.15530395507812, 37.4999885559082, 139.02587890625)
                                }

                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    if i == 8 then
                                        lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                    end
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Pinewood") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(129.27752685546875, 28.4999942779541, 241.45860290527344),
                                    [2] = Vector3.new(79.45954132080078, 28.49999237060547, 240.6741943359375),
                                    [3] = Vector3.new(80.80793762207031, 28.49999237060547, 155.99095153808594),
                                    [4] = Vector3.new(91.66584777832031, 28.49999237060547, 156.12608337402344),
                                    [5] = Vector3.new(91.90682983398438, 28.49999237060547, 136.84848022460938),
                                    [6] = Vector3.new(129.66644287109375, 28.49999237060547, 137.31893920898438)
                                }

                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Seasonal") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(135.16567993164062, 22.4999942779541, 409.7474365234375),
                                    [2] = Vector3.new(135.17654418945312, 25.4999942779541, 380.8885803222656),
                                    [3] = Vector3.new(124.0099105834961, 25.49999237060547, 380.8028869628906),
                                    [4] = Vector3.new(124.02178955078125, 25.49999237060547, 280.3576354980469),
                                    [5] = Vector3.new(123.74276733398438, 25.49999237060547, 262.22003173828125),
                                    [6] = Vector3.new(123.6146469116211, 28.4999942779541, 253.8889617919922),
                                    [7] = Vector3.new(123.49169921875, 31.4999942779541, 245.8935546875),
                                    [8] = Vector3.new(123.3890380859375, 25.4999942779541, 169.56488037109375),
                                    [9] = Vector3.new(140.38137817382812, 25.49999237060547, 169.5316925048828)
                                }

                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    if i == 2 or i == 6 or i == 7 then
                                        lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                    end
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Snowman-Park") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(140.38137817382812, 25.49999237060547, 169.5316925048828),
                                    [2] = Vector3.new(244.02467346191406, 16.4999942779541, 193.6885223388672),
                                    [3] = Vector3.new(164.97314453125, 16.49999237060547, 194.03672790527344),
                                    [4] = Vector3.new(164.86520385742188, 16.49999237060547, 169.71209716796875)
                                }

                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_SteamPunk") then
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(2.33)
                                local pos = {
                                    [1] = Vector3.new(459.31365966796875, 82.4999771118164, 180.3105010986328),
                                    [2] = Vector3.new(406.04095458984375, 82.4999771118164, 179.7035369873047),
                                    [3] = Vector3.new(399.0287780761719, 85.4999771118164, 179.84088134765625),
                                    [4] = Vector3.new(393.3252258300781, 88.4999771118164, 179.9452667236328),
                                    [5] = Vector3.new(370.205322265625, 91.4999771118164, 179.96041870117188),
                                    [6] = Vector3.new(371.1557312011719, 91.4999771118164, 148.01693725585938),
                                    [7] = Vector3.new(371.19158935546875, 94.4999771118164, 143.04385375976562),
                                    [8] = Vector3.new(371.111572265625, 97.4999771118164, 140.0428924560547),
                                    [9] = Vector3.new(371.05657958984375, 100.4999771118164, 137.93524169921875),
                                    [10] = Vector3.new(370.9500732421875, 103.4999771118164, 134.1337127685547),
                                    [11] = Vector3.new(370.477294921875, 106.4999771118164, 124.73361206054688),
                                    [12] = Vector3.new(335.9317321777344, 106.4999771118164, 124.79263305664062),
                                    [13] = Vector3.new(335.83599853515625, 106.4999771118164, 154.04205322265625),
                                    [14] = Vector3.new(324.33575439453125, 106.4999771118164, 154.00502014160156),
                                    [15] = Vector3.new(320.086669921875, 109.4999771118164, 153.9910888671875),
                                    [16] = Vector3.new(287.7663269042969, 91.4999771118164, 153.884765625),
                                    [17] = Vector3.new(287.6502380371094, 91.4999771118164, 181.8335723876953)
                                }

                                for i, waypoint in ipairs(pos) do
                                    vape:CreateNotification("AutoWin | Specific", "Fixing Position [" .. i .. "] !", 8)
                                    lplr.Character.Humanoid:MoveTo(waypoint)
                                    if
                                        i == 3 or i == 4 or i == 5 or i == 7 or i == 8 or i == 9 or i == 10 or i == 11 or
                                            i == 15
                                     then
                                        lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                    end
                                    lplr.Character.Humanoid.MoveToFinished:Wait()
                                    task.wait(0.5)
                                end
                            elseif workspace.Map.Worlds:FindFirstChild("duels_Volatile") then
                                vape:CreateNotification("AutoWin", "Teleporting to lobby, incorrect map!", 4, "warning")
                                task.wait(2.25)
                                lobby()
                            else
                                vape:CreateNotification("AutoWin", "Moving back to Iron Gen!", 8)
                                lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                                task.wait(3)
                            end
                        end

                        if CurrentGen then
                            vape:CreateNotification("AutoWin", "Moving to Iron Gen!", 8)
                            lplr.Character.Humanoid:MoveTo(CurrentGen.Value.Position)
                            task.wait((T + 3.33))
                            vape:CreateNotification("AutoWin", "Moving to Shop!", 8)
                            lplr.Character.Humanoid:MoveTo(CurrentItemShop.Position)
                            Speed()
                            task.wait(1.5)
                            vape:CreateNotification("AutoWin", "Purchasing Wool!", 8)
                            task.wait(3)
                            for i = 6, 0, -1 do
                                PurchaseWool()
                                task.wait(0.05)
                            end
                            if oppTeamName == "Orange" then
                                MapLayoutBLUE()
                            else
                                MapLayoutORANGE()
                            end
                            vape:CreateNotification("AutoWin", "Moving to " .. oppTeamName .. "'s Bed!", 8)
                            fly()
                            climbwalls()
                            task.spawn(function()
                                lplr.Character.Humanoid:MoveTo(OppositeTeamBedPos)
                            end)
                            
                            lplr.Character.Humanoid.MoveToFinished:Connect(function()
								lplr.Character.Humanoid:MoveTo(OppositeTeamBedPos)
							end)
                        end
	end

	local function Skywars()
        local T = 10
        if #playersService:GetChildren() > 1 then
            vape:CreateNotification("AutoWin", "Teleporting to Empty Game!", 6)
            task.wait((6 / 3.335))
            local data = TeleportService:GetLocalPlayerTeleportData()
            AutoWin:Clean(TeleportService:Teleport(game.PlaceId, lplr, data))
        end
		task.wait((T + 3.33))
		local Delays = {}
		local function lootChest(chest)
            vape:CreateNotification("AutoWin", "Grabbing Items in chest", 8)
			chest = chest and chest.Value or nil
			local chestitems = chest and chest:GetChildren() or {}
			if #chestitems > 1 and (Delays[chest] or 0) < tick() then
				Delays[chest] = tick() + 0.2
				bedwars.Client:GetNamespace('Inventory'):Get('SetObservedChest'):SendToServer(chest)
		
				for _, v in chestitems do
					if v:IsA('Accessory') then
						task.spawn(function()
							pcall(function()
								bedwars.Client:GetNamespace('Inventory'):Get('ChestGetItem'):CallServer(chest, v)
							end)
						end)
					end
				end
		
				bedwars.Client:GetNamespace('Inventory'):Get('SetObservedChest'):SendToServer(nil)
			end
		end
	
		local localPosition = entitylib.character.RootPart.Position
		local chests = collection('chest', AutoWin)
		repeat task.wait(0.1) until store.queueType ~= 'bedwars_test'
		if not store.queueType:find('skywars') then return end
		for _, v in chests do
			if (localPosition - v.Position).Magnitude <= 30 then
				vape:CreateNotification("AutoWin", "Moving to chest",2)
				entitylib.character.Humanoid:MoveTo(v.Position)
				lootChest(v:FindFirstChild('ChestFolderValue'))
			end
		end
		task.wait(4.85)
        vape:CreateNotification("AutoWin", "Resetting..", 3)
		entitylib.character.Humanoid.Health = (lplr.Character:GetAttribute("MaxHealth") - lplr.Character:GetAttribute("Health"))
		vape:CreateNotification("AutoWin", "Requeueing.", 1.85)
		AutoWin:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
				if deathTable.finalKill and deathTable.entityInstance == lplr.Character and isEveryoneDead() and store.matchState ~= 2 then
					bedwars.QueueController:joinQueue(store.queueType)
				end
		end))
		AutoWin:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(...)
			bedwars.QueueController:joinQueue(store.queueType)
		end))
	end


    AutoWin = vape.Categories.Exploits:CreateModule({
        Name = "AutoWin",
        Tooltip = "makes you go into a empty game and win for you!",
        Function = function(callback)
            if not callback then
           	 	vape:CreateNotification("AutoWin", "Disabled next game!", 4.5, "warning")
                return
            end
			local GameMode = readfile('ReVape/profiles/autowin.txt')
			if GameMode == "duels" then
				Duels()
			elseif GameMode == "skywars" then
				Skywars()
			else
           	 	vape:CreateNotification("AutoWin", "File does not exist? switching to use duels method!", 4.5, "warning")
                Duels()
			end
    	end
    })
end)
run(function()
	TrapDisabler = vape.Categories.Utility:CreateModule({
		Name = 'TrapDisabler',
		Tooltip = 'Disables Snap Traps'
	})
end)
	
run(function()
	vape.Categories.World:CreateModule({
		Name = 'Anti-AFK',
		Function = function(callback)
			if callback then
				for _, v in getconnections(lplr.Idled) do
					v:Disconnect()
				end
	
				for _, v in getconnections(runService.Heartbeat) do
					if type(v.Function) == 'function' and table.find(debug.getconstants(v.Function), remotes.AfkStatus) then
						v:Disconnect()
					end
				end
	
				bedwars.Client:Get(remotes.AfkStatus):SendToServer({
					afk = false
				})
			end
		end,
		Tooltip = 'Lets you stay ingame without getting kicked'
	})
end)
	
	
run(function()
	local AutoTool
	local old, event
	
	local function switchHotbarItem(block)
		if block and not block:GetAttribute('NoBreak') and not block:GetAttribute('Team'..(lplr:GetAttribute('Team') or 0)..'NoBreak') then
			local tool, slot = store.tools[bedwars.ItemMeta[block.Name].block.breakType], nil
			if tool then
				for i, v in store.inventory.hotbar do
					if v.item and v.item.itemType == tool.itemType then slot = i - 1 break end
				end
	
				if hotbarSwitch(slot) then
					if inputService:IsMouseButtonPressed(0) then 
						event:Fire() 
					end
					return true
				end
			end
		end
	end
	
	AutoTool = vape.Categories.World:CreateModule({
		Name = 'AutoTool',
		Function = function(callback)
			if callback then
				event = Instance.new('BindableEvent')
				AutoTool:Clean(event)
				AutoTool:Clean(event.Event:Connect(function()
					contextActionService:CallFunction('block-break', Enum.UserInputState.Begin, newproxy(true))
				end))
				old = bedwars.BlockBreaker.hitBlock
				bedwars.BlockBreaker.hitBlock = function(self, maid, raycastparams, ...)
					local block = self.clientManager:getBlockSelector():getMouseInfo(1, {ray = raycastparams})
					if switchHotbarItem(block and block.target and block.target.blockInstance or nil) then return end
					return old(self, maid, raycastparams, ...)
				end
			else
				bedwars.BlockBreaker.hitBlock = old
				old = nil
			end
		end,
		Tooltip = 'Automatically selects the correct tool'
	})
end)
	
	
run(function()
	local ChestSteal
	local Range
	local Open
	local Skywars
	local Delays = {}
	
	local function lootChest(chest)
		chest = chest and chest.Value or nil
		local chestitems = chest and chest:GetChildren() or {}
		if #chestitems > 1 and (Delays[chest] or 0) < tick() then
			Delays[chest] = tick() + 0.2
			bedwars.Client:GetNamespace('Inventory'):Get('SetObservedChest'):SendToServer(chest)
	
			for _, v in chestitems do
				if v:IsA('Accessory') then
					task.spawn(function()
						pcall(function()
							bedwars.Client:GetNamespace('Inventory'):Get('ChestGetItem'):CallServer(chest, v)
						end)
					end)
				end
			end
	
			bedwars.Client:GetNamespace('Inventory'):Get('SetObservedChest'):SendToServer(nil)
		end
	end
	
	ChestSteal = vape.Categories.World:CreateModule({
		Name = 'ChestSteal',
		Function = function(callback)
			if callback then
				local chests = collection('chest', ChestSteal)
				repeat task.wait() until store.queueType ~= 'bedwars_test'
				if (not Skywars.Enabled) or store.queueType:find('skywars') then
					repeat
						if entitylib.isAlive and store.matchState ~= 2 then
							if Open.Enabled then
								if bedwars.AppController:isAppOpen('ChestApp') then
									lootChest(lplr.Character:FindFirstChild('ObservedChestFolder'))
								end
							else
								local localPosition = entitylib.character.RootPart.Position
								for _, v in chests do
									if (localPosition - v.Position).Magnitude <= Range.Value then
										lootChest(v:FindFirstChild('ChestFolderValue'))
									end
								end
							end
						end
						task.wait(0.1)
					until not ChestSteal.Enabled
				end
			end
		end,
		Tooltip = 'Grabs items from near chests.'
	})
	Range = ChestSteal:CreateSlider({
		Name = 'Range',
		Min = 0,
		Max = 18,
		Default = 18,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Open = ChestSteal:CreateToggle({Name = 'GUI Check'})
	Skywars = ChestSteal:CreateToggle({
		Name = 'Only Skywars',
		Function = function()
			if ChestSteal.Enabled then
				ChestSteal:Toggle()
				ChestSteal:Toggle()
			end
		end,
		Default = true
	})
end)
	
	
run(function()
	local AutoBuy
	local Sword
	local Armor
	local Upgrades
	local TierCheck
	local BedwarsCheck
	local GUI
	local SmartCheck
	local Custom = {}
	local CustomPost = {}
	local UpgradeToggles = {}
	local Functions, id = {}
	local Callbacks = {Custom, Functions, CustomPost}
	local npctick = tick()
	
	local swords = {
		'wood_sword',
		'stone_sword',
		'iron_sword',
		'diamond_sword',
		'emerald_sword'
	}
	
	local armors = {
		'none',
		'leather_chestplate',
		'iron_chestplate',
		'diamond_chestplate',
		'emerald_chestplate'
	}
	
	local axes = {
		'none',
		'wood_axe',
		'stone_axe',
		'iron_axe',
		'diamond_axe'
	}
	
	local pickaxes = {
		'none',
		'wood_pickaxe',
		'stone_pickaxe',
		'iron_pickaxe',
		'diamond_pickaxe'
	}
	
	local function getShopNPC()
		local shop, items, upgrades, newid = nil, false, false, nil
		if entitylib.isAlive then
			local localPosition = entitylib.character.RootPart.Position
			for _, v in store.shop do
				if (v.RootPart.Position - localPosition).Magnitude <= 20 then
					shop = v.Upgrades or v.Shop or nil
					upgrades = upgrades or v.Upgrades
					items = items or v.Shop
					newid = v.Shop and v.Id or newid
				end
			end
		end
		return shop, items, upgrades, newid
	end
	
	local function canBuy(item, currencytable, amount)
		amount = amount or 1
		if not currencytable[item.currency] then
			local currency = getItem(item.currency)
			currencytable[item.currency] = currency and currency.amount or 0
		end
		if item.ignoredByKit and table.find(item.ignoredByKit, store.equippedKit or '') then return false end
		if item.lockedByForge or item.disabled then return false end
		if item.require and item.require.teamUpgrade then
			if (bedwars.Store:getState().Bedwars.teamUpgrades[item.require.teamUpgrade.upgradeId] or -1) < item.require.teamUpgrade.lowestTierIndex then
				return false
			end
		end
		return currencytable[item.currency] >= (item.price * amount)
	end
	
	local function buyItem(item, currencytable)
		if not id then return end
		notif('AutoBuy', 'Bought '..bedwars.ItemMeta[item.itemType].displayName, 3)
		bedwars.Client:Get('BedwarsPurchaseItem'):CallServerAsync({
			shopItem = item,
			shopId = id
		}):andThen(function(suc)
			if suc then
				bedwars.SoundManager:playSound(bedwars.SoundList.BEDWARS_PURCHASE_ITEM)
				bedwars.Store:dispatch({
					type = 'BedwarsAddItemPurchased',
					itemType = item.itemType
				})
				bedwars.BedwarsShopController.alreadyPurchasedMap[item.itemType] = true
			end
		end)
		currencytable[item.currency] -= item.price
	end
	
	local function buyUpgrade(upgradeType, currencytable)
		if not Upgrades.Enabled then return end
		local upgrade = bedwars.TeamUpgradeMeta[upgradeType]
		local currentUpgrades = bedwars.Store:getState().Bedwars.teamUpgrades[lplr:GetAttribute('Team')] or {}
		local currentTier = (currentUpgrades[upgradeType] or 0) + 1
		local bought = false
	
		for i = currentTier, #upgrade.tiers do
			local tier = upgrade.tiers[i]
			if tier.availableOnlyInQueue and not table.find(tier.availableOnlyInQueue, store.queueType) then continue end
	
			if canBuy({currency = 'diamond', price = tier.cost}, currencytable) then
				notif('AutoBuy', 'Bought '..(upgrade.name == 'Armor' and 'Protection' or upgrade.name)..' '..i, 3)
				bedwars.Client:Get('RequestPurchaseTeamUpgrade'):CallServerAsync(upgradeType)
				currencytable.diamond -= tier.cost
				bought = true
			else
				break
			end
		end
	
		return bought
	end
	
	local function buyTool(tool, tools, currencytable)
		local bought, buyable = false
		tool = tool and table.find(tools, tool.itemType) and table.find(tools, tool.itemType) + 1 or math.huge
	
		for i = tool, #tools do
			local v = bedwars.Shop.getShopItem(tools[i], lplr)
			if canBuy(v, currencytable) then
				if SmartCheck.Enabled and bedwars.ItemMeta[tools[i]].breakBlock and i > 2 then
					if Armor.Enabled then
						local currentarmor = store.inventory.inventory.armor[2]
						currentarmor = currentarmor and currentarmor ~= 'empty' and currentarmor.itemType or 'none'
						if (table.find(armors, currentarmor) or 3) < 3 then break end
					end
					if Sword.Enabled then
						if store.tools.sword and (table.find(swords, store.tools.sword.itemType) or 2) < 2 then break end
					end
				end
				bought = true
				buyable = v
			end
			if TierCheck.Enabled and v.nextTier then break end
		end
	
		if buyable then
			buyItem(buyable, currencytable)
		end
	
		return bought
	end
	
	AutoBuy = vape.Categories.World:CreateModule({
		Name = 'AutoBuy',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.queueType ~= 'bedwars_test'
				if BedwarsCheck.Enabled and not store.queueType:find('bedwars') then return end
	
				local lastupgrades
				AutoBuy:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(function()
					if (npctick - tick()) > 1 then npctick = tick() end
				end))
	
				repeat
					local npc, shop, upgrades, newid = getShopNPC()
					id = newid
					if GUI.Enabled then
						if not (bedwars.AppController:isAppOpen('BedwarsItemShopApp') or bedwars.AppController:isAppOpen('TeamUpgradeApp')) then
							npc = nil
						end
					end
	
					if npc and lastupgrades ~= upgrades then
						if (npctick - tick()) > 1 then npctick = tick() end
						lastupgrades = upgrades
					end
	
					if npc and npctick <= tick() and store.matchState ~= 2 and store.shopLoaded then
						local currencytable = {}
						local waitcheck
						for _, tab in Callbacks do
							for _, callback in tab do
								if callback(currencytable, shop, upgrades) then
									waitcheck = true
								end
							end
						end
						npctick = tick() + (waitcheck and 0.4 or math.huge)
					end
	
					task.wait(0.1)
				until not AutoBuy.Enabled
			else
				npctick = tick()
			end
		end,
		Tooltip = 'Automatically buys items when you go near the shop'
	})
	Sword = AutoBuy:CreateToggle({
		Name = 'Buy Sword',
		Function = function(callback)
			npctick = tick()
			Functions[2] = callback and function(currencytable, shop)
				if not shop then return end
	
				if store.equippedKit == 'dasher' then
					swords = {
						[1] = 'wood_dao',
						[2] = 'stone_dao',
						[3] = 'iron_dao',
						[4] = 'diamond_dao',
						[5] = 'emerald_dao'
					}
				elseif store.equippedKit == 'ice_queen' then
					swords[5] = 'ice_sword'
				elseif store.equippedKit == 'ember' then
					swords[5] = 'infernal_saber'
				elseif store.equippedKit == 'lumen' then
					swords[5] = 'light_sword'
				end
	
				return buyTool(store.tools.sword, swords, currencytable)
			end or nil
		end
	})
	Armor = AutoBuy:CreateToggle({
		Name = 'Buy Armor',
		Function = function(callback)
			npctick = tick()
			Functions[1] = callback and function(currencytable, shop)
				if not shop then return end
				local currentarmor = store.inventory.inventory.armor[2] ~= 'empty' and store.inventory.inventory.armor[2] or getBestArmor(1)
				currentarmor = currentarmor and currentarmor.itemType or 'none'
				return buyTool({itemType = currentarmor}, armors, currencytable)
			end or nil
		end,
		Default = true
	})
	AutoBuy:CreateToggle({
		Name = 'Buy Axe',
		Function = function(callback)
			npctick = tick()
			Functions[3] = callback and function(currencytable, shop)
				if not shop then return end
				return buyTool(store.tools.wood or {itemType = 'none'}, axes, currencytable)
			end or nil
		end
	})
	AutoBuy:CreateToggle({
		Name = 'Buy Pickaxe',
		Function = function(callback)
			npctick = tick()
			Functions[4] = callback and function(currencytable, shop)
				if not shop then return end
				return buyTool(store.tools.stone, pickaxes, currencytable)
			end or nil
		end
	})
	Upgrades = AutoBuy:CreateToggle({
		Name = 'Buy Upgrades',
		Function = function(callback)
			for _, v in UpgradeToggles do
				v.Object.Visible = callback
			end
		end,
		Default = true
	})
	local count = 0
	for i, v in bedwars.TeamUpgradeMeta do
		local toggleCount = count
		table.insert(UpgradeToggles, AutoBuy:CreateToggle({
			Name = 'Buy '..(v.name == 'Armor' and 'Protection' or v.name),
			Function = function(callback)
				npctick = tick()
				Functions[5 + toggleCount + (v.name == 'Armor' and 20 or 0)] = callback and function(currencytable, shop, upgrades)
					if not upgrades then return end
					if v.disabledInQueue and table.find(v.disabledInQueue, store.queueType) then return end
					return buyUpgrade(i, currencytable)
				end or nil
			end,
			Darker = true,
			Default = (i == 'ARMOR' or i == 'DAMAGE')
		}))
		count += 1
	end
	TierCheck = AutoBuy:CreateToggle({Name = 'Tier Check'})
	BedwarsCheck = AutoBuy:CreateToggle({
		Name = 'Only Bedwars',
		Function = function()
			if AutoBuy.Enabled then
				AutoBuy:Toggle()
				AutoBuy:Toggle()
			end
		end,
		Default = true
	})
	GUI = AutoBuy:CreateToggle({Name = 'GUI check'})
	SmartCheck = AutoBuy:CreateToggle({
		Name = 'Smart check',
		Default = true,
		Tooltip = 'Buys iron armor before iron axe'
	})
	AutoBuy:CreateTextList({
		Name = 'Item',
		Placeholder = 'priority/item/amount/after',
		Function = function(list)
			table.clear(Custom)
			table.clear(CustomPost)
			for _, entry in list do
				local tab = entry:split('/')
				local ind = tonumber(tab[1])
				if ind then
					(tab[4] and CustomPost or Custom)[ind] = function(currencytable, shop)
						if not shop then return end
	
						local v = bedwars.Shop.getShopItem(tab[2], lplr)
						if v then
							local item = getItem(tab[2] == 'wool_white' and bedwars.Shop.getTeamWool(lplr:GetAttribute('Team')) or tab[2])
							item = (item and tonumber(tab[3]) - item.amount or tonumber(tab[3])) // v.amount
							if item > 0 and canBuy(v, currencytable, item) then
								for _ = 1, item do
									buyItem(v, currencytable)
								end
								return true
							end
						end
					end
				end
			end
		end
	})
end)

run(function()
	local AutoConsume
	local Health
	local SpeedPotion
	local Apple
	local ShieldPotion
	
	local function consumeCheck(attribute)
		if entitylib.isAlive then
			if SpeedPotion.Enabled and (not attribute or attribute == 'StatusEffect_speed') then
				local speedpotion = getItem('speed_potion')
				if speedpotion and (not lplr.Character:GetAttribute('StatusEffect_speed')) then
					for _ = 1, 4 do
						if bedwars.Client:Get(remotes.ConsumeItem):CallServer({item = speedpotion.tool}) then break end
					end
				end
			end
	
			if Apple.Enabled and (not attribute or attribute:find('Health')) then
				if (lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) <= (Health.Value / 100) then
					local apple = getItem('orange') or (not lplr.Character:GetAttribute('StatusEffect_golden_apple') and getItem('golden_apple')) or getItem('apple')
					
					if apple then
						bedwars.Client:Get(remotes.ConsumeItem):CallServerAsync({
							item = apple.tool
						})
					end
				end
			end
	
			if ShieldPotion.Enabled and (not attribute or attribute:find('Shield')) then
				if (lplr.Character:GetAttribute('Shield_POTION') or 0) == 0 then
					local shield = getItem('big_shield') or getItem('mini_shield')
	
					if shield then
						bedwars.Client:Get(remotes.ConsumeItem):CallServerAsync({
							item = shield.tool
						})
					end
				end
			end
		end
	end
	
	AutoConsume = vape.Categories.Combat:CreateModule({
		Name = 'AutoConsume',
		Function = function(callback)
			if callback then
				AutoConsume:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(consumeCheck))
				AutoConsume:Clean(vapeEvents.AttributeChanged.Event:Connect(function(attribute)
					if attribute:find('Shield') or attribute:find('Health') or attribute == 'StatusEffect_speed' then
						consumeCheck(attribute)
					end
				end))
				consumeCheck()
			end
		end,
		Tooltip = 'Automatically heals for you when health or shield is under threshold.'
	})
	Health = AutoConsume:CreateSlider({
		Name = 'Health Percent',
		Min = 1,
		Max = 99,
		Default = 70,
		Suffix = '%'
	})
	SpeedPotion = AutoConsume:CreateToggle({
		Name = 'Speed Potions',
		Default = true
	})
	Apple = AutoConsume:CreateToggle({
		Name = 'Apple',
		Default = true
	})
	ShieldPotion = AutoConsume:CreateToggle({
		Name = 'Shield Potions',
		Default = true
	})
end)
	

	
run(function()
	local BedPlates
	local Background
	local Color = {}
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function scanSide(self, start, tab)
		for _, side in sides do
			for i = 1, 15 do
				local block = getPlacedBlock(start + (side * i))
				if not block or block == self then break end
				if not block:GetAttribute('NoBreak') and not table.find(tab, block.Name) then
					table.insert(tab, block.Name)
				end
			end
		end
	end
	
	local function refreshAdornee(v)
		for _, obj in v.Frame:GetChildren() do
			if obj:IsA('ImageLabel') and obj.Name ~= 'Blur' then
				obj:Destroy()
			end
		end
	
		local start = v.Adornee.Position
		local alreadygot = {}
		scanSide(v.Adornee, start, alreadygot)
		scanSide(v.Adornee, start + Vector3.new(0, 0, 3), alreadygot)
		table.sort(alreadygot, function(a, b)
			return (bedwars.ItemMeta[a].block and bedwars.ItemMeta[a].block.health or 0) > (bedwars.ItemMeta[b].block and bedwars.ItemMeta[b].block.health or 0)
		end)
		v.Enabled = #alreadygot > 0
	
		for _, block in alreadygot do
			local blockimage = Instance.new('ImageLabel')
			blockimage.Size = UDim2.fromOffset(32, 32)
			blockimage.BackgroundTransparency = 1
			blockimage.Image = bedwars.getIcon({itemType = block}, true)
			blockimage.Parent = v.Frame
		end
	end
	
	local function Added(v)
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = 'bed'
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = v
		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled
		local frame = Instance.new('Frame')
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		frame.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		frame.Parent = billboard
		local layout = Instance.new('UIListLayout')
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 4)
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			billboard.Size = UDim2.fromOffset(math.max(layout.AbsoluteContentSize.X + 4, 36), 36)
		end)
		layout.Parent = frame
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = frame
		Reference[v] = billboard
		refreshAdornee(billboard)
	end
	
	local function refreshNear(data)
		data = data.blockRef.blockPosition * 3
		for i, v in Reference do
			if (data - i.Position).Magnitude <= 30 then
				refreshAdornee(v)
			end
		end
	end
	
	BedPlates = vape.Categories.Render:CreateModule({
		Name = 'BedPlates',
		Function = function(callback)
			if callback then
				for _, v in collectionService:GetTagged('bed') do 
					task.spawn(Added, v) 
				end
				BedPlates:Clean(vapeEvents.PlaceBlockEvent.Event:Connect(refreshNear))
				BedPlates:Clean(vapeEvents.BreakBlockEvent.Event:Connect(refreshNear))
				BedPlates:Clean(collectionService:GetInstanceAddedSignal('bed'):Connect(Added))
				BedPlates:Clean(collectionService:GetInstanceRemovedSignal('bed'):Connect(function(v)
					if Reference[v] then
						Reference[v]:Destroy()
						Reference[v]:ClearAllChildren()
						Reference[v] = nil
					end
				end))
			else
				table.clear(Reference)
				Folder:ClearAllChildren()
			end
		end,
		Tooltip = 'Displays blocks over the bed'
	})
	Background = BedPlates:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color.Object then 
				Color.Object.Visible = callback 
			end
			for _, v in Reference do
				v.Frame.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
				v.Blur.Visible = callback
			end
		end,
		Default = true
	})
	Color = BedPlates:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			for _, v in Reference do
				v.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				v.Frame.BackgroundTransparency = 1 - opacity
			end
		end,
		Darker = true
	})
end)
	
run(function()
	local Nuker
	local Range
	local UpdateRate
	local Custom
	local Bed
	local LuckyBlock
	local IronOre
	local Effect
	local CustomHealth = {}
	local Animation
	local SelfBreak
	local InstantBreak
	local LimitItem
	local customlist, parts = {}, {}
	
	local function customHealthbar(self, blockRef, health, maxHealth, changeHealth, block)
		if block:GetAttribute('NoHealthbar') then return end
		if not self.healthbarPart or not self.healthbarBlockRef or self.healthbarBlockRef.blockPosition ~= blockRef.blockPosition then
			self.healthbarMaid:DoCleaning()
			self.healthbarBlockRef = blockRef
			local create = bedwars.Roact.createElement
			local percent = math.clamp(health / maxHealth, 0, 1)
			local cleanCheck = true
			local part = Instance.new('Part')
			part.Size = Vector3.one
			part.CFrame = CFrame.new(bedwars.BlockController:getWorldPosition(blockRef.blockPosition))
			part.Transparency = 1
			part.Anchored = true
			part.CanCollide = false
			part.Parent = workspace
			self.healthbarPart = part
			bedwars.QueryUtil:setQueryIgnored(self.healthbarPart, true)
	
			local mounted = bedwars.Roact.mount(create('BillboardGui', {
				Size = UDim2.fromOffset(249, 102),
				StudsOffset = Vector3.new(0, 2.5, 0),
				Adornee = part,
				MaxDistance = 40,
				AlwaysOnTop = true
			}, {
				create('Frame', {
					Size = UDim2.fromOffset(160, 50),
					Position = UDim2.fromOffset(44, 32),
					BackgroundColor3 = Color3.new(),
					BackgroundTransparency = 0.5
				}, {
					create('UICorner', {CornerRadius = UDim.new(0, 5)}),
					create('ImageLabel', {
						Size = UDim2.new(1, 89, 1, 52),
						Position = UDim2.fromOffset(-48, -31),
						BackgroundTransparency = 1,
						Image = getcustomasset('vape/assets/new/blur.png'),
						ScaleType = Enum.ScaleType.Slice,
						SliceCenter = Rect.new(52, 31, 261, 502)
					}),
					create('TextLabel', {
						Size = UDim2.fromOffset(145, 14),
						Position = UDim2.fromOffset(13, 12),
						BackgroundTransparency = 1,
						Text = bedwars.ItemMeta[block.Name].displayName or block.Name,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextColor3 = Color3.new(),
						TextScaled = true,
						Font = Enum.Font.Arial
					}),
					create('TextLabel', {
						Size = UDim2.fromOffset(145, 14),
						Position = UDim2.fromOffset(12, 11),
						BackgroundTransparency = 1,
						Text = bedwars.ItemMeta[block.Name].displayName or block.Name,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextColor3 = color.Dark(uipallet.Text, 0.16),
						TextScaled = true,
						Font = Enum.Font.Arial
					}),
					create('Frame', {
						Size = UDim2.fromOffset(138, 4),
						Position = UDim2.fromOffset(12, 32),
						BackgroundColor3 = uipallet.Main
					}, {
						create('UICorner', {CornerRadius = UDim.new(1, 0)}),
						create('Frame', {
							[bedwars.Roact.Ref] = self.healthbarProgressRef,
							Size = UDim2.fromScale(percent, 1),
							BackgroundColor3 = Color3.fromHSV(math.clamp(percent / 2.5, 0, 1), 0.89, 0.75)
						}, {create('UICorner', {CornerRadius = UDim.new(1, 0)})})
					})
				})
			}), part)
	
			self.healthbarMaid:GiveTask(function()
				cleanCheck = false
				self.healthbarBlockRef = nil
				bedwars.Roact.unmount(mounted)
				if self.healthbarPart then
					self.healthbarPart:Destroy()
				end
				self.healthbarPart = nil
			end)
	
			bedwars.RuntimeLib.Promise.delay(5):andThen(function()
				if cleanCheck then
					self.healthbarMaid:DoCleaning()
				end
			end)
		end
	
		local newpercent = math.clamp((health - changeHealth) / maxHealth, 0, 1)
		tweenService:Create(self.healthbarProgressRef:getValue(), TweenInfo.new(0.3), {
			Size = UDim2.fromScale(newpercent, 1), BackgroundColor3 = Color3.fromHSV(math.clamp(newpercent / 2.5, 0, 1), 0.89, 0.75)
		}):Play()
	end
	
	local hit = 0
	
	local function attemptBreak(tab, localPosition)
		if not tab then return end
		for _, v in tab do
			if (v.Position - localPosition).Magnitude < Range.Value and bedwars.BlockController:isBlockBreakable({blockPosition = v.Position / 3}, lplr) then
				if not SelfBreak.Enabled and v:GetAttribute('PlacedByUserId') == lplr.UserId then continue end
				if (v:GetAttribute('BedShieldEndTime') or 0) > workspace:GetServerTimeNow() then continue end
				if LimitItem.Enabled and not (store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name].breakBlock) then continue end
	
				hit += 1
				local target, path, endpos = bedwars.breakBlock(v, Effect.Enabled, Animation.Enabled, CustomHealth.Enabled and customHealthbar or nil, InstantBreak.Enabled)
				if path then
					local currentnode = target
					for _, part in parts do
						part.Position = currentnode or Vector3.zero
						if currentnode then
							part.BoxHandleAdornment.Color3 = currentnode == endpos and Color3.new(1, 0.2, 0.2) or currentnode == target and Color3.new(0.2, 0.2, 1) or Color3.new(0.2, 1, 0.2)
						end
						currentnode = path[currentnode]
					end
				end
	
				task.wait(InstantBreak.Enabled and (store.damageBlockFail > tick() and 4.5 or 0) or 0.25)
	
				return true
			end
		end
	
		return false
	end
	
	Nuker = vape.Categories.Blatant:CreateModule({
		Name = 'Nuker',
		Function = function(callback)
			if callback then
				for _ = 1, 30 do
					local part = Instance.new('Part')
					part.Anchored = true
					part.CanQuery = false
					part.CanCollide = false
					part.Transparency = 1
					part.Parent = gameCamera
					local highlight = Instance.new('BoxHandleAdornment')
					highlight.Size = Vector3.one
					highlight.AlwaysOnTop = true
					highlight.ZIndex = 1
					highlight.Transparency = 0.5
					highlight.Adornee = part
					highlight.Parent = part
					table.insert(parts, part)
				end
	
				local beds = collection('bed', Nuker)
				local luckyblock = collection('LuckyBlock', Nuker)
				local ironores = collection('iron-ore', Nuker)
				customlist = collection('block', Nuker, function(tab, obj)
					if table.find(Custom.ListEnabled, obj.Name) then
						table.insert(tab, obj)
					end
				end)
	
				repeat
					task.wait(1 / UpdateRate.Value)
					if not Nuker.Enabled then return end
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
	
						if attemptBreak(Bed.Enabled and beds, localPosition) then continue end
						if attemptBreak(customlist, localPosition) then continue end
						if attemptBreak(LuckyBlock.Enabled and luckyblock, localPosition) then continue end
						if attemptBreak(IronOre.Enabled and ironores, localPosition) then continue end
	
						for _, v in parts do
							v.Position = Vector3.zero
						end
					end
				until not Nuker.Enabled
			else
				for _, v in parts do
					v:ClearAllChildren()
					v:Destroy()
				end
				table.clear(parts)
			end
		end,
		Tooltip = 'Break blocks around you automatically'
	})
	Range = Nuker:CreateSlider({
		Name = 'Break range',
		Min = 1,
		Max = 30,
		Default = 30,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	UpdateRate = Nuker:CreateSlider({
		Name = 'Update rate',
		Min = 1,
		Max = 120,
		Default = 60,
		Suffix = 'hz'
	})
	Custom = Nuker:CreateTextList({
		Name = 'Custom',
		Function = function()
			if not customlist then return end
			table.clear(customlist)
			for _, obj in store.blocks do
				if table.find(Custom.ListEnabled, obj.Name) then
					table.insert(customlist, obj)
				end
			end
		end
	})
	Bed = Nuker:CreateToggle({
		Name = 'Break Bed',
		Default = true
	})
	LuckyBlock = Nuker:CreateToggle({
		Name = 'Break Lucky Block',
		Default = true
	})
	IronOre = Nuker:CreateToggle({
		Name = 'Break Iron Ore',
		Default = true
	})
	Effect = Nuker:CreateToggle({
		Name = 'Show Healthbar & Effects',
		Function = function(callback)
			if CustomHealth.Object then
				CustomHealth.Object.Visible = callback
			end
		end,
		Default = true
	})
	CustomHealth = Nuker:CreateToggle({
		Name = 'Custom Healthbar',
		Default = true,
		Darker = true
	})
	Animation = Nuker:CreateToggle({Name = 'Animation'})
	SelfBreak = Nuker:CreateToggle({Name = 'Self Break'})
	InstantBreak = Nuker:CreateToggle({Name = 'Instant Break'})
	LimitItem = Nuker:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only breaks when tools are held'
	})
end)
	
run(function()
	local BedBreakEffect
	local Mode
	local List
	local NameToId = {}
	
	BedBreakEffect = vape.Legit:CreateModule({
		Name = 'Bed Break Effect',
		Function = function(callback)
			if callback then
	            BedBreakEffect:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(data)
	                firesignal(bedwars.Client:Get('BedBreakEffectTriggered').instance.OnClientEvent, {
	                    player = data.player,
	                    position = data.bedBlockPosition * 3,
	                    effectType = NameToId[List.Value],
	                    teamId = data.brokenBedTeam.id,
	                    centerBedPosition = data.bedBlockPosition * 3
	                })
	            end))
	        end
		end,
		Tooltip = 'Custom bed break effects'
	})
	local BreakEffectName = {}
	for i, v in bedwars.BedBreakEffectMeta do
		table.insert(BreakEffectName, v.name)
		NameToId[v.name] = i
	end
	table.sort(BreakEffectName)
	List = BedBreakEffect:CreateDropdown({
		Name = 'Effect',
		List = BreakEffectName
	})
end)
	
run(function()
	vape.Legit:CreateModule({
		Name = 'Clean Kit',
		Function = function(callback)
			if callback then
				bedwars.WindWalkerController.spawnOrb = function() end
				local zephyreffect = lplr.PlayerGui:FindFirstChild('WindWalkerEffect', true)
				if zephyreffect then 
					zephyreffect.Visible = false 
				end
			end
		end,
		Tooltip = 'Removes zephyr status indicator'
	})
end)
		
run(function()
	local FOV
	local Value
	local old, old2
	
	FOV = vape.Legit:CreateModule({
		Name = 'FOV',
		Function = function(callback)
			if callback then
				old = bedwars.FovController.setFOV
				old2 = bedwars.FovController.getFOV
				bedwars.FovController.setFOV = function(self) 
					return old(self, Value.Value) 
				end
				bedwars.FovController.getFOV = function() 
					return Value.Value 
				end
			else
				bedwars.FovController.setFOV = old
				bedwars.FovController.getFOV = old2
			end
			
			bedwars.FovController:setFOV(bedwars.Store:getState().Settings.fov)
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
	local FPSBoost
	local Kill
	local Visualizer
	local effects, util = {}, {}
	
	FPSBoost = vape.Legit:CreateModule({
		Name = 'FPS Boost',
		Function = function(callback)
			if callback then
				if Kill.Enabled then
					for i, v in bedwars.KillEffectController.killEffects do
						if not i:find('Custom') then
							effects[i] = v
							bedwars.KillEffectController.killEffects[i] = {
								new = function() 
									return {
										onKill = function() end, 
										isPlayDefaultKillEffect = function() 
											return true 
										end
									} 
								end
							}
						end
					end
				end
	
				if Visualizer.Enabled then
					for i, v in bedwars.VisualizerUtils do
						util[i] = v
						bedwars.VisualizerUtils[i] = function() end
					end
				end
	
				repeat task.wait() until store.matchState ~= 0
				if not bedwars.AppController then return end
				bedwars.NametagController.addGameNametag = function() end
				for _, v in bedwars.AppController:getOpenApps() do
					if tostring(v):find('Nametag') then
						bedwars.AppController:closeApp(tostring(v))
					end
				end
			else
				for i, v in effects do 
					bedwars.KillEffectController.killEffects[i] = v 
				end
				for i, v in util do 
					bedwars.VisualizerUtils[i] = v 
				end
				table.clear(effects)
				table.clear(util)
			end
		end,
		Tooltip = 'Improves the framerate by turning off certain effects'
	})
	Kill = FPSBoost:CreateToggle({
		Name = 'Kill Effects',
		Function = function()
			if FPSBoost.Enabled then
				FPSBoost:Toggle()
				FPSBoost:Toggle()
			end
		end,
		Default = true
	})
	Visualizer = FPSBoost:CreateToggle({
		Name = 'Visualizer',
		Function = function()
			if FPSBoost.Enabled then
				FPSBoost:Toggle()
				FPSBoost:Toggle()
			end
		end,
		Default = true
	})
end)
	
run(function()
	local HitColor
	local Color
	local done = {}
	
	HitColor = vape.Legit:CreateModule({
		Name = 'Hit Color',
		Function = function(callback)
			if callback then 
				repeat
					for i, v in entitylib.List do 
						local highlight = v.Character and v.Character:FindFirstChild('_DamageHighlight_')
						if highlight then 
							if not table.find(done, highlight) then 
								table.insert(done, highlight) 
							end
							highlight.FillColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
							highlight.FillTransparency = Color.Opacity
						end
					end
					task.wait(0.1)
				until not HitColor.Enabled
			else
				for i, v in done do 
					v.FillColor = Color3.new(1, 0, 0)
					v.FillTransparency = 0.4
				end
				table.clear(done)
			end
		end,
		Tooltip = 'Customize the hit highlight options'
	})
	Color = HitColor:CreateColorSlider({
		Name = 'Color',
		DefaultOpacity = 0.4
	})
end)
	
run(function()
	vape.Legit:CreateModule({
		Name = 'HitFix',
		Function = function(callback)
			debug.setconstant(bedwars.SwordController.swingSwordAtMouse, 23, callback and 'raycast' or 'Raycast')
			debug.setupvalue(bedwars.SwordController.swingSwordAtMouse, 4, callback and bedwars.QueryUtil or workspace)
		end,
		Tooltip = 'Changes the raycast function to the correct one'
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
	
	SongBeats = vape.Legit:CreateModule({
		Name = 'Song Beats',
		Function = function(callback)
			if callback then
				songobj = Instance.new('Sound')
				songobj.Volume = Volume.Value / 100
				songobj.Parent = workspace
				repeat
					if not songobj.Playing then choosesong() end
					if beattick < tick() and SongBeats.Enabled and FOV.Enabled then
						beattick = tick() + songbpm
						oldfov = math.min(bedwars.FovController:getFOV() * (bedwars.SprintController.sprinting and 1.1 or 1), 120)
						gameCamera.FieldOfView = oldfov - FOVValue.Value
						songtween = tweenService:Create(gameCamera, TweenInfo.new(math.min(songbpm, 0.2), Enum.EasingStyle.Linear), {FieldOfView = oldfov})
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
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
end)
	

	
run(function()
	local UICleanup
	local OpenInv
	local KillFeed
	local OldTabList
	local HotbarApp = getRoactRender(require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-app']).HotbarApp.render)
	local HotbarOpenInventory = require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-open-inventory']).HotbarOpenInventory
	local old, new = {}, {}
	local oldkillfeed
	
	vape:Clean(function()
		for _, v in new do
			table.clear(v)
		end
		for _, v in old do
			table.clear(v)
		end
		table.clear(new)
		table.clear(old)
	end)
	
	local function modifyconstant(func, ind, val)
		if not old[func] then old[func] = {} end
		if not new[func] then new[func] = {} end
		if not old[func][ind] then
			local typing = type(old[func][ind])
			if typing == 'function' or typing == 'userdata' then return end
			old[func][ind] = debug.getconstant(func, ind)
		end
		if typeof(old[func][ind]) ~= typeof(val) and val ~= nil then return end
	
		new[func][ind] = val
		if UICleanup.Enabled then
			if val then
				debug.setconstant(func, ind, val)
			else
				debug.setconstant(func, ind, old[func][ind])
				old[func][ind] = nil
			end
		end
	end
	
	UICleanup = vape.Legit:CreateModule({
		Name = 'UI Cleanup',
		Function = function(callback)
			for i, v in (callback and new or old) do
				for i2, v2 in v do
					debug.setconstant(i, i2, v2)
				end
			end
			if callback then
				if OpenInv.Enabled then
					oldinvrender = HotbarOpenInventory.render
					HotbarOpenInventory.render = function()
						return bedwars.Roact.createElement('TextButton', {Visible = false}, {})
					end
				end
	
				if KillFeed.Enabled then
					oldkillfeed = bedwars.KillFeedController.addToKillFeed
					bedwars.KillFeedController.addToKillFeed = function() end
				end
	
				if OldTabList.Enabled then
					starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
				end
			else
				if oldinvrender then
					HotbarOpenInventory.render = oldinvrender
					oldinvrender = nil
				end
	
				if KillFeed.Enabled then
					bedwars.KillFeedController.addToKillFeed = oldkillfeed
					oldkillfeed = nil
				end
	
				if OldTabList.Enabled then
					starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
				end
			end
		end,
		Tooltip = 'Cleans up the UI for kits & main'
	})
	UICleanup:CreateToggle({
		Name = 'Resize Health',
		Function = function(callback)
			modifyconstant(HotbarApp, 60, callback and 1 or nil)
			modifyconstant(debug.getupvalue(HotbarApp, 15).render, 30, callback and 1 or nil)
			modifyconstant(debug.getupvalue(HotbarApp, 23).tweenPosition, 16, callback and 0 or nil)
		end,
		Default = true
	})
	UICleanup:CreateToggle({
		Name = 'No Hotbar Numbers',
		Function = function(callback)
			local func = oldinvrender or HotbarOpenInventory.render
			modifyconstant(debug.getupvalue(HotbarApp, 23).render, 90, callback and 0 or nil)
			modifyconstant(func, 71, callback and 0 or nil)
		end,
		Default = true
	})
	OpenInv = UICleanup:CreateToggle({
		Name = 'No Inventory Button',
		Function = function(callback)
			modifyconstant(HotbarApp, 78, callback and 0 or nil)
			if UICleanup.Enabled then
				if callback then
					oldinvrender = HotbarOpenInventory.render
					HotbarOpenInventory.render = function()
						return bedwars.Roact.createElement('TextButton', {Visible = false}, {})
					end
				else
					HotbarOpenInventory.render = oldinvrender
					oldinvrender = nil
				end
			end
		end,
		Default = true
	})
	KillFeed = UICleanup:CreateToggle({
		Name = 'No Kill Feed',
		Function = function(callback)
			if UICleanup.Enabled then
				if callback then
					oldkillfeed = bedwars.KillFeedController.addToKillFeed
					bedwars.KillFeedController.addToKillFeed = function() end
				else
					bedwars.KillFeedController.addToKillFeed = oldkillfeed
					oldkillfeed = nil
				end
			end
		end,
		Default = true
	})
	OldTabList = UICleanup:CreateToggle({
		Name = 'Old Player List',
		Function = function(callback)
			if UICleanup.Enabled then
				starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, callback)
			end
		end,
		Default = true
	})
	UICleanup:CreateToggle({
		Name = 'Fix Queue Card',
		Function = function(callback)
			modifyconstant(bedwars.QueueCard.render, 15, callback and 0.1 or nil)
		end,
		Default = true
	})
end)


-- OSVPrivate


run(function()
	local LagbackNotifier
	
	LagbackNotifier = vape.Categories.Utility:CreateModule({
        Name = 'LagbackNotifier',
        Function = function(enabled)
            if enabled then
                local lastnetowner = true
                LagbackNotifier:Clean(lplr:GetAttributeChangedSignal('LastTeleported'):Connect(function()
                    vape:CreateNotification('LagbackNotifier', 'Teleport detected', 3)
                end))
                LagbackNotifier:Clean(runService.Heartbeat:Connect(function()
                    local char = lplr.Character
                    local hrp = char and char:FindFirstChild('HumanoidRootPart')

                    if hrp then
                        if lastnetowner ~= isnetworkowner(hrp) then
                            lastnetowner = isnetworkowner(hrp)
                            if not lastnetowner then
                                vape:CreateNotification('LagbackNotifier', 'Lagback detected', 3)
                            end
                        end
                    end
                end))
            end
        end
    })
end)



run(function()
	local EmoteSpammer
    local Emote

    EmoteSpammer = vape.Categories.Utility:CreateModule({
        Name = 'EmoteSpammer',
        Tooltip = '',
        Function = function(enabled)
            if enabled then
                repeat
                    for _, v in Emote.ListEnabled do
                        RemotesInstance.Emote:InvokeServer({
                            emoteType = v
                        })
                    end

                    task.wait()
                until not EmoteSpammer.Enabled
            end
        end
    })

    Emote = EmoteSpammer:CreateTextList({
        Name = 'Emote',
        Placeholder = 'bed_break',
        Tooltip = ''
    })
end)
run(function()
	local Disabler
	
	local function characterAdded(char)
		for _, v in getconnections(char.RootPart:GetPropertyChangedSignal('CFrame')) do
			hookfunction(v.Function, function() end)
		end
		for _, v in getconnections(char.RootPart:GetPropertyChangedSignal('Velocity')) do
			hookfunction(v.Function, function() end)
		end
	end
	
	Disabler = vape.Categories.Combat:CreateModule({
		Name = 'Disabler',
		Function = function(callback)
			if callback then
				Disabler:Clean(entitylib.Events.LocalAdded:Connect(characterAdded))
				if entitylib.isAlive then
					characterAdded(entitylib.character)
				end
			end
		end,
		Tooltip = 'Disables GetPropertyChangedSignal detections for movement'
	})
end)
run(function()
    local ZoomUnlocker
    ZoomUnlocker = vape.Categories.Utility:CreateModule({
        Name = "Zoom Unlocker",
        Function = function(callback)
	    	if callback then
            	lplr.CameraMaxZoomDistance = callback and math.huge or 128
			end
        end,
        Tooltip = "Makes it so you can zoom infinitely"
    })
end)
run(function()
	local DamageIndicator = {}
	local DamageIndicatorColorToggle = {}
	local DamageIndicatorColor = {Hue = 0, Sat = 0, Value = 0}
	local DamageIndicatorTextToggle = {}
	local DamageIndicatorText = {ListEnabled = {}}
	local DamageIndicatorFontToggle = {}
	local DamageIndicatorFont = {Value = 'GothamBlack'}
	local DamageIndicatorTextObjects = {}
    local DamageIndicatorMode1
    local DamageMessages = {
		'OSVPrivate!',
		'Pop!',
		'Hit!',
		'Smack!',
		'Bang!',
		'Boom!',
		'Whoop!',
		'Damage!',
		'Meow!',
		'Whack!',
		'Crash!',
		'Slam!',
		'Zap!',
		'Snap!',
		'Thump!'
	}
	local RGBColors = {
		Color3.fromRGB(255, 0, 0),
		Color3.fromRGB(255, 127, 0),
		Color3.fromRGB(255, 255, 0),
		Color3.fromRGB(0, 255, 0),
		Color3.fromRGB(0, 0, 255),
		Color3.fromRGB(75, 0, 130),
		Color3.fromRGB(148, 0, 211)
	}
	local orgI, mz, vz = 1, 5, 10
    local DamageIndicatorMode = {Value = 'Rainbow'}
	local DamageIndicatorMode2 = {Value = 'Gradient'}
	DamageIndicator = vape.Categories.Render:CreateModule({
        PerformanceModeBlacklisted = true,
		Name = 'DamageIndicator',
		Function = function(calling)
			if calling then
				task.spawn(function()
					table.insert(DamageIndicator.Connections, workspace.DescendantAdded:Connect(function(v)
						pcall(function()
                            if v.Name ~= 'DamageIndicatorPart' then return end
							local indicatorobj = v:FindFirstChildWhichIsA('BillboardGui'):FindFirstChildWhichIsA('Frame'):FindFirstChildWhichIsA('TextLabel')
							if indicatorobj then
                                if DamageIndicatorColorToggle.Enabled then
                                    -- indicatorobj.TextColor3 = Color3.fromHSV(DamageIndicatorColor.Hue, DamageIndicatorColor.Sat, DamageIndicatorColor.Value)
                                    if DamageIndicatorMode.Value == 'Rainbow' then
                                        if DamageIndicatorMode2.Value == 'Gradient' then
                                            indicatorobj.TextColor3 = Color3.fromHSV(tick() % mz / mz, orgI, orgI)
                                        else
                                            runService.Stepped:Connect(function()
                                                orgI = (orgI % #RGBColors) + 1
                                                indicatorobj.TextColor3 = RGBColors[orgI]
                                            end)
                                        end
                                    elseif DamageIndicatorMode.Value == 'Custom' then
                                        indicatorobj.TextColor3 = Color3.fromHSV(
                                            DamageIndicatorColor.Hue, 
                                            DamageIndicatorColor.Sat, 
                                            DamageIndicatorColor.Value
                                        )
                                    else
                                        indicatorobj.TextColor3 = Color3.fromRGB(127, 0, 255)
                                    end
                                end
                                if DamageIndicatorTextToggle.Enabled then
                                    if DamageIndicatorMode1.Value == 'Custom' then
                                        print(getrandomvalue(DamageIndicatorText.ListEnabled))
                                        local o = getrandomvalue(DamageIndicatorText.ListEnabled)
                                        indicatorobj.Text = o ~= '' and o or indicatorobj.Text
									elseif DamageIndicatorMode1.Value == 'Multiple' then
										indicatorobj.Text = DamageMessages[math.random(orgI, #DamageMessages)]
									else
										indicatorobj.Text = 'Render Intents on top!'
									end
								end
								indicatorobj.Font = DamageIndicatorFontToggle.Enabled and Enum.Font[DamageIndicatorFont.Value] or indicatorobject.Font
							end
						end)
					end))
				end)
			end
		end
	})
    DamageIndicatorMode = DamageIndicator:CreateDropdown({
		Name = 'Color Mode',
		List = {
			'Rainbow',
			'Custom',
			'Lunar'
		},
		HoverText = 'Mode to color the Damage Indicator',
		Value = 'Rainbow',
		Function = function() end
	})
	DamageIndicatorMode2 = DamageIndicator:CreateDropdown({
		Name = 'Rainbow Mode',
		List = {
			'Gradient',
			'Paint'
		},
		HoverText = 'Mode to color the Damage Indicator\nwith Rainbow Color Mode',
		Value = 'Gradient',
		Function = function() end
	})
    DamageIndicatorMode1 = DamageIndicator:CreateDropdown({
		Name = 'Text Mode',
		List = {
            'Custom',
			'Multiple',
			'Lunar'
		},
		HoverText = 'Mode to change the Damage Indicator Text',
		Value = 'Custom',
		Function = function() end
	})
	DamageIndicatorColorToggle = DamageIndicator:CreateToggle({
		Name = 'Custom Color',
		Function = function(calling) pcall(function() DamageIndicatorColor.Object.Visible = calling end) end
	})
	DamageIndicatorColor = DamageIndicator:CreateColorSlider({
		Name = 'Text Color',
		Function = function() end
	})
	DamageIndicatorTextToggle = DamageIndicator:CreateToggle({
		Name = 'Custom Text',
		HoverText = 'random messages for the indicator',
		Function = function(calling) pcall(function() DamageIndicatorText.Object.Visible = calling end) end
	})
	DamageIndicatorText = DamageIndicator:CreateTextList({
		Name = 'Text',
		TempText = 'Indicator Text',
		AddFunction = function() end
	})
	DamageIndicatorColor.Object.Visible = DamageIndicatorColorToggle.Enabled
	DamageIndicatorText.Object.Visible = DamageIndicatorTextToggle.Enabled
end)
run(function()
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    Headless = vape.Categories.Utility:CreateModule({
        Name = "Headless",
        Function = function(enabled)
            if enabled then
                local function applyHeadlessToCharacter(character)
                    local humanoid = character:FindFirstChildOfClass("Humanoid")
                    if humanoid and humanoid.RigType == Enum.HumanoidRigType.R15 then
                        local head = character:FindFirstChild("Head")
                        if head then
                            head.Transparency = 1
                            local face = head:FindFirstChildWhichIsA("Decal")
                            if face then
                                face.Transparency = 1
                            end
                        end
                    end
                end

                local currentChar = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                applyHeadlessToCharacter(currentChar)

                Headless:Clean(LocalPlayer.CharacterAdded:Connect(function(char)
                    if Headless.Enabled then
                        task.wait(0.5)
                        applyHeadlessToCharacter(char)
                    end
                end))
            else
                local char = LocalPlayer.Character
                if char then
                    local head = char:FindFirstChild("Head")
                    if head then
                        head.Transparency = 0
                        local face = head:FindFirstChildWhichIsA("Decal")
                        if face then
                            face.Transparency = 0
                        end
                    end
                end
            end
        end,
        Default = false,
        Tooltip = "yurrr"
    })
end)									
run(function()
    local runService = game:GetService("RunService")
    local players = game:GetService("Players")
    local lplr = players.LocalPlayer

    local NoNameTag = vape.Categories.Utility:CreateModule({
        Name = 'Name Hider',
        Function = function(callback)
            if callback then
                NoNameTag:Clean(runService.RenderStepped:Connect(function()
                    pcall(function()
                        if lplr.Character and lplr.Character:FindFirstChild("Head") and lplr.Character.Head:FindFirstChild("Nametag") then
                            lplr.Character.Head.Nametag:Destroy()
                        end
                    end)
                end))
            end
        end,
        Tooltip = "Client Sided",
        Default = false
    })
end)

run(function() 
	local TPExploit = {}
	TPExploit = vape.Categories.Utility:CreateModule({
		Name = "EmptyGameTP",
		Function = function(calling)
			if calling then 
				TPExploit:Toggle()
				local TeleportService = game:GetService("TeleportService")
				local e2 = TeleportService:GetLocalPlayerTeleportData()
				game:GetService("TeleportService"):Teleport(game.PlaceId, game.Players.LocalPlayer, e2)
			end
		end,
		WhitelistRequired = 1
	}) 
end)
if not shared.CheatEngineMode then
	run(function()
		local AntiLagback = {Enabled = false}
		local control_module = require(lplr:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")).controls
		local old = control_module.moveFunction
		local clone
		local connection
		local function clone_lplr_char()
			if not (lplr.Character ~= nil and lplr.Character.PrimaryPart ~= nil) then return nil end
			lplr.Character.Archivable = true
		
			local clone = lplr.Character:Clone()
		
			clone.Parent = game.Workspace
			clone.Name = "Clone"
		
			clone.PrimaryPart.CFrame = lplr.Character.PrimaryPart.CFrame
		
			gameCamera.CameraSubject = clone.Humanoid	
		
			task.spawn(function()
				for i, v in next, clone:FindFirstChild("Head"):GetDescendants() do
					v:Destroy()
				end
				for i, v in next, clone:GetChildren() do
					if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
						v.Transparency = 1
					end
					if v:IsA("Accessory") then
						v:FindFirstChild("Handle").Transparency = 1
					end
				end
			end)
			return clone
		end
		local function bypass()
			clone = clone_lplr_char()
			if not entitylib.isAlive then return AntiLagback:Toggle() end
			if not clone then return AntiLagback:Toggle() end
			control_module.moveFunction = function(self, vec, ...)
				local RaycastParameters = RaycastParams.new()
	
				RaycastParameters.FilterType = Enum.RaycastFilterType.Include
				RaycastParameters.FilterDescendantsInstances = {CollectionService:GetTagged("block")}
	
				local LookVector = Vector3.new(gameCamera.CFrame.LookVector.X, 0, gameCamera.CFrame.LookVector.Z).Unit
	
				if clone.PrimaryPart then
					local Raycast = game.Workspace:Raycast((clone.PrimaryPart.Position + LookVector), Vector3.new(0, -1000, 0), RaycastParameters)
					local Raycast2 = game.Workspace:Raycast(((clone.PrimaryPart.Position - Vector3.new(0, 15, 0)) + (LookVector * 3)), Vector3.new(0, -1000, 0), RaycastParameters)
	
					if Raycast or Raycast2 then
						clone.PrimaryPart.CFrame = CFrame.new(clone.PrimaryPart.Position + (LookVector / (GetSpeed())))
						vec = LookVector
					end
	
					if (not clone) and entitylib.isAlive then
						control_module.moveFunction = OldMoveFunction
						gameCamera.CameraSubject = lplr.Character.Humanoid
					end
				end
	
				return old(self, vec, ...)
			end
		end
		local function safe_revert()
			control_module.moveFunction = old
			if entitylib.isAlive then
				gameCamera.CameraSubject = lplr.Character:WaitForChild("Humanoid")
			end
						pcall(function()
				clone:Destroy()
			end)
		end
		AntiLagback = vape.Categories.Blatant:CreateModule({
			Name = "AntiLagback",
			Function = function(call)
				if call then
					connection = lplr:GetAttributeChangedSignal("LastTeleported"):Connect(function()
						if entitylib.isAlive and store.matchState ~= 0 and not lplr.Character:FindFirstChildWhichIsA("ForceField") and (not vape.Modules.BedTP.Enabled) and (not vape.Modules.PlayerTP.Enabled) then					
							bypass()
							task.wait(4.5)
							safe_revert()
						end 
					end)
				else
					pcall(function() connection:Disconnect() end)
					control_module.moveFunction = old
					if entitylib.isAlive then
						gameCamera.CameraSubject = lplr.Character:WaitForChild("Humanoid")
					end
					pcall(function() clone:Destroy() end)
				end
			end
		})
	end)
end

run(function()
    local ClientCrasher
	local collectionService = game:GetService("CollectionService")
	local entitylib = entitylib or entityLibrary
	local signal
    ClientCrasher = vape.Categories.Blatant:CreateModule({
        Name = "Swap Spammer",
        Function = function(call)
            if call then
                signal = collectionService:GetInstanceAddedSignal('inventory-entity'):Connect(function(player)
                    local item = player:WaitForChild('HandInvItem')
                    for i,v in getconnections(item.Changed) do
						pcall(function()
                        	v:Disable()
						end)
                    end                
                end)

                repeat
                    if entitylib.isAlive then
                        for _, tool in store.inventory.inventory.items do
							task.spawn(switchItem, tool.tool)
						end
                    end
                    task.wait()
                until not ClientCrasher.Enabled
            else
				if signal then
					pcall(function() signal:Disconnect() end)
					signal = nil
				end
			end
        end
    })
end)

run(function()
    local AntiHit = {}
    local physEngine = game:GetService("RunService")
    local worldSpace = game.Workspace
    local camView = worldSpace.CurrentCamera
    local plyr = lplr
    local entSys = entitylib
    local queryutil = {}
    function queryutil:setQueryIgnored(part, index)
        if index == nil then index = true end
        if part then part:SetAttribute("gamecore_GameQueryIgnore", index) end
    end
    local utilPack = {QueryUtil = queryutil}

    local dupeNode, altHeight
    shared.anchorBase = nil
    shared.evadeFlag = false

    local trigSet = {p = true, n = false, w = false}
    local shiftMode = "Up"
    local scanRad = 30

    local function genTwin()
        if entSys.isAlive and entSys.character.Humanoid.Health > 0 and entSys.character.HumanoidRootPart then
            altHeight = entSys.character.Humanoid.HipHeight
            shared.anchorBase = entSys.character.HumanoidRootPart
            utilPack.QueryUtil:setQueryIgnored(shared.anchorBase, true)
            if not plyr.Character or not plyr.Character.Parent then return false end

            plyr.Character.Parent = game
            dupeNode = shared.anchorBase:Clone()
            dupeNode.Parent = plyr.Character
            shared.anchorBase.Parent = camView
            dupeNode.CFrame = shared.anchorBase.CFrame

            plyr.Character.PrimaryPart = dupeNode
            entSys.character.HumanoidRootPart = dupeNode
            entSys.character.RootPart = dupeNode
            plyr.Character.Parent = worldSpace

            for _, x in plyr.Character:GetDescendants() do
                if x:IsA('Weld') or x:IsA('Motor6D') then
                    if x.Part0 == shared.anchorBase then x.Part0 = dupeNode end
                    if x.Part1 == shared.anchorBase then x.Part1 = dupeNode end
                end
            end
            return true
        end
        return false
    end

    local function resetCore()
        if not entSys.isAlive or not shared.anchorBase or not shared.anchorBase:IsDescendantOf(game) then
            shared.anchorBase = nil
            dupeNode = nil
            return false
        end

        if not plyr.Character or not plyr.Character.Parent then return false end

        plyr.Character.Parent = game

        shared.anchorBase.Parent = plyr.Character
        shared.anchorBase.CanCollide = true
        shared.anchorBase.Velocity = Vector3.zero 
        shared.anchorBase.Anchored = false 

        plyr.Character.PrimaryPart = shared.anchorBase
        entSys.character.HumanoidRootPart = shared.anchorBase
        entSys.character.RootPart = shared.anchorBase

        for _, x in plyr.Character:GetDescendants() do
            if x:IsA('Weld') or x:IsA('Motor6D') then
                if x.Part0 == dupeNode then x.Part0 = shared.anchorBase end
                if x.Part1 == dupeNode then x.Part1 = shared.anchorBase end
            end
        end

        local prevLoc = dupeNode and dupeNode.CFrame or shared.anchorBase.CFrame
        if dupeNode then
            dupeNode:Destroy()
            dupeNode = nil
        end

        plyr.Character.Parent = worldSpace
        shared.anchorBase.CFrame = prevLoc

        if entSys.character.Humanoid then
            entSys.character.Humanoid.HipHeight = altHeight or 2
        end

        shared.anchorBase = nil
        shared.evadeFlag = false
        altHeight = nil

        return true
    end

    local function isEnemy(plr)
        return plr and plr.Team ~= lplr.Team
    end

    local function shiftPos()
        if not AntiHit.on or not VeloAntiHit.Enabled then return end
        local hits = entSys.AllPosition({
            Range = scanRad,
            Wallcheck = trigSet.w or nil,
            Part = 'RootPart',
            Players = trigSet.p,
            NPCs = trigSet.n,
            Limit = 5
        })

        for _, target in ipairs(hits) do
            if target and target.Player and isEnemy(target.Player) and not shared.evadeFlag then
                local base = entSys.character.RootPart
                if base then
                    shared.evadeFlag = true
                    local targetY = shiftMode == "Up" and -100 or 0
                    shared.anchorBase.CFrame = CFrame.new(base.CFrame.X, targetY, base.CFrame.Z)
                    task.wait(0.15)
                    shared.anchorBase.CFrame = base.CFrame
                    task.wait(0.05)
                    shared.evadeFlag = false
                end
                break
            end
        end
    end

    function AntiHit:engage()
        if self.on then return end
        self.on = true

        if not genTwin() then
            self:disengage()
            return
        end

        self.physHook = physEngine.PreSimulation:Connect(function()
            if not VeloAntiHit.Enabled then return end
            if entSys.isAlive and shared.anchorBase and entSys.character.RootPart then
                local currBase = entSys.character.RootPart
                local currPos = currBase.CFrame

                if not isnetworkowner(shared.anchorBase) then
                    currBase.CFrame = shared.anchorBase.CFrame
                    currBase.Velocity = shared.anchorBase.Velocity
                    return
                end
                if not shared.evadeFlag then
                    shared.anchorBase.CFrame = currPos
                end
                shared.anchorBase.Velocity = Vector3.zero
                shared.anchorBase.CanCollide = false
                shiftPos()
            else
                self:disengage()
            end
        end)

        self.respawnHook = entSys.Events.LocalAdded:Connect(function()
            if VeloAntiHit.Enabled then
                self:disengage()
                task.wait(0.1)
                self:engage()
            end
        end)
    end

    function AntiHit:disengage()
        self.on = false
        pcall(resetCore)
        if self.physHook then self.physHook:Disconnect() self.physHook = nil end
        if self.respawnHook then self.respawnHook:Disconnect() self.respawnHook = nil end
    end

    VeloAntiHit = vape.Categories.Blatant:CreateModule({
        Name = "Anti hit real",
        Function = function(enabled)
            if enabled then
                AntiHit:engage()
            else
                AntiHit:disengage()
            end
        end,
        Tooltip = "Dodges attacks"
    })

    VeloAntiHit:CreateTargets({
        Players = true,
        NPCs = false
    })
    VeloAntiHit:CreateDropdown({
        Name = "Shift Type",
        List = {"Up", "Down"},
        Value = "Up",
        Function = function(opt) shiftMode = opt end
    })
    VeloAntiHit:CreateSlider({
        Name = "Scan Perimeter",
        Min = 1,
        Max = 30,
        Default = 30,
        Suffix = function(v) return v == 1 and "span" or "spans" end,
        Function = function(v) scanRad = v end
    })
end)
run(function()
    local AutoBuyWool
    local shopId

    local function getShopNPC()
        local shop, newid = nil, nil
        if entitylib.isAlive then
            local localPosition = entitylib.character.RootPart.Position
            for _, v in store.shop do
                if (v.RootPart.Position - localPosition).Magnitude <= 10 then
                    shop = v.Shop
                    newid = v.Id
                end
            end
        end
        return shop, newid
    end

    local function buyWool()
        local woolItem = bedwars.Shop.getShopItem('wool_white', lplr)
        if woolItem and woolItem.currency == 'iron' then
            local iron = getItem('iron')
            if iron and iron.amount >= woolItem.price then
                bedwars.Client:Get('BedwarsPurchaseItem'):CallServerAsync({
                    shopItem = woolItem,
                    shopId = shopId
                })
            end
        end
    end

    AutoBuyWool = vape.Categories.World:CreateModule({
        Name = 'AutoBuyWool',
        Tooltip = 'Buys White Wool instantly when you have ≥8 iron near shop',
        Function = function(callback)
            if callback then
                task.spawn(function()
                    repeat
                        local iron = getItem('iron')
                        local shop, newid = getShopNPC()
                        if iron and iron.amount >= 8 and shop then
                            shopId = newid
                            buyWool()
                        end
                        task.wait(0.001) -- fast polling
                    until not AutoBuyWool.Enabled
                end)
            end
        end
    })
end)
run(function()
    local JadeExploit = {Enabled = false}
    JadeExploit = vape.Categories.Blatant:CreateModule({
        Name = "Jade Disabler",
        Function = function(call)
            if call then
                task.spawn(function()
                    while JadeExploit.Enabled do
                        game:GetService("ReplicatedStorage"):WaitForChild("events-@easy-games/game-core:shared/game-core-networking@getEvents.Events"):WaitForChild("useAbility"):FireServer("jade_hammer_jump")
                        task.wait(0.1)
                        game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("JadeHammerSlam"):FireServer({slamIndex = 0})
                    end
                end)
            end
        end
    })
end)
run(function()
    local KillAuraV2 = vape.Categories.Blatant:CreateModule({
        Name = "KillauraV2",
        Tooltip = "Customizable CPS kill aura with spoof validation",
        ExtraText = function() return "V2" end,
        Function = function(enabled)
            if not enabled then return end

            local AttackRemote = bedwars.Client:Get(remotes.AttackEntity).instance
            local lastSwingTime = 0

            bedwars.SwordController.isClickingTooFast = function(self)
                self.lastSwing = os.clock()
                return false
            end

            KillAuraV2:Clean(runService.Heartbeat:Connect(function()
                if not entitylib.isAlive then return end
                local sword = store.hand
                if not sword or sword.toolType ~= "sword" or not sword.tool then return end

                local cpsDelay = 1 / (KillAuraCPS.Value > 0 and KillAuraCPS.Value or 1)
                local now = tick()
                if now - lastSwingTime < cpsDelay then return end
                lastSwingTime = now

                local targets = entitylib.AllPosition({
                    Range = 18,
                    Sort = sortmethods.Damage,
                    Part = "RootPart",
                    Wallcheck = true,
                    Players = true,
                    NPCs = false,
                    Limit = 10
                })

                for _, v in targets do
                    local root = v.Character and v.Character.PrimaryPart
                    if not root then continue end

                    local selfPos = entitylib.character.RootPart.Position
                    local targetPos = root.Position
                    local dir = CFrame.lookAt(selfPos, targetPos).LookVector
                    local spoofPos = selfPos + dir * math.max((targetPos - selfPos).Magnitude - 14.399, 0)

                    AttackRemote:FireServer({
                        weapon = sword.tool,
                        chargedAttack = { chargeRatio = 0 },
                        lastSwingServerTimeDelta = 0,
                        entityInstance = v.Character,
                        validate = {
                            raycast = {
                                cameraPosition = { value = spoofPos },
                                cursorDirection = { value = dir }
                            },
                            targetPosition = { value = targetPos },
                            selfPosition = { value = spoofPos }
                        }
                    })
                end
            end))
        end
    })

    KillAuraCPS = KillAuraV2:CreateSlider({
        Name = "CPS",
        Min = 1,
        Max = 1000000000,
        Default = 100,
        Suffix = "cps",
        Tooltip = "Set your preferred click rate"
    })
end)

run(function()
    local pack1
	local packassetids = {
		['OSVPrivate'] = 'rbxassetid://13780890894',
		['Shad'] = 'rbxassetid://13988978091',
		['Minecraft Swords'] = 'rbxassetid://14427750969',
	}
    local TexturePacks 
	TexturePacks = vape.Categories.Render:CreateModule({
        Name = 'Tool Textures',
        Tooltip = 'Self Explanitory',
        Function = function(call)
            if call then
				local import = game:GetObjects(packassetids[pack1.Value])[1]
				import.Parent = replicatedStorage
				local index = {
					{
						name = "wood_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-89),math.rad(-90)),
						model = import:WaitForChild("Wood_Sword"),
					},
					{
						name = "stone_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-89),math.rad(-90)),
						model = import:WaitForChild("Stone_Sword"),
					},
					{
						name = "iron_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-89),math.rad(-90)),
						model = import:WaitForChild("Iron_Sword"),
					},
					{
						name = "diamond_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-89),math.rad(-90)),
						model = import:WaitForChild("Diamond_Sword"),
					},
					{
						name = "emerald_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-89),math.rad(-90)),
						model = import:WaitForChild("Emerald_Sword"),
					},
				}
				for i,v in {'Wood', 'Diamond', 'Emerald', 'Stone', 'Iron', 'Gold'} do
					if import:FindFirstChild(`{v}_Pickaxe`) then
						table.insert(index, {
							name = `{v:lower()}_pickaxe`,
							offset = CFrame.Angles(math.rad(0), math.rad(-180), math.rad(-95)),
							model = import[`{v}_Pickaxe`],
						})
					end
					if import:FindFirstChild(v) then
						table.insert(index, {
							name = `{v:lower()}`,
							offset = CFrame.Angles(math.rad(0),math.rad(-90),math.rad(table.find({'Emerald', 'Diamond'}, v) and 90 or -90)),
							model = import[`{v}`],
						})
					end
				end
				TexturePacks:Clean(workspace.Camera.Viewmodel.ChildAdded:Connect(function(tool)
					if(not tool:IsA("Accessory")) then return end
					for i,v in pairs(index) do
						if(v.name == tool.Name) then
							for i,v in pairs(tool:GetDescendants()) do
								if(v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation")) then
									v.Transparency = 1
								end
							end
							local model = v.model:Clone()
							model.CFrame = tool:WaitForChild("Handle").CFrame * v.offset
							model.CFrame *= CFrame.Angles(math.rad(0),math.rad(-50),math.rad(0))
							model.Parent = tool
							local weld = Instance.new("WeldConstraint",model)
							weld.Part0 = model
							weld.Part1 = tool:WaitForChild("Handle")
							local tool2 = lplr.Character:WaitForChild(tool.Name)
							for i,v in pairs(tool2:GetDescendants()) do
								if(v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation")) then
									v.Transparency = 1
								end            
							end            
							local model2 = v.model:Clone()
							model2.Anchored = false
							model2.CFrame = tool2:WaitForChild("Handle").CFrame * v.offset
							model2.CFrame *= CFrame.Angles(math.rad(0),math.rad(-50),math.rad(0))
							model2.CFrame *= CFrame.new(0.6,0,-.9)
							model2.Parent = tool2
							local weld2 = Instance.new("WeldConstraint",model)
							weld2.Part0 = model2
							weld2.Part1 = tool2:WaitForChild("Handle")
						end
					end
				end))
            end
        end
    })
	local list = {}
	for i,v in packassetids do
		table.insert(list, i)
	end
    pack1 = TexturePacks:CreateDropdown({
        Name = 'Pack',
        List = list,
		Function = function()
			if TexturePacks.Enabled then
				TexturePacks:Toggle()
				TexturePacks:Toggle()
			end
		end
    })
end)
run(function()
	local ZephyrExploit
	local zepcontroller = require(lplr.PlayerScripts.TS.controllers.games.bedwars.kit.kits['wind-walker']['wind-walker-controller'])
	local old, old2
	ZephyrExploit = vape.Categories.Exploits:CreateModule({
		Name = 'ZephyrExploit',
		Function = function(callback)
			if callback then
				old = zepcontroller.updateSpeed
				old2 = zepcontroller.updateJump
				zepcontroller.updateSpeed = function(v1,v2) 
					v1 = {currentSpeedModifier = nil}
					v2 = 5
					return old(v1,v2)
				end
				zepcontroller.updateJump = function(v1,v2) 
					v1 = {doubleJumpActive = nil}
					v2 = 5
					return old2(v1,v2)
				end
			else
				zepcontroller.updateSpeed = old
				zepcontroller.updateJump = old2
				old = nil
				old2 = nil
			end
		end,
		Tooltip = 'Anti-Cheat Bypasser!'
	})

end)
