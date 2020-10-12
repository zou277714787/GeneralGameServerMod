--[[
Title: ScrollBar
Author(s): wxa
Date: 2020/8/14
Desc: 滚动条
-------------------------------------------------------
local ScrollBar = NPL.load("Mod/GeneralGameServerMod/App/ui/Core/Window/Controls/ScrollBar.lua");
-------------------------------------------------------
]]

local Element = NPL.load("../Element.lua", IsDevEnv);
local ScrollBarDebug = GGS.Debug.GetModuleDebug("ScrollBarDebug");

local defaultScrollBarSize = 10;

local function GetPxValue(val)
    if (type(val) ~= "string") then return val end
    return tonumber(string.match(val, "[%+%-]?%d+"));
end

local ScrollBarButton = commonlib.inherit(Element, {});
function ScrollBarButton:ctor()
    self:SetName("ScrollBarButton");
    self:SetBaseStyle({NormalStyle = {}});
end

function ScrollBarButton:Init(xmlNode, window)
    ScrollBarButton._super.Init(self, xmlNode, window);

    local ScrollBarDirection = self:GetAttrValue("ScrollBarDirection");
    local NormalStyle = self:GetBaseStyle().NormalStyle;
    NormalStyle["position"] = "absolute";
    NormalStyle["width"] = ScrollBarDirection == "horizontal" and defaultScrollBarSize or "100%";
    NormalStyle["height"] = ScrollBarDirection == "horizontal" and "100%" or defaultScrollBarSize;

    if (self:GetTagName() == "ScrollBarPrevButton") then
        NormalStyle["left"] = "0px";
        NormalStyle["top"] = "0px";
    else
        NormalStyle["right"] = "0px";
        NormalStyle["bottom"] = "0px";
    end

    self:InitStyle();

    return self;
end

local ScrollBarThumb = commonlib.inherit(Element, {});
ScrollBarThumb:Property("ScrollBar");  -- 所属ScrollBar
ScrollBarThumb:Property("BaseStyle", {
    NormalStyle = {
        ["position"] = "absoulte",
        ["background-color"] = "#ffffff",
    }
});

function ScrollBarThumb:ctor()
    self:SetName("ScrollBarThumb");
    self.left, self.top, self.width, self.height = 0, 0, 0, 0;
    self.maxLeft, self.maxTop, self.maxWidth, self.maxHeight = 1, 1, 0, 0;
end

function ScrollBarThumb:Init(xmlNode, window)
    ScrollBarThumb._super.Init(self, xmlNode, window);
    self:InitStyle();
    return self;
end

function ScrollBarThumb:OnAfterUpdateLayout()
    local width, height = self:GetSize();
    width = if_else(not width or width == 0, self.maxWidth - 2, width);
    height = if_else(not height or height == 0, self.maxHeight - 2, height);

    if (self:GetScrollBar():IsHorizontal()) then
        self.width, self.height = self.width, math.min(height, self.maxHeight);
        self.left, self.top = math.max(0, math.min(self.left, self.maxLeft)), (self.maxHeight - self.height) / 2;
    else
        self.width, self.height = math.min(width, self.maxWidth), self.height;
        self.left, self.top = (self.maxWidth - self.width) / 2, math.max(0, math.min(self.top, self.maxTop));
    end
    
    self:SetGeometry(self.left, self.top, self.width, self.height);
end

function ScrollBarThumb:OnMouseDown(event)
    if(event:isAccepted()) then return end
    if (event:button() ~= "left") then return end

    self.isMouseDown = true;
    self.lastX, self.lastY = event:screenPos():get();
    self.startX, self.startY = self.lastX, self.lastY;
    self:CaptureMouse();
    
    event:accept();
end

function ScrollBarThumb:OnMouseMove(event)
    if(event:isAccepted()) then return end
    
	if(self.isMouseDown and event:button() == "left") then
        local x, y = event:screenPos():get();
        if (self:GetScrollBar():IsHorizontal()) then
            self.left = self.left + x - self.lastX;
            self.left = math.max(0, math.min(self.left, self.maxLeft));
            self.lastX = x;
            if (math.abs(y - self.startY) > 30 or math.abs(x - self.startX) > self.maxLeft) then 
                self:ReleaseMouseCapture();
                self.isMouseDown = false;
            end
        else
            self.top = self.top + y - self.lastY;
            self.top = math.max(0, math.min(self.top, self.maxTop));
            self.lastY = y;
            if (math.abs(x - self.startX) > 30 or math.abs(y - self.startY) > self.maxTop) then 
                self:ReleaseMouseCapture();
                self.isMouseDown = false;
            end
        end
        self:SetPosition(self.left, self.top);
        self:GetScrollBar():OnScroll();
		event:accept();
	end
