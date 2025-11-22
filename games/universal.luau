local Library = shared.MoeLibrary

local Window = Library:Window("v1.0.0")

-- // Services
local Players = cloneref(game:GetService("Players"))
local TeleportService = cloneref(game:GetService("TeleportService"))
local HttpService = cloneref(game:GetService("HttpService"))
local CoreGui = game.CoreGui

-- // Variables
local LocalPlayer = Players.LocalPlayer
local CurrentCamera = cloneref(workspace.CurrentCamera)
local PlayerGui = LocalPlayer.PlayerGui
local AppLayout = CoreGui.ExperienceChat.appLayout

local queueonteleport = queueonteleport or queue_on_teleport or function() end

-- // Friends tbl
local FriendsTable = {}

task.spawn(function()
    -- Somewhere in https://raw.githubusercontent.com/SiriusSoftwareLtd/Sirius/request/source.lua
    local function UpdateFriends()
        local Success, Page = pcall(Players.GetFriendsAsync, Players, LocalPlayer.UserId)
        if Success then
            local TempFriends = {}
            repeat
                local Info = Page:GetCurrentPage()
                for _, FriendInfo in next, Info do
                    table.insert(TempFriends, FriendInfo.Id)
                end
                if not Page.IsFinished then
                    Page:AdvanceToNextPageAsync()
                end
            until Page.IsFinished
            FriendsTable = TempFriends
        end
    end
    
    UpdateFriends()

    while task.wait(15) do
        UpdateFriends()
    end
end)

-- // Tabs
local AimbotTab = Window:Tab("aimbot")
local VisualsTab = Window:Tab("visuals")
local PlayersTab = Window:Tab("players")
local MiscTab = Window:Tab("misc")

-- // Sections
local AimbotSection = AimbotTab:Section("aimbot")
local PlayersSection = PlayersTab:Section("players")
local SelfSection = PlayersTab:Section("self")

local ChatSection = MiscTab:Section("chat")
local ServerSection = MiscTab:Section("server")
local ScriptsSection = MiscTab:Section("scripts")

-- // Players tab
local PlayersTable = {}
local SelectedPlayer = nil
local IsSpectating = false

local function AddPlayerToTable(Player)
    if Player == LocalPlayer then return end
    if table.find(PlayersTable, Player.Name) then
        table.remove(PlayersTable, table.find(PlayersTable, Player.Name))
    else
        table.insert(PlayersTable, Player.Name)
    end
end

for _, Player in Players:GetPlayers() do
    AddPlayerToTable(Player)
end

Players.PlayerAdded:Connect(AddPlayerToTable)
Players.PlayerRemoving:Connect(AddPlayerToTable)

local PlayerDropdown = PlayersSection:Dropdown{
    Name = "players",
    Values = PlayersTable,
    Default = PlayersTable[1],
    Callback = function(Player)
        if Player ~= "" then
            SelectedPlayer = Players[Player]
        end
    end
}

PlayersSection:Button("goto", function()
    if LocalPlayer.Character and SelectedPlayer and SelectedPlayer.Character then
        LocalPlayer.Character.PrimaryPart.CFrame = SelectedPlayer.Character.PrimaryPart.CFrame
    end
end)

PlayersSection:Button("spectate", function()
    if not SelectedPlayer or not SelectedPlayer.Character then return end
    if IsSpectating then
        CurrentCamera.CameraSubject = LocalPlayer.Character.Humanoid or nil
        IsSpectating = false
    else
        CurrentCamera.CameraSubject = SelectedPlayer.Character.Humanoid
        IsSpectating = true
    end
end)

local CoreGuiConnection = nil
local PlayerGuiConnection = nil

local function FilterTextFromName(Object)
    if not Object:IsA("TextLabel") and not Object:IsA("TextButton") then return end
    if Object.Text:find(LocalPlayer.Name) or Object.Text:find(LocalPlayer.DisplayName) then
        Object.Text = Object.Text:gsub(LocalPlayer.Name, "local")
        Object.Text = Object.Text:gsub(LocalPlayer.DisplayName, "local")
    end
end

SelfSection:Toggle("hide name", function(value)
    if value then
        for _, Descendant in CoreGui:GetDescendants() do FilterTextFromName(Descendant) end
        for _, Descendant in PlayerGui:GetDescendants() do FilterTextFromName(Descendant) end
        CoreGuiConnection = CoreGui.DescendantAdded:Connect(FilterTextFromName)
        PlayerGuiConnection = PlayerGui.DescendantAdded:Connect(FilterTextFromName)
    elseif CoreGuiConnection and PlayerGuiConnection then
        CoreGuiConnection:Disconnect()
        PlayerGuiConnection:Disconnect()
        CoreGuiConnection = nil
        PlayerGuiConnection = nil
    end
end)

SelfSection:Slider{
    Name = "walkspeed",
    Default = LocalPlayer.Character.Humanoid.WalkSpeed,
    Max = 250,
    Callback = function(Value)
        LocalPlayer.Character.Humanoid.WalkSpeed = Value
    end
}

