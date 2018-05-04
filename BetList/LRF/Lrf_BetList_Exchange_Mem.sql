/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Lrf_BetList_Exchange_Mem]
	@AgentList			VARCHAR(MAX),
	@CustId				INT,
	@FromDate			DATETIME,
	@ToDate				DATETIME,
	@SumWinLost			MONEY		= 0 OUTPUT,
	@SumWinLostGBP		MONEY		= 0 OUTPUT,
	@SumWinLostEUR		MONEY		= 0 OUTPUT,
	@SumWinLostUSD		MONEY		= 0 OUTPUT
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

	SELECT * INTO #TempExchange
	FROM Lrf_f_GetExchangeDaily(@FDate, @TDate)
	WHERE ExchangeId IN (SELECT DISTINCT Currency FROM @Data)

	SELECT
		@SumWinLost		= SUM(ISNULL(b.WinLost, 0)			+ ISNULL(b.Commission, 0)),
		@SumWinLostGBP	= SUM(ISNULL(b.WinLost * e.GBP, 0)	+ ISNULL(b.Commission * e.GBP, 0)),
		@SumWinLostEUR	= SUM(ISNULL(b.WinLost * e.EUR, 0)	+ ISNULL(b.Commission * e.EUR, 0)),
		@SumWinLostUSD	= SUM(ISNULL(b.WinLost * e.USD, 0)	+ ISNULL(b.Commission * e.USD, 0))
	FROM @Data AS b
		INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.Currency

	SELECT
		b.*,
		b.WinLost	* e.GBP	AS WinLostGBP,
		b.Commission* e.GBP	AS CommissionGBP,
		b.WinLost	* e.EUR	AS WinLostEUR,
		b.Commission* e.EUR	AS CommissionEUR,
		b.WinLost	* e.USD	AS WinLostUSD,
		b.Commission* e.USD	AS CommissionUSD
	FROM @Data AS b
		INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.Currency

	SELECT
		b.*,
		b.Stake		* e.GBP	AS StakeGBP,
		b.WinLost	* e.GBP	AS WinLostGBP,
		b.Stake		* e.EUR	AS StakeEUR,
		b.WinLost	* e.EUR	AS WinLostEUR,
		b.Stake		* e.USD	AS StakeUSD,
		b.WinLost	* e.USD	AS WinLostUSD
	FROM @Detail AS b
		INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.Currency

	DROP TABLE #TempExchange
END


GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_Exchange_Mem] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_Exchange_Mem] TO vnteam
GO
 