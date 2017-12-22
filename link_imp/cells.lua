--- Management of link view cells.

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

-- Exports --
local M = {}

-- Standard library imports --
local ceil = math.ceil
local max = math.max
local min = math.min
local next = next
local pairs = pairs

-- Modules --
local grid = require("tektite_core.array.grid")
local morton = require("number_sequences.morton")
local touch = require("corona_ui.utils.touch")

-- Corona globals --
local display = display

-- Cached module references --
local _FindFreeCell_

--
--
--

local CellDim, NCells

local function GetCells (igroup, box)
	local bbounds = box.contentBounds
	local x, y = igroup:contentToLocal(bbounds.xMin, bbounds.yMin)
	local col1, row1 = grid.PosToCell(x, y, CellDim, CellDim)
	local col2, row2 = grid.PosToCell(x + box.contentWidth, y + box.contentHeight, CellDim, CellDim)

	return max(col1 - 1, 0), max(row1 - 1, 0), max(col2 - 1, 0), max(row2 - 1, 0)
end

local Occupied

local function VisitCells (action)
	return function(igroup, box)
		local col1, row1, col2, row2 = GetCells(igroup, box)
	
		for num in morton.Morton2_LineY(col1, row1, row2) do
			for col = col1, col2 do
				local cnum = morton.MortonPairUpdate_X(num, col)

				action(Occupied[cnum], box, cnum)
			end
		end
	end
end

--- DOCME
M.AddToCell = VisitCells(function(cell, box, num)
	cell = cell or {}

	Occupied[num], cell[box] = cell, true
end)

--- DOCME
function M.FindFreeCell (last_spot)
	repeat
		last_spot = last_spot + 1

		local cell = Occupied[last_spot]
	until (cell and next(cell, nil)) == nil

	return last_spot, morton.MortonPair(last_spot)
end

--- DOCME
function M.FindFreeCell_LeftOrRight (last_spot, x, how)
	local tries, ok, sx, sy = 0

	repeat
		tries, last_spot, sx, sy = tries + 1, _FindFreeCell_(last_spot)

		if how == "left_of" then
			ok = sx < x
		else
			ok = sx > x
		end
	until ok or tries == 5

	return last_spot, sx, sy
end

local VisitID = 0

--- DOCME
function M.GatherVisibleBoxes (xoff, yoff, list)
	local count, col1, row1 = 0, grid.PosToCell(xoff, yoff, CellDim, CellDim)

	for num in morton.Morton2_LineY(col1 - 1, row1 - 1, row1 + NCells - 2) do
		for i = 0, NCells - 1 do
			local cell = Occupied[num]

			if cell then
				for box in pairs(cell) do
					if box.m_visit_id ~= VisitID then
						list[count + 1], count, box.m_visit_id = box, count + 1, VisitID
					end
				end
			end

			num = morton.MortonPairUpdate_X(num, col1 + i)
		end
	end

	for i = #list, count + 1, -1 do
		list[i] = nil
	end

	VisitID = VisitID + 1
end

local CellFrac

--- DOCME
function M.Load (cont)
	CellDim, Occupied = ceil(CellFrac * min(cont.width, cont.height)), {}
end

--- DOCME
function M.NewBox (group, w, h, radius)
	return display.newRoundedRect(group, 0, 0, w, h, radius)
end

--- DOCME
function M.PutBoxAt (box, x, y, how)
	if how ~= "raw" then
		box.parent:translate((x + .5) * CellDim, (y + .5) * CellDim)
	else
		box.parent:translate(x, y)
	end

	touch.Spoof(box) -- trigger began / ended logic
end

--- DOCME
M.RemoveFromCell = VisitCells(function(cell, box)
	if cell then
		cell[box] = nil
	end
end)

--- DOCME
function M.SetCellFraction (frac)
	CellFrac, NCells = frac, ceil(1 / frac) + 1
end

--- DOCME
function M.Unload ()
	Occupied = nil
end

-- Cache module members.
_FindFreeCell_ = M.FindFreeCell

-- Export the module.
return M