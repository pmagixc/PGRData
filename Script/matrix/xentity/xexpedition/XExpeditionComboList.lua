-- 虚像地平线组合对象列表
local XExpeditionComboList = XClass(nil, "XExpeditionComboList")
local XCombo = require("XEntity/XExpedition/XExpeditionCombo")
local COMBOTYPE_TACTICS = 1 -- 战术连携
local COMBOTYPE_DEFAULTTEAM = 4 --预设羁绊
--================
--构造函数
--================
function XExpeditionComboList:Ctor(team)
    self.Team = team
    self:InitCombos()  
end
--================
--初始化羁绊
--================
function XExpeditionComboList:InitCombos()
    self.Combos = {}
    local childComboList = XExpeditionConfig.GetChildComboTable()
    for id, combo in pairs(childComboList) do
        self.Combos[id] = XCombo.New(combo, self.Team)
    end
    self:InitComboReferences()
end
--================
--初始化所有羁绊的固定关联人员列表
--================
function XExpeditionComboList:InitComboReferences()
    local allCharas = XExpeditionConfig.GetBaseCharacterCfg()
    for eBaseId, eBaseCharaCfg in pairs(allCharas) do
        for _, comboId in pairs(eBaseCharaCfg.ReferenceComboId) do
            local combo = self.Combos[comboId]
            if combo and (combo:GetComboTypeId() == COMBOTYPE_TACTICS or combo:GetComboTypeId() == COMBOTYPE_DEFAULTTEAM) then
                combo:SetDefaultReferenceCharaList(eBaseId)
            end
        end
    end
end
--================
--获取所有羁绊对象列表（包括没激活的）
--================
function XExpeditionComboList:GetAllCombos()
    local allCombos = {}
    local eActivity = XDataCenter.ExpeditionManager.GetEActivity()
    local defaultTeamCfgs = eActivity:GetDefaultTeamCfg()
    local defaultIdDic = {}
    for _, cfgs in pairs(defaultTeamCfgs or {}) do
        defaultIdDic[cfgs.TeamId] = true
    end
    for id, combo in pairs(self.Combos) do
        if (not combo:CheckIsDefaultCombo()) or defaultIdDic[combo:GetDefaultTeamId()] then
            allCombos[id] = combo
        end
    end
    return allCombos
end
--================
--获取指定Id的组合对象
--@param comboId:组合ID
--================
function XExpeditionComboList:GetComboByComboId(comboId)
    if not self.Combos[comboId] then
        return nil
    end
    return self.Combos[comboId]
end
--================
--检查队伍羁绊列表
--@param team:队伍
--================
function XExpeditionComboList:CheckCombos(team)
    if not team then return end
    local tempIds = {}
    self:ResetComboCheckList()
    self.CurrentCombos = {}
    for _, teamChara in pairs(team) do
        local comboIds = teamChara:GetCharacterComboIds()
        for _, comboId in pairs(comboIds) do
            local combo = self:GetComboByComboId(comboId)
            if not tempIds[comboId] then
                tempIds[comboId] = true
                if combo:CheckDefaultTeamCombo() then
                    table.insert(self.CurrentCombos, combo)
                end
            end
            combo:AddCheckList(teamChara)
        end
    end
    self:CheckActiveStatus()
end
--================
--获取所有现在关联的羁绊列表（包括没激活的）
--================
function XExpeditionComboList:GetCurrentCombos(team)
    self:CheckCombos(team)
    local allCurrentCombos = {}
    local eActivity = XDataCenter.ExpeditionManager.GetEActivity()
    local defaultTeamCfgs = eActivity:GetDefaultTeamCfg()
    local defaultIdDic = {}
    for _, cfgs in pairs(defaultTeamCfgs or {}) do
        defaultIdDic[cfgs.TeamId] = true
    end
    for _, combo in pairs(self.CurrentCombos) do
        if (not combo:CheckIsDefaultCombo()) or defaultIdDic[combo:GetDefaultTeamId()] then
            table.insert(allCurrentCombos, combo)
        end
    end
    return allCurrentCombos
