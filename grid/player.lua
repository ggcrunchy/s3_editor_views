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
local editor_strings = require("config.EditorStrings")
local grid = require("s3_editor.Grid")
local grid_views = require("s3_editor.GridViews")
local help = require("s3_editor.Help")

-- Exports --
local M = {}

--
--
--

-- --
local Grid

-- --
local StartPos

--
local function Cell (event)
	local existed = StartPos ~= nil

	StartPos = grid_views.ImageUpdate(event.target, event.x, event.y, editor_config.player_image, StartPos)

	if event.col ~= StartPos.m_col or event.row ~= StartPos.m_row then
		StartPos.m_col = event.col
		StartPos.m_row = event.row

		if existed then
			common.Dirty()
		end
	end
end

-- --
local Choices

-- --
local HelpContext

---
-- @pgroup view X
function M.Load (view)
	Grid = grid.NewGrid()

	Grid:addEventListener("cell", Cell)
	Grid:TouchCell(1, 1)

	grid.Show(false)
	
	HelpContext = help.NewContext()
	Choices = common.AddCommandsBar{
		title = "Player commands", help_context = HelpContext,

		"Mode:", { column = { "Start", "Move" }, column_width = 60 }, "m_mode", editor_strings("player_mode")
	}

	Choices.m_mode:addEventListener("item_change", function(event)
		grid.SetDraggable(event.text == "Move")
	end)

	view:insert(Choices)
	HelpContext:Register()
end

--- DOCMAYBE
function M.Enter ()
	grid.Show(Grid)

	Choices.isVisible = true

	HelpContext:Show(true)
	-- Zoom factors?
end

--- DOCMAYBE
function M.Exit ()
	grid.Show(false)

	Choices.isVisible = false

	HelpContext:Show(false)
end

--- DOCMAYBE
function M.Unload ()
	Choices, Grid, HelpContext, StartPos = nil
end

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

return M