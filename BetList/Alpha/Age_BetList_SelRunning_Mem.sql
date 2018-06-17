USE [bodb02]
GO
ALTER PROCEDURE [dbo].[Age_BetList_SelRunning_Mem]
	@CustId		INT			= NULL,
	@FromDate	DATETIME	= '',
	@ToDate		DATETIME	= '',
	@GetAll		BIT			= 0,
	@Language	VARCHAR(2)	= 'E',
	@Username	VARCHAR(30)	= NULL, -- for API
	@ProductIds	VARCHAR(MAX)
AS

/*
	Created:
	Task: Bet List
	DB: DBAGE.bodb02
	Original DBAGE.bodb_Age.Age_BetList_SelRunningByDate_Mem
	Revisions:
		- 20080707@Viet: Remove Teamname, Leaguename, Sportname, TypeName
		- 20081106@VinhTrinh: Get more result(Sporttype: Horseracing) for betlist
		- 20090227@Hiep: Get more result for Casino Integration
		- 20090406@HanhVu: remove Refno
		- 20090415@HiepVo: Create @BetListSelAllByDateMem temp table, add column BetID to temp table
		- 20090416@Minh: remove indexName
		- 20090417@HiepVo: re-add Refno since Refno is used for Casino
		- 20090506@Simon: add BetType=112 for Casino
		- 20090522@HiepVo: More filter: ShowHR, ShowFI. Add F.O Horse Racing bet type (split Sport Book); Get more data from bettransm for HR
		- 20090710@Phuc: unhide IP for TB currency
		- 20090930@Phuc: get oddstype
		- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement
		- 20100611@Henry: Change mix-parlay match from 0 to 9
		- 20100902@Kiwi: Add Number Game & IBCBet Bingo
		- 20101007@Henry: Change column transid from INT to BIGINT
		- 20110308@Lukas: change @ShowHR -> @ShowRB
		- 20110408@Amy: Change function to get Odds value AND showed odds type
						Show Odds value AND odds type for Number Game
		- 20110516@Johnson: Apply new arrange bettype
		- 20110801@Sophia: change the range of number game's bettype from 81 to 120, add new bettype 29 for Combination Mix parlay
		- 20110809@Sophia: Not to use function f_GetChoice to get betteam (bettype <> 14, 16)
		- 20110811@Sophia: Add new columns actual_stake AND modds 
		- 20110929@Johnson: Get column matchid into betlist
		- 20111118@Lukas: using [creator] column AS sporttype (for racing tickets)
		- 20111122@Sophia: Add Checktime AND SecAcceptFlag to show status waiting or running
						- Change Sporttype of P2P to 253
		- 20111216@Sophia: Remove function f_GetOddsByBettype, f_GetChoice, f_ShowOddsByBettype
		- 20120112@Sophia: Add show time Table - Shoe - Hand of Live Casino
		- 20120405@Hurri: Change bettype for P2P
		- 20120626@Elodie: exclude outright, HR from sportbook ( in case of matchid = orid)
		- 20120629@Sophia: Show hdp1 for Number game
		- 20120705@Sophia: Get sporttype for outright
		- 20120807@Sophia: Add new parametter @showVS for Virtual Sports (sporttype = 180 for representing)
						. Remove Financial product
		- 20120926@Sophia: Get Comstatus
		- 20130107@Dan: merge code from production
		- 20130121@Dan: Move sp from DB053/bodb02 to DBAGE/bodb_AGE
		- 20130225@Elodie: Add bet list of Virtual HR
		- 20140307@Patrick: Add more Keno product
		- 20140310@Patrick: Exclude keno from Sportbook
		- 20140611@Dom: Support BetRadar [Redmine: #17148]
		- 20140907@Dom: Remove duplicate VS transaction id in bet list feature [Redmine #22012]
		- 20141103@Dom: Apply sport bettype matrix
		- 20150209@Tom: Support 60 BetRadar (27218) Show betcheck coloum on Bettype 216,217
		- 20150522@Bobby: Add GD product
		- 20150706@Bobby: #39097 - Fixing bug for showing Keno's bettype info
		- 20150924@Bobby: Add Metric Gaming product
		- 20150925@Kos: Add Myanmar Odds and Colossus Bet
		- 20151022@Kos: Return [translog].[transid3rd] to support view ticket detail
		- 20151118@Kos: Change length of Username column of temp table to 30
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20151217@Kos: Support Cockfighting (#Redmine: 48850)
		- 20151229@Kos: Support Colossus Bet ticket flow change [Redmine: #49967]
		- 20160106@Kos: Support RNG Casino Single Wallet [Redmine: #48958]
		- 20160125@Kos: Support PH All In One 1.2 [Redmine: #50897]
		- 20160125@Kos: Fix Colossus Bet result issue
		- 20160216@Kos: Support yesterday running ticket for Casino products [Redmine: #52277]
		- 20160216@Kos: Hotfix - Missing Cockfighting [Redmine: #54269]
		- 20160217@Kos: Support AllBet [Redmine: #50864]
		- 20160328@Francis: Change to use inline function instead of table variable to enhance performance
		- 20160401@Kos: Support Macau Games [#Redmine: 54643]
		- 20160411@Kos: Support Combo Parlay [Redmine: #55282]
		- 20160812@Kos: Support NG2
		- 20161010@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20161020@Francis: Check tickets existence in bettransRNG/bettransLC before querying to enhance performance [Redmine: #58288]
		- 20161101@Kos: Don't support Bingo and P2P anymore [#Redmine: 53988]
					- Support Fishing World [#Redmine: 65934]
		- 20170301@Kos: Support KickOffTime for Virtual Soccer and Virtual Tennis [#Redmine: 71906]
		- 20170327@Kos: Change input params, return column CustId for Microsite bet list [#Redmine: 66992]
		- 20170620@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20170705@Kos: Support Keno Lottery [#Redmine: 77929]
		- 20170718@Kos: Don't parse transdesc for Keno anymore [#Redmine: 80082]
		- 20170829@Kos: Support Lucky 3 [#Redmine: 75277]
		- 20171027@Kos: Support Bullfighting [#Redmine: 84961]
					- Don't support Live Casino anymore
		- 20180131@Kos: Don't support Racing, Cockfighting, RNG Casino (bettype 71, 72) anymore [#Redmine: 86086]
		- 20180326@Kos: Hotfix - Remove duplicate Virtual Sports [#Redmine: 92748]
		- 20180330@Kos: Support ONERnG Jackpot [#Redmine: 88652]
		- 20180418@Kos: Support Pragmatic Casino [#Redmine: 92160]
		- 20180510@Kos: Support Keno 6 new Mini Games [#Redmine: 93759]
		- 20180515@Kos: Add Match No for Bullfighting [#Redmine: 84961]
		- 20180617@Kos: Change to use bodb02.bettrans instead of bodb_Age.bettrans_running [#Redmine: 97037]
*/

