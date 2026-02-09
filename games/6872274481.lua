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

local isnetworkowner = identifyexecutor and table.find({'AWP', 'Nihon'}, ({identifyexecutor()})[1]) and isnetworkowner or function()
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
	blur.Image = getcustomasset('newvape/assets/new/blur.png')
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
	for slot, item in (inv or store.inventory.inventory.items) do
		if item.itemType == itemName then
			return item, slot
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
		BedBreakEffectMeta = require(replicatedStorage.TS.locker["bed-break-effect"]["bed-break-effect-meta"]).BedBreakEffectMeta,
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
		EquipItem = debug.getproto(require(replicatedStorage.TS.entity.entities['inventory-entity']).InventoryEntity.equipItem, 3),
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
		Min = 1,
		Max = 20,
		Default = 6
	})
	Distance = AimAssist:CreateSlider({
		Name = 'Distance',
		Min = 1,
		Max = 30,
		Default = 30,
		Suffx = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AngleSlider = AimAssist:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 70
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
		Min = 1,
		Max = 9,
		DefaultMin = 7,
		DefaultMax = 7
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
		Max = 12,
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
		Max = 18,
		Default = 18,
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
	local TriggerBot
	local CPS
	local rayParams = RaycastParams.new()
	
	TriggerBot = vape.Categories.Combat:CreateModule({
		Name = 'TriggerBot',
		Function = function(callback)
			if callback then
				repeat
					local doAttack
					if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
						if entitylib.isAlive and store.hand.toolType == 'sword' and bedwars.DaoController.chargingMaid == nil then
							local attackRange = bedwars.ItemMeta[store.hand.tool.Name].sword.attackRange
							rayParams.FilterDescendantsInstances = {lplr.Character}
	
							local unit = lplr:GetMouse().UnitRay
							local localPos = entitylib.character.RootPart.Position
							local rayRange = (attackRange or 14.4)
							local ray = bedwars.QueryUtil:raycast(unit.Origin, unit.Direction * 200, rayParams)
							if ray and (localPos - ray.Instance.Position).Magnitude <= rayRange then
								local limit = (attackRange)
								for _, ent in entitylib.List do
									doAttack = ent.Targetable and ray.Instance:IsDescendantOf(ent.Character) and (localPos - ent.RootPart.Position).Magnitude <= rayRange
									if doAttack then
										break
									end
								end
							end
	
							doAttack = doAttack or bedwars.SwordController:getTargetInRegion(attackRange or 3.8 * 3, 0)
							if doAttack then
								bedwars.SwordController:swingSwordAtMouse()
							end
						end
					end
	
					task.wait(doAttack and 1 / CPS.GetRandomValue() or 0.016)
				until not TriggerBot.Enabled
			end
		end,
		Tooltip = 'Automatically swings when hovering over a entity'
	})
	CPS = TriggerBot:CreateTwoSlider({
		Name = 'CPS',
		Min = 1,
		Max = 9,
		DefaultMin = 7,
		DefaultMax = 7
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
										if vape.Modules.Fly.Enabled or vape.Modules.InfiniteFly.Enabled or vape.Modules.LongJump.Enabled then
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
	
local Fly
local LongJump
run(function()
	local Value
	local VerticalValue
	local WallCheck
	local PopBalloons
	local TP
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local up, down, old = 0, 0

	Fly = vape.Categories.Blatant:CreateModule({
		Name = 'Fly',
		Function = function(callback)
			frictionTable.Fly = callback or nil
			updateVelocity()
			if callback then
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
				Fly:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive and not InfiniteFly.Enabled and isnetworkowner(entitylib.character.RootPart) then
						local flyAllowed = (lplr.Character:GetAttribute('InflatedBalloons') and lplr.Character:GetAttribute('InflatedBalloons') > 0) or store.matchState == 2
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
				bedwars.BalloonController.deflateBalloon = old
				if PopBalloons.Enabled and entitylib.isAlive and (lplr.Character:GetAttribute('InflatedBalloons') or 0) > 0 then
					for _ = 1, 3 do
						bedwars.BalloonController:deflateBalloon()
					end
				end
			end
		end,
		ExtraText = function()
			return 'Heatseeker'
		end,
		Tooltip = 'Makes you go zoom.'
	})
	Value = Fly:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 23,
		Default = 23,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	VerticalValue = Fly:CreateSlider({
		Name = 'Vertical Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	WallCheck = Fly:CreateToggle({
		Name = 'Wall Check',
		Default = true
	})
	PopBalloons = Fly:CreateToggle({
		Name = 'Pop Balloons',
		Default = true
	})
	TP = Fly:CreateToggle({
		Name = 'TP Down',
		Default = true
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
	local Speed
	local Value
	local WallCheck
	local AutoJump
	local AlwaysJump
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
	
						local root, velo = entitylib.character.RootPart, getSpeed()
						local moveDirection = AntiFallDirection or entitylib.character.Humanoid.MoveDirection
						local destination = (moveDirection * math.max(Value.Value - velo, 0) * dt)
	
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
						if AutoJump.Enabled and (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed) and moveDirection ~= Vector3.zero and (Attacking or AlwaysJump.Enabled) then
							entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
						end
					end
				end))
			end
		end,
		ExtraText = function()
			return 'Heatseeker'
		end,
		Tooltip = 'Increases your movement with various methods.'
	})
	Value = Speed:CreateSlider({
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
	AutoJump = Speed:CreateToggle({
		Name = 'AutoJump',
		Function = function(callback)
			AlwaysJump.Object.Visible = callback
		end
	})
	AlwaysJump = Speed:CreateToggle({
		Name = 'Always Jump',
		Visible = false,
		Darker = true
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
	local StorageESP
	local List
	local Background
	local Color = {}
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function nearStorageItem(item)
		for _, v in List.ListEnabled do
			if item:find(v) then return v end
		end
	end
	
	local function refreshAdornee(v)
		local chest = v.Adornee:FindFirstChild('ChestFolderValue')
		chest = chest and chest.Value or nil
		if not chest then
			v.Enabled = false
			return
		end
	
		local chestitems = chest and chest:GetChildren() or {}
		for _, obj in v.Frame:GetChildren() do
			if obj:IsA('ImageLabel') and obj.Name ~= 'Blur' then
				obj:Destroy()
			end
		end
	
		v.Enabled = false
		local alreadygot = {}
		for _, item in chestitems do
			if not alreadygot[item.Name] and (table.find(List.ListEnabled, item.Name) or nearStorageItem(item.Name)) then
				alreadygot[item.Name] = true
				v.Enabled = true
				local blockimage = Instance.new('ImageLabel')
				blockimage.Size = UDim2.fromOffset(32, 32)
				blockimage.BackgroundTransparency = 1
				blockimage.Image = bedwars.getIcon({itemType = item.Name}, true)
				blockimage.Parent = v.Frame
			end
		end
		table.clear(chestitems)
	end
	
	local function Added(v)
		local chest = v:WaitForChild('ChestFolderValue', 3)
		if not (chest and StorageESP.Enabled) then return end
		chest = chest.Value
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = 'chest'
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
		StorageESP:Clean(chest.ChildAdded:Connect(function(item)
			if table.find(List.ListEnabled, item.Name) or nearStorageItem(item.Name) then
				refreshAdornee(billboard)
			end
		end))
		StorageESP:Clean(chest.ChildRemoved:Connect(function(item)
			if table.find(List.ListEnabled, item.Name) or nearStorageItem(item.Name) then
				refreshAdornee(billboard)
			end
		end))
		task.spawn(refreshAdornee, billboard)
	end
	
	StorageESP = vape.Categories.Render:CreateModule({
		Name = 'StorageESP',
		Function = function(callback)
			if callback then
				StorageESP:Clean(collectionService:GetInstanceAddedSignal('chest'):Connect(Added))
				for _, v in collectionService:GetTagged('chest') do
					task.spawn(Added, v)
				end
			else
				table.clear(Reference)
				Folder:ClearAllChildren()
			end
		end,
		Tooltip = 'Displays items in chests'
	})
	List = StorageESP:CreateTextList({
		Name = 'Item',
		Function = function()
			for _, v in Reference do
				task.spawn(refreshAdornee, v)
			end
		end
	})
	Background = StorageESP:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color.Object then Color.Object.Visible = callback end
			for _, v in Reference do
				v.Frame.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
				v.Blur.Visible = callback
			end
		end,
		Default = true
	})
	Color = StorageESP:CreateColorSlider({
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
	local AutoBalloon
	
	AutoBalloon = vape.Categories.Utility:CreateModule({
		Name = 'AutoBalloon',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.matchState ~= 0 or (not AutoBalloon.Enabled)
				if not AutoBalloon.Enabled then return end
	
				local lowestpoint = math.huge
				for _, v in store.blocks do
					local point = (v.Position.Y - (v.Size.Y / 2)) - 50
					if point < lowestpoint then 
						lowestpoint = point 
					end
				end
	
				repeat
					if entitylib.isAlive then
						if entitylib.character.RootPart.Position.Y < lowestpoint and (lplr.Character:GetAttribute('InflatedBalloons') or 0) < 3 then
							local balloon = getItem('balloon')
							if balloon then
								for _ = 1, 3 do 
									bedwars.BalloonController:inflateBalloon() 
								end
							end
							task.wait(0.1)
						end
					end
					task.wait(0.1)
				until not AutoBalloon.Enabled
			end
		end,
		Tooltip = 'Inflates when you fall into the void'
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
					if part and (part.Position - localPosition).Magnitude <= (not Legit.Enabled and specific and math.huge or range) then
						func(v)
					end
				end
			end
			task.wait(0.1)
		until not AutoKit.Enabled
	end
	
	local AutoKitFunctions = {
		battery = function()
			repeat
				if entitylib.isAlive then
					local localPosition = entitylib.character.RootPart.Position
					for i, v in bedwars.BatteryEffectsController.liveBatteries do
						if (v.position - localPosition).Magnitude <= 10 then
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
			kitCollection('bee', function(v)
				bedwars.Client:Get(remotes.BeePickup):SendToServer({beeId = v:GetAttribute('BeeId')})
			end, 18, false)
		end,
		bigman = function()
			kitCollection('treeOrb', function(v)
				if bedwars.Client:Get(remotes.ConsumeTreeOrb):CallServer({treeOrbSecret = v:GetAttribute('TreeOrbSecret')}) then
					v:Destroy()
				end
			end, 12, false)
		end,
		block_kicker = function()
			local old = bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition
			bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition = function(...)
				local origin, dir = select(2, ...)
				local plr = entitylib.EntityMouse({
					Part = 'RootPart',
					Range = 1000,
					Origin = origin,
					Players = true,
					Wallcheck = true
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
					task.spawn(bedwars.breakBlock, block, false, nil, true)
				end
	
				return unpack(res)
			end
	
			AutoKit:Clean(function()
				bedwars.CannonHandController.launchSelf = old
			end)
		end,
		dragon_slayer = function()
			kitCollection('KaliyahPunchInteraction', function(v)
				bedwars.DragonSlayerController:deleteEmblem(v)
				bedwars.DragonSlayerController:playPunchAnimation(Vector3.zero)
				bedwars.Client:Get(remotes.KaliyahPunch):SendToServer({
					target = v
				})
			end, 18, true)
		end,
		farmer_cletus = function()
			kitCollection('HarvestableCrop', function(v)
				if bedwars.Client:Get(remotes.HarvestCrop):CallServer({position = bedwars.BlockController:getBlockPosition(v.Position)}) then
					bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.PUNCH)
					bedwars.SoundManager:playSound(bedwars.SoundList.CROP_HARVEST)
				end
			end, 10, false)
		end,
		fisherman = function()
			local old = bedwars.FishingMinigameController.startMinigame
			bedwars.FishingMinigameController.startMinigame = function(_, _, result)
				result({win = true})
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
						task.spawn(bedwars.breakBlock, block, false, nil, true)
					end
				end
	
				return unpack(res)
			end
	
			AutoKit:Clean(function()
				bedwars.LaunchPadController.attemptLaunch = old
			end)
		end,
		hannah = function()
			kitCollection('HannahExecuteInteraction', function(v)
				local billboard = bedwars.Client:Get(remotes.HannahKill):CallServer({
					user = lplr,
					victimEntity = v
				}) and v:FindFirstChild('Hannah Execution Icon')
	
				if billboard then
					billboard:Destroy()
				end
			end, 30, true)
		end,
		jailor = function()
			kitCollection('jailor_soul', function(v)
				bedwars.JailorController:collectEntity(lplr, v, 'JailorSoul')
			end, 20, false)
		end,
		grim_reaper = function()
			kitCollection(bedwars.GrimReaperController.soulsByPosition, function(v)
				if entitylib.isAlive and lplr.Character:GetAttribute('Health') <= (lplr.Character:GetAttribute('MaxHealth') / 4) and (not lplr.Character:GetAttribute('GrimReaperChannel')) then
					bedwars.Client:Get(remotes.ConsumeSoul):CallServer({
						secret = v:GetAttribute('GrimReaperSoulSecret')
					})
				end
			end, 120, false)
		end,
		melody = function()
			repeat
				local mag, hp, ent = 30, math.huge
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
			kitCollection('hidden-metal', function(v)
				bedwars.Client:Get(remotes.PickupMetal):SendToServer({
					id = v:GetAttribute('Id')
				})
			end, 20, false)
		end,
		miner = function()
			kitCollection('petrified-player', function(v)
				bedwars.Client:Get(remotes.MinerDig):SendToServer({
					petrifyId = v:GetAttribute('PetrifyId')
				})
			end, 6, true)
		end,
		pinata = function()
			kitCollection(lplr.Name..':pinata', function(v)
				if getItem('candy') then
					bedwars.Client:Get(remotes.DepositPinata):CallServer(v)
				end
			end, 6, true)
		end,
		spirit_assassin = function()
			kitCollection('EvelynnSoul', function(v)
				bedwars.SpiritAssassinController:useSpirit(lplr, v)
			end, 120, true)
		end,
		star_collector = function()
			kitCollection('stars', function(v)
				bedwars.StarCollectorController:collectEntity(lplr, v, v.Name)
			end, 20, false)
		end,
		summoner = function()
			repeat
				local plr = entitylib.EntityPosition({
					Range = 31,
					Part = 'RootPart',
					Players = true,
					Sort = sortmethods.Health
				})
	
				if plr and (not Legit.Enabled or (lplr.Character:GetAttribute('Health') or 0) > 0) then
					local localPosition = entitylib.character.RootPart.Position
					local shootDir = CFrame.lookAt(localPosition, plr.RootPart.Position).LookVector
					localPosition += shootDir * math.max((localPosition - plr.RootPart.Position).Magnitude - 16, 0)
	
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
						Range = 30,
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
						Range = 30,
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
		wizard = function()
			repeat
				local ability = lplr:GetAttribute('WizardAbility')
				if ability and bedwars.AbilityController:canUseAbility(ability) then
					local plr = entitylib.EntityPosition({
						Range = 50,
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
		end
	}
	
	AutoKit = vape.Categories.Utility:CreateModule({
		Name = 'AutoKit',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.equippedKit ~= '' and store.matchState ~= 0 or (not AutoKit.Enabled)
				if AutoKit.Enabled and AutoKitFunctions[store.equippedKit] and Toggles[store.equippedKit].Enabled then
					AutoKitFunctions[store.equippedKit]()
				end
			end
		end,
		Tooltip = 'Automatically uses kit abilities.'
	})
	Legit = AutoKit:CreateToggle({Name = 'Legit Range'})
	local sortTable = {}
	for i in AutoKitFunctions do
		table.insert(sortTable, i)
	end
	table.sort(sortTable, function(a, b)
		return bedwars.BedwarsKitMeta[a].name < bedwars.BedwarsKitMeta[b].name
	end)
	for _, v in sortTable do
		Toggles[v] = AutoKit:CreateToggle({
			Name = bedwars.BedwarsKitMeta[v].name,
			Default = true
		})
	end
end)
	
run(function()
	local AutoPearl
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local projectileRemote = {InvokeServer = function() end}
	task.spawn(function()
		projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
	end)
	
	local function firePearl(pos, spot, item)
		switchItem(item.tool)
		local meta = bedwars.ProjectileMeta.telepearl
		local calc = prediction.SolveTrajectory(pos, meta.launchVelocity, meta.gravitationalAcceleration, spot, Vector3.zero, workspace.Gravity, 0, 0)
	
		if calc then
			local dir = CFrame.lookAt(pos, calc).LookVector * meta.launchVelocity
			bedwars.ProjectileController:createLocalProjectile(meta, 'telepearl', 'telepearl', pos, nil, dir, {drawDurationSeconds = 1})
			projectileRemote:InvokeServer(item.tool, 'telepearl', 'telepearl', pos, pos, dir, httpService:GenerateGUID(true), {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - 0.045)
		end
	
		if store.hand then
			switchItem(store.hand.tool)
		end
	end
	
	AutoPearl = vape.Categories.Utility:CreateModule({
		Name = 'AutoPearl',
		Function = function(callback)
			if callback then
				local check
				repeat
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						local pearl = getItem('telepearl')
						rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiFallPart}
						rayCheck.CollisionGroup = root.CollisionGroup
	
						if pearl and root.Velocity.Y < -100 and not workspace:Raycast(root.Position, Vector3.new(0, -200, 0), rayCheck) then
							if not check then
								check = true
								local ground = getNearGround(20)
	
								if ground then
									firePearl(root.Position, ground, pearl)
								end
							end
						else
							check = false
						end
					end
					task.wait(0.1)
				until not AutoPearl.Enabled
			end
		end,
		Tooltip = 'Automatically throws a pearl onto nearby ground after\nfalling a certain distance.'
	})
end)
	
run(function()
	local AutoPlay
	local Random
	
	local function isEveryoneDead()
		return #bedwars.Store:getState().Party.members <= 0
	end
	
	local function joinQueue()
		if not bedwars.Store:getState().Game.customMatch and bedwars.Store:getState().Party.leader.userId == lplr.UserId and bedwars.Store:getState().Party.queueState == 0 then
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
		end
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
	local AutoToxic
	local GG
	local Toggles, Lists, said, dead = {}, {}, {}
	
	local function sendMessage(name, obj, default)
		local tab = Lists[name].ListEnabled
		local custommsg = #tab > 0 and tab[math.random(1, #tab)] or default
		if not custommsg then return end
		if #tab > 1 and custommsg == said[name] then
			repeat 
				task.wait() 
				custommsg = tab[math.random(1, #tab)] 
			until custommsg ~= said[name]
		end
		said[name] = custommsg
	
		custommsg = custommsg and custommsg:gsub('<obj>', obj or '') or ''
		if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(custommsg)
		else
			replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(custommsg, 'All')
		end
	end
	
	AutoToxic = vape.Categories.Utility:CreateModule({
		Name = 'AutoToxic',
		Function = function(callback)
			if callback then
				AutoToxic:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
					if Toggles.BedDestroyed.Enabled and bedTable.brokenBedTeam.id == lplr:GetAttribute('Team') then
						sendMessage('BedDestroyed', (bedTable.player.DisplayName or bedTable.player.Name), 'how dare you >:( | <obj>')
					elseif Toggles.Bed.Enabled and bedTable.player.UserId == lplr.UserId then
						local team = bedwars.QueueMeta[store.queueType].teams[tonumber(bedTable.brokenBedTeam.id)]
						sendMessage('Bed', team and team.displayName:lower() or 'white', 'nice bed lul | <obj>')
					end
				end))
				AutoToxic:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
					if deathTable.finalKill then
						local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
						local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
						if not killed or not killer then return end
						if killed == lplr then
							if (not dead) and killer ~= lplr and Toggles.Death.Enabled then
								dead = true
								sendMessage('Death', (killer.DisplayName or killer.Name), 'my gaming chair subscription expired :( | <obj>')
							end
						elseif killer == lplr and Toggles.Kill.Enabled then
							sendMessage('Kill', (killed.DisplayName or killed.Name), 'vxp on top | <obj>')
						end
					end
				end))
				AutoToxic:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winstuff)
					if GG.Enabled then
						if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
							textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync('gg')
						else
							replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer('gg', 'All')
						end
					end
					
					local myTeam = bedwars.Store:getState().Game.myTeam
					if myTeam and myTeam.id == winstuff.winningTeamId or lplr.Neutral then
						if Toggles.Win.Enabled then 
							sendMessage('Win', nil, 'yall garbage') 
						end
					end
				end))
			end
		end,
		Tooltip = 'Says a message after a certain action'
	})
	GG = AutoToxic:CreateToggle({
		Name = 'AutoGG',
		Default = true
	})
	for _, v in {'Kill', 'Death', 'Bed', 'BedDestroyed', 'Win'} do
		Toggles[v] = AutoToxic:CreateToggle({
			Name = v..' ',
			Function = function(callback)
				if Lists[v] then
					Lists[v].Object.Visible = callback
				end
			end
		})
		Lists[v] = AutoToxic:CreateTextList({
			Name = v,
			Darker = true,
			Visible = false
		})
	end
end)
	
run(function()
	local AutoVoidDrop
	local OwlCheck
	
	AutoVoidDrop = vape.Categories.Utility:CreateModule({
		Name = 'AutoVoidDrop',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.matchState ~= 0 or (not AutoVoidDrop.Enabled)
				if not AutoVoidDrop.Enabled then return end
	
				local lowestpoint = math.huge
				for _, v in store.blocks do
					local point = (v.Position.Y - (v.Size.Y / 2)) - 50
					if point < lowestpoint then
						lowestpoint = point
					end
				end
	
				repeat
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						if root.Position.Y < lowestpoint and (lplr.Character:GetAttribute('InflatedBalloons') or 0) <= 0 and not getItem('balloon') then
							if not OwlCheck.Enabled or not root:FindFirstChild('OwlLiftForce') then
								for _, item in {'iron', 'diamond', 'emerald', 'gold'} do
									item = getItem(item)
									if item then
										item = bedwars.Client:Get(remotes.DropItem):CallServer({
											item = item.tool,
											amount = item.amount
										})
	
										if item then
											item:SetAttribute('ClientDropTime', tick() + 100)
										end
									end
								end
							end
						end
					end
	
					task.wait(0.1)
				until not AutoVoidDrop.Enabled
			end
		end,
		Tooltip = 'Drops resources when you fall into the void'
	})
	OwlCheck = AutoVoidDrop:CreateToggle({
		Name = 'Owl check',
		Default = true,
		Tooltip = 'Refuses to drop items if being picked up by an owl'
	})
end)
	
run(function()
	local MissileTP
	
	MissileTP = vape.Categories.Utility:CreateModule({
		Name = 'MissileTP',
		Function = function(callback)
			if callback then
				MissileTP:Toggle()
				local plr = entitylib.EntityMouse({
					Range = 1000,
					Players = true,
					Part = 'RootPart'
				})
	
				if getItem('guided_missile') and plr then
					local projectile = bedwars.RuntimeLib.await(bedwars.GuidedProjectileController.fireGuidedProjectile:CallServerAsync('guided_missile'))
					if projectile then
						local projectilemodel = projectile.model
						if not projectilemodel.PrimaryPart then
							projectilemodel:GetPropertyChangedSignal('PrimaryPart'):Wait()
						end
	
						local bodyforce = Instance.new('BodyForce')
						bodyforce.Force = Vector3.new(0, projectilemodel.PrimaryPart.AssemblyMass * workspace.Gravity, 0)
						bodyforce.Name = 'AntiGravity'
						bodyforce.Parent = projectilemodel.PrimaryPart
	
						repeat
							projectile.model:SetPrimaryPartCFrame(CFrame.lookAlong(plr.RootPart.CFrame.p, gameCamera.CFrame.LookVector))
							task.wait(0.1)
						until not projectile.model or not projectile.model.Parent
					else
						notif('MissileTP', 'Missile on cooldown.', 3)
					end
				end
			end
		end,
		Tooltip = 'Spawns and teleports a missile to a player\nnear your mouse.'
	})
end)
	
run(function()
	local PickupRange
	local Range
	local Network
	local Lower
	
	PickupRange = vape.Categories.Utility:CreateModule({
		Name = 'PickupRange',
		Function = function(callback)
			if callback then
				local items = collection('ItemDrop', PickupRange)
				repeat
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in items do
							if tick() - (v:GetAttribute('ClientDropTime') or 0) < 2 then continue end
							if isnetworkowner(v) and Network.Enabled and entitylib.character.Humanoid.Health > 0 then 
								v.CFrame = CFrame.new(localPosition - Vector3.new(0, 3, 0)) 
							end
							
							if (localPosition - v.Position).Magnitude <= Range.Value then
								if Lower.Enabled and (localPosition.Y - v.Position.Y) < (entitylib.character.HipHeight - 1) then continue end
								task.spawn(function()
									bedwars.Client:Get(remotes.PickupItem):CallServerAsync({
										itemDrop = v
									}):andThen(function(suc)
										if suc and bedwars.SoundList then
											bedwars.SoundManager:playSound(bedwars.SoundList.PICKUP_ITEM_DROP)
											local sound = bedwars.ItemMeta[v.Name].pickUpOverlaySound
											if sound then
												bedwars.SoundManager:playSound(sound, {
													position = v.Position,
													volumeMultiplier = 0.9
												})
											end
										end
									end)
								end)
							end
						end
					end
					task.wait(0.1)
				until not PickupRange.Enabled
			end
		end,
		Tooltip = 'Picks up items from a farther distance'
	})
	Range = PickupRange:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 10,
		Default = 10,
		Suffix = function(val) 
			return val == 1 and 'stud' or 'studs' 
		end
	})
	Network = PickupRange:CreateToggle({
		Name = 'Network TP',
		Default = true
	})
	Lower = PickupRange:CreateToggle({Name = 'Feet Check'})
end)
	
run(function()
	local RavenTP
	
	RavenTP = vape.Categories.Utility:CreateModule({
		Name = 'RavenTP',
		Function = function(callback)
			if callback then
				RavenTP:Toggle()
				local plr = entitylib.EntityMouse({
					Range = 1000,
					Players = true,
					Part = 'RootPart'
				})
	
				if getItem('raven') and plr then
					bedwars.Client:Get(remotes.SpawnRaven):CallServerAsync():andThen(function(projectile)
						if projectile then
							local bodyforce = Instance.new('BodyForce')
							bodyforce.Force = Vector3.new(0, projectile.PrimaryPart.AssemblyMass * workspace.Gravity, 0)
							bodyforce.Parent = projectile.PrimaryPart
	
							if plr then
								task.spawn(function()
									for _ = 1, 20 do
										if plr.RootPart and projectile then
											projectile:SetPrimaryPartCFrame(CFrame.lookAlong(plr.RootPart.Position, gameCamera.CFrame.LookVector))
										end
										task.wait(0.05)
									end
								end)
								task.wait(0.3)
								bedwars.RavenController:detonateRaven()
							end
						end
					end)
				end
			end
		end,
		Tooltip = 'Spawns and teleports a raven to a player\nnear your mouse.'
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
		Max = 6
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
	local AutoSuffocate
	local Range
	local LimitItem
	
	local function fixPosition(pos)
		return bedwars.BlockController:getBlockPosition(pos) * 3
	end
	
	AutoSuffocate = vape.Categories.World:CreateModule({
		Name = 'AutoSuffocate',
		Function = function(callback)
			if callback then
				repeat
					local item = store.hand.toolType == 'block' and store.hand.tool.Name or not LimitItem.Enabled and getWool()
	
					if item then
						local plrs = entitylib.AllPosition({
							Part = 'RootPart',
							Range = Range.Value,
							Players = true
						})
	
						for _, ent in plrs do
							local needPlaced = {}
	
							for _, side in Enum.NormalId:GetEnumItems() do
								side = Vector3.fromNormalId(side)
								if side.Y ~= 0 then continue end
	
								side = fixPosition(ent.RootPart.Position + side * 2)
								if not getPlacedBlock(side) then
									table.insert(needPlaced, side)
								end
							end
	
							if #needPlaced < 3 then
								table.insert(needPlaced, fixPosition(ent.Head.Position))
								table.insert(needPlaced, fixPosition(ent.RootPart.Position - Vector3.new(0, 1, 0)))
	
								for _, pos in needPlaced do
									if not getPlacedBlock(pos) then
										task.spawn(bedwars.placeBlock, pos, item)
										break
									end
								end
							end
						end
					end
	
					task.wait(0.09)
				until not AutoSuffocate.Enabled
			end
		end,
		Tooltip = 'Places blocks on nearby confined entities'
	})
	Range = AutoSuffocate:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 20,
		Default = 20,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	LimitItem = AutoSuffocate:CreateToggle({
		Name = 'Limit to Items',
		Default = true
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
	local BedProtector
	
	local function getBedNear()
		local localPosition = entitylib.isAlive and entitylib.character.RootPart.Position or Vector3.zero
		for _, v in collectionService:GetTagged('bed') do
			if (localPosition - v.Position).Magnitude < 20 and v:GetAttribute('Team'..(lplr:GetAttribute('Team') or -1)..'NoBreak') then
				return v
			end
		end
	end
	
	local function getBlocks()
		local blocks = {}
		for _, item in store.inventory.inventory.items do
			local block = bedwars.ItemMeta[item.itemType].block
			if block then
				table.insert(blocks, {item.itemType, block.health})
			end
		end
		table.sort(blocks, function(a, b) 
			return a[2] > b[2]
		end)
		return blocks
	end
	
	local function getPyramid(size, grid)
		local positions = {}
		for h = size, 0, -1 do
			for w = h, 0, -1 do
				table.insert(positions, Vector3.new(w, (size - h), ((h + 1) - w)) * grid)
				table.insert(positions, Vector3.new(w * -1, (size - h), ((h + 1) - w)) * grid)
				table.insert(positions, Vector3.new(w, (size - h), (h - w) * -1) * grid)
				table.insert(positions, Vector3.new(w * -1, (size - h), (h - w) * -1) * grid)
			end
		end
		return positions
	end
	
	BedProtector = vape.Categories.World:CreateModule({
		Name = 'BedProtector',
		Function = function(callback)
			if callback then
				local bed = getBedNear()
				bed = bed and bed.Position or nil
				if bed then
					for i, block in getBlocks() do
						for _, pos in getPyramid(i, 3) do
							if not BedProtector.Enabled then break end
							if getPlacedBlock(bed + pos) then continue end
							bedwars.placeBlock(bed + pos, block[1], false)
						end
					end
					if BedProtector.Enabled then 
						BedProtector:Toggle() 
					end
				else
					notif('BedProtector', 'Unable to locate bed', 5)
					BedProtector:Toggle()
				end
			end
		end,
		Tooltip = 'Automatically places strong blocks around the bed.'
	})
end)	
run(function()
	local Schematica
	local File
	local Mode
	local Transparency
	local parts, guidata, poschecklist = {}, {}, {}
	local point1, point2
	
	for x = -3, 3, 3 do
		for y = -3, 3, 3 do
			for z = -3, 3, 3 do
				if Vector3.new(x, y, z) ~= Vector3.zero then
					table.insert(poschecklist, Vector3.new(x, y, z))
				end
			end
		end
	end
	
	local function checkAdjacent(pos)
		for _, v in poschecklist do
			if getPlacedBlock(pos + v) then return true end
		end
		return false
	end
	
	local function getPlacedBlocksInPoints(s, e)
		local list, blocks = {}, bedwars.BlockController:getStore()
		for x = (e.X > s.X and s.X or e.X), (e.X > s.X and e.X or s.X) do
			for y = (e.Y > s.Y and s.Y or e.Y), (e.Y > s.Y and e.Y or s.Y) do
				for z = (e.Z > s.Z and s.Z or e.Z), (e.Z > s.Z and e.Z or s.Z) do
					local vec = Vector3.new(x, y, z)
					local block = blocks:getBlockAt(vec)
					if block and block:GetAttribute('PlacedByUserId') == lplr.UserId then
						list[vec] = block
					end
				end
			end
		end
		return list
	end
	
	local function loadMaterials()
		for _, v in guidata do 
			v:Destroy() 
		end
		local suc, read = pcall(function() 
			return isfile(File.Value) and httpService:JSONDecode(readfile(File.Value)) 
		end)
	
		if suc and read then
			local items = {}
			for _, v in read do 
				items[v[2]] = (items[v[2]] or 0) + 1 
			end
			
			for i, v in items do
				local holder = Instance.new('Frame')
				holder.Size = UDim2.new(1, 0, 0, 32)
				holder.BackgroundTransparency = 1
				holder.Parent = Schematica.Children
				local icon = Instance.new('ImageLabel')
				icon.Size = UDim2.fromOffset(24, 24)
				icon.Position = UDim2.fromOffset(4, 4)
				icon.BackgroundTransparency = 1
				icon.Image = bedwars.getIcon({itemType = i}, true)
				icon.Parent = holder
				local text = Instance.new('TextLabel')
				text.Size = UDim2.fromOffset(100, 32)
				text.Position = UDim2.fromOffset(32, 0)
				text.BackgroundTransparency = 1
				text.Text = (bedwars.ItemMeta[i] and bedwars.ItemMeta[i].displayName or i)..': '..v
				text.TextXAlignment = Enum.TextXAlignment.Left
				text.TextColor3 = uipallet.Text
				text.TextSize = 14
				text.FontFace = uipallet.Font
				text.Parent = holder
				table.insert(guidata, holder)
			end
			table.clear(read)
			table.clear(items)
		end
	end
	
	local function save()
		if point1 and point2 then
			local tab = getPlacedBlocksInPoints(point1, point2)
			local savetab = {}
			point1 = point1 * 3
			for i, v in tab do
				i = bedwars.BlockController:getBlockPosition(CFrame.lookAlong(point1, entitylib.character.RootPart.CFrame.LookVector):PointToObjectSpace(i * 3)) * 3
				table.insert(savetab, {
					{
						x = i.X, 
						y = i.Y, 
						z = i.Z
					}, 
					v.Name
				})
			end
			point1, point2 = nil, nil
			writefile(File.Value, httpService:JSONEncode(savetab))
			notif('Schematica', 'Saved '..getTableSize(tab)..' blocks', 5)
			loadMaterials()
			table.clear(tab)
			table.clear(savetab)
		else
			local mouseinfo = bedwars.BlockBreaker.clientManager:getBlockSelector():getMouseInfo(0)
			if mouseinfo and mouseinfo.target then
				if point1 then
					point2 = mouseinfo.target.blockRef.blockPosition
					notif('Schematica', 'Selected position 2, toggle again near position 1 to save it', 3)
				else
					point1 = mouseinfo.target.blockRef.blockPosition
					notif('Schematica', 'Selected position 1', 3)
				end
			end
		end
	end
	
	local function load(read)
		local mouseinfo = bedwars.BlockBreaker.clientManager:getBlockSelector():getMouseInfo(0)
		if mouseinfo and mouseinfo.target then
			local position = CFrame.new(mouseinfo.placementPosition * 3) * CFrame.Angles(0, math.rad(math.round(math.deg(math.atan2(-entitylib.character.RootPart.CFrame.LookVector.X, -entitylib.character.RootPart.CFrame.LookVector.Z)) / 45) * 45), 0)
	
			for _, v in read do
				local blockpos = bedwars.BlockController:getBlockPosition((position * CFrame.new(v[1].x, v[1].y, v[1].z)).p) * 3
				if parts[blockpos] then continue end
				local handler = bedwars.BlockController:getHandlerRegistry():getHandler(v[2]:find('wool') and getWool() or v[2])
				if handler then
					local part = handler:place(blockpos / 3, 0)
					part.Transparency = Transparency.Value
					part.CanCollide = false
					part.Anchored = true
					part.Parent = workspace
					parts[blockpos] = part
				end
			end
			table.clear(read)
	
			repeat
				if entitylib.isAlive then
					local localPosition = entitylib.character.RootPart.Position
					for i, v in parts do
						if (i - localPosition).Magnitude < 60 and checkAdjacent(i) then
							if not Schematica.Enabled then break end
							if not getItem(v.Name) then continue end
							bedwars.placeBlock(i, v.Name, false)
							task.delay(0.1, function()
								local block = getPlacedBlock(i)
								if block then
									v:Destroy()
									parts[i] = nil
								end
							end)
						end
					end
				end
				task.wait()
			until getTableSize(parts) <= 0
	
			if getTableSize(parts) <= 0 and Schematica.Enabled then
				notif('Schematica', 'Finished building', 5)
				Schematica:Toggle()
			end
		end
	end
	
	Schematica = vape.Categories.World:CreateModule({
		Name = 'Schematica',
		Function = function(callback)
			if callback then
				if not File.Value:find('.json') then
					notif('Schematica', 'Invalid file', 3)
					Schematica:Toggle()
					return
				end
	
				if Mode.Value == 'Save' then
					save()
					Schematica:Toggle()
				else
					local suc, read = pcall(function() 
						return isfile(File.Value) and httpService:JSONDecode(readfile(File.Value)) 
					end)
	
					if suc and read then
						load(read)
					else
						notif('Schematica', 'Missing / corrupted file', 3)
						Schematica:Toggle()
					end
				end
			else
				for _, v in parts do 
					v:Destroy() 
				end
				table.clear(parts)
			end
		end,
		Tooltip = 'Save and load placements of buildings'
	})
	File = Schematica:CreateTextBox({
		Name = 'File',
		Function = function()
			loadMaterials()
			point1, point2 = nil, nil
		end
	})
	Mode = Schematica:CreateDropdown({
		Name = 'Mode',
		List = {'Load', 'Save'}
	})
	Transparency = Schematica:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Default = 0.7,
		Decimal = 10,
		Function = function(val)
			for _, v in parts do 
				v.Transparency = val 
			end
		end
	})
end)
	
run(function()
	local ArmorSwitch
	local Mode
	local Targets
	local Range
	
	ArmorSwitch = vape.Categories.Inventory:CreateModule({
		Name = 'ArmorSwitch',
		Function = function(callback)
			if callback then
				if Mode.Value == 'Toggle' then
					repeat
						local state = entitylib.EntityPosition({
							Part = 'RootPart',
							Range = Range.Value,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled
						}) and true or false
	
						for i = 0, 2 do
							if (store.inventory.inventory.armor[i + 1] ~= 'empty') ~= state and ArmorSwitch.Enabled then
								bedwars.Store:dispatch({
									type = 'InventorySetArmorItem',
									item = store.inventory.inventory.armor[i + 1] == 'empty' and state and getBestArmor(i) or nil,
									armorSlot = i
								})
								vapeEvents.InventoryChanged.Event:Wait()
							end
						end
						task.wait(0.1)
					until not ArmorSwitch.Enabled
				else
					ArmorSwitch:Toggle()
					for i = 0, 2 do
						bedwars.Store:dispatch({
							type = 'InventorySetArmorItem',
							item = store.inventory.inventory.armor[i + 1] == 'empty' and getBestArmor(i) or nil,
							armorSlot = i
						})
						vapeEvents.InventoryChanged.Event:Wait()
					end
				end
			end
		end,
		Tooltip = 'Puts on / takes off armor when toggled for baiting.'
	})
	Mode = ArmorSwitch:CreateDropdown({
		Name = 'Mode',
		List = {'Toggle', 'On Key'}
	})
	Targets = ArmorSwitch:CreateTargets({
		Players = true,
		NPCs = true
	})
	Range = ArmorSwitch:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 30,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)
	
run(function()
	local AutoBank
	local UIToggle
	local UI
	local Chests
	local Items = {}
	
	local function addItem(itemType, shop)
		local item = Instance.new('ImageLabel')
		item.Image = bedwars.getIcon({itemType = itemType}, true)
		item.Size = UDim2.fromOffset(32, 32)
		item.Name = itemType
		item.BackgroundTransparency = 1
		item.LayoutOrder = #UI:GetChildren()
		item.Parent = UI
		local itemtext = Instance.new('TextLabel')
		itemtext.Name = 'Amount'
		itemtext.Size = UDim2.fromScale(1, 1)
		itemtext.BackgroundTransparency = 1
		itemtext.Text = ''
		itemtext.TextColor3 = Color3.new(1, 1, 1)
		itemtext.TextSize = 16
		itemtext.TextStrokeTransparency = 0.3
		itemtext.Font = Enum.Font.Arial
		itemtext.Parent = item
		Items[itemType] = {Object = itemtext, Type = shop}
	end
	
	local function refreshBank(echest)
		for i, v in Items do
			local item = echest:FindFirstChild(i)
			v.Object.Text = item and item:GetAttribute('Amount') or ''
		end
	end
	
	local function nearChest()
		if entitylib.isAlive then
			local pos = entitylib.character.RootPart.Position
			for _, chest in Chests do
				if (chest.Position - pos).Magnitude < 20 then
					return true
				end
			end
		end
	end
	
	local function handleState()
		local chest = replicatedStorage.Inventories:FindFirstChild(lplr.Name..'_personal')
		if not chest then return end
	
		local mapCF = workspace.MapCFrames:FindFirstChild((lplr:GetAttribute('Team') or 1)..'_spawn')
		if mapCF and (entitylib.character.RootPart.Position - mapCF.Value.Position).Magnitude < 80 then
			for _, v in chest:GetChildren() do
				local item = Items[v.Name]
				if item then
					task.spawn(function()
						bedwars.Client:GetNamespace('Inventory'):Get('ChestGetItem'):CallServer(chest, v)
						refreshBank(chest)
					end)
				end
			end
		else
			for _, v in store.inventory.inventory.items do
				local item = Items[v.itemType]
				if item then
					task.spawn(function()
						bedwars.Client:GetNamespace('Inventory'):Get('ChestGiveItem'):CallServer(chest, v.tool)
						refreshBank(chest)
					end)
				end
			end
		end
	end
	
	AutoBank = vape.Categories.Inventory:CreateModule({
		Name = 'AutoBank',
		Function = function(callback)
			if callback then
				Chests = collection('personal-chest', AutoBank)
				UI = Instance.new('Frame')
				UI.Size = UDim2.new(1, 0, 0, 32)
				UI.Position = UDim2.fromOffset(0, -240)
				UI.BackgroundTransparency = 1
				UI.Visible = UIToggle.Enabled
				UI.Parent = vape.gui
				AutoBank:Clean(UI)
				local Sort = Instance.new('UIListLayout')
				Sort.FillDirection = Enum.FillDirection.Horizontal
				Sort.HorizontalAlignment = Enum.HorizontalAlignment.Center
				Sort.SortOrder = Enum.SortOrder.LayoutOrder
				Sort.Parent = UI
				addItem('iron', true)
				addItem('gold', true)
				addItem('diamond', false)
				addItem('emerald', true)
				addItem('void_crystal', true)
	
				repeat
					local hotbar = lplr.PlayerGui:FindFirstChild('hotbar')
					hotbar = hotbar and hotbar['1']:FindFirstChild('HotbarHealthbarContainer')
					if hotbar then
						UI.Position = UDim2.fromOffset(0, (hotbar.AbsolutePosition.Y + guiService:GetGuiInset().Y) - 40)
					end
	
					local newState = nearChest()
					if newState then
						handleState()
					end
	
					task.wait(0.1)
				until (not AutoBank.Enabled)
			else
				table.clear(Items)
			end
		end,
		Tooltip = 'Automatically puts resources in ender chest'
	})
	UIToggle = AutoBank:CreateToggle({
		Name = 'UI',
		Function = function(callback)
			if AutoBank.Enabled then
				UI.Visible = callback
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
	
	AutoBuy = vape.Categories.Inventory:CreateModule({
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
	
	AutoConsume = vape.Categories.Inventory:CreateModule({
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
	local AutoHotbar
	local Mode
	local Clear
	local List
	local Active
	
	local function CreateWindow(self)
		local selectedslot = 1
		local window = Instance.new('Frame')
		window.Name = 'HotbarGUI'
		window.Size = UDim2.fromOffset(660, 465)
		window.Position = UDim2.fromScale(0.5, 0.5)
		window.BackgroundColor3 = uipallet.Main
		window.AnchorPoint = Vector2.new(0.5, 0.5)
		window.Visible = false
		window.Parent = vape.gui.ScaledGui
		local title = Instance.new('TextLabel')
		title.Name = 'Title'
		title.Size = UDim2.new(1, -10, 0, 20)
		title.Position = UDim2.fromOffset(math.abs(title.Size.X.Offset), 12)
		title.BackgroundTransparency = 1
		title.Text = 'AutoHotbar'
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = uipallet.Text
		title.TextSize = 13
		title.FontFace = uipallet.Font
		title.Parent = window
		local divider = Instance.new('Frame')
		divider.Name = 'Divider'
		divider.Size = UDim2.new(1, 0, 0, 1)
		divider.Position = UDim2.fromOffset(0, 40)
		divider.BackgroundColor3 = color.Light(uipallet.Main, 0.04)
		divider.BorderSizePixel = 0
		divider.Parent = window
		addBlur(window)
		local modal = Instance.new('TextButton')
		modal.Text = ''
		modal.BackgroundTransparency = 1
		modal.Modal = true
		modal.Parent = window
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 5)
		corner.Parent = window
		local close = Instance.new('ImageButton')
		close.Name = 'Close'
		close.Size = UDim2.fromOffset(24, 24)
		close.Position = UDim2.new(1, -35, 0, 9)
		close.BackgroundColor3 = Color3.new(1, 1, 1)
		close.BackgroundTransparency = 1
		close.Image = getcustomasset('newvape/assets/new/close.png')
		close.ImageColor3 = color.Light(uipallet.Text, 0.2)
		close.ImageTransparency = 0.5
		close.AutoButtonColor = false
		close.Parent = window
		close.MouseEnter:Connect(function()
			close.ImageTransparency = 0.3
			tween:Tween(close, TweenInfo.new(0.2), {
				BackgroundTransparency = 0.6
			})
		end)
		close.MouseLeave:Connect(function()
			close.ImageTransparency = 0.5
			tween:Tween(close, TweenInfo.new(0.2), {
				BackgroundTransparency = 1
			})
		end)
		close.MouseButton1Click:Connect(function()
			window.Visible = false
			vape.gui.ScaledGui.ClickGui.Visible = true
		end)
		local closecorner = Instance.new('UICorner')
		closecorner.CornerRadius = UDim.new(1, 0)
		closecorner.Parent = close
		local bigslot = Instance.new('Frame')
		bigslot.Size = UDim2.fromOffset(110, 111)
		bigslot.Position = UDim2.fromOffset(11, 71)
		bigslot.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
		bigslot.Parent = window
		local bigslotcorner = Instance.new('UICorner')
		bigslotcorner.CornerRadius = UDim.new(0, 4)
		bigslotcorner.Parent = bigslot
		local bigslotstroke = Instance.new('UIStroke')
		bigslotstroke.Color = color.Light(uipallet.Main, 0.034)
		bigslotstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		bigslotstroke.Parent = bigslot
		local slotnum = Instance.new('TextLabel')
		slotnum.Size = UDim2.fromOffset(80, 20)
		slotnum.Position = UDim2.fromOffset(25, 200)
		slotnum.BackgroundTransparency = 1
		slotnum.Text = 'SLOT 1'
		slotnum.TextColor3 = color.Dark(uipallet.Text, 0.1)
		slotnum.TextSize = 12
		slotnum.FontFace = uipallet.Font
		slotnum.Parent = window
		for i = 1, 9 do
			local slotbkg = Instance.new('TextButton')
			slotbkg.Name = 'Slot'..i
			slotbkg.Size = UDim2.fromOffset(51, 52)
			slotbkg.Position = UDim2.fromOffset(89 + (i * 55), 382)
			slotbkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
			slotbkg.Text = ''
			slotbkg.AutoButtonColor = false
			slotbkg.Parent = window
			local slotimage = Instance.new('ImageLabel')
			slotimage.Size = UDim2.fromOffset(32, 32)
			slotimage.Position = UDim2.new(0.5, -16, 0.5, -16)
			slotimage.BackgroundTransparency = 1
			slotimage.Image = ''
			slotimage.Parent = slotbkg
			local slotcorner = Instance.new('UICorner')
			slotcorner.CornerRadius = UDim.new(0, 4)
			slotcorner.Parent = slotbkg
			local slotstroke = Instance.new('UIStroke')
			slotstroke.Color = color.Light(uipallet.Main, 0.04)
			slotstroke.Thickness = 2
			slotstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			slotstroke.Enabled = i == selectedslot
			slotstroke.Parent = slotbkg
			slotbkg.MouseEnter:Connect(function()
				slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
			end)
			slotbkg.MouseLeave:Connect(function()
				slotbkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
			end)
			slotbkg.MouseButton1Click:Connect(function()
				window['Slot'..selectedslot].UIStroke.Enabled = false
				selectedslot = i
				slotstroke.Enabled = true
				slotnum.Text = 'SLOT '..selectedslot
			end)
			slotbkg.MouseButton2Click:Connect(function()
				local obj = self.Hotbars[self.Selected]
				if obj then
					window['Slot'..i].ImageLabel.Image = ''
					obj.Hotbar[tostring(i)] = nil
					obj.Object['Slot'..i].Image = '	'
				end
			end)
		end
		local searchbkg = Instance.new('Frame')
		searchbkg.Size = UDim2.fromOffset(496, 31)
		searchbkg.Position = UDim2.fromOffset(142, 80)
		searchbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
		searchbkg.Parent = window
		local search = Instance.new('TextBox')
		search.Size = UDim2.new(1, -10, 0, 31)
		search.Position = UDim2.fromOffset(10, 0)
		search.BackgroundTransparency = 1
		search.Text = ''
		search.PlaceholderText = ''
		search.TextXAlignment = Enum.TextXAlignment.Left
		search.TextColor3 = uipallet.Text
		search.TextSize = 12
		search.FontFace = uipallet.Font
		search.ClearTextOnFocus = false
		search.Parent = searchbkg
		local searchcorner = Instance.new('UICorner')
		searchcorner.CornerRadius = UDim.new(0, 4)
		searchcorner.Parent = searchbkg
		local searchicon = Instance.new('ImageLabel')
		searchicon.Size = UDim2.fromOffset(14, 14)
		searchicon.Position = UDim2.new(1, -26, 0, 8)
		searchicon.BackgroundTransparency = 1
		searchicon.Image = getcustomasset('newvape/assets/new/search.png')
		searchicon.ImageColor3 = color.Light(uipallet.Main, 0.37)
		searchicon.Parent = searchbkg
		local children = Instance.new('ScrollingFrame')
		children.Name = 'Children'
		children.Size = UDim2.fromOffset(500, 240)
		children.Position = UDim2.fromOffset(144, 122)
		children.BackgroundTransparency = 1
		children.BorderSizePixel = 0
		children.ScrollBarThickness = 2
		children.ScrollBarImageTransparency = 0.75
		children.CanvasSize = UDim2.new()
		children.Parent = window
		local windowlist = Instance.new('UIGridLayout')
		windowlist.SortOrder = Enum.SortOrder.LayoutOrder
		windowlist.FillDirectionMaxCells = 9
		windowlist.CellSize = UDim2.fromOffset(51, 52)
		windowlist.CellPadding = UDim2.fromOffset(4, 3)
		windowlist.Parent = children
		windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			children.CanvasSize = UDim2.fromOffset(0, windowlist.AbsoluteContentSize.Y / vape.guiscale.Scale)
		end)
		table.insert(vape.Windows, window)
	
		local function createitem(id, image)
			local slotbkg = Instance.new('TextButton')
			slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
			slotbkg.Text = ''
			slotbkg.AutoButtonColor = false
			slotbkg.Parent = children
			local slotimage = Instance.new('ImageLabel')
			slotimage.Size = UDim2.fromOffset(32, 32)
			slotimage.Position = UDim2.new(0.5, -16, 0.5, -16)
			slotimage.BackgroundTransparency = 1
			slotimage.Image = image
			slotimage.Parent = slotbkg
			local slotcorner = Instance.new('UICorner')
			slotcorner.CornerRadius = UDim.new(0, 4)
			slotcorner.Parent = slotbkg
			slotbkg.MouseEnter:Connect(function()
				slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.04)
			end)
			slotbkg.MouseLeave:Connect(function()
				slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
			end)
			slotbkg.MouseButton1Click:Connect(function()
				local obj = self.Hotbars[self.Selected]
				if obj then
					window['Slot'..selectedslot].ImageLabel.Image = image
					obj.Hotbar[tostring(selectedslot)] = id
					obj.Object['Slot'..selectedslot].Image = image
				end
			end)
		end
	
		local function indexSearch(text)
			for _, v in children:GetChildren() do
				if v:IsA('TextButton') then
					v:ClearAllChildren()
					v:Destroy()
				end
			end
	
			if text == '' then
				for _, v in {'diamond_sword', 'diamond_pickaxe', 'diamond_axe', 'shears', 'wood_bow', 'wool_white', 'fireball', 'apple', 'iron', 'gold', 'diamond', 'emerald'} do
					createitem(v, bedwars.ItemMeta[v].image)
				end
				return
			end
	
			for i, v in bedwars.ItemMeta do
				if text:lower() == i:lower():sub(1, text:len()) then
					if not v.image then continue end
					createitem(i, v.image)
				end
			end
		end
	
		search:GetPropertyChangedSignal('Text'):Connect(function()
			indexSearch(search.Text)
		end)
		indexSearch('')
	
		return window
	end
	
	vape.Components.HotbarList = function(optionsettings, children, api)
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		local optionapi = {
			Type = 'HotbarList',
			Hotbars = {},
			Selected = 1
		}
		local hotbarlist = Instance.new('TextButton')
		hotbarlist.Name = 'HotbarList'
		hotbarlist.Size = UDim2.fromOffset(220, 40)
		hotbarlist.BackgroundColor3 = optionsettings.Darker and (children.BackgroundColor3 == color.Dark(uipallet.Main, 0.02) and color.Dark(uipallet.Main, 0.04) or color.Dark(uipallet.Main, 0.02)) or children.BackgroundColor3
		hotbarlist.Text = ''
		hotbarlist.BorderSizePixel = 0
		hotbarlist.AutoButtonColor = false
		hotbarlist.Parent = children
		local textbkg = Instance.new('Frame')
		textbkg.Name = 'BKG'
		textbkg.Size = UDim2.new(1, -20, 0, 31)
		textbkg.Position = UDim2.fromOffset(10, 4)
		textbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
		textbkg.Parent = hotbarlist
		local textbkgcorner = Instance.new('UICorner')
		textbkgcorner.CornerRadius = UDim.new(0, 4)
		textbkgcorner.Parent = textbkg
		local textbutton = Instance.new('TextButton')
		textbutton.Name = 'HotbarList'
		textbutton.Size = UDim2.new(1, -2, 1, -2)
		textbutton.Position = UDim2.fromOffset(1, 1)
		textbutton.BackgroundColor3 = uipallet.Main
		textbutton.Text = ''
		textbutton.AutoButtonColor = false
		textbutton.Parent = textbkg
		textbutton.MouseEnter:Connect(function()
			tween:Tween(textbkg, TweenInfo.new(0.2), {
				BackgroundColor3 = color.Light(uipallet.Main, 0.14)
			})
		end)
		textbutton.MouseLeave:Connect(function()
			tween:Tween(textbkg, TweenInfo.new(0.2), {
				BackgroundColor3 = color.Light(uipallet.Main, 0.034)
			})
		end)
		local textbuttoncorner = Instance.new('UICorner')
		textbuttoncorner.CornerRadius = UDim.new(0, 4)
		textbuttoncorner.Parent = textbutton
		local textbuttonicon = Instance.new('ImageLabel')
		textbuttonicon.Size = UDim2.fromOffset(12, 12)
		textbuttonicon.Position = UDim2.fromScale(0.5, 0.5)
		textbuttonicon.AnchorPoint = Vector2.new(0.5, 0.5)
		textbuttonicon.BackgroundTransparency = 1
		textbuttonicon.Image = getcustomasset('newvape/assets/new/add.png')
		textbuttonicon.ImageColor3 = Color3.fromHSV(0.46, 0.96, 0.52)
		textbuttonicon.Parent = textbutton
		local childrenlist = Instance.new('Frame')
		childrenlist.Size = UDim2.new(1, 0, 1, -40)
		childrenlist.Position = UDim2.fromOffset(0, 40)
		childrenlist.BackgroundTransparency = 1
		childrenlist.Parent = hotbarlist
		local windowlist = Instance.new('UIListLayout')
		windowlist.SortOrder = Enum.SortOrder.LayoutOrder
		windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
		windowlist.Padding = UDim.new(0, 3)
		windowlist.Parent = childrenlist
		windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			hotbarlist.Size = UDim2.fromOffset(220, math.min(43 + windowlist.AbsoluteContentSize.Y / vape.guiscale.Scale, 603))
		end)
		textbutton.MouseButton1Click:Connect(function()
			optionapi:AddHotbar()
		end)
		optionapi.Window = CreateWindow(optionapi)
	
		function optionapi:Save(savetab)
			local hotbars = {}
			for _, v in self.Hotbars do
				table.insert(hotbars, v.Hotbar)
			end
			savetab.HotbarList = {
				Selected = self.Selected,
				Hotbars = hotbars
			}
		end
	
		function optionapi:Load(savetab)
			for _, v in self.Hotbars do
				v.Object:ClearAllChildren()
				v.Object:Destroy()
				table.clear(v.Hotbar)
			end
			table.clear(self.Hotbars)
			for _, v in savetab.Hotbars do
				self:AddHotbar(v)
			end
			self.Selected = savetab.Selected or 1
		end
	
		function optionapi:AddHotbar(data)
			local hotbardata = {Hotbar = data or {}}
			table.insert(self.Hotbars, hotbardata)
			local hotbar = Instance.new('TextButton')
			hotbar.Size = UDim2.fromOffset(200, 27)
			hotbar.BackgroundColor3 = table.find(self.Hotbars, hotbardata) == self.Selected and color.Light(uipallet.Main, 0.034) or uipallet.Main
			hotbar.Text = ''
			hotbar.AutoButtonColor = false
			hotbar.Parent = childrenlist
			hotbardata.Object = hotbar
			local hotbarcorner = Instance.new('UICorner')
			hotbarcorner.CornerRadius = UDim.new(0, 4)
			hotbarcorner.Parent = hotbar
			for i = 1, 9 do
				local slot = Instance.new('ImageLabel')
				slot.Name = 'Slot'..i
				slot.Size = UDim2.fromOffset(17, 18)
				slot.Position = UDim2.fromOffset(-7 + (i * 18), 5)
				slot.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
				slot.Image = hotbardata.Hotbar[tostring(i)] and bedwars.getIcon({itemType = hotbardata.Hotbar[tostring(i)]}, true) or ''
				slot.BorderSizePixel = 0
				slot.Parent = hotbar
			end
			hotbar.MouseButton1Click:Connect(function()
				local ind = table.find(optionapi.Hotbars, hotbardata)
				if ind == optionapi.Selected then
					vape.gui.ScaledGui.ClickGui.Visible = false
					optionapi.Window.Visible = true
					for i = 1, 9 do
						optionapi.Window['Slot'..i].ImageLabel.Image = hotbardata.Hotbar[tostring(i)] and bedwars.getIcon({itemType = hotbardata.Hotbar[tostring(i)]}, true) or ''
					end
				else
					if optionapi.Hotbars[optionapi.Selected] then
						optionapi.Hotbars[optionapi.Selected].Object.BackgroundColor3 = uipallet.Main
					end
					hotbar.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
					optionapi.Selected = ind
				end
			end)
			local close = Instance.new('ImageButton')
			close.Name = 'Close'
			close.Size = UDim2.fromOffset(16, 16)
			close.Position = UDim2.new(1, -23, 0, 6)
			close.BackgroundColor3 = Color3.new(1, 1, 1)
			close.BackgroundTransparency = 1
			close.Image = getcustomasset('newvape/assets/new/closemini.png')
			close.ImageColor3 = color.Light(uipallet.Text, 0.2)
			close.ImageTransparency = 0.5
			close.AutoButtonColor = false
			close.Parent = hotbar
			local closecorner = Instance.new('UICorner')
			closecorner.CornerRadius = UDim.new(1, 0)
			closecorner.Parent = close
			close.MouseEnter:Connect(function()
				close.ImageTransparency = 0.3
				tween:Tween(close, TweenInfo.new(0.2), {
					BackgroundTransparency = 0.6
				})
			end)
			close.MouseLeave:Connect(function()
				close.ImageTransparency = 0.5
				tween:Tween(close, TweenInfo.new(0.2), {
					BackgroundTransparency = 1
				})
			end)
			close.MouseButton1Click:Connect(function()
				local ind = table.find(self.Hotbars, hotbardata)
				local obj = self.Hotbars[self.Selected]
				local obj2 = self.Hotbars[ind]
				if obj and obj2 then
					obj2.Object:ClearAllChildren()
					obj2.Object:Destroy()
					table.remove(self.Hotbars, ind)
					ind = table.find(self.Hotbars, obj)
					self.Selected = table.find(self.Hotbars, obj) or 1
				end
			end)
		end
	
		api.Options.HotbarList = optionapi
	
		return optionapi
	end
	
	local function getBlock()
		local clone = table.clone(store.inventory.inventory.items)
		table.sort(clone, function(a, b)
			return a.amount < b.amount
		end)
	
		for _, item in clone do
			local block = bedwars.ItemMeta[item.itemType].block
			if block and not block.seeThrough then
				return item
			end
		end
	end
	
	local function getCustomItem(v)
		if v == 'diamond_sword' then
			local sword = store.tools.sword
			v = sword and sword.itemType or 'wood_sword'
		elseif v == 'diamond_pickaxe' then
			local pickaxe = store.tools.stone
			v = pickaxe and pickaxe.itemType or 'wood_pickaxe'
		elseif v == 'diamond_axe' then
			local axe = store.tools.wood
			v = axe and axe.itemType or 'wood_axe'
		elseif v == 'wood_bow' then
			local bow = getBow()
			v = bow and bow.itemType or 'wood_bow'
		elseif v == 'wool_white' then
			local block = getBlock()
			v = block and block.itemType or 'wool_white'
		end
	
		return v
	end
	
	local function findItemInTable(tab, item)
		for slot, v in tab do
			if item.itemType == getCustomItem(v) then
				return tonumber(slot)
			end
		end
	end
	
	local function findInHotbar(item)
		for i, v in store.inventory.hotbar do
			if v.item and v.item.itemType == item.itemType then
				return i - 1, v.item
			end
		end
	end
	
	local function findInInventory(item)
		for _, v in store.inventory.inventory.items do
			if v.itemType == item.itemType then
				return v
			end
		end
	end
	
	local function dispatch(...)
		bedwars.Store:dispatch(...)
		vapeEvents.InventoryChanged.Event:Wait()
	end
	
	local function sortCallback()
		if Active then return end
		Active = true
		local items = (List.Hotbars[List.Selected] and List.Hotbars[List.Selected].Hotbar or {})
	
		for _, v in store.inventory.inventory.items do
			local slot = findItemInTable(items, v)
			if slot then
				local olditem = store.inventory.hotbar[slot]
				if olditem.item and olditem.item.itemType == v.itemType then continue end
				if olditem.item then
					dispatch({
						type = 'InventoryRemoveFromHotbar',
						slot = slot - 1
					})
				end
	
				local newslot = findInHotbar(v)
				if newslot then
					dispatch({
						type = 'InventoryRemoveFromHotbar',
						slot = newslot
					})
					if olditem.item then
						dispatch({
							type = 'InventoryAddToHotbar',
							item = findInInventory(olditem.item),
							slot = newslot
						})
					end
				end
	
				dispatch({
					type = 'InventoryAddToHotbar',
					item = findInInventory(v),
					slot = slot - 1
				})
			elseif Clear.Enabled then
				local newslot = findInHotbar(v)
				if newslot then
				   	dispatch({
						type = 'InventoryRemoveFromHotbar',
						slot = newslot
					})
				end
			end
		end
	
		Active = false
	end
	
	AutoHotbar = vape.Categories.Inventory:CreateModule({
		Name = 'AutoHotbar',
		Function = function(callback)
			if callback then
				task.spawn(sortCallback)
				if Mode.Value == 'On Key' then
					AutoHotbar:Toggle()
					return
				end
	
				AutoHotbar:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(sortCallback))
			end
		end,
		Tooltip = 'Automatically arranges hotbar to your liking.'
	})
	Mode = AutoHotbar:CreateDropdown({
		Name = 'Activation',
		List = {'Toggle', 'On Key'},
		Function = function()
			if AutoHotbar.Enabled then
				AutoHotbar:Toggle()
				AutoHotbar:Toggle()
			end
		end
	})
	Clear = AutoHotbar:CreateToggle({Name = 'Clear Hotbar'})
	List = AutoHotbar:CreateHotbarList({})
end)
	
run(function()
	local Value
	local oldclickhold, oldshowprogress
	
	local FastConsume = vape.Categories.Inventory:CreateModule({
		Name = 'FastConsume',
		Function = function(callback)
			if callback then
				oldclickhold = bedwars.ClickHold.startClick
				oldshowprogress = bedwars.ClickHold.showProgress
				bedwars.ClickHold.startClick = function(self)
					self.startedClickTime = tick()
					local handle = self:showProgress()
					local clicktime = self.startedClickTime
					bedwars.RuntimeLib.Promise.defer(function()
						task.wait(self.durationSeconds * (Value.Value / 40))
						if handle == self.handle and clicktime == self.startedClickTime and self.closeOnComplete then
							self:hideProgress()
							if self.onComplete then self.onComplete() end
							if self.onPartialComplete then self.onPartialComplete(1) end
							self.startedClickTime = -1
						end
					end)
				end
	
				bedwars.ClickHold.showProgress = function(self)
					local roact = debug.getupvalue(oldshowprogress, 1)
					local countdown = roact.mount(roact.createElement('ScreenGui', {}, { roact.createElement('Frame', {
						[roact.Ref] = self.wrapperRef,
						Size = UDim2.new(),
						Position = UDim2.fromScale(0.5, 0.55),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = Color3.fromRGB(0, 0, 0),
						BackgroundTransparency = 0.8
					}, { roact.createElement('Frame', {
						[roact.Ref] = self.progressRef,
						Size = UDim2.fromScale(0, 1),
						BackgroundColor3 = Color3.new(1, 1, 1),
						BackgroundTransparency = 0.5
					}) }) }), lplr:FindFirstChild('PlayerGui'))
	
					self.handle = countdown
					local sizetween = tweenService:Create(self.wrapperRef:getValue(), TweenInfo.new(0.1), {
						Size = UDim2.fromScale(0.11, 0.005)
					})
					local countdowntween = tweenService:Create(self.progressRef:getValue(), TweenInfo.new(self.durationSeconds * (Value.Value / 100), Enum.EasingStyle.Linear), {
						Size = UDim2.fromScale(1, 1)
					})
	
					sizetween:Play()
					countdowntween:Play()
					table.insert(self.tweens, countdowntween)
					table.insert(self.tweens, sizetween)
					
					return countdown
				end
			else
				bedwars.ClickHold.startClick = oldclickhold
				bedwars.ClickHold.showProgress = oldshowprogress
				oldclickhold = nil
				oldshowprogress = nil
			end
		end,
		Tooltip = 'Use/Consume items quicker.'
	})
	Value = FastConsume:CreateSlider({
		Name = 'Multiplier',
		Min = 0,
		Max = 100
	})
end)
	
run(function()
	local FastDrop
	
	FastDrop = vape.Categories.Inventory:CreateModule({
		Name = 'FastDrop',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and (not store.inventory.opened) and (inputService:IsKeyDown(Enum.KeyCode.H) or inputService:IsKeyDown(Enum.KeyCode.Backspace)) and inputService:GetFocusedTextBox() == nil then
						task.spawn(bedwars.ItemDropController.dropItemInHand)
						task.wait()
					else
						task.wait(0.1)
					end
				until not FastDrop.Enabled
			end
		end,
		Tooltip = 'Drops items fast when you hold Q'
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
	
	BedPlates = vape.Categories.Minigames:CreateModule({
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
	local Breaker
	local Range
	local BreakSpeed
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
						Image = getcustomasset('newvape/assets/new/blur.png'),
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
	
				task.wait(InstantBreak.Enabled and (store.damageBlockFail > tick() and 4.5 or 0) or BreakSpeed.Value)
	
				return true
			end
		end
	
		return false
	end
	
	Breaker = vape.Categories.Minigames:CreateModule({
		Name = 'Breaker',
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
	
				local beds = collection('bed', Breaker)
				local luckyblock = collection('LuckyBlock', Breaker)
				local ironores = collection('iron-ore', Breaker)
				customlist = collection('block', Breaker, function(tab, obj)
					if table.find(Custom.ListEnabled, obj.Name) then
						table.insert(tab, obj)
					end
				end)
	
				repeat
					task.wait(1 / UpdateRate.Value)
					if not Breaker.Enabled then break end
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
				until not Breaker.Enabled
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
	Range = Breaker:CreateSlider({
		Name = 'Break range',
		Min = 1,
		Max = 30,
		Default = 30,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	BreakSpeed = Breaker:CreateSlider({
		Name = 'Break speed',
		Min = 0,
		Max = 0.3,
		Default = 0.25,
		Decimal = 100,
		Suffix = 'seconds'
	})
	UpdateRate = Breaker:CreateSlider({
		Name = 'Update rate',
		Min = 1,
		Max = 120,
		Default = 60,
		Suffix = 'hz'
	})
	Custom = Breaker:CreateTextList({
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
	Bed = Breaker:CreateToggle({
		Name = 'Break Bed',
		Default = true
	})
	LuckyBlock = Breaker:CreateToggle({
		Name = 'Break Lucky Block',
		Default = true
	})
	IronOre = Breaker:CreateToggle({
		Name = 'Break Iron Ore',
		Default = true
	})
	Effect = Breaker:CreateToggle({
		Name = 'Show Healthbar & Effects',
		Function = function(callback)
			if CustomHealth.Object then
				CustomHealth.Object.Visible = callback
			end
		end,
		Default = true
	})
	CustomHealth = Breaker:CreateToggle({
		Name = 'Custom Healthbar',
		Default = true,
		Darker = true
	})
	Animation = Breaker:CreateToggle({Name = 'Animation'})
	SelfBreak = Breaker:CreateToggle({Name = 'Self Break'})
	InstantBreak = Breaker:CreateToggle({Name = 'Instant Break'})
	LimitItem = Breaker:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only breaks when tools are held'
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
	local old
	local Image
	
	local Crosshair = vape.Legit:CreateModule({
		Name = 'Crosshair',
		Function = function(callback)
			if callback then
				old = debug.getconstant(bedwars.ViewmodelController.showCrosshair, 25)
				debug.setconstant(bedwars.ViewmodelController.showCrosshair, 25, Image.Value)
				debug.setconstant(bedwars.ViewmodelController.showCrosshair, 37, Image.Value)
			else
				debug.setconstant(bedwars.ViewmodelController.showCrosshair, 25, old)
				debug.setconstant(bedwars.ViewmodelController.showCrosshair, 37, old)
				old = nil
			end
	
			if bedwars.ViewmodelController.crosshair then
				bedwars.ViewmodelController:hideCrosshair()
				bedwars.ViewmodelController:showCrosshair()
			end
		end,
		Tooltip = 'Custom first person crosshair depending on the image choosen.'
	})
	Image = Crosshair:CreateTextBox({
		Name = 'Image',
		Placeholder = 'image id (roblox)',
		Function = function(enter)
			if enter and Crosshair.Enabled then
				Crosshair:Toggle()
				Crosshair:Toggle()
			end
		end
	})
end)
	
run(function()
	local DamageIndicator
	local FontOption
	local Color
	local Size
	local Anchor
	local Stroke
	local suc, tab = pcall(function()
		return debug.getupvalue(bedwars.DamageIndicator, 2)
	end)
	tab = suc and tab or {}
	local oldvalues, oldfont = {}
	
	DamageIndicator = vape.Legit:CreateModule({
		Name = 'Damage Indicator',
		Function = function(callback)
			if callback then
				oldvalues = table.clone(tab)
				oldfont = debug.getconstant(bedwars.DamageIndicator, 86)
				debug.setconstant(bedwars.DamageIndicator, 86, Enum.Font[FontOption.Value])
				debug.setconstant(bedwars.DamageIndicator, 119, Stroke.Enabled and 'Thickness' or 'Enabled')
				tab.strokeThickness = Stroke.Enabled and 1 or false
				tab.textSize = Size.Value
				tab.blowUpSize = Size.Value
				tab.blowUpDuration = 0
				tab.baseColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				tab.blowUpCompleteDuration = 0
				tab.anchoredDuration = Anchor.Value
			else
				for i, v in oldvalues do
					tab[i] = v
				end
				debug.setconstant(bedwars.DamageIndicator, 86, oldfont)
				debug.setconstant(bedwars.DamageIndicator, 119, 'Thickness')
			end
		end,
		Tooltip = 'Customize the damage indicator'
	})
	local fontitems = {'GothamBlack'}
	for _, v in Enum.Font:GetEnumItems() do
		if v.Name ~= 'GothamBlack' then
			table.insert(fontitems, v.Name)
		end
	end
	FontOption = DamageIndicator:CreateDropdown({
		Name = 'Font',
		List = fontitems,
		Function = function(val)
			if DamageIndicator.Enabled then
				debug.setconstant(bedwars.DamageIndicator, 86, Enum.Font[val])
			end
		end
	})
	Color = DamageIndicator:CreateColorSlider({
		Name = 'Color',
		DefaultHue = 0,
		Function = function(hue, sat, val)
			if DamageIndicator.Enabled then
				tab.baseColor = Color3.fromHSV(hue, sat, val)
			end
		end
	})
	Size = DamageIndicator:CreateSlider({
		Name = 'Size',
		Min = 1,
		Max = 32,
		Default = 32,
		Function = function(val)
			if DamageIndicator.Enabled then
				tab.textSize = val
				tab.blowUpSize = val
			end
		end
	})
	Anchor = DamageIndicator:CreateSlider({
		Name = 'Anchor',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Function = function(val)
			if DamageIndicator.Enabled then
				tab.anchoredDuration = val
			end
		end
	})
	Stroke = DamageIndicator:CreateToggle({
		Name = 'Stroke',
		Function = function(callback)
			if DamageIndicator.Enabled then
				debug.setconstant(bedwars.DamageIndicator, 119, callback and 'Thickness' or 'Enabled')
				tab.strokeThickness = callback and 1 or false
			end
		end
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
	local Interface
	local HotbarOpenInventory = require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-open-inventory']).HotbarOpenInventory
	local HotbarHealthbar = require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui.healthbar['hotbar-healthbar']).HotbarHealthbar
	local HotbarApp = getRoactRender(require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-app']).HotbarApp.render)
	local old, new = {}, {}
	
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
		if not func then return end
		if not old[func] then old[func] = {} end
		if not new[func] then new[func] = {} end
		if not old[func][ind] then
			old[func][ind] = debug.getconstant(func, ind)
		end
		if typeof(old[func][ind]) ~= typeof(val) then return end
		new[func][ind] = val
	
		if Interface.Enabled then
			if val then
				debug.setconstant(func, ind, val)
			else
				debug.setconstant(func, ind, old[func][ind])
				old[func][ind] = nil
			end
		end
	end
	
	Interface = vape.Legit:CreateModule({
		Name = 'Interface',
		Function = function(callback)
			for i, v in (callback and new or old) do
				for i2, v2 in v do
					debug.setconstant(i, i2, v2)
				end
			end
		end,
		Tooltip = 'Customize bedwars UI'
	})
	local fontitems = {'LuckiestGuy'}
	for _, v in Enum.Font:GetEnumItems() do
		if v.Name ~= 'LuckiestGuy' then
			table.insert(fontitems, v.Name)
		end
	end
	Interface:CreateDropdown({
		Name = 'Health Font',
		List = fontitems,
		Function = function(val)
			modifyconstant(HotbarHealthbar.render, 77, val)
		end
	})
	Interface:CreateColorSlider({
		Name = 'Health Color',
		Function = function(hue, sat, val)
			modifyconstant(HotbarHealthbar.render, 16, tonumber(Color3.fromHSV(hue, sat, val):ToHex(), 16))
			if Interface.Enabled then
				local hotbar = lplr.PlayerGui:FindFirstChild('hotbar')
				hotbar = hotbar and hotbar:FindFirstChild('HealthbarProgressWrapper', true)
				if hotbar then
					hotbar['1'].BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				end
			end
		end
	})
	Interface:CreateColorSlider({
		Name = 'Hotbar Color',
		DefaultOpacity = 0.8,
		Function = function(hue, sat, val, opacity)
			local func = oldinvrender or HotbarOpenInventory.render
			modifyconstant(debug.getupvalue(HotbarApp, 23).render, 51, tonumber(Color3.fromHSV(hue, sat, val):ToHex(), 16))
			modifyconstant(debug.getupvalue(HotbarApp, 23).render, 58, tonumber(Color3.fromHSV(hue, sat, math.clamp(val > 0.5 and val - 0.2 or val + 0.2, 0, 1)):ToHex(), 16))
			modifyconstant(debug.getupvalue(HotbarApp, 23).render, 54, 1 - opacity)
			modifyconstant(debug.getupvalue(HotbarApp, 23).render, 55, math.clamp(1.2 - opacity, 0, 1))
			modifyconstant(func, 31, tonumber(Color3.fromHSV(hue, sat, val):ToHex(), 16))
			modifyconstant(func, 32, math.clamp(1.2 - opacity, 0, 1))
			modifyconstant(func, 34, tonumber(Color3.fromHSV(hue, sat, math.clamp(val > 0.5 and val - 0.2 or val + 0.2, 0, 1)):ToHex(), 16))
		end
	})
end)	
run(function()
	local ReachDisplay
	local label
	
	ReachDisplay = vape.Legit:CreateModule({
		Name = 'Reach Display',
		Function = function(callback)
			if callback then
				repeat
					label.Text = (store.attackReachUpdate > tick() and store.attackReach or '0.00')..' studs'
					task.wait(0.4)
				until not ReachDisplay.Enabled
			end
		end,
		Size = UDim2.fromOffset(100, 41)
	})
	ReachDisplay:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			label.FontFace = val
		end
	})
	ReachDisplay:CreateColorSlider({
		Name = 'Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			label.BackgroundTransparency = 1 - opacity
		end
	})
	label = Instance.new('TextLabel')
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.5
	label.TextSize = 15
	label.Font = Enum.Font.Gotham
	label.Text = '0.00 studs'
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.new()
	label.Parent = ReachDisplay.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
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
	local SoundChanger
	local List
	local soundlist = {}
	local old
	
	SoundChanger = vape.Legit:CreateModule({
		Name = 'SoundChanger',
		Function = function(callback)
			if callback then
				old = bedwars.SoundManager.playSound
				bedwars.SoundManager.playSound = function(self, id, ...)
					if soundlist[id] then
						id = soundlist[id]
					end
	
					return old(self, id, ...)
				end
			else
				bedwars.SoundManager.playSound = old
				old = nil
			end
		end,
		Tooltip = 'Change ingame sounds to custom ones.'
	})
	List = SoundChanger:CreateTextList({
		Name = 'Sounds',
		Placeholder = '(DAMAGE_1/ben.mp3)',
		Function = function()
			table.clear(soundlist)
			for _, entry in List.ListEnabled do
				local split = entry:split('/')
				local id = bedwars.SoundList[split[1]]
				if id and #split > 1 then
					soundlist[id] = split[2]:find('rbxasset') and split[2] or isfile(split[2]) and assetfunction(split[2]) or ''
				end
			end
		end
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
	local WinEffect
	local List
	local NameToId = {}
	
	WinEffect = vape.Legit:CreateModule({
		Name = 'WinEffect',
		Function = function(callback)
			if callback then
				WinEffect:Clean(vapeEvents.MatchEndEvent.Event:Connect(function()
					for i, v in getconnections(bedwars.Client:Get('WinEffectTriggered').instance.OnClientEvent) do
						if v.Function then
							v.Function({
								winEffectType = NameToId[List.Value],
								winningPlayer = lplr
							})
						end
					end
				end))
			end
		end,
		Tooltip = 'Allows you to select any clientside win effect'
	})
	local WinEffectName = {}
	for i, v in bedwars.WinEffectMeta do
		table.insert(WinEffectName, v.name)
		NameToId[v.name] = i
	end
	table.sort(WinEffectName)
	List = WinEffect:CreateDropdown({
		Name = 'Effects',
		List = WinEffectName
	})
end)
local ZoomUnlocker
run(function()
    ZoomUnlocker = vape.Categories.Utility:CreateModule({
        Name = "Zoom Unlocker",
        Function = function(enabled)
            game:GetService("Players").LocalPlayer.CameraMaxZoomDistance = enabled and math.huge or 128
        end,
        Tooltip = "Makes it so you can zoom infinitely"
    })
end)
run(function()
    local TextChatService = game:GetService("TextChatService")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    local ChatTag = vape.Categories.Render:CreateModule({
        Name = "ChatTag",
        Function = function(enabled)
            if enabled then
                TextChatService.OnIncomingMessage = function(message)
                    local properties = Instance.new("TextChatMessageProperties")
                    if message.TextSource and message.TextSource.UserId == LocalPlayer.UserId then
                        -- Change the color to blue
                        properties.PrefixText = "<font color='#0000ff'>[RainWare V6]</font> " .. (message.PrefixText or "")
                    end
                    return properties
                end
            else
                TextChatService.OnIncomingMessage = nil
            end
        end,
        Tooltip = "Adds a tag next to your name when you chat."
    })
end)
run(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LocalPlayer = Players.LocalPlayer
    local loopConn
    local invisibilityEnabled = false

    local function modifyHRP(onEnable)
        local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local hrp = character:WaitForChild("HumanoidRootPart")

        if onEnable then
            hrp.Transparency = 0.3
            hrp.Color = Color3.new(1, 1, 1)
            hrp.Material = Enum.Material.Plastic
        else
            hrp.Transparency = 1
        end

        hrp.CanCollide = true
        hrp.Anchored = false
    end

    local function setCharacterVisibility(isVisible)
        local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.LocalTransparencyModifier = isVisible and 0 or 1
            elseif part:IsA("Decal") then
                part.Transparency = isVisible and 0 or 1
            elseif part:IsA("LayerCollector") then
                part.Enabled = isVisible
            end
        end
    end

    local function startLoop(Character)
        local Humanoid = Character:FindFirstChild("Humanoid")
        if not Humanoid or Humanoid.RigType == Enum.HumanoidRigType.R6 then return end

        local RootPart = Character:FindFirstChild("HumanoidRootPart")
        if not RootPart then return end

        if loopConn then loopConn:Disconnect() end

        loopConn = RunService.Heartbeat:Connect(function()
            if not invisibilityEnabled or not Character or not Humanoid or not RootPart then return end

            -- Force character invisible every frame
            for _, part in ipairs(Character:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.LocalTransparencyModifier = 1
                elseif part:IsA("Decal") then
                    part.Transparency = 1
                elseif part:IsA("LayerCollector") then
                    part.Enabled = false
                end
            end

            -- Position/animation spoof
            local oldcf = RootPart.CFrame
            local oldcamoffset = Humanoid.CameraOffset
            local newcf = RootPart.CFrame - Vector3.new(0, Humanoid.HipHeight + (RootPart.Size.Y / 2) - 1, 0)

            RootPart.CFrame = newcf * CFrame.Angles(0, 0, math.rad(180))
            Humanoid.CameraOffset = Vector3.new(0, -5, 0)

            local anim = Instance.new("Animation")
            anim.AnimationId = "http://www.roblox.com/asset/?id=11360825341"
            local loaded = Humanoid.Animator:LoadAnimation(anim)
            loaded.Priority = Enum.AnimationPriority.Action4
            loaded:Play()
            loaded.TimePosition = 0.2
            loaded:AdjustSpeed(0)

            RunService.RenderStepped:Wait()
            loaded:Stop()

            Humanoid.CameraOffset = oldcamoffset
            RootPart.CFrame = oldcf
        end)
    end

    Invisibility = vape.Categories.Blatant:CreateModule({
        Name = 'Invisibility',
        Function = function(callback)
            invisibilityEnabled = callback
            local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

            if callback then
                vape:CreateNotification('Invisibility Enabled', 'You are now invisible.', 4)
                modifyHRP(true)
                setCharacterVisibility(false)
                startLoop(character)
            else
                if loopConn then
                    loopConn:Disconnect()
                    loopConn = nil
                end
                modifyHRP(false)
                setCharacterVisibility(true)
            end
        end,
        Default = false,
        Tooltip = ""
    })

    LocalPlayer.CharacterAdded:Connect(function()
        if invisibilityEnabled then
            task.wait(0.5)
            Invisibility.Function(true)
        end
    end)
end)
run(function()
    local InfiniteJump
    local Velocity
    InfiniteJump = vape.Categories.Modules:CreateModule({
        Name = "InfiniteJump",
        Function = function(callback)
            if callback then
				InfiniteJump:Clean(inputService.InputBegan:Connect(function(input, gameProcessed)
					if gameProcessed then return end
					if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Space then
						while inputService:IsKeyDown(Enum.KeyCode.Space) do
							local PrimaryPart = lplr.Character.PrimaryPart
							if entitylib.isAlive and PrimaryPart then
								PrimaryPart.Velocity = vector.create(PrimaryPart.Velocity.X, Velocity.Value, PrimaryPart.Velocity.Z)
							end
							wait()
						end
					end
				end))
				if inputService.TouchEnabled then
					local Jumping = false
					local JumpButton = lplr.PlayerGui:WaitForChild("TouchGui"):WaitForChild("TouchControlFrame"):WaitForChild("JumpButton")
					
					InfiniteJump:Clean(JumpButton.MouseButton1Down:Connect(function()
						Jumping = true
					end))

					InfiniteJump:Clean(JumpButton.MouseButton1Up:Connect(function()
						Jumping = false
					end))

					InfiniteJump:Clean(runService.RenderStepped:Connect(function()
						if Jumping and entitylib.isAlive then
							local PrimaryPart = lplr.Character.PrimaryPart
							PrimaryPart.Velocity = vector.create(PrimaryPart.Velocity.X, Velocity.Value, PrimaryPart.Velocity.Z)
						end
					end))
				end
			end
        end,
        Tooltip = "Allows infinite jumping"
    })
    Velocity = InfiniteJump:CreateSlider({
        Name = 'Velocity',
        Min = 50,
        Max = 300,
        Default = 50
    })
end)
run(function()
    local ClickDash
    local DashDistance

    ClickDash = vape.Categories.Utility:CreateModule({
        Name = "ClickDash",
        Function = function(callback)
            if callback and entitylib.isAlive and lplr.Character and lplr.Character.PrimaryPart then
                local root = lplr.Character.PrimaryPart
                local forward = workspace.CurrentCamera.CFrame.LookVector
                local dashTo = root.Position + (forward * DashDistance.Value)
                lplr.Character:SetPrimaryPartCFrame(CFrame.new(dashTo))
            end
        end,
        Tooltip = "Dashes forward instantly when activated"
    })

    DashDistance = ClickDash:CreateSlider({
        Name = "Dash Distance",
        Min = 10,
        Max = 100,
        Default = 40
    })
end)
local YuziFly
run(function()
	local up, down = 0, 0
	local JumpTick, JumpSpeed, Direction = tick(), 0
	local delayFlyUntil = 0

	YuziFly = vape.Categories.Blatant:CreateModule({
		Name = "YuziFly",
		Function = function(enabled)
			frictionTable.YuziFly = enabled or nil
			updateVelocity()
			if enabled then
				JumpTick = tick()
				JumpSpeed = 0
				Direction = nil
				delayFlyUntil = 0
				up, down = 0, 0

				local daoList = {
					["wood_dao"] = true,
					["stone_dao"] = true,
					["iron_dao"] = true,
					["diamond_dao"] = true,
					["emerald_dao"] = true
				}

				local item = store.hand and store.hand.tool
				if item and daoList[item.Name] and bedwars.AbilityController:canUseAbility("dash") then
					local root = entitylib.character.RootPart
					local pos = root.Position
					local dir = root.CFrame.LookVector

					bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
					switchItem(item, 0.1)

					replicatedStorage["events-@easy-games/game-core:shared/game-core-networking@getEvents.Events"]
						.useAbility:FireServer("dash", {
							direction = dir,
							origin = pos,
							weapon = item.Name
						})

					JumpSpeed = 4.5
					JumpTick = tick() + 2.4
					Direction = Vector3.new(dir.X, 0, dir.Z).Unit
					delayFlyUntil = tick() + 0.2
				end

				YuziFly:Clean(runService.PreSimulation:Connect(function()
					if not entitylib.isAlive then return end
					local root = entitylib.character.RootPart
					if not isnetworkowner(root) then return end

					local moveDir = entitylib.character.Humanoid.MoveDirection
					local flyVec = moveDir * getSpeed()
					local yVel = (up + down) * 45

					if JumpTick > tick() and Direction then
						flyVec += Direction * JumpSpeed
					end

					if tick() >= delayFlyUntil then
						root.AssemblyLinearVelocity = flyVec + Vector3.new(0, yVel, 0)
					end
				end))

				YuziFly:Clean(inputService.InputBegan:Connect(function(input)
					if not inputService:GetFocusedTextBox() then
						if input.KeyCode == Enum.KeyCode.Space then
							up = 1
						elseif input.KeyCode == Enum.KeyCode.LeftShift then
							down = -1
						end
					end
				end))

				YuziFly:Clean(inputService.InputEnded:Connect(function(input)
					if input.KeyCode == Enum.KeyCode.Space then
						up = 0
					elseif input.KeyCode == Enum.KeyCode.LeftShift then
						down = 0
					end
				end))
			else
				JumpSpeed = 0
				Direction = nil
				delayFlyUntil = 0
				up, down = 0, 0
			end
		end,
		ExtraText = function()
			return "Heatseeker"
		end,
		Tooltip = "Lets you fly longer with yuzi"
	})
end)
run(function()
	local studantivoid

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

	studantivoid = vape.Categories.Blatant:CreateModule({
		Name = "StudAntiVoid",
		Function = function(callback)
			if callback then
				repeat task.wait() until store.matchState ~= 0 or (not studantivoid.Enabled)
				if not studantivoid.Enabled then return end

				local pos = getLowGround()
				if pos ~= math.huge then
					local part = Instance.new("Part")
					part.Size = Vector3.new(10000, 1, 10000)
					part.Transparency = 0.23
					part.Anchored = true
					part.CanCollide = true
					part.Material = Enum.Material.Plastic
					part.Color = Color3.new(0.5, 0, 0.5)
					part.Position = Vector3.new(0, pos - 2, 0)
					part.Parent = workspace

					local decal = Instance.new("Decal")
					decal.Texture = "rbxasset://textures/terrain/Studs.png"
					decal.Face = Enum.NormalId.Top
					decal.Parent = part

					studantivoid:Clean(part)
				end
			end
		end,
		Tooltip = "Stud Antivoid"
	})
end)
local CheaterDetector
run(function()
	local flagged = {}

	CheaterDetector = vape.Categories.Utility:CreateModule({
		Name = "CheaterDetector",
		Function = function(enabled)
			if enabled then
				for _, player in pairs(game.Players:GetPlayers()) do
					if player ~= game.Players.LocalPlayer and not flagged[player] then
						local accountAge = player.AccountAge or 0
						if accountAge < 25 then
							flagged[player] = true
							notif("Cheaterdetector", player.Name .. " might be cheating (" .. accountAge .. " days)", 10, "warning")
						end
					end
				end
				game.Players.PlayerAdded:Connect(function(player)
					if player ~= game.Players.LocalPlayer then
						task.delay(5, function() 
							if not flagged[player] then
								local accountAge = player.AccountAge or 0
								if accountAge < 25 then
									flagged[player] = true
									notif("Cheaterdetector", player.Name .. " might be cheating (" .. accountAge .. " days)", 10, "warning")
								end
							end
						end)
					end
				end)
			else
				flagged = {}
			end
		end,
		Tooltip = "Detects players that might be cheating"
	})
end)
notif("Rainware", "Loaded RainWare V6 Rewrite🌧️", 5, "alert")
run(function()
    local MusicPlayer
    local songLibrary = {
        {name = "Raining Tacos", tags = {"Raining", "Tacos", "ambient"}, id = "rbxassetid://142376088"},
        {name = "Elegant Scones Lover", tags = {"Elegant", "Scones", "Lover"}, id = "rbxassetid://93669715727290"},
        {name = "Fantasy Echo", tags = {"fantasy", "echo", "dreamy"}, id = "rbxassetid://1837095140"},
        {name = "Relax Beats", tags = {"chill", "relax", "vibe"}, id = "rbxassetid://85145737471753"},
        {name = "Ambient Haze", tags = {"ambient", "fog", "haze"}, id = "rbxassetid://16190760005"}
    }

    local currentTrack = 1
    local soundInstance

    local function playTrack(index)
        if soundInstance then soundInstance:Stop(); soundInstance:Destroy() end
        soundInstance = Instance.new("Sound")
        soundInstance.SoundId = songLibrary[index].id
        soundInstance.Volume = 0.7
        soundInstance.Looped = true
        soundInstance.Parent = workspace
        task.wait(1)
        soundInstance:Play()
    end

    local function searchSongs(query)
        for i, song in ipairs(songLibrary) do
            if string.lower(song.name):find(string.lower(query)) then
                return i
            else
                for _, tag in ipairs(song.tags) do
                    if string.lower(tag):find(string.lower(query)) then
                        return i
                    end
                end
            end
        end
        return nil
    end

    local function createGUI()
        local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
        local screenGui = Instance.new("ScreenGui", playerGui)
        screenGui.Name = "BlueSpotifyGUI"
        screenGui.ResetOnSpawn = false

        local frame = Instance.new("Frame", screenGui)
        frame.Size = UDim2.new(0, 360, 0, 230)
        frame.Position = UDim2.new(0.5, -180, 0.75, -115)
        frame.BackgroundColor3 = Color3.fromRGB(60, 130, 200)
        frame.BorderSizePixel = 0
        frame.Active = true
        frame.Draggable = true
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

        local title = Instance.new("TextLabel", frame)
        title.Size = UDim2.new(1, 0, 0, 30)
        title.Text = "🔍 Virtual Music Search"
        title.Font = Enum.Font.GothamBold
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.BackgroundTransparency = 1
        title.TextSize = 18

        local searchBox = Instance.new("TextBox", frame)
        searchBox.Position = UDim2.new(0.05, 0, 0, 35)
        searchBox.Size = UDim2.new(0.9, 0, 0, 28)
        searchBox.PlaceholderText = "Enter track name or keyword..."
        searchBox.Text = ""
        searchBox.Font = Enum.Font.Gotham
        searchBox.TextSize = 14
        searchBox.BackgroundColor3 = Color3.fromRGB(180, 210, 230)
        searchBox.TextColor3 = Color3.fromRGB(0, 0, 0)

        local trackLabel = Instance.new("TextLabel", frame)
        trackLabel.Position = UDim2.new(0, 0, 0, 70)
        trackLabel.Size = UDim2.new(1, 0, 0, 30)
        trackLabel.Text = songLibrary[currentTrack].name
        trackLabel.Font = Enum.Font.GothamSemibold
        trackLabel.TextColor3 = Color3.fromRGB(10, 40, 80)
        trackLabel.BackgroundTransparency = 1
        trackLabel.TextSize = 16

        searchBox.FocusLost:Connect(function()
            local foundIndex = searchSongs(searchBox.Text)
            if foundIndex then
                currentTrack = foundIndex
                trackLabel.Text = songLibrary[foundIndex].name
                playTrack(foundIndex)
            else
                trackLabel.Text = "No match found"
            end
        end)

        local function createButton(txt, pos, callback)
            local btn = Instance.new("TextButton", frame)
            btn.Size = UDim2.new(0, 60, 0, 30)
            btn.Position = pos
            btn.Text = txt
            btn.Font = Enum.Font.Gotham
            btn.BackgroundColor3 = Color3.fromRGB(150, 200, 250)
            btn.TextColor3 = Color3.fromRGB(0, 20, 50)
            btn.TextSize = 14
            btn.MouseButton1Click:Connect(callback)
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
        end

        createButton("⏮️", UDim2.new(0.05, 0, 0, 110), function()
            currentTrack = (currentTrack - 1 < 1) and #songLibrary or currentTrack - 1
            trackLabel.Text = songLibrary[currentTrack].name
            playTrack(currentTrack)
        end)

        createButton("▶️", UDim2.new(0.30, 0, 0, 110), function()
            playTrack(currentTrack)
        end)

        createButton("⏸️", UDim2.new(0.55, 0, 0, 110), function()
            if soundInstance then soundInstance:Pause() end
        end)

        createButton("⏭️", UDim2.new(0.80, 0, 0, 110), function()
            currentTrack = (currentTrack + 1 > #songLibrary) and 1 or currentTrack + 1
            trackLabel.Text = songLibrary[currentTrack].name
            playTrack(currentTrack)
        end)

        local volumeSlider = Instance.new("TextBox", frame)
        volumeSlider.Position = UDim2.new(0.05, 0, 0, 160)
        volumeSlider.Size = UDim2.new(0.9, 0, 0, 28)
        volumeSlider.PlaceholderText = "Volume (0.0 - 1.0)"
        volumeSlider.Text = tostring(soundInstance and soundInstance.Volume or 0.7)
        volumeSlider.Font = Enum.Font.Gotham
        volumeSlider.TextSize = 14
        volumeSlider.BackgroundColor3 = Color3.fromRGB(180, 210, 230)
        volumeSlider.TextColor3 = Color3.fromRGB(0, 0, 0)

        volumeSlider.FocusLost:Connect(function()
            local val = tonumber(volumeSlider.Text)
            if val and soundInstance then
                soundInstance.Volume = math.clamp(val, 0, 1)
            end
        end)
    end

    MusicPlayer = vape.Categories.Utility:CreateModule({
        Name = "MusicPlayer",
        Function = function(enabled)
            if enabled then
                createGUI()
                playTrack(currentTrack)
            else
                if soundInstance then soundInstance:Stop(); soundInstance:Destroy() end
                local pg = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
                if pg and pg:FindFirstChild("BlueSpotifyGUI") then
                    pg.BlueSpotifyGUI:Destroy()
                end
            end
        end,
        Tooltip = "Search and play royalty-free music in a custom GUI"
    })
end)
local Ambience1

run(function()
	local lighting = game:GetService("Lighting")
	local Workspace = game:GetService("Workspace")
	local part

	local function getHighGround()
		local mag = -math.huge
		for _, pos in bedwars.BlockController:getStore():getAllBlockPositions() do
			pos = pos * 3
			if pos.Y > mag and not getPlacedBlock(pos + Vector3.new(0, 3, 0)) then
				mag = pos.Y
			end
		end
		return mag
	end

	Ambience1 = vape.Categories.Render:CreateModule({
		Name = "RainWare Sky",
		Function = function(enabled)
			if enabled then
				local sky = Instance.new("Sky")
				sky.Name = "Ambience 1"
				local id = "rbxassetid://116207594540740"
				sky.SkyboxBk = id
				sky.SkyboxDn = id
				sky.SkyboxFt = id
				sky.SkyboxLf = id
				sky.SkyboxRt = id
				sky.SkyboxUp = id
				sky.Parent = lighting

				local height = getHighGround()
				if height ~= -math.huge then
					part = Instance.new("Part")
					part.Name = "AmbienceSnow"
					part.Size = Vector3.new(500, 1, 500)
					part.Anchored = true
					part.CanCollide = false
					part.Transparency = 1
					part.Position = Vector3.new(0, height + 10, 0)
					part.Parent = Workspace

					local snow = Instance.new("ParticleEmitter")
					snow.Texture = "http://www.roblox.com/asset/?id=558200857"
					snow.Rate = 250
					snow.Lifetime = NumberRange.new(6, 10)
					snow.Speed = NumberRange.new(1, 2)
					snow.VelocitySpread = 360
					snow.Size = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0.2),
						NumberSequenceKeypoint.new(1, 0.35)
					})
					snow.Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0.3),
						NumberSequenceKeypoint.new(1, 0.5)
					})
					snow.LightInfluence = 0.1
					snow.Rotation = NumberRange.new(0, 180)
					snow.RotSpeed = NumberRange.new(-10, 10)
					snow.SpreadAngle = Vector2.new(20, 20)
					snow.Acceleration = Vector3.new(0, -1, 0)
					snow.Parent = part
				end
			else
				local sky = lighting:FindFirstChild("Ambience 1")
				if sky then sky:Destroy() end
				if part and part.Parent then
					part:Destroy()
					part = nil
				end
			end
		end,
		Tooltip = "RainWare Sky"
	})
end)

local Ambience2
run(function()
	local lighting = game:GetService("Lighting")

	Ambience2 = vape.Categories.Render:CreateModule({
		Name = "Xylex Sky",
  Function = function(enabled)
			if enabled then
				local sky = Instance.new("Sky")
				sky.Name = "Ambience 1"
				local id = "rbxassetid://13953598788"
				sky.SkyboxBk = id
				sky.SkyboxDn = id
				sky.SkyboxFt = id
				sky.SkyboxLf = id
				sky.SkyboxRt = id
				sky.SkyboxUp = id
				sky.Parent = lighting
			else
				local sky = lighting:FindFirstChild("Ambience 1")
				if sky then sky:Destroy() end
			end
		end,
		Tooltip = "Xylex Sky"
	})
end)
local ClearChat
run(function()
    local player = game.Players.LocalPlayer

    ClearChat = vape.Categories.Utility:CreateModule({
        Name = "Clear Chat",
        Tooltip = "Fills the chat with blank lines to push old messages off screen",
        Function = function(enabled)
            if enabled then
                local function chat(msg)
                    if game:GetService("TextChatService").ChatVersion == Enum.ChatVersion.TextChatService then
                        game:GetService("TextChatService").TextChannels.RBXGeneral:SendAsync(msg)
                    else
                        game.ReplicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(msg, "All")
                    end
                end

                -- Prepare shorter blank messages that respect the chat character limit
                local blankLine = "\u{000D} "
                local segment = "" .. string.rep(blankLine, 40) .. ""

                -- Send multiple smaller messages
                for i = 1, 3 do
                    chat(segment)
                    task.wait(0.2)
                end
            end
        end
    })
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
local namecall; namecall = hookmetamethod(game, '__namecall', function(self, ...)
	if getnamecallmethod() == 'FireServer' and tostring(self) == 'GroundHit' and NoFall.Enabled then
		local args = {...}
		if args[3] then
			args[3] = 1/1
		end
		return namecall(self, unpack(args))
	end
	return namecall(self, ...)
end)
run(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LocalPlayer = Players.LocalPlayer
    local jumpConn
    local jumpEnabled = false
    local range = 15 -- distance to trigger jump

    -- Utility to check if a player is a teammate (BedWars team system)
    local function isEnemy(otherPlayer)
        if not otherPlayer or not LocalPlayer then return false end
        local myTeam = LocalPlayer:GetAttribute("Team")
        local theirTeam = otherPlayer:GetAttribute("Team")
        return myTeam and theirTeam and myTeam ~= theirTeam
    end

    local function startJumpLoop(character)
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then
            character:WaitForChild("Humanoid")
            humanoid = character:FindFirstChildOfClass("Humanoid")
        end

        if jumpConn then jumpConn:Disconnect() end

        jumpConn = RunService.RenderStepped:Connect(function()
            if not jumpEnabled or not humanoid or not humanoid.Parent then return end

            local rootPart = character:FindFirstChild("HumanoidRootPart")
            if not rootPart then return end

            for _, otherPlayer in pairs(Players:GetPlayers()) do
                if otherPlayer ~= LocalPlayer and isEnemy(otherPlayer) then
                    local otherChar = otherPlayer.Character
                    if otherChar and otherChar:FindFirstChild("HumanoidRootPart") then
                        local distance = (rootPart.Position - otherChar.HumanoidRootPart.Position).Magnitude
                        if distance <= range then
                            if humanoid:GetState() == Enum.HumanoidStateType.Running then
                                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                break
                            end
                        end
                    end
                end
            end
        end)
    end

    WalkJump = vape.Categories.Blatant:CreateModule({
        Name = 'AutoJump',
        Function = function(callback)
            jumpEnabled = callback

            if callback then
                local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                vape:CreateNotification('WalkJump Enabled', 'Jump near enemy activated.', 4)
                startJumpLoop(character)
            else
                if jumpConn then
                    jumpConn:Disconnect()
                    jumpConn = nil
                end
            end
        end,
        Default = false,
        Tooltip = 'Jump when close to an enemy'
    })

    LocalPlayer.CharacterAdded:Connect(function(character)
        character:WaitForChild("Humanoid")
        task.wait(0.2)

        -- Restart jump loop if module is still enabled
        if jumpEnabled then
            startJumpLoop(character)
        end
    end)
end)																																																																																									run(function()
        local GameRain: table = {["Enabled"] = false}
        local RainParts: {BasePart} = {}
        local RainSound: Sound? = nil
        local Roof: (cframe: CFrame) -> Part? = function(cframe: CFrame): Part?
                return workspace:FindPartOnRayWithIgnoreList(
                        Ray.new(cframe.p, Vector3.new(0, 150, 0)),
                        {lplr.Character}
                );
        end;

        local Particle: (cframe: CFrame) -> () = function(cframe: CFrame): ()
                local Spread: Vector3 = Vector3.new(
                        math.random(-100, 100),
                        math.random(-100, 100),
                        math.random(-100, 100)
                );
                local Part: Part = Instance.new("Part");
                Part.Anchored = false;
                Part.CanCollide = false;
                Part.Transparency = 0.25;
                Part.Reflectance = 0.15;
                Part.Size = Vector3.new(0.15, 2, 0.15);
                Part.BrickColor = BrickColor.new("Steel blue");
                Part.FormFactor = Enum.FormFactor.Custom;
                Part.CFrame = CFrame.new(
                        cframe.p + (cframe:VectorToWorldSpace(Vector3.new(0, 1, 0)).Unit * 150) + Spread
                ) * CFrame.Angles(0, math.atan2(cframe.p.X, cframe.p.Z) + math.pi, 0);
                local Smoke: Smoke = Instance.new("Smoke", Part);
                Smoke.RiseVelocity = -25;
                Smoke.Opacity = 0.25;
                Smoke.Size = 25;
                Instance.new("BlockMesh", Part)
                Part.Touched:Connect(function()
                        if Part then Part:Destroy(); end;
                end);
                Part.Parent = gameCamera;
                table.insert(RainParts, Part);
                game:GetService("Debris"):AddItem(Part, 3);
        end;
        GameRain = vape.Categories.Render:CreateModule({
                ["Name"] = "Rain",
                ["HoverText"] = "Enables rain effect.",
                ["Function"] = function(callback: boolean): void
                        if callback then
                                GameRain["Enabled"] = true
                                task.spawn(function()
                                        local character: Model = lplr.Character or lplr.CharacterAdded:Wait();
                                        if not character then return; end;
                                        local torso: BasePart = character:WaitForChild("UpperTorso", 10);
                                        if not torso then return; end;
                                        RainSound = Instance.new("Sound", gameCamera);
                                        RainSound.SoundId = "http://www.roblox.com/asset/?ID=236148388";
                                        RainSound.Looped = true;
                                        RainSound.Volume = 0.03;
                                        RainSound:Play();
                                        while GameRain["Enabled"] do
                                                task.wait(0.13)
                                                if Roof(torso.CFrame) == nil then
                                                        for _ = 1, 5 do
                                                                if (gameCamera.CFrame.p - torso.CFrame.p).Magnitude > 100 then
                                                                        Particle(gameCamera.CFrame);
                                                                        Particle(torso.CFrame);
                                                                else
                                                                        Particle(torso.CFrame);
                                                                end;
                                                        end;
                                                else
                                                        if Roof(gameCamera.CFrame) == nil then
                                                                for _ = 1, 5 do
                                                                        Particle(gameCamera.CFrame);
                                                                end;
                                                        end;
                                                end;
                                        end;
                                        if RainSound then
                                                RainSound:Stop();
                                                RainSound:Destroy();
                                                RainSound = nil;
                                        end;
                                        for _, part: BasePart in pairs(RainParts) do
                                                if part and part:IsDescendantOf(workspace) then
                                                        part:Destroy();
                                                end;
                                        end;
                                        table.clear(RainParts);
                                end);
                        end;
                end;
        });
end)
-- bedwars uses the new chat sys gng 🙏
run(function()
    local AutoCorrect
    local blacklistedwords = {
        'hack',
        'hax',
        'cheat'
    }

    local function getWord(msg)
        for i,v in blacklistedwords do
            if string.find(tostring(msg), v) then
                return true
            end
        end

        return false
    end

    local function sendmsg(msg)
        if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(msg)
        else
            replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(msg, 'All')
        end
    end

    AutoCorrect = vape.Categories.Utility:CreateModule({
        Name = 'AutoCorrect',
        Function = function(callback)
            if callback then
                for i,v in playersService:GetPlayers() do
                    if v ~= lplr then
                        AutoCorrect:Clean(v.Chatted:Connect(function(msg)
                            if getWord(msg) then
                                sendmsg('Actually, '..v.Name..' it\'s called "Exploiters/Exploits".')
                            end
                        end))
                    end
                end
            end
        end,
        Tooltip = 'Automatically corrects someone for using the incorrect terminology.'
    })
end)
run(function()
    local MelodyExploit
    MelodyExploit = vape.Categories.Utility:CreateModule({
        Name = 'MelodyExploit',
        Function = function(callback)
            if callback then
                repeat
                    if entitylib.isAlive and getItem('guitar') then
                        bedwars.Client:Get(remotes.GuitarHeal):SendToServer({
                            healTarget = lplr.Character
                        })
                    end
                    task.wait()
                until not MelodyExploit.Enabled
            end
        end,
        Tooltip = 'Acts like a god-mode with the Melody kit'
    })
end)
run(function()
	local a = {Enabled = false}
	a = vape.Categories.World:CreateModule({
		Name = "Leave Party",
		Function = function(call)
			if call then
				a:Toggle(false)
				game:GetService("ReplicatedStorage"):WaitForChild("events-@easy-games/lobby:shared/event/lobby-events@getEvents.Events"):WaitForChild("leaveParty"):FireServer()
			end
		end
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
run(function()
    local savedLightingSettings = {}
    local savedEffects = {}
    local savedParts = {}

    FPSBoostPlus = vape.Categories.Utility:CreateModule({
        Name = 'FPSBoostPremium',
        Function = function(enabled)
            local Players = game:GetService("Players")
            local Workspace = game:GetService("Workspace")
            local Lighting = game:GetService("Lighting")
            local gray = Color3.fromRGB(90, 90, 90)

            local function isPlayerCharacter(instance)
                for _, player in ipairs(Players:GetPlayers()) do
                    if player.Character and instance:IsDescendantOf(player.Character) then
                        return true
                    end
                end
                return false
            end

            if enabled then
                savedLightingSettings = {
                    FogStart = Lighting.FogStart,
                    FogEnd = Lighting.FogEnd,
                    FogColor = Lighting.FogColor,
                    GlobalShadows = Lighting.GlobalShadows,
                    Brightness = Lighting.Brightness
                }

                for _, effect in ipairs(Lighting:GetChildren()) do
                    if effect:IsA("PostEffect") or effect:IsA("BloomEffect") or effect:IsA("ColorCorrectionEffect") or effect:IsA("SunRaysEffect") or effect:IsA("DepthOfFieldEffect") or effect:IsA("BlurEffect") then
                        savedEffects[effect] = effect.Enabled
                        effect.Enabled = false
                    end
                end

                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if not isPlayerCharacter(obj) then
                        if obj:IsA("BasePart") or obj:IsA("UnionOperation") or obj:IsA("CornerWedgePart") or obj:IsA("TrussPart") or obj:IsA("MeshPart") then
                            savedParts[obj] = {
                                Material = obj.Material,
                                Color = obj.Color,
                                Reflectance = obj.Reflectance,
                                TextureID = obj:IsA("MeshPart") and obj.TextureID or nil
                            }
                            obj.Material = Enum.Material.Air
                            obj.Color = gray
                            obj.Reflectance = 0
                            if obj:IsA("MeshPart") then
                                obj.TextureID = ""
                            end
                        elseif obj:IsA("Decal") or obj:IsA("Texture") then
                            obj:Destroy()
                        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
                            obj.Lifetime = NumberRange.new(0)
                        elseif obj:IsA("Fire") or obj:IsA("SpotLight") or obj:IsA("Smoke") then
                            obj.Enabled = false
                        end
                    end
                end

                Lighting.FogStart = 1e10
                Lighting.FogEnd = 1e10
                Lighting.FogColor = Color3.new(1, 1, 1)
                Lighting.GlobalShadows = false
                Lighting.Brightness = 0
            else
                for obj, data in pairs(savedParts) do
                    if obj and obj.Parent then
                        obj.Material = data.Material
                        obj.Color = data.Color
                        obj.Reflectance = data.Reflectance
                        if obj:IsA("MeshPart") and data.TextureID then
                            obj.TextureID = data.TextureID
                        end
                    end
                end

                for effect, wasEnabled in pairs(savedEffects) do
                    if effect and effect.Parent then
                        effect.Enabled = wasEnabled
                    end
                end

                Lighting.FogStart = savedLightingSettings.FogStart or 0
                Lighting.FogEnd = savedLightingSettings.FogEnd or 100000
                Lighting.FogColor = savedLightingSettings.FogColor or Color3.new(1, 1, 1)
                Lighting.GlobalShadows = savedLightingSettings.GlobalShadows or true
                Lighting.Brightness = savedLightingSettings.Brightness or 1
            end
        end,
        Default = false,
        Tooltip = "Boosts Your Game With High Fps"
    })
end)
run(function()
  local texturepack = {Enabled = false}
  local packDropdown = {Value = "Melo Pack"}

  local ogpackloader = game:GetObjects("rbxassetid://14027120450")
  local ogtxtpack = ogpackloader[1]
  ogtxtpack.Name = "OG Pack"
  ogtxtpack.Parent = replicatedStorage
  task.wait()
  local melopackloader = game:GetObjects("rbxassetid://14774202839")
  local melotxtpack = melopackloader[1]
  melotxtpack.Name = "Melo's Pack"
  melotxtpack.Parent = replicatedStorage
  task.wait()
  local azzapackloader = game:GetObjects("rbxassetid://14803122185")
  local azzatxtpack = azzapackloader[1]
  azzatxtpack.Name = "4zze's Pack"
  azzatxtpack.Parent = replicatedStorage
  local viewmodelCon
  local textures = {
    ["OG Pack"] = ogtxtpack,
    ["Melo's Pack"] = melotxtpack,
    ["4zze's Pack"] = azzatxtpack
  }

  local function refreshViewmodel(child)
    if not entitylib.character then return end
    for _,v1 in textures[packDropdown.Value]:GetChildren() do
      if not (string.lower(v1.Name) == child.Name and child.Parent.Name ~= child.Name) then continue end
      -- first person viewmodel check
      for _,v2 in child:GetDescendants() do
        if v2:IsA("Part") or v2:IsA("MeshPart") then
          v2.Transparency = 1
        end
      end
      -- third person viewmodel check
      for _,v2 in lplr.Character:GetChildren() do
        if v2.Name == string.lower(v1.Name) then
          for _,v3 in v2:GetDescendants() do
            if v3.Name ~= child.Name then
              if v3:IsA("Part") or v3:IsA("MeshPart") then
                v3.Transparency = 1
                v3:GetPropertyChangedSignal("Transparency"):Connect(function() v3.Transparency = 1 end)
              end
            end
          end
        end
      end
      -- first person txtpack renderer
      local vmmodel = v1:Clone()
      vmmodel.CFrame = child.Handle.CFrame 
      vmmodel.CFrame = vmmodel.CFrame * (packDropdown.Value == "OG Pack" and CFrame.new(0, -0.2, 0) or packDropdown.Value == "Melo's Pack" and CFrame.new(0.2, -0.2, 0) or packDropdown.Value == "4zze's Pack" and CFrame.new(0.8,0.1,0.7)) * CFrame.Angles(math.rad(90),math.rad(-130),math.rad(0))
      if string.lower(child.Name) == "rageblade" then vmmodel.CFrame = vmmodel.CFrame * CFrame.Angles(math.rad(-180),math.rad(100),math.rad(0)) end
      if string.lower(child.Name):find("pickaxe") then vmmodel.CFrame = vmmodel.CFrame * CFrame.Angles(math.rad(-55),math.rad(-30),math.rad(50)) end
      if string.lower(child.Name):find("scythe") then vmmodel.CFrame = vmmodel.CFrame * CFrame.Angles(math.rad(-65),math.rad(-80),math.rad(100)) * CFrame.new(-2.8,0.4,-0.8) end
      if (string.lower(child.Name):find("axe")) and not (string.lower(child.Name):find("pickaxe")) then vmmodel.CFrame = vmmodel.CFrame * CFrame.Angles(math.rad(-55),math.rad(-30),math.rad(50)) * (packDropdown.Value == "Melo's Pack" and CFrame.new(-0.2,0,0.2) or packDropdown.Value == "4zze's Pack" and CFrame.new(-1.5,0,-0.8)) end
      vmmodel.Parent = child
      local vmmodelweld = Instance.new("WeldConstraint",vmmodel)
      vmmodelweld.Part0 = vmmodelweld.Parent
      vmmodelweld.Part1 = child.Handle
      -- third person txtpack renderer
      local charmodel = v1:Clone()
      charmodel.CFrame = playersService.LocalPlayer.Character[child.Name]:FindFirstChild("Handle").CFrame
      charmodel.CFrame = charmodel.CFrame * (packDropdown.Value == "OG Pack" and CFrame.new(0, -0.5, 0) or packDropdown.Value == "Melo's Pack" and CFrame.new(0.2, -0.9, 0) or packDropdown.Value == "4zze's Pack" and CFrame.new(0.1,-1.2,0)) * CFrame.Angles(math.rad(90),math.rad(-130),math.rad(0))
      if string.lower(child.Name) == "rageblade" then charmodel.CFrame = charmodel.CFrame * CFrame.Angles(math.rad(-180),math.rad(100),math.rad(0)) * CFrame.new(0.8,0,-1.1) end
      if string.lower(child.Name):find("pickaxe") then charmodel.CFrame = charmodel.CFrame * CFrame.Angles(math.rad(-55),math.rad(-30),math.rad(50)) * CFrame.new(-0.8,-0.2,1.1) end
      if string.lower(child.Name):find("scythe") then charmodel.CFrame = charmodel.CFrame * CFrame.Angles(math.rad(-65),math.rad(-80),math.rad(100)) * CFrame.new(-1.8,-0.5,0) end
      if (string.lower(child.Name):find("axe")) and not (string.lower(child.Name):find("pickaxe")) then charmodel.CFrame = charmodel.CFrame * CFrame.Angles(math.rad(-55),math.rad(-30),math.rad(50)) * CFrame.new(-1.4,-0.2,0.6) end
      charmodel.Anchored = false
      charmodel.CanCollide = false
      charmodel.Parent = playersService.LocalPlayer.Character[child.Name]
      local charmodelweld = Instance.new("WeldConstraint",charmodel)
      charmodelweld.Part0 = charmodelweld.Parent
      charmodelweld.Part1 = playersService.LocalPlayer.Character[child.Name].Handle
    end
  end

  texturepack = vape.Categories.Render:CreateModule({
    Name = "TexturePack",
    HoverText = "Modifies your renderer",
    Function = function(callback)
      if callback then
        if gameCamera.Viewmodel:FindFirstChildWhichIsA("Accessory") then refreshViewmodel(gameCamera.Viewmodel:FindFirstChildWhichIsA("Accessory")) end
        viewmodelCon = gameCamera.Viewmodel.ChildAdded:Connect(refreshViewmodel)
      else
        if viewmodelCon then pcall(function() viewmodelCon:Disconnect() end) end
      end
    end,
    ExtraText = function() return packDropdown.Value end
    })
  packDropdown = texturepack:CreateDropdown({
    Name = "Texture",
    List = {"OG Pack","Melo's Pack","4zze's Pack"},
    Function = function() end
  })
end)

run(function()
  local TexturePacks = {["Enabled"] = false}
  local packselected = {["Value"] = "OldBedwars"}

	local toolFunction = function() end
	local con

	local packfunctions = {
		SeventhPack = function() 
			task.spawn(function()
				local Players = game:GetService("Players")
				local ReplicatedStorage = game:GetService("ReplicatedStorage")
				local Workspace = game:GetService("Workspace")
				local objs = game:GetObjects("rbxassetid://14033898270")
				local import = objs[1]
				import.Parent = ReplicatedStorage
				local index = {
					{
						name = "wood_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
						model = import:WaitForChild("Wood_Sword"),
					},	
					{
						name = "stone_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
						model = import:WaitForChild("Stone_Sword"),
					},
					{
						name = "iron_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
						model = import:WaitForChild("Iron_Sword"),
					},
					{
						name = "diamond_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
						model = import:WaitForChild("Diamond_Sword"),
					},
					{
						name = "emerald_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
						model = import:WaitForChild("Emerald_Sword"),
					},
					{
						name = "wood_pickaxe",
						offset = CFrame.Angles(math.rad(0), math.rad(-190), math.rad(-95)),
						model = import:WaitForChild("Wood_Pickaxe"),
					},
					{
						name = "stone_pickaxe",
						offset = CFrame.Angles(math.rad(0), math.rad(-190), math.rad(-95)),
						model = import:WaitForChild("Stone_Pickaxe"),
					},
					{
						name = "iron_pickaxe",
						offset = CFrame.Angles(math.rad(0), math.rad(-190), math.rad(-95)),
						model = import:WaitForChild("Iron_Pickaxe"),
					},
					{
						name = "diamond_pickaxe",
						offset = CFrame.Angles(math.rad(0), math.rad(80), math.rad(-95)),
						model = import:WaitForChild("Diamond_Pickaxe"),
					},	
					{
						name = "wood_axe",
						offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
						model = import:WaitForChild("Wood_Axe"),
					},	
					{
						name = "stone_axe",
						offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
						model = import:WaitForChild("Stone_Axe"),
					},	
					{
						name = "iron_axe",
						offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
						model = import:WaitForChild("Iron_Axe"),
					},	
					{
						name = "diamond_axe",
						offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(-95)),
						model = import:WaitForChild("Diamond_Axe"),
					},	
					{
						name = "fireball",
						offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
						model = import:WaitForChild("Fireball"),
					},	
					{
						name = "telepearl",
						offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
						model = import:WaitForChild("Telepearl"),
					},
				}
				toolFunction = function(tool)	
					if not tool:IsA("Accessory") then return end	
					for _, v in ipairs(index) do	
						if v.name == tool.Name then		
							for _, part in ipairs(tool:GetDescendants()) do
								if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then				
									part.Transparency = 1
								end			
							end		
							local model = v.model:Clone()
							model.CFrame = tool:WaitForChild("Handle").CFrame * v.offset
							model.CFrame *= CFrame.Angles(math.rad(0), math.rad(-50), math.rad(0))
							model.Parent = tool			
							local weld = Instance.new("WeldConstraint", model)
							weld.Part0 = model
							weld.Part1 = tool:WaitForChild("Handle")			
							local tool2 = Players.LocalPlayer.Character:WaitForChild(tool.Name)			
							for _, part in ipairs(tool2:GetDescendants()) do
								if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then				
									part.Transparency = 1				
								end			
							end			
							local model2 = v.model:Clone()
							model2.Anchored = false
							model2.CFrame = tool2:WaitForChild("Handle").CFrame * v.offset
							model2.CFrame *= CFrame.Angles(math.rad(0), math.rad(-50), math.rad(0))
							if v.name:match("sword") or v.name:match("blade") then
								model2.CFrame *= CFrame.new(.5, 0, -1.1) - Vector3.new(0, 0, -.3)
							elseif v.name:match("axe") and not v.name:match("pickaxe") and v.name:match("diamond") then
								model2.CFrame *= CFrame.new(.08, 0, -1.1) - Vector3.new(0, 0, -.9)
							elseif v.name:match("axe") and not v.name:match("pickaxe") and not v.name:match("diamond") then
								model2.CFrame *= CFrame.new(-.2, 0, -2.4) + Vector3.new(0, 0, 2.12)
							else
								model2.CFrame *= CFrame.new(.2, 0, -.09)
							end
							model2.Parent = tool2
							local weld2 = Instance.new("WeldConstraint", model)
							weld2.Part0 = model2
							weld2.Part1 = tool2:WaitForChild("Handle")
						end
					end
				end
			end)
		end,
		EighthPack = function() 
			task.spawn(function()
				local Players = game:GetService("Players")
				local ReplicatedStorage = game:GetService("ReplicatedStorage")
				local Workspace = game:GetService("Workspace")
				local objs = game:GetObjects("rbxassetid://14078540433")
				local import = objs[1]
				import.Parent = game:GetService("ReplicatedStorage")
				index = {
					{
						name = "wood_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Wood_Sword"),
					},
					{
						name = "stone_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Stone_Sword"),
					},
					{
						name = "iron_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Iron_Sword"),
					},
					{
						name = "diamond_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Diamond_Sword"),
					},
					{
						name = "emerald_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Emerald_Sword"),
					},
					{
						name = "rageblade",
						offset = CFrame.Angles(math.rad(0),math.rad(-90),math.rad(90)),
						model = import:WaitForChild("Rageblade"),
					}, 
				}
				toolFunction = function(tool)
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
							local tool2 = Players.LocalPlayer.Character:WaitForChild(tool.Name)
							for i,v in pairs(tool2:GetDescendants()) do
								if(v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation")) then
									v.Transparency = 1
								end
							end
							local model2 = v.model:Clone()
							model2.Anchored = false
							model2.CFrame = tool2:WaitForChild("Handle").CFrame * v.offset
							model2.CFrame *= CFrame.Angles(math.rad(0),math.rad(-50),math.rad(0))
							model2.CFrame *= CFrame.new(.5,0,-.8)
							model2.Parent = tool2
							local weld2 = Instance.new("WeldConstraint",model)
							weld2.Part0 = model2
							weld2.Part1 = tool2:WaitForChild("Handle")
						end
					end
				end
			end)
		end,
		SixthPack = function() 
			task.spawn(function()
				local Players = game:GetService("Players")
				local ReplicatedStorage = game:GetService("ReplicatedStorage")
				local Workspace = game:GetService("Workspace")

				local objs = game:GetObjects("rbxassetid://13780890894")
				local import = objs[1]
				import.Parent = ReplicatedStorage
				
				local swordIndex = {
					{
						name = "wood_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
						model = import:WaitForChild("Wood_Sword"),
					},
					{
						name = "stone_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
						model = import:WaitForChild("Stone_Sword"),
					},
					{
						name = "iron_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
						model = import:WaitForChild("Iron_Sword"),
					},
					{
						name = "diamond_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
						model = import:WaitForChild("Diamond_Sword"),
					},
					{
						name = "emerald_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
						model = import:WaitForChild("Emerald_Sword"),
					},
				}
				
				local pickaxeIndex = {
					{
						name = "wood_pickaxe",
						offset = CFrame.Angles(math.rad(0), math.rad(-190), math.rad(-95)),
						model = import:WaitForChild("Wood_Pickaxe"),
					},
					{
						name = "stone_pickaxe",
						offset = CFrame.Angles(math.rad(0), math.rad(-190), math.rad(-95)),
						model = import:WaitForChild("Stone_Pickaxe"),
					},
					{
						name = "iron_pickaxe",
						offset = CFrame.Angles(math.rad(0), math.rad(-190), math.rad(-95)),
						model = import:WaitForChild("Iron_Pickaxe"),
					},
					{
						name = "diamond_pickaxe",
						offset = CFrame.Angles(math.rad(0), math.rad(80), math.rad(-95)),
						model = import:WaitForChild("Diamond_Pickaxe"),
					},
				}

				local swordFunction = function(tool)
					if not tool:IsA("Accessory") then
						return
					end
					
					for _, v in pairs(swordIndex) do
						if v.name == tool.Name then
							for _, v in pairs(tool:GetDescendants()) do
								if v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation") then
									v.Transparency = 1
								end
							end
							
							local model = v.model:Clone()
							model.CFrame = tool.Handle.CFrame * v.offset
							model.CFrame *= CFrame.Angles(math.rad(0), math.rad(-50), math.rad(0))
							model.Parent = tool
							
							local weld = Instance.new("WeldConstraint", model)
							weld.Part0 = model
							weld.Part1 = tool.Handle
							
							local tool2 = Players.LocalPlayer.Character[tool.Name]
							
							for _, v in pairs(tool2:GetDescendants()) do
								if v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation") then
									v.Transparency = 1
								end
							end
							
							local model2 = v.model:Clone()
							model2.Anchored = false
							model2.CFrame = tool2.Handle.CFrame * v.offset
							model2.CFrame *= CFrame.Angles(math.rad(0), math.rad(-50), math.rad(0))
							model2.CFrame *= CFrame.new(0.4, 0, -0.9)
							model2.Parent = tool2
							
							local weld2 = Instance.new("WeldConstraint", model)
							weld2.Part0 = model2
							weld2.Part1 = tool2.Handle
						end
					end
				end

				local pickaxeFunction = function(tool)
					if not tool:IsA("Accessory") then
						return
					end

					for _, v in pairs(pickaxeIndex) do
						if v.name == tool.Name then
							for _, v in pairs(tool:GetDescendants()) do
								if v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation") then
									v.Transparency = 1
								end
							end
							local model = v.model:Clone()
							model.CFrame = tool.Handle.CFrame * v.offset
							model.CFrame *= CFrame.Angles(math.rad(0), math.rad(-50), math.rad(0))
							model.Parent = tool
							local weld = Instance.new("WeldConstraint", model)
							weld.Part0 = model
							weld.Part1 = tool.Handle
							local tool2 = Players.LocalPlayer.Character[tool.Name]
							for _, v in pairs(tool2:GetDescendants()) do
								if v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation") then
									v.Transparency = 1
								end
							end
							local model2 = v.model:Clone()
							model2.Anchored = false
							model2.CFrame = tool2.Handle.CFrame * v.offset
							model2.CFrame *= CFrame.Angles(math.rad(0), math.rad(-50), math.rad(0))
							model2.CFrame *= CFrame.new(-0.2, 0, -0.08)
							model2.Parent = tool2
							local weld2 = Instance.new("WeldConstraint", model)
							weld2.Part0 = model2
							weld2.Part1 = tool2.Handle
						end
					end
				end

				toolFunction = function(tool)
					task.spawn(function() swordFunction(tool) end)
					task.spawn(function() pickaxeFunction(tool) end)
				end
			end)
		end,
		FifthPack = function() 
			task.spawn(function()
				local Players = game:GetService("Players")
				local ReplicatedStorage = game:GetService("ReplicatedStorage")
				local Workspace = game:GetService("Workspace")
				
				local objs = game:GetObjects("rbxassetid://13802020264")
				local import = objs[1]
				
				import.Parent = game:GetService("ReplicatedStorage")
				
				index = {
					{
						name = "wood_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Wood_Sword"),
					},
					
					{
						name = "stone_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Stone_Sword"),
					},
					
					{
						name = "iron_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Iron_Sword"),
					},
					
					{
						name = "diamond_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Diamond_Sword"),
					},
					
					{
						name = "emerald_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Emerald_Sword"),
					},
					
					
				}
				
				toolFunction = function(tool)
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
							
							local tool2 = Players.LocalPlayer.Character:WaitForChild(tool.Name)
							
							for i,v in pairs(tool2:GetDescendants()) do
								if(v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation")) then
									v.Transparency = 1
								end
							end
							
							local model2 = v.model:Clone()
							model2.Anchored = false
							model2.CFrame = tool2:WaitForChild("Handle").CFrame * v.offset
							model2.CFrame *= CFrame.Angles(math.rad(0),math.rad(-50),math.rad(0))
							model2.CFrame *= CFrame.new(0.8,0,-.9)
							model2.Parent = tool2
							
							local weld2 = Instance.new("WeldConstraint",model)
							weld2.Part0 = model2
							weld2.Part1 = tool2:WaitForChild("Handle")			
						end
					end
				end
			end)
		end,
		FourthPack = function() 
			task.spawn(function()
				local Players = game:GetService("Players")
				local ReplicatedStorage = game:GetService("ReplicatedStorage")
				local Workspace = game:GetService("Workspace")
				
				local objs = game:GetObjects("rbxassetid://13801509384")
				local import = objs[1]
				
				import.Parent = game:GetService("ReplicatedStorage")
				
				index = {
				
					{
						name = "wood_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Wood_Sword"),
					},
					
					{
						name = "stone_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Stone_Sword"),
					},
					
					{
						name = "iron_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Iron_Sword"),
					},
					
					{
						name = "diamond_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Diamond_Sword"),
					},
					
					{
						name = "emerald_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Emerald_Sword"),
					},
					
					{
						name = "rageblade",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-270)),
						model = import:WaitForChild("Rageblade"),
					},
					
					
				}

				toolFunction = function(tool)
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
							
							local tool2 = Players.LocalPlayer.Character:WaitForChild(tool.Name)
							
							for i,v in pairs(tool2:GetDescendants()) do
								if(v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation")) then	
									v.Transparency = 1	
								end	
							end

							local model2 = v.model:Clone()
							model2.Anchored = false
							model2.CFrame = tool2:WaitForChild("Handle").CFrame * v.offset
							model2.CFrame *= CFrame.Angles(math.rad(0),math.rad(-50),math.rad(0))
							model2.CFrame *= CFrame.new(0.4,0,-.9)
							model2.Parent = tool2
							
							local weld2 = Instance.new("WeldConstraint",model)
							weld2.Part0 = model2
							weld2.Part1 = tool2:WaitForChild("Handle")					
						end
					end
				end
			end)
		end,
		SecondPack = function() 
			task.spawn(function()
				local Players = game:GetService("Players")
				local ReplicatedStorage = game:GetService("ReplicatedStorage")
				local Workspace = game:GetService("Workspace")
				local objs = game:GetObjects("rbxassetid://13801616054")
				local import = objs[1]
				import.Parent = game:GetService("ReplicatedStorage")
				index = {
					{
						name = "wood_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(100),math.rad(-90)),
						model = import:WaitForChild("Wood_Sword"),
					},
					
					{
						name = "stone_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(100),math.rad(-90)),
						model = import:WaitForChild("Stone_Sword"),
					},
					
					{
						name = "iron_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(100),math.rad(-90)),
						model = import:WaitForChild("Iron_Sword"),
					},
					
					{
						name = "diamond_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(100),math.rad(-90)),
						model = import:WaitForChild("Diamond_Sword"),
					},
					
					{
						name = "emerald_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(100),math.rad(-90)),
						model = import:WaitForChild("Emerald_Sword"),
					},
					
					{
						name = "rageblade",
						offset = CFrame.Angles(math.rad(0),math.rad(100),math.rad(-270)),
						model = import:WaitForChild("Rageblade"),
					},
					
					
				}

				toolFunction = function(tool)
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
							
							local tool2 = Players.LocalPlayer.Character:WaitForChild(tool.Name)
							
							for i,v in pairs(tool2:GetDescendants()) do
								if(v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation")) then
									v.Transparency = 1
								end
							end
							
							local model2 = v.model:Clone()
							model2.Anchored = false
							model2.CFrame = tool2:WaitForChild("Handle").CFrame * v.offset
							model2.CFrame *= CFrame.Angles(math.rad(0),math.rad(-50),math.rad(0))
							model2.CFrame *= CFrame.new(0.8,0,-.9)
							model2.Parent = tool2
							
							local weld2 = Instance.new("WeldConstraint",model)
							weld2.Part0 = model2
							weld2.Part1 = tool2:WaitForChild("Handle")
						end
					end
				end
			end)
		end,
		FirstPack = function() 
			task.spawn(function()
				local Players = game:GetService("Players")
				local ReplicatedStorage = game:GetService("ReplicatedStorage")
				local Workspace = game:GetService("Workspace")
				local objs = game:GetObjects("rbxassetid://13783192680")
				local import = objs[1]
				import.Parent = game:GetService("ReplicatedStorage")
				index = {
					{
						name = "wood_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Wood_Sword"),
					},
					
					{
						name = "stone_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Stone_Sword"),
					},
					
					{
						name = "iron_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Iron_Sword"),
					},
					
					{
						name = "diamond_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Diamond_Sword"),
					},
					
					{
						name = "emerald_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Emerald_Sword"),
					},
					
					
				}
				toolFunction = function(tool)
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
							
							local tool2 = Players.LocalPlayer.Character:WaitForChild(tool.Name)
							
							for i,v in pairs(tool2:GetDescendants()) do
								if(v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation")) then
									v.Transparency = 1
								end
							end
							
							local model2 = v.model:Clone()
							model2.Anchored = false
							model2.CFrame = tool2:WaitForChild("Handle").CFrame * v.offset
							model2.CFrame *= CFrame.Angles(math.rad(0),math.rad(-50),math.rad(0))
							model2.CFrame *= CFrame.new(0.4,0,-.9)
							model2.Parent = tool2
							
							local weld2 = Instance.new("WeldConstraint",model)
							weld2.Part0 = model2
							weld2.Part1 = tool2:WaitForChild("Handle")
						end
					end
				end
			end)
		end,
		CottonCandy = function() 
			task.spawn(function() 
				local Players = game:GetService("Players")
				local ReplicatedStorage = game:GetService("ReplicatedStorage")
				local Workspace = game:GetService("Workspace")
				local objs = game:GetObjects("rbxassetid://14161283331")
				local import = objs[1]
				import.Parent = ReplicatedStorage
				local index = {
					{
						name = "wood_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
						model = import:WaitForChild("Wood_Sword"),
					},	
					{
						name = "stone_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
						model = import:WaitForChild("Stone_Sword"),
					},
					{
						name = "iron_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
						model = import:WaitForChild("Iron_Sword"),
					},
					{
						name = "diamond_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
						model = import:WaitForChild("Diamond_Sword"),
					},
					{
						name = "emerald_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
						model = import:WaitForChild("Emerald_Sword"),
					},
					{
						name = "rageblade",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(90)),
						model = import:WaitForChild("Rageblade"),
					}, 
					{
						name = "wood_pickaxe",
						offset = CFrame.Angles(math.rad(0), math.rad(-180), math.rad(-95)),
						model = import:WaitForChild("Wood_Pickaxe"),
					},
					{
						name = "stone_pickaxe",
						offset = CFrame.Angles(math.rad(0), math.rad(-180), math.rad(-95)),
						model = import:WaitForChild("Stone_Pickaxe"),
					},
					{
						name = "iron_pickaxe",
						offset = CFrame.Angles(math.rad(0), math.rad(-18033), math.rad(-95)),
						model = import:WaitForChild("Iron_Pickaxe"),
					},
					{
						name = "diamond_pickaxe",
						offset = CFrame.Angles(math.rad(0), math.rad(80), math.rad(-95)),
						model = import:WaitForChild("Diamond_Pickaxe"),
					},	
					{
						name = "wood_axe",
						offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
						model = import:WaitForChild("Wood_Axe"),
					},	
					{
						name = "stone_axe",
						offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
						model = import:WaitForChild("Stone_Axe"),
					},	
					{
						name = "iron_axe",
						offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
						model = import:WaitForChild("Iron_Axe"),
					},	
					{
						name = "diamond_axe",
						offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-95)),
						model = import:WaitForChild("Diamond_Axe"),
					},	
					{
						name = "fireball",
						offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
						model = import:WaitForChild("Fireball"),
					},	
					{
						name = "telepearl",
						offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
						model = import:WaitForChild("Telepearl"),
					},
					{
						name = "diamond",
						offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
						model = import:WaitForChild("Diamond"),
					},
					{
						name = "iron",
						offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
						model = import:WaitForChild("Iron"),
					},
					{
						name = "gold",
						offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
						model = import:WaitForChild("Gold"),
					},
					{
						name = "emerald",
						offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
						model = import:WaitForChild("Emerald"),
					},
					{
						name = "wood_bow",
						offset = CFrame.Angles(math.rad(0), math.rad(0), math.rad(90)),
						model = import:WaitForChild("Bow"),
					},
					{
						name = "wood_crossbow",
						offset = CFrame.Angles(math.rad(0), math.rad(0), math.rad(90)),
						model = import:WaitForChild("Bow"),
					},
					{
						name = "tactical_crossbow",
						offset = CFrame.Angles(math.rad(0), math.rad(180), math.rad(-90)),
						model = import:WaitForChild("Bow"),
					},
				}
				toolFunction = function(tool)	
					if not tool:IsA("Accessory") then return end	
					for _, v in ipairs(index) do	
						if v.name == tool.Name then		
							for _, part in ipairs(tool:GetDescendants()) do
								if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then				
									part.Transparency = 1
								end			
							end		
							local model = v.model:Clone()
							model.CFrame = tool:WaitForChild("Handle").CFrame * v.offset
							model.CFrame *= CFrame.Angles(math.rad(0), math.rad(-50), math.rad(0))
							model.Parent = tool			
							local weld = Instance.new("WeldConstraint", model)
							weld.Part0 = model
							weld.Part1 = tool:WaitForChild("Handle")			
							local tool2 = Players.LocalPlayer.Character:WaitForChild(tool.Name)			
							for _, part in ipairs(tool2:GetDescendants()) do
								if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then				
									part.Transparency = 1				
								end			
							end			
							local model2 = v.model:Clone()
							model2.Anchored = false
							model2.CFrame = tool2:WaitForChild("Handle").CFrame * v.offset
							model2.CFrame *= CFrame.Angles(math.rad(0), math.rad(-50), math.rad(0))
							if v.name:match("rageblade") then
								model2.CFrame *= CFrame.new(0.7, 0, -1)                           
							elseif v.name:match("sword") or v.name:match("blade") then
								model2.CFrame *= CFrame.new(.6, 0, -1.1) - Vector3.new(0, 0, -.3)
							elseif v.name:match("axe") and not v.name:match("pickaxe") and v.name:match("diamond") then
								model2.CFrame *= CFrame.new(.08, 0, -1.1) - Vector3.new(0, 0, -1.1)
							elseif v.name:match("axe") and not v.name:match("pickaxe") and not v.name:match("diamond") then
								model2.CFrame *= CFrame.new(-.2, 0, -2.4) + Vector3.new(0, 0, 2.12)
							elseif v.name:match("iron") then
								model2.CFrame *= CFrame.new(0, -.24, 0)
							elseif v.name:match("gold") then
								model2.CFrame *= CFrame.new(0, .03, 0)
							elseif v.name:match("diamond") then
								model2.CFrame *= CFrame.new(0, .027, 0)
							elseif v.name:match("emerald") then
								model2.CFrame *= CFrame.new(0, .001, 0)
							elseif v.name:match("telepearl") then
								model2.CFrame *= CFrame.new(.1, 0, .1)
							elseif v.name:match("fireball") then
								model2.CFrame *= CFrame.new(.28, .1, 0)
							elseif v.name:match("bow") and not v.name:match("crossbow") then
								model2.CFrame *= CFrame.new(-.29, .1, -.2)
							elseif v.name:match("wood_crossbow") and not v.name:match("tactical_crossbow") then
								model2.CFrame *= CFrame.new(-.6, 0, 0)
							elseif v.name:match("tactical_crossbow") and not v.name:match("wood_crossbow") then
								model2.CFrame *= CFrame.new(-.5, 0, -1.2)
							else
								model2.CFrame *= CFrame.new(.2, 0, -.2)
							end
							model2.Parent = tool2
							local weld2 = Instance.new("WeldConstraint", model)
							weld2.Part0 = model2
							weld2.Part1 = tool2:WaitForChild("Handle")
						end
					end
				end   
			end)
		end,
		EgirlPack = function() 
			task.spawn(function() 	
				local Players = game:GetService("Players")
				local ReplicatedStorage = game:GetService("ReplicatedStorage")
				local Workspace = game:GetService("Workspace")
				local objs = game:GetObjects("rbxassetid://14126814481")
				local import = objs[1]
				import.Parent = game:GetService("ReplicatedStorage")
				index = {
					{
						name = "wood_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Wood_Sword"),
					},
					{
						name = "stone_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Stone_Sword"),
					},
					{
						name = "iron_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Iron_Sword"),
					},
					{
						name = "diamond_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Diamond_Sword"),
					},
					{
						name = "emerald_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Emerald_Sword"),
					},
					{
						name = "rageblade",
						offset = CFrame.Angles(math.rad(0),math.rad(-90),math.rad(90)),
						model = import:WaitForChild("Rageblade"),
					}, 
				}
				toolFunction = function(tool)
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
							local tool2 = Players.LocalPlayer.Character:WaitForChild(tool.Name)
							for i,v in pairs(tool2:GetDescendants()) do
								if(v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation")) then
									v.Transparency = 1
								end
							end
							local model2 = v.model:Clone()
							model2.Anchored = false
							model2.CFrame = tool2:WaitForChild("Handle").CFrame * v.offset
							model2.CFrame *= CFrame.Angles(math.rad(0),math.rad(-50),math.rad(0))
							model2.CFrame *= CFrame.new(.6,0,-1)
							model2.Parent = tool2
							local weld2 = Instance.new("WeldConstraint",model)
							weld2.Part0 = model2
							weld2.Part1 = tool2:WaitForChild("Handle")
						end
					end
				end             
			end)
		end,
		GlizzyPack = function() 
			task.spawn(function()
				local Players = game:GetService("Players")
				local ReplicatedStorage = game:GetService("ReplicatedStorage")
				local Workspace = game:GetService("Workspace")
				local objs = game:GetObjects("rbxassetid://13804645310")
				local import = objs[1]
				import.Parent = game:GetService("ReplicatedStorage")
				index = {
					{
						name = "wood_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Wood_Sword"),
					},
					{
						name = "stone_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Stone_Sword"),
					},
					{
						name = "iron_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Iron_Sword"),
					},
					{
						name = "diamond_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Diamond_Sword"),
					},
					{
						name = "emerald_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Emerald_Sword"),
					},
					{
						name = "rageblade",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-270)),
						model = import:WaitForChild("Rageblade"),
					},
				}
				toolFunction = function(tool)
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
							model.CFrame *= CFrame.Angles(math.rad(0),math.rad(100),math.rad(0))
							model.Parent = tool
							local weld = Instance.new("WeldConstraint",model)
							weld.Part0 = model
							weld.Part1 = tool:WaitForChild("Handle")
							local tool2 = Players.LocalPlayer.Character:WaitForChild(tool.Name)
							for i,v in pairs(tool2:GetDescendants()) do
								if(v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation")) then
									v.Transparency = 1
								end
							end
							local model2 = v.model:Clone()
							model2.Anchored = false
							model2.CFrame = tool2:WaitForChild("Handle").CFrame * v.offset
							model2.CFrame *= CFrame.Angles(math.rad(0),math.rad(-105),math.rad(0))
							model2.CFrame *= CFrame.new(-0.4,0,-0.10)
							model2.Parent = tool2
							local weld2 = Instance.new("WeldConstraint",model)
							weld2.Part0 = model2
							weld2.Part1 = tool2:WaitForChild("Handle")
						end
					end
				end
			end)
        end,
		PrivatePack = function() 
			task.spawn(function()
				local Players = game:GetService("Players")
				local ReplicatedStorage = game:GetService("ReplicatedStorage")
				local Workspace = game:GetService("Workspace")
				local objs = game:GetObjects("rbxassetid://14161283331")
				local import = objs[1]
				import.Parent = ReplicatedStorage
				local index = {
					{
						name = "wood_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
						model = import:WaitForChild("Wood_Sword"),
					},	
					{
						name = "stone_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
						model = import:WaitForChild("Stone_Sword"),
					},
					{
						name = "iron_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
						model = import:WaitForChild("Iron_Sword"),
					},
					{
						name = "diamond_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
						model = import:WaitForChild("Diamond_Sword"),
					},
					{
						name = "emerald_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
						model = import:WaitForChild("Emerald_Sword"),
					},
					{
						name = "rageblade",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(90)),
						model = import:WaitForChild("Rageblade"),
					}, 
					{
						name = "wood_pickaxe",
						offset = CFrame.Angles(math.rad(0), math.rad(-180), math.rad(-95)),
						model = import:WaitForChild("Wood_Pickaxe"),
					},
					{
						name = "stone_pickaxe",
						offset = CFrame.Angles(math.rad(0), math.rad(-180), math.rad(-95)),
						model = import:WaitForChild("Stone_Pickaxe"),
					},
					{
						name = "iron_pickaxe",
						offset = CFrame.Angles(math.rad(0), math.rad(-18033), math.rad(-95)),
						model = import:WaitForChild("Iron_Pickaxe"),
					},
					{
						name = "diamond_pickaxe",
						offset = CFrame.Angles(math.rad(0), math.rad(80), math.rad(-95)),
						model = import:WaitForChild("Diamond_Pickaxe"),
					},	
					{
						name = "wood_axe",
						offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
						model = import:WaitForChild("Wood_Axe"),
					},	
					{
						name = "stone_axe",
						offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
						model = import:WaitForChild("Stone_Axe"),
					},	
					{
						name = "iron_axe",
						offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
						model = import:WaitForChild("Iron_Axe"),
					},	
					{
						name = "diamond_axe",
						offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-95)),
						model = import:WaitForChild("Diamond_Axe"),
					},	
					{
						name = "fireball",
						offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
						model = import:WaitForChild("Fireball"),
					},	
					{
						name = "telepearl",
						offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
						model = import:WaitForChild("Telepearl"),
					},
					{
						name = "diamond",
						offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
						model = import:WaitForChild("Diamond"),
					},
					{
						name = "iron",
						offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
						model = import:WaitForChild("Iron"),
					},
					{
						name = "gold",
						offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
						model = import:WaitForChild("Gold"),
					},
					{
						name = "emerald",
						offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
						model = import:WaitForChild("Emerald"),
					},
					{
						name = "wood_bow",
						offset = CFrame.Angles(math.rad(0), math.rad(0), math.rad(90)),
						model = import:WaitForChild("Bow"),
					},
					{
						name = "wood_crossbow",
						offset = CFrame.Angles(math.rad(0), math.rad(0), math.rad(90)),
						model = import:WaitForChild("Bow"),
					},
					{
						name = "tactical_crossbow",
						offset = CFrame.Angles(math.rad(0), math.rad(180), math.rad(-90)),
						model = import:WaitForChild("Bow"),
					},
				}
				toolFunction = function(tool)	
					if not tool:IsA("Accessory") then return end	
					for _, v in ipairs(index) do	
						if v.name == tool.Name then		
							for _, part in ipairs(tool:GetDescendants()) do
								if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then				
									part.Transparency = 1
								end			
							end		
							local model = v.model:Clone()
							model.CFrame = tool:WaitForChild("Handle").CFrame * v.offset
							model.CFrame *= CFrame.Angles(math.rad(0), math.rad(-50), math.rad(0))
							model.Parent = tool			
							local weld = Instance.new("WeldConstraint", model)
							weld.Part0 = model
							weld.Part1 = tool:WaitForChild("Handle")			
							local tool2 = Players.LocalPlayer.Character:WaitForChild(tool.Name)			
							for _, part in ipairs(tool2:GetDescendants()) do
								if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then				
									part.Transparency = 1				
								end			
							end			
							local model2 = v.model:Clone()
							model2.Anchored = false
							model2.CFrame = tool2:WaitForChild("Handle").CFrame * v.offset
							model2.CFrame *= CFrame.Angles(math.rad(0), math.rad(-50), math.rad(0))
							if v.name:match("rageblade") then
								model2.CFrame *= CFrame.new(0.7, 0, -1)                           
							elseif v.name:match("sword") or v.name:match("blade") then
								model2.CFrame *= CFrame.new(.6, 0, -1.1) - Vector3.new(0, 0, -.3)
							elseif v.name:match("axe") and not v.name:match("pickaxe") and v.name:match("diamond") then
								model2.CFrame *= CFrame.new(.08, 0, -1.1) - Vector3.new(0, 0, -1.1)
							elseif v.name:match("axe") and not v.name:match("pickaxe") and not v.name:match("diamond") then
								model2.CFrame *= CFrame.new(-.2, 0, -2.4) + Vector3.new(0, 0, 2.12)
							elseif v.name:match("iron") then
								model2.CFrame *= CFrame.new(0, -.24, 0)
							elseif v.name:match("gold") then
								model2.CFrame *= CFrame.new(0, .03, 0)
							elseif v.name:match("diamond") then
								model2.CFrame *= CFrame.new(0, .027, 0)
							elseif v.name:match("emerald") then
								model2.CFrame *= CFrame.new(0, .001, 0)
							elseif v.name:match("telepearl") then
								model2.CFrame *= CFrame.new(.1, 0, .1)
							elseif v.name:match("fireball") then
								model2.CFrame *= CFrame.new(.28, .1, 0)
							elseif v.name:match("bow") and not v.name:match("crossbow") then
								model2.CFrame *= CFrame.new(-.29, .1, -.2)
							elseif v.name:match("wood_crossbow") and not v.name:match("tactical_crossbow") then
								model2.CFrame *= CFrame.new(-.6, 0, 0)
							elseif v.name:match("tactical_crossbow") and not v.name:match("wood_crossbow") then
								model2.CFrame *= CFrame.new(-.5, 0, -1.2)
							else
								model2.CFrame *= CFrame.new(.2, 0, -.2)
							end
							model2.Parent = tool2
							local weld2 = Instance.new("WeldConstraint", model)
							weld2.Part0 = model2
							weld2.Part1 = tool2:WaitForChild("Handle")
						end
					end
				end          
			end)
        end,
		DemonSlayerPack = function() 
			task.spawn(function()
				local Players = game:GetService("Players")
				local ReplicatedStorage = game:GetService("ReplicatedStorage")
				local Workspace = game:GetService("Workspace")
				local objs = game:GetObjects("rbxassetid://14241215869")
				local import = objs[1]
				import.Parent = ReplicatedStorage
				local index = {
					{
						name = "wood_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
						model = import:WaitForChild("Wood_Sword"),
					},	
					{
						name = "stone_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
						model = import:WaitForChild("Stone_Sword"),
					},
					{
						name = "iron_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
						model = import:WaitForChild("Iron_Sword"),
					},
					{
						name = "diamond_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
						model = import:WaitForChild("Diamond_Sword"),
					},
					{
						name = "emerald_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
						model = import:WaitForChild("Emerald_Sword"),
					},
					{
						name = "wood_pickaxe",
						offset = CFrame.Angles(math.rad(0), math.rad(-180), math.rad(-95)),
						model = import:WaitForChild("Wood_Pickaxe"),
					},
					{
						name = "stone_pickaxe",
						offset = CFrame.Angles(math.rad(0), math.rad(-180), math.rad(-95)),
						model = import:WaitForChild("Stone_Pickaxe"),
					},
					{
						name = "iron_pickaxe",
						offset = CFrame.Angles(math.rad(0), math.rad(-180), math.rad(-95)),
						model = import:WaitForChild("Iron_Pickaxe"),
					},
					{
						name = "diamond_pickaxe",
						offset = CFrame.Angles(math.rad(0), math.rad(90), math.rad(-95)),
						model = import:WaitForChild("Diamond_Pickaxe"),
					},	
					{
						name = "fireball",
						offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
						model = import:WaitForChild("Fireball"),
					},	
					{
						name = "telepearl",
						offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
						model = import:WaitForChild("Telepearl"),
					},
					{
						name = "diamond",
						offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(-90)),
						model = import:WaitForChild("Diamond"),
					},
					{
						name = "iron",
						offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
						model = import:WaitForChild("Iron"),
					},
					{
						name = "gold",
						offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
						model = import:WaitForChild("Gold"),
					},
					{
						name = "emerald",
						offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(-90)),
						model = import:WaitForChild("Emerald"),
					},
					{
						name = "wood_bow",
						offset = CFrame.Angles(math.rad(0), math.rad(0), math.rad(90)),
						model = import:WaitForChild("Bow"),
					},
					{
						name = "wood_crossbow",
						offset = CFrame.Angles(math.rad(0), math.rad(0), math.rad(90)),
						model = import:WaitForChild("Bow"),
					},
					{
						name = "tactical_crossbow",
						offset = CFrame.Angles(math.rad(0), math.rad(180), math.rad(-90)),
						model = import:WaitForChild("Bow"),
					},
					{
						name = "wood_dao",
						offset = CFrame.Angles(math.rad(0), math.rad(89), math.rad(-90)),
						model = import:WaitForChild("Wood_Sword"),
					},
					{
						name = "stone_dao",
						offset = CFrame.Angles(math.rad(0), math.rad(89), math.rad(-90)),
						model = import:WaitForChild("Stone_Sword"),
					},
					{
						name = "iron_dao",
						offset = CFrame.Angles(math.rad(0), math.rad(89), math.rad(-90)),
						model = import:WaitForChild("Iron_Sword"),
					},
					{
						name = "diamond_dao",
						offset = CFrame.Angles(math.rad(0), math.rad(89), math.rad(-90)),
						model = import:WaitForChild("Diamond_Sword"),
					},
				}
				toolFunction = function(tool)	
					if not tool:IsA("Accessory") then return end	
					for _, v in ipairs(index) do	
						if v.name == tool.Name then		
							for _, part in ipairs(tool:GetDescendants()) do
								if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then				
									part.Transparency = 1
								end			
							end		
							local model = v.model:Clone()
							model.CFrame = tool:WaitForChild("Handle").CFrame * v.offset
							model.CFrame *= CFrame.Angles(math.rad(0), math.rad(-50), math.rad(0))
							model.Parent = tool			
							local weld = Instance.new("WeldConstraint", model)
							weld.Part0 = model
							weld.Part1 = tool:WaitForChild("Handle")			
							local tool2 = Players.LocalPlayer.Character:WaitForChild(tool.Name)			
							for _, part in ipairs(tool2:GetDescendants()) do
								if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then				
									part.Transparency = 1				
								end			
							end			
							local model2 = v.model:Clone()
							model2.Anchored = false
							model2.CFrame = tool2:WaitForChild("Handle").CFrame * v.offset
							model2.CFrame *= CFrame.Angles(math.rad(0), math.rad(-50), math.rad(0))
							if v.name:match("rageblade") then
								model2.CFrame *= CFrame.new(0.7, 0, -.7)                           
							elseif v.name:match("sword") or v.name:match("blade") then
								model2.CFrame *= CFrame.new(.2, 0, -.8)
							elseif v.name:match("dao") then
								model2.CFrame *= CFrame.new(.7, 0, -1.3)
							elseif v.name:match("axe") and not v.name:match("pickaxe") and v.name:match("diamond") then
								model2.CFrame *= CFrame.new(.08, 0, -1.1) - Vector3.new(0, 0, -1.1)
							elseif v.name:match("axe") and not v.name:match("pickaxe") and not v.name:match("diamond") then
								model2.CFrame *= CFrame.new(-.2, 0, -2.4) + Vector3.new(0, 0, 2.12)
							elseif v.name:match("diamond_pickaxe") then
								model2.CFrame *= CFrame.new(.2, 0, -.26)
							elseif v.name:match("iron") and not v.name:match("iron_pickaxe") then
								model2.CFrame *= CFrame.new(0, -.24, 0)
							elseif v.name:match("gold") then
								model2.CFrame *= CFrame.new(0, .03, 0)
							elseif v.name:match("diamond") or v.name:match("emerald") then
								model2.CFrame *= CFrame.new(0, -.03, 0)
							elseif v.name:match("telepearl") then
								model2.CFrame *= CFrame.new(.1, 0, .1)
							elseif v.name:match("fireball") then
								model2.CFrame *= CFrame.new(.28, .1, 0)
							elseif v.name:match("bow") and not v.name:match("crossbow") then
								model2.CFrame *= CFrame.new(-.2, .1, -.05)
							elseif v.name:match("wood_crossbow") and not v.name:match("tactical_crossbow") then
								model2.CFrame *= CFrame.new(-.5, 0, .05)
							elseif v.name:match("tactical_crossbow") and not v.name:match("wood_crossbow") then
								model2.CFrame *= CFrame.new(-.35, 0, -1.2)
							else
								model2.CFrame *= CFrame.new(.0, 0, -.06)
							end
							model2.Parent = tool2
							local weld2 = Instance.new("WeldConstraint", model)
							weld2.Part0 = model2
							weld2.Part1 = tool2:WaitForChild("Handle")
						end
					end
				end
			end)
		end,
        FirstHighResPack = function() 
            task.spawn(function()
				local Players = game:GetService("Players")
				local ReplicatedStorage = game:GetService("ReplicatedStorage")
				local Workspace = game:GetService("Workspace")
				local objs = game:GetObjects("rbxassetid://14224565815")
				local import = objs[1]
				import.Parent = ReplicatedStorage
				local index = {
					{
						name = "wood_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
						model = import:WaitForChild("Wood_Sword"),
					},
					{
						name = "stone_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
						model = import:WaitForChild("Stone_Sword"),
					},
					{
						name = "iron_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
						model = import:WaitForChild("Iron_Sword"),
					},
					{
						name = "diamond_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
						model = import:WaitForChild("Diamond_Sword"),
					},
					{
						name = "emerald_sword",
						offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
						model = import:WaitForChild("Emerald_Sword"),
					},
          			{
                        name = "rageblade",
                        offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(90)),
                        model = import:WaitForChild("Rageblade"),
          			},
					{
						name = "wood_pickaxe",
						offset = CFrame.Angles(math.rad(0), math.rad(-180), math.rad(-95)),
						model = import:WaitForChild("Wood_Pickaxe"),
					},
					{
						name = "stone_pickaxe",
						offset = CFrame.Angles(math.rad(0), math.rad(-180), math.rad(-95)),
						model = import:WaitForChild("Stone_Pickaxe"),
					},
					{
						name = "iron_pickaxe",
						offset = CFrame.Angles(math.rad(0), math.rad(-180), math.rad(-95)),
						model = import:WaitForChild("Iron_Pickaxe"),
					},
					{
						name = "diamond_pickaxe",
						offset = CFrame.Angles(math.rad(0), math.rad(90), math.rad(-95)),
						model = import:WaitForChild("Diamond_Pickaxe"),
					},
					{
						name = "wood_axe",
						offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
						model = import:WaitForChild("Wood_Axe"),
					},
					{
						name = "stone_axe",
						offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
						model = import:WaitForChild("Stone_Axe"),
					},
					{
						name = "iron_axe",
						offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
						model = import:WaitForChild("Iron_Axe"),
					},
					{
						name = "diamond_axe",
						offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-95)),
						model = import:WaitForChild("Diamond_Axe"),
					},
					{
						name = "fireball",
						offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
						model = import:WaitForChild("Fireball"),
					},
					{
						name = "telepearl",
						offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
						model = import:WaitForChild("Telepearl"),
					},
					{
						name = "diamond",
						offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(-90)),
						model = import:WaitForChild("Diamond"),
					},
					{
						name = "iron",
						offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
						model = import:WaitForChild("Iron"),
					},
					{
						name = "gold",
						offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
						model = import:WaitForChild("Gold"),
					},
					{
						name = "emerald",
						offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(-90)),
						model = import:WaitForChild("Emerald"),
					},
					{
						name = "wood_bow",
						offset = CFrame.Angles(math.rad(0), math.rad(0), math.rad(90)),
						model = import:WaitForChild("Bow"),
					},
					{
						name = "wood_crossbow",
						offset = CFrame.Angles(math.rad(0), math.rad(0), math.rad(90)),
						model = import:WaitForChild("Bow"),
					},
					{
						name = "tactical_crossbow",
						offset = CFrame.Angles(math.rad(0), math.rad(180), math.rad(-90)),
						model = import:WaitForChild("Bow"),
					},
				}
				toolFunction = function(tool)
					if not tool:IsA("Accessory") then return end
					for _, v in ipairs(index) do
						if v.name == tool.Name then
							for _, part in ipairs(tool:GetDescendants()) do
								if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then
									part.Transparency = 1
								end
							end
							local model = v.model:Clone()
							model.CFrame = tool:WaitForChild("Handle").CFrame * v.offset
							model.CFrame *= CFrame.Angles(math.rad(0), math.rad(-50), math.rad(0))
							model.Parent = tool
							local weld = Instance.new("WeldConstraint", model)
							weld.Part0 = model
							weld.Part1 = tool:WaitForChild("Handle")
							local tool2 = Players.LocalPlayer.Character:WaitForChild(tool.Name)
							for _, part in ipairs(tool2:GetDescendants()) do
								if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then
									part.Transparency = 1
								end
							end
							local model2 = v.model:Clone()
							model2.Anchored = false
							model2.CFrame = tool2:WaitForChild("Handle").CFrame * v.offset
							model2.CFrame *= CFrame.Angles(math.rad(0), math.rad(-50), math.rad(0))
							if v.name:match("rageblade") then
								model2.CFrame *= CFrame.new(0.7, 0, -1)
							elseif v.name:match("sword") or v.name:match("blade") then
								model2.CFrame *= CFrame.new(.6, 0, -1.1) - Vector3.new(0, 0, -.3)
							elseif v.name:match("axe") and not v.name:match("pickaxe") and v.name:match("diamond") then
								model2.CFrame *= CFrame.new(.08, 0, -1.1) - Vector3.new(0, 0, -1.1)
							elseif v.name:match("axe") and not v.name:match("pickaxe") and not v.name:match("diamond") then
								model2.CFrame *= CFrame.new(-.2, 0, -2.4) + Vector3.new(0, 0, 2.12)
							elseif v.name:match("diamond_pickaxe") then
								model2.CFrame *= CFrame.new(.2, 0, -.26)
							elseif v.name:match("iron") and not v.name:match("iron_pickaxe") then
								model2.CFrame *= CFrame.new(0, -.24, 0)
							elseif v.name:match("gold") then
								model2.CFrame *= CFrame.new(0, .03, 0)
							elseif v.name:match("diamond") or v.name:match("emerald") then
								model2.CFrame *= CFrame.new(0, -.03, 0)
							elseif v.name:match("telepearl") then
								model2.CFrame *= CFrame.new(.1, 0, .1)
							elseif v.name:match("fireball") then
								model2.CFrame *= CFrame.new(.28, .1, 0)
							elseif v.name:match("bow") and not v.name:match("crossbow") then
								model2.CFrame *= CFrame.new(-.2, .1, -.05)
							elseif v.name:match("wood_crossbow") and not v.name:match("tactical_crossbow") then
								model2.CFrame *= CFrame.new(-.5, 0, .05)
							elseif v.name:match("tactical_crossbow") and not v.name:match("wood_crossbow") then
								model2.CFrame *= CFrame.new(-.35, 0, -1.2)
							else
								model2.CFrame *= CFrame.new(.2, 0, -.24)
							end
							model2.Parent = tool2
							local weld2 = Instance.new("WeldConstraint", model)
							weld2.Part0 = model2
							weld2.Part1 = tool2:WaitForChild("Handle")
						end
					end
				end
           end)
		end,
        RandomPack = function() 
            task.spawn(function()  
				local Players = game:GetService("Players")
				local ReplicatedStorage = game:GetService("ReplicatedStorage")
				local Workspace = game:GetService("Workspace")
				local objs = game:GetObjects("rbxassetid://14282106674")
				local import = objs[1]
				import.Parent = game:GetService("ReplicatedStorage")
				index = {
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
				toolFunction = function(tool)
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
							local tool2 = Players.LocalPlayer.Character:WaitForChild(tool.Name)
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
				end  
           end)
		end,
		SecondHighResPack = function() 
            task.spawn(function()
				local Players = game:GetService("Players")
				local ReplicatedStorage = game:GetService("ReplicatedStorage")
				local Workspace = game:GetService("Workspace")
				local objs = game:GetObjects("rbxassetid://14078540433")
				local import = objs[1]
				import.Parent = game:GetService("ReplicatedStorage")
				index = {
					{
						name = "wood_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Wood_Sword"),
					},
					{
						name = "stone_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Stone_Sword"),
					},
					{
						name = "iron_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Iron_Sword"),
					},
					{
						name = "diamond_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Diamond_Sword"),
					},
					{
						name = "emerald_sword",
						offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
						model = import:WaitForChild("Emerald_Sword"),
					},
					{
						name = "rageblade",
						offset = CFrame.Angles(math.rad(0),math.rad(-90),math.rad(90)),
						model = import:WaitForChild("Rageblade"),
					}, 
				}
				toolFunction = function(tool)
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
							local tool2 = Players.LocalPlayer.Character:WaitForChild(tool.Name)
							for i,v in pairs(tool2:GetDescendants()) do
								if(v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation")) then
									v.Transparency = 1
								end
							end
							local model2 = v.model:Clone()
							model2.Anchored = false
							model2.CFrame = tool2:WaitForChild("Handle").CFrame * v.offset
							model2.CFrame *= CFrame.Angles(math.rad(0),math.rad(-50),math.rad(0))
							model2.CFrame *= CFrame.new(.5,0,-.8)
							model2.Parent = tool2
							local weld2 = Instance.new("WeldConstraint",model)
							weld2.Part0 = model2
							weld2.Part1 = tool2:WaitForChild("Handle")
						end
					end
				end
           end)
		end
	}

	if (not TexturePacks.Enabled) then toolFunction = function() end end

	local function refresh()
		pcall(function() con:Disconnect() end)
		con = game:GetService("Workspace"):WaitForChild("Camera").Viewmodel.ChildAdded:Connect(toolFunction)
		for i,v in pairs(game:GetService("Workspace"):WaitForChild("Camera").Viewmodel:GetChildren()) do toolFunction(v) end
	end

	TexturePacks = vape.Categories.Render:CreateModule({
		["Name"] = "TexturePacksV3",
		["Function"] = function(callback) 
			if callback then 
				packfunctions[packselected["Value"]]()
				refresh()
            else 
				toolFunction = function() end
				refresh()
			end
		end
	})
	local list = {}
	for i,v in pairs(packfunctions) do table.insert(list, tostring(i)) end
	packselected = TexturePacks:CreateDropdown({
		["Name"] = "Pack",
		["Function"] = function() if TexturePacks.Enabled then packfunctions[packselected["Value"]](); refresh() end end,
		["List"] = list
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

    AutoBuyWool = vape.Categories.Inventory:CreateModule({
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
                        task.wait(0.05) -- fast polling
                    until not AutoBuyWool.Enabled
                end)
            end
        end
    })
end)
run(function()
        local ChestSteal: table = { ["Enabled"] = false };
        local Range: table = { ["Value"] = 18 };
        local Ping: table = { ["Value"] = 300 };
        local Open: table = { ["Enabled"] = false };
        local Skywars: table = { ["Enabled"] = false };
        local Delays: table = {};
        local LootedChests: table = {};
		local pingValue: number = 0
        task.spawn(function()
                local pingStat: any = game:GetService("Stats"):WaitForChild("PerformanceStats"):WaitForChild("Ping");
                while task.wait(0.05) do
                        pingValue = tonumber(pingStat:GetValue());
                end;
        end);
        local getPing: () -> number = function()
        		return pingValue;
		end;
        local lootChest: (chestFolder: Instance) -> boolean = function(chestFolder: Instance): boolean
                local chest: any = chestFolder and chestFolder.Value;
                if not chest or LootedChests[chest] or (Delays[chest] or 0) >= tick() then
                        return false;
                end;
                local ping: number? = getPing();
                if ping > Ping["Value"] then
                        return false;
                end;
                Delays[chest] = tick() + 0.3;
                local chestItems: { Instance } = chest:GetChildren();
                if #chestItems == 0 then return false; end;
                pcall(function()
                        bedwars.Client:GetNamespace("Inventory"):Get("SetObservedChest"):SendToServer(chest);
                end);
                for _: any, item: any in next, chestItems do
                        if item:IsA("Accessory") then
                                ping = getPing();
                                if ping > Ping["Value"] then break; end;
                                pcall(function()
                                        bedwars.Client:GetNamespace("Inventory"):Get("ChestGetItem"):CallServer(chest, item);
                                end);
                                task.wait(math.max(0.03, 0.00075 * ping - 0.025));
                        end;
                end;
                task.wait(0.05);
                pcall(function()
                        bedwars.Client:GetNamespace("Inventory"):Get("SetObservedChest"):SendToServer(nil);
                end);
                LootedChests[chest] = true;
                return true;
        end;
        ChestSteal = vape.Categories.World:CreateModule({
                ["Name"] = "ChestSteal",
                ["Function"] = function(call: boolean): void
                        if not call then return end;
                        local chests: { Instance } = collection("chest", ChestSteal);
                        repeat task.wait() until store.queueType ~= "bedwars_test";
                        if (not Skywars["Enabled"]) or store.queueType:find("skywars") then
                                while ChestSteal["Enabled"] do
                                        task.wait(0.16);
                                        if entitylib.isAlive and store.matchState ~= 2 then
                                                local localPos: Vector3 = entitylib.character.RootPart.Position;
                                                if Open["Enabled"] then
                                                        local obsChest: Instance? = lplr.Character:FindFirstChild("ObservedChestFolder");
                                                        if obsChest and bedwars.AppController:isAppOpen("ChestApp") then
                                                                lootChest(obsChest);
                                                        end;
                                                else
                                                        local closestChest: Instance?;
                                                        local minDistance: number = math.huge;
                                                        for _: any, chest: Instance in next, chests do
                                                                local chestFolder: Instance? = chest:FindFirstChild("ChestFolderValue");
                                                                if chestFolder and not LootedChests[chestFolder.Value] then
                                                                        local distance: number = (localPos - chest.Position).Magnitude;
                                                                        if distance <= Range["Value"] and distance < minDistance then
                                                                                minDistance = distance;
                                                                                closestChest = chestFolder;
                                                                        end;
                                                                end;
                                                        end;
                                                        if closestChest then
                                                                lootChest(closestChest);
                                                        end;
                                                end;
                                        end;
                                end;
                        end;
                end,
                ["Tooltip"] = "Grabs items from near chests (one at a time)."
        });
        Range = ChestSteal:CreateSlider({
                ["Name"] = "Range",
                ["Min"] = 0,
                ["Max"] = 18,
                ["Default"] = 18,
                ["Suffix"] = function(val: number) return val == 1 and "stud" or "studs" end
        });
        Ping = ChestSteal:CreateSlider({
                ["Name"] = "Ping",
                ["Min"] = 0,
                ["Max"] = 1000,
                ["Default"] = 300,
                ["Function"] = function(val: number) end
        });
        Open = ChestSteal:CreateToggle({ ["Name"] = "GUI Check" });
        Skywars = ChestSteal:CreateToggle({
                ["Name"] = "Only Skywars",
                ["Function"] = function()
                        if ChestSteal["Enabled"] then
                                ChestSteal:Toggle();
                                ChestSteal:Toggle();
                        end;
                end,
                ["Default"] = true
        });
end)
run(function()
	local NoFall
	local Mode
	local rayParams = RaycastParams.new()
	
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
				elseif Mode.Value == 'Land' then
					local lastSpoof = tick()
					local lastY = 0
					NoFall:Clean(runService.Heartbeat:Connect(function()
						if entitylib.isAlive then
							local root = entitylib.character.RootPart
							if root.AssemblyLinearVelocity.Y < -79 then
								root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, -80, root.AssemblyLinearVelocity.Z)
								root.CFrame -= Vector3.new(0,(tick() - lastSpoof),0)
							else
								lastSpoof = tick()
							end
							if math.abs(lastY - root.Position.Y) > 5 then
								entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Landed)
							end
							lastY = root.Position.Y
						end
					end))
				else
					repeat
						if entitylib.isAlive then
							local root = entitylib.character.RootPart
							tracked = entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air and math.min(tracked, root.AssemblyLinearVelocity.Y) or 0
							if tracked < -85 then
								if Mode.Value == 'Teleport' then
									rayParams.FilterDescendantsInstances = {lplr.Character, gameCamera}
									rayParams.CollisionGroup = root.CollisionGroup
									local rootSize = root.Size.Y / 2 + entitylib.character.HipHeight
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
						task.wait(0.03)
					until not NoFall.Enabled
				end
			end
		end,
		Tooltip = 'Prevents taking fall damage.'
	})
	Mode = NoFall:CreateDropdown({
		Name = 'Mode',
		List = {'Gravity', 'Teleport', 'Bounce', 'Land'},
		Function = function()
			if NoFall.Enabled then
				NoFall:Toggle()
				NoFall:Toggle()
			end
		end
	})
