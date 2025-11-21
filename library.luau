if shared.MoeLibrary then shared.MoeLibrary:Unload() end

local StartTime; if shared.MoeDebug then
    StartTime = os.clock()
end

-- This library is heavily pasted from linoria

-- // Services
local InputService = cloneref(game:GetService("UserInputService"))
local TweenService = cloneref(game:GetService("TweenService"))
local HttpService = cloneref(game:GetService("HttpService"))
local RunService = cloneref(game:GetService("RunService"))
local Players = cloneref(game:GetService("Players"))

-- // Variables
local PreRender = RunService.PreRender
local Mouse = cloneref(Players.LocalPlayer:GetMouse())
local Options = {}

local WindowFrame

-- // ScreenGui
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global

-- // Library
local Library = {
    KeyCode = Enum.KeyCode.RightControl,
    Registry = {},

    KeepInBounds = false,

    TextColor = Color3.fromRGB(240, 240, 240),
    MainColor = Color3.fromRGB(20, 20, 20),
    BackgroundColor = Color3.fromRGB(15, 15, 15),
    StrokeColor = Color3.fromRGB(50, 50, 50),
    AccentColor = Color3.fromRGB(200, 150, 225),
    DeselectedColor = Color3.fromRGB(180, 180, 180),

    Black = Color3.new(0, 0, 0),
    Font = Font.new("rbxassetid://12187365364"), -- Inter

    OpenedFrames = {},
    Connections = {},

    ScreenGui = ScreenGui
}

for _, Folder in {"moehook", "moehook/configs", "moehook/assets"} do
    if not isfolder(Folder) then
        makefolder(Folder)
    end
end

local Assets = {
    ["moehook/assets/resize.png"] = "rbxassetid://102131664028298",
    ["moehook/assets/transparency.png"] = "rbxassetid://105632977311596",
    ["moehook/assets/logo.png"] = "rbxassetid://133547912349609", -- yes it's just a paw i'll make an actual logo later

}

local getcustomasset = getcustomasset and function(Path)
    if not isfile(Path) then
        writefile(Path, game:HttpGet(Path:gsub("moehook", "https://raw.githubusercontent.com/moehook/script/refs/heads/"..shared.moehook_beta and "beta/" or "main/")))
    end

    return readfile(Path)
end or function(Path)
    return Assets[Path]
end

function Library:Unload()
    for _, Connection in Library.Connections do
        Connection:Disconnect()
    end

    ScreenGui:Destroy()
end

-- // Helper functions
local function New(ClassName, Properties)
    local Object = Instance.new(ClassName)

    if Properties then for Property, Value in next, Properties do
        Object[Property] = Value
    end end

    return Object
end

local function Connect(Signal, Callback)
    -- Should only be used for signals outside of the main GUI
    local Connection = Signal:Connect(Callback)
    table.insert(Library.Connections, Connection)
    return Connection
end

local function ModifyBrightness(Color, Amount)
    local H, S, V = Color:ToHSV()
    local NewV = V + Amount

    if NewV < 0 or NewV > 1 then
        NewV = V - Amount
    end

    return Color3.fromHSV(H, S, NewV)
end

Library.DarkerAccentColor = ModifyBrightness(Library.AccentColor, -0.185)

local function ColorText(Text, Color)
    local R, G, B = math.floor(Color.R * 255), math.floor(Color.G * 255), math.floor(Color.B * 255)
    return `<font color="rgb({R}, {G}, {B})">{Text}</font>`
end

local function GetIdx(Name)
    -- Returns index for option table
    local Key = Name
    local Counter = 2

    while Options[Key] do
        Key = Name.."_"..Counter
        Counter += 1
    end

    return Key
end

-- // Registry functions
local function AddToRegistry(Object, Properties)
    Library.Registry[Object] = Properties
end

function Library:UpdateColors()
    Library.DarkerAccentColor = ModifyBrightness(Library.AccentColor, -0.185)
    Library.Title.Text = `moe{ColorText("hook", Library.AccentColor)} {ColorText(Library.Version, Library.DeselectedColor)}`

    for Object, Properties in next, Library.Registry do
        for Property, Color in Properties do
            Object[Property] = Library[Color] or Color
        end
    end
end

Connect(ScreenGui.DescendantRemoving, function(Object)
    if Library.Registry[Object] then
        Library.Registry[Object] = nil
    end
end)

-- // UI helper functions
local function ApplyStroke(Object, Inner)
    local Stroke = New("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = Inner and Library.AccentColor or Library.Black,
        Parent = New("Frame", {
            BackgroundTransparency = 1,
            Position = Inner and UDim2.fromOffset(1, 1) or UDim2.fromOffset(-1, -1),
            Size = Inner and UDim2.new(1, -2, 1, -2) or UDim2.new(1, 2, 1, 2),
            Parent = Object
        })
    })

    AddToRegistry(Stroke, {Color = Inner and "AccentColor" or "Black"})

    return Stroke
end

local function ApplyPadding(Object, Paddings)
    return New("UIPadding", {
        PaddingLeft = UDim.new(0, Paddings.L or 0),
        PaddingRight = UDim.new(0, Paddings.R or 0),
        PaddingTop = UDim.new(0, Paddings.T or 0),
        PaddingBottom = UDim.new(0, Paddings.B or 0),
        Parent = Object
    })
end

local function AddGradient(Object, Color, Transparency)
    -- TODO: Simplify, I hate this function so much...
    return New("UIGradient", {
        Color = if typeof(Color) == "ColorSequence" then Color else ColorSequence.new({ColorSequenceKeypoint.new(0, Color), ColorSequenceKeypoint.new(1, Color)}),
        Transparency = if typeof(Transparency) == "NumberSequence" then Transparency else NumberSequence.new({NumberSequenceKeypoint.new(0, Transparency), NumberSequenceKeypoint.new(1, Transparency)}),
        Parent = Object
    })
end

local function AddLine(Object)
    local Line = New("Frame", {
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Library.StrokeColor,
        BorderSizePixel = 0,
        Parent = Object
    })

    AddToRegistry(Line, {BackgroundColor3 = "StrokeColor"})
    
    return Line
end

local function IsMouseOverFrame(Frame)
    local Pos, Size = Frame.AbsolutePosition, Frame.AbsoluteSize

    return Mouse.X >= Pos.X and Mouse.X <= Pos.X + Size.X
    and Mouse.Y >= Pos.Y and Mouse.Y <= Pos.Y + Size.Y
end

local function IsMouseOverOpenedFrame()
    for Frame, _ in next, Library.OpenedFrames do
        local Pos, Size = Frame.AbsolutePosition, Frame.AbsoluteSize

        return Mouse.X >= Pos.X and Mouse.X <= Pos.X + Size.X
        and Mouse.Y >= Pos.Y and Mouse.Y <= Pos.Y + Size.Y
    end
end

local Tooltip = New("TextLabel", {
    BackgroundColor3 = Library.MainColor,
    FontFace = Library.Font,
    TextColor3 = Library.TextColor,
    BorderColor3 = Library.StrokeColor,
    TextSize = 14,
    Visible = false,
    Parent = ScreenGui
})

