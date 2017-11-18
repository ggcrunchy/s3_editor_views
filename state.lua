--- Editing components for assorted game state.

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

-- Standard library imports --
local ipairs = ipairs
local pairs = pairs

-- Modules --
local actions = require("s3_utils.state.actions")
local common = require("s3_editor.Common")
local common_ui = require("s3_editor.CommonUI")
local config = require("config.GlobalEvents")
local dialog = require("s3_editor.Dialog")
local events = require("s3_editor.Events")
local global_events = require("s3_utils.global_events")
local grid1D = require("corona_ui.widgets.grid_1D")
local help = require("s3_editor.Help")
local layout = require("corona_ui.utils.layout")
local list_views = require("s3_editor.ListViews")
local table_view_patterns = require("corona_ui.patterns.table_view")
local values = require("s3_utils.state.values")

-- Corona globals --
local display = display
local native = native

-- Exports --
local M = {}

-- --
local Global

-- --
local Group

-- --
local ActionChoices, ValueChoices

-- --
local ActionDialog = dialog.DialogWrapper(actions.EditorEvent)
local ValueDialog = dialog.DialogWrapper(values.EditorEvent)

-- --
local ActionView, ValueView = list_views.EditErase(ActionDialog, function()
	return ActionChoices:GetSelection()
end), list_views.EditErase(ValueDialog, function()
	return ValueChoices:GetSelection()
end)

--
local function Lists (str, view, top, r, g, b, names)
	local text = display.newText(Group, str, 0, 0, native.systemFont, layout.ResolveY("5%"))

	layout.PutRightOf(text, "15.625%")
	layout.PutBelow(text, top)

	local list, bottom = view:Load(Group, layout.Below(text), layout.LeftOf(text))

	common_ui.Frame(list, r, g, b)

	local choices = table_view_patterns.Listbox(Group, {
		width = "30%", height = list.height, text_rect_height = "6%", text_size = "4.25%"
	})

	layout.PutRightOf(choices, list, "5%")
	layout.BottomAlignWith(choices, list)

	local ttext = display.newText(Group, "Types", 0, 0, native.systemFont, layout.ResolveY("5%"))

	layout.LeftAlignWith(ttext, choices)
	layout.PutAbove(ttext, choices)

	for _, name in ipairs(names) do
		choices:Append(name)
	end

	return list, bottom, choices
end

-- --
local ActionTypes, ValueTypes

---
-- @pgroup view X
function M.Load (view)
	--
	Group = display.newGroup()

	--
	Global = { name = "Global" }

	common.BindRepAndValuesWithTag(view, Global, common.GetTag(false, global_events.EditorEvent))
	common.AttachLinkInfo(view, config.link_info)

	--
	ActionTypes = actions.GetTypes()
	ValueTypes = values.GetTypes()

	--
	local action_list, abot, achoices = Lists("Actions", ActionView, "16.67%", 0, 0, 1, ActionTypes)
	local value_list, vbot, vchoices = Lists("Values", ValueView, abot + layout.ResolveY("3.125%"), 0, 1, 0, ValueTypes)

	ActionChoices = achoices
	ValueChoices = vchoices

	--
	Group.isVisible = false

	view:insert(Group)

	--
	help.AddHelp("State", {
		action = action_list, value = value_list,
		achoices = achoices, vchoices = vchoices
	})
	help.AddHelp("State", {
		action = "Add or remove actions.",
		value = "Add or remove values.",
		achoices = "Action type to add.",
		vchoices = "Value type to add."
	})
end

---
-- @pgroup view X
function M.Enter (view)
	Group.isVisible = true

	ActionView:Enter(view)
	ValueView:Enter(view)

	help.SetContext("State")
end

--- DOCMAYBE
function M.Exit ()
	ActionView:Exit()
	ValueView:Exit()

	Group.isVisible = false
end

--- DOCMAYBE
function M.Unload ()
	ActionView:Unload()
	ValueView:Unload()

	Global, Group = nil -- TODO: remove more?
end

-- Listen to events.
for k, v in pairs{
	-- Build Level --
	build_level = function(level)
		level.global_events = events.BuildEntry(level, global_events, level.global_events, nil)[1]

		--
		local action_builds, value_builds

		for _, aentry in pairs(level.action.entries) do
			action_builds = events.BuildEntry(level, actions, aentry, action_builds)
		end

		for _, ventry in pairs(level.value.entries) do
			value_builds = events.BuildEntry(level, values, ventry, value_builds)
		end

		level.action, level.value = action_builds, value_builds
	end,

	-- Load Level WIP --
	load_level_wip = function(level)
		events.LoadValuesFromEntry(level, global_events, Global, level.global_events)
		events.LoadGroupOfValues_List(level, "action", actions, ActionView)
		events.LoadGroupOfValues_List(level, "value", values, ValueView)
	end,

	-- Save Level WIP --
	save_level_wip = function(level)
		level.global_events = events.SaveValuesIntoEntry(level, global_events, Global, { version = 1 })
		events.SaveGroupOfValues(level, "action", actions, ActionView)
		events.SaveGroupOfValues(level, "value", values, ValueView)
	end,

	-- Verify Level WIP --
	verify_level_wip = function(verify)
		if verify.pass == 1 then
			events.CheckNamesInValues("action", verify, ActionView)
			events.CheckNamesInValues("value", verify, ValueView)
		end

		events.VerifyValues(verify, actions, ActionView)
		events.VerifyValues(verify, values, ValueView)
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M