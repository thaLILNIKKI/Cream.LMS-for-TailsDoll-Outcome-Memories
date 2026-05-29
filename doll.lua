local Players			= game:GetService("Players")
local RunService		= game:GetService("RunService")
local ReplicatedStorage	= game:GetService("ReplicatedStorage")

local function remapMotors(honeyModel)
	local function find(model, name)
		return model:FindFirstChild(name, true)
	end

	local function rename(obj, newName)
		if obj and obj.Name ~= newName then
			obj.Name = newName
		end
	end

	rename(find("Body"), "MainBody")
	rename(find("waist"), "Waist")
	rename(find("Left Sleeve"), "LArm1")
	rename(find("Right Sleeve"), "RArm1")
	rename(find("Left Leg"), "LLeg1")
	rename(find("Right Leg"), "RLeg1")
end

local _skinModelCache = nil
local function getSkinModel()
	if _skinModelCache and _skinModelCache.Parent then
		return _skinModelCache
	end
	local chars = ReplicatedStorage:FindFirstChild("Characters", true)
	if not chars then return nil end
	local result = chars:FindFirstChild("Survivors", true)
	result = result and result:FindFirstChild("Cream", true)
	result = result and result:FindFirstChild("Skins", true)
	result = result and result:FindFirstChild("Default", true)
	_skinModelCache = result
	return result
end

local function makeRough(model)
	for a, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Material = (part.Material == Enum.Material.Fabric)
				and Enum.Material.Carpet
				or  Enum.Material.Sandstone
		end
	end
end

local function setupEye(eye, origSize)
	eye.Material	= Enum.Material.Neon
	eye.Size		= origSize / 1.2
	task.spawn(function()
		local sz = origSize / 1.2
		while eye and eye.Parent do
			eye.Color = Color3.new(math.random(70, 100) / 100, 0, 0)
			eye.Size  = sz * (0.8 + math.random() * 0.2)
			task.wait(math.random(3, 15) / 100)
		end
	end)
end

local function customizeEyes(model)
	local whites = model:FindFirstChild("eyes", true)
	if whites and whites:IsA("BasePart") then
		whites.Color	= Color3.new(0, 0, 0)
		whites.Material	= Enum.Material.SmoothPlastic
	end
	local eye1 = model:FindFirstChild("eye1", true)
	local eye2 = model:FindFirstChild("eye2", true)
	if eye1 then setupEye(eye1, eye1.Size) end
	if eye2 then setupEye(eye2, eye2.Size) end
end

local activeData = {}

local function resetState(playerName)
	local data = activeData[playerName]
	if not data then return end
	if data.syncConn then data.syncConn:Disconnect() end
	if data.descConn then data.descConn:Disconnect() end
	if data.mdl then data.mdl:Destroy() end
	activeData[playerName] = nil
end

local function showDescendants(container)
	for _, v in ipairs(container:GetDescendants()) do
		if v:IsA("BasePart") then v.Transparency = 0 end
	end
end

local function applyToPlayer(playerName)

	resetState(playerName)

	local plrModel = workspace.Players:FindFirstChild(playerName)
	if not plrModel then return end

	if plrModel:GetAttribute("Character") ~= "TailsDoll" then return end

	local source = plrModel:FindFirstChild("Default") or Players[playerName].Skin
	if not source then return end

	local hrp = source:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- hide original visuals
	for _, v in ipairs(plrModel:GetDescendants()) do
		if v:IsA("BasePart") then
			v.Transparency = 1
		end
	end
	local descConn = nil
	descConn = plrModel.DescendantAdded:Connect(function(v)
		if v:IsA("BasePart") then
			v.Transparency = 1
		end
	end)

	local mdl = getSkinModel()
	if not mdl then return end

	mdl = mdl:Clone()
	mdl.Parent = plrModel

	local newHrp = mdl:FindFirstChild("HumanoidRootPart", true)
	if not newHrp then mdl:Destroy() return end
	
	for _, v in ipairs(mdl:GetDescendants()) do
		if v:IsA("Humanoid") then
			v:Destroy()
		elseif v:IsA("BasePart") then
			v.CanCollide = false
		end
	end

	makeRough(mdl)
	customizeEyes(mdl)
	remapMotors(mdl)

	local hrpOffset = Vector3.new(0, -1.0, 0)

	local syncConn
	syncConn = RunService.Heartbeat:Connect(function()
		if not plrModel.Parent then
			resetState(playerName)
			return
		end
		newHrp.CFrame = hrp.CFrame + hrpOffset
	end)

	activeData[playerName] = {
		mdl = mdl,
		syncConn = syncConn,
	}
