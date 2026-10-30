# 🛡️ Полный регламент бэкапа и восстановления World of Warcraft (`GeminiOps Disaster Recovery`)

Этот документ описывает, **что именно сохранено** в репозитории `GeminiOps` (`https://github.com/nakesreong/GeminiOps.git`) из клиента World of Warcraft (`_retail_`) и **как за 2 минуты полностью восстановить весь интерфейс, профили, макросы, бинды и аддоны**, если завтра слетит Windows или придётся ставить систему и игру с нуля.

---

## 📦 1. Что именно забэкаплено в Git (`Backup/`)

Весь слепок живого состояния игры лежит в папке [`Backup/`](file:///c:/Users/ev3n7/.gemini/antigravity/scratch/Games/GeminiOps/Backup) (около `6.5 МБ` чистых конфигов в `Backup/WTF/` без мусорных `.bak`-файлов):

| Компонент | Путь в `Backup/` | Что внутри и зачем это нужно |
| :--- | :--- | :--- |
| **Глобальный конфиг клиента (`Config.wtf`)** | `Backup/WTF/Config.wtf` | Настройки графики (DirectX 12, ультравайд `3440x1440`, масштаб рендера, FPS-лимиты), звука, языка и базовых системных CVar'ов. **Никаких паролей или токенов внутри нет** — авторизация идёт только через Battle.net. |
| **Аккаунтные макросы, бинды и Edit Mode** | `Backup/WTF/Account/112976512#2/` (`macros-cache.txt`, `bindings-cache.wtf`, `edit-mode-cache-account.txt`, `config-cache.wtf`) | Все **общие макросы аккаунта** (`macros-cache.txt`, 23 КБ), глобальные горячие клавиши (`bindings-cache.wtf`), раскладки стандартного Режима Редактирования Blizzard (`edit-mode-cache-account.txt`) и серверные CVar'ы аккаунта. |
| **База профилей всех 57+ аддонов (`SavedVariables`)** | `Backup/WTF/Account/112976512#2/SavedVariables/*.lua` | **Сердце интерфейса (`5.8 МБ`):** все профили `ElvUI.lua`, `Plater.lua`, `Bartender4.lua`, `SpArc.lua`, `MAWM.lua`, `MountCollector.lua`, `GeminiOps.lua`, `Details.lua`, `CombatMode.lua`, `BlizzMove.lua` (1.5x масштаб окон), `Baganator.lua`, `Syndicator.lua`, `Masque.lua`, `SimpleAddonManager.lua`, `Homestead.lua`, `HomeBound.lua`, `TomTom.lua`, `Pawn.lua` и др. |
| **Персональные папки всех героев (по всем 9 мирам)** | `Backup/WTF/Account/112976512#2/<Сервер>/<Персонаж>/` | Папки персонажей на **Пиратской Бухте** (`Ньарлатхотеп`, `Трипобраз`, `Котастрофа`, `Котострофа`), **Свежевателе Душ** (`Ньарлатхотеп`, `Стархаммер`, `Калиратри`, `Трипобраз`, `Морвара`, `Моржовый`, `Улак` и др.), **Вечной Песне**, **Борейской тундре**, **Дракономоре**, **Ревущем фьорде** и т.д. Внутри каждого: **персональные макросы (`macros-cache.txt`)**, бинды персонажа, вкладки и цвета чата (`chat-cache.txt`), список включённых аддонов (`AddOns.txt`) и `SavedVariables/ElvUI.lua` (`ElvCharacterDB`). |
| **Офлайн-архив ElvUI (`ElvUI_Bundle.zip`)** | `Backup/ElvUI_Bundle.zip` | Так как **ElvUI** (`ElvUI`, `ElvUI_Options`, `ElvUI_Libraries`) качается с Tukui, а не из CurseForge, он упакован прямо в репозиторий, чтобы при восстановлении ElvUI разворачивался за 1 секунду без браузера. |
| **Манифест всех установленных аддонов (`AddOns_Manifest.json`)** | `Backup/AddOns_Manifest.json` | Полный реестр всех 100 папок в `Interface\AddOns` с точными версиями, названиями и `Curse-Project-ID` / `Wago-ID`. |

---

## 🚀 2. Процедура восстановления с нуля («Если завтра слетела винда»)

Представим худший сценарий: чистая Windows, установлен только Battle.net, Git и скачан клиент World of Warcraft (`C:\Program Files (x86)\World of Warcraft\_retail_`).

### Шаг 1. Клонируем `GeminiOps` (и наши аддоны)
Открой PowerShell и выполни:
```powershell
mkdir "C:\Users\$env:USERNAME\.gemini\antigravity\scratch\Games" -Force
cd "C:\Users\$env:USERNAME\.gemini\antigravity\scratch\Games"

git clone https://github.com/nakesreong/GeminiOps.git
```

### Шаг 2. Запускаем однокнопочный скрипт восстановления (`Restore-WoWState.ps1`)
Убедись, что **игра (`Wow.exe`) закрыта** (иначе при выходе из игры клиент перезапишет восстановленные `SavedVariables` пустыми данными из оперативной памяти!), и запусти:
```powershell
powershell -ExecutionPolicy Bypass -File ".\GeminiOps\Restore-WoWState.ps1"
```

**Что скрипт сделает автоматически за 5 секунд:**
1. Проверит, что `Wow.exe` не запущен.
2. Если в папке игры уже есть какая-то папка `WTF`, сохранит её в страховочный архив `WTF_PreRestore_<дата>.zip`.
3. Скопирует все `362+` файла из `Backup/WTF/` в `C:\Program Files (x86)\World of Warcraft\_retail_\WTF\` (`Config.wtf`, все профили `SavedVariables`, макросы аккаунта и всех персонажей на Пиратской Бухте и Свежевателе Душ).
4. Распакует `Backup/ElvUI_Bundle.zip` (`ElvUI`, `ElvUI_Options`, `ElvUI_Libraries`) прямо в `Interface\AddOns\`.
5. Склонирует с GitHub (если их ещё нет рядом) и развернёт в `Interface\AddOns\` все 4 наших собственных аддона:
   - **`GeminiOps`** (`https://github.com/nakesreong/GeminiOps.git`)
   - **`SpArc`** (`https://github.com/nakesreong/SpArc.git`)
   - **`MAWM`** (`https://github.com/nakesreong/MAWM.git`)
   - **`MountCollector`** (`https://github.com/nakesreong/MountCollector.git`)
6. Сверит `Interface\AddOns\` со списком в `Backup/AddOns_Manifest.json` и выведет список недостающих сторонних аддонов из CurseForge.

### Шаг 3. Докачиваем сторонние аддоны через CurseForge (по желанию)
Открой приложение **CurseForge** → **World of Warcraft** и поставь сторонние аддоны из списка (`Bartender4`, `Plater`, `Details`, `Baganator`, `Syndicator`, `BlizzMove`, `CombatMode`, `Masque`, `Plumber`, `SimpleAddonManager`, `DialogueUI`, `FrameSort`, `LiteMount`, `BugSack`, `!BugGrabber`, `ElvUI_WindTools` и др.).
> **Важно:** Настраивать их заново **НЕ НУЖНО**! Все их профили, позиции баров, цвета неймплейтов и списки уже лежат на своих местах в `WTF\Account\112976512#2\SavedVariables\` после Шага 2 — как только ты скачаешь аддон в CurseForge, он сразу подхватит свой профиль.

---

## 🔄 3. Как обновлять бэкап в будущем (одной командой)

В любой момент, когда ты поменяла настройки в игре, сделала `/reload` или вышла из WoW, просто запусти:
```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\ev3n7\.gemini\antigravity\scratch\Games\GeminiOps\Backup-WoWState.ps1" -CommitAndPush
```
Скрипт сам обновит слепок `Backup/WTF/`, пересоберёт манифест `AddOns_Manifest.json`, закоммитит изменения и запушит их в приватный/личный репозиторий `GeminiOps` на GitHub.
