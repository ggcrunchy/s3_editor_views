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
local editor_strings = require("config.EditorStrings")
local grid = require("s3_editor.Grid")
local help = require("s3_editor.Help")
local strings = require("tektite_core.var.strings")
local tilesets = require("s3_utils.tilesets")

-- Corona globals --
local display = display

-- Exports --
local M = {}

--
--
--

-- --
local Grid

-- --
local Erase

-- --
local Choices

-- --
local Tiles

-- --
local TileNames = tilesets.GetShorthands()

-- --
local Names = tilesets.GetNames()

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
		common.Dirty()
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

-- --
local HelpContext

--
local Options = { "Paint", "Erase" }

---
-- @pgroup view X
function M.Load (view)
	Tiles, Grid = {}, grid.NewGrid()

	Grid:addEventListener("cell", Cell)
	Grid:addEventListener("show", ShowHide)

	HelpContext = help.NewContext()
	Choices = common.AddCommandsBar{
		title = "Tile commands", help_context = HelpContext,

		"Mode:", { column = Options, column_width = 60 }, "m_mode", editor_strings("tile_mode"),
		"Tile:", {
			column = TileColumns, sheets = { false }, column_width = 40, how = "no_op", image_width = 20, image_height = 20
		}, "m_tile", editor_strings("tile_cur"),
		"Tileset:", { column = tilesets.GetTypes(), column_width = 60, how = "no_op" }, "m_tileset", editor_strings("tileset")
	}

	Choices.isVisible = false

	Choices.m_mode:addEventListener("item_change", function(event)
		Erase = event.text == "Erase"
	end)
	Choices.m_tileset:addEventListener("item_change", function(event)
		tilesets.UseTileset(event.text)

		for _, tile in pairs(Tiles) do
			tilesets.SetTileShader(tile, Names[tile.m_id])
		end

		common.IsDirty()
	end)
	Choices.m_tileset:Select(nil, "first_in_first_column") -- do this first to trigger tileset_details_changed
	Choices.m_tile:Select(nil, "first_in_first_column")

	view:insert(Choices)
	HelpContext:Register()
	HelpContext:Show(false)
end

--- DOCMAYBE
function M.Enter ()
	grid.Show(Grid)
	common.ShowCurrent(Choices, Options)

	HelpContext:Show(true)
end

--- DOCMAYBE
function M.Exit ()
	common.ShowCurrent(Choices, false)
	grid.Show(false)

	HelpContext:Show(false)
end

--- DOCMAYBE
function M.Unload ()
	Choices, Erase, Grid, HelpContext, Tiles = nil
end

for k, v in pairs{
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

	load_level_wip = function(level)
		grid.Show(Grid)

		level.tiles.version = nil

		Choices.m_tileset:Select(level.tileset)

		for k, v in pairs(level.tiles) do
			Choices.m_tile:Select(v)

			Grid:TouchCell(strings.KeyToPair(k))
		end

		Choices.m_tile:Select(nil, "first_in_first_column")

		grid.ShowOrHide(Tiles)
		grid.Show(false)
	end,

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

	save_level_wip = function(level)
		level.tiles = { version = 1 }
		level.tileset = Choices.m_tileset:GetSelection("text")

		for k, v in pairs(Tiles) do
			level.tiles[k] = v.m_id
		end
	end,

	tileset_details_changed = function()
		if Choices then
			Choices.m_tile:UpdateSheet(1, tilesets.GetSheet(), tilesets.GetShader())
		end
	end,

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

return M