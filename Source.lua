-- Linoria-style UI Library for Roblox
-- By: YourNameHere

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local Library = {
    Windows = {},
    Dragging = nil,
    Resizing = nil,
    Open = true,
    Theme = {},
    Flags = {},
    ConfigFolder = "UI_Library_Configs",
    Notifications = {}
}

-- Utility functions
local function Create(className, properties)
    local instance = Instance.new(className)
    for property, value in pairs(properties) do
        instance[property] = value
    end
    return instance
end

local function Tween(instance, properties, duration, ...)
    local tweenInfo = TweenInfo.new(duration, ...)
    local tween = TweenService:Create(instance, tweenInfo, properties)
    tween:Play()
    return tween
end

local function MapValue(value, inMin, inMax, outMin, outMax)
    return (value - inMin) * (outMax - outMin) / (inMax - inMin) + outMin
end

local function Round(number, decimalPlaces)
    decimalPlaces = decimalPlaces or 0
    local multiplier = 10 ^ decimalPlaces
    return math.floor(number * multiplier + 0.5) / multiplier
end

local function FormatNumber(number)
    if number >= 1000000 then
        return string.format("%.1fM", number / 1000000)
    elseif number >= 1000 then
        return string.format("%.1fK", number / 1000)
    else
        return tostring(number)
    end
end

-- Color conversion functions
local function RGBToHSV(r, g, b)
    r, g, b = r / 255, g / 255, b / 255
    local max, min = math.max(r, g, b), math.min(r, g, b)
    local h, s, v
    v = max

    local d = max - min
    s = max == 0 and 0 or d / max

    if max == min then
        h = 0
    else
        if max == r then
            h = (g - b) / d + (g < b and 6 or 0)
        elseif max == g then
            h = (b - r) / d + 2
        elseif max == b then
            h = (r - g) / d + 4
        end
        h = h / 6
    end

    return h, s, v
end

local function HSVToRGB(h, s, v)
    local r, g, b

    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)

    i = i % 6

    if i == 0 then
        r, g, b = v, t, p
    elseif i == 1 then
        r, g, b = q, v, p
    elseif i == 2 then
        r, g, b = p, v, t
    elseif i == 3 then
        r, g, b = p, q, v
    elseif i == 4 then
        r, g, b = t, p, v
    elseif i == 5 then
        r, g, b = v, p, q
    end

    return r * 255, g * 255, b * 255
end

-- Default theme
Library.DefaultTheme = {
    Background = Color3.fromRGB(24, 24, 24),
    Foreground = Color3.fromRGB(31, 31, 31),
    Accent = Color3.fromRGB(0, 120, 215),
    LightContrast = Color3.fromRGB(36, 36, 36),
    DarkContrast = Color3.fromRGB(19, 19, 19),
    TextColor = Color3.fromRGB(255, 255, 255),
    SubTextColor = Color3.fromRGB(180, 180, 180),
    Highlight = Color3.fromRGB(40, 40, 40),
    Border = Color3.fromRGB(12, 12, 12)
}

-- Apply default theme
for key, value in pairs(Library.DefaultTheme) do
    Library.Theme[key] = value
end

-- Main screen GUI
Library.ScreenGui = Create("ScreenGui", {
    Name = "UILibrary",
    Parent = CoreGui,
    ZIndexBehavior = Enum.ZIndexBehavior.Global
})

-- Notification handler
function Library:SendNotification(title, content, duration)
    duration = duration or 5
    
    local notification = {
        Title = title,
        Content = content,
        Duration = duration,
        Time = tick()
    }
    
    table.insert(self.Notifications, notification)
    
    if not self.NotificationHandler then
        self.NotificationHandler = RunService.RenderStepped:Connect(function()
            self:UpdateNotifications()
        end)
    end
    
    return notification
end

function Library:UpdateNotifications()
    local currentTime = tick()
    local toRemove = {}
    
    for i, notification in ipairs(self.Notifications) do
        if currentTime - notification.Time >= notification.Duration then
            table.insert(toRemove, i)
        end
    end
    
    for i = #toRemove, 1, -1 do
        table.remove(self.Notifications, toRemove[i])
    end
    
    if #self.Notifications == 0 and self.NotificationHandler then
        self.NotificationHandler:Disconnect()
        self.NotificationHandler = nil
    end
end

-- Config system
function Library:SaveConfig(name)
    local config = {
        Theme = self.Theme,
        Flags = self.Flags
    }
    
    local json = HttpService:JSONEncode(config)
    
    if not isfolder(self.ConfigFolder) then
        makefolder(self.ConfigFolder)
    end
    
    writefile(self.ConfigFolder .. "/" .. name .. ".json", json)
    
    return self:SendNotification("Config Saved", "Config '" .. name .. "' has been saved.", 3)
end

function Library:LoadConfig(name)
    if not isfolder(self.ConfigFolder) then
        return self:SendNotification("Error", "Config folder not found.", 3)
    end
    
    local success, result = pcall(function()
        return readfile(self.ConfigFolder .. "/" .. name .. ".json")
    end)
    
    if not success then
        return self:SendNotification("Error", "Config '" .. name .. "' not found.", 3)
    end
    
    local config = HttpService:JSONDecode(result)
    
    for key, value in pairs(config.Theme) do
        self.Theme[key] = Color3.new(value.R, value.G, value.B)
    end
    
    for flag, value in pairs(config.Flags) do
        if self.Flags[flag] ~= nil then
            self.Flags[flag] = value
        end
    end
    
    -- Update all elements with new flag values
    for _, window in ipairs(self.Windows) do
        window:UpdateAllFlags()
    end
    
    return self:SendNotification("Config Loaded", "Config '" .. name .. "' has been loaded.", 3)
end

function Library:GetConfigs()
    if not isfolder(self.ConfigFolder) then
        return {}
    end
    
    local files = listfiles(self.ConfigFolder)
    local configs = {}
    
    for _, file in ipairs(files) do
        if string.sub(file, -5) == ".json" then
            table.insert(configs, string.match(file, "([^/]+)%.json$"))
        end
    end
    
    return configs
end

-- Theme system
function Library:SaveTheme(name)
    local themes = self:GetThemes()
    themes[name] = self.Theme
    
    local json = HttpService:JSONEncode(themes)
    
    if not isfolder(self.ConfigFolder) then
        makefolder(self.ConfigFolder)
    end
    
    writefile(self.ConfigFolder .. "/themes.json", json)
    
    return self:SendNotification("Theme Saved", "Theme '" .. name .. "' has been saved.", 3)
end

function Library:LoadTheme(name)
    if not isfolder(self.ConfigFolder) then
        return self:SendNotification("Error", "Config folder not found.", 3)
    end
    
    local success, result = pcall(function()
        return readfile(self.ConfigFolder .. "/themes.json")
    end)
    
    if not success then
        return self:SendNotification("Error", "Themes file not found.", 3)
    end
    
    local themes = HttpService:JSONDecode(result)
    
    if not themes[name] then
        return self:SendNotification("Error", "Theme '" .. name .. "' not found.", 3)
    end
    
    for key, value in pairs(themes[name]) do
        self.Theme[key] = Color3.new(value.R, value.G, value.B)
    end
    
    -- Update all UI elements with new theme
    for _, window in ipairs(self.Windows) do
        window:UpdateTheme()
    end
    
    return self:SendNotification("Theme Loaded", "Theme '" .. name .. "' has been loaded.", 3)
end

function Library:GetThemes()
    if not isfolder(self.ConfigFolder) then
        return {}
    end
    
    local success, result = pcall(function()
        return readfile(self.ConfigFolder .. "/themes.json")
    end)
    
    if not success then
        return {}
    end
    
    return HttpService:JSONDecode(result) or {}
end

-- Window class
local Window = {}
Window.__index = Window

