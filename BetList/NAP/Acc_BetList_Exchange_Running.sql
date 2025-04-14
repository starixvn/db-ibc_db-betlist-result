/*<info serverAlias="DBAGE-bodb02" executers="wsv_nap" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetList_Exchange_Running]
	@CustId		INT,
	@PageSize	INT			= 1000,
	@PageIndex	INT			= 1,
	@TotalRows	INT			= 0 OUTPUT
AS

/*
	Created: 20240826@Kos
	Task: NAP - Exchange - Bet List Running
	DB: DBAGE.bodb02

	Revisions:
		- 20240826@Kos: Support Exchange Running [#Redmine: 209743]
		- 20250410@Dave: Change datatype for ExchangeID [RedmineID: #221098]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Data AS TABLE (
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
		Currency		INT,
		OddsAvg			SMALLMONEY,
		FancyBetRuns	MONEY,
		Stake			MONEY
	)

	INSERT INTO @Data
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
		b.currencyType AS Currency,
		b.matchAvgOdds AS OddsAvg,
		ISNULL(bm.txFancyBetRuns, b.fancyBetRuns) AS fancyBetRuns,
		b.matchStake / IIF(c.site = '12bet', e.ExVirtualRate, 1) AS Stake
	FROM bodb_3rdProduct.dbo.Bettrans_Exchange AS b WITH (NOLOCK)
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = b.CustID
		INNER JOIN dbo.Exchange AS e WITH (NOLOCK) ON e.ExchangeId = c.currency
		LEFT JOIN bodb_3rdProduct.dbo.BettransM_Exchange AS bm WITH (NOLOCK) ON b.betID = bm.BetID
	WHERE b.CustID = @CustId
		AND b.betstatus = 'Not Settled'

	IF EXISTS (SELECT 1 FROM @Data)
	BEGIN
		SELECT
			@TotalRows = COUNT(1)
		FROM @Data
	END
	ELSE
	BEGIN
		SET @TotalRows = 0
	END

	DECLARE @PagingData AS TABLE (
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
		Currency		INT,
		OddsAvg			SMALLMONEY,
		FancyBetRuns	MONEY,
		Stake			MONEY
	)

	INSERT INTO @PagingData
	SELECT
		t.BetId,
		t.UserId,
		t.CategoryType,
		t.EventTypeName,
		t.EventId,
		t.EventName,
		t.MarketId,
		t.MarketName,
		t.SelectionId,
		t.SelectionName,
		t.Type,
		t.BetPlaced,
		t.Currency,
		t.OddsAvg,
		t.FancyBetRuns,
		t.Stake
	FROM (
			SELECT
				ROW_NUMBER() OVER (ORDER BY BetPlaced DESC) AS RowNum,
				*
			FROM @Data
		) AS t
	WHERE t.RowNum BETWEEN ((@PageIndex - 1) * @PageSize + 1) AND (@PageSize * @PageIndex)

	SELECT * FROM @PagingData
END
GO