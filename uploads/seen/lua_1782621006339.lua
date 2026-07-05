local workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local camera = workspace.CurrentCamera
local mouse = player:GetMouse()

local playerGui = player:WaitForChild("PlayerGui")
local playGui = playerGui:WaitForChild("PlayGui")
local fadeFrame = playGui:WaitForChild("Frame")
local skipButton = playGui:WaitForChild("TextButton")
local ImageLabelPaty = workspace:WaitForChild("FolderText"):WaitForChild("FolderImg2"):WaitForChild("Img"):WaitForChild("SurfaceGui"):WaitForChild("CanvasGroup")
local ImageLabelJoin = playGui:WaitForChild("ImageLabelJoin")

local folderText = workspace:WaitForChild("FolderText")
local folderImg = folderText:WaitForChild("FolderImg")
local textPart = folderText:WaitForChild("Text")

local button1 = folderImg:WaitForChild("Button1")
local button2 = folderImg:WaitForChild("Button2")
local click1 = button1:WaitForChild("ClickDetector")
local click2 = button2:WaitForChild("ClickDetector")

local buttonEvent = ReplicatedStorage:WaitForChild("Button")
local EventTalk = ReplicatedStorage:WaitForChild("EventTalk")

local clickDetector = textPart:WaitForChild("ClickDetector")
clickDetector.MaxActivationDistance = 1000
click1.MaxActivationDistance = 1000
click2.MaxActivationDistance = 1000

local SENSITIVITY = 2
local SMOOTHNESS = 0.1

local SWAY_SPEED = 0.5
local SWAY_AMOUNT_X = 2.5
local SWAY_AMOUNT_Y = 1.8
local SWAY_ROLL = 0.35

local BOB_SPEED = 6
local BOB_AMOUNT_X = 0.025
local BOB_AMOUNT_Y = 0.08
local BOB_ROLL = 0.01

local BASE_SIZE = textPart.Size
local MAX_SIZE = BASE_SIZE * 1.1

local B1_BASE_SIZE = button1.Size
local B1_MAX_SIZE = B1_BASE_SIZE * 1.1

local B2_BASE_SIZE = button2.Size
local B2_MAX_SIZE = B2_BASE_SIZE * 1.1

local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local imgTweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local currentTween = nil
local b1Tween = nil
local b2Tween = nil
local isClicked = false
local isSkipped = false

local cameraState = 0

local activeCameraPart = folderText:WaitForChild("Cam1")
local baseCFrame = activeCameraPart.CFrame

local cam12TurnOffset = CFrame.new()
local cam12TurnProgress = 0

local state2SwayIntensity = 0

local chimesSound = workspace:WaitForChild("Before_the_Chimes_Stop")
local footstepSound = workspace:WaitForChild("footstep")

local imgLabel = folderImg:WaitForChild("Img"):WaitForChild("SurfaceGui"):WaitForChild("ImageLabel")
local img1Label = folderImg:WaitForChild("Button1"):WaitForChild("SurfaceGui"):WaitForChild("ImageLabel")
local img2Label = folderImg:WaitForChild("Button2"):WaitForChild("SurfaceGui"):WaitForChild("ImageLabel")

skipButton.Visible = false
skipButton.BackgroundTransparency = 1
skipButton.TextTransparency = 1

fadeFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
fadeFrame.BackgroundTransparency = 1

local radSensitivity = math.rad(SENSITIVITY)
local radSwayX = math.rad(SWAY_AMOUNT_X)
local radSwayY = math.rad(SWAY_AMOUNT_Y)
local radSwayZ = math.rad(SWAY_ROLL)

local function createFadeTween(targetTransparency, duration)
	return TweenService:Create(fadeFrame, TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
		BackgroundTransparency = targetTransparency
	})
end

