local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local LocalPlayer = Players.LocalPlayer

local GetEnv: any = (getgenv and getgenv()) or getfenv()
if GetEnv.SkipRobloxOwnedAnimations == nil then
    GetEnv.SkipRobloxOwnedAnimations = false
end

local SetClipboard: any = rawget(GetEnv, "setclipboard")
if not SetClipboard then
    local Syn: any = rawget(GetEnv, "syn")
    if type(Syn) == "table" and rawget(Syn, "write_clipboard") then
        SetClipboard = rawget(Syn, "write_clipboard")
    elseif rawget(GetEnv, "toclipboard") then
        SetClipboard = rawget(GetEnv, "toclipboard")
    else
        SetClipboard = function(Txt: any) end
    end
end

local ParentGui: any = nil
pcall(function()
    local GetHui: any = rawget(GetEnv, "gethui")
    if type(GetHui) == "function" then
        ParentGui = GetHui()
    elseif CoreGui then
        ParentGui = CoreGui
    end
end)
if not ParentGui then
    ParentGui = LocalPlayer:WaitForChild("PlayerGui")
end

local OldGui = ParentGui:FindFirstChild("AnimLoggerUI_🗿")
if OldGui then
    OldGui:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AnimLoggerUI_🗿"
ScreenGui.DisplayOrder = 500
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = ParentGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.BackgroundColor3 = Color3.fromRGB(44, 47, 51)
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.1, 0, 0.2, 0)
MainFrame.Size = UDim2.new(0, 260, 0, 360)
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 6)
MainCorner.Parent = MainFrame

local DragBar = Instance.new("Frame")
DragBar.Name = "DragBar"
DragBar.BackgroundColor3 = Color3.fromRGB(114, 137, 218)
DragBar.BorderSizePixel = 0
DragBar.Size = UDim2.new(1, 0, 0, 22)
DragBar.Parent = MainFrame

local DragCorner = Instance.new("UICorner")
DragCorner.CornerRadius = UDim.new(0, 6)
DragCorner.Parent = DragBar

local DragBottomCover = Instance.new("Frame")
DragBottomCover.BackgroundColor3 = Color3.fromRGB(114, 137, 218)
DragBottomCover.BorderSizePixel = 0
DragBottomCover.Position = UDim2.new(0, 0, 1, -6)
DragBottomCover.Size = UDim2.new(1, 0, 0, 6)
DragBottomCover.Parent = DragBar

local function MakeDraggable(Frame: Frame, DragHandle: Frame)
    local Dragging = false
    local DragInput: InputObject? = nil
    local DragStart: Vector3 = Vector3.zero
    local StartPos: UDim2 = UDim2.new()

    DragHandle.InputBegan:Connect(function(Input)
        if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch)
            and UserInputService:GetFocusedTextBox() == nil then
            Dragging = true
            DragStart = Input.Position
            StartPos = Frame.Position

            Input.Changed:Connect(function()
                if Input.UserInputState == Enum.UserInputState.End then
                    Dragging = false
                end
            end)
        end
    end)

    DragHandle.InputChanged:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then
            DragInput = Input
        end
    end)

    UserInputService.InputChanged:Connect(function(Input)
        if Input == DragInput and Dragging then
            local Delta = Input.Position - DragStart
            Frame.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + Delta.X, StartPos.Y.Scale, StartPos.Y.Offset + Delta.Y)
        end
    end)
end
MakeDraggable(MainFrame, DragBar)

local SearchContainer = Instance.new("Frame")
SearchContainer.Name = "SearchContainer"
SearchContainer.BackgroundColor3 = Color3.fromRGB(35, 39, 42)
SearchContainer.BorderSizePixel = 0
SearchContainer.Position = UDim2.new(0, 0, 0, 22)
SearchContainer.Size = UDim2.new(1, 0, 0, 32)
SearchContainer.Parent = MainFrame

