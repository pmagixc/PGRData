---@class XFubenExAgency : XAgency
---@field private _Model XFubenExModel
local XFubenExAgency = XClass(XAgency, "XFubenExAgency")
function XFubenExAgency:OnInit()
    --初始化一些变量
    ---@type XFubenBaseAgency[]
    self._ChapterAgencyList = {}
    ---@type XFubenActivityAgency[]
    self._ActivityAgencyList = {}
end

function XFubenExAgency:InitRpc()
    --实现服务器事件注册
    --XRpc.XXX
end

function XFubenExAgency:InitEvent()
    --实现跨Agency事件注册
    --self:AddAgencyEvent()
end

--兼容老的manager
function XFubenExAgency:AfterInitManager()
    --往XFubenManagerEx添加
    XDataCenter.FubenManagerEx.RegisterActivityAgency(self._ActivityAgencyList)
    XDataCenter.FubenManagerEx.RegisterFubenAgency(self._ChapterAgencyList)
end

----------public start----------
---@param agency XFubenBaseAgency
function XFubenExAgency:RegisterChapterAgency(agency)
    table.insert(self._ChapterAgencyList, agency)
end

---@param agency XFubenActivityAgency
function XFubenExAgency:RegisterActivityAgency(agency)
    table.insert(self._ActivityAgencyList, agency)
end

----------public end----------

----------private start----------


----------private end----------

return XFubenExAgency