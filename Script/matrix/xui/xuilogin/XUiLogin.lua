local UiLoginSpineAnimPath = CS.XGame.ClientConfig:GetString("UiLoginSpineAnimPath")
local XUiLoginNetworkModePanel = require("XUi/XUiLogin/XUiLoginNetworkModePanel")
-- local UiLoginMovieId = CS.XGame.ClientConfig:GetInt("UiLoginMovieId")
-- local UiLoginMovieTimeStr = CS.XGame.ClientConfig:GetString("UiLoginMovieTimeStr")
-- local UiLoginMovieTimeEnd = CS.XGame.ClientConfig:GetString("UiLoginMovieTimeEnd")
local XUiLogin = XLuaUiManager.Register(XLuaUi, "UiLogin")
local KEY_USER_AGREE

local XUiGridServer = require("XUi/XUiLogin/XUiGridServer")
--if CS.XHeroSdkAgent.KEY_USER_AGREE then
--    KEY_USER_AGREE = CS.XHeroSdkAgent.KEY_USER_AGREE
--else
KEY_USER_AGREE = "USER_AGREE_LGOIN"
--end
local WaterMarkStatus = {
    AllOff = 0,
    AllOn = 1,
    OnlyWaterMarkOn = 2,
    OnlySuperWaterMarkOn = 3,
}

local NoticeOpenFuncList = {
    XDataCenter.NoticeManager.AutoOpenLoginNotice,
    XDataCenter.NoticeManager.AutoOpenInGameNotice
}

local NoticeNameMap = {
    UiLoginNotice   = true,
    UiAnnouncement  = true
}

local NoticeOpenIndex = 0


local null = "null"

function XUiLogin:OnAwake()
    self:InitAutoScript()
    self:InitUiView()

    XLoginManager.SetStartGuide(false)
    self:OnAwakeOversea()
end

function XUiLogin:OnEnable()
    self.LongClicker = XUiButtonLongClick.New(self.LongClickShowUid, 500, self, self.OnClickShowUid, self.OnLongClickShowUid, false)
    self.LongClicker:SetTriggerOffset(CS.XGame.ClientConfig:GetInt("LoginUidShowLongClickOffset"))
    self:OnEnableOversea()
end

function XUiLogin:CheckFool()
    if not XDataCenter.AprilFoolDayManager or not XDataCenter.AprilFoolDayManager.IsInTitleTime() then
        return
    end
    self.ImgLogo:SetRawImage(CS.XGame.ClientConfig:GetString("JPFoolLogo"))
    local scale = self.ImgLogo.transform.localScale
    self.ImgLogo.transform.localScale = Vector3(-scale.x, scale.y, scale.z)
    scale = self.TextStart.transform.localScale
    self.TextStart.transform.localScale = Vector3(-scale.x, scale.y, scale.z)
end

function XUiLogin:OnStart()
    CS.XEffectManager.useNewEffect = 1
    --删除闪屏
    CS.XUnloadSplash.DoUnloadSplash()
    --GC
    CS.System.GC.Collect()

    self.BlackMask.color = CS.UnityEngine.Color(0, 0, 0, 0)
    self.BlackMask.gameObject:SetActiveEx(false)
    self.BtnLoginNotice.gameObject:SetActiveEx(false)

    local needCGBtn, videoUrl, width, height = XDataCenter.VideoManager.CheckCgUrl()
    self.VideoUrl = videoUrl
    self.VideoWidth = width
    self.VideoHeight = height
    -- local isPlayVideo = UiLoginMovieId and UiLoginMovieId ~= 0
    -- local isInTime = false
    -- if UiLoginMovieTimeStr and UiLoginMovieTimeEnd then
    --     local now = CS.XDateUtil.GetNowTimestamp()
    --     local startTime = XTime.ParseToTimestamp(UiLoginMovieTimeStr)
    --     local endTime = XTime.ParseToTimestamp(UiLoginMovieTimeEnd)
    --     if now >= startTime and now <= endTime then
    --         isInTime = true
    --     end
    -- end
    self.BtnVideo.gameObject:SetActiveEx(needCGBtn)
    self:RequestNotice()
    --self:RequestLoginNotice()
    --CS.XAudioManager.PlayMusic(CS.XAudioManager.LOGIN_BGM)
    self:InitServerPanel()
    self:PlaySpineAnimation()
    self.GameObject:ScheduleOnce(function()
        --释放启动界面的资源
        CS.UnityEngine.Resources.UnloadUnusedAssets()
    end, 100)

    self:OnStartOversea()

    --愚人节处理
    self:CheckFool()

    -- en不走国服的逻辑
    --pc版
    -- self:InitPcUi()
end

function XUiLogin:InitUiView()
    self.TxtDocumentVersion.text = CS.XRemoteConfig.DocumentVersion .. " (DocumentVersion)"
    self.TxtApplicationVersion.text = CS.XRemoteConfig.ApplicationVersion .. " (ApplicationVersion)"
    if CS.XUriPrefix.HaveDevelopmentCdn then
        self.TxtApplicationVersion.text = self.TxtApplicationVersion.text .. " <color=#5bf54f>[DevCdn Enable]</color>"
    end

    self.TxtUser.text = XUserManager.UserName
    self.LongClickShowUid.gameObject:SetActiveEx(XUserManager.UserId ~= nil)

    self.BackGround.gameObject:SetActiveEx(true)
    self.PanelSpine.gameObject:SetActiveEx(false)

    self.IsUserAgree = (CS.UnityEngine.PlayerPrefs.GetInt(KEY_USER_AGREE, 0) ~= 0)
    self.ToggleAgree.isOn = self.IsUserAgree
    self.PanelUserAgreement.gameObject:SetActiveEx(false) -- 屏蔽国服登录协议

    -- self.HtmlText.text = self:GetProtocolContent() -- 屏蔽国服协议
    if self.BtnCode then
        self.BtnCode.gameObject:SetActiveEx(not XUserManager.IsNeedLogin() and CS.XHeroSdkAgent.IsScanQRCode())
    end

    -- 以下lua兼容ugui bug，容用户协议无法点击问题
    --      （当父节点继承了PointClick与PointDown，子节点也需同时继承PointClick与PointDown，否则无法接收点击）
    local uiPointer = self.HtmlText.gameObject:GetComponent(typeof(CS.XUiPointer))
    if not uiPointer then
        uiPointer = self.HtmlText.gameObject:AddComponent(typeof(CS.XUiPointer))
    end

    self.HtmlText.HrefListener = function(url, title)
        XUiManager.OpenPopWebview(url, title)
    end
    self.HtmlText.HrefUnderLineColor = CS.UnityEngine.Color(52 / 255, 175 / 255, 248 / 255, 1)
    self.HtmlText.raycastTarget = true
    self.ToggleAgree.onValueChanged:AddListener(function(value) self:OnToggleAgree(value) end)

    self:SetupAgeTip()
