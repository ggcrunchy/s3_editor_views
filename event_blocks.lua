--- Event block editing components.

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
local ipairs = ipairs
local max = math.max
local min = math.min

-- Modules --
local common = require("s3_editor.Common")
local dialog = require("s3_editor.Dialog")
local event_blocks = require("s3_utils.event_blocks")
local events = require("s3_editor.Events")
local grid = require("s3_editor.Grid")
local grid1D = require("corona_ui.widgets.grid_1D")
local grid_views = require("s3_editor.GridViews")
local help = require("s3_editor.Help")
local sheet = require("corona_ui.utils.sheet")
local strings = require("tektite_core.var.strings")
local touch = require("corona_ui.utils.touch")

-- Corona globals --
local display = display

-- Exports --
local M = {}

-- --
local TileImages

-- --
local CurrentEvent

-- --
local Option, TryOption

-- --
local Tabs

-- --
local Blocks

-- --
local Tiles

-- --
local Types

-- --
local Dialog = dialog.DialogWrapper(event_blocks.EditorEvent)

-- --
local CanFill, Name, ID

--
local function FitTo (rep, ul, lr)
	local x, y, w, h = ul.x, ul.y, ul.width, ul.height

	if lr then
		local x2, y2, w2, h2 = lr.x, lr.y, lr.width, lr.height
		local xr, yb = max(x + w, x2 + w2), max(y + h, y2 + h2)

		x, y = min(x - w, x2 - w2), min(y - h, y2 - h2)
		w, h = xr - x, yb - y
	end

	rep.anchorX, rep.x, rep.width = 0, x, w
	rep.anchorY, rep.y, rep.height = 0, y, h
end

--
local function SetHandle (handle, tile, scale)
	handle.x = tile.x + scale * (tile.contentWidth - handle.width)
	handle.y = tile.y + scale * (tile.contentHeight - handle.height)
end

--
local function GetCorners (block)
	local ul = Tiles[strings.PairToKey(block.col1, block.row1)].image
	local lr = Tiles[strings.PairToKey(block.col2, block.row2)].image

	return ul, lr
end

--
local function CenterRect (group, block, ul, lr)
	local x, w = (ul.x + lr.x) / 2, lr.x - ul.x + lr.contentWidth
	local y, h = (ul.y + lr.y) / 2, lr.y - ul.y + lr.contentHeight

	if not group then
		group = block.selection.parent

		block.selection:removeSelf()
	end
		
	local selection = display.newRoundedRect(group, x, y, w, h, 15)

	selection:setFillColor(.9, 0, 0, .08)
	selection:setStrokeColor(1, 0, 0)
	selection:toBack()

	selection.strokeWidth = 5

	block.selection = selection
end

--
local function UpdateHandles (block)
	local ul, lr = GetCorners(block)

	if ID then
		CenterRect(nil, block, ul, lr)
	else
		SetHandle(block.m_ul, ul, -.5)
		SetHandle(block.m_lr, lr, .5)
	end

	if not block.m_handle_group then
		block.m_handle_group = display.newGroup()

		ul.parent:insert(block.m_handle_group)
	
		block.m_handle_group:toBack()

		block.m_handle_group:insert(block.m_ul)
		block.m_handle_group:insert(block.m_lr)
	end

	if block.rep then
		FitTo(block.rep, ul, lr)
	end
end

-- --
local Col1, Col2, Row1, Row2

--
local function GetColsRows ()
	return min(Col1, Col2), min(Row1, Row2), max(Col1, Col2), max(Row1, Row2)
end

--
local function WipeBlock (block)
	for row = block.row1, block.row2 do
		for col = block.col1, block.col2 do
			local key = strings.PairToKey(col, row)
			local tile = Tiles[key]

			if tile then
				block.cache:insert(tile.image)
				block.cache:insert(tile.id_str)

				Tiles[key] = nil
			end
		end
	end
end

--
local Grid

--
local function TouchBlock (block, name, old_name)
	Name = name

	for row = block.row1, block.row2 do
		for col = block.col1, block.col2 do
			Grid:TouchCell(col, row)
		end
	end

	Name = old_name
