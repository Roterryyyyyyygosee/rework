-- ImGui.lua (ModuleScript)
local ImGui = {}
ImGui.__index = ImGui

-- Default styling
ImGui.Styles = {
    Background = Color3.fromRGB(40, 40, 40),
    Text = Color3.fromRGB(220, 220, 220),
    Primary = Color3.fromRGB(0, 120, 215),
    Hover = Color3.fromRGB(30, 144, 255),
    Active = Color3.fromRGB(0, 90, 158),
    Border = Color3.fromRGB(60, 60, 60),
    Disabled = Color3.fromRGB(120, 120, 120),
    ToggleOn = Color3.fromRGB(0, 170, 0),
    ToggleOff = Color3.fromRGB(120, 120, 120),
    SliderFill = Color3.fromRGB(0, 120, 215),
    SliderBackground = Color3.fromRGB(80, 80, 80),
}

-- Default sizes
ImGui.Sizes = {
    WindowPadding = Vector2.new(8, 8),
    ItemSpacing = Vector2.new(4, 4),
    TextSize = 14,
    ButtonHeight = 24,
    SliderHeight = 16,
    DropdownItemHeight = 24,
    BorderSize = 1,
}

-- Create a new ImGui instance
function ImGui.new(parentFrame)
    local self = setmetatable({}, ImGui)
    
    self.Parent = parentFrame or Instance.new("Frame")
    self.Parent.BackgroundTransparency = 1
    
    self.Elements = {}
    self.Windows = {}
    self.ActiveDropdown = nil
    
    return self
end

-- Utility functions
function ImGui:CreateElement(className, properties)
    local element = Instance.new(className)
    
    for property, value in pairs(properties) do
        element[property] = value
    end
    
    return element
end

function ImGui:AddToLayout(element)
    table.insert(self.Elements, element)
    return element
end

-- Window creation
function ImGui:BeginWindow(title, position, size, flags)
    local window = {
        Title = title,
        Position = position or Vector2.new(50, 50),
        Size = size or Vector2.new(200, 300),
        Flags = flags or {},
        Elements = {},
        Cursor = Vector2.new(self.Sizes.WindowPadding.X, self.Sizes.WindowPadding.Y + 20)
    }
    
    -- Create window frame
    local windowFrame = self:CreateElement("Frame", {
        Name = title .. "Window",
        Position = UDim2.fromOffset(window.Position.X, window.Position.Y),
        Size = UDim2.fromOffset(window.Size.X, window.Size.Y),
        BackgroundColor3 = self.Styles.Background,
        BorderColor3 = self.Styles.Border,
        BorderSizePixel = self.Sizes.BorderSize,
        Parent = self.Parent
    })
    
    -- Window title
    local titleLabel = self:CreateElement("TextLabel", {
        Name = "Title",
        Position = UDim2.fromOffset(8, 4),
        Size = UDim2.new(1, -16, 0, 16),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = self.Styles.Text,
        TextSize = self.Sizes.TextSize,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = windowFrame
    })
    
    -- Content area
    local contentFrame = self:CreateElement("Frame", {
        Name = "Content",
        Position = UDim2.fromOffset(0, 24),
        Size = UDim2.new(1, 0, 1, -24),
        BackgroundTransparency = 1,
        Parent = windowFrame
    })
    
    window.Frame = windowFrame
    window.Content = contentFrame
    
    table.insert(self.Windows, window)
    self.CurrentWindow = window
    
    return window
end

function ImGui:EndWindow()
    self.CurrentWindow = nil
end

