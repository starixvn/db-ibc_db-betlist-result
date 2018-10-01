/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet,bodbExtAccNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetsSelBetList]
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@CustId			INT,
	@BetType		INT = 0
AS

/*
	Created by: [Creator]
	Date: 2008
	Task: Bet List
	DB: DBAGE.bodb02
	
	Revisions:
		- 20060225@[]: remove refno
		- 20081223@PhuongNguyen: Get sdiscount, adiscount, discount, placing
		- 20081230@PhuongNguyen: Get livehomescore and liveawayscore, hdp1, hdp2
		- 20081231@PhuongNguyen: Remove placing
		- 20090109@PhuongNguyen: Get eventdate
		- 20090325@PhuongNguyen: out put AllowDelete base on bet type
		- 20090408@PhuongDao: Get checktime as SettleTime
		- 20090415@Daniel: Fix AllowDelete status for void and settled tickets
		- 20090416@KhoaTran: Get column BetFrom ( if befrom = p then 'no need to typ msg to delete' else 'need to type msg')
		- 20090509@Simon: Bet List For Casino
		- 20090517@KhoaTran: get column matchid
		- 20090528@PhuongDao: Get PT for Horseracing
		- 20091002@Simon: Get Odds && OddsType columns
		- 20091003@Jamie: Remove comstatus out 
		- 20091023@Simon: Displays Odds at Bet/Settle time
		- 20091205@Henry: Get more column: refno for viewing Mix Parlay detail
		- 20091229@Henry: Enhance Betlist by filtering: Bettype + support search in bettrans14
		- 20100409@Daniel: Support Mini game
		- 20100501@Daniel: Remove support Mini game, add agent W/L amount, agent's commission amount columns
		- 20100524@Jamie: Show currency2's exchange rate for OpenTote 
		- 20100525@Henry: Change to use StatusID instead of Status in WHERE statement
		- 20100611@Henry: Change mix-parlay match from 0 to 9
		- 20100907@Henry: Add IBC Bingo bettype
		- 20101007@Henry: Change column transid from INT to BIGINT
		- 20101130@Henry: Add column betid for number game
		- 20101201@Henry: Return winlost-actual_stake for column winlost
		- 20110408@Amy: Change function to get Odds value and odds type
		- 20110513@Lukas: re-arrange bettype
		- 20110524@Henry: change to use winlostdate instead of transdate
		- 20110711@Johnson: show exchange rate for SA Tote(Pool currency)
		- 20110802@Johnson: Add column actual_stake into betlist 
						- Add new bettype combination mix parlay
		- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
		- 20111207@Sophia: Add P2P
		- 20120120@Sophia: Add Showtime for Table-hand-shoe of Live Casino
							Add sub detail for Live Casino
		- 20120217@Daniel: Allow to delete mix palay bet (whole ticket)
		- 20120405@Hurri: Exclude bettype 72 (P2P bet ticket) in the calculation of Casino
		- 20120416@Johnson: Correct column transid for p2p
		- 20120423@Lukas: show transid of main ticket for all subticket of system parlay
		- 20120606@Sophia: Change datatype of stake to money
		- 20120626@Elodie: exclude outright, HR from sportbook ( in case of matchid = orid)
		- 20120629@Sophia: Remove function f_GetOddsByBettype, f_ShowOddsByBettype, f_GetChoice for odds, Oddstype, betteam
		- 20120927@Johnson: get commstatus column to check double comm losing
		- 20130227@Elodie: Add Virtual HR product
		- 20130405@Lukas: return value odds.teamid to alias name homeid instead of awayid
		- 20130718@Elodie: correct value of homeid and awayid
						   Get Winlostdate field
		- 20140306@Dom: Add Keno
		- 20140318@Dom: #13487 Prevent user to delete LAS ticket in bet list accounting site
		- 20140908@Dom: [Redmine #22012] Update VS conditions
		- 20141103@Dom: Apply sport bettype matrix
		- 20150122@Dom: HotFix #29646 Fix bug virtual HR
		- 20150415@Sophia: Get Betcheck for Betradar
		- 20150506@Tom: Support Gold Deluxe Product [#34847]
		- 20150506@Bobby: Add transdesc column for metric gaming bettypes (801-899)
		- 20150615@Edward: Support for BetTrade
		- 20150707@Bobby: Exclude Metric Gaming running ticket from bettrans table
		- 20150625@Edward: Support for Microgaming
		- 20150805@Bobby: Enhance code for SQL parameter sniffing
		- 20150825@Kos: Add OddsSpread column to support Myanmar Odds
		- 20150828@Kos: Support Colossus Bet
		- 20150930@Bobby: Enhance performance - re-arrange indexers
		- 20151008@Kos: Support Microgaming RNG Game and AG Casino
		- 20151022@Kos: Return [translog].[transid3rd] and [bettransm].[betcheck] to support view CB ticket detail
		- 20151030@Kos: Change ProductId/SportType of Microgaming RNG Casino
		- 20151207@Kos: Add index hint to fix performance issue
		- 20151210@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20151214@Kos: Remove LAS code
		- 20151214@Kos: Support Cockfighting (#Redmine: 48850)
		- 20151229@Kos: Support RNG Casino Single Wallet [Redmine: #48958]
		- 20160119@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160125@Kos: Fix Colossus Bet result issue
		- 20160129@Kos: Support RNG Casino Single Wallet yesterday running ticket
		- 20160204@Kos: Support AllBet [#Redmine: 50864]
		- 20160331@Kos: Support Voidbridge [#Redmine: 54925]
		- 20160407@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20160711@Kos: Change to use inline function for SportBettypeMatrix
		- 20160804@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20160810@Kos: Support NG2
		- 20161019@Kos: Remove Bingo and P2P in bettrans and bettrans14 range [#Redmine: 53988]
					  - Support Fishing World [#Redmine: 65934]
		- 20170228@Kos: Support KickOffTime for Virtual Soccer and Virtual Tennis [#Redmine: 71906]
		- 20170315@Kos: Support CashOut [#Redmine: 71963]
		- 20170602@Kos: Get liveindicator from original ticket for 911 and 912 tickets [#Redmine: 77669]
		- 20170616@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20170629@Kos: Support Keno Lottery [#Redmine: 77929]
		- 20170717@Kos: Don't parse transdesc for Keno anymore [#Redmine: 80082]
		- 20170829@Kos: Support Lucky 3 [#Redmine: 75277]
		- 20171020@Kos: Support Bullfighting [#Redmine: 84961]
		- 20171227@Kos: Return ticket detail of Racing and Virtual Horse Racing [#Redmine: 88775]
					- Don't support Live Casino in bettrans and bettrans14 anymore
		- 20180118@Kos: Support Licensee Bonus System [#Redmine: 74978]
		- 20180305@Kos: Don't support Racing, Cockfighting, RNG Casino (bettype 71, 72) anymore [#Redmine: 86086]
		- 20180308@Kos: Support Betradar Virtual Basketball [Redmine: #90616]
		- 20180323@Kos: Support ONERnG Jackpot [#Redmine: 88652]
		- 20180405@Kos: Support Pragmatic Casino [#Redmine: 92160]
		- 20180509@Kos: Support Keno 6 new Mini Games [#Redmine: 93759]
					- Fix duplicate data during Move Bet process
		- 20180515@Kos: Add Match No for Bullfighting [#Redmine: 84961]
		- 20180709@Kos: Support Poker Games [#Redmine: 97565]
		- 20181003@Helen: Modify code to adapt indexes changed on DB053 [Redmine:101405]
		- 20181011@Kos: Support new status Result Pending and Under Settlement [#Redmine: 101949]
*/