local SearchBox = Instance.new("TextBox")
SearchBox.Name = "SearchBox"
SearchBox.BackgroundTransparency = 1
SearchBox.Size = UDim2.new(1, -16, 1, 0)
SearchBox.Position = UDim2.new(0, 8, 0, 0)
SearchBox.PlaceholderText = "Player name (blank = everyone)"
SearchBox.PlaceholderColor3 = Color3.fromRGB(145, 150, 160)
SearchBox.Text = ""
SearchBox.TextColor3 = Color3.fromRGB(245, 245, 245)
SearchBox.TextSize = 13
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextXAlignment = Enum.TextXAlignment.Center
SearchBox.ClearTextOnFocus = false
SearchBox.Parent = SearchContainer

local SearchDivider = Instance.new("Frame")
SearchDivider.BackgroundColor3 = Color3.fromRGB(32, 34, 37)
SearchDivider.BorderSizePixel = 0
SearchDivider.Position = UDim2.new(0, 0, 1, -1)
SearchDivider.Size = UDim2.new(1, 0, 0, 1)
SearchDivider.Parent = SearchContainer

local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Name = "AnimationList"
ScrollFrame.BackgroundColor3 = Color3.fromRGB(44, 47, 51)
ScrollFrame.BorderSizePixel = 0
ScrollFrame.Position = UDim2.new(0, 0, 0, 54)
ScrollFrame.Size = UDim2.new(1, 0, 1, -54)
ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(32, 34, 37)
ScrollFrame.Parent = MainFrame

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 1)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = ScrollFrame

local AnimationTable: { [string]: boolean } = {}
local CreatedEntries: { { Button: TextButton, PlayerName: string, Id: string } } = {}
local NameCache: { [number]: string } = {}
local OwnerCache: { [number]: boolean } = {}
local CurrentFilter = ""

local function CheckRobloxOwned(NumId: number): (boolean, string?)
    if OwnerCache[NumId] ~= nil then
        return OwnerCache[NumId], NameCache[NumId]
    end

    local Success, Info = pcall(function()
        return MarketplaceService:GetProductInfo(NumId, Enum.InfoType.Asset)
    end)

    if Success and Info then
        if Info.Name then
            NameCache[NumId] = Info.Name
        end
        if Info.Creator then
            local CreatorName = string.lower(tostring(Info.Creator.Name or ""))
            local CreatorId = Info.Creator.Id or Info.Creator.CreatorTargetId
            if CreatorName == "roblox" or CreatorId == 1 then
                OwnerCache[NumId] = true
                return true, Info.Name
            end
        end
    end

    OwnerCache[NumId] = false
    return false, (Info and Info.Name)
end

local function ResolveAnimationName(IdStr: string, TrackName: string?): string
    local NumId = tonumber(IdStr)
    if not NumId then return TrackName or "Animation" end
    if NameCache[NumId] then return NameCache[NumId] end

    if TrackName and TrackName ~= "" and TrackName ~= "Animation" and TrackName ~= "AnimationTrack" and TrackName ~= "Anim" then
        NameCache[NumId] = TrackName
        return TrackName
    end

    local _, FetchedName = CheckRobloxOwned(NumId)
    if FetchedName and FetchedName ~= "" then
        NameCache[NumId] = FetchedName
        return FetchedName
    end

    NameCache[NumId] = TrackName or "Animation"
    return NameCache[NumId]
end

