--- Tile editing components.

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
local common = require("s3_editor.Common")
local grid = require("s3_editor.Grid")
local help = require("s3_editor.Help")
local strings = require("tektite_core.var.strings")
local tilesets = require("s3_utils.tilesets")

-- Corona globals --
local display = display

-- Exports --
local M = {}

-- --
local Grid

-- --
local Erase, TryOption

-- --
local Choices

-- --
local Tiles

-- --
local TileNames = tilesets.GetShorthands()

-- --
local Names = tilesets.GetNames()

-- --
local IsLoading

--
local function Cell (event)
	local key, maybe_dirty = strings.PairToKey(event.col, event.row)
	local tile = Tiles[key]

	if Erase then
		maybe_dirty, Tiles[key] = tile
	else
		local id = Choices.m_tile:GetSelection("id")

		if not (tile and tile.m_id == id) then
			local grid = event.target

			Tiles[key] = tilesets.NewTile(grid:GetCanvas(), Names[id], event.x, event.y, grid:GetCellDims())
			Tiles[key].m_id, maybe_dirty = id, true
		end
	end

	if maybe_dirty then
		display.remove(tile)

		if not IsLoading then
			common.Dirty()
		end
	end
end

--
local function ShowHide (event)
	local tile = Tiles[strings.PairToKey(event.col, event.row)]

	if tile then
		tile.isVisible = event.show
	end
end

--
local TileColumns = {}

for i, name in ipairs(Names) do
	TileColumns[#TileColumns + 1] = {
		id = i,
		frame = tilesets.GetFrameFromName(name),
		shader = function(tile)
			tilesets.SetTileShader(tile, name)
		end
	}
end

---
-- @pgroup view X
function M.Load (view)
	Tiles, Grid = {}, grid.NewGrid()

	Grid:addEventListener("cell", Cell)
	Grid:addEventListener("show", ShowHide)

	--
	local choices = { "Paint", "Erase" }

	Choices = common.AddCommandsBar{
		title = "Tile commands",

		"Mode:", { column = choices, column_width = 60 }, "m_mode",
		"Tile:", {
			column = TileColumns, sheets = { false }, column_width = 40, how = "no_op", image_width = 20, image_height = 20
		}, "m_tile",
		"Tileset:", { column = tilesets.GetTypes(), column_width = 60, how = "no_op" }, "m_tileset"
	}

	Choices.isVisible = false

	Choices.m_mode:addEventListener("item_change", function(event)
		Erase = event.text == "Erase"
	end)

	IsLoading = true

	Choices.m_tileset:addEventListener("item_change", function(event)
		tilesets.UseTileset(event.text)

		for _, tile in pairs(Tiles) do
			tilesets.SetTileShader(tile, Names[tile.m_id])
		end

		if not IsLoading then
			common.IsDirty()
		end
	end)
	Choices.m_tileset:Select(nil, "first_in_first_column") -- do this first to trigger tileset_details_changed

	IsLoading = false

	Choices.m_tile:Select(nil, "first_in_first_column")

	view:insert(Choices)

	--
	TryOption = grid.ChoiceTrier(choices)
--[[
	--
	help.AddHelp("Tiles", { current = CurrentTile, tabs = Tabs })
	help.AddHelp("Tiles", {
		current = "The current tile. When painting, cells are populated with this tile.",
		["tabs:1"] = "'Paint Mode' is used to add new tiles to the level, by clicking a grid cell or dragging across the grid.",
		["tabs:2"] = "'Erase Mode' is used to remove tiles from the level, by clicking an occupied grid cell or dragging across the grid."
	})]]
end

--- DOCMAYBE
function M.Enter ()
	grid.Show(Grid)
--	TryOption(Tabs)

	Choices.isVisible = true

	help.SetContext("Tiles")
end

--- DOCMAYBE
function M.Exit ()
	Choices.isVisible = false

--	grid.SetChoice(Erase and "Erase" or "Paint")
--	common.ShowCurrent(CurrentTile, false)
	grid.Show(false)
end

--- DOCMAYBE
function M.Unload ()
	Choices, Erase, Grid, Tiles, TryOption = nil
end

-- Listen to events.
for k, v in pairs{
	-- Build Level --
	build_level = function(level)
		local ncols, nrows = common.GetDims()
		local tiles = {}

		level.tiles.version = nil

		for k, v in pairs(level.tiles) do
			local col, row = strings.KeyToPair(k)

			tiles[(row - 1) * nrows + col] = TileNames[v]
		end

		for i = 1, ncols * nrows do
			tiles[i] = tiles[i] or "__"
		end

		level.tiles = { version = 1, values = tiles }
	end,

	-- Load Level WIP --
	load_level_wip = function(level)
		grid.Show(Grid)

		IsLoading, level.tiles.version = true

		Choices.m_tileset:Select(level.tileset)

		for k, v in pairs(level.tiles) do
			Choices.m_tile:Select(v)

			Grid:TouchCell(strings.KeyToPair(k))
		end

		IsLoading = false

		Choices.m_tile:Select(nil, "first_in_first_column")

		grid.ShowOrHide(Tiles)
		grid.Show(false)
	end,

	-- Preprocess Level String --
	preprocess_level_string = function(event)
		local ppinfo = event.ppinfo

		if ppinfo.is_building then
			ppinfo[#ppinfo + 1] = {
				[["tiles":%b{}]],
				function(subs)
					local col, ncols = 0, common.GetDims()

					return subs:gsub(",", function(comma)
						if col == ncols then
							col, comma = 1, ",~"
						else
							col = col + 1
						end

						return comma
					end)
				end
			}
		end
	end,

	-- Save Level WIP --
	save_level_wip = function(level)
		level.tiles = { version = 1 }
		level.tileset = Choices.m_tileset:GetSelection("text")

		for k, v in pairs(Tiles) do
			level.tiles[k] = v.m_id
		end
	end,

	-- Tileset Details Changed --
	tileset_details_changed = function()
		if Choices then
			Choices.m_tile:UpdateSheet(1, tilesets.GetSheet(), tilesets.GetShader())
		end
	end,

	-- Verify Level WIP --
	verify_level_wip = function(verify)
		-- At least one shape, if winning condition = all dots removed
		-- All dots reachable?
		
		-- When laying down tiles, store directions
		-- Just compare each one, making sure, say, a left-right one has a right one to left and a left one to right...
		-- Do walks from some dot in each start to a dot in each shape
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M