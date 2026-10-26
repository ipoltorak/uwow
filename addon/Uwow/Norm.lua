-- Uwow · Norm.lua — нормалізація англ. тексту в шаблон і 52-бітний хеш (двійник server/uwow2/norm.py;
-- паритет перевіряє tests/test_norm.lua на векторах, згенерованих Python).
local U = UWOW
local N = {}
U.Norm = N

local P1, P2, B1, B2, T26 = 67108859, 67108837, 131, 137, 67108864
local byte, sub, find, gsub = string.byte, string.sub, string.find, string.gsub

function N.hash(s)
    local h1, h2 = 0, 0
    for i = 1, #s do
        local c = byte(s, i)
        h1 = (h1 * B1 + c) % P1
        h2 = (h2 * B2 + c) % P2
    end
    return h1 * T26 + h2
end

local PUNCT = {
    ["\226\128\153"] = "'", ["\226\128\152"] = "'", ["\202\188"] = "'",
    ["\226\128\156"] = '"', ["\226\128\157"] = '"',
    ["\194\160"] = " ", ["\226\128\137"] = " ", ["\226\128\175"] = " ",
    ["\226\128\147"] = "-", ["\226\128\148"] = "-", ["\226\128\166"] = "...",
}

local function isW(b)
    return b and (b >= 128 or (b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or b == 95)
end

local function replaceWord(s, word, rep)
    if not word or word == "" then return s end
    local out, i, n = {}, 1, #word
    while true do
        local a, b = find(s, word, i, true)
        if not a then break end
        if not isW(byte(s, a - 1)) and not isW(byte(s, b + 1)) then
            out[#out + 1] = sub(s, i, a - 1); out[#out + 1] = rep
        else
            out[#out + 1] = sub(s, i, b)
        end
        i = b + 1
    end
    out[#out + 1] = sub(s, i)
    return table.concat(out)
end

-- числа: максимальний пробіг \d+([.,]\d+)*; межа зі «словом» або { } → лишити як є (без відкату)
local function templNumbers(s, keep)
    local nums, res, i, len = {}, {}, 1, #s
    while i <= len do
        local a, b = find(s, "%d+", i)
        if not a then break end
        while true do
            local c, d = find(s, "^[%.,]%d+", b + 1)
            if not c then break end
            b = d
        end
        local prev, nxt = byte(s, a - 1), byte(s, b + 1)
        if (prev and (isW(prev) or prev == 123)) or (nxt and (isW(nxt) or nxt == 125)) then
            res[#res + 1] = sub(s, i, b)
        else
            nums[#nums + 1] = sub(s, a, b)
            res[#res + 1] = sub(s, i, a - 1)
            res[#res + 1] = keep and sub(s, a, b) or "{#}"
        end
        i = b + 1
    end
    res[#res + 1] = sub(s, i)
    return table.concat(res), nums
end

local function punct(seq)
    for k, v in pairs(PUNCT) do
        if sub(seq, 1, #k) == k then return v .. sub(seq, #k + 1) end
    end
end

-- → шаблон, {числа}
function N.norm(s, speaker, player, keep)
    if type(s) ~= "string" or s == "" then return "", {} end
    s = gsub(gsub(s, "\r\n", "\n"), "\r", "\n")
    s = gsub(s, "|c%x%x%x%x%x%x%x%x", ""); s = gsub(s, "|cn[%w_]+:", ""); s = gsub(s, "|r", "")
    s = gsub(s, "|T.-|t", ""); s = gsub(s, "|A.-|a", ""); s = gsub(s, "|H.-|h(.-)|h", "%1")
    s = gsub(s, "|K.-|k", ""); s = gsub(s, "|n", "\n")
    s = gsub(s, "[\194\202\226][\128-\191]+", punct)
    if player then s = replaceWord(s, player, "{p}") end
    if speaker and #speaker >= 2 and speaker ~= player then s = replaceWord(s, speaker, "{a}") end
    s = gsub(s, "%%%d+%$s", "{a}"); s = gsub(s, "%%s", "{a}")
    s = gsub(s, "%$[nN]%f[^%w_]", "{p}")
    s = gsub(s, "<[nN][aA][mM][eE]>", "{p}"); s = gsub(s, "{[nN][aA][mM][eE]}", "{p}")
    s = gsub(s, "%%%d+%$d", "{#}"); s = gsub(s, "%%d", "{#}"); s = gsub(s, "{n}", "{#}"); s = gsub(s, "{m}", "{#}")
    local nums
    s, nums = templNumbers(s, keep)
    local lines = {}
    for ln in (s .. "\n"):gmatch("(.-)\n") do
        ln = gsub(ln, "[ \t]+", " "); ln = gsub(ln, "^ ", ""); ln = gsub(ln, " $", "")
        lines[#lines + 1] = ln
    end
    s = table.concat(lines, "\n")
    s = gsub(gsub(s, "^%s+", ""), "%s+$", "")
    return s, nums
end
