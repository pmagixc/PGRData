local XUiButton = require("XUi/XUiCommon/XUiButton")
local XUiTransfiniteMainGridIsland = require("XUi/XUiTransfinite/Main/XUiTransfiniteMainGridIsland")
local XUiTransfiniteMainStageFlag = require("XUi/XUiTransfinite/Main/XUiTransfiniteMainStageFlag")
local XViewModelTransfinite = require("XEntity/XTransfinite/ViewModel/XViewModelTransfinite")
local STATE = {
    NORMAL = 1,
    ISLAND = 2,
}

---@class XUiTransfiniteMain:XLuaUi
local XUiTransfiniteMain = XLuaUiManager.Register(XLuaUi, "UiTransfiniteMain")

function XUiTransfiniteMain:Ctor()
    ---@type XViewModelTransfinite
    self._ViewModel = XViewModelTransfinite.New()

    self._Timer = false
end

function XUiTransfiniteMain:OnAwake()
    XUiPanelAsset.New(self, self.PanelAsset, XDataCenter.ItemManager.ItemId.FreeGem, XDataCenter.ItemManager.ItemId.ActionPoint, XDataCenter.ItemManager.ItemId.Coin)
    self:BindExitBtns()
    self:BindHelpBtn(nil, self._ViewModel:GetHelpKey())
    self:RegisterClickEvent(self.BtnGift, self.OnClickGift)
    self:RegisterClickEvent(self.BtnPassage, self.OnClickFight)
    self:RegisterClickEvent(self.BtnNote, self.OnClickRecord)
    self:RegisterClickEvent(self.BtnSuccess, self.OnClickSuccess)
    self:RegisterClickEvent(self.BtnLost, self.OnClickIsland)
    self:RegisterClickEvent(self.BtnBack, self.OnClickBack, true)
    self:RegisterClickEvent(self.BtnBoss, self.OnClickFight)
    --self:RegisterClickEvent(self.BtnPresent, self.OnClickStageGroup, self)
    ---@type XUiButtonLua
    self._BtnAchievement = XUiButton.New(self.BtnSuccess)

    if not self.GridIcon then
        self.GridIcon = XUiHelper.TryGetComponent(self.Transform, "SafeAreaContentPane/PanelMain/BtnGift/PanelIcon/GridIcon", "RectTransform")
    end

    ---@type XUiGridCommon
    self._GridCommon1 = XUiGridCommon.New(self.UiRoot, self.GridIcon)

    local gridIcon2 = CS.UnityEngine.Object.Instantiate(self.GridIcon, self.GridIcon.parent.transform)
    ---@type XUiGridCommon
    self._GridCommon2 = XUiGridCommon.New(self.UiRoot, gridIcon2)

    self.DynamicTable = XDynamicTableNormal.New(self.SViewLostList)
    self.DynamicTable:SetProxy(XUiTransfiniteMainGridIsland)
    self.DynamicTable:SetDelegate(self)
    self.PanelLost.gameObject:SetActiveEx(false)

    self._State = STATE.NORMAL

    ---@type XUiTransfiniteMainStageFlag[]
    self._StageFlag = {}
    self.PanelNun.gameObject:SetActiveEx(false)

    local util = require("XUi/XUiTransfinite/XUiTransfiniteUtil")
    util.HideEffectHuan(self)

    XDataCenter.TransfiniteManager.SetUiShowed(true)
end

function XUiTransfiniteMain:OnEnable()
    self:Update()
    self:UpdateTime()
    if not self._Timer then
        self._Timer = XScheduleManager.ScheduleForever(function()
            if XTool.UObjIsNil(self.Transform) then
                self:UnSchedule()
                return
            end
            self:UpdateTime()
        end, XScheduleManager.SECOND)
    end

    XEventManager.AddEventListener(XEventId.EVENT_TRANSFINITE_UPDATE_ROOM, self.Update, self)
    XEventManager.AddEventListener(XEventId.EVENT_TASK_SYNC, self.Update, self)
    XEventManager.AddEventListener(XEventId.EVENT_FINISH_TASK, self.Update, self)
end

function XUiTransfiniteMain:UnSchedule()
    XScheduleManager.UnSchedule(self._Timer)
    self._Timer = false
end

function XUiTransfiniteMain:OnDisable()
    self:UnSchedule()

    XEventManager.RemoveEventListener(XEventId.EVENT_TRANSFINITE_UPDATE_ROOM, self.Update, self)
    XEventManager.RemoveEventListener(XEventId.EVENT_TASK_SYNC, self.Update, self)
    XEventManager.RemoveEventListener(XEventId.EVENT_FINISH_TASK, self.Update, self)
end

function XUiTransfiniteMain:OnDestroy()
    XDataCenter.TransfiniteManager.Clear()
    XDataCenter.TransfiniteManager.SetUiShowed(false)
end

