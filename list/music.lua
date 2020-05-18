--- Music editing components.

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

-- Modules --
local checkbox = require("solar2d_ui.widgets.checkbox")
local editable = require("solar2d_ui.patterns.editable")
local editor_strings = require("config.EditorStrings")
local layout = require("solar2d_ui.utils.layout")
local layout_dsl = require("solar2d_ui.utils.layout_dsl")
local lists = require("s3_editor_views.lists")
local music = require("s3_utils.music")

-- Solar2D globals --
local display = display
local native = native

--
--
--

-- --
local Enter, Reset

-- --
local PlayOnEnter, PlayOnReset
-- ^^^ TODO: Maybe these names are backward, intuition-wise

local function CheckNameIntegrity (verify, list, editable, what)
	local n, name = list:GetCount(), editable:GetText()

	if n > 0 then
		if name ~= "" then
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
end

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

return lists.ListOfItemsMaker("music", music, {
	add_elements = function(group, list, bottom, _, help_context)
		Enter = checkbox.Checkbox(group, "5%", "8.33%")

		Enter:Check(true)
		help_context:Add(Enter, editor_strings("music_enter"))

		layout.PutBelow(Enter, bottom, "2.1%")
		layout.LeftAlignWith(Enter, list)

		local xsep, texth = layout_dsl.EvalDims(".625%", "4.6%")
		local enter_str = display.newText(group, "Play on enter?", 0, Enter.y, native.systemFontBold, texth)

		layout.PutRightOf(enter_str, Enter, xsep)

		PlayOnEnter = editable.Editable_XY(group, 0, Enter.y)
		help_context:Add(PlayOnEnter, editor_strings("music_play_on_enter"))

		layout.PutRightOf(PlayOnEnter, enter_str, xsep)

		Reset = checkbox.Checkbox_XY(group, 0, Enter.y, "5%", "8.3%")

		Reset:Check(true)
		help_context:Add(Reset, editor_strings("music_reset"))

		layout.PutRightOf(Reset, PlayOnEnter, xsep * 3)

		local reset_str = display.newText(group, "Reset track?", 0, Enter.y, native.systemFontBold, texth)

		layout.PutRightOf(reset_str, Reset, xsep)

		PlayOnReset = editable.Editable_XY(group, 0, Enter.y)
		help_context:Add(PlayOnReset, editor_strings("music_play_on_reset"))

		layout.PutRightOf(PlayOnReset, reset_str, xsep)

		return {
			enter = Enter, play_on_enter = PlayOnEnter,
			reset = Reset, play_on_reset = PlayOnReset
		}
	end,

	build_level = function(level, builds)
		local state = level.music_state

		level.music_state = nil

		AddFlag(builds, state.enter and state.play_on_enter, "play_on_enter")
		AddFlag(builds, state.reset and state.play_on_reset, "play_on_reset")
	end,

	load_level_wip = function(level)
		local state = level.music_state

		Enter:Check(state.enter)
		Reset:Check(state.reset)

		PlayOnEnter:SetText(state.play_on_enter)
		PlayOnReset:SetText(state.play_on_reset)
	end,

	save_level_wip = function(level)
		level.music_state = {
			enter = Enter:IsChecked(), play_on_enter = PlayOnEnter:GetText(),
			reset = Reset:IsChecked(), play_on_reset = PlayOnReset:GetText()
		}
	end,

	text = "Music tracks",

	unload = function()
		Enter, PlayOnEnter, PlayOnReset, Reset = nil
	end,

	verify_level_wip = function(verify, music_view)
		if verify.pass == 1 then
			local music_list = music_view:GetListbox()

			if Enter:IsChecked() then
				CheckNameIntegrity(verify, music_list, PlayOnEnter, "play on enter")
			end

			if Reset:IsChecked() then
				CheckNameIntegrity(verify, music_list, PlayOnReset, "play on reset")
			end
		end
	end
})