AddToRegistry(Tooltip, {
    BackgroundColor3 = "MainColor",
    TextColor3 = "TextColor",
    BorderColor3 = "StrokeColor"
})

local function AddTooltip(Object, Text)
    local IsHovering = false

    Object.MouseEnter:Connect(function()
        if IsMouseOverOpenedFrame() then return end

        IsHovering = true
        Tooltip.Text = Text
        Tooltip.Size = UDim2.fromOffset(Tooltip.TextBounds.X, 30)
        Tooltip.Visible = true

        while IsHovering do
            PreRender:Wait()
            Tooltip.Position = UDim2.fromOffset(Mouse.X + 8, Mouse.Y + 8)
        end
    end)

    Object.MouseLeave:Connect(function()
        IsHovering = false
        Tooltip.Visible = false
    end)
end

local function MakeDraggable(Object, DependsOnObject, IsWindow)
    Object.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 and (not DependsOnObject or DependsOnObject.Visible) then
            local Pos = Vector2.new(Mouse.X - Object.AbsolutePosition.X, Mouse.Y - Object.AbsolutePosition.Y)

            if IsWindow and Pos.Y > 30 then return end

            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                local NewX = Mouse.X - Pos.X
                local NewY = Mouse.Y - Pos.Y

                -- Screen Boundary Check
                if Library.KeepInBounds then
                    local ScreenSize = ScreenGui.AbsoluteSize
                    local ObjectSize = Object.AbsoluteSize
                    
                    NewX = math.clamp(NewX, 0, ScreenSize.X - ObjectSize.X)
                    NewY = math.clamp(NewY, 0, ScreenSize.Y - ObjectSize.Y)
                end

                Object.Position = UDim2.fromOffset(
                    NewX + (Object.Size.X.Offset * Object.AnchorPoint.X),
                    NewY + (Object.Size.Y.Offset * Object.AnchorPoint.Y)
                )

                PreRender:Wait()
            end
        end
    end)
end
-- // UI objects
local Notifications = New("Frame", {
    Position = UDim2.fromOffset(8, 8),
    Size = UDim2.new(1, -16, 1, -16),
    BackgroundTransparency = 1,
    Parent = ScreenGui
})

local NotifTweenInfo = TweenInfo.new(.2, Enum.EasingStyle.Exponential)

-- // Watermark (Yes this is copied from Ateris)
local WatermarkFrame = New("Frame", {
    BackgroundColor3 = Library.BackgroundColor,
    BorderColor3 = Library.StrokeColor,
    Position = UDim2.fromOffset(8, 8),
    Size = UDim2.fromOffset(30, 30),
    Parent = ScreenGui
}) ApplyStroke(WatermarkFrame); MakeDraggable(WatermarkFrame, WindowFrame)

AddToRegistry(WatermarkFrame, {
    BackgroundColor3 = "BackgroundColor",
    BorderColor3 = "StrokeColor"
})

local WatermarkIcon = New("ImageLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(5, 5),
        Size = UDim2.fromOffset(20, 20),
        Image = getcustomasset("moehook/assets/logo.png"),
        ImageColor3 = Library.AccentColor,
        Parent = WatermarkFrame
})

AddToRegistry(WatermarkIcon, {ImageColor3 = "AccentColor"})

local WatermarkTextFrame = New("Frame", {
    BackgroundColor3 = Library.BackgroundColor,
    BorderColor3 = Library.StrokeColor,
    Position = UDim2.new(1, 10, 0, 0),
    Size = UDim2.fromOffset(150, 30),
    Parent = WatermarkFrame
})  local WatermarkTextFrameStroke = ApplyStroke(WatermarkTextFrame)

AddToRegistry(WatermarkTextFrame, {
    BackgroundColor3 = "BackgroundColor",
    BorderColor3 = "StrokeColor"
})

local WatermarkGradient = AddGradient(WatermarkTextFrame, Color3.new(1, 1, 1), NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0),
    NumberSequenceKeypoint.new(1, 1)
}))

WatermarkGradient:Clone().Parent = WatermarkTextFrameStroke

local WatermarkText = New("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(8, 0),
    Size = UDim2.new(1, -16, 1, 0),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextSize = 14,
    FontFace = Library.Font,
    TextColor3 = Library.TextColor,
    TextStrokeTransparency = .5,
    RichText = true,
    Text = `moehook v{Library.Version}`,
    Parent = WatermarkTextFrame
})

AddToRegistry(WatermarkText, {TextColor3 = "TextColor"})

-- // Dropdown
local DropdownFrame = New("ScrollingFrame", {
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
    BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
    ScrollBarThickness = 2,
    ScrollBarImageColor3 = Library.StrokeColor,
    ScrollBarImageTransparency = 0,
    CanvasSize = UDim2.new(),
    BackgroundColor3 = Library.BackgroundColor,
    BorderColor3 = Library.StrokeColor,
    ZIndex = 2,
    Visible = false,
    Parent = ScreenGui
}) ApplyPadding(DropdownFrame, {L=6, R=8}); New("UIListLayout", {
    Parent = DropdownFrame
})

AddToRegistry(DropdownFrame, {
    BackgroundColor3 = "BackgroundColor",
    ScrollBarImageColor3 = "StrokeColor",
    BorderColor3 = "StrokeColor"
})

-- // Keybind context menu
local KeyContextMenu = New("Frame", {
    Size = UDim2.fromOffset(54, 61),
    BackgroundColor3 = Library.MainColor,
    BorderColor3 = Library.StrokeColor,
    Visible = false,
    ZIndex = 2,
    Parent = ScreenGui
}) ApplyPadding(KeyContextMenu, {B=1, L=6, R=8})

AddToRegistry(KeyContextMenu, {
    BackgroundColor3 = "MainColor",
    BorderColor3 = "StrokeColor"
})

local HoldButton = New("TextButton", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 20),
    FontFace = Library.Font,
    TextSize = 14,
    TextColor3 = Library.DeselectedColor,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "hold",
    ZIndex = 3,
    Parent = KeyContextMenu
})

local ToggleButton = HoldButton:Clone()
ToggleButton.Position = UDim2.fromOffset(0, 20)
ToggleButton.Text = "toggle"
ToggleButton.Parent = KeyContextMenu

local AlwaysButton = HoldButton:Clone()
AlwaysButton.Position = UDim2.fromOffset(0, 40)
AlwaysButton.Text = "always"
AlwaysButton.Parent = KeyContextMenu

for _, Button in {HoldButton, ToggleButton, AlwaysButton} do
    AddToRegistry(Button, {TextColor3 = "DeselectedColor"})

    Button.MouseEnter:Connect(function()
        if Button.TextColor3 ~= Library.AccentColor then
            Button.TextColor3 = Library.TextColor
            Library.Registry[Button].TextColor3 = "TextColor"
        end
    end)

    Button.MouseLeave:Connect(function()
        if Button.TextColor3 ~= Library.AccentColor then
            Button.TextColor3 = Library.DeselectedColor
            Library.Registry[Button].TextColor3 = "DeselectedColor"
        end
    end)
end

