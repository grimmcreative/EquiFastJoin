-- EquiFastJoin: Core
local _, EFJ = ...

local L = EFJ.L

EFJ.State = EFJ.State or { applications = {} }

local DEFAULTS = {
  debug = false,
  lastDismissSignature = "",
  scale = 1.0,
  lockFrame = false,
  width = 400,
  height = 300,
  point = "CENTER",
  rel = "CENTER",
  x = 0, y = 0,
  -- Filters & UX
  showRaids = true,
  showDungeons = true,
  showMythicPlus = true,
  showPvP = false,
  showCustom = true,
  openOnQuickJoin = true,
  playSound = false,
  showToast = true,
}
EFJ.DEFAULTS = DEFAULTS

local function CopyDefaults(dst, src)
  for k,v in pairs(src) do
    if type(v)=="table" then
      dst[k] = dst[k] or {}
      CopyDefaults(dst[k], v)
    elseif dst[k]==nil then
      dst[k]=v
    end
  end
end
EFJ.CopyDefaults = CopyDefaults

local function DBG(...)
  if EquiFastJoinDB and EquiFastJoinDB.debug then
    print("|cff33ff99[EFJ]|r", ...)
  end
end
EFJ.DBG = DBG
