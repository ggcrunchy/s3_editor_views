--- Management of link view connections.

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
local pairs = pairs

-- Modules --
local box_layout = require("s3_editor_views.link_imp.box_layout")
local common = require("s3_editor.Common")
local link_group = require("corona_ui.widgets.link_group")
local objects = require("s3_editor_views.link_imp.objects")

--
--
--

local LinkGroup
 
--- DOCME
function M.AddLink (id, is_source, link)
	LinkGroup:AddLink(id, not is_source, link)
end

local KnotLists

--- DOCME
function M.AddKnotList (id)
	KnotLists[id] = {}
end

local function Connect (_, link1, link2, knot)
	local links, klink = common.GetLinks()
	local obj1, obj2 = link1.m_obj, link2.m_obj

	for link in links:Links(obj1, link1.m_sub) do
		if link:GetOtherObject(obj1) == obj2 then
			klink = link
		end
	end
-- TODO: ^^^^ this might not be flexible enough, actually
	knot.m_link = klink or links:LinkObjects(link1.m_obj, link2.m_obj, link1.m_sub, link2.m_sub)

	local id1, id2 = link_group.GetLinkInfo(link1), link_group.GetLinkInfo(link2)
	local kl1, kl2 = KnotLists[id1], KnotLists[id2]

	knot.m_id1, knot.m_id2 = id1, id2
	kl1[knot], kl2[knot] = true, true
-- TODO: rather than use knot here, use say strings.PairToKey(id1, id2) here, since
-- presumably it's more robust after Redo or Undo
	common.Dirty()
end

local function GetList (id)
	return KnotLists[id] or KnotLists	-- use KnotLists to avoid special-casing failure case
										-- KnotLists[knot] is already absent, so nil'ing it is a no-op
end

local KnotTouch = link_group.BreakTouchFunc(function(knot)
	knot.m_link:Break()

	GetList(knot.m_id1)[knot], GetList(knot.m_id2)[knot] = nil
-- TODO: see TODO in Connect
	common.Dirty()
end)

local DoingLinks

--
local function FindLink (box, sub)
	for _, group in box_layout.IterateGroupsOfLinks(box) do
		for i = 1, group.numChildren do
			local item = group[i]

			if item.m_sub == sub then
				return item
			end
		end
	end
end

--
local function DoLinks (links, group, object)
	for i = 1, group.numChildren do
		local link1 = group[i]
		local lsub = link1.m_sub

		if lsub then
			for link in links:Links(object, lsub) do
				DoingLinks = DoingLinks or {}

				if not DoingLinks[link] then
					local other, osub = link:GetOtherObject(object)
					local knot = LinkGroup:ConnectObjects(link1, FindLink(objects.GetBox(other), osub))

					knot.m_link, DoingLinks[link] = link, true
				end
			end
		end
	end
end

--- DOCME
function M.ConnectObject (object)
	local links = common.GetLinks()

	for _, group in box_layout.IterateGroupsOfLinks(objects.GetBox(object)) do
		DoLinks(links, group, object)
	end
end

--- DOCME
function M.FinishConnecting ()
	DoingLinks = false
end

--- DOCME
function M.LinkAttachment (link, attachment)
	link_group.Connect(link, attachment.primary, false, LinkGroup:GetGroups())

	link.alpha, attachment.primary.alpha = .025, .025
end

--- DOCME
function M.Load (group, emphasize, gather)
	LinkGroup, KnotLists, DoingLinks = link_group.LinkGroup(group, Connect, KnotTouch, {
		can_link = function(link1, link2)
			return DoingLinks or common.GetLinks():CanLink(link1.m_obj, link2.m_obj, link1.m_sub, link2.m_sub)
		end, emphasize = emphasize, gather = gather
	}), {}, false
end

--- DOCME
function M.RemoveKnotList (id)
	local list = KnotLists[id]

	if list then -- attachments will share primary's list
		for knot in pairs(list) do
			link_group.Break(knot)
		end
	end

	KnotLists[id] = nil
end

--- DOCME
function M.Unload ()
	LinkGroup, KnotLists = nil
end

-- Export the module.
return M