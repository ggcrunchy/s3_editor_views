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

-- Modules --
local actions = require("s3_utils.state.actions")
local common = require("s3_editor.Common")
local dialog = require("s3_editor.Dialog")
local events = require("s3_editor.Events")
local global_events = require("s3_utils.global_events")
local grid1D = require("corona_ui.widgets.grid_1D")
local list_views = require("s3_editor.ListViews")
local values = require("s3_utils.state.values")

-- Corona globals --
local display = display

-- Exports --
local M = {}

-- --
local Global

-- --
local Group

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

	-- TODO: common.AttachLinkInfo(rep, ...)

	-- Actions and basic predicates need 1D grids to select type, plus lists
	-- ^^^ Those probably need captions / titles too, since the types are pretty low-level and conceptual
	-- Binary and complex predicates just need lists
	-- Can we unify the three predicate types in a single list? (trouble with name clashes?)
	-- Much of this can be adapted from the audio view

	--
	ActionTypes = actions.GetTypes()
	ValueTypes = values.GetTypes()

	-- For actions, values:
	-- Label (description), listbox (choices), button (add), button (remove), listbox (choices)

	--
	Group.isVisible = false

	view:insert(Group)
end

---
-- @pgroup view X
function M.Enter (view)
	Group.isVisible = true
end

--- DOCMAYBE
function M.Exit ()
	Group.isVisible = false
end

--- DOCMAYBE
function M.Unload ()
	Global, Group = nil
end

-- Listen to events.
for k, v in pairs{
	-- Build Level --
	build_level = function(level)
		level.global_events = events.BuildEntry(level, global_events, level.global_events, nil)[1]
	end,

	-- Load Level WIP --
	load_level_wip = function(level)
		events.LoadValuesFromEntry(level, global_events, Global, level.global_events)
	end,

	-- Save Level WIP --
	save_level_wip = function(level)
		level.global_events = events.SaveValuesIntoEntry(level, global_events, Global, { version = 1 })
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M