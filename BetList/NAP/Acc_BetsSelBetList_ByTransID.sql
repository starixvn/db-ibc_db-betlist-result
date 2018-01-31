USE bodb02
Go

ALTER PROCEDURE [dbo].[Acc_BetsSelBetList_ByTransID]
	@CustId			INT,
	@RefNo			BIGINT,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME
AS

/*
	Created by: Henry
	Date: 2008
	Task: Bet List By TransID
	DB: DBAGE.bodb02
	Original: Acc_BetsSelBetList

	Revisions:
		- 20091229@Henry: newly created
		- 20100409@Daniel:
				+ Support Mini game
				+ Fix search Casino & Mini game by bettrans.refno instead
		- 20100501@Daniel: Remove support Mini game, add agent W/L amount, agent's commission amount columns
		- 20100524@Jamie: Show currency2's exchange rate for OpenTote
		- 20100525@Henry: Change to use StatusID instead of Status in WHERE statement
		- 20100611@Henry: Change mix-parlay match from 0 to 9
		- 20100907@Henry: Add IBC Bingo bettype
		- 20101130@Henry: Add column betid for number game
		- 20101201@Henry: Return winlost-actual_stake for column winlost
		- 20110408@Amy: Change function to get Odds value and odds type
		- 20110516@Lukas: re-arrange bettype  
		- 20110711@Johnson: show exchange rate for SA Tote(Pool Currency)
		- 20110802@Johnson: Add column actual_stake into betlist
						- Add new bettype combination mix parlay
		- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
		- 20111207@Sophia: Add P2P
		- 20120120@Sophia: Add Showtime for Table-hand-shoe of Live Casino
						- Add sub detail for Live Casino
		- 20120217@Daniel: Allow to delete mix palay bet (whole ticket)
		- 20120405@Hurri: Exclude bettype 72 (P2P bet ticket) in the calculation of Casino
		- 20120410@Hurri: change matchid 0 -> 1000 for bettype 1000
		- 20120417@Johnson: Correct column transid for p2p
		- 20120424@Lukas: show transid of main-ticket for sub-tickets of system parlay
		- 20120507@Jamie: Fix p2p to get transID
		- 20120606@Sophia: Change datatype of stake to money
		- 20120626@Lukas: exclude outright from sportbook ( in case of matchid = orid)
		- 20120629@Sophia: Remove function f_GetOddsByBettype, f_ShowOddsByBettype,f_GetChoice for odds, Oddstype, betteam
		- 20120927@Johnson: get commstatus column to check double comm losing
		- 20130121@Dan: change linked server DB06 to DBARC
		- 20130227@Elodie: Add Virtual HR product
		- 20130705@Kathy: Update matchid for RnG Casino (71) and Bingo (73)
		- 20130724@Elodie: Get winlostdate field
		- 20130726@Elodie: Define data for bettrans, bettrans14 or bettrans_bk by winlostdate field, enhance performance
		- 20140307@Dom: Add Keno
		- 20140318@Dom: #13487 Prevent user to delete LAS ticket in bet list accounting site
		- 20140908@Dom: [Redmine #22012] Update VS conditions
		- 20141103@Dom: Apply sport bettype matrix
		- 20150122@Dom: HotFix #29646 Fix bug virtual HR
		- 20150415@Sophia: Get Betcheck for Betradar
		- 20150506@Tom: Support Gold Deluxe Product [#34847]
		- 20150506@Bobby: Add transdesc column for Metric Gaming bettypes (801-899)
		- 20150615@Edward: Support for BetTrade
		- 20150707@Bobby: Exclude Metric Gaming running ticket from bettrans table
		- 20150625@Edward: Support for Microgaming Live Casino
		- 20150805@Bobby: remove checking product when selecting ticket's eventtype = 1 from bettrans_bk
		- 20150825@Kos: Add OddsSpread column to support Myanmar Odds
		- 20150828@Kos: Support Colossus Bet
		- 20151009@Kos: Support Microgaming RNG Casino and AG Casino
		- 20151022@Kos: Return [translog].[transid3rd] and [bettransm].[betcheck] to support view CB ticket detail
		- 20151030@Kos: Change ProductId/SportType of Microgaming RNG Casino
		- 20151210@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20151216@Kos: Support Cockfighting (#Redmine: 48850)
		- 20151222@Kos: Support search in bettransRnG and bettransLC tables
		- 20151230@Kos: Support RNG Casino Single Wallet [Redmine: #48958]
		- 20160119@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160125@Kos: Fix Colossus Bet result issue
		- 20160129@Kos: Support RNG Casino Single Wallet yesterday running ticket
		- 20160204@Kos: Support AllBet [#Redmine: 50864]
		- 20160307@Kos: Hotfix Missing choice of Gold Deluxe [#Redmine: 53506]
		- 20160331@Kos: Support Voidbridge [#Redmine: 54925]
		- 20160407@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20160606@Kos: Unable to search Gold Deluxe ticket [#Redmine: 58852]
		- 20160711@Kos: Change to use inline function for SportBettypeMatrix
		- 20160804@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20160810@Kos: Support NG2
		- 20161019@Kos: Remove Bingo and P2P in bettrans and bettrans14 range [#Redmine: 53988]
					  - Support Fishing World [#Redmine: 65934]
		- 20170228@Kos: Support KickOffTime for Virtual Soccer and Virtual Tennis [#Redmine: 71906]
		- 20170315@Kos: Support CashOut [#Redmine: 71963]
		- 20170602@Kos: Get liveindicator from original ticket for 911 and 912 tickets [#Redmine: 77669]
		- 20170616@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20170628@Kos: Support Keno Lottery [#Redmine: 77929]
		- 20170717@Kos: Don't parse transdesc for Keno anymore [#Redmine: 80082]
		- 20170829@Kos: Support Lucky 3 [#Redmine: 75277]
		- 20171019@Kos: Support Bullfighting [#Redmine: 84961]
		- 20171227@Kos: Return ticket detail of Racing and Virtual Horse Racing [#Redmine: 88775]
					- Don't support Live Casino in bettrans and bettrans14 anymore
		- 20180118@Kos: Support Licensee Bonus System [#Redmine: 74978]
		- 20180130@Kos: Don't support Racing and RNG Casino (bettype 71, 72) in bettrans and bettrans14 [#Redmine: 86086]
					- Don't support Cockfighting anymore
*/