function XUiTransfiniteMain:Update()
    self._ViewModel:Update()
    local data = self._ViewModel.Data

    self.ImgLv:SetRawImage(data.RegionIconLv)
    --self.ImgBg.color = data.RegionColor
    self.TxtLvTitle.text = data.RegionName
    self.TxtLv.text = data.RegionLevel
    if self.TxtGameObjectTitle then
        self.TxtGameObjectTitle.text = data.StageGroupName
    end

    --self.TxtTitle.text = data.StageGroupName
    self.TxtSpeedNubmer.text = data.TextWinAmount
    for i = 1, data.StageAmount do
        local stageFlag = self._StageFlag[i]
        if not stageFlag then
            local ui = CS.UnityEngine.Object.Instantiate(self.PanelNun, self.PanelNun.parent)
            stageFlag = XUiTransfiniteMainStageFlag.New(ui)
            self._StageFlag[i] = stageFlag
            stageFlag:SetIndex(i)
        end
        stageFlag:SetEnable(data.WinAmount == i)
        stageFlag.GameObject:SetActiveEx(true)
    end
    for i = data.StageAmount + 1, #self._StageFlag do
        local stageFlag = self._StageFlag[i]
        stageFlag.GameObject:SetActiveEx(false)
    end

    self.BtnSuccess:SetNameByGroup(0, data.AchievementAmount)
    self._BtnAchievement:SetFillAmount("ImgProgressBarBg/ImgProgressBar", data.AchievementProgress)
    self.BtnSuccess:ShowReddot(data.AchievementReward)

    self.BtnLost:ShowReddot(data.IslandReward)

    self.BtnGift:ShowReddot(data.ScoreReward)
    self.BtnGift:SetNameByGroup(0, data.ScoreNumber)
    self.BtnGift:SetNameByGroup(1, data.ScoreNumber2)
    self.Progress.fillAmount = data.ScoreRatio

    --self.BtnPresent:ShowReddot(false)
    self.BtnLost.gameObject:SetActiveEx(data.IsShowIsland)

    for i = 1, #data.Background do
        local img = self["ImgPassage" .. i]
        if img then
            img:SetRawImage(data.Background[i])
        end
    end

    if self._GridCommon1 then
        self._GridCommon1:Refresh(data.NextScoreReward)
        self._GridCommon1:SetReceived(data.NextScoreRewardReceived)
    end
    if self._GridCommon2 then
        self._GridCommon2:Refresh(data.NextChallengeReward)
        self._GridCommon2:SetReceived(data.NextChallengeRewardReceived)
    end

    self.BtnGift:SetRawImage(data.ImgScore)
    self.BtnNote:ShowReddot(data.RedPointRecord)
end

function XUiTransfiniteMain:UpdateTime()
    self._ViewModel:UpdateTime()
    local data = self._ViewModel.Data
    self.TxtTime.text = data.Time
end

function XUiTransfiniteMain:OnClickGift()
    XLuaUiManager.Open("UiTransfiniteGift")
end

function XUiTransfiniteMain:OnClickFight()
    XLuaUiManager.Open("UiTransfiniteBattlePrepare", self._ViewModel:GetStageGroup())
end

function XUiTransfiniteMain:OnClickRecord()
    self._ViewModel:OnClickRecord()
    self.BtnNote:ShowReddot(self._ViewModel.Data.RedPointRecord)
end

function XUiTransfiniteMain:OnClickSuccess()
    local stageGroup = self._ViewModel:GetStageGroup()

    XLuaUiManager.Open("UiTransfiniteSuccess", stageGroup)
end

function XUiTransfiniteMain:OnClickIsland()
    self.SViewLostList.gameObject:SetActiveEx(true)
    self.PanelMain.gameObject:SetActiveEx(false)
    self.BtnLost.gameObject:SetActiveEx(false)
    --self.BtnPresent.gameObject:SetActiveEx(true)

    self._ViewModel:UpdateIsland()
    self.DynamicTable:SetDataSource(self._ViewModel.DataIsland.DataSource)
    self.DynamicTable:ReloadDataSync(1)
    self._State = STATE.ISLAND
end

function XUiTransfiniteMain:OnClickStageGroup()
    self.SViewLostList.gameObject:SetActiveEx(false)
    self.PanelMain.gameObject:SetActiveEx(true)
    self.BtnLost.gameObject:SetActiveEx(true)
    --self.BtnPresent.gameObject:SetActiveEx(false)
    self._State = STATE.NORMAL
end

---@param grid XUiTransfiniteMainGridIsland
function XUiTransfiniteMain:OnDynamicTableEvent(event, index, grid)
    if event == DYNAMIC_DELEGATE_EVENT.DYNAMIC_GRID_ATINDEX then
        local data = self.DynamicTable:GetData(index)
        grid:Update(data)
    end
end

function XUiTransfiniteMain:OnClickBack()
    if self._State == STATE.ISLAND then
        self:OnClickStageGroup()
        return
    end
    if self._State == STATE.NORMAL then
        self:Close()
        return
    end
end

return XUiTransfiniteMain