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
local pairs = pairs

-- Modules --
local args = require("iterator_ops.args")
local common = require("s3_editor.Common")
local dialog = require("s3_editor.Dialog")
local editor_strings = require("config.EditorStrings")
local event_blocks = require("s3_utils.event_blocks")
local events = require("s3_editor.Events")
local grid = require("s3_editor.Grid")
local help = require("s3_editor.Help")
local layout = require("corona_ui.utils.layout")
local strings = require("tektite_core.var.strings")
local touch = require("corona_ui.utils.touch")

-- Corona globals --
local display = display

-- Exports --
local M = {}

--
--
--

-- --
local Choices

-- --
local Option

-- --
local Blocks

-- --
local Handles

-- --
local TileIDs

-- --
local Types

-- --
local Dialog = dialog.DialogWrapper(event_blocks.EditorEvent)

-- --
local CanFill, Name, ID

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
			TileIDs[strings.PairToKey(col, row)] = nil
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
local function AlignToBlock (block)
	local rep, frame = block.rep, block.m_frame

	layout.LeftAlignWith(block.m_ul, rep)
	layout.TopAlignWith(block.m_ul, rep)
	layout.RightAlignWith(block.m_lr, rep)
	layout.BottomAlignWith(block.m_lr, rep)

	frame.x, frame.width = rep.x - .5, rep.width - 3
	frame.y, frame.height = rep.y - .5, rep.height - 3
end

--
local function UpdateBlock (block)
	WipeBlock(block)

	block.col1, block.row1, block.col2, block.row2 = GetColsRows()

	TouchBlock(block, "fill", Name)
	AlignToBlock(block)
end

--
local HandleTouch = touch.TouchHelperFunc(function(_, handle)
	local block = Blocks[handle.m_id]

	Col1, Col2, Row1, Row2 = block.col1, block.col2, block.row1, block.row2
	block.oldc1, block.oldc2, block.oldr1, block.oldr2 = Col1, Col2, Row1, Row2
end, function(event, handle)
	CanFill, ID, Name = true, handle.m_id, handle.m_name

	Grid:TouchXY(event.xStart, event.yStart, event.x, event.y)

	UpdateBlock(Blocks[ID])
end, function(_, handle)
	local block = Blocks[handle.m_id]

	CanFill, ID, Name = nil

	if block.col1 ~= block.oldc1 or block.row1 ~= block.oldr1 or block.col2 ~= block.oldc2 or block.row2 ~= block.oldr2 then
		common.Dirty()
	end
end)

--
local function AddHandle (block, name, id)
	local handle = display.newCircle(Handles, 0, 0, 12)

	handle:addEventListener("touch", HandleTouch)
	handle:setFillColor(1, 0, 0, .15)
	handle:setStrokeColor(0, 0, 1, .5)

	handle.strokeWidth = 3

	handle.m_id = id
	handle.m_name = name

	block["m_" .. name] = handle
end

--
local Cell

-- --
local Options = { "Paint", "Move", "Edit", "Stretch", "Erase" }

-- --
local HelpContext

