local Players				= game:GetService("Players")
local RunService			= game:GetService("RunService")
local ReplicatedStorage		= game:GetService("ReplicatedStorage")

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

local function remapMotors(creamModel)
	local function find(name)
		return creamModel:FindFirstChild(name, true)
	end

	local function rename(obj, newName)
		if obj and obj.Name ~= newName then
			obj.Name = newName
		end
	end

	-- Части
	rename(find("Body"), "MainBody")
	rename(find("waist"), "Waist")
	rename(find("Left Sleeve"), "LArm1")
	rename(find("Right Sleeve"), "RArm1")
	rename(find("Left Leg"), "LLeg1")
	rename(find("Right Leg"), "RLeg1")

	-- Motor6D в HumanoidRootPart
	local hrp = find("HumanoidRootPart")
	if hrp then
		for _, motor in ipairs(hrp:GetChildren()) do
			if motor:IsA("Motor6D") then
				if motor.Name == "waist" then motor.Name = "Waist" end
			end
		end
	end

	-- Motor6D в Waist
	local waist = find("Waist")
	if waist then
		for _, motor in ipairs(waist:GetChildren()) do
			if motor:IsA("Motor6D") then
				if motor.Name == "Body" then motor.Name = "MainBody" end
				if motor.Name == "Left Leg" then motor.Name = "LLeg1" end
				if motor.Name == "Right Leg" then motor.Name = "RLeg1" end
			end
		end
	end

	-- Motor6D в MainBody
	local mainBody = find("MainBody")
	if mainBody then
		for _, motor in ipairs(mainBody:GetChildren()) do
			if motor:IsA("Motor6D") then
				if motor.Name == "Left Sleeve" then motor.Name = "LArm1" end
				if motor.Name == "Right Sleeve" then motor.Name = "RArm1" end
			end
		end
	end

	-- Цепочка левой руки
	local lArm1 = find("LArm1")
	if lArm1 then
		for _, motor in ipairs(lArm1:GetChildren()) do
			if motor:IsA("Motor6D") then
				motor.Name = "LArm2"
				break
			end
		end
	end

	-- Цепочка правой руки
	local rArm1 = find("RArm1")
	if rArm1 then
		for _, motor in ipairs(rArm1:GetChildren()) do
			if motor:IsA("Motor6D") then
				motor.Name = "RArm2"
				break
			end
		end
	end

	-- Цепочка левой ноги
	local lLeg1 = find("LLeg1")
	if lLeg1 then
		for _, motor in ipairs(lLeg1:GetChildren()) do
			if motor:IsA("Motor6D") then
				motor.Name = "LLeg2"
				break
			end
		end
	end

	-- Цепочка правой ноги
	local rLeg1 = find("RLeg1")
	if rLeg1 then
		for _, motor in ipairs(rLeg1:GetChildren()) do
			if motor:IsA("Motor6D") then
				motor.Name = "RLeg2"
				break
			end
		end
	end
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
	for a, v in ipairs(container:GetDescendants()) do
		if v:IsA("BasePart") then v.Transparency = 0 end
	end
end

local function applyToPlayer(playerName)
	resetState(playerName)
	
	local plrModel = workspace.Players:FindFirstChild(playerName)
	if not plrModel then return end
	
	if plrModel:GetAttribute("Character") ~= "TailsDoll" then return end
	
	local source = plrModel:FindFirstChild("Default") or Players[playerName].Character
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
	if source then
		descConn = source.DescendantAdded:Connect(function(v)
			if v:IsA("BasePart") then
				v.Transparency = 1
			end
		end)
	end
	
	local skinSource = getSkinModel()
	if not skinSource then return end
	
	local mdl = skinSource:Clone()
	mdl.Parent = plrModel
	
	local newHrp = mdl:FindFirstChild("HumanoidRootPart")
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
	
	local muzzle = mdl:FindFirstChild("muzzle", true)
	if muzzle then
		local decal		= Instance.new("Decal")
		decal.Texture	= "rbxassetid://7321057974"
		decal.Parent	= muzzle
	end
	
	local syncConn
	syncConn = RunService.Heartbeat:Connect(function()
		if not plrModel.Parent then
			resetState(playerName)
			return
		end
		if newHrp and hrp and newHrp.Parent and hrp.Parent then
			newHrp.CFrame = hrp.CFrame
		end
	end)
	
	activeData[playerName] = {
		mdl = mdl,
		syncConn = syncConn,
		descConn = descConn,
		hiddenSet = hiddenSet,
	}
end

local function removeFromPlayer(playerName)
	local data = activeData[playerName]
	if not data then return end
	
	local plrModel = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild(playerName)
	local playerObj = Players:FindFirstChild(playerName)
	local standardChar = playerObj and playerObj.Character
	local defaultFolder = plrModel and plrModel:FindFirstChild("Default")
	
	if defaultFolder then showDescendants(defaultFolder) end
	if standardChar then showDescendants(standardChar) end
	if plrModel then showDescendants(plrModel) end
	
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
	player.CharacterAdded:Connect(function(char)
		local plrModel = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild(player.Name)
		if plrModel and plrModel:GetAttribute("Character") == "TailsDoll" then
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
    [131820864449998] = loadCustomAsset("Retract.mp3"),

	[97101227703333] = "rbxassetid://139116822099909",
	[93465914238963] = "rbxassetid://88164444698409",
	[113251186335660] = "rbxassetid://5507830073",
	
    [73636680793269] = "rbxassetid://77110140707717",
    [108753423324802] = "rbxassetid://77110140707717",
    [134998846301914] = "rbxassetid://77110140707717",
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
