/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_Licensee_TotalRows]
	@AgentList		VARCHAR(MAX),
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@SportType		TINYINT			= 0,
	@BetType		SMALLINT		= 0,
	@LeagueId		INT				= 0,
	@MatchId		INT				= 0,
	@StatusIdList	VARCHAR(50)		= '',
	@LiveIndicator	TINYINT			= 3,
	@Product		VARCHAR(10)	= '',
	@TotalRows		INT				= 0 OUTPUT
AS

/*
	Created: Kos@20180613
	Task: Betting Ticket Center - Multiple Customer Bet List - Get total rows only
	DB: DBEXT.bodb02
	Parameter's Explanation:
		- @Status: '111,112,113,101,102,103'
		- @Platform:
			- 0 - All: All
			- 1 - Asia: d (mobile), g (MG Download only)
			- 2 - China: a (dep-Singbet), z (dep2-SingBet)
			- 3 - Euro: e (Europe), u (dep-Euro), y (dep2-Euro)
			- 4 - WAP: m (dep-wap)
			- 5 - Smart Site: s (smartphone), l (dep-smart)
			- 6 - Tablet: r (dep2-tablet)
			 -7 - New Asia: x (dep2-Asia)
		- @LiveIndicator:
			- 0 : Non-live
			- 1 : Live
			- 2 : Mix Non Live & Live
			- 3 : All

	Revisions:
		- 20180711@Kos: Created [#Redmine: 80941]
		- 20190214@Kos: Betting Ticket Center phase 3b [Redmine: #108221]
					- Change input param from @ProductList to @Product
					- Remove input param @ShowBA
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

	DECLARE @TotalRowsBettrans	INT = 0,
		@TotalRowsBettrans14	INT = 0

	IF @HasError = 0
	BEGIN
		DECLARE @ProductList		VARCHAR(10)

		IF @Product = 'BA'
		BEGIN
			SET @ProductList = 'SB'
		END
		ELSE
		BEGIN
			SET @ProductList = @Product
		END

		-- Get SportBettypeMatrix
		DECLARE @SportBettype TABLE (ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

		DECLARE @IsTest BIT = 0

		SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

		IF @ProductList <> ''
		BEGIN
			INSERT INTO @SportBettype
			SELECT ProductID, BetType, EventType, SubProduct
			FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @ProductList, @IsTest)
			WHERE (@BetType = 0
				OR BetType IN (	SELECT @BetType
								UNION SELECT GroupTypeId FROM dbo.f_GroupBettype() WHERE Bettype = @BetType))
				AND BetType NOT IN (901, 902, 903, 904, 913, 914)
				AND BetType NOT BETWEEN 801 AND 899
		END

		DECLARE @TempToDate	SMALLDATETIME,
			@TempFromDate	SMALLDATETIME

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
					INNER JOIN @TempAg AS a ON b.recommend = a.CustId
					INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
				WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
					AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
					AND (@LiveIndicator = 3
						OR (b.bettype IN (9, 29, 2799) AND b.livehomescore = @LiveIndicator)
						OR (b.bettype NOT IN (9, 29, 2799) AND b.liveindicator = @LiveIndicator))
					AND (@MatchId = 0 OR b.matchid = @MatchId)
					AND 1 = CASE
								WHEN s.ProductID = 1 THEN
									CASE
										WHEN @Product = 'SB' AND b.tpositiontaking <> 0 THEN 1
										WHEN @Product = 'BA' AND b.tpositiontaking = 0 THEN 1
										ELSE 0
									END
								ELSE 1
							END
			END
			ELSE
			BEGIN
				SELECT @TotalRowsBettrans = COUNT(1)
				FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_Recommend)
					INNER JOIN @TempAg AS a ON b.recommend = a.CustId
					INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
					LEFT JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1 AND s.ProductID IN (1, 3, 5, 25, 27)
					LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.matchid = o.orid AND s.EventType = 2 AND s.ProductID = 1
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid AND s.EventType = 2 AND s.ProductID = 1
					LEFT JOIN dbo.VSOutright AS vo WITH (NOLOCK) ON b.oddsid = vo.Orid AND s.EventType = 3 AND s.ProductID = 5
					LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON vr.EventID = vo.EventID AND s.EventType = 3 AND s.ProductID = 5
				WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
					AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
					AND (@LiveIndicator = 3
						OR (b.bettype IN (9, 29, 2799) AND b.livehomescore = @LiveIndicator)
						OR (b.bettype NOT IN (9, 29, 2799) AND b.liveindicator = @LiveIndicator))
					AND (@SportType = 0 OR m.sporttype IS NULL OR m.sporttype = @SportType)
					AND (@LeagueId = 0 OR m.leagueid IS NULL OR m.leagueid = @LeagueId)
					AND (@LeagueId = 0 OR o.leagueid IS NULL OR o.leagueid = @LeagueId)
					AND (@SportType = 0 OR l.sporttype IS NULL OR l.sporttype = @SportType)
					AND (@SportType = 0 OR vr.sporttype IS NULL OR vr.sporttype = @SportType)
					AND (@MatchId = 0 OR b.matchid = @MatchId)
					AND 1 = CASE
								WHEN s.ProductID = 1 THEN
									CASE
										WHEN @Product = 'SB' AND b.tpositiontaking <> 0 THEN 1
										WHEN @Product = 'BA' AND b.tpositiontaking = 0 THEN 1
										ELSE 0
									END
								ELSE 1
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
					INNER JOIN @TempAg AS a ON b.recommend = a.CustId
					INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
				WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
					AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
					AND (@LiveIndicator = 3
						OR (b.bettype IN (9, 29, 2799) AND b.livehomescore = @LiveIndicator)
						OR (b.bettype NOT IN (9, 29, 2799) AND b.liveindicator = @LiveIndicator))
					AND (@MatchId = 0 OR b.matchid = @MatchId)
					AND 1 = CASE
								WHEN s.ProductID = 1 THEN
									CASE
										WHEN @Product = 'SB' AND b.tpositiontaking <> 0 THEN 1
										WHEN @Product = 'BA' AND b.tpositiontaking = 0 THEN 1
										ELSE 0
									END
								ELSE 1
							END
			END
			ELSE
			BEGIN
				SELECT @TotalRowsBettrans = COUNT(1)
				FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_Recommend)
					INNER JOIN @TempAg AS a ON b.recommend = a.CustId
					INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
					LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1 AND s.ProductID IN (1, 3, 5, 25, 27)
					LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.matchid = o.orid AND s.EventType = 2 AND s.ProductID = 1
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid AND s.EventType = 2 AND s.ProductID = 1
					LEFT JOIN dbo.VSOutright14 AS vo WITH (NOLOCK) ON b.oddsid = vo.Orid AND s.EventType = 3 AND s.ProductID = 5
					LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON vr.EventID = vo.EventID AND s.EventType = 3 AND s.ProductID = 5
				WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
					AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
					AND (@LiveIndicator = 3
						OR (b.bettype IN (9, 29, 2799) AND b.livehomescore = @LiveIndicator)
						OR (b.bettype NOT IN (9, 29, 2799) AND b.liveindicator = @LiveIndicator))
					AND (@SportType = 0 OR m.sporttype IS NULL OR m.sporttype = @SportType)
					AND (@LeagueId = 0 OR m.leagueid IS NULL OR m.leagueid = @LeagueId)
					AND (@LeagueId = 0 OR o.leagueid IS NULL OR o.leagueid = @LeagueId)
					AND (@SportType = 0 OR l.sporttype IS NULL OR l.sporttype = @SportType)
					AND (@SportType = 0 OR vr.sporttype IS NULL OR vr.sporttype = @SportType)
					AND (@MatchId = 0 OR b.matchid = @MatchId)
					AND 1 = CASE
								WHEN s.ProductID = 1 THEN
									CASE
										WHEN @Product = 'SB' AND b.tpositiontaking <> 0 THEN 1
										WHEN @Product = 'BA' AND b.tpositiontaking = 0 THEN 1
										ELSE 0
									END
								ELSE 1
							END
			END
		END
	END

	SELECT @TotalRows = @TotalRowsBettrans + @TotalRowsBettrans14
END








GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_Licensee_TotalRows] TO [bodbLicenseeNet]
GO
