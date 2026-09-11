local fontName = "Interface\\AddOns\\dmg\\font.ttf"
local fontHeight = 40

local applying = false
local function FS_SetFont()
	if applying then return end
	applying = true
	DAMAGE_TEXT_FONT = fontName
	COMBAT_TEXT_HEIGHT = fontHeight
	COMBAT_TEXT_CRIT_MAXHEIGHT = fontHeight + 10
	COMBAT_TEXT_CRIT_MINHEIGHT = fontHeight - 10
	if CombatTextFont then
		local _, _, fFlags = CombatTextFont:GetFont()
		CombatTextFont:SetFont(fontName, fontHeight, fFlags)
	end
	applying = false
end

-- Apply once immediately (as before), so nothing changes for the normal case
FS_SetFont()

-- Reported (2026-09-11): still overwritten on a brand new character, even
-- with the timed re-apply window below (added 2026-09-08 for the same
-- pfUI-overwrites-it problem). pfUI's own pfUI:UpdateFonts() runs on EVERY
-- ADDON_LOADED, not just once -- and on a fresh character it also has to do
-- first-time profile setup (CopyTable from the "Modern" profile,
-- LoadConfig, MigrateConfig), which can easily take longer than an
-- established character's login, outlasting a fixed enforcement window.
-- Timing-based re-assertion can only ever be a race with a guessed
-- deadline -- it will keep breaking whenever something else's init happens
-- to run slower than that guess.
--
-- Fix properly instead of guessing a longer timeout: hook
-- CombatTextFont:SetFont directly. Whenever ANYTHING changes the combat
-- text font -- pfUI on ADDON_LOADED, a delayed profile load, a first-run
-- wizard, any other addon, no matter how late -- reassert dmg's font
-- immediately right after. No timing assumption needed at all, so it can't
-- lose the race regardless of how slow another addon's init is.
local dmgFrame = CreateFrame("Frame", "dmg_EnforceFrame")
dmgFrame:RegisterEvent("PLAYER_LOGIN")
dmgFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
dmgFrame:RegisterEvent("ADDON_LOADED")

-- Kept as a defensive fallback alongside the hook below -- covers the
-- unlikely case of something setting DAMAGE_TEXT_FONT / COMBAT_TEXT_HEIGHT
-- directly (not through CombatTextFont:SetFont, so the hook wouldn't see
-- it), without depending on it being the only line of defense.
local enforceDuration = 15   -- seconds to keep enforcing after entering world
local enforceInterval = 0.5  -- how often to reapply during that window
local elapsedSinceStart = 0
local elapsedSinceTick = 0
local enforcing = false

local hooked = false
dmgFrame:SetScript("OnEvent", function()
	FS_SetFont()

	-- (re)start the enforcement window
	enforcing = true
	elapsedSinceStart = 0
	elapsedSinceTick = 0

	-- CombatTextFont is a Blizzard FrameXML font object; it should exist by
	-- PLAYER_LOGIN, but wasn't guaranteed to exist yet when this file's
	-- top-level code first ran (addon load order, before FrameXML is fully
	-- up) -- hence installing the hook here instead of at file scope, and
	-- only once.
	if not hooked and CombatTextFont then
		hooked = true
		hooksecurefunc(CombatTextFont, "SetFont", FS_SetFont)
	end
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
