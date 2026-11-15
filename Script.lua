-- MM2 module. Experimental adapters; no anticheat bypass or account protection.
local env=type(getgenv)=='function' and getgenv() or _G
if type(env.MM2Cleanup)=='function' then pcall(env.MM2Cleanup) end
-- Shared black/violet shell for this project. Embedded by build.cjs.
local function create_project_gui(title, subtitle)
    local env = type(getgenv) == 'function' and getgenv() or _G
    if type(env.MM2GuiCleanup) == 'function' then pcall(env.MM2GuiCleanup) end
    local url = 'https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua'
    local ok, code = pcall(function() return game:HttpGet(url) end)
    if not ok or type(code) ~= 'string' or code == '' then
        local transport = request or http_request
        assert(type(transport) == 'function', 'Nao foi possivel baixar a interface.')
        local response = transport({Url=url,Method='GET'})
        assert(response and tonumber(response.StatusCode)==200, 'Falha ao baixar a interface.')
        code = response.Body
    end
    local chunk, err = loadstring(code, 'Universal_GUI')
    assert(chunk, err)
    local Fluent = chunk()
    local window = Fluent:CreateWindow({
        Title=title, SubTitle=subtitle, TabWidth=160,
        Size=UDim2.fromOffset(620,450), Acrylic=false,
        Theme='Amethyst', MinimizeKey=Enum.KeyCode.RightShift,
    })
    local connections, stopped = {}, false
    local function cleanup()
        if stopped then return end
        stopped=true
        for _,connection in ipairs(connections) do connection:Disconnect() end
        if env.MM2GuiCleanup==cleanup then env.MM2GuiCleanup=nil end
        if not Fluent.Unloaded then Fluent:Destroy() end
    end
    env.MM2GuiCleanup=cleanup
    if Fluent.GUI then connections[#connections+1]=Fluent.GUI.Destroying:Connect(cleanup) end
    local function apply_theme()
        local themeOk, themeError=pcall(function()
    -- ZYON_BLACK_PURPLE_UI_BEGIN
do
    -- Keep Fluent's control callbacks and navigation; customize the surrounding shell.
    local purple = Color3.fromRGB(155, 105, 245)
    local root = window.Root
    local paint = window.AcrylicPaint.Frame
    local tab_width = tonumber(window.TabWidth) or 160
    local function frame(name, parent, position, size, color)
        local object = Instance.new('Frame')
        object.Name = name
        object.BorderSizePixel = 0
        object.BackgroundColor3 = color
        object.Position = position
        object.Size = size
        object.Active = false
        object.Parent = parent
        return object
    end
    -- Draw behind the interactive tabs and content, on the window's paint layer.
    local sidebar = frame('ZyonSidebar', paint, UDim2.fromOffset(1, 43),
        UDim2.new(0, tab_width + 20, 1, -52), Color3.fromRGB(5, 5, 8))
    local divider = frame('ZyonSidebarDivider', paint, UDim2.fromOffset(tab_width + 21, 43),
        UDim2.new(0, 1, 1, -52), Color3.fromRGB(48, 34, 66))
    local accent = frame('ZyonHeaderAccent', root, UDim2.fromOffset(12, 42),
        UDim2.new(1, -24, 0, 2), purple)
    accent.ZIndex = 3
    local gradient = Instance.new('UIGradient')
    gradient.Color = ColorSequence.new(purple, Color3.fromRGB(49, 24, 79))
    gradient.Parent = accent
    window.TabDisplay.TextSize = 24
    local function apply_shell()
        if stopped or not root.Parent then return end
        paint.BackgroundColor3 = Color3.fromRGB(8, 8, 11)
        paint.BackgroundTransparency = 0
        for _, child in ipairs(paint:GetChildren()) do
            if child.Name == 'Background' and child:IsA('Frame') then
                child.BackgroundColor3 = Color3.fromRGB(8, 8, 11)
                child.BackgroundTransparency = 0
            elseif child:IsA('Frame') and child:FindFirstChildOfClass('UIGradient') then
                -- Remove the library's purple wash so black remains the primary color.
                child.Visible = false
            elseif child:IsA('ImageLabel') and child.ScaleType == Enum.ScaleType.Tile then
                child.Visible = false
            end
        end
    end
    -- Fluent refreshes theme properties when controls/dialogs are created.
    local queued = false
    connections[#connections + 1] = Fluent.GUI.DescendantAdded:Connect(function()
        if queued or stopped then return end
        queued = true
        task.defer(function() queued = false; apply_shell() end)
    end)
    apply_shell()
end
-- ZYON_BLACK_PURPLE_UI_END

        end)
        if not themeOk then warn('Universal: tema personalizado indisponivel: '..tostring(themeError)) end
        return themeOk
    end
    return {Library=Fluent,Window=window,Close=cleanup,ApplyTheme=apply_theme,IsClosed=function() return stopped or Fluent.Unloaded end}
end

local MM2Logic={}
function MM2Logic.normalize_role(value)
    if type(value)~='table' or value.Killed==true or value.Dead==true then return 'Unknown',false end
    local role=value.Role
    if role=='Murderer' or role=='Sheriff' or role=='Hero' or role=='Innocent' then return role,true end
    return 'Unknown',false
end
function MM2Logic.movement(cfg,role)
    if (cfg.kill or cfg.killSheriff) and role=='Murderer' then return 'kill' end
    if cfg.grab and role=='Innocent' then return 'grab' end
end
function MM2Logic.choose_target(candidates,history)
    local selected,oldest
    for _,candidate in ipairs(candidates)do
        local tried=history[candidate]or -math.huge
        if not selected or tried<oldest then selected=candidate;oldest=tried end
    end
    return selected
end
MM2Logic.r6={{'Head','Torso'},{'Torso','Left Arm'},{'Torso','Right Arm'},{'Torso','Left Leg'},{'Torso','Right Leg'}}
MM2Logic.r15={{'Head','UpperTorso'},{'UpperTorso','LowerTorso'},
    {'UpperTorso','LeftUpperArm'},{'LeftUpperArm','LeftLowerArm'},{'LeftLowerArm','LeftHand'},
    {'UpperTorso','RightUpperArm'},{'RightUpperArm','RightLowerArm'},{'RightLowerArm','RightHand'},
    {'LowerTorso','LeftUpperLeg'},{'LeftUpperLeg','LeftLowerLeg'},{'LeftLowerLeg','LeftFoot'},
    {'LowerTorso','RightUpperLeg'},{'RightUpperLeg','RightLowerLeg'},{'RightLowerLeg','RightFoot'}}
function MM2Logic.can_shoot(localRole,targetRole,equipped,visible)
    return (localRole=='Sheriff' or localRole=='Hero') and targetRole=='Murderer' and equipped and visible
end

local MM2Text={
["Sheriff"]={"Sheriff","Sheriff","Sheriff","Шериф","警长"},
["Murder"]={"Murderer","Murder","Murder","Убийца","凶手"},
["Inocentes"]={"Innocents","Inocentes","Inocentes","Мирные","平民"},
["ESP"]={"ESP","ESP","ESP","ESP","ESP"},
["Configuracoes"]={"Settings","Configurações","Definições","Настройки","设置"},
["Aimbot no Murderer"]={"Aim at murderer","Aimbot no Murderer","Mira no assassino","Прицел на убийцу","瞄准凶手"},
["Tecla do aimbot (segurar)"]={"Aim key (hold)","Tecla do aimbot (segurar)","Tecla da mira (manter premida)","Клавиша прицела (удерживать)","瞄准按键（按住）"},
["Raio do FOV"]={"FOV radius","Raio do FOV","Raio do FOV","Радиус FOV","瞄准范围半径"},
["Suavizacao da mira"]={"Aim smoothing","Suavização da mira","Suavização da mira","Плавность прицела","瞄准平滑度"},
["Silent aim no Murderer"]={"Silent shot at murderer","Silent aim no Murderer","Disparo silencioso no assassino","Выстрел без поворота камеры","静默射击凶手"},
["Tecla do disparo silent (pressionar)"]={"Silent shot key (press)","Tecla do disparo silent (pressionar)","Tecla de disparo silencioso (premir)","Клавиша выстрела (нажать)","静默射击按键（按下）"},
["Antecipacao do disparo"]={"Shot prediction","Antecipação do disparo","Antecipação do disparo","Упреждение выстрела","射击预判"},
["Auto kill Sheriff"]={"Auto attack sheriff","Auto kill Sheriff","Atacar o xerife automaticamente","Автоатака шерифа","自动攻击警长"},
["Pegar arma do Sheriff"]={"Retrieve sheriff's gun","Pegar arma do Sheriff","Recolher arma do xerife","Подобрать оружие шерифа","拾取警长的枪"},
["ESP box 3D"]={"3D box ESP","ESP box 3D","ESP caixa 3D","3D-рамки ESP","3D方框透视"},
["ESP linhas"]={"Tracer ESP","ESP linhas","ESP linhas","Линии ESP","连线透视"},
["Origem das linhas"]={"Tracer origin","Origem das linhas","Origem das linhas","Начало линий","连线起点"},
["Cima"]={"Top","Cima","Cima","Сверху","顶部"},
["Baixo"]={"Bottom","Baixo","Baixo","Снизу","底部"},
["Meio"]={"Middle","Meio","Meio","По центру","中间"},
["ESP funcoes"]={"Role ESP","ESP funções","ESP funções","Роли ESP","角色身份透视"},
["ESP arma caida"]={"Dropped gun ESP","ESP arma caída","ESP arma caída","ESP выпавшего оружия","掉落枪械透视"},
["Idioma"]={"Language","Idioma","Idioma","Язык","语言"},
["Exibir FPS"]={"Show FPS","Exibir FPS","Mostrar FPS","Показывать FPS","显示帧率"},
["Exibir ping"]={"Show ping","Exibir ping","Mostrar ping","Показывать пинг","显示延迟"},
["Status"]={"Status","Status","Estado","Состояние","状态"},
["Desligado"]={"Off","Desligado","Desligado","Выключено","已关闭"},
["Como usar"]={"How to use","Como usar","Como utilizar","Как использовать","使用说明"},
["Aimbot: segure a tecla escolhida. Silent: equipe a arma e pressione a tecla propria. Nao gira a camera. Sem alvo confirmado, nao dispara."]={"Aim tracks the confirmed target within FOV. Enable Require aim key for hold mode. Silent: equip the gun and press its key.","A mira acompanha o alvo confirmado dentro do FOV. Ative Exigir tecla para usar o modo segurar. Silent: equipe a arma e pressione sua tecla.","A mira acompanha o alvo confirmado no FOV. Ative Exigir tecla para manter premida. Silent: equipe a arma e prima a tecla.","Прицел следит за подтверждённой целью в FOV. Включите требование клавиши для режима удержания. Для скрытого выстрела возьмите оружие и нажмите клавишу.","瞄准会跟踪范围内已确认的目标。启用按键要求可使用按住模式。静默射击：装备枪并按对应按键。"},
["Diagnostico"]={"Diagnostics","Diagnóstico","Diagnóstico","Диагностика","诊断"},
["Aguardando dados da rodada"]={"Waiting for round data","Aguardando dados da rodada","A aguardar dados da ronda","Ожидание данных раунда","等待回合数据"},
["Falha de movimento"]={"Movement failed","Falha de movimento","Falha de movimento","Ошибка движения","移动失败"},
["Funcoes indisponiveis"]={"Roles unavailable","Funções indisponíveis","Funções indisponíveis","Роли недоступны","身份数据不可用"},
["Dados da rodada recebidos"]={"Round data received","Dados da rodada recebidos","Dados da ronda recebidos","Данные раунда получены","已收到回合数据"},
["Equipe a arma"]={"Equip your gun; a target is required","Equipe a arma; é necessário um alvo","Equipe a arma; é necessário um alvo","Возьмите оружие; нужна цель","请装备枪并确认有目标"},
["Sem alvo visivel"]={"No visible confirmed target","Sem alvo confirmado visível","Sem alvo confirmado visível","Нет видимой подтверждённой цели","没有可见的确认目标"},
["Arma incompativel"]={"Unsupported gun interface","Arma incompatível","Arma incompatível","Интерфейс оружия не поддерживается","不支持此枪械接口"},
["Disparo solicitado"]={"Shot requested","Disparo solicitado","Disparo solicitado","Выстрел запрошен","已请求射击"},
["Falha no disparo"]={"Shot request failed","Falha no disparo","Falha no disparo","Ошибка запроса выстрела","射击请求失败"},
["Murderer"]={"Murderer","Assassino","Assassino","Убийца","凶手"},
["Hero"]={"Hero","Herói","Herói","Герой","英雄"},
["Innocent"]={"Innocent","Inocente","Inocente","Мирный","平民"},
["Unknown"]={"Unknown","Desconhecido","Desconhecido","Неизвестно","未知"},
["Arma caida"]={"Dropped gun","Arma caída","Arma caída","Выпавшее оружие","掉落的枪"},
["Fechar e limpar"]={"Close and clean up","Fechar e limpar","Fechar e limpar","Закрыть и очистить","关闭并清理"},
["Jogo diferente"]={"Unsupported place","Jogo diferente","Jogo diferente","Другая игра","不支持此场景"},
["Aguardando funcao compativel"]={"Waiting for a compatible role","Aguardando função compatível","A aguardar função compatível","Ожидание подходящей роли","等待适用身份"},
["Buscando arma"]={"Walking to the gun","Buscando arma","A procurar arma","Движение к оружию","正在走向枪"},
["Aguardando arma"]={"Waiting for a dropped gun","Aguardando arma","A aguardar arma","Ожидание выпавшего оружия","等待掉落的枪"},
["Perseguindo Sheriff"]={"Chasing sheriff","Perseguindo Sheriff","A perseguir xerife","Погоня за шерифом","正在追击警长"},
["Aguardando Sheriff"]={"Waiting for sheriff","Aguardando Sheriff","A aguardar xerife","Ожидание шерифа","等待警长"},
["Ataque solicitado"]={"Attack requested","Ataque solicitado","Ataque solicitado","Атака запрошена","已请求攻击"},
["Falha"]={"Error","Falha","Falha","Ошибка","错误"},
["Exigir tecla para mirar"]={"Require aim key","Exigir tecla para mirar","Exigir tecla para apontar","Требовать клавишу прицела","需要按住瞄准键"},
["Aimbot no Sheriff"]={"Aim at sheriff","Aimbot no Sheriff","Mira no xerife","Прицел на шерифа","瞄准警长"},
["Perigo"]={"Danger","Perigo","Perigo","Опасность","危险"},
["Auto kill todos"]={"Auto attack everyone","Auto kill todos","Atacar todos","Автоатака всех","自动攻击所有人"},
["ESP esqueleto"]={"Skeleton ESP","ESP esqueleto","ESP esqueleto","Скелет ESP","骨骼透视"},
["Auto kill Murderer (requer arma)"]={"Auto attack murderer (gun required)","Auto kill Murderer (requer arma)","Atacar assassino (requer arma)","Автоатака убийцы (нужно оружие)","自动攻击凶手（需要枪）"},
["Aguardando alvo"]={"Waiting for target","Aguardando alvo","A aguardar alvo","Ожидание цели","等待目标"},
["Indisponivel como inocente: nenhum metodo validado de dano ou void."]={"Unavailable as innocent: no validated damage or void method.","Indisponível como inocente: nenhum método validado de dano ou void.","Indisponível como inocente: sem método validado de dano ou void.","Недоступно для мирного: нет проверенного способа нанести урон или сбросить в пустоту.","平民不可用：尚无已验证的伤害或虚空方法。"},
["Tenta recolher a arma caida e atacar o Murderer visivel. Sem arma, aguarda. Nao elimina jogadores desarmado."]={"Tries to retrieve the dropped gun and attack the visible murderer. Waits without a gun. Cannot eliminate players unarmed.","Tenta recolher a arma caída e atacar o Murderer visível. Sem arma, aguarda. Não elimina jogadores desarmado.","Tenta recolher a arma caída e atacar o assassino visível. Sem arma, aguarda. Não elimina jogadores desarmado.","Пытается подобрать оружие и атаковать видимого убийцу. Без оружия ждёт. Не устраняет игроков без оружия.","尝试拾取掉落的枪并攻击可见的凶手。没有枪时等待，无法在无武器时消灭玩家。"},
["Auto kill Murderer"]={"Auto attack murderer","Auto kill Murderer","Atacar assassino","Автоатака убийцы","自动攻击凶手"},
["Ligado"]={"On","Ligado","Ligado","Включено","已开启"},
["Exibir botao: Silent aim no Murderer"]={"Show button: Silent shot at murderer","Exibir botão: Silent aim no Murderer","Mostrar botão: Disparo silencioso no assassino","Показать кнопку: Выстрел без поворота камеры","显示按钮：静默射击凶手"},
["Exibir botao: Auto kill Murderer"]={"Show button: Auto attack murderer","Exibir botão: Auto kill Murderer","Mostrar botão: Atacar assassino","Показать кнопку: Автоатака убийцы","显示按钮：自动攻击凶手"},
["Exibir botao: Auto kill todos"]={"Show button: Auto attack everyone","Exibir botão: Auto kill todos","Mostrar botão: Atacar todos","Показать кнопку: Автоатака всех","显示按钮：自动攻击所有人"},
["Exibir botao: Auto kill Sheriff"]={"Show button: Auto attack sheriff","Exibir botão: Auto kill Sheriff","Mostrar botão: Atacar o xerife automaticamente","Показать кнопку: Автоатака шерифа","显示按钮：自动攻击警长"},
["Player"]={"Player","Player","Jogador","Игрок","玩家"},
["Speed booster"]={"Speed booster","Speed booster","Aumento de velocidade","Ускорение","移动加速"},
["Jump booster"]={"Jump booster","Jump booster","Aumento de salto","Усиление прыжка","跳跃增强"},
["Fly"]={"Fly","Fly","Voar","Полёт","飞行"},
["No clip"]={"No clip","No clip","Atravessar paredes","Полёт сквозь стены","穿墙飞行"},
["Velocidade"]={"Speed","Velocidade","Velocidade","Скорость","速度"},
["Forca do pulo"]={"Jump strength","Força do pulo","Força do salto","Сила прыжка","跳跃力度"},
["Velocidade do voo"]={"Flight speed","Velocidade do voo","Velocidade do voo","Скорость полёта","飞行速度"},
["Velocidade do no clip"]={"Noclip flight speed","Velocidade do no clip","Velocidade de voo sem colisão","Скорость полёта сквозь стены","穿墙飞行速度"}
}
local Players=game:GetService('Players')
local Run=game:GetService('RunService')
local Input=game:GetService('UserInputService')
local Replicated=game:GetService('ReplicatedStorage')
local Http=game:GetService('HttpService')
local player=Players.LocalPlayer
local app=create_project_gui('<font color="#B58AFF"><b>MM2</b></font>','UNIVERSAL')
local cfg={aim=false,silent=false,kill=false,grab=false,box=false,tracer=false,roles=false,gun=false,fps=false,ping=false,prediction=0.08,origin='Baixo',locale=2}
cfg.skeleton=false;cfg.sheriffAuto=false;cfg.killSheriff=false
cfg.mobileSilent=false
cfg.speedBoost=false;cfg.jumpBoost=false;cfg.fly=false;cfg.noclip=false
cfg.playerSpeed=28;cfg.jumpPower=70;cfg.flySpeed=35;cfg.noclipSpeed=35
local stopped=false
local connections={}
local cleanupCallbacks={}
local function T(key)return MM2Text[key] and MM2Text[key][cfg.locale] or key end
local function addSignal(signal,fn)local c=signal:Connect(fn);connections[#connections+1]=c;return c end
local function create(class,parent,props)
    local o=Instance.new(class);for k,v in pairs(props or {})do o[k]=v end;o.Parent=parent;return o
end
local tabs={}
for _,title in ipairs({'Sheriff','Murder','Inocentes','ESP','Player','Configuracoes'})do tabs[title]=app.Window:AddTab({Title=title,Icon='layers'})end
local statuses={}
local lastStatus={}
local statusState={}
local function status(tab,key,detail)
    statusState[tab]={key,detail}
    local text=T(key)..(detail and (' '..tostring(detail)) or '')
    if not stopped and text~=lastStatus[tab]then statuses[tab]:SetDesc(text);lastStatus[tab]=text end
end
local controls={}
local motionKeys={grab=true,kill=true,killSheriff=true,sheriffAuto=true,fly=true,noclip=true}
local motionChanged=function()end
local refreshFloating=function()end
local function toggle(tab,key,title)
    local o=tabs[tab]:AddToggle('MM2_'..key,{Title=title,Default=false})
    controls[key]=o
    o:OnChanged(function(v)
        cfg[key]=v
        if motionKeys[key]then
            motionChanged(key,v)
            if v then
                for other in pairs(motionKeys)do
                    if other~=key and cfg[other]and controls[other]then controls[other]:SetValue(false)end
                end
            end
        end
        if (key=='silent'or key=='show_silent')and not v then cfg.mobileSilent=false end
        refreshFloating()
    end);return o
end
toggle('Sheriff','silent','Silent aim no Murderer')
toggle('Sheriff','show_silent','Exibir botao: Silent aim no Murderer')
local silentKey=tabs.Sheriff:AddKeybind('MM2SilentKey',{Title='Tecla do disparo silent (pressionar)',Default='G',Mode='Hold'})
toggle('Sheriff','sheriffAuto','Auto kill Murderer')
toggle('Sheriff','show_sheriffAuto','Exibir botao: Auto kill Murderer')
toggle('Murder','kill','Auto kill todos')
toggle('Murder','show_kill','Exibir botao: Auto kill todos')
toggle('Murder','killSheriff','Auto kill Sheriff')
toggle('Murder','show_killSheriff','Exibir botao: Auto kill Sheriff')
toggle('Inocentes','grab','Pegar arma do Sheriff')
toggle('ESP','skeleton','ESP esqueleto')
toggle('ESP','box','ESP box 3D')
toggle('ESP','tracer','ESP linhas')
local origin=tabs.ESP:AddDropdown('MM2TracerOrigin',{Title='Origem das linhas',Values={'Cima','Baixo','Meio'},Default=2,Multi=false})
origin:OnChanged(function(v)cfg.origin=v end)
toggle('ESP','roles','ESP funcoes')
toggle('ESP','gun','ESP arma caida')

toggle('Player','speedBoost','Speed booster')
tabs.Player:AddSlider('MM2PlayerSpeed',{Title='Velocidade',Default=28,Min=16,Max=100,Rounding=0,Callback=function(v)cfg.playerSpeed=v end})
toggle('Player','jumpBoost','Jump booster')
tabs.Player:AddSlider('MM2JumpPower',{Title='Forca do pulo',Default=70,Min=30,Max=150,Rounding=0,Callback=function(v)cfg.jumpPower=v end})
toggle('Player','fly','Fly')
tabs.Player:AddSlider('MM2FlySpeed',{Title='Velocidade do voo',Default=35,Min=5,Max=120,Rounding=0,Callback=function(v)cfg.flySpeed=v end})
toggle('Player','noclip','No clip')
tabs.Player:AddSlider('MM2NoclipSpeed',{Title='Velocidade do no clip',Default=35,Min=5,Max=120,Rounding=0,Callback=function(v)cfg.noclipSpeed=v end})
local language=tabs.Configuracoes:AddDropdown('MM2Language',{Title='Idioma',Values={'English','Português BR','Português','Русский','中文'},Default=2,Multi=false})
toggle('Configuracoes','fps','Exibir FPS')
toggle('Configuracoes','ping','Exibir ping')
for _,name in ipairs({'Sheriff','Murder','Inocentes'})do statuses[name]=tabs[name]:AddParagraph({Title='Status',Content=T('Desligado')})end
local diagnostic=tabs.Configuracoes:AddParagraph({Title='Diagnostico',Content='Aguardando dados da rodada'})
local focused=true
local roleData,roleStamp={},-math.huge
local roleBusy=false
local roleError='Aguardando dados da rodada'
local roleGetter
local supported=game.PlaceId==142823291
local guns={}
local entries={}
local shotBusy=false
local lastShot=-math.huge
local folder=create('Folder',workspace,{Name='MM2_Visuals_'..Http:GenerateGUID(false)})
local overlay=create('ScreenGui',player:WaitForChild('PlayerGui'),{Name='MM2Overlay',ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=21})
pcall(function()overlay.ScreenInsets=Enum.ScreenInsets.None end)
local metrics=create('TextLabel',overlay,{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-16,0,46),Size=UDim2.fromOffset(230,28),BackgroundColor3=Color3.fromRGB(12,9,18),BackgroundTransparency=.15,TextColor3=Color3.fromRGB(205,170,255),Font=Enum.Font.GothamMedium,TextSize=14,Visible=false})
create('UICorner',metrics,{CornerRadius=UDim.new(0,6)})
local floating={}
local floatingSpecs={
    {'silent','Silent aim no Murderer'},
    {'sheriffAuto','Auto kill Murderer'},
    {'kill','Auto kill todos'},
    {'killSheriff','Auto kill Sheriff'},
}
for index,spec in ipairs(floatingSpecs)do
    local key,title=spec[1],spec[2]
    local view=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800,600)
    local panel=create('Frame',overlay,{Visible=false,Size=UDim2.fromOffset(158,54),
        Position=UDim2.fromOffset(math.max(0,view.X-178),math.max(0,math.min(70+(index-1)*59,view.Y-56))),
        BackgroundColor3=Color3.fromRGB(17,12,25),BorderSizePixel=0,Active=true,ZIndex=30})
    create('UICorner',panel,{CornerRadius=UDim.new(0,9)})
    local grip=create('TextLabel',panel,{Size=UDim2.new(1,0,0,15),BackgroundTransparency=1,
        Text='•••',TextSize=15,TextColor3=Color3.fromRGB(183,141,245),Active=true,ZIndex=32})
    local button=create('TextButton',panel,{Position=UDim2.fromOffset(4,15),Size=UDim2.new(1,-8,1,-19),
        BackgroundTransparency=1,TextWrapped=true,TextSize=12,Font=Enum.Font.GothamMedium,
        TextColor3=Color3.fromRGB(235,223,255),ZIndex=31})
    floating[key]={panel=panel,button=button,title=title}
    addSignal(button.Activated,function()
        if stopped then return end
        local value=not cfg[key]
        if key=='silent'then cfg.mobileSilent=value end
        controls[key]:SetValue(value)
    end)
    local dragging,start,panelStart
    addSignal(grip.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging=input;start=input.Position;panelStart=panel.Position
        end
    end)
    addSignal(Input.InputChanged,function(input)
        if not dragging or not panel.Visible then return end
        if input~=dragging and input.UserInputType~=Enum.UserInputType.MouseMovement then return end
        local delta=input.Position-start
        local camera=workspace.CurrentCamera;if not camera then return end
        local size=camera.ViewportSize
        panel.Position=UDim2.fromOffset(math.clamp(panelStart.X.Offset+delta.X,0,math.max(0,size.X-158)),
            math.clamp(panelStart.Y.Offset+delta.Y,0,math.max(0,size.Y-54)))
    end)
    addSignal(Input.InputEnded,function(input)
        if input==dragging or input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=nil end
    end)
