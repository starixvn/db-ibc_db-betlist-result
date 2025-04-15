/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_Licensee_TotalRows]
	@AgentList			VARCHAR(MAX),
	@Username			VARCHAR(50)		= '',
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@MoveBetsDay		SMALLDATETIME,
	@ProductList		VARCHAR(300)	= 'All',
	@SportTypeList		VARCHAR(MAX)	= 'All',
	@BetTypeList		VARCHAR(MAX)	= 'All',
	@CashOutMode		TINYINT			= 0,
	@LeagueId			INT				= 0,
	@MatchId			INT				= 0,
	@LeagueGroupIds		VARCHAR(200)	= '',
	@StatusIdList		VARCHAR(50)		= '',
	@LiveIndicator		VARCHAR(10)		= '0,1,2',
	@PlatformType		VARCHAR(100)	= 'All',
	@CustomerClass		VARCHAR(MAX)	= 'All',
	@FullCustomerClass	VARCHAR(MAX)	= 'All',
	@OddsGroup			VARCHAR(100)	= 'All',
	@Ip					VARCHAR(45)		= '',
	@MaxTotalRows		INT				= 1000000,
	@TotalRows			INT				= 0 OUTPUT
AS

/*
	Created: Kos@20180613
	Task: Betting Ticket Center - Multiple Customer Bet List - Get total rows only
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
					<Sport SportType="999" LeagueGroupIds="0"/>
				</ROOT>
				+ Parlay: <Sport SportType="999" LeagueGroupIds="0"/>
				+ Sports Lottery: <Sport SportType="169" LeagueGroupIds="0"/>
				+ Saba Soccer: <Sport SportType="1" LeagueGroupIds="42,74"/>
				+ Saba Soccer PinGoal: <Sport SportType="1" LeagueGroupIds="113"/>
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
		- 20190214@Kos: Betting Ticket Center phase 3b [Redmine: #108221]
					- Change input param from @ProductList to @Product
					- Remove input param @ShowBA
		- 20190313@Kos: Change param @LiveIndicator from TINYINT to VARCHAR(10) [Redmine: #108717]
					- Add new param @Username VARCHAR(50)
		- 20190422@Kos: Enhance performance for searching too many members [Redmine: #112313]
		- 20190829@Kos: Support PH AIO 4b [Redmine: #118300]
		- 20200623@Kos: Integrate archive process for table VSRaceInfo [Redmine: #136285]
		- 20201210@Kos: Exclude bettype 999 Odds Spread Adjustment [Redmine: #142532]
		- 20211104@Kos: Merge Sports Lottery into Sportsbook [RedmineID: #163191]
		- 20211220@Kos: Support new Cash Out [Redmine: #165160]
		- 20220128@Kos: Support search by IP [RedmineID: #166079]
		- 20220428@Kos: Support Bitcoin [Redmine: #160160]
		- 20230316@Kos: Support Saba Sports [Redmine: 183841]
		- 20230511@Kos: Support Saba Sports [Redmine: 183841]
					- Add new input params @LeagueGroupIds, @PlatformType, @CustomerClass, @OddsGroup
		- 20240129@Kos: Merge VS1, VS2, VS3 into VS [Redmine: 199523]
		- 20240207@Kos: Hotfix - No data when filtering player has Risk Level Uncategorized [RedmineID: #200913]
					- Add new input param @FullCustomerClass VARCHAR(MAX)
		- 20241001@Kos: Enhance performance [Redmine: 211655]
		- 20241002@Kos: Support BetRadar Horse Racing [Redmine: #210808]
		- 20241028@Kos: Support Virtual Sports 6 [Redmine: 212446]
		- 20241210@Kos: Add unknown betfroms into group Others [#Redmine: 214849]
		- 20241226@Kos: Allow to search multiple days [RedmineID: #212395]
					- Remove input params @Product, @SportType, @BetType
					- Add new input params @ProductList VARCHAR(300), @SportTypeList VARCHAR(MAX), @BetTypeList VARCHAR(MAX), @CashOutMode TINYINT, @MaxTotalRows INT
		- 20250212@Kos: Remove BA [RedmineID: #216882]
		- 20250415@Kos: Hotfix - VS racing range bettrans14 [Redmine: 224163]
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

	DECLARE @TotalRowsBettrans	INT = 0,
		@TotalRowsBettrans14	INT = 0

	CREATE TABLE #TempCust (CustId INT PRIMARY KEY, CustomerClass SMALLINT)

	CREATE TABLE #SportBettype (ProductId TINYINT, ProductPrefix VARCHAR(500), BetType SMALLINT, EventType TINYINT, RefTable TINYINT)

	CREATE CLUSTERED INDEX IX_BetType ON #SportBettype (BetType)

	CREATE TABLE #TempBetType (ProductPrefix VARCHAR(10), BetTypeList VARCHAR(MAX))

	CREATE TABLE #TempSportType (SportType SMALLINT, LeagueGroupIdList VARCHAR(200))

	CREATE CLUSTERED INDEX IX_SportType ON #TempSportType (SportType)

	CREATE TABLE #AllPlatformList (BetFrom NVARCHAR(4))
	CREATE TABLE #PlatformList (BetFrom NVARCHAR(4))

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

		-- Get bet type list
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
				LEFT JOIN dbo.f_GroupBettype() AS gbt ON gbt.bettype = sbt.BetType
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
												OR (s.ProductID = 1 AND st.SportType = 999))
		END TRY
		BEGIN CATCH
			SET @HasError = 1
		END CATCH

		IF ',' + @StatusIdList + ',' LIKE '%,99,%'		-- Abnormal Bet
		BEGIN
			SET @StatusIdList = @StatusIdList + ',102'
		END

		IF ',' + @StatusIdList + ',' LIKE '%,2,%'		-- Delay Payout
		BEGIN
			SET @StatusIdList = @StatusIdList + ',111,112,113'
		END

		IF @Username IS NOT NULL AND @Username <> ''
		BEGIN
			DECLARE @Site VARCHAR(10)

			SELECT @Site = site
			FROM dbo.Customer WITH (NOLOCK)
			WHERE custid IN (SELECT TOP(1) CustId FROM #TempAg)

			INSERT INTO #TempCust (CustId, CustomerClass)
			SELECT
				c.custid,
				ci.CustomerClass
			FROM dbo.Customer AS c WITH (NOLOCK)
				INNER JOIN #TempAg AS a ON c.recommend = a.CustId
				LEFT JOIN dbo.custInfo AS ci WITH (NOLOCK) ON ci.custid = c.custid
			WHERE c.roleid = 1
				AND (c.username LIKE '%' + @Username + '%'
					OR c.username2 LIKE @Site + '$%' + @Username + '%')
				AND (@OddsGroup = 'All'
					OR ',' + @OddsGroup + ',' LIKE + '%,' + c.ugroup + ',%')

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

		IF @PlatformType <> 'All'
		BEGIN
			INSERT INTO #AllPlatformList (BetFrom)
			SELECT DISTINCT betfrom
			FROM dbo.Lrf_f_BetFromType_Sel('All')

			INSERT INTO #PlatformList (BetFrom)
			SELECT DISTINCT betfrom
			FROM dbo.Lrf_f_BetFromType_Sel(@PlatformType)
		END

		DECLARE @NumOfMem	INT = 0

		SELECT @NumOfMem = COUNT(1) FROM #TempCust

		DECLARE @MatchSportType	SMALLINT,
			@ParentId			INT

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

		DECLARE @Match TABLE(MatchId INT)

		IF @MatchSportType IN (8, 50) AND @ParentId IS NULL		-- Baseball, Cricket, parent match
		BEGIN
			INSERT INTO @Match
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
		END

		DECLARE @TempToDate	SMALLDATETIME,
			@TempFromDate	SMALLDATETIME

		IF @Username IS NULL OR @Username = '' OR @NumOfMem > 5000		-- Licensee level (not input username or number of searched member > 5000)
		BEGIN
			-- Bettrans range
			IF @ToDate > @MoveBetsDay
			BEGIN
				SET @TempFromDate = CASE
										WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay)
										ELSE @FromDate
									END

				IF @OddsGroup = 'All' AND @CustomerClass = 'All'	-- don't need table Customer, custinfo
				BEGIN
					IF @Ip IS NULL OR @Ip = ''		-- don't need key lookup
					BEGIN
						SELECT @TotalRowsBettrans = COUNT(1)
						FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_Recommend)
							INNER JOIN #TempAg AS a ON b.recommend = a.CustId
							INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
							LEFT JOIN #PlatformList AS pl ON pl.BetFrom = b.betfrom
							LEFT JOIN #AllPlatformList AS apl ON apl.BetFrom = b.betfrom
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
																WHEN b.bettype IN (9, 29) THEN 999
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
							AND 1 = CASE
										WHEN @PlatformType = 'All' THEN 1
										WHEN pl.BetFrom IS NOT NULL THEN 1
										WHEN apl.BetFrom IS NULL AND ',' + @PlatformType + ',' LIKE '%,88,%' THEN 1
										WHEN apl.BetFrom IS NULL AND ',' + @PlatformType + ',' LIKE '%,99,%' THEN 1
										ELSE 0
									END
					END
					ELSE
					BEGIN
						SELECT @TotalRowsBettrans = COUNT(1)
						FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_Recommend)
							INNER JOIN #TempAg AS a ON b.recommend = a.CustId
							INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
							LEFT JOIN #PlatformList AS pl ON pl.BetFrom = b.betfrom
							LEFT JOIN #AllPlatformList AS apl ON apl.BetFrom = b.betfrom
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
																WHEN b.bettype IN (9, 29) THEN 999
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
							AND b.ip = @Ip
							AND 1 = CASE
										WHEN @PlatformType = 'All' THEN 1
										WHEN pl.BetFrom IS NOT NULL THEN 1
										WHEN apl.BetFrom IS NULL AND ',' + @PlatformType + ',' LIKE '%,88,%' THEN 1
										WHEN apl.BetFrom IS NULL AND ',' + @PlatformType + ',' LIKE '%,99,%' THEN 1
										ELSE 0
									END
						END
				END
				ELSE
				BEGIN
					SELECT @TotalRowsBettrans = COUNT(1)
					FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_Recommend)
						INNER JOIN #TempAg AS a ON b.recommend = a.CustId
						INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
						INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = b.custid
						INNER JOIN dbo.custInfo AS ci WITH (NOLOCK) ON ci.custid = b.custid
						LEFT JOIN #PlatformList AS pl ON pl.BetFrom = b.betfrom
						LEFT JOIN #AllPlatformList AS apl ON apl.BetFrom = b.betfrom
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
															WHEN b.bettype IN (9, 29) THEN 999
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
						AND (@Ip IS NULL
							OR @Ip IN (b.ip, ''))
						AND 1 = CASE
									WHEN @PlatformType = 'All' THEN 1
									WHEN pl.BetFrom IS NOT NULL THEN 1
									WHEN apl.BetFrom IS NULL AND ',' + @PlatformType + ',' LIKE '%,88,%' THEN 1
									WHEN apl.BetFrom IS NULL AND ',' + @PlatformType + ',' LIKE '%,99,%' THEN 1
									ELSE 0
								END
						AND (@OddsGroup = 'All'
							OR ',' + @OddsGroup + ',' LIKE + '%,' + c.ugroup + ',%')
						AND 1 = CASE
									WHEN @CustomerClass = 'All' THEN 1
									WHEN ',' + @CustomerClass + ',' LIKE '%,0,%' AND ci.CustomerClass IS NULL THEN 1
									WHEN ',' + @CustomerClass + ',' LIKE '%,0,%'
										AND ',' + @FullCustomerClass + ',' NOT LIKE '%,' + CONVERT(VARCHAR(6), ci.CustomerClass) + ',%' THEN 1
									WHEN ',' + @CustomerClass + ',' LIKE '%,' + CONVERT(VARCHAR(6), ci.CustomerClass) + ',%' THEN 1
									ELSE 0
								END
				END
			END

			-- Bettrans14 range
			IF @TotalRowsBettrans <= @MaxTotalRows
			BEGIN
				IF @FromDate <= @MoveBetsDay
				BEGIN
					SET @TempToDate = CASE
										WHEN @ToDate > @MoveBetsDay THEN @MoveBetsDay
										ELSE @ToDate
									END

					IF @OddsGroup = 'All' AND @CustomerClass = 'All'	-- don't need table Customer, custinfo
					BEGIN
						SELECT @TotalRowsBettrans14 = COUNT(1)
						FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_Recommend)
							INNER JOIN #TempAg AS a ON b.recommend = a.CustId
							INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
							LEFT JOIN #PlatformList AS pl ON pl.BetFrom = b.betfrom
							LEFT JOIN #AllPlatformList AS apl ON apl.BetFrom = b.betfrom
							LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1
							LEFT JOIN dbo.Match3rd14 AS m3rd WITH (NOLOCK) ON m3rd.Match3rdId = b.MatchId AND s.EventType = 5
							LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.matchid = o.orid AND b.bettype = 10
							LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
							LEFT JOIN dbo.VSRaceInfo14 AS vr WITH (NOLOCK) ON vr.EventID = b.matchid AND s.EventType = 3
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
																WHEN b.bettype IN (9, 29) THEN 999
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
							AND (@Ip IS NULL
								OR @Ip IN (b.ip, ''))
							AND 1 = CASE
										WHEN @PlatformType = 'All' THEN 1
										WHEN pl.BetFrom IS NOT NULL THEN 1
										WHEN apl.BetFrom IS NULL AND ',' + @PlatformType + ',' LIKE '%,88,%' THEN 1
										WHEN apl.BetFrom IS NULL AND ',' + @PlatformType + ',' LIKE '%,99,%' THEN 1
										ELSE 0
									END
					END
					ELSE
					BEGIN
						SELECT @TotalRowsBettrans14 = COUNT(1)
						FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_Recommend)
							INNER JOIN #TempAg AS a ON b.recommend = a.CustId
							INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
							INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = b.custid
							INNER JOIN dbo.custInfo AS ci WITH (NOLOCK) ON ci.custid = b.custid
							LEFT JOIN #PlatformList AS pl ON pl.BetFrom = b.betfrom
							LEFT JOIN #AllPlatformList AS apl ON apl.BetFrom = b.betfrom
							LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1
							LEFT JOIN dbo.Match3rd14 AS m3rd WITH (NOLOCK) ON m3rd.Match3rdId = b.MatchId AND s.EventType = 5
							LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.matchid = o.orid AND b.bettype = 10
							LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
							LEFT JOIN dbo.VSRaceInfo14 AS vr WITH (NOLOCK) ON vr.EventID = b.matchid AND s.EventType = 3
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
																WHEN b.bettype IN (9, 29) THEN 999
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
							AND (@Ip IS NULL
								OR @Ip IN (b.ip, ''))
							AND 1 = CASE
										WHEN @PlatformType = 'All' THEN 1
										WHEN pl.BetFrom IS NOT NULL THEN 1
										WHEN apl.BetFrom IS NULL AND ',' + @PlatformType + ',' LIKE '%,88,%' THEN 1
										WHEN apl.BetFrom IS NULL AND ',' + @PlatformType + ',' LIKE '%,99,%' THEN 1
										ELSE 0
									END
							AND (@OddsGroup = 'All'
								OR ',' + @OddsGroup + ',' LIKE + '%,' + c.ugroup + ',%')
							AND 1 = CASE
										WHEN @CustomerClass = 'All' THEN 1
										WHEN ',' + @CustomerClass + ',' LIKE '%,0,%' AND ci.CustomerClass IS NULL THEN 1
										WHEN ',' + @CustomerClass + ',' LIKE '%,0,%'
											AND ',' + @FullCustomerClass + ',' NOT LIKE '%,' + CONVERT(VARCHAR(6), ci.CustomerClass) + ',%' THEN 1
										WHEN ',' + @CustomerClass + ',' LIKE '%,' + CONVERT(VARCHAR(6), ci.CustomerClass) + ',%' THEN 1
										ELSE 0
									END
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

				SELECT @TotalRowsBettrans = COUNT(1)
				FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_CustId)
					INNER JOIN #TempCust AS c ON b.custid = c.CustId
					INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
					LEFT JOIN #PlatformList AS pl ON pl.BetFrom = b.betfrom
					LEFT JOIN #AllPlatformList AS apl ON apl.BetFrom = b.betfrom
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
														WHEN b.bettype IN (9, 29) THEN 999
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
					AND (@Ip IS NULL
						OR @Ip IN (b.ip, ''))
					AND 1 = CASE
								WHEN @PlatformType = 'All' THEN 1
								WHEN pl.BetFrom IS NOT NULL THEN 1
								WHEN apl.BetFrom IS NULL AND ',' + @PlatformType + ',' LIKE '%,88,%' THEN 1
								WHEN apl.BetFrom IS NULL AND ',' + @PlatformType + ',' LIKE '%,99,%' THEN 1
								ELSE 0
							END
			END

			-- Bettrans14 range
			IF @TotalRowsBettrans <= @MaxTotalRows
			BEGIN
				IF @FromDate <= @MoveBetsDay
				BEGIN
					SET @TempToDate = CASE
										WHEN @ToDate > @MoveBetsDay THEN @MoveBetsDay
										ELSE @ToDate
									END

					SELECT @TotalRowsBettrans14 = COUNT(1)
					FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_CustId)
						INNER JOIN #TempCust AS c ON b.custid = c.CustId
						INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
						LEFT JOIN #PlatformList AS pl ON pl.BetFrom = b.betfrom
						LEFT JOIN #AllPlatformList AS apl ON apl.BetFrom = b.betfrom
						LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1
						LEFT JOIN dbo.Match3rd14 AS m3rd WITH (NOLOCK) ON m3rd.Match3rdId = b.MatchId AND s.EventType = 5
						LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.matchid = o.orid AND b.bettype = 10
						LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
						LEFT JOIN dbo.VSRaceInfo14 AS vr WITH (NOLOCK) ON vr.EventID = b.matchid AND s.EventType = 3
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
															WHEN b.bettype IN (9, 29) THEN 999
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
						AND (@Ip IS NULL
							OR @Ip IN (b.ip, ''))
						AND 1 = CASE
									WHEN @PlatformType = 'All' THEN 1
									WHEN pl.BetFrom IS NOT NULL THEN 1
									WHEN apl.BetFrom IS NULL AND ',' + @PlatformType + ',' LIKE '%,88,%' THEN 1
									WHEN apl.BetFrom IS NULL AND ',' + @PlatformType + ',' LIKE '%,99,%' THEN 1
									ELSE 0
								END
				END
			END
		END
	END

	SELECT @TotalRows = @TotalRowsBettrans + @TotalRowsBettrans14

	DROP TABLE #TempCust
	DROP TABLE #TempAg
	DROP TABLE #SportBettype
	DROP TABLE #TempBetType
	DROP TABLE #TempSportType
	DROP TABLE #AllPlatformList
	DROP TABLE #PlatformList
END
GO