-- Layout management
function ImGui:SameLine()
    if self.CurrentWindow then
        local lastElement = self.CurrentWindow.Elements[#self.CurrentWindow.Elements]
        if lastElement then
            self.CurrentWindow.Cursor = Vector2.new(
                lastElement.AbsolutePosition.X + lastElement.AbsoluteSize.X + self.Sizes.ItemSpacing.X,
                self.CurrentWindow.Cursor.Y
            )
        end
    end
end

function ImGui:NewLine()
    if self.CurrentWindow then
        local maxY = self.CurrentWindow.Cursor.Y
        
        for _, element in ipairs(self.CurrentWindow.Elements) do
            local bottom = element.AbsolutePosition.Y + element.AbsoluteSize.Y
            if bottom > maxY then
                maxY = bottom
            end
        end
        
        self.CurrentWindow.Cursor = Vector2.new(
            self.Sizes.WindowPadding.X,
            maxY + self.Sizes.ItemSpacing.Y
        )
    end
end

-- Button
function ImGui:Button(text, size)
    if not self.CurrentWindow then return false end
    
    size = size or Vector2.new(80, self.Sizes.ButtonHeight)
    
    local button = self:CreateElement("TextButton", {
        Name = text .. "Button",
        Position = UDim2.fromOffset(self.CurrentWindow.Cursor.X, self.CurrentWindow.Cursor.Y),
        Size = UDim2.fromOffset(size.X, size.Y),
        BackgroundColor3 = self.Styles.Primary,
        BorderColor3 = self.Styles.Border,
        BorderSizePixel = self.Sizes.BorderSize,
        Text = text,
        TextColor3 = self.Styles.Text,
        TextSize = self.Sizes.TextSize,
        Font = Enum.Font.Gotham,
        Parent = self.CurrentWindow.Content
    })
    
    local clicked = false
    
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = self.Styles.Hover
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = self.Styles.Primary
    end)
    
    button.MouseButton1Down:Connect(function()
        button.BackgroundColor3 = self.Styles.Active
    end)
    
    button.MouseButton1Up:Connect(function()
        button.BackgroundColor3 = self.Styles.Hover
        clicked = true
    end)
    
    table.insert(self.CurrentWindow.Elements, button)
    self.CurrentWindow.Cursor = Vector2.new(
        self.CurrentWindow.Cursor.X,
        self.CurrentWindow.Cursor.Y + size.Y + self.Sizes.ItemSpacing.Y
    )
    
    return clicked
end

-- Toggle
function ImGui:Toggle(text, state)
    if not self.CurrentWindow then return state end
    
    local toggleSize = self.Sizes.ButtonHeight
    local textSize = self:GetTextSize(text)
    local totalWidth = toggleSize + 8 + textSize.X
    
    local toggleFrame = self:CreateElement("Frame", {
        Name = text .. "Toggle",
        Position = UDim2.fromOffset(self.CurrentWindow.Cursor.X, self.CurrentWindow.Cursor.Y),
        Size = UDim2.fromOffset(totalWidth, toggleSize),
        BackgroundTransparency = 1,
        Parent = self.CurrentWindow.Content
    })
    
    local toggleButton = self:CreateElement("TextButton", {
        Name = "Toggle",
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.fromOffset(toggleSize, toggleSize),
        BackgroundColor3 = state and self.Styles.ToggleOn or self.Styles.ToggleOff,
        BorderColor3 = self.Styles.Border,
        BorderSizePixel = self.Sizes.BorderSize,
        Text = "",
        Parent = toggleFrame
    })
    
    local toggleLabel = self:CreateElement("TextLabel", {
        Name = "Label",
        Position = UDim2.fromOffset(toggleSize + 8, 0),
        Size = UDim2.fromOffset(textSize.X, toggleSize),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = self.Styles.Text,
        TextSize = self.Sizes.TextSize,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = toggleFrame
    })
    
    toggleButton.MouseButton1Click:Connect(function()
        state = not state
        toggleButton.BackgroundColor3 = state and self.Styles.ToggleOn or self.Styles.ToggleOff
    end)
    
    table.insert(self.CurrentWindow.Elements, toggleFrame)
    self.CurrentWindow.Cursor = Vector2.new(
        self.CurrentWindow.Cursor.X,
        self.CurrentWindow.Cursor.Y + toggleSize + self.Sizes.ItemSpacing.Y
    )
    
    return state
end