end
refreshFloating=function()
    for key,item in pairs(floating)do
        item.panel.Visible=cfg['show_'..key]==true
        item.button.Text=T(item.title)..'\n'..T(cfg[key]and 'Ligado'or 'Desligado')
        item.panel.BackgroundColor3=cfg[key]and Color3.fromRGB(78,37,125)or Color3.fromRGB(17,12,25)
    end
end
refreshFloating()

local function living(p)
    local c=p and p.Character
    local h=c and c:FindFirstChildOfClass('Humanoid')
    local r=c and c:FindFirstChild('HumanoidRootPart')
    if h and r and r:IsA('BasePart') and h.Health>0 then return c,h,r end
end
local function tool(p,name)
    local c=p and p.Character;local backpack=p and p:FindFirstChild('Backpack')
    local item=(c and c:FindFirstChild(name)) or (backpack and backpack:FindFirstChild(name))
    return item and item:IsA('Tool') and item or nil
end
local function role(p)
    if not living(p) then return 'Unknown',false end
    -- A current weapon is stronger evidence than the previous round's cached role.
    if tool(p,'Knife') then return 'Murderer',true end
    if tool(p,'Gun') then
        local data=roleData[p.Name]
        return type(data)=='table' and data.Role=='Hero' and 'Hero' or 'Sheriff',true
    end
    if os.clock()-roleStamp<5 then
        local data=roleData[p.Name]
        if data then return MM2Logic.normalize_role(data) end
    end
    if not living(p) then return 'Unknown',false end
    if tool(p,'Knife') then return 'Murderer',true end
    if tool(p,'Gun') then return 'Sheriff',true end
    return 'Unknown',false
