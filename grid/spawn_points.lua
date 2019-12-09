--- Spawn point editing components.

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
local dialog = require("s3_editor.Dialog")
local editor_strings = require("config.EditorStrings")
local enemies = require("s3_utils.enemies")
local events = require("s3_editor.Events")
local grid_views = require("s3_editor.GridViews")
local strings = require("tektite_core.var.strings")

-- Exports --
local M = {}

--
--
--

-- --
local Dialog = dialog.DialogWrapper(enemies.EditorEvent)

-- --
local GridView = grid_views.EditErase(Dialog, enemies.GetTypes())

--- DOCME
-- @pgroup view X
function M.Load (view)
	GridView:Load(view, "Enemy", editor_strings("spawn_point_mode"), {
		column_width = 115, help = editor_strings("spawn_point_cur")
	})
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

		for k, sp in pairs(level.enemies.entries) do
			sp.col, sp.row = strings.KeyToPair(k)

			builds = events.BuildEntry(level, enemies, sp, builds)
		end

		level.enemies = builds
	end,

	load_level_wip = function(level)
		events.LoadGroupOfValues_Grid(level, "enemies", enemies, GridView)
	end,

	save_level_wip = function(level)
		events.SaveGroupOfValues(level, "enemies", enemies, GridView)
	end,

	verify_level_wip = function(verify)
		if verify.pass == 1 then
			events.CheckNamesInValues("spawn point", verify, GridView)
		end

		events.VerifyValues(verify, enemies, GridView)
	end
} do
	Runtime:addEventListener(k, v)
end

return M