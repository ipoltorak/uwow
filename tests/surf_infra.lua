-- tests/surf_infra.lua — тести ядра й загального інтерфейсу (агент infra): компактні пакети, форматні рядки, шрифти,
-- фільтр збору, StaticPopup, UIErrorsFrame, HelpTip, навчальні банери, меню гри, заголовки вікон, налаштування, відсік аддонів, /uw.
-- setup(H) — заглушки фреймів Blizzard до PLAYER_LOGIN; run(H, U, check) — перевірки після завантаження.
local M = {}
local CYR = "[\208\209]"

function M.setup(H)
    issecurevariable = function(t, k)
        if type(t) == "string" then k = t end
        return not (type(k) == "string" and k:find("^MyAddon"))
    end
    GetRealmName = function() return "Silvermoon" end
    GetNormalizedRealmName = function() return "Silvermoon" end
    GetAutoCompleteRealms = function() return { "Silvermoon", "Argent Dawn" } end
    IsInRaid = function() return false end
    local un = UnitName
    UnitName = function(u) if u == "party1" then return "Bobbyx", "Draenor" end return un(u) end
    GetGuildInfo = function() return "Order of Testers" end
    C_AddOns.GetNumAddOns = function() return 3 end
    C_AddOns.GetAddOnInfo = function(i) return ({ "Uwow", "DBM-Core", "Details" })[i], ({ "Uwow", "|cffff0000DBM|r Core", "Details! Damage Meter" })[i] end
    GetTime = function() return H.now or 100 end

    -- StaticPopup (GameDialogMixin): Init ставить текст і кнопки так, як Blizzard
    StaticPopupDialogs = {
        CONFIRM_TRADE = { text = "Are you sure you want to accept this trade?", button1 = "Accept", button2 = "Cancel" },
        DESTROY = { text = "Do you want to destroy %s?", button1 = "Yes", button2 = "Cancel" },
        UNKNOWN_FMT = { text = "%s wants to frobnicate your %s.", button1 = "Okay" },
        MyAddonPopup = { text = "Reload the interface for MyAddon settings?", button1 = "Okay" },
    }
    local d = H.frame("StaticPopup1")
    d.Text, d.SubText = H.fontString(d), H.fontString(d)
    rawset(d.SubText, "_hidden", true)
    d.SubText.IsShown = function() return false end
    d.ButtonContainer = { Buttons = { H.frame(nil, d), H.frame(nil, d) } }
    function d:GetTextFontString() return self.Text end
    function d:GetButtons() return self.ButtonContainer.Buttons end
    function d:Init(which, a1, a2)
        local info = StaticPopupDialogs[which]
        self.Text:SetText(info.text:format(a1 or "", a2 or ""))
        for i, b in ipairs(self:GetButtons()) do b:SetText(info["button" .. i]) end
    end
    StaticPopup1 = d
    H.popup = function(which, a1, a2)
        d.which, d.dialogInfo = which, StaticPopupDialogs[which]
        d:Init(which, a1, a2)
        H.script(d, "OnShow")
        return d
    end

    -- UIErrorsFrame (MessageFrame): рядок на messageType
    local GS = { [1] = "ERR_INV_FULL", [2] = "ERR_LEFT_GROUP_S", [3] = "ERR_QUEST_ADD_KILL_SII", [4] = "ERR_UNKNOWN_TEST" }
    ERR_INV_FULL, ERR_LEFT_GROUP_S, ERR_QUEST_ADD_KILL_SII = "Inventory is full.", "%s has left the instance group.", "%s slain: %d/%d"
    ERR_UNKNOWN_TEST = "%s frobnicated %d widgets."
    GetGameMessageInfo = function(t) return GS[t] end
    local ef = H.frame("UIErrorsFrame")
    ef._lines = {}
    function ef:GetFontStringByID(id) return self._lines[id] end
    function ef:TryDisplayMessage(t, msg) local fs = H.fontString(self); fs:SetText(msg); self._lines[t] = fs end
    function ef:CheckAddMessage(msg, r, g, b, a, id) if id then self:TryDisplayMessage(id, msg) end end
    UIErrorsFrame = ef

    -- HelpTip: пул фреймів з міксином; один фрейм уже активний до хуків
    HelpTipTemplateMixin = { ApplyText = function(self) self.Text:SetText(self.info.text) end }
    local active = {}
    local function newTip()
        local f = H.frame(nil, UIParent)
        for k, v in pairs(HelpTipTemplateMixin) do f[k] = v end
        f.Text, f.OkayButton = H.fontString(f), H.frame(nil, f)
        return f
    end
    HelpTip = { framePool = { EnumerateActive = function() return pairs(active) end } }
    function HelpTip:Show(parent, info)
        local f = newTip()
        f.info = info
        f.OkayButton:SetText("Okay")
        f:ApplyText()
        active[f] = true
        return true
    end
    local early = newTip(); early.info = { text = "Return to Game" }; early:ApplyText(); active[early] = true
    H.earlyTip = early

    -- навчальні банери
    TutorialMainFrame_Frame = H.frame("TutorialMainFrame_Frame")
    TutorialMainFrame_Frame.ContainerFrame = H.frame(nil, TutorialMainFrame_Frame)
    TutorialMainFrame_Frame.ContainerFrame.Text = H.fontString()
    function TutorialMainFrame_Frame:_SetContent(content) self.ContainerFrame.Text:SetText(content.text) end
    TutorialPointerFrame = { NextID = 1, InUseFrames = {} }
    function TutorialPointerFrame:Show(content)
        local f = H.frame(nil, UIParent); f.Content = H.frame(nil, f); f.Content.Text = H.fontString(f.Content)
        f.Content.Text:SetText(content)
        self.InUseFrames[self.NextID] = f; self.NextID = self.NextID + 1
        H.lastPointer = f
        return self.NextID - 1
    end

    -- меню гри
    local gm = H.frame("GameMenuFrame")
    local buttons = {}
    gm.buttonPool = { EnumerateActive = function() return pairs(buttons) end }
    gm.Header = H.frame(nil, gm); gm.Header.Text = H.fontString(gm.Header)
    function gm:InitButtons()
        for k in pairs(buttons) do buttons[k] = nil end
        for _, t in ipairs({ "Options", "Shop", "AddOns", "Edit Mode", "Support", "Macros", "Logout", "Exit Game", "Return to Game" }) do
            local b = H.frame(nil, self); b:SetText(t); buttons[b] = true
        end
        self.Header.Text:SetText("Game Menu")
    end
    GameMenuFrame = gm
    H.menuButtons = buttons

    -- заголовки вікон: міксин і вікно, створене до аддона (копія методу)
    TitledPanelMixin = { GetTitleText = function(self) return self.TitleText end,
                         SetTitle = function(self, t) self:GetTitleText():SetText(t) end }
    PortraitFrameMixin = { GetTitleText = TitledPanelMixin.GetTitleText, SetTitle = TitledPanelMixin.SetTitle }
    local ff = H.frame("FriendsFrame"); ff.TitleText = H.fontString(ff)
    ff.GetTitleText, ff.SetTitle = TitledPanelMixin.GetTitleText, TitledPanelMixin.SetTitle
    ff:SetTitle("Options")
    FriendsFrame = ff

    -- титули (PaperDollTitlesPane_InitButton, CharacterFrame) — заглушки агента char (surf_char.lua)

    -- налаштування й відсік аддонів
    Settings = {
        RegisterCanvasLayoutCategory = function(frame, name) H.canvas = { frame = frame, name = name }
            return { GetID = function() return 777 end } end,
        RegisterAddOnCategory = function(cat) H.canvasRegistered = cat end,
        OpenToCategory = function(id) H.openedCategory = id end,
    }
    AddonCompartmentFrame = { RegisterAddon = function(_, data) H.compartment = data end }