BEGIN
	SET NOCOUNT ON

	IF @CustId IS NULL
		SELECT @CustId = custid
		FROM dbo.customer WITH (NOLOCK)
		WHERE username = @Username
	ELSE
		SELECT @Username = username
		FROM dbo.customer WITH (NOLOCK)
		WHERE custid = @CustId

	DECLARE @BetListSelRunningByDateMem TABLE (
		SportType		SMALLINT,
		CustId			INT,
		Username		NVARCHAR(50),
		BetType			SMALLINT,
		LeagueId		INT,
		RefNo			BIGINT,
		TransId			BIGINT,
		BetId			BIGINT,
		MatchCode		NVARCHAR(50),
		Race			NVARCHAR(20),
		MatchId			INT,
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		MOdds			MONEY,
		Status			NVARCHAR(10),
		Stake			MONEY,
		Actual_Stake	MONEY,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		BetTeam			NVARCHAR(20),
		APositionTaking SMALLMONEY,
		MPositionTaking SMALLMONEY,
		SPositionTaking SMALLMONEY,
		ADiscount		SMALLMONEY,
		MDiscount		SMALLMONEY,
		SDiscount		SMALLMONEY,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				NVARCHAR(15),
		IsNeutral		BIT,
		OddsType		TINYINT,
		ShowTime		NVARCHAR(50),
		ComStatus		NVARCHAR(20),
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000),
		OddsSpread		MONEY
	)

	DECLARE @BetListDetail TABLE(
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		MPositionTaking	SMALLMONEY,
		SPositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(20),
		TransDesc		VARCHAR (1000)
	)

	/* Get sport bettype */
	-- Get Betradar Virtual Sports in addition to Virtual Sports
	SET @ProductIds = dbo.f_AddRelatedProducts(@ProductIds)

	-- Check SP Version
	DECLARE @isTest BIT = 0

	SELECT @isTest = dbo.f_CheckSPVersion(@@PROCID)

	DECLARE @SportBettype TABLE (ProductID INT, Bettype INT, EventType INT, SubProduct VARCHAR(500))

	INSERT INTO @SportBettype
	SELECT ProductID, Bettype, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest)
	WHERE BetType NOT IN (901, 902, 903, 904, 71, 72)
	/* End get sport bettype */

	DECLARE @Today SMALLDATETIME,
		@Yesterday SMALLDATETIME

	SELECT @Today = CONVERT(DATE, CURRENT_TIMESTAMP, 112),
		@Yesterday = DATEADD(DAY, -1, @Today)
	
	IF @GetAll = 0
	BEGIN
		-- Sportsbook
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductID = 1)
		BEGIN
			INSERT INTO @BetListSelRunningByDateMem
			SELECT
				m.sporttype,
				@CustId AS CustId,
				@Username AS UserName,
				b.bettype,
				m.leagueid,
				b.refno,
				b.transid,
				ISNULL(b.betid, 0),
				m.matchcode,
				'' AS Race,
				m.matchid,
				m.homeid,
				m.awayid,
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
				b.transdate AS WinLostDate,
				b.betteam,
				b.apositiontaking,
				b.mpositiontaking,
				b.spositiontaking,
				b.discount AS adiscount,
				b.adiscount AS mdiscount,
				b.sdiscount AS sdiscount,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.IP,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.oddstype,
				'' AS showtime,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				b.betcheck,
				ISNULL(b.transdesc, '') AS TransDesc,
				ISNULL(b.oddsspread, 0) AS OddsSpread
			FROM
				dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_custid)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE
				b.transdate >= @FromDate AND b.transdate <= @ToDate
				AND b.custid = @CustId
				AND b.statusID IN (0, 1)
				AND s.ProductID = 1
				AND s.EventType = 1
				AND s.SubProduct NOT IN ('MG-SuperLive')	-- --exclude running tickets of MetricGaming

			-- Outright
			INSERT INTO @BetListSelRunningByDateMem
			SELECT
				l.sporttype,
				@CustId AS CustId,
				@Username AS UserName,
				b.bettype,
				m.leagueID,
				b.refno,
				b.transid,
				ISNULL(b.betid, 0),
				m.matchcode,
				m.GroupMatch AS Race,
				0 AS matchid,
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
				b.transdate AS WinLostDate,
				'' AS Betteam,
				b.apositiontaking,
				b.mpositiontaking,
				b.spositiontaking,
				b.discount AS adiscount,
				b.adiscount AS mdiscount,
				b.sdiscount AS sdiscount,
				0 AS liveindicator,
				0 AS livehomescore,
				0 AS liveawayscore,
				b.IP,
				CONVERT(BIT,0) AS IsNeutral,
				0 AS oddstype,
				'' AS showtime,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				'' AS BetCheck,
				'' AS TransDesc,
				0 AS OddsSpread
			FROM
				dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_custid)
				INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
			WHERE
				b.bettype = 10
				AND b.transdate >= @FromDate AND b.transdate <= @ToDate 
				AND b.custid = @CustId
				AND b.statusID IN (0, 1)

			-- Mix Parlay, System Parlay
			INSERT INTO @BetListSelRunningByDateMem
			SELECT
				0 AS sporttype,
				@CustId AS CustId,
				@Username AS UserName,
				b.bettype,
				0 AS leagueID,
				b.refno,
				b.transid,
				ISNULL(b.betid, 0),
				'' AS matchcode,
				'' AS Race,
				0 AS matchid,
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
				b.transdate AS WinLostDate,
				b.betteam,
				b.apositiontaking,
				b.mpositiontaking,
				b.spositiontaking,
				b.discount AS adiscount,
				b.adiscount AS mdiscount,
				b.sdiscount AS sdiscount,
				0 AS liveindicator,
				0 AS livehomescore,
				0 AS liveawayscore,
				b.IP,
				CONVERT(BIT,0) AS IsNeutral,
				0 AS oddstype,
				'' AS showtime,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS TransDesc,
				0 AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_custid)
			WHERE
				b.transdate >= @FromDate AND b.transdate <= @ToDate
				AND b.custid = @CustId
				AND b.bettype IN (9, 29)
				AND b.matchid IN (9, 29)
				AND b.statusID IN (0, 1)

			-- Metric Gaming
			INSERT INTO @BetListSelRunningByDateMem
			SELECT
				m.Sporttype,
				@CustId AS CustId,
				@Username AS UserName,
				b.GameId AS bettype,
				m.leagueID,
				b.TransLogId AS RefNo,
				b.translogid AS TransId,
				0 AS BetID,
				ISNULL(m.matchcode, '') AS matchcode,
				'' AS Race,
				b.eventid AS MatchID,
				m.homeID,
				m.awayID,
				0 AS hdp1,
				0 AS hdp2,
				b.odds,
				0 AS modds,
				b.status,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.transdate AS WinLostDate,
				'' AS betteam,
				b.apositiontaking,
				b.mpositiontaking,
				b.spositiontaking,
				b.discount AS adiscount,
				b.adiscount AS mdiscount,
				b.sdiscount AS sdiscount,
				0 AS liveindicator,
				0 AS livehomescore,
				0 AS liveawayscore,
				b.ip,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				CASE
					WHEN s.SubProduct IN ('MG-SuperLive') THEN CONVERT(TINYINT, ISNULL(b.custom1, 0))
					ELSE 0
				END AS oddstype,
				ISNULL(m.showtime,'') AS showtime,
				0 AS comstatus,
				'' AS BetCheck,
				b.transdesc,
				0 AS OddsSpread
			FROM 
				dbo.translog AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.eventid = m.matchid
			WHERE b.transdate >= @FromDate AND b.transdate <= @ToDate 
				AND b.custid = @CustId
				AND b.statusID IN (0, 1)
				AND s.SubProduct IN ('MG-SuperLive')
		END

		-- Number Game, Lucky 3, Virtual Sports, Betradar Virtual Sports (EventType = 1)
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductID IN (3, 5, 26, 27))
		BEGIN
			INSERT INTO @BetListSelRunningByDateMem
			SELECT
				m.sporttype,
				@CustId AS CustId,
				@Username AS UserName,
				b.bettype,
				m.leagueid,
				b.refno,
				b.transid,
				ISNULL(b.betid, 0),
				m.matchcode,
				'' AS Race,
				CASE
					WHEN s.ProductID IN (5, 27) THEN m.matchid
					ELSE 0
				END AS MatchId,
				CASE
					WHEN s.ProductID IN (5, 27) THEN m.homeid
					ELSE 0
				END AS HomeId,
				CASE
					WHEN s.ProductID IN (5, 27) THEN m.awayid
					ELSE 0
				END AS AwayId,
				b.hdp1,
				CASE
					WHEN s.ProductID IN (5, 27) THEN b.hdp2
					ELSE 0
				END AS Hdp2,
				b.odds,
				b.modds,
				CASE
					WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.status
				END AS status,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.transdate AS WinLostDate,
				b.betteam,
				b.apositiontaking,
				b.mpositiontaking,
				b.spositiontaking,
				CASE
					WHEN s.ProductID = 26 THEN 0
					ELSE b.discount
				END AS adiscount,
				CASE
					WHEN s.ProductID = 26 THEN 0
					ELSE b.adiscount
				END AS mdiscount,
				CASE
					WHEN s.ProductID = 26 THEN 0
					ELSE b.sdiscount
				END AS sdiscount,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.IP,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				CASE
					WHEN s.ProductID IN (3, 5, 27) THEN b.oddstype
					ELSE 0
				END AS OddsType,
				CASE
					WHEN s.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
					ELSE ''
				END AS ShowTime,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				'' AS BetCheck,
				CASE
					WHEN s.ProductID IN (26, 27) THEN ISNULL(b.transdesc, '')
					ELSE ''
				END AS TransDesc,
				0 AS OddsSpread
			FROM
				dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_custid)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE
				b.transdate BETWEEN @FromDate AND @ToDate
				AND b.custid = @CustId
				AND b.statusID IN (0, 1)
				AND s.ProductID IN (3, 5, 26, 27)
				AND s.EventType = 1
		END

		-- Virtual Sports (EventType = 3)
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductID = 5)
		BEGIN
			INSERT INTO @BetListSelRunningByDateMem
			SELECT
				r.SportType,
				@CustId AS CustId,
				@Username AS UserName,
				b.bettype,
				r.LeagueID,
				b.refno,
				b.transid,
				ISNULL(b.betid, 0),
				o.RacerNum AS matchcode,
				b.oddsid AS Race,
				b.matchid,
				o.RacerID AS homeID,
				0 AS awayID,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				b.status,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.transdate AS WinLostDate,
				'' AS betteam,
				b.apositiontaking,
				b.mpositiontaking,
				b.spositiontaking,
				b.discount AS adiscount,
				b.adiscount AS mdiscount,
				b.sdiscount AS sdiscount,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.IP,
				CONVERT(BIT,0) AS IsNeutral,
				0 AS OddsType,
				r.EventTime AS showtime,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				'' AS BetCheck,
				'' AS TransDesc,
				0 AS OddsSpread
			FROM
				dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_custid)
				INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON o.EventID = r.EventID
				INNER JOIN @SportBettype AS s ON s.BetType = b.BetType
			WHERE
				b.transdate BETWEEN @FromDate AND @ToDate
				AND b.custid = @CustId
				AND b.statusID IN (0, 1)
				AND s.ProductID = 5
				AND s.EventType = 3
		END

		-- Betradar Virtual Sports (EventType = 0)
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductID = 27)
		BEGIN
			-- Mix Parlay
			INSERT INTO @BetListSelRunningByDateMem
			SELECT
				0 AS sporttype,
				@CustId AS CustId,
				@Username AS UserName,
				b.bettype,
				0 AS leagueID,
				b.refno,
				b.transid,
				ISNULL(b.betid, 0),
				'' AS matchcode,
				'' AS Race,
				0 AS matchid,
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
				b.transdate AS WinLostDate,
				b.betteam,
				b.apositiontaking,
				b.mpositiontaking,
				b.spositiontaking,
				b.discount AS adiscount,
				b.adiscount AS mdiscount,
				b.sdiscount AS sdiscount,
				0 AS liveindicator,
				0 AS livehomescore,
				0 AS liveawayscore,
				b.IP,
				CONVERT(BIT,0) AS IsNeutral,
				0 AS oddstype,
				'' AS showtime,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS TransDesc,
				0 AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_custid)
			WHERE b.transdate BETWEEN @FromDate AND @ToDate
				AND b.custid = @CustId
				AND b.bettype = 2799
				AND b.matchid = 2799
				AND b.statusID IN (0, 1)
		END

		-- Keno, Gold Deluxe, Colossus Bet, Lottery (translog)
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductID IN (8, 12, 15, 28))
		BEGIN
			INSERT INTO @BetListSelRunningByDateMem
			SELECT
				CASE
					WHEN s.ProductID = 8 THEN 202
					WHEN s.ProductID = 12 THEN 255
					WHEN s.ProductID = 15 THEN 204
					WHEN s.ProductID = 28 THEN 220
					ELSE 0
				END AS Sporttype,
				@CustId AS CustId,
				@Username AS UserName,
				b.gameID AS bettype,
				0 AS leagueID,
				b.TransLogId AS RefNo,
				b.translogid AS TransId,
				0 AS BetID,
				'' AS matchcode,
				'' AS Race,
				CASE 
					WHEN s.ProductID = 12 THEN 255
					ELSE 0
				END AS MatchID,
				0 AS homeID,
				0 AS awayID,
				0 AS hdp1,
				0 AS hdp2,
				b.odds,
				0 AS modds,
				b.status,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.transdate AS WinLostDate,
				'' AS betteam,
				b.apositiontaking,
				b.mpositiontaking,
				b.spositiontaking,
				b.discount AS adiscount,
				b.adiscount AS mdiscount,
				b.sdiscount AS sdiscount,
				0 AS liveindicator,
				0 AS livehomescore,
				0 AS liveawayscore,
				b.IP,
				CONVERT(BIT, 0) AS IsNeutral,
				0 AS OddsType,
				'' AS showtime,
				0 AS comstatus,
				CASE
					WHEN s.ProductID = 12 THEN b.Gameid3rd
					WHEN s.ProductID = 15 THEN b.Tranid3rd
					WHEN s.ProductId = 8 THEN ISNULL(b.custom2, '')
					ELSE '' 
				END AS BetCheck,
				CASE 
					WHEN s.ProductID IN (8, 28) THEN b.transdesc
					ELSE ''
				END AS TransDesc,
				0 AS OddsSpread
			FROM
				dbo.translog AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
			WHERE b.transdate >= @FromDate AND b.transdate <= @ToDate
				AND b.custid = @CustId
				AND b.statusID IN (0, 1)
				AND s.ProductID IN (8, 12, 15, 28)
		END

		-- Bullfighting (EventType = 5) (translog)
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductID = 30)
		BEGIN
			INSERT INTO @BetListSelRunningByDateMem
			SELECT
				m.SportType,
				@CustId AS CustId,
				@Username AS UserName,
				b.gameID AS bettype,
				m.League3rdId AS LeagueId,
				b.TransLogId AS RefNo,
				b.translogid AS TransId,
				0 AS BetId,
				m.MatchNo AS MatchCode,
				'' AS Race,
				CASE
					WHEN s.ProductID = 30 THEN b.eventid
					ELSE 0
				END AS MatchId,
				m.HomeId,
				m.AwayId,
				CASE
					WHEN s.ProductID = 30 THEN CONVERT(SMALLMONEY, ISNULL(b.custom2, 0))
					ELSE 0
				END AS Hdp1,
				0 AS Hdp2,
				b.odds,
				0 AS MOdds,
				b.status,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.transdate AS WinLostDate,
				CASE
					WHEN s.ProductID = 30 THEN b.custom3
					ELSE ''
				END AS BetTeam,
				b.apositiontaking,
				b.mpositiontaking,
				b.spositiontaking,
				b.discount AS adiscount,
				b.adiscount AS mdiscount,
				b.sdiscount AS sdiscount,
				b.liveindicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				b.ip,
				CONVERT(BIT, 0) AS IsNeutral,
				CASE
					WHEN s.ProductID = 30 THEN CONVERT(TINYINT, ISNULL(b.custom1, 0))
					ELSE 0
				END AS OddsType,
				'' AS ShowTime,
				0 AS ComStatus,
				CASE
					WHEN s.ProductID = 30 THEN ISNULL(b.Tranid3rd, '')
					ELSE ''
				END AS BetCheck,
				CASE
					WHEN s.ProductID = 30 THEN ISNULL(b.transdesc, '')
					ELSE ''
				END AS TransDesc,
				0 AS OddsSpread
			FROM
				dbo.translog AS b WITH (NOLOCK)
				INNER JOIN dbo.Match3rd AS m WITH (NOLOCK) ON b.eventid = m.Match3rdId
				INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
			WHERE b.transdate BETWEEN @FromDate AND @ToDate
				AND b.custid = @CustId
				AND b.statusID IN (0, 1)
				AND s.ProductID = 30
		END

		-- Colossus Bet bettrans
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductID = 15)
		BEGIN
			INSERT INTO @BetListSelRunningByDateMem
			SELECT
				204 AS Sporttype,
				@CustId AS CustId,
				@Username AS UserName,
				b.bettype,
				0 AS leagueID,
				b.refno,
				b.transId,
				0 AS BetID,
				'' AS matchcode,
				'' AS Race,
				0 AS MatchID,
				0 AS homeID,
				0 AS awayID,
				0 AS hdp1,
				0 AS hdp2,
				0 AS odds,
				0 AS modds,
				b.status,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.transdate AS WinLostDate,
				'' AS betteam,
				b.apositiontaking,
				b.mpositiontaking,
				b.spositiontaking,
				b.discount AS adiscount,
				b.adiscount AS mdiscount,
				b.sdiscount AS sdiscount,
				0 AS liveindicator,
				0 AS livehomescore,
				0 AS liveawayscore,
				b.IP,
				CONVERT(BIT, 0) AS IsNeutral,
				0 AS oddstype,
				'' AS showtime,
				0 AS comstatus,
				ISNULL(bm.betcheck, '') AS BetCheck,
				'' AS TransDesc,
				0 AS OddsSpread
			FROM
				dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_custid)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				LEFT JOIN dbo.bettransm AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
			WHERE b.transdate >= @FromDate AND b.transdate <= @ToDate
				AND b.custid = @CustId
				AND b.statusID IN (0, 1)
				AND s.ProductID = 15
		END

		-- NG2 bettrans
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductID = 23)
		BEGIN
			INSERT INTO @BetListSelRunningByDateMem
			SELECT
				CASE
					WHEN s.ProductId = 23 AND s.Bettype BETWEEN 2501 AND 2539 THEN 213
					WHEN s.ProductId = 23 AND s.Bettype BETWEEN 2541 AND 2579 THEN 214
					WHEN s.ProductId = 23 AND s.Bettype BETWEEN 2581 AND 2619 THEN 215
					WHEN s.ProductId = 23 AND s.Bettype BETWEEN 2621 AND 2659 THEN 216
					WHEN s.ProductId = 23 AND s.Bettype BETWEEN 2681 AND 2699 THEN 218
					ELSE 0
				END AS Sporttype,
				@CustId AS CustId,
				@Username AS UserName,
				b.bettype,
				0 AS leagueID,
				b.refno,
				b.transId,
				ISNULL(b.betid, 0) AS BetId,
				'' AS matchcode,
				'' AS Race,
				0 AS MatchID,
				0 AS homeID,
				0 AS awayID,
				b.hdp1,
				b.hdp2,
				b.odds,
				0 AS modds,
				b.status,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.transdate AS WinLostDate,
				'' AS betteam,
				b.apositiontaking,
				b.mpositiontaking,
				b.spositiontaking,
				b.discount AS adiscount,
				b.adiscount AS mdiscount,
				b.sdiscount AS sdiscount,
				0 AS liveindicator,
				b.livehomescore,
				0 AS liveawayscore,
				b.IP,
				CONVERT(BIT, 0) AS IsNeutral,
				0 AS oddstype,
				'' AS showtime,
				0 AS comstatus,
				'' AS BetCheck,
				ISNULL(b.transdesc, '') AS TransDesc, 
				0 AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_custid)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.transdate >= @FromDate AND b.transdate <= @ToDate
				AND b.custid = @CustId
				AND b.statusID IN (0, 1)
				AND s.ProductID = 23
		END

		-- RNG Casino Single Wallet, Macau Games, Fishing World, Pragmatic Casino
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductID IN (6, 22, 24, 32))
		BEGIN
			IF EXISTS ( SELECT TOP(1) 1
						FROM dbo.bettransRnG WITH (NOLOCK)
						WHERE custid = @CustId AND winlostdate >= @Yesterday)
				INSERT INTO @BetListSelRunningByDateMem
				SELECT
					CASE
						WHEN s.ProductID = 6 THEN b.matchid
						WHEN s.ProductID = 22 THEN 212
						WHEN s.ProductID = 24 THEN 219
						WHEN s.ProductID = 32 THEN 248
						ELSE 0
					END AS Sporttype,
					@CustId AS CustId,
					@Username AS UserName,
					b.bettype,
					0 AS leagueID,
					b.refno,
					b.transid,
					0 AS BetID,
					'' AS matchcode,
					'' AS Race,
					0 AS MatchID,
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
					b.winlostdate,
					'' AS betteam,
					AVG(brng.apositiontaking) AS APositiontaking,
					AVG(brng.mpositiontaking) AS MPositiontaking,
					AVG(brng.spositiontaking) AS SPositiontaking,
					AVG(brng.discount) AS adiscount,
					AVG(brng.adiscount) AS mdiscount,
					AVG(brng.sdiscount) AS sdiscount,
					0 AS liveindicator,
					0 AS livehomescore,
					0 AS liveawayscore,
					b.ip,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS oddstype,
					'' AS showtime,
					0 AS comstatus,
					'' AS BetCheck,
					b.transdesc,
					0 AS OddsSpread
				FROM dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_custid_matchid_bettype)
					INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = b.transid
					INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
				WHERE 
					b.transdate BETWEEN @FromDate AND @ToDate
					AND b.winlostdate >= @Yesterday	-- yesterday and later summary ticket
					AND b.custid = @CustId
					AND brng.[status] = 'running'
					AND s.ProductID IN (6, 22, 24, 32)
				GROUP BY
					b.transid,
					b.bettype,
					b.refno,
					b.transdate,
					b.winlostdate,
					b.ip,
					b.matchid,
					b.transdesc,
					s.ProductID
		END

		-- AllBet
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductID = 21)
		BEGIN
			IF EXISTS ( SELECT TOP(1) 1
						FROM dbo.bettransLC WITH (NOLOCK)
						WHERE custid = @CustId AND winlostdate >= @Yesterday)
				INSERT INTO @BetListSelRunningByDateMem
				SELECT
					211 AS Sporttype,
					@CustId AS CustId,
					@Username AS UserName,
					b.bettype,
					0 AS leagueID,
					b.refno,
					b.transid,
					0 AS BetID,
					'' AS matchcode,
					'' AS Race,
					0 AS MatchID,
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
					b.winlostdate,
					'' AS betteam,
					AVG(blc.apositiontaking) AS APositiontaking,
					AVG(blc.mpositiontaking) AS MPositiontaking,
					AVG(blc.spositiontaking) AS SPositiontaking,
					AVG(blc.discount) AS adiscount,
					AVG(blc.adiscount) AS mdiscount,
					AVG(blc.sdiscount) AS sdiscount,
					0 AS liveindicator,
					0 AS livehomescore,
					0 AS liveawayscore,
					b.IP,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS oddstype,
					'' AS showtime,
					0 AS comstatus,
					'' AS BetCheck,
					'' AS TransDesc,
					0 AS OddsSpread
				FROM dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_custid_matchid_bettype)
					INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = b.transid
					INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
				WHERE 
					b.transdate BETWEEN @FromDate AND @ToDate
					AND b.winlostdate >= @Yesterday	-- yesterday and later summary ticket
					AND b.custid = @CustId
					AND blc.[status] = 'running'
					AND s.ProductID = 21
				GROUP BY
					b.transid,
					b.bettype,
					b.refno,
					b.transdate,
					b.winlostdate,
					b.ip,
					b.matchid,
					b.transdesc,
					s.ProductID
		END
	END
	ELSE --@GetAll = 1
	BEGIN
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductID = 1)
		BEGIN
			INSERT INTO @BetListSelRunningByDateMem
			SELECT
				m.sporttype,
				@CustId AS CustId,
				@Username AS UserName,
				b.bettype,
				m.leagueID,
				b.refno,
				b.transid,
				ISNULL(b.betid, 0),
				m.matchcode,
				'' AS Race,
				m.matchid,
				m.homeID,
				m.awayID,
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
				b.transdate AS WinLostDate,
				b.betteam,
				b.apositiontaking,
				b.mpositiontaking,
				b.spositiontaking,
				b.discount AS adiscount,
				b.adiscount AS mdiscount,
				b.sdiscount AS sdiscount,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.IP,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.OddsType,
				'' AS showtime,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				b.betcheck,
				ISNULL(b.transdesc, '') AS TransDesc,
				ISNULL(b.oddsspread, 0) AS OddsSpread
			FROM
				dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_custid)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE
				b.custid = @CustId
				AND b.statusID IN (0, 1)
				AND s.ProductID = 1
				AND s.EventType = 1
				AND s.SubProduct NOT IN ('MG-SuperLive')

			-- Outright
			INSERT INTO @BetListSelRunningByDateMem
			SELECT
				l.sporttype,
				@CustId AS CustId,
				@Username AS UserName,
				b.bettype,
				m.leagueid,
				b.refno,
				b.transid,
				ISNULL(b.betid, 0),
				m.matchcode,
				m.GroupMatch AS Race,
				0 AS matchid,
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
				b.transdate AS WinLostDate,
				'' AS Betteam,
				b.apositiontaking,
				b.mpositiontaking,
				b.spositiontaking,
				b.discount AS adiscount,
				b.adiscount AS mdiscount,
				b.sdiscount AS sdiscount,
				0 AS liveindicator,
				0 AS livehomescore,
				0 AS liveawayscore,
				b.IP,
				CONVERT(BIT,0) AS IsNeutral,
				0 AS oddstype,
				'' AS showtime,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				'' AS BetCheck,
				'' AS TransDesc,
				0 AS OddsSpread
			FROM
				dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_custid)
				INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
			WHERE
				b.bettype = 10
				AND b.custid = @CustId
				AND b.statusID IN (0, 1)

			-- Mix Parlay, System Parlay
			INSERT INTO @BetListSelRunningByDateMem
			SELECT
				0 AS sporttype,
				@CustId AS CustId,
				@Username AS UserName,
				b.bettype,
				0 AS leagueID,
				b.refno,
				b.transid,
				ISNULL(b.betid, 0),
				'' AS matchcode,
				'' AS Race,
				0 AS matchid,
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
				b.transdate AS WinLostDate,
				b.betteam,
				b.apositiontaking,
				b.mpositiontaking,
				b.spositiontaking,
				b.discount AS adiscount,
				b.adiscount AS mdiscount,
				b.sdiscount AS sdiscount,
				0 AS liveindicator,
				0 AS livehomescore,
				0 AS liveawayscore,
				b.IP,
				CONVERT(BIT,0) AS IsNeutral,
				0 AS oddstype,
				'' AS showtime,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS TransDesc,
				0 AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_custid)
			WHERE
				b.custid = @CustId
				AND b.statusID IN (0, 1)
				AND b.bettype IN (9, 29)
				AND b.matchid IN (9, 29)

			-- Metric Gaming
			INSERT INTO @BetListSelRunningByDateMem
			SELECT
				m.sporttype,
				@CustId AS CustId,
				@Username AS UserName,
				b.GameId AS bettype,
				m.leagueid,
				b.translogid AS RefNo,
				b.translogid AS TransId,
				0 AS BetID,
				ISNULL(m.MatchCode,'') AS matchcode,
				'' AS Race,
				b.eventid AS MatchID,
				m.homeID,
				m.awayID,
				0 AS hdp1,
				0 AS hdp2,
				b.odds,
				0 AS modds,
				b.status,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.transdate AS WinLostDate,
				'' AS betteam,
				b.apositiontaking,
				b.mpositiontaking,
				b.spositiontaking,
				b.discount AS adiscount,
				b.adiscount AS mdiscount,
				b.sdiscount AS sdiscount,
				0 AS liveindicator,
				0 AS livehomescore,
				0 AS liveawayscore,
				b.ip,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				CASE
					WHEN s.SubProduct IN ('MG-SuperLive') THEN CONVERT(TINYINT, ISNULL(b.custom1, 0))
					ELSE 0
				END AS oddstype,
				ISNULL(m.showtime,'') AS showtime,
				0 AS comstatus,
				'' AS BetCheck,
				b.transdesc,
				0 AS OddsSpread
			FROM 
				dbo.translog AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.eventid = m.matchid
			WHERE b.custid = @CustId
				AND b.statusID IN (0, 1)
				AND s.SubProduct IN ('MG-SuperLive')
		END

		-- Number Game, Lucky 3, Virtual Sports, Betradar Virtual Sports (EventType = 1)
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductID IN (3, 5, 26, 27))
		BEGIN
			INSERT INTO @BetListSelRunningByDateMem
			SELECT
				m.sporttype,
				@CustId AS CustId,
				@Username AS UserName,
				b.bettype,
				m.leagueid,
				b.refno,
				b.transid,
				ISNULL(b.betid, 0),
				m.matchcode,
				'' AS Race,
				CASE
					WHEN s.ProductID IN (5, 27) THEN m.matchid
					ELSE 0
				END AS MatchId,
				CASE
					WHEN s.ProductID IN (5, 27) THEN m.homeid
					ELSE 0
				END AS HomeId,
				CASE
					WHEN s.ProductID IN (5, 27) THEN m.awayid
					ELSE 0
				END AS AwayId,
				b.hdp1,
				CASE
					WHEN s.ProductID IN (5, 27) THEN b.hdp2
					ELSE 0
				END AS Hdp2,
				b.odds,
				b.modds,
				CASE
					WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.status
				END AS status,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.transdate AS WinLostDate,
				b.betteam,
				b.apositiontaking,
				b.mpositiontaking,
				b.spositiontaking,
				CASE
					WHEN s.ProductID = 26 THEN 0
					ELSE b.discount
				END AS adiscount,
				CASE
					WHEN s.ProductID = 26 THEN 0
					ELSE b.adiscount
				END AS mdiscount,
				CASE
					WHEN s.ProductID = 26 THEN 0
					ELSE b.sdiscount
				END AS sdiscount,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.IP,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				CASE
					WHEN s.ProductID IN (3, 5, 27) THEN b.oddstype
					ELSE 0
				END AS OddsType,
				CASE
					WHEN s.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
					ELSE ''
				END AS ShowTime,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				'' AS BetCheck,
				CASE
					WHEN s.ProductID IN (26, 27) THEN ISNULL(b.transdesc, '')
					ELSE ''
				END AS TransDesc,
				0 AS OddsSpread
			FROM
				dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_custid)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE
				b.custid = @CustId
				AND b.statusID IN (0, 1)
				AND s.ProductID IN (3, 5, 26, 27)
				AND s.EventType = 1
		END

		-- Virtual Sports (EventType = 3)
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductID = 5)
		BEGIN
			INSERT INTO @BetListSelRunningByDateMem
			SELECT
				r.SportType,
				@CustId AS CustId,
				@Username AS UserName,
				b.bettype,
				r.LeagueID,
				b.refno,
				b.transid,
				ISNULL(b.betid, 0),
				o.RacerNum AS matchcode,
				b.oddsid AS Race,
				b.matchid,
				o.RacerID AS homeID,
				0 AS awayID,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				b.status,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.transdate AS WinLostDate,
				'' AS betteam,
				b.apositiontaking,
				b.mpositiontaking,
				b.spositiontaking,
				b.discount AS adiscount,
				b.adiscount AS mdiscount,
				b.sdiscount AS sdiscount,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.IP,
				CONVERT(BIT, 0) AS IsNeutral,
				0 AS OddsType,
				r.EventTime AS showtime,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				'' AS BetCheck,
				'' AS TransDesc,
				0 AS OddsSpread
			FROM
				dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_custid)
				INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON o.EventID = r.EventID
				INNER JOIN @SportBettype AS s ON s.BetType = b.BetType 
			WHERE
				b.custid = @CustId
				AND b.statusID IN (0, 1)
				AND s.ProductID = 5
				AND s.EventType = 3
		END

		-- Betradar Virtual Sports (EventType = 0)
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductID = 27)
		BEGIN
			-- Mix Parlay
			INSERT INTO @BetListSelRunningByDateMem
			SELECT
				0 AS SportType,
				@CustId AS CustId,
				@Username AS UserName,
				b.bettype,
				0 AS leagueID,
				b.refno,
				b.transid,
				ISNULL(b.betid, 0),
				'' AS matchcode,
				'' AS Race,
				0 AS matchid,
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
				b.transdate AS WinLostDate,
				b.betteam,
				b.apositiontaking,
				b.mpositiontaking,
				b.spositiontaking,
				b.discount AS adiscount,
				b.adiscount AS mdiscount,
				b.sdiscount AS sdiscount,
				0 AS liveindicator,
				0 AS livehomescore,
				0 AS liveawayscore,
				b.IP,
				CONVERT(BIT,0) AS IsNeutral,
				0 AS oddstype,
				'' AS showtime,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS TransDesc,
				0 AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_custid)
			WHERE b.custid = @CustId
				AND b.statusID IN (0, 1)
				AND b.bettype = 2799
				AND b.matchid = 2799
		END

		-- Keno, Gold Deluxe, Colossus Bet, Lottery (translog)
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductID IN (8, 12, 15, 28))
		BEGIN
			INSERT INTO @BetListSelRunningByDateMem
			SELECT
				CASE
					WHEN s.ProductID = 8 THEN 202
					WHEN s.ProductID = 12 THEN 255
					WHEN s.ProductID = 15 THEN 204
					WHEN s.ProductID = 28 THEN 220
					ELSE 0
				END	AS Sporttype,
				@CustId AS CustId,
				@Username AS UserName,
				b.GameId AS bettype,
				0 AS leagueID,
				b.TransLogId AS RefNo,
				b.translogid AS TransId,
				0 AS BetID,
				'' AS matchcode,
				'' AS Race,
				CASE 
					WHEN s.ProductID = 12 THEN 255
					ELSE 0
				END AS matchid,
				0 AS homeID,
				0 AS awayID,
				0 AS hdp1,
				0 AS hdp2,
				b.odds,
				0 AS modds,
				b.status,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.transdate AS WinLostDate,
				'' AS betteam,
				b.apositiontaking,
				b.mpositiontaking,
				b.spositiontaking,
				b.discount AS adiscount,
				b.adiscount AS mdiscount,
				b.sdiscount AS sdiscount,
				0 AS liveindicator,
				0 AS livehomescore,
				0 AS liveawayscore,
				b.IP,
				CONVERT(BIT, 0) AS IsNeutral,
				0 AS OddsType,
				'' AS showtime,
				0 AS comstatus,
				CASE
					WHEN s.ProductID = 12 THEN b.Gameid3rd
					WHEN s.ProductID = 15 THEN b.Tranid3rd
					WHEN s.ProductId = 8 THEN ISNULL(b.custom2, '')
					ELSE '' 
				END AS BetCheck,
				CASE
					WHEN s.ProductID IN (8, 28) THEN b.transdesc
					ELSE ''
				END AS TransDesc,
				0 AS OddsSpread
			FROM
				dbo.translog AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.bettype = b.gameid
			WHERE b.custid = @CustId
				AND b.statusID IN (0, 1)
				AND s.ProductID IN (8, 12, 15, 28)
		END

		-- Bullfighting (EventType = 5) (translog)
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductID = 30)
		BEGIN
			INSERT INTO @BetListSelRunningByDateMem
			SELECT
				m.SportType,
				@CustId AS CustId,
				@Username AS UserName,
				b.gameID AS bettype,
				m.League3rdId AS LeagueId,
				b.TransLogId AS RefNo,
				b.translogid AS TransId,
				0 AS BetId,
				m.MatchNo AS MatchCode,
				'' AS Race,
				CASE
					WHEN s.ProductID = 30 THEN b.eventid
					ELSE 0
				END AS MatchId,
				m.HomeId,
				m.AwayId,
				CASE
					WHEN s.ProductID = 30 THEN CONVERT(SMALLMONEY, ISNULL(b.custom2, 0))
					ELSE 0
				END AS Hdp1,
				0 AS Hdp2,
				b.odds,
				0 AS MOdds,
				b.status,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.transdate AS WinLostDate,
				CASE
					WHEN s.ProductID = 30 THEN b.custom3
					ELSE ''
				END AS BetTeam,
				b.apositiontaking,
				b.mpositiontaking,
				b.spositiontaking,
				b.discount AS adiscount,
				b.adiscount AS mdiscount,
				b.sdiscount AS sdiscount,
				b.liveindicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				b.ip,
				CONVERT(BIT, 0) AS IsNeutral,
				CASE
					WHEN s.ProductID = 30 THEN CONVERT(TINYINT, ISNULL(b.custom1, 0))
					ELSE 0
				END AS OddsType,
				'' AS ShowTime,
				0 AS ComStatus,
				CASE
					WHEN s.ProductID = 30 THEN ISNULL(b.Tranid3rd, '')
					ELSE ''
				END AS BetCheck,
				CASE
					WHEN s.ProductID = 30 THEN ISNULL(b.transdesc, '')
					ELSE ''
				END AS TransDesc,
				0 AS OddsSpread
			FROM
				dbo.translog AS b WITH (NOLOCK)
				INNER JOIN dbo.Match3rd AS m WITH (NOLOCK) ON b.eventid = m.Match3rdId
				INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
			WHERE b.custid = @CustId
				AND b.statusID IN (0, 1)
				AND s.ProductID = 30
		END

		-- Colossus Bet bettrans
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductID = 15)
		BEGIN
			INSERT INTO @BetListSelRunningByDateMem
			SELECT
				204 AS Sporttype,
				@CustId AS CustId,
				@Username AS UserName,
				b.bettype,
				0 AS leagueID,
				b.refno,
				b.transId,
				0 AS BetID,
				'' AS matchcode,
				'' AS Race,
				0 AS MatchID,
				0 AS homeID,
				0 AS awayID,
				0 AS hdp1,
				0 AS hdp2,
				0 AS odds,
				0 AS modds,
				b.status,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.transdate AS WinLostDate,
				'' AS betteam,
				b.apositiontaking,
				b.mpositiontaking,
				b.spositiontaking,
				b.discount AS adiscount,
				b.adiscount AS mdiscount,
				b.sdiscount AS sdiscount,
				0 AS liveindicator,
				0 AS livehomescore,
				0 AS liveawayscore,
				b.IP,
				CONVERT(BIT, 0) AS IsNeutral,
				0 AS oddstype,
				'' AS showtime,
				0 AS comstatus,
				ISNULL(bm.betcheck, '') AS BetCheck,
				'' AS TransDesc, 
				0 AS OddsSpread
			FROM 
				dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_custid)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				LEFT JOIN dbo.bettransm AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
			WHERE b.custid = @CustId 
				AND b.statusID IN (0, 1)
				AND s.ProductID = 15
		END

		-- NG2 bettrans
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductID = 23)
		BEGIN
			INSERT INTO @BetListSelRunningByDateMem
			SELECT
				CASE
					WHEN s.ProductId = 23 AND s.Bettype BETWEEN 2501 AND 2539 THEN 213
					WHEN s.ProductId = 23 AND s.Bettype BETWEEN 2541 AND 2579 THEN 214
					WHEN s.ProductId = 23 AND s.Bettype BETWEEN 2581 AND 2619 THEN 215
					WHEN s.ProductId = 23 AND s.Bettype BETWEEN 2621 AND 2659 THEN 216
					WHEN s.ProductId = 23 AND s.Bettype BETWEEN 2681 AND 2699 THEN 218
					ELSE 0
				END AS Sporttype,
				@CustId AS CustId,
				@Username AS UserName,
				b.bettype,
				0 AS leagueID,
				b.refno,
				b.transId,
				ISNULL(b.betid, 0) AS BetId,
				'' AS matchcode,
				'' AS Race,
				0 AS MatchID,
				0 AS homeID,
				0 AS awayID,
				b.hdp1,
				b.hdp2,
				b.odds,
				0 AS modds,
				b.status,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.transdate AS WinLostDate,
				'' AS betteam,
				b.apositiontaking,
				b.mpositiontaking,
				b.spositiontaking,
				b.discount AS adiscount,
				b.adiscount AS mdiscount,
				b.sdiscount AS sdiscount,
				0 AS liveindicator,
				b.livehomescore,
				0 AS liveawayscore,
				b.IP,
				CONVERT(BIT, 0) AS IsNeutral,
				0 AS oddstype,
				'' AS showtime,
				0 AS comstatus,
				'' AS BetCheck,
				ISNULL(b.transdesc, '') AS TransDesc, 
				0 AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_custid)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.statusID IN (0, 1)
				AND s.ProductID = 23
		END

		-- RNG Casino Single Wallet, Macau Games, Fishing World, Pragmatic Casino
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductID IN (6, 22, 24, 32))
		BEGIN
			IF EXISTS ( SELECT TOP(1) 1
						FROM dbo.bettransRnG WITH (NOLOCK)
						WHERE custid = @CustId AND winlostdate >= @Yesterday)
				INSERT INTO @BetListSelRunningByDateMem
				SELECT
					CASE
						WHEN s.ProductID = 6 THEN b.matchid
						WHEN s.ProductID = 22 THEN 212
						WHEN s.ProductID = 24 THEN 219
						WHEN s.ProductID = 32 THEN 248
						ELSE 0
					END AS Sporttype,
					@CustId AS CustId,
					@Username AS UserName,
					b.bettype,
					0 AS leagueID,
					b.refno,
					b.transid,
					0 AS BetID,
					'' AS matchcode,
					'' AS Race,
					0 AS MatchID,
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
					b.winlostdate,
					'' AS betteam,
					AVG(brng.apositiontaking) AS APositiontaking,
					AVG(brng.mpositiontaking) AS MPositiontaking,
					AVG(brng.spositiontaking) AS SPositiontaking,
					AVG(brng.discount) AS adiscount,
					AVG(brng.adiscount) AS mdiscount,
					AVG(brng.sdiscount) AS sdiscount,
					0 AS liveindicator,
					0 AS livehomescore,
					0 AS liveawayscore,
					b.ip,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS oddstype,
					'' AS showtime,
					0 AS comstatus,
					'' AS BetCheck,
					b.transdesc,
					0 AS OddsSpread
				FROM dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_custid_matchid_bettype)
					INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = b.transid
					INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
				WHERE b.winlostdate >= @Yesterday	-- yesterday and later summary ticket
					AND b.custid = @CustId
					AND brng.[status] = 'running'
					AND s.ProductID IN (6, 22, 24, 32)
				GROUP BY
					b.transid,
					b.bettype,
					b.refno,
					b.transdate,
					b.winlostdate,
					b.ip,
					b.matchid,
					b.transdesc,
					s.ProductID
		END

		-- AllBet
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductID = 21)
		BEGIN
			IF EXISTS ( SELECT TOP(1) 1
						FROM dbo.bettransLC WITH (NOLOCK)
						WHERE custid = @CustId AND winlostdate >= @Yesterday)
				INSERT INTO @BetListSelRunningByDateMem
				SELECT
					211 AS Sporttype,
					@CustId AS CustId,
					@Username AS UserName,
					b.bettype,
					0 AS leagueID,
					b.refno,
					b.transid,
					0 AS BetID,
					'' AS matchcode,
					'' AS Race,
					0 AS MatchID,
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
					b.winlostdate,
					'' AS betteam,
					AVG(blc.apositiontaking) AS APositiontaking,
					AVG(blc.mpositiontaking) AS MPositiontaking,
					AVG(blc.spositiontaking) AS SPositiontaking,
					AVG(blc.discount) AS adiscount,
					AVG(blc.adiscount) AS mdiscount,
					AVG(blc.sdiscount) AS sdiscount,
					0 AS liveindicator,
					0 AS livehomescore,
					0 AS liveawayscore,
					b.IP,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS oddstype,
					'' AS showtime,
					0 AS comstatus,
					'' AS BetCheck,
					'' AS TransDesc,
					0 AS OddsSpread
				FROM dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_custid_matchid_bettype)
					INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = b.transid
					INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
				WHERE b.winlostdate >= @Yesterday	-- yesterday and later summary ticket
					AND b.custid = @CustId
					AND blc.[status] = 'running'
					AND s.ProductID = 21
				GROUP BY
					b.transid,
					b.bettype,
					b.refno,
					b.transdate,
					b.winlostdate,
					b.ip,
					b.matchid,
					b.transdesc,
					s.ProductID
		END
	END

	-- Get currency name
	DECLARE @CurrencyName NVARCHAR(50)

	SELECT @CurrencyName = ex.currency
	FROM dbo.custinfo AS c WITH (NOLOCK)
		INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON c.currency = ex.exchangeid
	WHERE c.custid = @CustId

	SELECT *,
		@CurrencyName AS Currency
	FROM @BetListSelRunningByDateMem
	ORDER BY TransId DESC

	-- Get sub tickets
	-- Virtual Sports (bettype 1233)
	IF EXISTS (	SELECT 1
				FROM @BetListSelRunningByDateMem AS b
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
			bm.mpositiontaking,
			bm.spositiontaking,
			bm.bettype,
			'' AS betteam,
			'' AS transdesc
		FROM dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN @BetListSelRunningByDateMem AS b ON bm.refno = b.refno
			INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
		WHERE bm.custid = @CustId
			AND sbt.ProductID = 5
			AND sbt.EventType = 3
			AND sbtm.ProductID = 5
			AND sbtm.EventType = 3
	END

	-- Gold Deluxe
	IF EXISTS (	SELECT 1
				FROM @BetListSelRunningByDateMem AS b
					INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.Bettype
				WHERE sbt.ProductId = 12 )
	BEGIN
		INSERT INTO @BetListDetail
		SELECT
			bg.refno,
			bg.odds,
			bg.stake,
			bg.status,
			bg.apositiontaking,
			bg.mpositiontaking,
			bg.spositiontaking,
			bg.bettype,
			bg.betteam,
			bg.transdesc
		FROM dbo.bettransg AS bg WITH (NOLOCK)
			INNER JOIN @BetListSelRunningByDateMem AS b ON bg.refno = b.transid
			INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			INNER JOIN @SportBettype AS sbtg ON bg.bettype = sbtg.Bettype
		WHERE bg.custid = @CustId
			AND sbt.ProductID = 12
			AND sbtg.ProductID = 12
	END

	SELECT * FROM @BetListDetail
	ORDER BY RefNo
END





GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelRunning_Mem] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelRunning_Mem] TO [bodbDownlineNetView] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelRunning_Mem] TO [vnteam] AS [dbo]
GO
