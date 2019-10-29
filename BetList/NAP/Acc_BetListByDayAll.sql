/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetListByDayAll]
	@CustId			INT,
	@FromDate		SMALLDATETIME,
	@MoveBetsDay	DATETIME,
	@TransType		INT				= 0
AS

/*
	Created by: [Creator]
	Date: 2008
	Task: Bet list by date
	DB: DBAGE.bodb02
	
	Revisions:
		- 20081218@PhuongNguyen: Get Isneutral from Match
		- 20081223@PhuongNguyen: Get sdiscount, adiscount, discount, placing
		- 20081230@PhuongNguyen: Get livehomescore, liveawayscore, hdp1, hdp2 for Horse Racing
		- 20081231@PhuongNguyen: Remove placing
		- 20090109@PhuongNguyen: Get eventdate
		- 20090408@PhuongDao: Get checktime as SettleTime
		- 20090508@PhuongDao: Get username form bettrans and bettrans14 table
		- 20090509@Simon: Bet List For Casino
		- 20090528@PhuongDao: Add HR Fixed Odd
		- 20091002@Simon: Get Odds && OddsType columns
		- 20091003@Jamie: Remove comstatus out
		- 20091009@Daniel: Get refund status from bettrans
		- 20091015@Shifu: Get refno for Casino
		- 20091023@Simon: Displays Odds at Bet/Settle time
		- 20091205@Henry: Get more column: refno for viewing Mix Parlay detail
		- 20100306@Daniel: Query all @FromDate on winlostdate to support Finacial tickets
		- 20100409@Daniel: Support Mini game
		- 20100501@Daniel: Remove support Mini game
		- 20100524@Jamie: Show currency2's exchange rate for OpenTote
		- 20100603@Jamie: Change datatype transid to BIGINT
		- 20100611@Henry: Change mix-parlay match from 0 to 9
		- 20100907@Henry: Add IBC Bingo bettype
		- 20101007@Henry: Change column transid from INT to BIGINT
		- 20101130@Henry: Add column betid for number game
		- 20101201@Henry: Return winlost-actual_stake for column winlost
		- 20110408@Amy: Change function to get Odds value and odds type
		- 20110513@Lukas: re-arrange bettype
		- 20110705@Tom:Add new parameter @TransType and modify method get creator of the bet transaction
		- 20110711@Johnson: show exchange rate for SA Tote(Pool Currency)
		- 20110725@Lukas: Get refund tickets when transtype = 1
		- 20110802@Johnson: Add new bettype combination mix parlay
						- Add new column actual_stake for betlist
		- 20110810@Jamie: Get betteam for Combination Parlay
		- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
		- 20111207@Sophia: Add P2P
		- 20120120@Sophia: Add Showtime for Table-hand-shoe of Live Casino
							Add sub detail for Live Casino
		- 20120405@Hurri: Exclude bettype 72 (P2P bet ticket) in the calculation of Casino
		- 20120416@Johnson: Correct column transid for p2p
		- 20120423@Lukas: show transid of main ticket for all subticket of system parlay
		- 20120528@Lukas: return refno for matchcode column (temporarily fix)
		- 20120606@Sophia: Change datatype of stake to money
		- 20120626@Elodie: exclude outright, HR from sportbook ( in case of matchid = orid)
		- 20120629@Sophia: Remove function f_GetOddsByBettype, f_ShowOddsByBettype,f_GetChoice for odds, Oddstype, betteam
		- 20120927@Johnson: get commstatus column to check double comm losing
		- 20130227@Elodie: Add Virtual HR product
		- 20130625@Elodie: Not apply Virtual HR for bet list by IP yet at this time
		- 20130718@Elodie: Apply core betlist
		- 20140306@Dom: Add Keno
		- 20140908@Dom: Update VS conditions [#Redmine 22012]
		- 20141103@Dom: Apply sport bettype matrix
		- 20152001@Dom: Fix Bug Virtual HR condition
		- 20150415@Sophia: Get Betcheck for Betradar
		- 20150506@Tom: Support Gold Deluxe Product [#34847]
		- 20150506@Bobby: Add transdesc column for metric gaming bettypes (801-899)
		- 20150615@Edward: Support for BetTrade
		- 20150707@Bobby: Exclude Metric Gaming running ticket from bettrans table
		- 20150708@Edward: Support for Microgaming Live Casino
		- 20150825@Kos: Add OddsSpread column to support Myanmar Odds
		- 20150828@Kos: Support Colossus Bet
		- 20150828@Kos: Fix bug not show CB ticket after clicking Grand Prize in Statement report
		- 20151009@Kos: Support Microgaming RNG Casino and AG Casino
		- 20151019@Kos: Support Microgaming RNG Casino Jackpot Win
		- 20151022@Kos: Return [translog].[transid3rd] and [bettransm].[betcheck] to support view CB ticket detail
		- 20151030@Kos: Change ProductId/SportType of Microgaming RNG Casino
		- 20151109@Kos: Replace using Jackpotwin table by PayoutTrans table
		- 20151119@Kos: Use PayoutTrans table in DBACC instead of DBAGE
		- 20151210@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20151214@Kos: Support Cockfighting (#Redmine: 48850)
		- 20151229@Kos: Support Colossus Bet ticket flow change [Redmine: #49967]
		- 20151229@Kos: Support RNG Casino Single Wallet [Redmine: #48958]
		- 20160121@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160125@Kos: Fix Colossus Bet result issue
		- 20160129@Kos: Support RNG Casino Single Wallet yesterday running ticket
		- 20160215@Kos: Support AllBet [#Redmine: 50864]
		- 20160328@Kos: Support Grand Prize ticket which status is Expired
		- 20160331@Kos: Support Voidbridge [#Redmine: 54925]
		- 20160407@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20160711@Kos: Change to use inline function for SportBettypeMatrix
		- 20160801@Kos: Fix bug not showing summary tickets if have only Void/Reject detail tickets [#Redmine: 61651]
		- 20160804@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20160810@Kos: Support NG2
		- 20161019@Kos: Remove Bingo and P2P in bettrans and bettrans14 range [#Redmine: 53988]
					- Support Fishing World [#Redmine: 65934]
		- 20170209@Kos: Statement - Unable to show NG2 betlist [#Redmine: 71344]
		- 20170228@Kos: Support KickOffTime for Virtual Soccer and Virtual Tennis [#Redmine: 71906]
		- 20170315@Kos: Support CashOut [#Redmine: 71963]
		- 20170602@Kos: Get liveindicator from original ticket for 911 and 912 tickets [#Redmine: 77669]
		- 20170616@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20170629@Kos: Support Keno Lottery [#Redmine: 77929]
		- 20170718@Kos: Don't parse transdesc for Keno anymore [#Redmine: 80082]
		- 20170829@Kos: Support Lucky 3 [#Redmine: 75277]
		- 20171024@Kos: Support Bullfighting [#Redmine: 84961]
		- 20171227@Kos: Return ticket detail of Racing and Virtual Horse Racing [#Redmine: 88775]
					- Don't support Live Casino in bettrans and bettrans14 anymore
		- 20180118@Kos: Support Licensee Bonus System [#Redmine: 74978]
		- 20180305@Kos: Don't support Racing, Cockfighting, RNG Casino (bettype 71, 72) anymore [#Redmine: 86086]	
		- 20180323@Kos: Support ONERnG Jackpot [#Redmine: 88652]
		- 20180405@Kos: Support Pragmatic Casino [#Redmine: 92160]
		- 20180509@Kos: Support Keno 6 new Mini Games [#Redmine: 93759]
		- 20180515@Kos: Add Match No for Bullfighting [#Redmine: 84961]
		- 20180709@Kos: Support Poker Games [#Redmine: 97565]
		- 20180910@Kos: HotFix - Missing Seat # in Poker Games [#Redmine: 101215]
		- 20181003@Helen: Modify code to adapt indexes changed on DB053 [Redmine:101405]
		- 20181011@Kos: Support new status Result Pending and Under Settlement [#Redmine: 101949]
		- 20190107@Kos: Support Parlay Changes [#Redmine: 105585]
		- 20190503@Kos: Show match KO time for single ticket [#Redmine: 112092]
		- 20190611@Kos: Support Card Club [#Redmine: 107645]
					- Don't support Poker Games anymore
					- Remove param @Language, @TransId
		- 20190722@Kos: Support new status Pending [#Redmine: 113142]
		- 20190919@Kos: Hotfix - Wrong match showtime of Cash Out ticket [#Redmine: 120242]
		- 20190924@Kos: Don't support inactive products anymore [Redmine: #119100]
		- 20191029@Kos: Show Running status for Marked tickets [Redmine: 122391]

	Param's Explanation:
		+ @TransType:
			1: Betting Statement
			2: Void/Cancelled Bet
			3: Outstanding Bet
			4: Grand Prize (Colossus Bet)
*/

