--[[
  AHProbe / UI/Main.lua

  Presentation layer. Builds widgets, forwards clicks, formats text.
  It calls ns.Probe / ns.Env and never contains business decisions.
]]

local ADDON_NAME, ns = ...

local UI = {}
ns.UI = UI
local frame

local function Build()
  local f = _G.CreateFrame("Frame", "AHProbeFrame", _G.UIParent, "BackdropTemplate")
  f:SetSize(380, 150)
  f:SetPoint("CENTER")
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetClampedToScreen(true)
  f:Hide()

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOP", 0, -14)
  title:SetText(ns.Lang("TITLE"))

  local mode = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  mode:SetPoint("TOP", 0, -38)
  mode:SetText(ns.Lang("MODE") .. ": " .. ns.Lang("RETAIL"))

  local count = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  count:SetPoint("TOP", 0, -60)
  count:SetText(ns.Lang("AUCTIONS") .. ": 0")

  local button = _G.CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  button:SetSize(110, 24)
  button:SetPoint("BOTTOM", 0, 18)
  button:SetText(ns.Lang("SCAN"))
  button:SetScript("OnClick", function()
    ns.Probe:Scan()
  end)

  f.countLabel = count
  return f
end

function UI.Show()
  if not frame then
    frame = Build()
  end
  frame:Show()
end

function UI.Refresh()
  if frame and frame.countLabel then
    frame.countLabel:SetText(
      ns.Lang("AUCTIONS") .. ": " .. tostring(ns.Probe.count or 0)
    )
  end
end

local loader = _G.CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    _G.AHProbeDB = _G.AHProbeDB or {}
    ns.Env.RegisterAHEvents(self, "browse")
    ns.Env.RegisterAHEvents(self, "ah")
  elseif event == "PLAYER_LOGIN" then
    UI.Show()
    UI.Refresh()
  elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED"
      or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED"
      or event == "AUCTION_HOUSE_BROWSE_FAILURE" then
    ns.Probe:OnBrowseUpdate()
  end
end)

_G.SLASH_AHPROBE1 = "/ahprobe"
_G.SlashCmdList["AHPROBE"] = function(message)
  message = string.lower(message or "")
  if message == "scan" then
    ns.Probe:Scan()
  else
    UI.Show()
  end
end