end)
run(function()
    local ElkSummonModule = vape.Categories.Blatant:CreateModule({
        Name = "ElkSummon",
        Tooltip = "Summon elk using the useAbility event",
        Function = function(callback)
            if callback then
                -- Replace the event path with the correct one if different
                local event = game:GetService("ReplicatedStorage"):WaitForChild("events-@easy-games/game-core:shared/game-core-networking@getEvents.Events"):WaitForChild("useAbility")
                local args = {
                    [1] = "elk_summon"
                }
                -- Fire the server event with the specified arguments
                event:FireServer(unpack(args))
            end
        end
    })
end)
run(function()
    local WindWalkerModule = {Enabled = false}

    WindWalkerModule = vape.Categories.Blatant:CreateModule({
        Name = "Zephyr Exploit",
        Function = function(callback)
            if callback then
                repeat
                    local ReplicatedStorage = game:GetService("ReplicatedStorage")
                    local WindWalkerSpeedUpdate = ReplicatedStorage:WaitForChild("rbxts_include").node_modules["@rbxts"].net.out._NetManaged.WindWalkerSpeedUpdate

                    firesignal(WindWalkerSpeedUpdate.OnClientEvent, {
                        multiplier = 1.15,
                        orbCount = 2
                    })

                    task.wait(1)
                until not WindWalkerModule.Enabled
            end
        end,
        Tooltip = "Automatically updates zephyr time"
    })
end)
run(function()
    local MomentumModule = {Enabled = false}

    MomentumModule = vape.Categories.Blatant:CreateModule({
        Name = "KrystalExploit",
        Function = function(callback)
            if callback then
                repeat
                    local ReplicatedStorage = game:GetService("ReplicatedStorage")
                    local ServerMomentumUpdate = ReplicatedStorage:WaitForChild("rbxts_include").node_modules["@rbxts"].net.out._NetManaged.ServerMomentumUpdate

                    firesignal(ServerMomentumUpdate.OnClientEvent, {
                        momentumIncrement = 9e9
                    })

                    task.wait(0.01)
                until not MomentumModule.Enabled
            end
        end,
        Tooltip = "Repeatedly updates server momentum"
    })
end)
run(function()
    local DinoCharge = {Enabled = false}

    DinoCharge = vape.Categories.Blatant:CreateModule({
        Name = "Dino Disabler",
        Function = function(callback)
            if callback then
                local ReplicatedStorage = game:GetService("ReplicatedStorage")
                local abilityUsed = ReplicatedStorage["events-@easy-games/game-core:shared/game-core-networking@getEvents.Events"].abilityUsed -- RemoteEvent
                local player = game.Players.LocalPlayer

                while DinoCharge.Enabled do
                    firesignal(abilityUsed.OnClientEvent, workspace[player.Name], "dino_charge")
                    wait(5)
                end
            end
        end,
        Tooltip = "Disables the anti cheat by spam charging dino charge"
    })
end)
run(function()
    local Antihit = {Enabled = false}
    local TimeUp = {Value = 0.4}
    local Down = {Value = 0.1}
    local Range = {Value = 15}

    Antihit = vape.Categories.Blatant:CreateModule({
        Name = "AntiHit",
        Function = function(callback)
            if callback then
                spawn(function()
                    while Antihit.Enabled do
                        local character = lplr.Character
                        local root = character and character:FindFirstChild("HumanoidRootPart")
                        if root then
                            local orgPos = root.Position
                            local foundEnemy = false

                            for _, v in next, playersService:GetPlayers() do
                                if v ~= lplr and v.Team ~= lplr.Team then
                                    local enemyChar = v.Character
                                    local enemyRoot = enemyChar and enemyChar:FindFirstChild("HumanoidRootPart")
                                    local enemyHum = enemyChar and enemyChar:FindFirstChild("Humanoid")
                                    if enemyRoot and enemyHum and enemyHum.Health > 0 then
                                        local dist = (root.Position - enemyRoot.Position).Magnitude
                                        if dist <= Range.Value then
                                            foundEnemy = true
                                            break
                                        end
                                    end
                                end
                            end

                            if foundEnemy then
                                -- Move up
                                root.CFrame = CFrame.new(orgPos + Vector3.new(0, 45, 0))
                                task.wait(TimeUp.Value)

                                -- Move down to normal ground level
                                if Antihit.Enabled and lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart") then
                                    lplr.Character.HumanoidRootPart.CFrame = CFrame.new(orgPos)
                                end
                            end
                        end
                        task.wait(Down.Value)
                    end
                end)
            end
        end,
        Tooltip = "Prevents you from dying"
    })

    Range = Antihit:CreateSlider({
        Name = "Range",
        Min = 0,
        Max = 50,
        Default = 15,
        Function = function(val) Range.Value = val end
    })

    TimeUp = Antihit:CreateSlider({
        Name = "Time Up",
        Min = 0,
        Max = 1,
        Default = 0.4,
        Function = function(val) TimeUp.Value = val end
    })

    Down = Antihit:CreateSlider({
        Name = "Time Down",
        Min = 0,
        Max = 1,
        Default = 0.1,
        Function = function(val) Down.Value = val end
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
        Name = "AntiHitV2",
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
					if (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 0.5 then
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
										local switched
										for i,v in game:GetService("ReplicatedStorage"):GetDescendants() do
											if v.Name == "SetInvItem" and v:IsA("RemoteFunction") then switched = v break end
										end
										switched:InvokeServer({hand = item.tool})
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
	local Value
	local CameraDir
	local start
	local JumpTick, JumpSpeed, Direction = tick(), 0
	local projectileRemote = {InvokeServer = function() end}

	task.spawn(function()
		projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
	end)

	local function launchProjectile(item, pos, proj, speed, dir)
		if not pos then return end

		pos = pos - dir * 0.1
		local shootPosition = (CFrame.lookAlong(pos, Vector3.new(0, -speed, 0)) *
			CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ)))

		local longjumppath
		for i,v in game:GetService("ReplicatedStorage"):GetDescendants() do
			if v.Name == "SetInvItem" and v:IsA("RemoteFunction") then longjumppath = v break end
		end
	longjumppath:InvokeServer({hand = item.tool})
		task.wait(0.1)
		bedwars.ProjectileController:createLocalProjectile(
			bedwars.ProjectileMeta[proj], proj, proj, shootPosition.Position, '', shootPosition.LookVector * speed, {drawDurationSeconds = 1}
		)

		if projectileRemote:InvokeServer(item.tool, proj, proj, shootPosition.Position, pos,
			shootPosition.LookVector * speed, httpService:GenerateGUID(true), {drawDurationSeconds = 1},
			workspace:GetServerTimeNow() - 0.045) then

			local shoot = bedwars.ItemMeta[item.itemType].projectileSource.launchSound
			shoot = shoot and shoot[math.random(1, #shoot)] or nil
			if shoot then
				bedwars.SoundManager:playSound(shoot)
			end
		end
	end

	local LongJumpMethods = {
		cannon = function(_, pos, dir)
			pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
			local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
			bedwars.placeBlock(rounded, 'cannon', false)

			task.delay(0, function()
				local block, blockpos = getPlacedBlock(rounded)
				if block and block.Name == 'cannon' and (entitylib.character.RootPart.Position - block.Position).Magnitude < 20 then
					local breaktype = bedwars.ItemMeta[block.Name].block.breakType
					local tool = store.tools[breaktype]
					if tool then
				local cannonpath
					for i,v in game:GetService("ReplicatedStorage"):GetDescendants() do
						if v.Name == "SetInvItem" and v:IsA("RemoteFunction") then cannonpath = v break end
					end
				cannonpath:InvokeServer({hand = tool.tool})
					end

					bedwars.Client:Get(remotes.CannonAim):SendToServer({
						cannonBlockPos = blockpos,
						lookVector = dir
					})

					local broken = 0.1
					if bedwars.BlockController:calculateBlockDamage(lplr, {blockPosition = blockpos}) < block:GetAttribute('Health') then
						broken = 0.4
						bedwars.breakBlock(block, true, true)
					end

					task.delay(broken, function()
						for _ = 1, 3 do
							local call = bedwars.Client:Get(remotes.CannonLaunch):CallServer({cannonBlockPos = blockpos})
							if call then
								bedwars.breakBlock(block, true, true)
								JumpSpeed = 5.25 * Value.Value
								JumpTick = tick() + 2.3
								Direction = Vector3.new(dir.X, 0, dir.Z).Unit
								break
							end
							task.wait(0.1)
						end
					end)
				end
			end)
		end,

		cat = function(_, _, dir)
			LongJump:Clean(vapeEvents.CatPounce.Event:Connect(function()
				JumpSpeed = 4 * Value.Value
				JumpTick = tick() + 2.5
				Direction = Vector3.new(dir.X, 0, dir.Z).Unit
				entitylib.character.RootPart.Velocity = Vector3.zero
			end))

			if not bedwars.AbilityController:canUseAbility('CAT_POUNCE') then
				repeat task.wait() until bedwars.AbilityController:canUseAbility('CAT_POUNCE') or not LongJump.Enabled
			end

			if bedwars.AbilityController:canUseAbility('CAT_POUNCE') and LongJump.Enabled then
				bedwars.AbilityController:useAbility('CAT_POUNCE')
			end
		end,

		fireball = function(item, pos, dir)
			launchProjectile(item, pos, 'fireball', 60, dir)
		end,

		grappling_hook = function(item, pos, dir)
			launchProjectile(item, pos, 'grappling_hook_projectile', 140, dir)
		end,

		jade_hammer = function(item, _, dir)
			if not bedwars.AbilityController:canUseAbility(item.itemType..'_jump') then
				repeat task.wait() until bedwars.AbilityController:canUseAbility(item.itemType..'_jump') or not LongJump.Enabled
			end

			if bedwars.AbilityController:canUseAbility(item.itemType..'_jump') and LongJump.Enabled then
				bedwars.AbilityController:useAbility(item.itemType..'_jump')
				JumpSpeed = 1.4 * Value.Value
				JumpTick = tick() + 2.5
				Direction = Vector3.new(dir.X, 0, dir.Z).Unit
			end
		end,

		tnt = function(item, pos, dir)
			pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
			local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
			start = Vector3.new(rounded.X, start.Y, rounded.Z) + (dir * (item.itemType == 'pirate_gunpowder_barrel' and 2.6 or 0.2))
			bedwars.placeBlock(rounded, item.itemType, false)
		end,

		wood_dao = function(item, pos, dir)
			if (lplr.Character:GetAttribute('CanDashNext') or 0) > workspace:GetServerTimeNow() or not bedwars.AbilityController:canUseAbility('dash') then
				repeat task.wait() until (lplr.Character:GetAttribute('CanDashNext') or 0) < workspace:GetServerTimeNow() and bedwars.AbilityController:canUseAbility('dash') or not LongJump.Enabled
			end

			if LongJump.Enabled then
				bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
				switchItem(item.tool, 0.1)
				replicatedStorage['events-@easy-games/game-core:shared/game-core-networking@getEvents.Events'].useAbility:FireServer('dash', {
					direction = dir,
					origin = pos,
					weapon = item.itemType
				})
				JumpSpeed = 4.5 * Value.Value
				JumpTick = tick() + 2.4
				Direction = Vector3.new(dir.X, 0, dir.Z).Unit
			end
		end
	}

	for _, v in {'stone_dao', 'iron_dao', 'diamond_dao', 'emerald_dao'} do
		LongJumpMethods[v] = LongJumpMethods.wood_dao
	end

	LongJumpMethods.void_axe = LongJumpMethods.jade_hammer
	LongJumpMethods.siege_tnt = LongJumpMethods.tnt
	LongJumpMethods.pirate_gunpowder_barrel = LongJumpMethods.tnt

	LongJump = vape.Categories.Blatant:CreateModule({
		Name = 'LongJump',
		Function = function(callback)
			frictionTable.LongJump = callback or nil
			updateVelocity()

			if callback then
				LongJump:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
					if damageTable.entityInstance == lplr.Character and damageTable.fromEntity == lplr.Character and
						(not damageTable.knockbackMultiplier or not damageTable.knockbackMultiplier.disabled) then
						
						local knockbackBoost = bedwars.KnockbackUtil.calculateKnockbackVelocity(Vector3.one, 1, {
							vertical = 0,
							horizontal = (damageTable.knockbackMultiplier and damageTable.knockbackMultiplier.horizontal or 1)
						}).Magnitude * 1.1

						if knockbackBoost >= JumpSpeed then
							local pos = damageTable.fromPosition and Vector3.new(damageTable.fromPosition.X, damageTable.fromPosition.Y, damageTable.fromPosition.Z)
								or damageTable.fromEntity and damageTable.fromEntity.PrimaryPart.Position
							if not pos then return end
							local vec = (entitylib.character.RootPart.Position - pos)
							JumpSpeed = knockbackBoost
							JumpTick = tick() + 2.5
							Direction = Vector3.new(vec.X, 0, vec.Z).Unit
						end
					end
				end))

				LongJump:Clean(vapeEvents.GrapplingHookFunctions.Event:Connect(function(dataTable)
					if dataTable.hookFunction == 'PLAYER_IN_TRANSIT' then
						local vec = entitylib.character.RootPart.CFrame.LookVector
						JumpSpeed = 2.5 * Value.Value
						JumpTick = tick() + 2.5
						Direction = Vector3.new(vec.X, 0, vec.Z).Unit
					end
				end))

				start = entitylib.isAlive and entitylib.character.RootPart.Position or nil

				LongJump:Clean(runService.PreSimulation:Connect(function(dt)
					local root = entitylib.isAlive and entitylib.character.RootPart or nil

					if root and isnetworkowner(root) then
						if JumpTick > tick() then
							root.AssemblyLinearVelocity = Direction * (getSpeed() + ((JumpTick - tick()) > 1.1 and JumpSpeed or 0))
								+ Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)

							if entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air and not start then
								root.AssemblyLinearVelocity += Vector3.new(0, dt * (workspace.Gravity - 23), 0)
							else
								root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 15, root.AssemblyLinearVelocity.Z)
							end

							start = nil
						else
							if start then
								root.CFrame = CFrame.lookAlong(start, root.CFrame.LookVector)
							end
							root.AssemblyLinearVelocity = Vector3.zero
							JumpSpeed = 0
						end
					else
						start = nil
					end
				end))

				if store.hand and LongJumpMethods[store.hand.tool.Name] then
					task.spawn(LongJumpMethods[store.hand.tool.Name], getItem(store.hand.tool.Name),
						start, (CameraDir.Enabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector)
					return
				end

				for i, v in LongJumpMethods do
					local item = getItem(i)
					if item or store.equippedKit == i then
						task.spawn(v, item, start, (CameraDir.Enabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector)
						break
					end
				end
			else
				JumpTick = tick()
				Direction = nil
				JumpSpeed = 0
			end
		end,
		ExtraText = function() return 'Heatseeker' end,
		Tooltip = 'Lets you jump farther'
	})

	Value = LongJump:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 37,
		Default = 37,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})

	CameraDir = LongJump:CreateToggle({
		Name = 'Camera Direction'
	})
