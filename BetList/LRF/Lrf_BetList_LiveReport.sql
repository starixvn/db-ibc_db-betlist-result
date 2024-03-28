/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_LiveReport]
	@AgentList		VARCHAR(MAX),
	@ProductList	VARCHAR(200),
	@SportType		SMALLINT,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BaseCurrency	VARCHAR(12)		= '',
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 1,
	@Sort			NVARCHAR(50)	= 'TransDate ASC'
AS

/*
	Created: 20210913@Kos
	Task: Live Report - Bet List
	DB: DBEXT.bodb02

	Revisions:
		- 20211104@Kos: Support Sports Lottery [RedmineID: #163191]
		- 20220113@Kos: Support new 3rd result API [Redmine: #166047]
		- 20220215@Kos: Support TxId for 3rd products [Redmine: #166706]
		- 20220313@Kos: Hotfix - Extend range for IP v6 [Redmine: #169856]
		- 20220314@Kos: Support Virtual Sports 3 [Redmine: #145337]
		- 20220428@Kos: Support Bitcoin [RedmineID: #160160]
		- 20220922@Kos: Support crypto currency [Redmine: 177481]
		- 20230404@Kos: Don't return betfrom anymore [Redmine: #178059]
*/

BEGIN
	SET NOCOUNT ON

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
		SELECT ErrCode = 100,
			ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductID TINYINT, BetType SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)
	
	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, @SportType, 0, 2, '', @ProductList, @IsTest)

	DECLARE @TempFromDate DATETIME,
		@TempToDate DATETIME

	CREATE TABLE #Data (
		TransId			BIGINT,
		RefNo			BIGINT,
		CustId			INT,
		Recommend		INT,
		Currency		SMALLINT,
		SportType		SMALLINT,
		BetType			SMALLINT,
		BetId			BIGINT,
		BetTeam			NVARCHAR(20),
		Hdp1			SMALLMONEY,
		Odds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		Status			NVARCHAR(10),
		TransDate		DATETIME,
		WinLostDate		SMALLDATETIME,
		Ip				VARCHAR(45),
		LeagueId		INT,
		MatchId			INT,
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000),
		BetdaqId		BIGINT,
		SiteId			VARCHAR(20),
		ExtraInfo		VARCHAR(1000),
		Product			VARCHAR(30),
		EventType		TINYINT,
		WhTicket		TINYINT
	)

	CREATE TABLE #PagingData (
		RowNum			INT,
		TransId			BIGINT,
		RefNo			BIGINT,
		CustId			INT,
		Recommend		INT,
		Currency		SMALLINT,
		SportType		SMALLINT,
		BetType			SMALLINT,
		BetId			BIGINT,
		BetTeam			NVARCHAR(20),
		Hdp1			SMALLMONEY,
		Odds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		Status			NVARCHAR(10),
		TransDate		DATETIME,
		WinLostDate		SMALLDATETIME,
		Ip				VARCHAR(45),
		LeagueId		INT,
		MatchId			INT,
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000),
		BetdaqId		BIGINT,
		SiteId			VARCHAR(20),
		ExtraInfo		VARCHAR(1000),
		Product			VARCHAR(30),
		EventType		TINYINT,
		WhTicket		TINYINT
	)

	CREATE TABLE #ExchangeRate (
		ExchangeId					INT,
		FirstExchangeDateByMonth	SMALLDATETIME,
		LastExchangeDateByMonth		SMALLDATETIME,
		Rate						FLOAT
	)

	-- bettrans
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
			Odds,
			Stake,
			Actual_Stake,
			WinLost,
			LicenseeWL,
			Comm,
			PlayerComm,
			Status,
			TransDate,
			WinLostDate,
			Ip,
			MatchId,
			BetCheck,
			TransDesc,
			BetdaqId,
			ExtraInfo,
			EventType,
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
			b.odds,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.status,
			b.transdate,
			b.winlostdate,
			b.ip,
			b.matchid,
			ISNULL(b.betcheck, ''),
			ISNULL(b.transdesc, ''),
			b.betdaqid,
			ISNULL(b.ExtraInfo, ''),
			sbt.EventType,
			1 AS WhTicket
		FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_recommend)
			INNER JOIN #TempAg AS t ON t.custid = b.recommend
			INNER JOIN @SportBettype AS sbt ON sbt.bettype = b.Bettype
		WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
			AND b.statusID IN (111, 112, 113)
	END

	-- bettrans14
	IF @FromDate <= @MoveBetsDay
	BEGIN
		SET @TempToDate = CASE
							WHEN @ToDate >= @MoveBetsDay THEN @MoveBetsDay
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
			Odds,
			Stake,
			Actual_Stake,
			WinLost,
			LicenseeWL,
			Comm,
			PlayerComm,
			Status,
			TransDate,
			WinLostDate,
			Ip,
			MatchId,
			BetCheck,
			TransDesc,
			BetdaqId,
			ExtraInfo,
			EventType,
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
			b.odds,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.status,
			b.transdate,
			b.winlostdate,
			b.ip,
			b.matchid,
			ISNULL(b.betcheck, ''),
			ISNULL(b.transdesc, ''),
			b.betdaqid,
			ISNULL(b.ExtraInfo, ''),
			sbt.EventType,
			2 AS WhTicket
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN #TempAg AS t ON t.custid = b.recommend
			INNER JOIN @SportBettype AS sbt ON sbt.bettype = b.Bettype
		WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
			AND b.statusID IN (111, 112, 113)
	END

	DELETE b
	FROM #Data AS b
	WHERE NOT EXISTS (SELECT 1 FROM #TempAg WHERE CustId = b.Recommend AND Currency = b.Currency)

	DECLARE @TotalRows INT

	SELECT @TotalRows = COUNT(1) FROM #Data

	DECLARE @Sql NVARCHAR(2000)

	IF @TotalRows > 0
	BEGIN
		UPDATE b
		SET b.Product = CASE
							WHEN s.ProductID = 49 THEN 'VS3'	-- Virtual Sports 3
							WHEN s.ProductID = 63 THEN 'SLT'	-- Sports Lottery
							WHEN s.ProductID = 69 THEN 'BTC'	-- Bitcoin
							ELSE ''
						END
		FROM #Data AS b
			INNER JOIN @SportBettype AS s ON s.BetType = b.BetType

		DECLARE @ExFromDate SMALLDATETIME,
			@ExToDate SMALLDATETIME

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
							AND WinLostDate BETWEEN e.FromDate AND e.ToDate	)
		END

		-- Get sort text
		IF @BaseCurrency <> ''
			AND (@Sort LIKE '%Stake%' OR @Sort LIKE '%WinLost%' OR @Sort LIKE '%LicenseeWL%')
		BEGIN
			DECLARE @CharIndex TINYINT

			SELECT @CharIndex = CHARINDEX(' ', @Sort, 1)

			SELECT @Sort = SUBSTRING(@Sort, 0, @CharIndex) + ' * ISNULL(e.Rate, 1)' + SUBSTRING(@Sort, @CharIndex, LEN(@Sort))
		END
	END

	IF @PageSize < @TotalRows
	BEGIN
		DECLARE @RowStart INT,
			@RowEnd INT

		SELECT @PageIndex = @PageIndex - 1,
			@RowStart = @PageSize * @PageIndex + 1,
			@RowEnd = @RowStart + @PageSize - 1

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

		UPDATE b
		SET
			SiteId = CASE
						WHEN b.Product IN ('SLT') THEN CONVERT(VARCHAR(20), b.BetdaqId)
						ELSE ''
					END
		FROM #PagingData AS b

		SELECT
			c.username,
			SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS NickName,
			b.TransId,
			b.RefNo,
			b.CustId,
			b.Currency,
			CASE
				WHEN b.Product IN ('BTC') AND b.WhTicket = 1 THEN m3rd.SportType
				WHEN b.Product IN ('BTC') AND b.WhTicket = 2 THEN m3rd14.SportType
				ELSE b.MatchId
			END AS SportType,
			b.BetType,
			b.BetId,
			b.BetTeam,
			b.Hdp1,
			b.Odds,
			b.Stake * ISNULL(e.Rate, 1) AS Stake,
			b.Actual_Stake * ISNULL(e.Rate, 1) AS Actual_Stake,
			b.WinLost * ISNULL(e.Rate, 1) AS WinLost,
			b.LicenseeWL * ISNULL(e.Rate, 1) AS LicenseeWL,
			b.Comm * ISNULL(e.Rate, 1) AS Comm,
			b.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm,
			b.Status,
			b.TransDate,
			b.WinLostDate,
			b.Ip,
			b.BetCheck,
			b.TransDesc,
			b.BetdaqId,
			b.SiteId,
			CASE
				WHEN b.Product IN ('BTC') AND b.WhTicket = 1 THEN m3rd.League3rdId
				WHEN b.Product IN ('BTC') AND b.WhTicket = 2 THEN m3rd14.League3rdId
				ELSE 0
			END AS LeagueId,
			b.MatchId,
			CASE
				WHEN b.Product IN ('BTC') AND b.WhTicket = 1 THEN m3rd.EndTime
				WHEN b.Product IN ('BTC') AND b.WhTicket = 2 THEN m3rd14.EndTime
				ELSE ''
			END AS EventDate,
			b.ExtraInfo
		FROM
			#PagingData AS b
			INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = b.CustId
			LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK) ON m3rd.Match3rdId = b.matchid AND b.WhTicket = 1
			LEFT JOIN dbo.Match3rd14 AS m3rd14 WITH (NOLOCK) ON m3rd14.Match3rdId = b.matchid AND b.WhTicket = 2
			LEFT JOIN #ExchangeRate AS e
				ON e.ExchangeId = b.Currency
					AND b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
		ORDER BY b.RowNum ASC
	END
	ELSE
	BEGIN
		CREATE TABLE #Customer (
			CustId		INT PRIMARY KEY,
			Username	VARCHAR(30),
			Username2	VARCHAR(50))

		INSERT INTO #Customer (
			CustId,
			Username,
			Username2)
		SELECT
			custid,
			username,
			username2
		FROM dbo.Customer WITH (NOLOCK)
		WHERE custid IN (SELECT DISTINCT CustId FROM #Data)

		UPDATE b
		SET
			SiteId = CASE
						WHEN b.Product IN ('SLT') THEN CONVERT(VARCHAR(20), b.BetdaqId)
						ELSE ''
					END
		FROM #Data AS b

		SET @Sql = 
			N'SELECT
				c.username,
				SUBSTRING(c.username2, CHARINDEX(''$'', c.username2) + 1, LEN(c.username2) - CHARINDEX(''$'', c.username2)) AS NickName,
				b.TransId,
				b.RefNo,
				b.CustId,
				b.Currency,
				CASE
					WHEN b.Product IN (''BTC'') AND b.WhTicket = 1 THEN m3rd.SportType
					WHEN b.Product IN (''BTC'') AND b.WhTicket = 2 THEN m3rd14.SportType
					ELSE b.MatchId
				END AS SportType,
				b.BetType,
				b.BetId,
				b.BetTeam,
				b.Hdp1,
				b.Odds,
				b.Stake * ISNULL(e.Rate, 1) AS Stake,
				b.Actual_Stake * ISNULL(e.Rate, 1) AS Actual_Stake,
				b.WinLost * ISNULL(e.Rate, 1) AS WinLost,
				b.LicenseeWL * ISNULL(e.Rate, 1) AS LicenseeWL,
				b.Comm * ISNULL(e.Rate, 1) AS Comm,
				b.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm,
				b.Status,
				b.TransDate,
				b.WinLostDate,
				b.Ip,
				b.BetCheck,
				b.TransDesc,
				b.BetdaqId,
				b.SiteId,
				CASE
					WHEN b.Product IN (''BTC'') AND b.WhTicket = 1 THEN m3rd.League3rdId
					WHEN b.Product IN (''BTC'') AND b.WhTicket = 2 THEN m3rd14.League3rdId
					ELSE 0
				END AS LeagueId,
				b.MatchId,
				CASE
					WHEN b.Product IN (''BTC'') AND b.WhTicket = 1 THEN m3rd.EndTime
					WHEN b.Product IN (''BTC'') AND b.WhTicket = 2 THEN m3rd14.EndTime
					ELSE ''''
				END AS EventDate,
				b.ExtraInfo
			FROM
				#Data AS b
				INNER JOIN #Customer AS c ON c.custid = b.CustId
				LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK) ON m3rd.Match3rdId = b.matchid AND b.WhTicket = 1
				LEFT JOIN dbo.Match3rd14 AS m3rd14 WITH (NOLOCK) ON m3rd14.Match3rdId = b.matchid AND b.WhTicket = 2
				LEFT JOIN #ExchangeRate AS e
					ON e.ExchangeId = b.Currency
						AND b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
			ORDER BY ' + @Sort

		EXEC sp_executesql @Sql

		DROP TABLE #Customer
	END

	DROP TABLE #Data
	DROP TABLE #PagingData
	DROP TABLE #ExchangeRate
END
GO
