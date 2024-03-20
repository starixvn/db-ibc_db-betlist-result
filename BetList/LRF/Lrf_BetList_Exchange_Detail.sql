/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet,wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

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

	DECLARE @Data AS TABLE (
		TransId			BIGINT,
		EventType		INT,
		CategoryType	SMALLINT,
		BetTaken		DATETIME,
		WinLostDate		DATETIME,
		Currency		TINYINT,
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
		DATEADD(DAY, 0, DATEDIFF(DAY, 0, s.settledDate)) AS WinLostDate,
		s.Currency,
		bm.txStake / s.ExVirtualRate AS Stake,
		bm.actualOdds AS OddsRequest,
		bm.txOddsMatched AS OddsMatched,
		bm.txFancyBetRuns AS FancyBetRuns
	FROM bodb_3rdProduct.dbo.Bettrans_Exchange AS b WITH (NOLOCK)
		INNER JOIN bodb_3rdProduct.dbo.BettransM_Exchange AS bm WITH (NOLOCK) ON b.betID = bm.BetID
		INNER JOIN bodb_3rdProduct.dbo.Sum_winloss_Exchange AS s WITH (NOLOCK)
			ON b.userId = s.userId
				AND b.eventID = s.eventID
				AND b.marketID = s.marketID
	WHERE b.betID = @BetId
		AND s.CustID = @CustId
		AND s.Currency IN (SELECT DISTINCT Currency FROM @TempAg)

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
		b.Currency,
		b.Stake * ISNULL(e.Rate, 1) AS Stake,
		b.OddsRequest,
		b.OddsMatched,
		b.FancyBetRuns
	FROM @Data AS b
		LEFT JOIN @ExchangeRate AS e ON b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
END
GO
