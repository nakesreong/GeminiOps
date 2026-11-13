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

GeminiOps.VERSION = "1.1.0"
GeminiOps.DEFAULT_TEMPLATE_CHAR = "Ньарлатхотеп - Свежеватель Душ"
GeminiOps.DEFAULT_TEMPLATE_DETAILS = "Ньарлатхотеп-Свежеватель Душ"
GeminiOps.PRIEST_TEMPLATE_CANDIDATES = {
  "Ньарлатхотеп - Пиратская Бухта",
  "Ньярлатхотеп - Пиратская Бухта",
  "Ньарлатхотеп - Свежеватель Душ",
}

function GeminiOps.ResolvePriestTemplateKey(dstKey)
  local profiles = _G.ElvDB and _G.ElvDB.profiles
  if type(profiles) == "table" then
    for _, cand in ipairs(GeminiOps.PRIEST_TEMPLATE_CANDIDATES) do
      if cand ~= dstKey and type(profiles[cand]) == "table" and next(profiles[cand]) ~= nil then
        -- Prefer a candidate that also exists in Bartender4DB (full configured profile)
        if not _G.Bartender4DB or not _G.Bartender4DB.profiles or _G.Bartender4DB.profiles[cand] then
          return cand
        end
      end
    end
  end
  return GeminiOps.DEFAULT_TEMPLATE_CHAR
end

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

local DeepCopy = DeepCopyTable
GeminiOps.DeepCopyTable = DeepCopyTable

local function OverwriteTableInPlace(dst, src)
  if type(dst) ~= "table" or type(src) ~= "table" then return end
  for k in pairs(dst) do
    if src[k] == nil then
      dst[k] = nil
    end
  end
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then
        dst[k] = {}
      end
      OverwriteTableInPlace(dst[k], v)
    else
      dst[k] = v
    end
  end
end

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
    if E.db.WT and E.db.WT.quest and E.db.WT.quest.turnIn then
      E.db.WT.quest.turnIn.enable = false
    end
    if E.db.WT and E.db.WT.combat and E.db.WT.combat.combatAlert then
      E.db.WT.combat.combatAlert.enable = false
    end
  end
  if _G.ElvDB and type(_G.ElvDB.profiles) == "table" then
    for _, prof in pairs(_G.ElvDB.profiles) do
      if type(prof) == "table" and prof.WT and prof.WT.combat then
        prof.WT.combat.combatAlert = prof.WT.combat.combatAlert or {}
        prof.WT.combat.combatAlert.enable = false
      end
    end
  end
  local W = (_G.WindTools and _G.WindTools[1]) or (_G.ElvUI_WindTools and _G.ElvUI_WindTools[1])
  if W and W.GetModule then
    local okTI, TI = pcall(W.GetModule, W, "TurnIn", true)
    if okTI and TI then
      if TI.db then TI.db.enable = false end
      if TI.UnregisterAllEvents then pcall(TI.UnregisterAllEvents, TI) end
      TI.initialized = false
    end
    local okCA, CA = pcall(W.GetModule, W, "CombatAlert", true)
    if okCA and CA then
      if CA.db then CA.db.enable = false end
      CA.ShowAlert = function() end
      CA.QueueAlert = function() end
      CA.PLAYER_REGEN_DISABLED = function() end
      CA.PLAYER_REGEN_ENABLED = function() end
      if CA.UnregisterAllEvents then pcall(CA.UnregisterAllEvents, CA) end
      if CA.AlertFrame and CA.AlertFrame.Hide then pcall(CA.AlertFrame.Hide, CA.AlertFrame) end
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

function GeminiOps.KillAllBlizzardTutorials()
  if _G.C_Tutorial and _G.C_Tutorial.AbandonTutorialArea then
    pcall(_G.C_Tutorial.AbandonTutorialArea)
  end
  if _G.AbandonTutorialArea then
    pcall(_G.AbandonTutorialArea)
  end
  if _G.HelpTip then
    if _G.HelpTip.HideAll then
      pcall(_G.HelpTip.HideAll, _G.HelpTip)
    end
    if _G.HelpTip.framePool and _G.HelpTip.framePool.EnumerateActive then
      pcall(function()
        for frame in _G.HelpTip.framePool:EnumerateActive() do
          if frame.Hide then frame:Hide() end
          if frame.SetAlpha then frame:SetAlpha(0) end
        end
      end)
    end
    _G.HelpTip.Show = function() return false end
  end
  for _, ptrTblName in ipairs({ "TutorialPointerFrame", "NPE_TutorialPointerFrame" }) do
    local ptr = _G[ptrTblName]
    if type(ptr) == "table" then
      ptr.Show = function() return 0 end
      if ptr.Hide then
        for id = 1, 30 do
          pcall(ptr.Hide, ptr, id)
        end
      end
    end
    for i = 1, 20 do
      local pf = _G[ptrTblName .. "_" .. i]
      if pf then
        if pf.Hide then pcall(pf.Hide, pf) end
        if pf.SetAlpha then pcall(pf.SetAlpha, pf, 0) end
        if pf.EnableMouse then pcall(pf.EnableMouse, pf, false) end
      end
    end
  end
  if _G.TutorialManager and _G.TutorialManager.Shutdown then
    pcall(_G.TutorialManager.Shutdown, _G.TutorialManager)
  end
  if _G.NPE_TutorialInterface and _G.NPE_TutorialInterface.Shutdown then
    pcall(_G.NPE_TutorialInterface.Shutdown, _G.NPE_TutorialInterface)
  end
  local tutorialFrames = {
    "NPE_TutorialMainFrame",
    "NPE_TutorialSingleKey_Frame",
    "NPE_TutorialKeyboardMouseFrame_Frame",
    "NPE_TutorialWalk_Frame",
    "TutorialMainFrame_Frame",
    "TutorialSingleKey_Frame",
    "TutorialKeyboardMouseFrame_Frame",
    "TutorialWalk_Frame",
    "TutorialLeaveButton",
  }
  for _, fName in ipairs(tutorialFrames) do
    local tf = _G[fName]
    if tf then
      if tf.Hide then pcall(tf.Hide, tf) end
      if tf.SetAlpha then pcall(tf.SetAlpha, tf, 0) end
      if tf.EnableMouse then pcall(tf.EnableMouse, tf, false) end
      if not tf._geminiKilled and tf.HookScript then
        tf._geminiKilled = true
        pcall(tf.HookScript, tf, "OnShow", function(s)
          if s.Hide then pcall(s.Hide, s) end
        end)
      end
    end
  end
end

function GeminiOps.ApplyEnvironmentHygiene()
  if C_CVar and C_CVar.SetCVar then
    pcall(C_CVar.SetCVar, "assistedCombatHighlight", "1")
    pcall(C_CVar.SetCVar, "CursorStickyCentering", "0")
    pcall(C_CVar.SetCVar, "scriptErrors", "1")
    pcall(C_CVar.SetCVar, "floatingCombatTextCombatState", "0")
    pcall(C_CVar.SetCVar, "showTutorials", "0")
    pcall(C_CVar.SetCVar, "showNPETutorials", "0")
    pcall(C_CVar.SetCVar, "hideAdventureJournalAlerts", "1")
  end
  GeminiOps.KillAllBlizzardTutorials()
  if C_AddOns and C_AddOns.EnableAddOn then
    pcall(C_AddOns.EnableAddOn, "!BugGrabber")
    pcall(C_AddOns.EnableAddOn, "BugSack")
  end
  if C_AddOns and C_AddOns.DisableAddOn then
    pcall(C_AddOns.DisableAddOn, "CombatMode")
    pcall(C_AddOns.DisableAddOn, "MoveSearchEye")
    pcall(C_AddOns.DisableAddOn, "WeakAuras")
    pcall(C_AddOns.DisableAddOn, "WeakAurasOptions")
    pcall(C_AddOns.DisableAddOn, "WeakAurasArchive")
    pcall(C_AddOns.DisableAddOn, "WeakAurasCompanion")
  end
  local E = _G.ElvUI and _G.ElvUI[1]
  if E and E.private and E.private.WT and E.privateVars and E.privateVars.profile and E.privateVars.profile.WT then
    for k, v in pairs(E.privateVars.profile.WT) do
      if E.private.WT[k] == nil and type(v) == "table" then
        E.private.WT[k] = v
      end
    end
  end
  if not (_G.InCombatLockdown and _G.InCombatLockdown()) then
    if _G.GetActionBarPage and _G.ChangeActionBarPage then
      local curPage = _G.GetActionBarPage()
      if curPage and curPage ~= 1 then
        pcall(_G.ChangeActionBarPage, 1)
      end
    end
    -- Unbind all F1..F12 keys (plus Shift/Ctrl/Alt modifiers) & hidden ACTIONPAGE binds so Insights recorder (F6/F7) and system hotkeys never conflict with WoW
    if _G.SetBinding then
      local changedBinds = false
      if _G.GetBindingKey then
        for _, pageAct in ipairs({
          "ACTIONPAGE1", "ACTIONPAGE2", "ACTIONPAGE3", "ACTIONPAGE4", "ACTIONPAGE5", "ACTIONPAGE6",
          "PREVIOUSACTIONPAGE", "NEXTACTIONPAGE",
        }) do
          local keys = { _G.GetBindingKey(pageAct) }
          for _, k in ipairs(keys) do
            if k and k ~= "" then
              pcall(_G.SetBinding, k, nil)
              changedBinds = true
            end
          end
        end
      end
      if _G.GetBindingAction then
        for i = 1, 12 do
          for _, prefix in ipairs({ "", "SHIFT-", "CTRL-", "ALT-" }) do
            local fKey = prefix .. "F" .. i
            local act = _G.GetBindingAction(fKey)
            if act and act ~= "" then
              pcall(_G.SetBinding, fKey, nil)
              changedBinds = true
            end
          end
        end
      end
      if changedBinds and _G.SaveBindings and _G.GetCurrentBindingSet then
        pcall(_G.SaveBindings, _G.GetCurrentBindingSet() or 2)
      end
    end
  end
  GeminiOps.ForceElvUIChatAlwaysVisible()
  GeminiOps.RestoreMicroMenuAndBagsWithoutElvUI()
end

function GeminiOps.RestoreMicroMenuAndBagsWithoutElvUI()
  if _G.ElvUI then return end
  if _G.InCombatLockdown and _G.InCombatLockdown() then return end

  local gopsDB = GeminiOps:EnsureDB()
  local migrateToTop = not gopsDB.completedTasks["bt4_top_micromenu_bags_v2"]

  -- Dismiss annoying yellow Blizzard tutorial HelpTips ("Откройте коллекцию отряда...")
  if _G.HelpTip and _G.HelpTip.HideAll then
    pcall(_G.HelpTip.HideAll, _G.HelpTip)
  end

  -- Restore Bartender4 MicroMenu and BagBar that were hidden when ElvUI WindTools GameBar was active.
  -- IMPORTANT: Never overwrite user's saved position after the one-time top migration!
  if type(_G.Bartender4DB) == "table" and type(_G.Bartender4DB.namespaces) == "table" then
    local mmNS = _G.Bartender4DB.namespaces.MicroMenu
    if type(mmNS) == "table" and type(mmNS.profiles) == "table" then
      for _, prof in pairs(mmNS.profiles) do
        if type(prof) == "table" then
          prof.enabled = true
          if type(prof.visibility) == "table" then
            prof.visibility.always = false
          end
          if migrateToTop or type(prof.position) ~= "table" or not prof.position.point or (prof.position.point == "BOTTOM" and prof.position.y == 42) then
            prof.position = prof.position or {}
            prof.position.point = "TOP"
            prof.position.x = -137.05
            prof.position.y = -0.91
            prof.position.scale = 0.85
          end
        end
      end
    end
    local bagNS = _G.Bartender4DB.namespaces.BagBar
    if type(bagNS) == "table" and type(bagNS.profiles) == "table" then
      for _, prof in pairs(bagNS.profiles) do
        if type(prof) == "table" then
          prof.enabled = true
          prof.onebag = true
          if type(prof.visibility) == "table" then
            prof.visibility.always = false
          end
          if migrateToTop or type(prof.position) ~= "table" or not prof.position.point or (prof.position.point == "BOTTOM" and prof.position.y == 42) then
            prof.position = prof.position or {}
            prof.position.point = "TOP"
            prof.position.x = 169.40
            prof.position.y = -4.28
            prof.position.scale = 0.90
          end
        end
      end
    end
  end

  local BT4 = _G.Bartender4
  if BT4 and BT4.GetModule then
    local mmMod = BT4:GetModule("MicroMenu", true)
    if mmMod and mmMod.db and mmMod.db.profile then
      local mmCfg = mmMod.db.profile
      mmCfg.enabled = true
      mmCfg.visibility = mmCfg.visibility or {}
      mmCfg.visibility.always = false
      mmCfg.position = mmCfg.position or {}
      if migrateToTop or not mmCfg.position.point or (mmCfg.position.point == "BOTTOM" and mmCfg.position.y == 42) then
        mmCfg.position.point = "TOP"
        mmCfg.position.x = -137.05
        mmCfg.position.y = -0.91
        mmCfg.position.scale = 0.85
      end
      if BT4.EnableModule and mmMod.IsEnabled and not mmMod:IsEnabled() then
        pcall(BT4.EnableModule, BT4, "MicroMenu")
      end
      if mmMod.ApplyConfig then
        pcall(mmMod.ApplyConfig, mmMod)
      end
      if mmMod.bar and mmMod.bar.Show then
        pcall(mmMod.bar.Show, mmMod.bar)
      end
    end

    local bagMod = BT4:GetModule("BagBar", true)
    if bagMod and bagMod.db and bagMod.db.profile then
      local bagCfg = bagMod.db.profile
      bagCfg.enabled = true
      bagCfg.onebag = true
      bagCfg.visibility = bagCfg.visibility or {}
      bagCfg.visibility.always = false
      bagCfg.position = bagCfg.position or {}
      if migrateToTop or not bagCfg.position.point or (bagCfg.position.point == "BOTTOM" and bagCfg.position.y == 42) then
        bagCfg.position.point = "TOP"
        bagCfg.position.x = 169.40
        bagCfg.position.y = -4.28
        bagCfg.position.scale = 0.90
      end
      if BT4.EnableModule and bagMod.IsEnabled and not bagMod:IsEnabled() then
        pcall(BT4.EnableModule, BT4, "BagBar")
      end
      if bagMod.ApplyConfig then
        pcall(bagMod.ApplyConfig, bagMod)
      end
      if bagMod.bar and bagMod.bar.Show then
        pcall(bagMod.bar.Show, bagMod.bar)
      end
    end
  end

  if migrateToTop then
    gopsDB.completedTasks["bt4_top_micromenu_bags_v2"] = true
    if gopsDB.hardwareProfiles and gopsDB.hardwareProfiles["PC"] and gopsDB.hardwareProfiles["PC"].bartender4 then
      local btSnap = gopsDB.hardwareProfiles["PC"].bartender4
      if btSnap.MicroMenu and btSnap.MicroMenu.position then
        btSnap.MicroMenu.position.point = "TOP"
        btSnap.MicroMenu.position.x = -137.05
        btSnap.MicroMenu.position.y = -0.91
        btSnap.MicroMenu.position.scale = 0.85
      end
      if btSnap.BagBar and btSnap.BagBar.position then
        btSnap.BagBar.position.point = "TOP"
        btSnap.BagBar.position.x = 169.40
        btSnap.BagBar.position.y = -4.28
        btSnap.BagBar.position.scale = 0.90
      end
    end
  end
end

---------------------------------------------------------------------------------------
--  2. COMBATMODE WATCHLIST & BLIZZMOVE 1.5X ULTRAWIDE QOL
---------------------------------------------------------------------------------------
local COMBATMODE_REMOVE_WATCHLIST = {
  ["SpArcMainFrame"] = true,
  ["SpArcHUDRoot"] = true,
  ["EndeavorTrackerFrame"] = true,
  ["DecoTrackerFrame"] = true,
}