end

--
local function UpdateBlock (block)
	WipeBlock(block)

	block.col1, block.row1, block.col2, block.row2 = GetColsRows()

	TouchBlock(block, "fill", Name)

	common.Dirty()
end

--
local HandleTouch = touch.TouchHelperFunc(function(event, handle)
	local block = Blocks[handle.m_id]
	local hgroup = block.m_handle_group

	CenterRect(hgroup.parent, block, GetCorners(block))

	block.selection:setFillColor(.9, 0, 0, .08)
	block.selection:setStrokeColor(1, 0, 0)
	block.selection:toBack()

	block.selection.strokeWidth = 5

	hgroup.isVisible, Col1, Col2, Row1, Row2 = false, block.col1, block.col2, block.row1, block.row2
end, function(event, handle)
	CanFill, ID, Name = true, handle.m_id, handle.m_name

	Grid:TouchXY(event.xStart, event.yStart, event.x, event.y)

	UpdateBlock(Blocks[ID])
	UpdateHandles(Blocks[ID])
end, function(_, handle)
	local block = Blocks[handle.m_id]
	local hgroup = block.m_handle_group

	block.selection:removeSelf()

	hgroup.isVisible, block.selection, CanFill, ID, Name = true

	UpdateHandles(block)
end)

--
local function AddHandle (block, name, id)
	local handle = display.newCircle(0, 0, 12)

	handle:addEventListener("touch", HandleTouch)
	handle:setFillColor(1, 0, 0, .15)
	handle:setStrokeColor(0, 0, 1, .5)

	handle.strokeWidth = 3

	handle.m_id = id
	handle.m_name = name

	block["m_" .. name] = handle
end

--
local function ShowHandles (block, group, id)
	if not block then
		return
	
	--
	elseif group then
		AddHandle(block, "ul", id)
		AddHandle(block, "lr", id)

		UpdateHandles(block)

	--
	else
		block.m_ul:removeSelf()
		block.m_lr:removeSelf()

		display.remove(block.m_handle_group)

		block.m_ul, block.m_lr, block.m_handle_group = nil
	end
end

--
local Cell

--
local function ShowHide (event)
	local tile = Tiles[strings.PairToKey(event.col, event.row)]

	if tile then
		tile.image.isVisible = event.show and Option ~= "Stretch"
		tile.id_str.isVisible = event.show
	end
end

