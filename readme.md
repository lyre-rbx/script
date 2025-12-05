# Socials
Join our Discord server! https://discord.gg/5KHc2rpVc9

# Script
```lua
loadstring(game:HttpGet("https://moehook.github.io"))()
```

# Library example script
```lua
-- // Library
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/moehook/script/beta/library.luau"), "moehook library")()

-- // Window
local Window = Library:Window("v1.0.0") -- Passes in the version, don't use any names!

-- // Tab
local PreviewTab = Window:Tab("preview")

-- // Sections
local Section1 = PreviewTab:Section("example")
local Section2 = PreviewTab:Section("dropdowns")

-- // Label
local Label = Section1:Label("this is a label!\nwhich allows multi-lines")

-- // Button
Section1:Button("press me", function()
    local Number = tostring(math.random(1, 99))
    Label:SetValue(`cool number: {Number}`)
    Library:Notify(`The cool number is {Number}.`)
end)

-- // Toggle
local Toggle = Section1:Toggle("toggle me", function(Value)
    print(`Toggle value is now {Value}`)
end, true) -- Defaults to false

-- // Input
Section1:Input{
    Name = "your name",
    Placeholder = "enter your name...", -- Defaults to "type something..."
    Default = game.Players.LocalPlayer.Name, -- Defaults to ""
    Callback = function(Name)
        print(`Your name is: {Name}`)

        if Name == "secret name wow" then
            Toggle:SetValue(true)
        end
    end
}

-- // Colorpicker
Section1:Colorpicker{
    Name = "accent color",
    Default = Library.AccentColor, -- Defaults to Color3.new(1, 1, 1)
    Callback = function(Color)
        Library.AccentColor = Color
        Library:UpdateColors()
    end
}

-- // Keybind
Section1:Keybind{
    Name = "keybind",
    Default = Enum.KeyCode.J,
    Mode = "Hold", -- "Hold", "Toggle", "Always". Defaults to "Toggle".
    Callback = function(Value)
        print(`Keybind changed to {Value}`)
    end,
    ChangedCallback = function(Key)
        print(`new key: {Key}`)
    end
}

-- // Non-multi dropdown
Section2:Dropdown{
    Name = "non multi dropdown",
    Values = {"option1", "option2", "option3", "option4"},
    Default = "option1", -- To make the dropdown multi-selectable, make this a table instead of a string. Defaults to ""
    Callback = function(Option)
        print(`Option is now {Option}`)
    end
}

-- // Multi dropdown
Section2:Dropdown{
    Name = "multi dropdown",
    Values = {"option1", "option2", "option3", "option4"},
    Default = {"option1", "option3"},
    Callback = function(Options)
        print(`New options: {table.concat(Options, ", ")}`)
    end
}

local DropdownMade = false
local BigTable = {}

for Idx = 1, 100 do
    table.insert(BigTable, `option {Idx}`)
end

-- // Big dropdown
Section2:Button("biiig dropdown", function()
    if DropdownMade then return end
    DropdownMade = true

    Section2:Dropdown{
        Name = "huge dropdown",
        Values = BigTable,
        Default = {"option1", "option2"},
        Callback = function() end
    }
end)

-- // Notification
Library:Notify("Library example loaded what's up", "Success") -- "Info", "Success", "Warn", "Error". Defaults to "Info"
-- // Settings tab
Library:ConfigManager(Window)
```
