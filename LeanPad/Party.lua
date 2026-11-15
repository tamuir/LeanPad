local _, ns = ...

-- Party targeting: while the Layer 3 button (Alt) is held, four directions are Blizzard's Target Party Member 1-4
-- and one more press is Target Self. These are plain saved bindings, so they work in combat with no secure code of
-- LeanPad's. The ring names who is where while the button is held. A unit's name may be secret in combat, so it
-- goes straight to SetText and is never read, and nothing here asks which member is the target.
local COMMANDS = { "TARGETPARTYMEMBER1", "TARGETPARTYMEMBER2", "TARGETPARTYMEMBER3", "TARGETPARTYMEMBER4", "TARGETSELF" }
-- Up, right, down, left, then the press that is the player: the right stick and its click, or the D-pad and A.
local STYLES = {
	ring = { "PADRSTICKUP", "PADRSTICKRIGHT", "PADRSTICKDOWN", "PADRSTICKLEFT", "PADRSTICK" },
	dpad = { "PADDUP", "PADDRIGHT", "PADDDOWN", "PADDLEFT", "PAD1" },
}
local UNITS = { "party1", "party2", "party3", "party4", "player" }
-- Each name's place around the ring's centre: its own point, the ring's point, then the offset.
local PLACES = { { "BOTTOM", "TOP", 0, 6 }, { "LEFT", "RIGHT", 6, 0 }, { "TOP", "BOTTOM", 0, -6 }, { "RIGHT", "LEFT", -6, 0 }, { "CENTER", "CENTER", 0, 0 } }

-- Binds a style's five presses, or none for "off", clearing what either style bound before. The stick's four
-- directions are keys only while GamePadStickAxisButtons is on.
-- shortcut: off leaves GamePadStickAxisButtons on, as it may have been the player's own; put it back if it bites.
function ns.SetupParty(style)
	local keys = STYLES[style]
	if not keys and style ~= "off" then return print("LeanPad: type /lp party ring, /lp party dpad or /lp party off.") end
	ns.OutOfCombat(function()
		for _, old in pairs(STYLES) do
			for i, key in ipairs(old) do
				if GetBindingAction("ALT-" .. key) == COMMANDS[i] then ns.BindKey("ALT-" .. key, "") end
			end
		end
		for i, key in ipairs(keys or {}) do ns.BindKey("ALT-" .. key, COMMANDS[i]) end
		if style == "ring" then SetCVar("GamePadStickAxisButtons", "1") end
		ns.SaveBindings()
		if not keys then return print("LeanPad: party targeting is off.") end
		print(("LeanPad: party targeting is on the %s. Hold the Layer 3 button and press a direction."):format(style == "ring" and "right stick" or "D-pad"))
		if ns.LayerButtonKey("GamePadEmulateAlt") == "none" then print("LeanPad: no button is Layer 3 yet. Choose one in /lp settings.") end
	end)
end

-- The style bound now, read from the bindings so the settings page and the ring follow whatever set them.
function ns.PartyStyle()
	for style, keys in pairs(STYLES) do
		if GetBindingAction("ALT-" .. keys[1]) == COMMANDS[1] then return style end
	end
	return "off"
end

local ring
local function build()
	ring = CreateFrame("Frame", "LeanPadPartyRing", UIParent)
	ring:SetSize(110, 110)
	ring:SetPoint("CENTER")
	ring:SetFrameStrata("HIGH")
	ring.names = {}
	for i, place in ipairs(PLACES) do
		local name = ns.Panel(ring, ns.COLORS.bg, i == 5 and ns.COLORS.edge or ns.COLORS.accent)
		name:SetSize(120, 26)
		name:SetPoint(place[1], ring, place[2], place[3], place[4])
		name.Text = ns.Text(name, 15, ns.COLORS.text, "CENTER")
		name.Text:SetPoint("LEFT", 6, 0)
		name.Text:SetPoint("RIGHT", -6, 0)
		name.Text:SetWordWrap(false)
		ring.names[i] = name
	end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("MODIFIER_STATE_CHANGED")
watcher:SetScript("OnEvent", function()
	if not (IsAltKeyDown() and IsInGroup() and ns.PartyStyle() ~= "off") then
		if ring then ring:Hide() end
		return
	end
	if not ring then build() end
	for i, name in ipairs(ring.names) do
		name:SetShown(UnitExists(UNITS[i]))
		name.Text:SetText((UnitName(UNITS[i])))
	end
	ring:Show()
end)
