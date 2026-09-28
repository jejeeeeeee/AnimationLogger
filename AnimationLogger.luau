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

local OldGui = ParentGui:FindFirstChild("AnimTrackerUI_🗿") or ParentGui:FindFirstChild("AnimLoggerUI_🗿")
if OldGui then
    OldGui:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AnimTrackerUI_🗿"
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

local function ResolvePath(PathStr: string): Instance?
    if typeof(PathStr) ~= "string" or PathStr == "" then
        return nil
    end

    local Clean = PathStr:gsub("^%s*(.-)%s*$", "%1")
    if Clean == "" then
        return nil
    end

    Clean = Clean:gsub('game:GetService%("Workspace"%)', "workspace")
    Clean = Clean:gsub("game:GetService%('Workspace'%)", "workspace")
    Clean = Clean:gsub('game:GetService%("([^"]+)"%)', "game.%1")
    Clean = Clean:gsub("game:GetService%('([^']+)'%)", "game.%1")
    Clean = Clean:gsub(':WaitForChild%("([^"]+)"%)', ".%1")
    Clean = Clean:gsub(":WaitForChild%('([^']+)'%)", ".%1")
    Clean = Clean:gsub(':FindFirstChild%("([^"]+)"%)', ".%1")
    Clean = Clean:gsub(":FindFirstChild%('([^']+)'%)", ".%1")
    Clean = Clean:gsub('%["([^"]+)"%]', ".%1")
    Clean = Clean:gsub("%['([^']+)'%]", ".%1")
    Clean = Clean:gsub("%[([^%]]+)%]", ".%1")
    Clean = Clean:gsub("[/\\]", ".")

    local Segments: { string } = {}
    for Seg in string.gmatch(Clean, "[^%.]+") do
        if Seg ~= "" then
            table.insert(Segments, Seg)
        end
    end

    if #Segments == 0 then
        return nil
    end

    local Current: any = nil
    local StartIdx = 1

    local FirstLower = string.lower(Segments[1])
    if FirstLower == "game" then
        Current = game
        StartIdx = 2
    elseif FirstLower == "workspace" then
        Current = workspace
        StartIdx = 2
    elseif FirstLower == "localplayer" then
        Current = (LocalPlayer and LocalPlayer.Character) or LocalPlayer
        StartIdx = 2
    else
        Current = workspace:FindFirstChild(Segments[1])
        if not Current then
            local TargetLower = string.lower(Segments[1])
            for _, Child in ipairs(workspace:GetChildren()) do
                if string.lower(Child.Name) == TargetLower then
                    Current = Child
                    break
                end
            end
        end

        if not Current then
            Current = game:FindFirstChild(Segments[1])
            if not Current then
                local TargetLower = string.lower(Segments[1])
                for _, Child in ipairs(game:GetChildren()) do
                    if string.lower(Child.Name) == TargetLower then
                        Current = Child
                        break
                    end
                end
            end
        end

        if Current then
            StartIdx = 2
        else
            return nil
        end
    end

    for i = StartIdx, #Segments do
        local TargetName = Segments[i]
        local Found = Current:FindFirstChild(TargetName)
        if not Found and Current == game then
            pcall(function()
                Found = game:GetService(TargetName)
            end)
        end
        if not Found and Current:IsA("Players") and string.lower(TargetName) == "localplayer" then
            Found = LocalPlayer
        end
        if not Found and Current:IsA("Player") and string.lower(TargetName) == "character" then
            Found = Current.Character
        end
        if not Found then
            local TargetLower = string.lower(TargetName)
            for _, Child in ipairs(Current:GetChildren()) do
                if string.lower(Child.Name) == TargetLower then
                    Found = Child
                    break
                end
            end
        end
        if not Found then
            return nil
        end
        Current = Found
    end

    return Current
end

local function CollectTracksFromInstance(Inst: Instance): { AnimationTrack }
    local FoundTracks: { AnimationTrack } = {}
    local Visited: { [any]: boolean } = {}

    local function QueryTracks(Obj: any)
        if not Obj or Visited[Obj] then return end
        Visited[Obj] = true

        local Success, Tracks = pcall(function()
            return Obj:GetPlayingAnimationTracks()
        end)
        if Success and typeof(Tracks) == "table" then
            for _, Track in ipairs(Tracks) do
                table.insert(FoundTracks, Track)
            end
        end
    end

    if Inst:IsA("AnimationTrack") then
        table.insert(FoundTracks, Inst)
    elseif Inst:IsA("Animator") or Inst:IsA("AnimationController") or Inst:IsA("Humanoid") then
        QueryTracks(Inst)
        local ChildAnimator = Inst:FindFirstChildOfClass("Animator")
        if ChildAnimator then
            QueryTracks(ChildAnimator)
        end
    else
        for _, Desc in ipairs(Inst:GetDescendants()) do
            if Desc:IsA("Animator") or Desc:IsA("AnimationController") or Desc:IsA("Humanoid") then
                QueryTracks(Desc)
            end
        end
    end

    return FoundTracks
