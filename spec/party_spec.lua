local wow = require("spec.wow")

describe("Party targeting", function()
	local ns, w

	local function held(modifier, down)
		w.held[modifier] = down
		for _, widget in ipairs(w.widgets) do
			if widget.events.MODIFIER_STATE_CHANGED and widget.scripts.OnEvent then widget.scripts.OnEvent(widget, "MODIFIER_STATE_CHANGED") end
		end
	end

	local function altChanged(down) held("alt", down) end

	local function shownNames()
		local names = {}
		for i, name in ipairs(LeanPadPartyRing.names) do names[i] = name:IsShown() and name.Text.text or false end
		return names
	end

	before_each(function()
		ns, w = wow.boot({ prompted = true })
		w.cvars.GamePadEmulateAlt = "PADRSHOULDER"
	end)
	after_each(wow.restore)

	it("puts the party on the right stick while Layer 3 is held, as saved bindings", function()
		SlashCmdList.LEANPAD("party ring")
		assert.equal("TARGETPARTYMEMBER1", w.bindings["ALT-PADRSTICKUP"])
		assert.equal("TARGETPARTYMEMBER2", w.bindings["ALT-PADRSTICKRIGHT"])
		assert.equal("TARGETPARTYMEMBER3", w.bindings["ALT-PADRSTICKDOWN"])
		assert.equal("TARGETPARTYMEMBER4", w.bindings["ALT-PADRSTICKLEFT"])
		assert.equal("TARGETSELF", w.bindings["ALT-PADRSTICK"])
		assert.equal("1", w.cvars.GamePadStickAxisButtons)
		assert.same({ 1 }, w.saved)
		assert.same({ "LeanPad: party targeting is on the right stick. Hold the Layer 3 button and press a direction." }, w.printed)
	end)

	it("moves it to the D-pad, and says when no button is Layer 3", function()
		SlashCmdList.LEANPAD("party ring")
		w.cvars.GamePadEmulateAlt, w.printed = nil, {}
		SlashCmdList.LEANPAD("party dpad")
		assert.is_nil(w.bindings["ALT-PADRSTICKUP"])
		assert.is_nil(w.bindings["ALT-PADRSTICK"])
		assert.equal("TARGETPARTYMEMBER1", w.bindings["ALT-PADDUP"])
		assert.equal("TARGETSELF", w.bindings["ALT-PAD1"])
		assert.same({
			"LeanPad: party targeting is on the D-pad. Hold the Layer 3 button and press a direction.",
			"LeanPad: no button is Layer 3 yet. Choose one in /lp settings.",
		}, w.printed)
	end)

	it("turns off, leaving the player's other Layer 3 bindings alone", function()
		SlashCmdList.LEANPAD("party dpad")
		w.bindings["ALT-PADDRIGHT"] = "JUMP"
		w.printed = {}
		SlashCmdList.LEANPAD("party off")
		assert.is_nil(w.bindings["ALT-PADDUP"])
		assert.equal("JUMP", w.bindings["ALT-PADDRIGHT"])
		assert.same({ "LeanPad: party targeting is off." }, w.printed)
	end)

	it("says how to use the command when it isn't one of the three", function()
		SlashCmdList.LEANPAD("party")
		assert.same({ "LeanPad: type /lp party ring, /lp party dpad or /lp party off." }, w.printed)
		assert.same({}, w.saved)
	end)

	it("waits for combat to end", function()
		w.combat = true
		SlashCmdList.LEANPAD("party ring")
		assert.is_nil(w.bindings["ALT-PADRSTICKUP"])
		w.combat = false
		wow.fire("PLAYER_REGEN_ENABLED")
		assert.equal("TARGETPARTYMEMBER1", w.bindings["ALT-PADRSTICKUP"])
	end)

	describe("ring", function()
		before_each(function()
			SlashCmdList.LEANPAD("party ring")
			w.group = { player = "Bear", party1 = "Thornwall", party2 = "Kessa", party4 = "Vael" }
		end)

		it("names who is where while Layer 3 is held, and only then", function()
			assert.is_nil(LeanPadPartyRing)
			altChanged(false)
			assert.is_nil(LeanPadPartyRing)
			altChanged(true)
			assert.is_true(LeanPadPartyRing:IsShown())
			assert.same({ "Thornwall", "Kessa", false, "Vael", "Bear" }, shownNames())
			assert.same({ "BOTTOM", LeanPadPartyRing, "TOP", 0, 6 }, LeanPadPartyRing.names[1].point)
			altChanged(false)
			assert.is_false(LeanPadPartyRing:IsShown())
		end)

		it("follows the group as it changes between holds", function()
			altChanged(true)
			altChanged(false)
			w.group.party3 = "Odrin"
			altChanged(true)
			assert.same({ "Thornwall", "Kessa", "Odrin", "Vael", "Bear" }, shownNames())
		end)

		it("follows the buttons the player chose, on whichever layer they are", function()
			SlashCmdList.LEANPAD("party off")
			w.bindings["CTRL-PADPADDLE1"], w.bindings["ALT-CTRL-PADPADDLE2"] = "TARGETPARTYMEMBER2", "TARGETPARTYMEMBER1"
			altChanged(true)
			assert.is_nil(LeanPadPartyRing)
			altChanged(false)
			held("ctrl", true)
			assert.same({ false, "Kessa", false, false, false }, shownNames())
			held("ctrl", false)
			assert.is_false(LeanPadPartyRing:IsShown())
		end)

		it("shows each button's glyph beside the name", function()
			w.glyphs.PADRSTICKUP = "|A:Gen_RStickUp:14:14|a"
			altChanged(true)
			assert.equal("|A:Gen_RStickUp:18:18|a Thornwall", LeanPadPartyRing.names[1].Text.text)
		end)

		it("stays away outside a group", function()
			w.group = nil
			altChanged(true)
			assert.is_nil(LeanPadPartyRing)
		end)

		it("stays away once party targeting is off", function()
			SlashCmdList.LEANPAD("party off")
			altChanged(true)
			assert.is_nil(LeanPadPartyRing)
		end)
	end)
end)
