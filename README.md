# GeminiOps — Personal AI Account, Profile Manager & Disaster Recovery (`v1.1.0`)

**GeminiOps** is the personal World of Warcraft engineering utility and full account backup/recovery repository built for **Anya (`5cr3am1ng5oul`) & Gemini (`Tiger`)**.

---

## 🛡️ Full WoW State Backup & Disaster Recovery (`Backup/`)

This repository also stores the complete, version-controlled snapshot of our World of Warcraft (`_retail_`) state so we can restore the entire UI, settings, macros, keybindings, and addons in **1 command** if Windows is reinstalled:

* **[`RESTORE_GUIDE.md`](./RESTORE_GUIDE.md)** — Full step-by-step Disaster Recovery Guide (in Russian) explaining everything backed up and how to restore on a fresh Windows/WoW installation.
* **[`Backup-WoWState.ps1`](./Backup-WoWState.ps1)** — Automated PowerShell backup script that snapshots:
  * `Backup/WTF/Config.wtf` (DirectX 12, `3440x1440` ultrawide, graphics, audio, global CVars)
  * `Backup/WTF/Account/112976512#2/` (account-wide `macros-cache.txt`, `bindings-cache.wtf`, `edit-mode-cache-account.txt`, `config-cache.wtf`)
  * `Backup/WTF/Account/112976512#2/SavedVariables/*.lua` (all 57+ addon databases: `ElvUI`, `Plater`, `SpArc`, `MAWM`, `MountCollector`, `Bartender4`, `Details`, `CombatMode`, `BlizzMove`, `Baganator`, `Syndicator`, `Masque`, `Homestead`, etc.)
  * `Backup/WTF/Account/112976512#2/<Realm>/<Character>/` across all realms (**Пиратская Бухта**, **Свежеватель Душ**, **Вечная Песня**, **Борейская тундра**, **Дракономор**, **Ревущий фьорд**, etc.)
  * `Backup/ElvUI_Bundle.zip` (offline package of `ElvUI`, `ElvUI_Options`, and `ElvUI_Libraries`)
  * `Backup/AddOns_Manifest.json` (inventory of all 100 installed addons with versions & CurseForge/Wago IDs)
* **[`Restore-WoWState.ps1`](./Restore-WoWState.ps1)** — One-click PowerShell restore script that restores `WTF/`, unpacks `ElvUI_Bundle.zip`, and deploys our 4 custom GitHub addons (`GeminiOps`, `SpArc`, `MAWM`, `MountCollector`) directly into `Interface\AddOns\`.

---

## 🏛️ Architectural Rule ("Мухи отдельно от котлет")
* **Public Addons ([`SpArc`](https://github.com/nakesreong/SpArc), [`MAWM`](https://github.com/nakesreong/MAWM), [`MountCollector`](https://github.com/nakesreong/MountCollector))** stay 100% pure, portable, and free of account-specific or third-party addon overrides.
* **Personal Account Operations (`GeminiOps`)** live exclusively in this standalone addon:
  1. **Cross-Realm AceDB & Addon Profile Cloner (`/gops clone`)**: Automatically resolves the Priest template across **Пиратская Бухта** (`Ньарлатхотеп - Пиратская Бухта`) and **Свежеватель Душ** (`Ньарлатхотеп - Свежеватель Душ`) and clones `ElvUI`, `ElvPrivateDB`, `Bartender4` (plus all 10 bar namespaces), `Plater`, `SpArc`, `CombatMode`, `Details!` (including window coordinates), `Masque`, `BetterBags`, `BigWigs`, `Baganator`, and character keybindings.
  2. **Ultrawide & CombatMode QoL (`/gops qol`)**: Maintains `CombatModeDB.global.watchlist` and configures `BlizzMoveDB` with `1.5x` centered ultrawide coordinates (`3440x1440`) for `MerchantFrame`, `GossipFrame`, `QuestFrame`, `MailFrame`, and `ClassTrainerFrame`.
  3. **Details! Left Chat Integration (`/gops tab` / `/gops above`)**: Embeds `Details!` cleanly as a 3rd tab inside `LeftChatPanel` or nails it directly above `LeftChatPanel` so `RightChatPanel` (Loot) stays 100% unobstructed.

## ⌨️ Slash Commands
* `/gops` or `/gemini` — Show active character and profile status (`ElvUI`, `Bartender4`, `Plater`).
* `/gops clone` — Clone all UI profiles and keybindings from the template Priest to the currently logged-in character.
* `/gops tab` — Embed `Details!` as a toggleable 3rd tab inside the Left Chat Panel.
* `/gops above` — Nail `Details!` directly above the Left Chat Panel.
* `/gops qol` — Re-apply `CombatMode` cursor watchlist and `BlizzMove` `1.5x` centered ultrawide frames.
