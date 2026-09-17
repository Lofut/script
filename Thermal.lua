local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

task.wait(1)

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

--------------------------------------------------
-- KEYBINDS
--------------------------------------------------

local THERMAL_KEYBIND = Enum.KeyCode.N
local REVEAL_KEYBIND = Enum.KeyCode.H

local STREAM_GRACE = 0.5

local Settings = {
    Thermal = true,
    DarkEnvironment = false,
    ShowBots = false,
    ShowName = false,
    ShowDistance = false,
    MaxDistance = 1000,
    ScanRate = 20
}

local HighlightCache = Instance.new("Folder")
HighlightCache.Name = "UltimateX_Highlights"
HighlightCache.Parent = CoreGui

local ESP = {}
local BotESP = {}
local Connections = {}
local Unloaded = false

local RevealActive = false
local RevealEnd = 0
local RevealCooldown = false
local RevealCooldownEnd = 0

local REVEAL_DURATION = 10
local REVEAL_COOLDOWN = 20

local SavedLighting = nil

local DarkWasEnabledBeforeThermalOff = false

local scanExistingBots
local removeAllBots
local updateDarkEnvironment
local activateReveal
local applyDarkValues

local RefreshThermalToggle
local RefreshDarkToggle

--------------------------------------------------
-- GUI
--------------------------------------------------

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "UltimateX"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 280, 0, 560)
Main.Position = UDim2.new(0.5, -140, 0.5, -280 - 58)
Main.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(45, 45, 45)
MainStroke.Thickness = 1
MainStroke.Parent = Main

--------------------------------------------------
-- CUSTOM CURSOR OVERLAY
--------------------------------------------------

local CURSOR_RENDER_OFFSET = -58

local CursorDot = Instance.new("Frame")
CursorDot.Name = "UltimateX_Cursor"
CursorDot.Size = UDim2.new(0, 6, 0, 6)
CursorDot.AnchorPoint = Vector2.new(0.5, 0.5)
CursorDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
CursorDot.BorderSizePixel = 0
CursorDot.ZIndex = 1000
CursorDot.Visible = false
CursorDot.Parent = ScreenGui

local CursorDotCorner = Instance.new("UICorner")
CursorDotCorner.CornerRadius = UDim.new(1, 0)
CursorDotCorner.Parent = CursorDot

local CursorOutline = Instance.new("Frame")
CursorOutline.Name = "UltimateX_CursorOutline"
CursorOutline.Size = UDim2.new(0, 14, 0, 14)
CursorOutline.AnchorPoint = Vector2.new(0.5, 0.5)
CursorOutline.BackgroundTransparency = 1
CursorOutline.BorderSizePixel = 0
CursorOutline.ZIndex = 999
CursorOutline.Visible = false
CursorOutline.Parent = ScreenGui

local CursorOutlineCorner = Instance.new("UICorner")
CursorOutlineCorner.CornerRadius = UDim.new(1, 0)
CursorOutlineCorner.Parent = CursorOutline

local CursorOutlineStroke = Instance.new("UIStroke")
CursorOutlineStroke.Color = Color3.fromRGB(255, 255, 255)
CursorOutlineStroke.Thickness = 1
CursorOutlineStroke.Transparency = 0.4
CursorOutlineStroke.Parent = CursorOutline

local CursorVisible = false

local function getCursorPosition()
    local pos = UserInputService:GetMouseLocation()
    return Vector2.new(pos.X, pos.Y + CURSOR_RENDER_OFFSET)
end

local function updateCursorVisibility()
    if Unloaded then
        CursorDot.Visible = false
        CursorOutline.Visible = false
        return
    end

    local mousePos = getCursorPosition()
    local mainPos = Main.AbsolutePosition
    local mainSize = Main.AbsoluteSize

    local inside =
        mousePos.X >= mainPos.X and
        mousePos.X <= mainPos.X + mainSize.X and
        mousePos.Y >= mainPos.Y and
        mousePos.Y <= mainPos.Y + mainSize.Y

    if inside and not CursorVisible then
        CursorVisible = true
        CursorDot.Visible = true
        CursorOutline.Visible = true
    elseif not inside and CursorVisible then
        CursorVisible = false
        CursorDot.Visible = false
        CursorOutline.Visible = false
    end
end

