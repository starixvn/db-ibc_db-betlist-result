/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE bodb02
GO
ALTER PROCEDURE [dbo].[Age_CoreBetList_BetTicket_SelDetail]
	@tempCust	TVP_TicketSportBettype READONLY
AS

/*
	Created: Bobby.Nguyen
	Task: Re-factor core betlist and apply GD product
	DB: DBAGE.bodb02
	Original:

	Revisions:
		- 20150504@Bobby: Create new SP
		- 20150910@Bobby: Enhance performance for SP core. Apply TVP for input parameters
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20161010@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20180202@Kos: Don't support Racing, Live Casino [#Redmine: 86086]

	Param's Explanation:
	
	Dependences:
		- 
*/

BEGIN
	SET NOCOUNT ON;

	-- CREATE output detail tickets
	DECLARE @BettransDetail TABLE (
		RefNo				BIGINT
		, Odds				MONEY
		, Stake				MONEY
		, Status			NVARCHAR(10)
		, APositionTaking	SMALLMONEY
		, MPositionTaking	SMALLMONEY
		, SPositionTaking	SMALLMONEY
		, BetType			SMALLINT
		, BetTeam			NVARCHAR(10)
		, TransDesc			VARCHAR(300)
	)

	IF EXISTS (SELECT TOP(1) 1 FROM @tempCust WHERE ProductId IN (5, 12))
	BEGIN
		-- Get Sport Bettype Matrix
		DECLARE @SportBettype TABLE(ProductId TINYINT, Bettype SMALLINT, EventType TINYINT)

		DECLARE @IsTest BIT = 0

		SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

		INSERT INTO @SportBettype
		SELECT ProductID, BetType, EventType
		FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
		WHERE ProductID IN (5, 12)

		IF EXISTS (SELECT TOP(1) 1 FROM @tempCust WHERE WhTicket = 1)
		BEGIN
			-- Virtual Sports
			INSERT INTO @BettransDetail
			SELECT
				bm.refno
				, bm.odds
				, bm.stake
				, bm.status
				, bm.apositiontaking
				, bm.mpositiontaking 
				, bm.spositiontaking
				, bm.bettype
				, bm.betteam
				, '' AS transdesc
			FROM dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN @tempCust AS b ON bm.refno = b.refno AND bm.custid = b.custid
				INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
			WHERE b.ProductID = 5
				AND sbtm.ProductId = 5
				AND sbtm.EventType = 3

			-- Gold Deluxe
			UNION ALL
			SELECT
				bg.refno
				, bg.odds
				, bg.stake
				, bg.status
				, bg.apositiontaking
				, bg.mpositiontaking 
				, bg.spositiontaking
				, bg.bettype
				, bg.betteam 
				, bg.transdesc
			FROM dbo.bettransg AS bg WITH (NOLOCK)
				INNER JOIN @tempCust AS b ON bg.refno = b.transid AND bg.custid = b.custid
				INNER JOIN @SportBettype AS sbtg ON bg.bettype = sbtg.bettype
			WHERE b.ProductId = 12 AND sbtg.ProductID = 12
		END

		IF EXISTS (SELECT TOP(1) 1 FROM @tempCust WHERE WhTicket = 2)
		BEGIN
			-- Virtual Sports
			INSERT INTO @BettransDetail
			SELECT 
				bm.refno
				, bm.odds
				, bm.stake
				, bm.status
				, bm.apositiontaking
				, bm.mpositiontaking
				, bm.spositiontaking
				, bm.bettype
				, bm.betteam
				, '' AS transdesc
			FROM dbo.bettransm14 AS bm WITH (NOLOCK)
				INNER JOIN @tempCust AS b ON bm.refno = b.refno AND bm.custid = b.custid
				INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
			WHERE b.ProductId = 5
				AND sbtm.ProductId = 5
				AND sbtm.EventType = 3

			-- Gold Deluxe
			UNION ALL
			SELECT
				bg.refno
				, bg.odds
				, bg.stake
				, bg.status
				, bg.apositiontaking
				, bg.mpositiontaking 
				, bg.spositiontaking
				, bg.bettype
				, bg.betteam 
				, bg.transdesc
			FROM dbo.bettransg14 AS bg WITH (NOLOCK)
				INNER JOIN @tempCust AS b ON bg.refno = b.transid AND bg.custid = b.custid
				INNER JOIN @SportBettype AS sbtg ON bg.bettype = sbtg.bettype
			WHERE b.ProductId = 12 AND sbtg.ProductID = 12
		END
	END

	-- OUTPUT ticket detail
	SELECT * 
	FROM @BettransDetail
	ORDER BY RefNo DESC

	RETURN;
END


GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_BetTicket_SelDetail] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_BetTicket_SelDetail] TO [bodbDownlineNetView]
GO