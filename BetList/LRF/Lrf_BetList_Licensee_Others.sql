/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_Licensee_Others]
	@AgentList			VARCHAR(MAX),
	@Username			VARCHAR(50)		= '',
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@MoveBetsDay		SMALLDATETIME,
	@Product			VARCHAR(100)		= '',
	@SportType			TINYINT			= 0,
	@BetType			SMALLINT		= 0,
	@BaseCurrency		VARCHAR(12),
	@ConvertToBaseCur	BIT				= 0,	-- Convert to base currency or not
	@StatusIdList		VARCHAR(50)		= '',
	@LiveIndicator		VARCHAR(10)		= '0,1,2',
	@PlatformType		VARCHAR(100)	= 'All',
	@CustomerClass		VARCHAR(MAX)	= 'All',
	@FullCustomerClass	VARCHAR(MAX)	= 'All',
	@OddsGroup			VARCHAR(100)	= 'All',
	@Ip					VARCHAR(45)		= '',
	@PageSize			INT				= 1000,
	@PageIndex			INT				= 1,
	@Sort				NVARCHAR(50)	= N'Transid ASC',
	@TotalRows			INT				= 0 OUTPUT,
	@SumStake			MONEY			= 0 OUTPUT,
	@SumWinLost			MONEY			= 0 OUTPUT,
	@SumLicenseeWL		MONEY			= 0 OUTPUT,
	@SumComm			MONEY			= 0 OUTPUT,
	@SumPlayerComm		MONEY			= 0 OUTPUT
AS

