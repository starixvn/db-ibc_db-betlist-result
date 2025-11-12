/*<info serverAlias="DBACC-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_Mem]
	@AgentList		VARCHAR(MAX),
	@CustId			INT				= 0,
	@Username		VARCHAR(50)		= '',
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@BaseCurrency	VARCHAR(12)		= '',
	@StatusIdList	VARCHAR(50)		= '',
	@Platform		VARCHAR(100)	= 'All',
	@LiveIndicator	VARCHAR(10)		= '0,1,2',
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 1,
	@SortType		TINYINT			= 0,		-- TransDate
	@SortOrder		TINYINT			= 1,		-- ASC
	@ProductList	VARCHAR(MAX)	= '',
	@SportTypeList	VARCHAR(MAX)	= 'All',
	@BetTypeList	VARCHAR(MAX)	= 'All',
	@CashoutMode	TINYINT			= 0,
	@TotalRows		INT				= 0 OUTPUT,
	@SumStake		MONEY			= 0 OUTPUT,
	@SumWinLost		MONEY			= 0 OUTPUT,
	@SumLicenseeWL	MONEY			= 0 OUTPUT,
	@SumComm		MONEY			= 0 OUTPUT,
	@SumPlayerComm	MONEY			= 0 OUTPUT
AS

/*
	Created: Kos@20180613
	Task: Betting Ticket Center - Single Customer Bet List
	DB: DBACC.bodb02
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
		- @Platform:
			- All - All: All
			- 1 - Desktop New Asia: x (dep2-Asia)
			- 2 - Desktop China: a (dep-Singbet), z (dep2-SingBet)
			- 3 - Desktop Others: 9 (3rd Party Portal Service - Desktop)
			- 4 - Mobile Standard: l (dep-smart), _ (Quick Bet)
			- 5 - Mobile Euro: % (Mobile Euro)
			- 6 - Mobile Compact: c (dep-MCV), @ (Quick Bet)
			- 7 - Mobile Others: 7 (3rd Party Portal Service - Facebook Wall), 8 (3rd Party Portal Service - Statement AD)
			- 8 - E-Sports Desktop: 1 (E-Sports Web Desktop), 4 (eGamer Desktop)
			- 9 - E-Sports Mobile: 2 (E-Sports Web Mobile), 5 (eGamer Mobile)
			- 10 - E-Sports APP: 3 (E-Sports App), 6 (eGamer App)
			- 11 - Mobile APP: o (dep-New Mobile APP)
			- 12 - Native APP: 0 (Native App)
			- 13 - Tablet: r (dep2-tablet)
			- 14 - Deep Link: t (Licensee-Deeplink)
			- 15 - WAP: m (dep-wap)
			- 88 - Others: v (Licensee Odds Feed), d (mobile), g (MG Download only), e (Europe), u (dep-Euro)
		- @LiveIndicator:
			- 0 : Non-live
			- 1 : Live
			- 2 : Mix Non Live & Live (Parlay only)
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
		- @CashoutMode:
			+ 0: Include
			+ 1: Exclude
			+ 2: View CO only
		- @SortType:
			- 0: TransDate
			- 1: Stake
			- 2: WinLoss
			- 3: LicenseeWL
		- @SortOrder
			- 1: ASC
			- 2: DESC

	Revisions:
		- 20180711@Kos: Created [#Redmine: 80941]
		- 20181102@Kos: Remove DBLIC linked server [#Redmine: 103660]
		- 20181113@Kos: Support new platform 'o' Mobile App [#Redmine: 104521]
		- 20181210@Kos: Support new platform 'c' Mobile China View [#Redmine: 106088]
		- 20190121@Kos: Betting Ticket Center phase 3a [Redmine: #103555]
		- 20190305@Kos: Change param @LiveIndicator from TINYINT to VARCHAR(10) [Redmine: #108717]
		- 20190426@Kos: Support base currency INH [Redmine: #112603]
		- 20190509@Kos: Fix licensee WL for BA tickets in bettrans14/bk range [Redmine: #113083]
		- 20190515@Kos: Show match KO time for single ticket [Redmine: #112731]
					- Return additional column EventDate DATETIME
		- 20190627@Kos: Support PH AIO 4a [Redmine: #115448]
		- 20190829@Kos: Support betfrom Deeplink 't' [Redmine: #115448]
					- Remove betfrom 's' and 'y'
		- 20191216@Kos: Support betfrom Licensee Odds Feed 'v' [Redmine: #125553]
		- 20191226@Kos: Support betfrom Native Apps '0' [Redmine: #125824]
		- 20200207@Kos: Support sort by trans time [Redmine: #126886]
		- 20200302@Kos: Support 3 new betfrom [Redmine: #129253]
		- 20200402@Kos: Support Table Games [Redmine: #131447]
		- 20200416@Kos: Support Indo 4D [Redmine: #130859]
		- 20200425@Kos: Support status Delay Payout [Redmine: #132629]
		- 20200502@Kos: Support Table Game Half Won Half Lose [Redmine: #133323]
		- 20200525@Kos: Support show licensee transaction ID [Redmine: #134629]
		- 20200619@Kos: Support 3 new eGamer betfrom [Redmine: #136107]
		- 20200623@Kos: Integrate archive process for table VSRaceInfo [Redmine: #136285]
		- 20201210@Kos: Exclude bettype 999 Odds Spread Adjustment [Redmine: #142532]
		- 20201231@Kos: Support Virtual Games [Redmine: #147843]
		- 20210108@Kos: Support Happy 5 Linked Games [Redmine: #147446]
		- 20210122@Kos: Support betfrom '7' [Redmine: #149108]
		- 20210301@Kos: Add BDT and INR as base currencies [Redmine: 150375]
		- 20210309@Kos: Support betfrom '_', '@', '%' [Redmine: #151019]
		- 20210311@Kos: Support Sports Lottery [Redmine: #150872]
		- 20210325@Kos: Support betfrom '8', '9' [Redmine: #152158]
		- 20210518@Kos: Support multiple selection on Platform filter [Redmine: #153102]
		- 20210705@Kos: Support Happy 5 Linked Games - Soccer 5 [Redmine: #154898]
		- 20210714@Kos: Support Casino products [Redmine: #157987]
		- 20210929@Kos: Extend length to support IPv6 [Redmine: 162342]
		- 20211029@Kos: Decompress IP in bk range [Redmine: 162342]
		- 20211102@Kos: Support AdvantPlay and AdvantPlay Mini [Redmine: #158186]
		- 20211126@Kos: Support Parlay Abnormal Bet [Redmine: #163900]
		- 20211215@Kos: Hotfix - Show Casino tickets when choosing Delayed Payout [Redmine: #166109]
		- 20211220@Kos: Support new Cash Out [Redmine: #165160]
		- 20220113@Kos: Support new 3rd result API [Redmine: #166047]
		- 20220215@Kos: Support TxId for 3rd products [Redmine: #166706]
		- 20220217@Kos: Support SG Jackpot [Redmine: #167035]
		- 20220227@Kos: Support Virtual Sports 3 [Redmine: #145337]
		- 20220427@Kos: Support Virtual Games result [Redmine: #170997]
		- 20220428@Kos: Support Bitcoin [RedmineID: #160160]
		- 20220512@Kos: Support FGG [Redmine: #167897]
		- 20220527@Kos: Support MaxGame [RedmineID: #172919]
		- 20220922@Kos: Support crypto currency [Redmine: 177481]
		- 20230119@Kos: Support Jili [Redmine: 182914]
		- 20230328@Kos: Remove inactive products CB, FW, GDG [Redmine: 181424]
		- 20230404@Kos: Extend betfrom length [Redmine: #178059]
		- 20230602@Kos: Support YeeBet [Redmine: 187947]
		- 20230629@Kos: Support MG-RNG [Redmine: 189988]
		- 20230803@Kos: Support Virtual Sports 3 [Redmine: 190908]
		- 20231127@Kos: Support Jollysports [RedmineID: #197192]
		- 20231130@Kos: Support SEAL Entertaiment [Redmine: 180648]
		- 20231207@Kos: Support WE Live Casino [Redmine: 196573]
		- 20231227@Kos: Hotfix - cannot view result [Redmine: 198900]
		- 20231227@Kos: Hide Saba text for Jollysports licensees [Redmine: 198697]
		- 20240129@Kos: Merge VS1, VS2, VS3 into VS [Redmine: 199523]
		- 20240305@Kos: Support Virtual Sports 4 [Redmine: 199347]
		- 20240619@Kos: Hotfix - Missing TranId3rd for Sports Lottery and Virtual Games [Redmine: 206758]
		- 20240705@Kos: Support more filters [Redmine: 202409]
					- Add new input params @SportTypeList, @BetTypeList, @CashoutMode
		- 20240815@Kos: Don't support Promotion tickets [Redmine: 208144]
		- 20240919@Kos: Support BetRadar Horse Racing [Redmine: #210808]
		- 20241113@Kos: Hotfix - wrong VS tickets [Redmine: #213614]
		- 20241115@Kos: Support Virtual Sports 6 [Redmine: 212446]
		- 20241210@Kos: Add unknown betfroms into group Others [#Redmine: 214849]
		- 20250225@Kos: Fix bug FLOAT rounding [#Redmine: 194970]
		- 20250313@Kos: Remove BA [RedmineID: #216882]
					- Remove input param @ShowBA
		- 20250318@Kos: Support Virtual Sports 5 [Redmine: 207582]
		- 20250415@Kos: Hotfix - VS racing range bettrans14 [Redmine: 224163]
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

	DECLARE @TempAg TABLE (CustId INT, Currency INT)

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

	IF ',' + @ProductList + ',' NOT LIKE '%,SB,%'
	BEGIN
		SET @CashoutMode = 1	-- Exclude Cash Out tickets
	END

	-- Get child product list
	IF EXISTS (SELECT 1 FROM dbo.Lrf_f_GroupProduct() WHERE ',' + @ProductList + ',' LIKE '%,' + GroupProductPrefix + ',%')
	BEGIN
		DECLARE @ChildProductList VARCHAR(500)

		SELECT @ChildProductList = STRING_AGG(ProductPrefix, ',')
		FROM dbo.Lrf_f_GroupProduct()
		WHERE ',' + @ProductList + ',' LIKE '%,' + GroupProductPrefix + ',%'

		SET @ProductList = @ProductList + ',' + @ChildProductList
	END

	CREATE TABLE #TempBetType (ProductPrefix VARCHAR(10), BetTypeList VARCHAR(MAX))

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductID TINYINT, ProductPrefix VARCHAR(500), BetType SMALLINT, EventType TINYINT, RefTable TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype (ProductID, ProductPrefix, BetType, EventType, RefTable, SubProduct)
	SELECT ProductID, ProductPrefix, BetType, EventType, RefTable, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @ProductList, @IsTest)
	WHERE BetType NOT IN (71, 73, 901, 902, 903, 904, 911, 912, 913, 914)
		AND BetType NOT BETWEEN 801 AND 899
		AND BetType NOT IN (SELECT BetType FROM dbo.Lrf_f_SelExcludedBetType())

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
	CREATE TABLE #TempSportType (SportType SMALLINT, LeagueGroupIdList VARCHAR(200))

	CREATE CLUSTERED INDEX IX_SportType ON #TempSportType (SportType)

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

	IF @HasError = 0
	BEGIN
		-- Get CustId in case of inputting Username
		IF @CustId = 0 AND @Username <> ''
		BEGIN
			SET @CustId = -1

			SELECT @CustId = custid
			FROM dbo.Customer AS c WITH (NOLOCK)
			WHERE EXISTS (SELECT 1 FROM @TempAg WHERE CustId = c.recommend)
				AND c.username = @Username

			IF @CustId = -1
			BEGIN
				SELECT @CustId = custid
				FROM dbo.Customer AS c WITH (NOLOCK)
				WHERE EXISTS (SELECT 1 FROM @TempAg WHERE CustId = c.recommend)
					AND c.username2 LIKE + '%$' + @Username
			END
		END

		IF @CustId <> 0
			AND NOT EXISTS (	SELECT 1 FROM dbo.custInfo AS c WITH (NOLOCK)
								WHERE c.custid = @CustId
									AND EXISTS (	SELECT 1 FROM @TempAg
													WHERE CustId = c.recommend AND Currency = c.currency))
		BEGIN
			SET @HasError = 1
		END
	END

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
		AWinLost			MONEY,
		WinLost				MONEY,
		LicenseeWL			MONEY,
		PlayerComm			MONEY,
		Comm				MONEY,
		Status				NVARCHAR(10),
		StatusId			TINYINT,
		SettlementStatus	TINYINT,
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
		SiteId				VARCHAR(20),
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
		AWinLost			MONEY,
		WinLost				MONEY,
		LicenseeWL			MONEY,
		PlayerComm			MONEY,
		Comm				MONEY,
		Status				NVARCHAR(10),
		StatusId			TINYINT,
		SettlementStatus	TINYINT,
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
		SiteId				VARCHAR(20),
		TableID				TINYINT,
		Product				VARCHAR(30),
		SubProduct			VARCHAR(500),
		RefTable			TINYINT,
		EventType			TINYINT
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

	DECLARE @TmpData TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		Status			NVARCHAR(10),
		WinLost			MONEY,
		BetEffective	MONEY,
		LicenseeWL		MONEY,
		PlayerComm		MONEY,
		Comm			MONEY,
		OddsSpread		MONEY
	)

	CREATE TABLE #ExchangeRate (
		FirstExchangeDateByMonth	SMALLDATETIME,
		LastExchangeDateByMonth		SMALLDATETIME,
		Rate						FLOAT
	)

	CREATE TABLE #AllPlatformList (BetFrom NVARCHAR(4))
	CREATE TABLE #PlatformList (BetFrom NVARCHAR(4))

	DECLARE @Yesterday SMALLDATETIME = DATEADD(DAY, DATEDIFF(DAY, 1, CURRENT_TIMESTAMP), 0)

	DECLARE @Currency	INT,
		@Nickname		NVARCHAR(50)

	IF @HasError = 0
	BEGIN
		IF @Platform <> 'All'
		BEGIN
			INSERT INTO #AllPlatformList (BetFrom)
			SELECT DISTINCT betfrom
			FROM dbo.Lrf_f_BetFromType_Sel('All')

			INSERT INTO #PlatformList (BetFrom)
			SELECT DISTINCT betfrom
			FROM dbo.Lrf_f_BetFromType_Sel(@Platform)
		END

		DECLARE @OriginalStatusIdList	VARCHAR(50)

		SET @OriginalStatusIdList = @StatusIdList

		IF ',' + @StatusIdList + ',' LIKE '%,99,%'		-- Abnormal Bet
		BEGIN
			SET @StatusIdList = @StatusIdList + ',102'
		END

		IF ',' + @StatusIdList + ',' LIKE '%,2,%'		-- Delay Payout
		BEGIN
			SET @StatusIdList = @StatusIdList + ',111,112,113'
		END

		DECLARE @TempToDate	SMALLDATETIME,
			@TempFromDate	SMALLDATETIME

		-- bettrans
		IF @ToDate > @MoveBetsDay
		BEGIN
			IF @FromDate <= @MoveBetsDay
				SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
			ELSE
				SET @TempFromDate = @FromDate

			IF @SportTypeList = 'All'
			BEGIN
				INSERT INTO #Data (
					TransId, RefNo, CustId, Currency, Recommend, BetType, BetId, BetTeam, Hdp1, Hdp2,
					OddsId, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, AWinLost, WinLost, PlayerComm,
					Comm, Status, StatusId, TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, BetFrom,
					MatchId, BetCheck, ComStatus, TransDesc, BetdaqId, ExtraInfo, WalletType, RefCode, TableID
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
					b.awinlost,
					b.winlost,
					b.playercomm,
					b.comm,
					b.status,
					b.statusID,
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
				FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_custid)
					INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
					LEFT JOIN #PlatformList AS pl ON pl.BetFrom = b.betfrom
					LEFT JOIN #AllPlatformList AS apl ON apl.BetFrom = b.betfrom
				WHERE b.custid = @CustId
					AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
					AND (',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
						OR (b.winlostdate >= @Yesterday AND s.RefTable IN (1, 2)))		-- don't care status of casino's summary rows if >= yesterday
					AND ((b.bettype IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.livehomescore) + ',%')
						OR (b.bettype NOT IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'))
					AND 1 = CASE
								WHEN @Platform = 'All' THEN 1
								WHEN pl.BetFrom IS NOT NULL THEN 1
								WHEN apl.BetFrom IS NULL AND ',' + @Platform + ',' LIKE '%,88,%' THEN 1
								WHEN apl.BetFrom IS NULL AND ',' + @Platform + ',' LIKE '%,99,%' THEN 1
								ELSE 0
							END
			END
			ELSE
			BEGIN
				INSERT INTO #Data (
					TransId, RefNo, CustId, Currency, Recommend, BetType, BetId, BetTeam, Hdp1, Hdp2,
					OddsId, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, AWinLost, WinLost, PlayerComm,
					Comm, Status, StatusId, TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, BetFrom,
					MatchId, BetCheck, ComStatus, TransDesc, BetdaqId, ExtraInfo, WalletType, RefCode, TableID
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
					b.awinlost,
					b.winlost,
					b.playercomm,
					b.comm,
					b.status,
					b.statusID,
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
				FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_custid)
					INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
					LEFT JOIN #PlatformList AS pl ON pl.BetFrom = b.betfrom
					LEFT JOIN #AllPlatformList AS apl ON apl.BetFrom = b.betfrom
					LEFT JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1
					LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK) ON m3rd.Match3rdId = b.MatchId AND s.EventType = 5
					LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.matchid = o.orid AND b.bettype = 10
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
					LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON vr.EventID = b.matchid AND s.EventType = 3
				WHERE b.custid = @CustId
					AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
					AND (',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
						OR (b.winlostdate >= @Yesterday AND s.RefTable IN (1, 2)))		-- don't care status of casino's summary rows if >= yesterday
					AND ((b.bettype IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.livehomescore) + ',%')
						OR (b.bettype NOT IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'))
					AND EXISTS (	SELECT 1 FROM #TempSportType
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
													END)
					AND 1 = CASE
								WHEN @Platform = 'All' THEN 1
								WHEN pl.BetFrom IS NOT NULL THEN 1
								WHEN apl.BetFrom IS NULL AND ',' + @Platform + ',' LIKE '%,88,%' THEN 1
								WHEN apl.BetFrom IS NULL AND ',' + @Platform + ',' LIKE '%,99,%' THEN 1
								ELSE 0
							END
			END
		END

		-- bettrans14
		IF @FromDate <= @MoveBetsDay AND @ToDate >= @BalanceUpDay
		BEGIN
			IF @ToDate >= @MoveBetsDay
				SET @TempToDate = @MoveBetsDay
			ELSE
				SET @TempToDate = @ToDate

			IF @FromDate < @BalanceUpDay
				SET @TempFromDate = @BalanceUpDay
			ELSE
				SET @TempFromDate = @FromDate

			IF @SportTypeList = 'All'
			BEGIN
				INSERT INTO #Data (
					TransId, RefNo, CustId, Currency, Recommend, BetType, BetId, BetTeam, Hdp1, Hdp2,
					OddsId, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, AWinLost, WinLost, PlayerComm,
					Comm, Status, StatusId, TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, BetFrom,
					MatchId, BetCheck, ComStatus, TransDesc, BetdaqId, ExtraInfo, WalletType, RefCode, TableID
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
					b.awinlost,
					b.winlost,
					b.playercomm,
					b.comm,
					b.status,
					b.statusID,
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
					2 AS TableID
				FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_memberStatement14)
					LEFT JOIN #PlatformList AS pl ON pl.BetFrom = b.betfrom
					LEFT JOIN #AllPlatformList AS apl ON apl.BetFrom = b.betfrom
				WHERE b.custid = @CustId
					AND b.winlostdate BETWEEN @TempFromDate AND @TempToDate
					AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
					AND ((b.bettype IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.livehomescore) + ',%')
						OR (b.bettype NOT IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'))
					AND 1 = CASE
								WHEN @Platform = 'All' THEN 1
								WHEN pl.BetFrom IS NOT NULL THEN 1
								WHEN apl.BetFrom IS NULL AND ',' + @Platform + ',' LIKE '%,88,%' THEN 1
								WHEN apl.BetFrom IS NULL AND ',' + @Platform + ',' LIKE '%,99,%' THEN 1
								ELSE 0
							END
			END
			ELSE
			BEGIN
				INSERT INTO #Data (
					TransId, RefNo, CustId, Currency, Recommend, BetType, BetId, BetTeam, Hdp1, Hdp2,
					OddsId, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, AWinLost, WinLost, PlayerComm,
					Comm, Status, StatusId, TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, BetFrom,
					MatchId, BetCheck, ComStatus, TransDesc, BetdaqId, ExtraInfo, WalletType, RefCode, TableID
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
					b.awinlost,
					b.winlost,
					b.playercomm,
					b.comm,
					b.status,
					b.statusID,
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
					2 AS TableID
				FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_memberStatement14)
					INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
					LEFT JOIN #PlatformList AS pl ON pl.BetFrom = b.betfrom
					LEFT JOIN #AllPlatformList AS apl ON apl.BetFrom = b.betfrom
					LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1
					LEFT JOIN dbo.Match3rd14 AS m3rd WITH (NOLOCK) ON m3rd.Match3rdId = b.MatchId AND s.EventType = 5
					LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.matchid = o.orid AND b.bettype = 10
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
					LEFT JOIN dbo.VSRaceInfo14 AS vr WITH (NOLOCK) ON vr.EventID = b.matchid AND s.EventType = 3
				WHERE b.custid = @CustId
					AND b.winlostdate BETWEEN @TempFromDate AND @TempToDate
					AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
					AND ((b.bettype IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.livehomescore) + ',%')
						OR (b.bettype NOT IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'))
					AND EXISTS (	SELECT 1 FROM #TempSportType
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
													END)
					AND 1 = CASE
								WHEN @Platform = 'All' THEN 1
								WHEN pl.BetFrom IS NOT NULL THEN 1
								WHEN apl.BetFrom IS NULL AND ',' + @Platform + ',' LIKE '%,88,%' THEN 1
								WHEN apl.BetFrom IS NULL AND ',' + @Platform + ',' LIKE '%,99,%' THEN 1
								ELSE 0
							END
			END
		END

		-- bettrans_bk
		IF @FromDate <= @BalanceUpDay
		BEGIN
			IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
				SET @TempToDate = DATEADD(dd, -1, @BalanceUpDay)
			ELSE
				SET @TempToDate = @ToDate

			IF @SportTypeList = 'All'
			BEGIN
				INSERT INTO #Data (
					TransId, RefNo, CustId, Currency, Recommend, BetType, BetId, BetTeam, Hdp1, Hdp2,
					OddsId, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, AWinLost, WinLost, PlayerComm,
					Comm, Status, StatusId, TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip,
					BetFrom, MatchId, BetCheck, ComStatus, TransDesc, BetdaqId, ExtraInfo, WalletType, RefCode, TableID
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
					b.awinlost,
					b.winlost,
					b.playercomm,
					b.comm,
					b.status,
					b.statusID,
					b.transdate,
					b.winlostdate,
					b.liveindicator,
					b.livehomescore,
					b.liveawayscore,
					dp.IP,
					b.betfrom,
					b.matchid,
					b.betcheck,
					b.comstatus,
					b.transdesc,
					b.betdaqid,
					b.ExtraInfo,
					b.WalletType,
					ISNULL(b.RefCode, 0),
					3 AS TableID
				FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX = IX_custid)
					LEFT JOIN #PlatformList AS pl ON pl.BetFrom = b.betfrom
					LEFT JOIN #AllPlatformList AS apl ON apl.BetFrom = b.betfrom
					CROSS APPLY dbo.f_IP_Decompress(b.ip) AS dp
				WHERE b.custid = @CustId
					AND b.winlostdate BETWEEN @FromDate AND @TempToDate
					AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
					AND ((b.bettype IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.livehomescore) + ',%')
						OR (b.bettype NOT IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'))
					AND 1 = CASE
								WHEN @Platform = 'All' THEN 1
								WHEN pl.BetFrom IS NOT NULL THEN 1
								WHEN apl.BetFrom IS NULL AND ',' + @Platform + ',' LIKE '%,88,%' THEN 1
								WHEN apl.BetFrom IS NULL AND ',' + @Platform + ',' LIKE '%,99,%' THEN 1
								ELSE 0
							END
			END
			ELSE
			BEGIN
				INSERT INTO #Data (
					TransId, RefNo, CustId, Currency, Recommend, BetType, BetId, BetTeam, Hdp1, Hdp2,
					OddsId, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, AWinLost, WinLost, PlayerComm,
					Comm, Status, StatusId, TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip,
					BetFrom, MatchId, BetCheck, ComStatus, TransDesc, BetdaqId, ExtraInfo, WalletType, RefCode, TableID
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
					b.awinlost,
					b.winlost,
					b.playercomm,
					b.comm,
					b.status,
					b.statusID,
					b.transdate,
					b.winlostdate,
					b.liveindicator,
					b.livehomescore,
					b.liveawayscore,
					dp.IP,
					b.betfrom,
					b.matchid,
					b.betcheck,
					b.comstatus,
					b.transdesc,
					b.betdaqid,
					b.ExtraInfo,
					b.WalletType,
					ISNULL(b.RefCode, 0),
					3 AS TableID
				FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX = IX_custid)
					INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
					LEFT JOIN #PlatformList AS pl ON pl.BetFrom = b.betfrom
					LEFT JOIN #AllPlatformList AS apl ON apl.BetFrom = b.betfrom
					LEFT JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1
					LEFT JOIN bodb_Archive.dbo.Match3rd_bk AS m3rd WITH (NOLOCK) ON m3rd.Match3rdId = b.MatchId AND s.EventType = 5
					LEFT JOIN bodb_Archive.dbo.outright_bk AS o WITH (NOLOCK) ON b.matchid = o.orid AND b.bettype = 10
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
					LEFT JOIN bodb_Archive.dbo.VSRaceInfo_bk AS vr WITH (NOLOCK) ON vr.EventID = b.matchid AND s.EventType = 3
					CROSS APPLY dbo.f_IP_Decompress(b.ip) AS dp
				WHERE b.custid = @CustId
					AND b.winlostdate BETWEEN @FromDate AND @TempToDate
					AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
					AND ((b.bettype IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.livehomescore) + ',%')
						OR (b.bettype NOT IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'))
					AND EXISTS (	SELECT 1 FROM #TempSportType
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
													END)
					AND 1 = CASE
								WHEN @Platform = 'All' THEN 1
								WHEN pl.BetFrom IS NOT NULL THEN 1
								WHEN apl.BetFrom IS NULL AND ',' + @Platform + ',' LIKE '%,88,%' THEN 1
								WHEN apl.BetFrom IS NULL AND ',' + @Platform + ',' LIKE '%,99,%' THEN 1
								ELSE 0
							END
			END
		END

		DELETE b
		FROM #Data AS b
		WHERE NOT EXISTS (SELECT 1 FROM @TempAg WHERE CustId = b.Recommend AND Currency = b.Currency)
			OR (',' + @OriginalStatusIdList + ',' NOT LIKE '%,99,%'
				AND b.Status = 'Void'
				AND ISNULL(CAST(('<xml>' + ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@ab)[1]','TINYINT'), 0) = 1)
			OR (',' + @OriginalStatusIdList + ',' NOT LIKE '%,102,%'
				AND b.Status = 'Void'
				AND ISNULL(CAST(('<xml>' + ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@ab)[1]','TINYINT'), 0) = 0)

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
							WHEN s.ProductID = 63 THEN 'SLT'							-- Sports Lottery
							WHEN s.ProductID = 66 THEN 'VGA'							-- Vgaming
							WHEN s.ProductID = 67 THEN 'AP'								-- AdvantPlay
							WHEN s.ProductID = 68 THEN 'APM'							-- AdvantPlay Mini
							WHEN s.ProductID = 69 THEN 'BTC'							-- Bitcoin
							WHEN s.ProductID = 70 THEN 'FGGL'							-- FGG
							WHEN s.ProductID = 72 THEN 'SEA'							-- SEAL Entertainment
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
				INNER JOIN @SportBetType AS s ON b.bettype = s.bettype

			DELETE #Data
			WHERE Product IS NULL
				OR (@CashoutMode = 1	-- Cash Out tickets
					AND Product IN ('SB', 'Parlay', 'Outright')
					AND BetdaqId = -2)
				OR (@CashoutMode = 2	-- Normal SB tickets
					AND Product IN ('SB', 'Parlay', 'Outright')
					AND ISNULL(BetdaqId, 0) <> -2)
				OR (Product NOT IN ('SB', 'Parlay')
					AND ',' + @OriginalStatusIdList + ',' NOT LIKE '%,' + CONVERT(VARCHAR(3), StatusId) + ',%')
				OR (Product = 'Parlay'
					AND Status IN ('Draw', 'Won', 'Lose')
					AND ',' + @OriginalStatusIdList + ',' NOT LIKE '%,' + CONVERT(VARCHAR(3), StatusId) + ',%')

			-- Check status
			IF EXISTS (SELECT 1 FROM #Data WHERE Product = 'SB' AND Status IN ('Draw', 'Won', 'Lose'))
			BEGIN
				UPDATE b
				SET b.SettlementStatus = m.SettlementStatus
				FROM #Data AS b
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.matchid
				WHERE b.Product = 'SB' AND b.Status IN ('Draw', 'Won', 'Lose')

				IF ',' + @OriginalStatusIdList + ',' NOT LIKE '%,111,%'		-- Not include Draw, Won, Lose
					OR ',' + @OriginalStatusIdList + ',' NOT LIKE '%,112,%'
					OR ',' + @OriginalStatusIdList + ',' NOT LIKE '%,113,%'
				BEGIN
					DELETE FROM #Data
					WHERE Product = 'SB'
						AND (ISNULL(SettlementStatus, 0) & 1 = 0		-- isPending flag (bit 1) = 0
							OR (Stake = 0								-- Cash Out All
								AND BetdaqId = 0
								AND ExtraInfo LIKE '%p25%'))
						AND ((Status = 'Draw' AND ',' + @OriginalStatusIdList + ',' NOT LIKE '%,111,%')
							OR (Status = 'Won' AND ',' + @OriginalStatusIdList + ',' NOT LIKE '%,112,%')
							OR (Status = 'Lose' AND ',' + @OriginalStatusIdList + ',' NOT LIKE '%,113,%'))
				END

				IF ',' + @OriginalStatusIdList + ',' NOT LIKE '%,2,%'		-- Not include Delay Payout
				BEGIN
					DELETE #Data
					WHERE Product = 'SB'
						AND ISNULL(SettlementStatus, 0) & 1 <> 0		-- isPending flag (bit 1) = 1
						AND Status IN ('Draw', 'Won', 'Lose')
						AND (Stake <> 0									-- Not Cash Out All
							OR BetdaqId <> 0
							OR ExtraInfo NOT LIKE '%p25%')
				END
			END

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
				WHERE b.Product = 'SB' AND b.TableID = 1

				UPDATE b
				SET SportType = m.sporttype,
					LeagueId = m.leagueid,
					LeagueGroupId = l.LeagueGroupID
				FROM #Data AS b
					INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.MatchId
					INNER JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
				WHERE b.Product = 'SB' AND b.TableID = 2

				UPDATE b
				SET SportType = m.sporttype,
					LeagueId = m.leagueid,
					LeagueGroupId = l.LeagueGroupID
				FROM #Data AS b
					INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON m.matchid = b.MatchId
					INNER JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
				WHERE b.Product = 'SB' AND b.TableID = 3

				UPDATE b
				SET SportType = l.sporttype,
					LeagueId = l.leagueid,
					LeagueGroupId = l.LeagueGroupID
				FROM #Data AS b
					INNER JOIN dbo.outright AS o WITH (NOLOCK) ON o.orid = b.MatchId
					INNER JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = o.leagueid
				WHERE b.Product = 'Outright' AND b.TableID = 1

				UPDATE b
				SET SportType = l.sporttype,
					LeagueId = l.leagueid,
					LeagueGroupId = l.LeagueGroupID
				FROM #Data AS b
					INNER JOIN dbo.outright14 AS o WITH (NOLOCK) ON o.orid = b.MatchId
					INNER JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = o.leagueid
				WHERE b.Product = 'Outright' AND b.TableID = 2

				UPDATE b
				SET SportType = l.sporttype,
					LeagueId = l.leagueid,
					LeagueGroupId = l.LeagueGroupID
				FROM #Data AS b
					INNER JOIN bodb_Archive.dbo.outright_bk AS o WITH (NOLOCK) ON o.orid = b.MatchId
					INNER JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = o.leagueid
				WHERE b.Product = 'Outright' AND b.TableID = 3

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

			UPDATE #Data
			SET
				WinLost = WinLost - Actual_Stake,
				LicenseeWL = - (WinLost - Actual_Stake)

			-- Get data for summary ticket of multiple Bonus/Cash sub tickets
			IF EXISTS (SELECT 1 FROM #Data WHERE RefCode <> 0)
			BEGIN
				DECLARE @RefCodeTmp TABLE (
					RefCode			BIGINT,
					TransId			BIGINT,
					Stake			MONEY,
					Actual_Stake	MONEY,
					WinLost			MONEY,
					LicenseeWL		MONEY,
					Comm			MONEY,
					PlayerComm		MONEY
				)

				-- Prepare temp table
				INSERT INTO @RefCodeTmp
				(
					RefCode,
					TransId,
					Stake,
					Actual_Stake,
					WinLost,
					LicenseeWL,
					Comm,
					PlayerComm
				)
				SELECT
					RefCode,
					MIN(TransId) AS TransId,
					SUM(Stake) AS Stake,
					SUM(Actual_Stake) AS Actual_Stake,
					SUM(WinLost) AS WinLost,
					SUM(LicenseeWL) AS LicenseeWL,
					SUM(Comm) AS Comm,
					SUM(PlayerComm) AS PlayerComm
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
						b.Actual_Stake = r.Actual_Stake,
						b.WinLost = r.WinLost,
						b.LicenseeWL = r.LicenseeWL,
						b.Comm = r.Comm,
						b.PlayerComm = r.PlayerComm,
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

			-- Get yesterday and today settled bettransRnG/bettransLC tickets
			IF ',' + @OriginalStatusIdList + ',' LIKE '%,111,%'
				OR ',' + @OriginalStatusIdList + ',' LIKE '%,112,%'
				OR ',' + @OriginalStatusIdList + ',' LIKE '%,113,%'
			BEGIN
				IF EXISTS (SELECT 1 FROM #Data WHERE RefTable = 1 AND WinLostDate >= @Yesterday)		-- bettransRnG
				BEGIN
					INSERT INTO @TmpData
					(
						RefNo,
						Odds,
						Stake,
						Actual_Stake,
						Status,
						WinLost,
						BetEffective,
						LicenseeWL,
						PlayerComm,
						Comm,
						OddsSpread
					)
					SELECT
						c.TransId AS RefNo,
						CASE
							WHEN Product IN ('OneRNG', 'PP', 'SBC', 'VGA', 'SG', 'PTRNG') THEN ISNULL(AVG(CASE WHEN brng.statusID IN (111, 112, 113) THEN brng.ContributionRate END), 0)
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
						ABS(SUM(brng.winlost - brng.actual_stake)) AS BetEffective,
						- SUM(brng.winlost - brng.actual_stake) AS LicenseeWL,
						SUM(brng.playercomm) AS Commission,
						SUM(brng.comm) AS Comm,
						CASE
							WHEN c.Product IN ('OneRNG', 'PP', 'SBC', 'VGA', 'SG', 'PTRNG') THEN SUM(ISNULL(brng.BetStake, 0))
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
					(
						RefNo,
						Odds,
						Stake,
						Actual_Stake,
						Status,
						WinLost,
						BetEffective,
						LicenseeWL,
						PlayerComm,
						Comm,
						OddsSpread
					)
					SELECT
						c.TransId AS RefNo,
						CASE
							WHEN c.SubProduct LIKE '%Jackpot%' THEN ISNULL(AVG(CASE WHEN blc.statusID IN (111, 112, 113) THEN blc.ContributionRate END), 0)
							ELSE 0
						END AS Odds,
						SUM(blc.stake) AS Stake,
						SUM(blc.actual_stake) AS Actual_Stake,
						CASE
							WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
							WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
							ELSE 'Draw'
						END AS Status,
						SUM(blc.winlost - blc.actual_stake) AS WinLost,
						ABS(SUM(blc.winlost - blc.actual_stake)) AS BetEffective,
						- SUM(blc.winlost - blc.actual_stake) AS LicenseeWL,
						SUM(blc.playercomm) AS Commission,
						SUM(blc.comm) AS Comm,
						CASE
							WHEN c.SubProduct LIKE '%Jackpot%' THEN SUM(ISNULL(blc.BetStake, 0))
							ELSE 0
						END AS OddsSpread
					FROM #Data AS c
						INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = c.TransId
					WHERE c.RefTable = 2
						AND c.WinLostDate >= @Yesterday
						AND blc.statusID NOT IN (0, 1)
					GROUP BY
						c.TransId,
						c.Product,
						c.SubProduct
				END

				DELETE FROM @TmpData
				WHERE (Status = 'Draw' AND ',' + @StatusIdList + ',' NOT LIKE '%,111,%')
					OR (Status = 'Won' AND ',' + @StatusIdList + ',' NOT LIKE '%,112,%')
					OR (Status = 'Lose' AND ',' + @StatusIdList + ',' NOT LIKE '%,113,%')

				DELETE b
				FROM #Data AS b
				WHERE b.RefTable IN (1, 2)
					AND b.Winlostdate >= @Yesterday
					AND NOT EXISTS (SELECT 1 FROM @TmpData WHERE RefNo = b.TransId)
			END

			UPDATE b
			SET
				Odds = CASE
							WHEN b.Product IN ('OneRNG', 'PP', 'SBC', 'VGA', 'SG') AND x.Odds IS NOT NULL THEN x.Odds
							WHEN b.SubProduct LIKE '%Jackpot%' AND x.Odds IS NOT NULL THEN x.Odds
							ELSE b.Odds
						END,
				OddsSpread = CASE
								WHEN b.Product IN ('OneRNG', 'PP', 'SBC', 'VGA', 'SG') AND x.OddsSpread IS NOT NULL THEN x.OddsSpread
								WHEN b.SubProduct LIKE '%Jackpot%' AND x.OddsSpread IS NOT NULL THEN x.OddsSpread
								ELSE b.oddsspread
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
			WHERE b.TableID = 1

			SELECT @Currency = currency,
				@Username = username,
				@Nickname = SUBSTRING(username2, CHARINDEX('$', username2) + 1, LEN(username2) - CHARINDEX('$', username2))
			FROM dbo.Customer WITH (NOLOCK)
			WHERE custid = @CustId

			DECLARE @ExFromDate SMALLDATETIME,
				@ExToDate SMALLDATETIME

			SELECT
				@ExFromDate = MIN(WinLostDate),
				@ExToDate = MAX(WinLostDate)
			FROM #Data

			-- Get exchange rate
			IF @BaseCurrency <> ''
			BEGIN
				INSERT INTO #ExchangeRate (FirstExchangeDateByMonth, LastExchangeDateByMonth, Rate)
				SELECT
					e.FromDate,
					e.ToDate,
					e.Rate
				FROM dbo.Lrf_f_GetExchangeRate(@ExFromDate, @ExToDate, @BaseCurrency, '') AS e
				WHERE ExchangeId = @Currency
					AND EXISTS (SELECT 1 FROM #Data WHERE WinLostDate BETWEEN e.FromDate AND e.ToDate)
			END

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
				LEFT JOIN #ExchangeRate AS e ON b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth

			DECLARE @SortText VARCHAR(100)

			-- Get sort text
			SET @SortText = CASE
								WHEN @SortType = 0 THEN 'TransDate'
								WHEN @SortType = 1 THEN 'Stake'
								WHEN @SortType = 2 THEN 'WinLost'
								WHEN @SortType = 3 THEN 'LicenseeWL'
								ELSE ''
							END

			IF @BaseCurrency <> '' AND @SortType IN (1, 2, 3)
			BEGIN
				SET @SortText = @SortText + ' * ISNULL(e.Rate, 1)'
			END

			SET @SortText = @SortText + ' ' + CASE
												WHEN @SortOrder = 1 THEN 'ASC'
												WHEN @SortOrder = 2 THEN 'DESC'
												ELSE ''
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
							ROW_NUMBER() OVER (ORDER BY ' + @SortText + N') AS RowNum,
							d.*
						FROM #Data AS d' +
						CASE
							WHEN @SortText LIKE '%e.Rate%' THEN N'
							LEFT JOIN #ExchangeRate AS e ON d.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth'
							ELSE N' '
						END + N'
					) AS a
				WHERE a.RowNum BETWEEN @RowStart AND @RowEnd
				ORDER BY a.RowNum ASC'

			INSERT INTO #PagingData
			(
				RowNum, TransId, RefNo, CustId, Currency, Recommend, SportType, BetType, BetId, BetTeam,
				Hdp1, Hdp2, OddsId, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, AWinLost,
				WinLost, LicenseeWL, PlayerComm, Comm, Status, StatusId, SettlementStatus, TransDate, WinLostDate, LiveIndicator,
				LiveHomeScore, LiveAwayScore, Ip, BetFrom, LeagueId, LeagueGroupId, MatchId, MatchCode, Race, EventDate,
				HomeId, AwayId, BetStatus, IsNeutral, Placing, ShowTime, BetCheck, ComStatus, TransDesc, BetdaqId,
				ExtraInfo, OriginalStake, OriginalBetType, WalletType, RefCode, SiteId, TableID, Product, SubProduct, RefTable,
				EventType
			)
			EXEC sp_executesql @Sql, N'@RowStart INT, @RowEnd INT', @RowStart, @RowEnd;

			-- bettrans
			IF EXISTS (SELECT TOP(1) 1 FROM #PagingData WHERE TableID = 1)
			BEGIN
				UPDATE b
				SET
					SportType = CASE
									WHEN b.Product IN ('Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VRG', 'TG', 'SBC', 'I4D', 'SXG', 'SAG', 'PGS', 'JK',
										'H5LG', 'SLT', 'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM', 'VS3', 'FGGL', 'MXG', 'JIG', 'YB', 'MGRNG', 'SEA') THEN b.MatchId
									WHEN b.Product = 'AllBet' THEN 211		-- AllBet
									WHEN b.Product = 'VB' THEN 212			-- Macau Games
									WHEN b.Product = 'PP' THEN 248			-- Pragmatic Casino
									WHEN b.Product IN ('Outright') THEN l.sporttype
									WHEN b.EventType = 1 THEN m.sporttype
									WHEN b.EventType = 3 THEN vr.SportType
									WHEN b.EventType = 5 THEN m3rd.SportType
									WHEN b.RefTable IN (1, 2) THEN b.MatchId
									ELSE 0
								END,
					Status = CASE
								WHEN b.Product = 'TG' AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
								WHEN b.Product = 'TG' AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
								ELSE b.status
							END,
					SettlementStatus = CASE
										WHEN b.Product = 'SB' THEN ISNULL(m.SettlementStatus, 0)
										ELSE 0
									END,
					LiveIndicator = CASE
										WHEN b.EventType IN (1, 5) THEN b.liveindicator
										ELSE 0
									END,
					LeagueId = CASE
									WHEN b.EventType = 1 THEN m.leagueid
									WHEN b.EventType = 5 THEN m3rd.League3rdId
									WHEN b.Product IN ('Outright') THEN o.leagueid
									WHEN b.EventType = 3 THEN vr.LeagueID
									ELSE 0
								END,
					LeagueGroupId = CASE
									WHEN b.Product IN ('SB') THEN le.LeagueGroupID
									ELSE 0
								END,
					MatchId = CASE
									WHEN b.EventType IN (1, 3, 5) THEN b.matchid
									WHEN b.Product IN ('BTC') THEN b.matchid
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.EventType = 1 THEN m.matchcode
									WHEN b.Product IN ('Outright') THEN o.matchcode
									ELSE ''
								END,
					Race = CASE
								WHEN b.Product IN ('Outright') THEN o.groupmatch
								ELSE ''
							END,
					EventDate = CASE
									WHEN b.Product IN ('SB') THEN m.GlobalShowTime
									WHEN b.Product IN ('BTC') THEN m3rd.EndTime
									ELSE b.WinLostDate
								END,
					HomeId = CASE
								WHEN b.EventType = 1 THEN m.homeid
								WHEN b.EventType = 5 THEN m3rd.HomeId
								WHEN b.Product IN ('Outright') THEN o.teamid
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.EventType = 1 THEN m.awayid
								WHEN b.EventType = 5 THEN m3rd.AwayId
								ELSE 0
							END,
					BetStatus = CASE
									WHEN b.EventType = 1 THEN m.betstatus
									ELSE ''
								END,
					IsNeutral = CASE
									WHEN b.EventType = 1 THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					Placing = '',
					ShowTime = CASE
									WHEN b.Product IN ('VS') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN b.EventType = 5 THEN CONVERT(NVARCHAR(50), m3rd.StartTime)
									ELSE ''
								END,
					BetCheck = CASE
									WHEN b.Product IN ('SB', 'VRG', 'SLT', 'H5LG') THEN ISNULL(b.betcheck, '')
									WHEN b.EventType = 0 AND b.RefTable = 0 THEN ISNULL(b.betcheck, '')
									WHEN b.Product IN ('Keno') THEN ISNULL(b.ComStatus, '')
									ELSE ''
								END,
					TransDesc = CASE
									WHEN b.Product IN ('Parlay', 'Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VB', 'PP', 
										'VRG', 'TG', 'I4D', 'PGS', 'JK', 'H5LG', 'SLT', 'HB', 'CG', 'AP', 'APM', 'VS3', 'SEA') THEN ISNULL(b.transdesc, '')
									WHEN b.EventType IN (1, 3, 5) THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					BetdaqId = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.betdaqid, -1)
									ELSE -1
								END,
					OriginalStake = CASE
										WHEN b.Product IN ('SB') AND b.ExtraInfo LIKE '%p25%' THEN
											ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
										ELSE 0
									END,
					OriginalBetType = CASE
										WHEN b.Product IN ('SB') AND b.stake <> 0 THEN -1
										ELSE 0
									END,
					WalletType = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.WalletType, 0)
									ELSE 0
								END,
					RefCode = CASE
									WHEN b.Product IN ('SB') AND b.stake <> 0 THEN ISNULL(b.RefCode, 0)
									ELSE 0
								END,
					SiteId = CASE
								WHEN b.Product IN ('H5LG', 'SLT', 'VRG') THEN CONVERT(VARCHAR(20), b.BetdaqId)
								ELSE ''
							END
				FROM #PagingData AS b
					LEFT JOIN dbo.match AS m WITH (NOLOCK) ON b.EventType = 1 AND b.matchid = m.matchid
					LEFT JOIN dbo.League AS le WITH (NOLOCK) ON b.Product IN ('SB') AND le.leagueid = m.leagueid
					LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK) ON b.EventType = 5 AND m3rd.Match3rdId = b.matchid
					LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueID = l.leagueID
					LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON b.EventType = 3 AND vr.EventID = b.matchid
				WHERE b.TableID = 1
			END

			-- bettrans14
			IF EXISTS (SELECT TOP(1) 1 FROM #PagingData WHERE TableID = 2)
			BEGIN
				UPDATE b
				SET
					SportType = CASE
									WHEN b.Product IN ('Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VRG', 'TG', 'SBC', 'I4D', 'SXG', 'SAG', 'PGS', 'JK',
										'H5LG', 'SLT', 'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM', 'VS3', 'FGGL', 'MXG', 'JIG', 'YB', 'MGRNG', 'SEA') THEN b.MatchId
									WHEN b.Product = 'AllBet' THEN 211		-- AllBet
									WHEN b.Product = 'VB' THEN 212			-- Macau Games
									WHEN b.Product = 'PP' THEN 248			-- Pragmatic Casino
									WHEN b.Product IN ('Outright') THEN l.sporttype
									WHEN b.EventType = 1 THEN m.sporttype
									WHEN b.EventType = 3 THEN vr.SportType
									WHEN b.EventType = 5 THEN m3rd.SportType
									WHEN b.RefTable IN (1, 2) THEN b.MatchId
									ELSE 0
								END,
					Status = CASE
								WHEN b.Product = 'TG' AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
								WHEN b.Product = 'TG' AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
								ELSE b.status
							END,
					SettlementStatus = 0,
					LiveIndicator = CASE
										WHEN b.EventType IN (1, 5) THEN b.liveindicator
										ELSE 0
									END,
					LeagueId = CASE
									WHEN b.EventType = 1 THEN m.leagueid
									WHEN b.EventType = 5 THEN m3rd.League3rdId
									WHEN b.Product IN ('Outright') THEN o.leagueid
									WHEN b.EventType = 3 THEN vr.LeagueID
									ELSE 0
								END,
					LeagueGroupId = CASE
									WHEN b.Product IN ('SB') THEN le.LeagueGroupID
									ELSE 0
								END,
					MatchId = CASE
									WHEN b.EventType IN (1, 3, 5) THEN b.matchid
									WHEN b.Product IN ('BTC') THEN b.matchid
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.EventType = 1 THEN m.matchcode
									WHEN b.Product IN ('Outright') THEN o.matchcode
									ELSE ''
								END,
					Race = CASE
								WHEN b.Product IN ('Outright') THEN o.groupmatch
								ELSE ''
							END,
					EventDate = CASE
									WHEN b.Product IN ('SB') THEN m.GlobalShowTime
									WHEN b.Product IN ('BTC') THEN m3rd.EndTime
									ELSE b.WinLostDate
								END,
					HomeId = CASE
								WHEN b.EventType = 1 THEN m.homeid
								WHEN b.EventType = 5 THEN m3rd.HomeId
								WHEN b.Product IN ('Outright') THEN o.teamid
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.EventType = 1 THEN m.awayid
								WHEN b.EventType = 5 THEN m3rd.AwayId
								ELSE 0
							END,
					BetStatus = CASE
									WHEN b.EventType = 1 THEN m.betstatus
									ELSE ''
								END,
					IsNeutral = CASE
									WHEN b.EventType = 1 THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					Placing = '',
					ShowTime = CASE
									WHEN b.Product IN ('VS') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN b.EventType = 5 THEN CONVERT(NVARCHAR(50), m3rd.StartTime)
									ELSE ''
								END,
					BetCheck = CASE
									WHEN b.Product IN ('SB', 'VRG', 'SLT', 'H5LG') THEN ISNULL(b.betcheck, '')
									WHEN b.EventType = 0 AND b.RefTable = 0 THEN ISNULL(b.betcheck, '')
									WHEN b.Product IN ('Keno') THEN ISNULL(b.ComStatus, '')
									ELSE ''
								END,
					TransDesc = CASE
									WHEN b.Product IN ('Parlay', 'Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VB', 'PP', 
										'VRG', 'TG', 'I4D', 'PGS', 'JK', 'H5LG', 'SLT', 'HB', 'CG', 'AP', 'APM', 'VS3', 'SEA') THEN ISNULL(b.transdesc, '')
									WHEN b.EventType IN (1, 3, 5) THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					BetdaqId = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.betdaqid, -1)
									ELSE -1
								END,
					OriginalStake = CASE
										WHEN b.Product IN ('SB') AND b.ExtraInfo LIKE '%p25%' THEN
											ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
										ELSE 0
									END,
					OriginalBetType = CASE
										WHEN b.Product IN ('SB') AND b.stake <> 0 THEN -1
										ELSE 0
									END,
					WalletType = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.WalletType, 0)
									ELSE 0
								END,
					RefCode = CASE
									WHEN b.Product IN ('SB') AND b.stake <> 0 THEN ISNULL(b.RefCode, 0)
									ELSE 0
								END,
					SiteId = CASE
								WHEN b.Product IN ('H5LG', 'SLT', 'VRG') THEN CONVERT(VARCHAR(20), b.BetdaqId)
								ELSE ''
							END
				FROM #PagingData AS b
					LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON b.EventType = 1 AND b.matchid = m.matchid
					LEFT JOIN dbo.League AS le WITH (NOLOCK) ON b.Product IN ('SB') AND le.leagueid = m.leagueid
					LEFT JOIN dbo.Match3rd14 AS m3rd WITH (NOLOCK) ON b.EventType = 5 AND m3rd.Match3rdId = b.matchid
					LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueID = l.leagueID
					LEFT JOIN dbo.VSRaceInfo14 AS vr WITH (NOLOCK) ON b.EventType = 3 AND vr.EventID = b.matchid
				WHERE b.TableID = 2
			END

			-- bettrans_bk
			IF EXISTS (SELECT TOP(1) 1 FROM #PagingData WHERE TableID = 3)
			BEGIN
				UPDATE b
				SET
					SportType = CASE
									WHEN b.Product IN ('Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VRG', 'TG', 'SBC', 'I4D', 'SXG', 'SAG', 'PGS', 'JK',
										'H5LG', 'SLT', 'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM', 'VS3', 'FGGL', 'MXG', 'JIG', 'YB', 'MGRNG', 'SEA') THEN b.MatchId
									WHEN b.Product = 'AllBet' THEN 211		-- AllBet
									WHEN b.Product = 'VB' THEN 212			-- Macau Games
									WHEN b.Product = 'PP' THEN 248			-- Pragmatic Casino
									WHEN b.Product IN ('Outright') THEN l.sporttype
									WHEN b.EventType = 1 THEN m.sporttype
									WHEN b.EventType = 3 THEN vr.SportType
									WHEN b.EventType = 5 THEN m3rd.SportType
									WHEN b.RefTable IN (1, 2) THEN b.MatchId
									ELSE 0
								END,
					Status = CASE
								WHEN b.Product = 'TG' AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
								WHEN b.Product = 'TG' AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
								ELSE b.status
							END,
					SettlementStatus = 0,
					LiveIndicator = CASE
										WHEN b.EventType IN (1, 5) THEN b.liveindicator
										ELSE 0
									END,
					LeagueId = CASE
									WHEN b.EventType = 1 THEN m.leagueid
									WHEN b.EventType = 5 THEN m3rd.League3rdId
									WHEN b.Product IN ('Outright') THEN o.leagueid
									WHEN b.EventType = 3 THEN vr.LeagueID
									ELSE 0
								END,
					LeagueGroupId = CASE
									WHEN b.Product IN ('SB') THEN le.LeagueGroupID
									ELSE 0
								END,
					MatchId = CASE
									WHEN b.EventType IN (1, 3, 5) THEN b.matchid
									WHEN b.Product IN ('BTC') THEN b.matchid
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.EventType = 1 THEN m.matchcode
									WHEN b.Product IN ('Outright') THEN o.matchcode
									ELSE ''
								END,
					Race = CASE
								WHEN b.Product IN ('Outright') THEN o.groupmatch
								ELSE ''
							END,
					EventDate = CASE
									WHEN b.Product IN ('SB') THEN m.GlobalShowTime
									WHEN b.Product IN ('BTC') THEN m3rd.EndTime
									ELSE b.WinLostDate
								END,
					HomeId = CASE
								WHEN b.EventType = 1 THEN m.homeid
								WHEN b.EventType = 5 THEN m3rd.HomeId
								WHEN b.Product IN ('Outright') THEN o.teamid
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.EventType = 1 THEN m.awayid
								WHEN b.EventType = 5 THEN m3rd.AwayId
								ELSE 0
							END,
					BetStatus = CASE
									WHEN b.EventType = 1 THEN m.betstatus
									ELSE ''
								END,
					IsNeutral = CASE
									WHEN b.EventType = 1 THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					Placing = '',
					ShowTime = CASE
									WHEN b.Product IN ('VS') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN b.EventType = 5 THEN CONVERT(NVARCHAR(50), m3rd.StartTime)
									ELSE ''
								END,
					BetCheck = CASE
									WHEN b.Product IN ('SB', 'VRG', 'SLT', 'H5LG') THEN ISNULL(b.betcheck, '')
									WHEN b.EventType = 0 AND b.RefTable = 0 THEN ISNULL(b.betcheck, '')
									WHEN b.Product IN ('Keno') THEN ISNULL(b.ComStatus, '')
									ELSE ''
								END,
					TransDesc = CASE
									WHEN b.Product IN ('Parlay', 'Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VB', 'PP', 
										'VRG', 'TG', 'I4D', 'PGS', 'JK', 'H5LG', 'SLT', 'HB', 'CG', 'AP', 'APM', 'VS3', 'SEA') THEN ISNULL(b.transdesc, '')
									WHEN b.EventType IN (1, 3, 5) THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					BetdaqId = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.betdaqid, -1)
									ELSE -1
								END,
					OriginalStake = CASE
										WHEN b.Product IN ('SB') AND b.ExtraInfo LIKE '%p25%' THEN
											ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
										ELSE 0
									END,
					OriginalBetType = CASE
										WHEN b.Product IN ('SB') AND b.stake <> 0 THEN -1
										ELSE 0
									END,
					WalletType = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.WalletType, 0)
									ELSE 0
								END,
					RefCode = CASE
									WHEN b.Product IN ('SB') AND b.stake <> 0 THEN ISNULL(b.RefCode, 0)
									ELSE 0
								END,
					SiteId = CASE
								WHEN b.Product IN ('H5LG', 'SLT', 'VRG') THEN CONVERT(VARCHAR(20), b.BetdaqId)
								ELSE ''
							END
				FROM #PagingData AS b
					LEFT JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.EventType = 1 AND b.matchid = m.matchid
					LEFT JOIN dbo.League AS le WITH (NOLOCK) ON b.Product IN ('SB') AND le.leagueid = m.leagueid
					LEFT JOIN bodb_Archive.dbo.Match3rd_bk AS m3rd WITH (NOLOCK) ON b.EventType = 5 AND m3rd.Match3rdId = b.matchid
					LEFT JOIN bodb_Archive.dbo.outright_bk AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueID = l.leagueID
					LEFT JOIN bodb_Archive.dbo.VSRaceInfo_bk AS vr WITH(NOLOCK) ON b.EventType = 3 AND vr.EventID = b.matchid
				WHERE b.TableID = 3
			END
		END
	END

	-- Get ticket detail
	-- Virtual Sports
	IF EXISTS (SELECT 1 FROM #PagingData WHERE Product = 'VR' AND TableID = 1)
	BEGIN
		INSERT INTO @Detail
		(
			RefNo,
			Odds,
			Stake,
			Status,
			APositionTaking,
			BetType,
			BetTeam
		)
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
			AND b.TableID = 1
			AND sbt.ProductID = 5
			AND sbt.EventType = 3
	END

	IF EXISTS (SELECT 1 FROM #PagingData WHERE Product = 'VR' AND TableID = 2)
	BEGIN
		INSERT INTO @Detail
		(
			RefNo,
			Odds,
			Stake,
			Status,
			APositionTaking,
			BetType,
			BetTeam
		)
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
			AND b.TableID = 2
			AND sbt.ProductID = 5
			AND sbt.EventType = 3
	END

	IF EXISTS (SELECT 1 FROM #PagingData WHERE Product = 'VR' AND TableID = 3)
	BEGIN
		INSERT INTO @Detail
		(
			RefNo,
			Odds,
			Stake,
			Status,
			APositionTaking,
			BetType,
			BetTeam
		)
		SELECT
			bm.refno,
			bm.odds,
			bm.stake * ISNULL(e.Rate, 1) AS Stake,
			bm.status,
			bm.apositiontaking,
			bm.bettype,
			bm.betteam
		FROM bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN #PagingData AS b ON bm.refno = b.RefNo AND bm.custid = b.CustId
			INNER JOIN dbo.SportBettypeMatrix AS sbt WITH (NOLOCK) ON bm.bettype = sbt.Bettype
			LEFT JOIN #ExchangeRate AS e ON bm.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
		WHERE b.Product = 'VR'
			AND b.TableID = 3
			AND sbt.ProductID = 5
			AND sbt.EventType = 3
	END

	-- Return data
	SELECT
		@Username AS Username,
		@Nickname AS NickName,
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
		a.BetStatus,
		a.Placing,
		a.ShowTime,
		a.Currency,
		CAST(a.Stake * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS Stake,
		CAST(a.Actual_Stake * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS Actual_Stake,
		CAST(a.WinLost * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS WinLost,
		CAST(a.LicenseeWL * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS LicenseeWL,
		CAST(a.Comm * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS Comm,
		CAST(a.PlayerComm * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS PlayerComm,
		a.Ip,
		a.BetFrom,
		a.BetCheck,
		a.TransDesc,
		a.BetdaqId,
		a.ExtraInfo,
		a.OriginalStake * ISNULL(e.Rate, 1) AS OriginalStake,
		a.OriginalBetType,
		a.WalletType,
		a.RefCode,
		a.SiteId
	FROM
		#PagingData AS a
		LEFT JOIN #ExchangeRate AS e ON a.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
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

	DROP TABLE #PlatformList
	DROP TABLE #Data
	DROP TABLE #PagingData
	DROP TABLE #ExchangeRate
	DROP TABLE #TempSportType
END
GO
