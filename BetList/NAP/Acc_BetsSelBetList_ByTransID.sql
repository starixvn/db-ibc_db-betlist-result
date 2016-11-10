USE bodb02
Go

ALTER PROCEDURE [dbo].[Acc_BetsSelBetList_ByTransID]
	@CustID			INT,
	@TransID		BIGINT,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME
AS

/*
	Created by: Henry
	Date: 2008 
	Task: Bet List By TransID
	DB: DBAGE.bodb02
	Original:  Acc_BetsSelBetList

	Revisions:
		- 20091229@[Henry]: newly created
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
		- 20110802@Johnson: - Add column actual_stake into betlist
		   - Add new bettype combination mix parlay
		- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
		- 20111207@Sophia: Add P2P  
		- 20120120@Sophia: Add Showtime for Table-hand-shoe of Live Casino
		   Add sub detail for Live Casino  
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
		- 20130726@Elodie: Define data for bettrans, bettrans14 or bettrans_bk by winlostdate field
						   Enhance performance
		- 20140307@Dom: Add Keno
		- 20140318@Dom: #13487 Prevent user to delete LAS ticket in bet list accounting site
		- 20140908@Dom: [Redmine #22012] Update VS conditions
		- 20141103@Dom: Apply sport bettype matrix
		- 20150122@Dom: HotFix #29646 Fix bug virtual HR
		- 20150415@Sophia: Get Betcheck for Betradar
		- 20150506@Tom: Support Gold Deluxe Product [#34847]
		- 20150506@Bobby: Add transdesc column for metric gaming bettypes (801-899)
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
*/