local COMBATMODE_EXTRA_FRAMES = {
  "HomeBoundMainFrame",
  "DecorVendorFrame",
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
  "ProfessionsCustomerOrdersFrame",
  "CraftSimControlPanelFrame",
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

local COMBATMODE_MOUSE_BINDINGS = {
  button1      = { key = "BUTTON1",       value = "ACTIONBUTTON1" },
  button2      = { key = "BUTTON2",       value = "ACTIONBUTTON2" },
  shiftbutton1 = { key = "SHIFT-BUTTON1", value = "ACTIONBUTTON3" },
  shiftbutton2 = { key = "SHIFT-BUTTON2", value = "ACTIONBUTTON4" },
  ctrlbutton1  = { key = "CTRL-BUTTON1",  value = "ACTIONBUTTON5" },
  ctrlbutton2  = { key = "CTRL-BUTTON2",  value = "ACTIONBUTTON6" },
  altbutton1   = { key = "ALT-BUTTON1",   value = "ACTIONBUTTON7" },
  altbutton2   = { key = "ALT-BUTTON2",   value = "ACTIONBUTTON8" },
}

local function ApplyMouseBindingsToTable(bindingsTbl)
  if type(bindingsTbl) ~= "table" then return end
  for slotName, cfg in pairs(COMBATMODE_MOUSE_BINDINGS) do
    bindingsTbl[slotName] = bindingsTbl[slotName] or {}
    bindingsTbl[slotName].enabled = true
    bindingsTbl[slotName].key = cfg.key
    bindingsTbl[slotName].value = cfg.value
    bindingsTbl[slotName].macroName = ""
  end
end

local DEFAULT_MOUSE_KEY_TO_ACTION = {
  ["BUTTON1"]       = "ACTIONBUTTON1",
  ["BUTTON2"]       = "ACTIONBUTTON2",
  ["SHIFT-BUTTON1"] = "ACTIONBUTTON3",
  ["SHIFT-BUTTON2"] = "ACTIONBUTTON4",
  ["CTRL-BUTTON1"]  = "ACTIONBUTTON5",
  ["CTRL-BUTTON2"]  = "ACTIONBUTTON6",
  ["ALT-BUTTON1"]   = "ACTIONBUTTON7",
  ["ALT-BUTTON2"]   = "ACTIONBUTTON8",
}

local function ResolveBartenderKeybindCommand(key, fallbackAction, CM)
  if not key or key == "" then return nil end
  local action = fallbackAction or DEFAULT_MOUSE_KEY_TO_ACTION[key]
  if key ~= "BUTTON1" and key ~= "BUTTON2" and _G.GetBindingAction then
    local userBind = _G.GetBindingAction(key)
    if userBind and userBind ~= "" and userBind ~= "CAMERAORSELECTORMOVE" and userBind ~= "TURNORACTION" then
      action = userBind
    end
  end
  if not action or action == "" then return nil end

  if action:match("^CLICK ") then
    -- Ensure Bartender4 buttons always use :Keybind (never :LeftButton or :RightButton)
    return action:gsub("^(CLICK%s+BT4Button%d+):%S+$", "%1:Keybind")
  end

  local realFrame = CM and CM.GetEffectiveBarButtonFrameName and CM.GetEffectiveBarButtonFrameName(action)
  if realFrame and realFrame:match("^BT4Button") and _G[realFrame] then
    return "CLICK " .. realFrame .. ":Keybind"
  end
  local num = action:match("^ACTIONBUTTON(%d+)$")
  if num and _G["BT4Button" .. num] then
    return "CLICK BT4Button" .. num .. ":Keybind"
  end
  return action
end

local function ApplyDirectBartenderMouselookBinds(CM)
  if not _G.SetMouselookOverrideBinding then return end
  if _G.InCombatLockdown and _G.InCombatLockdown() then return end
  for key, defaultAction in pairs(DEFAULT_MOUSE_KEY_TO_ACTION) do
    local cmd = ResolveBartenderKeybindCommand(key, defaultAction, CM)
    if cmd then
      pcall(_G.SetMouselookOverrideBinding, key, cmd)
    end
  end
end

function GeminiOps.ApplyExternalAddonQoL()
  if type(_G.CombatModeDB) == "table" then
    _G.CombatModeDB.global = _G.CombatModeDB.global or {}
    _G.CombatModeDB.global.watchlist = _G.CombatModeDB.global.watchlist or {}
    local wl = _G.CombatModeDB.global.watchlist
    for i = #wl, 1, -1 do
      if COMBATMODE_REMOVE_WATCHLIST[wl[i]] then
        table.remove(wl, i)
      end
    end
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

    _G.CombatModeDB.global.bindings = _G.CombatModeDB.global.bindings or {}
    ApplyMouseBindingsToTable(_G.CombatModeDB.global.bindings)

    if type(_G.CombatModeDB.char) == "table" then
      for _, charTbl in pairs(_G.CombatModeDB.char) do
        if type(charTbl) == "table" then
          charTbl.reticleTargeting = false
          charTbl.bindings = charTbl.bindings or {}
          ApplyMouseBindingsToTable(charTbl.bindings)
        end
      end
    end
  end

  local CM = _G.CM or _G.CombatMode
  if CM then
    if CM.DB then
      if CM.DB.global and CM.DB.global.bindings then
        ApplyMouseBindingsToTable(CM.DB.global.bindings)
      end
      if CM.DB.char then
        CM.DB.char.reticleTargeting = false
        if CM.DB.char.bindings then
          ApplyMouseBindingsToTable(CM.DB.char.bindings)
        end
      end
    end

    -- Clear any existing CombatMode 5.1.3 keyboard/focus override owners while reticleTargeting=false
    if not (_G.InCombatLockdown and _G.InCombatLockdown()) then
      if CM.ApplyGroundCastKeyOverrides and not CM._gopsPatched then
        pcall(CM.ApplyGroundCastKeyOverrides)
      end
      if CM.ApplyToggleFocusTargetBinding and not CM._gopsPatched then
        pcall(CM.ApplyToggleFocusTargetBinding)
      end
      if CM.ApplyCycleFocusBindings and not CM._gopsPatched then
        pcall(CM.ApplyCycleFocusBindings)
      end
    end

    -- Detach CombatMode 5.1.3 from hijacking action bars; route mouselook clicks directly to Bartender4 :Keybind
    CM._gopsPatched = true
    CM.ApplyGroundCastKeyOverrides = function() end
    CM.ApplyToggleFocusTargetBinding = function() end
    CM.ApplyCycleFocusBindings = function() end
    CM.SetNewBinding = function(buttonSettings)
      if not buttonSettings or not buttonSettings.key then return end
      if _G.InCombatLockdown and _G.InCombatLockdown() then return end
      local cmd = ResolveBartenderKeybindCommand(buttonSettings.key, DEFAULT_MOUSE_KEY_TO_ACTION[buttonSettings.key] or buttonSettings.value, CM)
      if cmd and _G.SetMouselookOverrideBinding then
        pcall(_G.SetMouselookOverrideBinding, buttonSettings.key, cmd)
      end
    end
    CM.OverrideDefaultButtons = function()
      ApplyDirectBartenderMouselookBinds(CM)
    end
    CM.RefreshClickCastMacros = function()
      ApplyDirectBartenderMouselookBinds(CM)
    end

    if _G.C_CVar and _G.C_CVar.SetCVar then
      pcall(_G.C_CVar.SetCVar, "CursorStickyCentering", "0")
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

  -- Do NOT overwrite user keybindings in Bartender4 / WoW (SetBinding / SaveBindings removed).
  -- SpArc Combat Camera handles Mouselook click-casting dynamically via SetMouselookOverrideBinding.
  if not (_G.InCombatLockdown and _G.InCombatLockdown()) then
    if _G.SpArc and _G.SpArc.ApplyCombatCameraBindings then
      pcall(_G.SpArc.ApplyCombatCameraBindings, _G.SpArc)
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
  return name .. " - " .. realm, name .. "-" .. realm, name .. "-" .. realm:gsub("%s+", "")
end

local TEMPLATE_KEYBINDINGS = {
  { "DOWN", "MOVEBACKWARD" },
  { "C", "TOGGLECHARACTER0" },
  { "B", "TOGGLEBACKPACK" },
  { "BUTTON3", "ACTIONBUTTON9" },
  { "Q", "ACTIONBUTTON11" },
  { "E", "INTERACTTARGET" },
  { "NUMPAD0", "NONE" },
  { "X", "NONE" },
  { "1", "MULTIACTIONBAR2BUTTON1" },
  { "2", "MULTIACTIONBAR2BUTTON2" },
  { "3", "MULTIACTIONBAR2BUTTON3" },
  { "4", "MULTIACTIONBAR2BUTTON4" },
  { "5", "NONE" },
  { "V", "MULTIACTIONBAR1BUTTON10" },
  { "R", "MULTIACTIONBAR1BUTTON3" },
  { "SHIFT-1", "MULTIACTIONBAR2BUTTON5" },
  { "SHIFT-2", "MULTIACTIONBAR2BUTTON6" },
  { "SHIFT-3", "MULTIACTIONBAR2BUTTON7" },
  { "PAGEDOWN", "TOGGLESHEATH" },
  { ",", "NAMEPLATES" },
  { ".", "FRIENDNAMEPLATES" },
  { "]", "PAWN_COMPARE_RIGHT" },
  { "[", "PAWN_COMPARE_LEFT" },
  { "BUTTON4", "FLIPCAMERAYAW" },
  { "INSERT", "FOLLOWTARGET" },
  { "SHIFT-R", "MULTIACTIONBAR1BUTTON4" },
  { "6", "NONE" },
  { "7", "NONE" },
  { "8", "NONE" },
  { "9", "NONE" },
  { "0", "NONE" },
  { "-", "NONE" },
  { "=", "NONE" },
  { "CTRL-F1", "NONE" },
  { "CTRL-1", "NONE" },
  { "CTRL-2", "NONE" },
  { "CTRL-3", "NONE" },
  { "CTRL-4", "NONE" },
  { "CTRL-5", "NONE" },
  { "CTRL-6", "NONE" },
  { "CTRL-7", "NONE" },
  { "CTRL-8", "NONE" },
  { "CTRL-9", "NONE" },
  { "CTRL-0", "NONE" },
  { "CTRL-TAB", "TARGETNEARESTENEMY" },
  { "F1", "NONE" },
  { "F2", "NONE" },
  { "F3", "NONE" },
  { "F4", "NONE" },
  { "F5", "NONE" },
  { "F6", "NONE" },
  { "F7", "NONE" },
  { "F8", "NONE" },
  { "F9", "NONE" },
  { "F10", "NONE" },
  { "F11", "NONE" },
  { "F12", "NONE" },
  { "G", "Combat Mode - Mouse Look" },
  { "F", "MULTIACTIONBAR1BUTTON5" },
  { "SHIFT-V", "NONE" },
  { "CTRL-V", "NONE" },
  { "SHIFT-T", "MULTIACTIONBAR1BUTTON8" },
  { "SHIFT-B", "NONE" },
  { "SHIFT-SPACE", "EXTRAACTIONBUTTON1" },
  { "J", "NONE" },
  { "SHIFT-Y", "NONE" },
  { "CTRL-S", "NONE" },
  { "ALT-Z", "NONE" },
  { "CTRL-R", "MULTIACTIONBAR1BUTTON9" },
  { "CTRL-Q", "NONE" },
  { "CTRL-W", "NONE" },
  { "CTRL-E", "NONE" },
  { "CTRL-T", "NONE" },
  { "SHIFT-C", "NONE" },
  { "Z", "MULTIACTIONBAR1BUTTON11" },
  { "SHIFT-4", "MULTIACTIONBAR2BUTTON8" },
  { "SHIFT-5", "NONE" },
  { "SHIFT-6", "NONE" },
  { "SHIFT-UP", "NONE" },
  { "SHIFT-MOUSEWHEELUP", "NONE" },
  { "SHIFT-DOWN", "NONE" },
  { "SHIFT-MOUSEWHEELDOWN", "NONE" },
  { "SHIFT-Q", "ACTIONBUTTON12" },
  { "SHIFT-E", "ACTIONBUTTON10" },
  { "SHIFT-F", "MULTIACTIONBAR1BUTTON6" },
  { "SHIFT-BUTTON3", "MULTIACTIONBAR1BUTTON2" },
  { "CTRL-BUTTON3", "NONE" },
  { "ALT-BUTTON3", "NONE" },
  { "CTRL-SPACE", "NONE" },
  { "ALT-E", "INTERACTMOUSEOVER" },
  { "T", "MULTIACTIONBAR1BUTTON7" },
  { "BUTTON5", "CLICK LM_B1:LeftButton" },
  { "SHIFT-BUTTON5", "NONE" },
  { "`", "Combat Mode - Mouse Look" },
  { "F6", "NONE" },
  { "CTRL-.", "TOGGLESOUND" },
  { "ALT-Q", "NONE" },
  { "ALT-R", "NONE" },
  { "SHIFT-X", "NONE" },
  { "SHIFT-Z", "MULTIACTIONBAR1BUTTON12" },
  { "SHIFT-G", "NONE" },
  { "SHIFT-W", "NONE" },
  { "SHIFT-S", "NONE" },
  { "SHIFT-A", "NONE" },
  { "SHIFT-D", "NONE" },
  { "CAPSLOCK", "NONE" },
  { "CTRL-F", "NONE" },
  { "OEM3", "NONE" },
  { "ALT-1", "MULTIACTIONBAR2BUTTON9" },
  { "ALT-2", "MULTIACTIONBAR2BUTTON10" },
  { "ALT-3", "MULTIACTIONBAR2BUTTON11" },
  { "SHIFT-H", "NONE" },
  { "SHIFT-`", "NONE" },
  { "SHIFT-,", "ALLNAMEPLATES" },
  { "SHIFT-7", "Combat Mode Toggle" },
  { "\\", "NONE" },
  { "ALT-\\", "TOGGLEUI" },
  { "ALT-4", "NONE" },
  { "ALT-SHIFT-1", "NONE" },
  { "ALT-SHIFT-2", "NONE" },
  { "ALT-SHIFT-3", "NONE" },
  { "ALT-SHIFT-4", "MULTIACTIONBAR2BUTTON12" },
  { "CTRL-D", "NONE" },
  { "ALT-BUTTON2", "ACTIONBUTTON8" },
  { "ALT-BUTTON1", "ACTIONBUTTON7" },
  { "SHIFT-BUTTON1", "ACTIONBUTTON3" },
  { "SHIFT-BUTTON2", "ACTIONBUTTON4" },
  { "CTRL-BUTTON1", "ACTIONBUTTON5" },
  { "CTRL-BUTTON2", "ACTIONBUTTON6" },
}

function GeminiOps.SyncTemplateKeybindings()
  if _G.InCombatLockdown and _G.InCombatLockdown() then return false end
  if not _G.SetBinding then return false end

  for _, pair in ipairs(TEMPLATE_KEYBINDINGS) do
    local key, action = pair[1], pair[2]
    if action == "NONE" then
      pcall(_G.SetBinding, key, nil)
    else
      pcall(_G.SetBinding, key, action)
    end
  end
  if _G.SetModifiedClick then
    pcall(_G.SetModifiedClick, "SELFCAST", "NONE")
  end
  if _G.SaveBindings then
    local bindSet = (_G.GetCurrentBindingSet and _G.GetCurrentBindingSet()) or 2
    pcall(_G.SaveBindings, bindSet)
  end
  local BT4 = _G.Bartender4
  if BT4 and BT4.GetModule then
    local abMod = BT4:GetModule("ActionBars", true)
    if abMod and abMod.ReassignBindings then
      pcall(abMod.ReassignBindings, abMod)
    end
  end
  if _G.SpArc and _G.SpArc.ApplyCombatCameraBindings then
    pcall(_G.SpArc.ApplyCombatCameraBindings, _G.SpArc)
  end
  return true
end

function GeminiOps.CloneCharacterProfiles(srcKey, dstKey, force)
  srcKey = srcKey or GeminiOps.DEFAULT_TEMPLATE_CHAR
  local curKey, curDetKey, curNoSpaceKey = GeminiOps.GetCurrentCharKey()
  dstKey = dstKey or curKey
  if not dstKey or dstKey == srcKey then
    return false, "Target character is same as template (" .. tostring(srcKey) .. ")"
  end

  local gopsDB = GeminiOps:EnsureDB()
  if gopsDB.clonedCharacters[dstKey] == "v6" and not force then
    return false, "Already cloned (v6)"
  end

  -- 0. Keybindings & core Priest CVars
  GeminiOps.SyncTemplateKeybindings()
  if C_CVar and C_CVar.SetCVar then
    pcall(C_CVar.SetCVar, "displaySpellActivationOverlays", "0")
    pcall(C_CVar.SetCVar, "SoftTargetEnemy", "3")
    pcall(C_CVar.SetCVar, "SoftTargetEnemyRange", "60")
    pcall(C_CVar.SetCVar, "SoftTargetEnemyArc", "0")
    pcall(C_CVar.SetCVar, "SoftTargetFriendRange", "60")
    pcall(C_CVar.SetCVar, "SoftTargetFriendArc", "0")
    pcall(C_CVar.SetCVar, "enableMultiActionBars", "7")
    pcall(C_CVar.SetCVar, "mapFade", "0")
    pcall(C_CVar.SetCVar, "raidFramesDisplayClassColor", "1")
    pcall(C_CVar.SetCVar, "raidFramesDisplayPowerBars", "1")
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
  elseif type(_G.ElvDB) == "table" and _G.ElvDB.profiles and _G.ElvDB.profiles[srcKey] then
    _G.ElvDB.profileKeys = _G.ElvDB.profileKeys or {}
    _G.ElvDB.profileKeys[dstKey] = dstKey
    _G.ElvDB.profiles[dstKey] = DeepCopyTable(_G.ElvDB.profiles[srcKey])
  end

  -- 2. ElvPrivateDB (preserve AceDB metatables on E.private and E.private.WT!)
  if E and E.charSettings and E.charSettings.SetProfile and E.charSettings.CopyProfile then
    pcall(function()
      if _G.ElvPrivateDB and _G.ElvPrivateDB.profiles and _G.ElvPrivateDB.profiles[srcKey] then
        E.charSettings:SetProfile(dstKey)
        E.charSettings:CopyProfile(srcKey, false)
      end
    end)
  elseif type(_G.ElvPrivateDB) == "table" and _G.ElvPrivateDB.profiles and _G.ElvPrivateDB.profiles[srcKey] then
    _G.ElvPrivateDB.profileKeys = _G.ElvPrivateDB.profileKeys or {}
    _G.ElvPrivateDB.profileKeys[dstKey] = dstKey
    _G.ElvPrivateDB.profiles[dstKey] = DeepCopyTable(_G.ElvPrivateDB.profiles[srcKey])
  end
  if E and E.private then
    E.private.actionbar = E.private.actionbar or {}
    E.private.actionbar.enable = false
    E.private.nameplates = E.private.nameplates or {}
    E.private.nameplates.enable = false
    E.private.bags = E.private.bags or {}
    E.private.bags.enable = false
    E.private.install_complete = E.version or 16
  end
  if _G.ElvUIInstallFrame and _G.ElvUIInstallFrame.Hide then
    pcall(_G.ElvUIInstallFrame.Hide, _G.ElvUIInstallFrame)
  end
  if _G.PluginInstallerFrame and _G.PluginInstallerFrame.Hide then
    pcall(_G.PluginInstallerFrame.Hide, _G.PluginInstallerFrame)
  end

  -- 3. Bartender4 (AceDB + all child bar namespaces via native AceDB CopyProfile)
  local BT4 = _G.Bartender4
  if BT4 and BT4.db and BT4.db.SetProfile and BT4.db.CopyProfile then
    pcall(function()
      if _G.Bartender4DB and _G.Bartender4DB.profiles and _G.Bartender4DB.profiles[srcKey] then
        BT4.db:SetProfile(dstKey)
        BT4.db:CopyProfile(srcKey, false)
        if BT4.UpdateModuleConfigs then
          BT4:UpdateModuleConfigs()
        end
      end
    end)
  elseif type(_G.Bartender4DB) == "table" then
    _G.Bartender4DB.profileKeys = _G.Bartender4DB.profileKeys or {}
    _G.Bartender4DB.profileKeys[dstKey] = dstKey
    if type(_G.Bartender4DB.profiles) == "table" and _G.Bartender4DB.profiles[srcKey] then
      _G.Bartender4DB.profiles[dstKey] = DeepCopyTable(_G.Bartender4DB.profiles[srcKey])
    end
    if type(_G.Bartender4DB.namespaces) == "table" then
      for _, nsTbl in pairs(_G.Bartender4DB.namespaces) do
        if type(nsTbl) == "table" and type(nsTbl.profiles) == "table" and nsTbl.profiles[srcKey] then
          nsTbl.profiles[dstKey] = DeepCopyTable(nsTbl.profiles[srcKey])
        end
      end
    end
  end
  if BT4 and BT4.UpdateModuleConfigs then
    pcall(BT4.UpdateModuleConfigs, BT4)
  end

  -- 4. Plater (AceDB)
  local Plater = _G.Plater
  if Plater and Plater.db and Plater.db.SetProfile and Plater.db.CopyProfile then
    pcall(function()
      local srcPlaterProf = (_G.PlaterDB and _G.PlaterDB.profileKeys and _G.PlaterDB.profileKeys[srcKey]) or srcKey
      if _G.PlaterDB and _G.PlaterDB.profiles and _G.PlaterDB.profiles[srcPlaterProf] then
        Plater.db:SetProfile(dstKey)
        Plater.db:CopyProfile(srcPlaterProf, false)
        if Plater.RefreshDB then Plater.RefreshDB() end
        if Plater.UpdateAllPlates then Plater.UpdateAllPlates() end
      end
    end)
  elseif type(_G.PlaterDB) == "table" and type(_G.PlaterDB.profiles) == "table" then
    local srcPlaterProf = (_G.PlaterDB.profileKeys and _G.PlaterDB.profileKeys[srcKey]) or srcKey
    if _G.PlaterDB.profiles[srcPlaterProf] then
      _G.PlaterDB.profileKeys = _G.PlaterDB.profileKeys or {}
      _G.PlaterDB.profileKeys[dstKey] = dstKey
      _G.PlaterDB.profiles[dstKey] = DeepCopyTable(_G.PlaterDB.profiles[srcPlaterProf])
    end
  end

  -- 5. SpArc (Per-Character Visual/Camera Profile Cloner; only copy DoT aura rules if same character name across realms)
  local srcBase = tostring(srcKey or ""):match("^(.-)%s*%-") or tostring(srcKey or "")
  local dstBase = tostring(dstKey or ""):match("^(.-)%s*%-") or tostring(dstKey or "")
  local sameChar = (srcBase ~= "" and srcBase == dstBase)
    or (srcKey == "Гитпулл - Пиратская Бухта" and dstKey == "Гитхард - Гордунни")
  if _G.SpArc and _G.SpArc.CopyProfileFrom then
    pcall(_G.SpArc.CopyProfileFrom, _G.SpArc, srcKey, sameChar)
  end
  if type(_G.SpArcDB) == "table" and type(_G.SpArcDB.profiles) == "table" then
    local spSrc = _G.SpArcDB.profiles[srcKey]
    if sameChar and type(spSrc) == "table" then
      _G.SpArcDB.profiles[dstKey] = DeepCopyTable(spSrc)
      if _G.SpArcDB.profileKeys then
        _G.SpArcDB.profileKeys[dstKey] = dstKey
      end
    end
    local spDst = _G.SpArcDB.profiles[dstKey]
    if type(spDst) == "table" then
      if type(spSrc) == "table" and spSrc.mode then
        spDst.mode = spSrc.mode
      end
      if sameChar and type(spSrc) == "table" then
        if spSrc.activePresetID then
          spDst.activePresetID = spSrc.activePresetID
          _G.SpArcDB.activePresetID = spSrc.activePresetID
        end
        if type(spSrc.autoPresets) == "table" then
          spDst.autoPresets = DeepCopyTable(spSrc.autoPresets)
          _G.SpArcDB.autoPresets = DeepCopyTable(spSrc.autoPresets)
        end
        if _G.SpArc and _G.SpArc.SelectActiveParsedProfile then
          pcall(_G.SpArc.SelectActiveParsedProfile, _G.SpArc)
        end
      elseif srcKey == "Калиратри - Свежеватель Душ" then
        spDst.activePresetID = "MAGE_04_FROST_PVE"
        spDst.autoPresets = {
          PVE  = "MAGE_04_FROST_PVE",
          BOSS = "MAGE_04_FROST_PVE",
          PVP  = "MAGE_05_FROST_PVP",
        }
        _G.SpArcDB.activePresetID = "MAGE_04_FROST_PVE"
        _G.SpArcDB.autoPresets = DeepCopyTable(spDst.autoPresets)
        if _G.SpArc and _G.SpArc.SelectActiveParsedProfile then
          pcall(_G.SpArc.SelectActiveParsedProfile, _G.SpArc)
        end
      end
    end
  end

  -- 6. CombatMode (AceDB)
  local CM = _G.CombatMode
  if CM and CM.db and CM.db.SetProfile and CM.db.CopyProfile then
    pcall(function()
      if _G.CombatModeDB and _G.CombatModeDB.profiles and _G.CombatModeDB.profiles[srcKey] then
        CM.db:SetProfile(dstKey)
        CM.db:CopyProfile(srcKey, false)
      end
    end)
  end

  -- 7. Details! Damage Meter (Profile + Window Position)
  local srcDetKey = (srcKey and srcKey:gsub("%s*%-%s*", "-")) or GeminiOps.DEFAULT_TEMPLATE_DETAILS
  local dstDetKey = curDetKey or dstKey:gsub("%s*%-%s*", "-")
  if type(_G._detalhes_global) == "table" and type(_G._detalhes_global.__profiles) == "table" then
    local srcProf = _G._detalhes_global.__profiles[srcDetKey]
      or _G._detalhes_global.__profiles[srcKey]
      or _G._detalhes_global.__profiles[GeminiOps.DEFAULT_TEMPLATE_DETAILS]
      or _G._detalhes_global.__profiles["Ньарлатхотеп-СвежевательДуш"]
    if type(srcProf) == "table" then
      _G._detalhes_global.__profiles[dstDetKey] = DeepCopyTable(srcProf)
      if type(_G._detalhes_database) == "table" then
        _G._detalhes_database.active_profile = dstDetKey
      end
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

  -- 8. Baganator tracked currencies
  if type(_G.BAGANATOR_CONFIG) == "table"
    and type(_G.BAGANATOR_CONFIG.CharacterSpecific) == "table"
    and type(_G.BAGANATOR_CONFIG.CharacterSpecific.currencies_tracked) == "table" then
    local ct = _G.BAGANATOR_CONFIG.CharacterSpecific.currencies_tracked
    local srcBagKey = (srcKey and srcKey:gsub("%s+", "")) or "Ньарлатхотеп-СвежевательДуш"
    local srcBagData = ct[srcBagKey] or ct["Ньарлатхотеп-СвежевательДуш"]
    if curNoSpaceKey and type(srcBagData) == "table" then
      ct[curNoSpaceKey] = DeepCopyTable(srcBagData)
    end
  end

  -- 9. Other AceDB SavedVariables tables
  local otherAddons = {
    "MasqueDB",
    "BetterBagsDB",
    "BigWigs3DB",
    "Krowi_ExtendedVendorUI_DB",
    "TomTomDB",
    "Details_StreamerDB",
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

  -- 10. MacroToolkit per-character extended macros (121..150) & live macro book sync when cloning same character across realms
  if sameChar and type(_G.MacroToolkitDB) == "table" then
    if type(_G.MacroToolkitDB.char) == "table" and type(_G.MacroToolkitDB.char[srcKey]) == "table" then
      _G.MacroToolkitDB.char[dstKey] = DeepCopyTable(_G.MacroToolkitDB.char[srcKey])
      if type(_G.MacroToolkitDB.profileKeys) == "table" then
        _G.MacroToolkitDB.profileKeys[dstKey] = _G.MacroToolkitDB.profileKeys[srcKey] or "profile"
      end
      local srcMacros = _G.MacroToolkitDB.char[srcKey].macros
      if type(srcMacros) == "table" and not (_G.InCombatLockdown and _G.InCombatLockdown()) then
        for slot = 121, 150 do
          local mData = srcMacros[slot]
          if type(mData) == "table" and type(mData.name) == "string" and type(mData.body) == "string" then
            local cleanBody = mData.body:gsub("\r\n", "\n"):gsub("%s+$", "")
            local existingIdx = 0
            if _G.GetMacroInfo then
              for idx = 121, 150 do
                local n = _G.GetMacroInfo(idx)
                if n == mData.name then
                  existingIdx = idx
                  break
                end
              end
            end
            if existingIdx > 0 and _G.EditMacro then
              pcall(_G.EditMacro, existingIdx, mData.name, "INV_MISC_QUESTIONMARK", cleanBody)
            elseif _G.CreateMacro then
              pcall(_G.CreateMacro, mData.name, "INV_MISC_QUESTIONMARK", cleanBody, true)
            end
          end
        end
      end
    end
  end

  if sameChar then
    gopsDB.completedTasks["hunter_macros_v5_mo_" .. dstKey] = true
    gopsDB.completedTasks["hunter_macros_v5_pvp_" .. dstKey] = true
  end

  gopsDB.clonedCharacters[dstKey] = "v6"
  return true, "Скопированы все профили (ElvUI, Bartender4 + бинды, Plater, Details!, SpArc, MacroToolkit, Masque, BigWigs) с [" .. tostring(srcKey) .. "] на [" .. tostring(dstKey) .. "]"
end

---------------------------------------------------------------------------------------
--  3B. STARHAMMER ARMS WARRIOR MACRO SYNC (SLAYER DELVES/M+ & FALLBACKS)
---------------------------------------------------------------------------------------
local STARHAMMER_MACROS = {
  ["1"] = "#showtooltip\n/stopmacro [flying]\n/cast [known:845] Рассекающий удар; Вихрь",
  ["2"] = "#showtooltip\n/stopmacro [flying]\n/cast [known:190456] !Стойкость к боли\n/cast Верная победа",
  ["3"] = "#showtooltip Аватара\n/stopmacro [flying]\n/cast [nostance:2] Боевая стойка\n/cast Аватара",
  ["B3"] = "#showtooltip\n/stopmacro [flying]\n/cast [known:5246,@target,harm] Устрашающий крик; [known:384100] Крик берсерка; Ярость берсерка",
  ["SB3"] = "#showtooltip\n/stopmacro [flying]\n/cast [known:12323] Пронзительный вой; [known:384100] Крик берсерка; Ярость берсерка",
  ["CM1"] = "#showtooltip Бой насмерть\n/stopmacro [flying]\n/cast [nostance:1] Оборонительная стойка\n/cast Бой насмерть",
  ["CM2"] = "#showtooltip [known:383762] Горестная невосприимчивость; Ободряющий клич\n/stopmacro [flying]\n/cast [nostance:1] Оборонительная стойка\n/cast [known:383762] Горестная невосприимчивость; Ободряющий клич",
  ["M1"] = "#showtooltip [known:262161] Миротворец; [known:436358] Сокрушение; Удар колосса\n/stopmacro [flying]\n/cast [nostance:2] Боевая стойка\n/cast [known:262161] Миротворец; [known:436358] Сокрушение; Удар колосса",
  ["M2"] = "#showtooltip\n/stopmacro [flying][nocombat]\n/cast [known:228920, @player] Опустошитель; Вихрь клинков",
  ["R"] = "#showtooltip\n/stopmacro [flying]\n/cast [known:384318] Громогласный рык; [known:376079,@player] Копье чемпиона; [known:772] Кровопускание; Размашистые удары",
  ["S1"] = "#showtooltip Вмешательство\n#FS OD, X, ODTG\n/stopmacro [flying]\n/cast [known:3411, nostance:1] Оборонительная стойка\n/cast [known:3411, @none][@targetfriend] Вмешательство\n/cast [@none, harm] Рывок",
  ["S2"] = "#showtooltip Вмешательство\n#FS healer\n/stopmacro [flying]\n/cast [known:3411, nostance:1] Оборонительная стойка\n/cast [known:3411, @none] Вмешательство",
  ["SM2"] = "#showtooltip Размашистые удары\n/stopmacro [flying]\n/cast [nostance:2] Боевая стойка\n/cast Размашистые удары\n/cast [combat] Аватара",
  ["T"] = "#showtooltip\n/stopmacro [flying]\n#FS EH, X\n/cast [known:107570,@none][known:107570,@target] Удар громовержца; [@target] Героический бросок",
  ["V"] = "#showtooltip\n/stopmacro [flying]\n/cast [stance:1] Боевая стойка; Оборонительная стойка",
}

local STARHAMMER_SQ_THUNDER = "#showtooltip\n/stopmacro [flying]\n/cast [known:6343] Удар грома; Мощный удар"
local STARHAMMER_SQ_SHARPEN = "#showtooltip\n/stopmacro [flying]\n/cast [known:198817] Заточка клинка; [known:20572] Кровавое неистовство; Размашистые удары"

function GeminiOps.IsPlayerWarrior()
  if _G.UnitClass then
    local ok, _, cls = pcall(_G.UnitClass, "player")
    if ok and cls == "WARRIOR" then
      return true
    end
  end
  return false
end

function GeminiOps.SyncStarhammerMacros(force)
  local curKey = GeminiOps.GetCurrentCharKey()
  if not GeminiOps.IsPlayerWarrior() and curKey ~= "Стархаммер - Свежеватель Душ" then
    return false, "Macro sync is only for Warrior (Стархаммер)"
  end
  if _G.InCombatLockdown and _G.InCombatLockdown() then
    return false, "Cannot sync macros in combat"
  end
  local gopsDB = GeminiOps:EnsureDB()
  local taskKey = "starhammer_macros_v5_" .. tostring(curKey or "default")
  if gopsDB.completedTasks[taskKey] and not force then
    return false, "Already synced (v5)"
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
    gopsDB.completedTasks[taskKey] = true
  end
  return updated > 0, "Обновлено макросов Вара со стойками [nostance] (v5): " .. tostring(updated)
end

---------------------------------------------------------------------------------------
--  3C. PRIEST (НЬАРЛАТХОТЕП) CHARACTER MACRO RESTORATION (30 SLOTS: 121..150)
--  Blizzard's Realm Transfer truncates character macros at 18 (slots 121..138),
--  dropping slots 139..150 (p2vp, p4, pvptal, S1, S4, SM1, SM2, sp1pvp, sp3, sp4, sp8, V).
---------------------------------------------------------------------------------------
local PRIEST_CHARACTER_MACROS = {
  { name = "1_to_2", icon = 134400, body = "#showtooltip [bar:1] Придание сил; Взрыв разума\n#FS OD\n/cast [bar:1, @none, exists][bar:1, @player] !Придание сил; [@target, harm] Взрыв разума\n/cast [bar:1] Облик Бездны\n/changeactionbar [bar:1]2" },
  { name = "AM1",    icon = 136230, body = "#showtooltip\n/cast [known:15286] Объятия вампира" },
  { name = "AM2",    icon = 134400, body = "#showtooltip\n/cast Слово силы: Стойкость" },
  { name = "CM1",    icon = 237550, body = "#showtooltip\n/stopcasting\n/cast !Молитва отчаяния\n/cast [@player] Слово силы: Щит" },
  { name = "CM2",    icon = 134400, body = "#showtooltip Слияние с тьмой\n/stopcasting\n/cast !Слияние с тьмой" },
  { name = "DD_Sield", icon = 134400, body = "#showtooltip Слово силы: Щит\n#FS OD\n/cast [@none] Слово силы: Щит" },
  { name = "Dps",    icon = 537079, body = "#showtooltip Вхождение в Бездну\n#FS OD\n/stopmacro [flying]\n/cast [@none] Вхождение в Бездну" },
  { name = "F",      icon = 134400, body = "#showtooltip Безмолвие\n#FS target, EH\n/stopmacro [flying]\n/cast [@target, mod:ctrl] !Безмолвие; [@none][@target] !Безмолвие\n/cast [@target] Рассеивание заклинаний" },
  { name = "H_Shield", icon = 134400, body = "#showtooltip Слово силы: Щит\n#FS H\n/cast [@none, exists] Слово силы: Щит" },
  { name = "Healer", icon = 537079, body = "#showtooltip Вхождение в Бездну\n#FS H\n/stopmacro [flying]\n/cast [@none] Вхождение в Бездну" },
  { name = "M1",     icon = 134400, body = "#showtooltip\n/stopmacro [channeling:391403][channeling:263165][flying]\n/changeactionbar [known:1242173][known:Залп Бездны]2;1\n/cast [noform] Облик Тьмы; [bar:2,known:1242173][bar:2,known:Залп Бездны] Залп Бездны; Взрыв разума" },
  { name = "M2",     icon = 134400, body = "#showtooltip [stance:0] Облик Тьмы; Мощный удар щупальцем\n/stopmacro [channeling:391403][channeling:263165][flying]\n/cast [stance:0] Облик Тьмы; [stance:1, @target, harm] Мощный удар щупальцем" },
  { name = "M3",     icon = 134400, match = "Боль", body = "#showtooltip Слово Тьмы: Боль\n/focus [mod:alt,@mouseover,exists][mod:alt]\n/stopmacro [channeling][flying][mod:alt]\n/cast [@mouseover,help];[@target,harm,nodead] Слово Тьмы: Боль\n/tar [@mouseover,exists][@softenemy,exists][@softfriend,exists]" },
  { name = "M3",     icon = 237568, match = "ужас", body = "#showtooltip Глубинный ужас\n/stopmacro [flying]\n/cast [known:64044, @target] Глубинный ужас" },
  { name = "p1",     icon = 642580, body = "#showtooltip\n/stopmacro [flying]\n/cast [mod:ctrl] Позолоченный брутозавр торговца; [mod:alt] Вожак стаи из Седых холмов\n/castrandom [mod:shift] Жуткий скакун Всадника без головы\n/cast [@player] Божественное перышко" },
  { name = "p12",    icon = 134400, body = "#showtooltip Уход в тень\n/stopmacro [flying]\n/cast !Уход в тень\n/cast [@player] Слово силы: Щит" },
  { name = "p16",    icon = 134400, body = "#showtooltip Воля к жизни\n/stopmacro [flying]\n/cast Воля к жизни" },
  { name = "p2",     icon = 136184, body = "#showtooltip Ментальный крик\n/stopcasting\n/cast Ментальный крик" },
  -- Slots 19..30 (139..150) truncated during Blizzard realm transfer:
  { name = "p2vp",   icon = 237568, body = "#showtooltip Глубинный ужас\n#FS EH\n/stopmacro [flying]\n/cast [known:64044, @none] Глубинный ужас" },
  { name = "p4",     icon = 134400, body = "#showtooltip Слово силы: Щит\n/stopmacro [channeling:391403][channeling:263165][flying]\n/cast [@player] !Слово силы: Щит\n/cast Уход в тень" },
  { name = "pvptal", icon = 134400, body = "#showtooltip\n#FS EH, EH, X, X\n/cast [known:211522, mod:ctrl, @none] Ментальный демон; [known:375901, mod:ctrl, @none] Игры разума; [known:211522, @target] Ментальный демон; [known:375901, @target] Игры разума; [@target] Слово Тьмы: Боль\n/targetenemy" },
  { name = "S1",     icon = 134400, slots = { 53 }, body = "#showtooltip\n/stopmacro [flying]\n/cast [known:122121] !Божественная звезда; [known:120644] !Сияние; [@target] Рассеивание заклинаний" },
  { name = "S4",     icon = 134400, slots = { 56 }, body = "#showtooltip\n/cast Левитация" },
  { name = "SM1",    icon = 136149, slots = { 3, 15 }, body = "#showtooltip Слово Тьмы: Смерть\n/stopcasting\n/cast [@target, harm] Слово Тьмы: Смерть" },
  { name = "SM2",    icon = 1386551, slots = { 4, 16 }, body = "#showtooltip Поток бездны\n/stopmacro [channeling:391403][channeling:263165][flying]\n/changeactionbar [actionbar:2]1\n/cast [noform] Облик Тьмы; [@target, harm] Поток бездны" },
  { name = "sp1pvp", icon = 134400, body = "#showtooltip Прикосновение вампира\n/stopmacro [channeling][flying]\n/cast [@target, harm] !Прикосновение вампира\n/targetenemyplayer" },
  { name = "sp3",    icon = "INV_MISC_QUESTIONMARK", slots = { 51 }, body = "#showtooltip [known:Мощный удар щупальцем] Мощный удар щупальцем; Прикосновение вампира\n/stopmacro [channeling:391403][channeling:263165][flying]\n/cast [noform] Облик Тьмы; [known:Мощный удар щупальцем, @target, harm] Мощный удар щупальцем; [@target, harm] Прикосновение вампира" },
  { name = "sp4",    icon = "INV_MISC_QUESTIONMARK", slots = { 52 }, body = "#showtooltip Слово Тьмы: Безумие\n/stopmacro [channeling:391403][channeling:263165][flying]\n/cancelaura Слияние с Тьмой\n/cast [noform] Облик Тьмы; [@target, harm, exists] !Слово Тьмы: Безумие\n/cast Рассеивание заклинаний" },
  { name = "sp8",    icon = 134400, body = "#showtooltip Пытка разума\n/stopmacro [channeling:391403][channeling:263165][flying]\n/cast [noform] Облик Тьмы; [@target, harm] !Пытка разума" },
  { name = "V",      icon = 134400, slots = { 70 }, body = "#showtooltip \n/cast [mod:ctrl, @player, known:32375][@cursor, known:32375] !Массовое рассеивание; [known:108920] !Щупальца Бездны\n/cast [@target] Рассеивание заклинаний" },
}

function GeminiOps.IsPlayerPriest()
  if _G.UnitClass then
    local ok, _, cls = pcall(_G.UnitClass, "player")
    if ok and cls == "PRIEST" then
      return true
    end
  end
  return false
end

function GeminiOps.SyncPriestMacros(force)
  local curKey = GeminiOps.GetCurrentCharKey()
  if not GeminiOps.IsPlayerPriest()
    and curKey ~= "Ньарлатхотеп - Пиратская Бухта"
    and curKey ~= "Ньярлатхотеп - Пиратская Бухта"
    and curKey ~= "Ньарлатхотеп - Свежеватель Душ" then
    return false, "Macro sync is only for Priest (Ньарлатхотеп)"
  end
  if _G.InCombatLockdown and _G.InCombatLockdown() then
    return false, "Cannot sync macros in combat"
  end
  if not _G.GetMacroInfo or not _G.CreateMacro or not _G.EditMacro then
    return false, "Macro API unavailable"
  end

  local created = 0
  local updated = 0
  local placed  = 0

  for _, entry in ipairs(PRIEST_CHARACTER_MACROS) do
    local foundIdx = nil
    for idx = 121, 150 do
      local name, _, body = _G.GetMacroInfo(idx)
      if name == entry.name then
        if not entry.match or (type(body) == "string" and body:find(entry.match, 1, true)) then
          foundIdx = idx
          break
        end
      end
    end

    if not foundIdx then
      local okC, newIdx = pcall(_G.CreateMacro, entry.name, entry.icon or 134400, entry.body, true)
      if okC and newIdx then
        created = created + 1
        foundIdx = newIdx
      end
    elseif force then
      pcall(_G.EditMacro, foundIdx, entry.name, entry.icon or 134400, entry.body)
      updated = updated + 1
    end
  end

  -- Re-scan character macros after alphabetical sort and restore any emptied action bar slots
  if _G.HasAction and _G.PickupMacro and _G.PlaceAction and _G.ClearCursor then
    for _, entry in ipairs(PRIEST_CHARACTER_MACROS) do
      if entry.slots then
        local macroIdx = nil
        for idx = 121, 150 do
          local name, _, body = _G.GetMacroInfo(idx)
          if name == entry.name then
            if not entry.match or (type(body) == "string" and body:find(entry.match, 1, true)) then
              macroIdx = idx
              break
            end
          end
        end
        if macroIdx then
          for _, slot in ipairs(entry.slots) do
            if not _G.HasAction(slot) then
              pcall(_G.PickupMacro, macroIdx)
              pcall(_G.PlaceAction, slot)
              pcall(_G.ClearCursor)
              placed = placed + 1
            end
          end
        end
      end
    end
  end

  if created > 0 or updated > 0 or placed > 0 then
    return true, string.format(
      "Восстановлены макросы Приста: создано %d (S1, S4, SM1, SM2, V, p4, sp3, sp4, sp8...), обновлено %d, возвращено на пустые слоты панелей: %d",
      created, updated, placed
    )
  end
  return false, "Все 30 персональных макросов Приста уже на месте"
end

---------------------------------------------------------------------------------------
--  3D. ENHANCEMENT SHAMAN (НИОЧ) SMART MELEE / RANGED MACRO SYNC & ANTI-PET PVP MODE
--  • Melee abilities (Удар бури, Вскипание лавы, Ледяной клинок):
--      Default (MO): [@mouseover,harm,nodead][@target,harm,nodead] + /startattack
--      Anti-Pet PvP: /targetenemyplayer [noharm][dead] + [@target,harm,nodead][@mouseover,harm,nodead]
--  • Ranged offensive abilities (Гальваническое пламя, Молния, Свирепый выпад, Сглаз,
--    Пронизывающий ветер, Великое очищение):
--      Always [@target,harm,nodead][@mouseover,harm,nodead] (Target priority -> Mouseover fallback)
--  • Self-buffs / Weapon Imbues / Burst (Перерождение, Оружие неистовства ветра, etc.):
--      Clean /cast without [@target] restriction so they never stall without a target.
---------------------------------------------------------------------------------------
local SHAMAN_MELEE_SPELLS = {
  ["Удар бури"]      = true,
  ["Вскипание лавы"] = true,
  ["Ледяной клинок"] = true,
}

local SHAMAN_RANGED_HARM_SPELLS = {
  ["Гальваническое пламя"] = false,
  ["Огненный шок"]         = false,
  ["Свирепый выпад"]       = true, -- gap-closer: target priority, mouseover fallback + /startattack
  ["Молния"]               = false,
  ["Цепная молния"]        = false,
  ["Ледяной шок"]          = false,
  ["Первозданная волна"]   = false,
  ["Великое очищение"]     = false,
  ["Сглаз"]                = false,
  ["Пронизывающий ветер"]  = false,
}

local SHAMAN_NAMED_MACROS = {
  ["10"]  = "#showtooltip Исцеляющий всплеск\n/stopmacro [flying][channeling]\n/cast [@target,help,nodead][@player] Исцеляющий всплеск",
  ["2"]   = "#showtooltip\n/stopmacro [flying]\n/cleartarget [dead][noharm]\n/cast [known:187874] Сокрушающая молния\n/startattack",
  ["es1"] = "#showtooltip Гальваническое пламя\n/stopmacro [flying]\n/cast [@target,harm,nodead][@mouseover,harm,nodead] Гальваническое пламя",
  ["es2"] = "#showtooltip Оружие неистовства ветра\n/stopmacro [flying]\n/cast Оружие неистовства ветра",
  ["es3"] = "#showtooltip Оружие языка пламени\n/stopmacro [flying]\n/cast Оружие языка пламени",
  ["es4"] = "#showtooltip Перерождение\n/stopmacro [flying]\n/cast Перерождение",
  ["es5"] = "#showtooltip Свирепый выпад\n/stopmacro [flying]\n/cast [@target,harm,nodead][@mouseover,harm,nodead] Свирепый выпад\n/startattack",
  ["F"]   = "#showtooltip Пронизывающий ветер\n/stopmacro [flying]\n/cast [@target,harm,nodead][@mouseover,harm,nodead] Пронизывающий ветер",
  ["s1"]  = "#showtooltip Астральное возвращение\n/stopmacro [flying]\n/cast Астральное возвращение",
  ["s2"]  = "#showtooltip Великое очищение\n/stopmacro [flying]\n/cast [@target,harm,nodead][@mouseover,harm,nodead] Великое очищение",
  ["s3"]  = "#showtooltip Героизм\n/stopmacro [flying]\n/cast Героизм",
  ["s4"]  = "#showtooltip Дальнее зрение\n/stopmacro [flying]\n/cast Дальнее зрение",
  ["s5"]  = "#showtooltip Дух предков\n/stopmacro [flying]\n/cast [@mouseover,help,dead][@target,help,dead] Дух предков",
  ["s6"]  = "#showtooltip Молния\n/stopmacro [flying]\n/cast [@target,harm,nodead][@mouseover,harm,nodead] Молния",
  ["s7"]  = "#showtooltip Очищение духа\n/stopmacro [flying]\n/cast [@mouseover,help,nodead][@target,help,nodead][@player] Очищение духа",
  ["s9"]  = "#showtooltip\n/stopmacro [flying]\n/cast [indoors][combat] Призрачный волк; [mod:alt] Вожак стаи из Седых холмов; [mod:ctrl] Позолоченный брутозавр торговца; [noflyable] Призрачный волк; Лунный чарофитильный транспорт",
  ["s10"] = "#showtooltip Проецирование тотемов\n/stopmacro [flying]\n/cast [@cursor] Проецирование тотемов",
  ["s11"] = "#showtooltip Сглаз\n/stopmacro [flying]\n/cast [@target,harm,nodead][@mouseover,harm,nodead] Сглаз",
  ["s12"] = "#showtooltip Хождение по воде\n/stopmacro [flying]\n/cast [@mouseover,help,nodead][@target,help,nodead][@player] Хождение по воде",
  ["s13"] = "#showtooltip Цепное исцеление\n/stopmacro [flying]\n/cast [@mouseover,help,nodead][@target,help,nodead][@player] Цепное исцеление",
  ["s14"] = "#showtooltip Щит земли\n/stopmacro [flying]\n/cast [@player] Щит земли",
}

local function BuildShamanMeleeMacro(spellName, antiPetMode)
  if antiPetMode then
    return string.format(
      "#showtooltip %s\n/stopmacro [flying]\n/cleartarget [dead][noharm]\n/targetenemyplayer [noharm][dead]\n/cast [@target,harm,nodead][@mouseover,harm,nodead] %s\n/startattack",
      spellName, spellName
    )
  end
  return string.format(
    "#showtooltip %s\n/stopmacro [flying]\n/cleartarget [dead][noharm]\n/cast [@mouseover,harm,nodead][@target,harm,nodead] %s\n/startattack",
    spellName, spellName
  )
end

local function BuildShamanRangedHarmMacro(spellName, withStartAttack)
  if withStartAttack then
    return string.format(
      "#showtooltip %s\n/stopmacro [flying]\n/cast [@target,harm,nodead][@mouseover,harm,nodead] %s\n/startattack",
      spellName, spellName
    )
  end
  return string.format(
    "#showtooltip %s\n/stopmacro [flying]\n/cast [@target,harm,nodead][@mouseover,harm,nodead] %s",
    spellName, spellName
  )
end

function GeminiOps.IsPlayerShaman()
  if _G.UnitClass then
    local ok, _, cls = pcall(_G.UnitClass, "player")
    if ok and cls == "SHAMAN" then
      return true
    end
  end
  return false
end

function GeminiOps.IsPlayerMonk()
  if _G.UnitClass then
    local ok, _, cls = pcall(_G.UnitClass, "player")
    if ok and cls == "MONK" then
      return true
    end
  end
  return false
end

function GeminiOps.IsPlayerHunter()
  if _G.UnitClass then
    local ok, _, cls = pcall(_G.UnitClass, "player")
    if ok and cls == "HUNTER" then
      return true
    end
  end
  return false
end

---------------------------------------------------------------------------------------
--  3E. WINDWALKER MONK (ГИТСУТРА) SMART MELEE / RANGED / PBAOE MACRO SYNC
--  • Melee abilities (Лапа тигра, Нокаутирующий удар, Удар восходящего солнца,
--    Неистовые кулаки, Рука-копье, Смертельное касание, Закон кармы, Вывести из строя):
--      Default (MO): [@mouseover,harm,nodead][@target,harm,nodead] + /startattack
--      Anti-Pet PvP: /targetenemyplayer [noharm][dead] + [@target,harm,nodead][@mouseover,harm,nodead]
--  • Combat PBAoE / Cones / Burst Summons (Танцующий журавль, Удар крутящегося дракона,
--    Удар владыки ветра, Небесный проводник, Призыв Сюэня, Буря, земля и огонь,
--    Круговой удар ногой, Режущие ветра):
--      Never require [@target] (so they never fail when a mob dies in a pack) + /startattack
--  • Ranged offensive abilities (Сверкающая нефритовая молния, Паралич, Вызов):
--      [@target,harm,nodead][@mouseover,harm,nodead] (Target priority -> Mouseover fallback)
--  • Friendly heals / dispels (Оживление, Детоксикация, Тигриное рвение):
--      [@target,help,nodead][@player] (or mouseover -> target -> player)
---------------------------------------------------------------------------------------
local MONK_MELEE_SPELLS = {
  ["Лапа тигра"]              = true,
  ["Нокаутирующий удар"]      = true,
  ["Удар восходящего солнца"] = true,
  ["Неистовые кулаки"]        = true,
  ["Рука-копье"]              = true,
  ["Смертельное касание"]     = true,
  ["Закон кармы"]             = true,
  ["Вывести из строя"]        = true,
  ["Однокнопочный помощник"]  = true,
}

local MONK_COMBAT_PBAOE_SPELLS = {
  ["Танцующий журавль"]              = true,
  ["Удар крутящегося дракона"]       = true,
  ["Удар владыки ветра"]             = true,
  ["Удар Владыки Ветра"]             = true,
  ["Небесный проводник"]             = true,
  ["Призыв Сюэня, Белого Тигра"]     = true,
  ["Буря, земля и огонь"]            = true,
  ["Зенит"]                          = true,
  ["Круговой удар ногой"]            = true,
  ["Режущие ветра"]                  = true,
  ["Удар летящего змея"]             = true,
}

local MONK_SELF_UTILITY_SPELLS = {
  ["Укрепляющий отвар"]              = true,
  ["Распыление магии"]               = true,
  ["Смягчение удара"]                = true,
  ["Устранение вреда"]               = true,
  ["Кувырок"]                        = true,
  ["Ци-полет"]                       = true,
  ["Трансцендентность"]              = true,
  ["Трансцендентность: перенос"]     = true,
  ["Полет дзен"]                     = true,
  ["Дзен-полет"]                     = true,
  ["Духовное путешествие"]           = true,
  ["Дзен-паломничество"]             = true,
  ["Песнь Чи-Цзи"]                   = true,
}

local MONK_RANGED_HARM_SPELLS = {
  ["Сверкающая нефритовая молния"] = false,
  ["Паралич"]                      = false,
  ["Вызов"]                        = false,
  ["Столкновение"]                 = true,
}

local MONK_CUSTOM_SPELL_BODIES = {
  ["Оживить"]         = "#showtooltip Оживить\n/stopmacro [flying][channeling]\n/cast [@target,help,nodead][@player] Оживить",
  ["Оживление"]       = "#showtooltip Оживление\n/stopmacro [flying][channeling]\n/cast [@target,help,nodead][@player] Оживление",
  ["Детоксикация"]    = "#showtooltip Детоксикация\n/stopmacro [flying]\n/cast [@mouseover,help,nodead][@target,help,nodead][@player] Детоксикация",
  ["Тигриное рвение"] = "#showtooltip Тигриное рвение\n/stopmacro [flying]\n/cast [@mouseover,help,nodead][@target,help,nodead][@player] Тигриное рвение",
  ["Воскрешение"]     = "#showtooltip Воскрешение\n/stopmacro [flying]\n/cast [@mouseover,help,dead][@target,help,dead] Воскрешение",
  ["Круг мира"]       = "#showtooltip Круг мира\n/stopmacro [flying]\n/cast [@cursor] Круг мира",
}

local MONK_MOUNT_ROLL_MACRO = "#showtooltip\n/stopmacro [flying]\n/cast [combat][indoors] Кувырок; [mod:alt] Вожак стаи из Седых холмов; [mod:ctrl] Позолоченный брутозавр торговца; [mod:shift,flyable] Зотокрылый глубинный искатель; Величественный мушан бойца\n/cast [nomounted] Кувырок"

local function ExtractSingleCastSpellName(body)
  if type(body) ~= "string" then return nil end
  local castCount = 0
  local foundSpell = nil
  for line in body:gmatch("[^\r\n]+") do
    local castRest = line:match("^%s*/[cC][aA][sS][tT]%s+(.+)$")
    if castRest then
      castCount = castCount + 1
      if castCount > 1 or castRest:find(";", 1, true) then
        return nil
      end
      local cleaned = castRest:gsub("%b[]", ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("^!", "")
      if cleaned ~= "" then
        foundSpell = cleaned
      end
    end
  end
  return (castCount == 1) and foundSpell or nil
end

function GeminiOps.SyncMonkMacros(force, antiPetMode)
  local curKey = GeminiOps.GetCurrentCharKey()
  if not GeminiOps.IsPlayerMonk() and curKey ~= "Гитсутра - Пиратская Бухта" and curKey ~= "Гитсутра - Свежеватель Душ" then
    return false, "Macro sync is only for Monk (Гитсутра)"
  end
  if _G.InCombatLockdown and _G.InCombatLockdown() then
    return false, "Cannot sync macros in combat"
  end
  if not _G.GetMacroInfo or not _G.EditMacro then
    return false, "Macro API unavailable"
  end

  local gopsDB = GeminiOps:EnsureDB()
  if antiPetMode ~= nil then
    gopsDB.monkAntiPetPvP = (antiPetMode == true)
  end
  local useAntiPet = (gopsDB.monkAntiPetPvP == true)

  local taskKey = "monk_macros_v2_" .. (useAntiPet and "pvp_" or "mo_") .. tostring(curKey or "default")
  if gopsDB.completedTasks[taskKey] and not force then
    return false, "Already synced (" .. taskKey .. ")"
  end

  local updated = 0

  -- Scan only "." (mount/roll macro) and SpArc-generated m1..m30 / wm1..wm30 macros
  for idx = 1, 150 do
    local name, _, body = _G.GetMacroInfo(idx)
    if name and type(body) == "string" then
      local isCharSlot = (idx >= 121)
      local isSpArcMonkMacro = (name:match("^w?m%d+$") ~= nil)
      local newBody = nil

      if isCharSlot and name == "." then
        newBody = MONK_MOUNT_ROLL_MACRO
      elseif isSpArcMonkMacro then
        local spName = ExtractSingleCastSpellName(body)
        if spName then
          if MONK_CUSTOM_SPELL_BODIES[spName] then
            newBody = MONK_CUSTOM_SPELL_BODIES[spName]
          elseif MONK_MELEE_SPELLS[spName] then
            newBody = BuildShamanMeleeMacro(spName, useAntiPet)
          elseif MONK_COMBAT_PBAOE_SPELLS[spName] then
            newBody = string.format(
              "#showtooltip %s\n/stopmacro [flying]\n/cleartarget [dead][noharm]\n/cast %s\n/startattack",
              spName, spName
            )
          elseif MONK_SELF_UTILITY_SPELLS[spName] then
            newBody = string.format(
              "#showtooltip %s\n/stopmacro [flying]\n/cast %s",
              spName, spName
            )
          elseif MONK_RANGED_HARM_SPELLS[spName] ~= nil then
            newBody = BuildShamanRangedHarmMacro(spName, MONK_RANGED_HARM_SPELLS[spName])
          end
        end
      end

      if newBody and body ~= newBody then
        pcall(_G.EditMacro, idx, name, (name == "." and "134400" or "INV_MISC_QUESTIONMARK"), newBody)
        updated = updated + 1
      end
    end
  end

  gopsDB.completedTasks[taskKey] = true
  local modeLabel = useAntiPet
    and "PvP Anti-Pet (/targetenemyplayer + приоритет @target)"
    or "Восстановлен '.' (Маунты + Кувырок) + Мили (@mouseover) + АоЕ/Зенит (без @target)"
  return true, string.format("Обновлено макросов Монаха (Гитсутра): %d [%s]", updated, modeLabel)
end

---------------------------------------------------------------------------------------
--  3F. HUNTER (ГИТПУЛЛ — SURVIVAL / BM / MM) SMART MELEE / PET / TRAP / RANGED SYNC
--  • Melee abilities (Удар ящера, Укус мангуста, Намордник, Подрезать крылья):
--      Default (MO): [@mouseover,harm,nodead][@target,harm,nodead] + /startattack + /petattack
--      Anti-Pet PvP: /targetenemyplayer [noharm][dead] + [@target,harm,nodead][@mouseover,harm,nodead]
--  • Combat PBAoE / Cones / Bursts (Освежевание, Разделка туш, Ярость орла,
--    Согласованная атака, Звериный гнев, Меткий выстрел, Зов дикой природы):
--      Never require [@target] + /startattack + /petattack
--  • Ranged / Mid-Range Attacks (Команда «Взять!», Удар с фланга, Острие копья,
--    Бомба дикого огня, Убийственный выстрел, Разрывной выстрел, Гарпун и др.):
--      [@target,harm,nodead][@mouseover,harm,nodead] + /startattack + /petattack
--  • Traps / Ground Reticles (Замораживающая ловушка, Смоляная ловушка, Осветительная ракета и др.):
--      [@cursor] for instant 1-click throw at the CombatMode crosshair
--  • Smart Pet Care (Воскрешение питомца / Лечение питомца):
--      [nopet] Призыв питомца 1; Воскрешение питомца
--  • Smart Misdirection (Перенаправление):
--      [@focus,help,nodead][@mouseover,help,nodead][@target,help,nodead][@pet,exists,nodead]
---------------------------------------------------------------------------------------
local HUNTER_MELEE_SPELLS = {
  ["Удар ящера"]            = true,
  ["Укус мангуста"]         = true,
  ["Намордник"]             = true,
  ["Подрезать крылья"]      = true,
  ["Однокнопочный помощник"] = true,
}

local HUNTER_COMBAT_PBAOE_SPELLS = {
  ["Освежевание"]           = true,
  ["Разделка туш"]          = true,
  ["Ярость орла"]           = true,
  ["Огнестрел"]             = true,
  ["Дух орла"]              = true,
  ["Согласованная атака"]   = true,
  ["Звериный гнев"]         = true,
  ["Меткий выстрел"]        = true,
  ["Зов дикой природы"]     = true,
}

local HUNTER_CURSOR_SPELLS = {
  ["Замораживающая ловушка"] = true,
  ["Смоляная ловушка"]       = true,
  ["Фугасная ловушка"]       = true,
  ["Взрывная ловушка"]       = true,
  ["Стальной капкан"]        = true,
  ["Связующий выстрел"]      = true,
  ["Осветительная ракета"]   = true,
  ["Беглый огонь"]           = true,
  ["Орлиный глаз"]           = true,
}

local HUNTER_SELF_UTILITY_SPELLS = {
  ["Живость"]              = true,
  ["Выживает сильнейший"]  = true,
  ["Отрыв"]                = true,
  ["Дух хамелеона"]        = true,
  ["Камуфляж"]             = true,
  ["Глаза зверя"]          = true,
  ["Призыв питомца 1"]     = true,
  ["Призыв питомца 2"]     = true,
  ["Призыв питомца 3"]     = true,
  ["Призыв питомца 4"]     = true,
  ["Призыв питомца 5"]     = true,
  ["Отпустить питомца"]    = true,
  ["Кормление питомца"]    = true,
  ["Звериный глаз"]        = true,
  ["Фейерверк"]            = true,
}

-- Value = true if it should also trigger /startattack and /petattack; false for CC / Mark / Dispel
local HUNTER_RANGED_HARM_SPELLS = {
  ["Команда «Взять!»"]     = true,
  ["Команда \"Взять!\""]   = true,
  ["Удар с фланга"]        = true,
  ["Захват врасплох"]      = true,
  ["Острие копья"]         = true,
  ["Бомба дикого огня"]    = true,
  ["Огнебомба"]            = true,
  ["Бросок топорика"]      = true,
  ["Убийственный выстрел"] = true,
  ["Разрывной выстрел"]    = true,
  ["Гарпун"]               = true,
  ["Укус змеи"]            = true,
  ["Чародейский выстрел"]  = true,
  ["Верный выстрел"]       = true,
  ["Выстрел кобры"]        = true,
  ["Разрывающий выстрел"]  = true,
  ["Прицельный выстрел"]   = true,
  ["Быстрая стрельба"]     = true,
  ["Залп"]                 = true,
  ["Черная стрела"]        = true,
  ["Кровопролитие"]        = true,
  ["Яростный вой"]         = true,
  ["Метка охотника"]       = false,
  ["Устрашение"]           = false,
  ["Усмиряющий выстрел"]   = false,
  ["Контузящий выстрел"]   = false,
  ["Встречный выстрел"]    = false,
  ["Отпугивание зверя"]    = false,
  ["Приручение зверя"]     = false,
  ["Знание зверя"]         = false,
}

local HUNTER_MOUNT_CHEETAH_MACRO = "#showtooltip\n/stopmacro [flying]\n/castrandom [combat][indoors]Дух гепарда;[mod:alt]Вожак стаи из Седых холмов;[mod:ctrl]Позолоченный брутозавр торговца;[mod:shift]Зотокрылый темный искатель,Лютый звероястреб верховного следопыта;Неустрашимая императорская рысь"

local HUNTER_CUSTOM_SPELL_BODIES = {
  ["Дух гепарда"]          = HUNTER_MOUNT_CHEETAH_MACRO,
  ["Команда \"Взять!\""]   = "#showtooltip Команда \"Взять!\"\n/stopmacro [flying]\n/cleartarget [dead][noharm]\n/cast [@target,harm,nodead][@mouseover,harm,nodead] Команда \"Взять!\"\n/settarget\n/startattack\n/petattack",
  ["Отрыв"]                = "#showtooltip Отрыв\n/stopmacro [flying]\n/cast Отрыв\n/cast [combat][mod:shift] Дух орла",
  ["Дух орла"]             = "#showtooltip Дух орла\n/stopmacro [flying]\n/cleartarget [dead][noharm]\n/cast Отрыв\n/cast Дух орла\n/startattack\n/petattack",
  ["Огнестрел"]            = "#showtooltip Огнестрел\n/stopmacro [flying]\n/cleartarget [dead][noharm]\n/cast [combat][harm,nodead] Огнестрел; Распыление\n/stopmacro [nocombat,noharm]\n/startattack\n/petattack",
  ["Притвориться мертвым"] = "#showtooltip Притвориться мертвым\n/stopcasting\n/stopmacro [flying]\n/cast Притвориться мертвым",
  ["Дух черепахи"]         = "#showtooltip Дух черепахи\n/stopcasting\n/stopmacro [flying]\n/cast Дух черепахи",
  ["Перенаправление"]      = "#showtooltip Перенаправление\n/stopmacro [flying]\n/cast [@focus,help,nodead][@mouseover,help,nodead][@target,help,nodead][@pet,exists,nodead] Перенаправление",
  ["Воскрешение питомца"]  = "#showtooltip Воскрешение питомца\n/stopmacro [flying]\n/cast Воскрешение питомца",
  ["Лечение питомца"]      = "#showtooltip\n/stopmacro [flying]\n/cast [mod:shift,pet] Отпустить питомца; [nopet,mod:alt] Призыв питомца 2; [nopet] Призыв питомца 1; Лечение питомца",
  ["Кормление питомца"]    = "#showtooltip Кормление питомца\n/stopmacro [flying]\n/cast Кормление питомца",
  ["Отпустить питомца"]    = "#showtooltip Отпустить питомца\n/stopmacro [flying]\n/cast Отпустить питомца",
  ["Приказ хозяина"]       = "#showtooltip Приказ хозяина\n/stopmacro [flying]\n/cast [@mouseover,help,nodead][@target,help,nodead][@player] Приказ хозяина",
  ["Рев жертвенности"]     = "#showtooltip Рев жертвенности\n/stopmacro [flying]\n/cast [@mouseover,help,nodead][@target,help,nodead][@player] Рев жертвенности",
}

local HUNTER_PET_UTILITY_LIST = {
  {
    key  = "REVIVE_PET",
    match = "Воскрешение питомца",
    body = HUNTER_CUSTOM_SPELL_BODIES["Воскрешение питомца"],
  },
  {
    key  = "MEND_PET",
    match = "Лечение питомца",
    body = HUNTER_CUSTOM_SPELL_BODIES["Лечение питомца"],
  },
  {
    key  = "FEED_PET",
    match = "Кормление питомца",
    body = HUNTER_CUSTOM_SPELL_BODIES["Кормление питомца"],
  },
  {
    key  = "DISMISS_PET",
    match = "Отпустить питомца",
    body = HUNTER_CUSTOM_SPELL_BODIES["Отпустить питомца"],
  },
}

local function BuildHunterMeleeMacro(spellName, antiPetMode)
  if antiPetMode then
    return string.format(
      "#showtooltip %s\n/stopmacro [flying]\n/cleartarget [dead][noharm]\n/targetenemyplayer [noharm][dead]\n/cast [@target,harm,nodead][@mouseover,harm,nodead] %s\n/startattack\n/petattack",
      spellName, spellName
    )
  end
  return string.format(
    "#showtooltip %s\n/stopmacro [flying]\n/cleartarget [dead][noharm]\n/cast [@mouseover,harm,nodead][@target,harm,nodead] %s\n/startattack\n/petattack",
    spellName, spellName
  )
end

local function BuildHunterRangedHarmMacro(spellName, withAttack)
  if withAttack then
    return string.format(
      "#showtooltip %s\n/stopmacro [flying]\n/cleartarget [dead][noharm]\n/cast [@target,harm,nodead][@mouseover,harm,nodead] %s\n/startattack\n/petattack",
      spellName, spellName
    )
  end
  return string.format(
    "#showtooltip %s\n/stopmacro [flying]\n/cast [@target,harm,nodead][@mouseover,harm,nodead] %s",
    spellName, spellName
  )
end

function GeminiOps.SyncHunterMacros(force, antiPetMode)
  local curKey = GeminiOps.GetCurrentCharKey()
  if not GeminiOps.IsPlayerHunter() and curKey ~= "Гитхард - Гордунни" and curKey ~= "Гитпулл - Пиратская Бухта" and curKey ~= "Гитпулл - Свежеватель Душ" then
    return false, "Macro sync is only for Hunter (Гитхард / Гитпулл)"
  end
  if _G.InCombatLockdown and _G.InCombatLockdown() then
    return false, "Cannot sync macros in combat"
  end
  if not _G.GetMacroInfo or not _G.EditMacro then
    return false, "Macro API unavailable"
  end

  local gopsDB = GeminiOps:EnsureDB()
  if antiPetMode ~= nil then
    gopsDB.hunterAntiPetPvP = (antiPetMode == true)
  end
  local useAntiPet = (gopsDB.hunterAntiPetPvP == true)

  local taskKey = "hunter_macros_v5_" .. (useAntiPet and "pvp_" or "mo_") .. tostring(curKey or "default")
  if gopsDB.completedTasks[taskKey] and not force then
    return false, "Already synced (" .. taskKey .. ")"
  end

  local updated = 0
  local hasMountCheetahMacro = false
  local duplicateCheetahSlots = {}
  local existingNames = {}
  local foundPetUtility = {}
  local charMacroCount = 0

  -- First pass: check if h2 (or another macro) already holds the Mount + Cheetah macro
  for idx = 121, 150 do
    local name, _, body = _G.GetMacroInfo(idx)
    if name and type(body) == "string" then
      charMacroCount = charMacroCount + 1
      existingNames[name] = idx
      if body:find("Позолоченный брутозавр торговца", 1, true) and body:find("Дух гепарда", 1, true) then
        hasMountCheetahMacro = true
      end
      for _, pu in ipairs(HUNTER_PET_UTILITY_LIST) do
        if body:find(pu.match, 1, true) then
          foundPetUtility[pu.key] = idx
        end
      end
    end
  end

  -- Scan "." (mount/cheetah macro) and SpArc-generated h1..h30 / sh1..sh30 / bh1..bh30 / mh1..mh30 macros
  for idx = 1, 150 do
    local name, _, body = _G.GetMacroInfo(idx)
    if name and type(body) == "string" then
      local isCharSlot = (idx >= 121)
      local isSpArcHunterMacro = (name:match("^[sbm]?h%d+$") ~= nil)
      local newBody = nil

      if isCharSlot and name == "." then
        newBody = HUNTER_MOUNT_CHEETAH_MACRO
        hasMountCheetahMacro = true
      elseif isSpArcHunterMacro then
        local spName = ExtractSingleCastSpellName(body)
        if not spName then
          local ttSpell = body:match("^#showtooltip%s+([^\r\n]+)")
          if ttSpell then
            ttSpell = ttSpell:gsub("^%s+", ""):gsub("%s+$", "")
            if ttSpell ~= "" then
              spName = ttSpell
            end
          end
        end
        if spName == "Дух гепарда" and hasMountCheetahMacro and name ~= "h2" then
          duplicateCheetahSlots[#duplicateCheetahSlots + 1] = { idx = idx, name = name }
        elseif spName then
          if spName == "Дух гепарда" then
            hasMountCheetahMacro = true
          end
          if HUNTER_CUSTOM_SPELL_BODIES[spName] then
            newBody = HUNTER_CUSTOM_SPELL_BODIES[spName]
          elseif HUNTER_MELEE_SPELLS[spName] then
            newBody = BuildHunterMeleeMacro(spName, useAntiPet)
          elseif HUNTER_COMBAT_PBAOE_SPELLS[spName] then
            newBody = string.format(
              "#showtooltip %s\n/stopmacro [flying]\n/cleartarget [dead][noharm]\n/cast %s\n/startattack\n/petattack",
              spName, spName
            )
          elseif HUNTER_CURSOR_SPELLS[spName] then
            newBody = string.format(
              "#showtooltip %s\n/stopmacro [flying]\n/cast [@cursor] %s",
              spName, spName
            )
          elseif HUNTER_SELF_UTILITY_SPELLS[spName] then
            newBody = string.format(
              "#showtooltip %s\n/stopmacro [flying]\n/cast %s",
              spName, spName
            )
          elseif HUNTER_RANGED_HARM_SPELLS[spName] ~= nil then
            newBody = BuildHunterRangedHarmMacro(spName, HUNTER_RANGED_HARM_SPELLS[spName])
          end
        end
      end

      if newBody and body ~= newBody then
        pcall(_G.EditMacro, idx, name, (name == "." and "134400" or "INV_MISC_QUESTIONMARK"), newBody)
        updated = updated + 1
      end
    end
  end

  -- Ensure standalone Pet Utility macros exist (Revive Pet, Mend/Call Pet, Feed Pet, Dismiss Pet)
  -- so the player never has to use the spellbook Pet Utility flyout dropdown
  local nextHNum = 18
  local function NextFreeHunterMacroName()
    while existingNames["h" .. nextHNum] do
      nextHNum = nextHNum + 1
    end
    local mName = "h" .. nextHNum
    existingNames[mName] = true
    nextHNum = nextHNum + 1
    return mName
  end

  for _, pu in ipairs(HUNTER_PET_UTILITY_LIST) do
    local existingIdx = foundPetUtility[pu.key]
    if existingIdx then
      local mName, _, mBody = _G.GetMacroInfo(existingIdx)
      if mName and mBody ~= pu.body then
        pcall(_G.EditMacro, existingIdx, mName, "INV_MISC_QUESTIONMARK", pu.body)
        updated = updated + 1
      end
    elseif #duplicateCheetahSlots > 0 then
      local dup = table.remove(duplicateCheetahSlots, 1)
      pcall(_G.EditMacro, dup.idx, dup.name, "INV_MISC_QUESTIONMARK", pu.body)
      updated = updated + 1
    elseif _G.CreateMacro and charMacroCount < 30 then
      local newName = NextFreeHunterMacroName()
      local okCreate = pcall(_G.CreateMacro, newName, "INV_MISC_QUESTIONMARK", pu.body, true)
      if okCreate then
        charMacroCount = charMacroCount + 1
        updated = updated + 1
      end
    end
  end

  gopsDB.completedTasks[taskKey] = true
  local modeLabel = useAntiPet
    and "PvP Anti-Pet (/targetenemyplayer + приоритет @target) + Pet Macros (h18..h21)"
    or "h2 (Маунты + Гепард) + Pet (h18:Оживить, h19:Лечить/Призвать, h20:Кормить, h21:Отпустить) + Смарт-таргетинг"
  return true, string.format("Обновлено макросов Охотника (Гитпулл): %d [%s]", updated, modeLabel)
end

function GeminiOps.SyncShamanMacros(force, antiPetMode)
  local curKey = GeminiOps.GetCurrentCharKey()
  if not GeminiOps.IsPlayerShaman() and curKey ~= "Ниоч - Пиратская Бухта" then
    return false, "Macro sync is only for Shaman (Ниоч)"
  end
  if _G.InCombatLockdown and _G.InCombatLockdown() then
    return false, "Cannot sync macros in combat"
  end
  if not _G.GetMacroInfo or not _G.EditMacro then
    return false, "Macro API unavailable"
  end

  local gopsDB = GeminiOps:EnsureDB()
  if antiPetMode ~= nil then
    gopsDB.shamanAntiPetPvP = (antiPetMode == true)
  end
  local useAntiPet = (gopsDB.shamanAntiPetPvP == true)

  local taskKey = "shaman_macros_v4_" .. (useAntiPet and "pvp_" or "mo_") .. tostring(curKey or "default")
  if gopsDB.completedTasks[taskKey] and not force then
    return false, "Already synced (" .. taskKey .. ")"
  end

  local updated = 0

  -- Scan both Account Macros (es5, es6, es7 in 1..120) and Character Macros (121..150)
  for idx = 1, 150 do
    local name, _, body = _G.GetMacroInfo(idx)
    if name and type(body) == "string" then
      local isCharSlot = (idx >= 121)
      local isShamanAcctSlot = (not isCharSlot) and (name:match("^es%d+$") ~= nil)
      if isCharSlot or isShamanAcctSlot then
        local newBody = nil
        if name == "es6" then
          newBody = BuildShamanMeleeMacro("Удар бури", useAntiPet)
        elseif name == "es7" then
          newBody = BuildShamanMeleeMacro("Вскипание лавы", useAntiPet)
        elseif SHAMAN_NAMED_MACROS[name] then
          newBody = SHAMAN_NAMED_MACROS[name]
        else
          for meleeSpell in pairs(SHAMAN_MELEE_SPELLS) do
            if body:find(meleeSpell, 1, true) then
              newBody = BuildShamanMeleeMacro(meleeSpell, useAntiPet)
              break
            end
          end
          if not newBody then
            for rangedSpell, startAtk in pairs(SHAMAN_RANGED_HARM_SPELLS) do
              if body:find(rangedSpell, 1, true) then
                newBody = BuildShamanRangedHarmMacro(rangedSpell, startAtk)
                break
              end
            end
          end
        end

        if newBody and body ~= newBody then
          pcall(_G.EditMacro, idx, name, "INV_MISC_QUESTIONMARK", newBody)
          updated = updated + 1
        end
      end
    end
  end

  gopsDB.completedTasks[taskKey] = true
  local modeLabel = useAntiPet
    and "PvP Anti-Pet (/targetenemyplayer + приоритет @target)"
    or "Мили = @mouseover -> @target, Дальние = @target -> @mouseover"
  return true, string.format("Обновлено макросов Шамана (Ниоч): %d [%s]", updated, modeLabel)
end

local detailsChatTabBtn = nil
local detailsChatTabBg = nil
local detailsTabActive = false
local detailsHooksInstalled = false
local detailsSuppressHook = false

local function GetDetailsSubFrames(inst)
  if not inst then return {} end
  local id = inst.meu_id or 1
  local list = {}
  local seen = {}
  local function add(f)
    if type(f) == "table" and f.Hide and f.Show and not seen[f] then
      seen[f] = true
      list[#list + 1] = f
    end
  end
  add(inst.baseframe)
  add(inst.rowframe)
  add(inst.floatingframe)
  add(inst.windowSwitchButton)
  add(_G["DetailsBaseFrame" .. id])
  add(_G["DetailsRowFrame" .. id])
  add(_G["DetailsUpFrameInstance" .. id])
  add(_G["DetailsWindowSwitchButton" .. id])
  return list
end

local function SetDetailsFramesVisible(inst, visible)
  detailsSuppressHook = true
  for _, f in ipairs(GetDetailsSubFrames(inst)) do
    if visible then
      pcall(f.Show, f)
      if f.SetAlpha then pcall(f.SetAlpha, f, 1) end
    else
      if f.SetAlpha then pcall(f.SetAlpha, f, 0) end
      pcall(f.Hide, f)
    end
  end
  detailsSuppressHook = false
end

local function ApplyDetailsTabFont(fs, size)
  if not fs then return end
  local fPath = (_G.ChatFrame1Tab and _G.ChatFrame1Tab.Text and select(1, _G.ChatFrame1Tab.Text:GetFont()))
    or (_G.GameFontNormal and select(1, _G.GameFontNormal:GetFont()))
    or "Fonts\\FRIZQT___CYR.TTF"
  local ok = fs:SetFont(fPath, size or 11, "OUTLINE")
  if not ok then
    fs:SetFont("Fonts\\FRIZQT___CYR.TTF", size or 11, "OUTLINE")
  end
end

function GeminiOps.ConfigureNativeChatAndScale(customWidth, customHeight, customFontSize, customUiScale, silent)
  local gopsDB = GeminiOps:EnsureDB()
  local activeSlot = gopsDB.activeHardwareProfile or "PC"
  local defaultFont = (activeSlot == "LAPTOP") and 14 or 15
  local defaultScale = (activeSlot == "LAPTOP") and 0.85 or 0.78

  -- Pick up actual live ChatFrame1 dimensions from Blizzard Edit Mode unless custom dimensions were explicitly requested
  local cf1 = _G.ChatFrame1
  local liveW = (cf1 and cf1.GetWidth and math.floor((cf1:GetWidth() or 0) + 0.5)) or 0
  local liveH = (cf1 and cf1.GetHeight and math.floor((cf1:GetHeight() or 0) + 0.5)) or 0
  if customWidth then
    gopsDB.chatWidth = customWidth
  elseif liveW >= 250 then
    gopsDB.chatWidth = liveW
  else
    gopsDB.chatWidth = gopsDB.chatWidth or 445
  end
  if customHeight then
    gopsDB.chatHeight = customHeight
  elseif liveH >= 100 then
    gopsDB.chatHeight = liveH
  else
    gopsDB.chatHeight = gopsDB.chatHeight or 260
  end

  local fontSize = customFontSize or gopsDB.chatFontSize or defaultFont
  local uiScale = customUiScale or gopsDB.targetUiScale or defaultScale

  if customFontSize then
    gopsDB.chatFontSize = customFontSize
  else
    -- Pick up user's live ChatFrame1 font size if they changed it in-game
    if cf1 and cf1.GetFont then
      local _, liveFontSz = cf1:GetFont()
      if liveFontSz and liveFontSz >= 10 and liveFontSz <= 24 and gopsDB.completedTasks["native_chatfont_init_v1"] then
        fontSize = math.floor(liveFontSz + 0.5)
      end
    end
    gopsDB.chatFontSize = fontSize
  end

  if customUiScale then
    gopsDB.targetUiScale = customUiScale
  else
    local liveScale = tonumber(C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("uiScale"))
    if liveScale and liveScale >= 0.5 and liveScale <= 1.2 and gopsDB.completedTasks["native_uiscale_init_v1"] then
      uiScale = liveScale
    end
    gopsDB.targetUiScale = uiScale
  end

  -- 1. Native WoW UI Scale calibration (only on first-ever init or when user explicitly clicks a scale button)
  if not (_G.ElvUI and _G.ElvUI[1]) and C_CVar and C_CVar.SetCVar then
    if not gopsDB.completedTasks["native_uiscale_init_v1"] or customUiScale ~= nil then
      pcall(C_CVar.SetCVar, "useUiScale", "1")
      pcall(C_CVar.SetCVar, "uiScale", string.format("%.2f", uiScale))
      gopsDB.completedTasks["native_uiscale_init_v1"] = true
    end
  end

  -- 2. Native ChatFrame1..10 dark background (matching Details! opacity) — never fight EditMode position/size!
  _G.DEFAULT_CHATFRAME_ALPHA = 0.85
  _G.CHAT_FRAME_TAB_NORMAL_NOMOUSE_ALPHA = 0.65
  _G.CHAT_FRAME_TAB_SELECTED_NOMOUSE_ALPHA = 0.90
  _G.CHAT_FRAME_FADE_OUT_TIME = 0

  local applyFontNow = (not gopsDB.completedTasks["native_chatfont_init_v1"]) or (customFontSize ~= nil)
  gopsDB.completedTasks["native_chatfont_init_v1"] = true

  local numChat = _G.NUM_CHAT_WINDOWS or 10
  for i = 1, numChat do
    if applyFontNow and _G.SetChatWindowSize then pcall(_G.SetChatWindowSize, i, fontSize) end
    if _G.SetChatWindowColor then pcall(_G.SetChatWindowColor, i, 0.04, 0.04, 0.05) end
    if _G.SetChatWindowAlpha then pcall(_G.SetChatWindowAlpha, i, 0.85) end

    local cf = _G["ChatFrame" .. i]
    if cf then
      cf.oldAlpha = 0.85
      if applyFontNow and _G.FCF_SetChatWindowFontSize then pcall(_G.FCF_SetChatWindowFontSize, nil, cf, fontSize) end
      if _G.FCF_SetWindowColor then pcall(_G.FCF_SetWindowColor, cf, 0.04, 0.04, 0.05) end
      if _G.FCF_SetWindowAlpha then pcall(_G.FCF_SetWindowAlpha, cf, 0.85) end
      if applyFontNow then
        local fPath, _, fFlags = cf:GetFont()
        if fPath then
          pcall(cf.SetFont, cf, fPath, fontSize, fFlags or "")
        end
      end
    end

    local bg = _G["ChatFrame" .. i .. "Background"]
    if bg then
      pcall(bg.SetVertexColor, bg, 0.04, 0.04, 0.05, 0.85)
      pcall(bg.SetAlpha, bg, 0.85)
      pcall(bg.Show, bg)
    end
  end

  -- Only resize ChatFrame1 if user explicitly clicked a size button in GeminiOps
  if (customWidth or customHeight) and cf1 and not (_G.LeftChatPanel and _G.LeftChatPanel:IsShown()) then
    pcall(function()
      cf1:SetSize(gopsDB.chatWidth, gopsDB.chatHeight)
      cf1:SetWidth(gopsDB.chatWidth)
      cf1:SetHeight(gopsDB.chatHeight)
    end)
  end

  if not GeminiOps._chatFadeHooked and _G.hooksecurefunc and _G.FCF_FadeOutChatFrame then
    GeminiOps._chatFadeHooked = true
    _G.hooksecurefunc("FCF_FadeOutChatFrame", function(chatFrame)
      if not chatFrame then return end
      chatFrame.oldAlpha = 0.85
      local name = chatFrame:GetName()
      local bg = name and _G[name .. "Background"]
      if bg then
        pcall(bg.SetVertexColor, bg, 0.04, 0.04, 0.05, 0.85)
        pcall(bg.SetAlpha, bg, 0.85)
      end
    end)
  end

  if not silent then
    print(string.format(
      "|cff00ccff[GeminiOps]|r Настройки чата обновлены (шрифт %dpt, тёмный фон 85%%) | UIScale: %.2f",
      fontSize, uiScale
    ))
  end
  return true
end

function GeminiOps.SetupDetailsLeftChat(modeOverride, toggleActiveTab, forceAlign)
  local gopsDB = GeminiOps:EnsureDB()
  if not gopsDB.completedTasks["details_default_above_v2"] then
    gopsDB.detailsLeftMode = "ABOVE"
    gopsDB.completedTasks["details_default_above_v2"] = true
  end
  if modeOverride == "TAB" or modeOverride == "ABOVE" then
    gopsDB.detailsLeftMode = modeOverride
  end
  local mode = gopsDB.detailsLeftMode or "ABOVE" -- "ABOVE" (above Chat) or "TAB" (inside ElvUI LeftChatPanel)
  gopsDB.detailsLeftMode = mode

  -- Ensure native ChatFrame1 dark background is applied without overwriting user's EditMode chat size
  GeminiOps.ConfigureNativeChatAndScale(nil, nil, nil, nil, true)

  local Details = _G.Details or _G._detalhes
  if not Details or not Details.GetInstance then
    return false, "Details! not loaded"
  end

  local lcp = (_G.LeftChatPanel and _G.LeftChatPanel:IsShown() and _G.LeftChatPanel) or _G.ChatFrame1Background or _G.ChatFrame1
  if not lcp then
    return false, "Chat frame not found"
  end

  local ok, err = pcall(function()
    local inst = Details:GetInstance(1)
    if not inst or not inst.baseframe then return end

    -- Create the opaque background mask for TAB mode inside LeftChatPanel
    if not detailsChatTabBg then
      detailsChatTabBg = _G.CreateFrame("Frame", "GeminiOpsDetailsTabBg", lcp, "BackdropTemplate")
      detailsChatTabBg:SetPoint("TOPLEFT", lcp, "TOPLEFT", 2, -24)
      detailsChatTabBg:SetPoint("BOTTOMRIGHT", lcp, "BOTTOMRIGHT", -2, 22)
      detailsChatTabBg:SetFrameStrata("MEDIUM")
      detailsChatTabBg:SetFrameLevel(18)
      detailsChatTabBg:EnableMouse(true)
      if detailsChatTabBg.SetBackdrop then
        detailsChatTabBg:SetBackdrop({
          bgFile = "Interface\\Buttons\\WHITE8X8",
          edgeFile = "Interface\\Buttons\\WHITE8X8",
          edgeSize = 1,
        })
        detailsChatTabBg:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
        detailsChatTabBg:SetBackdropBorderColor(0.15, 0.15, 0.20, 1.0)
      end
      detailsChatTabBg:Hide()
    end

    -- Create the Chat Tab button ("Details!") anchored directly to LeftChatPanel top-right/top-left
    if not detailsChatTabBtn then
      detailsChatTabBtn = _G.CreateFrame("Button", "GeminiOpsDetailsChatTab", UIParent, "BackdropTemplate")
      detailsChatTabBtn:SetSize(78, 20)
      detailsChatTabBtn:SetFrameStrata("MEDIUM")
      detailsChatTabBtn:SetFrameLevel(35)
      detailsChatTabBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      if detailsChatTabBtn.SetBackdrop then
        detailsChatTabBtn:SetBackdrop({
          bgFile = "Interface\\Buttons\\WHITE8X8",
          edgeFile = "Interface\\Buttons\\WHITE8X8",
          edgeSize = 1,
        })
        detailsChatTabBtn:SetBackdropColor(0.08, 0.08, 0.10, 0.75)
        detailsChatTabBtn:SetBackdropBorderColor(0.25, 0.25, 0.32, 0.85)
      end

      local fs = detailsChatTabBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      ApplyDetailsTabFont(fs, 11)
      fs:SetPoint("CENTER", detailsChatTabBtn, "CENTER", 0, 0)
      detailsChatTabBtn.fs = fs

      detailsChatTabBtn:SetScript("OnEnter", function(self)
        self:SetAlpha(1.0)
        if not detailsTabActive and gopsDB.detailsLeftMode == "TAB" then
          self.fs:SetTextColor(1.0, 0.85, 0.25, 1.0)
        end
        if _G.GameTooltip then
          _G.GameTooltip:SetOwner(self, "ANCHOR_TOP")
          _G.GameTooltip:AddLine("|cffa335eeDetails! (Управление окном)|r")
          _G.GameTooltip:AddLine("|cffffd100ЛКМ:|r Показать / скрыть Details!", 0.9, 0.9, 0.9)
          _G.GameTooltip:AddLine("|cffffd100ПКМ:|r Режим: Вкладка в чате <-> Окно НАД чатом", 0.9, 0.9, 0.9)
          _G.GameTooltip:Show()
        end
      end)
      detailsChatTabBtn:SetScript("OnLeave", function()
        GeminiOps.UpdateDetailsTabVisual()
        if _G.GameTooltip then _G.GameTooltip:Hide() end
      end)

      detailsChatTabBtn:SetScript("OnClick", function(_, mouseBtn)
        if mouseBtn == "RightButton" then
          local nextMode = (gopsDB.detailsLeftMode == "TAB") and "ABOVE" or "TAB"
          detailsTabActive = false
          GeminiOps.SetupDetailsLeftChat(nextMode, false, true)
          if nextMode == "ABOVE" then
            print("|cff00ccff[GeminiOps]|r Details! вынесен |cffffd100НАД левым чатом|r.")
          else
            print("|cff00ccff[GeminiOps]|r Details! спрятан |cff00ff96во вкладку левого чата|r.")
          end
        else
          if gopsDB.detailsLeftMode == "TAB" then
            detailsTabActive = not detailsTabActive
            GeminiOps.ApplyDetailsVisibilityAndPosition(false)
          else
            local isVis = inst.rowframe and inst.rowframe:IsShown()
            SetDetailsFramesVisible(inst, not isVis)
            GeminiOps.UpdateDetailsTabVisual()
          end
        end
      end)
    end

    -- Anchor button cleanly to top-right of LeftChatPanel (only shown in TAB mode)
    detailsChatTabBtn:ClearAllPoints()
    detailsChatTabBtn:SetPoint("BOTTOMRIGHT", lcp, "TOPRIGHT", -2, 2)
    if mode == "TAB" then
      detailsChatTabBtn:Show()
    else
      detailsChatTabBtn:Hide()
    end

    -- Hook ChatFrame1Tab..10Tab clicks and Details subframes OnShow (only active in TAB mode)
    if not detailsHooksInstalled then
      detailsHooksInstalled = true
      for i = 1, 10 do
        local cTab = _G["ChatFrame" .. i .. "Tab"]
        if cTab and cTab.HookScript then
          cTab:HookScript("OnClick", function()
            if gopsDB.detailsLeftMode == "TAB" and detailsTabActive then
              detailsTabActive = false
              GeminiOps.ApplyDetailsVisibilityAndPosition(false)
            end
          end)
        end
      end
      if _G.hooksecurefunc and _G.FCF_Tab_OnClick then
        _G.hooksecurefunc("FCF_Tab_OnClick", function()
          if gopsDB.detailsLeftMode == "TAB" and detailsTabActive then
            detailsTabActive = false
            GeminiOps.ApplyDetailsVisibilityAndPosition(false)
          end
        end)
      end
      for _, subF in ipairs(GetDetailsSubFrames(inst)) do
        if subF.HookScript then
          subF:HookScript("OnShow", function()
            if detailsSuppressHook then return end
            if gopsDB.detailsLeftMode == "TAB" and not detailsTabActive then
              if detailsChatTabBg then detailsChatTabBg:Hide() end
              SetDetailsFramesVisible(inst, false)
            end
          end)
        end
      end
    end

    if toggleActiveTab ~= nil then
      detailsTabActive = toggleActiveTab
    end

    GeminiOps.ApplyDetailsVisibilityAndPosition(forceAlign)
  end)

  if ok then
    return true, (mode == "TAB")
      and "Details! встроен вкладкой в левый чат"
      or "Details! разблокирован и готов к настройке над левым чатом"
  end
  return false, tostring(err)
end

function GeminiOps.UpdateDetailsTabVisual()
  if not detailsChatTabBtn or not detailsChatTabBtn.fs then return end
  local gopsDB = GeminiOps:EnsureDB()
  if gopsDB.detailsLeftMode == "TAB" then
    detailsChatTabBtn:Show()
    if detailsTabActive then
      detailsChatTabBtn:SetAlpha(1.0)
      detailsChatTabBtn.fs:SetText("> Details! <")
      detailsChatTabBtn.fs:SetTextColor(1.0, 0.84, 0.20, 1.0)
    else
      detailsChatTabBtn:SetAlpha(0.55)
      detailsChatTabBtn.fs:SetText("Details!")
      detailsChatTabBtn.fs:SetTextColor(0.78, 0.78, 0.84, 1.0)
    end
  else
    detailsChatTabBtn:Hide()
  end
end

function GeminiOps.ApplyDetailsVisibilityAndPosition(forceAlign)
  local gopsDB = GeminiOps:EnsureDB()
  local mode = gopsDB.detailsLeftMode or "ABOVE"
  local Details = _G.Details or _G._detalhes
  local inst = Details and Details.GetInstance and Details:GetInstance(1)
  local hasElvChat = (_G.LeftChatPanel and _G.LeftChatPanel:IsShown())
  local lcp = hasElvChat and _G.LeftChatPanel or _G.ChatFrame1Background or _G.ChatFrame1
  if not inst or not inst.baseframe or not lcp then
    return
  end

  -- Always UNLOCK Details! so Anya can freely move or resize it without GeminiOps fighting her!
  inst.isLocked = false
  if inst.baseframe then
    inst.baseframe.isLocked = false
  end
  if inst.LockInstance then
    pcall(inst.LockInstance, inst, false)
  end
  if type(_G._detalhes_database) == "table" and _G._detalhes_database.local_instances_config and _G._detalhes_database.local_instances_config[1] then
    _G._detalhes_database.local_instances_config[1].isLocked = false
  end

  if mode == "TAB" and hasElvChat then
    local lw = lcp:GetWidth() or 468
    local lh = lcp:GetHeight() or 225
    local w = lw - 4
    local h = lh - 46
    inst.baseframe:ClearAllPoints()
    inst.baseframe:SetPoint("BOTTOMLEFT", lcp, "BOTTOMLEFT", 2, 22)
    inst.baseframe:SetSize(w, h)
    inst.baseframe:SetFrameStrata("MEDIUM")
    inst.baseframe:SetFrameLevel(22)
    if inst.rowframe then
      inst.rowframe:SetFrameStrata("MEDIUM")
      inst.rowframe:SetFrameLevel(24)
    end

    if detailsTabActive then
      if detailsChatTabBg then detailsChatTabBg:Show() end
      SetDetailsFramesVisible(inst, true)
    else
      if detailsChatTabBg then detailsChatTabBg:Hide() end
      SetDetailsFramesVisible(inst, false)
    end
  else
    -- ABOVE mode: Do NOT overwrite user's manual Details! position/size on /reload!
    -- Only snap above chat if user explicitly clicked "Выровнять Details! над чатом" (forceAlign)
    -- or one single time if Details! is currently overlapping the taller ChatFrame1 tabs.
    if detailsChatTabBg then detailsChatTabBg:Hide() end
    SetDetailsFramesVisible(inst, true)

    local needOneTimeLift = false
    if not gopsDB.completedTasks["details_free_lift_above_tall_chat_v1"] then
      gopsDB.completedTasks["details_free_lift_above_tall_chat_v1"] = true
      local detBottom = inst.baseframe.GetBottom and inst.baseframe:GetBottom()
      local chatTop = (_G.GeneralDockManager and _G.GeneralDockManager.GetTop and _G.GeneralDockManager:GetTop())
        or (lcp.GetTop and lcp:GetTop())
      if detBottom and chatTop and detBottom < (chatTop + 2) then
        needOneTimeLift = true
      end
    end

    if forceAlign or needOneTimeLift then
      local lw = lcp:GetWidth() or gopsDB.chatWidth or 445
      if lw < 200 then lw = 445 end
      local w = hasElvChat and (lw - 2) or lw
      local h = (inst.baseframe:GetHeight() and inst.baseframe:GetHeight() >= 80) and inst.baseframe:GetHeight() or 155
      local offX = hasElvChat and 1 or 0
      local offY = hasElvChat and 8 or 28
      inst.baseframe:ClearAllPoints()
      inst.baseframe:SetPoint("BOTTOMLEFT", lcp, "TOPLEFT", offX, offY)
      inst.baseframe:SetSize(w, h)
      inst.baseframe:SetFrameStrata("LOW")
      if inst.rowframe then
        inst.rowframe:SetFrameStrata("LOW")
      end
      if inst.SaveMainWindowPosition then
        pcall(inst.SaveMainWindowPosition, inst)
      end
      if inst.SaveMainWindowSize then
        pcall(inst.SaveMainWindowSize, inst)
      end
      if inst.ReajustaGump then
        pcall(inst.ReajustaGump, inst)
      end
    end
  end

  GeminiOps.UpdateDetailsTabVisual()
end

GeminiOps.EmbedDetailsInRightChat = GeminiOps.SetupDetailsLeftChat

---------------------------------------------------------------------------------------
--  3H. ECO / POWER-STATION GRAPHICS MODE & MINIMAP BUTTON
---------------------------------------------------------------------------------------
local function IsRunningOnLaptop()
  local gopsDB = GeminiOps:EnsureDB()
  if gopsDB.activeHardwareProfile == "LAPTOP" then
    return true
  end
  if _G.GetPhysicalScreenSize then
    local ok, w, h = pcall(_G.GetPhysicalScreenSize)
    if ok and w and h and w <= 2560 and h == 1600 then
      return true
    end
  end
  return false
end

local ECO_GRAPHICS_CVARS = {
  useMaxFPS                 = "1",
  maxFPS                    = "55",
  useMaxFPSBk               = "1",
  maxFPSBk                  = "8",
  LowLatencyMode            = "0",    -- Kills NVIDIA Reflex+Boost idle/load clock lock (2250MHz -> P8 idle!)
  renderScale               = "0.75",
  ResampleQuality           = "3",    -- AMD FSR 1.0 upscaling
  ResampleAlwaysSharpen     = "1",
  ResampleSharpness         = "0.3",
  ffxAntiAliasingMode       = "0",
  MSAAQuality               = "0",    -- Disables heavy 4x/8x MSAA GPU drain
  RAIDsettingsEnabled       = "0",    -- Prevents dungeons/delves/raids from reverting to heavy RAID* CVars
  -- High-level Settings UI sliders
  graphicsShadowQuality     = "0",
  graphicsLiquidDetail      = "0",
  graphicsSSAO              = "0",
  graphicsDepthEffects      = "0",
  graphicsComputeEffects    = "0",
  graphicsOutlineMode       = "1",
  graphicsParticleDensity   = "2",
  graphicsSpellDensity      = "1",    -- Essential spells only (keeps all boss mechanics visible!)
  graphicsViewDistance      = "2",
  graphicsEnvironmentDetail = "2",
  graphicsGroundClutter     = "1",
  -- Low-level render engine CVars (guaranteed immediate GPU/CPU power drop without opening Settings UI)
  shadowMode                = "0",
  shadowSoft                = "0",
  shadowRt                  = "0",
  SSAO                      = "0",
  volumeFog                 = "0",
  volumeFogLevel            = "0",
  sunShafts                 = "0",
  waterDetail               = "0",
  refraction                = "0",
  rippleDetail              = "0",
  reflectionMode            = "0",
  weatherDensity            = "0",
  physicsLevel              = "0",
  particledensity           = "40",
  OutlineEngineMode         = "1",
  farclip                   = "3500",
  horizonClip               = "3500",
  horizonStart              = "1000",
  terrainLodDist            = "250",
  wmoLodDist                = "250",
  doodadLodScale            = "75",
  lodObjectCullSize         = "22",
  lodObjectFadeScale        = "75",
  groundEffectDensity       = "32",
  groundEffectDist          = "70",
}

local LAPTOP_ECO_OVERRIDES = {
  maxFPS                    = "45",   -- Sweet spot for battery/power-station on laptop
  maxFPSBk                  = "5",    -- Drops background dGPU draw to ~4-5W
  renderScale               = "0.65", -- 1664x1040 w/ FSR on 16" 2560x1600 = crisp UI + 2.4x fewer pixels!
}

local BEAUTIFUL_FALLBACK_CVARS = {
  useMaxFPS                 = "1",
  maxFPS                    = "120",
  useMaxFPSBk               = "1",
  maxFPSBk                  = "15",
  LowLatencyMode            = "2",
  renderScale               = "1",
  ResampleAlwaysSharpen     = "0",
  ResampleSharpness         = "0.2",
  ffxAntiAliasingMode       = "0",
  MSAAQuality               = "0",
  RAIDsettingsEnabled       = "1",
  graphicsShadowQuality     = "3",
  graphicsLiquidDetail      = "2",
  graphicsSSAO              = "3",
  graphicsDepthEffects      = "3",
  graphicsComputeEffects    = "3",
  graphicsOutlineMode       = "2",
  graphicsParticleDensity   = "4",
  graphicsSpellDensity      = "2",
  graphicsViewDistance      = "7",
  graphicsEnvironmentDetail = "7",
  graphicsGroundClutter     = "7",
  shadowMode                = "3",
  shadowSoft                = "1",
  shadowRt                  = "0",
  SSAO                      = "3",
  volumeFog                 = "1",
  volumeFogLevel            = "2",
  sunShafts                 = "2",
  waterDetail               = "2",
  refraction                = "2",
  rippleDetail              = "1",
  reflectionMode            = "0",
  weatherDensity            = "3",
  physicsLevel              = "2",
  particledensity           = "80",
  OutlineEngineMode         = "2",
  farclip                   = "8000",
  horizonClip               = "8000",
  horizonStart              = "3000",
  terrainLodDist            = "550",
  wmoLodDist                = "400",
  doodadLodScale            = "125",
  lodObjectCullSize         = "16",
  lodObjectFadeScale        = "125",
  groundEffectDensity       = "128",
  groundEffectDist          = "260",
}

local ecoMinimapBtn = nil

function GeminiOps.SnapshotBeautifulGraphics()
  if not C_CVar or not C_CVar.GetCVar then return end
  local gopsDB = GeminiOps:EnsureDB()
  gopsDB.savedNormalGraphics = gopsDB.savedNormalGraphics or {}
  for cvarName in pairs(ECO_GRAPHICS_CVARS) do
    local ok, val = pcall(C_CVar.GetCVar, cvarName)
    if ok and val ~= nil and val ~= "" then
      gopsDB.savedNormalGraphics[cvarName] = tostring(val)
    end
  end
  -- Guard against accidentally snapshotting while already in reduced renderScale / ECO FPS
  if tonumber(gopsDB.savedNormalGraphics.renderScale) and tonumber(gopsDB.savedNormalGraphics.renderScale) < 0.85 then
    gopsDB.savedNormalGraphics.renderScale = "1"
  end
  if tonumber(gopsDB.savedNormalGraphics.maxFPS) and tonumber(gopsDB.savedNormalGraphics.maxFPS) <= 56 then
    gopsDB.savedNormalGraphics.maxFPS = IsRunningOnLaptop() and "60" or "120"
  end
end

function GeminiOps.UpdateEcoMinimapButtonVisual()
  if not ecoMinimapBtn then return end
  local gopsDB = GeminiOps:EnsureDB()
  local isEco = (gopsDB.ecoModeActive == true)
  if isEco then
    if ecoMinimapBtn.SetBackdropBorderColor then
      ecoMinimapBtn:SetBackdropBorderColor(0.15, 0.95, 0.45, 1.0)
      ecoMinimapBtn:SetBackdropColor(0.04, 0.16, 0.08, 0.92)
    end
    if ecoMinimapBtn.icon then
      ecoMinimapBtn.icon:SetVertexColor(0.35, 1.0, 0.55, 1.0)
    end
    if ecoMinimapBtn.label then
      ecoMinimapBtn.label:SetText("ECO")
      ecoMinimapBtn.label:SetTextColor(0.20, 1.0, 0.45, 1.0)
    end
  else
    if ecoMinimapBtn.SetBackdropBorderColor then
      ecoMinimapBtn:SetBackdropBorderColor(0.85, 0.70, 0.25, 0.85)
      ecoMinimapBtn:SetBackdropColor(0.08, 0.08, 0.10, 0.88)
    end
    if ecoMinimapBtn.icon then
      ecoMinimapBtn.icon:SetVertexColor(1.0, 0.88, 0.45, 1.0)
    end
    if ecoMinimapBtn.label then
      ecoMinimapBtn.label:SetText("MAX")
      ecoMinimapBtn.label:SetTextColor(1.0, 0.84, 0.25, 1.0)
    end
  end
end

function GeminiOps.ApplyEcoGraphicsMode(enable, silent)
  if not C_CVar or not C_CVar.SetCVar then return false end
  local gopsDB = GeminiOps:EnsureDB()
  local isLaptop = IsRunningOnLaptop()

  if enable then
    if not gopsDB.ecoModeActive or type(gopsDB.savedNormalGraphics) ~= "table" or next(gopsDB.savedNormalGraphics) == nil then
      GeminiOps.SnapshotBeautifulGraphics()
    end
    for cvarName, ecoVal in pairs(ECO_GRAPHICS_CVARS) do
      pcall(C_CVar.SetCVar, cvarName, ecoVal)
    end
    if isLaptop then
      for cvarName, lapVal in pairs(LAPTOP_ECO_OVERRIDES) do
        pcall(C_CVar.SetCVar, cvarName, lapVal)
      end
    end
    gopsDB.ecoModeActive = true
    GeminiOps.UpdateEcoMinimapButtonVisual()
    if not silent then
      if isLaptop then
        print("|cff00ccff[GeminiOps]|r |cff00ff7fВКЛЮЧЕН ЭКО-РЕЖИМ (Ноут Раптор / Блэкаут)|r: 45 FPS (5 в фоне), FSR 65% с резкостью, выключены Reflex Boost, MSAA, тени, туман и дальность.")
      else
        print("|cff00ccff[GeminiOps]|r |cff00ff7fВКЛЮЧЕН ЭКО-РЕЖИМ (Станция / Генератор)|r: 55 FPS (8 в фоне), FSR 75% с резкостью, выключены Reflex Boost, MSAA, тени и туман.")
      end
    end
  else
    local saved = (type(gopsDB.savedNormalGraphics) == "table" and next(gopsDB.savedNormalGraphics) ~= nil)
      and gopsDB.savedNormalGraphics
      or BEAUTIFUL_FALLBACK_CVARS
    for cvarName, defaultVal in pairs(BEAUTIFUL_FALLBACK_CVARS) do
      local targetVal = saved[cvarName] or defaultVal
      pcall(C_CVar.SetCVar, cvarName, targetVal)
    end
    for cvarName, savedVal in pairs(saved) do
      pcall(C_CVar.SetCVar, cvarName, savedVal)
    end
    gopsDB.ecoModeActive = false
    GeminiOps.UpdateEcoMinimapButtonVisual()
    if not silent then
      print("|cff00ccff[GeminiOps]|r |cffffd100ВКЛЮЧЕН КРАСИВЫЙ РЕЖИМ (Ультра / Розетка)|r: возвращены 100% масштаб разрешения, Reflex, FPS и полная графика!")
    end
  end
  return true
end

function GeminiOps.ToggleEcoGraphicsMode()
  local gopsDB = GeminiOps:EnsureDB()
  return GeminiOps.ApplyEcoGraphicsMode(not gopsDB.ecoModeActive, false)
end

local function PositionEcoMinimapButton(btn, angleDeg)
  local mm = _G.Minimap
  if not btn or not mm then return end
  local rad = math.rad(angleDeg or 205)
  local w = (mm:GetWidth() or 140) * 0.5 + 8
  local h = (mm:GetHeight() or 140) * 0.5 + 8
  local x = math.cos(rad) * w
  local y = math.sin(rad) * h
  -- Clamp cleanly to square border if ElvUI square minimap is active
  local isSquare = (_G.ElvUI and _G.ElvUI[1]) or (_G.GetMinimapShape and _G.GetMinimapShape() == "SQUARE")
  if isSquare then
    local maxW = (mm:GetWidth() or 140) * 0.5 + 2
    local maxH = (mm:GetHeight() or 140) * 0.5 + 2
    x = math.max(-maxW, math.min(maxW, x * 1.25))
    y = math.max(-maxH, math.min(maxH, y * 1.25))
  end
  btn:ClearAllPoints()
  btn:SetPoint("CENTER", mm, "CENTER", x, y)
end

function GeminiOps.SetupEcoMinimapButton()
  local mm = _G.Minimap
  if not mm then return end
  local gopsDB = GeminiOps:EnsureDB()
  gopsDB.ecoMinimapAngle = gopsDB.ecoMinimapAngle or 205

  if not ecoMinimapBtn then
    ecoMinimapBtn = _G.CreateFrame("Button", "GeminiOpsEcoMinimapButton", mm, "BackdropTemplate")
    ecoMinimapBtn:SetSize(28, 28)
    ecoMinimapBtn:SetFrameStrata("MEDIUM")
    ecoMinimapBtn:SetFrameLevel(25)
    ecoMinimapBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    ecoMinimapBtn:RegisterForDrag("LeftButton", "RightButton")

    if ecoMinimapBtn.SetBackdrop then
      ecoMinimapBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
      })
    end

    local icon = ecoMinimapBtn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", ecoMinimapBtn, "TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", ecoMinimapBtn, "BOTTOMRIGHT", -3, 3)
    icon:SetTexture(136048) -- Nature_Lightning icon
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ecoMinimapBtn.icon = icon

    local label = ecoMinimapBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ApplyDetailsTabFont(label, 9)
    label:SetPoint("BOTTOM", ecoMinimapBtn, "BOTTOM", 0, 1)
    ecoMinimapBtn.label = label

    ecoMinimapBtn:SetScript("OnDragStart", function(self)
      self.isDragging = true
      self:SetScript("OnUpdate", function(btn)
        local mx, my = mm:GetCenter()
        local cx, cy = _G.GetCursorPosition()
        local scale = mm:GetEffectiveScale() or 1
        if mx and my and cx and cy then
          local dx = (cx / scale) - mx
          local dy = (cy / scale) - my
          local deg = math.deg(math.atan2(dy, dx))
          gopsDB.ecoMinimapAngle = deg
          PositionEcoMinimapButton(btn, deg)
        end
      end)
    end)

    ecoMinimapBtn:SetScript("OnDragStop", function(self)
      self.isDragging = false
      self:SetScript("OnUpdate", nil)
    end)

    ecoMinimapBtn:SetScript("OnClick", function(_, mouseBtn)
      if mouseBtn == "RightButton" then
        if GeminiOps.ToggleControlPanel then
          GeminiOps.ToggleControlPanel()
        end
      else
        GeminiOps.ToggleEcoGraphicsMode()
        if GeminiOps.UpdateControlPanelVisuals then
          GeminiOps.UpdateControlPanelVisuals()
        end
      end
      if _G.GameTooltip and _G.GameTooltip:IsOwned(ecoMinimapBtn) then
        ecoMinimapBtn:GetScript("OnEnter")(ecoMinimapBtn)
      end
    end)

    ecoMinimapBtn:SetScript("OnEnter", function(self)
      if _G.GameTooltip then
        _G.GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        local isEco = (gopsDB.ecoModeActive == true)
        local hwSlot = (gopsDB.activeHardwareProfile == "LAPTOP") and "💻 Ноут (Раптор)" or "🖥️ ПК (Монитор)"
        _G.GameTooltip:AddLine("|cff00ccffGeminiOps — Операционная панель|r")
        _G.GameTooltip:AddLine("Активный профиль UI: |cffffd100" .. hwSlot .. "|r", 0.9, 0.9, 0.9)
        if isEco then
          if IsRunningOnLaptop() then
            _G.GameTooltip:AddLine("Графика: |cff00ff7f⚡ ECO (Ноут Блэкаут — 45 FPS, FSR 65%, Reflex OFF)|r", 0.85, 0.95, 0.85)
          else
            _G.GameTooltip:AddLine("Графика: |cff00ff7f⚡ ECO (Станция / Генератор — 55 FPS, FSR 75%, Reflex OFF)|r", 0.85, 0.95, 0.85)
          end
        else
          _G.GameTooltip:AddLine("Графика: |cffffd100✨ MAX (Розетка — 100% Ультра)|r", 0.95, 0.92, 0.80)
        end
        _G.GameTooltip:AddLine(" ")
        _G.GameTooltip:AddLine("|cffffd100ЛКМ:|r Переключить графику (|cffffd100MAX|r <-> |cff00ff7fECO|r)", 1, 1, 1)
        _G.GameTooltip:AddLine("|cffffd100ПКМ:|r Открыть |cff00ccffGeminiOps|r (Режимы |cffffd100ПК <-> Ноут|r, Скейл, Чат)", 1, 1, 1)
        _G.GameTooltip:AddLine("|cffaaaaaaПеретащить:|r Зажать и двигать вокруг миникарты", 0.7, 0.7, 0.7)
        _G.GameTooltip:Show()
      end
    end)

    ecoMinimapBtn:SetScript("OnLeave", function()
      if _G.GameTooltip then _G.GameTooltip:Hide() end
    end)
  end

  PositionEcoMinimapButton(ecoMinimapBtn, gopsDB.ecoMinimapAngle)
  GeminiOps.UpdateEcoMinimapButtonVisual()
  ecoMinimapBtn:Show()

  if gopsDB.ecoModeActive then
    GeminiOps.ApplyEcoGraphicsMode(true, true)
  end
end

---------------------------------------------------------------------------------------
--  3I. HARDWARE LAYOUT PROFILES ("PC" ULTRWIDE <-> "LAPTOP" RAPTOR) & CONTROL PANEL
---------------------------------------------------------------------------------------
local BT4_PROFILE_MODULES = {
  "ActionBars",
  "StanceBar",
  "PetBar",
  "BagBar",
  "MicroMenu",
  "StatusTrackingBar",
  "ExtraActionBar",
  "ZoneAbilityBar",
}

local controlPanelFrame = nil

function GeminiOps.SaveHardwareProfile(slot, silent)
  slot = (slot == "LAPTOP") and "LAPTOP" or "PC"
  local gopsDB = GeminiOps:EnsureDB()
  gopsDB.hardwareProfiles = gopsDB.hardwareProfiles or {}

  local cf1 = _G.ChatFrame1
  local liveW = (cf1 and cf1.GetWidth and math.floor((cf1:GetWidth() or 0) + 0.5)) or 0
  local liveH = (cf1 and cf1.GetHeight and math.floor((cf1:GetHeight() or 0) + 0.5)) or 0
  if liveW > 100 then gopsDB.chatWidth = liveW end
  if liveH > 60 then gopsDB.chatHeight = liveH end

  local curW = (liveW > 100 and liveW) or gopsDB.chatWidth or 450
  local curH = (liveH > 60 and liveH) or gopsDB.chatHeight or 240

  local snap = {
    savedAt      = _G.date and _G.date("%Y-%m-%d %H:%M") or "now",
    uiScale      = tonumber(C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("uiScale")) or gopsDB.targetUiScale or ((slot == "LAPTOP") and 0.85 or 0.78),
    useUiScale   = (C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("useUiScale")) or "1",
    chatWidth    = curW,
    chatHeight   = curH,
    chatFontSize = gopsDB.chatFontSize or 15,
    bartender4   = {},
  }

  -- 1. Snapshot Blizzard Edit Mode active layout index
  if _G.C_EditMode and _G.C_EditMode.GetLayouts then
    local okEM, layouts = pcall(_G.C_EditMode.GetLayouts)
    if okEM and type(layouts) == "table" and layouts.activeLayout then
      snap.editModeActiveLayout = layouts.activeLayout
    end
  end

  -- 2. Snapshot Bartender4 active profile bar positions, scales, rows & padding
  local BT4 = _G.Bartender4
  if BT4 and BT4.GetModule then
    for _, modName in ipairs(BT4_PROFILE_MODULES) do
      local mod = BT4:GetModule(modName, true)
      if mod and mod.db and type(mod.db.profile) == "table" then
        snap.bartender4[modName] = DeepCopy(mod.db.profile)
      end
    end
  end

  -- 3. Snapshot Details! Window 1 live position & size
  local Det = _G.Details or _G._detalhes
  if Det and Det.GetInstance then
    local okD, inst = pcall(Det.GetInstance, Det, 1)
    if okD and inst then
      if inst.SaveMainWindowPosition then
        pcall(inst.SaveMainWindowPosition, inst)
      end
      snap.detailsWindow1 = {
        libwindow = type(inst.libwindow) == "table" and DeepCopy(inst.libwindow) or nil,
        posicaoNormal = (type(inst.posicao) == "table" and type(inst.posicao.normal) == "table") and DeepCopy(inst.posicao.normal) or nil,
      }
    end
  end

  -- 4. Snapshot SpArc active profile & global layout geometry
  if type(_G.SpArcDB) == "table" then
    snap.sparcDB = DeepCopy(_G.SpArcDB)
  end

  -- 5. Snapshot BasicMinimap & BlizzMove
  if type(_G.BasicMinimapSV) == "table" then
    snap.basicMinimap = DeepCopy(_G.BasicMinimapSV)
  end
  if type(_G.BlizzMoveDB) == "table" then
    snap.blizzMove = DeepCopy(_G.BlizzMoveDB)
  end

  gopsDB.hardwareProfiles[slot] = snap
  gopsDB.activeHardwareProfile = slot

  if GeminiOps.UpdateControlPanelVisuals then
    GeminiOps.UpdateControlPanelVisuals()
  end

  if not silent then
    local label = (slot == "LAPTOP") and "💻 Ноут (Раптор)" or "🖥️ ПК (Широкоформатный монитор)"
    print(string.format(
      "|cff00ccff[GeminiOps]|r Текущая раскладка интерфейса (EditMode, Details!, Bartender4, SpArc, UIScale %.2f) сохранена в профиль: |cffffd100%s|r!",
      snap.uiScale, label
    ))
  end
  return true
end

function GeminiOps.ApplyHardwareProfile(slot, silent)
  slot = (slot == "LAPTOP") and "LAPTOP" or "PC"
  local gopsDB = GeminiOps:EnsureDB()
  gopsDB.hardwareProfiles = gopsDB.hardwareProfiles or {}

  -- Ensure PC baseline exists before switching away for the first time
  if not gopsDB.hardwareProfiles["PC"] then
    GeminiOps.SaveHardwareProfile("PC", true)
  end

  local snap = gopsDB.hardwareProfiles[slot]
  if not snap then
    -- Initialize Laptop profile from current layout with Laptop-friendly scale
    GeminiOps.SaveHardwareProfile(slot, true)
    snap = gopsDB.hardwareProfiles[slot]
    if slot == "LAPTOP" and snap then
      snap.uiScale = 0.85
      snap.chatFontSize = 14
    end
  end

  gopsDB.activeHardwareProfile = slot

  -- 1. Apply UI Scale & Chat font/dark backdrop (without overriding Edit Mode chat size)
  GeminiOps.ConfigureNativeChatAndScale(
    nil,
    nil,
    snap.chatFontSize or ((slot == "LAPTOP") and 14 or 15),
    snap.uiScale or ((slot == "LAPTOP") and 0.85 or 0.78),
    true
  )

  -- 2. Apply Blizzard Edit Mode layout if saved
  if snap.editModeActiveLayout and _G.C_EditMode and _G.C_EditMode.SetActiveLayout then
    if not (_G.InCombatLockdown and _G.InCombatLockdown()) then
      pcall(_G.C_EditMode.SetActiveLayout, snap.editModeActiveLayout)
    end
  end

  -- 3. Apply Bartender4 bar positions & scales live
  local BT4 = _G.Bartender4
  if BT4 and BT4.GetModule and type(snap.bartender4) == "table" and not (_G.InCombatLockdown and _G.InCombatLockdown()) then
    for _, modName in ipairs(BT4_PROFILE_MODULES) do
      local savedModProfile = snap.bartender4[modName]
      local mod = BT4:GetModule(modName, true)
      if savedModProfile and mod and mod.db and type(mod.db.profile) == "table" then
        OverwriteTableInPlace(mod.db.profile, savedModProfile)
        if modName == "ActionBars" and type(mod.actionbars) == "table" and type(mod.db.profile.actionbars) == "table" then
          for i = 1, 10 do
            local barCfg = mod.db.profile.actionbars[i]
            local barObj = mod.actionbars[i]
            if barCfg and barObj and barObj.ApplyConfig then
              pcall(barObj.ApplyConfig, barObj, barCfg)
            end
          end
        elseif mod.bar and mod.bar.ApplyConfig then
          pcall(mod.bar.ApplyConfig, mod.bar, mod.db.profile)
        elseif mod.ApplyConfig then
          pcall(mod.ApplyConfig, mod)
        end
      end
    end
  end

  -- 4. Restore Details! Window 1 saved position & size for this profile
  local Det = _G.Details or _G._detalhes
  if Det and Det.GetInstance and type(snap.detailsWindow1) == "table" then
    local okD, inst = pcall(Det.GetInstance, Det, 1)
    if okD and inst then
      inst.isLocked = false
      if inst.LockInstance then pcall(inst.LockInstance, inst, false) end
      if type(snap.detailsWindow1.libwindow) == "table" then
        inst.libwindow = inst.libwindow or {}
        OverwriteTableInPlace(inst.libwindow, snap.detailsWindow1.libwindow)
      end
      if type(snap.detailsWindow1.posicaoNormal) == "table" then
        inst.posicao = inst.posicao or {}
        inst.posicao.normal = inst.posicao.normal or {}
        OverwriteTableInPlace(inst.posicao.normal, snap.detailsWindow1.posicaoNormal)
      end
      if inst.RestoreMainWindowPosition then
        pcall(inst.RestoreMainWindowPosition, inst)
      end
    end
  end

  -- 5. Apply SpArc layout geometry
  if type(snap.sparcDB) == "table" and type(_G.SpArcDB) == "table" then
    OverwriteTableInPlace(_G.SpArcDB, snap.sparcDB)
    if _G.SpArc then
      if _G.SpArc.ApplyLayout then pcall(_G.SpArc.ApplyLayout, _G.SpArc) end
      if _G.SpArc.UpdateHUD then pcall(_G.SpArc.UpdateHUD, _G.SpArc) end
      if _G.SpArc.RefreshUnitFrames then pcall(_G.SpArc.RefreshUnitFrames, _G.SpArc) end
    end
  end

  -- 6. Apply BasicMinimap & BlizzMove
  if type(snap.basicMinimap) == "table" and type(_G.BasicMinimapSV) == "table" then
    OverwriteTableInPlace(_G.BasicMinimapSV, snap.basicMinimap)
  end
  if type(snap.blizzMove) == "table" and type(_G.BlizzMoveDB) == "table" then
    OverwriteTableInPlace(_G.BlizzMoveDB, snap.blizzMove)
  end

  -- 7. Refresh Chat dark backdrop & Details! styling (without overriding user positions)
  GeminiOps.ConfigureNativeChatAndScale(nil, nil, nil, nil, true)
  GeminiOps.SetupDetailsLeftChat("ABOVE", false, false)

  if GeminiOps.UpdateControlPanelVisuals then
    GeminiOps.UpdateControlPanelVisuals()
  end

  if not silent then
    local label = (slot == "LAPTOP") and "💻 Ноут (Раптор)" or "🖥️ ПК (Широкоформатный монитор)"
    print(string.format(
      "|cff00ccff[GeminiOps]|r Включён профиль интерфейса: |cffffd100%s|r (UIScale: %.2f).",
      label, gopsDB.targetUiScale or 0.78
    ))
  end
  return true
end

function GeminiOps.EnsureDefaultPCHardwareProfile()
  local gopsDB = GeminiOps:EnsureDB()
  gopsDB.hardwareProfiles = gopsDB.hardwareProfiles or {}
  gopsDB.activeHardwareProfile = gopsDB.activeHardwareProfile or "PC"
  if not gopsDB.hardwareProfiles["PC"] then
    GeminiOps.SaveHardwareProfile("PC", true)
  end
end

local function CreateOpsButton(parent, width, height, text, onClick)
  local btn = _G.CreateFrame("Button", nil, parent, "BackdropTemplate")
  btn:SetSize(width, height)
  if btn.SetBackdrop then
    btn:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
    })
    btn:SetBackdropColor(0.11, 0.12, 0.16, 0.95)
    btn:SetBackdropBorderColor(0.28, 0.30, 0.38, 0.95)
  end
  local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  ApplyDetailsTabFont(fs, 12)
  fs:SetPoint("CENTER", btn, "CENTER", 0, 0)
  fs:SetText(text)
  fs:SetTextColor(0.92, 0.92, 0.96, 1.0)
  btn.fs = fs

  btn:SetScript("OnEnter", function(self)
    if not self._isActive and self.SetBackdropBorderColor then
      self:SetBackdropBorderColor(0.95, 0.80, 0.30, 1.0)
    end
  end)
  btn:SetScript("OnLeave", function(self)
    if GeminiOps.UpdateControlPanelVisuals then
      GeminiOps.UpdateControlPanelVisuals()
    elseif self.SetBackdropBorderColor then
      self:SetBackdropBorderColor(0.28, 0.30, 0.38, 0.95)
    end
  end)
  btn:SetScript("OnClick", onClick)
  return btn
end

local function SetOpsButtonHighlight(btn, active, activeR, activeG, activeB)
  if not btn or not btn.SetBackdropBorderColor then return end
  btn._isActive = active
  if active then
    local r, g, b = activeR or 1.0, activeG or 0.82, activeB or 0.22
    btn:SetBackdropColor(r * 0.18, g * 0.18, b * 0.18, 0.96)
    btn:SetBackdropBorderColor(r, g, b, 1.0)
    if btn.fs then btn.fs:SetTextColor(r, g, b, 1.0) end
  else
    btn:SetBackdropColor(0.11, 0.12, 0.16, 0.95)
    btn:SetBackdropBorderColor(0.28, 0.30, 0.38, 0.95)
    if btn.fs then btn.fs:SetTextColor(0.88, 0.88, 0.92, 1.0) end
  end
end

function GeminiOps.UpdateControlPanelVisuals()
  if not controlPanelFrame then return end
  local gopsDB = GeminiOps:EnsureDB()
  local hw = gopsDB.activeHardwareProfile or "PC"
  local isEco = (gopsDB.ecoModeActive == true)
  local curScale = tonumber(C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("uiScale")) or gopsDB.targetUiScale or 0.78
  local curFont = gopsDB.chatFontSize or 15

  if controlPanelFrame.statusText then
    local hwText = (hw == "LAPTOP") and "|cff00ccff💻 Ноут (Раптор)|r" or "|cffffd100🖥️ ПК (Монитор 3440x1440)|r"
    local ecoText = isEco and "|cff00ff7f⚡ ECO (Станция)|r" or "|cffffd100✨ MAX (Розетка)|r"
    controlPanelFrame.statusText:SetText(string.format("Режим UI: %s   |   Графика: %s", hwText, ecoText))
  end

  SetOpsButtonHighlight(controlPanelFrame.btnPC, hw == "PC", 1.0, 0.82, 0.22)
  SetOpsButtonHighlight(controlPanelFrame.btnLaptop, hw == "LAPTOP", 0.25, 0.85, 1.0)

  SetOpsButtonHighlight(controlPanelFrame.btnMax, not isEco, 1.0, 0.82, 0.22)
  SetOpsButtonHighlight(controlPanelFrame.btnEco, isEco, 0.20, 0.95, 0.45)

  if controlPanelFrame.scaleBtns then
    for _, sb in ipairs(controlPanelFrame.scaleBtns) do
      SetOpsButtonHighlight(sb, math.abs((sb._val or 0) - curScale) < 0.015, 0.35, 0.90, 1.0)
    end
  end
  if controlPanelFrame.fontBtns then
    for _, fb in ipairs(controlPanelFrame.fontBtns) do
      SetOpsButtonHighlight(fb, (fb._val or 0) == curFont, 0.35, 0.90, 1.0)
    end
  end
end

function GeminiOps.ToggleControlPanel()
  if not controlPanelFrame then
    local f = _G.CreateFrame("Frame", "GeminiOpsControlPanel", UIParent, "BackdropTemplate")
    f:SetSize(460, 415)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(50)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    if f.SetBackdrop then
      f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
      })
      f:SetBackdropColor(0.05, 0.06, 0.08, 0.96)
      f:SetBackdropBorderColor(0.25, 0.70, 0.95, 0.90)
    end

    if _G.UISpecialFrames then
      table.insert(_G.UISpecialFrames, "GeminiOpsControlPanel")
    end

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ApplyDetailsTabFont(title, 15)
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
    title:SetText("|cff00ccffGeminiOps|r — Управление конфигурацией")

    local closeBtn = CreateOpsButton(f, 24, 24, "X", function() f:Hide() end)
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -10)

    local statusText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ApplyDetailsTabFont(statusText, 12)
    statusText:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -38)
    f.statusText = statusText

    -- Section 1: Hardware Profile (PC vs Laptop)
    local sec1 = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ApplyDetailsTabFont(sec1, 12)
    sec1:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -66)
    sec1:SetText("|cffffd1001. Профиль рабочего места (ПК Монитор <-> Ноут Раптор):|r")

    f.btnPC = CreateOpsButton(f, 208, 32, "🖥️ Режим: ПК (Монитор)", function()
      GeminiOps.ApplyHardwareProfile("PC", false)
    end)
    f.btnPC:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -86)

    f.btnLaptop = CreateOpsButton(f, 208, 32, "💻 Режим: Ноут (Раптор)", function()
      GeminiOps.ApplyHardwareProfile("LAPTOP", false)
    end)
    f.btnLaptop:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -86)

    f.btnSavePC = CreateOpsButton(f, 208, 24, "💾 Сохранить текущий UI как ПК", function()
      GeminiOps.SaveHardwareProfile("PC", false)
    end)
    f.btnSavePC:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -124)

    f.btnSaveLaptop = CreateOpsButton(f, 208, 24, "💾 Сохранить текущий UI как Ноут", function()
      GeminiOps.SaveHardwareProfile("LAPTOP", false)
    end)
    f.btnSaveLaptop:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -124)

    -- Section 2: Power & Graphics Mode (MAX vs ECO)
    local sec2 = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ApplyDetailsTabFont(sec2, 12)
    sec2:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -162)
    sec2:SetText("|cffffd1002. Питание и Графика (Розетка <-> Зарядная станция / Генератор):|r")

    f.btnMax = CreateOpsButton(f, 208, 30, "✨ MAX: Красивый (Розетка)", function()
      GeminiOps.ApplyEcoGraphicsMode(false, false)
      GeminiOps.UpdateControlPanelVisuals()
    end)
    f.btnMax:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -182)

    f.btnEco = CreateOpsButton(f, 208, 30, "⚡ ECO: Эко-режим (Станция)", function()
      GeminiOps.ApplyEcoGraphicsMode(true, false)
      GeminiOps.UpdateControlPanelVisuals()
    end)
    f.btnEco:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -182)

    -- Section 3: Native UI Scale (Crisp Fonts) & Chat
    local sec3 = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ApplyDetailsTabFont(sec3, 12)
    sec3:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -226)
    sec3:SetText("|cffffd1003. Масштаб интерфейса (UIScale для чётких шрифтов):|r")

    f.scaleBtns = {}
    local scales = { 0.70, 0.75, 0.78, 0.82, 0.85, 0.90 }
    for idx, sc in ipairs(scales) do
      local sb = CreateOpsButton(f, 66, 26, string.format("%.2f", sc), function()
        GeminiOps.ConfigureNativeChatAndScale(nil, nil, nil, sc, false)
        GeminiOps.UpdateControlPanelVisuals()
      end)
      sb._val = sc
      sb:SetPoint("TOPLEFT", f, "TOPLEFT", 16 + (idx - 1) * 72, -246)
      f.scaleBtns[#f.scaleBtns + 1] = sb
    end

    local sec4 = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ApplyDetailsTabFont(sec4, 12)
    sec4:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -284)
    sec4:SetText("|cffffd1004. Шрифт чата и быстрая стыковка Details! (размер чата — в Редакторе):|r")

    f.fontBtns = {}
    local fonts = { 13, 14, 15, 16 }
    for idx, fz in ipairs(fonts) do
      local fb = CreateOpsButton(f, 48, 26, tostring(fz) .. "pt", function()
        GeminiOps.ConfigureNativeChatAndScale(nil, nil, fz, nil, false)
        GeminiOps.UpdateControlPanelVisuals()
      end)
      fb._val = fz
      fb:SetPoint("TOPLEFT", f, "TOPLEFT", 16 + (idx - 1) * 52, -304)
      f.fontBtns[#f.fontBtns + 1] = fb
    end

    f.btnAlignDetails = CreateOpsButton(f, 208, 26, "📐 Выровнять Details! над чатом", function()
      GeminiOps.SetupDetailsLeftChat("ABOVE", false, true)
    end)
    f.btnAlignDetails:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -304)

    -- Section 5: Quick Macro Operations
    local sec5 = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ApplyDetailsTabFont(sec5, 12)
    sec5:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -342)
    sec5:SetText("|cffffd1005. Операции с макросами персонажа:|r")

    local btnSyncM = CreateOpsButton(f, 136, 28, "🔄 Синхр. макросы", function()
      _G.SlashCmdList["GEMINIOPS"]("macros")
    end)
    btnSyncM:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -362)

    local btnPvE = CreateOpsButton(f, 136, 28, "🎯 Мили: @mouseover", function()
      _G.SlashCmdList["GEMINIOPS"]("pve")
    end)
    btnPvE:SetPoint("TOPLEFT", f, "TOPLEFT", 162, -362)

    local btnPvP = CreateOpsButton(f, 136, 28, "⚔️ Мили: Анти-Пет PvP", function()
      _G.SlashCmdList["GEMINIOPS"]("pvp")
    end)
    btnPvP:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -362)

    controlPanelFrame = f
    GeminiOps.UpdateControlPanelVisuals()
    f:Show()
    return
  end

  if controlPanelFrame:IsShown() then
    controlPanelFrame:Hide()
  else
    GeminiOps.UpdateControlPanelVisuals()
    controlPanelFrame:Show()
  end
