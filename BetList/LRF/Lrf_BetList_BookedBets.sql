/*<info serverAlias="DBACC-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_BookedBets]
	@AgentList			VARCHAR(MAX),
	@SearchText			VARCHAR(50),
	@SearchOption		TINYINT			= 1,
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@BaseCurrency		VARCHAR(12)		= '',
	@ConvertToBaseCur	BIT				= 0,	-- Convert to base currency or not
	@StatusIdList		VARCHAR(50)		= '',
	@Platform			VARCHAR(100)	= 'All',
	@PageSize			INT				= 1000,
	@PageIndex			INT				= 1,
	@Sort				NVARCHAR(50)	= N'TransDate ASC',
	@TotalRows			INT				= 0 OUTPUT,
	@SumStake			MONEY			= 0 OUTPUT
AS

/*
	Created: Kos@20240321
	Task: LAP - Betting Ticket Center - Booked Bets
	DB: DBACC.bodb02
	Parameter's Explanation:
		- @SearchOption:
			- 1: Booked ID
			- 2: Ref No
			- 3: Username
		- @StatusIdList:
			- 0: Booking
			- 1: Successful
			- 2: Unsuccessful
			- 4: Cancelled
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

	Revisions:
		- 20240321@Kos: Support Booked Bets [#Redmine: 202341]
		- 20241210@Kos: Add unknown betfroms into group Others [#Redmine: 214849]
		- 20250225@Kos: Fix bug FLOAT rounding [#Redmine: 194970]
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

	DECLARE @CustId	INT = 0

	IF @HasError = 0
	BEGIN
		-- Get CustId in case of inputting Username
		IF @SearchOption = 3
		BEGIN
			SET @CustId = -1

			SELECT @CustId = custid
			FROM dbo.Customer AS c WITH (NOLOCK)
			WHERE EXISTS (SELECT 1 FROM @TempAg WHERE CustId = c.recommend)
				AND c.username = @SearchText

			IF @CustId = -1
			BEGIN
				SELECT @CustId = custid
				FROM dbo.Customer AS c WITH (NOLOCK)
				WHERE EXISTS (SELECT 1 FROM @TempAg WHERE CustId = c.recommend)
					AND c.username2 LIKE + '%$' + @SearchText
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
		TransId			BIGINT,
		RefNo			BIGINT,
		CustId			INT,
		Currency		SMALLINT,
		Recommend		INT,
		SportType		SMALLINT,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(20),
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		OddsType		TINYINT,
		OddsLower		MONEY,
		OddsUpper		MONEY,
		Stake			MONEY,
		StatusId		TINYINT,
		TransDate		DATETIME,
		WinLostDate		SMALLDATETIME,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				VARCHAR(45),
		BetFrom			NVARCHAR(4),
		LeagueId		INT,
		LeagueGroupId	SMALLINT,
		MatchId			INT,
		MatchCode		NVARCHAR(50),
		EventDate		DATETIME,
		HomeId			INT,
		AwayId			INT,
		IsNeutral		BIT,
		BetStatus		NVARCHAR(50),
		TransDesc		NVARCHAR(1000),
		Reason			SMALLINT,
		OddsInfo		VARCHAR(500),
		Hdp				SMALLMONEY
	)

	CREATE TABLE #PagingData (
		RowNum			INT,
		TransId			BIGINT,
		RefNo			BIGINT,
		CustId			INT,
		Currency		SMALLINT,
		Recommend		INT,
		SportType		SMALLINT,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(20),
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		OddsType		TINYINT,
		OddsLower		MONEY,
		OddsUpper		MONEY,
		Stake			MONEY,
		StatusId		TINYINT,
		TransDate		DATETIME,
		WinLostDate		SMALLDATETIME,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				VARCHAR(45),
		BetFrom			NVARCHAR(4),
		LeagueId		INT,
		LeagueGroupId	SMALLINT,
		MatchId			INT,
		MatchCode		NVARCHAR(50),
		EventDate			DATETIME,
		HomeId			INT,
		AwayId			INT,
		IsNeutral		BIT,
		BetStatus		NVARCHAR(50),
		TransDesc		NVARCHAR(1000),
		Reason			SMALLINT,
		OddsInfo		VARCHAR(500),
		Hdp				SMALLMONEY
	)

	CREATE TABLE #ExchangeRate (
		ExchangeId					INT,
		FirstExchangeDateByMonth	SMALLDATETIME,
		LastExchangeDateByMonth		SMALLDATETIME,
		Rate						FLOAT
	)

	DECLARE @RefNo BIGINT = 0

	IF @SearchOption IN (1, 2)
		SET @RefNo = CONVERT(BIGINT, @SearchText)

	IF @HasError = 0
	BEGIN
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

		IF ',' + @StatusIdList + ',' LIKE '%,0,%'		-- Processing Bet
		BEGIN
			SET @StatusIdList = @StatusIdList + ',3'
		END

		DECLARE @TempFromDate	DATETIME2(7),
			@TempToDate			DATETIME2(7)

		SET @TempFromDate = @FromDate
		SET @TempToDate = DATEADD(DAY, 1, @ToDate)

		IF @SearchOption IN (1, 2)
		BEGIN
			INSERT INTO #Data (
				TransId,
				RefNo,
				CustId,
				Currency,
				Recommend,
				SportType,
				BetType,
				BetTeam,
				OddsType,
				OddsLower,
				OddsUpper,
				Stake,
				StatusId,
				TransDate,
				LiveIndicator,
				LiveHomeScore,
				LiveAwayScore,
				Ip,
				BetFrom,
				LeagueId,
				MatchId,
				HomeId,
				AwayId,
				Reason,
				OddsInfo,
				Hdp)
			SELECT
				b.ReservationTicketId,
				b.TransId,
				b.CustId,
				b.CurrencyId,
				b.recommend,
				b.SportType,
				b.BetType,
				b.BetTeam,
				b.OddsType,
				b.OddsLower,
				b.OddsUpper,
				b.Stake,
				b.Status,
				b.CreateTime,
				b.IsLive,
				b.livehomescore,
				b.liveawayscore,
				b.Ip,
				b.BetFrom,
				b.LeagueId,
				b.MatchId,
				b.HomeTeamId,
				b.AwayTeamId,
				b.MatchingFailureReason,
				b.OddsInfo,
				b.Hdp
			FROM dbo.ReservationTickets AS b WITH (NOLOCK)
			WHERE 1 = CASE
						WHEN @SearchOption = 1 AND b.ReservationTicketId = @RefNo THEN 1
						WHEN @SearchOption = 2 AND ISNULL(b.TransId, 0) = @RefNo THEN 1
						ELSE 0
					END
		END
		ELSE
		BEGIN
			INSERT INTO #Data (
				TransId,
				RefNo,
				CustId,
				Currency,
				Recommend,
				SportType,
				BetType,
				BetTeam,
				OddsType,
				OddsLower,
				OddsUpper,
				Stake,
				StatusId,
				TransDate,
				LiveIndicator,
				LiveHomeScore,
				LiveAwayScore,
				Ip,
				BetFrom,
				LeagueId,
				MatchId,
				HomeId,
				AwayId,
				Reason,
				OddsInfo,
				Hdp)
			SELECT
				b.ReservationTicketId,
				b.TransId,
				b.CustId,
				b.CurrencyId,
				b.recommend,
				b.SportType,
				b.BetType,
				b.BetTeam,
				b.OddsType,
				b.OddsLower,
				b.OddsUpper,
				b.Stake,
				b.Status,
				b.CreateTime,
				b.IsLive,
				b.livehomescore,
				b.liveawayscore,
				b.Ip,
				b.BetFrom,
				b.LeagueId,
				b.MatchId,
				b.HomeTeamId,
				b.AwayTeamId,
				b.MatchingFailureReason,
				b.OddsInfo,
				b.Hdp
			FROM dbo.ReservationTickets AS b WITH (NOLOCK)
				LEFT JOIN #PlatformList AS pl ON pl.BetFrom = b.betfrom
				LEFT JOIN #AllPlatformList AS apl ON apl.BetFrom = b.betfrom
			WHERE b.CreateTime >= @TempFromDate AND b.CreateTime < @TempToDate
				AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.Status) + ',%'
				AND b.CustId = @CustId
				AND 1 = CASE
							WHEN @Platform = 'All' THEN 1
							WHEN pl.BetFrom IS NOT NULL THEN 1
							WHEN apl.BetFrom IS NULL AND ',' + @Platform + ',' LIKE '%,88,%' THEN 1
							WHEN apl.BetFrom IS NULL AND ',' + @Platform + ',' LIKE '%,99,%' THEN 1
							ELSE 0
						END
		END

		DELETE b
		FROM #Data AS b
		WHERE NOT EXISTS (SELECT 1 FROM @TempAg WHERE CustId = b.Recommend AND Currency = b.Currency)

		IF EXISTS (SELECT TOP(1) 1 FROM #Data)
		BEGIN
			UPDATE b
			SET
				Hdp1 = CASE
							WHEN b.Hdp > 0 THEN b.Hdp
							ELSE 0
						END,
				Hdp2 = CASE
							WHEN b.Hdp < 0 THEN -b.Hdp
							ELSE 0
						END,
				TransDesc = b.OddsInfo
			FROM #Data AS b

			UPDATE b
			SET
				WinLostDate = m.eventdate,
				LeagueGroupId = l.LeagueGroupID,
				MatchCode = m.matchcode,
				EventDate = m.GlobalShowTime,
				IsNeutral = m.IsNeutral,
				BetStatus = m.betstatus
			FROM #Data AS b
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.matchid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = m.leagueid

			UPDATE b
			SET
				WinLostDate = m.eventdate,
				LeagueGroupId = l.LeagueGroupID,
				MatchCode = m.matchcode,
				EventDate = m.GlobalShowTime,
				IsNeutral = m.IsNeutral,
				BetStatus = m.betstatus
			FROM #Data AS b
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.matchid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
			WHERE b.WinLostDate IS NULL

			UPDATE b
			SET
				WinLostDate = m.eventdate,
				LeagueGroupId = l.LeagueGroupID,
				MatchCode = m.matchcode,
				EventDate = m.GlobalShowTime,
				IsNeutral = m.IsNeutral,
				BetStatus = m.betstatus
			FROM #Data AS b
				INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON m.matchid = b.matchid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
			WHERE b.WinLostDate IS NULL

			DECLARE @ExFromDate	SMALLDATETIME,
				@ExToDate 		SMALLDATETIME,
				@Today			SMALLDATETIME

			SET @Today = DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)

			SELECT
				@ExFromDate = MIN(WinLostDate),
				@ExToDate = MAX(WinLostDate)
			FROM #Data

			-- Get exchange rate
			IF @BaseCurrency <> ''
			BEGIN
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
							
				IF EXISTS (SELECT 1 FROM #Data WHERE WinLostDate > @Today)
				BEGIN
					INSERT INTO #ExchangeRate
					SELECT
						e.ExchangeId,
						e.FromDate,
						e.ToDate,
						e.Rate
					FROM dbo.Lrf_f_GetExchangeRate(@Today, @Today, @BaseCurrency, '') AS e
					WHERE EXISTS (SELECT 1 FROM #Data WHERE Currency = e.ExchangeId)
						AND NOT EXISTS (SELECT 1 FROM #ExchangeRate
										WHERE ExchangeId = e.ExchangeId
											AND @Today BETWEEN FromDate AND ToDate )
				END
			END

			-- Return data
			SELECT
				@TotalRows	= COUNT(b.TransId),
				@SumStake	= SUM(b.Stake * ISNULL(e.Rate, 1))
			FROM #Data AS b
				LEFT JOIN #ExchangeRate AS e
					ON e.ExchangeId = b.Currency
					AND CASE
							WHEN b.WinLostDate > @Today THEN @Today
							ELSE b.WinLostDate
						END BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth

			IF @ConvertToBaseCur = 0
			BEGIN
				DELETE FROM #ExchangeRate
			END

			-- Get sort text
			IF @BaseCurrency <> '' AND @Sort LIKE '%Stake%'
			BEGIN
				DECLARE @CharIndex TINYINT

				SELECT @CharIndex = CHARINDEX(' ', @Sort, 1)

				SELECT @Sort = SUBSTRING(@Sort, 0, @CharIndex) + ' * ISNULL(e.Rate, 1)' + SUBSTRING(@Sort, @CharIndex, LEN(@Sort))
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
		END
	END

	-- Return data
	SELECT
		c.username,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS NickName,
		a.TransId,
		a.RefNo,
		a.CustId,
		a.Currency,
		a.SportType,
		a.BetType,
		a.BetTeam,
		a.Hdp1,
		a.Hdp2,
		a.OddsType,
		a.OddsLower,
		a.OddsUpper,
		CAST(a.Stake * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS Stake,
		a.StatusId,
		a.TransDate,
		a.WinLostDate,
		a.LiveIndicator,
		a.LiveHomeScore,
		a.LiveAwayScore,
		a.Ip,
		a.BetFrom,
		a.LeagueId,
		a.LeagueGroupId,
		a.MatchId,
		a.MatchCode,
		a.EventDate,
		a.HomeId,
		a.AwayId,
		a.IsNeutral,
		a.BetStatus,
		a.TransDesc,
		a.Reason
	FROM
		#PagingData AS a
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = a.CustId
		LEFT JOIN #ExchangeRate AS e
			ON e.ExchangeId = a.Currency
			AND CASE
					WHEN a.WinLostDate > @Today THEN @Today
					ELSE a.WinLostDate
				END BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
	ORDER BY a.RowNum ASC

	DROP TABLE #AllPlatformList
	DROP TABLE #PlatformList
	DROP TABLE #Data
	DROP TABLE #PagingData
	DROP TABLE #ExchangeRate
END
GO
