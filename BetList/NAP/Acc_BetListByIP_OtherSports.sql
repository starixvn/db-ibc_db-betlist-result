USE bodb02
GO

ALTER PROCEDURE [dbo].[Acc_BetListByIP_OtherSports]
	@CustId		INT,
	@Ip			VARCHAR(15),
	@FromDate	DATETIME
AS

/*
	Created: Phuong Dao
	Task : Bet List By IP and Other Sports
	DB: DBACC.bodb02
	Original: Acc_BetListByDayAllIP
	Revisions:
		- 20090509@Simon: Bet List For Casino
		- 20090528@PhuongDao: Add HR Fixed Odd 
		- 20091002@Simon: Get Odds && OddsType columns.
		- 20091003@Jamie: Remove comstatus out 
		- 20091009@Daniel: Get refund status from bettrans
		- 20091015@Shifu: Get refno
		- 20091023@Simon: Displays Odds at Bet/Settle time
		- 20091205@Henry: Get more column: refno for viewing Mix Parlay detail
		- 20100524@Jamie: Show currency2's exchange rate for OpenTote 
		- 20100611@Henry: Change mix-parlay match from 0 to 9
		- 20100907@Henry: Add IBC Bingo bettype
		- 20101130@Henry: Add column betid for number game
		- 20101201@Henry: Return winlost-actual_stake for column winlost
		- 20110408@Amy: Change function to get Odds value and odds type
		- 20110516@Lukas: re-arrange bettype
		- 20110711@Johnson: show exchange rate for SA Tote
		- 20110802@Johnson: - Add new bettype combination mix-parlay
							- Add new column actual_stake into betlist
		- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
		- 20111207@Sophia: Add P2P
		- 20120120@Sophia: Add Showtime for Table-hand-shoe of Live Casino
						   Add sub detail for Live Casino
		- 20120321@Sophia: Select @Data table (fix bug) 
		- 20120405@Hurri: Exclude bettype 72 (P2P bet ticket) in the calculation of Casino
		- 20120410@Hurri: change matchid 0 -> 1000 for bettype 1000
		- 20120417@Johnson: Correct column transid for p2p	
		- 20120423@Lukas: show transid of main ticket for all subticket of system parlay
		- 20120606@Sophia: Change datatype of stake to money
		- 20120626@Elodie: exclude outright, HR from sportbook ( in case of matchid = orid)
		- 20120629@Sophia: Remove function f_GetOddsByBettype, f_ShowOddsByBettype for odds, Oddstype
		- 20120927@Johnson: get commstatus column to check double comm losing
		- 20121029@Elodie: Get matchid column
		- 20130227@Elodie: Add Virtual HR product
		- 20130625@Elodie: Not apply Virtual HR for bet list by IP yet at this time	
		- 20130703@Kathy: Update matchid for RnG Casino(71) and Bingo(73)
		- 20130718@Elodie: Apply core betlist
		- 20131126@Lukas: get sporttype column in VSRaceinfo instead of hardcode
		- 20140306@Dom: Add Keno
		- 20140908@Dom:	[Redmine #22012] Update VS conditions
		- 20141103@Dom: Apply sport bettype matrix
		- 20150506@Tom: Support Gold Deluxe Product [#34847]
		- 20150506@Bobby: Add transdesc column for metric gaming bettypes (801-899)
		- 20150709@Edward: Supporting for Microgaming
		- 20150826@Kos: Add OddsSpread column to support Myanmar Odds
		- 20150831@Kos: Support Colossus Bet
		- 20151009@Kos: Support Microgaming RNG Casino and AG casino
		- 20151023@Kos: Return [translog].[transid3rd] and [bettransm].[betcheck] to support view CB ticket detail
		- 20151030@Kos: Change ProductId/SportType of Microgaming RNG Casino
		- 20151210@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20151216@Kos: Support Cockfighting (#Redmine: 48850)
		- 20151231@Kos: Support RNG Casino Single Wallet [Redmine: #48958]
		- 20160121@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160125@Kos: Fix Colossus Bet result issue
		- 20160129@Kos: Support RNG Casino Single Wallet yesterday running ticket
		- 20160215@Kos: Support AllBet [#Redmine: 50864]
		- 20160331@Kos: Support Voidbridge [#Redmine: 54925]
		- 20160407@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20160711@Kos: Change to use inline function for SportBettypeMatrix
		- 20160801@Kos: Fix bug not showing summary tickets if have only Void/Reject detail tickets [#Redmine: 61651]
		- 20160810@Kos: Support NG2

	Param's Explanation:
		• @fromdate = @winlostdate
*/