function Window.new(title, size, position, options)
    options = options or {}
    local self = setmetatable({}, Window)
    
    self.Title = title or "Window"
    self.Size = size or Vector2.new(500, 600)
    self.Position = position or Vector2.new(100, 100)
    self.Visible = true
    self.Tabs = {}
    self.ActiveTab = nil
    self.MinSize = options.MinSize or Vector2.new(300, 400)
    
    -- Create main frame
    self.Main = Create("Frame", {
        Name = title .. "Window",
        Parent = Library.ScreenGui,
        Size = UDim2.new(0, self.Size.X, 0, self.Size.Y),
        Position = UDim2.new(0, self.Position.X, 0, self.Position.Y),
        BackgroundColor3 = Library.Theme.Background,
        BorderColor3 = Library.Theme.Border,
        BorderSizePixel = 1,
        ClipsDescendants = true,
        ZIndex = 1
    })
    
    -- Title bar
    self.TitleBar = Create("Frame", {
        Name = "TitleBar",
        Parent = self.Main,
        Size = UDim2.new(1, 0, 0, 30),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Library.Theme.Foreground,
        BorderSizePixel = 0,
        ZIndex = 2
    })
    
    self.TitleText = Create("TextLabel", {
        Name = "TitleText",
        Parent = self.TitleBar,
        Size = UDim2.new(1, -60, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = self.Title,
        TextColor3 = Library.Theme.TextColor,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.Gotham,
        TextSize = 14,
        ZIndex = 3
    })
    
    -- Close button
    self.CloseButton = Create("TextButton", {
        Name = "CloseButton",
        Parent = self.TitleBar,
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -30, 0, 0),
        BackgroundTransparency = 1,
        Text = "X",
        TextColor3 = Library.Theme.TextColor,
        Font = Enum.Font.Gotham,
        TextSize = 14,
        ZIndex = 3
    })
    
    self.CloseButton.MouseButton1Click:Connect(function()
        self:SetVisible(not self.Visible)
    end)
    
    -- Tab container
    self.TabContainer = Create("Frame", {
        Name = "TabContainer",
        Parent = self.Main,
        Size = UDim2.new(1, -20, 0, 30),
        Position = UDim2.new(0, 10, 0, 35),
        BackgroundTransparency = 1,
        ZIndex = 2
    })
    
    self.TabListLayout = Create("UIListLayout", {
        Parent = self.TabContainer,
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 5)
    })
    
    -- Content container
    self.ContentContainer = Create("ScrollingFrame", {
        Name = "ContentContainer",
        Parent = self.Main,
        Size = UDim2.new(1, -20, 1, -70),
        Position = UDim2.new(0, 10, 0, 70),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 5,
        ScrollBarImageColor3 = Library.Theme.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ZIndex = 2
    })
    
    self.ContentLayout = Create("UIListLayout", {
        Parent = self.ContentContainer,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 5)
    })
    
    self.ContentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        self.ContentContainer.CanvasSize = UDim2.new(0, 0, 0, self.ContentLayout.AbsoluteContentSize.Y)
    end)
    
    -- Resize handle
    self.ResizeHandle = Create("Frame", {
        Name = "ResizeHandle",
        Parent = self.Main,
        Size = UDim2.new(0, 10, 0, 10),
        Position = UDim2.new(1, -10, 1, -10),
        BackgroundColor3 = Library.Theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 2
    })
    
    -- Set up dragging
    self.TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Library.Dragging = {
                Window = self,
                Start = input.Position,
                Position = self.Main.Position
            }
        end
    end)
    
    -- Set up resizing
    self.ResizeHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Library.Resizing = {
                Window = self,
                Start = input.Position,
                Size = self.Main.Size
            }
        end
    end)
    
    table.insert(Library.Windows, self)
    return self
end

function Window:SetVisible(visible)
    self.Visible = visible
    self.Main.Visible = visible
    
    if visible then
        -- Bring to front
        for _, window in ipairs(Library.Windows) do
            window.Main.ZIndex = 1
        end
        self.Main.ZIndex = 10
    end
end

function Window:AddTab(name)
    local tab = {
        Name = name,
        Window = self,
        Sections = {},
        Container = nil
    }
    
    -- Tab button
    tab.Button = Create("TextButton", {
        Name = name .. "TabButton",
        Parent = self.TabContainer,
        Size = UDim2.new(0, 80, 1, 0),
        BackgroundColor3 = Library.Theme.Foreground,
        BorderSizePixel = 0,
        Text = name,
        TextColor3 = Library.Theme.TextColor,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        ZIndex = 3,
        AutoButtonColor = false
    })
    
    -- Tab content
    tab.Container = Create("Frame", {
        Name = name .. "TabContent",
        Parent = self.ContentContainer,
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = 2
    })
    
    tab.ContainerLayout = Create("UIListLayout", {
        Parent = tab.Container,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 10)
    })
    
    tab.ContainerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        tab.Container.Size = UDim2.new(1, 0, 0, tab.ContainerLayout.AbsoluteContentSize.Y)
    end)
    
    -- Tab button click event
    tab.Button.MouseButton1Click:Connect(function()
        self:SelectTab(tab)
    end)
    
    -- Set as active if first tab
    if #self.Tabs == 0 then
        self:SelectTab(tab)
    end
    
    table.insert(self.Tabs, tab)
    return tab
end

function Window:SelectTab(tab)
    -- Hide all tab contents
    for _, t in ipairs(self.Tabs) do
        t.Container.Visible = false
        t.Button.BackgroundColor3 = Library.Theme.Foreground
        t.Button.TextColor3 = Library.Theme.TextColor
    end
    
    -- Show selected tab content
    tab.Container.Visible = true
    tab.Button.BackgroundColor3 = Library.Theme.Accent
    tab.Button.TextColor3 = Color3.new(1, 1, 1)
    
    self.ActiveTab = tab
end

function Window:AddSection(tab, name, side)
    side = side or "Left"
    
    local section = {
        Name = name,
        Tab = tab,
        Elements = {},
        Container = nil
    }
    
    -- Section container
    section.Container = Create("Frame", {
        Name = name .. "Section",
        Parent = tab.Container,
        Size = UDim2.new(0.5, -5, 0, 0),
        BackgroundTransparency = 1,
        LayoutOrder = #tab.Sections + 1,
        ZIndex = 2
    })
    
    if side == "Full" then
        section.Container.Size = UDim2.new(1, 0, 0, 0)
    end
    
    section.ContainerLayout = Create("UIListLayout", {
        Parent = section.Container,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 5)
    })
    
    section.ContainerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        section.Container.Size = UDim2.new(section.Container.Size.X.Scale, section.Container.Size.X.Offset, 0, section.ContainerLayout.AbsoluteContentSize.Y)
    end)
    
    -- Section title
    section.Title = Create("TextLabel", {
        Name = "Title",
        Parent = section.Container,
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = Library.Theme.TextColor,
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3
    })
    
    table.insert(tab.Sections, section)
    return section
end

function Window:UpdateTheme()
    self.Main.BackgroundColor3 = Library.Theme.Background
    self.Main.BorderColor3 = Library.Theme.Border
    self.TitleBar.BackgroundColor3 = Library.Theme.Foreground
    self.TitleText.TextColor3 = Library.Theme.TextColor
    self.CloseButton.TextColor3 = Library.Theme.TextColor
    self.ContentContainer.ScrollBarImageColor3 = Library.Theme.Accent
    self.ResizeHandle.BackgroundColor3 = Library.Theme.Accent
    
    for _, tab in ipairs(self.Tabs) do
        tab.Button.BackgroundColor3 = self.ActiveTab == tab and Library.Theme.Accent or Library.Theme.Foreground
        tab.Button.TextColor3 = self.ActiveTab == tab and Color3.new(1, 1, 1) or Library.Theme.TextColor
        
        for _, section in ipairs(tab.Sections) do
            section.Title.TextColor3 = Library.Theme.TextColor
            
            for _, element in ipairs(section.Elements) do
                if element.UpdateTheme then
                    element:UpdateTheme()
                end
            end
        end
    end
end

function Window:UpdateAllFlags()
    for _, tab in ipairs(self.Tabs) do
        for _, section in ipairs(tab.Sections) do
            for _, element in ipairs(section.Elements) do
                if element.UpdateFlag then
                    element:UpdateFlag()
                end
            end
        end
    end
end

-- Element base class
local Element = {}
Element.__index = Element

