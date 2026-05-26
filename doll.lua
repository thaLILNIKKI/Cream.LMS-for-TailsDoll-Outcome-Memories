local Players				= game:GetService("Players")
local RunService			= game:GetService("RunService")
local ReplicatedStorage		= game:GetService("ReplicatedStorage")

local BONE_MAP = {
	["HumanoidRootPart"]	= "HumanoidRootPart",
	["Waist"]				= "waist",
	["MainBody"]			= "Body",
	["Head"]				= "Head",
	["RArm1"]				= "Right Sleeve",
	["LArm1"]				= "Left Sleeve",
	["RLeg1"]				= "Right Leg",
	["LLeg1"]				= "Left Leg",
}

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

local function hideDescendants(container, hiddenSet)
	for a, v in ipairs(container:GetDescendants()) do
		if v:IsA("BasePart") then
			v.Transparency = 1
			hiddenSet[v]   = true
		end
	end
end

local function showDescendants(container)
	for a, v in ipairs(container:GetDescendants()) do
		if v:IsA("BasePart") then v.Transparency = 0 end
	end
end

local function applyToPlayer(playerName)
	resetState(playerName)
	
	local playerModel = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild(playerName)
	if not playerModel then return end
	if playerModel:GetAttribute("Character") ~= "TailsDoll" then return end
	
	local playerObj = Players:FindFirstChild(playerName)
	local standardChar = playerObj and playerObj.Character
	local defaultFolder = playerModel:FindFirstChild("Default")
	local source = defaultFolder or standardChar
	if not source then return end
	
	local hrp = source:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	
	local hiddenSet = {}
	hideDescendants(playerModel, hiddenSet)
	if defaultFolder then
		hideDescendants(defaultFolder, hiddenSet)
	end
	if standardChar and standardChar ~= source then
		hideDescendants(standardChar, hiddenSet)
	end
	
	local descConn = nil
	if defaultFolder then
		descConn = defaultFolder.DescendantAdded:Connect(function(v)
			if v:IsA("BasePart") then
				v.Transparency = 1
				hiddenSet[v] = true
			end
		end)
	end
	
	local skinSource = getSkinModel()
	if not skinSource then return end
	
	local mdl = skinSource:Clone()
	mdl.Parent = playerModel
	
	local newHrp = mdl:FindFirstChild("HumanoidRootPart")
	if not newHrp then mdl:Destroy(); return end
	
	for a, v in ipairs(mdl:GetDescendants()) do
		if v:IsA("Humanoid") or v:IsA("Animator") then
			v:Destroy()
		elseif v:IsA("BasePart") then
			v.CanCollide = false
			v.Anchored   = false
		elseif v:IsA("Trail") or v:IsA("Beam") then
			v.Enabled = false
		end
	end
	
	newHrp.Anchored		= true
	newHrp.Transparency	= 1
	newHrp.CFrame		= hrp.CFrame
	
	makeRough(mdl)
	customizeEyes(mdl)
	
	local muzzle = mdl:FindFirstChild("muzzle", true)
	if muzzle then
		local decal		= Instance.new("Decal")
		decal.Texture	= "rbxassetid://7321057974"
		decal.Parent	= muzzle
	end
	
	local partPairs = {}
	local found, total = 0, 0
	for srcName, dstName in pairs(BONE_MAP) do
		total += 1
		local srcPart = source:FindFirstChild(srcName, true)
		local dstPart = mdl:FindFirstChild(dstName, true)
		if srcPart and dstPart then
			dstPart.Anchored = true
			partPairs[#partPairs + 1] = { srcPart, dstPart }
			found += 1
		end
	end
	
	local syncConn = RunService.Heartbeat:Connect(function()
		if not playerModel.Parent then
			resetState(playerName)
			return
		end
		for part in pairs(hiddenSet) do
			if part.Parent then
				part.Transparency = 1
			else
				hiddenSet[part] = nil
			end
		end
		for i = 1, #partPairs do
			local p = partPairs[i]
			if p[1].Parent and p[2].Parent then
				p[2].CFrame = p[1].CFrame
			end
		end
	end)
	
	activeData[playerName] = {
		mdl = mdl,
		syncConn = syncConn,
		descConn = descConn,
		hiddenSet = hiddenSet,
		partPairs = partPairs,
	}
end

local function removeFromPlayer(playerName)
	local data = activeData[playerName]
	if not data then return end
	
	local playerModel = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild(playerName)
	local playerObj = Players:FindFirstChild(playerName)
	local standardChar = playerObj and playerObj.Character
	local defaultFolder = playerModel and playerModel:FindFirstChild("Default")
	
	if defaultFolder then showDescendants(defaultFolder) end
	if standardChar then showDescendants(standardChar) end
	if playerModel then showDescendants(playerModel) end
	
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
	local name = model.Name
	removeFromPlayer(name)
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
    [131820864449998] = loadCustomAsset("Retract.mp3"), -- giggle or smth here ~
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
