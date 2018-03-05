USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Lrf_BetList_Exchange_Detail]
	@AgentList	VARCHAR(MAX),
	@CustId		INT,
	@BetId		BIGINT
AS

/*
	Created: Kos@20180301
	Task: Bet list detail for Exchange
	DB: DBEXT.bodb02

	Revisions:
		- 20180302@Kos: First revision [#Redmine: 91048]
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
			ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH

	DECLARE @Data AS TABLE (
		TransId			BIGINT,
		BetTaken		DATETIME,
		WinLostDate		DATETIME,
		Currency		TINYINT,
		Stake			MONEY,
		OddsRequest		SMALLMONEY,
		OddsMatched		SMALLMONEY
	)

	INSERT INTO @Data
	SELECT
		bm.TransID,
		bm.betTaken,
		DATEADD(DAY, 0, DATEDIFF(DAY, 0, s.settledDate)) AS WinLostDate,
		s.Currency,
		bm.txStake / s.ExVirtualRate AS Stake,
		bm.actualOdds AS OddsRequest,
		bm.txOddsMatched AS OddsMatched
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

	SELECT * INTO #TempExchange
	FROM Lrf_f_GetExchangeDaily(@FDate, @TDate)
	WHERE ExchangeId IN (SELECT DISTINCT Currency FROM @Data)

	SELECT
		b.*,
		b.Stake	* e.GBP	AS StakeGBP,
		b.Stake	* e.EUR	AS StakeEUR,
		b.Stake	* e.USD	AS StakeUSD
	FROM @Data AS b
		INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.Currency

	DROP TABLE #TempExchange
END


GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_Exchange_Detail] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_Exchange_Detail] TO vnteam
GO
 