end

function ScrollBarThumb:OnMouseUp(event)
    if(event:isAccepted()) then return end

    if (self.isMouseDown) then
        self.isMouseDown = false;
        self:ReleaseMouseCapture();
        event:accept();
    end
end

function ScrollBarThumb:SetThumbWidthHeight(width, height, scrollBarWidth, scrollBarHeight)
    local style = self:GetStyle();
    self.maxWidth, self.maxHeight = scrollBarWidth, scrollBarHeight;
    if (self:GetScrollBar():IsHorizontal()) then
        self.width = width;
        self.height = GetPxValue(style["height"]) or (height > 2 and (height - 2) or height);
        self.maxLeft = math.max(scrollBarWidth - width, 1);
    else
        self.width = GetPxValue(style["width"]) or (width > 2 and (width - 2) or width);
        self.height = height;
        self.maxTop = math.max(scrollBarHeight - height, 1);
    end
    style["width"], style["height"] = self.width, self.height;
end

function ScrollBarThumb:ScrollByDelta(delta)
    if (self:GetScrollBar():IsHorizontal()) then
        self.left = self.left - self.width * delta / 10;
        self.left = math.max(0, math.min(self.left, self.maxLeft));
    else
        self.top = self.top - self.height * delta / 10;
        self.top = math.max(0, math.min(self.top, self.maxTop));
    end
    self:SetPosition(self.left, self.top);
    self:GetScrollBar():OnScroll();
end

function ScrollBarThumb:ScrollTo(left, top)
    if (self:GetScrollBar():IsHorizontal()) then
        self.left = left or 0;
        self.left = math.max(0, math.min(self.left, self.maxLeft));
    else
        self.top = top or 0;
        self.top = math.max(0, math.min(self.top, self.maxTop));
    end
    self:SetPosition(self.left, self.top);
    self:GetScrollBar():OnScroll();
end

local ScrollBarTrack = commonlib.inherit(Element, {});
function ScrollBarTrack:ctor()
    self:SetName("ScrollBarTrack");
end

function ScrollBarTrack:Init(xmlNode, window)
    ScrollBarThumb._super.Init(self, xmlNode, window);
    self:InitStyle();
    return self;
end

local ScrollBar = commonlib.inherit(Element, NPL.export());
ScrollBar:Property("Direction");  -- 方向         
ScrollBar:Property("DefaultWidth", 10);                      
ScrollBar:Property("BaseStyle", {
    NormalStyle = {
        ["position"] = "relative",
        ["background-color"] = "#000000",
    }
});

function ScrollBar:ctor()
    self:SetName("ScrollBar");
    self.left, self.top, self.width, self.height = 0, 0, 0, 0;
    self.scrollTop, self.contentHeight, self.scrollHeight, self.clientHeight = 0, 0, 0, 0;
    self.scrollLeft, self.contentWidth, self.scrollWidth, self.clientWidth = 0, 0, 0, 0;
    self.thumbSize = 0;
end

function ScrollBar:IsHorizontal()
    return self:GetDirection() == "horizontal";
end

function ScrollBar:Init(xmlNode, window)
    ScrollBar._super.Init(self, xmlNode, window);
    self:InitStyle();

    self:SetDirection(self:GetAttrValue("direction") or "horizontal"); -- horizontal  vertical
    self.prevButton = ScrollBarButton:new():Init({name = "ScrollBarPrevButton", attr = {ScrollBarDirection = self:GetDirection()}}, window);
    self.track = ScrollBarTrack:new():Init({name = "ScrollBarTrack"}, window);
    self.thumb = ScrollBarThumb:new():Init({name = "ScrollBarThumb"}, window);
    self.nextButton = ScrollBarButton:new():Init({name = "ScrollBarNextButton", attr = {ScrollBarDirection = self:GetDirection()}}, window);
    -- self.trackPiece = Element:new():Init({name = "ScrollBarTrackPiece"}, window);
    -- self.corner = Element:new():Init({name = "ScrollBarTrackCorner"}, window);
    -- self.resizer = Element:new():Init({name = "ScrollBarTrackResizer"}, window);
    table.insert(self.childrens, self.prevButton);
    self.prevButton:SetParentElement(self);
    table.insert(self.childrens, self.track);
    self.track:SetParentElement(self);
    table.insert(self.childrens, self.thumb);
    self.thumb:SetParentElement(self);
    self.thumb:SetScrollBar(self);
    table.insert(self.childrens, self.nextButton);
    self.nextButton:SetParentElement(self);

    return self;
