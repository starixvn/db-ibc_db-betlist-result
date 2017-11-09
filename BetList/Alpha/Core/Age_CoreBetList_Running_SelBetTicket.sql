USE [bodb_AGE]
GO
/****** Object:  StoredProcedure [dbo].[Age_CoreBetList_Running_SelBetTicket]    Script Date: 5/5/2015 1:45:13 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Age_CoreBetList_Running_SelBetTicket]
(
	-- MEM INFO
	@CustId				INT
	, @RoleId			TINYINT
	, @Username			NVARCHAR(50)	= NULL
	, @FromDate			DATETIME		= NULL
	, @ToDate			DATETIME		= NULL
	--Event
	, @MatchId			INT				= 0
	, @LiveIndicator	INT				= NULL
	, @BetTeam			NVARCHAR(20)	= ''
	-- PRODUCT - BETTYPE - STATUS
	, @BettypeMatrix	[dbo].[TVP_SportBettypeMatrix]	READONLY
	, @Language			VARCHAR(2)		= 'E'
	, @ColumnOutput		VARCHAR(MAX)	= NULL
	, @Error			INT				= 0 OUTPUT
	, @ErrorMsg			VARCHAR(250)	= '' OUTPUT
)
AS

/*
	Created: Bobby
	Task: Aphla site - refactor betlist core 
	DB: DBAGE.bodb_AGE
	Original:

	Revisions:
		- 20150504@Bobby: Create new SP
		- 20150706@Bobby: Exclude Metric Gaming running ticket from bettrans table
		- 20150814@Bobby: #41600 - Update time range to datetime formation
		- 20150910@Bobby: Enhance performence for SP core. Apply TVP for input parameters
		- 20150925@Bobby: Add MO & CB ticket
		- 20151217@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20151217@Kos: Support Cockfighting (#Redmine: 48850)
		- 20171109@Kos: Return IsNeutral for neutral match [#Redmine: 86312]

	Param's Explanation:
		- @BettypeMatrix	: Table TYPE variable

	Wrapped SP List:
		- Age_BetList_SelRunningByBettype_Ag
		- Age_BetList_SelRunningByBettype_MAg
		- Age_BetList_SelRunningByBettypeMatch_SAg

	Scope of tickets:
		- bettrans	: All products - all status
		- translog	: Keno, Gold Deluxe, Colossus Bet, Cockfighting - running status only
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @tempRunning TABLE (
		SportType			SMALLINT
		, CustId			INT
		, Username			NVARCHAR(50)
		, BetType			SMALLINT
		, LeagueId			INT
		, RefNo				BIGINT
		, TransId			BIGINT
		, BetId				BIGINT
		, MatchCode			NVARCHAR(50)
		, Race				NVARCHAR(20)
		, MatchId			INT
		, HomeId			INT
		, AwayId			INT 
		, Hdp1				SMALLMONEY 
		, Hdp2				SMALLMONEY 
		, Odds				MONEY 
		, MOdds				MONEY 
		, Status			NVARCHAR(10)
		, Stake				MONEY 
		, Actual_Stake		MONEY 
		, Transdate			DATETIME
		, BetTeam			NVARCHAR(20)
		, APositionTaking	SMALLMONEY
		, MPositionTaking	SMALLMONEY
		, SPositionTaking	SMALLMONEY
		, TPositionTaking	SMALLMONEY 
		, ADiscount			SMALLMONEY
		, MDiscount			SMALLMONEY
		, SDiscount			SMALLMONEY
		, LiveIndicator		BIT
		, LiveHomeScore		SMALLINT
		, LivAawayScore		SMALLINT
		, Ip				NVARCHAR(15)
		, IsNeutral			BIT
		, OddsType			TINYINT
		, ShowTime			NVARCHAR(50) 
		, ComStatus			NVARCHAR(20)
		, BetCheck			NVARCHAR(50)
		, TransDesc			NVARCHAR(300)
		, OddsSpread		SMALLMONEY
		, ProductId			TINYINT
		, EventType			TINYINT
	)

	SELECT @Error	= 0
		, @ErrorMsg	= ''
		, @CustId	= ISNULL(@CustId, 0)
		, @MatchId	= ISNULL(@MatchId, 0)
		, @BetTeam	= ISNULL(@BetTeam, '')

	-- CHECK member info
	IF( (@CustId = 0 AND @RoleId = 1)
		AND @UserName IS NOT NULL
	)
	BEGIN
		SELECT TOP(1) @CustId = custid
		FROM bodb02.dbo.custinfo WITH (NOLOCK)
		WHERE username = @UserName
	END

	IF ISNULL(@CustId, 0) = 0
	BEGIN
		SELECT @Error 	= 100
			, @ErrorMsg	= 'The customer was not found.'

		RETURN;
	END

	IF @RoleId = 1
	BEGIN
		INSERT INTO @tempRunning
		SELECT
			0 Sporttype
			, b.custid
			, b.Username
			, b.Bettype
			, 0 LeagueID
			, b.refno
			, b.TransID
			, b.BetID
			, '' MatchCode
			, '' Race
			, b.matchid
			, 0 HomeID
			, 0 AwayID
			, b.hdp1
			, b.hdp2
			, b.Odds
			, b.Modds
			,CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status
			, b.Stake
			, b.actual_stake
			, b.Transdate
			, b.Betteam
			, b.APositiontaking
			, b.MPositiontaking
			, b.SPositiontaking
			, b.tpositiontaking
			, b.discount AS Adiscount --Agent
			, b.adiscount AS Mdiscount --Master
			, b.sdiscount AS Sdiscount --Super
			, b.Liveindicator
			, b.Livehomescore
			, b.Liveawayscore
			, b.IP
			,CONVERT(BIT,0) IsNeutral
			, b.oddstype
			, '' showtime
			, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
			, b.BetCheck
			, '' AS transdesc
			, CASE WHEN bt.SubProduct IN ('MO') THEN b.OddsSpread ELSE 0 END AS OddsSpread
			, bt.productid
			, bt.eventtype
		FROM dbo.bettrans_running AS b WITH (NOLOCK)
			INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
		WHERE b.custid = @CustId
			AND bt.SubProduct NOT IN ('MG-SuperLive')
			AND b.statusID IN (0, 1)
			AND b.transdate BETWEEN @FromDate AND @ToDate
	END

	IF @RoleId = 2
	BEGIN
		INSERT INTO @tempRunning
		SELECT
			0 Sporttype
			, b.custid
			, b.Username
			, b.Bettype
			, 0 LeagueID
			, b.refno
			, b.TransID
			, b.BetID
			, '' MatchCode
			, '' Race
			, b.matchid
			, 0 HomeID
			, 0 AwayID
			, b.hdp1
			, b.hdp2
			, b.Odds
			, b.Modds
			,CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status
			, b.Stake
			, b.actual_stake
			, b.Transdate
			, b.Betteam
			, b.APositiontaking
			, b.MPositiontaking
			, b.SPositiontaking
			, b.tpositiontaking
			, b.discount AS Adiscount --Agent
			, b.adiscount AS Mdiscount --Master
			, b.sdiscount AS Sdiscount --Super
			, b.Liveindicator
			, b.Livehomescore
			, b.Liveawayscore
			, b.IP
			,CONVERT(BIT,0) IsNeutral
			, b.oddstype
			, '' showtime
			,CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
			, b.BetCheck
			, ''transdesc
			, CASE WHEN bt.SubProduct IN ('MO') THEN b.OddsSpread ELSE 0 END AS OddsSpread
			, bt.productid
			, bt.eventtype
		FROM dbo.bettrans_running AS b WITH (NOLOCK)
			INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
		WHERE b.recommend = @CustId
			AND bt.SubProduct NOT IN ('MG-SuperLive')
			AND b.statusID IN (0,1)
			AND (@MatchId = 0 OR b.matchid = @MatchId)
	END
	
	IF @RoleId = 3
	BEGIN
		INSERT INTO @tempRunning
		SELECT 
			0 Sporttype
			, b.custid
			, b.Username
			, b.Bettype
			, 0 LeagueID
			, b.refno
			, b.TransID
			, b.BetID
			, '' MatchCode
			, '' Race
			, b.matchid
			, 0 HomeID
			, 0 AwayID
			, b.hdp1
			, b.hdp2
			, b.Odds
			, b.Modds
			,CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status
			, b.Stake
			, b.actual_stake
			, b.Transdate
			, b.Betteam
			, b.APositiontaking
			, b.MPositiontaking
			, b.SPositiontaking
			, b.tpositiontaking
			, b.discount AS Adiscount --Agent
			, b.adiscount AS Mdiscount --Master
			, b.sdiscount AS Sdiscount --Super
			, b.Liveindicator
			, b.Livehomescore
			, b.Liveawayscore
			, b.IP
			,CONVERT(BIT,0) IsNeutral
			, b.oddstype
			, '' showtime
			,CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
			, b.BetCheck
			, ''transdesc
			, CASE WHEN bt.SubProduct IN ('MO') THEN b.OddsSpread ELSE 0 END AS OddsSpread
			, bt.productid
			, bt.eventtype
		FROM dbo.bettrans_running AS b WITH (NOLOCK)
			INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
		WHERE b.mrecommend = @CustId
			AND bt.SubProduct NOT IN ('MG-SuperLive')
			AND b.statusID IN (0,1)
			AND (@MatchId = 0 OR b.matchid = @MatchId)
	END
	
	IF @RoleId = 4
	BEGIN
		INSERT INTO @tempRunning
		SELECT 
			0 Sporttype
			, b.custid
			, b.Username
			, b.Bettype
			, 0 LeagueID
			, b.refno
			, b.TransID
			, b.BetID
			, '' MatchCode
			, '' Race
			, b.matchid
			, 0 HomeID
			, 0 AwayID
			, b.hdp1
			, b.hdp2
			, b.Odds
			, b.Modds
			,CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status
			, b.Stake
			, b.actual_stake
			, b.Transdate
			, b.Betteam
			, b.APositiontaking
			, b.MPositiontaking
			, b.SPositiontaking
			, b.tpositiontaking
			, b.discount AS Adiscount --Agent
			, b.adiscount AS Mdiscount --Master
			, b.sdiscount AS Sdiscount --Super
			, b.Liveindicator
			, b.Livehomescore
			, b.Liveawayscore
			, b.IP
			,CONVERT(BIT,0) IsNeutral
			, b.oddstype
			, '' showtime
			,CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
			, b.BetCheck
			, ''transdesc
			, CASE WHEN bt.SubProduct IN('MO') THEN b.OddsSpread ELSE 0 END AS OddsSpread
			, bt.productid
			, bt.eventtype
		FROM dbo.bettrans_running b WITH (NOLOCK)
			INNER JOIN @BettypeMatrix bt ON b.bettype = bt.bettype
		WHERE b.srecommend = @CustId
			AND bt.SubProduct NOT IN ('MG-SuperLive')
			AND b.statusID IN (0,1)
			AND (@MatchId = 0 OR b.matchid 	= @MatchId)
			
	END

	/* translog - running tickets
		- Keno			: ProductId = 8
		- Gold Deluxe	: ProductId = 12
		- Metric Gaming	: Bettype(801-899)
	*/
	IF (@RoleId = 1 
		AND EXISTS (SELECT TOP(1) 1 FROM @BettypeMatrix WHERE ProductId IN (8, 12) OR SubProduct IN ('MG-SuperLive')))
	BEGIN
		INSERT INTO @tempRunning
		SELECT
			CASE
				WHEN bt.ProductID = 8 THEN 202
				WHEN bt.ProductID = 12 THEN 255
				WHEN bt.SubProduct IN ('MG-SuperLive') THEN 1
				WHEN bt.ProductID = 15 THEN 204
				WHEN bt.ProductID = 19 THEN 206
				ELSE 0
			END AS Sporttype
			, b.custid
			, b.Username
			, b.gameid AS Bettype
			, 0 LeagueID
			, b.translogid AS refno
			, b.translogid AS TransID
			, 0 BetID
			, '' MatchCode
			, '' Race
			,CASE
				WHEN bt.ProductID = 8 THEN fnc.GameId 
				WHEN bt.ProductID = 12 THEN 255 
				WHEN bt.SubProduct IN ('MG-SuperLive') THEN b.eventID
				WHEN bt.ProductID = 19 THEN b.eventID
				ELSE 0 
			END AS matchid
			, 0 HomeID
			, 0 AwayID
			, 0 hdp1
			, 0 hdp2
			, b.Odds
			, 0 Modds
			, b.status
			, b.Stake
			, b.actual_stake
			, b.Transdate
			,CASE 
				WHEN bt.ProductID = 8 THEN fnc.ChoiceId 
				ELSE '' 
			END AS betteam
			, b.APositiontaking
			, b.MPositiontaking
			, b.SPositiontaking
			, b.tpositiontaking
			, b.discount AS Adiscount --Agent
			, b.adiscount AS Mdiscount --Master
			, b.sdiscount AS Sdiscount --Super
			, b.Liveindicator
			, 0 Livehomescore
			, 0 Liveawayscore
			, b.IP
			, CONVERT(BIT,0) IsNeutral
			, CASE
				WHEN bt.SubProduct IN ('MG-SuperLive') THEN CONVERT(TINYINT, ISNULL(b.custom1, 0))
				WHEN bt.ProductID = 19 THEN CONVERT(TINYINT, ISNULL(b.custom1, 0))
				ELSE 0 
			END AS OddsType 
			, '' showtime
			, '' comstatus
			, CASE
				WHEN bt.ProductID = 12 THEN b.Gameid3rd 
				WHEN bt.ProductID = 19 THEN b.custom2
				ELSE '' 
			END AS betcheck
			, CASE
				WHEN (bt.SubProduct IN ('MG-SuperLive') OR bt.ProductID IN (15, 19)) THEN b.transdesc 
				ELSE '' 
			END AS transdesc
			, 0 AS OddsSpread
			, bt.productid
			, bt.eventtype
		FROM bodb02.dbo.translog AS b WITH (NOLOCK)
			INNER JOIN @BettypeMatrix AS bt ON b.gameid = bt.bettype
			OUTER APPLY dbo.f_ParseTransDesc(b.transdesc, b.gameid) fnc
		WHERE b.custid = @CustId
			AND b.statusID IN (0, 1)
			AND (bt.ProductId IN (8, 12, 15, 19) 
				OR SubProduct IN ('MG-SuperLive'))
			AND b.transdate BETWEEN @FromDate AND @ToDate
	END

	IF @LiveIndicator IS NOT NULL OR @BetTeam <> ''
	BEGIN
		DELETE b
		FROM @tempRunning AS b
			INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
		WHERE ( @LiveIndicator IS NOT NULL
				AND bt.productid = 3
				AND b.Liveindicator <> @LiveIndicator)
			OR ( @BetTeam <> '' 
				AND bt.productid = 3
				AND b.betteam <> @BetTeam )
	END

	UPDATE b
	SET
		SportType	= m.sporttype,
		LeagueId	= m.leagueID,
		MatchCode	= m.matchcode,
		HomeId		= m.homeID,
		AwayId		= m.awayID,
		ShowTime	= m.showtime,
		IsNeutral	= m.IsNeutral
	FROM @tempRunning AS b
		INNER JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
	WHERE b.EventType = 1

	UPDATE b
	SET
		SportType = l.sporttype,
		LeagueId = m.leagueID,
		MatchCode = m.matchcode,
		HomeId = m.teamID,
		AwayId = 0,
		ShowTime = ''
	FROM @tempRunning AS b
		INNER JOIN bodb02.dbo.outright AS m WITH (NOLOCK) ON  b.matchid = m.orid
		INNER JOIN bodb02.dbo.league AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
	WHERE b.EventType = 2

	SELECT * FROM @tempRunning
	ORDER BY transid DESC

	-- Get bet detail
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
	FROM bodb02.dbo.bettransm AS bm WITH (NOLOCK)
		INNER JOIN @tempRunning AS b
			ON bm.refno = b.transid AND bm.bettype = b.bettype
	WHERE bm.custid = b.custid AND b.ProductId = 2

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
	FROM bodb02.dbo.bettransm AS bm WITH (NOLOCK)
		INNER JOIN @tempRunning AS b
			ON bm.refno = b.refno AND bm.bettype = b.bettype
	WHERE bm.custid = b.custid AND b.ProductId = 5

	-- SELECT bettransg
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
		, '' AS transdesc
	FROM bodb02.dbo.bettransg AS bg WITH (NOLOCK)
		INNER JOIN @tempRunning AS b
			ON bg.refno = b.refno AND bg.bettype = b.bettype
	WHERE bg.custid = b.custid AND b.ProductId = 4

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
	FROM bodb02.dbo.bettransg AS bg WITH (NOLOCK)
		INNER JOIN @tempRunning AS b
			ON bg.refno = b.transid AND bg.bettype = b.bettype
	WHERE bg.custid = b.custid AND b.ProductId = 12
END


GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_Running_SelBetTicket] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_Running_SelBetTicket] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_CoreBetList_Running_SelBetTicket] TO [vnteam]
GO