end

function XUiLogin:SetupAgeTip()
    self.PanelAgeReminder.gameObject:SetActiveEx(false)

    self:RegisterClickEvent(self.BtnAge, function()
        self.PanelAgeReminder.gameObject:SetActiveEx(true)
    end)

    self:RegisterClickEvent(self.BtnAgeDetermine, function()
        self.PanelAgeReminder.gameObject:SetActiveEx(false)
    end)

    self.txtAgeTip.text = string.gsub(CS.XTextManager.GetText("LoginCADPANoticTittle"), "\\n", "\n")
    self.txtAgeContent.text = string.gsub(CS.XTextManager.GetText("LoginCADPANoticDesc"), "\\n", "\n")
end

function XUiLogin:GetProtocolContent()
    local protocolData = nil
    if CS.XHeroSdkAgent.GetProtocolData then
        protocolData = CS.XHeroSdkAgent.GetProtocolData()
    end
    local content = nil
    if protocolData then
        content = CsXTextManagerGetText("LoginUserAgreeToggleSdk")
        local contentAnd = CsXTextManagerGetText("LoginUserAgreeItemAnd")
        if protocolData.priAgrName then
            local urlItemStr = CsXTextManagerGetText("LoginUserAgreeItem", protocolData.priAgrUrl, protocolData.priAgrName)
            content = content .. urlItemStr
        end

        if protocolData.userAgrName then
            local urlItemStr = CsXTextManagerGetText("LoginUserAgreeItem", protocolData.userAgrUrl, protocolData.userAgrName)
            content = content .. contentAnd .. urlItemStr
        end

        if protocolData.childAgrName then
            local urlItemStr = CsXTextManagerGetText("LoginUserAgreeItem", protocolData.childAgrUrl, protocolData.childAgrName)
            content = content .. contentAnd .. urlItemStr
        end

        if protocolData.sdkAgrName then
            local urlItemStr = CsXTextManagerGetText("LoginUserAgreeItem", protocolData.sdkAgrUrl, protocolData.sdkAgrName)
            content = content .. contentAnd .. urlItemStr
        end
    else
        content = CsXTextManagerGetText("LoginUserAgreeToggle", CS.XGame.ClientConfig:GetString("UserAgreementUrl"), CS.XGame.ClientConfig:GetString("ChildArgUrl"), CS.XGame.ClientConfig:GetString("PrivacyPolicyUrl"))
    end
    content = string.gsub(content, "|", "\"")

    return content
end

function XUiLogin:OnGetEvents()
    return {
        XEventId.EVENT_USERNAME_CHANGE,
        XEventId.EVENT_USERID_CHANGE,
        XEventId.EVENT_SERVER_LIST_CHANGE,
        XEventId.EVENT_LOGIN_PC_SELECT_SERVER,
        XEventId.EVENT_NOTICE_REQUEST_SUCCESS,
        CS.XEventId.EVENT_UI_DESTROY,
    }
end

function XUiLogin:OnNotify(evt, ...)
    if evt == XEventId.EVENT_USERNAME_CHANGE then
        self:OnUsernameChanged(...)
    elseif evt == XEventId.EVENT_USERID_CHANGE then
        self:OnUidChanged(...)
    elseif evt == XEventId.EVENT_SERVER_LIST_CHANGE then
        self:UpdateSeverList(true)
    elseif evt == XEventId.EVENT_LOGIN_PC_SELECT_SERVER then
        self:SelectServer(...)
    elseif evt == CS.XEventId.EVENT_UI_DESTROY then
        self:OnUiDestroy(...)
    end
end

function XUiLogin:OnDisable()
    if self.LongClicker then
        self.LongClicker:Destroy()
    end
    self.LongClicker = nil
    self:OnDisableOversea()
end

function XUiLogin:OnUsernameChanged(userName)
    self.TxtUser.text = userName
    self:UpdatePcUi()
end

function XUiLogin:OnUidChanged(userId)
    self.LongClickShowUid.gameObject:SetActiveEx(userId ~= nil)
    self.TxtUid.text = userId
    if self.BtnCode then
        self.BtnCode.gameObject:SetActiveEx(userId ~= nil and CS.XHeroSdkAgent.IsScanQRCode())
    end
end

function XUiLogin:InitServerPanel()
    self.PanelServerList.gameObject:SetActiveEx(false)
    self.GridServer.gameObject:SetActiveEx(false)

    self.DynamicTable = XDynamicTableNormal.New(self.PanelDynamicTable)
    self.DynamicTable:SetProxy(XUiGridServer)
    self.DynamicTable:SetDelegate(self)

    self.BtnServer.gameObject:SetActiveEx(XServerManager.CheckOpenSelect())
    self:InitServerPanelOversea()
end