function Element.new(section, name, flag, callback)
    local self = setmetatable({}, Element)
    
    self.Section = section
    self.Name = name
    self.Flag = flag
    self.Callback = callback
    self.Container = nil
    
    if flag then
        Library.Flags[flag] = Library.Flags[flag] or nil
    end
    
    return self
end

-- Toggle element
local Toggle = setmetatable({}, Element)
Toggle.__index = Toggle

function Toggle.new(section, name, default, flag, callback)
    local self = setmetatable(Element.new(section, name, flag, callback), Toggle)
    
    self.Value = default or false
    self.Toggled = self.Value
    
    if flag then
        Library.Flags[flag] = self.Value
    end
    
    -- Create container
    self.Container = Create("Frame", {
        Name = name .. "Toggle",
        Parent = section.Container,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        LayoutOrder = #section.Elements + 1,
        ZIndex = 3
    })
    
    -- Toggle label
    self.Label = Create("TextLabel", {
        Name = "Label",
        Parent = self.Container,
        Size = UDim2.new(1, -40, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = Library.Theme.TextColor,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4
    })
    
    -- Toggle background
    self.ToggleFrame = Create("Frame", {
        Name = "ToggleFrame",
        Parent = self.Container,
        Size = UDim2.new(0, 30, 0, 15),
        Position = UDim2.new(1, -30, 0.5, -7.5),
        BackgroundColor3 = Library.Theme.Foreground,
        BorderSizePixel = 0,
        ZIndex = 4
    })
    
    self.ToggleCorner = Create("UICorner", {
        Parent = self.ToggleFrame,
        CornerRadius = UDim.new(0, 7)
    })
    
    -- Toggle button
    self.ToggleButton = Create("Frame", {
        Name = "ToggleButton",
        Parent = self.ToggleFrame,
        Size = UDim2.new(0, 11, 0, 11),
        Position = UDim2.new(0, 2, 0, 2),
        BackgroundColor3 = Library.Theme.TextColor,
        BorderSizePixel = 0,
        ZIndex = 5
    })
    
    self.ButtonCorner = Create("UICorner", {
        Parent = self.ToggleButton,
        CornerRadius = UDim.new(0, 5)
    })
    
    -- Set initial state
    self:SetValue(self.Value)
    
    -- Click event
    self.ToggleFrame.MouseButton1Click:Connect(function()
        self:SetValue(not self.Value)
    end)
    
    self.Label.MouseButton1Click:Connect(function()
        self:SetValue(not self.Value)
    end)
    
    table.insert(section.Elements, self)
    return self
end

function Toggle:SetValue(value, silent)
    self.Value = value
    
    if self.Flag then
        Library.Flags[self.Flag] = self.Value
    end
    
    if value then
        Tween(self.ToggleButton, {Position = UDim2.new(0, 17, 0, 2)}, 0.2)
        Tween(self.ToggleFrame, {BackgroundColor3 = Library.Theme.Accent}, 0.2)
    else
        Tween(self.ToggleButton, {Position = UDim2.new(0, 2, 0, 2)}, 0.2)
        Tween(self.ToggleFrame, {BackgroundColor3 = Library.Theme.Foreground}, 0.2)
    end
    
    if not silent and self.Callback then
        self.Callback(self.Value)
    end
end

function Toggle:UpdateTheme()
    self.Label.TextColor3 = Library.Theme.TextColor
    self.ToggleFrame.BackgroundColor3 = self.Value and Library.Theme.Accent or Library.Theme.Foreground
    self.ToggleButton.BackgroundColor3 = Library.Theme.TextColor
end

function Toggle:UpdateFlag()
    if self.Flag and Library.Flags[self.Flag] ~= nil then
        self:SetValue(Library.Flags[self.Flag], true)
    end
end

-- Slider element
local Slider = setmetatable({}, Element)
Slider.__index = Slider

function Slider.new(section, name, min, max, default, flag, callback, options)
    options = options or {}
    local self = setmetatable(Element.new(section, name, flag, callback), Slider)
    
    self.Min = min or 0
    self.Max = max or 100
    self.Value = default or min
    self.Precision = options.Precision or 0
    self.Suffix = options.Suffix or ""
    
    if flag then
        Library.Flags[flag] = self.Value
    end
    
    -- Create container
    self.Container = Create("Frame", {
        Name = name .. "Slider",
        Parent = section.Container,
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundTransparency = 1,
        LayoutOrder = #section.Elements + 1,
        ZIndex = 3
    })
    
    -- Slider label
    self.Label = Create("TextLabel", {
        Name = "Label",
        Parent = self.Container,
        Size = UDim2.new(1, 0, 0, 15),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = Library.Theme.TextColor,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4
    })
    
    -- Value label
    self.ValueLabel = Create("TextLabel", {
        Name = "ValueLabel",
        Parent = self.Container,
        Size = UDim2.new(1, 0, 0, 15),
        Position = UDim2.new(0, 0, 0, 15),
        BackgroundTransparency = 1,
        Text = tostring(self.Value) .. self.Suffix,
        TextColor3 = Library.Theme.SubTextColor,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 4
    })
    
    -- Slider track
    self.Track = Create("Frame", {
        Name = "Track",
        Parent = self.Container,
        Size = UDim2.new(1, 0, 0, 5),
        Position = UDim2.new(0, 0, 0, 35),
        BackgroundColor3 = Library.Theme.Foreground,
        BorderSizePixel = 0,
        ZIndex = 4
    })
    
    self.TrackCorner = Create("UICorner", {
        Parent = self.Track,
        CornerRadius = UDim.new(0, 2)
    })
    
    -- Slider fill
    self.Fill = Create("Frame", {
        Name = "Fill",
        Parent = self.Track,
        Size = UDim2.new(0, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Library.Theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 5
    })
    
    self.FillCorner = Create("UICorner", {
        Parent = self.Fill,
        CornerRadius = UDim.new(0, 2)
    })
    
    -- Slider button
    self.Button = Create("TextButton", {
        Name = "Button",
        Parent = self.Track,
        Size = UDim2.new(0, 15, 0, 15),
        Position = UDim2.new(0, 0, 0.5, -7.5),
        BackgroundColor3 = Library.Theme.TextColor,
        BorderSizePixel = 0,
        Text = "",
        ZIndex = 6
    })
    
    self.ButtonCorner = Create("UICorner", {
        Parent = self.Button,
        CornerRadius = UDim.new(0, 7)
    })
    
    -- Set initial value
    self:SetValue(self.Value, true)
    
    -- Drag event
    local dragging = false
    
    self.Button.MouseButton1Down:Connect(function()
        dragging = true
        
        local connection
        connection = RunService.RenderStepped:Connect(function()
            if not dragging then
                connection:Disconnect()
                return
            end
            
            local mousePos = UserInputService:GetMouseLocation()
            local trackPos = self.Track.AbsolutePosition
            local trackSize = self.Track.AbsoluteSize
            
            local relativeX = math.clamp(mousePos.X - trackPos.X, 0, trackSize.X)
            local value = MapValue(relativeX, 0, trackSize.X, self.Min, self.Max)
            
            if self.Precision > 0 then
                value = Round(value, self.Precision)
            else
                value = math.floor(value)
            end
            
            self:SetValue(value)
        end)
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    table.insert(section.Elements, self)
    return self
end

function Slider:SetValue(value, silent)
    value = math.clamp(value, self.Min, self.Max)
    self.Value = value
    
    if self.Flag then
        Library.Flags[self.Flag] = self.Value
    end
    
    local percentage = (value - self.Min) / (self.Max - self.Min)
    self.Fill.Size = UDim2.new(percentage, 0, 1, 0)
    self.Button.Position = UDim2.new(percentage, -7.5, 0.5, -7.5)
    
    self.ValueLabel.Text = tostring(self.Value) .. self.Suffix
    
    if not silent and self.Callback then
        self.Callback(self.Value)
    end
end

function Slider:UpdateTheme()
    self.Label.TextColor3 = Library.Theme.TextColor
    self.ValueLabel.TextColor3 = Library.Theme.SubTextColor
    self.Track.BackgroundColor3 = Library.Theme.Foreground
    self.Fill.BackgroundColor3 = Library.Theme.Accent
    self.Button.BackgroundColor3 = Library.Theme.TextColor
end

function Slider:UpdateFlag()
    if self.Flag and Library.Flags[self.Flag] ~= nil then
        self:SetValue(Library.Flags[self.Flag], true)
    end
end

-- Button element
local Button = setmetatable({}, Element)
Button.__index = Button

function Button.new(section, name, callback)
    local self = setmetatable(Element.new(section, name, nil, callback), Button)
    
    -- Create container
    self.Container = Create("Frame", {
        Name = name .. "Button",
        Parent = section.Container,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        LayoutOrder = #section.Elements + 1,
        ZIndex = 3
    })
    
    -- Button
    self.Button = Create("TextButton", {
        Name = "Button",
        Parent = self.Container,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Library.Theme.Foreground,
        BorderSizePixel = 0,
        Text = name,
        TextColor3 = Library.Theme.TextColor,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        ZIndex = 4
    })
    
    self.ButtonCorner = Create("UICorner", {
        Parent = self.Button,
        CornerRadius = UDim.new(0, 4)
    })
    
    -- Click event
    self.Button.MouseButton1Click:Connect(function()
        if self.Callback then
            self.Callback()
        end
    end)
    
    -- Hover effects
    self.Button.MouseEnter:Connect(function()
        Tween(self.Button, {BackgroundColor3 = Library.Theme.LightContrast}, 0.2)
    end)
    
    self.Button.MouseLeave:Connect(function()
        Tween(self.Button, {BackgroundColor3 = Library.Theme.Foreground}, 0.2)
    end)
    
    table.insert(section.Elements, self)
    return self
end

function Button:UpdateTheme()
    self.Button.BackgroundColor3 = Library.Theme.Foreground
    self.Button.TextColor3 = Library.Theme.TextColor
end

-- Dropdown element
local Dropdown = setmetatable({}, Element)
Dropdown.__index = Dropdown

function Dropdown.new(section, name, options, default, flag, callback)
    local self = setmetatable(Element.new(section, name, flag, callback), Dropdown)
    
    self.Options = options or {}
    self.Value = default or (options and options[1]) or nil
    self.Open = false
    
    if flag then
        Library.Flags[flag] = self.Value
    end
    
    -- Create container
    self.Container = Create("Frame", {
        Name = name .. "Dropdown",
        Parent = section.Container,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        LayoutOrder = #section.Elements + 1,
        ZIndex = 3
    })
    
    -- Dropdown button
    self.Button = Create("TextButton", {
        Name = "Button",
        Parent = self.Container,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = Library.Theme.Foreground,
        BorderSizePixel = 0,
        Text = name .. ": " .. tostring(self.Value),
        TextColor3 = Library.Theme.TextColor,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4
    })
    
    self.ButtonCorner = Create("UICorner", {
        Parent = self.Button,
        CornerRadius = UDim.new(0, 4)
    })
    
    -- Dropdown arrow
    self.Arrow = Create("TextLabel", {
        Name = "Arrow",
        Parent = self.Button,
        Size = UDim2.new(0, 20, 0, 20),
        Position = UDim2.new(1, -25, 0.5, -10),
        BackgroundTransparency = 1,
        Text = "▼",
        TextColor3 = Library.Theme.TextColor,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        ZIndex = 5
    })
    
    -- Options container
    self.OptionsContainer = Create("Frame", {
        Name = "OptionsContainer",
        Parent = self.Container,
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 0, 35),
        BackgroundColor3 = Library.Theme.Foreground,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false,
        ZIndex = 6
    })
    
    self.OptionsCorner = Create("UICorner", {
        Parent = self.OptionsContainer,
        CornerRadius = UDim.new(0, 4)
    })
    
    self.OptionsLayout = Create("UIListLayout", {
        Parent = self.OptionsContainer,
        SortOrder = Enum.SortOrder.LayoutOrder
    })
    
    self.OptionsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if self.Open then
            self.OptionsContainer.Size = UDim2.new(1, 0, 0, self.OptionsLayout.AbsoluteContentSize.Y)
        end
    end)
    
    -- Create option buttons
    for i, option in ipairs(self.Options) do
        local optionButton = Create("TextButton", {
            Name = option .. "Option",
            Parent = self.OptionsContainer,
            Size = UDim2.new(1, 0, 0, 25),
            BackgroundColor3 = Library.Theme.Foreground,
            BorderSizePixel = 0,
            Text = tostring(option),
            TextColor3 = Library.Theme.TextColor,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = i,
            ZIndex = 7
        })
        
        optionButton.Padding = Create("UIPadding", {
            Parent = optionButton,
            PaddingLeft = UDim.new(0, 10)
        })
        
        optionButton.MouseButton1Click:Connect(function()
            self:SetValue(option)
            self:Toggle()
        end)
        
        optionButton.MouseEnter:Connect(function()
            Tween(optionButton, {BackgroundColor3 = Library.Theme.LightContrast}, 0.2)
        end)
        
        optionButton.MouseLeave:Connect(function()
            Tween(optionButton, {BackgroundColor3 = Library.Theme.Foreground}, 0.2)
        end)
    end
    
    -- Toggle event
    self.Button.MouseButton1Click:Connect(function()
        self:Toggle()
    end)
    
    table.insert(section.Elements, self)
    return self
end

function Dropdown:Toggle()
    self.Open = not self.Open
    
    if self.Open then
        self.OptionsContainer.Visible = true
        self.OptionsContainer.Size = UDim2.new(1, 0, 0, self.OptionsLayout.AbsoluteContentSize.Y)
        Tween(self.Arrow, {Rotation = 180}, 0.2)
    else
        self.OptionsContainer.Size = UDim2.new(1, 0, 0, 0)
        wait(0.2)
        self.OptionsContainer.Visible = false
        Tween(self.Arrow, {Rotation = 0}, 0.2)
    end
end

function Dropdown:SetValue(value, silent)
    self.Value = value
    self.Button.Text = self.Name .. ": " .. tostring(value)
    
    if self.Flag then
        Library.Flags[self.Flag] = self.Value
    end
    
    if not silent and self.Callback then
        self.Callback(self.Value)
    end
end

function Dropdown:UpdateTheme()
    self.Button.BackgroundColor3 = Library.Theme.Foreground
    self.Button.TextColor3 = Library.Theme.TextColor
    self.Arrow.TextColor3 = Library.Theme.TextColor
    self.OptionsContainer.BackgroundColor3 = Library.Theme.Foreground
    
    for _, child in ipairs(self.OptionsContainer:GetChildren()) do
        if child:IsA("TextButton") then
            child.BackgroundColor3 = Library.Theme.Foreground
            child.TextColor3 = Library.Theme.TextColor
        end
    end
end

function Dropdown:UpdateFlag()
    if self.Flag and Library.Flags[self.Flag] ~= nil then
        self:SetValue(Library.Flags[self.Flag], true)
    end
end

-- MultiDropdown element
local MultiDropdown = setmetatable({}, Dropdown)
MultiDropdown.__index = MultiDropdown

function MultiDropdown.new(section, name, options, default, flag, callback)
    default = default or {}
    local self = setmetatable(Element.new(section, name, flag, callback), MultiDropdown)
    
    self.Options = options or {}
    self.Value = {}
    self.Open = false
    
    -- Set default values
    for _, option in ipairs(default) do
        if table.find(self.Options, option) then
            table.insert(self.Value, option)
        end
    end
    
    if flag then
        Library.Flags[flag] = self.Value
    end
    
    -- Create container (same as Dropdown)
    self.Container = Create("Frame", {
        Name = name .. "MultiDropdown",
        Parent = section.Container,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        LayoutOrder = #section.Elements + 1,
        ZIndex = 3
    })
    
    -- Dropdown button
    self.Button = Create("TextButton", {
        Name = "Button",
        Parent = self.Container,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = Library.Theme.Foreground,
        BorderSizePixel = 0,
        Text = self:GetText(),
        TextColor3 = Library.Theme.TextColor,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4
    })
    
    self.ButtonCorner = Create("UICorner", {
        Parent = self.Button,
        CornerRadius = UDim.new(0, 4)
    })
    
    self.Button.Padding = Create("UIPadding", {
        Parent = self.Button,
        PaddingLeft = UDim.new(0, 10)
    })
    
    -- Dropdown arrow
    self.Arrow = Create("TextLabel", {
        Name = "Arrow",
        Parent = self.Button,
        Size = UDim2.new(0, 20, 0, 20),
        Position = UDim2.new(1, -25, 0.5, -10),
        BackgroundTransparency = 1,
        Text = "▼",
        TextColor3 = Library.Theme.TextColor,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        ZIndex = 5
    })
    
    -- Options container
    self.OptionsContainer = Create("Frame", {
        Name = "OptionsContainer",
        Parent = self.Container,
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 0, 35),
        BackgroundColor3 = Library.Theme.Foreground,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false,
        ZIndex = 6
    })
    
    self.OptionsCorner = Create("UICorner", {
        Parent = self.OptionsContainer,
        CornerRadius = UDim.new(0, 4)
    })
    
    self.OptionsLayout = Create("UIListLayout", {
        Parent = self.OptionsContainer,
        SortOrder = Enum.SortOrder.LayoutOrder
    })
    
    self.OptionsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if self.Open then
            self.OptionsContainer.Size = UDim2.new(1, 0, 0, self.OptionsLayout.AbsoluteContentSize.Y)
        end
    end)
    
    -- Create option buttons with checkboxes
    for i, option in ipairs(self.Options) do
        local optionFrame = Create("Frame", {
            Name = option .. "Option",
            Parent = self.OptionsContainer,
            Size = UDim2.new(1, 0, 0, 25),
            BackgroundTransparency = 1,
            LayoutOrder = i,
            ZIndex = 7
        })
        
        local optionButton = Create("TextButton", {
            Name = "Button",
            Parent = optionFrame,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            ZIndex = 8
        })
        
        local optionText = Create("TextLabel", {
            Name = "Text",
            Parent = optionFrame,
            Size = UDim2.new(1, -30, 1, 0),
            Position = UDim2.new(0, 30, 0, 0),
            BackgroundTransparency = 1,
            Text = tostring(option),
            TextColor3 = Library.Theme.TextColor,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 8
        })
        
        local checkbox = Create("Frame", {
            Name = "Checkbox",
            Parent = optionFrame,
            Size = UDim2.new(0, 15, 0, 15),
            Position = UDim2.new(0, 10, 0.5, -7.5),
            BackgroundColor3 = Library.Theme.Foreground,
            BorderSizePixel = 0,
            ZIndex = 8
        })
        
        local checkboxCorner = Create("UICorner", {
            Parent = checkbox,
            CornerRadius = UDim.new(0, 2)
        })
        
        local checkmark = Create("TextLabel", {
            Name = "Checkmark",
            Parent = checkbox,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "✓",
            TextColor3 = Library.Theme.TextColor,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            Visible = false,
            ZIndex = 9
        })
        
        -- Set initial state
        if table.find(self.Value, option) then
            checkmark.Visible = true
            checkbox.BackgroundColor3 = Library.Theme.Accent
        end
        
        -- Click event
        optionButton.MouseButton1Click:Connect(function()
            self:ToggleOption(option)
            
            if table.find(self.Value, option) then
                checkmark.Visible = true
                Tween(checkbox, {BackgroundColor3 = Library.Theme.Accent}, 0.2)
            else
                checkmark.Visible = false
                Tween(checkbox, {BackgroundColor3 = Library.Theme.Foreground}, 0.2)
            end
        end)
        
        -- Hover effects
        optionButton.MouseEnter:Connect(function()
            Tween(optionText, {TextColor3 = Library.Theme.Accent}, 0.2)
        end)
        
        optionButton.MouseLeave:Connect(function()
            Tween(optionText, {TextColor3 = Library.Theme.TextColor}, 0.2)
        end)
    end
    
    -- Toggle event
    self.Button.MouseButton1Click:Connect(function()
        self:Toggle()
    end)
    
    table.insert(section.Elements, self)
    return self