-- // Colorpicker
local ColorpickerFrame = New("Frame", {
    Size = UDim2.fromOffset(172, 200),
    BackgroundColor3 = Library.MainColor,
    BorderColor3 = Library.StrokeColor,
    Visible = false,
    ZIndex = 2,
    Parent = ScreenGui
}) ApplyStroke(ColorpickerFrame)

AddToRegistry(ColorpickerFrame, {
    BackgroundColor3 = "MainColor",
    BorderColor3 = "StrokeColor"
})

local SaturationFrame = New("TextButton", {
    Position = UDim2.fromOffset(8, 8),
    AutoButtonColor = false,
    Size = UDim2.fromOffset(156, 130),
    BorderColor3 = Library.StrokeColor,
    ZIndex = 3,
    BackgroundColor3 = Color3.new(1, 1, 1),
    Text = "",
    Parent = ColorpickerFrame
}); local BlackColor = New("Frame", {
    BackgroundColor3 = Library.Black,
    Size = UDim2.fromScale(1, 1),
    ZIndex = 4,
    Interactable = false,
    Parent = SaturationFrame
})

AddToRegistry(SaturationFrame, {
    BorderColor3 = "StrokeColor"
})

local SaturationDragger = New("Frame", {
    BackgroundColor3 = Library.TextColor,
    AnchorPoint = Vector2.new(.5, .5),
    BorderColor3 = Library.Black,
    Interactable = false,
    ZIndex = 5,
    Size = UDim2.fromOffset(2, 2),
    Parent = SaturationFrame
})

AddToRegistry(SaturationDragger, {BackgroundColor3 = "TextColor"})

local HueSlider = New("TextButton", {
    Position = UDim2.fromOffset(8, 146),
    Size = UDim2.fromOffset(156, 20),
    BorderColor3 = Library.StrokeColor,
    AutoButtonColor = false,
    ZIndex = 3,
    BackgroundColor3 = Color3.new(1, 1, 1),
    Text = "",
    Parent = ColorpickerFrame
})

AddToRegistry(HueSlider, {BorderColor3 = "StrokeColor"})

local HueLine = New("Frame", {
    BackgroundColor3 = Library.TextColor,
    Size = UDim2.new(0, 1, 1, 0),
    BorderColor3 = Library.Black,
    ZIndex = 4,
    Interactable = false,
    Parent = HueSlider
})

AddToRegistry(HueLine, {BackgroundColor3 =  "TextColor"})

local RTextBox = New("TextBox", {
    Position = UDim2.fromOffset(63, 174),
    FontFace = Library.Font,
    BackgroundColor3 = Library.BackgroundColor,
    BorderColor3 = Library.StrokeColor,
    TextColor3 = Color3.fromRGB(240, 150, 150),
    TextSize = 14,
    PlaceholderText = "",
    ZIndex = 3,
    Parent = ColorpickerFrame
})

local GTextBox = RTextBox:Clone()
GTextBox.Position = UDim2.fromOffset(63, 174)
GTextBox.TextColor3 = Color3.fromRGB(150, 240, 150)
GTextBox.Parent = ColorpickerFrame

local BTextBox = RTextBox:Clone()
BTextBox.Position = UDim2.fromOffset(117, 174)
BTextBox.TextColor3 = Color3.fromRGB(150, 150, 240)
BTextBox.Parent = ColorpickerFrame

for _, TextBox in next, {RTextBox, GTextBox, BTextBox} do
    AddToRegistry(TextBox, {
        BackgroundColor3 = "BackgroundColor",
        BorderColor3 = "StrokeColor"
    })
end

-- // Colorpicker context menu
local ColorpickerContextMenu = New("Frame", {
    Size = UDim2.fromOffset(54, 41),
    BackgroundColor3 = Library.MainColor,
    BorderColor3 = Library.StrokeColor,
    Visible = false,
    ZIndex = 2,
    Parent = ScreenGui
}) ApplyPadding(ColorpickerContextMenu, {B=1, L=6, R=8})

AddToRegistry(ColorpickerContextMenu, {
    BackgroundColor3 = "MainColor",
    BorderColor3 = "StrokeColor"
})

local CopyButton = New("TextButton", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 20),
    FontFace = Library.Font,
    TextSize = 14,
    TextColor3 = Library.DeselectedColor,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "copy",
    ZIndex = 3,
    Parent = ColorpickerContextMenu
})

AddToRegistry(CopyButton, {TextColor3 = "DeselectedColor"})

local PasteButton = CopyButton:Clone()
PasteButton.Position = UDim2.fromOffset(0, 20)
PasteButton.Text = "paste"
PasteButton.Parent = ColorpickerContextMenu

AddToRegistry(PasteButton, {TextColor3 = "DeselectedColor"})

CopyButton.MouseEnter:Connect(function()
    CopyButton.TextColor3 = Library.TextColor
    Library.Registry[CopyButton].TextColor3 = "TextColor"
end)

CopyButton.MouseLeave:Connect(function()
    CopyButton.TextColor3 = Library.DeselectedColor
    Library.Registry[CopyButton].TextColor3 = "DeselectedColor"
end)

PasteButton.MouseEnter:Connect(function()
    if PasteButton.Selectable then
        PasteButton.TextColor3 = Library.TextColor
        Library.Registry[PasteButton] = "TextColor"
    end
end)

PasteButton.MouseLeave:Connect(function()
    if PasteButton.Selectable then
        PasteButton.TextColor3 = Library.DeselectedColor
        Library.Registry[PasteButton] = "DeselectedColor"
    end
end)