-- 2.0 迭代动画播放:入场动画、不同分辨率比例支持动画偏移
function XUiLogin:PlaySpineAnimation()
    self.BackGround.gameObject:SetActiveEx(false)
    self.PanelSpine.gameObject:SetActiveEx(true)

    self:SetScreenOffect(self.PanelSpine)

    local spineGo = self.PanelSpine:LoadPrefab(UiLoginSpineAnimPath)

    local timeLineAnim = CS.XGame.ClientConfig:GetString("UiLoginTimeLineAnim")
    local spineStartAnim = CS.XGame.ClientConfig:GetString("UiLoginSpineStartAnim")
    local spineLoopAnim = CS.XGame.ClientConfig:GetString("UiLoginSpineLoopAnim")

    if spineStartAnim ~= null or spineLoopAnim ~= null then
        -- 收集Spine对象
        local spineAnimObjs = {}
        local spineAnim = spineGo:GetComponent("SkeletonAnimation")
        if spineAnim then
            table.insert(spineAnimObjs, spineAnim)
        end
        for i = 0, spineGo.transform.childCount - 1, 1 do
            local obj = spineGo.transform:GetChild(i):GetComponent("SkeletonAnimation")
            if not XTool.UObjIsNil(obj) then
                table.insert(spineAnimObjs, obj)
            end
        end
        -- 播放
        for _, spineObj in ipairs(spineAnimObjs) do
            self:PlaySpineObjAnim(spineObj, spineStartAnim, spineLoopAnim)
        end
    end
    if timeLineAnim ~= null then
        self:PlayAnimation(timeLineAnim)
    end
end

-- spine对象播放动画
function XUiLogin:PlaySpineObjAnim(spineObject, fromAnim, toAnim)
    if XTool.UObjIsNil(spineObject) then return end

    -- 判断Spine是否存在动画轨道
    local isHaveFrom = fromAnim and spineObject.skeletonDataAsset:GetSkeletonData(false):FindAnimation(fromAnim)
    local isHaveTo = toAnim and spineObject.skeletonDataAsset:GetSkeletonData(false):FindAnimation(toAnim)
    if isHaveFrom then
        local cb
        cb = function(track)
            if track.Animation.Name == fromAnim and isHaveTo then
                spineObject.AnimationState:SetAnimation(0, toAnim, true)
                spineObject.AnimationState:Complete('-', cb)
            end
        end
        spineObject.AnimationState:Complete('+', cb)
        spineObject.AnimationState:SetAnimation(0, fromAnim, false)
    elseif isHaveTo then
        spineObject.AnimationState:SetAnimation(0, toAnim, true)
    end
end

-- v2.0 美术要求不同分辨率下支持动画偏移
function XUiLogin:SetScreenOffect(rectTransform)
    local screen = CS.UnityEngine.Screen
    local width = screen.width
    local height = screen.height
    local verticalOffect = 0
    local horizontalOffect = 0

    local x = width / height
    -- 屏幕长宽比保留两位有效小数(舍去极小误差)
    local configKey = x - x % 0.1 ^ 2
    local configVerticalKey = "UiLoginScreenOffect_V_" .. configKey
    local configHorizontalKey = "UiLoginScreenOffect_H_" .. configKey
    if CS.XGame.ClientConfig:TryGetInt(configVerticalKey, false) then
        verticalOffect = CS.XGame.ClientConfig:GetInt(configVerticalKey)
    end
    if CS.XGame.ClientConfig:TryGetInt(configHorizontalKey, false) then
        horizontalOffect = CS.XGame.ClientConfig:GetInt(configHorizontalKey)
    end
    rectTransform.offsetMin = Vector2(horizontalOffect, verticalOffect)
    rectTransform.offsetMax = Vector2(horizontalOffect, verticalOffect)
end

-- auto
-- Automatic generation of code, forbid to edit
function XUiLogin:InitAutoScript()
    self:AutoInitUi()
    self:AutoAddListener()
end

function XUiLogin:AutoInitUi()
    self.BtnStart = self.Transform:Find("SafeAreaContentPane/PanelLogin/BtnStart"):GetComponent("Button")
    self.PanelLoginServer = self.Transform:Find("SafeAreaContentPane/PanelLogin/PanelLoginServer")
    self.PanelUser = self.Transform:Find("SafeAreaContentPane/PanelLogin/PanelUser")
    self.BtnUser = self.Transform:Find("SafeAreaContentPane/PanelLogin/PanelUser/BtnUser"):GetComponent("Button")
    self.TxtUser = self.Transform:Find("SafeAreaContentPane/PanelLogin/PanelUser/BtnUser/TxtUser"):GetComponent("Text")
    self.ImgLogo = self.Transform:Find("SafeAreaContentPane/ImgLogo"):GetComponent("RawImage")
    self.BackGround = self.Transform:Find("FullScreenBackground/BackGround")
    self.TextStart = XUiHelper.TryGetComponent(self.BtnStart.transform, "Text")
end

function XUiLogin:AutoAddListener()
    self:RegisterClickEvent(self.BtnStart, self.OnBtnStartClick)
    self:RegisterClickEvent(self.BtnServer, self.OnBtnServerClick)
    self:RegisterClickEvent(self.BtnUser, self.OnBtnUserClick)
    self:RegisterClickEvent(self.BtnHideServerList, self.OnBtnHideServerListClick)
    self:RegisterClickEvent(self.BtnLoginNotice, self.OnBtnLoginNoticeClick)
    self:RegisterClickEvent(self.BtnCode, self.OnBtnCodeClick)
    self.BtnClosePlayerInfo.CallBack = function()
        self.PanelPlayerInfo.gameObject:SetActiveEx(false)
    end
    self.BtnVideo.CallBack = function()
        self:PlayLoginVideo(true)
    end
    if XMain.IsDebug then
        self.BtnAddServer.gameObject:SetActiveEx(true)
        self.InFAddr.gameObject:SetActiveEx(true)
        self:RegisterClickEvent(self.BtnAddServer, self.OnBtnAddServerClick)
        self.InFAddr.onValueChanged:AddListener(handler(self, self.UpdateSeverList))
    else
        self.BtnAddServer.gameObject:SetActiveEx(false)
        self.InFAddr.gameObject:SetActiveEx(false)
    end
