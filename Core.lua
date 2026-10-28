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
GeminiOps.DEFAULT_TEMPLATE_DETAILS = "Ньарлатхотеп-Свежеватель Душ"

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
    if E.db.WT and E.db.WT.quest and E.db.WT.quest.turnIn then
      E.db.WT.quest.turnIn.enable = false
    end
  end
  local W = _G.ElvUI_WindTools and _G.ElvUI_WindTools[1]
  if W and W.GetModule then
    local okTI, TI = pcall(W.GetModule, W, "TurnIn")
    if okTI and TI then
      if TI.db then TI.db.enable = false end
      if TI.UnregisterAllEvents then pcall(TI.UnregisterAllEvents, TI) end
      TI.initialized = false
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
    pcall(C_CVar.SetCVar, "CursorStickyCentering", "0")
  end
  if C_AddOns and C_AddOns.EnableAddOn then
    pcall(C_AddOns.EnableAddOn, "!BugGrabber")
    pcall(C_AddOns.EnableAddOn, "BugSack")
  end
  if C_AddOns and C_AddOns.DisableAddOn then
    pcall(C_AddOns.DisableAddOn, "CombatMode")
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
  { "F5", "ACTIONPAGE5" },
  { "G", "Combat Mode - Mouse Look" },
  { "F", "MULTIACTIONBAR1BUTTON5" },
  { "SHIFT-V", "NONE" },
  { "CTRL-V", "NONE" },
  { "SHIFT-T", "MULTIACTIONBAR1BUTTON8" },
  { "SHIFT-B", "NONE" },
  { "F12", "TOGGLESOUND" },
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
  { "F6", "ACTIONPAGE6" },
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
  if gopsDB.clonedCharacters[dstKey] == "v5" and not force then
    return false, "Already cloned (v5)"
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

  -- 2. ElvPrivateDB (disable ElvUI ActionBars/Nameplates/Bags + WindTools private config)
  if type(_G.ElvPrivateDB) == "table" and _G.ElvPrivateDB.profiles and _G.ElvPrivateDB.profiles[srcKey] then
    _G.ElvPrivateDB.profileKeys = _G.ElvPrivateDB.profileKeys or {}
    _G.ElvPrivateDB.profileKeys[dstKey] = dstKey
    _G.ElvPrivateDB.profiles[dstKey] = DeepCopyTable(_G.ElvPrivateDB.profiles[srcKey])
    if E and E.private then
      for k, v in pairs(_G.ElvPrivateDB.profiles[dstKey]) do
        E.private[k] = DeepCopyTable(v)
      end
    end
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

  -- 5. SpArc (Per-Character Visual/Camera Profile Cloner)
  if _G.SpArc and _G.SpArc.CopyProfileFrom then
    pcall(_G.SpArc.CopyProfileFrom, _G.SpArc, srcKey)
  end
  if type(_G.SpArcDB) == "table" and type(_G.SpArcDB.profiles) == "table" then
    local spSrc = _G.SpArcDB.profiles[srcKey]
    local spDst = _G.SpArcDB.profiles[dstKey]
    if type(spDst) == "table" then
      if type(spSrc) == "table" and spSrc.mode then
        spDst.mode = spSrc.mode
      end
      if srcKey == "Калиратри - Свежеватель Душ" then
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
    "MoveSearchEyeDB",
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

  gopsDB.clonedCharacters[dstKey] = "v5"
  return true, "Скопированы все профили (ElvUI, Bartender4 + бинды, Plater, Details!, SpArc, Masque, BigWigs) с [" .. tostring(srcKey) .. "] на [" .. tostring(dstKey) .. "]"
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

local detailsChatTabBtn = nil
local detailsChatTabBg = nil
local detailsTabActive = false
local detailsHooksInstalled = false

local function ApplyDetailsTabFont(fs, size)
  if not fs then return end
  local fPath = (_G.ChatFrame1Tab and _G.ChatFrame1Tab.Text and select(1, _G.ChatFrame1Tab.Text:GetFont()))
    or (_G.GameFontNormal and select(1, _G.GameFontNormal:GetFont()))
    or "Fonts\\FRIZQT___CYR.TTF"
  local ok = fs:SetFont(fPath, size or 12, "OUTLINE")
  if not ok then
    fs:SetFont("Fonts\\FRIZQT___CYR.TTF", size or 12, "OUTLINE")
  end
end

