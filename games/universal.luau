local Library = shared.MoeLibrary
local Window = Library:Window("v1.0.0")

-- // Services
local Players = cloneref(game:GetService("Players"))
local TeleportService = cloneref(game:GetService("TeleportService"))
local Lighting = cloneref(game:GetService("Lighting"))
local RunService = cloneref(game:GetService("RunService"))
local HttpService = cloneref(game:GetService("HttpService"))
local CoreGui = game.CoreGui

-- // Variables
local LocalPlayer = Players.LocalPlayer
local CurrentCamera = cloneref(workspace.CurrentCamera)
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local PreRender = RunService.PreRender
local AppLayout = CoreGui.ExperienceChat.appLayout

local queueonteleport = queueonteleport or queue_on_teleport or function() end

-- // Helper funcs
local function GetUID(String)
    local UIDFromString = tonumber(String)

    if UIDFromString then
        return UIDFromString
    end

    local Success, UIDFromName = pcall(Players.GetUserIdFromNameAsync, Players, String)

    if Success and UIDFromName then
        return UIDFromName
    end

    return nil
end

-- // Friends tbl
local FriendsTable = {}

task.spawn(function()
    local function UpdateFriends()
        if not LocalPlayer.UserId then return end
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
    while task.wait(15) do UpdateFriends() end
end)

-- // Tabs
local AimbotTab = Window:Tab("aimbot")
local VisualsTab = Window:Tab("visuals")
local PlayersTab = Window:Tab("players")
local MiscTab = Window:Tab("misc")

-- // Sections
local AimbotSection = AimbotTab:Section("aimbot")
local TriggerbotSection = AimbotTab:Section("triggerbot")

local ESPSection = VisualsTab:Section("esp")
local SelfSection = VisualsTab:Section("self")
local WorldSection = VisualsTab:Section("world")
local OtherSection = VisualsTab:Section("other")

local PlayersSection = PlayersTab:Section("players")
local PlayerSelfSection = PlayersTab:Section("self")

local ChatSection = MiscTab:Section("chat")
local ServerSection = MiscTab:Section("server")
local ScriptsSection = MiscTab:Section("scripts")

-- // Visuals tab
local FullbrightEnabled
local ClockTime = Lighting.ClockTime
local FogEnd = Lighting.FogEnd
local FullbrightBefore = {
	Brightness = Lighting.Brightness,
	GlobalShadows = Lighting.GlobalShadows,
	OutdoorAmbient = Lighting.OutdoorAmbient
}

WorldSection:Toggle("fullbright", function(Value)
	FullbrightEnabled = Value

	Lighting.Brightness = FullbrightEnabled and 2 or FullbrightBefore.Brightness
	Lighting.ClockTime = FullbrightEnabled and 14 or ClockTime
	Lighting.FogEnd = FullbrightEnabled and 100000 or FogEnd
	Lighting.GlobalShadows = not FullbrightEnabled
	Lighting.OutdoorAmbient = FullbrightEnabled and Color3.fromRGB(128, 128, 128) or FullbrightBefore.OutdoorAmbient
end, false)

WorldSection:Slider{
	Name = "clock time",
	Default = Lighting.ClockTime,
	Min = 0,
	Max = 23,
	Callback = function(Value)
		ClockTime = Value
		if not FullbrightEnabled then
			Lighting.ClockTime = Value
		end
	end
}

local Sky = Lighting:FindFirstChildWhichIsA("Sky") or Instance.new("Sky", game.Lighting)

WorldSection:Toggle("show sun/moon", function(Value)
	Sky.CelestialBodiesShown = Value
end, Sky.CelestialBodiesShown)
local CustomSkies = {
	["default"] = {
		Bk = Sky.SkyboxBk,
		Dn = Sky.SkyboxDn,
		Ft = Sky.SkyboxFt,
		Lf = Sky.SkyboxLf,
		Rt = Sky.SkyboxRt,
		Up = Sky.SkyboxUp
	},

	["nebula"] = {
		Bk = "rbxassetid://16553658937",
		Dn = "rbxassetid://16553660713",
		Ft = "rbxassetid://16553662144",
		Lf = "rbxassetid://16553664042",
		Rt = "rbxassetid://16553665766",
		Up = "rbxassetid://16553667750"
	},

	["space"] = {
		Bk = "rbxassetid://15593304635",
		Dn = "rbxassetid://15593307656",
		Ft = "rbxassetid://15593319759",
		Lf = "rbxassetid://15593316960",
		Rt = "rbxassetid://15593329329",
		Up = "rbxassetid://15593324381"
	},

	["purple clouds"] = {
		Bk = "rbxassetid://17279854976",
		Dn = "rbxassetid://17279856318",
		Ft = "rbxassetid://17279858447",
		Lf = "rbxassetid://17279860360",
		Rt = "rbxassetid://17279862234",
		Up = "rbxassetid://17279864507"
	},

	["night"] = {
		Bk = "rbxassetid://155624722",
		Dn = "rbxassetid://155624727",
		Ft = "rbxassetid://155624730",
		Lf = "rbxassetid://155624736",
		Rt = "rbxassetid://155624742",
		Up = "rbxassetid://155624749"
	},
}