/*
	Created: Kos@20180613
	Task: Betting Ticket Center - Multiple Customer Bet List - Other products except SB and BA
	DB: DBEXT.bodb02
	Parameter's Explanation:
		- @StatusIdList:
			- 101: Reject
			- 102: Void (not include Abnormal Bets)
			- 103: Refund
			- 111: Draw
			- 112: Won
			- 113: Lose
			- 99: Abnormal Bets
			- 2: Delay Payout
		- @LiveIndicator:
			- 0 : Non-live
			- 1 : Live
			- 2 : Mix Non Live & Live

	Revisions:
		- 20190214@Kos: Betting Ticket Center phase 3b [Redmine: #108221]
		- 20190314@Kos: Change param @LiveIndicator from TINYINT to VARCHAR(10) [Redmine: #108717]
					- Add new param @Username, @ConvertToBaseCur
		- 20190422@Kos: Enhance performance for searching too many members [Redmine: #112313]
		- 20190426@Kos: Support base currency INH [Redmine: #112603]
		- 20190509@Kos: Show match KO time for single ticket [Redmine: #112731]
					- Return additional column EventDate DATETIME
		- 20190628@Kos: Support PH AIO 4a [Redmine: #115448]
		- 20200402@Kos: Support Table Games [Redmine: #131447]
		- 20200416@Kos: Support Indo 4D [Redmine: #130859]
		- 20200425@Kos: Support status Delay Payout [Redmine: #132629]
		- 20200502@Kos: Support Table Game Half Won Half Lose [Redmine: #133323]
		- 20200623@Kos: Integrate archive process for table VSRaceInfo [Redmine: #136285]
		- 20201231@Kos: Support Virtual Games [Redmine: #147843]
		- 20210108@Kos: Support Happy 5 Linked Games [Redmine: #147446]
		- 20210301@Kos: Add BDT and INR as base currencies [Redmine: 150375]
		- 20210311@Kos: Support Sports Lottery [Redmine: #150872]
		- 20210705@Kos: Support Happy 5 Linked Games - Soccer 5 [Redmine: #154898]
		- 20210714@Kos: Support Casino products [Redmine: #157987]
		- 20210929@Kos: Extend length to support IPv6 [Redmine: 162342]
		- 20211104@Kos: Merge Sports Lottery into Sportsbook [RedmineID: #163191]
		- 20211201@Kos: Support AdvantPlay and AdvantPlay Mini [Redmine: #158186]
		- 20211215@Kos: Hotfix - Show Casino tickets when choosing Delayed Payout [Redmine: #166109]
		- 20220110@Kos: Support TxId for 3rd products [Redmine: #166706]
		- 20220128@Kos: Support search by IP [RedmineID: #166079]
		- 20220221@Kos: Support SG Jackpot [Redmine: #167035]
		- 20220227@Kos: Support Virtual Sports 3 [Redmine: #145337]
		- 20220414@Kos: Fix issue search Void status [Redmine: #170054]
		- 20220427@Kos: Support Virtual Games result [Redmine: #170997]
		- 20220512@Kos: Support FGG [Redmine: #167897]
		- 20220527@Kos: Support MaxGame [RedmineID: #172919]
		- 20220922@Kos: Support crypto currency [Redmine: 177481]
		- 20230119@Kos: Support Jili [Redmine: 182914]
		- 20230328@Kos: Remove inactive products CB, FW, GDG [Redmine: 181424]
		- 20230404@Kos: Extend betfrom length [Redmine: #178059]
		- 20230602@Kos: Support YeeBet [Redmine: 187947]
		- 20230628@Kos: Support Saba Sports [Redmine: 183841]
					- Add new input params @LeagueGroupIds, @PlatformType, @CustomerClass, @OddsGroup
		- 20230629@Kos: Support MG-RNG [Redmine: 189988]
		- 20230803@Kos: Support Virtual Sports 3 [Redmine: 190908]
		- 20231107@Kos: Support SEAL Entertaiment [Redmine: 180648]
		- 20231110@Kos: Support WE Live Casino [Redmine: 196573]
		- 20231227@Kos: Hotfix - cannot view result [Redmine: 198900]
		- 20240129@Kos: Merge VS1, VS2, VS3 into VS [Redmine: 199523]
		- 20240207@Kos: Hotfix - No data when filtering player has Risk Level Uncategorized [RedmineID: #200913]
					- Add new input param @FullCustomerClass VARCHAR(MAX)
		- 20240411@Kos: Hotfix - show detail ticket in bettrans14 range [RedmineID: #203793]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempAg TABLE (CustId INT, Currency INT)

	DECLARE @HasError BIT = 0

	-- Get AgentList
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO @TempAg (CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SET @HasError = 1
	END CATCH

	CREATE TABLE #Data (
		TransId				BIGINT,
		RefNo				BIGINT,
		CustId				INT,
		Recommend			INT,
		Currency			SMALLINT,
		SportType			SMALLINT,
		BetType				SMALLINT,
		BetId				BIGINT,
		BetTeam				NVARCHAR(20),
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		OddsId				INT,
		OddsType			TINYINT,
		Odds				MONEY,
		MOdds				MONEY,
		OddsSpread			MONEY,
		Stake				MONEY,
		Actual_Stake		MONEY,
		WinLost				MONEY,
		LicenseeWL			MONEY,
		Comm				MONEY,
		PlayerComm			MONEY,
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		TransDate			DATETIME,
		WinLostDate			SMALLDATETIME,
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		Ip					VARCHAR(45),
		BetFrom				NVARCHAR(4),
		LeagueId			INT,
		MatchId				INT,
		MatchCode			NVARCHAR(50),
		Race				NVARCHAR(50),
		EventDate			DATETIME,
		HomeId				INT,
		AwayId				INT,
		BetStatus			NVARCHAR(50),
		IsNeutral			BIT,
		Placing				NVARCHAR(20),
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(50),
		ComStatus			NVARCHAR(20),
		TransDesc			NVARCHAR(1000),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		SiteId				VARCHAR(20),
		Product				VARCHAR(30),
		RefTable			TINYINT,
		WhTicket			TINYINT
	)

	CREATE TABLE #PagingData (
		RowNum				INT,
		TransId				BIGINT,
		RefNo				BIGINT,
		CustId				INT,
		Recommend			INT,
		Currency			SMALLINT,
		SportType			SMALLINT,
		BetType				SMALLINT,
		BetId				BIGINT,
		BetTeam				NVARCHAR(20),
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		OddsId				INT,
		OddsType			TINYINT,
		Odds				MONEY,
		MOdds				MONEY,
		OddsSpread			MONEY,
		Stake				MONEY,
		Actual_Stake		MONEY,
		WinLost				MONEY,
		LicenseeWL			MONEY,
		Comm				MONEY,
		PlayerComm			MONEY,
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		TransDate			DATETIME,
		WinLostDate			SMALLDATETIME,
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		Ip					VARCHAR(45),
		BetFrom				NVARCHAR(4),
		LeagueId			INT,
		MatchId				INT,
		MatchCode			NVARCHAR(50),
		Race				NVARCHAR(50),
		EventDate			DATETIME,
		HomeId				INT,
		AwayId				INT,
		BetStatus			NVARCHAR(50),
		IsNeutral			BIT,
		Placing				NVARCHAR(20),
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(50),
		ComStatus			NVARCHAR(20),
		TransDesc			NVARCHAR(1000),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		SiteId				VARCHAR(20),
		Product				VARCHAR(30),
		RefTable			TINYINT,
		WhTicket			TINYINT
	)

	DECLARE @TmpData TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		Status			NVARCHAR(10),
		WinLost			MONEY,
		LicenseeWL		MONEY,
		PlayerComm		MONEY,
		Comm			MONEY,
		OddsSpread		MONEY
	)

	DECLARE @Detail TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(10)
	)

	CREATE TABLE #ExchangeRate (
		ExchangeId					INT,
		FirstExchangeDateByMonth	SMALLDATETIME,
		LastExchangeDateByMonth		SMALLDATETIME,
		Rate						FLOAT
	)

	DECLARE @Yesterday SMALLDATETIME = DATEADD(DAY, DATEDIFF(DAY, 1, CURRENT_TIMESTAMP), 0)

	IF @HasError = 0 AND @StatusIdList <> '99'		-- Abnormal Bet only
	BEGIN
		-- Get child product list
		IF EXISTS (SELECT 1 FROM dbo.Lrf_f_GroupProduct() WHERE ',' + @Product + ',' LIKE '%,' + GroupProductPrefix + ',%')
		BEGIN
			DECLARE @ChildProductList VARCHAR(500)

			SELECT @ChildProductList = STRING_AGG(ProductPrefix, ',')
			FROM dbo.Lrf_f_GroupProduct()
			WHERE ',' + @Product + ',' LIKE '%,' + GroupProductPrefix + ',%'

			SET @Product = @Product + ',' + @ChildProductList
		END

		-- Get SportBettypeMatrix
		DECLARE @SportBettype TABLE (ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, RefTable TINYINT)

		DECLARE @IsTest BIT = 0

		SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

		IF @Product <> ''
		BEGIN
			INSERT INTO @SportBettype
			SELECT ProductID, BetType, EventType, RefTable
			FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @Product, @IsTest)
			WHERE (@BetType = 0
					OR BetType IN (	SELECT @BetType
									UNION SELECT Bettype FROM dbo.Lrf_f_GroupBettype() WHERE GroupTypeId = @BetType))
				AND BetType <> 914
		END

		DECLARE @TempToDate	SMALLDATETIME,
			@TempFromDate	SMALLDATETIME

		DECLARE @TempCust TABLE (CustId INT PRIMARY KEY, CustomerClass SMALLINT)

		IF @Username IS NOT NULL AND @Username <> ''
		BEGIN
			INSERT INTO @TempCust (CustId, CustomerClass)
			SELECT
				c.custid,
				ci.CustomerClass
			FROM dbo.Customer AS c WITH (NOLOCK)
				INNER JOIN @TempAg AS a ON c.recommend = a.CustId
				LEFT JOIN dbo.custInfo AS ci WITH (NOLOCK) ON ci.custid = c.custid
			WHERE c.roleid = 1
				AND (c.username LIKE + '%' + @Username + '%'
					OR c.username2 LIKE + '%$%' + @Username + '%')
				AND (@OddsGroup = 'All'
					OR ',' + @OddsGroup + ',' LIKE + '%,' + c.ugroup + ',%')

			IF @CustomerClass <> 'All'
			BEGIN
				DELETE @TempCust
				WHERE 1 <> CASE
								WHEN ',' + @CustomerClass + ',' LIKE '%,0,%' AND CustomerClass IS NULL THEN 1
								WHEN ',' + @CustomerClass + ',' LIKE '%,0,%'
									AND ',' + @FullCustomerClass + ',' NOT LIKE '%,' + CONVERT(VARCHAR(6), CustomerClass) + ',%' THEN 1
								WHEN ',' + @CustomerClass + ',' LIKE '%,' + CONVERT(VARCHAR(6), CustomerClass) + ',%' THEN 1
								ELSE 0
							END
			END
		END

		DECLARE @NumOfMem	INT = 0
 
		SELECT @NumOfMem = COUNT(1) FROM @TempCust

		-- Bettrans range
		IF @ToDate > @MoveBetsDay
		BEGIN
			IF @FromDate <= @MoveBetsDay
				SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
			ELSE
				SET @TempFromDate = @FromDate

			IF @Username IS NULL OR @Username = '' OR @NumOfMem > 5000		-- Licensee level (not input username of number of searched member > 5000)
			BEGIN
				IF @SportType = 0
				BEGIN
					INSERT INTO #Data (
						TransId,
						RefNo,
						CustId,
						Recommend,
						Currency,
						BetType,
						BetId,
						BetTeam,
						Hdp1,
						Hdp2,
						OddsId,
						OddsType,
						Odds,
						MOdds,
						OddsSpread,
						Stake,
						Actual_Stake,
						WinLost,
						LicenseeWL,
						Comm,
						PlayerComm,
						Status,
						TransDate,
						WinLostDate,
						LiveIndicator,
						LiveHomeScore,
						LiveAwayScore,
						Ip,
						BetFrom,
						MatchId,
						BetCheck,
						ComStatus,
						TransDesc,
						BetdaqId,
						ExtraInfo,
						WhTicket)
					SELECT
						b.transid,
						b.refno,
						b.custid,
						b.recommend,
						b.currency,
						b.bettype,
						b.betid,
						b.betteam,
						b.hdp1,
						b.hdp2,
						b.oddsid,
						b.oddstype,
						b.odds,
						b.modds,
						b.oddsspread,
						b.stake,
						b.actual_stake,
						(b.winlost - b.actual_stake) AS WinLost,
						- (b.winlost - b.actual_stake) AS LiceseeWL,
						b.comm,
						b.playercomm,
						b.status,
						b.transdate,
						b.winlostdate,
						b.liveindicator,
						b.livehomescore,
						b.liveawayscore,
						b.ip,
						b.betfrom,
						b.matchid,
						b.betcheck,
						b.comstatus,
						b.transdesc,
						b.betdaqid,
						b.ExtraInfo,
						1 AS WhTicket
					FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_Recommend)
						INNER JOIN @TempAg AS a ON b.recommend = a.CustId
						INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
					WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
						AND (',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
							OR (b.winlostdate >= @Yesterday AND s.RefTable IN (1, 2)))		-- don't care status of casino's summary rows if >= yesterday
						AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'
				END
				ELSE
				BEGIN
					INSERT INTO #Data (
						TransId,
						RefNo,
						CustId,
						Recommend,
						Currency,
						BetType,
						BetId,
						BetTeam,
						Hdp1,
						Hdp2,
						OddsId,
						OddsType,
						Odds,
						MOdds,
						OddsSpread,
						Stake,
						Actual_Stake,
						WinLost,
						LicenseeWL,
						Comm,
						PlayerComm,
						Status,
						TransDate,
						WinLostDate,
						LiveIndicator,
						LiveHomeScore,
						LiveAwayScore,
						Ip,
						BetFrom,
						MatchId,
						BetCheck,
						ComStatus,
						TransDesc,
						BetdaqId,
						ExtraInfo,
						WhTicket)
					SELECT
						b.transid,
						b.refno,
						b.custid,
						b.recommend,
						b.currency,
						b.bettype,
						b.betid,
						b.betteam,
						b.hdp1,
						b.hdp2,
						b.oddsid,
						b.oddstype,
						b.odds,
						b.modds,
						b.oddsspread,
						b.stake,
						b.actual_stake,
						(b.winlost - b.actual_stake) AS WinLost,
						- (b.winlost - b.actual_stake) AS LiceseeWL,
						b.comm,
						b.playercomm,
						b.status,
						b.transdate,
						b.winlostdate,
						b.liveindicator,
						b.livehomescore,
						b.liveawayscore,
						b.ip,
						b.betfrom,
						b.matchid,
						b.betcheck,
						b.comstatus,
						b.transdesc,
						b.betdaqid,
						b.ExtraInfo,
						1 AS WhTicket
					FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_Recommend)
						INNER JOIN @TempAg AS a ON b.recommend = a.CustId
						INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
						LEFT JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1
						LEFT JOIN dbo.VSOutright AS vo WITH (NOLOCK) ON b.oddsid = vo.Orid AND s.EventType = 3 AND s.ProductID = 5
						LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON vr.EventID = vo.EventID AND s.EventType = 3 AND s.ProductID = 5
					WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
						AND (',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
							OR (b.winlostdate >= @Yesterday AND s.RefTable IN (1, 2)))		-- don't care status of casino's summary rows if >= yesterday
						AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'
						AND ((s.EventType = 1 AND m.sporttype = @SportType)
							OR (s.EventType = 3 AND s.ProductID = 5 AND vr.sporttype = @SportType)
							OR (s.EventType = 0 AND s.ProductID IN (3, 8, 28, 38, 40, 43, 49, 63) AND b.matchid = @SportType)
							OR (s.EventType = 0 AND s.ProductID = 27 AND b.oddsid = @SportType))
				END
			END
			ELSE		-- Customer level
			BEGIN
				IF @SportType = 0
				BEGIN
					INSERT INTO #Data (
						TransId,
						RefNo,
						CustId,
						Recommend,
						Currency,
						BetType,
						BetId,
						BetTeam,
						Hdp1,
						Hdp2,
						OddsId,
						OddsType,
						Odds,
						MOdds,
						OddsSpread,
						Stake,
						Actual_Stake,
						WinLost,
						LicenseeWL,
						Comm,
						PlayerComm,
						Status,
						TransDate,
						WinLostDate,
						LiveIndicator,
						LiveHomeScore,
						LiveAwayScore,
						Ip,
						BetFrom,
						MatchId,
						BetCheck,
						ComStatus,
						TransDesc,
						BetdaqId,
						ExtraInfo,
						WhTicket)
					SELECT
						b.transid,
						b.refno,
						b.custid,
						b.recommend,
						b.currency,
						b.bettype,
						b.betid,
						b.betteam,
						b.hdp1,
						b.hdp2,
						b.oddsid,
						b.oddstype,
						b.odds,
						b.modds,
						b.oddsspread,
						b.stake,
						b.actual_stake,
						(b.winlost - b.actual_stake) AS WinLost,
						- (b.winlost - b.actual_stake) AS LiceseeWL,
						b.comm,
						b.playercomm,
						b.status,
						b.transdate,
						b.winlostdate,
						b.liveindicator,
						b.livehomescore,
						b.liveawayscore,
						b.ip,
						b.betfrom,
						b.matchid,
						b.betcheck,
						b.comstatus,
						b.transdesc,
						b.betdaqid,
						b.ExtraInfo,
						1 AS WhTicket
					FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_CustId)
						INNER JOIN @TempCust AS c ON b.custid = c.CustId
						INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
					WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
						AND (',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
							OR (b.winlostdate >= @Yesterday AND s.RefTable IN (1, 2)))		-- don't care status of casino's summary rows if >= yesterday
						AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'
				END
				ELSE
				BEGIN
					INSERT INTO #Data (
						TransId,
						RefNo,
						CustId,
						Recommend,
						Currency,
						BetType,
						BetId,
						BetTeam,
						Hdp1,
						Hdp2,
						OddsId,
						OddsType,
						Odds,
						MOdds,
						OddsSpread,
						Stake,
						Actual_Stake,
						WinLost,
						LicenseeWL,
						Comm,
						PlayerComm,
						Status,
						TransDate,
						WinLostDate,
						LiveIndicator,
						LiveHomeScore,
						LiveAwayScore,
						Ip,
						BetFrom,
						MatchId,
						BetCheck,
						ComStatus,
						TransDesc,
						BetdaqId,
						ExtraInfo,
						WhTicket)
					SELECT
						b.transid,
						b.refno,
						b.custid,
						b.recommend,
						b.currency,
						b.bettype,
						b.betid,
						b.betteam,
						b.hdp1,
						b.hdp2,
						b.oddsid,
						b.oddstype,
						b.odds,
						b.modds,
						b.oddsspread,
						b.stake,
						b.actual_stake,
						(b.winlost - b.actual_stake) AS WinLost,
						- (b.winlost - b.actual_stake) AS LiceseeWL,
						b.comm,
						b.playercomm,
						b.status,
						b.transdate,
						b.winlostdate,
						b.liveindicator,
						b.livehomescore,
						b.liveawayscore,
						b.ip,
						b.betfrom,
						b.matchid,
						b.betcheck,
						b.comstatus,
						b.transdesc,
						b.betdaqid,
						b.ExtraInfo,
						1 AS WhTicket
					FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_CustId)
						INNER JOIN @TempCust AS c ON b.custid = c.CustId
						INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
						LEFT JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1
						LEFT JOIN dbo.VSOutright AS vo WITH (NOLOCK) ON b.oddsid = vo.Orid AND s.EventType = 3 AND s.ProductID = 5
						LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON vr.EventID = vo.EventID AND s.EventType = 3 AND s.ProductID = 5
					WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
						AND (',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
							OR (b.winlostdate >= @Yesterday AND s.RefTable IN (1, 2)))		-- don't care status of casino's summary rows if >= yesterday
						AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'
						AND ((s.EventType = 1 AND m.sporttype = @SportType)
							OR (s.EventType = 3 AND s.ProductID = 5 AND vr.sporttype = @SportType)
							OR (s.EventType = 0 AND s.ProductID IN (3, 8, 28, 38, 40, 43, 49, 63) AND b.matchid = @SportType)
							OR (s.EventType = 0 AND s.ProductID = 27 AND b.oddsid = @SportType))
				END
			END
		END

		-- Bettrans14 range
		IF @FromDate <= @MoveBetsDay
		BEGIN
			IF @ToDate > @MoveBetsDay
				SET @TempToDate = @MoveBetsDay
			ELSE
				SET @TempToDate = @ToDate

			IF @Username IS NULL OR @Username = '' OR @NumOfMem > 5000		-- Licensee level (not input username of number of searched member > 5000)
			BEGIN
				IF @SportType = 0
				BEGIN
					INSERT INTO #Data (
						TransId,
						RefNo,
						CustId,
						Recommend,
						Currency,
						BetType,
						BetId,
						BetTeam,
						Hdp1,
						Hdp2,
						OddsId,
						OddsType,
						Odds,
						MOdds,
						OddsSpread,
						Stake,
						Actual_Stake,
						WinLost,
						LicenseeWL,
						Comm,
						PlayerComm,
						Status,
						TransDate,
						WinLostDate,
						LiveIndicator,
						LiveHomeScore,
						LiveAwayScore,
						Ip,
						BetFrom,
						MatchId,
						BetCheck,
						ComStatus,
						TransDesc,
						BetdaqId,
						ExtraInfo,
						WhTicket)
					SELECT
						b.transid,
						b.refno,
						b.custid,
						b.recommend,
						b.currency,
						b.bettype,
						b.betid,
						b.betteam,
						b.hdp1,
						b.hdp2,
						b.oddsid,
						b.oddstype,
						b.odds,
						b.modds,
						b.oddsspread,
						b.stake,
						b.actual_stake,
						(b.winlost - b.actual_stake) AS WinLost,
						- (b.winlost - b.actual_stake) AS LiceseeWL,
						b.comm,
						b.playercomm,
						b.status,
						b.transdate,
						b.winlostdate,
						b.liveindicator,
						b.livehomescore,
						b.liveawayscore,
						b.ip,
						b.betfrom,
						b.matchid,
						b.betcheck,
						b.comstatus,
						b.transdesc,
						b.betdaqid,
						b.ExtraInfo,
						2 AS WhTicket
					FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_Recommend)
						INNER JOIN @TempAg AS a ON b.recommend = a.CustId
						INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
					WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
						AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
						AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'
				END
				ELSE
				BEGIN
					INSERT INTO #Data (
						TransId,
						RefNo,
						CustId,
						Recommend,
						Currency,
						BetType,
						BetId,
						BetTeam,
						Hdp1,
						Hdp2,
						OddsId,
						OddsType,
						Odds,
						MOdds,
						OddsSpread,
						Stake,
						Actual_Stake,
						WinLost,
						LicenseeWL,
						Comm,
						PlayerComm,
						Status,
						TransDate,
						WinLostDate,
						LiveIndicator,
						LiveHomeScore,
						LiveAwayScore,
						Ip,
						BetFrom,
						MatchId,
						BetCheck,
						ComStatus,
						TransDesc,
						BetdaqId,
						ExtraInfo,
						WhTicket)
					SELECT
						b.transid,
						b.refno,
						b.custid,
						b.recommend,
						b.currency,
						b.bettype,
						b.betid,
						b.betteam,
						b.hdp1,
						b.hdp2,
						b.oddsid,
						b.oddstype,
						b.odds,
						b.modds,
						b.oddsspread,
						b.stake,
						b.actual_stake,
						(b.winlost - b.actual_stake) AS WinLost,
						- (b.winlost - b.actual_stake) AS LiceseeWL,
						b.comm,
						b.playercomm,
						b.status,
						b.transdate,
						b.winlostdate,
						b.liveindicator,
						b.livehomescore,
						b.liveawayscore,
						b.ip,
						b.betfrom,
						b.matchid,
						b.betcheck,
						b.comstatus,
						b.transdesc,
						b.betdaqid,
						b.ExtraInfo,
						2 AS WhTicket
					FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_Recommend)
						INNER JOIN @TempAg AS a ON b.recommend = a.CustId
						INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
						LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1
						LEFT JOIN dbo.VSOutright14 AS vo WITH (NOLOCK) ON b.oddsid = vo.Orid AND s.EventType = 3 AND s.ProductID = 5
						LEFT JOIN dbo.VSRaceInfo14 AS vr WITH (NOLOCK) ON vr.EventID = vo.EventID AND s.EventType = 3 AND s.ProductID = 5
					WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
						AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
						AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'
						AND ((s.EventType = 1 AND m.sporttype = @SportType)
							OR (s.EventType = 3 AND s.ProductID = 5 AND vr.sporttype = @SportType)
							OR (s.EventType = 0 AND s.ProductID IN (3, 8, 28, 38, 40, 43, 49, 63) AND b.matchid = @SportType)
							OR (s.EventType = 0 AND s.ProductID = 27 AND b.oddsid = @SportType))
				END
			END
			ELSE		-- Customer level
			BEGIN
				IF @SportType = 0
				BEGIN
					INSERT INTO #Data (
						TransId,
						RefNo,
						CustId,
						Recommend,
						Currency,
						BetType,
						BetId,
						BetTeam,
						Hdp1,
						Hdp2,
						OddsId,
						OddsType,
						Odds,
						MOdds,
						OddsSpread,
						Stake,
						Actual_Stake,
						WinLost,
						LicenseeWL,
						Comm,
						PlayerComm,
						Status,
						TransDate,
						WinLostDate,
						LiveIndicator,
						LiveHomeScore,
						LiveAwayScore,
						Ip,
						BetFrom,
						MatchId,
						BetCheck,
						ComStatus,
						TransDesc,
						BetdaqId,
						ExtraInfo,
						WhTicket)
					SELECT
						b.transid,
						b.refno,
						b.custid,
						b.recommend,
						b.currency,
						b.bettype,
						b.betid,
						b.betteam,
						b.hdp1,
						b.hdp2,
						b.oddsid,
						b.oddstype,
						b.odds,
						b.modds,
						b.oddsspread,
						b.stake,
						b.actual_stake,
						(b.winlost - b.actual_stake) AS WinLost,
						- (b.winlost - b.actual_stake) AS LiceseeWL,
						b.comm,
						b.playercomm,
						b.status,
						b.transdate,
						b.winlostdate,
						b.liveindicator,
						b.livehomescore,
						b.liveawayscore,
						b.ip,
						b.betfrom,
						b.matchid,
						b.betcheck,
						b.comstatus,
						b.transdesc,
						b.betdaqid,
						b.ExtraInfo,
						2 AS WhTicket
					FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_CustId)
						INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
						CROSS APPLY ( SELECT CustId FROM @TempCust ) AS t
					WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
						AND t.CustId = b.custid
						AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
						AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'
				END
				ELSE
				BEGIN
					INSERT INTO #Data (
						TransId,
						RefNo,
						CustId,
						Recommend,
						Currency,
						BetType,
						BetId,
						BetTeam,
						Hdp1,
						Hdp2,
						OddsId,
						OddsType,
						Odds,
						MOdds,
						OddsSpread,
						Stake,
						Actual_Stake,
						WinLost,
						LicenseeWL,
						Comm,
						PlayerComm,
						Status,
						TransDate,
						WinLostDate,
						LiveIndicator,
						LiveHomeScore,
						LiveAwayScore,
						Ip,
						BetFrom,
						MatchId,
						BetCheck,
						ComStatus,
						TransDesc,
						BetdaqId,
						ExtraInfo,
						WhTicket)
					SELECT
						b.transid,
						b.refno,
						b.custid,
						b.recommend,
						b.currency,
						b.bettype,
						b.betid,
						b.betteam,
						b.hdp1,
						b.hdp2,
						b.oddsid,
						b.oddstype,
						b.odds,
						b.modds,
						b.oddsspread,
						b.stake,
						b.actual_stake,
						(b.winlost - b.actual_stake) AS WinLost,
						- (b.winlost - b.actual_stake) AS LiceseeWL,
						b.comm,
						b.playercomm,
						b.status,
						b.transdate,
						b.winlostdate,
						b.liveindicator,
						b.livehomescore,
						b.liveawayscore,
						b.ip,
						b.betfrom,
						b.matchid,
						b.betcheck,
						b.comstatus,
						b.transdesc,
						b.betdaqid,
						b.ExtraInfo,
						2 AS WhTicket
					FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_CustId)
						INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
						LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1
						LEFT JOIN dbo.VSOutright14 AS vo WITH (NOLOCK) ON b.oddsid = vo.Orid AND s.EventType = 3 AND s.ProductID = 5
						LEFT JOIN dbo.VSRaceInfo14 AS vr WITH (NOLOCK) ON vr.EventID = vo.EventID AND s.EventType = 3 AND s.ProductID = 5
						CROSS APPLY ( SELECT CustId FROM @TempCust ) AS t
					WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
						AND t.CustId = b.custid
						AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
						AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'
						AND ((s.EventType = 1 AND m.sporttype = @SportType)
							OR (s.EventType = 3 AND s.ProductID = 5 AND vr.sporttype = @SportType)
							OR (s.EventType = 0 AND s.ProductID IN (3, 8, 28, 38, 40, 43, 49, 63) AND b.matchid = @SportType)
							OR (s.EventType = 0 AND s.ProductID = 27 AND b.oddsid = @SportType))
				END
			END
		END
		
		IF ISNULL(@Ip, '') <> ''
		BEGIN
			DELETE #Data
			WHERE Ip <> @Ip
		END

		IF @PlatformType <> 'All'
		BEGIN
			DELETE #Data
			WHERE BetFrom NOT IN (SELECT betfrom FROM dbo.Lrf_f_BetFromType_Sel(@PlatformType))
		END

		IF EXISTS (SELECT TOP(1) 1 FROM #Data)
		BEGIN
			-- Get Sport/Bettype info
			UPDATE b
			SET
				Product = CASE
							WHEN s.ProductID = 6 THEN 'OneRNG'							-- RNG Casino
							WHEN s.ProductID = 8 THEN 'Keno'
							WHEN s.ProductID = 21 THEN 'AllBet'
							WHEN s.ProductID = 22 THEN 'VB'								-- Macau Games
							WHEN s.ProductID = 28 THEN 'Lottery'
							WHEN s.ProductID = 32 THEN 'PP'								-- Pragmatic Play Casino
							WHEN s.ProductID = 34 THEN 'CC'								-- Card Club
							WHEN s.ProductID = 36 THEN 'SG'								-- Spadegaming
							WHEN s.ProductID = 38 THEN 'VRG'							-- Virtual Games
							WHEN s.ProductID = 39 THEN 'SAG'							-- SA Gaming
							WHEN s.ProductID = 40 THEN 'TG'								-- Table Games
							WHEN s.ProductID = 42 THEN 'SBC'							-- Saba.club
							WHEN s.ProductID = 43 THEN 'I4D'							-- Indo 4D
							WHEN s.ProductID = 45 THEN 'SXG'							-- Sexy Gaming
							WHEN s.ProductID = 49 THEN 'VS3'							-- Virtual Sports 3
							WHEN s.ProductID = 51 THEN 'WM'								-- WM Live Casino
							WHEN s.ProductID = 55 THEN 'PGS'							-- PG Soft
							WHEN s.ProductID = 56 THEN 'JK'								-- Joker
							WHEN s.ProductID = 57 THEN 'BG'								-- Big Gaming
							WHEN s.ProductID = 60 THEN 'MXG'							-- MaxGame
							WHEN s.ProductID = 61 THEN 'HB'								-- Habanero
							WHEN s.ProductID = 62 THEN 'CG'								-- CG
							WHEN s.ProductID = 66 THEN 'VGA'							-- Vgaming
							WHEN s.ProductID = 67 THEN 'AP'								-- AdvantPlay
							WHEN s.ProductID = 68 THEN 'APM'							-- AdvantPlay Mini
							WHEN s.ProductID = 70 THEN 'FGGL'							-- FGG
							WHEN s.ProductId = 72 THEN 'SEA'							-- SEAL Entertainment
							WHEN s.ProductID = 73 THEN 'MGRNG'							-- MG-RNG
							WHEN s.ProductID = 75 THEN 'JIG'							-- Jili
							WHEN s.ProductID = 76 THEN 'YB'								-- YeeBet
							WHEN s.ProductID = 77 THEN 'LG'								-- Virtual Sports 3
							WHEN s.EventType = 0 AND s.ProductID = 3 THEN 'H5LG'		-- Happy 5 Linked Games (Number Game)
							WHEN s.EventType = 0 AND s.ProductID = 27 THEN 'ParlayVS2'	-- Betradar Virtual Sports Parlay
							WHEN s.EventType = 1 AND s.ProductID = 3 THEN 'NG'			-- Number Game
							WHEN s.EventType = 1 AND s.ProductID = 5 THEN 'VS'			-- Virtual Sports Sportsbook
							WHEN s.EventType = 1 AND s.ProductID = 27 THEN 'VS2'		-- Betradar Virtual Sports
							WHEN s.EventType = 3 AND s.ProductID = 5 THEN 'VR'			-- Virtual Sports Racing
							ELSE 'Unknown'
						END,
				RefTable = s.RefTable
			FROM #Data AS b
				INNER JOIN @SportBetType AS s ON b.bettype = s.bettype
		END

		IF @Username IS NULL OR @Username = ''
		BEGIN
			INSERT INTO @TempCust (CustId, CustomerClass)
			SELECT DISTINCT
				c.custid,
				ci.CustomerClass
			FROM dbo.Customer AS c WITH (NOLOCK)
				INNER JOIN dbo.custInfo AS ci WITH (NOLOCK) ON ci.custid = c.custid
			WHERE c.roleid = 1
				AND (@OddsGroup = 'All'
					OR ',' + @OddsGroup + ',' LIKE + '%,' + c.ugroup + ',%')
				AND EXISTS (SELECT 1 FROM #Data WHERE CustId = c.CustId)

			IF @CustomerClass <> 'All'
			BEGIN
				DELETE @TempCust
				WHERE 1 <> CASE
								WHEN ',' + @CustomerClass + ',' LIKE '%,0,%' AND CustomerClass IS NULL THEN 1
								WHEN ',' + @CustomerClass + ',' LIKE '%,0,%'
									AND ',' + @FullCustomerClass + ',' NOT LIKE '%,' + CONVERT(VARCHAR(6), CustomerClass) + ',%' THEN 1
								WHEN ',' + @CustomerClass + ',' LIKE '%,' + CONVERT(VARCHAR(6), CustomerClass) + ',%' THEN 1
								ELSE 0
							END
			END
		END

		IF @Username IS NULL OR @Username = '' OR @NumOfMem <= 5000
		BEGIN
			DELETE b
			FROM #Data AS b
			WHERE NOT EXISTS (SELECT 1 FROM @TempCust WHERE CustId = b.CustId)
				OR NOT EXISTS (SELECT 1 FROM @TempAg WHERE CustId = b.Recommend AND Currency = b.Currency)
				OR b.BetType = 913
		END
		ELSE
		BEGIN
			DELETE b
			FROM #Data AS b
			WHERE NOT EXISTS (SELECT 1 FROM @TempCust WHERE CustId = b.CustId)
				OR NOT EXISTS (SELECT 1 FROM @TempAg WHERE CustId = b.Recommend AND Currency = b.Currency)
				OR b.BetType = 913
		END

		-- Get yesterday and today settled bettransRnG/bettransLC tickets
		IF ',' + @StatusIdList + ',' LIKE '%,111,%'
			OR ',' + @StatusIdList + ',' LIKE '%,112,%'
			OR ',' + @StatusIdList + ',' LIKE '%,113,%'
		BEGIN
			IF EXISTS (SELECT 1 FROM #Data WHERE RefTable = 1 AND WinLostDate >= @Yesterday)		-- bettransRnG
			BEGIN
				INSERT INTO @TmpData
				SELECT
					c.TransId AS RefNo,
					CASE
						WHEN Product IN ('OneRNG', 'PP', 'SBC', 'VGA', 'SG') THEN ISNULL(AVG(CASE WHEN brng.statusID IN (111, 112, 113)
							THEN brng.ContributionRate END), 0)
						ELSE 0
					END AS Odds,
					SUM(brng.stake) AS Stake,
					SUM(brng.actual_stake) AS Actual_Stake,
					CASE
						WHEN SUM(brng.winlost - brng.actual_stake) > 0 THEN 'Won'
						WHEN SUM(brng.winlost - brng.actual_stake) < 0 THEN 'Lose'
						ELSE 'Draw'
					END AS Status,
					SUM(brng.winlost - brng.actual_stake) AS WinLost,
					- SUM(brng.winlost - brng.actual_stake) AS LicenseeWL,
					SUM(brng.playercomm) AS Commission,
					SUM(brng.comm) AS Comm,
					CASE
						WHEN c.Product IN ('OneRNG', 'PP', 'SBC', 'VGA', 'SG') THEN SUM(ISNULL(brng.BetStake, 0))
						ELSE 0
					END AS OddsSpread
				FROM #Data AS c
					INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = c.TransId
				WHERE c.RefTable = 1
					AND c.WinLostDate >= @Yesterday
					AND brng.statusID NOT IN (0, 1)
				GROUP BY
					c.TransId,
					c.Product
			END

			IF EXISTS (SELECT 1 FROM #Data WHERE RefTable = 2 AND WinLostDate >= @Yesterday)				-- bettransLC
			BEGIN
				INSERT INTO @TmpData
				SELECT
					c.TransId AS RefNo,
					0 AS Odds,
					SUM(blc.stake) AS Stake,
					SUM(blc.actual_stake) AS Actual_Stake,
					CASE
						WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
						WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
						ELSE 'Draw'
					END AS Status,
					SUM(blc.winlost - blc.actual_stake) AS WinLost,
					- SUM(blc.winlost - blc.actual_stake) AS LicenseeWL,
					SUM(blc.playercomm) AS Commission,
					SUM(blc.comm) AS Comm,
					0 AS OddsSpread
				FROM #Data AS c
					INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = c.TransId
				WHERE c.RefTable = 2
					AND c.WinLostDate >= @Yesterday
					AND blc.statusID NOT IN (0, 1)
				GROUP BY
					c.TransId,
					c.Product
			END

			DELETE FROM @TmpData
			WHERE (Status = 'Draw' AND ',' + @StatusIdList + ',' NOT LIKE '%,111,%')
				OR (Status = 'Won' AND ',' + @StatusIdList + ',' NOT LIKE '%,112,%')
				OR (Status = 'Lose' AND ',' + @StatusIdList + ',' NOT LIKE '%,113,%')
		END

		DELETE b
		FROM #Data AS b
		WHERE b.RefTable IN (1, 2)
			AND b.Winlostdate >= @Yesterday
			AND NOT EXISTS (SELECT 1 FROM @TmpData WHERE RefNo = b.TransId)

		UPDATE b
		SET
			Odds = CASE
						WHEN b.Product IN ('OneRNG', 'PP', 'SBC', 'VGA', 'SG') AND x.Odds IS NOT NULL THEN x.Odds
						ELSE b.Odds
					END,
			OddsSpread = CASE
							WHEN b.Product IN ('OneRNG', 'PP', 'SBC', 'VGA', 'SG') AND x.OddsSpread IS NOT NULL THEN x.OddsSpread
							ELSE b.OddsSpread
						END,
			Stake = CASE
						WHEN b.RefTable IN (1, 2) AND x.Stake IS NOT NULL THEN x.Stake
						ELSE b.stake
					END,
			Actual_Stake = CASE
							WHEN b.RefTable IN (1, 2) AND x.Actual_Stake IS NOT NULL THEN x.Actual_Stake
							ELSE b.actual_stake
						END,
			Status = CASE
						WHEN b.RefTable IN (1, 2) AND x.Status IS NOT NULL THEN x.Status
						ELSE b.status
					END,
			WinLost = CASE
							WHEN b.RefTable IN (1, 2) AND x.WinLost IS NOT NULL THEN x.WinLost
							ELSE b.WinLost
						END,
			LicenseeWL = CASE
							WHEN b.RefTable IN (1, 2) AND x.LicenseeWL IS NOT NULL THEN x.LicenseeWL
							ELSE b.LicenseeWL
						END,
			PlayerComm = CASE
							WHEN b.RefTable IN (1, 2) AND x.PlayerComm IS NOT NULL THEN x.PlayerComm
							ELSE b.PlayerComm
						END,
			Comm = CASE
						WHEN b.RefTable IN (1, 2) AND x.Comm IS NOT NULL THEN x.Comm
						ELSE b.Comm
					END
		FROM #Data AS b
			LEFT JOIN @TmpData AS x
				ON b.RefTable IN (1, 2)
				AND b.Winlostdate >= @Yesterday
				AND x.RefNo = b.transid
		WHERE b.WhTicket = 1

		IF EXISTS (SELECT TOP(1) 1 FROM #Data)
		BEGIN
			DECLARE @ExFromDate SMALLDATETIME,
				@ExToDate SMALLDATETIME

			SELECT
				@ExFromDate = MIN(WinLostDate),
				@ExToDate = MAX(WinLostDate)
			FROM #Data

			-- Get exchange rate
			INSERT INTO #ExchangeRate
			SELECT
				e.ExchangeId,
				e.FromDate,
				e.ToDate,
				e.Rate
			FROM dbo.Lrf_f_GetExchangeRate(@ExFromDate, @ExToDate, @BaseCurrency, '') AS e
			WHERE EXISTS (SELECT 1 FROM #Data
						WHERE Currency = e.ExchangeId
							AND WinLostDate BETWEEN e.FromDate AND e.ToDate)

			-- Return data
			SELECT
				@TotalRows		= COUNT(b.TransId),
				@SumStake		= SUM(CASE
										WHEN b.RefTable IN (1, 2) AND x.Stake IS NOT NULL THEN x.Stake
										ELSE b.Stake
									END * ISNULL(e.Rate, 1)),
				@SumWinlost		= SUM(CASE
										WHEN b.RefTable IN (1, 2) AND x.WinLost IS NOT NULL THEN x.WinLost
										ELSE b.WinLost
									END * ISNULL(e.Rate, 1)),
				@SumLicenseeWL	= SUM(CASE
										WHEN b.RefTable IN (1, 2) AND x.LicenseeWL IS NOT NULL THEN x.LicenseeWL
										ELSE b.LicenseeWL
									END * ISNULL(e.Rate, 1)),
				@SumComm		= SUM(CASE
										WHEN b.RefTable IN (1, 2) AND x.Comm IS NOT NULL THEN x.Comm
										ELSE b.Comm
									END * ISNULL(e.Rate, 1)),
				@SumPlayerComm	= SUM(CASE
										WHEN b.RefTable IN (1, 2) AND x.PlayerComm IS NOT NULL THEN x.PlayerComm
										ELSE b.PlayerComm
									END * ISNULL(e.Rate, 1))
			FROM #Data AS b
				LEFT JOIN @TmpData AS x
					ON b.RefTable IN (1, 2)
					AND b.WinLostDate >= @Yesterday
					AND x.RefNo = b.transid
				LEFT JOIN #ExchangeRate AS e
					ON e.ExchangeId = b.Currency
					AND b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth

			IF @ConvertToBaseCur = 0
			BEGIN
				DELETE FROM #ExchangeRate
			END

			-- Get sort text
			IF @ConvertToBaseCur = 1
				AND (@Sort LIKE '%Stake%' OR @Sort LIKE '%WinLost%' OR @Sort LIKE '%LicenseeWL%')
			BEGIN
				DECLARE @CharIndex TINYINT

				SELECT @CharIndex = CHARINDEX(' ', @Sort, 1)

				SELECT @Sort = SUBSTRING(@Sort, 0, @CharIndex) + ' * ISNULL(e.Rate, 1)' + SUBSTRING(@Sort, @CharIndex, LEN(@Sort))
			END
		END

		IF @PageSize < @TotalRows
		BEGIN
			-- Paging
			DECLARE @RowStart INT,
				@RowEnd INT

			SELECT @PageIndex = @PageIndex - 1,
				@RowStart = @PageSize * @PageIndex + 1,
				@RowEnd = @RowStart + @PageSize - 1

			DECLARE @Sql NVARCHAR(MAX)

			SET @Sql = 
				N'SELECT a.*
				FROM
					(
						SELECT
							ROW_NUMBER() OVER (ORDER BY ' + @Sort + N') AS RowNum,
							d.*
						FROM #Data AS d' +
						CASE
							WHEN @Sort LIKE '%e.Rate%' THEN N'
							LEFT JOIN #ExchangeRate AS e
								ON e.ExchangeId = d.Currency
									AND d.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth'
							ELSE N' '
						END + N'
					) AS a
				WHERE a.RowNum BETWEEN @RowStart AND @RowEnd
				ORDER BY a.RowNum'

			INSERT INTO #PagingData
			EXEC sp_executesql @Sql, N'@RowStart INT, @RowEnd INT', @RowStart, @RowEnd;

			-- bettrans
			IF EXISTS (SELECT TOP(1) 1 FROM #PagingData WHERE WhTicket = 1)
			BEGIN
				UPDATE b
				SET
					SportType = CASE
									WHEN b.Product IN ('Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VRG', 'TG', 'SBC', 'I4D', 'SXG', 'SAG', 'PGS', 'JK',
										'H5LG', 'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM', 'VS3', 'FGGL', 'MXG', 'JIG', 'YB', 'MGRNG', 'SEA') THEN b.MatchId
									WHEN b.Product = 'AllBet' THEN 211		-- AllBet
									WHEN b.Product = 'VB' THEN 212			-- Macau Games
									WHEN b.Product = 'PP' THEN 248			-- Pragmatic Casino
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.sporttype
									WHEN b.Product IN ('VR') THEN vr.SportType
									WHEN b.RefTable IN (1, 2) THEN b.MatchId
									ELSE 0
								END,
					BetTeam = CASE
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'ParlayVS2', 'LG') THEN b.BetTeam
									ELSE ''
								END,
					Hdp1 = CASE
								WHEN b.Product IN ('NG', 'VS', 'VS2', 'VR', 'ParlayVS2', 'LG') THEN b.Hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.Product IN ('VS', 'VS2', 'VR', 'ParlayVS2', 'LG') THEN b.Hdp2
								ELSE 0
							END,
					OddsType = CASE
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'VR', 'LG') THEN b.OddsType
									ELSE 0
								END,
					Odds = CASE
								WHEN b.Product IN ('NG', 'VS', 'VS2', 'VR', 'Keno', 'ParlayVS2', 'Lottery', 'TG', 'I4D', 'VRG', 
									'H5LG', 'OneRNG', 'PP', 'SBC', 'VGA', 'SG', 'VS3', 'LG') THEN b.Odds
								ELSE 0
							END,
					MOdds = CASE 
								WHEN b.Product IN ('NG', 'VS', 'VS2', 'VR', 'ParlayVS2', 'LG') THEN b.modds 
								ELSE 0
							END,
					OddsSpread = CASE
									WHEN b.Product IN ('OneRNG', 'PP', 'SBC', 'VGA', 'SG') THEN ISNULL(b.oddsspread, 0)
									ELSE 0
								END,
					Status = CASE
								WHEN b.Product = 'TG' AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
								WHEN b.Product = 'TG' AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
								ELSE b.status
							END,
					SettlementStatus = 0,
					LiveIndicator = CASE
										WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN b.liveindicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.Product IN ('NG', 'VS', 'VS2', 'VR', 'ParlayVS2', 'LG') THEN b.livehomescore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.Product IN ('NG', 'VS', 'VS2', 'VR', 'LG') THEN b.liveawayscore
										ELSE 0
									END,
					LeagueId = CASE
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.leagueid
									WHEN b.Product IN ('VR') THEN vr.LeagueID
									ELSE 0
								END,
					MatchId = CASE
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.matchid
									WHEN b.Product IN ('VR') THEN b.matchid
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.Product IN ('NG', 'VS', 'VS2') THEN m.matchcode
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vo.RacerNum)
									ELSE ''
								END,
					Race = CASE
								WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), b.oddsid)
								ELSE ''
							END,
					EventDate = b.WinLostDate,
					HomeId = CASE
								WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.homeid
								WHEN b.Product IN ('VR') THEN vo.RacerID
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.awayid
								ELSE 0
							END,
					BetStatus = CASE
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.betstatus
									ELSE ''
								END,
					IsNeutral = CASE
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					Placing = CASE
									WHEN b.Product IN ('VR') THEN CONVERT(VARCHAR(5), vo.Placing)
									ELSE ''
								END,
					ShowTime = CASE
									WHEN b.Product IN ('VS', 'VS2') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
									ELSE ''
								END,
					BetCheck = CASE
									WHEN b.Product IN ('ParlayVS2', 'VRG', 'H5LG') THEN ISNULL(b.betcheck, '')
									WHEN b.Product IN ('Keno') THEN ISNULL(b.ComStatus, '')
									ELSE ''
								END,
					TransDesc = CASE
									WHEN b.Product IN ('VS2', 'Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VB', 'PP', 
										'VRG', 'TG', 'I4D', 'PGS', 'JK', 'H5LG', 'HB', 'CG', 'AP', 'APM', 'VS3', 'LG', 'SEA') THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					BetdaqId = -1,
					ExtraInfo = CASE
									WHEN b.Product IN ('Keno', 'Lottery', 'TG', 'NG', 'H5LG', 'VS', 'VS2', 'ParlayVS2', 'VR', 'VS3', 'LG') THEN ISNULL(b.ExtraInfo, '')
									ELSE ''
								END,
					SiteId = CASE
								WHEN b.Product IN ('H5LG', 'VRG') THEN CONVERT(VARCHAR(20), b.BetdaqId)
								ELSE ''
							END
				FROM #PagingData AS b
					LEFT JOIN dbo.match AS m WITH (NOLOCK) ON b.Product IN ('NG', 'VS', 'VS2', 'LG') AND b.matchid = m.matchid
					LEFT JOIN dbo.VSOutright AS vo WITH (NOLOCK) ON b.Product IN ('VR') AND b.oddsid = vo.Orid
					LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON b.Product IN ('VR') AND vr.EventID = vo.EventID
				WHERE b.WhTicket = 1
			END

			-- bettrans14
			IF EXISTS (SELECT TOP(1) 1 FROM #PagingData WHERE WhTicket = 2)
			BEGIN
				UPDATE b
				SET
					SportType = CASE
									WHEN b.Product IN ('Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VRG', 'TG', 'SBC', 'I4D', 'SXG', 'SAG', 'PGS', 'JK', 
										'H5LG', 'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM', 'VS3', 'FGGL', 'MXG', 'JIG', 'YB', 'MGRNG', 'SEA') THEN b.MatchId
									WHEN b.Product = 'AllBet' THEN 211		-- AllBet
									WHEN b.Product = 'VB' THEN 212			-- Macau Games
									WHEN b.Product = 'PP' THEN 248			-- Pragmatic Casino
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.sporttype
									WHEN b.Product IN ('VR') THEN vr.SportType
									WHEN b.RefTable IN (1, 2) THEN b.MatchId
									ELSE 0
								END,
					BetTeam = CASE
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'ParlayVS2', 'LG') THEN b.BetTeam
									ELSE ''
								END,
					Hdp1 = CASE
								WHEN b.Product IN ('NG', 'VS', 'VS2', 'VR', 'ParlayVS2', 'LG') THEN b.Hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.Product IN ('VS', 'VS2', 'VR', 'ParlayVS2', 'LG') THEN b.Hdp2
								ELSE 0
							END,
					OddsType = CASE
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'VR', 'LG') THEN b.OddsType
									ELSE 0
								END,
					Odds = CASE
								WHEN b.Product IN ('NG', 'VS', 'VS2', 'VR', 'Keno', 'ParlayVS2', 'Lottery', 'TG', 'I4D', 'VRG', 
									'H5LG', 'OneRNG', 'PP', 'SBC', 'VGA', 'SG', 'VS3', 'LG') THEN b.Odds
								ELSE 0
							END,
					MOdds = CASE 
								WHEN b.Product IN ('NG', 'VS', 'VS2', 'VR', 'ParlayVS2', 'LG') THEN b.modds 
								ELSE 0
							END,
					OddsSpread = CASE
									WHEN b.Product IN ('OneRNG', 'PP', 'SBC', 'VGA', 'SG') THEN ISNULL(b.oddsspread, 0)
									ELSE 0
								END,
					Status = CASE
								WHEN b.Product = 'TG' AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
								WHEN b.Product = 'TG' AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
								ELSE b.status
							END,
					SettlementStatus = 0,
					LiveIndicator = CASE
										WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN b.liveindicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.Product IN ('NG', 'VS', 'VS2', 'VR', 'ParlayVS2', 'LG') THEN b.livehomescore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.Product IN ('NG', 'VS', 'VS2', 'VR', 'LG') THEN b.liveawayscore
										ELSE 0
									END,
					LeagueId = CASE
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.leagueid
									WHEN b.Product IN ('VR') THEN vr.LeagueID
									ELSE 0
								END,
					MatchId = CASE
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.matchid
									WHEN b.Product IN ('VR') THEN b.matchid
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.matchcode
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vo.RacerNum)
									ELSE ''
								END,
					Race = CASE
								WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), b.oddsid)
								ELSE ''
							END,
					EventDate = b.WinLostDate,
					HomeId = CASE
								WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.homeid
								WHEN b.Product IN ('VR') THEN vo.RacerID
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.awayid
								ELSE 0
							END,
					BetStatus = CASE
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.betstatus
									ELSE ''
								END,
					IsNeutral = CASE
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					Placing = CASE
									WHEN b.Product IN ('VR') THEN CONVERT(VARCHAR(5), vo.Placing)
									ELSE ''
								END,
					ShowTime = CASE
									WHEN b.Product IN ('VS', 'VS2') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
									ELSE ''
								END,
					BetCheck = CASE
									WHEN b.Product IN ('ParlayVS2', 'VRG', 'H5LG') THEN ISNULL(b.betcheck, '')
									WHEN b.Product IN ('Keno') THEN ISNULL(b.ComStatus, '')
									ELSE ''
								END,
					TransDesc = CASE
									WHEN b.Product IN ('VS2', 'Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VB', 'PP', 
										'VRG', 'TG', 'I4D', 'PGS', 'JK', 'H5LG', 'HB', 'CG', 'AP', 'APM', 'VS3', 'LG', 'SEA') THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					BetdaqId = -1,
					ExtraInfo = CASE
									WHEN b.Product IN ('Keno', 'Lottery', 'TG', 'NG', 'H5LG', 'VS', 'VS2', 'ParlayVS2', 'VR', 'VS3', 'LG') THEN ISNULL(b.ExtraInfo, '')
									ELSE ''
								END,
					SiteId = CASE
								WHEN b.Product IN ('H5LG', 'VRG') THEN CONVERT(VARCHAR(20), b.BetdaqId)
								ELSE ''
							END
				FROM #PagingData AS b
					LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON b.Product IN ('NG', 'VS', 'VS2', 'LG') AND b.matchid = m.matchid
					LEFT JOIN dbo.VSOutright14 AS vo WITH (NOLOCK) ON b.Product IN ('VR') AND b.oddsid = vo.Orid
					LEFT JOIN dbo.VSRaceInfo14 AS vr WITH (NOLOCK) ON b.Product IN ('VR') AND vr.EventID = vo.EventID
				WHERE b.WhTicket = 2
			END

			-- Get ticket detail
			-- Virtual Sports
			IF EXISTS (SELECT 1 FROM #PagingData WHERE Product = 'VR' AND WhTicket = 1)
			BEGIN
				INSERT INTO @Detail
				SELECT
					bm.refno,
					bm.odds,
					bm.stake * ISNULL(e.Rate, 1) AS Stake,
					bm.status,
					bm.apositiontaking,
					bm.bettype,
					bm.betteam
				FROM dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN #PagingData AS b ON bm.refno = b.RefNo AND bm.custid = b.CustId
					INNER JOIN dbo.SportBettypeMatrix AS sbt WITH (NOLOCK) ON bm.bettype = sbt.Bettype
					LEFT JOIN #ExchangeRate AS e ON bm.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
				WHERE b.Product = 'VR'
					AND b.WhTicket = 1
					AND sbt.ProductID = 5
					AND sbt.EventType = 3
			END

			IF EXISTS (SELECT 1 FROM #PagingData WHERE Product = 'VR' AND WhTicket = 2)
			BEGIN
				INSERT INTO @Detail
				SELECT
					bm.refno,
					bm.odds,
					bm.stake * ISNULL(e.Rate, 1) AS Stake,
					bm.status,
					bm.apositiontaking,
					bm.bettype,
					bm.betteam
				FROM dbo.bettransm14 AS bm WITH (NOLOCK)
					INNER JOIN #PagingData AS b ON bm.refno = b.RefNo AND bm.custid = b.CustId
					INNER JOIN dbo.SportBettypeMatrix AS sbt WITH (NOLOCK) ON bm.bettype = sbt.Bettype
					LEFT JOIN #ExchangeRate AS e ON bm.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
				WHERE b.Product = 'VR'
					AND b.WhTicket = 2
					AND sbt.ProductID = 5
					AND sbt.EventType = 3
			END

			-- Return data
			SELECT
				c.username,
				SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS NickName,
				a.TransId,
				a.RefNo,
				a.Currency,
				a.CustId,
				a.SportType,
				a.BetType,
				a.BetId,
				a.BetTeam,
				a.Hdp1,
				a.Hdp2,
				a.OddsType,
				a.Odds,
				a.MOdds,
				a.OddsSpread,
				a.Stake * ISNULL(e.Rate, 1) AS Stake,
				a.Actual_Stake * ISNULL(e.Rate, 1) AS Actual_Stake,
				a.WinLost * ISNULL(e.Rate, 1) AS WinLost,
				a.LicenseeWL * ISNULL(e.Rate, 1) AS LicenseeWL,
				a.Comm * ISNULL(e.Rate, 1) AS Comm,
				a.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm,
				a.Status,
				a.SettlementStatus,
				a.TransDate,
				a.WinLostDate,
				a.LiveIndicator,
				a.LiveHomeScore,
				a.LiveAwayScore,
				a.Ip,
				a.BetFrom,
				a.LeagueId,
				a.MatchId,
				a.MatchCode,
				a.Race,
				a.EventDate,
				a.HomeId,
				a.AwayId,
				a.IsNeutral,
				a.BetStatus,
				a.Placing,
				a.ShowTime,
				a.BetCheck,
				a.TransDesc,
				a.BetdaqId,
				a.ExtraInfo,
				a.SiteId,
				ci.CustomerClass
			FROM
				#PagingData AS a
				INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = a.CustId
				INNER JOIN dbo.custInfo AS ci WITH (NOLOCK) ON ci.custid = a.CustId
				LEFT JOIN #ExchangeRate AS e
					ON e.ExchangeId = a.Currency
						AND a.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
			ORDER BY a.RowNum
		END
		ELSE
		BEGIN
			-- bettrans
			IF EXISTS (SELECT TOP(1) 1 FROM #Data WHERE WhTicket = 1)
			BEGIN
				UPDATE b
				SET
					SportType = CASE
									WHEN b.Product IN ('Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VRG', 'TG', 'SBC', 'I4D', 'SXG', 'SAG', 'PGS', 'JK',
										'H5LG', 'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM', 'VS3', 'FGGL', 'MXG', 'JIG', 'YB', 'MGRNG', 'SEA') THEN b.MatchId
									WHEN b.Product = 'AllBet' THEN 211		-- AllBet
									WHEN b.Product = 'VB' THEN 212			-- Macau Games
									WHEN b.Product = 'PP' THEN 248			-- Pragmatic Casino
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.sporttype
									WHEN b.Product IN ('VR') THEN vr.SportType
									WHEN b.RefTable IN (1, 2) THEN b.MatchId
									ELSE 0
								END,
					BetTeam = CASE
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'ParlayVS2', 'LG') THEN b.BetTeam
									ELSE ''
								END,
					Hdp1 = CASE
								WHEN b.Product IN ('NG', 'VS', 'VS2', 'VR', 'ParlayVS2', 'LG') THEN b.Hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.Product IN ('VS', 'VS2', 'VR', 'ParlayVS2', 'LG') THEN b.Hdp2
								ELSE 0
							END,
					OddsType = CASE
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'VR', 'LG') THEN b.OddsType
									ELSE 0
								END,
					Odds = CASE
								WHEN b.Product IN ('NG', 'VS', 'VS2', 'VR', 'Keno', 'ParlayVS2', 'Lottery', 'TG', 'I4D', 'VRG', 
									'H5LG', 'OneRNG', 'PP', 'SBC', 'VGA', 'SG', 'VS3', 'LG') THEN b.Odds
								ELSE 0 END,
					MOdds = CASE 
								WHEN b.Product IN ('NG', 'VS', 'VS2', 'VR', 'ParlayVS2', 'LG') THEN b.modds
								ELSE 0
							END,
					OddsSpread = CASE
									WHEN b.Product IN ('OneRNG', 'PP', 'SBC', 'VGA', 'SG') THEN ISNULL(b.oddsspread, 0)
									ELSE 0
								END,
					Status = CASE
								WHEN b.Product = 'TG' AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
								WHEN b.Product = 'TG' AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
								ELSE b.status
							END,
					SettlementStatus = 0,
					LiveIndicator = CASE
										WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN b.liveindicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.Product IN ('NG', 'VS', 'VS2', 'VR', 'ParlayVS2', 'LG') THEN b.livehomescore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.Product IN ('NG', 'VS', 'VS2', 'VR', 'LG') THEN b.liveawayscore
										ELSE 0
									END,
					LeagueId = CASE
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.leagueid
									WHEN b.Product IN ('VR') THEN vr.LeagueID
									ELSE 0
								END,
					MatchId = CASE
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.matchid
									WHEN b.Product IN ('VR') THEN b.matchid
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.matchcode
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vo.RacerNum)
									ELSE ''
								END,
					Race = CASE
								WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), b.oddsid)
								ELSE ''
							END,
					EventDate = b.WinLostDate,
					HomeId = CASE
								WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.homeid
								WHEN b.Product IN ('VR') THEN vo.RacerID
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.awayid
								ELSE 0
							END,
					BetStatus = CASE
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.betstatus
									ELSE ''
								END,
					IsNeutral = CASE
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					Placing = CASE
									WHEN b.Product IN ('VR') THEN CONVERT(VARCHAR(5), vo.Placing)
									ELSE ''
								END,
					ShowTime = CASE
									WHEN b.Product IN ('VS', 'VS2') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
									ELSE ''
								END,
					BetCheck = CASE
									WHEN b.Product IN ('ParlayVS2', 'VRG', 'H5LG') THEN ISNULL(b.betcheck, '')
									WHEN b.Product IN ('Keno') THEN ISNULL(b.ComStatus, '')
									ELSE ''
								END,
					TransDesc = CASE
									WHEN b.Product IN ('VS2', 'Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VB', 'PP', 
										'VRG', 'TG', 'I4D', 'PGS', 'JK', 'H5LG', 'HB', 'CG', 'AP', 'APM', 'VS3', 'LG', 'SEA') THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					BetdaqId = -1,
					ExtraInfo = CASE
									WHEN b.Product IN ('Keno', 'Lottery', 'TG', 'NG', 'H5LG', 'VS', 'VS2', 'ParlayVS2', 'VR', 'VS3', 'LG') THEN ISNULL(b.ExtraInfo, '')
									ELSE ''
								END,
					SiteId = CASE
								WHEN b.Product IN ('H5LG', 'VRG') THEN CONVERT(VARCHAR(20), b.BetdaqId)
								ELSE ''
							END
				FROM #Data AS b
					LEFT JOIN dbo.match AS m WITH (NOLOCK) ON b.Product IN ('NG', 'VS', 'VS2', 'LG') AND b.matchid = m.matchid
					LEFT JOIN dbo.VSOutright AS vo WITH (NOLOCK) ON b.Product IN ('VR') AND b.oddsid = vo.Orid
					LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON b.Product IN ('VR') AND vr.EventID = vo.EventID
				WHERE b.WhTicket = 1
			END

			-- bettrans14
			IF EXISTS (SELECT TOP(1) 1 FROM #Data WHERE WhTicket = 2)
			BEGIN
				UPDATE b
				SET
					SportType = CASE
									WHEN b.Product IN ('Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VRG', 'TG', 'SBC', 'I4D', 'SXG', 'SAG', 'PGS', 'JK',
										'H5LG', 'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM', 'VS3', 'FGGL', 'MXG', 'JIG', 'YB', 'MGRNG', 'SEA') THEN b.MatchId
									WHEN b.RefTable IN (1, 2) THEN b.MatchId
									WHEN b.Product = 'AllBet' THEN 211		-- AllBet
									WHEN b.Product = 'VB' THEN 212			-- Macau Games
									WHEN b.Product = 'PP' THEN 248			-- Pragmatic Casino
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.sporttype
									WHEN b.Product IN ('VR') THEN vr.SportType
									ELSE 0
								END,
					BetTeam = CASE
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'ParlayVS2', 'LG') THEN b.BetTeam
									ELSE ''
								END,
					Hdp1 = CASE
								WHEN b.Product IN ('NG', 'VS', 'VS2', 'VR', 'ParlayVS2', 'LG') THEN b.Hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.Product IN ('VS', 'VS2', 'VR', 'ParlayVS2', 'LG') THEN b.Hdp2
								ELSE 0
							END,
					OddsType = CASE
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'VR', 'LG') THEN b.OddsType
									ELSE 0
								END,
					Odds = CASE
								WHEN b.Product IN ('NG', 'VS', 'VS2', 'VR', 'Keno', 'ParlayVS2', 'Lottery', 'TG', 'I4D', 'VRG', 
									'H5LG', 'OneRNG', 'PP', 'SBC', 'VGA', 'SG', 'VS3', 'LG') THEN b.Odds
								ELSE 0 END,
					MOdds = CASE 
								WHEN b.Product IN ('NG', 'VS', 'VS2', 'VR', 'ParlayVS2', 'LG') THEN b.modds
								ELSE 0
							END,
					OddsSpread = CASE
									WHEN b.Product IN ('OneRNG', 'PP', 'SBC', 'VGA', 'SG') THEN ISNULL(b.oddsspread, 0)
									ELSE 0
								END,
					Status = CASE
								WHEN b.Product = 'TG' AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
								WHEN b.Product = 'TG' AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
								ELSE b.status
							END,
					SettlementStatus = 0,
					LiveIndicator = CASE
										WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN b.liveindicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.Product IN ('NG', 'VS', 'VS2', 'VR', 'ParlayVS2', 'LG') THEN b.livehomescore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.Product IN ('NG', 'VS', 'VS2', 'VR', 'LG') THEN b.liveawayscore
										ELSE 0
									END,
					LeagueId = CASE
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.leagueid
									WHEN b.Product IN ('VR') THEN vr.LeagueID
									ELSE 0
								END,
					MatchId = CASE
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.matchid
									WHEN b.Product IN ('VR') THEN b.matchid
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.matchcode
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vo.RacerNum)
									ELSE ''
								END,
					Race = CASE
								WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), b.oddsid)
								ELSE ''
							END,
					EventDate = b.WinLostDate,
					HomeId = CASE
								WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.homeid
								WHEN b.Product IN ('VR') THEN vo.RacerID
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.awayid
								ELSE 0
							END,
					BetStatus = CASE
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.betstatus
									ELSE ''
								END,
					IsNeutral = CASE
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					Placing = CASE
									WHEN b.Product IN ('VR') THEN CONVERT(VARCHAR(5), vo.Placing)
									ELSE ''
								END,
					ShowTime = CASE
									WHEN b.Product IN ('VS', 'VS2') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
									ELSE ''
								END,
					BetCheck = CASE
									WHEN b.Product IN ('ParlayVS2', 'VRG', 'H5LG') THEN ISNULL(b.betcheck, '')
									WHEN b.Product IN ('Keno') THEN ISNULL(b.ComStatus, '')
									ELSE ''
								END,
					TransDesc = CASE
									WHEN b.Product IN ('VS2', 'Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VB', 'PP', 
										'VRG', 'TG', 'I4D', 'PGS', 'JK', 'H5LG', 'HB', 'CG', 'AP', 'APM', 'VS3', 'LG', 'SEA') THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					BetdaqId = -1,
					ExtraInfo = CASE
									WHEN b.Product IN ('Keno', 'Lottery', 'TG', 'NG', 'H5LG', 'VS', 'VS2', 'ParlayVS2', 'VR', 'VS3', 'LG') THEN ISNULL(b.ExtraInfo, '')
									ELSE ''
								END,
					SiteId = CASE
								WHEN b.Product IN ('H5LG', 'VRG') THEN CONVERT(VARCHAR(20), b.BetdaqId)
								ELSE ''
							END
				FROM #Data AS b
					LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON b.Product IN ('NG', 'VS', 'VS2', 'LG') AND b.matchid = m.matchid
					LEFT JOIN dbo.VSOutright14 AS vo WITH (NOLOCK) ON b.Product IN ('VR') AND b.oddsid = vo.Orid
					LEFT JOIN dbo.VSRaceInfo14 AS vr WITH (NOLOCK) ON b.Product IN ('VR') AND vr.EventID = vo.EventID
				WHERE b.WhTicket = 2
			END
			
			CREATE TABLE #Customer (
				CustId			INT,
				Username		VARCHAR(30),
				NickName		VARCHAR(50),
				CustomerClass	SMALLINT)

			INSERT INTO #Customer (
				CustId,
				Username,
				NickName,
				CustomerClass)
			SELECT
				c.custid,
				c.username,
				SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS NickName,
				ci.CustomerClass
			FROM dbo.Customer AS c WITH (NOLOCK)
				INNER JOIN dbo.custInfo AS ci WITH (NOLOCK) ON ci.custid = c.custid
			WHERE c.custid IN (SELECT DISTINCT CustId FROM #Data)

			-- Get ticket detail
			-- Virtual Sports
			IF EXISTS (SELECT 1 FROM #Data WHERE Product = 'VR' AND WhTicket = 1)
			BEGIN
				INSERT INTO @Detail
				SELECT
					bm.refno,
					bm.odds,
					bm.stake * ISNULL(e.Rate, 1) AS Stake,
					bm.status,
					bm.apositiontaking,
					bm.bettype,
					bm.betteam
				FROM dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN #Data AS b ON bm.refno = b.RefNo AND bm.custid = b.CustId
					INNER JOIN dbo.SportBettypeMatrix AS sbt WITH (NOLOCK) ON bm.bettype = sbt.Bettype
					LEFT JOIN #ExchangeRate AS e ON bm.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
				WHERE b.Product = 'VR'
					AND b.WhTicket = 1
					AND sbt.ProductID = 5
					AND sbt.EventType = 3
			END

			IF EXISTS (SELECT 1 FROM #Data WHERE Product = 'VR' AND WhTicket = 2)
			BEGIN
				INSERT INTO @Detail
				SELECT
					bm.refno,
					bm.odds,
					bm.stake * ISNULL(e.Rate, 1) AS Stake,
					bm.status,
					bm.apositiontaking,
					bm.bettype,
					bm.betteam
				FROM dbo.bettransm14 AS bm WITH (NOLOCK)
					INNER JOIN #Data AS b ON bm.refno = b.RefNo AND bm.custid = b.CustId
					INNER JOIN dbo.SportBettypeMatrix AS sbt WITH (NOLOCK) ON bm.bettype = sbt.Bettype
					LEFT JOIN #ExchangeRate AS e ON bm.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
				WHERE b.Product = 'VR'
					AND b.WhTicket = 2
					AND sbt.ProductID = 5
					AND sbt.EventType = 3
			END

			SET @Sql = 
				N'SELECT
					c.Username,
					c.NickName,
					a.TransId,
					a.RefNo,
					a.Currency,
					a.CustId,
					a.SportType,
					a.BetType,
					a.BetId,
					a.BetTeam,
					a.Hdp1,
					a.Hdp2,
					a.OddsType,
					a.Odds,
					a.MOdds,
					a.OddsSpread,
					a.Stake * ISNULL(e.Rate, 1) AS Stake,
					a.Actual_Stake * ISNULL(e.Rate, 1) AS Actual_Stake,
					a.WinLost * ISNULL(e.Rate, 1) AS WinLost,
					a.LicenseeWL * ISNULL(e.Rate, 1) AS LicenseeWL,
					a.Comm * ISNULL(e.Rate, 1) AS Comm,
					a.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm,
					a.Status,
					a.SettlementStatus,
					a.TransDate,
					a.WinLostDate,
					a.LiveIndicator,
					a.LiveHomeScore,
					a.LiveAwayScore,
					a.Ip,
					a.BetFrom,
					a.LeagueId,
					a.MatchId,
					a.MatchCode,
					a.Race,
					a.EventDate,
					a.HomeId,
					a.AwayId,
					a.IsNeutral,
					a.BetStatus,
					a.Placing,
					a.ShowTime,
					a.BetCheck,
					a.TransDesc,
					a.BetdaqId,
					a.ExtraInfo,
					a.SiteId,
					c.CustomerClass
				FROM
					#Data AS a
					INNER JOIN #Customer AS c ON c.custid = a.CustId
					LEFT JOIN #ExchangeRate AS e
						ON e.ExchangeId = a.Currency
							AND a.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
				ORDER BY ' + @Sort

			EXEC sp_executesql @Sql

			DROP TABLE #Customer
		END
	END
	ELSE
	BEGIN
		SELECT * FROM #Data
	END

	SELECT DISTINCT * FROM @Detail

	DROP TABLE #PagingData
	DROP TABLE #Data
	DROP TABLE #ExchangeRate
END
GO
