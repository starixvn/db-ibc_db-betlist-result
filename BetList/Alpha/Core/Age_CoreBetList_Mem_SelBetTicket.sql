USE [bodb02]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Age_CoreBetList_Mem_SelBetTicket]
(
	-- MEM INFO
	@CustId				INT				= NULL
	, @UserName			NVARCHAR(50)	= NULL
	, @FromDate			DATE
	, @ToDate			DATE
	, @MoveBetsDay		DATE			= NULL
	, @BalanceUpDay		DATE			= NULL
	-- PRODUCT - BETTYPE - STATUS
	, @TransStatus		[dbo].[TVP_BetTicketStatus]		READONLY
	, @BettypeMatrix	[dbo].[TVP_SportBettypeMatrix]	READONLY
	, @TransType		INT				= 0
	-- PAGING
	, @PageIndex		INT				= 1
	, @PageSize			INT				= 5000
	, @Language			VARCHAR(2)		= 'E'
	-- OPTIONAL
	, @ColumnOutput		VARCHAR(MAX)	= NULL
	-- OUTPUT INFO
	, @TotalRows		INT 			= 0 OUTPUT
	, @Error			INT 			= 0 OUTPUT
	, @ErrorMsg			VARCHAR(250)	= '' OUTPUT
)
AS

