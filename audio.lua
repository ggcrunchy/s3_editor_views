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
local common_ui = require("s3_editor.CommonUI")
local file = require("corona_utils.file")
local help = require("s3_editor.Help")
local layout = require("corona_ui.utils.layout")
local match_slot_id = require("tektite_core.array.match_slot_id")
local strings = require("tektite_core.var.strings")
local table_view_patterns = require("corona_ui.patterns.table_view")

-- Corona globals --
local audio = audio
local display = display
local native = native
local system = system

-- Exports --
local M = {}

-- --
local Current, CurrentText

-- --
local Group

-- --
local PlayOrStop

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
		-- SetCurrent(Songs:GetSelection())
		action("new", using, list)
	end, "New")

	layout.LeftAlignWith(new, list)
	layout.PutBelow(new, list, 10)

	local delete = button.Button_XY(Group, 0, new.y, new.width, new.height, function()
		local index = list:Find(list:GetSelection())

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

---
-- @pgroup view X
function M.Load (view)
	local w, h = display.contentWidth, display.contentHeight

	--
	if system.getInfo("environment") == "device" then
		file.AddDirectory("Music", system.DocumentsDirectory)
	end

	--
	Group = display.newGroup()

	-- music sidebar

	--
	local music_props = display.newGroup()
	local music_list, music_items, mbot = List("Music tracks", function(what, using, arg1, arg2)
		local items = using("get_array")

		if what == "update" then
			music_props.isVisible = true

			-- Set one by one
		elseif what == "new" then
			local music = { name = GetName(using, "Music") }

			items[#items + 1] = music

			arg1:Append(music.name)
		elseif what == "delete" then
			music_props.isVisible = #items == 0

			arg1:Delete(arg2)
		end
	end, 80, 0, 0, 1)

	-- sound sidebar

	--
	local sound_props = display.newGroup()
	local sound_list, sound_items, sbot = List("Sound sources", function(what, using, arg1, arg2)
		local items = using("get_array")

		if what == "update" then
			sound_props.isVisible = true

			-- Set one by one
		elseif what == "new" then
			local sound = { name = GetName(using, "Sound") }

			items[#items + 1] = sound

			arg1:Append(sound.name)
		elseif what == "delete" then
			sound_props.isVisible = #items == 0

			arg1:Delete(arg2)
		end
	end, mbot + 15, 0, 1, 0)


	-- Two listboxes:
		-- Sounds
			-- Name
			-- Filename
			-- Panning, volume, etc.?
		-- Music (tracks?)
			-- Name
			-- Filename
			-- What else?
		-- On selection, populate property list to side? (Alternatively, dialog box)
		-- Have button to call up ChooseAudio dialog for each (pass in current selection, if any?)
	-- "Global" state:
		-- On enter level: play track (with "default" checked, or lone track); nothing
		-- On reset level: play enter track; reset current track; stop current track; nothing (what about sounds?)
		-- ^^^ These just hook up global events; for finer control, do manually
--[[
	--
	CurrentText = display.newText(Group, "", 0, 0, native.systemFont, 24)

	SetCurrent(nil)


	--
	local widgets = { current = CurrentText, list = Songs, play_or_stop = PlayOrStop }

	widgets.set = button.Button_XY(Group, 0, y, bw, bh, function()
		SetCurrent(Songs:GetSelection())
	end, "Set")

	widgets.clear = button.Button_XY(Group, 0, y, bw, bh, function()
		SetCurrent(nil)
	end, "Clear")
]]
	--
	Group.isVisible = false

	view:insert(Group)
--[[
	--
	help.AddHelp("Ambience", widgets)
	help.AddHelp("Ambience", {
		current = "What is the 'current' selection?",
		list = "A list of available songs.",
		play_or_stop = "If music is playing, stops it. Otherwise, plays the 'current' selection, if available.",
		set = "Make the selected item in the songs list into the 'current' selection.",
		clear = "Clear the 'current' selection."
	})]]
end

---
-- @pgroup view X
function M.Enter (view)
--[[
	-- Sample music (until switch view or option)
	-- Background option, sample (scroll views, event block selector)
	-- Picture option, sample
	SetText(PlayOrStop[2], "Play")
]]
	Group.isVisible = true
require("composer").showOverlay("s3_editor.overlay.ChooseAudio", { params = { assign = function(a) print("YEAH!", a) end, mode = "stream" } })
--	help.SetContext("Ambience")
end

--- DOCMAYBE
function M.Exit ()
	Group.isVisible = false
end

--- DOCMAYBE
function M.Unload ()
	Current, CurrentText, Group, PlayOrStop, Using = nil
end

-- Listen to events.
for k, v in pairs{
	-- Build Level --
	build_level = function(level)
		-- ??
	end,

	-- Load Level WIP --
	load_level_wip = function(level)
		level.ambience.version = nil

		SetCurrent(level.ambience.music)
	end,

	-- Save Level WIP --
	save_level_wip = function(level)
		level.ambience = { version = 1, music = Current }

		-- Secondary scores?
		-- Persist on level reset?
	end,

	-- Verify Level WIP --
	verify_level_wip = function(verify)
		-- Ensure music exists?
		-- Could STILL fail later... :(
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M