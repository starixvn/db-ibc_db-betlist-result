/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_BetList_SelDeleted]
	@CustId			INT,
	@RoleId			INT,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@ProductIds		VARCHAR(MAX),
	@StatusIdList	VARCHAR(50)		= '',
	@PageSize		INT				= 50,
	@PageIndex		INT				= 1,
	@TotalRows		INT				= 0 OUTPUT
AS

/*
	Task:
	DB: DBAGE.bodb02

	Revisions:
		- 20060222@[]: Remove refno
		- 20071112@Thien: Add username for calling from API
		- 20080513@Viet: Add IP
		- 20080629@Viet: Remove Teamname, Leaguename, Sportname, TypeName
		- 20090416@Minh: Remove indexName
		- 20090523@Hiep: Get more result for Horse racing fix odds
		- 20090618@AnhPham: Remove 'Customer' table
		- 20090710@Phuc: Unhide IP for TP currency
		- 20091003@[MinhNguyen]: Get oddstype
		- 20091024@[MinhNguyen]: Get modds, finalodds
		- 20091208@Henry: Get real refno (column refno from bettrans)
		- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement
		- 20110408@Amy: Change function to get Odds value and showed odds type
					- Remove hardcode for b.status
		- 20110811@Sophia: Add betID
		- 20111216@Sophia: Remove function f_GetOddsByBettype, f_GetChoice, f_ShowOddsByBettype
		- 20120119@Sophia: Add show time for LiveCasino: Sporttype: 162, bettype: 1101 -> 1199
						- Add Detail for Live Casino
		- 20120704@Jamie: Insert wrong column in temp table for groupmatch and eventdate at Agent Level
		- 20130228@Elodie: Add Virtual HR report
		- 20140303@Elodie: Add Keno sport [Redmine:#12756]
		- 20141103@Dom: Apply sport bettype matrix
		- 20150504@Tom: Get BetCheck Column
		- 20150522@Bobby: Add GD product
		- 20150526@Bobby: Implement bet list core
		- 20150706@Bobby: #39097 - Fixing bug for showing Keno's bettype info
		- 20150826@Kos: Add OddsSpread column to support Myanmar Odds
		- 20150903@Bobby: Correct data type of sport bet type matrix for avoiding SQL data conversion
		- 20150910@Bobby: Enhance performance for SP core. Apply TVP for input parameters
		- 20160105@Kos: Don't support RNG Casino Single Wallet [Redmine: 48958]
		- 20160215@Kos: Don't support AllBet [#Redmine: 50864]
		- 20160401@Kos: Don't support Voidbridge [#Redmine: 54643]
		- 20160712@Kos: Change to use inline function for SportBettypeMatrix
		- 20161101@Kos: Don't support Fishing World [#Redmine: 65934]
		- 20180201@Kos: Don't support Racing, RNG Casino (bettype 71, 72), Bingo, P2P, Cockfighting [#Redmine: 86086]
		- 20180418@Kos: Don't support Pragmatic Casino [#Redmine: 92160]
		- 20180710@Kos: Don't support Poker Games [#Redmine: 97565]
		- 20180807@Kos: Enhance and support Refund tickets [#Redmine: 98338]
					- Support Poker Games
		- 20181003@Helen: Modify code to adapt indexes changed on DB053 [Redmine:101405]
		- 20181011@Kos: Support Gold Deluxe - SicBo & BidMe [#Redmine: 101690]
		- 20181218@Kos: Support E-Sports phase 2b [#Redmine: 106456]
		- 20190506@Kos: Show match KO time for single ticket [Redmine: #112092]
		- 20190628@Kos: Support PH AIO 4a [Redmine: #112894]
		- 20190723@Kos: Don't support Poker Games anymore [Redmine: #107645]
		- 20190829@Kos: Don't support inactive products anymore [Redmine: #119100]
		- 20191127@Kos: Hotfix - Oddsspread data type [Redmine: #124483]
		- 20191218@Kos: Support Virtual Games [Redmine: #124759]
		- 20200402@Kos: Support Table Games [Redmine: #129433]
		- 20200410@Kos: Support BBIN [Redmine: #131362]
		- 20200625@Kos: Integrate archive process for table VSRaceInfo [Redmine: #135963]
		- 20201127@Kos: Support Leap Gaming Virtual Sports 3 [Redmine: #131371]
		- 20201224@Kos: Support Happy 5 Linked Games [Redmine: #146540]
		- 20210129@Kos: Support God Of Fortune [Redmine: #149740]
		- 20210301@Razor: Support Sports Lottery [Redmine: #147368]
		- 20210705@Razor: Show Odds for Happy 5 Linked Games [Redmine: #154704]
		- 20210706@Razor: Display Decimal Odds for Decimal Odds Only Bettypes [#Redmine: 157545]
		- 20210813@Razor: Support Bitcoin [Redmine: #159041]
		- 20211004@Razor: Extend Data type of IP v6 [Redmine: #90903]
		- 20211130@Razor: Support new Cash out model [Redmine: #164903]
		- 20211223@Razor: Support Third Party Result API [Redmine: #165815]
		- 20230727@Razor: Support Virtual Sports 3 [Redmine: #189205]
		- 20230909@Razor: Remove GD, Colossusbet products [Redmine: #179132]
		- 20231004@Kos: Support Parlay Boost [Redmine: #194992]
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Data (
		TransId			BIGINT,
		RefNo			BIGINT,
		CustId			INT,
		SportType		SMALLINT,
		BetType			SMALLINT,
		BetId			BIGINT,
		BetTeam			NVARCHAR(20),
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		OddsType		TINYINT,
		OddsId			INT,
		Odds			MONEY,
		MOdds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		Status			NVARCHAR(10),
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				VARCHAR(45),
		LeagueId		INT,
		MatchId			INT,
		MatchCode		NVARCHAR(50),
		Race			NVARCHAR(20),
		EventDate		DATETIME,
		HomeId			INT,
		AwayId			INT,
		BetStatus		NVARCHAR(50),
		IsNeutral		BIT,
		Placing			NVARCHAR(20),
		ShowTime		NVARCHAR(50),
		BetCheck		NVARCHAR(50),
		ComStatus		NVARCHAR(20),
		TransDesc		NVARCHAR(1000),
		OddsSpread		MONEY,
		ExtraInfo		VARCHAR(1000),
		ProductId		TINYINT,
		EventType		INT,
		SubProduct		VARCHAR(500),
		WhTicket		TINYINT,
		BetdaqId		BIGINT,
		CurrencyId		TINYINT,
		SiteId			VARCHAR(20)
	);

	CREATE TABLE #PagingData (
		TransId			BIGINT,
		RefNo			BIGINT,
		CustId			INT,
		SportType		SMALLINT,
		BetType			SMALLINT,
		BetId			BIGINT,
		BetTeam			NVARCHAR(20),
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		OddsType		TINYINT,
		OddsId			INT,
		Odds			MONEY,
		MOdds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		Status			NVARCHAR(10),
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				VARCHAR(45),
		LeagueId		INT,
		MatchId			INT,
		MatchCode		NVARCHAR(50),
		Race			NVARCHAR(20),
		EventDate		DATETIME,
		HomeId			INT,
		AwayId			INT,
		BetStatus		NVARCHAR(50),
		IsNeutral		BIT,
		Placing			NVARCHAR(20),
		ShowTime		NVARCHAR(50),
		BetCheck		NVARCHAR(50),
		ComStatus		NVARCHAR(20),
		TransDesc		NVARCHAR(1000),
		OddsSpread		MONEY,
		ExtraInfo		VARCHAR(1000),
		ProductId		TINYINT,
		EventType		INT,
		SubProduct		VARCHAR(500),
		WhTicket		TINYINT,
		BetdaqId		BIGINT,
		CurrencyId		TINYINT,
		SiteId			VARCHAR(20)
	);

	DECLARE @BetListDetail TABLE(
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		MPositionTaking	SMALLMONEY,
		SPositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(20),
		TransDesc		VARCHAR (1000)
	)

	DECLARE @TempFromDate	SMALLDATETIME,
		@TempToDate			SMALLDATETIME

	-- bettrans
	IF @ToDate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		IF @RoleId = 2
		BEGIN
			INSERT INTO #Data (
				TransId,
				RefNo,
				CustId,
				BetType,
				BetId,
				BetTeam,
				Hdp1,
				Hdp2,
				OddsType,
				OddsId,
				Odds,
				MOdds,
				Stake,
				Actual_Stake,
				Status,
				TransDate,
				WinLostDate,
				LiveIndicator,
				LiveHomeScore,
				LiveAwayScore,
				Ip,
				MatchId,
				BetCheck,
				ComStatus,
				TransDesc,
				OddsSpread,
				ExtraInfo,
				WhTicket,
				BetdaqId,
				CurrencyId,
				SiteId)
			SELECT
				b.transid,
				b.refno,
				b.custid,
				b.bettype,
				b.betid,
				b.betteam,
				b.hdp1,
				b.hdp2,
				b.oddstype,
				b.oddsid,
				b.odds,
				b.modds,
				b.stake,
				b.actual_stake,
				b.status,
				b.transdate,
				b.winlostdate,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				b.matchid,
				b.betcheck,
				b.comstatus,
				b.transdesc,
				b.oddsspread,
				b.ExtraInfo,
				1 AS WhTicket,
				b.betdaqid,
				b.currency,
				b.betdaqid
			FROM dbo.bettrans AS b WITH (NOLOCK)
			WHERE b.recommend = @CustId
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
		END

		IF @RoleId = 3
		BEGIN
			INSERT INTO #Data (
				TransId,
				RefNo,
				CustId,
				BetType,
				BetId,
				BetTeam,
				Hdp1,
				Hdp2,
				OddsType,
				OddsId,
				Odds,
				MOdds,
				Stake,
				Actual_Stake,
				Status,
				TransDate,
				WinLostDate,
				LiveIndicator,
				LiveHomeScore,
				LiveAwayScore,
				Ip,
				MatchId,
				BetCheck,
				ComStatus,
				TransDesc,
				OddsSpread,
				ExtraInfo,
				WhTicket,
				BetdaqId,
				CurrencyId,
				SiteId)
			SELECT
				b.transid,
				b.refno,
				b.custid,
				b.bettype,
				b.betid,
				b.betteam,
				b.hdp1,
				b.hdp2,
				b.oddstype,
				b.oddsid,
				b.odds,
				b.modds,
				b.stake,
				b.actual_stake,
				b.status,
				b.transdate,
				b.winlostdate,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				b.matchid,
				b.betcheck,
				b.comstatus,
				b.transdesc,
				b.oddsspread,
				b.ExtraInfo,
				1 AS WhTicket,
				b.BetdaqId,
				b.currency,
				b.betdaqid
			FROM dbo.bettrans AS b WITH (NOLOCK)
			WHERE b.mrecommend = @CustId
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
		END

		IF @RoleId = 4
		BEGIN
			INSERT INTO #Data (
				TransId,
				RefNo,
				CustId,
				BetType,
				BetId,
				BetTeam,
				Hdp1,
				Hdp2,
				OddsType,
				OddsId,
				Odds,
				MOdds,
				Stake,
				Actual_Stake,
				Status,
				TransDate,
				WinLostDate,
				LiveIndicator,
				LiveHomeScore,
				LiveAwayScore,
				Ip,
				MatchId,
				BetCheck,
				ComStatus,
				TransDesc,
				OddsSpread,
				ExtraInfo,
				WhTicket,
				BetdaqId,
				CurrencyId,
				SiteId)
			SELECT
				b.transid,
				b.refno,
				b.custid,
				b.bettype,
				b.betid,
				b.betteam,
				b.hdp1,
				b.hdp2,
				b.oddstype,
				b.oddsid,
				b.odds,
				b.modds,
				b.stake,
				b.actual_stake,
				b.status,
				b.transdate,
				b.winlostdate,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				b.matchid,
				b.betcheck,
				b.comstatus,
				b.transdesc,
				b.oddsspread,
				b.ExtraInfo,
				1 AS WhTicket,
				b.BetdaqId,
				b.currency,
				b.betdaqid
			FROM dbo.bettrans AS b WITH (NOLOCK)
			WHERE b.srecommend = @CustId
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
		END
	END

	-- bettrans14
	IF @FromDate <= @MoveBetsDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @ToDate

		IF @RoleId = 2
		BEGIN
			INSERT INTO #Data (
				TransId,
				RefNo,
				CustId,
				BetType,
				BetId,
				BetTeam,
				Hdp1,
				Hdp2,
				OddsType,
				OddsId,
				Odds,
				MOdds,
				Stake,
				Actual_Stake,
				Status,
				TransDate,
				WinLostDate,
				LiveIndicator,
				LiveHomeScore,
				LiveAwayScore,
				Ip,
				MatchId,
				BetCheck,
				ComStatus,
				TransDesc,
				OddsSpread,
				ExtraInfo,
				WhTicket,
				BetdaqId,
				CurrencyId,
				SiteId)
			SELECT
				b.transid,
				b.refno,
				b.custid,
				b.bettype,
				b.betid,
				b.betteam,
				b.hdp1,
				b.hdp2,
				b.oddstype,
				b.oddsid,
				b.odds,
				b.modds,
				b.stake,
				b.actual_stake,
				b.status,
				b.transdate,
				b.winlostdate,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				b.matchid,
				b.betcheck,
				b.comstatus,
				b.transdesc,
				b.oddsspread,
				b.ExtraInfo,
				2 AS WhTicket,
				b.BetdaqId,
				b.currency,
				b.betdaqid
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
			WHERE b.recommend = @CustId
				AND b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
		END

		IF @RoleId = 3
		BEGIN
			INSERT INTO #Data (
				TransId,
				RefNo,
				CustId,
				BetType,
				BetId,
				BetTeam,
				Hdp1,
				Hdp2,
				OddsType,
				OddsId,
				Odds,
				MOdds,
				Stake,
				Actual_Stake,
				Status,
				TransDate,
				WinLostDate,
				LiveIndicator,
				LiveHomeScore,
				LiveAwayScore,
				Ip,
				MatchId,
				BetCheck,
				ComStatus,
				TransDesc,
				OddsSpread,
				ExtraInfo,
				WhTicket,
				BetdaqId,
				CurrencyId,
				SiteId)
			SELECT
				b.transid,
				b.refno,
				b.custid,
				b.bettype,
				b.betid,
				b.betteam,
				b.hdp1,
				b.hdp2,
				b.oddstype,
				b.oddsid,
				b.odds,
				b.modds,
				b.stake,
				b.actual_stake,
				b.status,
				b.transdate,
				b.winlostdate,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				b.matchid,
				b.betcheck,
				b.comstatus,
				b.transdesc,
				b.oddsspread,
				b.ExtraInfo,
				2 AS WhTicket,
				b.BetdaqId,
				b.currency,
				b.betdaqid
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
			WHERE b.mrecommend = @CustId
				AND b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
		END

		IF @RoleId = 4
		BEGIN
			INSERT INTO #Data (
				TransId,
				RefNo,
				CustId,
				BetType,
				BetId,
				BetTeam,
				Hdp1,
				Hdp2,
				OddsType,
				OddsId,
				Odds,
				MOdds,
				Stake,
				Actual_Stake,
				Status,
				TransDate,
				WinLostDate,
				LiveIndicator,
				LiveHomeScore,
				LiveAwayScore,
				Ip,
				MatchId,
				BetCheck,
				ComStatus,
				TransDesc,
				OddsSpread,
				ExtraInfo,
				WhTicket,
				BetdaqId,
				CurrencyId,
				SiteId)
			SELECT
				b.transid,
				b.refno,
				b.custid,
				b.bettype,
				b.betid,
				b.betteam,
				b.hdp1,
				b.hdp2,
				b.oddstype,
				b.oddsid,
				b.odds,
				b.modds,
				b.stake,
				b.actual_stake,
				b.status,
				b.transdate,
				b.winlostdate,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				b.matchid,
				b.betcheck,
				b.comstatus,
				b.transdesc,
				b.oddsspread,
				b.ExtraInfo,
				2 AS WhTicket,
				b.BetdaqId,
				b.currency,
				b.betdaqid
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
			WHERE b.srecommend = @CustId
				AND b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
		END
	END

	IF EXISTS (SELECT TOP(1) 1 FROM #Data)
	BEGIN
		DECLARE @IsTest BIT = 0

		SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

		-- Get Betradar Virtual Sports in addition to Virtual Sports
		SET @ProductIds = dbo.f_AddRelatedProducts(@ProductIds)

		-- Get Sport/Bettype info
		UPDATE b
		SET ProductID = s.ProductID,
			EventType = s.EventType,
			SubProduct = s.SubProduct
		FROM #Data AS b
			INNER JOIN dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) AS s ON b.bettype = s.bettype

		DELETE #Data
		WHERE ProductID IS NULL
			OR ProductID NOT IN (1, 3, 5, 8, 23, 27, 28, 38, 40, 47, 49, 63, 69, 77)	-- Only support these products
			OR BetType IN (901, 902, 903, 904)

		IF EXISTS (SELECT TOP(1) 1 FROM #Data)
		BEGIN
			SELECT @TotalRows = COUNT(TransId)
			FROM #Data

			DECLARE @RowStart INT,
				@RowEnd INT

			SELECT @PageIndex = @PageIndex - 1,
				@RowStart = @PageSize * @PageIndex + 1,
				@RowEnd = @RowStart + @PageSize - 1

			INSERT INTO #PagingData (
				TransId,
				RefNo,
				CustId,
				BetType,
				BetId,
				BetTeam,
				Hdp1,
				Hdp2,
				OddsType,
				OddsId,
				Odds,
				MOdds,
				Stake,
				Actual_Stake,
				Status,
				TransDate,
				WinLostDate,
				LiveIndicator,
				LiveHomeScore,
				LiveAwayScore,
				Ip,
				MatchId,
				BetCheck,
				ComStatus,
				TransDesc,
				OddsSpread,
				ExtraInfo,
				ProductId,
				EventType,
				SubProduct,
				WhTicket,
				BetdaqId,
				CurrencyId,
				SiteId)
			SELECT
				b.TransId,
				b.RefNo,
				b.CustId,
				b.BetType,
				b.BetId,
				b.BetTeam,
				b.Hdp1,
				b.Hdp2,
				b.OddsType,
				b.OddsId,
				b.Odds,
				b.MOdds,
				b.Stake,
				b.Actual_Stake,
				b.Status,
				b.TransDate,
				b.WinLostDate,
				b.LiveIndicator,
				b.LiveHomeScore,
				b.LiveAwayScore,
				b.Ip,
				b.MatchId,
				b.BetCheck,
				b.ComStatus,
				b.TransDesc,
				b.OddsSpread,
				b.ExtraInfo,
				b.ProductId,
				b.EventType,
				b.SubProduct,
				b.WhTicket,
				b.BetdaqId,
				b.CurrencyId,
				b.SiteId
			FROM
				(
					SELECT
						ROW_NUMBER() OVER (ORDER BY TransId DESC) AS RowNum,
						*
					FROM #Data
				) AS b
			WHERE b.RowNum BETWEEN @RowStart AND @RowEnd

			DROP TABLE #Data

			-- bettrans
			IF EXISTS (SELECT 1 FROM #PagingData WHERE WhTicket = 1)
			BEGIN
				-- Sportsbook, Number Game, Virtual Sports, Betradar Virtual Sports, Virtual Sports 3
				UPDATE b
				SET
					SportType = m.sporttype,
					Hdp2 = CASE
								WHEN b.ProductId = 3 THEN 0
								ELSE b.Hdp2
							END,
					LeagueId = m.leagueid,
					MatchCode = m.matchcode,
					Race = '',
					EventDate = CASE
									WHEN b.ProductId = 1 THEN m.GlobalShowTime
									ELSE m.eventdate
								END,
					HomeId = m.homeid,
					AwayId = m.awayid,
					BetStatus = m.betstatus,
					IsNeutral = ISNULL(m.IsNeutral, CONVERT(BIT,0)),
					Placing = '',
					ShowTime = CASE
									WHEN b.ProductId IN (5, 27, 77) THEN CONVERT(NVARCHAR(50), m.kickofftime)
									ELSE ISNULL(m.showtime, '')
								END,
					BetCheck = b.BetCheck,
					ComStatus = '',
					TransDesc = CASE
									WHEN b.ProductId IN (1, 27, 77) THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					OddsSpread = CASE
									WHEN b.ProductId = 1 THEN ISNULL(b.oddsspread, 0)
									ELSE 0
								END,
					ExtraInfo = CASE
									WHEN b.ProductId = 1 THEN ISNULL(b.ExtraInfo, '')
									ELSE ''
								END,
					BetdaqId = CASE
									WHEN b.ProductId IN (1) THEN ISNULL(b.betdaqid, -1)
									ELSE -1
								END
				FROM #PagingData AS b
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				WHERE b.WhTicket = 1 AND b.EventType = 1

				-- Outright
				UPDATE b
				SET
					SportType = l.sporttype,
					BetTeam = '',
					Hdp1 = 0,
					Hdp2 = 0,
					LiveIndicator = 0,
					LiveHomeScore = 0,
					LiveAwayScore = 0,
					LeagueId = o.leagueid,
					MatchId = 0,
					MatchCode = o.matchcode,
					Race = o.groupmatch,
					EventDate = o.eventdate,
					HomeId = o.teamid,
					AwayId  = 0,
					BetStatus = '',
					IsNeutral = 0,
					Placing = '',
					ShowTime = '',
					BetCheck = '',
					ComStatus = '',
					TransDesc = '',
					OddsSpread = 0,
					ExtraInfo = ''
				FROM #PagingData AS b
					INNER JOIN dbo.outright AS o WITH (NOLOCK) ON b.matchid = o.orid
					INNER JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
				WHERE b.WhTicket = 1 AND b.BetType = 10

				/*
				- Mix & System Parlay	: ProductId = 1
				- Number Game			: ProductId = 3
				- Keno					: ProductId = 8
				- NG2					: ProductId = 23
				- Mix Parlay (VS2)		: ProductId = 27
				- Lottery				: ProductId = 28
				- Virtual Games			: ProductId = 38
				- Table Games			: ProductId = 40
				- BBIN					: ProductId = 47
				- Leap Gaming (VS3)		: ProductId = 49
				- Sports Lottery		: ProductId = 63
				*/
				UPDATE b
				SET
					SportType = CASE
									WHEN b.ProductId = 8 THEN 202
									WHEN b.ProductId = 23 AND b.bettype BETWEEN 2501 AND 2539 THEN 213
									WHEN b.ProductId = 23 AND b.bettype BETWEEN 2541 AND 2579 THEN 214
									WHEN b.ProductId = 23 AND b.bettype BETWEEN 2581 AND 2619 THEN 215
									WHEN b.ProductId = 23 AND b.bettype BETWEEN 2621 AND 2659 THEN 216
									WHEN b.ProductId = 23 AND b.bettype BETWEEN 2681 AND 2699 THEN 218
									WHEN b.ProductId = 28 THEN 220
									WHEN b.ProductId IN (3, 38, 40, 47, 49, 63) THEN b.MatchId
									ELSE 0
								END,
					BetTeam = CASE
									WHEN b.ProductId IN (1, 27) THEN b.BetTeam
									ELSE ''
								END,
					Hdp1 = CASE
								WHEN b.ProductId IN (1, 23, 27) THEN b.Hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.ProductId IN (1, 23, 27) THEN b.Hdp2
								ELSE 0
							END,
					OddsType = CASE
									WHEN b.ProductId = 8 THEN b.OddsType
									ELSE 0
								END,
					Odds = CASE
								WHEN b.ProductId IN (1, 3, 8, 23, 27, 28, 38, 40, 49, 63) THEN b.Odds
								ELSE 0
							END,
					MOdds = CASE
								WHEN b.ProductId IN (1, 27) THEN b.MOdds
								ELSE 0
							END,
					LiveIndicator = CASE
										WHEN b.ProductId = 1 THEN b.LiveIndicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.ProductId IN (1, 23) THEN b.LiveHomeScore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.ProductId = 1 THEN b.LiveAwayScore
										ELSE 0
									END,
					LeagueId = 0,
					MatchId = 0,
					MatchCode = '',
					Race = '',
					EventDate = b.WinLostDate,
					HomeId = 0,
					AwayId  = 0,
					BetStatus = '',
					IsNeutral = 0,
					Placing = '',
					ShowTime = '',
					BetCheck = CASE
									WHEN b.ProductId IN (1, 3, 27, 38, 63) THEN ISNULL(b.BetCheck, '')
									WHEN b.ProductId = 8 THEN ISNULL(b.ComStatus, '')
									ELSE ''
								END,
					ComStatus = '',
					TransDesc = CASE
									WHEN b.ProductId IN (3, 8, 23, 28, 38, 40, 49, 63) THEN b.transdesc
									ELSE ''
								END,
					OddsSpread = CASE
									WHEN b.ProductId = 1 THEN ISNULL(b.oddsspread, 0)
									ELSE 0
								END,
					ExtraInfo = CASE
									WHEN b.ProductId IN (1, 49) THEN ISNULL(b.ExtraInfo, '')
									ELSE ''
								END,
					CurrencyId = CASE
									WHEN b.ProductId IN (3, 63) THEN b.CurrencyId
									ELSE 0
								END,
					SiteId = CASE
								WHEN b.ProductId IN (3, 63) THEN b.SiteId
								ELSE ''
							END
				FROM #PagingData AS b
				WHERE b.WhTicket = 1
					AND b.EventType = 0
					AND b.ProductId NOT IN (69)

				-- Virtual Sports (EventType = 3)
				UPDATE b
				SET
					SportType = r.SportType,
					BetTeam = '',
					OddsType = 0,
					LiveIndicator = 0,
					LeagueId = r.LeagueID,
					MatchCode = CONVERT(NVARCHAR(50), o.RacerNum),
					Race = CONVERT(NVARCHAR(50), b.OddsId),
					EventDate = o.EventDate,
					HomeId = o.RacerID,
					AwayId = 0,
					BetStatus = '',
					IsNeutral = 0,
					Placing = o.Placing,
					ShowTime = CONVERT(VARCHAR(20), r.EventTime, 113),
					BetCheck = '',
					ComStatus = '',
					TransDesc = '',
					OddsSpread = 0,
					ExtraInfo = ''
				FROM #PagingData AS b
					INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON b.OddsId = o.Orid
					INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON o.EventID = r.EventID
				WHERE b.WhTicket = 1
					AND b.ProductID = 5
					AND b.EventType = 3

				-- Bitcoin
				UPDATE b
				SET Sporttype = m.SportType,
					EventDate = m.EndTime
				FROM #PagingData AS b
					INNER JOIN dbo.match3rd AS m WITH (NOLOCK) ON b.matchid = m.match3rdid
				WHERE b.ProductID = 69
					AND b.WhTicket = 1
			END

			-- bettrans14
			IF EXISTS (SELECT 1 FROM #PagingData WHERE WhTicket = 2)
			BEGIN
				-- Sportsbook, Number Game, Virtual Sports, Betradar Virtual Sports, Virtual Sports 3
				UPDATE b
				SET
					SportType = m.sporttype,
					Hdp2 = CASE
								WHEN b.ProductId = 3 THEN 0
								ELSE b.Hdp2
							END,
					LeagueId = m.leagueid,
					MatchCode = m.matchcode,
					Race = '',
					EventDate = CASE
									WHEN b.ProductId = 1 THEN m.GlobalShowTime
									ELSE m.eventdate
								END,
					HomeId = m.homeid,
					AwayId = m.awayid,
					BetStatus = m.betstatus,
					IsNeutral = ISNULL(m.IsNeutral, CONVERT(BIT,0)),
					Placing = '',
					ShowTime = CASE
									WHEN b.ProductId IN (5, 27, 77) THEN CONVERT(NVARCHAR(50), m.kickofftime)
									ELSE ISNULL(m.showtime, '')
								END,
					BetCheck = b.BetCheck,
					ComStatus = '',
					TransDesc = CASE
									WHEN b.ProductId IN (1, 27, 77) THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					OddsSpread = CASE
									WHEN b.ProductId = 1 THEN ISNULL(b.oddsspread, 0)
									ELSE 0
								END,
					ExtraInfo = CASE
									WHEN b.ProductId = 1 THEN ISNULL(b.ExtraInfo, '')
									ELSE ''
								END,
					BetdaqId = CASE
									WHEN b.ProductId IN (1) THEN ISNULL(b.betdaqid, -1)
									ELSE -1
								END
				FROM #PagingData AS b
					INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				WHERE b.WhTicket = 2 AND b.EventType = 1

				-- Outright
				UPDATE b
				SET
					SportType = l.sporttype,
					BetTeam = '',
					Hdp1 = 0,
					Hdp2 = 0,
					LiveIndicator = 0,
					LiveHomeScore = 0,
					LiveAwayScore = 0,
					LeagueId = o.leagueid,
					MatchId = 0,
					MatchCode = o.matchcode,
					Race = o.groupmatch,
					EventDate = o.eventdate,
					HomeId = o.teamid,
					AwayId  = 0,
					BetStatus = '',
					IsNeutral = 0,
					Placing = '',
					ShowTime = '',
					BetCheck = '',
					ComStatus = '',
					TransDesc = '',
					OddsSpread = 0,
					ExtraInfo = ''
				FROM #PagingData AS b
					INNER JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.matchid = o.orid
					INNER JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
				WHERE b.WhTicket = 2 AND b.BetType = 10

				/*
				- Mix & System Parlay	: ProductId = 1
				- Number Game			: ProductId = 3
				- Keno					: ProductId = 8
				- NG2					: ProductId = 23
				- Mix Parlay			: ProductId = 27
				- Lottery				: ProductId = 28
				- Virtual Games			: ProductId = 38
				- Table Games			: ProductId = 40
				- BBIN					: ProductId = 47
				- Leap Gaming (VS3)		: ProductId = 49
				- Sports Lottery		: ProductId = 63
				*/
				UPDATE b
				SET
					SportType = CASE
									WHEN b.ProductId = 8 THEN 202
									WHEN b.ProductId = 23 AND b.bettype BETWEEN 2501 AND 2539 THEN 213
									WHEN b.ProductId = 23 AND b.bettype BETWEEN 2541 AND 2579 THEN 214
									WHEN b.ProductId = 23 AND b.bettype BETWEEN 2581 AND 2619 THEN 215
									WHEN b.ProductId = 23 AND b.bettype BETWEEN 2621 AND 2659 THEN 216
									WHEN b.ProductId = 23 AND b.bettype BETWEEN 2681 AND 2699 THEN 218
									WHEN b.ProductId = 28 THEN 220
									WHEN b.ProductId IN (3, 38, 40, 47, 49, 63) THEN b.MatchId
									ELSE 0
								END,
					BetTeam = CASE
									WHEN b.ProductId IN (1, 27) THEN b.BetTeam
									ELSE ''
								END,
					Hdp1 = CASE
								WHEN b.ProductId IN (1, 23, 27) THEN b.Hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.ProductId IN (1, 23, 27) THEN b.Hdp2
								ELSE 0
							END,
					OddsType = CASE
									WHEN b.ProductId = 8 THEN b.OddsType
									ELSE 0
								END,
					Odds = CASE
								WHEN b.ProductId IN (1, 3, 8, 23, 27, 28, 38, 40, 49, 63) THEN b.Odds
								ELSE 0
							END,
					MOdds = CASE
								WHEN b.ProductId IN (1, 27) THEN b.MOdds
								ELSE 0
							END,
					LiveIndicator = CASE
										WHEN b.ProductId = 1 THEN b.LiveIndicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.ProductId IN (1, 23) THEN b.LiveHomeScore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.ProductId = 1 THEN b.LiveAwayScore
										ELSE 0
									END,
					LeagueId = 0,
					MatchId = 0,
					MatchCode = '',
					Race = '',
					EventDate = b.WinLostDate,
					HomeId = 0,
					AwayId  = 0,
					BetStatus = '',
					IsNeutral = 0,
					Placing = '',
					ShowTime = '',
					BetCheck = CASE
									WHEN b.ProductId IN (1, 3, 27, 38, 63) THEN ISNULL(b.BetCheck, '')
									WHEN b.ProductId = 8 THEN ISNULL(b.ComStatus, '')
									ELSE ''
								END,
					ComStatus = '',
					TransDesc = CASE
									WHEN b.ProductId IN (3, 8, 23, 28, 38, 40, 49, 63) THEN b.transdesc
									ELSE ''
								END,
					OddsSpread = CASE
									WHEN b.ProductId = 1 THEN ISNULL(b.oddsspread, 0)
									ELSE 0
								END,
					ExtraInfo = CASE
									WHEN b.ProductId IN (1, 49) THEN ISNULL(b.ExtraInfo, '')
									ELSE ''
								END,
					CurrencyId = CASE
									WHEN b.ProductId IN (3, 63) THEN b.CurrencyId
									ELSE 0
								END,
					SiteId = CASE
								WHEN b.ProductId IN (3, 63) THEN b.SiteId
								ELSE ''
							END
				FROM #PagingData AS b
				WHERE b.WhTicket = 2
					AND b.EventType = 0
					AND b.ProductId NOT IN (69)

				-- Virtual Sports (EventType = 3)
				UPDATE b
				SET
					SportType = r.SportType,
					BetTeam = '',
					OddsType = 0,
					LiveIndicator = 0,
					LeagueId = r.LeagueID,
					MatchCode = CONVERT(NVARCHAR(50), o.RacerNum),
					Race = CONVERT(NVARCHAR(50), b.OddsId),
					EventDate = o.EventDate,
					HomeId = o.RacerID,
					AwayId = 0,
					BetStatus = '',
					IsNeutral = 0,
					Placing = o.Placing,
					ShowTime = CONVERT(VARCHAR(20), r.EventTime, 113),
					BetCheck = '',
					ComStatus = '',
					TransDesc = '',
					OddsSpread = 0,
					ExtraInfo = ''
				FROM #PagingData AS b
					INNER JOIN dbo.VSOutright14 AS o WITH (NOLOCK) ON b.OddsId = o.Orid
					INNER JOIN dbo.VSRaceInfo14 AS r WITH (NOLOCK) ON o.EventID = r.EventID
				WHERE b.WhTicket = 2
					AND b.ProductID = 5
					AND b.EventType = 3

				-- Bitcoin
				UPDATE b
				SET Sporttype = m.SportType,
					EventDate = m.EndTime
				FROM #PagingData AS b
					INNER JOIN dbo.match3rd14 AS m WITH (NOLOCK) ON b.matchid = m.match3rdid
				WHERE b.ProductID = 69
					AND b.WhTicket = 2
			END

			-- Get original odds for Mix Parlay
			IF EXISTS (SELECT 1 FROM #PagingData WHERE BetType = 29 AND BetTeam = '1')
			BEGIN
				DECLARE @TmpParlayData TABLE (
					RefNo	BIGINT,
					Odds	MONEY)

				-- Mix Parlay which having at least 1 settled sub ticket
				INSERT INTO @TmpParlayData
				SELECT
					b.RefNo,
					dbo.PRODUCT(bpd.odds) AS Odds
				FROM #PagingData AS b
					INNER JOIN dbo.BetParlayDetail AS bpd WITH (NOLOCK) ON bpd.RefNo = b.RefNo
				WHERE b.BetType = 29 AND b.BetTeam = '1'
				GROUP BY b.refno

				-- Mix Parlay which having no settled sub ticket
				INSERT INTO @TmpParlayData
				SELECT
					b.RefNo,
					dbo.PRODUCT(bm.odds) AS Odds
				FROM #PagingData AS b
					INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON bm.refno = b.RefNo
				WHERE b.BetType = 29
					AND b.BetTeam = '1'
					AND NOT EXISTS (SELECT 1 FROM @TmpParlayData WHERE RefNo = b.RefNo)
				GROUP BY b.refno

				UPDATE b
				SET b.Odds = td.Odds
				FROM #PagingData AS b
					INNER JOIN @TmpParlayData AS td ON td.RefNo = b.RefNo
				WHERE b.BetType = 29 AND b.BetTeam = '1'
			END

			-- Get sub tickets
			-- Virtual Sports (bettype 1233) (bettrans)
			IF EXISTS (	SELECT 1 FROM #PagingData
						WHERE ProductId = 5
							AND EventType = 3
							AND WhTicket = 1)
			BEGIN
				INSERT INTO @BetListDetail
				SELECT
					bm.refno,
					bm.odds,
					bm.stake,
					bm.status,
					bm.apositiontaking,
					bm.mpositiontaking,
					bm.spositiontaking,
					bm.bettype,
					'' AS betteam,
					'' AS transdesc
				FROM dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN #PagingData AS b ON bm.refno = b.refno
				WHERE bm.custid = b.CustId
					AND b.ProductID = 5
					AND b.EventType = 3
					AND b.WhTicket = 1
					AND bm.bettype IN (	SELECT DISTINCT bettype FROM dbo.SportBettypeMatrix WITH (NOLOCK)
										WHERE ProductID = 5 AND EventType = 3)
			END

			-- Virtual Sports (bettype 1233) (bettrans14)
			IF EXISTS (	SELECT 1 FROM #PagingData
						WHERE ProductId = 5
							AND EventType = 3
							AND WhTicket = 2)
			BEGIN
				INSERT INTO @BetListDetail
				SELECT
					bm.refno,
					bm.odds,
					bm.stake,
					bm.status,
					bm.apositiontaking,
					bm.mpositiontaking,
					bm.spositiontaking,
					bm.bettype,
					'' AS betteam,
					'' AS transdesc
				FROM dbo.bettransm14 AS bm WITH (NOLOCK)
					INNER JOIN #PagingData AS b ON bm.refno = b.refno
				WHERE bm.custid = b.CustId
					AND b.ProductID = 5
					AND b.EventType = 3
					AND b.WhTicket = 2
					AND bm.bettype IN (	SELECT DISTINCT bettype FROM dbo.SportBettypeMatrix WITH (NOLOCK)
										WHERE ProductID = 5 AND EventType = 3)
			END
		END
	END

	SELECT
		b.TransId,
		b.RefNo,
		b.CustId,
		c.username,
		ex.currency,
		b.SportType,
		b.BetType,
		b.BetId,
		b.BetTeam,
		b.Hdp1,
		b.Hdp2,
		b.OddsType,
		b.OddsId,
		b.Odds,
		b.MOdds,
		b.Stake,
		b.Actual_Stake,
		b.Status,
		b.TransDate,
		b.WinLostDate,
		b.LiveIndicator,
		b.LiveHomeScore,
		b.LiveAwayScore,
		b.Ip,
		b.LeagueId,
		b.MatchId,
		b.MatchCode,
		b.Race,
		b.EventDate,
		b.HomeId,
		b.AwayId,
		b.BetStatus,
		b.IsNeutral,
		b.Placing,
		b.ShowTime,
		b.BetCheck,
		b.ComStatus,
		b.TransDesc,
		b.OddsSpread,
		b.ExtraInfo,
		b.BetdaqId,
		b.CurrencyId,
		b.SiteId
	FROM #PagingData AS b
		INNER JOIN dbo.custinfo AS c WITH (NOLOCK) ON b.CustId = c.custid
		INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON c.currency = ex.exchangeid
	ORDER BY TransId DESC

	SELECT * FROM @BetListDetail
	ORDER BY RefNo ASC

	DROP TABLE #PagingData
END
GO
