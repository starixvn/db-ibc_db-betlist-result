/*<info serverAlias="DBAGE-bodb02" executers="wsv_nap" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetList_Exchange_Detail]
	@CustId	INT,
	@BetId	BIGINT
AS

/*
	Created: Kos@20180301
	Task: Bet list detail for Exchange
	DB: DBAGE.bodb02

	Revisions:
		- 20180313@Kos: First revision [#Redmine: 91808]
		- 20200827@Kos: Support Fancy Bet [#Redmine: 138524]
		- 20240826@Kos: Support Exchange Running [#Redmine: 209743]
		- 20250410@Dave: Change datatype for ExchangeID [RedmineID: #221098]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Data AS TABLE (
		TransId			BIGINT,
		EventType		INT,
		CategoryType	SMALLINT,
		BetTaken		DATETIME,
		WinLostDate		DATETIME,
		Currency		INT,
		Stake			MONEY,
		OddsRequest		SMALLMONEY,
		OddsMatched		SMALLMONEY,
		FancyBetRuns	MONEY
	)

	DECLARE @Currency	INT,
		@ExVirtualRate	FLOAT

	SELECT
		@Currency = c.currency,
		@ExVirtualRate = IIF(c.site = '12bet', e.ExVirtualRate, 1)
	FROM dbo.Customer AS c WITH (NOLOCK)
		INNER JOIN dbo.Exchange AS e WITH (NOLOCK) ON e.ExchangeId = c.currency
	WHERE c.custid = @CustId

	INSERT INTO @Data
	SELECT
		bm.TransID,
		b.eventType,
		b.categoryType,
		bm.betTaken,
		DATEADD(DAY, 0, DATEDIFF(DAY, 0, ISNULL(s.settledDate, GETDATE()))) AS WinLostDate,
		@Currency AS Currency,
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

	SELECT * FROM @Data
END
GO