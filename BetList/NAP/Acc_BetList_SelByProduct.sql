/*<info serverAlias="DBAGE-BODB02" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetList_SelByProduct]
	@ProductId		TINYINT,
	@CustId			INT				= 0,
	@Username		NVARCHAR(50)	= '',
	@GameId			VARCHAR(100)	= '',
	@BetId			VARCHAR(100)	= '',
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@Permission		VARCHAR(20)		= '1,2,3',
	@DeniedList		VARCHAR(MAX) = ''
AS

/*
	Created by: 20160609@Kos
	Task: Search tickets by product
	DB: DBAGE.bodb02
	Original:
	
	Parameter Explanantion
		- @Permission
			- 1: Credit sites
			- 2: Deposit sites
			- 3: CN88
	
	Revisions:
		- 20160623@Kos: Hide special sites from unauthorized users [#Redmine: 48948]
		- 20160906@Kos: Support AllBet [#Redmine: 61876]
		- 20161202@Kos: Support Fishing World [#Redmine: 65934]
		- 20171025@Kos: Support Bullfighting [#Redmine: 84961]
		- 20180328@Kos: Increase Transdesc length to 1000 [Redmine: #92841]
		- 20180405@Kos: Support Pragmatic Casino [#Redmine: 92160]
		- 20180515@Kos: Add Match No for Bullfighting [#Redmine: 84961]
		- 20180709@Kos: Support Poker Games [#Redmine: 97565]
		- 20180808@Helen: DB05.DBPOLICY migration - Move to DBCUST [Redmine:99462]
		- 20180927@Kos: Add new permission to view Licensee account [#Redmine: 96118]
		- 20181115@Kos: Hotfix - Bullfighting [#Redmine: 104833]
		- 20190321@Kos: Support Pragmatic Promotion Prize [#Redmine: 108117]
		- 20190531@Kos: Add new input param @Permission VARCHAR(20) [#Redmine: 114125]
					- Remove param @SiteType
		- 20190611@Kos: Support Card Club [#Redmine: 107645]
					- Don't support Poker Games anymore
		- 20190829@Kos: Don't support inactive products anymore [Redmine: #119100]
		- 20191029@Kos: Support Spadegaming [Redmine: #122140]
		- 20191218@Kos: Support Virtual Games [Redmine: #124759]
		- 20200222@Kos: Support SA Gaming [Redmine: #128048]
		- 20200324@Kos: Support Sexy Gaming [Redmine: #130680]
		- 20200331@Kos: Support Saba.club [Redmine: #130769]
		- 20200421@Kos: Support IBCBet Live Casino [Redmine: #130688]
		- 20200514@Kos: Support BBIN [Redmine: #131362]
		- 20200525@Kos: Support ION [Redmine: #132329]
		- 20200709@Kos: Support PP Jackpot [Redmine: #137284]
					- Return additional column BetdaqId BIGINT
		- 20200731@Kos: Support Saba.club Result [Redmine: #137680]
		- 20200808@Kos: Support PG Soft [Redmine: #137769]
		- 20200919@Kos: Support Joker [Redmine: #137942]
		- 20200930@Kos: Support GameId3rd for PG Soft [Redmine: #137769]
		- 20201001@Kos: Support WM Live Casino [Redmine: #131588]
		- 20201203@Kos: Support GDG [Redmine: #144104]
		- 20201218@Kos: Support SiteId for GDG [Redmine: #147084]
		- 20210112@Kos: Support Big Gaming [Redmine: #142455]
		- 20210114@Kos: Support MaxGame [Redmine: #147568]
					- Return additional column EventDate DATETIME
		- 20210119@Kos: Support Saba.club Jackpot Contribution and Jackpot Prize tickets [Redmine: #147709]
		- 20210301@Razor: Support Sports Lottery [Redmine: #147368]
		- 20210311@Razor: Support PP Live Casino [Redmine: #134042]
		- 20210319@Razor: Support Habanero [Redmine: #145460]
		- 20210402@Razor: Support CG [Redmine: #146020]
		- 20210429@Razor: Support VGaming [Redmine: #154047]
		- 20210513@Razor: Support AdvantPlay [Redmine: #154259]
		- 20210513@Razor: Support AdvantPlay Mini [Redmine: #155134]
		- 20211004@Razor: Extend Data type of IP v6 [Redmine: #90903]
		- 20211222@Razor: BBIN Support Third Party Result API [Redmine: #165158]
		- 20211223@Razor: Support Third Party Result API [Redmine: #165815]
		- 20220209@Razor: Support TxId for 3rd products [Redmine: #167320]
		- 20220215@Razor: VGaming, Sabaclub return SiteId on MatchCode property
		- 20220215@Razor: Support SG Jackpot [Redmine: #166683]
		- 20220317@Razor: Support FGG [Redmine: #165683]
		- 20220324@Razor: Support TxId for VGaming [Redmine: #170054]
		- 20220422@Razor: Support Virtual games result [Redmine: #170997]
		- 20220825@Razor: Support SEAL Entertainment [Redmine: #176210]
		- 20220909@Razor: Support Microgaming RNG Casino [Redmine: #175851]
		- 20230206@Razor: Support Jili [Redmine: #182864]
		- 20230417@Razor: Remove Betfrom column [Redmine: #126137]
		- 20230526@Razor: Support YeeBet [Redmine: #186547]
		- 20230830@Razor: Show LicTxId for MaxGame [Redmine: #193273]
		- 20230909@Razor: Remove GDG, Fishing World products [Redmine: #174511]
		- 20230909@Razor: Remove GD, Colossusbet products [Redmine: #179132]
		- 20231016@Razor: HF for not show product Virtual Games, Sports Lottery [Redmine: #195487]
		- 20231017@Razor: Support show max payout [Redmine: #194491]
					- Return new JackpotInfo column
					- Return ExtraInfo for show Max Payout
		- 20231019@Razor: Return Device Type info [Redmine: #192667]
		- 20231108@Razor: Support WE Live Casino [Redmine: #195887]
		- 20231215@Razor: Support Live22 [Redmine: #197609]
		- 20240105@Razor: Extend data type [Redmine: #199259]
		- 20240206@Razor: Support new Game API related to TransId3rd/BetId3rd [Redmine: #199259]
		- 20240207@Kos: Return GameId3rd to support Live22 Result [Redmine: #197609]
		- 20240222@Razor: Fix to call sp version on function [Redmine: #197160]
		- 20240325@Razor: Enhance search TranId3rd/BetId3rd/GameId3rd [Redmine: #201962]
		- 20240327@Kos: Support UU Slots [Redmine: #192600]
		- 20240411@Razor: Return TranId3rd for Running ticket of Virtual Games/SportsLottery [Redmine: #203734]
		- 20240417@Razor: Support Saba xD [Redmine: #203371]
		- 20240507@Razor: Check permission for Real Currency [Redmine: #202523]
		- 20240626@Razor: Support FastSpin [Redmine: #205742]
		- 20240717@Razor: Support FA CHAI [Redmine: #206633]
		- 20240806@Razor: Support Nextspin [Redmine: #199985]
		- 20240912@Razor: Support ON Casino [Redmine: #210026]
		- 20241003@Razor: Remove Linked Server on DBCust [Redmine: #206893]
		- 20241003@Razor: Support VS2 - Racing sports [Redmine: #211092]
		- 20241023@Razor: Support Playtech [Redmine: #210553]
		- 20241023@Razor: Support GPI [Redmine: #207173]
		- 20241202@Razor: Support GPI Live Casino [Redmine: #213486]
		- 20241231@Razor: Support PLAY STAR [Redmine: #208023]
		- 20250106@Razor: SA Gaming support Saba Plus [Redmine: #215645]
		- 20250213@Razor: Support ASKMESLOT [Redmine: #216976]
		- 20250218@Razor: Support SABA Keno [Redmine: #214757]
		- 20250312@Benji: Support Funky Games [Redmine: #218176]
		- 20250326@Benji: Support Upcoming Product (HOTDOG, Kiron VS7, Microgaming Live Casino, GPI Lottery, ODIN GAMING, Playtech Live Casino ) [Redmine: #221188]
		- 20250410@Benji: Remove productID 101,107 (Microgaming Live Casino, Playtech Live Casino) [Redmine: #221188]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix --
	DECLARE @SportBettype TABLE (ProductID TINYINT, BetType SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (@ProductId, 0, 0, 2, '', '', @IsTest)

	-- Get CustId if @CustId IS NULL
	IF @CustId IS NULL OR @CustId = 0
	BEGIN
		SELECT @CustId = custid
		FROM dbo.custInfo WITH (NOLOCK)
		WHERE username = @Username
	END

	DECLARE @Data TABLE (
		BetType			INT,
		TransId			BIGINT,
		BetId			BIGINT,
		RefNo			NVARCHAR(50),
		MatchCode		NVARCHAR(1000),
		EventDate		DATETIME,
		SDiscount		SMALLMONEY,
		ADiscount		SMALLMONEY,
		Discount		SMALLMONEY,
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		OddsType		TINYINT,
		Status			NVARCHAR(50),
		ComStatus		NVARCHAR(50),
		Stake			MONEY,
		Actual_Stake	MONEY,
		TransDate		DATETIME,
		BetTeam			NVARCHAR(200),
		SPositionTaking	SMALLMONEY,
		MPositionTaking	SMALLMONEY,
		APositionTaking	SMALLMONEY,
		LiveIndicator	BIT,
		CustId			INT,
		LiveHomeScore	INT,
		LiveAwayScore	INT,
		LeagueId		INT,
		SportType		INT,
		Ip				VARCHAR(45),
		MatchId			INT,
		WinLost			MONEY,
		Commission		MONEY,
		SComm			MONEY,
		AComm			MONEY,
		Comm			MONEY,
		AWinLost		MONEY,
		MWinLost		MONEY,
		SWinLost		MONEY,
		WinLostDate		SMALLDATETIME,
		BetCheck		NVARCHAR(2000),
		TransDesc		NVARCHAR(1000),
		OddsSpread		SMALLMONEY,
		ExtraInfo		VARCHAR(1000),
		JackpotInfo		VARCHAR(50),
		BetdaqId		BIGINT,
		CurrencyId		TINYINT,
		SiteId			VARCHAR(7),
		DeviceType		TINYINT
	)

	DECLARE @TempFromDate	SMALLDATETIME,
		@TempToDate			SMALLDATETIME

	DECLARE @DeniedSite TABLE (
		SiteId			INT,
		Site			NVARCHAR(50))

	DECLARE @DeniedCurrency TABLE (
		ExchangeId			INT)

	IF @DeniedList <> ''
	BEGIN
		INSERT INTO @DeniedSite(SiteId, Site)
		SELECT vl.ID, vl.Name
		FROM OPENJSON(@DeniedList) 
				WITH (  [KeyName]	VARCHAR(30),
						[Value]	NVARCHAR(MAX) AS JSON
					) AS js
		CROSS APPLY OPENJSON (js.[value])
				WITH (  [ID]	INT,
						[Name]	NVARCHAR(30),
						[Opt]	TINYINT
					) AS vl
		WHERE js.[KeyName]='Site'

		INSERT INTO @DeniedCurrency (ExchangeId)
		SELECT vl.ID
		FROM OPENJSON(@DeniedList) 
				WITH (  [KeyName]	VARCHAR(30),
						[Value]		NVARCHAR(MAX) AS JSON
					) AS js
		CROSS APPLY OPENJSON (js.[value])
				WITH (  [ID]	INT,
						[Name]	NVARCHAR(30),
						[Opt]	TINYINT
					) AS vl
		WHERE js.[KeyName]='Exchange'
	END

	INSERT INTO @DeniedSite (SiteId, Site)
	SELECT
		s.siteid,
		s.site
	FROM dbo.Site AS s WITH (NOLOCK)
	WHERE NOT EXISTS (SELECT 1 FROM @DeniedSite WHERE SiteId = s.siteid)
		AND ((s.isLicensee = 0									-- Don't have Credit sites permission
				AND s.site <> 'cn88'
				AND ',' + @Permission + ',' NOT LIKE '%,1,%')
			OR (s.isLicensee = 1								-- Don't have Deposit sites permission
				AND s.site <> 'cn88'
				AND ',' + @Permission + ',' NOT LIKE '%,2,%')
			OR (s.site = 'cn88'									-- Don't have CN88 site permission
				AND ',' + @Permission + ',' NOT LIKE '%,3,%'))

	IF NOT EXISTS ( SELECT 1
					FROM dbo.customer AS c WITH (NOLOCK)
						INNER JOIN dbo.customer AS a WITH (NOLOCK) ON c.recommend = a.custid
						WHERE c.custid = @CustId
							AND a.site IN (SELECT Site FROM @DeniedSite))
		AND NOT EXISTS ( SELECT 1
						FROM dbo.customer AS c WITH (NOLOCK)
						WHERE c.custid = @CustId
							AND c.currency IN (SELECT ExchangeId FROM @DeniedCurrency))
	BEGIN
		-- bettrans range
		IF @Todate > @MoveBetsDay
		BEGIN
			IF @FromDate <= @MoveBetsDay
				SET @TempFromDate =  DATEADD(DAY, 1, @MoveBetsDay)
			ELSE
				SET @TempFromDate = @FromDate

			-- Virtual Games, Sports Lottery
			IF @ProductId IN (38, 63)
			BEGIN
				IF @GameId <> ''
				BEGIN
					-- translog
					INSERT INTO @Data
					SELECT
						b.gameid AS BetType,
						b.translogid AS TransId,
						0 AS BetId,
						b.translogid AS RefNo,
						'' AS MatchCode,
						'' AS EventDate,
						b.sdiscount,
						b.adiscount,
						b.discount,
						0 AS HomeId,
						0 AS AwayId,
						0 AS Hdp1,
						0 AS Hdp2,
						b.odds,
						0 AS OddsType,
						b.status,
						0 AS ComStatus,
						b.stake,
						b.actual_stake,
						b.transdate,
						'' AS BetTeam,
						b.spositiontaking,
						b.mpositiontaking,
						b.apositiontaking,
						0 AS LiveIndicator,
						b.custid,
						0 AS LiveHomeScore,
						0 AS LiveAwayScore,
						0 AS LeagueId,
						b.productID AS SportType,
						b.ip,
						0 AS MatchId,
						(- b.actual_stake) AS WinLost,
						0 AS Commission,
						0 AS SComm,
						0 AS AComm,
						0 AS Comm,
						0 AS AWinLost,
						0 AS MWinLost,
						0 AS SWinLost,
						b.winlostdate,
						b.TranId3rd AS BetCheck,
						CASE
							WHEN s.ProductID IN (38, 63) THEN ISNULL(b.transdesc, '')
							ELSE ''
						END AS TransDesc,
						0 AS OddsSpread,
						'' AS ExtraInfo,
						'' AS JackpotInfo,
						-1 AS BetdaqId,
						b.currency,
						b.SiteId,
						b.DeviceType
					FROM dbo.translog AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.BetType = b.gameID
						CROSS APPLY (SELECT TOP 1 val FROM dbo.f_StringSplit(b.TranId3rd, '|$|') ORDER BY id DESC) AS t3rd
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
						AND b.statusID IN (0, 1)
						AND t3rd.val = @GameId
				END

				IF @GameId <> ''
				BEGIN
					INSERT INTO @Data
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetId,
						b.refno,
						'' AS MatchCode,
						'' AS EventDate,
						b.sdiscount,
						b.adiscount,
						b.discount,
						0 AS HomeId,
						0 AS AwayId,
						0 AS Hdp1,
						0 AS Hdp2,
						b.odds,
						0 AS OddsType,
						b.status,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS ComStatus,
						b.stake,
						b.actual_stake,
						b.transdate,
						'' AS BetTeam,
						b.spositiontaking,
						b.mpositiontaking,
						b.apositiontaking,
						0 AS LiveIndicator,
						b.custid,
						0 AS LiveHomeScore,
						0 AS LiveAwayScore,
						0 AS LeagueId,
						b.matchid AS SportType,
						b.ip,
						0 AS MatchId,
						(b.winlost - b.actual_stake) AS WinLost,
						b.playercomm AS Commission,
						(b.scomm - b.acomm) AS SComm,
						(b.acomm - b.comm) AS AComm,
						(b.comm - b.playercomm) AS Comm,
						b.awinlost,
						b.mwinlost,
						b.swinlost,
						b.winlostdate,
						b.betcheck,
						ISNULL(b.transdesc, '') AS TransDesc,
						0 AS OddsSpread,
						b.ExtraInfo,
						'' AS JackpotInfo,
						-1 AS BetdaqId,
						b.currency,
						b.betdaqid AS SiteId,
						b.DeviceType
					FROM dbo.bettrans AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
						CROSS APPLY (SELECT TOP 1 val FROM dbo.f_StringSplit(b.betcheck, '|$|') ORDER BY id DESC) AS t3rd
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
						AND b.statusID NOT IN (0, 1)
						AND t3rd.val = @GameId
				END
			END

			-- AllBet, SA Gaming, Sexy Gaming, ION, WM, PP Live Casino, FGG, YeeBet, WE, ON Casino, GPI Live Casino, Playtech Live Casino, Microgaming Live
			IF @ProductId IN (21, 39, 45, 46, 51, 52, 57, 65, 70, 76, 80, 96, 90, 101, 107)
			BEGIN
				IF (@GameId <> '' AND @ProductId <> 52)
					OR @BetId <> ''
				BEGIN
					INSERT INTO @Data
					SELECT
						b.gameID AS BetType,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.transid, b.transid)
							ELSE b.transid
						END AS TransId,
						0 AS BetId,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.refno, b.refno)
							ELSE b.refno
						END AS RefNo,
						b.GameId3rd AS MatchCode,
						CASE
							WHEN s.ProductID IN (70, 90) THEN b.TransDate3rd
							ELSE ''
						END AS EventDate,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.sdiscount, b.sdiscount)
							ELSE b.sdiscount
						END AS SDiscount,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.adiscount, b.adiscount)
							ELSE b.adiscount
						END AS ADiscount,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.discount, b.discount)
							ELSE b.discount
						END AS Discount,
						0 AS HomeId,
						0 AS AwayId,
						0 AS Hdp1,
						0 AS Hdp2,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.odds, b.odds)
							ELSE b.odds
						END AS Odds,
						0 AS OddsType,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.status, b.status)
							ELSE b.status
						END AS Status,
						'' AS ComStatus,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.stake, b.stake)
							ELSE b.stake
						END AS Stake,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.stake, b.actual_stake)
							ELSE b.actual_stake
						END AS Actual_Stake,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.transdate, b.transdate)
							ELSE b.transdate
						END AS TransDate,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.BetID3rd, '')
							ELSE ''
						END AS BetTeam,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.spositiontaking, b.spositiontaking)
							ELSE b.spositiontaking
						END AS SPositionTaking,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.mpositiontaking, b.mpositiontaking)
							ELSE b.mpositiontaking
						END AS MPositionTaking,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.apositiontaking, b.apositiontaking)
							ELSE b.apositiontaking
						END AS APositionTaking,
						0 AS LiveIndicator,
						b.custid,
						0 AS LiveHomeScore,
						0 AS LiveAwayScore,
						0 AS LeagueId,
						b.productID AS SportType,
						b.ip,
						0 AS MatchId,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.winlost - bg.stake, b.winlost - b.actual_stake)
							ELSE b.winlost - b.actual_stake
						END AS WinLost,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.playercomm, b.playercomm)
							ELSE b.playercomm
						END AS Commission,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.scomm - bg.acomm, b.scomm - b.acomm)
							ELSE b.scomm - b.acomm
						END AS SComm,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.acomm - bg.comm, b.acomm - b.comm)
							ELSE b.acomm - b.comm
						END AS AComm,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.comm - bg.playercomm, b.comm - b.playercomm)
							ELSE b.comm - b.playercomm
						END AS Comm,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.awinlost, b.awinlost)
							ELSE b.awinlost
						END AS AWinLost,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.mwinlost, b.mwinlost)
							ELSE b.mwinlost
						END AS MWinLost,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.swinlost, b.swinlost)
							ELSE b.swinlost
						END AS SWinLost,
						b.winlostdate,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.TransDesc, b.TranId3rd)
							ELSE b.TranId3rd
						END AS BetCheck,
						b.transdesc,
						0 AS OddsSpread,
						CASE
							WHEN s.ProductID IN (39) THEN bg.ExtraInfo
							ELSE b.ExtraInfo
						END AS ExtraInfo,
						'' AS JackpotInfo,
						-1 AS BetdaqId,
						b.currency,
						b.SiteId,
						b.DeviceType
					FROM dbo.bettransLC AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.BetType = b.gameID
						LEFT JOIN dbo.bettransg AS bg WITH (NOLOCK)
							ON bg.refno = b.transid AND bg.custid = b.custid AND s.ProductID = 39
						CROSS APPLY (SELECT TOP 1 val FROM dbo.f_StringSplit(b.TranId3rd, '|$|') ORDER BY id DESC) AS t3rd
						CROSS APPLY (SELECT TOP 1 val FROM dbo.f_StringSplit(ISNULL(bg.BetID3rd, ''), '|$|') ORDER BY id DESC) AS b3rd
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
						AND (@GameId = '' OR b.GameId3rd = @GameId)
						AND (@BetId = ''
							OR (s.ProductID IN (21, 39, 45, 46, 51, 52, 57, 65, 70, 76, 80, 96, 90, 101) AND t3rd.val = @BetId)
							OR (s.ProductID = 39 AND b3rd.val = @BetId)
							OR (s.productID = 107 AND b.Transdesc = @BetId)
							)
				END
			END

			-- Macau Games, Pragmatic Casino, Card Club, Spadegaming, Saba.club, PG Soft, Joker, MaxGame, Habanero, CG, VGaming, AdvantPlay, AdvantPlay Mini, MG RNGCasino
			-- SEAL Entertainment, MG RNGCasino, Jili, Live22, UU Slots, Saba xD, FastSpin, FA CHAI, Nextspin, Playtech, GPI, PLAY STAR, SABA Keno, ASKMESLOT, Funky Games, HOTDOG, ODIN GAMING, GPI Lottery
			IF @ProductId IN (22, 32, 34, 36, 42, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75, 78, 79, 84, 86, 87, 89, 85, 100, 48, 91, 102, 103, 104, 95, 105)
			BEGIN
				IF @BetId <> ''
				BEGIN
					INSERT INTO @Data
					SELECT
						b.gameID AS BetType,
						b.transid,
						0 AS BetId,
						b.refno,
						CASE
							WHEN s.productID IN (42) THEN ISNULL(b.SiteID, '')
							ELSE b.Additional
						END AS MatchCode,
						CASE
							WHEN s.productID IN (60) THEN b.Transdate3rd
							ELSE ''
						END AS EventDate,
						b.sdiscount,
						b.adiscount,
						b.discount,
						0 AS HomeId,
						0 AS AwayId,
						0 AS Hdp1,
						0 AS Hdp2,
						CASE
							WHEN s.ProductID IN (32, 36, 42, 66) AND b.statusID IN (111, 112, 113) THEN ISNULL(b.ContributionRate, 0)
							ELSE b.odds
						END AS Odds,
						0 AS OddsType,
						b.status,
						'' AS ComStatus,
						b.stake,
						b.actual_stake,
						b.transdate,
						b.GameId3rd AS BetTeam,
						b.spositiontaking,
						b.mpositiontaking,
						b.apositiontaking,
						0 AS LiveIndicator,
						b.custid,
						0 AS LiveHomeScore,
						0 AS LiveAwayScore,
						0 AS LeagueId,
						b.productID AS SportType,
						b.ip,
						0 AS MatchId,
						(b.winlost - b.actual_stake) AS WinLost,
						b.playercomm AS Commission,
						(b.scomm - b.acomm) AS SComm,
						(b.acomm - b.comm) AS AComm,
						(b.comm - b.playercomm) AS Comm,
						b.awinlost,
						b.mwinlost,
						b.swinlost,
						b.winlostdate,
						b.TranId3rd AS BetCheck,
						b.transdesc,
						CASE
							WHEN s.ProductID IN (32, 36, 42, 66) AND b.statusID IN (111, 112, 113) THEN ISNULL(b.BetStake, 0)
							ELSE 0
						END AS OddsSpread,
						b.ExtraInfo,
						CASE
							WHEN s.ProductID IN (32, 36, 42, 66) THEN ISNULL(b.JackpotInfo, '')
							ELSE ''
						END AS JackpotInfo,
						CASE
							WHEN s.ProductID IN (32, 36, 42, 66) THEN ISNULL(b.RefNo2, -1)
							ELSE -1
						END AS BetdaqId,
						b.currency,
						b.SiteId,
						b.DeviceType
					FROM dbo.bettransRnG AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.BetType = b.gameID
						CROSS APPLY (SELECT TOP 1 val FROM dbo.f_StringSplit(b.TranId3rd, '|$|') ORDER BY id DESC) AS t3rd
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
						AND t3rd.val = @BetId
				END
			END

			-- BBIN
			IF @ProductId IN (47)
			BEGIN
				IF @GameId <> '' OR @BetId <> ''
				BEGIN
					INSERT INTO @Data
					SELECT
						bg.bettype,
						bg.transid,
						0 AS BetId,
						bg.refno,
						'' AS MatchCode,
						'' AS EventDate,
						bg.sdiscount,
						bg.adiscount,
						bg.discount,
						0 AS HomeId,
						0 AS AwayId,
						0 AS Hdp1,
						0 AS Hdp2,
						0 AS Odds,
						0 AS OddsType,
						bg.status,
						'' AS ComStatus,
						bg.stake,
						bg.actual_stake,
						bg.transdate,
						ISNULL(bg.betteam, '') AS BetTeam,
						bg.spositiontaking,
						bg.mpositiontaking,
						bg.apositiontaking,
						0 AS LiveIndicator,
						bg.custid,
						0 AS LiveHomeScore,
						0 AS LiveAwayScore,
						0 AS LeagueId,
						bg.matchid AS SportType,
						b.ip,
						0 AS MatchId,
						bg.winlost - bg.actual_stake AS WinLost,
						bg.playercomm AS Commission,
						bg.scomm - bg.acomm AS SComm,
						bg.acomm - bg.comm AS AComm,
						bg.comm - bg.playercomm AS Comm,
						bg.awinlost,
						bg.mwinlost,
						bg.swinlost,
						bg.winlostdate,
						ISNULL(bg.BetID3rd, '') AS BetCheck,
						bg.transdesc,
						0 AS OddsSpread,
						'' AS ExtraInfo,
						'' AS JackpotInfo,
						-1 AS BetdaqId,
						b.currency,
						bg.SiteId,
						b.DeviceType
					FROM dbo.bettransg AS bg WITH (NOLOCK)
						INNER JOIN @SportBettype AS sbt ON bg.bettype = sbt.Bettype
						INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON b.transid = bg.refno AND b.custid = bg.custid
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
						AND (@GameId = '' OR bg.betteam = @GameId)
						AND (@BetId = '' OR bg.BetID3rd = @BetId)
				END
			END
		END

		-- bettrans14 range
		IF @Fromdate <= @MoveBetsDay
		BEGIN
			IF @ToDate >= @MoveBetsDay
				SET @TempToDate = @MoveBetsDay
			ELSE
				SET @TempToDate = @ToDate
	
			IF @BalanceUpDay < @FromDate 
				SELECT @BalanceUpDay = @FromDate

			-- Virtual Games, Sports Lottery
			IF @ProductId IN (38, 63)
			BEGIN
				IF @GameId <> ''
				BEGIN
					INSERT INTO @Data
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetId,
						b.refno,
						'' AS MatchCode,
						'' AS EventDate,
						b.sdiscount,
						b.adiscount,
						b.discount,
						0 AS HomeId,
						0 AS AwayId,
						0 AS Hdp1,
						0 AS Hdp2,
						b.odds,
						0 AS OddsType,
						b.status,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS ComStatus,
						b.stake,
						b.actual_stake,
						b.transdate,
						'' AS BetTeam,
						b.spositiontaking,
						b.mpositiontaking,
						b.apositiontaking,
						0 AS LiveIndicator,
						b.custid,
						0 AS LiveHomeScore,
						0 AS LiveAwayScore,
						0 AS LeagueId,
						b.matchid AS SportType,
						b.ip,
						0 AS MatchId,
						(b.winlost - b.actual_stake) AS WinLost,
						b.playercomm AS Commission,
						(b.scomm - b.acomm) AS SComm,
						(b.acomm - b.comm) AS AComm,
						(b.comm - b.playercomm) AS Comm,
						b.awinlost,
						b.mwinlost,
						b.swinlost,
						b.winlostdate,
						b.betcheck,
						ISNULL(b.transdesc, '') AS TransDesc,
						0 AS OddsSpread,
						b.ExtraInfo,
						'' AS JackpotInfo,
						-1 AS BetdaqId,
						b.currency,
						b.betdaqid AS SiteId,
						b.DeviceType
					FROM dbo.bettrans14 AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
						CROSS APPLY (SELECT TOP 1 val FROM dbo.f_StringSplit(b.betcheck, '|$|') ORDER BY id DESC) AS t3rd
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
						AND b.statusID NOT IN (0, 1)
						AND t3rd.val = @GameId
				END
			END

			-- AllBet, SA Gaming, Sexy Gaming, IBCBet Live Casino, ION, WM, PP Live Casino, FGG, YeeBet, WE, ON Casino, GPI Live Casino, Playtech Live Casino, Microgaming Live
			IF @ProductId IN (21, 39, 45, 46, 51, 52, 57, 65, 70, 76, 80, 96, 90, 101, 107)
			BEGIN
				IF (@GameId <> '' AND @ProductId <> 52)
					OR @BetId <> ''
				BEGIN
					INSERT INTO @Data
					SELECT
						b.gameID AS BetType,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.transid, b.transid)
							ELSE b.transid
						END AS TransId,
						0 AS BetId,
						CASE
							WHEN s.ProductID = 39 THEN b.transid
							ELSE b.refno
						END AS RefNo,
						b.GameId3rd AS MatchCode,
						CASE
							WHEN s.ProductID IN (70, 90) THEN b.TransDate3rd
							ELSE ''
						END AS EventDate,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.sdiscount, b.sdiscount)
							ELSE b.sdiscount
						END AS SDiscount,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.adiscount, b.adiscount)
							ELSE b.adiscount
						END AS ADiscount,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.discount, b.discount)
							ELSE b.discount
						END AS Discount,
						0 AS HomeId,
						0 AS AwayId,
						0 AS Hdp1,
						0 AS Hdp2,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.odds, b.odds)
							ELSE b.odds
						END AS Odds,
						0 AS OddsType,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.status, b.status)
							ELSE b.status
						END AS Status,
						'' AS ComStatus,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.stake, b.stake)
							ELSE b.stake
						END AS Stake,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.stake, b.actual_stake)
							ELSE b.actual_stake
						END AS Actual_Stake,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.transdate, b.transdate)
							ELSE b.transdate
						END AS TransDate,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.BetID3rd, '')
							ELSE ''
						END AS BetTeam,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.spositiontaking, b.spositiontaking)
							ELSE b.spositiontaking
						END AS SPositionTaking,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.mpositiontaking, b.mpositiontaking)
							ELSE b.mpositiontaking
						END AS MPositionTaking,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.apositiontaking, b.apositiontaking)
							ELSE b.apositiontaking
						END AS APositionTaking,
						0 AS LiveIndicator,
						b.custid,
						0 AS LiveHomeScore,
						0 AS LiveAwayScore,
						0 AS LeagueId,
						b.productID AS SportType,
						b.ip,
						0 AS MatchId,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.winlost - bg.stake, b.winlost - b.actual_stake)
							ELSE b.winlost - b.actual_stake
						END AS WinLost,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.playercomm, b.playercomm)
							ELSE b.playercomm
						END AS Commission,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.scomm - bg.acomm, b.scomm - b.acomm)
							ELSE b.scomm - b.acomm
						END AS SComm,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.acomm - bg.comm, b.acomm - b.comm)
							ELSE b.acomm - b.comm
						END AS AComm,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.comm - bg.playercomm, b.comm - b.playercomm)
							ELSE b.comm - b.playercomm
						END AS Comm,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.awinlost, b.awinlost)
							ELSE b.awinlost
						END AS AWinLost,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.mwinlost, b.mwinlost)
							ELSE b.mwinlost
						END AS MWinLost,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.swinlost, b.swinlost)
							ELSE b.swinlost
						END AS SWinLost,
						b.winlostdate,
						CASE
							WHEN s.ProductID = 39 THEN ISNULL(bg.TransDesc, b.TranId3rd)
							ELSE b.TranId3rd
						END AS BetCheck,
						b.transdesc,
						0 AS OddsSpread,
						CASE
							WHEN s.ProductID IN (39) THEN ISNULL(bg.ExtraInfo, b.ExtraInfo)
							ELSE b.ExtraInfo
						END AS ExtraInfo,
						'' AS JackpotInfo,
						-1 AS BetdaqId,
						b.currency,
						b.SiteId,
						b.DeviceType
					FROM dbo.bettransLC14 AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.BetType = b.gameID
						LEFT JOIN dbo.bettransg14 AS bg WITH (NOLOCK)
							ON bg.refno = b.transid AND bg.custid = b.custid AND s.ProductID = 39
						CROSS APPLY (SELECT TOP 1 val FROM dbo.f_StringSplit(b.TranId3rd, '|$|') ORDER BY id DESC) AS t3rd
						CROSS APPLY (SELECT TOP 1 val FROM dbo.f_StringSplit(ISNULL(bg.BetID3rd, ''), '|$|')ORDER BY id DESC) AS b3rd
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
						AND (@GameId = '' OR b.GameId3rd = @GameId)
						AND (@BetId = ''
							OR (s.ProductID IN (21, 39, 45, 46, 51, 52, 57, 65, 70, 76, 80, 96, 90, 101) AND t3rd.val = @BetId)
							OR (s.ProductID = 39 AND b3rd.val = @BetId)
							OR (s.productID = 107 AND b.Transdesc = @BetId)
							)
				END
			END

			-- Macau Games, Pragmatic Casino, Card Club, Spadegaming, Saba.club, PG Soft, Joker, MaxGame, Habanero, CG, VGaming, AdvantPlay, AdvantPlay Mini, MG RNG Casino
			-- SEAL Entertainment, MG RNGCasino, Jili, Live22, UU Slots, Saba xD, FastSpin, FA CHAI, Nextspin, Playtech, GPI, PLAY STAR, SABA Keno, ASKMESLOT, Funky Games, HOTDOG, ODIN GAMING, GPI Lottery
			IF @ProductId IN (22, 32, 34, 36, 42, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75, 78, 79, 84, 86, 87, 89, 85, 100, 48, 91, 102, 103, 104, 95, 105)
			BEGIN
				IF @BetId <> ''
				BEGIN
					INSERT INTO @Data
					SELECT
						b.gameID AS BetType,
						b.transid,
						0 AS BetId,
						b.refno,
						CASE
							WHEN s.productID IN (42) THEN ISNULL(b.SiteID, '')
							ELSE b.Additional
						END AS MatchCode,
						CASE
							WHEN s.productID IN (60) THEN b.Transdate3rd
							ELSE ''
						END AS EventDate,
						b.sdiscount,
						b.adiscount,
						b.discount,
						0 AS HomeId,
						0 AS AwayId,
						0 AS Hdp1,
						0 AS Hdp2,
						CASE
							WHEN s.ProductID IN (32, 36, 42, 66) AND b.statusID IN (111, 112, 113) THEN ISNULL(b.ContributionRate, 0)
							ELSE b.odds
						END AS Odds,
						0 AS OddsType,
						b.status,
						'' AS ComStatus,
						b.stake,
						b.actual_stake,
						b.transdate,
						b.GameId3rd AS BetTeam,
						b.spositiontaking,
						b.mpositiontaking,
						b.apositiontaking,
						0 AS LiveIndicator,
						b.custid,
						0 AS LiveHomeScore,
						0 AS LiveAwayScore,
						0 AS LeagueId,
						b.productID AS SportType,
						b.ip,
						0 AS MatchId,
						(b.winlost - b.actual_stake) AS WinLost,
						b.playercomm AS Commission,
						(b.scomm - b.acomm) AS SComm,
						(b.acomm - b.comm) AS AComm,
						(b.comm - b.playercomm) AS Comm,
						b.awinlost,
						b.mwinlost,
						b.swinlost,
						b.winlostdate,
						b.TranId3rd AS BetCheck,
						b.transdesc,
						CASE
							WHEN s.ProductID IN (32, 36, 42, 66) AND b.statusID IN (111, 112, 113) THEN ISNULL(b.BetStake, 0)
							ELSE 0
						END AS OddsSpread,
						b.ExtraInfo,
						CASE
							WHEN s.ProductID IN (32, 36, 42, 66) THEN ISNULL(b.JackpotInfo, '')
							ELSE ''
						END AS JackpotInfo,
						CASE
							WHEN s.ProductID IN (32, 36, 42, 66) THEN ISNULL(b.RefNo2, -1)
							ELSE -1
						END AS BetdaqId,
						b.currency,
						b.SiteId,
						b.DeviceType
					FROM dbo.bettransRnG14 AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.BetType = b.gameID
						CROSS APPLY (SELECT TOP 1 val FROM dbo.f_StringSplit(b.TranId3rd, '|$|') ORDER BY id DESC) AS t3rd
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
						AND t3rd.val = @BetId
				END
			END

			-- BBIN
			IF @ProductId IN (47)
			BEGIN
				IF @GameId <> '' OR @BetId <> ''
				BEGIN
					INSERT INTO @Data
					SELECT
						bg.bettype,
						bg.transid,
						0 AS BetId,
						bg.refno,
						'' AS MatchCode,
						'' AS EventDate,
						bg.sdiscount,
						bg.adiscount,
						bg.discount,
						0 AS HomeId,
						0 AS AwayId,
						0 AS Hdp1,
						0 AS Hdp2,
						0 AS Odds,
						0 AS OddsType,
						bg.status,
						'' AS ComStatus,
						bg.stake,
						bg.actual_stake,
						bg.transdate,
						ISNULL(bg.betteam, '') AS BetTeam,
						bg.spositiontaking,
						bg.mpositiontaking,
						bg.apositiontaking,
						0 AS LiveIndicator,
						bg.custid,
						0 AS LiveHomeScore,
						0 AS LiveAwayScore,
						0 AS LeagueId,
						bg.matchid AS SportType,
						b.ip,
						0 AS MatchId,
						bg.winlost - bg.actual_stake AS WinLost,
						bg.playercomm AS Commission,
						bg.scomm - bg.acomm AS SComm,
						bg.acomm - bg.comm AS AComm,
						bg.comm - bg.playercomm AS Comm,
						bg.awinlost,
						bg.mwinlost,
						bg.swinlost,
						bg.winlostdate,
						ISNULL(bg.BetID3rd, '') AS BetCheck,
						bg.transdesc,
						0 AS OddsSpread,
						'' AS ExtraInfo,
						'' AS JackpotInfo,
						-1 AS BetdaqId,
						b.currency,
						bg.SiteId,
						b.DeviceType
					FROM dbo.bettransg14 AS bg WITH (NOLOCK)
						INNER JOIN @SportBettype AS sbt ON bg.bettype = sbt.Bettype
						INNER JOIN dbo.bettrans14 AS b WITH (NOLOCK) ON b.transid = bg.refno AND b.custid = bg.custid
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
						AND (@GameId = '' OR bg.betteam = @GameId)
						AND (@BetId = '' OR bg.BetID3rd = @BetId)
				END
			END
		END
	END

	SELECT DISTINCT b.*,
		ci.username,
		ex.currency
	FROM @Data AS b
		LEFT JOIN dbo.custInfo AS ci WITH (NOLOCK) ON b.CustId = ci.custid
		LEFT JOIN dbo.Exchange AS ex WITH (NOLOCK) ON ci.currency = ex.exchangeid
	ORDER BY b.TransId ASC
END
GO