table.insert(Connections, RunService.Heartbeat:Connect(function()
    if Unloaded then return end

    updateCursorVisibility()

    if not CursorVisible then return end

    local mousePos = getCursorPosition()

    CursorDot.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y)
    CursorOutline.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y)
end))

--------------------------------------------------
-- TITLE BAR
--------------------------------------------------

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 48)
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Main

local TitleBarCorner = Instance.new("UICorner")
TitleBarCorner.CornerRadius = UDim.new(0, 10)
TitleBarCorner.Parent = TitleBar

local TitleBarBottomCover = Instance.new("Frame")
TitleBarBottomCover.Size = UDim2.new(1, 0, 0, 10)
TitleBarBottomCover.Position = UDim2.new(0, 0, 1, -10)
TitleBarBottomCover.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
TitleBarBottomCover.BorderSizePixel = 0
TitleBarBottomCover.Parent = TitleBar

local TitleDot = Instance.new("Frame")
TitleDot.Size = UDim2.new(0, 6, 0, 6)
TitleDot.Position = UDim2.new(0, 16, 0.5, -3)
TitleDot.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
TitleDot.BorderSizePixel = 0
TitleDot.Parent = TitleBar

local TitleDotCorner = Instance.new("UICorner")
TitleDotCorner.CornerRadius = UDim.new(1, 0)
TitleDotCorner.Parent = TitleDot

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -110, 1, 0)
Title.Position = UDim2.new(0, 32, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Ultimate X"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 17
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

local Creator = Instance.new("TextLabel")
Creator.Size = UDim2.new(0, 60, 1, 0)
Creator.Position = UDim2.new(1, -100, 0, 0)
Creator.BackgroundTransparency = 1
Creator.Text = "by Lofut"
Creator.TextColor3 = Color3.fromRGB(120, 120, 120)
Creator.TextSize = 11
Creator.Font = Enum.Font.Gotham
Creator.TextXAlignment = Enum.TextXAlignment.Right
Creator.Parent = TitleBar

local CollapseElements = { TitleDot, Title, Creator, TitleBarBottomCover }

--------------------------------------------------
-- MINIMIZE BUTTON
--------------------------------------------------

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 28, 0, 28)
MinimizeBtn.Position = UDim2.new(1, -38, 0, 10)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
MinimizeBtn.BorderSizePixel = 0
MinimizeBtn.Text = "–"
MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeBtn.TextSize = 16
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.AutoButtonColor = false
MinimizeBtn.Parent = TitleBar

local MinimizeBtnCorner = Instance.new("UICorner")
MinimizeBtnCorner.CornerRadius = UDim.new(0, 6)
MinimizeBtnCorner.Parent = MinimizeBtn

MinimizeBtn.MouseEnter:Connect(function()
    TweenService:Create(MinimizeBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    }):Play()
end)
MinimizeBtn.MouseLeave:Connect(function()
    TweenService:Create(MinimizeBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    }):Play()
end)

--------------------------------------------------
-- DRAGGING
--------------------------------------------------

local dragging = false
local dragStart
local startPos

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

--------------------------------------------------
-- GUI HELPERS
--------------------------------------------------

local BodyElements = {}

local function hideOnMinimize(obj)
    table.insert(BodyElements, obj)
    return obj
end

local function createSection(text, y)
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -28, 0, 16)
    Label.Position = UDim2.new(0, 14, 0, y)
    Label.BackgroundTransparency = 1
    Label.Text = string.upper(text)
    Label.TextColor3 = Color3.fromRGB(130, 130, 130)
    Label.TextSize = 11
    Label.Font = Enum.Font.GothamBold
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Main
    return hideOnMinimize(Label)
end

local function createButton(text, y)
    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(1, -28, 0, 30)
    Button.Position = UDim2.new(0, 14, 0, y)
    Button.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
    Button.BorderSizePixel = 0
    Button.Text = text
    Button.TextColor3 = Color3.fromRGB(255, 255, 255)
    Button.TextSize = 13
    Button.Font = Enum.Font.Gotham
    Button.AutoButtonColor = false
    Button.Parent = Main

    local ButtonCorner = Instance.new("UICorner")
    ButtonCorner.CornerRadius = UDim.new(0, 6)
    ButtonCorner.Parent = Button

    return hideOnMinimize(Button)
end