end

function ScrollBar:SetScrollWidthHeight(clientWidth, clientHeight, contentWidth, contentHeight, scrollWidth, scrollHeight)
    self.clientWidth, self.clientHeight, self.contentWidth, self.contentHeight, self.scrollWidth, self.scrollHeight = clientWidth or 0, clientHeight or 0, contentWidth or 0, contentHeight or 0, scrollWidth or 0, scrollHeight or 0;

    -- 选择当前样式
    self:SelectStyle();

    local style = self:GetStyle();
    local thumbSize, defaultScrollBarSize = 0, self:GetDefaultWidth();

    self.width = GetPxValue(style["width"]);
    self.height = GetPxValue(style["height"]);
    
    if (self:IsHorizontal()) then
        self.width = self.clientWidth;
        self.height = self.height or defaultScrollBarSize;
        if (self.scrollWidth > 0 and self.clientWidth > 0) then
            thumbSize = math.floor(self.clientWidth / self.scrollWidth * self.contentWidth);
        end
        self.thumb:SetThumbWidthHeight(thumbSize, self.height, self.width, self.height);
    else
        self.width = self.width or defaultScrollBarSize;
        self.height = self.clientHeight;
        if (self.scrollHeight > 0 and self.clientHeight > 0) then
            thumbSize = math.floor(self.clientHeight / self.scrollHeight * self.contentHeight);
        end
        self.thumb:SetThumbWidthHeight(self.width, thumbSize, self.width, self.height);
    end
    
    self.thumbSize = thumbSize;
    self:OnScroll();
    style["width"], style["height"] = self.width, self.height;

    self:UpdateLayout();

    -- ScrollBarDebug.Format("SetScrollWidthHeight direction = %s, width = %s, height = %s, thumbSize = %s", self:GetDirection(), self.width, self.height, thumbSize);
end

-- 滚动位置计算
function ScrollBar:OnScroll()
    local thumb = self.thumb;
    if (self:IsHorizontal()) then
        self.scrollLeft = self.thumb.left / self.thumb.maxLeft * (self.scrollWidth - self.contentWidth);
        self:SetX(self.scrollLeft);
    else 
        self.scrollTop = self.thumb.top / self.thumb.maxTop * (self.scrollHeight - self.contentHeight);
        self:SetY(self.scrollTop);
    end
end

-- 布局更新完成重置元素几何大小
function ScrollBar:OnAfterUpdateLayout()
    local width, height = self:GetSize();
    width = if_else(not width or width == 0, self:GetDefaultWidth(), width);
    height = if_else(not height or height == 0, self:GetDefaultWidth(), height);
    if (self:IsHorizontal()) then
        self.width, self.height = self.width, height;
        self.left, self.top = self.left, self.clientHeight - self.height;
    else 
        self.width, self.height = width, self.height;
        self.left, self.top = self.clientWidth - self.width, self.top;
    end
    self:SetGeometry(self.left, self.top, self.width, self.height);
    -- ScrollBarDebug.Format("SetScrollWidthHeight direction = %s, left = %s, top = %s, width = %s, height = %s", self:GetDirection(), self.left, self.top, self.width, self.height);
end

-- 鼠标滚动事件
function ScrollBar:OnMouseWheel(event)
    local delta = event:GetDelta();  -- 1 向上滚动  -1 向下滚动
    self.thumb:ScrollByDelta(delta);
end

-- 鼠标点击事件
function ScrollBar:OnMouseDown(event)
    local pos = event:pos();
    self.thumb:ScrollTo(pos:x() - self.scrollLeft - self.thumbSize / 2, pos:y() - self.scrollTop - self.thumbSize / 2);
end

-- 滚动到指定位置
function ScrollBar:ScrollTo(val)
    if (self:IsHorizontal()) then 
        self.thumb:ScrollTo(val / (self.scrollWidth - self.contentWidth) * self.thumb.maxLeft , nil);
    else 
        self.thumb:ScrollTo(nil, val / (self.scrollHeight - self.contentHeight) * self.thumb.maxTop);
    end
end