function GeminiOps.SetupDetailsLeftChat(modeOverride, toggleActiveTab)
  local gopsDB = GeminiOps:EnsureDB()
  if modeOverride == "TAB" or modeOverride == "ABOVE" then
    gopsDB.detailsLeftMode = modeOverride
  end
  local mode = gopsDB.detailsLeftMode or "TAB" -- "TAB" (inside LeftChatPanel as a tab) or "ABOVE" (nailed above LeftChatPanel)
  gopsDB.detailsLeftMode = mode

  local Details = _G.Details or _G._detalhes
  if not Details or not Details.GetInstance then
    return false, "Details! not loaded"
  end

  local lcp = _G.LeftChatPanel
  if not lcp then
    return false, "LeftChatPanel not found"
  end

  local ok, err = pcall(function()
    local inst = Details:GetInstance(1)
    if not inst or not inst.baseframe then return end

    -- Create the opaque background mask for TAB mode inside LeftChatPanel
    if not detailsChatTabBg then
      detailsChatTabBg = _G.CreateFrame("Frame", "GeminiOpsDetailsTabBg", lcp, "BackdropTemplate")
      detailsChatTabBg:SetPoint("TOPLEFT", lcp, "TOPLEFT", 2, -26)
      detailsChatTabBg:SetPoint("BOTTOMRIGHT", lcp, "BOTTOMRIGHT", -2, 23)
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

    -- Create the 3rd Chat Tab button ("Details!") in LeftChatPanel's tab bar
    if not detailsChatTabBtn then
      detailsChatTabBtn = _G.CreateFrame("Button", "GeminiOpsDetailsChatTab", lcp)
      detailsChatTabBtn:SetSize(86, 22)
      detailsChatTabBtn:SetFrameStrata("MEDIUM")
      detailsChatTabBtn:SetFrameLevel(30)
      detailsChatTabBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

      local fs = detailsChatTabBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      ApplyDetailsTabFont(fs, 12)
      fs:SetPoint("CENTER", detailsChatTabBtn, "CENTER", 0, 0)
      detailsChatTabBtn.fs = fs

      detailsChatTabBtn:SetScript("OnEnter", function(self)
        if not detailsTabActive and gopsDB.detailsLeftMode == "TAB" then
          self.fs:SetTextColor(1.0, 0.85, 0.25, 1.0)
        end
        if _G.GameTooltip then
          _G.GameTooltip:SetOwner(self, "ANCHOR_TOP")
          _G.GameTooltip:AddLine("|cffa335eeDetails! (Левый чат)|r")
          _G.GameTooltip:AddLine("|cffffd100ЛКМ:|r Показать / скрыть Details!", 0.9, 0.9, 0.9)
          _G.GameTooltip:AddLine("|cffffd100ПКМ:|r Переключить режим: Вкладка чата <-> Над левым чатом", 0.9, 0.9, 0.9)
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
          detailsTabActive = true
          GeminiOps.SetupDetailsLeftChat(nextMode, false)
          if nextMode == "ABOVE" then
            print("|cff00ccff[GeminiOps]|r Details! закреплён |cffffd100НАД левым чатом|r и прибит гвоздями (ПКМ по вкладке Details! — вернуть внутрь чата).")
          else
            print("|cff00ccff[GeminiOps]|r Details! встроен |cff00ff96вкладкой внутрь левого чата|r (ПКМ по вкладке Details! — вынести над чатом).")
          end
        else
          if gopsDB.detailsLeftMode == "TAB" then
            detailsTabActive = not detailsTabActive
            GeminiOps.ApplyDetailsVisibilityAndPosition()
          else
            if inst.baseframe:IsShown() then
              inst.baseframe:Hide()
            else
              inst.baseframe:Show()
            end
            GeminiOps.UpdateDetailsTabVisual()
          end
        end
      end)
    end

    -- Anchor tab right after ChatFrame2Tab (Журнал) or last docked tab
    detailsChatTabBtn:ClearAllPoints()
    local anchorTab = _G.ChatFrame2Tab or _G.ChatFrame1Tab
    if anchorTab and anchorTab:IsVisible() then
      detailsChatTabBtn:SetPoint("LEFT", anchorTab, "RIGHT", 6, 0)
    else
      detailsChatTabBtn:SetPoint("TOPLEFT", lcp, "TOPLEFT", 148, -3)
    end

    -- Hook ChatFrame1Tab..10Tab clicks so clicking "Общий" or "Журнал" switches back to chat
    if not detailsHooksInstalled then
      detailsHooksInstalled = true
      for i = 1, 10 do
        local cTab = _G["ChatFrame" .. i .. "Tab"]
        if cTab and cTab.HookScript then
          cTab:HookScript("OnClick", function()
            if gopsDB.detailsLeftMode == "TAB" and detailsTabActive then
              detailsTabActive = false
              GeminiOps.ApplyDetailsVisibilityAndPosition()
            end
          end)
        end
      end
      if _G.hooksecurefunc and _G.FCF_Tab_OnClick then
        _G.hooksecurefunc("FCF_Tab_OnClick", function()
          if gopsDB.detailsLeftMode == "TAB" and detailsTabActive then
            detailsTabActive = false
            GeminiOps.ApplyDetailsVisibilityAndPosition()
          end
        end)
      end
      if inst.baseframe and inst.baseframe.HookScript then
        inst.baseframe:HookScript("OnShow", function(self)
          if gopsDB.detailsLeftMode == "TAB" and not detailsTabActive then
            if detailsChatTabBg then detailsChatTabBg:Hide() end
            self:Hide()
          end
        end)
      end
    end

    if toggleActiveTab ~= nil then
      detailsTabActive = toggleActiveTab
    end

    GeminiOps.ApplyDetailsVisibilityAndPosition()
  end)

  if ok then
    return true, (mode == "TAB")
      and "Details! встроен третьей вкладкой в левый чат (ПКМ по вкладке Details! — закрепить над чатом)"
      or "Details! прибит гвоздями над левым чатом"
  end
  return false, tostring(err)
