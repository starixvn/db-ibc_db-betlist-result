/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_LiveReport_SelWinlossOutright]
	@AgentList		VARCHAR(MAX),
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 0,
	@BaseCurrency	VARCHAR(12),
	@TotalRows		INT				= 0 OUTPUT,
	@SumWinLost		MONEY			= 0 OUTPUT,
	@SumLicenseeWL	MONEY			= 0 OUTPUT,
	@SumComm		MONEY			= 0 OUTPUT,
	@SumPlayerComm	MONEY			= 0 OUTPUT
AS

/*
	Created: Henry@20120111
	Task: get bet tickets for outright, horse racing in Live Report
	DB: DBEXT.bodb02

	Revisions:
		- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily
		- 20120614@Jim: optimize code
		- 20120724@Jim: add playercomm value
		- 20121004@Jim: replace @currency input param by @currencyID
		- 20130305@Jim: remove Grand Total Row in the result data
		- 20130404@Jim: set default @ShowBA=0
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20130625@Jim: support to view currency UUS
		- 20141111@Winnie: Change from LicenseeCust to f_SelLicenseeCust
		- 20150126@Winnie: Add base currency GBP 
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20170306@Kos: Support sub licensees [#Redmine: 71679]
		- 20170531@Kos: Prevent data duplication during Move Bet process [#Redmine: 77065]
		- 20190521@Kos: Add new input param @BaseCurrency [#Redmine: 112531]
					- Don't return column AwayId, IsNeutral, IsBA anymore
		- 20200207@Kos: Support sort by trans time [Redmine: #126886]
		- 20200525@Kos: Support show licensee transaction ID [Redmine: #134629]
		- 20210301@Kos: Add BDT and INR as base currencies [Redmine: 150375]
		- 20210706@Kos: Support Beach Volleyball [Redmine: #157296]
		- 20210929@Kos: Extend length to support IPv6 [Redmine: 162342]
		- 20230922@Kos: Support crypto currency [Redmine: 177481]
		- 20240527@Kos: Hotfix - support paging [Redmine: #204955]
				- Add new params @TotalRows INT, @SumWinLost MONEY, @SumLicenseeWL MONEY, @SumComm MONEY, @SumPlayerComm MONEY
		- 20250225@Kos: Fix bug FLOAT rounding [#Redmine: 194970]
		- 20250313@Kos: Remove BA [RedmineID: #216882]
					- Remove input param @ShowBA, @ShowSB
*/

