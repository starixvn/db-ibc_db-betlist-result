/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet,wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_LiveReport_SelWinlossVHRacing]
	@AgentList		VARCHAR(MAX),
	@SportType		INT				= 181,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BaseCurrency	VARCHAR(12),
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 1,
	@Sort			NVARCHAR(50)	= N'TransDate ASC',
	@SumWL			MONEY			= 0 OUTPUT,
	@SumLicenseeWL	MONEY			= 0 OUTPUT
AS

/*
	Created: Jim@20130912
	Task: Betlist VHR for Live Report
	DB: DBEXT.bodb02
	Original: 
	Revisions:
		- 20140520@Hannah: Sort betlist
		- 20140522@Hannah: fix bug Sort betlist
		- 20141111@Winnie: change from LicenseeCust to f_SelLicenseeCust 
		- 20150126@Winnie: Add base currency GBP
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20161004@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20170306@Kos: Support sub licensees [#Redmine: 71679]
		- 20190527@Kos: Add new input param @BaseCurrency [#Redmine: 112531]
					- Remove params @SUMWLUSD, @SUMLicenseeWLUSD, @SUMWLEUR, ...
					- Don't return column AwayId, IsNeutral, BetStatus, Betteam, LiveIndicator, Discount, PlayerDiscount, APositiontaking anymore
					- Change input param @Sort data type from VARCHAR(20) to NVARCHAR(50)
		- 20200207@Kos: Support sort by trans time [Redmine: #126886]
		- 20200623@Kos: Integrate archive process for table VSRaceInfo [Redmine: #136285]
		- 20210301@Kos: Add BDT and INR as base currencies [Redmine: 150375]
		- 20210929@Kos: Extend length to support IPv6 [Redmine: 162342]
		- 20220110@Kos: Support TxId for 3rd products [Redmine: #166706]
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

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE (ProductId TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (5, 0, 0, 2, '', '', @IsTest)
	WHERE EventType = 3

	CREATE TABLE #Data (
		CustId			INT,
		Username		NVARCHAR(50),
		Recommend		INT,
		TransId			BIGINT,
		RefNo			BIGINT,
		SportType		SMALLINT,
		BetType			SMALLINT,
		Race			VARCHAR(50),
		MatchCode		VARCHAR(50),
		HomeId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Modds			MONEY,
		Odds			MONEY,
		Status			NVARCHAR(50),
		Stake			MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		TransDate		DATETIME,
		WinLostDate		SMALLDATETIME,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LeagueId		INT,
		MatchId			INT,
		Ip				VARCHAR(45),
		Currency		SMALLINT,
		ShowTime		DATETIME,
		ExtraInfo		VARCHAR(1000)
	)

	DECLARE @TempFromDate	DATETIME,
		@TempToDate			DATETIME

	IF @ToDate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate =  DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		INSERT INTO #Data
		SELECT
			b.custid,
			b.username,
			b.recommend,
			b.transid,
			b.refno,
			r.SportType,
			b.bettype,
			b.oddsid AS Race,
			CONVERT(VARCHAR(50), o.RacerNum) AS MatchCode,
			o.RacerID AS HomeId,
			b.hdp1,
			b.hdp2,
			b.modds,
			b.odds,
			b.status,
			b.stake,
			(b.winlost - b.actual_stake) AS WinLost,
			-(b.winlost - b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.transdate,
			b.winlostdate,
			b.livehomescore,
			b.liveawayscore,
			r.LeagueID,
			o.EventID AS MatchId,
			b.ip,
			b.currency,
			r.EventTime,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @TempAg AS t ON b.recommend = t.CustId
			INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON b.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
			AND r.SportType = @SportType
			AND b.statusID IN (111, 112, 113)
	END

	IF @FromDate <= @MoveBetsDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @ToDate

		INSERT INTO #Data
		SELECT
			b.custid,
			b.username,
			b.recommend,
			b.transid,
			b.refno,
			r.SportType,
			b.bettype,
			b.oddsid AS Race,
			CONVERT(VARCHAR(50), o.RacerNum) AS MatchCode,
			o.RacerID AS HomeId,
			b.hdp1,
			b.hdp2,
			b.modds,
			b.odds,
			b.status,
			b.stake,
			(b.winlost - b.actual_stake) AS WinLost,
			-(b.winlost - b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.transdate,
			b.winlostdate,
			b.livehomescore,
			b.liveawayscore,
			r.LeagueID,
			o.EventID AS MatchId,
			b.ip,
			b.currency,
			r.EventTime,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN @TempAg AS t ON b.recommend = t.CustId
			INNER JOIN dbo.VSOutright14 AS o WITH (NOLOCK) ON b.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo14 AS r WITH (NOLOCK) ON r.EventID = o.EventID
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
			AND r.SportType = @SportType
			AND b.statusID IN (111, 112, 113)
	END

	DELETE b
	FROM #Data AS b
	WHERE NOT EXISTS (SELECT 1 FROM @TempAg WHERE CustId = b.Recommend AND Currency = b.Currency)

	-- Get exchange rate
	CREATE TABLE #ExchangeRate (
		ExchangeId					INT,
		FirstExchangeDateByMonth	SMALLDATETIME,
		LastExchangeDateByMonth		SMALLDATETIME,
		Rate						FLOAT
	)

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

	-- Return data
	SELECT
		@SumWL			= SUM(b.WinLost		* ISNULL(e.Rate, 1)),
		@SumLicenseeWL	= SUM(b.LicenseeWL	* ISNULL(e.Rate, 1))
	FROM #Data AS b
		LEFT JOIN #ExchangeRate AS e
			ON e.ExchangeId = b.Currency
				AND b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth

	CREATE TABLE #PagingData (
		RowNum			INT,
		CustId			INT,
		Username		NVARCHAR(50),
		Recommend		INT,
		TransId			BIGINT,
		RefNo			BIGINT,
		SportType		SMALLINT,
		BetType			SMALLINT,
		Race			VARCHAR(50),
		MatchCode		VARCHAR(50),
		HomeId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Modds			MONEY,
		Odds			MONEY,
		Status			NVARCHAR(50),
		Stake			MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		TransDate		DATETIME,
		WinLostDate		SMALLDATETIME,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LeagueId		INT,
		MatchId			INT,
		Ip				VARCHAR(45),
		Currency		SMALLINT,
		ShowTime		DATETIME,
		ExtraInfo		VARCHAR(1000)
	)

	-- Exchange rate is different for each day => Stake order may be different from StakeUSD order
	IF @Sort LIKE '%Stake%' OR @Sort LIKE '%WinLost%' OR @Sort LIKE '%LicenseeWL%'
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

	DECLARE @Sql NVARCHAR(1000)

	SET @Sql = 
		'SELECT a.*
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
							AND b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth'
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
		b.CustId,
		b.Username,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$',c.username2)) AS Nickname,
		b.Recommend,
		b.TransId,
		b.RefNo,
		b.SportType,
		b.BetType,
		b.Race,
		b.MatchCode,
		b.HomeId,
		b.Hdp1,
		b.Hdp2,
		b.Modds,
		b.Odds,
		b.Status,
		b.Stake * ISNULL(e.Rate, 1) AS Stake,
		b.WinLost * ISNULL(e.Rate, 1) AS WinLost,
		b.LicenseeWL * ISNULL(e.Rate, 1) AS LicenseeWL,
		b.Comm * ISNULL(e.Rate, 1) AS Comm,
		b.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm,
		b.TransDate,
		b.WinLostDate,
		b.LiveHomeScore,
		b.LiveAwayScore,
		b.LeagueId,
		b.MatchId,
		b.Ip,
		b.Currency,
		b.ShowTime,
		b.ExtraInfo
	FROM #PagingData AS b
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = b.custid
		LEFT JOIN #ExchangeRate AS e
			ON e.ExchangeId = b.Currency
				AND b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
	ORDER BY b.RowNum

	-- Get ticket detail
	DECLARE @Bettransm TABLE(
		RefNo			BIGINT,
		FinalOdds		MONEY,
		Odds			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		BetType			SMALLINT
	)

	IF @ToDate > @MoveBetsDay
	BEGIN
		INSERT INTO @Bettransm
		SELECT
			bm.refno,
			bm.finalodds,
			bm.odds,
			bm.status,
			bm.apositiontaking,
			bm.bettype
		FROM dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN #PagingData AS b ON bm.refno = b.refno AND bm.custid = b.custid
			INNER JOIN @SportBettype AS sbt ON sbt.Bettype = bm.bettype
			LEFT JOIN #ExchangeRate AS e
				ON e.ExchangeId = b.Currency
					AND b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
	END
	
	IF @FromDate <= @MoveBetsDay
	BEGIN
		INSERT INTO @Bettransm
		SELECT
			bm.refno,
			bm.finalodds,
			bm.odds,
			bm.status,
			bm.apositiontaking,
			bm.bettype
		FROM dbo.bettransm14 AS bm WITH (NOLOCK)
			INNER JOIN #PagingData AS b ON bm.refno = b.refno AND bm.custid = b.custid
			INNER JOIN @SportBettype AS sbt ON sbt.Bettype = bm.bettype
			LEFT JOIN #ExchangeRate AS e
				ON e.ExchangeId = b.Currency
					AND b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
	END

	SELECT DISTINCT * FROM @Bettransm
	ORDER BY RefNo ASC, Bettype ASC

	DROP TABLE #PagingData
	DROP TABLE #ExchangeRate
END
GO
