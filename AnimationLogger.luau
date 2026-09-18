local function getService(Name)
    local Success, Service = pcall(function()
        return game:GetService(Name)
    end)
    return Success and Service or nil
end

local Players = getService("Players")
local UserInputService = getService("UserInputService")
local LocalPlayer = Players and Players.LocalPlayer
if not Players or not UserInputService then
    warn("Animation logger: Roblox services are unavailable")
    return
end

local CoreGui = getService("CoreGui")
local MarketplaceService = getService("MarketplaceService")
local HttpService = getService("HttpService")

local Env = _G
if type(getgenv) == "function" then
    local Success, Value = pcall(getgenv)
    if Success and type(Value) == "table" then Env = Value end
elseif type(getfenv) == "function" then
    local Success, Value = pcall(getfenv)
    if Success and type(Value) == "table" then Env = Value end
end

if Env.SkipRobloxOwnedAnimations == nil then Env.SkipRobloxOwnedAnimations = false end
if Env.InitAdvancedAnimationLogger == nil then Env.InitAdvancedAnimationLogger = false end

local function findFunction(Name)
    local Value = rawget(Env, Name) or rawget(_G, Name)
    return type(Value) == "function" and Value or nil
end

local WriteFile = findFunction("writefile")
local ReadFile = findFunction("readfile")
local SetClipboard = findFunction("setclipboard") or findFunction("toclipboard")
if not SetClipboard then SetClipboard = function() end end

local function sanitize(Name)
    Name = tostring(Name):gsub("[<>:\"/\\|?*]", "_"):gsub("%c", "_"):gsub("%s+$", "")
    return Name ~= "" and Name or tostring(game.GameId)
end

local FileName = "Animations_" .. sanitize(game.Name) .. ".json"
task.spawn(function()
    if MarketplaceService and game.GameId ~= 0 then
        local Success, Info = pcall(function()
            return MarketplaceService:GetProductInfo(game.GameId, Enum.InfoType.Game)
        end)
        if Success and Info and Info.Name and Info.Name ~= "" then
            FileName = "Animations_" .. sanitize(Info.Name) .. ".json"
        elseif game.GameId ~= 0 then
            FileName = "Animations_Game_" .. game.GameId .. ".json"
        end
    end
end)

local PlayerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
local ParentGui
pcall(function()
    local GetHui = rawget(Env, "gethui")
    if type(GetHui) == "function" then ParentGui = GetHui() end
end)
ParentGui = ParentGui or PlayerGui or CoreGui

if ParentGui then
    pcall(function()
        local Old = ParentGui:FindFirstChild("AnimTrackerUI")
        if Old then Old:Destroy() end
    end)
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AnimTrackerUI"
ScreenGui.DisplayOrder = 500
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local ParentSuccess = pcall(function() ScreenGui.Parent = ParentGui end)
if (not ParentSuccess or not ScreenGui.Parent) and PlayerGui then
    pcall(function() ScreenGui.Parent = PlayerGui end)
end
if not ScreenGui.Parent then
    warn("Animation logger: unable to create UI")
    return
end

local NameCache = {}
local function resolveName(Id, Track, Animation)
    local TrackName = Track and Track.Name
    local AnimationName = Animation and Animation.Name
    if NameCache[Id] and NameCache[Id] ~= "" and NameCache[Id] ~= "Animation" then
        return NameCache[Id]
    end
    if TrackName and TrackName ~= "" and TrackName ~= "Animation" and TrackName ~= "AnimationTrack" and TrackName ~= "Anim" then
        NameCache[Id] = TrackName
        return TrackName
    end
    if AnimationName and AnimationName ~= "" and AnimationName ~= "Animation" and AnimationName ~= "AnimationTrack" and AnimationName ~= "Anim" then
        NameCache[Id] = AnimationName
        return AnimationName
    end
    if MarketplaceService then
        local Success, Info = pcall(function()
            return MarketplaceService:GetProductInfo(tonumber(Id), Enum.InfoType.Asset)
        end)
        if Success and Info and Info.Name and Info.Name ~= "" then
            NameCache[Id] = Info.Name
            return Info.Name
        end
    end
    local Fallback = (TrackName and TrackName ~= "") and TrackName or AnimationName or "Unknown"
    NameCache[Id] = Fallback
    return Fallback
end

local function isRobloxOwned(Id)
    if not MarketplaceService then return false end
    local Success, Info = pcall(function()
        return MarketplaceService:GetProductInfo(tonumber(Id), Enum.InfoType.Asset)
    end)
    if not Success or not Info or not Info.Creator then return false end
    return string.lower(tostring(Info.Creator.Name or "")) == "roblox" or Info.Creator.Id == 1