end
local function target_role(wanted)
    for _,p in ipairs(Players:GetPlayers())do
        if p~=player and living(p)then local value,active=role(p);if active and (value==wanted or wanted=='Sheriff' and value=='Hero')then return p end end
    end
end
local function part_of(object)
    if not object or not object:IsDescendantOf(workspace)then return end
    if object:IsA('BasePart')then return object end
    if object:IsA('Model')then return object.PrimaryPart or object:FindFirstChildWhichIsA('BasePart',true)end
    if object:IsA('Folder')then return object:FindFirstChildWhichIsA('BasePart',true)end
end
local function discover(object)
    local ancestor=object
    while ancestor and ancestor~=workspace do
        if ancestor.Name=='GunDrop' and part_of(ancestor)then guns[ancestor]=true;return end
        ancestor=ancestor.Parent
    end
end
local function nearest(set,position)
    local best,distance
    for object in pairs(set)do
        local part=part_of(object)
        if not part then set[object]=nil
        else
            local d=(part.Position-position).Magnitude
            if not distance or d<distance then best=object;distance=d end
        end
    end
    return best,distance
end
addSignal(workspace.DescendantAdded,discover)
addSignal(workspace.DescendantRemoving,function(o)guns[o]=nil end)
task.spawn(function()
    for i,o in ipairs(workspace:GetDescendants())do
        if stopped then return end;discover(o)
        if i%400==0 then task.wait()end
    end
end)
local function line_of_sight(position,target)
    local _,_,r=living(player);if not r then return false end
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={player.Character,folder}
    local hit=workspace:Raycast(r.Position,position-r.Position,params)
    return not hit or hit.Instance:IsDescendantOf(target)
