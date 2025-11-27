/*<info serverAlias="DBSIG-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[SiteDB_Acc_BetList_SelByRefNo]
	@RefNo			BIGINT,
	@MoveBetsDay	SMALLDATETIME,
	@Permission		VARCHAR(20)		= '1,2,3',
	@DeniedList		VARCHAR(MAX) = ''
AS

/*
	Created by: 20220729@Kos
	Task: Get tickets by RefNo (display in column RefNo in bet list)
	DB: DBSIG.bodb02

	Parameter Explanantion
		- @Permission
			- 1: Credit sites
			- 2: Deposit sites
			- 3: CN88
	
	Revisions:
		- 20220729@Kos: Scale out DBTRANS [Redmine: #175253]
		- 20220825@Razor: Support SEAL Entertainment [Redmine: #176210]
		- 20220909@Razor: Support Microgaming RNG Casino [Redmine: #175851]
		- 20221010@Kos: Scale out DBTRANS [Redmine: #178943]
					- Remove param @Site
		- 20221109@Kos: Enhance performance [Redmine: #179269]
		- 20221117@Razor: Support Player Tips [Redmine: #180590]
		- 20230206@Razor: Support Jili [Redmine: #182864]
		- 20230417@Razor: Remove Betfrom column [Redmine: #126137]
		- 20230526@Razor: Support YeeBet [Redmine: #186547]
		- 20230704@Razor: Remove Related tickets ION [Redmine: #190827]
		- 20230727@Razor: Support LG Virtual Sports (NewVirtual Sports 3 [Redmine: #189205]
		- 20230830@Razor: Show LicTxId for MaxGame [Redmine: #193273]
		- 20230909@Razor: Remove GDG, Fishing World products [Redmine: #174511]
		- 20230909@Razor: Remove GD, Colossusbet products [Redmine: #179132]
		- 20231005@Kos: Support Parlay Boost [Redmine: #194992]
		- 20231020@Razor: Support show max payout [Redmine: #194491]
					- Return new JackpotInfo column
					- Return ExtraInfo for show Max Payout
		- 20231019@Razor: Return Device Type info [Redmine: #192667]
		- 20231108@Razor: Support WE Live Casino [Redmine: #195887]
		- 20231215@Razor: Support Live22 [Redmine: #197609]
		- 20240105@Razor: Extend data type [Redmine: #199259]
		- 20240118@Razor: HF of SEAL Entertainment [Redmine: #199994]
		- 20240207@Kos: Return GameId3rd to support Live22 Result [Redmine: #197609]
		- 20240222@Razor: Support Project 777 - return SpecialPlatfrom [Redmine: #194591]
		- 20240222@Razor: Support Vitual Sports 4 [Redmine: #198619]
		- 20240327@Kos: Support UU Slots [Redmine: #192600]
		- 20240411@Razor: Return TranId3rd for Running ticket of Virtual Games/SportsLottery [Redmine: #203734]
		- 20240417@Razor: Support Saba xD [Redmine: #203371]
		- 20240419@Razor: Support Saba Coins [Redmine: #204003]
		- 20240507@Razor: Check permission for Real Currency [Redmine: #202523]
		- 20240626@Razor: Support FastSpin [Redmine: #205742]
		- 20240912@Razor: Support ON Casino [Redmine: #210026]
		- 20241003@Razor: Remove Linked Server on DBCust [Redmine: #206893]
		- 20241003@Razor: Support VS2 Racing sports [Redmine: #211092]
		- 20241106@Razor: Support VS 5 - Virtually Sports [Redmine: #207589]
		- 20241202@Razor: Support GPI Live Casino [Redmine: #213486]
		- 20241219@Razor: Support VS6 - Betby Virtual Sports [Redmine: #212546]
		- 20250326@Benji: Support Upcoming Product (Microgaming Live Casino, Playtech Live Casino ) [Redmine: #221188]		
		- 20250410@Benji: Remove Unnecessary Returned Data (Microgaming Live Casino, Playtech Live Casino) [Redmine: #221188]
		- 20250414@Razor: Support Direct Member [Redmine: #211969]
		- 20250428@Dave: change datatype for ExchangeID [RedmineID: #225676]
		- 20250730@Benji: Support Playtech RNG Jackpot - Support Automate Integration for Jackpot Betlist [Redmine: #234576]
		- 20250819@Razor: Support VS 2 - VS Tournament [Redmine: #235084]
		- 20250820@Benji: Support Playtech Live Jackpot [Redmine: #230127]
		- 20251015@Bobby: Support BetBuilder Hybrid Parlay [Redmine: #242255]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix --
	DECLARE @SportBettype TABLE (ProductID TINYINT, BetType SMALLINT, EventType TINYINT, SubProduct VARCHAR(500), RefTable TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype(ProductID, BetType, EventType, SubProduct, RefTable)
	SELECT ProductID, BetType, EventType, SubProduct, RefTable
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE BetType NOT IN (903, 904, 913, 914)
		AND ProductID NOT IN (2, 4, 7, 9, 13, 17, 19, 24, 26, 30, 31, 33)

	DECLARE
		@TransId		BIGINT,
		@BetType		INT,
		@WinLostDate	SMALLDATETIME,
		@CustId			INT
	
	DECLARE @ProductJackpot TABLE(ProductId TINYINT)
	
	INSERT INTO @ProductJackpot(ProductId)
    SELECT DISTINCT ProductId
    FROM @SportBettype
    WHERE SubProduct LIKE 'Jackpot%'

	-- translog
	SELECT TOP(1)
		@TransId = b.translogid,
		@BetType = b.gameID,
		@WinLostDate = b.winlostdate,
		@CustId = b.custid
	FROM dbo.translog AS b WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp ON b.gameID = sp.bettype
	WHERE b.translogid = @RefNo
		AND b.statusID IN (0, 1)
		AND ( sp.productid IN (8, 28, 38, 40, 43, 49, 63)
			OR (sp.productid = 3 AND sp.EventType = 0))

	-- bettrans
	IF @WinLostDate IS NULL
	BEGIN
		SELECT TOP(1)
			@TransId = b.transid,
			@BetType = b.bettype,
			@WinLostDate = b.winlostdate,
			@CustId = b.custid
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON b.bettype = sp.bettype
		WHERE b.transid = @RefNo

		IF @WinLostDate IS NULL
		BEGIN
			SELECT TOP(1)
				@TransId = b.transid,
				@BetType = b.bettype,
				@WinLostDate = b.winlostdate,
				@CustId = b.custid
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sp ON b.bettype = sp.bettype
			WHERE b.refno = @RefNo
				AND (sp.productid IN (8, 28, 38, 40, 43, 49, 63)
					OR (sp.productid = 3 AND sp.EventType = 0) )
		END
	END

	DECLARE @Data TABLE (
		BetType				INT,
		TransId				BIGINT,
		BetId				BIGINT,
		RefNo				NVARCHAR(50),
		MatchCode			NVARCHAR(1000),
		Race				NVARCHAR(20),
		EventDate			DATETIME,
		VirtualRate			FLOAT,
		IsShowOTExRate		BIT,
		SDiscount			SMALLMONEY,
		ADiscount			SMALLMONEY,
		Discount			SMALLMONEY,
		HomeId				INT,
		AwayId				INT,
		SettleTime			DATETIME,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
		FinalOdds			MONEY,
		FinalOdds2			MONEY,
		OddsType			TINYINT,
		Status				NVARCHAR(50),
		SettlementStatus	TINYINT,
		ComStatus			NVARCHAR(50),
		Stake				MONEY,
		Actual_Stake		MONEY,
		TransDate			DATETIME,
		BetTeam				NVARCHAR(200),
		SPositionTaking		SMALLMONEY,
		MPositionTaking		SMALLMONEY,
		APositionTaking		SMALLMONEY,
		SPositionTaking2	SMALLMONEY,
		MPositionTaking2	SMALLMONEY,
		APositionTaking2	SMALLMONEY,
		LiveIndicator		BIT,
		Modds				MONEY,
		CustId				INT,
		LiveHomeScore		INT,
		LiveAwayScore		INT,
		FinalHomeScore		INT,
		FinalAwayScore		INT,
		LeagueId			INT,
		SportType			SMALLINT,
		Ip					VARCHAR(45),
		MatchId				INT,
		IsNeutral			BIT,
		WinLost				MONEY,
		Commission			MONEY,
		SComm				MONEY,
		AComm				MONEY,
		Comm				MONEY,
		AWinLost			MONEY,
		MWinLost			MONEY,
		SWinLost			MONEY,
		ShowTime			NVARCHAR(50),
		WinLostDate			SMALLDATETIME,
		BetCheck			NVARCHAR(2000),
		TransDesc			NVARCHAR(1000),
		OddsSpread			MONEY,
		OriginalBetType		INT,
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		JackpotInfo			VARCHAR(50),
		WalletType			TINYINT,
		RefCode				BIGINT,
		CurrencyId			SMALLINT,
		SiteId				VARCHAR(20),
		LeagueGroupId		SMALLINT,
		DeviceType			TINYINT
	)

	DECLARE @DeniedSite TABLE (
		SiteId			INT,
		Site			NVARCHAR(50))

	DECLARE @DeniedCurrency TABLE (
		ExchangeId			INT)

	IF @DeniedList <> ''
	BEGIN
		INSERT INTO @DeniedSite (siteid, site)
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
	FROM CustDB.dbo.Site AS s WITH (NOLOCK)
	WHERE NOT EXISTS (SELECT 1 FROM @DeniedSite WHERE SiteId = s.siteid)
		AND ((s.isLicensee = 0									-- Don't have Credit sites permission
				AND s.site <> 'cn88'
				AND ',' + @Permission + ',' NOT LIKE '%,1,%')
			OR (s.isLicensee = 1								-- Don't have Deposit sites permission
				AND s.site <> 'cn88'
				AND ',' + @Permission + ',' NOT LIKE '%,2,%')
			OR (s.site = 'cn88'									-- Don't have CN88 site permission
				AND ',' + @Permission + ',' NOT LIKE '%,3,%'))

	IF @WinLostDate IS NOT NULL
		AND @WinLostDate > @MoveBetsDay
		AND NOT EXISTS ( SELECT 1
						FROM CustDB.dbo.Customer AS c WITH (NOLOCK)
							INNER JOIN CustDB.dbo.Customer AS a WITH (NOLOCK) ON c.recommend = a.custid
						WHERE c.custid = @CustId
							AND a.site IN (SELECT Site FROM @DeniedSite))
		AND NOT EXISTS ( SELECT 1
						FROM CustDB.dbo.customer AS c WITH (NOLOCK)
						WHERE c.custid = @CustId
							AND c.currency IN (SELECT ExchangeId FROM @DeniedCurrency))
	BEGIN
		-- Sportbooks, Number Game, Virtual Sports, BetRadar Virtual Sports, Cash Out, Virtual Sports 3, Virtual Sports 4 (EventType = 1)
		IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE EventType = 1 AND BetType = @BetType)
		BEGIN
			INSERT INTO @Data
			(
				BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime
				, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam, SPositionTaking
				, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore
				, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost
				, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode, CurrencyId, SiteId
				, LeagueGroupId, DeviceType
			)
			SELECT
				b.bettype,
				b.transid,
				ISNULL(b.betid, 0) AS BetId,
				b.refno,
				m.matchcode,
				'' AS Race,
				CASE
					WHEN s.ProductID IN (1, 25) THEN m.GlobalShowTime
					ELSE m.eventdate
				END AS EventDate,
				0 AS VirtualRate,
				0 AS IsShowOTExRate,
				b.sdiscount,
				CASE
					WHEN b.mrecommend = -4 THEN 0
					ELSE b.adiscount
				END,
				CASE
					WHEN b.recommend IN (-3, -4) THEN 0
					ELSE b.discount
				END,
				m.homeid,
				m.awayid,
				ISNULL(b.checktime,'') AS SettleTime,
				b.hdp1,
				b.hdp2,
				b.odds,
				0 AS finalodds,
				0 AS finalodds2,
				b.OddsType,
				CASE
					WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.status
				END AS status,
				ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.betteam,
				b.spositiontaking,
				b.mpositiontaking,
				b.apositiontaking,
				0 AS SPositionTaking2,
				0 AS MPositionTaking2,
				0 AS APositionTaking2,
				b.liveindicator,
				b.modds,
				b.custid,
				b.livehomescore,
				b.liveawayscore,
				m.finalhomescore,
				m.finalawayscore,
				m.leagueid,
				m.sporttype,
				b.ip,
				b.matchid,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				(b.winlost - b.actual_stake) AS winlost,
				b.playercomm AS Commission,
				(b.scomm - b.acomm) AS scomm,
				(b.acomm - b.comm) AS acomm,
				(b.comm - b.playercomm) AS comm,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				CASE
					WHEN s.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
					ELSE m.showtime
				END AS ShowTime,
				b.winlostdate,
				b.betcheck,
				ISNULL(b.transdesc, '') AS TransDesc,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				0 AS OriginalBetType,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b.betdaqid, -1)
					ELSE -1
				END AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				'' AS JackpotInfo,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b.WalletType, 0)
					ELSE 0
				END AS WalletType,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b.RefCode, 0)
					ELSE 0
				END AS RefCode,
				b.currency,
				'' AS SiteId,
				l.LeagueGroupID,
				b.DeviceType
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				LEFT JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
			WHERE b.transid = @TransId AND s.EventType = 1

			UNION ALL -- translog metric gaming
			SELECT
				btl.gameid AS BetType,
				btl.translogid AS TransId,
				0 AS BetId,
				btl.translogid AS RefNo,
				m.matchcode,
				'' AS Race,
				m.GlobalShowTime AS EventDate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				btl.sdiscount,
				CASE
					WHEN btl.mrecommend = -4 THEN 0
					ELSE btl.adiscount
				END,
				CASE
					WHEN btl.recommend IN (-3, -4) THEN 0
					ELSE btl.discount
				END,
				m.homeid,
				m.awayid,
				'' AS settleTime,
				0 AS hdp1,
				0 AS hdp2,
				btl.odds,
				0 AS finalodds,
				0 AS finalodds2,
				CASE
					WHEN btl.gameid IN (801,803,804,805,806) THEN CONVERT(TINYINT, ISNULL(btl.custom1, 0))
					ELSE 0
				END AS OddsType,
				btl.status,
				ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
				'' AS comstatus,
				btl.stake,
				btl.actual_stake,
				btl.transdate,
				'' AS betteam,
				btl.spositiontaking,
				btl.mpositiontaking,
				btl.apositiontaking,
				0 AS SPositionTaking2,
				0 AS MPositionTaking2,
				0 AS APositionTaking2,
				0 AS liveindicator,
				0 AS modds,
				btl.custid,
				0 AS livehomescore,
				0 AS liveawayscore,
				m.finalhomescore,
				m.finalawayscore,
				m.leagueid,
				m.sporttype,
				btl.ip,
				btl.eventID AS MatchId,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0 AS winlost,
				0 AS Commission,
				0 AS scomm,
				0 AS acomm,
				0 AS comm,
				0 AS awinlost,
				0 AS mwinlost,
				0 AS swinlost,
				m.showtime,
				btl.winlostdate,
				'' AS BetCheck,
				ISNULL(btl.transdesc, '') AS TransDesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				'' AS JackpotInfo,
				0 AS WalletType,
				0 AS RefCode,
				btl.currency,
				'' AS SiteId,
				0 AS LeagueGroupID,
				btl.DeviceType
			FROM dbo.translog AS btl WITH (NOLOCK) 
				INNER JOIN @SportBettype AS s ON s.Bettype = btl.gameID
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON btl.eventId = m.matchid
			WHERE btl.translogid = @TransId
				AND btl.statusID IN (0, 1)
				AND s.BetType BETWEEN 801 AND 899
		END

		-- Bitcoin, Virtual Sports 5, VS6 (EventType = 5)
		IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE EventType = 5 AND BetType = @BetType)
		BEGIN
			INSERT INTO @Data
			(
				BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime
				, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam, SPositionTaking
				, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore
				, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost
				, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode, CurrencyId, SiteId
				, LeagueGroupId, DeviceType
			)
			SELECT
				bbv.bettype,
				bbv.transid,
				ISNULL(bbv.betid, 0) AS BetId,
				bbv.refno,
				m.matchcode,
				'' AS Race,
				m.EndTime AS EventDate,
				0 AS VirtualRate,
				0 AS IsShowOTExRate,
				bbv.sdiscount,
				CASE
					WHEN bbv.mrecommend = -4 THEN 0
					ELSE bbv.adiscount
				END,
				CASE
					WHEN bbv.recommend IN (-3, -4) THEN 0
					ELSE bbv.discount
				END,
				m.homeid,
				m.awayid,
				ISNULL(bbv.checktime,'') AS SettleTime,
				bbv.hdp1,
				bbv.hdp2,
				bbv.odds,
				0 AS finalodds,
				0 AS finalodds2,
				bbv.OddsType,
				bbv.status AS status,
				0 AS SettlementStatus,
				0 AS comstatus,
				bbv.stake,
				bbv.actual_stake,
				bbv.transdate,
				bbv.betteam,
				bbv.spositiontaking,
				bbv.mpositiontaking,
				bbv.apositiontaking,
				0 AS SPositionTaking2,
				0 AS MPositionTaking2,
				0 AS APositionTaking2,
				bbv.liveindicator,
				bbv.modds,
				bbv.custid,
				bbv.livehomescore,
				bbv.liveawayscore,
				m.finalhomescore,
				m.finalawayscore,
				m.league3rdid,
				m.sporttype,
				bbv.ip,
				bbv.matchid,
				CONVERT(BIT,0) AS IsNeutral,
				(bbv.winlost - bbv.actual_stake) AS winlost,
				bbv.playercomm AS Commission,
				(bbv.scomm - bbv.acomm) AS scomm,
				(bbv.acomm - bbv.comm) AS acomm,
				(bbv.comm - bbv.playercomm) AS comm,
				bbv.awinlost,
				bbv.mwinlost,
				bbv.swinlost,
				CONVERT(NVARCHAR(50), m.StartTime) AS ShowTime,
				bbv.winlostdate,
				bbv.betcheck,
				ISNULL(bbv.transdesc, '') AS TransDesc,
				ISNULL(bbv.oddsspread, 0) AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				ISNULL(bbv.ExtraInfo, '') AS ExtraInfo,
				'' AS JackpotInfo,
				0 AS WalletType,
				0 AS RefCode,
				bbv.currency,
				'' AS SiteId,
				0 AS LeagueGroupID,
				bbv.DeviceType
			FROM dbo.bettrans AS bbv WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.BetType = bbv.bettype
				INNER JOIN dbo.match3rd AS m WITH (NOLOCK) ON bbv.matchid = m.match3rdid
			WHERE bbv.transid = @TransId AND s.EventType = 5
		END

		-- Mix Parlay, System Parlay, Mix Parlay (Betradar Virtual Sports), Mix Parlay (VS4), Mix Parlay (VS5)
		IF @BetType IN (9, 29, 2798, 2799, 10449, 11099)
		BEGIN
			INSERT INTO @Data
			(
				BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime
				, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam, SPositionTaking
				, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore
				, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost
				, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode, CurrencyId, SiteId
				, LeagueGroupId, DeviceType
			)
			SELECT
				bmx.bettype,
				bmx.transid,
				ISNULL(bmx.betid, 0) AS BetId,
				bmx.refno,
				'' AS MatchCode,
				'' AS Race,
				'' AS EventDate,
				0 AS VirtualRate,
				0 AS IsShowOTExRate,
				bmx.sdiscount,
				CASE
					WHEN bmx.mrecommend = -4 THEN 0
					ELSE bmx.adiscount
				END,
				CASE
					WHEN bmx.recommend IN (-3, -4) THEN 0
					ELSE bmx.discount
				END,
				0 AS HomeId,
				0 AS AwayId,
				'' AS SettleTime,
				bmx.hdp1,
				bmx.hdp2,
				bmx.odds,
				0 AS FinalOdds,
				0 AS FinalOdds2,
				0 AS OddsType,
				CASE
					WHEN bmx.status = 'running' THEN
						CASE
							WHEN EXISTS (SELECT 1 FROM dbo.bettransm AS bm WITH (NOLOCK)
										WHERE bm.custid = bmx.custid
											AND bm.refno = bmx.refno
											AND (bm.status = 'waiting'
												OR (bm.status = 'running' AND ISNULL(bm.SecAcceptFlag, 0) = 1 AND ISNULL(bm.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)))
								THEN 'Waiting'
							ELSE bmx.status
						END
					ELSE bmx.status
				END AS Status,
				0 AS SettlementStatus,
				CASE WHEN bmx.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				bmx.stake,
				bmx.actual_stake,
				bmx.transdate,
				bmx.betteam,
				bmx.spositiontaking,
				bmx.mpositiontaking,
				bmx.apositiontaking,
				0 AS SPositionTaking2,
				0 AS MPositionTaking2,
				0 AS APositionTaking2,
				0 AS LiveIndicator,
				bmx.modds,
				bmx.custid,
				bmx.livehomescore,
				bmx.liveawayscore,
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				0 AS LeagueId,
				0 AS SportType,
				bmx.ip,
				0 AS MatchId,
				CONVERT(BIT, 0) AS IsNeutral,
				(bmx.winlost - bmx.actual_stake) AS WinLost,
				bmx.playercomm AS Commission,
				(bmx.scomm - bmx.acomm) AS SComm,
				(bmx.acomm - bmx.comm) AS AComm,
				(bmx.comm - bmx.playercomm) AS Comm,
				bmx.awinlost,
				bmx.mwinlost,
				bmx.swinlost,
				'' AS ShowTime,
				bmx.winlostdate,
				bmx.betcheck,
				IIF(bmx.bettype = 29 AND OddsSpread = 3, ISNULL(bmx.transdesc, ''), '') AS TransDesc,
				ISNULL(bmx.oddsspread, 0) AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				bmx.ExtraInfo,
				'' AS JackpotInfo,
				0 AS WalletType,
				0 AS RefCode,
				bmx.currency,
				'' AS SiteId,
				0 AS LeagueGroupID,
				bmx.DeviceType
			FROM dbo.bettrans AS bmx WITH (NOLOCK)
			WHERE bmx.transid = @TransId AND bmx.bettype IN (9, 29, 2798, 2799, 10449, 11099)
		END

		-- Outright
		IF @BetType = 10
		BEGIN
			INSERT INTO @Data
			(
				BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime
				, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam, SPositionTaking
				, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore
				, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost
				, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode, CurrencyId, SiteId
				, LeagueGroupId, DeviceType
			)
			SELECT
				b10.bettype,
				b10.transid,
				ISNULL(b10.betid, 0) AS BetId,
				b10.refno,
				odds.matchcode,
				odds.groupmatch AS Race,
				odds.eventdate,
				0 AS VirtualRate,
				0 AS IsShowOTExRate,
				b10.sdiscount,
				CASE
					WHEN b10.mrecommend = -4 THEN 0
					ELSE b10.adiscount
				END,
				CASE
					WHEN b10.recommend IN (-3, -4) THEN 0
					ELSE b10.discount
				END,
				0 AS Homeid,
				odds.teamid AS awayid,
				'' AS SettleTime,
				b10.hdp1,
				b10.hdp2,
				b10.odds,
				0 AS FinalOdds,
				0 AS FinalOdds2,
				b10.oddstype AS OddsType,
				b10.status,
				0 AS SettlementStatus,
				CASE WHEN b10.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b10.stake,
				b10.actual_stake,
				b10.transdate,
				b10.betteam,
				b10.spositiontaking,
				b10.mpositiontaking,
				b10.apositiontaking,
				0 AS SPositionTaking2,
				0 AS MPositionTaking2,
				0 AS APositionTaking2,
				b10.liveindicator,
				b10.modds,
				b10.custid,
				b10.livehomescore,
				b10.liveawayscore,
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				odds.leagueid,
				l.sporttype,
				b10.ip ,
				b10.matchid,
				CONVERT(BIT,0) AS IsNeutral,
				(b10.winlost - b10.actual_stake) AS winlost,
				b10.playercomm AS Commission,
				(b10.scomm - b10.acomm) AS scomm,
				(b10.acomm - b10.comm) AS acomm,
				(b10.comm - b10.playercomm) AS comm,
				b10.awinlost,
				b10.mwinlost,
				b10.swinlost,
				'' AS showtime,
				b10.winlostdate,
				b10.BetCheck,
				'' AS TransDesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				'' AS JackpotInfo,
				0 AS WalletType,
				0 AS RefCode,
				b10.currency,
				'' AS SiteId,
				0 AS LeagueGroupID,
				b10.DeviceType
			FROM dbo.bettrans AS b10 WITH (NOLOCK)
				INNER JOIN dbo.outright AS odds WITH (NOLOCK) ON b10.matchid = odds.orid
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON odds.leagueid = l.leagueid
			WHERE b10.transid = @TransId AND b10.bettype = 10
		END

		-- Keno, NG2, Lottery, NPH Promotion, Virtual Games, Table Games, Indo 4D, BBIN, Leap Gaming Virtual Sports, Happy 5 Linked Games(Number Game), Sports Lottery
		-- Player Tips, Saba Coins
		IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype
					WHERE BetType = @BetType
						AND (ProductID IN (8, 23, 28, 37, 38, 40, 43, 47, 49, 63, 74, 81) OR (ProductID = 3 AND EventType = 0)))
		BEGIN
			INSERT INTO @Data
			(
				BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime
				, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam, SPositionTaking
				, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore
				, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost
				, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode, CurrencyId, SiteId
				, LeagueGroupId, DeviceType
			)
			SELECT
				bti.bettype,
				bti.transid,
				ISNULL(bti.betid, 0) AS BetId,
				bti.refno,
				'' AS matchcode,
				'' AS Race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				bti.sdiscount,
				CASE
					WHEN bti.mrecommend = -4 THEN 0
					ELSE bti.adiscount
				END,
				CASE
					WHEN bti.recommend IN (-3, -4) THEN 0
					ELSE bti.discount
				END,
				0 AS homeid,
				0 AS awayid,
				'' AS settleTime,
				CASE
					WHEN s.ProductId = 23 THEN bti.hdp1
					ELSE 0
				END AS hdp1,
				CASE
					WHEN s.ProductId = 23 THEN bti.hdp2
					ELSE 0
				END AS hdp2,
				CASE
					WHEN s.ProductID IN (3, 8, 23, 28, 38, 40, 43, 49, 63) THEN bti.odds
					ELSE 0
				END AS odds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				CASE
					WHEN s.ProductID = 40 AND bti.status = 'Won' AND bti.modds = 0.25 THEN 'Half Won'
					WHEN s.ProductID = 40 AND bti.status = 'Lose' AND bti.modds = -0.25 THEN 'Half Lose'
					ELSE bti.status
				END AS status,
				0 AS SettlementStatus,
				'' AS comstatus,
				bti.stake,
				bti.actual_stake,
				bti.transdate,
				'' AS betteam,
				bti.spositiontaking,
				bti.mpositiontaking,
				bti.apositiontaking,
				0 AS SPositionTaking2,
				0 AS MPositionTaking2,
				0 AS APositionTaking2,
				0 AS liveindicator,
				0 AS modds,
				bti.custid,
				CASE
					WHEN s.ProductId = 23 THEN bti.livehomescore
					ELSE 0
				END AS livehomescore,
				0 AS LiveAwayScore,
				0,
				0,
				0 AS leagueid,
				CASE
					WHEN s.ProductID = 8 THEN 202
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2501 AND 2539 THEN 213
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2541 AND 2579 THEN 214
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2581 AND 2619 THEN 215
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2621 AND 2659 THEN 216
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2681 AND 2699 THEN 218
					WHEN s.ProductID = 28 THEN 220
					WHEN s.ProductID IN (3, 37, 38, 40, 43, 47, 49, 63, 74, 81) THEN bti.matchid
					ELSE 0
				END AS SportType,
				bti.ip,
				CASE
					WHEN s.ProductID = 23 THEN bti.betdaqid
					WHEN s.ProductID = 74 THEN ISNULL(CAST(('<xml>' + bti.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@m)[1]','INT'), 0)
					ELSE 0
				END AS MatchId,
				CONVERT(BIT, 0) AS IsNeutral,
				(bti.winlost - bti.actual_stake) AS winlost,
				bti.playercomm AS Commission,
				(bti.scomm - bti.acomm) AS scomm,
				(bti.acomm - bti.comm) AS acomm,
				(bti.comm - bti.playercomm) AS comm,
				bti.awinlost,
				bti.mwinlost,
				bti.swinlost,
				'' AS showtime,
				bti.winlostdate,
				CASE
					WHEN s.ProductID IN (3, 38, 63) THEN bti.betcheck
					WHEN s.ProductId = 8 THEN ISNULL(bti.comstatus, '')
					ELSE ''
				END AS BetCheck,
				CASE
					WHEN s.ProductID IN (3, 8, 23, 28, 38, 40, 43, 49, 63) THEN bti.transdesc
					ELSE ''
				END AS TransDesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				ISNULL(bti.ExtraInfo, '') AS ExtraInfo,
				'' AS JackpotInfo,
				0 AS WalletType,
				0 AS RefCode,
				bti.currency,
				CASE 
					WHEN s.ProductId = 3 AND s.EventType = 0 THEN CONVERT(VARCHAR(20), bti.betdaqid)
					WHEN s.ProductId IN (38, 63) THEN CONVERT(VARCHAR(20), bti.betdaqid)
					ELSE '' 
				END AS SiteId,
				0 AS LeagueGroupID,
				bti.DeviceType
			FROM dbo.bettrans AS bti WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = bti.bettype
			WHERE bti.transid = @TransId
				AND (s.ProductId IN (8, 23, 28, 37, 38, 40, 43, 47, 49, 63, 74, 81)
						OR (s.ProductId = 3 AND s.EventType = 0))

			-- Get match info for Player Tips
			IF EXISTS (SELECT 1 FROM @Data WHERE SportType = 157)
			BEGIN
				UPDATE b
				SET
					LeagueId = m.leagueid,
					HomeId = m.homeid,
					AwayId = m.awayid,
					EventDate = m.GlobalShowTime
				FROM @Data AS b
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId
				WHERE b.SportType = 157
			END
		END

		-- Virtual Horse Racing, VS2 Racing
		IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (5, 27, 106) AND EventType = 3 AND BetType = @BetType)
		BEGIN
			INSERT INTO @Data
			(
				BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime
				, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam, SPositionTaking
				, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore
				, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost
				, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode, CurrencyId, SiteId
				, LeagueGroupId, DeviceType
			)
			SELECT
				bvh.bettype,
				bvh.transid,
				0 AS BetId,
				bvh.refno,
				'' AS MatchCode,
				bvh.oddsid AS Race,
				'' eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				bvh.sdiscount,
				CASE
					WHEN bvh.mrecommend = -4 THEN 0
					ELSE bvh.adiscount
				END,
				CASE
					WHEN bvh.recommend IN (-3, -4) THEN 0
					ELSE bvh.discount
				END,
				0 AS HomeId,
				0 AS awayID,
				'' AS SettleTime,
				bvh.hdp1,
				bvh.hdp2,
				bvh.odds,
				0 AS finalodds,
				0 AS finalodds2,
				bvh.OddsType,
				bvh.status,
				0 AS SettlementStatus,
				CASE WHEN bvh.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				bvh.stake,
				bvh.actual_stake,
				bvh.transdate,
				bvh.betteam AS betteam,
				CASE WHEN bvh.bettype = 1233 THEN bm.spositiontaking ELSE bvh.spositiontaking END,
				CASE WHEN bvh.bettype = 1233 THEN bm.mpositiontaking ELSE bvh.mpositiontaking END,
				CASE WHEN bvh.bettype = 1233 THEN bm.apositiontaking ELSE bvh.apositiontaking END,
				CASE WHEN bvh.bettype = 1233 THEN bm.spositiontaking2 ELSE 0 END,
				CASE WHEN bvh.bettype = 1233 THEN bm.mpositiontaking2 ELSE 0 END,
				CASE WHEN bvh.bettype = 1233 THEN bm.apositiontaking2 ELSE 0 END,
				0 liveindicator,
				bvh.modds,
				bvh.custid,
				bvh.livehomescore,
				bvh.liveawayscore,
				0 finalhomescore,
				0 finalawayscore,
				r.leagueid,
				r.sporttype,
				bvh.ip,
				bvh.matchid,
				CONVERT (BIT, 0) AS IsNeutral,
				(bvh.winlost - bvh.actual_stake) AS winlost,
				bvh.playercomm AS Commission,
				(bvh.scomm - bvh.acomm) AS scomm,
				(bvh.acomm - bvh.comm) AS acomm,
				(bvh.comm - bvh.playercomm) AS comm,
				bvh.awinlost,
				bvh.mwinlost,
				bvh.swinlost,
				'' AS showtime,
				bvh.winlostdate,
				bvh.BetCheck,
				bvh.transdesc AS TransDesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				bvh.ExtraInfo,
				'' AS JackpotInfo,
				0 AS WalletType,
				0 AS RefCode,
				bvh.currency,
				'' AS SiteId,
				0 AS LeagueGroupID,
				bvh.DeviceType
			FROM dbo.bettrans AS bvh WITH (NOLOCK) 
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = bvh.matchid
				INNER JOIN @SportBettype AS s ON s.BetType = bvh.BetType 
				LEFT JOIN (
					SELECT
						t.refno,
						t.apositiontaking,
						t.mpositiontaking,
						t.spositiontaking,
						f.apositiontaking AS APositionTaking2,
						f.mpositiontaking AS MPositionTaking2,
						f.spositiontaking AS spositiontaking2
					FROM dbo.bettransm AS t WITH (NOLOCK)
						INNER JOIN dbo.bettransm AS f WITH (NOLOCK) ON t.refno = f.refno
					WHERE t.bettype = 1231 AND f.bettype = 1232 
					) bm ON bvh.refno = bm.refno
			WHERE bvh.transid = @TransId
				AND s.EventType = 3
		END

		-- Keno, Lottery, Virtual Games, Table Games, Indo 4D, Leap Gaming Virtual Sports, Happy 5 Linked Games(Number Game), Sports Lottery (translog)
		IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype
					WHERE (ProductID IN (8, 28, 38, 40, 43, 49, 63) OR (ProductID = 3 AND EventType = 0))
						AND Bettype = @BetType)
		BEGIN
			INSERT INTO @Data
			(
				BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime
				, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam, SPositionTaking
				, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore
				, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost
				, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode, CurrencyId, SiteId
				, LeagueGroupId, DeviceType
			)
			SELECT
				bkl.gameid AS BetType,
				bkl.translogid AS TransId,
				0 AS BetId,
				bkl.translogid AS RefNo,
				'' AS matchcode,
				'' AS Race,
				'' AS eventdate,
				0,
				0,
				bkl.sdiscount,
				CASE
					WHEN bkl.mrecommend = -4 THEN 0
					ELSE bkl.adiscount
				END,
				CASE
					WHEN bkl.recommend IN (-3, -4) THEN 0
					ELSE bkl.discount
				END,
				0 AS homeid,
				0 AS awayid,
				'' AS settleTime,
				0 AS hdp1,
				0 AS hdp2,
				CASE
					WHEN s.ProductID IN (3, 8, 28, 38, 40, 43, 49, 63) THEN bkl.odds
					ELSE 0
				END AS odds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				bkl.status,
				0 AS SettlementStatus,
				0 AS comstatus,
				bkl.stake,
				bkl.actual_stake,
				bkl.transdate,
				'' AS betteam,
				bkl.spositiontaking,
				bkl.mpositiontaking,
				bkl.apositiontaking,
				0 AS SPositionTaking2,
				0 AS MPositionTaking2,
				0 AS APositionTaking2,
				0 AS liveindicator,
				0 AS modds,
				bkl.custid,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS leagueid,
				CASE
					WHEN s.ProductID = 8 THEN 202
					WHEN s.ProductID = 28 THEN 220
					WHEN s.ProductID IN (3, 38, 40, 43, 49, 63) THEN bkl.productID
					ELSE 0
				END AS SportType,
				bkl.ip,
				0 AS MatchId,
				CONVERT(BIT, 0) AS IsNeutral,
				(-bkl.actual_stake) AS winlost,
				0 AS Commission,
				0,
				0,
				0,
				0,
				0,
				0,
				'' AS showtime,
				bkl.winlostdate,
				CASE
					WHEN s.ProductID IN (3) THEN bkl.GameID3rd
					WHEN s.ProductID IN (38, 63) THEN bkl.TranId3rd
					WHEN s.ProductId = 8 THEN ISNULL(bkl.custom2, '')
					WHEN s.ProductId = 49 THEN ISNULL(bkl.custom1, '')
					ELSE ''
				END AS BetCheck,
				CASE
					WHEN s.ProductID IN (3, 8, 28, 38, 40, 43, 49, 63) THEN ISNULL(bkl.transdesc, '')
					ELSE ''
				END AS TransDesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				'' AS JackpotInfo,
				0 AS WalletType,
				0 AS RefCode,
				bkl.currency,
				bkl.SiteId,
				0 AS LeagueGroupID,
				bkl.DeviceType
			FROM dbo.translog AS bkl WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = bkl.gameID
			WHERE bkl.translogid = @TransId
				AND bkl.statusID IN (0, 1)
				AND (s.ProductID IN (8, 28, 38, 40, 43, 49, 63)
						OR (s.ProductID = 3 AND s.EventType = 0))
		END

		-- RNG Casino Single Wallet, Macau Games, Pragmatic Casino, Card Club, Spadegaming, Saba.club, RNG War, PG Soft, Joker, MaxGame, CG, VGaming
		-- Habanero, AdvantPlay, AdvantPlay Mini, SEAL, MG RNGCasino, Jili, Live22, UU Slots, Saba xD
		IF EXISTS (	SELECT TOP(1) 1 FROM @SportBettype
					WHERE Bettype = @BetType
						AND (ProductID IN (22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75, 78, 79, 86)
								OR (ProductID = 6 AND SubProduct <> '')
								OR RefTable = 1))
		BEGIN
			IF @WinLostDate >= DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)		-- yesterday and later
			BEGIN
				-- Yesterday and later running ticket
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime
					, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam, SPositionTaking
					, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore
					, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost
					, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode, CurrencyId, SiteId
					, LeagueGroupId, DeviceType
				)
				SELECT
					byl.bettype,
					byl.transid,
					ISNULL(byl.BetID, 0) AS BetId,
					byl.refno,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					AVG(brng.sdiscount) AS sdiscount,
					CASE
						WHEN brng.mrecommend = -4 THEN 0
						ELSE AVG(brng.adiscount) 
					END AS adiscount,
					CASE
						WHEN brng.recommend IN (-3, -4) THEN 0
						ELSE AVG(brng.discount) 
					END AS discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					0 AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					'Running' AS Status,
					0 AS SettlementStatus,
					CASE WHEN byl.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					SUM(brng.stake) AS stake,
					SUM(brng.actual_stake) AS actual_stake,
					byl.transdate,
					'' AS betteam,
					AVG(brng.spositiontaking) AS spositiontaking,
					AVG(brng.mpositiontaking) AS mpositiontaking,
					AVG(brng.apositiontaking) AS apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					byl.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0,
					0,
					0 AS leagueid,
					CASE
						WHEN s.ProductID = 22 THEN 212
						WHEN s.ProductID = 32 THEN 248
						ELSE byl.matchid
					END AS Sporttype,
					byl.ip,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS winlost,
					0 AS Commission,
					0 AS scomm,
					0 AS acomm,
					0 AS comm,
					0 AS awinlost,
					0 AS mwinlost,
					0 AS swinlost,
					'' AS showtime,
					byl.winlostdate,
					'' AS BetCheck,
					CASE
						WHEN s.ProductID IN (6, 22, 32, 34, 36, 55, 56, 61, 62, 67, 68, 72) THEN byl.transdesc
						ELSE ''
					END AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					0 AS CurrencyId,
					'' AS SiteId,
					0 AS LeagueGroupID,
					byl.DeviceType
				FROM dbo.bettransRnG AS brng WITH (NOLOCK)
					INNER JOIN dbo.bettrans AS byl WITH (NOLOCK) ON brng.RefNo = byl.transid
					INNER JOIN @SportBettype AS s ON s.Bettype = byl.bettype
				WHERE byl.transid = @TransId
					AND (s.ProductId IN (22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75, 78, 79, 86)
						OR (s.ProductId = 6 AND s.SubProduct <> '')
						OR s.RefTable = 1)
					AND brng.statusid IN (0, 1)
				GROUP BY
					byl.transid,
					ISNULL(byl.betid, 0),
					byl.bettype,
					byl.refno,
					byl.transdate,
					byl.winlostdate,
					byl.custid,
					byl.ip,
					byl.matchid,
					byl.comstatus,
					byl.transdesc,
					s.ProductID,
					byl.DeviceType,
					brng.recommend,
					brng.mrecommend

				-- Yesterday and later settled ticket
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime
					, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam, SPositionTaking
					, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore
					, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost
					, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode, CurrencyId, SiteId
					, LeagueGroupId, DeviceType
				)
				SELECT
					byl.bettype,
					byl.transid,
					ISNULL(byl.betid, 0) AS BetId,
					byl.refno,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					AVG(brng.sdiscount) AS sdiscount,
					CASE
						WHEN brng.mrecommend = -4 THEN 0
						ELSE AVG(brng.adiscount) 
					END AS adiscount,
					CASE
						WHEN brng.recommend IN (-3, -4) THEN 0
						ELSE AVG(brng.discount) 
					END AS discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN pj.ProductId IS NOT NULL 
							THEN ISNULL(AVG(CASE WHEN brng.statusID IN (111, 112, 113) THEN brng.ContributionRate END), 0)
						ELSE 0
					END AS Odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					CASE 
						WHEN SUM(brng.winlost - brng.actual_stake) > 0 THEN 'Won'
						WHEN SUM(brng.winlost - brng.actual_stake) < 0 THEN 'Lose'
						ELSE 'Draw'
					END AS Status,
					0 AS SettlementStatus,
					CASE WHEN byl.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					SUM(brng.stake) AS stake,
					SUM(brng.actual_stake) AS actual_stake,
					byl.transdate,
					'' AS betteam,
					AVG(brng.spositiontaking) AS spositiontaking,
					AVG(brng.mpositiontaking) AS mpositiontaking,
					AVG(brng.apositiontaking) AS apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					byl.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0,
					0,
					0 AS leagueid,
					CASE
						WHEN s.ProductID = 22 THEN 212
						WHEN s.ProductID = 32 THEN 248
						ELSE byl.matchid
					END AS Sporttype,
					byl.ip,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					SUM(brng.winlost - brng.actual_stake) AS winlost,
					SUM(brng.playercomm) AS Commission,
					SUM(brng.scomm - brng.acomm) AS scomm,
					SUM(brng.acomm - brng.comm) AS acomm,
					SUM(brng.comm - brng.playercomm) AS comm,
					SUM(brng.awinlost) AS awinlost,
					SUM(brng.mwinlost) AS mwinlost,
					SUM(brng.swinlost) AS swinlost,
					'' AS showtime,
					byl.winlostdate,
					'' AS BetCheck,
					CASE
						WHEN s.ProductID IN (6, 22, 32, 34, 36, 55, 56, 61, 62, 67, 68, 72) THEN byl.transdesc
						ELSE ''
					END AS TransDesc,
					CASE
						WHEN pj.ProductId IS NOT NULL  THEN ISNULL(SUM(brng.BetStake), 0)
						ELSE 0
					END AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					0 AS CurrencyId,
					'' AS SiteId,
					0 AS LeagueGroupID,
					byl.DeviceType
				FROM dbo.bettransRnG AS brng WITH (NOLOCK)
					INNER JOIN dbo.bettrans AS byl WITH (NOLOCK) ON brng.RefNo = byl.transid
					INNER JOIN @SportBettype AS s ON s.Bettype = byl.bettype
					LEFT JOIN @ProductJackpot AS pj ON s.ProductId = pj.ProductId
				WHERE byl.transid = @TransId
					AND (s.ProductId IN (22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75, 78, 79, 86)
						OR (s.ProductId = 6 AND s.SubProduct <> '')
						OR s.RefTable = 1)
					AND brng.statusid NOT IN (0, 1)
				GROUP BY
					byl.transid,					
					ISNULL(byl.betid, 0),
					byl.bettype,
					byl.refno,
					byl.transdate,
					byl.winlostdate,
					byl.custid,
					byl.ip,
					byl.matchid,
					byl.comstatus,
					byl.transdesc,
					pj.ProductID,
					s.ProductID,
					byl.DeviceType,
					brng.mrecommend,
					brng.recommend
			END
			ELSE
			BEGIN
				-- Before yesterday settled ticket
				INSERT INTO @Data
				(
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime
					, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam, SPositionTaking
					, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore
					, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost
					, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode, CurrencyId, SiteId
					, LeagueGroupId, DeviceType
				)
				SELECT
					bby.bettype,
					bby.transid,
					ISNULL(bby.betid, 0) AS BetId,
					bby.refno,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					bby.sdiscount,
					CASE
						WHEN bby.mrecommend = -4 THEN 0
						ELSE bby.adiscount
					END,
					CASE
						WHEN bby.recommend IN (-3, -4) THEN 0
						ELSE bby.discount
					END,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN pj.ProductId IS NOT NULL THEN bby.odds
						ELSE 0
					END AS Odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					bby.status,
					0 AS SettlementStatus,
					CASE WHEN bby.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					bby.stake,
					bby.actual_stake,
					bby.transdate,
					'' AS betteam,
					bby.spositiontaking,
					bby.mpositiontaking,
					bby.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					bby.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0,
					0,
					0 AS leagueid,
					CASE
						WHEN s.ProductID = 22 THEN 212
						WHEN s.ProductID = 32 THEN 248
						ELSE bby.matchid
					END AS Sporttype,
					bby.ip,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(bby.winlost - bby.actual_stake) AS winlost,
					bby.playercomm AS Commission,
					(bby.scomm - bby.acomm) AS scomm,
					(bby.acomm - bby.comm) AS acomm,
					(bby.comm - bby.playercomm) AS comm,
					bby.awinlost,
					bby.mwinlost,
					bby.swinlost,
					'' AS showtime,
					bby.winlostdate,
					'' AS BetCheck,
					CASE
						WHEN s.ProductID IN (6, 22, 32, 34, 36, 55, 56, 61, 62, 67, 68, 72) THEN bby.transdesc
						ELSE ''
					END AS TransDesc,
					CASE
						WHEN pj.ProductId IS NOT NULL THEN ISNULL(bby.oddsspread, 0)
						ELSE 0
					END AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					bby.currency,
					'' AS SiteId,
					0 AS LeagueGroupID,
					bby.DeviceType
				FROM dbo.bettrans AS bby WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = bby.bettype
					LEFT JOIN @ProductJackpot AS pj ON s.ProductId = pj.ProductId
				WHERE bby.transid = @TransId
					AND (s.ProductId IN (22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75, 78, 79, 86)
						OR (s.ProductId = 6 AND s.SubProduct <> '')
						OR s.RefTable = 1)
			END
		END

		-- AG Casino, AllBet, SA Gaming, Sexy Gaming, IBCBet Live Casino, ION, WM, Big Gaming, PP Live Casino, FGG, YeeBet, WE
		IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE (ProductID IN (11, 21, 39, 45, 46, 51, 52, 57, 65, 70, 76, 80) OR RefTable = 2) AND Bettype = @BetType)
		BEGIN
			IF @WinLostDate >= DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)		-- yesterday and later
			BEGIN
				-- Yesterday and later running ticket
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime
					, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam, SPositionTaking
					, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore
					, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost
					, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode, CurrencyId, SiteId
					, LeagueGroupId, DeviceType
				)
				SELECT
					bag.bettype,
					bag.transid,
					ISNULL(bag.BetID, 0) AS BetId,
					bag.refno,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					AVG(blc.sdiscount) AS sdiscount,
					CASE
						WHEN blc.mrecommend = -4 THEN 0
						ELSE AVG(blc.adiscount) 
					END AS adiscount,
					CASE
						WHEN blc.recommend IN (-3, -4) THEN 0
						ELSE AVG(blc.discount) 
					END AS discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					0 AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					'Running' AS Status,
					0 AS SettlementStatus,
					CASE WHEN bag.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					SUM(blc.stake) AS stake,
					SUM(blc.actual_stake) AS actual_stake,
					bag.transdate,
					'' AS betteam,
					AVG(blc.spositiontaking) AS spositiontaking,
					AVG(blc.mpositiontaking) AS mpositiontaking,
					AVG(blc.apositiontaking) AS apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					bag.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0,
					0,
					0 AS leagueid,
					CASE
						WHEN s.ProductID = 11 THEN 250
						WHEN s.ProductID = 21 THEN 211
						ELSE bag.matchid
					END AS Sporttype,
					bag.ip,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS winlost,
					0 AS Commission,
					0 AS scomm,
					0 AS acomm,
					0 AS comm,
					0 AS awinlost,
					0 AS mwinlost,
					0 AS swinlost,
					'' AS showtime,
					bag.winlostdate,
					'' AS BetCheck,
					'' AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					0 AS CurrencyId,
					'' AS SiteId,
					0 AS LeagueGroupID,
					bag.DeviceType
				FROM dbo.bettransLC AS blc WITH (NOLOCK)
					INNER JOIN dbo.bettrans AS bag WITH (NOLOCK) ON blc.RefNo = bag.transid
					INNER JOIN @SportBettype AS s ON s.Bettype = bag.bettype
				WHERE bag.transid = @TransId
					AND (s.ProductID IN (11, 21, 39, 45, 46, 51, 52, 57, 65, 70, 76, 80) OR s.RefTable = 2)
					AND blc.statusID = 0
				GROUP BY
					bag.transid,
					ISNULL(bag.betid, 0),
					bag.bettype,
					bag.refno,
					bag.transdate,
					bag.winlostdate,
					bag.custid,
					bag.ip,
					bag.comstatus,
					s.ProductID,
					bag.matchid,
					bag.DeviceType,
					blc.recommend,
					blc.mrecommend

				-- Yesterday and later settled ticket
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime
					, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam, SPositionTaking
					, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore
					, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost
					, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode, CurrencyId, SiteId
					, LeagueGroupId, DeviceType
				)
				SELECT
					bag.bettype,
					bag.transid,
					ISNULL(bag.betid, 0) AS BetId,
					bag.refno,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					AVG(blc.sdiscount) AS sdiscount,
					CASE
						WHEN blc.mrecommend = -4 THEN 0
						ELSE AVG(blc.adiscount) 
					END AS adiscount,
					CASE
						WHEN blc.recommend IN (-3, -4) THEN 0
						ELSE AVG(blc.discount) 
					END AS discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN pj.ProductId IS NOT NULL 
							THEN ISNULL(AVG(CASE WHEN blc.statusID IN (111, 112, 113) THEN blc.ContributionRate END), 0)
						ELSE 0
					END AS Odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					CASE 
						WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
						WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
						ELSE 'Draw'
					END AS Status,
					0 AS SettlementStatus,
					CASE WHEN bag.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					SUM(blc.stake) AS stake,
					SUM(blc.actual_stake) AS actual_stake,
					bag.transdate,
					'' AS betteam,
					AVG(blc.spositiontaking) AS spositiontaking,
					AVG(blc.mpositiontaking) AS mpositiontaking,
					AVG(blc.apositiontaking) AS apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					bag.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0,
					0,
					0 AS leagueid,
					CASE
						WHEN s.ProductID = 11 THEN 250
						WHEN s.ProductID = 21 THEN 211
						ELSE bag.matchid
					END AS Sporttype,
					bag.ip,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					SUM(blc.winlost - blc.actual_stake) AS winlost,
					SUM(blc.playercomm) AS Commission,
					SUM(blc.scomm - blc.acomm) AS scomm,
					SUM(blc.acomm - blc.comm) AS acomm,
					SUM(blc.comm - blc.playercomm) AS comm,
					SUM(blc.awinlost) AS awinlost,
					SUM(blc.mwinlost) AS mwinlost,
					SUM(blc.swinlost) AS swinlost,
					'' AS showtime,
					bag.winlostdate,
					'' AS BetCheck,
					'' AS TransDesc,
					CASE
						WHEN pj.ProductId IS NOT NULL  THEN ISNULL(SUM(blc.BetStake), 0)
						ELSE 0
					END AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					0 AS CurrencyId,
					'' AS SiteId,
					0 AS LeagueGroupID,
					bag.DeviceType
				FROM dbo.bettransLC AS blc WITH (NOLOCK)
					INNER JOIN dbo.bettrans AS bag WITH (NOLOCK) ON blc.RefNo = bag.transid
					INNER JOIN @SportBettype AS s ON s.Bettype = bag.bettype
					LEFT JOIN @ProductJackpot AS pj ON s.ProductId = pj.ProductId
				WHERE bag.transid = @TransId
					AND (s.ProductID IN (11, 21, 39, 45, 46, 51, 52, 57, 65, 70, 76, 80) OR s.RefTable = 2)
					AND blc.statusID <> 0
				GROUP BY
					bag.transid,
					pj.ProductID,
					ISNULL(bag.betid, 0),
					bag.bettype,
					bag.refno,
					bag.transdate,
					bag.winlostdate,
					bag.custid,
					bag.ip,
					bag.comstatus,
					s.ProductID,
					bag.matchid,
					bag.DeviceType,
					blc.recommend,
					blc.mrecommend,
					s.SubProduct
			END
			ELSE
			BEGIN
				-- Before yesterday settled ticket
				INSERT INTO @Data
				(
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime
					, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam, SPositionTaking
					, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore
					, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost
					, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode, CurrencyId, SiteId
					, LeagueGroupId, DeviceType
				)
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.BetID, 0) AS BetId,
					b.refno,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					CASE
						WHEN b.mrecommend = -4 THEN 0
						ELSE b.adiscount
					END,
					CASE
						WHEN b.recommend IN (-3, -4) THEN 0
						ELSE b.discount
					END,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN pj.ProductId IS NOT NULL THEN b.odds
						ELSE 0
					END AS Odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					0 AS SettlementStatus,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0,
					0,
					0 AS leagueid,
					CASE
						WHEN s.ProductID = 11 THEN 250
						WHEN s.ProductID = 21 THEN 211
						WHEN s.ProductID IN (39, 45, 46, 51, 52, 57, 65, 70, 76, 80) THEN b.matchid
						WHEN s.RefTable = 2 THEN b.matchid
					END AS Sporttype,
					b.ip,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(b.winlost - b.actual_stake) AS winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					'' AS BetCheck,
					'' AS TransDesc,
					CASE
						WHEN pj.ProductId IS NOT NULL THEN ISNULL(b.oddsspread, 0)
						ELSE 0
					END AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b.currency,
					'' AS SiteId,
					0 AS LeagueGroupID,
					b.DeviceType
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					LEFT JOIN @ProductJackpot AS pj ON s.ProductId = pj.ProductId
				WHERE b.transid = @TransId
					AND (s.ProductID IN (11, 21, 39, 45, 46, 51, 52, 57, 65, 70, 76, 80) OR s.RefTable = 2)
			END
		END
		-- Get related Bonus/Cash tickets
		IF EXISTS (SELECT 1 FROM @Data WHERE RefCode <> 0)
		BEGIN
			INSERT INTO @Data
			(
				BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime
				, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam, SPositionTaking
				, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore
				, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost
				, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode, CurrencyId, SiteId
				, LeagueGroupId, DeviceType
			)
			SELECT
				boc.bettype,
				boc.transid,
				ISNULL(boc.betid, 0) AS BetId,
				boc.refno,
				m.matchcode,
				'' AS Race,
				m.GlobalShowTime AS EventDate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				boc.sdiscount,
				CASE
					WHEN boc.mrecommend = -4 THEN 0
					ELSE boc.adiscount
				END,
				CASE
					WHEN boc.recommend IN (-3, -4) THEN 0
					ELSE boc.discount
				END,
				m.homeid,
				m.awayid,
				ISNULL(boc.checktime,'') settleTime,
				boc.hdp1,
				boc.hdp2,
				boc.odds,
				0 AS finalodds,
				0 AS finalodds2,
				boc.oddstype,
				CASE
					WHEN boc.status = 'running' AND ISNULL(boc.SecAcceptFlag, 0) = 1 AND ISNULL(boc.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE boc.status
				END AS status,
				ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
				CASE WHEN boc.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				boc.stake,
				boc.actual_stake,
				boc.transdate,
				boc.betteam,
				boc.spositiontaking,
				boc.mpositiontaking,
				boc.apositiontaking,
				0 AS SPositionTaking2,
				0 AS MPositionTaking2,
				0 AS APositionTaking2,
				boc.liveindicator,
				boc.modds,
				boc.custid,
				boc.livehomescore,
				boc.liveawayscore,
				m.finalhomescore,
				m.finalawayscore,
				m.leagueid,
				m.sporttype,
				boc.ip,
				boc.matchid,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				(boc.winlost - boc.actual_stake) AS winlost,
				boc.playercomm AS Commission,
				(boc.scomm - boc.acomm) AS scomm,
				(boc.acomm - boc.comm) AS acomm,
				(boc.comm - boc.playercomm) AS comm,
				boc.awinlost,
				boc.mwinlost,
				boc.swinlost,
				m.showtime,
				boc.winlostdate,
				boc.BetCheck,
				ISNULL(boc.transdesc, '') AS TransDesc,
				ISNULL(boc.oddsspread, 0) AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				ISNULL(boc.ExtraInfo, '') AS ExtraInfo,
				'' AS JackpotInfo,
				ISNULL(boc.WalletType, 0) AS WalletType,
				ISNULL(boc.RefCode, 0) AS RefCode,
				boc.currency,
				'' AS SiteId,
				0 AS LeagueGroupID,
				boc.DeviceType
			FROM
				dbo.bettrans AS boc WITH (NOLOCK)
				INNER JOIN @Data AS b1
					ON boc.custid = b1.CustId
					AND boc.winlostdate = b1.WinLostDate
					AND boc.RefCode = b1.RefCode
					AND boc.transid <> b1.TransId
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON boc.matchid = m.matchid
		END
	END

	-- Get original odds for Mix Parlay and final odds, boost rate for Mix Parlay Boost Bonus
	IF EXISTS (SELECT 1 FROM @Data WHERE BetType = 29 AND BetTeam = '1')
	BEGIN
		-- Running/Waiting
		DECLARE @ParlayData TABLE (
			RefNo		BIGINT,
			BoostRate	MONEY)

		INSERT INTO @ParlayData(RefNo, BoostRate)
		SELECT
			b.refno,
			CASE
				WHEN b.bettype = 29 AND b.betteam = 1 AND b.oddsspread = 2 THEN
					ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@bbp)[1]','MONEY'), 0)
				ELSE 0
			END AS BoostRate
		FROM @Data AS b
		WHERE b.BetType = 29
			AND b.BetTeam = '1'
			AND b.Status IN ('Running', 'Waiting')

		DECLARE @TmpParlayData TABLE (
			RefNo	BIGINT,
			Odds	MONEY,
			MOdds	MONEY)

		-- Mix Parlay which having at least 1 settled sub ticket
		INSERT INTO @TmpParlayData (RefNo, Odds, MOdds)
		SELECT
			b.RefNo,
			dbo.PRODUCT(bpd.odds) AS Odds,
			dbo.PRODUCT(bpd.odds) * (b.BoostRate + 1) - b.BoostRate AS MOdds
		FROM @ParlayData AS b
			INNER JOIN dbo.BetParlayDetail AS bpd WITH (NOLOCK) ON bpd.RefNo = b.RefNo
		GROUP BY
			b.RefNo,
			b.BoostRate
		-- Mix Parlay which having no settled sub ticket
		UNION ALL
		SELECT
			b.RefNo,
			dbo.PRODUCT(bm.odds) AS Odds,
			dbo.PRODUCT(bm.odds) * (b.BoostRate + 1) - b.BoostRate AS MOdds
		FROM @ParlayData AS b
			INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON bm.refno = b.RefNo
		WHERE NOT EXISTS (SELECT 1 FROM @TmpParlayData WHERE RefNo = b.RefNo)
		GROUP BY
			b.RefNo,
			b.BoostRate

		UPDATE b
		SET
			b.Odds = td.Odds,
			b.MOdds = td.MOdds
		FROM @Data AS b
			INNER JOIN @TmpParlayData AS td ON td.RefNo = b.RefNo

		-- Settled
		UPDATE b
		SET
			b.Odds = bpr.Odds,
			b.Modds = bpr.mOdds,
			b.TransDesc = IIF(b.OddsSpread = 3,b.TransDesc, CONVERT(VARCHAR(20), ISNULL(bpr.ExtraValue, '')))
		FROM @Data AS b
			INNER JOIN dbo.BetParlayResult AS bpr WITH (NOLOCK) ON bpr.RefNo = b.RefNo
		WHERE b.BetType = 29
			AND b.BetTeam = '1'
			AND b.Status NOT IN ('Running', 'Waiting')
	END
	
	-- Don't display Cash text for ticket from Cash Wallet only
	UPDATE @Data
	SET WalletType = 0
	WHERE WalletType = 2 AND RefCode = 0

	-- Display Cash/Bonus text for ticket from multiple wallets
	UPDATE @Data
	SET RefCode = 0
	WHERE RefCode <> 0

	-- BettransRnG tables
	SET @WinLostDate = NULL
	SET @CustId = NULL

	-- bettransRnG
	SELECT TOP(1)
		@TransId = b.transid,
		@BetType = b.gameID,
		@WinLostDate = b.winlostdate,
		@CustId = b.custid
	FROM dbo.bettransRnG AS b WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp ON b.gameID = sp.bettype
	WHERE b.transid = @RefNo

	IF @WinLostDate IS NOT NULL
		AND @WinLostDate > @MoveBetsDay
		AND NOT EXISTS ( SELECT 1
						FROM CustDB.dbo.Customer AS c WITH (NOLOCK)
							INNER JOIN CustDB.dbo.Customer AS a WITH (NOLOCK) ON c.recommend = a.custid
							WHERE c.custid = @CustId
								AND a.site IN (SELECT Site FROM @DeniedSite))
		AND NOT EXISTS ( SELECT 1
						FROM CustDB.dbo.customer AS c WITH (NOLOCK)
						WHERE c.custid = @CustId
							AND c.currency IN (SELECT ExchangeId FROM @DeniedCurrency))
	BEGIN
		-- RNG Casino Single Wallet, Macau Games, Pragmatic Casino, Card Club, Spadegaming, Saba.club, RNG War, PG Soft, Joker, MaxGame, Habanero, CG, VGaming
		-- AdvantPlay, AdvantPlay Mini, SEAL, MG RNGCasino, Jili, Live22, UU Slots, Saba xD
		IF EXISTS (	SELECT TOP(1) 1 FROM @SportBettype
					WHERE Bettype = @BetType
						AND (ProductID IN (22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75, 78, 79, 86)
								OR (ProductId = 6 AND SubProduct <> '')
								OR RefTable = 1))
		BEGIN
			INSERT INTO @Data
			(
				BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime
				, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam, SPositionTaking
				, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore
				, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost
				, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode, CurrencyId, SiteId
				, LeagueGroupId, DeviceType
			)
			SELECT
				brn.gameID AS BetType,
				brn.transid,
				0 AS BetId,
				brn.refno,
				CASE
					WHEN s.productID IN (42) THEN ISNULL(brn.SiteID, '')
					ELSE brn.Additional
				END AS MatchCode,
				'' AS Race,
				CASE
					WHEN s.productID IN (60) THEN brn.Transdate3rd
					ELSE ''
				END AS EventDate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				brn.sdiscount,
				CASE
					WHEN brn.mrecommend = -4 THEN 0
					ELSE brn.adiscount
				END,
				CASE
					WHEN brn.recommend IN (-3, -4) THEN 0
					ELSE brn.discount
				END,
				0 AS homeid,
				0 AS awayid,
				'' AS settleTime,
				0 AS hdp1,
				0 AS hdp2,
				CASE
					WHEN pj.ProductId IS NOT NULL AND brn.statusID IN (111, 112, 113) THEN ISNULL(brn.ContributionRate, 0)
					ELSE brn.odds
				END AS Odds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				brn.status,
				0 AS SettlementStatus,
				'' AS comstatus,
				brn.stake,
				brn.actual_stake,
				brn.transdate,
				brn.GameId3rd AS betteam,
				brn.spositiontaking,
				brn.mpositiontaking,
				brn.apositiontaking,
				0 AS SPositionTaking2,
				0 AS MPositionTaking2,
				0 AS APositionTaking2,
				0 AS liveindicator,
				0 AS modds,
				brn.custid,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS leagueid,
				brn.productID AS Sporttype,
				brn.ip,
				0 AS MatchId,
				CONVERT(BIT, 0) AS IsNeutral,
				(brn.winlost - brn.actual_stake) AS winlost,
				brn.playercomm AS Commission,
				(brn.scomm - brn.acomm) AS scomm,
				(brn.acomm - brn.comm) AS acomm,
				(brn.comm - brn.playercomm) AS comm,
				brn.awinlost,
				brn.mwinlost,
				brn.swinlost,
				'' AS showtime,
				brn.winlostdate,
				brn.TranId3rd AS BetCheck,
				brn.transdesc,
				CASE
					WHEN pj.ProductId IS NOT NULL AND brn.statusID IN (111, 112, 113) THEN ISNULL(brn.BetStake, 0)
					ELSE 0
				END AS OddsSpread,
				0 AS OriginalBetType,
				CASE
					WHEN pj.ProductId IS NOT NULL THEN ISNULL(brn.RefNo2, -1)
					ELSE -1
				END AS BetdaqId,
				brn.ExtraInfo,
				CASE
					WHEN pj.ProductId IS NOT NULL THEN ISNULL(brn.JackpotInfo, '')
					ELSE ''
				END AS JackpotInfo,
				0 AS WalletType,
				0 AS RefCode,
				brn.currency,
				brn.SiteId,
				0 AS LeagueGroupID,
				brn.DeviceType
			FROM dbo.bettransRnG AS brn WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = brn.gameID
				LEFT JOIN @ProductJackpot AS pj ON s.ProductId = pj.ProductId
			WHERE brn.transid = @TransId
				AND (s.ProductId IN (22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75, 78, 79, 86)
					OR (s.ProductId = 6 AND s.SubProduct <> '')
					OR RefTable = 1)
		END
	END

	-- BettransLC tables
	SET @WinLostDate = NULL
	SET @CustId = NULL

	-- bettransLC
	SELECT TOP(1)
		@TransId = b.transid,
		@BetType = b.gameID,
		@WinLostDate = b.winlostdate,
		@CustId = b.custid
	FROM dbo.bettransLC AS b WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp ON b.gameID = sp.bettype
	WHERE b.transid = @RefNo

	IF @WinLostDate IS NOT NULL
		AND @WinLostDate > @MoveBetsDay
		AND NOT EXISTS ( SELECT 1
						FROM CustDB.dbo.Customer AS c WITH (NOLOCK)
							INNER JOIN CustDB.dbo.Customer AS a WITH (NOLOCK) ON c.recommend = a.custid
							WHERE c.custid = @CustId
								AND a.site IN (SELECT Site FROM @DeniedSite))
		AND NOT EXISTS ( SELECT 1
						FROM CustDB.dbo.customer AS c WITH (NOLOCK)
						WHERE c.custid = @CustId
							AND c.currency IN (SELECT ExchangeId FROM @DeniedCurrency))
	BEGIN
		-- AG Casino, AllBet, Sexy Gaming, IBCBet Live Casino, ION, WM, Big Gaming, FGG, YeeBet, WE
		IF EXISTS ( SELECT TOP(1) 1 FROM @SportBettype WHERE (ProductID IN (11, 21, 45, 46, 51, 52, 57, 65, 70, 76, 80) OR RefTable = 2) AND Bettype = @BetType )
		BEGIN
			INSERT INTO @Data
			(
				BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime
				, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam, SPositionTaking
				, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore
				, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost
				, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode, CurrencyId, SiteId
				, LeagueGroupId, DeviceType
			)
			SELECT
				blc2.gameID AS BetType,
				blc2.transid,
				0 AS BetId,
				blc2.refno,
				CASE
					WHEN s.ProductID = 11 THEN ''
					ELSE blc2.GameId3rd
				END AS matchcode,
				'' AS Race,
				CASE
					WHEN s.ProductID IN (70, 90) THEN blc2.TransDate3rd
					ELSE '' 
				END AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				blc2.sdiscount,
				CASE
					WHEN blc2.mrecommend = -4 THEN 0
					ELSE blc2.adiscount
				END,
				CASE
					WHEN blc2.recommend IN (-3, -4) THEN 0
					ELSE blc2.discount
				END,
				0 AS homeid,
				0 AS awayid,
				'' AS settleTime,
				0 AS hdp1,
				0 AS hdp2,
				CASE
					WHEN s.ProductID IN (21, 45, 46, 51, 52, 57, 76, 80, 96) THEN blc2.odds
					WHEN pj.ProductId IS NOT NULL AND blc2.statusID IN (111, 112, 113) THEN ISNULL(blc2.ContributionRate, 0)
					ELSE 0
				END AS odds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				blc2.status,
				0 AS SettlementStatus,
				'' AS comstatus,
				blc2.stake,
				blc2.actual_stake,
				blc2.transdate,
				'' AS betteam,
				blc2.spositiontaking,
				blc2.mpositiontaking,
				blc2.apositiontaking,
				0 AS SPositionTaking2,
				0 AS MPositionTaking2,
				0 AS APositionTaking2,
				0 AS liveindicator,
				0 AS modds,
				blc2.custid,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS leagueid,
				blc2.productID AS Sporttype,
				blc2.ip,
				0 AS MatchId,
				CONVERT(BIT, 0) AS IsNeutral,
				(blc2.winlost - blc2.actual_stake) AS winlost,
				blc2.playercomm AS Commission,
				(blc2.scomm - blc2.acomm) AS scomm,
				(blc2.acomm - blc2.comm) AS acomm,
				(blc2.comm - blc2.playercomm) AS comm,
				blc2.awinlost,
				blc2.mwinlost,
				blc2.swinlost,
				'' AS showtime,
				blc2.winlostdate,
				blc2.TranId3rd AS BetCheck,
				blc2.transdesc,
				CASE
					WHEN pj.ProductId IS NOT NULL AND blc2.statusID IN (111, 112, 113) THEN ISNULL(blc2.BetStake, 0)
					ELSE 0
				END AS OddsSpread,
				0 AS OriginalBetType,
				CASE
					WHEN pj.ProductId IS NOT NULL THEN ISNULL(blc2.RefNo2, -1)
					ELSE -1
				END AS BetdaqId,
				blc2.ExtraInfo,
				CASE
					WHEN pj.ProductId IS NOT NULL THEN ISNULL(blc2.JackpotInfo, '')
					ELSE ''
				END AS JackpotInfo,
				0 AS WalletType,
				0 AS RefCode,
				blc2.currency,
				blc2.SiteId,
				0 AS LeagueGroupID,
				blc2.DeviceType
			FROM dbo.bettransLC AS blc2 WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = blc2.gameID
				LEFT JOIN @ProductJackpot AS pj ON s.ProductId = pj.ProductId
			WHERE blc2.transid = @TransId
				AND (s.ProductID IN (11, 21, 45, 46, 51, 52, 57, 65, 70, 76, 80) OR s.RefTable = 2)
		END
	END

	-- Get AllBet, Sexy Gaming, IBCBet Live Casino, WM, Big Gaming, PP Live Casino, FGG, YeeBet, WE related tickets (same game)
	IF @WinLostDate IS NOT NULL
		AND @WinLostDate > @MoveBetsDay
		AND EXISTS (SELECT 1
					FROM @Data AS b
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE (s.ProductID IN (21, 45, 46, 51, 57, 65, 70, 76, 80) OR s.RefTable = 2) AND b.MatchCode <> '')
	BEGIN
		INSERT INTO @Data
		(
			BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime
			, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam, SPositionTaking
			, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore
			, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost
			, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode, CurrencyId, SiteId
			, LeagueGroupId, DeviceType
		)
		SELECT
			blc.gameID AS BetType,
			blc.transid,
			0 AS BetId,
			blc.refno,
			CASE
				WHEN s.ProductID = 11 THEN ''
				ELSE blc.GameId3rd
			END AS matchcode,
			'' AS Race,
			CASE
				WHEN s.ProductID IN (70, 90) THEN blc.TransDate3rd
				ELSE '' 
			END AS eventdate,
			0 AS virtualrate,
			0 AS isShowOTExRate,
			blc.sdiscount,
			CASE
				WHEN blc.mrecommend = -4 THEN 0
				ELSE blc.adiscount
			END,
			CASE
				WHEN blc.recommend IN (-3, -4) THEN 0
				ELSE blc.discount
			END,
			0 AS homeid,
			0 AS awayid,
			'' AS settleTime,
			0 AS hdp1,
			0 AS hdp2,
			CASE
				WHEN s.ProductID IN (21, 45, 46, 51, 57, 76, 80, 96) THEN blc.odds
				WHEN pj.ProductId IS NOT NULL AND blc.statusID IN (111, 112, 113) THEN ISNULL(blc.ContributionRate, 0)
				ELSE 0
			END AS odds,
			0 AS finalodds,
			0 AS finalodds2,
			0 AS OddsType,
			blc.status,
			0 AS SettlementStatus,
			'' AS comstatus,
			blc.stake,
			blc.actual_stake,
			blc.transdate,
			'' AS betteam,
			blc.spositiontaking,
			blc.mpositiontaking,
			blc.apositiontaking,
			0 AS SPositionTaking2,
			0 AS MPositionTaking2,
			0 AS APositionTaking2,
			0 AS liveindicator,
			0 AS modds,
			blc.custid,
			0 AS livehomescore,
			0 AS liveawayscore,
			0 AS finalhomescore,
			0 AS finalawayscore,
			0 AS leagueid,
			blc.productID AS Sporttype,
			blc.ip,
			0 AS MatchId,
			CONVERT(BIT, 0) AS IsNeutral,
			(blc.winlost - blc.actual_stake) AS winlost,
			blc.playercomm AS Commission,
			(blc.scomm - blc.acomm) AS scomm,
			(blc.acomm - blc.comm) AS acomm,
			(blc.comm - blc.playercomm) AS comm,
			blc.awinlost,
			blc.mwinlost,
			blc.swinlost,
			'' AS showtime,
			blc.winlostdate,
			blc.TranId3rd AS BetCheck,
			blc.transdesc,
			CASE
					WHEN pj.ProductId IS NOT NULL AND blc.statusID IN (111, 112, 113) THEN ISNULL(blc.BetStake, 0)
					ELSE 0
				END AS OddsSpread,
			0 AS OriginalBetType,
			CASE
					WHEN pj.ProductId IS NOT NULL THEN ISNULL(blc.RefNo2, -1)
					ELSE -1
				END AS BetdaqId,
			blc.ExtraInfo,
			CASE
					WHEN pj.ProductId IS NOT NULL THEN ISNULL(blc.JackpotInfo, '')
					ELSE ''
				END AS JackpotInfo,
			0 AS WalletType,
			0 AS RefCode,
			blc.currency,
			blc.SiteId,
			0 AS LeagueGroupID,
			blc.DeviceType
		FROM dbo.bettransLC AS blc WITH (NOLOCK)
			INNER JOIN @Data AS b1 ON blc.custid = b1.CustId AND blc.gameID = b1.BetType AND blc.GameId3rd = b1.MatchCode
			INNER JOIN @SportBettype AS s ON s.Bettype = b1.bettype
			LEFT JOIN @ProductJackpot AS pj ON s.ProductId = pj.ProductId
		WHERE (s.ProductID IN (21, 45, 46, 51, 57, 65, 70, 76, 80) OR s.RefTable = 2)
			AND b1.MatchCode <> ''
			AND blc.transid <> @TransId
	END

	-- Bettransg tables
	SET @WinLostDate = NULL
	SET @CustId = NULL

	-- bettransg
	SELECT TOP(1)
		@TransId = b.transid,
		@BetType = b.bettype,
		@WinLostDate = b.winlostdate,
		@CustId = b.custid
	FROM dbo.bettransg AS b WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp ON b.bettype = sp.bettype
	WHERE b.transid = @RefNo

	IF @WinLostDate IS NOT NULL
		AND @WinLostDate > @MoveBetsDay
		AND NOT EXISTS ( SELECT 1
						FROM CustDB.dbo.Customer AS c WITH (NOLOCK)
							INNER JOIN CustDB.dbo.Customer AS a WITH (NOLOCK) ON c.recommend = a.custid
							WHERE c.custid = @CustId
								AND a.site IN (SELECT Site FROM @DeniedSite))
		AND NOT EXISTS ( SELECT 1
						FROM CustDB.dbo.customer AS c WITH (NOLOCK)
						WHERE c.custid = @CustId
							AND c.currency IN (SELECT ExchangeId FROM @DeniedCurrency))
	BEGIN
		-- SA Gaming
		IF EXISTS ( SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (39) AND Bettype = @BetType )
		BEGIN
			INSERT INTO @Data
			(
				BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime
				, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam, SPositionTaking
				, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore
				, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost
				, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode, CurrencyId, SiteId
				, LeagueGroupId, DeviceType
			)
			SELECT
				b39.bettype,
				b39.transid,
				0 AS BetId,
				b39.refno,
				ISNULL(blc.GameId3rd, '') AS matchcode,
				'' AS Race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b39.sdiscount,
				CASE
					WHEN blc.mrecommend = -4 THEN 0
					ELSE b39.adiscount
				END,
				CASE
					WHEN blc.recommend IN (-3, -4) THEN 0
					ELSE b39.discount
				END,
				0 AS homeid,
				0 AS awayid,
				'' AS settleTime,
				0 AS hdp1,
				0 AS hdp2,
				b39.odds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				b39.status,
				0 AS SettlementStatus,
				'' AS comstatus,
				b39.stake,
				b39.actual_stake,
				b39.transdate,
				ISNULL(b39.BetID3rd, '') AS BetTeam,
				b39.spositiontaking,
				b39.mpositiontaking,
				b39.apositiontaking,
				0 AS SPositionTaking2,
				0 AS MPositionTaking2,
				0 AS APositionTaking2,
				0 AS liveindicator,
				0 AS modds,
				b39.custid,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS leagueid,
				ISNULL(blc.ProductID, 0) AS Sporttype,
				ISNULL(blc.ip, '') AS Ip,
				0 AS MatchId,
				CONVERT(BIT, 0) AS IsNeutral,
				b39.winlost - b39.actual_stake AS WinLost,
				b39.playercomm AS Commission,
				b39.scomm - b39.acomm AS SComm,
				b39.acomm - b39.comm AS AComm,
				b39.comm - b39.playercomm AS Comm,
				b39.awinlost,
				b39.mwinlost,
				b39.swinlost,
				'' AS showtime,
				b39.winlostdate,
				ISNULL(b39.TransDesc, '') AS BetCheck,
				ISNULL(blc.transdesc, '') AS TransDesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				b39.ExtraInfo,
				'' AS JackpotInfo,
				0 AS WalletType,
				0 AS RefCode,
				b2.currency,
				b39.SiteId,
				0 AS LeagueGroupID,
				b39.DeviceType
			FROM dbo.bettransg AS b39 WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.BetType = b39.bettype
				INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON b39.refno = blc.transid AND b39.custid = blc.custid
				INNER JOIN dbo.bettrans AS b2 WITH (NOLOCK) ON b2.transid = blc.refno AND b2.custid = b39.CustId
			WHERE b39.transid = @TransId AND s.ProductID IN (39)
		END

		-- BBIN
		IF EXISTS ( SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (47) AND Bettype = @BetType )
		BEGIN
			INSERT INTO @Data
			(
				BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime
				, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam, SPositionTaking
				, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore
				, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost
				, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode, CurrencyId, SiteId
				, LeagueGroupId, DeviceType
			)
			SELECT
				b47.bettype,
				b47.transid,
				0 AS BetId,
				b47.refno,
				'' AS matchcode,
				'' AS Race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b47.sdiscount,
				CASE
					WHEN b2.mrecommend = -4 THEN 0
					ELSE b47.adiscount
				END,
				CASE
					WHEN b2.recommend IN (-3, -4) THEN 0
					ELSE b47.discount
				END,
				0 AS homeid,
				0 AS awayid,
				'' AS settleTime,
				0 AS hdp1,
				0 AS hdp2,
				b47.odds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				b47.status,
				0 AS SettlementStatus,
				'' AS comstatus,
				b47.stake,
				b47.actual_stake,
				b47.transdate,
				ISNULL(b47.betteam, '') AS BetTeam,
				b47.spositiontaking,
				b47.mpositiontaking,
				b47.apositiontaking,
				0 AS SPositionTaking2,
				0 AS MPositionTaking2,
				0 AS APositionTaking2,
				0 AS liveindicator,
				0 AS modds,
				b47.custid,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS leagueid,
				b47.matchid AS Sporttype,
				ISNULL(b2.ip, '') AS Ip,
				0 AS MatchId,
				CONVERT(BIT, 0) AS IsNeutral,
				b47.winlost - b47.actual_stake AS WinLost,
				b47.playercomm AS Commission,
				b47.scomm - b47.acomm AS SComm,
				b47.acomm - b47.comm AS AComm,
				b47.comm - b47.playercomm AS Comm,
				b47.awinlost,
				b47.mwinlost,
				b47.swinlost,
				'' AS showtime,
				b47.winlostdate,
				ISNULL(b47.BetID3rd, '') AS BetCheck,
				ISNULL(b47.transdesc, '') AS TransDesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				'' AS JackpotInfo,
				0 AS WalletType,
				0 AS RefCode,
				b2.currency,
				b47.SiteId,
				0 AS LeagueGroupID,
				b47.DeviceType
			FROM dbo.bettransg AS b47 WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.BetType = b47.bettype
				INNER JOIN dbo.bettrans AS b2 WITH (NOLOCK) ON b2.transid = b47.refno AND b2.custid = b47.CustId
			WHERE b47.transid = @TransId AND s.ProductID IN (47)
		END
	END

	-- Get SA Gaming, BBIN related tickets (same game)
	IF @WinLostDate IS NOT NULL
		AND @WinLostDate > @MoveBetsDay
		AND EXISTS (SELECT 1
					FROM @Data AS b
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE (s.ProductID = 39 AND b.MatchCode <> '')
						OR (s.ProductID = 47 AND b.BetTeam <> ''))
	BEGIN
		-- SA Gaming
		INSERT INTO @Data (
			BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime
			, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam, SPositionTaking
			, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore
			, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost
			, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode, CurrencyId, SiteId
			, LeagueGroupId, DeviceType
		)
		SELECT
			bsa.bettype,
			bsa.transid,
			0 AS BetId,
			bsa.refno,
			ISNULL(blc.GameId3rd, '') AS matchcode,
			'' AS Race,
			'' AS eventdate,
			0 AS virtualrate,
			0 AS isShowOTExRate,
			bsa.sdiscount,
			CASE
				WHEN b2.mrecommend = -4 THEN 0
				ELSE bsa.adiscount
			END,
			CASE
				WHEN b2.recommend IN (-3, -4) THEN 0
				ELSE bsa.discount
			END,
			0 AS homeid,
			0 AS awayid,
			'' AS settleTime,
			0 AS hdp1,
			0 AS hdp2,
			bsa.odds,
			0 AS finalodds,
			0 AS finalodds2,
			0 AS OddsType,
			bsa.status,
			0 AS SettlementStatus,
			'' AS comstatus,
			bsa.stake,
			bsa.actual_stake,
			bsa.transdate,
			ISNULL(bsa.BetID3rd, '') AS BetTeam,
			bsa.spositiontaking,
			bsa.mpositiontaking,
			bsa.apositiontaking,
			0 AS SPositionTaking2,
			0 AS MPositionTaking2,
			0 AS APositionTaking2,
			0 AS liveindicator,
			0 AS modds,
			bsa.custid,
			0 AS livehomescore,
			0 AS liveawayscore,
			0 AS finalhomescore,
			0 AS finalawayscore,
			0 AS leagueid,
			ISNULL(blc.ProductID, 0) AS Sporttype,
			ISNULL(blc.ip, '') AS Ip,
			0 AS MatchId,
			CONVERT(BIT, 0) AS IsNeutral,
			bsa.winlost - bsa.actual_stake AS WinLost,
			bsa.playercomm AS Commission,
			bsa.scomm - bsa.acomm AS SComm,
			bsa.acomm - bsa.comm AS AComm,
			bsa.comm - bsa.playercomm AS Comm,
			bsa.awinlost,
			bsa.mwinlost,
			bsa.swinlost,
			'' AS showtime,
			bsa.winlostdate,
			ISNULL(bsa.TransDesc, '') AS BetCheck,
			ISNULL(blc.transdesc, '') AS TransDesc,
			0 AS OddsSpread,
			0 AS OriginalBetType,
			-1 AS BetdaqId,
			bsa.ExtraInfo,
			'' AS JackpotInfo,
			0 AS WalletType,
			0 AS RefCode,
			b2.currency,
			bsa.SiteId,
			0 AS LeagueGroupID,
			bsa.DeviceType
		FROM dbo.bettransg AS bsa WITH (NOLOCK)
			INNER JOIN @Data AS b1 ON bsa.custid = b1.CustId AND bsa.bettype = b1.BetType AND bsa.winlostdate = b1.WinLostDate
			INNER JOIN @SportBettype AS s ON s.Bettype = b1.bettype
			INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON bsa.refno = blc.transid AND bsa.custid = blc.custid
			INNER JOIN dbo.bettrans AS b2 WITH (NOLOCK) ON b2.transid = blc.refno AND b2.custid = bsa.CustId
		WHERE bsa.transid <> @TransId
			AND s.productID = 39
			AND b1.MatchCode <> ''
			AND bsa.betteam = b1.MatchCode
			
		-- BBIN
		INSERT INTO @Data (
			BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime
			, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam, SPositionTaking
			, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore
			, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost
			, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode, CurrencyId, SiteId
			, LeagueGroupId, DeviceType
		)
		SELECT
			bbi.bettype,
			bbi.transid,
			0 AS BetId,
			bbi.refno,
			'' AS matchcode,
			'' AS Race,
			'' AS eventdate,
			0 AS virtualrate,
			0 AS isShowOTExRate,
			bbi.sdiscount,
			CASE
				WHEN b2.mrecommend = -4 THEN 0
				ELSE bbi.adiscount
			END,
			CASE
				WHEN b2.recommend IN (-3, -4) THEN 0
				ELSE bbi.discount
			END,
			0 AS homeid,
			0 AS awayid,
			'' AS settleTime,
			0 AS hdp1,
			0 AS hdp2,
			bbi.odds,
			0 AS finalodds,
			0 AS finalodds2,
			0 AS OddsType,
			bbi.status,
			0 AS SettlementStatus,
			'' AS comstatus,
			bbi.stake,
			bbi.actual_stake,
			bbi.transdate,
			ISNULL(bbi.betteam, '') AS BetTeam,
			bbi.spositiontaking,
			bbi.mpositiontaking,
			bbi.apositiontaking,
			0 AS SPositionTaking2,
			0 AS MPositionTaking2,
			0 AS APositionTaking2,
			0 AS liveindicator,
			0 AS modds,
			bbi.custid,
			0 AS livehomescore,
			0 AS liveawayscore,
			0 AS finalhomescore,
			0 AS finalawayscore,
			0 AS leagueid,
			bbi.matchid AS Sporttype,
			ISNULL(b2.ip, '') AS Ip,
			0 AS MatchId,
			CONVERT(BIT, 0) AS IsNeutral,
			bbi.winlost - bbi.actual_stake AS WinLost,
			bbi.playercomm AS Commission,
			bbi.scomm - bbi.acomm AS SComm,
			bbi.acomm - bbi.comm AS AComm,
			bbi.comm - bbi.playercomm AS Comm,
			bbi.awinlost,
			bbi.mwinlost,
			bbi.swinlost,
			'' AS showtime,
			bbi.winlostdate,
			ISNULL(bbi.BetID3rd, '') AS BetCheck,
			ISNULL(bbi.transdesc, '') AS TransDesc,
			0 AS OddsSpread,
			0 AS OriginalBetType,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			'' AS JackpotInfo,
			0 AS WalletType,
			0 AS RefCode,
			b2.currency,
			bbi.SiteId,
			0 AS LeagueGroupID,
			bbi.DeviceType
		FROM dbo.bettransg AS bbi WITH (NOLOCK)
			INNER JOIN @Data AS b1 ON bbi.custid = b1.CustId AND bbi.bettype = b1.BetType AND bbi.winlostdate = b1.WinLostDate
			INNER JOIN @SportBettype AS s ON s.Bettype = b1.bettype
			INNER JOIN dbo.bettrans AS b2 WITH (NOLOCK) ON b2.transid = bbi.refno AND b2.custid = bbi.CustId
		WHERE bbi.transid <> @TransId
			AND s.productID = 47
			AND b1.BetTeam <> ''
			AND bbi.betteam = b1.BetTeam
	END

	SELECT 
		b.BetType,
		b.TransId,
		b.BetId,
		b.RefNo,
		b.MatchCode,
		b.Race,
		b.EventDate,
		b.VirtualRate,
		b.IsShowOTExRate,
		b.SDiscount,
		b.ADiscount,
		b.Discount,
		b.HomeId,
		b.AwayId,
		b.SettleTime,
		b.Hdp1,
		b.Hdp2,
		b.Odds,
		b.FinalOdds,
		b.FinalOdds2,
		b.OddsType,
		b.Status,
		b.SettlementStatus,
		b.ComStatus,
		b.Stake,
		b.Actual_Stake,
		b.TransDate,
		b.BetTeam,
		b.SPositionTaking,
		b.MPositionTaking,
		b.APositionTaking,
		b.SPositionTaking2,
		b.MPositionTaking2,
		b.APositionTaking2,
		b.LiveIndicator,
		b.Modds,
		b.CustId,
		b.LiveHomeScore,
		b.LiveAwayScore,
		b.FinalHomeScore,
		b.FinalAwayScore,
		b.LeagueId,
		b.SportType,
		b.Ip,
		b.MatchId,
		b.IsNeutral,
		b.WinLost,
		b.Commission,
		b.SComm,
		b.AComm,
		b.Comm,
		b.AWinLost,
		b.MWinLost,
		b.SWinLost,
		b.ShowTime,
		b.WinLostDate,
		b.BetCheck,
		b.TransDesc,
		b.OddsSpread,
		b.OriginalBetType,
		b.BetdaqId,
		b.ExtraInfo,
		b.JackpotInfo,
		b.WalletType,
		b.RefCode,
		b.CurrencyId,
		b.SiteId,
		b.LeagueGroupId,
		b.DeviceType,
		c.username,
		ex.currency,
		s.IsChinaView,
		s.SpecialPlatfrom
	FROM @Data AS b
		LEFT JOIN CustDB.dbo.Customer AS c WITH (NOLOCK) ON c.CustId = b.CustId
		LEFT JOIN CustDB.dbo.Exchange AS ex WITH (NOLOCK) ON c.currency = ex.exchangeid
		LEFT JOIN CustDB.dbo.Site AS s WITH (NOLOCK) ON s.Site = c.Site
	ORDER BY b.TransId ASC	
END
GO