local function createToggle(settingName, text, y, callback)
    local Button = createButton("", y)

    local function refresh()
        if Settings[settingName] then
            Button.Text = "● " .. text
            Button.TextColor3 = Color3.fromRGB(255, 255, 255)
            TweenService:Create(Button, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.fromRGB(48, 48, 48)
            }):Play()
        else
            Button.Text = "○ " .. text
            Button.TextColor3 = Color3.fromRGB(150, 150, 150)
            TweenService:Create(Button, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.fromRGB(32, 32, 32)
            }):Play()
        end
    end

    Button.MouseButton1Click:Connect(function()
        Settings[settingName] = not Settings[settingName]
        refresh()
        if callback then
            callback(Settings[settingName])
        end
    end)

    refresh()
    return Button, refresh
end

local function createTextBox(labelText, y, getValue, setValue)
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.5, -14, 0, 26)
    Label.Position = UDim2.new(0, 14, 0, y)
    Label.BackgroundTransparency = 1
    Label.Text = labelText
    Label.TextColor3 = Color3.fromRGB(200, 200, 200)
    Label.TextSize = 12
    Label.Font = Enum.Font.Gotham
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Main
    hideOnMinimize(Label)

    local Box = Instance.new("TextBox")
    Box.Size = UDim2.new(0.5, -14, 0, 26)
    Box.Position = UDim2.new(0.5, 0, 0, y)
    Box.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
    Box.BorderSizePixel = 0
    Box.Text = tostring(getValue())
    Box.TextColor3 = Color3.fromRGB(255, 255, 255)
    Box.TextSize = 12
    Box.Font = Enum.Font.Gotham
    Box.ClearTextOnFocus = false
    Box.Parent = Main
    hideOnMinimize(Box)

    local BoxCorner = Instance.new("UICorner")
    BoxCorner.CornerRadius = UDim.new(0, 6)
    BoxCorner.Parent = Box

    Box.FocusLost:Connect(function()
        local value = tonumber(Box.Text)
        if value then
            setValue(value)
        end
        Box.Text = tostring(getValue())
    end)

    return Box
end

--------------------------------------------------
-- REVEAL UI
--------------------------------------------------

local RevealButton = createButton("REVEAL", 62)

local RevealStatusLabel = Instance.new("TextLabel")
RevealStatusLabel.Size = UDim2.new(1, -28, 0, 16)
RevealStatusLabel.Position = UDim2.new(0, 14, 0, 98)
RevealStatusLabel.BackgroundTransparency = 1
RevealStatusLabel.Text = "Ready"
RevealStatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
RevealStatusLabel.TextSize = 11
RevealStatusLabel.Font = Enum.Font.Gotham
RevealStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
RevealStatusLabel.Parent = Main
hideOnMinimize(RevealStatusLabel)

local RevealBarBack = Instance.new("Frame")
RevealBarBack.Size = UDim2.new(1, -28, 0, 6)
RevealBarBack.Position = UDim2.new(0, 14, 0, 116)
RevealBarBack.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
RevealBarBack.BorderSizePixel = 0
RevealBarBack.Parent = Main
hideOnMinimize(RevealBarBack)

local RevealBarBackCorner = Instance.new("UICorner")
RevealBarBackCorner.CornerRadius = UDim.new(1, 0)
RevealBarBackCorner.Parent = RevealBarBack

local RevealBar = Instance.new("Frame")
RevealBar.Size = UDim2.new(1, 0, 1, 0)
RevealBar.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
RevealBar.BorderSizePixel = 0
RevealBar.Parent = RevealBarBack

local RevealBarCorner = Instance.new("UICorner")
RevealBarCorner.CornerRadius = UDim.new(1, 0)
RevealBarCorner.Parent = RevealBar

activateReveal = function()
    if RevealActive or RevealCooldown then return end

    RevealActive = true
    RevealEnd = tick() + REVEAL_DURATION

    TweenService:Create(RevealButton, TweenInfo.new(0.1), {
        BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    }):Play()
    task.delay(0.1, function()
        TweenService:Create(RevealButton, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(38, 38, 38)
        }):Play()
    end)
end

RevealButton.MouseButton1Click:Connect(activateReveal)