end

function GeminiOps.EnableStarhammerBar5(force)
  local curKey = GeminiOps.GetCurrentCharKey()
  if not GeminiOps.IsPlayerWarrior() and curKey ~= "Стархаммер - Свежеватель Душ" then
    return false
  end
  if _G.InCombatLockdown and _G.InCombatLockdown() then
    return false
  end
  local gopsDB = GeminiOps:EnsureDB()
  local taskKey = "starhammer_bt4_bar5_v1_" .. tostring(curKey or "default")
  if gopsDB.completedTasks[taskKey] and not force then
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

  gopsDB.completedTasks[taskKey] = true
  return true, "Включена Панель 5 Bartender4 (1, 2, 3, 4 / Shift+1..4) третьей сверху в масштабе 0.75"
end

---------------------------------------------------------------------------------------
--  4. EVENT LOOP & SLASH COMMANDS (/gops, /gemini)
---------------------------------------------------------------------------------------
local eventFrame = _G.CreateFrame("Frame", "GeminiOpsEventFrame", UIParent)
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

local pendingPageReset = false

eventFrame:SetScript("OnEvent", function(_, event)
  if event == "ACTIONBAR_PAGE_CHANGED" then
    if _G.GetActionBarPage and _G.ChangeActionBarPage then
      local curPage = _G.GetActionBarPage()
      if curPage and curPage > 2 then
        if _G.InCombatLockdown and _G.InCombatLockdown() then
          pendingPageReset = true
        else
          pcall(_G.ChangeActionBarPage, 1)
        end
      end
    end
    return
  elseif event == "PLAYER_REGEN_ENABLED" then
    if pendingPageReset and _G.ChangeActionBarPage then
      pendingPageReset = false
      pcall(_G.ChangeActionBarPage, 1)
    end
    return
  elseif event == "PLAYER_LOGIN" then
    GeminiOps.ApplyEnvironmentHygiene()
    GeminiOps.ApplyExternalAddonQoL()

    if C_Timer and C_Timer.After then
      C_Timer.After(1.5, function()
        GeminiOps.ApplyEnvironmentHygiene()
        GeminiOps.ApplyExternalAddonQoL()

        -- One-time profile clone for Пиратская Бухта, Свежеватель Душ & Гордунни characters
        local curKey = GeminiOps.GetCurrentCharKey()
        local autoCloneFromPriest = {
          ["Ньарлатхотеп - Пиратская Бухта"] = "Ньарлатхотеп - Свежеватель Душ",
          ["Ньярлатхотеп - Пиратская Бухта"] = "Ньарлатхотеп - Свежеватель Душ",
          ["Гитхард - Гордунни"]             = "Гитпулл - Пиратская Бухта",
          ["Гитпулл - Гордунни"]             = "Гитпулл - Пиратская Бухта",
          ["Гитсутра - Пиратская Бухта"]     = true,
          ["Гитсутра - Свежеватель Душ"]     = true,
          ["Гитпулл - Пиратская Бухта"]      = true,
          ["Гитпулл - Свежеватель Душ"]      = true,
          ["Гитпул - Пиратская Бухта"]       = true,
          ["Гитпул - Свежеватель Душ"]       = true,
          ["Ребейскармы - Пиратская Бухта"]  = true,
          ["Ребейскармы - Свежеватель Душ"]  = true,
          ["Гитхеранир - Пиратская Бухта"]   = true,
          ["Гитхеранир - Свежеватель Душ"]   = true,
          ["Гитхард - Пиратская Бухта"]      = true,
          ["Гитхард - Свежеватель Душ"]      = true,
          ["Мержменя - Пиратская Бухта"]     = true,
          ["Мержменя - Свежеватель Душ"]     = true,
          ["Ниоч - Пиратская Бухта"]         = true,
          ["Трипобраз - Пиратская Бухта"]    = true,
          ["Котастрофа - Пиратская Бухта"]   = true,
          ["Котострофа - Пиратская Бухта"]   = true,
          ["Улак - Пиратская Бухта"]         = true,
          ["Трипобраз - Свежеватель Душ"]    = true,
          ["Улак - Свежеватель Душ"]         = true,
        }
        if curKey and autoCloneFromPriest[curKey] then
          local srcTpl = (type(autoCloneFromPriest[curKey]) == "string")
            and autoCloneFromPriest[curKey]
            or GeminiOps.ResolvePriestTemplateKey(curKey)
          local okC, msgC = GeminiOps.CloneCharacterProfiles(srcTpl, curKey, false)
          if okC then
            print("|cff00ccff[GeminiOps]|r " .. tostring(msgC))
          end
        elseif curKey == "Морвара - Свежеватель Душ" or curKey == "Морвара - Пиратская Бухта" then
          local okC, msgC = GeminiOps.CloneCharacterProfiles("Калиратри - Свежеватель Душ", curKey, false)
          if okC then
            print("|cff00ccff[GeminiOps]|r " .. tostring(msgC))
          end
        end

        -- Automatically restore & update Priest character macros (including M1 and 1_to_2 fix v3)
        if GeminiOps.IsPlayerPriest() then
          local gopsDB = GeminiOps:EnsureDB()
          local pmKey = "priest_macros_v3_" .. tostring(curKey or "default")
          local forceUpdate = not gopsDB.completedTasks[pmKey]
          local okPM, msgPM = GeminiOps.SyncPriestMacros(forceUpdate)
          if forceUpdate then
            gopsDB.completedTasks[pmKey] = true
          end
          if okPM then
            print("|cff00ccff[GeminiOps]|r " .. tostring(msgPM))
          end
        end

        -- Automatically sync Enhancement Shaman (Ниоч) melee (@mouseover) & ranged (@target) macros
        if GeminiOps.IsPlayerShaman() then
          local okSM, msgSM = GeminiOps.SyncShamanMacros(false, nil)
          if okSM then
            print("|cff00ccff[GeminiOps]|r " .. tostring(msgSM))
          end
        end

        -- Automatically sync Windwalker Monk (Гитсутра) melee (@mouseover), PBAoE & ranged (@target) macros
        if GeminiOps.IsPlayerMonk() then
          local okMM, msgMM = GeminiOps.SyncMonkMacros(false, nil)
          if okMM then
            print("|cff00ccff[GeminiOps]|r " .. tostring(msgMM))
          end
        end

        -- Automatically sync Hunter (Гитпулл) melee (@mouseover), pet attack, traps (@cursor) & ranged (@target) macros
        if GeminiOps.IsPlayerHunter() then
          local okHM, msgHM = GeminiOps.SyncHunterMacros(false, nil)
          if okHM then
            print("|cff00ccff[GeminiOps]|r " .. tostring(msgHM))
          end
        end

        -- Style Chat & Details! without overriding user positions
        GeminiOps.SetupDetailsLeftChat(nil, nil, false)
        GeminiOps.SetupEcoMinimapButton()
        GeminiOps.EnsureDefaultPCHardwareProfile()
      end)
      C_Timer.After(3.0, function()
        GeminiOps.SetupDetailsLeftChat(nil, nil, false)
        GeminiOps.SetupEcoMinimapButton()
        GeminiOps.EnsureDefaultPCHardwareProfile()
      end)
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    GeminiOps.ApplyEnvironmentHygiene()
    if C_Timer and C_Timer.After then
      C_Timer.After(1.0, function()
        GeminiOps.SetupDetailsLeftChat(nil, nil, false)
        GeminiOps.SetupEcoMinimapButton()
      end)
    end
  elseif event == "PLAYER_LOGOUT" then
    GeminiOps.ApplyExternalAddonQoL()
    -- Automatically pick up any manual UI changes made during this session into the active hardware profile
    local gopsDB = GeminiOps:EnsureDB()
    GeminiOps.SaveHardwareProfile(gopsDB.activeHardwareProfile or "PC", true)
  end
end)

