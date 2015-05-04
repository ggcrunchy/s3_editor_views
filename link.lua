--- Link editing.

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

-- Some sort of cloud of groups, probably made on the fly
-- Nodes moved in and out of those as they're moved around (groups will be somewhat generous, accommodate largest size)
-- Lines in separate groups? (Must allow for large distances, in general... but could use some bounding box analysis...)
-- Search feature? (Based on tag, then on list... essentially what's available now)
-- Would the above make LinkGroup obsolete? Would it promote the search box?

-- Standard library imports --
local pairs = pairs

-- Modules --
local common = require("s3_editor.Common")
local touch = require("corona_ui.utils.touch")

-- Corona globals --
local display = display

-- Exports --
local M = {}

-- --
local Group

-- --
local Tagged

---
-- @pgroup view X
function M.Load (view)
	Group, Tagged = display.newGroup(), {}

	-- Keep a mostly up-to-date list of tagged objects.
	local links = common.GetLinks()

	links:SetAssignFunc(function(object)
		Tagged[object] = true
	end)
	links:SetRemoveFunc(function(object)
		Tagged[object] = nil
	end)

	-- TODO: ^^ Could this be deterministic?
	-- Cloud of links, etc.

	-- Draggable thing...
	local box = display.newRect(Group, 0, 0, display.contentWidth, display.contentHeight)

	box:addEventListener("touch", touch.DragParentTouch{ no_clamp = true })

	box.x = display.contentCenterX
	box.y = display.contentCenterY
	box.isHitTestable, box.isVisible = true, false

--	local aa = display.newCircle(Group, 20, 60, 35)
--	local bb = display.newCircle(Group, 300, 200, 20)

	Group.isVisible = false

	view:insert(Group)
end

---
-- @pgroup view X
function M.Enter (view)
	-- Cull any dangling objects.
	for object in pairs(Tagged) do
		if object.parent then
			-- add links (do some arbitrage to not duplicate them)
		else
			Tagged[object] = nil
		end
	end

	--

	Group.isVisible = true
end

--- DOCMAYBE
function M.Exit ()
	-- Tear down link groups

	Group.isVisible = false
end

--- DOCMAYBE
function M.Unload ()
	Group, Tagged = nil
end

-- Export the module.
return M