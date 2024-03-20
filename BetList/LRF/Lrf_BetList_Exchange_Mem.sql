/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet,wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_Exchange_Mem]
	@AgentList			VARCHAR(MAX),
	@CustId				INT,
	@FromDate			DATETIME,
	@ToDate				DATETIME,
	@DateOption			TINYINT		= 1,
	@ViewResettledOnly	BIT			= 0,
	@BaseCurrency		VARCHAR(12),
	@SumWinLost			MONEY		= 0 OUTPUT
AS

/*
	Created: Kos@20180301
	Task: Bet list detail for Exchange
	DB: DBEXT.bodb02

	Revisions:
		- 20180302@Kos: First revision [#Redmine: 91048]
		- 20190625@Kos: Add new input param @BaseCurrency [#Redmine: 112531]
					- Remove params @SumWinLostUSD, @SumWinLostEUR, @SumWinLostGBP, ...
		- 20200827@Kos: Support Fancy Bet [#Redmine: 138524]
		- 20210301@Kos: Add BDT and INR as base currencies [Redmine: 150375]
		- 20220922@Kos: Support crypto currency [Redmine: 177481]
		- 20221117@Kos: Support filter by resettled date [Redmine: 179079]
					- Add new input param @DateOption TINYINT
		- 20231006@Kos: Support view resettled ticket only [Redmine: 193954]
		- 20231213@Kos: Hotfix - inconsistent odds [Redmine: 198327]
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
			ErrMsg = N'Paramrter invalid.'

		RETURN
	END CATCH

	DECLARE @Data AS TABLE (
		UserId			VARCHAR(16),
		EventTypeName	VARCHAR(50),
		EventId			INT,
		EventName		VARCHAR(500),
		MarketId		VARCHAR(50),
		MarketName		VARCHAR(500),
		SettledDate		DATETIME,
		WinLostDate		DATETIME,
		WinLost			MONEY,
		Commission		MONEY,
		Currency		TINYINT,
		ExVirtualRate	FLOAT
	)

	DECLARE @Detail AS TABLE (
		BetId			BIGINT,
		UserId			VARCHAR(16),
		CategoryType	SMALLINT,
		EventTypeName	VARCHAR(50),
		EventId			INT,
		EventName		VARCHAR(500),
		MarketId		VARCHAR(50),
		MarketName		VARCHAR(500),
		SelectionId		INT,
		SelectionName	VARCHAR(100),
		Type			VARCHAR(10),
		BetPlaced		DATETIME,
		WinLostDate		DATETIME,
		Currency		TINYINT,
		OddsAvg			SMALLMONEY,
		FancyBetRuns	MONEY,
		Stake			MONEY,
		WinLost			MONEY
	)

	DECLARE @TempToDate	DATETIME

	SET @TempToDate = DATEADD(MILLISECOND, -2, DATEADD(DAY, DATEDIFF(DAY, -1, @ToDate), 0))

	IF @DateOption = 1		-- Filter by settled date
	BEGIN
		INSERT INTO @Data
		SELECT
			b.userId,
			b.eventTypeName,
			b.eventID,
			b.eventName,
			b.marketID,
			b.marketName,
			b.settledDate,
			DATEADD(DAY, 0, DATEDIFF(DAY, 0, b.settledDate)) AS WinLostDate,
			b.marketTotal / b.ExVirtualRate AS WinLost,
			b.commission / b.ExVirtualRate AS Commission,
			b.Currency,
			b.ExVirtualRate
		FROM bodb_3rdProduct.dbo.Sum_winloss_Exchange AS b WITH (NOLOCK)
		WHERE b.CustID = @CustId
			AND b.settledDate BETWEEN @FromDate AND @TempToDate
			AND 1 = CASE
						WHEN @ViewResettledOnly = 0 THEN 1
						WHEN ISNULL(b.IsResettled, 0) = 1 THEN 1
						ELSE 0
					END
	END
	ELSE		-- Filter by resettled date
	BEGIN
		INSERT INTO @Data
		SELECT
			b.userId,
			b.eventTypeName,
			b.eventID,
			b.eventName,
			b.marketID,
			b.marketName,
			b.settledDate,
			DATEADD(DAY, 0, DATEDIFF(DAY, 0, b.settledDate)) AS WinLostDate,
			b.marketTotal / b.ExVirtualRate AS WinLost,
			b.commission / b.ExVirtualRate AS Commission,
			b.Currency,
			b.ExVirtualRate
		FROM bodb_3rdProduct.dbo.Sum_winloss_Exchange AS b WITH (NOLOCK)
		WHERE b.CustID = @CustId
			AND ISNULL(b.resettledDate, b.settledDate) BETWEEN @FromDate AND @TempToDate
			AND 1 = CASE
						WHEN @ViewResettledOnly = 0 THEN 1
						WHEN ISNULL(b.IsResettled, 0) = 1 THEN 1
						ELSE 0
					END
	END

	DELETE @Data
	WHERE Currency NOT IN (SELECT DISTINCT Currency FROM @TempAg)

	INSERT INTO @Detail
	SELECT
		b.betID,
		b.userId,
		b.categoryType,
		b.eventTypeName,
		b.eventID,
		b.eventName,
		b.marketID,
		b.marketName,
		b.selectionID,
		b.selectionName,
		b.matchType AS Type,
		b.betPlaced,
		s.WinLostDate,
		s.Currency,
		b.matchAvgOdds AS OddsAvg,
		ISNULL(bm.txFancyBetRuns, b.fancyBetRuns) AS fancyBetRuns,
		b.matchStake / s.ExVirtualRate AS Stake,
		b.profitLoss / s.ExVirtualRate AS WinLost
	FROM bodb_3rdProduct.dbo.Bettrans_Exchange AS b WITH (NOLOCK)
		INNER JOIN @Data AS s
			ON b.userId = s.userId
				AND b.eventID = s.eventID
				AND b.marketID = s.marketID
		LEFT JOIN bodb_3rdProduct.dbo.BettransM_Exchange AS bm WITH (NOLOCK) ON b.betID = bm.BetID

	DECLARE @FDate	DATETIME,
		@TDate		DATETIME

	SELECT
		@FDate = MIN(WinLostDate),
		@TDate = MAX(WinLostDate)
	FROM @Data

	DECLARE @ExchangeRate TABLE (
		FirstExchangeDateByMonth	SMALLDATETIME,
		LastExchangeDateByMonth		SMALLDATETIME,
		Rate						FLOAT
	)

	DECLARE @Currency	INT

	SELECT @Currency = currency
	FROM dbo.Customer WITH (NOLOCK)
	WHERE custid = @CustId

	-- Get exchange rate
	INSERT INTO @ExchangeRate
	SELECT
		e.FromDate,
		e.ToDate,
		e.Rate
	FROM dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @BaseCurrency, '') AS e
	WHERE e.ExchangeId = @Currency
		AND EXISTS (SELECT 1 FROM @Data WHERE WinLostDate BETWEEN e.FromDate AND e.ToDate)

	SELECT @SumWinLost = SUM(ISNULL(b.WinLost, 0) * ISNULL(e.Rate, 1) + ISNULL(b.Commission, 0) * ISNULL(e.Rate, 1))
	FROM @Data AS b
		LEFT JOIN @ExchangeRate AS e ON b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth

	SELECT
		b.UserId,
		b.EventTypeName,
		b.EventId,
		b.EventName,
		b.MarketId,
		b.MarketName,
		b.SettledDate,
		b.WinLostDate,
		b.WinLost * ISNULL(e.Rate, 1) AS WinLost,
		b.Commission * ISNULL(e.Rate, 1) AS Commission,
		b.Currency,
		b.ExVirtualRate
	FROM @Data AS b
		LEFT JOIN @ExchangeRate AS e ON b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth

	SELECT
		b.BetId,
		b.UserId,
		b.CategoryType,
		b.EventTypeName,
		b.EventId,
		b.EventName,
		b.MarketId,
		b.MarketName,
		b.SelectionId,
		b.SelectionName,
		b.Type,
		b.BetPlaced,
		b.WinLostDate,
		b.Currency,
		b.OddsAvg,
		b.FancyBetRuns,
		b.Stake * ISNULL(e.Rate, 1) AS Stake,
		b.WinLost * ISNULL(e.Rate, 1) AS WinLost
	FROM @Detail AS b
		LEFT JOIN @ExchangeRate AS e ON b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
END
GO