---
-- @pgroup view X
function M.Load (view)
	Blocks, TileIDs, Grid = {}, {}, grid.NewGrid()

	Grid:addEventListener("cell", Cell)

	Handles = display.newGroup()
	Handles.isVisible = false

	Grid:GetCanvas():insert(Handles)

	--
	Types = event_blocks.GetTypes()

	--
	local block_column, editor_event = {}, event_blocks.EditorEvent

	for i, name in ipairs(Types) do
		block_column[#block_column + 1] = { id = i, filename = editor_event(name, "get_thumb_filename") }
	end

	HelpContext = help.NewContext()
	Choices = common.AddCommandsBar{
		title = "Event block commands", help_context = HelpContext,

		"Mode:", { column = Options, column_width = 60 }, "m_mode", editor_strings("event_block_mode"),
		"Block:", {
			column = block_column, column_width = 40, image_width = 20, image_height = 20
		}, "m_block", editor_strings("event_block_cur")
	}

	Choices.m_mode:addEventListener("item_change", function(event)
		local label = event.text

		if Option ~= label then
			grid.SetDraggable(label == "Move")

			Handles.isVisible = label == "Stretch"

			if Option == "Edit" then
				Dialog("close")
			end

			Option = label
		end
	end)

	Choices.isVisible, Option = false, "Paint"

	view:insert(Choices)
	HelpContext:Register()
	HelpContext:Show(false)
end

--
local function AddRep (group, block, type)
	local tag = Dialog("get_tag", type)

	if tag then
		local rep = display.newImage(group, event_blocks.EditorEvent(block.info.type, "get_thumb_filename"))

		common.BindRepAndValuesWithTag(rep, block.info, tag, Dialog)

		block.rep = rep

		local frame = display.newRect(group, 0, 0, 1, 1)

		frame:setFillColor(0, 0)
		frame:setStrokeColor(0, 0, 1)

		frame.strokeWidth = 3

		block.m_frame = frame

		AddHandle(block, "ul", ID)
		AddHandle(block, "lr", ID)
		TouchBlock(block, "fill")
		AlignToBlock(block)
	end
end

--
local function CheckCol (col, rfrom, rto)
	for row = rfrom, rto do
		local id = TileIDs[strings.PairToKey(col, row)]

		if id and id ~= ID then
			return
		end
	end

	return true
end

--
local function CheckRow (row, cfrom, cto)
	for col = cfrom, cto do
		local id = TileIDs[strings.PairToKey(col, row)]

		if id and id ~= ID then
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
	local id = TileIDs[key]

	--
	if Name == "fill" then
		id = ID or id
		TileIDs[key] = id

		local block = Blocks[id]
		local rep = block.rep

		if col == block.col1 and row == block.row1 then
			rep.x, rep.y = event.x, event.y
		end

		if col == block.col2 and row == block.row2 then
			local x1, x2 = rep.x, event.x
			local y1, y2 = rep.y, event.y

			rep.x, rep.y = (x1 + x2) / 2, (y1 + y2) / 2

			local gw, gh = event.target:GetCellDims()

			rep.width = (block.col2 - block.col1 + 1) * gw
			rep.height = (block.row2 - block.row1 + 1) * gh
		end
		
	elseif Option == "Paint" then
		if not id then
			ID = FindFreeID()

			local btype = Types[Choices.m_block:GetSelection("id")]

			Blocks[ID] = { col1 = col, row1 = row, col2 = col, row2 = row, info = Dialog("new_values", btype, ID) }

			AddRep(event.target:GetCanvas(), Blocks[ID], btype)

			ID = nil

			common.Dirty()
		end

	--
	elseif Option == "Edit" then
		if id then
			Dialog("edit", Blocks[id].info, Choices.parent, id)
		else
			Dialog("close")
		end

	--
	elseif Option == "Erase" then
		local block = Blocks[id]

		if block then
			WipeBlock(block)

			common.BindRepAndValues(block.rep, nil)

			block.rep:removeSelf()

			for _, name in args.Args("m_frame", "m_ul", "m_lr", "rep") do
				block[name]:removeSelf()
			end

			Blocks[id] = false

			common.Dirty()
		end

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
	common.ShowCurrent(Choices, Options)

	Handles.isVisible = Option == "Stretch"

	HelpContext:Show(true)
end

--- DOCMAYBE
function M.Exit ()
	Dialog("close")

	Handles.isVisible = false

	common.ShowCurrent(Choices, false)
	grid.Show(false)

	HelpContext:Show(false)
end

--- DOCMAYBE
function M.Unload ()
	Grid, Handles, HelpContext, Option, Blocks, TileIDs, Types = nil
end

--
local function NewBlock (block, info)
	return { col1 = block.col1, row1 = block.row1, col2 = block.col2, row2 = block.row2, info = info }
end

for k, v in pairs{
	-- Build Level --
	build_level = function(level)
		local builds

		for _, block in ipairs(level.event_blocks.blocks) do
			if block then
				builds = events.BuildEntry(level, event_blocks, block.info, builds)

				local new = builds[#builds]

				for k, v in pairs(block) do
					if k ~= "info" then
						new[k] = v
					end
				end
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

				AddRep(Grid:GetCanvas(), Blocks[#Blocks], block.info.type)

				Option, ID = "Paint"

				events.LoadValuesFromEntry(level, event_blocks, Blocks[#Blocks].info, block.info)
			else
				Blocks[#Blocks + 1] = false
			end
		end

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

			for _, block in ipairs(Blocks) do
				if block then
					if events.CheckForNameDups("event block", verify, names, block.info) then
						return
					else
						event_blocks.EditorEvent(block.info.type, "verify", verify, block, block.rep)
					end
				end
			end
		end
	end
} do
	Runtime:addEventListener(k, v)
end

return M