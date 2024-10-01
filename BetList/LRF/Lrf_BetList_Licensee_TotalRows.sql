/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_Licensee_TotalRows]
	@AgentList			VARCHAR(MAX),
	@Username			VARCHAR(50)		= '',
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@MoveBetsDay		SMALLDATETIME,
	@Product			VARCHAR(100)	= '',
	@SportType			TINYINT			= 0,
	@BetType			SMALLINT		= 0,
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

	IF @HasError = 0
	BEGIN
		DECLARE @ProductList	VARCHAR(10),
			@ShowSB				BIT				= 0

		IF @Product IN ('BA', 'CO')
		BEGIN
			SET @ProductList = 'SB'
		END
		ELSE
		BEGIN
			SET @ProductList = @Product
		END

		IF ',' + @Product + ',' LIKE '%,SB,%'
			SET @ShowSB = 1

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
		CREATE TABLE #SportBettype (ProductId TINYINT, BetType SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

		CREATE CLUSTERED INDEX IX_BetType ON #SportBettype (BetType)

		DECLARE @IsTest BIT = 0

		SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

		IF @ProductList <> ''
		BEGIN
			INSERT INTO #SportBettype
			SELECT ProductID, BetType, EventType, SubProduct
			FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @ProductList, @IsTest)
			WHERE (@BetType = 0
				OR BetType IN (	SELECT @BetType
								UNION SELECT Bettype FROM dbo.Lrf_f_GroupBettype() WHERE GroupTypeId = @BetType))
				AND BetType NOT IN (901, 902, 903, 904, 913, 914, 999)
				AND BetType NOT BETWEEN 801 AND 899
		END

		DECLARE @TempToDate	SMALLDATETIME,
			@TempFromDate	SMALLDATETIME

		IF @Username IS NOT NULL AND @Username <> ''
		BEGIN
			INSERT INTO #TempCust (CustId, CustomerClass)
			SELECT
				c.custid,
				ci.CustomerClass
			FROM dbo.Customer AS c WITH (NOLOCK)
				INNER JOIN #TempAg AS a ON c.recommend = a.CustId
				LEFT JOIN dbo.custInfo AS ci WITH (NOLOCK) ON ci.custid = c.custid
			WHERE c.roleid = 1
				AND (c.username LIKE + '%' + @Username + '%'
					OR c.username2 LIKE + '%$%' + @Username + '%')
				AND ',' + @OddsGroup + ',' LIKE + '%,' + c.ugroup + ',%'

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

		IF @Username IS NULL OR @Username = '' OR @NumOfMem > 5000		-- Licensee level (not input username or number of searched member > 5000)
		BEGIN
			-- Bettrans range
			IF @ToDate > @MoveBetsDay
			BEGIN
				IF @FromDate <= @MoveBetsDay
					SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
				ELSE
					SET @TempFromDate = @FromDate

				IF @SportType = 0 AND @LeagueId = 0
				BEGIN
					SELECT @TotalRowsBettrans = COUNT(1)
					FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_Recommend)
						INNER JOIN #TempAg AS a ON b.recommend = a.CustId
						INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
						INNER JOIN dbo.custInfo AS ci WITH (NOLOCK) ON ci.custid = b.custid
						INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = b.custid
					WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
						AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
						AND ((b.bettype IN (9, 29, 2799) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.livehomescore) + ',%')
							OR (b.bettype NOT IN (9, 29, 2799) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'))
						AND (@MatchId = 0 OR b.matchid = @MatchId)
						AND (@Ip = '' OR b.ip = @Ip)
						AND 1 = CASE
									WHEN s.ProductID = 1 THEN
										CASE
											WHEN @Product = 'CO' AND b.betdaqid = -2 THEN 1
											WHEN @ShowSB = 1 AND b.tpositiontaking <> 0 THEN 1
											WHEN @Product = 'BA' AND b.tpositiontaking = 0 THEN 1
											ELSE 0
										END
									ELSE 1
								END
						AND (@PlatformType = 'All'
							OR b.betfrom IN (SELECT betfrom FROM dbo.Lrf_f_BetFromType_Sel(@PlatformType)))
						AND ',' + @OddsGroup + ',' LIKE + '%,' + c.ugroup + ',%'
						AND 1 = CASE
									WHEN ',' + @CustomerClass + ',' LIKE '%,0,%' AND CustomerClass IS NULL THEN 1
									WHEN ',' + @CustomerClass + ',' LIKE '%,0,%'
										AND ',' + @FullCustomerClass + ',' NOT LIKE '%,' + CONVERT(VARCHAR(6), CustomerClass) + ',%' THEN 1
									WHEN ',' + @CustomerClass + ',' LIKE '%,' + CONVERT(VARCHAR(6), CustomerClass) + ',%' THEN 1
									ELSE 0
								END
				END
				ELSE
				BEGIN
					SELECT @TotalRowsBettrans = COUNT(1)
					FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_Recommend)
						INNER JOIN #TempAg AS a ON b.recommend = a.CustId
						INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
						INNER JOIN dbo.custInfo AS ci WITH (NOLOCK) ON ci.custid = b.custid
						INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = b.custid
						LEFT JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1 AND s.ProductID IN (1, 3, 5, 25, 27)
						LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK) ON m3rd.Match3rdId = b.MatchId AND s.ProductID IN (69)
						LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.matchid = o.orid AND s.EventType = 2 AND s.ProductID = 1
						LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid AND s.EventType = 2 AND s.ProductID = 1
						LEFT JOIN dbo.VSOutright AS vo WITH (NOLOCK) ON b.oddsid = vo.Orid AND s.EventType = 3 AND s.ProductID = 5
						LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON vr.EventID = vo.EventID AND s.EventType = 3 AND s.ProductID = 5
					WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
						AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
						AND ((b.bettype IN (9, 29, 2799) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.livehomescore) + ',%')
							OR (b.bettype NOT IN (9, 29, 2799) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'))
						AND (@SportType = 0 OR m.sporttype IS NULL OR m.sporttype = @SportType)
						AND (@LeagueId = 0 OR m.leagueid IS NULL OR m.leagueid = @LeagueId)
						AND (@LeagueId = 0 OR o.leagueid IS NULL OR o.leagueid = @LeagueId)
						AND (@SportType = 0 OR l.sporttype IS NULL OR l.sporttype = @SportType)
						AND (@SportType = 0 OR vr.sporttype IS NULL OR vr.sporttype = @SportType)
						AND (@SportType = 0 OR s.ProductId NOT IN (63) OR b.matchid = @SportType)
						AND (@SportType = 0 OR m3rd.sporttype IS NULL OR m3rd.SportType = @SportType)
						AND (@MatchId = 0 OR b.matchid = @MatchId)
						AND (@Ip = '' OR b.ip = @Ip)
						AND 1 = CASE
									WHEN s.ProductID = 1 THEN
										CASE
											WHEN @Product = 'CO' AND b.betdaqid = -2 THEN 1
											WHEN @ShowSB = 1 AND b.tpositiontaking <> 0 THEN 1
											WHEN @Product = 'BA' AND b.tpositiontaking = 0 THEN 1
											ELSE 0
										END
									ELSE 1
								END
						AND (@PlatformType = 'All'
							OR b.betfrom IN (SELECT betfrom FROM dbo.Lrf_f_BetFromType_Sel(@PlatformType)))
						AND ',' + @OddsGroup + ',' LIKE + '%,' + c.ugroup + ',%'
						AND 1 = CASE
									WHEN ',' + @CustomerClass + ',' LIKE '%,0,%' AND CustomerClass IS NULL THEN 1
									WHEN ',' + @CustomerClass + ',' LIKE '%,0,%'
										AND ',' + @FullCustomerClass + ',' NOT LIKE '%,' + CONVERT(VARCHAR(6), CustomerClass) + ',%' THEN 1
									WHEN ',' + @CustomerClass + ',' LIKE '%,' + CONVERT(VARCHAR(6), CustomerClass) + ',%' THEN 1
									ELSE 0
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

				IF @SportType = 0 AND @LeagueId = 0
				BEGIN
					SELECT @TotalRowsBettrans14 = COUNT(1)
					FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_Recommend)
						INNER JOIN #TempAg AS a ON b.recommend = a.CustId
						INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
						INNER JOIN dbo.custInfo AS ci WITH (NOLOCK) ON ci.custid = b.custid
						INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = b.custid
					WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
						AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
						AND ((b.bettype IN (9, 29, 2799) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.livehomescore) + ',%')
							OR (b.bettype NOT IN (9, 29, 2799) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'))
						AND (@MatchId = 0 OR b.matchid = @MatchId)
						AND (@Ip = '' OR b.ip = @Ip)
						AND 1 = CASE
									WHEN s.ProductID = 1 THEN
										CASE
											WHEN @Product = 'CO' AND b.betdaqid = -2 THEN 1
											WHEN @ShowSB = 1 AND b.tpositiontaking <> 0 THEN 1
											WHEN @Product = 'BA' AND b.tpositiontaking = 0 THEN 1
											ELSE 0
										END
									ELSE 1
								END
						AND (@PlatformType = 'All'
							OR b.betfrom IN (SELECT betfrom FROM dbo.Lrf_f_BetFromType_Sel(@PlatformType)))
						AND ',' + @OddsGroup + ',' LIKE + '%,' + c.ugroup + ',%'
						AND 1 = CASE
									WHEN ',' + @CustomerClass + ',' LIKE '%,0,%' AND CustomerClass IS NULL THEN 1
									WHEN ',' + @CustomerClass + ',' LIKE '%,0,%'
										AND ',' + @FullCustomerClass + ',' NOT LIKE '%,' + CONVERT(VARCHAR(6), CustomerClass) + ',%' THEN 1
									WHEN ',' + @CustomerClass + ',' LIKE '%,' + CONVERT(VARCHAR(6), CustomerClass) + ',%' THEN 1
									ELSE 0
								END
				END
				ELSE
				BEGIN
					SELECT @TotalRowsBettrans14 = COUNT(1)
					FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_Recommend)
						INNER JOIN #TempAg AS a ON b.recommend = a.CustId
						INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
						INNER JOIN dbo.custInfo AS ci WITH (NOLOCK) ON ci.custid = b.custid
						INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = b.custid
						LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1 AND s.ProductID IN (1, 3, 5, 25, 27)
						LEFT JOIN dbo.Match3rd14 AS m3rd WITH (NOLOCK) ON m3rd.Match3rdId = b.MatchId AND s.ProductID IN (69)
						LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.matchid = o.orid AND s.EventType = 2 AND s.ProductID = 1
						LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid AND s.EventType = 2 AND s.ProductID = 1
						LEFT JOIN dbo.VSOutright14 AS vo WITH (NOLOCK) ON b.oddsid = vo.Orid AND s.EventType = 3 AND s.ProductID = 5
						LEFT JOIN dbo.VSRaceInfo14 AS vr WITH (NOLOCK) ON vr.EventID = vo.EventID AND s.EventType = 3 AND s.ProductID = 5
					WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
						AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
						AND ((b.bettype IN (9, 29, 2799) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.livehomescore) + ',%')
							OR (b.bettype NOT IN (9, 29, 2799) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'))
						AND (@SportType = 0 OR m.sporttype IS NULL OR m.sporttype = @SportType)
						AND (@LeagueId = 0 OR m.leagueid IS NULL OR m.leagueid = @LeagueId)
						AND (@LeagueId = 0 OR o.leagueid IS NULL OR o.leagueid = @LeagueId)
						AND (@SportType = 0 OR l.sporttype IS NULL OR l.sporttype = @SportType)
						AND (@SportType = 0 OR vr.sporttype IS NULL OR vr.sporttype = @SportType)
						AND (@SportType = 0 OR s.ProductId NOT IN (63) OR b.matchid = @SportType)
						AND (@SportType = 0 OR m3rd.sporttype IS NULL OR m3rd.SportType = @SportType)
						AND (@MatchId = 0 OR b.matchid = @MatchId)
						AND (@Ip = '' OR b.ip = @Ip)
						AND 1 = CASE
									WHEN s.ProductID = 1 THEN
										CASE
											WHEN @Product = 'CO' AND b.betdaqid = -2 THEN 1
											WHEN @ShowSB = 1 AND b.tpositiontaking <> 0 THEN 1
											WHEN @Product = 'BA' AND b.tpositiontaking = 0 THEN 1
											ELSE 0
										END
									ELSE 1
								END
						AND (@PlatformType = 'All'
							OR b.betfrom IN (SELECT betfrom FROM dbo.Lrf_f_BetFromType_Sel(@PlatformType)))
						AND ',' + @OddsGroup + ',' LIKE + '%,' + c.ugroup + ',%'
						AND 1 = CASE
									WHEN ',' + @CustomerClass + ',' LIKE '%,0,%' AND CustomerClass IS NULL THEN 1
									WHEN ',' + @CustomerClass + ',' LIKE '%,0,%'
										AND ',' + @FullCustomerClass + ',' NOT LIKE '%,' + CONVERT(VARCHAR(6), CustomerClass) + ',%' THEN 1
									WHEN ',' + @CustomerClass + ',' LIKE '%,' + CONVERT(VARCHAR(6), CustomerClass) + ',%' THEN 1
									ELSE 0
								END
				END
			END
		END
		ELSE
		BEGIN
			-- Bettrans range
			IF @ToDate > @MoveBetsDay
			BEGIN
				IF @FromDate <= @MoveBetsDay
					SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
				ELSE
					SET @TempFromDate = @FromDate

				SELECT @TotalRowsBettrans = COUNT(1)
				FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_CustId)
					INNER JOIN #TempCust AS c ON b.custid = c.CustId
					INNER JOIN #SportBettype AS s ON b.bettype = s.bettype
				WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
					AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
					AND ((b.bettype IN (9, 29, 2799) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.livehomescore) + ',%')
						OR (b.bettype NOT IN (9, 29, 2799) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'))
					AND (@MatchId = 0 OR b.matchid = @MatchId)
					AND (@Ip = '' OR b.ip = @Ip)
					AND 1 = CASE
								WHEN s.ProductID = 1 THEN
									CASE
										WHEN @Product = 'CO' AND b.betdaqid = -2 THEN 1
										WHEN @ShowSB = 1 AND b.tpositiontaking <> 0 THEN 1
										WHEN @Product = 'BA' AND b.tpositiontaking = 0 THEN 1
										ELSE 0
									END
								ELSE 1
							END
					AND (@PlatformType = 'All'
						OR b.betfrom IN (SELECT betfrom FROM dbo.Lrf_f_BetFromType_Sel(@PlatformType)))
			END

			-- Bettrans14 range
			IF @FromDate <= @MoveBetsDay
			BEGIN
				IF @ToDate > @MoveBetsDay
					SET @TempToDate = @MoveBetsDay
				ELSE
					SET @TempToDate = @ToDate

				SELECT @TotalRowsBettrans14 = COUNT(1)
				FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_CustId)
					INNER JOIN #TempCust AS c ON b.custid = c.CustId
					INNER JOIN #SportBettype AS s ON b.bettype = s.BetType
				WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
					AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
					AND ((b.bettype IN (9, 29, 2799) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.livehomescore) + ',%')
						OR (b.bettype NOT IN (9, 29, 2799) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.liveindicator) + ',%'))
					AND (@MatchId = 0 OR b.matchid = @MatchId)
					AND (@Ip = '' OR b.ip = @Ip)
					AND 1 = CASE
								WHEN s.ProductID = 1 THEN
									CASE
										WHEN @Product = 'CO' AND b.betdaqid = -2 THEN 1
										WHEN @ShowSB = 1 AND b.tpositiontaking <> 0 THEN 1
										WHEN @Product = 'BA' AND b.tpositiontaking = 0 THEN 1
										ELSE 0
									END
								ELSE 1
							END
					AND (@PlatformType = 'All'
						OR b.betfrom IN (SELECT betfrom FROM dbo.Lrf_f_BetFromType_Sel(@PlatformType)))
			END
		END
	END

	SELECT @TotalRows = @TotalRowsBettrans + @TotalRowsBettrans14

	DROP TABLE #TempCust
END
GO
