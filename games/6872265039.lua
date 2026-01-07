--This watermark is used to delete the file if its cached, remove it to make the file persist after OSVPrivate updates.
--This watermark is used to delete the file if its cached, remove it to make the file persist after OSVPrivate updates.
local run = function(func) func() end
local cloneref = cloneref or function(obj) return obj end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local inputService = cloneref(game:GetService('UserInputService'))

local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity
local sessioninfo = vape.Libraries.sessioninfo
local bedwars = {}

local function notif(...)
	return vape:CreateNotification(...)
end

run(function()
	local function dumpRemote(tab)
		local ind = table.find(tab, 'Client')
		return ind and tab[ind + 1] or ''
	end

	local KnitInit, Knit
	repeat
		KnitInit, Knit = pcall(function() return debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 9) end)
		if KnitInit then break end
		task.wait()
	until KnitInit
	if not debug.getupvalue(Knit.Start, 1) then
		repeat task.wait() until debug.getupvalue(Knit.Start, 1)
	end
	local Flamework = require(replicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out).Flamework
	local Client = require(replicatedStorage.TS.remotes).default.Client

	bedwars = setmetatable({
		Client = Client,
		CrateItemMeta = debug.getupvalue(Flamework.resolveDependency('client/controllers/global/reward-crate/crate-controller@CrateController').onStart, 3),
		Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore
	}, {
		__index = function(self, ind)
			rawset(self, ind, Knit.Controllers[ind])
			return rawget(self, ind)
		end
	})

	local kills = sessioninfo:AddItem('Kills')
	local beds = sessioninfo:AddItem('Beds')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')

	vape:Clean(function()
		table.clear(bedwars)
	end)
end)

for _, v in vape.Modules do
	if v.Category == 'Combat' or v.Category == 'Minigames' then
		vape:Remove(i)
	end
end

run(function()
	local Sprint
	local old
	
	Sprint = vape.Categories.Combat:CreateModule({
		Name = 'Sprint',
		Function = function(callback)
			if callback then
				if inputService.TouchEnabled then pcall(function() lplr.PlayerGui.MobileUI['2'].Visible = false end) end
				old = bedwars.SprintController.stopSprinting
				bedwars.SprintController.stopSprinting = function(...)
					local call = old(...)
					bedwars.SprintController:startSprinting()
					return call
				end
				Sprint:Clean(entitylib.Events.LocalAdded:Connect(function() bedwars.SprintController:stopSprinting() end))
				bedwars.SprintController:stopSprinting()
			else
				if inputService.TouchEnabled then pcall(function() lplr.PlayerGui.MobileUI['2'].Visible = true end) end
				bedwars.SprintController.stopSprinting = old
				bedwars.SprintController:stopSprinting()
			end
		end,
		Tooltip = 'Sets your sprinting to true.'
	})
end)
	