BEGIN
	SET NOCOUNT ON

	-- List of bettype not allowed to delete
	DECLARE @tableBettypeNotAllowDelete TABLE(typeid INT NOT NULL)

	INSERT INTO @tableBettypeNotAllowDelete (typeid)
	SELECT 31 UNION ALL SELECT 32 UNION ALL SELECT 33 UNION ALL SELECT 41 UNION ALL SELECT 42 UNION ALL SELECT 43 UNION ALL
	SELECT 51 UNION ALL SELECT 52 UNION ALL SELECT 53 UNION ALL SELECT 54 UNION ALL SELECT 55 UNION ALL SELECT 56 UNION ALL
	SELECT 61 UNION ALL SELECT 62 UNION ALL SELECT 63 UNION ALL SELECT 64 UNION ALL SELECT 65 UNION SELECT 66

	DECLARE @Data TABLE (
		BetType			INT,
		TransId			BIGINT,
		BetId			BIGINT,
		RefNo			NVARCHAR(50),
		MatchCode		NVARCHAR(1000),
		Race			NVARCHAR(20),
		EventDate		SMALLDATETIME,
		VirtualRate		FLOAT,
		IsShowOTExRate	BIT,
		SDiscount		SMALLMONEY,
		ADiscount		SMALLMONEY,
		Discount		SMALLMONEY,
		HomeId			INT,
		AwayId			INT,
		SettleTime		DATETIME,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		FinalOdds		MONEY,
		FinalOdds2		MONEY,
		OddsType		TINYINT,
		Status			NVARCHAR(50),
		ComStatus		NVARCHAR(50),
		Stake			MONEY,
		Actual_Stake	MONEY,
		TransDate		DATETIME,
		BetTeam			NVARCHAR(50),
		SPositionTaking SMALLMONEY,
		MPositionTaking SMALLMONEY,
		APositionTaking SMALLMONEY,
		SPositionTaking2 SMALLMONEY,
		MPositionTaking2 SMALLMONEY,
		APositionTaking2 SMALLMONEY,
		LiveIndicator	BIT,
		Modds			MONEY,
		CustId			INT,
		LiveHomeScore	INT,
		LiveAwayScore	INT,
		FinalHomeScore	INT,
		FinalAwayScore	INT,
		LeagueId		INT,
		SportType		SMALLINT,
		Ip				NVARCHAR(15),
		BetFrom			NVARCHAR(1),
		MatchId			INT,
		IsNeutral		BIT,
		AllowDelete		BIT,
		WinLost			MONEY,
		Commission		MONEY,
		SComm			MONEY,
		AComm			MONEY,
		Comm			MONEY,
		AWinLost		MONEY,
		MWinLost		MONEY,
		SWinLost		MONEY,
		ShowTime		NVARCHAR(50),
		WinLostDate		SMALLDATETIME,
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000),
		OddsSpread		MONEY,
		OriginalBetType	INT,
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000),
		WalletType		TINYINT,
		RefCode			BIGINT
	)

	DECLARE @TransId	BIGINT,
		@WinLostDate	SMALLDATETIME,
		@BetType		INT

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE BetType NOT IN (903, 904, 913, 914)
		AND ProductID NOT IN (19)

	-- FROM translog
	SELECT TOP(1)
		@TransId = b.translogid,
		@WinLostDate = b.winlostdate,
		@BetType = b.gameID,
		@RefNo = b.translogid
	FROM dbo.translog AS b WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp ON b.gameID = sp.bettype
	WHERE b.custid = @CustId
		AND b.translogid = @RefNo
		AND b.statusID IN (0, 1)
		AND ( sp.productid IN (8, 12, 13, 15, 28, 30)
			OR sp.bettype BETWEEN 801 AND 899 )

	-- FROM bettrans
	IF @WinLostDate IS NULL
	BEGIN
		SELECT TOP(1)
			@TransId = b.transid,
			@WinLostDate = b.winlostdate,
			@BetType = b.bettype,
			@RefNo = b.refno
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON b.bettype = sp.bettype
		WHERE b.custid = @CustId
			AND ( b.transid = @RefNo
				OR ( b.refno = @RefNo
					AND (sp.productid IN (8, 12, 13, 15, 28, 30)
						OR sp.bettype BETWEEN 801 AND 899)))
			--exclude metric gaming running ticket
			AND (b.bettype NOT BETWEEN 801 AND 806
				OR (b.bettype BETWEEN 801 AND 806 AND b.statusID NOT IN (0, 1)))
	END

	-- FROM bettrans14
	IF @WinLostDate IS NULL
	BEGIN
		SELECT TOP(1)
			@TransId = b.transid,
			@WinLostDate = b.winlostdate,
			@BetType = b.bettype,
			@RefNo = b.refno
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON b.bettype = sp.bettype
		WHERE b.custid = @CustId
			AND ( b.transid = @RefNo
				OR ( b.refno = @RefNo
					AND (sp.productid IN (8, 12, 13, 15, 28, 30)
						OR sp.bettype BETWEEN 801 AND 899)))
	END

	-- FROM bettrans_bk
	IF @WinLostDate IS NULL
	BEGIN
		SELECT TOP(1)
			@TransId = b.transid,
			@WinLostDate = b.winlostdate,
			@BetType = b.bettype,
			@RefNo = b.refno
		FROM DBARC.bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON b.bettype = sp.bettype
		WHERE b.custid = @CustId
			AND ( b.transid = @RefNo
				OR ( b.refno = @RefNo
					AND (sp.productid IN (6, 7, 8, 9, 12, 13, 15, 28, 30)
						OR sp.bettype BETWEEN 801 AND 899)))
	END

	IF @WinLostDate IS NOT NULL
	BEGIN
		-- Bettrans
		IF @WinLostDate > @MoveBetsDay
		BEGIN
			-- Sportbooks, Number Game, Virtual Sports, Lucky 3, BetRadar Virtual Sports
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE EventType = 1 AND bettype = @BetType )
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetID,
					b.refno,
					m.matchcode,
					'' AS race,
					m.eventdate,
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
					ISNULL(b.checktime,'') settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 finalodds,
					0 finalodds2,
					b.OddsType,
					CASE 
						WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
						ELSE b.status
					END AS status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 spositiontaking2,
					0 mpositiontaking2,
					0 apositiontaking2,
					b.liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					m.finalhomescore,
					m.finalawayscore,
					m.leagueid,
					m.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					CASE 
						WHEN b.bettype IN (SELECT typeid FROM @tableBettypeNotAllowDelete)
							OR b.statusID NOT IN (0, 1, 112, 113, 111) THEN 0
						ELSE 1
					END AS allowdelete,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					CASE
						WHEN s.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
						ELSE m.showtime
					END AS ShowTime,
					b.winlostdate,
					b.BetCheck,
					ISNULL(b.transdesc, '') AS transdesc,
					ISNULL(b.oddsspread, 0) AS OddsSpread,	-- For Myanmar Odds
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
				FROM
					dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.transid = @TransId AND s.EventType = 1

				UNION ALL -- translog metric gaming
				SELECT
					b.gameid AS BetType,
					b.translogid AS transid,
					0 AS BetID,
					b.translogid AS refno,
					m.matchcode,
					'' AS race,
					m.eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					m.homeid,
					m.awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					b.odds,
					0 finalodds,
					0 finalodds2,
					CASE
						WHEN b.gameid IN (801, 803, 804, 805, 806) THEN CONVERT(TINYINT, ISNULL(b.custom1, 0))
						ELSE 0
					END AS OddsType,
					b.status,
					0 AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 spositiontaking2,
					0 mpositiontaking2,
					0 apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					m.finalhomescore,
					m.finalawayscore,
					m.leagueid,
					m.sporttype,
					b.ip,
					'' AS betfrom,
					b.eventID,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					CASE
						WHEN b.gameID IN (SELECT typeid FROM @tableBettypeNotAllowDelete)
							OR b.statusID NOT IN (0, 1, 112, 113, 111) THEN 0
						ELSE 1
					END AS allowdelete,
					0 AS WinLost,
					0 AS commission,
					0 AS scomm,
					0 AS acomm,
					0 AS comm,
					0 AS awinlost,
					0 AS mwinlost,
					0 AS swinlost,
					m.showtime,
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
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.eventid = m.matchid
					INNER JOIN @SportBettype s ON s.Bettype = b.gameid
				WHERE
					s.Bettype BETWEEN 801 AND 899
					AND b.translogid = @TransId
					AND b.statusID IN (0, 1)

				-- Get more info for BetTrade tickets
				IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE SportType = 1 AND BetType = 901)
				BEGIN
					UPDATE b
					SET b.Odds = ob.odds,
						b.Stake = ob.stake,
						b.LiveHomeScore = ob.livehomescore,
						b.LiveAwayScore = ob.liveawayscore,
						b.BetId = ob.bettype
					FROM @Data AS b
						INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
					WHERE b.SportType = 1 AND b.BetType = 901
				END

				IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE SportType = 1 AND BetType = 902)
				BEGIN
					UPDATE b
					SET b.Odds = ob.odds,
						b.Stake = ob.stake,
						b.LiveHomeScore = ob.livehomescore,
						b.LiveAwayScore = ob.liveawayscore,
						b.Comm = ISNULL(cb.awinlost, 0),
						b.BetId = ob.bettype
					FROM @Data AS b
						INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
						LEFT JOIN dbo.bettrans AS cb WITH (NOLOCK)
							ON b.RefNo = cb.RefNo
							AND cb.BetType = 903
							AND cb.custid = @CustId
							AND cb.winlostdate = @WinLostDate
					WHERE b.SportType = 1 AND b.BetType = 902
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
						LEFT JOIN dbo.bettrans AS cb WITH (NOLOCK)
							ON b.RefNo = cb.RefNo
							AND cb.BetType = 913
							AND cb.custid = @CustId
							AND cb.winlostdate = @WinLostDate
					WHERE b.BetType = 912
				END
			END

			-- Mix Parlay, System Parlay, Mix Parlay (Betradar Virtual Sports)
			IF @BetType IN (9, 29, 2799)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					CASE
						WHEN (b.bettype = 29 AND ISNULL(b.betid, 0) > 0) THEN b.betid
						ELSE b.transid
					END AS transid,
					ISNULL(b.betid, 0) AS BetID,
					b.refno,
					'' matchcode,
					'' AS race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					sdiscount,
					adiscount,
					discount,
					0 AS homeid,
					0 AS awayid,
					'' settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 finalodds,
					0 finalodds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 spositiontaking2,
					0 mpositiontaking2,
					0 apositiontaking2,
					0 liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0,
					0,
					0 AS leagueid,
					0 AS sporttype,
					b.ip,
					b.betfrom,
					0 matchid,
					CONVERT(BIT,0) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
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
				WHERE
					b.matchid IN (9, 29, 2799)
					AND b.bettype IN (9, 29, 2799)
					AND b.transid = @TransId
			END

			-- Keno, Gold Deluxe, Microgaming Live Casino, Cockfighting, Lottery
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (8, 12, 13, 28) AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetID,
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
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductID IN (8, 12, 28) THEN b.odds
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0,
					0,
					0 AS leagueid,
					CASE
						WHEN s.ProductID = 8 THEN 202
						WHEN s.ProductID = 12 THEN 255
						WHEN s.ProductID = 13 THEN 203
						WHEN s.ProductID = 28 THEN 220
						ELSE 0
					END AS sporttype,
					b.ip,
					b.betfrom,
					CASE
						WHEN s.ProductID = 12 THEN b.matchid
						ELSE 0
					END AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					CASE
						WHEN s.ProductID IN (12, 13) THEN b.betcheck
						ELSE ''
					END AS BetCheck,
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
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.transid = @TransId
					AND s.ProductId IN (8, 12, 13, 28)
			END

			-- NG2
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID = 23 AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetId,
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
					'' AS settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					b.livehomescore,
					0 AS liveawayscore,
					0,
					0,
					0 AS leagueid,
					CASE
						WHEN s.Bettype BETWEEN 2501 AND 2539 THEN 213
						WHEN s.Bettype BETWEEN 2541 AND 2579 THEN 214
						WHEN s.Bettype BETWEEN 2581 AND 2619 THEN 215
						WHEN s.Bettype BETWEEN 2621 AND 2659 THEN 216
						WHEN s.Bettype BETWEEN 2681 AND 2699 THEN 218
						ELSE 0
					END AS sporttype,
					b.ip,
					b.betfrom,
					b.betdaqid AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					'' AS BetCheck,
					ISNULL(b.transdesc, '') AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.transid = @TransId
					AND s.ProductId = 23
			END

			-- Outright
			IF @BetType = 10
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetID,
					b.refno,
					odds.matchcode,
					odds.groupmatch AS race,
					odds.eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					odds.teamid AS awayid,
					'' AS settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					b.liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0,
					0,
					odds.leagueid,
					l.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					CONVERT(BIT,0) AS IsNeutral,
					CASE
						WHEN b.bettype IN (SELECT typeid FROM @tableBettypeNotAllowDelete)
							OR b.statusID NOT IN (0, 1, 112, 113, 111) THEN 0
						ELSE 1
					END AS allowdelete,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
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
					INNER JOIN dbo.outright AS odds WITH (NOLOCK) ON b.matchid = odds.orid
					INNER JOIN dbo.league l WITH (NOLOCK) ON odds.leagueid = l.leagueid
				WHERE b.bettype = 10
					AND b.transid = @TransId
			END

			-- Virtual Horse Racing
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID = 5 AND EventType = 3 AND bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					'' AS BetID,
					b.refno,
					o.RacerNum matchcode, --Horse Number
					b.oddsid AS Race, --Outright ID
					'' eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					o.RacerID AS homeID,
					0 AS awayID,
					'' settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 finalodds,
					0 finalodds2,
					b.OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' betteam,
					CASE WHEN b.bettype = 1233 THEN bm.spositiontaking ELSE b.spositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.mpositiontaking ELSE b.mpositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.apositiontaking ELSE b.apositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.spositiontaking2 ELSE 0 END,
					CASE WHEN b.bettype = 1233 THEN bm.mpositiontaking2 ELSE 0 END,
					CASE WHEN b.bettype = 1233 THEN bm.apositiontaking2 ELSE 0 END,
					0 liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0 finalhomescore,
					0 finalawayscore,
					r.leagueid,
					r.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					CASE 
						WHEN b.bettype IN (SELECT typeid FROM @tableBettypeNotAllowDelete)
							OR statusID NOT IN (0, 1, 112, 113, 111) THEN 0 
						ELSE 1 
					END AS allowdelete,
					(b.winlost - b.actual_stake) winlost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					r.EventTime AS showtime,
					b.winlostdate,
					b.BetCheck,
					'' AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM 
					dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON b.oddsid = o.Orid
					INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
					INNER JOIN @SportBettype AS s ON s.BetType = b.BetType 
					LEFT JOIN (
						SELECT
							t.refno,
							t.apositiontaking,
							t.mpositiontaking,
							t.spositiontaking,
							f.apositiontaking apositiontaking2,
							f.mpositiontaking mpositiontaking2,
							f.spositiontaking spositiontaking2
						FROM dbo.bettransm AS t WITH (NOLOCK)
							INNER JOIN dbo.bettransm AS f WITH (NOLOCK) ON t.refno = f.refno
						WHERE t.bettype = 1231 AND f.bettype = 1232
						) bm ON b.refno = bm.refno
				WHERE
					b.transid = @TransId
					AND s.ProductID = 5
					AND s.EventType = 3
			END

			-- Keno, Gold Deluxe, Microgaming Live Casino, Colossus Bet, Lottery (translog)
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (8, 12, 13, 15, 28) AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.gameid AS BetType,
					b.translogid AS transid,
					0 AS betid,
					b.translogid AS refno,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductID IN (8, 12, 13, 28) THEN b.odds
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					0 AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					CASE
						WHEN s.ProductID = 8 THEN 202
						WHEN s.ProductID = 12 THEN 255
						WHEN s.ProductID = 13 THEN 203
						WHEN s.ProductID = 15 THEN 204
						WHEN s.ProductID = 28 THEN 220
						ELSE 0
					END AS sporttype,
					b.ip,
					b.betfrom,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					(-b.actual_stake) AS WinLost,
					0 AS commission,
					0,
					0,
					0,
					0,
					0,
					0,
					'' AS showtime,
					b.winlostdate,
					CASE
						WHEN s.ProductID IN (12, 13) THEN b.GameID3rd
						WHEN s.ProductID = 15 THEN b.Tranid3rd
						ELSE ''
					END AS BetCheck,
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
				WHERE b.translogid = @TransId
					AND s.ProductID IN (8, 12, 13, 15, 28)
					AND b.statusID IN (0, 1)
			END

			-- Bullfighting (EventType = 5) (bettrans)
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE EventType = 5 AND Bettype = @BetType )
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetID,
					b.refno,
					m.MatchNo AS MatchCode,
					'' AS Race,
					m.EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					m.HomeId,
					m.AwayId,
					ISNULL(b.checktime, '') settleTime,
					0 AS Hdp1,
					0 AS Hdp2,
					b.odds,
					0 AS FinalOdds,
					0 AS FinalOdds2,
					b.oddstype,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					b.liveindicator,
					0 AS MOdds,
					b.custid,
					0 AS LiveHomeScore,
					0 AS LiveAwayScore,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					m.League3rdId AS LeagueId,
					m.SportType,
					b.ip,
					b.betfrom,
					b.matchid,
					0 AS IsNeutral,
					0 AS AllowDelete,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS ShowTime,
					b.winlostdate,
					ISNULL(b.betcheck, '') AS BetCheck,
					ISNULL(b.transdesc, '') AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM
					dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.Match3rd AS m WITH (NOLOCK) ON b.matchid = m.Match3rdId
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.transid = @TransId AND s.EventType = 5
			END

			-- Bullfighting (EventType = 5) (translog)
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID = 30 AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.gameid AS BetType,
					b.translogid AS TransId,
					0 AS betid,
					b.translogid AS RefNo,
					m.MatchNo AS MatchCode,
					'' AS Race,
					m.EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					m.HomeId,
					m.AwayId,
					'' AS SettleTime,
					0 AS Hdp1,
					0 AS Hdp2,
					b.odds,
					0 AS FinalOdds,
					0 AS FinalOdds2,
					CASE
						WHEN s.ProductID = 30 THEN CONVERT(TINYINT, ISNULL(b.custom1, 0))
						ELSE 0
					END AS OddsType,
					b.status,
					0 AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					CASE
						WHEN s.ProductID = 30 THEN b.custom3
						ELSE ''
					END AS BetTeam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					b.liveindicator,
					0 AS MOdds,
					b.custid,
					0 AS LiveHomeScore,
					0 AS LiveAwayScore,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					m.League3rdId AS LeagueId,
					m.SportType,
					b.ip,
					b.betfrom,
					CASE
						WHEN s.ProductID = 30 THEN b.eventid
						ELSE 0
					END AS MatchId,
					0 AS IsNeutral,
					0 AS AllowDelete,
					0 AS WinLost,
					0 AS commission,
					0,
					0,
					0,
					0,
					0,
					0,
					'' AS ShowTime,
					b.winlostdate,
					CASE
						WHEN s.ProductID = 30 THEN b.Tranid3rd
						ELSE ''
					END AS BetCheck,
					CASE
						WHEN s.ProductID = 30 THEN b.transdesc
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
				WHERE b.translogid = @TransId
					AND b.statusID IN (0, 1)
					AND s.ProductID = 30
			END

			-- Microgaming RNG Casino, RNG Casino Single Wallet, Voidbridge, Fishing World
			IF EXISTS (	SELECT TOP(1) 1 FROM @SportBettype
						WHERE Bettype = @BetType
							AND (ProductID IN (17, 22, 24)
								OR (ProductID = 6 AND SubProduct <> '')))
			BEGIN
				IF @WinLostDate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
					AND DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)	-- yesterday and today
				BEGIN
					-- Yesterday and today running ticket
					INSERT INTO @Data
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetID,
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
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						0 AS odds,
						0 AS finalodds,
						0 AS finalodds2,
						0 AS OddsType,
						'Running' AS Status,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						SUM(brng.stake) AS stake,
						SUM(brng.actual_stake) AS actual_stake,
						b.transdate,
						'' AS betteam,
						AVG(brng.spositiontaking) AS spositiontaking,
						AVG(brng.mpositiontaking) AS mpositiontaking,
						AVG(brng.apositiontaking) AS apositiontaking,
						0 AS spositiontaking2,
						0 AS mpositiontaking2,
						0 AS apositiontaking2,
						0 AS liveindicator,
						0 AS modds,
						b.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 6 THEN b.matchid
							WHEN s.ProductID = 17 THEN 205
							WHEN s.ProductID = 22 THEN 212
							WHEN s.ProductID = 24 THEN 219
							ELSE 0
						END AS Sporttype,
						b.ip,
						b.betfrom,
						0 AS matchid,
						CONVERT(BIT, 0) AS IsNeutral,
						0 AS allowdelete,
						0 AS WinLost,
						0 AS commission,
						0 AS scomm,
						0 AS acomm,
						0 AS comm,
						0 AS awinlost,
						0 AS mwinlost,
						0 AS swinlost,
						'' AS showtime,
						b.winlostdate,
						'' AS BetCheck,
						CASE
							WHEN s.ProductID IN (6, 22, 24) THEN b.transdesc
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
					WHERE
						b.transid = @TransId
						AND (s.ProductId IN (17, 22, 24)
							OR (s.ProductId = 6 AND s.SubProduct <> ''))
						AND brng.statusid IN (0, 1)
					GROUP BY
						b.transid,
						ISNULL(b.betid, 0),
						b.Bettype,
						b.refno,
						b.transdate,
						b.winlostdate,
						b.custid,
						b.ip,
						b.Username,
						b.betfrom,
						b.comstatus,
						b.matchid,
						b.transdesc,
						s.ProductID

					-- Yesterday and today settled ticket
					INSERT INTO @Data
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetID,
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
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						0 AS odds,
						0 finalodds,
						0 finalodds2,
						'' OddsType,
						CASE 
							WHEN SUM(brng.winlost - brng.actual_stake) > 0 THEN 'Won'
							WHEN SUM(brng.winlost - brng.actual_stake) < 0 THEN 'Lose'
							ELSE 'Draw'
						END AS Status,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						SUM(brng.stake) AS stake,
						SUM(brng.actual_stake) AS actual_stake,
						b.transdate,
						'' AS betteam,
						AVG(brng.spositiontaking) AS spositiontaking,
						AVG(brng.mpositiontaking) AS mpositiontaking,
						AVG(brng.apositiontaking) AS apositiontaking,
						0 AS spositiontaking2,
						0 AS mpositiontaking2,
						0 AS apositiontaking2,
						0 AS liveindicator,
						0 AS modds,
						b.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 6 THEN b.matchid
							WHEN s.ProductID = 17 THEN 205
							WHEN s.ProductID = 22 THEN 212
							WHEN s.ProductID = 24 THEN 219
							ELSE 0
						END AS Sporttype,
						b.ip,
						b.betfrom,
						0 AS matchid,
						CONVERT(BIT, 0) AS IsNeutral,
						0 AS allowdelete,
						SUM(brng.winlost - brng.actual_stake) AS WinLost,
						SUM(brng.playercomm) AS commission,
						SUM(brng.scomm - brng.acomm) AS scomm,
						SUM(brng.acomm - brng.comm) AS acomm,
						SUM(brng.comm - brng.playercomm) AS comm,
						SUM(brng.awinlost) AS awinlost,
						SUM(brng.mwinlost) AS mwinlost,
						SUM(brng.swinlost) AS swinlost,
						'' AS showtime,
						b.winlostdate,
						'' AS BetCheck,
						CASE
							WHEN s.ProductID IN (6, 22, 24) THEN b.transdesc
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
					WHERE
						b.transid = @TransId
						AND (s.ProductId IN (17, 22, 24)
							OR (s.ProductId = 6 AND s.SubProduct <> ''))
						AND brng.statusid NOT IN (0, 1)
					GROUP BY
						b.transid,
						ISNULL(b.betid, 0),
						b.bettype,
						b.refno,
						b.transdate,
						b.winlostdate,
						b.custid,
						b.ip,
						b.Username,
						b.betfrom,
						b.comstatus,
						b.matchid,
						b.transdesc,
						s.ProductID
				END
				ELSE
				BEGIN
					-- Not yesterday and today settled ticket
					INSERT INTO @Data
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetID,
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
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						0 AS odds,
						0 AS finalodds,
						0 AS finalodds2,
						0 AS OddsType,
						b.status,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						b.stake,
						b.actual_stake,
						b.transdate,
						'' AS betteam,
						b.spositiontaking,
						b.mpositiontaking,
						b.apositiontaking,
						0 AS spositiontaking2,
						0 AS mpositiontaking2,
						0 AS apositiontaking2,
						0 AS liveindicator,
						0 AS modds,
						b.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 6 THEN b.matchid
							WHEN s.ProductID = 17 THEN 205
							WHEN s.ProductID = 22 THEN 212
							WHEN s.ProductID = 24 THEN 219
							ELSE 0
						END AS Sporttype,
						b.ip,
						b.betfrom,
						0 AS matchid,
						CONVERT(BIT, 0) AS IsNeutral,
						0 AS allowdelete,
						(b.winlost - b.actual_stake) AS WinLost,
						b.playercomm AS commission,
						(b.scomm - b.acomm) AS scomm,
						(b.acomm - b.comm) AS acomm,
						(b.comm - b.playercomm) AS comm,
						b.awinlost,
						b.mwinlost,
						b.swinlost,
						'' AS showtime,
						b.winlostdate,
						'' AS BetCheck,
						CASE
							WHEN s.ProductID IN (6, 22, 24) THEN b.transdesc
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
					WHERE b.transid = @TransId
						AND (s.ProductId IN (17, 22, 24)
							OR (s.ProductId = 6 AND s.SubProduct <> ''))
				END
			END

			-- AG Casino, AllBet
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (11, 21) AND Bettype = @BetType)
			BEGIN
				IF @WinLostDate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
					AND DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)	-- yesterday and today
				BEGIN
					-- Yesterday and today running ticket
					INSERT INTO @Data
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetID,
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
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						0 AS odds,
						0 AS finalodds,
						0 AS finalodds2,
						0 AS OddsType,
						'Running' AS Status,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						SUM(blc.stake) AS stake,
						SUM(blc.actual_stake) AS actual_stake,
						b.transdate,
						'' AS betteam,
						AVG(blc.spositiontaking) AS spositiontaking,
						AVG(blc.mpositiontaking) AS mpositiontaking,
						AVG(blc.apositiontaking) AS apositiontaking,
						0 AS spositiontaking2,
						0 AS mpositiontaking2,
						0 AS apositiontaking2,
						0 AS liveindicator,
						0 AS modds,
						b.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 11 THEN 250
							WHEN s.ProductID = 21 THEN 211
							ELSE 0
						END AS Sporttype,
						b.ip,
						b.betfrom,
						0 AS matchid,
						CONVERT(BIT, 0) AS IsNeutral,
						0 AS allowdelete,
						0 AS WinLost,
						0 AS commission,
						0 AS scomm,
						0 AS acomm,
						0 AS comm,
						0 AS awinlost,
						0 AS mwinlost,
						0 AS swinlost,
						'' AS showtime,
						b.winlostdate,
						'' AS BetCheck,
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
					WHERE
						b.transid = @TransId
						AND s.ProductID IN (11, 21)
						AND blc.statusID IN (0, 1)
					GROUP BY
						b.transid,
						ISNULL(b.betid, 0),
						b.Bettype,
						b.refno,
						b.transdate,
						b.winlostdate,
						b.custid,
						b.ip,
						b.Username,
						b.betfrom,
						b.comstatus,
						s.ProductID

					-- Yesterday and today settled ticket
					INSERT INTO @Data
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetID,
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
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						0 AS odds,
						0 finalodds,
						0 finalodds2,
						0 AS OddsType,
						CASE 
							WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
							WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
							ELSE 'Draw'
						END AS Status,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						SUM(blc.stake) AS stake,
						SUM(blc.actual_stake) AS actual_stake,
						b.transdate,
						'' AS betteam,
						AVG(blc.spositiontaking) AS spositiontaking,
						AVG(blc.mpositiontaking) AS mpositiontaking,
						AVG(blc.apositiontaking) AS apositiontaking,
						0 AS spositiontaking2,
						0 AS mpositiontaking2,
						0 AS apositiontaking2,
						0 AS liveindicator,
						0 AS modds,
						b.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 11 THEN 250
							WHEN s.ProductID = 21 THEN 211
							ELSE 0
						END AS Sporttype,
						b.ip,
						b.betfrom,
						0 AS matchid,
						CONVERT(BIT, 0) AS IsNeutral,
						0 AS allowdelete,
						SUM(blc.winlost - blc.actual_stake) AS WinLost,
						SUM(blc.playercomm) AS commission,
						SUM(blc.scomm - blc.acomm) AS scomm,
						SUM(blc.acomm - blc.comm) AS acomm,
						SUM(blc.comm - blc.playercomm) AS comm,
						SUM(blc.awinlost) AS awinlost,
						SUM(blc.mwinlost) AS mwinlost,
						SUM(blc.swinlost) AS swinlost,
						'' AS showtime,
						b.winlostdate,
						'' AS BetCheck,
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
					WHERE
						b.transid = @TransId
						AND s.ProductID IN (11, 21)
						AND blc.statusID NOT IN (0, 1)
					GROUP BY
						b.transid,
						ISNULL(b.betid, 0),
						b.Bettype,
						b.refno,
						b.transdate,
						b.winlostdate,
						b.custid,
						b.ip,
						b.Username,
						b.betfrom,
						b.comstatus,
						s.ProductID
				END
				ELSE
				BEGIN
					-- Not yesterday and today settled ticket
					INSERT INTO @Data
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetID,
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
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						0 AS odds,
						0 AS finalodds,
						0 AS finalodds2,
						0 AS OddsType,
						b.status,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						b.stake,
						b.actual_stake,
						b.transdate,
						'' AS betteam,
						b.spositiontaking,
						b.mpositiontaking,
						b.apositiontaking,
						0 AS spositiontaking2,
						0 AS mpositiontaking2,
						0 AS apositiontaking2,
						0 AS liveindicator,
						0 AS modds,
						b.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 11 THEN 250
							WHEN s.ProductID = 21 THEN 211
							ELSE 0
						END AS Sporttype,
						b.ip,
						b.betfrom,
						0 AS matchid,
						CONVERT(BIT, 0) AS IsNeutral,
						0 AS allowdelete,
						(b.winlost - b.actual_stake) AS WinLost,
						b.playercomm AS commission,
						(b.scomm - b.acomm) AS scomm,
						(b.acomm - b.comm) AS acomm,
						(b.comm - b.playercomm) AS comm,
						b.awinlost,
						b.mwinlost,
						b.swinlost,
						'' AS showtime,
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
					WHERE b.transid = @TransId
						AND s.ProductID IN (11, 21)
				END
			END

			-- Colossus Bet
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID = 15 AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetID,
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
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					0 AS odds,
					0 finalodds,
					0 finalodds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0,
					0,
					0 AS leagueid,
					204 AS sporttype,
					b.ip,
					b.betfrom,
					0 AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
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
				WHERE b.transid = @TransId AND s.ProductID = 15
			END

			-- Get related Bonus/Cash tickets
			IF EXISTS ( SELECT 1 FROM @Data WHERE RefCode <> 0 )
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.BetID,0) AS BetID,
					b.refno,
					m.matchcode,
					'' AS race,
					m.eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					m.homeid,
					m.awayid,
					ISNULL(b.checktime,'') settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 finalodds,
					0 finalodds2,
					b.OddsType,
					CASE 
						WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
						ELSE b.status
					END AS status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 spositiontaking2,
					0 mpositiontaking2,
					0 apositiontaking2,
					b.liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					m.finalhomescore,
					m.finalawayscore,
					m.leagueid,
					m.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					CASE 
						WHEN b.bettype IN (SELECT typeid FROM @tableBettypeNotAllowDelete) OR statusID NOT IN (0, 1, 112, 113, 111) THEN 0 
						ELSE 1 
					END AS allowdelete,
					(b.winlost-b.actual_stake) AS winlost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					m.showtime,
					b.winlostdate,
					b.BetCheck,
					ISNULL(b.transdesc, '') AS transdesc,
					ISNULL(b.oddsspread, 0) AS OddsSpread,	-- For Myanmar Odds
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					ISNULL(b.WalletType, 0) AS WalletType,
					ISNULL(b.RefCode, 0) AS RefCode
				FROM
					dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @Data AS b1
						ON b.custid = b1.CustId
						AND b.winlostdate = b1.WinLostDate
						AND b.RefCode = b1.RefCode
						AND b.transid <> b1.transid
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			END
		END

		-- Bettrans14
		ELSE IF @WinLostDate <= @MoveBetsDay AND @WinLostDate >= @BalanceUpDay
		BEGIN
			-- Sportbooks, Number Game, Virtual Sports, Lucky 3, Betradar Virtual Sports
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE eventtype = 1 AND bettype = @BetType )
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetID,
					b.refno,
					m.matchcode,
					'' AS race,
					m.eventdate,
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
					ISNULL(b.checktime,'') settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 finalodds,
					0 finalodds2,
					b.OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 spositiontaking2,
					0 mpositiontaking2,
					0 apositiontaking2,
					b.liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					m.finalhomescore,
					m.finalawayscore,
					m.leagueid,
					m.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost - b.actual_stake)  winlost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					CASE
						WHEN s.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
						ELSE m.showtime
					END AS ShowTime,
					b.winlostdate,
					b.BetCheck,
					ISNULL(b.transdesc, '') AS transdesc,
					ISNULL(b.oddsspread, 0) AS OddsSpread,		-- For Myanmar Odds
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
				FROM
					dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.transid = @TransId AND s.EventType = 1

				-- Get more info for BetTrade tickets
				IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE SportType = 1 AND BetType = 901)
				BEGIN
					UPDATE b
					SET b.Odds = ob.odds,
						b.Stake = ob.stake,
						b.LiveHomeScore = ob.livehomescore,
						b.LiveAwayScore = ob.liveawayscore,
						b.BetId = ob.bettype
					FROM @Data AS b
						INNER JOIN dbo.bettrans14 AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
					WHERE b.SportType = 1 AND b.BetType = 901
				END

				IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE SportType = 1 AND BetType = 902)
				BEGIN
					UPDATE b
					SET b.Odds = ob.odds,
						b.Stake = ob.stake,
						b.LiveHomeScore = ob.livehomescore,
						b.LiveAwayScore = ob.liveawayscore,
						b.Comm = ISNULL(cb.awinlost, 0),
						b.BetId = ob.bettype
					FROM @Data AS b
						INNER JOIN dbo.bettrans14 AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
						LEFT JOIN dbo.bettrans14 AS cb WITH (NOLOCK)
							ON b.RefNo = cb.RefNo
							AND cb.BetType = 903
							AND cb.custid = @CustId
							AND cb.winlostdate = @WinLostDate
					WHERE b.SportType = 1 AND b.BetType = 902
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
						LEFT JOIN dbo.bettrans14 AS cb WITH (NOLOCK)
							ON b.RefNo = cb.refno
							AND cb.BetType = 913
							AND cb.custid = @CustId
							AND cb.winlostdate = @WinLostDate
					WHERE b.BetType = 912
				END
			END

			-- Mix Parlay, System Parlay, Mix Parlay (Betradar Virtual Sports)
			IF @BetType IN (9, 29, 2799)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					CASE
						WHEN (b.bettype = 29 AND ISNULL(b.betid, 0) > 0) THEN b.betid
						ELSE b.transid
					END AS transid,
					ISNULL(b.betid, 0) AS BetID,
					b.refno,
					'' matchcode,
					'' AS race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					sdiscount,
					adiscount,
					discount,
					0 AS homeid,
					0 AS awayid,
					'' settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 finalodds,
					0 finalodds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 spositiontaking2,
					0 mpositiontaking2,
					0 apositiontaking2,
					0 liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0,
					0,
					0 AS leagueid,
					0 AS sporttype,
					b.ip,
					b.betfrom,
					0 matchid,
					CONVERT(BIT,0) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
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
				WHERE b.transid = @TransId
					AND b.matchid IN (9, 29, 2799)
					AND b.bettype IN (9, 29, 2799)
			END

			-- Keno, Gold Deluxe, Microgaming Live Casino, Lottery
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE Bettype = @BetType AND ProductID IN (8, 12, 13, 28))
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetID,
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
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductID IN (8, 12, 28) THEN b.odds
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					CASE
						WHEN s.ProductID = 8 THEN 202
						WHEN s.ProductID = 12 THEN 255
						WHEN s.ProductID = 13 THEN 203
						WHEN s.ProductID = 28 THEN 220
						ELSE 0
					END AS sporttype,
					b.ip,
					b.betfrom,
					CASE
						WHEN s.ProductID = 12 THEN b.matchid
						ELSE 0
					END AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					CASE
						WHEN s.ProductID IN (12, 13) THEN b.betcheck
						ELSE ''
					END AS BetCheck,
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
				FROM dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.transid = @TransId
					AND s.ProductID IN (8, 12, 13, 28)
			END

			-- Outright
			IF @BetType = 10
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.BetID,0) AS BetID,
					b.refno,
					odds.matchcode,
					odds.groupmatch AS race,
					odds.eventdate AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					odds.teamid AS awayid,
					'' settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 finalodds,
					0 finalodds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,  
					b.stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 spositiontaking2,
					0 mpositiontaking2,
					0 apositiontaking2,
					b.liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0,
					0,
					odds.leagueid,
					l.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					CONVERT(BIT,0) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost - b.actual_stake) AS winlost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
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
					INNER JOIN dbo.outright14 AS odds WITH (NOLOCK) ON b.matchid = odds.orid
					INNER JOIN dbo.league l WITH (NOLOCK) ON odds.leagueid = l.leagueid
				WHERE b.bettype = 10 AND b.transid = @TransId
			END

			-- Virtual Horse Racing
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID = 5 AND EventType = 3 AND bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					'' AS BetID,
					b.refno,
					o.RacerNum matchcode, --Horse Number
					b.oddsid AS Race, --Outright ID
					'' eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					o.RacerID AS homeID,
					0 AS awayID,
					'' settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 finalodds,
					0 finalodds2,
					b.OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,  
					b.stake,
					b.actual_stake,
					b.transdate,
					'' betteam,
					CASE WHEN b.bettype = 1233 THEN bm.spositiontaking ELSE b.spositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.mpositiontaking ELSE b.mpositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.apositiontaking ELSE b.apositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.spositiontaking2 ELSE 0 END,
					CASE WHEN b.bettype = 1233 THEN bm.mpositiontaking2 ELSE 0 END,
					CASE WHEN b.bettype = 1233 THEN bm.apositiontaking2 ELSE 0 END,
					0 liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0 finalhomescore,
					0 finalawayscore,
					r.leagueid,
					r.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					CONVERT (BIT, 0) AS IsNeutral,
					CASE
						WHEN b.bettype IN (SELECT typeid FROM @tableBettypeNotAllowDelete)
							OR b.statusID NOT IN (0, 1, 112, 113, 111) THEN 0
						ELSE 1
					END AS allowdelete,
					(b.winlost - b.actual_stake) AS winlost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					r.EventTime showtime, -- Race Name
					b.winlostdate,
					b.BetCheck,
					'' AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM
					dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN dbo.VSOutright14 AS o WITH (NOLOCK) ON b.oddsid = o.Orid
					INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
					INNER JOIN @SportBettype AS s ON s.BetType = b.BetType 
					LEFT JOIN (
						SELECT
							t.refno,
							t.apositiontaking,
							t.mpositiontaking,
							t.spositiontaking,
							f.apositiontaking apositiontaking2,
							f.mpositiontaking mpositiontaking2,
							f.spositiontaking spositiontaking2
						FROM dbo.bettransm14 AS t WITH (NOLOCK)
						  INNER JOIN dbo.bettransm14 AS f WITH (NOLOCK) ON t.refno = f.refno
						WHERE t.bettype = 1231 AND f.bettype = 1232
						) bm ON b.refno = bm.refno
				WHERE b.transid = @TransId
					AND s.ProductID = 5
					AND s.EventType = 3
			END

			-- Colossus Bet
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID = 15 AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetID,
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
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					0 AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					204 AS sporttype,
					b.ip,
					b.betfrom,
					0 AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost - b.actual_stake) winlost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
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
				WHERE b.transid = @TransId AND s.ProductID = 15
			END

			-- Microgaming RNG Casino, AG Casino, RNG Casino Single Wallet, AllBet, Voidbridge, NG2, Fishing World
			IF EXISTS(	SELECT TOP(1) 1 FROM @SportBettype
						WHERE Bettype = @BetType
							AND (ProductID IN (11, 17, 21, 22, 23, 24) 
								OR (ProductID = 6 AND SubProduct <> '')))
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetId,
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
					'' AS settleTime,
					CASE
						WHEN s.ProductID = 23 THEN b.hdp1
						ELSE 0
					END AS hdp1,
					CASE
						WHEN s.ProductID = 23 THEN b.hdp2
						ELSE 0
					END AS hdp2,
					CASE
						WHEN s.ProductID = 23 THEN b.odds
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					CASE
						WHEN s.ProductID = 23 THEN b.livehomescore
						ELSE 0
					END AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					CASE
						WHEN s.ProductID = 6 THEN b.matchid
						WHEN s.ProductID = 11 THEN 250
						WHEN s.ProductID = 17 THEN 205
						WHEN s.ProductID = 21 THEN 211
						WHEN s.ProductID = 22 THEN 212
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2501 AND 2539 THEN 213
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2541 AND 2579 THEN 214
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2581 AND 2619 THEN 215
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2621 AND 2659 THEN 216
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2681 AND 2699 THEN 218
						WHEN s.ProductID = 24 THEN 219
						ELSE 0
					END AS sporttype,
					b.ip,
					b.betfrom,
					b.betdaqid AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					'' AS BetCheck,
					CASE
						WHEN s.ProductID IN (6, 22, 23, 24) THEN b.transdesc
						ELSE ''
					END AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.transid = @TransId
					AND (s.ProductID IN (11, 17, 21, 22, 23, 24)
						OR (ProductID = 6 AND SubProduct <> ''))
			END

			-- Bullfighting (EventType = 5) (bettrans14)
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE eventtype = 5 AND bettype = @BetType )
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetID,
					b.refno,
					m.MatchNo AS MatchCode,
					'' AS Race,
					m.EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					m.HomeId,
					m.AwayId,
					ISNULL(b.checktime, '') settleTime,
					0 AS Hdp1,
					0 AS Hdp2,
					b.odds,
					0 AS FinalOdds,
					0 AS FinalOdds2,
					b.oddstype,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					b.liveindicator,
					0 AS MOdds,
					b.custid,
					0 AS LiveHomeScore,
					0 AS LiveAwayScore,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					m.League3rdId AS LeagueId,
					m.SportType,
					b.ip,
					b.betfrom,
					b.matchid,
					0 AS IsNeutral,
					0 AS AllowDelete,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS ShowTime,
					b.winlostdate,
					ISNULL(b.betcheck, '') AS BetCheck,
					ISNULL(b.transdesc, '') AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM
					dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN dbo.Match3rd14 AS m WITH (NOLOCK) ON b.matchid = m.Match3rdId
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.transid = @TransId AND s.EventType = 5
			END

			-- Get related Bonus/Cash tickets
			IF EXISTS ( SELECT 1 FROM @Data WHERE RefCode <> 0 )
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.BetID,0) AS BetID,
					b.refno,
					m.matchcode,
					'' AS race,
					m.eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					m.homeid,
					m.awayid,
					ISNULL(b.checktime,'') settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 finalodds,
					0 finalodds2,
					b.OddsType,
					CASE 
						WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
						ELSE b.status
					END AS status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 spositiontaking2,
					0 mpositiontaking2,
					0 apositiontaking2,
					b.liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					m.finalhomescore,
					m.finalawayscore,
					m.leagueid,
					m.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					CASE 
						WHEN b.bettype IN (SELECT typeid FROM @tableBettypeNotAllowDelete) OR statusID NOT IN (0, 1, 112, 113, 111) THEN 0 
						ELSE 1 
					END AS allowdelete,
					(b.winlost-b.actual_stake) AS winlost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					m.showtime,
					b.winlostdate,
					b.BetCheck,
					ISNULL(b.transdesc, '') AS transdesc,
					ISNULL(b.oddsspread, 0) AS OddsSpread,	-- For Myanmar Odds
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					ISNULL(b.WalletType, 0) AS WalletType,
					ISNULL(b.RefCode, 0) AS RefCode
				FROM
					dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN @Data AS b1
						ON b.custid = b1.CustId
						AND b.winlostdate = b1.WinLostDate
						AND b.RefCode = b1.RefCode
						AND b.transid <> b1.transid
					INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
			END
		END

		-- bettrans_bk
		ELSE IF @WinLostDate < @BalanceUpDay 
		BEGIN
			-- Sportbooks, Number Game, Live Casino, Virtual Sports, Lucky 3, Betradar Virtual Sports
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE eventtype = 1 AND bettype = @BetType )
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.BetID,0) AS BetID,
					b.refno,
					m.matchcode,
					'' AS race,
					m.eventdate,
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
					ISNULL(b.checktime,'') settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 finalodds,
					0 finalodds2,
					b.OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 spositiontaking2,
					0 mpositiontaking2,
					0 apositiontaking2,
					b.liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					m.finalhomescore,
					m.finalawayscore,
					m.leagueid,
					m.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost - b.actual_stake) AS winlost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					CASE
						WHEN s.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
						ELSE m.showtime
					END AS ShowTime,
					b.winlostdate,
					b.BetCheck,
					ISNULL(b.transdesc, '') AS transdesc,
					ISNULL(b.oddsspread, 0) AS OddsSpread,	-- For Myanmar Odds
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
				FROM
					DBARC.bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					INNER JOIN DBARC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
					INNER JOIN @SportBettype AS s ON s.BetType = b.BetType
				WHERE b.transid = @TransId AND s.EventType = 1

				-- Get more info for BetTrade tickets
				IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE SportType = 1 AND BetType = 901)
				BEGIN
					UPDATE b
					SET b.Odds = ob.odds,
						b.Stake = ob.stake,
						b.LiveHomeScore = ob.livehomescore,
						b.LiveAwayScore = ob.liveawayscore,
						b.BetId = ob.bettype
					FROM @Data AS b
						INNER JOIN DBARC.bodb_Archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
					WHERE b.SportType = 1 AND b.BetType = 901
				END

				IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE SportType = 1 AND BetType = 902)
				BEGIN
					UPDATE b
					SET b.Odds = ob.odds,
						b.Stake = ob.stake,
						b.LiveHomeScore = ob.livehomescore,
						b.LiveAwayScore = ob.liveawayscore,
						b.Comm = ISNULL(cb.awinlost, 0),
						b.BetId = ob.bettype
					FROM @Data AS b
						INNER JOIN DBARC.bodb_Archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
						LEFT JOIN DBARC.bodb_Archive.dbo.bettrans_bk AS cb WITH (NOLOCK)
							ON b.RefNo = cb.RefNo
							AND cb.BetType = 903
							AND cb.custid = @CustId
							AND cb.winlostdate = @WinLostDate
					WHERE b.SportType = 1 AND b.BetType = 902
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
						INNER JOIN DBARC.bodb_Archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
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
						INNER JOIN DBARC.bodb_Archive.dbo.bettrans_bk AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
						INNER JOIN DBARC.bodb_Archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
						LEFT JOIN DBARC.bodb_Archive.dbo.bettrans_bk AS cb WITH (NOLOCK)
							ON b.RefNo = cb.RefNo
							AND cb.BetType = 913
							AND cb.custid = @CustId
							AND cb.winlostdate = @WinLostDate
					WHERE b.BetType = 912
				END
			END

			-- Mix Parlay, System Parlay, Mix Parlay (Betradar Virtual Sports)
			IF @BetType IN (9, 29, 2799)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					CASE
						WHEN (b.bettype = 29 AND ISNULL(b.betid, 0) > 0) THEN b.betid
						ELSE b.transid
					END AS transid,
					ISNULL(b.betid, 0) AS BetID,
					b.refno,
					'' matchcode,
					'' AS race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					sdiscount,
					adiscount,
					discount,
					0 AS homeid,
					0 AS awayid,
					'' settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 finalodds,
					0 finalodds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 spositiontaking2,
					0 mpositiontaking2,
					0 apositiontaking2,
					0 liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0,
					0,
					0 AS leagueid,
					0 AS sporttype,
					b.ip,
					b.betfrom,
					0 matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost - b.actual_stake) AS winlost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					ISNULL(b.betcheck, '') AS BetCheck,
					'' AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM DBARC.bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				WHERE b.transid = @TransId
					AND b.matchid IN (9, 29, 2799)
					AND b.bettype IN (9, 29, 2799)
			END

			-- RNG Casino, Bingo, Keno, Gold Deluxe, Microgaming Live Casino, Lottery
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype
						WHERE Bettype = @BetType 
							AND (ProductID IN (7, 8, 12, 13, 28)
								OR (ProductID = 6 AND SubProduct = '')))
			BEGIN
				INSERT INTO @Data
				SELECT
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
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductID IN (8, 12, 28) THEN b.odds
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					CASE
						WHEN s.ProductID = 6 THEN 251
						WHEN s.ProductID = 7 THEN 252
						WHEN s.ProductID = 8 THEN 202
						WHEN s.ProductID = 12 THEN 255
						WHEN s.ProductID = 13 THEN 203
						WHEN s.ProductID = 28 THEN 220
						ELSE 0
					END AS sporttype,
					b.ip,
					b.betfrom,
					CASE
						WHEN s.ProductID = 12 THEN b.matchid
						ELSE 0
					END AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					CASE
						WHEN s.ProductID IN (12, 13) THEN b.betcheck
						ELSE ''
					END AS BetCheck,
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
				FROM DBARC.bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.transid = @TransId
					AND (s.ProductID IN (7, 8, 12, 13, 28)
						OR (s.ProductID = 6 AND s.SubProduct = ''))
			END

			-- P2P
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID = 9 AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					bettype,
					b.transid,
					ISNULL(b.BetID,0) AS BetID,
					b.refno,
					'' matchcode,
					'' AS race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					sdiscount,
					adiscount,
					discount,
					0 AS homeid,
					0 AS awayid,
					'' settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 finalodds,
					0 finalodds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 spositiontaking2,
					0 mpositiontaking2,
					0 apositiontaking2,
					b.liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0,
					0,
					0 AS leagueid,
					253 AS sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					CONVERT(BIT,0) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost - b.actual_stake) AS winlost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					b.BetCheck,
					'' AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM DBARC.bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				WHERE b.transid = @TransId
					AND b.matchid = 1000
					AND b.bettype = 1000
			END

			-- Outright
			IF @BetType = 10
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.BetID,0) AS BetID,
					b.refno,
					odds.matchcode,
					odds.groupmatch AS race,
					odds.eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					odds.teamid AS awayid,  
					'' settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 finalodds,
					0 finalodds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 spositiontaking2,
					0 mpositiontaking2,
					0 apositiontaking2,
					b.liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0,
					0,
					odds.leagueid,
					l.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					CONVERT(BIT,0) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost - b.actual_stake)  winlost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					b.BetCheck,
					'' AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM DBARC.bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					INNER JOIN DBARC.bodb_archive.dbo.Outright_bk AS odds WITH (NOLOCK) ON b.matchid = odds.orid
					INNER JOIN dbo.league l WITH (NOLOCK) ON odds.leagueid = l.leagueid
				WHERE b.bettype = 10 AND b.transid = @TransId
			END

			-- Horse Racing
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID = 2 AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.BetID,0) AS BetID,
					b.refno,
					odds.matchcode,
					odds.groupmatch AS race,
					odds.eventdate,
					b.virtualrate,
					CASE WHEN b.currency2 IS NULL THEN CONVERT(BIT,0) ELSE CONVERT(BIT,1) END AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					odds.teamid AS homeid,
					0 AS awayid,
					'' settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					bm.finalodds,
					bm.finalodds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					CASE WHEN b.bettype IN (33,43) THEN bm.spositiontaking ELSE b.spositiontaking END,
					CASE WHEN b.bettype IN (33,43) THEN bm.mpositiontaking ELSE b.mpositiontaking END,
					CASE WHEN b.bettype IN (33,43) THEN bm.apositiontaking ELSE b.apositiontaking END,
					CASE WHEN b.bettype IN (33,43) THEN bm.spositiontaking2 ELSE 0 END,
					CASE WHEN b.bettype IN (33,43) THEN bm.mpositiontaking2 ELSE 0 END,
					CASE WHEN b.bettype IN (33,43) THEN bm.apositiontaking2 ELSE 0 END,
					b.liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0,
					0,
					odds.leagueid,
					l.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					CONVERT(BIT,0) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost - b.actual_stake)  winlost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					b.BetCheck,
					'' AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM DBARC.bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					INNER JOIN DBARC.bodb_archive.dbo.Outright_bk AS odds WITH (NOLOCK) ON b.matchid = odds.orid
					INNER JOIN dbo.league AS l WITH (NOLOCK) ON odds.leagueid = l.leagueid
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					LEFT JOIN (
						SELECT
							t.refno,
							t.apositiontaking,
							t.mpositiontaking,
							t.spositiontaking,
							t.finalodds,
							f.apositiontaking apositiontaking2,
							f.mpositiontaking mpositiontaking2,
							f.spositiontaking spositiontaking2,
							f.finalodds finalodds2
						FROM DBARC.bodb_archive.dbo.bettransm AS t WITH (NOLOCK)
							INNER JOIN DBARC.bodb_archive.dbo.bettransm AS f WITH (NOLOCK) ON t.refno = f.refno
						WHERE t.bettype IN (31,41) AND f.bettype IN (32,42)
						) bm ON b.transid = bm.refno
				WHERE s.ProductID = 2 AND b.transid = @TransId
				ORDER BY b.transid
			END

			-- Virtual Horse Racing
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID = 5 AND EventType = 3 AND bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					'' AS BetID,
					b.refno,
					o.RacerNum matchcode, --Horse Number
					b.oddsid AS Race, --Outright ID
					'' eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					o.RacerID AS homeID,
					0 AS awayID,
					'' settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 finalodds,
					0 finalodds2,
					b.OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' betteam,
					CASE WHEN b.bettype = 1233 THEN bm.spositiontaking ELSE b.spositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.mpositiontaking ELSE b.mpositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.apositiontaking ELSE b.apositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.spositiontaking2 ELSE 0 END,
					CASE WHEN b.bettype = 1233 THEN bm.mpositiontaking2 ELSE 0 END,
					CASE WHEN b.bettype = 1233 THEN bm.apositiontaking2 ELSE 0 END,
					0 liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0 finalhomescore,
					0 finalawayscore,
					r.leagueid,
					r.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					CASE
						WHEN b.bettype IN (SELECT typeid FROM @tableBettypeNotAllowDelete)
							OR b.statusID NOT IN (0, 1, 112, 113, 111) THEN 0
						ELSE 1
					END AS allowdelete,
					(b.winlost - b.actual_stake)  winlost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					r.EventTime showtime, -- Race Name
					b.winlostdate,
					b.BetCheck,
					'' AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM
					DBARC.bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					INNER JOIN DBARC.bodb_archive.dbo.VSOutright_bk AS o WITH (NOLOCK) ON b.oddsid = o.Orid
					INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
					INNER JOIN @SportBettype AS s ON s.BetType = b.BetType 
					LEFT JOIN (
						SELECT
							t.refno,
							t.apositiontaking,
							t.mpositiontaking,
							t.spositiontaking,
							f.apositiontaking apositiontaking2,
							f.mpositiontaking mpositiontaking2,
							f.spositiontaking spositiontaking2
						FROM DBARC.bodb_archive.dbo.bettransm AS t WITH (NOLOCK)
							INNER JOIN DBARC.bodb_archive.dbo.bettransm AS f WITH (NOLOCK) ON t.refno = f.refno
						WHERE t.bettype = 1231 AND f.bettype = 1232
						) bm ON b.refno = bm.refno
				WHERE b.transid = @TransId
					AND s.ProductID = 5
					AND s.EventType = 3
			END

			-- Colossus Bet
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID = 15 AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
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
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					0 AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0,
					0,
					0 AS leagueid,
					204 AS sporttype,
					b.ip,
					b.betfrom,
					0 AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost - b.actual_stake) winlost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					ISNULL(bm.betcheck, '') AS BetCheck,
					'' AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM DBARC.bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					LEFT JOIN DBARC.bodb_archive.dbo.bettransm AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
				WHERE b.transid = @TransId AND s.ProductID = 15
			END

			-- Microgaming RNG Casino, AG Casino, RNG Casino Single Wallet, AllBet, Voidbridge, NG2, Fishing World
			IF EXISTS (	SELECT TOP(1) 1 FROM @SportBettype
						WHERE Bettype = @BetType
							AND (ProductID IN (11, 17, 21, 22, 23, 24) 
								OR (ProductID = 6 AND SubProduct <> '')))
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.BetID, 0) AS BetId,
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
					'' AS settleTime,
					CASE
						WHEN s.ProductID = 23 THEN b.hdp1
						ELSE 0
					END AS hdp1,
					CASE
						WHEN s.ProductID = 23 THEN b.hdp2
						ELSE 0
					END AS hdp2,
					CASE
						WHEN s.ProductID = 23 THEN b.odds
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 spositiontaking2,
					0 mpositiontaking2,
					0 apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					CASE
						WHEN s.ProductID = 23 THEN b.livehomescore
						ELSE 0
					END AS livehomescore,
					0 AS liveawayscore,
					0,
					0,
					0 AS leagueid,
					CASE
						WHEN s.ProductID = 6 THEN b.matchid
						WHEN s.ProductID = 11 THEN 250
						WHEN s.ProductID = 17 THEN 205
						WHEN s.ProductID = 21 THEN 211
						WHEN s.ProductID = 22 THEN 212
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2501 AND 2539 THEN 213
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2541 AND 2579 THEN 214
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2581 AND 2619 THEN 215
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2621 AND 2659 THEN 216
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2681 AND 2699 THEN 218
						WHEN s.ProductID = 24 THEN 219
						ELSE 0
					END AS sporttype,
					b.ip,
					b.betfrom,
					b.betdaqid AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					'' AS BetCheck,
					CASE
						WHEN s.ProductID IN (6, 22, 23, 24) THEN b.transdesc
						ELSE ''
					END AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM DBARC.bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.transid = @TransId
					AND (s.ProductID IN (11, 17, 21, 22, 23, 24)
						OR (s.ProductID = 6 AND s.SubProduct <> ''))
			END

			-- Bullfighting (EventType = 5) (bettrans_bk)
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE eventtype = 1 AND bettype = @BetType )
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetID,
					b.refno,
					m.MatchNo AS MatchCode,
					'' AS Race,
					m.EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					m.HomeId,
					m.AwayId,
					ISNULL(b.checktime, '') settleTime,
					0 AS Hdp1,
					0 AS Hdp2,
					b.odds,
					0 AS FinalOdds,
					0 AS FinalOdds2,
					b.oddstype,
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					b.liveindicator,
					0 AS MOdds,
					b.custid,
					0 AS LiveHomeScore,
					0 AS LiveAwayScore,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					m.League3rdId AS LeagueId,
					m.SportType,
					b.ip,
					b.betfrom,
					b.matchid,
					0 AS IsNeutral,
					0 AS AllowDelete,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS ShowTime,
					b.winlostdate,
					ISNULL(b.betcheck, '') AS BetCheck,
					ISNULL(b.transdesc, '') AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM
					DBARC.bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					INNER JOIN DBARC.bodb_Archive.dbo.Match3rd_bk AS m WITH (NOLOCK) ON b.matchid = m.Match3rdId
					INNER JOIN @SportBettype AS s ON s.BetType = b.BetType
				WHERE b.transid = @TransId AND s.EventType = 5
			END

			-- Get related Bonus/Cash tickets
			IF EXISTS ( SELECT 1 FROM @Data WHERE RefCode <> 0 )
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.BetID,0) AS BetID,
					b.refno,
					m.matchcode,
					'' AS race,
					m.eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					m.homeid,
					m.awayid,
					ISNULL(b.checktime,'') settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 finalodds,
					0 finalodds2,
					b.OddsType,
					CASE 
						WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
						ELSE b.status
					END AS status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 spositiontaking2,
					0 mpositiontaking2,
					0 apositiontaking2,
					b.liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					m.finalhomescore,
					m.finalawayscore,
					m.leagueid,
					m.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					CASE 
						WHEN b.bettype IN (SELECT typeid FROM @tableBettypeNotAllowDelete) OR statusID NOT IN (0, 1, 112, 113, 111) THEN 0 
						ELSE 1 
					END AS allowdelete,
					(b.winlost-b.actual_stake) AS winlost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					m.showtime,
					b.winlostdate,
					b.BetCheck,
					ISNULL(b.transdesc, '') AS transdesc,
					ISNULL(b.oddsspread, 0) AS OddsSpread,	-- For Myanmar Odds
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					ISNULL(b.WalletType, 0) AS WalletType,
					ISNULL(b.RefCode, 0) AS RefCode
				FROM
					DBARC.bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					INNER JOIN @Data AS b1
						ON b.custid = b1.CustId
						AND b.winlostdate = b1.WinLostDate
						AND b.RefCode = b1.RefCode
						AND b.transid <> b1.transid
					INNER JOIN DBARC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
			END
		END
	END
	
	-- Don't display Cash text for ticket from Cash Wallet only
	UPDATE @Data
	SET WalletType = 0
	WHERE WalletType = 2 AND RefCode = 0

	-- Display Cash/Bonus text for ticket from multiple wallets
	UPDATE @Data
	SET RefCode = 0
	WHERE RefCode <> 0

	DECLARE @DetailData TABLE (
		RefNo			NVARCHAR(50),
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(50),
		APositionTaking	SMALLMONEY,
		MPositionTaking	SMALLMONEY,
		SPositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(50),
		TransDesc		VARCHAR(300)
	)

	-- Horse Racing
	IF EXISTS (	SELECT TOP(1) 1
				FROM @SportBettype AS sp
					INNER JOIN @Data AS d ON d.bettype = sp.bettype 
				WHERE sp.ProductID = 2)
	BEGIN
		IF @WinLostDate < @BalanceUpDay
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
			FROM DBARC.bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN @SportBettype AS sp ON bm.bettype = sp.bettype
				INNER JOIN @Data AS b ON bm.custid = b.CustId AND bm.refno = b.transid
			WHERE sp.ProductID = 2
		END
	END

	-- Live Casino
	IF EXISTS (	SELECT TOP(1) 1
				FROM @SportBettype AS sp
					INNER JOIN @Data AS d ON d.bettype = sp.bettype 
				WHERE sp.ProductID = 4)
	BEGIN
		IF @WinLostDate < @BalanceUpDay
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
			FROM DBARC.bodb_Archive.dbo.bettransg AS bg WITH (NOLOCK)
				INNER JOIN @SportBettype AS sp ON bg.bettype = sp.bettype
				INNER JOIN @Data AS b ON bg.custid = b.CustID AND bg.refno = b.refno AND bg.bettype = b.bettype
			WHERE sp.ProductID = 4
		END
	END

	-- Virtual Sports
	IF EXISTS (	SELECT TOP(1) 1
				FROM @SportBettype AS sp
					INNER JOIN @Data AS d ON d.bettype = sp.bettype
				WHERE sp.ProductID = 5 AND sp.EventType = 3)
	BEGIN
		IF @WinLostDate > @MoveBetsDay
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
				INNER JOIN @Data AS b ON bm.custid = b.CustId AND bm.refno = b.RefNo
			WHERE sp.ProductID = 5 AND sp.EventType = 3
		END
		ELSE IF @WinLostDate <= @MoveBetsDay AND @WinLostDate >= @BalanceUpDay
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
				INNER JOIN @Data AS b ON bm.custid = b.CustId AND bm.refno = b.RefNo
			WHERE sp.ProductID = 5 AND sp.EventType = 3
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
			FROM DBARC.bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN @SportBettype AS sp ON bm.bettype = sp.bettype
				INNER JOIN @Data AS b ON bm.custid = b.CustId AND bm.refno = b.RefNo
			WHERE sp.ProductID = 5 AND sp.EventType = 3
		END
	END

	-- Gold Deluxe
	IF EXISTS (	SELECT TOP(1) 1
				FROM @SportBettype AS sp
					INNER JOIN @Data AS d ON d.bettype = sp.bettype 
				WHERE sp.ProductID = 12)
	BEGIN
		IF @WinLostDate > @MoveBetsDay
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
				INNER JOIN @Data AS b ON bg.custid = b.CustId AND bg.refno = b.transid AND bg.bettype = b.bettype
			WHERE sp.ProductID = 12
		END
		ELSE IF @WinLostDate <= @MoveBetsDay AND @WinLostDate >= @BalanceUpDay
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
				INNER JOIN @Data AS b ON bg.custid = b.CustId AND bg.refno = b.transid AND bg.bettype = b.bettype
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
			FROM DBARC.bodb_Archive.dbo.bettransg AS bg WITH (NOLOCK)
				INNER JOIN @SportBettype AS sp ON bg.bettype = sp.bettype
				INNER JOIN @Data AS b ON bg.custid = b.CustId AND bg.refno = b.TransId AND bg.bettype = b.bettype
			WHERE sp.ProductID = 12
		END
	END
	
	-- BettransRnG tables
	SET @WinLostDate = NULL

	-- bettransRnG
	SELECT TOP(1)
		@TransId = b.transid,
		@WinLostDate = b.winlostdate,
		@BetType = b.gameID
	FROM dbo.bettransRnG AS b WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp ON b.gameID = sp.Bettype
	WHERE b.custid = @CustId AND b.transid = @RefNo

	-- bettransRnG14
	IF @WinLostDate IS NULL
	BEGIN
		SELECT TOP(1)
			@TransId = b.transid,
			@WinLostDate = b.winlostdate,
			@BetType = b.gameID
		FROM dbo.bettransRnG14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON b.gameID = sp.Bettype
		WHERE b.custid = @CustId AND b.transid = @RefNo
	END

	-- bettransRnG_bk
	IF @WinLostDate IS NULL
	BEGIN
		SELECT TOP(1)
			@TransId = b.transid,
			@WinLostDate = b.winlostdate,
			@BetType = b.gameID
		FROM DBARC.bodb_Archive.dbo.bettransRnG_bk AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON b.gameID = sp.Bettype
		WHERE b.custid = @CustId AND b.transid = @RefNo
	END

	IF @WinLostDate IS NOT NULL
	BEGIN
		-- bettransRnG
		IF @WinLostDate > @MoveBetsDay
		BEGIN
			-- Microgaming RNG Casino, RNG Casino Single Wallet, Macau Games, Fishing World
			IF EXISTS (	SELECT TOP(1) 1 FROM @SportBettype 
						WHERE Bettype = @BetType
							AND (ProductID IN (17, 22, 24)
								OR (ProductID = 6 AND SubProduct <> '')))
			BEGIN
				INSERT INTO @Data
				SELECT
					b.gameID AS BetType,
					b.transid,
					0 AS BetID,
					b.refno,
					CASE
						WHEN s.productID = 24 THEN b.Additional
						ELSE ''
					END AS MatchCode,
					'' AS race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					'' AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					b.productID AS Sporttype,
					b.ip,
					b.betfrom,
					0 AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					b.TranId3rd AS BetCheck,
					b.transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM dbo.bettransRnG AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				WHERE b.transid = @TransId
					AND (s.ProductId IN (17, 22, 24)
						OR (s.ProductId = 6 AND s.SubProduct <> ''))
			END
		END

		-- bettransRnG14
		ELSE IF @WinLostDate BETWEEN @BalanceUpDay AND @MoveBetsDay
		BEGIN
			-- Microgaming RNG Casino, RNG Casino Single Wallet, Macau Games, Fishing World
			IF EXISTS (	SELECT TOP(1) 1 FROM @SportBettype 
						WHERE Bettype = @BetType
							AND (ProductID IN (17, 22, 24)
								OR (ProductID = 6 AND SubProduct <> '')))
			BEGIN
				INSERT INTO @Data
				SELECT
					b.gameID AS BetType,
					b.transid,
					0 AS BetID,
					b.refno,
					CASE
						WHEN s.productID = 24 THEN b.Additional
						ELSE ''
					END AS MatchCode,
					'' AS race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					'' AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					b.productID AS Sporttype,
					b.ip,
					b.betfrom,
					0 AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					b.TranId3rd AS BetCheck,
					b.transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM dbo.bettransRnG14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				WHERE b.transid = @TransId
					AND (s.ProductId IN (17, 22, 24)
						OR (s.ProductId = 6 AND s.SubProduct <> ''))
			END
		END

		-- bettransRnG_bk
		ELSE IF @WinLostDate < @BalanceUpDay
		BEGIN
			-- Microgaming RNG Casino, RNG Casino Single Wallet, Macau Games, Fishing World
			IF EXISTS (	SELECT TOP(1) 1 FROM @SportBettype 
						WHERE Bettype = @BetType
							AND (ProductID IN (17, 22, 24)
								OR (ProductID = 6 AND SubProduct <> '')))
			BEGIN
				INSERT INTO @Data
				SELECT
					b.gameID AS BetType,
					b.transid,
					0 AS BetID,
					b.refno,
					CASE
						WHEN s.productID = 24 THEN b.Additional
						ELSE ''
					END AS MatchCode,
					'' AS race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					'' AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					b.productID AS Sporttype,
					b.ip,
					b.betfrom,
					0 AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					b.TranId3rd AS BetCheck,
					b.transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM DBARC.bodb_archive.dbo.bettransRnG_bk AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				WHERE b.custid = @CustId
					AND b.winlostdate = @WinLostDate
					AND b.transid = @TransId
					AND (s.ProductId IN (17, 22, 24)
						OR (s.ProductId = 6 AND s.SubProduct <> ''))
			END
		END
	END

	-- BettransLC tables
	SET @WinLostDate = NULL

	-- bettransLC
	SELECT TOP(1)
		@TransId = b.transid,
		@WinLostDate = b.winlostdate,
		@BetType = b.gameID
	FROM dbo.bettransLC AS b WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp ON b.gameID = sp.bettype
	WHERE b.custid = @CustId AND b.transid = @RefNo

	-- bettransLC14
	IF @WinLostDate IS NULL
	BEGIN
		SELECT TOP(1)
			@TransId = b.transid,
			@WinLostDate = b.winlostdate,
			@BetType = b.gameID
		FROM dbo.bettransLC14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON b.gameID = sp.bettype
		WHERE b.custid = @CustId AND b.transid = @RefNo
	END

	-- bettransLC_bk
	IF @WinLostDate IS NULL
	BEGIN
		SELECT TOP(1)
			@TransId = b.transid,
			@WinLostDate = b.winlostdate,
			@BetType = b.gameID
		FROM DBARC.bodb_archive.dbo.bettransLC_bk AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON b.gameID = sp.bettype
		WHERE b.custid = @CustId AND b.transid = @RefNo
	END

	IF @WinLostDate IS NOT NULL
	BEGIN
		-- bettransLC
		IF @WinLostDate > @MoveBetsDay
		BEGIN
			-- AG Casino, AllBet
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (11, 21) AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.gameID AS BetType,
					b.transid,
					0 AS BetID,
					b.refno,
					CASE
						WHEN s.ProductID = 21 THEN b.GameId3rd
						ELSE ''
					END AS matchcode,
					'' AS race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductID = 21 THEN b.odds
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					'' AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					b.productID AS Sporttype,
					b.ip,
					b.betfrom,
					0 AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					b.TranId3rd AS BetCheck,
					b.transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM dbo.bettransLC AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				WHERE b.transid = @TransId
					AND s.ProductID IN (11, 21)
			END
		END

		-- bettransLC14
		ELSE IF @WinLostDate BETWEEN @BalanceUpDay AND @MoveBetsDay
		BEGIN
			-- AG Casino, AllBet
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (11, 21) AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.gameID AS BetType,
					b.transid,
					0 AS BetID,
					b.refno,
					CASE
						WHEN s.ProductID = 21 THEN b.GameId3rd
						ELSE ''
					END AS matchcode,
					'' AS race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductID = 21 THEN b.odds
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					'' AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					b.productID AS Sporttype,
					b.ip,
					b.betfrom,
					0 AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					b.TranId3rd AS BetCheck, 
					b.transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM dbo.bettransLC14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				WHERE b.transid = @TransId
					AND s.ProductID IN (11, 21)
			END
		END

		-- bettransLC_bk
		ELSE IF @WinLostDate < @BalanceUpDay
		BEGIN
			-- AG Casino, AllBet
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (11, 21) AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.gameID AS BetType,
					b.transid,
					0 AS BetID,
					b.refno,
					CASE
						WHEN s.ProductID = 21 THEN b.GameId3rd
						ELSE ''
					END AS matchcode,
					'' AS race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductID = 21 THEN b.odds
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					'' AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					b.productID AS Sporttype,
					b.ip,
					b.betfrom,
					0 AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					b.TranId3rd AS BetCheck,
					b.transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM DBARC.bodb_archive.dbo.bettransLC_bk AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				WHERE b.custid = @CustId
					AND b.winlostdate = @WinLostDate
					AND b.transid = @TransId
					AND s.ProductID IN (11, 21)
			END
		END
	END

	SELECT b.*,
		ex.currency
	FROM @Data AS b
		LEFT JOIN dbo.custInfo AS ci WITH (NOLOCK) ON b.CustId = ci.custid
		LEFT JOIN dbo.Exchange AS ex WITH (NOLOCK) ON ci.currency = ex.exchangeid
	ORDER BY b.TransId

	SELECT * FROM @DetailData
END








GO
GRANT EXECUTE ON [dbo].[Acc_BetsSelBetList_ByTransID] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Acc_BetsSelBetList_ByTransID] TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BetsSelBetList_ByTransID] TO [vnteam] 
GO
