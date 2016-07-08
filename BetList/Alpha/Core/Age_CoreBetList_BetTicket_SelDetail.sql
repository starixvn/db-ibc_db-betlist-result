USE bodb02
--USE bodb_archive
GO
ALTER PROCEDURE [dbo].[Age_CoreBetList_BetTicket_SelDetail]
(
	@tempCust	TVP_TicketSportBettype READONLY
)
AS

/*
	Created: Bobby.Nguyen
	Task : Re-factor core betlist and apply GD product
	DB: DBAGE.bodb02
	Original: 

	Revisions:
		- 20150504@Bobby.Nguyen: Create new SP
		- 20150910@Bobby: Enhance performance for SP core. Apply TVP for input parameters
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]

	Param's Explanation:
	
	Dependences:
		- 
*/

BEGIN
	SET NOCOUNT ON;
	

	-- CREATE output detail tickets
	DECLARE @BettransDetail TABLE 
	(  
		refno 				BIGINT
		, odds 				MONEY
		, stake 			MONEY
		, status 			NVARCHAR(10)
		, apositiontaking	SMALLMONEY
		, mpositiontaking	SMALLMONEY
		, spositiontaking	SMALLMONEY
		, bettype 			SMALLINT
		, betteam 			NVARCHAR(10)
		, transdesc			VARCHAR(300)
	) 
	IF ( EXISTS (SELECT TOP 1 1 
				FROM @tempCust c
				WHERE c.ProductId IN (2, 5, 4, 12)
		)
	)
	BEGIN
		IF (EXISTS (SELECT TOP 1 1 FROM @tempCust WHERE WhTicket = 1))
		BEGIN
			
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
			FROM dbo.bettransm bm WITH (NOLOCK)
				INNER JOIN @tempCust b 
				ON bm.refno			= b.transid
			WHERE bm.custid			= b.custid
				AND b.ProductId		= 2
				
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
				, '' AS transdesc
			FROM dbo.bettransm bm WITH (NOLOCK)
				INNER JOIN @tempCust b 
				ON bm.refno			= b.refno
			WHERE bm.custid			= b.custid
				AND b.ProductID		= 5

			-- SELECT bettransg
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
				, '' AS transdesc
			FROM dbo.bettransg bg WITH (NOLOCK)
				INNER JOIN @tempCust b
				ON bg.refno			= b.refno
			WHERE bg.custid			= b.custid
				AND b.ProductId		= 4

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
			FROM dbo.bettransg bg WITH (NOLOCK)
				INNER JOIN @tempCust b
				ON bg.refno			= b.transid
			WHERE bg.custid			= b.custid
				AND b.ProductId		= 12
		END

		IF (EXISTS ( SELECT TOP 1 1 FROM @tempCust WHERE WhTicket = 2))
		BEGIN
			
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
			FROM dbo.bettransm14 bm WITH (NOLOCK)
				INNER JOIN @tempCust b 
				ON bm.refno		= b.transid
			WHERE bm.custid		= b.custid
				AND b.ProductId	= 2
				
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
				, '' AS transdesc
			FROM dbo.bettransm14 bm WITH (NOLOCK)
				INNER JOIN @tempCust b 
				ON bm.refno		= b.refno
			WHERE bm.custid		= b.custid
				AND b.ProductId	= 5

			-- SELECT bettransg14
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
				, '' AS transdesc
			FROM dbo.bettransg14 bg WITH (NOLOCK)
				INNER JOIN @tempCust b
				ON bg.refno		= b.refno
			WHERE bg.custid		= b.custid
				AND b.ProductId	= 4

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
			FROM dbo.bettransg14 bg WITH (NOLOCK)
				INNER JOIN @tempCust b
				ON bg.refno		= b.transid
			WHERE bg.custid		= b.custid
				AND b.ProductId	= 12
		END
		
	END

	-- OUTPUT ticket detail
	SELECT * 
	FROM @BettransDetail d
	ORDER BY d.refno DESC
	
	RETURN;
END


GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_BetTicket_SelDetail] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_BetTicket_SelDetail] TO [bodbDownlineNetView]
GO