--- Management of layouts for link view boxes.

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
local max = math.max
local min = math.min

-- Modules --
local layout = require("corona_ui.utils.layout")

-- Corona globals --
local display = display

-- Cached module references --
local _Arrange_
local _GetLineWidth_
local _GetY1_
local _LeftAndRight_

-- Exports --
local M = {}

--
--
--

--- DOCME
function M.AddLine (group, left_object, right_object, spacing, lowest)
	local w, line, n = _GetLineWidth_(left_object, right_object), (group.m_line or 0) + 1, group.numChildren

	group.m_w = max(group.m_w or 0, w)

	for i = (group.m_last_count or 0) + 1, group.numChildren do
		local object = group[i]

		if line > 1 then
			layout.PutBelow(object, group.m_prev, spacing)
		else
			group.m_y1 = min(group.m_y1 or 0, _GetY1_(object))
		end
	--	object.m_w = w
	end

	group.m_last_count, group.m_line, group.m_prev = n, line, lowest
end

--- DOCME
function M.Append (box, instance)
	-- row with these elements
		-- delete
		-- "key:" (possible, in sets), just a label
		-- text field (sets, to assign key) or number (arrays, to mark position)
		-- link
end

--- DOCME
function M.Arrange (is_source, offset, a, b, c, d, e, f)
	local method

	if is_source then
		method, offset = layout.PutLeftOf, -offset
	else
		method = layout.PutRightOf
	end

	if b then
		method(b, a, offset)
	end

	if c then
		method(c, b, offset)
	end

	if d then
		method(d, c, offset)
	end

	if e then
		method(e, d, offset)
	end

	if f then
		method(f, e, offset)
	end

	return _LeftAndRight_(is_source, a, b, c, d, e, f)
end

local LeftAndRightGroup

--- DOCME
function M.ChooseLeftOrRightGroup (bgroup, is_source)
	local gi = is_source and 2 or 1

	if not LeftAndRightGroup[gi] then
		LeftAndRightGroup[gi] = display.newGroup()

		bgroup:insert(LeftAndRightGroup[gi])
	end

	return LeftAndRightGroup[gi]
end

--[[
TODO: might be superfluous

local function Align (group, is_rgroup)
	local w = group.m_w

	for i = 1, group.numChildren do
		local object = group[i]
		local dx = w - object.m_w

		if is_rgroup then
			object.x = object.x + dx
		else
			object.x = object.x - dx
		end
	end
end
]]

--- DOCME
function M.CommitLeftAndRightGroups (box, hmargin, vmargin)
	local lgroup, rgroup = LeftAndRightGroup[1], LeftAndRightGroup[2]
	local hw, y1 = box.width / 2 - hmargin, _GetY1_(box) + vmargin
--[[
	TODO: unnecessary?

	Align(lgroup, false)
	Align(lgroup, true)
]]
	if lgroup then
		box.m_lgroup, lgroup.x, lgroup.y = lgroup, box.x - hw, y1
	end

	if rgroup then
		box.m_rgroup, rgroup.x, rgroup.y = rgroup, box.x + hw, y1
		rgroup.anchorX = 1
	end

	LeftAndRightGroup[1], LeftAndRightGroup[2] = nil
end

--- DOCME
function M.GetLineWidth (left_object, right_object)
	return layout.RightOf(right_object) - layout.LeftOf(left_object)
end

local function FindBottom (group)
	local y2, n = 0, group.numChildren
	local line = n > 0 and group[n].m_line

	for i = n, 1, -1 do
		local object = group[i]

		if object.m_line ~= line then
			break
		else
			y2 = max(y2, object.y + object.height / 2)
		end
	end

	return y2
end

--- DOCME
function M.GetSize ()
	local lgroup, rgroup = LeftAndRightGroup[1], LeftAndRightGroup[2]
	local w, y1, y2 = lgroup and lgroup.m_w or 0, 0, 0

	if lgroup and rgroup then
		w = w + rgroup.m_w
		y1 = min(lgroup.m_y1, rgroup.m_y1)
		y2 = max(FindBottom(lgroup), FindBottom(rgroup))
	elseif lgroup then
		y1, y2 = lgroup.m_y1, FindBottom(lgroup)
	elseif rgroup then
		w, y1, y2 = rgroup.m_w, rgroup.m_y1, FindBottom(rgroup)
	end

	return w, y2 - y1
end

--- DOCME
function M.GetY1 (object)
	return object.y - object.height / 2
end

local function AuxGroups (groups, index)
	index = index + 1

	local cur = groups[index]

	if cur then
		return index, cur
	end
end

local List1, List2

--- DOCME
function M.IterateGroupsOfLinks (box)
	List1, List2 = List2, List1

	local glist = List1

	for i = #glist, 1, -1 do
		glist[i] = nil
	end

	glist[#glist + 1] = box.m_lgroup
	glist[#glist + 1] = box.m_rgroup

	for i = 1, #(box.m_attachments or "") do
		glist[#glist + 1] = box.m_attachments[i].parent.links
	end

	return AuxGroups, glist, 0
end

--- DOCME
function M.LeftAndRight (is_source, a, b, c, d, e, f)
	local last = f or e or d or c or b or a

	if is_source then
		return last, a
	else
		return a, last
	end
end

--- DOCME
function M.Load ()
	LeftAndRightGroup, List1, List2 = {}, {}, {}
end

--- DOCME
function M.RemoveRow (box, row)
	-- for each object with row = row
		-- find minimum y
		-- remove element
	-- remove links[row]
	-- more rows?
		-- dy = min y - prev min y
	-- else
		-- dy = difference to bottom margin
	-- for each remaining row
		-- move all elements up by dy
		-- decrement row
		-- same for links[row], but move back slot
	-- shrink heights by dy
	-- ^^^ some similar stuff for Append
	-- in arrays, enable or disable arrows as necessary
		-- for that matter, leave these in place and only remove last row, avoiding need to update index
end

--- DOCME
function M.SwapRows (box, row1, row2)
	-- very basic if rows are fixed size, otherwise need to pull up below max(row1, row2) and 
		-- pull down beyond min(row1, row2)...
	-- fixed size sounding pretty good, actually... just need to account for numbers? (not sure how text field looks)
	-- in first case just swap positions (plus row values) and entries in links
		-- leave arrows in place (enable, disable etc.)
	-- aside from link could maybe just edit the contents of each element, rather than moving them
	-- loop must take some care, since ranges could be adjacent
		-- but will always be same number of elements for format (array or set)? (just make arrows invisible on top / bottom row)
		-- ^^^ If so could use these counts to find position instead
end

--- DOCME
function M.Unload ()
	LeftAndRightGroup, List1, List2 = nil
end

--- DOCME
function M.UpdateWidth (box, w)
	-- TODO!
	-- basically: names can change, potentially overflowing the box...
	-- but could later shorten, too
end

-- Cache module members.
_Arrange_ = M.Arrange
_GetLineWidth_ = M.GetLineWidth
_GetY1_ = M.GetY1
_LeftAndRight_ = M.LeftAndRight

-- Export the module.
return M