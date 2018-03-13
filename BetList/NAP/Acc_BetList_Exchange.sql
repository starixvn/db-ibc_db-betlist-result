USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Acc_BetList_Exchange]
	@CustId		INT,
	@FromDate	DATETIME,
	@ToDate		DATETIME,
	@PageSize	INT			= 1000,
	@PageIndex	INT			= 1,
	@TotalRows	INT			= 0 OUTPUT,
	@GrandTotal	MONEY		= 0 OUTPUT
AS

/*
	Created: Kos@20180301
	Task: Bet list for Exchange
	DB: DBEXT.bodb02

	Revisions:
		- 20180313@Kos: First revision [#Redmine: 91808]
*/

BEGIN
	SET NOCOUNT ON

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

	IF EXISTS (SELECT 1 FROM @Data)
	BEGIN
		SELECT
			@TotalRows = COUNT(1),
			@GrandTotal = SUM(WinLost + Commission)
		FROM @Data
	END
	ELSE
	BEGIN
		SET @TotalRows = 0
		SET @GrandTotal = 0
	END

	DECLARE @PagingData AS TABLE (
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

	INSERT INTO @PagingData
	SELECT
		t.UserId,
		t.EventTypeName,
		t.EventId,
		t.EventName,
		t.MarketId,
		t.MarketName,
		t.SettledDate,
		t.WinLostDate,
		t.WinLost,
		t.Commission,
		t.Currency,
		t.ExVirtualRate
	FROM (
			SELECT
				ROW_NUMBER() OVER (ORDER BY SettledDate DESC) AS RowNum,
				*
			FROM @Data
		) AS t
	WHERE t.RowNum BETWEEN ((@PageIndex - 1) * @PageSize + 1) AND (@PageSize * @PageIndex)

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
		INNER JOIN @PagingData AS s
			ON b.userId = s.userId
				AND b.eventID = s.eventID
				AND b.marketID = s.marketID

	SELECT * FROM @PagingData
	SELECT * FROM @Detail
END


GO
GRANT EXECUTE ON [dbo].[Acc_BetList_Exchange] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BetList_Exchange] TO vnteam
GO
 