end

local function removeFromPlayer(playerName)
	local data = activeData[playerName]
	if not data then return end

	local playerModel  = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild(playerName)
	local playerObj    = Players:FindFirstChild(playerName)
	local standardChar = playerObj and playerObj.Character
	local defaultFolder = playerModel and playerModel:FindFirstChild("Default")

	if defaultFolder  then showDescendants(defaultFolder)  end
	if standardChar   then showDescendants(standardChar)   end
	if playerModel    then showDescendants(playerModel)    end

	resetState(playerName)
end

local function onModelAdded(model)
	if not model:IsA("Model") then return end
	local name = model.Name
	if model:GetAttribute("Character") == "TailsDoll" then
		task.wait(0.5)
		applyToPlayer(name)
	end
	model.AttributeChanged:Connect(function(attr)
		if attr == "Character" then
			if model:GetAttribute("Character") == "TailsDoll" then
				applyToPlayer(name)
			else
				removeFromPlayer(name)
			end
		end
	end)
end

local function onModelRemoved(model)
	removeFromPlayer(model.Name)
end

local playersContainer = workspace:FindFirstChild("Players")
if playersContainer then
	for _, model in ipairs(playersContainer:GetChildren()) do
		onModelAdded(model)
	end
	playersContainer.ChildAdded:Connect(onModelAdded)
	playersContainer.ChildRemoved:Connect(onModelRemoved)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		local playerModel = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild(player.Name)
		if playerModel and playerModel:GetAttribute("Character") == "TailsDoll" then
			applyToPlayer(player.Name)
		end
	end)
end)


-- custom sounds..
local function loadCustomAsset(fileName)
    local cachePath = "cache/cream-on-doll/" .. fileName
    if isfile(cachePath) then return getcustomasset(cachePath) end
    local success, result = pcall(
        function()
            return game:HttpGet(
                "https://github.com/thaLILNIKKI/Cream.LMS-for-TailsDoll-Outcome-Memories/releases/download/"
                .. "assets/" .. fileName
            )
        end
    )
    if success and result then
        writefile(cachePath, result)
        return getcustomasset(cachePath)
    else
        warn("failed to load " .. fileName)
        return nil
    end
end

local assigns = {
    [80901931085615] = loadCustomAsset("NormalChase.mp3"),
    [129416111545242] = loadCustomAsset("TerrorRadius.mp3"),
    [112879248941055] = loadCustomAsset("LastLifeChase.mp3"),
	
    [112976135484851] = loadCustomAsset("Unleashed1.mp3"),
    [106071428647005]  = loadCustomAsset("Unleashed2.mp3"),
    [87302988643016]  = loadCustomAsset("Unleashed3.mp3"),
    [131820864449998] = loadCustomAsset("Retract.mp3"), -- giggle or smth here ~

	[97101227703333] = "rbxassetid://139116822099909",  -- .Hit1]  2011x Hit2
	[93465914238963] = "rbxassetid://88164444698409",  -- Lilith.Hit2] 
	[113251186335660] = "rbxassetid://5507830073",  -- Lilith.Hit3] 
	
    [73636680793269] = "rbxassetid://77110140707717",  -- basic Swing
    [108753423324802] = "rbxassetid://77110140707717",  -- basic Swing
    [134998846301914] = "rbxassetid://77110140707717",  -- basic Swing
}

game.DescendantAdded:Connect(function(desc)
    if desc:IsA("Sound") then
        task.wait(0.01)
        local soundId = desc.SoundId
        local id = tonumber(soundId:match("rbxassetid://(%d+)"))
        if id and assigns[id] then
            local newAsset = assigns[id]
            desc.SoundId = newAsset
            desc:GetPropertyChangedSignal("SoundId"):Connect(function()
                if desc.SoundId ~= newAsset then
                    desc.SoundId = newAsset
                end
            end)
        end
    end
end)