end
local function allowed()
    return supported and focused and not Input:GetFocusedTextBox() and not stopped
end
local tripBusy=false
local tripRestore
local lastTrip=-math.huge
local function cancel_trip()
    if tripRestore then tripRestore()end
end
motionChanged=function()cancel_trip()end
cleanupCallbacks[#cleanupCallbacks+1]=function()cancel_trip()end
local propertyRestore={}
local collisionRestore=setmetatable({},{__mode='k'})
local controlHumanoid
local flightHeld={up=false,down=false}
local hoverRoot,hoverAttachment,hoverVelocity
local function setHover(root)
    if hoverRoot==root and (not root or hoverVelocity and hoverVelocity.Parent)then return end
    if hoverVelocity then hoverVelocity:Destroy()end
    if hoverAttachment then hoverAttachment:Destroy()end
    hoverRoot=root;hoverVelocity=nil;hoverAttachment=nil
    if root then
        hoverAttachment=create('Attachment',root,{Name='MM2FlightAttachment'})
        hoverVelocity=create('LinearVelocity',root,{Name='MM2FlightHold',Attachment0=hoverAttachment,
            RelativeTo=Enum.ActuatorRelativeTo.World,VectorVelocity=Vector3.zero,
            MaxForce=math.huge,ForceLimitsEnabled=false})
    end
end
local function setControlled(hum,key,value)
    local saved=propertyRestore[key]
    if not saved then saved={original=hum[key]};propertyRestore[key]=saved end
    saved.applied=value;hum[key]=value
end
local function releaseProperty(hum,key)
    local saved=propertyRestore[key]
    if saved then
        if hum and hum.Parent and hum[key]==saved.applied then hum[key]=saved.original end
        propertyRestore[key]=nil
    end
end
local function restoreCollisions()
    for part,value in pairs(collisionRestore)do
        if part.Parent then part.CanCollide=value end
        collisionRestore[part]=nil
    end
end
local function releasePlayerControls()
    setHover(nil)
    for key in pairs(propertyRestore)do releaseProperty(controlHumanoid,key)end
    restoreCollisions();controlHumanoid=nil;flightHeld.up=false;flightHeld.down=false
end
local flightButtons={}
for index,key in ipairs({'up','down'})do
    local b=create('TextButton',overlay,{Visible=false,Text=key=='up'and '▲'or '▼',
        Size=UDim2.fromOffset(54,48),Position=UDim2.new(1,-70,1,-180+(index-1)*54),
        BackgroundColor3=Color3.fromRGB(67,31,105),TextColor3=Color3.fromRGB(240,230,255),
        TextSize=23,BorderSizePixel=0,ZIndex=35})
    create('UICorner',b,{CornerRadius=UDim.new(0,9)})
    flightButtons[key]=b
    addSignal(b.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then flightHeld[key]=input end
    end)
end
addSignal(Input.InputEnded,function(input)
    for key,held in pairs(flightHeld)do if held==input then flightHeld[key]=false end end
end)
local function playerControlsStep(dt)
    local c,hum,root=living(player)
    if hum~=controlHumanoid then releasePlayerControls();controlHumanoid=hum end
    local enabled=hum and allowed()
    local flying=enabled and not tripBusy and (cfg.fly or cfg.noclip)
    flightButtons.up.Visible=flying and true or false;flightButtons.down.Visible=flying and true or false
    if not enabled then releasePlayerControls();return end
    if cfg.speedBoost and not tripBusy then setControlled(hum,'WalkSpeed',cfg.playerSpeed)else releaseProperty(hum,'WalkSpeed')end
    if cfg.jumpBoost and not tripBusy then
        if hum.UseJumpPower then
            releaseProperty(hum,'JumpHeight');setControlled(hum,'JumpPower',cfg.jumpPower)
        else
            releaseProperty(hum,'JumpPower')
            setControlled(hum,'JumpHeight',cfg.jumpPower*cfg.jumpPower/(2*math.max(1,workspace.Gravity)))
        end
    else releaseProperty(hum,'JumpPower');releaseProperty(hum,'JumpHeight')end
    setHover(flying and root or nil)
    if flying then
        setControlled(hum,'PlatformStand',true);setControlled(hum,'AutoRotate',false)
    else releaseProperty(hum,'PlatformStand');releaseProperty(hum,'AutoRotate')end
    if cfg.noclip then
        for _,part in ipairs(c:GetDescendants())do
            if part:IsA('BasePart')then
                if collisionRestore[part]==nil then collisionRestore[part]=part.CanCollide end
                part.CanCollide=false
            end
        end
    else restoreCollisions()end
    if flying then
        local camera=workspace.CurrentCamera;if not camera then return end
        local move=hum.MoveDirection
        local direction=move
        if not Input.TouchEnabled then
            local forward=(Input:IsKeyDown(Enum.KeyCode.W)and 1 or 0)-(Input:IsKeyDown(Enum.KeyCode.S)and 1 or 0)
            local side=(Input:IsKeyDown(Enum.KeyCode.D)and 1 or 0)-(Input:IsKeyDown(Enum.KeyCode.A)and 1 or 0)
            direction=camera.CFrame.LookVector*forward+camera.CFrame.RightVector*side
        elseif move.Magnitude>.01 then
            local horizontal=Vector3.new(camera.CFrame.LookVector.X,0,camera.CFrame.LookVector.Z)
            if horizontal.Magnitude>.01 then direction=move+Vector3.new(0,camera.CFrame.LookVector.Y*move:Dot(horizontal.Unit),0)end
        end
        local up=(flightHeld.up or Input:IsKeyDown(Enum.KeyCode.Space))and 1 or 0
        local down=(flightHeld.down or Input:IsKeyDown(Enum.KeyCode.LeftControl))and 1 or 0
        direction=direction+Vector3.new(0,up-down,0)
        if direction.Magnitude>1 then direction=direction.Unit end
        local speed=cfg.noclip and cfg.noclipSpeed or cfg.flySpeed
        root.CFrame=CFrame.new(root.Position+direction*speed*math.min(dt,.1))*root.CFrame.Rotation
        root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero
    end
end
cleanupCallbacks[#cleanupCallbacks+1]=releasePlayerControls
addSignal(player.CharacterRemoving,releasePlayerControls)
addSignal(Input.WindowFocusReleased,releasePlayerControls)
addSignal(Run.Heartbeat,function(dt)
    local ok,err=pcall(playerControlsStep,dt)
    if not ok then releasePlayerControls();warn('MM2 Player: '..tostring(err))end
end)

local function quick_trip(object,mode,onArrival)
    if tripBusy or os.clock()-lastTrip<1.5 or not allowed()then return end
    local c,hum,root=living(player)
    local destination=part_of(object)
    if not root or not destination then return end
    local function enabled()
        return mode=='kill' and (cfg.kill or cfg.killSheriff)or mode=='grab'and cfg.grab
            or mode=='shoot'and cfg.sheriffAuto
    end
    local original=root.CFrame
    setHover(nil);tripBusy=true;lastTrip=os.clock()
    local returned=false
    local function restore()
        if returned then return end;returned=true
        if player.Character==c and root.Parent and hum.Health>0 then
            pcall(function()root.CFrame=original;root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero end)
        end
    end
    tripRestore=restore
    task.spawn(function()
        local ok=pcall(function()
            if returned or not allowed()or not enabled()or not part_of(object)then return end
            if mode=='kill'then
                local knife=tool(player,'Knife')
                if not knife or role(player)~='Murderer'then return end
                local targetCharacter=destination.Parent
                local targetHumanoid=targetCharacter and targetCharacter:FindFirstChildOfClass('Humanoid')
                if not targetHumanoid or targetHumanoid.Health<=0 then return end
                hum:EquipTool(knife)
                local started=os.clock()
                local lastAttack=started
                local attacks=0
                repeat
                    if returned or not allowed()or not enabled()or player.Character~=c or hum.Health<=0
                        or not part_of(object)or destination.Parent~=targetCharacter or targetHumanoid.Health<=0
                        or role(player)~='Murderer'or knife.Parent~=c then break end
                    -- Follow the current target position throughout contact, not its initial position.
                    local velocity=destination.AssemblyLinearVelocity
                    local lead=Vector3.new(velocity.X,0,velocity.Z)*.06
                    if lead.Magnitude>1.5 then lead=lead.Unit*1.5 end
                    local point=destination.Position
                    local facing=destination.CFrame.LookVector
                    local behind=Vector3.new(facing.X,0,facing.Z)
                    if behind.Magnitude<.01 then behind=Vector3.new(0,0,-1)else behind=behind.Unit end
                    local position=point-behind*2+lead
                    root.CFrame=CFrame.lookAt(position,point)
                    root.AssemblyLinearVelocity=Vector3.zero
                    root.AssemblyAngularVelocity=Vector3.zero
                    local now=os.clock()
                    if now-started>=.06 and now-lastAttack>=.22 and attacks<2 then
                        knife:Activate();attacks=attacks+1;lastAttack=now
                        status('Murder','Ataque solicitado')
                    end
                    task.wait(.03)
                until os.clock()-started>=.5
                return
            elseif mode=='shoot'then
                local gun=tool(player,'Gun')
                local ownRole=role(player)
                if not gun or (ownRole~='Sheriff'and ownRole~='Hero')or not onArrival then return end
                local targetCharacter=destination.Parent
                local targetHumanoid=targetCharacter and targetCharacter:FindFirstChildOfClass('Humanoid')
                if not targetHumanoid or targetHumanoid.Health<=0 then return end
                local function valid()
                    return not returned and allowed()and enabled()and player.Character==c and hum.Health>0
                        and part_of(object)and destination.Parent==targetCharacter and targetHumanoid.Health>0
                        and gun.Parent==c
                end
                hum:EquipTool(gun)
                local function approach()
                    local point=destination.Position
                    local forward=destination.CFrame.LookVector
                    local offset=Vector3.new(forward.X,0,forward.Z)
                    offset=offset.Magnitude>.01 and offset.Unit or Vector3.new(0,0,-1)
                    root.CFrame=CFrame.lookAt(point-offset*3,point)
                    root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero
                end
                approach()
                task.wait(.08)
                if not valid()then return end
                approach()
                onArrival(valid)
                local deadline=os.clock()+.2
                repeat task.wait(.03)until not valid()or os.clock()>=deadline
                return
            else
                if role(player)~='Innocent'then return end
                root.CFrame=CFrame.new(destination.Position+Vector3.new(0,1,0))*original.Rotation
                status('Inocentes','Buscando arma')
            end
            local deadline=os.clock()+.4
            repeat task.wait(.03)
            until returned or not allowed()or not enabled()or player.Character~=c or hum.Health<=0
                or not part_of(object)or (mode=='grab'and tool(player,'Gun'))or os.clock()>=deadline
        end)
        restore()
        if tripRestore==restore then tripRestore=nil end
        tripBusy=false
        if not ok and not stopped then status(mode=='kill'and 'Murder'or mode=='shoot'and 'Sheriff'or 'Inocentes','Falha de movimento')end
    end)
end
local function update_roles()
    if roleBusy or not supported then return end
    roleGetter=roleGetter and roleGetter.Parent and roleGetter or Replicated:FindFirstChild('GetPlayerData',true)
    if not roleGetter or not roleGetter:IsA('RemoteFunction')then roleError='Funcoes indisponiveis';return end
    roleBusy=true
    task.delay(5,function()if not stopped and roleBusy then roleError='Funcoes indisponiveis' end end)
    task.spawn(function()
        local ok,data=pcall(function()return roleGetter:InvokeServer()end)
        roleBusy=false
        if stopped then return end
        if ok and type(data)=='table'then roleData=data;roleStamp=os.clock();roleError='Dados da rodada recebidos'
        else roleError='Funcoes indisponiveis' end
    end)
end
local function shoot_murderer(automatic,expectedRoot,tripValid)
    local statusTab='Sheriff'
    local function enabled()
        return (automatic and cfg.sheriffAuto or not automatic and cfg.silent)and (not tripValid or tripValid())
    end
    if not enabled() or not allowed() or shotBusy or os.clock()-lastShot<1 then return end
    local murderer=target_role('Murderer')
    local c,_,root=living(player);local tc,_,tr=living(murderer)
    if expectedRoot and tr~=expectedRoot then return end
    local gun=tool(player,'Gun')
    if not gun or gun.Parent~=c or not root or not tr then status(statusTab,'Equipe a arma');return end
    local localRole=role(player)
    if not MM2Logic.can_shoot(localRole,role(murderer),true,line_of_sight(tr.Position,tc))then status(statusTab,'Sem alvo visivel');return end
    local remote=gun:FindFirstChild('Shoot')
    local legacy=gun:FindFirstChild('KnifeLocal')
    legacy=legacy and legacy:FindFirstChild('CreateBeam')
    legacy=legacy and legacy:FindFirstChild('RemoteFunction')
    local hand=c:FindFirstChild('RightHand') or c:FindFirstChild('Right Arm') or root
    if not (remote and remote:IsA('RemoteEvent')) and not (legacy and legacy:IsA('RemoteFunction'))then status(statusTab,'Arma incompativel');return end
    shotBusy=true;lastShot=os.clock()
    task.spawn(function()
        local ok,sent=pcall(function()
            if not enabled() or not allowed() or player.Character~=c or gun.Parent~=c
                or not hand:IsDescendantOf(c) or not living(player) then return false end
            local currentTarget,_,targetRoot=living(murderer)
            if currentTarget~=tc or targetRoot~=tr then return false end
            if not MM2Logic.can_shoot(role(player),role(murderer),true,line_of_sight(tr.Position,tc))then return false end
            local position=tr.Position+tr.AssemblyLinearVelocity*cfg.prediction
            local origin=hand.Position
            if (position-origin).Magnitude<.001 then return false end
            -- Preserve the real origin, but orient the shot towards the target, not a fixed world axis.
            local direction=(position-origin).Unit
            local up=math.abs(direction.Y)>.99 and Vector3.xAxis or Vector3.yAxis
            if remote and remote:IsA('RemoteEvent')then remote:FireServer(CFrame.lookAt(origin,position,up),CFrame.new(position))
            else legacy:InvokeServer(1,position,'AH2')end
            return true
        end)
        shotBusy=false
        if not stopped then status(statusTab,ok and (sent and 'Disparo solicitado' or 'Sem alvo visivel') or 'Falha no disparo')end
    end)
end
local colors={Murderer=Color3.fromRGB(246,80,100),Sheriff=Color3.fromRGB(80,155,255),Hero=Color3.fromRGB(255,205,65),Innocent=Color3.fromRGB(90,225,135),Unknown=Color3.fromRGB(180,180,190)}
local signs={Vector3.new(-1,-1,-1),Vector3.new(1,-1,-1),Vector3.new(1,1,-1),Vector3.new(-1,1,-1),Vector3.new(-1,-1,1),Vector3.new(1,-1,1),Vector3.new(1,1,1),Vector3.new(-1,1,1)}
local edges={{1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8}}
local function draw(line,root,a,b,color)
    local delta=b-a
    if delta.Magnitude<.001 then line.Visible=false;return end
    local up=math.abs(delta.Unit:Dot(Vector3.yAxis))>.99 and Vector3.xAxis or Vector3.yAxis
    line.Adornee=root;line.CFrame=root.CFrame:ToObjectSpace(CFrame.lookAt(a,b,up))
    line.Length=delta.Magnitude;line.Color3=color;line.Visible=true
end
local function visual(p)
    if entries[p]then return entries[p]end
    local group=create('Folder',folder,{Name='ESP_'..p.UserId})
    local e={group=group,lines={},bones={}}
    for i=1,14 do e.bones[i]=create('LineHandleAdornment',group,{Visible=false,AlwaysOnTop=true,Thickness=2,ZIndex=2})end
    for i=1,12 do e.lines[i]=create('LineHandleAdornment',group,{Visible=false,AlwaysOnTop=true,Thickness=1.5,ZIndex=1})end
    e.tracer=create('Frame',overlay,{Visible=false,BorderSizePixel=0,AnchorPoint=Vector2.new(.5,.5),ZIndex=2})
    e.highlight=create('Highlight',group,{Enabled=false,FillTransparency=1,DepthMode=Enum.HighlightDepthMode.AlwaysOnTop})
    e.tag=create('BillboardGui',overlay,{Enabled=false,AlwaysOnTop=true,Size=UDim2.fromOffset(260,42),StudsOffsetWorldSpace=Vector3.new(0,3.5,0)})
    e.label=create('TextLabel',e.tag,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,TextColor3=colors.Unknown,TextStrokeTransparency=.3,TextSize=13,Font=Enum.Font.GothamMedium})
    entries[p]=e;return e
end
local gunHighlight=create('Highlight',folder,{Enabled=false,FillTransparency=.65,OutlineColor=Color3.fromRGB(255,220,60),FillColor=Color3.fromRGB(255,220,60),DepthMode=Enum.HighlightDepthMode.AlwaysOnTop})
local gunTag=create('BillboardGui',overlay,{Enabled=false,AlwaysOnTop=true,Size=UDim2.fromOffset(160,30),StudsOffsetWorldSpace=Vector3.new(0,2,0)})
local gunLabel=create('TextLabel',gunTag,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,TextColor3=Color3.fromRGB(255,220,60),TextStrokeTransparency=.3,TextSize=14,Font=Enum.Font.GothamBold})
local function remove_visual(p)
    local e=entries[p];if e then e.group:Destroy();e.tag:Destroy();e.tracer:Destroy();entries[p]=nil end