/*
	Created: Bobby.Nguyen
	Task: Re-factor core betlist and apply GD product
	DB: DBAGE.bodb02
	Original:

	Revisions:
		- 20150504@Bobby: Create new SP
		- 20150706@Bobby: Exclude Metric Gaming running ticket from bettrans table
		- 20150831@Kos: Support Colossus Bet
		- 20150909@Kos: Add TransType params to support Colossus Bet Grand Prize ticket
		- 20150910@Bobby: Enhance performance for SP core. Apply TVP for input parameters
		- 20151223@Kos: Support Cockfighting [#Redmine: 48850]
		- 20160108@Kos: Support Colossus Bet ticket flow change [#Redmine: 49967]
		- 20160111@Kos: Add @TransStatus param to support RNG Casino Single Wallet [#Redmine: 48958]
		- 20160125@Kos: Fix performance issue with today RNG Casino Single Wallet ticket [#Redmine: 51388]
		- 20160216@Kos: Support yesterday running ticket for Casino products
		- 20160217@Kos: Support AllBet [Redmine: #50864]
		- 20160323@Kos: Hotfix - Colossus Bet Grand Prize ticket in bettrans14 [#Redmine: 54643]
		- 20160328@Kos: Support Grand Prize ticket which status is Expired
		- 20160404@Kos: Support Macau Games [Redmine: #54925]
		- 20160518@Francis: Use local variables to avoid bad parameter sniffing
		- 20161101@Kos: Support Fishing World [#Redmine: 65934]
		- 20170705@Kos: Support Keno Lottery [#Redmine: 77929]
		- 20171030@Kos: Support Bullfighting [#Redmine: 84961]
		- 20180202@Kos: Don't support Cockfighting [#Redmine: 86086]
		- 20180323@Kos: Support ONERnG Jackpot [#Redmine: 88652]
		- 20180418@Kos: Support Pragmatic Casino [#Redmine: 92160]

	Param's Explanation:
		- @BettypeMatrix	: XML.format(<BettypeMatrix><row ProductID="1" Bettype="1" EventType="1" /></BettypeMatrix>)
		- @TransStatus		: string formation (0,1,102,103,111,112,113)
		- @TransType		: 4: Grand Prize ticket, Others: normal ticket
		
	Wrapped SP List:
		- Age_BetList_SelWinLossByDate_Mem_xtest
		- Age_BetList_SelByDayAll_Mem_xtest
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @Recommend	INT
		, @tempCust		dbo.TVP_TicketSportBettype
	
	--Use Local variables to avoid bad params sniffing
	DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME

	-- CHECK for MoveBetsDay
	IF @MoveBetsDay IS NULL
	BEGIN
		SELECT @MoveBetsDay = MAX(Winlostdate)
		FROM bodb02.dbo.bettrans14 WITH (NOLOCK)
	END

	-- RESET output
	SELECT @TotalRows	= 0,
		@Error			= 0,
		@ErrorMsg		= ''

	-- CHECK member info
	IF @CustId IS NULL AND @UserName IS NOT NULL
	BEGIN
		SELECT @CustId = custid,
			@Recommend = recommend
		FROM bodb02.dbo.custinfo WITH (NOLOCK)
		WHERE UserName = @UserName
	END

	IF @CustId > 0
		AND (@Recommend IS NULL OR @UserName IS NULL)
	BEGIN
		SELECT @Recommend = Recommend,
			@UserName = UserName
		FROM bodb02.dbo.custinfo WITH (NOLOCK)
		WHERE custid = @CustId
	END

	IF @Recommend IS NULL
	BEGIN
		SELECT @Error 	= 100
			, @ErrorMsg	= 'The customer was not found.'

		RETURN;
	END

	DECLARE @Yesterday	SMALLDATETIME

	SELECT @Yesterday = DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)

	-- bettrans
	IF @ToDate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @FDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @FDate = @FromDate

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
			FROM bodb02.dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
				INNER JOIN @TransStatus AS stt ON b.statusid = stt.statusid
			WHERE b.winlostdate BETWEEN @FDate AND @ToDate
				AND b.recommend = @Recommend 
				AND b.custid = @CustId
				--exclude running tickets of MetricGaming
				AND ( bt.SubProduct NOT IN ('MG-SuperLive')
					OR ( bt.SubProduct IN ('MG-SuperLive') AND b.StatusId NOT IN (0, 1) )
				)
				AND ((bt.ProductId NOT IN (21, 22, 24, 32)		-- before yesterday AllBet, RNG Casino Single Wallet, Macau Games, Fishing World, Pragmatic Casino
					AND (bt.ProductId <> 6 OR bt.SubProduct = ''))
						OR b.winlostdate < @Yesterday)

			/* select running tickets (translog)
				- Keno			: ProductId = 8
				- Gold Deluxe	: ProductId = 12
				- Colossus Bet	: ProductId = 15
				- Lottery		: ProductId = 28
				- Bullfighting	: ProductId = 30
				- Sportsbook	: Metric Gaming bettype(801-899)
			*/
			IF EXISTS (SELECT TOP(1) 1 FROM @TransStatus WHERE StatusId IN (0, 1))
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
					b.translogid AS transid
					, b.translogid AS refno
					, b.custid
					, bt.ProductId
					, b.gameid
					, bt.EventType
					, 0 AS WhTicket
				FROM bodb02.dbo.translog AS b WITH (NOLOCK)
					INNER JOIN @BettypeMatrix AS bt ON b.gameid = bt.Bettype
					INNER JOIN @TransStatus AS st ON b.statusID = st.StatusID
				WHERE b.winlostdate BETWEEN @FDate AND @ToDate
					AND b.custid = @CustId
					AND (bt.ProductId IN (8, 12, 15, 28, 30)
						OR bt.Bettype BETWEEN 801 AND 899)
					AND b.statusID IN (0, 1)
			END

			/*
				Yesterday and later RNG Casino/Live Casino summary ticket
				+ RNG Casino (WhTicket = 4)
					- RNG Casino Single Wallet	: ProductId = 6 AND bettype <> 71
					- Macau Games				: ProductId = 22
					- Fishing World				: ProductId = 24
					- Pragmatic Casino			: ProductId = 32
				+ Live Casino (WhTicket = 5)
					- AllBet	: ProductId = 21
			*/
			IF @ToDate >= @Yesterday
				AND EXISTS(SELECT TOP(1) 1 FROM @TransStatus WHERE StatusId IN (0, 1, 111, 112, 113))
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
					, CASE
							WHEN bt.ProductId = 6 AND bt.SubProduct <> '' THEN 4
							WHEN bt.ProductId IN (22, 24, 32) THEN 4
							WHEN bt.ProductId = 21 THEN 5
							ELSE 0
						END AS WhTicket
				FROM bodb02.dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
				WHERE b.winlostdate BETWEEN @FDate AND @ToDate
					AND b.winlostdate >= @Yesterday
					AND b.recommend = @Recommend
					AND b.custid = @CustId
					AND (bt.ProductId IN (21, 22, 24, 32)
						OR (bt.ProductId = 6 AND bt.SubProduct <> ''))
			END
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
					, 6 AS WhTicket
				FROM bodb02.dbo.bettransRnG AS b WITH (NOLOCK)
					INNER JOIN @BettypeMatrix AS bt ON b.gameID = bt.bettype
					INNER JOIN @TransStatus AS stt ON b.statusid = stt.statusid
				WHERE b.winlostdate BETWEEN @FDate AND @ToDate
					AND b.recommend = @Recommend
					AND b.custid = @CustId
					AND bt.ProductID = 6
					AND EXISTS (	SELECT 1
									FROM DBACC.bodb02.dbo.PayoutTrans AS pt WITH (NOLOCK)
									WHERE pt.refno = b.transid AND pt.PayoutStatus IN ('Completed', 'Expired'))
			END

			-- Colossus Bets
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
					, 1 AS WhTicket
				FROM bodb02.dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
					INNER JOIN @TransStatus AS stt ON b.statusid = stt.statusid
				WHERE b.winlostdate BETWEEN @FDate AND @ToDate
					AND b.recommend = @Recommend
					AND b.custid = @CustId
					AND bt.ProductID = 15
					AND EXISTS (	SELECT 1
									FROM DBACC.bodb02.dbo.PayoutTrans AS pt WITH (NOLOCK)
									WHERE pt.refno = b.transid AND pt.PayoutStatus IN ('Completed', 'Expired'))
			END
		END
	END

	-- bettrans14
	IF @FromDate <= @MoveBetsDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TDate = @MoveBetsDay
		ELSE
			SET @TDate = @ToDate

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
			WHERE b.winlostdate BETWEEN @FromDate AND @TDate
				AND b.recommend = @Recommend
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
					, 7 AS WhTicket
				FROM bodb02.dbo.bettransRnG14 AS b WITH (NOLOCK)
					INNER JOIN @BettypeMatrix AS bt ON b.gameID = bt.bettype
					INNER JOIN @TransStatus AS stt ON b.statusid = stt.statusid
				WHERE b.winlostdate BETWEEN @FromDate AND @TDate
					AND b.recommend = @Recommend
					AND b.custid = @CustId
					AND bt.ProductID = 6
					AND EXISTS (	SELECT 1
									FROM DBACC.bodb02.dbo.PayoutTrans AS pt WITH (NOLOCK)
									WHERE pt.refno = b.transid AND pt.PayoutStatus IN ('Completed', 'Expired'))
			END

			-- Colossus Bets
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
					, 2 AS WhTicket
				FROM bodb02.dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
					INNER JOIN @TransStatus AS stt ON b.statusid = stt.statusid
				WHERE b.winlostdate BETWEEN @FromDate AND @TDate
					AND b.recommend = @Recommend
					AND b.custid = @CustId
					AND bt.ProductID = 15
					AND EXISTS (	SELECT 1
									FROM DBACC.bodb02.dbo.PayoutTrans AS pt WITH (NOLOCK)
									WHERE pt.refno = b.transid AND pt.PayoutStatus IN ('Completed', 'Expired'))
			END
		END
	END

	-- Get ticket info
	EXEC [dbo].[Age_CoreBetList_BetTicket_SelMainInfo]
		@tempCust = @tempCust,
		@TransStatus = @TransStatus,
		@ColumnOutput = @ColumnOutput
END



GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_Mem_SelBetTicket] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_Mem_SelBetTicket] TO [bodbDownlineNetView] AS [dbo]
GO
