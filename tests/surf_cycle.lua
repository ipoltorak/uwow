-- tests/surf_cycle.lua — нагадування завантажити збір (агент cycle, 26.10.2026): після входу в гру, якщо від останнього
-- нагадування зібрано ≥ U.REMIND_EVERY нових текстів, — один рядок у чат, не частіше раз на сесію; /uw stats показує збір.
-- run(H, U, check) — викликається останнім у run_tests.lua (підміняє UwowMiss.d і відновлює його).
local M = {}

local MSG = "завантаж файл Uwow.lua на uwow.wearebob.dev/capture (/uw help — де він лежить)"

local function chat(H) return table.concat(H.chat or {}, "\n") end
local function count(H, pat)
    local n = 0
    for _, m in ipairs(H.chat or {}) do if m:find(pat, 1, true) then n = n + 1 end end
    return n
end
local function login(H)
    H.fire("PLAYER_ENTERING_WORLD", true, false)
    for _ = 1, 30 do
        if not H.timers or #H.timers == 0 then break end
        H.runTimers()
    end
end

function M.run(H, U, check)
    local saveD, saveAt, saveSess = UwowMiss.d, U.Settings.remindAt, U.remindedSession
    local okAll, why = true, {}
    local function need(c, m) if not c then okAll = false; why[#why + 1] = m end end

    -- 1. менше порогу — мовчимо (і сесія вважається відпрацьованою)
    UwowMiss.d = { dialog = { n = 60 }, ui = { n = 30 } }
    U.Settings.remindAt, U.remindedSession, H.chat = nil, nil, {}
    login(H)
    need(count(H, MSG) == 0, "нагадав при 90 < 100")
    need(U.Settings.remindAt == nil or U.Settings.remindAt == 0, "remindAt змінено без нагадування")

    -- 2. нова сесія, ≥100 — один рядок з точним числом, remindAt = усього
    UwowMiss.d.ui.n = 50                                       -- 60 + 50 = 110
    U.remindedSession, H.chat = nil, {}
    login(H)
    need(count(H, MSG) == 1, "немає нагадування при 110")
    need(chat(H):find("зібрано 110 нових текстів без перекладу — " .. MSG, 1, true) ~= nil, "текст нагадування: " .. chat(H):sub(1, 200))
    need(U.Settings.remindAt == 110, "remindAt ≠ 110")

    -- 3. та сама сесія: ще один екран завантаження і +200 — повтору нема
    UwowMiss.d.quest = { n = 200 }
    H.chat = {}
    login(H)
    need(count(H, MSG) == 0, "повторне нагадування в тій самій сесії")

    -- 4. /uw stats: скільки зібрано
    H.chat = {}
    SlashCmdList.UWOW("stats")
    need(chat(H):find("зібрано текстів без перекладу: 310 (нових від останнього нагадування: 200", 1, true) ~= nil,
        "/uw stats без лічильника збору")

    -- 5. наступна сесія: +200 ≥ 100 → нагадування з числом нових, а не всіх
    U.remindedSession, H.chat = nil, {}
    login(H)
    need(chat(H):find("зібрано 200 нових текстів", 1, true) ~= nil and U.Settings.remindAt == 310, "друга сесія: не 200 нових")

    -- 6. файл збору почистили (усього менше за remindAt) — відлік з нуля, без нагадування
    UwowMiss.d = { ui = { n = 5 } }
    U.remindedSession, H.chat = nil, {}
    login(H)
    need(count(H, MSG) == 0 and U.Settings.remindAt == 5, "після очищення файлу")

    -- 7. /uw help каже, де лежить файл
    H.chat = {}
    SlashCmdList.UWOW("help")
    need(chat(H):find("SavedVariables/Uwow.lua", 1, true) ~= nil, "/uw help без шляху до Uwow.lua")

    UwowMiss.d, U.Settings.remindAt, U.remindedSession = saveD, saveAt, saveSess
    check("upload-reminder", okAll, okAll and "≥100 нових — один рядок за сесію; /uw stats; очищений файл" or table.concat(why, "; "))
end

return M
