# Uwow — українська локалізація World of Warcraft

Аддон для World of Warcraft (Retail, Midnight 12.x), що перекладає гру українською: квести, діалоги й субтитри NPC,
імена, предмети, закляття з живими числами, таланти, досягнення, журнал підземель, колекції, мапу, інтерфейс.

**Завантажити готовий аддон:** https://uwow.wearebob.dev · **Поточна версія:** 0.3.11

## Що тут

| тека / файл | що це | ліцензія |
|---|---|---|
| `addon/Uwow/` | код аддона (Lua): ядро, нормалізація тексту, поверхні інтерфейсу, налаштування, `/uw fix` | MIT |
| `tests/` | офлайн-тести в Lua 5.1 із заглушками API WoW | MIT |
| `translations/` | переклади EN → UA за типами тексту, TSV | CC BY 4.0 |
| `glossary.tsv` | глосарій власних назв EN → UA (55,200 записів) | CC BY 4.0 |

Дані аддона (`UwowData_*` і `Uwow/Data/`) збираються з `translations/` компілятором, який живе окремо; у готовому архіві
на сайті вони вже є. Англійські оригінали всіх текстів гри — у сусідньому репозиторії
[ipoltorak/wow-text-en](https://github.com/ipoltorak/wow-text-en).

## Переклади

Колонки: `id` (ID у грі, якщо текст до нього прив'язаний), `field` (поле: `title`, `description`, `name`…), `en`, `ua`,
`source` (`uwow` — переклад проєкту, `wowukrainizer` — з проєкту WowUkrainizer, MIT). Переноси записано як `\n`.
Змінні: `{p}` — ім'я гравця, `{c}` / `{c:форма}` — клас, `{r}` — раса, `{a}`, `{a1}` — аргументи, `{#}` / `{#N}` — числа,
`$p(ч:ж)` — слово за статтю гравця.

Усього рядків: 1,135,996 (з них з WowUkrainizer: 34,360).

| файл | рядків |
|---|---|
| `translations/ach.tsv` | 27,600 |
| `translations/collections.tsv` | 23,884 |
| `translations/currency.tsv` | 1,831 |
| `translations/dialog.tsv` | 96,096 |
| `translations/faction.tsv` | 1,150 |
| `translations/item.tsv` | 209,043 |
| `translations/journal.tsv` | 31,079 |
| `translations/mount.tsv` | 3,214 |
| `translations/names.tsv` | 43,720 |
| `translations/pet.tsv` | 4,247 |
| `translations/quest.tsv` (×2 частини: `quest-01.tsv`…) | 162,723 |
| `translations/questui.tsv` | 30,041 |
| `translations/sdesc.tsv` | 152,392 |
| `translations/spell.tsv` | 278,222 |
| `translations/ui.tsv` | 70,754 |

## Як допомогти

- Знайшли поганий переклад — у грі `/uw fix`, або форма на https://uwow.wearebob.dev/feedback.
- Просто грайте з аддоном: він збирає неперекладені тексти, файл `Uwow.lua` можна надіслати на https://uwow.wearebob.dev/capture.

## Ліцензія й подяки

Код — MIT. Переклади — CC BY 4.0, вказуйте «Uwow» як джерело. Частина перекладів власних назв і текстів походить з проєкту
[WowUkrainizer](https://github.com/Cancri55E/WowUkrainizer) (MIT). Англійські оригінали текстів належать Blizzard Entertainment;
World of Warcraft — торгова марка Blizzard Entertainment, Inc. Проєкт фанатський, некомерційний і не пов'язаний із Blizzard.
