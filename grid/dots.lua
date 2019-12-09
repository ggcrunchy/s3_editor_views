--- Dot editing components.

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
local dots = require("s3_utils.dots")
local editor_strings = require("config.EditorStrings")
local events = require("s3_editor.Events")
local grid_views = require("s3_editor.GridViews")
local strings = require("tektite_core.var.strings")

-- Exports --
local M = {}

--
--
--

-- --
local Dialog = dialog.DialogWrapper(dots.EditorEvent)

-- --
local GridView = grid_views.EditErase(Dialog, dots.GetTypes())

--- DOCME
-- @pgroup view X
function M.Load (view)
	GridView:Load(view, "Dot", editor_strings("dot_mode"), editor_strings("dot_cur"))
end

--- DOCME
-- @pgroup view
function M.Enter (view)
	GridView:Enter(view)
end

--- DOCME
function M.Exit ()
	GridView:Exit()
end

--- DOCME
function M.Unload ()
	GridView:Unload()
end

for k, v in pairs{
	build_level = function(level)
		local builds

		for k, dot in pairs(level.dots.entries) do
			dot.col, dot.row = strings.KeyToPair(k)

			builds = events.BuildEntry(level, dots, dot, builds)
		end

		level.dots = builds
	end,

	load_level_wip = function(level)
		events.LoadGroupOfValues_Grid(level, "dots", dots, GridView)
	end,

	save_level_wip = function(level)
		events.SaveGroupOfValues(level, "dots", dots, GridView)
	end,

	verify_level_wip = function(verify)
		if verify.pass == 1 then
			events.CheckNamesInValues("dot", verify, GridView)
		end

		events.VerifyValues(verify, dots, GridView)
	end
} do
	Runtime:addEventListener(k, v)
end

return M