end)
run(function()
	local KaidaKillaura
	local Targets
	local AttackRange
	local UpdateRate
	local MouseDown
	local GUICheck
	local ShowAnimation
	local lastAttackTime = 0
	local attackCooldown = 0.65
	
	KaidaKillaura = vape.Categories.Blatant:CreateModule({
		Name = 'Kaida Killaura',
		Function = function(callback)
			
			if callback then
				if store.equippedKit ~= 'summoner' then
					notif('Kaida Killaura', 'You need to be using Summoner kit!', 3, 'alert')
					KaidaKillaura:Toggle()
					return
				end
				
				lastAttackTime = 0
				
				repeat
					if not entitylib.isAlive then
						task.wait(0.1)
						continue
					end
					
					if GUICheck.Enabled then
						if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
							task.wait(0.1)
							continue
						end
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
					
					if MouseDown.Enabled then
						local mousePressed = inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
						if not mousePressed then
							task.wait(1.2)
							continue
						end
					end
					
					if workspace:GetServerTimeNow() - lastAttackTime < 0.1 then
						task.wait(0.05)
						continue
					end
					
					if (workspace:GetServerTimeNow() - lastAttackTime) < attackCooldown then
						task.wait(0.1)
						continue
					end
					
					local plr = entitylib.EntityPosition({
						Range = AttackRange.Value,
						Part = 'RootPart',
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Wallcheck = Targets.Walls.Enabled or nil
					})
					
					if plr then
						local localPosition = entitylib.character.RootPart.Position
						local shootDir = CFrame.lookAt(localPosition, plr.RootPart.Position).LookVector
						localPosition += shootDir * math.max((localPosition - plr.RootPart.Position).Magnitude - 16, 0)
						
						lastAttackTime = workspace:GetServerTimeNow()
						
						if ShowAnimation.Enabled then
							pcall(function()
								bedwars.AnimationUtil:playAnimation(lplr, bedwars.GameAnimationUtil:getAssetId(bedwars.AnimationType.SUMMONER_CHARACTER_SWIPE), {
									looped = false
								})
							end)
							
							task.spawn(function()
								pcall(function()
									local clawModel = replicatedStorage.Assets.Misc.Kaida.Summoner_DragonClaw:Clone()
									
									if bedwars.KnightClient and bedwars.KnightClient.Controllers.SummonerKitSkinController then
										if bedwars.KnightClient.Controllers.SummonerKitSkinController:isPrismaticSkin(lplr) then
											bedwars.KnightClient.Controllers.SummonerKitSkinController:applyClawRGB(clawModel)
										end
									end
									
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
						end
						
						bedwars.Client:Get(remotes.SummonerClawAttack):SendToServer({
							position = localPosition,
							direction = shootDir,
							clientTime = workspace:GetServerTimeNow()
						})
					end
					
					task.wait(1 / UpdateRate.Value)
				until not KaidaKillaura.Enabled
			end
		end,
		Tooltip = 'Auto attacks with Summoner claw'
	})
	
	Targets = KaidaKillaura:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = true
	})
	
	AttackRange = KaidaKillaura:CreateSlider({
		Name = 'Attack Range',
		Min = 1,
		Max = 32,
		Default = 22,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	
	UpdateRate = KaidaKillaura:CreateSlider({
		Name = 'Update Rate',
		Min = 1,
		Max = 120,
		Default = 60,
		Suffix = 'hz'
	})
	
	MouseDown = KaidaKillaura:CreateToggle({
		Name = 'Require Mouse Down',
		Tooltip = 'Only attacks while holding left click'
	})
	
	GUICheck = KaidaKillaura:CreateToggle({
		Name = 'GUI Check'
	})
	
	ShowAnimation = KaidaKillaura:CreateToggle({
		Name = 'Show Animation',
		Default = true
	})
end)
run(function()
    local OGNametags = vape.Categories.Render:CreateModule({
        Name = "OG Nametags",
        Function = function(callback)
            
            if callback then
                local storedNametags = {}
                local localPlayer = playersService.LocalPlayer
                local localTeamId = localPlayer and localPlayer:GetAttribute("Team")
                
                local function createOGNametag(character)
                    if not character then return end
                    
                    local head = character:FindFirstChild("Head")
                    if not head then return end
                    
                    local originalNametag = head:FindFirstChild("Nametag")
                    if originalNametag then
                        storedNametags[character] = originalNametag:Clone()
                        originalNametag:Destroy()
                    end
                    
                    local oldOGNametag = head:FindFirstChild("OGNametag")
                    if oldOGNametag then oldOGNametag:Destroy() end
                    
                    local nametag = Instance.new("BillboardGui")
                    nametag.Name = "OGNametag"
                    nametag.Size = UDim2.fromScale(5, 0.65)
                    nametag.StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0)
                    nametag.AlwaysOnTop = true
                    nametag.MaxDistance = 150
                    nametag.ResetOnSpawn = false
                    nametag.AutoLocalize = false
                    nametag.Adornee = head
                    
                    local mainContainer = Instance.new("Frame")
                    mainContainer.Name = "MainContainer"
                    mainContainer.Size = UDim2.fromScale(1, 1)
                    mainContainer.BackgroundTransparency = 1
                    mainContainer.BorderSizePixel = 0
                    mainContainer.Parent = nametag
                    
                    local teamCircle = Instance.new("Frame")
                    teamCircle.Name = "TeamCircle"
                    teamCircle.Size = UDim2.fromScale(0.15, 0.8)
                    teamCircle.Position = UDim2.fromScale(0.05, 0.1)
                    teamCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    teamCircle.BackgroundTransparency = 0.3
                    teamCircle.BorderSizePixel = 0
                    
                    local corner = Instance.new("UICorner")
                    corner.CornerRadius = UDim.new(1, 0)
                    corner.Parent = teamCircle
                    
                    teamCircle.Parent = mainContainer
                    
                    local nameBg = Instance.new("Frame")
                    nameBg.Name = "NameBackground"
                    nameBg.Size = UDim2.fromScale(0.7, 0.8)
                    nameBg.Position = UDim2.fromScale(0.25, 0.1)
                    nameBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                    nameBg.BackgroundTransparency = 0.5
                    nameBg.BorderSizePixel = 0
                    
                    local outline = Instance.new("UIStroke")
                    outline.Thickness = 1.5
                    outline.Color = Color3.fromRGB(255, 255, 255)
                    outline.Parent = nameBg
                    
                    nameBg.Parent = mainContainer
                    
                    local nameLabel = Instance.new("TextLabel")
                    nameLabel.Name = "Name"
                    
                    local player = playersService:GetPlayerFromCharacter(character)
                    local displayName = character.Name
                    
                    if player then
                        local clanTag = player:GetAttribute("ClanTag")
                        if clanTag and clanTag ~= "" then
                            displayName = "[" .. clanTag .. "] " .. displayName
                        end
                    end
                    
                    nameLabel.Text = displayName
                    nameLabel.Size = UDim2.fromScale(0.95, 0.9)
                    nameLabel.Position = UDim2.fromScale(0.5, 0.5)
                    nameLabel.AnchorPoint = Vector2.new(0.5, 0.5)
                    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                    nameLabel.Font = Enum.Font.GothamMedium
                    nameLabel.BackgroundTransparency = 1
                    nameLabel.BorderSizePixel = 0
                    nameLabel.TextScaled = true
                    nameLabel.TextYAlignment = Enum.TextYAlignment.Center
                    nameLabel.TextXAlignment = Enum.TextXAlignment.Center
                    
                    nameLabel.Parent = nameBg
                    
                    nametag.Parent = head
                    
                    local teamId = player and player:GetAttribute("Team") or character:GetAttribute("Team")
                    
                    if teamId then
                        task.spawn(function()
                            local success, KnitClient = pcall(function()
                                return require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['knit'].src).KnitClient
                            end)
                            
                            if success and KnitClient and KnitClient.Controllers and KnitClient.Controllers.TeamController then
                                local team = KnitClient.Controllers.TeamController:getTeamById(teamId)
                                if team and team.color then
                                    teamCircle.BackgroundColor3 = team.color
                                    outline.Color = team.color
                                    
                                    local localPlayer = playersService.LocalPlayer
                                    local localTeamId = localPlayer and localPlayer:GetAttribute("Team")
                                    
                                    if teamId == localTeamId then
                                        nameLabel.TextColor3 = Color3.fromRGB(85, 255, 85)
                                    else
                                        nameLabel.TextColor3 = Color3.fromRGB(255, 0, 0) 
                                    end
                                end
                            end
                        end)
                    end
                end
                
                for _, player in playersService:GetPlayers() do
                    if player.Character then
                        createOGNametag(player.Character)
                    end
                    
                    player.CharacterAdded:Connect(function(character)
                        task.wait(0.1)
                        createOGNametag(character)
                    end)
                end
                
                for _, entity in collectionService:GetTagged("entity") do
                    if entity:IsA("Model") then
                        createOGNametag(entity)
                    end
                end
                
                playersService.PlayerAdded:Connect(function(player)
                    if player.Character then
                        createOGNametag(player.Character)
                    end
                    
                    player.CharacterAdded:Connect(function(character)
                        task.wait(0.1)
                        createOGNametag(character)
                    end)
                end)
                
                collectionService:GetInstanceAddedSignal("entity"):Connect(function(entity)
                    if entity:IsA("Model") then
                        task.wait(0.1)
                        createOGNametag(entity)
                    end
                end)
                
            else
                for _, player in playersService:GetPlayers() do
                    if player.Character then
                        local head = player.Character:FindFirstChild("Head")
                        if head then
                            local ogNametag = head:FindFirstChild("OGNametag")
                            if ogNametag then
                                ogNametag:Destroy()
                            end
                            
                            if storedNametags[player.Character] then
                                local restoredNametag = storedNametags[player.Character]:Clone()
                                restoredNametag.Parent = head
                                storedNametags[player.Character] = nil
                            end
                        end
                    end
                end
                
                for _, entity in collectionService:GetTagged("entity") do
                    if entity:IsA("Model") then
                        local head = entity:FindFirstChild("Head")
                        if head then
                            local ogNametag = head:FindFirstChild("OGNametag")
                            if ogNametag then
                                ogNametag:Destroy()
                            end
                            
                            if storedNametags[entity] then
                                local restoredNametag = storedNametags[entity]:Clone()
                                restoredNametag.Parent = head
                                storedNametags[entity] = nil
                            end
                        end
                    end
                end
                
                table.clear(storedNametags)
            end
        end,
        Tooltip = "Replaces all nametags with OG BedWars nametags"
    })
end)
run(function()
	local FastBow
	local Delay
	local oldSetOnCooldown
	
	task.spawn(function()
		repeat task.wait() until bedwars.ProjectileMeta and shared.vape
		
		for projectileName, projectileData in pairs(bedwars.ProjectileMeta) do
			if projectileData.projectile then
				local itemMeta = bedwars.ItemMeta[projectileData.projectile.itemType or '']
				if itemMeta and itemMeta.projectileSource then
					itemMeta.projectileSource.fireDelaySec = Delay.Value
				end
			end
		end
	end)
	
	FastBow = vape.Categories.Combat:CreateModule({
		Name = 'Fast Bow',
		Function = function(callback)
			if callback then
				task.spawn(function()
					repeat task.wait() until bedwars.CooldownController
					
					if not oldSetOnCooldown then
						oldSetOnCooldown = bedwars.CooldownController.setOnCooldown
					end
					
					bedwars.CooldownController.setOnCooldown = function(self, cooldownId, duration, options, ...)
						if FastBow.Enabled and (tostring(cooldownId):find("proj-source") or tostring(cooldownId):find("bow") or tostring(cooldownId):find("crossbow")) then
							duration = Delay.Value
						end
						return oldSetOnCooldown(self, cooldownId, duration, options, ...)
					end
				end)
				
				for _, item in pairs(bedwars.ItemMeta) do
					if item.projectileSource then
						item.projectileSource.fireDelaySec = Delay.Value
					end
				end
			else
				if oldSetOnCooldown then
					bedwars.CooldownController.setOnCooldown = oldSetOnCooldown
				end
				
				for _, item in pairs(bedwars.ItemMeta) do
					if item.projectileSource then
						local originalDelay = item.projectileSource.originalFireDelaySec or 1
						item.projectileSource.fireDelaySec = originalDelay
					end
				end
			end
		end,
		Tooltip = 'Reduces bow/crossbow fire delay(not every shot will hit but its fun to add ig)'
	})
	
	Delay = FastBow:CreateSlider({
		Name = 'Fire Delay',
		Min = 0,
		Max = 1,
		Default = 0.1,
		Decimal = 100,
		Suffix = 's',
		Function = function(val)
			if FastBow.Enabled then
				for _, item in pairs(bedwars.ItemMeta) do
					if item.projectileSource then
						if not item.projectileSource.originalFireDelaySec then
							item.projectileSource.originalFireDelaySec = item.projectileSource.fireDelaySec
						end
						item.projectileSource.fireDelaySec = val
					end
				end
			end
		end
	})
end)
local Killaura
local ChargeTime
run(function()
	local SlientAura
	local Distance

	local currentTarget
	local chargeStart = 0
	local chargeDuration = 0

	SlientAura = vape.Categories.Combat:CreateModule({
		Name = "SlientAura",
		Tooltip = "Synchronizes swing timing with AimAssist within a 180 angle",
		Function = function(callback)
			if callback then
				if not Killaura.Enabled then
					vape:CreateNotification("SlientAura","You must have KillAura enabled!",8.5,"warning")
					SlientAura:Toggle(false)
					return
				end

				SlientAura:Clean(runService.Heartbeat:Connect(function(dt)
					if entitylib.isAlive then
						local ent = entitylib.EntityPosition({
							Range = Distance.Value,
							Part = "RootPart",
							Wallcheck = true,
							Players = true,
							NPCs = false,
							Sort = "Distance"
						})

						local root = entitylib.character.RootPart
						local delta = ent.RootPart.Position - root.Position
						local localfacing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
						local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
						if angle > (math.rad(360) / 2) then return end
						if ent then
							chargeStart = tick()
							local base = math.clamp(ChargeTime.Value / 10, 0.1, 1)
							chargeDuration = math.clamp(base + math.random(-5, 5) / 100,0.1,1)

							local progress = math.clamp((tick() - chargeStart) / chargeDuration,0,1)
							local eased = progress * progress * (3 - 2 * progress)

							gameCamera.CFrame = gameCamera.CFrame:Lerp(CFrame.lookAt(gameCamera.CFrame.Position,ent.RootPart.Position),eased)
						end

					end
				end))
			end
		end
	})

	Distance = SlientAura:CreateSlider({
		Name = "Distance",
		Min = 1,
		Max = 30,
		Default = 12,
		Suffix = function(v)
			return v <= 1 and "stud" or "studs"
		end
	})

end)
run(function()
    local PositionRaper
    local Delay = {Value = 1250}
    local TransmissionOffset = {Value = 25}
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
            while PositionRaper.Enabled and #queuedCalls > 0 do
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
                    if PositionRaper.Enabled and Delay.Value > 0 then
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
                    if PositionRaper.Enabled and Delay.Value > 0 then
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
    
    PositionRaper = vape.Categories.World:CreateModule({
        Name = 'PositionRaper',
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
        Tooltip = 'real position raper!?'

    })
end)
run(function()
	local BackTrackIncoming = {}
	local KPS
	local BackTrack = vape.Categories.World:CreateModule({
		Name = "BackTrack", 
		Function = function(callback)  
			if callback then
				game:GetService("NetworkClient"):SetOutgoingKBPSLimit(KPS.Value)
				if BackTrackIncoming.Enabled then 
					settings():GetService("NetworkSettings").IncomingReplicationLag = KPS.Value * 3
				end
			else
				game:GetService("NetworkClient"):SetOutgoingKBPSLimit(math.huge)
				if BackTrackIncoming.Enabled then 
					settings():GetService("NetworkSettings").IncomingReplicationLag = 0
				end
			end
		end, 
		Tooltip = "PositionRaper"
	})
	BackTrackIncoming = BackTrack:CreateToggle({
		Name = "Incoming",
		Function = function(callback)
			if callback then
				if BackTrack.Enabled then 
					settings():GetService("NetworkSettings").IncomingReplicationLag = 99999999
				end
			else
				if BackTrack.Enabled then 
					settings():GetService("NetworkSettings").IncomingReplicationLag = 0
				end
			end
		end
	})
	KPS = BackTrack:CreateSlider({
		Name = "KPS Limit",
		Max = 250,
		Min = 1,
		Default = 25,
		Function = function()
			if BackTrack.Enabled then
				if KPS.Value <= 0 then KPS.Value = 1 end
				game:GetService("NetworkClient"):SetOutgoingKBPSLimit(KPS.Value)
				if BackTrackIncoming.Enabled then 
					settings():GetService("NetworkSettings").IncomingReplicationLag = KPS.Value * 4
				end
			else
				game:GetService("NetworkClient"):SetOutgoingKBPSLimit(math.huge)
				if BackTrackIncoming.Enabled then 
					settings():GetService("NetworkSettings").IncomingReplicationLag = 0
				end
			end
		end
	})
end)
run(function()
    local AutoDodge
    local Distance = 15
    local D

    AutoDodge = vape.Categories.Blatant:CreateModule({
        Name = 'AutoDodge',
        Tooltip = 'Automatically dodges arrows for you -- close range only',
        Function = function(callback)
            if not callback then return end 
            AutoDodge:Clean(workspace.DescendantAdded:Connect(function(arrow)
                    if not AutoDodge.Enabled then return end
                    if not entitylib.isAlive then return end

                    if (arrow.Name == "crossbow_arrow" or arrow.Name == "arrow" or arrow.Name == "headhunter_arrow")and arrow:IsA("Model") then

                        if arrow:GetAttribute("ProjectileShooter") == lplr.UserId then return end

                        local root = arrow:FindFirstChildWhichIsA("BasePart")
                        if not root then return end

                        while AutoDodge.Enabled and root and root.Parent and entitylib.isAlive do
                            local char = lplr.Character
                            local hrp = char and char:FindFirstChild("HumanoidRootPart")
                            local hum = char and char:FindFirstChildOfClass("Humanoid")
                            if not hrp or not hum then break end

                            local dist = (hrp.Position - root.Position).Magnitude
                            if dist <= (Distance + 5) then
                                local dodgePos = hrp.Position + Vector3.new(8, 0, 0)
								if humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
									humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
								end
                                hum:MoveTo(dodgePos)
                                break
                            end

                            task.wait(0.05)
                        end
                    end
                end)
            )
        end
    })

    D = AutoDodge:CreateSlider({
        Name = "Distance",
        Min = 1,
        Max = 30,
        Default = 15,
        Suffix = function(val)
            return val == 1 and "stud" or "studs"
        end,
        Function = function(val)
            Distance = val
        end
    })
end)
run(function()
		local Value
		local CameraDir
		local start
		local JumpTick, JumpSpeed, Direction = tick(), 0
		local JadeHammerPulse = {active = false, nextPulse = 0, speed = 0, boostEnd = 0}
		local projectileRemote = {InvokeServer = function() end}
		task.spawn(function()
			projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
		end)
		
		local function launchProjectile(item, pos, proj, speed, dir)
			if not pos then return end
		
			pos = pos - dir * 0.1
			local shootPosition = (CFrame.lookAlong(pos, Vector3.new(0, -speed, 0)) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ)))
			switchItem(item.tool, 0)
			task.wait(0.1)
			bedwars.ProjectileController:createLocalProjectile(bedwars.ProjectileMeta[proj], proj, proj, shootPosition.Position, '', shootPosition.LookVector * speed, {drawDurationSeconds = 1})
			if projectileRemote:InvokeServer(item.tool, proj, proj, shootPosition.Position, pos, shootPosition.LookVector * speed, httpService:GenerateGUID(true), {drawDurationSeconds = 1}, workspace:GetServerTimeNow() - 0.045) then
				local shoot = bedwars.ItemMeta[item.itemType].projectileSource.launchSound
				shoot = shoot and shoot[math.random(1, #shoot)] or nil
				if shoot then
					bedwars.SoundManager:playSound(shoot)
				end
			end
		end
		
		local LongJumpMethods = {
			cannon = function(_, pos, dir)
				pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
				local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
				bedwars.placeBlock(rounded, 'cannon', false)
		
				task.delay(0, function()
					local block, blockpos = getPlacedBlock(rounded)
					if block and block.Name == 'cannon' and (entitylib.character.RootPart.Position - block.Position).Magnitude < 20 then
						local breaktype = bedwars.ItemMeta[block.Name].block.breakType
						local tool = store.tools[breaktype]
						if tool then
							switchItem(tool.tool)
						end
		
						bedwars.Client:Get(remotes.CannonAim):SendToServer({
							cannonBlockPos = blockpos,
							lookVector = dir
						})
		
						local broken = 0.1
						if bedwars.BlockController:calculateBlockDamage(lplr, {blockPosition = blockpos}) < block:GetAttribute('Health') then
							broken = 0.4
							bedwars.breakBlock(block, true, true)
						end
		
						task.delay(broken, function()
							for _ = 1, 3 do
								local call = bedwars.Client:Get(remotes.CannonLaunch):CallServer({cannonBlockPos = blockpos})
								if call then
									bedwars.breakBlock(block, true, true)
									JumpSpeed = 5.25 * Value.Value
									JumpTick = tick() + 2.3
									Direction = Vector3.new(dir.X, 0, dir.Z).Unit
									break
								end
								task.wait(0.1)
							end
						end)
					end
				end)
			end,
			cat = function(_, _, dir)
				LongJump:Clean(vapeEvents.CatPounce.Event:Connect(function()
					JumpSpeed = 4 * Value.Value
					JumpTick = tick() + 2.5
					Direction = Vector3.new(dir.X, 0, dir.Z).Unit
					entitylib.character.RootPart.Velocity = Vector3.zero
				end))
		
				if not bedwars.AbilityController:canUseAbility('CAT_POUNCE') then
					repeat task.wait() until bedwars.AbilityController:canUseAbility('CAT_POUNCE') or not LongJump.Enabled
				end
		
				if bedwars.AbilityController:canUseAbility('CAT_POUNCE') and LongJump.Enabled then
					bedwars.AbilityController:useAbility('CAT_POUNCE')
				end
			end,
			fireball = function(item, pos, dir)
				launchProjectile(item, pos, 'fireball', 60, dir)
			end,
			grappling_hook = function(item, pos, dir)
				launchProjectile(item, pos, 'grappling_hook_projectile', 140, dir)
			end,
			jade_hammer = function(item, _, dir)
				if JadePulse.Enabled then
					JadeHammerPulse.active = true
					JadeHammerPulse.nextPulse = 0
				else
					if not bedwars.AbilityController:canUseAbility(item.itemType..'_jump') then
						repeat task.wait() until bedwars.AbilityController:canUseAbility(item.itemType..'_jump') or not LongJump.Enabled
					end
		
					if bedwars.AbilityController:canUseAbility(item.itemType..'_jump') and LongJump.Enabled then
						bedwars.AbilityController:useAbility(item.itemType..'_jump')
						JumpSpeed = 1.4 * Value.Value
						JumpTick = tick() + 2.5
						Direction = Vector3.new(dir.X, 0, dir.Z).Unit
					end
				end
			end,
			tnt = function(item, pos, dir)
				pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
				local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
				start = Vector3.new(rounded.X, start.Y, rounded.Z) + (dir * (item.itemType == 'pirate_gunpowder_barrel' and 2.6 or 0.2))
				bedwars.placeBlock(rounded, item.itemType, false)
			end,
			wood_dao = function(item, pos, dir)
				if (lplr.Character:GetAttribute('CanDashNext') or 0) > workspace:GetServerTimeNow() or not bedwars.AbilityController:canUseAbility('dash') then
					repeat task.wait() until (lplr.Character:GetAttribute('CanDashNext') or 0) < workspace:GetServerTimeNow() and bedwars.AbilityController:canUseAbility('dash') or not LongJump.Enabled
				end
		
				if LongJump.Enabled then
					bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
					switchItem(item.tool, 0.1)
					replicatedStorage['events-@easy-games/game-core:shared/game-core-networking@getEvents.Events'].useAbility:FireServer('dash', {
						direction = dir,
						origin = pos,
						weapon = item.itemType
					})
					JumpSpeed = 4.5 * Value.Value
					JumpTick = tick() + 2.4
					Direction = Vector3.new(dir.X, 0, dir.Z).Unit
				end
			end
		}
		for _, v in {'stone_dao', 'iron_dao', 'diamond_dao', 'emerald_dao'} do
			LongJumpMethods[v] = LongJumpMethods.wood_dao
		end
		LongJumpMethods.void_axe = LongJumpMethods.jade_hammer
		LongJumpMethods.siege_tnt = LongJumpMethods.tnt
		LongJumpMethods.pirate_gunpowder_barrel = LongJumpMethods.tnt
		local Speds
		LongJump = vape.Categories.Blatant:CreateModule({
			Name = 'LongJump',
			Function = function(callback)
				frictionTable.LongJump = callback or nil
				updateVelocity()
				if callback then
					LongJump:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
						if damageTable.entityInstance == lplr.Character and damageTable.fromEntity == lplr.Character and (not damageTable.knockbackMultiplier or not damageTable.knockbackMultiplier.disabled) then
							local knockbackBoost = bedwars.KnockbackUtil.calculateKnockbackVelocity(Vector3.one, 1, {
								vertical = 0,
								horizontal = (damageTable.knockbackMultiplier and damageTable.knockbackMultiplier.horizontal or 1)
							}).Magnitude * 1.1
		
							if knockbackBoost >= JumpSpeed then
								local pos = damageTable.fromPosition and Vector3.new(damageTable.fromPosition.X, damageTable.fromPosition.Y, damageTable.fromPosition.Z) or damageTable.fromEntity and damageTable.fromEntity.PrimaryPart.Position
								if not pos then return end
								local vec = (entitylib.character.RootPart.Position - pos)
								JumpSpeed = knockbackBoost
								JumpTick = tick() + 2.5
								Direction = Vector3.new(vec.X, 0, vec.Z).Unit
							end
						end
					end))
					LongJump:Clean(vapeEvents.GrapplingHookFunctions.Event:Connect(function(dataTable)
						if dataTable.hookFunction == 'PLAYER_IN_TRANSIT' then
							local vec = entitylib.character.RootPart.CFrame.LookVector
							JumpSpeed = 2.5 * Value.Value
							JumpTick = tick() + 2.5
							Direction = Vector3.new(vec.X, 0, vec.Z).Unit
						end
					end))
		
					start = entitylib.isAlive and entitylib.character.RootPart.Position or nil
					LongJump:Clean(runService.PreSimulation:Connect(function(dt)
						local root = entitylib.isAlive and entitylib.character.RootPart or nil
						if root and isnetworkowner(root) then
							if JadePulse["Enabled"] then
								local foundItem, method
								local jadeHammer = getItem("jade_hammer")
								if jadeHammer then
									foundItem, method = jadeHammer, LongJumpMethods.jade_hammer
								end
								if foundItem and method and LongJump.Enabled then
									method(foundItem, nil, (CameraDir.Enabled and gameCamera or root).CFrame.LookVector)
								else
									JumpTick = 0
									Direction = nil
								end
							end
							if JadeHammerPulse.active then
								if tick() >= JadeHammerPulse.nextPulse then
									local item = getItem('jade_hammer') or getItem('void_axe')
									if item and bedwars.AbilityController:canUseAbility(item.itemType..'_jump') then
										bedwars.AbilityController:useAbility(item.itemType..'_jump')
										JadeHammerPulse.boostEnd = tick() + 1.5
										JadeHammerPulse.nextPulse = tick() + 2.5
									end
								end
								if tick() < JadeHammerPulse.boostEnd then
									local moveDir = entitylib.character.Humanoid.MoveDirection
									if moveDir.Magnitude > 0 then
										root.AssemblyLinearVelocity = moveDir.Unit * (getSpeed() + (1.0 * Value.Value)) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
									else
										root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
									end
								else
									local moveDir = entitylib.character.Humanoid.MoveDirection
									if moveDir.Magnitude > 0 then
										root.AssemblyLinearVelocity = moveDir.Unit * getSpeed() + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
									else
										root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
									end
								end
							elseif JumpTick > tick() then
								root.AssemblyLinearVelocity = Direction * (getSpeed() + ((JumpTick - tick()) > 1.1 and JumpSpeed or 0)) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
								if entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air and not start then
									root.AssemblyLinearVelocity += Vector3.new(0, dt * (workspace.Gravity - 23), 0)
								else
									root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 15, root.AssemblyLinearVelocity.Z)
								end
								start = nil
							else
								if not JadePulse["Enabled"] then
									if start then
										root.CFrame = CFrame.lookAlong(start, root.CFrame.LookVector)
									end
									root.AssemblyLinearVelocity = Vector3.zero
								else
									if entitylib.isAlive then
										local humanoid = entitylib.character.Humanoid
										local root = entitylib.character.RootPart
										local state = humanoid:GetState()
										if state == Enum.HumanoidStateType.Climbing then return end
										local moveDirection = humanoid.MoveDirection
										local velo = getSpeed()
										local destination = moveDirection * math.max(Speds["Value"] - velo, 0) * dt 
										root.CFrame += destination
										root.AssemblyLinearVelocity = (moveDirection * Speds["Value"]) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
									end
                                end
                                JumpSpeed = 0
							end
						else
							start = nil
						end
					end))
					if not JadePulse["Enabled"] then
						if store.hand and LongJumpMethods[store.hand.tool.Name] then
							task.spawn(LongJumpMethods[store.hand.tool.Name], getItem(store.hand.tool.Name), start, (CameraDir.Enabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector)
							return
						end
			
						for i, v in LongJumpMethods do
							local item = getItem(i)
							if item or store.equippedKit == i then
								task.spawn(v, item, start, (CameraDir.Enabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector)
								break
							end
						end
					end
				else
					JumpTick = tick()
					Direction = nil
					JumpSpeed = 0
					JadeHammerPulse.active = false
					JadeHammerPulse.speed = 0
				end
			end,
			ExtraText = function()
				return 'Heatseeker'
			end,
			Tooltip = 'Lets you jump farther'
		})
		Value = LongJump:CreateSlider({
			Name = 'Speed',
			Min = 1,
			Max = 37,
			Default = 37,
			Suffix = function(val)
				return val == 1 and 'stud' or 'studs'
			end
		})
		CameraDir = LongJump:CreateToggle({
			Name = 'Camera Direction'
		})
		Speds = LongJump:CreateSlider({
            Name = 'Walk Speed',
            Min = 1,
            Max = 23,
            Default = 23,
            Suffix = function(val)
                return val == 1 and 'stud' or 'studs'
            end
        })
		JadePulse = LongJump:CreateToggle({
			Name = 'JadePulse',
			Default = true,
			Function = function(callback)
				if Speds.Object then
					Speds.Object.Visible = callback
				end
			end
		})
	end)