BEGIN
	SET NOCOUNT ON

	--list of bettype not allowed to delete
	DECLARE @tableBettypeNotAllowDelete TABLE(typeid INT NOT NULL)

	INSERT INTO @tableBettypeNotAllowDelete (typeid)
	SELECT 31 UNION ALL SELECT 32 UNION ALL SELECT 33 UNION ALL SELECT 41 UNION ALL SELECT 42 UNION ALL SELECT 43 UNION ALL
	SELECT 51 UNION ALL SELECT 52 UNION ALL SELECT 53 UNION ALL SELECT 54 UNION ALL SELECT 55 UNION ALL SELECT 56 UNION ALL
	SELECT 61 UNION ALL SELECT 62 UNION ALL SELECT 63 UNION ALL SELECT 64 UNION ALL SELECT 65 UNION SELECT 66
	--End

	-- Get Sport Bettype Matrix
	CREATE TABLE #SportBettype (ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO #SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE @BetType = 0
		OR BetType = @BetType
		OR (BetType = 903 AND @BetType = 902)
		OR (BetType = 913 AND @BetType = 912)

	DELETE FROM #SportBettype
	WHERE Bettype IN (904, 914)
		OR ProductID IN (2, 4, 7, 9, 19)
		OR (ProductID = 6 AND SubProduct = '')

	-- Add bettypes which have the same name
	IF EXISTS ( SELECT 1 FROM #SportBettype WHERE Bettype IN (SELECT DISTINCT GroupTypeId FROM f_GroupBetType3rd()))
	BEGIN
		INSERT INTO #SportBettype
		SELECT
			s.ProductID,
			f.BetType,
			s.EventType,
			s.SubProduct
		FROM #SportBettype AS s
			INNER JOIN (SELECT * FROM f_GroupBetType3rd() WHERE BetType <> GroupTypeId) AS f ON s.Bettype = f.GroupTypeId
		WHERE NOT EXISTS ( SELECT 1 FROM #SportBettype AS sbt WHERE sbt.Bettype = f.Bettype )
	END

	DECLARE @Today	SMALLDATETIME,
		@Yesterday	SMALLDATETIME

	SELECT @Today = DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0),
		@Yesterday = DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)

	CREATE TABLE #BetListData (
		BetType				INT,
		TransId				BIGINT,
		BetId				BIGINT,
		RefNo				NVARCHAR(50),
		MatchCode			NVARCHAR(50),
		Race				NVARCHAR(20),
		EventDate			SMALLDATETIME,
		VirtualRate			FLOAT,
		IsShowOTExRate		BIT,
		SDiscount			SMALLMONEY,
		ADiscount			SMALLMONEY,
		Discount			SMALLMONEY,
		HomeId				INT,
		AwayId				INT,
		SettleTime			DATETIME,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
		FinalOdds			MONEY,
		FinalOdds2			MONEY,
		OddsType			TINYINT,
		Status				NVARCHAR(50),
		SettlementStatus	TINYINT,
		ComStatus			NVARCHAR(50),
		Stake				MONEY,
		Actual_Stake		MONEY,
		TransDate			DATETIME,
		BetTeam				NVARCHAR(50),
		SPositionTaking		SMALLMONEY,
		MPositionTaking		SMALLMONEY,
		APositionTaking		SMALLMONEY,
		SPositionTaking2	SMALLMONEY,
		MPositionTaking2	SMALLMONEY,
		APositionTaking2	SMALLMONEY,
		LiveIndicator		BIT,
		Modds				MONEY,
		CustId				INT,
		LiveHomeScore		INT,
		LiveAwayScore		INT,
		FinalHomeScore		INT,
		FinalAwayScore		INT,
		LeagueId			INT,
		SportType			SMALLINT,
		Ip					NVARCHAR(15),
		BetFrom				NVARCHAR(1),
		MatchId				INT,
		IsNeutral			BIT,
		AllowDelete			BIT,
		WinLost				MONEY,
		Commission			MONEY,
		SComm				MONEY,
		AComm				MONEY,
		Comm				MONEY,
		AWinLost			MONEY,
		MWinLost			MONEY,
		SWinLost			MONEY,
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

	DECLARE @TempFromDate SMALLDATETIME,
		@TempToDate SMALLDATETIME

	IF @ToDate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		/* normal tickets
			- Sportsbook				: ProductID = 1
			- Number Game				: ProductID = 3
			- Virtual Sports			: ProductID = 5
			- Cash Out					: ProductID = 25
			- Lucky 3					: ProductID = 26
			- Betradar Virtual Sports	: ProductID = 27
		*/
		IF EXISTS (SELECT TOP(1) 1 FROM #SportBettype WHERE ProductID IN (1, 3, 5, 25, 26, 27))
		BEGIN
			INSERT INTO #BetListData
			SELECT
				b.bettype,
				b.transid,
				ISNULL(b.betid, 0),
				b.refno,
				m.matchcode,
				'' AS race,
				m.eventdate,
				0,
				0,
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
				ISNULL(b.checktime, '') settleTime,
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
				ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
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
				(b.winlost - b.actual_stake) AS winlost,
				b.playercomm AS commission,
				(b.scomm - b.acomm),
				(b.acomm - b.comm),
				(b.comm - b.playercomm),
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
			FROM 
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN #SportBettype AS s ON s.Bettype = b.bettype
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			WHERE b.custid = @CustId
				AND b.matchid > 0
				AND s.EventType = 1
				--exclude metric gaming running ticket
				AND (s.SubProduct NOT IN ('MG-SuperLive')
					OR (s.SubProduct IN ('MG-SuperLive') AND b.statusID NOT IN (0, 1)))
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate

			UNION ALL -- translog metric gaming
			SELECT
				b.gameid AS bettype,
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
				ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
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
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				CASE 
					WHEN b.gameID IN (SELECT typeid FROM @tableBettypeNotAllowDelete) 
						OR b.statusID NOT IN (0, 1, 112, 113, 111) THEN 0 
					ELSE 1 
				END AS allowdelete,
				0 AS winlost,
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
				INNER JOIN #SportBettype AS s ON b.gameid = s.Bettype
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.eventid = m.matchid
			WHERE
				b.custid = @CustId
				AND s.SubProduct IN ('MG-SuperLive')
				AND b.statusID IN (0, 1)
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate

			-- Mix Parlay, System Parlay, Mix Parlay (Betradar Virtual Sports)
			IF EXISTS (SELECT TOP(1) 1 FROM #SportBettype WHERE Bettype IN (9, 29, 2799))
			BEGIN
				INSERT INTO #BetListData
				SELECT
					b.bettype,
					CASE
						WHEN b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
						ELSE b.transid
					END AS TransId,
					ISNULL(b.betid, 0),
					b.refno,
					'' matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
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
					0 AS SettlementStatus,
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
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					0 AS sporttype,
					b.ip,
					b.betfrom,
					0 matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					CASE WHEN b.statusID IN (0, 1) THEN 1 ELSE 0 END AS allowdelete,
					(b.winlost - b.actual_stake)  winlost,
					b.playercomm AS commission,
					(b.scomm - b.acomm),
					(b.acomm - b.comm),
					(b.comm - b.playercomm),
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
					INNER JOIN #SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.custid = @CustId
					AND b.matchid IN (9, 29, 2799)
					AND b.bettype IN (9, 29, 2799)
					AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
			END

			-- Outright
			IF EXISTS (SELECT TOP(1) 1 FROM #SportBettype WHERE ProductID = 1 AND Bettype = 10)
			BEGIN
				INSERT INTO #BetListData
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0),
					b.refno,
					odds.matchcode,
					odds.groupmatch AS race,
					odds.eventdate,
					0,
					0,
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
					0 AS SettlementStatus,
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
					0 AS finalhomescore,
					0 AS finalawayscore,
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
					(b.winlost - b.actual_stake) AS winlost,
					b.playercomm AS commission,
					(b.scomm - b.acomm),
					(b.acomm - b.comm),
					(b.comm - b.playercomm),
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
					INNER JOIN dbo.league AS l WITH (NOLOCK) ON odds.leagueid = l.leagueid
				WHERE b.custid = @CustId
					AND b.matchid > 0
					AND b.bettype = 10
					AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
			END

			-- Get more info for BetTrade tickets
			IF EXISTS (SELECT TOP(1) 1 FROM #BetListData WHERE SportType = 1 AND BetType IN (901, 902))
			BEGIN
				UPDATE betList
				SET
					betList.Odds = originBetList.Odds,
					betList.Stake = originBetList.Stake,
					betList.LiveHomeScore = originBetList.livehomescore,
					betList.LiveAwayScore = originBetList.liveawayscore,
					betList.Comm = CASE
										WHEN betList.BetType = 902 THEN ISNULL(commBetList.AWinLost, 0)
										ELSE betList.Comm
									END,
					betList.BetId = originBetList.bettype
				FROM #BetListData AS betList
					INNER JOIN dbo.bettrans AS originBetList WITH (NOLOCK) ON betList.RefNo = originBetList.transid
					LEFT JOIN #BetListData AS commBetList ON betList.RefNo = commBetList.RefNo AND commBetList.BetType = 903
				WHERE betList.SportType = 1 AND betList.BetType IN (901, 902)
			END

			-- Get more info for CashOut tickets
			IF EXISTS (SELECT TOP(1) 1 FROM #BetListData WHERE BetType = 911)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.LiveIndicator = ob.liveindicator,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.OriginalBetType = ob.bettype,
					b.BetdaqId = ob.transid
				FROM #BetListData AS b
					INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
				WHERE b.BetType = 911
			END

			IF EXISTS (SELECT TOP(1) 1 FROM #BetListData WHERE BetType = 912)
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
				FROM #BetListData AS b
					INNER JOIN dbo.bettrans AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
					INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
					LEFT JOIN #BetListData AS cb ON b.RefNo = cb.RefNo AND cb.BetType = 913
				WHERE b.BetType = 912
			END
		END
		
		-- Keno, Gold Deluxe, Microgaming Live Casino, NG2, Lottery, Poker Games (bettrans)
		IF EXISTS (	SELECT TOP(1) 1 FROM #SportBettype
					WHERE ProductID IN (8, 12, 13, 23, 28, 33))
		BEGIN
			INSERT INTO #BetListData
			SELECT
				b.bettype,
				b.transid,
				ISNULL(b.betid, 0) AS betid,
				b.refno,
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
				CASE
					WHEN s.ProductId IN (8, 13, 28) THEN 0
					ELSE b.hdp1
				END AS hdp1,
				CASE
					WHEN s.ProductId IN (8, 13, 28) THEN 0
					ELSE b.hdp2
				END AS hdp2,
				CASE
					WHEN s.ProductId = 13 THEN 0
					ELSE b.odds
				END AS odds,
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
				CASE
					WHEN s.ProductId = 13 THEN ''
					ELSE b.betteam
				END AS betteam,
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
					WHEN s.ProductId IN (23, 33) THEN b.livehomescore
					ELSE 0
				END AS livehomescore,
				0 AS liveawayscore,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS leagueid,
				CASE
					WHEN s.ProductId = 8 THEN 202
					WHEN s.ProductId = 12 THEN 255
					WHEN s.ProductId = 13 THEN 203
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2501 AND 2539 THEN 213
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2541 AND 2579 THEN 214
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2581 AND 2619 THEN 215
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2621 AND 2659 THEN 216
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2681 AND 2699 THEN 218
					WHEN s.ProductID = 28 THEN 220
					WHEN s.ProductID = 33 THEN 163
					ELSE 0
				END AS sporttype,
				b.ip,
				b.betfrom,
				CASE
					WHEN s.ProductId = 12 THEN b.matchid
					WHEN s.ProductId = 23 THEN b.betdaqid
					ELSE 0
				END AS matchid,
				CONVERT(BIT, 0) AS IsNeutral,
				0 AS allowdelete,
				(b.winlost - b.actual_stake) AS winlost,
				b.playercomm AS commission,
				(b.scomm - b.acomm),
				(b.acomm - b.comm),
				(b.comm - b.playercomm),
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				'' AS showtime,
				b.winlostdate,
				CASE
					WHEN s.ProductId IN (12, 13, 33) THEN b.BetCheck
					WHEN s.ProductId = 8 THEN ISNULL(b.comstatus, '')
					ELSE ''
				END AS BetCheck,
				CASE
					WHEN s.ProductId IN (8, 23, 28) THEN ISNULL(b.transdesc, '')
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
				INNER JOIN #SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND s.ProductId IN (8, 12, 13, 23, 28, 33)
		END

		-- Virtual Horse Racing
		IF EXISTS (SELECT TOP(1) 1 FROM #SportBettype WHERE ProductID = 5)
		BEGIN
			INSERT INTO #BetListData
			SELECT
				b.bettype,
				b.transid,
				0 AS betid,
				b.refno,
				o.RacerNum AS matchcode,
				b.oddsid AS Race,
				'' AS eventdate,
				0,
				0,
				b.sdiscount,
				b.adiscount,
				b.discount,
				o.RacerID AS homeID, 
				0 AS awayID,
				'' settleTime,
				b.hdp1,
				b.hdp2,
				b.odds,
				0 AS finalodds,
				0 AS finalodds2,
				b.OddsType,
				b.status,
				0 AS SettlementStatus,
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
				0 AS liveindicator,
				b.modds,
				b.custid,
				b.livehomescore,
				b.liveawayscore,
				0 AS finalhomescore,
				0 AS finalawayscore,
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
				(b.scomm - b.acomm),
				(b.acomm - b.comm),
				(b.comm - b.playercomm),
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				r.EventTime showtime,
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
				INNER JOIN #SportBettype AS s ON s.BetType = b.BetType 
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
					WHERE t.custid = @custid
						AND t.winlostdate BETWEEN @FromDate AND @ToDate
						AND t.bettype = 1231
						AND f.bettype = 1232
				) bm ON b.refno = bm.refno
			WHERE b.custid = @CustId
				AND b.matchid > 0
				AND s.ProductID = 5
				AND s.eventtype = 3
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
		END

		-- Keno, Gold Deluxe, Microgaming Live Casino, Colossus Bets, Lottery (translog)
		IF EXISTS (SELECT TOP(1) 1 FROM #SportBettype WHERE ProductID IN (8, 12, 13, 15, 28))
		BEGIN
			INSERT INTO #BetListData
			SELECT
				b.gameid AS BetType,
				b.translogid AS TransId,
				0 AS BetId,
				b.translogid AS RefNo,
				'' AS MatchCode,
				'' AS Race,
				'' AS EventDate,
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
					WHEN s.ProductId IN (8, 12, 28) THEN b.odds
					ELSE 0
				END AS Odds,
				0 AS FinalOdds,
				0 AS FinalOdds2,
				0 AS OddsType,
				b.status,
				0 AS SettlementStatus,
				0 AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				CASE
					WHEN s.ProductId = 12 THEN b.GameID3rd
					ELSE ''
				END AS betteam,
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
					WHEN s.ProductId = 8 THEN 202
					WHEN s.ProductId = 12 THEN 255
					WHEN s.ProductId = 13 THEN 203
					WHEN s.ProductId = 15 THEN 204
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
				'' AS ShowTime,
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
				END AS TransDesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.translog AS b WITH (NOLOCK)
				INNER JOIN #SportBettype AS s ON s.Bettype = b.gameID
			WHERE b.custid = @CustId
				AND b.statusid IN (0, 1)
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND s.ProductID IN (8, 12, 13, 15, 28)
		END

		-- Bullfighting (EventType = 5) (bettrans)
		IF EXISTS (SELECT TOP(1) 1 FROM #SportBettype WHERE EventType = 5)
		BEGIN
			INSERT INTO #BetListData
			SELECT
				b.bettype,
				b.transid,
				ISNULL(b.betid, 0) AS BetId,
				b.refno,
				m.MatchNo AS MatchCode,
				'' AS Race,
				m.EventDate,
				0,
				0,
				b.sdiscount,
				b.adiscount,
				b.discount,
				m.HomeId,
				m.AwayId,
				ISNULL(b.checktime, '') settleTime,
				b.hdp1,
				0 AS Hdp2,
				b.odds,
				0 AS FinalOdds,
				0 AS FinalOdds2,
				b.OddsType,
				b.status,
				0 AS SettlementStatus,
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
				(b.winlost - b.actual_stake) AS winlost,
				b.playercomm AS commission,
				(b.scomm - b.acomm),
				(b.acomm - b.comm),
				(b.comm - b.playercomm),
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
				INNER JOIN #SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND s.EventType = 5
		END

		-- Bullfighting (EventType = 5) (translog)
		IF EXISTS (SELECT TOP(1) 1 FROM #SportBettype WHERE ProductID = 30)
		BEGIN
			INSERT INTO #BetListData
			SELECT
				b.gameid AS BetType,
				b.translogid AS TransId,
				0 AS BetId,
				b.translogid AS RefNo,
				m.MatchNo AS MatchCode,
				'' AS Race,
				m.EventDate,
				0,
				0,
				b.sdiscount,
				b.adiscount,
				b.discount,
				m.HomeId,
				m.AwayId,
				'' AS settleTime,
				CASE
					WHEN s.ProductID = 30 THEN CONVERT(SMALLMONEY, ISNULL(b.custom2, 0))
					ELSE 0
				END AS Hdp1,
				0 AS Hdp2,
				b.odds,
				0 AS FinalOdds,
				0 AS FinalOdds2,
				CASE
					WHEN s.ProductID = 30 THEN CONVERT(TINYINT, ISNULL(b.custom1, 0))
					ELSE 0
				END AS OddsType,
				b.status,
				0 AS SettlementStatus,
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
				'' AS ShowTime,
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
				INNER JOIN #SportBettype AS s ON s.Bettype = b.gameID
			WHERE b.custid = @CustId
				AND b.statusid IN (0, 1)
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND s.ProductID = 30
		END

		-- Microgaming RNG Casino, RNG Casino Single Wallet, Voidbridge, Fishing World, Pragmatic Casino
		IF EXISTS (	SELECT TOP(1) 1 FROM #SportBettype WHERE ProductID IN (6, 17, 22, 24, 32))
		BEGIN
			-- Before yesterday settled ticket
			INSERT INTO #BetListData
			SELECT
				b.bettype,
				b.transid,
				ISNULL(b.betid, 0),
				b.refno,
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
					WHEN s.ProductID = 6 THEN b.odds
					ELSE 0
				END AS Odds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				b.status,
				0 AS SettlementStatus,
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
					WHEN s.ProductID = 6 THEN b.matchid
					WHEN s.ProductID = 17 THEN 205
					WHEN s.ProductID = 22 THEN 212
					WHEN s.ProductID = 24 THEN 219
					WHEN s.ProductID = 32 THEN 248
					ELSE 0
				END AS Sporttype,
				b.ip,
				b.betfrom,
				0 AS matchid,
				CONVERT(BIT, 0) AS IsNeutral,
				0 AS allowdelete,
				(b.winlost - b.actual_stake) AS winlost,
				b.playercomm AS commission,
				(b.scomm - b.acomm),
				(b.acomm - b.comm),
				(b.comm - b.playercomm),
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				'' AS showtime,
				b.winlostdate,
				'' AS BetCheck,
				CASE
					WHEN s.ProductID IN (6, 22, 24, 32) THEN b.transdesc
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
				INNER JOIN #SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId 
				AND s.ProductId IN (6, 17, 22, 24, 32)
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.winlostdate < @Yesterday	-- before yesterday

			IF @ToDate >= @Yesterday
			BEGIN
				-- Yesterday and later running ticket
				INSERT INTO #BetListData
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0),
					b.refno,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					AVG(brng.sdiscount) AS sdiscount,
					AVG(brng.adiscount) AS adiscount,
					AVG(brng.discount) AS discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					0 AS Odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					'Running' AS Status,
					0 AS SettlementStatus,
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
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					CASE
						WHEN s.ProductID = 6 THEN b.matchid
						WHEN s.ProductID = 17 THEN 205
						WHEN s.ProductID = 22 THEN 212
						WHEN s.ProductID = 24 THEN 219
						WHEN s.ProductID = 32 THEN 248
						ELSE 0
					END AS Sporttype,
					b.ip,
					b.betfrom,
					0 AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					0 AS winlost,
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
						WHEN s.ProductID IN (6, 22, 24, 32) THEN b.transdesc
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
					INNER JOIN #SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.custid = @CustId 
					AND s.ProductId IN (6, 17, 22, 24, 32)
					AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
					AND b.winlostdate >= @Yesterday
					AND brng.statusID IN (0, 1)
				GROUP BY
					b.transid,
					ISNULL(b.BetID, 0),
					b.Bettype,
					b.refno,
					b.transdate,
					b.winlostdate,
					b.custid,
					b.IP,
					b.betfrom,
					b.comstatus,
					b.matchid,
					b.transdesc,
					s.ProductID
				OPTION (RECOMPILE)
			END

			IF @ToDate >= @Yesterday AND @FromDate <= @Today
			BEGIN
				-- Yesterday and today settled ticket
				INSERT INTO #BetListData
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0),
					b.refno,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					AVG(brng.sdiscount) AS sdiscount,
					AVG(brng.adiscount) AS adiscount,
					AVG(brng.discount) AS discount,
					0 AS homeid,
					0 AS awayid,
					'' settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductID = 6
							THEN ISNULL(AVG(CASE WHEN brng.statusID IN (111, 112, 113) THEN brng.ContributionRate END), 0)
						ELSE 0
					END AS Odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					CASE 
						WHEN SUM(brng.winlost - brng.actual_stake) > 0 THEN 'Won'
						WHEN SUM(brng.winlost - brng.actual_stake) < 0 THEN 'Lose'
						ELSE 'Draw'
					END AS Status,
					0 AS SettlementStatus,
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
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					CASE
						WHEN s.ProductID = 6 THEN b.matchid
						WHEN s.ProductID = 17 THEN 205
						WHEN s.ProductID = 22 THEN 212
						WHEN s.ProductID = 24 THEN 219
						WHEN s.ProductID = 32 THEN 248
						ELSE 0
					END AS Sporttype,
					b.ip,
					b.betfrom,
					0 AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					SUM(brng.winlost - brng.actual_stake) AS winlost,
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
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = b.transid
					INNER JOIN #SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.custid = @CustId 
					AND s.ProductId IN (6, 17, 22, 24, 32)
					AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
					AND b.winlostdate BETWEEN @Yesterday AND @Today
					AND brng.statusID NOT IN (0, 1)
				GROUP BY
					b.transid,
					ISNULL(b.betid, 0),
					b.Bettype,
					b.refno,
					b.transdate,
					b.winlostdate,
					b.custid,
					b.IP,
					b.betfrom,
					b.comstatus,
					b.matchid,
					b.transdesc,
					s.ProductID
				OPTION (RECOMPILE)
			END
		END

		-- AG Casino, AllBet
		IF EXISTS (SELECT TOP(1) 1 FROM #SportBettype WHERE ProductID IN (11, 21))
		BEGIN
			-- Before yesterday settled ticket
			INSERT INTO #BetListData
			SELECT
				b.bettype,
				b.transid,
				ISNULL(b.betid, 0),
				b.refno,
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
				0 AS odds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				b.status,
				0 AS SettlementStatus,
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
					WHEN s.ProductID = 11 THEN 250
					WHEN s.ProductID = 21 THEN 211
					ELSE 0
				END AS Sporttype,
				b.ip,
				b.betfrom,
				0 AS matchid,
				CONVERT(BIT, 0) AS IsNeutral,
				0 AS allowdelete,
				(b.winlost - b.actual_stake) AS winlost,
				b.playercomm AS commission,
				(b.scomm - b.acomm),
				(b.acomm - b.comm),
				(b.comm - b.playercomm),
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
				INNER JOIN #SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId 
				AND s.ProductId IN (11, 21)
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.winlostdate < @Yesterday

			IF @ToDate >= @Yesterday
			BEGIN
				-- Yesterday and later running ticket
				INSERT INTO #BetListData
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0),
					b.refno,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
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
					0 AS SettlementStatus,
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
					0 AS finalhomescore,
					0 AS finalawayscore,
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
					0 AS winlost,
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
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = b.transid
					INNER JOIN #SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.custid = @CustId 
					AND s.ProductId IN (11, 21)
					AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
					AND b.winlostdate >= @Yesterday
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
					b.betfrom,
					b.comstatus,
					s.ProductID
				OPTION (RECOMPILE)
			END

			IF @ToDate >= @Yesterday AND @FromDate <= @Today
			BEGIN
				-- Yesterday and today settled ticket
				INSERT INTO #BetListData
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0),
					b.refno,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
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
					CASE 
						WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
						WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
						ELSE 'Draw'
					END AS Status,
					0 AS SettlementStatus,
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
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					CASE
						WHEN s.ProductID = 11 THEN 250
						WHEN s.ProductID = 21 THEN 211
					END AS Sporttype,
					b.ip,
					b.betfrom,
					0 AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					SUM(blc.winlost - blc.actual_stake) AS winlost,
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
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = b.transid
					INNER JOIN #SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.custid = @CustId 
					AND s.ProductId IN (11, 21)
					AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
					AND b.winlostdate BETWEEN @Yesterday AND @Today
					AND blc.statusID NOT IN (0, 1)
				GROUP BY
					b.transid,
					ISNULL(b.BetID, 0),
					b.Bettype,
					b.refno,
					b.transdate,
					b.winlostdate,
					b.custid,
					b.IP,
					b.betfrom,
					b.comstatus,
					s.ProductID
				OPTION (RECOMPILE)
			END
		END

		-- Colossus Bets
		IF EXISTS (SELECT TOP(1) 1 FROM #SportBettype WHERE ProductID = 15)
		BEGIN
			INSERT INTO #BetListData
			SELECT
				b.bettype,
				b.transid,
				ISNULL(b.betid, 0),
				b.refno,
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
				0 AS odds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				b.status,
				0 AS SettlementStatus,
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
				(b.scomm - b.acomm),
				(b.acomm - b.comm),
				(b.comm - b.playercomm),
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
				INNER JOIN #SportBettype AS s ON s.Bettype = b.bettype
				LEFT JOIN dbo.bettransm AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
			WHERE b.custid = @CustId
				AND b.matchid = 204
				AND s.ProductId = 15
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
		END
	END

	IF @FromDate <= @MoveBetsDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @ToDate

		/* normal tickets 
			- Sportsbook				: ProductID = 1
			- Number Game				: ProductID = 3
			- Virtual Sports			: ProductID = 5
			- Cash Out					: ProductID = 25
			- Lucky 3					: ProductID = 26
			- Betradar Virtual Sports	: ProductID = 27
		*/
		IF EXISTS (SELECT TOP(1) 1 FROM #SportBettype WHERE ProductID IN (1, 3, 5, 25, 26, 27))
		BEGIN
			INSERT INTO #BetListData
			SELECT 
				b.bettype,
				b.transid,
				ISNULL(b.betid, 0),
				b.refno,
				m.matchcode,
				'' AS race,
				m.eventdate,
				0,
				0,
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
				ISNULL(b.checktime, '') settleTime,
				b.hdp1,
				b.hdp2,
				b.odds,
				0 finalodds,
				0 finalodds2,
				b.OddsType,
				b.status,
				0 AS SettlementStatus,
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
			FROM 
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN #SportBettype AS s ON s.Bettype = b.bettype
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
			WHERE b.custid = @CustId
				AND b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND b.matchid > 0
				AND s.EventType = 1

			-- Mix Parlay, System Parlay, Mix Parlay (Betradar Virtual Sports)
			IF EXISTS (SELECT TOP(1) 1 FROM #SportBettype WHERE Bettype IN (9, 29, 2799))
			BEGIN
				INSERT INTO #BetListData
				SELECT 
					b.bettype,
					CASE
						WHEN b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
						ELSE b.transid
					END AS TransId,
					ISNULL(b.betid, 0),
					b.refno,
					'' matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					b.sdiscount,
					b.adiscount,
					b.discount,
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
					0 AS SettlementStatus,
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
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					0 AS sporttype,
					b.ip,
					b.betfrom,
					0 matchid,
					CONVERT(BIT,0) AS IsNeutral,
					CASE WHEN b.statusID IN (0, 1) THEN 1 ELSE 0 END AS allowdelete,
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
				FROM dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN #SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.custid = @CustId
					AND b.winlostdate BETWEEN @FromDate AND @TempToDate
					AND b.matchid IN (9, 29, 2799)
					AND b.bettype IN (9, 29, 2799)
			END

			-- Outright
			IF EXISTS (SELECT TOP(1) 1 FROM #SportBettype WHERE ProductID = 1 AND Bettype = 10)
			BEGIN
				INSERT INTO #BetListData
				SELECT 
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0),
					b.refno,
					odds.matchcode, 
					odds.groupmatch AS race,
					odds.eventdate,
					0,
					0,
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
					0 AS SettlementStatus,
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
					0 AS finalhomescore,
					0 AS finalawayscore,
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
					INNER JOIN dbo.league AS l WITH (NOLOCK) ON odds.leagueid = l.leagueid
				WHERE b.custid = @CustId
					AND b.winlostdate BETWEEN @FromDate AND @TempToDate
					AND b.bettype = 10
					AND b.matchid > 0
			END

			-- Get more info for BetTrade tickets
			IF EXISTS (SELECT TOP(1) 1 FROM #BetListData WHERE SportType = 1 AND BetType IN (901, 902))
			BEGIN
				UPDATE betList
				SET betList.Odds = originBetList.Odds,
					betList.Stake = originBetList.Stake,
					betList.LiveHomeScore = originBetList.livehomescore,
					betList.LiveAwayScore = originBetList.liveawayscore,
					betList.comm = CASE
										WHEN betList.Bettype = 902 THEN ISNULL(commBetList.awinlost, 0)
										ELSE betList.comm
									END,
					betList.BetID = originBetList.Bettype
				FROM #BetListData AS betList
					INNER JOIN dbo.bettrans14 AS originBetList WITH (NOLOCK) ON betList.RefNo = originBetList.transid
					LEFT JOIN #BetListData AS commBetList ON betList.RefNO = commBetList.RefNo AND commBetList.BetType = 903
				WHERE betList.SportType = 1 AND betList.BetType IN (901, 902)
			END

			-- Get more info for CashOut tickets
			IF EXISTS (SELECT TOP(1) 1 FROM #BetListData WHERE BetType = 911)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.LiveIndicator = ob.liveindicator,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.OriginalBetType = ob.bettype,
					b.BetdaqId = ob.transid
				FROM #BetListData AS b
					INNER JOIN dbo.bettrans14 AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
				WHERE b.BetType = 911
			END

			IF EXISTS (SELECT TOP(1) 1 FROM #BetListData WHERE BetType = 912)
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
				FROM #BetListData AS b
					INNER JOIN dbo.bettrans14 AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
					INNER JOIN dbo.bettrans14 AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
					LEFT JOIN #BetListData AS cb ON b.RefNo = cb.RefNo AND cb.BetType = 913
				WHERE b.BetType = 912
			END
		END
		
		-- RNG Casino, Keno, Gold Deluxe, AG Casino, Microgaming Live Casino, Microgaming RNG Casino, AllBet
		-- Voidbridge, NG2, Fishing World, Lottery, Pragmatic Casino, Poker Games
		IF EXISTS(SELECT TOP(1) 1 FROM #SportBettype WHERE ProductID IN (6, 8, 11, 12, 13, 17, 21, 22, 23, 24, 28, 32, 33))
		BEGIN
			INSERT INTO #BetListData
			SELECT
				b.bettype,
				b.transid,
				ISNULL(b.betid, 0) AS betid,
				b.refno,
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
					WHEN s.ProductId IN (23, 33) THEN b.livehomescore
					ELSE 0
				END AS livehomescore,
				0 AS liveawayscore,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS leagueid,
				CASE
					WHEN s.ProductID = 6 THEN b.matchid
					WHEN s.ProductId = 8 THEN 202
					WHEN s.ProductId = 11 THEN 250
					WHEN s.ProductId = 12 THEN 255
					WHEN s.ProductId = 13 THEN 203
					WHEN s.ProductId = 17 THEN 205
					WHEN s.ProductId = 21 THEN 211
					WHEN s.ProductId = 22 THEN 212
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2501 AND 2539 THEN 213
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2541 AND 2579 THEN 214
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2581 AND 2619 THEN 215
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2621 AND 2659 THEN 216
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2681 AND 2699 THEN 218
					WHEN s.ProductId = 24 THEN 219
					WHEN s.ProductID = 28 THEN 220
					WHEN s.ProductID = 32 THEN 248
					WHEN s.ProductID = 33 THEN 163
					ELSE 0
				END AS sporttype,
				b.ip,
				b.betfrom,
				CASE
					WHEN s.ProductId = 12 THEN 255
					WHEN s.ProductId = 23 THEN b.betdaqid
					ELSE 0
				END AS matchid,
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
				CASE
					WHEN s.ProductId IN (12, 13, 33) THEN b.betcheck
					WHEN s.ProductId = 8 THEN ISNULL(b.comstatus, '')
					ELSE ''
				END AS BetCheck,
				CASE
					WHEN s.ProductId IN (6, 8, 22, 23, 24, 28, 32) THEN b.transdesc
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
				INNER JOIN #SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND s.ProductId IN (6, 8, 11, 12, 13, 17, 21, 22, 23, 24, 28, 32, 33)
		END

		-- Virtual Horse Racing
		IF EXISTS (SELECT TOP(1) 1 FROM #SportBettype WHERE ProductID = 5)
		BEGIN
			INSERT INTO #BetListData
			SELECT
				b.bettype,
				b.transid,
				0 AS betid,
				b.refno,
				o.RacerNum AS matchcode, --Horse Number
				b.oddsid AS Race, --Outright ID
				'' eventdate,
				0,
				0,
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
				0 AS SettlementStatus,
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
				(b.scomm - b.acomm),
				(b.acomm - b.comm),
				(b.comm - b.playercomm),
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
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.VSOutright14 AS o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN #SportBettype AS s ON s.BetType = b.BetType 
				OUTER APPLY (
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
					WHERE t.refno = b.refno
						AND t.bettype = 1231 
						AND f.bettype = 1232 
				) bm
			WHERE b.custid = @CustId
				AND b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND b.matchid > 0
				AND s.ProductId = 5
				AND s.EventType = 3
		END

		-- Bullfighting (EventType = 5) (bettrans14)
		IF EXISTS (SELECT TOP(1) 1 FROM #SportBettype WHERE EventType = 5)
		BEGIN
			INSERT INTO #BetListData
			SELECT
				b.bettype,
				b.transid,
				ISNULL(b.betid, 0) AS BetId,
				b.refno,
				m.MatchNo AS MatchCode,
				'' AS Race,
				m.EventDate,
				0,
				0,
				b.sdiscount,
				b.adiscount,
				b.discount,
				m.HomeId,
				m.AwayId,
				ISNULL(b.checktime, '') settleTime,
				b.hdp1,
				0 AS Hdp2,
				b.odds,
				0 AS FinalOdds,
				0 AS FinalOdds2,
				b.OddsType,
				b.status,
				0 AS SettlementStatus,
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
				(b.winlost - b.actual_stake) AS winlost,
				b.playercomm AS commission,
				(b.scomm - b.acomm),
				(b.acomm - b.comm),
				(b.comm - b.playercomm),
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
				INNER JOIN #SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND s.EventType = 5
		END

		--  Colossus Bets
		IF EXISTS (SELECT TOP(1) 1 FROM #SportBettype WHERE ProductID = 15)
		BEGIN
			INSERT INTO #BetListData
			SELECT
				b.bettype,
				b.transid,
				ISNULL(b.betid, 0),
				b.refno,
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
				0 AS odds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				b.status,
				0 AS SettlementStatus,
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
				ISNULL(bm.betcheck, '') AS BetCheck,
				'' AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN #SportBettype AS s ON s.Bettype = b.bettype
				LEFT JOIN dbo.bettransm14 AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
			WHERE b.custid = @CustId
				AND b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND b.matchid = 204 
				AND s.ProductId = 15
		END
	END

	DELETE #BetListData
	WHERE SportType = 1 AND BetType IN (903, 913)

	-- Get data for summary ticket of multiple Bonus/Cash sub tickets
	IF EXISTS (SELECT 1 FROM #BetListData WHERE RefCode <> 0)
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
		FROM #BetListData
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
			FROM #BetListData AS b
				INNER JOIN @RefCodeTmp AS r ON b.RefCode = r.RefCode AND b.TransId = r.TransId

			-- Delete 2nd Bonus/Cash tickets
			DELETE #BetListData
			WHERE WalletType <> 0
				AND RefCode IN (SELECT RefCode FROM @RefCodeTmp)
		END
	END

	-- Display detail link for ticket from Bonus Wallet only
	UPDATE #BetListData
	SET RefCode = TransId
	WHERE WalletType = 1 AND RefCode = 0

	-- Don't display Cash text for ticket from Cash Wallet only
	UPDATE #BetListData
	SET WalletType = 0
	WHERE WalletType = 2 AND RefCode = 0

	-- Get currency name
	DECLARE @CurrencyName NVARCHAR(50)

	SELECT @CurrencyName = ex.currency
	FROM dbo.custInfo AS ci WITH (NOLOCK)
		INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON ci.currency = ex.exchangeid
	WHERE ci.custid = @CustId

	SELECT *,
		@CurrencyName AS Currency
	FROM #BetListData
	ORDER BY TransId

	-- Get ticket detail
	CREATE TABLE #BetListDetailData (
		RefNo			VARCHAR(50),
		Odds			MONEY,
		Stake			MONEY,
		Status			VARCHAR(50),
		APositionTaking SMALLMONEY,
		MPositionTaking SMALLMONEY,
		SPositionTaking SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(50),
		TransDesc		VARCHAR(300)
	)

	-- Virtual Sports
	IF EXISTS (	SELECT TOP(1) 1
				FROM #SportBettype AS sp
					INNER JOIN #BetListData AS d ON d.bettype = sp.bettype
				WHERE sp.ProductID = 5 AND sp.EventType = 3)
	BEGIN
		IF @Todate > @MoveBetsDay
		BEGIN
			INSERT INTO #BetListDetailData
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
				INNER JOIN dbo.SportBettypeMatrix AS sp WITH (NOLOCK) ON bm.bettype = sp.bettype
				INNER JOIN #BetListData AS b ON bm.refno = b.RefNo
			WHERE sp.ProductID = 5
				AND sp.EventType = 3
				AND bm.custid = @CustId
		END

		IF @Fromdate <= @MoveBetsDay
		BEGIN
			INSERT INTO #BetListDetailData
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
				INNER JOIN dbo.SportBettypeMatrix AS sp WITH (NOLOCK) ON bm.bettype = sp.bettype
				INNER JOIN #BetListData AS b ON bm.refno = b.RefNo
			WHERE sp.ProductID = 5
				AND sp.EventType = 3
				AND bm.custid = @CustId
		END
	END

	-- Gold Deluxe
	IF EXISTS (	SELECT TOP(1) 1
				FROM #SportBettype AS sp
					INNER JOIN #BetListData AS d ON d.bettype = sp.bettype
				WHERE sp.ProductID = 12)
	BEGIN
		IF @Todate > @MoveBetsDay
		BEGIN
			INSERT INTO #BetListDetailData
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
				INNER JOIN #SportBettype AS sp ON bg.bettype = sp.Bettype
				INNER JOIN #BetListData AS b ON bg.refno = b.TransId AND bg.bettype = b.BetType
			WHERE sp.ProductID = 12
		END

		IF @Fromdate <= @MoveBetsDay
		BEGIN
			INSERT INTO #BetListDetailData
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
				INNER JOIN #SportBettype AS sp ON bg.bettype = sp.Bettype
				INNER JOIN #BetListData AS b ON bg.refno = b.TransId AND bg.bettype = b.BetType
			WHERE sp.ProductID = 12
		END 
	END

	SELECT DISTINCT * FROM #BetListDetailData
	ORDER BY RefNo

	DROP TABLE #BetListData
	DROP TABLE #BetListDetailData
	DROP TABLE #SportBettype
END
GO
GRANT	VIEW DEFINITION	ON	Acc_BetsSelBetList	TO	vnteam
GRANT	EXECUTE	ON	Acc_BetsSelBetList	TO	bodbExtAccNet
GRANT	EXECUTE	ON	Acc_BetsSelBetList	TO	bodbAdminNet
GO
