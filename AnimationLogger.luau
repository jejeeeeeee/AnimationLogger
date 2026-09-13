local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local LocalPlayer = Players.LocalPlayer

local GetEnv: any = (getgenv and getgenv()) or getfenv()
if GetEnv.SkipRobloxOwnedAnimations == nil then
    GetEnv.SkipRobloxOwnedAnimations = false
end
if GetEnv.InitAdvancedAnimationLogger == nil then
    GetEnv.InitAdvancedAnimationLogger = false
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

local NameCache: { [number]: string } = {}
local OwnerCache: { [number]: boolean } = {}

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

if GetEnv.InitAdvancedAnimationLogger then
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
    MainFrame.BorderSizePixel = 0
    MainFrame.Position = UDim2.new(0.05, 0, 0.2, 0)
    MainFrame.Size = UDim2.new(0, 360, 0, 400)
    MainFrame.Active = true
    MainFrame.Parent = ScreenGui

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 4)
    MainCorner.Parent = MainFrame

    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(50, 50, 50)
    MainStroke.Thickness = 1
    MainStroke.Parent = MainFrame

    local DragBar = Instance.new("Frame")
    DragBar.Name = "DragBar"
    DragBar.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    DragBar.BorderSizePixel = 0
    DragBar.Size = UDim2.new(1, 0, 0, 26)
    DragBar.Parent = MainFrame

    local DragCorner = Instance.new("UICorner")
    DragCorner.CornerRadius = UDim.new(0, 4)
    DragCorner.Parent = DragBar

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Name = "TitleLabel"
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Size = UDim2.new(1, 0, 1, 0)
    TitleLabel.Font = Enum.Font.RobotoMono
    TitleLabel.TextSize = 13
    TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.Text = "Animation Tracker (0 unique)"
    TitleLabel.Parent = DragBar

    MakeDraggable(MainFrame, DragBar)

    local ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Name = "AnimationList"
    ScrollFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    ScrollFrame.BorderSizePixel = 0
    ScrollFrame.Position = UDim2.new(0, 0, 0, 26)
    ScrollFrame.Size = UDim2.new(1, 0, 1, -26)
    ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    ScrollFrame.ScrollBarThickness = 4
    ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
    ScrollFrame.Parent = MainFrame

    local ListLayout = Instance.new("UIListLayout")
    ListLayout.Padding = UDim.new(0, 3)
    ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ListLayout.Parent = ScrollFrame

    local ListPadding = Instance.new("UIPadding")
    ListPadding.PaddingLeft = UDim.new(0, 6)
    ListPadding.PaddingRight = UDim.new(0, 6)
    ListPadding.PaddingTop = UDim.new(0, 6)
    ListPadding.PaddingBottom = UDim.new(0, 6)
    ListPadding.Parent = ScrollFrame

    local UniqueCount = 0
    local AdvancedEntries: {
        [string]: {
            Plays: number,
            Last: string,
            Sources: { [string]: boolean },
            StatsLabel: TextLabel,
            SourcesLabel: TextLabel,
        }
    } = {}

    local function LogAdvancedAnimation(Player: Player, Track: AnimationTrack, StrId: string, NumId: number)
        local RawId = Track.Animation and Track.Animation.AnimationId or ("rbxassetid://" .. StrId)
        local SourcePath = Player.Character and Player.Character:GetFullName() .. ".Humanoid" or (Player.Name .. ".Humanoid")

        if AdvancedEntries[StrId] then
            local Entry = AdvancedEntries[StrId]
            Entry.Plays += 1
            Entry.Last = os.date("%X")
            Entry.Sources[SourcePath] = true

            Entry.StatsLabel.Text = string.format("plays: %d | last: %s", Entry.Plays, Entry.Last)

            local SourceList = {}
            for S in pairs(Entry.Sources) do
                table.insert(SourceList, S)
            end
            Entry.SourcesLabel.Text = "sources: " .. table.concat(SourceList, ", ")
            return
        end

        UniqueCount += 1
        TitleLabel.Text = string.format("Animation Tracker (%d unique)", UniqueCount)

        local Card = Instance.new("TextButton")
        Card.Name = "Entry_" .. StrId
        Card.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
        Card.BorderSizePixel = 0
        Card.Size = UDim2.new(1, 0, 0, 72)
        Card.Text = ""
        Card.AutoButtonColor = true
        Card.Parent = ScrollFrame

        local CardCorner = Instance.new("UICorner")
        CardCorner.CornerRadius = UDim.new(0, 4)
        CardCorner.Parent = Card

        local CardStroke = Instance.new("UIStroke")
        CardStroke.Color = Color3.fromRGB(40, 40, 40)
        CardStroke.Thickness = 1
        CardStroke.Parent = Card

        local NameLine = Instance.new("TextLabel")
        NameLine.Name = "NameLine"
        NameLine.BackgroundTransparency = 1
        NameLine.Position = UDim2.new(0, 6, 0, 4)
        NameLine.Size = UDim2.new(1, -12, 0, 16)
        NameLine.Font = Enum.Font.RobotoMono
        NameLine.TextSize = 12
        NameLine.TextColor3 = Color3.fromRGB(240, 240, 240)
        NameLine.TextXAlignment = Enum.TextXAlignment.Left
        NameLine.TextTruncate = Enum.TextTruncate.AtEnd
        NameLine.Text = ResolveAnimationName(StrId, Track.Name)
        NameLine.Parent = Card

        local UrlLine = Instance.new("TextLabel")
        UrlLine.Name = "UrlLine"
        UrlLine.BackgroundTransparency = 1
        UrlLine.Position = UDim2.new(0, 6, 0, 20)
        UrlLine.Size = UDim2.new(1, -12, 0, 16)
        UrlLine.Font = Enum.Font.RobotoMono
        UrlLine.TextSize = 11
        UrlLine.TextColor3 = Color3.fromRGB(180, 180, 180)
        UrlLine.TextXAlignment = Enum.TextXAlignment.Left
        UrlLine.TextTruncate = Enum.TextTruncate.AtEnd
        UrlLine.Text = RawId
        UrlLine.Parent = Card

        local StatsLine = Instance.new("TextLabel")
        StatsLine.Name = "StatsLine"
        StatsLine.BackgroundTransparency = 1
        StatsLine.Position = UDim2.new(0, 6, 0, 36)
        StatsLine.Size = UDim2.new(1, -12, 0, 16)
        StatsLine.Font = Enum.Font.RobotoMono
        StatsLine.TextSize = 11
        StatsLine.TextColor3 = Color3.fromRGB(150, 150, 150)
        StatsLine.TextXAlignment = Enum.TextXAlignment.Left
        StatsLine.Text = string.format("plays: 1 | last: %s", os.date("%X"))
        StatsLine.Parent = Card

        local SourcesLine = Instance.new("TextLabel")
        SourcesLine.Name = "SourcesLine"
        SourcesLine.BackgroundTransparency = 1
        SourcesLine.Position = UDim2.new(0, 6, 0, 52)
        SourcesLine.Size = UDim2.new(1, -12, 0, 16)
        SourcesLine.Font = Enum.Font.RobotoMono
        SourcesLine.TextSize = 11
        SourcesLine.TextColor3 = Color3.fromRGB(130, 130, 130)
        SourcesLine.TextXAlignment = Enum.TextXAlignment.Left
        SourcesLine.TextTruncate = Enum.TextTruncate.AtEnd
        SourcesLine.Text = "sources: " .. SourcePath
        SourcesLine.Parent = Card

        Card.Activated:Connect(function()
            pcall(SetClipboard, StrId)
            local PrevColor = NameLine.TextColor3
            local PrevText = NameLine.Text
            NameLine.Text = "✓ Copied ID: " .. StrId
            NameLine.TextColor3 = Color3.fromRGB(80, 240, 140)
            task.delay(1, function()
                if NameLine and NameLine.Parent then
                    NameLine.Text = PrevText
                    NameLine.TextColor3 = PrevColor
                end
            end)
        end)

        AdvancedEntries[StrId] = {
            Plays = 1,
            Last = os.date("%X"),
            Sources = { [SourcePath] = true },
            StatsLabel = StatsLine,
            SourcesLabel = SourcesLine,
        }
    end

    local function ScanPlayerAdvanced(Player: Player)
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
                    task.spawn(LogAdvancedAnimation, Player, Track, StrId, NumId or 0)
                end
            end
        end
    end

    task.spawn(function()
        while true do
            for _, Player in ipairs(Players:GetPlayers()) do
                pcall(ScanPlayerAdvanced, Player)
            end
            task.wait(0.2)
        end
    end)
else
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
    local CurrentFilter = ""

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
end