run(function()
	local PlayerAttach
	local Range
	local Targets
	local Sorts
	PlayerAttach = vape.Categories.Blatant:CreateModule({
		Name = "PlayerAttach",
		Tooltip = 'teleports you the closest player/npc near you in a specific range',
		Function = function(callback)
			if callback then
				repeat 
					local plrs = entitylib.AllPosition({
						Range = Range.Value,
						Wallcheck = Targets.Walls.Enabled,
						Part = "RootPart",
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Limit = 1,
						Sort = sortmethods[Sorts.Value]
					})
					local char = entitylib.character
					local root = char.RootPart
					if plrs then
						local ent = plrs[1]
						if ent and ent.RootPart then
							local Pos = ent.RootPart.Position
							local Vec = entitylib.character.RootPart.CFrame.LookVector
							local Delta = CFrame.lookAlong(Pos, Vec)
							entitylib.character.RootPart.CFrame = Delta
						end
					end
					task.wait(1.05 - math.random())
				until not PlayerAttach.Enabled
			end
		end
	})
	Range = PlayerAttach:CreateSlider({
		Name = "Distance",
		Min = 0,
		Max = 32,
		Default = 16,
		Suffix = function(val)
			if val == 1 then
				return 'stud'
			else
				return 'studs'
			end
		end
	})
	Targets = PlayerAttach:CreateTargets({
		Players=true,
		Walls=true,
		NPCs=true
	})
	Sorts = PlayerAttach:CreateDropdown({
		Name = "Sorts",
		List = {'Damage','Threat','Kit','Health','Angle'}
	})
end)
run(function()
	local RemoveStatus
	local old
	RemoveStatus = vape.Categories.Render:CreateModule({
		Name = "RemoveStatus",
		Tooltip = 'removes them annoying ass effects on ur screen(like that static thingy or being glooped)',
		Function = function(callback)
			if callback then
				old = bedwars.VignetteController.createVignette
			    bedwars.VignetteController.createVignette = function(...)
					return nil
				end
			else
				bedwars.VignetteController.createVignette = old
				old = nil
			end
		end
	})
end)
run(function()
	local IE
	local Text
	IE = vape.Categories.Utility:CreateModule({
		Name = "Invite Exploit",
		Tooltip = 'allows you to invite anyone ingame',
		Function = function(callback)
			if not callback then
				return
			end
			IE:Toggle(false)
			local plr = playersService:FindFirstChild(Text.Value)
			if plr then
				bedwars.PartyController.invitePlayer(plr)
			else
				vape:CreateNotification('Invite Exploit',Text.Value.." does not exist ingame...",6,'warning')
				return
			end
		end
	})
	Text = IE:CreateTextBox({
		Name = "Username",
		Tooltip = 'THIS MUST BE THE PLAYER\'S USERNAME'
	})
end)
run(function()
	local Lobby
	Lobby = vape.Categories.Render:CreateModule({
		Name = 'LobbyTP',
		Tooltip = 'allows you to lobby if u dont have access to the chat(like me not letting jews get my face)',
		Function = function(callback)
			if not callback then
				return
			end
			Lobby:Toggle(false)
			local s,err = pcall(function()
				bedwars.Client:Get("TeleportToLobby"):SendToServer()
			end)
			if not s then
				warn(err)
				task.wait(8)
				lobby()
			end
		end
	})
end)
run(function()
    local HitFix
	local PingBased
	local Options
    HitFix = vape.Categories.Blatant:CreateModule({
        Name = 'HitFix',
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
    local KitRender
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    local PlayerGui = player:WaitForChild("PlayerGui")

    local function createkitrender(plr)
        local render = bedwars.BedwarsKitMeta[plr:GetAttribute("PlayingAsKits")]  or bedwars.BedwarsKitMeta.none
        if not render or not render.renderImage then return end
        local icon = Instance.new("ImageLabel")
        icon.Name = "VapeKitRender"
        icon.AnchorPoint = Vector2.new(1, 0.5)
        icon.BackgroundTransparency = 1
        icon.Position = UDim2.new(1.05, 0, 0, 0)
        icon.Size = UDim2.new(1.5, 0, 1.5, 0)
        icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
        icon.ImageTransparency = 0.4
        icon.ScaleType = Enum.ScaleType.Crop
        icon.Image = render.renderImage
		icon.ZIndex = 1
        local uar = Instance.new("UIAspectRatioConstraint")
        uar.AspectRatio = 1
        uar.AspectType = Enum.AspectType.FitWithinMaxSize
        uar.DominantAxis = Enum.DominantAxis.Width
        uar.Parent = icon
        return icon
    end

    local function removeallkitrenders()
        for _, v in ipairs(PlayerGui:GetDescendants()) do
            if v:IsA("ImageLabel") and v.Name == "ReVapeKitRender" then
                v:Destroy()
            end
        end
    end

    local function refreshicon(icon, plr)
        local render = bedwars.BedwarsKitMeta[plr:GetAttribute("PlayingAsKits")]  or bedwars.BedwarsKitMeta.none
        if not render or not render.renderImage then return end
        icon.Image = render.renderImage
    end

    local function findPlayer(label, container)
        local render = container:FindFirstChild("PlayerRender", true)
        if render and render:IsA("ImageLabel") and render.Image then
            local userId = string.match(render.Image, "id=(%d+)")
            if userId then
                local plr = Players:GetPlayerByUserId(tonumber(userId))
                if plr then return plr end
            end
        end
        local text = label.Text
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Name == text or plr.DisplayName == text or plr:GetAttribute("DisguiseDisplayName") == text then
                return plr
            end
        end
    end

    local function handleLabel(label)
        if not (label:IsA("TextLabel") and label.Name == "PlayerName") then return end
        task.spawn(function()
            local container = label.Parent
            for _ = 1, 3 do
                if container and container.Parent then
                    container = container.Parent
                end
            end
            if not container or not container:IsA("Frame") then return end
            local playerFound = findPlayer(label, container)
            if not playerFound then
                task.wait(0.5)
                playerFound = findPlayer(label, container)
            end
            if not playerFound then return end
            container.Name = playerFound.Name
            local card = container:FindFirstChild("1") and container["1"]:FindFirstChild("MatchDraftPlayerCard")
            if not card then return end
            local icon = card:FindFirstChild("ReVapeKitRender")
            if not icon then
                icon = createkitrender(playerFound)
                icon.Parent = card
				task.wait(0.05)
       		 	tweenService:Create(icon,TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Position = UDim2.fromScale(1.05, 0.5)}):Play()
            end
            task.spawn(function()
                while container and container.Parent do
                    local updatedPlayer = findPlayer(label, container)
                    if updatedPlayer and updatedPlayer ~= playerFound then
                        playerFound = updatedPlayer
                    end
                    if playerFound and icon then
                        refreshicon(icon, playerFound)
                    end
                    task.wait(0.95)
                end
            end)
        end)
    end

    KitRender = vape.Categories.Utility:CreateModule({
        Name = "KitRender",
        Tooltip = "Allows you to see everyone's kit during kit phase (5v5, Ranked)",
        Function = function(callback)
            if callback then
                task.spawn(function()
                    local team2 = PlayerGui:WaitForChild("MatchDraftApp"):WaitForChild("DraftAppBackground"):WaitForChild("BodyContainer"):WaitForChild("Team2Column")
                    for _, child in ipairs(team2:GetDescendants()) do
                        if KitRender.Enabled then handleLabel(child) end
                    end
                    KitRender:Clean(team2.DescendantAdded:Connect(function(child)
                        if KitRender.Enabled then handleLabel(child) end
                    end))
                end)
            else
                removeallkitrenders()
            end
        end
    })
end)
run(function()
	local PromptDuration
	local Duration
	PromptDuration = vape.Categories.Utility:CreateModule({
		Name = 'Prompt Duration',
		Tooltip = 'Changes duration of proximity prompts',
		Function = function(call)
			if call then
				PromptDuration:Clean(proximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, player)
					if player == lplr then
						task.delay(Duration.Value, fireproximityprompt, prompt)
					end
				end))
			end
		end
	})

	Duration = PromptDuration:CreateSlider({
		Name = 'Duration',
		Min = 0,
		Max = 2,
		Default = 0,
		Suffix = function(val)
			return val > 1 and 'secs' or 'sec'
		end,
		Decimal = 5
	})