BEGIN

	SET NOCOUNT ON
	--list of bettype not allowed to delete
	DECLARE @tableBettypeNotAllowDelete TABLE(typeid INT NOT NULL)

	INSERT INTO @tableBettypeNotAllowDelete (typeid)
	SELECT 31 UNION ALL SELECT 32 UNION ALL SELECT 33 UNION ALL SELECT 41 UNION ALL SELECT 42 UNION ALL SELECT 43 UNION  ALL
	SELECT 51 UNION ALL SELECT 52 UNION ALL SELECT 53 UNION ALL SELECT 54 UNION ALL SELECT 55 UNION ALL SELECT 56 UNION  ALL
	SELECT 61 UNION ALL SELECT 62 UNION ALL SELECT 63 UNION ALL SELECT 64 UNION ALL SELECT 65 UNION SELECT 66  

	--End  

	DECLARE @refno BIGINT
	DECLARE @Data TABLE (
		BetType			INT,
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
		OddsSpread		SMALLMONEY
	)

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

	DECLARE @WinlostDate	SMALLDATETIME,
			@bettype		INT

	----Get Sport Bettype Matrix------
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM bodb02.dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID <> 1 OR Bettype <> 904

	-- FROM translog
	SELECT TOP 1 
		@WinlostDate	= bt.winlostdate
		, @bettype		= bt.gameID 
		, @refno 		= bt.translogid
	FROM dbo.translog AS bt WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp ON bt.gameID = sp.bettype
	WHERE bt.custid 	= @Custid
		AND translogid 	= @transid 
		AND statusID 	= 0
		AND ( sp.productid IN (8, 12, 13, 15, 19)
			OR sp.bettype BETWEEN 801 AND 899 )

	-- FROM bettrans
	IF @WinlostDate IS NULL
	BEGIN
		SELECT TOP 1 
			@WinlostDate	= bt.winlostdate
			, @bettype		= bt.bettype
			, @refno 		= bt.refno
		FROM dbo.bettrans AS bt WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON bt.bettype = sp.bettype
		WHERE bt.custid = @Custid
			AND (
				bt.transid = @transid 
				OR (
					bt.refno = @transid 
					AND (sp.productid IN (6, 7, 8, 9, 12, 13, 15, 19) OR sp.bettype BETWEEN 801 AND 899)
				)
			)
			--exclude metric gaming running ticket
			AND (bt.bettype NOT BETWEEN 801 AND 806 OR (bt.bettype BETWEEN 801 AND 806 AND bt.statusID NOT IN (0, 1)))
	END

	-- FROM bettrans14
	IF @WinlostDate IS NULL
	BEGIN
		SELECT TOP 1 
			@WinlostDate	= bt.winlostdate
			, @bettype		= bt.bettype 
			, @refno 		= bt.refno
		FROM dbo.bettrans14 AS bt WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON bt.bettype = sp.bettype
		WHERE bt.custid = @Custid
			AND (
				bt.transid = @transid 
				OR (
					bt.refno = @transid 
					AND (sp.productid IN (6, 7, 8, 9, 12, 13, 15, 19) OR sp.bettype BETWEEN 801 AND 899)
				)
			)
	END

	-- FROM bettrans_bk
	IF @WinlostDate IS NULL
	BEGIN
		SELECT TOP 1 
			@WinlostDate	= bt.winlostdate
			, @bettype 		= bt.bettype 
			, @refno 		= bt.refno
		FROM DBARC.bodb_archive.dbo.bettrans_bk bt WITH (NOLOCK)
			INNER JOIN @SportBettype sp ON bt.bettype = sp.bettype
		WHERE bt.custid = @Custid
			AND (
				bt.transid 	= @transid 
				OR (
					bt.refno = @transid 
					AND (sp.productid IN (6, 7, 8, 9, 12, 13, 15, 19) OR sp.bettype BETWEEN 801 AND 899)
				)
			)
	END

	IF @WinlostDate IS NOT NULL
	BEGIN
		-- Bettrans
		IF @WinlostDate > @MoveBetsDay
		BEGIN
			-- Sportbooks, Number Game, Live Casino, Virtual Sports
			IF EXISTS (SELECT TOP 1 1 FROM @SportBettype WHERE eventtype = 1 AND bettype = @bettype )
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
					stake,
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
						WHEN b.bettype IN (SELECT typeid FROM @tableBettypeNotAllowDelete) OR statusID NOT IN(0, 1, 112, 113, 111) THEN 0 
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
					ISNULL(b.oddsspread, 0) AS OddsSpread	-- For Myanmar Odds
				FROM
					dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid --phuong.nguyen, remove left join match_remark  
					INNER JOIN @SportBettype s ON s.Bettype = b.bettype
				WHERE
					b.custid = @Custid
					AND s.EventType = 1
					AND (b.transid = @TransID
						OR ( @bettype BETWEEN 801 AND 899 AND b.refno = @refno ))
					--exclude metric gaming running ticket
					AND (b.bettype NOT BETWEEN 801 AND 806 
						OR (b.bettype BETWEEN 801 AND 806 AND b.statusID NOT IN (0, 1)))
				
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
					CASE WHEN b.gameid IN (801,803,804,805,806) THEN CONVERT(TINYINT, ISNULL(b.custom1, 0)) ELSE 0 END AS OddsType,
					b.status,
					0 AS comstatus,
					stake,
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
						WHEN b.gameID IN (SELECT typeid FROM @tableBettypeNotAllowDelete) OR statusID NOT IN(0, 1, 112, 113, 111) THEN 0 
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
					0 AS OddsSpread
				FROM   
					dbo.translog AS b WITH (NOLOCK) 
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.eventid = m.matchid
					INNER JOIN @SportBettype s ON s.Bettype = b.gameid
				WHERE
					b.custid = @Custid 
					AND s.Bettype BETWEEN 801 AND 899
					AND b.translogid = @TransID 
					AND b.statusID IN (0,1)
		
				UPDATE betList
				SET betList.Odds	= originBetList.Odds
					,betList.Stake	= originBetList.Stake
					,betList.comm	= CASE WHEN betList.Bettype = 902 THEN ISNULL(commBetList.awinlost,0) ELSE betList.comm END
					,betList.BetID	= originBetList.Bettype
				FROM @Data AS betList
					INNER JOIN dbo.bettrans AS originBetList WITH (NOLOCK) ON betList.RefNO = originBetList.TransID
					LEFT JOIN @Data AS commBetList ON betList.RefNO = commBetList.RefNO AND commBetList.Bettype = 903
				WHERE betList.Sporttype = 1 AND betList.Bettype IN (901, 902)
			END

			-- Mix Parlay
			IF @bettype = 9
			BEGIN
				INSERT INTO @Data
				SELECT
					9 bettype,
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
					CASE WHEN statusID = 0 THEN 1 ELSE 0 END AS allowdelete,
					(b.winlost-b.actual_stake)  winlost,
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
					0 AS OddsSpread
				FROM dbo.bettrans AS b WITH (NOLOCK)
				WHERE
					b.custid = @Custid
					AND matchid = 9
					AND bettype = 9
					AND b.transid = @TransID
			END

			-- Combination Mix Parlay
			IF @bettype = 29
			BEGIN
				SELECT @refno = refno
				FROM dbo.bettrans b WITH(NOLOCK)
				WHERE b.custid = @Custid
					AND matchid = 29
					AND bettype = 29
					AND b.transid = @TransID
			END

			-- Casino, Bingo, Gold Deluxe, Microgaming Live Casino, Cockfighting
			IF EXISTS (SELECT TOP 1 1 FROM  @SportBettype s 
						WHERE (ProductID IN (7, 12, 13, 19)
								OR (ProductID = 6 AND SubProduct = ''))
							AND Bettype = @Bettype)
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
						WHEN s.ProductID IN (12, 19) THEN b.odds
						ELSE 0
					END AS odds,
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
						WHEN s.ProductID = 6 THEN 251
						WHEN s.ProductID = 7 THEN 252
						WHEN s.ProductID = 12 THEN 255
						WHEN s.ProductID = 13 THEN 203
						WHEN s.ProductID = 19 THEN 206
					END AS sporttype,
					b.ip,
					b.betfrom,
					CASE
						WHEN s.ProductID = 12 THEN b.matchid
						WHEN s.ProductID = 19 THEN b.betdaqid
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
						WHEN s.ProductID IN (12, 13, 19) THEN b.betcheck
						ELSE ''
					END AS BetCheck,
					CASE
						WHEN s.ProductID = 19 THEN b.transdesc
						ELSE ''
					END AS transdesc,
					0 AS OddsSpread
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.custid = @Custid
					AND (s.ProductId IN (7, 12, 13, 19)
						OR (s.ProductId = 6 AND s.SubProduct = ''))
					AND b.refno = @refno
			END

			-- NG2
			IF EXISTS (SELECT TOP 1 1 FROM  @SportBettype WHERE ProductID = 23 AND Bettype = @Bettype)
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
					END AS sporttype,
					b.ip,
					b.betfrom,
					b.betdaqid AS matchid,
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
					'' AS BetCheck,
					ISNULL(b.transdesc, '') AS transdesc,
					0 AS OddsSpread
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.custid = @Custid
					AND s.ProductId = 23
					AND b.transid = @transid
			END

			-- Keno
			IF EXISTS (SELECT TOP 1 1 FROM  @SportBettype s WHERE ProductID = 8 AND Bettype = @Bettype)
			BEGIN
				INSERT INTO @Data
				SELECT
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
					d.ChoiceId AS betteam,
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
					0 AS leagueid,
					202 AS sporttype,
					b.ip,
					b.betfrom,
					d.GameId matchid,
					CONVERT(BIT,0) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost-b.actual_stake)  winlost,
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
					0 AS OddsSpread
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					OUTER APPLY dbo.[f_ParseTransDesc](b.TransDesc, b.bettype) d
				WHERE
					b.custid = @Custid
					AND s.ProductID = 8
					AND b.refno = @refno
				UNION ALL	-- translog
				SELECT 
					b.gameid AS bettype,
					0 AS transid,
					0 AS betid,
					b.translogid,
					'' AS matchcode,
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
					0 AS hdp1,
					0 AS hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					0 AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					d.ChoiceId betteam,
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
					202 AS sporttype,
					b.ip,
					b.betfrom,
					d.GameId matchid,
					CONVERT(BIT,0) AS IsNeutral,
					0 AS allowdelete,
					(-b.actual_stake) AS winlost,
					0 AS commission,
					0,
					0,
					0,
					0,
					0,
					0,
					'' AS showtime,
					b.winlostdate,
					'' AS BetCheck,
					'' AS transdesc,
					0 AS OddsSpread
				FROM dbo.translog AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
					OUTER APPLY dbo.[f_ParseTransDesc](b.TransDesc, b.gameid) d
				WHERE	b.custid = @Custid
					AND s.ProductID = 8
					AND b.statusID = 0
					AND b.translogid = @TransID
			END

			-- P2P
			IF EXISTS (SELECT TOP 1 1 FROM  @SportBettype s WHERE ProductID = 9 AND Bettype = @Bettype)
			BEGIN
				INSERT INTO @Data
				SELECT
					bettype,
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
					(b.winlost-b.actual_stake) AS winlost,
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
					0 AS OddsSpread
				FROM dbo.bettrans AS b WITH (NOLOCK)
				WHERE
					b.custid = @Custid
					AND matchid = 1000
					AND bettype = 1000
					AND b.transid = @TransID
			END

			-- Outright
			IF @bettype = 10
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
					b.ip ,
					b.betfrom,
					b.matchid,
					CONVERT(BIT,0) AS IsNeutral,
					CASE WHEN b.bettype IN (SELECT typeid FROM @tableBettypeNotAllowDelete) OR b.statusID NOT IN(0, 1, 112, 113, 111) THEN 0 ELSE 1 END AS allowdelete,  
					(b.winlost-b.actual_stake)  winlost,
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
					0 AS OddsSpread
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.outright AS odds WITH (NOLOCK) ON b.matchid = odds.orid
					INNER JOIN dbo.league l WITH (NOLOCK) ON odds.leagueid = l.leagueid
				WHERE b.bettype = 10
					AND b.custid = @Custid
					AND b.transid = @TransID
			END

			-- HR
			IF EXISTS (SELECT TOP 1 1 FROM  @SportBettype s WHERE ProductID = 2 AND Bettype = @Bettype)
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
					0,
					0,
					odds.leagueid,
					l.sporttype,
					b.ip ,
					b.betfrom,
					b.matchid,
					CONVERT(BIT,0) AS IsNeutral,
					CASE 
						WHEN b.bettype IN (SELECT typeid FROM @tableBettypeNotAllowDelete) OR b.statusID NOT IN(0, 1, 112, 113, 111) THEN 0 
						ELSE 1 
					END AS allowdelete,
					(b.winlost-b.actual_stake)  winlost,
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
					0 AS OddsSpread
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.outright AS odds WITH (NOLOCK) ON b.matchid = odds.orid
					INNER JOIN dbo.league l WITH (NOLOCK) ON odds.leagueid = l.leagueid
					INNER JOIN @SportBettype s ON s.Bettype = b.bettype  
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
						FROM dbo.bettransm AS t WITH (NOLOCK)
							INNER JOIN dbo.bettransm AS f WITH (NOLOCK) ON t.refno = f.refno
						WHERE t.bettype IN (31,41) AND f.bettype IN (32,42)
						) bm ON b.transid = bm.refno
				WHERE s.ProductID = 2
					AND b.custid = @Custid
					AND b.transid = @TransID
			END

			-- Virtual HR
			IF EXISTS(SELECT TOP 1 1 FROM @SportBettype s WHERE s.ProductID = 5 AND s.EventType = 3 AND s.bettype = @bettype)
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
					stake,
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
						WHEN b.bettype IN (SELECT typeid FROM @tableBettypeNotAllowDelete) OR statusID NOT IN(0, 1, 112, 113, 111) THEN 0 
						ELSE 1 
					END AS allowdelete,
					(b.winlost-b.actual_stake) winlost,
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
					0 AS OddsSpread
				FROM 
					dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.VSOutright o WITH (NOLOCK) ON b.oddsid = o.Orid
					INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
					INNER JOIN @SportBettype s ON s.BetType = b.BetType 
					LEFT JOIN (
						SELECT 
							t.refno, 
							t.apositiontaking , 
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
					b.custid = @Custid AND  
					s.ProductID = 5 AND
					s.EventType = 3 AND
					b.transid = @TransID
			END

			-- Gold Deluxe, Microgaming Live Casino, Cockfighting, Colossus Bet (translog)
			IF EXISTS (SELECT TOP 1 1 FROM @SportBettype s WHERE ProductID IN (12, 13, 15, 19) AND Bettype = @Bettype)
			BEGIN
				INSERT INTO @Data
				SELECT 
					b.gameid AS bettype,
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
						WHEN s.ProductID IN (12, 13, 19) THEN b.odds
						ELSE 0
					END AS odds,
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
						WHEN s.ProductID = 12 THEN 255
						WHEN s.ProductID = 13 THEN 203
						WHEN s.ProductID = 15 THEN 204
						WHEN s.ProductID = 19 THEN 206
					END AS sporttype,
					b.ip,
					b.betfrom,
					CASE
						WHEN s.ProductID = 19 THEN b.Gameid3rd
						ELSE 0
					END AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					(-b.actual_stake) AS winlost,
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
						WHEN s.ProductID = 19 THEN b.custom2
						ELSE ''
					END AS BetCheck,
					CASE
						WHEN s.ProductID = 19 THEN b.transdesc
						ELSE ''
					END AS transdesc,
					0 AS OddsSpread
				FROM dbo.translog AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				WHERE b.custid = @Custid
					AND s.ProductID IN (12, 13, 15, 19)
					AND b.statusID = 0
					AND b.translogid = @refno
			END

			-- Microgaming RNG Casino, RNG Casino Single Wallet, Voidbridge
			IF EXISTS (	SELECT TOP 1 1 FROM @SportBettype
						WHERE Bettype = @Bettype
							AND (ProductID IN (17, 22) 
								OR (ProductID = 6 AND SubProduct <> '')))
			BEGIN
				IF @WinlostDate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
					AND DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)	-- yesterday and today
				BEGIN
					-- Today running ticket
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
							WHEN s.ProductID IN (6, 22) THEN b.transdesc
							ELSE ''
						END AS transdesc,
						0 AS OddsSpread
					FROM dbo.bettransRnG AS brng WITH (NOLOCK)
						INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE
						b.custid = @Custid
						AND (s.ProductId IN (17, 22)
							OR (s.ProductId = 6 AND s.SubProduct <> ''))
						AND b.transid = @TransId
						AND brng.statusid = 0
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

					-- Today settled ticket
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
							WHEN SUM(brng.winlost - brng.actual_stake) = 0 THEN 'Draw'
							WHEN SUM(brng.winlost - brng.actual_stake) > 0 THEN 'Won'
							WHEN SUM(brng.winlost - brng.actual_stake) < 0 THEN 'Lose'
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
							WHEN s.ProductID IN (6, 22) THEN b.transdesc
							ELSE ''
						END AS transdesc,
						0 AS OddsSpread
					FROM dbo.bettransRnG AS brng WITH (NOLOCK)
						INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE
						b.custid = @Custid
						AND (s.ProductId IN (17, 22)
							OR (s.ProductId = 6 AND s.SubProduct <> ''))
						AND b.transid = @TransId
						AND brng.statusid <> 0
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
				END
				ELSE
				BEGIN
					-- Not today settled ticket
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
						CASE
							WHEN s.ProductID = 6 THEN b.matchid
							WHEN s.ProductID = 17 THEN 205
							WHEN s.ProductID = 22 THEN 212
						END AS Sporttype,
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
						'' AS BetCheck,
						CASE
							WHEN s.ProductID IN (6, 22) THEN b.transdesc
							ELSE ''
						END AS transdesc,
						0 AS OddsSpread
					FROM dbo.bettrans AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE
						b.custid = @Custid
						AND (s.ProductId IN (17, 22)
							OR (s.ProductId = 6 AND s.SubProduct <> ''))
						AND b.transid = @TransId
				END
			END

			-- AG Casino, AllBet
			IF EXISTS (SELECT TOP 1 1 FROM @SportBettype WHERE ProductID IN (11, 21) AND Bettype = @Bettype)
			BEGIN
				IF @WinlostDate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
					AND DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)	-- yesterday and today
				BEGIN
					-- Yesterday and today running ticket
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
						0 AS OddsSpread
					FROM dbo.bettransLC AS blc WITH (NOLOCK)
						INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE
						b.custid = @Custid
						AND s.ProductID IN (11, 21)
						AND b.transid = @TransId
						AND blc.statusID = 0
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

					-- Yesterday and today settled ticket
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
							WHEN SUM(blc.winlost - blc.actual_stake) = 0 THEN 'Draw'
							WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
							WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
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
						0 AS OddsSpread
					FROM dbo.bettransLC AS blc WITH (NOLOCK)
						INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE
						b.custid = @Custid
						AND s.ProductID IN (11, 21)
						AND b.transid = @TransId
						AND blc.statusID <> 0
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
				END
				ELSE
				BEGIN
					-- Not yesterday and today settled ticket
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
						CASE
							WHEN s.ProductID = 11 THEN 250
							WHEN s.ProductID = 21 THEN 211
						END AS Sporttype,
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
						'' AS BetCheck,
						'' AS transdesc,
						0 AS OddsSpread
					FROM dbo.bettrans AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE
						b.custid = @Custid
						AND s.ProductID IN (11, 21)
						AND b.transid = @TransId
				END
			END

			-- Colossus Bet
			IF EXISTS (SELECT TOP 1 1 FROM  @SportBettype s WHERE ProductID = 15 AND Bettype = @Bettype)
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
					0 AS OddsSpread
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					LEFT JOIN dbo.bettransm AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
				WHERE
					b.custid = @Custid
					AND s.ProductID = 15
					AND b.refno = @refno
			END
		END 

		-- Bettrans14
		ELSE IF @WinlostDate <= @MoveBetsDay AND @WinlostDate >= @BalanceUpDay 
		BEGIN
			-- Sportbooks, Number Game, Live Casino, Virtual Sports
			IF EXISTS (SELECT TOP 1 1 FROM @SportBettype WHERE eventtype = 1 AND bettype = @bettype )
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
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					stake,
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
					(b.winlost-b.actual_stake)  winlost,
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
					ISNULL(b.oddsspread, 0) AS OddsSpread		-- For Myanmar Odds
				FROM
					dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid  
					INNER JOIN @SportBettype s ON s.Bettype = b.bettype
				WHERE
					b.custid = @Custid AND
					s.EventType = 1 AND
					(b.transid = @TransID
						OR ( @bettype BETWEEN 801 AND 899 AND b.refno = @refno ))

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

			-- Mix Parlay
			IF @bettype = 9
			BEGIN
				INSERT INTO @Data
				SELECT
					9 bettype,
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
					CASE WHEN statusID = 0 THEN 1 ELSE 0 END AS allowdelete,
					(b.winlost-b.actual_stake) AS winlost,
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
					0 AS OddsSpread
				FROM dbo.bettrans14 AS b WITH (NOLOCK)
				WHERE b.custid = @Custid
					AND matchid = 9
					AND bettype = 9
					AND b.transid = @TransID  
			END

			-- Combination Mix Parlay
			IF @bettype = 29
			BEGIN
				SELECT @refno = refno
				FROM dbo.bettrans14 b WITH (NOLOCK)
				WHERE b.custid = @Custid
					AND matchid = 29
					AND bettype = 29
					AND b.transid = @TransID
			END

			-- RNG Casino, Bingo, Gold Deluxe, Microgaming Live Casino, Cockfighting
			IF EXISTS (SELECT TOP 1 1 FROM @SportBettype s 
						WHERE Bettype = @Bettype 
							AND (ProductID IN (7, 12, 13, 19)
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
						WHEN s.ProductID IN (12, 19) THEN b.odds
						ELSE 0
					END AS odds,
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
						WHEN s.ProductID = 12 THEN 255
						WHEN s.ProductID = 13 THEN 203
						WHEN s.ProductID = 19 THEN 206
					END AS sporttype,
					b.ip,
					b.betfrom,
					CASE
						WHEN s.ProductID = 12 THEN b.matchid
						WHEN s.ProductID = 19 THEN b.betdaqid
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
						WHEN s.ProductID IN (12, 13, 19) THEN b.betcheck
						ELSE ''
					END AS BetCheck,
					CASE
						WHEN s.ProductID = 19 THEN b.transdesc
						ELSE ''
					END AS transdesc,
					0 AS OddsSpread
				FROM dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.custid = @Custid
					AND (s.ProductID IN (7, 12, 13, 19)
						OR (ProductID = 6 AND SubProduct = ''))
					AND b.refno = @refno
			END

			-- Keno
			IF EXISTS (SELECT TOP 1 1 FROM  @SportBettype s WHERE ProductID = 8 AND Bettype = @Bettype)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.BetID,0) AS BetID,
					b.refno,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					sdiscount,
					adiscount,
					discount,
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
					d.ChoiceId betteam,
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
					0 AS leagueid,
					202 AS sporttype,
					b.ip,
					b.betfrom,
					d.GameId matchid,
					CONVERT(BIT,0) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost-b.actual_stake) AS winlost,
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
					0 AS OddsSpread
				FROM dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					OUTER APPLY dbo.[f_ParseTransDesc](b.TransDesc, b.bettype) d
				WHERE
					b.custid = @Custid
					AND b.refno = @refno
					AND s.ProductID = 8
					AND b.statusID NOT IN (0,1)
			END

			-- P2P
			IF EXISTS (SELECT TOP 1 1 FROM  @SportBettype s WHERE ProductID = 9 AND Bettype = @Bettype)
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
					(b.winlost-b.actual_stake)  winlost,
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
					0 AS OddsSpread
				FROM dbo.bettrans14 b WITH (NOLOCK)
				WHERE
					b.custid = @Custid
					AND matchid = 1000
					AND bettype = 1000
					AND b.transid = @TransID
			END

			-- Outright
			IF @bettype = 10
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
					(b.winlost-b.actual_stake)  winlost,
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
					0 AS OddsSpread
				FROM dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN dbo.outright14 AS odds WITH (NOLOCK) ON b.matchid = odds.orid
					INNER JOIN dbo.league l WITH (NOLOCK) ON odds.leagueid = l.leagueid
				WHERE b.bettype = 10
					AND b.custid = @Custid
					AND b.transid = @TransID
			END

			-- HR
			IF EXISTS (SELECT TOP 1 1 FROM  @SportBettype s WHERE ProductID = 2 AND Bettype = @Bettype)
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
					(b.winlost-b.actual_stake)  winlost,
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
					0 AS OddsSpread
				FROM dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN dbo.outright14 AS odds WITH (NOLOCK) ON b.matchid = odds.orid
					INNER JOIN dbo.league l WITH (NOLOCK) ON odds.leagueid = l.leagueid
					INNER JOIN @SportBettype s ON s.Bettype = b.bettype
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
						FROM dbo.bettransm14 t WITH (NOLOCK)
							INNER JOIN dbo.bettransm14 f WITH (NOLOCK) ON t.refno = f.refno
						WHERE t.bettype IN (31,41) AND f.bettype IN (32,42)
						) bm ON b.transid = bm.refno
				WHERE s.ProductID = 2
					AND b.custid = @Custid
					AND b.transid = @TransID
			END

			-- Virtual HR
			IF EXISTS(SELECT TOP 1 1 FROM @SportBettype s WHERE s.ProductID = 5 AND s.EventType = 3 AND s.bettype = @bettype)
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
					stake,
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
					CASE WHEN b.bettype IN (SELECT typeid FROM @tableBettypeNotAllowDelete) OR statusID NOT IN(0, 1, 112, 113, 111) THEN 0 ELSE 1 END AS allowdelete,
					(b.winlost-b.actual_stake)  winlost,
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
					0 AS OddsSpread
				FROM
					dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN dbo.VSOutright14 o WITH (NOLOCK) ON b.oddsid = o.Orid
					INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
					INNER JOIN @SportBettype s ON s.BetType = b.BetType 
					LEFT JOIN (
						SELECT
							t.refno,
							t.apositiontaking,
							t.mpositiontaking,
							t.spositiontaking,
							f.apositiontaking apositiontaking2,
							f.mpositiontaking mpositiontaking2,
							f.spositiontaking spositiontaking2
						FROM dbo.bettransm14 t WITH (NOLOCK)
						  INNER JOIN dbo.bettransm14 f WITH (NOLOCK) ON t.refno = f.refno
						WHERE t.bettype = 1231 AND f.bettype = 1232
						) bm ON b.refno = bm.refno
				WHERE
					b.custid = @Custid AND
					s.ProductID = 5 AND
					s.EventType = 3 AND
					b.transid = @TransID
			END

			-- Colossus Bet
			IF EXISTS (SELECT TOP 1 1 FROM @SportBettype WHERE ProductID = 15 AND Bettype = @Bettype)
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
					b.winlostdate ,
					ISNULL(bm.betcheck, '') AS BetCheck,
					'' AS transdesc,
					0 AS OddsSpread
				FROM dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					LEFT JOIN dbo.bettransm14 AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
				WHERE b.custid = @Custid
					AND s.ProductID = 15
					AND b.refno = @refno
			END

			-- Microgaming RNG Casino, AG Casino, RNG Casino Single Wallet, AllBet, Voidbridge, NG2
			IF EXISTS(	SELECT TOP 1 1 FROM @SportBettype
						WHERE Bettype = @Bettype 
							AND (ProductID IN (11, 17, 21, 22, 23) 
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
					END AS sporttype,
					b.ip,
					b.betfrom,
					b.betdaqid AS matchid,
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
					'' AS BetCheck,
					CASE
						WHEN s.ProductID IN (6, 22, 23) THEN b.transdesc
						ELSE ''
					END AS transdesc,
					0 AS OddsSpread
				FROM dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.custid = @Custid
					AND (s.ProductID IN (11, 17, 21, 22, 23)
						OR (ProductID = 6 AND SubProduct <> ''))
					AND b.transid = @TransID
			END
		END

		-- bettrans_bk
		ELSE IF @WinlostDate < @BalanceUpDay 
		BEGIN
			-- Sportbooks, Number Game, Live Casino, Virtual Sports
			IF EXISTS (SELECT TOP 1 1 FROM @SportBettype WHERE eventtype = 1 AND bettype = @bettype )
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
					b.status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					stake,
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
					(b.winlost-b.actual_stake)  winlost,
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
					ISNULL(b.oddsspread, 0) AS OddsSpread	-- For Myanmar Odds
				FROM
					DBARC.bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					INNER JOIN DBARC.bodb_archive.dbo.match_BK AS m WITH (NOLOCK) ON b.matchid = m.matchid
					INNER JOIN @SportBettype s ON s.BetType = b.BetType
				WHERE
					b.custid = @Custid
					AND s.EventType = 1
					AND (b.transid = @TransID
						OR ( @bettype BETWEEN 801 AND 899 AND b.refno = @refno ))

				UPDATE betList
				SET betList.Odds	= originBetList.Odds
					,betList.Stake	= originBetList.Stake
					,betList.comm	= CASE WHEN betList.Bettype = 902 THEN ISNULL(commBetList.awinlost,0) ELSE betList.comm END
					,betList.BetID	= originBetList.Bettype
				FROM @Data AS betList
					INNER JOIN DBARC.bodb_archive.dbo.bettrans_bk AS originBetList WITH(NOLOCK) ON betList.RefNO = originBetList.TransID
					LEFT JOIN @Data AS commBetList ON betList.RefNO = commBetList.RefNO AND commBetList.Bettype = 903
				WHERE betList.Sporttype = 1 AND betList.Bettype IN (901, 902)
			END

			-- Mix Parlay
			IF @bettype = 9
			BEGIN
				INSERT INTO @Data
				SELECT
					9 bettype,
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
					(b.winlost-b.actual_stake)  winlost,
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
					0 AS OddsSpread
				FROM DBARC.bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				WHERE b.custid = @Custid
					AND matchid = 9
					AND bettype = 9
					AND b.transid = @TransID
			END

			-- Combination Mix Parlay
			IF @bettype = 29
			BEGIN
				SELECT @refno = refno
				FROM DBARC.bodb_archive.dbo.bettrans_bk b WITH(NOLOCK)
				WHERE b.custid = @Custid
					AND matchid = 29
					AND bettype = 29
					AND b.transid = @TransID
			END

			-- RNG Casino, Bingo, Gold Deluxe, Microgaming Live Casino, Cockfighting
			IF EXISTS (SELECT TOP 1 1 FROM  @SportBettype s 
						WHERE Bettype = @Bettype 
							AND (ProductID IN (7, 12, 13, 19)
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
						WHEN s.ProductID IN (12, 19) THEN b.odds
						ELSE 0
					END AS odds,
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
						WHEN s.ProductID = 12 THEN 255
						WHEN s.ProductID = 13 THEN 203
						WHEN s.ProductID = 19 THEN 206
					END AS sporttype,
					b.ip,
					b.betfrom,
					CASE
						WHEN s.ProductID = 12 THEN b.matchid
						WHEN s.ProductID = 19 THEN b.betdaqid
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
						WHEN s.ProductID IN (12, 13, 19) THEN b.betcheck
						ELSE ''
					END AS BetCheck,
					CASE
						WHEN s.ProductID = 19 THEN b.transdesc
						ELSE ''
					END AS transdesc,
					0 AS OddsSpread
				FROM DBARC.bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.custid = @Custid
					AND (s.ProductID IN (7, 12, 13, 19)
						OR (ProductID = 6 AND SubProduct = ''))
					AND b.refno = @refno
			END

			-- Keno
			IF EXISTS (SELECT TOP 1 1 FROM  @SportBettype s WHERE ProductID = 8 AND Bettype = @Bettype)
			BEGIN
				INSERT INTO @Data
				SELECT
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
					d.ChoiceId betteam,
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
					202 AS sporttype,
					b.ip,
					b.betfrom,
					d.GameId matchid,
					CONVERT(BIT,0) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost-b.actual_stake)  winlost,
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
					0 AS OddsSpread
				FROM DBARC.bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					INNER JOIN @SportBettype s ON s.Bettype = b.bettype
					OUTER APPLY dbo.[f_ParseTransDesc](b.TransDesc, b.bettype) d
				WHERE
					b.custid = @Custid
					AND s.ProductID = 8
					AND b.refno = @refno
			END

			-- P2P
			IF EXISTS (SELECT TOP 1 1 FROM  @SportBettype s WHERE ProductID = 9 AND Bettype = @Bettype)
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
					(b.winlost-b.actual_stake)  winlost,
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
					0 AS OddsSpread
				FROM DBARC.bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				WHERE
					b.custid = @Custid
					AND matchid = 1000
					AND bettype = 1000
					AND b.transid = @TransID
			END

			-- Outright
			IF @bettype = 10
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
					(b.winlost-b.actual_stake)  winlost,
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
					0 AS OddsSpread
				FROM DBARC.bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					INNER JOIN DBARC.bodb_archive.dbo.Outright_bk AS odds WITH (NOLOCK) ON b.matchid = odds.orid
					INNER JOIN dbo.league l WITH (NOLOCK) ON odds.leagueid = l.leagueid
				WHERE b.bettype = 10
					AND b.custid = @Custid
					AND b.transid = @TransID
			END

			-- HR
			IF EXISTS (SELECT TOP 1 1 FROM  @SportBettype s WHERE ProductID = 2 AND Bettype = @Bettype)
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
					(b.winlost-b.actual_stake)  winlost,
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
					0 AS OddsSpread
				FROM DBARC.bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					INNER JOIN DBARC.bodb_archive.dbo.Outright_bk AS odds WITH (NOLOCK) ON b.matchid = odds.orid
					INNER JOIN dbo.league l WITH (NOLOCK) ON odds.leagueid = l.leagueid
					INNER JOIN @SportBettype s ON s.Bettype = b.bettype
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
						FROM DBARC.bodb_archive.dbo.bettransm t WITH (NOLOCK)
							INNER JOIN DBARC.bodb_archive.dbo.bettransm f WITH (NOLOCK) ON t.refno = f.refno
						WHERE t.bettype IN (31,41) AND f.bettype IN (32,42)
						) bm ON b.transid = bm.refno
				WHERE s.ProductID = 2
					AND b.custid = @Custid
					AND b.transid = @TransID
				ORDER BY b.transid
			END

			-- Virtual HR
			IF EXISTS(SELECT TOP 1 1 FROM @SportBettype s WHERE s.ProductID = 5 AND s.EventType = 3 AND s.bettype = @bettype)
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
					stake,
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
					CASE WHEN b.bettype IN (SELECT typeid FROM @tableBettypeNotAllowDelete) OR statusID NOT IN(0, 1, 112, 113, 111) THEN 0 ELSE 1 END AS allowdelete,
					(b.winlost-b.actual_stake)  winlost,
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
					0 AS OddsSpread
				FROM
					DBARC.bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					INNER JOIN DBARC.bodb_archive.dbo.VSOutright_bk o WITH (NOLOCK) ON b.oddsid = o.Orid
					INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
					INNER JOIN @SportBettype s ON s.BetType = b.BetType 
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
				WHERE
					b.custid = @Custid AND
					s.ProductID = 5 AND
					s.EventType = 3 AND
					b.transid = @TransID
			END

			-- Colossus Bet
			IF EXISTS( SELECT TOP 1 1 FROM @SportBettype s WHERE ProductID = 15 AND Bettype = @Bettype)
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
					0 AS OddsSpread
				FROM DBARC.bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					INNER JOIN @SportBettype s ON s.Bettype = b.bettype
					LEFT JOIN DBARC.bodb_archive.dbo.bettransm AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
				WHERE b.custid = @Custid
					AND s.ProductID = 15
					AND b.refno = @refno
			END

			-- Microgaming RNG Casino, AG Casino, RNG Casino Single Wallet, AllBet, Voidbridge, NG2
			IF EXISTS (	SELECT TOP 1 1 FROM @SportBettype s 
						WHERE Bettype = @Bettype
							AND (ProductID IN (11, 17, 21, 22, 23) 
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
					END AS sporttype,
					b.ip,
					b.betfrom,
					b.betdaqid AS matchid,
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
					'' AS BetCheck,
					CASE
						WHEN s.ProductID IN (6, 22, 23) THEN b.transdesc
						ELSE ''
					END AS transdesc,
					0 AS OddsSpread
				FROM DBARC.bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.custid = @Custid
					AND (s.ProductID IN (11, 17, 21, 22, 23)
						OR (ProductID = 6 AND SubProduct <> ''))
					AND b.transid = @TransID
			END
		END

		-- System parlay
		IF @refno IS NOT NULL AND @bettype = 29
		BEGIN
			-- bettrans
			INSERT INTO @Data
			SELECT
				29 bettype,
				CASE WHEN ISNULL(b.betid, 0) = 0 THEN b.transid ELSE b.betID END AS transid,
				ISNULL(b.BetID, 0) AS BetID,
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
				(b.winlost-b.actual_stake)  winlost,
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
				0 AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK)
			WHERE
				b.custid = @Custid
				AND matchid = 29
				AND bettype = 29
				AND b.refno = @refno

			-- bettrans14
			INSERT INTO @Data
			SELECT
				29 bettype,
				CASE WHEN ISNULL(b.betid,0) = 0 THEN b.transid ELSE b.betID END AS transid,  
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
				(b.winlost-b.actual_stake)  winlost,
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
				0 AS OddsSpread
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
			WHERE
				b.custid = @Custid
				AND matchid = 29
				AND bettype = 29
				AND b.refno = @refno

			-- bettrans_bk
			INSERT INTO @Data
			SELECT
				29 bettype,
				CASE WHEN ISNULL(b.betid,0) = 0 THEN b.transid ELSE b.betID END AS transid,
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
				(b.winlost-b.actual_stake)  winlost,
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
				0 AS OddsSpread
			FROM DBARC.bodb_archive.dbo.bettrans_bk b WITH(NOLOCK)
			WHERE  b.custid = @Custid
				AND matchid = 29
				AND bettype = 29
				AND b.refno = @refno
		END
		
		DELETE @Data WHERE sporttype = 1 AND bettype = 903
	END
	
	IF EXISTS (	SELECT TOP 1 1 
				FROM @SportBettype AS sp 
					INNER JOIN @Data AS d ON d.bettype = sp.bettype 
				WHERE ProductID IN (4, 12)) 
	BEGIN
		IF @WinlostDate > @MoveBetsDay
		BEGIN
			INSERT INTO @DetailData
			SELECT
				BG.refno,
				BG.odds,
				BG.stake,
				BG.status,
				BG.apositiontaking,
				BG.mpositiontaking,
				BG.spositiontaking,
				BG.bettype,
				BG.betteam,
				BG.TransDesc
			FROM dbo.bettransg AS BG WITH (NOLOCK)
				INNER JOIN @SportBettype AS sp ON BG.bettype = sp.bettype
				INNER JOIN @Data AS B ON BG.CustID = B.CustID AND (BG.refno = B.refno AND BG.bettype = B.bettype)
			WHERE sp.Productid = 4

			UNION ALL

			SELECT
				BG.refno,
				BG.odds,
				BG.stake,
				BG.status,
				BG.apositiontaking,
				BG.mpositiontaking,
				BG.spositiontaking,
				BG.bettype,
				BG.betteam,
				BG.TransDesc
			FROM dbo.bettransg AS BG WITH (NOLOCK)
				INNER JOIN @SportBettype AS sp ON BG.bettype = sp.bettype
				INNER JOIN @Data AS B ON BG.CustID = B.CustID AND (BG.refno = B.transid AND BG.bettype = B.bettype)
			WHERE sp.Productid = 12
		END
		ELSE IF @WinlostDate <= @MoveBetsDay AND @WinlostDate >= @BalanceUpDay 
		BEGIN
			INSERT INTO @DetailData
			SELECT
				BG.refno,
				BG.odds,
				BG.stake,
				BG.status,
				BG.apositiontaking,
				BG.mpositiontaking,
				BG.spositiontaking,
				BG.bettype,
				BG.betteam,
				BG.TransDesc
			FROM dbo.bettransg14 AS BG WITH (NOLOCK)
				INNER JOIN @SportBettype AS sp ON BG.bettype = sp.bettype
				INNER JOIN @Data AS B1 ON (BG.refno = B1.refno AND BG.bettype = B1.bettype)
			WHERE sp.Productid = 4

			UNION ALL

			SELECT
				BG.refno,
				BG.odds,
				BG.stake,
				BG.status,
				BG.apositiontaking,
				BG.mpositiontaking,
				BG.spositiontaking,
				BG.bettype,
				BG.betteam,
				BG.TransDesc
			FROM dbo.bettransg14 AS BG WITH (NOLOCK)
				INNER JOIN @SportBettype AS sp ON BG.bettype = sp.bettype
				INNER JOIN @Data AS B2 ON BG.refno = B2.transid AND BG.bettype = B2.bettype
			WHERE sp.Productid = 12
		END
		ELSE
		BEGIN
			INSERT INTO @DetailData
			SELECT
				BG.refno,
				BG.odds,
				BG.stake,
				BG.status,
				BG.apositiontaking,
				BG.mpositiontaking,
				BG.spositiontaking,
				BG.bettype,
				BG.betteam,
				BG.TransDesc
			FROM DBARC.bodb_archive.dbo.bettransg AS BG WITH (NOLOCK)
				INNER JOIN @SportBettype AS sp ON BG.bettype = sp.bettype
				INNER JOIN @Data AS B1 ON BG.refno = B1.refno AND BG.bettype = B1.bettype
			WHERE sp.Productid = 4

			UNION ALL

			SELECT
				BG.refno,
				BG.odds,
				BG.stake,
				BG.status,
				BG.apositiontaking,
				BG.mpositiontaking,
				BG.spositiontaking,
				BG.bettype,
				BG.betteam,
				BG.TransDesc
			FROM DBARC.bodb_archive.dbo.bettransg AS BG WITH (NOLOCK)
				INNER JOIN @SportBettype AS sp ON BG.bettype = sp.bettype
				INNER JOIN @Data AS B2 ON BG.refno = B2.transid AND BG.bettype = B2.bettype
			WHERE sp.Productid = 12
		END
	END
	
	-- BettransRnG tables
	SET @WinlostDate = NULL

	-- bettransRnG
	SELECT TOP 1 
		@WinlostDate	= bt.winlostdate
		, @bettype		= bt.gameID
		, @refno		= bt.refno
	FROM dbo.bettransRnG AS bt WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp ON bt.gameID = sp.bettype
	WHERE bt.custid = @Custid AND bt.transid = @transid

	-- bettransRnG14
	IF @WinlostDate IS NULL
	BEGIN
		SELECT TOP 1 
			@WinlostDate	= bt.winlostdate
			, @bettype		= bt.gameID
			, @refno		= bt.refno
		FROM dbo.bettransRnG14 AS bt WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON bt.gameID = sp.bettype
		WHERE bt.custid = @Custid AND bt.transid = @transid
	END

	-- bettransRnG_bk
	IF @WinlostDate IS NULL
	BEGIN
		SELECT TOP 1 
			@WinlostDate	= bt.winlostdate
			, @bettype		= bt.gameID
			, @refno		= bt.refno
		FROM DBARC.bodb_archive.dbo.bettransRnG_bk AS bt WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON bt.gameID = sp.bettype
		WHERE bt.custid = @Custid AND bt.transid = @transid
	END

	IF @WinlostDate IS NOT NULL
	BEGIN
		-- bettransRnG
		IF @WinlostDate > @MoveBetsDay
		BEGIN
			-- Microgaming RNG Casino, RNG Casino Single Wallet
			IF EXISTS(	SELECT TOP 1 1 FROM @SportBettype 
						WHERE Bettype = @Bettype 
							AND (ProductID IN (17, 22) 
								OR (ProductID = 6 AND SubProduct <> '')))
			BEGIN
				INSERT INTO @Data
				SELECT
					b.gameID AS bettype,
					b.transid,
					0 AS BetID,
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
					b.TranId3rd AS BetCheck,
					b.transdesc,
					0 AS OddsSpread
				FROM dbo.bettransRnG AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				WHERE b.custid = @Custid
					AND b.transid = @TransID
					AND (s.ProductId IN (17, 22)
						OR (s.ProductId = 6 AND s.SubProduct <> ''))
			END
		END

		-- bettransRnG14
		ELSE IF @WinlostDate BETWEEN @BalanceUpDay AND @MoveBetsDay
		BEGIN
			-- Microgaming RNG Casino, RNG Casino Single Wallet
			IF EXISTS(	SELECT TOP 1 1 FROM @SportBettype 
						WHERE Bettype = @Bettype 
							AND (ProductID IN (17, 22) 
								OR (ProductID = 6 AND SubProduct <> '')))
			BEGIN
				INSERT INTO @Data
				SELECT
					b.gameID AS bettype,
					b.transid,
					0 AS BetID,
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
					b.TranId3rd AS BetCheck,
					b.transdesc,
					0 AS OddsSpread
				FROM dbo.bettransRnG14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				WHERE b.custid = @Custid
					AND b.transid = @TransID
					AND (s.ProductId IN (17, 22)
						OR (s.ProductId = 6 AND s.SubProduct <> ''))
			END
		END

		-- bettransRnG_bk
		ELSE IF @WinlostDate < @BalanceUpDay
		BEGIN
			-- Microgaming RNG Casino, RNG Casino Single Wallet
			IF EXISTS(	SELECT TOP 1 1 FROM @SportBettype 
						WHERE Bettype = @Bettype 
							AND (ProductID IN (17, 22) 
								OR (ProductID = 6 AND SubProduct <> '')))
			BEGIN
				INSERT INTO @Data
				SELECT
					b.gameID AS bettype,
					b.transid,
					0 AS BetID,
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
					b.TranId3rd AS BetCheck,
					b.transdesc,
					0 AS OddsSpread
				FROM DBARC.bodb_archive.dbo.bettransRnG_bk AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				WHERE b.custid = @Custid
					AND b.transid = @TransID
					AND (s.ProductId IN (17, 22)
						OR (s.ProductId = 6 AND s.SubProduct <> ''))
			END
		END
	END

	-- BettransLC tables
	SET @WinlostDate = NULL

	-- bettransLC
	SELECT TOP 1 
		@WinlostDate	= bt.winlostdate
		, @bettype		= bt.gameID
		, @refno		= bt.refno
	FROM dbo.bettransLC AS bt WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp ON bt.gameID = sp.bettype
	WHERE bt.custid = @Custid AND bt.transid = @transid

	-- bettransLC14
	IF @WinlostDate IS NULL
	BEGIN
		SELECT TOP 1 
			@WinlostDate	= bt.winlostdate
			, @bettype		= bt.gameID
			, @refno		= bt.refno
		FROM dbo.bettransLC14 AS bt WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON bt.gameID = sp.bettype
		WHERE bt.custid = @Custid AND bt.transid = @transid
	END

	-- bettransLC_bk
	IF @WinlostDate IS NULL
	BEGIN
		SELECT TOP 1 
			@WinlostDate	= bt.winlostdate
			, @bettype		= bt.gameID
			, @refno		= bt.refno
		FROM DBARC.bodb_archive.dbo.bettransLC_bk AS bt WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON bt.gameID = sp.bettype
		WHERE bt.custid = @Custid AND bt.transid = @transid
	END

	IF @WinlostDate IS NOT NULL
	BEGIN
		-- bettransLC
		IF @WinlostDate > @MoveBetsDay
		BEGIN
			-- AG Casino, AllBet
			IF EXISTS( SELECT TOP 1 1 FROM @SportBettype WHERE ProductID IN (11, 21) AND Bettype = @Bettype )
			BEGIN
				INSERT INTO @Data
				SELECT
					b.gameID AS bettype,
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
					b.TranId3rd AS BetCheck,
					b.transdesc,
					0 AS OddsSpread
				FROM dbo.bettransLC AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				WHERE b.custid = @Custid
					AND b.transid = @TransID
					AND s.ProductID IN (11, 21)
			END
		END

		-- bettransLC14
		ELSE IF @WinlostDate BETWEEN @BalanceUpDay AND @MoveBetsDay
		BEGIN
			-- AG Casino, AllBet
			IF EXISTS( SELECT TOP 1 1 FROM @SportBettype WHERE ProductID IN (11, 21) AND Bettype = @Bettype )
			BEGIN
				INSERT INTO @Data
				SELECT
					b.gameID AS bettype,
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
					b.TranId3rd AS BetCheck, 
					b.transdesc,
					0 AS OddsSpread
				FROM dbo.bettransLC14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				WHERE b.custid = @Custid
					AND b.transid = @TransID
					AND s.ProductID IN (11, 21)
			END
		END

		-- bettransLC_bk
		ELSE IF @WinlostDate < @BalanceUpDay
		BEGIN
			-- AG Casino, AllBet
			IF EXISTS( SELECT TOP 1 1 FROM @SportBettype WHERE ProductID IN (11, 21) AND Bettype = @Bettype )
			BEGIN
				INSERT INTO @Data
				SELECT
					b.gameID AS bettype,
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
					b.TranId3rd AS BetCheck,
					b.transdesc,
					0 AS OddsSpread
				FROM DBARC.bodb_archive.dbo.bettransLC_bk AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				WHERE b.custid = @Custid
					AND b.transid = @TransID
					AND s.ProductID IN (11, 21)
			END
		END
	END

	SELECT *
	FROM @Data
	ORDER BY transid

	SELECT * FROM @DetailData
END




GO
GRANT EXECUTE ON [dbo].[Acc_BetsSelBetList_ByTransID] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Acc_BetsSelBetList_ByTransID] TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BetsSelBetList_ByTransID] TO [vnteam] 
