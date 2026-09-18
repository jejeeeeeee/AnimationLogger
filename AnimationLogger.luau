local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local function getService(Name)
    local Success, Service = pcall(function()
        return game:GetService(Name)
    end)
    return Success and Service or nil
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
    if NameCache[Id] then return NameCache[Id] end
    local Name = Track and Track.Name
    if not Name or Name == "" or Name == "Animation" or Name == "Anim" then
        Name = Animation and Animation.Name
    end
    if (not Name or Name == "") and MarketplaceService then
        local Success, Info = pcall(function()
            return MarketplaceService:GetProductInfo(tonumber(Id), Enum.InfoType.Asset)
        end)
        if Success and Info then Name = Info.Name end
    end
    NameCache[Id] = (Name and Name ~= "" and Name) or "Unknown"
    return NameCache[Id]
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
    local Record = {
        Id = Id,
        Name = Name or resolveName(Id, Track, Animation),
        Source = "Workspace.Players." .. Player.Name .. ".Humanoid",
        Weight = tonumber(Track.WeightCurrent) or 0,
        Speed = tonumber(Track.Speed) or 0,
    }
    Records[tostring(Player.UserId) .. ":" .. Id] = Record
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
    Position = UDim2.new(0.1, 0, 0.2, 0),
    Size = Advanced and UDim2.new(0, 370, 0, 420) or UDim2.new(0, 260, 0, 360),
    Active = true,
})
make("UICorner", Main, { CornerRadius = UDim.new(0, 5) })

local TitleBar = make("Frame", Main, {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 28),
})
local Title = make("TextLabel", TitleBar, {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 1, 0),
    Font = Enum.Font.Code,
    TextSize = 13,
    TextColor3 = Color3.new(1, 1, 1),
    Text = "Animation Tracker (0 unique)",
    TextXAlignment = Enum.TextXAlignment.Center,
})

local Dragging, DragStart, StartPosition
TitleBar.InputBegan:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType.MouseButton1 then
        Dragging, DragStart, StartPosition = true, Input.Position, Main.Position
    end
end)
TitleBar.InputEnded:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType.MouseButton1 then Dragging = false end
end)
UserInputService.InputChanged:Connect(function(Input)
    if Dragging and Input.UserInputType == Enum.UserInputType.MouseMovement then
        local Delta = Input.Position - DragStart
        Main.Position = UDim2.new(StartPosition.X.Scale, StartPosition.X.Offset + Delta.X, StartPosition.Y.Scale, StartPosition.Y.Offset + Delta.Y)
    end
end)

local SearchBox
if not Advanced then
    SearchBox = make("TextBox", Main, {
        BackgroundColor3 = Color3.fromRGB(35, 39, 42),
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 28),
        Size = UDim2.new(1, 0, 0, 26),
        PlaceholderText = "Player name (blank = everyone)",
        PlaceholderColor3 = Color3.fromRGB(145, 150, 160),
        Text = "",
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Center,
        ClearTextOnFocus = false,
    })
end

local SaveButton = make("TextButton", Main, {
    BackgroundColor3 = Color3.fromRGB(60, 180, 110),
    BorderSizePixel = 0,
    Size = UDim2.new(0, Advanced and 180 or 0, 0, 22),
    Position = Advanced and UDim2.new(0.5, 0, 0, 30) or UDim2.new(0, 8, 0, 57),
    AnchorPoint = Advanced and Vector2.new(0.5, 0) or Vector2.new(0, 0),
    Text = "save anims to workspace",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 12,
    Font = Enum.Font.Gotham,
})
if not Advanced then SaveButton.Size = UDim2.new(1, -16, 0, 24) end
make("UICorner", SaveButton, { CornerRadius = UDim.new(0, 4) })
SaveButton.Activated:Connect(function()
    local Success, Message = saveAnimations()
    SaveButton.Text = Success and Message or "error: " .. Message
    SaveButton.BackgroundColor3 = Success and Color3.fromRGB(60, 180, 110) or Color3.fromRGB(190, 70, 70)
    task.delay(1.5, function()
        if SaveButton.Parent then
            SaveButton.Text = "save anims to workspace"
            SaveButton.BackgroundColor3 = Color3.fromRGB(60, 180, 110)
        end
    end)
end)

local List = make("ScrollingFrame", Main, {
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Position = Advanced and UDim2.new(0, 8, 0, 56) or UDim2.new(0, 0, 0, 86),
    Size = Advanced and UDim2.new(1, -12, 1, -62) or UDim2.new(1, 0, 1, -86),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness = 4,
})
make("UIListLayout", List, { Padding = UDim.new(0, Advanced and 8 or 1), SortOrder = Enum.SortOrder.LayoutOrder })

local UiEntries, Filter = {}, ""
local function addEntry(PlayerName, Name, Id, Source)
    local Key = (Advanced and Id or PlayerName .. ":" .. Id)
    if UiEntries[Key] then return end
    local Button = make("TextButton", List, {
        BackgroundColor3 = Advanced and Color3.fromRGB(30, 30, 30) or Color3.fromRGB(35, 39, 42),
        BorderSizePixel = 0,
        Size = UDim2.new(1, -6, 0, Advanced and 50 or 44),
        Text = PlayerName .. " - Animation: " .. Name .. "\n" .. Id .. "\n" .. Source,
        TextColor3 = Color3.fromRGB(235, 235, 235),
        TextSize = 11,
        Font = Enum.Font.Code,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
    })
    Button.Activated:Connect(function() pcall(SetClipboard, Id) end)
    UiEntries[Key] = { Button = Button, PlayerName = string.lower(PlayerName) }
    if Filter ~= "" and not string.find(UiEntries[Key].PlayerName, Filter, 1, true) then Button.Visible = false end
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
            addEntry(Player.Name, Name, Id, "Workspace.Players." .. Player.Name .. ".Humanoid")
        end
    end
end

task.spawn(function()
    while ScreenGui.Parent do
        for _, Player in ipairs(Players:GetPlayers()) do pcall(scan, Player) end
        local Count = 0
        for _ in pairs(RecordsById) do Count += 1 end
        Title.Text = string.format("Animation Tracker (%d unique)", Count)
        task.wait(0.25)
    end
end)