BEGIN
	SET NOCOUNT ON

	----Get Sport Bettype Matrix------
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM bodb02.dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)

	DECLARE @Data TABLE (
		finalhomescore	INT,
		finalawayscore	INT,
		oddsid			INT,
		leagueid		INT,
		bettype			SMALLINT,
		transid			BIGINT,
		betid			BIGINT, 
		refno			BIGINT,
		matchid			INT,
		matchcode		NVARCHAR(50),
		race			NVARCHAR(50),
		eventdate		DATETIME,
		virtualrate		FLOAT, --in case OpenTote, it's currency2's exRate 
		isShowOTExRate	BIT, --show OpenTote ExRate or not 
		sdiscount		DECIMAL(9, 8),
		adiscount		DECIMAL(9, 8),
		discount		DECIMAL(9, 8),
		homeid			INT,
		awayid			INT,
		settleTime		DATETIME,
		hdp1			SMALLMONEY,
		hdp2			SMALLMONEY,
		odds			MONEY,
		modds			MONEY,
		finalodds		MONEY,
		finalodds2		MONEY,
		OddsType		INT, 
		status			NVARCHAR(50),
		comstatus		NVARCHAR(20),
		stake			MONEY,
		actual_stake	MONEY,
		transdate		DATETIME,
		betteam			NVARCHAR (50),
		spositiontaking SMALLMONEY,
		mpositiontaking SMALLMONEY,
		apositiontaking SMALLMONEY,
		spositiontaking2 SMALLMONEY,
		mpositiontaking2 SMALLMONEY,
		apositiontaking2 SMALLMONEY,
		livehomescore	INT,
		liveawayscore	INT,
		liveindicator	BIT,
		winlost			MONEY,
		commission		MONEY,
		scomm			MONEY,
		acomm			MONEY,
		comm			MONEY,
		awinlost		MONEY,
		mwinlost		MONEY,
		swinlost		MONEY,
		creator			VARCHAR(50),
		username		NVARCHAR(50),
		hthomescore		INT,
		htawayscore		INT,
		ip				NVARCHAR(15),
		betfrom			NVARCHAR(1),
		sporttype		INT,
		IsNeutral		BIT,
		showtime		NVARCHAR(50),
		winlostdate		SMALLDATETIME,
		BetCheck		NVARCHAR(50),
		transdesc		NVARCHAR(1000),
		OddsSpread		SMALLMONEY
	)

	DECLARE @DetailData TABLE (
		refno			NVARCHAR(50),
		odds			MONEY,
		stake			MONEY,
		status			NVARCHAR(50),
		apositiontaking SMALLMONEY,
		mpositiontaking SMALLMONEY,
		spositiontaking SMALLMONEY,
		bettype			SMALLINT,
		betteam			NVARCHAR(50),
		TransDesc		VARCHAR(300)
	)

	INSERT INTO @Data
	SELECT
		finalhomescore,
		finalawayscore,
		oddsid,
		leagueid,
		bettype,
		transid,
		betid,
		refno,
		matchid,
		matchcode,
		race,
		eventdate,
		virtualrate,
		isShowOTExRate,
		sdiscount,
		adiscount,
		discount,
		homeid,
		awayid,
		checktime settleTime,
		hdp1,
		hdp2,
		odds,
		modds,
		finalodds,
		finalodds2,
		OddsType,
		status,
		comstatus,
		stake,
		actual_stake,
		transdate,
		betteam,
		0 spositiontaking, -- unuse in this report
		0 mpositiontaking, -- unuse in this report
		0 apositiontaking, -- unuse in this report
		0 spositiontaking2,-- unuse in this report
		0 mpositiontaking2,-- unuse in this report
		0 apositiontaking2,-- unuse in this report
		livehomescore,
		liveawayscore,
		liveindicator,
		winlost,
		commission,
		0 scomm, -- unuse in this report
		0 acomm, -- unuse in this report
		0 comm,	-- unuse in this report
		awinlost,
		mwinlost,
		swinlost,
		creator,
		username,
		hthomescore,
		htawayscore,
		ip,
		betfrom,
		sporttype,
		IsNeutral,
		showtime,
		winlostdate,
		BetCheck,
		transdesc,
		OddsSpread
	FROM (
			SELECT
				match.finalhomescore,
				match.finalawayscore,
				b.oddsid,
				match.leagueid,
				b.bettype,
				b.transid,
				ISNULL(b.BetID, 0) AS BetID,
				b.refno,
				match.matchcode,
				'' AS race, 
				'' AS eventdate, 
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				match.homeid,
				match.awayid,
				ISNULL(b.checktime,'') checktime,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				0 finalodds,
				0 finalodds2,
				b.oddstype,
				b.status,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.betteam,
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator,
				(b.winlost-b.actual_stake)  winlost,
				b.playercomm AS commission,
				creator.username creator,
				b.username,
				match.hthomescore,
				match.htawayscore,
				ip,
				match.sporttype,
				b.matchid,
				match.IsNeutral,
				match.showtime,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.betfrom,
				b.winlostdate,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc,
				ISNULL(b.oddsspread, 0) AS OddsSpread
			FROM dbo.bettrans14 b WITH (NOLOCK) 
				INNER JOIN dbo.match14 match WITH (NOLOCK) ON b.matchid = match.matchid
				INNER JOIN dbo.custInfo creator WITH (NOLOCK) ON creator.custid = b.creator
				INNER JOIN dbo.league l WITH (NOLOCK) ON match.leagueid = l.leagueid 
				INNER JOIN dbo.sports s WITH (NOLOCK) ON l.sporttype = s.sporttype 
				INNER JOIN @SportBettype sp ON sp.Bettype = b.bettype
			WHERE b.winlostdate = @fromdate
				AND sp.eventtype = 1
				AND b.custid = @custid
				AND s.sporttype <> 1

			UNION ALL 
			SELECT 
				0 finalhomescore,
				0 finalawayscore,
				0,
				0 leagueid,
				9 bettype,
				b.transid,
				ISNULL(b.BetID,0) AS BetID,
				b.refno,
				'' matchcode,
				'' race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				0 homeid, 
				0 awayid,
				ISNULL(b.checktime,'') checktime,
				0 hdp1,
				0 hdp2,
				b.odds,
				b.modds,
				0 finalodds,
				0 finalodds2,
				' ' OddsType, 
				b.status,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.betteam,
				0 livehomescore, 
				0 liveawayscore,
				0 liveindicator,
				(b.winlost-b.actual_stake)  winlost,
				b.playercomm AS commission,
				creator.username creator,
				b.username,
				0 hthomescore,
				0 htawayscore,
				ip,
				0 sporttype,
				0 matchid,
				0 IsNeutral,
				'' AS showtime,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.betfrom,
				b.winlostdate,
				b.betcheck,
				'' AS transdesc,
				0 AS OddsSpread
			FROM dbo.bettrans14 b  WITH (NOLOCK) 
				INNER JOIN dbo.custInfo creator  WITH (NOLOCK) ON creator.custid = b.creator
			WHERE b.bettype = 9 
				AND b.winlostdate = @fromdate 
				AND b.matchid = 9
				AND b.custid = @custid 
				AND b.refno IN (SELECT RefNo 
								FROM dbo.bettransm14 b WITH (NOLOCK)
									INNER JOIN dbo.match14 m WITH (NOLOCK) ON b.matchid = m.MatchID
								WHERE m.sporttype <> 1)
				AND b.refno NOT IN (SELECT RefNo 
									FROM dbo.bettransm14 b WITH (NOLOCK)
										INNER JOIN dbo.match14 m WITH (NOLOCK) ON b.matchid = m.MatchID
									WHERE m.sporttype = 1)
			UNION ALL 
			SELECT 
				0 finalhomescore,
				0 finalawayscore,
				0,
				0 leagueid,
				29 bettype,
				CASE WHEN ISNULL(b.betID, 0) = 0 THEN b.transid ELSE b.betID END AS transid,
				ISNULL(b.BetID, 0) AS BetID,
				b.refno,
				'' matchcode,
				'' race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				0 homeid, 
				0 awayid,
				ISNULL(b.checktime,'') checktime,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				0 finalodds,
				0 finalodds2,
				' ' OddsType, 
				b.status,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.betteam,
				0 livehomescore, 
				0 liveawayscore,
				0 liveindicator,
				(b.winlost-b.actual_stake)  winlost,
				b.playercomm AS commission, 
				creator.username creator,
				b.username,
				0 hthomescore,
				0 htawayscore,
				ip,
				0 sporttype,
				0 matchid,
				0 IsNeutral,
				'' AS showtime,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.betfrom,
				b.winlostdate,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS transdesc,
				0 AS OddsSpread
			FROM dbo.bettrans14 b WITH (NOLOCK) 
				INNER JOIN dbo.custInfo creator WITH (NOLOCK) ON creator.custid = b.creator
			WHERE	b.bettype = 29 
				AND b.winlostdate = @fromdate
				AND b.matchid = 29
				AND b.custid = @custid 
				AND b.refno IN (SELECT RefNo
								FROM dbo.bettransm14 b WITH (NOLOCK)
									INNER JOIN dbo.match14 m WITH (NOLOCK) ON b.matchid = m.MatchID
								WHERE m.sporttype <> 1)
				AND b.refno NOT IN (SELECT RefNo
									FROM dbo.bettransm14 b WITH (NOLOCK)
										INNER JOIN dbo.match14 m WITH (NOLOCK) ON b.matchid = m.MatchID
									WHERE m.sporttype = 1)
			UNION ALL
			SELECT 
				match.finalhomescore,
				match.finalawayscore,
				b.oddsid,
				match.leagueid,
				b.bettype,
				b.transid,
				ISNULL(b.BetID, 0) AS BetID,
				b.refno,
				match.matchcode,
				'' race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				match.homeid,
				match.awayid,
				ISNULL(b.checktime,'') checktime,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				0 finalodds,
				0 finalodds2,
				b.oddstype,
				CASE 
					WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.status 
				END AS status,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.betteam,
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator,
				(b.winlost-b.actual_stake)  winlost,
				b.playercomm AS commission, 
				creator.username creator,
				b.username,
				match.hthomescore,
				match.htawayscore,
				ip,
				match.sporttype,
				b.matchid,
				match.IsNeutral,
				match.showtime,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.betfrom,
				b.winlostdate,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc,
				ISNULL(b.oddsspread, 0) AS OddsSpread
			FROM dbo.bettrans b WITH (NOLOCK) 
				INNER JOIN dbo.match WITH (NOLOCK) ON b.matchid = match.matchid
				INNER JOIN dbo.custInfo creator WITH (NOLOCK) ON creator.custid = b.creator
				INNER JOIN dbo.league l WITH (NOLOCK) ON match.leagueid = l.leagueid
				INNER JOIN dbo.sports s WITH (NOLOCK) ON l.sporttype = s.sporttype
				INNER JOIN @SportBettype sp ON sp.Bettype = b.bettype
			WHERE	b.winlostdate = @fromdate
				AND sp.eventtype = 1 
				AND b.bettype <> 10
				AND s.sporttype <> 1
				AND b.custid = @custid
		
			UNION ALL
			SELECT
				0 finalhomescore,
				0 finalawayscore,
				0,
				0 leagueid,
				9 bettype,
				b.transid,
				ISNULL(b.BetID, 0) AS BetID,
				b.refno,
				'' matchcode,
				'' race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				0 homeid,
				0 awayid,
				ISNULL(b.checktime, '') checktime,
				0 hdp1,
				0 hdp2,
				b.odds,
				b.modds,
				0 finalodds,
				0 finalodds2,
				' ' OddsType,
				b.status,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.betteam,
				0 livehomescore, 
				0 liveawayscore,
				0 liveindicator,
				(b.winlost-b.actual_stake)  winlost,
				b.playercomm AS commission, 
				creator.username creator,
				b.username,
				0 hthomescore,
				0 htawayscore,
				ip,
				0 sporttype,
				b.matchid,
				0 IsNeutral,
				'' AS showtime,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.betfrom,
				b.winlostdate,
				b.betcheck,
				'' AS transdesc,
				0 AS OddsSpread
			FROM bettrans b WITH (NOLOCK) 
				INNER JOIN custInfo creator  WITH (NOLOCK) ON creator.custid = b.creator
			WHERE	b.winlostdate = @fromdate 
				AND b.matchid = 9
				AND b.bettype = 9
				AND b.custid = @custid
				AND b.refno IN (SELECT RefNo 
								FROM bettransm b WITH (NOLOCK)
									INNER JOIN match m WITH (NOLOCK) ON b.matchid = m.matchid
								WHERE m.sporttype <> 1 )
				AND b.refno NOT IN (SELECT RefNo 
									FROM bettransm b WITH (NOLOCK)
										INNER JOIN match m WITH (NOLOCK) ON b.matchid = m.matchid
									WHERE m.sporttype = 1 )
			UNION ALL
			SELECT
				0 finalhomescore,
				0 finalawayscore,
				0,
				0 leagueid,
				29 bettype,
				CASE WHEN ISNULL(b.betID, 0) = 0 THEN b.transid ELSE b.betID END AS transid,
				ISNULL(b.BetID, 0) AS BetID,
				b.refno,
				'' matchcode,
				'' race, 
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				0 homeid,
				0 awayid,
				ISNULL(b.checktime, '') checktime,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				0 finalodds,
				0 finalodds2,
				' ' OddsType,
				b.status,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,  
				b.stake,
				b.actual_stake,
				b.transdate,
				b.betteam,
				0 livehomescore,
				0 liveawayscore,
				0 liveindicator,
				(b.winlost-b.actual_stake)  winlost,
				b.playercomm AS commission,
				creator.username creator,
				b.username,
				0 hthomescore,
				0 htawayscore,
				ip,
				0 sporttype,
				b.matchid,
				0 IsNeutral,
				'' AS showtime,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.betfrom,
				b.winlostdate,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS transdesc,
				0 AS OddsSpread
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN dbo.custInfo creator WITH (NOLOCK) ON creator.custid = b.creator
			WHERE	b.winlostdate = @fromdate
				AND b.matchid = 29
				AND b.bettype = 29
				AND b.custid = @custid
				AND b.refno IN (SELECT RefNo 
								FROM dbo.bettransm b WITH (NOLOCK)
									INNER JOIN dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid
								WHERE m.sporttype <> 1 )
				AND b.refno NOT IN (SELECT RefNo 
									FROM dbo.bettransm b WITH (NOLOCK)
										INNER JOIN dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid
									WHERE m.sporttype = 1 )
			-- OUTRIGHT
			UNION ALL
			SELECT
				0 finalhomescore,
				0 finalawayscore,
				0 oddsid,
				odds.leagueid,
				b.bettype,
				b.transid,
				ISNULL(b.BetID, 0) AS BetID,
				b.refno,
				odds.matchcode, 
				odds.groupmatch AS race,
				odds.eventdate,
				b.virtualrate,
				CASE WHEN b.currency2 IS NULL THEN CONVERT(BIT, 0) ELSE CONVERT(BIT, 1) END AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				CASE WHEN b.bettype = 10 THEN 0 ELSE odds.teamid END homeid,
				CASE WHEN b.bettype = 10 THEN odds.teamid ELSE 0 END awayid,
				ISNULL(b.checktime,'') checktime,
				b.hdp1, --phuong.nguyen <2008-12-30>
				b.hdp2, --end
				b.odds,
				b.modds,
				bmOdd.finalodds,
				bmOdd.finalodds2,
				' ' OddsType, 
				b.status,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.betteam,
				b.livehomescore, --phuong.nguyen <2008-12-30>
				b.liveawayscore,
				0 liveindicator, 
				(b.winlost-b.actual_stake)  winlost,
				b.playercomm AS commission, 
				CASE b.custid WHEN b.creator THEN b.Username ELSE '' END creator,
				b.username,
				0 hthomescore,
				0 htawayscore,
				ip,
				s.sporttype,
				b.matchid,
				0 IsNeutral,
				'' AS showtime,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.betfrom,
				b.winlostdate,
				b.betcheck,
				'' AS transdesc,
				0 AS OddsSpread
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN dbo.outright odds WITH (NOLOCK) ON b.matchid = odds.orid
				INNER JOIN dbo.league l WITH (NOLOCK) ON odds.leagueid = l.leagueid
				INNER JOIN dbo.Sports s WITH (NOLOCK) ON l.sporttype = s.sporttype
				INNER JOIN @SportBettype sbt ON sbt.Bettype = b.bettype
				LEFT JOIN (
					SELECT
						t.refno,
						t.finalodds,
						f.finalodds finalodds2
					FROM dbo.bettransm t WITH (NOLOCK)
						INNER JOIN dbo.bettransm f WITH (NOLOCK) ON t.refno = f.refno 
					WHERE t.bettype = 41 AND f.bettype = 42
				) bmOdd ON b.transid = bmOdd.refno 
			WHERE sbt.eventtype = 2
				AND b.winlostdate = @fromdate
				AND b.custid = @custid
				AND s.sporttype <> 1

			-- OUTRIGHT 14
			UNION ALL
			SELECT
				0 finalhomescore,
				0 finalawayscore,
				0 oddsid,
				odds.leagueid,
				b.bettype,
				b.transid,
				ISNULL(b.BetID,0) AS BetID,
				b.refno,
				odds.matchcode,
				odds.groupmatch AS race, --phuong.nguyen, get HR bet list,
				odds.eventdate,
				b.virtualrate,
				CASE WHEN b.currency2 IS NULL THEN CONVERT(BIT, 0) ELSE CONVERT(BIT, 1) END AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				CASE WHEN b.bettype = 10 THEN 0 ELSE odds.teamid END homeid,
				CASE WHEN b.bettype = 10 THEN odds.teamid ELSE 0 END awayid,
				ISNULL(b.checktime,'') checktime, 
				b.hdp1, --phuong.nguyen <2008-12-30>
				b.hdp2, --end
				b.odds,   
				b.modds,
				bmOdd.finalodds,
				bmOdd.finalodds2,
				' ' OddsType,
				b.status,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.betteam,
				b.livehomescore, --phuong.nguyen <2008-12-30>
				b.liveawayscore, --end
				0 liveindicator, 
				(b.winlost-b.actual_stake)  winlost,
				b.playercomm AS commission,
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END creator,
				b.username,
				0 hthomescore,
				0 htawayscore,
				ip,
				s.sporttype,
				b.matchid,
				0 IsNeutral,
				'' AS showtime,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.betfrom,
				b.winlostdate,
				b.betcheck,
				'' AS transdesc,
				0 AS OddsSpread
			FROM dbo.bettrans14 b WITH (NOLOCK)
				INNER JOIN dbo.outright14 odds WITH (NOLOCK) ON b.matchid = odds.orid
				INNER JOIN dbo.league l WITH (NOLOCK) ON odds.leagueid = l.leagueid
				INNER JOIN dbo.Sports s WITH (NOLOCK) ON l.sporttype = s.sporttype
				INNER JOIN @SportBettype sbt ON sbt.Bettype = b.bettype
				LEFT JOIN (
					SELECT
						t.refno,
						t.finalodds,
						f.finalodds finalodds2
					FROM dbo.bettransm14 t WITH (NOLOCK)
						INNER JOIN dbo.bettransm14 f WITH (NOLOCK) ON t.refno = f.refno 
					WHERE	t.bettype = 41 AND f.bettype = 42
				) bmOdd ON b.transid = bmOdd.refno 
			WHERE	sbt.eventtype = 2
				AND b.winlostdate = @fromdate
				AND b.custid = @custid
				AND s.SportType <> 1 

			-- Casino, Bingo, Gold Deluxe, Cockfighting, Microgaming Live Casino, NG2 bettrans
			UNION ALL
			SELECT
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS oddsid,
				0 AS leagueid,
				b.bettype,
				b.transid,
				ISNULL(b.BetID, 0) AS BetID,
				b.refno,
				'' AS matchcode,
				'' AS race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				0 AS homeid,
				0 AS awayid,
				ISNULL(b.checktime, '') AS checktime,
				CASE
					WHEN s.ProductId = 23 THEN b.hdp1
					ELSE 0
				END AS hdp1,
				CASE
					WHEN s.ProductId = 23 THEN b.hdp2
					ELSE 0
				END AS hdp2,
				CASE
					WHEN s.ProductID IN (12, 19, 23) THEN b.odds
					ELSE 0
				END AS odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				CASE
					WHEN s.ProductID = 19 THEN b.oddstype
					ELSE 0
				END AS OddsType,
				b.status,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				'' AS betteam,
				CASE
					WHEN s.ProductId = 23 THEN b.livehomescore
					ELSE 0
				END AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				(b.winlost - b.actual_stake) AS winlost,
				b.playercomm AS commission,
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END AS creator,
				b.username,
				0 AS hthomescore,
				0 AS htawayscore,
				ip,
				CASE
					WHEN s.ProductID = 6 THEN 251
					WHEN s.ProductID = 7 THEN 252
					WHEN s.ProductID = 12 THEN 255
					WHEN s.ProductID = 13 THEN 203
					WHEN s.ProductID = 19 THEN 206
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2501 AND 2539 THEN 213
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2541 AND 2579 THEN 214
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2581 AND 2619 THEN 215
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2621 AND 2659 THEN 216
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2681 AND 2699 THEN 218
				END AS sporttype,
				CASE
					WHEN s.ProductID = 12 THEN b.matchid
					WHEN s.ProductID IN (19, 23) THEN b.betdaqid
					ELSE 0
				END AS matchid,
				0 AS IsNeutral,
				'' AS showtime,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.betfrom,
				b.winlostdate,
				CASE
					WHEN s.ProductID IN (12, 13, 19) THEN b.betcheck
					ELSE ''
				END AS betcheck,
				CASE
					WHEN s.ProductID IN (19, 23) THEN b.transdesc
					ELSE ''
				END AS transdesc,
				0 AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @custid
				AND b.winlostdate = @fromdate
				AND (s.ProductID IN (7, 12, 13, 19, 23)
					OR (s.ProductId = 6 AND s.SubProduct = ''))

			-- Casino, Bingo, Gold Deluxe, Microgaming Live Casino, Microgaming RNG Casino, AG Casino, Cockfighting, AllBet 
			-- Voidbridge, NG2 bettrans14
			UNION ALL
			SELECT
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS oddsid,
				0 AS leagueid,
				b.bettype,
				b.transid,
				ISNULL(b.BetID, 0) AS BetID,
				b.refno,
				'' AS matchcode,
				'' AS race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				0 AS homeid,
				0 AS awayid,
				ISNULL(b.checktime, '') AS checktime,
				CASE
					WHEN s.ProductId = 23 THEN b.hdp1
					ELSE 0
				END AS hdp1,
				CASE
					WHEN s.ProductId = 23 THEN b.hdp2
					ELSE 0
				END AS hdp2,
				CASE
					WHEN s.ProductID IN (12, 19, 23) THEN b.odds
					ELSE 0
				END AS odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				CASE
					WHEN s.ProductID = 19 THEN b.oddstype
					ELSE 0
				END AS OddsType,
				b.status,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.betteam,
				b.livehomescore,
				b.liveawayscore,
				0 AS liveindicator,
				(b.winlost - b.actual_stake) AS winlost,
				b.playercomm AS commission,
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END creator,
				b.username,
				0 AS hthomescore,
				0 AS htawayscore,
				ip,
				CASE
					WHEN s.ProductID = 6 AND s.SubProduct = '' THEN 251
					WHEN s.ProductID = 6 AND s.SubProduct <> '' THEN b.matchid
					WHEN s.ProductID = 7 THEN 252
					WHEN s.ProductID = 11 THEN 250
					WHEN s.ProductID = 12 THEN 255
					WHEN s.ProductID = 13 THEN 203
					WHEN s.ProductID = 17 THEN 205
					WHEN s.ProductID = 19 THEN 206
					WHEN s.ProductID = 21 THEN 211
					WHEN s.ProductID = 22 THEN 212
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2501 AND 2539 THEN 213
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2541 AND 2579 THEN 214
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2581 AND 2619 THEN 215
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2621 AND 2659 THEN 216
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2681 AND 2699 THEN 218
				END AS sporttype,
				CASE
					WHEN s.ProductID = 12 THEN b.matchid
					WHEN s.ProductID IN (19, 23) THEN b.betdaqid
					ELSE 0
				END AS matchid,
				0 AS IsNeutral,
				'' AS showtime,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.betfrom,
				b.winlostdate,
				CASE
					WHEN s.ProductID IN (12, 13, 19) THEN b.betcheck
					ELSE ''
				END AS betcheck,
				CASE
					WHEN s.ProductID = 6 AND s.SubProduct <> '' THEN b.transdesc
					WHEN s.ProductID IN (19, 22, 23) THEN b.transdesc
					ELSE ''
				END AS transdesc,
				0 AS OddsSpread
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @custid
				AND b.winlostdate = @fromdate
				AND s.ProductID IN (6, 7, 11, 12, 13, 17, 19, 21, 22, 23)

			-- Keno
			UNION ALL
			SELECT
				0 finalhomescore,
				0 finalawayscore,
				0 oddsid,
				0 leagueid,
				b.bettype,
				b.transid,
				ISNULL(b.BetID,0) AS BetID,
				b.refno,
				'' AS matchcode,
				'' AS race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				0 homeid,
				0 awayid,
				ISNULL(b.checktime,'') checktime,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				0 finalodds,
				0 finalodds2, 
				' ' OddsType, 
				b.status,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				d.ChoiceId betteam,
				b.livehomescore,
				b.liveawayscore, 
				0 liveindicator, 
				(b.winlost-b.actual_stake) AS winlost,
				b.playercomm AS commission, 
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END creator,
				b.username,
				0 hthomescore,
				0 htawayscore,
				ip,
				202 AS sporttype,
				d.GameId matchid,
				0 IsNeutral,
				'' AS showtime,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.betfrom,
				b.winlostdate,
				b.betcheck,
				'' AS transdesc,
				0 AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype s ON s.Bettype = b.bettype
				OUTER APPLY dbo.[f_ParseTransDesc](b.TransDesc, b.bettype) d
			WHERE	s.ProductID = 8
				AND b.winlostdate = @fromdate
				AND b.custid = @custid

			UNION ALL -- keno translog
			SELECT	
				0 finalhomescore,
				0 finalawayscore,
				0 oddsid,
				0 leagueid,
				b.gameid,
				0 transid,
				0 AS BetID,
				b.translogid,
				'' matchcode,
				'' AS race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				0 homeid,
				0 awayid,
				'' checktime,
				0 hdp1,
				0 hdp2,
				b.odds,
				0 modds,
				0 finalodds,
				0 finalodds2, 
				' ' OddsType,
				b.status,
				0 AS comstatus,
				b.stake, 
				b.actual_stake,
				b.transdate, 
				d.ChoiceId betteam,
				0 livehomescore,
				0 liveawayscore, 
				0 liveindicator, 
				(-b.actual_stake)  winlost,
				0 commission, 
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END creator, 
				b.username,
				0 hthomescore,
				0 htawayscore,
				ip,
				202 AS sporttype, 
				d.GameId matchid,
				0 IsNeutral,
				'' AS showtime,
				0 awinlost,
				0 mwinlost,
				0 swinlost,
				b.betfrom,
				b.winlostdate,
				'' betcheck,
				'' AS transdesc,
				0 AS OddsSpread
			FROM dbo.translog b WITH (NOLOCK)
				INNER JOIN @SportBettype s ON s.Bettype = b.gameID
				OUTER APPLY dbo.[f_ParseTransDesc](b.TransDesc, b.gameid) d
			WHERE	s.ProductID = 8
				AND b.winlostdate = @fromdate
				AND b.custid = @custid
				AND b.statusID = 0

			--- IBC keno 14
			UNION ALL
			SELECT	
				0 finalhomescore,
				0 finalawayscore, 
				0 oddsid, 
				0 leagueid,
				b.bettype, 
				b.betid transid,
				ISNULL(b.BetID, 0) AS BetID,
				b.refno,
				CONVERT(VARCHAR(50),b.refno) matchcode,
				'' AS race, 
				'' AS eventdate, 
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				0 homeid,
				0 awayid,
				ISNULL(b.checktime, '') checktime, 
				b.hdp1, 
				b.hdp2, 
				b.odds,   
				b.modds,
				0 finalodds,
				0 finalodds2,
				' ' OddsType, 
				b.status, 
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,  
				b.stake, 
				b.actual_stake,
				b.transdate, 
				d.ChoiceId betteam,
				b.livehomescore, 
				b.liveawayscore,
				0 liveindicator, 
				(b.winlost - b.actual_stake) winlost,
				b.playercomm AS commission,
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END creator, 
				b.username,
				0 hthomescore,
				0 htawayscore,
				ip,
				202 sporttype,
				d.GameId matchid,
				0 IsNeutral,
				'' AS showtime,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.betfrom,
				b.winlostdate,
				b.betcheck,
				'' AS transdesc,
				0 AS OddsSpread
			FROM dbo.bettrans14 b WITH (NOLOCK)
				INNER JOIN @SportBettype s ON s.Bettype = b.bettype
				OUTER APPLY dbo.[f_ParseTransDesc](b.TransDesc, b.bettype) d
			WHERE s.ProductID = 8
				AND b.winlostdate = @fromdate
				AND b.custid = @custid

			-- P2P
			UNION ALL
			SELECT
				0 finalhomescore,
				0 finalawayscore,
				0 oddsid,
				0 leagueid,
				b.bettype,
				b.transid,
				ISNULL(b.BetID,0) AS BetID,
				b.refno,
				'' AS matchcode,
				'' AS race, --phuong.nguyen, get HR bet list,
				'' AS eventdate, --phuong.nguyen
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				0 homeid,
				0 awayid,
				ISNULL(b.checktime, '') checktime, 
				b.hdp1, --phuong.nguyen <2008-12-30>
				b.hdp2, --end
				b.odds,
				b.modds,
				0 finalodds,
				0 finalodds2,
				' ' OddsType,
				b.status,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,  
				b.stake, 
				b.actual_stake,
				b.transdate, 
				b.betteam,
				b.livehomescore, --phuong.nguyen <2008-12-30>
				b.liveawayscore, --end
				0 liveindicator, 
				(b.winlost-b.actual_stake)  winlost,
				b.playercomm AS commission,
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END creator,
				b.username,
				0 hthomescore,
				0 htawayscore,
				ip,
				253 AS sporttype,
				b.matchid,
				0 IsNeutral,
				'' AS showtime,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.betfrom,
				b.winlostdate,
				b.betcheck,
				'' AS transdesc,
				0 AS OddsSpread
			FROM dbo.bettrans b WITH (NOLOCK)
			WHERE	b.bettype = 1000
				AND b.matchid = 1000 
				AND b.winlostdate = @fromdate
				AND b.custid = @custid

			--- P2P 14
			UNION ALL
			SELECT
				0 finalhomescore,
				0 finalawayscore,
				0 oddsid,
				0 leagueid,
				b.bettype,
				b.transid,
				ISNULL(b.BetID,0) AS BetID,
				b.refno,
				'' matchcode,
				'' AS race, --phuong.nguyen, get HR bet list,
				'' AS eventdate, --phuong.nguyen
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				0 homeid,
				0 awayid,
				ISNULL(b.checktime,'') checktime, 
				b.hdp1, --phuong.nguyen <2008-12-30>
				b.hdp2, --end
				b.odds,
				b.modds,
				0 finalodds,
				0 finalodds2,
				' ' OddsType,
				b.status, 
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,  
				b.stake, 
				b.actual_stake,
				b.transdate, 
				b.betteam,
				b.livehomescore, --phuong.nguyen <2008-12-30>
				b.liveawayscore, --end
				0 liveindicator, 
				(b.winlost-b.actual_stake)  winlost,
				b.playercomm AS commission, 
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END creator, 
				b.username,
				0 hthomescore,
				0 htawayscore,
				ip,
				253 sporttype,
				b.matchid,
				0 IsNeutral,
				'' AS showtime,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.betfrom,
				b.winlostdate,
				b.betcheck,
				'' AS transdesc,
				0 AS OddsSpread
			FROM dbo.bettrans14 b WITH (NOLOCK)
			WHERE	b.bettype = 1000
				AND b.matchid = 1000 
				AND b.winlostdate = @fromdate
				AND b.custid = @custid

			-- Virtual HR
			UNION ALL
			SELECT
				0 finalhomescore,
				0 finalawayscore,
				b.oddsid,
				r.LeagueID,
				b.bettype,
				b.transid,
				'' AS BetID,
				b.refno,
				CONVERT(NVARCHAR(50), o.RacerNum) matchcode, --Horse Number
				b.oddsid AS Race, -- OutrightID
				'' EventDate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				o.RacerID AS homeID, 
				0 AS awayID,
				'' checktime, 
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				0 finalodds,
				0 finalodds2,
				'' OddsType,
				b.status, 
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake, 
				b.actual_stake,
				b.transdate, 
				'' AS betteam,
				b.livehomescore,
				b.liveawayscore,
				0 liveindicator,
				(b.winlost - b.actual_stake) winlost,
				b.playercomm AS commission, 
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END creator,
				b.username,
				0 hthomescore,
				0 htawayscore,
				ip,
				r.SportType,
				b.matchid,
				0 IsNeutral,
				CONVERT(NVARCHAR(50), r.EventTime) AS showtime, -- race name
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.betfrom,
				b.winlostdate,
				b.betcheck,
				'' AS transdesc,
				0 AS OddsSpread
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN dbo.VSOutright o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @SportBettype s ON s.BetType = b.BetType 
			WHERE	s.ProductID = 5
				AND s.EventType = 3
				AND b.winlostdate = @fromdate
				AND b.custid = @custid

			-- Virtual HR 14
			UNION ALL
			SELECT	
				0 finalhomescore,
				0 finalawayscore,
				b.oddsid,
				r.LeagueID,
				b.bettype,
				b.transid,
				'' AS BetID,
				b.refno,
				CONVERT(NVARCHAR(50), o.RacerNum) matchcode, --Horse Number
				b.oddsid AS Race, -- OutrightID
				'' EventDate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				o.RacerID AS homeID,
				0 AS awayID,
				'' checktime,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				0 finalodds,
				0 finalodds2,
				'' OddsType,
				b.status, 
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,  
				b.stake, 
				b.actual_stake,
				b.transdate,
				'' AS betteam,
				b.livehomescore,
				b.liveawayscore,
				0 liveindicator, 
				(b.winlost-b.actual_stake)  winlost,
				b.playercomm AS commission,
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END creator, 
				b.username,
				0 hthomescore,
				0 htawayscore,
				ip,
				r.SportType,
				b.matchid,
				0 IsNeutral,
				CONVERT(NVARCHAR(50), r.EventTime) AS showtime,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.betfrom,
				b.winlostdate,
				b.betcheck,
				'' AS transdesc,
				0 AS OddsSpread
			FROM dbo.bettrans14 b WITH (NOLOCK)
				INNER JOIN dbo.VSOutright14 o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @SportBettype s ON s.BetType = b.BetType 
			WHERE	s.ProductID = 5
				AND s.EventType = 3
				AND b.winlostdate = @fromdate
				AND b.custid = @custid

			-- Gold Deluxe, Microgaming Live Casino, Colossus Bet, Cockfighting translog
			UNION ALL 
			SELECT
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS oddsid,
				0 AS leagueid,
				b.gameid AS bettype,
				0 AS transid,
				0 AS BetID,
				b.translogid AS RefNo,
				'' AS matchcode,
				'' AS race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				0 AS homeid,
				0 AS awayid,
				'' AS checktime,
				0 AS hdp1,
				0 AS hdp2,
				CASE
					WHEN s.ProductID IN (12, 19) THEN b.odds
					ELSE 0
				END AS odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				CASE
					WHEN s.ProductID = 19 THEN CONVERT(TINYINT, ISNULL(b.custom1, 0))
					ELSE 0
				END AS OddsType,
				b.status,
				0 AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.GameID3rd AS betteam,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				(-b.actual_stake) AS winlost,
				0 AS commission,
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END creator,
				b.username,
				0 AS hthomescore,
				0 AS htawayscore,
				ip,
				CASE
					WHEN s.ProductID = 12 THEN 255
					WHEN s.ProductID = 13 THEN 203
					WHEN s.ProductID = 15 THEN 204
					WHEN s.ProductID = 19 THEN 206
				END AS sporttype,
				CASE
					WHEN s.ProductID = 19 THEN b.Gameid3rd
					ELSE 0
				END AS matchid,
				0 AS IsNeutral,
				'' AS showtime,
				0 AS awinlost,
				0 AS mwinlost,
				0 AS swinlost,
				b.betfrom,
				b.winlostdate,
				CASE
					WHEN s.ProductID = 15 THEN b.Tranid3rd
					WHEN s.ProductID = 19 THEN b.custom2
					ELSE ''
				END AS betcheck,
				CASE
					WHEN s.ProductID = 19 THEN b.transdesc
					ELSE ''
				END AS transdesc,
				0 AS OddsSpread
			FROM dbo.translog AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
			WHERE s.ProductID IN (12, 13, 15, 19)
				AND b.winlostdate = @fromdate
				AND b.custid = @custid
				AND b.statusID = 0

			-- Colossus Bet
			UNION ALL
			SELECT
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS oddsid,
				0 AS leagueid,
				b.bettype,
				b.transid,
				ISNULL(b.BetID, 0) AS BetID,
				b.refno,
				'' AS matchcode,
				'' AS race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				0 AS homeid,
				0 AS awayid,
				ISNULL(b.checktime, '') AS checktime,
				0 AS hdp1,
				0 AS hdp2,
				0 AS odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				b.status,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				'' AS betteam,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				(b.winlost - b.actual_stake) AS winlost,
				b.playercomm AS commission, 
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END AS creator,
				b.username,
				0 AS hthomescore,
				0 AS htawayscore,
				ip,
				204 AS sporttype,
				0 AS matchid,
				0 AS IsNeutral,
				'' AS showtime,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.betfrom,
				b.winlostdate,
				ISNULL(bm.betcheck, '') AS BetCheck,
				'' AS transdesc,
				0 AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				LEFT JOIN dbo.bettransm AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
			WHERE b.custid = @custid
				AND b.winlostdate = @fromdate
				AND s.ProductID = 15

			-- Colossus Bet
			UNION ALL
			SELECT
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS oddsid,
				0 AS leagueid,
				b.bettype,
				b.transid,
				ISNULL(b.BetID, 0) AS BetID,
				b.refno,
				'' AS matchcode,
				'' AS race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				0 AS homeid,
				0 AS awayid,
				ISNULL(b.checktime, '') AS checktime,
				0 AS hdp1,
				0 AS hdp2,
				0 AS odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType, 
				b.status, 
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.betteam,
				b.livehomescore,
				b.liveawayscore,
				0 AS liveindicator,
				(b.winlost - b.actual_stake) AS winlost,
				b.playercomm AS commission,
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END creator,
				b.username,
				0 AS hthomescore,
				0 AS htawayscore,
				ip,
				204 AS sporttype,
				b.matchid,
				0 AS IsNeutral,
				'' AS showtime,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.betfrom,
				b.winlostdate,
				ISNULL(bm.betcheck, '') AS BetCheck,
				'' AS transdesc,
				0 AS OddsSpread
			FROM dbo.bettrans14 b WITH (NOLOCK)
				INNER JOIN @SportBettype s ON s.Bettype = b.bettype
				LEFT JOIN dbo.bettransm14 AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
			WHERE b.custid = @custid
				AND b.winlostdate = @fromdate
				AND s.ProductID = 15

			-- Microgaming RNG Casino, RNG Casino Single Wallet, Voidbridge (not yesterday and today ticket)
			UNION ALL
			SELECT
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS oddsid,
				0 AS leagueid,
				b.bettype,
				b.transid,
				ISNULL(b.BetID, 0) AS BetID,
				b.refno,
				'' AS matchcode,
				'' AS race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				0 AS homeid,
				0 AS awayid,
				ISNULL(b.checktime, '') AS checktime,
				0 AS hdp1,
				0 AS hdp2,
				0 AS odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				b.status,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				'' AS betteam,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				(b.winlost - b.actual_stake) AS winlost,
				b.playercomm AS commission, 
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END AS creator,
				b.username,
				0 AS hthomescore,
				0 AS htawayscore,
				b.ip,
				CASE
					WHEN s.ProductID = 6 THEN b.matchid
					WHEN s.ProductID = 17 THEN 205
					WHEN s.ProductID = 22 THEN 212
				END AS Sporttype,
				0 AS matchid,
				0 AS IsNeutral,
				'' AS showtime,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.betfrom,
				b.winlostdate,
				'' AS betcheck,
				CASE
					WHEN s.ProductID IN (6, 22) THEN b.transdesc
					ELSE ''
				END AS transdesc,
				0 AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @custid
				AND b.winlostdate = @fromdate
				AND @fromdate <> DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)		-- not today
				AND (s.ProductId IN (17, 22)
					OR (s.ProductId = 6 AND s.SubProduct <> ''))

			-- Microgaming RNG Casino, RNG Casino Single Wallet, Voidbridge (yesterday and today running ticket)
			UNION ALL
			SELECT
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS oddsid,
				0 AS leagueid,
				b.bettype,
				b.transid,
				0 AS BetID,
				b.refno,
				'' AS matchcode,
				'' AS race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				AVG(brng.sdiscount) AS sdiscount,
				AVG(brng.adiscount) AS adiscount,
				AVG(brng.discount) AS discount,
				0 AS homeid,
				0 AS awayid,
				ISNULL(b.checktime, '') AS checktime,
				0 AS hdp1,
				0 AS hdp2,
				0 AS odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				'Running' AS Status,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				SUM(brng.stake) AS Stake,
				SUM(brng.actual_stake) AS Actual_Stake,
				b.transdate,
				'' AS betteam,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0 AS Winlost,
				0 AS commission, 
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END AS creator,
				b.username,
				0 AS hthomescore,
				0 AS htawayscore,
				b.ip,
				CASE
					WHEN s.ProductID = 6 THEN b.matchid
					WHEN s.ProductID = 17 THEN 205
					WHEN s.ProductID = 22 THEN 212
				END AS Sporttype,
				0 AS matchid,
				0 AS IsNeutral,
				'' AS showtime,
				0 AS awinlost,
				0 AS mwinlost,
				0 AS swinlost,
				b.betfrom,
				b.winlostdate,
				'' AS betcheck,
				CASE
					WHEN s.ProductID IN (6, 22) THEN b.transdesc
					ELSE ''
				END AS transdesc,
				0 AS OddsSpread
			FROM dbo.bettransRnG AS brng WITH (NOLOCK)
				INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @custid
				AND b.winlostdate = @fromdate
				AND @fromdate = DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)		-- today
				AND (s.ProductId IN (17, 22)
					OR (s.ProductId = 6 AND s.SubProduct <> ''))
				AND brng.statusID IN (0, 1)
			GROUP BY
				b.transid,
				ISNULL(b.BetID, 0),
				ISNULL(b.checktime, ''),
				b.Bettype,
				b.refno,
				b.transdate,
				b.winlostdate,
				b.custid,
				b.username,
				b.creator,
				b.IP,
				b.betfrom,
				b.comstatus,
				b.matchid,
				b.transdesc,
				s.ProductID

			-- Microgaming RNG Game, RNG Casino Single Wallet (yesterday and today settled ticket)
			UNION ALL
			SELECT
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS oddsid,
				0 AS leagueid,
				b.bettype,
				b.transid,
				0 AS BetID,
				b.refno,
				'' AS matchcode,
				'' AS race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				AVG(brng.sdiscount) AS sdiscount,
				AVG(brng.adiscount) AS adiscount,
				AVG(brng.discount) AS discount,
				0 AS homeid,
				0 AS awayid,
				ISNULL(b.checktime, '') AS checktime,
				0 AS hdp1,
				0 AS hdp2,
				0 AS odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				CASE 
					WHEN SUM(brng.winlost - brng.actual_stake) = 0 THEN 'Draw'
					WHEN SUM(brng.winlost - brng.actual_stake) > 0 THEN 'Won'
					WHEN SUM(brng.winlost - brng.actual_stake) < 0 THEN 'Lose'
				END AS Status,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				SUM(brng.stake) AS Stake,
				SUM(brng.actual_stake) AS Actual_Stake,
				b.transdate,
				'' AS betteam,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				SUM(brng.winlost - brng.actual_stake) AS Winlost,
				SUM(brng.playercomm) AS commission, 
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END AS creator,
				b.username,
				0 AS hthomescore,
				0 AS htawayscore,
				b.ip,
				CASE
					WHEN s.ProductID = 6 THEN b.matchid
					WHEN s.ProductID = 17 THEN 205
					WHEN s.ProductID = 22 THEN 212
				END AS Sporttype,
				0 AS matchid,
				0 AS IsNeutral,
				'' AS showtime,
				SUM(brng.awinlost) AS awinlost,
				SUM(brng.mwinlost) AS mwinlost,
				SUM(brng.swinlost) AS swinlost,
				b.betfrom,
				b.winlostdate,
				'' AS betcheck,
				CASE
					WHEN s.ProductID IN (6, 22) THEN b.transdesc
					ELSE ''
				END AS transdesc,
				0 AS OddsSpread
			FROM dbo.bettransRnG AS brng WITH (NOLOCK)
				INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @custid
				AND b.winlostdate = @fromdate
				AND @fromdate = DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)		-- today
				AND (s.ProductId IN (17, 22)
					OR (s.ProductId = 6 AND s.SubProduct <> ''))
				AND brng.statusID NOT IN (0, 1)
			GROUP BY
				b.transid,
				ISNULL(b.BetID, 0),
				ISNULL(b.checktime, ''),
				b.Bettype,
				b.refno,
				b.transdate,
				b.winlostdate,
				b.custid,
				b.username,
				b.creator,
				b.IP,
				b.betfrom,
				b.comstatus,
				b.matchid,
				b.transdesc,
				s.ProductID

			-- AG Casino, AllBet (not yesterday and today ticket)
			UNION ALL
			SELECT
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS oddsid,
				0 AS leagueid,
				b.bettype,
				b.transid,
				ISNULL(b.BetID, 0) AS BetID,
				b.refno,
				'' AS matchcode,
				'' AS race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				0 AS homeid,
				0 AS awayid,
				ISNULL(b.checktime, '') AS checktime,
				0 AS hdp1,
				0 AS hdp2,
				0 AS odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				b.status,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				'' AS betteam,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				(b.winlost - b.actual_stake) AS winlost,
				b.playercomm AS commission, 
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END AS creator,
				b.username,
				0 AS hthomescore,
				0 AS htawayscore,
				ip,
				CASE
					WHEN s.ProductID = 11 THEN 250
					WHEN s.ProductID = 21 THEN 211
				END AS sporttype,
				0 AS matchid,
				0 AS IsNeutral,
				'' AS showtime,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.betfrom,
				b.winlostdate,
				'' AS betcheck,
				'' AS transdesc,
				0 AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @custid
				AND b.winlostdate = @fromdate
				AND @fromdate < DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)		-- not today
				AND s.ProductID IN (11, 21)

			-- AG Casino, AllBet (yesterday and today running ticket)
			UNION ALL
			SELECT
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS oddsid,
				0 AS leagueid,
				b.bettype,
				b.transid,
				0 AS BetID,
				b.refno,
				'' AS matchcode,
				'' AS race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				AVG(blc.sdiscount) AS sdiscount,
				AVG(blc.adiscount) AS adiscount,
				AVG(blc.discount) AS discount,
				0 AS homeid,
				0 AS awayid,
				ISNULL(b.checktime, '') AS checktime,
				0 AS hdp1,
				0 AS hdp2,
				0 AS odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				'Running' AS Status,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				SUM(blc.stake) AS Stake,
				SUM(blc.actual_stake) AS Actual_Stake,
				b.transdate,
				'' AS betteam,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0 AS Winlost,
				0 AS commission, 
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END AS creator,
				b.username,
				0 AS hthomescore,
				0 AS htawayscore,
				b.ip,
				CASE
					WHEN s.ProductID = 11 THEN 250
					WHEN s.ProductID = 21 THEN 211
				END AS sporttype,
				0 AS matchid,
				0 AS IsNeutral,
				'' AS showtime,
				0 AS awinlost,
				0 AS mwinlost,
				0 AS swinlost,
				b.betfrom,
				b.winlostdate,
				'' AS betcheck,
				'' AS transdesc,
				0 AS OddsSpread
			FROM dbo.bettransLC AS blc WITH (NOLOCK)
				INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @custid
				AND b.winlostdate = @fromdate
				AND @fromdate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
					AND DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)		-- yesterday and today
				AND s.ProductID IN (11, 21)
				AND blc.statusID IN (0, 1)
			GROUP BY
				b.transid,
				ISNULL(b.BetID, 0),
				ISNULL(b.checktime, ''),
				b.Bettype,
				b.refno,
				b.transdate,
				b.winlostdate,
				b.custid,
				b.username,
				b.creator,
				b.IP,
				b.betfrom,
				b.comstatus,
				s.ProductID

			-- AG Casino, AllBet (yesterday and today settled ticket)
			UNION ALL
			SELECT
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS oddsid,
				0 AS leagueid,
				b.bettype,
				b.transid,
				0 AS BetID,
				b.refno,
				'' AS matchcode,
				'' AS race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				AVG(blc.sdiscount) AS sdiscount,
				AVG(blc.adiscount) AS adiscount,
				AVG(blc.discount) AS discount,
				0 AS homeid,
				0 AS awayid,
				ISNULL(b.checktime, '') AS checktime,
				0 AS hdp1,
				0 AS hdp2,
				0 AS odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				CASE 
					WHEN SUM(blc.winlost - blc.actual_stake) = 0 THEN 'Draw'
					WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
					WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
				END AS Status,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				SUM(blc.stake) AS Stake,
				SUM(blc.actual_stake) AS Actual_Stake,
				b.transdate,
				'' AS betteam,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				SUM(blc.winlost - blc.actual_stake) AS Winlost,
				SUM(blc.playercomm) AS commission, 
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END AS creator,
				b.username,
				0 AS hthomescore,
				0 AS htawayscore,
				b.ip,
				CASE
					WHEN s.ProductID = 11 THEN 250
					WHEN s.ProductID = 21 THEN 211
				END AS sporttype,
				0 AS matchid,
				0 AS IsNeutral,
				'' AS showtime,
				SUM(blc.awinlost) AS awinlost,
				SUM(blc.mwinlost) AS mwinlost,
				SUM(blc.swinlost) AS swinlost,
				b.betfrom,
				b.winlostdate,
				'' AS betcheck,
				'' AS transdesc,
				0 AS OddsSpread
			FROM dbo.bettransLC AS blc WITH (NOLOCK)
				INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @custid
				AND b.winlostdate = @fromdate
				AND @fromdate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
					AND DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)		-- yesterday and today
				AND s.ProductID IN (11, 21)
				AND blc.statusID NOT IN (0, 1)
			GROUP BY
				b.transid,
				ISNULL(b.BetID, 0),
				ISNULL(b.checktime, ''),
				b.Bettype,
				b.refno,
				b.transdate,
				b.winlostdate,
				b.custid,
				b.username,
				b.creator,
				b.IP,
				b.betfrom,
				b.currency,
				b.comstatus,
				s.ProductID
		) x
	WHERE ip = @ip
	ORDER BY 4, 26

	IF EXISTS (	SELECT TOP 1 1 
				FROM @SportBettype sp 
					INNER JOIN @Data d ON d.bettype = sp.bettype 
				WHERE ProductID IN (4,12))
	BEGIN
		INSERT INTO @DetailData
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
			bg.TransDesc
		FROM dbo.bettransg AS bg WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON bg.bettype = sp.bettype AND sp.Productid IN (4)
			INNER JOIN @Data AS B ON bg.CustID = @CustID AND (sp.Productid IN (4) AND bg.refno = B.refno AND bg.bettype = B.bettype)
		UNION ALL
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
			bg.TransDesc
		FROM dbo.bettransg AS bg WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON bg.bettype = sp.bettype AND sp.Productid IN (12)
			INNER JOIN @Data AS B ON bg.CustID = @CustID AND (sp.Productid IN (12) AND bg.refno = B.transid AND bg.bettype = B.bettype)

		INSERT INTO @DetailData
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
			bg.TransDesc
		FROM dbo.bettransg14 AS bg WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON bg.bettype = sp.bettype AND sp.Productid IN (4)
			INNER JOIN @Data AS B ON  (bg.refno = B.refno AND bg.CustID = @CustID AND sp.Productid IN (4))
		UNION ALL
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
			bg.TransDesc
		FROM dbo.bettransg14 AS bg WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON bg.bettype = sp.bettype AND sp.Productid IN (12)
			INNER JOIN @Data AS B ON (bg.refno = B.transid AND bg.CustID = @CustID AND sp.Productid IN (12))
	END

	SELECT * FROM @Data
	ORDER BY 4, 26

	SELECT * FROM @DetailData
END









GO
GRANT EXECUTE ON [dbo].[Acc_BetListByIP_OtherSports] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BetListByIP_OtherSports] TO [vnteam]