end

local function CollectAnimationsFromInstance(Inst: Instance): { { AnimationId: string, Name: string } }
    local FoundAnims: { { AnimationId: string, Name: string } } = {}

    if Inst:IsA("Animation") and Inst.AnimationId ~= "" then
        table.insert(FoundAnims, { AnimationId = Inst.AnimationId, Name = Inst.Name })
    end

    for _, Desc in ipairs(Inst:GetDescendants()) do
        if Desc:IsA("Animation") and Desc.AnimationId ~= "" then
            table.insert(FoundAnims, { AnimationId = Desc.AnimationId, Name = Desc.Name })
        end
    end

    return FoundAnims
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
        if Info.Name and Info.Name ~= "" and Info.Name ~= "Animation" then
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

local function ResolveAnimationName(IdStr: string, TrackName: string?, AnimInstanceName: string?): string
    local NumId = tonumber(IdStr)
    if NumId and NameCache[NumId] and NameCache[NumId] ~= "" and NameCache[NumId] ~= "Animation" then
        return NameCache[NumId]
    end

    if TrackName and TrackName ~= "" and TrackName ~= "Animation" and TrackName ~= "AnimationTrack" and TrackName ~= "Anim" then
        if NumId then NameCache[NumId] = TrackName end
        return TrackName
    end

    if AnimInstanceName and AnimInstanceName ~= "" and AnimInstanceName ~= "Animation" and AnimInstanceName ~= "AnimationTrack" and AnimInstanceName ~= "Anim" then
        if NumId then NameCache[NumId] = AnimInstanceName end
        return AnimInstanceName
    end

    if NumId then
        local Success, Info = pcall(function()
            return MarketplaceService:GetProductInfo(NumId, Enum.InfoType.Asset)
        end)
        if Success and Info and Info.Name and Info.Name ~= "" and Info.Name ~= "Animation" then
            NameCache[NumId] = Info.Name
            return Info.Name
        end
    end

    local Fallback = "Unknown"
    if NumId then NameCache[NumId] = Fallback end
    return Fallback
end