end
addSignal(Players.PlayerRemoving,remove_visual)
local bodyNames={Head=true,Torso=true,UpperTorso=true,LowerTorso=true,
    ['Left Arm']=true,['Right Arm']=true,['Left Leg']=true,['Right Leg']=true,
    LeftUpperArm=true,LeftLowerArm=true,LeftHand=true,RightUpperArm=true,RightLowerArm=true,RightHand=true,
    LeftUpperLeg=true,LeftLowerLeg=true,LeftFoot=true,RightUpperLeg=true,RightLowerLeg=true,RightFoot=true}
local function body_bounds(character,root)
    local low,high
    for _,part in ipairs(character:GetChildren())do
        if bodyNames[part.Name] and part:IsA('BasePart')then
            for _,sign in ipairs(signs)do
                local p=root.CFrame:PointToObjectSpace(part.CFrame:PointToWorldSpace(part.Size*sign/2))
                low=low and Vector3.new(math.min(low.X,p.X),math.min(low.Y,p.Y),math.min(low.Z,p.Z))or p
                high=high and Vector3.new(math.max(high.X,p.X),math.max(high.Y,p.Y),math.max(high.Z,p.Z))or p
            end
        end
    end
    if not low then return root.CFrame,root.Size end
    return root.CFrame*CFrame.new((low+high)/2),high-low
