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
local common_ui = require("s3_editor.CommonUI")
local help = require("s3_editor.Help")
local layout = require("corona_ui.utils.layout")
local touch = require("corona_ui.utils.touch")

-- Corona globals --
local display = display

-- Exports --
local M = {}

-- --
local Group

-- --
local Tagged

-- --
local X, Y = 120, 80

---
-- @pgroup view X
function M.Load (view)
	--
	Group, Tagged = display.newGroup(), {}

	view:insert(Group)

	local cont = display.newContainer(display.contentWidth - (X + 10), display.contentHeight - (Y + 10))

	Group:insert(cont)

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

	--
	local group, cw, ch = display.newGroup(), cont.width, cont.height

	cont:insert(group)

	group:translate(-cw / 2, -ch / 2)

--	local aa = display.newCircle(group, 20, 60, 35)
--	local bb = display.newCircle(group, 300, 200, 20)

	layout.PutRightOf(cont, X, 5)
	layout.PutBelow(cont, Y, 5)

	-- Draggable thing...
	local drag = display.newRect(Group, cont.x, cont.y, cw, ch)

	drag:addEventListener("touch", touch.DragViewTouch(group))

	drag.isHitTestable, drag.isVisible = true, false

	--
	common_ui.Frame(cont, 1, 0, 1)

	--
	Group.isVisible = false

	help.AddHelp("Link", { cont = cont })
	help.AddHelp("Link", {
		cont =  "Drag boxes to move them, or the background to move the world. Links can be established by dragging from an " ..
				"output node (on the right side) to a linkable input node (left side), or vice versa. Links are broken by " ..
				"clicking the dot on the line between the nodes. TODO: Far apart nodes"
	})
end

---
-- @pgroup view X
function M.Enter (view)
	-- Cull any dangling objects.
	local group = Group[1][1]

	for object in pairs(Tagged) do
		if object.parent then
			-- add links (do some arbitrage to not duplicate them)
		else
			Tagged[object] = nil
		end
	end

	--
	Group.isVisible = true

	help.SetContext("Link")
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