end

function GeminiOps.UpdateDetailsTabVisual()
  if not detailsChatTabBtn or not detailsChatTabBtn.fs then return end
  local gopsDB = GeminiOps:EnsureDB()
  local Details = _G.Details or _G._detalhes
  local inst = Details and Details.GetInstance and Details:GetInstance(1)
  if gopsDB.detailsLeftMode == "TAB" then
    if detailsTabActive then
      detailsChatTabBtn.fs:SetText("> Details! <")
      detailsChatTabBtn.fs:SetTextColor(1.0, 0.84, 0.20, 1.0)
    else
      detailsChatTabBtn.fs:SetText("Details!")
      detailsChatTabBtn.fs:SetTextColor(0.78, 0.78, 0.84, 1.0)
    end
  else
    local shown = inst and inst.baseframe and inst.baseframe:IsShown()
    detailsChatTabBtn.fs:SetText(shown and "Details! [^]" or "Details! [-]")
    detailsChatTabBtn.fs:SetTextColor(0.65, 0.85, 1.0, 1.0)
  end
end

function GeminiOps.ApplyDetailsVisibilityAndPosition()
  local gopsDB = GeminiOps:EnsureDB()
  local mode = gopsDB.detailsLeftMode or "TAB"
  local Details = _G.Details or _G._detalhes
  local inst = Details and Details.GetInstance and Details:GetInstance(1)
  local lcp = _G.LeftChatPanel
  if not inst or not inst.baseframe or not lcp then return end

  local lw = lcp:GetWidth() or 468
  local lh = lcp:GetHeight() or 230
  if lw < 200 then lw = 468 end
  if lh < 100 then lh = 230 end

  if mode == "TAB" then
    local w = lw - 4
    local h = lh - 50
    inst.baseframe:ClearAllPoints()
    inst.baseframe:SetPoint("BOTTOMLEFT", lcp, "BOTTOMLEFT", 2, 23)
    inst.baseframe:SetSize(w, h)
    inst.baseframe:SetFrameStrata("MEDIUM")
    inst.baseframe:SetFrameLevel(22)
    if inst.SaveMainWindowPosition then
      pcall(inst.SaveMainWindowPosition, inst)
    end
    inst.baseframe:ClearAllPoints()
    inst.baseframe:SetPoint("BOTTOMLEFT", lcp, "BOTTOMLEFT", 2, 23)
    inst.baseframe:SetSize(w, h)

    if detailsTabActive then
      if detailsChatTabBg then detailsChatTabBg:Show() end
      inst.baseframe:Show()
    else
      if detailsChatTabBg then detailsChatTabBg:Hide() end
      inst.baseframe:Hide()
    end
  else
    -- ABOVE mode: Nailed directly above LeftChatPanel (leaving both LeftChatPanel & RightChatPanel 100% visible)
    if detailsChatTabBg then detailsChatTabBg:Hide() end
    local w = lw - 2
    local h = 165
    inst.baseframe:ClearAllPoints()
    inst.baseframe:SetPoint("BOTTOMLEFT", lcp, "TOPLEFT", 1, 16)
    inst.baseframe:SetSize(w, h)
    inst.baseframe:SetFrameStrata("LOW")
    if inst.SaveMainWindowPosition then
      pcall(inst.SaveMainWindowPosition, inst)
    end
    inst.baseframe:ClearAllPoints()
    inst.baseframe:SetPoint("BOTTOMLEFT", lcp, "TOPLEFT", 1, 16)
    inst.baseframe:SetSize(w, h)
    inst.baseframe:Show()
  end

  -- Nail it down ("прибить гвоздями") so it cannot be accidentally dragged
  inst.isLocked = true
  if inst.LockInstance then
    pcall(inst.LockInstance, inst, true)
  end
  if type(_G._detalhes_database) == "table" and _G._detalhes_database.local_instances_config and _G._detalhes_database.local_instances_config[1] then
    _G._detalhes_database.local_instances_config[1].isLocked = true
  end

  GeminiOps.UpdateDetailsTabVisual()