end

-- auto
function XUiLogin:OnBtnLoginNoticeClick()
    XDataCenter.NoticeManager.OpenLoginNotice()
end

function XUiLogin:OnBtnCodeClick()
    CS.XHeroSdkAgent.ScanQRCode()
end

function XUiLogin:OnBtnHideServerListClick()
    self.PanelServerList.gameObject:SetActiveEx(false)
end

function XUiLogin:OnBtnServerClick()
    self:UpdateSeverList()
    self.PanelServerList.gameObject:SetActiveEx(true)
end

function XUiLogin:OnBtnAddServerClick()
    local result, desc = XServerManager.InsertTempServer(self.InFAddr.text)
    if not result then
        XUiManager.TipMsg(desc)
    end
end

function XUiLogin:UpdateSeverList(isForce)
    local keyWord = self.InFAddr.text
    if keyWord == self.LastKeyWord and not isForce then
        XScheduleManager.ScheduleOnce(function()
            self.DynamicTable:ReloadDataSync()
        end, 0)
        return
    end
    self.LastKeyWord = keyWord
    if string.IsNilOrEmpty(keyWord) then
        self.ServerList = XServerManager.GetServerList(true)
        self.DynamicTable:SetDataSource(self.ServerList)
    else
        local showList = {}
        for _, v in ipairs(XServerManager.GetServerList()) do
            if string.match(v.Name, keyWord) then
                table.insert(showList, v)
            end
        end
        table.sort(showList, function(a, b)
            return a.LastTime > b.LastTime
        end)

        self.DynamicTable:SetDataSource(showList)
        self.ServerList = showList
    end
    self.DynamicTable:ReloadDataSync()
end

function XUiLogin:OnBtnUserClick()
    if self.OnBtnUserClickOversea then
        self:OnBtnUserClickOversea()
        return
    end
    if self.IsLoginingGameServer then
        return
    end

    if self.IsLogoutingAccount then
        return
    end

    self.IsLogoutingAccount = true
    XUserManager.Logout(function()
        self.IsLogoutingAccount = false
    end)
end

function XUiLogin:OnBtnStartClick()
    if not self.IsRequestNotice then
        return
    end

    if XLuaUiManager.IsUiShow("UiLoginNotice") then
        return
    end

    if self.IsLogoutingAccount then
        return
    end

    -- if XUserManager.IsNeedLogin() or XUserManager.HasLoginError() then
    --     XUserManager.ShowLogin()
    --     return
    -- end

    -- if self:TryShowUserAgreeTips() then
    --     return
    -- end


    -- XLog.Error("Lua memory Login:" .. CS.XLuaEngine.Env.Memroy)
    if not self:OnBtnStartClickOversea() then
        return
    end
    self:DoLogin()
end

function XUiLogin:OnToggleAgree(value)
    self.IsUserAgree = value
    if value then
        CS.UnityEngine.PlayerPrefs.SetInt(KEY_USER_AGREE, 1)
    else 
        CS.UnityEngine.PlayerPrefs.SetInt(KEY_USER_AGREE, 0)
    end
    self:TryShowUserAgreeTips()
end

function XUiLogin:TryShowUserAgreeTips()
    if XDataCenter.FunctionEventManager.CheckFuncDisable() then return end
    if not self.IsUserAgree then
        local text = CS.XTextManager.GetText("LoginUserAgree")
        XUiManager.TipMsg(text, XUiManager.UiTipType.Tip)
        return true
    end
    return false
end

function XUiLogin:OnClickShowUid() -- 长按触发
    if not self.PanelPlayerInfo.gameObject.activeSelf then
        self:OnBtnStartClick()
    end
end

function XUiLogin:OnLongClickShowUid() -- 长按触发
    self.PanelPlayerInfo.gameObject:SetActiveEx(true)
    self.TxtUid.text = XUserManager.GetUniqueUserId()
end

function XUiLogin:PlayLoginVideo(isReplay)
    local data = {
        VideoUrl = self.VideoUrl,
        Width = self.VideoWidth,
        Height = self.VideoHeight,
    }
    XLuaUiManager.Open("UiVideoPlayer", data, nil, false, false)
    -- if UiLoginMovieTimeStr and UiLoginMovieTimeEnd then
    --     local now = CS.XDateUtil.GetNowTimestamp()
    --     local startTime = XTime.ParseToTimestamp(UiLoginMovieTimeStr)
    --     local endTime = XTime.ParseToTimestamp(UiLoginMovieTimeEnd)
    --     if now <= startTime or now >= endTime then
    --         return
    --     end
    -- end

    -- if UiLoginMovieId and UiLoginMovieId ~= 0 then
    --     if not isReplay then
    --         local key = string.format("LoginVideo-%s-%s", UiLoginMovieId, XPlayer.Id)
    --         local isPlayed = XSaveTool.GetData(key)
    --         if isPlayed == 1 then return end
    --         XSaveTool.SaveData(key, 1)
    --     end
    --     self.GameObject:SetActiveEx(false)
    --     XDataCenter.VideoManager.PlayMovie(UiLoginMovieId, function()
    --         self.GameObject:SetActiveEx(true)
    --     end)
    -- end
end