-- Slider
function ImGui:Slider(text, value, min, max)
    if not self.CurrentWindow then return value end
    
    local sliderHeight = self.Sizes.SliderHeight
    local textSize = self:GetTextSize(text)
    local totalHeight = sliderHeight + textSize.Y + 4
    
    local sliderFrame = self:CreateElement("Frame", {
        Name = text .. "Slider",
        Position = UDim2.fromOffset(self.CurrentWindow.Cursor.X, self.CurrentWindow.Cursor.Y),
        Size = UDim2.fromOffset(150, totalHeight),
        BackgroundTransparency = 1,
        Parent = self.CurrentWindow.Content
    })
    
    local sliderLabel = self:CreateElement("TextLabel", {
        Name = "Label",
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.fromOffset(150, textSize.Y),
        BackgroundTransparency = 1,
        Text = text .. ": " .. string.format("%.2f", value),
        TextColor3 = self.Styles.Text,
        TextSize = self.Sizes.TextSize,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = sliderFrame
    })
    
    local sliderBackground = self:CreateElement("Frame", {
        Name = "Background",
        Position = UDim2.fromOffset(0, textSize.Y + 4),
        Size = UDim2.fromOffset(150, sliderHeight),
        BackgroundColor3 = self.Styles.SliderBackground,
        BorderColor3 = self.Styles.Border,
        BorderSizePixel = self.Sizes.BorderSize,
        Parent = sliderFrame
    })
    
    local fillWidth = ((value - min) / (max - min)) * 150
    local sliderFill = self:CreateElement("Frame", {
        Name = "Fill",
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.fromOffset(fillWidth, sliderHeight),
        BackgroundColor3 = self.Styles.SliderFill,
        BorderSizePixel = 0,
        Parent = sliderBackground
    })
    
    local dragging = false
    
    local function updateSlider(input)
        local relativeX = input.Position.X - sliderBackground.AbsolutePosition.X
        relativeX = math.clamp(relativeX, 0, 150)
        
        local newValue = min + (relativeX / 150) * (max - min)
        value = math.clamp(newValue, min, max)
        
        fillWidth = ((value - min) / (max - min)) * 150
        sliderFill.Size = UDim2.fromOffset(fillWidth, sliderHeight)
        sliderLabel.Text = text .. ": " .. string.format("%.2f", value)
    end
    
    sliderBackground.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            updateSlider(input)
        end
    end)
    
    sliderBackground.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    sliderBackground.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateSlider(input)
        end
    end)
    
    table.insert(self.CurrentWindow.Elements, sliderFrame)
    self.CurrentWindow.Cursor = Vector2.new(
        self.CurrentWindow.Cursor.X,
        self.CurrentWindow.Cursor.Y + totalHeight + self.Sizes.ItemSpacing.Y
    )
    
    return value
end