end
local espErrors=setmetatable({},{__mode='k'})
local function render_esp(camera)
    for _,p in ipairs(Players:GetPlayers())do
        if p~=player then
            local espOk,espError=pcall(function()
            local e=entries[p]
            if cfg.box or cfg.tracer or cfg.roles or cfg.skeleton then e=e or visual(p)end
            if e then
                for _,line in ipairs(e.lines)do line.Visible=false end
                for _,line in ipairs(e.bones)do line.Visible=false end
                e.tag.Enabled=false;e.highlight.Enabled=false;e.tracer.Visible=false
                local c,_,r=living(p);local value,active=role(p)
                -- Render living characters even if the previous round's role data says dead.
                if r then
                    local tint=colors[value]or colors.Unknown
                    if cfg.roles then
                        e.tag.Adornee=c:FindFirstChild('Head')or r
                        e.tag.StudsOffsetWorldSpace=Vector3.new(0,2,0)
                        e.label.Text=(p.DisplayName or p.Name)..'\n'..T(value);e.label.TextColor3=tint;e.tag.Enabled=true end
                    if cfg.skeleton then
                        local links=c:FindFirstChild('UpperTorso')and MM2Logic.r15 or MM2Logic.r6
                        for i,link in ipairs(links)do
                            local a,b=c:FindFirstChild(link[1]),c:FindFirstChild(link[2])
                            if a and b and a:IsA('BasePart')and b:IsA('BasePart')then draw(e.bones[i],r,a.Position,b.Position,tint)end
                        end
                    end
                    if cfg.box then
                        local cf,size=body_bounds(c,r);local points={}
                        for i,v in ipairs(signs)do points[i]=cf:PointToWorldSpace(size*v/2)end
                        for i,edge in ipairs(edges)do draw(e.lines[i],r,points[edge[1]],points[edge[2]],tint)end
                    end
                    if cfg.tracer then
                        local v=camera.ViewportSize;local y=cfg.origin=='Cima' and 5 or cfg.origin=='Meio' and v.Y/2 or v.Y-5
                        local point,onScreen=camera:WorldToViewportPoint(r.Position)
                        if onScreen and point.Z>0 then
                            local start=Vector2.new(v.X/2,y)
                            local finish=Vector2.new(point.X,point.Y)
                            local delta=finish-start
                            if delta.Magnitude>.5 then
                                e.tracer.Position=UDim2.fromOffset((start.X+finish.X)/2,(start.Y+finish.Y)/2)
                                e.tracer.Size=UDim2.fromOffset(delta.Magnitude,1.5)
                                e.tracer.Rotation=math.deg(math.atan2(delta.Y,delta.X))
                                e.tracer.BackgroundColor3=tint;e.tracer.Visible=true
                            end
                        end
                    end
                end
            end
            end)
            if not espOk and os.clock()-(espErrors[p]or -math.huge)>3 then
                espErrors[p]=os.clock();warn('MM2 ESP ('..tostring(p.Name)..'): '..tostring(espError))
            end
        end
    end
    gunHighlight.Enabled=false;gunTag.Enabled=false
    if cfg.gun then
        local _,_,r=living(player);local object=r and nearest(guns,r.Position)
        local part=part_of(object)
        if part then gunHighlight.Adornee=object;gunHighlight.Enabled=true;gunTag.Adornee=part;gunTag.Enabled=true;gunLabel.Text=T('Arma caida')end
    end
