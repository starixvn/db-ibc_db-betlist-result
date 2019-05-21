/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_Exchange_Mem]
	@AgentList		VARCHAR(MAX),
	@CustId			INT,
	@FromDate		DATETIME,
	@ToDate			DATETIME,
	@BaseCurrency	VARCHAR(10),
	@SumWinLost		MONEY		= 0 OUTPUT
AS

/*
	Created: Kos@20180301
	Task: Bet list detail for Exchange
	DB: DBEXT.bodb02

	Revisions:
		- 20180302@Kos: First revision [#Redmine: 91048]
		- 20190625@Kos: Add new input param @BaseCurrency [#Redmine: 112531]
					- Remove params @SumWinLostUSD, @SumWinLostEUR, @SumWinLostGBP, ...
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
		Stake			MONEY,
		WinLost			MONEY
	)

	DECLARE @TempToDate DATETIME

	SET @TempToDate = DATEADD(MILLISECOND, -2, DATEADD(DAY, DATEDIFF(DAY, -1, @ToDate), 0))

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

	DELETE @Data
	WHERE Currency NOT IN (SELECT DISTINCT Currency FROM @TempAg)

	INSERT INTO @Detail
	SELECT
		b.betID,
		b.userId,
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
		b.matchStake / s.ExVirtualRate AS Stake,
		b.profitLoss / s.ExVirtualRate AS WinLost
	FROM bodb_3rdProduct.dbo.Bettrans_Exchange AS b WITH (NOLOCK)
		INNER JOIN @Data AS s
			ON b.userId = s.userId
				AND b.eventID = s.eventID
				AND b.marketID = s.marketID

	DECLARE @FDate	DATETIME,
		@TDate		DATETIME

	SELECT @FDate = MIN(WinLostDate) FROM @Data
	SELECT @TDate = MAX(WinLostDate) FROM @Data

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
	FROM dbo.Lrf_f_GetSubExchangeDaily(@FDate, @TDate) AS e
	WHERE e.ExchangeId = @Currency
		AND EXISTS (SELECT 1 FROM @Data WHERE WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth)

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
		b.Stake * ISNULL(e.Rate, 1) AS Stake,
		b.WinLost * ISNULL(e.Rate, 1) AS WinLost
	FROM @Detail AS b
		LEFT JOIN @ExchangeRate AS e ON b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
END
GO


GRANT EXECUTE ON [dbo].[Lrf_BetList_Exchange_Mem] TO [bodbLicenseeNet]
GO
 