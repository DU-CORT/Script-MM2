-- [[ SCRIPT MM2 - DU-CORT COMPLETO (ESP + ROLES + GAMEPLAY + SETTINGS + TRADUÇÃO IA) ]]

local success, Fluent = pcall(function()
    return loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
end)

if not success or not Fluent then
    warn("Erro ao carregar a biblioteca Fluent!")
    return
end

-- SISTEMA DE CONFIGURAÇÃO, INTERFACE E TRADUÇÃO
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "DU-CORT V1 | Murder Mystery 2",
    SubTitle = "Indetectavel",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Visuals = Window:AddTab({ Title = "ESP & Roles", Icon = "eye" }),
    Murderer = Window:AddTab({ Title = "Murderer", Icon = "target" }),
    Sheriff = Window:AddTab({ Title = "Sheriff", Icon = "shield" }),
    Gameplay = Window:AddTab({ Title = "Gameplay", Icon = "gamepad-2" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Stats = game:GetService("Stats")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local MM2ESP = {
    RoleESP = false,
    ShowMurderer = true,
    ShowSheriff = true,
    ShowInnocents = false,
    GunESP = false
}

local MurdererSettings = {
    CamLockSheriff = false,
    Locking = false
}

local SheriffSettings = {
    CamLockMurderer = false,
    AutoShootMurderer = false,
    LockingSheriff = false
}

local UtilitySettings = {
    FpsEnabled = false,
    PingEnabled = false
}

--------------------------------------------------------------------------------
-- CRIAR GUI FLUTUANTE PARA FPS E PING NA TELA
--------------------------------------------------------------------------------
local StatsGui = Instance.new("ScreenGui")
StatsGui.Name = "DU_CORT_StatsGui"
StatsGui.ResetOnSpawn = false
StatsGui.Parent = CoreGui

local StatsFrame = Instance.new("Frame")
StatsFrame.Size = UDim2.new(0, 150, 0, 50)
StatsFrame.Position = UDim2.new(0, 10, 0, 10)
StatsFrame.BackgroundTransparency = 0.5
StatsFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
StatsFrame.BorderSizePixel = 0
StatsFrame.Visible = false
StatsFrame.Parent = StatsGui

local StatsLayout = Instance.new("UIListLayout")
StatsLayout.SortOrder = Enum.SortOrder.LayoutOrder
StatsLayout.Padding = UDim.new(0, 2)
StatsLayout.Parent = StatsFrame

local FpsText = Instance.new("TextLabel")
FpsText.Size = UDim2.new(1, 0, 0.5, 0)
FpsText.BackgroundTransparency = 1
FpsText.TextColor3 = Color3.fromRGB(0, 255, 0)
FpsText.TextSize = 14
FpsText.Font = Enum.Font.SourceSansBold
FpsText.TextXAlignment = Enum.TextXAlignment.Left
FpsText.Parent = StatsFrame

local PingText = Instance.new("TextLabel")
PingText.Size = UDim2.new(1, 0, 0.5, 0)
PingText.BackgroundTransparency = 1
PingText.TextColor3 = Color3.fromRGB(255, 255, 0)
PingText.TextSize = 14
PingText.Font = Enum.Font.SourceSansBold
PingText.TextXAlignment = Enum.TextXAlignment.Left
PingText.Parent = StatsFrame

local function UpdateStatsVisibility()
    if UtilitySettings.FpsEnabled or UtilitySettings.PingEnabled then
        StatsFrame.Visible = true
        FpsText.Visible = UtilitySettings.FpsEnabled
        PingText.Visible = UtilitySettings.PingEnabled
    else
        StatsFrame.Visible = false
    end
end

--------------------------------------------------------------------------------
-- ABA 1: ESP & ROLES
--------------------------------------------------------------------------------
Tabs.Visuals:AddToggle("RoleESPToggle", { Title = "Ativar ESP de Papéis (Texto & Distância)", Default = false }):OnChanged(function(v) MM2ESP.RoleESP = v end)
Tabs.Visuals:AddToggle("MurdererToggle", { Title = "Mostrar Murderer (Vermelho)", Default = true }):OnChanged(function(v) MM2ESP.ShowMurderer = v end)
Tabs.Visuals:AddToggle("SheriffToggle", { Title = "Mostrar Sheriff (Azul)", Default = true }):OnChanged(function(v) MM2ESP.ShowSheriff = v end)
Tabs.Visuals:AddToggle("InnocentToggle", { Title = "Mostrar Innocents (Verde)", Default = false }):OnChanged(function(v) MM2ESP.ShowInnocents = v end)
Tabs.Visuals:AddToggle("GunESPToggle", { Title = "ESP da Arma Caída no Chão", Default = false }):OnChanged(function(v) MM2ESP.GunESP = v end)

--------------------------------------------------------------------------------
-- ABA 2: MURDERER
--------------------------------------------------------------------------------
Tabs.Murderer:AddToggle("CamLockToggle", { Title = "Ativar CamLock no Sheriff (Botão Direito)", Default = false }):OnChanged(function(v)
    MurdererSettings.CamLockSheriff = v
end)

Tabs.Murderer:AddButton({
    Title = "Teleportar para o Sheriff",
    Description = "Vai instantaneamente para cima do Sheriff.",
    Callback = function()
        local foundSheriff = false
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local backpack = player:FindFirstChild("Backpack")
                local char = player.Character
                local hasGun = char:FindFirstChild("Gun") or (backpack and backpack:FindFirstChild("Gun"))
                
                if hasGun and char:FindFirstChild("HumanoidRootPart") then
                    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        LocalPlayer.Character.HumanoidRootPart.CFrame = char.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0)
                        foundSheriff = true
                        Fluent:Notify({ Title = "Sucesso", Content = "Teleportado para o Sheriff!", Duration = 3 })
                        break
                    end
                end
            end
        end
        if not foundSheriff then
            Fluent:Notify({ Title = "Aviso", Content = "Sheriff ainda não encontrado ou sem arma.", Duration = 3 })
        end
    end
})

--------------------------------------------------------------------------------
-- ABA 3: SHERIFF
--------------------------------------------------------------------------------
Tabs.Sheriff:AddToggle("CamLockMurdererToggle", { Title = "Ativar CamLock no Murderer (Botão Direito)", Default = false }):OnChanged(function(v)
    SheriffSettings.CamLockMurderer = v
end)

Tabs.Sheriff:AddToggle("AutoShootToggle", { Title = "Auto-Shoot / Silent Aim no Murderer", Default = false }):OnChanged(function(v)
    SheriffSettings.AutoShootMurderer = v
end)

Tabs.Sheriff:AddButton({
    Title = "Teleportar para o Murderer",
    Description = "Vai diretamente para a posição do Murderer.",
    Callback = function()
        local foundMurderer = false
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local backpack = player:FindFirstChild("Backpack")
                local char = player.Character
                local hasKnife = char:FindFirstChild("Knife") or (backpack and backpack:FindFirstChild("Knife"))
                
                if hasKnife and char:FindFirstChild("HumanoidRootPart") then
                    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        LocalPlayer.Character.HumanoidRootPart.CFrame = char.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0)
                        foundMurderer = true
                        Fluent:Notify({ Title = "Sucesso", Content = "Teleportado para o Murderer!", Duration = 3 })
                        break
                    end
                end
            end
        end
        if not foundMurderer then
            Fluent:Notify({ Title = "Aviso", Content = "Murderer ainda não encontrado ou sem faca.", Duration = 3 })
        end
    end
})

