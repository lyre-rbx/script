local SharedTable = (getgenv and getgenv()) or getfenv(0)

if SharedTable.LyreUI then
    SharedTable.LyreUI:Unload()
end

-- // Locals
local EmptyFunction = function(...) return ... end

local cloneref = cloneref or clonereference or EmptyFunction

local isfile = isfile or (readfile and function(Path)
    local Success, Result = pcall(readfile, Path)
    return Success and Result and Result ~= ""
end) or EmptyFunction

local delfile = delfile or (writefile and function(Path)
    writefile(Path, "")
end) or EmptyFunction

local isfolder = isfolder or function(...) return true end

-- // Signal
local Signal = {}
Signal.__index = Signal

function Signal.new()
    return setmetatable({
        _callbacks = {}
    }, Signal)
end

function Signal:Connect(Func)
    assert(type(Func) ~= "function", "Signal: Given callback isn't a function!")

    table.insert(self._callbacks, Func)
    return {
        Disconnect = function()
            for Index, Callback in self._callbacks do
                if Callback == Func then
                    table.remove(self._callbacks, Index)
                    break
                end
            end
        end
    }
end

function Signal:Fire(...)
    for _, Callback in self._callbacks do
        Callback(...)
    end
end

-- // Services
local Services = setmetatable({}, {
    __index = function(self, Name)
        local Service = cloneref(game:GetService(Name))
        rawset(self, Name, Service)
        return Service
    end
})

local InputService = Services.UserInputService
local PlayersService = Services.Players
local RunService = Services.RunService

-- // Variables
local LocalPlayer = PlayersService.LocalPlayer
local PreRender = RunService.PreRender
local Mouse = cloneref(LocalPlayer:GetMouse())

-- Some people like to use KBM on mobile, or just keyboard scripts
local TouchEnabled = InputService.TouchEnabled and not InputService.KeyboardEnabled

-- // ScreenGui
local Container = Instance.new("ScreenGui", (function()
    for _, Try in {
        function() return gethui() end,
        function() return Services.CoreGui.RobloxGui end,
        function() return Services.CoreGui end,
        function() return LocalPlayer:FindFirstChildWhichIsA("PlayerGui") end
    } do
        local Success, Parent = pcall(Try)

        if Success and Parent then
            return Parent
        end
    end
end)())
Container.IgnoreGuiInset = true
Container.OnTopOfCoreBlur = true

-- // Library
local Library = {
    Registry = {},
    Connections = {},
    OpenedFrames = {},

    OnUnload = Signal.new(),

    Palette = {
        Text = Color3.fromRGB(255, 255, 255),
        Background = Color3.fromRGB(15, 15, 15)
    },

    KeyCode = Enum.KeyCode.RightControl,
    ScreenGui = Container,
}

function Library:Unload()
    self:AttemptSave()

    local Connections = self.Connections

    for Connection = 1, #Connections do
        local Index = table.remove(Connections, table.find(Connections, Connection))

        if Index then
            Index:Disconnect()
        end
    end

    self.ScreenGui:Destroy()
    table.clear(self)
end

-- // Filesystem creation
if makefolder then
    for _, Folder in {"Library", "Library/Assets", "Library/Configs"} do
        if not isfolder(Folder) then
            makefolder(Folder)
        end
    end
end

-- // Assets
local Assets = {
    ["Library/Assets/shadow.png"] = "rbxassetid://1234567890",

}

local assetfunction = getcustomasset; local getcustomasset = (assetfunction and writefile) and function(Path)
    if not isfile(Path) then
        local Success, Content = pcall(game.HttpGet, game, Path:gsub("Library", "https://example.com"))
    
        if Success and Content and Content ~= "404: Not Found" then
            writefile(Path, Content)
        else
            return Assets[Path] or ""
        end
    end

    return assetfunction(Path)
end or function(Path)
    return Assets[Path] or ""
end

-- // Helper functions
function Library:Create(ClassName: string | Instance, Properties: {[string]: any}?): Instance
    local Object = type(ClassName) == "string" and Instance.new(ClassName) or ClassName

    if Properties then for Property, Value in Properties do
        Object[Property] = Value
    end end

    return Object
end