WorldSection:Dropdown{
	Name = "skybox",
	Values = {"default", "nebula", "space", "purple clouds", "night"},
	Default = "default",
	Callback = function(Value)
		for Side, Value in CustomSkies[Value] do
			Sky["Skybox"..Side] = Value
		end
	end
}

WorldSection:Dropdown{
	Name = "lighting technology",
	Values = {"compatibility", "future", "shadowmap", "unified", "voxel"},
	Default = Lighting.Technology.Name:lower(),
	Callback = function(Value)
		if Value ~= "shadowmap" then
			Lighting.Technology = Value:sub(1, 1):upper()..Value:sub(2)
		else
			Lighting.Technology = "ShadowMap"
		end
	end
}

-- // Fog
WorldSection:Colorpicker{
	Name = "fog color",
	Default = Lighting.FogColor,
	Callback = function(Color)
		local Atmosphere = Lighting:FindFirstChildWhichIsA("Atmosphere")
		if Atmosphere then Atmosphere:Destroy() end

		Lighting.FogColor = Color
	end
}

WorldSection:Slider{
	Name = "fog start",
	Default = Lighting.FogStart,
	Min = 0,
	Max = 1000,
	Callback = function(Value)
		Lighting.FogStart = Value
	end
}

WorldSection:Slider{
	Name = "fog end",
	Default = FullbrightBefore.FogEnd,
	Min = 0,
	Max = 1000,
	Callback = function(Value)
		FogEnd = Value
		Lighting.FogEnd = Value
	end
}
OtherSection:Slider{
	Name = "field of view",
	Min = CurrentCamera.FieldOfView,
	Max = 120,
	Callback = function(Value)
		CurrentCamera.FieldOfView = Value
	end
}

local AspectRatio = 1
local AspectRatioCon = nil

OtherSection:Slider{
    Name = "aspect ratio",
    Default = 1,
    Min = .5,
    Max = 1,
    Increment = .01,
    Callback = function(Value)
        AspectRatio = Value

        if Value == 1 and AspectRatioCon then
            AspectRatioCon:Disconnect()
            AspectRatioCon = nil
        elseif not AspectRatioCon then
            AspectRatioCon = PreRender:Connect(function()
                if AspectRatio ~= 1 then
                    CurrentCamera.CFrame *= CFrame.new(0, 0, 0, 1, 0, 0, 0, AspectRatio, 0, 0, 0, 1)
                end
            end)
        end
    end
}

-- // Players tab
local PlayersTable = {}
local SelectedPlayer = nil
local IsSpectating = false
local PlayerDropdown = nil

local function AddPlayerToTable(Player)
    if Player == LocalPlayer then return end
    
    local index = table.find(PlayersTable, Player.Name)
    if index then
        table.remove(PlayersTable, index)
    else
        table.insert(PlayersTable, Player.Name)
    end

    if PlayerDropdown then
        PlayerDropdown:SetValues(PlayersTable)
    end
end

for _, Player in Players:GetPlayers() do
    if Player ~= LocalPlayer then
        table.insert(PlayersTable, Player.Name)
    end
end

Players.PlayerAdded:Connect(AddPlayerToTable)
Players.PlayerRemoving:Connect(AddPlayerToTable)

PlayerDropdown = PlayersSection:Dropdown{
    Name = "players",
    Values = PlayersTable,
    Default = PlayersTable[1] or "none",
    Callback = function(Player)
        if Player ~= "" and Player ~= "none" then
            SelectedPlayer = Players:FindFirstChild(Player)
        end
    end
}

PlayersSection:Button("goto", function()
    if LocalPlayer.Character and SelectedPlayer and SelectedPlayer.Character then
        local Root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local TargetRoot = SelectedPlayer.Character:FindFirstChild("HumanoidRootPart")
        if Root and TargetRoot then
            Root.CFrame = TargetRoot.CFrame
        end
    end
end)

PlayersSection:Button("spectate", function()
    if not SelectedPlayer or not SelectedPlayer.Character then return end
    local Hum = SelectedPlayer.Character:FindFirstChildOfClass("Humanoid")
    
    if IsSpectating then
        CurrentCamera.CameraSubject = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") or nil
        IsSpectating = false
    else
        if Hum then
            CurrentCamera.CameraSubject = Hum
            IsSpectating = true
        end
    end
end)

