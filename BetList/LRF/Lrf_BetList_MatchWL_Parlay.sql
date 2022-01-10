/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_MatchWL_Parlay]
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
	@TotalRows		INT				= 0 OUTPUT,
	@SumWinlost		MONEY			= 0 OUTPUT,
	@SumLicenseeWL	MONEY			= 0 OUTPUT,
	@SumComm		MONEY			= 0 OUTPUT,
	@SumPlayerComm	MONEY			= 0 OUTPUT,
	@Sort			NVARCHAR(50)	= N'TransDate ASC'
AS

/*
	Created: Henry@20120111
	Task: Betlist for Parlay
	DB: DBEXT.bodb02
	Original: [Age_BetList_SelWinlossParlay_Ag]
	Revisions:
		- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily
		- 20120319@Henry: show main transid for sub-ticket of System Parlay
		- 20120614@Jim: optimize code
		- 20120724@Jim: add playercomm value
		- 20121004@Jim: replace @currency input param by @currencyID
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20140428@Hannah: Sort betlist
		- 20140516@Hannah: Fix bug Sort betlist
		- 20141111@Winnie: change from LicenseeCust to f_SelLicenseeCust
		- 20150128@Winnie: Add base currency GBP
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160414@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20160516@Kos: Add sorting function [#Redmine: 57433]
		- 20170223@Kos: Support sub licensees [#Redmine: 71679]
		- 20170531@Kos: Prevent data duplication during Move Bet process [#Redmine: 77065]
		- 20170620@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20180205@Kos: Add more condition checking [#Redmine: 90492]
		- 20190521@Kos: Add new input param @BaseCurrency [#Redmine: 112531]
					- Change input param @Sort data type from VARCHAR(100) to NVARCHAR(50)
					- Remove params @SumWinLostUSD, @SumWinLostEUR, @SumWinLostGBP, ...
					- Don't return column IsNeutral, IsBA anymore
		- 20200207@Kos: Support sort by trans time [Redmine: #126886]
		- 20200525@Kos: Support show licensee transaction ID [Redmine: #134629]
		- 20210301@Kos: Add BDT and INR as base currencies [Redmine: 150375]
		- 20210929@Kos: Extend length to support IPv6 [Redmine: 162342]
		- 20220110@Kos: Support TxId for 3rd products [Redmine: #166706]
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

	-- Use local variables to avoid bad params sniffing
	DECLARE @TempFromDate	SMALLDATETIME,
		@TempToDate			SMALLDATETIME

	CREATE TABLE #Data (
		Username		NVARCHAR(50),
		Nickname		VARCHAR(50),
		CustId			INT,
		BetType			SMALLINT,
		RefNo			BIGINT,
		TransId			BIGINT,
		BetId			BIGINT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		Modds			MONEY,
		Status			NVARCHAR(50),
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		TransDate		DATETIME,
		WinLostDate		SMALLDATETIME,
		BetTeam			NVARCHAR(10),
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				VARCHAR(45),
		Currency		SMALLINT,
		AWinLost		MONEY,
		BetCheck		NVARCHAR(50),
		ExtraInfo		VARCHAR(1000)
	)

	CREATE TABLE #ExchangeRate (
		ExchangeId					INT,
		FirstExchangeDateByMonth	SMALLDATETIME,
		LastExchangeDateByMonth		SMALLDATETIME,
		Rate						FLOAT
	)

	IF @ToDate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate =  DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		IF @ShowBA = 1 AND @BetType IN (9, 29)
		BEGIN
			INSERT INTO #Data
			SELECT
				b.username,
				'' AS Nickname,
				b.custid,
				b.bettype,
				b.refno,
				CASE
					WHEN bettype <> 29 THEN b.transid
					ELSE CASE WHEN ISNULL(b.betid, 0) = 0 THEN b.transid ELSE betid END
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
				b.awinlost,
				ISNULL(b.betcheck, '') AS BetCheck,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN #TempAg AS a ON b.recommend = a.CustId
			WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.bettype = @BetType
				AND b.tpositiontaking = 0
				AND b.statusID IN (111, 112, 113)
		END

		IF (@ShowSB = 1 AND @BetType IN (9, 29))
			OR (@ShowVS2 = 1 AND @BetType = 2799)
		BEGIN
			INSERT INTO #Data
			SELECT
				b.username,
				'' AS Nickname,
				b.custid,
				b.bettype,
				b.refno,
				CASE
					WHEN bettype <> 29 THEN b.transid
					ELSE CASE WHEN ISNULL(b.betid, 0) = 0 THEN b.transid ELSE betid END
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
				b.awinlost,
				ISNULL(b.betcheck, '') AS BetCheck,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN #TempAg AS a ON b.recommend = a.CustId
			WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.bettype = @BetType
				AND b.tpositiontaking <> 0
				AND b.statusID IN (111, 112, 113)
		END
	END

	IF @FromDate <= @MoveBetsDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @ToDate

		IF @ShowBA = 1 AND @BetType IN (9, 29)
		BEGIN
			INSERT INTO #Data 
			SELECT
				b.username,
				'' AS Nickname,
				b.custid,
				b.bettype,
				b.refno,
				CASE
					WHEN bettype <> 29 THEN b.transid
					ELSE CASE WHEN ISNULL(b.betid, 0) = 0 THEN b.transid ELSE betid END
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
				b.awinlost,
				ISNULL(b.betcheck, '') AS BetCheck,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN #TempAg AS a ON b.recommend = a.CustId
			WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND b.bettype = @BetType
				AND b.tpositiontaking = 0
				AND b.statusID IN (111, 112, 113)
		END

		IF (@ShowSB = 1 AND @BetType IN (9, 29))
			OR (@ShowVS2 = 1 AND @BetType = 2799)
		BEGIN
			INSERT INTO #Data
			SELECT
				b.username,
				'' AS Nickname,
				b.custid,
				b.bettype,
				b.refno,
				CASE
					WHEN bettype <> 29 THEN b.transid
					ELSE CASE WHEN ISNULL(b.betid, 0) = 0 THEN b.transid ELSE betid END
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
				b.awinlost,
				ISNULL(b.betcheck, '') AS BetCheck,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN #TempAg AS a ON b.recommend = a.CustId
			WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND b.bettype = @BetType
				AND b.tpositiontaking <> 0
				AND b.statusID IN (111, 112, 113)
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
			WHEN @BaseCurrency = 'BDT' THEN e.BDT
			WHEN @BaseCurrency = 'INR' THEN e.INR
			ELSE 1
		END AS Rate
	FROM dbo.Lrf_f_GetSubExchangeDaily(@ExFromDate, @ExToDate) AS e
	WHERE EXISTS (SELECT 1 FROM #Data
				WHERE Currency = e.ExchangeId
					AND WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth)

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
		Username		NVARCHAR(50),
		Nickname		VARCHAR(50),
		CustId			INT,
		BetType			SMALLINT,
		RefNo			BIGINT,
		TransId			BIGINT,
		BetId			BIGINT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		Modds			MONEY,
		Status			NVARCHAR(50),
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		TransDate		DATETIME,
		WinLostDate		SMALLDATETIME,
		BetTeam			NVARCHAR(10),
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				VARCHAR(45),
		Currency		SMALLINT,
		AWinLost		MONEY,
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
		b.Username,
		b.Nickname,
		b.CustId,
		b.BetType,
		b.RefNo,
		b.TransId,
		b.BetId,
		b.Hdp1,
		b.Hdp2,
		b.Odds,
		b.Modds,
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
		b.AWinLost,
		b.BetCheck,
		b.ExtraInfo
	FROM #PagingData AS b
		LEFT JOIN #ExchangeRate AS e
			ON e.ExchangeId = b.Currency
				AND CASE
						WHEN b.WinLostDate > @Today THEN @Today
						ELSE b.WinLostDate
					END BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
	ORDER BY b.RowNum ASC

	DROP TABLE #TempAg
	DROP TABLE #PagingData
	DROP TABLE #ExchangeRate
END
GO