-- // Library functions
function Library:Window(Version)
    Library.Version = Version

    WindowFrame = New("Frame", {
        AnchorPoint = Vector2.new(.5, .5),
        Position = UDim2.fromScale(.5, .5),
        BorderColor3 = Library.StrokeColor,
        BackgroundColor3 = Library.BackgroundColor,
        Size = UDim2.fromOffset(400, 400),
        Parent = ScreenGui
    }) ApplyStroke(WindowFrame); MakeDraggable(WindowFrame, nil, true)

    AddToRegistry(WindowFrame, {
        BackgroundColor3 = "BackgroundColor",
        BorderColor3 = "StrokeColor"
    })

    local ResizeButton = New("ImageButton", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ImageColor3 = Library.StrokeColor,
        Image = getcustomasset("moehook/assets/resize.png"),
        Size = UDim2.fromOffset(12, 12),
        Parent = WindowFrame
    })

    AddToRegistry(ResizeButton, {ImageColor3 = "StrokeColor"})

    ResizeButton.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            local StartMouse = Vector2.new(Mouse.X, Mouse.Y)
            local StartSize = WindowFrame.AbsoluteSize
            local StartPos = WindowFrame.AbsolutePosition
            
            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                local Delta = Vector2.new(Mouse.X, Mouse.Y) - StartMouse
                
                local NewX = math.max(StartSize.X + Delta.X, 400)
                local NewY = math.max(StartSize.Y + Delta.Y, 400)

                if Library.KeepInBounds then
                    local ScreenSize = ScreenGui.AbsoluteSize
                    
                    if StartPos.X + NewX > ScreenSize.X then
                        NewX = ScreenSize.X - StartPos.X
                    end
                    
                    if StartPos.Y + NewY > ScreenSize.Y then
                        NewY = ScreenSize.Y - StartPos.Y
                    end
                end

                WindowFrame.Size = UDim2.fromOffset(NewX, NewY)
                WindowFrame.Position = UDim2.fromOffset(StartPos.X + (NewX / 2), StartPos.Y + (NewY / 2))

                PreRender:Wait()
            end
        end
    end)

    Connect(InputService.InputBegan, function(Input)
        if Input.KeyCode == Library.KeyCode then
            WindowFrame.Visible = not WindowFrame.Visible
            if Library.OpenedFrames[DropdownFrame] then
                Library.OpenedFrames[DropdownFrame]:Hide()
            end
        end

        -- TODO: Make it so the dropdown moves around w/ the window
        if Input.UserInputType == Enum.UserInputType.MouseButton1 and Library.OpenedFrames[DropdownFrame] then
            if not IsMouseOverFrame(Library.OpenedFrames[DropdownFrame].Button) and not
            IsMouseOverFrame(DropdownFrame) and Library.OpenedFrames[DropdownFrame].Open then
                Library.OpenedFrames[DropdownFrame]:Hide()
            end
        end

        if Input.UserInputType == Enum.UserInputType.MouseButton1 and Library.OpenedFrames[KeyContextMenu] then
            if not IsMouseOverFrame(Library.OpenedFrames[KeyContextMenu].Button) and not
            IsMouseOverFrame(KeyContextMenu) and Library.OpenedFrames[KeyContextMenu].Open then
                Library.OpenedFrames[KeyContextMenu]:Hide()
            end
        end
    end)

    -- // "Last" variables for open-up menus
    local LastDropdown = nil


    local TitleFrame = New("Frame", {
        BackgroundColor3 = Library.MainColor,
        Size = UDim2.new(1, 0, 0, 30),
        BorderSizePixel = 0,
        Parent = WindowFrame
    }) AddLine(TitleFrame)

    AddToRegistry(TitleFrame, {BackgroundColor3 = "MainColor"})

    local Title = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(8, 0),
        FontFace = Library.Font,
        TextColor3 = Library.TextColor,
        TextSize = 14,
        RichText = true,
        Text = `moe{ColorText("hook", Library.AccentColor)} {ColorText(Version, Library.DeselectedColor)}`,
        Parent = TitleFrame
    }) Title.Size = UDim2.new(0, Title.TextBounds.X, 1, 0)

    Library.Title = Title

    AddToRegistry(Title, {TextColor3 = "TextColor"})

    local TabsFrame = New("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -8, 0, 4),
        Size = UDim2.new(1, -Title.AbsoluteSize.X - 8, 1, -8),
        Parent = TitleFrame
    }) New("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = TabsFrame
    })

    local TabComponentHolder = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, -30),
        Position = UDim2.fromOffset(0, 30),
        Parent = WindowFrame
    })

    local WindowFunctions = {}
    local SelectedTab = nil

    local function SelectTab(TabButton)
        if SelectedTab then
            SelectedTab.TextColor3 = Library.DeselectedColor
            Library.Registry[SelectedTab].TextColor3 = "DeselectedColor"
            TabComponentHolder[SelectedTab.Name].Visible = false
        end

        TabButton.TextColor3 = Library.AccentColor
        Library.Registry[TabButton].TextColor3 = "AccentColor"
        TabComponentHolder[TabButton.Name].Visible = true

        SelectedTab = TabButton
    end

    function WindowFunctions:Tab(Name)
        local TabButton = New("TextButton", {
            Name = Name,
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            FontFace = Library.Font,
            TextColor3 = Library.DeselectedColor,
            TextSize = 14,
            Text = Name,
            Parent = TabsFrame
        }) TabButton.Size = UDim2.new(0, TabButton.TextBounds.X + 8, 1, 0)

        AddToRegistry(TabButton, {TextColor3 = "DeselectedColor"})
        
        TabButton.MouseEnter:Connect(function()
            if SelectedTab ~= TabButton then
                TabButton.TextColor3 = Library.TextColor
                Library.Registry[TabButton].TextColor3 = "TextColor"
            end
        end)

        TabButton.MouseLeave:Connect(function()
            if SelectedTab ~= TabButton then
                TabButton.TextColor3 = Library.DeselectedColor
                Library.Registry[TabButton].TextColor3 = "DeselectedColor"
            end
        end)

        TabButton.MouseButton1Down:Connect(function() SelectTab(TabButton) end)

        local TabComponents = New("ScrollingFrame", {
            Name = Name,
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            CanvasSize = UDim2.new(),
            ScrollBarThickness = 0,
            Visible = false,
            Parent = TabComponentHolder
        }) ApplyPadding(TabComponents, {L=8, R=8, B=8, T=8})

        local LeftSide = New("Frame", {
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(0.5, -13),
            Parent = TabComponents
        }) New("UIListLayout", {
            Padding = UDim.new(0, 10),
            Parent = LeftSide
        })

        local RightSide = LeftSide:Clone()
        RightSide.Position = UDim2.new(0.5, 5, 0, 0)
        RightSide.Parent = TabComponents

        if not SelectedTab then SelectTab(TabButton) end

        local TabFunctions = {}
        local SectionCount = 0

        function TabFunctions:Section(Name)
            SectionCount += 1

            local SectionFrame = New("Frame", {
                AutomaticSize = Enum.AutomaticSize.Y,
                Size = UDim2.new(1, 0, 0, 60),
                BorderColor3 = Library.StrokeColor,
                BackgroundColor3 = Library.MainColor,
                Parent = (SectionCount % 2 == 1) and LeftSide or RightSide
            })

            AddToRegistry(SectionFrame, {
                BackgroundColor3 = "MainColor",
                BorderColor3 = "StrokeColor"
            })

            local SectionTitle = New("TextLabel", {
                BackgroundColor3 = Library.BackgroundColor,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 30),
                FontFace = Library.Font,
                TextSize = 14,
                TextColor3 = Library.TextColor,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = Name,
                Parent = SectionFrame
            }) ApplyPadding(SectionTitle, {L=8}); local SectionLine = AddLine(SectionTitle)
            SectionLine.Position = UDim2.new(0, -8, 1, -1)
            SectionLine.Size = UDim2.new(1, 8, 0, 1)

            AddToRegistry(SectionTitle, {
                BackgroundColor3 = "BackgroundColor",
                TextColor3 = "TextColor"
            })

            local SectionComponents = New("Frame", {
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.Y,
                Position = UDim2.fromOffset(0, 30),
                Size = UDim2.new(1, 0, 0, 30),
                Parent = SectionFrame
            }) ApplyPadding(SectionComponents, {L=8, R=8, B=8, T=8}); New("UIListLayout", {
                Padding = UDim.new(0, 8),
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = SectionComponents
            })

            local SectionFunctions = {}
            local ComponentCount = 0

            function SectionFunctions:Label(Text)
                local TextLabel = New("TextLabel", {
                    
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 20),
                    FontFace = Library.Font,
                    RichText = true,
                    TextSize = 14,
                    TextColor3 = Library.TextColor,
                    TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = Text,
                    Parent = SectionComponents
                })

                AddToRegistry(TextLabel, {TextColor3 = "TextColor"})
                
                local Label = {

                }
                function Label:SetValue(Value)
                    TextLabel.Text = Value
                    Label.Value = Value
                end
                
                return Label
            end

            function SectionFunctions:Button(Name, Callback)
                local Button = New("TextButton", {
                    
                    BackgroundColor3 = Library.BackgroundColor,
                    BorderColor3 = Library.StrokeColor,
                    AutoButtonColor = false,
                    Size = UDim2.new(1, 0, 0, 20),
                    FontFace = Library.Font,
                    TextColor3 = Library.DeselectedColor,
                    TextSize = 14,
                    RichText = true,
                    Text = Name,
                    Parent = SectionComponents
                })

                AddToRegistry(Button, {
                    BackgroundColor3 = "BackgroundColor",
                    BorderColor3 = "StrokeColor",
                    TextColor3 = "DeselectedColor"
                })

                Button.MouseEnter:Connect(function()
                    Button.TextColor3 = Library.TextColor
                    Library.Registry[Button].TextColor3 = "TextColor"
                end)

                Button.MouseLeave:Connect(function()
                    Button.TextColor3 = Library.DeselectedColor
                    Library.Registry[Button].TextColor3 = "DeselectedColor"
                end)

                Button.MouseButton1Up:Connect(function()
                    Button.TextColor3 = Library.TextColor
                    Library.Registry[Button].TextColor3 = "TextColor"
                end)

                Button.MouseButton1Down:Connect(function()
                    Callback()
                    Button.TextColor3 = Library.DeselectedColor
                    Library.Registry[Button].TextColor3 = "DeselectedColor"
                end)
            end

            function SectionFunctions:Toggle(Name, Callback, Default)
                local ToggleState = Default or false

                local ToggleButton = New("TextButton", {
                    
                    Size = UDim2.new(1, 0, 0, 20),
                    BackgroundTransparency = 1,
                    FontFace = Library.Font,
                    TextSize = 14,
                    TextColor3 = Library.DeselectedColor,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = Name,
                    Parent = SectionComponents
                }) ApplyPadding(ToggleButton, {L=28})

                AddToRegistry(ToggleButton, {TextColor3 = "DeselectedColor"})

                local ToggleFrame = New("Frame", {
                    BackgroundColor3 = Library.BackgroundColor,
                    Position = UDim2.fromOffset(-28, 0),
                    Size = UDim2.fromOffset(20, 20),
                    Interactable = false,
                    BorderColor3 = Library.StrokeColor,
                    Parent = ToggleButton
                })

                AddToRegistry(ToggleFrame, {
                    BackgroundColor3 = "BackgroundColor",
                    BorderColor3 = "StrokeColor"
                })

                local Toggle = {
                    Value = ToggleState,
                    Type = "Toggle",
                    Callback = Callback
                }

                local function UpdateToggle(State)
                    ToggleButton.TextColor3 = State and Library.TextColor or Library.DeselectedColor
                    Library.Registry[ToggleButton].TextColor3 = State and "TextColor" or "DeselectedColor"

                    ToggleFrame.BackgroundColor3 = State and Library.DarkerAccentColor or Library.BackgroundColor
                    ToggleFrame.BorderColor3 = State and Library.AccentColor or Library.StrokeColor

                    Library.Registry[ToggleFrame].BackgroundColor3 = State and "DarkerAccentColor" or "BackgroundColor"
                    Library.Registry[ToggleFrame].BorderColor3 = State and "AccentColor" or "StrokeColor"
                end

                function Toggle:SetState(State)
                    Toggle.Value = State
                    UpdateToggle(State)
                    Toggle.Callback(State)
                end

                ToggleButton.MouseEnter:Connect(function()
                    if not Toggle.Value then
                        ToggleButton.TextColor3 = Library.TextColor
                        Library.Registry[ToggleButton].TextColor3 = "TextColor"
                    end
                end)

                ToggleButton.MouseLeave:Connect(function()
                    if not Toggle.Value then
                        ToggleButton.TextColor3 = Library.DeselectedColor
                        Library.Registry[ToggleButton].TextColor3 = "DeselectedColor"           
                    end
                end)

                ToggleButton.MouseButton1Down:Connect(function()
                    Toggle:SetState(not Toggle.Value)
                end)

                UpdateToggle(ToggleState)
                Toggle.Callback(ToggleState)

                Options[GetIdx(Name)] = Toggle
                return Toggle
            end

            function SectionFunctions:Slider(Info)
                Info.Min = Info.Min or 0
                Info.Default = Info.Default or Info.Min
                Info.Increment = Info.Increment or 1

                local DecimalPlaces do
                    local Str = tostring(Info.Increment)
                    local DecimalPos = Str:find("%.")
                    if not DecimalPos then
                        DecimalPlaces = 0
                    else
                        DecimalPlaces = #Str - DecimalPos
                    end
                end

                local SliderLabel = New("TextLabel", {
                    
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 40),
                    FontFace = Library.Font,
                    TextSize = 14,
                    TextColor3 = Library.TextColor,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    Text = Info.Name,
                    Parent = SectionComponents
                })

                AddToRegistry(SliderLabel, {TextColor3 = "TextColor"})

                local SliderAmount = New("TextBox", {
                    Size = UDim2.fromOffset(50, 20),
                    AnchorPoint = Vector2.new(1, 0),
                    Position = UDim2.new(1, 0, 0, -2),
                    BackgroundTransparency = 1,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    TextSize = 14,
                    PlaceholderText = "",
                    FontFace = Library.Font,
                    TextColor3 = Library.TextColor,
                    Parent = SliderLabel
                })

                AddToRegistry(SliderAmount, {TextColor3 = "TextColor"})

                local SliderButton = New("TextButton", {
                    Position = UDim2.fromOffset(0, 20),
                    Size = UDim2.new(1, 0, 0, 20),
                    AutoButtonColor = false,
                    BackgroundColor3 = Library.BackgroundColor,
                    BorderColor3 = Library.StrokeColor,
                    Text = "",
                    Parent = SliderLabel
                })

                AddToRegistry(SliderButton, {
                    BackgroundColor3 = "BackgroundColor",
                    BorderColor3 = "StrokeColor"
                })

                local SliderValue = New("Frame", {
                    BackgroundColor3 = Library.DarkerAccentColor,
                    BorderSizePixel = 0,
                    Size = UDim2.fromScale(0, 1),
                    Interactable = false,
                    Parent = SliderButton
                }) local SliderValueStroke = ApplyStroke(SliderValue, true)

                AddToRegistry(SliderValue, {BackgroundColor3 = "DarkerAccentColor"})

                local Slider = {
                    Value = Info.Default,
                    Min = Info.Min,
                    Max = Info.Max,
                    Type = "Slider",
                    Callback = Info.Callback
                }

                local Last = nil

                local function Round(Value)
                    if DecimalPlaces == 0 then
                        return math.floor(Value)
                    end

                    return tonumber(string.format('%.' .. DecimalPlaces .. 'f', Value))
                end

                function Slider:SetValue(Value)
                    Value = math.clamp(Value, Slider.Min, Slider.Max)
                    
                    local Snapped = math.floor((Value - Slider.Min) / Info.Increment + 0.5) * Info.Increment + Slider.Min
                    Snapped = math.clamp(Snapped, Slider.Min, Slider.Max)

                    local Current = Round(Snapped)
                    
                    local Percent = (Current - Slider.Min) / (Slider.Max - Slider.Min)
                    
                    if Last ~= Current then
                        Slider.Value = Current
                        SliderValue.Size = UDim2.fromScale(Percent, 1)
                        SliderValueStroke.Enabled = true

                        if Current == Info.Min then
                            SliderValueStroke.Enabled = false
                        end

                        SliderAmount.Text = tostring(Current)
                        Last = Current
                        Slider.Callback(Current)
                    end
                end

                local function UpdateFromMouse()
                    local Percent = math.clamp((Mouse.X - SliderButton.AbsolutePosition.X) / SliderButton.AbsoluteSize.X, 0, 1)
                    local Value = Info.Min + (Info.Max - Info.Min) * Percent

                    Slider:SetValue(Value)
                end

                SliderButton.MouseButton1Down:Connect(function()
                    UpdateFromMouse()
                    
                    while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                        UpdateFromMouse()
                        PreRender:Wait()
                    end
                end)

                SliderAmount.FocusLost:Connect(function(EnterPressed)
                    if EnterPressed then
                        local Value = tonumber(SliderAmount.Text)
                        if Value then
                            Slider:SetValue(Value)
                        else
                            SliderAmount.Text = tostring(Slider.Value)
                        end
                    else
                        SliderAmount.Text = tostring(Slider.Value)
                    end
                end)

                Slider:SetValue(Info.Default)

                Options[GetIdx(Info.Name)] = Slider
                return Slider
            end

            function SectionFunctions:Dropdown(Info)
                Info.Default = Info.Default or ""
                Info.Multi = type(Info.Default) == "table"

                local DropdownLabel = New("TextLabel", {
                    
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 40),
                    FontFace = Library.Font,
                    TextSize = 14,
                    TextColor3 = Library.TextColor,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    Text = Info.Name,
                    Parent = SectionComponents
                })

                AddToRegistry(DropdownLabel, {TextColor3 = "TextColor"})

                local DropdownButton = New("TextButton", {
                    AnchorPoint = Vector2.new(0, 1),
                    Position = UDim2.fromScale(0, 1),
                    AutoButtonColor = false,
                    Size = UDim2.new(1, 0, 0, 20),
                    BackgroundColor3 = Library.BackgroundColor,
                    BorderColor3 = Library.StrokeColor,
                    TextColor3 = Library.DeselectedColor,
                    FontFace = Library.Font,
                    TextTruncate = Enum.TextTruncate.SplitWord,
                    TextSize = 14,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = DropdownLabel
                }) ApplyPadding(DropdownButton, {L=4, R=24})

                AddToRegistry(DropdownButton, {
                    BackgroundColor3 = "BackgroundColor",
                    BorderColor3 = "StrokeColor",
                    TextColor3 = "DeselectedColor"
                })

                local DropdownArrow = New("TextLabel", {
                    AnchorPoint = Vector2.new(1, 0),
                    BackgroundTransparency = 1,
                    Position = UDim2.new(1, 18, 0, 1),
                    Rotation = -45,
                    Size = UDim2.fromOffset(14, 14),
                    FontFace = Library.Font,
                    Text = "◣",
                    TextColor3 = Library.DeselectedColor,
                    TextSize = 10,
                    Parent = DropdownButton
                }) AddToRegistry(DropdownArrow, {TextColor3 = "DeselectedColor"})

                local Dropdown = {
                    Value = Info.Multi and {} or nil,
                    Values = Info.Values,
                    Type = "Dropdown",
                    Button = DropdownButton,
                    Callback = Info.Callback
                }

                DropdownButton.MouseEnter:Connect(function()
                    if not Dropdown.Open then
                        DropdownButton.TextColor3 = Library.TextColor
                        Library.Registry[DropdownButton].TextColor3 = "TextColor"
                    end
                end)

                DropdownButton.MouseLeave:Connect(function()
                    if not Dropdown.Open then
                        DropdownButton.TextColor3 = Library.DeselectedColor
                        Library.Registry[DropdownButton].TextColor3 = "DeselectedColor"
                    end
                end)

                local function UpdateButtonText()
                    if Info.Multi then
                        if #Dropdown.Value == 0 then
                            DropdownButton.Text = "none"
                        else
                            DropdownButton.Text = table.concat(Dropdown.Value, ", ")
                        end
                    else
                        DropdownButton.Text = Dropdown.Value or "none"
                    end
                end

                local function UpdateColors()
                    for _, Button in DropdownFrame:GetChildren() do
                        if Button:IsA("TextButton") then
                            local IsSelected = Button.Text == Dropdown.Value
                            Button.TextColor3 = IsSelected and Library.AccentColor or Library.DeselectedColor
                            Library.Registry[Button].TextColor3 = IsSelected and "AccentColor" or "DeselectedColor"
                        end
                    end
                end

                function Dropdown:Show()
                    Dropdown.Open = true
                    DropdownFrame.Position = UDim2.fromOffset(Mouse.X + 8, Mouse.Y + 8)
                    DropdownFrame.Size = UDim2.fromOffset(200, math.min(#Dropdown.Values, 7) * 20) -- 7=max items
                    DropdownFrame.Visible = true

                    DropdownButton.TextColor3 = Library.TextColor
                    Library.Registry[DropdownButton].TextColor3 = "TextColor"

                    DropdownArrow.Rotation = 135
                    DropdownArrow.Position = UDim2.new(1, 21, 0, 5)

                    Library.OpenedFrames[DropdownFrame] = Dropdown

                    if LastDropdown ~= Dropdown then
                        for _, Item in next, DropdownFrame:GetChildren() do
                            if Item:IsA("TextButton") then
                                Item:Destroy()
                            end
                        end

                        for _, Value in next, Dropdown.Values do
                            local IsSelected = Info.Multi and table.find(Dropdown.Value, Value) or Dropdown.Value == Value

                            local ItemButton = New("TextButton", {
                                BackgroundTransparency = 1,
                                Size = UDim2.new(1, 0, 0, 20),
                                FontFace = Library.Font,
                                TextSize = 14,
                                TextColor3 = IsSelected and Library.AccentColor or Library.DeselectedColor,
                                Text = Value,
                                ZIndex = 3,
                                TextXAlignment = Enum.TextXAlignment.Left,
                                Parent = DropdownFrame
                            })

                            AddToRegistry(ItemButton, {TextColor3 = IsSelected and "AccentColor" or "DeselectedColor"})

                            local function UpdateColor()
                                IsSelected = (Info.Multi and table.find(Dropdown.Value, Value)) or Dropdown.Value == Value

                                Library.Registry[ItemButton].TextColor3 = IsSelected and "AccentColor" or "DeselectedColor"
                                ItemButton.TextColor3 = IsSelected and Library.AccentColor or Library.DeselectedColor
                            end

                            ItemButton.MouseEnter:Connect(function()
                                if ItemButton.TextColor3 ~= Library.AccentColor then
                                    ItemButton.TextColor3 = Library.TextColor
                                    Library.Registry[ItemButton].TextColor3 = "TextColor"
                                end
                            end)

                            ItemButton.MouseLeave:Connect(UpdateColor)

                            ItemButton.MouseButton1Down:Connect(function()
                                if Info.Multi then
                                    local Idx = table.find(Dropdown.Value, Value)

                                    if Idx then
                                        table.remove(Dropdown.Value, Idx)
                                        UpdateColor()
                                    else
                                        table.insert(Dropdown.Value, Value)
                                        UpdateColor()
                                    end

                                    UpdateButtonText()
                                    Dropdown.Callback(Dropdown.Value)
                                else
                                    Dropdown:SetValue(Value)
                                    UpdateColors()
                                    Dropdown:Hide()
                                end
                            end)
                        end

                        LastDropdown = Dropdown
                    end
                end

                function Dropdown:Hide()
                    Dropdown.Open = false
                    DropdownFrame.Visible = false

                    DropdownButton.TextColor3 = Library.DeselectedColor
                    Library.Registry[DropdownButton].TextColor3 = "DeselectedColor"

                    DropdownArrow.Rotation = -45
                    DropdownArrow.Position = UDim2.new(1, 18, 0, 1)

                    Library.OpenedFrames[DropdownFrame] = nil
                end

                function Dropdown:SetValue(Value)
                    if Info.Multi then
                        Dropdown.Value = type(Value) == "table" and Value or {}
                    else
                        Dropdown.Value = Value
                    end

                    UpdateButtonText()
                    Dropdown.Callback(Dropdown.Value)
                end

                function Dropdown:SetValues(Values)
                    Dropdown.Values = Values
                    LastDropdown = nil
                end

                DropdownButton.MouseButton1Down:Connect(function()
                    if Library.OpenedFrames[DropdownFrame] then
                        Library.OpenedFrames[DropdownFrame]:Hide()
                    else
                        Dropdown:Show()
                    end
                end)

                Dropdown:SetValue(Info.Default)

                Options[GetIdx(Info.Name)] = Dropdown
                return Dropdown
            end

            function SectionFunctions:Keybind(Info)
                Info.Default = Info.Default or "none"
                Info.Mode = Info.Mode or "Toggle" -- Hold, Toggle, Always

                local KeybindLabel = New("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 20),
                    BackgroundTransparency = 1,
                    FontFace = Library.Font,
                    TextColor3 = Library.TextColor,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = Info.Text,
                    TextSize = 14,
                    Parent = SectionComponents
                })

                AddToRegistry(KeybindLabel, {
                    TextColor3 = "TextColor"
                })

                local KeybindButton = New("TextButton", {
                    AnchorPoint = Vector2.new(1, 0),
                    Position = UDim2.fromScale(1, 0),
                    AutomaticSize = Enum.AutomaticSize.X,
                    FontFace = Library.Font,
                    TextSize = 14,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    TextColor3 = Library.DeselectedColor,
                    Parent = KeybindLabel
                })

                AddToRegistry(KeybindButton, {
                    TextColor3 = "DeselectedColor"
                })

                local Keybind = {
                    Value = Info.Default,
                    Mode = Info.Mode,
                    Type = "Keybind",
                    ContextMenuOpen = false,
                    Listening = false,
                    Active = false,
                    Button = KeybindButton,
                    Callback = Info.Callback,
                    ChangedCallback = Info.ChangedCallback
                }

                function Keybind:Show()
                    Library.OpenedFrames[KeyContextMenu] = Keybind
                    KeyContextMenu.Position = UDim2.fromOffset(Mouse.X + 8, Mouse.Y + 8)
                    KeyContextMenu.Visible = true

                    for _, Button in {HoldButton, ToggleButton, AlwaysButton} do
                        Button.TextColor3 = Keybind.Mode:lower() == Button.Text and Library.AccentColor or Library.DeselectedColor
                        Library.Registry[Button].TextColor3 = Keybind.Mode:lower() == Button.Text and "AccentColor" or "DeselectedColor"
                    end
                end

                function Keybind:Hide()
                    Library.OpenedFrames[KeyContextMenu] = nil
                    KeyContextMenu.Visible = false
                end

                function Keybind:SetValue(Value)

                end

                function Keybind:SetMode(Value)
                    Keybind.Mode = Value
                end


                KeybindButton.MouseButton1Down:Connect(function()
                    if Keybind.Listening then return end
                    Keybind.Listening = true
                    Keybind.Text = "[...]"
                end)

                KeybindButton.MouseButton2Down:Connect(function()
                    Keybind:Show()
                end)

                if Info.Mode == "Always" then
                    Keybind.Active = true
                    Keybind.Callback(true)
                end

                Options[GetIdx(Info.Name)] = Keybind
                return Keybind
            end

            function SectionFunctions:Input(Info)
                Info.Placeholder = Info.Placeholder or "type something..."
                Info.Default = Info.Default or ""

                local InputLabel = New("TextLabel", {
                    
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 40),
                    FontFace = Library.Font,
                    TextSize = 14,
                    TextColor3 = Library.TextColor,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    Text = Info.Name,
                    Parent = SectionComponents
                })

                AddToRegistry(InputLabel, {TextColor3 = "TextColor"})

                local InputBox = New("TextBox", {
                    AnchorPoint = Vector2.new(0, 1),
                    Position = UDim2.fromScale(0, 1),
                    Size = UDim2.new(1, 0, 0, 20),
                    BackgroundColor3 = Library.BackgroundColor,
                    BorderColor3 = Library.StrokeColor,
                    PlaceholderColor3 = Library.DeselectedColor,
                    TextColor3 = Library.TextColor,
                    FontFace = Library.Font,
                    ClipsDescendants = true,
                    TextSize = 14,
                    Text = Info.Default,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    PlaceholderText = Info.Placeholder,
                    Parent = InputLabel
                }) ApplyPadding(InputBox, {L=4, R=4})

                AddToRegistry(InputBox, {
                    BackgroundColor3 = "BackgroundColor",
                    BorderColor3 = "StrokeColor",
                    PlaceholderColor3 = "DeselectedColor",
                    TextColor3 = "TextColor"
                })

                local Input = {
                    Value = Info.Default,
                    Type = "Input",
                    Callback = Info.Callback
                }

                function Input:SetValue(Value)
                    Input.Value = Value
                    InputBox.Text = Value
                    Input.Callback(Value)
                end

                local LastInput = Info.Default

                InputBox.Focused:Connect(function() InputBox.PlaceholderText = "" end)
                InputBox.FocusLost:Connect(function()
                    InputBox.PlaceholderText = Info.Placeholder

                    if InputBox.Text ~= LastInput then
                        Input:SetValue(InputBox.Text)
                    end

                    LastInput = InputBox.Text
                end)

                Input:SetValue(Info.Default)

                Options[GetIdx(Info.Name)] = Input
                return Input
            end

            function SectionFunctions:Colorpicker(Info)
                Info.Default = Options.Default or Color3.fromRGB(255, 255, 255)

                local Colorpicker = {
                    Value = Info.Default,
                    AValue = Info.DefaultTransparency,
                    Type = "Colorpicker",
                    Callback = Info.Callback
                }

                -- Not finished yet

                Options[GetIdx(Info.Name)] = Colorpicker
                return Colorpicker
            end

            return SectionFunctions
        end

        return TabFunctions
    end

    return WindowFunctions
