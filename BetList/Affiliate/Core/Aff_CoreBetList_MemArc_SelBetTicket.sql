/*<info serverAlias="DBARC-bodb_Archive" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE [bodb_Archive]
GO
/****** Object:  StoredProcedure [dbo].[Aff_CoreBetList_MemArc_SelBetTicket]    Script Date: 5/22/2017 11:20:07 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Aff_CoreBetList_MemArc_SelBetTicket]
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
AS

/*
	Created: Bobby.Nguyen
	Task: Core bet list for Affiliate
	DB: DBARC.bodb_Archive
	Original: DBARC.bodb_Archive.dbo.Age_CoreBetList_MemArc_SelBetTicket

	Revisions:
		- 20170519@Kos: Clone from original SP and support CashOut [#Redmine: 71963]

	Param's Explanation:
		- @TransStatus	: string formation (0,1,102,103,111,112,113)
		- @TransType	: 4: Grand Prize ticket, Others: normal ticket

	Wrapped SP List:
		- Aff_BetList_SelWinLossByDate_Old

	Dependences:
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @Recommend	INT
		, @Username		NVARCHAR(30)
		, @tempCust		dbo.TVP_TicketSportBettype

	SELECT @Error	= 0
		, @ErrorMsg	= ''

	SELECT @Recommend	= Recommend
		,@UserName		= UserName
	FROM bodb02.dbo.custinfo WITH (NOLOCK)
	WHERE custid = @CustId

	IF @Recommend IS NULL
	BEGIN
		SELECT @Error 	= 100
			, @ErrorMsg	= 'The customer was not found.'

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
		-- Colossus Bet
		IF EXISTS (SELECT TOP 1 1 FROM @BettypeMatrix WHERE ProductID = 15)
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

	-- CALL to get ticket info
	EXEC [dbo].[Aff_CoreBetList_BetTicket_SelMainInfoArc] @tempCust = @tempCust, @ColumnOutput = @ColumnOutput

	RETURN;
END




GO
GRANT EXECUTE ON [dbo].[Aff_CoreBetList_MemArc_SelBetTicket] TO [bodbAdminNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Aff_CoreBetList_MemArc_SelBetTicket] TO [bodbDownlineNet] AS [dbo]
GO