end

function MultiDropdown:GetText()
    if #self.Value == 0 then
        return self.Name .. ": None"
    elseif #self.Value == 1 then
        return self.Name .. ": " .. tostring(self.Value[1])
    else
        return self.Name .. ": " .. tostring(#self.Value) .. " selected"
    end
end

function MultiDropdown:ToggleOption(option)
    if table.find(self.Value, option) then
        table.remove(self.Value, table.find(self.Value, option))
    else
        table.insert(self.Value, option)
    end
    
    self.Button.Text = self:GetText()
    
    if self.Flag then
        Library.Flags[self.Flag] = self.Value
    end
    
    if self.Callback then
        self.Callback(self.Value)
    end
end

function MultiDropdown:Toggle()
    self.Open = not self.Open
    
    if self.Open then
        self.OptionsContainer.Visible = true
        self.OptionsContainer.Size = UDim2.new(1, 0, 0, self.OptionsLayout.AbsoluteContentSize.Y)
        Tween(self.Arrow, {Rotation = 180}, 0.2)
    else
        self.OptionsContainer.Size = UDim2.new(1, 0, 0, 0)
        wait(0.2)
        self.OptionsContainer.Visible = false
        Tween(self.Arrow, {Rotation = 0}, 0.2)
    end
end

function MultiDropdown:SetValue(values, silent)
    self.Value = values or {}
    self.Button.Text = self:GetText()
    
    if self.Flag then
        Library.Flags[self.Flag] = self.Value
    end
    
    -- Update checkboxes
    for _, optionFrame in ipairs(self.OptionsContainer:GetChildren()) do
        if optionFrame:IsA("Frame") and optionFrame.Name ~= "UIListLayout" then
            local option = string.gsub(optionFrame.Name, "Option", "")
            local checkbox = optionFrame:FindFirstChild("Checkbox")
            local checkmark = checkbox and checkbox:FindFirstChild("Checkmark")
            
            if checkbox and checkmark then
                if table.find(self.Value, option) then
                    checkmark.Visible = true
                    checkbox.BackgroundColor3 = Library.Theme.Accent
                else
                    checkmark.Visible = false
                    checkbox.BackgroundColor3 = Library.Theme.Foreground
                end
            end
        end
    end
    
    if not silent and self.Callback then
        self.Callback(self.Value)
    end
end

function MultiDropdown:UpdateTheme()
    self.Button.BackgroundColor3 = Library.Theme.Foreground
    self.Button.TextColor3 = Library.Theme.TextColor
    self.Arrow.TextColor3 = Library.Theme.TextColor
    self.OptionsContainer.BackgroundColor3 = Library.Theme.Foreground
    
    for _, optionFrame in ipairs(self.OptionsContainer:GetChildren()) do
        if optionFrame:IsA("Frame") and optionFrame.Name ~= "UIListLayout" then
            local optionText = optionFrame:FindFirstChild("Text")
            local checkbox = optionFrame:FindFirstChild("Checkbox")
            local checkmark = checkbox and checkbox:FindFirstChild("Checkmark")
            
            if optionText then
                optionText.TextColor3 = Library.Theme.TextColor
            end
            
            if checkbox then
                local option = string.gsub(optionFrame.Name, "Option", "")
                if table.find(self.Value, option) then
                    checkbox.BackgroundColor3 = Library.Theme.Accent
                else
                    checkbox.BackgroundColor3 = Library.Theme.Foreground
                end
            end
            
            if checkmark then
                checkmark.TextColor3 = Library.Theme.TextColor
            end
        end
    end
end

function MultiDropdown:UpdateFlag()
    if self.Flag and Library.Flags[self.Flag] ~= nil then
        self:SetValue(Library.Flags[self.Flag], true)
    end
end

-- Keybind element
local Keybind = setmetatable({}, Element)
Keybind.__index = Keybind

function Keybind.new(section, name, default, flag, callback, options)
    options = options or {}
    local self = setmetatable(Element.new(section, name, flag, callback), Keybind)
    
    self.Value = default or Enum.KeyCode.Unknown
    self.Listening = false
    self.Mode = options.Mode or "Toggle" -- "Toggle", "Hold", "Always"
    
    if flag then
        Library.Flags[flag] = self.Value
    end
    
    -- Create container
    self.Container = Create("Frame", {
        Name = name .. "Keybind",
        Parent = section.Container,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        LayoutOrder = #section.Elements + 1,
        ZIndex = 3
    })
    
    -- Keybind label
    self.Label = Create("TextLabel", {
        Name = "Label",
        Parent = self.Container,
        Size = UDim2.new(1, -80, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = Library.Theme.TextColor,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4
    })
    
    -- Keybind button
    self.Button = Create("TextButton", {
        Name = "Button",
        Parent = self.Container,
        Size = UDim2.new(0, 70, 0, 20),
        Position = UDim2.new(1, -70, 0.5, -10),
        BackgroundColor3 = Library.Theme.Foreground,
        BorderSizePixel = 0,
        Text = self.Value.Name,
        TextColor3 = Library.Theme.TextColor,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        ZIndex = 4
    })
    
    self.ButtonCorner = Create("UICorner", {
        Parent = self.Button,
        CornerRadius = UDim.new(0, 4)
    })
    
    -- Set up input listener
    self.InputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if self.Listening and input.UserInputType == Enum.UserInputType.Keyboard then
            self:SetValue(input.KeyCode)
            self:StopListening()
        elseif not self.Listening and input.KeyCode == self.Value and self.Value ~= Enum.KeyCode.Unknown then
            if self.Mode == "Toggle" then
                if self.Callback then
                    self.Callback(true)
                end
            elseif self.Mode == "Hold" then
                if self.Callback then
                    self.Callback(true)
                end
                
                -- Connect to input ended for hold mode
                local connection
                connection = UserInputService.InputEnded:Connect(function(endInput)
                    if endInput.KeyCode == self.Value then
                        if self.Callback then
                            self.Callback(false)
                        end
                        connection:Disconnect()
                    end
                end)
            end
        end
    end)
    
    -- Click event
    self.Button.MouseButton1Click:Connect(function()
        if self.Listening then
            self:StopListening()
        else
            self:StartListening()
        end
    end)
    
    table.insert(section.Elements, self)
    return self
end

function Keybind:StartListening()
    self.Listening = true
    self.Button.Text = "..."
    self.Button.BackgroundColor3 = Library.Theme.Accent
end

function Keybind:StopListening()
    self.Listening = false
    self.Button.Text = self.Value.Name
    self.Button.BackgroundColor3 = Library.Theme.Foreground
end

function Keybind:SetValue(value, silent)
    self.Value = value
    self.Button.Text = value.Name
    
    if self.Flag then
        Library.Flags[self.Flag] = self.Value
    end
    
    if not silent and self.Callback then
        self.Callback(self.Value)
    end
end

function Keybind:UpdateTheme()
    self.Label.TextColor3 = Library.Theme.TextColor
    self.Button.BackgroundColor3 = self.Listening and Library.Theme.Accent or Library.Theme.Foreground
    self.Button.TextColor3 = Library.Theme.TextColor
end

function Keybind:UpdateFlag()
    if self.Flag and Library.Flags[self.Flag] ~= nil then
        self:SetValue(Library.Flags[self.Flag], true)
    end
end

-- Textbox element
local Textbox = setmetatable({}, Element)
Textbox.__index = Textbox

function Textbox.new(section, name, default, flag, callback, options)
    options = options or {}
    local self = setmetatable(Element.new(section, name, flag, callback), Textbox)
    
    self.Value = default or ""
    self.Placeholder = options.Placeholder or ""
    self.Numeric = options.Numeric or false
    
    if flag then
        Library.Flags[flag] = self.Value
    end
    
    -- Create container
    self.Container = Create("Frame", {
        Name = name .. "Textbox",
        Parent = section.Container,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        LayoutOrder = #section.Elements + 1,
        ZIndex = 3
    })
    
    -- Textbox label
    self.Label = Create("TextLabel", {
        Name = "Label",
        Parent = self.Container,
        Size = UDim2.new(1, 0, 0, 15),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = Library.Theme.TextColor,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4
    })
    
    -- Textbox
    self.Box = Create("TextBox", {
        Name = "Box",
        Parent = self.Container,
        Size = UDim2.new(1, 0, 0, 20),
        Position = UDim2.new(0, 0, 0, 15),
        BackgroundColor3 = Library.Theme.Foreground,
        BorderSizePixel = 0,
        Text = self.Value,
        PlaceholderText = self.Placeholder,
        TextColor3 = Library.Theme.TextColor,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        ZIndex = 4
    })
    
    self.BoxCorner = Create("UICorner", {
        Parent = self.Box,
        CornerRadius = UDim.new(0, 4)
    })
    
    self.Box.Padding = Create("UIPadding", {
        Parent = self.Box,
        PaddingLeft = UDim.new(0, 5),
        PaddingRight = UDim.new(0, 5)
    })
    
    -- Focus lost event
    self.Box.FocusLost:Connect(function()
        local value = self.Box.Text
        
        if self.Numeric then
            value = tonumber(value) or 0
        end
        
        self:SetValue(value)
    end)
    
    table.insert(section.Elements, self)
    return self
end

function Textbox:SetValue(value, silent)
    self.Value = value
    self.Box.Text = tostring(value)
    
    if self.Flag then
        Library.Flags[self.Flag] = self.Value
    end
    
    if not silent and self.Callback then
        self.Callback(self.Value)
    end
end

function Textbox:UpdateTheme()
    self.Label.TextColor3 = Library.Theme.TextColor
    self.Box.BackgroundColor3 = Library.Theme.Foreground
    self.Box.TextColor3 = Library.Theme.TextColor
end

function Textbox:UpdateFlag()
    if self.Flag and Library.Flags[self.Flag] ~= nil then
        self:SetValue(Library.Flags[self.Flag], true)
    end
end

-- Label element
local Label = setmetatable({}, Element)
Label.__index = Label

function Label.new(section, text)
    local self = setmetatable(Element.new(section, text, nil, nil), Label)
    
    -- Create container
    self.Container = Create("Frame", {
        Name = text .. "Label",
        Parent = section.Container,
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        LayoutOrder = #section.Elements + 1,
        ZIndex = 3
    })
    
    -- Label
    self.TextLabel = Create("TextLabel", {
        Name = "Label",
        Parent = self.Container,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Library.Theme.TextColor,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4
    })
    
    table.insert(section.Elements, self)
    return self
end

function Label:SetText(text)
    self.TextLabel.Text = text
end

function Label:UpdateTheme()
    self.TextLabel.TextColor3 = Library.Theme.TextColor
end

-- ColorPicker element
local ColorPicker = setmetatable({}, Element)
ColorPicker.__index = ColorPicker

function ColorPicker.new(section, name, default, flag, callback)
    local self = setmetatable(Element.new(section, name, flag, callback), ColorPicker)
    
    self.Value = default or Color3.fromRGB(255, 255, 255)
    self.Open = false
    
    if flag then
        Library.Flags[flag] = self.Value
    end
    
    -- Create container
    self.Container = Create("Frame", {
        Name = name .. "ColorPicker",
        Parent = section.Container,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        LayoutOrder = #section.Elements + 1,
        ZIndex = 3
    })
    
    -- ColorPicker label
    self.Label = Create("TextLabel", {
        Name = "Label",
        Parent = self.Container,
        Size = UDim2.new(1, -50, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = Library.Theme.TextColor,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4
    })
    
    -- Color preview
    self.Preview = Create("TextButton", {
        Name = "Preview",
        Parent = self.Container,
        Size = UDim2.new(0, 40, 0, 20),
        Position = UDim2.new(1, -40, 0.5, -10),
        BackgroundColor3 = self.Value,
        BorderSizePixel = 0,
        Text = "",
        ZIndex = 4
    })
    
    self.PreviewCorner = Create("UICorner", {
        Parent = self.Preview,
        CornerRadius = UDim.new(0, 4)
    })
    
    -- Picker container
    self.PickerContainer = Create("Frame", {
        Name = "PickerContainer",
        Parent = self.Container,
        Size = UDim2.new(0, 200, 0, 0),
        Position = UDim2.new(0, 0, 0, 35),
        BackgroundColor3 = Library.Theme.Foreground,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false,
        ZIndex = 6
    })
    
    self.PickerCorner = Create("UICorner", {
        Parent = self.PickerContainer,
        CornerRadius = UDim.new(0, 4)
    })
    
    -- Hue slider
    self.HueSlider = Create("Frame", {
        Name = "HueSlider",
        Parent = self.PickerContainer,
        Size = UDim2.new(0, 15, 0, 150),
        Position = UDim2.new(1, -20, 0, 10),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 7
    })
    
    self.HueSliderCorner = Create("UICorner", {
        Parent = self.HueSlider,
        CornerRadius = UDim.new(0, 4)
    })
    
    -- Hue gradient
    local hueGradient = Create("UIGradient", {
        Parent = self.HueSlider,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))
        }),
        Rotation = 90
    })
    
    -- Hue selector
    self.HueSelector = Create("Frame", {
        Name = "HueSelector",
        Parent = self.HueSlider,
        Size = UDim2.new(1, 0, 0, 2),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 8
    })
    
    -- Saturation/Brightness area
    self.SatBrightArea = Create("ImageButton", {
        Name = "SatBrightArea",
        Parent = self.PickerContainer,
        Size = UDim2.new(0, 150, 0, 150),
        Position = UDim2.new(0, 10, 0, 10),
        BackgroundColor3 = Color3.fromRGB(255, 0, 0),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        ZIndex = 7
    })
    
    self.SatBrightAreaCorner = Create("UICorner", {
        Parent = self.SatBrightArea,
        CornerRadius = UDim.new(0, 4)
    })
    
    -- Saturation gradient
    local satGradient = Create("UIGradient", {
        Parent = self.SatBrightArea,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))
        }),
        Rotation = 0
    })
    
    -- Brightness gradient
    local brightGradient = Create("UIGradient", {
        Parent = self.SatBrightArea,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
            ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1))
        }),
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 0.5)
        })
    })
    
    -- Sat/Bright selector
    self.SatBrightSelector = Create("Frame", {
        Name = "SatBrightSelector",
        Parent = self.SatBrightArea,
        Size = UDim2.new(0, 6, 0, 6),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderColor3 = Color3.fromRGB(0, 0, 0),
        ZIndex = 8
    })
    
    self.SelectorCorner = Create("UICorner", {
        Parent = self.SatBrightSelector,
        CornerRadius = UDim.new(0, 3)
    })
    
    -- RGB inputs
    self.RInput = Create("TextBox", {
        Name = "RInput",
        Parent = self.PickerContainer,
        Size = UDim2.new(0, 40, 0, 20),
        Position = UDim2.new(0, 10, 0, 170),
        BackgroundColor3 = Library.Theme.LightContrast,
        BorderSizePixel = 0,
        Text = tostring(math.floor(self.Value.R * 255)),
        TextColor3 = Library.Theme.TextColor,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        ZIndex = 7
    })
    
    self.RInputCorner = Create("UICorner", {
        Parent = self.RInput,
        CornerRadius = UDim.new(0, 4)
    })
    
    self.RInput.Padding = Create("UIPadding", {
        Parent = self.RInput,
        PaddingLeft = UDim.new(0, 5)
    })
    
    self.GInput = Create("TextBox", {
        Name = "GInput",
        Parent = self.PickerContainer,
        Size = UDim2.new(0, 40, 0, 20),
        Position = UDim2.new(0, 60, 0, 170),
        BackgroundColor3 = Library.Theme.LightContrast,
        BorderSizePixel = 0,
        Text = tostring(math.floor(self.Value.G * 255)),
        TextColor3 = Library.Theme.TextColor,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        ZIndex = 7
    })
    
    self.GInputCorner = Create("UICorner", {
        Parent = self.GInput,
        CornerRadius = UDim.new(0, 4)
    })
    
    self.GInput.Padding = Create("UIPadding", {
        Parent = self.GInput,
        PaddingLeft = UDim.new(0, 5)
    })
    
    self.BInput = Create("TextBox", {
        Name = "BInput",
        Parent = self.PickerContainer,
        Size = UDim2.new(0, 40, 0, 20),
        Position = UDim2.new(0, 110, 0, 170),
        BackgroundColor3 = Library.Theme.LightContrast,
        BorderSizePixel = 0,
        Text = tostring(math.floor(self.Value.B * 255)),
        TextColor3 = Library.Theme.TextColor,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        ZIndex = 7
    })
    
    self.BInputCorner = Create("UICorner", {
        Parent = self.BInput,
        CornerRadius = UDim.new(0, 4)
    })
    
    self.BInput.Padding = Create("UIPadding", {
        Parent = self.BInput,
        PaddingLeft = UDim.new(0, 5)
    })
    
    -- Hex input
    self.HexInput = Create("TextBox", {
        Name = "HexInput",
        Parent = self.PickerContainer,
        Size = UDim2.new(0, 60, 0, 20),
        Position = UDim2.new(0, 10, 0, 200),
        BackgroundColor3 = Library.Theme.LightContrast,
        BorderSizePixel = 0,
        Text = self:RGBToHex(self.Value),
        TextColor3 = Library.Theme.TextColor,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        ZIndex = 7
    })
    
    self.HexInputCorner = Create("UICorner", {
        Parent = self.HexInput,
        CornerRadius = UDim.new(0, 4)
    })
    
    self.HexInput.Padding = Create("UIPadding", {
        Parent = self.HexInput,
        PaddingLeft = UDim.new(0, 5)
    })
    
    -- Set initial HSV values
    local h, s, v = RGBToHSV(self.Value.R * 255, self.Value.G * 255, self.Value.B * 255)
    self.Hue = h
    self.Saturation = s
    self.ValueValue = v
    
    -- Update selector positions
    self.HueSelector.Position = UDim2.new(0, 0, self.Hue, -1)
    self.SatBrightSelector.Position = UDim2.new(self.Saturation, -3, 1 - self.ValueValue, -3)
    
    -- Toggle event
    self.Preview.MouseButton1Click:Connect(function()
        self:Toggle()
    end)
    
    -- Hue slider events
    local hueDragging = false
    
    self.HueSlider.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            hueDragging = true
            
            local connection
            connection = RunService.RenderStepped:Connect(function()
                if not hueDragging then
                    connection:Disconnect()
                    return
                end
                
                local mousePos = UserInputService:GetMouseLocation()
                local sliderPos = self.HueSlider.AbsolutePosition
                local sliderSize = self.HueSlider.AbsoluteSize
                
                local relativeY = math.clamp(mousePos.Y - sliderPos.Y, 0, sliderSize.Y)
                local hue = relativeY / sliderSize.Y
                
                self:SetHue(hue)
            end)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            hueDragging = false
        end
    end)
    
    -- Sat/Bright area events
    local satBrightDragging = false
    
    self.SatBrightArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            satBrightDragging = true
            
            local connection
            connection = RunService.RenderStepped:Connect(function()
                if not satBrightDragging then
                    connection:Disconnect()
                    return
                end
                
                local mousePos = UserInputService:GetMouseLocation()
                local areaPos = self.SatBrightArea.AbsolutePosition
                local areaSize = self.SatBrightArea.AbsoluteSize
                
                local relativeX = math.clamp(mousePos.X - areaPos.X, 0, areaSize.X)
                local relativeY = math.clamp(mousePos.Y - areaPos.Y, 0, areaSize.Y)
                
                local sat = relativeX / areaSize.X
                local val = 1 - (relativeY / areaSize.Y)
                
                self:SetSaturationAndValue(sat, val)
            end)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            satBrightDragging = false
        end
    end)
    
    -- RGB input events
    self.RInput.FocusLost:Connect(function()
        local r = tonumber(self.RInput.Text) or 0
        r = math.clamp(r, 0, 255)
        self.RInput.Text = tostring(r)
        
        local g = tonumber(self.GInput.Text) or 0
        local b = tonumber(self.BInput.Text) or 0
        
        self:SetRGB(r, g, b)
    end)
    
    self.GInput.FocusLost:Connect(function()
        local g = tonumber(self.GInput.Text) or 0
        g = math.clamp(g, 0, 255)
        self.GInput.Text = tostring(g)
        
        local r = tonumber(self.RInput.Text) or 0
        local b = tonumber(self.BInput.Text) or 0
        
        self:SetRGB(r, g, b)
    end)
    
    self.BInput.FocusLost:Connect(function()
        local b = tonumber(self.BInput.Text) or 0
        b = math.clamp(b, 0, 255)
        self.BInput.Text = tostring(b)
        
        local r = tonumber(self.RInput.Text) or 0
        local g = tonumber(self.GInput.Text) or 0
        
        self:SetRGB(r, g, b)
    end)
    
    -- Hex input event
    self.HexInput.FocusLost:Connect(function()
        local hex = self.HexInput.Text
        if string.sub(hex, 1, 1) == "#" then
            hex = string.sub(hex, 2)
        end
        
        if #hex == 6 then
            local r = tonumber("0x" .. string.sub(hex, 1, 2))
            local g = tonumber("0x" .. string.sub(hex, 3, 4))
            local b = tonumber("0x" .. string.sub(hex, 5, 6))
            
            if r and g and b then
                self:SetRGB(r, g, b)
            end
        end
    end)
    
    table.insert(section.Elements, self)
    return self
