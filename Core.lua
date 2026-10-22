---------------------------------------------------------------------------------------
--  GeminiOps/Core.lua — Personal AI Account, Profile & QoL Management Utility
--  Authors: Gemini (Tiger) & Anya (5cr3am1ng5oul)
--
--  Purpose ("Мухи отдельно от котлет"):
--  Keep public addons (like SpArc) 100% pure for external players, while routing all
--  personal account automation, live AceDB profile cloning, CombatMode/BlizzMove QoL,
--  and SavedVariables operations through this dedicated standalone utility addon.
---------------------------------------------------------------------------------------
local _G = _G
local GeminiOps = _G.GeminiOps or {}
_G.GeminiOps = GeminiOps

GeminiOps.VERSION = "1.0.0"
GeminiOps.DEFAULT_TEMPLATE_CHAR = "Ньарлатхотеп - Свежеватель Душ"
GeminiOps.DEFAULT_TEMPLATE_DETAILS = "Ньарлатхотеп-СвежевательДуш"

local C_AddOns = _G.C_AddOns
local C_CVar = _G.C_CVar
local C_Timer = _G.C_Timer
local UIParent = _G.UIParent
local pcall = _G.pcall
local ipairs = _G.ipairs
local pairs = _G.pairs
local type = _G.type

local function DeepCopyTable(src, seen)
  if type(src) ~= "table" then return src end
  if seen and seen[src] then return seen[src] end
  local s = seen or {}
  local copy = {}
  s[src] = copy
  for k, v in pairs(src) do
    copy[DeepCopyTable(k, s)] = DeepCopyTable(v, s)
  end
  return copy
end

GeminiOps.DeepCopyTable = DeepCopyTable

function GeminiOps:EnsureDB()
  _G.GeminiOpsDB = _G.GeminiOpsDB or {}
  local db = _G.GeminiOpsDB
  db.clonedCharacters = db.clonedCharacters or {}
  db.completedTasks = db.completedTasks or {}
  db.templateChar = db.templateChar or GeminiOps.DEFAULT_TEMPLATE_CHAR
  return db
end

---------------------------------------------------------------------------------------
--  1. PERSONAL ENVIRONMENT & ELVUI CHAT GUARD
---------------------------------------------------------------------------------------
function GeminiOps.ForceElvUIChatAlwaysVisible()
  local E = _G.ElvUI and _G.ElvUI[1]
  if E and E.db then
    E.db.LeftChatPanelFaded = nil
    E.db.RightChatPanelFaded = nil
    if E.db.chat then
      E.db.chat.fade = false
      E.db.chat.hideChatToggles = true
      E.db.chat.inactivityTimer = 120
    end
  end
  if _G.LeftChatPanel then
    if E and E.UIFrameFadeRemoveFrame then
      pcall(E.UIFrameFadeRemoveFrame, E, _G.LeftChatPanel)
    end
    pcall(_G.LeftChatPanel.SetAlpha, _G.LeftChatPanel, 1)
    pcall(_G.LeftChatPanel.Show, _G.LeftChatPanel)
  end
  if _G.RightChatPanel then
    if E and E.UIFrameFadeRemoveFrame then
      pcall(E.UIFrameFadeRemoveFrame, E, _G.RightChatPanel)
    end
    pcall(_G.RightChatPanel.SetAlpha, _G.RightChatPanel, 1)
    pcall(_G.RightChatPanel.Show, _G.RightChatPanel)
  end
  if _G.LeftChatToggleButton then
    pcall(_G.LeftChatToggleButton.SetAlpha, _G.LeftChatToggleButton, 0)
    pcall(_G.LeftChatToggleButton.EnableMouse, _G.LeftChatToggleButton, false)
  end
  if _G.RightChatToggleButton then
    pcall(_G.RightChatToggleButton.SetAlpha, _G.RightChatToggleButton, 0)
    pcall(_G.RightChatToggleButton.EnableMouse, _G.RightChatToggleButton, false)
  end
  for i = 1, 10 do
    local cf = _G["ChatFrame" .. i]
    if cf and cf.SetFading then
      pcall(cf.SetFading, cf, false)
    end
  end
