--[[
Title: Event
Author(s): wxa
Date: 2020/6/30
Desc: Event
use the lib:
-------------------------------------------------------
local Event = NPL.load("Mod/GeneralGameServerMod/App/ui/Core/Window/Event.lua");
-------------------------------------------------------
]]

NPL.load("(gl)script/ide/System/Windows/MouseEvent.lua");

local MouseEvent = commonlib.inherit(commonlib.gettable("System.Windows.MouseEvent"), {});

function MouseEvent:init(event_type, window)
	MouseEvent._super.init(self, event_type);

    local screenX, screenY = window:GetScreenPosition();

    self.global_pos:set(self.x, self.y);
    self.local_pos:set(self.x - screenX, self.y - screenY);
    self.window_pos = self.local_pos;

	return self;
end

local Event = NPL.export();

Event.MouseEvent = MouseEvent;