end

function M.run(H, U, check)
    -- 1. компактний пакет: кошики, екранування, кеш, промах
    do
        local T26 = 67108864
        local h1, h2 = 5 * T26 + 7, 1234 * T26 + 8
        local b1 = ("\n%x.%x=рядок\\nдругий \\\\ кінець\n%x.%x=ще"):format(5, 7, 1234, 9)
        local p = U.PackCompact("t_compact", 2, { "", b1 })
        local okA = p[h1] == "рядок\nдругий \\ кінець" and rawget(p, h1) ~= nil
        local okB = p[h2] == nil and p[1234 * T26 + 9] == "ще" and p["x"] == nil
        local core = getmetatable(U.packs.ui) ~= nil and getmetatable(U.packs.dialog) ~= nil
        check("infra-compact-pack", okA and okB and core, ("розбір %s, промах/кеш %s, ядро компактне %s"):format(
            tostring(okA), tostring(okB), tostring(core)))
    end

    -- 2. форматні рядки
    do
        local a = U.Unformat("%s slain: %d/%d", "Boar slain: 3/6")
        local b = U.Unformat("%2$s and %1$s", "X and Y")
        local c = U.Unformat("Discount 50%% for %s", "Discount 50% for Bob")
        local f1 = U.Fmt("ui", "%s has left the instance group.", { "Bobbyx" })
        local f2 = U.Fmt("ui", "%s slain: %d/%d", { "Кабан", "3", "6" })
        local ok = a and a[1] == "Boar" and a[2] == "3" and a[3] == "6" and b and b[1] == "Y" and b[2] == "X"
            and c and c[1] == "Bob" and f1 and f1:find("Bobbyx", 1, true) and f1:find(CYR) and f2 == "Кабан вбито: 3/6"
        check("infra-format", ok and true or false, ("%s | %s"):format(tostring(f1), tostring(f2)))
    end

    -- 3. поверхні встановились (рядки /uw stats)
    do
        H.chat = {}
        SlashCmdList.UWOW("stats")
        -- титули гравця — поверхня «titles» агента char (CharItems.lua), перевіряє surf_char.lua
        local want = { "ui-popup", "ui-errors", "ui-helptip", "ui-tutorial", "ui-game-menu", "ui-panel-titles", "ui-options" }
        local bad = {}
        local all = table.concat(H.chat, "\n")
        for _, n in ipairs(want) do
            if not all:find("  " .. n .. ": ok", 1, true) then bad[#bad + 1] = n end
        end
        if all:find("помилка хука", 1, true) then bad[#bad + 1] = "hook-error" end
        check("infra-surfaces", #bad == 0, #bad == 0 and (#want .. " поверхонь ok") or table.concat(bad, ", ") .. " | " .. all:sub(1, 300))
    end

    -- 4. StaticPopup: точний текст, шаблон з аргументом, кнопки; чужий діалог не збирається; збір шаблоном
    do
        local d1 = H.popup("CONFIRM_TRADE")
        local t1, b1 = d1.Text:GetText(), d1.ButtonContainer.Buttons[1]:GetText()
        local d2 = H.popup("DESTROY", "Hearthstone")
        local t2 = d2.Text:GetText()
        UwowMiss.d = {}
        H.popup("UNKNOWN_FMT", "Bobbyx", "hat")
        H.popup("MyAddonPopup")
        local got = {}
        for _, r in pairs(UwowMiss.d.ui or {}) do if type(r) == "table" then got[#got + 1] = r.en end end
        local all = table.concat(got, " | ")
        local ok = t1 == U.T("ui", "Are you sure you want to accept this trade?") and t1:find(CYR) and b1 == "Прийняти"
            and t2 and t2:find("Hearthstone", 1, true) and t2:find(CYR)
            and all:find("%s wants to frobnicate your %s.", 1, true) and not all:find("Bobbyx", 1, true)
            and not all:find("MyAddon", 1, true)
        check("infra-popup", ok and true or false, ("%s | %s | %s | збір: %s"):format(tostring(t1), tostring(b1), tostring(t2), all))
    end

    -- 5. UIErrorsFrame: точний, шаблон з ніком, прогрес цілі; невідоме — у збір шаблоном
    do
        local ef = UIErrorsFrame
        ef:TryDisplayMessage(1, "Inventory is full.")
        ef:TryDisplayMessage(2, "Bobbyx has left the instance group.")
        ef:TryDisplayMessage(3, "Gnoll slain: 2/8")
        UwowMiss.d = {}
        ef:TryDisplayMessage(4, "Zed frobnicated 7 widgets.")
        local e1, e2, e3 = ef._lines[1]:GetText(), ef._lines[2]:GetText(), ef._lines[3]:GetText()
        local col = {}
        for _, r in pairs(UwowMiss.d.ui or {}) do if type(r) == "table" then col[#col + 1] = r.en .. "@" .. tostring(r.id) end end
        local cs = table.concat(col, " | ")
        local ok = e1 == "Інвентар заповнений." and e2 and e2:find("Bobbyx", 1, true) and e2:find(CYR)
            and e3 and e3:find("2/8", 1, true) and e3:find(CYR) and cs:find("%s frobnicated %d widgets.@ERR_UNKNOWN_TEST", 1, true)
        check("infra-errors", ok and true or false, ("%s | %s | %s | збір: %s"):format(tostring(e1), tostring(e2), tostring(e3), cs))
    end

    -- 6. HelpTip (фрейм до хука й новий з пулу) і навчальні банери
    do
        -- фрейм, показаний до входу (тоді діяв «оригінал» зі старих налаштувань): наступний ApplyText — уже через хук
        H.earlyTip:ApplyText()
        local early = H.earlyTip.Text:GetText()
        HelpTip:Show(UIParent, { text = "Edit Mode" })
        local newText, okBtn
        for f in HelpTip.framePool:EnumerateActive() do
            if f.info.text == "Edit Mode" then newText = f.Text:GetText(); okBtn = f.OkayButton:GetText() end
        end
        TutorialMainFrame_Frame:_SetContent({ text = "Options" })
        local banner = TutorialMainFrame_Frame.ContainerFrame.Text:GetText()
        TutorialPointerFrame:Show("Macros", "UP", UIParent)
        local ptr = H.lastPointer.Content.Text:GetText()
        local ok = early == "Повернутися до гри" and newText == "Режим редагування" and okBtn == "Гаразд"
            and banner == "Параметри" and ptr == "Макроси"
        check("infra-helptip", ok, ("%s | %s | %s | %s | %s"):format(tostring(early), tostring(newText), tostring(okBtn),
            tostring(banner), tostring(ptr)))
    end

    -- 7. меню гри й заголовки вікон
    do
        GameMenuFrame:InitButtons()
        local n, tr = 0, 0
        for b in pairs(H.menuButtons) do n = n + 1; if (b:GetText() or ""):find(CYR) then tr = tr + 1 end end
        local hdr = GameMenuFrame.Header.Text:GetText()
        -- на вході діяв «оригінал» (фікстура міграції), тож стартовий заголовок лишився англійським — як і в грі
        local p1 = FriendsFrame.TitleText:GetText()
        FriendsFrame:SetTitle("Macros"); local p2 = FriendsFrame.TitleText:GetText()
        local late = H.frame(); late.TitleText = H.fontString(late)
        for k, v in pairs(PortraitFrameMixin) do late[k] = v end                 -- вікно модуля, створене пізніше
        late:SetTitle("Edit Mode"); local p3 = late.TitleText:GetText()
        local ok = n == 9 and tr == 9 and hdr == "Меню гри" 
            and p1 == "Options" and p2 == "Макроси" and p3 == "Режим редагування"
        check("infra-menu-titles", ok, ("кнопок %d/%d, %s, вікна: %s/%s/%s"):format(tr, n, tostring(hdr),
            tostring(p1), tostring(p2), tostring(p3)))
    end

    -- 8. шрифти: одна функція ядра, режими, повернення свого шрифту
    do
        local fs = H.fontString()
        U.Settings.font = "auto"; U.Font(fs)
        local a = (fs:GetFont())
        local ar = H.fontString(); rawset(ar, "_baseFont", "Fonts\\ARIALN.TTF"); U.Font(ar)
        local a2 = (ar:GetFont())
        U.Apply(fs, "Тест", "Test")
        U.SetOption("font", "arial")
        local b = (fs:GetFont())
        U.SetOption("font", "off")
        local c = (fs:GetFont())
        U.SetOption("font", "auto")
        local ok = a == "Fonts\\FRIZQT___CYR.TTF" and a2 == "Fonts\\ARIALN.TTF" and b == "Fonts\\ARIALN.TTF"
            and c == "Fonts\\FRIZQT__.TTF" and U.CyrFont == U.Font
        check("infra-fonts", ok, ("auto %s · arialn %s · arial %s · off %s"):format(tostring(a), tostring(a2), tostring(b), tostring(c)))
    end

    -- 9. фільтр збору
    do
        UwowMiss.d = {}; UwowMiss.filtered = 0
        U.Miss("ui", "t", "Bobbyx joins the party.")                       -- учасник групи
        U.Miss("ui", "t", "Zork-ArgentDawn has invited you.")               -- Ім'я-Реалм (CamelCase)
        U.Miss("ui", "t", "Krag-Silvermoon whispers.")                      -- Ім'я-Реалм (відомий реалм)
        U.Miss("ui", "t", "Order of Testers raid night")                    -- гільдія
        U.Miss("ui", "t", "[DBM] Pull in 5")                                -- чужий аддон
        U.Miss("ui", "t", "Details: segment reset")
        U.Miss("ui", "t", "|Hplayer:Someone|h[Someone]|h says hi")
        local own = H.frame("MyAddonOptionsFrame"); local child = H.frame(nil, own)
        U.Miss("ui", "t", "Enable advanced mode", nil, nil, child)           -- напис у фреймі чужого аддону
        U.Miss("ui", "t", "Two-Handed Axes")                                 -- звичайний UI-рядок — збираємо
        U.Miss("ui", "t", "Draenor Pathfinder")                              -- реалм-слово окремо — збираємо
        local got = {}
        for _, r in pairs(UwowMiss.d.ui or {}) do if type(r) == "table" then got[#got + 1] = r.en end end
        table.sort(got)
        local ok = #got == 2 and got[1] == "Draenor Pathfinder" and got[2] == "Two-Handed Axes" and UwowMiss.filtered == 8
        check("infra-miss-filter", ok, ("зібрано: %s · відсіяно %d"):format(table.concat(got, " | "), UwowMiss.filtered or 0))
    end

    -- 10. налаштування, відсік аддонів, /uw, перемикання оригіналу
    do
        local f = H.canvas and H.canvas.frame
        local okPanel = f and H.canvasRegistered and f.boxes and f.boxes.enabled and f.radios and f.radios.arial
        if okPanel then
            f.OnRefresh()
            H.script(f.boxes.capture, "OnClick")                                 -- прапорець відображає стан
            f.boxes.capture:SetChecked(false); H.script(f.boxes.capture, "OnClick")
            H.script(f.radios.arial, "OnClick")
        end
        local capOff, fontArial = U.Settings.capture == false, U.Settings.font == "arial"
        U.SetOption("capture", true); U.SetOption("font", "auto")
        U.OpenOptions()
        local fs = H.fontString(); fs:SetText("Options")
        U.TrFS(fs, "ui", "test")
        local t1 = fs:GetText()
        SlashCmdList.UWOW("")                                                    -- оригінал
        local t2 = fs:GetText()
        SlashCmdList.UWOW("")                                                    -- назад
        U.SetOption("enabled", false); local t3 = fs:GetText()
        U.SetOption("enabled", true); local t4 = fs:GetText()
        H.chat = {}
        SlashCmdList.UWOW("help")
        local help = #H.chat >= 6 and table.concat(H.chat):find("/uw options", 1, true)
        SlashCmdList.UWOW("font arial"); local sf = U.Settings.font; SlashCmdList.UWOW("font auto")
        local cp = H.compartment
        local ok = okPanel and capOff and fontArial and H.openedCategory == 777 and t1 == "Параметри" and t2 == "Options"
            and t3 == "Options" and t4 == "Параметри" and help and sf == "arial"
            and cp and cp.text == "Uwow" and type(cp.func) == "function"
        check("infra-options", ok and true or false, ("панель %s, capture→%s, font→%s, відкрито %s, %s/%s/%s/%s, /uw help %s, відсік %s"):format(
            tostring(okPanel and true), tostring(capOff), tostring(fontArial), tostring(H.openedCategory), tostring(t1), tostring(t2),
            tostring(t3), tostring(t4), tostring(help and true), tostring(cp and cp.text)))
    end

    -- 11. journal: «#» у джерелі стає {#N} (живе число підставляється); jsec: опис здібності за sectionID з EN-шаблоном
    do
        local j = U.T("journal", "5 Pets")
        U.Need("jsec")
        local n, ok, ex = 0, 0, nil
        for k, en in pairs(U.packs.jsec_en or {}) do
            local c = U.SpellText.Compile(en)
            if c then
                n = n + 1
                local shown = en
                for _, t in ipairs(c.toks) do shown = shown:gsub(t:gsub("%p", "%%%0"), "123", 1) end
                shown = shown:gsub("%$[lL][^:;]*:([^;]*);", "%1")
                local r = U.TemplateText("jsec", (k - 3) / 16, shown)
                if r and r:find(CYR) then ok = ok + 1 elseif not ex then ex = shown:sub(1, 80) end
            end
            if n >= 500 then break end
        end
        check("infra-journal", j == "5 Улюбленці" and n >= 100 and ok >= n * 0.95,
            ("«5 Pets» → %s · jsec %d/%d%s"):format(tostring(j), ok, n, ex and (" · промах: " .. ex) or ""))
    end

    -- 12. буквальний «\n» у джерелі EN розекрановано в compile.py; /uw npc; кілька тултіп-обробників на тип
    do
        local d = U.T("dialog", "-[blade slashes]\n-[screams]")
        local before = U.Settings.npcNames
        SlashCmdList.UWOW("npc"); local on = U.Settings.npcNames
        SlashCmdList.UWOW("npc"); local off = U.Settings.npcNames
        local calls = 0
        TooltipDataProcessor.AddTooltipPostCall(99, function() calls = calls + 1 end)
        TooltipDataProcessor.AddTooltipPostCall(99, function() calls = calls + 1 end)
        H.tooltipPost[99]({}, {})
        local ok = d ~= nil and d:find(CYR) ~= nil and before == false and on == true and off == false and calls == 2
        check("infra-misc", ok, ("«\\n» → %s · npcNames %s→%s→%s · обробників %d"):format(tostring(d), tostring(before),
            tostring(on), tostring(off), calls))
    end

    -- 13. рендер: лише токени v2 ({p} {c} {c:форма} {r} {r:форма}); чужі {caster} {rank} {EventStartDate} — як є
    --     journal «#»: переклад переставив числа (Kith'ix, sid 500236) — зіставлення за типом числа (%, сек, шкода)
    do
        local r1 = U.Render("{caster} застосовує {spellName}: {c}, {c:v}, {r}, {rank}, {EventStartDate}")
        local want = "{caster} застосовує {spellName}: воїн, воїне, таурен, {rank}, {EventStartDate}"
        U.Need("journal")
        local live = "Kith'ix's storm of darkness pacifies players caught within, reduces their movement speed by 30%, "
            .. "and inflicts 5000 Shadow damage every 2 sec."
        local j = U.T("journal", live)
        local ok = r1 == want and j ~= nil and j:find("30%", 1, true) ~= nil and j:find("кожні 2 сек завдає 5000", 1, true) ~= nil
        check("infra-render-journal", ok, ("%s | %s"):format(r1, tostring(j)))
    end
end

return M