end

function ColorPicker:RGBToHex(color)
    local r = math.floor(color.R * 255)
    local g = math.floor(color.G * 255)
    local b = math.floor(color.B * 255)
    return string.format("#%02X%02X%02X", r, g, b)
end

function ColorPicker:SetHue(hue)
    self.Hue = hue
    self.HueSelector.Position = UDim2.new(0, 0, hue, -1)
    
    local r, g, b = HSVToRGB(hue, self.Saturation, self.ValueValue)
    self.SatBrightArea.BackgroundColor3 = Color3.fromRGB(r, g, b)
    
    self:UpdateColor()
end

function ColorPicker:SetSaturationAndValue(sat, val)
    self.Saturation = sat
    self.ValueValue = val
    self.SatBrightSelector.Position = UDim2.new(sat, -3, 1 - val, -3)
    
    self:UpdateColor()
end

function ColorPicker:SetRGB(r, g, b)
    local h, s, v = RGBToHSV(r, g, b)
    self.Hue = h
    self.Saturation = s
    self.ValueValue = v
    
    self.HueSelector.Position = UDim2.new(0, 0, h, -1)
    self.SatBrightSelector.Position = UDim2.new(s, -3, 1 - v, -3)
    self.SatBrightArea.BackgroundColor3 = Color3.fromRGB(r, g, b)
    
    self:UpdateColor()