end

function GeminiOps.ApplyEnvironmentHygiene()
  if C_CVar and C_CVar.SetCVar then
    pcall(C_CVar.SetCVar, "assistedCombatHighlight", "1")
  end
  if C_AddOns and C_AddOns.EnableAddOn then
    pcall(C_AddOns.EnableAddOn, "!BugGrabber")
    pcall(C_AddOns.EnableAddOn, "BugSack")
  end
  if C_AddOns and C_AddOns.DisableAddOn then
    pcall(C_AddOns.DisableAddOn, "WeakAuras")
    pcall(C_AddOns.DisableAddOn, "WeakAurasOptions")
    pcall(C_AddOns.DisableAddOn, "WeakAurasArchive")
    pcall(C_AddOns.DisableAddOn, "WeakAurasCompanion")
  end
  if UIParent and UIParent.UnregisterEvent then
    pcall(UIParent.UnregisterEvent, UIParent, "LUA_WARNING")
    pcall(UIParent.UnregisterEvent, UIParent, "ADDON_ACTION_FORBIDDEN")
    pcall(UIParent.UnregisterEvent, UIParent, "ADDON_ACTION_BLOCKED")
  end
  if _G.StaticPopupDialogs then
    _G.StaticPopupDialogs["TOO_MANY_LUA_ERRORS"] = nil
  end
  if _G.StaticPopup_Hide then
    pcall(_G.StaticPopup_Hide, "TOO_MANY_LUA_ERRORS")
    pcall(_G.StaticPopup_Hide, "ADDON_ACTION_FORBIDDEN")
  end
  GeminiOps.ForceElvUIChatAlwaysVisible()
end

---------------------------------------------------------------------------------------
--  2. COMBATMODE WATCHLIST & BLIZZMOVE 1.5X ULTRAWIDE QOL
---------------------------------------------------------------------------------------
local COMBATMODE_EXTRA_FRAMES = {
  "EndeavorTrackerFrame",
  "HomeBoundMainFrame",
  "DecorVendorFrame",
  "DecoTrackerFrame",
  "HousingDashboardFrame",
  "HousingModelPreviewFrame",
  "HousingCatalogFrame",
  "HousingEditorFrame",
  "HousingControlsFrame",
  "HousingPlotSettingsFrame",
  "HousingPermissionSettingsFrame",
  "BetterBagsBagBackpack",
  "BetterBagsBagBank",
  "ElvUI_ContainerFrame",
  "ElvUI_BankContainerFrame",
  "Baganator_SingleViewBackpackViewFrame",
  "Baganator_SingleViewBankViewFrame",
  "Baganator_CategoryViewBackpackViewFrame",
  "Baganator_CategoryViewBankViewFrame",
  "ContainerFrameCombinedBags",
  "ContainerFrame1",
  "BankFrame",
  "AccountBankPanel",
  "PlumberLandingPage",
  "MerchantFrame",
  "MailFrame",
  "TradeFrame",
  "GossipFrame",
  "QuestFrame",
  "ItemTextFrame",
  "DressUpFrame",
  "CollectionsJournal",
  "EncounterJournal",
  "AchievementFrame",
  "CommunitiesFrame",
  "PVEFrame",
  "FriendsFrame",
  "AuctionHouseFrame",
  "ProfessionsFrame",
  "ProfessionsBookFrame",
  "ClassTrainerFrame",
  "PlayerChoiceFrame",
  "GenericTraitFrame",
  "ItemUpgradeFrame",
  "ItemInteractionFrame",
  "ScrappingMachineFrame",
  "WeeklyRewardsFrame",
  "WorldMapFrame",
  "SettingsPanel",
  "EditModeManagerFrame",
  "SpArcControlCenter",
}

