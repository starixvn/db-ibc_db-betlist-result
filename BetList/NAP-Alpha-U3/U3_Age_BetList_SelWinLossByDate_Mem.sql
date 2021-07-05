/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[U3_Age_BetList_SelWinLossByDate_Mem]
	@CustId			INT
	, @FromDate		SMALLDATETIME
	, @ToDate		SMALLDATETIME
	, @MoveBetsDay	SMALLDATETIME
	, @ShowNG		BIT = 0
AS

/*
	Created: Kos@20170810
	Task: Master/Agent/Member Win Loss bet list of U3
	DB: DBAGE.bodb02
	Original: Age_BetList_SelWinLossByDate_Mem

	Revisions:
		- 20170810@Kos: Support Lucky 3 [#Redmine: 75277]
		- 20201224@Kos: Support Happy 5 Linked Games [Redmine: #146540]
					- Don't support Live Casino, Bingo, Lucky 3 anymore
					- Remove input param @ShowBI, @ShowLiveCasino, @ShowLK3
					- Don't return column Race, Placing, OddsSpread
		- 20210705@Razor: Show Odds for Happy 5 Linked Games [Redmine: #154704]
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @BettypeMatrix	[dbo].[TVP_SportBettypeMatrix]

	-- Check SP Version
	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	-- Gather BettypeMatrix
	INSERT INTO @BettypeMatrix
	SELECT ProductID, Bettype, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (3, 0, 0, 2, '', '', @IsTest)

	-- DO filtering bettype by product
	DELETE FROM @BettypeMatrix
	WHERE ProductID	= CASE WHEN @ShowNG	= 0 THEN 3 END

	DECLARE @tempCust	dbo.TVP_TicketSportBettype
	
	--Use Local variables to avoid bad params sniffing
	DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME

	SELECT @FDate = @fromdate,
		@TDate = @todate

	-- Bettrans
	IF @ToDate > @MoveBetsDay
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
		WHERE b.winlostdate BETWEEN @FDate AND @TDate
			AND b.custid = @CustId
			AND b.statusID > 1
	END

	-- Bettrans14
	IF @FromDate <= @MoveBetsDay
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
		WHERE b.winlostdate BETWEEN @FDate AND @TDate
			AND b.custid = @CustId
	END

	-- CREATE output main info ticket
	CREATE TABLE #MemBetTicket (
		TransId				BIGINT
		, RefNo				BIGINT
		, CustId			INT
		, Username			NVARCHAR(30)
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
		, Ip				NVARCHAR(15)
		, LeagueId			INT
		, MatchId			INT
		, MatchCode			NVARCHAR(50)
		, EventDate			DATETIME
		, HomeId			INT
		, AwayId			INT
		, BetStatus			NVARCHAR(50)
		, IsNeutral			BIT
		, ShowTime			NVARCHAR(50)
		, BetCheck			NVARCHAR(50)
		, ComStatus			NVARCHAR(20)
		, TransDesc			NVARCHAR(1000)
	);

	-- bettrans
	IF EXISTS (SELECT TOP(1) 1 FROM @tempCust WHERE WhTicket = 1)
	BEGIN
		-- Number Game
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
			, b.hdp2
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
			, b.discount AS ADiscount
			, b.adiscount AS MDiscount
			, b.sdiscount AS SDiscount
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
			, m.eventdate
			, m.homeid
			, m.awayid
			, m.betstatus
			, ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
			, ISNULL(m.showtime, '') AS ShowTime
			, '' AS betcheck
			, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
			, '' AS TransDesc
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN @tempCust AS c ON b.transid = c.transid
		WHERE c.WhTicket = 1 AND c.EventType = 1

		-- Happy 5 Linked Games
		INSERT INTO #MemBetTicket
		SELECT
			b.transid
			, b.refno
			, b.custid
			, b.username
			, b.matchid AS sporttype
			, b.bettype
			, ISNULL(b.betid, 0) AS BetId
			, '' AS betteam
			, 0 AS hdp1
			, 0 AS hdp2
			, 0 AS oddstype
			, b.oddsid
			, b.odds AS odds
			, 0 AS modds
			, b.stake
			, b.actual_stake
			, b.status
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
			, b.discount AS ADiscount
			, b.adiscount AS MDiscount
			, b.sdiscount AS SDiscount
			, 0 AS liveindicator
			, 0 AS livehomescore
			, 0 AS liveawayscore
			, 0 AS finalhomescore
			, 0 AS finalawayscore
			, 0 AS hthomescore
			, 0 AS htawayscore
			, b.ip
			, 0 AS leagueid
			, 0 AS matchid
			, '' AS matchcode
			, '' AS eventdate
			, 0 AS homeid
			, 0 AS awayid
			, '' AS betstatus
			, 0 AS IsNeutral
			, '' AS ShowTime
			, ISNULL(b.betcheck, '') AS betcheck
			, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
			, ISNULL(b.transdesc, '') AS TransDesc
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @tempCust AS c ON b.transid = c.transid
		WHERE c.WhTicket = 1 AND c.EventType = 0
	END

	-- bettrans14
	IF EXISTS (SELECT TOP(1) 1 FROM @tempCust WHERE WhTicket = 2)
	BEGIN
		-- Number Game
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
			, b.hdp2
			, b.oddstype
			, b.oddsid
			, b.odds
			, b.modds
			, b.stake
			, b.actual_stake
			, CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1
					AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status
			, b.transdate
			, b.winlostdate
			, (b.winlost - b.actual_stake) AS WinLost
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
			, b.discount AS ADiscount
			, b.adiscount AS MDiscount
			, b.sdiscount AS SDiscount
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
			, m.eventdate
			, m.homeid
			, m.awayid
			, m.Betstatus
			, ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral
			, ISNULL(m.showtime, '') AS ShowTime
			, '' AS BetCheck
			, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
			, '' AS TransDesc
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN @tempCust AS c ON b.transid = c.transid
		WHERE c.WhTicket = 2 AND c.EventType = 1

		-- Happy 5 Linked Games
		INSERT INTO #MemBetTicket
		SELECT
			b.transid
			, b.refno
			, b.custid
			, b.username
			, b.matchid AS sporttype
			, b.bettype
			, ISNULL(b.betid, 0) AS BetId
			, '' AS betteam
			, 0 AS hdp1
			, 0 AS hdp2
			, 0 AS oddstype
			, b.oddsid
			, b.odds AS odds
			, 0 AS modds
			, b.stake
			, b.actual_stake
			, b.status
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
			, b.discount AS ADiscount
			, b.adiscount AS MDiscount
			, b.sdiscount AS SDiscount
			, 0 AS liveindicator
			, 0 AS livehomescore
			, 0 AS liveawayscore
			, 0 AS finalhomescore
			, 0 AS finalawayscore
			, 0 AS hthomescore
			, 0 AS htawayscore
			, b.ip
			, 0 AS leagueid
			, 0 AS matchid
			, '' AS matchcode
			, '' AS eventdate
			, 0 AS homeid
			, 0 AS awayid
			, '' AS betstatus
			, 0 AS IsNeutral
			, '' AS ShowTime
			, ISNULL(b.betcheck, '') AS betcheck
			, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
			, ISNULL(b.transdesc, '') AS TransDesc
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN @tempCust AS c ON b.transid = c.transid
		WHERE c.WhTicket = 2 AND c.EventType = 0
	END

	SELECT
		t.*,
		e.currency
	FROM #MemBetTicket AS t
		LEFT JOIN dbo.custInfo AS ci WITH (NOLOCK) ON t.CustId = ci.custid
		LEFT JOIN dbo.Exchange AS e WITH (NOLOCK) ON ci.Currency = e.exchangeid
	ORDER BY t.TransId DESC
END
GO
