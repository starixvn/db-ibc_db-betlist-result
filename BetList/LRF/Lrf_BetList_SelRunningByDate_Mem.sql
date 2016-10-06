ALTER PROCEDURE [dbo].[Lrf_BetList_SelRunningByDate_Mem]
	@LicenseeID INT,
	@UserID		INT,
	@CustID		INT			= NULL,
	@CurrencyId INT			= 0,
	@FromDate	DATETIME	= '',
	@ToDate		DATETIME	= '',
	@Langkey	VARCHAR(10)	= 'en-US',
	@username	VARCHAR(30)	= NULL, -- for API
	@PageSize	INT			= 1000,
	@PageIndex	INT			= 1,
	-- check for showing product
	@ShowSB		BIT			= 0,
	@ShowRB		BIT			= 0,
	@ShowNG		BIT			= 0,
	@ShowBA		BIT			= 0,
	@ShowLC		BIT			= 0,
	@ShowVS		BIT			= 0,
	@ShowCS		BIT			= 0,	-- RNG Casino
	@ShowKN		BIT			= 0,	-- Keno
	@ShowMGCLC	BIT			= 0,	-- Microgaming Live Casino
	@ShowMGCRNG	BIT			= 0,	-- Microgaming RNG Casino
	@ShowAGC	BIT			= 0,	-- AG Casino
	@ShowAB		BIT			= 0,	-- AllBet
	@ShowVB		BIT			= 0,	-- Voidbridge
	-- output info
	@TotalRows	INT			= 0 OUTPUT,
	@ErrorCode	INT			= 0 OUTPUT,
	@ErrorMsg	NVARCHAR(100)='' OUTPUT
AS

