USE bodb_archive
GO
ALTER PROCEDURE [dbo].[Aff_CoreBetList_BetTicket_SelDetailArc]
	@tempCust	TVP_TicketSportBettype READONLY
AS

/*
	Created: Bobby.Nguyen
	Task: Core bet list for Affiliate
	DB: DBARC.bodb_Archive
	Original: DBARC.bodb_Archive.dbo.Aff_CoreBetList_BetTicket_SelDetailArc

	Revisions:
		- 20170519@Kos: Clone from original SP and support CashOut [#Redmine: 71963]

	Param's Explanation:

	Dependences:
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
		, TransDesc			VARCHAR(300))

	IF EXISTS (SELECT TOP 1 1 FROM @tempCust WHERE ProductId IN (2, 5, 4, 12))
	BEGIN
		-- Get Sport Bettype Matrix
		DECLARE @SportBettype TABLE(ProductId TINYINT, Bettype SMALLINT, EventType TINYINT)

		DECLARE @IsTest BIT = 0

		SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

		INSERT INTO @SportBettype
		SELECT ProductID, BetType, EventType
		FROM bodb02.dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
		WHERE ProductID IN (2, 4, 5, 12)

		-- Horse Racing
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
			, '''' AS transdesc
		FROM bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN @tempCust AS b ON bm.refno = b.transid AND bm.custid = b.custid
			INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
		WHERE b.ProductId = 2 AND sbtm.ProductId = 2

		-- Virtual Sports
		UNION ALL
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
			, '''' AS transdesc
		FROM bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN @tempCust AS b ON bm.refno = b.refno AND bm.custid = b.custid
			INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
		WHERE b.ProductId = 5
			AND sbtm.ProductId = 5
			AND sbtm.EventType = 3

		-- Live Casino
		INSERT INTO @BettransDetail
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
			, '''' AS transdesc
		FROM bodb_Archive.dbo.bettransg AS bg WITH (NOLOCK)
			INNER JOIN @tempCust AS b ON bg.refno = b.refno AND bg.custid = b.custid
			INNER JOIN @SportBettype AS sbtg ON bg.bettype = sbtg.bettype
		WHERE b.ProductId = 4 AND sbtg.ProductID = 4

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
		FROM bodb_Archive.dbo.bettransg AS bg WITH (NOLOCK)
			INNER JOIN @tempCust AS b ON bg.refno = b.transid AND bg.custid = b.custid
			INNER JOIN @SportBettype AS sbtg ON bg.bettype = sbtg.bettype
		WHERE b.ProductId = 12 AND sbtg.ProductID = 12
	END

	-- OUTPUT ticket detail
	SELECT *
	FROM @BettransDetail
	ORDER BY RefNo DESC

	RETURN;
END


GRANT EXECUTE ON [dbo].[Aff_CoreBetList_BetTicket_SelDetailArc] TO [bodbAdminNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Aff_CoreBetList_BetTicket_SelDetailArc] TO [bodbDownlineNet] AS [dbo]
GO