function GeminiOps.ApplyExternalAddonQoL()
  if type(_G.CombatModeDB) == "table" then
    _G.CombatModeDB.global = _G.CombatModeDB.global or {}
    _G.CombatModeDB.global.watchlist = _G.CombatModeDB.global.watchlist or {}
    local wl = _G.CombatModeDB.global.watchlist
    local existing = {}
    for _, name in ipairs(wl) do
      existing[name] = true
    end
    for _, name in ipairs(COMBATMODE_EXTRA_FRAMES) do
      if not existing[name] then
        wl[#wl + 1] = name
        existing[name] = true
      end
    end
  end

  if type(_G.BlizzMoveDB) == "table" then
    _G.BlizzMoveDB.savePosStrategy = "permanent"
    _G.BlizzMoveDB.saveScaleStrategy = "permanent"
    _G.BlizzMoveDB.scales = _G.BlizzMoveDB.scales or {}
    _G.BlizzMoveDB.points = _G.BlizzMoveDB.points or {}

    local scales = _G.BlizzMoveDB.scales
    local points = _G.BlizzMoveDB.points

    local centerFrames = {
      MerchantFrame     = { scale = 1.5, x = -220, y = 40 },
      GossipFrame       = { scale = 1.5, x = -220, y = 40 },
      QuestFrame        = { scale = 1.5, x = -220, y = 40 },
      ItemTextFrame     = { scale = 1.5, x = -220, y = 40 },
      ClassTrainerFrame = { scale = 1.5, x = -180, y = 40 },
      MailFrame         = { scale = 1.5, x = -220, y = 40 },
      DressUpFrame      = { scale = 1.35, x = 220, y = 30 },
    }

    for frameName, cfg in pairs(centerFrames) do
      if not scales[frameName] then
        scales[frameName] = cfg.scale
      end
      if not points[frameName] then
        points[frameName] = {
          startPoints = {
            { "CENTER", "UIParent", "CENTER", cfg.x, cfg.y },
          },
          dragPoints = {
            { "CENTER", "UIParent", "CENTER", cfg.x, cfg.y },
          },
        }
      end
    end
  end

  -- Ensure both "G" (hold) and "`" (toggle) are bound to "Combat Mode - Mouse Look"
  if _G.GetBindingKey and _G.SetBinding and not (_G.InCombatLockdown and _G.InCombatLockdown()) then
    local k1, k2 = _G.GetBindingKey("Combat Mode - Mouse Look")
    local hasG = (k1 == "G" or k2 == "G")
    local hasTick = (k1 == "`" or k2 == "`")
    if not hasG or not hasTick then
      pcall(_G.SetBinding, "G", "Combat Mode - Mouse Look")
      pcall(_G.SetBinding, "`", "Combat Mode - Mouse Look")
      if _G.SaveBindings and _G.GetCurrentBindingSet then
        pcall(_G.SaveBindings, _G.GetCurrentBindingSet())
      end
      local CM = _G.CombatMode
      if CM then
        if CM.ApplyToggleFocusTargetBinding then pcall(CM.ApplyToggleFocusTargetBinding) end
        if CM.ApplyCycleFocusBindings then pcall(CM.ApplyCycleFocusBindings) end
      end
    end
  end
end

---------------------------------------------------------------------------------------
--  3. SAFE ACEDB & ADDON PROFILE CLONER (PRIEST TEMPLATE -> ALT)
---------------------------------------------------------------------------------------
function GeminiOps.GetCurrentCharKey()
  if not _G.UnitName or not _G.GetRealmName then return nil end
  local name = _G.UnitName("player")
  local realm = _G.GetRealmName()
  if not name or not realm then return nil end
  return name .. " - " .. realm, name .. "-" .. realm:gsub("%s+", "")
end

function GeminiOps.CloneCharacterProfiles(srcKey, dstKey, force)
  srcKey = srcKey or GeminiOps.DEFAULT_TEMPLATE_CHAR
  local curKey, curDetKey = GeminiOps.GetCurrentCharKey()
  dstKey = dstKey or curKey
  if not dstKey or dstKey == srcKey then
    return false, "Target character is same as template (" .. tostring(srcKey) .. ")"
  end

  local gopsDB = GeminiOps:EnsureDB()
  if gopsDB.clonedCharacters[dstKey] == "v2" and not force then
    return false, "Already cloned (v2)"
  end

  -- 1. ElvUI (via AceDB SetProfile + CopyProfile so merged runtime defaults stay intact)
  local E = _G.ElvUI and _G.ElvUI[1]
  if E and E.data and E.data.SetProfile and E.data.CopyProfile then
    pcall(function()
      if _G.ElvDB and _G.ElvDB.profiles and _G.ElvDB.profiles[srcKey] then
        E.data:SetProfile(dstKey)
        E.data:CopyProfile(srcKey, false)
        if E.StaggeredUpdateAll then
          E:StaggeredUpdateAll()
        elseif E.UpdateAll then
          E:UpdateAll(true)
        end
      end
    end)
  end

  -- 2. ElvPrivateDB (disable ElvUI ActionBars/Nameplates/Bags so Bartender4/Plater/BetterBags work cleanly)
  if E and E.private then
    E.private.actionbar = E.private.actionbar or {}
    E.private.actionbar.enable = false
    E.private.nameplates = E.private.nameplates or {}
    E.private.nameplates.enable = false
    E.private.bags = E.private.bags or {}
    E.private.bags.enable = false
    E.private.install_complete = E.version or 15.10
  end
  if type(_G.ElvPrivateDB) == "table" and _G.ElvPrivateDB.profiles and _G.ElvPrivateDB.profiles[srcKey] then
    _G.ElvPrivateDB.profileKeys = _G.ElvPrivateDB.profileKeys or {}
    _G.ElvPrivateDB.profileKeys[dstKey] = dstKey
    _G.ElvPrivateDB.profiles[dstKey] = DeepCopyTable(_G.ElvPrivateDB.profiles[srcKey])
  end

  -- 3. Bartender4 (AceDB + all child bar namespaces)
  local BT4 = _G.Bartender4
  if BT4 and BT4.db and BT4.db.SetProfile and BT4.db.CopyProfile then
    pcall(function()
      if _G.Bartender4DB and _G.Bartender4DB.profiles and _G.Bartender4DB.profiles[srcKey] then
        BT4.db:SetProfile(dstKey)
        BT4.db:CopyProfile(srcKey, false)
      end
    end)
  end

  -- 4. Plater (AceDB)
  local Plater = _G.Plater
  if Plater and Plater.db and Plater.db.SetProfile and Plater.db.CopyProfile then
    pcall(function()
      if _G.PlaterDB and _G.PlaterDB.profiles and _G.PlaterDB.profiles[srcKey] then
        Plater.db:SetProfile(dstKey)
        Plater.db:CopyProfile(srcKey, false)
        if Plater.RefreshDB then Plater.RefreshDB() end
        if Plater.UpdateAllPlates then Plater.UpdateAllPlates() end
      end
    end)
  end

  -- 5. CombatMode (AceDB)
  local CM = _G.CombatMode
  if CM and CM.db and CM.db.SetProfile and CM.db.CopyProfile then
    pcall(function()
      if _G.CombatModeDB and _G.CombatModeDB.profiles and _G.CombatModeDB.profiles[srcKey] then
        CM.db:SetProfile(dstKey)
        CM.db:CopyProfile(srcKey, false)
      end
    end)
  end

  -- 6. Details! Damage Meter (Profile + Window Position)
  local srcDetKey = GeminiOps.DEFAULT_TEMPLATE_DETAILS
  local dstDetKey = curDetKey or dstKey:gsub("%s+", "")
  if type(_G._detalhes_global) == "table" and type(_G._detalhes_global.__profiles) == "table" then
    local srcProf = _G._detalhes_global.__profiles[srcDetKey]
    if type(srcProf) == "table" then
      _G._detalhes_global.__profiles[dstDetKey] = DeepCopyTable(srcProf)
      local Details = _G.Details or _G._detalhes
      if Details and Details.ApplyProfile then
        pcall(Details.ApplyProfile, Details, dstDetKey)
      end
      if Details and Details.GetInstance and srcProf.instances and srcProf.instances[1] then
        pcall(function()
          local inst = Details:GetInstance(1)
          if inst then
            inst.posicao = DeepCopyTable(srcProf.instances[1].posicao)
            if inst.RestoreMainWindowPosition then
              inst:RestoreMainWindowPosition(true)
            end
            if inst.SaveMainWindowPosition then
              inst:SaveMainWindowPosition()
            end
          end
        end)
      end
    end
  end

  -- 7. Other AceDB SavedVariables tables
  local otherAddons = {
    "MasqueDB",
    "BetterBagsDB",
    "BigWigs3DB",
    "Krowi_ExtendedVendorUI_DB",
    "MoveSearchEyeDB",
  }
  for _, globalName in ipairs(otherAddons) do
    local sv = _G[globalName]
    if type(sv) == "table" and type(sv.profileKeys) == "table" and type(sv.profiles) == "table" then
      local srcProfName = sv.profileKeys[srcKey]
      if srcProfName and type(sv.profiles[srcProfName]) == "table" then
        sv.profiles[dstKey] = DeepCopyTable(sv.profiles[srcProfName])
        sv.profileKeys[dstKey] = dstKey
      end
    end
  end

  gopsDB.clonedCharacters[dstKey] = "v2"
  return true, "Cloned all profiles from [" .. tostring(srcKey) .. "] to [" .. tostring(dstKey) .. "]"
end

---------------------------------------------------------------------------------------
--  3B. STARHAMMER ARMS WARRIOR MACRO SYNC (SLAYER DELVES/M+ & FALLBACKS)
---------------------------------------------------------------------------------------
local STARHAMMER_MACROS = {
  ["1"] = "#showtooltip\n/stopmacro [flying]\n/cast [known:845] Рассекающий удар; Вихрь",
  ["2"] = "#showtooltip\n/stopmacro [flying]\n/cast [known:190456] !Стойкость к боли\n/cast Верная победа",
  ["3"] = "#showtooltip Аватара\n/stopmacro [flying]\n/cast !Боевая стойка\n/cast Аватара",
  ["B3"] = "#showtooltip\n/stopmacro [flying]\n/cast [known:5246,@target,harm] Устрашающий крик; [known:384100] Крик берсерка; Ярость берсерка",
  ["SB3"] = "#showtooltip\n/stopmacro [flying]\n/cast [known:12323] Пронзительный вой; [known:384100] Крик берсерка; Ярость берсерка",
  ["CM1"] = "#showtooltip Бой насмерть\n/stopmacro [flying]\n/cast !Оборонительная стойка\n/cast Бой насмерть",
  ["CM2"] = "#showtooltip [known:383762] Горестная невосприимчивость; Ободряющий клич\n/stopmacro [flying]\n/cast !Оборонительная стойка\n/cast [known:383762] Горестная невосприимчивость; Ободряющий клич",
  ["M1"] = "#showtooltip [known:262161] Миротворец; [known:436358] Сокрушение; Удар колосса\n/stopmacro [flying]\n/cast !Боевая стойка\n/cast [known:262161] Миротворец; [known:436358] Сокрушение; Удар колосса",
  ["M2"] = "#showtooltip\n/stopmacro [flying][nocombat]\n/cast [known:228920, @player] Опустошитель; Вихрь клинков",
  ["R"] = "#showtooltip\n/stopmacro [flying]\n/cast [known:384318] Громогласный рык; [known:376079,@player] Копье чемпиона; [known:772] Кровопускание; Размашистые удары",
  ["SM2"] = "#showtooltip Размашистые удары\n/stopmacro [flying]\n/cast !Боевая стойка\n/cast Размашистые удары\n/cast [combat] Аватара",
  ["T"] = "#showtooltip\n/stopmacro [flying]\n#FS EH, X\n/cast [known:107570,@none][known:107570,@target] Удар громовержца; [@target] Героический бросок",
  ["V"] = "#showtooltip\n/stopmacro [flying]\n/cast [stance:1] Боевая стойка; Оборонительная стойка",
}

local STARHAMMER_SQ_THUNDER = "#showtooltip\n/stopmacro [flying]\n/cast [known:6343] Удар грома; Мощный удар"
local STARHAMMER_SQ_SHARPEN = "#showtooltip\n/stopmacro [flying]\n/cast [known:198817] Заточка клинка; [known:20572] Кровавое неистовство; Размашистые удары"

function GeminiOps.SyncStarhammerMacros(force)
  local curKey = GeminiOps.GetCurrentCharKey()
  if curKey ~= "Стархаммер - Свежеватель Душ" then
    return false, "Macro sync is only for Стархаммер"
  end
  if _G.InCombatLockdown and _G.InCombatLockdown() then
    return false, "Cannot sync macros in combat"
  end
  local gopsDB = GeminiOps:EnsureDB()
  if gopsDB.completedTasks["starhammer_macros_v4"] and not force then
    return false, "Already synced (v4)"
  end
  if not _G.GetMacroInfo or not _G.EditMacro then
    return false, "Macro API unavailable"
  end

  local updated = 0
  for idx = 121, 150 do
    local name, _, body = _G.GetMacroInfo(idx)
    if name then
      if name == "SQ" and type(body) == "string" then
        if body:find("Заточка") or body:find("Кровав") then
          pcall(_G.EditMacro, idx, "SQ", "INV_MISC_QUESTIONMARK", STARHAMMER_SQ_SHARPEN)
          updated = updated + 1
        else
          pcall(_G.EditMacro, idx, "SQ", "INV_MISC_QUESTIONMARK", STARHAMMER_SQ_THUNDER)
          updated = updated + 1
        end
      elseif STARHAMMER_MACROS[name] then
        pcall(_G.EditMacro, idx, name, "INV_MISC_QUESTIONMARK", STARHAMMER_MACROS[name])
        updated = updated + 1
      end
    end
  end

  if updated > 0 then
    gopsDB.completedTasks["starhammer_macros_v4"] = true
  end
  return updated > 0, "Обновлено макросов Стархаммера (v4): " .. tostring(updated)
end

function GeminiOps.EnableStarhammerBar5(force)
  local curKey = GeminiOps.GetCurrentCharKey()
  if curKey ~= "Стархаммер - Свежеватель Душ" then
    return false
  end
  if _G.InCombatLockdown and _G.InCombatLockdown() then
    return false
  end
  local gopsDB = GeminiOps:EnsureDB()
  if gopsDB.completedTasks["starhammer_bt4_bar5_v1"] and not force then
    return false
  end

  local BT4 = _G.Bartender4
  if not BT4 or not BT4.GetModule then
    return false
  end

  local abMod = BT4:GetModule("ActionBars", true)
  if abMod and abMod.db and abMod.db.profile and abMod.db.profile.actionbars then
    local b5 = abMod.db.profile.actionbars[5]
    if b5 then
      b5.enabled = true
      b5.WoW10Layout = true
      b5.version = 3
      b5.rows = 1
      b5.buttons = 12
      b5.showgrid = true
      b5.fadeout = false
      b5.fadeoutalpha = 1
      b5.visibility = b5.visibility or {}
      b5.visibility.custom = false
      b5.visibility.combat = false
      b5.visibility.nocombat = false
      b5.position = b5.position or {}
      b5.position.point = "BOTTOM"
      b5.position.x = -327.75
      b5.position.y = 302
      b5.position.scale = 0.75
      if abMod.EnableBar then
        pcall(abMod.EnableBar, abMod, 5)
      end
      if abMod.actionbars and abMod.actionbars[5] then
        local barObj = abMod.actionbars[5]
        pcall(barObj.ApplyConfig, barObj, b5)
      end
    end
  end

  local stMod = BT4:GetModule("StanceBar", true)
  if stMod and stMod.db and stMod.db.profile then
    local stCfg = stMod.db.profile
    stCfg.position = stCfg.position or {}
    stCfg.position.point = "BOTTOM"
    stCfg.position.x = -327.75
    stCfg.position.y = 338
    stCfg.position.scale = 0.9
    if stMod.bar and stMod.bar.ApplyConfig then
      pcall(stMod.bar.ApplyConfig, stMod.bar, stCfg)
    end
  end

  gopsDB.completedTasks["starhammer_bt4_bar5_v1"] = true
  return true, "Включена Панель 5 Bartender4 (1, 2, 3, 4 / Shift+1..4) третьей сверху в масштабе 0.75"
end

---------------------------------------------------------------------------------------
--  4. EVENT LOOP & SLASH COMMANDS (/gops, /gemini)
---------------------------------------------------------------------------------------
local eventFrame = _G.CreateFrame("Frame", "GeminiOpsEventFrame", UIParent)
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LOGOUT")

eventFrame:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    GeminiOps.ApplyEnvironmentHygiene()
    GeminiOps.ApplyExternalAddonQoL()

    if C_Timer and C_Timer.After then
      C_Timer.After(1.5, function()
        GeminiOps.ApplyEnvironmentHygiene()
        GeminiOps.ApplyExternalAddonQoL()

        -- Auto-clone & macro sync if Стархаммер has not received them yet
        local curKey = GeminiOps.GetCurrentCharKey()
        if curKey == "Стархаммер - Свежеватель Душ" then
          local ok, msg = GeminiOps.CloneCharacterProfiles(GeminiOps.DEFAULT_TEMPLATE_CHAR, curKey, false)
          if ok then
            print("|cff00ccff[GeminiOps]|r " .. tostring(msg))
          end
          local okM, msgM = GeminiOps.SyncStarhammerMacros(false)
          if okM then
            print("|cff00ccff[GeminiOps]|r " .. tostring(msgM))
          end
          local okB, msgB = GeminiOps.EnableStarhammerBar5(false)
          if okB then
            print("|cff00ccff[GeminiOps]|r " .. tostring(msgB))
          end
        end
      end)
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    GeminiOps.ApplyEnvironmentHygiene()
  elseif event == "PLAYER_LOGOUT" then
    GeminiOps.ApplyExternalAddonQoL()
  end
end)

