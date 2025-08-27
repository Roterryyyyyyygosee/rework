-- Linoria-like UI Library for Roblox
-- By: [Your Name]

local Library = {}
Library.__index = Library

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Colors
local ACCENT = Color3.fromRGB(0, 120, 215)
local BACKGROUND = Color3.fromRGB(25, 25, 25)
local ELEMENT_BG = Color3.fromRGB(35, 35, 35)
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local BORDER_COLOR = Color3.fromRGB(60, 60, 60)

-- Utility functions
local function Create(class, properties)
    local instance = Instance.new(class)
    for property, value in pairs(properties) do
        instance[property] = value
    end
    return instance
end

local function Tween(object, properties, duration, style)
    local tweenInfo = TweenInfo.new(duration or 0.2, style or Enum.EasingStyle.Quad)
    local tween = TweenService:Create(object, tweenInfo, properties)
    tween:Play()
    return tween
end

-- Window
function Library:CreateWindow(name)
    local Window = {}
    Window.Tabs = {}
    Window.Visible = false
    
    -- Main screen GUI
    local ScreenGui = Create("ScreenGui", {
        Name = name .. "UI",
        Parent = game.CoreGui,
        ResetOnSpawn = false
    })
    
    -- Main container
    local MainFrame = Create("Frame", {
        Parent = ScreenGui,
        Size = UDim2.new(0, 500, 0, 400),
        Position = UDim2.new(0.5, -250, 0.5, -200),
        BackgroundColor3 = BACKGROUND,
        BorderColor3 = BORDER_COLOR,
        BorderSizePixel = 1,
        Visible = false
    })
    
    -- Title bar
    local TitleBar = Create("Frame", {
        Parent = MainFrame,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = ACCENT,
        BorderSizePixel = 0
    })
    
    local Title = Create("TextLabel", {
        Parent = TitleBar,
        Size = UDim2.new(1, -60, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = TEXT_COLOR,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.GothamBold
    })
    
    local CloseButton = Create("TextButton", {
        Parent = TitleBar,
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -30, 0, 0),
        BackgroundTransparency = 1,
        Text = "X",
        TextColor3 = TEXT_COLOR,
        Font = Enum.Font.GothamBold
    })
    
    CloseButton.MouseButton1Click:Connect(function()
        Window:Toggle()
    end)
    
    -- Tab container
    local TabContainer = Create("Frame", {
        Parent = MainFrame,
        Size = UDim2.new(1, -20, 0, 30),
        Position = UDim2.new(0, 10, 0, 35),
        BackgroundTransparency = 1
    })
    
    local UIListLayout = Create("UIListLayout", {
        Parent = TabContainer,
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 5)
    })
    
    -- Content area
    local ContentFrame = Create("ScrollingFrame", {
        Parent = MainFrame,
        Size = UDim2.new(1, -20, 1, -70),
        Position = UDim2.new(0, 10, 0, 70),
        BackgroundTransparency = 1,
        ScrollBarThickness = 5,
        ScrollBarImageColor3 = BORDER_COLOR,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y
    })
    
    local ContentLayout = Create("UIListLayout", {
        Parent = ContentFrame,
        Padding = UDim.new(0, 5)
    })
    
    -- Make window draggable
    local dragInput, dragStart, startPos
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragStart = nil
                end
            end)
        end
    end)
    
    TitleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragStart then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, 
                                          startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    -- Window methods
    function Window:Toggle()
        Window.Visible = not Window.Visible
        MainFrame.Visible = Window.Visible
    end
    
    function Window:CreateTab(name)
        local Tab = {}
        Tab.Sections = {}
        
        -- Tab button
        local TabButton = Create("TextButton", {
            Parent = TabContainer,
            Size = UDim2.new(0, 80, 1, 0),
            BackgroundColor3 = ELEMENT_BG,
            BorderColor3 = BORDER_COLOR,
            BorderSizePixel = 1,
            Text = name,
            TextColor3 = TEXT_COLOR,
            Font = Enum.Font.Gotham
        })
        
        -- Tab content
        local TabContent = Create("Frame", {
            Parent = ContentFrame,
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            Visible = false
        })
        
        local TabLayout = Create("UIListLayout", {
            Parent = TabContent,
            Padding = UDim.new(0, 10)
        })
        
        TabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            TabContent.Size = UDim2.new(1, 0, 0, TabLayout.AbsoluteContentSize.Y)
        end)
        
        -- Tab activation
        TabButton.MouseButton1Click:Connect(function()
            for _, otherTab in pairs(Window.Tabs) do
                otherTab.Content.Visible = false
                Tween(otherTab.Button, {BackgroundColor3 = ELEMENT_BG}, 0.2)
            end
            TabContent.Visible = true
            Tween(TabButton, {BackgroundColor3 = ACCENT}, 0.2)
        end)
        
        -- Tab methods
        function Tab:CreateSection(name)
            local Section = {}
            
            local SectionFrame = Create("Frame", {
                Parent = TabContent,
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundColor3 = ELEMENT_BG,
                BorderColor3 = BORDER_COLOR,
                BorderSizePixel = 1
            })
            
            local SectionTitle = Create("TextLabel", {
                Parent = SectionFrame,
                Size = UDim2.new(1, -10, 0, 25),
                Position = UDim2.new(0, 5, 0, 5),
                BackgroundTransparency = 1,
                Text = name,
                TextColor3 = TEXT_COLOR,
                TextXAlignment = Enum.TextXAlignment.Left,
                Font = Enum.Font.GothamBold
            })
            
            local SectionContent = Create("Frame", {
                Parent = SectionFrame,
                Size = UDim2.new(1, -10, 0, 0),
                Position = UDim2.new(0, 5, 0, 30),
                BackgroundTransparency = 1
            })
            
            local SectionLayout = Create("UIListLayout", {
                Parent = SectionContent,
                Padding = UDim.new(0, 5)
            })
            
            SectionLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                SectionContent.Size = UDim2.new(1, 0, 0, SectionLayout.AbsoluteContentSize.Y)
                SectionFrame.Size = UDim2.new(1, 0, 0, SectionLayout.AbsoluteContentSize.Y + 35)
            end)
            
            -- Section methods
            function Section:AddButton(name, callback)
                local Button = Create("TextButton", {
                    Parent = SectionContent,
                    Size = UDim2.new(1, 0, 0, 30),
                    BackgroundColor3 = ELEMENT_BG,
                    BorderColor3 = BORDER_COLOR,
                    BorderSizePixel = 1,
                    Text = name,
                    TextColor3 = TEXT_COLOR,
                    Font = Enum.Font.Gotham
                })
                
                Button.MouseButton1Click:Connect(function()
                    callback()
                    Tween(Button, {BackgroundColor3 = ACCENT}, 0.2)
                    Tween(Button, {BackgroundColor3 = ELEMENT_BG}, 0.2)
                end)
                
                Button.MouseEnter:Connect(function()
                    Tween(Button, {BackgroundColor3 = Color3.fromRGB(45, 45, 45)}, 0.2)
                end)
                
                Button.MouseLeave:Connect(function()
                    Tween(Button, {BackgroundColor3 = ELEMENT_BG}, 0.2)
                end)
            end
            
            function Section:AddToggle(name, default, callback)
                local Toggle = {}
                Toggle.Value = default or false
                
                local ToggleFrame = Create("Frame", {
                    Parent = SectionContent,
                    Size = UDim2.new(1, 0, 0, 30),
                    BackgroundTransparency = 1
                })
                
                local ToggleLabel = Create("TextLabel", {
                    Parent = ToggleFrame,
                    Size = UDim2.new(0.7, 0, 1, 0),
                    BackgroundTransparency = 1,
                    Text = name,
                    TextColor3 = TEXT_COLOR,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Font = Enum.Font.Gotham
                })
                
                local ToggleButton = Create("TextButton", {
                    Parent = ToggleFrame,
                    Size = UDim2.new(0, 50, 0, 20),
                    Position = UDim2.new(1, -50, 0.5, -10),
                    BackgroundColor3 = Toggle.Value and ACCENT or ELEMENT_BG,
                    BorderColor3 = BORDER_COLOR,
                    BorderSizePixel = 1,
                    Text = "",
                    Font = Enum.Font.Gotham
                })
                
                local ToggleIndicator = Create("Frame", {
                    Parent = ToggleButton,
                    Size = UDim2.new(0, 18, 0, 18),
                    Position = UDim2.new(0, Toggle.Value and 28 or 2, 0, 1),
                    BackgroundColor3 = TEXT_COLOR,
                    BorderSizePixel = 0
                })
                
                function Toggle:SetValue(value)
                    Toggle.Value = value
                    Tween(ToggleButton, {BackgroundColor3 = value and ACCENT or ELEMENT_BG}, 0.2)
                    Tween(ToggleIndicator, {Position = UDim2.new(0, value and 28 or 2, 0, 1)}, 0.2)
                    callback(value)
                end
                
                ToggleButton.MouseButton1Click:Connect(function()
                    Toggle:SetValue(not Toggle.Value)
                end)
                
                return Toggle
            end
            
            function Section:AddSlider(name, min, max, default, callback)
                local Slider = {}
                Slider.Value = default or min
                
                local SliderFrame = Create("Frame", {
                    Parent = SectionContent,
                    Size = UDim2.new(1, 0, 0, 50),
                    BackgroundTransparency = 1
                })
                
                local SliderLabel = Create("TextLabel", {
                    Parent = SliderFrame,
                    Size = UDim2.new(1, 0, 0, 20),
                    BackgroundTransparency = 1,
                    Text = name .. ": " .. Slider.Value,
                    TextColor3 = TEXT_COLOR,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Font = Enum.Font.Gotham
                })
                
                local SliderTrack = Create("Frame", {
                    Parent = SliderFrame,
                    Size = UDim2.new(1, 0, 0, 5),
                    Position = UDim2.new(0, 0, 0, 25),
                    BackgroundColor3 = ELEMENT_BG,
                    BorderColor3 = BORDER_COLOR,
                    BorderSizePixel = 1
                })
                
                local SliderFill = Create("Frame", {
                    Parent = SliderTrack,
                    Size = UDim2.new((Slider.Value - min) / (max - min), 0, 1, 0),
                    BackgroundColor3 = ACCENT,
                    BorderSizePixel = 0
                })
                
                local SliderButton = Create("TextButton", {
                    Parent = SliderTrack,
                    Size = UDim2.new(0, 15, 0, 15),
                    Position = UDim2.new((Slider.Value - min) / (max - min), -7.5, 0.5, -7.5),
                    BackgroundColor3 = TEXT_COLOR,
                    BorderSizePixel = 0,
                    Text = "",
                    ZIndex = 2
                })
                
                local dragging = false
                
                local function updateSlider(input)
                    local percent = math.clamp((input.Position.X - SliderTrack.AbsolutePosition.X) / SliderTrack.AbsoluteSize.X, 0, 1)
                    Slider.Value = math.floor(min + (max - min) * percent)
                    SliderLabel.Text = name .. ": " .. Slider.Value
                    SliderFill.Size = UDim2.new(percent, 0, 1, 0)
                    SliderButton.Position = UDim2.new(percent, -7.5, 0.5, -7.5)
                    callback(Slider.Value)
                end
                
                SliderButton.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = true
                    end
                end)
                
                SliderButton.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = false
                    end
                end)
                
                UserInputService.InputChanged:Connect(function(input)
                    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                        updateSlider(input)
                    end
                end)
                
                return Slider
            end
            
            function Section:AddDropdown(name, options, default, callback)
                local Dropdown = {}
                Dropdown.Value = default or options[1]
                Dropdown.Open = false
                
                local DropdownFrame = Create("Frame", {
                    Parent = SectionContent,
                    Size = UDim2.new(1, 0, 0, 30),
                    BackgroundTransparency = 1
                })
                
                local DropdownButton = Create("TextButton", {
                    Parent = DropdownFrame,
                    Size = UDim2.new(1, 0, 0, 30),
                    BackgroundColor3 = ELEMENT_BG,
                    BorderColor3 = BORDER_COLOR,
                    BorderSizePixel = 1,
                    Text = name .. ": " .. Dropdown.Value,
                    TextColor3 = TEXT_COLOR,
                    Font = Enum.Font.Gotham
                })
                
                local DropdownArrow = Create("TextLabel", {
                    Parent = DropdownButton,
                    Size = UDim2.new(0, 20, 0, 20),
                    Position = UDim2.new(1, -25, 0.5, -10),
                    BackgroundTransparency = 1,
                    Text = "▼",
                    TextColor3 = TEXT_COLOR,
                    Font = Enum.Font.Gotham
                })
                
                local DropdownList = Create("ScrollingFrame", {
                    Parent = DropdownFrame,
                    Size = UDim2.new(1, 0, 0, 0),
                    Position = UDim2.new(0, 0, 0, 35),
                    BackgroundColor3 = ELEMENT_BG,
                    BorderColor3 = BORDER_COLOR,
                    BorderSizePixel = 1,
                    ScrollBarThickness = 5,
                    Visible = false,
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    AutomaticCanvasSize = Enum.AutomaticSize.Y
                })
                
                local ListLayout = Create("UIListLayout", {
                    Parent = DropdownList,
                    Padding = UDim.new(0, 1)
                })
                
                function Dropdown:SetValue(value)
                    Dropdown.Value = value
                    DropdownButton.Text = name .. ": " .. value
                    callback(value)
                end
                
                function Dropdown:Toggle()
                    Dropdown.Open = not Dropdown.Open
                    DropdownList.Visible = Dropdown.Open
                    DropdownList.Size = UDim2.new(1, 0, 0, Dropdown.Open and math.min(#options * 30, 150) or 0)
                    Tween(DropdownArrow, {Rotation = Dropdown.Open and 180 or 0}, 0.2)
                end
                
                for _, option in ipairs(options) do
                    local OptionButton = Create("TextButton", {
                        Parent = DropdownList,
                        Size = UDim2.new(1, 0, 0, 30),
                        BackgroundColor3 = ELEMENT_BG,
                        BorderSizePixel = 0,
                        Text = option,
                        TextColor3 = TEXT_COLOR,
                        Font = Enum.Font.Gotham
                    })
                    
                    OptionButton.MouseButton1Click:Connect(function()
                        Dropdown:SetValue(option)
                        Dropdown:Toggle()
                    end)
                    
                    OptionButton.MouseEnter:Connect(function()
                        Tween(OptionButton, {BackgroundColor3 = Color3.fromRGB(45, 45, 45)}, 0.2)
                    end)
                    
                    OptionButton.MouseLeave:Connect(function()
                        Tween(OptionButton, {BackgroundColor3 = ELEMENT_BG}, 0.2)
                    end)
                end
                
                DropdownButton.MouseButton1Click:Connect(function()
                    Dropdown:Toggle()
                end)
                
                return Dropdown
            end
            
            table.insert(Tab.Sections, Section)
            return Section
        end
        
        Tab.Button = TabButton
        Tab.Content = TabContent
        table.insert(Window.Tabs, Tab)
        
        -- Activate first tab
        if #Window.Tabs == 1 then
            TabContent.Visible = true
            TabButton.BackgroundColor3 = ACCENT
        end
        
        return Tab
    end
    
    -- Show window by default
    Window:Toggle()
    
    return Window
end

-- Keybind to toggle UI
local function CreateToggleKeybind()
    local toggleKey = Enum.KeyCode.RightShift
    
    UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == toggleKey then
            -- This would need to be handled differently in a real implementation
            -- since we don't have access to all windows from here
        end
    end)
end

CreateToggleKeybind()

return Library