end

function ColorPicker:UpdateColor()
    local r, g, b = HSVToRGB(self.Hue, self.Saturation, self.ValueValue)
    self.Value = Color3.fromRGB(r, g, b)
    self.Preview.BackgroundColor3 = self.Value
    
    -- Update RGB inputs
    self.RInput.Text = tostring(math.floor(r))
    self.GInput.Text = tostring(math.floor(g))
    self.BInput.Text = tostring(math.floor(b))
    
    -- Update hex input
    self.HexInput.Text = self:RGBToHex(self.Value)
    
    if self.Flag then
        Library.Flags[self.Flag] = self.Value
    end
    
    if self.Callback then
        self.Callback(self.Value)
    end
end

function ColorPicker:Toggle()
    self.Open = not self.Open
    
    if self.Open then
        self.PickerContainer.Visible = true
        self.PickerContainer.Size = UDim2.new(0, 200, 0, 230)
    else
        self.PickerContainer.Size = UDim2.new(0, 200, 0, 0)
        wait(0.2)
        self.PickerContainer.Visible = false
    end
end

function ColorPicker:SetValue(value, silent)
    self.Value = value
    self.Preview.BackgroundColor3 = value
    
    local r = math.floor(value.R * 255)
    local g = math.floor(value.G * 255)
    local b = math.floor(value.B * 255)
    
    local h, s, v = RGBToHSV(r, g, b)
    self.Hue = h
    self.Saturation = s
    self.ValueValue = v
    
    if self.Open then
        self.HueSelector.Position = UDim2.new(0, 0, h, -1)
        self.SatBrightSelector.Position = UDim2.new(s, -3, 1 - v, -3)
        self.SatBrightArea.BackgroundColor3 = value
        
        self.RInput.Text = tostring(r)
        self.GInput.Text = tostring(g)
        self.BInput.Text = tostring(b)
        self.HexInput.Text = self:RGBToHex(value)
    end
    
    if self.Flag then
        Library.Flags[self.Flag] = self.Value
    end
    
    if not silent and self.Callback then
        self.Callback(self.Value)
    end