BEGIN
	SET NOCOUNT ON;

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE Bettype NOT IN (904, 914)
		AND ProductID NOT IN (2, 4, 7, 9, 13, 17, 19, 26, 30, 31, 33)
		AND (ProductID <> 6 OR SubProduct <> '')

	DECLARE @tmpStatus TABLE ([statusID] TINYINT);

	IF @TransType = 1
	BEGIN
		INSERT INTO @tmpStatus ([statusID])
		SELECT 111 UNION ALL
		SELECT 112 UNION ALL
		SELECT 113 UNION ALL
		SELECT 103
	END
	ELSE IF @TransType = 2
	BEGIN
		INSERT INTO @tmpStatus ([statusID])
		SELECT 101 UNION ALL
		SELECT 102
	END
	ELSE IF @TransType = 3
	BEGIN
		INSERT INTO @tmpStatus ([statusID])
		SELECT 0 UNION ALL
		SELECT 1
	END
	ELSE IF @TransType = 4	-- Grand Prize of ONERnG Jackpot, Colossus Bet
	BEGIN
		INSERT INTO @tmpStatus ([statusID])
		SELECT 111 UNION ALL
		SELECT 112 UNION ALL
		SELECT 113

		DELETE @SportBettype
		WHERE ProductID NOT IN (6, 15)
	END

	DECLARE @Data TABLE (
		SportType			INT,
		LeagueId			INT,
		HomeId				INT,
		AwayId				INT,
		MatchCode			NVARCHAR(50),
		Race				NVARCHAR(50),
		EventDate			DATETIME,
		VirtualRate			FLOAT,			-- in case OpenToe, it's currency2's exchange rate 
		IsShowOTExRate		BIT,			-- Show OpenTote currency2's exchange rate or not 
		SDiscount			DECIMAL(9, 8),
		ADiscount			DECIMAL(9, 8),
		Discount			DECIMAL(9, 8),
		SettleTime			DATETIME,
		MatchId				INT,
		TransId				BIGINT,
		BetId				BIGINT,
		RefNo				BIGINT,
		TransDate			DATETIME,
		OddsId				INT,
		BetType				SMALLINT,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
		MOdds				MONEY,
		FinalOdds			MONEY,
		FinalOdds2			MONEY,
		OddsType			INT,
		BetTeam				NVARCHAR(50),
		Status				NVARCHAR(50),
		SettlementStatus	TINYINT,
		BetStatus			NVARCHAR(50),
		ComStatus			NVARCHAR(50),
		Stake				MONEY,
		Actual_Stake		MONEY,
		WinLost				MONEY,
		Commission			MONEY,
		LiveHomeScore		INT,
		LiveAwayScore		INT,
		LiveIndicator		BIT,
		FinalHomeScore		INT,
		FinalAwayScore		INT,
		HtHomeScore			INT,
		HtAwayScore			INT,
		Creator				VARCHAR(50),
		Ip					NVARCHAR(15),
		Username			VARCHAR(50),
		IsNeutral			BIT,
		ShowTime			NVARCHAR(50),
		SPositionTaking		SMALLMONEY,
		MPositionTaking		SMALLMONEY,
		APositionTaking		SMALLMONEY,
		SPositionTaking2	SMALLMONEY,
		MPositionTaking2	SMALLMONEY,
		APositionTaking2	SMALLMONEY,
		BetFrom				NVARCHAR(1),
		SComm				MONEY,
		AComm				MONEY,
		Comm				MONEY,
		AWinLost			MONEY,
		MWinLost			MONEY,
		SWinLost			MONEY,
		WinLostDate			SMALLDATETIME,
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		OddsSpread			MONEY,
		OriginalBetType		INT,
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		WalletType			TINYINT,
		RefCode				BIGINT
	);

	IF @Fromdate <= @MoveBetsDay
	BEGIN
		IF @TransType <> 4
		BEGIN
			/* normal tickets
				- Sportsbook		: ProductID = 1
				- Number Game		: ProductID = 3
				- Virtual Sports	: ProductID = 5
				- Cash Out			: ProductID = 25
			*/
			INSERT INTO @Data
			SELECT
				m.sporttype,
				m.leagueid,
				m.homeid,
				m.awayid,
				m.matchcode,
				'' AS race,
				CASE
					WHEN s.ProductID IN (1, 25) THEN m.GlobalShowTime
					ELSE m.eventdate
				END AS EventDate,
				0,
				0,
				b.sdiscount,
				b.adiscount,
				b.discount,
				ISNULL(b.checktime, '') AS settletime,
				m.matchid,
				b.transid,
				ISNULL(b.BetID, 0),
				b.refno,
				b.transdate,
				b.oddsid,
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				0 AS finalodds,
				0 AS finalodds2,
				b.oddstype,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				m.betstatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm,
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator,
				m.finalhomescore,
				m.finalawayscore,
				m.hthomescore,
				m.htawayscore,
				b.creator,
				b.ip,
				b.Username,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				CASE
					WHEN s.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
					ELSE m.showtime
				END AS ShowTime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				b.betfrom,
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.winlostdate,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				0 AS OriginalBetType,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b.betdaqid, -1)
					ELSE -1
				END AS BetdaqId,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b.ExtraInfo, '')
					ELSE ''
			END AS ExtraInfo,
			CASE
				WHEN s.ProductID = 1 THEN ISNULL(b.WalletType, 0)
				ELSE 0
			END AS WalletType,
			CASE
				WHEN s.ProductID = 1 THEN ISNULL(b.RefCode, 0)
				ELSE 0
			END AS RefCode
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND s.EventType = 1
				AND b.statusID IN (SELECT statusID FROM @tmpStatus)

			-- Mix Parlay, System Parlay, Mix Parlay (Betradar Virtual Sports)
			INSERT INTO @Data
			SELECT
				0,
				0,
				0,
				0,
				'',
				'' AS race,
				'' AS eventdate,
				0,
				0,
				b.sdiscount,
				b.adiscount,
				b.discount,
				ISNULL(b.checktime, '') AS settletime,
				0 AS MatchId,
				CASE
					WHEN b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
					ELSE b.transid
				END AS TransId,
				ISNULL(b.betid, 0),
				b.refno,
				b.transdate,
				0,
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				0 AS finalodds,
				0 AS finalodds2,
				'' AS oddstype,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				'' AS betstatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm,
				0,
				0,
				0,
				0,
				0,
				0,
				0,
				b.creator,
				b.ip,
				b.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				'' AS showtime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				b.betfrom,
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				b.awinlost,
				b.mwinlost,
				b.swinlost,
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
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND b.matchid IN (9, 29, 2799)
				AND b.bettype IN (9, 29, 2799)
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus);

			-- Outright
			INSERT INTO @Data
			SELECT
				l.sporttype,
				o.leagueid,
				o.teamid,
				0,
				o.matchcode,
				o.groupmatch AS race,
				o.eventdate,
				b.virtualrate,
				CASE WHEN b.currency2 IS NULL THEN CONVERT(BIT,0) ELSE CONVERT(BIT,1) END AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				ISNULL(b.checktime, '') AS settletime,
				'',
				b.transid,
				ISNULL(b.betid, 0),
				b.refno,
				b.transdate,
				o.orid,
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				0 AS FinalOdds,
				0 AS FinalOdds2,
				0 AS oddstype,
				'',
				b.status,
				0 AS SettlementStatus,
				'',
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm,
				b.livehomescore,
				b.liveawayscore,
				0,
				0,
				0,
				0,
				0,
				b.creator,
				b.ip,
				b.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				'' AS showtime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				b.betfrom,
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.winlostdate,
				b.BetCheck,
				'' AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.matchid = o.orid
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
			WHERE b.custid = @CustId
				AND b.bettype = 10
				AND b.winlostdate = @FromDate
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus);

			-- Virtual Horse Racing
			INSERT INTO @Data
			SELECT
				r.SportType,
				r.LeagueID,
				o.RacerID AS homeid,
				0 AS awayid,
				o.RacerNum AS matchcode,
				b.oddsid AS Race,
				o.EventDate,
				0,
				0,
				b.sdiscount,
				b.adiscount,
				b.discount,
				ISNULL(b.checktime, '') AS settletime,
				b.matchid,
				b.transid,
				ISNULL(b.BetID, 0),
				b.refno,
				b.transdate,
				b.oddsid,
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				0 AS finalodds,
				0 AS finalodds2,
				b.oddstype,
				'' AS betteam,
				b.status,
				0 AS SettlementStatus,
				'' AS betstatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm,
				b.livehomescore,
				b.liveawayscore,
				0 AS liveindicator,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS hthomescore,
				0 AS htawayscore,
				b.creator,
				b.ip,
				b.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				CONVERT(NVARCHAR(50), r.EventTime) AS ShowTime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				b.betfrom,
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.winlostdate,
				b.BetCheck,
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
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND s.ProductID = 5
				AND s.EventType = 3
				AND b.statusID IN (SELECT statusID FROM @tmpStatus)

			-- RNG Casino, Keno, Gold Deluxe, AG Casino, AllBet, Voidbridge, NG2, Fishing World, Lottery, Pragmatic Casino, Card Club
			INSERT INTO @Data
			SELECT
				CASE
					WHEN s.ProductID = 6 THEN b.matchid
					WHEN s.ProductID = 8 THEN 202
					WHEN s.ProductID = 11 THEN 250
					WHEN s.ProductID = 12 THEN 255
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
					WHEN s.ProductID = 34 THEN b.matchid
					ELSE 0
				END AS SportType,
				0 AS leagueid,
				0 AS homeid,
				0 AS awayid,
				'' AS matchcode,
				'' AS race,
				'' AS eventdate,
				0,
				0,
				b.sdiscount,
				b.adiscount,
				b.discount,
				ISNULL(b.checktime, '') AS settletime,
				CASE
					WHEN s.ProductID = 12 THEN b.matchid
					WHEN s.ProductId = 23 THEN b.betdaqid
					ELSE 0
				END AS MatchID,
				b.transid,
				ISNULL(b.betid, 0),
				b.refno,
				b.transdate,
				b.oddsid,
				b.bettype,
				CASE
					WHEN s.ProductId = 23 THEN b.hdp1
					ELSE 0
				END AS hdp1,
				CASE
					WHEN s.ProductId = 23 THEN b.hdp2
					ELSE 0
				END AS hdp2,
				CASE 
					WHEN s.ProductID IN (6, 8, 12, 23, 28) THEN b.Odds
					ELSE 0 
				END AS Odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				'' AS betteam,
				b.status,
				0 AS SettlementStatus,
				'' AS betstatus,
				'' AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm,
				CASE
					WHEN s.ProductId = 23 THEN b.livehomescore
					ELSE 0
				END AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS hthomescore,
				0 AS htawayscore,
				b.creator,
				b.ip,
				b.Username,
				0 AS IsNeutral,
				'' AS showtime,
				0 AS spositiontaking, -- unuse in this report
				0 AS mpositiontaking, -- unuse in this report
				0 AS apositiontaking, -- unuse in this report
				0 AS spositiontaking2,-- unuse in this report
				0 AS mpositiontaking2,-- unuse in this report
				0 AS apositiontaking2,-- unuse in this report
				b.betfrom,
				0 AS scomm, -- unuse in this report
				0 AS acomm, -- unuse in this report
				0 AS comm,	-- unuse in this report
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.winlostdate,
				CASE
					WHEN s.ProductID = 12 THEN b.betcheck
					WHEN s.ProductId = 8 THEN ISNULL(b.comstatus, '')
					ELSE ''
				END AS betcheck,
				CASE
					WHEN s.ProductId IN (6, 8, 22, 23, 24, 28, 32, 34) THEN b.transdesc
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
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND s.ProductID IN (6, 8, 11, 12, 21, 22, 23, 24, 28, 32, 34)
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus);

			-- Colossus Bet
			INSERT INTO @Data
			SELECT
				204 AS SportType,
				0 AS leagueid,
				0 AS homeid,
				0 AS awayid,
				'' AS matchcode,
				'' AS race,
				'' AS eventdate,
				0,
				0,
				b.sdiscount,
				b.adiscount,
				b.discount,
				ISNULL(b.checktime, '') AS settletime,
				0 AS matchid,
				b.transid,
				ISNULL(b.betid, 0),
				b.refno,
				b.transdate,
				b.oddsid,
				b.bettype,
				0 AS hdp1,
				0 AS hdp2,
				0 AS odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS oddstype,
				'' AS betteam,
				b.status,
				0 AS SettlementStatus,
				'' AS betstatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0, --finalhomescore
				0, --finalawayscore
				0, --hthomescore
				0, --htawayscore
				b.creator,
				b.ip,
				b.Username,
				0 AS IsNeutral,
				'' AS showtime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				b.betfrom,
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				b.awinlost,
				b.mwinlost,
				b.swinlost,
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
				AND b.winlostdate = @FromDate
				AND s.ProductID = 15
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

			-- Get more info for BetTrade tickets
			IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType IN (901, 902))
			BEGIN
				UPDATE betList
				SET betList.Odds = originBetList.odds,
					betList.Stake = originBetList.stake,
					betList.LiveHomeScore = originBetList.livehomescore,
					betList.LiveAwayScore = originBetList.liveawayscore,
					betList.Comm = CASE
										WHEN betList.BetType = 902 THEN ISNULL(commBetList.AWinLost, 0)
										ELSE betList.Comm
									END,
					betList.BetId = originBetList.bettype
				FROM @Data AS betList
					INNER JOIN dbo.bettrans14 AS originBetList WITH (NOLOCK) ON betList.RefNo = originBetList.transid
					LEFT JOIN @Data AS commBetList ON betList.RefNo = commBetList.RefNo AND commBetList.BetType = 903
				WHERE betList.Sporttype = 1 AND betList.BetType IN (901, 902)
			END

			-- Get more info for CashOut tickets
			IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 911)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.LiveIndicator = ob.liveindicator,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.OriginalBetType = ob.bettype,
					b.BetdaqId = ob.transid
				FROM @Data AS b
					INNER JOIN dbo.bettrans14 AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
				WHERE b.BetType = 911
			END

			IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 912)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.LiveIndicator = ob.liveindicator,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.OriginalBetType = ob.bettype,
					b.BetdaqId = ob.transid,
					b.Stake = cob.stake,
					b.Comm = ISNULL(cb.AWinLost, 0)
				FROM @Data AS b
					INNER JOIN dbo.bettrans14 AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
					INNER JOIN dbo.bettrans14 AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
					LEFT JOIN @Data AS cb ON b.RefNo = cb.RefNo AND cb.BetType = 913
				WHERE b.BetType = 912
			END
		END

		-- Grand Prize Jackpot Win
		IF @TransType = 4
		BEGIN
			-- ONERnG Jackpot
			INSERT INTO @Data
			SELECT
				CASE
					WHEN s.ProductID = 6 THEN b.productID
					ELSE 0
				END AS SportType,
				0 AS leagueid,
				0 AS homeid,
				0 AS awayid,
				'' AS matchcode,
				'' AS race,
				'' AS eventdate,
				0,
				0,
				0 AS sdiscount,
				0 AS adiscount,
				0 AS discount,
				'' AS settletime,
				0 AS matchid,
				b.transid,
				0 AS BetId,
				b.RefNo,
				b.transdate,
				0 AS oddsid,
				b.gameID AS BetType,
				0 AS hdp1,
				0 AS hdp2,
				b.odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS oddstype,
				'' AS betteam,
				b.status,
				0 AS SettlementStatus,
				'' AS betstatus,
				0 AS comstatus,
				b.stake,
				b.actual_stake,
				CASE
					WHEN s.ProductID = 6 THEN (b.winlost - b.actual_stake)
					ELSE 0
				END AS WinLost,
				CASE
					WHEN s.ProductID = 6 THEN b.playercomm
					ELSE 0
				END AS PlayerComm,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS hthomescore,
				0 AS htawayscore,
				b.creator,
				b.ip,
				b.Username,
				0 AS IsNeutral,
				'' AS showtime,
				0 AS spositiontaking, -- unuse in this report
				0 AS mpositiontaking, -- unuse in this report
				0 AS apositiontaking, -- unuse in this report
				0 AS spositiontaking2,-- unuse in this report
				0 AS mpositiontaking2,-- unuse in this report
				0 AS apositiontaking2,-- unuse in this report
				b.betfrom,
				0 AS scomm, -- unuse in this report
				0 AS acomm, -- unuse in this report
				0 AS comm,	-- unuse in this report
				0 AS awinlost,
				0 AS mwinlost,
				0 AS swinlost,
				pt.winlostdate,
				b.TranId3rd AS BetCheck,
				b.transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				CASE
					WHEN s.ProductID = 6 THEN ISNULL(b.RefNo2, -1)
					ELSE -1
				END AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM DBACC.bodb02.dbo.PayoutTrans AS pt WITH (NOLOCK)
				INNER JOIN dbo.bettransRnG14 AS b WITH (NOLOCK) ON pt.RefNo = b.transid
				INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
			WHERE pt.custid = @CustId
				AND pt.winlostdate = @FromDate
				AND (s.ProductID = 6 AND pt.PayoutStatus IN ('Completed', 'Expired'))
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

			-- Colossus Bet
			INSERT INTO @Data
			SELECT 
				204, --sporttype,
				0 AS leagueid,
				0 AS homeid,
				0 AS awayid,
				'' AS matchcode,
				'' AS race,
				'' AS eventdate,
				0,
				0,
				b.sdiscount,
				b.adiscount,
				b.discount,
				ISNULL(b.checktime, '') AS settletime,
				0 AS matchid,
				b.transid,
				ISNULL(b.BetID, 0),
				b.refno,
				b.transdate,
				b.oddsid,
				b.bettype,
				0 AS hdp1,
				0 AS hdp2,
				0 AS odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				'' AS oddstype,
				'' AS betteam,
				b.status,
				0 AS SettlementStatus,
				'' AS betstatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm,
				b.livehomescore,
				b.liveawayscore,
				0 AS liveindicator,
				0, --finalhomescore,
				0, --finalawayscore,
				0, --hthomescore,
				0, --htawayscore,
				b.creator,
				b.ip,
				b.Username,
				0 AS IsNeutral,
				'' AS showtime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				b.betfrom,
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				b.awinlost,
				b.mwinlost,
				b.swinlost,
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
				AND b.winlostdate = @FromDate
				AND s.ProductID = 15
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
				AND EXISTS (	SELECT 1 
								FROM DBACC.bodb02.dbo.PayoutTrans AS pt WITH (NOLOCK)
								WHERE pt.refno = b.transid AND pt.PayoutStatus IN ('Completed', 'Expired'))
		END
	END
	ELSE
	BEGIN
		IF @TransType <> 4
		BEGIN
			/* normal tickets
				- Sportsbook		: ProductID = 1
				- Number Game		: ProductID = 3
				- Virtual Sports	: ProductID = 5
				- Cash Out			: ProductID = 25
			*/
			INSERT INTO @Data
			SELECT
				m.sporttype,
				m.leagueid,
				m.homeid,
				m.awayid,
				m.matchcode,
				'' AS race,
				CASE
					WHEN s.ProductID IN (1, 25) THEN m.GlobalShowTime
					ELSE m.eventdate
				END AS EventDate,
				0,
				0,
				b.sdiscount,
				b.adiscount,
				b.discount,
				ISNULL(b.checktime, '') AS settletime,
				m.matchid,
				b.transid,
				ISNULL(b.betid, 0),
				b.refno,
				b.transdate,
				b.oddsid,
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				0 AS finalodds,
				0 AS finalodds2,
				b.oddstype,
				b.betteam,
				CASE
					WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.status
				END AS status,
				ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
				m.betstatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm,
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator,
				m.finalhomescore,
				m.finalawayscore,
				m.hthomescore,
				m.htawayscore,
				b.creator,
				b.ip,
				b.Username,
				ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral, --phuong.nguyen, get isneutral from Match
				CASE
					WHEN s.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
					ELSE m.showtime
				END AS ShowTime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				b.betfrom,
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.winlostdate,
				b.BetCheck,
				ISNULL(b.transdesc, '') AS transdesc,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				0 AS OriginalBetType,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b.betdaqid, -1)
					ELSE -1
				END AS BetdaqId,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b.ExtraInfo, '')
					ELSE ''
			END AS ExtraInfo,
			CASE
				WHEN s.ProductID = 1 THEN ISNULL(b.WalletType, 0)
				ELSE 0
			END AS WalletType,
			CASE
				WHEN s.ProductID = 1 THEN ISNULL(b.RefCode, 0)
				ELSE 0
			END AS RefCode
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND s.EventType = 1
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
				AND (b.bettype NOT BETWEEN 801 AND 806			--exclude metric gaming running ticket
					OR (b.bettype BETWEEN 801 AND 806 AND b.statusID NOT IN (0, 1)))

			-- Metric gaming running ticket
			UNION ALL
			SELECT 
				m.sporttype,
				m.leagueid,
				m.homeid,
				m.awayid,
				m.matchcode,
				'' AS race,
				m.GlobalShowTime AS EventDate,
				0,
				0,
				b.sdiscount,
				b.adiscount,
				b.discount,
				'' AS settletime,
				m.matchid,
				b.translogid AS transid,
				0 AS BetID,
				b.translogid AS refno,
				b.transdate,
				0 AS oddsid,
				b.gameID AS bettype,
				0 AS hdp1,
				0 AS hdp2,
				b.odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				CASE
					WHEN b.gameid IN (801, 803, 804, 805, 806) THEN CONVERT(TINYINT, ISNULL(b.custom1, 0))
					ELSE 0
				END AS OddsType,
				'' AS betteam,
				b.status,
				ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
				m.betstatus,
				0 AS comstatus,
				b.stake,
				b.actual_stake,
				0 AS WinLost,
				0 AS playercomm,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				m.finalhomescore,
				m.finalawayscore,
				m.hthomescore,
				m.htawayscore,
				b.creator,
				b.ip,
				b.Username,
				ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral, --phuong.nguyen, get isneutral from Match
				m.showtime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				b.betfrom,
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				0 AS awinlost,
				0 AS mwinlost,
				0 AS swinlost,
				b.winlostdate,
				'' AS BetCheck,
				b.transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM
				dbo.translog AS b WITH (NOLOCK)
				INNER JOIN dbo.custInfo AS c WITH (NOLOCK) ON c.custid = b.creator
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.eventid = m.matchid
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND b.gameID BETWEEN 801 AND 899
				AND b.statusID IN (0,1)
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus WHERE statusID IN (0, 1))

			-- Mix Parlay, System Parlay, Mix Parlay (Betradar Virtual Sports)
			INSERT INTO @Data
			SELECT 
				0,
				0,
				0,
				0,
				'',
				'' AS race,
				'' AS eventdate,
				0,
				0,
				b.sdiscount,
				b.adiscount,
				b.discount,
				ISNULL(b.checktime, '') AS settletime,
				0 AS MatchId,
				CASE
					WHEN b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
					ELSE b.transid
				END AS TransId,
				ISNULL(b.betid, 0),
				b.refno,
				b.transdate,
				0,
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				0 AS finalodds,
				0 AS finalodds2,
				'' AS oddstype,
				b.betteam,
				CASE
					WHEN b.status = 'running' THEN
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
				0 AS SettlementStatus,
				'' AS betstatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm,
				0,
				0,
				0,
				0,
				0,
				0,
				0,
				b.creator,
				b.ip,
				b.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				'' AS showtime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				b.betfrom,
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				b.awinlost,
				b.mwinlost,
				b.swinlost,
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
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND b.matchid IN (9, 29, 2799)
				AND b.bettype IN (9, 29, 2799)
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus);

			-- Outright
			INSERT INTO @Data
			SELECT 
				l.sporttype,
				o.leagueid,
				o.teamid,
				0,
				o.matchcode,
				o.groupmatch AS race,
				o.eventdate,
				b.virtualrate,
				CASE WHEN b.currency2 IS NULL THEN CONVERT(BIT,0) ELSE CONVERT(BIT,1) END AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				'' AS settletime,
				'',
				b.transid,
				ISNULL(b.betid, 0),
				b.refno,
				b.transdate,
				o.orid,
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				0 AS FinalOdds,
				0 AS FinalOdds2,
				0 AS oddstype,
				'',
				b.status,
				0 AS SettlementStatus,
				'',
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm,
				b.livehomescore,
				b.liveawayscore,
				0,
				0,
				0,
				0,
				0,
				b.creator,
				b.ip,
				b.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				'' AS showtime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				b.betfrom,
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.winlostdate,
				b.BetCheck,
				'' AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.outright AS o WITH (NOLOCK) ON b.matchid = o.orid
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
			WHERE b.custid = @CustId
				AND b.bettype = 10
				AND b.winlostdate = @FromDate
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus);

			-- Virtual Horse Racing
			INSERT INTO @Data
			SELECT 
				r.SportType,
				r.LeagueID,
				o.RacerID AS homeid,
				0 AS awayid,
				o.RacerNum AS matchcode,
				b.oddsid AS Race,
				o.EventDate,
				0,
				0,
				b.sdiscount,
				b.adiscount,
				b.discount,
				ISNULL(b.checktime, '') AS settletime,
				b.matchid,
				b.transid,
				ISNULL(b.BetID, 0),
				b.refno,
				b.transdate,
				b.oddsid,
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				0 AS finalodds,
				0 AS finalodds2,
				b.oddstype,
				'' AS betteam,
				b.status,
				0 AS SettlementStatus,
				'' AS betstatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm,
				b.livehomescore,
				b.liveawayscore,
				0 AS liveindicator,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS hthomescore,
				0 AS htawayscore,
				b.creator,
				b.ip,
				b.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				CONVERT(NVARCHAR(50), r.EventTime) AS ShowTime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				b.betfrom,
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.winlostdate,
				b.BetCheck,
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
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND s.ProductID = 5
				AND s.EventType = 3
				AND b.statusID IN (SELECT statusID FROM @tmpStatus)

			-- NG2
			INSERT INTO @Data
			SELECT
				CASE
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2501 AND 2539 THEN 213
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2541 AND 2579 THEN 214
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2581 AND 2619 THEN 215
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2621 AND 2659 THEN 216
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2681 AND 2699 THEN 218
					ELSE 0
				END AS SportType,
				0 AS leagueid,
				0 AS homeid,
				0 AS awayid,
				'' AS matchcode,
				'' AS race,
				'' AS eventdate,
				0,
				0,
				b.sdiscount,
				b.adiscount,
				b.discount,
				'' AS settletime,
				CASE
					WHEN s.ProductId = 23 THEN b.betdaqid
					ELSE 0
				END AS matchid,
				b.transid,
				ISNULL(b.betid, 0),
				b.refno,
				b.transdate,
				b.oddsid,
				b.bettype,
				CASE
					WHEN s.ProductId = 23 THEN b.hdp1
					ELSE 0
				END AS hdp1,
				CASE
					WHEN s.ProductId = 23 THEN b.hdp2
					ELSE 0
				END AS hdp2,
				b.odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS oddstype,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				'' AS betstatus,
				'' AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm,
				CASE
					WHEN s.ProductId = 23 THEN b.livehomescore
					ELSE 0
				END AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0, --finalhomescore, 
				0, --finalawayscore, 
				0, --hthomescore, 
				0, --htawayscore,
				b.creator,
				b.ip,
				b.Username,
				0 AS IsNeutral,
				'' AS showtime,
				0 AS spositiontaking, -- unuse in this report
				0 AS mpositiontaking, -- unuse in this report
				0 AS apositiontaking, -- unuse in this report
				0 AS spositiontaking2,-- unuse in this report
				0 AS mpositiontaking2,-- unuse in this report
				0 AS apositiontaking2,-- unuse in this report
				b.betfrom,
				0 AS scomm, -- unuse in this report
				0 AS acomm, -- unuse in this report
				0 AS comm,	-- unuse in this report
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.winlostdate,
				'' AS BetCheck,
				CASE
					WHEN s.ProductId = 23 THEN ISNULL(b.transdesc, '')
					ELSE ''
				END AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND s.ProductId = 23
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus);

			-- Keno, Gold Deluxe, Colossus Bet, Lottery (translog)
			IF EXISTS (SELECT TOP(1) 1 FROM @tmpStatus WHERE statusID IN (0, 1))
			BEGIN
				INSERT INTO @Data
				SELECT 
					CASE
						WHEN s.ProductId = 8 THEN 202
						WHEN s.ProductId = 12 THEN 255
						WHEN s.ProductId = 15 THEN 204
						WHEN s.ProductID = 28 THEN 220
						ELSE 0
					END AS sporttype,
					0 AS leagueid,
					0 AS homeid,
					0 AS awayid,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					b.sdiscount,
					b.adiscount,
					b.discount,
					'' AS settletime,
					0 AS MatchId,
					0 AS transid,
					0 AS betid,
					b.translogid AS refno,
					b.transdate,
					0 AS oddsid,
					b.gameID AS bettype,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductId IN (8, 12, 28) THEN b.odds
						ELSE 0
					END AS odds,
					0 AS modds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					CASE
						WHEN s.ProductId = 12 THEN b.GameID3rd
						ELSE ''
					END AS betteam,
					b.status,
					0 AS SettlementStatus,
					'' AS betstatus,
					0 AS comstatus,
					b.stake,
					b.actual_stake,
					0 AS WinLost,
					0 AS playercomm,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS hthomescore,
					0 AS htawayscore,
					b.creator,
					b.ip,
					b.Username,
					0 AS IsNeutral,
					'' AS showtime,
					0 AS spositiontaking, -- unuse in this report
					0 AS mpositiontaking, -- unuse in this report
					0 AS apositiontaking, -- unuse in this report
					0 AS spositiontaking2,-- unuse in this report
					0 AS mpositiontaking2,-- unuse in this report
					0 AS apositiontaking2,-- unuse in this report
					b.betfrom,
					0 AS scomm, -- unuse in this report
					0 AS acomm, -- unuse in this report
					0 AS comm,	-- unuse in this report
					0 AS awinlost,
					0 AS mwinlost,
					0 AS swinlost,
					b.winlostdate,
					CASE
						WHEN s.ProductId = 12 THEN b.GameID3rd
						WHEN s.ProductId = 15 THEN b.Tranid3rd
						WHEN s.ProductId = 8 THEN ISNULL(b.custom2, '')
						ELSE ''
					END AS BetCheck,
					CASE
						WHEN s.ProductId IN (8, 28) THEN b.transdesc
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
				WHERE b.custid = @CustId
					AND b.winlostdate = @FromDate
					AND s.ProductID IN (8, 12, 15, 28)
					AND b.statusID IN (0, 1)
			END

			-- Keno, Gold Deluxe, Lottery (bettrans)
			IF EXISTS (SELECT TOP(1) 1 FROM @tmpStatus WHERE statusID NOT IN (0, 1))
			BEGIN
				INSERT INTO @Data
				SELECT
					CASE
						WHEN s.ProductId = 8 THEN 202
						WHEN s.ProductId = 12 THEN 255
						WHEN s.ProductID = 28 THEN 220
						ELSE 0
					END AS sporttype,
					0 AS leagueid,
					0 AS homeid,
					0 AS awayid,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					b.sdiscount,
					b.adiscount,
					b.discount,
					'' AS settletime,
					CASE
						WHEN s.ProductId = 12 THEN b.matchid
						ELSE 0
					END AS matchid,
					b.transid,
					ISNULL(b.BetID, 0) AS betid,
					b.refno,
					b.transdate,
					0 AS oddsid,
					b.bettype,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductId IN (8, 12, 28) THEN b.odds
						ELSE 0
					END AS odds,
					0 AS modds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					'' AS betteam,
					b.status,
					0 AS SettlementStatus,
					'' AS betstatus,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm,
					b.livehomescore,
					b.liveawayscore,
					b.liveindicator,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS hthomescore,
					0 AS htawayscore,
					b.creator,
					b.ip,
					b.Username,
					0 AS IsNeutral,
					'' AS showtime,
					0 AS spositiontaking, -- unuse in this report
					0 AS mpositiontaking, -- unuse in this report
					0 AS apositiontaking, -- unuse in this report
					0 AS spositiontaking2,-- unuse in this report
					0 AS mpositiontaking2,-- unuse in this report
					0 AS apositiontaking2,-- unuse in this report
					b.betfrom,
					0 AS scomm, -- unuse in this report
					0 AS acomm, -- unuse in this report
					0 AS comm,	-- unuse in this report
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					b.winlostdate,
					CASE
						WHEN s.ProductId IN (12, 28) THEN b.betcheck
						WHEN s.ProductId = 8 THEN ISNULL(b.comstatus, '')
						ELSE ''
					END AS BetCheck,
					CASE
						WHEN s.ProductId IN (8, 28) THEN b.transdesc
						ELSE ''
					END AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE  b.custid = @CustId
					AND b.winlostdate = @FromDate
					AND s.ProductID IN (8, 12, 28)
					AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
			END

			-- RNG Casino Single Wallet, Voidbridge, Fishing World, Pragmatic Casino, Card Club
			IF @TransType = 1	-- before yesterday settled ticket
				AND @FromDate < DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
			BEGIN
				INSERT INTO @Data
				SELECT 
					CASE
						WHEN s.ProductID IN (6, 34) THEN b.matchid
						WHEN s.ProductID = 22 THEN 212
						WHEN s.ProductID = 24 THEN 219
						WHEN s.ProductID = 32 THEN 248
						ELSE 0
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeid,
					0 AS awayid,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					b.sdiscount,
					b.adiscount,
					b.discount,
					'' AS settletime,
					0 AS matchid,
					b.transid,
					ISNULL(b.betid, 0) AS betid,
					b.refno,
					b.transdate,
					0 AS oddsid,
					b.bettype,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductID = 6 THEN b.odds
						ELSE 0
					END AS Odds,
					0 AS modds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS oddstype,
					'' AS betteam,
					b.status,
					0 AS SettlementStatus,
					'' AS betstatus,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS commission,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS hthomescore,
					0 AS htawayscore,
					b.creator,
					b.ip,
					b.Username,
					0 AS IsNeutral,
					'' AS showtime,
					0 AS spositiontaking, -- unuse in this report
					0 AS mpositiontaking, -- unuse in this report
					0 AS apositiontaking, -- unuse in this report
					0 AS spositiontaking2,-- unuse in this report
					0 AS mpositiontaking2,-- unuse in this report
					0 AS apositiontaking2,-- unuse in this report
					b.betfrom,
					0 AS scomm, -- unuse in this report
					0 AS acomm, -- unuse in this report
					0 AS comm,	-- unuse in this report
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					b.winlostdate,
					'' AS BetCheck,
					CASE
						WHEN s.ProductID IN (6, 22, 24, 32, 34) THEN b.transdesc
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
					AND b.winlostdate = @FromDate
					AND s.ProductId IN (6, 22, 24, 32, 34)
					AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
			END

			IF @TransType = 1	-- yesterday and today settled ticket
				AND @FromDate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
					AND DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)
			BEGIN
				INSERT INTO @Data
				SELECT
					CASE
						WHEN s.ProductID IN (6, 34) THEN b.matchid
						WHEN s.ProductID = 22 THEN 212
						WHEN s.ProductID = 24 THEN 219
						WHEN s.ProductID = 32 THEN 248
						ELSE 0
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeid,
					0 AS awayid,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					AVG(brng.sdiscount) AS sdiscount,
					AVG(brng.adiscount) AS adiscount,
					AVG(brng.discount) AS discount,
					'' AS settletime,
					0 AS matchid,
					b.transid,
					ISNULL(b.betid, 0) AS betid,
					b.refno,
					b.transdate,
					0 AS oddsid,
					b.bettype,
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
					0 AS oddstype,
					'' AS betteam,
					CASE 
						WHEN SUM(brng.winlost - brng.actual_stake) > 0 THEN 'Won'
						WHEN SUM(brng.winlost - brng.actual_stake) < 0 THEN 'Lose'
						ELSE 'Draw'
					END AS Status,
					0 AS SettlementStatus,
					'' AS betstatus,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					SUM(brng.stake) AS stake,
					SUM(brng.actual_stake) AS actual_stake,
					SUM(brng.winlost - brng.actual_stake) AS WinLost,
					SUM(brng.playercomm) AS commission,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS hthomescore,
					0 AS htawayscore,
					b.creator,
					b.ip,
					b.Username,
					0 AS IsNeutral,
					'' AS showtime,
					0 AS spositiontaking, -- unuse in this report
					0 AS mpositiontaking, -- unuse in this report
					0 AS apositiontaking, -- unuse in this report
					0 AS spositiontaking2,-- unuse in this report
					0 AS mpositiontaking2,-- unuse in this report
					0 AS apositiontaking2,-- unuse in this report
					b.betfrom,
					0 AS scomm, -- unuse in this report
					0 AS acomm, -- unuse in this report
					0 AS comm,	-- unuse in this report
					SUM(brng.awinlost) AS awinlost,
					SUM(brng.mwinlost) AS mwinlost,
					SUM(brng.swinlost) AS swinlost,
					b.winlostdate,
					'' AS BetCheck,
					CASE
						WHEN s.ProductID IN (6, 22, 24, 32, 34) THEN b.transdesc
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
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = b.transid
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.custid = @CustId
					AND b.winlostdate = @FromDate
					AND s.ProductId IN (6, 22, 24, 32, 34)
					AND brng.statusID NOT IN (0, 1)
				GROUP BY
					b.transid,
					ISNULL(b.betid, 0),
					b.bettype,
					b.refno,
					b.transdate,
					b.winlostdate,
					b.custid,
					b.creator,
					b.ip,
					b.Username,
					b.betfrom,
					b.comstatus,
					b.matchid,
					b.transdesc,
					s.ProductID
				OPTION (RECOMPILE)
			END

			IF EXISTS (SELECT TOP(1) 1 FROM @tmpStatus WHERE [statusID] IN (0, 1))	-- yesterday and later running ticket
				AND @FromDate >= DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
			BEGIN
				INSERT INTO @Data
				SELECT 
					CASE
						WHEN s.ProductID IN (6, 34) THEN b.matchid
						WHEN s.ProductID = 22 THEN 212
						WHEN s.ProductID = 24 THEN 219
						WHEN s.ProductID = 32 THEN 248
						ELSE 0
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeid,
					0 AS awayid,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					AVG(brng.sdiscount) AS sdiscount,
					AVG(brng.adiscount) AS adiscount,
					AVG(brng.discount) AS discount,
					'' AS settletime,
					0 AS matchid,
					b.transid,
					ISNULL(b.betid, 0) AS betid,
					b.refno,
					b.transdate,
					0 AS oddsid,
					b.bettype,
					0 AS hdp1,
					0 AS hdp2,
					0 AS odds,
					0 AS modds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS oddstype,
					'' AS betteam,
					'Running' AS Status,
					0 AS SettlementStatus,
					'' AS betstatus,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					SUM(brng.stake) AS stake,
					SUM(brng.actual_stake) AS actual_stake,
					0 AS WinLost,
					0 AS commission,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS hthomescore,
					0 AS htawayscore,
					b.creator,
					b.ip,
					b.Username,
					0 AS IsNeutral,
					'' AS showtime,
					0 AS spositiontaking, -- unuse in this report
					0 AS mpositiontaking, -- unuse in this report
					0 AS apositiontaking, -- unuse in this report
					0 AS spositiontaking2,-- unuse in this report
					0 AS mpositiontaking2,-- unuse in this report
					0 AS apositiontaking2,-- unuse in this report
					b.betfrom,
					0 AS scomm, -- unuse in this report
					0 AS acomm, -- unuse in this report
					0 AS comm,	-- unuse in this report
					0 AS awinlost,
					0 AS mwinlost,
					0 AS swinlost,
					b.winlostdate,
					'' AS BetCheck,
					CASE
						WHEN s.ProductID IN (6, 22, 24, 32, 34) THEN b.transdesc
						ELSE ''
					END AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = b.transid
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.custid = @CustId
					AND b.winlostdate = @FromDate
					AND s.ProductId IN (6, 22, 24, 32, 34)
					AND brng.statusID IN (0, 1)
				GROUP BY
					b.transid,
					ISNULL(b.betid, 0),
					b.Bettype,
					b.refno,
					b.transdate,
					b.winlostdate,
					b.custid,
					b.creator,
					b.ip,
					b.Username,
					b.betfrom,
					b.comstatus,
					b.matchid,
					b.transdesc,
					s.ProductID
				OPTION (RECOMPILE)
			END

			-- AG Casino, AllBet
			IF @TransType = 1	-- before yesterday settled ticket
				AND @FromDate < DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
			BEGIN
				INSERT INTO @Data
				SELECT
					CASE
						WHEN s.ProductID = 11 THEN 250
						WHEN s.ProductID = 21 THEN 211
						ELSE 0
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeid,
					0 AS awayid,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					b.sdiscount,
					b.adiscount,
					b.discount,
					'' AS settletime,
					0 AS matchid,
					b.transid,
					ISNULL(b.betid, 0) AS betid,
					b.refno,
					b.transdate,
					0 AS oddsid,
					b.bettype,
					0 AS hdp1,
					0 AS hdp2,
					0 AS odds,
					0 AS modds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS oddstype,
					'' AS betteam,
					b.status,
					0 AS SettlementStatus,
					'' AS betstatus,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS commission,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS hthomescore,
					0 AS htawayscore,
					b.creator,
					b.ip,
					b.Username,
					0 AS IsNeutral,
					'' AS showtime,
					0 AS spositiontaking, -- unuse in this report
					0 AS mpositiontaking, -- unuse in this report
					0 AS apositiontaking, -- unuse in this report
					0 AS spositiontaking2,-- unuse in this report
					0 AS mpositiontaking2,-- unuse in this report
					0 AS apositiontaking2,-- unuse in this report
					b.betfrom,
					0 AS scomm, -- unuse in this report
					0 AS acomm, -- unuse in this report
					0 AS comm,	-- unuse in this report
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					b.winlostdate,
					'' AS BetCheck,
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
					AND b.winlostdate = @FromDate
					AND s.ProductID IN (11, 21)
					AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
			END

			IF @TransType = 1	-- yesterday and today settled ticket
				AND @FromDate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
					AND DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)
			BEGIN
				INSERT INTO @Data
				SELECT
					CASE
						WHEN s.ProductID = 11 THEN 250
						WHEN s.ProductID = 21 THEN 211
						ELSE 0
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeid,
					0 AS awayid,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					AVG(blc.sdiscount) AS sdiscount,
					AVG(blc.adiscount) AS adiscount,
					AVG(blc.discount) AS discount,
					'' AS settletime,
					0 AS matchid,
					b.transid,
					ISNULL(b.BetID, 0) AS betid,
					b.refno,
					b.transdate,
					0 AS oddsid,
					b.bettype,
					0 AS hdp1,
					0 AS hdp2,
					0 AS odds,
					0 AS modds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS oddstype,
					'' AS betteam,
					CASE 
						WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
						WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
						ELSE 'Draw'
					END AS Status,
					0 AS SettlementStatus,
					'' AS betstatus,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					SUM(blc.stake) AS stake,
					SUM(blc.actual_stake) AS actual_stake,
					SUM(blc.winlost - blc.actual_stake) AS WinLost,
					SUM(blc.playercomm) AS commission,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS hthomescore,
					0 AS htawayscore,
					b.creator,
					b.ip,
					b.Username,
					0 AS IsNeutral,
					'' AS showtime,
					0 AS spositiontaking, -- unuse in this report
					0 AS mpositiontaking, -- unuse in this report
					0 AS apositiontaking, -- unuse in this report
					0 AS spositiontaking2,-- unuse in this report
					0 AS mpositiontaking2,-- unuse in this report
					0 AS apositiontaking2,-- unuse in this report
					b.betfrom,
					0 AS scomm, -- unuse in this report
					0 AS acomm, -- unuse in this report
					0 AS comm,	-- unuse in this report
					SUM(blc.awinlost) AS awinlost,
					SUM(blc.mwinlost) AS mwinlost,
					SUM(blc.swinlost) AS swinlost,
					b.winlostdate,
					'' AS BetCheck,
					'' AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = b.transid
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.custid = @CustId
					AND b.winlostdate = @FromDate
					AND s.ProductID IN (11, 21)
					AND blc.statusID NOT IN (0, 1)
				GROUP BY
					b.transid,
					ISNULL(b.betid, 0),
					b.bettype,
					b.refno,
					b.transdate,
					b.winlostdate,
					b.custid,
					b.creator,
					b.ip,
					b.Username,
					b.betfrom,
					b.comstatus,
					s.ProductID
				OPTION (RECOMPILE)
			END

			IF EXISTS (SELECT TOP(1) 1 FROM @tmpStatus WHERE [statusID] IN (0, 1))	-- yesterday and later running ticket
				AND @FromDate >= DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
			BEGIN
				INSERT INTO @Data
				SELECT
					CASE
						WHEN s.ProductID = 11 THEN 250
						WHEN s.ProductID = 21 THEN 211
						ELSE 0
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeid,
					0 AS awayid,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					AVG(blc.sdiscount) AS sdiscount,
					AVG(blc.adiscount) AS adiscount,
					AVG(blc.discount) AS discount,
					'' AS settletime,
					0 AS matchid,
					b.transid,
					ISNULL(b.betid, 0) AS betid,
					b.refno,
					b.transdate,
					0 AS oddsid,
					b.bettype,
					0 AS hdp1,
					0 AS hdp2,
					0 AS odds,
					0 AS modds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS oddstype,
					'' AS betteam,
					'Running' AS Status,
					0 AS SettlementStatus,
					'' AS betstatus,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					SUM(blc.stake) AS stake,
					SUM(blc.actual_stake) AS actual_stake,
					0 AS WinLost,
					0 AS commission,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS hthomescore,
					0 AS htawayscore,
					b.creator,
					b.ip,
					b.Username,
					0 AS IsNeutral,
					'' AS showtime,
					0 AS spositiontaking, -- unuse in this report
					0 AS mpositiontaking, -- unuse in this report
					0 AS apositiontaking, -- unuse in this report
					0 AS spositiontaking2,-- unuse in this report
					0 AS mpositiontaking2,-- unuse in this report
					0 AS apositiontaking2,-- unuse in this report
					b.betfrom,
					0 AS scomm, -- unuse in this report
					0 AS acomm, -- unuse in this report
					0 AS comm,	-- unuse in this report
					0 AS awinlost,
					0 AS mwinlost,
					0 AS swinlost,
					b.winlostdate,
					'' AS BetCheck,
					'' AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = b.transid
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.custid = @CustId
					AND b.winlostdate = @FromDate
					AND s.ProductID IN (11, 21)
					AND blc.statusID IN (0, 1)
				GROUP BY
					b.transid,
					ISNULL(b.betid, 0),
					b.bettype,
					b.refno,
					b.transdate,
					b.winlostdate,
					b.custid,
					b.creator,
					b.ip,
					b.Username,
					b.betfrom,
					b.comstatus,
					s.ProductID
				OPTION (RECOMPILE)
			END

			-- Colossus Bet
			IF EXISTS (SELECT TOP(1) 1 FROM @tmpStatus WHERE [statusID] IN (0, 1))
			BEGIN
				INSERT INTO @Data
				SELECT
					204, --sporttype,
					0, --leagueid,
					0, --homeid,
					0, --awayid,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate, --get eventdate
					0,
					0,
					b.sdiscount,
					b.adiscount,
					b.discount,
					'' AS settletime,
					0 AS matchid,
					b.transid,
					ISNULL(b.betid, 0),
					b.refno,
					b.transdate,
					0 AS oddsid,
					b.bettype,
					0 AS hdp1,
					0 AS hdp2,
					0 AS odds,
					0 AS modds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS oddstype,
					'',
					b.status,
					0 AS SettlementStatus,
					'' AS betstatus,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					0 AS WinLost,
					0 AS playercomm,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0, --finalhomescore,
					0, --finalawayscore,
					0, --hthomescore,
					0, --htawayscore,
					b.creator,
					b.ip,
					b.Username,
					0 AS IsNeutral,
					'' AS showtime,
					0 spositiontaking, -- unuse in this report
					0 mpositiontaking, -- unuse in this report
					0 apositiontaking, -- unuse in this report
					0 spositiontaking2,-- unuse in this report
					0 mpositiontaking2,-- unuse in this report
					0 apositiontaking2,-- unuse in this report
					b.betfrom,
					0 scomm, -- unuse in this report
					0 acomm, -- unuse in this report
					0 comm,	-- unuse in this report
					0 AS awinlost,
					0 AS mwinlost,
					0 AS swinlost,
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
					AND b.winlostdate = @FromDate
					AND s.ProductID = 15
					AND b.statusID IN (0, 1)
			END

			IF EXISTS (SELECT TOP(1) 1 FROM @tmpStatus WHERE [statusID] NOT IN (0, 1))
			BEGIN
				INSERT INTO @Data
				SELECT
					204, --sporttype,
					0, --leagueid,
					0, --homeid,
					0, --awayid,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate, 
					0,
					0,
					b.sdiscount,
					b.adiscount,
					b.discount,
					'' AS settletime,
					b.matchid,
					b.transid,
					ISNULL(b.betid, 0),
					b.refno,
					b.transdate,
					0 AS oddsid,
					b.bettype,
					0 AS hdp1,
					0 AS hdp2,
					0 AS odds,
					0 AS modds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS oddstype,
					'',
					b.status,
					0 AS SettlementStatus,
					'' AS betstatus,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0, --finalhomescore,
					0, --finalawayscore,
					0, --hthomescore,
					0, --htawayscore,
					b.creator,
					b.ip,
					b.Username,
					0 AS IsNeutral,
					'' AS showtime,
					0 spositiontaking, -- unuse in this report
					0 mpositiontaking, -- unuse in this report
					0 apositiontaking, -- unuse in this report
					0 spositiontaking2,-- unuse in this report
					0 mpositiontaking2,-- unuse in this report
					0 apositiontaking2,-- unuse in this report
					b.betfrom,
					0 scomm, -- unuse in this report
					0 acomm, -- unuse in this report
					0 comm,	-- unuse in this report
					b.awinlost,
					b.mwinlost,
					b.swinlost,
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
					AND b.winlostdate = @FromDate
					AND s.ProductID = 15
					AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
					AND @TransType <> 4
			END

			-- Get more info for BetTrade tickets
			IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType IN (901, 902))
			BEGIN
				UPDATE betList
				SET betList.Odds = originBetList.odds,
					betList.Stake = originBetList.stake,
					betList.comm = CASE
										WHEN betList.Bettype = 902 THEN ISNULL(commBetList.AWinLost, 0)
										ELSE betList.comm
									END,
					betList.BetID = originBetList.bettype
				FROM @Data AS betList
					INNER JOIN dbo.bettrans AS originBetList WITH (NOLOCK) ON betList.RefNo = originBetList.transid
					LEFT JOIN @Data AS commBetList ON betList.RefNo = commBetList.RefNo AND commBetList.BetType = 903
				WHERE betList.SportType = 1 AND betList.BetType IN (901, 902)
			END

			-- Get more info for CashOut tickets
			IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 911)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.LiveIndicator = ob.liveindicator,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.OriginalBetType = ob.bettype,
					b.BetdaqId = ob.transid
				FROM @Data AS b
					INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
				WHERE b.BetType = 911
			END

			IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 912)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.LiveIndicator = ob.liveindicator,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.OriginalBetType = ob.bettype,
					b.BetdaqId = ob.transid,
					b.Stake = cob.stake,
					b.Comm = ISNULL(cb.AWinLost, 0)
				FROM @Data AS b
					INNER JOIN dbo.bettrans AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
					INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
					LEFT JOIN @Data AS cb ON b.RefNo = cb.RefNo AND cb.BetType = 913
				WHERE b.BetType = 912
			END
		END

		-- Grand Prize Jackpot Win
		IF @TransType = 4
		BEGIN
			-- ONERnG Jackpot
			INSERT INTO @Data
			SELECT
				CASE
					WHEN s.ProductID = 6 THEN b.productID
					ELSE 0
				END AS SportType,
				0 AS leagueid,
				0 AS homeid,
				0 AS awayid,
				'' AS matchcode,
				'' AS race,
				'' AS eventdate,
				0,
				0,
				0 AS sdiscount,
				0 AS adiscount,
				0 AS discount,
				'' AS settletime,
				0 AS matchid,
				b.transid,
				0 AS BetId,
				b.RefNo,
				b.transdate,
				0 AS oddsid,
				b.gameID AS BetType,
				0 AS hdp1,
				0 AS hdp2,
				b.odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS oddstype,
				'' AS betteam,
				b.status,
				0 AS SettlementStatus,
				'' AS betstatus,
				0 AS comstatus,
				b.stake,
				b.actual_stake,
				CASE
					WHEN s.ProductID = 6 THEN (b.winlost - b.actual_stake)
					ELSE 0
				END AS WinLost,
				CASE
					WHEN s.ProductID = 6 THEN b.playercomm
					ELSE 0
				END AS PlayerComm,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS hthomescore,
				0 AS htawayscore,
				b.creator,
				b.ip,
				b.Username,
				0 AS IsNeutral,
				'' AS showtime,
				0 AS spositiontaking, -- unuse in this report
				0 AS mpositiontaking, -- unuse in this report
				0 AS apositiontaking, -- unuse in this report
				0 AS spositiontaking2,-- unuse in this report
				0 AS mpositiontaking2,-- unuse in this report
				0 AS apositiontaking2,-- unuse in this report
				b.betfrom,
				0 AS scomm, -- unuse in this report
				0 AS acomm, -- unuse in this report
				0 AS comm,	-- unuse in this report
				0 AS awinlost,
				0 AS mwinlost,
				0 AS swinlost,
				pt.winlostdate,
				b.TranId3rd AS BetCheck,
				b.transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				CASE
					WHEN s.ProductID = 6 THEN ISNULL(b.RefNo2, -1)
					ELSE -1
				END AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM DBACC.bodb02.dbo.PayoutTrans AS pt WITH (NOLOCK)
				INNER JOIN dbo.bettransRnG AS b WITH (NOLOCK) ON pt.RefNo = b.transid
				INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
			WHERE pt.custid = @CustId
				AND pt.winlostdate = @FromDate
				AND (s.ProductID = 6 AND pt.PayoutStatus IN ('Completed', 'Expired'))
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

			-- Colossus Bet
			INSERT INTO @Data
			SELECT
				204, --sporttype,
				0, --leagueid,
				0, --homeid,
				0, --awayid,
				'' AS matchcode,
				'' AS race,
				'' AS eventdate, 
				0,
				0,
				b.sdiscount,
				b.adiscount,
				b.discount,
				'' AS settletime,
				b.matchid,
				b.transid,
				ISNULL(b.betid, 0),
				b.refno,
				b.transdate,
				b.oddsid,
				b.bettype,
				0 AS hdp1,
				0 AS hdp2,
				0 AS odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				'' AS oddstype,
				'',
				b.status,
				0 AS SettlementStatus,
				'' AS betstatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm,
				b.livehomescore,
				b.liveawayscore,
				0 AS liveindicator,
				0, --finalhomescore
				0, --finalawayscore
				0, --hthomescore
				0, --htawayscore
				b.creator,
				b.ip,
				b.Username,
				0 AS IsNeutral,
				'' AS showtime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				b.betfrom,
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				b.awinlost,
				b.mwinlost,
				b.swinlost,
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
				AND b.winlostdate = @FromDate
				AND s.ProductID = 15
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
				AND EXISTS (	SELECT 1
								FROM DBACC.bodb02.dbo.PayoutTrans AS pt WITH (NOLOCK)
								WHERE pt.refno = b.transid AND pt.PayoutStatus IN ('Completed', 'Expired'))
		END
	END

	DELETE @Data
	WHERE Bettype IN (903, 913)

	UPDATE tblTemp
	SET tblTemp.Creator = cu.username
	FROM @Data AS tblTemp
		INNER JOIN dbo.Customer AS cu WITH (NOLOCK) ON cu.custid = tblTemp.Creator;

	-- Get currency name
	DECLARE @CurrencyName NVARCHAR(50)

	SELECT @CurrencyName = ex.currency
	FROM dbo.custInfo AS ci WITH (NOLOCK)
		INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON ci.currency = ex.exchangeid
	WHERE ci.custid = @CustId

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
			AWinLost		MONEY,
			SComm			MONEY,
			AComm			MONEY,
			Comm			MONEY
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
			SUM(AWinLost) AS AWinLost,
			SUM(SComm) AS SComm,
			SUM(AComm) AS AComm,
			SUM(Comm) AS Comm
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
				b.SComm = r.SComm,
				b.AComm = r.AComm,
				b.Comm = r.Comm,
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

	SELECT *,
		@CurrencyName AS Currency
	FROM @Data
	ORDER BY TransId ASC

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

	-- Virtual Sports
	IF EXISTS ( SELECT TOP(1) 1
				FROM @SportBettype AS sp
					INNER JOIN @Data AS d ON d.bettype = sp.bettype
				WHERE sp.ProductID = 5 AND sp.EventType = 3)
	BEGIN
		IF @Fromdate > @MoveBetsDay
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
				INNER JOIN @SportBettype AS sp ON bm.bettype = sp.bettype
				INNER JOIN @Data AS b ON bm.refno = b.RefNo
			WHERE sp.ProductID = 5
				AND sp.EventType = 3
				AND bm.custid = @CustId
		END
		ELSE
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
			FROM dbo.bettransm14 AS bm WITH (NOLOCK)
				INNER JOIN @SportBettype AS sp ON bm.bettype = sp.bettype
				INNER JOIN @Data AS b ON bm.refno = b.RefNo
			WHERE sp.ProductID = 5
				AND sp.EventType = 3
				AND bm.custid = @CustId
		END
	END

	-- Gold Deluxe
	IF EXISTS ( SELECT TOP(1) 1
				FROM @SportBettype AS sp
					INNER JOIN @Data AS d ON d.bettype = sp.bettype
				WHERE sp.ProductID = 12)
	BEGIN
		IF @Fromdate > @MoveBetsDay
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
				INNER JOIN @SportBettype AS sp ON bg.bettype = sp.bettype
				INNER JOIN @Data AS b ON bg.refno = b.TransId AND bg.bettype = b.BetType
			WHERE sp.ProductID = 12
		END
		ELSE
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
			FROM dbo.bettransg14 AS bg WITH (NOLOCK)
				INNER JOIN @SportBettype AS sp ON bg.bettype = sp.bettype
				INNER JOIN @Data AS b ON bg.refno = b.TransId AND bg.bettype = b.BetType
			WHERE sp.ProductID = 12
		END
	END

	SELECT * FROM @DetailData
END
GO


GRANT EXECUTE ON [dbo].[Acc_BetListByDayAll] TO [bodbAdminNet]
GO
