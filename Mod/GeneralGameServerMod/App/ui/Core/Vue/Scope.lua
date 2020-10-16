--[[
Title: Slot
Author(s): wxa
Date: 2020/6/30
Desc: 插槽组件
use the lib:
-------------------------------------------------------
local Scope = NPL.load("Mod/GeneralGameServerMod/App/ui/Core/Scope.lua");
-------------------------------------------------------
]]

local __global_index_callback__ = nil;
local __global_newindex_callback__ = nil;

local function Inherit(baseClass, inheritClass)
	if (type(baseClass) ~= "table") then baseClass = nil end
	-- 初始化派生类
    local inheritClass = inheritClass or {};
    local inheritClassMetaTable = { __index = inheritClass };

    -- 新建实例函数
    function inheritClass:___new___(o)
        local o = o or {}
        
        -- 递归基类构造函数
        if(baseClass and baseClass.___new___ ~= nil) then baseClass:___new___(o) end

        -- 设置实例元表
        setmetatable(o, rawget(inheritClass, "__metatable") or inheritClassMetaTable);
        
        -- 调用构造函数
        local __ctor__ = rawget(inheritClass, "__ctor__");
		if(__ctor__) then __ctor__(o) end
		
        return o;
    end

    -- 获取基类
    function inheritClass:__super_class__()
        return baseClass;
    end

    -- 设置基类
    if (baseClass ~= nil) then
        setmetatable(inheritClass, { __index = baseClass } )
    end

    return inheritClass
end

local Scope = Inherit(nil, NPL.export());
-- 基础函数
Scope.__inherit__ = Inherit;

-- 获取值
local function __get_val__(val)
    if (type(val) ~= "table" or Scope:__is_scope__(val)) then return val end

    return Scope:__new__(val);
end

-- 设置全局读取回调
function Scope.__set_global_index__(__index__)
    __global_index_callback__ = __index__;
end

-- 设置全局写入回调
function Scope.__set_global_newindex__(__newindex__)
    __global_newindex_callback__ = __newindex__;
end

function Scope:__new__(obj)
    if (self:__is_scope__(obj)) then return obj end

    local metatable = self:___new___();
    -- 获取值
    metatable.__index = function(scope, key)
        return metatable:__get__(scope, key);
    end

    -- 设置值
    metatable.__newindex = function(scope, key, val)
        metatable:__set__(scope, key, val);
    end

    -- 遍历
    metatable.__pairs = function(scope)
        return pairs(metatable.__data__);
    end

    -- 遍历
    metatable.__ipairs = function(scope)
        return ipairs(metatable.__data__);
    end

    -- 长度
    metatable.__len = function(scope)
        return #(metatable.__data__);
    end

    -- 构建scope对象
    local scope = setmetatable({}, metatable);
    if (type(obj) == "table") then 
        for key, val in pairs(obj) do
            scope[key] = val;
        end
    end

    -- 设置scope
    metatable.__scope__ = scope;

    return scope;
end

-- 构造函数
function Scope:__ctor__()
    self.__data__ = {};                                 -- 数据表      
    self.__scope__ = true;                              -- 是否为Scope
    self.__index_callback__ = nil;                      -- 读取回调
    self.__newindex_callback__ = nil;                   -- 写入回调   
    -- print("--------------------------scope:__ctor__-------------------------------");
    -- 内置可读写属性
    self.__inner_can_set_attrs__ = {
        __newindex_callback__ = true,
        __index_callback__ = true,
        __metatable_index__ = true,
    }
end

-- 初始化
function Scope:__init__()
    return self;
end

-- 是否是Scope
function Scope:__is_scope__(scope)
    return type(scope) == "table" and scope.__scope__ ~= nil;
end
-- 是否可以设置
function Scope:__is_inner_attr__(key)
    return self[key] ~= nil or self.__inner_can_set_attrs__[key];
end

function Scope:__set_metatable_index__(__metatable_index__)
    self.__metatable_index__ = __metatable_index__;
end

function Scope:__get_metatable_index__()
    return self.__metatable_index__;
end

-- 是否是scope更新
function Scope:__is_list_index__(key)
    return type(key) == "number" and key >= 1 and key <= (#self.__data__ + 1);
end

-- 全局读取回调
function Scope:__call_global_index_callback__(scope, key)
    if (type(__global_index_callback__) == "function") then __global_index_callback__(scope, key) end
end

-- 读取回调
function Scope:__call_index_callback__(scope, key)
    self:__call_global_index_callback__(scope, key);
    if (key ~= nil and self:__is_scope__(self.__data__[key])) then self:__call_global_index_callback__(self.__data__[key], nil) end
    if (self:__is_list_index__(key)) then self:__call_global_index_callback__(scope, nil) end

    if (type(self.__index_callback__) == "function") then self.__index_callback__(scope, key) end
end

-- 设置读取回调
function Scope:__set_index_callback__(__index__)
    self.__index_callback__ = __index__;
end

-- 获取键值
function Scope:__get__(scope, key)
    -- 内置属性直接返回
    if (self:__is_inner_attr__(key)) then return self[key] end

    -- print("__index", scope, key);

    -- 触发回调
    self:__call_index_callback__(scope, key);

    -- 返回数据值
    if (self.__data__[key]) then return self.__data__[key] end

    -- 返回用户自定的读取
    if (type(self.__metatable_index__) == "table") then return self.__metatable_index__[key] end
    if (type(self.__metatable_index__) == "table") then return self.__metatable_index__(scope, key) end
end

-- 写入回调   
function Scope:__call_global_newindex_callback__(scope, key, newval, oldval)
    if (type(__global_newindex_callback__) == "function") then __global_newindex_callback__(scope, key, newval, oldval) end
end

-- 写入回调   
function Scope:__call_newindex_callback__(scope, key, newval, oldval)
    self:__call_global_newindex_callback__(scope, key, newval, oldval)
    if (key ~= nil and self:__is_scope__(self.__data__[key])) then self:__call_global_newindex_callback__(self.__data__[key], nil, self.__data__[key]) end
    if (self:__is_list_index__(key)) then self:__call_global_newindex_callback__(scope, nil, scope) end

    if (type(self.__newindex_callback__) == "function") then self.__newindex_callback__(scope, key, newval, oldval) end
end

-- 设置写入回调   
function Scope:__set_newindex_callback__(__newindex__)
    self.__newindex_callback__ = __newindex__;
end

-- 设置键值
function Scope:__set__(scope, key, val)
    if (self:__is_inner_attr__(key)) then
        if (self.__inner_can_set_attrs__[key]) then self[key] = val end
        return;
    end

    -- print("__newindex", scope, key, val);

    -- 更新值
    local oldval = self.__data__[key];
    self.__data__[key] = __get_val__(val);

    -- 相同直接退出
    if (oldval == val) then return end

    -- 触发更新回调
    self:__call_newindex_callback__(scope, key, val, oldval);
end

-- 插入列表元素
function Scope:__insert__(pos, val)
    table.insert(self.__data__, pos, __get_val__(val));
    self:__call_global_newindex_callback__(self.__scope__, nil);
end

-- 移除列表元素
function Scope:__remove__(pos)
    table.remove(self.__data__, pos);
    self:__call_global_newindex_callback__(self.__scope__, nil);
end


