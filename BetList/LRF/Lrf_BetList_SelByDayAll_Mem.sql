ALTER PROCEDURE [dbo].[Lrf_BetList_SelByDayAll_Mem]
	@AgentList			VARCHAR(MAX),
	@CustId				INT,
	@FromDate			SMALLDATETIME,
	@MoveBetsDay		SMALLDATETIME,
	@TransType			INT				= 0,
	@PageSize			INT				= 1000,
	@PageIndex			INT				= 1,
	@TotalRows			INT				= 0 OUTPUT,
	@SumWinLost			MONEY			= 0 OUTPUT,
	@SumLicenseeWL		MONEY			= 0 OUTPUT,
	@SumComm			MONEY			= 0 OUTPUT,
	@SumPlayerComm		MONEY			= 0 OUTPUT,
	@SumWinLostUSD		MONEY			= 0 OUTPUT,
	@SumLicenseeWLUSD	MONEY			= 0 OUTPUT,
	@SumCommUSD			MONEY			= 0 OUTPUT,
	@SumPlayerCommUSD	MONEY			= 0 OUTPUT,
	@SumWinLostEUR		MONEY			= 0 OUTPUT,
	@SumLicenseeWLEUR	MONEY			= 0 OUTPUT,
	@SumCommEUR			MONEY			= 0 OUTPUT,
	@SumPlayerCommEUR	MONEY			= 0 OUTPUT,
	@SumWinLostGBP		MONEY			= 0 OUTPUT,
	@SumLicenseeWLGBP	MONEY			= 0 OUTPUT,
	@SumCommGBP			MONEY			= 0 OUTPUT,
	@SumPlayerCommGBP	MONEY			= 0 OUTPUT,
	@ErrCode			INT				= 0 OUTPUT,
	@ErrMsg				NVARCHAR(4000)	= '' OUTPUT
AS

