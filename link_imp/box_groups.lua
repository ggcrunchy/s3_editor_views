--- Management of various groups relevant to links.

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

--
--
--

local function AuxGroups (groups, index)
	index = index + 1

	local cur = groups[index]

	if cur then
		return index, cur
	end
end

local List1, List2

--- DOCME
function M.Iterate (box)
	List1, List2 = List2, List1

	local glist = List1

	for i = #glist, 1, -1 do
		glist[i] = nil
	end

	glist[#glist + 1] = box.m_lgroup
	glist[#glist + 1] = box.m_rgroup

	for i = 1, #(box.m_attachments or "") do
		glist[#glist + 1] = box.m_attachments[i].links
	end

	return AuxGroups, glist, 0
end

--- DOCME
function M.Load ()
	List1, List2 = {}, {}
end

--- DOCME
function M.Unload ()
	List1, List2 = nil
end

-- Export the module.
return M