---
-- @pgroup view X
function M.Load (view)
	Blocks, Tiles, Grid = {}, {}, grid.NewGrid()

	Grid:addEventListener("cell", Cell)
	Grid:addEventListener("show", ShowHide)

	--
	CurrentEvent = grid1D.OptionsHGrid(view, nil, 150, 50, 200, 100, "Current event")

	--
	local choices = { "Paint", "Edit", "Stretch", "Erase" }

	Tabs = grid_views.AddTabs(view, choices, function(label)
		return function()
			if Option ~= label then
				common.ShowCurrent(CurrentEvent, label == "Paint")

				--
				if Option == "Edit" then
					Dialog("close")

				--
				elseif Option == "Stretch" then
					grid.ShowOrHide(Tiles, function(tile, show)
						tile.image.isVisible = show
					end)

					for _, block in ipairs(Blocks) do
						ShowHandles(block)
					end
				end

				--
				if label == "Stretch" then
					grid.ShowOrHide(Tiles, function(tile)
						tile.image.isVisible = false
					end)

					for id, block in ipairs(Blocks) do
						ShowHandles(block, view, id)
					end
				end

				Option = label

				return true
			end
		end
	end, 360)

	--
	TryOption = grid.ChoiceTrier(choices)

	--
	Types = event_blocks.GetTypes()

	--
	TileImages = common.SpriteSetFromThumbs("EventBlock", Types)

	--
	CurrentEvent:Bind(TileImages, #TileImages)
	CurrentEvent:toFront()

	common.ShowCurrent(CurrentEvent, false)

	--
	help.AddHelp("EventBlock", { current = CurrentEvent, tabs = Tabs })
	help.AddHelp("EventBlock", {
		current = "The current event block type. When painting, cells are populated with this event block.",
		["tabs:1"] = "'Paint Mode' is used to add new event blocks to the level, by clicking an unoccupied grid cell or dragging across the grid.",
		["tabs:2"] = "'Edit Mode' lets the user edit an event block's properties. Clicking any occupied grid cell will call up a dialog.",
		["tabs:3"] = "'Stretch Mode' is used to change an event block's area. Click and drag either of the two handles at the current corners.",
		["tabs:4"] = "'Erase Mode' is used to remove event blocks from the level, by clicking any occupied grid cell or dragging across the grid."
	})
end

--
local function GetCache (block, group)
	local cache, n = block.cache

	if not cache then
		cache, n = display.newGroup(), 0

		group:insert(cache)

		block.cache, cache.isVisible = cache, false
	else
		n = cache.numChildren
	end

	return cache, n
end

--
local function AddImage (group, key, id, x, y, w, h, hide)
	local block = Blocks[id]
	local cache, n = GetCache(block, group)
	local image = n > 0 and cache[n - 1] or sheet.NewImage(group, TileImages, 0, 0, w, h)

	sheet.SetSpriteSetImageFrame(image, events.GetIndex(Types, block.info.type))

	image.x, image.y, image.isVisible = x, y, not hide
-- TODO (make this a block thing? the rep?)
	local id_str = n > 0 and cache[n] or display.newText(group, id, 0, 0, native.systemFontBold, 32)

	id_str.x, id_str.y = image.x, image.y

	id_str:setFillColor(0, 1, 0)
-- /TODO
	if n > 0 then
		group:insert(image)
		group:insert(id_str)
	end

	Tiles[key] = { image = image, id_str = id_str, id = id }

	common.Dirty()
end

--
local function AddRep (block, type)
	local tag = Dialog("get_tag", type)

	if tag then
		local tile = Tiles[strings.PairToKey(block.col1, block.row1)].image
		local rep = display.newRect(tile.parent, 0, 0, 50, 50)--, 15) -- <- should be rounded?

		FitTo(rep, tile)

		common.BindRepAndValues(rep, block.info)
		common.GetLinks():SetTag(rep, tag)

		block.rep, rep.isVisible = rep, false
	end
end

--
local function CheckCol (col, rfrom, rto)
	for row = rfrom, rto do
		local tile = Tiles[strings.PairToKey(col, row)]

		if tile and tile.id ~= ID then
			return
		end
	end

	return true
end

--
local function CheckRow (row, cfrom, cto)
	for col = cfrom, cto do
		local tile = Tiles[strings.PairToKey(col, row)]

		if tile and tile.id ~= ID then
			return
		end
	end

	return true
end

--
local function FindFreeID ()
	for i, v in ipairs(Blocks) do
		if not v then
			return i
		end
	end

	return #Blocks + 1
end

--
function Cell (event)
	local col, row = event.col, event.row
	local key = strings.PairToKey(col, row)
	local tile = Tiles[key]

	--
	if Option == "Paint" then
		if not tile then
			local id, which = FindFreeID(), CurrentEvent:GetCurrent()

			Blocks[id] = { col1 = col, row1 = row, col2 = col, row2 = row, info = Dialog("new_values", Types[which], id) }

			AddImage(event.target:GetCanvas(), key, id, event.x, event.y, event.target:GetCellDims())
			AddRep(Blocks[id], Types[which])

			common.Dirty()
		end

	--
	elseif Option == "Edit" then
		if tile then
			Dialog("edit", Blocks[tile.id].info, CurrentEvent.parent, tile.id, Blocks[tile.id].rep)
		else
			Dialog("close")
		end

	--
	elseif Option == "Erase" then
		local id = tile and tile.id

		if id then
			WipeBlock(Blocks[id])

			common.BindRepAndValues(Blocks[id].rep, nil)
			display.remove(Blocks[id].rep)

			Blocks[id].cache:removeSelf()

			Blocks[id] = false

			common.Dirty()
		end

	--
	elseif Name == "fill" then
		local w, h = event.target:GetCellDims()

		AddImage(event.target:GetCanvas(), key, ID, event.x, event.y, w, h, true)

	--
	elseif CanFill then
		local col1, row1, col2, row2 = GetColsRows()

		CanFill = CheckCol(col, row1, row2) and CheckRow(row, col1, col2)

		if CanFill then
			if Name == "ul" then
				Col1, Row1 = col, row
			else
				Col2, Row2 = col, row
			end
		end
	end
