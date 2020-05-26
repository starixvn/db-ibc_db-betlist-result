/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_LiveReport_SelWinlossParlay]
	@AgentList		VARCHAR(MAX),
	@BetType		INT				= 9,
	@ShowBA			BIT				= 0,
	@ShowSB			BIT				= 0,
	@ShowVS2		BIT				= 0,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BaseCurrency	VARCHAR(10),
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 1,
	@Sort			NVARCHAR(50)	= 'TransDate ASC',
	@LiveIndicator	INT				= 1
AS

/*
	Created: Henry@20120111
	Task: Betlist for Parlay
	DB: DBEXT.bodb02
	Original: [Age_BetList_SelWinlossParlay_Ag]
	Revisions:
		- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily
		- 20120319@Henry: show main transid for sub-ticket of system parlay 
		- 20120614@Jim: optimize code
		- 20120724@Jim: add playercomm value
		- 20121004@Jim: replace @currency input param by @currencyID
		- 20130305@Jim: remove Grand total row in the result data
		- 20130404@Jim: set default @ShowBA=0
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20130625@Jim: Support to view currency UUS
		- 20140520@Hannah: Sort betlist
		- 20140602@Hannah: Separate Live/ Non - Live data in Live Report
		- 20141111@Winnie: Change from LicenseeCust to f_SelLicenseeCust
		- 20150126@Winnie: Add base currency GBP
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160413@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20170306@Kos: Support sub licensees [#Redmine: 71679]
		- 20170531@Kos: Prevent data duplication during Move Bet process [#Redmine: 77065]
		- 20170620@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20180205@Kos: Add more condition checking [#Redmine: 90492]
		- 20190521@Kos: Add new input param @BaseCurrency [#Redmine: 112531]
					- Change input param @Sort data type from VARCHAR(100) to NVARCHAR(50)
					- Don't return column IsNeutral, IsBA anymore
		- 20200207@Kos: Support sort by trans time [Redmine: #126886]
		- 20200525@Kos: Support show licensee transaction ID [Redmine: #134629]

	Param's Explanation:
		@LiveIndicator : indicate that whether the report will get live data or not
			+ 0: Non - Live data only
			+ 1: Live data only
			+ 2: All
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

	CREATE TABLE #AgWinlossMP (
		Username		NVARCHAR(50),
		CustId			INT,
		BetType			SMALLINT,
		RefNo			BIGINT,
		TransId			BIGINT,
		BetId			BIGINT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		MOdds			MONEY,
		Status			NVARCHAR(50),
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		BetTeam			NVARCHAR(25),
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				VARCHAR(30),
		Currency		SMALLINT,
		BetCheck		NVARCHAR(50),
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

	IF @Todate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate =  DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		IF @ShowBA = 1 AND @BetType IN (9, 29)
		BEGIN
			INSERT INTO #AgWinlossMP
			SELECT
				b.username,
				b.custid,
				b.bettype,
				b.refno,
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE CASE WHEN ISNULL(b.betid, 0) = 0 THEN b.transid ELSE b.betid END
				END AS transid,
				ISNULL(b.betid, 0),
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				b.status,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				b.currency,
				ISNULL(b.betcheck, '') AS BetCheck,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo
			FROM dbo.bettrans AS b WITH (NOLOCK)
			WHERE
				b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.bettype = @BetType
				AND b.tpositiontaking = 0
				AND b.statusID IN (111, 112, 113)
				AND ((@LiveIndicator = 0 AND b.livehomescore = 0)
					OR (@LiveIndicator = 1 AND b.livehomescore = 1)
					OR (@LiveIndicator = 2))
		END

		IF (@ShowSB = 1 AND @BetType IN (9, 29))
			OR (@ShowVS2 = 1 AND @BetType = 2799)
		BEGIN
			INSERT INTO #AgWinlossMP
			SELECT
				b.username,
				b.custid,
				b.bettype,
				b.refno,
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE CASE WHEN ISNULL(b.betid, 0) = 0 THEN b.transid ELSE b.betid END
				END AS transid,
				ISNULL(b.betid, 0),
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				b.status,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				 -(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				b.currency,
				ISNULL(b.betcheck, '') AS BetCheck,
				CASE
					WHEN b.bettype IN (9, 29) THEN ISNULL(b.ExtraInfo, '')
					ELSE ''
				END AS ExtraInfo
			FROM dbo.bettrans AS b WITH (NOLOCK)
			WHERE
				b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.bettype = @BetType
				AND b.tpositiontaking <> 0
				AND b.statusID IN (111, 112, 113)
				AND ((@LiveIndicator = 0 AND b.livehomescore = 0)
					OR (@LiveIndicator = 1 AND b.livehomescore = 1)
					OR (@LiveIndicator = 2))
		END
	END

	IF @Fromdate <= @MoveBetsDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @ToDate

		IF @ShowBA = 1 AND @BetType IN (9, 29)
		BEGIN
			INSERT INTO #AgWinlossMP
			SELECT
				b.username,
				b.custid,
				b.bettype,
				b.refno,
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE CASE WHEN ISNULL(b.betid, 0) = 0 THEN b.transid ELSE b.betid END
				END AS transid,
				ISNULL(b.betid, 0),
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				b.status,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				b.currency,
				ISNULL(b.betcheck, '') AS BetCheck,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
			WHERE
				b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND b.bettype = @BetType
				AND b.tpositiontaking = 0
				AND b.statusID IN (111, 112, 113)
				AND ((@LiveIndicator = 0 AND b.livehomescore = 0)
					OR (@LiveIndicator = 1 AND b.livehomescore = 1)
					OR (@LiveIndicator = 2))
		END

		IF (@ShowSB = 1 AND @BetType IN (9, 29))
			OR (@ShowVS2 = 1 AND @BetType = 2799)
		BEGIN
			INSERT INTO #AgWinlossMP
			SELECT
				b.username,
				b.custid,
				b.bettype,
				b.refno,
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE CASE WHEN ISNULL(b.betid, 0) = 0 THEN b.transid ELSE b.betid END
				END AS transid,
				ISNULL(b.betid, 0),
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				b.status,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				 -(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				b.currency,
				ISNULL(b.betcheck, '') AS BetCheck,
				CASE
					WHEN b.bettype IN (9, 29) THEN ISNULL(b.ExtraInfo, '')
					ELSE ''
				END AS ExtraInfo
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
			WHERE
				b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND b.bettype = @BetType
				AND b.tpositiontaking <> 0
				AND b.statusID IN (111, 112, 113)
				AND ((@LiveIndicator = 0 AND b.livehomescore = 0)
					OR (@LiveIndicator = 1 AND b.livehomescore = 1)
					OR (@LiveIndicator = 2))
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
	FROM #AgWinlossMP

	INSERT INTO #ExchangeRate
	SELECT
		e.ExchangeId,
		e.FirstExchangeDateByMonth,
		e.LastExchangeDateByMonth,
		CASE
			WHEN @BaseCurrency = 'MYR' THEN e.MYR
			WHEN @BaseCurrency = 'USD' THEN e.USD
			WHEN @BaseCurrency = 'EUR' THEN e.EUR
			WHEN @BaseCurrency = 'CNY' THEN e.CNY
			WHEN @BaseCurrency = 'IDR' THEN e.IDR
			WHEN @BaseCurrency = 'GBP' THEN e.GBP
			WHEN @BaseCurrency = 'THB' THEN e.THB
			WHEN @BaseCurrency = 'INH' THEN e.INH
			ELSE 1
		END AS Rate
	FROM dbo.Lrf_f_GetSubExchangeDaily(@ExFromDate, @ExToDate) AS e
	WHERE EXISTS (SELECT 1 FROM #AgWinlossMP
				WHERE Currency = e.ExchangeId
					AND WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth)

	CREATE TABLE #PagingData (
		RowNum			INT,
		Username		NVARCHAR(50),
		CustId			INT,
		BetType			SMALLINT,
		RefNo			BIGINT,
		TransId			BIGINT,
		BetId			BIGINT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		MOdds			MONEY,
		Status			NVARCHAR(50),
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		BetTeam			NVARCHAR(25),
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				VARCHAR(30),
		Currency		SMALLINT,
		BetCheck		NVARCHAR(50),
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
				FROM #AgWinlossMP AS b' +
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

	DROP TABLE #AgWinlossMP

	SELECT
		b.RowNum,
		b.Username,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$',c.username2)) AS Nickname,
		b.CustId,
		b.BetType,
		b.RefNo,
		b.TransId,
		b.BetId,
		b.Hdp1,
		b.Hdp2,
		b.Odds,
		b.MOdds,
		b.Status,
		b.Stake * ISNULL(e.Rate, 1) AS Stake,
		b.Actual_Stake * ISNULL(e.Rate, 1) AS Actual_Stake,
		b.WinLost * ISNULL(e.Rate, 1) AS WinLost,
		b.LicenseeWL * ISNULL(e.Rate, 1) AS LicenseeWL,
		b.Comm * ISNULL(e.Rate, 1) AS Comm,
		b.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm,
		b.TransDate,
		b.WinLostDate,
		b.BetTeam,
		b.LiveIndicator,
		b.LiveHomeScore,
		b.LiveAwayScore,
		b.Ip,
		b.Currency,
		b.BetCheck,
		b.ExtraInfo
	FROM #PagingData AS b
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = b.custid
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



GRANT EXECUTE ON [dbo].[Lrf_BetList_LiveReport_SelWinlossParlay] TO [bodbLicenseeNet]
GO
