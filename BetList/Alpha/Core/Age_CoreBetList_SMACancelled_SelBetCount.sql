USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_CoreBetList_SMACancelled_SelBetCount]
	@CustId				INT 			= NULL
	, @Username			NVARCHAR(30)	= NULL
	, @RoleId			INT
	-- PRODUCT - BETTYPE - STATUS
	, @TransStatus		[dbo].[TVP_BetTicketStatus]		READONLY
	, @BettypeMatrix	[dbo].[TVP_SportBettypeMatrix]	READONLY
	, @Language			VARCHAR(2)		= 'E'
	, @Error			INT 			= 0
	, @ErrorMsg			NVARCHAR(250)	= NULL
AS

/*
	Created: Bobby.Nguyen
	Task: Aphla site - refactor betlist core
	DB: DBAGE.bodb02
	Original:

	Revisions:
		- 20150504@Bobby: Create new SP
		- 20150831@Kos: Support Colossus Bet
		- 20150910@Bobby: Enhance performance for SP core. Apply TVP for input parameters
		- 20151214@Kos: Support Cockfighting (#Redmine: 48850)
		- 20160812@Kos: Support NG2

	Param's Explanation:
		- @BettypeMatrix	: XML.format(<BettypeMatrix><row ProductID="1" Bettype="1" EventType="1" /></BettypeMatrix>)
		- @TransStatus		: string formation (0,1,102,103,111,112,113)

	Wrapped SP List:
		- Age_BetList_SelDeleted_UserList_Ag
		- Age_BetList_SelDeleted_UserList_MAg
		- Age_BetList_SelDeleted_UserList_SAg
*/