function XUiLogin:DoLogin()
    if self.DoLoginOversea then
        self:DoLoginOversea()
        return
    end
    if self.IsLoginingGameServer then
        return
    end
    self.IsLoginingGameServer = true

    XLuaUiManager.SetAnimationMask("DoLogin", true)
    local loginProfiler = CS.XProfiler.Create("login")
    loginProfiler:Start()
    XLoginManager.Login(function(code)
        XLuaUiManager.SetAnimationMask("DoLogin", false)
        if code and code ~= XCode.Success then
            if code == XCode.LoginServiceInvalidToken then
                XUserManager.ClearLoginData()
                -- XUserManager.ShowLogin()
            end

            self.IsLoginingGameServer = false
            return
        end

        --CS.XAudioManager.PlayMusic(CS.XAudioManager.MAIN_BGM)
        local runMainProfiler = loginProfiler:CreateChild("RunMain")
        runMainProfiler:Start()

        --打开水印窗口
        if CS.XRemoteConfig.WatermarkType == WaterMarkStatus.AllOn then
            XLuaUiManager.Open("UiWaterMask")
            XLuaUiManager.Open("UiSuperWaterMarks")
        elseif CS.XRemoteConfig.WatermarkType == WaterMarkStatus.OnlyWaterMarkOn then
            XLuaUiManager.Open("UiWaterMask")
        elseif CS.XRemoteConfig.WatermarkType == WaterMarkStatus.OnlySuperWaterMarkOn then
            XLuaUiManager.Open("UiSuperWaterMarks")
        end

        --BDC
        CS.XHeroBdcAgent.BdcAfterSdkLoginPage()

        XDataCenter.PurchaseManager.YKInfoDataReq(function()
            self.BlackMask.color = CS.UnityEngine.Color(0, 0, 0, 0)
            self.BlackMask.gameObject:SetActiveEx(true)
            self.BlackMask:DOFade(1.1, 0.3):OnComplete(function()
                local guideFight = XDataCenter.GuideManager.GetNextGuideFight()
                if guideFight then
                    self:Close()
                    -- 海外打点
                    --CheckPoint: APPEVENT_ANIM_START_1
                    XAppEventManager.AppLogEvent(XAppEventManager.CommonEventNameConfig.Anime_Start)
                    --CheckPoint: APPEVENT_COMPLETED_REGISTRATION_1
                    XAppEventManager.AppLogEvent(XAppEventManager.CommonEventNameConfig.Completed_Registration)
                    local movieId = CS.XGame.ClientConfig:GetString("NewUserMovieId")
                    XDataCenter.MovieManager.PlayMovie(movieId, function()
                        XDataCenter.FubenManager.EnterGuideFight(guideFight.Id, guideFight.StageId, guideFight.NpcId, guideFight.Weapon)
                    end)
                else
                    XLoginManager.SetFirstOpenMainUi(true)
                    XLuaUiManager.RunMain()
                end
            end)
            -- 设置月卡信息本地缓存
            XDataCenter.PurchaseManager.SetYKLocalCache()
            self:OnCheckBindTask() -- 检查绑定任务，可以触发完成任务
        end)

        XDataCenter.SetManager.SetOwnFontSizeByCache()
        runMainProfiler:Stop()

        loginProfiler:Stop()
        XLog.Debug(loginProfiler)
    end)
end

function XUiLogin:RequestLoginNotice()
    if self.RequestLoginNoticeOversea then
        self:RequestLoginNoticeOversea()
        return
    end
    if XMain.IsDebug and XDataCenter.NoticeManager.CheckFuncDisable() then
        self.IsRequestNotice = true
        return
    end
    XLuaUiManager.SetAnimationMask("RequestLoginNotice", true)
    XDataCenter.NoticeManager.RequestLoginNotice(function(isValid)
       
        self.IsRequestNotice = true
        XLuaUiManager.SetAnimationMask("RequestLoginNotice", false)
        local btnLoginNotice = self:IsPc() and self.BtnLoginNoticePc or self.BtnLoginNotice
        if not XTool.UObjIsNil(btnLoginNotice) then
            btnLoginNotice.gameObject:SetActiveEx(isValid)
        end
        XDataCenter.NoticeManager.AutoOpenLoginNotice()
    end)
end

function XUiLogin:RequestLoginNoticeOversea()
    XLuaUiManager.SetAnimationMask(true)
    XDataCenter.NoticeManager.RequestLoginNotice(function(invalid)
        self.IsRequestNotice = true
        XLuaUiManager.SetAnimationMask(false)
        XDataCenter.NoticeManager.AutoOpenLoginNotice()
    end)
end

-- 在en可能没有生效
function XUiLogin:RequestNotice()
    if XMain.IsDebug and XDataCenter.NoticeManager.CheckFuncDisable() then
        self.IsRequestNotice = true
        return
    end

    local noticeTypeLogin   = XDataCenter.NoticeManager.NoticeType.Login
    local noticeTypeInGame  = XDataCenter.NoticeManager.NoticeType.InGame
    --需要打开Ui的公告类型
    self.OpUiNoticeTypes = {
        [noticeTypeLogin]    = true,
        [noticeTypeInGame]   = true
    }
    --登陆公告协议
    XDataCenter.NoticeManager.RequestLoginNotice(function(isValid)
        self:OnLoginNoticeResponse(isValid)
        if self.NeedAutoLoginByAF and not openNotice then
            self:AutoDoLogin()
        else
            self.OpUiNoticeTypes[noticeTypeLogin] = nil
            self:OnNoticeResponse()
        end
    end)

    --游戏公告协议
    XDataCenter.NoticeManager.RequestInGameNotice(function(isValid)
        self.IsRequestNotice = true
        XLuaUiManager.SetAnimationMask("RequestLoginNotice", false)
        self.OpUiNoticeTypes[noticeTypeInGame] = nil
        self:OnNoticeResponse()
    end, os.time())

end

function XUiLogin:OnLoginNoticeResponse(isValid)
    local btnLoginNotice = self:IsPc() and self.BtnLoginNoticePc or self.BtnLoginNotice
    if not XTool.UObjIsNil(btnLoginNotice) then
        btnLoginNotice.gameObject:SetActiveEx(isValid)
    end
end

