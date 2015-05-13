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
local remove = table.remove
local tonumber = tonumber

-- Modules --
local button = require("corona_ui.widgets.button")
local checkbox = require("corona_ui.widgets.checkbox")
local common = require("s3_editor.Common")
local common_ui = require("s3_editor.CommonUI")
local dialog = require("s3_editor.Dialog")
local editable = require("corona_ui.patterns.editable")
local help = require("s3_editor.Help")
local layout = require("corona_ui.utils.layout")
local match_slot_id = require("tektite_core.array.match_slot_id")
local music = require("s3_utils.music")
local sound = require("s3_utils.sound")
local strings = require("tektite_core.var.strings")
local table_view_patterns = require("corona_ui.patterns.table_view")

-- Corona globals --
local display = display
local native = native

-- Corona modules --
local composer = require("composer")

-- Exports --
local M = {}

-- --
local MusicDialog = dialog.DialogWrapper(music.EditorEvent)
local SoundDialog = dialog.DialogWrapper(sound.EditorEvent)

-- --
local Group

--
local function List (str, action, top, r, g, b)
	local text = display.newText(Group, str, 0, 0, native.systemFont, 24)
	local using, items = match_slot_id.Wrap{}
	local list = table_view_patterns.Listbox(Group, {
		width = "30%", height = "15%",

		--
		press = function(event)
			action("update", using, event.index)
		end
	})

	layout.PutRightOf(text, 125)
	layout.PutBelow(text, top)
	layout.LeftAlignWith(list, text)
	layout.PutBelow(list, text)
	common_ui.Frame(list, r, g, b)

	local new = button.Button_XY(Group, 0, 0, 110, 40, function()
		action("new", using, list)
	end, "New")

	layout.LeftAlignWith(new, list)
	layout.PutBelow(new, list, 10)

	local delete = button.Button_XY(Group, 0, new.y, new.width, new.height, function()
		local index = list:FindSelection()

		if index then
			remove(items, index)
			action("delete", using, list, index)
		end
	end, "Delete")

	layout.PutRightOf(delete, new, 10)

	return list, items, layout.Below(new)
end

--
local function GetName (using, prefix)
	using("begin_generation")

	local items = using("get_array")
	local n = #items

	for i = 1, n do
		local begins, suffix = strings.BeginsWith_AnyCase(items[i].name, prefix, true)
		local index = begins and tonumber(suffix)

		if index then
			using("mark", index)
		end
	end

	for i = 1, n do
		if not using("check", i) then
			return prefix .. i
		end
	end

	return prefix .. (n + 1)
end

