--[[
Title: TextArea
Author(s): wxa
Date: 2020/8/14
Desc: 文本编辑器
-------------------------------------------------------
local TextArea = NPL.load("Mod/GeneralGameServerMod/App/ui/Core/Window/Elements/TextArea.lua");
-------------------------------------------------------
]]
NPL.load("(gl)script/ide/System/Core/UniString.lua");
NPL.load("(gl)script/ide/math/Rect.lua");
local Rect = commonlib.gettable("mathlib.Rect");
local UniString = commonlib.gettable("System.Core.UniString");
local Keyboard = commonlib.gettable("System.Windows.Keyboard");
local FocusPolicy = commonlib.gettable("System.Core.Namespace.FocusPolicy");
local Point = commonlib.gettable("mathlib.Point");

local Element = NPL.load("../Element.lua", IsDevEnv);

local TextArea = commonlib.inherit(Element, NPL.export());

local TextAreaDebug = GGS.Debug.GetModuleDebug("TextAreaDebug").Disable();   --Enable  Disable
local CursorShowHideMaxTickCount = 30;

TextArea:Property("Value");                                    -- 文本值
TextArea:Property("RowCount", 2);                              -- 行数
TextArea:Property("AutoWrap", true, "IsAutoWrap");             -- 是否自动换行

TextArea:Property("ShowCursor", false, "IsShowCursor");
TextArea:Property("BaseStyle", {
    NormalStyle = {
        ["border-width"] = 1,
        ["border-color"] = "#cccccc",
        ["color"] = "#000000",
        ["height"] = 50,
        ["width"] = 100,
        ["padding-left"] = 4, 
        ["padding-right"] = 4, 
        ["padding-top"] = 2, 
        ["padding-bottom"] = 2, 
        ["overflow-y"] = "scroll",
    }
});

function TextArea:ctor()
    self:SetName("TextArea");
    self.cursorShowHideTickCount = 0;
    self.cursorX, self.cursorY, self.cursorWidth, self.cursorHeight = 0, 0, nil, nil;
    self.cursorAt = 1;    -- 光标位置 占据下一个输入位置
    self.undoCmds = {};   -- 撤销命令
    self.redoCmds = {};   -- 重做命令
    self.lines = {};      -- 所有文本行
    self.selectStartAt, self.selectEndAt = nil, nil;  -- 文本选择

    self.text = UniString:new();  -- 文本值
    self:UpdateValue();
end

-- 初始化完成
function TextArea:Init(xmlNode, window, parent)
    TextArea._super.Init(self, xmlNode, window, parent);

    self.text = UniString:new(self:GetAttrStringValue("value", ""));
    self:UpdateValue();

    return self;
end

-- 是否选择
function TextArea:IsSelected()
    return self.selectStartAt and self.selectEndAt and self.selectStartAt > 0 and self.selectEndAt > 0;  -- [selectStartAt, selectEndAt]
end

-- 获取选择
function TextArea:GetSelected()
    if (not self:IsSelected()) then return end
    if (self.selectStartAt < self.selectEndAt) then return self.selectStartAt, self.selectEndAt end
    return self.selectEndAt, self.selectStartAt;
end

-- 获取选择的文本
function TextArea:GetSelectedText()
    if (not self:IsSelected()) then return "" end
    return self.text:sub(self:GetSelected()):GetText();
end

-- 清除选择
function TextArea:ClearSelected()
    self.selectStartAt, self.selectEndAt = nil, nil;
end

function TextArea:IsReadOnly()
    return self:GetAttrBoolValue("readonly");
end

function TextArea:handleReturn()
    self:InsertTextCmd("\n", self.cursorAt);
end

function TextArea:handleEscape()
end

function TextArea:handleBackspace()
    if (self:IsSelected()) then
        self:DeleteSelected();
    else
        self:DeleteTextCmd(self.cursorAt - 1, 1);
    end
end

function TextArea:handleDelete()
    self:DeleteTextCmd(self.cursorAt, 1);
end

