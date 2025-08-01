/*<info serverAlias="DBACC-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_Licensee]
	@AgentList			VARCHAR(MAX),
	@Username			VARCHAR(50)		= '',
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@MoveBetsDay		SMALLDATETIME,
	@BalanceUpDay		SMALLDATETIME,
	@ProductList		VARCHAR(300)	= 'All',
	@SportTypeList		VARCHAR(MAX)	= 'All',
	@BetTypeList		VARCHAR(MAX)	= 'All',
	@CashOutMode		TINYINT			= 0,
	@LeagueId			INT				= 0,
	@MatchId			INT				= 0,
	@LeagueGroupIds		VARCHAR(200)	= '',
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
	@Sort				NVARCHAR(50)	= N'TransDate ASC',
	@TotalRows			INT				= 0 OUTPUT,
	@SumStake			MONEY			= 0 OUTPUT,
	@SumWinLost			MONEY			= 0 OUTPUT,
	@SumLicenseeWL		MONEY			= 0 OUTPUT,
	@SumComm			MONEY			= 0 OUTPUT,
	@SumPlayerComm		MONEY			= 0 OUTPUT
AS

/*
	Created: Kos@20180613
	Task: Betting Ticket Center - Multiple Customer Bet List
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
		- @LiveIndicator:
			- 0 : Non-live
			- 1 : Live
			- 2 : Mix Non Live & Live
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
		- @CashOutMode:
			+ 0: Include
			+ 1: Exclude
			+ 2: View CO only

	Revisions:
		- 20180711@Kos: Created [#Redmine: 80941]
		- 20190117@Kos: Fix outright tickets of specific sporttype [#Redmine: 105805]
		- 20190214@Kos: Betting Ticket Center phase 3b [Redmine: #108221]
					- Change input param from @ProductList to @Product
					- Remove input param @ShowBA
		- 20190313@Kos: Change param @LiveIndicator from TINYINT to VARCHAR(10) [Redmine: #108717]
					- Add new param @Username, @ConvertToBaseCur
		- 20200207@Kos: Support sort by trans time [Redmine: #126886]
		- 20211104@Kos: Merge Sports Lottery into Sportsbook [RedmineID: #163191]
		- 20211220@Kos: Support new Cash Out [Redmine: #165160]
		- 20220128@Kos: Support search by IP [RedmineID: #166079]
		- 20230922@Kos: Support crypto currency [Redmine: 177481]
		- 20230316@Kos: Support Saba Sports [Redmine: 183841]
					- Add new input params @LeagueGroupIds, @PlatformType, @CustomerClass, @OddsGroup
		- 20240207@Kos: Hotfix - No data when filtering player has Risk Level Uncategorized [RedmineID: #200913]
					- Add new input param @FullCustomerClass VARCHAR(MAX)
		- 20241226@Kos: Allow to search multiple days [RedmineID: #212395]
					- Remove input params @Product, @SportType, @BetType
					- Add new input params @ProductList VARCHAR(300), @SportTypeList VARCHAR(MAX), @BetTypeList VARCHAR(MAX), @CashOutMode TINYINT
		- 20250110@Kos: Hotfix - VS6 [RedmineID: #216711]
		- 20250116@Kos: VS6 - Fix group bet type [RedmineID: #212446]
		- 20250306@Kos: Hotfix - Missing ExtraInfo for some products [RedmineID: #219311]
		- 20250307@Kos: Fix bug FLOAT rounding [#Redmine: 194970]
		- 20250313@Kos: Remove BA [RedmineID: #216882]
		- 20250318@Kos: Support Virtual Sports 5 [Redmine: 207582]
		- 20250415@Kos: Hotfix - VS racing range bettrans14 [Redmine: 224163]
		- 20250506@Kos: Support Saba Soccer Marble [#Redmine: 225015]
		- 20250523@Kos: Support bk range [RedmineID: #213933]
					- Add new input param @BalanceUpDay SMALLDATETIME
					- Move SP to DBACC
		- 20250724@Kos: Enhance performance when search username [#Redmine: 234062]
		- 20250725@Kos: Hotfix - Parlay sport [#Redmine: 234256]
		- 20250801@Kos: Support Playtech Jackpot [#Redmine: 233781]
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #TempAg (CustId INT, Currency INT)

	CREATE CLUSTERED INDEX IX_TempAg ON #TempAg (CustId)

	DECLARE @HasError BIT = 0

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

	INSERT INTO @SabaSportType
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
		Recommend			INT,
		Currency			SMALLINT,
		SportType			SMALLINT,
		BetType				SMALLINT,
		BetId				BIGINT,
		BetTeam				NVARCHAR(20),
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		OddsType			TINYINT,
		OddsId				INT,
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
		ShowTime			NVARCHAR(50),
		ComStatus			NVARCHAR(20),
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		WalletType			TINYINT,
		RefCode				BIGINT,
		SiteId				VARCHAR(20),
		Product				VARCHAR(30),
		RefTable			TINYINT,
		EventType			TINYINT,
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
		OddsType			TINYINT,
		OddsId				INT,
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
		ShowTime			NVARCHAR(50),
		ComStatus			NVARCHAR(20),
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		WalletType			TINYINT,
		RefCode				BIGINT,
		SiteId				VARCHAR(20),
		Product				VARCHAR(30),
		RefTable			TINYINT,
		EventType			TINYINT,
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

	CREATE TABLE #Customer (
		CustId			INT PRIMARY KEY,
		Username		VARCHAR(30),
		NickName		VARCHAR(50),
		CustomerClass	SMALLINT
	)

	DECLARE @Yesterday SMALLDATETIME = DATEADD(DAY, DATEDIFF(DAY, 1, CURRENT_TIMESTAMP), 0)

	CREATE TABLE #SportBettype (ProductId TINYINT, ProductPrefix VARCHAR(500), BetType SMALLINT, EventType TINYINT, RefTable TINYINT)

	CREATE CLUSTERED INDEX IX_BetType ON #SportBettype (BetType)

	CREATE TABLE #TempBetType (ProductPrefix VARCHAR(10), BetTypeList VARCHAR(MAX))

	CREATE TABLE #TempSportType (SportType SMALLINT, LeagueGroupIdList VARCHAR(200))

	CREATE CLUSTERED INDEX IX_SportType ON #TempSportType (SportType)

	IF @HasError = 0
	BEGIN
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

		-- Get SportBettypeMatrix
		DECLARE @IsTest BIT = 0

		SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

		INSERT INTO #SportBettype
		SELECT ProductID, ProductPrefix, BetType, EventType, RefTable
		FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @ProductList, @IsTest)
		WHERE BetType NOT IN (71, 73, 901, 902, 903, 904, 911, 912, 913, 914)
			AND BetType NOT BETWEEN 801 AND 899
			AND BetType <> 999
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
			FROM #SportBettype AS sbt
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

			DELETE FROM #SportBettype
			WHERE ProductID NOT IN ( SELECT DISTINCT s.ProductID
									FROM dbo.SportBettypeMatrix AS s WITH (NOLOCK)
										INNER JOIN #TempSportType AS st
											ON s.SportType = st.SportType
												OR (s.ProductID = 1 AND st.SportType = -1))
		END TRY
		BEGIN CATCH
			SET @HasError = 1
		END CATCH

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

		CREATE TABLE #TempCust (CustId INT PRIMARY KEY, CustomerClass SMALLINT)

		DECLARE @Site VARCHAR(10)

		SELECT @Site = site
		FROM dbo.Customer WITH (NOLOCK)
		WHERE custid IN (SELECT TOP(1) CustId FROM #TempAg)

		IF @Username IS NOT NULL AND @Username <> ''
		BEGIN
			IF @OddsGroup = 'All'
			BEGIN
				INSERT INTO #TempCust (CustId)
				SELECT c.custid
				FROM (
					SELECT c.custid
					FROM dbo.Customer AS c WITH (NOLOCK)
						INNER JOIN #TempAg AS a ON c.recommend = a.CustId
					WHERE c.roleid = 1
						AND CHARINDEX(@Username, c.username) > 0

					UNION

					SELECT c.custid
					FROM dbo.Customer AS c WITH (NOLOCK, INDEX = IX_agent)
						INNER JOIN #TempAg AS a ON c.recommend = a.CustId
					WHERE c.roleid = 1
						AND c.username2 LIKE @Site + '$%' + @Username + '%'
					) AS c
			END
			ELSE
			BEGIN
				INSERT INTO #TempCust (CustId)
				SELECT c.custid
				FROM (
					SELECT c.custid
					FROM dbo.Customer AS c WITH (NOLOCK)
						INNER JOIN #TempAg AS a ON c.recommend = a.CustId
					WHERE c.roleid = 1
						AND CHARINDEX(@Username, c.username) > 0
						AND ',' + @OddsGroup + ',' LIKE + '%,' + c.ugroup + ',%'

					UNION

					SELECT c.custid
					FROM dbo.Customer AS c WITH (NOLOCK, INDEX = IX_agent)
						INNER JOIN #TempAg AS a ON c.recommend = a.CustId
					WHERE c.roleid = 1
						AND c.username2 LIKE @Site + '$%' + @Username + '%'
						AND ',' + @OddsGroup + ',' LIKE + '%,' + c.ugroup + ',%'
					) AS c
			END

			UPDATE c
			SET c.CustomerClass = ci.CustomerClass
			FROM #TempCust AS c
				LEFT JOIN dbo.custInfo AS ci WITH (NOLOCK) ON ci.custid = c.custid

			IF @CustomerClass <> 'All'
			BEGIN
				DELETE #TempCust
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

		SELECT @NumOfMem = COUNT(1) FROM #TempCust

		DECLARE @MatchSportType	SMALLINT,
			@ParentId			INT

		DECLARE @Match TABLE(MatchId INT)

		IF @MatchId <> 0
		BEGIN
			SELECT
				@MatchSportType = sporttype,
				@ParentId = ParentID
			FROM dbo.match WITH (NOLOCK)
			WHERE matchid = @MatchId AND eventdate > @MoveBetsDay

			IF @MatchSportType IS NULL
			BEGIN
				SELECT
					@MatchSportType = sporttype,
					@ParentId = ParentID
				FROM dbo.match14 WITH (NOLOCK)
				WHERE matchid = @MatchId
			END

			IF @MatchSportType IN (8, 50) AND @ParentId IS NULL		-- Baseball, Cricket, parent match
			BEGIN
				INSERT INTO @Match
				SELECT @MatchId
				UNION
				SELECT DISTINCT MatchId
				FROM dbo.match WITH (NOLOCK)
				WHERE ParentID = @MatchId
					AND sporttype = @MatchSportType
					AND eventdate BETWEEN @FromDate AND @ToDate
					AND ChildMatchType = 200
				UNION
				SELECT DISTINCT MatchId
				FROM dbo.match14 WITH (NOLOCK)
				WHERE ParentID = @MatchId
					AND sporttype = @MatchSportType
					AND eventdate BETWEEN @FromDate AND @ToDate
					AND ChildMatchType = 200
				UNION
				SELECT DISTINCT MatchId
				FROM bodb_Archive.dbo.match_bk WITH (NOLOCK)
				WHERE ParentID = @MatchId
					AND sporttype = @MatchSportType
					AND eventdate BETWEEN @FromDate AND @ToDate
					AND ChildMatchType = 200
			END
		END

		DECLARE @TempToDate	SMALLDATETIME,
			@TempFromDate	SMALLDATETIME

		IF @Username IS NULL OR @Username = '' OR @NumOfMem > 5000		-- Licensee level (not input username of number of searched member > 5000)
		BEGIN
			-- Bettrans range
			IF @ToDate > @MoveBetsDay
			BEGIN
				SET @TempFromDate = CASE
										WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay)
										ELSE @FromDate
									END

				IF NOT EXISTS (SELECT 1 FROM @Match)
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
						StatusId,
						TransDate,
						WinLostDate,
						LiveIndicator,
						LiveHomeScore,
						LiveAwayScore,
						Ip,
						BetFrom,
						MatchId,
						ComStatus,
						BetCheck,
						TransDesc,
						BetdaqId,
						ExtraInfo,
						WalletType,
						RefCode,
						WhTicket)
					SELECT
						b.transid,
						b.refno,
						b.custid,
						b.recommend,
						b.currency,
						b.bettype,
						ISNULL(b.betid, 0) AS BetId,
						b.betteam,
						b.hdp1,
						b.hdp2,
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
						b.statusID,
						b.transdate,
						b.winlostdate,
						b.liveindicator,
						b.livehomescore,
						b.liveawayscore,
						b.ip,
						b.betfrom,
						b.matchid,
						b.comstatus,
						b.betcheck,
						b.transdesc,
						b.betdaqid,
						b.ExtraInfo,
						b.WalletType,
						ISNULL(b.RefCode, 0),
						1 AS WhTicket
					FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_Recommend)
						INNER JOIN #TempAg AS a ON b.recommend = a.CustId
						INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
						LEFT JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1
						LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK) ON m3rd.Match3rdId = b.MatchId AND s.EventType = 5
						LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.matchid = o.orid AND b.bettype = 10
						LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
						LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON vr.EventID = b.matchid AND s.EventType = 3
					WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
						AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
						AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), CASE
																							WHEN b.bettype IN (9, 29) THEN b.livehomescore
																							ELSE b.liveindicator
																						END) + ',%'
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
						AND @LeagueId IN (0, CASE
												WHEN s.EventType = 1 THEN m.leagueid
												WHEN b.bettype = 10 THEN o.leagueid
												ELSE -1
											END)
						AND @MatchId IN (0, b.matchid)
						AND 1 = CASE
									WHEN s.ProductID = 1 THEN
										CASE
											WHEN @CashOutMode IN (0, 2) AND b.betdaqid = -2 THEN 1	-- Cash Out tickets
											WHEN @CashOutMode IN (0, 1) AND b.betdaqid <> -2 THEN 1	-- Normal SB tickets
											ELSE 0
										END
									WHEN @CashOutMode = 2 THEN 0
									ELSE 1
								END
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
						StatusId,
						TransDate,
						WinLostDate,
						LiveIndicator,
						LiveHomeScore,
						LiveAwayScore,
						Ip,
						BetFrom,
						MatchId,
						ComStatus,
						BetCheck,
						TransDesc,
						BetdaqId,
						ExtraInfo,
						WalletType,
						RefCode,
						WhTicket)
					SELECT
						b.transid,
						b.refno,
						b.custid,
						b.recommend,
						b.currency,
						b.bettype,
						ISNULL(b.betid, 0) AS BetId,
						b.betteam,
						b.hdp1,
						b.hdp2,
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
						b.statusID,
						b.transdate,
						b.winlostdate,
						b.liveindicator,
						b.livehomescore,
						b.liveawayscore,
						b.ip,
						b.betfrom,
						b.matchid,
						b.comstatus,
						b.betcheck,
						b.transdesc,
						b.betdaqid,
						b.ExtraInfo,
						b.WalletType,
						ISNULL(b.RefCode, 0),
						1 AS WhTicket
					FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_Recommend)
						INNER JOIN #TempAg AS a ON b.recommend = a.CustId
						INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
						INNER JOIN @Match AS tm ON tm.MatchId = b.matchid
						LEFT JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1
						LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK) ON m3rd.Match3rdId = b.MatchId AND s.EventType = 5
						LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.matchid = o.orid AND b.bettype = 10
						LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
						LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON vr.EventID = b.matchid AND s.EventType = 3
					WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
						AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
						AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), CASE
																							WHEN b.bettype IN (9, 29) THEN b.livehomescore
																							ELSE b.liveindicator
																						END) + ',%'
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
						AND @LeagueId IN (0, CASE
												WHEN s.EventType = 1 THEN m.leagueid
												WHEN b.bettype = 10 THEN o.leagueid
												ELSE -1
											END)
						AND 1 = CASE
									WHEN s.ProductID = 1 THEN
										CASE
											WHEN @CashOutMode IN (0, 2) AND b.betdaqid = -2 THEN 1	-- Cash Out tickets
											WHEN @CashOutMode IN (0, 1) AND b.betdaqid <> -2 THEN 1	-- Normal SB tickets
											ELSE 0
										END
									WHEN @CashOutMode = 2 THEN 0
									ELSE 1
								END
				END
			END

			-- Bettrans14 range
			IF @FromDate <= @MoveBetsDay AND @ToDate >= @BalanceUpDay 
				AND @OriginalStatusIdList <> '2'
			BEGIN
				SET @TempFromDate = CASE
										WHEN @FromDate < @BalanceUpDay THEN @BalanceUpDay
										ELSE @FromDate
									END

				SET @TempToDate = CASE
									WHEN @ToDate > @MoveBetsDay THEN @MoveBetsDay
									ELSE @ToDate
								END

				IF NOT EXISTS (SELECT 1 FROM @Match)
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
					StatusId,
					TransDate,
					WinLostDate,
					LiveIndicator,
					LiveHomeScore,
					LiveAwayScore,
					Ip,
					BetFrom,
					MatchId,
					ComStatus,
					BetCheck,
					TransDesc,
					BetdaqId,
					ExtraInfo,
					WalletType,
					RefCode,
					WhTicket)
				SELECT
					b.transid,
					b.refno,
					b.custid,
					b.recommend,
					b.currency,
					b.bettype,
					ISNULL(b.betid, 0) AS BetId,
					b.betteam,
					b.hdp1,
					b.hdp2,
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
					b.statusID,
					b.transdate,
					b.winlostdate,
					b.liveindicator,
					b.livehomescore,
					b.liveawayscore,
					b.ip,
					b.betfrom,
					b.matchid,
					b.comstatus,
					b.betcheck,
					b.transdesc,
					b.betdaqid,
					b.ExtraInfo,
					b.WalletType,
					ISNULL(b.RefCode, 0),
					2 AS WhTicket
				FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_bettrans3)
					INNER JOIN #TempAg AS a ON b.recommend = a.CustId
					INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
					LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1
					LEFT JOIN dbo.Match3rd14 AS m3rd WITH (NOLOCK) ON m3rd.Match3rdId = b.MatchId AND s.EventType = 5
					LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.matchid = o.orid AND b.bettype = 10
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
					LEFT JOIN dbo.VSRaceInfo14 AS vr WITH (NOLOCK) ON vr.EventID = b.matchid AND s.EventType = 3
				WHERE b.winlostdate BETWEEN @TempFromDate AND @TempToDate
					AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
					AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), CASE
																						WHEN b.bettype IN (9, 29) THEN b.livehomescore
																						ELSE b.liveindicator
																					END) + ',%'
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
														WHEN s.EventType = 0 AND s.ProductID IN (27, 83) THEN b.oddsid
														WHEN s.RefTable IN (1, 2) THEN b.matchid
														ELSE 0
													END))
					AND @LeagueId IN (0, CASE
											WHEN s.EventType = 1 THEN m.leagueid
											WHEN b.bettype = 10 THEN o.leagueid
											ELSE -1
										END)
					AND @MatchId IN (0, b.matchid)
					AND 1 = CASE
								WHEN s.ProductID = 1 THEN
									CASE
										WHEN @CashOutMode IN (0, 2) AND b.betdaqid = -2 THEN 1	-- Cash Out tickets
										WHEN @CashOutMode IN (0, 1) AND b.betdaqid <> -2 THEN 1	-- Normal SB tickets
										ELSE 0
									END
								WHEN @CashOutMode = 2 THEN 0
								ELSE 1
							END
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
					StatusId,
					TransDate,
					WinLostDate,
					LiveIndicator,
					LiveHomeScore,
					LiveAwayScore,
					Ip,
					BetFrom,
					MatchId,
					ComStatus,
					BetCheck,
					TransDesc,
					BetdaqId,
					ExtraInfo,
					WalletType,
					RefCode,
					WhTicket)
				SELECT
					b.transid,
					b.refno,
					b.custid,
					b.recommend,
					b.currency,
					b.bettype,
					ISNULL(b.betid, 0) AS BetId,
					b.betteam,
					b.hdp1,
					b.hdp2,
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
					b.statusID,
					b.transdate,
					b.winlostdate,
					b.liveindicator,
					b.livehomescore,
					b.liveawayscore,
					b.ip,
					b.betfrom,
					b.matchid,
					b.comstatus,
					b.betcheck,
					b.transdesc,
					b.betdaqid,
					b.ExtraInfo,
					b.WalletType,
					ISNULL(b.RefCode, 0),
					2 AS WhTicket
				FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_bettrans3)
					INNER JOIN #TempAg AS a ON b.recommend = a.CustId
					INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
					INNER JOIN @Match AS tm ON tm.MatchId = b.matchid
					LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1
					LEFT JOIN dbo.Match3rd14 AS m3rd WITH (NOLOCK) ON m3rd.Match3rdId = b.MatchId AND s.EventType = 5
					LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.matchid = o.orid AND b.bettype = 10
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
					LEFT JOIN dbo.VSRaceInfo14 AS vr WITH (NOLOCK) ON vr.EventID = b.matchid AND s.EventType = 3
				WHERE b.winlostdate BETWEEN @TempFromDate AND @TempToDate
					AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
					AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), CASE
																						WHEN b.bettype IN (9, 29) THEN b.livehomescore
																						ELSE b.liveindicator
																					END) + ',%'
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
														WHEN s.EventType = 0 AND s.ProductID IN (27, 83) THEN b.oddsid
														WHEN s.RefTable IN (1, 2) THEN b.matchid
														ELSE 0
													END))
					AND @LeagueId IN (0, CASE
											WHEN s.EventType = 1 THEN m.leagueid
											WHEN b.bettype = 10 THEN o.leagueid
											ELSE -1
										END)
					AND 1 = CASE
								WHEN s.ProductID = 1 THEN
									CASE
										WHEN @CashOutMode IN (0, 2) AND b.betdaqid = -2 THEN 1	-- Cash Out tickets
										WHEN @CashOutMode IN (0, 1) AND b.betdaqid <> -2 THEN 1	-- Normal SB tickets
										ELSE 0
									END
								WHEN @CashOutMode = 2 THEN 0
								ELSE 1
							END
				END
			END

			-- Bettrans_bk range
			IF @FromDate < @BalanceUpDay AND @OriginalStatusIdList <> '2'
			BEGIN
				SET @TempFromDate = @FromDate
				SET @TempToDate = CASE
									WHEN @ToDate >= DATEADD(DD, -1, @BalanceUpDay) THEN DATEADD(DD, -1, @BalanceUpDay)
									ELSE @ToDate
								END

				DECLARE @TmpDate TABLE (Date SMALLDATETIME)

				DECLARE @TmpAgDate TABLE (
					CustId	INT,
					Date	SMALLDATETIME
				)

				;WITH X AS 
				(
					SELECT @TempFromDate AS VAL
					UNION ALL
					SELECT DATEADD(DD, 1, VAL) FROM X
					WHERE VAL < @TempToDate
				)
				INSERT INTO @TmpDate
				SELECT *
				FROM X
				OPTION(MAXRECURSION 0)

				INSERT INTO @TmpAgDate
				SELECT
					a.CustId,
					d.Date
				FROM #TempAg AS a
					CROSS JOIN @TmpDate AS d

				DECLARE @str VARCHAR(MAX) = (SELECT STRING_AGG(CAST(BetType AS VARCHAR(MAX)), ',') FROM #SportBettype)

				IF NOT EXISTS (SELECT 1 FROM @Match)
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
						OddsType,
						OddsId,
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
						StatusId,
						TransDate,
						WinLostDate,
						LiveIndicator,
						LiveHomeScore,
						LiveAwayScore,
						Ip,
						BetFrom,
						MatchId,
						ComStatus,
						BetCheck,
						TransDesc,
						BetdaqId,
						ExtraInfo,
						WalletType,
						RefCode,
						WhTicket)
					SELECT
						b.transid,
						b.refno,
						b.custid,
						b.recommend,
						b.currency,
						b.bettype,
						ISNULL(b.betid, 0) AS BetId,
						b.betteam,
						b.hdp1,
						b.hdp2,
						b.oddstype,
						b.oddsid,
						b.odds,
						b.modds,
						b.oddsspread,
						b.stake,
						b.actual_stake,
						(b.winlost - b.actual_stake) AS WinLost,
						CASE
							WHEN b.tpositiontaking = 0 THEN 0
							ELSE - (b.winlost - b.actual_stake)
						END AS LiceseeWL,
						b.comm,
						b.playercomm,
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
						b.comstatus,
						b.betcheck,
						b.transdesc,
						b.betdaqid,
						b.ExtraInfo,
						b.WalletType,
						ISNULL(b.RefCode, 0),
						3 AS WhTicket
					FROM @TmpAgDate AS t
						CROSS APPLY (
							SELECT b.*
							FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
							WHERE b.recommend = t.CustId
								AND b.winlostdate = t.Date
								AND CHARINDEX(',' + CONVERT(VARCHAR(10), b.bettype) + ',', ',' + @str + ',', 1) > 0
						) b
						CROSS APPLY dbo.f_IP_Decompress(b.ip) AS dp
					OPTION (MAXDOP 8)

					DELETE FROM #Data
					WHERE WhTicket = 3
						AND (',' + @StatusIdList + ',' NOT LIKE '%,' + CONVERT(VARCHAR(3), StatusId) + ',%'
							OR ',' + @LiveIndicator + ',' NOT LIKE '%,' + CONVERT(VARCHAR(3), CASE
																								WHEN BetType IN (9, 29) THEN LiveHomeScore
																								ELSE LiveIndicator
																							END) + ',%')

					IF @MatchId <> 0
						DELETE FROM #Data
						WHERE MatchId <> @MatchId AND WhTicket = 3

					DELETE b
					FROM #Data AS b
						INNER JOIN #SportBettype AS s ON s.BetType = b.BetType
					WHERE b.WhTicket = 3
						AND 1 <> CASE
									WHEN s.ProductId = 1 THEN
										CASE
											WHEN @CashOutMode IN (0, 2) AND b.BetdaqId = -2 THEN 1	-- Cash Out tickets
											WHEN @CashOutMode IN (0, 1) AND b.BetdaqId <> -2 THEN 1	-- Normal SB tickets
											ELSE 0
										END
									WHEN @CashOutMode = 2 THEN 0
									ELSE 1
								END

					IF @LeagueId <> 0
						DELETE b
						FROM #Data AS b
							INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
							LEFT JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1
							LEFT JOIN bodb_Archive.dbo.outright_bk AS o WITH (NOLOCK) ON b.matchid = o.orid AND b.bettype = 10
							LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
						WHERE b.WhTicket = 3
							AND @LeagueId <> CASE
												WHEN s.EventType = 1 THEN m.leagueid
												WHEN b.bettype = 10 THEN o.leagueid
												ELSE -1
											END

					IF @SportTypeList <> 'All'
						DELETE b
						FROM #Data AS b
							INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
							LEFT JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1
							LEFT JOIN bodb_Archive.dbo.Match3rd_bk AS m3rd WITH (NOLOCK) ON m3rd.Match3rdId = b.MatchId AND s.EventType = 5
							LEFT JOIN bodb_Archive.dbo.outright_bk AS o WITH (NOLOCK) ON b.matchid = o.orid AND b.bettype = 10
							LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
							LEFT JOIN bodb_Archive.dbo.VSRaceInfo_bk AS vr WITH (NOLOCK) ON vr.EventID = b.matchid AND s.EventType = 3
						WHERE b.WhTicket = 3
							AND NOT EXISTS (	SELECT 1 FROM #TempSportType
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

					IF @MatchId <> 0
						DELETE FROM #Data
						WHERE MatchId <> @MatchId AND WhTicket = 3

					DELETE b
					FROM #Data AS b
						INNER JOIN #SportBettype AS s ON s.BetType = b.BetType
					WHERE b.WhTicket = 3
						AND 1 <> CASE
									WHEN s.ProductId = 1 THEN
										CASE
											WHEN @CashOutMode IN (0, 2) AND b.BetdaqId = -2 THEN 1	-- Cash Out tickets
											WHEN @CashOutMode IN (0, 1) AND b.BetdaqId <> -2 THEN 1	-- Normal SB tickets
											ELSE 0
										END
									WHEN @CashOutMode = 2 THEN 0
									ELSE 1
								END
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
						StatusId,
						TransDate,
						WinLostDate,
						LiveIndicator,
						LiveHomeScore,
						LiveAwayScore,
						Ip,
						BetFrom,
						MatchId,
						ComStatus,
						BetCheck,
						TransDesc,
						BetdaqId,
						ExtraInfo,
						WalletType,
						RefCode,
						WhTicket)
					SELECT
						b.transid,
						b.refno,
						b.custid,
						b.recommend,
						b.currency,
						b.bettype,
						ISNULL(b.betid, 0) AS BetId,
						b.betteam,
						b.hdp1,
						b.hdp2,
						b.oddstype,
						b.odds,
						b.modds,
						b.oddsspread,
						b.stake,
						b.actual_stake,
						(b.winlost - b.actual_stake) AS WinLost,
						CASE
							WHEN s.ProductID = 1 AND b.tpositiontaking = 0 THEN 0
							ELSE - (b.winlost - b.actual_stake)
						END AS LiceseeWL,
						b.comm,
						b.playercomm,
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
						b.comstatus,
						b.betcheck,
						b.transdesc,
						b.betdaqid,
						b.ExtraInfo,
						b.WalletType,
						ISNULL(b.RefCode, 0),
						3 AS WhTicket
					FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
						INNER JOIN #TempAg AS a ON b.recommend = a.CustId
						INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
						INNER JOIN @Match AS tm ON tm.MatchId = b.matchid
						LEFT JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1
						LEFT JOIN bodb_Archive.dbo.Match3rd_bk AS m3rd WITH (NOLOCK) ON m3rd.Match3rdId = b.MatchId AND s.EventType = 5
						LEFT JOIN bodb_Archive.dbo.outright_bk AS o WITH (NOLOCK) ON b.matchid = o.orid AND b.bettype = 10
						LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
						LEFT JOIN bodb_Archive.dbo.VSRaceInfo_bk AS vr WITH (NOLOCK) ON vr.EventID = b.matchid AND s.EventType = 3
						CROSS APPLY dbo.f_IP_Decompress(b.ip) AS dp
					WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
						AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
						AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), CASE
																							WHEN b.bettype IN (9, 29) THEN b.livehomescore
																							ELSE b.liveindicator
																						END) + ',%'
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
						AND @LeagueId IN (0, CASE
												WHEN s.EventType = 1 THEN m.leagueid
												WHEN b.bettype = 10 THEN o.leagueid
												ELSE -1
											END)
						AND @MatchId IN (0, b.matchid)
						AND 1 = CASE
									WHEN s.ProductID = 1 THEN
										CASE
											WHEN @CashOutMode IN (0, 2) AND b.betdaqid = -2 THEN 1	-- Cash Out tickets
											WHEN @CashOutMode IN (0, 1) AND b.betdaqid <> -2 THEN 1	-- Normal SB tickets
											ELSE 0
										END
									WHEN @CashOutMode = 2 THEN 0
									ELSE 1
								END
				END
			END
		END
		ELSE
		BEGIN
			-- Bettrans range
			IF @ToDate > @MoveBetsDay
			BEGIN
				SET @TempFromDate = CASE
										WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay)
										ELSE @FromDate
									END

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
					StatusId,
					TransDate,
					WinLostDate,
					LiveIndicator,
					LiveHomeScore,
					LiveAwayScore,
					Ip,
					BetFrom,
					MatchId,
					ComStatus,
					BetCheck,
					TransDesc,
					BetdaqId,
					ExtraInfo,
					WalletType,
					RefCode,
					WhTicket)
				SELECT
					b.transid,
					b.refno,
					b.custid,
					b.recommend,
					b.currency,
					b.bettype,
					ISNULL(b.betid, 0) AS BetId,
					b.betteam,
					b.hdp1,
					b.hdp2,
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
					b.statusID,
					b.transdate,
					b.winlostdate,
					b.liveindicator,
					b.livehomescore,
					b.liveawayscore,
					b.ip,
					b.betfrom,
					b.matchid,
					b.comstatus,
					b.betcheck,
					b.transdesc,
					b.betdaqid,
					b.ExtraInfo,
					b.WalletType,
					ISNULL(b.RefCode, 0),
					1 AS WhTicket
				FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_CustId)
					INNER JOIN #TempCust AS c ON b.custid = c.CustId
					INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
					LEFT JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1
					LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK) ON m3rd.Match3rdId = b.MatchId AND s.EventType = 5
					LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.matchid = o.orid AND b.bettype = 10
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
					LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON vr.EventID = b.matchid AND s.EventType = 3
				WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
					AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
					AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), CASE
																						WHEN b.bettype IN (9, 29) THEN b.livehomescore
																						ELSE b.liveindicator
																					END) + ',%'
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
					AND @LeagueId IN (0, CASE
											WHEN s.EventType = 1 THEN m.leagueid
											WHEN b.bettype = 10 THEN o.leagueid
											ELSE -1
										END)
					AND (@MatchId IN (0, b.matchid)
						OR b.matchid IN (SELECT MatchId FROM @Match))
					AND 1 = CASE
								WHEN s.ProductID = 1 THEN
									CASE
										WHEN @CashOutMode IN (0, 2) AND b.betdaqid = -2 THEN 1	-- Cash Out tickets
										WHEN @CashOutMode IN (0, 1) AND b.betdaqid <> -2 THEN 1	-- Normal SB tickets
										ELSE 0
									END
								WHEN @CashOutMode = 2 THEN 0
								ELSE 1
							END
			END

			-- Bettrans14 range
			IF @FromDate <= @MoveBetsDay AND @ToDate >= @BalanceUpDay
				AND @OriginalStatusIdList <> '2'
			BEGIN
				SET @TempFromDate = CASE
										WHEN @FromDate < @BalanceUpDay THEN @BalanceUpDay
										ELSE @FromDate
									END

				SET @TempToDate = CASE
									WHEN @ToDate > @MoveBetsDay THEN @MoveBetsDay
									ELSE @ToDate
								END

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
					StatusId,
					TransDate,
					WinLostDate,
					LiveIndicator,
					LiveHomeScore,
					LiveAwayScore,
					Ip,
					BetFrom,
					MatchId,
					ComStatus,
					BetCheck,
					TransDesc,
					BetdaqId,
					ExtraInfo,
					WalletType,
					RefCode,
					WhTicket)
				SELECT
					b.transid,
					b.refno,
					b.custid,
					b.recommend,
					b.currency,
					b.bettype,
					ISNULL(b.betid, 0) AS BetId,
					b.betteam,
					b.hdp1,
					b.hdp2,
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
					b.statusID,
					b.transdate,
					b.winlostdate,
					b.liveindicator,
					b.livehomescore,
					b.liveawayscore,
					b.ip,
					b.betfrom,
					b.matchid,
					b.comstatus,
					b.betcheck,
					b.transdesc,
					b.betdaqid,
					b.ExtraInfo,
					b.WalletType,
					ISNULL(b.RefCode, 0),
					2 AS WhTicket
				FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_bettrans3)
					INNER JOIN #TempCust AS c ON b.custid = c.CustId
					INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
					LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1
					LEFT JOIN dbo.Match3rd14 AS m3rd WITH (NOLOCK) ON m3rd.Match3rdId = b.MatchId AND s.EventType = 5
					LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.matchid = o.orid AND b.bettype = 10
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
					LEFT JOIN dbo.VSRaceInfo14 AS vr WITH (NOLOCK) ON vr.EventID = b.matchid AND s.EventType = 3
				WHERE b.winlostdate BETWEEN @TempFromDate AND @TempToDate
					AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
					AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), CASE
																						WHEN b.bettype IN (9, 29) THEN b.livehomescore
																						ELSE b.liveindicator
																					END) + ',%'
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
														WHEN s.EventType = 0 AND s.ProductID IN (27, 83) THEN b.oddsid
														WHEN s.RefTable IN (1, 2) THEN b.matchid
														ELSE 0
													END))
					AND @LeagueId IN (0, CASE
											WHEN s.EventType = 1 THEN m.leagueid
											WHEN b.bettype = 10 THEN o.leagueid
											ELSE -1
										END)
					AND (@MatchId IN (0, b.matchid)
						OR b.matchid IN (SELECT MatchId FROM @Match))
					AND 1 = CASE
								WHEN s.ProductID = 1 THEN
									CASE
										WHEN @CashOutMode IN (0, 2) AND b.betdaqid = -2 THEN 1	-- Cash Out tickets
										WHEN @CashOutMode IN (0, 1) AND b.betdaqid <> -2 THEN 1	-- Normal SB tickets
										ELSE 0
									END
								WHEN @CashOutMode = 2 THEN 0
								ELSE 1
							END
			END

			-- Bettrans_bk range
			IF @FromDate < @BalanceUpDay AND @OriginalStatusIdList <> '2'
			BEGIN
				SET @TempToDate = CASE
									WHEN @ToDate >= DATEADD(DD, -1, @BalanceUpDay) THEN DATEADD(DD, -1, @BalanceUpDay)
									ELSE @ToDate
								END

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
					StatusId,
					TransDate,
					WinLostDate,
					LiveIndicator,
					LiveHomeScore,
					LiveAwayScore,
					Ip,
					BetFrom,
					MatchId,
					ComStatus,
					BetCheck,
					TransDesc,
					BetdaqId,
					ExtraInfo,
					WalletType,
					RefCode,
					WhTicket)
				SELECT
					b.transid,
					b.refno,
					b.custid,
					b.recommend,
					b.currency,
					b.bettype,
					ISNULL(b.betid, 0) AS BetId,
					b.betteam,
					b.hdp1,
					b.hdp2,
					b.oddstype,
					b.odds,
					b.modds,
					b.oddsspread,
					b.stake,
					b.actual_stake,
					(b.winlost - b.actual_stake) AS WinLost,
					CASE
						WHEN s.ProductID = 1 AND b.tpositiontaking = 0 THEN 0
						ELSE - (b.winlost - b.actual_stake)
					END AS LiceseeWL,
					b.comm,
					b.playercomm,
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
					b.comstatus,
					b.betcheck,
					b.transdesc,
					b.betdaqid,
					b.ExtraInfo,
					b.WalletType,
					ISNULL(b.RefCode, 0),
					3 AS WhTicket
				FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX = IX_CustId)
					INNER JOIN #TempCust AS c ON b.custid = c.CustId
					INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
					LEFT JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1
					LEFT JOIN bodb_Archive.dbo.Match3rd_bk AS m3rd WITH (NOLOCK) ON m3rd.Match3rdId = b.MatchId AND s.EventType = 5
					LEFT JOIN bodb_Archive.dbo.outright_bk AS o WITH (NOLOCK) ON b.matchid = o.orid AND b.bettype = 10
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
					LEFT JOIN bodb_Archive.dbo.VSRaceInfo_bk AS vr WITH (NOLOCK) ON vr.EventID = b.matchid AND s.EventType = 3
					CROSS APPLY dbo.f_IP_Decompress(b.ip) AS dp
				WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
					AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
					AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), CASE
																						WHEN b.bettype IN (9, 29) THEN b.livehomescore
																						ELSE b.liveindicator
																					END) + ',%'
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
					AND @LeagueId IN (0, CASE
											WHEN s.EventType = 1 THEN m.leagueid
											WHEN b.bettype = 10 THEN o.leagueid
											ELSE -1
										END)
					AND (@MatchId IN (0, b.matchid)
						OR b.matchid IN (SELECT MatchId FROM @Match))
					AND 1 = CASE
								WHEN s.ProductID = 1 THEN
									CASE
										WHEN @CashOutMode IN (0, 2) AND b.betdaqid = -2 THEN 1	-- Cash Out tickets
										WHEN @CashOutMode IN (0, 1) AND b.betdaqid <> -2 THEN 1	-- Normal SB tickets
										ELSE 0
									END
								WHEN @CashOutMode = 2 THEN 0
								ELSE 1
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
			CREATE TABLE #AllPlatformList (BetFrom NVARCHAR(4))
			CREATE TABLE #PlatformList (BetFrom NVARCHAR(4))

			INSERT INTO #AllPlatformList (BetFrom)
			SELECT DISTINCT betfrom
			FROM dbo.Lrf_f_BetFromType_Sel('All')

			INSERT INTO #PlatformList (BetFrom)
			SELECT DISTINCT betfrom
			FROM dbo.Lrf_f_BetFromType_Sel(@PlatformType)

			DELETE b
			FROM #Data AS b
				LEFT JOIN #PlatformList AS pl ON pl.BetFrom = b.BetFrom
				LEFT JOIN #AllPlatformList AS apl ON apl.BetFrom = b.betfrom
			WHERE 1 = CASE
							WHEN pl.BetFrom IS NOT NULL THEN 0
							WHEN apl.BetFrom IS NULL AND ',' + @PlatformType + ',' LIKE '%,88,%' THEN 0
							WHEN apl.BetFrom IS NULL AND ',' + @PlatformType + ',' LIKE '%,99,%' THEN 0
							ELSE 1
						END

			DROP TABLE #AllPlatformList
			DROP TABLE #PlatformList
		END

		UPDATE b
		SET b.Product = CASE
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
							WHEN s.ProductId = 63 THEN 'SLT'							-- Sports Lottery
							WHEN s.ProductID = 66 THEN 'VGA'							-- Vgaming
							WHEN s.ProductID = 67 THEN 'AP'								-- AdvantPlay
							WHEN s.ProductID = 68 THEN 'APM'							-- AdvantPlay Mini
							WHEN s.ProductId = 69 THEN 'BTC'							-- Bitcoin
							WHEN s.ProductID = 70 THEN 'FGGL'							-- FGG
							WHEN s.ProductId = 72 THEN 'SEA'							-- SEAL Entertainment
							WHEN s.ProductID = 73 THEN 'MGRNG'							-- MG-RNG
							WHEN s.ProductID = 75 THEN 'JIG'							-- Jili
							WHEN s.ProductID = 76 THEN 'YB'								-- YeeBet
							WHEN s.ProductID = 77 THEN 'LG'								-- Virtual Sports 3
							WHEN s.EventType = 0 AND s.ProductId = 1 THEN 'Parlay'	-- Sportsbook Parlay
							WHEN s.EventType = 1 AND s.ProductId = 1 THEN 'SB'		-- Sportsbook
							WHEN s.EventType = 2 AND s.ProductId = 1 THEN 'Outright'
							WHEN s.EventType = 0 AND s.ProductID = 3 THEN 'H5LG'		-- Happy 5 Linked Games (Number Game)
							WHEN s.EventType = 0 AND s.ProductID = 27 THEN 'ParlayVS2'	-- Betradar Virtual Sports Parlay
							WHEN s.EventType = 1 AND s.ProductID = 3 THEN 'NG'			-- Number Game
							WHEN s.EventType = 1 AND s.ProductID = 5 THEN 'VS'			-- Virtual Sports Sportsbook
							WHEN s.EventType = 1 AND s.ProductID = 27 THEN 'VS2'		-- Betradar Virtual Sports
							ELSE 'Unknown'
						END,
			b.RefTable = s.RefTable,
			b.EventType = s.EventType
		FROM #Data AS b
			INNER JOIN #SportBettype AS s ON s.BetType = b.BetType

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
			WHERE b.Product = 'SB' AND b.WhTicket = 1

			UPDATE b
			SET SportType = m.sporttype,
				LeagueId = m.leagueid,
				LeagueGroupId = l.LeagueGroupID
			FROM #Data AS b
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.MatchId
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
			WHERE b.Product = 'SB' AND b.WhTicket = 2

			UPDATE b
			SET SportType = m.sporttype,
				LeagueId = m.leagueid,
				LeagueGroupId = l.LeagueGroupID
			FROM #Data AS b
				INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON m.matchid = b.MatchId
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
			WHERE b.Product = 'SB' AND b.WhTicket = 3

			UPDATE b
			SET SportType = l.sporttype,
				LeagueId = l.leagueid,
				LeagueGroupId = l.LeagueGroupID
			FROM #Data AS b
				INNER JOIN dbo.outright AS o WITH (NOLOCK) ON o.orid = b.MatchId
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = o.leagueid
			WHERE b.Product = 'Outright' AND b.WhTicket = 1

			UPDATE b
			SET SportType = l.sporttype,
				LeagueId = l.leagueid,
				LeagueGroupId = l.LeagueGroupID
			FROM #Data AS b
				INNER JOIN dbo.outright14 AS o WITH (NOLOCK) ON o.orid = b.MatchId
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = o.leagueid
			WHERE b.Product = 'Outright' AND b.WhTicket = 2

			UPDATE b
			SET SportType = l.sporttype,
				LeagueId = l.leagueid,
				LeagueGroupId = l.LeagueGroupID
			FROM #Data AS b
				INNER JOIN bodb_Archive.dbo.outright_bk AS o WITH (NOLOCK) ON o.orid = b.MatchId
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = o.leagueid
			WHERE b.Product = 'Outright' AND b.WhTicket = 3

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

		IF @Username IS NULL OR @Username = ''
		BEGIN
			INSERT INTO #TempCust (CustId, CustomerClass)
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
				DELETE #TempCust
				WHERE 1 <> CASE
								WHEN ',' + @CustomerClass + ',' LIKE '%,0,%' AND CustomerClass IS NULL THEN 1
								WHEN ',' + @CustomerClass + ',' LIKE '%,0,%'
									AND ',' + @FullCustomerClass + ',' NOT LIKE '%,' + CONVERT(VARCHAR(6), CustomerClass) + ',%' THEN 1
								WHEN ',' + @CustomerClass + ',' LIKE '%,' + CONVERT(VARCHAR(6), CustomerClass) + ',%' THEN 1
								ELSE 0
							END
			END
		END

		CREATE NONCLUSTERED INDEX IX_CustId ON #Data (CustId)

		DELETE b
		FROM #Data AS b
		WHERE NOT EXISTS (SELECT 1 FROM #TempCust WHERE CustId = b.CustId)
			OR (b.Product NOT IN ('SB', 'Parlay')
				AND ',' + @OriginalStatusIdList + ',' NOT LIKE '%,' + CONVERT(VARCHAR(3), StatusId) + ',%')
			OR (b.Product = 'Parlay'
				AND b.Status IN ('Draw', 'Won', 'Lose')
				AND ',' + @OriginalStatusIdList + ',' NOT LIKE '%,' + CONVERT(VARCHAR(3), StatusId) + ',%')

		IF ',' + @OriginalStatusIdList + ',' NOT LIKE '%,99,%'
		BEGIN
			DELETE b
			FROM #Data AS b
			WHERE b.Status = 'Void'
				AND ISNULL(CAST(('<xml>' + ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@ab)[1]','TINYINT'), 0) = 1
		END

		IF ',' + @OriginalStatusIdList + ',' NOT LIKE '%,102,%'
		BEGIN
			DELETE b
			FROM #Data AS b
			WHERE b.Status = 'Void'
				AND ISNULL(CAST(('<xml>' + ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@ab)[1]','TINYINT'), 0) = 0
		END

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
					AND (Stake <> 0						-- Not Cash Out All
						OR BetdaqId <> 0
						OR ExtraInfo NOT LIKE '%p25%')
			END
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
						WHEN Product IN ('OneRNG', 'PP', 'SBC', 'VGA', 'SG', 'PTRNG') THEN ISNULL(AVG(CASE WHEN brng.statusID IN (111, 112, 113)
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
					TransId = CASE
									WHEN b.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
									ELSE b.transid
								END,
					SportType = CASE
									WHEN b.Product IN ('SLT', 'Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VRG', 'TG', 'SBC', 'I4D', 'SXG', 'SAG', 'PGS', 'JK',
										'H5LG', 'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM', 'VS3', 'FGGL', 'MXG', 'JIG', 'YB', 'MGRNG', 'SEA') THEN b.MatchId
									WHEN b.Product = 'AllBet' THEN 211		-- AllBet
									WHEN b.Product = 'VB' THEN 212			-- Macau Games
									WHEN b.Product = 'PP' THEN 248			-- Pragmatic Casino
									WHEN b.Product = 'Outright' THEN l.sporttype
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
					LeagueId = CASE
								WHEN b.EventType = 1 THEN m.leagueid
								WHEN b.EventType = 3 THEN vr.LeagueID
								WHEN b.EventType = 5 THEN m3rd.League3rdId
								WHEN b.Product = 'Outright' THEN o.leagueid
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
					ShowTime = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(m.showtime, '')
									WHEN b.Product IN ('VS') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN b.EventType = 5 THEN CONVERT(NVARCHAR(50), m3rd.StartTime)
									ELSE ''
								END,
					BetCheck = CASE
								WHEN b.Product IN ('SB', 'Parlay', 'SLT', 'VRG', 'H5LG') THEN ISNULL(b.BetCheck, '')
								WHEN b.EventType = 0 AND b.RefTable = 0 THEN ISNULL(b.betcheck, '')
								WHEN b.Product IN ('Keno') THEN ISNULL(b.ComStatus, '')
								ELSE ''
							END,
					TransDesc = CASE
									WHEN b.Product IN ('SB', 'SLT', 'Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VB', 'PP', 
										'VRG', 'TG', 'I4D', 'PGS', 'JK', 'H5LG', 'HB', 'CG', 'AP', 'APM', 'SEA') THEN ISNULL(b.transdesc, '')
									WHEN b.EventType IN (1, 3, 5) THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					BetdaqId = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.BetdaqId, -1)
									ELSE -1
								END,
					OriginalStake = 0,
					OriginalBetType = CASE
										WHEN b.Product = 'SB' AND b.stake <> 0 THEN -1
										ELSE 0
									END,
					WalletType = CASE
									WHEN b.Product = 'SB' THEN ISNULL(b.WalletType, 0)
									ELSE 0
								END,
					RefCode = CASE
									WHEN b.Product = 'SB' THEN ISNULL(b.RefCode, 0)
									ELSE 0
								END,
					SiteId = CASE
								WHEN b.Product IN ('SLT', 'H5LG', 'VRG') THEN CONVERT(VARCHAR(20), b.BetdaqId)
								ELSE ''
							END
				FROM #PagingData AS b
					LEFT JOIN dbo.match AS m WITH (NOLOCK) ON b.EventType = 1 AND m.matchid = b.matchid
					LEFT JOIN dbo.League AS le WITH (NOLOCK) ON b.Product IN ('SB') AND le.leagueid = m.leagueid
					LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK) ON b.EventType = 5 AND m3rd.Match3rdId = b.matchid
					LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.Product = 'Outright' AND o.orid = b.matchid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product = 'Outright' AND l.leagueid = o.leagueid
					LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON b.EventType = 3 AND vr.EventID = b.matchid
				WHERE b.WhTicket = 1
			END

			-- bettrans14
			IF EXISTS (SELECT TOP(1) 1 FROM #PagingData WHERE WhTicket = 2)
			BEGIN
				UPDATE b
				SET
					TransId = CASE
									WHEN b.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
									ELSE b.transid
								END,
					SportType = CASE
									WHEN b.Product IN ('SLT', 'Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VRG', 'TG', 'SBC', 'I4D', 'SXG', 'SAG', 'PGS', 'JK',
										'H5LG', 'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM', 'VS3', 'FGGL', 'MXG', 'JIG', 'YB', 'MGRNG', 'SEA') THEN b.MatchId
									WHEN b.Product = 'AllBet' THEN 211		-- AllBet
									WHEN b.Product = 'VB' THEN 212			-- Macau Games
									WHEN b.Product = 'PP' THEN 248			-- Pragmatic Casino
									WHEN b.Product = 'Outright' THEN l.sporttype
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
					LeagueId = CASE
								WHEN b.EventType = 1 THEN m.leagueid
								WHEN b.EventType = 3 THEN vr.LeagueID
								WHEN b.EventType = 5 THEN m3rd.League3rdId
								WHEN b.Product = 'Outright' THEN o.leagueid
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
					ShowTime = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(m.showtime, '')
									WHEN b.Product IN ('VS') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN b.EventType = 5 THEN CONVERT(NVARCHAR(50), m3rd.StartTime)
									ELSE ''
								END,
					BetCheck = CASE
								WHEN b.Product IN ('SB', 'Parlay', 'SLT', 'VRG', 'H5LG') THEN ISNULL(b.BetCheck, '')
								WHEN b.EventType = 0 AND b.RefTable = 0 THEN ISNULL(b.betcheck, '')
								WHEN b.Product IN ('Keno') THEN ISNULL(b.ComStatus, '')
								ELSE ''
							END,
					TransDesc = CASE
									WHEN b.Product IN ('SB', 'SLT', 'Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VB', 'PP', 
										'VRG', 'TG', 'I4D', 'PGS', 'JK', 'H5LG', 'HB', 'CG', 'AP', 'APM', 'SEA') THEN ISNULL(b.transdesc, '')
									WHEN b.EventType IN (1, 3, 5) THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					BetdaqId = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.BetdaqId, -1)
									ELSE -1
								END,
					OriginalStake = 0,
					OriginalBetType = CASE
										WHEN b.Product = 'SB' AND b.stake <> 0 THEN -1
										ELSE 0
									END,
					WalletType = CASE
									WHEN b.Product = 'SB' THEN ISNULL(b.WalletType, 0)
									ELSE 0
								END,
					RefCode = CASE
									WHEN b.Product = 'SB' THEN ISNULL(b.RefCode, 0)
									ELSE 0
								END,
					SiteId = CASE
								WHEN b.Product IN ('SLT', 'H5LG', 'VRG') THEN CONVERT(VARCHAR(20), b.BetdaqId)
								ELSE ''
							END
				FROM #PagingData AS b
					LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON b.EventType = 1 AND m.matchid = b.matchid
					LEFT JOIN dbo.League AS le WITH (NOLOCK) ON b.Product IN ('SB') AND le.leagueid = m.leagueid
					LEFT JOIN dbo.Match3rd14 AS m3rd WITH (NOLOCK) ON b.EventType = 5 AND m3rd.Match3rdId = b.matchid
					LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.Product = 'Outright' AND o.orid = b.matchid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product = 'Outright' AND l.leagueid = o.leagueid
					LEFT JOIN dbo.VSRaceInfo14 AS vr WITH (NOLOCK) ON b.EventType = 3 AND vr.EventID = b.matchid
				WHERE b.WhTicket = 2
			END

			-- bettrans_bk
			IF EXISTS (SELECT TOP(1) 1 FROM #PagingData WHERE WhTicket = 3)
			BEGIN
				UPDATE b
				SET
					TransId = CASE
									WHEN b.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
									ELSE b.transid
								END,
					SportType = CASE
									WHEN b.Product IN ('SLT', 'Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VRG', 'TG', 'SBC', 'I4D', 'SXG', 'SAG', 'PGS', 'JK',
										'H5LG', 'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM', 'VS3', 'FGGL', 'MXG', 'JIG', 'YB', 'MGRNG', 'SEA') THEN b.MatchId
									WHEN b.Product = 'AllBet' THEN 211		-- AllBet
									WHEN b.Product = 'VB' THEN 212			-- Macau Games
									WHEN b.Product = 'PP' THEN 248			-- Pragmatic Casino
									WHEN b.Product = 'Outright' THEN l.sporttype
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
					LeagueId = CASE
								WHEN b.EventType = 1 THEN m.leagueid
								WHEN b.EventType = 3 THEN vr.LeagueID
								WHEN b.EventType = 5 THEN m3rd.League3rdId
								WHEN b.Product = 'Outright' THEN o.leagueid
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
					ShowTime = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(m.showtime, '')
									WHEN b.Product IN ('VS') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN b.EventType = 5 THEN CONVERT(NVARCHAR(50), m3rd.StartTime)
									ELSE ''
								END,
					BetCheck = CASE
								WHEN b.Product IN ('SB', 'Parlay', 'SLT', 'VRG', 'H5LG') THEN ISNULL(b.BetCheck, '')
								WHEN b.EventType = 0 AND b.RefTable = 0 THEN ISNULL(b.betcheck, '')
								WHEN b.Product IN ('Keno') THEN ISNULL(b.ComStatus, '')
								ELSE ''
							END,
					TransDesc = CASE
									WHEN b.Product IN ('SB', 'SLT', 'Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VB', 'PP', 
										'VRG', 'TG', 'I4D', 'PGS', 'JK', 'H5LG', 'HB', 'CG', 'AP', 'APM', 'SEA') THEN ISNULL(b.transdesc, '')
									WHEN b.EventType IN (1, 3, 5) THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					BetdaqId = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.BetdaqId, -1)
									ELSE -1
								END,
					OriginalStake = 0,
					OriginalBetType = CASE
										WHEN b.Product = 'SB' AND b.stake <> 0 THEN -1
										ELSE 0
									END,
					WalletType = CASE
									WHEN b.Product = 'SB' THEN ISNULL(b.WalletType, 0)
									ELSE 0
								END,
					RefCode = CASE
									WHEN b.Product = 'SB' THEN ISNULL(b.RefCode, 0)
									ELSE 0
								END,
					SiteId = CASE
								WHEN b.Product IN ('SLT', 'H5LG', 'VRG') THEN CONVERT(VARCHAR(20), b.BetdaqId)
								ELSE ''
							END
				FROM #PagingData AS b
					LEFT JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.EventType = 1 AND m.matchid = b.matchid
					LEFT JOIN dbo.League AS le WITH (NOLOCK) ON b.Product IN ('SB') AND le.leagueid = m.leagueid
					LEFT JOIN bodb_Archive.dbo.Match3rd_bk AS m3rd WITH (NOLOCK) ON b.EventType = 5 AND m3rd.Match3rdId = b.matchid
					LEFT JOIN bodb_Archive.dbo.outright_bk AS o WITH (NOLOCK) ON b.Product = 'Outright' AND o.orid = b.matchid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product = 'Outright' AND l.leagueid = o.leagueid
					LEFT JOIN bodb_Archive.dbo.VSRaceInfo_bk AS vr WITH (NOLOCK) ON b.EventType = 3 AND vr.EventID = b.matchid
				WHERE b.WhTicket = 3
			END

			CREATE NONCLUSTERED INDEX IX_CustId ON #PagingData (CustId)

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
			WHERE c.custid IN (SELECT DISTINCT CustId FROM #PagingData)

			-- Return data
			SELECT
				c.Username,
				c.NickName,
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
				a.SiteId,
				c.CustomerClass
			FROM
				#PagingData AS a
				INNER JOIN #Customer AS c ON c.custid = a.CustId
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
					TransId = CASE
									WHEN b.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
									ELSE b.transid
								END,
					SportType = CASE
									WHEN b.Product IN ('SLT', 'Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VRG', 'TG', 'SBC', 'I4D', 'SXG', 'SAG', 'PGS', 'JK',
										'H5LG', 'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM', 'VS3', 'FGGL', 'MXG', 'JIG', 'YB', 'MGRNG', 'SEA') THEN b.MatchId
									WHEN b.Product = 'AllBet' THEN 211		-- AllBet
									WHEN b.Product = 'VB' THEN 212			-- Macau Games
									WHEN b.Product = 'PP' THEN 248			-- Pragmatic Casino
									WHEN b.Product = 'Outright' THEN l.sporttype
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
					LeagueId = CASE
								WHEN b.EventType = 1 THEN m.leagueid
								WHEN b.EventType = 3 THEN vr.LeagueID
								WHEN b.EventType = 5 THEN m3rd.League3rdId
								WHEN b.Product = 'Outright' THEN o.leagueid
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
					ShowTime = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(m.showtime, '')
									WHEN b.Product IN ('VS') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN b.EventType = 5 THEN CONVERT(NVARCHAR(50), m3rd.StartTime)
									ELSE ''
								END,
					BetCheck = CASE
								WHEN b.Product IN ('SB', 'Parlay', 'SLT', 'VRG', 'H5LG') THEN ISNULL(b.BetCheck, '')
								WHEN b.EventType = 0 AND b.RefTable = 0 THEN ISNULL(b.betcheck, '')
								WHEN b.Product IN ('Keno') THEN ISNULL(b.ComStatus, '')
								ELSE ''
							END,
					TransDesc = CASE
									WHEN b.Product IN ('SB', 'SLT', 'Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VB', 'PP', 
										'VRG', 'TG', 'I4D', 'PGS', 'JK', 'H5LG', 'HB', 'CG', 'AP', 'APM', 'SEA') THEN ISNULL(b.transdesc, '')
									WHEN b.EventType IN (1, 3, 5) THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					BetdaqId = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.BetdaqId, -1)
									ELSE -1
								END,
					OriginalStake = 0,
					OriginalBetType = CASE
										WHEN b.Product = 'SB' AND b.stake <> 0 THEN -1
										ELSE 0
									END,
					WalletType = CASE
									WHEN b.Product = 'SB' THEN ISNULL(b.WalletType, 0)
									ELSE 0
								END,
					RefCode = CASE
									WHEN b.Product = 'SB' THEN ISNULL(b.RefCode, 0)
									ELSE 0
								END,
					SiteId = CASE
								WHEN b.Product IN ('SLT', 'H5LG', 'VRG') THEN CONVERT(VARCHAR(20), b.BetdaqId)
								ELSE ''
							END
				FROM #Data AS b
					LEFT JOIN dbo.match AS m WITH (NOLOCK) ON b.EventType = 1 AND m.matchid = b.matchid
					LEFT JOIN dbo.League AS le WITH (NOLOCK) ON b.Product IN ('SB') AND le.leagueid = m.leagueid
					LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK) ON b.EventType = 5 AND m3rd.Match3rdId = b.matchid
					LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.Product = 'Outright' AND o.orid = b.matchid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product = 'Outright' AND l.leagueid = o.leagueid
					LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON b.EventType = 3 AND vr.EventID = b.matchid
				WHERE b.WhTicket = 1
			END

			-- bettrans14
			IF EXISTS (SELECT TOP(1) 1 FROM #Data WHERE WhTicket = 2)
			BEGIN
				UPDATE b
				SET
					TransId = CASE
									WHEN b.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
									ELSE b.transid
								END,
					SportType = CASE
									WHEN b.Product IN ('SLT', 'Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VRG', 'TG', 'SBC', 'I4D', 'SXG', 'SAG', 'PGS', 'JK',
										'H5LG', 'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM', 'VS3', 'FGGL', 'MXG', 'JIG', 'YB', 'MGRNG', 'SEA') THEN b.MatchId
									WHEN b.Product = 'AllBet' THEN 211		-- AllBet
									WHEN b.Product = 'VB' THEN 212			-- Macau Games
									WHEN b.Product = 'PP' THEN 248			-- Pragmatic Casino
									WHEN b.Product = 'Outright' THEN l.sporttype
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
					LeagueId = CASE
								WHEN b.EventType = 1 THEN m.leagueid
								WHEN b.EventType = 3 THEN vr.LeagueID
								WHEN b.EventType = 5 THEN m3rd.League3rdId
								WHEN b.Product = 'Outright' THEN o.leagueid
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
					ShowTime = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(m.showtime, '')
									WHEN b.Product IN ('VS') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN b.EventType = 5 THEN CONVERT(NVARCHAR(50), m3rd.StartTime)
									ELSE ''
								END,
					BetCheck = CASE
								WHEN b.Product IN ('SB', 'Parlay', 'SLT', 'VRG', 'H5LG') THEN ISNULL(b.BetCheck, '')
								WHEN b.EventType = 0 AND b.RefTable = 0 THEN ISNULL(b.betcheck, '')
								WHEN b.Product IN ('Keno') THEN ISNULL(b.ComStatus, '')
								ELSE ''
							END,
					TransDesc = CASE
									WHEN b.Product IN ('SB', 'SLT', 'Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VB', 'PP', 
										'VRG', 'TG', 'I4D', 'PGS', 'JK', 'H5LG', 'HB', 'CG', 'AP', 'APM', 'SEA') THEN ISNULL(b.transdesc, '')
									WHEN b.EventType IN (1, 3, 5) THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					BetdaqId = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.BetdaqId, -1)
									ELSE -1
								END,
					OriginalStake = 0,
					OriginalBetType = CASE
										WHEN b.Product = 'SB' AND b.stake <> 0 THEN -1
										ELSE 0
									END,
					WalletType = CASE
									WHEN b.Product = 'SB' THEN ISNULL(b.WalletType, 0)
									ELSE 0
								END,
					RefCode = CASE
									WHEN b.Product = 'SB' THEN ISNULL(b.RefCode, 0)
									ELSE 0
								END,
					SiteId = CASE
								WHEN b.Product IN ('SLT', 'H5LG', 'VRG') THEN CONVERT(VARCHAR(20), b.BetdaqId)
								ELSE ''
							END
				FROM #Data AS b
					LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON b.EventType = 1 AND m.matchid = b.matchid
					LEFT JOIN dbo.League AS le WITH (NOLOCK) ON b.Product IN ('SB') AND le.leagueid = m.leagueid
					LEFT JOIN dbo.Match3rd14 AS m3rd WITH (NOLOCK) ON b.EventType = 5 AND m3rd.Match3rdId = b.matchid
					LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.Product = 'Outright' AND o.orid = b.matchid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product = 'Outright' AND l.leagueid = o.leagueid
					LEFT JOIN dbo.VSRaceInfo14 AS vr WITH (NOLOCK) ON b.EventType = 3 AND vr.EventID = b.matchid
				WHERE b.WhTicket = 2
			END

			-- bettrans_bk
			IF EXISTS (SELECT TOP(1) 1 FROM #Data WHERE WhTicket = 3)
			BEGIN
				UPDATE b
				SET
					TransId = CASE
									WHEN b.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
									ELSE b.transid
								END,
					SportType = CASE
									WHEN b.Product IN ('SLT', 'Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VRG', 'TG', 'SBC', 'I4D', 'SXG', 'SAG', 'PGS', 'JK',
										'H5LG', 'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM', 'VS3', 'FGGL', 'MXG', 'JIG', 'YB', 'MGRNG', 'SEA') THEN b.MatchId
									WHEN b.Product = 'AllBet' THEN 211		-- AllBet
									WHEN b.Product = 'VB' THEN 212			-- Macau Games
									WHEN b.Product = 'PP' THEN 248			-- Pragmatic Casino
									WHEN b.Product = 'Outright' THEN l.sporttype
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
					LeagueId = CASE
								WHEN b.EventType = 1 THEN m.leagueid
								WHEN b.EventType = 3 THEN vr.LeagueID
								WHEN b.EventType = 5 THEN m3rd.League3rdId
								WHEN b.Product = 'Outright' THEN o.leagueid
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
					ShowTime = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(m.showtime, '')
									WHEN b.Product IN ('VS') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN b.EventType = 5 THEN CONVERT(NVARCHAR(50), m3rd.StartTime)
									ELSE ''
								END,
					BetCheck = CASE
								WHEN b.Product IN ('SB', 'Parlay', 'SLT', 'VRG', 'H5LG') THEN ISNULL(b.BetCheck, '')
								WHEN b.EventType = 0 AND b.RefTable = 0 THEN ISNULL(b.betcheck, '')
								WHEN b.Product IN ('Keno') THEN ISNULL(b.ComStatus, '')
								ELSE ''
							END,
					TransDesc = CASE
									WHEN b.Product IN ('SB', 'SLT', 'Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VB', 'PP', 
										'VRG', 'TG', 'I4D', 'PGS', 'JK', 'H5LG', 'HB', 'CG', 'AP', 'APM', 'SEA') THEN ISNULL(b.transdesc, '')
									WHEN b.EventType IN (1, 3) THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					BetdaqId = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.BetdaqId, -1)
									ELSE -1
								END,
					OriginalStake = 0,
					OriginalBetType = CASE
										WHEN b.Product = 'SB' AND b.stake <> 0 THEN -1
										ELSE 0
									END,
					WalletType = CASE
									WHEN b.Product = 'SB' THEN ISNULL(b.WalletType, 0)
									ELSE 0
								END,
					RefCode = CASE
									WHEN b.Product = 'SB' THEN ISNULL(b.RefCode, 0)
									ELSE 0
								END,
					SiteId = CASE
								WHEN b.Product IN ('SLT', 'H5LG', 'VRG') THEN CONVERT(VARCHAR(20), b.BetdaqId)
								ELSE ''
							END
				FROM #Data AS b
					LEFT JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.EventType = 1 AND m.matchid = b.matchid
					LEFT JOIN dbo.League AS le WITH (NOLOCK) ON b.Product IN ('SB') AND le.leagueid = m.leagueid
					LEFT JOIN bodb_Archive.dbo.Match3rd_bk AS m3rd WITH (NOLOCK) ON b.EventType = 5 AND m3rd.Match3rdId = b.matchid
					LEFT JOIN bodb_Archive.dbo.outright_bk AS o WITH (NOLOCK) ON b.Product = 'Outright' AND o.orid = b.matchid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product = 'Outright' AND l.leagueid = o.leagueid
					LEFT JOIN bodb_Archive.dbo.VSRaceInfo_bk AS vr WITH (NOLOCK) ON b.EventType = 3 AND vr.EventID = b.matchid
				WHERE b.WhTicket = 3
			END

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

			SET @Sql = 
				N'SELECT
					c.Username,
					c.NickName,
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
		END
	END
	ELSE
	BEGIN
		SELECT * FROM #Data
	END

	SELECT DISTINCT * FROM @Detail

	DROP TABLE #Customer
	DROP TABLE #PagingData
	DROP TABLE #TempAg
	DROP TABLE #TempCust
	DROP TABLE #Data
	DROP TABLE #ExchangeRate
	DROP TABLE #SportBettype
	DROP TABLE #TempBetType
	DROP TABLE #TempSportType
END
GO
