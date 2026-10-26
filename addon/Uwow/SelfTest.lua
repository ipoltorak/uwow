-- Uwow · SelfTest.lua — /uw selftest: проганяє відомі рядки збірки (Data/selftest.lua) через пошук і рендер.
local U = UWOW
U.SELFTEST = U.SELFTEST or {}

function U.SelfTest()
    local ok, bad, ex = 0, 0, {}
    for _, t in ipairs(U.SELFTEST) do
        local dom, en, want, id, field = t[1], t[2], t[3], t[4], t[5]
        local got = id and U.ID(dom, id, field) or U.T(dom, en)
        if got and (not want or got:sub(1, #want) == want) then ok = ok + 1 else
            bad = bad + 1
            if #ex < 5 then ex[#ex + 1] = (en or tostring(id)):sub(1, 40) end
        end
    end
    U.Say(("самоперевірка: %d з %d%s"):format(ok, ok + bad, #ex > 0 and (" · промахи: " .. table.concat(ex, " | ")) or ""))
    return ok, bad
end