end

--- DOCMAYBE
function M.Enter ()
	grid.Show(Grid)
	TryOption(Tabs, Option)
	common.ShowCurrent(CurrentEvent, Option == "Paint")

	Tabs.isVisible = true

	help.SetContext("EventBlock")
end

--- DOCMAYBE
function M.Exit ()
	Dialog("close")

	Tabs.isVisible = false

	grid.SetChoice(Option)
	common.ShowCurrent(CurrentEvent, false)
	grid.Show(false)
end

--- DOCMAYBE
function M.Unload ()
	Tabs:removeSelf()

	CurrentEvent, Grid, Option, Blocks, Tabs, Tiles, TileImages, TryOption, Types = nil
end

--
local function NewBlock (block, info)
	return { col1 = block.col1, row1 = block.row1, col2 = block.col2, row2 = block.row2, info = info }
end

-- Listen to events.
for k, v in pairs{
	-- Build Level --
	build_level = function(level)
		local builds

		for _, block in ipairs(level.event_blocks.blocks) do
			if block then
				builds = events.BuildEntry(level, event_blocks, block.info, builds)

				common.CopyInto(builds[#builds], block, "info")
			end
		end

		level.event_blocks = builds
	end,

	-- Editor Event Message --
	editor_event_message = function(event)
		-- TODO: Needs fixing when reincorporated back into game!
		local packet, verify = event.packet, event.verify

		if packet.message == "target:event_block" then
			for _, block in ipairs(Blocks) do
				if block and block.info.name == packet.target then
					return
				end
			end

			verify[#verify + 1] = ("Target `%s` of %s `%s` does not exist."):format(packet.target, packet.what, packet.name)
		end
	end,

	-- Load Level WIP --
	load_level_wip = function(level)
		grid.Show(Grid)

		level.event_blocks.version = nil

		for id, block in ipairs(level.event_blocks.blocks) do
			if block then
				Blocks[#Blocks + 1] = NewBlock(block, Dialog("new_values", block.info.type, id))

				Option, ID = "Stretch", id

				TouchBlock(Blocks[#Blocks], "fill")
				AddRep(Blocks[#Blocks], block.info.type)

				Option, ID = "Paint"

				events.LoadValuesFromEntry(level, event_blocks, Blocks[#Blocks].info, block.info)
			else
				Blocks[#Blocks + 1] = false
			end
		end

		grid.ShowOrHide(Tiles, function(tile, show)
			tile.id_str.isVisible = show
			tile.image.isVisible = show
		end)
		grid.Show(false)
	end,

	-- Save Level WIP --
	save_level_wip = function(level)
		level.event_blocks = { blocks = {}, version = 1 }

		local blocks = level.event_blocks.blocks

		for _, block in ipairs(Blocks) do
			local new_block = false

			if block then
				new_block = NewBlock(block, {})

				events.SaveValuesIntoEntry(level, event_blocks, block.info, new_block.info)
			end

			blocks[#blocks + 1] = new_block
		end
	end,

	-- Verify Level WIP --
	verify_level_wip = function(verify)
		if verify.pass == 1 then
			local names = {}

			for id, block in ipairs(Blocks) do
				if block then
					if events.CheckForNameDups("event block", verify, names, block.info) then
						return
					else
						event_blocks.EditorEvent(block.info.type, "verify", verify, block, block.rep)--Blocks, id) TODO: Is this okay?)
					end
				end
			end
		end
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M