_G.SLASH_GEMINIOPS1 = "/gops"
_G.SLASH_GEMINIOPS2 = "/gemini"
_G.SlashCmdList["GEMINIOPS"] = function(msg)
  local cmd = (msg or ""):match("^(%S*)")
  cmd = (cmd or ""):lower()

  if cmd == "" or cmd == "ui" or cmd == "panel" or cmd == "menu" then
    GeminiOps.ToggleControlPanel()
  elseif cmd == "pc" or cmd == "desktop" then
    GeminiOps.ApplyHardwareProfile("PC", false)
  elseif cmd == "laptop" or cmd == "note" or cmd == "raptor" then
    GeminiOps.ApplyHardwareProfile("LAPTOP", false)
  elseif cmd == "savepc" then
    GeminiOps.SaveHardwareProfile("PC", false)
  elseif cmd == "savelaptop" or cmd == "savenote" then
    GeminiOps.SaveHardwareProfile("LAPTOP", false)
  elseif cmd == "clone" then
    local curKey = GeminiOps.GetCurrentCharKey()
    local tpl
    if curKey == "Морвара - Свежеватель Душ" or curKey == "Морвара - Пиратская Бухта" then
      tpl = "Калиратри - Свежеватель Душ"
    elseif curKey == "Ньарлатхотеп - Пиратская Бухта" or curKey == "Ньярлатхотеп - Пиратская Бухта" then
      tpl = "Ньарлатхотеп - Свежеватель Душ"
    elseif curKey == "Гитхард - Гордунни" or curKey == "Гитпулл - Гордунни" then
      tpl = "Гитпулл - Пиратская Бухта"
    else
      tpl = GeminiOps.ResolvePriestTemplateKey(curKey)
    end
    local ok, statusMsg = GeminiOps.CloneCharacterProfiles(tpl, curKey, true)
    print("|cff00ccff[GeminiOps]|r " .. tostring(statusMsg))
    if ok then
      print("|cff00ccff[GeminiOps]|r Напиши |cffffd100/reload|r, чтобы применить приватные модули ElvUI.")
    end
  elseif cmd == "macros" or cmd == "priestmacros" or cmd == "shamanmacros" or cmd == "monkmacros" or cmd == "huntermacros" then
    if cmd == "priestmacros" or GeminiOps.IsPlayerPriest() then
      local _, msgM = GeminiOps.SyncPriestMacros(true)
      print("|cff00ccff[GeminiOps]|r " .. tostring(msgM))
    elseif cmd == "shamanmacros" or GeminiOps.IsPlayerShaman() then
      local _, msgM = GeminiOps.SyncShamanMacros(true, nil)
      print("|cff00ccff[GeminiOps]|r " .. tostring(msgM))
    elseif cmd == "monkmacros" or GeminiOps.IsPlayerMonk() then
      local _, msgM = GeminiOps.SyncMonkMacros(true, nil)
      print("|cff00ccff[GeminiOps]|r " .. tostring(msgM))
    elseif cmd == "huntermacros" or GeminiOps.IsPlayerHunter() then
      local _, msgM = GeminiOps.SyncHunterMacros(true, nil)
      print("|cff00ccff[GeminiOps]|r " .. tostring(msgM))
    else
      local _, msgM = GeminiOps.SyncStarhammerMacros(true)
      print("|cff00ccff[GeminiOps]|r " .. tostring(msgM))
    end
  elseif cmd == "pvp" then
    if GeminiOps.IsPlayerMonk() then
      local _, msgM = GeminiOps.SyncMonkMacros(true, true)
      print("|cff00ccff[GeminiOps]|r " .. tostring(msgM))
    elseif GeminiOps.IsPlayerHunter() then
      local _, msgM = GeminiOps.SyncHunterMacros(true, true)
      print("|cff00ccff[GeminiOps]|r " .. tostring(msgM))
    else
      local _, msgM = GeminiOps.SyncShamanMacros(true, true)
      print("|cff00ccff[GeminiOps]|r " .. tostring(msgM))
    end
  elseif cmd == "pve" or cmd == "mo" then
    if GeminiOps.IsPlayerMonk() then
      local _, msgM = GeminiOps.SyncMonkMacros(true, false)
      print("|cff00ccff[GeminiOps]|r " .. tostring(msgM))
    elseif GeminiOps.IsPlayerHunter() then
      local _, msgM = GeminiOps.SyncHunterMacros(true, false)
      print("|cff00ccff[GeminiOps]|r " .. tostring(msgM))
    else
      local _, msgM = GeminiOps.SyncShamanMacros(true, false)
      print("|cff00ccff[GeminiOps]|r " .. tostring(msgM))
    end
  elseif cmd == "eco" or cmd == "power" or cmd == "blackout" then
    GeminiOps.ToggleEcoGraphicsMode()
  elseif cmd == "tab" then
    local _, statusMsg = GeminiOps.SetupDetailsLeftChat("TAB", true)
    print("|cff00ccff[GeminiOps]|r " .. tostring(statusMsg))
  elseif cmd == "above" or cmd == "details" then
    local _, statusMsg = GeminiOps.SetupDetailsLeftChat("ABOVE", false, true)
    print("|cff00ccff[GeminiOps]|r " .. tostring(statusMsg))
  elseif cmd == "qol" then
    GeminiOps.ApplyExternalAddonQoL()
    GeminiOps.ApplyEnvironmentHygiene()
    GeminiOps.SetupDetailsLeftChat(nil, nil)
    GeminiOps.SetupEcoMinimapButton()
    print("|cff00ccff[GeminiOps]|r Применены настройки CombatMode (watchlist), BlizzMove (1.5x центр), Details! (слева) и защита чата ElvUI.")
  else
    local curKey = GeminiOps.GetCurrentCharKey() or "Unknown"
    local E = _G.ElvUI and _G.ElvUI[1]
    local elvProf = (E and E.data and E.data.GetCurrentProfile and E.data:GetCurrentProfile()) or "N/A"
    local btProf = (_G.Bartender4 and _G.Bartender4.db and _G.Bartender4.db.GetCurrentProfile and _G.Bartender4.db:GetCurrentProfile()) or "N/A"
    local plProf = (_G.Plater and _G.Plater.db and _G.Plater.db.GetCurrentProfile and _G.Plater.db:GetCurrentProfile()) or "N/A"
    print("|cff00ccff[GeminiOps v" .. GeminiOps.VERSION .. "]|r Персонаж: |cffffd100" .. curKey .. "|r")
    print("  • Профиль ElvUI: |cff00ff96" .. tostring(elvProf) .. "|r | Bartender4: |cff00ff96" .. tostring(btProf) .. "|r | Plater: |cff00ff96" .. tostring(plProf) .. "|r")
    print("  • Команды: |cffffd100/gops|r (панель), |cffffd100/gops pc|r, |cffffd100/gops laptop|r, |cffffd100/gops eco|r, |cffffd100/gops macros|r.")
  end
end
