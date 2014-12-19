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
local enemies = require("s3_utils.enemies")
local events = require("s3_editor.Events")
local grid_views = require("s3_editor.GridViews")
local help = require("s3_editor.Help")
local strings = require("tektite_core.var.strings")

-- Exports --
local M = {}

-- --
local Dialog = dialog.DialogWrapper(enemies.EditorEvent)

-- --
local GridView = grid_views.EditErase(Dialog, enemies.GetTypes())

--- DOCME
-- @pgroup view X
function M.Load (view)
	GridView:Load(view, "Enemy", "Current enemy")

	help.AddHelp("Enemy", {
		current = "The current enemy type. When painting, cells are populated with this type's spawn point.",
		["tabs:1"] = "'Paint Mode' is used to add new spawn points to the level, by clicking a grid cell or dragging across the grid.",
		["tabs:2"] = "'Edit Mode' lets the user edit a spawn point's properties. Clicking an occupied grid cell will call up a dialog.",
		["tabs:3"] = "'Erase Mode' is used to remove spawn points from the level, by clicking an occupied grid cell or dragging across the grid."
	})
end

--- DOCME
-- @pgroup view
function M.Enter (view)
	GridView:Enter(view)

	help.SetContext("Enemy")
end

--- DOCME
function M.Exit ()
	GridView:Exit()
end

--- DOCME
function M.Unload ()
	GridView:Unload()
end

-- Listen to events.
for k, v in pairs{
	-- Build Level --
	build_level = function(level)
		local builds

		for k, sp in pairs(level.enemies.entries) do
			sp.col, sp.row = strings.KeyToPair(k)

			builds = events.BuildEntry(level, enemies, sp, builds)
		end

		level.enemies = builds
	end,

	-- Load Scene --
	load_level_wip = function(level)
		events.LoadGroupOfValues_Grid(level, "enemies", enemies, GridView)
	end,

	-- Save Scene --
	save_level_wip = function(level)
		events.SaveGroupOfValues(level, "enemies", enemies, GridView)
	end,

	-- Verify Level WIP --
	verify_level_wip = function(verify)
		if verify.pass == 1 then
			events.CheckNamesInValues("spawn point", verify, GridView)
		end

		events.VerifyValues(verify, enemies, GridView)
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M