SelfSection:Slider{
    Name = "jump power",
    Default =  LocalPlayer.Character.Humanoid[LocalPlayer.Character.Humanoid.UseJumpPower and "JumpPower" or "JumpHeight"],
    Max = 250,
    Callback = function(Value)
        LocalPlayer.Character.Humanoid[LocalPlayer.Character.Humanoid.UseJumpPower and "JumpPower" or "JumpHeight"] = Value
    end
}

SelfSection:Button("reset", function()
    LocalPlayer.Character.Humanoid.Health = 0
end)

-- // Chat tags
local LocalCTs = false
local FriendCTs = false

local FriendRaw = "[Friend] "
local LocalRaw = "[You] "

local FriendVis = "<font color='#64F064'>" .. FriendRaw .. "</font>"
local FriendInvis = "<stroke transparency='1'><font transparency='1'>" .. FriendRaw .. "</font></stroke>"

local LocalVis = "<font color='#FFFFFF'>" .. LocalRaw .. "</font>"
local LocalInvis = "<stroke transparency='1'><font transparency='1'>" .. LocalRaw .. "</font></stroke>"

local function AddChatTagsToMsg(MsgFrame)
    if not LocalCTs or FriendCTs then return end

    local SenderUID = tonumber(MsgFrame.Name:match("^(%d+)"))
    if not SenderUID or SenderUID == 0 then return end

    local TextMessage = MsgFrame.TextMessage
    local PrefixText = TextMessage.PrefixText
    local BodyText = TextMessage.BodyText
    
    local TagToAddVis = nil
    local TagToAddInvis = nil
    
    if LocalCTs and SenderUID == LocalPlayer.UserId then
        TagToAddVis = LocalVis
        TagToAddInvis = LocalInvis
    elseif FriendCTs and table.find(FriendsTable, SenderUID) then
        TagToAddVis = FriendVis
        TagToAddInvis = FriendInvis
    end
    
    if TagToAddVis and (not PrefixText:find(">" .. LocalRaw:gsub("%s", "") .. "<") and not PrefixText:find(">" .. FriendRaw:gsub("%s", "") .. "<")) then
        PrefixText.Text = TagToAddVis .. PrefixText.Text
        BodyText.Text = TagToAddInvis .. BodyText.Text
    end
end

local function HookContentView(ContentView)
    for _, Child in next, ContentView:GetChildren() do
        AddChatTagsToMsg(Child)
    end

    ContentView.ChildAdded:Connect(AddChatTagsToMsg)
end

local function OnChatWindowAdded(ChatWindow)
    local ScrollingView = ChatWindow:WaitForChild("scrollingView")
    local ContentView = ScrollingView and ScrollingView.bottomLockedScrollView.RCTScrollView:FindFirstChild("RCTScrollContentView")

    if ContentView then
        HookContentView(ContentView)
    end
end

local AppLayout = CoreGui.ExperienceChat.appLayout

if AppLayout:FindFirstChild("chatWindow") then
    OnChatWindowAdded(AppLayout.chatWindow)
end

AppLayout.ChildAdded:Connect(function(Child)
    if Child.Name == "chatWindow" then
        OnChatWindowAdded(Child)
    end
end)

local CTDropdown = ChatSection:Dropdown{
    Name = "chat tags",
    Values = {"local", "friends"},
    Default = {},
    Callback = function(Values)
        LocalCTs = table.find(Values, "local") and true or false
        FriendCTs = table.find(Values, "friends") and true or false
    end
}

CTDropdown:Tooltip("only works with default chat")

ServerSection:Button("rejoin", function()
    if #Players:GetPlayers() <= 1 then
        queueonteleport(game:HttpGet("https://raw.githubusercontent.com/moehook/script/refs/heads/beta/games/universal.luau"))
        LocalPlayer:Kick("Rejoining...")
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    else
        queueonteleport(game:HttpGet("https://raw.githubusercontent.com/moehook/script/refs/heads/beta/games/universal.luau"))
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end
end)

ServerSection:Button("serverhop", function()
    local Servers = {}
    local Body = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true"))

    if Body and Body.data then
        for _, Server in next, Body.data do
            if type(Server) == "table" and tonumber(Server.playing) and tonumber(Server.maxPlayers) and Server.playing < Server.maxPlayers and Server.id ~= game.JobId then
                table.insert(Servers, 1, Server.id)
            end
        end
    end

    if #Servers > 0 then
        queueonteleport(game:HttpGet("https://raw.githubusercontent.com/moehook/script/refs/heads/beta/games/universal.luau"))
        TeleportService:TeleportToPlaceInstance(game.PlaceId, Servers[math.random(1, #Servers)], LocalPlayer)
    else
        Library:Notify("Couldn't serverhop; server not found.", "Error")
    end
end)

ScriptsSection:Button("infinite yield", function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/refs/heads/master/source"), "Infinite Yield")()
end)

ScriptsSection:Button("dex explorer", function()
    loadstring(game:HttpGet("https://github.com/LorekeeperZinnia/Dex/releases/latest/download/out.lua"), "Dex Explorer")()
end)

ScriptsSection:Button("remote spy", function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/78n/SimpleSpy/main/SimpleSpyBeta.lua"), "Simple Spy")()
end)

Library:ConfigManager(Window)