end

function ColorPicker:UpdateTheme()
    self.Label.TextColor3 = Library.Theme.TextColor
    self.PickerContainer.BackgroundColor3 = Library.Theme.Foreground
    self.RInput.BackgroundColor3 = Library.Theme.LightContrast
    self.RInput.TextColor3 = Library.Theme.TextColor
    self.GInput.BackgroundColor3 = Library.Theme.LightContrast
    self.GInput.TextColor3 = Library.Theme.TextColor
    self.BInput.BackgroundColor3 = Library.Theme.LightContrast
    self.BInput.TextColor3 = Library.Theme.TextColor
    self.HexInput.BackgroundColor3 = Library.Theme.LightContrast
    self.HexInput.TextColor3 = Library.Theme.TextColor
end

function ColorPicker:UpdateFlag()
    if self.Flag and Library.Flags[self.Flag] ~= nil then
        self:SetValue(Library.Flags[self.Flag], true)
    end
end

-- Input handling for dragging and resizing
UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        if Library.Dragging then
            local delta = input.Position - Library.Dragging.Start
            Library.Dragging.Window.Main.Position = UDim2.new(
                0, Library.Dragging.Position.X.Offset + delta.X,
                0, Library.Dragging.Position.Y.Offset + delta.Y
            )
        end
        
        if Library.Resizing then
            local delta = input.Position - Library.Resizing.Start
            local newSize = Vector2.new(
                math.max(Library.Resizing.Size.X.Offset + delta.X, Library.Resizing.Window.MinSize.X),
                math.max(Library.Resizing.Size.Y.Offset + delta.Y, Library.Resizing.Window.MinSize.Y)
            )
            
            Library.Resizing.Window.Main.Size = UDim2.new(0, newSize.X, 0, newSize.Y)
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        Library.Dragging = nil
        Library.Resizing = nil
    end
