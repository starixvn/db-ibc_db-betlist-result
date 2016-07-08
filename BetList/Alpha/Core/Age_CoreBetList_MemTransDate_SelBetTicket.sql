USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Age_BetList_CoreMem_SelBetTicket]    Script Date: 5/5/2015 1:45:13 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Age_CoreBetList_MemTransDate_SelBetTicket]
	-- MEM INFO
	@CustId				INT
	, @Username			NVARCHAR(30)
	, @FromDate			DATETIME
	, @ToDate			DATETIME
	-- PRODUCT - BETTYPE - STATUS
	, @TransStatus		[dbo].[TVP_BetTicketStatus]		READONLY
	, @BettypeMatrix	[dbo].[TVP_SportBettypeMatrix]	READONLY
	, @ColumnOutput		VARCHAR(MAX)	= NULL
	, @Error			INT 			= 0 OUTPUT
	, @ErrorMsg			VARCHAR(250)	= '' OUTPUT
AS

/*
	Created: Bobby.Nguyen
	Task : Aphla site - refactor betlist core 
	DB: DBAGE.bodb02
	Original: 

	Revisions:
		- 20150504@Bobby.Nguyen: Create new SP
		- 20150706@Bobby: Exclude Metric Gaming running ticket from bettrans table
		- 20150814@Bobby: #41600 - Update time range to datetime formation
		- 20150831@Kos: Support Colossus Bet
		- 20150910@Bobby: Enhance performance for SP core. Apply TVP for input parameters
		- 20151214@Kos: Support Cockfighting (#Redmine: 48850)
		- 20160111@Kos: Add column list in INSERT statement
		- 20160111@Kos: Add @TransStatus param to support RNG Casino Single Wallet [#Redmine: 48958]
		- 20160125@Kos: Fix performance issue with today RNG Casino Single Wallet ticket [#Redmine: 51388]
		- 20160216@Kos: Support yesterday running ticket for Casino products
		- 20160217@Kos: Support AllBet [Redmine: #50864]
		- 20160404@Kos: Support Voidbridge [Redmine: #54925]

	Param's Explanation:
		- @BettypeMatrix	: XML.format(<BettypeMatrix><row ProductID="1" Bettype="1" EventType="1" /></BettypeMatrix>)
		- @TransStatus		: string formation (0,1,102,103,111,112,113)

	Wrapped SP List:
		- Age_BetList_SelRunningByDate_Mem
		- Age_BetList_SelAllByDate_Mem
		
	Scope of tickets:
		- bettrans	: All products - all status
		- translog	: Keno, Gold Deluxe, Metric Gaming, Colossus Bet, Cockfighting - running status only
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @Recommend	INT
		, @tempCust		dbo.TVP_TicketSportBettype

	SELECT @Error = 0
		, @ErrorMsg = ''

	-- CHECK member info
	IF @CustID IS NULL AND @UserName IS NOT NULL
	BEGIN
		SELECT @CustID = CustID
			, @Recommend = Recommend 
		FROM dbo.custinfo WITH (NOLOCK)
		WHERE UserName = @UserName
	END
	
	IF( @CustID > 0
		AND (@Recommend IS NULL 
			OR @UserName IS NULL
		)
	)
	BEGIN
		SELECT @Recommend	= Recommend
			,@UserName		= UserName
		FROM dbo.custinfo WITH (NOLOCK)
		WHERE CustID = @CustID
	END
	
	IF @Recommend IS NULL
	BEGIN
		SELECT @Error = 100
			, @ErrorMsg = 'The customer was not found.'

		RETURN;
	END
	
	INSERT INTO @tempCust (
		TransID,
		Refno,
		CustID,
		ProductID,
		Bettype,
		EventType,
		WhTicket )
	SELECT 
		b.transid
		, b.refno
		, b.custid
		, bt.ProductId
		, b.bettype
		, bt.EventType
		, CASE
			WHEN b.winlostdate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0) 
				AND DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0) THEN		-- Yesterday and today summary ticket
				CASE
					WHEN bt.ProductId = 6 AND bt.SubProduct <> '' THEN 4	-- RNG Casino Single Wallet
					WHEN bt.ProductId = 22 THEN 4							-- Voidbridge
					WHEN bt.ProductId = 21 THEN 5							-- AllBet
					ELSE 1
				END
			ELSE 1
		END AS WhTicket
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
		INNER JOIN @TransStatus AS stt ON b.statusid = stt.statusid
	WHERE b.transdate BETWEEN @fromdate AND @todate 
		AND b.recommend = @Recommend 
		AND b.custid = @CustID
		--exclude running tickets of MetricGaming
		AND ( bt.SubProduct NOT IN ('MG-SuperLive') 
			OR ( bt.SubProduct	IN ('MG-SuperLive') AND b.StatusId NOT IN (0, 1) )
		)

	/* running tickets
		- Keno			: ProductId = 8
		- Gold Deluxe	: ProductId = 12
		- Colossus Bet	: ProductId = 15
		- Cockfighting	: ProductId = 19
		- Metric Gaming	: Bettype(801-899)
	*/
	IF EXISTS(SELECT TOP 1 1 FROM @TransStatus WHERE StatusId IN (0, 1))
	BEGIN
		INSERT INTO @tempCust (
			TransID,
			Refno,
			CustID,
			ProductID,
			Bettype,
			EventType,
			WhTicket )
		SELECT 
			b.translogid AS transid
			, b.translogid AS refno
			, b.custid
			, bt.ProductId
			, b.gameid
			, bt.EventType
			, 0 AS WhTicket
		FROM dbo.translog AS b WITH (NOLOCK)
			INNER JOIN @BettypeMatrix bt ON b.gameid = bt.Bettype
			INNER JOIN @TransStatus st ON b.statusID = st.StatusID
		WHERE b.transdate BETWEEN @fromdate AND @todate 
			AND b.custid = @CustID
			AND (
				bt.ProductId IN (8, 12, 15, 19) 
				OR bt.bettype BETWEEN 801 AND 899
			)
			AND b.statusID IN (0, 1)
	END

	--CALL to get ticket info
	EXEC [dbo].[Age_CoreBetList_BetTicket_SelMainInfo]
		@tempCust = @tempCust
		, @TransStatus = @TransStatus
		, @ColumnOutput = @ColumnOutput

	RETURN;
END



GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_MemTransDate_SelBetTicket] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_MemTransDate_SelBetTicket] TO [bodbDownlineNetView]
GO
