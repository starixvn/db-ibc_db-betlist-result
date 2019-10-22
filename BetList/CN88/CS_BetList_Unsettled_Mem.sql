/*<info serverAlias="DB042-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[CS_BetList_Unsettled_Mem]
	@CustId				INT,
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@SportTypeGroups	VARCHAR(MAX)	= '0',
	@BetTypeGroup		SMALLINT		= 0,
	@LiveIndicator		TINYINT			= 2
AS

/*
	Created: Kos@20190227
	Task: Bet List of CN88 Unsettled ticket
	DB: DB042.bodb02

	Param's Explanation:
		- @SportTypeGroup: Sport type group (0: ALL)
		- @BetTypeGroup: Bet type group (0: ALL)
		- @LiveIndicator: 
			- 0: Non-Live, Mix Live & Non-Live (System Parlay bettype 29)
			- 1: Live
			- 2: All (Live, Non-Live, Mix Live & Non-Live)

	Revisions:
		- 20190331@Kos: Create new [Redmine: #109230]
		- 20190705@Kos: Fix bug Virtual Racing [Redmine: #116333]
		- 20190711@Kos: Support PH AIO 4a [Redmine: 115866]
		- 20190723@Kos: Support new status Pending [#Redmine: 116863]
		- 20190821@Kos: Support multiple sport filter [Redmine: 109230]
		- 20191022@Kos: Show Running status for Marked tickets [Redmine: 122391]
*/