--------------------------------------------------------------------------------
-- ABA 4: GAMEPLAY
--------------------------------------------------------------------------------
Tabs.Gameplay:AddButton({
    Title = "Puxar Arma (Vai, Pega e Volta)",
    Description = "Vai até à arma caída, apanha-a e regressa ao sítio original.",
    Callback = function()
        local foundGun = false
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "GunDrop" and obj:IsA("BasePart") then
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    local hrp = char.HumanoidRootPart
                    local originalPos = hrp.CFrame
                    
                    foundGun = true
                    hrp.CFrame = obj.CFrame + Vector3.new(0, 3, 0)
                    task.wait(0.15)
                    hrp.CFrame = originalPos
                    
                    Fluent:Notify({ Title = "Sucesso", Content = "Arma puxada com sucesso!", Duration = 3 })
                    break
                end
            end
        end
        if not foundGun then
            Fluent:Notify({ Title = "Aviso", Content = "Nenhuma arma caída no chão encontrada.", Duration = 3 })
        end
    end
})

--------------------------------------------------------------------------------
-- ABA 5: SETTINGS (IDIOMA IA, FPS, PING, SAVE & RESET)
--------------------------------------------------------------------------------
Tabs.Settings:AddToggle("FpsDisplayToggle", { Title = "Mostrar FPS na Tela", Default = false }):OnChanged(function(v)
    UtilitySettings.FpsEnabled = v
    UpdateStatsVisibility()
end)

