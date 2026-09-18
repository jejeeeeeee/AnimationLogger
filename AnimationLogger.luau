local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
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
        if Info.Name and Info.Name ~= "" then
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
        if Success and Info and Info.Name and Info.Name ~= "" then
            NameCache[NumId] = Info.Name
            return Info.Name
        end
    end

    local Fallback = (TrackName and TrackName ~= "") and TrackName or "Unknown"
    if NumId then NameCache[NumId] = Fallback end
    return Fallback
end

local WriteFile: any = rawget(GetEnv, "writefile") or rawget(_G, "writefile")
local ReadFile: any = rawget(GetEnv, "readfile") or rawget(_G, "readfile")
local AnimationRecords: { [string]: {
    Id: string,
    Name: string,
    Weight: number,
    Speed: number,
} } = {}

local function UpdateAnimationRecord(Player: Player, Track: AnimationTrack, StrId: string, AnimName: string?)
    local Signature = tostring(Player.UserId) .. "_" .. StrId
    local Anim = Track.Animation
    local Existing = AnimationRecords[Signature]
    local ResolvedName = AnimName or ResolveAnimationName(StrId, Track.Name, Anim and Anim.Name)

    AnimationRecords[Signature] = {
        Id = StrId,
        Name = ResolvedName,
        Weight = tonumber(Track.WeightCurrent) or 0,
        Speed = tonumber(Track.Speed) or 0,
    }

    if Existing and Existing.Name ~= "" and (ResolvedName == "Unknown" or ResolvedName == "Animation") then
        AnimationRecords[Signature].Name = Existing.Name
    end
end