end

local Records = {}
local RecordsById = {}
local function updateRecord(Player, Track, Id, Name)
    local Animation = Track.Animation
    local Key = tostring(Player.UserId) .. ":" .. Id
    local Existing = Records[Key]
    local ResolvedName = Name or resolveName(Id, Track, Animation)
    if Existing and (ResolvedName == "Unknown" or ResolvedName == "Animation") then
        ResolvedName = Existing.Name
    end
    local Record = {
        Id = Id,
        Name = ResolvedName,
        Source = "Workspace.Players." .. Player.Name .. ".Humanoid",
        Weight = tonumber(Track.WeightCurrent) or 0,
        Speed = tonumber(Track.Speed) or 0,
    }
    Records[Key] = Record
    RecordsById[Id] = Record
end

local function readSaved()
    local Saved = {}
    if not ReadFile or not HttpService then return Saved end
    local ReadSuccess, Text = pcall(function() return ReadFile(FileName) end)
    if not ReadSuccess or type(Text) ~= "string" or Text == "" then return Saved end
    local DecodeSuccess, Data = pcall(function() return HttpService:JSONDecode(Text) end)
    if not DecodeSuccess or type(Data) ~= "table" then return Saved end
    local List = Data.Animations or Data
    for Key, Value in pairs(List) do
        if type(Value) == "table" then
            local Id = tostring(Value.Id or Value.AnimationId or Key or "")
            if Id ~= "" then
                Saved[Id] = {
                    Id = Id,
                    Name = tostring(Value.Name or "Unknown"),
                    Source = tostring(Value.Source or "Unknown"),
                    Weight = tonumber(Value.Weight) or 0,
                    Speed = tonumber(Value.Speed) or 0,
                }
            end
        end
    end
    return Saved
end

local function jsonString(Value)
    return HttpService:JSONEncode(tostring(Value))
end

local function formatJson(Entries)
    local Lines = { "{", '    "Animations": [' }
    for Index, Record in ipairs(Entries) do
        table.insert(Lines, "        {")
        table.insert(Lines, '            "Id": ' .. jsonString(Record.Id) .. ',')
        table.insert(Lines, '            "Name": ' .. jsonString(Record.Name) .. ',')
        table.insert(Lines, '            "Source": ' .. jsonString(Record.Source) .. ',')
        table.insert(Lines, '            "Weight": ' .. tostring(Record.Weight) .. ',')
        table.insert(Lines, '            "Speed": ' .. tostring(Record.Speed))
        table.insert(Lines, "        }" .. (Index == #Entries and "" or ","))
    end
    if #Entries == 0 then
        return "{\r\n    \"Animations\": []\r\n}"
    end
    table.insert(Lines, "    ]")
    table.insert(Lines, "}")
    return table.concat(Lines, "\r\n")
end

local function saveAnimations()
    if not WriteFile then return false, "writefile unavailable" end
    if not HttpService then return false, "HttpService unavailable" end
    local Saved, Added = readSaved(), 0
    for Id, Record in pairs(RecordsById) do
        if not Saved[Id] then
            Saved[Id] = Record
            Added += 1
        elseif (Saved[Id].Name == "Animation" or Saved[Id].Name == "Unknown") and Record.Name ~= "Unknown" then
            Saved[Id].Name = Record.Name
        end
    end
    local Entries = {}
    for _, Record in pairs(Saved) do table.insert(Entries, Record) end
    table.sort(Entries, function(A, B) return A.Id < B.Id end)
    local Success, Error = pcall(function()
        WriteFile(FileName, formatJson(Entries))
    end)
    if not Success then return false, tostring(Error) end
    return true, string.format("saved %d animations", Added)
end

local function make(className, Parent, Properties)
    local Object = Instance.new(className)
    for Key, Value in pairs(Properties or {}) do Object[Key] = Value end
    Object.Parent = Parent
    return Object
end

local Advanced = Env.InitAdvancedAnimationLogger == true
local Main = make("Frame", ScreenGui, {
    Name = "MainFrame",
    BackgroundColor3 = Advanced and Color3.fromRGB(30, 30, 30) or Color3.fromRGB(44, 47, 51),
    BorderSizePixel = 0,
    Position = Advanced and UDim2.new(0.08, 0, 0.15, 0) or UDim2.new(0.1, 0, 0.2, 0),
    Size = Advanced and UDim2.new(0, 370, 0, 420) or UDim2.new(0, 260, 0, 360),
    Active = true,
})
make("UICorner", Main, { CornerRadius = UDim.new(0, Advanced and 4 or 6) })

local function makeDraggable(Frame, Handle)
    local Dragging, DragStart, StartPosition, DragInput = false, nil, nil, nil
    Handle.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
            Dragging, DragStart, StartPosition = true, Input.Position, Frame.Position
            Input.Changed:Connect(function()
                if Input.UserInputState == Enum.UserInputState.End then Dragging = false end
            end)
        end
    end)
    Handle.InputChanged:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then DragInput = Input end
    end)
    UserInputService.InputChanged:Connect(function(Input)
        if Dragging and Input == DragInput then
            local Delta = Input.Position - DragStart
            Frame.Position = UDim2.new(StartPosition.X.Scale, StartPosition.X.Offset + Delta.X, StartPosition.Y.Scale, StartPosition.Y.Offset + Delta.Y)
        end
    end)
