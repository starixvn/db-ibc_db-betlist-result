USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Age_CoreBetList_Mem_SelBetTicket]    Script Date: 5/11/2015 10:31:30 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Aff_CoreBetList_Mem_SelBetTicket]
(
	-- MEM INFO
	@CustId 			INT				= NULL
	, @UserName 		NVARCHAR(30)	= NULL
	, @FromDate			DATE
	, @ToDate 			DATE
	, @MoveBetsDay 		DATE			= NULL
	, @BalanceupDay		DATE			= NULL
	-- PRODUCT - BETTYPE - STATUS
	, @TransStatus 		[dbo].[TVP_BetTicketStatus]		READONLY
	, @BettypeMatrix	[dbo].[TVP_SportBettypeMatrix]	READONLY
	, @TransType		INT 			= 0
	-- PAGING
	, @PageIndex		INT				= 1
	, @PageSize			INT				= 5000
	, @Language 		VARCHAR(2) 		= 'E'
	--OPTIONAL
	, @ColumnOutput		VARCHAR(MAX) 	= NULL
	-- OUTPUT INFO
	, @TotalRows		INT 			= 0 OUTPUT
	, @Error			INT 			= 0 OUTPUT
	, @ErrorMsg			VARCHAR(250) 	= '' OUTPUT
)
AS

/*
	Created: Bobby.Nguyen
	Task : Re-factor core betlist and apply GD product
	DB: DBEXT.bodb02
	Original: DBAGE.bodb02.dbo.Age_CoreBetList_Mem_SelBetTicket

	Revisions:
		- 20160308@Bobby: Implement LIC core bet list for Affiliate site

	Param's Explanation:
		- @TransType		: 4: Grand Prize ticket, Others: normal ticket
				
	Scope of tickets:
		- bettrans	: All products - all status
		- translog	: Keno & GD - running status only
		- bettrans14: [MoveBetDay] All product - all status
*/