end

GeminiOps.EmbedDetailsInRightChat = GeminiOps.SetupDetailsLeftChat

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

eventFrame:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    GeminiOps.ApplyEnvironmentHygiene()
    GeminiOps.ApplyExternalAddonQoL()

    if C_Timer and C_Timer.After then
      C_Timer.After(1.5, function()
        GeminiOps.ApplyEnvironmentHygiene()
        GeminiOps.ApplyExternalAddonQoL()

        -- One-time profile clone for Трипобраз & Улак (from Ньарлатхотеп) and Морвара (from Калиратри)
        local curKey = GeminiOps.GetCurrentCharKey()
        if curKey == "Трипобраз - Свежеватель Душ" or curKey == "Улак - Свежеватель Душ" then
          local okC, msgC = GeminiOps.CloneCharacterProfiles(GeminiOps.DEFAULT_TEMPLATE_CHAR, curKey, false)
          if okC then
            print("|cff00ccff[GeminiOps]|r " .. tostring(msgC))
          end
        elseif curKey == "Морвара - Свежеватель Душ" then
          local okC, msgC = GeminiOps.CloneCharacterProfiles("Калиратри - Свежеватель Душ", curKey, false)
          if okC then
            print("|cff00ccff[GeminiOps]|r " .. tostring(msgC))
          end
        end

        -- Move Details! out of RightChatPanel (Loot) to LeftChatPanel (Tab or Above) for all characters
        GeminiOps.SetupDetailsLeftChat(nil, nil)
      end)
      C_Timer.After(3.0, function()
        GeminiOps.SetupDetailsLeftChat(nil, nil)
      end)
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    GeminiOps.ApplyEnvironmentHygiene()
    if C_Timer and C_Timer.After then
      C_Timer.After(1.0, function()
        GeminiOps.SetupDetailsLeftChat(nil, nil)
      end)
    end
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
    local tpl = (curKey == "Морвара - Свежеватель Душ") and "Калиратри - Свежеватель Душ" or GeminiOps.DEFAULT_TEMPLATE_CHAR
    local ok, statusMsg = GeminiOps.CloneCharacterProfiles(tpl, curKey, true)
    print("|cff00ccff[GeminiOps]|r " .. tostring(statusMsg))
    if ok then
      print("|cff00ccff[GeminiOps]|r Напиши |cffffd100/reload|r, чтобы применить приватные модули ElvUI.")
    end
  elseif cmd == "macros" then
    local okM, msgM = GeminiOps.SyncStarhammerMacros(true)
    print("|cff00ccff[GeminiOps]|r " .. tostring(msgM))
  elseif cmd == "tab" then
    local _, statusMsg = GeminiOps.SetupDetailsLeftChat("TAB", true)
    print("|cff00ccff[GeminiOps]|r " .. tostring(statusMsg))
  elseif cmd == "above" or cmd == "details" then
    local _, statusMsg = GeminiOps.SetupDetailsLeftChat("ABOVE", false)
    print("|cff00ccff[GeminiOps]|r " .. tostring(statusMsg))
  elseif cmd == "qol" then
    GeminiOps.ApplyExternalAddonQoL()
    GeminiOps.ApplyEnvironmentHygiene()
    GeminiOps.SetupDetailsLeftChat(nil, nil)
    print("|cff00ccff[GeminiOps]|r Применены настройки CombatMode (watchlist), BlizzMove (1.5x центр), Details! (слева) и защита чата ElvUI.")
  else
    local curKey = GeminiOps.GetCurrentCharKey() or "Unknown"
    local E = _G.ElvUI and _G.ElvUI[1]
    local elvProf = (E and E.data and E.data.GetCurrentProfile and E.data:GetCurrentProfile()) or "N/A"
    local btProf = (_G.Bartender4 and _G.Bartender4.db and _G.Bartender4.db.GetCurrentProfile and _G.Bartender4.db:GetCurrentProfile()) or "N/A"
    local plProf = (_G.Plater and _G.Plater.db and _G.Plater.db.GetCurrentProfile and _G.Plater.db:GetCurrentProfile()) or "N/A"
    print("|cff00ccff[GeminiOps v" .. GeminiOps.VERSION .. "]|r Персонаж: |cffffd100" .. curKey .. "|r")
    print("  • Профиль ElvUI: |cff00ff96" .. tostring(elvProf) .. "|r | Bartender4: |cff00ff96" .. tostring(btProf) .. "|r | Plater: |cff00ff96" .. tostring(plProf) .. "|r")
    print("  • Команды: |cffffd100/gops tab|r (Details вкладкой левого чата), |cffffd100/gops above|r (Details над левым чатом), |cffffd100/gops clone|r, |cffffd100/gops qol|r.")
  end
end
