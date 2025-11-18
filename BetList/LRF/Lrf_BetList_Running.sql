/*<info serverAlias="DBBOF-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_Running]
	@AgentList			VARCHAR(MAX),
	@CustId				INT				= 0,
	@Username			VARCHAR(50)		= '',
	@BaseCurrency		VARCHAR(12),
	@ConvertToBaseCur	BIT				= 0,	-- Convert to base currency or not
	@StatusFilter		VARCHAR(10)		= '1,2,3',
	@PageSize			INT				= 1000,
	@PageIndex			INT				= 1,
	@SortType			TINYINT			= 0,		-- TransDate
	@SortOrder			TINYINT			= 1,		-- ASC
	@ProductList		VARCHAR(MAX)	= '',
	@SportTypeList		VARCHAR(MAX)	= 'All',
	@BetTypeList		VARCHAR(MAX)	= 'All',
	@LeagueList			VARCHAR(MAX)	= 'All',
	@MatchId			INT				= 0,
	@LiveIndicator		VARCHAR(10)		= '0,1,2',
	@CustomerClass		VARCHAR(MAX)	= 'All',
	@FullCustomerClass	VARCHAR(MAX)	= 'All',
	@Platform			VARCHAR(200)	= 'All',
	@OddsGroup			VARCHAR(100)	= 'All',
	@Ip					VARCHAR(45)		= '',
	@TotalRows			INT				= 0 OUTPUT,
	@SumStake			MONEY			= 0 OUTPUT
AS

/*
	Created: Kos@20180613
	Task: Betting Ticket Center - Running Bet List
	DB: DBBOF.bodb02
	Param's Explanation:
		- @StatusFilter:
			- 1: Running, Waiting
			- 2: Delay Payout
			- 3: Under Settlement
		- @SportTypeList: 
			+ All: all sport types
			+ XML format
				<ROOT>
					<Sport SportType="1" LeagueGroupIds="0"/>
					<Sport SportType="1" LeagueGroupIds="42,74"/>
					<Sport SportType="5" LeagueGroupIds="0"/>
					<Sport SportType="-1" LeagueGroupIds="0"/>
				</ROOT>
				+ Parlay: <Sport SportType="-1" LeagueGroupIds="0"/>
				+ Sports Lottery: <Sport SportType="169" LeagueGroupIds="0"/>
				+ Saba Soccer: <Sport SportType="1" LeagueGroupIds="42,74"/>
				+ Saba Soccer PinGoal: <Sport SportType="1" LeagueGroupIds="113"/>
				+ Saba Soccer Marble: <Sport SportType="1" LeagueGroupIds="252"/>
				+ Saba Basketball: <Sport SportType="2" LeagueGroupIds="42"/>
				+ Saba Basketball PinGoal: <Sport SportType="2" LeagueGroupIds="122"/>
				+ Saba Cricket: <Sport SportType="50" LeagueGroupIds="42"/>
				+ Saba Futsal: <Sport SportType="1" LeagueGroupIds="108"/>
				+ Saba E-Sports PinGoal: <Sport SportType="43" LeagueGroupIds="151"/>
				+ Saba Tennis: <Sport SportType="5" LeagueGroupIds="42"/>
				+ Saba Ice Hockey: <Sport SportType="4" LeagueGroupIds="42"/>
				+ Saba Kabaddi: <Sport SportType="47" LeagueGroupIds="42"/>
		- @BetTypeList:
			+ All: all bet types
			+ XML format
				<ROOT>
					<BetType ProductPrefix="SB" BetTypes="1,2,3,4,5,6,7,8,10,12,13,14"/>
					<BetType ProductPrefix="VS" BetTypes="1,3,4,5,7,8,9,15,24,501,1206,1220,1231,1232"/>
					<BetType ProductPrefix="KN" BetTypes="1501,1502,1503,1504,1505,1506"/>
				</ROOT>
		- @LeagueList: list of league seperated by commas (All: all leagues)
		- @LiveIndicator:
			- 0 : Non-live
			- 1 : Live
			- 2 : Mix Non Live & Live
		- @CustomerClass: list of customer class seperated by commas (All: all customer classes)
		- @FullCustomerClass: list of all customer class seperated by commas (All: all customer classes)
		- @Platform: list of platform seperated by commas (All: all platforms)
		- @OddsGroup: list of odds group seperated by commas (All: all odds group)
		- @SortType:
			- 0: TransDate
			- 1: Stake
		- @SortOrder
			- 1: ASC
			- 2: DESC

	Revisions:
		- 20180613@Kos: Created [#Redmine: 80941]
		- 20181114@Kos: Change getting ticket status [#Redmine: 104664]
		- 20181121@Kos: Support 2 new statuses Result Pending and Under Settlement [#Redmine: 102428]
		- 20190107@Kos: Support Parlay Changes [#Redmine: 107165]
		- 20190121@Kos: Betting Ticket Center phase 3a [Redmine: #103555]
					- Remove param @FromDate and @ToDate
		- 20190305@Kos: Add new param @StatusFilter, @ConvertToBaseCur [Redmine: #108717]
					- Remove param @CurrencyId
		- 20190411@Kos: Support search LIKE on username [Redmine: #111665]
		- 20190422@Kos: Enhance performance for searching too many members [Redmine: #112313]
		- 20190426@Kos: Support base currency INH [Redmine: #112603]
		- 20190506@Kos: Result Pending for SettlementStatus = 5 [Redmine: #112886]
		- 20190509@Kos: Show match KO time for single ticket [Redmine: #112731]
					- Return additional column EventDate DATETIME
		- 20190627@Kos: Support PH AIO 4a [Redmine: #115448]
		- 20190730@Kos: Support new status Pending [#Redmine: 117729]
		- 20191031@Kos: Show Running status for Marked tickets [Redmine: 120309]
		- 20200207@Kos: Support sort by trans time [Redmine: #126886]
		- 20200402@Kos: Support Table Games [Redmine: #131447]
		- 20200416@Kos: Support Indo 4D [Redmine: #130859]
		- 20200425@Kos: Support status Delay Payout [Redmine: #132629]
		- 20200525@Kos: Support show licensee transaction ID [Redmine: #134629]
		- 20201231@Kos: Support Virtual Games [Redmine: #147843]
		- 20200108@Kos: Support Happy 5 Linked Games [Redmine: #147446]
		- 20210301@Kos: Add BDT and INR as base currencies [Redmine: 150375]
		- 20210311@Kos: Support Sports Lottery [Redmine: #150872]
		- 20210705@Kos: Support Happy 5 Linked Games - Soccer 5 [Redmine: #154898]
		- 20210714@Kos: Support Casino products [Redmine: #157987]
		- 20210929@Kos: Extend length to support IPv6 [Redmine: 162342]
		- 20211102@Kos: Support AdvantPlay and AdvantPlay Mini [Redmine: #158186]
		- 20211215@Kos: Hotfix - Show Casino tickets when choosing Delayed Payout [Redmine: #166109]
		- 20220110@Kos: Support TxId for 3rd products [Redmine: #166706]
		- 20220227@Kos: Support Virtual Sports 3 [Redmine: #145337]
		- 20220428@Kos: Support Bitcoin [Redmine: #160160]
		- 20220526@Kos: Support FGG [Redmine: #167897]
		- 20220527@Kos: Support MaxGame [RedmineID: #172919]
		- 20220922@Kos: Support crypto currency [Redmine: 177481]
		- 20230119@Kos: Support Jili [Redmine: 182914]
		- 20230328@Kos: Remove inactive products CB, FW, GDG [Redmine: 181424]
		- 20230404@Kos: Extend betfrom length [Redmine: #178059]
		- 20230602@Kos: Support YeeBet [Redmine: 187947]
		- 20230629@Kos: Support MG-RNG [Redmine: 189988]
		- 20230803@Kos: Support Virtual Sports 3 [Redmine: 190908]
		- 20231107@Kos: Support SEAL Entertaiment [Redmine: 180648]
		- 20231110@Kos: Support WE Live Casino [Redmine: 196573]
		- 20231227@Kos: Hotfix - cannot view result [Redmine: 198900]
		- 20231227@Kos: Hide Saba text for Jollysports licensees [Redmine: 198697]
		- 20240102@Kos: Extend data type [Redmine: 198966]
		- 20240129@Kos: Merge VS1, VS2, VS3 into VS [Redmine: 199523]
		- 20240412@Kos: Support Gaming API [Redmine: 203734]
		- 20240425@Kos: Support Virtual Sports 4 [Redmine: 199347]
		- 20240705@Kos: Support more filters [Redmine: 202409]
					- Add new input params @SportTypeList, @BetTypeList, @LeagueList, @MatchId, @LiveIndicator, 
					@CustomerClass, @FullCustomerClass, @Platform, @OddsGroup, @Ip
		- 20240906@Kos: Support Baseball AIO phase 2 [Redmine: 209344]
		- 20240919@Kos: Support BetRadar Horse Racing [Redmine: #210808]
		- 20241113@Kos: Hotfix - wrong VS tickets [Redmine: #213614]
		- 20241115@Kos: Support Virtual Sports 6 [Redmine: 212446]
		- 20241210@Kos: Add unknown betfroms into group Others [#Redmine: 214849]
		- 20250225@Kos: Fix bug FLOAT rounding [#Redmine: 194970]
		- 20250313@Kos: Remove BA [RedmineID: #216882]
					- Remove input param @ShowBA
		- 20250318@Kos: Support Virtual Sports 5 [Redmine: 207582]
		- 20250416@Kos: Extend input param length [Redmine: 219083]
		- 20250506@Kos: Support Saba Soccer Marble [#Redmine: 225015]
		- 20250725@Kos: Hotfix - Parlay sport [#Redmine: 234256]
		- 20250801@Kos: Support Playtech Jackpot [#Redmine: 233781]
		- 20250806@Kos: Fix security issue in dynamic query [#Redmine: 227496]
					- Remove input param @Sort
					- Add new input params @SortType TINYINT, @SortOrder TINYINT
		- 20250820@Kos: Support Playtech Live Jackpot [#Redmine: 230078]
		- 20251028@Kelvin: Integrate - Jacktime - Basketball Main Bettype Hybrid Parlay [#Redmine: 242357]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @HasError BIT = 0

	CREATE TABLE #TempAg (CustId INT, Currency INT)

	CREATE CLUSTERED INDEX IX_CustId ON #TempAg (CustId)

	-- Get AgentList
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO #TempAg (CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SET @HasError = 1
	END CATCH

	-- Get Saba sport type list
	DECLARE @SabaSportType TABLE (SportType SMALLINT, LeagueGroupIdList VARCHAR(200))

	INSERT INTO @SabaSportType (SportType, LeagueGroupIdList)
	SELECT 1, '42,74'		-- Saba Soccer
	UNION SELECT 1, '113'	-- Saba Soccer PinGoal
	UNION SELECT 1, '252'	-- Saba Soccer Marble
	UNION SELECT 2, '42'	-- Saba Basketball
	UNION SELECT 2, '122'	-- Saba Basketball PinGoal
	UNION SELECT 50, '42'	-- Saba Cricket
	UNION SELECT 1, '108'	-- Saba Futsal
	UNION SELECT 43, '151'	-- Saba E-Sports PinGoal
	UNION SELECT 5, '42'	-- Saba Tennis
	UNION SELECT 4, '42'	-- Saba Ice Hockey
	UNION SELECT 47, '42'	-- Saba Kabaddi

	CREATE TABLE #Data (
		TransId				BIGINT,
		RefNo				BIGINT,
		CustId				INT,
		Currency			SMALLINT,
		Recommend			INT,
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
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		SecAcceptFlag		BIT,
		CheckTime			DATETIME,
		TransDate			DATETIME,
		WinLostDate			SMALLDATETIME,
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		Ip					VARCHAR(45),
		BetFrom				NVARCHAR(4),
		LeagueId			INT,
		LeagueGroupId		SMALLINT,
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
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		WalletType			TINYINT,
		RefCode				BIGINT,
		ProductId			INT,
		Custom1				NVARCHAR(50),
		Custom2				NVARCHAR(50),
		Custom3				NVARCHAR(50),
		Gameid3rd			NVARCHAR(50),
		Tranid3rd			NVARCHAR(200),
		TableID				TINYINT,
		Product				VARCHAR(30),
		SubProduct			VARCHAR(500),
		RefTable			TINYINT,
		EventType			TINYINT
	)

	CREATE TABLE #PagingData (
		RowNum				INT,
		TransId				BIGINT,
		RefNo				BIGINT,
		CustId				INT,
		Currency			SMALLINT,
		Recommend			INT,
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
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		SecAcceptFlag		BIT,
		CheckTime			DATETIME,
		TransDate			DATETIME,
		WinLostDate			SMALLDATETIME,
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		Ip					VARCHAR(45),
		BetFrom				NVARCHAR(4),
		LeagueId			INT,
		LeagueGroupId		SMALLINT,
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
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		WalletType			TINYINT,
		RefCode				BIGINT,
		ProductId			INT,
		Custom1				NVARCHAR(50),
		Custom2				NVARCHAR(50),
		Custom3				NVARCHAR(50),
		Gameid3rd			NVARCHAR(50),
		Tranid3rd			NVARCHAR(200),
		TableID				TINYINT,
		Product				VARCHAR(30),
		SubProduct			VARCHAR(500),
		RefTable			TINYINT,
		EventType			TINYINT
	)

	DECLARE @TmpData TABLE (
		RefNo			BIGINT,
		BetType			SMALLINT,
		Odds			MONEY,
		OddsSpread		MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		IsNew			BIT
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

	-- Get exchange rate
	CREATE TABLE #ExchangeRate (
		ExchangeId	INT,
		Rate		FLOAT
	)

	CREATE TABLE #TempSportType (SportType SMALLINT, LeagueGroupIdList VARCHAR(200))

	CREATE TABLE #TempBetType (ProductPrefix VARCHAR(10), BetTypeList VARCHAR(MAX))

	CREATE TABLE #AllPlatformList (BetFrom NVARCHAR(4))
	CREATE TABLE #PlatformList (BetFrom NVARCHAR(4))

	IF @Platform <> 'All'
	BEGIN
		INSERT INTO #AllPlatformList (BetFrom)
		SELECT DISTINCT betfrom
		FROM dbo.Lrf_f_BetFromType_Sel('All')

		INSERT INTO #PlatformList (BetFrom)
		SELECT DISTINCT betfrom
		FROM dbo.Lrf_f_BetFromType_Sel(@Platform)
	END

	IF @HasError = 0
	BEGIN
		-- Get child product list
		IF EXISTS (SELECT 1 FROM dbo.Lrf_f_GroupProduct() WHERE ',' + @ProductList + ',' LIKE '%,' + GroupProductPrefix + ',%')
		BEGIN
			DECLARE @ChildProductList VARCHAR(500)

			SELECT @ChildProductList = STRING_AGG(ProductPrefix, ',')
			FROM dbo.Lrf_f_GroupProduct()
			WHERE ',' + @ProductList + ',' LIKE '%,' + GroupProductPrefix + ',%'

			SET @ProductList = @ProductList + ',' + @ChildProductList
		END

		-- Get Sport Bettype Matrix
		DECLARE @SportBettype TABLE(ProductID TINYINT, ProductPrefix VARCHAR(500), BetType SMALLINT, EventType TINYINT, RefTable TINYINT, SubProduct VARCHAR(500))

		DECLARE @IsTest BIT = 0

		SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

		INSERT INTO @SportBettype (ProductID, ProductPrefix, BetType, EventType, RefTable, SubProduct)
		SELECT ProductID, ProductPrefix, BetType, EventType, RefTable, SubProduct
		FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @ProductList, @IsTest)
		WHERE BetType NOT IN (71, 73, 901, 902, 903, 904, 911, 912, 913, 914, 997, 999)
			AND BetType NOT BETWEEN 801 AND 899

		IF @BetTypeList <> 'All'
		BEGIN
			BEGIN TRY
				EXEC sp_xml_preparedocument @DocHandler OUTPUT, @BetTypeList

				INSERT INTO #TempBetType (ProductPrefix, BetTypeList)
				SELECT ProductPrefix, BetTypes
				FROM OPENXML(@DocHandler, '/ROOT/BetType', 1) WITH (ProductPrefix VARCHAR(10), BetTypes VARCHAR(MAX)) AS Data

				EXEC sp_xml_removedocument @DocHandler
			END TRY
			BEGIN CATCH
				SET @HasError = 1
			END CATCH
			
			DELETE sbt
			FROM @SportBettype AS sbt
				LEFT JOIN dbo.Lrf_f_GroupProduct() AS gp ON gp.ProductPrefix = sbt.ProductPrefix
				LEFT JOIN dbo.Lrf_f_GroupBettype() AS gbt ON gbt.bettype = sbt.BetType
			WHERE NOT EXISTS (SELECT 1 FROM #TempBetType AS tbt
							WHERE (',' + tbt.BetTypeList + ',' LIKE '%,' + CONVERT(VARCHAR(6), sbt.BetType) + ',%'
									OR ',' + tbt.BetTypeList + ',' LIKE '%,' + CONVERT(VARCHAR(6), gbt.GroupTypeId) + ',%')
								AND tbt.ProductPrefix IN (sbt.ProductPrefix, gp.GroupProductPrefix))
		END

		-- Get sport type list
		IF @SportTypeList <> 'All'
		BEGIN TRY
			EXEC sp_xml_preparedocument @DocHandler OUTPUT, @SportTypeList
	
			INSERT INTO #TempSportType (SportType, LeagueGroupIdList)
			SELECT SportType, LeagueGroupIds
			FROM OPENXML(@DocHandler, '/ROOT/Sport', 1) WITH (SportType SMALLINT, LeagueGroupIds VARCHAR(200)) AS Data

			EXEC sp_xml_removedocument @DocHandler

			DELETE FROM @SportBettype
			WHERE ProductID NOT IN ( SELECT DISTINCT s.ProductID
									FROM dbo.SportBettypeMatrix AS s WITH (NOLOCK)
										INNER JOIN #TempSportType AS st
										ON s.SportType = st.SportType
											OR (s.ProductID = 1 AND st.SportType = -1))
		END TRY
		BEGIN CATCH
			SET @HasError = 1
		END CATCH

		CREATE CLUSTERED INDEX IX_SportType ON #TempSportType (SportType)

		DECLARE @TempCust TABLE (CustId INT PRIMARY KEY, CustomerClass SMALLINT)

		IF @Username IS NOT NULL AND @Username <> ''
		BEGIN
			INSERT INTO @TempCust (CustId, CustomerClass)
			SELECT c.custid,
				ci.CustomerClass
			FROM dbo.Customer AS c WITH (NOLOCK)
				INNER JOIN #TempAg AS a ON c.recommend = a.CustId
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

		DECLARE @Yesterday SMALLDATETIME = DATEADD(DAY, DATEDIFF(DAY, 1, CURRENT_TIMESTAMP), 0)

		DECLARE @MatchSportType	SMALLINT,
			@ParentId			INT

		SELECT
			@MatchSportType = sporttype,
			@ParentId = ParentID
		FROM dbo.match WITH (NOLOCK)
		WHERE matchid = @MatchId

		IF @MatchSportType IS NULL
		BEGIN
			SELECT
				@MatchSportType = sporttype,
				@ParentId = ParentID
			FROM dbo.match14 WITH (NOLOCK)
			WHERE matchid = @MatchId
		END

		DECLARE @Match TABLE(MatchId INT)

		IF @MatchSportType IN (8, 50) AND @ParentId IS NULL		-- Baseball, Cricket, parent match
		BEGIN
			INSERT INTO @Match (MatchId)
			SELECT DISTINCT MatchId
			FROM dbo.match WITH (NOLOCK)
			WHERE ParentID = @MatchId
				AND sporttype = @MatchSportType
				AND eventdate > @Yesterday
				AND ChildMatchType = 200
		END

		DECLARE @NumOfMem	INT = 0

		SELECT @NumOfMem = COUNT(1) FROM @TempCust

		IF @Username IS NULL OR @Username = '' OR @NumOfMem > 5000		-- Licensee level (not input username of number of searched member > 5000)
		BEGIN
			-- bettrans
			INSERT INTO #Data (
				TransId, RefNo, CustId, Currency, Recommend, BetType, BetId, BetTeam, Hdp1, Hdp2,
				OddsId, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, Status, SecAcceptFlag, CheckTime,
				TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, BetFrom, MatchId, BetCheck, ComStatus,
				TransDesc, BetdaqId, ExtraInfo, WalletType, RefCode, TableID
			)
			SELECT
				b.transid,
				b.refno,
				b.custid,
				b.currency,
				b.recommend,
				b.bettype,
				ISNULL(b.BetId, 0) AS BetId,
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
				b.status,
				b.SecAcceptFlag,
				b.checktime,
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
				b.WalletType,
				ISNULL(b.RefCode, 0),
				1 AS TableID
			FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_betrunning_recommend)
				INNER JOIN #TempAg AS a ON a.CustId = b.recommend
				INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
				LEFT JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1
				LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK) ON m3rd.Match3rdId = b.MatchId AND s.EventType = 5
				LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.matchid = o.orid AND b.bettype = 10
				LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
				LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON vr.EventID = b.matchid AND s.EventType = 3
			WHERE b.statusID IN (0, 1)
				AND ((b.bettype IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.livehomescore) + ',%')
					OR (b.bettype NOT IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'))
				AND (@SportTypeList = 'All'
					OR EXISTS (	SELECT 1 FROM #TempSportType
								WHERE SportType = CASE
													WHEN s.EventType = 1 THEN m.sporttype
													WHEN b.bettype = 10 THEN l.sporttype
													WHEN b.bettype IN (9, 29) THEN -1
													WHEN s.ProductId IN (63) THEN b.matchid
													WHEN s.EventType = 5 THEN m3rd.SportType
													WHEN s.EventType = 3 THEN vr.sporttype
													WHEN s.EventType = 0 AND s.RefTable = 3 THEN b.matchid
													WHEN s.EventType = 0 AND s.ProductID IN (27, 83, 88) THEN b.oddsid
													WHEN s.RefTable IN (1, 2) THEN b.matchid
													ELSE 0
												END))
				AND (@LeagueList = 'All'
					OR ',' + @LeagueList + ',' LIKE '%,' + CONVERT(VARCHAR(11), CASE
																					WHEN s.EventType = 1 THEN m.leagueid
																					WHEN b.bettype = 10 THEN o.leagueid
																					ELSE 0
																				END) + ',%')
				AND (@MatchId = 0
					OR b.matchid = @MatchId
					OR b.matchid IN (SELECT MatchId FROM @Match))

			-- translog
			INSERT INTO #Data (
				TransId, RefNo, CustId, Currency, Recommend, BetType, Odds, Stake, Actual_Stake, Status,
				TransDate, WinLostDate, LiveIndicator, Ip, BetFrom, TransDesc, ProductId, Custom1, Custom2, Custom3,
				Gameid3rd, Tranid3rd, TableID
			)
			SELECT
				tl.translogid AS TransId,
				tl.translogid AS RefNo,
				tl.custid,
				tl.currency,
				tl.recommend,
				tl.gameID AS BetType,
				tl.odds,
				tl.stake,
				tl.actual_stake,
				tl.status,
				tl.transdate,
				tl.transdate AS WinLostDate,
				tl.LiveIndicator,
				tl.ip,
				tl.betfrom,
				tl.transdesc,
				tl.productID,
				tl.custom1,
				tl.custom2,
				tl.custom3,
				tl.GameId3rd,
				tl.TranId3rd,
				2 AS TableID
			FROM dbo.translog AS tl WITH (NOLOCK, INDEX = IX_betrunning_recommend)
				INNER JOIN #TempAg AS a ON a.CustId = tl.recommend
			WHERE tl.statusID IN (0, 1)
				AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), tl.liveindicator) + ',%'
				AND (@SportTypeList = 'All'
					OR EXISTS (SELECT 1 FROM #TempSportType WHERE SportType = tl.productID))
		END
		ELSE		-- Customer level
		BEGIN
			-- bettrans
			INSERT INTO #Data (
				TransId, RefNo, CustId, Currency, Recommend, BetType, BetId, BetTeam, Hdp1, Hdp2,
				OddsId, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, Status, SecAcceptFlag, CheckTime,
				TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, BetFrom, MatchId, BetCheck, ComStatus,
				TransDesc, BetdaqId, ExtraInfo, WalletType, RefCode, TableID
			)
			SELECT
				b.transid,
				b.refno,
				b.custid,
				b.currency,
				b.recommend,
				b.bettype,
				ISNULL(b.BetId, 0) AS BetId,
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
				b.status,
				b.SecAcceptFlag,
				b.checktime,
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
				b.WalletType,
				ISNULL(b.RefCode, 0),
				1 AS TableID
			FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_betrunning_custid)
				INNER JOIN @TempCust AS c ON b.custid = c.CustId
				INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
				LEFT JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1
				LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK) ON m3rd.Match3rdId = b.MatchId AND s.EventType = 5
				LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.matchid = o.orid AND b.bettype = 10
				LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
				LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON vr.EventID = b.matchid AND s.EventType = 3
			WHERE b.statusID IN (0, 1)
				AND ((b.bettype IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.livehomescore) + ',%')
					OR (b.bettype NOT IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'))
				AND (@SportTypeList = 'All'
					OR EXISTS (	SELECT 1 FROM #TempSportType
								WHERE SportType = CASE
													WHEN s.EventType = 1 THEN m.sporttype
													WHEN b.bettype = 10 THEN l.sporttype
													WHEN b.bettype IN (9, 29) THEN -1
													WHEN s.ProductId IN (63) THEN b.matchid
													WHEN s.EventType = 5 THEN m3rd.SportType
													WHEN s.EventType = 3 THEN vr.sporttype
													WHEN s.EventType = 0 AND s.RefTable = 3 THEN b.matchid
													WHEN s.EventType = 0 AND s.ProductID IN (27, 83, 88) THEN b.oddsid
													WHEN s.RefTable IN (1, 2) THEN b.matchid
													ELSE 0
												END))
				AND (@LeagueList = 'All'
					OR ',' + @LeagueList + ',' LIKE '%,' + CONVERT(VARCHAR(11), CASE
																					WHEN s.EventType = 1 THEN m.leagueid
																					WHEN b.bettype = 10 THEN o.leagueid
																					ELSE 0
																				END) + ',%')
				AND (@MatchId = 0
					OR b.matchid = @MatchId
					OR b.matchid IN (SELECT MatchId FROM @Match))

			-- translog
			INSERT INTO #Data (
				TransId, RefNo, CustId, Currency, Recommend, BetType, Odds, Stake, Actual_Stake, Status,
				TransDate, WinLostDate, LiveIndicator, Ip, BetFrom, TransDesc, ProductId, Custom1, Custom2, Custom3,
				Gameid3rd, Tranid3rd, TableID
			)
			SELECT
				tl.translogid AS TransId,
				tl.translogid AS RefNo,
				tl.custid,
				tl.currency,
				tl.recommend,
				tl.gameID AS BetType,
				tl.odds,
				tl.stake,
				tl.actual_stake,
				tl.status,
				tl.transdate,
				tl.transdate AS WinLostDate,
				tl.LiveIndicator,
				tl.ip,
				tl.betfrom,
				tl.transdesc,
				tl.productID,
				tl.custom1,
				tl.custom2,
				tl.custom3,
				tl.GameId3rd,
				tl.TranId3rd,
				2 AS TableID
			FROM dbo.translog AS tl WITH (NOLOCK, INDEX = IX_betrunning_custid)
				INNER JOIN @TempCust AS c ON tl.custid = c.CustId
			WHERE tl.statusID IN (0, 1)
				AND (@SportTypeList = 'All'
					OR EXISTS (	SELECT 1 FROM #TempSportType WHERE SportType = tl.productID))
		END

		-- Platform filter
		IF @Platform <> 'All'
		BEGIN
			DELETE b
			FROM #Data AS b
				LEFT JOIN #PlatformList AS pl ON pl.BetFrom = b.BetFrom
				LEFT JOIN #AllPlatformList AS apl ON apl.BetFrom = b.betfrom
			WHERE 1 = CASE
							WHEN pl.BetFrom IS NOT NULL THEN 0
							WHEN apl.BetFrom IS NULL AND ',' + @Platform + ',' LIKE '%,88,%' THEN 0
							WHEN apl.BetFrom IS NULL AND ',' + @Platform + ',' LIKE '%,99,%' THEN 0
							ELSE 1
						END
		END

		-- IP filter
		IF ISNULL(@Ip, '') <> ''
		BEGIN
			DELETE #Data
			WHERE Ip <> @Ip
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

		DELETE b
		FROM #Data AS b
		WHERE NOT EXISTS (SELECT 1 FROM @TempCust WHERE CustId = b.CustId)
			OR NOT EXISTS (SELECT 1 FROM #TempAg WHERE CustId = b.Recommend AND Currency = b.Currency)

		IF EXISTS (SELECT TOP(1) 1 FROM #Data)
		BEGIN
			-- Get original odds and final odds for Mix Parlay
			--============================================================================================================================================
			IF EXISTS (SELECT 1 FROM #Data b WHERE b.BetType = 29 AND b.BetTeam = '1')
			BEGIN
				-- Running
				;WITH CTE_Update AS
				(
					SELECT b.TransId, TRY_CAST(b.ExtraInfo AS XML).value('(/p1/@o)[1]', 'MONEY') AS OriginalOdds
					FROM #Data b
					WHERE b.BetType = 29 AND b.BetTeam = '1' AND b.Status IN ('Running', 'Waiting')
				)
				UPDATE b
				SET
					b.Odds = ISNULL(t.OriginalOdds, 0),
					b.Modds = ISNULL(t.OriginalOdds, 0)
				FROM #Data AS b
					INNER JOIN CTE_Update t ON t.TransId = b.TransId

				-- Settled
				;WITH CTE_Update AS
				(
					SELECT b.TransId, TRY_CAST(b.ExtraInfo AS XML).value('(/p1/@o)[1]', 'MONEY') AS OriginalOdds
					FROM #Data b
					WHERE b.BetType = 29 AND b.BetTeam = '1' AND b.Status NOT IN ('Running', 'Waiting')
				)
				UPDATE b
				SET
					b.Odds = ISNULL(t.OriginalOdds, bpr.Odds),
					b.Modds = CASE 
								WHEN bpr.statusid = 113 AND bpr.mOdds = 0 THEN ISNULL(t.OriginalOdds, bpr.Odds)
								ELSE bpr.mOdds 
							END
				FROM #Data AS b
					INNER JOIN CTE_Update t ON t.TransId = b.TransId
					INNER JOIN dbo.BetParlayResult AS bpr WITH (NOLOCK) ON bpr.RefNo = b.RefNo
			END
			--============================================================================================================================================

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
							WHEN s.ProductID = 34 THEN 'CC'								-- Card Club(Arcadia Gaming)
							WHEN s.ProductID = 36 THEN 'SG'								-- Spadegaming
							WHEN s.ProductID = 38 THEN 'VRG'							-- Virtual Games
							WHEN s.ProductID = 39 THEN 'SAG'							-- SA Gaming
							WHEN s.ProductID = 40 THEN 'TG'								-- Table Games
							WHEN s.ProductID = 42 THEN 'SBC'							-- Saba.club
							WHEN s.ProductID = 43 THEN 'I4D'							-- Indo 4D
							WHEN s.ProductID = 45 THEN 'SXG'							-- Sexy Gaming
							WHEN s.ProductID = 49 THEN 'VS3'							-- Virtual Sports 3 (Old)
							WHEN s.ProductID = 51 THEN 'WM'								-- WM Live Casino
							WHEN s.ProductID = 55 THEN 'PGS'							-- PG Soft
							WHEN s.ProductID = 56 THEN 'JK'								-- Joker
							WHEN s.ProductID = 57 THEN 'BG'								-- Big Gaming
							WHEN s.ProductID = 60 THEN 'MXG'							-- MaxGame
							WHEN s.ProductID = 61 THEN 'HB'								-- Habanero
							WHEN s.ProductID = 62 THEN 'CG'								-- CG
							WHEN s.ProductID = 63 THEN 'SLT'							-- Sports Lottery
							WHEN s.ProductID = 66 THEN 'VGA'							-- Vgaming
							WHEN s.ProductID = 67 THEN 'AP'								-- AdvantPlay
							WHEN s.ProductID = 68 THEN 'APM'							-- AdvantPlay Mini
							WHEN s.ProductID = 69 THEN 'BTC'							-- Bitcoin
							WHEN s.ProductID = 70 THEN 'FGGL'							-- FGG
							WHEN s.ProductId = 72 THEN 'SEA'							-- SEAL Entertainment
							WHEN s.ProductID = 73 THEN 'MGRNG'							-- MG-RNG
							WHEN s.ProductID = 75 THEN 'JIG'							-- Jili
							WHEN s.ProductID = 76 THEN 'YB'								-- YeeBet
							WHEN s.ProductID = 77 THEN 'LG'								-- Virtual Sports 3
							WHEN s.EventType = 0 AND s.ProductID = 1 THEN 'Parlay'		-- Sportsbook Parlay
							WHEN s.EventType = 0 AND s.ProductID = 3 THEN 'H5LG'		-- Happy 5 Linked Games (Number Game)
							WHEN s.EventType = 0 AND s.ProductID = 27 THEN 'ParlayVS2'	-- Betradar Virtual Sports Parlay
							WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'			-- Sportsbook
							WHEN s.EventType = 1 AND s.ProductID = 3 THEN 'NG'			-- Number Game
							WHEN s.EventType = 1 AND s.ProductID = 5 THEN 'VS'			-- Virtual Sports Sportsbook
							WHEN s.EventType = 1 AND s.ProductID = 27 THEN 'VS2'		-- Betradar Virtual Sports
							WHEN s.EventType = 2 AND s.ProductID = 1 THEN 'Outright'
							ELSE 'Unknown'
						END,
				RefTable = s.RefTable,
				EventType = s.EventType,
				SubProduct = s.SubProduct
			FROM #Data AS b
				INNER JOIN @SportBettype AS s ON b.bettype = s.bettype

			IF @StatusFilter <> '1,2,3'
			BEGIN
				UPDATE b
				SET b.SettlementStatus = m.SettlementStatus
				FROM #Data AS b
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.Product = 'SB' AND m.matchid = b.matchid

				IF ',' + @StatusFilter + ',' NOT LIKE '%,1,%'	-- Not include Running, Waiting
				BEGIN
					DELETE #Data
					WHERE Product <> 'SB'
						OR (Product = 'SB'
							AND (Status = 'Waiting'																										-- Waiting
								OR (Status = 'Running' AND ISNULL(SecAcceptFlag, 0) = 1 AND ISNULL(CheckTime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)	-- Waiting (Second Accept)
								OR (Status = 'Running' AND ISNULL(SettlementStatus, 0) & 13 = 0)								-- Running (normal)
								OR (Status = 'Running'			-- Cash Out All
									AND Stake = 0
									AND BetdaqId = 0
									AND ExtraInfo LIKE '%p25%')))
				END
				
				IF ',' + @StatusFilter + ',' NOT LIKE '%,2,%'		-- Not include Delay Payout
					OR ',' + @StatusFilter + ',' NOT LIKE '%,3,%'	-- Not include Under Settlement
				BEGIN
					DELETE #Data
					WHERE Product = 'SB'
						AND Status = 'Running'
						AND (ISNULL(SecAcceptFlag, 0) = 0 OR ISNULL(CheckTime, CURRENT_TIMESTAMP) <= CURRENT_TIMESTAMP)
						AND (Stake <> 0						-- Not Cash Out All
							OR BetdaqId <> 0
							OR ExtraInfo NOT LIKE '%p25%')
						AND ((',' + @StatusFilter + ',' NOT LIKE '%,2,%' AND ISNULL(SettlementStatus, 0) & 1 <> 0)			-- Delay Payout
							OR (',' + @StatusFilter + ',' NOT LIKE '%,3,%'
								AND ISNULL(SettlementStatus, 0) & 12 <> 0
								AND ISNULL(SettlementStatus, 0) & 1 = 0))		-- Under Settlement
				END
			END

			DELETE #Data
			WHERE Product IS NULL
				OR BetType IN (901, 902, 903, 904, 911, 912, 913, 914)
				OR BetType BETWEEN 801 AND 899

			-- Check Saba Virtual Sports
			IF @SportTypeList <> 'All'
				AND EXISTS ( SELECT 1
							FROM @SabaSportType AS s
								INNER JOIN #TempSportType AS t ON t.SportType = s.SportType)
			BEGIN
				-- Get event info
				UPDATE b
				SET SportType = m.sporttype,
					LeagueId = m.leagueid,
					LeagueGroupId = l.LeagueGroupID
				FROM #Data AS b
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId
					INNER JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
				WHERE b.Product = 'SB'

				UPDATE b
				SET SportType = l.sporttype,
					LeagueId = l.leagueid,
					LeagueGroupId = l.LeagueGroupID
				FROM #Data AS b
					INNER JOIN dbo.outright AS o WITH (NOLOCK) ON o.orid = b.MatchId
					INNER JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = o.leagueid
				WHERE b.Product = 'Outright'

				-- Special league group
				DELETE b
				FROM #Data AS b
				WHERE b.Product IN ('SB', 'Outright')
					AND EXISTS (SELECT 1 FROM @SabaSportType
								WHERE SportType = b.SportType
									AND ',' + LeagueGroupIdList + ',' LIKE '%,' + CONVERT(VARCHAR(6), b.LeagueGroupId) + ',%')
					AND NOT EXISTS (SELECT 1 FROM #TempSportType
									WHERE SportType = b.SportType
										AND ',' + LeagueGroupIdList + ',' LIKE '%,' + CONVERT(VARCHAR(11), b.LeagueGroupId) + ',%')

				-- Normal league group
				DELETE b
				FROM #Data AS b
				WHERE b.Product IN ('SB', 'Outright')
					AND NOT EXISTS (SELECT 1 FROM @SabaSportType
									WHERE SportType = b.SportType
										AND ',' + LeagueGroupIdList + ',' LIKE '%,' + CONVERT(VARCHAR(6), b.LeagueGroupId) + ',%')
					AND NOT EXISTS (SELECT 1 FROM #TempSportType
									WHERE SportType = b.SportType AND LeagueGroupIdList = '0')
			END

			IF ',' + @StatusFilter + ',' LIKE '%,1,%'	-- Yesterday and today bettransRnG/bettransLC running tickets
			BEGIN
				IF @Username IS NULL OR @Username = '' OR @NumOfMem > 5000		-- Licensee level (not input username of number of searched member > 5000)
				BEGIN
					-- bettransRnG
					INSERT INTO @TmpData
					(
						RefNo,
						BetType,
						Odds,
						OddsSpread,
						Stake,
						Actual_Stake,
						IsNew
					)
					SELECT
						rng.RefNo,
						rng.gameID AS BetType,
						CASE
							WHEN s.ProductID IN (6, 32, 42, 66, 100) THEN ISNULL(AVG(CASE WHEN statusID IN (111, 112, 113) THEN ContributionRate END), 0)
							ELSE 0
						END AS Odds,
						CASE
							WHEN s.ProductID IN (6, 32, 42, 66, 100) THEN ISNULL(SUM(BetStake), 0)
							ELSE 0
						END AS OddsSpread,
						SUM(rng.stake) AS Stake,
						SUM(rng.actual_stake) AS Actual_Stake,
						1 AS IsNew
					FROM dbo.bettransRnG AS rng WITH (NOLOCK)
						INNER JOIN #TempAg AS a ON a.CustId = rng.recommend
						INNER JOIN @SportBettype AS s ON rng.gameID = s.bettype
					WHERE rng.winlostdate >= @Yesterday AND rng.statusID IN (0, 1)
					GROUP BY rng.RefNo,
						rng.gameID,
						s.ProductID

					-- bettransLC
					INSERT INTO @TmpData
					(
						RefNo,
						BetType,
						Odds,
						OddsSpread,
						Stake,
						Actual_Stake,
						IsNew
					)
					SELECT
						lc.RefNo,
						lc.gameID AS BetType,
						CASE
							WHEN s.SubProduct LIKE '%Jackpot%' THEN ISNULL(AVG(CASE WHEN statusID IN (111, 112, 113) THEN ContributionRate END), 0)
							ELSE 0
						END AS Odds,
						CASE
							WHEN s.SubProduct LIKE '%Jackpot%' THEN ISNULL(SUM(BetStake), 0)
							ELSE 0
						END AS OddsSpread,
						SUM(lc.stake) AS Stake,
						SUM(lc.actual_stake) AS Actual_Stake,
						1 AS IsNew
					FROM dbo.bettransLC AS lc WITH (NOLOCK)
						INNER JOIN #TempAg AS a ON a.CustId = lc.recommend
						INNER JOIN @SportBettype AS s ON lc.gameID = s.bettype
					WHERE lc.winlostdate >= @Yesterday AND lc.statusID IN (0, 1)
					GROUP BY lc.RefNo,
						lc.gameID,
						s.SubProduct
				END
				ELSE
				BEGIN
					-- bettransRnG
					INSERT INTO @TmpData
					(
						RefNo,
						BetType,
						Odds,
						OddsSpread,
						Stake,
						Actual_Stake,
						IsNew
					)
					SELECT
						rng.RefNo,
						rng.gameID AS BetType,
						CASE
							WHEN s.ProductID IN (6, 32, 42, 66, 100) THEN ISNULL(AVG(CASE WHEN statusID IN (111, 112, 113) THEN ContributionRate END), 0)
							ELSE 0
						END AS Odds,
						CASE
							WHEN s.ProductID IN (6, 32, 42, 66, 100) THEN ISNULL(SUM(BetStake), 0)
							ELSE 0
						END AS OddsSpread,
						SUM(rng.stake) AS Stake,
						SUM(rng.actual_stake) AS Actual_Stake,
						1 AS IsNew
					FROM dbo.bettransRnG AS rng WITH (NOLOCK)
						INNER JOIN @TempCust AS a ON a.CustId = rng.custid
						INNER JOIN @SportBettype AS s ON rng.gameID = s.bettype
					WHERE rng.winlostdate >= @Yesterday AND rng.statusID IN (0, 1)
					GROUP BY rng.RefNo,
						rng.gameID,
						s.ProductID

					-- bettransLC
					INSERT INTO @TmpData
					(
						RefNo,
						BetType,
						Odds,
						OddsSpread,
						Stake,
						Actual_Stake,
						IsNew
					)
					SELECT
						lc.RefNo,
						lc.gameID AS BetType,
						CASE
							WHEN s.SubProduct LIKE '%Jackpot%' THEN ISNULL(AVG(CASE WHEN statusID IN (111, 112, 113) THEN ContributionRate END), 0)
							ELSE 0
						END AS Odds,
						CASE
							WHEN s.SubProduct LIKE '%Jackpot%' THEN ISNULL(SUM(BetStake), 0)
							ELSE 0
						END AS OddsSpread,
						SUM(lc.stake) AS Stake,
						SUM(lc.actual_stake) AS Actual_Stake,
						1 AS IsNew
					FROM dbo.bettransLC AS lc WITH (NOLOCK)
						INNER JOIN @TempCust AS a ON a.CustId = lc.custid
						INNER JOIN @SportBettype AS s ON lc.gameID = s.bettype
					WHERE lc.winlostdate >= @Yesterday AND lc.statusID IN (0, 1)
					GROUP BY lc.RefNo,
						lc.gameID,
						s.SubProduct
				END

				-- Delete settled only summary ticket
				DELETE b
				FROM #Data AS b
				WHERE b.RefTable IN (1, 2)
					AND b.WinLostDate >= @Yesterday
					AND NOT EXISTS (SELECT 1 FROM @TmpData WHERE RefNo = b.TransId)

				-- Update tickets EXISTS in #Data
				UPDATE b
				SET b.IsNew = 0
				FROM @TmpData AS b
					INNER JOIN #Data AS d ON d.TransId = b.RefNo AND d.BetType = b.BetType
				WHERE d.WinLostDate >= @Yesterday AND d.RefTable IN (1, 2)

				INSERT INTO #Data (
					TransId, RefNo, CustId, Currency, Recommend, BetType, BetId, BetTeam, Hdp1, Hdp2,
					OddsId, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, Status, SecAcceptFlag, CheckTime,
					TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, BetFrom, MatchId, BetCheck, ComStatus,
					TransDesc, BetdaqId, ExtraInfo, WalletType, RefCode, TableID, Product, RefTable, EventType
				)
				SELECT
					b.transid,
					b.refno,
					b.custid,
					b.currency,
					b.recommend,
					b.bettype,
					ISNULL(b.betid, 0) AS BetId,
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
					b.status,
					b.SecAcceptFlag,
					b.checktime,
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
					b.WalletType,
					ISNULL(b.RefCode, 0),
					1 AS TableID,
					CASE
						WHEN s.ProductID = 6 THEN 'OneRNG'	-- RNG Casino
						WHEN s.ProductID = 21 THEN 'AllBet'
						WHEN s.ProductID = 22 THEN 'VB'		-- Macau Games
						WHEN s.ProductID = 32 THEN 'PP'		-- Pragmatic Play Casino
						WHEN s.ProductID = 34 THEN 'CC'		-- Card Club (Arcadia Gaming)
						WHEN s.ProductID = 36 THEN 'SG'		-- Spadegaming
						WHEN s.ProductID = 39 THEN 'SAG'	-- SA Gaming
						WHEN s.ProductID = 42 THEN 'SBC'	-- Saba.club
						WHEN s.ProductID = 45 THEN 'SXG'	-- Sexy Gaming
						WHEN s.ProductID = 51 THEN 'WM'		-- WM Live Casino
						WHEN s.ProductID = 55 THEN 'PGS'	-- PG Soft
						WHEN s.ProductID = 56 THEN 'JK'		-- Joker
						WHEN s.ProductID = 57 THEN 'BG'		-- Big Gaming
						WHEN s.ProductID = 60 THEN 'MXG'	-- MaxGame
						WHEN s.ProductID = 61 THEN 'HB'		-- Habanero
						WHEN s.ProductID = 62 THEN 'CG'		-- CG
						WHEN s.ProductID = 66 THEN 'VGA'	-- Vgaming
						WHEN s.ProductID = 67 THEN 'AP'		-- AdvantPlay
						WHEN s.ProductID = 68 THEN 'APM'	-- AdvantPlay Mini
						WHEN s.ProductID = 70 THEN 'FGGL'	-- FGG
						WHEN s.ProductId = 72 THEN 'SEA'	-- SEAL Entertainment
						WHEN s.ProductID = 73 THEN 'MGRNG'	-- MG-RNG
						WHEN s.ProductID = 75 THEN 'JIG'	-- Jili
						WHEN s.ProductID = 76 THEN 'YB'		-- YeeBet
						ELSE 'Unknown'
					END AS Product,
					s.RefTable,
					s.EventType
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @TmpData AS t ON t.RefNo = b.transid AND t.BetType = b.BetType
					INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
					LEFT JOIN #PlatformList AS pl ON pl.BetFrom = b.betfrom
					LEFT JOIN #AllPlatformList AS apl ON apl.BetFrom = b.betfrom
				WHERE t.IsNew = 1
					AND 1 = CASE
								WHEN @Platform = 'All' THEN 1
								WHEN pl.BetFrom IS NOT NULL THEN 1
								WHEN apl.BetFrom IS NULL AND ',' + @Platform + ',' LIKE '%,88,%' THEN 1
								WHEN apl.BetFrom IS NULL AND ',' + @Platform + ',' LIKE '%,99,%' THEN 1
								ELSE 0
							END
					AND (ISNULL(@Ip, '') = '' OR b.ip = @Ip)
					AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'
					AND (@SportTypeList = 'All'
						OR EXISTS (	SELECT 1 FROM #TempSportType
									WHERE SportType = CASE
														WHEN s.RefTable IN (1, 2) THEN b.matchid
														ELSE 0
													END))

				IF @Username IS NULL OR @Username = ''
				BEGIN
					DELETE FROM @TempCust

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

				DELETE b
				FROM #Data AS b
				WHERE NOT EXISTS (SELECT 1 FROM @TempCust WHERE CustId = b.CustId)
					OR NOT EXISTS (SELECT 1 FROM #TempAg WHERE CustId = b.Recommend AND Currency = b.Currency)
			END

			-- Get data for summary ticket of multiple Bonus/Cash sub tickets
			IF EXISTS (SELECT 1 FROM #Data WHERE RefCode <> 0)
			BEGIN
				DECLARE @RefCodeTmp TABLE (
					RefCode	BIGINT,
					TransId	BIGINT,
					Stake	MONEY
				)

				-- Prepare temp table
				INSERT INTO @RefCodeTmp (RefCode, TransId, Stake)
				SELECT
					RefCode,
					MIN(TransId) AS TransId,
					SUM(Stake) AS Stake
				FROM #Data
				WHERE RefCode <> 0
				GROUP BY RefCode
				HAVING COUNT(*) > 1

				IF EXISTS (SELECT 1 FROM @RefCodeTmp)
				BEGIN
					-- Update data for summmary ticket
					UPDATE b
					SET
						b.Stake = r.Stake,
						b.WalletType = 0
					FROM #Data AS b
						INNER JOIN @RefCodeTmp AS r ON b.RefCode = r.RefCode AND b.TransId = r.TransId

					-- Delete 2nd Bonus/Cash tickets
					DELETE #Data
					WHERE WalletType <> 0
						AND RefCode IN (SELECT RefCode FROM @RefCodeTmp)
				END
			END

			-- Display detail link for ticket from Bonus Wallet only
			UPDATE #Data
			SET RefCode = TransId
			WHERE WalletType = 1 AND RefCode = 0

			-- Don't display Cash text for ticket from Cash Wallet only
			UPDATE #Data
			SET WalletType = 0
			WHERE WalletType = 2 AND RefCode = 0

			-- Get exchange rate
			INSERT INTO #ExchangeRate (ExchangeId, Rate)
			SELECT
				e.ExchangeId,
				e.Rate
			FROM dbo.Lrf_f_GetExchangeRate(DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0), DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0), @BaseCurrency, '') AS e
			WHERE EXISTS (SELECT 1 FROM #Data WHERE Currency = e.ExchangeId)

			DECLARE @SortText VARCHAR(100)

			-- Get sort text
			SET @SortText = CASE
								WHEN @SortType = 0 THEN 'TransDate'
								WHEN @SortType = 1 THEN 'Stake'
								ELSE ''
							END

			IF @BaseCurrency <> '' AND @SortType = 1
			BEGIN
				SET @SortText = @SortText + ' * ISNULL(e.Rate, 1)'
			END

			SET @SortText = @SortText + ' ' + CASE
												WHEN @SortOrder = 1 THEN 'ASC'
												WHEN @SortOrder = 2 THEN 'DESC'
												ELSE ''
											END

			-- Return data
			SELECT
				@TotalRows = COUNT(b.TransId),
				@SumStake = SUM(b.Stake * ISNULL(e.Rate, 1))
			FROM #Data AS b
				LEFT JOIN #ExchangeRate AS e ON e.ExchangeId = b.Currency

			IF @ConvertToBaseCur = 0
			BEGIN
				DELETE FROM #ExchangeRate
			END

			DECLARE @RowStart INT,
				@RowEnd INT

			SELECT @PageIndex = @PageIndex - 1,
				@RowStart = @PageSize * @PageIndex + 1,
				@RowEnd = @RowStart + @PageSize - 1

			DECLARE @Sql NVARCHAR(2000)

			SET @Sql = 
				N'SELECT a.*
				FROM
					(
						SELECT
							ROW_NUMBER() OVER (ORDER BY ' + @SortText +') AS RowNum,
							d.*
						FROM #Data AS d' +
						CASE
							WHEN @SortText LIKE '%e.Rate%' THEN N'
							LEFT JOIN #ExchangeRate AS e ON e.ExchangeId = d.Currency'
							ELSE N' '
						END + N'
					) AS a
				WHERE a.RowNum BETWEEN @RowStart AND @RowEnd
				ORDER BY a.RowNum ASC'

			INSERT INTO #PagingData
			(
				RowNum, TransId, RefNo, CustId, Currency, Recommend, SportType, BetType, BetId, BetTeam,
				Hdp1, Hdp2, OddsId, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, Status,
				SettlementStatus, SecAcceptFlag, CheckTime, TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, BetFrom,
				LeagueId, LeagueGroupId, MatchId, MatchCode, Race, EventDate, HomeId, AwayId, BetStatus, IsNeutral,
				Placing, ShowTime, BetCheck, ComStatus, TransDesc, BetdaqId, ExtraInfo, OriginalStake, OriginalBetType, WalletType,
				RefCode, ProductId, Custom1, Custom2, Custom3, Gameid3rd, Tranid3rd, TableID, Product, SubProduct,
				RefTable, EventType
			)
			EXEC sp_executesql @Sql, N'@RowStart INT, @RowEnd INT', @RowStart, @RowEnd;

			UPDATE p
			SET
				SportType = CASE
								WHEN p.Product IN ('VB', 'PP', 'CC', 'SG', 'OneRNG', 'Allbet', 'SBC', 'SXG', 'SAG', 'PGS', 'JK', 
									'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM', 'FGGL', 'MXG', 'JIG', 'YB', 'MGRNG', 'SEA') THEN p.MatchId
								WHEN p.Product IN ('Keno', 'Lottery', 'TG', 'I4D', 'VRG', 'H5LG', 'SLT', 'VS3') THEN p.ProductId
								WHEN p.Product IN ('Outright') THEN l.sporttype
								WHEN p.EventType = 1 THEN m.sporttype
								WHEN p.EventType = 3 THEN vr.SportType
								WHEN p.EventType = 5 THEN m3rd.SportType
								WHEN p.RefTable IN (1, 2) THEN p.MatchId
								ELSE 0
							END,
				Odds = CASE
							WHEN p.Product IN ('OneRNG', 'PP', 'SBC', 'VGA') AND x.Odds IS NOT NULL THEN x.Odds
							WHEN p.SubProduct LIKE '%Jackpot%' AND x.Odds IS NOT NULL THEN x.Odds
							ELSE p.Odds
						END,
				OddsSpread = CASE
								WHEN p.Product IN ('OneRNG', 'PP', 'SBC', 'VGA') AND x.OddsSpread IS NOT NULL THEN x.OddsSpread
								WHEN p.SubProduct LIKE '%Jackpot%' AND x.OddsSpread IS NOT NULL THEN x.OddsSpread
								WHEN p.Product IN ('SB', 'Parlay') THEN ISNULL(p.oddsspread, 0)
								ELSE 0
							END,
				Stake = CASE
							WHEN p.RefTable IN (1, 2) AND x.Stake IS NOT NULL THEN x.Stake
							ELSE p.stake 
						END,
				Actual_Stake = CASE
									WHEN p.RefTable IN (1, 2) AND x.Actual_Stake IS NOT NULL THEN x.Actual_Stake
									ELSE p.actual_stake
								END,
				Status = CASE
							WHEN p.RefTable IN (1, 2) AND x.RefNo IS NOT NULL THEN 'Running'
							WHEN p.Product = 'SB'
								AND p.status = 'running' AND ISNULL(p.SecAcceptFlag, 0) = 1 AND ISNULL(p.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
							WHEN p.Product = 'Parlay' AND p.status = 'running' THEN
								CASE
									WHEN EXISTS (SELECT 1 FROM dbo.bettransm AS bm WITH (NOLOCK)
												WHERE bm.custid = p.custid
													AND bm.refno = p.refno
													AND (bm.status = 'waiting'
														OR (bm.status = 'running' AND ISNULL(bm.SecAcceptFlag, 0) = 1 AND ISNULL(bm.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)))
										THEN 'Waiting'
									ELSE p.status
								END
							ELSE p.status
						END,
				SettlementStatus = CASE
										WHEN p.Product IN ('SB') THEN ISNULL(m.SettlementStatus, 0)
										ELSE 0
									END,
				LeagueId = CASE
								WHEN p.EventType = 1 THEN m.leagueid
								WHEN p.EventType = 5 THEN m3rd.League3rdId
								WHEN p.Product IN ('Outright') THEN o.leagueid
								WHEN p.EventType = 3 THEN vr.LeagueID
								ELSE 0
							END,
				LeagueGroupId = CASE
									WHEN p.Product IN ('SB') THEN le.LeagueGroupID
									ELSE 0
								END,
				MatchCode = CASE
								WHEN p.EventType = 1 THEN m.matchcode
								WHEN p.Product IN ('Outright') THEN o.matchcode
								ELSE ''
							END,
				Race = CASE
							WHEN p.Product IN ('Outright') THEN o.groupmatch
							ELSE ''
						END,
				EventDate = CASE
								WHEN p.Product IN ('SB') THEN m.GlobalShowTime
								WHEN p.Product IN ('BTC') THEN m3rd.EndTime
								ELSE p.WinLostDate
							END,
				HomeId = CASE
							WHEN p.EventType = 1 THEN m.homeid
							WHEN p.EventType = 5 THEN m3rd.HomeId
							WHEN p.Product IN ('Outright') THEN o.teamid
							ELSE 0
						END,
				AwayId = CASE
							WHEN p.EventType = 1 THEN m.awayid
							WHEN p.EventType = 5 THEN m3rd.AwayId
							ELSE 0
						END,
				BetStatus = CASE
								WHEN p.EventType = 1 THEN m.betstatus
								ELSE ''
							END,
				IsNeutral = CASE
								WHEN p.EventType = 1 THEN ISNULL(m.IsNeutral, 0)
								ELSE 0
							END,
				Placing = '',
				ShowTime = CASE
								WHEN p.Product IN ('VS') THEN CONVERT(NVARCHAR(50), m.kickofftime)
								WHEN p.EventType = 5 THEN CONVERT(NVARCHAR(50), m3rd.StartTime)
								ELSE ''
							END,
				BetCheck = CASE
								WHEN p.Product IN ('SB') THEN ISNULL(p.betcheck, '')
								WHEN p.Product IN ('Keno') THEN ISNULL(p.custom2, '')
								WHEN p.Product IN ('VRG', 'SLT') THEN ISNULL(p.TranId3rd, '')
								WHEN p.Product IN ('H5LG') THEN ISNULL(p.Gameid3rd, '')
								WHEN p.Product IN ('VS3') THEN ISNULL(p.Custom1, '')
								WHEN p.EventType = 0 AND p.RefTable = 0 THEN ISNULL(p.betcheck, '')
								ELSE ''
							END,
				TransDesc = CASE
								WHEN p.Product IN ('Parlay', 'Keno', 'Lottery', 'OneRNG', 'VB', 'PP', 
									'CC', 'SG', 'VRG', 'TG', 'PGS', 'JK', 'H5LG', 'SLT', 'HB', 'CG', 'AP', 'APM', 'SEA') THEN ISNULL(p.transdesc, '')
								WHEN p.EventType IN (1, 3, 5) THEN ISNULL(p.transdesc, '')
								ELSE ''
							END,
				BetdaqId = CASE
								WHEN p.Product IN ('SB') THEN ISNULL(p.betdaqid, -1)
								ELSE -1
							END,
				OriginalStake = 0,
				OriginalBetType = CASE
									WHEN p.Product IN ('SB') AND p.stake <> 0 THEN -1
									ELSE 0
								END,
				WalletType = CASE
								WHEN p.Product IN ('SB') THEN ISNULL(p.WalletType, 0)
								ELSE 0
							END,
				RefCode = CASE
								WHEN p.Product IN ('SB') AND p.stake <> 0 THEN ISNULL(p.RefCode, 0)
								ELSE 0
							END
			FROM #PagingData AS p
				LEFT JOIN @TmpData AS x
					ON p.RefTable IN (1, 2)
					AND p.Winlostdate >= @Yesterday
					AND x.RefNo = p.TransId
				LEFT JOIN dbo.match AS m WITH (NOLOCK) ON p.EventType = 1 AND p.matchid = m.matchid
				LEFT JOIN dbo.League AS le WITH (NOLOCK) ON p.Product IN ('SB') AND le.leagueid = m.leagueid
				LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK) ON p.EventType = 5 AND m3rd.Match3rdId = p.matchid
				LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON p.Product IN ('Outright') AND p.matchid = o.orid
				LEFT JOIN dbo.League AS l WITH (NOLOCK) ON p.Product IN ('Outright') AND o.leagueID = l.leagueID
				LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON p.EventType = 3 AND vr.EventID = p.matchid
		END
	END

	SELECT
		c.username,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS NickName,
		a.TransId,
		a.RefNo,
		a.BetId,
		a.CustId,
		a.TransDate,
		a.WinLostDate,
		a.SportType,
		a.BetType,
		a.BetTeam,
		a.Hdp1,
		a.Hdp2,
		a.Odds,
		a.MOdds,
		a.OddsType,
		a.OddsSpread,
		a.Status,
		a.SettlementStatus,
		a.LiveIndicator,
		a.LiveHomeScore,
		a.LiveAwayScore,
		a.Race,
		a.LeagueId,
		a.LeagueGroupId,
		a.MatchId,
		a.MatchCode,
		a.EventDate,
		a.HomeId,
		a.AwayId,
		a.IsNeutral,
		a.Placing,
		a.BetStatus,
		a.ShowTime,
		a.Currency,
		CAST(a.Stake * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS Stake,
		CAST(a.Actual_Stake * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS Actual_Stake,
		a.Ip,
		a.BetFrom,
		a.BetCheck,
		a.TransDesc,
		a.BetdaqId,
		a.ExtraInfo,
		a.OriginalStake * ISNULL(e.Rate, 1) AS OriginalStake,
		a.OriginalBetType,
		a.WalletType,
		a.RefCode
	FROM
		#PagingData AS a
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = a.CustId
		LEFT JOIN #ExchangeRate AS e ON e.ExchangeId = a.Currency
	ORDER BY a.RowNum ASC

	SELECT DISTINCT
		RefNo,
		Odds,
		Stake,
		Status,
		APositionTaking,
		BetType,
		BetTeam
	FROM @Detail

	DROP TABLE #TempAg
	DROP TABLE #Data
	DROP TABLE #PagingData
	DROP TABLE #ExchangeRate
	DROP TABLE #TempSportType
	DROP TABLE #TempBetType
	DROP TABLE #AllPlatformList
	DROP TABLE #PlatformList
END
