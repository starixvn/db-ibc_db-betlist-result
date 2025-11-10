/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_LiveReport_SelWinlossParlay]
	@AgentList		VARCHAR(MAX),
	@ProductList	VARCHAR(500),
	@BetType		INT				= 9,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@LiveIndicator	INT				= 1,
	@BaseCurrency	VARCHAR(12),
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 1,
	@SortType		TINYINT			= 0,		-- TransDate
	@SortOrder		TINYINT			= 1,		-- ASC
	@TotalRows		INT				= 0 OUTPUT,
	@SumWinLost		MONEY			= 0 OUTPUT,
	@SumLicenseeWL	MONEY			= 0 OUTPUT,
	@SumComm		MONEY			= 0 OUTPUT,
	@SumPlayerComm	MONEY			= 0 OUTPUT
AS

/*
	Created: Henry@20120111
	Task: LAP - Live Report - Betlist for Parlay
	DB: DBEXT.bodb02
	Param's Explanation:
		- @LiveIndicator:
			- 0: Non-Live ticket only
			- 1: Live ticket only
			- 2: All
		- @SortType:
			- 0: TransDate
			- 1: Stake
			- 2: WinLoss
			- 3: LicenseeWL
		- @SortOrder
			- 1: ASC
			- 2: DESC

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
		- 20210301@Kos: Add BDT and INR as base currencies [Redmine: 150375]
		- 20210929@Kos: Extend length to support IPv6 [Redmine: 162342]
		- 20220110@Kos: Support TxId for 3rd products [Redmine: #166706]
		- 20230922@Kos: Support crypto currency [Redmine: 177481]
		- 20240129@Kos: Merge VS1, VS2, VS3 into VS [Redmine: 199523]
					- Remove input params @ShowSB, @ShowVS2
					- Add new input param @ProductList VARCHAR(500)
		- 20240527@Kos: Hotfix - support paging [Redmine: #204955]
				- Add new params @TotalRows INT, @SumWinLost MONEY, @SumLicenseeWL MONEY, @SumComm MONEY, @SumPlayerComm MONEY
		- 20250225@Kos: Fix bug FLOAT rounding [#Redmine: 194970]
		- 20250313@Kos: Remove BA [RedmineID: #216882]
					- Remove input param @ShowBA
		- 20250702@Kos: Fix security issue in dynamic query [#Redmine: 227496]
					- Remove input param @Sort
					- Add new input params @SortType TINYINT, @SortOrder TINYINT
		- 20251028@Kelvin: Integrate - Jacktime - Basketball Main Bettype Hybrid Parlay [#Redmine: 242357]
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

	-- Get group bettype
	DECLARE @GroupBetType TABLE (BetType INT, GroupTypeId INT)

	INSERT INTO @GroupBetType (BetType, GroupTypeId)
	SELECT
		bettype,
		GroupTypeId
	FROM dbo.Lrf_f_GroupBettype()

	-- Get child product list
	IF EXISTS (SELECT 1 FROM dbo.Lrf_f_GroupProduct() WHERE ',' + @ProductList + ',' LIKE '%,' + GroupProductPrefix + ',%')
	BEGIN
		DECLARE @ChildProductList VARCHAR(500)

		SELECT @ChildProductList = STRING_AGG(ProductPrefix, ',')
		FROM dbo.Lrf_f_GroupProduct()
		WHERE ',' + @ProductList + ',' LIKE '%,' + GroupProductPrefix + ',%'

		SET @ProductList = @ProductList + ',' + @ChildProductList
	END

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductId TINYINT, BetType SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype (ProductId, BetType, EventType)
	SELECT s.ProductID, s.BetType, s.EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @ProductList, @IsTest) AS s
	WHERE (s.BetType = @BetType
			OR EXISTS (SELECT 1 FROM @GroupBetType WHERE GroupTypeId = @BetType AND BetType = s.BetType))
		AND s.BetType NOT IN (901, 902, 903, 904)
		AND s.BetType NOT BETWEEN 801 AND 899

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
		Ip				VARCHAR(45),
		Currency		SMALLINT,
		BetCheck		NVARCHAR(50),
		ExtraInfo		VARCHAR(1000),
		TransDesc		NVARCHAR(1000),
		OddsSpread		MONEY
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

		INSERT INTO #AgWinlossMP (
			Username, CustId, BetType, RefNo, TransId, BetId, Hdp1, Hdp2, Odds, MOdds,
			Status, Stake, Actual_Stake, WinLost, LicenseeWL, Comm, PlayerComm, TransDate, WinLostDate, BetTeam,
			LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, Currency, BetCheck, ExtraInfo, TransDesc, OddsSpread
		)
		SELECT
			b.username,
			b.custid,
			b.bettype,
			b.refno,
			b.transid,
			ISNULL(b.betid, 0),
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
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
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			ISNULL(b.transdesc, '') AS TransDesc,
			ISNULL(b.OddsSpread, 0) AS OddsSpread
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN #TempAg AS a ON a.CustId = b.recommend
			INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
		WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
			AND b.statusID IN (111, 112, 113)
			AND ((@LiveIndicator = 0 AND b.livehomescore = 0)
				OR (@LiveIndicator = 1 AND b.livehomescore = 1)
				OR (@LiveIndicator = 2))
	END

	IF @Fromdate <= @MoveBetsDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @ToDate

		INSERT INTO #AgWinlossMP (
			Username, CustId, BetType, RefNo, TransId, BetId, Hdp1, Hdp2, Odds, MOdds,
			Status, Stake, Actual_Stake, WinLost, LicenseeWL, Comm, PlayerComm, TransDate, WinLostDate, BetTeam,
			LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, Currency, BetCheck, ExtraInfo, TransDesc, OddsSpread
		)
		SELECT
			b14.username,
			b14.custid,
			b14.bettype,
			b14.refno,
			b14.transid,
			ISNULL(b14.betid, 0),
			b14.hdp1,
			b14.hdp2,
			b14.odds,
			b14.modds,
			b14.status,
			b14.stake,
			b14.actual_stake,
			(b14.winlost - b14.actual_stake) AS WinLost,
			- (b14.winlost - b14.actual_stake) AS LicenseeWL,
			b14.comm,
			b14.playercomm,
			b14.transdate,
			b14.winlostdate,
			b14.betteam,
			b14.liveindicator,
			b14.livehomescore,
			b14.liveawayscore,
			b14.ip,
			b14.currency,
			ISNULL(b14.betcheck, '') AS BetCheck,
			ISNULL(b14.ExtraInfo, '') AS ExtraInfo,
			ISNULL(b14.transdesc, '') AS TransDesc,
			ISNULL(b14.OddsSpread, 0) AS OddsSpread
		FROM dbo.bettrans14 AS b14 WITH (NOLOCK)
			INNER JOIN #TempAg AS a ON a.CustId = b14.recommend
			INNER JOIN @SportBettype AS s ON s.BetType = b14.bettype
		WHERE b14.winlostdate BETWEEN @FromDate AND @TempToDate
			AND b14.statusID IN (111, 112, 113)
			AND ((@LiveIndicator = 0 AND b14.livehomescore = 0)
				OR (@LiveIndicator = 1 AND b14.livehomescore = 1)
				OR (@LiveIndicator = 2))
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

	INSERT INTO #ExchangeRate (ExchangeId, FirstExchangeDateByMonth, LastExchangeDateByMonth, Rate)
	SELECT
		e.ExchangeId,
		e.FromDate,
		e.ToDate,
		e.Rate
	FROM dbo.Lrf_f_GetExchangeRate(@ExFromDate, @ExToDate, @BaseCurrency, '') AS e
	WHERE EXISTS (SELECT 1 FROM #AgWinlossMP
				WHERE Currency = e.ExchangeId
					AND WinLostDate BETWEEN e.FromDate AND e.ToDate)

	-- Return data
	SELECT
		@TotalRows		= COUNT(b.TransId),
		@SumWinlost		= SUM(b.WinLost * ISNULL(e.Rate, 1)),
		@SumLicenseeWL	= SUM(b.LicenseeWL * ISNULL(e.Rate, 1)),
		@SumComm		= SUM(b.Comm * ISNULL(e.Rate, 1)),
		@SumPlayerComm	= SUM(b.PlayerComm * ISNULL(e.Rate, 1))
	FROM #AgWinlossMP AS b
		LEFT JOIN #ExchangeRate AS e
			ON e.ExchangeId = b.Currency
				AND b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth

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
		Ip				VARCHAR(45),
		Currency		SMALLINT,
		BetCheck		NVARCHAR(50),
		ExtraInfo		VARCHAR(1000),
		TransDesc		NVARCHAR(1000),
		OddsSpread		MONEY
	)

	DECLARE @SortText VARCHAR(100)

	-- Get sort text
	SET @SortText = CASE
						WHEN @SortType = 0 THEN 'TransDate'
						WHEN @SortType = 1 THEN 'Stake'
						WHEN @SortType = 2 THEN 'WinLost'
						WHEN @SortType = 3 THEN 'LicenseeWL'
						ELSE ''
					END

	IF @BaseCurrency <> '' AND @SortType IN (1, 2, 3)
	BEGIN
		SET @SortText = @SortText + ' * ISNULL(e.Rate, 1)'
	END

	SET @SortText = @SortText + ' ' + CASE
										WHEN @SortOrder = 1 THEN 'ASC'
										WHEN @SortOrder = 2 THEN 'DESC'
										ELSE ''
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

		SELECT	a.*
		FROM
			(
				SELECT
					ROW_NUMBER() OVER (ORDER BY ' + @SortText + ') AS RowNum,
					b.*
				FROM #AgWinlossMP AS b' +
				CASE
					WHEN @SortText LIKE '%e.Rate%' THEN N'
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
		ORDER BY a.RowNum ASC'

	INSERT INTO #PagingData
	(
		RowNum, Username, CustId, BetType, RefNo, TransId, BetId, Hdp1, Hdp2, Odds,
		MOdds, Status, Stake, Actual_Stake, WinLost, LicenseeWL, Comm, PlayerComm, TransDate, WinLostDate,
		BetTeam, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, Currency, BetCheck, ExtraInfo, TransDesc, OddsSpread
	)
	EXEC sp_executesql @Sql, N'@RowStart INT, @RowEnd INT', @RowStart, @RowEnd;

	DROP TABLE #AgWinlossMP

	SELECT
		p.RowNum,
		p.Username,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$',c.username2)) AS Nickname,
		p.CustId,
		p.BetType,
		p.RefNo,
		p.TransId,
		p.BetId,
		p.Hdp1,
		p.Hdp2,
		p.Odds,
		p.MOdds,
		p.Status,
		CAST(p.Stake * ISNULL(e.Rate, 1) AS MONEY) AS Stake,
		CAST(p.Actual_Stake * ISNULL(e.Rate, 1) AS MONEY) AS Actual_Stake,
		CAST(p.WinLost * ISNULL(e.Rate, 1) AS MONEY) AS WinLost,
		CAST(p.LicenseeWL * ISNULL(e.Rate, 1) AS MONEY) AS LicenseeWL,
		CAST(p.Comm * ISNULL(e.Rate, 1) AS MONEY) AS Comm,
		CAST(p.PlayerComm * ISNULL(e.Rate, 1) AS MONEY) AS PlayerComm,
		p.TransDate,
		p.WinLostDate,
		p.BetTeam,
		p.LiveIndicator,
		p.LiveHomeScore,
		p.LiveAwayScore,
		p.Ip,
		p.Currency,
		p.BetCheck,
		p.ExtraInfo,
		p.TransDesc,
		p.OddsSpread
	FROM #PagingData AS p
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = p.custid
		LEFT JOIN #ExchangeRate AS e
			ON e.ExchangeId = p.Currency
				AND CASE
						WHEN p.WinLostDate > @Today THEN @Today
						ELSE p.WinLostDate
					END BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
	ORDER BY p.RowNum ASC

	DROP TABLE #TempAg
	DROP TABLE #PagingData
	DROP TABLE #ExchangeRate
END
GO
