--[[
Title: EntityPlayerHelper
Author(s): wxa
Date: 2020/6/30
Desc: 实体玩家辅助类, 此类实现本应做为基类(EntityPlayer),  为了不更改基础类引入新类, 通过类组合实现相关需求
use the lib:
------------------------------------------------------------
NPL.load("Mod/GeneralGameServerMod/App/Client/AppEntityPlayerHelper.lua");
local AppEntityPlayerHelper = commonlib.gettable("Mod.GeneralGameServerMod.App.Client.AppEntityPlayerHelper");
-------------------------------------------------------
]]
NPL.load("(gl)script/ide/headon_speech.lua");
NPL.load("Mod/GeneralGameServerMod/Core/Common/Log.lua");
NPL.load("Mod/GeneralGameServerMod/Core/Common/Config.lua");
local Config = commonlib.gettable("Mod.GeneralGameServerMod.Core.Common.Config");
local Log = commonlib.gettable("Mod.GeneralGameServerMod.Core.Common.Log");
local AppEntityPlayerHelper = commonlib.inherit(nil, commonlib.gettable("Mod.GeneralGameServerMod.App.Client.AppEntityPlayerHelper"));

function AppEntityPlayerHelper:Init(entityPlayer, isMainPlayer)
    self.entityPlayer = entityPlayer;
    self.isMainPlayer = isMainPlayer;
    return self;
end

function AppEntityPlayerHelper:GetEntityPlayer()
    return self.entityPlayer;
end

function AppEntityPlayerHelper:GetPlayerInfo()
    return self:GetEntityPlayer():GetPlayerInfo();
end

function AppEntityPlayerHelper:GetUserInfo() 
    return self:GetPlayerInfo().userinfo or {};
end

function AppEntityPlayerHelper:SetPlayerInfo(playerInfo)
    local oldPlayerInfo = self:GetPlayerInfo();
    
    -- 显示信息是否更改
    local isSetHeadOnDisplay = playerInfo.state and playerInfo.username and (oldPlayerInfo.state ~= playerInfo.state or oldPlayerInfo.username ~= playerInfo.username);
    
    -- 设置玩家信息
    self:GetEntityPlayer():SetSuperPlayerInfo(playerInfo);

    -- 设置显示
    if (isSetHeadOnDisplay) then 
        self:SetHeadOnDisplay(); 
    end
end

-- 设置头顶信息
function AppEntityPlayerHelper:SetHeadOnDisplay()
    local player = self:GetEntityPlayer();
    local playerInfo = self:GetPlayerInfo();
    local userinfo = self:GetUserInfo();
    local username = userinfo.nickname or playerInfo.username;
    local state = playerInfo.state;
    local isVip = userinfo.isVip;
    Log:Debug("username: %s, state: %s, vip: %s", username, state, isVip);
    local color = state == "online" and (self.isMainPlayer and "#ffffff" or "#0cff05") or "#b1b1b1";
    local vipIconUrl = state == "online" and "Texture/Aries/Creator/keepwork/UserInfo/V_32bits.png#0 0 18 18" or "Texture/Aries/Creator/keepwork/UserInfo/V_gray_32bits.png#0 0 18 18";
    local playerUsernameStyle = state == "online" and "" or "shadow-quality:8; shadow-color:#2b2b2b;text-shadow:true;";
    local school = userinfo.school or "";
    local mcml = string.format([[
<pe:mcml>
    <div style="width:200px; margin-left: -100px; margin-top: -30px; color: %s;">
        <div align="center" style="">
            <pe:if condition="%s"><div style="float:left;width:16px;height:16px;background:url(%s);"></div></pe:if>
            <div style="float:left; margin-left: 2px; margin-top: -2px; font-weight:bold; font-size: 14px; base-font-size:14px; color: %s; %s">%s</div>
        </div>
        <div style="text-align: center; font-weight: bold; font-size: 12px; base-font-size:12px; margin-top: 0px;">%s</div>
    </div>
</pe:mcml>
    ]], color, isVip and "true" or "false", vipIconUrl, color, playerUsernameStyle, username, school);
    player:SetHeadOnDisplay({url = ParaXML.LuaXML_ParseString(mcml)});
end

-- -- 设置头顶信息
-- function AppEntityPlayerHelper:SetHeadOnDisplay()
--     local player = self:GetEntityPlayer();
--     local playerInfo = self:GetPlayerInfo();
--     local userinfo = self:GetUserInfo();
--     local username = userinfo.nickname or playerInfo.username;
--     local state = playerInfo.state;
--     local isVip = userinfo.isVip;
--     Log:Debug("username: %s, state: %s, vip: %s", username, state, isVip);
--     local color = state == "online" and (self.isMainPlayer and "#ffffff" or "#0cff05") or "#b1b1b1";
--     local vipIconUrl = state == "online" and "Texture/Aries/Creator/keepwork/UserInfo/V_32bits.png#0 0 18 18" or "Texture/Aries/Creator/keepwork/UserInfo/V_gray_32bits.png#0 0 18 18";
--     -- local playerUsernameStyle = state == "online" and "" or "shadow-quality:8; shadow-color:#2b2b2b;text-shadow:true;"; -- toto test
--     local playerUsernameStyle = "";
--     local textWidth = _guihelper.GetTextWidth(username) + 6 + (isVip and 16 or 0);
--     local mcml = string.format([[
-- <pe:mcml>
--     <div style="margin-top: -25px; margin-left: -%spx">
--         <kp:usertag tag="%s" gray="%s", style="float:left;width:18px;height:18px;"/>
--         <div style="float:left; margin-left: 2px; margin-top: -4px; font-weight:bold; font-size: 16px; base-font-size:14px; color: %s; %s">%s</div>
--     </div>    
-- </pe:mcml>
--     ]], textWidth / 2, isVip and "V" or "", state == "online" and "true" or "false", color, playerUsernameStyle, username);
--     player:SetHeadOnDisplay({url = ParaXML.LuaXML_ParseString(mcml)});
-- end