BEGIN
	SET NOCOUNT ON;
	
	DECLARE @Recommend	INT
		, @tempCust		dbo.TVP_TicketSportBettype

	-- CHECK for MoveBetsDay
	IF @MoveBetsDay IS NULL
	BEGIN
		SELECT @MoveBetsDay = MAX(Winlostdate) 
		FROM bodb02.dbo.bettrans14 WITH (NOLOCK)
	END

	-- RESTET output
	SELECT @TotalRows	= 0
		,@Error			= 0
		,@ErrorMsg		= ''

	-- CHECK member info
	IF( @CustID IS NULL AND @UserName IS NOT NULL )
	BEGIN
		SELECT @CustID 	= CustID
			, @Recommend = Recommend 
		FROM bodb02.dbo.custinfo WITH (NOLOCK) 
		WHERE UserName	= @UserName
	END

	IF( @CustID > 0
		AND (@Recommend IS NULL 
			OR @UserName IS NULL
		)
	)
	BEGIN
		SELECT @Recommend = Recommend 
			,@UserName = UserName
		FROM bodb02.dbo.custinfo WITH (NOLOCK) 
		WHERE CustID = @CustID
	END

	IF @Recommend IS NULL
	BEGIN
		SELECT @Error 	= 100
			, @ErrorMsg	= 'The customer was not found.'
			
		RETURN;
	END

	-- do selecting from bettrans
	IF @ToDate > @MoveBetsDay
	BEGIN
		IF @TransType <> 4
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
				, 1 AS WhTicket
			FROM bodb02.dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @BettypeMatrix bt ON b.bettype = bt.bettype
				INNER JOIN @TransStatus stt ON b.statusid = stt.statusid
			WHERE b.winlostdate	BETWEEN @fromdate AND @todate 
				AND	b.recommend	= @Recommend 
				AND	b.custid	= @CustID
				--exclude running tickets of MetricGaming
				AND ( bt.SubProduct NOT IN ('MG-SuperLive') 
					OR ( bt.SubProduct	IN ('MG-SuperLive')	AND b.StatusId NOT IN (0, 1) )
				)
				AND (bt.ProductId <> 6 OR bt.SubProduct = ''
					OR b.winlostdate < DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0))

			/* 	select running tickets
				- Keno 			: ProductId = 8
				- Gold Deluxe	: ProductId = 12
				- Colossus Bet	: ProductId = 15
				- Cockfighting	: ProductId = 19
				- Sportsbook	: Metric Gaming bettype(801-899)
			*/
			IF EXISTS(SELECT TOP 1 1 FROM @TransStatus WHERE StatusId IN (0,1))
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
					b.translogid	AS transid
					, b.translogid 	AS refno
					, b.custid
					, bt.ProductId
					, b.gameid
					, bt.EventType
					, 0 AS WhTicket
				FROM bodb02.dbo.translog AS b WITH (NOLOCK)
					INNER JOIN @BettypeMatrix bt ON b.gameid = bt.Bettype
					INNER JOIN @TransStatus st ON b.statusID = st.StatusID
				WHERE b.winlostdate	BETWEEN @fromdate AND @todate 
					AND b.custid		= @CustID
					AND	(bt.ProductId	IN (8, 12, 15, 19)
						OR bt.Bettype BETWEEN 801 AND 899
					)
					AND b.statusID IN (0, 1)
			END

			IF @todate >= DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)
				AND @fromdate <= DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)	-- Today
				AND EXISTS(SELECT TOP 1 1 FROM @TransStatus WHERE StatusId IN (0, 1, 111, 112, 113))
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
					, 4 AS WhTicket
				FROM bodb02.dbo.bettrans b WITH (NOLOCK)
					INNER JOIN @BettypeMatrix bt ON b.bettype = bt.bettype
				WHERE b.winlostdate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0) AND @todate 
					AND b.recommend = @Recommend 
					AND b.custid = @CustID
					AND (bt.ProductId = 6 AND bt.SubProduct <> '')
			END
		END
		
		-- Grand Prize ticket
		IF @TransType = 4
		BEGIN
			-- Colossus Bet 
			IF EXISTS(SELECT TOP 1 1 FROM @BettypeMatrix WHERE ProductID = 15)
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
					, 1 AS WhTicket
				FROM bodb02.dbo.bettrans b WITH (NOLOCK)
					INNER JOIN @BettypeMatrix bt ON b.bettype = bt.bettype
					INNER JOIN @TransStatus stt ON b.statusid = stt.statusid
				WHERE b.winlostdate	BETWEEN @fromdate AND @todate 
					AND	b.recommend	= @Recommend 
					AND	b.custid	= @CustID
					AND EXISTS (	SELECT 1 
									FROM DBACC.bodb02.dbo.PayoutTrans AS pt WITH (NOLOCK)
									WHERE pt.refno = b.transid AND pt.PayoutStatus = 'Completed')
			END
		END
	END

	-- CHECK for bettrans14
	IF @FromDate <= @MoveBetsDay
	BEGIN
		IF @TransType <> 4
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
				, 2 AS WhTicket
			FROM bodb02.dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
				INNER JOIN @TransStatus AS stt ON b.statusid = stt.statusid
			WHERE b.winlostdate	BETWEEN @fromdate AND @todate 
				AND	b.recommend	= @Recommend 
				AND	b.custid	= @CustID
		END

		-- Grand Prize ticket
		IF @TransType = 4
		BEGIN
			-- Colossus Bet 
			IF EXISTS(SELECT TOP 1 1 FROM @BettypeMatrix WHERE ProductID = 15)
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
					, 1 AS WhTicket
				FROM bodb02.dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
					INNER JOIN @TransStatus AS stt ON b.statusid = stt.statusid
				WHERE b.winlostdate	BETWEEN @fromdate AND @todate 
					AND	b.recommend	= @Recommend 
					AND	b.custid	= @CustID
					AND EXISTS (	SELECT 1 
									FROM DBACC.bodb02.dbo.PayoutTrans AS pt WITH (NOLOCK)
									WHERE pt.refno = b.transid AND pt.PayoutStatus = 'Completed')
			END
		END
	END
	
	--CALL to get ticket info
	EXEC [dbo].[Aff_CoreBetList_BetTicket_SelMainInfo] 
		@tempCust = @tempCust, 
		@TransStatus = @TransStatus, 
		@ColumnOutput = @ColumnOutput
	
	RETURN;
END

GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_Mem_SelBetTicket] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_Mem_SelBetTicket] TO [bodbDownlineNetView]
GO