--
local function AddListbox (listbox_str, choose_str, mode, new, y, r, g, b)
	local props, params = display.newGroup(), { mode = mode }
	local name = editable.Editable(props)
	local filename = button.Button(props, 240, 40, function()
		composer.showOverlay("s3_editor.overlay.ChooseAudio", { params = params })
	end, choose_str)

	local list, items, bottom = List(listbox_str, function(what, using, arg1, arg2)
		local items = using("get_array")

		if what == "update" then
			props.isVisible = true

			name:SetText(items[arg1].name)
		elseif what == "new" then
			local item = {}

			new(item, using)

			items[#items + 1] = item

			arg1:Append(item.name)
		elseif what == "delete" then
			props.isVisible = #items > 0

			arg1:Delete(arg2)
		end

		if what ~= "update" then
			common.Dirty()
		end
	end, y, r, g, b)

	name:addEventListener("closing", function(event)
		local old_text = list:GetSelection()
		local index = list:Find(old_text)

		if index and event.closed_by_key then
			local str = event.target:GetString().text

			items[index].name = str

			list:Update(index, str)

			common.Dirty()
		else
			event.target:SetText(old_text)
		end
	end)

	function params.assign (name)
		local index = list:FindSelection()

		if index then
			items[index].filename = name

			common.Dirty()
		end
	end

	layout.PutRightOf(name, list, 10)
	layout.TopAlignWith(name, list)
	layout.LeftAlignWith(filename, name)
	layout.PutBelow(filename, name, 10)

	props.isVisible = false

	Group:insert(props)

	return list, bottom
end

---
-- @pgroup view X
function M.Load (view)
	--
	Group = display.newGroup()

	-- music sidebar
	local music_list, mbot = AddListbox("Music tracks", "Choose track", "stream", function(item, using)
		item.name = GetName(using, "Music")
	end, 80, 0, 0, 1)
	local sound_list, sbot  = AddListbox("Sound samples", "Choose sample", "souond", function(item, using)
		item.name = GetName(using, "Sound")
	end, mbot + 15, 0, 1, 0)

	-- "Global" state:
		-- On enter level: play track (with "default" checked, or lone track); nothing
		-- On reset level: play enter track; reset current track; stop current track; nothing (what about sounds?)
		-- ^^^ These just hook up global events; for finer control, do manually

	--
	local enter = checkbox.Checkbox(Group, 40, 40)

	enter:Check(true)

	layout.PutBelow(enter, sbot, 10)
	layout.LeftAlignWith(enter, sound_list)

	local enter_str = display.newText(Group, "Play on enter?", 0, enter.y, native.systemFontBold, 22)

	layout.PutRightOf(enter_str, enter, 5)

	local play_on_enter = editable.Editable_XY(Group, 0, enter.y)

	layout.PutRightOf(play_on_enter, enter_str, 5)

	local reset = checkbox.Checkbox_XY(Group, 0, enter.y, 40, 40)

	reset:Check(true)

	layout.PutRightOf(reset, play_on_enter, 5)

	local reset_str = display.newText(Group, "Reset track?", 0, enter.y, native.systemFontBold, 22)

	layout.PutRightOf(reset_str, reset, 5)

	local play_on_reset = editable.Editable_XY(Group, 0, enter.y)

	layout.PutRightOf(play_on_reset, reset_str, 5)

	--
	Group.isVisible = false

	view:insert(Group)

	--
	help.AddHelp("Audio", {
		music = music_list, sound = sound_list,
		enter = enter, play_on_enter = play_on_enter,
		reset = reset, play_on_reset = play_on_reset
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

	help.SetContext("Audio")
end

--- DOCMAYBE
function M.Exit ()
	Group.isVisible = false
end

--- DOCMAYBE
function M.Unload ()
	Group = nil
end

-- Listen to events.
for k, v in pairs{
	-- Build Level --
	build_level = function(level)
		-- ??
--[[
		local builds

		for k, sp in pairs(level.enemies.entries) do
			sp.col, sp.row = strings.KeyToPair(k)

			builds = events.BuildEntry(level, enemies, sp, builds)
		end

		level.enemies = builds
]]
-- 		level.global_events = events.BuildEntry(level, global_events, level.global_events, nil)[1]
-- Probably, do two of the first sort of thing
	end,

	-- Load Level WIP --
	load_level_wip = function(level)
		level.ambience.version = nil

	--	SetCurrent(level.ambience.music)
--		events.LoadGroupOfValues_Grid(level, "enemies", enemies, GridView)
-- 		events.LoadValuesFromEntry(level, global_events, Global, level.global_events)
-- Probably need new "load group of values" variant
	end,

	-- Save Level WIP --
	save_level_wip = function(level)
	--	level.ambience = { version = 1, music = Current }
--		events.SaveGroupOfValues(level, "enemies", enemies, GridView)
--		level.global_events = events.SaveValuesIntoEntry(level, global_events, Global, { version = 1 })
		-- Secondary scores?
		-- Persist on level reset?
-- Will work?
	end,

	-- Verify Level WIP --
	verify_level_wip = function(verify)
		-- Ensure music exists?
		-- Could STILL fail later... :(
--[[
		if verify.pass == 1 then
			events.CheckNamesInValues("spawn point", verify, GridView)
		end

		events.VerifyValues(verify, enemies, GridView)
]]
-- two checks?
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M