end

function Library:Notify(Text, Type, Duration)
    Duration = Duration or 5
    local Idx = #Notifications:GetChildren() + 1

    local Notification = New("TextLabel", {
        BackgroundColor3 = Library.BackgroundColor,

        BorderColor3 = Type == "Success" and Color3.fromRGB(100, 240, 100) or
        Type == "Warning" and Color3.fromRGB(240, 240, 100) or
        Type == "Error" and Color3.fromRGB(240, 100, 100) or
        Library.AccentColor,

        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(1, 0, 1, -(38 * Idx)),
        FontFace = Library.Font,
        TextColor3 = Library.TextColor,
        TextSize = 14,
        Text = Text,
        Parent = Notifications
    }) ApplyPadding(Notification, {L=8, R=8})
    Notification.Size = UDim2.fromOffset(Notification.TextBounds.X + 16, 30)
    local Stroke = ApplyStroke(Notification).Parent
    Stroke.Position = UDim2.fromOffset(-9, -1)
    Stroke.Size = UDim2.new(1, 18, 1, 2)

    TweenService:Create(Notification, NotifTweenInfo, {AnchorPoint = Vector2.new(1, 1)}):Play()

    task.delay(Duration, function()
        local Tween = TweenService:Create(Notification, NotifTweenInfo, {AnchorPoint = Vector2.new(0, 1)})
        Tween:Play()
        Tween.Completed:Once(function()
            Notification:Destroy()
        end)
    end)