BEGIN
	SET NOCOUNT ON

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
		SELECT ErrCode = 100,
			ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH

	CREATE TABLE #AgWinlossOutright (
		SportType		INT,
		CustId			INT,
		BetType			SMALLINT,
		TransId			BIGINT,
		MatchCode		VARCHAR(50),
		HomeId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		OddsType		TINYINT,
		Status			NVARCHAR(50),
		Stake			MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		TransDate		DATETIME,
		BetTeam			NVARCHAR(50),
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LeagueId		INT,
		MatchId			INT,
		Ip				VARCHAR(45),
		WinLostDate		SMALLDATETIME,
		Currency		SMALLINT,
		ExtraInfo		VARCHAR(1000)
	)

	DECLARE @TempFromDate	SMALLDATETIME,
		@TempToDate			SMALLDATETIME

	IF @Todate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate =  DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		INSERT INTO #AgWinlossOutright
		SELECT
			l.sporttype,
			b.custid,
			b.bettype,
			b.transid,
			m.matchcode,
			m.teamid,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.oddstype,
			b.status,
			b.stake,
			(b.winlost - b.actual_stake) AS WinLost,
			-(b.winlost - b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.transdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			l.leagueID,
			b.matchid, 
			b.ip,
			b.winlostdate,
			b.currency,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
		WHERE
			b.recommend IN (SELECT CustId FROM @TempAg)
			AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
			AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
			AND b.bettype = 10
			AND b.statusID IN (111, 112, 113)
	END

	IF @Fromdate <= @MoveBetsDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @ToDate

		INSERT INTO #AgWinlossOutright
		SELECT
			l.sporttype,
			b.custid,
			b.bettype,
			b.transid,
			m.matchcode,
			m.teamid,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.oddstype,
			b.status,
			b.stake,
			(b.winlost - b.actual_stake) AS WinLost,
			-(b.winlost - b.actual_stake)AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.transdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			l.leagueID,
			b.matchid,
			b.ip,
			b.winlostdate,
			b.currency,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo
		FROM
			dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.outright14 AS m WITH (NOLOCK) ON b.matchid = m.orid
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
		WHERE
			b.recommend IN (SELECT CustId FROM @TempAg)
			AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
			AND b.winlostdate BETWEEN @FromDate AND @TempToDate
			AND b.bettype = 10
			AND b.statusID IN (111, 112, 113)
	END

	CREATE TABLE #ExchangeRate (
		ExchangeId					INT,
		FirstExchangeDateByMonth	SMALLDATETIME,
		LastExchangeDateByMonth		SMALLDATETIME,
		Rate						FLOAT
	)

	-- Get exchange rate
	DECLARE @Today SMALLDATETIME
 
	SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

	DECLARE @ExFromDate SMALLDATETIME,
		@ExToDate SMALLDATETIME

	SELECT
		@ExFromDate = MIN(WinLostDate),
		@ExToDate = MAX(WinLostDate)
	FROM #AgWinlossOutright

	INSERT INTO #ExchangeRate
	SELECT
		e.ExchangeId,
		e.FromDate,
		e.ToDate,
		e.Rate
	FROM dbo.Lrf_f_GetExchangeRate(@ExFromDate, @ExToDate, @BaseCurrency, '') AS e
	WHERE EXISTS (SELECT 1 FROM #AgWinlossOutright
				WHERE Currency = e.ExchangeId
					AND WinLostDate BETWEEN e.FromDate AND e.ToDate)

	-- Return data
	SELECT
		@TotalRows		= COUNT(b.TransId),
		@SumWinlost		= SUM(b.WinLost * ISNULL(e.Rate, 1)),
		@SumLicenseeWL	= SUM(b.LicenseeWL * ISNULL(e.Rate, 1)),
		@SumComm		= SUM(b.Comm * ISNULL(e.Rate, 1)),
		@SumPlayerComm	= SUM(b.PlayerComm * ISNULL(e.Rate, 1))
	FROM #AgWinlossOutright AS b
		LEFT JOIN #ExchangeRate AS e
			ON e.ExchangeId = b.Currency
				AND b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth

	DECLARE @RowStart INT,
		@RowEnd INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	SELECT
		a.SportType,
		a.CustId,
		c.username,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS Nickname,
		a.BetType,
		a.TransId,
		a.MatchCode,
		a.HomeId,
		a.Hdp1,
		a.Hdp2,
		a.Odds,
		a.OddsType,
		a.Status,
		CAST(a.Stake * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS Stake,
		CAST(a.WinLost * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS WinLost,
		CAST(a.LicenseeWL * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS LicenseeWL,
		CAST(a.Comm * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS Comm,
		CAST(a.PlayerComm * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS PlayerComm,
		a.TransDate,
		a.BetTeam,
		a.LiveIndicator,
		a.LiveHomeScore,
		a.LiveAwayScore,
		a.LeagueId,
		a.MatchId,
		a.Ip,
		a.WinLostDate,
		a.Currency,
		a.ExtraInfo
	FROM (
			SELECT
				ROW_NUMBER() OVER(ORDER BY b.TransDate ASC) AS RowNum,
				b.*
			FROM #AgWinlossOutright AS b
		) AS a
		INNER JOIN dbo.customer AS c WITH (NOLOCK) ON c.custid = a.custid
		LEFT JOIN #ExchangeRate AS e
			ON e.ExchangeId = a.Currency
				AND CASE
						WHEN a.WinLostDate > @Today THEN @Today
						ELSE a.WinLostDate
					END BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
	WHERE a.RowNum BETWEEN @RowStart AND @RowEnd

	DROP TABLE #AgWinlossOutright
	DROP TABLE #ExchangeRate
END
GO