-- Dropdown
function ImGui:Dropdown(text, options, selectedIndex)
    if not self.CurrentWindow then return selectedIndex end
    
    local dropdownHeight = self.Sizes.ButtonHeight
    local dropdownWidth = 150
    
    local dropdownFrame = self:CreateElement("Frame", {
        Name = text .. "Dropdown",
        Position = UDim2.fromOffset(self.CurrentWindow.Cursor.X, self.CurrentWindow.Cursor.Y),
        Size = UDim2.fromOffset(dropdownWidth, dropdownHeight),
        BackgroundColor3 = self.Styles.Background,
        BorderColor3 = self.Styles.Border,
        BorderSizePixel = self.Sizes.BorderSize,
        Parent = self.CurrentWindow.Content,
        ClipsDescendants = true
    })
    
    local dropdownButton = self:CreateElement("TextButton", {
        Name = "Button",
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.fromOffset(dropdownWidth, dropdownHeight),
        BackgroundColor3 = self.Styles.Background,
        BorderSizePixel = 0,
        Text = selectedIndex and options[selectedIndex] or "Select...",
        TextColor3 = self.Styles.Text,
        TextSize = self.Sizes.TextSize,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = dropdownFrame
    })
    
    local dropdownArrow = self:CreateElement("TextLabel", {
        Name = "Arrow",
        Position = UDim2.new(1, -20, 0, 0),
        Size = UDim2.fromOffset(20, dropdownHeight),
        BackgroundTransparency = 1,
        Text = "▼",
        TextColor3 = self.Styles.Text,
        TextSize = self.Sizes.TextSize - 2,
        Font = Enum.Font.Gotham,
        Parent = dropdownFrame
    })
    
    local dropdownOpen = false
    local dropdownOptionsFrame = self:CreateElement("ScrollingFrame", {
        Name = "Options",
        Position = UDim2.fromOffset(0, dropdownHeight),
        Size = UDim2.fromOffset(dropdownWidth, 0),
        BackgroundColor3 = self.Styles.Background,
        BorderColor3 = self.Styles.Border,
        BorderSizePixel = self.Sizes.BorderSize,
        ScrollBarThickness = 4,
        CanvasSize = UDim2.fromOffset(0, #options * self.Sizes.DropdownItemHeight),
        Visible = false,
        Parent = dropdownFrame
    })
    
    for i, option in ipairs(options) do
        local optionButton = self:CreateElement("TextButton", {
            Name = option,
            Position = UDim2.fromOffset(0, (i-1) * self.Sizes.DropdownItemHeight),
            Size = UDim2.new(1, 0, 0, self.Sizes.DropdownItemHeight),
            BackgroundColor3 = self.Styles.Background,
            BorderSizePixel = 0,
            Text = option,
            TextColor3 = self.Styles.Text,
            TextSize = self.Sizes.TextSize,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = dropdownOptionsFrame
        })
        
        optionButton.MouseButton1Click:Connect(function()
            selectedIndex = i
            dropdownButton.Text = option
            dropdownOpen = false
            dropdownOptionsFrame.Visible = false
            dropdownOptionsFrame.Size = UDim2.fromOffset(dropdownWidth, 0)
        end)
        
        optionButton.MouseEnter:Connect(function()
            optionButton.BackgroundColor3 = self.Styles.Hover
        end)
        
        optionButton.MouseLeave:Connect(function()
            optionButton.BackgroundColor3 = self.Styles.Background
        end)
    end
    
    dropdownButton.MouseButton1Click:Connect(function()
        dropdownOpen = not dropdownOpen
        
        if dropdownOpen then
            self:CloseActiveDropdown()
            self.ActiveDropdown = dropdownFrame
            
            local maxHeight = math.min(#options * self.Sizes.DropdownItemHeight, 120)
            dropdownOptionsFrame.Size = UDim2.fromOffset(dropdownWidth, maxHeight)
            dropdownOptionsFrame.Visible = true
        else
            dropdownOptionsFrame.Size = UDim2.fromOffset(dropdownWidth, 0)
            dropdownOptionsFrame.Visible = false
            self.ActiveDropdown = nil
        end
    end)
    
    -- Close dropdown when clicking elsewhere
    local connection
    connection = game:GetService("UserInputService").InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and dropdownOpen then
            local mousePos = game:GetService("UserInputService"):GetMouseLocation()
            local dropdownPos = dropdownFrame.AbsolutePosition
            local dropdownSize = dropdownFrame.AbsoluteSize
            
            if not (mousePos.X >= dropdownPos.X and mousePos.X <= dropdownPos.X + dropdownSize.X and
                   mousePos.Y >= dropdownPos.Y and mousePos.Y <= dropdownPos.Y + dropdownSize.Y + dropdownOptionsFrame.AbsoluteSize.Y) then
                dropdownOpen = false
                dropdownOptionsFrame.Visible = false
                dropdownOptionsFrame.Size = UDim2.fromOffset(dropdownWidth, 0)
                self.ActiveDropdown = nil
                connection:Disconnect()
            end
        end
    end)
    
    table.insert(self.CurrentWindow.Elements, dropdownFrame)
    self.CurrentWindow.Cursor = Vector2.new(
        self.CurrentWindow.Cursor.X,
        self.CurrentWindow.Cursor.Y + dropdownHeight + self.Sizes.ItemSpacing.Y
    )
    
    return selectedIndex
end

-- Multi Dropdown
function ImGui:MultiDropdown(text, options, selectedIndices)
    if not self.CurrentWindow then return selectedIndices end
    
    selectedIndices = selectedIndices or {}
    local dropdownHeight = self.Sizes.ButtonHeight
    local dropdownWidth = 150
    
    local dropdownFrame = self:CreateElement("Frame", {
        Name = text .. "MultiDropdown",
        Position = UDim2.fromOffset(self.CurrentWindow.Cursor.X, self.CurrentWindow.Cursor.Y),
        Size = UDim2.fromOffset(dropdownWidth, dropdownHeight),
        BackgroundColor3 = self.Styles.Background,
        BorderColor3 = self.Styles.Border,
        BorderSizePixel = self.Sizes.BorderSize,
        Parent = self.CurrentWindow.Content,
        ClipsDescendants = true
    })
    
    local selectedText = ""
    local count = 0
    for i, selected in ipairs(selectedIndices) do
        if selected then
            count = count + 1
            if count <= 2 then
                selectedText = selectedText .. (selectedText == "" and "" or ", ") .. options[i]
            end
        end
    end
    if count > 2 then
        selectedText = selectedText .. " +" .. (count - 2)
    end
    if selectedText == "" then
        selectedText = "Select..."
    end
    
    local dropdownButton = self:CreateElement("TextButton", {
        Name = "Button",
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.fromOffset(dropdownWidth, dropdownHeight),
        BackgroundColor3 = self.Styles.Background,
        BorderSizePixel = 0,
        Text = selectedText,
        TextColor3 = self.Styles.Text,
        TextSize = self.Sizes.TextSize,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = dropdownFrame
    })
    
    local dropdownArrow = self:CreateElement("TextLabel", {
        Name = "Arrow",
        Position = UDim2.new(1, -20, 0, 0),
        Size = UDim2.fromOffset(20, dropdownHeight),
        BackgroundTransparency = 1,
        Text = "▼",
        TextColor3 = self.Styles.Text,
        TextSize = self.Sizes.TextSize - 2,
        Font = Enum.Font.Gotham,
        Parent = dropdownFrame
    })
    
    local dropdownOpen = false
    local dropdownOptionsFrame = self:CreateElement("ScrollingFrame", {
        Name = "Options",
        Position = UDim2.fromOffset(0, dropdownHeight),
        Size = UDim2.fromOffset(dropdownWidth, 0),
        BackgroundColor3 = self.Styles.Background,
        BorderColor3 = self.Styles.Border,
        BorderSizePixel = self.Sizes.BorderSize,
        ScrollBarThickness = 4,
        CanvasSize = UDim2.fromOffset(0, #options * self.Sizes.DropdownItemHeight),
        Visible = false,
        Parent = dropdownFrame
    })
    
    for i, option in ipairs(options) do
        local optionFrame = self:CreateElement("Frame", {
            Name = option,
            Position = UDim2.fromOffset(0, (i-1) * self.Sizes.DropdownItemHeight),
            Size = UDim2.new(1, 0, 0, self.Sizes.DropdownItemHeight),
            BackgroundTransparency = 1,
            Parent = dropdownOptionsFrame
        })
        
        local checkbox = self:CreateElement("Frame", {
            Name = "Checkbox",
            Position = UDim2.fromOffset(4, 4),
            Size = UDim2.fromOffset(16, 16),
            BackgroundColor3 = selectedIndices[i] and self.Styles.Primary or self.Styles.Background,
            BorderColor3 = self.Styles.Border,
            BorderSizePixel = self.Sizes.BorderSize,
            Parent = optionFrame
        })
        
        if selectedIndices[i] then
            self:CreateElement("TextLabel", {
                Name = "Check",
                Position = UDim2.fromOffset(2, 0),
                Size = UDim2.fromOffset(12, 16),
                BackgroundTransparency = 1,
                Text = "✓",
                TextColor3 = self.Styles.Text,
                TextSize = self.Sizes.TextSize,
                Font = Enum.Font.Gotham,
                Parent = checkbox
            })
        end
        
        local optionLabel = self:CreateElement("TextLabel", {
            Name = "Label",
            Position = UDim2.fromOffset(28, 0),
            Size = UDim2.new(1, -28, 1, 0),
            BackgroundTransparency = 1,
            Text = option,
            TextColor3 = self.Styles.Text,
            TextSize = self.Sizes.TextSize,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = optionFrame
        })
        
        optionFrame.MouseButton1Click:Connect(function()
            selectedIndices[i] = not selectedIndices[i]
            
            checkbox.BackgroundColor3 = selectedIndices[i] and self.Styles.Primary or self.Styles.Background
            
            if selectedIndices[i] then
                local check = self:CreateElement("TextLabel", {
                    Name = "Check",
                    Position = UDim2.fromOffset(2, 0),
                    Size = UDim2.fromOffset(12, 16),
                    BackgroundTransparency = 1,
                    Text = "✓",
                    TextColor3 = self.Styles.Text,
                    TextSize = self.Sizes.TextSize,
                    Font = Enum.Font.Gotham,
                    Parent = checkbox
                })
            else
                if checkbox:FindFirstChild("Check") then
                    checkbox.Check:Destroy()
                end
            end
            
            -- Update button text
            local selectedText = ""
            local count = 0
            for j, selected in ipairs(selectedIndices) do
                if selected then
                    count = count + 1
                    if count <= 2 then
                        selectedText = selectedText .. (selectedText == "" and "" or ", ") .. options[j]
                    end
                end
            end
            if count > 2 then
                selectedText = selectedText .. " +" .. (count - 2)
            end
            if selectedText == "" then
                selectedText = "Select..."
            end
            
            dropdownButton.Text = selectedText
        end)
        
        optionFrame.MouseEnter:Connect(function()
            optionFrame.BackgroundColor3 = self.Styles.Hover
        end)
        
        optionFrame.MouseLeave:Connect(function()
            optionFrame.BackgroundColor3 = Color3.new(0, 0, 0)
            optionFrame.BackgroundTransparency = 1
        end)
    end
    
    dropdownButton.MouseButton1Click:Connect(function()
        dropdownOpen = not dropdownOpen
        
        if dropdownOpen then
            self:CloseActiveDropdown()
            self.ActiveDropdown = dropdownFrame
            
            local maxHeight = math.min(#options * self.Sizes.DropdownItemHeight, 120)
            dropdownOptionsFrame.Size = UDim2.fromOffset(dropdownWidth, maxHeight)
            dropdownOptionsFrame.Visible = true
        else
            dropdownOptionsFrame.Size = UDim2.fromOffset(dropdownWidth, 0)
            dropdownOptionsFrame.Visible = false
            self.ActiveDropdown = nil
        end
    end)
    
    -- Close dropdown when clicking elsewhere
    local connection
    connection = game:GetService("UserInputService").InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and dropdownOpen then
            local mousePos = game:GetService("UserInputService"):GetMouseLocation()
            local dropdownPos = dropdownFrame.AbsolutePosition
            local dropdownSize = dropdownFrame.AbsoluteSize
            
            if not (mousePos.X >= dropdownPos.X and mousePos.X <= dropdownPos.X + dropdownSize.X and
                   mousePos.Y >= dropdownPos.Y and mousePos.Y <= dropdownPos.Y + dropdownSize.Y + dropdownOptionsFrame.AbsoluteSize.Y) then
                dropdownOpen = false
                dropdownOptionsFrame.Visible = false
                dropdownOptionsFrame.Size = UDim2.fromOffset(dropdownWidth, 0)
                self.ActiveDropdown = nil
                connection:Disconnect()
            end
        end
    end)
    
    table.insert(self.CurrentWindow.Elements, dropdownFrame)
    self.CurrentWindow.Cursor = Vector2.new(
        self.CurrentWindow.Cursor.X,
        self.CurrentWindow.Cursor.Y + dropdownHeight + self.Sizes.ItemSpacing.Y
    )
    
    return selectedIndices
end

-- Helper function to close active dropdown
function ImGui:CloseActiveDropdown()
    if self.ActiveDropdown then
        local optionsFrame = self.ActiveDropdown:FindFirstChild("Options")
        if optionsFrame then
            optionsFrame.Visible = false
            optionsFrame.Size = UDim2.fromOffset(optionsFrame.AbsoluteSize.X, 0)
        end
        self.ActiveDropdown = nil
    end
end

-- Helper function to calculate text size
function ImGui:GetTextSize(text)
    local textLabel = Instance.new("TextLabel")
    textLabel.Text = text
    textLabel.Font = Enum.Font.Gotham
    textLabel.TextSize = self.Sizes.TextSize
    textLabel.Size = UDim2.fromOffset(0, 0)
    
    -- Approximate text size (Roblox doesn't provide a direct way to measure text)
    local approximateWidth = #text * (self.Sizes.TextSize * 0.6)
    local approximateHeight = self.Sizes.TextSize
    
    textLabel:Destroy()
    
    return Vector2.new(approximateWidth, approximateHeight)
end

-- Label
function ImGui:Label(text)
    if not self.CurrentWindow then return end
    
    local textSize = self:GetTextSize(text)
    
    local label = self:CreateElement("TextLabel", {
        Name = text .. "Label",
        Position = UDim2.fromOffset(self.CurrentWindow.Cursor.X, self.CurrentWindow.Cursor.Y),
        Size = UDim2.fromOffset(textSize.X, textSize.Y),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = self.Styles.Text,
        TextSize = self.Sizes.TextSize,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = self.CurrentWindow.Content
    })
    
    table.insert(self.CurrentWindow.Elements, label)
    self.CurrentWindow.Cursor = Vector2.new(
        self.CurrentWindow.Cursor.X,
        self.CurrentWindow.Cursor.Y + textSize.Y + self.Sizes.ItemSpacing.Y
    )
end

return ImGui