if GetEnv.InitAdvancedAnimationLogger then
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    MainFrame.BorderSizePixel = 0
    MainFrame.Position = UDim2.new(0.08, 0, 0.15, 0)
    MainFrame.Size = UDim2.new(0, 370, 0, 420)
    MainFrame.Active = true
    MainFrame.Parent = ScreenGui

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 4)
    MainCorner.Parent = MainFrame

    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.BackgroundTransparency = 1
    TitleBar.Size = UDim2.new(1, 0, 0, 26)
    TitleBar.Parent = MainFrame

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Name = "TitleLabel"
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Size = UDim2.new(1, 0, 1, 0)
    TitleLabel.Font = Enum.Font.Code
    TitleLabel.TextSize = 13
    TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.Text = "Animation Tracker (0 unique)"
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Center
    TitleLabel.Parent = TitleBar

    MakeDraggable(MainFrame, TitleBar)

    local SearchContainer = Instance.new("Frame")
    SearchContainer.Name = "SearchContainer"
    SearchContainer.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    SearchContainer.BorderSizePixel = 0
    SearchContainer.Position = UDim2.new(0, 8, 0, 26)
    SearchContainer.Size = UDim2.new(1, -16, 0, 24)
    SearchContainer.Parent = MainFrame

    local SearchCorner = Instance.new("UICorner")
    SearchCorner.CornerRadius = UDim.new(0, 3)
    SearchCorner.Parent = SearchContainer

    local SearchBox = Instance.new("TextBox")
    SearchBox.Name = "SearchBox"
    SearchBox.BackgroundTransparency = 1
    SearchBox.Size = UDim2.new(1, -12, 1, 0)
    SearchBox.Position = UDim2.new(0, 6, 0, 0)
    SearchBox.PlaceholderText = "Player name or Path (blank = everyone)"
    SearchBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
    SearchBox.Text = ""
    SearchBox.TextColor3 = Color3.fromRGB(240, 240, 240)
    SearchBox.TextSize = 11
    SearchBox.Font = Enum.Font.Code
    SearchBox.TextXAlignment = Enum.TextXAlignment.Center
    SearchBox.ClearTextOnFocus = false
    SearchBox.Parent = SearchContainer

    local ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Name = "AnimationList"
    ScrollFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    ScrollFrame.BackgroundTransparency = 1
    ScrollFrame.BorderSizePixel = 0
    ScrollFrame.Position = UDim2.new(0, 8, 0, 54)
    ScrollFrame.Size = UDim2.new(1, -12, 1, -58)
    ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    ScrollFrame.ScrollBarThickness = 5
    ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(120, 120, 120)
    ScrollFrame.Parent = MainFrame

    local ListLayout = Instance.new("UIListLayout")
    ListLayout.Padding = UDim.new(0, 10)
    ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ListLayout.Parent = ScrollFrame

    local UniqueCount = 0
    local AdvancedEntries: {
        [string]: {
            Plays: number,
            Last: string,
            Sources: { [string]: boolean },
            EntryContainer: TextButton,
            TitleLabel: TextLabel,
            StatsLabel: TextLabel,
            SourcesLabel: TextLabel,
        }
    } = {}
    local CurrentFilter = ""

    local function MatchesFilter(Entry: any, FilterText: string, TargetPathInstance: Instance?): boolean
        if FilterText == "" then
            return true
        end
        if TargetPathInstance then
            local InstName = string.lower(TargetPathInstance.Name)
            local FullName = string.lower(TargetPathInstance:GetFullName())
            for Source in pairs(Entry.Sources) do
                local LowerSource = string.lower(Source)
                if string.find(LowerSource, FullName, 1, true) or string.find(LowerSource, InstName, 1, true) then
                    return true
                end
            end
            return false
        end
        for Source in pairs(Entry.Sources) do
            if string.find(string.lower(Source), FilterText, 1, true) then
                return true
            end
        end
        if string.find(string.lower(Entry.TitleLabel.Text), FilterText, 1, true) then
            return true
        end
        return false
    end

    local function UpdateAdvancedFilter()
        local Text = string.lower(CurrentFilter)
        local TargetPathInstance = ResolvePath(CurrentFilter)
        for _, Entry in pairs(AdvancedEntries) do
            Entry.EntryContainer.Visible = MatchesFilter(Entry, Text, TargetPathInstance)
        end
    end

    local function LogAdvancedAnimation(SourcePath: string, RawTrackName: string?, RawAnimId: string, StrId: string, NumId: number)
        local RawId = (RawAnimId ~= "" and RawAnimId) or ("rbxassetid://" .. StrId)

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

        local EntryContainer = Instance.new("TextButton")
        EntryContainer.Name = "Entry_" .. StrId
        EntryContainer.BackgroundTransparency = 1
        EntryContainer.BorderSizePixel = 0
        EntryContainer.Size = UDim2.new(1, -6, 0, 64)
        EntryContainer.Text = ""
        EntryContainer.AutoButtonColor = false
        EntryContainer.Parent = ScrollFrame

        local FastName = (NumId and NameCache[NumId]) or (RawTrackName and RawTrackName ~= "" and RawTrackName ~= "Animation" and RawTrackName ~= "AnimationTrack" and RawTrackName) or "Loading..."
        local DisplayHeader = (string.find(FastName, "^Animation:") and FastName) or ("Animation: " .. FastName)

        local Line1 = Instance.new("TextLabel")
        Line1.Name = "Line1"
        Line1.BackgroundTransparency = 1
        Line1.Position = UDim2.new(0, 0, 0, 0)
        Line1.Size = UDim2.new(1, 0, 0, 15)
        Line1.Font = Enum.Font.Code
        Line1.TextSize = 12
        Line1.TextColor3 = Color3.fromRGB(225, 225, 225)
        Line1.TextXAlignment = Enum.TextXAlignment.Left
        Line1.TextTruncate = Enum.TextTruncate.AtEnd
        Line1.Text = DisplayHeader
        Line1.Parent = EntryContainer

        local Line2 = Instance.new("TextLabel")
        Line2.Name = "Line2"
        Line2.BackgroundTransparency = 1
        Line2.Position = UDim2.new(0, 0, 0, 15)
        Line2.Size = UDim2.new(1, 0, 0, 15)
        Line2.Font = Enum.Font.Code
        Line2.TextSize = 12
        Line2.TextColor3 = Color3.fromRGB(225, 225, 225)
        Line2.TextXAlignment = Enum.TextXAlignment.Left
        Line2.TextTruncate = Enum.TextTruncate.AtEnd
        Line2.Text = RawId
        Line2.Parent = EntryContainer

        local Line3 = Instance.new("TextLabel")
        Line3.Name = "Line3"
        Line3.BackgroundTransparency = 1
        Line3.Position = UDim2.new(0, 0, 0, 30)
        Line3.Size = UDim2.new(1, 0, 0, 15)
        Line3.Font = Enum.Font.Code
        Line3.TextSize = 12
        Line3.TextColor3 = Color3.fromRGB(225, 225, 225)
        Line3.TextXAlignment = Enum.TextXAlignment.Left
        Line3.Text = string.format("plays: 1 | last: %s", os.date("%X"))
        Line3.Parent = EntryContainer

        local Line4 = Instance.new("TextLabel")
        Line4.Name = "Line4"
        Line4.BackgroundTransparency = 1
        Line4.Position = UDim2.new(0, 0, 0, 45)
        Line4.Size = UDim2.new(1, 0, 0, 15)
        Line4.Font = Enum.Font.Code
        Line4.TextSize = 12
        Line4.TextColor3 = Color3.fromRGB(225, 225, 225)
        Line4.TextXAlignment = Enum.TextXAlignment.Left
        Line4.TextTruncate = Enum.TextTruncate.AtEnd
        Line4.Text = "sources: " .. SourcePath
        Line4.Parent = EntryContainer

        EntryContainer.Activated:Connect(function()
            pcall(SetClipboard, StrId)
            local PrevColor = Line1.TextColor3
            local PrevText = Line1.Text
            Line1.Text = "Copied: " .. StrId
            Line1.TextColor3 = Color3.fromRGB(60, 240, 140)
            task.delay(1, function()
                if Line1 and Line1.Parent then
                    Line1.Text = PrevText
                    Line1.TextColor3 = PrevColor
                end
            end)
        end)

        local NewEntry = {
            Plays = 1,
            Last = os.date("%X"),
            Sources = { [SourcePath] = true },
            EntryContainer = EntryContainer,
            TitleLabel = Line1,
            StatsLabel = Line3,
            SourcesLabel = Line4,
        }
        AdvancedEntries[StrId] = NewEntry

        EntryContainer.Visible = MatchesFilter(NewEntry, string.lower(CurrentFilter), ResolvePath(CurrentFilter))

        task.spawn(function()
            local Fetched = ResolveAnimationName(StrId, RawTrackName, nil)
            if Fetched and Fetched ~= "" and Line1 and Line1.Parent then
                Line1.Text = (string.find(Fetched, "^Animation:") and Fetched) or ("Animation: " .. Fetched)
            end
        end)
    end

    local function ScanPlayerAdvanced(Player: Player)
        if not Player or not Player.Character then return end
        local Humanoid = Player.Character:FindFirstChildOfClass("Humanoid")
        if not Humanoid then return end

        local SourcePath = "Workspace.Players." .. Player.Name .. ".Humanoid"
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
                    local TrackSource = SourcePath
                    if Track.Name and Track.Name ~= "" and Track.Name ~= "Animation" then
                        TrackSource = TrackSource .. " (" .. Track.Name .. ")"
                    end
                    task.spawn(LogAdvancedAnimation, TrackSource, Track.Name, Anim.AnimationId, StrId, NumId or 0)
                end
            end
        end
    end

    SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        CurrentFilter = SearchBox.Text:gsub("^%s*(.-)%s*$", "%1")
        UpdateAdvancedFilter()
    end)

    task.spawn(function()
        while true do
            local InputText = string.lower(CurrentFilter)
            local TargetPathInstance = ResolvePath(CurrentFilter)

            if TargetPathInstance then
                local SourceName = TargetPathInstance:GetFullName()
                local Tracks = CollectTracksFromInstance(TargetPathInstance)
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
                            local TrackSource = SourceName
                            if Track.Name and Track.Name ~= "" and Track.Name ~= "Animation" then
                                TrackSource = TrackSource .. " (" .. Track.Name .. ")"
                            end
                            task.spawn(LogAdvancedAnimation, TrackSource, Track.Name, Anim.AnimationId, StrId, NumId or 0)
                        end
                    end
                end

                local StaticAnims = CollectAnimationsFromInstance(TargetPathInstance)
                for _, AnimData in ipairs(StaticAnims) do
                    local StrId = string.match(AnimData.AnimationId, "%d+")
                    if StrId and StrId ~= "" then
                        local NumId = tonumber(StrId)
                        if NumId and GetEnv.SkipRobloxOwnedAnimations then
                            local IsRobloxOwned = CheckRobloxOwned(NumId)
                            if IsRobloxOwned then
                                continue
                            end
                        end
                        task.spawn(LogAdvancedAnimation, SourceName, AnimData.Name, AnimData.AnimationId, StrId, NumId or 0)
                    end
                end
            else
                for _, Player in ipairs(Players:GetPlayers()) do
                    if InputText == "" or string.find(string.lower(Player.Name), InputText, 1, true) or string.find(string.lower(Player.DisplayName), InputText, 1, true) then
                        pcall(ScanPlayerAdvanced, Player)
                    end
                end
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
    SearchBox.PlaceholderText = "Player name or Path (blank = everyone)"
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
    local CreatedEntries: { { Button: TextButton, PlayerName: string, Id: string, AnimTitle: string } } = {}
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

        local FormattedName = (string.find(AnimName, "^Animation:") and AnimName) or ("Animation: " .. AnimName)

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
        NameLabel.Text = PlayerName .. " - " .. FormattedName
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
        local TargetPathInstance = ResolvePath(CurrentFilter)
        if Filter ~= "" then
            if TargetPathInstance then
                local InstName = string.lower(TargetPathInstance.Name)
                if not string.find(string.lower(PlayerName), InstName, 1, true) then
                    Button.Visible = false
                end
            else
                if not string.find(string.lower(PlayerName), Filter, 1, true)
                    and not string.find(string.lower(FormattedName), Filter, 1, true)
                    and not string.find(StrId, Filter, 1, true) then
                    Button.Visible = false
                end
            end
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
            Id = StrId,
            AnimTitle = FormattedName
        })
    end

    local function UpdateFilter()
        local Text = string.lower(SearchBox.Text:gsub("^%s*(.-)%s*$", "%1"))
        CurrentFilter = Text
        local TargetPathInstance = ResolvePath(Text)

        for _, Item in ipairs(CreatedEntries) do
            if Text == "" then
                Item.Button.Visible = true
            elseif TargetPathInstance then
                local InstName = string.lower(TargetPathInstance.Name)
                Item.Button.Visible = string.find(string.lower(Item.PlayerName), InstName, 1, true) ~= nil
            else
                Item.Button.Visible = (string.find(string.lower(Item.PlayerName), Text, 1, true) ~= nil)
                    or (string.find(string.lower(Item.AnimTitle), Text, 1, true) ~= nil)
                    or (string.find(Item.Id, Text, 1, true) ~= nil)
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
                            local AnimName = ResolveAnimationName(StrId, Track.Name, Track.Animation and Track.Animation.Name)
                            CreateButton(Player.Name, AnimName, StrId)
                        end)
                    end
                end
            end
        end
    end

    task.spawn(function()
        while true do
            local InputText = string.lower(CurrentFilter)
            local TargetPathInstance = ResolvePath(CurrentFilter)

            if TargetPathInstance then
                local SourceName = TargetPathInstance.Name
                if TargetPathInstance.Parent and TargetPathInstance.Parent ~= workspace and TargetPathInstance.Parent ~= game then
                    SourceName = TargetPathInstance.Parent.Name .. "." .. TargetPathInstance.Name
                end

                local Tracks = CollectTracksFromInstance(TargetPathInstance)
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

                            local Signature = SourceName .. "_" .. StrId
                            if not AnimationTable[Signature] then
                                AnimationTable[Signature] = true
                                task.spawn(function()
                                    local AnimName = ResolveAnimationName(StrId, Track.Name, Track.Animation and Track.Animation.Name)
                                    CreateButton(SourceName, AnimName, StrId)
                                end)
                            end
                        end
                    end
                end

                local StaticAnims = CollectAnimationsFromInstance(TargetPathInstance)
                for _, AnimData in ipairs(StaticAnims) do
                    local StrId = string.match(AnimData.AnimationId, "%d+")
                    if StrId and StrId ~= "" then
                        local NumId = tonumber(StrId)
                        if NumId and GetEnv.SkipRobloxOwnedAnimations then
                            local IsRobloxOwned = CheckRobloxOwned(NumId)
                            if IsRobloxOwned then
                                continue
                            end
                        end

                        local Signature = SourceName .. "_" .. StrId
                        if not AnimationTable[Signature] then
                            AnimationTable[Signature] = true
                            task.spawn(function()
                                local AnimName = ResolveAnimationName(StrId, AnimData.Name, nil)
                                CreateButton(SourceName, AnimName, StrId)
                            end)
                        end
                    end
                end
            else
                local PlayerList = Players:GetPlayers()
                for _, Player in ipairs(PlayerList) do
                    if InputText == "" or string.find(string.lower(Player.Name), InputText, 1, true) or string.find(string.lower(Player.DisplayName), InputText, 1, true) then
                        pcall(ScanPlayer, Player)
                    end
                end
            end
            task.wait(0.2)
        end
    end)
end