end

local Title, SearchBox, List
if Advanced then
    local TitleBar = make("Frame", Main, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28) })
    Title = make("TextLabel", TitleBar, {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Font = Enum.Font.Code,
        TextSize = 13, TextColor3 = Color3.new(1, 1, 1), Text = "Animation Tracker (0 unique)",
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    makeDraggable(Main, TitleBar)
    List = make("ScrollingFrame", Main, {
        BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.new(0, 8, 0, 56),
        Size = UDim2.new(1, -12, 1, -62), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0), ScrollBarThickness = 5,
    })
else
    local DragBar = make("Frame", Main, {
        BackgroundColor3 = Color3.fromRGB(114, 137, 218), BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 22),
    })
    make("UICorner", DragBar, { CornerRadius = UDim.new(0, 6) })
    make("Frame", DragBar, {
        BackgroundColor3 = Color3.fromRGB(114, 137, 218), BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, -6), Size = UDim2.new(1, 0, 0, 6),
    })
    makeDraggable(Main, DragBar)
    local SearchContainer = make("Frame", Main, {
        BackgroundColor3 = Color3.fromRGB(35, 39, 42), BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 0, 32),
    })
    SearchBox = make("TextBox", SearchContainer, {
        BackgroundTransparency = 1, Size = UDim2.new(1, -16, 1, 0), Position = UDim2.new(0, 8, 0, 0),
        PlaceholderText = "Player name (blank = everyone)", PlaceholderColor3 = Color3.fromRGB(145, 150, 160),
        Text = "", TextColor3 = Color3.fromRGB(245, 245, 245), TextSize = 13, Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Center, ClearTextOnFocus = false,
    })
    make("Frame", SearchContainer, {
        BackgroundColor3 = Color3.fromRGB(32, 34, 37), BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1),
    })
    List = make("ScrollingFrame", Main, {
        BackgroundColor3 = Color3.fromRGB(44, 47, 51), BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 86), Size = UDim2.new(1, 0, 1, -86),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0), ScrollBarThickness = 4,
    })
end

local SaveButton = make("TextButton", Main, {
    BackgroundColor3 = Color3.fromRGB(60, 180, 110), BorderSizePixel = 0,
    Position = Advanced and UDim2.new(0.5, 0, 0, 30) or UDim2.new(0, 8, 0, 57),
    Size = Advanced and UDim2.new(0, 180, 0, 22) or UDim2.new(1, -16, 0, 24),
    AnchorPoint = Advanced and Vector2.new(0.5, 0) or Vector2.new(0, 0),
    Text = "save anims to workspace", TextColor3 = Color3.new(1, 1, 1), TextSize = 12, Font = Enum.Font.Gotham,
})
make("UICorner", SaveButton, { CornerRadius = UDim.new(0, 4) })
SaveButton.Activated:Connect(function()
    local Success, Message = saveAnimations()
    SaveButton.Text = Success and Message or "error: " .. Message
    SaveButton.BackgroundColor3 = Success and Color3.fromRGB(60, 180, 110) or Color3.fromRGB(190, 70, 70)
    task.delay(1.5, function()
        if SaveButton.Parent then SaveButton.Text, SaveButton.BackgroundColor3 = "save anims to workspace", Color3.fromRGB(60, 180, 110) end
    end)
end)

make("UIListLayout", List, { Padding = UDim.new(0, Advanced and 10 or 1), SortOrder = Enum.SortOrder.LayoutOrder })
local UiEntries, Filter, AdvancedCount = {}, "", 0

local function sourceList(Entry)
    local Sources = {}
    for Source in pairs(Entry.Sources) do table.insert(Sources, Source) end
    table.sort(Sources)
    return table.concat(Sources, ", ")
end