function TextArea:handleUndo()
    if (#self.undoCmds == 0) then return end
    local len = #self.undoCmds;
    local cmd = self.undoCmds[len];
    table.remove(self.undoCmds, len);
    table.insert(self.redoCmds, cmd);
    if (cmd.action == "insert") then
        self:DeleteText(cmd.startAt, cmd.endAt);
    elseif (cmd.action == "delete") then
        self:InsertText(cmd.startAt, cmd.endAt, cmd.text);
    end
end

function TextArea:handleRedo()
    if (#self.redoCmds == 0) then return end
    local len = #self.redoCmds;
    local cmd = self.redoCmds[len];
    table.remove(self.redoCmds, len);
    table.insert(self.undoCmds, cmd);
    if (cmd.action == "insert") then
        self:InsertText(cmd.startAt, cmd.endAt, cmd.text);
    elseif (cmd.action == "delete") then
        self:DeleteText(cmd.startAt, cmd.endAt);
    end
end

function TextArea:handleSelectAll()
    self.selectStartAt, self.selectEndAt = 1, self.text:length();
    TextAreaDebug.Format("handleSelectAll selectStartAt = %s, selectEndAt = %s", self.selectStartAt, self.selectEndAt);
end

function TextArea:handleCopy()
    if (not self:IsSelected()) then return end
    local selectedText = self:GetSelectedText();
    ParaMisc.CopyTextToClipboard(selectedText);
end

function TextArea:handleCut()
    self:handleCopy();
    self:DeleteSelected();
end

function TextArea:handlePaste()
    local clip = ParaMisc.GetTextFromClipboard();
    self:InsertTextCmd(clip)
end

function TextArea:handleHome()
end
function TextArea:handleEnd()
end

function TextArea:handleMoveToPrevLine()
    local cursorLine = self:GetCursorLine();
    if (cursorLine.line <= 1) then return end
    local lastLine = self.lines[cursorLine.line - 1];
    local cursorAt = lastLine.startAt + self.cursorAt - cursorLine.startAt;
    self.cursorAt = cursorAt > lastLine.endAt and lastLine.endAt or cursorAt;
end

function TextArea:handleMoveToNextLine()
    local cursorLine = self:GetCursorLine();
    if (cursorLine.line >= #self.lines) then return end
    local nextLine = self.lines[cursorLine.line + 1];
    local cursorAt = nextLine.startAt + self.cursorAt - cursorLine.startAt;
    self.cursorAt = cursorAt > nextLine.endAt and nextLine.endAt or cursorAt;
end

function TextArea:handleMoveToPrevChar()
    TextAreaDebug("handleMoveToPrevChar");
    self:ClearSelected();
    self:SetShowCursor(true);
    self:AdjustCursorAt(-1, "move");
end

function TextArea:handleMoveToNextChar()
    TextAreaDebug("handleMoveToNextChar");
    self:ClearSelected();
    self:SetShowCursor(true);
    self:AdjustCursorAt(1, "move");
end

function TextArea:handleSelectToPrevLine()
    
end

function TextArea:handleSelectToNextLine()
    
end

function TextArea:handleSelectNextChar()
    TextAreaDebug.Format("handleSelectNextChar Before selectStartAt = %s, selectEndAt = %s", self.selectStartAt, self.selectEndAt);
    self.selectEndAt = self.selectEndAt or self.cursorAt - 1;
    self.selectEndAt = self.selectEndAt + 1;
    self.selectEndAt = math.max(math.min(self.selectEndAt, self.text:length()), 1);
    self.selectStartAt = self.selectEndAt >= self.cursorAt and self.cursorAt or self.cursorAt -1;
    TextAreaDebug.Format("handleSelectNextChar After selectStartAt = %s, selectEndAt = %s", self.selectStartAt, self.selectEndAt);
end

function TextArea:handleSelectPrevChar()
    TextAreaDebug("handleSelectPrevChar");
    self.selectEndAt = self.selectEndAt or self.cursorAt;
    self.selectEndAt = self.selectEndAt - 1;
    self.selectEndAt = math.max(math.min(self.selectEndAt, self.text:length()), 1);
    self.selectStartAt = self.selectEndAt >= self.cursorAt and self.cursorAt or self.cursorAt -1;
end

function TextArea:handleMoveToNextWord()
end

function TextArea:handleMoveToPrevWord()
end

function TextArea:handleSelectNextWord()
end

function TextArea:handleSelectPrevWord()
end

function TextArea:OnKeyDown(event)
    if (not self:IsFocus()) then return end
    if (self:IsReadOnly()) then return end
    event:accept();

	local keyname = event.keyname;
	if (keyname == "DIK_RETURN") then self:handleReturn(event) 
	elseif (keyname == "DIK_ESCAPE") then self:handleEscape(event)
	elseif (keyname == "DIK_BACKSPACE") then self:handleBackspace(event)
	elseif (event:IsKeySequence("Undo")) then self:handleUndo(event)
	elseif (event:IsKeySequence("Redo")) then self:handleRedo(event)
	elseif (event:IsKeySequence("SelectAll")) then self:handleSelectAll(event)
	elseif (event:IsKeySequence("Copy")) then self:handleCopy(event)
	elseif (event:IsKeySequence("Paste")) then self:handlePaste(event, "Clipboard");
	elseif (event:IsKeySequence("Cut")) then self:handleCut(event)
	elseif (event:IsKeySequence("MoveToStartOfLine") or event:IsKeySequence("MoveToStartOfBlock")) then self:handleHome(event, false)
    elseif (event:IsKeySequence("MoveToEndOfLine") or event:IsKeySequence("MoveToEndOfBlock")) then self:handleEnd(event, false)
    elseif (event:IsKeySequence("SelectStartOfLine") or event:IsKeySequence("SelectStartOfBlock")) then self:handleHome(event, true)
    elseif (event:IsKeySequence("SelectEndOfLine") or event:IsKeySequence("SelectEndOfBlock")) then self:handleEnd(event, true)
    elseif (event:IsKeySequence("MoveToPreviousLine")) then self:handleMoveToPrevLine(event)
    elseif (event:IsKeySequence("MoveToNextLine")) then self:handleMoveToNextLine(event)
    elseif (event:IsKeySequence("SelectToPreviousLine")) then self:handleSelectToPrevLine(event)
    elseif (event:IsKeySequence("SelectToNextLine")) then self:handleSelectToNextLine(event)
    elseif (event:IsKeySequence("MoveToNextChar")) then self:handleMoveToNextChar(event)
	elseif (event:IsKeySequence("SelectNextChar")) then self:handleSelectNextChar(event)
	elseif (event:IsKeySequence("MoveToPreviousChar")) then self:handleMoveToPrevChar(event)
	elseif (event:IsKeySequence("SelectPreviousChar")) then self:handleSelectPrevChar(event)
	elseif (event:IsKeySequence("MoveToNextWord")) then self:handleMoveToNextWord(event)
    elseif (event:IsKeySequence("MoveToPreviousWord")) then self:handleMoveToPrevWord(event)
    elseif (event:IsKeySequence("SelectNextWord")) then self:handleSelectNextWord(event)
    elseif (event:IsKeySequence("SelectPreviousWord")) then self:handleSelectPrevWord(event)
    elseif (event:IsKeySequence("Delete")) then self:handleDelete(event)
    elseif (event:IsFunctionKey() or event.ctrl_pressed) then 
    else -- 处理普通输入
	end
end

function TextArea:OnKey(event)
    if (not self:IsFocus()) then return end
    if (self:IsReadOnly()) then return end
    event:accept();

    local commitString = event:commitString();

    -- 忽略控制字符
    local char1 = string.byte(commitString, 1);
	if(char1 <= 31) then return end
    
    -- 添加新文本
    self:InsertTextCmd(commitString);
end

-- 返回指定行文本
function TextArea:GetLineText(line)
    local line = self.lines[line];
    if (not line) then return UniString:new() end
    return self.text:sub(line.startAt, line.endAt);
end

-- 返回值指定文本长度
function TextArea:GetTextLength(text)
    return ParaMisc.GetUnicodeCharNum(text);
end

function TextArea:InsertTextCmd(text)
    -- 先删除已选择的文本
    if (self:IsSelected()) then self:DeleteSelected() end
    if (not text or text == "") then return end
    text = UniString:new(string.gsub(text, "\r", ""));
    local startAt = self.cursorAt;
    local textLength = text:length();
    local endAt = startAt + textLength - 1;
    table.insert(self.undoCmds, {startAt = startAt, endAt = endAt, action = "insert", text = text});
    TextAreaDebug.Format("InsertTextCmd before cursorAt = %s, startAt = %s, endAt = %s", self.cursorAt, startAt, endAt);
    self:InsertText(startAt, endAt, text);
    TextAreaDebug.Format("InsertTextCmd after cursorAt = %s, startAt = %s, endAt = %s", self.cursorAt, startAt, endAt);
end

function TextArea:InsertText(startAt, endAt, text)
    self.text:insert(startAt - 1, text);
    self:UpdateValue();
    if (startAt <= self.cursorAt) then self:AdjustCursorAt(endAt - startAt + 1) end
end

-- 获取位置信息
function TextArea:GetLineByAt(at)
    if (at < 1) then return self.lines[1] end
    if (at > self.text:length()) then return self.lines[#(self.lines)] end
    
    for i, line in ipairs(self.lines) do
        if (line.startAt <= at and at <= line.endAt) then return line end
    end

    return self.lines[1];
end

-- 更新文本行信息
function TextArea:UpdateLineInfo()
    local text = self.text:GetText();
    local linetexts = commonlib.split(text, "\n");
    local x, y, w, h = self:GetContentGeometry();
    local linecount, lines, line, at = #linetexts, {}, 0, 0;

    w = w - self:GetScrollBarWidth();
    if (w <= 0 or h == 0) then linecount = 0 end
    for i = 1, linecount do
        local linetext = linetexts[i];
        local trimtext, remaintext = _guihelper.TrimUtf8TextByWidth(linetext, w, self:GetFont());
        local startAt, endAt = at + 1, at + self:GetTextLength(trimtext);
        TextAreaDebug.Format("UpdateLineInfo line = %s, at = %s, startAt = %s, endAt = %s, trimtext = %s, remaintext = %s", line, at, startAt, endAt, trimtext, remaintext);
        line = line + 1;
        at = endAt;
        table.insert(lines, {line = line, startAt = startAt, endAt = endAt});
        while (remaintext and remaintext ~= "" and startAt <= endAt) do
            trimtext, remaintext = _guihelper.TrimUtf8TextByWidth(remaintext, w, self:GetFont());
            startAt, endAt = at + 1, at + self:GetTextLength(trimtext);
            line = line + 1;
            at = endAt;
            TextAreaDebug.Format("UpdateLineInfo line = %s, at = %s, startAt = %s, endAt = %s, trimtext = %s, remaintext = %s", line, at, startAt, endAt, trimtext, remaintext);
            table.insert(lines, {line = line, startAt = startAt, endAt = endAt});
        end
        -- 加一个换行符
        if (i < linecount) then
            at = at + 1; 
            lines[#lines].endAt = at;
        end
    end
    
    if (#lines == 0) then table.insert(lines, {line = 1, startAt = 1, endAt = 1}) end

    self.lines = lines;
    -- TextAreaDebug("UpdateLineInfo", text, lines);

    if (not self:GetStyle()) then return end

    local LineHeight = self:GetStyle():GetLineHeight(); 
    self:GetLayout():SetRealContentWidthHeight(w, (#lines) * LineHeight);
    self:OnRealContentSizeChange();
end

function TextArea:DeleteTextCmd(startAt, count)
    if (not startAt or not count or count == 0) then return end
    local endAt = startAt + count - 1;
    if (endAt < startAt) then startAt, endAt = endAt, startAt end
    if (endAt < 1) then return end
    startAt = math.max(startAt, 1);
    table.insert(self.undoCmds, {startAt = startAt, endAt = endAt, action = "delete", text = self.text:sub(startAt, endAt)});
    TextAreaDebug.Format("DeleteTextCmd before cursorAt = %s, startAt = %s, endAt = %s, text = %s", self.cursorAt, startAt, endAt, self:GetValue());
    self:DeleteText(startAt, endAt);
    TextAreaDebug.Format("DeleteTextCmd after cursorAt = %s, startAt = %s, endAt = %s, text = %s", self.cursorAt, startAt, endAt, self:GetValue());
end


function TextArea:DeleteSelected()
    if (not self:IsSelected()) then return end
    local selectStartAt, selectEndAt = self:GetSelected();
    self:DeleteTextCmd(selectStartAt, selectEndAt - selectStartAt + 1);
    self:ClearSelected();
end

function TextArea:DeleteText(startAt, endAt)
    local count = endAt - startAt + 1;
    if (self.cursorAt <= startAt) then
    elseif (self.cursorAt >= endAt) then self:AdjustCursorAt(-count)
    else self:AdjustCursorAt(startAt - self.cursorAt) end 
    self.text:remove(startAt, count);
    self:UpdateValue();
end

function TextArea:UpdateValue()
    local value = self.text:GetText();
    if (self:GetValue() == value) then return end
    self:UpdateLineInfo();
    self:SetValue(value);
    -- self:OnChange(value);
end

-- 调整光标的位置, 调整前文本需完整, 因此添加需先添加后调整光标, 移除需先调整光标后移除
function TextArea:AdjustCursorAt(offset)
    self.cursorAt = self.cursorAt + offset;
    self.cursorAt = math.max(self.cursorAt, 1);
    self.cursorAt = math.min(self.cursorAt, self.text:length() + 1);

    local x, y, w, h = self:GetContentGeometry();
    local line = self:GetLineByAt(self.cursorAt);
    local LineHeight = self:GetStyle():GetLineHeight(); 
    local offsetY = (line.line - 1) * LineHeight;
    local scrollValue = self:GetScrollBarValue();
    if ((offsetY + LineHeight) > h) then scrollValue = offsetY + LineHeight - h end
    if (offsetY < scrollValue) then scrollValue = offsetY end
    TextAreaDebug.Format("AdjustCursorAt offsetY = %s, scrollValue = %s, h = %s", offsetY, scrollValue, h);
    self:SetScrollBarValue(scrollValue);
end

function TextArea:GetCursorLine()
    return self:GetLineByAt(self.cursorAt);
end

function TextArea:RenderCursor(painter)
    local x, y, w, h = self:GetContentGeometry();
    local line = self:GetLineByAt(self.cursorAt);
    local LineHeight = self:GetStyle():GetLineHeight(); 

    self.cursorShowHideTickCount = self.cursorShowHideTickCount + 1;
    if (self.cursorShowHideTickCount > CursorShowHideMaxTickCount) then 
        self.cursorShowHideTickCount = 0;
        self:SetShowCursor(not self:IsShowCursor());
    end

    if (self:IsShowCursor() and self:IsFocus()) then
        painter:SetPen(self:GetColor());
    else
        painter:SetPen("#00000000");
    end
    local offsetX = self.text:sub(line.startAt, self.cursorAt - 1):GetWidth();
    local offsetY = (line.line - 1) * LineHeight;
    painter:DrawRectTexture(x + offsetX, y + offsetY, 1, LineHeight);
end

-- 绘制内容
function TextArea:RenderContent(painter)
    local LineHeight = self:GetStyle():GetLineHeight(); 
    local x, y, w, h = self:GetContentGeometry();

    -- 存在滚动需要做裁剪
    local layout = self:GetLayout();
    local width, height = self:GetSize();
    local scrollX, scrollY = self:GetScrollPos();
    if (layout:IsOverflowX() or layout:IsOverflowY()) then
        painter:Save();
        painter:SetClipRegion(x, y, w, h);
        painter:Translate(-scrollX, -scrollY);
    end
    
    self:RenderCursor(painter);

    -- 渲染选择背景
    if (self:IsSelected()) then
        painter:SetPen("#3390ff");
        local function RenderSelectedBG(line, baseAt, startAt, endAt)
            local offsetX = self.text:sub(baseAt, startAt - 1):GetWidth(self:GetFont());
            local width = self.text:sub(startAt, endAt):GetWidth(self:GetFont());
            painter:DrawRectTexture(x + offsetX, y + (line - 1) * LineHeight, width, LineHeight);
        end
        local selectStartAt, selectEndAt = self:GetSelected();
        local startPos, endPos = self:GetLineByAt(selectStartAt), self:GetLineByAt(selectEndAt);
        if (startPos.line == endPos.line) then
            local startAt, lineNo = startPos.startAt, startPos.line;
            RenderSelectedBG(startPos.line, startPos.startAt, selectStartAt, selectEndAt);
        else
            RenderSelectedBG(startPos.line, startPos.startAt, selectStartAt, startPos.endAt);
            for i = startPos.line + 1, endPos.line - 1 do
                local line = self.lines[i];
                RenderSelectedBG(line.line, line.startAt, line.startAt, line.endAt)
            end
            RenderSelectedBG(endPos.line, endPos.startAt, endPos.startAt, selectEndAt);
        end
    end
    
    painter:SetPen(self:GetColor());
    for i, line in ipairs(self.lines) do
        painter:DrawText(x, y + (line.line - 1) * LineHeight, self.text:sub(line.startAt, line.endAt):GetText());
    end

    -- 恢复裁剪
    if (layout:IsOverflowX() or layout:IsOverflowY()) then
        painter:Translate(scrollX, scrollY);
        painter:Restore();
    end
end

-- 获取滚动条的宽度
function TextArea:GetScrollBarWidth()
    if (not self.verticalScrollBar or not self.verticalScrollBar:IsVisible()) then return 0 end
    return self.verticalScrollBar:GetWidth();
end

-- 获取滚动位置
function TextArea:GetScrollBarValue()
    local scrollX, scrollY = self:GetScrollPos();
    return scrollY;
end

-- 设置滚动条的位置
function TextArea:SetScrollBarValue(val)
    if (not self.verticalScrollBar) then return end
    self.verticalScrollBar:ScrollTo(val or 0);
end

function TextArea:GetAtByPos(x, y)
    local lineNo, LineHeight = 1, self:GetStyle():GetLineHeight(); 
    y = y + self:GetScrollBarValue();
    while (y > LineHeight) do 
        y = y - LineHeight;
        lineNo = lineNo + 1;
    end
    local startAt = self.text:length() + 1;
    if (self.lines[lineNo]) then startAt = self.lines[lineNo].startAt end
    local text = _guihelper.AutoTrimTextByWidth(self:GetLineText(lineNo):GetText(), x, self:GetFont());
    local textlen = ParaMisc.GetUnicodeCharNum(text);
    local textWidth = _guihelper.GetTextWidth(text, self:GetFont());
    while (textWidth > x and textlen > 0) do
        textlen = textlen - 1;
        text = ParaMisc.UniSubString(text, 1, textlen);
        textWidth = _guihelper.GetTextWidth(text, self:GetFont());
    end

    TextAreaDebug.Format("GetAtByPos, x = %s, textWidth = %s textlen = %s, cursorAt = %s", x, textWidth, textlen, self.cursorAt);

    return startAt + textlen;
end

function TextArea:GloablToContentGeometryPos(x, y)
    local parentScreenX, parentScreenY = self:GetParentElement():GetScreenPos();
    local contentX, contentY = self:GetContentGeometry();
    return x - parentScreenX - contentX, y - parentScreenY - contentY;
end

function TextArea:OnAfterUpdateLayout()
    self:UpdateLineInfo();
end

function TextArea:OnMouseDown(event)
    if (not self:IsFocus()) then self:FocusIn() end
    local x, y = self:GloablToContentGeometryPos(event.x, event.y);
    self:ClearSelected();
    self.cursorAt = self:GetAtByPos(x, y);
    self.mouseDown = true;
    self:CaptureMouse();
    self.mouseStartScreenX, self.mouseStartScreenY = ParaUI.GetMousePosition(); 
    self.mouseLastScreenX, self.mouseLastScreenY = self.mouseStartScreenX, self.mouseStartScreenY;

    TextAreaDebug.Format("OnMouseDown, x = %s, cursorAt = %s", x, self.cursorAt);

    event:accept();
end

function TextArea:OnMouseMove(event)
    if (not self.mouseDown) then return end
    local sx, sy = self:GetScreenPos();
    local x, y = ParaUI.GetMousePosition();
    if (not self:IsContainPoint(x, y)) then return self:OnMouseUp() end
    local cursorAt = self:GetAtByPos(self:GloablToContentGeometryPos(x, y));
    self.selectStartAt = cursorAt < self.cursorAt and self.cursorAt - 1 or self.cursorAt;
    self.selectEndAt = cursorAt;
end

function TextArea:OnMouseUp(event)
    self:ReleaseMouseCapture();
    self.mouseDown = false;
    if (not self:IsSelected()) then
        self:ClearSelected();
    end 
end