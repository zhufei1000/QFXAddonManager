local _, manager = ...
manager.ToolboxRuntime:AddFile("Core", function(...)
-- LibDataBroker-1.1.lua
-- Lightweight embedded LibDataBroker-compatible implementation for launcher objects.
local MAJOR, MINOR = "LibDataBroker-1.1", 4
local LibStub = _G.LibStub
if not LibStub then error(MAJOR .. " requires LibStub.") end
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

lib.objects = lib.objects or {}
lib.callbacks = lib.callbacks or {}

local function fire(event, ...)
    local list = lib.callbacks[event]
    if not list then return end
    for target, method in pairs(list) do
        if type(method) == "function" then
            pcall(method, target, event, ...)
        elseif type(target) == "table" and type(target[method]) == "function" then
            pcall(target[method], target, event, ...)
        end
    end
end

local object_mt = {
    __newindex = function(t, k, v)
        rawset(t, k, v)
        local name = rawget(t, "__ldb_name")
        if name then
            fire("LibDataBroker_AttributeChanged", name, k, v, t)
            fire("LibDataBroker_AttributeChanged_" .. name, name, k, v, t)
            fire("LibDataBroker_AttributeChanged__" .. k, name, k, v, t)
            fire("LibDataBroker_AttributeChanged_" .. name .. "_" .. k, name, k, v, t)
        end
    end,
}

function lib:NewDataObject(name, dataobj)
    assert(type(name) == "string", "Usage: NewDataObject(name, dataobj)")
    if self.objects[name] then return self.objects[name] end
    dataobj = dataobj or {}
    rawset(dataobj, "__ldb_name", name)
    setmetatable(dataobj, object_mt)
    self.objects[name] = dataobj
    fire("LibDataBroker_DataObjectCreated", name, dataobj)
    return dataobj
end

function lib:GetDataObjectByName(name)
    return self.objects[name]
end

function lib:DataObjectIterator()
    return pairs(self.objects)
end

function lib:RegisterCallback(target, event, method)
    if type(event) ~= "string" then return end
    self.callbacks[event] = self.callbacks[event] or {}
    self.callbacks[event][target] = method or event
end

function lib:UnregisterCallback(target, event)
    if self.callbacks[event] then self.callbacks[event][target] = nil end
end

function lib:UnregisterAllCallbacks(target)
    for _, list in pairs(self.callbacks) do list[target] = nil end
end

end)
