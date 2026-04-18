-- EquiFastJoin: Locales
local _, EFJ = ...

local locale = GetLocale()
local L = setmetatable({}, {
  __index = function(_, key) return key end
})
-- enUS: keys ARE the English strings; metatable __index returns key as-is.
-- deDE overrides:
if locale == "deDE" then
  -- Button labels
  L["Join"]       = "Beitreten"
  L["Leave"]      = "Abmelden"
  L["Invited"]    = "Eingeladen"
  L["Left"]       = "Abgemeldet"
  L["Not in LFG"] = "Nicht LFG"
  L["OK"]         = "OK"
  -- Activity text
  L["Quick Join"]          = "Schnellbeitritt"
  L["Unknown Activity"]    = "Unbekannte Aktivität"
  L["New Entry"]           = "Neuer Eintrag"
  -- Banner / test
  L["New Quick Join suggestions available."] = "Es sind neue Schnellbeitritt-Vorschläge verfügbar."
  L["This is a test entry."]                 = "Dies ist ein Testeintrag."
  -- Error messages
  L["EFJ: Join blocked in combat"]    = "EFJ: Beitritt im Kampf gesperrt"
  L["EFJ: Application failed"]        = "EFJ: Bewerbung fehlgeschlagen"
  L["EFJ: Action blocked (Taint)"]    = "EFJ: Aktion blockiert (Taint)"
  L["EFJ: Leave blocked in combat"]   = "EFJ: Abmelden im Kampf gesperrt"
  L["EFJ: Leave failed"]              = "EFJ: Abmelden fehlgeschlagen"
  L["EFJ: Not available in combat"]   = "EFJ: Nicht im Kampf verfügbar"
  L["EFJ: Options blocked in combat"] = "EFJ: Optionen im Kampf gesperrt"
  -- Options panel title
  L["EquiFastJoin Options"]                  = "EquiFastJoin Optionen"
  -- Filter checkboxes (label, tooltip)
  L["Show Dungeons"]                         = "Dungeons anzeigen"
  L["Show dungeons"]                         = "Zeigt Dungeon-Gruppen"
  L["Show Raids"]                            = "Raids/Schlachtzüge anzeigen"
  L["Show raids"]                            = "Zeigt Raid-Gruppen"
  L["Show Mythic+"]                          = "Mythic+ anzeigen"
  L["Show M+ groups"]                        = "Zeigt M+ Gruppen"
  L["Show PvP"]                              = "PvP anzeigen"
  L["Show PvP groups"]                       = "Zeigt PvP-Gruppen"
  L["Show Custom/Quest"]                     = "Benutzerdefiniert/Quest anzeigen"
  L["Show custom/quest groups"]              = "Zeigt benutzerdefinierte/Quest-Gruppen"
  L["Auto-open on Quick Join"]               = "Bei Schnellbeitritt auto-öffnen"
  L["Opens list on Quick Join suggestions"]  = "Öffnet Liste bei QuickJoin Vorschlägen"
  L["Play Sound"]                            = "Sound abspielen"
  L["Plays a short sound on open"]           = "Spielt einen kurzen Sound beim Öffnen"
  L["Toast Message"]                         = "Toast Nachricht"
  L["Shows a RaidWarning toast"]             = "Zeigt eine RaidWarning Toast"
  L["Lock Frame"]                            = "Rahmen sperren"
  L["Prevents moving the window"]            = "Verhindert Verschieben des Fensters"
  L["Scale"]                                 = "Skalierung"
  -- Buttons
  L["Test Window"]                           = "Testfenster"
  L["Refresh Now"]                           = "Jetzt aktualisieren"
end

EFJ.L = L
