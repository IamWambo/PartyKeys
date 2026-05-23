--- Util functions

function PKPrint(msg)
    print("[PartyKeys] " .. msg)
end

-- ============================================================
-- Dungeon Name Abbreviations
-- ============================================================

local DUNGEON_ABBREV = {
    ["Magisters' Terrace"] = "MT",
    ["Maisara Caverns"] = "MC",
    ["Nexus-Point Xenas"] = "XENAS",
    ["Windrunner Spire"] = "SPIRE",
    ["Algeth'ar Academy"] = "AA",
    ["Pit of Saron"] = "PIT",
    ["Seat of the Triumvirate"] = "SEAT",
    ["Skyreach"] = "SKY"
}

function ShortName(dungeonName)
    return DUNGEON_ABBREV[dungeonName] or dungeonName
end