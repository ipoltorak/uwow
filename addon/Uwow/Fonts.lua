-- Uwow · Fonts.lua — кириличний шрифт лише для написів, які ми перекладаємо. Глобальні font-об'єкти не чіпаємо.
-- Одна точка для всіх поверхонь: U.Font(fs). U.Apply кличе її сама; поверхня, що ставить текст повз U.Apply
-- (власні написи, SetFormattedText), кличе U.Font(fs) перед SetText.
-- Режим — налаштування font: auto (кирилична версія того самого шрифту), friz, arial, off (шрифт не міняємо).
-- Клієнт enUS має кириличні варіанти FRIZQT___CYR, MORPHEUS_CYR, SKURRI_CYR; ARIALN кирилицю вже має.
local U = UWOW

local FILE = {
    friz = "Fonts\\FRIZQT___CYR.TTF",
    arial = "Fonts\\ARIALN.TTF",
    morpheus = "Fonts\\MORPHEUS_CYR.TTF",
    skurri = "Fonts\\SKURRI_CYR.TTF",
}
U.FONT_FILE = FILE
-- auto: підрядок шляху поточного шрифту → кириличний відповідник. Шрифти без кирилиці, яких тут нема, — Friz CYR.
local AUTO = {
    { "_cyr", false }, { "arialn", false }, { "frizqt__", FILE.friz }, { "morpheus", FILE.morpheus },
    { "skurri", FILE.skurri }, { "theboldfont", FILE.friz }, { "nim_", FILE.friz }, { "friends", FILE.friz },
}
U.FONT_MODES = { "auto", "friz", "arial", "off" }

local base = setmetatable({}, { __mode = "k" })   -- напис → {шлях, розмір, прапорці} до нашої зміни

local function target(path, mode)
    if mode ~= "auto" then return FILE[mode] end
    local low = path:lower()
    for _, m in ipairs(AUTO) do
        if low:find(m[1], 1, true) then return m[2] or nil end
    end
    return FILE.friz
end

function U.Font(fs)
    if not fs or not fs.GetFont then return end
    local mode = U.Settings and U.Settings.font or "auto"
    local b = base[fs]
    if mode == "off" then
        if b then pcall(fs.SetFont, fs, b[1], b[2], b[3]); base[fs] = nil end
        return
    end
    local ok, path, size, flags = pcall(fs.GetFont, fs)
    if not ok or type(path) ~= "string" then return end
    local want = target(b and b[1] or path, mode)
    if not want then                               -- шрифт уже з кирилицею: повернути свій, якщо міняли
        if b then pcall(fs.SetFont, fs, b[1], size, flags); base[fs] = nil end
        return
    end
    if want:lower() == path:lower() then return end
    if not b then base[fs] = { path, size, flags } end
    pcall(fs.SetFont, fs, want, size, flags)
end
U.CyrFont = U.Font                                 -- стара назва (Core/поверхні 0.3.0-dev.1)

-- Після зміни режиму — перешрифтувати вже перекладені написи.
function U.RefreshFonts()
    for fs in pairs(U.orig) do U.Font(fs) end
end