end

function Library:ConfigManager(Window)
    local SettingsTab = Window:Tab("settings")
    local UISection = SettingsTab:Section("interface")
    local ConfigSection = SettingsTab:Section("configuration")

    if not isfolder(`moehook/configs/{game.PlaceId}`) then
        makefolder(`moehook/configs/{game.PlaceId}`)
    end

    local ConfigFolder = `moehook/configs/{game.PlaceId}`
    local AutoloadPath = `moehook/configs/{game.PlaceId}/autoload.txt`
    
    local CurrentConfigName = ""
    local SelectedConfig = nil
    
    local function GetConfigList()
        if not isfolder(ConfigFolder) then makefolder(ConfigFolder) end
        local Files = listfiles(ConfigFolder)
        local Names = {}

        for _, File in ipairs(Files) do
            if File:sub(-5) == ".json" then
                local Name = File:match("[^\\/]+$")
                table.insert(Names, Name:sub(1, -6))
            end
        end

        return #Names > 0 and Names or {"None"}
    end

    local function GetAutoloadName()
        return isfile(AutoloadPath) and readfile(AutoloadPath) or "none"
    end

    local function SaveConfig(Name)
        if not Name or Name == "" or Name == "None" then
            Library:Notify("Invalid config name", "Error")
            return
        end
        local Data = {}
        for Idx, Option in next, Options do
            if Idx ~= "configs" and Option.Value ~= nil then
                Data[Idx] = Option.Value
            end
        end
        writefile(`{ConfigFolder}/{Name}.json`, HttpService:JSONEncode(Data))
        Library:Notify(`saved config: {Name}`, "Success")
    end

    local function LoadConfig(Name)
        local Path = `{ConfigFolder}/{Name}.json`
        if not isfile(Path) then
            Library:Notify("Config file not found", "Error")
            return
        end

        local Success, Decoded = pcall(HttpService.JSONDecode, HttpService, readfile(Path))

        if not Success then
            Library:Notify("Failed to decode JSON", "Error")
            return
        end

        for Idx, Value in next, Decoded do
            local Option = Options[Idx]
            if Option and Idx ~= "configs" then
                if Option.SetState then Option:SetState(Value)
                elseif Option.SetValue then Option:SetValue(Value)
                end
            end
        end

        Library:Notify(`Config '{Name}' loaded`, "Success")
    end

    local function DeleteConfig(Name)
        local Path = `{ConfigFolder}/{Name}.json`
        if isfile(Path) then
            delfile(Path)
            Library:Notify(`Config '{Name}' deleted`, "Success")
        end
    end

    local ConfigDropdown = ConfigSection:Dropdown({
        Name = "configs",
        Values = GetConfigList(),
        Default = "None",
        Callback = function(Val)
            SelectedConfig = Val
        end
    })

    ConfigSection:Input({
        Name = "name",
        Placeholder = "config name",
        Callback = function(Val)
            CurrentConfigName = Val
        end
    })

    ConfigSection:Button("create", function()
        if CurrentConfigName ~= "" then
            SaveConfig(CurrentConfigName)
            local NewValues = GetConfigList()
            ConfigDropdown:SetValues(NewValues)
            ConfigDropdown:SetValue(CurrentConfigName)
        end
    end)

    ConfigSection:Button("save", function()
        if SelectedConfig and SelectedConfig ~= "None" then
            SaveConfig(SelectedConfig)
        else
            Library:Notify("Select a config first", "Error")
        end
    end)

    ConfigSection:Button("load", function()
        if SelectedConfig and SelectedConfig ~= "None" then
            LoadConfig(SelectedConfig)
        else
            Library:Notify("Select a config first", "Error")
        end
    end)

    ConfigSection:Button("delete", function()
        if SelectedConfig and SelectedConfig ~= "None" then
            DeleteConfig(SelectedConfig)
            local NewValues = GetConfigList()
            ConfigDropdown:SetValues(NewValues)
            ConfigDropdown:SetValue(NewValues[1] or "None")
        else
            Library:Notify("Select a config first", "Error")
        end
    end)

    ConfigSection:Button("refresh", function()
        local NewValues = GetConfigList()
        ConfigDropdown:SetValues(NewValues)
        ConfigDropdown:SetValue(NewValues[1] or "None")
    end)

    local AutoloadLabel = ConfigSection:Label(`current autoload: {GetAutoloadName()}`)

    ConfigSection:Button("set as autoload", function()
        if SelectedConfig and SelectedConfig ~= "None" then
            writefile(AutoloadPath, SelectedConfig)
            AutoloadLabel:SetValue(`current autoload: <font color="#B48EAD">{SelectedConfig}</font>`)
            Library:Notify(`Set autoload to: {SelectedConfig}`, "Success")
        else
            Library:Notify("Select a config first", "Error")
        end
    end)

    --

    if isfile(AutoloadPath) then
        local AutoName = readfile(AutoloadPath)
        if isfile(`{ConfigFolder}/{AutoName}.json`) then
            task.delay(0.1, function()
                LoadConfig(AutoName)
                ConfigDropdown:SetValue(AutoName)
            end)
        end
    end
end

-- // Init
if shared.MoeDebug then
    Library:Notify(string.format("Loaded in %.2f seconds!", os.clock() - StartTime), "Success")
end

shared.MoeLibrary = Library
return Library
