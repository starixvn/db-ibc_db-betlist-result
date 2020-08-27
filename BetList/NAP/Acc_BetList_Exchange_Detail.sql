/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/

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
*/

BEGIN
	SET NOCOUNT ON

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

	SELECT * FROM @Data
END
GO