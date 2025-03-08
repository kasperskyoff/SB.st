surface.CreateFont("ScoreBoard", {
    font = "Roboto",
    size = ScreenScale(5),
    weight = 450,
    extended = true
})

surface.CreateFont("ScoreBoardMoreTwo", {
    font = "Roboto",
    size = 20,
    weight = 550,
    extended = true
})

surface.CreateFont("ScoreBoardMore", {
    font = "Roboto",
    size = ScreenScale(6.5),
    weight = 550,
    extended = true
})

local function cache_nick(ply)
    if not ec_markup or not ply then
        return nil
    end

    if ply == LocalPlayer() and not ply.RichNick then
        return nil
    end
    
    local nick_cache = ec_markup.AdvancedParse(ply:RichNick(), {
        nick = true,
        no_shadow = true,
        default_font = "ScoreBoardMore",
        default_color = team.GetColor(ply:Team()),
    })
    
    return nick_cache
end


local ScoreBoard
local BackgroundBlur
local MoreInfo
local scrw, scrh = ScrW(), ScrH()
local currentAlpha = 0

do
    local PANEL = {}

    function PANEL:Init()
        self.base = vgui.Create("AvatarImage", self)
        self.base:Dock(FILL)
        self.base:SetPaintedManually(true)
        self:SetMouseInputEnabled(false)
    end
    
    function PANEL:GetBase()
        return self.base
    end
    
    function PANEL:PushMask(mask)
        render.ClearStencil()
        render.SetStencilEnable(true)
        render.SetStencilWriteMask(1)
        render.SetStencilTestMask(1)
        render.SetStencilFailOperation(STENCILOPERATION_REPLACE)
        render.SetStencilPassOperation(STENCILOPERATION_ZERO)
        render.SetStencilZFailOperation(STENCILOPERATION_ZERO)
        render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_NEVER)
        render.SetStencilReferenceValue(1)
        mask()
        render.SetStencilFailOperation(STENCILOPERATION_ZERO)
        render.SetStencilPassOperation(STENCILOPERATION_REPLACE)
        render.SetStencilZFailOperation(STENCILOPERATION_ZERO)
        render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
        render.SetStencilReferenceValue(1)
    end
    
    function PANEL:PopMask()
        render.SetStencilEnable(false)
        render.ClearStencil()
    end
    
    function PANEL:Paint(w, h)
        self:PushMask(function()
            local poly = {}
            local x, y = w / 2, h / 2
            for angle = 1, 360 do
                local rad = math.rad(angle)
                local cos = math.cos(rad) * y
                local sin = math.sin(rad) * y
                poly[#poly + 1] = {
                    x = x + cos,
                    y = y + sin
                }
            end
    
            draw.NoTexture()
            surface.SetDrawColor(Color(255, 255, 255))
            surface.DrawPoly(poly)
        end)
        self.base:PaintManual()
        self:PopMask()
    end

    vgui.Register("scoreboard.avatar", PANEL)

    local PANEL = {}

    function PANEL:Init()
        self.cornerRadius = 10 
        self.textureMaterial = nil 
        self.color = Color( 255, 255, 255 )
    end

    function PANEL:SetCornerRadius(radius)
        self.cornerRadius = radius
    end

    function PANEL:SetTextureMaterial(materialPath)
        self.textureMaterial = materialPath
    end

    function PANEL:PushMask(mask)
        render.ClearStencil()
        render.SetStencilEnable(true)

        render.SetStencilWriteMask(1)
        render.SetStencilTestMask(1)

        render.SetStencilFailOperation(STENCILOPERATION_REPLACE)
        render.SetStencilPassOperation(STENCILOPERATION_REPLACE)
        render.SetStencilZFailOperation(STENCILOPERATION_ZERO)
        render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_NEVER)
        render.SetStencilReferenceValue(1)

        mask()

        render.SetStencilFailOperation(STENCILOPERATION_KEEP)
        render.SetStencilPassOperation(STENCILOPERATION_KEEP)
        render.SetStencilZFailOperation(STENCILOPERATION_KEEP)
        render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
        render.SetStencilReferenceValue(1)
    end

    function PANEL:PopMask()
        render.SetStencilEnable(false)
        render.ClearStencil()
    end

    function PANEL:Paint(w, h)
        self:PushMask(function()
            local radius = self.cornerRadius
            local poly = {}

            local function addCorner(x, y, startAngle, endAngle)
                for angle = startAngle, endAngle, 1 do
                    local rad = math.rad(angle)
                    local cos = math.cos(rad) * radius
                    local sin = math.sin(rad) * radius
                    table.insert(poly, { x = x + cos, y = y + sin })
                end
            end

            addCorner(radius, radius, 180, 270)  
            addCorner(w - radius, radius, 270, 360) 
            addCorner(w - radius, h - radius, 0, 90) 
            addCorner(radius, h - radius, 90, 180) 

            surface.SetDrawColor(255, 255, 255, 255)
            draw.NoTexture()
            surface.DrawPoly(poly)
        end)

        if self.textureMaterial then
            surface.SetMaterial(self.textureMaterial)
            surface.SetDrawColor(self.color)

            local texWidth, texHeight = self.textureMaterial:Width(), self.textureMaterial:Height()
            local aspectRatio = texWidth / texHeight
            local panelAspectRatio = w / h

            local uMin, vMin, uMax, vMax = 0, 0, 1, 1
            if panelAspectRatio > aspectRatio then
                local scaledHeight = texWidth / panelAspectRatio
                local offset = (texHeight - scaledHeight) / 2
                vMin = offset / texHeight
                vMax = (offset + scaledHeight) / texHeight
            else
                local scaledWidth = texHeight * panelAspectRatio
                local offset = (texWidth - scaledWidth) / 2
                uMin = offset / texWidth
                uMax = (offset + scaledWidth) / texWidth
            end

            surface.DrawTexturedRectUV(0, 0, w, h, uMin, vMin, uMax, vMax)
        else
            surface.SetDrawColor(self.color)
            surface.DrawRect(0, 0, w, h)
        end

        self:PopMask()
    end

    vgui.Register("scoreboard.BackgroundCard", PANEL)

    local PANEL = {}

    function PANEL:Init()
        self.ply = nil
        self.card = vgui.Create("EditablePanel", self)
        self.card:Dock(FILL)
        self.card:SetPaintedManually(false)
        self:SetMouseInputEnabled(true)

        self.card.isExpanded = false
        self.tall = 50 
        self.card.alpha = 0
        self.card.smooth = 1
        self.card.smootha = 0.9
        self.card.round = 20
        self.card.timePosX = 0
        self.card.modePosX = 0
        self.card.aplha = 0
        self.color = Color(22, 22, 22, 230)
    end

    function PANEL:SetPlayer(ply)
        self.ply = ply
        self:SetupPanel()
        self:LoadPlayerData()
    end
    
    function PANEL:LoadPlayerData()
        if not IsValid(self.ply) then return end

        net.Start("RequestPlayerLink")
        net.WritePlayer(LocalPlayer()) 
        net.WritePlayer(self.ply)
        net.SendToServer() 
        
        net.Receive("RequestPlayerLink", function()
            local link = net.ReadString()
            print("Ссылка обновлена на:", link)

            matex.url(link, false, function(data)
                if data and data.material then
                    self.textureMaterial = data.material
                end
            end)
        end)
    end  

    function PANEL:SetupPanel()
        if not IsValid(self.ply) then return end

        local ply = self.ply
        local card = self.card
        local me = self 


        card.Paint = function(self, w, h)
            me:SetTall(me.tall)
            me:SetCornerRadius(me.card.round)

            if me.textureMaterial then
                if self.isExpanded then
                    me.color = me.color:Lerp(Color(!me.ply:Alive() and 180 or 101, 101, 101), .2)
                else
                    me.color = me.color:Lerp(Color(!me.ply:Alive() and 150 or 70, 70, 70), .2)
                end
            else
                me.color = me.color:Lerp(Color(!me.ply:Alive() and 105 or 22, 22, 22, 230), .2)
            end
            if self.isExpanded then
                me.tall = Lerp(FrameTime() * 9, me.tall, 80)
                self.smooth = Lerp(FrameTime() * 5 * 1.5, self.smooth, 1.8) 
                self.alpha = Lerp(FrameTime() * 5 * 3, self.alpha, 255) 
                self.smootha = Lerp(FrameTime() * 5, self.smootha, .875) 
                self.round = Lerp(FrameTime() * 5, self.round, 38) 
            else
                me.tall = Lerp(FrameTime() * 9, me.tall, 50)
                self.smooth = Lerp(FrameTime() * 5 * 1.5, self.smooth, 1) 
                self.alpha = Lerp(FrameTime() * 5 * 3, self.alpha, 0) 
                self.smootha = Lerp(FrameTime() * 5, self.smootha, .9) 
                self.round = Lerp(FrameTime() * 5, self.round, 25) 
            end

            if IsValid(ply) then
                local name = ply:Name()
                local ping = ply:Ping() .. "ms"
                local time = ply.GetSQLTimeTotalTime and ply:GetSQLTimeTotalTime() or 0
                local session_time = CurTime() - (ply:GetNWFloat("SessionStart", CurTime()))
                local total_time = time + session_time
                local time_disp = string.FormattedTime(total_time)
                local formatted_time = string.format("%02d:%02d:%02d", time_disp.h or 0, time_disp.m or 0, time_disp.s or 0)  
                local mode = not ply:GetNWBool("BuildMode") and "Строитель" or "ПВП-режим"
                local markup2 = cache_nick(ply)                  
                local xPos = math.Clamp(w * .03 + 32, 0, w)
                local yPos = math.Clamp(h / 2 - (markup2 and markup2:GetTall() or surface.GetTextSize(ply:Name())) / 2 * self.smooth, 0, h)
                local teamcolor = team.GetColor(ply:Team())

                draw.SimpleText(formatted_time, "ScoreBoard", self.timePosX, h / 2, Color(255, 255, 255, self.alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                teamcolor.a = 255  -- Показывает ники, а то обычно скрыты

                if markup2 then
                    markup2:Draw(w * .03 + 32, h / 2 - markup2:GetTall() / 2 * self.smooth)
                else
                    draw.SimpleText(ply:Name(), "ScoreBoardMore", w * .03 + 32, h / 2, teamcolor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end

                teamcolor.a = self.alpha
            
                surface.SetFont("ScoreBoardMore")
                local pingWidth = surface.GetTextSize(ping)
            
                self.timePosX = w - pingWidth - w * 0.06
                self.modePosX = self.timePosX - w * 0.1
            
                draw.SimpleText(ping, "ScoreBoardMore", w / 1.03, h / 2, HSVToColor(140 - math.Clamp(ply:Ping(), 0, 100) * 1.2, 1, 1), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            
                if self.isExpanded then
                    draw.SimpleText("Кол-во энтити: " .. (ply:GetCount("sents") + ply:GetCount("props")), "ScoreBoard", self.timePosX, h * 0.75,
                        Color(255, 255, 255, self.alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                    draw.SimpleText(team.GetName(ply:Team()), "ScoreBoard", w * .03 + 32,
                        h / 1.5 * self.smootha,
                        teamcolor,
                        TEXT_ALIGN_LEFT,
                        TEXT_ALIGN_CENTER)
                    draw.SimpleText(formatted_time,
                        "ScoreBoard",
                        self.timePosX,
                        h / 2,
                        Color(255, 255, 255,
                            self.alpha),
                        TEXT_ALIGN_RIGHT,
                        TEXT_ALIGN_CENTER)
                    draw.SimpleText(mode,
                        "ScoreBoard",
                        self.modePosX,
                        h / 2,
                        not ply:GetNWBool("BuildMode") and Color(111,
                            111,
                            255,
                            self.alpha) or Color(255,
                            122,
                            122,
                            self.alpha),
                        TEXT_ALIGN_RIGHT,
                        TEXT_ALIGN_CENTER)
                end
            end            
        end

        card.mainButton = vgui.Create("DButton", card)
        card.mainButton:Dock(FILL)
        card.mainButton:SetText("")
        card.mainButton:SetCursor("hand") 
        card.mainButton.Paint = function(self, w, h)
        end

        card.mainButton.DoClick = function()
            if ScoreBoard.activePlayerPanel == card then
                if ScoreBoard.activePlayerPanel:IsValid() then
                    ScoreBoard.activePlayerPanel = nil
                end
                card.isExpanded = false
            else
                if ScoreBoard.activePlayerPanel then
                    if ScoreBoard.activePlayerPanel:IsValid() then
                        ScoreBoard.activePlayerPanel.isExpanded = false 
                    end
                end
                ScoreBoard.activePlayerPanel = card
                card.isExpanded = true
            end
        end      
        
        
        local countryNames = {
            ["ru"] = "Россия", ["by"] = "Беларусь",
            ["ua"] = "Украина", ["kz"] = "Казахстан",
            ["am"] = "Армения", ["az"] = "Азербайджан",
            ["ge"] = "Грузия", ["md"] = "Молдова",
            ["kg"] = "Киргизия", ["tj"] = "Таджикистан",
            ["tm"] = "Туркменистан", ["uz"] = "Узбекистан",
            ["us"] = "США", ["de"] = "Германия",
            ["fr"] = "Франция", ["uk"] = "Великобритания",
            ["it"] = "Италия", ["es"] = "Испания",
            ["pt"] = "Португалия", ["nl"] = "Нидерланды",
            ["be"] = "Бельгия", ["ch"] = "Швейцария",
            ["at"] = "Австрия", ["se"] = "Швеция",
            ["no"] = "Норвегия", ["dk"] = "Дания",
            ["fi"] = "Финляндия", ["pl"] = "Польша",
            ["cz"] = "Чехия", ["sk"] = "Словакия",
            ["hu"] = "Венгрия", ["ro"] = "Румыния",
            ["bg"] = "Болгария", ["gr"] = "Греция",
            ["tr"] = "Турция", ["si"] = "Словения",
            ["hr"] = "Хорватия", ["ba"] = "Босния и Герцеговина",
            ["rs"] = "Сербия", ["mk"] = "Северная Македония",
            ["al"] = "Албания", ["ee"] = "Эстония",
            ["lv"] = "Латвия", ["lt"] = "Литва",
            ["ie"] = "Ирландия", ["is"] = "Исландия",
            ["lu"] = "Люксембург", ["mt"] = "Мальта",
            ["cy"] = "Кипр", ["li"] = "Лихтенштейн",
            ["mc"] = "Монако", ["ad"] = "Андорра",
            ["sm"] = "Сан-Марино", ["va"] = "Ватикан",
            ["jp"] = "Япония"
        }

        local data = ply:GetNW2String('scoreboard_country')
        
        card.mainButton.DoRightClick = function()
            local menu = vgui.Create("DMenu")
            menu:AddOption('Открыть профиль', function()
                ply:ShowProfile()
            end):SetIcon('icon16/user_gray.png')

        
            local countryName = countryNames[string.lower(data)] or "? ? ?"

            menu:AddOption('Страна: ' .. countryName, function() 
            end):SetIcon('flags16/' .. string.lower(data) .. '.png')
            
            menu:AddOption(ply:SteamID(), function()
                SetClipboardText(ply:SteamID())
            end):SetIcon('icon16/paste_plain.png')

            menu:AddSpacer()

            if LocalPlayer():IsUserGroup('moderator') or LocalPlayer():IsUserGroup('admin') or LocalPlayer():IsUserGroup('superadmin') or LocalPlayer():IsUserGroup('engineer') then

                local child, parent = menu:AddSubMenu('Телепортация')
                parent:SetIcon('icon16/group_go.png')
                if ply != LocalPlayer() then
                    child:AddOption('К игроку', function()
                        RunConsoleCommand('ulx', 'goto', ply:Nick())
                    end):SetIcon('icon16/arrow_right.png')
                    child:AddOption('Игрока к себе', function()
                        RunConsoleCommand('ulx', 'bring', ply:Nick())
                    end):SetIcon('icon16/arrow_left.png')
                end
                child:AddOption('Вернуть игрока', function()
                    RunConsoleCommand('ulx', 'return', ply:Nick())
                end):SetIcon('icon16/arrow_redo.png')
                
                if ply != LocalPlayer() then
                    local child, parent = menu:AddSubMenu('Админ-функции')
                    parent:SetIcon('icon16/lightning.png')
                    
                    child:AddOption('Заджайлить', function()
                        Derma_StringRequest(
                            "Заджайлить игрока",
                            "Укажите время в секундах для джайла игрока:",
                            "",
                            function(time)
                                RunConsoleCommand('ulx', 'jail', ply:Nick(), time)
                            end,
                            function() end,
                            "Применить",
                            "Отмена"
                        )
                    end):SetIcon('icon16/monkey.png')
                    
                    child:AddOption('Заморозить', function()
                        RunConsoleCommand('ulx', 'freeze', ply:Nick())
                    end):SetIcon('icon16/control_pause.png')
                    
                    child:AddOption('Разморозить', function()
                        RunConsoleCommand('ulx', 'unfreeze', ply:Nick())
                    end):SetIcon('icon16/control_play.png')
                    
                    child:AddOption('Кикнуть', function()
                        Derma_StringRequest(
                            "Кикнуть игрока",
                            "Укажите причину для кика игрока:",
                            "",
                            function(reason)
                                RunConsoleCommand('ulx', 'kick', ply:Nick(), reason)
                            end,
                            function() end,
                            "Применить",
                            "Отмена"
                        )
                    end):SetIcon('icon16/cross.png')
                end
            end                    

            menu:AddSpacer()
            
            if ply != LocalPlayer() then
                local isMuted = ply:IsMuted()

                if !isMuted then
                    local volumePanel = vgui.Create("DPanel", menu)
                    volumePanel:SetSize(200, 20)
                    volumePanel.Paint = function(self, w, h)
                        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 200))
                    end

                    local volumeSlider = vgui.Create("DSlider", volumePanel)
                    volumeSlider:Dock(FILL)
                    volumeSlider:SetSlideX(ply:GetVoiceVolumeScale() or 1)
                    volumeSlider.OnValueChanged = function(self, value)
                        local volume = math.Round(value * 100)
                        ply:SetVoiceVolumeScale(value)
                    end
                    volumeSlider.Knob:SetVisible(false)
                    volumeSlider.Paint = function(self, w, h)
                        local value = self:GetSlideX()
                        draw.RoundedBox(0, 0, 0, w, h, Color(50, 50, 50, 200))
                        draw.RoundedBox(0, 0, 0, w * value, h, Color(0, 184, 0))
                        draw.SimpleText("Громкость: " .. math.Round(value * 100) .. "%", "ScoreBoard", w / 2, h / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end

                    menu:AddPanel(volumePanel) 
                end

                local muteButton = menu:AddOption(isMuted and 'Разглушить' or 'Заглушить', function()
                    ply:SetMuted(not isMuted)
                end)
                muteButton:SetIcon(isMuted and 'icon16/sound_mute.png' or 'icon16/sound.png')
            end

            menu:Open()
        end

        card.avatarImage = vgui.Create("scoreboard.avatar", card)
        card.avatarImage:SetSize(32, 32)
        card.avatarImage.base:SetPlayer(ply, 32)
        
        local iconUser = Material("icon16/user.png", "noclamp smooth") 

        card.PaintOver = function(self, w, h)
            if self.isExpanded then
                if card.aplha != 0 then card.aplha = Lerp(.3, card.aplha, 0) end
            else
                if card.aplha != 255 then card.aplha = Lerp(.4, card.aplha, 255) end
            end

            local iconSize = 16
            local iconX = self.timePosX * .98
            local iconY = card:GetTall() / 2 - iconSize / 2

            surface.SetMaterial(iconUser)
            surface.SetDrawColor(255, 255, 255, !ply:GetNWBool('BuildMode') and card.aplha or 0) 
            surface.DrawTexturedRect(iconX, iconY, iconSize, iconSize)
        end
    end

    function PANEL:PerformLayout(w, h)
        self.card.avatarImage:SetPos(w * .0125, h / 2 - 16) 
    end

    vgui.Register("scoreboard.card", PANEL, "scoreboard.BackgroundCard")
end

local function init() 
    local blur = Material("pp/blurscreen")
    local function DrawBlurRect(x, y, w, h, amount)
        surface.SetDrawColor(255, 255, 255)
        surface.SetMaterial(blur)
        for i = 1, 3 do
            blur:SetFloat("$blur", (i / 3) * (amount or 6))
            blur:Recompute()
            render.UpdateScreenEffectTexture()
            surface.DrawTexturedRect(x * -1, y * -1, w, h)
        end
    end

    if BackgroundBlur and ispanel(BackgroundBlur) then BackgroundBlur:Remove() end
    BackgroundBlur = vgui.Create("DPanel")
    BackgroundBlur:SetSize(ScrW(), ScrH())
    BackgroundBlur:Center()
    BackgroundBlur.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 150))
        -- DrawBlurRect(0, 0, w, h, 5) 
    end
    BackgroundBlur:AlphaTo(255, 0.25, 0)

    local screenW, screenH = ScrW(), ScrH()

    MoreInfo = vgui.Create("EditablePanel", BackgroundBlur)
    MoreInfo:SetPos(screenW * 0.02, screenH * 0.02)
    MoreInfo:SetSize(200, 200)
    MoreInfo.smooth = 0
    MoreInfo.cacheTotal = 0
    MoreInfo.MemCputotal = {}

    local function ReceiveCache()
        MoreInfo.cacheTotal = net.ReadInt(14)
    end
    local function ReceiveCPUMEM()
        MoreInfo.MemCputotal = net.ReadTable() 
    end

    net.Receive("NetCache", ReceiveCache)
    net.Receive("NetCPUandmemoryusage", ReceiveCPUMEM)

    function MoreInfo:Paint(w, h)
        draw.SimpleText("Кэш: " .. self.cacheTotal .. "/4096", "ScoreBoardMoreTwo", 0, 0, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        
        if next(self.MemCputotal) then
            local percent = math.floor((self.MemCputotal["ProcessCPUUsage"] / 18) * 100)
            local color = HSVToColor(120 - math.Clamp(percent, 0, 100) * 1.2, 1, 1)
            self.smooth = Lerp(FrameTime() * 10, self.smooth, 170 * (percent / 100))

            draw.RoundedBox(6, 0, 25, 170, 27, Color(0, 0, 0, 121))
            draw.RoundedBox(6, 0, 25, self.smooth, 27, color)
            draw.SimpleText("Нагрузка: " .. percent .. "%", "ScoreBoard", 84, 38, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    ScoreBoard = vgui.Create("EditablePanel", BackgroundBlur)
    ScoreBoard:SetSize(screenW * .4, screenH * .92)
    ScoreBoard:Center()
    ScoreBoard:AlphaTo(255, .25, 0)
    ScoreBoard:MakePopup()
    ScoreBoard:SetMouseInputEnabled(false)
    ScoreBoard:SetKeyBoardInputEnabled(false)

    ScoreBoard.Header = vgui.Create("EditablePanel", ScoreBoard)
    ScoreBoard.Header:Dock(TOP)
    ScoreBoard.Header:DockMargin(0, 0, 0, 5)
    ScoreBoard.Header.Paint = function(self, w, h)
        draw.SimpleText("Кол-во игроков: " .. table.Count(player.GetAll()) .. "/" .. game.MaxPlayers(), "ScoreBoardMoreTwo", 0, 0, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    ScoreBoard.scrollPanel = vgui.Create("DScrollPanel", ScoreBoard)
    ScoreBoard.scrollPanel:Dock(FILL)

    local scrollBar = ScoreBoard.scrollPanel:GetVBar()
    scrollBar:SetSize(8, ScoreBoard.scrollPanel:GetTall())
    scrollBar.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(0, 0, 0, 215))
    end
    scrollBar.btnUp.Paint = function(self, w, h)
    end
    scrollBar.btnDown.Paint = function(self, w, h)
    end
    scrollBar.btnGrip.Paint = function(self, w, h)
        draw.RoundedBox(50, 0, 0, w, h, Color(202, 202, 202, 200))
    end
    ScoreBoard.scrollPanel:SetSize(ScoreBoard:GetWide() - 30, ScoreBoard:GetTall() - 40)

    ScoreBoard.playerPanels = {}

    local function UpdatePlayerPanels()
        local players = player.GetAll()
        table.sort(players, function(a, b)
            local timeA = a.GetSQLTimeTotalTime and a:GetSQLTimeTotalTime() or 0
            local timeB = b.GetSQLTimeTotalTime and b:GetSQLTimeTotalTime() or 0

            if a == LocalPlayer() then return true end
            if b == LocalPlayer() then return false end
    
            if a:Team() == b:Team() then
                return timeB < timeA
            else
                return a:Team() < b:Team()
            end
        end)
        

        for plyID, panel in pairs(ScoreBoard.playerPanels) do
            if not IsValid(panel.ply) then
                panel:Remove()
                ScoreBoard.playerPanels[plyID] = nil
            end
        end

        for _, ply in ipairs(players) do
            if !IsValid(ply) then continue end
            local plyID = ply:IsBot() and ply:Nick() or ply:SteamID()
            
            if !IsValid(ScoreBoard.playerPanels[plyID]) then
                local playerPanel = vgui.Create('scoreboard.card', ScoreBoard.scrollPanel)
                playerPanel:SetPlayer(ply)
                playerPanel:Dock(TOP)
                playerPanel:DockMargin(0, 5, scrollBar:GetWide() / 2, 0)
                playerPanel:SetTall(50)
                ScoreBoard.playerPanels[plyID] = playerPanel
            end
        end
    end

    hook.Add("Think", "UpdatePlayerPanels", function()
        if ScoreBoard:IsVisible() then
            UpdatePlayerPanels()
        end
    end)

    BackgroundBlur:Hide()
end


hook.Add("ScoreboardShow", "OpenScoreBoard", function()
    if not IsValid(BackgroundBlur) then init() end
    BackgroundBlur:Show()
    ScoreBoard:AlphaTo(0, 0, 0)
    BackgroundBlur:AlphaTo(0, 0, 0)
    BackgroundBlur:AlphaTo(255, .15, 0)
    ScoreBoard:AlphaTo(255, .15, 0)


    hook.Add('CreateMove', '_mouse_listener', function(cmd)
        cmd:RemoveKey(MOUSE_LEFT)
    
        if input.WasMousePressed(MOUSE_LEFT) or input.WasMousePressed(MOUSE_RIGHT) then
            if BackgroundBlur:IsValid() then
                ScoreBoard:SetMouseInputEnabled(true)
                ScoreBoard:SetKeyBoardInputEnabled(false)
            end
            hook.Remove('CreateMove', '_mouse_listener')
        end
    end)

    return false 
end)

hook.Add("ScoreboardHide", "HideScoreBoard", function()
    hook.Remove('CreateMove', '_mouse_listener')

    ScoreBoard:SetMouseInputEnabled(false)
    ScoreBoard:SetKeyBoardInputEnabled(false)

    BackgroundBlur:Hide()
    currentAlpha = 0 
    return true
end)
    
-- init() 