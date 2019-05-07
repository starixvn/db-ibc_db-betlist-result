/*<info serverAlias="DBARC-bodb_Archive" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetsSelBetList_Old]
	@FromDate	SMALLDATETIME,
	@ToDate		SMALLDATETIME,
	@CustId		INT,
	@BetType	INT = 0,
	@IsCN88			BIT = 0
AS

/*
	Created: 20100123@Henry
	Task: Get Bet List from Archive
	DB: DBARC.bodb_Archive
	Original:

	Revisions:
		- 20100123@Henry: Newly created
		- 20100409@Daniel: Support Mini game
		- 20100501@Daniel: Remove support Mini game, add agent W/L amount, agent's commission amount columns
		- 20100524@Jamie: Show currency2's exchange rate for OpenTote
		- 20100611@Henry: For mix-parlay, match value is either 0 OR 9
		- 20100907@Henry: Add IBC Bingo bettype
		- 20101007@Henry: Change column transid from INT to BIGINT
		- 20101130@Henry: Add column betid for number game
		- 20101201@Henry: Return winlost-actual_stake for column winlost
		- 20110408@Amy: Change function to get Odds value and odds type
		- 20110516@Lukas: re-arrange bettype
		- 20110524@Henry: change to use winlostdate instead of transdate
		- 20110711@Johnson: show exchange rate for SA Tote(Pool Currency)
		- 20110802@Johnson: Add new column actual_stake into betlist
						- Add new bettype combination mix parlay
		- 20111207@Sophia: Add P2P
		- 20120120@Sophia: Add Showtime for Table-hand-shoe of Live Casino
						   Add sub detail for Live Casino
		- 20120405@Hurri: Exclude bettype 72 (P2P bet ticket) in the calculation of Casino
		- 20120416@Johnson: Correct column transid for p2p
		- 20120418@Sophia: Edit sub detail for Live Casino
		- 20120423@Lukas: show transid of main ticket for all subticket of system parlay
		- 20120606@Sophia: Change datatype of stake to money
		- 20120626@Lukas: exclude outright from sportbook (in case of matchid = orid)
		- 20120629@Sophia: Remove function f_GetOddsByBettype, f_ShowOddsByBettype, f_GetChoice for odds, Oddstype, betteam
		- 20120927@Johnson: get commstatus column to check double comm losing
		- 20130226@Lukas: Move SP to bodb_archive
		- 20130227@Elodie: Add Virtual HR product
		- 20130408@Lukas: return value odds.teamid to alias name homeid instead of awayid
		- 20130724@Elodie: Get winlostdate field
		- 20140306@Dom: Add Keno
		- 20140908@Dom: [Redmine #22012] Update VS conditions
		- 20141103@Dom: Apply sport bettype matrix
		- 20150415@Sophia: Get Betcheck for Betradar
		- 20150506@Tom: Support Gold Deluxe Product [#34847]
		- 20150506@Bobby: Add transdesc column for metric gaming bettypes (801-899)
		- 20150615@Edward: Support for BetTrade
		- 20150625@Edward: Support for MicroGamming
		- 20150805@Bobby: Enhance code for SQL parameter sniffing
		- 20150826@Kos: Add OddsSpread column to support Myanmar Odds
		- 20150828@Kos: Support Colossus Bet
		- 20150930@Bobby: Enhance performance - re-arrange indexers
		- 20151008@Kos: Support Microgaming RNG Casino and AG Casino
		- 20151022@Kos: Return [bettransm].[betcheck] to support view CB ticket detail
		- 20151030@Kos: Change ProductId/SportType of Microgaming RNG Casino
		- 20151210@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20151214@Kos: Support Cockfighting (#Redmine: 48850)
		- 20151229@Kos: Support RNG Casino Single Wallet [Redmine: #48958]
		- 20160119@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160125@Kos: Fix Colossus Bet result issue
		- 20160204@Kos: Support AllBet [#Redmine: 50864]
		- 20160331@Kos: Support Voidbridge [#Redmine: 54925]
		- 20160407@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20160711@Kos: Change to use inline function for SportBettypeMatrix
		- 20160804@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20160810@Kos: Support NG2
		- 20161019@Kos: Support Fishing World [#Redmine: 65934]
		- 20170228@Kos: Support KickOffTime for Virtual Soccer and Virtual Tennis [#Redmine: 71906]
		- 20170315@Kos: Support CashOut [#Redmine: 71963]
		- 20170602@Kos: Get liveindicator from original ticket for 911 and 912 tickets [#Redmine: 77669]
		- 20170616@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20170629@Kos: Support Keno Lottery [#Redmine: 77929]
		- 20170718@Kos: Don't parse transdesc for Keno anymore [#Redmine: 80082]
		- 20170722@Kos: Hotfix - Does not show Betradar Virtual Sports ticket [#Redmine: 81925]
		- 20170829@Kos: Support Lucky 3 [#Redmine: 75277]
		- 20171023@Kos: Support Bullfighting [#Redmine: 84961]
		- 20171227@Kos: Return ticket detail of Racing and Virtual Horse Racing [#Redmine: 88775]
		- 20180118@Kos: Support Licensee Bonus System [#Redmine: 74978]
		- 20180305@Kos: Don't support Cockfighting anymore [#Redmine: 86086]
		- 20180308@Kos: Support Betradar Virtual Basketball [Redmine: #90616]
		- 20180323@Kos: Support ONERnG Jackpot [#Redmine: 88652]
		- 20180405@Kos: Support Pragmatic Casino [#Redmine: 92160]
		- 20180509@Kos: Support Keno 6 new Mini Games [#Redmine: 93759]
		- 20180515@Kos: Add Match No for Bullfighting [#Redmine: 84961]
		- 20180709@Kos: Support Poker Games [#Redmine: 97565]
		- 20190503@Kos: Show match KO time for single ticket [#Redmine: 112092]
		- 20190507@Kos: Support CN88 [Redmine: #112225]
					- Add new param @IsCN88 BIT
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #BetListData (
		BetType			SMALLINT,
		TransId			BIGINT,
		BetId			BIGINT,
		RefNo			NVARCHAR(50),
		MatchCode		NVARCHAR(50),
		Race			NVARCHAR(20),
		EventDate		SMALLDATETIME,
		VirtualRate		FLOAT,
		IsShowOTExRate	BIT,
		SDiscount		SMALLMONEY,
		ADiscount		SMALLMONEY,
		Discount		SMALLMONEY,
		PlayerDiscount	SMALLMONEY,
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
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		FinalHomeScore	SMALLINT,
		FinalAwayScore	SMALLINT,
		LeagueId		INT,
		SportType		SMALLINT,
		Ip				NVARCHAR(15),
		BetFrom			NVARCHAR (1),
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

	-- Get Sport Bettype Matrix
	CREATE TABLE #SportBettype (ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO #SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM bodb02.dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE @BetType = 0
		OR BetType = @BetType
		OR (BetType = 903 AND @BetType = 902)
		OR (BetType = 913 AND @BetType = 912)
	
	DELETE FROM #SportBettype
	WHERE Bettype IN (904, 914)
		OR ProductID IN (19)

	-- Add bettypes which have the same name
	IF EXISTS ( SELECT 1 FROM #SportBettype AS s
				WHERE s.Bettype IN (SELECT DISTINCT GroupTypeId FROM bodb02.dbo.f_GroupBetType3rd()))
	BEGIN
		INSERT INTO #SportBettype
		SELECT
			s.ProductID,
			f.BetType,
			s.EventType,
			s.SubProduct
		FROM #SportBettype AS s
			INNER JOIN (SELECT * FROM bodb02.dbo.f_GroupBetType3rd() WHERE BetType <> GroupTypeId) AS f ON s.Bettype = f.GroupTypeId
		WHERE NOT EXISTS ( SELECT 1 FROM #SportBettype AS sbt WHERE sbt.Bettype = f.Bettype )
	END

	IF EXISTS (SELECT TOP(1) 1 FROM #SportBettype WHERE ProductID IN (1, 3, 4, 5, 25, 26, 27))
	BEGIN
		/*
			EventType = 1
			- Sportsbook				: ProductID = 1
			- Number Game				: ProductID = 3
			- Live Casino				: ProductID = 4
			- Virtual Sports			: ProductID = 5
			- Cash Out					: ProductID = 25
			- Lucky 3					: ProductID = 26
			- Betradar Virtual Sports	: ProductID = 27
		*/
		INSERT INTO #BetListData
		SELECT
			b.bettype,
			b.transid,
			ISNULL(b.betid, 0),
			b.refno,
			m.matchcode,
			'' AS race,
			CASE
				WHEN s.ProductID = 1 THEN m.GlobalShowTime
				ELSE m.eventdate
			END AS EventDate,
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
			b.playerdiscount,
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
				WHEN @IsCN88 = 1 AND s.ProductID IN (1, 5, 27) AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
				WHEN @IsCN88 = 1 AND s.ProductID IN (1, 5, 27) AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
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
			0 AS allowdelete,
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
			dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
			INNER JOIN dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN #SportBettype AS s ON s.Bettype = b.bettype
		WHERE b.custid = @CustId
			AND b.winlostdate BETWEEN @FromDate AND @ToDate
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
				'' AS matchcode,
				'' AS race,
				'' AS eventdate,
				0,
				0,
				b.sdiscount,
				b.adiscount,
				b.discount,
				b.playerdiscount,
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
				b.betteam,
				b.spositiontaking,
				b.mpositiontaking,
				b.apositiontaking,
				0 AS spositiontaking2,
				0 AS mpositiontaking2,
				0 AS apositiontaking2,
				0 AS liveindicator,
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
				b.BetCheck,
				'' AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
				INNER JOIN #SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate BETWEEN @FromDate AND @ToDate
				AND b.matchid IN (0, 9, 29, 2799)
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
				b.playerdiscount,
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
				0 AS finalhomescore,
				0 AS finalawayscore,
				odds.leagueid,
				l.sporttype,
				b.ip,
				b.betfrom,
				b.matchid,
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
				b.BetCheck,
				'' AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettrans_bk AS b WITH (NOLOCK,INDEX=IX_custid)
				INNER JOIN dbo.outright_bk AS odds WITH (NOLOCK) ON b.matchid = odds.orid
				INNER JOIN bodb02.dbo.league AS l WITH (NOLOCK) ON odds.leagueid = l.leagueid
			WHERE b.custid = @CustId
				AND b.winlostdate BETWEEN @FromDate AND @ToDate
				AND b.bettype = 10
		END
	END

	-- RNG Casino, Bingo, Keno, P2P, Gold Deluxe, AG Casino, Microgaming Live Casino, Microgaming RNG Casino
	-- AllBet, Voidbridge, NG2, Fishing World, Lottery, Pragmatic Casino, Poker Games
	IF EXISTS (SELECT TOP(1) 1 FROM #SportBettype WHERE ProductID IN (6, 7, 8, 9, 11, 12, 13, 17, 21, 22, 23, 24, 28, 32, 33))
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
			b.playerdiscount,
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
				WHEN s.ProductId IN (6, 8, 12, 23, 28) THEN b.odds
				ELSE 0
			END AS odds,
			0 AS finalodds,
			0 AS finalodds2,
			0 AS OddsType,
			b.status,
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
				WHEN s.ProductID = 6 AND s.SubProduct = '' THEN 251
				WHEN s.ProductID = 6 AND s.SubProduct <> '' THEN b.matchid
				WHEN s.ProductId = 7 THEN 252
				WHEN s.ProductId = 8 THEN 202
				WHEN s.ProductId = 9 THEN 253
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
				WHEN s.ProductId = 12 THEN b.matchid
				WHEN s.ProductId = 23 THEN b.betdaqid
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
				WHEN s.ProductId IN (12, 13, 33) THEN b.BetCheck
				WHEN s.ProductId = 8 THEN ISNULL(b.comstatus, '')
				ELSE ''
			END AS BetCheck,
			CASE
				WHEN s.ProductID = 6 AND s.SubProduct <> '' THEN b.transdesc
				WHEN s.ProductId IN (8, 22, 23, 24, 28, 32) THEN b.transdesc
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
		FROM dbo.bettrans_bk AS b WITH (NOLOCK,INDEX=IX_custid)
			INNER JOIN #SportBettype AS s ON s.Bettype = b.bettype
		WHERE b.custid = @CustId
			AND b.winlostdate BETWEEN @FromDate AND @ToDate
			AND s.ProductId IN (6, 7, 8, 9, 11, 12, 13, 17, 21, 22, 23, 24, 28, 32, 33)
	END

	-- Horse Racing
	IF EXISTS (SELECT TOP(1) 1 FROM #SportBettype WHERE ProductID = 2)
	BEGIN
		INSERT INTO #BetListData 
		SELECT 
			b.bettype,
			b.transid,
			ISNULL(b.betid,0),
			b.refno,
			o.matchcode,
			o.groupmatch AS race,
			o.eventdate,
			b.virtualrate,
			CASE WHEN b.currency2 IS NULL THEN CONVERT(BIT,0) ELSE CONVERT(BIT,1) END AS isShowOTExRate,
			b.sdiscount,
			b.adiscount,
			b.discount,
			b.playerdiscount,
			o.teamid AS homeid,
			0 AS awayid,
			'' AS settleTime,
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
			0 AS finalhomescore,
			0 AS finalawayscore,
			o.leagueid,
			l.sporttype,
			b.ip,
			b.betfrom,
			b.matchid,
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
			b.BetCheck,
			'' AS transdesc,
			0 AS OddSpread,
			0 AS OriginalBetType,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS WalletType,
			0 AS RefCode
		FROM dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
			INNER JOIN dbo.outright_bk AS o WITH (NOLOCK) ON b.matchid = o.orid
			INNER JOIN bodb02.dbo.league AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
			INNER JOIN #SportBettype AS s ON s.Bettype = b.bettype
			OUTER APPLY (
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
				FROM dbo.bettransm AS t WITH (NOLOCK)
					INNER JOIN dbo.bettransm AS f WITH (NOLOCK) ON t.refno = f.refno
				WHERE t.refno = b.transid
					AND t.bettype IN (31, 41)
					AND f.bettype IN (32, 42)
			) bm
		WHERE b.custid = @CustId
			AND b.winlostdate BETWEEN @FromDate AND @ToDate
			AND s.ProductId = 2
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
			b.playerdiscount,
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
			0 AS allowdelete,
			(b.winlost - b.actual_stake) AS WinLost,
			b.playercomm AS commission,
			(b.scomm - b.acomm),
			(b.acomm - b.comm),
			(b.comm - b.playercomm),
			b.awinlost,
			b.mwinlost,
			b.swinlost,
			r.EventTime AS showtime, -- Race Name
			b.winlostdate,
			b.betcheck,
			'' AS transdesc,
			0 AS OddSpread,
			0 AS OriginalBetType,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS WalletType,
			0 AS RefCode
		FROM dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
			INNER JOIN dbo.VSOutright_bk AS o WITH (NOLOCK) ON b.oddsid = o.Orid
			INNER JOIN bodb02.dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
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
				FROM dbo.bettransm AS t WITH (NOLOCK)
					INNER JOIN dbo.bettransm AS f WITH (NOLOCK) ON t.refno = f.refno
				WHERE t.refno = b.refno
					AND t.bettype = 1231
					AND f.bettype = 1232
			) bm
		WHERE b.custid = @CustId
			AND b.winlostdate BETWEEN @FromDate AND @ToDate
			AND s.ProductId = 5
			AND s.EventType = 3
	END

	-- Colossus Bet
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
			b.playerdiscount,
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
			0 AS OddSpread,
			0 AS OriginalBetType,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS WalletType,
			0 AS RefCode
		FROM dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
			INNER JOIN #SportBettype AS s ON s.Bettype = b.bettype
			LEFT JOIN dbo.bettransm AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
		WHERE b.custid = @CustId
			AND b.winlostdate BETWEEN @FromDate AND @ToDate
			AND s.ProductId = 15
	END

	-- Bullfighting (EventType = 5) (bettrans_bk)
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
			b.playerdiscount,
			m.HomeId,
			m.AwayId,
			ISNULL(b.checktime, '') AS settleTime,
			b.hdp1,
			0 AS Hdp2,
			b.odds,
			0 AS FinalOdds,
			0 AS FinalOdds2,
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
			0 AS allowdelete,
			(b.winlost - b.actual_stake) AS WinLost,
			b.playercomm AS commission,
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
			dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
			INNER JOIN dbo.Match3rd_bk AS m WITH (NOLOCK) ON b.matchid = m.Match3rdId
			INNER JOIN #SportBettype AS s ON s.Bettype = b.bettype
		WHERE b.custid = @CustId
			AND b.winlostdate BETWEEN @FromDate AND @ToDate
			AND s.EventType = 5
	END

	-- Get more info for BetTrade tickets
	IF EXISTS (SELECT TOP(1) 1 FROM #BetListData WHERE BetType IN (901, 902, 903))
	BEGIN
		UPDATE betList
		SET betList.Odds = originBetList.Odds,
			betList.Stake = originBetList.Stake,
			betList.LiveHomeScore = originBetList.livehomescore,
			betList.LiveAwayScore = originBetList.liveawayscore,
			betList.Comm = CASE
								WHEN betList.BetType = 902 THEN ISNULL(commBetList.AWinLost, 0)
								ELSE betList.Comm END,
			betList.BetId = originBetList.bettype
		FROM #BetListData AS betList
			INNER JOIN dbo.bettrans_bk AS originBetList WITH (NOLOCK) ON betList.RefNo = originBetList.transid
			LEFT JOIN #BetListData AS commBetList ON betList.RefNO = commBetList.RefNo AND commBetList.BetType = 903
		WHERE betList.Bettype IN (901, 902)

		DELETE #BetListData
		WHERE Sporttype = 1 AND Bettype = 903
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
			INNER JOIN dbo.bettrans_bk AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
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
			INNER JOIN dbo.bettrans_bk AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
			INNER JOIN dbo.bettrans_bk AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
			LEFT JOIN #BetListData AS cb ON b.RefNo = cb.RefNo AND cb.BetType = 913
		WHERE b.BetType = 912

		DELETE #BetListData
		WHERE Bettype = 913
	END

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
	DECLARE @UGroup		VARCHAR(3),
		@CurrencyName	NVARCHAR(50),
		@Username		NVARCHAR(50)

	SELECT
		@Username = c.username,
		@UGroup = c.ugroup,
		@CurrencyName = ex.currency
	FROM bodb02.dbo.Customer AS c WITH (NOLOCK)
		INNER JOIN bodb02.dbo.Exchange AS ex WITH (NOLOCK) ON c.currency = ex.exchangeid
	WHERE c.custid = @CustId

	SELECT *,
		@CurrencyName AS Currency,
		@Username AS Username,
		@UGroup AS UGroup
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

	-- Horse Racing
	IF EXISTS (	SELECT TOP(1) 1
				FROM #SportBettype AS sp
					INNER JOIN #BetListData AS d ON d.bettype = sp.bettype
				WHERE sp.ProductID = 2)
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
			INNER JOIN bodb02.dbo.SportBettypeMatrix AS sp WITH (NOLOCK) ON bm.bettype = sp.bettype
			INNER JOIN #BetListData AS b ON bm.refno = b.TransId
		WHERE sp.Productid = 2 AND bm.custid = @CustId
	END

	-- Live Casino
	IF EXISTS (	SELECT TOP(1) 1
				FROM #SportBettype AS sp
					INNER JOIN #BetListData AS d ON d.bettype = sp.bettype
				WHERE sp.ProductID = 4)
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
			INNER JOIN #SportBettype AS sp ON bg.bettype = sp.bettype
			INNER JOIN #BetListData AS b ON bg.refno = b.RefNo AND bg.custid = b.CustId
		WHERE sp.Productid = 4
	END

	-- Virtual Sports
	IF EXISTS (	SELECT TOP(1) 1
				FROM #SportBettype AS sp
					INNER JOIN #BetListData AS d ON d.bettype = sp.bettype
				WHERE sp.ProductID = 5 AND sp.EventType = 3)
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
			INNER JOIN bodb02.dbo.SportBettypeMatrix AS sp WITH (NOLOCK) ON bm.bettype = sp.bettype
			INNER JOIN #BetListData AS b ON bm.refno = b.RefNo
		WHERE sp.ProductID = 5
			AND sp.EventType = 3
			AND bm.custid = @CustId
	END

	-- Gold Deluxe
	IF EXISTS (	SELECT TOP(1) 1
				FROM #SportBettype AS sp
					INNER JOIN #BetListData AS d ON d.bettype = sp.bettype
				WHERE sp.ProductID = 12)
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
			INNER JOIN #SportBettype AS sp ON bg.bettype = sp.bettype
			INNER JOIN #BetListData AS b ON bg.refno = b.TransId AND bg.custid = b.CustId
		WHERE sp.Productid = 12
	END

	SELECT * FROM #BetListDetailData
	ORDER BY RefNo

	DROP TABLE #BetListData;
	DROP TABLE #BetListDetailData;
	DROP TABLE #SportBettype
END
GO



GRANT EXECUTE ON [dbo].[Acc_BetsSelBetList_Old] TO [bodbAdminNet]
GO