end)
run(function()
	local MiloDisguse
	local Blocks
	local old
	MiloDisguse = vape.Categories.Blatant:CreateModule({
		Name = "MiloDisguse",
		Tooltip = 'allows you to be any block u want to hide as',
		Function = function(callback)
			if not callback then
				return
			end
			if store.equippedKit ~= 'mimic' then
				vape:CreateNotification("MiloDisguse",'Kit require only!',6,"warning")
				return
			end
			MiloDisguse:Toggle(false)
			old = bedwars.MimicController.onAbilityUsed
			bedwars.MimicController.onAbilityUsed = function(s1,s2)
				if not entitylib.isAlive then
					return nil
				end
				task.spawn(function()
					local v88 = {
						["data"] = {
							["blockType"] = Blocks.Value or 'wool_red'
						}
					}
					bedwars.Client:Get("MimicBlock"):SendToServer(v88)
				end)
			end
			if bedwars.AbilityController:canUseAbility("MIMIC_BLOCK") then
				bedwars.AbilityController:useAbility('MIMIC_BLOCK')
				task.wait(2)
				bedwars.MimicController.onAbilityUsed = old
				old = nil
			end
		end
	})
	Blocks = MiloDisguse:CreateTextBox({
		Name = "Blocks",
		Tooltip = 'Meta names only(wool_red)',
		Default = 'wool_brown'
	})
	
end)
run(function()
	local BetterLassy
	local WallCheck
	local Distance
	local Angle
	local Delay
	local Limits
	local Sorts
	local CanLasso = true
	local projectileRemote = {InvokeServer = function() end}
	task.spawn(function()
		projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
	end)
	BetterLassy = vape.Categories.Utility:CreateModule({
		Name = 'BetterLassy',
		Tooltip = 'makes you be semi-blatant at lassy',
		Function = function(callback)
			if store.equippedKit ~= "cowgirl" then
				vape:CreateNotification("BetterLassy","Kit required only!",8,"warning")
				return
			end
			if callback then
				repeat
					local item = getItem("lasso")
					if not item then task.wait(0.1) continue end
					local plrs = entitylib.AllPosition({
						Range = Distance.Value,
						Wallcheck = WallCheck.Enabled,
						Part = "RootPart",
						Players = true,
						NPCs = false,
						Limit = 1,
						Sort = sortmethods[Sorts.Value]
					})
					local char = entitylib.character
					local root = char.RootPart
					if plrs then
						local ent = plrs[1]
						if ent and ent.RootPart then
							local delta = ent.RootPart.Position - root.Position
							local localFacing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
							local angle = math.acos(localFacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
							if angle > (math.rad(Angle.Value) / 2) then task.wait(0.1); continue end
							if Limits.Enabled then
								if store.hand.toolType ~= "lasso" then
									continue
								end
							end
							if item and CanLasso then
								task.wait(1 / Delay.GetRandomValue())		
								local meta = bedwars.ProjectileMeta.lasso
								local calc = prediction.SolveTrajectory(pos, meta.launchVelocity, meta.gravitationalAcceleration, ent.RootPart.Velocity, Vector3.zero, workspace.Gravity, 0, 0)
								if calc then
									local dir = CFrame.lookAt(pos, calc).LookVector * meta.launchVelocity
									PR:InvokeServer(item.tool, meta, pos, dir)     
									CanLasso = false
									task.wait(12)
									CanLasso = true
								end
							end
						end
					end
					task.wait(0.05)
				until not BetterLassy.Enabled
			end
		end	
	})
	Distance = BetterLassy:CreateSlider({
		Name = "Range",
		Min = 1,
		Max = 24,
		Default = 12,
		Suffix = "Studs"
	})
	Delay = BetterLassy:CreateTwoSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Decimal = 10,
		Suffix = "s",
		DefaultMin = 0.2,
		DefaultMax = 1
	})
	Angle = BetterLassy:CreateSlider({
		Name = "Angle",
		Min = 1,
		Max = 360,
		Default = 120
	})
	WallCheck = BetterLassy:CreateToggle({Name='Wall Check',Default=true})
	Limits = BetterLassy:CreateToggle({Name='Limit to items',Default=true})
	Sorts = BetterLassy:CreateDropdown({
		Name = "Sorts",
		List = {'Damage','Threat','Kit','Health','Angle'}
	})
