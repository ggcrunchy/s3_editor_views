--- Editing components for auxiliary positions.

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
local editor_strings = require("config.EditorStrings")
local events = require("s3_editor.Events")
local grid_views = require("s3_editor.GridViews")
local positions = require("s3_utils.positions")
local strings = require("tektite_core.var.strings")

-- Exports --
local M = {}

--
--
--

-- --
local Dialog = dialog.DialogWrapper(positions.EditorEvent)

-- --
local GridView = grid_views.EditErase(Dialog, "position", "circle")

---
-- @pgroup view X
function M.Load (view)
	GridView:Load(view, "Position", editor_strings("position_mode"))
end

---
-- @pgroup view X
function M.Enter (view)
	GridView:Enter(view)
end

--- DOCMAYBE
function M.Exit ()
	GridView:Exit()
end

--- DOCMAYBE
function M.Unload ()
	GridView:Unload()
end

for k, v in pairs{
	build_level = function(level)
		local builds

		for k, pos in pairs(level.positions.entries) do
			pos.col, pos.row = strings.KeyToPair(k)

			builds = events.BuildEntry(level, positions, pos, builds)
		end

		level.positions = builds
	end,

	load_level_wip = function(level)
		events.LoadGroupOfValues_Grid(level, "positions", positions, GridView)
	end,

	save_level_wip = function(level)
 		events.SaveGroupOfValues(level, "positions", positions, GridView)
	end,

	verify_level_wip = function(verify)
		if verify.pass == 1 then
			events.CheckNamesInValues("position", verify, GridView)
		end

		events.VerifyValues(verify, positions, GridView)
	end
} do
	Runtime:addEventListener(k, v)
end

return M