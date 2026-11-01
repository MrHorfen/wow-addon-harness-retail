--[[
  AHProbe / Core/Probe.lua

  Data layer. Pure behavior: ask the adapter for a browse query, then read the
  result count. It never touches raw APIs and never builds UI.
]]

local ADDON_NAME, ns = ...

local Env = ns.Env
local Probe = {}
ns.Probe = Probe

Probe.count = 0

function Probe:Scan()
  if not Env.IsAuctionOpen() then
    ns.Print(ns.Lang("OPEN_AH"))
    return false
  end

  if not Env.CanBrowse() then
    ns.Print(ns.Lang("THROTTLED"))
    return false
  end

  local ok, err = Env.QueryBrowse()
  if not ok then
    ns.Print(string.format(ns.Lang("QUERY_FAILED"), tostring(err or "unknown")))
    return false
  end

  ns.Print(string.format(ns.Lang("QUERY_SENT"), Env.Flavor()))
  return true
end

function Probe:OnBrowseUpdate()
  self.count = Env.GetBrowseCount()
  if ns.UI and ns.UI.Refresh then
    ns.UI.Refresh()
  end
end
