USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_CoreBetList_SMABettype_SelBetTicket]
	@CustId 			INT
	, @RoleId			INT
	, @EventDate		DATETIME		= NULL
	, @Language			VARCHAR(2) = 'E'
	-- PRODUCT - BETTYPE - STATUS
	, @TransStatus 		[dbo].[TVP_BetTicketStatus]		READONLY
	, @BettypeMatrix	[dbo].[TVP_SportBettypeMatrix]	READONLY
	, @ColumnOutput		VARCHAR(MAX) 	= NULL
	, @Error			INT 			= 0 OUTPUT
	, @ErrorMsg			NVARCHAR(250) 	= '' OUTPUT
AS

/*
	Created: Bobby.Nguyen
	Task : Aphla site - refactor betlist core 
	DB: DB053.bodb02
	Original: 

	Revisions:
		- 20150504@Bobby.Nguyen: Create new SP
		- 20150706@Bobby: Exclude Metric Gaming running ticket from bettrans table
		- 20150910@Bobby: Enhance performance for SP core. Apply TVP for input parameters
		- 20160111@Kos: Add @TransStatus param to support RNG Casino Single Wallet [#Redmine: 48958]
	
	Param's Explanation:
		- @BettypeMatrix	: XML.format(<BettypeMatrix><row ProductID="1" Bettype="1" EventType="1" /></BettypeMatrix>)
		- @TransStatus		: string formation (0,1,102,103,111,112,113)
		- @EventDate		: Indicate cancelled tickets
		
	Wrapped SP List:
		- Age_BetList_SelRunningByBettype_Ag
		- Age_BetList_SelRunningByBettype_MAg
		- Age_BetList_SelRunningByBettype_SAg
		- Age_BetList_SelDeleted
	
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @tempCust dbo.TVP_TicketSportBettype

	-- RESTET output
	SELECT @Error	= 0
		,@ErrorMsg	= ''

	CREATE TABLE #tempRawData
	( 
		transid			BIGINT
		, refno			BIGINT
		, custid 		INT 
		, productId 	TINYINT 
		, bettype		SMALLINT
		, eventType		TINYINT
		, WhTicket		TINYINT
	)

	-- MEMBER
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
		FROM bodb02.dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @BettypeMatrix bt ON b.bettype = bt.bettype
			INNER JOIN @TransStatus stt ON b.statusid = stt.statusid
		WHERE b.custid = @custid
			--exclude running tickets of MetricGaming
			AND ( bt.SubProduct NOT IN ('MG-SuperLive') 
				OR ( bt.SubProduct	IN ('MG-SuperLive')	AND b.StatusId NOT IN (0, 1) )
			)
	END

	-- AGENT
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
		FROM bodb02.dbo.bettrans b WITH(NOLOCK)
			INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON b.recommend = c.custid
			INNER JOIN @BettypeMatrix bt ON b.bettype = bt.bettype
			INNER JOIN @TransStatus stt ON b.statusid = stt.statusid
		WHERE c.recommend 	= @custid
			AND c.roleid 	= 2
			--exclude running tickets of MetricGaming
			AND ( bt.SubProduct NOT IN ('MG-SuperLive') 
				OR ( bt.SubProduct	IN ('MG-SuperLive')	AND b.StatusId NOT IN (0, 1) )
			)
	END

	-- MASTER
	IF @roleid = 3
	BEGIN
		INSERT INTO #tempRawData
		SELECT b.transid	
			,b.refno
			,b.custid
			,bt.ProductId
			,b.bettype
			,bt.EventType
			,1 AS WhTicket
		FROM bodb02.dbo.bettrans b WITH(NOLOCK)
			INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON b.recommend = c.custid
			INNER JOIN @BettypeMatrix bt ON b.bettype	= bt.bettype
			INNER JOIN @TransStatus stt ON b.statusid	= stt.statusid
		WHERE c.mrecommend 	= @custid
			AND c.roleid 	= 2
			--exclude running tickets of MetricGaming
			AND ( bt.SubProduct NOT IN ('MG-SuperLive') 
				OR ( bt.SubProduct	IN ('MG-SuperLive')	AND b.StatusId NOT IN (0, 1) )
			)
	END

	--SUPER
	IF @roleid = 4
	BEGIN
		INSERT INTO #tempRawData
		SELECT b.transid	
			,b.refno
			,b.custid
			,bt.ProductId
			,b.bettype
			,bt.EventType
			,1 AS WhTicket
		FROM bodb02.dbo.bettrans b WITH(NOLOCK)
			INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON b.recommend 	= c.custid	
			INNER JOIN @BettypeMatrix bt ON b.bettype	= bt.bettype
			INNER JOIN @TransStatus stt ON b.statusid	= stt.statusid
		WHERE c.srecommend 	= @custid
			AND c.roleid 	= 2
			--exclude running tickets of MetricGaming
			AND ( bt.SubProduct NOT IN ('MG-SuperLive') 
				OR ( bt.SubProduct	IN ('MG-SuperLive')	AND b.StatusId NOT IN (0, 1) )
			)
	END

	-- CHECK for cancelling tickets
	IF @EventDate IS NOT NULL
	BEGIN
		DELETE c
		FROM #tempRawData c
			INNER JOIN dbo.bettrans b (NOLOCK)
			ON c.transid 	= b.transid
			LEFT JOIN dbo.match m WITH(NOLOCK)
			ON b.matchid	= m.matchid
			AND c.EventType	= 1
			LEFT JOIN dbo.outright o WITH (NOLOCK) 
			ON b.matchid	= o.orid
			AND c.EventType	= 2
			LEFT JOIN dbo.VSOutright vs (nolock) 
			ON b.oddsid		= vs.Orid
			AND c.EventType	= 3
		WHERE b.statusid IN (101, 102)
			AND (
				(	m.eventdate 	<= @EventDate
					OR o.eventdate 	<= @EventDate
					OR vs.eventdate <= @EventDate
				) OR b.bettype IN (9, 29) --exclude parlay tickets
			)
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
GRANT EXECUTE ON [dbo].[Age_CoreBetList_SMABettype_SelBetTicket] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_SMABettype_SelBetTicket] TO [bodbDownlineNetView]
GO