table.insert(Connections, RunService.Heartbeat:Connect(function()
    local now = tick()

    if RevealActive then
        local remaining = RevealEnd - now
        if remaining <= 0 then
            RevealActive = false
            RevealCooldown = true
            RevealCooldownEnd = now + REVEAL_COOLDOWN
        else
            RevealStatusLabel.Text = string.format("Active — %.1fs", remaining)
            RevealStatusLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
            RevealBar.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
            RevealBar.Size = UDim2.new(remaining / REVEAL_DURATION, 0, 1, 0)
            return
        end
    end

    if RevealCooldown then
        local remaining = RevealCooldownEnd - now
        if remaining <= 0 then
            RevealCooldown = false
            RevealStatusLabel.Text = "Ready"
            RevealStatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
            RevealBar.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
            RevealBar.Size = UDim2.new(1, 0, 1, 0)
        else
            local progress = 1 - (remaining / REVEAL_COOLDOWN)
            RevealStatusLabel.Text = "Cooldown — " .. math.ceil(remaining) .. "s"
            RevealStatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            RevealBar.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
            RevealBar.Size = UDim2.new(progress, 0, 1, 0)
        end
    else
        RevealStatusLabel.Text = "Ready"
        RevealStatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        RevealBar.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
        RevealBar.Size = UDim2.new(1, 0, 1, 0)
    end
end))

--------------------------------------------------
-- MINIMIZE / EXPAND LOGIC
--------------------------------------------------

local EXPANDED_SIZE = UDim2.new(0, 280, 0, 560)
local COLLAPSED_SIZE = UDim2.new(0, 48, 0, 48)
local IsMinimized = false

local function setMinimized(min)
    if IsMinimized == min then return end
    IsMinimized = min

    if min then
        for _, v in ipairs(BodyElements) do v.Visible = false end
        for _, v in ipairs(CollapseElements) do v.Visible = false end
    end

    local tween = TweenService:Create(
        Main,
        TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        { Size = min and COLLAPSED_SIZE or EXPANDED_SIZE }
    )
    tween:Play()

    MinimizeBtn.Text = min and "+" or "–"
    MinimizeBtn.Position = min and UDim2.new(0, 10, 0, 10) or UDim2.new(1, -38, 0, 10)

    if not min then
        tween.Completed:Connect(function()
            if not IsMinimized then
                for _, v in ipairs(BodyElements) do v.Visible = true end
                for _, v in ipairs(CollapseElements) do v.Visible = true end
            end
        end)
    end
end

MinimizeBtn.MouseButton1Click:Connect(function()
    setMinimized(not IsMinimized)
end)

--------------------------------------------------
-- SECTIONS
--------------------------------------------------

createSection("Thermal", 140)

local ThermalToggle, RefreshThermalToggleLocal = createToggle("Thermal", "Thermal", 162, function(enabled)
    if not enabled then
        if Settings.DarkEnvironment then
            DarkWasEnabledBeforeThermalOff = true
            Settings.DarkEnvironment = false
            updateDarkEnvironment()
            if RefreshDarkToggle then RefreshDarkToggle() end
        else
            DarkWasEnabledBeforeThermalOff = false
        end
    else
        if DarkWasEnabledBeforeThermalOff and not Settings.DarkEnvironment then
            Settings.DarkEnvironment = true
            DarkWasEnabledBeforeThermalOff = false
            updateDarkEnvironment()
            if RefreshDarkToggle then RefreshDarkToggle() end
        end
    end
end)
RefreshThermalToggle = RefreshThermalToggleLocal

local DarkToggle, RefreshDarkToggleLocal = createToggle("DarkEnvironment", "Dark Environment", 196, function(enabled)
    updateDarkEnvironment()
end)
RefreshDarkToggle = RefreshDarkToggleLocal

createSection("Targets", 240)
createToggle("ShowBots", "Show Bots", 262, function(enabled)
    if enabled then
        task.defer(function()
            if not Unloaded then
                scanExistingBots()
            end
        end)
    else
        removeAllBots()
    end
end)

createSection("Display", 306)
createToggle("ShowName", "Name", 328)
createToggle("ShowDistance", "Distance", 362)

createSection("Configuration", 406)
createTextBox("Distance", 428,
    function() return Settings.MaxDistance end,
    function(v) Settings.MaxDistance = math.clamp(v, 10, 5000) end
)
createTextBox("Scan Rate", 460,
    function() return Settings.ScanRate end,
    function(v) Settings.ScanRate = math.clamp(v, 1, 60) end
)

--------------------------------------------------
-- UNLOAD
--------------------------------------------------

local UnloadButton = createButton("UNLOAD", 512)
UnloadButton.BackgroundColor3 = Color3.fromRGB(60, 25, 25)

