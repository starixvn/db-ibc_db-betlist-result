/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_MatchWL_Outright]
	@AgentList		VARCHAR(MAX),
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ShowBA			BIT				= 0,
	@ShowSB			BIT				= 0,
	@ExcludeReject	BIT				= 0,
	@MoveBetsDay	SMALLDATETIME,
	@BaseCurrency	VARCHAR(12),
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 0,
	@Sort			NVARCHAR(50)	= N'TransDate ASC',
	@TotalRows		INT				= 0 OUTPUT,
	@SumWinLost		MONEY			= 0 OUTPUT,
	@SumLicenseeWL	MONEY			= 0 OUTPUT,
	@SumComm		MONEY			= 0 OUTPUT,
	@SumPlayerComm	MONEY			= 0 OUTPUT
AS

/*
	Created: Henry@20101210
	Task: Get bet tickets for outright, horse racing
	DB: DBEXT.bodb02
	Original: [Age_BetList_SelWinlossOutright_Ag]
	Revisions:
		- 20110214@Jacob: Add column discount IN the result SET
		- 20110216@Jacob: Add column nickname IN the result SET
		- 20110303@Henry: suppport based currency
		- 20110506@Henry: Change to param: @LicenseeID, @LicenseeType, @CurrencyName to get the list of agents
		- 20110712@Henry: Add column LicenseeWL
		- 20111121@Jacob: Add 3 parameters: @ShowBA & @Show SB & @ExcludeReject
		- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily
		- 20120614@Jim: optimize code
		- 20120726@Jim: add player comm value
		- 20121004@Jim: replace @currencyname input param by @currencyID
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20141111@Winnie: change from LicenseeCust to f_SelLicenseeCust
		- 20150128@Winnie: Add base currency GBP
		- 20150406@Winnie: Apply spottype bettype matrix
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160516@Kos: Add sorting function [#Redmine: 57433]
		- 20170223@Kos: Support sub licensees [#Redmine: 71679]
		- 20170531@Kos: Prevent data duplication during Move Bet process [#Redmine: 77065]
		- 20190521@Kos: Add new input param @BaseCurrency [#Redmine: 112531]
					- Change input param @Sort data type from VARCHAR(100) to NVARCHAR(50)
					- Remove params @SumWinLostUSD, @SumWinLostEUR, @SumWinLostGBP, ...
					- Don't return column AwayId, IsNeutral, IsBA anymore
		- 20200207@Kos: Support sort by trans time [Redmine: #126886]
		- 20200525@Kos: Support show licensee transaction ID [Redmine: #134629]
		- 20210301@Kos: Add BDT and INR as base currencies [Redmine: 150375]
		- 20210706@Kos: Support Beach Volleyball [Redmine: #157296]
		- 20210929@Kos: Extend length to support IPv6 [Redmine: 162342]
		- 20230922@Kos: Support crypto currency [Redmine: 177481]
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

	CREATE TABLE #Data (
		SportType		INT,
		Username		NVARCHAR(50),
		Nickname		VARCHAR(50),
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
		BetTeam			NVARCHAR(10),
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

	CREATE TABLE #ExchangeRate (
		ExchangeId					INT,
		FirstExchangeDateByMonth	SMALLDATETIME,
		LastExchangeDateByMonth		SMALLDATETIME,
		Rate						FLOAT
	)

	DECLARE @TempFromDate	SMALLDATETIME,
		@TempToDate			SMALLDATETIME

	IF @ToDate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate =  DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		IF @ShowBA = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				l.sporttype,
				b.username,
				'' AS Nickname,
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
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				l.leagueid,
				b.matchid,
				b.ip,
				b.winlostdate,
				b.currency,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
			WHERE b.bettype = 10
				AND b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.ruben = 1
				AND b.tpositiontaking = 0
				AND (@ExcludeReject = 0
					OR (@ExcludeReject = 1 AND b.statusID NOT IN (101, 102, 103)))
		END

		IF @ShowSB = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				l.sporttype,
				b.username,
				'' AS Nickname,
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
				l.leagueid,
				b.matchid,
				b.ip,
				b.winlostdate,
				b.currency,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
			WHERE b.bettype = 10
				AND b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.ruben = 1
				AND b.tpositiontaking <> 0
				AND (@ExcludeReject = 0
					OR (@ExcludeReject = 1 AND b.statusID NOT IN (101, 102, 103))) 
		END
	END

	IF @FromDate <= @MoveBetsDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @ToDate

		IF @ShowBA = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				l.sporttype,
				b.username,
				'' AS Nickname,
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
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				l.leagueid,
				b.matchid,
				b.ip,
				b.winlostdate,
				b.currency,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK) 
				INNER JOIN dbo.outright14 AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
			WHERE b.bettype = 10
				AND b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND b.ruben = 1
				AND b.tpositiontaking = 0
				AND (@ExcludeReject = 0
					OR (@ExcludeReject = 1 AND b.statusID NOT IN (101, 102, 103)))
		END

		IF @ShowSB = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				l.sporttype,
				b.username,
				'' AS Nickname,
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
				l.leagueid,
				b.matchid,
				b.ip,
				b.winlostdate,
				b.currency,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.outright14 AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
			WHERE b.bettype = 10
				AND b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND b.ruben = 1
				AND b.tpositiontaking <> 0
				AND (@ExcludeReject = 0
					OR (@ExcludeReject = 1 AND b.statusID NOT IN (101, 102, 103))) 
		END
	END

	-- Get exchange rate
	DECLARE @Today SMALLDATETIME
 
	SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

	DECLARE @ExFromDate SMALLDATETIME,
		@ExToDate SMALLDATETIME

	SELECT
		@ExFromDate = MIN(WinLostDate),
		@ExToDate = MAX(WinLostDate)
	FROM #Data

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

	SELECT
		@TotalRows		= COUNT(b.TransId),
		@SumWinlost		= SUM(b.WinLost		* ISNULL(e.Rate, 1)),
		@SumLicenseeWL	= SUM(b.LicenseeWL	* ISNULL(e.Rate, 1)),
		@SumComm		= SUM(b.Comm		* ISNULL(e.Rate, 1)),
		@SumPlayerComm	= SUM(b.PlayerComm	* ISNULL(e.Rate, 1))
	FROM #Data AS b
		LEFT JOIN #ExchangeRate AS e
			ON e.ExchangeId = b.Currency
				AND CASE
						WHEN b.WinLostDate > @Today THEN @Today
						ELSE b.WinLostDate
					END BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth

	UPDATE #Data
	SET Nickname = SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2))
	FROM #Data AS b
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON b.CustId = c.custid

	CREATE TABLE #PagingData (
		RowNum			INT,
		SportType		INT,
		Username		NVARCHAR(50),
		Nickname		VARCHAR(50),
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
		BetTeam			NVARCHAR(10),
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

	-- Exchange rate is different for each day => Stake order may be different from StakeUSD order
	IF @Sort LIKE '%Stake%' OR @Sort LIKE '%WinLost%' OR @Sort LIKE '%LicenseeWL%'
	BEGIN
		DECLARE @CharIndex TINYINT

		SELECT @CharIndex = CHARINDEX(' ', @Sort, 1)

		SELECT @Sort = SUBSTRING(@Sort, 0, @CharIndex) + ' * ISNULL(e.Rate, 1)' + SUBSTRING(@Sort, @CharIndex, LEN(@Sort))
	END

	IF @Sort NOT LIKE '%TransId%'
	BEGIN
		SELECT @Sort = @Sort + ', TransId ASC'
	END

	DECLARE @RowStart INT,
		@RowEnd INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	DECLARE @Sql NVARCHAR(1000)

	SET @Sql = 
		'DECLARE @Today SMALLDATETIME

		SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

		SELECT a.*
		FROM
			(
				SELECT
					ROW_NUMBER() OVER (ORDER BY ' + @Sort + ') AS RowNum,
					b.*
				FROM #Data AS b' +
				CASE
					WHEN @Sort LIKE '%e.Rate%' THEN N'
					LEFT JOIN #ExchangeRate AS e
						ON e.ExchangeId = b.Currency
							AND CASE
									WHEN b.WinLostDate > @Today THEN @Today
									ELSE b.WinLostDate
								END BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth'
					ELSE N' '
				END + N'
			) AS a
		WHERE a.RowNum BETWEEN @RowStart AND @RowEnd
		ORDER BY a.RowNum'

	INSERT INTO #PagingData
	EXEC sp_executesql @Sql, N'@RowStart INT, @RowEnd INT', @RowStart, @RowEnd;

	DROP TABLE #Data

	SELECT
		b.RowNum,
		b.SportType,
		b.Username,
		b.Nickname,
		b.CustId,
		b.BetType,
		b.TransId,
		b.MatchCode,
		b.HomeId,
		b.Hdp1,
		b.Hdp2,
		b.Odds,
		b.OddsType,
		b.Status,
		b.Stake * ISNULL(e.Rate, 1) AS Stake,
		b.WinLost * ISNULL(e.Rate, 1) AS WinLost,
		b.LicenseeWL * ISNULL(e.Rate, 1) AS LicenseeWL,
		b.Comm * ISNULL(e.Rate, 1) AS Comm,
		b.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm,
		b.TransDate,
		b.BetTeam,
		b.LiveIndicator,
		b.LiveHomeScore,
		b.LiveAwayScore,
		b.LeagueId,
		b.MatchId, 
		b.Ip,
		b.WinLostDate,
		b.Currency,
		b.ExtraInfo
	FROM #PagingData AS b
		LEFT JOIN #ExchangeRate AS e
			ON e.ExchangeId = b.Currency
				AND CASE
						WHEN b.WinLostDate > @Today THEN @Today
						ELSE b.WinLostDate
					END BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
	ORDER BY b.RowNum ASC

	DROP TABLE #PagingData
	DROP TABLE #ExchangeRate
END
GO