--等到全部协议返回 在en可能没有生效
function XUiLogin:OnNoticeResponse()
    if XTool.IsTableEmpty(self.OpUiNoticeTypes) then
        --打开窗口优先级
        for idx, func in ipairs(NoticeOpenFuncList) do
            local isOpen = func()
            if isOpen then
                NoticeOpenIndex = idx
                break
            end
        end
    end
end

--顺序打开Ui界面
function XUiLogin:OnUiDestroy(uiData)
    if not (uiData and uiData.UiData) then
        return
    end
    local uiName = uiData.UiData.UiName
    if not uiName or not NoticeNameMap[uiName] then
        return
    end
    
    local NoticeUiCount = #NoticeOpenFuncList
    if NoticeOpenIndex > NoticeUiCount then
        return
    end
    
    NoticeOpenIndex = NoticeOpenIndex + 1
    if NoticeOpenIndex > NoticeUiCount then
        return
    end
    for i = NoticeOpenIndex, NoticeUiCount do
        local func = NoticeOpenFuncList[i]
        local isOpen = func and func() or false
        if isOpen then
            NoticeOpenIndex = i
            break
        end
    end
end

--动态列表事件
function XUiLogin:OnDynamicTableEvent(event, index, grid)
    if event == DYNAMIC_DELEGATE_EVENT.DYNAMIC_GRID_INIT then
        grid:Init(self)
    elseif event == DYNAMIC_DELEGATE_EVENT.DYNAMIC_GRID_ATINDEX then
        local server = self.ServerList[index]
        if not server then return end
        grid:Refresh(server)
        XServerManager.TestConnectivity(server, function() grid:UpdateServerState() end)
    elseif event == DYNAMIC_DELEGATE_EVENT.DYNAMIC_GRID_TOUCHED then
        self.BtnServerOversea:SetName(grid.Server.Name)
        self:SelectServer(grid.Server)
        self.PanelServerList.gameObject:SetActiveEx(false)
    elseif event == DYNAMIC_DELEGATE_EVENT.DYNAMIC_GRID_RECYCLE then
        grid:OnRecycle()
    end
end

function XUiLogin:UpdateSelectServer(currentServer) 
    self.BtnServerOversea:SetName(currentServer.Name)
end

function XUiLogin:SelectServer(server)
    XServerManager.Select(server)
    if self:IsPc() then
        self.TxtServerPc.text = server.Name
    end
    XLog.Debug("当前选择的服务器为：" .. server.Name .. "\n Url = " .. server.LoginUrl)
end

--region pc
function XUiLogin:InitPcUi()
    if not self:IsPc() then
        self.PanelUser.gameObject:SetActiveEx(true)
        self.PanelUserPc.gameObject:SetActiveEx(false)
        return
    end
    self.PanelUser.gameObject:SetActiveEx(false)
    self.PanelUserPc.gameObject:SetActiveEx(true)
    self.BtnLoginNoticePc.gameObject:SetActiveEx(false)

    self:RegisterClickEvent(self.BtnUserPc, self.OnBtnUserClickPc)
    self:RegisterClickEvent(self.BtnLoginNoticePc, self.OnBtnLoginNoticeClickPC)
    self:UpdatePcUi()
end

function XUiLogin:UpdatePcUi()
    local userName = XUserManager.UserName
    self.TxtUserPc.text = userName
    if not self:IsUserNameEmpty(userName) then
        self.TxtServerPc.text = XServerManager.GetCurServerName()
        self.PanelUserInfoPc.gameObject:SetActiveEx(true)
    else
        self.PanelUserInfoPc.gameObject:SetActiveEx(false)
    end
end

function XUiLogin:IsPc()
    return false --不特殊处理pc
    --return XDataCenter.UiPcManager.IsPc()
end

function XUiLogin:IsUserNameEmpty(userName)
    userName = userName or XUserManager.UserName
    return userName == nil or userName == ""
end

function XUiLogin:OnBtnUserClickPc()
    if self:IsUserNameEmpty() then
        self:OnBtnStartClick()
    else
        XLuaUiManager.Open("UiPcServer")
    end
end

function XUiLogin:OnBtnLoginNoticeClickPC()
    self:OnBtnLoginNoticeClick()
end

function XUiLogin:OnDestroy()
    self:OnDestroyOversea()
end

--endregion

--region oversea

function XUiLogin:OnAwakeOversea()
    self:AutoInitUiOversea()
    self:AutoAddListenerOversea()
    XEventManager.AddEventListener(XEventId.EVNET_HGSDKLOGIN_SUCCESS, self.OnHgSdkLoginSuccess, self)
    XEventManager.AddEventListener(XEventId.EVENT_AGREEMENT_LOAD_FINISH, self.OnLoadAgreementFinish, self)
    XEventManager.AddEventListener(XEventId.EVENT_WHEN_CLOSE_LOGIN_NOTICE, self.OnCloseLoginNotice, self)
    XEventManager.BindEvent(self.TxtUser, XEventId.EVENT_USERID_CHANGE, function(userName)
        self.TxtUser.text = userName or ""
    end)
    XEventManager.BindEvent(self.TxtUser, XEventId.EVNET_HGSDKLOGIN_SUCCESS, function()
        self.TxtUser.text = XUserManager.UserId or ""
    end)

    if XUserManager.Channel ~= XUserManager.CHANNEL.KURO_SDK or XUserManager.Channel ~= XUserManager.CHANNEL.KuroPC then 
        self.TxtUser.text = XUserManager.UserName
        XEventManager.BindEvent(self.TxtUser, XEventId.EVENT_USERID_CHANGE, function(userName)
            self.TxtUser.text = userName or ""
            XLog.Warning("XEventId.EVENT_USERID_CHANGE")
        end)
    else 
        self.TxtUser.text = XUserManager.UserId
    end
end