end)

-- Add element creation methods to Window class
function Window:AddToggle(section, name, default, flag, callback)
    return Toggle.new(section, name, default, flag, callback)
end

function Window:AddSlider(section, name, min, max, default, flag, callback, options)
    return Slider.new(section, name, min, max, default, flag, callback, options)
end

function Window:AddButton(section, name, callback)
    return Button.new(section, name, callback)
end

function Window:AddDropdown(section, name, options, default, flag, callback)
    return Dropdown.new(section, name, options, default, flag, callback)
end

function Window:AddMultiDropdown(section, name, options, default, flag, callback)
    return MultiDropdown.new(section, name, options, default, flag, callback)
end

function Window:AddKeybind(section, name, default, flag, callback, options)
    return Keybind.new(section, name, default, flag, callback, options)
end

function Window:AddTextbox(section, name, default, flag, callback, options)
    return Textbox.new(section, name, default, flag, callback, options)
end

function Window:AddLabel(section, text)
    return Label.new(section, text)
end

function Window:AddColorPicker(section, name, default, flag, callback)
    return ColorPicker.new(section, name, default, flag, callback)
end

-- Library functions
function Library:CreateWindow(title, size, position, options)
    return Window.new(title, size, position, options)
end

function Library:Unload()
    if self.ScreenGui then
        self.ScreenGui:Destroy()
    end
    
    if self.NotificationHandler then
        self.NotificationHandler:Disconnect()
    end
    
    for _, connection in ipairs(self.Connections or {}) do
        connection:Disconnect()
    end
    
    self.Windows = {}
    self.Flags = {}
end

-- Return the library
return Library