end)
run(function()
	local MLG 
	local Pearls
	local Fireball
	local Gumdrop
	local check = false
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local projectileRemote = {InvokeServer = function() end}
	task.spawn(function()
		projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
	end)

	local function getDropDistance(root)
		local result = workspace:Raycast(root.Position,Vector3.new(0, -500, 0),rayCheck)

		if result then
			return (root.Position.Y - result.Position.Y)
		end

		return math.huge 
	end
	
	local function firePearl(pos, spot, item)
		if item then		
			local pearl = getObjSlot('telepearl')
			local originalSlot = store.inventory.hotbarSlot
			hotbarSwitch(pearl)
			local meta = bedwars.ProjectileMeta.telepearl
			local calc = prediction.SolveTrajectory(pos, meta.launchVelocity, meta.gravitationalAcceleration, spot, Vector3.zero, workspace.Gravity, 0, 0)
			if calc then
				local dir = CFrame.lookAt(pos, calc).LookVector * meta.launchVelocity
				bedwars.ProjectileController:createLocalProjectile(meta, 'telepearl', 'telepearl', pos, nil, dir, {drawDurationSeconds = 1})
				PR:InvokeServer(item.tool, meta, pos, dir)
				task.wait(0.15)
				hotbarSwitch(originalSlot)
			end
		end
	end

	local function fireFireball(pos, spot, item)		
		if item then	
			local fireball = getObjSlot('fireball')
			local originalSlot = store.inventory.hotbarSlot
			hotbarSwitch(fireball)
			local meta = bedwars.ProjectileMeta.fireball
			local calc = prediction.SolveTrajectory(pos, meta.launchVelocity, meta.gravitationalAcceleration, spot, Vector3.zero, workspace.Gravity, 0, 0)
			if calc then
				local dir = CFrame.lookAt(pos, calc).LookVector * meta.launchVelocity
				bedwars.ProjectileController:createLocalProjectile(meta, 'fireball', 'fireball', pos, nil, dir, {drawDurationSeconds = 1})
				PR:InvokeServer(item.tool, meta, pos, dir)
				task.wait(0.15)
				hotbarSwitch(originalSlot)
			end
		end
	end

	local function launchpad(item)
		if item then
			local gum = getObjSlot('gumdrop_bounce_pad')
			local originalSlot = store.inventory.hotbarSlot
			hotbarSwitch(gum)
			task.wait(0.15)
			hotbarSwitch(originalSlot)
			local old = bedwars.LaunchPadController.attemptLaunch
			bedwars.LaunchPadController.attemptLaunch = function(...)
				local res = {old(...)}
				local self, block = ...
			
				if (workspace:GetServerTimeNow() - self.lastLaunch) < 0.4 then
					if block:GetAttribute('PlacedByUserId') == lplr.UserId and (block.Position - entitylib.character.RootPart.Position).Magnitude < 30 then
						task.spawn(bedwars.breakBlock, block, false, nil, true)
					end
				end
			
					return unpack(res)
				end
			
			MLG:Clean(function()
				bedwars.LaunchPadController.attemptLaunch = old
			end)
		end
	end

	MLG = vape.Categories.Utility:CreateModule({
		Name = "MLG",
		Tooltip = "Impressive game plays tactics",
		Function = function(callback)
			if callback then
				if not Pearls.Enabled and not Fireball.Enabled and not Gumdrop.Enabled then
					vape:CreateNotification("MLG", "nigga you dont have anything enabled for this holy useless gng", 10, "alert")
					MLG:Toggle(false)
					return
				end
				repeat
					if Pearls.Enabled then
						if entitylib.isAlive then
							local root = entitylib.character.RootPart
							local pearl = getItem('telepearl')
							rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiFallPart}
							rayCheck.CollisionGroup = root.CollisionGroup
							local drop = getDropDistance(root)

							if pearl and root.Velocity.Y < -80 and drop > 20  then
								if not check then
									check = true
									local ground = getNearGround(20)
		
									if ground then
										firePearl(root.Position, ground, pearl)
									end
								end
							else
								check = false
							end
						end
					end
					if Fireball.Enabled then
						if entitylib.isAlive then
							local root = entitylib.character.RootPart
							local fireball = getItem('fireball')
							rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiFallPart}
							rayCheck.CollisionGroup = root.CollisionGroup
							local drop = getDropDistance(root)

							if fireball and drop < 20  then
								if not check then
									check = true
									local ground = getNearGround(20)
		
									if ground then
										fireFireball(root.Position, ground, fireball)
									end
								end
							else
								check = false
							end
						end
					end
					if Gumdrop.Enabled then
						if entitylib.isAlive then
							local root = entitylib.character.RootPart
							local gum = getItem('gumdrop_bounce_pad')
							rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiFallPart}
							rayCheck.CollisionGroup = root.CollisionGroup
							local drop = getDropDistance(root)

							if gum and drop <= 10  then
								if not check then
									check = true
									local ground = getNearGround(20)
		
									if ground then
										launchpad(gum)
									end
								end
							else
								check = false
							end
						end
					end
					task.wait(0.05)
				until MLG.Enabled
			else
 				
			end
		end
	})

	Pearls = MLG:CreateToggle({
		Name = "Pearl",
		Tooltip = "Good pearl plays, void and high ground",
		Default = true
	})
	Fireball = MLG:CreateToggle({
		Name = "Fireball",
		Tooltip = "Fires a fireball at the ground when close to ground deflecting fall damage",
		Default = true
	})
	Gumdrop = MLG:CreateToggle({
		Name = "Gumdrop",
		Tooltip = "Places an gumdrop whenever ur close to falling to the ground deflecting the fall damage",
		Default = true
	})