function XUiLogin:AutoInitUiOversea()
    self.SafeAreaContentPane = self.Transform:Find("SafeAreaContentPane")
    self.SafeAreaContentPane.gameObject:AddComponent(typeof(CS.XUiLoadPrefab))
    self.PanelNetworkModeTip = self.SafeAreaContentPane:LoadPrefab("Assets/Product/Ui/ComponentPrefab/UiLogin/PanelNetworkModeTip.prefab")
    self.PanelLoginNetworkMode = XUiLoginNetworkModePanel.New(self, self.PanelNetworkModeTip)
    self.PanelLoginNetworkMode.GameObject:SetActiveEx(false)

    self.PanelLogin = self.SafeAreaContentPane:Find("PanelLogin")
    self.PanelLogin.gameObject:AddComponent(typeof(CS.XUiLoadPrefab))
    self.BtnServerOversea = self.PanelLogin:LoadPrefab("Assets/Product/Ui/ComponentPrefab/UiLogin/BtnServer.prefab"):GetComponent(typeof(CS.XUiComponent.XUiButton))
    
    self.PanelUser.gameObject:AddComponent(typeof(CS.XUiLoadPrefab))
    self.BtnNetworkMode = self.PanelUser:LoadPrefab("Assets/Product/Ui/ComponentPrefab/UiLogin/BtnNetworkMode.prefab"):GetComponent(typeof(CS.XUiComponent.XUiButton))
    
end

function XUiLogin:OnStartOversea()
    self:RequestLoginNotice()
    self.BtnServer.gameObject:SetActiveEx(false)  
    self.PanelUser.gameObject:SetActiveEx(true)

    XAgreementManager.LoadAgreeInfo()
    if XUserManager.Channel ~= XUserManager.CHANNEL.KuroPC then 
        self.TxtUser.text = XUserManager.UserId or ""
    else 
        self.TxtUser.text = ""
    end
end

function XUiLogin:OnBtnUserClickOversea()
    if self.ClickCount == nil then
        self.ClickCount = 0
        return
    end
    self.ClickCount = self.ClickCount + 1
    if self.ClickCount == 10 then
        local type = CS.XRemoteConfig.Channel
        type = type + 1
        if type == 5 then
            type = 1
        end
        CS.XRemoteConfig.Channel = type
        XUiManager.TipError("Network connect Type changed to " .. type)
        self.ClickCount = 0
    end
end

function XUiLogin:OnEnableOversea()
end

function XUiLogin:InitServerPanelOversea()
    local list = XServerManager.GetServerList(true)
    for _, server in pairs(list) do
        if server.Id == XServerManager.Id then
            self.BtnServerOversea:SetName(server.Name)
            break
        end
    end
end

function XUiLogin:InitServerPanelOversea()
    local list = XServerManager.GetServerList(true)
    for _, server in pairs(list) do
        if server.Id == XServerManager.Id then
            self.BtnServerOversea:SetName(server.Name)
            break
        end
    end
end

function XUiLogin:OnBtnStartClickOversea()
    --如果默认的用户没有同意协议，则弹出用户协议
    --当用户成功登录后，将同意协议存储在本地，不再需要同意协议
    if XLoginManager.GetSDKAccountStatus() == XLoginManager.SDKAccountStatus.Cancellation then
        XUiManager.DialogTip(CS.XGame.ClientConfig:GetString("AccountUnCancellationTitle"), CS.XGame.ClientConfig:GetString("AccountUnCancellationContent"), nil, function() end, function()
            XHgSdkManager.AccountUnCancellation()
        end)
        return
    end
    if XAgreementManager.CheckNeedShow() then
        XLuaUiManager.Open("UiLoginAgreement")
        return
    end

    if not self.IsRequestNotice then
        return
    end

    XAppEventManager.AppLogEvent(XAppEventManager.CommonEventNameConfig.SDK_Login)

    if XUserManager.IsNeedLogin() then
        XUserManager.ShowLogin()
    else
        self:DoLogin()
    end
end

function XUiLogin:OnDisableOversea()
    self.IsInLogin = false
end

function XUiLogin:OnDestroyOversea()
    XEventManager.RemoveEventListener(XEventId.EVNET_HGSDKLOGIN_SUCCESS, self.OnHgSdkLoginSuccess, self)
    XEventManager.RemoveEventListener(XEventId.EVENT_AGREEMENT_LOAD_FINISH, self.OnLoadAgreementFinish, self)
    XEventManager.RemoveEventListener(XEventId.EVENT_WHEN_CLOSE_LOGIN_NOTICE, self.OnCloseLoginNotice, self)
    XEventManager.UnBindEvent(self.TxtUser)
end

function XUiLogin:AutoAddListenerOversea()
    self:RegisterClickEvent(self.BtnServerOversea, self.OnBtnServerClick)
    self:RegisterClickEvent(self.SwitchAccount, self.OnSwitchAccountClick)
    self:RegisterClickEvent(self.PanelAgree, self.OnAgreePanelClick)
    self:RegisterClickEvent(self.BtnMenu, self.OnBtnMenuClick)

    self.BtnNetworkMode.CallBack = function() self:OnBtnNetworkModeClick() end
end

function XUiLogin:OnBtnNetworkModeClick()
    self.PanelLoginNetworkMode:Show()
end

function XUiLogin:OnSwitchAccountClick()
    if XUserManager.Channel == XUserManager.CHANNEL.Android or XUserManager.Channel == XUserManager.CHANNEL.IOS then
        XAppEventManager.AppLogEvent(XAppEventManager.CommonEventNameConfig.Change_account)
        XLuaUiManager.Open("UiLoginDialog", "Account")
    elseif XUserManager.Channel == XUserManager.CHANNEL.KuroPC then 
        XUserManager.Logout()
    else
        CsXUiManager.Instance:Open("UiRegister")
    end
end

function XUiLogin:OnAgreePanelClick()
    XLuaUiManager.Open("UiLoginAgreement")
