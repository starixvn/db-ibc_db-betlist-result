/*<info serverAlias="DBARC-bodb_Archive" executers="bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE [bodb_archive]
GO
/****** Object:  StoredProcedure [dbo].[Age_BetList_SelWinLossByDate_Mem]    Script Date: 3/10/2014 3:29:18 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Age_CoreBetList_MemArc_SelBetTicket]
(
	-- MEM INFO
	@CustId				INT
	, @FromDate			DATE
	, @ToDate			DATE
	-- PRODUCT - BETTYPE - STATUS
	, @TransStatus		[dbo].[TVP_BetTicketStatus]		READONLY
	, @BettypeMatrix	[dbo].[TVP_SportBettypeMatrix]	READONLY
	, @TransType		INT				= 0
	-- PAGING
	, @PageIndex		INT				= 1
	, @PageSize			INT				= 1000
	, @ColumnOutput		VARCHAR(MAX)	= NULL
	-- OUTPUT INFO
	, @Error			INT				= 0		OUTPUT
	, @ErrorMsg			VARCHAR(250)	= ''	OUTPUT
)
AS

/*
	Created: Bobby.Nguyen
	Task: Aphla site - refactor betlist core 
	DB: DBARC.bodb_archive
	Original: 

	Revisions:
		- 20150504@Bobby: Create new SP
		- 20150504@Bobby: Due to performance, we should use index hint (IX_custid) on bettrans_bk
		- 20150910@Bobby: Enhance performance for SP core. Apply TVP for input parameters
		- 20160111@Kos: Add column list in INSERT statement
		- 20160323@Kos: Support Colossus Bet Grand Prize [Redmine: #54643]
		- 20160328@Kos: Support Grand Prize ticket which status is Expired
		- 20180126@Kos: Support ONERnG Jackpot [#Redmine: 88652]

	Param's Explanation:
		- @TransStatus		: string formation (0,1,102,103,111,112,113)
		- @TransType		: 4: Grand Prize ticket, Others: normal ticket

	Wrapped SP List:
		- Age_BetList_SelByDayAll_Mem_Old
		- Age_BetList_SelWinLossByDate_Mem_Old
	
	Dependences:
		
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @Recommend	INT
		, @tempCust		dbo.TVP_TicketSportBettype

	SELECT @Error	= 0
		, @ErrorMsg	= ''

	SELECT @Recommend = Recommend
	FROM bodb02.dbo.custinfo WITH (NOLOCK)
	WHERE CustID = @CustId

	IF @Recommend IS NULL
	BEGIN
		SELECT @Error = 100
			, @ErrorMsg = 'The customer was not found.'

		RETURN;
	END

	IF @TransType <> 4
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
			b.transid
			, b.refno
			, b.custid
			, bt.ProductId
			, b.bettype
			, bt.EventType
			, 3 AS WhTicket
		FROM dbo.bettrans_bk AS b WITH (NOLOCK, INDEX = IX_custid)
			INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
			INNER JOIN @TransStatus AS stt ON b.statusid = stt.statusid
		WHERE b.winlostdate BETWEEN @FromDate AND @ToDate
			AND b.custid = @CustId
	END

	-- Grand Prize ticket
	IF @TransType = 4
	BEGIN
		-- ONERnG Jackpot
		IF EXISTS (SELECT TOP(1) 1 FROM @BettypeMatrix WHERE ProductID = 6)
		BEGIN
			INSERT INTO @tempCust (
				TransID
				, Refno
				, CustID
				, ProductID
				, Bettype
				, EventType
				, WhTicket)
			SELECT 
				b.transid
				, b.refno
				, b.custid
				, bt.ProductId
				, b.gameID
				, bt.EventType
				, 8 AS WhTicket
			FROM dbo.bettransRnG_bk AS b WITH (NOLOCK)
				INNER JOIN @BettypeMatrix AS bt ON b.gameID = bt.bettype
				INNER JOIN @TransStatus AS stt ON b.statusid = stt.statusid
			WHERE b.winlostdate BETWEEN @FromDate AND @ToDate
				AND b.recommend = @Recommend
				AND b.custid = @CustId
				AND EXISTS (	SELECT 1
								FROM bodb02.dbo.PayoutTrans AS pt WITH (NOLOCK)
								WHERE pt.refno = b.transid AND pt.PayoutStatus IN ('Completed', 'Expired'))
		END

		-- Colossus Bet
		IF EXISTS (SELECT TOP(1) 1 FROM @BettypeMatrix WHERE ProductID = 15)
		BEGIN
			INSERT INTO @tempCust (
				TransID
				, Refno
				, CustID
				, ProductID
				, Bettype
				, EventType
				, WhTicket)
			SELECT
				b.transid
				, b.refno
				, b.custid
				, bt.ProductId
				, b.bettype
				, bt.EventType
				, 3 AS WhTicket
			FROM dbo.bettrans_bk AS b WITH (NOLOCK, INDEX = IX_custid)
				INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
				INNER JOIN @TransStatus AS stt ON b.statusid = stt.statusid
			WHERE b.winlostdate BETWEEN @FromDate AND @ToDate
				AND b.custid = @CustId
				AND EXISTS (	SELECT 1
								FROM bodb02.dbo.PayoutTrans AS pt WITH (NOLOCK)
								WHERE pt.refno = b.transid AND pt.PayoutStatus IN ('Completed', 'Expired'))
		END
	END

	--CALL to get ticket info
	EXEC [dbo].[Age_CoreBetList_BetTicket_SelMainInfoArc]
		@tempCust = @tempCust,
		@ColumnOutput = @ColumnOutput
END



GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_MemArc_SelBetTicket] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_MemArc_SelBetTicket] TO [bodbDownlineNetView]
GO