end)
run(function()
	local BetterCait
	
	BetterCait = vape.Categories.Utility:CreateModule({
		Name = 'BetterCaitlyn',
		Function = function(callback)
			if store.equippedKit ~= "blood_assassin" then
				vape:CreateNotification("BetterCaitlyn","Kit required only!",8,"warning")
				return
			end
			local hitPlayers = {} 
				
			BetterCait:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
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
			repeat task.wait(0.01) until not entitylib.isAlive or not BetterCait.Enabled
			table.clear(hitPlayers)
		end,
		Tooltip = 'Makes you look better with caitlyn'
	})
	
end)
run(function()
	local BetterRamil
	local Distance
	local Sorts
	local Angle
	local MaxTargets
	local Targets
	local MovingTornadoDistance
	local UseTornandos
	local Rate
	BetterRamil = vape.Categories.Utility:CreateModule({
		Name = "BetterRamil",
		Tooltip = 'makes you play like me at ramil(i like ramil)',
		Function = function(callback)
			if store.equippedKit ~= "airbender" then
				vape:CreateNotification("BetterRamil","Kit required only!",8,"warning")
				return
			end
			if callback then
				repeat
		            local plrs = entitylib.AllPosition({
		                Range = AttackRange.Value,
		                Wallcheck = Targets.Walls.Enabled,
		                Part = "RootPart",
		                Players = Targets.Players.Enabled,
		                NPCs = Targets.NPCs.Enabled,
		                Limit = MaxTargets.Value,
		                Sort = sortmethods[Sorts.Value]
		            })
					local castplrs = nil

					if UseTornandos.Enabled then
						castplrs = entitylib.AllPosition({
							Range = MovingTornadoDistance.Value,
							Wallcheck = Targets.Walls.Enabled,
							Part = "RootPart",
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Limit = MaxTargets.Value,
							Sort = sortmethods[Sorts.Value]
		            	})
					end
		
		            local char = entitylib.character
		            local root = char.RootPart
		
		            if plrs then
		                local ent = plrs[1]
		                if ent and ent.RootPart then
		                    local delta = ent.RootPart.Position - root.Position
		                    local localFacing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		                    local angle = math.acos(localFacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
		                    if angle > (math.rad(Angle.Value) / 2) then task.wait(0.1); continue end
							if bedwars.AbilityController:canUseAbility('airbender_tornado') then
								bedwars.AbilityController:useAbility('airbender_tornado')
							end
		                end
		            end
					if castplrs then
		                local ent = castplrs[1]
		                if ent and ent.RootPart then
							if UseTornandos.Enabled then
								if bedwars.AbilityController:canUseAbility('airbender_moving_tornado') then
									bedwars.AbilityController:useAbility('airbender_moving_tornado')
								end
							end
						end
					end
					task.wait(1 / Rate.Value or 0.2)
				until not BetterRamil.Enabled
			end


		end
	})
	Targets = BetterRamil:CreateTargets({Players = true,NPCs = false,Walls = true})
    Angle = BetterRamil:CreateSlider({
        Name = "Angle",
        Min = 0,
        Max = 360,
        Default = 180
    })
	Sorts = BetterRamil:CreateDropdown({
		Name = "Sorts",
		List = {'Damage','Threat','Kit','Health','Angle'}
	})
	MaxTargets = BetterRamil:CreateSlider({
		Name = "Max Targets",
		Min = 1,
		Max = 3,
		Default = 2
	})
	Distance = BetterRamil:CreateSlider({
		Name = "Distance",
		Min = 1,
		Max = 25,
		Default = 18,
		Suffix = function(v)
			if v <= 1 then
				return 'stud'
			else
				return 'studs'
			end
		end
	})
	MovingTornadoDistance = BetterRamil:CreateSlider({
		Darker = true,
		Name = "Tornado Distance",
		Min = 1,
		Max = 31,
		Default = 18,
		Suffix = function(v)
			if v <= 1 then
				return 'stud'
			else
				return 'studs'
			end
		end
	})
	UseTornandos = BetterRamil:CreateToggle({Name='Use Moving Tornado\'s',Default=false,Function=function(v) MovingTornadoDistance.Object.Visible = v end})
	Rate = BetterRamil:CreateSlider({
		Name = "Update Rate",
		Min = 1,
		Max = 360,
		Default = 60,
		Suffix = "hz"
	})
end)
run(function()
	local FlyY 
	local Fly
	local Heal
	local HealthHP
	local AutoSummon
	local PlrUserTxt
	local isWhispering = false
	local BetterWhisper
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true

    BetterWhisper = vape.Categories.Utility:CreateModule({
        Name = 'BetterWhisper',
        Function = function(callback)
            if callback then
			if store.equippedKit ~= "owl" then
				vape:CreateNotification("BetterWhisper","Kit required only!",8,"warning")
				return
			end
				BetterWhisper:Clean(bedwars.Client:Get("OwlSummoned"):Connect(function(plr,target)
					if plr == lplr then
						local chr = target.Character
						local hum = chr:FindFirstChild('Humanoid')
						local root = chr:FindFirstChild('HumanoidRootPart')
						isWhispering = true
						repeat
							rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
							rayCheck.CollisionGroup = root.CollisionGroup

							if Fly.Enabled and root.Velocity.Y <= FlyY.Value and not workspace:Raycast(root.Position, Vector3.new(0, -100, 0), rayCheck) then
								WhisperController:request("Fly")
							end
							if Heal.Enabled and hum.Health <= HealthHP.Value then
								WhisperController:request("Heal")
							end
							task.wait(0.05)
						until not isWhispering or not BetterWhisper.Enabled
					end
				end))
				BetterWhisper:Clean(bedwars.Client:Get("OwlDeattached"):Connect(function(plr)
					if plr == lplr then
						isWhispering = false
					end
				end))
			else
				isWhispering = false
			end
        end,
        Tooltip = "Better whisper skills and u look like u play like therac!"
    })
	FlyY = BetterWhisper:CreateSlider({
		Name = 'Y-Level fly',																																																																							
		Min = -50,
		Max = -100,
		Default = -90,
	})	
	HealthHP = BetterWhisper:CreateSlider({
		Name = 'Heal HP',																																																																							
		Min = 1,
		Max = 99,
		Default = 80,
	})	
	Fly = BetterWhisper:CreateToggle({
		Name = 'Fly',
		Default = true,
	})
	Heal = BetterWhisper:CreateToggle({
		Name = 'Heal',
		Default = true,
	})
end)
run(function()
		local BetterNazar
		local AutoHeal

		BetterNazar = vape.Categories.Utility:CreateModule({
			Name = "BetterNazar",
			Tooltip = "makes you look good with nazar lmfao",
			Function = function(callback)
			if store.equippedKit ~= "nazar" then
				vape:CreateNotification("BetterNazar","Kit required only!",8,"warning")
				return
			end
				if callback then
					local lastHitTime = 0
					local hitTimeout = 3
					BetterNazar:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
						if not entitylib.isAlive then return end
							
						local attacker = playersService:GetPlayerFromCharacter(damageTable.fromEntity)
						local victim = playersService:GetPlayerFromCharacter(damageTable.entityInstance)
							
						if attacker == lplr and victim and victim ~= lplr then
							lastHitTime = workspace:GetServerTimeNow()
							NazarController:request('enabled')
						end
					end))
						
					BetterNazar:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
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

							if  entitylib.character.Humanoid.Health <= AutoHeal.Value then
								NazarController:request('heal')
							end

						else
							if empoweredMode then
								NazarController:request('disabled')
							end
						end
							
						task.wait(0.1)
					until not BetterNazar.Enabled
						
					if empoweredMode then
						NazarController:request('disabled')
					end
				end
			end
		})

		AutoHeal = BetterNazar:CreateSlider({
			Name = "Heal",
			Min = 35,
			Max = 85,
			Default = 75,
			Suffix = "%"
		})
end)
run(function()
	local BetterMetal
	local StreamerMode
	local Delay
	local Animation
	local Distance
	local Limits
	local Legit
	BetterMetal = vape.Categories.Utility:CreateModule({
		Name = "BetterMetal",
		Tooltip = 'makes you play like bobcat at metal or any1 whos good(js naming sm1 i know who mains metal)',
		Function = function(callback)
			if store.equippedKit ~= "metal_detector" then
				vape:CreateNotification("BetterMetal","Kit required only!",8,"warning")
				return
			end
			task.spawn(function()
				while BetterMetal.Enabled do
					if not entitylib.isAlive then task.wait(0.1); continue end
					local character = entitylib.character
					if not character or not character.RootPart then task.wait(0.1); continue end
					local tool = (store and store.hand and store.hand.tool) and store.hand.tool or nil
					if not tool or tool.Name ~= "metal_detector" then task.wait(0.5); continue end
					local localPos = character.RootPart.Position
					local metals = collectionService:GetTagged("hidden-metal")
					for _, obj in pairs(metals) do
						if obj:IsA("Model") and obj.PrimaryPart then
							local metalPos = obj.PrimaryPart.Position
							local distance = (localPos - metalPos).Magnitude
							local range = Legit.Enabled and 10 or (Distance.Value or 8)
							if distance <= range then
								if StreamerMode.Enabled then
									local Key = obj:FindFirstChild('hidden-metal-prompt').KeyboardKeyCode
									vim:SendKeyEvent(true, Key, false, game)
									task.wait(obj:FindFirstChild('hidden-metal-prompt').HoldDuration + math.random())
									vim:SendKeyEvent(false, Key, false, game)
								else
									local waitTime = Legit.Enabled and .854 or (1 / (Delay.GetRandomValue and Delay:GetRandomValue() or 1))
									task.wait(waitTime)
									if Legit.Enabled or Animation.Enabled then
										bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.SHOVEL_DIG)
										bedwars.SoundManager:playSound(bedwars.SoundList.SNAP_TRAP_CONSUME_MARK)
									end
									pcall(function()
										bedwars.Client:Get('CollectCollectableEntity'):SendToServer({id = obj:GetAttribute("Id")})
									end)
									task.wait(0.1)
								end
							end
						end
					end
					task.wait(0.1)
				end
			end)
		end
	})
	Limits = BetterMetal:CreateToggle({Name='Limit To Item',Default=false})
	StreamerMode = BetterMetal:CreateToggle({Name='Streamer Mode',Default=false})
	Distance = BetterMetal:CreateSlider({Name='Range',Min=6,Max=12,Default=8})
	Delay = BetterMetal:CreateTwoSlider({
		Name = "Delay",
		Min = 0,
		Max = 2,
		DefaultMin = 0.4,
		DefaultMax = 1,
		Suffix = 's',
        Decimal = 10,	
	})
	Animation = BetterMetal:CreateToggle({Name='Animations',Default=true})
	Legit = BetterMetal:CreateToggle({
		Name='Legit',
		Default=true,
		Darker=true,
		Function = function(v)
			Animation.Object.Visible = (not v)
			Delay.Object.Visible = (not v)
			Distance.Object.Visible = (not v)
			Limits.Object.Visible = (not v)
		end
	})

end)
run(function()
	local BetterLani
	local Legit
	local Delay
	local Player
	local t = 0
	BetterLani = vape.Categories.Utility:CreateModule({
		Name = "BetterLani",
		Tooltip = 'allows you to tp to a targetted player no matter what!',
		Function = function(callback)
			if store.equippedKit ~= "paladin" then
				vape:CreateNotification("BetterLani","Kit required only!",8,"warning")
				return
			end
			if callback then
				if Legit.Enabled then
					t = 1.33
				else
					t = (1 / Delay.GetRandomValue()) or 0.859
				end
				BetterLani:Clean(lplr:GetAttributeChangedSignal("PaladinStartTime"):Connect(function()
					task.wait(t)
					if bedwars.AbilityController:canUseAbility('PALADIN_ABILITY') then
						local plr = playersService:WaitForChild(Player.Value)
						if plr.Character then
							bedwars.Client:Get("PaladinAbilityRequest"):SendToServer({target = plr})
						else
							bedwars.Client:Get("PaladinAbilityRequest"):SendToServer({})
						end	
						task.wait(0.022)
						bedwars.AbilityController:useAbility('PALADIN_ABILITY')
					end
				end))
			else
				t = 0
			end
		end
	})
	Delay = BetterLani:CreateTwoSlider({
		Name = "Delay",
		Min = 0,
		Max = 2,
		DefaultMin = 0.4,
		DefaultMax = 1.33,
		Suffix = 's',
        Decimal = 10,
		Visible = false	
	})
	Player = BetterLani:CreateTextBox({
		Name = "Player",
		Tooltip = 'enter the player\'s USERNAME not DISPLAY'
	})
	Legit = BetterLani:CreateToggle({
		Name = "Legit",
		Darker = true,
		Default = true,
		Function = function(v)
			Delay.Object.Visible = v
		end
	})
end)
run(function()
	local BetterZeno
	local Delay
	local Distance
	local Targets
	local Angle
	local Sorts
	local ShockWaveChance
	math.randomseed(os.clock() * 1e6)
	local roll = math.random(0,100)
	BetterZeno = vape.Categories.Utility:CreateModule({
		Name = "BetterZeno",
		Tooltip = 'makes you play like yuta(demon at zeno for those who know ☠️☠️)',
		Function = function(callback)
			if store.equippedKit ~= "wizard" then
				vape:CreateNotification("BetterZeno","Kit required only!",8,"warning")
				return
			end
			if callback then
				repeat
		            local plrs = entitylib.AllPosition({
		                Range = Distance.Value,
		                Wallcheck = Targets.Walls.Enabled,
		                Part = "RootPart",
		                Players = Targets.Players.Enabled,
		                NPCs = Targets.NPCs.Enabled,
		                Sort = sortmethods[Sorts.Value]
		            })
		
		            local char = entitylib.character
		            local root = char.RootPart
		
		            if plrs then
		                local ent = plrs[1]
		                if ent and ent.RootPart then
		                    local delta = ent.RootPart.Position - root.Position
		                    local localFacing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		                    local angle = math.acos(localFacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
		                	if angle > (math.rad(Angle.Value) / 2) then task.wait(0.1); continue end
		                    local localPosition = root.Position
		                    local shootDir = CFrame.lookAt(localPosition, ent.RootPart.Position).LookVector
		                    localPosition = localPosition + shootDir * math.max((localPosition - ent.RootPart.Position).Magnitude - 16, 0)
							local ability = lplr:GetAttribute("WizardAbility")
							if not ability then
								task.wait(0.85)
								continue
							end
							local itemType = store.hand.tool.Name.itemType
							local targetPos = ent.RootPart.Position
							if bedwars.AbilityController:canUseAbility(ability) then
								bedwars.AbilityController:useAbility(ability,newproxy(true),{target = targetPos})
								 roll = math.random(0,100)
							end
							if itemType == "wizard_staff_2" or itemType == "wizard_staff_3" then
								if roll >= ShockWaveChance.Value then
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
							if itemType == "wizard_staff_3" then
								if roll >= math.min(100, ShockWaveChance.Value + ShockWaveChance.Value)then
									if bedwars.AbilityController:canUseAbility("LIGHTNING_STORM") then
										bedwars.AbilityController:useAbility("LIGHTNING_STORM",newproxy(true),{target = targetPos})
										 roll = math.random(0,100)
									end
								elseif roll >= ShockWaveChance.Value then
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
		            end
					task.wait(1 / Delay.GetRandomValue() - math.random())
				until not BetterZeno.Enabled
			end
		end
	})
    Targets = BetterZeno:CreateTargets({
        Players = true,
        NPCs = true,
        Walls = true
    })
	Sorts = BetterZeno:CreateDropdown({
		Name = "Sorts",
		List = {'Damage','Threat','Kit','Health','Angle'}
	})
    Angle = BetterZeno:CreateSlider({
        Name = "Angle",
        Min = 0,
        Max = 360,
        Default = math.random(120,180)
    })
	Delay = BetterZeno:CreateTwoSlider({
		Name = 'Delay',
		Min = 0.2,
		Max = 3,
		Suffix = 's',
        Decimal = 10,
		DefaultMin = 0.5,
		DefaultMax = 1
	})
    Distance = BetterZeno:CreateSlider({
        Name = "Range",
        Min = 1,
        Max = 18,
        Default = 25,
        Suffix = function(val) return val == 1 and "stud" or "studs" end
    })
    ShockWaveChance = BetterZeno:CreateSlider({
        Name = "ShockWave Chance",
        Min = 0,
        Max = 100,
        Default = 40,
    })
end)
run(function()
	local BetterWarden
	local Legit
	local Range
	local Delay
	local Angle
	local tip = ''
	if user == 'kolifyz' then
		tip = "makes you play like kolifyz(DEMON AT WARDEN BOI)"
	else
		tip = "makes you play like jewlifyz"
	end
	local function kitCollection(id, func, range, angle,d)
		local objs = type(id) == 'table' and id or collection(id, BetterWarden)
		repeat
			if entitylib.isAlive then
				local localPosition = entitylib.character.RootPart.Position
				for _, v in objs do
					if InfiniteFly.Enabled or not BetterWarden.Enabled then break end
					local part = not v:IsA('Model') and v or v.PrimaryPart
		            local delta = part.Position - localPosition
		            local localFacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
		            local a = math.acos(localFacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
		            if a > (math.rad(angle) / 2) then continue end
					if part and (part.Position - localPosition).Magnitude <= (range) then
						func(v)
					end
				end
			end
			task.wait(d)
		until not BetterWarden.Enabled
	end

	BetterWarden = vape.Categories.Utility:CreateModule({
		Name = "BetterWarden",
		Tooltip = tip,
		Function = function(callback)
			if store.equippedKit ~= "jailor" then
				vape:CreateNotification("BetterWarden","Kit required only!",8,"warning")
				return
			end
			if callback then
				local range = 0
				local angle = 0
				local d = 0
				if Legit.Enabled then
					range = 6
					angle = 120
					d = 1.115
				else
					range = Range.Value
					angle = Angle.Value
					d = (1 / Delay.GetRandomValue())
				end
				kitCollection('jailor_soul', function(v)
					bedwars.JailorController:collectEntity(lplr, v, 'JailorSoul')
				end, range, angle,d)
			end
		end
	})
	Range = BetterWarden:CreateSlider({
		Name = "Distance",
		Min = 1,
		Max = 12,
		Default = math.random(4,12),
		Visible = false
	})
	Angle = BetterWarden:CreateSlider({
		Name = "Angle",
		Min = 1,
		Max = 360,
		Default = 120,
		Visible = false
	})
	Delay = BetterWarden:CreateTwoSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 1,
		Suffix = 's',
        Decimal = 10,
		DefaultMin = 0.2,
		DefaultMax = 1,
		Visible = false
	})
	Legit = BetterWarden:CreateToggle({
		Name = "Legit",
		Darker = true,
		Default = true,
		Function = function(v)
			local V = (not v)
			Range.Object.Visible = V
			Delay.Object.Visible = V
			Angle.Object.Visible = V
		end
	})
end)
run(function()
	local DaveyAim
	local Range
	local AutoLaunch
	local AimTypes
	local AimMode

	local function getWorldFolder()
		local Map = workspace:WaitForChild("Map", math.huge)
		local Worlds = Map:WaitForChild("Worlds", math.huge)
		if not Worlds then return nil end
		return Worlds:GetChildren()[1]
	end

	DaveyAim = vape.Categories.Utility:CreateModule({
		Name = 'DaveyAim',
		Function = function(callback)
			if not callback then return end
			DaveyAim:Toggle(false)
            local worldFolder = getWorldFolder()
            if not worldFolder then return end
            local blocks = worldFolder:WaitForChild("Blocks")
			if blocks then
				for i, v in blocks:GetChildren() do
					if v.Name == "cannon" then
						local cannon = v
						local distance = (cannon.Position - entitylib.character.RootPart.Position).Magnitude
						if distance <= Range.Value then
							if AimTypes.Value == "Mouse" then
								local position
								local rayCheck = RaycastParams.new()
								rayCheck.RespectCanCollide = true
								local ray = cloneref(lplr:GetMouse()).UnitRay
								rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
								ray = workspace:Raycast(ray.Origin, ray.Direction * 10000, rayCheck)
								position = ray and ray.Position + Vector3.new(0, entitylib.character.HipHeight or 2, 0)
								position = CFrame.lookAlong(position, entitylib.character.RootPart.CFrame.LookVector)
								local delay = 0
								if AimMode.Value == "Fast" then
									delay = 0.005
								elseif AimMode.Value == "Normal" then
									delay = 0.1
								elseif AimMode.Value == "Slow" then
									delay = 0.125
								else
									delay = 0.105
								end
								task.wait(delay)
								bedwars.Client:Get('AimCannon'):SendToServer({
									cannonBlockPos = bedwars.BlockController:getBlockPosition(cannon.Position),
									lookVector = position
								})
								if AutoLaunch.Enabled then
									task.wait(math.random() * math.random() * Random.new():NextNumber() + delay)
									local call = bedwars.Client:Get('LaunchSelfFromCannon'):CallServer({cannonBlockPos = bedwars.BlockController:getBlockPosition(cannon.Position)})
									if call then
										local v30 = lplr.Character.PrimaryPart.AssemblyMass
										lplr.Character.PrimaryPart:ApplyImpulse(cannon:GetAttribute('LookVector') * (v30 == nil and 0 or v30) * 200)
										local pickaxe = getPickaxeSlot()
										if hotbarSwitch(pickaxe) or store.hand.tool.Name:lower():find("pickaxe") then
											bedwars.breakBlock(cannon)
											bedwars.breakBlock(cannon)
										end
									end
								end
							else
								local delay = 0
								if AimMode.Value == "Fast" then
									delay = 0.005
								elseif AimMode.Value == "Normal" then
									delay = 0.1
								elseif AimMode.Value == "Slow" then
									delay = 0.125
								else
									delay = 0.105
								end
								task.wait(delay)
								bedwars.Client:Get('AimCannon'):SendToServer({
									cannonBlockPos = bedwars.BlockController:getBlockPosition(cannon.Position),
									lookVector = gameCamera.CFrame.LookVector
								})
								if AutoLaunch.Enabled then
									task.wait(math.random() * math.random() * Random.new():NextNumber() + delay)
									local call = bedwars.Client:Get('LaunchSelfFromCannon'):CallServer({cannonBlockPos = bedwars.BlockController:getBlockPosition(cannon.Position)})
									if call then
										local v30 = lplr.Character.PrimaryPart.AssemblyMass
										lplr.Character.PrimaryPart:ApplyImpulse(cannon:GetAttribute('LookVector') * (v30 == nil and 0 or v30) * 200)
										local pickaxe = getPickaxeSlot()
										if hotbarSwitch(pickaxe) or store.hand.tool.Name:lower():find("pickaxe") then
											bedwars.breakBlock(cannon)
											bedwars.breakBlock(cannon)
										end
									end
								end
							end
						end
					end
				end
			else
				return
			end
		end
	})
	Range = DaveyAim:CreateSlider({
		Name = 'Range',
		Min = 0,
		Max = 16,
		Default = 12
	})
	if inputService.TouchEnabled then
		list = {'Camera'}
	else
		list = {'Camera','Mouse'}
	end
	AimTypes = DaveyAim:CreateDropdown({
		Name = "Aim Types",
		List = list,
		Default = 'Camera'
	})
	AimMode = DaveyAim:CreateDropdown({
		Name = "Aim Modes",
		List = {'Fast','Normal','Slow'},
		Default = 'Normal'
	})
	AutoLaunch = DaveyAim:CreateToggle({Name='Auto Launch',Default=false})
end)
run(function()
	local BetterElder
	local Range
	local Animations
	BetterElder = vape.Categories.Utility:CreateModule({
		Name = 'BetterElder',
		Function = function(callback)
			if callback then
			if store.equippedKit ~= "bigman" then
				vape:CreateNotification("BetterElder","Kit required only!",8,"warning")
				return
			end
			task.spawn(function()
				while BetterElder.Enabled do
					if not entitylib.isAlive then task.wait(0.1); continue end
					local character = entitylib.character
					if not character or not character.RootPart then task.wait(0.1); continue end
					local localPos = character.RootPart.Position
					local trees = collectionService:GetTagged("treeOrb")
					for _, obj in pairs(trees) do
						if obj then
							local Pos = obj.PrimaryPart.Position
							local distance = (localPos - Pos).Magnitude
							local range = (Range.Value or 8)
							if distance <= range then
								local waitTime = .854 
								task.wait(waitTime)
								if Animation.Enabled then
									bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.PUNCH)
									bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM)
									bedwars.SoundManager:playSound(bedwars.SoundList.CROP_HARVEST)
								end
								pcall(function()
									bedwars.Client:Get('ConsumeTreeOrb'):CallServer({treeOrbSecret = obj:GetAttribute("TreeOrbSecret")})
								end)
								task.wait(0.1)
							end
						end
					end
					task.wait(0.1)
				end
			end)
			end
		end
	})
	Range = BetterElder:CreateSlider({
		Name = "Distance",
		Min = 0,
		Max = 16,
		Default = 8,
		Suffix = "studs",
	})	
	Animations = BetterElder:CreateToggle({Name='Animations',Default=false})
