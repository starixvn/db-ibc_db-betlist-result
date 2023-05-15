/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_LiveReport_SelWinlossNumberGame]
	@AgentList		VARCHAR(MAX),
	@SportType		SMALLINT,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BaseCurrency	VARCHAR(12)		= '',
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 1,
	@Sort			NVARCHAR(50)	= 'TransDate ASC',
	@LiveIndicator	INT				= 1
AS

/*
	Created: Henry@20120119
	Task: Live Report - Number Game Betlist
	DB: DBEXT.bodb02
	Original: [Lrf_BetList_SelWinlossNumberGame]
	Revisions:
		- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily
		- 20120614@Jim: optimize code
		- 20120724@Jim: add player commision value 
		- 20121004@Jim: replace @currency input param by @currencyID
		- 20130403@Jim: fix bug page index and liveindicator value 
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20130625@Jim: Support to view currency UUS
		- 20140520@Hannah: Sort betlist
		- 20140522@Hannah: fix bug Sort betlist
		- 20140602@Hannah: Separate Live/ Non - Live data in Live Report
		- 20141111@Winnie: change from LicenseeCust to f_SelLicenseeCust
		- 20150124@Winnie: add base currency GBP
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY, sporttype from TINYINT to SMALLINT [Redmine: #48660]
		- 20170301@Kos: Support sub licensees [#Redmine: 71679]
		- 20181031@Patrick: DB052 indexes revolution [RedmineID: #103572]
		- 20181207@Kos: Enhance performance [#Redmine: 103698]
					- Add new params @SportType, @BaseCurrency
		- 20190524@Kos: Support more base currency [#Redmine: 112531]
		- 20200207@Kos: Support sort by trans time [Redmine: #126886]
		- 20201231@Kos: Support Happy 5 Linked Games [Redmine: #147446]
		- 20210301@Kos: Add BDT and INR as base currencies [Redmine: 150375]
		- 20210929@Kos: Extend length to support IPv6 [Redmine: 162342]
		- 20220110@Kos: Support TxId for 3rd products [Redmine: #166706]
		- 20220922@Kos: Support crypto currency [Redmine: 177481]
		- 20230404@Kos: Don't return betfrom anymore [Redmine: #178059]
		- 20230515@Kos: Hotfix - extend dynamic SQL length [Redmine: #188202]

	Param's Explanation:
		@LiveIndicator : indicate that whether the report will get live data or not
			+ 0: Non-Live data only
			+ 1: Live data only
			+ 2: All
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
	FROM dbo.f_SportBettypeMatrix_Sel (3, @SportType, 0, 2, '', '', @IsTest)

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
		OddsType		TINYINT,
		Odds			MONEY,
		MOdds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		Status			NVARCHAR(10),
		TransDate		DATETIME,
		WinLostDate		SMALLDATETIME,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				VARCHAR(45),
		LeagueId		INT,
		MatchId			INT,
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000),
		ExtraInfo		VARCHAR(1000),
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
		OddsType		TINYINT,
		Odds			MONEY,
		MOdds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		Status			NVARCHAR(10),
		TransDate		DATETIME,
		WinLostDate		SMALLDATETIME,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				VARCHAR(45),
		LeagueId		INT,
		MatchId			INT,
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000),
		ExtraInfo		VARCHAR(1000),
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
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

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
			OddsType,
			Odds,
			MOdds,
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
			MatchId,
			BetCheck,
			TransDesc,
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
			b.oddstype,
			b.odds,
			b.modds,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.status,
			b.transdate,
			b.winlostdate,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			b.matchid,
			b.betcheck,
			b.transdesc,
			b.ExtraInfo,
			sbt.EventType,
			1 AS WhTicket
		FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_recommend)
			INNER JOIN #TempAg AS t ON t.custid = b.recommend
			INNER JOIN @SportBettype AS sbt ON sbt.bettype = b.Bettype
		WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
			AND b.statusID IN (111, 112, 113)
			AND (@LiveIndicator = 2 OR b.liveindicator = @LiveIndicator)
	END

	-- bettrans14
	IF @FromDate <= @MoveBetsDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @ToDate

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
			OddsType,
			Odds,
			MOdds,
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
			MatchId,
			BetCheck,
			TransDesc,
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
			b.oddstype,
			b.odds,
			b.modds,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.status,
			b.transdate,
			b.winlostdate,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			b.matchid,
			b.betcheck,
			b.transdesc,
			b.ExtraInfo,
			sbt.EventType,
			2 AS WhTicket
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN #TempAg AS t ON t.custid = b.recommend
			INNER JOIN @SportBettype AS sbt ON sbt.bettype = b.Bettype
		WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
			AND b.statusID IN (111, 112, 113)
			AND (@LiveIndicator = 2 OR b.liveindicator = @LiveIndicator)
	END

	DELETE b
	FROM #Data AS b
	WHERE NOT EXISTS (SELECT 1 FROM #TempAg WHERE CustId = b.Recommend AND Currency = b.Currency)

	DECLARE @TotalRows INT

	SELECT @TotalRows = COUNT(1) FROM #Data

	DECLARE @Sql NVARCHAR(3000)

	IF @TotalRows > 0
	BEGIN
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
							AND WinLostDate BETWEEN e.FromDate AND e.ToDate)
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

		SELECT
			c.username,
			SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS NickName,
			b.TransId,
			b.RefNo,
			b.CustId,
			b.Currency,
			CASE
				WHEN b.EventType = 0 THEN b.MatchId
				WHEN b.EventType = 1 AND b.WhTicket = 1 THEN m.sporttype
				WHEN b.EventType = 1 AND b.WhTicket = 2 THEN m14.sporttype
				ELSE 0
			END AS SportType,
			b.BetType,
			b.BetId,
			b.BetTeam,
			b.Hdp1,
			b.OddsType,
			b.Odds,
			b.MOdds,
			b.Stake * ISNULL(e.Rate, 1) AS Stake,
			b.Actual_Stake * ISNULL(e.Rate, 1) AS Actual_Stake,
			b.WinLost * ISNULL(e.Rate, 1) AS WinLost,
			b.LicenseeWL * ISNULL(e.Rate, 1) AS LicenseeWL,
			b.Comm * ISNULL(e.Rate, 1) AS Comm,
			b.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm,
			b.Status,
			b.TransDate,
			b.WinLostDate,
			b.LiveIndicator,
			b.LiveHomeScore,
			b.LiveAwayScore,
			b.Ip,
			CASE
				WHEN b.EventType = 1 AND b.WhTicket = 1 THEN m.leagueid
				WHEN b.EventType = 1 AND b.WhTicket = 2 THEN m14.leagueid
				ELSE 0
			END AS LeagueId,
			b.MatchId,
			CASE
				WHEN b.EventType = 1 AND b.WhTicket = 1 THEN m.matchcode
				WHEN b.EventType = 1 AND b.WhTicket = 2 THEN m14.matchcode
				ELSE ''
			END AS MatchCode,
			CASE
				WHEN b.EventType = 0 THEN ISNULL(b.betcheck, '')
				ELSE ''
			END AS BetCheck,
			CASE
				WHEN b.EventType = 0 THEN ISNULL(b.transdesc, '')
				ELSE ''
			END AS TransDesc,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo
		FROM
			#PagingData AS b
			INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = b.CustId
			LEFT JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid AND b.WhTicket = 1
			LEFT JOIN dbo.match14 AS m14 WITH (NOLOCK) ON b.matchid = m14.matchid AND b.WhTicket = 2
			LEFT JOIN #ExchangeRate AS e
				ON e.ExchangeId = b.Currency
					AND b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
		ORDER BY b.RowNum ASC
	END
	ELSE
	BEGIN
		CREATE TABLE #Customer (
			CustId		INT,
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

		SET @Sql = 
			N'SELECT
				c.username,
				SUBSTRING(c.username2, CHARINDEX(''$'', c.username2) + 1, LEN(c.username2) - CHARINDEX(''$'', c.username2)) AS NickName,
				b.TransId,
				b.RefNo,
				b.CustId,
				b.Currency,
				CASE
					WHEN b.EventType = 0 THEN b.MatchId
					WHEN b.EventType = 1 AND b.WhTicket = 1 THEN m.sporttype
					WHEN b.EventType = 1 AND b.WhTicket = 2 THEN m14.sporttype
					ELSE 0
				END AS SportType,
				b.BetType,
				b.BetId,
				b.BetTeam,
				b.Hdp1,
				b.OddsType,
				b.Odds,
				b.MOdds,
				b.Stake * ISNULL(e.Rate, 1) AS Stake,
				b.Actual_Stake * ISNULL(e.Rate, 1) AS Actual_Stake,
				b.WinLost * ISNULL(e.Rate, 1) AS WinLost,
				b.LicenseeWL * ISNULL(e.Rate, 1) AS LicenseeWL,
				b.Comm * ISNULL(e.Rate, 1) AS Comm,
				b.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm,
				b.Status,
				b.TransDate,
				b.WinLostDate,
				b.LiveIndicator,
				b.LiveHomeScore,
				b.LiveAwayScore,
				b.Ip,
				CASE
					WHEN b.EventType = 1 AND b.WhTicket = 1 THEN m.leagueid
					WHEN b.EventType = 1 AND b.WhTicket = 2 THEN m14.leagueid
					ELSE 0
				END AS LeagueId,
				b.MatchId,
				CASE
					WHEN b.EventType = 1 AND b.WhTicket = 1 THEN m.matchcode
					WHEN b.EventType = 1 AND b.WhTicket = 2 THEN m14.matchcode
					ELSE ''''
				END AS MatchCode,
				CASE
					WHEN b.EventType = 0 THEN ISNULL(b.betcheck, '''')
					ELSE ''''
				END AS BetCheck,
				CASE
					WHEN b.EventType = 0 THEN ISNULL(b.transdesc, '''')
					ELSE ''''
				END AS TransDesc,
				ISNULL(b.ExtraInfo, '''') AS ExtraInfo
			FROM
				#Data AS b
				INNER JOIN #Customer AS c ON c.custid = b.CustId
				LEFT JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid AND b.WhTicket = 1
				LEFT JOIN dbo.match14 AS m14 WITH (NOLOCK) ON b.matchid = m14.matchid AND b.WhTicket = 2
					LEFT JOIN #ExchangeRate AS e
						ON e.ExchangeId = b.Currency
							AND b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
			ORDER BY ' + @Sort

		EXEC sp_executesql @Sql

		DROP TABLE #Customer
	END

	DROP TABLE #TempAg
	DROP TABLE #Data
	DROP TABLE #PagingData
	DROP TABLE #ExchangeRate
END
GO
