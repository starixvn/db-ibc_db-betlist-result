/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_Exchange_Detail]
	@AgentList		VARCHAR(MAX),
	@CustId			INT,
	@BetId			BIGINT,
	@BaseCurrency	VARCHAR(12)
AS

/*
	Created: Kos@20180301
	Task: Bet list detail for Exchange
	DB: DBEXT.bodb02

	Revisions:
		- 20180302@Kos: First revision [#Redmine: 91048]
		- 20190625@Kos: Add new input param @BaseCurrency [#Redmine: 112531]
		- 20200827@Kos: Support Fancy Bet [#Redmine: 138524]
		- 20210301@Kos: Add BDT and INR as base currencies [Redmine: 150375]
		- 20230922@Kos: Support crypto currency [Redmine: 177481]
		- 20240821@Kos: Support BTC Exchange Running [#Redmine: 208108]
		- 20250225@Kos: Fix bug FLOAT rounding [#Redmine: 194970]
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

	DECLARE @Currency	INT,
		@ExVirtualRate	FLOAT

	SELECT
		@Currency = c.currency,
		@ExVirtualRate = IIF(c.site = '12bet', e.ExVirtualRate, 1)
	FROM dbo.Customer AS c WITH (NOLOCK)
		INNER JOIN dbo.Exchange AS e WITH (NOLOCK) ON e.ExchangeId = c.currency
	WHERE c.custid = @CustId

	DECLARE @Data AS TABLE (
		TransId			BIGINT,
		EventType		INT,
		CategoryType	SMALLINT,
		BetTaken		DATETIME,
		WinLostDate		DATETIME,
		Stake			MONEY,
		OddsRequest		SMALLMONEY,
		OddsMatched		SMALLMONEY,
		FancyBetRuns	MONEY
	)

	INSERT INTO @Data
	SELECT
		bm.TransID,
		b.eventType,
		b.categoryType,
		bm.betTaken,
		DATEADD(DAY, 0, DATEDIFF(DAY, 0, ISNULL(s.settledDate, GETDATE()))) AS WinLostDate,
		bm.txStake / @ExVirtualRate AS Stake,
		bm.actualOdds AS OddsRequest,
		bm.txOddsMatched AS OddsMatched,
		bm.txFancyBetRuns AS FancyBetRuns
	FROM bodb_3rdProduct.dbo.Bettrans_Exchange AS b WITH (NOLOCK)
		INNER JOIN bodb_3rdProduct.dbo.BettransM_Exchange AS bm WITH (NOLOCK) ON b.betID = bm.BetID
		LEFT JOIN bodb_3rdProduct.dbo.Sum_winloss_Exchange AS s WITH (NOLOCK)
			ON b.userId = s.userId
				AND b.eventID = s.eventID
				AND b.marketID = s.marketID
	WHERE b.betID = @BetId
		AND ISNULL(s.CustID, b.CustID) = @CustId

	DECLARE @FDate	DATETIME,
		@TDate		DATETIME

	SELECT @FDate = MIN(WinLostDate) FROM @Data
	SELECT @TDate = MAX(WinLostDate) FROM @Data

	DECLARE @ExchangeRate TABLE (
		FirstExchangeDateByMonth	SMALLDATETIME,
		LastExchangeDateByMonth		SMALLDATETIME,
		Rate						FLOAT
	)

	-- Get exchange rate
	INSERT INTO @ExchangeRate
	SELECT
		e.FromDate,
		e.ToDate,
		e.Rate
	FROM dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @BaseCurrency, '') AS e
	WHERE e.ExchangeId = @Currency
		AND EXISTS (SELECT 1 FROM @Data WHERE WinLostDate BETWEEN e.FromDate AND e.ToDate)

	SELECT
		b.TransId,
		b.EventType,
		b.CategoryType,
		b.BetTaken,
		b.WinLostDate,
		@Currency AS Currency,
		CAST(b.Stake * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS Stake,
		b.OddsRequest,
		b.OddsMatched,
		b.FancyBetRuns
	FROM @Data AS b
		LEFT JOIN @ExchangeRate AS e ON b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
END
GO
