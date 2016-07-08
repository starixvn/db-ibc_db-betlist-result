USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_CoreBetList_SMAEventBettype_SelBetTicket]
	@CustId 			INT 			= NULL
	, @Username 		VARCHAR(50) 	= NULL
	, @RoleId			INT
	, @MatchId 			INT
	-- PRODUCT - BETTYPE - STATUS
	, @TransStatus 		[dbo].[TVP_BetTicketStatus]		READONLY
	, @BettypeMatrix	[dbo].[TVP_SportBettypeMatrix]	READONLY
	
	, @Language 		VARCHAR(2) 		= 'E'
	, @Liveindicator 	INT 			= 0
	, @Betteam 			NVARCHAR(20)	= NULL
	, @ColumnOutput		VARCHAR(MAX) 	= NULL
	, @Error			INT 			= 0
	, @ErrorMsg			NVARCHAR(250)	= NULL
AS

/*
	Created: Bobby.Nguyen
	Task : Aphla site - refactor betlist core 
	DB: DB053.bodb02
	Original: 

	Revisions:
		- 20150504@Bobby.Nguyen: Create new SP
		- 20150706@Bobby: Exclude Metric Gaming running ticket from bettrans table
		- 20150910@Bobby: Enhance performence for SP core. Apply TVP for input parameters
		- 20160111@Kos: Add @TransStatus param to support RNG Casino Single Wallet [#Redmine: 48958]
		
	Param's Explanation:
		- @BettypeMatrix	: XML.format(<BettypeMatrix><row ProductID="1" Bettype="1" EventType="1" /></BettypeMatrix>)
		- @TransStatus		: string formation (0,1,102,103,111,112,113)
		
	Wrapped SP List:
		- Age_BetList_SelRunningByBettypeMatch_Ag
		- Age_BetList_SelRunningByBettypeMatch_MAg
		- Age_BetList_SelRunningByBettypeMatch_SAg
		- Age_BetList_SelWinlossByBettypeMatch_Ag
		- Age_BetList_SelWinlossByBettypeMatch_MAg
		- Age_BetList_SelWinlossByBettypeMatch_SAg
	
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @IsBet14	BIT
		, @tempCust		dbo.TVP_TicketSportBettype

	-- RESTET output
	SELECT @Error	= 0
		,@ErrorMsg	= ''

	--CHECK bettrans14
	SELECT TOP 1 @IsBet14 = CAST(1 AS BIT) 
	FROM dbo.match14 WITH (NOLOCK) 
	WHERE matchid = @matchid

	SET @IsBet14 = ISNULL(@IsBet14, 0)

	IF @custid IS NULL
	BEGIN
		SELECT @custid = custid 
		FROM dbo.customer WITH (NOLOCK) 
		WHERE username = @username
	END

	CREATE TABLE #tempRawData
	( 
		transid		BIGINT
		, refno		BIGINT
		, custid 	INT 
		, productId	TINYINT 
		, bettype	SMALLINT 
		, eventType	TINYINT 
		, WhTicket	TINYINT
	)
	
	-- from bettrans
	IF @IsBet14 = 0
	BEGIN
		IF @roleid = 1
		BEGIN
			INSERT INTO #tempRawData
			SELECT b.transid
				,b.refno
				,b.custid
				,bt.ProductId
				,b.bettype
				,bt.EventType
				,1 AS WhTicket
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @BettypeMatrix bt ON b.bettype	= bt.bettype
				INNER JOIN @TransStatus stt ON b.statusid	= stt.statusid
			WHERE b.custid 		= @custid
				AND b.matchid	= @matchid
				AND (bt.SubProduct NOT IN ('MG-SuperLive') OR bt.SubProduct	IN ('MG-SuperLive') AND b.StatusId NOT IN (0, 1))
		END

		IF @roleid = 2
		BEGIN
			INSERT INTO #tempRawData
			SELECT b.transid
				,b.refno
				,b.custid
				,bt.ProductId
				,b.bettype
				,bt.EventType
				,1 AS WhTicket
			FROM dbo.bettrans b WITH(NOLOCK)
				INNER JOIN @BettypeMatrix bt ON b.bettype	= bt.bettype
				INNER JOIN @TransStatus stt ON b.statusid	= stt.statusid
			WHERE b.recommend	= @custid
				AND b.matchid	= @matchid
				AND (bt.SubProduct NOT IN ('MG-SuperLive') OR bt.SubProduct	IN ('MG-SuperLive') AND b.StatusId NOT IN (0, 1))
		END

		IF @roleid = 3
		BEGIN
			WITH CteRecommend ( custid )
			AS (
				SELECT custid
				FROM dbo.Customer c WITH(NOLOCK)
				WHERE c.mrecommend 	= @custid
					AND c.roleid 	= 2
			)
			INSERT INTO #tempRawData
			SELECT b.transid
				,b.refno
				,b.custid
				,bt.ProductId
				,b.bettype
				,bt.EventType
				,1 AS WhTicket
			FROM dbo.bettrans b WITH(NOLOCK)
				INNER JOIN CteRecommend c ON b.recommend = c.custid
				INNER JOIN @BettypeMatrix bt ON b.bettype	= bt.bettype
				INNER JOIN @TransStatus stt ON b.statusid	= stt.statusid
			WHERE b.matchid		= @matchid
				AND (bt.SubProduct NOT IN ('MG-SuperLive') OR bt.SubProduct	IN ('MG-SuperLive') AND b.StatusId NOT IN (0, 1))
		END

		IF @roleid = 4
		BEGIN
			WITH CteRecommend ( custid )
			AS (
				SELECT custid
				FROM dbo.Customer c WITH(NOLOCK)
				WHERE c.srecommend 	= @custid
					AND c.roleid 	= 2
			)
			INSERT INTO #tempRawData
			SELECT b.transid
				,b.refno
				,b.custid
				,bt.ProductId
				,b.bettype
				,bt.EventType
				,1 AS WhTicket
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN CteRecommend c ON b.recommend = c.custid
				INNER JOIN @BettypeMatrix bt ON b.bettype	= bt.bettype
				INNER JOIN @TransStatus stt ON b.statusid	= stt.statusid
			WHERE b.matchid		= @matchid
				AND (bt.SubProduct NOT IN ('MG-SuperLive') OR bt.SubProduct	IN ('MG-SuperLive') AND b.StatusId NOT IN (0, 1))
		END
	END

	IF @IsBet14 = 1 -- from bettrans14
	BEGIN
		IF @roleid = 1
		BEGIN
			INSERT INTO #tempRawData
			SELECT b.transid
				,b.refno
				,b.custid
				,bt.ProductId
				,b.bettype
				,bt.EventType
				,2 AS WhTicket
			FROM dbo.bettrans14 b WITH (NOLOCK)
				INNER JOIN @BettypeMatrix bt ON b.bettype	= bt.bettype
				INNER JOIN @TransStatus stt ON b.statusid	= stt.statusid
			WHERE b.custid 		= @custid
				AND b.matchid	= @matchid
		END

		IF @roleid = 2
		BEGIN
			INSERT INTO #tempRawData
			SELECT b.transid
				,b.refno
				,b.custid
				,bt.ProductId
				,b.bettype
				,bt.EventType
				,2 AS WhTicket
			FROM dbo.bettrans14 b WITH (NOLOCK)
				INNER JOIN @BettypeMatrix bt ON b.bettype	= bt.bettype
				INNER JOIN @TransStatus stt ON b.statusid	= stt.statusid
			WHERE b.recommend	= @custid
				AND b.matchid	= @matchid
		END

		IF @roleid = 3
		BEGIN
			WITH CteRecommend ( custid )
			AS (
				SELECT custid
				FROM dbo.Customer c WITH(NOLOCK)
				WHERE c.mrecommend 	= @custid
					AND c.roleid 	= 2
			)
			INSERT INTO #tempRawData
			SELECT b.transid
				,b.refno
				,b.custid
				,bt.ProductId
				,b.bettype
				,bt.EventType
				,2 AS WhTicket
			FROM dbo.bettrans14 b WITH (NOLOCK)
				INNER JOIN CteRecommend c ON b.recommend = c.custid
				INNER JOIN @BettypeMatrix bt ON b.bettype	= bt.bettype
				INNER JOIN @TransStatus stt ON b.statusid	= stt.statusid
			WHERE b.matchid = @matchid
		END
		
		IF @roleid = 4
		BEGIN
			WITH CteRecommend ( custid )
			AS (
				SELECT custid
				FROM dbo.Customer c WITH(NOLOCK)
				WHERE c.srecommend 	= @custid
					AND c.roleid 	= 2
			)
			INSERT INTO #tempRawData
			SELECT b.transid
				,b.refno
				,b.custid
				,bt.ProductId
				,b.bettype
				,bt.EventType
				,2 AS WhTicket
			FROM dbo.bettrans14 b WITH (NOLOCK)
				INNER JOIN CteRecommend c ON b.recommend = c.custid
				INNER JOIN @BettypeMatrix bt ON b.bettype	= bt.bettype
				INNER JOIN @TransStatus stt ON b.statusid	= stt.statusid
			WHERE b.matchid = @matchid
		END
	END

	IF EXISTS (SELECT TOP 1 1 FROM #tempRawData WHERE ProductId = 3 AND eventType = 1 )
	BEGIN
	
		IF @IsBet14 = 0
		BEGIN
			DELETE c
			FROM #tempRawData c
				INNER JOIN dbo.bettrans b WITH (NOLOCK)
				ON c.transid 		= b.transid 
				AND c.custid 		= b.custid
			WHERE c.WhTicket 		= 1
				AND c.ProductId 	= 3 
				AND c.eventType 	= 1
				AND (
					((@liveindicator IS NOT NULL AND b.Liveindicator <> @liveindicator))
					OR 
					((LEN(@betteam) > 0 AND b.betteam <> @betteam))
				 )
		END
		
		IF @IsBet14 = 1
		BEGIN
			DELETE c
			FROM #tempRawData c
				INNER JOIN dbo.bettrans14 b WITH (NOLOCK)
				ON c.transid 		= b.transid 
				AND c.custid 		= b.custid
			WHERE c.WhTicket 		= 2
				AND c.ProductId 	= 3 
				AND c.eventType 	= 1
				AND (
					((@liveindicator IS NOT NULL AND b.Liveindicator <> @liveindicator))
					OR 
					((LEN(@betteam) > 0 AND b.betteam <> @betteam))
				 )
		END
	END
	
	INSERT INTO @tempCust
	SELECT TransID
		, Refno
		, CustID
		, ProductID
		, Bettype
		, EventType
		, WhTicket
	FROM #tempRawData
	
	--CALL to get ticket info
	EXEC [dbo].[Age_CoreBetList_BetTicket_SelMainInfo] 
		@tempCust = @tempCust, 
		@TransStatus = @TransStatus, 
		@ColumnOutput = @ColumnOutput

	RETURN;
END


GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_SMAEventBettype_SelBetTicket] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_SMAEventBettype_SelBetTicket] TO [bodbDownlineNetView]
GO