/*
	Created: Henry@20101210
	Task: Bet List
	DB: DBEXT.bodb02
	Original [Age_BetList_SelRunningByDate_Mem]
	Revisions:
		- 20110303@Henry: suppport based currency
		- 20110408@Amy: Change function to get Odds value AND odds type
						Show odds value AND odds type for Number game
		- 20110627@Henry: show column discount
		- 20110712@Henry: remove @ShowBI, @ShowP2P, @ShowCasino. Add @ShowBA
		- 20110729@Henry: offer 3 new bettypes for Number Game + Combination Mixed Parlay
		- 20111118@Henry: using [creator] column as sporttype for racing ticket
		- 20111122@Henry: Compare Checktime and CURRENT_TIMESTAMP to show waiting or running status
		- 20111208@Jim : Change condition bettype <31 
		- 20111229@Jim : change the way to get odds/oddstype/betteam to web dev
		- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
		- 20120319@Henry: show main transid for sub-ticket of system parlay
		- 20120706@Jim: get sporttype for Outright 
		- 20120726@Jim: add playercomm value 
		- 20120817@Henry: add live casino
		- 20120924@Jim: add virtual sport
		- 20130226@Jim: support RNG Casino,Bingo
		- 20130326@Jim: remove input parameter @GetAll
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20130716@Jim: update matchid for RNG Casino and Bingo
		- 20130903@Jim: support Virtual Horse Racing
		- 20140310@Hannah: offer Keno
		- 20140319@Hannah: fix bug for showing DrawID 
		- 20140630@Hannah: offer BetRadar and Sporting Solution 
		- 20141128@Jim: add more input param @CurrencyID
		- 20150126@Winnie: add base currency GBP 
		- 20150402@Bobby: Apply sporttype matrix & #32844 new 60 bettypes - betradar phase 2
		- 20150608@Edward: Support MicroGamming
		- 20150608@Edward: Exclude 3 transactions SOLD/BOUGHT/BetTrade Commission of BetTrade
		- 20150917@Kos: Support Microgaming RNG Game
		- 20150922@Kos: Support AG Casino
		- 20151029@Kos: Change ProductId/SportType of Microgaming RNG Game
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20151225@Kos: Support RNG Casino Single Wallet [Redmine: #48958]
		- 20160202@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160216@Kos: Support yesterday running ticket [Redmine: #52277]
		- 20160406@Kos: Support Voidbridge [#Redmine: 54925]
		- 20160413@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20160714@Kos: Remove Bingo and change to use inline function for SportBettypeMatrix
		- 20160727@Kos: Support AllBet [#Redmine: 61066]
		- 20160801@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20161006@Kos: Add product bet type range for sub tickets [Redmine: #65045]
*/
BEGIN

	SET NOCOUNT ON
	
	DECLARE @Today		SMALLDATETIME
		, @Yesterday	SMALLDATETIME
	
	SELECT @Today	= DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)
		,@Yesterday	= DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
		,@TotalRows	= 0
		,@ErrorCode	= 0
		,@ErrorMsg	= ''

	-- validate customer info
	SELECT currencyID
		, LicenseeID 
	INTO #currency
	FROM dbo.Lrf_f_GetCurrencybyUser(@licenseeID, @userID, 1)-- System is default=1 (LRF)
	
	IF @CustID IS NULL
	BEGIN
		SELECT TOP 1 
			@custid = c.custid
			, @username = CASE WHEN @username IS NULL THEN c.username ELSE @username END 
		FROM dbo.customer AS c WITH (NOLOCK) 
			INNER JOIN #currency AS cy ON c.Currency = cy.CurrencyID
		WHERE username = @username
	END
	ELSE
	BEGIN
		SELECT TOP 1 
			@custid = @custid
			, @username = CASE WHEN @username IS NULL THEN c.username ELSE @username END 
		FROM dbo.customer AS c WITH (NOLOCK) 
			INNER JOIN #currency AS cy ON c.Currency = cy.CurrencyID
		WHERE CustID = @CustID
	END

	IF (@custid IS NULL OR @username IS NULL)
	BEGIN
		SELECT @ErrorCode	= 100
			, @ErrorMsg		= 'The customer was not found.'
		RETURN;
	END

	-- filer bettypes by sporttype
	DECLARE @SportBettype TABLE ( ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID <= 6 OR ProductID IN (8, 11, 13, 17, 21, 22)

	-- Don't support BetTrade, RNG Casino old bet type (71)
	DELETE FROM @SportBettype
	WHERE (ProductID = 1 AND Bettype IN (901, 902, 903, 904))
		OR (ProductID = 6 AND SubProduct = '')

	DELETE FROM @SportBettype
	WHERE ProductID		= CASE WHEN @ShowSB	= 0 AND @ShowBA = 0 THEN 1 END
		OR ProductID	= CASE WHEN @ShowRB	= 0		THEN 2 END
		OR ProductID	= CASE WHEN @ShowNG	= 0		THEN 3 END
		OR ProductID	= CASE WHEN @ShowLC	= 0		THEN 4 END
		OR ProductID	= CASE WHEN @ShowVS	= 0		THEN 5 END
		OR ProductID	= CASE WHEN @ShowCS	= 0		THEN 6 END
		OR ProductID	= CASE WHEN @ShowKN	= 0		THEN 8 END
		OR ProductID	= CASE WHEN @ShowAGC = 0	THEN 11 END
		OR ProductID	= CASE WHEN @ShowMGCLC = 0	THEN 13 END
		OR ProductID	= CASE WHEN @ShowMGCRNG = 0	THEN 17 END
		OR ProductID	= CASE WHEN @ShowAB = 0		THEN 21 END
		OR ProductID	= CASE WHEN @ShowVB = 0		THEN 22 END
	-- end filer bettypes by sporttype

	CREATE TABLE #BetListSelRunningByDateMem (
		SportType		INT,
		Username		NVARCHAR(50),
		BetType			SMALLINT,
		LeagueId		INT,
		RefNo			BIGINT,
		TransId			BIGINT,
		BetId			BIGINT,
		MatchCode		NVARCHAR(50),
		Race			NVARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds 			MONEY,
		Modds 			MONEY,
		Status			NVARCHAR(50),
		Stake			MONEY,
		Actual_Stake	MONEY,
		TransDate		DATETIME,
		BetTeam			NVARCHAR(50),
		Discount		DECIMAL(9,8),
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				NVARCHAR(30),
		IsNeutral		BIT,
		OddsType		INT,
		WinLostDate		DATETIME,
		Currency		SMALLINT,
		PlayerComm		MONEY,
		ShowTime		NVARCHAR(50), -- table - shoe - hand of Live Casino
		MatchId			INT,
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(300)
	)

	CREATE TABLE #TempBATicket (
		BetType			INT,
		RefNo			BIGINT,
		TransId			BIGINT PRIMARY KEY,
		BetId			BIGINT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		Modds			MONEY,
		Status			NVARCHAR(10),
		Stake			MONEY,
		Actual_Stake	MONEY,
		TransDate		DATETIME,
		BetTeam			NVARCHAR(20),
		Discount		DECIMAL(9,8),
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				NVARCHAR(50),
		OddsType		TINYINT,
		WinLostDate		DATETIME,
		Currency		INT,
		MatchId			INT,
		PlayerComm		MONEY,
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(300)
	)

	IF @ShowBA = 1
	BEGIN
		-- Receive BA Ticket - SB ticket only
		INSERT INTO #TempBATicket
		SELECT
			b.bettype,
			b.refno,
			b.transid,
			ISNULL(b.betid, 0),
			CONVERT(FLOAT, b.hdp1) AS hdp1,
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			b.odds,
			b.modds,
			CASE
				WHEN b.bettype NOT IN (9,29,10) AND b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1
					AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status,
			b.stake,
			b.actual_stake,
			b.transdate,
			b.betteam,
			b.discount,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			b.oddstype,
			b.winlostdate,
			b.currency,
			b.matchid,
			b.playercomm,
			b.betcheck,
			ISNULL(b.transdesc, '') AS transdesc
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction AS BA WITH (NOLOCK) ON b.transid = BA.transid
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.Bettype
		WHERE b.transdate >= @FromDate AND b.transdate <= @ToDate
			AND b.custid = @CustID
			AND sbt.ProductId = 1
			AND b.statusID IN (0, 1)

		-- Sportbook
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			m.sporttype,
			@Username AS UserName,
			b.bettype,
			m.leagueID,
			b.RefNo,
			b.TransId,
			b.BetId,
			m.matchcode,
			'' AS Race,
			m.homeID,
			m.awayID,
			b.Hdp1,
			b.Hdp2,
			b.Odds,
			b.Modds,
			b.Status,
			b.Stake,
			b.Actual_Stake,
			b.TransDate,
			b.BetTeam,
			b.Discount,
			b.LiveIndicator,
			b.LiveHomeScore,
			b.LiveAwayScore,
			b.Ip,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.OddsType,
			b.WinLostDate,
			b.Currency,
			b.PlayerComm,
			'' AS ShowTime,
			m.matchid,
			CASE WHEN b.BetType IN (216, 217) THEN b.BetCheck ELSE '' END AS betcheck,
			b.TransDesc
		FROM #TempBATicket AS b
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE sbt.ProductID = 1 AND sbt.EventType = 1

		-- Outright
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			l.sporttype,
			@Username AS UserName,
			b.bettype,
			m.leagueid,
			b.refno,
			b.transid,
			b.BetId,
			m.matchcode,
			m.groupmatch AS Race,
			m.teamid AS homeID,
			0 AS awayID,
			0 AS hdp1,
			0 AS hdp2,
			b.Odds,
			b.Modds,
			b.Status,
			b.Stake,
			b.Actual_Stake,
			b.TransDate,
			'' AS Betteam,
			b.Discount,
			0 AS liveindicator,
			0 AS livehomescore,
			0 AS liveawayscore,
			b.Ip,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS oddstype,
			b.WinLostDate,
			b.Currency,
			b.PlayerComm,
			'' AS ShowTime,
			0 AS matchid,
			'' AS betcheck,
			'' AS transdesc
		FROM #TempBATicket AS b
			INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
			INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueID = l.leagueid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE sbt.ProductID = 1 AND sbt.EventType = 2

		-- Mix Parlay & System Parlay
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			0 AS sporttype,
			@Username AS UserName,
			b.BetType,
			0 AS leagueID,
			b.RefNo,
			CASE
				WHEN (ISNULL(b.BetId, 0) = 0 OR b.BetType = 9) THEN b.transid 
				ELSE betid 
			END AS transid,
			b.BetId,
			'' AS matchcode,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			b.hdp1, 
			b.hdp2, 
			b.Odds,
			b.Modds,
			b.status,
			b.stake,
			b.actual_stake,
			b.transdate,
			b.betteam,
			b.discount,
			0 AS liveindicator,
			0 AS livehomescore,
			0 AS liveawayscore,
			b.IP,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS oddstype,
			b.winlostdate,
			b.currency,
			b.playercomm,
			'' As ShowTime,
			0 AS matchid,
			ISNULL(b.betcheck, '') AS BetCheck,
			'' AS transdesc
		FROM 
			#TempBATicket AS b 
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE sbt.ProductID = 1 AND sbt.EventType = 0
	END

	IF @ShowSB = 1
	BEGIN
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			m.sporttype,
			@Username AS UserName,
			b.bettype,
			m.leagueid,
			b.refno,
			b.transid,
			ISNULL(b.betid, 0),
			m.matchcode,
			'' AS Race,
			m.homeID,
			m.awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1,
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			b.odds,
			b.modds,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status,
			b.stake,
			b.actual_stake,
			b.transdate,
			b.betteam,
			b.discount,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.oddstype,
			b.winlostdate,
			b.currency,
			b.playercomm,
			'' AS ShowTime,
			m.matchid,
			CASE WHEN b.bettype IN (216,217) THEN b.betcheck ELSE '' END AS betcheck,
			ISNULL(b.transdesc, '') AS transdesc
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE
			b.transdate >= @FromDate AND b.transdate <= @ToDate
			AND b.custid = @CustID
			AND sbt.ProductID = 1
			AND sbt.EventType = 1
			AND b.matchid > 0
			AND b.statusID IN (0, 1)
			AND b.transid NOT IN (SELECT transid FROM #TempBATicket)

		-- Outright
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			l.sporttype,
			@Username AS UserName,
			b.bettype,
			m.leagueID,
			b.refno,
			b.transid,
			ISNULL(b.betid, 0),
			m.matchcode,
			m.GroupMatch AS Race,
			m.teamID AS homeID,
			0 AS awayID,
			0 AS hdp1,
			0 AS hdp2,
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake,
			b.transdate,
			'' AS Betteam,
			b.discount,
			0 AS liveindicator,
			0 AS livehomescore,
			0 AS liveawayscore,
			b.ip,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS oddstype,
			b.winlostdate,
			b.currency,
			b.playercomm,
			'' AS ShowTime,
			0 AS matchid,
			'' AS betcheck,
			'' AS transdesc
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
			INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE
			b.transdate >= @FromDate AND b.transdate<=@ToDate
			AND b.custid = @CustID
			AND sbt.ProductID = 1
			AND sbt.EventType = 2
			AND b.statusID IN (0,1)
			AND b.transid NOT IN (SELECT transid FROM #TempBATicket)

		-- Mix Parlay & System Parlay
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			0 AS sporttype,
			@Username AS UserName,
			b.bettype,
			0 AS leagueID,
			b.refno,
			CASE WHEN (ISNULL(b.BetID,0) = 0 OR b.bettype = 9) THEN b.transid ELSE betid END AS transid,
			ISNULL(b.BetID,0),
			'' AS matchcode,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			b.hdp1, 
			b.hdp2, 
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake,
			b.transdate,
			b.betteam,
			b.discount,
			0 AS liveindicator,
			0 AS livehomescore,
			0 AS liveawayscore,
			b.IP,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS oddstype,
			b.winlostdate,
			b.currency,
			b.playercomm,
			'' AS ShowTime,
			0 AS matchid,
			ISNULL(b.betcheck, '') AS BetCheck,
			'' AS transdesc
		FROM 
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE
			b.transdate >= @FromDate AND b.transdate<=@ToDate 
			AND b.custid = @CustID
			AND sbt.ProductID = 1
			AND sbt.EventType = 0
			AND b.statusID IN (0, 1)
			AND b.transid NOT IN (SELECT transid FROM #TempBATicket)
	END

	-- release mem for tempdb
	DROP TABLE #TempBATicket;

	-- Horse Racing
	IF @ShowRB = 1
	BEGIN
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			m.creator AS sporttype,
			@Username AS UserName,
			b.bettype,
			m.leagueID,
			b.refno,
			b.transid,
			ISNULL(b.betid, 0),
			m.matchcode,
			m.groupmatch AS Race,
			m.teamID AS homeID,
			0 AS awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1,
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			b.odds,
			b.modds,
			CASE WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
			ELSE b.status
			END AS status,
			b.stake,
			b.actual_stake,
			b.transdate,
			'' AS Betteam,
			b.discount,
			0 AS liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.IP,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS oddstype,
			b.winlostdate,
			b.currency,
			b.playercomm,
			'' AS ShowTime,
			0 AS matchid,
			'' AS betcheck,
			'' AS transdesc
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE
			b.transdate >= @FromDate AND b.transdate <= @ToDate
			AND b.custid = @CustID 
			AND sbt.ProductID = 2
			AND sbt.EventType = 2
			AND b.statusID IN (0, 1)
	END
	
	-- Number Game, Live Casino, Virtual Sport
	IF @ShowNG = 1 OR @ShowLC = 1 OR @ShowVS = 1
	BEGIN
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			m.sporttype,
			@Username AS UserName,
			b.bettype,
			m.leagueID,
			b.refno,
			b.transid,
			ISNULL(b.BetID,0),
			m.matchcode,
			'' AS Race,
			m.homeID,
			m.awayID,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			CASE WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
			ELSE b.status
			END AS status,
			b.stake,
			b.actual_stake,
			b.transdate,
			b.betteam,
			b.discount,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.IP,
			CONVERT(BIT,0) AS IsNeutral,
			b.oddstype,
			b.winlostdate,
			b.currency,
			b.playercomm,
			CASE WHEN @ShowLC = 1 THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime,
			m.matchid,
			'' AS betcheck,
			'' AS transdesc
		FROM 
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE
			b.transdate >= @FromDate AND b.transdate <= @ToDate 
			AND b.custid = @CustID
			AND sbt.ProductID IN (3, 4, 5)
			AND sbt.EventType = 1
			AND b.statusID IN (0, 1)

		UNION
		SELECT
			r.sporttype,
			@Username AS UserName,
			b.bettype,
			r.LeagueID,
			b.refno,
			b.transid,
			ISNULL(b.BetID, 0),
			CONVERT(VARCHAR(50), o.RacerNum) AS matchcode,
			b.oddsid AS Race,
			o.RacerID AS homeID,
			0 AS awayID,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
				ELSE b.status
			END AS status,
			b.stake,
			b.actual_stake,
			b.transdate,
			b.betteam,
			b.discount,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.IP,
			CONVERT(BIT,0) AS IsNeutral,
			b.oddstype,
			b.winlostdate,
			b.currency,
			b.playercomm, 
			CONVERT(VARCHAR(20), r.EventTime) AS ShowTime,
			0 AS matchid,
			'' AS betcheck,
			'' AS transdesc
		FROM 
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON b.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.Bettype
		WHERE
			b.transdate >= @FromDate AND b.transdate <= @ToDate
			AND b.custid = @CustID 
			AND sbt.ProductID = 5
			AND sbt.EventType = 3
			AND b.statusID IN (0, 1)
	END

	-- RNG Casino
	IF @ShowCS = 1
	BEGIN
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			251 AS sporttype,
			@Username AS UserName,
			b.bettype,
			0 AS leagueID,
			b.refno,
			b.transid,
			ISNULL(b.BetID, 0),
			'' AS matchcode,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status,
			b.stake,
			b.actual_stake, 
			b.transdate,
			b.betteam,
			b.discount,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.IP,
			CONVERT(BIT,0) AS IsNeutral,
			b.oddstype,
			b.winlostdate,
			b.currency,
			b.playercomm,
			'' AS ShowTime,
			b.bettype AS MatchID,
			'' AS betcheck,
			'' AS transdesc
		FROM 
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE
			b.transdate >= @FromDate AND b.transdate <= @ToDate
			AND b.custid = @CustID
			AND (sbt.ProductID = 6 AND sbt.SubProduct = '')
			AND sbt.EventType = 0
			AND b.statusID IN (0, 1)
	END

	-- Keno
	IF @ShowKN = 1
	BEGIN
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			202 AS sporttype,
			@Username AS UserName,
			t.gameid AS bettype,
			0 AS leagueID,
			t.translogid AS refno,
			t.translogid AS transid,
			0 AS BetID,
			'' AS matchcode,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			0 AS hdp1,
			0 AS hdp2,
			t.odds,
			0 AS modds,
			t.status,
			t.stake,
			t.actual_stake,
			t.transdate,
			fnc.ChoiceId AS betteam,
			t.discount,
			0 AS liveindicator,
			0 AS livehomescore,
			0 AS liveawayscore,
			t.ip,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS oddstype,
			t.winlostdate,
			t.currency,
			0 AS playercomm,
			'' AS ShowTime,
			fnc.GameId AS matchid,
			'' AS betcheck,
			'' AS transdesc
		FROM 
			dbo.translog AS t WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON t.gameID = sbt.Bettype
			CROSS APPLY dbo.f_ParseTransDesc(t.transdesc, t.gameid) fnc
		WHERE
			t.transdate >= @FromDate AND t.transdate <= @ToDate 
			AND t.custid = @CustID 
			AND sbt.ProductID = 8
			AND sbt.EventType = 0
			AND t.statusID IN (0, 1)
	END

	-- Microgaming Live Casino
	IF @ShowMGCLC = 1
	BEGIN
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			203 AS sporttype,
			@Username AS UserName,
			t.gameid AS bettype,
			0 AS leagueID,
			t.translogid AS refno,
			t.translogid AS transid,
			0 AS BetID,
			'' AS matchcode,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			0 AS hdp1,
			0 AS hdp2,
			0 AS odds,
			0 AS modds,
			t.status,
			t.stake,
			t.actual_stake,
			t.transdate,
			'' AS betteam,
			t.discount,
			0 AS liveindicator,
			0 AS livehomescore,
			0 AS liveawayscore,
			t.IP,
			CONVERT(BIT, 0) AS IsNeutral,
			0 AS oddstype,
			t.winlostdate,
			t.currency,
			0 AS playercomm,
			'' AS ShowTime,
			0 AS matchid,
			'' AS betcheck,
			'' AS transdesc
		FROM 
			dbo.translog AS t WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON t.gameID = sbt.Bettype
		WHERE
			t.transdate BETWEEN @FromDate AND @ToDate 
			AND t.custid = @CustID 
			AND sbt.ProductID = 13
			AND sbt.EventType = 0
			AND t.statusID IN (0, 1) 
	END

	-- Microgaming RNG Casino, RNG Casino Single Wallet, Voidbridge
	IF @ShowCS = 1 OR @ShowMGCRNG = 1 OR @ShowVB = 1
	BEGIN
		-- Yesterday and today running ticket
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			CASE
				WHEN sbt.ProductID = 6 THEN b.matchid
				WHEN sbt.ProductID = 17 THEN 205
				WHEN sbt.ProductID = 22 THEN 212
			END AS Sporttype,
			@Username AS UserName,
			b.bettype,
			0 AS leagueID,
			b.refno,
			b.transid,
			0 AS BetID,
			'' AS matchcode,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			0 AS hdp1,
			0 AS hdp2,
			0 AS odds,
			0 AS modds,
			'Running' AS Status,
			SUM(brng.stake) AS Stake,
			SUM(brng.actual_stake) AS Actual_Stake,
			b.transdate,
			'' AS betteam,
			b.discount,
			0 AS liveindicator,
			0 AS livehomescore,
			0 AS liveawayscore,
			b.ip,
			CONVERT(BIT, 0) AS IsNeutral,
			0 AS oddstype,
			b.winlostdate,
			b.currency,
			0 AS playercomm,
			'' AS ShowTime,
			0 AS matchid,
			'' AS betcheck,
			CASE
				WHEN sbt.ProductID IN (6, 22) THEN b.transdesc
				ELSE ''
			END AS transdesc
		FROM 
			dbo.bettransRnG AS brng WITH (NOLOCK)
			INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE
			b.transdate BETWEEN @FromDate AND @ToDate
			AND b.winlostdate BETWEEN @Yesterday AND @Today		-- yesterday and today
			AND b.custid = @CustID
			AND (sbt.ProductID IN (17, 22)
				OR (sbt.ProductID = 6 AND sbt.SubProduct <> ''))
			AND sbt.EventType = 0
			AND brng.statusID = 0
		GROUP BY
			b.transid,
			ISNULL(b.betid, 0),
			b.bettype,
			b.refno,
			b.transdate,
			b.discount,
			b.winlostdate,
			b.ip,
			b.currency,
			b.matchid,
			b.transdesc,
			sbt.ProductID
	END

	-- AG Casino, AllBet
	IF @ShowAGC = 1 OR @ShowAB = 1
	BEGIN
		-- Yesterday and today running ticket
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			CASE
				WHEN sbt.ProductID = 11 THEN 250
				WHEN sbt.ProductID = 21 THEN 211
			END AS Sporttype,
			@Username AS UserName,
			b.bettype,
			0 AS leagueID,
			b.refno,
			b.transid,
			0 AS BetID,
			'' AS matchcode,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			0 AS hdp1,
			0 AS hdp2,
			0 AS odds,
			0 AS modds,
			'Running' AS Status,
			SUM(blc.stake) AS Stake,
			SUM(blc.actual_stake) AS Actual_Stake,
			b.transdate,
			'' AS betteam,
			b.discount,
			0 AS liveindicator,
			0 AS livehomescore,
			0 AS liveawayscore,
			b.IP,
			CONVERT(BIT, 0) AS IsNeutral,
			0 AS oddstype,
			b.winlostdate,
			b.currency,
			0 AS playercomm,
			'' AS ShowTime,
			0 AS matchid,
			'' AS betcheck,
			'' AS transdesc
		FROM 
			dbo.bettransLC AS blc WITH (NOLOCK)
			INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE
			b.transdate BETWEEN @FromDate AND @ToDate
			AND b.winlostdate BETWEEN @Yesterday AND @Today		-- yesterday and today
			AND b.custid = @CustID
			AND sbt.ProductID IN (11, 21)
			AND sbt.EventType = 0
			AND blc.statusID = 0
		GROUP BY
			b.transid,
			ISNULL(b.betid, 0),
			b.bettype,
			b.refno,
			b.transdate,
			b.discount,
			b.winlostdate,
			b.ip,
			b.currency,
			sbt.ProductID
	END

	-- check for filtering by currency
	IF @CurrencyID <> 0 
	BEGIN 
		DELETE #BetListSelRunningByDateMem
		WHERE Currency <> @CurrencyID
	END

	-- set totalrows
	SELECT @TotalRows = COUNT(1)
	FROM #BetListSelRunningByDateMem

	SELECT * INTO #TempExchange
	FROM Lrf_f_GetExchangeDaily(@Today, @Today)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #BetListSelRunningByDateMem)

	-- select to paging
	SELECT A.*
	FROM
		(	SELECT
				ROW_NUMBER() OVER(ORDER BY b.TransId DESC) AS RowNum,
				b.*,
				b.Stake * e.USD AS StakeUSD,
				b.Stake * e.EUR AS StakeEUR,
				b.Stake * e.GBP AS StakeGBP,
				b.Actual_Stake * e.USD AS Actual_StakeUSD,
				b.Actual_Stake * e.EUR AS Actual_StakeEUR,
				b.Actual_Stake * e.GBP AS Actual_StakeGBP,
				b.PlayerComm * e.USD AS PlayerCommUSD,
				b.PlayerComm * e.EUR AS PlayerCommEUR,
				b.PlayerComm * e.GBP AS PlayerCommGBP
			FROM #BetListSelRunningByDateMem AS b
				INNER JOIN #TempExchange AS e ON e.exchangeid = b.currency
		) AS A 
	WHERE A.RowNum BETWEEN (((@PageIndex - 1) * @PageSize) + 1) AND (@PageSize * @PageIndex)

	-- Get sub tickets
	DECLARE @BetListDetail TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(20),
		StakeEUR		MONEY,
		StakeUSD		MONEY,
		StakeGBP		MONEY
	);

	-- Horse Racing
	IF EXISTS (	SELECT 1
				FROM #BetListSelRunningByDateMem AS b
					INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.Bettype
				WHERE sbt.ProductID = 2)
	BEGIN
		INSERT INTO @BetListDetail
		SELECT
			bm.refno,
			bm.odds,
			bm.stake,
			bm.status,
			bm.apositiontaking,
			bm.bettype,
			'' AS betteam,
			bm.stake * e.EUR,
			bm.stake * e.USD,
			bm.stake * e.GBP
		FROM dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN #BetListSelRunningByDateMem AS b ON bm.refno = b.TransId
			INNER JOIN #TempExchange AS e ON e.exchangeid = b.Currency
			INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.Bettype
			INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
		WHERE bm.custid = @CustId
			AND sbt.ProductID = 2
			AND sbtm.ProductID = 2
	END

	-- Live Casino
	IF EXISTS (	SELECT 1
				FROM #BetListSelRunningByDateMem AS b
					INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.Bettype
				WHERE sbt.ProductId = 4 )
	BEGIN
		INSERT INTO @BetListDetail
		SELECT 
			bg.refno,
			bg.odds,
			bg.stake,
			bg.status,
			bg.apositiontaking,
			b.bettype,
			bg.betteam,
			bg.stake * e.EUR,
			bg.stake * e.USD,
			bg.stake * e.GBP
		FROM dbo.bettransg AS bg WITH (NOLOCK)
			INNER JOIN #BetListSelRunningByDateMem AS b ON bg.refno = b.RefNo
			INNER JOIN #TempExchange AS e ON e.exchangeid = b.Currency
			INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.bettype
			INNER JOIN @SportBettype AS sbtg ON bg.bettype = sbtg.Bettype
		WHERE bg.custid = @CustId
			AND sbt.ProductID = 4
			AND sbtg.ProductID = 4
	END

	-- Virtual Sports
	IF EXISTS (	SELECT 1
				FROM #BetListSelRunningByDateMem AS b
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				WHERE sbt.ProductId = 5 AND sbt.EventType = 3)
	BEGIN
		INSERT INTO @BetListDetail
		SELECT
			bm.refno,
			bm.odds,
			bm.stake,
			bm.status,
			bm.apositiontaking,
			bm.bettype,
			'' AS betteam,
			bm.stake * e.EUR,
			bm.stake * e.USD,
			bm.stake * e.GBP
		FROM dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN #BetListSelRunningByDateMem AS b ON bm.refno = b.RefNo
			INNER JOIN #TempExchange AS e ON e.exchangeid = b.Currency
			INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.bettype
			INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
		WHERE bm.custid = @CustId
			AND sbt.ProductID = 5
			AND sbt.EventType = 3
			AND sbtm.ProductID = 5
			AND sbtm.EventType = 3
	END

	SELECT * FROM @BetListDetail
	ORDER BY RefNo

	DROP TABLE #BetListSelRunningByDateMem
	DROP TABLE #TempExchange
END





GO

GRANT EXECUTE ON [dbo].[Lrf_BetList_SelRunningByDate_Mem] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelRunningByDate_Mem] TO vnteam
GO