end)
run(function()
	local LuciaSpy
	local IgnoreTeammates
	local CheckDespoit
	local util = require(replicatedStorage.TS.games.bedwars.kit.kits['piggy-bank']['piggy-bank-util']).PiggyBankUtil
	LuciaSpy = vape.Categories.Utility:CreateModule({
		Name = "LuciaSpy",
		Tooltip = 'notifys whenever a lucia has opened their pinata\nmay be annoying for some users',
		Function = function(callback)
			if callback then
				LuciaSpy:Clean(bedwars.Client:Get("PiggyBankIncrement"):Connect(function(Data)
					if not CheckDespoit.Enabled then
						--warn('ignored cuz im jewish')
						return
					end
					local Level = util.getStageFromCoins(Data.coin)
					Level = Level or 0
					vape:CreateNotification("LuciaSpy",`Someone has despoited {Data.coin} candy and is at level {Level}.`,8)
				end))	
				LuciaSpy:Clean(bedwars.Client:Get("PiggyBankPop"):Connect(function(self)
					local plr = self.awardedPlayer
					local rewards = util:getRewardsFromCoins(self.coins)
					local I = rewards[1]
					local D = rewards[2]
					local E = rewards[3]
					local irons = I and I.amount or 0
					local diamond = D and D.amount or 0
					local emeralds = E and E.amount or 0
					if plr then
						if IgnoreTeammates.Enabled then
							if plr.Team == lplr.Team then
								return
							else
								local plrName = plr.Name
								local str = plrName:sub(1, 1):upper()..plrName:sub(2) or 'NIL'
								local loot = irons.." iron's, "..diamond.." diamond's, and "..emeralds.." emerald's"
								vape:CreateNotification("LuciaSpy",`{str} has opened their pinata and got {loot}`,8)
							end
						else
							local plrName = plr.Name
							local str = plrName:sub(1, 1):upper()..plrName:sub(2) or 'NIL'
							local loot = irons.." iron's, "..diamond.." diamond's, and "..emeralds.." emerald's"
							vape:CreateNotification("LuciaSpy",`{str} has opened their pinata and got {loot}`,8)
						end
					end
				end))
			end
		end
	})
	IgnoreTeammates = LuciaSpy:CreateToggle({Name='Ignore Teammates',Default=true})
	CheckDespoit = LuciaSpy:CreateToggle({Name='Check Deposit',Default=false})

end)
run(function()
	local BetterMelody
    local Limits
    local Targetted
    local Angle
    local Distance
    local Delay
	local UpdateRate
	local Health
	BetterMelody = vape.Categories.Utility:CreateModule({
		Name = "BetterMelody",
		Tooltip = 'makes u godtier at melody boi',
		Function = function(callback)
			if callback then
				if store.equippedKit ~= 'melody' then
					notify('BetterMelody', 'Kit required only!', 6, 'warning')
					return
				end
				repeat
					if entitylib.isAlive then
						if Limits.Enabled then
							local tool = (store and store.hand and store.hand.tool) and store.hand.tool or nil
							if not tool or tool.Name ~= "guitar" then continue end
						end
						local plr = playersService:FindFirstChild(Targetted)
						if plr then
							if (plr.Character.HumanoidRootPart.Positionn - entitylib.character.RootPart).Magnitude <= (Distance.Value) then
								local root = entitylib.character.RootPart
								local delta = plr.Character.HumanoidRootPart.Position - root.Position
								local localfacing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
								local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
								if angle >= (math.rad(Angle.Value) / 2) then continue end
								if plr.Character:GetAttribute("Health") <= Health.Value then
									bedwars.Client:Get(remotes.GuitarHeal):SendToServer({
										healTarget = plr.Character
									})
									task.wait(1 / Delay.GetRandomValue())
								else
									task.wait(1 / Delay.GetRandomValue())
									continue
								end
							else
								continue
							end
						else
							continue
						end
					end
					task.wait(1 / UpdateRate.Value)
				until MelodyExploit.Enabled
			end
		end
	})
	Targetted = BetterMelody:CreateTextBox({
		Name = "Username",
		Tooltip = 'this must be the users USERNAME not DISPLAYNAME',
		Placeholder = 'Roblox'
	})
	Distance = BetterMelody:CreateSlider({
		Name = "Heal Distance",
		Min = 0,
		Max = 45,
		Default = 15,
		Decimal = 5,
		Suffix = function(v)
			if v == 1 then
				return 'stud'
			else
				return 'studs'
			end
		end
	})
	Angle = BetterMelody:CreateSlider({
		Name = "Angle",
		Min = 0,
		Max = 360,
		Default = 180
	})
	UpdateRate = BetterMelody:CreateSlider({
		Name = "Update Rate",
		Min = 0,
		Max = 120,
		Default = 60,
		Suffix = 'hz'
	})
	Health = BetterMelody:CreateSlider({
		Name = "Health",
		Min = 0,
		Max = 100,
		Default = 75,
		Suffix = '%',
		Decimal = 5,
	})	
	Delay = BetterMelody:CreateTwoSlider({
		Name = "Delay",
		Min = 0,
		Max = 2,
		DefaultMin = 0.2,
		DefaultMax = 0.7
	})
	Limits = BetterMelody:CreateToggle({Name="Limit to items"})

end)

run(function()
	local BedAlarm
	local PlayersNearBed = {}
	local currentPlayersNear= {}
	local LastNotificationTime= {}
	local bedPosition
	local function UpdateCurrentBedPOS()
		if workspace:FindFirstChild("MapCFrames") then
			local currentTeam =  lplr.Character:GetAttribute("Team")
			if workspace:FindFirstChild("MapCFrames") then
				local CFRameName = tostring(currentTeam).."_bed"
				return workspace:FindFirstChild("MapCFrames"):FindFirstChild(CFRameName).Value.Position
			end
		end
	end	
	local function start()
				for _, ent in entitylib.List do
					if ent.Targetable and ent.Player then
						local distance = (ent.RootPart.Position - bedPosition).Magnitude
						if distance <= 32 then
							currentPlayersNear[ent] = true
							local shouldNotify = false
							if not PlayersNearBed[ent] then
								shouldNotify = true
							end
							if shouldNotify then
								notif("BedAlarm",ent.Player.DisplayName or ent.Player.Name.."  is on your bed!",12,"alert")
							end
						end
					end
				end
				PlayersNearBed = currentPlayersNear
	end
	BedAlarm = vape.Categories.Render:CreateModule({
		Name = "BedAlarm",
		Function = function(callback)
			if callback then
				bedPosition = UpdateCurrentBedPOS()
				if not bedPosition then
					notif('BedAlarm', 'Cannot locate your bed!', 3, 'error')
					return
				end
				PlayersNearBed = {}
				LastNotificationTime = {}
				BedAlarm:Clean(runService.Heartbeat:Connect(start))
			else
				table.clear(PlayersNearBed)
				table.clear(LastNotificationTime)				
			end
		end
	})
end)
run(function()
	local TaxRemover
	local oldDispatch
	local oldtax
	local oldadded
	local olditems
	local oldhook
	local oldConnect
	TaxRemover = vape.Categories.Blatant:CreateModule({
		Name = "TaxRemover",
		Function = function(callback)
			if callback then
				oldtax = bedwars.ShopTaxController.isTaxed
				oldadded = bedwars.ShopTaxController.getAddedTax
				olditems = bedwars.ShopTaxController.getTaxedItems
				oldDispatch = bedwars.Store.dispatch
				task.spawn(function()
					bedwars.Store.dispatch = function(...)
						local arg = select(2, ...)
						if arg and typeof(arg) == 'table' and arg.type == 'IncrementTaxState'  then
							return false
						end 	
						return oldDispatch(...)
					end
				end)
				task.spawn(function()
					bedwars.ShopTaxController.isTaxed = function(...)
						return false
					end
				end)
				task.spawn(function()
					bedwars.ShopTaxController.getTaxedItems = function(...)
						return {}
					end
				end)
				task.spawn(function()
					bedwars.ShopTaxController.getAddedTax = function(...)
						return 0
					end
				end)

				task.spawn(function()
					if bedwars.ShopTaxController.taxStateUpdateEvent then
						oldConnect = bedwars.ShopTaxController.taxStateUpdateEvent.Connect
						bedwars.ShopTaxController.taxStateUpdateEvent.Connect = function() 
							return {Disconnect = function() end}
						end
					end
				end)
				task.spawn(function()
					bedwars.ShopTaxController.hasTax = false
					bedwars.ShopTaxController.taxedItems = {}
					bedwars.ShopTaxController.addedTaxMap = {}
				end)
			else
				bedwars.Store.dispatch = oldDispatch
				bedwars.ShopTaxController.isTaxed = oldtax
				bedwars.ShopTaxController.getAddedTax = oldadded
				bedwars.ShopTaxController.getTaxedItems = olditems
				bedwars.ShopTaxController.taxStateUpdateEvent.Connect = oldConnect
				oldDispatch = nil
				oldtax = nil
				oldadded = nil
				olditems = nil
				oldConnect = nil
			end
		end
	})
end)
run(function()
	local FishermanSpy
	local IgnoreTeammates

	local FishNames = {
		fish_iron = "Iron Fish",
		fish_diamond = "Diamond Fish",
		fish_emerald = "Emerald Fish",
		fish_special = "Special Fish",
		fish_gold = "Gold Fish",
	}	
	
	FishermanSpy = vape.Categories.Utility:CreateModule({
		Name = "FishermanSpy",
		Tooltip = 'notifys whenever a fisher has caught something',
		Function = function(callback)
			if callback then
				bedwars.Client:WaitFor("FishCaught"):andThen(function(rbx)
					FishermanSpy:Clean(rbx:Connect(function(tbl)
						local char = tbl.catchingPlayer.Character
						local fish = tbl.dropData.fishModel
						local plrName = char.Name
						local str = plrName:sub(1, 1):upper()..plrName:sub(2) or 'NIL'
						local strfish = FishNames[tostring(fish)] or 'NIL Fish'
						if IgnoreTeammates.Enabled then
							local currentTeam = lplr.Team
							local currentplr = playersService:GetPlayerFromCharacter(char)
							if currentplr.Team == currentTeam then
							else
								notif("FishermanSpy",`{str} has caught an {strfish}`,8)
							end
						else
							notif("FishermanSpy",`{str} has caught an {strfish}`,8)
						end
					end))
				end)
			end
		end
	})
	IgnoreTeammates = FishermanSpy:CreateToggle({Name='Ignore Teammates',Default=true})
end)
run(function()
	local BetterUma
	local CycleMode
	local AttackMode
	local HealMode
	local Range
	local AutoSummon
	local TargetVisualiser
	local PriorityDropdown
	local selectedTarget = nil
	local targetOutline = nil
	local hovering = false
	local old
	local summonThread = nil
	local currentAffinity = nil
	
	local priorityOrders = {
		['Emerald > Diamond > Iron'] = {'emerald', 'diamond', 'iron'},
		['Diamond > Emerald > Iron'] = {'diamond', 'emerald', 'iron'},
		['Iron > Diamond > Emerald'] = {'iron', 'diamond', 'emerald'}
	}
	
	local function updateOutline(target)
		if targetOutline then
			targetOutline:Destroy()
			targetOutline = nil
		end
		if target and TargetVisualiser.Enabled then
			targetOutline = Instance.new("Highlight")
			targetOutline.FillTransparency = 0.5
			targetOutline.OutlineColor = Color3.fromRGB(255, 215, 0)
			targetOutline.OutlineTransparency = 0
			targetOutline.Adornee = target
			targetOutline.Parent = target
		end
	end
	
	local function clearOutline()
		if targetOutline then
			targetOutline:Destroy()
			targetOutline = nil
		end
	end
	
	local function getClosestLoot(originPos)
		local closest, closestDist = nil, math.huge
		local priorityOrder = priorityOrders[PriorityDropdown.Value] or priorityOrders['Emerald > Diamond > Iron']
		
		for _, itemType in priorityOrder do
			for _, drop in collectionService:GetTagged('ItemDrop') do
				if not drop:FindFirstChild('Handle') then continue end
				
				local itemName = drop.Name:lower()
				if itemName:find(itemType) then
					local dist = (drop.Handle.Position - originPos).Magnitude
					if dist <= Range.Value and dist < closestDist then
						closest = drop.Handle
						closestDist = dist
					end
				end
			end
			
			if closest then return closest end
		end
		
		return closest
	end
	
	local function switchAffinity(targetAffinity)
		local currentAff = lplr:GetAttribute('SpiritSummonerAffinity')
		if currentAff ~= targetAffinity then
			pcall(function()
				if bedwars.AbilityController:canUseAbility('spirit_summoner_switch_affinity') then
					bedwars.AbilityController:useAbility('spirit_summoner_switch_affinity')
					task.wait(0.1)
				end
			end)
		end
	end
	
	local function getTeammateHealth(plr)
		if not plr.Character then return 100 end
		local health = plr.Character:GetAttribute('Health') or 100
		local maxHealth = plr.Character:GetAttribute('MaxHealth') or 100
		return health, maxHealth
	end
	
	local function getLowHealthTeammate()
		local myTeam = lplr:GetAttribute('Team')
		if not myTeam then return nil end
		
		for _, plr in game:GetService('Players'):GetPlayers() do
			if plr ~= lplr and plr:GetAttribute('Team') == myTeam then
				local health, maxHealth = getTeammateHealth(plr)
				if health <= 40 and health > 0 then
					return plr
				end
			end
		end
		return nil
	end
	
	local function startAutoSummon()
		if summonThread then
			task.cancel(summonThread)
			summonThread = nil
		end
		
		summonThread = task.spawn(function()
			while BetterUma.Enabled and AutoSummon.Enabled do
				if not entitylib.isAlive then
					task.wait(0.1)
					continue
				end
				
				local hasStaff = false
				for _, item in store.inventory.inventory.items do
					if item.itemType == 'spirit_staff' then
						hasStaff = true
						break
					end
				end
				
				if hasStaff then
					local attackSpirits = lplr:GetAttribute('ReadySummonedAttackSpirits') or 0
					local healSpirits = lplr:GetAttribute('ReadySummonedHealSpirits') or 0
					local totalSpirits = attackSpirits + healSpirits
					
					if totalSpirits < 10 then
						local hasStone = false
						for _, item in store.inventory.inventory.items do
							if item.itemType == 'summon_stone' then
								hasStone = true
								break
							end
						end
						
						if hasStone then
							pcall(function()
								if bedwars.AbilityController:canUseAbility('summon_attack_spirit') then
									bedwars.AbilityController:useAbility('summon_attack_spirit')
									task.wait(0.5)
								end
							end)
						end
					end
				end
				
				task.wait(0.2)
			end
		end)
	end
	
	local function stopAutoSummon()
		if summonThread then
			task.cancel(summonThread)
			summonThread = nil
		end
	end
	
	BetterUma = vape.Categories.Utility:CreateModule({
		Name = 'BetterUma',
		Function = function(callback)
			if callback then
				old = bedwars.ProjectileController.calculateImportantLaunchValues
				bedwars.ProjectileController.calculateImportantLaunchValues = function(...)
					hovering = true
					local self, projmeta, worldmeta, origin, shootpos = ...
					
					if not (projmeta.projectile == 'attack_spirit' or projmeta.projectile == 'heal_spirit') then
						hovering = false
						clearOutline()
						return old(...)
					end
					
					local originPos = entitylib.isAlive and (shootpos or entitylib.character.RootPart.Position) or Vector3.zero
					local target = nil
					local targetPos = nil
					
					if CycleMode.Enabled then
						local targetLoot = getClosestLoot(originPos)
						if targetLoot and (targetLoot.Position - originPos).Magnitude <= Range.Value then
							target = targetLoot
							targetPos = targetLoot.Position
							updateOutline(targetLoot)
						else
							clearOutline()
						end
					end
					
					if HealMode.Enabled and not CycleMode.Enabled then
						local lowTeammate = getLowHealthTeammate()
						if lowTeammate and lowTeammate.Character and lowTeammate.Character.PrimaryPart then
							switchAffinity('heal')
							local dist = (lowTeammate.Character.PrimaryPart.Position - originPos).Magnitude
							if dist <= Range.Value then
								target = lowTeammate.Character.PrimaryPart
								targetPos = lowTeammate.Character.PrimaryPart.Position + Vector3.new(0, 2, 0)
								updateOutline(lowTeammate.Character)
							else
								clearOutline()
							end
						else
							clearOutline()
						end
					end
					
					if AttackMode.Enabled and not CycleMode.Enabled and not (HealMode.Enabled and getLowHealthTeammate()) then
						switchAffinity('attack')
						local plr = entitylib.EntityMouse({
							Part = 'RootPart',
							Range = 1000,
							Players = true,
							NPCs = true,
							Wallcheck = false,
							Origin = originPos
						})
						
						if plr and plr.RootPart and (plr.RootPart.Position - originPos).Magnitude <= Range.Value then
							target = plr.RootPart
							targetPos = plr.RootPart.Position + Vector3.new(0, 2, 0)
							updateOutline(plr.Character)
						else
							clearOutline()
						end
					end
					
					if target and targetPos then
						local pos = shootpos or self:getLaunchPosition(origin)
						if not pos then
							hovering = false
							clearOutline()
							return old(...)
						end
						
						local meta = projmeta:getProjectileMeta()
						local lifetime = (worldmeta and meta.predictionLifetimeSec or meta.lifetimeSec or 3)
						local gravity = (meta.gravitationalAcceleration or 196.2) * projmeta.gravityMultiplier
						local projSpeed = (meta.launchVelocity or 100)
						local offsetpos = pos + projmeta.fromPositionOffset
						
						local direction = (targetPos - offsetpos).Unit
						local distance = (targetPos - offsetpos).Magnitude
						local timeToReach = distance / projSpeed
						local dropAmount = 0.5 * gravity * (timeToReach * timeToReach)
						local adjustedTarget = targetPos + Vector3.new(0, dropAmount, 0)
						
						local newlook = CFrame.new(offsetpos, adjustedTarget)
						
						hovering = false
						return {
							initialVelocity = newlook.LookVector * projSpeed,
							positionFrom = offsetpos,
							deltaT = lifetime,
							gravitationalAcceleration = gravity,
							drawDurationSeconds = 5
						}
					end
					
					hovering = false
					clearOutline()
					return old(...)
				end
				
				if AutoSummon.Enabled then
					startAutoSummon()
				end
			else
				if old then
					bedwars.ProjectileController.calculateImportantLaunchValues = old
				end
				clearOutline()
				stopAutoSummon()
				selectedTarget = nil
			end
		end,
		Tooltip = 'Spirit Summoner automation - lock onto loot, enemies, or heal teammates'
	})
	
	CycleMode = BetterUma:CreateToggle({
		Name = 'Cycle',
		Function = function(callback)
			if callback then
				if AttackMode.Enabled then
					AttackMode:Toggle()
				end
				if HealMode.Enabled then
					HealMode:Toggle()
				end
				PriorityDropdown.Object.Visible = true
			else
				PriorityDropdown.Object.Visible = false
				clearOutline()
			end
		end,
		Tooltip = 'Lock onto loot (iron/diamond/emerald) with priority system'
	})
	
	PriorityDropdown = BetterUma:CreateDropdown({
		Name = 'Loot Priority',
		List = {'Emerald > Diamond > Iron', 'Diamond > Emerald > Iron', 'Iron > Diamond > Emerald'},
		Default = 'Emerald > Diamond > Iron',
		Darker = true
	})
	PriorityDropdown.Object.Visible = false
	
	AttackMode = BetterUma:CreateToggle({
		Name = 'Attack',
		Function = function(callback)
			if callback then
				if CycleMode.Enabled then
					CycleMode:Toggle()
				end
				if HealMode.Enabled then
					HealMode:Toggle()
				end
				clearOutline()
			else
				clearOutline()
			end
		end,
		Tooltip = 'Lock onto enemies and attack them'
	})
	
	HealMode = BetterUma:CreateToggle({
		Name = 'Heal',
		Function = function(callback)
			if callback then
				if CycleMode.Enabled then
					CycleMode:Toggle()
				end
				if AttackMode.Enabled then
					AttackMode:Toggle()
				end
				clearOutline()
			else
				clearOutline()
			end
		end,
		Tooltip = 'Heal teammates below 40 HP (switches to attack above 50 HP)'
	})
	
	Range = BetterUma:CreateSlider({
		Name = 'Lock Range',
		Min = 10,
		Max = 70,
		Default = 70,
		Tooltip = 'Maximum distance to lock onto targets'
	})
	
	AutoSummon = BetterUma:CreateToggle({
		Name = 'Auto Summon',
		Function = function(callback)
			if callback and BetterUma.Enabled then
				startAutoSummon()
			else
				stopAutoSummon()
			end
		end,
		Default = true,
		Tooltip = 'Automatically summons spirits when you have summon stones'
	})
	
	TargetVisualiser = BetterUma:CreateToggle({
		Name = 'Target Visualiser',
		Function = function(callback)
			if not callback then
				clearOutline()
			end
		end,
		Default = true,
		Tooltip = 'Shows gold outline on locked target'
	})
end)



run(function()
	local BetterFrosty
	local Angle
	local Sorts
	local Distance 
	local Targets
	local Limits
	local Delay
	local CanShoot = true
	BetterFrosty = vape.Categories.Utility:CreateModule({
		Name = "BetterFrosty",
		Tooltip = 'makes you good at frosty like lumpy(he frostied for me when i was ranking with him lol)',
		Function = function(callback)
			if store.equippedKit ~= "frosty" then
				vape:CreateNotification("BetterFrosty","Kit required only!",8,"warning")
				return
			end
			if callback then
				repeat
					local item = getItem("frosty_snowball")
					if not item then task.wait(0.1); continue end
					local plrs = entitylib.AllPosition({
						Range = Distance.Value,
						Wallcheck = Targets.Walls.Enabled,
						Part = "RootPart",
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Limit = 1,
						Sort = sortmethods[Sorts.Value]
					})
					local char = entitylib.character
					local root = char.RootPart
					if plrs then
						local ent = plrs[1]
						if ent and ent.RootPart then
							local delta = ent.RootPart.Position - root.Position
							local localFacing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
							local angle = math.acos(localFacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
							if angle > (math.rad(Angle.Value) / 2) then continue end
							if Limits.Enabled then
								if store.hand.toolType ~= "frosty_snowball" then
									continue
								end
							end
							if item and CanShoot then
								task.wait(1 / Delay.GetRandomValue())		
								local meta = bedwars.ProjectileMeta.frosty_snowball_1
								local calc = prediction.SolveTrajectory(pos, meta.launchVelocity, meta.gravitationalAcceleration, ent.RootPart.Velocity, Vector3.zero, workspace.Gravity, 0, 0)
								if calc then
									local dir = CFrame.lookAt(pos, calc).LookVector * meta.launchVelocity
									PR:InvokeServer(item.tool, meta, pos, dir)     
									CanShoot = false
									task.wait(1 / Delay.GetRandomValue() - math.random())
									CanShoot = true
								end
							end
						end
					end
					task.wait(1 / Delay.GetRandomValue())
				until not BetterFrosty.Enabled
			end
		end
	})
	Targets = BetterFrosty:CreateTargets({Players = true,NPCs = true,Walls = true})
	Distance = BetterFrosty:CreateSlider({
		Name = "Range",
		Min = 1,
		Max = 42,
		Default = 18,
		Suffix = "Studs"
	})
	Delay = BetterFrosty:CreateTwoSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Decimal = 10,
		Suffix = "s",
		DefaultMin = 0.2,
		DefaultMax = 1
	})
	Angle = BetterFrosty:CreateSlider({
		Name = "Angle",
		Min = 1,
		Max = 360,
		Default = 120
	})
	Limits = BetterFrosty:CreateToggle({Name='Limit to items',Default=true})
	Sorts = BetterFrosty:CreateDropdown({
		Name = "Sorts",
		List = {'Damage','Threat','Kit','Health','Angle'}
	})
end)
run(function()
	local Clutch
	local UseBlacklisted_Blocks
	local blacklisted
	local Speed
	local LimitToItems
	local RequireMouse
	local SilentAim
	local lastPlace = 0
	local clutchCount = 0
	local lastResetTime = 0
	local function GetBlocks()
		if store.hand.toolType == 'block' then
			return store.hand.tool.Name, store.hand.amount
		elseif (not LimitToItems.Enabled) then
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

	local function callPlace(blockpos, block, rotate)
		task.spawn(bedwars.placeBlock, blockpos, block, rotate)
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

	Clutch = vape.Categories.World:CreateModule({
		Name = 'Clutch',
		Function = function(callback)
			if callback then
				Clutch:Clean(runService.Heartbeat:Connect(function()
					if not entitylib.isAlive then return end
					local root = entitylib.character.RootPart
					local blocks = select(1, GetBlocks())
					if not blocks then return end
					
					if blocks and not UseBlacklisted_Blocks.Enabled then
						for i,v in blacklisted.ListEnabled do
							if blocks == v then
								return																																																																																																																																																																									
							end																																																																																																																																																																												
						end
					end
					
					if RequireMouse.Enabled and not inputService:IsMouseButtonPressed(0) then return end

					
					local vy = root.Velocity.Y
					local now = os.clock()
					
					if (now - lastResetTime) > 5 then
						clutchCount = 0
						lastResetTime = now
					end
					
					local cooldown = math.clamp(HoldBase - (Speed.Value * 0.015), 0.01, HoldBase)
					
					if vy < -6 and (now - lastPlace) > cooldown then
						local target = roundPos(root.Position - Vector3.new(0, entitylib.character.HipHeight + 4.5, 0))
						local exists, blockpos = getPlacedBlock(target)
						
						if not exists then
							local prox = blockProximity(target)
							local placePos = prox or (target * 3)
							
							callPlace(placePos, blocks, false)
							lastPlace = now
							clutchCount = clutchCount + 1
							
							
							if SilentAim.Enabled then
								local camera = workspace.CurrentCamera
								local camCFrame = camera and camera.CFrame
								local camType = camera and camera.CameraType
								local camSubject = camera and camera.CameraSubject
								local lv = root.CFrame.LookVector
								local newLook = -Vector3.new(lv.X, 0, lv.Z).Unit
								local rootPos = root.Position
								root.CFrame = CFrame.new(rootPos, rootPos + newLook)
								if camera and camCFrame then
									camera.CameraType = camType
									camera.CameraSubject = camSubject
									camera.CFrame = camCFrame
								end
							end
						end
					end
				end))
			end
		end,
		Tooltip = 'automatically\'s places a block when falling to clutch'
	})
	UseBlacklisted_Blocks = Clutch:CreateToggle({
		Name = "Use Blacklisted Blocks",
		Default = false,
		Tooltip = "Allows clutching with blacklisted blocks"
	})
	blacklisted = Clutch:CreateTextList({
		Name = "Blacklisted Blocks",
		Placeholder = "tnt"
	})
	Speed = Clutch:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 15,
		Default = 8,
		Tooltip = 'How fast it places the blocks'
	})
	LimitToItems = Clutch:CreateToggle({
		Name = 'Limit to items',
		Default = false,
		Tooltip = "Only clutch when holding blocks"
	})
	RequireMouse = Clutch:CreateToggle({
		Name = 'Require mouse down',
		Default = false,
		Tooltip = "Only clutch when holding left click"
	})
	SilentAim = Clutch:CreateToggle({
		Name = 'SilentAim',
		Default = false,
		Tooltip = "Corrects ur position when placing blocks"
	})
end)
run(function()
	local DamageBoost
	local SM
	local old = nil
	local NewSpeed = 0
	local speed = nil
	DamageBoost = vape.Categories.Combat:CreateModule({
		Name = 'DamageBoost',
		Tooltip = 'makes you little bit faster by taking knockback\nmay anti cheat',
		Function = function(callback)
			if callback then
				old = bedwars.KnockbackUtil.applyKnockback
				bedwars.KnockbackUtil.applyKnockback = function(...)
					if entitylib.isAlive then
						if speed then
							speed = speed
						else
							speed = lplr.Character.Humanoid.WalkSpeed
						end
						
						local OldSpeed = SM.Value / 1000
						OldSpeed = OldSpeed - (math.random(1,2) - math.random())
						if OldSpeed < 0 then
							OldSpeed = OldSpeed * -1
						end
						NewSpeed = NewSpeed + OldSpeed
						lplr.Character.Humanoid.WalkSpeed = NewSpeed
						task.delay(6,function()
							lplr.Character.Humanoid.WalkSpeed = speed
							speed = nil
						end)
						return old(...)
					end
					
				end
			else
				bedwars.KnockbackUtil.applyKnockback = old
				old = nil
				if speed then
					lplr.Character.Humanoid.WalkSpeed = speed
				end
			end
		end
	})
	SM = DamageBoost:CreateSlider({
		Name = "Speed Mutipler",
		Min = 1,
		Max = 1000,
		Default = 250,
		Suffix = "ms",
	})	
end)
local Attacking
run(function()
	local Killaura
	local Targets
	local Sort
	local SwingRange
	local AttackRange
	local ChargeTime
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
	local RangeColor
	local killaurarangecircle
	local killaurarangecirclepart
	local RangeVisualizerSize = 18
	local killaurarangecircleconn
	local Limit
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
			if (tick() - bedwars.SwordController.lastSwing) > 0.2 then return false end
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

				if Animation.Enabled and not (identifyexecutor and table.find({'Argon', 'Delta'}, ({identifyexecutor()})[1])) then
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
local path for i,v in game:GetService("ReplicatedStorage"):GetDescendants() do if v.Name == "SetInvItem" and v:IsA("RemoteFunction") then path = v break end end path:InvokeServer({hand = sword.tool})
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
									if killaurarangecirclepart then
										cloneref(game:GetService('TweenService')):Create(killaurarangecirclepart,TweenInfo.new(0.5,Enum.EasingStyle.Linear),{Transparency=0}):Play()
					                end
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
									swingCooldown = tick()
									bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
									store.attackReach = (delta.Magnitude * 100) // 1 / 100
									store.attackReachUpdate = tick() + 1

									if delta.Magnitude < 14.4 and ChargeTime.Value > 0.11 then
										AnimDelay = tick()
									end

									AttackRemote:FireServer({
										weapon = sword.tool,
										chargedAttack = {chargeRatio = 0},
										lastSwingServerTimeDelta = 0.5,
										entityInstance = v.Character,
										validate = {
											raycast = {
												cameraPosition = {value = pos},
												cursorDirection = {value = dir}
											},
											targetPosition = {value = actualRoot.Position},
											selfPosition = {value = pos}
										}
									})
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
				if killaurarangecirclepart then
					cloneref(game:GetService('TweenService')):Create(killaurarangecirclepart,TweenInfo.new(0.5,Enum.EasingStyle.Linear),{Transparency=1}):Play()
				end
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
	SwingRange = Killaura:CreateSlider({
		Name = 'Swing range',
		Min = 1,
		Max = 18,
		Default = 18,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = 18,
		Default = 18,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	ChargeTime = Killaura:CreateSlider({
		Name = 'Swing time',
		Min = 0,
		Max = 0.5,
		Default = 0.04,
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
		Max = 120,
		Default = 60,
		Suffix = 'hz'
	})
	MaxTargets = Killaura:CreateSlider({
		Name = 'Max targets',
		Min = 1,
		Max = 5,
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
	RangeColor = Killaura:CreateColorSlider({
		Name = "Range Color",
		Visible = false,
		Function = function(hue, sat, val, o) 
			if killaurarangecirclepart then 
				killaurarangecirclepart.Color = Color3.fromHSV(hue, sat, val)
				killaurarangecirclepart.Transparency = 1 - o
			end
		end,
		Default = 1
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
	killaurarangecircle = Killaura:CreateToggle({
		Name = "Range Visualizer",
		Function = function(callback)
			RangeColor.Object.Visible = callback
			if callback then
				if killaurarangecirclepart == nil then
					if vape.ThreadFix then
					setthreadidentity(8)
				    end
					killaurarangecirclepart = Instance.new("MeshPart")
					killaurarangecirclepart.Name = "KillauraVisualizer"
					killaurarangecirclepart.MeshId = "rbxassetid://3726303797"
					killaurarangecirclepart.Color = Color3.fromRGB(255, 0, 0)
					killaurarangecirclepart.CanCollide = false
					killaurarangecirclepart.Anchored = true
					killaurarangecirclepart.CanTouch = false
					killaurarangecirclepart.Material = Enum.Material.Neon
					killaurarangecirclepart.Size = Vector3.new(18 * 0.7, 0.01, 18 * 0.7)
					killaurarangecirclepart.Transparency = 1
					killaurarangecirclepart.Parent = gameCamera
					--bedwars.QueryUtil:setQueryIgnored(killaurarangecirclepart, true)--ererer skill issue
				end
	
				if killaurarangecircleconn then
					killaurarangecircleconn:Disconnect()
				end
	
				killaurarangecircleconn = runService.RenderStepped:Connect(function()
					local char = lplr.Character
					if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") and killaurarangecirclepart then
						local offset = Vector3.new(0, char.Humanoid.HipHeight, 0)
						if (killaurarangecirclepart and killaurarangecirclepart.CFrame and killaurarangecirclepart) then
						killaurarangecirclepart.CFrame = entitylib.isAlive and entitylib.character.HumanoidRootPart.CFrame - offset
					    end
					end
				end)
			else
				if killaurarangecircleconn then
					killaurarangecircleconn:Disconnect()
					killaurarangecircleconn = nil
				end
				if killaurarangecirclepart then
					killaurarangecirclepart:Destroy()
					killaurarangecirclepart = nil
				end
			end
		end
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
	--[[LegitAura = Killaura:CreateToggle({
		Name = 'Swing only',
		Tooltip = 'Only attacks while swinging manually'
	})]]
end)