local CoreGuiConnection
local PlayerGuiConnection
local HideNameEnabled

local function FilterText(Object)
	if HideNameEnabled then
		Object.Text = Object.Text:gsub(LocalPlayer.Name, "local"):gsub(LocalPlayer.DisplayName, "local")
	end
end

local function FilterTextFromName(Object)
    if not Object:IsA("TextLabel") and not Object:IsA("TextButton") then return end
    
	FilterText(Object)

	Object:GetPropertyChangedSignal("Text"):Connect(function()
		FilterText(Object)
	end)
end

PlayerSelfSection:Toggle("hide name", function(Value)
	HideNameEnabled = Value

    if HideNameEnabled then
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

PlayerSelfSection:Slider{
    Name = "walkspeed",
    Default = 16,
    Max = 250,
    Callback = function(Value)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = Value
        end
    end
}

PlayerSelfSection:Slider{
    Name = "jump power",
    Default = LocalPlayer.Character.Humanoid[LocalPlayer.Character.Humanoid.UseJumpPower and "JumpPower" or "JumpHeight"],
    Max = 250,
    Callback = function(Value)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            local Hum = LocalPlayer.Character.Humanoid
            Hum[Hum.UseJumpPower and "JumpPower" or "JumpHeight"] = Value
        end
    end
}

PlayerSelfSection:Button("reset", function()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.Health = 0
    end
end)

local MorphConnection = nil
local CurrentMorphUID = LocalPlayer.UserId

local function Morph()
	local Character = LocalPlayer.Character
    if not Character then return end

    local Appearance = Players:GetCharacterAppearanceAsync(CurrentMorphUID)
	if not Appearance then return end

    local ToRemove = {
        Accessory = true,
        Shirt = true,
        Pants = true,
        CharacterMesh = true,
        BodyColors = true,
    }

    for _, Item in next, Character:GetChildren() do
        if ToRemove[Item.ClassName] then
            Item:Destroy()
        end
    end

    local Face = Character.Head:FindFirstChild("face")
    if Face then Face:Destroy() end

    for _, Item in next, Appearance:GetChildren() do
        if Item:IsA("Shirt") or Item:IsA("Pants") or Item:IsA("BodyColors") then
            Item.Parent = Character
        elseif Item:IsA("Accessory") then
            Character.Humanoid:AddAccessory(Item)
        elseif Item.Name == Character.Humanoid.RigType.Name then
            local Mesh = Item:FindFirstChildWhichIsA("CharacterMesh")
            if Mesh then Mesh.Parent = Character end
        end
    end

	Face = Appearance:FindFirstChild("face")

	if Face then
		Face.Parent = Character.Head
	else
		local DefaultFace = Instance.new("Decal", Character.Head)
		DefaultFace.Name = "face"
		DefaultFace.Face = "Front"
		DefaultFace.Texture = "rbxasset://textures/face.png"
	end

	local PrevCharParent = Character.Parent
	LocalPlayer.Character.Parent = nil
	LocalPlayer.Character.Parent = PrevCharParent
end

PlayerSelfSection:Input{
    Name = "morph to user (clientside)",
    Callback = function(String)
        if String == "" then
            CurrentMorphUID = LocalPlayer.UserId
            Morph()

			if MorphConnection then
				MorphConnection:Disconnect()
				MorphConnection = nil
			end

            return
        end

        local UID = GetUID(String)

        if not UID then
            Library:Notify("No such player found!", "Error")
            return
        end

        CurrentMorphUID = UID
        Morph()

        if not MorphConnection then
            MorphConnection = LocalPlayer.CharacterAdded:Connect(Morph)
        end
    end
}:Tooltip("leave blank if none")

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
    if not (LocalCTs or FriendCTs) then return end

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
    
    if TagToAddVis and (not PrefixText.Text:find(">" .. LocalRaw:gsub("%s", "") .. "<") and not PrefixText.Text:find(">" .. FriendRaw:gsub("%s", "") .. "<")) then
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
    local ContentView = ScrollingView and ScrollingView.bottomLockedScrollView.RCTScrollView.RCTScrollContentView
    if ContentView then
        HookContentView(ContentView)
    end
end

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
		LocalCTs = false
		FriendCTs = false
		for _, Value in Values do
			if Value == "local" then LocalCTs = true end
			if Value == "friends" then FriendCTs = true end
		end
    end
}

CTDropdown:Tooltip("only works with new TextChatService")

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
    local req = game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true")
    local Body = HttpService:JSONDecode(req)

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