local function disableEverything()
	ContextActionService:BindAction("FreezeAction", function() return Enum.ContextActionResult.Sink end, false, unpack(Enum.PlayerActions:GetEnumItems()))
	ContextActionService:BindAction("FreezeJump", function() return Enum.ContextActionResult.Sink end, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	for _, gui in ipairs(playerGui:GetChildren()) do
		if gui:IsA("ScreenGui") and gui.Name ~= "PlayGui" then
			gui.Enabled = false
		end
	end
end

local function fadeInSkipButton()
	skipButton.BackgroundTransparency = 1
	skipButton.TextTransparency = 1
	skipButton.Visible = true

	TweenService:Create(skipButton, TweenInfo.new(1.0, Enum.EasingStyle.Linear), {TextTransparency = 0}):Play()
end

local function fadeOutSkipButton()
	local t2 = TweenService:Create(skipButton, TweenInfo.new(0.5, Enum.EasingStyle.Linear), {TextTransparency = 1})
	t2:Play()
	task.defer(function()
		if skipButton.TextTransparency == 1 then
			skipButton.Visible = false
		end
	end)
end

if activeCameraPart then
	camera.CameraType = Enum.CameraType.Scriptable

	local targetMouseOffset = CFrame.new()
	local currentMouseOffset = CFrame.new()

	local cameraConnection
	cameraConnection = RunService.RenderStepped:Connect(function()
		if not activeCameraPart or not activeCameraPart:IsDescendantOf(workspace) then
			cameraConnection:Disconnect()
			return
		end

		local viewportSize = camera.ViewportSize
		local viewSizeX = viewportSize.X
		local viewSizeY = viewportSize.Y
		if viewSizeX == 0 or viewSizeY == 0 then return end

		local currentTime = os.clock()
		local finalOffset = CFrame.new()

		if cameraState == 0 or cameraState == 2 then
			local mouseX = (mouse.X - (viewSizeX * 0.5)) / (viewSizeX * 0.5)
			local mouseY = (mouse.Y - (viewSizeY * 0.5)) / (viewSizeY * 0.5)

			targetMouseOffset = CFrame.fromEulerAnglesXYZ(-mouseY * radSensitivity, -mouseX * radSensitivity, 0)
			currentMouseOffset = currentMouseOffset:Lerp(targetMouseOffset, SMOOTHNESS)

			local intensity = 1
			if cameraState == 2 then
				intensity = state2SwayIntensity
			end

			local swayX = math.sin(currentTime * SWAY_SPEED) * radSwayX * intensity
			local swayY = math.cos(currentTime * SWAY_SPEED * 0.7) * radSwayY * intensity
			local swayZ = math.sin(currentTime * SWAY_SPEED * 0.5) * radSwayZ * intensity

			finalOffset = currentMouseOffset * CFrame.fromEulerAnglesXYZ(swayY, swayX, swayZ)
		elseif cameraState == 1 then
			local bobX = math.sin(currentTime * BOB_SPEED) * BOB_AMOUNT_X
			local bobY = math.abs(math.cos(currentTime * BOB_SPEED)) * BOB_AMOUNT_Y
			local bobZ = math.sin(currentTime * BOB_SPEED * 0.5) * BOB_ROLL

			finalOffset = CFrame.new(bobX, bobY, 0) * CFrame.fromEulerAnglesXYZ(0, 0, bobZ)
		end

		local currentCam12Offset = CFrame.new():Lerp(cam12TurnOffset, cam12TurnProgress)

		camera.CFrame = baseCFrame * currentCam12Offset * finalOffset
	end)
end

local function tweenVolume(sound, targetVolume, duration)
	if not sound then return end

	if targetVolume > 0 and not sound.IsPlaying then
		sound.Volume = 0
		sound:Play()
	end

	local volumeTween = TweenService:Create(sound, TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
		Volume = targetVolume
	})

	if targetVolume == 0 then
		task.defer(function()
			volumeTween.Completed:Wait()
			if sound.Volume == 0 then
				sound:Stop()
			end
		end)
	end

	volumeTween:Play()
	return volumeTween
end

local function applyCam12Effects()
	if footstepSound then tweenVolume(footstepSound, 0, 0.5) end
	if chimesSound then tweenVolume(chimesSound, 0.7, 1.0) end

	TweenService:Create(imgLabel, imgTweenInfo, {ImageTransparency = 0}):Play()
	TweenService:Create(img1Label, imgTweenInfo, {ImageTransparency = 0}):Play()
	TweenService:Create(img2Label, imgTweenInfo, {ImageTransparency = 0}):Play()
end

local function endCutsceneAtCam12()
	fadeOutSkipButton()

	if isSkipped and fadeFrame.BackgroundTransparency ~= 0 then
		cameraState = 0
		local skipFadeBlack = createFadeTween(0, 0.5)
		skipFadeBlack:Play()
		skipFadeBlack.Completed:Wait()
	end

	local cam12 = folderText:FindFirstChild("Cam12")
	if cam12 then
		activeCameraPart = cam12
		baseCFrame = cam12.CFrame
	end

	applyCam12Effects()
	cam12TurnProgress = 1

	local fadeToClearFinal = createFadeTween(1, 1.0)
	fadeToClearFinal:Play()
	fadeToClearFinal.Completed:Wait()

	state2SwayIntensity = 0
	cameraState = 2

	local intensityValue = Instance.new("NumberValue")
	local swayFadeTween = TweenService:Create(intensityValue, TweenInfo.new(3.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Value = 1})

	local intensityConnection = intensityValue.Changed:Connect(function(val)
		state2SwayIntensity = val
	end)

	swayFadeTween:Play()
	task.defer(function()
		swayFadeTween.Completed:Wait()
		intensityConnection:Disconnect()
		intensityValue:Destroy()
	end)
end