function Library:Connect(Signal: RBXScriptSignal, Callback: (any) -> ()): RBXScriptConnection
    -- Should only be used for non-UI objects
    local Connection = Signal:Connect(Callback)
    self.Connections[#self.Connections+1] = Connection
    return Connection
end

-- // Registry functions
function Library:AddToRegistry(Object: Instance | any, Properties: {[string]: string | Color3})
    -- Could also be used for Drawings, hence why Instance | any
    self.Registry[Object] = Properties
end

function Library:RemoveFromRegistry(Object: Instance | any)
    self.Registry[Object] = nil
end

function Library:UpdateColorsUsingRegistry()
    for Object, Properties in self.Registry do
        for Property, Value in Properties do
            Object[Property] = self.Palette[Value] or Value
        end
    end
end

Container.DescendantRemoving:Connect(function(Descendant)
    local Connections = Library.Connections

    local Entry = table.remove(Connections, table.find(Connections, Descendant))

    if Entry then
        Library:RemoveFromRegistry(Entry)
    end
end)

-- // UI helper functions
function Library:ApplyCorner(Object: GuiObject, Radius: number?)
    return self:Create("UICorner", {
        CornerRadius = Radius or UDim.new(0, 10),
        Parent = Object
    })
end

function Library:ApplyStroke(Object: GuiObject): UIStroke
    local Stroke = self:Create("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = self.Palette.Stroke,
        Parent = Object
    })

    self:AddToRegistry(Stroke, {Color = "Stroke"})

    return Stroke
end

function Library:ApplyPadding(Object: GuiObject, Sides: {[string]: number}): UIPadding
    return self:Create("UIPadding", {
        PaddingLeft = UDim.new(0, Sides.L or 0),
        PaddingRight = UDim.new(0, Sides.R or 0),
        PaddingTop = UDim.new(0, Sides.T or 0),
        PaddingBottom = UDim.new(0, Sides.B or 0),
        Parent = Object
    })
end

function Library:AddShadow(Object: GuiObject, isCircle: boolean?): ImageLabel
    local Shadow = self:Create("ImageLabel", {
        BackgroundTransparency = 1,
        Image = getcustomasset(`Library/Assets/{isCircle and "shadow-circle.png" or "shadow.png"}`),
        ImageColor3 = Color3.new(),
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = isCircle and Rect.new() or Rect.new(),
        Parent = Object
    })

    if not isCircle then
        Shadow.AutomaticSize = Enum.AutomaticSize.XY
        self:ApplyPadding(Shadow, {L=12, B=12, R=12, T=12})

    end
end

local DragInfo
Library:Connect(InputService.InputChanged, function(Input)
    if DragInfo and (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch) then
        local Delta = Input.Position - DragInfo.Start
        local DragPos = DragInfo.Position
        DragInfo.Object.Position = UDim2.new(
            DragPos.X.Scale,
            DragPos.X.Offset + Delta.X,
            DragPos.Y.Scale,
            DragPos.Y.Offset + Delta.Y
        )
    end
end)

Library:Connect(InputService.InputEnded, function(Input)
    if DragInfo and (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
        DragInfo = nil
    end
end)

function Library:MakeDraggable(Object: GuiObject, DependsOnObject: GuiObject?)
    Object.InputBegan:Connect(function(Input)
        -- If DependsOnObject is given, update Object's position only when DependsOnObject is visible
        -- Used for separate windows like keybinds, watermark, etc.
        if (not DependsOnObject or DependsOnObject.Visible) and Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
            DragInfo = {
                Object = Object,
                Start = Input.Position,
                Position = Object.Position
            }
        end
    end)
end

-- // UI objects
local Translator = Library:Create("Translator")

-- // Window
function Library:Window(Options: {
        Title: string?,
        Subtitle: string?,
        Icon: string?,
    })

    local Window = {
        Title = Options.Title or "Window",
        Subtitle = Options.Subtitle,
        Icon = Options.Icon,
        Tabs = {}
    }

    return Window
end

-- // Notify
function Library:Notify(Options: {
        Title: string?,
        Text: string,
        Icon: string?,
        Duration: number?
    })

end

-- // Tab initialization
function Library:InitTabs(Window)

    -- // Tabs
    local BindsTab = Window:Tab({
        Name = "Binds",
        Icon = "keyboard",
        OnlyOneSide = true
    })

    local ConfigTab = Window:Tab({
        Name = "Config",
        Icon = "settings"
    })

    -- // Sections
    local NewBindSection = BindsTab:Section("New bind")
    local BindsSection = BindsTab:Section("Binds")

    local ConfigSection = ConfigTab:Section("Config")
    local UISection = ConfigTab:Section("Interface")
    local ColorsSection = ConfigTab:Section("Colors")
end

-- // Initialization
SharedTable.LyreUI = Library
return Library