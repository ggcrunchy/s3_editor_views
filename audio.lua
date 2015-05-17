--- Game audio editing components.

--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
--

-- Music

-- Song???

-- Could add sound effects, other music with event_target tags

-- ^^ Wrap up audio stuff from this module into "music" object?
-- ^^ Then use in game, hook up here in editor to events

-- Standard library imports --
local pairs = pairs

-- Modules --
local checkbox = require("corona_ui.widgets.checkbox")
local common_ui = require("s3_editor.CommonUI")
local dialog = require("s3_editor.Dialog")
local editable = require("corona_ui.patterns.editable")
local events = require("s3_editor.Events")
local help = require("s3_editor.Help")
local layout = require("corona_ui.utils.layout")
local list_views = require("s3_editor.ListViews")
local music = require("s3_utils.music")
local sound = require("s3_utils.sound")

-- Corona globals --
local display = display
local native = native

-- Exports --
local M = {}

-- --
local Group

-- --
local MusicDialog = dialog.DialogWrapper(music.EditorEvent)
local SoundDialog = dialog.DialogWrapper(sound.EditorEvent)

-- --
local MusicView = list_views.EditErase(MusicDialog, "music")
local SoundView = list_views.EditErase(SoundDialog, "sound")

--
local function List (str, prefix, view, top, r, g, b)
	local text = display.newText(Group, str, 0, 0, native.systemFont, 24)

	layout.PutRightOf(text, 125)
	layout.PutBelow(text, top)

	local list, bottom = view:Load(Group, prefix, layout.Below(text), layout.LeftOf(text))

	common_ui.Frame(list, r, g, b)

	return list, bottom
end

-- --
local Enter, Reset

-- --
local PlayOnEnter, PlayOnReset
-- ^^^ TODO: Maybe these names are backward, intuition-wise

---
-- @pgroup view X
function M.Load (view)
	--
	Group = display.newGroup()

	--
	local music_list, mbot = List("Music tracks", "music", MusicView, 80, 0, 0, 1)
	local sound_list, sbot = List("Sound samples", "sound", SoundView, mbot + 15, 0, 1, 0)

	--
	Enter = checkbox.Checkbox(Group, 40, 40)

	Enter:Check(true)

	layout.PutBelow(Enter, sbot, 10)
	layout.LeftAlignWith(Enter, sound_list)

	local enter_str = display.newText(Group, "Play on enter?", 0, Enter.y, native.systemFontBold, 22)

	layout.PutRightOf(enter_str, Enter, 5)

	PlayOnEnter = editable.Editable_XY(Group, 0, Enter.y)

	layout.PutRightOf(PlayOnEnter, enter_str, 5)

	Reset = checkbox.Checkbox_XY(Group, 0, Enter.y, 40, 40)

	Reset:Check(true)

	layout.PutRightOf(Reset, PlayOnEnter, 15)

	local reset_str = display.newText(Group, "Reset track?", 0, Enter.y, native.systemFontBold, 22)

	layout.PutRightOf(reset_str, Reset, 5)

	PlayOnReset = editable.Editable_XY(Group, 0, Enter.y)

	layout.PutRightOf(PlayOnReset, reset_str, 5)

	--
	Group.isVisible = false

	view:insert(Group)

	--
	help.AddHelp("Audio", {
		music = music_list, sound = sound_list,
		enter = Enter, play_on_enter = PlayOnEnter,
		reset = Reset, play_on_reset = PlayOnReset
	})
	help.AddHelp("Audio", {
		music = "Add or remove music tracks.",
		sound = "Add or remove sound samples.",
		enter = "Should music play as soon as the level is entered?",
		play_on_enter = "If music should play when entering the level, the name of the track to play. " ..
						"(This is optional when there is only one track.)",
		reset = "When the level is reset, should a new track play?",
		play_on_reset = "If new music should play when the level is reset, the name of the track to " ..
						"play. (If absent, the level-entering track is used.)"
	})
end

---
-- @pgroup view X
function M.Enter (view)
	Group.isVisible = true

	MusicView:Enter(view)
	SoundView:Enter(view)

	help.SetContext("Audio")
end

--- DOCMAYBE
function M.Exit ()
	MusicView:Exit()
	SoundView:Exit()

	Group.isVisible = false
end

--- DOCMAYBE
function M.Unload ()
	MusicView:Unload()
	SoundView:Unload()

	Enter, Group, PlayOnEnter, PlayOnReset, Reset = nil
end

--
local function CheckNameIntegrity (verify, list, editable, what)
	local n, name = list:GetCount(), editable:GetString().text

	if n == 0 then
		verify[#verify + 1] = ("No music available for `%s` to reference"):format(what)
	elseif name ~= "" then
		for i = 1, n do
			if list:GetData(i).filename == name then
				return
			end
		end

		verify[#verify + 1] = ("No music with filename `%s` available to associate with `%s`"):format(name, what)
	elseif n > 1 then
		verify[#verify + 1] = ("Multiple pieces of music to associate with `%s`, but none specified"):format(what)
	end
end

--
local function AddFlag (music, name, flag)
	if name and music then
		local index = 1

		if name ~= "" then
			while music[index].filename ~= name do
				index = index + 1
			end
		end

		music[index][flag] = true
	end
end

-- Listen to events.
for k, v in pairs{
	-- Build Level --
	build_level = function(level)
		--
		local state, music_builds, sound_builds = level.music_state

		for _, mentry in pairs(level.music.entries) do
			music_builds = events.BuildEntry(level, music, mentry, music_builds)
		end

		for _, sentry in pairs(level.sound.entries) do
			sound_builds = events.BuildEntry(level, sound, sentry, sound_builds)
		end

		level.music, level.sound, level.music_state = music_builds, sound_builds

		--
		AddFlag(music_builds, state.enter and state.play_on_enter, "play_on_enter")
		AddFlag(music_builds, state.reset and state.play_on_reset, "play_on_reset")
	end,

	-- Load Level WIP --
	load_level_wip = function(level)
		events.LoadGroupOfValues_List(level, "music", music, MusicView)
		events.LoadGroupOfValues_List(level, "sound", sound, SoundView)

		local state = level.music_state

		Enter:Check(state.enter)
		Reset:Check(state.reset)

		PlayOnEnter:SetText(state.play_on_enter)
		PlayOnReset:SetText(state.play_on_reset)
	end,

	-- Save Level WIP --
	save_level_wip = function(level)
		events.SaveGroupOfValues(level, "music", music, MusicView)
		events.SaveGroupOfValues(level, "sound", sound, SoundView)

		level.music_state = {
			enter = Enter:IsChecked(), play_on_enter = PlayOnEnter:GetString().text,
			reset = Reset:IsChecked(), play_on_reset = PlayOnReset:GetString().text
		}
	end,

	-- Verify Level WIP --
	verify_level_wip = function(verify)
		if verify.pass == 1 then
			events.CheckNamesInValues("music", verify, MusicView)
			events.CheckNamesInValues("sound", verify, SoundView)

			-- Make sure any name lookups are intact.
			local music_list = MusicView:GetListbox()

			if Enter:IsChecked() then
				CheckNameIntegrity(verify, music_list, PlayOnEnter, "play on enter")
			end

			if Reset:IsChecked() then
				CheckNameIntegrity(verify, music_list, PlayOnReset, "play on reset")
			end
		end

		events.VerifyValues(verify, music, MusicView)
		events.VerifyValues(verify, sound, SoundView)
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M