run(function()
	local AutoGamble
	
	AutoGamble = vape.Categories.World:CreateModule({
		Name = 'AutoGamble',
		Function = function(callback)
			if callback then
				AutoGamble:Clean(bedwars.Client:GetNamespace('RewardCrate'):Get('CrateOpened'):Connect(function(data)
					if data.openingPlayer == lplr then
						local tab = bedwars.CrateItemMeta[data.reward.itemType] or {displayName = data.reward.itemType or 'unknown'}
						notif('AutoGamble', 'Won '..tab.displayName, 5)
					end
				end))
	
				repeat
					if not bedwars.CrateAltarController.activeCrates[1] then
						for _, v in bedwars.Store:getState().Consumable.inventory do
							if v.consumable:find('crate') then
								bedwars.CrateAltarController:pickCrate(v.consumable, 1)
								task.wait(1.2)
								if bedwars.CrateAltarController.activeCrates[1] and bedwars.CrateAltarController.activeCrates[1][2] then
									bedwars.Client:GetNamespace('RewardCrate'):Get('OpenRewardCrate'):SendToServer({
										crateId = bedwars.CrateAltarController.activeCrates[1][2].attributes.crateId
									})
								end
								break
							end
						end
					end
					task.wait(1)
				until not AutoGamble.Enabled
			end
		end,
		Tooltip = 'Automatically opens lucky crates, piston inspired!'
	})
end)
local TrollMode = vape.Categories.Exploits:CreateModule({
    Name = "TrollMode",
    Function = function(callback)
        if callback then
            -- Make everyone's head spin
            for _, player in pairs(playersService:GetPlayers()) do
                if player.Character and player.Character:FindFirstChild("Head") then
                    local spin = Instance.new("BodyAngularVelocity")
                    spin.AngularVelocity = Vector3.new(0, 50, 0)
                    spin.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                    spin.Parent = player.Character.Head
                    spin.Name = "TrollSpin"
                end
            end
            
            -- Make screen shake
            local shakeIntensity = 10
            local connection
            connection = runService.RenderStepped:Connect(function()
                gameCamera.CFrame = gameCamera.CFrame * CFrame.Angles(
                    math.rad(math.random(-shakeIntensity, shakeIntensity)) * 0.01,
                    math.rad(math.random(-shakeIntensity, shakeIntensity)) * 0.01,
                    math.rad(math.random(-shakeIntensity, shakeIntensity)) * 0.01
                )
            end)
            
            -- Random sound effects
            local sounds = {
                "rbxassetid://911089837", -- Vine boom
                "rbxassetid://138081500", -- Windows XP error
                "rbxassetid://131147549", -- Bruh sound
                "rbxassetid://2767098492" -- Oof
            }
            
            task.spawn(function()
                while TrollMode.Enabled do
                    task.wait(math.random(2, 5))
                    bedwars.SoundManager:playSound(sounds[math.random(1, #sounds)], {
                        position = gameCamera.CFrame.Position
                    })
                end
            end)
            
            -- Invert colors occasionally
            task.spawn(function()
                while TrollMode.Enabled do
                    task.wait(math.random(3, 7))
                    local colorCorrection = Instance.new("ColorCorrectionEffect")
                    colorCorrection.Parent = game:GetService("Lighting")
                    colorCorrection.TintColor = Color3.new(1, 0, 1) -- Pink tint
                    colorCorrection.Saturation = -1
                    task.wait(0.5)
                    colorCorrection:Destroy()
                end
            end)
            
            -- Store connections for cleanup
            TrollMode.Connections = {
                playersService.PlayerAdded:Connect(function(player)
                    player.CharacterAdded:Connect(function(character)
                        task.wait(0.5)
                        if TrollMode.Enabled and character:FindFirstChild("Head") then
                            local spin = Instance.new("BodyAngularVelocity")
                            spin.AngularVelocity = Vector3.new(0, 50, 0)
                            spin.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                            spin.Parent = character.Head
                            spin.Name = "TrollSpin"
                        end
                    end)
                end),
                connection
            }
        else
            -- Cleanup
            for _, player in pairs(playersService:GetPlayers()) do
                if player.Character and player.Character:FindFirstChild("Head") then
                    local spin = player.Character.Head:FindFirstChild("TrollSpin")
                    if spin then spin:Destroy() end
                end
            end
            
            for _, conn in pairs(TrollMode.Connections or {}) do
                conn:Disconnect()
            end
        end
    end,
    Tooltip = "Troll everyone with funny effects"
})

local RainbowSky = TrollMode:CreateToggle({
    Name = "Rainbow Skybox",
    Function = function(callback)
        if callback then
            local sky = Instance.new("Sky")
            sky.Parent = game:GetService("Lighting")
            sky.CelestialBodiesShown = false
            
            local hue = 0
            local connection
            connection = runService.RenderStepped:Connect(function()
                hue = (hue + 0.001) % 1
                local color = Color3.fromHSV(hue, 1, 1)
                
                sky.SkyboxBk = "rbxassetid://3010081835"
                sky.SkyboxDn = "rbxassetid://3010082122"
                sky.SkyboxFt = "rbxassetid://3010081835"
                sky.SkyboxLf = "rbxassetid://3010081835"
                sky.SkyboxRt = "rbxassetid://3010081835"
                sky.SkyboxUp = "rbxassetid://3010081835"
                
                game:GetService("Lighting").Ambient = color
                game:GetService("Lighting").OutdoorAmbient = color
            end)
            
            TrollMode.Connections = TrollMode.Connections or {}
            table.insert(TrollMode.Connections, connection)
        else
            local sky = game:GetService("Lighting"):FindFirstChildOfClass("Sky")
            if sky then sky:Destroy() end
        end
    end
})

local GiantHeads = TrollMode:CreateToggle({
    Name = "Giant Heads",
    Function = function(callback)
        if callback then
            for _, player in pairs(playersService:GetPlayers()) do
                if player.Character and player.Character:FindFirstChild("Head") then
                    player.Character.Head.Mesh.Scale = Vector3.new(5, 5, 5)
                end
            end
        else
            for _, player in pairs(playersService:GetPlayers()) do
                if player.Character and player.Character:FindFirstChild("Head") then
                    player.Character.Head.Mesh.Scale = Vector3.new(1, 1, 1)
                end
            end
        end
    end
})

local RandomTeleport = TrollMode:CreateToggle({
    Name = "Random Teleport",
    Function = function(callback)
        if callback then
            task.spawn(function()
                while TrollMode.Enabled and RandomTeleport.Enabled do
                    task.wait(math.random(5, 10))
                    if entitylib.isAlive then
                        local randomPos = Vector3.new(
                            math.random(-100, 100),
                            math.random(50, 100),
                            math.random(-100, 100)
                        )
                        entitylib.character.RootPart.CFrame = CFrame.new(randomPos)
                    end
                end
            end)
        end
    end
})
run(function()
    local GodmodeAntiCheatDisabler

    GodmodeAntiCheatDisabler = vape.Categories.Exploits:CreateModule({
        Name = 'Client Side ac disabler',
        Function = function(callback)
            if callback then
                task.wait(2)
                
                if not entitylib.isAlive then
                    notif('GodmodeAntiCheatDisabler', 'Character not alive', 3, 'alert')
                    return
                end

                local character = entitylib.character
                local rootPart = character.RootPart
                
                if not rootPart then
                    notif('GodmodeAntiCheatDisabler', 'RootPart not found', 3, 'alert')
                    return
                end

                local hrpRemovalThread
                local cleanupConnection
                
                hrpRemovalThread = task.spawn(function()
                    while GodmodeAntiCheatDisabler.Enabled and entitylib.isAlive do
                        -- Temporarily remove HRP from character
                        rootPart.Parent = nil
                        
                        -- Move character to current position
                        character.Character:MoveTo(character.Character:GetPivot().Position)
                        
                        task.wait() -- Yield for one frame
                        
                        -- Restore HRP
                        rootPart.Parent = character.Character
                        
                        task.wait(0.25) -- Wait before next iteration
                    end
                end)

                -- Store thread for cleanup
                GodmodeAntiCheatDisabler:Clean(function()
                    if hrpRemovalThread then
                        task.cancel(hrpRemovalThread)
                        hrpRemovalThread = nil
                    end
                    
                    -- Ensure HRP is restored
                    if entitylib.isAlive and rootPart and rootPart.Parent == nil then
                        rootPart.Parent = character.Character
                    end
                end)

                notif('GodmodeAntiCheatDisabler', 'HRP removal active', 5)

            else
                notif('GodmodeAntiCheatDisabler', 'Reset character to fully disable', 5)
            end
        end,
        Tooltip = 'Advanced HRP remover for anti-cheat bypass'
    })
end)