BEGIN
	SET NOCOUNT ON;

	-- Check SP Version
	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	CREATE TABLE #MemBetTicket (
		TransId				BIGINT,
		RefNo				BIGINT,
		CustId				INT,
		Username			NVARCHAR(50),
		SportType			SMALLINT,
		BetType				SMALLINT,
		BetId				BIGINT,
		BetTeam				NVARCHAR(20),
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		OddsType			TINYINT,
		Odds				MONEY,
		MOdds				MONEY,
		Stake				MONEY,
		Actual_Stake		MONEY,
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		TransDate			DATETIME,
		WinLostDate			SMALLDATETIME,
		APositionTaking		SMALLMONEY,
		MPositionTaking		SMALLMONEY,
		SPositionTaking		SMALLMONEY,
		TPositionTaking		SMALLMONEY,
		PlayerDiscount		SMALLMONEY,
		ADiscount			SMALLMONEY,
		MDiscount			SMALLMONEY,
		SDiscount			SMALLMONEY,
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		Ip					NVARCHAR(15),
		LeagueId			INT,
		MatchId				INT,
		MatchCode			NVARCHAR(50),
		Race				NVARCHAR(20),
		EventDate			DATETIME,
		HomeId				INT,
		AwayId				INT,
		BetStatus			NVARCHAR(50),
		IsNeutral			BIT,
		Placing				NVARCHAR(20),
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(50),
		ComStatus			NVARCHAR(20),
		TransDesc			NVARCHAR(1000),
		OddsSpread			SMALLMONEY,
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		Currency			NVARCHAR(50)
	);

	DECLARE @BettransDetail TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		MPositionTaking	SMALLMONEY,
		SPositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(10),
		TransDesc		VARCHAR(300)
	)

	DECLARE @Tickets TABLE (
		TransId	BIGINT,
		RefNo	BIGINT,
		Product	VARCHAR(30)
	)

	DECLARE @SportType TABLE (SportType SMALLINT)
	DECLARE @BetType TABLE (ProductId TINYINT, BetType SMALLINT, EventType TINYINT)

	INSERT INTO @SportType
	SELECT DISTINCT SportType
	FROM dbo.CS_f_SporttypeMatrix_Sel (0, @SportTypeGroups, @BetTypeGroup, @IsTest)

	INSERT INTO @BetType
	SELECT DISTINCT
		ProductID,
		Bettype,
		EventType
	FROM dbo.CS_f_BettypeMatrix_Sel (0, @SportTypeGroups, @BetTypeGroup, @IsTest)

	DECLARE @TempFromDate SMALLDATETIME
	DECLARE @TempToDate SMALLDATETIME

	SET @TempFromDate = @FromDate
	SET @TempToDate = @ToDate

	-- translog range
	INSERT INTO #MemBetTicket
	SELECT
		b.translogid AS TransId,
		b.translogid AS RefNo,
		b.custid,
		b.username,
		b.ProductId AS SportType,
		b.gameID AS BetType,
		0 AS BetId,
		'' AS BetTeam,
		0 AS Hdp1,
		0 Hdp2,
		0 AS OddsType,
		b.odds,
		0 AS MOdds,
		b.stake,
		b.actual_stake,
		b.status,
		0 AS SettlementStatus,
		b.transdate,
		b.winlostdate,
		b.apositiontaking,
		b.mpositiontaking,
		b.spositiontaking,
		b.tpositiontaking,
		b.playerdiscount,
		b.discount AS ADiscount,
		b.adiscount AS MDiscount,
		b.sdiscount AS SDiscount,
		b.liveindicator,
		0 AS LiveHomeScore,
		0 AS LiveAwayScore,
		b.ip,
		0 AS LeagueId,
		0 AS MatchId,
		'' AS MatchCode,
		'' AS Race,
		b.winlostdate AS EventDate,
		0 AS HomeId,
		0 AS AwayId,
		'' AS BetStatus,
		0 AS IsNeutral,
		'' AS Placing,
		'' AS ShowTime,
		CASE
			WHEN s.ProductId = 8 THEN ISNULL(b.custom2, '')
			ELSE ''
		END AS BetCheck,
		0 AS ComStatus,
		ISNULL(b.transdesc, '') AS TransDesc,
		0 AS OddsSpread,
		-1 AS BetdaqId,
		'' AS ExtraInfo,
		b.currencyname AS Currency
	FROM dbo.translog AS b WITH (NOLOCK, INDEX = IX_betrunning_custid)
		INNER JOIN @BetType AS s ON s.bettype = b.gameID
	WHERE b.custid = @CustId
		AND b.winlostdate BETWEEN @TempFromDate AND @TempToDate
		AND b.statusID IN (0, 1)
		AND (@LiveIndicator = 2 OR b.liveindicator = @LiveIndicator)
		AND s.ProductId IN (8, 28)

	-- bettrans range
	IF @SportTypeGroups = '0'
	BEGIN
		INSERT INTO @Tickets (
			TransId,
			RefNo,
			Product
		)
		SELECT
			b.transid,
			b.refno,
			CASE
				WHEN s.EventType = 0 AND s.ProductId = 1 THEN 'Parlay'		-- Sportsbook Parlay
				WHEN s.EventType = 0 AND s.ProductId = 8 THEN 'Keno'		-- Keno
				WHEN s.EventType = 0 AND s.ProductId = 27 THEN 'ParlayVS2'	-- Betradar Virtual Sports Parlay
				WHEN s.EventType = 0 AND s.ProductId = 28 THEN 'Lottery'	-- Lottery
				WHEN s.EventType = 1 AND s.ProductId = 1 THEN 'SB'			-- Sportsbook
				WHEN s.EventType = 1 AND s.ProductId = 3 THEN 'NG'			-- Number Game
				WHEN s.EventType = 1 AND s.ProductId = 5 THEN 'VS'			-- Virtual Sports Sportsbook
				WHEN s.EventType = 1 AND s.ProductId = 27 THEN 'VS2'		-- Betradar Virtual Sports
				WHEN s.EventType = 2 AND s.ProductId = 1 THEN 'Outright'
				WHEN s.EventType = 3 AND s.ProductId = 5 THEN 'VR'			-- Virtual Sports Racing
				ELSE 'Unknown'
			END AS Product
		FROM dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_betrunning_custid)
			INNER JOIN @BetType AS s ON b.bettype = s.bettype
		WHERE b.custid = @CustId
			AND b.winlostdate BETWEEN @TempFromDate AND @TempToDate
			AND b.statusID IN (0, 1)
			AND (@LiveIndicator = 2
				OR (b.bettype IN (9, 29, 2799) AND b.livehomescore IN (	SELECT 0 WHERE @LiveIndicator = 0
																UNION	SELECT 2 WHERE @LiveIndicator = 0
																UNION	SELECT 1 WHERE @LiveIndicator = 1 ))
				OR (b.bettype NOT IN (9, 29, 2799) AND b.liveindicator = @LiveIndicator))
	END
	ELSE
	BEGIN
		INSERT INTO @Tickets (
			TransId,
			RefNo,
			Product
		)
		SELECT
			b.transid,
			b.refno,
			CASE
				WHEN s.EventType = 0 AND s.ProductId = 1 THEN 'Parlay'		-- Sportsbook Parlay
				WHEN s.EventType = 0 AND s.ProductId = 8 THEN 'Keno'		-- Keno
				WHEN s.EventType = 0 AND s.ProductId = 27 THEN 'ParlayVS2'	-- Betradar Virtual Sports Parlay
				WHEN s.EventType = 0 AND s.ProductId = 28 THEN 'Lottery'	-- Lottery
				WHEN s.EventType = 1 AND s.ProductId = 1 THEN 'SB'			-- Sportsbook
				WHEN s.EventType = 1 AND s.ProductId = 3 THEN 'NG'			-- Number Game
				WHEN s.EventType = 1 AND s.ProductId = 5 THEN 'VS'			-- Virtual Sports Sportsbook
				WHEN s.EventType = 1 AND s.ProductId = 27 THEN 'VS2'		-- Betradar Virtual Sports
				WHEN s.EventType = 2 AND s.ProductId = 1 THEN 'Outright'
				WHEN s.EventType = 3 AND s.ProductId = 5 THEN 'VR'			-- Virtual Sports Racing
				ELSE 'Unknown'
			END AS Product
		FROM dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_betrunning_custid)
			INNER JOIN @BetType AS s ON b.bettype = s.bettype
			LEFT JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1 AND s.ProductId IN (1, 3, 5, 25, 27)
			LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON o.orid = b.matchid AND s.EventType = 2 AND s.ProductId = 1
			LEFT JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = o.leagueid AND s.EventType = 2 AND s.ProductId = 1
			LEFT JOIN dbo.VSOutright AS vo WITH (NOLOCK) ON b.oddsid = vo.Orid AND s.EventType = 3 AND s.ProductId = 5
			LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON vr.EventID = vo.EventID AND s.EventType = 3 AND s.ProductId = 5
		WHERE b.custid = @CustId
			AND b.winlostdate BETWEEN @TempFromDate AND @TempToDate
			AND b.statusID IN (0, 1)
			AND (m.sporttype IS NULL OR m.sporttype IN (SELECT SportType FROM @SportType))
			AND (l.sporttype IS NULL OR l.sporttype IN (SELECT SportType FROM @SportType))
			AND (vr.sporttype IS NULL OR vr.sporttype IN (SELECT SportType FROM @SportType))
			AND (@LiveIndicator = 2
				OR (b.bettype IN (9, 29, 2799) AND b.livehomescore IN (	SELECT 0 WHERE @LiveIndicator = 0
																UNION	SELECT 2 WHERE @LiveIndicator = 0
																UNION	SELECT 1 WHERE @LiveIndicator = 1 ))
				OR (b.bettype NOT IN (9, 29, 2799) AND b.liveindicator = @LiveIndicator))
	END

	IF @@ROWCOUNT > 0
	BEGIN
		INSERT INTO #MemBetTicket
		SELECT
			CASE
				WHEN c.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
				ELSE b.transid
			END AS TransId,
			b.refno,
			b.custid,
			b.username,
			CASE
				WHEN c.Product IN ('Keno', 'Lottery') THEN b.matchid
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.sporttype
				WHEN c.Product IN ('Outright') THEN l.sporttype
				WHEN c.Product IN ('VR') THEN vr.SportType
				ELSE 0
			END AS SportType,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'Parlay', 'ParlayVS2') THEN b.betteam
				ELSE ''
			END AS BetTeam,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2') THEN b.hdp1
				ELSE 0
			END AS Hdp1,
			CASE
				WHEN c.Product IN ('SB', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2') THEN b.hdp2
				ELSE 0
			END AS Hdp2,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.oddstype
				ELSE 0
			END AS OddsType,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'ParlayVS2', 'Keno', 'Lottery') THEN b.odds
				ELSE 0
			END AS Odds,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'ParlayVS2') THEN b.modds
				ELSE 0
			END AS MOdds,
			b.stake,
			b.actual_stake,
			CASE
				WHEN c.Product = 'SB'
					AND b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'Waiting'
				WHEN c.Product = 'Parlay' AND b.status = 'running' THEN
					CASE
						WHEN EXISTS (SELECT 1 FROM dbo.bettransm AS bm WITH (NOLOCK)
									WHERE bm.custid = b.custid
										AND bm.refno = b.refno
										AND (bm.status = 'waiting'
											OR (bm.status = 'running' AND ISNULL(bm.SecAcceptFlag, 0) = 1 AND ISNULL(bm.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)))
							THEN 'Waiting'
						ELSE b.status
					END
				ELSE b.status
			END AS Status,
			ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
			b.transdate,
			b.winlostdate,
			b.APositiontaking,
			b.MPositiontaking,
			b.SPositiontaking,
			b.TPositiontaking,
			b.playerdiscount,
			b.discount AS ADiscount,
			b.adiscount AS MDiscount,
			b.sdiscount AS SDiscount,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.liveindicator
				ELSE 0
			END AS LiveIndicator,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'ParlayVS2') THEN b.livehomescore
				ELSE 0
			END AS LiveHomeScore,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR') THEN b.liveawayscore
				ELSE 0
			END AS LiveAwayScore,
			b.ip,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.leagueid
				WHEN c.Product IN ('Outright') THEN o.leagueid
				WHEN c.Product IN ('VR') THEN vr.LeagueID
				ELSE 0
			END AS LeagueId,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.matchid
				WHEN c.Product IN ('VR') THEN b.matchid
				ELSE 0
			END AS MatchId,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.matchcode
				WHEN c.Product IN ('Outright') THEN o.matchcode
				WHEN c.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vo.RacerNum)
				ELSE ''
			END AS MatchCode,
			CASE
				WHEN c.Product IN ('Outright') THEN o.groupmatch
				WHEN c.Product IN ('VR') THEN CONVERT(NVARCHAR(50), b.oddsid)
				ELSE ''
			END AS Race,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.eventdate
				WHEN c.Product IN ('Outright') THEN o.eventdate
				WHEN c.Product IN ('VR') THEN vo.EventDate
				ELSE b.winlostdate
			END AS EventDate,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.homeid
				WHEN c.Product IN ('Outright') THEN o.teamid
				WHEN c.Product IN ('VR') THEN vo.RacerID
				ELSE 0
			END AS HomeId,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.awayid
				ELSE 0
			END AS AwayId,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.betstatus
				ELSE ''
			END AS BetStatus,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN ISNULL(m.IsNeutral, 0)
				ELSE 0
			END AS IsNeutral,
			CASE
				WHEN c.Product IN ('VR') THEN CONVERT(VARCHAR(5), vo.Placing)
				ELSE ''
			END AS Placing,
			CASE
				WHEN c.Product IN ('VS', 'VS2') THEN CONVERT(NVARCHAR(50), m.kickofftime)
				WHEN c.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
				ELSE ''
			END AS ShowTime,
			CASE
				WHEN c.Product IN ('SB', 'Parlay', 'ParlayVS2') THEN ISNULL(b.betcheck, '')
				WHEN c.Product IN ('Keno') THEN ISNULL(b.comstatus, '')
				ELSE ''
			END AS BetCheck,
			CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS ComStatus,
			CASE
				WHEN c.Product IN ('SB', 'VS2', 'Keno', 'Lottery') THEN ISNULL(b.transdesc, '')
				ELSE ''
			END AS TransDesc,
			CASE
				WHEN c.Product IN ('SB') THEN ISNULL(b.oddsspread, 0)
				ELSE 0
			END AS OddsSpread,
			-1 AS BetdaqId,
			CASE
				WHEN c.Product IN ('SB') THEN ISNULL(b.ExtraInfo, '')
				ELSE ''
			END AS ExtraInfo,
			b.currencyname AS Currency
		FROM @Tickets AS c
			INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON b.transid = c.transid
			LEFT JOIN dbo.match AS m WITH (NOLOCK) ON c.Product IN ('SB', 'NG', 'VS', 'VS2') AND b.matchid = m.matchid
			LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON c.Product IN ('Outright') AND b.matchid = o.orid
			LEFT JOIN dbo.League AS l WITH (NOLOCK) ON c.Product IN ('Outright') AND o.leagueID = l.leagueid
			LEFT JOIN dbo.VSOutright AS vo WITH (NOLOCK) ON c.Product IN ('VR') AND b.oddsid = vo.Orid
			LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON c.Product IN ('VR') AND vr.EventID = vo.EventID

		-- Get ticket detail
		-- Virtual Sports Racing
		INSERT INTO @BettransDetail
		SELECT
			bm.refno,
			bm.odds,
			bm.stake,
			bm.status,
			bm.apositiontaking,
			bm.mpositiontaking,
			bm.spositiontaking,
			bm.bettype,
			bm.betteam,
			'' AS TransDesc
		FROM @Tickets AS c
			INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON c.refno = bm.refno
		WHERE bm.custid = @CustId AND c.Product IN ('VR')
	END

	DECLARE @UGroup VARCHAR(3)

	SELECT @UGroup = ugroup
	FROM dbo.Customer WITH (NOLOCK)
	WHERE CustId = @CustId

	SELECT *,
		@UGroup AS UGroup
	FROM #MemBetTicket
	ORDER BY TransId DESC

	SELECT * 
	FROM @BettransDetail
	ORDER BY RefNo DESC

	DROP TABLE #MemBetTicket
END
GO




GRANT EXECUTE ON [dbo].[CS_BetList_Unsettled_Mem] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[CS_BetList_Unsettled_Mem] TO [bodbDownlineNetView] AS [dbo]
GO
