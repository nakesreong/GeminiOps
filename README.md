# GeminiOps — Personal AI Account & Profile Manager (WoW Retail)

**GeminiOps** is a personal World of Warcraft management utility built for **Anya (`5cr3am1ng5oul`) & Gemini (`Tiger`)**.

## Architectural Rule ("Мухи отдельно от котлет")
* **Public Addons (like [`SpArc`](https://github.com/nakesreong/SpArc))** must stay 100% pure, portable, and free of account-specific or third-party addon overrides.
* **Personal Account Operations (`GeminiOps`)** live exclusively in this standalone addon:
  1. **Live AceDB & Addon Profile Cloner (`/gops clone`)**: Clones `ElvUI`, `ElvPrivateDB`, `Bartender4` (plus all 10 bar namespaces), `Plater`, `CombatMode`, `Details!` (including window coordinates), `Masque`, `BetterBags`, `BigWigs`, `Krowi_ExtendedVendorUI`, and character keybindings from the template character (`Ньарлатхотеп - Свежеватель Душ`) into independent per-character profiles for alts (`Стархаммер - Свежеватель Душ`, etc.) using official AceDB-3.0 runtime APIs (`SetProfile` + `CopyProfile`).
  2. **Ultrawide & CombatMode QoL (`/gops qol`)**: Automatically maintains `CombatModeDB.global.watchlist` (Housing frames, BetterBags, Baganator, Plumber, Vendor/Quest/Gossip dialogs) so cursor lock releases cleanly, and configures `BlizzMoveDB` with `1.5x` centered ultrawide coordinates for `MerchantFrame`, `GossipFrame`, `QuestFrame`, `MailFrame`, and `ClassTrainerFrame`.
  3. **ElvUI Chat & Popup Hygiene**: Keeps `ElvUI` chat panels unfaded and suppresses intrusive taint popups without touching third-party addon code.

## Slash Commands
* `/gops` or `/gemini` — Show active character and profile status (`ElvUI`, `Bartender4`, `Plater`).
* `/gops clone` — Clone all UI profiles and keybindings from the template Priest to the currently logged-in character.
* `/gops qol` — Re-apply `CombatMode` cursor watchlist and `BlizzMove` `1.5x` centered ultrawide frames.
