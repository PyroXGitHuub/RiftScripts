-- ==========================================
-- 1. VORBEREITUNG & SETUP
-- ==========================================

-- HIER DEN LINK ZUR RAW-DATEI DER BIBLIOTHEK EINTRAGEN
local gui_link = "https://raw.githubusercontent.com/PyroXGitHuub/MyCode/refs/heads/main/Gui_Libary/GUI_Libary.lua"
local Library = loadstring(game:HttpGet(gui_link))()

local ConfigFolderName = "Example"
Library.ConfigFolder = ConfigFolderName

local ThemeColor = Color3.fromRGB(0, 150, 255)
local MyWindow = Library.New("Example GUI", ThemeColor)

-- Tabs erstellen 
local Tab1 = MyWindow:AddTab("tab 1")
MyWindow:AddTab("tab 2")
MyWindow:AddTab("tab 3")
MyWindow:AddTab("tab 4")

-- Sub-Tabs für Tab 1 erstellen
local Sub1 = Tab1:AddSubTab("Sub Tab 1")
local Sub2 = Tab1:AddSubTab("Sub Tab 2")
local Sub3 = Tab1:AddSubTab("Sub Tab 3")
local Sub4 = Tab1:AddSubTab("Sub Tab 4")
local Sub5 = Tab1:AddSubTab("Sub Tab 5")

-- ================= SHOWCASE (MIT CONFIG-TABLES) ================= --

Sub1:AddToggle({
    Name = "Toggel Button",
    Default = false,
    Callback = function(v)
        print("Toggle changed to:", v)
    end
})

Sub1:AddSlider({
    Name = "Set Value",
    Min = 0,
    Max = 100,
    Default = 25,
    Callback = function(v)
        print("Slider value:", v)
    end
})

Sub1:AddKeybind({
    Name = "Set Key",
    Key = Enum.KeyCode.E,
    Callback = function(key)
        print("Key pressed:", key.Name)
    end
})

Sub1:AddDropdown({
    Name = "Set Methode",
    Options = {"1", "2", "3", "4"},
    Default = "1",
    Callback = function(opt)
        print("Method selected:", opt)
    end
})

-- Filter Button in Variable speichern
local FilterBtn = Sub1:AddFilterButton({
    Name = "Set Filter",
    Callback = function()
        print("Filter panel toggled!")
    end
})

Sub1:AddColorPicker({
    Name = "Set Color",
    Default = Color3.fromRGB(255, 255, 255),
    Callback = function(col)
        print("Color selected:", col)
    end
})

Sub1:AddToggleWithKey({
    Name = "Toggel Button With Set key",
    Default = false,
    Key = Enum.KeyCode.F,
    Callback = function(v)
        print("Toggle with key state:", v)
    end
})

Sub1:AddDropdown({
    Name = "Drop Down Multi",
    Options = {"Option A", "Option B", "Option C"},
    MultiSelect = true,
    Callback = function(optTable)
        for k, v in pairs(optTable) do
            if v then print("Multi-Select active:", k) end
        end
    end
})

Sub1:AddTextBox({
    Name = "Text Field",
    Placeholder = "Enter Text...",
    Callback = function(text, enterPressed)
        print("Text entered:", text)
    end
})

Sub1:AddButton({
    Name = "Simple Button",
    Callback = function()
        print("Simple button clicked!")
    end
})

-- Filter Items über die Variable FilterBtn hinzufügen
for i = 1, 10 do
    FilterBtn:AddItem({
        Name = "Loot_Item " .. i,
        Default = false,
        Callback = function(state)
            print("Filter Item " .. i .. " is:", state)
        end
    })
end
