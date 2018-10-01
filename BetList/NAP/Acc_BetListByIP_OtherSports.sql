/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetListByIP_OtherSports]
	@CustId		INT,
	@Ip			VARCHAR(15),
	@FromDate	DATETIME
AS

/*
	Created: Phuong Dao
	Task: Bet List By IP and Other Sports
	DB: DBACC.bodb02
	Original: Acc_BetListByDayAllIP
	Revisions:
		- 20090509@Simon: Bet List For Casino
		- 20090528@PhuongDao: Add HR Fixed Odd
		- 20091002@Simon: Get Odds && OddsType columns
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
		- 20110802@Johnson: Add new bettype combination mix-parlay
						- Add new column actual_stake into betlist
		- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
		- 20111207@Sophia: Add P2P
		- 20120120@Sophia: Add Showtime for Table-hand-shoe of Live Casino
						- Add sub detail for Live Casino
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
		- 20140908@Dom: Update VS conditions [Redmine #22012]
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
		- 20161019@Kos: Remove Bingo and P2P in bettrans and bettrans14 range [#Redmine: 53988]
					- Support Fishing World [#Redmine: 65934]
		- 20170228@Kos: Support KickOffTime for Virtual Soccer and Virtual Tennis [#Redmine: 71906]
		- 20170321@Kos: Support CashOut [#Redmine: 71963]
		- 20170620@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20170629@Kos: Support Keno Lottery [#Redmine: 77929]
		- 20170718@Kos: Don't parse transdesc for Keno anymore [#Redmine: 80082]
		- 20170829@Kos: Support Lucky 3 [#Redmine: 75277]
		- 20171025@Kos: Support Bullfighting [#Redmine: 84961]
					- Don't support Live Casino anymore
		- 20171227@Kos: Return ticket detail of Racing and Virtual Horse Racing [#Redmine: 88775]
					- Don't support Live Casino in bettrans and bettrans14 anymore
		- 20180118@Kos: Support Licensee Bonus System [#Redmine: 74978]
		- 20180305@Kos: Don't support Racing, Cockfighting, RNG Casino (bettype 71, 72) anymore [#Redmine: 86086]
		- 20180323@Kos: Support ONERnG Jackpot [#Redmine: 88652]
		- 20180405@Kos: Support Pragmatic Casino [#Redmine: 92160]
		- 20180510@Kos: Support Keno 6 new Mini Games [#Redmine: 93759]
		- 20180515@Kos: Add Match No for Bullfighting [#Redmine: 84961]
		- 20180709@Kos: Support Poker Games [#Redmine: 97565]
		- 20180911@Kos: Hotfix - Wrong operator name [#Redmine: 101299]
		- 20180927@Kos: Support new status Result Pending and Under Settlement [#Redmine: 101949]

	Param's Explanation:
		• @FromDate = @winlostdate
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID NOT IN (2, 4, 7, 9, 19)
		AND (ProductID <> 6 OR SubProduct <> '')

	DECLARE @Date DATETIME

	SET @Date = @FromDate

	DECLARE @Data TABLE (
		FinalHomeScore		INT,
		FinalAwayScore		INT,
		OddsId				INT,
		LeagueId			INT,
		BetType				SMALLINT,
		TransId				BIGINT,
		BetId				BIGINT,
		RefNo				BIGINT,
		MatchId				INT,
		MatchCode			NVARCHAR(50),
		Race				NVARCHAR(50),
		EventDate			DATETIME,
		VirtualRate			FLOAT, --in case OpenTote, it's currency2's exRate 
		IsShowOTExRate		BIT, --show OpenTote ExRate or not 
		SDiscount			DECIMAL(9, 8),
		ADiscount			DECIMAL(9, 8),
		Discount			DECIMAL(9, 8),
		HomeId				INT,
		AwayId				INT,
		SettleTime			DATETIME,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
		MOdds				MONEY,
		FinalOdds			MONEY,
		FinalOdds2			MONEY,
		OddsType			INT,
		Status				NVARCHAR(50),
		SettlementStatus	TINYINT,
		ComStatus			NVARCHAR(20),
		Stake				MONEY,
		Actual_Stake		MONEY,
		TransDate			DATETIME,
		BetTeam				NVARCHAR(50),
		LiveHomeScore		INT,
		LiveAwayScore		INT,
		LiveIndicator		BIT,
		WinLost				MONEY,
		Commission			MONEY,
		AWinLost			MONEY,
		MWinLost			MONEY,
		SWinLost			MONEY,
		Creator				VARCHAR(50),
		Username			NVARCHAR(50),
		HtHomeScore			INT,
		HtAwayScore			INT,
		Ip					NVARCHAR(15),
		BetFrom				NVARCHAR(1),
		SportType			INT,
		IsNeutral			BIT,
		ShowTime			NVARCHAR(50),
		WinLostDate			SMALLDATETIME,
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		OddsSpread			MONEY,
		OriginalBetType		INT,
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		WalletType			TINYINT,
		RefCode				BIGINT
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
		SettlementStatus,
		comstatus,
		stake,
		actual_stake,
		transdate,
		betteam,
		livehomescore,
		liveawayscore,
		liveindicator,
		winlost,
		commission,
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
		OddsSpread,
		OriginalBetType,
		BetdaqId,
		ExtraInfo,
		WalletType,
		RefCode
	FROM (
			SELECT
				m.finalhomescore,
				m.finalawayscore,
				b.oddsid,
				m.leagueid,
				b.bettype,
				b.transid,
				ISNULL(b.betid, 0) AS BetID,
				b.refno,
				m.matchcode,
				'' AS race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				CASE
					WHEN s.ProductID = 26 THEN 0
					ELSE b.sdiscount
				END AS SDiscount,
				CASE
					WHEN s.ProductID = 26 THEN 0
					ELSE b.adiscount
				END AS ADiscount,
				CASE
					WHEN s.ProductID = 26 THEN 0
					ELSE b.discount
				END AS Discount,
				m.homeid,
				m.awayid,
				ISNULL(b.checktime,'') checktime,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				0 finalodds,
				0 finalodds2,
				b.oddstype,
				b.status,
				0 AS SettlementStatus,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.betteam,
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm AS commission,
				c.username AS creator,
				b.username,
				m.hthomescore,
				m.htawayscore,
				b.ip,
				m.sporttype,
				b.matchid,
				m.IsNeutral,
				CASE
					WHEN s.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
					ELSE m.showtime
				END AS ShowTime,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.betfrom,
				b.winlostdate,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b.WalletType, 0)
					ELSE 0
				END AS WalletType,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b.RefCode, 0)
					ELSE 0
				END AS RefCode
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN dbo.custInfo AS c WITH (NOLOCK) ON c.custid = b.creator
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.winlostdate = @Date
				AND s.EventType = 1
				AND b.custid = @CustId
				AND m.sporttype <> 1

			-- Mix Parlay, System Parlay, Mix Parlay (Betradar Virtual Sports)
			UNION ALL
			SELECT
				0 finalhomescore,
				0 finalawayscore,
				0,
				0 leagueid,
				b.bettype,
				CASE
					WHEN b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
					ELSE b.transid
				END AS TransId,
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
				0 AS OddsType,
				b.status,
				0 AS SettlementStatus,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.betteam,
				0 livehomescore, 
				0 liveawayscore,
				0 liveindicator,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm AS commission,
				c.username AS creator,
				b.username,
				0 hthomescore,
				0 htawayscore,
				b.ip,
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
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettrans14 AS b WITH (NOLOCK) 
				INNER JOIN dbo.custInfo AS c WITH (NOLOCK) ON c.custid = b.creator
			WHERE b.bettype IN (9, 29, 2799)
				AND b.winlostdate = @Date
				AND b.matchid IN (9, 29, 2799)
				AND b.custid = @CustId
				AND b.refno IN (SELECT DISTINCT b.refno
								FROM dbo.bettransm14 AS b WITH (NOLOCK)
									INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
								WHERE m.sporttype <> 1)
				AND b.refno NOT IN (SELECT DISTINCT b.refno
									FROM dbo.bettransm14 AS b WITH (NOLOCK)
										INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
									WHERE m.sporttype = 1)
			UNION ALL
			SELECT 
				m.finalhomescore,
				m.finalawayscore,
				b.oddsid,
				m.leagueid,
				b.bettype,
				b.transid,
				ISNULL(b.betid, 0) AS BetID,
				b.refno,
				m.matchcode,
				'' race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				CASE
					WHEN s.ProductID = 26 THEN 0
					ELSE b.sdiscount
				END AS SDiscount,
				CASE
					WHEN s.ProductID = 26 THEN 0
					ELSE b.adiscount
				END AS ADiscount,
				CASE
					WHEN s.ProductID = 26 THEN 0
					ELSE b.discount
				END AS Discount,
				m.homeid,
				m.awayid,
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
				ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.betteam,
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm AS commission, 
				c.username AS creator,
				b.username,
				m.hthomescore,
				m.htawayscore,
				b.ip,
				m.sporttype,
				b.matchid,
				m.IsNeutral,
				CASE
					WHEN s.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
					ELSE m.showtime
				END AS ShowTime,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.betfrom,
				b.winlostdate,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b.WalletType, 0)
					ELSE 0
				END AS WalletType,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b.RefCode, 0)
					ELSE 0
				END AS RefCode
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN dbo.custInfo AS c WITH (NOLOCK) ON c.custid = b.creator
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.winlostdate = @Date
				AND s.eventtype = 1
				AND b.bettype <> 10
				AND m.sporttype <> 1
				AND b.custid = @CustId

			-- Mix Parlay, System Parlay, Mix Parlay (Betradar Virtual Sports)
			UNION ALL
			SELECT
				0 finalhomescore,
				0 finalawayscore,
				0,
				0 leagueid,
				b.bettype,
				CASE
					WHEN b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
					ELSE b.transid
				END AS TransId,
				ISNULL(b.betid, 0) AS BetID,
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
				0 AS OddsType,
				b.status,
				0 AS SettlementStatus,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.betteam,
				0 livehomescore,
				0 liveawayscore,
				0 liveindicator,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm AS commission,
				c.username AS creator,
				b.username,
				0 hthomescore,
				0 htawayscore,
				b.ip,
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
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.custInfo AS c WITH (NOLOCK) ON c.custid = b.creator
			WHERE b.winlostdate = @Date
				AND b.matchid IN (9, 29, 2799)
				AND b.bettype IN (9, 29, 2799)
				AND b.custid = @CustId
				AND b.refno IN (SELECT DISTINCT b.refno
								FROM dbo.bettransm AS b WITH (NOLOCK)
									INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
								WHERE m.sporttype <> 1 )
				AND b.refno NOT IN (SELECT DISTINCT b.refno
									FROM dbo.bettransm AS b WITH (NOLOCK)
										INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
									WHERE m.sporttype = 1 )

			-- Outright
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
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				bmOdd.finalodds,
				bmOdd.finalodds2,
				0 AS OddsType, 
				b.status,
				0 AS SettlementStatus,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.betteam,
				b.livehomescore,
				b.liveawayscore,
				0 liveindicator, 
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm AS commission,
				CASE b.custid WHEN b.creator THEN b.Username ELSE '' END creator,
				b.username,
				0 hthomescore,
				0 htawayscore,
				b.ip,
				l.sporttype,
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
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.outright AS odds WITH (NOLOCK) ON b.matchid = odds.orid
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON odds.leagueid = l.leagueid
				INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
				LEFT JOIN (
					SELECT
						t.refno,
						t.finalodds,
						f.finalodds AS finalodds2
					FROM dbo.bettransm AS t WITH (NOLOCK)
						INNER JOIN dbo.bettransm AS f WITH (NOLOCK) ON t.refno = f.refno
					WHERE t.bettype = 41 AND f.bettype = 42
				) bmOdd ON b.transid = bmOdd.refno
			WHERE sbt.eventtype = 2
				AND b.winlostdate = @Date
				AND b.custid = @CustId
				AND l.sporttype <> 1

			-- Outright14
			UNION ALL
			SELECT
				0 finalhomescore,
				0 finalawayscore,
				0 oddsid,
				odds.leagueid,
				b.bettype,
				b.transid,
				ISNULL(b.betid, 0) AS BetID,
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
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				bmOdd.finalodds,
				bmOdd.finalodds2,
				0 AS OddsType,
				b.status,
				0 AS SettlementStatus,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.betteam,
				b.livehomescore,
				b.liveawayscore,
				0 liveindicator,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm AS commission,
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END creator,
				b.username,
				0 hthomescore,
				0 htawayscore,
				b.ip,
				l.sporttype,
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
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.outright14 AS odds WITH (NOLOCK) ON b.matchid = odds.orid
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON odds.leagueid = l.leagueid
				INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
				LEFT JOIN (
					SELECT
						t.refno,
						t.finalodds,
						f.finalodds finalodds2
					FROM dbo.bettransm14 AS t WITH (NOLOCK)
						INNER JOIN dbo.bettransm14 AS f WITH (NOLOCK) ON t.refno = f.refno
					WHERE t.bettype = 41 AND f.bettype = 42
				) bmOdd ON b.transid = bmOdd.refno
			WHERE sbt.eventtype = 2
				AND b.winlostdate = @Date
				AND b.custid = @CustId
				AND l.sporttype <> 1 

			-- Keno, Gold Deluxe, Microgaming Live Casino, NG2, Lottery, Poker Games bettrans
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
					WHEN s.ProductId IN (23, 33) THEN b.hdp1
					ELSE 0
				END AS hdp1,
				CASE
					WHEN s.ProductId = 23 THEN b.hdp2
					ELSE 0
				END AS hdp2,
				CASE
					WHEN s.ProductID IN (8, 12, 23, 28) THEN b.odds
					ELSE 0
				END AS odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				b.status,
				0 AS SettlementStatus,
				CASE
					WHEN s.ProductID = 33 THEN ISNULL(b.comstatus, '')
					ELSE ''
				END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				'' AS betteam,
				CASE
					WHEN s.ProductId IN (23, 33) THEN b.livehomescore
					ELSE 0
				END AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm AS commission,
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END AS creator,
				b.username,
				0 AS hthomescore,
				0 AS htawayscore,
				b.ip,
				CASE
					WHEN s.ProductID = 8 THEN 202
					WHEN s.ProductID = 12 THEN 255
					WHEN s.ProductID = 13 THEN 203
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2501 AND 2539 THEN 213
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2541 AND 2579 THEN 214
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2581 AND 2619 THEN 215
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2621 AND 2659 THEN 216
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2681 AND 2699 THEN 218
					WHEN s.ProductID = 28 THEN 220
					WHEN s.ProductID = 33 THEN 163
					ELSE 0
				END AS sporttype,
				CASE
					WHEN s.ProductID = 12 THEN b.matchid
					WHEN s.ProductID = 23 THEN b.betdaqid
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
					WHEN s.ProductID IN (12, 13, 33) THEN b.betcheck
					WHEN s.ProductId = 8 THEN ISNULL(b.comstatus, '')
					ELSE ''
				END AS betcheck,
				CASE
					WHEN s.ProductID IN (8, 23, 28) THEN b.transdesc
					ELSE ''
				END AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				CASE
					WHEN s.ProductId = 33 THEN ISNULL(b.ExtraInfo, '')
					ELSE ''
				END AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate = @Date
				AND s.ProductID IN (8, 12, 13, 23, 28, 33)

			-- Casino, Keno, Gold Deluxe, Microgaming Live Casino, Microgaming RNG Casino, AG Casino, AllBet 
			-- Voidbridge, NG2, Fishing World, Lottery, Pragmatic Casino, Poker Games bettrans14
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
					WHEN s.ProductId IN (23, 33) THEN b.hdp1
					ELSE 0
				END AS hdp1,
				CASE
					WHEN s.ProductId = 23 THEN b.hdp2
					ELSE 0
				END AS hdp2,
				CASE
					WHEN s.ProductID IN (6, 8, 12, 23, 28) THEN b.odds
					ELSE 0
				END AS odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				b.status,
				0 AS SettlementStatus,
				CASE
					WHEN s.ProductID = 33 THEN ISNULL(b.comstatus, '')
					ELSE ''
				END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.betteam,
				b.livehomescore,
				b.liveawayscore,
				0 AS liveindicator,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm AS commission,
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END creator,
				b.username,
				0 AS hthomescore,
				0 AS htawayscore,
				b.ip,
				CASE
					WHEN s.ProductID = 6 THEN b.matchid
					WHEN s.ProductID = 8 THEN 202
					WHEN s.ProductID = 11 THEN 250
					WHEN s.ProductID = 12 THEN 255
					WHEN s.ProductID = 13 THEN 203
					WHEN s.ProductID = 17 THEN 205
					WHEN s.ProductID = 21 THEN 211
					WHEN s.ProductID = 22 THEN 212
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2501 AND 2539 THEN 213
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2541 AND 2579 THEN 214
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2581 AND 2619 THEN 215
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2621 AND 2659 THEN 216
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2681 AND 2699 THEN 218
					WHEN s.ProductID = 24 THEN 219
					WHEN s.ProductID = 28 THEN 220
					WHEN s.ProductID = 32 THEN 248
					WHEN s.ProductID = 33 THEN 163
					ELSE 0
				END AS sporttype,
				CASE
					WHEN s.ProductID = 12 THEN b.matchid
					WHEN s.ProductID = 23 THEN b.betdaqid
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
					WHEN s.ProductID IN (12, 13, 33) THEN b.betcheck
					WHEN s.ProductId = 8 THEN ISNULL(b.comstatus, '')
					ELSE ''
				END AS betcheck,
				CASE
					WHEN s.ProductID IN (6, 8, 22, 23, 24, 28, 32) THEN b.transdesc
					ELSE ''
				END AS transdesc,
				CASE
					WHEN s.ProductID = 6 THEN ISNULL(b.oddsspread, 0)
					ELSE 0
				END AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				CASE
					WHEN s.ProductId = 33 THEN ISNULL(b.ExtraInfo, '')
					ELSE ''
				END AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate = @Date
				AND s.ProductID IN (6, 7, 8, 11, 12, 13, 17, 21, 22, 23, 24, 28, 32, 33)

			-- Virtual Horse Racing
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
				CONVERT(NVARCHAR(50), o.RacerNum) matchcode,
				b.oddsid AS Race,
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
				0 AS OddsType,
				b.status,
				0 AS SettlementStatus,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
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
				b.ip,
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
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @SportBettype AS s ON s.BetType = b.BetType 
			WHERE s.ProductID = 5
				AND s.EventType = 3
				AND b.winlostdate = @Date
				AND b.custid = @CustId

			-- Virtual Horse Racing 14
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
				CONVERT(NVARCHAR(50), o.RacerNum) matchcode,
				b.oddsid AS Race,
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
				0 AS OddsType,
				b.status,
				0 AS SettlementStatus,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				b.stake, 
				b.actual_stake,
				b.transdate,
				'' AS betteam,
				b.livehomescore,
				b.liveawayscore,
				0 liveindicator, 
				(b.winlost - b.actual_stake)  winlost,
				b.playercomm AS commission,
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END creator,
				b.username,
				0 hthomescore,
				0 htawayscore,
				b.ip,
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
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.VSOutright14 AS o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @SportBettype AS s ON s.BetType = b.BetType 
			WHERE s.ProductID = 5
				AND s.EventType = 3
				AND b.winlostdate = @Date
				AND b.custid = @CustId

			-- Keno, Gold Deluxe, Microgaming Live Casino, Colossus Bet, Lottery translog
			UNION ALL
			SELECT
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS oddsid,
				0 AS leagueid,
				b.gameid AS bettype,
				b.translogid AS TransId,
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
					WHEN s.ProductID IN (8, 12, 28) THEN b.odds
					ELSE 0
				END AS odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				b.status,
				0 AS SettlementStatus,
				'' AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.GameID3rd AS betteam,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				(-b.actual_stake) AS WinLost,
				0 AS commission,
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END creator,
				b.username,
				0 AS hthomescore,
				0 AS htawayscore,
				b.ip,
				CASE
					WHEN s.ProductID = 8 THEN 202
					WHEN s.ProductID = 12 THEN 255
					WHEN s.ProductID = 13 THEN 203
					WHEN s.ProductID = 15 THEN 204
					WHEN s.ProductID = 28 THEN 220
					ELSE 0
				END AS sporttype,
				0 AS MatchId,
				0 AS IsNeutral,
				'' AS showtime,
				0 AS awinlost,
				0 AS mwinlost,
				0 AS swinlost,
				b.betfrom,
				b.winlostdate,
				CASE
					WHEN s.ProductID = 15 THEN b.Tranid3rd
					WHEN s.ProductId = 8 THEN ISNULL(b.custom2, '')
					ELSE ''
				END AS betcheck,
				CASE
					WHEN s.ProductID IN (8, 28) THEN b.transdesc
					ELSE ''
				END AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.translog AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
			WHERE s.ProductID IN (8, 12, 13, 15, 28)
				AND b.winlostdate = @Date
				AND b.custid = @CustId
				AND b.statusID IN (0, 1)

			-- Bullfighting (EventType = 5) (translog)
			UNION ALL
			SELECT
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				0 AS OddsId,
				m.League3rdId AS LeagueId,
				b.gameid AS BetType,
				b.translogid AS TransId,
				0 AS BetId,
				b.translogid AS RefNo,
				m.MatchNo AS MatchCode,
				'' AS Race,
				'' AS EventDate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				m.HomeId,
				m.AwayId,
				'' AS checktime,
				CASE
					WHEN s.ProductID = 30 THEN CONVERT(SMALLMONEY, ISNULL(b.custom2, 0))
					ELSE 0
				END AS Hdp1,
				0 AS Hdp2,
				b.odds,
				0 AS MOdds,
				0 AS FinalOdds,
				0 AS FinalOdds2,
				CASE
					WHEN s.ProductID = 30 THEN CONVERT(TINYINT, ISNULL(b.custom1, 0))
					ELSE 0
				END AS OddsType,
				b.status,
				0 AS SettlementStatus,
				'' AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				CASE
					WHEN s.ProductID = 30 THEN ISNULL(b.custom3, '')
					ELSE ''
				END AS BetTeam,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				b.liveindicator,
				(-b.actual_stake) AS WinLost,
				0 AS commission,
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END creator,
				b.username,
				0 AS HtHomeScore,
				0 AS HtAwayScore,
				b.ip,
				m.SportType,
				CASE
					WHEN s.ProductID = 30 THEN b.eventid
					ELSE 0
				END AS MatchId,
				0 AS IsNeutral,
				'' AS showtime,
				0 AS awinlost,
				0 AS mwinlost,
				0 AS swinlost,
				b.betfrom,
				b.winlostdate,
				CASE
					WHEN s.ProductID = 30 THEN ISNULL(b.Tranid3rd, '')
					ELSE ''
				END AS BetCheck,
				CASE
					WHEN s.ProductID = 30 THEN ISNULL(b.transdesc, '')
					ELSE ''
				END AS TransDesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.translog AS b WITH (NOLOCK)
				INNER JOIN dbo.Match3rd AS m WITH (NOLOCK) ON b.eventid = m.Match3rdId
				INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
			WHERE s.ProductID = 30
				AND b.winlostdate = @Date
				AND b.custid = @CustId
				AND b.statusID IN (0, 1)

			-- Bullfighting (EventType = 5) (bettrans)
			UNION ALL
			SELECT
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				0 AS OddsId,
				m.League3rdId AS LeagueId,
				b.bettype,
				b.transid,
				ISNULL(b.betid, 0) AS BetId,
				b.refno,
				m.MatchNo AS MatchCode,
				'' AS Race,
				'' AS EventDate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				m.HomeId,
				m.AwayId,
				ISNULL(b.checktime, '') AS checktime,
				b.hdp1,
				0 AS Hdp2,
				b.odds,
				0 AS MOdds,
				0 AS FinalOdds,
				0 AS FinalOdds2,
				b.oddstype,
				b.status,
				0 AS SettlementStatus,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.betteam,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				b.liveindicator,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm AS commission,
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END creator,
				b.username,
				0 AS HtHomeScore,
				0 AS HtAwayScore,
				b.ip,
				m.SportType,
				b.matchid,
				0 AS IsNeutral,
				'' AS showtime,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.betfrom,
				b.winlostdate,
				ISNULL(b.betcheck, '') AS BetCheck,
				ISNULL(b.transdesc, '') AS TransDesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettrans AS b WITH (NOLOCK) 
				INNER JOIN dbo.Match3rd AS m WITH (NOLOCK) ON b.matchid = m.Match3rdId
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.winlostdate = @Date
				AND b.custid = @CustId
				AND s.EventType = 5

			-- Bullfighting (EventType = 5) (bettrans14)
			UNION ALL
			SELECT
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				0 AS OddsId,
				m.League3rdId AS LeagueId,
				b.bettype,
				b.transid,
				ISNULL(b.betid, 0) AS BetId,
				b.refno,
				m.MatchNo AS MatchCode,
				'' AS Race,
				'' AS EventDate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				m.HomeId,
				m.AwayId,
				ISNULL(b.checktime, '') AS checktime,
				b.hdp1,
				0 AS Hdp2,
				b.odds,
				0 AS MOdds,
				0 AS FinalOdds,
				0 AS FinalOdds2,
				b.oddstype,
				b.status,
				0 AS SettlementStatus,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.betteam,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				b.liveindicator,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm AS commission,
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END creator,
				b.username,
				0 AS HtHomeScore,
				0 AS HtAwayScore,
				b.ip,
				m.SportType,
				b.matchid,
				0 AS IsNeutral,
				'' AS showtime,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.betfrom,
				b.winlostdate,
				ISNULL(b.betcheck, '') AS BetCheck,
				ISNULL(b.transdesc, '') AS TransDesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettrans14 AS b WITH (NOLOCK) 
				INNER JOIN dbo.Match3rd14 AS m WITH (NOLOCK) ON b.matchid = m.Match3rdId
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.winlostdate = @Date
				AND b.custid = @CustId
				AND s.EventType = 5

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
				0 AS SettlementStatus,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				'' AS betteam,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm AS commission, 
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END AS creator,
				b.username,
				0 AS hthomescore,
				0 AS htawayscore,
				b.ip,
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
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				LEFT JOIN dbo.bettransm AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
			WHERE b.custid = @CustId
				AND b.winlostdate = @Date
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
				0 AS SettlementStatus,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.betteam,
				b.livehomescore,
				b.liveawayscore,
				0 AS liveindicator,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm AS commission,
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END creator,
				b.username,
				0 AS hthomescore,
				0 AS htawayscore,
				b.ip,
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
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				LEFT JOIN dbo.bettransm14 AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
			WHERE b.custid = @CustId
				AND b.winlostdate = @Date
				AND s.ProductID = 15

			-- Microgaming RNG Casino, RNG Casino Single Wallet, Voidbridge, Fishing World, Pragmatic Casino
			-- (before yesterday ticket)
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
				CASE
					WHEN s.ProductID = 6 THEN b.odds
					ELSE 0
				END AS Odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				b.status,
				0 AS SettlementStatus,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				'' AS betteam,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				(b.winlost - b.actual_stake) AS WinLost,
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
					WHEN s.ProductID = 24 THEN 219
					WHEN s.ProductID = 32 THEN 248
					ELSE 0
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
					WHEN s.ProductID IN (6, 22, 24) THEN b.transdesc
					ELSE ''
				END AS transdesc,
				CASE
					WHEN s.ProductID = 6 THEN ISNULL(b.oddsspread, 0)
					ELSE 0
				END AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate = @Date
				AND @Date < DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)	-- not yesterday and today
				AND s.ProductId IN (6, 17, 22, 24, 32)

			-- Microgaming RNG Casino, RNG Casino Single Wallet, Macau Games, Fishing World
			-- (yesterday and later running ticket)
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
				0 AS Odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				'Running' AS Status,
				0 AS SettlementStatus,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
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
					WHEN s.ProductID = 24 THEN 219
					WHEN s.ProductID = 32 THEN 248
					ELSE 0
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
					WHEN s.ProductID IN (6, 22, 24, 32) THEN b.transdesc
					ELSE ''
				END AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettransRnG AS brng WITH (NOLOCK)
				INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate = @Date
				AND @Date >= DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)	-- yesterday and later
				AND s.ProductId IN (6, 17, 22, 24, 32)
				AND brng.statusID IN (0, 1)
			GROUP BY
				b.transid,
				ISNULL(b.betid, 0),
				ISNULL(b.checktime, ''),
				b.Bettype,
				b.refno,
				b.transdate,
				b.winlostdate,
				b.custid,
				b.username,
				b.creator,
				b.ip,
				b.betfrom,
				b.comstatus,
				b.matchid,
				b.transdesc,
				s.ProductID

			-- Microgaming RNG Game, RNG Casino Single Wallet, Macau Games, Fishing World
			-- (yesterday and today settled ticket)
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
				CASE
					WHEN s.ProductID = 6
						THEN ISNULL(AVG(CASE WHEN brng.statusID IN (111, 112, 113) THEN brng.ContributionRate END), 0)
					ELSE 0
				END AS Odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				CASE
					WHEN SUM(brng.winlost - brng.actual_stake) > 0 THEN 'Won'
					WHEN SUM(brng.winlost - brng.actual_stake) < 0 THEN 'Lose'
					ELSE 'Draw'
				END AS Status,
				0 AS SettlementStatus,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
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
					WHEN s.ProductID = 24 THEN 219
					WHEN s.ProductID = 32 THEN 248
					ELSE 0
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
					WHEN s.ProductID IN (6, 22, 24, 32) THEN b.transdesc
					ELSE ''
				END AS transdesc,
				CASE
					WHEN s.ProductID = 6 THEN ISNULL(SUM(brng.BetStake), 0)
					ELSE 0
				END AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettransRnG AS brng WITH (NOLOCK)
				INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate = @Date
				AND @Date BETWEEN DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
					AND DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)		-- yesterday and today
				AND s.ProductId IN (6, 17, 22, 24, 32)
				AND brng.statusID NOT IN (0, 1)
			GROUP BY
				b.transid,
				ISNULL(b.betid, 0),
				ISNULL(b.checktime, ''),
				b.Bettype,
				b.refno,
				b.transdate,
				b.winlostdate,
				b.custid,
				b.username,
				b.creator,
				b.ip,
				b.betfrom,
				b.comstatus,
				b.matchid,
				b.transdesc,
				s.ProductID

			-- AG Casino, AllBet (before yesterday ticket)
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
				0 AS SettlementStatus,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				'' AS betteam,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm AS commission, 
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END AS creator,
				b.username,
				0 AS hthomescore,
				0 AS htawayscore,
				b.ip,
				CASE
					WHEN s.ProductID = 11 THEN 250
					WHEN s.ProductID = 21 THEN 211
					ELSE 0
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
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate = @Date
				AND @Date < DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)	-- not yesterday and today
				AND s.ProductID IN (11, 21)

			-- AG Casino, AllBet (yesterday and later running ticket)
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
				0 AS SettlementStatus,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
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
					ELSE 0
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
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettransLC AS blc WITH (NOLOCK)
				INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate = @Date
				AND @Date >= DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)	-- yesterday and later
				AND s.ProductID IN (11, 21)
				AND blc.statusID IN (0, 1)
			GROUP BY
				b.transid,
				ISNULL(b.betid, 0),
				ISNULL(b.checktime, ''),
				b.Bettype,
				b.refno,
				b.transdate,
				b.winlostdate,
				b.custid,
				b.username,
				b.creator,
				b.ip,
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
					WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
					WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
					ELSE 'Draw'
				END AS Status,
				0 AS SettlementStatus,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
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
					ELSE 0
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
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettransLC AS blc WITH (NOLOCK)
				INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate = @Date
				AND @Date BETWEEN DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
					AND DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)		-- yesterday and today
				AND s.ProductID IN (11, 21)
				AND blc.statusID NOT IN (0, 1)
			GROUP BY
				b.transid,
				ISNULL(b.betid, 0),
				ISNULL(b.checktime, ''),
				b.bettype,
				b.refno,
				b.transdate,
				b.winlostdate,
				b.custid,
				b.username,
				b.creator,
				b.ip,
				b.betfrom,
				b.currency,
				b.comstatus,
				s.ProductID
		) x
	WHERE ip = @ip
	ORDER BY 4, 26

	-- Get data for summary ticket of multiple Bonus/Cash sub tickets
	IF EXISTS (SELECT 1 FROM @Data WHERE RefCode <> 0)
	BEGIN
		DECLARE @RefCodeTmp TABLE (
			RefCode			BIGINT,
			TransId			BIGINT,
			Stake			MONEY,
			Actual_Stake	MONEY,
			WinLost			MONEY,
			Commission		MONEY,
			SWinLost		MONEY,
			MWinLost		MONEY,
			AWinLost		MONEY
		)

		-- Prepare temp table
		INSERT INTO @RefCodeTmp
		SELECT
			RefCode,
			MIN(TransId) AS TransId,
			SUM(Stake) AS Stake,
			SUM(Actual_Stake) AS Actual_Stake,
			SUM(WinLost) AS WinLost,
			SUM(Commission) AS Commission,
			SUM(SWinLost) AS SWinLost,
			SUM(MWinLost) AS MWinLost,
			SUM(AWinLost) AS AWinLost
		FROM @Data
		WHERE RefCode <> 0
		GROUP BY RefCode
		HAVING COUNT(*) > 1

		IF EXISTS (SELECT 1 FROM @RefCodeTmp)
		BEGIN
			-- Update data for summmary ticket
			UPDATE b
			SET
				b.Stake = r.Stake,
				b.Actual_Stake = r.Actual_Stake,
				b.WinLost = r.WinLost,
				b.Commission = r.Commission,
				b.SWinLost = r.SWinLost,
				b.MWinLost = r.MWinLost,
				b.AWinLost = r.AWinLost,
				b.WalletType = 0
			FROM @Data AS b
				INNER JOIN @RefCodeTmp AS r ON b.RefCode = r.RefCode AND b.TransId = r.TransId

			-- Delete 2nd Bonus/Cash tickets
			DELETE @Data
			WHERE WalletType <> 0
				AND RefCode IN (SELECT RefCode FROM @RefCodeTmp)
		END
	END

	-- Display detail link for ticket from Bonus Wallet only
	UPDATE @Data
	SET RefCode = TransId
	WHERE WalletType = 1 AND RefCode = 0

	-- Don't display Cash text for ticket from Cash Wallet only
	UPDATE @Data
	SET WalletType = 0
	WHERE WalletType = 2 AND RefCode = 0
	
	-- Get ticket detail
	DECLARE @DetailData TABLE (
		RefNo			NVARCHAR(50),
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(50),
		APositionTaking SMALLMONEY,
		MPositionTaking SMALLMONEY,
		SPositionTaking SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(50),
		TransDesc		VARCHAR(300)
	)

	-- Virtual Horse Racing
	IF EXISTS (	SELECT TOP(1) 1
				FROM @SportBettype AS sp
					INNER JOIN @Data AS d ON d.bettype = sp.bettype 
				WHERE sp.ProductID = 5 AND sp.EventType = 3)
	BEGIN
		INSERT INTO @DetailData
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
		FROM dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON bm.bettype = sp.Bettype
			INNER JOIN @Data AS b ON bm.refno = b.RefNo
		WHERE sp.ProductID = 5
			AND sp.EventType = 3
			AND bm.custid = @CustId

		INSERT INTO @DetailData
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
		FROM dbo.bettransm14 AS bm WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON bm.bettype = sp.Bettype
			INNER JOIN @Data AS b ON bm.refno = b.RefNo
		WHERE sp.ProductID = 5
			AND sp.EventType = 3
			AND bm.custid = @CustId
	END

	-- Gold Deluxe
	IF EXISTS (	SELECT TOP(1) 1
				FROM @SportBettype AS sp
					INNER JOIN @Data AS d ON d.bettype = sp.bettype 
				WHERE sp.ProductID = 12)
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
			INNER JOIN @SportBettype AS sp ON bg.bettype = sp.Bettype
			INNER JOIN @Data AS b ON bg.refno = b.TransId AND bg.bettype = b.bettype
		WHERE sp.ProductID = 12 AND bg.custid = @CustId

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
			INNER JOIN @SportBettype AS sp ON bg.bettype = sp.Bettype
			INNER JOIN @Data AS b ON bg.refno = b.TransId AND bg.bettype = b.bettype
		WHERE sp.ProductID = 12 AND bg.custid = @CustId
	END

	-- Get currency name
	DECLARE @CurrencyName NVARCHAR(50)

	SELECT @CurrencyName = ex.currency
	FROM dbo.custInfo AS ci WITH (NOLOCK)
		INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON ci.currency = ex.exchangeid
	WHERE ci.custid = @CustId

	SELECT *,
		@CurrencyName AS Currency
	FROM @Data
	ORDER BY 4, 26

	SELECT DISTINCT * FROM @DetailData
END







GO
GRANT EXECUTE ON [dbo].[Acc_BetListByIP_OtherSports] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BetListByIP_OtherSports] TO [vnteam]
GO