UnloadButton.MouseButton1Click:Connect(function()
    Unloaded = true

    for _, connection in ipairs(Connections) do
        pcall(function() connection:Disconnect() end)
    end

    if HighlightCache then HighlightCache:Destroy() end

    if SavedLighting then
        Lighting.Ambient = SavedLighting.Ambient
        Lighting.OutdoorAmbient = SavedLighting.OutdoorAmbient
        Lighting.Brightness = SavedLighting.Brightness
        Lighting.ClockTime = SavedLighting.ClockTime
        Lighting.GlobalShadows = SavedLighting.GlobalShadows
        SavedLighting = nil
    end

    ScreenGui:Destroy()
end)

--------------------------------------------------
-- TARGET DETECTION
--------------------------------------------------

local function isPlayerCharacter(model)
    if not model or not model:IsA("Model") then return false end
    return Players:GetPlayerFromCharacter(model) ~= nil
end

local function getRoot(model)
    if not model or not model:IsA("Model") then return nil end
    local root = model:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then return root end
    if model.PrimaryPart then return model.PrimaryPart end
    for _, obj in ipairs(model:GetChildren()) do
        if obj:IsA("BasePart") then return obj end
    end
    return nil
end

local function isBot(model)
    if not model or not model:IsA("Model") then return false end
    if isPlayerCharacter(model) then return false end

    -- Skip anything under the local player's character (guns, tools, arms)
    local localChar = LocalPlayer.Character
    if localChar and model:IsDescendantOf(localChar) then
        return false
    end

    -- Skip anything under the Camera (first-person viewmodels)
    if model:IsDescendantOf(Camera) then
        return false
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end

    return getRoot(model) ~= nil
end

--------------------------------------------------
-- HIGHLIGHT + BILLBOARD CREATION
--------------------------------------------------

local function createTargetData(isTargetBot)
    local highlight = Instance.new("Highlight")
    highlight.Name = "UltimateX_Highlight"
    highlight.FillTransparency = 0.4
    highlight.OutlineTransparency = 1
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    highlight.Enabled = false
    highlight.Adornee = nil
    highlight.Parent = HighlightCache

    local armorHighlight = Instance.new("Highlight")
    armorHighlight.Name = "UltimateX_ArmorHighlight"
    armorHighlight.FillTransparency = 0.15
    armorHighlight.OutlineTransparency = 1
    armorHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
    armorHighlight.Enabled = false
    armorHighlight.Adornee = nil
    armorHighlight.Parent = HighlightCache

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "UltimateX_Info"
    billboard.Size = UDim2.new(0, 150, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Enabled = false
    billboard.Adornee = nil
    billboard.Parent = HighlightCache

    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, 0, 1, 0)
    text.BackgroundTransparency = 1
    text.TextColor3 = Color3.fromRGB(255, 255, 255)
    text.TextStrokeTransparency = 0.5
    text.TextSize = 12
    text.Font = Enum.Font.GothamBold
    text.TextYAlignment = Enum.TextYAlignment.Center
    text.Parent = billboard

    if isTargetBot then
        highlight.FillColor = Color3.fromRGB(255, 30, 30)
        armorHighlight.FillColor = Color3.fromRGB(255, 30, 30)
        text.TextColor3 = Color3.fromRGB(255, 30, 30)
    else
        highlight.FillColor = Color3.fromRGB(255, 255, 255)
        armorHighlight.FillColor = Color3.fromRGB(255, 210, 130)
    end

    return {
        Highlight = highlight,
        ArmorHighlight = armorHighlight,
        Billboard = billboard,
        Text = text,
        IsBot = isTargetBot,
        LastShown = false,
        LastXray = false,
        LastShowInfo = false,
        BoundChar = nil,
        CharBoundAt = 0,
        ArmorAdornee = nil,
    }
end

local function setupPlayer(player)
    if player == LocalPlayer then return end
    if ESP[player] then return end

    local data = createTargetData(false)
    ESP[player] = data

    local function bindCharacter(character)
        if Unloaded then return end

        data.BoundChar = character
        data.CharBoundAt = tick()

        data.Highlight.Adornee = character
        data.Billboard.Adornee = character:FindFirstChild("HumanoidRootPart")

        local welded = character:FindFirstChild("WeldedObjects")
        if welded then
            data.ArmorAdornee = welded
            data.ArmorHighlight.Adornee = welded
        else
            data.ArmorAdornee = nil
            data.ArmorHighlight.Adornee = nil
        end
    end

    if player.Character then
        bindCharacter(player.Character)
    end

    table.insert(Connections, player.CharacterAdded:Connect(function(character)
        task.wait(0.15)
        bindCharacter(character)
    end))

    table.insert(Connections, player.CharacterRemoving:Connect(function()
        data.Highlight.Adornee = nil
        data.ArmorHighlight.Adornee = nil
        data.ArmorAdornee = nil
        data.Billboard.Adornee = nil
        data.BoundChar = nil
        data.CharBoundAt = 0
    end))