/*
	Created: Henry@20101210
	Task: Bet List for Daily Statement
	DB: DBEXT.bodb02
	Original: Age_BetList_SelByDayAll_Mem
	Revisions:
		- 20110214@Jacob: Add column discount IN the result SET
		- 20110303@Henry: suppport based currency
		- 20110408@Amy: Change function to get Odds value AND odds type
		- 20110712@Henry: Add column LicenseeWL
		- 20110725@Henry: Get refund tickets
		- 20110729@Henry: offer 3 new bettypes for Number Game + Combination Mix Parlay
		- 20111128@Henry: Compare Checktime and CURRENT_TIMESTAMP to show waiting or running status
		- 20111212@Jim: Edit condition bettype<19000
		- 20111229@Jim: change the way to get odds/oddstype/betteam to web dev
		- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily
		- 20120319@Henry: show main transid for sub-ticket of system parlay 
		- 20120724@Jim: add player commision value 
		- 20120817@Jim: add live casino
		- 20120913@Jim: add virtual sport 
		- 20130410@Jim: return betteam value for Parlay (mix parlay & system parlay) ticket
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20130905@Jim: support VHR
		- 20140310@Hannah: offer Keno
		- 20140324@Daniel: fix show RNG Casino / Bingo bets due to matchid = 0
		- 20140411@Francis: fix incorrect sporttypes showing for VHR, Racing
		- 20140630@Hannah: offer BetRadar and Sporting Solution
		- 20141121@Jim: support multiple currency per one member
		- 20150128@Winnie: Add currency GBP 
		- 20150413@Bobby: Re-format code  & #32844 new 60 bettypes - betradar phase 2
		- 20150511@Kiwi: Fixed the bug (RedmineID: #35562)
		- 20150608@Edward: Support Microgaming
		- 20150608@Edward: Support Bet Trade
		- 20150729@Edward: Return betcheck for Microgaming
		- 20150806@Edward: Fixed bug return 0 instead of game id for Microgaming
		- 20150831@Edward: Fixed bettrade performance and odds value
		- 20150916@Kos: Support Microgaming RNG Casino
		- 20150923@Kos: Support AG Casino
		- 20151028@Kos: Change ProductId, SportType of Microgaming RNG Casino
		- 20151124@Kos: Support Microgaming RNG Casino Jackpot Grand Prize ticket
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20151228@Kos: Support RNG Casino Single Wallet
		- 20160202@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160216@Kos: Support yesterday running ticket [Redmine: #52277]
		- 20160406@Kos: Support Voidbridge [#Redmine: 54925]
		- 20160413@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20160718@Kos: Remove Bingo and change to use inline function for SportBettypeMatrix
		- 20160727@Kos: Support AllBet [#Redmine: 61066]
		- 20160801@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20160913@Kos: Support Colossus Bets [#Redmine: 63785]
		- 20161007@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20161114@Kos: Support Fishing World [#Redmine: 66737]
		- 20170303@Kos: Support KickOffTime for Virtual Soccer and Virtual Tennis [#Redmine: 71906]
		- 20170307@Kos: Support sub licensees [#Redmine: 71679]

	Param's Explanation: 
		+ @TransType:
			1: Won/Lose/Draw/Refund ticket
			2: Void/Reject ticket
			3: Running/Waiting ticket
			4: Grand Prize ticket (Microgaming RNG Casino)
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempAg TABLE (CustId INT, Currency INT)

	-- Get AgentList
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO @TempAg (CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SELECT ErrCode = 100,
			ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH

	/*
		WON: 112, LOSE: 113, DRAW: 111, REFUND: 103
		VOID: 102, REJECT: 101
		RUNNING: 0, WAITING: 1
	*/
	DECLARE @tmpStatus TABLE ([statusID] INT)

	IF @TransType = 1
	BEGIN
		INSERT INTO @tmpStatus([statusID])
		SELECT 111 UNION ALL
		SELECT 112 UNION ALL
		SELECT 113 UNION ALL
		SELECT 103
	END
	ELSE IF @TransType = 2
	BEGIN
		INSERT INTO @tmpStatus([statusID])
		SELECT 101 UNION ALL
		SELECT 102
	END 
	ELSE IF @TransType = 3
	BEGIN
		INSERT INTO @tmpStatus([statusID])
		SELECT 0 UNION ALL
		SELECT 1
	END
	ELSE IF @TransType = 4
	BEGIN
		INSERT INTO @tmpStatus([statusID])
		SELECT 111 UNION ALL
		SELECT 112 UNION ALL
		SELECT 113 
	END

	DECLARE @Yesterday SMALLDATETIME
		, @Today SMALLDATETIME

	SELECT @Today = DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)
		, @Yesterday = DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)

	DECLARE @Data TABLE (
		SportType		INT,
		LeagueId		INT,
		HomeId			INT,
		AwayId			INT,
		BetType			SMALLINT,
		MatchCode		NVARCHAR(50),
		Race			NVARCHAR(50),
		MatchId			INT,
		TransId			BIGINT,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		RefNo			NVARCHAR(50),
		BetId			BIGINT,
		OddsId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Modds			MONEY,
		OddsType		TINYINT,
		Odds			MONEY,
		BetTeam			NVARCHAR(50),
		Status			NVARCHAR(50),
		BetStatus		NVARCHAR(50),
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		Discount		DECIMAL(9,8),
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LiveIndicator	BIT,
		FinalHomeScore	SMALLINT,
		FinalAwayScore	SMALLINT,
		HtHomeScore		SMALLINT,
		HtAwayScore		SMALLINT,
		Ip				NVARCHAR(20),
		Username		NVARCHAR(50),
		IsNeutral		BIT,
		Currency		SMALLINT,
		ShowTime		NVARCHAR(50), -- table - shoe - hand of Live Casino
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(300)
	)

	-- filer bettypes by sporttype
	DECLARE @SportBettype TABLE (ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID <= 6 OR ProductID IN (8, 11, 13, 15, 17, 21, 22, 24) -- not suport for LIC system

	DELETE @SportBettype
	WHERE ProductID = 1 AND Bettype = 904

	IF @TransType = 3	-- Don't support running RNG Casino old bet type (71)
	BEGIN
		DELETE @SportBettype
		WHERE ProductID = 6 AND SubProduct = ''
	END

	IF @TransType = 4	-- support only for Microgaming RNG Casino, Colossus Bets
	BEGIN
		DELETE @SportBettype
		WHERE ProductID NOT IN (15, 17)
	END

	-- END filer bettypes

	IF @FromDate <= @MoveBetsDay
	BEGIN
		-- single bet
		INSERT INTO @Data
		SELECT
			m.sporttype,
			m.leagueid,
			m.homeID,
			m.awayID,
			b.bettype,
			m.matchcode,
			'' AS race,
			m.matchid,
			b.transid,
			b.transdate,
			b.winlostdate,
			b.refno,
			b.betid,
			b.oddsid,
			b.hdp1,
			b.hdp2,
			modds,
			b.Oddstype,
			b.odds,
			b.betteam,
			b.status,
			m.betstatus,
			b.stake,
			b.actual_stake,
			(b.winlost-b.actual_stake) AS winlost,
			CASE WHEN BA.transid IS NULL THEN - (b.winlost-b.actual_stake) ELSE 0 END AS LicenseeWL,
			CASE WHEN b.bettype = 903 THEN b.awinlost ELSE b.comm END AS comm,
			b.playercomm,
			b.discount,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.finalhomescore,
			m.finalawayscore,
			m.hthomescore,
			m.htawayscore,
			b.IP,
			b.Username,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.currency,
			CASE
				WHEN sbt.ProductID = 4 THEN ISNULL(m.showtime, '')
				WHEN sbt.ProductID = 5 THEN CONVERT(NVARCHAR(50), m.kickofftime)
				ELSE ''
			END AS ShowTime,
			CASE 
				WHEN sbt.ProductID = 1 AND b.bettype IN (216,217) THEN b.betcheck 
				ELSE '' 
			END AS betcheck,
			ISNULL(b.transdesc, '') AS transdesc
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
			LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction AS BA WITH (NOLOCK) ON b.transid = BA.transid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
		WHERE
			b.custid = @custid
			AND b.winlostdate = @FromDate
			AND sbt.EventType = 1
			AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

		-- RNG Casino
		INSERT INTO @Data 
		SELECT
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN 251
				WHEN sbt.ProductID = 6 AND sbt.SubProduct <> '' THEN b.matchid
			END AS Sporttype,
			0 AS leagueid,
			0 AS homeID,
			0 AS awayID,
			b.bettype,
			'' AS matchcode,
			'' AS race,
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.bettype
				ELSE 0
			END AS MatchId,
			b.transid, 
			b.transdate, 
			b.winlostdate,
			b.refno, 
			b.betid,
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.oddsid
				ELSE 0
			END AS oddsid,
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.hdp1
				ELSE 0
			END AS hdp1,
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.hdp2
				ELSE 0
			END AS hdp2,
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.modds
				ELSE 0
			END AS modds,
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.oddstype
				ELSE 0
			END AS Oddstype,
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.Odds
				ELSE 0
			END AS Odds,
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.Betteam
				ELSE ''
			END AS Betteam,
			b.status,
			'' AS betstatus, 
			b.stake,
			b.actual_stake,
			(b.winlost-b.actual_stake) AS winlost, 
			- (b.winlost-b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.livehomescore
				ELSE ''
			END AS livehomescore,
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.liveawayscore
				ELSE ''
			END AS liveawayscore,
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.liveindicator
				ELSE ''
			END AS liveindicator,
			0 AS FinalHomeScore, 
			0 AS FinalAwayScore,
			0 AS hthomescore, 
			0 AS htawayscore,
			b.IP,
			b.Username,
			0 AS IsNeutral,
			b.currency,
			'' AS ShowTime,
			'' AS betcheck,
			CASE
				WHEN sbt.ProductID = 6 AND sbt.SubProduct <> '' THEN b.transdesc
				ELSE ''
			END AS transdesc
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
		WHERE b.custid = @custid 
			AND b.winlostdate = @FromDate
			AND sbt.ProductID = 6
			AND sbt.EventType = 0
			AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

		-- Keno
		IF @TransType = 1 OR @TransType = 2
		BEGIN
			INSERT INTO @Data 
			SELECT
				202 AS sporttype,
				0 AS leagueid,
				0 AS homeID,
				0 AS awayID,
				b.bettype,
				'' AS matchcode,
				'' AS race,
				t.gameid AS matchid,
				b.transid,
				b.transdate,
				b.winlostdate,
				b.refno,
				0 AS betid,
				0 AS oddsid,
				0 AS hdp1,
				0 AS hdp2,
				b.modds,
				0 AS Oddstype,
				b.odds,
				t.choiceid AS betteam,
				b.status,
				'' AS betstatus,
				b.stake,
				b.actual_stake,
				(b.winlost-b.actual_stake) AS winlost,
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.discount,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				0 AS hthomescore,
				0 AS htawayscore,
				b.IP,
				b.Username,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM 
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				OUTER APPLY dbo.[f_ParseTransDesc](b.TransDesc, b.bettype) t
			WHERE
				b.custid = @custid
				AND b.winlostdate = @FromDate 
				AND sbt.ProductID = 8
				AND sbt.EventType = 0
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
		END

		-- Virtual Horse Racing
		INSERT INTO @Data 
		SELECT
			r.sporttype,
			r.leagueid,
			o.RacerID AS homeID,
			0 awayID,
			b.bettype,
			CONVERT (VARCHAR(50),o.RacerNum) AS matchcode,
			'' AS race,
			o.EventID AS matchid,
			b.transid,
			b.transdate,
			b.winlostdate,
			b.refno,
			b.betid,
			b.oddsid,
			b.hdp1,
			b.hdp2,
			modds,
			b.Oddstype,
			b.odds,
			b.betteam,
			b.status,
			r.betstatus, 
			b.stake,
			b.actual_stake,
			(b.winlost-b.actual_stake) AS winlost,
			- (b.winlost-b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			0 AS FinalHomeScore,
			0 AS FinalAwayScore,
			0 AS hthomescore,
			0 AS htawayscore,
			b.IP,
			b.Username,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			CONVERT(VARCHAR(20),r.eventTime) AS ShowTime
			,'' AS betcheck
			,'' AS transdesc
		FROM 
			dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.VSOutright14 AS o WITH (NOLOCK) ON b.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
		WHERE
			b.custid = @custid
			AND b.winlostdate = @FromDate 
			AND sbt.ProductId = 5 
			AND sbt.EventType = 3
			AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

		-- Mixed Parlay, System Parlay
		INSERT INTO @Data 
		SELECT
			0,
			0,
			0,
			0,
			b.bettype,
			'',
			'' AS race,
			0, 
			CASE WHEN (ISNULL(b.BetID,0) = 0 OR b.bettype = 9) THEN b.transid ELSE betid END AS transid, 
			b.transdate,
			b.winlostdate,
			b.refno,
			0,
			0,
			b.hdp1,
			b.hdp2,
			b.modds,
			0 AS OddsType,
			b.odds,
			b.betteam,
			b.status,
			'' betstatus,
			b.stake,
			b.actual_stake,
			(b.winlost-b.actual_stake) AS winlost,
			CASE WHEN BA.transid IS NULL THEN - (b.winlost-b.actual_stake) ELSE 0 END AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			b.IP,
			b.Username,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			'' AS ShowTime,
			ISNULL(b.betcheck, '') AS BetCheck,
			'' AS transdesc
		FROM 
			dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
			LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction AS BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.custid = @custid
			AND b.winlostdate = @FromDate
			AND sbt.ProductID = 1
			AND sbt.EventType = 0
			AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

		-- Outright
		INSERT INTO @Data 
		SELECT
			l.sporttype,
			m.leagueID,
			m.teamID AS homeid,
			0 AS awayid,
			b.bettype,
			m.matchcode,
			m.groupmatch AS race,
			m.orid,
			b.transid,
			b.transdate,
			b.winlostdate,
			b.refno,
			0,
			10,
			b.hdp1,
			b.hdp2,
			b.modds,
			0 AS OddsType,
			b.odds,
			'',
			b.status,
			'', 
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS winlost,
			CASE
				WHEN ISNULL(BA.transid, 0) = 0 AND b.bettype = 10 THEN - (b.winlost - b.actual_stake)
				WHEN b.bettype IN (31, 32, 33) THEN awinlost
				ELSE 0
			END AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			b.livehomescore,
			b.liveawayscore,
			0,
			0,
			0,
			0,
			0,
			b.IP,
			b.Username,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			'' AS ShowTime,
			'' AS betcheck,
			'' AS transdesc
		FROM 
			dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.outright14 AS m WITH (NOLOCK) on b.matchid = m.orid
			INNER JOIN dbo.league AS l WITH (NOLOCK) on m.leagueid = l.leagueid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
			LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction AS BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.custid = @custid
			AND b.winlostdate = @FromDate
			AND sbt.ProductID IN (1, 2) 
			AND sbt.EventType = 2
			AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

		-- Microgaming Live Casino, Microgaming RNG Casino, AG Casino, AllBet, Macau Games, Fishing World
		IF @TransType = 1 OR @TransType = 2
		BEGIN
			INSERT INTO @Data 
			SELECT
				CASE
					WHEN sbt.ProductID = 11 THEN 250
					WHEN sbt.ProductID = 13 THEN 203
					WHEN sbt.ProductID = 17 THEN 205
					WHEN sbt.ProductID = 21 THEN 211
					WHEN sbt.ProductID = 22 THEN 212
					WHEN sbt.ProductID = 24 THEN 219
				END AS sporttype,
				0 AS leagueid,
				0 AS homeID,
				0 AS awayID,
				b.bettype,
				'' AS matchcode,
				'' AS race,
				0 AS matchid,
				b.transid,
				b.transdate,
				b.winlostdate,
				b.refno,
				0 AS betid,
				0 AS oddsid,
				0 AS hdp1,
				0 AS hdp2,
				0 AS modds,
				0 AS Oddstype,
				0 AS odds,
				'' AS betteam,
				b.status,
				'' AS betstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS winlost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.discount,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				0 AS hthomescore,
				0 AS htawayscore,
				b.ip,
				b.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				CASE
					WHEN sbt.ProductID = 13 THEN b.betcheck
					ELSE ''
				END AS betcheck,
				CASE
					WHEN sbt.ProductID IN (22, 24) THEN b.transdesc
					ELSE ''
				END AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
			WHERE
				b.custid = @custid
				AND b.winlostdate = @FromDate 
				AND sbt.ProductID IN (11, 13, 17, 21, 22, 24)
				AND sbt.EventType = 0
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
				AND @TransType <> 4
		END

		-- Colossus Bets
		IF @TransType <> 4
		BEGIN
			INSERT INTO @Data
			SELECT
				204 AS SportType,
				0 AS LeagueId,
				0 AS HomeId,
				0 AS AwayId,
				b.bettype,
				'' AS MatchCode,
				'' AS Race,
				0 AS MatchId,
				b.transid,
				b.transdate,
				b.winlostdate,
				b.refno,
				0 AS BetId,
				0 AS OddsId,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS MOdds,
				0 AS OddsYype,
				0 AS Odds,
				'' AS BetTeam,
				b.status,
				'' AS BetStatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.discount,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				0 AS LiveIndicator,
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				0 AS HtHomeScore,
				0 AS HtAwayScore,
				b.ip,
				b.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				ISNULL(bm.betcheck, '') AS BetCheck,
				'' AS TransDesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				LEFT JOIN dbo.bettransm14 AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
			WHERE
				b.custid = @custid
				AND b.winlostdate = @FromDate 
				AND sbt.ProductID = 15
				AND sbt.EventType = 0
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
		END

		-- Grand Prize Jackpot Win
		IF @TransType = 4
		BEGIN
			-- Microgaming RNG Casino
			INSERT INTO @Data
			SELECT
				205 AS sporttype,
				0 AS leagueid,
				0 AS homeID,
				0 AS awayID,
				b.gameID AS BetType,
				'' AS matchcode,
				'' AS race,
				0 AS matchid,
				b.transid,
				pt.transdate,
				pt.winlostdate,
				b.refno,
				0 AS betid,
				0 AS oddsid,
				0 AS hdp1,
				0 AS hdp2,
				0 AS modds,
				0 AS Oddstype,
				0 AS odds,
				'' AS betteam,
				b.status,
				'' AS betstatus,
				b.stake,
				b.actual_stake,
				pt.WinAmount AS winlost,
				0 AS LicenseeWL,
				0 AS comm,
				0 AS playercomm,
				0 AS discount,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				0 AS hthomescore,
				0 AS htawayscore,
				b.IP,
				b.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				b.TranId3rd AS BetCheck,
				b.transdesc
			FROM
				DBACC.bodb02.dbo.PayoutTrans AS pt WITH (NOLOCK)
				INNER JOIN dbo.bettransRnG14 AS b WITH (NOLOCK) ON pt.RefNo = b.transid
				INNER JOIN @SportBettype AS sbt ON b.gameID = sbt.bettype
			WHERE
				pt.custid = @custid
				AND pt.winlostdate = @FromDate 
				AND sbt.ProductID = 17
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

			-- Colossus Bets
			INSERT INTO @Data
			SELECT
				204 AS SportType,
				0 AS LeagueId,
				0 AS HomeId,
				0 AS AwayId,
				b.bettype,
				'' AS MatchCode,
				'' AS Race,
				0 AS MatchId,
				b.transid,
				b.transdate,
				b.winlostdate,
				b.refno,
				0 AS BetId,
				0 AS OddsId,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS MOdds,
				0 AS OddsType,
				0 AS Odds,
				'' AS BetTeam,
				b.status,
				'' AS BetStatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.discount,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				0 AS LiveIndicator,
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				0 AS HtHomeScore,
				0 AS HtAwayScore,
				b.ip,
				b.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				ISNULL(bm.betcheck, '') AS BetCheck,
				b.transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				LEFT JOIN dbo.bettransm14 AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
			WHERE
				b.custid = @custid
				AND b.winlostdate = @FromDate 
				AND sbt.ProductID = 15
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
				AND EXISTS (	SELECT 1 
								FROM DBACC.bodb02.dbo.PayoutTrans AS pt WITH (NOLOCK)
								WHERE pt.refno = b.transid AND pt.PayoutStatus IN ('Completed', 'Expired'))
		END

		-- For BetTrade
		UPDATE betList
		SET betList.Odds	= originBetList.Odds
			,betList.Stake	= originBetList.Stake
			,betList.comm	= CASE WHEN betList.Bettype = 902 THEN commBetList.comm ELSE betList.comm END
			,betList.BetID	= originBetList.Bettype
		FROM @Data AS betList
			INNER JOIN dbo.bettrans14 AS originBetList WITH (NOLOCK) ON betList.RefNo = originBetList.TransID
			LEFT JOIN @Data AS commBetList ON betList.RefNO = commBetList.RefNo AND commBetList.Bettype = 903
		WHERE betList.Sporttype = 1 AND betList.Bettype IN (901, 902)

		DELETE @Data WHERE Sporttype = 1 AND Bettype = 903
		-- End Bet Trade
	END
	ELSE
	BEGIN
		-- single bet
		INSERT INTO @Data 
		SELECT
			m.sporttype,
			m.leagueid,
			m.homeID,
			m.awayID,
			b.bettype,
			m.matchcode,
			'' AS race,
			m.matchid,
			b.transid,
			b.transdate,
			b.winlostdate,
			b.refno,
			b.betid,
			b.oddsid,
			b.hdp1,
			b.hdp2,
			b.modds,
			b.oddstype,
			b.odds,
			b.betteam,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 
					AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status,
			m.betstatus,
			b.stake,
			b.actual_stake,
			CASE
				WHEN b.statusID NOT IN (0,1) THEN (b.winlost-b.actual_stake) 
				ELSE 0 
			END AS winlost,
			CASE
				WHEN b.statusID NOT IN (0,1) THEN
					CASE WHEN BA.transid IS NULL THEN - (b.winlost-b.actual_stake) ELSE 0 END 
				ELSE 0
			END AS LicenseeWL,
			CASE 
				WHEN b.bettype = 903 THEN b.awinlost 
				ELSE 
					CASE WHEN b.statusID NOT IN (0,1) THEN b.comm ELSE 0 
					END
			END AS comm,
			b.playercomm,
			b.discount,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.finalhomescore,
			m.finalawayscore,
			m.hthomescore,
			m.htawayscore,
			b.IP,
			b.Username,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.currency,
			CASE
				WHEN sbt.ProductID = 4 THEN ISNULL(m.showtime, '')
				WHEN sbt.ProductID = 5 THEN CONVERT(NVARCHAR(50), m.kickofftime)
				ELSE ''
			END AS ShowTime,
			CASE 
				WHEN sbt.ProductID = 1 THEN b.betcheck
				ELSE '' 
			END AS betcheck,
			ISNULL(b.transdesc, '') AS transdesc
		FROM 
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
			LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction AS BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.custid = @custid
			AND b.winlostdate = @FromDate
			AND sbt.EventType = 1
			AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

		-- RNG Casino
		INSERT INTO @Data
		SELECT
			251 AS Sporttype,
			0 AS leagueid,
			0 AS homeID,
			0 AS awayID,
			b.bettype,
			'' AS matchcode,
			'' AS race,
			b.bettype AS matchid,
			b.transid,
			b.transdate,
			b.winlostdate,
			b.refno,
			b.betid,
			b.oddsid,
			b.hdp1,
			b.hdp2,
			b.modds,
			b.Oddstype,
			b.odds,
			b.betteam,
			b.status,
			'' betstatus,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			0 AS FinalHomeScore,
			0 AS FinalAwayScore,
			0 AS hthomescore,
			0 AS htawayscore,
			b.IP,
			b.Username,
			0 AS IsNeutral,
			b.currency,
			'' AS ShowTime,
			'' AS betcheck,
			'' AS transdesc
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
		WHERE b.custid = @custid
			AND b.winlostdate = @FromDate
			AND (sbt.ProductID = 6 AND sbt.SubProduct = '')
			AND sbt.EventType = 0
			AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

		-- Keno
		IF @TransType = 1 OR @TransType = 2
			INSERT INTO @Data
			SELECT
				202 AS sporttype,
				0 AS leagueid,
				0 AS homeID,
				0 AS awayID,
				b.bettype,
				'' AS matchcode,
				'' AS race,
				t.gameid AS matchid,
				b.transid,
				b.transdate,
				b.winlostdate,
				b.refno,
				0 AS betid,
				0 AS oddsid,
				0 AS hdp1,
				0 AS hdp2,
				b.modds, 
				0 AS Oddstype,
				b.odds,
				t.choiceid AS betteam,
				b.status,
				0 AS betstatus,
				b.stake,
				b.actual_stake,
				(b.winlost-b.actual_stake) AS winlost,
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.discount,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				0 AS hthomescore,
				0 AS htawayscore,
				b.IP,
				b.Username,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime
				,'' AS betcheck
				,'' AS transdesc
			FROM 
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				OUTER APPLY dbo.[f_ParseTransDesc](b.TransDesc, b.bettype) t
			WHERE
				b.custid = @custid
				AND b.winlostdate = @FromDate
				AND sbt.ProductID = 8
				AND sbt.EventType = 0
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
		ELSE
			INSERT INTO @Data
			SELECT
				202 AS sporttype,
				0 AS leagueid,
				0 AS homeID,
				0 AS awayID,
				t.gameID AS bettype,
				'' AS matchcode,
				'' AS race,
				k.GameId AS matchid,
				t.translogid,
				t.transdate,
				t.winlostdate,
				t.translogid,
				0 AS betid,
				0 AS oddsid,
				0 AS hdp1,
				0 AS hdp2,
				0 AS modds,
				0 AS OddsType,
				t.odds,
				k.ChoiceId AS betteam,
				t.status,
				0 AS betstatus,
				t.stake,
				t.actual_stake,
				0 AS winlost,
				0 AS LicenseeWL,
				0 AS comm,
				0 AS playercomm,
				t.discount,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				0 AS hthomescore,
				0 AS htawayscore,
				t.IP,
				t.Username,
				CONVERT(BIT,0) AS IsNeutral,
				t.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM 
				dbo.translog AS t WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON t.gameID = sbt.bettype
				OUTER APPLY dbo.[f_ParseTransDesc](t.TransDesc, t.gameID) k
			WHERE
				t.custid = @custid
				AND t.winlostdate = @FromDate 
				AND sbt.ProductID = 8
				AND sbt.EventType = 0
				AND t.statusID IN (SELECT [statusID] FROM @tmpStatus)

		-- Virtual Horse Racing
		INSERT INTO @Data
		SELECT
			r.sporttype,
			r.leagueid,
			o.RacerID AS homeID,
			0 awayID,
			b.bettype,
			CONVERT(VARCHAR(50),o.RacerNum) AS matchcode,
			'' AS race,
			o.EventID AS matchid,
			b.transid,
			b.transdate,
			b.winlostdate,
			b.refno,
			b.betid,
			b.oddsid,
			b.hdp1,
			b.hdp2,
			modds,
			b.Oddstype,
			b.odds,
			b.betteam,
			b.status,
			r.betstatus,
			b.stake,
			b.actual_stake,
			(b.winlost-b.actual_stake) AS winlost,
			- (b.winlost-b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			0 AS FinalHomeScore,
			0 AS FinalAwayScore,
			0 AS hthomescore,
			0 AS htawayscore,
			b.IP,
			b.Username,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			CONVERT(VARCHAR(20),r.eventTime) AS ShowTime
			,'' AS betcheck
			,'' AS transdesc
		FROM 
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON b.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
		WHERE
			b.custid = @custid
			AND b.winlostdate = @FromDate 
			AND sbt.ProductId = 5 
			AND sbt.EventType = 3
			AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

		-- Mixed parlay & system parlay
		INSERT INTO @Data
		SELECT
			0,
			0,
			0,
			0,
			b.bettype,
			'',
			'',
			0,
			CASE
				WHEN (ISNULL(b.BetID,0) = 0 OR b.bettype = 9) THEN b.transid
				ELSE betid
			END AS transid,
			b.transdate,
			b.winlostdate,
			b.refno,
			0,
			0,
			b.hdp1,
			b.hdp2,
			b.modds,
			0 AS OddsType,
			b.odds,
			b.betteam,
			b.status,
			'' betstatus,
			b.stake,
			b.actual_stake,
			CASE
				WHEN b.statusID NOT IN (0,1) THEN (b.winlost-b.actual_stake)
				ELSE 0
			END AS winlost,
			CASE WHEN b.statusID NOT IN (0,1) THEN 
				CASE WHEN BA.transid IS NULL THEN - (b.winlost-b.actual_stake) ELSE 0 END
			ELSE 0 END	AS LicenseeWL,
			CASE WHEN b.statusID NOT IN (0,1) THEN b.comm ELSE 0 END AS comm,
			b.playercomm,
			b.discount,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			b.IP,
			b.Username,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			'' AS ShowTime,
			ISNULL(b.betcheck, '') AS BetCheck,
			'' AS transdesc
		FROM 
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
			LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction AS BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.custid = @custid
			AND b.winlostdate = @FromDate
			AND sbt.ProductID = 1
			AND sbt.EventType = 0
			AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

		-- Outright
		INSERT INTO @Data 
		SELECT
			l.sporttype,
			m.leagueID,
			m.teamID AS homeid,
			0 AS awayid,
			b.bettype,
			m.matchcode,
			m.groupmatch AS race,
			m.orid,
			b.transid,
			b.transdate,
			b.winlostdate,
			b.refno,
			0,
			10,
			b.hdp1,
			b.hdp2,
			b.modds,
			0 AS OddsType,
			b.odds,
			'',
			b.status,
			'',
			b.stake,
			b.actual_stake,
			CASE
				WHEN b.statusID NOT IN (0,1) THEN (b.winlost - b.actual_stake)
				ELSE 0
			END AS winlost,
			CASE WHEN b.statusID NOT IN (0,1) THEN 
				CASE
					WHEN ISNULL(BA.transid,0) = 0 AND b.bettype = 10 THEN - (b.winlost-b.actual_stake)
					WHEN b.bettype IN (31,32,33) THEN awinlost 
					ELSE 0
				END
			ELSE 0 END AS LicenseeWL,
			CASE WHEN b.statusID NOT IN (0,1) THEN b.comm  ELSE 0 END AS comm,
			b.playercomm  AS PlayerComm,
			b.discount,
			b.livehomescore, 
			b.liveawayscore, 
			0,
			0,
			0,
			0,
			0,
			b.IP,
			b.Username,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			'' AS ShowTime
			,'' AS betcheck
			,'' AS transdesc
		FROM 
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.outright AS m WITH (NOLOCK) on b.matchid = m.orid
			INNER JOIN dbo.league AS l WITH (NOLOCK) on m.leagueid = l.leagueid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
			LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction AS BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.custid = @custid
			AND b.winlostdate = @FromDate
			AND sbt.ProductID IN (1, 2)
			AND sbt.EventType = 2
			AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

		-- Microgaming Live Casino
		IF @TransType = 1 OR @TransType = 2
		BEGIN
			INSERT INTO @Data 
			SELECT
				203 AS sporttype,
				0 AS leagueid,
				0 AS homeID,
				0 AS awayID,
				b.bettype,
				'' AS matchcode,
				'' AS race,
				0 AS matchid,
				b.transid,
				b.transdate,
				b.winlostdate,
				b.refno,
				0 AS betid,
				0 AS oddsid,
				0 AS hdp1,
				0 AS hdp2,
				b.modds,
				0 AS Oddstype,
				0 AS odds,
				'' AS betteam,
				b.status,
				0 AS betstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS winlost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.discount,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				0 AS hthomescore,
				0 AS htawayscore,
				b.IP,
				b.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				b.betcheck
				,'' AS transdesc
			FROM 
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
			WHERE
				b.custid = @custid
				AND b.winlostdate = @FromDate 
				AND sbt.ProductID = 13
				AND sbt.EventType = 0
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
		END

		-- Microgaming Live Casino, Colossus Bets (translog)
		IF @TransType = 3
		BEGIN
			INSERT INTO @Data
			SELECT
				CASE
					WHEN sbt.ProductId = 13 THEN 203
					WHEN sbt.ProductId = 15 THEN 204
				END AS SportType,
				0 AS LeagueId,
				0 AS homeID,
				0 AS awayID,
				t.gameID AS BetType,
				'' AS matchcode,
				'' AS race,
				0 AS matchid,
				t.translogid AS TransId,
				t.transdate,
				t.winlostdate,
				t.translogid AS RefNo,
				0 AS betid,
				0 AS oddsid,
				0 AS hdp1,
				0 AS hdp2,
				0 AS modds,
				0 AS OddsType,
				0 AS odds,
				'' AS betteam,
				t.status,
				0 AS betstatus,
				t.stake,
				t.actual_stake,
				0 AS WinLost,
				0 AS LicenseeWL,
				0 AS Comm,
				0 AS PlayerComm,
				t.discount,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				0 AS LiveIndicator,
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				0 AS hthomescore,
				0 AS htawayscore,
				t.ip,
				t.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				t.currency,
				'' AS ShowTime,
				CASE
					WHEN sbt.ProductId = 15 THEN t.Tranid3rd
					ELSE ''
				END AS BetCheck,
				'' AS transdesc
			FROM 
				dbo.translog AS t WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON t.gameID = sbt.bettype
			WHERE
				t.custid = @custid
				AND t.winlostdate = @FromDate
				AND sbt.ProductID IN (13, 15)
				AND t.statusID IN (SELECT [statusID] FROM @tmpStatus)
		END

		-- Microgaming RNG Casino, RNG Casino Single Wallet, Macau Games, Fishing World
		IF @TransType = 1
		BEGIN
			IF @FromDate < @yesterday	-- not yesterday and today settled ticket
			BEGIN
				INSERT INTO @Data 
				SELECT
					CASE
						WHEN sbt.ProductID = 6 THEN b.matchid
						WHEN sbt.ProductID = 17 THEN 205
						WHEN sbt.ProductID = 22 THEN 212
						WHEN sbt.ProductID = 24 THEN 219
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeID,
					0 AS awayID,
					b.bettype,
					'' AS matchcode,
					'' AS race,
					0 AS matchid,
					b.transid,
					b.transdate,
					b.winlostdate,
					b.refno,
					0 AS betid,
					0 AS oddsid,
					0 AS hdp1,
					0 AS hdp2,
					0 AS modds,
					0 AS Oddstype,
					0 AS odds,
					'' AS betteam,
					b.status,
					0 AS betstatus,
					b.stake,
					b.actual_stake,
					(b.winlost - b.actual_stake) AS winlost,
					- (b.winlost - b.actual_stake) AS LicenseeWL,
					b.comm,
					b.playercomm,
					b.discount,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					0 AS hthomescore,
					0 AS htawayscore,
					b.IP,
					b.Username,
					CONVERT(BIT, 0) AS IsNeutral,
					b.currency,
					'' AS ShowTime,
					'' AS betcheck,
					CASE
						WHEN sbt.ProductID IN (6, 22, 24) THEN b.transdesc
						ELSE ''
					END AS transdesc
				FROM 
					dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				WHERE
					b.custid = @custid
					AND b.winlostdate = @FromDate 
					AND (sbt.ProductID IN (17, 22, 24)
						OR (sbt.ProductID = 6 AND sbt.SubProduct <> ''))
					AND sbt.EventType = 0
					AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
			END
			ELSE	-- yesterday and today settled ticket
			BEGIN
				INSERT INTO @Data 
				SELECT
					CASE
						WHEN sbt.ProductID = 6 THEN b.matchid
						WHEN sbt.ProductID = 17 THEN 205
						WHEN sbt.ProductID = 22 THEN 212
						WHEN sbt.ProductID = 24 THEN 219
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeID,
					0 AS awayID,
					b.bettype,
					'' AS matchcode,
					'' AS race,
					0 AS matchid,
					b.transid,
					b.transdate,
					b.winlostdate,
					b.refno,
					0 AS betid,
					0 AS oddsid,
					0 AS hdp1,
					0 AS hdp2,
					0 AS modds,
					0 AS Oddstype,
					0 AS odds,
					'' AS betteam,
					CASE 
						WHEN SUM(brng.winlost - brng.actual_stake) = 0 THEN 'Draw'
						WHEN SUM(brng.winlost - brng.actual_stake) > 0 THEN 'Won'
						WHEN SUM(brng.winlost - brng.actual_stake) < 0 THEN 'Lose'
					END AS Status,
					0 AS betstatus,
					SUM(brng.stake) AS Stake,
					SUM(brng.actual_stake) AS Actual_Stake,
					SUM(brng.winlost - brng.actual_stake) AS Winlost,
					SUM(- (brng.winlost - brng.actual_stake)) AS LicenseeWL,
					SUM(brng.comm) AS comm,
					SUM(brng.playercomm) AS playercomm,
					b.discount,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					0 AS hthomescore,
					0 AS htawayscore,
					b.IP,
					b.Username,
					CONVERT(BIT, 0) AS IsNeutral,
					b.currency,
					'' AS ShowTime,
					'' AS betcheck,
					CASE
						WHEN sbt.ProductID IN (6, 22, 24) THEN b.transdesc
						ELSE ''
					END AS transdesc
				FROM 
					dbo.bettransRnG AS brng WITH (NOLOCK)
					INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				WHERE
					b.custid = @custid
					AND b.winlostdate = @FromDate 
					AND (sbt.ProductID IN (17, 22, 24)
						OR (sbt.ProductID = 6 AND sbt.SubProduct <> ''))
					AND sbt.EventType = 0
					AND brng.statusID NOT IN (0, 1)
				GROUP BY
					b.Bettype,
					b.transid,
					b.transdate,
					b.winlostdate,
					b.refno,
					b.discount,
					b.IP,
					b.Username,
					b.currency,
					b.matchid,
					b.transdesc,
					sbt.ProductID
			END
		END
		ELSE IF @TransType = 3
		BEGIN
			IF @FromDate BETWEEN @yesterday AND @today		-- yesterday and today running ticket
			BEGIN
				INSERT INTO @Data 
				SELECT
					CASE
						WHEN sbt.ProductID = 6 THEN b.matchid
						WHEN sbt.ProductID = 17 THEN 205
						WHEN sbt.ProductID = 22 THEN 212
						WHEN sbt.ProductID = 24 THEN 219
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeID,
					0 AS awayID,
					b.bettype,
					'' AS matchcode,
					'' AS race,
					0 AS matchid,
					b.transid,
					b.transdate,
					b.winlostdate,
					b.refno,
					0 AS betid,
					0 AS oddsid,
					0 AS hdp1,
					0 AS hdp2,
					0 AS modds,
					0 AS Oddstype,
					0 AS odds,
					'' AS betteam,
					'Running' AS status,
					0 AS betstatus,
					SUM(brng.stake) AS Stake,
					SUM(brng.actual_stake) AS Actual_Stake,
					0 AS Winlost,
					0 AS LicenseeWL,
					0 AS comm,
					0 AS playercomm,
					0 AS discount,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					0 AS hthomescore,
					0 AS htawayscore,
					b.IP,
					b.Username,
					CONVERT(BIT, 0) AS IsNeutral,
					b.currency,
					'' AS ShowTime,
					'' AS betcheck,
					CASE
						WHEN sbt.ProductID IN (6, 22, 24) THEN b.transdesc
						ELSE ''
					END AS transdesc
				FROM 
					dbo.bettransRnG AS brng WITH (NOLOCK)
					INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				WHERE
					b.custid = @custid
					AND b.winlostdate = @FromDate 
					AND (sbt.ProductID IN (17, 22, 24)
						OR (sbt.ProductID = 6 AND sbt.SubProduct <> ''))
					AND sbt.EventType = 0
					AND brng.statusID IN (0, 1)
				GROUP BY
					b.Bettype,
					b.transid,
					b.transdate,
					b.winlostdate,
					b.refno,
					b.IP,
					b.Username,
					b.currency,
					b.matchid,
					b.transdesc,
					sbt.ProductID
			END
		END

		-- Colossus Bets
		IF @TransType IN (1, 2)
		BEGIN
			INSERT INTO @Data 
			SELECT
				204 AS SportType,
				0 AS LeagueId,
				0 AS HomeId,
				0 AS AwayId,
				b.bettype,
				'' AS MatchCode,
				'' AS Race,
				0 AS MatchId,
				b.transid,
				b.transdate,
				b.winlostdate,
				b.refno,
				0 AS BetId,
				0 AS OddsId,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS MOdds,
				0 AS OddsYype,
				0 AS Odds,
				'' AS BetTeam,
				b.status,
				'' AS BetStatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.discount,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				0 AS LiveIndicator,
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				0 AS HtHomeScore,
				0 AS HtAwayScore,
				b.ip,
				b.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				ISNULL(bm.betcheck, '') AS BetCheck,
				'' AS TransDesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				LEFT JOIN dbo.bettransm AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
			WHERE
				b.custid = @custid
				AND b.winlostdate = @FromDate 
				AND sbt.ProductID = 15
				AND sbt.EventType = 0
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
		END
		ELSE IF @TransType = 3
		BEGIN
			INSERT INTO @Data 
			SELECT
				204 AS SportType,
				0 AS LeagueId,
				0 AS HomeId,
				0 AS AwayId,
				b.bettype,
				'' AS MatchCode,
				'' AS Race,
				0 AS MatchId,
				b.transid,
				b.transdate,
				b.winlostdate,
				b.refno,
				0 AS BetId,
				0 AS OddsId,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS MOdds,
				0 AS OddsYype,
				0 AS Odds,
				'' AS BetTeam,
				b.status,
				'' AS BetStatus,
				b.stake,
				b.actual_stake,
				0 AS WinLost,
				0 AS LicenseeWL,
				0 AS comm,
				0 AS playercomm,
				b.discount,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				0 AS LiveIndicator,
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				0 AS HtHomeScore,
				0 AS HtAwayScore,
				b.ip,
				b.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				ISNULL(bm.betcheck, '') AS BetCheck,
				'' AS TransDesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				LEFT JOIN dbo.bettransm AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
			WHERE
				b.custid = @custid
				AND b.winlostdate = @FromDate 
				AND sbt.ProductID = 15
				AND sbt.EventType = 0
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
		END
		
		-- Grand Prize Jackpot Win
		IF @TransType = 4
		BEGIN
			-- Microgaming RNG Casino
			INSERT INTO @Data 
			SELECT
				205 AS sporttype,
				0 AS leagueid,
				0 AS homeID,
				0 AS awayID,
				b.gameID AS BetType,
				'' AS matchcode,
				'' AS race,
				0 AS matchid,
				b.transid,
				pt.transdate,
				pt.winlostdate,
				b.refno,
				0 AS betid,
				0 AS oddsid,
				0 AS hdp1,
				0 AS hdp2,
				0 AS modds,
				0 AS Oddstype,
				0 AS odds,
				'' AS betteam,
				b.status,
				'' AS betstatus,
				b.stake,
				b.actual_stake,
				pt.WinAmount AS WinLost,
				0 AS LicenseeWL,
				0 AS comm,
				0 AS playercomm,
				0 AS discount,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				0 AS hthomescore,
				0 AS htawayscore,
				b.ip,
				b.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				b.TranId3rd AS BetCheck,
				b.transdesc
			FROM
				DBACC.bodb02.dbo.PayoutTrans AS pt WITH (NOLOCK)
				INNER JOIN dbo.bettransRnG AS b WITH (NOLOCK) ON pt.RefNo = b.transid
				INNER JOIN @SportBettype AS sbt ON b.gameID = sbt.bettype
			WHERE
				pt.custid = @custid
				AND pt.winlostdate = @FromDate 
				AND sbt.ProductID = 17
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

			-- Colossus Bets
			INSERT INTO @Data
			SELECT
				204 AS SportType,
				0 AS LeagueId,
				0 AS HomeId,
				0 AS AwayId,
				b.bettype,
				'' AS MatchCode,
				'' AS Race,
				0 AS MatchId,
				b.transid,
				b.transdate,
				b.winlostdate,
				b.refno,
				0 AS BetId,
				0 AS OddsId,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS MOdds,
				0 AS OddsType,
				0 AS Odds,
				'' AS BetTeam,
				b.status,
				'' AS BetStatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.discount,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				0 AS LiveIndicator,
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				0 AS HtHomeScore,
				0 AS HtAwayScore,
				b.ip,
				b.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				ISNULL(bm.betcheck, '') AS BetCheck,
				b.transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				LEFT JOIN dbo.bettransm AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
			WHERE
				b.custid = @custid
				AND b.winlostdate = @FromDate 
				AND sbt.ProductID = 15
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
				AND EXISTS (	SELECT 1 
								FROM DBACC.bodb02.dbo.PayoutTrans AS pt WITH (NOLOCK)
								WHERE pt.refno = b.transid AND pt.PayoutStatus IN ('Completed', 'Expired'))
		END

		-- AG Casino, AllBet
		IF @TransType = 1
		BEGIN
			IF @FromDate < @yesterday	-- not yesterday and today settled ticket
			BEGIN
				INSERT INTO @Data 
				SELECT
					CASE
						WHEN sbt.ProductID = 11 THEN 250
						WHEN sbt.ProductID = 21 THEN 211
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeID,
					0 AS awayID,
					b.bettype,
					'' AS matchcode,
					'' AS race,
					0 AS matchid,
					b.transid,
					b.transdate,
					b.winlostdate,
					b.refno,
					0 AS betid,
					0 AS oddsid,
					0 AS hdp1,
					0 AS hdp2,
					0 AS modds,
					0 AS Oddstype,
					0 AS odds,
					'' AS betteam,
					b.status,
					0 AS betstatus,
					b.stake,
					b.actual_stake,
					(b.winlost - b.actual_stake) AS winlost,
					- (b.winlost - b.actual_stake) AS LicenseeWL,
					b.comm,
					b.playercomm,
					b.discount,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					0 AS hthomescore,
					0 AS htawayscore,
					b.IP,
					b.Username,
					CONVERT(BIT, 0) AS IsNeutral,
					b.currency,
					'' AS ShowTime,
					'' AS betcheck
					,'' AS transdesc
				FROM 
					dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				WHERE
					b.custid = @custid
					AND b.winlostdate = @FromDate 
					AND sbt.ProductID IN (11, 21)
					AND sbt.EventType = 0
					AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
			END
			ELSE	-- yesterday and today settled ticket
			BEGIN
				INSERT INTO @Data 
				SELECT
					CASE
						WHEN sbt.ProductID = 11 THEN 250
						WHEN sbt.ProductID = 21 THEN 211
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeID,
					0 AS awayID,
					b.bettype,
					'' AS matchcode,
					'' AS race,
					0 AS matchid,
					b.transid,
					b.transdate,
					b.winlostdate,
					b.refno,
					0 AS betid,
					0 AS oddsid,
					0 AS hdp1,
					0 AS hdp2,
					0 AS modds,
					0 AS Oddstype,
					0 AS odds,
					'' AS betteam,
					CASE 
						WHEN SUM(blc.winlost - blc.actual_stake) = 0 THEN 'Draw'
						WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
						WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
					END AS Status,
					0 AS betstatus,
					SUM(blc.stake) AS Stake,
					SUM(blc.actual_stake) AS Actual_Stake,
					SUM(blc.winlost - blc.actual_stake) AS Winlost,
					SUM(- (blc.winlost - blc.actual_stake)) AS LicenseeWL,
					SUM(blc.comm) AS comm,
					SUM(blc.playercomm) AS playercomm,
					b.discount,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					0 AS hthomescore,
					0 AS htawayscore,
					b.IP,
					b.Username,
					CONVERT(BIT, 0) AS IsNeutral,
					b.currency,
					'' AS ShowTime,
					'' AS betcheck,
					'' AS transdesc
				FROM 
					dbo.bettransLC AS blc WITH (NOLOCK)
					INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				WHERE
					b.custid = @custid
					AND b.winlostdate = @FromDate 
					AND sbt.ProductID IN (11, 21)
					AND sbt.EventType = 0
					AND blc.statusID NOT IN (0, 1)
				GROUP BY
					b.Bettype,
					b.transid,
					b.transdate,
					b.winlostdate,
					b.refno,
					b.discount,
					b.IP,
					b.Username,
					b.currency,
					sbt.ProductID
			END
		END
		ELSE IF @TransType = 3
		BEGIN
			IF @FromDate BETWEEN @yesterday AND @today		-- yesterday and today running ticket
			BEGIN
				INSERT INTO @Data 
				SELECT
					CASE
						WHEN sbt.ProductID = 11 THEN 250
						WHEN sbt.ProductID = 21 THEN 211
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeID,
					0 AS awayID,
					b.bettype,
					'' AS matchcode,
					'' AS race,
					0 AS matchid,
					b.transid,
					b.transdate,
					b.winlostdate,
					b.refno,
					0 AS betid,
					0 AS oddsid,
					0 AS hdp1,
					0 AS hdp2,
					0 AS modds,
					0 AS Oddstype,
					0 AS odds,
					'' AS betteam,
					'Running' AS status,
					0 AS betstatus,
					SUM(blc.stake) AS Stake,
					SUM(blc.actual_stake) AS Actual_Stake,
					0 AS Winlost,
					0 AS LicenseeWL,
					0 AS comm,
					0 AS playercomm,
					0 AS discount,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					0 AS hthomescore,
					0 AS htawayscore,
					b.IP,
					b.Username,
					CONVERT(BIT, 0) AS IsNeutral,
					b.currency,
					'' AS ShowTime,
					'' AS betcheck
					,'' AS transdesc
				FROM 
					dbo.bettransLC AS blc WITH (NOLOCK)
					INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				WHERE
					b.custid = @custid
					AND b.winlostdate = @FromDate 
					AND sbt.ProductID IN (11, 21)
					AND sbt.EventType = 0
					AND blc.statusID IN (0, 1)
				GROUP BY
					b.Bettype,
					b.transid,
					b.transdate,
					b.winlostdate,
					b.refno,
					b.IP,
					b.Username,
					b.currency,
					sbt.ProductID
			END
		END

		-- For BetTrade
		UPDATE betList
		SET betList.Odds	= originBetList.Odds
			,betList.Stake	= originBetList.Stake
			,betList.comm	= CASE WHEN betList.Bettype = 902 THEN commBetList.comm ELSE betList.comm END
			,betList.BetID	= originBetList.Bettype
		FROM @Data AS betList
			INNER JOIN dbo.bettrans AS originBetList WITH (NOLOCK) ON betList.RefNo = originBetList.transid
			LEFT JOIN @Data AS commBetList ON betList.RefNo = commBetList.RefNo AND commBetList.Bettype = 903
		WHERE betList.Sporttype = 1 AND betList.BetType IN (901, 902)

		DELETE @Data WHERE Sporttype = 1 AND Bettype = 903
		-- End Bet Trade
	END

	DELETE @Data
	WHERE Currency NOT IN (SELECT DISTINCT Currency FROM @TempAg)

	SELECT *
	INTO #TempExchange
	FROM Lrf_f_GetExchangeDaily(@FromDate, @Today)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM @Data)

	SELECT
		@TotalRows 			= COUNT(b.TransId),
		@SumWinlost			= SUM(ISNULL(b.WinLost, 0)),
		@SumLicenseeWL		= SUM(ISNULL(b.LicenseeWL, 0)),
		@SumComm			= SUM(ISNULL(b.Comm, 0)),
		@SumPlayerComm		= SUM(ISNULL(b.PlayerComm, 0)),
		-- USD
		@SumWinlostUSD		= SUM(ISNULL(b.WinLost		* e.USD, 0)),
		@SumLicenseeWLUSD	= SUM(ISNULL(b.LicenseeWL	* e.USD, 0)),
		@SumCommUSD			= SUM(ISNULL(b.Comm			* e.USD, 0)),
		@SumPlayerCommUSD	= SUM(ISNULL(playercomm		* e.USD, 0)),
		-- EUR
		@SumWinlostEUR		= SUM(ISNULL(b.WinLost		* e.EUR, 0)),
		@SumLicenseeWLEUR	= SUM(ISNULL(b.LicenseeWL	* e.EUR, 0)),
		@SumCommEUR			= SUM(ISNULL(b.Comm			* e.EUR, 0)),
		@SumPlayerCommEUR	= SUM(ISNULL(b.PlayerComm	* e.EUR, 0)),
		-- GBP
		@SumWinlostGBP		= SUM(ISNULL(b.WinLost		* e.GBP, 0)),
		@SumLicenseeWLGBP	= SUM(ISNULL(b.LicenseeWL	* e.GBP, 0)),
		@SumCommGBP			= SUM(ISNULL(b.Comm			* e.GBP, 0)),
		@SumPlayerCommGBP	= SUM(ISNULL(b.PlayerComm	* e.GBP, 0))
	FROM @Data AS b
		INNER JOIN #TempExchange AS e
			ON e.ExchangeDate = (CASE WHEN b.winlostdate > @Today THEN @Today ELSE b.winlostdate END)
				AND e.exchangeid = b.currency

	SELECT A.*
	FROM
	(
		SELECT
			ROW_NUMBER() OVER(ORDER BY b.TransId, b.RefNo) AS RowNum,
			b.*,
			-- USD
			b.Stake			* e.USD AS StakeUSD,
			b.Actual_Stake	* e.USD AS Actual_StakeUSD,
			b.WinLost		* e.USD AS WinLostUSD,
			b.LicenseeWL	* e.USD AS LicenseeWLUSD,
			b.Comm			* e.USD AS CommUSD,
			b.PlayerComm	* e.USD AS PlayerCommUSD,
			-- EUR
			b.Stake			* e.EUR AS StakeEUR,
			b.Actual_Stake	* e.EUR AS Actual_StakeEUR,
			b.WinLost		* e.EUR AS WinLostEUR,
			b.LicenseeWL	* e.EUR AS LicenseeWLEUR,
			b.Comm			* e.EUR AS CommEUR,
			b.PlayerComm	* e.EUR AS PlayerCommEUR,
			-- GBP
			b.Stake			* e.GBP AS StakeGBP,
			b.Actual_Stake	* e.GBP AS Actual_StakeGBP,
			b.WinLost		* e.GBP AS WinLostGBP,
			b.LicenseeWL	* e.GBP AS LicenseeWLGBP,
			b.Comm			* e.GBP AS CommGBP,
			b.PlayerComm	* e.GBP AS PlayerCommGBP
		FROM @Data AS b
			INNER JOIN #TempExchange AS e
				ON e.ExchangeDate = (CASE WHEN b.winlostdate > @Today THEN @Today ELSE b.winlostdate END)
					AND e.exchangeid = b.currency
	) AS A
	WHERE A.RowNum BETWEEN (((@PageIndex - 1) * @PageSize) + 1) AND (@PageSize * @PageIndex)

	DECLARE @BettransDetail TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(10),
		StakeEUR		MONEY,
		StakeUSD		MONEY,
		StakeGBP		MONEY
	);

	IF @FromDate <= @MoveBetsDay
	BEGIN
		-- Horse Racing
		INSERT INTO @BettransDetail 
		SELECT
			bm.refno,
			bm.odds,
			bm.stake,
			bm.status,
			bm.apositiontaking,
			bm.bettype,
			bm.betteam,
			bm.stake * e.EUR,
			bm.stake * e.USD,
			bm.stake * e.GBP
		FROM dbo.bettransm14 AS bm WITH (NOLOCK)
			INNER JOIN @Data AS b ON bm.refno = b.TransId
			INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.currency
			INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.bettype
			INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
		WHERE bm.custid = @CustId
			AND sbt.ProductID = 2
			AND sbtm.ProductID = 2

		-- Live Casino
		UNION ALL
		SELECT
			bg.refno,
			bg.odds,
			bg.stake,
			bg.status,
			bg.apositiontaking,
			bg.bettype,
			bg.Betteam,
			bg.stake * e.EUR,
			bg.stake * e.USD,
			bg.stake * e.GBP
		FROM dbo.bettransg14 AS bg WITH (NOLOCK)
			INNER JOIN @Data AS b ON bg.refno = b.RefNo
			INNER JOIN #TempExchange AS e ON  e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.currency
			INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.bettype
			INNER JOIN @SportBettype AS sbtg ON bg.bettype = sbtg.Bettype
		WHERE bg.custid = @CustId
			AND sbt.ProductID = 4
			AND sbtg.ProductID = 4

		-- Virtual Sports
		UNION ALL
		SELECT
			bm.refno,
			bm.odds,
			bm.stake,
			bm.status,
			bm.apositiontaking,
			bm.bettype,
			bm.betteam,
			bm.stake * e.EUR,
			bm.stake * e.USD,
			bm.stake * e.GBP
		FROM dbo.bettransm14 AS bm WITH (NOLOCK, INDEX=IX_bettransm14)
			INNER JOIN @Data AS b ON bm.refno = b.RefNo
			INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.Currency
			INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.bettype
			INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
		WHERE bm.custid = @CustId
			AND sbt.ProductID = 5
			AND sbt.EventType = 3
			AND sbtm.ProductID = 5
			AND sbtm.EventType = 3
	END
	ELSE
	BEGIN
		-- Horse Racing
		INSERT INTO @BettransDetail
		SELECT
			bm.refno,
			bm.odds,
			bm.stake,
			bm.status,
			bm.apositiontaking,
			bm.bettype,
			bm.betteam,
			bm.stake * e.EUR,
			bm.stake * e.USD,
			bm.stake * e.GBP
		FROM dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN @Data AS b ON bm.refno = b.TransId
			INNER JOIN #TempExchange AS e ON  e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.currency
			INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.bettype
			INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
		WHERE  bm.custid = @CustId
			AND sbt.ProductID = 2
			AND sbtm.ProductID = 2

		-- Live Casino
		UNION ALL
		SELECT
			bg.refno,
			bg.odds,
			bg.stake,
			bg.status,
			bg.apositiontaking,
			bg.bettype,
			bg.betteam,
			bg.stake * e.EUR,
			bg.stake * e.USD,
			bg.stake * e.GBP
		FROM dbo.bettransg AS bg WITH (NOLOCK)
			INNER JOIN @Data AS b ON bg.refno = b.RefNo
			INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.currency
			INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.bettype
			INNER JOIN @SportBettype AS sbtg ON bg.bettype = sbtg.Bettype
		WHERE bg.custid = @CustId
			AND sbt.ProductID = 4
			AND sbtg.ProductID = 4

		-- Virtual Sports
		UNION ALL
		SELECT
			bm.refno,
			bm.odds,
			bm.Stake,
			bm.status,
			bm.apositiontaking,
			bm.bettype,
			bm.Betteam,
			bm.stake * e.EUR,
			bm.stake * e.USD,
			bm.stake * e.GBP
		FROM dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN @Data AS b ON bm.refno = b.RefNo
			INNER JOIN #TempExchange AS e ON  e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.currency
			INNER JOIN @SportBettype sbt ON b.BetType = sbt.bettype
			INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
		WHERE bm.custid = @CustId
			AND sbt.ProductID = 5
			AND sbt.EventType = 3
			AND sbtm.ProductID = 5
			AND sbtm.EventType = 3
	END

	SELECT DISTINCT * FROM @BettransDetail
	ORDER BY RefNo, BetType

	DROP TABLE #TempExchange
END



GO 

GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelByDayAll_Mem] TO [vnteam]
GO 

GRANT EXECUTE ON [dbo].[Lrf_BetList_SelByDayAll_Mem] TO [bodbLicenseeNet]
GO 
