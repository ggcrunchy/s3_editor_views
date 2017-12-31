--- Editing components for triggers.

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
local pairs = pairs

-- Modules --
local dialog = require("s3_editor.Dialog")
local events = require("s3_editor.Events")
local grid_views = require("s3_editor.GridViews")
local help = require("s3_editor.Help")
local strings = require("tektite_core.var.strings")
local triggers = require("s3_utils.triggers")

-- Exports --
local M = {}

-- --
local Dialog = dialog.DialogWrapper(triggers.EditorEvent)

-- --
local GridView = grid_views.EditErase(Dialog, "trigger", "circle")

---
-- @pgroup view X
function M.Load (view)
	-- Like positions, but...
	-- Are event sources
	-- Have bitfields: on(enter): { left, right, top, bottom }, on(leave): ditto
	-- Affected by: player, other? (also a bitfield?)
	-- One-time? Reset?
	GridView:Load(view, "Trigger")
--[[
	help.AddHelp("Trigger", {
		["tabs:1"] = "'Paint Mode' is used to add new triggers to the level, by clicking a grid cell or dragging across the grid.",
		["tabs:2"] = "'Edit Mode' lets the user edit a trigger's properties. Clicking an occupied grid cell will call up a dialog.",
		["tabs:3"] = "'Erase Mode' is used to remove triggers from the level, by clicking an occupied grid cell or dragging across the grid."
	})]]
end

---
-- @pgroup view X
function M.Enter (view)
	GridView:Enter(view)

--	help.SetContext("Trigger")
end

--- DOCMAYBE
function M.Exit ()
	GridView:Exit()
end

--- DOCMAYBE
function M.Unload ()
	GridView:Unload()
end

-- Listen to events.
for k, v in pairs{
	-- Build Level --
	build_level = function(level)
		local builds

		for k, sp in pairs(level.triggers.entries) do
			sp.col, sp.row = strings.KeyToPair(k)

			builds = events.BuildEntry(level, triggers, sp, builds)
		end

		level.triggers = builds
	end,

	-- Load Scene --
	load_level_wip = function(level)
		events.LoadGroupOfValues_Grid(level, "triggers", triggers, GridView)
	end,

	-- Save Scene --
	save_level_wip = function(level)
		events.SaveGroupOfValues(level, "triggers", triggers, GridView)
	end,

	-- Verify Level WIP --
	verify_level_wip = function(verify)
		if verify.pass == 1 then
			events.CheckNamesInValues("trigger", verify, GridView)
		end

		events.VerifyValues(verify, triggers, GridView)
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M