end

for _, player in ipairs(Players:GetPlayers()) do
    setupPlayer(player)
    task.wait()
end

table.insert(Connections, Players.PlayerAdded:Connect(setupPlayer))

table.insert(Connections, Players.PlayerRemoving:Connect(function(player)
    local data = ESP[player]
    if data then
        if data.Highlight then data.Highlight:Destroy() end
        if data.ArmorHighlight then data.ArmorHighlight:Destroy() end
        if data.Billboard then data.Billboard:Destroy() end
        ESP[player] = nil
    end
end))

--------------------------------------------------
-- BOT REGISTRATION
--------------------------------------------------

local function removeBot(model)
    local data = BotESP[model]
    if not data then return end
    if data.Highlight then data.Highlight:Destroy() end
    if data.ArmorHighlight then data.ArmorHighlight:Destroy() end
    if data.Billboard then data.Billboard:Destroy() end
    BotESP[model] = nil
end

local function registerBot(model)
    if BotESP[model] then return end
    local data = createTargetData(true)
    BotESP[model] = data
    data.BoundChar = model
    data.CharBoundAt = tick()
    data.Highlight.Adornee = model
    data.Billboard.Adornee = model:FindFirstChild("HumanoidRootPart")

    local welded = model:FindFirstChild("WeldedObjects")
    if welded then
        data.ArmorAdornee = welded
        data.ArmorHighlight.Adornee = welded
    end
end

local function tryRegisterBot(obj)
    if Unloaded or not Settings.ShowBots then return end
    if not obj:IsA("Model") then return end
    if BotESP[obj] then return end
    if isPlayerCharacter(obj) then return end

    if isBot(obj) then
        registerBot(obj)
        return
    end

    task.delay(0.25, function()
        if Unloaded or not Settings.ShowBots then return end
        if BotESP[obj] then return end
        if obj.Parent and isBot(obj) then
            registerBot(obj)
        end
    end)
end

scanExistingBots = function()
    if Unloaded or not Settings.ShowBots then return end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if Unloaded or not Settings.ShowBots then break end
        if obj:IsA("Model") then
            tryRegisterBot(obj)
            task.wait()
        end
    end
end

removeAllBots = function()
    for model, _ in pairs(BotESP) do
        removeBot(model)
    end
end

table.insert(Connections, workspace.DescendantAdded:Connect(function(obj)
    if Settings.ShowBots then
        tryRegisterBot(obj)
    end
end))

table.insert(Connections, workspace.DescendantRemoving:Connect(function(obj)
    if BotESP[obj] then
        removeBot(obj)
    end
end))

--------------------------------------------------
-- DARK ENVIRONMENT
--------------------------------------------------

local DARK_VALUES = {
    Ambient = Color3.fromRGB(15, 15, 15),
    OutdoorAmbient = Color3.fromRGB(30, 30, 30),
    Brightness = 0.6,
    ClockTime = 0,
    GlobalShadows = true,
}

applyDarkValues = function()
    Lighting.Ambient = DARK_VALUES.Ambient
    Lighting.OutdoorAmbient = DARK_VALUES.OutdoorAmbient
    Lighting.Brightness = DARK_VALUES.Brightness
    Lighting.ClockTime = DARK_VALUES.ClockTime
    Lighting.GlobalShadows = DARK_VALUES.GlobalShadows
end

updateDarkEnvironment = function()
    if Settings.DarkEnvironment then
        if not SavedLighting then
            SavedLighting = {
                Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
                Brightness = Lighting.Brightness,
                ClockTime = Lighting.ClockTime,
                GlobalShadows = Lighting.GlobalShadows,
            }
        end
        applyDarkValues()
    else
        if SavedLighting then
            Lighting.Ambient = SavedLighting.Ambient
            Lighting.OutdoorAmbient = SavedLighting.OutdoorAmbient
            Lighting.Brightness = SavedLighting.Brightness
            Lighting.ClockTime = SavedLighting.ClockTime
            Lighting.GlobalShadows = SavedLighting.GlobalShadows
            SavedLighting = nil
        end
    end