end
--================
--重置当前组合状态列表的所有组合检查列表
--================
function XExpeditionComboList:ResetComboCheckList()
    if not self.CurrentCombos then return end
    for _, combo in pairs(self.Combos) do
        combo:ResetCheckList()
    end
end
--================
--刷新当前组合状态列表的所有组合状态
--================
function XExpeditionComboList:CheckActiveStatus()
    for _, combo in pairs(self.CurrentCombos) do
        combo:Check()
    end
end
--================
--获取角色有效的羁绊ID列表
--================
function XExpeditionComboList:GetActiveComboIdsByEChara(eChara, isSort)
    local previewList = {}
    local comboIds = eChara:GetCharacterComboIds()
    local eActivity = XDataCenter.ExpeditionManager.GetEActivity()
    local defaultTeamCfgs = eActivity:GetDefaultTeamCfg()
    local defaultIdDic = {}
    for _, cfgs in pairs(defaultTeamCfgs or {}) do
        defaultIdDic[cfgs.TeamId] = true
    end
    for _, comboId in pairs(comboIds) do
        local combo = self:GetComboByComboId(comboId)
        if not combo:CheckIsDefaultCombo() or defaultIdDic[combo:GetDefaultTeamId()] then
        --if combo:GetComboActive() then
            table.insert(previewList, comboId)
        --end
        end
    end
    if isSort then
        table.sort(previewList, self.SortComboIdsFunc)
    end
    return previewList
end
--================
--返回招募时的预览羁绊ID列表
--================
function XExpeditionComboList:GetPreviewCombosWhenRecruit(eChara, isSort)
    local previewList = {}
    local comboIds = eChara:GetCharacterComboIds()
    local eActivity = XDataCenter.ExpeditionManager.GetEActivity()
    local defaultTeamCfgs = eActivity:GetDefaultTeamCfg()
    local defaultIdDic = {}
    for _, cfgs in pairs(defaultTeamCfgs or {}) do
        defaultIdDic[cfgs.TeamId] = true
    end
    for _, comboId in pairs(comboIds) do
        local combo = self:GetComboByComboId(comboId)
        if not combo:CheckIsDefaultCombo() or defaultIdDic[combo:GetDefaultTeamId()] then
            combo:PreviewCheckNew(eChara)
            --if combo:GetPreActive() then
            table.insert(previewList, comboId)
            --end
        end
    end
    if isSort then
        table.sort(previewList, self.SortComboIdsFunc)
    end
    return previewList
end
--================
--展示组合排序  核心羁绊＞当前羁绊星级＞人数 (激活状态按照星级排序，未激活状态按照人数排序)
--================
function XExpeditionComboList.SortComboIdsFunc(a, b)
    local ACombo = XDataCenter.ExpeditionManager.GetComboByChildComboId(a)
    local BCombo = XDataCenter.ExpeditionManager.GetComboByChildComboId(b)
    local aActive = ACombo:GetComboActive()
    local aDefaultTeamId = ACombo:GetDefaultTeamId()
    local aRank = ACombo:GetTotalRank()
    local aReachNum = ACombo:GetReachConditionNum()
    local bActive = BCombo:GetComboActive()
    local bDefaultTeamId = BCombo:GetDefaultTeamId()
    local bRank = BCombo:GetTotalRank()
    local bReachNum = BCombo:GetReachConditionNum()
    if aActive ~= bActive then
        return aActive and not bActive
    end
    if aDefaultTeamId ~= bDefaultTeamId then
        return aDefaultTeamId > bDefaultTeamId
    end
    if aActive and bActive and aRank ~= bRank then
        return aRank > bRank
    end
    if not aActive and not bActive and aReachNum ~= bReachNum then
        return aReachNum > bReachNum
    end
    return a > b
end
return XExpeditionComboList