end
local frames,fpsSeconds,fps,ping=0,0,0,0
local lastPoll,lastMove,lastStab,lastMetrics=0,0,0,0
local attackHistory=setmetatable({},{__mode='k'})
local silentHeld=false
local lastVisualError=-math.huge
local stepName='MM2Render_'..Http:GenerateGUID(false)
local function cleanup()
    if stopped then return end
    stopped=true;Run:UnbindFromRenderStep(stepName)
    for _,c in ipairs(connections)do c:Disconnect()end
    for _,fn in ipairs(cleanupCallbacks)do pcall(fn)end
    folder:Destroy();overlay:Destroy()
    if env.MM2Cleanup==cleanup then env.MM2Cleanup=nil end
    app.Close()
end
env.MM2Cleanup=cleanup
if app.Library.GUI then addSignal(app.Library.GUI.Destroying,cleanup)end
tabs.Configuracoes:AddButton({Title='Fechar e limpar',Callback=cleanup})
addSignal(Input.WindowFocused,function()focused=true end)
addSignal(Input.WindowFocusReleased,function()focused=false;cancel_trip()end)
addSignal(player.CharacterRemoving,function()cancel_trip();roleData={};roleStamp=-math.huge end)
addSignal(Run.Heartbeat,function(dt)
    if stopped or app.IsClosed()then cleanup();return end
    local ok,err=pcall(function()
        local now=os.clock()
        if now-lastPoll>=2 then lastPoll=now;update_roles()end
        if now-lastMetrics>=1 then
            lastMetrics=now;local success,value=pcall(function()return player:GetNetworkPing()end)
            ping=success and type(value)=='number' and value*1000 or nil
            diagnostic:SetDesc(supported and T(roleError)..' | '..T(role(player)) or T('Jogo diferente')..' '..tostring(game.PlaceId))
        end
        local pressed=cfg.silent and silentKey:GetState()
        if (pressed and not silentHeld)or (cfg.silent and cfg.mobileSilent and cfg.show_silent and not tripBusy)then shoot_murderer()end
        silentHeld=pressed
        if cfg.sheriffAuto and allowed()and not tripBusy then
            local own=role(player)
            local c,h=living(player);local gun=tool(player,'Gun')
            if gun and h and (own=='Sheriff'or own=='Hero')then
                local murderer=target_role('Murderer')
                local _,_,targetRoot=living(murderer)
                if targetRoot and not shotBusy and now-lastShot>=1 then
                    quick_trip(targetRoot,'shoot',function(valid)shoot_murderer(true,targetRoot,valid)end)
                elseif not targetRoot then status('Sheriff','Aguardando alvo')end
            else status('Sheriff','Aguardando funcao compativel')end
        end
        if tripBusy then
            if not allowed()or not(cfg.kill or cfg.killSheriff or cfg.grab or cfg.sheriffAuto)then cancel_trip()end
            return
        end
        if now-lastMove<.12 then return end;lastMove=now
        local c,hum,r=living(player);local ownRole,active=role(player)
        local mode=allowed() and r and MM2Logic.movement(cfg,ownRole) or nil
        if not mode then
            for name,key in pairs({Murder='kill',Inocentes='grab'})do
                status(name,cfg[key]and 'Aguardando funcao compativel'or 'Desligado')
            end
            return
        end
        local destination
        if mode=='grab'then
            destination=nearest(guns,r.Position)
            status('Inocentes',destination and 'Buscando arma' or 'Aguardando arma')
            if destination then quick_trip(destination,'grab')end
        elseif mode=='kill'then
            local candidates={}
            for _,candidate in ipairs(Players:GetPlayers())do
                local _,_,root=living(candidate);local value,active=role(candidate)
                if candidate~=player and root and active and value~='Murderer'and (cfg.kill or value=='Sheriff'or value=='Hero')then candidates[#candidates+1]=candidate end
            end
            local selected=MM2Logic.choose_target(candidates,attackHistory)
            local _,_,target=living(selected)
            status('Murder',target and 'Ataque solicitado'or 'Aguardando alvo')
            if target and tool(player,'Knife')and not tripBusy and now-lastTrip>=1.5 then
                attackHistory[selected]=now;quick_trip(target,'kill')
            end
        end
    end)
    if not ok then
        cancel_trip()
        if not stopped then diagnostic:SetDesc(T('Falha')..': '..tostring(err))end
    end
end)
Run:BindToRenderStep(stepName,Enum.RenderPriority.Camera.Value+2,function(dt)
    if stopped then return end
    -- ESP is independent from aim/input errors.
    local espCamera=workspace.CurrentCamera
    if espCamera then
        local espOk,espError=pcall(render_esp,espCamera)
        if not espOk and os.clock()-lastVisualError>3 then lastVisualError=os.clock();warn('MM2 ESP: '..tostring(espError))end
    end
    local ok,err=pcall(function()
        refreshFloating()
        frames=frames+1;fpsSeconds=fpsSeconds+dt
        if fpsSeconds>=.5 then fps=math.floor(frames/fpsSeconds+.5);frames=0;fpsSeconds=0 end
        metrics.Visible=cfg.fps or cfg.ping
        metrics.Text=(cfg.fps and ('FPS: '..fps) or '')..(cfg.fps and cfg.ping and ' | ' or '')..(cfg.ping and ('Ping: '..(ping and math.floor(ping)..' ms' or '--')) or '')

    end)
    if not ok and os.clock()-lastVisualError>3 then lastVisualError=os.clock();warn('MM2 visual: '..tostring(err))end
end)
local languageIds={English=1,['Português BR']=2,['Português']=3,['Русский']=4,['中文']=5}
local sources=setmetatable({},{__mode='k'})
local listeners={}
local writing=setmetatable({},{__mode='k'})
local function translate(label)
    local row=sources[label] and MM2Text[sources[label]]
    if not row or not label.Parent or label.Text==row[cfg.locale]then return end
    writing[label]=true;label.Text=row[cfg.locale];writing[label]=nil
end
local function watch(label)
    if not (label:IsA('TextLabel')or label:IsA('TextButton'))or listeners[label]then return end
    label.AutoLocalize=false
    sources[label]=MM2Text[label.Text] and label.Text or nil
    listeners[label]=label:GetPropertyChangedSignal('Text'):Connect(function()
        if stopped or writing[label]then return end
        local row=sources[label] and MM2Text[sources[label]]
        if row and label.Text==row[cfg.locale]then return end
        sources[label]=MM2Text[label.Text] and label.Text or nil
        translate(label)
    end)
    translate(label)
end
if app.Library.GUI then
    addSignal(app.Library.GUI.DescendantAdded,watch)
    addSignal(app.Library.GUI.DescendantRemoving,function(label)
        if listeners[label]then listeners[label]:Disconnect();listeners[label]=nil end
        sources[label]=nil
    end)
    for _,label in ipairs(app.Library.GUI:GetDescendants())do watch(label)end
end
language:OnChanged(function(value)
    cfg.locale=languageIds[value]or 2
    for label in pairs(sources)do translate(label)end
    lastStatus={}
    for tab,state in pairs(statusState)do status(tab,state[1],state[2])end
end)
cleanupCallbacks[#cleanupCallbacks+1]=function()
    for _,connection in pairs(listeners)do connection:Disconnect()end
    table.clear(listeners);table.clear(sources)
end

app.Window:SelectTab(1)
app.ApplyTheme()