end

function XUiLogin:OnBtnMenuClick()
    XLuaUiManager.Open("UiLoginDialog", "Menu")
end

function XUiLogin:DoLoginOversea()
    if self.IsInLogin then
        return
    end
    self.IsInLogin = true
    XLuaUiManager.SetAnimationMask(true)
    local loginProfiler = CS.XProfiler.Create("login")
    loginProfiler:Start()
    XLoginManager.Login(function(code)
        XLuaUiManager.SetAnimationMask(false)
        if code and code ~= XCode.Success then
            if code == XCode.Fail then
                self.IsInLogin = false
                return
            end
            if code == XCode.LoginServiceInvalidToken then
                self.IsInLogin = false
                XUserManager.SignOut()
                -- XUserManager.ShowLogin()
            end
            self.IsInLogin = false
            return
        end

        --CS.XAudioManager.PlayMusic(CS.XAudioManager.MAIN_BGM)

        local runMainProfiler = loginProfiler:CreateChild("RunMain")
        runMainProfiler:Start()

        --BDC
        CS.XHeroBdcAgent.BdcAfterSdkLoginPage()

        XDataCenter.PurchaseManager.YKInfoDataReq(function()
            if self.BlackMask then
                self.BlackMask.color = CS.UnityEngine.Color(0.0, 0.0, 0.0, 0.0)
                self.BlackMask.gameObject:SetActive(true)
                self.BlackMask:DOFade(1.1, 0.3):OnComplete(function()
                    local guideFight = XDataCenter.GuideManager.GetNextGuideFight()
                    if guideFight then
                        self:Close()

                        XAppEventManager.AppLogEvent(XAppEventManager.CommonEventNameConfig.Anime_Start)
                        XAppEventManager.AppLogEvent(XAppEventManager.CommonEventNameConfig.Completed_Registration)

                        local movieId = CS.XGame.ClientConfig:GetString("NewUserMovieId")
                        XDataCenter.MovieManager.PlayMovie(movieId, function()
                            XDataCenter.FubenManager.EnterGuideFight(guideFight.Id, guideFight.StageId, guideFight.NpcId, guideFight.Weapon)
                        end)
                    else
                        XLoginManager.SetFirstOpenMainUi(true)
                        XLuaUiManager.RunMain()
                    end
                end)
            else
                local guideFight = XDataCenter.GuideManager.GetNextGuideFight()
                if guideFight then
                    self:Close()

                    XAppEventManager.AppLogEvent(XAppEventManager.CommonEventNameConfig.Anime_Start)
                    XAppEventManager.AppLogEvent(XAppEventManager.CommonEventNameConfig.Completed_Registration)

                    local movieId = CS.XGame.ClientConfig:GetString("NewUserMovieId")
                    XDataCenter.MovieManager.PlayMovie(movieId, function()
                        XDataCenter.FubenManager.EnterGuideFight(guideFight.Id, guideFight.StageId, guideFight.NpcId, guideFight.Weapon)
                    end)
                else
                    XLoginManager.SetFirstOpenMainUi(true)
                    XLuaUiManager.RunMain()
                end
            end
            self:OnCheckBindTask() 
        end)

        XDataCenter.SetManager.SetOwnFontSizeByCache()
        runMainProfiler:Stop()

        loginProfiler:Stop()
        XLog.Debug(loginProfiler)
    end)
end

function XUiLogin:OnHgSdkLoginSuccess()
    self.PanelUser.gameObject:SetActiveEx(true)
    self.BtnStart.gameObject:SetActiveEx(true)
    -- self:OnUserIDChange()
    if XUserManager.UserId then -- 海外修改
        local user_ServerId = XSaveTool.GetData(XPrefs.User_ServerId..XUserManager.UserId)
        local user_ServerId_Num = tonumber(user_ServerId)
        XLog.Debug("User_ServerId:"..XPrefs.User_ServerId..XUserManager.UserId..":"..tostring(user_ServerId))
        self.TxtUser.text = XUserManager.UserId;
        local serverDataList = XServerManager.GetServerList()
        -- user_ServerId_Num 才是真实的serverId
        if user_ServerId and user_ServerId_Num then
            local currentServer;
            for _, server in ipairs(serverDataList) do
                if server.Id == user_ServerId_Num then
                    currentServer = server;
                end
            end
            if currentServer then
                XServerManager.Select(currentServer);
                self:UpdateSelectServer(currentServer);
            end
        else
            self:UpdateSeverList()
            self.PanelServerList.gameObject:SetActiveEx(true)
        end
    end
end

function XUiLogin:OnLoadAgreementFinish()
    if XLuaUiManager.IsUiShow("UiLoginNotice") then
        return
    end
    if XAgreementManager.CheckNeedShow() then
        if not XLuaUiManager.IsUiShow("UiLoginAgreement") then
            XLuaUiManager.Open("UiLoginAgreement")
        end
    end
end

function XUiLogin:OnDeepLinkPush2Login()
    self.NeedAutoLoginByAF = true
    self:RequestLoginNotice() -- 切回来重新请求一次登录提示并触发自动登录
end

function XUiLogin:OnCloseLoginNotice()
    if XAgreementManager.CheckNeedShow() then
        if not XLuaUiManager.IsUiShow("UiLoginAgreement") then
            XLuaUiManager.Open("UiLoginAgreement")
        end
    end
end

function XUiLogin:OnCheckBindTask()
    if XUserManager.UserType == XHgSdkManager.UserType.FaceBook or XUserManager.UserType == XHgSdkManager.UserType.Apple or XUserManager.UserType == XHgSdkManager.UserType.Google
    or XUserManager.UserType == XHgSdkManager.UserType.Twitter then
        XHgSdkManager.OnBindTaskFinished()
    elseif XDataCenter.UiPcManager.IsPc() then
        XHgSdkManager.OnBindTaskFinished()
    end
end

--endregion