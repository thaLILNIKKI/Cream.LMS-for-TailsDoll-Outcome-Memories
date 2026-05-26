local Players				= game:GetService("Players")
local RunService			= game:GetService("RunService")
local ReplicatedStorage		= game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local isActive  = false
local wasActive = false

local State = {
	mdl			= nil,
	syncConn	= nil,
	descConn	= nil,
	partPairs	= nil,   -- { { src, dst } }
	hiddenSet	= nil,   -- { [BasePart] = true }
}

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

local function isTailsDoll()
	local pf		= workspace:FindFirstChild("Players")
	local folder	= pf and pf:FindFirstChild(player.Name)
	return folder ~= nil and folder:GetAttribute("Character") == "TailsDoll"
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

local function resetState()
	if State.syncConn	then State.syncConn:Disconnect();	State.syncConn	= nil end
	if State.descConn	then State.descConn:Disconnect();	State.descConn	= nil end
	if State.mdl		then State.mdl:Destroy();			State.mdl		= nil end
	State.partPairs = nil
	State.hiddenSet = nil
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

local function applyMdl(char)
	resetState()
	
	local skinSource = getSkinModel()
	if not skinSource then return warn("[TailsDoll to Cream] can't find cream model!") end
	
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	
	local playerFolder	= workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild(player.Name)
	local defaultFolder	= playerFolder and playerFolder:FindFirstChild("Default")
	local source		= defaultFolder or char
	
	local hiddenSet = {}
	hideDescendants(char, hiddenSet)
	
	if defaultFolder then
		hideDescendants(defaultFolder, hiddenSet)
		State.descConn = defaultFolder.DescendantAdded:Connect(function(v)
			if isActive and v:IsA("BasePart") then
				v.Transparency = 1
				hiddenSet[v]   = true
			end
		end)
	end
	State.hiddenSet = hiddenSet
	
	local mdl = skinSource:Clone()
	mdl.Parent = playerFolder or char
	
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
	State.mdl			= mdl
	
	makeRough(mdl)
	customizeEyes(mdl)
	
	-- rabbit muzzle :>
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
		else
			warn("[TailsDoll to Cream] find fault:", srcName, "->", dstName)
		end
	end
	State.partPairs = partPairs
	print(string.format("[TailsDoll to Cream] map: %d / %d", found, total))
	
	State.syncConn = RunService.Heartbeat:Connect(function()
		if not hrp.Parent or not newHrp.Parent then
			State.syncConn:Disconnect()
			State.syncConn = nil
			return
		end
		
		for part in pairs(hiddenSet) do
			if part.Parent then
				part.Transparency = 1
			else
				hiddenSet[part] = nil
			end
		end
		
		local pairs_ = partPairs
		for i = 1, #pairs_ do
			local p = pairs_[i]
			if p[1].Parent and p[2].Parent then
				p[2].CFrame = p[1].CFrame
			end
		end
	end)
end

local function removeMdl()
	resetState()
	
	local playerFolder  = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild(player.Name)
	local defaultFolder = playerFolder and playerFolder:FindFirstChild("Default")
	if defaultFolder then showDescendants(defaultFolder) end
	
	local char = player.Character
	if char then showDescendants(char) end
end

player.CharacterAdded:Connect(function(char)
	if isActive then
		task.wait(1)
		applyMdl(char)
	end
end)

RunService.Heartbeat:Connect(function()
	local active = isTailsDoll()
	if active == wasActive then return end
	wasActive = active
	isActive  = active
	if active then
		task.wait(1)
		applyMdl(player.Character or player.CharacterAdded:Wait())
	else
		removeMdl()
	end
end)

if isTailsDoll() then
	isActive  = true
	wasActive = true
	task.wait(1)
	applyMdl(player.Character or player.CharacterAdded:Wait())
end


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
    [80901931085615] = loadCustomAsset("NormalChase.mp3")
    [129416111545242] = loadCustomAsset("TerrorRadius.mp3")
    [112879248941055] = loadCustomAsset("LastLifeChase.mp3")
    [131820864449998] = loadCustomAsset("Retract.mp3") -- giggle or smth here ~
	[73636680793269] = "rbxassetid://129707701166974" -- NMI Swing XD
	[108753423324802] = "rbxassetid://77110140707717" -- basic Swing
	[134998846301914] = "rbxassetid://129707701166974" -- NMI Swing XD
}

game.DescendantAdded:Connect(function(desc)
    if desc:IsA("Sound") then
        task.wait(0.01) -- huh
        -- print(desc:GetFullName() .. " - " .. tostring(desc.SoundId))
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
