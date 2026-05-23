-- PartyKeys
-- Place buttons next to the LFG frame for players to list a party members key without having to refill out the fields

local addonName = "PartyKeys"

-- ============================================================
-- Keystone
-- ============================================================

local function GetPlayerKeystone()
    local activityID, _, level = C_LFGList.GetOwnedKeystoneActivityAndGroupAndLevel()
    if not activityID or not level then return end

    local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
    return {
        activityID = activityID,
        level = level,
        dungeonName = activityInfo.fullName:match("^(.-)%s*%(") or activityInfo.fullName
    }
end

-- ============================================================
-- Comms
-- ============================================================

local COMM_PREFIX = "PartyKeys"
C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX)

local partyKeys = {}

local function BroadcastMyKey()
    local keystone = GetPlayerKeystone()
    if not keystone then return end

    local msg = string.format("KEY %d %d %s", keystone.activityID, keystone.level, keystone.dungeonName)
    local channel = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or "PARTY"
    C_ChatInfo.SendAddonMessage(COMM_PREFIX, msg, channel)
end

local function RequestPartyKeys()
    partyKeys = {}
    local channel = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or "PARTY"
    C_ChatInfo.SendAddonMessage(COMM_PREFIX, "REQUEST", channel)
    BroadcastMyKey()
end

-- ============================================================
-- Container frame
-- ============================================================
local panelWidth = 160
local panel = CreateFrame("Frame", addonName .. "Panel", UIParent, "BackdropTemplate")
panel:SetSize(panelWidth, 20)
panel:SetPoint("TOPRIGHT", PVEFrame, "BOTTOMRIGHT", 0, 0)

-- Give the panel a simple backdrop so it looks like a proper WoW window
panel:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    tile     = true,
    tileSize = 32,
    edgeSize = 16,
})

panel:Hide()

-- ============================================================
-- Buttons inside the panel
-- ============================================================

local function ButtonText(keyData)
    if keyData then
        return string.format("+%d %s (%s)", keyData.level, ShortName(keyData.dungeonName), keyData.playerName:sub(1, 7))
    end
    return "No Key"
end

local partyKeyButtons = {}
local partyKeyLabels = {}

local prevAnchor = nil

local function RebuildPartyButtons()
    -- Remove old buttons
    for _, btn in ipairs(partyKeyButtons) do btn:Hide() btn:SetParent(nil) end
    for _, lbl in ipairs(partyKeyLabels) do lbl:Hide() end

    partyKeyButtons = {}
    partyKeyLabels = {}

    local rowHeight = 24
    local count = 0

    local allKeys = {}

    local myKeystone = GetPlayerKeystone()
    if myKeystone then
        table.insert(allKeys, {
            playerName  = UnitName("player"),
            activityID  = myKeystone.activityID,
            level       = myKeystone.level,
            dungeonName = myKeystone.dungeonName,
        })
    end

    for playerName, keyData in pairs(partyKeys) do
        table.insert(allKeys, {
            playerName = Ambiguate(playerName, "short"),
            activityID = keyData.activityID,
            level = keyData.level,
            dungeonName = keyData.dungeonName
        })
    end

    for _, keyData in ipairs(allKeys) do
        count = count + 1

        local lbl = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lbl:SetHeight(rowHeight)
        if count == 1 then
            lbl:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, 0)
        else
            lbl:SetPoint("TOPLEFT", prevAnchor, "BOTTOMLEFT", 0, 0)
        end
        lbl:SetText(ButtonText(keyData))

        local btn = CreateFrame("Button", addonName .. "PartyBtn" .. count, panel, "UIPanelButtonTemplate")
        btn:SetSize(40, 22)
        btn:SetPoint("RIGHT", panel, "RIGHT", -8, 0)
        btn:SetPoint("TOP", lbl, "TOP", 0, 0)
        btn:SetText("List")
        btn:Disable()

        btn:SetScript("OnClick", function()
            C_LFGList.CreateListing({
                activityIDs = { keyData.activityID },
                generalPlaystyle = 2,
            })
        end)

        btn:Show()
        partyKeyButtons[count] = btn
        partyKeyLabels[count] = lbl
        prevAnchor = lbl
    end

    -- Resize panel to fit all buttons
    local totalHeight = (count * rowHeight)  -- top padding + own button + party buttons
    panel:SetSize(panelWidth, totalHeight)
end

-- ============================================================
-- Event Handling
-- ============================================================

local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("GROUP_ROSTER_UPDATE")

f:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender = ...
        if prefix ~= COMM_PREFIX then return end

        -- Strip realm from sender so we have a clean name for display
        local senderName = Ambiguate(sender, "none")

        if text == "REQUEST" then
            -- A party member is asking for everyone's key — send ours
            BroadcastMyKey()

        elseif text:match("^KEY ") then
            local activityID, level, dungeonName = text:match("^KEY (%d+) (%d+) (.+)$")
            if activityID and level and dungeonName then
                partyKeys[senderName] = {
                    activityID  = tonumber(activityID),
                    level       = tonumber(level),
                    dungeonName = dungeonName,
                }
                RebuildPartyButtons()
            end
        end

    elseif event == "GROUP_ROSTER_UPDATE" then
        -- Clear keys for players who left the party
        for name in pairs(partyKeys) do
            local found = false
            for i = 1, GetNumGroupMembers() do
                local unit = "party" .. i
                if UnitName(unit) == name then
                    found = true
                    break
                end
            end
            if not found then
                partyKeys[name] = nil
            end
        end
        RebuildPartyButtons()
    end
end)

local function UpdateButtonState()
    local allKeys = {}
    local myKeystone = GetPlayerKeystone()

    if myKeystone then
        table.insert(allKeys, {
            playerName  = UnitName("player"),
            activityID  = myKeystone.activityID,
            level       = myKeystone.level,
            dungeonName = myKeystone.dungeonName,
        })
    end

    for playerName, keyData in pairs(partyKeys) do
        table.insert(allKeys, {
            playerName = Ambiguate(playerName, "short"),
            activityID = keyData.activityID,
            level = keyData.level,
            dungeonName = keyData.dungeonName
        })
    end

    for i, keyData in ipairs(allKeys) do
        local currentName = LFGListFrame.EntryCreation.Name:GetText()

        if currentName:find("%f[%d]" .. keyData.level .. "%f[%D]") then
            partyKeyButtons[i]:Enable()
        else
            partyKeyButtons[i]:Disable()
        end
    end
end

-- ============================================================
-- Show / hide the panel with PVEFrame
-- ============================================================

LFGListFrame.EntryCreation:HookScript("OnShow", function()
    RebuildPartyButtons()
    RequestPartyKeys()
    panel:Show()
    UpdateButtonState()
end)

LFGListFrame.EntryCreation:HookScript("OnHide", function()
    panel:Hide()
end)

PVEFrame:HookScript("OnHide", function()
    panel:Hide()
end)

local frame = LFGListFrame.EntryCreation.Name
frame:HookScript("OnTextChanged", function(self, isUserInput)
    UpdateButtonState()
end)
