USE bodb02
GO 

ALTER PROCEDURE [dbo].[Acc_BetListByDayAll]
	@CustId			INT,
	@FromDate		SMALLDATETIME,
	@MoveBetsDay	DATETIME,
	@Language		NVARCHAR(2)		= 'en',
	@TransId		BIGINT			= 0,
	@TransType		INT				= 0
AS

/*
	Created by: [Creator]
	Date: 2008
	Task: Bet list by date
	DB: DBAGE.BODB02
	
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
		- 20091002@Simon: Get Odds && OddsType columns.
		- 20091003@Jamie: Remove comstatus out 
		- 20091009@Daniel: Get refund status from bettrans
		- 20091015@Shifu: Get refno for Casino
		- 20091023@Simon: Displays Odds at Bet/Settle time
		- 20091205@Henry: Get more column: refno for viewing Mix Parlay detail
		- 20100306@Daniel: Query all @FromDate on winlostdate to support Finacial tickets
		- 20100409@Daniel: Support Mini game
		- 20100501@Daniel: Remove support Mini game
		- 20100524@Jamie: Show currency2's exchange rate for OpenTote 
		- 20100603@Jamie: Change datatype transid to bigint
		- 20100611@Henry: Change mix-parlay match from 0 to 9
		- 20100907@Henry: Add IBC Bingo bettype
		- 20101007@Henry: Change column transid from INT to BIGINT
		- 20101130@Henry: Add column betid for number game
		- 20101201@Henry: Return winlost-actual_stake for column winlost
		- 20110408@Amy: Change function to get Odds value and odds type
		- 20110513@Lukas: re-arrange bettype
		- 20110705@Tom:Add new parameter @transtype and modify method get creator of the bet transaction
		- 20110711@Johnson: show exchange rate for SA Tote(Pool Currency)
		- 20110725@Lukas: Get refund tickets when transtype = 1
		- 20110802@Johnson: - Add new bettype combination mix parlay.
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
		- 20140908@Dom:	[Redmine #22012] Update VS conditions
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

	Param's Explanation:
		+ @transtype: 
			1: Betting Statement
			2: Void/Cancelled Bet
			3: Outstanding Bet
			4: Grand Prize (Colossus Bet, Microgaming RNG Casino)
*/