_G.SLASH_GEMINIOPS1 = "/gops"
_G.SLASH_GEMINIOPS2 = "/gemini"
_G.SlashCmdList["GEMINIOPS"] = function(msg)
  local cmd = (msg or ""):match("^(%S*)")
  cmd = (cmd or ""):lower()

  if cmd == "clone" then
    local curKey = GeminiOps.GetCurrentCharKey()
    local ok, statusMsg = GeminiOps.CloneCharacterProfiles(GeminiOps.DEFAULT_TEMPLATE_CHAR, curKey, true)
    print("|cff00ccff[GeminiOps]|r " .. tostring(statusMsg))
    if ok then
      print("|cff00ccff[GeminiOps]|r Напиши |cffffd100/reload|r, чтобы применить приватные модули ElvUI.")
    end
  elseif cmd == "macros" then
    local okM, msgM = GeminiOps.SyncStarhammerMacros(true)
    print("|cff00ccff[GeminiOps]|r " .. tostring(msgM))
  elseif cmd == "qol" then
    GeminiOps.ApplyExternalAddonQoL()
    GeminiOps.ApplyEnvironmentHygiene()
    print("|cff00ccff[GeminiOps]|r Применены настройки CombatMode (watchlist), BlizzMove (1.5x центр) и защита чата ElvUI.")
  else
    local curKey = GeminiOps.GetCurrentCharKey() or "Unknown"
    local E = _G.ElvUI and _G.ElvUI[1]
    local elvProf = (E and E.data and E.data.GetCurrentProfile and E.data:GetCurrentProfile()) or "N/A"
    local btProf = (_G.Bartender4 and _G.Bartender4.db and _G.Bartender4.db.GetCurrentProfile and _G.Bartender4.db:GetCurrentProfile()) or "N/A"
    local plProf = (_G.Plater and _G.Plater.db and _G.Plater.db.GetCurrentProfile and _G.Plater.db:GetCurrentProfile()) or "N/A"
    print("|cff00ccff[GeminiOps v" .. GeminiOps.VERSION .. "]|r Персонаж: |cffffd100" .. curKey .. "|r")
    print("  • Профиль ElvUI: |cff00ff96" .. tostring(elvProf) .. "|r | Bartender4: |cff00ff96" .. tostring(btProf) .. "|r | Plater: |cff00ff96" .. tostring(plProf) .. "|r")
    print("  • Команды: |cffffd100/gops clone|r (склонировать профили Ньярлатхотепа на текущего чара), |cffffd100/gops qol|r (обновить исключения камеры и масштаб окон).")
  end
end
