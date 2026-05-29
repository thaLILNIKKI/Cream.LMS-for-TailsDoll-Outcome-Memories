print("[Cream.LMS x TailsDoll] Now loading... Made by lil2kki <3")

local function remapMotors(model)
	local function find(name)
		return model:FindFirstChild(name, true)
	end

	local function rename(obj, newName)
		if obj and obj.Name ~= newName then
			obj.Name = newName
		end
	end

	rename(find("waist"), "Waist")
	rename(find("Body"), "MainBody")
	rename(find("eye1"), "REye")
	rename(find("eye2"), "LEye")
	rename(find("Right Sleeve"), "RArm1")
	rename(find("Cylinder.013"), "RArm2")
	rename(find("Cylinder.014"), "RArm3")
	rename(find("Cylinder.017"), "RArm4")
	rename(find("Right Hand"), "RHand")
	rename(find("Left Sleeve"), "LArm1")
	rename(find("Cylinder.023"), "LArm2")
	rename(find("Cylinder.022"), "LArm3")
	rename(find("Left Hand"), "LHand")
	rename(find("Right Leg"), "RLeg1")
	rename(find("Cylinder.001"), "RLeg2")
	rename(find("Cylinder"), "RLeg3")
	rename(find("Right Shoe"), "RShoe")
	rename(find("Left Leg"), "LLeg1")
	rename(find("Cylinder.034"), "LLeg2")
	rename(find("Cylinder.035"), "LLeg3")
	rename(find("Left Shoe"), "LShoe")
	rename(find("tail"), "RTail")
end

local _skinModelCache = nil
local function getSkinModel()
	if _skinModelCache and _skinModelCache.Parent then
		return _skinModelCache
	end
	local chars = game:GetService("ReplicatedStorage"):FindFirstChild("Characters", true)
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

local function applyToPlayer(plrModel)
	if plrModel:GetAttribute("Character") ~= "TailsDoll" then return end

	local hrp = plrModel:FindFirstChild("HumanoidRootPart", true)
	if not hrp then return end

	local mdl = getSkinModel()
	if not mdl then return end

	mdl = mdl:Clone()
	mdl.Parent = plrModel
	
	for _, v in ipairs(mdl:GetDescendants()) do
		if v:IsA("Humanoid") then
			v:Destroy()
		elseif v:IsA("BasePart") then
			v.CanCollide = false
			v.Anchored = false
		end
	end

	local newHrp = mdl:FindFirstChild("HumanoidRootPart", true)
	if not newHrp then mdl:Destroy() return end

	makeRough(mdl)
	customizeEyes(mdl)
	remapMotors(mdl)

    local toRestoreTransparency = {}
	for _, part in ipairs(mdl:GetDescendants()) do
		if part:IsA("BasePart") then
			toRestoreTransparency[part] = part.Transparency
		end
	end

	local hrpOffset = Vector3.new(0, -1, 0)

	local syncConn
	syncConn = game:GetService("RunService").Heartbeat:Connect(function()
		if not mdl or not mdl.Parent then
			syncConn:Disconnect()
			warn("pizdec")
			applyToPlayer(playerName)
			return
		end
		
		if plrModel:GetAttribute("Character") ~= "TailsDoll" then
			syncConn:Disconnect() 
			mdl:Destroy()
			return
		end
		
		--newHead.CFrame = head.CFrame
		newHrp.CFrame = hrp.CFrame + hrpOffset

		for _, v in ipairs(plrModel:GetDescendants()) do
			if v:IsA("BasePart") then v.Transparency = 1 end
		end
		for v, t in pairs(toRestoreTransparency) do v.Transparency = t end
	end)
end

local function onModelAdded(model)
	if not model:IsA("Model") then return end
	task.wait(1)
    applyToPlayer(model)
	model.AttributeChanged:Connect(function(attr)
		if attr == "Character" then
			task.wait(1)
			applyToPlayer(model) 
		end
	end)
end

for _, model in ipairs(workspace.Players:GetChildren()) do onModelAdded(model) end
workspace.Players.ChildAdded:Connect(onModelAdded)


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
