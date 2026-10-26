-- tests/surf_fix.lua — /uw fix (агент fix): кільце останніх текстів ядра, вікно пропозицій, запис у UwowMiss.fix за
-- контрактом docs/feedback-brief.md, ліміти (500 записів, 2000 символів), бій, довідка.
-- setup(H) — заглушки до завантаження аддона; run(H, U, check) — перевірки.
local M = {}

function M.setup(H)
    time = os.time
    GetMouseFoci = function() return H.mouseFoci or {} end
end

local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
local function utf8len(s) local n = 0 for _ in s:gmatch("[^\128-\191]") do n = n + 1 end return n end

local function rowFor(win, en)
    for _, b in ipairs(win.rows) do local r = rawget(b, "rec"); if type(r) == "table" and r.en == en then return b end end
end

function M.run(H, U, check)
    local okAll, why = true, {}
    local function need(cond, msg) if not cond then okAll = false; why[#why + 1] = msg end return cond end

    -- 1. кільце: влучання U.T, U.ID + U.Apply, промах U.Miss, витіснення, повтор EN
    do
        okAll, why = true, {}
        local ua = U.T("ui", "Horde Battleship")
        local r = U.recentByEn["Horde Battleship"]
        need(ua == "Лінкор Орди" and r and r.ua == ua and r.d == "ui" and r.id == nil, "U.T не потрапив у кільце")
        local iua = U.ID("item", 23139, "name")
        local fs = H.fontString()
        fs:SetText("Lord Blackwood's Buckler")
        U.Apply(fs, iua, "Lord Blackwood's Buckler")
        local ri = U.recentByEn["Lord Blackwood's Buckler"]
        need(iua and ri and ri.d == "item" and ri.id == 23139 and ri.f == "name" and ri.ua == iua, "U.ID+U.Apply без контексту id")
        U.Miss("dialog", "chat", "Zzqx never translated phrase.", nil, "Bob")
        local rm = U.recentByEn["Zzqx never translated phrase."]
        need(rm and rm.ua == nil and rm.d == "dialog" and rm.a == "Bob", "промах не в кільці")
        local wasCap = U.Settings.capture
        U.Settings.capture = false
        U.Miss("ui", "x", "Zzqx miss without capture")
        U.Settings.capture = wasCap
        need(U.recentByEn["Zzqx miss without capture"] ~= nil, "промах без збору не в кільці")
        U.Miss("ui", "x", "Bobbyx has joined the party.")                           -- нік групи: фільтр збору
        need(U.recentByEn["Bobbyx has joined the party."] == nil, "нік гравця потрапив у кільце")
        -- форматний рядок: показаний текст ↔ ключ-шаблон (k)
        local efs = H.fontString(); efs:SetText("Bobby slain: 3/10")
        U.TrFS(efs, "ui", "test", nil, "%s slain: %d/%d")
        local rf = U.recentByEn["Bobby slain: 3/10"]
        need(not rf or rf.k == "%s slain: %d/%d", "шаблон не записано як ключ")
        local n0 = #U.recent
        for i = 1, 120 do U.Remember("ui", nil, nil, "Zzqx line " .. i, "рядок " .. i) end
        local list = U.FixRecent()
        need(#U.recent == 50 and count(U.recentByEn) == 50, ("кільце %d/%d замість 50"):format(#U.recent, count(U.recentByEn)))
        need(list[1].en == "Zzqx line 120" and U.recentByEn["Zzqx line 70"] == nil and U.recentByEn["Zzqx line 71"], "порядок/витіснення")
        U.Remember("ui", nil, nil, "Zzqx line 80", "рядок 80")
        need(#U.recent == 50 and U.FixRecent()[1].en == "Zzqx line 80", "повтор EN не піднявся нагору")
        check("fix-buffer", okAll, okAll and ("50 записів, витіснення й повтор; було %d до заповнення"):format(n0) or table.concat(why, "; "))
    end

    -- 2. вікно: відкриття, пошук, вибір рядка, збереження (текстовий і ID-запис) за контрактом
    do
        okAll, why = true, {}
        UwowMiss.fix = nil
        GameTooltip:ClearLines(); H.mouseFoci = {}
        U.T("ui", "Horde Battleship")
        local iua = U.ID("item", 23139, "name")
        local fs = H.fontString(); fs:SetText("Lord Blackwood's Buckler"); U.Apply(fs, iua, "Lord Blackwood's Buckler")
        U.Miss("dialog", "chat", "Zzqx never translated phrase.", nil, "Bob")
        H.chat = {}
        SlashCmdList.UWOW("fix horde")
        local win = U.FixWindow()
        need(U.FixShown() and win, "вікно не відкрилось")
        local st = U.FixState
        need(#st.view == 1 and st.view[1].en == "Horde Battleship", ("пошук «horde»: %d рядків"):format(#st.view))
        local font = win.rows[1].text:GetFont()
        need(font and font:find("CYR"), "напис вікна без кириличного шрифту: " .. tostring(font))
        local b = rowFor(win, "Horde Battleship")
        if need(b, "рядка немає у списку") then H.script(b, "OnClick") end
        need(win.edit:GetText() == "Лінкор Орди", "поле варіанту не заповнено поточним перекладом")
        win.edit:SetText("  Бойовий корабель Орди\n"); win.comment:SetText("лінкор — це клас корабля")
        H.script(win.saveButton, "OnClick")
        local e = UwowMiss.fix and UwowMiss.fix[1]
        local h = string.format("%.0f", U.Norm.hash((U.Norm.norm("Horde Battleship", nil, U.Player()))))
        need(e and e.d == "ui" and e.id == nil and e.f == nil and e.h == h and e.en == "Horde Battleship" and e.ua == "Лінкор Орди"
            and e.s == "Бойовий корабель Орди" and e.c == "лінкор — це клас корабля" and e.v == tostring(U.version)
            and type(e.t) == "number" and e.t > 0, "текстовий запис не за контрактом")
        win.search:SetText("Buckler"); H.script(win.search, "OnTextChanged")
        local bi = rowFor(win, "Lord Blackwood's Buckler")
        if need(bi, "ID-рядка немає") then H.script(bi, "OnClick") end
        win.edit:SetText("Баклер лорда Блеквуда (щит)")
        H.script(win.saveButton, "OnClick")
        local e2 = UwowMiss.fix[2]
        need(e2 and e2.d == "item" and e2.id == 23139 and e2.f == "name" and e2.h == nil and e2.ua == iua, "ID-запис не за контрактом")
        -- рядок кільця з промахом: ua = ""
        win.search:SetText("Zzqx never"); H.script(win.search, "OnTextChanged")
        local bm = rowFor(win, "Zzqx never translated phrase.")
        if need(bm, "рядка промаху немає") then
            H.script(bm, "OnClick"); win.edit:SetText("Ніколи не перекладена фраза.")
            H.script(win.saveButton, "OnClick")
            local e3 = UwowMiss.fix[3]
            need(e3 and e3.ua == "" and e3.d == "dialog" and type(e3.h) == "string", "запис промаху")
        end
        -- лише поля контракту
        local allowed = { t = 1, d = 1, id = 1, f = 1, h = 1, en = 1, ua = 1, s = 1, c = 1, v = 1 }
        for _, x in ipairs(UwowMiss.fix) do for k in pairs(x) do need(allowed[k], "зайве поле " .. tostring(k)) end end
        U.CloseFix()
        need(not U.FixShown(), "вікно не закрилось")
        check("fix-window", okAll, okAll and ("збережено %d записи: текстовий (h=%s), ID, промах"):format(#UwowMiss.fix, h)
            or table.concat(why, "; "))
    end

    -- 3. текст під курсором: рядки тултіпа (наш переклад з U.orig + неперекладений рядок), напис фрейму під мишею
    do
        okAll, why = true, {}
        GameTooltip:Fill({ { "Horde Battleship" }, { "Zzqx tooltip line" } })
        local t1 = GameTooltipTextLeft1
        U.Apply(t1, U.T("ui", "Horde Battleship"), "Horde Battleship")
        need(t1:GetText() == "Лінкор Орди", "тултіп не перекладено")
        SlashCmdList.UWOW("fix")
        local st = U.FixState
        need(st.sel and st.sel.hover and st.sel.en == "Horde Battleship" and st.sel.ua == "Лінкор Орди" and st.sel.d == "ui",
            "рядок тултіпа не вибрано")
        need(st.list[2] and st.list[2].en == "Zzqx tooltip line" and st.list[2].hover and st.list[2].ua == nil, "другий рядок тултіпа")
        U.CloseFix()
        GameTooltip:ClearLines()
        local reg = H.fontString(); reg:SetText("Zzqx button label")
        reg.GetObjectType = function() return "FontString" end
        local fr = H.frame(); fr.GetRegions = function() return reg end
        H.mouseFoci = { fr }
        SlashCmdList.UWOW("fix")
        need(st.sel and st.sel.en == "Zzqx button label", "напис під мишею не запропоновано")
        U.CloseFix(); H.mouseFoci = {}
        check("fix-hover", okAll, okAll and "тултіп (переклад і промах) і напис під мишею" or table.concat(why, "; "))
    end

    -- 4. ліміти: 500 записів (старі витісняються), рядки ≤ 2000 символів UTF-8, порожній/незмінений варіант
    do
        okAll, why = true, {}
        UwowMiss.fix = {}
        local r = { d = "ui", en = "Zzqx limit", ua = "ліміт" }
        for i = 1, 520 do U.FixSave(r, "варіант " .. i, "") end
        need(#UwowMiss.fix == 500 and UwowMiss.fix[1].s == "варіант 21" and UwowMiss.fix[500].s == "варіант 520", "витіснення 500")
        local long = string.rep("ї", 5000)
        local e = U.FixSave({ d = "ui", en = string.rep("a", 3000), ua = long }, long, long)
        need(e and utf8len(e.s) == 2000 and #e.s == 4000 and #e.en == 2000 and utf8len(e.ua) == 2000 and utf8len(e.c) == 2000,
            "обрізання до 2000 символів")
        need(#UwowMiss.fix == 500, "після обрізання не 500")
        need(U.FixSave(r, "   ", "") == nil, "порожній варіант збережено")
        need(U.FixSave(r, "ліміт", "") == nil, "незмінений варіант без коментаря збережено")
        need(U.FixSave(r, "ліміт", "переклад правильний, але не влазить") ~= nil, "незмінений варіант із коментарем відхилено")
        need(U.FixSave(nil, "x", "") == nil, "запис без тексту")
        check("fix-limits", okAll, okAll and "500 записів, 2000 символів (UTF-8), порожнє відхилено" or table.concat(why, "; "))
    end

    -- 5. бій: не відкривається (повідомлення в чат), відкрите ховається на PLAYER_REGEN_DISABLED
    do
        okAll, why = true, {}
        local icl = InCombatLockdown
        InCombatLockdown = function() return true end
        H.chat = {}
        SlashCmdList.UWOW("fix")
        need(not U.FixShown() and table.concat(H.chat, "\n"):find("бою", 1, true), "відкрилось у бою")
        InCombatLockdown = icl
        SlashCmdList.UWOW("fix")
        need(U.FixShown(), "не відкрилось поза боєм")
        H.fire("PLAYER_REGEN_DISABLED")
        need(not U.FixShown(), "не сховалось на початку бою")
        check("fix-combat", okAll, okAll and "у бою — повідомлення, відкрите ховається" or table.concat(why, "; "))
    end

    -- 6. довідка й сторінка налаштувань
    do
        H.chat = {}
        SlashCmdList.UWOW("help")
        local all = table.concat(H.chat, "\n")
        local p = U.optionsPanel and U.optionsPanel.fixHelp and U.optionsPanel.fixHelp:GetText() or ""
        check("fix-help", all:find("/uw fix", 1, true) and all:find("uwow.wearebob.dev/capture", 1, true)
            and p:find("/uw fix", 1, true) and p:find("SavedVariables/Uwow.lua", 1, true) and p:find("uwow.wearebob.dev/capture", 1, true)
            and true or false, "/uw help і сторінка налаштувань")
    end
end

return M