BEGIN
	SET NOCOUNT ON;
	
	-- RESET output
	SELECT @Error	= 0
		, @ErrorMsg	= ''
	
	IF @custid IS NULL
	BEGIN
		SELECT @custid = custid
		FROM dbo.customer WITH (NOLOCK)
		WHERE username = @username
			AND roleid = @roleid
	END
	
	DECLARE @MemBetCount TABLE (
		custid 				INT
		, recommend			INT
		, mrecommend		INT
		, srecommend		INT
		, betcount			INT
	);

	CREATE TABLE #tempRawData (
		transid 		BIGINT
		, custid		INT
		, recommend		INT
		, mrecommend	INT
		, srecommend	INT
		, matchid		INT
		, oddsid		INT
		, productid		INT
		, eventtype		TINYINT
	)

	-- CHECK for supporting cancelled ticket only
	IF NOT EXISTS (SELECT TOP 1 1 FROM @TransStatus WHERE StatusId IN (101, 102))
	BEGIN
		SELECT * FROM @MemBetCount

		RETURN;
	END

	-- MEMBER
	IF @roleid = 1
	BEGIN
		INSERT INTO #tempRawData
		SELECT b.transid
			, b.custid
			, b.recommend
			, b.mrecommend
			, b.srecommend
			, b.matchid
			, b.oddsid
			, bt.ProductId
			, bt.EventType
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
			INNER JOIN @TransStatus AS stt ON b.statusid = stt.statusid
		WHERE b.custid = @custid
	END

	-- AGENT
	IF @roleid = 2
	BEGIN
		INSERT INTO #tempRawData
		SELECT b.transid
			,b.custid
			,b.recommend
			,b.mrecommend
			,b.srecommend
			,b.matchid
			,b.oddsid
			,bt.ProductId
			,bt.EventType
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON b.recommend = c.custid
			INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
			INNER JOIN @TransStatus AS stt ON b.statusid = stt.statusid
		WHERE c.custid = @custid
			AND c.roleid = 2
	END

	-- MASTER
	IF @roleid = 3
	BEGIN
		INSERT INTO #tempRawData
		SELECT b.transid
			,b.custid
			,b.recommend
			,b.mrecommend
			,b.srecommend
			,b.matchid
			,b.oddsid
			,bt.ProductId
			,bt.EventType
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON b.recommend = c.custid
			INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
			INNER JOIN @TransStatus AS stt ON b.statusid = stt.statusid
		WHERE c.mrecommend = @custid
			AND c.roleid = 2
	END

	-- SUPER
	IF @roleid = 4
	BEGIN
		INSERT INTO #tempRawData
		SELECT b.transid
			,b.custid
			,b.recommend
			,b.mrecommend
			,b.srecommend
			,b.matchid
			,b.oddsid
			,bt.ProductId
			,bt.EventType
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.recommend = c.custid
			INNER JOIN @BettypeMatrix bt ON b.bettype = bt.bettype
			INNER JOIN @TransStatus stt ON b.statusid = stt.statusid
		WHERE c.srecommend = @custid
			AND c.roleid = 2
	END

	/*	- Mix & System Parlay	: ProductId = 1
		- P2P tickets			: ProductId = 9
		- Casino				: ProductId = 6
		- Bingo					: ProductId = 7
		- Keno					: ProductId = 8
		- Gold Deluxe			: ProductId = 12
		- Colossus Bet			: ProductId = 15
		- Cockfighting			: ProductId = 19
		- NG2					: ProductId = 23
	*/
	IF EXISTS(SELECT TOP 1 1 FROM #tempRawData WHERE EventType IN (0))
	BEGIN
		INSERT INTO @MemBetCount
		SELECT
			b.custid
			, b.recommend
			, b.mrecommend
			, b.srecommend
			, COUNT(1) AS betcount
		FROM #tempRawData AS b
		WHERE b.EventType = 0
			AND b.ProductID IN (6, 7, 8, 9, 12, 15, 19, 23)
		GROUP BY b.custid
			, b.recommend
			, b.mrecommend
			, b.srecommend
	END

	/* normal tickets 
		- SB	: ProductID = 1
		- NG	: ProductID = 3
		- LC	: ProductID = 4
		- VS	: ProductID = 5
	*/
	IF EXISTS(SELECT TOP 1 1 FROM #tempRawData s WHERE s.EventType IN (1))
	BEGIN
		WITH CteMatch 
		AS(
			SELECT matchid
			FROM dbo.match WITH (NOLOCK)
			WHERE eventdate > DATEADD(DAY, -3, CURRENT_TIMESTAMP)
		)

		INSERT INTO @MemBetCount
		SELECT
			b.custid
			, b.recommend
			, b.mrecommend
			, b.srecommend
			, COUNT(1) AS betcount
		FROM #tempRawData AS b
			INNER JOIN CteMatch AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.EventType = 1
		GROUP BY b.custid
			, b.recommend
			, b.mrecommend
			, b.srecommend
	END

	/* 
		- SB outright	: ProductID = 1
		- HR			: ProductID = 2
	*/
	IF EXISTS(SELECT TOP 1 1 FROM #tempRawData s WHERE s.EventType IN (2))
	BEGIN
		WITH CteOutright 
		AS(
			SELECT leagueid, orid
			FROM dbo.outright (NOLOCK) 
			WHERE eventdate > DATEADD(DAY, -3, CURRENT_TIMESTAMP)
		)

		INSERT INTO @MemBetCount
		SELECT
			b.custid
			, b.recommend
			, b.mrecommend
			, b.srecommend
			, COUNT(1) AS betcount
		FROM #tempRawData AS b
			INNER JOIN CteOutright AS m WITH (NOLOCK) ON b.matchid = m.orid
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
		WHERE b.EventType = 2
		GROUP BY b.custid
			, b.recommend
			, b.mrecommend
			, b.srecommend
	END

	/*
		- VS	: ProductID = 3
	*/
	IF EXISTS(SELECT TOP 1 1 FROM #tempRawData s WHERE s.EventType IN (3))
	BEGIN
		WITH CteVSOutright
		AS(
			SELECT o.Orid
			FROM dbo.VSOutright AS o WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE EventDate > DATEADD(DAY, -3, CURRENT_TIMESTAMP)
		)

		INSERT INTO @MemBetCount
		SELECT
			b.custid
			, b.recommend
			, b.mrecommend
			, b.srecommend
			, COUNT(1) AS betcount
		FROM #tempRawData AS b
			INNER JOIN CteVSOutright AS o with (NOLOCK) ON b.oddsid = o.Orid
		WHERE b.EventType = 3
		GROUP BY b.custid
			, b.recommend
			, b.mrecommend
			, b.srecommend
	END
	
	;WITH SumBetcount (custid, betcount)
	AS (
		SELECT
			CASE WHEN @roleid = 3 THEN b.recommend 
				WHEN @roleid = 4 THEN b.mrecommend 
				ELSE b.custid 
			END	AS custid
			, SUM(b.betcount) AS betcount
		FROM @MemBetCount b
		GROUP BY
			CASE WHEN @roleid = 3 THEN b.recommend
				WHEN @roleid = 4 THEN b.mrecommend
				ELSE b.custid
			END
	)

	SELECT
		s.custid,
		c.username,
		s.betcount
	FROM SumBetcount AS s
		INNER JOIN dbo.customer AS c WITH(NOLOCK) ON s.custid = c.custid 
	ORDER BY s.betcount DESC

	RETURN;
END

GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_SMACancelled_SelBetCount] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_SMACancelled_SelBetCount] TO [bodbDownlineNetView]
GO