Tabs.Settings:AddToggle("PingDisplayToggle", { Title = "Mostrar Ping na Tela", Default = false }):OnChanged(function(v)
    UtilitySettings.PingEnabled = v
    UpdateStatsVisibility()
end)

Tabs.Settings:AddButton({
    Title = "Salvar Configurações (Save Config)",
    Description = "Salva todas as suas preferências atuais.",
    Callback = function()
        SaveManager:Save(Window.Title)
        Fluent:Notify({ Title = "Configurações", Content = "Configurações salvas com sucesso!", Duration = 3 })
    end
})

Tabs.Settings:AddButton({
    Title = "Redefinir Configurações (Reset Config)",
    Description = "Restaura os padrões originais.",
    Callback = function()
        SaveManager:Load()
        Fluent:Notify({ Title = "Configurações", Content = "Configurações redefinidas!", Duration = 3 })
    end
})

-- Integração do Sistema de Idioma e Interface (Tradução IA / Gerenciador de Idiomas da Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:SetLibrary(Fluent)
InterfaceManager:BuildInterfaceSection(Tabs.Settings)

--------------------------------------------------------------------------------
-- DETETAR CLIQUE DO BOTÃO DIREITO DO MOUSE
--------------------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        MurdererSettings.Locking = true
        SheriffSettings.LockingSheriff = true
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        MurdererSettings.Locking = false
        SheriffSettings.LockingSheriff = false
    end
end)

--------------------------------------------------------------------------------
-- LOOP PRINCIPAL (FPS, PING, ESP, CAMLOCKS & AUTO-SHOOT)
--------------------------------------------------------------------------------
local lastUpdate = 0
local frameCount = 0

