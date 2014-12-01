--- Player editing components.

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
local common = require("s3_editor.Common")
local editor_config = require("config.Editor")
local grid = require("s3_editor.Grid")
local grid_views = require("s3_editor.GridViews")
local help = require("s3_editor.Help")

-- Exports --
local M = {}

-- --
local Grid

-- --
local Option

-- --
local StartPos

-- --
local Tabs

--
local function Cell (event)
	StartPos = grid_views.ImageUpdate(event.target, event.x, event.y, editor_config.player_image, StartPos)

	if event.col ~= StartPos.m_col or event.row ~= StartPos.m_row then
		StartPos.m_col = event.col
		StartPos.m_row = event.row

		common.Dirty()
	end
end

---
-- @pgroup view X
function M.Load (view)
	Grid = grid.NewGrid()

	Grid:addEventListener("cell", Cell)

	--
	local choices = { "Start" }--, "Events" } -- todo: other player stuff, not events

	Tabs = grid_views.AddTabs(view, choices, function(label)
		return function()
			if Option ~= label then
				--
				if Option == "Start" then
					grid.Show(false)
				-- else...
				end

				--
				if label == "Start" then
					grid.Show(Grid)
				-- else ...
				end

				Option = label
			end

			return true
		end
	end, 200)

	--
	grid.Show(false)

	--
	help.AddHelp("Player", { tabs = Tabs })
	help.AddHelp("Player", {
		["tabs:1"] = "'Start' is used to choose where the player will first appear in the level.",
--		["tabs:2"] = "other stuff!"
	})
end

--- DOCMAYBE
function M.Enter ()
	if Option == "Start" then
		grid.Show(Grid)
	end

	-- Zoom factors?
	-- Triggers (can be affected by enemies?)
	-- "positions"

	Tabs.isVisible = true

	help.SetContext("Player")
end

--- DOCMAYBE
function M.Exit ()
	Tabs.isVisible = false

	grid.Show(false)
end

--- DOCMAYBE
function M.Unload ()
	Tabs:removeSelf()

	Grid, Option, StartPos, Tabs = nil
end

-- Listen to events.
for k, v in pairs{
	-- Load Level WIP --
	load_level_wip = function(level)
		if level.player.col and level.player.row then
			grid.Show(Grid)

			Grid:TouchCell(level.player.col, level.player.row)

			grid.Show(false)
		end
	end,

	-- Save Level WIP --
	save_level_wip = function(level)
		level.player = { version = 1 }

		if StartPos then
			level.player.col = StartPos.m_col
			level.player.row = StartPos.m_row
		end
	end,

	-- Verify Level WIP --
	verify_level_wip = function(verify)
		if verify.pass == 1 then
			if not StartPos then
				verify[#verify + 1] = "Missing start position"
			else
				-- Start position on a tile?
			end
		end
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M