local function startCameraCutscene()
	local fadeToBlack = createFadeTween(0, 1.5)
	fadeToBlack:Play()
	fadeToBlack.Completed:Wait()

	fadeInSkipButton()

	if isSkipped then
		endCutsceneAtCam12()
		return
	end

	task.wait(2)
	if isSkipped then
		endCutsceneAtCam12()
		return
	end

	local cam2 = folderText:FindFirstChild("Cam2")
	if cam2 then
		activeCameraPart = cam2
		baseCFrame = cam2.CFrame
	end

	cameraState = 1

	local fadeToClear = createFadeTween(1, 1.5)
	fadeToClear:Play()

	local durationSettings = {
		[3] = 6, [4] = 1, [5] = 0.4, [6] = 0.4, [7] = 1,
		[8] = 0.6, [9] = 1.4, [10] = 7.5, [11] = 1.2, [12] = 1.5
	}

	local cameraValue = Instance.new("CFrameValue")
	cameraValue.Value = baseCFrame

	local connection = cameraValue.Changed:Connect(function(newCFrame)
		baseCFrame = newCFrame
	end)

	local camIndex = 3
	while camIndex <= 12 do
		if isSkipped then break end

		local nextCamPart = folderText:FindFirstChild("Cam" .. camIndex)
		if nextCamPart then
			local duration = durationSettings[camIndex] or 3.5

			local moveTweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
			local cutsceneTween = TweenService:Create(cameraValue, moveTweenInfo, {Value = nextCamPart.CFrame})

			if camIndex == 12 then
				
				applyCam12Effects()

				local turnProgressValue = Instance.new("NumberValue")
				local turnTween = TweenService:Create(turnProgressValue, TweenInfo.new(durationSettings[12] or 2.0, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {Value = 1})

				local turnConnection = turnProgressValue.Changed:Connect(function(val)
					cam12TurnProgress = val
				end)

				turnTween:Play()
				task.defer(function()
					turnTween.Completed:Wait()
					cameraState = 0
					turnConnection:Disconnect()
					turnProgressValue:Destroy()
				end)
			end

			cutsceneTween:Play()

			local tweenFinished = false
			local completedConnection
			completedConnection = cutsceneTween.Completed:Connect(function()
				tweenFinished = true
			end)

			while not tweenFinished and not isSkipped do
				RunService.RenderStepped:Wait()
			end

			if completedConnection then completedConnection:Disconnect() end

			if isSkipped then
				cameraState = 0

				local skipFadeBlack = createFadeTween(0, 0.5)
				skipFadeBlack:Play()
				skipFadeBlack.Completed:Wait()

				cutsceneTween:Cancel()

				local cam12 = folderText:FindFirstChild("Cam12")
				if cam12 then
					cameraValue.Value = cam12.CFrame
					baseCFrame = cam12.CFrame
				end
				break
			else
				cutsceneTween:Cancel()
			end
		end
		camIndex = camIndex + 1
	end

	connection:Disconnect()
	baseCFrame = cameraValue.Value
	cameraValue:Destroy()

	endCutsceneAtCam12()
end

local function playSizeTween(targetSize)
	if currentTween then currentTween:Cancel() end
	currentTween = TweenService:Create(textPart, tweenInfo, {Size = targetSize})
	currentTween:Play()
end

local function playButton1Tween(targetSize)
	if b1Tween then b1Tween:Cancel() end
	b1Tween = TweenService:Create(button1, tweenInfo, {Size = targetSize})
	b1Tween:Play()
end

local function playButton2Tween(targetSize)
	if b2Tween then b2Tween:Cancel() end
	b2Tween = TweenService:Create(button2, tweenInfo, {Size = targetSize})
	b2Tween:Play()
end

clickDetector.MouseHoverEnter:Connect(function()
	if not isClicked then playSizeTween(MAX_SIZE) end
end)

clickDetector.MouseHoverLeave:Connect(function()
	if not isClicked then playSizeTween(BASE_SIZE) end
end)

clickDetector.MouseClick:Connect(function()
	if not isClicked then
		EventTalk:Fire()
		
		isClicked = true

		if chimesSound then tweenVolume(chimesSound, 0, 1.0) end
		if footstepSound then tweenVolume(footstepSound, 0.7, 1.5) end

		fadeFrame.Visible = true
		disableEverything()
		playSizeTween(BASE_SIZE)

		task.spawn(startCameraCutscene)
	end
end)

click1.MouseHoverEnter:Connect(function()
	playButton1Tween(B1_MAX_SIZE)
end)

click1.MouseHoverLeave:Connect(function()
	playButton1Tween(B1_BASE_SIZE)
end)

click1.MouseClick:Connect(function()

	if buttonEvent then
		buttonEvent:FireServer("create")
	end

	ImageLabelPaty.Visible = true
	ImageLabelJoin.Visible = false
end)

click2.MouseHoverEnter:Connect(function()
	playButton2Tween(B2_MAX_SIZE)
end)

click2.MouseHoverLeave:Connect(function()
	playButton2Tween(B2_BASE_SIZE)
end)

click2.MouseClick:Connect(function()
	local clickFade = createFadeTween(0, 0.5)
	clickFade:Play()

	task.defer(function()
		clickFade.Completed:Wait()

		ImageLabelPaty.Visible = true
		ImageLabelJoin.Visible = false
	end)
end)

skipButton.MouseButton1Click:Connect(function()
	if isClicked and not isSkipped then
		isSkipped = true
	end
end)

player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
end)