local function CreateButton(PlayerName: string, AnimName: string, StrId: string)
    local Button = Instance.new("TextButton")
    Button.Name = PlayerName .. "_" .. StrId
    Button.BorderSizePixel = 0
    Button.BackgroundColor3 = Color3.fromRGB(35, 39, 42)
    Button.Size = UDim2.new(1, 0, 0, 48)
    Button.Text = ""
    Button.AutoButtonColor = true
    Button.Parent = ScrollFrame

    local NameLabel = Instance.new("TextLabel")
    NameLabel.Name = "HeaderLabel"
    NameLabel.BackgroundTransparency = 1
    NameLabel.Position = UDim2.new(0, 8, 0, 4)
    NameLabel.Size = UDim2.new(1, -16, 0, 20)
    NameLabel.TextSize = 14
    NameLabel.Font = Enum.Font.Gotham
    NameLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
    NameLabel.TextXAlignment = Enum.TextXAlignment.Left
    NameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    NameLabel.Text = PlayerName .. " - " .. AnimName
    NameLabel.Parent = Button

    local IdLabel = Instance.new("TextLabel")
    IdLabel.Name = "IdLabel"
    IdLabel.BackgroundTransparency = 1
    IdLabel.Position = UDim2.new(0, 8, 0, 24)
    IdLabel.Size = UDim2.new(1, -16, 0, 18)
    IdLabel.TextSize = 13
    IdLabel.Font = Enum.Font.Gotham
    IdLabel.TextColor3 = Color3.fromRGB(180, 185, 195)
    IdLabel.TextXAlignment = Enum.TextXAlignment.Left
    IdLabel.Text = StrId
    IdLabel.Parent = Button

    local Filter = string.lower(CurrentFilter)
    if Filter ~= "" and not string.find(string.lower(PlayerName), Filter, 1, true) then
        Button.Visible = false
    end

    Button.Activated:Connect(function()
        pcall(SetClipboard, StrId)
        local OrigText = IdLabel.Text
        local OrigColor = IdLabel.TextColor3
        IdLabel.Text = "✓ Copied to clipboard (" .. StrId .. ")"
        IdLabel.TextColor3 = Color3.fromRGB(60, 240, 140)
        task.delay(1, function()
            if IdLabel and IdLabel.Parent then
                IdLabel.Text = OrigText
                IdLabel.TextColor3 = OrigColor
            end
        end)
    end)

    table.insert(CreatedEntries, {
        Button = Button,
        PlayerName = PlayerName,
        Id = StrId
    })
end

local function UpdateFilter()
    local Text = string.lower(SearchBox.Text:gsub("^%s*(.-)%s*$", "%1"))
    CurrentFilter = Text
    for _, Item in ipairs(CreatedEntries) do
        if Text == "" or string.find(string.lower(Item.PlayerName), Text, 1, true) then
            Item.Button.Visible = true
        else
            Item.Button.Visible = false
        end
    end
end
SearchBox:GetPropertyChangedSignal("Text"):Connect(UpdateFilter)

local function ScanPlayer(Player: Player)
    if not Player or not Player.Character then return end
    local Humanoid = Player.Character:FindFirstChildOfClass("Humanoid")
    if not Humanoid then return end

    local Tracks = Humanoid:GetPlayingAnimationTracks()
    for _, Track in ipairs(Tracks) do
        local Anim = Track.Animation
        if Anim and Anim.AnimationId and Anim.AnimationId ~= "" then
            local StrId = string.match(Anim.AnimationId, "%d+")
            if StrId and StrId ~= "" then
                local NumId = tonumber(StrId)
                if NumId and GetEnv.SkipRobloxOwnedAnimations then
                    local IsRobloxOwned = CheckRobloxOwned(NumId)
                    if IsRobloxOwned then
                        continue
                    end
                end

                local Signature = Player.Name .. "_" .. StrId
                if not AnimationTable[Signature] then
                    AnimationTable[Signature] = true
                    task.spawn(function()
                        local AnimName = ResolveAnimationName(StrId, Track.Name)
                        CreateButton(Player.Name, AnimName, StrId)
                    end)
                end
            end
        end
    end
end

task.spawn(function()
    while true do
        local FilterText = string.lower(CurrentFilter)
        local PlayerList = Players:GetPlayers()
        for _, Player in ipairs(PlayerList) do
            if FilterText == "" or string.find(string.lower(Player.Name), FilterText, 1, true) or string.find(string.lower(Player.DisplayName), FilterText, 1, true) then
                pcall(ScanPlayer, Player)
            end
        end
        task.wait(0.2)
    end
end)