BEGIN
	SET NOCOUNT ON;

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM bodb02.dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)

	DELETE FROM @SportBettype
	WHERE ProductID = 1 AND Bettype = 904

	DECLARE @tmpStatus TABLE ([statusID] TINYINT);

	IF @transtype = 1
	BEGIN
		INSERT INTO @tmpStatus ([statusID])
		SELECT 111 UNION ALL
		SELECT 112 UNION ALL
		SELECT 113 UNION ALL
		SELECT 103
	END
	ELSE IF @transtype = 2
	BEGIN
		INSERT INTO @tmpStatus ([statusID])
		SELECT 101 UNION ALL
		SELECT 102
	END
	ELSE IF @transtype = 3
	BEGIN
		INSERT INTO @tmpStatus ([statusID])
		SELECT 0 UNION ALL
		SELECT 1
	END
	ELSE IF @transtype = 4	-- Grand Prize of Colossus Bet, Microgaming RNG Casino
	BEGIN
		INSERT INTO @tmpStatus ([statusID])
		SELECT 111 UNION ALL
		SELECT 112 UNION ALL
		SELECT 113

		DELETE @SportBettype
		WHERE ProductID NOT IN (15, 17)
	END

	DECLARE @Data TABLE (
		SportType		INT,
		LeagueId		INT,
		HomeId			INT,
		AwayId			INT,
		MatchCode		NVARCHAR(50),
		Race			NVARCHAR(50),	--phuong.nguyen, add new field for Horse Racing race
		EventDate		DATETIME,		--phuong.nguyen, get eventdate
		VirtualRate		FLOAT,			-- in case OpenToe, it's currency2's exchange rate 
		IsShowOTExRate	BIT,			-- Show OpenTote currency2's exchange rate or not 
		SDiscount		DECIMAL (9, 8),
		ADiscount		DECIMAL (9, 8),
		Discount		DECIMAL (9, 8),
		SettleTime		DATETIME,
		MatchId			INT,
		TransId			BIGINT,
		BetId			BIGINT,
		RefNo			BIGINT,
		TransDate		DATETIME,
		OddsId			INT,
		BetType			SMALLINT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		MOdds			MONEY,
		FinalOdds		MONEY,
		FinalOdds2		MONEY,
		OddsType		INT,
		BetTeam			NVARCHAR(50),
		Status			NVARCHAR(50),
		BetStatus		NVARCHAR(50),
		ComStatus		NVARCHAR(50),
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		Commission		MONEY,
		LiveHomeScore	INT,
		LiveAwayScore	INT,
		LiveIndicator	BIT,
		FinalHomeScore	INT,
		FinalAwayScore	INT,
		HtHomeScore		INT,
		HtAwayScore		INT,
		Creator			VARCHAR(50),
		Ip				NVARCHAR(15),
		Username		VARCHAR(50),
		IsNeutral		BIT,
		ShowTime		NVARCHAR(50),
		SPositionTaking SMALLMONEY,
		MPositionTaking SMALLMONEY,
		APositionTaking SMALLMONEY,
		SPositionTaking2 SMALLMONEY,
		MPositionTaking2 SMALLMONEY,
		APositionTaking2 SMALLMONEY,
		BetFrom			NVARCHAR(1),
		SComm			MONEY,
		AComm			MONEY,
		Comm			MONEY,
		AWinLost		MONEY,
		MWinLost		MONEY,
		SWinLost		MONEY,
		WinLostDate		SMALLDATETIME,
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000),
		OddsSpread		MONEY
	);

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

	IF @Fromdate <= @MoveBetsDay
	BEGIN
		-- single bet
		INSERT INTO @Data
		SELECT
			m.sporttype,
			m.leagueid,
			m.homeid,
			m.awayid,
			m.matchcode,
			'' AS race,
			'' AS eventdate,
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
			m.betstatus,
			CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS winlost,
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
			ISNULL(m.isNeutral, CONVERT (BIT, 0)) AS IsNeutral,
			CASE
				WHEN s.ProductID = 5 THEN CONVERT(NVARCHAR(50), m.kickofftime)
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
			awinlost,
			mwinlost,
			swinlost,
			b.winlostdate,
			b.betcheck,
			ISNULL(b.transdesc, '') AS transdesc,
			ISNULL(b.oddsspread, 0) AS OddsSpread
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
		WHERE  b.custid = @CustId
			AND b.winlostdate = @FromDate
			AND s.EventType = 1
			AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

		-- Mixed parlay
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
			b.transid,
			ISNULL(b.BetID, 0),
			b.refno,
			b.transdate,
			0,
			9,
			0,
			0,
			b.odds,
			b.modds,
			0 AS finalodds,
			0 AS finalodds2,
			'' AS oddstype,
			'',
			b.status,
			'' AS betstatus,
			CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS winlost,
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
			CONVERT (BIT, 0) AS IsNeutral,
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
			awinlost,
			mwinlost,
			swinlost,
			b.winlostdate,
			b.BetCheck,
			'' AS transdesc,
			0 AS OddsSpread
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
		WHERE b.custid = @CustId
			AND b.winlostdate = @FromDate
			AND b.matchid = 9
			AND b.bettype = 9
			AND b.statusID IN (SELECT [statusID] FROM @tmpStatus);

		-- Combination mixed parlay
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
				WHEN ISNULL(b.betID,0) = 0 THEN b.transid
				ELSE b.betid
			END AS transid,
			ISNULL(b.betid, 0),
			b.refno,
			b.transdate,
			0,
			29,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			0 AS finalodds,
			0 AS finalodds2,
			'' AS oddstype,
			b.betteam,
			b.status,
			'' AS betstatus,
			CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS winlost,
			b.playercomm,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			b.CREATOR,
			b.ip,
			b.Username,
			CONVERT (BIT, 0) AS IsNeutral,
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
			awinlost,
			mwinlost,
			swinlost,
			b.winlostdate,
			ISNULL(b.betcheck, '') AS BetCheck,
			'' AS transdesc,
			0 AS OddsSpread
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
		WHERE b.custid = @CustId
			AND b.winlostdate = @FromDate
			AND b.matchid = 29
			AND b.bettype = 29
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
			ISNULL(b.BetID, 0),
			b.refno,
			b.transdate,
			o.orid,
			b.bettype,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			bmOdd.finalodds,
			bmOdd.finalodds2,
			0 AS oddstype,
			'',
			b.status,
			'',
			CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS winlost,
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
			CONVERT (BIT, 0) AS IsNeutral,
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
			awinlost,
			mwinlost,
			swinlost,
			b.winlostdate,
			b.BetCheck,
			'' AS transdesc,
			0 AS OddsSpread
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.matchid = o.orid
			INNER JOIN dbo.league AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
			LEFT OUTER JOIN (
				SELECT
					t.refno,
					t.finalodds,
					f.finalodds AS finalodds2
				FROM dbo.bettransm14 AS t WITH (NOLOCK)
					INNER JOIN dbo.bettransm14 AS f WITH (NOLOCK) ON t.refno = f.refno
				WHERE t.bettype = 41 AND f.bettype = 42
				) AS bmOdd ON b.transid = bmOdd.refno
		WHERE b.custid = @CustId
			AND b.bettype IN (10, 31, 32, 33, 41, 42, 43)
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
			'' AS betstatus,
			CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS winlost,
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
			awinlost,
			mwinlost,
			swinlost,
			b.winlostdate,
			b.BetCheck,
			'' AS transdesc,
			0 AS OddsSpread
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.VSOutright14 AS o WITH (NOLOCK) ON b.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
		WHERE b.custid = @CustId
			AND b.winlostdate = @FromDate
			AND s.ProductID = 5
			AND s.EventType = 3
			AND b.statusID IN (SELECT statusID FROM @tmpStatus)

		-- RNG Casino, Gold Deluxe, Microgaming Live Casino, Microgaming RNG Casino, AG Casino, Cockfighting, AllBet
		-- Voidbridge, NG2, Fishing World
		IF @transtype <> 4
		BEGIN
			INSERT INTO @Data
			SELECT
				CASE
					WHEN s.ProductID = 6 AND s.SubProduct = '' THEN 251
					WHEN s.ProductID = 6 AND s.SubProduct <> '' THEN b.matchid
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
					WHEN s.ProductID = 24 THEN 219
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
					WHEN s.ProductId IN (19, 23) THEN b.betdaqid
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
					WHEN s.ProductID IN (12, 19, 23) THEN b.Odds
					ELSE 0 
				END AS Odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				CASE
					WHEN s.ProductID = 19 THEN b.oddstype
					ELSE 0 
				END AS oddstype,
				'' AS betteam,
				b.status,
				'' AS betstatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS winlost,
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
					WHEN s.ProductID IN (12, 13, 19) THEN b.betcheck 
					ELSE ''
				END AS betcheck,
				CASE
					WHEN s.ProductID = 6 AND s.SubProduct <> '' THEN b.transdesc
					WHEN s.ProductId IN (19, 22, 23, 24) THEN b.transdesc
					ELSE ''
				END AS transdesc,
				0 AS OddsSpread
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND s.ProductID IN (6, 11, 12, 13, 17, 19, 21, 22, 23, 24)
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus);
		END

		-- Keno
		INSERT INTO @Data
		SELECT
			202, --sporttype,
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
			ISNULL(b.checktime, '') AS settletime,
			d.GameId AS matchid,
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
			0 AS oddstype,
			d.ChoiceId AS betteam,
			b.status,
			'' AS betstatus,
			CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS winlost,
			b.playercomm,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			0, --finalhomescore
			0, --finalawayscore
			0, --hthomescore
			0, --htawayscore
			b.CREATOR,
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
			0 AS scomm,	-- unuse in this report
			0 AS acomm,	-- unuse in this report
			0 AS comm,	-- unuse in this report
			b.awinlost,
			b.mwinlost,
			b.swinlost,
			b.winlostdate,
			b.BetCheck,
			'' AS transdesc,
			0 AS OddsSpread
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			OUTER APPLY dbo.[f_ParseTransDesc](b.TransDesc, b.bettype) d
		WHERE b.custid = @CustId
			AND b.winlostdate = @FromDate
			AND s.ProductID = 8
			AND b.statusID IN (SELECT [statusID] FROM @tmpStatus);

		-- Colossus Bet
		IF @transtype <> 4
		BEGIN
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
				0 AS oddstype,
				'' AS betteam,
				b.status,
				'' AS betstatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS winlost,
				b.playercomm,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0, --finalhomescore
				0, --finalawayscore
				0, --hthomescore
				0, --htawayscore
				b.CREATOR,
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
				0 AS OddsSpread
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				LEFT JOIN dbo.bettransm14 AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND s.ProductID = 15
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
		END

		-- Grand Prize Jackpot Win
		IF @transtype = 4
		BEGIN
			-- Microgaming RNG Casino
			INSERT INTO @Data
			SELECT
				205 AS SportType,
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
				pt.transdate,
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
				'' AS betstatus,
				0 AS comstatus,
				b.stake,
				b.actual_stake,
				pt.WinAmount AS WinLost,
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
				pt.winlostdate,
				b.TranId3rd AS BetCheck,
				b.transdesc,
				0 AS OddsSpread
			FROM DBACC.bodb02.dbo.PayoutTrans AS pt WITH (NOLOCK)
				INNER JOIN dbo.bettransRnG14 AS b WITH (NOLOCK) ON pt.RefNo = b.transid
				INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
			WHERE pt.custid = @CustId
				AND pt.winlostdate = @FromDate
				AND s.ProductID = 17
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
				'' AS betstatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS winlost,
				b.playercomm,
				b.livehomescore,
				b.liveawayscore,
				0 AS liveindicator,
				0, --finalhomescore, 
				0, --finalawayscore, 
				0, --hthomescore, 
				0, --htawayscore,
				b.CREATOR,
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
				0 AS OddsSpread
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				LEFT JOIN dbo.bettransm14 AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
			WHERE  b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND s.ProductID = 15
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
				AND EXISTS (	SELECT 1 
								FROM DBACC.bodb02.dbo.PayoutTrans AS pt WITH (NOLOCK)
								WHERE pt.refno = b.transid AND pt.PayoutStatus IN ('Completed', 'Expired'))
		END

		UPDATE betList
		SET betList.Odds	= originBetList.Odds
			,betList.Stake	= originBetList.Stake
			,betList.comm	= CASE WHEN betList.Bettype = 902 THEN ISNULL(commBetList.awinlost,0) ELSE betList.comm END
			,betList.BetID	= originBetList.Bettype
		FROM @Data AS betList
			INNER JOIN dbo.bettrans14 AS originBetList WITH(NOLOCK) ON betList.RefNO = originBetList.TransID
			LEFT JOIN @Data AS commBetList ON betList.RefNO = commBetList.RefNO AND commBetList.Bettype = 903
		WHERE betList.Sporttype = 1 AND betList.Bettype IN (901, 902)
	END
	ELSE
	BEGIN
		-- single bet
		INSERT INTO @Data
		SELECT
			m.sporttype,
			m.leagueid,
			m.homeid,
			m.awayid,
			m.matchcode,
			'' AS race,
			'' AS eventdate,
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
			CASE WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 and ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status,
			m.betstatus,
			CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS winlost,
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
			ISNULL(m.isNeutral, CONVERT (BIT, 0)) AS IsNeutral, --phuong.nguyen, get isneutral from Match
			CASE
				WHEN s.ProductID = 5 THEN CONVERT(NVARCHAR(50), m.kickofftime)
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
			awinlost,
			mwinlost,
			swinlost,
			b.winlostdate,
			b.BetCheck,
			ISNULL(b.transdesc, '') AS transdesc,
			ISNULL(b.oddsspread, 0) AS OddsSpread
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
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
			'' AS eventdate,
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
			CASE WHEN b.gameid IN (801,803,804,805,806) THEN CONVERT(TINYINT, ISNULL(b.custom1, 0)) ELSE 0 END AS OddsType,
			'' AS betteam,
			b.status,
			m.betstatus,
			0 AS comstatus,
			b.stake,
			b.actual_stake,
			0 AS winlost,
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
			ISNULL(m.isNeutral, CONVERT (BIT, 0)) AS IsNeutral, --phuong.nguyen, get isneutral from Match
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
			0 AS OddsSpread
		FROM
			dbo.translog AS b WITH (NOLOCK)
			INNER JOIN dbo.match AS m WITH (NOLOCK) on b.eventid = m.matchid
			INNER JOIN dbo.custInfo c WITH (NOLOCK) on c.custid = b.creator
		WHERE b.custid = @CustId
			AND b.winlostdate = @FromDate
			AND b.gameID BETWEEN 801 AND 899
			AND b.statusID IN (SELECT [statusID] FROM @tmpStatus WHERE statusID IN (0, 1))

		-- Mixed parlay
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
			b.transid,
			ISNULL(b.BetID, 0),
			b.refno,
			b.transdate,
			0,
			9,
			0,
			0,
			b.odds,
			b.modds,
			0 AS finalodds,
			0 AS finalodds2,
			'' AS oddstype,
			'',
			b.status,
			'' AS betstatus,
			CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS winlost,
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
			CONVERT (BIT, 0) AS IsNeutral,
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
			awinlost,
			mwinlost,
			swinlost,
			b.winlostdate,
			b.BetCheck,
			'' AS transdesc,
			0 AS OddsSpread
		FROM dbo.bettrans AS b WITH (NOLOCK)
		WHERE b.custid = @CustId
			AND b.winlostdate = @FromDate
			AND b.matchid = 9
			AND b.bettype = 9
			AND b.statusID IN (SELECT [statusID] FROM @tmpStatus);

		-- Combination mixed parlay
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
			CASE WHEN ISNULL(b.betID,0) = 0 THEN b.transid ELSE b.betID END AS transid,
			ISNULL(b.BetID, 0),
			b.refno,
			b.transdate,
			0,
			29,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			0 AS finalodds,
			0 AS finalodds2,
			'' AS oddstype,
			b.betteam,
			b.status,
			'' AS betstatus,
			CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,   
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS winlost,
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
			CONVERT (BIT, 0) AS IsNeutral,
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
			awinlost,
			mwinlost,
			swinlost,
			b.winlostdate,
			ISNULL(b.betcheck, '') AS BetCheck,
			'' AS transdesc,
			0 AS OddsSpread
		FROM dbo.bettrans AS b WITH (NOLOCK)
		WHERE b.custid = @CustId
			AND b.winlostdate = @FromDate
			AND b.matchid = 29
			AND b.bettype = 29
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
			ISNULL(b.BetID, 0),
			b.refno,
			b.transdate,
			o.orid,
			b.bettype,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			bmOdd.finalodds,
			bmOdd.finalodds2,
			0 AS oddstype,
			'',
			b.status,
			'',
			CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,   
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS winlost,
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
			CONVERT (BIT, 0) AS IsNeutral,
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
			awinlost,
			mwinlost,
			swinlost,
			b.winlostdate,
			b.BetCheck,
			'' AS transdesc,
			0 AS OddsSpread
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.outright AS o WITH (NOLOCK) ON b.matchid = o.orid
			INNER JOIN dbo.league AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
			LEFT OUTER JOIN (
				SELECT 
					t.refno,
					t.finalodds,
					f.finalodds AS finalodds2
				FROM dbo.bettransm AS t WITH (NOLOCK)
					INNER JOIN dbo.bettransm AS f WITH (NOLOCK) ON t.refno = f.refno
				WHERE t.bettype = 41 AND f.bettype = 42
				) AS bmOdd ON b.transid = bmOdd.refno
		WHERE b.custid = @CustId
			AND b.bettype IN (10, 31, 32, 33, 41, 42, 43)
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
			'' AS betstatus,
			CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS winlost,
			b.playercomm,
			b.livehomescore,
			b.liveawayscore,
			0 AS liveindicator,
			0 AS finalhomescore,
			0 AS finalawayscore,
			0 AS hthomescore,
			0 AS htawayscore,
			b.CREATOR,
			b.ip,
			b.Username,
			CONVERT (BIT, 0) AS IsNeutral,
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
			awinlost,
			mwinlost,
			swinlost,
			b.winlostdate,
			b.BetCheck,
			'' AS transdesc,
			0 AS OddsSpread
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON b.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
		WHERE b.custid = @CustId
			AND b.winlostdate = @FromDate
			AND s.ProductID = 5
			AND s.EventType = 3
			AND b.statusID IN (SELECT statusID FROM @tmpStatus)

		-- Casino, NG2
		INSERT INTO @Data
		SELECT
			CASE
				WHEN s.ProductID = 6 THEN 251
				WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2501 AND 2539 THEN 213
				WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2541 AND 2579 THEN 214
				WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2581 AND 2619 THEN 215
				WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2621 AND 2659 THEN 216
				WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2681 AND 2699 THEN 218
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
			ISNULL(b.BetID, 0),
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
			'' AS betstatus,
			CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,   
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS winlost,
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
			b.CREATOR,
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
			0 AS OddsSpread
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
		WHERE b.custid = @CustId
			AND b.winlostdate = @FromDate
			AND (s.ProductId = 23
				OR (s.ProductId = 6 AND s.SubProduct = ''))
			AND b.statusID IN (SELECT [statusID] FROM @tmpStatus);

		-- Keno
		INSERT INTO @Data
		SELECT 
			202, --sporttype,
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
			d.GameId AS matchid,
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
			0 AS oddstype,
			d.ChoiceId AS betteam,
			b.status,
			'' AS betstatus,
			CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS winlost,
			b.playercomm,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			0, --finalhomescore
			0, --finalawayscore
			0, --hthomescore
			0, --htawayscore
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
			awinlost,
			mwinlost,
			swinlost,
			b.winlostdate,
			b.BetCheck,
			'' AS transdesc,
			0 AS OddsSpread
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			OUTER APPLY dbo.[f_ParseTransDesc](b.TransDesc, b.bettype) d
		WHERE b.custid = @CustId
			AND b.winlostdate = @FromDate
			AND s.ProductID = 8
			AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
		UNION ALL
		SELECT 
			202, --sporttype,
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
			d.GameId matchid,
			0 transid,
			0 BetID,
			b.translogid,
			b.transdate,
			0 oddsid,
			b.gameID,
			0 hdp1,
			0 hdp2,
			b.odds,
			0 modds,
			0 AS finalodds,
			0 AS finalodds2,
			0 AS oddstype,
			d.ChoiceId betteam,
			b.status,
			'' AS betstatus,
			0 AS comstatus,
			b.stake,
			b.actual_stake,
			(-b.actual_stake) AS winlost,
			0 playercomm,
			0 livehomescore,
			0 liveawayscore,
			0 liveindicator,
			0, --finalhomescore,
			0, --finalawayscore,
			0, --hthomescore, 
			0, --htawayscore,
			b.CREATOR,
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
			0 awinlost,
			0 mwinlost,
			0 swinlost,
			b.winlostdate,
			'' AS BetCheck,
			'' AS transdesc,
			0 AS OddsSpread
		FROM dbo.translog AS b WITH (NOLOCK)
			INNER JOIN @SportBettype s ON s.Bettype = b.gameID
			OUTER APPLY dbo.[f_ParseTransDesc](b.TransDesc, b.gameid) d
		WHERE b.custid = @CustId
			AND b.winlostdate = @FromDate
			AND s.ProductID = 8
			AND b.statusID = 0
			AND EXISTS(SELECT [statusID] FROM @tmpStatus t WHERE t.statusID = 0);

		-- Gold Deluxe, Microgaming Live Casino, Cockfighting, Colossus Bet (translog)
		IF EXISTS (SELECT TOP 1 [statusID] FROM @tmpStatus WHERE [statusID] = 0)
		BEGIN
			INSERT INTO @Data
			SELECT 
				CASE
					WHEN s.ProductId = 12 THEN 255
					WHEN s.ProductId = 13 THEN 203
					WHEN s.ProductId = 15 THEN 204
					WHEN s.ProductId = 19 THEN 206
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
					WHEN s.ProductId = 19 THEN b.Gameid3rd
					ELSE 0
				END AS matchid,
				0 AS transid,
				0 AS betid,
				b.translogid AS refno,
				b.transdate,
				0 AS oddsid,
				b.gameID AS bettype,
				0 AS hdp1,
				0 AS hdp2,
				CASE
					WHEN s.ProductId IN (12, 19) THEN b.odds
					ELSE 0
				END AS odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				CASE
					WHEN s.ProductId = 19 THEN CONVERT(TINYINT, ISNULL(b.custom1, 0))
					ELSE 0
				END AS OddsType,
				CASE
					WHEN s.ProductId = 12 THEN b.GameID3rd
					ELSE ''
				END AS betteam,
				b.status,
				'' AS betstatus,
				0 AS comstatus,
				b.stake,
				b.actual_stake,
				0 AS winlost,
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
					WHEN s.ProductId = 19 THEN b.custom2
					ELSE ''
				END AS BetCheck,
				CASE
					WHEN s.ProductId = 19 THEN b.transdesc
					ELSE ''
				END AS transdesc,
				0 AS OddsSpread
			FROM dbo.translog AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND s.ProductID IN (12, 13, 15, 19)
				AND b.statusID = 0
		END

		-- Gold Deluxe, Microgaming Live Casino, Cockfighting (bettrans)
		IF EXISTS (SELECT TOP 1 [statusID] FROM @tmpStatus WHERE [statusID] NOT IN (0, 1))
		BEGIN
			INSERT INTO @Data
			SELECT
				CASE
					WHEN s.ProductId = 12 THEN 255
					WHEN s.ProductId = 13 THEN 203
					WHEN s.ProductId = 19 THEN 206
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
					WHEN s.ProductId = 19 THEN b.betdaqid
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
					WHEN s.ProductId IN (12, 19) THEN b.odds
					ELSE 0
				END AS odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				CASE
					WHEN s.ProductId = 19 THEN b.oddstype
					ELSE 0
				END AS oddstype,
				'' AS betteam,
				b.status,
				'' AS betstatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS winlost,
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
				awinlost,
				mwinlost,
				swinlost,
				b.winlostdate,
				b.BetCheck,
				CASE
					WHEN s.ProductId = 19 THEN b.transdesc
					ELSE ''
				END AS transdesc,
				0 AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE  b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND s.ProductID IN (12, 13, 19)
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
		END

		-- Microgaming RNG Casino, RNG Casino Single Wallet, Voidbridge, Fishing World
		IF @transtype = 1	-- not yesterday and today settled ticket
			AND @FromDate < DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
		BEGIN
			INSERT INTO @Data
			SELECT 
				CASE
					WHEN s.ProductID = 6 THEN b.matchid
					WHEN s.ProductID = 17 THEN 205
					WHEN s.ProductID = 22 THEN 212
					WHEN s.ProductID = 24 THEN 219
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
				b.status,
				'' AS betstatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS winlost,
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
					WHEN s.ProductID IN (6, 22, 24) THEN b.transdesc
					ELSE ''
				END AS transdesc,
				0 AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND (s.ProductId IN (17, 22, 24)
					OR (s.ProductId = 6 AND s.SubProduct <> ''))
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
		END

		IF @transtype = 1	-- yesterday and today settled ticket
			AND @FromDate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
				AND DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)
		BEGIN
			INSERT INTO @Data
			SELECT
				CASE
					WHEN s.ProductID = 6 THEN b.matchid
					WHEN s.ProductID = 17 THEN 205
					WHEN s.ProductID = 22 THEN 212
					WHEN s.ProductID = 24 THEN 219
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
					WHEN SUM(brng.winlost - brng.actual_stake) = 0 THEN 'Draw'
					WHEN SUM(brng.winlost - brng.actual_stake) > 0 THEN 'Won'
					WHEN SUM(brng.winlost - brng.actual_stake) < 0 THEN 'Lose'
				END AS Status,
				'' AS betstatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				SUM(brng.stake) AS stake,
				SUM(brng.actual_stake) AS actual_stake,
				SUM(brng.winlost - brng.actual_stake) AS winlost,
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
					WHEN s.ProductID IN (6, 22, 24) THEN b.transdesc
					ELSE ''
				END AS transdesc,
				0 AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_custid_matchid_bettype)
				INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = b.transid
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND (s.ProductId IN (17, 22, 24)
					OR (s.ProductId = 6 AND s.SubProduct <> ''))
				AND brng.statusID NOT IN (0, 1)
			GROUP BY
				b.transid,
				ISNULL(b.BetID, 0),
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

		IF EXISTS (SELECT TOP 1 [statusID] FROM @tmpStatus WHERE [statusID] = 0)	-- yesterday and today running ticket
			AND @FromDate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
				AND DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)
		BEGIN
			INSERT INTO @Data
			SELECT 
				CASE
					WHEN s.ProductID = 6 THEN b.matchid
					WHEN s.ProductID = 17 THEN 205
					WHEN s.ProductID = 22 THEN 212
					WHEN s.ProductID = 24 THEN 219
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
				'Running' AS Status,
				'' AS betstatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				SUM(brng.stake) AS stake,
				SUM(brng.actual_stake) AS actual_stake,
				0 AS winlost,
				0 AS commission,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS hthomescore,
				0 AS htawayscore,
				b.CREATOR,
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
					WHEN s.ProductID IN (6, 22, 24) THEN b.transdesc
					ELSE ''
				END AS transdesc,
				0 AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_custid_matchid_bettype)
				INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = b.transid
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND (s.ProductId IN (17, 22, 24)
					OR (s.ProductId = 6 AND s.SubProduct <> ''))
				AND brng.statusID IN (0, 1)
			GROUP BY
				b.transid,
				ISNULL(b.BetID, 0),
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
		IF @transtype = 1	-- not yesterday and today settled ticket
			AND @FromDate < DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
		BEGIN
			INSERT INTO @Data
			SELECT
				CASE
					WHEN s.ProductID = 11 THEN 250
					WHEN s.ProductID = 21 THEN 211
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
				b.status,
				'' AS betstatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS winlost,
				b.playercomm AS commission,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS hthomescore,
				0 AS htawayscore,
				b.CREATOR,
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
				0 AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND s.ProductID IN (11, 21)
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
		END

		IF @transtype = 1	-- yesterday and today settled ticket
			AND @FromDate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
				AND DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)
		BEGIN
			INSERT INTO @Data
			SELECT
				CASE
					WHEN s.ProductID = 11 THEN 250
					WHEN s.ProductID = 21 THEN 211
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
					WHEN SUM(blc.winlost - blc.actual_stake) = 0 THEN 'Draw'
					WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
					WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
				END AS Status,
				'' AS betstatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				SUM(blc.stake) AS stake,
				SUM(blc.actual_stake) AS actual_stake,
				SUM(blc.winlost - blc.actual_stake) AS winlost,
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
				0 AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_custid_matchid_bettype)
				INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = b.transid
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND s.ProductID IN (11, 21)
				AND blc.statusID NOT IN (0, 1)
			GROUP BY
				b.transid,
				ISNULL(b.BetID, 0),
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
				s.ProductID
			OPTION (RECOMPILE)
		END

		IF EXISTS (SELECT TOP 1 [statusID] FROM @tmpStatus WHERE [statusID] = 0)	-- yesterday and today running ticket
			AND @FromDate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
				AND DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)
		BEGIN
			INSERT INTO @Data
			SELECT
				CASE
					WHEN s.ProductID = 11 THEN 250
					WHEN s.ProductID = 21 THEN 211
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
				'Running' AS Status,
				'' AS betstatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				SUM(blc.stake) AS stake,
				SUM(blc.actual_stake) AS actual_stake,
				0 AS winlost,
				0 AS commission,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS hthomescore,
				0 AS htawayscore,
				b.CREATOR,
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
				0 AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_custid_matchid_bettype)
				INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = b.transid
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND s.ProductID IN (11, 21)
				AND blc.statusID IN (0, 1)
			GROUP BY
				b.transid,
				ISNULL(b.BetID, 0),
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
				s.ProductID
			OPTION (RECOMPILE)
		END

		-- Colossus Bet
		IF EXISTS (SELECT TOP 1 [statusID] FROM @tmpStatus WHERE [statusID] = 0)
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
				ISNULL(b.BetID, 0),
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
				'' AS betstatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				0 AS winlost,
				0 AS playercomm,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0, --finalhomescore,
				0, --finalawayscore,
				0, --hthomescore,
				0, --htawayscore,
				b.CREATOR,
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
				0 AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				LEFT JOIN dbo.bettransm AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND s.ProductID = 15
				AND b.statusID = 0
		END

		IF EXISTS (SELECT TOP 1 [statusID] FROM @tmpStatus WHERE [statusID] NOT IN (0, 1))
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
				ISNULL(b.BetID, 0),
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
				'' AS betstatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS winlost,
				b.playercomm,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0, --finalhomescore,
				0, --finalawayscore,
				0, --hthomescore,
				0, --htawayscore,
				b.CREATOR,
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
				0 AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				LEFT JOIN dbo.bettransm AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND s.ProductID = 15
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
				AND @transtype <> 4
		END

		-- Grand Prize Jackpot Win
		IF @transtype = 4
		BEGIN
			-- Microgaming RNG Casino
			INSERT INTO @Data
			SELECT 
				205 AS SportType,
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
				pt.TransDate,
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
				'' AS betstatus,
				0 AS comstatus,
				b.stake,
				b.actual_stake,
				pt.WinAmount AS WinLost,
				0 AS playercomm,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS hthomescore,
				0 AS htawayscore,
				b.CREATOR,
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
				0 AS OddsSpread
			FROM DBACC.bodb02.dbo.PayoutTrans AS pt WITH (NOLOCK)
				INNER JOIN dbo.bettransRnG AS b WITH (NOLOCK) ON pt.RefNo = b.transid
				INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
			WHERE pt.custid = @CustId
				AND pt.winlostdate = @FromDate
				AND s.ProductID = 17
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
				'',
				b.status,
				'' AS betstatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS winlost,
				b.playercomm,
				b.livehomescore,
				b.liveawayscore,
				0 AS liveindicator,
				0, --finalhomescore
				0, --finalawayscore
				0, --hthomescore
				0, --htawayscore
				b.CREATOR,
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
				0 AS OddsSpread
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

		UPDATE betList
		SET betList.Odds	= originBetList.Odds
			,betList.Stake	= originBetList.Stake
			,betList.comm	= CASE WHEN betList.Bettype = 902 THEN ISNULL(commBetList.awinlost,0) ELSE betList.comm END
			,betList.BetID	= originBetList.Bettype
		FROM @Data AS betList
			INNER JOIN dbo.bettrans AS originBetList WITH(NOLOCK) ON betList.RefNo = originBetList.transid
			LEFT JOIN @Data AS commBetList ON betList.RefNo = commBetList.RefNo AND commBetList.Bettype = 903
		WHERE betList.Sporttype = 1 AND betList.Bettype IN (901, 902)
	END

	DELETE @Data WHERE Sporttype = 1 AND Bettype = 903

	UPDATE @Data
	SET tblTemp.Creator = cu.username
	FROM @Data AS tblTemp
		INNER JOIN dbo.Customer AS cu WITH (NOLOCK) ON cu.custid = tblTemp.Creator;

	IF @transid = 0
		SELECT *
		FROM @Data
		ORDER BY transid;
	ELSE
		SELECT *
		FROM @Data
		WHERE transid = @transid;

	-- Live Casino
	IF EXISTS ( SELECT TOP 1 1
				FROM @SportBettype AS sp
					INNER JOIN @Data AS d ON d.bettype = sp.bettype 
				WHERE ProductID = 4)
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
				INNER JOIN @Data AS b1 ON bg.refno = b1.refno AND bg.bettype = b1.bettype
			WHERE sp.ProductID = 4
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
				INNER JOIN @Data AS b1 ON bg.refno = b1.refno AND bg.bettype = b1.bettype
			WHERE sp.ProductID = 4
		END
	END

	-- Gold Deluxe
	IF EXISTS ( SELECT TOP 1 1 
				FROM @SportBettype AS sp 
					INNER JOIN @Data AS d ON d.bettype = sp.bettype 
				WHERE ProductID = 12)
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
				INNER JOIN @Data AS b2 ON bg.refno = b2.transid AND bg.bettype = b2.bettype
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
				INNER JOIN @Data AS b2 ON bg.refno = b2.transid AND bg.bettype = b2.bettype
			WHERE sp.ProductID = 12
		END
	END

	SELECT * FROM @DetailData
	RETURN 
END








GO
GRANT EXECUTE ON [dbo].[Acc_BetListByDayAll] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Acc_BetListByDayAll] TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BetListByDayAll] TO [vnteam]
 