local function addEntry(PlayerName, Name, Id, Source)
    local Key = Advanced and Id or PlayerName .. ":" .. Id
    local Existing = UiEntries[Key]
    if Existing then
        if Advanced then
            Existing.Plays += 1
            Existing.Sources[Source] = true
            Existing.Stats.Text = string.format("plays: %d | last: %s", Existing.Plays, os.date("%X"))
            Existing.SourcesLabel.Text = "sources: " .. sourceList(Existing)
        end
        return
    end

    if Advanced then
        AdvancedCount += 1
        local Container = make("TextButton", List, {
            BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, -6, 0, 64), Text = "", AutoButtonColor = false,
        })
        local Header = make("TextLabel", Container, {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 15), Font = Enum.Font.Code, TextSize = 12,
            TextColor3 = Color3.fromRGB(225, 225, 225), TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, Text = "Animation: " .. Name,
        })
        local IdLabel = make("TextLabel", Container, {
            BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 15), Size = UDim2.new(1, 0, 0, 15),
            Font = Enum.Font.Code, TextSize = 12, TextColor3 = Color3.fromRGB(225, 225, 225), TextXAlignment = Enum.TextXAlignment.Left,
            Text = "rbxassetid://" .. Id,
        })
        local Stats = make("TextLabel", Container, {
            BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(1, 0, 0, 15),
            Font = Enum.Font.Code, TextSize = 12, TextColor3 = Color3.fromRGB(225, 225, 225), TextXAlignment = Enum.TextXAlignment.Left,
            Text = "plays: 1 | last: " .. os.date("%X"),
        })
        local SourcesLabel = make("TextLabel", Container, {
            BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 45), Size = UDim2.new(1, 0, 0, 15),
            Font = Enum.Font.Code, TextSize = 12, TextColor3 = Color3.fromRGB(225, 225, 225), TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, Text = "sources: " .. Source,
        })
        local Entry = { Button = Container, PlayerName = string.lower(PlayerName), Plays = 1, Sources = { [Source] = true }, Stats = Stats, SourcesLabel = SourcesLabel }
        UiEntries[Key] = Entry
        Container.Activated:Connect(function() pcall(SetClipboard, Id) end)
    else
        local Button = make("TextButton", List, {
            BackgroundColor3 = Color3.fromRGB(35, 39, 42), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 48),
            Text = "", AutoButtonColor = true,
        })
        make("TextLabel", Button, {
            BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 4), Size = UDim2.new(1, -16, 0, 20),
            Font = Enum.Font.Gotham, TextSize = 14, TextColor3 = Color3.fromRGB(245, 245, 245), TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, Text = PlayerName .. " - Animation: " .. Name,
        })
        make("TextLabel", Button, {
            BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 24), Size = UDim2.new(1, -16, 0, 18),
            Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = Color3.fromRGB(180, 185, 195), TextXAlignment = Enum.TextXAlignment.Left,
            Text = Id,
        })
        UiEntries[Key] = { Button = Button, PlayerName = string.lower(PlayerName) }
        Button.Activated:Connect(function() pcall(SetClipboard, Id) end)
    end
end

local function updateFilter()
    Filter = SearchBox and string.lower(SearchBox.Text:gsub("^%s*(.-)%s*$", "%1")) or ""
    for _, Entry in pairs(UiEntries) do
        Entry.Button.Visible = Filter == "" or string.find(Entry.PlayerName, Filter, 1, true) ~= nil
    end
end
if SearchBox then SearchBox:GetPropertyChangedSignal("Text"):Connect(updateFilter) end

local function scan(Player)
    if not Player.Character then return end
    local Humanoid = Player.Character:FindFirstChildOfClass("Humanoid")
    if not Humanoid then return end
    for _, Track in ipairs(Humanoid:GetPlayingAnimationTracks()) do
        local Animation = Track.Animation
        local Id = Animation and string.match(Animation.AnimationId or "", "%d+")
        if Id and (not Env.SkipRobloxOwnedAnimations or not isRobloxOwned(Id)) then
            local Name = resolveName(Id, Track, Animation)
            updateRecord(Player, Track, Id, Name)
            local Source = "Workspace.Players." .. Player.Name .. ".Humanoid"
            if Track.Name and Track.Name ~= "" and Track.Name ~= "Animation" then Source = Source .. " (" .. Track.Name .. ")" end
            addEntry(Player.Name, Name, Id, Source)
        end
    end
end

task.spawn(function()
    while ScreenGui.Parent do
        for _, Player in ipairs(Players:GetPlayers()) do pcall(scan, Player) end
        if Title then Title.Text = string.format("Animation Tracker (%d unique)", AdvancedCount) end
        task.wait(0.25)
    end
end)
