local fontName = "Interface\\AddOns\\dmg\\font.ttf"
local fontHeight = 40
local fFlags = ""

local function FS_SetFont()
	DAMAGE_TEXT_FONT = fontName
	COMBAT_TEXT_HEIGHT = fontHeight
	COMBAT_TEXT_CRIT_MAXHEIGHT = fontHeight + 10
	COMBAT_TEXT_CRIT_MINHEIGHT = fontHeight - 10
	if CombatTextFont then
		local fName, fHeight, fFlags = CombatTextFont:GetFont()
		CombatTextFont:SetFont(fontName, fontHeight, fFlags)
	end
end

-- Apply once immediately (as before), so nothing changes for the normal case
FS_SetFont()

-- From here on: keep re-asserting our font so addons that apply their
-- own font settings later (e.g. pfUI on PLAYER_LOGIN / PLAYER_ENTERING_WORLD
-- or after their own delayed init) can never overwrite dmg permanently.

local dmgFrame = CreateFrame("Frame", "dmg_EnforceFrame")
dmgFrame:RegisterEvent("PLAYER_LOGIN")
dmgFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
dmgFrame:RegisterEvent("ADDON_LOADED")

-- Additionally, re-apply repeatedly for a while after login/world-enter.
-- This catches addons (like pfUI) that apply their font settings on a
-- delay (e.g. after their own OnUpdate-based init or profile load),
-- which would otherwise win the "last write wins" race.
local enforceDuration = 15   -- seconds to keep enforcing after entering world
local enforceInterval = 0.5  -- how often to reapply during that window
local elapsedSinceStart = 0
local elapsedSinceTick = 0
local enforcing = false

dmgFrame:SetScript("OnEvent", function()
	FS_SetFont()
	-- (re)start the enforcement window
	enforcing = true
	elapsedSinceStart = 0
	elapsedSinceTick = 0
end)

dmgFrame:SetScript("OnUpdate", function()
	if not enforcing then return end

	-- Vanilla 1.12: elapsed time comes from the global arg1, not a function parameter
	local elapsed = arg1 or 0

	elapsedSinceStart = elapsedSinceStart + elapsed
	elapsedSinceTick = elapsedSinceTick + elapsed

	if elapsedSinceTick >= enforceInterval then
		elapsedSinceTick = 0
		FS_SetFont()
	end

	if elapsedSinceStart >= enforceDuration then
		enforcing = false
	end
end)