RunService.RenderStepped:Connect(function(dt)
    -- Atualizador de FPS e Ping na Tela
    frameCount = frameCount + 1
    lastUpdate = lastUpdate + dt
    if lastUpdate >= 1 then
        local fps = math.floor(frameCount / lastUpdate)
        local ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        
        FpsText.Text = " FPS: " .. fps
        PingText.Text = " Ping: " .. ping .. " ms"
        
        frameCount = 0
        lastUpdate = 0
    end

    -- 1. Lógica do ESP Original de Jogadores
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local character = player.Character
            local hrp = character:FindFirstChild("HumanoidRootPart")
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            
            if hrp and humanoid and humanoid.Health > 0 then
                local backpack = player:FindFirstChild("Backpack")
                
                local role = "Innocent"
                local roleColor = Color3.fromRGB(0, 255, 0)
                local showThis = MM2ESP.ShowInnocents

                local hasKnife = (character:FindFirstChild("Knife") or (backpack and backpack:FindFirstChild("Knife")))
                local hasGun = (character:FindFirstChild("Gun") or (backpack and backpack:FindFirstChild("Gun")))

                if hasKnife then
                    role = "Murderer"
                    roleColor = Color3.fromRGB(255, 0, 0)
                    showThis = MM2ESP.ShowMurderer
                elseif hasGun then
                    role = "Sheriff"
                    roleColor = Color3.fromRGB(0, 120, 255)
                    showThis = MM2ESP.ShowSheriff
                end

                local tag = hrp:FindFirstChild("DU_CORT_ESP")
                if MM2ESP.RoleESP and showThis then
                    local distance = math.floor((LocalPlayer.Character.HumanoidRootPart.Position - hrp.Position).Magnitude)
                    
                    if not tag then
                        tag = Instance.new("BillboardGui")
                        tag.Name = "DU_CORT_ESP"
                        tag.Size = UDim2.new(0, 160, 0, 50)
                        tag.StudsOffset = Vector3.new(0, 3, 0)
                        tag.AlwaysOnTop = true
                        tag.Parent = hrp
                        
                        local textLabel = Instance.new("TextLabel")
                        textLabel.Name = "Text"
                        textLabel.Size = UDim2.new(1, 0, 1, 0)
                        textLabel.BackgroundTransparency = 1
                        textLabel.TextSize = 13
                        textLabel.Font = Enum.Font.SourceSansBold
                        textLabel.TextStrokeTransparency = 0
                        textLabel.Parent = tag
                    end
                    
                    local txt = tag:FindFirstChild("Text")
                    if txt then
                        txt.Text = player.Name .. " [" .. role .. "]\n[" .. distance .. "m]"
                        txt.TextColor3 = roleColor
                    end
                    tag.Enabled = true
                else
                    if tag then
                        tag.Enabled = false
                    end
                end
            end
        end
    end

    -- 2. Lógica de ESP de Arma Caída
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "GunDrop" and obj:IsA("BasePart") then
            local gunTag = obj:FindFirstChild("DU_CORT_GunESP")
            if MM2ESP.GunESP then
                if not gunTag then
                    gunTag = Instance.new("BillboardGui")
                    gunTag.Name = "DU_CORT_GunESP"
                    gunTag.Size = UDim2.new(0, 120, 0, 40)
                    gunTag.StudsOffset = Vector3.new(0, 2, 0)
                    gunTag.AlwaysOnTop = true
                    gunTag.Parent = obj
                    
                    local txt = Instance.new("TextLabel")
                    txt.Name = "Text"
                    txt.Size = UDim2.new(1, 0, 1, 0)
                    txt.BackgroundTransparency = 1
                    txt.TextSize = 14
                    txt.Font = Enum.Font.SourceSansBold
                    txt.TextColor3 = Color3.fromRGB(255, 255, 0)
                    txt.TextStrokeTransparency = 0
                    txt.Text = "[ ARMA CAÍDA ]"
                    txt.Parent = gunTag
                end
                gunTag.Enabled = true
            else
                if gunTag then
                    gunTag.Enabled = false
                end
            end
        end
    end

    -- 3. CamLock do Murderer no Sheriff
    if MurdererSettings.CamLockSheriff and MurdererSettings.Locking then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local backpack = player:FindFirstChild("Backpack")
                local char = player.Character
                local hasGun = char:FindFirstChild("Gun") or (backpack and backpack:FindFirstChild("Gun"))
                
                if hasGun and char:FindFirstChild("HumanoidRootPart") then
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, char.HumanoidRootPart.Position)
                    break
                end
            end
        end
    end

    -- 4. CamLock do Sheriff no Murderer
    if SheriffSettings.CamLockMurderer and SheriffSettings.LockingSheriff then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local backpack = player:FindFirstChild("Backpack")
                local char = player.Character
                local hasKnife = char:FindFirstChild("Knife") or (backpack and backpack:FindFirstChild("Knife"))
                
                if hasKnife and char:FindFirstChild("HumanoidRootPart") then
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, char.HumanoidRootPart.Position)
                    break
                end
            end
        end
    end

    -- 5. Auto-Shoot / Silent Aim do Sheriff no Murderer
    if SheriffSettings.AutoShootMurderer then
        local localChar = LocalPlayer.Character
        local gun = localChar and (localChar:FindFirstChild("Gun") or (LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Gun")))
        if gun then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local backpack = player:FindFirstChild("Backpack")
                    local char = player.Character
                    local hasKnife = char:FindFirstChild("Knife") or (backpack and backpack:FindFirstChild("Knife"))
                    
                    if hasKnife and char:FindFirstChild("HumanoidRootPart") then
                        local tool = localChar:FindFirstChildOfClass("Tool")
                        if tool and tool.Name == "Gun" then
                            local args = {
                                [1] = 1,
                                [2] = char.HumanoidRootPart.Position,
                                [3] = "AH"
                            }
                            pcall(function()
                                tool.Shoot:FireServer(unpack(args))
                            end)
                        end
                        break
                    end
                end
            end
        end
    end
end)

-- Carregar salvamentos automáticos
SaveManager:LoadAutoloadConfig()

Window:SelectTab(1)
Fluent:Notify({
    Title = "DU-CORT",
    Content = "Tudo carregado com sucesso!",
    Duration = 4
})
