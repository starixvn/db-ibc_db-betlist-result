/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[U3_BetList_SelWinlossByBettypeMatch_Ag]
	@MatchId		INT,
	@CustId			INT			= NULL,
	@Username		VARCHAR(50)	= NULL,
	@BetType		INT,
	@Language		VARCHAR(2)	= 'E',
	@LiveIndicator	INT			= 0
AS

/*
	Created: Kos@20170810
	Task: Match Win Lost bet list of U3
	DB: DBAGE.bodb02
	Original: Age_BetList_SelWinlossByBettypeMatch_Ag
	Revisions:
		- 20170810@Kos: Support Lucky 3 [#Redmine: 75277]
		- 20211102@Razor: Extend Data type of IP v6 [Redmine: #90903]
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @TransStatus	[dbo].[TVP_BetTicketStatus]
		, @BettypeMatrix	[dbo].[TVP_SportBettypeMatrix]

	-- Gather Ticket Status
	INSERT INTO @TransStatus
	SELECT StatusId
	FROM dbo.All_f_TransStatus (1) stt
	WHERE statusid IN (111, 112, 113)

	-- Gather BettypeMatrix
	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @BettypeMatrix
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID IN (1, 3, 26)

	;WITH CteBettype (bettype)
	AS (
		SELECT bt.bettype
		FROM @BettypeMatrix bt
			LEFT JOIN (SELECT Bettype, GroupTypeId FROM [dbo].[f_GroupBettype]()) AS f ON f.bettype = bt.bettype
		WHERE bt.bettype = @BetType OR f.GroupTypeId = @BetType
	)

	DELETE bt
	FROM @BettypeMatrix AS bt
		LEFT JOIN CteBettype AS ct ON bt.bettype = ct.bettype
	WHERE ct.bettype IS NULL

	DECLARE @IsBet14	BIT,
		@tempCust		dbo.TVP_TicketSportBettype

	--CHECK bettrans14
	SELECT TOP(1) @IsBet14 = CAST(1 AS BIT)
	FROM dbo.match14 WITH (NOLOCK)
	WHERE matchid = @MatchId

	SET @IsBet14 = ISNULL(@IsBet14, 0)

	IF @CustId IS NULL
	BEGIN
		SELECT @CustId = custid
		FROM dbo.customer WITH (NOLOCK)
		WHERE username = @Username
	END

	CREATE TABLE #tempRawData (
		TransId		BIGINT,
		RefNo		BIGINT,
		CustId		INT,
		ProductId	TINYINT,
		BetType		SMALLINT,
		EventType	TINYINT,
		WhTicket	TINYINT
	)

	-- from bettrans
	IF @IsBet14 = 0
	BEGIN
		INSERT INTO #tempRawData
		SELECT b.transid,
			b.refno,
			b.custid,
			bt.ProductId,
			b.bettype,
			bt.EventType,
			1 AS WhTicket
		FROM dbo.bettrans AS b WITH(NOLOCK)
			INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
			INNER JOIN @TransStatus AS stt ON b.statusid = stt.statusid
		WHERE b.recommend = @CustId
			AND b.matchid = @MatchId
			AND (bt.SubProduct NOT IN ('MG-SuperLive')
				OR bt.SubProduct IN ('MG-SuperLive') AND b.StatusId NOT IN (0, 1))
	END

	IF @IsBet14 = 1 -- from bettrans14
	BEGIN
		INSERT INTO #tempRawData
		SELECT
			b.transid,
			b.refno,
			b.custid,
			bt.ProductId,
			b.bettype,
			bt.EventType,
			2 AS WhTicket
		FROM dbo.bettrans14 b WITH (NOLOCK)
			INNER JOIN @BettypeMatrix bt ON b.bettype = bt.bettype
			INNER JOIN @TransStatus stt ON b.statusid = stt.statusid
		WHERE b.recommend = @CustId
			AND b.matchid = @MatchId
	END

	IF EXISTS (SELECT TOP(1) 1 FROM #tempRawData WHERE ProductId = 3 AND EventType = 1 )
	BEGIN
		IF @IsBet14 = 0
		BEGIN
			DELETE c
			FROM #tempRawData c
				INNER JOIN dbo.bettrans b WITH (NOLOCK)
					ON c.transid = b.transid AND c.custid = b.custid
			WHERE c.WhTicket = 1
				AND c.ProductId = 3
				AND c.EventType = 1
				AND (@LiveIndicator IS NOT NULL AND b.Liveindicator <> @LiveIndicator)
		END
		
		IF @IsBet14 = 1
		BEGIN
			DELETE c
			FROM #tempRawData c
				INNER JOIN dbo.bettrans14 b WITH (NOLOCK)
					ON c.transid = b.transid AND c.custid = b.custid
			WHERE c.WhTicket = 2
				AND c.ProductId = 3
				AND c.EventType = 1
				AND (@LiveIndicator IS NOT NULL AND b.Liveindicator <> @LiveIndicator)
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
	
	-- CREATE output main info ticket
	CREATE TABLE #MemBetTicket (
		TransId				BIGINT
		, RefNo				BIGINT
		, CustId			INT
		, Username			NVARCHAR(50)
		, SportType			SMALLINT
		, BetType			SMALLINT
		, BetId				BIGINT
		, BetTeam			NVARCHAR(20)
		, Hdp1				SMALLMONEY
		, Hdp2				SMALLMONEY
		, OddsType			TINYINT
		, OddsId			INT
		, Odds				MONEY 
		, MOdds				MONEY
		, Stake				MONEY
		, Actual_Stake		MONEY
		, Status			NVARCHAR(10)
		, TransDate			DATETIME
		, WinLostDate		DATETIME
		, WinLost			MONEY
		, AWinLost			MONEY
		, MWinLost			MONEY
		, SWinLost			MONEY
		, PlayerComm		MONEY
		, Comm				MONEY
		, AComm				MONEY
		, SComm				MONEY
		, APositionTaking	SMALLMONEY
		, MPositionTaking	SMALLMONEY
		, SPositionTaking	SMALLMONEY
		, TPositionTaking	SMALLMONEY
		, ADiscount			SMALLMONEY
		, MDiscount			SMALLMONEY
		, SDiscount			SMALLMONEY
		, LiveIndicator		BIT
		, LiveHomeScore		SMALLINT
		, LiveAwayScore		SMALLINT
		, FinalHomeScore	SMALLINT
		, FinalAwayScore	SMALLINT
		, HtHomeScore		SMALLINT
		, HtAwayScore		SMALLINT
		, Ip				VARCHAR(45)
		, LeagueId			INT
		, MatchId			INT
		, MatchCode			NVARCHAR(50)
		, Race				NVARCHAR(20)
		, EventDate			DATETIME
		, HomeId			INT
		, AwayId			INT
		, BetStatus			NVARCHAR(50)
		, IsNeutral			BIT
		, Placing			NVARCHAR(20)
		, ShowTime			NVARCHAR(50)
		, BetCheck			NVARCHAR(50)
		, ComStatus			NVARCHAR(20)
		, TransDesc			NVARCHAR(1000)
		, OddsSpread		SMALLMONEY
	);

	-- bettrans
	IF EXISTS (SELECT TOP 1 1 FROM @tempCust WHERE WhTicket = 1)
	BEGIN
		/* 
		- Sportsbook	: ProductID = 1
		- Number Game	: ProductID = 3
		- Lucky 3		: ProductID = 26
		*/
		INSERT INTO #MemBetTicket
		SELECT
			b.transid
			, b.refno
			, b.custid
			, b.username
			, m.sporttype
			, b.bettype
			, ISNULL(b.betid, 0) AS BetId
			, b.betteam
			, b.hdp1
			, CASE
				WHEN c.ProductID IN (3, 26) THEN 0
				ELSE b.hdp2
			END AS hdp2
			, b.oddstype
			, b.oddsid
			, b.odds
			, b.modds
			, b.stake
			, b.actual_stake
			, CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status
			, b.transdate
			, b.winlostdate
			, (b.winlost - b.actual_stake) AS winlost
			, b.awinlost
			, b.mwinlost
			, b.swinlost
			, b.playercomm
			, (b.comm - b.playercomm) AS comm
			, (b.acomm - b.comm) AS acomm
			, (b.scomm - b.acomm) AS scomm
			, b.APositiontaking
			, b.MPositiontaking
			, b.SPositiontaking
			, b.TPositiontaking
			, CASE
				WHEN c.ProductID = 26 THEN 0
				ELSE b.discount
			END AS ADiscount
			, CASE
				WHEN c.ProductID = 26 THEN 0
				ELSE b.adiscount
			END AS MDiscount
			, CASE
				WHEN c.ProductID = 26 THEN 0
				ELSE b.sdiscount
			END AS SDiscount
			, b.liveindicator
			, b.livehomescore
			, b.liveawayscore
			, m.finalhomescore
			, m.finalawayscore
			, m.hthomescore
			, m.htawayscore
			, b.ip
			, m.leagueid
			, m.matchid
			, m.matchcode
			, '' AS Race
			, m.eventdate
			, m.homeid
			, m.awayid
			, m.betstatus
			, ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral
			, '' AS Placing
			, ISNULL(m.showtime, '') AS ShowTime
			, CASE
				WHEN (c.ProductId = 1 AND b.bettype IN (216, 217)) THEN b.betcheck
				ELSE ''
			END AS BetCheck
			, CASE WHEN b.comstatus = '1' THEN '1' 
				ELSE '0' 
			END AS comstatus
			, CASE
				WHEN c.ProductID IN (1, 26) THEN ISNULL(b.transdesc, '')
				ELSE ''
			END AS TransDesc
			, CASE
				WHEN c.ProductID = 1 THEN ISNULL(b.oddsspread, 0)
				ELSE 0
			END AS OddsSpread
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN @tempCust AS c ON b.transid = c.transid
		WHERE c.WhTicket = 1 AND c.EventType = 1
	END

	-- bettrans14
	IF EXISTS (SELECT TOP(1) 1 FROM @tempCust WHERE WhTicket = 2)
	BEGIN
		/*
		- Sportsbook	: ProductID = 1
		- Number Game	: ProductID = 3
		- Lucky 3		: ProductID = 26
		*/
		INSERT INTO #MemBetTicket
		SELECT
			b.transid
			, b.refno
			, b.custid
			, b.username
			, m.sporttype
			, b.bettype
			, ISNULL(b.betid, 0) AS BetId
			, b.betteam
			, CASE
				WHEN c.ProductID IN (4) THEN 0
				ELSE b.hdp1
			END AS hdp1
			, CASE
				WHEN c.ProductID IN (3, 26) THEN 0
				ELSE b.hdp2
			END AS hdp2
			, b.oddstype
			, b.oddsid
			, b.odds
			, b.modds
			, b.stake
			, b.actual_stake
			, CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status
			, b.transdate
			, b.winlostdate
			, (b.winlost - b.actual_stake) AS WinLost
			, b.awinlost
			, b.mwinlost
			, b.swinlost
			, b.PlayerComm
			, (b.comm - b.playercomm) AS comm
			, (b.acomm - b.comm) AS acomm
			, (b.scomm - b.acomm) AS scomm
			, b.APositiontaking
			, b.MPositiontaking
			, b.SPositiontaking
			, b.TPositiontaking
			, CASE
				WHEN c.ProductID = 26 THEN 0
				ELSE b.discount
			END AS ADiscount
			, CASE
				WHEN c.ProductID = 26 THEN 0
				ELSE b.adiscount
			END AS MDiscount
			, CASE
				WHEN c.ProductID = 26 THEN 0
				ELSE b.sdiscount
			END AS SDiscount
			, b.liveindicator
			, b.livehomescore
			, b.liveawayscore
			, m.finalhomescore
			, m.finalawayscore
			, m.hthomescore
			, m.htawayscore
			, b.ip
			, m.leagueid
			, m.matchid
			, m.matchcode
			, '' AS Race
			, m.eventdate
			, m.homeid
			, m.awayid
			, m.Betstatus
			, ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral
			, '' AS Placing
			, CASE
				WHEN c.ProductId = 5 THEN CONVERT(NVARCHAR(50), m.kickofftime)
				ELSE ISNULL(m.showtime, '')
			END AS ShowTime
			, CASE
				WHEN (c.ProductId = 1 AND b.bettype IN (154,155,156,216,217,1311,1312,1316,1317,1318,1324)) THEN b.betcheck
				ELSE '' 
			END AS BetCheck
			, CASE
				WHEN b.comstatus = '1' THEN '1'
				ELSE '0'
			END AS comstatus
			, CASE
				WHEN c.ProductID IN (1, 26) THEN ISNULL(b.transdesc, '')
				ELSE ''
			END AS TransDesc
			, CASE
				WHEN c.ProductID = 1 THEN ISNULL(b.oddsspread, 0)
				ELSE 0
			END AS OddsSpread
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN @tempCust AS c ON b.transid = c.transid
		WHERE c.WhTicket = 2 AND c.EventType = 1
	END

	SELECT
		t.*,
		e.currency
	FROM #MemBetTicket AS t
		LEFT JOIN dbo.custInfo AS ci WITH (NOLOCK) ON t.CustId = ci.custid
		LEFT JOIN dbo.Exchange AS e WITH (NOLOCK) ON ci.Currency = e.exchangeid
	ORDER BY t.TransId DESC

	RETURN;
END
GO