end

--------------------------------------------------
-- KEYBINDS
--------------------------------------------------

table.insert(Connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if Unloaded then return end
    if gameProcessed then return end

    if input.KeyCode == THERMAL_KEYBIND then
        Settings.Thermal = not Settings.Thermal

        if not Settings.Thermal then
            if Settings.DarkEnvironment then
                DarkWasEnabledBeforeThermalOff = true
                Settings.DarkEnvironment = false
                updateDarkEnvironment()
                if RefreshDarkToggle then RefreshDarkToggle() end
            else
                DarkWasEnabledBeforeThermalOff = false
            end
        else
            if DarkWasEnabledBeforeThermalOff and not Settings.DarkEnvironment then
                Settings.DarkEnvironment = true
                DarkWasEnabledBeforeThermalOff = false
                updateDarkEnvironment()
                if RefreshDarkToggle then RefreshDarkToggle() end
            end
        end

        if RefreshThermalToggle then RefreshThermalToggle() end
        return
    end

    if input.KeyCode == REVEAL_KEYBIND then
        activateReveal()
        return
    end
end))

--------------------------------------------------
-- ESP UPDATE
--------------------------------------------------

local lastScan = 0

local function processTarget(target, data, camPos, effectiveMaxDistance, now)
    if not data.BoundChar or not data.BoundChar.Parent then
        if data.LastShown then
            data.Highlight.Enabled = false
            if data.ArmorHighlight then data.ArmorHighlight.Enabled = false end
            data.LastShown = false
        end
        if data.LastShowInfo then
            data.Billboard.Enabled = false
            data.LastShowInfo = false
        end
        return
    end

    local root = getRoot(data.BoundChar)
    if not root then return end

    local distance = (camPos - root.Position).Magnitude
    local withinDistance = distance <= effectiveMaxDistance

    local stable = (now - data.CharBoundAt) >= STREAM_GRACE

    local shouldShow = withinDistance and Settings.Thermal and stable
    if RevealActive and withinDistance and stable then
        shouldShow = true
    end

    if data.LastShown ~= shouldShow then
        data.Highlight.Enabled = shouldShow
        if data.ArmorHighlight then
            data.ArmorHighlight.Enabled = shouldShow and data.ArmorAdornee ~= nil
        end
        data.LastShown = shouldShow
    end

    if shouldShow then
        local wantXray = RevealActive
        if data.LastXray ~= wantXray then
            local mode = wantXray
                and Enum.HighlightDepthMode.AlwaysOnTop
                or  Enum.HighlightDepthMode.Occluded
            data.Highlight.DepthMode = mode
            if data.ArmorHighlight then
                data.ArmorHighlight.DepthMode = mode
            end
            data.LastXray = wantXray
        end
    end

    local showInfo = stable
        and (distance <= Settings.MaxDistance)
        and (Settings.ShowName or Settings.ShowDistance)

    if data.LastShowInfo ~= showInfo then
        data.Billboard.Enabled = showInfo
        data.LastShowInfo = showInfo
    end

    if showInfo then
        data.Billboard.Adornee = root
        local text = ""
        if Settings.ShowName then
            text = target.Name
        end
        if Settings.ShowDistance then
            if text ~= "" then text = text .. "\n" end
            text = text .. math.floor(distance) .. " studs"
        end
        if data.Text.Text ~= text then
            data.Text.Text = text
        end
    end
end

table.insert(Connections, RunService.Heartbeat:Connect(function()
    if Unloaded then return end

    if Settings.DarkEnvironment then
        applyDarkValues()
    end

    local now = tick()
    if now - lastScan < (1 / math.max(Settings.ScanRate, 1)) then
        return
    end
    lastScan = now

    local camPos = Camera.CFrame.Position
    local effectiveMaxDistance = RevealActive and math.huge or Settings.MaxDistance

    for player, data in pairs(ESP) do
        processTarget(player, data, camPos, effectiveMaxDistance, now)
    end

    for model, data in pairs(BotESP) do
        processTarget(model, data, camPos, effectiveMaxDistance, now)
    end
end))

--------------------------------------------------
-- INITIAL DARK EFFECT
--------------------------------------------------

updateDarkEnvironment()
