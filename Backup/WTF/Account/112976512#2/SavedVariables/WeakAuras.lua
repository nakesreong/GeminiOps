
WeakAurasSaved = {
["dynamicIconCache"] = {
},
["login_squelch_time"] = 10,
["features"] = {
},
["lastArchiveClear"] = 1792445212,
["minimap"] = {
["hide"] = false,
},
["lastUpgrade"] = 1792445215,
["dbVersion"] = 88,
["migrationCutoff"] = 730,
["registered"] = {
},
["historyCutoff"] = 730,
["tigerPriestUIVersion"] = 5,
["displays"] = {
["Rotation"] = {
["iconSource"] = -1,
["xOffset"] = 0,
["adjustedMax"] = "",
["adjustedMin"] = "",
["yOffset"] = 0,
["anchorPoint"] = "CENTER",
["cooldownSwipe"] = false,
["cooldownEdge"] = false,
["actions"] = {
["start"] = {
},
["init"] = {
["do_custom"] = true,
["custom"] = "aura_env.lastCast = aura_env.lastCast or {}\naura_env.vtAppliedAt = aura_env.vtAppliedAt or 0\naura_env.activeTotal = 0\naura_env.baseCD = {\n  [8092] = 7.5,   -- Mind Blast\n  [450983] = 4.5, -- Void Blast\n  [32379] = 10,   -- Shadow Word: Death\n  [205385] = 20,  -- Shadow Crash\n  [457042] = 20,  -- Shadow Crash (Target)\n  [263165] = 45,  -- Void Torrent\n  [120644] = 60,  -- Halo\n  [120517] = 60,  -- Halo\n  [34433] = 180,  -- Shadowfiend\n  [200174] = 60,  -- Mindbender\n  [451235] = 60,  -- Voidwraith\n  [391109] = 60,  -- Dark Ascension\n  [228260] = 90,  -- Void Eruption\n  [205448] = 6,   -- Void Bolt\n}\naura_env.coreBaseline = {\n  [8092] = true,   -- Mind Blast\n  [450983] = true, -- Void Blast\n  [335467] = true, -- Devouring Plague\n  [34914] = true,  -- Vampiric Touch\n  [15407] = true,  -- Mind Flay\n  [391403] = true, -- Mind Flay: Insanity\n  [32379] = true,  -- Shadow Word: Death\n  [589] = true,    -- Shadow Word: Pain\n}\naura_env.nonDamageBlacklist = {\n  [121536] = true, -- Angelic Feather\n  [17] = true,     -- Power Word: Shield\n  [21562] = true,  -- Power Word: Fortitude\n  [586] = true,    -- Fade\n  [19236] = true,  -- Desperate Prayer\n  [47585] = true,  -- Dispersion\n  [15286] = true,  -- Vampiric Embrace\n}\n\nif not aura_env.castWatcher then\n  local f = CreateFrame(\"Frame\")\n  f:RegisterUnitEvent(\"UNIT_SPELLCAST_SUCCEEDED\", \"player\")\n  f:RegisterEvent(\"PLAYER_TARGET_CHANGED\")\n  f:SetScript(\"OnEvent\", function(_, event, _, _, spellID)\n    if event == \"PLAYER_TARGET_CHANGED\" then\n      aura_env.vtAppliedAt = 0\n      return\n    end\n    if spellID and not (issecretvalue and issecretvalue(spellID)) then\n      local now = GetTime()\n      aura_env.lastCast[spellID] = now\n      if spellID == 34914 or spellID == 205385 or spellID == 457042 then\n        aura_env.vtAppliedAt = now\n      end\n    end\n  end)\n  aura_env.castWatcher = f\nend\n\nfunction aura_env.IsSpellProcActive(spellID)\n  if not spellID then return false end\n  if C_Spell and C_Spell.IsSpellOverlayed then\n    local ok, over = pcall(C_Spell.IsSpellOverlayed, spellID)\n    if ok and not (issecretvalue and issecretvalue(over)) and over then\n      return true\n    end\n  end\n  if IsSpellOverlayed then\n    local ok, over = pcall(IsSpellOverlayed, spellID)\n    if ok and not (issecretvalue and issecretvalue(over)) and over then\n      return true\n    end\n  end\n  return false\nend\n\nfunction aura_env.IsSpellKnownOrOnBar(spellID)\n  if not spellID or aura_env.nonDamageBlacklist[spellID] then return false end\n  if aura_env.coreBaseline[spellID] then return true end\n  if IsSpellKnownOrOverridesKnown then\n    local ok, k = pcall(IsSpellKnownOrOverridesKnown, spellID)\n    if ok and not (issecretvalue and issecretvalue(k)) and k then return true end\n  end\n  if IsSpellKnown then\n    local ok, k = pcall(IsSpellKnown, spellID)\n    if ok and not (issecretvalue and issecretvalue(k)) and k then return true end\n  end\n  if C_SpellBook and C_SpellBook.IsSpellKnown then\n    local ok, k = pcall(C_SpellBook.IsSpellKnown, spellID)\n    if ok and not (issecretvalue and issecretvalue(k)) and k then return true end\n  end\n  if IsPlayerSpell then\n    local ok, k = pcall(IsPlayerSpell, spellID)\n    if ok and not (issecretvalue and issecretvalue(k)) and k then return true end\n  end\n  if C_ActionBar and C_ActionBar.FindSpellActionButtons then\n    local ok, slots = pcall(C_ActionBar.FindSpellActionButtons, spellID)\n    if ok and type(slots) == \"table\" and next(slots) ~= nil then return true end\n  end\n  return false\nend\n\nfunction aura_env.IsOnCooldown(spellID)\n  if not spellID then return true end\n  local now = GetTime()\n  if spellID == 34914 then\n    if aura_env.vtAppliedAt and (now - aura_env.vtAppliedAt) < 16 then\n      return true\n    end\n  end\n  if C_Spell and C_Spell.GetSpellCharges then\n    local okC, charges = pcall(C_Spell.GetSpellCharges, spellID)\n    if okC and type(charges) == \"table\" and not (issecretvalue and issecretvalue(charges.currentCharges)) then\n      if charges.currentCharges and charges.currentCharges >= 1 then\n        return false\n      elseif charges.currentCharges == 0 then\n        return true\n      end\n    end\n  end\n  if C_Spell and C_Spell.GetSpellCooldown then\n    local okCD, cd = pcall(C_Spell.GetSpellCooldown, spellID)\n    if okCD and type(cd) == \"table\" and not (issecretvalue and (issecretvalue(cd.duration) or issecretvalue(cd.startTime))) then\n      if cd.duration and cd.duration > 1.6 and cd.startTime and cd.startTime > 0 then\n        if (cd.startTime + cd.duration - now) > 0.15 then\n          return true\n        end\n      end\n      return false\n    end\n  end\n  local last = aura_env.lastCast[spellID]\n  local bcd = aura_env.baseCD[spellID]\n  if not bcd and GetSpellBaseCooldown then\n    local okB, ms = pcall(GetSpellBaseCooldown, spellID)\n    if okB and type(ms) == \"number\" and not (issecretvalue and issecretvalue(ms)) and ms > 1600 then\n      bcd = ms / 1000\n    end\n  end\n  if last and bcd and (now - last) < (bcd - 0.2) then\n    return true\n  end\n  return false\nend\n\nif not aura_env.circleDriver then\n  local d = CreateFrame(\"Frame\")\n  aura_env.circleDriver = d\n  -- Clockwise semicircle starting at 10 o'clock (-60 deg) -> 11:15 (-22) -> 12:30 (+14) -> 1:45 (+50) -> 3:00 (+86) -> 4:10 (+122)\n  local arcAngles = { -60, -22, 14, 50, 86, 122 }\n  d:SetScript(\"OnUpdate\", function()\n    local total = aura_env.activeTotal or 0\n    if total <= 0 then return end\n    local cx, cy = 0, 0\n    local cf = _G.CombatModeCrosshairFrame\n    if cf and cf:IsShown() and cf:GetCenter() and UIParent:GetCenter() then\n      local ux, uy = UIParent:GetCenter()\n      local fx, fy = cf:GetCenter()\n      if fx and fy and ux and uy then\n        cx = fx - ux\n        cy = fy - uy\n      end\n    end\n    local radius = 88\n    local now = GetTime()\n    local pulse = 1.50 + 0.06 * math.sin(now * 6.5)\n    for i = 1, total do\n      local reg = WeakAuras.GetRegion and WeakAuras.GetRegion(aura_env.id, tostring(i))\n      if reg and reg:IsShown() then\n        local deg = arcAngles[i] or (-60 + (i - 1) * 36)\n        local rad = math.rad(deg)\n        local tx = cx + math.sin(rad) * radius\n        local ty = cy + math.cos(rad) * radius\n        local s = (i == 1) and pulse or 1.0\n        reg:SetScale(s)\n        reg:SetOffset(tx / s, ty / s)\n      end\n    end\n  end)\nend\n",
},
["finish"] = {
},
},
["triggers"] = {
{
["trigger"] = {
["type"] = "custom",
["custom_type"] = "stateupdate",
["event"] = "Health",
["unit"] = "player",
["customVariables"] = "{\n  keybind = \"string\",\n}",
["names"] = {
},
["spellIds"] = {
},
["custom"] = "function(allStates)\n  local now = GetTime()\n  if aura_env.lastScan and (now - aura_env.lastScan) < 0.07 then\n    return false\n  end\n  aura_env.lastScan = now\n\n  if not aura_env.cvarSet and C_CVar and C_CVar.SetCVar then\n    aura_env.cvarSet = true\n    pcall(C_CVar.SetCVar, \"assistedCombatHighlight\", \"1\")\n  end\n\n  local function SafeBool(fn, ...)\n    if not fn then return false end\n    local ok, res = pcall(fn, ...)\n    if not ok or (issecretvalue and issecretvalue(res)) then return false end\n    return res and true or false\n  end\n\n  local isMountedOrVehicle = SafeBool(IsMounted) or SafeBool(UnitInVehicle, \"player\") or SafeBool(HasOverrideActionBar)\n  local hasHostileTarget = not isMountedOrVehicle\n    and SafeBool(UnitExists, \"target\")\n    and SafeBool(UnitCanAttack, \"player\", \"target\")\n    and not SafeBool(UnitIsDead, \"target\")\n\n  if not hasHostileTarget then\n    local changed = false\n    aura_env.activeTotal = 0\n    for _, st in pairs(allStates) do\n      if st.show then\n        st.show = false\n        st.changed = true\n        changed = true\n      end\n    end\n    return changed\n  end\n\n  local queue = {}\n  local seen = {}\n\n  local function ResolveSpellID(rawID)\n    local spellID = rawID\n    if C_Spell and C_Spell.GetOverrideSpell then\n      local okO, over = pcall(C_Spell.GetOverrideSpell, rawID)\n      if okO and type(over) == \"number\" and not (issecretvalue and issecretvalue(over)) and over > 0 then\n        spellID = over\n      end\n    end\n    return spellID\n  end\n\n  local function TryAddSpell(rawID, forceReady)\n    if not rawID or rawID <= 0 or #queue >= 6 then return end\n    local spellID = ResolveSpellID(rawID)\n    if aura_env.nonDamageBlacklist[spellID] or aura_env.nonDamageBlacklist[rawID] then return end\n    if seen[spellID] or seen[rawID] then return end\n    if not aura_env.IsSpellKnownOrOnBar(spellID) and not aura_env.IsSpellKnownOrOnBar(rawID) then\n      return\n    end\n    if not forceReady then\n      if aura_env.IsOnCooldown(spellID) then\n        return\n      end\n      if spellID == 335467 or spellID == 32379 or spellID == 205448 then\n        if C_Spell and C_Spell.IsSpellUsable then\n          local okU, usable = pcall(C_Spell.IsSpellUsable, spellID)\n          if okU and not (issecretvalue and issecretvalue(usable)) and usable == false then\n            return\n          end\n        end\n      end\n    end\n    local icon\n    if C_Spell and C_Spell.GetSpellInfo then\n      local okI, info = pcall(C_Spell.GetSpellInfo, spellID)\n      icon = okI and info and info.iconID or nil\n    end\n    if not icon then return end\n    seen[spellID] = true\n    seen[rawID] = true\n    local kb = _G.TigerGetSpellKeybind and _G.TigerGetSpellKeybind(spellID) or \"\"\n    if kb == \"\" and _G.TigerGetSpellKeybind then\n      kb = _G.TigerGetSpellKeybind(rawID) or \"\"\n    end\n    queue[#queue + 1] = {\n      spellID = spellID,\n      icon = icon,\n      keybind = kb,\n    }\n  end\n\n  -- 1. Active Procs & Empowered Transforms jump immediately to #1 (10 o'clock, 150% scale)\n  local procCandidates = {\n    205448, -- Void Bolt (Voidform)\n    450983, -- Void Blast (Voidweaver Entropic Rift)\n    391403, -- Mind Flay: Insanity proc\n    407466, -- Mind Spike: Insanity proc\n    32379,  -- Shadow Word: Death (Deathspeaker proc)\n    8092,   -- Mind Blast (Shadowy Insight proc)\n    335467, -- Devouring Plague (Mind Devourer proc)\n  }\n  for i = 1, #procCandidates do\n    local cid = procCandidates[i]\n    local overID = ResolveSpellID(cid)\n    if overID == 450983 or overID == 391403 or overID == 407466 or aura_env.IsSpellProcActive(overID) or aura_env.IsSpellProcActive(cid) then\n      TryAddSpell(overID, false)\n    end\n  end\n\n  -- 2. Blizzard C_AssistedCombat live next-cast recommendation (tracks target DoTs & Insanity in C++)\n  if C_AssistedCombat and C_AssistedCombat.GetNextCastSpell then\n    local okN, nextSpell = pcall(C_AssistedCombat.GetNextCastSpell)\n    if okN and type(nextSpell) == \"number\" and not (issecretvalue and issecretvalue(nextSpell)) and nextSpell > 0 then\n      TryAddSpell(nextSpell, true)\n    end\n  end\n\n  -- 3. Icy Veins Shadow Priest Priority Queue (Archon & Voidweaver)\n  local icyVeinsPriority = {\n    205385, -- Shadow Crash (applies VT + SW:P)\n    457042, -- Shadow Crash (Target)\n    34914,  -- Vampiric Touch (if not recently applied to current target)\n    120644, -- Halo\n    391109, -- Dark Ascension\n    228260, -- Void Eruption / Void Bolt\n    263165, -- Void Torrent\n    34433,  -- Shadowfiend / Mindbender / Voidwraith\n    200174, -- Mindbender\n    451235, -- Voidwraith\n    335467, -- Devouring Plague (when enough Insanity)\n    8092,   -- Mind Blast / Void Blast\n    32379,  -- Shadow Word: Death\n    15407,  -- Mind Flay / Mind Flay: Insanity\n    589,    -- Shadow Word: Pain\n  }\n  for i = 1, #icyVeinsPriority do\n    TryAddSpell(icyVeinsPriority[i], false)\n  end\n\n  aura_env.activeTotal = #queue\n  local changed = false\n  for i = 1, #queue do\n    local key = tostring(i)\n    local item = queue[i]\n    local st = allStates[key]\n    if not st or not st.show or st.icon ~= item.icon or st.name ~= item.keybind or st.index ~= i then\n      allStates[key] = {\n        show = true,\n        changed = true,\n        icon = item.icon,\n        name = item.keybind,\n        keybind = item.keybind,\n        index = i,\n        autoHide = false,\n      }\n      changed = true\n    end\n  end\n  for k, st in pairs(allStates) do\n    local idx = tonumber(k)\n    if not idx or idx > #queue then\n      if st.show then\n        st.show = false\n        st.changed = true\n        changed = true\n      end\n    end\n  end\n  return changed\nend\n",
["check"] = "update",
["subeventSuffix"] = "_CAST_START",
["subeventPrefix"] = "SPELL",
["debuffType"] = "HELPFUL",
},
["untrigger"] = {
},
},
["activeTriggerMode"] = -10,
},
["internalVersion"] = 88,
["keepAspectRatio"] = true,
["selfPoint"] = "CENTER",
["desaturate"] = false,
["subRegions"] = {
{
["type"] = "subbackground",
},
{
["type"] = "subborder",
["border_size"] = 2,
["border_color"] = {
0.08,
0.08,
0.1,
1,
},
["border_visible"] = true,
["border_edge"] = "Square Full White",
["border_offset"] = 0,
},
{
["text_shadowXOffset"] = 0,
["text_text"] = "%n",
["text_shadowColor"] = {
0,
0,
0,
1,
},
["text_selfPoint"] = "AUTO",
["text_automaticWidth"] = "Auto",
["text_fixedWidth"] = 64,
["anchorYOffset"] = 0,
["text_justify"] = "CENTER",
["rotateText"] = "NONE",
["type"] = "subtext",
["text_color"] = {
1,
0.96,
0.85,
1,
},
["text_font"] = "Friz Quadrata TT",
["text_shadowYOffset"] = 0,
["text_wordWrap"] = "WordWrap",
["text_fontType"] = "OUTLINE",
["text_visible"] = true,
["anchor_point"] = "CENTER",
["text_fontSize"] = 15,
["anchorXOffset"] = 0,
["text_text_format_n_format"] = "none",
},
},
["height"] = 36,
["load"] = {
["use_class"] = true,
["talent"] = {
["multi"] = {
},
},
["spec"] = {
["multi"] = {
},
},
["class"] = {
["single"] = "PRIEST",
["multi"] = {
},
},
["size"] = {
["multi"] = {
},
},
},
["useAdjustededMax"] = false,
["useAdjustededMin"] = false,
["regionType"] = "icon",
["animation"] = {
["start"] = {
["easeStrength"] = 3,
["type"] = "none",
["duration_type"] = "seconds",
["easeType"] = "none",
},
["main"] = {
["easeStrength"] = 3,
["type"] = "none",
["duration_type"] = "seconds",
["easeType"] = "none",
},
["finish"] = {
["easeStrength"] = 3,
["type"] = "none",
["duration_type"] = "seconds",
["easeType"] = "none",
},
},
["information"] = {
},
["authorOptions"] = {
},
["color"] = {
1,
1,
1,
1,
},
["parent"] = "PriestUI",
["zoom"] = 0.3,
["cooldownTextDisabled"] = true,
["config"] = {
},
["frameStrata"] = 1,
["id"] = "Rotation",
["width"] = 36,
["alpha"] = 1,
["anchorFrameType"] = "SCREEN",
["useCooldownModRate"] = true,
["uid"] = "TigerPriestUI_Rotation",
["inverse"] = false,
["icon"] = true,
["conditions"] = {
},
["cooldown"] = false,
["progressSource"] = {
-1,
"",
},
},
["Saves"] = {
["iconSource"] = -1,
["xOffset"] = -140,
["adjustedMax"] = "",
["adjustedMin"] = "",
["yOffset"] = 0,
["anchorPoint"] = "CENTER",
["cooldownSwipe"] = true,
["cooldownEdge"] = false,
["icon"] = true,
["triggers"] = {
{
["trigger"] = {
["type"] = "custom",
["custom_type"] = "stateupdate",
["event"] = "Health",
["unit"] = "player",
["names"] = {
},
["spellIds"] = {
},
["custom"] = "function(allStates)\n  return false\nend",
["events"] = "PLAYER_ENTERING_WORLD",
["check"] = "event",
["subeventSuffix"] = "_CAST_START",
["subeventPrefix"] = "SPELL",
["debuffType"] = "HELPFUL",
},
["untrigger"] = {
},
},
["activeTriggerMode"] = -10,
},
["internalVersion"] = 88,
["keepAspectRatio"] = true,
["selfPoint"] = "CENTER",
["desaturate"] = false,
["subRegions"] = {
{
["type"] = "subbackground",
},
},
["height"] = 40,
["load"] = {
["use_class"] = true,
["talent"] = {
["multi"] = {
},
},
["spec"] = {
["multi"] = {
},
},
["class"] = {
["single"] = "PRIEST",
["multi"] = {
},
},
["size"] = {
["multi"] = {
},
},
},
["useAdjustededMax"] = false,
["useAdjustededMin"] = false,
["regionType"] = "icon",
["animation"] = {
["start"] = {
["easeStrength"] = 3,
["type"] = "none",
["duration_type"] = "seconds",
["easeType"] = "none",
},
["main"] = {
["easeStrength"] = 3,
["type"] = "none",
["duration_type"] = "seconds",
["easeType"] = "none",
},
["finish"] = {
["easeStrength"] = 3,
["type"] = "none",
["duration_type"] = "seconds",
["easeType"] = "none",
},
},
["information"] = {
},
["actions"] = {
["start"] = {
},
["finish"] = {
},
["init"] = {
},
},
["parent"] = "PriestUI",
["authorOptions"] = {
},
["zoom"] = 0.3,
["cooldownTextDisabled"] = false,
["config"] = {
},
["alpha"] = 1,
["id"] = "Saves",
["width"] = 40,
["useCooldownModRate"] = true,
["anchorFrameType"] = "SCREEN",
["frameStrata"] = 1,
["uid"] = "TigerPriestUI_Saves",
["inverse"] = false,
["progressSource"] = {
-1,
"",
},
["conditions"] = {
},
["cooldown"] = true,
["color"] = {
1,
1,
1,
1,
},
},
["CDs"] = {
["iconSource"] = -1,
["xOffset"] = 140,
["adjustedMax"] = "",
["adjustedMin"] = "",
["yOffset"] = 0,
["anchorPoint"] = "CENTER",
["cooldownSwipe"] = true,
["cooldownEdge"] = false,
["icon"] = true,
["triggers"] = {
{
["trigger"] = {
["type"] = "custom",
["custom_type"] = "stateupdate",
["event"] = "Health",
["unit"] = "player",
["names"] = {
},
["spellIds"] = {
},
["custom"] = "function(allStates)\n  return false\nend",
["events"] = "PLAYER_ENTERING_WORLD",
["check"] = "event",
["subeventSuffix"] = "_CAST_START",
["subeventPrefix"] = "SPELL",
["debuffType"] = "HELPFUL",
},
["untrigger"] = {
},
},
["activeTriggerMode"] = -10,
},
["internalVersion"] = 88,
["keepAspectRatio"] = true,
["selfPoint"] = "CENTER",
["desaturate"] = false,
["subRegions"] = {
{
["type"] = "subbackground",
},
},
["height"] = 40,
["load"] = {
["use_class"] = true,
["talent"] = {
["multi"] = {
},
},
["spec"] = {
["multi"] = {
},
},
["class"] = {
["single"] = "PRIEST",
["multi"] = {
},
},
["size"] = {
["multi"] = {
},
},
},
["useAdjustededMax"] = false,
["useAdjustededMin"] = false,
["regionType"] = "icon",
["animation"] = {
["start"] = {
["easeStrength"] = 3,
["type"] = "none",
["duration_type"] = "seconds",
["easeType"] = "none",
},
["main"] = {
["easeStrength"] = 3,
["type"] = "none",
["duration_type"] = "seconds",
["easeType"] = "none",
},
["finish"] = {
["easeStrength"] = 3,
["type"] = "none",
["duration_type"] = "seconds",
["easeType"] = "none",
},
},
["information"] = {
},
["actions"] = {
["start"] = {
},
["finish"] = {
},
["init"] = {
},
},
["parent"] = "PriestUI",
["authorOptions"] = {
},
["zoom"] = 0.3,
["cooldownTextDisabled"] = false,
["config"] = {
},
["alpha"] = 1,
["id"] = "CDs",
["width"] = 40,
["useCooldownModRate"] = true,
["anchorFrameType"] = "SCREEN",
["frameStrata"] = 1,
["uid"] = "TigerPriestUI_CDs",
["inverse"] = false,
["progressSource"] = {
-1,
"",
},
["conditions"] = {
},
["cooldown"] = true,
["color"] = {
1,
1,
1,
1,
},
},
["PriestUI"] = {
["backdropColor"] = {
1,
1,
1,
0.5,
},
["controlledChildren"] = {
"Rotation",
"Saves",
"CDs",
"Castbar",
},
["borderBackdrop"] = "Blizzard Tooltip",
["scale"] = 1,
["information"] = {
},
["border"] = false,
["yOffset"] = 0,
["anchorPoint"] = "CENTER",
["borderSize"] = 2,
["internalVersion"] = 88,
["borderColor"] = {
0,
0,
0,
1,
},
["regionType"] = "group",
["actions"] = {
["start"] = {
},
["finish"] = {
},
["init"] = {
},
},
["triggers"] = {
{
["trigger"] = {
["debuffType"] = "HELPFUL",
["type"] = "aura2",
["spellIds"] = {
},
["subeventSuffix"] = "_CAST_START",
["unit"] = "player",
["subeventPrefix"] = "SPELL",
["event"] = "Health",
["names"] = {
},
},
["untrigger"] = {
},
},
},
["xOffset"] = 0,
["borderOffset"] = 4,
["selfPoint"] = "CENTER",
["animation"] = {
["start"] = {
["easeStrength"] = 3,
["type"] = "none",
["duration_type"] = "seconds",
["easeType"] = "none",
},
["main"] = {
["easeStrength"] = 3,
["type"] = "none",
["duration_type"] = "seconds",
["easeType"] = "none",
},
["finish"] = {
["easeStrength"] = 3,
["type"] = "none",
["duration_type"] = "seconds",
["easeType"] = "none",
},
},
["id"] = "PriestUI",
["config"] = {
},
["frameStrata"] = 1,
["anchorFrameType"] = "SCREEN",
["uid"] = "TigerPriestUI_Group",
["borderInset"] = 1,
["alpha"] = 1,
["borderEdge"] = "Square Full White",
["conditions"] = {
},
["load"] = {
["use_class"] = true,
["talent"] = {
["multi"] = {
},
},
["spec"] = {
["multi"] = {
},
},
["class"] = {
["single"] = "PRIEST",
["multi"] = {
},
},
["size"] = {
["multi"] = {
},
},
},
["authorOptions"] = {
},
},
["Castbar"] = {
["sparkWidth"] = 10,
["iconSource"] = -1,
["xOffset"] = 0,
["adjustedMax"] = "",
["adjustedMin"] = "",
["yOffset"] = -145,
["anchorPoint"] = "CENTER",
["sparkRotation"] = 0,
["sparkRotationMode"] = "AUTO",
["icon"] = true,
["triggers"] = {
{
["trigger"] = {
["type"] = "unit",
["subeventSuffix"] = "_CAST_START",
["event"] = "Cast",
["unit"] = "player",
["spellIds"] = {
},
["names"] = {
},
["use_unit"] = true,
["subeventPrefix"] = "SPELL",
["debuffType"] = "HELPFUL",
},
["untrigger"] = {
},
},
["activeTriggerMode"] = -10,
},
["icon_color"] = {
1,
1,
1,
1,
},
["internalVersion"] = 88,
["progressSource"] = {
-1,
"",
},
["selfPoint"] = "CENTER",
["barColor"] = {
0.58,
0.24,
0.92,
1,
},
["desaturate"] = false,
["width"] = 220,
["sparkOffsetY"] = 0,
["subRegions"] = {
{
["type"] = "subbackground",
},
{
["type"] = "subforeground",
},
},
["height"] = 22,
["textureSource"] = "LSM",
["load"] = {
["use_class"] = true,
["talent"] = {
["multi"] = {
},
},
["spec"] = {
["multi"] = {
},
},
["class"] = {
["single"] = "PRIEST",
["multi"] = {
},
},
["size"] = {
["multi"] = {
},
},
},
["sparkBlendMode"] = "ADD",
["useAdjustededMax"] = false,
["authorOptions"] = {
},
["information"] = {
},
["gradientOrientation"] = "HORIZONTAL",
["actions"] = {
["start"] = {
},
["finish"] = {
},
["init"] = {
},
},
["backgroundColor"] = {
0.08,
0.08,
0.1,
0.85,
},
["useAdjustededMin"] = false,
["regionType"] = "aurabar",
["enableGradient"] = false,
["uid"] = "TigerPriestUI_Castbar",
["icon_side"] = "LEFT",
["parent"] = "PriestUI",
["sparkHeight"] = 30,
["texture"] = "Solid",
["alpha"] = 1,
["zoom"] = 0.3,
["spark"] = false,
["sparkTexture"] = "Interface\\CastingBar\\UI-CastingBar-Spark",
["sparkHidden"] = "NEVER",
["id"] = "Castbar",
["frameStrata"] = 1,
["anchorFrameType"] = "SCREEN",
["sparkColor"] = {
1,
1,
1,
1,
},
["config"] = {
},
["inverse"] = false,
["sparkOffsetX"] = 0,
["orientation"] = "HORIZONTAL",
["conditions"] = {
},
["barColor2"] = {
1,
1,
0,
1,
},
["animation"] = {
["start"] = {
["easeStrength"] = 3,
["type"] = "none",
["duration_type"] = "seconds",
["easeType"] = "none",
},
["main"] = {
["easeStrength"] = 3,
["type"] = "none",
["duration_type"] = "seconds",
["easeType"] = "none",
},
["finish"] = {
["easeStrength"] = 3,
["type"] = "none",
["duration_type"] = "seconds",
["easeType"] = "none",
},
},
},
},
}