local function PrettyJson(Value: any, Indent: number?): string
    local CurrentIndent = Indent or 0
    local Prefix = string.rep("    ", CurrentIndent)
    local ChildPrefix = string.rep("    ", CurrentIndent + 1)
    local ValueType = type(Value)

    if ValueType == "string" then
        return HttpService:JSONEncode(Value)
    elseif ValueType == "number" or ValueType == "boolean" then
        return tostring(Value)
    elseif Value == nil then
        return "null"
    elseif ValueType ~= "table" then
        return HttpService:JSONEncode(tostring(Value))
    end

    local IsArray = true
    local ItemCount = 0
    for Key in pairs(Value) do
        ItemCount += 1
        if type(Key) ~= "number" or Key < 1 or Key % 1 ~= 0 then
            IsArray = false
        end
    end
    IsArray = IsArray and (ItemCount == #Value)

    local Parts = {}
    if IsArray then
        for _, Item in ipairs(Value) do
            table.insert(Parts, ChildPrefix .. PrettyJson(Item, CurrentIndent + 1))
        end
        if #Parts == 0 then
            return "[]"
        end
        return "[\n" .. table.concat(Parts, ",\n") .. "\n" .. Prefix .. "]"
    end

    local Keys = {}
    for Key in pairs(Value) do
        table.insert(Keys, tostring(Key))
    end
    table.sort(Keys)

    for _, Key in ipairs(Keys) do
        table.insert(Parts, ChildPrefix .. HttpService:JSONEncode(Key) .. ": " .. PrettyJson(Value[Key], CurrentIndent + 1))
    end
    if #Parts == 0 then
        return "{}"
    end
    return "{\n" .. table.concat(Parts, ",\n") .. "\n" .. Prefix .. "}"
end

local function ReadSavedAnimations(): { [string]: { Id: string, Name: string, Weight: number, Speed: number } }
    local SavedById = {}
    if type(ReadFile) ~= "function" then
        return SavedById
    end

    local ReadSuccess, Contents = pcall(function()
        return ReadFile("animations.json")
    end)
    if not ReadSuccess or type(Contents) ~= "string" or Contents == "" then
        return SavedById
    end

    local DecodeSuccess, Data = pcall(function()
        return HttpService:JSONDecode(Contents)
    end)
    if not DecodeSuccess or type(Data) ~= "table" then
        return SavedById
    end

    local Source = Data.Animations or Data
    if type(Source) ~= "table" then
        return SavedById
    end

    local function AddRecord(Key: any, Record: any)
        if type(Record) ~= "table" then
            return
        end

        local Id = tostring(Record.Id or Record.AnimationId or Key or "")
        if Id == "" then
            return
        end

        SavedById[Id] = {
            Id = Id,
            Name = tostring(Record.Name or "Unknown"),
            Weight = tonumber(Record.Weight or Record.AnimationWeight) or 0,
            Weight = tonumber(Record.Weight) or 0,
            Speed = tonumber(Record.Speed) or 0,
        }
    end

    for Key, Record in pairs(Source) do
        AddRecord(Key, Record)
    end

    return SavedById
end

local function SaveAnimationsToWorkspace(): (boolean, string)
    if type(WriteFile) ~= "function" then
        return false, "writefile unavailable"
    end

    local SavedById = ReadSavedAnimations()
    local AddedCount = 0
    for _, Record in pairs(AnimationRecords) do
        if not SavedById[Record.Id] then
            SavedById[Record.Id] = {
                Id = Record.Id,
                Name = Record.Name,
                Weight = Record.Weight,
                Speed = Record.Speed,
            }
            AddedCount += 1
        end
    end

    local Entries = {}
    for _, Record in pairs(SavedById) do
        table.insert(Entries, Record)
    end
    table.sort(Entries, function(A, B)
        return A.Id < B.Id
    end)

    local Payload = {
        Animations = Entries,
    }

    local Success = pcall(function()
        WriteFile("animations.json", PrettyJson(Payload))
    end)

    if not Success then
        return false, "save failed"
    end

    return true, string.format("saved %d animations", AddedCount)
end

local function CreateSaveButton(Parent: Instance, Position: UDim2, Size: UDim2): TextButton
    local Button = Instance.new("TextButton")
    Button.Name = "SaveAnimationsButton"
    Button.Position = Position
    Button.Size = Size
    Button.BackgroundColor3 = Color3.fromRGB(60, 180, 110)
    Button.BorderSizePixel = 0
    Button.Font = Enum.Font.Gotham
    Button.TextSize = 12
    Button.TextColor3 = Color3.fromRGB(255, 255, 255)
    Button.Text = "save anims to workspace"
    Button.AutoButtonColor = true
    Button.Parent = Parent

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 4)
    Corner.Parent = Button

    Button.Activated:Connect(function()
        local OriginalText = "save anims to workspace"
        local Success, Message = SaveAnimationsToWorkspace()
        Button.Text = Success and Message or ("error: " .. Message)
        Button.BackgroundColor3 = Success and Color3.fromRGB(60, 180, 110) or Color3.fromRGB(190, 70, 70)
        task.delay(1.5, function()
            if Button and Button.Parent then
                Button.Text = OriginalText
                Button.BackgroundColor3 = Color3.fromRGB(60, 180, 110)
            end
        end)
    end)

    return Button
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
    TitleBar.Size = UDim2.new(1, 0, 0, 28)
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

    local ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Name = "AnimationList"
    ScrollFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    ScrollFrame.BackgroundTransparency = 1
    ScrollFrame.BorderSizePixel = 0
    ScrollFrame.Position = UDim2.new(0, 8, 0, 56)
    ScrollFrame.Size = UDim2.new(1, -12, 1, -62)
    ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    ScrollFrame.ScrollBarThickness = 5
    ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(120, 120, 120)
    ScrollFrame.Parent = MainFrame

    CreateSaveButton(MainFrame, UDim2.new(0, 8, 0, 30), UDim2.new(0, 180, 0, 22))

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
            TitleLabel: TextLabel,
            StatsLabel: TextLabel,
            SourcesLabel: TextLabel,
        }
    } = {}

    local function LogAdvancedAnimation(Player: Player, Track: AnimationTrack, StrId: string, NumId: number)
        local RawId = (Track.Animation and Track.Animation.AnimationId ~= "" and Track.Animation.AnimationId) or ("rbxassetid://" .. StrId)
        local SourcePath = "Workspace.Players." .. Player.Name .. ".Humanoid"
        if Track.Name and Track.Name ~= "" and Track.Name ~= "Animation" then
            SourcePath = SourcePath .. " (" .. Track.Name .. ")"
        end

        local InitialResolved = ResolveAnimationName(StrId, Track.Name, Track.Animation and Track.Animation.Name)
        UpdateAnimationRecord(Player, Track, StrId, InitialResolved)

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

        local DisplayHeader = (string.find(InitialResolved, "^Animation:") and InitialResolved) or ("Animation: " .. InitialResolved)

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

        AdvancedEntries[StrId] = {
            Plays = 1,
            Last = os.date("%X"),
            Sources = { [SourcePath] = true },
            TitleLabel = Line1,
            StatsLabel = Line3,
            SourcesLabel = Line4,
        }

        task.spawn(function()
            local Fetched = ResolveAnimationName(StrId, Track.Name, Track.Animation and Track.Animation.Name)
            if Fetched and Fetched ~= "" and Line1 and Line1.Parent then
                Line1.Text = (string.find(Fetched, "^Animation:") and Fetched) or ("Animation: " .. Fetched)
            end
        end)
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
    ScrollFrame.Position = UDim2.new(0, 0, 0, 86)
    ScrollFrame.Size = UDim2.new(1, 0, 1, -86)
    ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    ScrollFrame.ScrollBarThickness = 4
    ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(32, 34, 37)
    ScrollFrame.Parent = MainFrame

    CreateSaveButton(MainFrame, UDim2.new(0, 8, 0, 57), UDim2.new(1, -16, 0, 24))

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

                    UpdateAnimationRecord(Player, Track, StrId)

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
