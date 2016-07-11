USE bodb02
GO

ALTER PROCEDURE [dbo].[Acc_BetsSelBetList_ByTransID_Advance]
	@TransID BIGINT
AS

/*
	Created by: Elodie
	Date: 20121212
	Task: Ticket's information by TransID only
	DB: DBAGE.bodb02 
	Original:  Acc_BetsSelBetList_ByTransID 
	
	Revisions:
		- 20130121@Dan: change linked server DB06 to DBARC
		- 20130227@Elodie: Add Virtual HR product
		- 20130724@Elodie: Get winlostdate field
		- 20130726@Elodie: Define data for bettrans, bettrans14 or bettrans_bk by winlostdate field
						   Enhance performance
		- 20140907@Dom:	[Redmine #22012] update VS Condition
		- 20141103@Dom: Apply sport bettype matrix
		- 20150415@Sophia: Support Betradar and revise code of Bettype matrix
		- 20150506@Tom: Support Gold Deluxe Product [#34847]
		- 20150506@Bobby: Add transdesc column for metric gaming bettypes (801-899)
		- 20150615@Edward: Support for BetTrade
		- 20150707@Bobby: Exclude Metric Gaming running ticket from bettrans table
		- 20150805@Bobby: 
			+ Dis-allow to get ticket detail by refno 
			+ remove checking product when selecting ticket's eventtype = 1 from bettrans_bk
		- 20150814@Bobby: Fix bug #41544 - Exclude CS, BG, GD, KN, MG, MGC tickets
		- 20150826@Kos: Add OddsSpread column to support Myanmar Odds
		- 20150826@Kos: Exclude Colossus Bet ticket
		- 20151008@Kos: Exclude AG Casino ticket
		- 20151008@Kos: Exclude Microgaming RNG Casino ticket
		- 20151210@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20151216@Kos: Exclude Cockfighting ticket [#Redmine: 48850]
		- 20160119@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160203@Kos: Support AllBet [#Redmine: 50257]
		- 20160407@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20160711@Kos: Change to use inline function for SportBettypeMatrix
*/

BEGIN
	SET NOCOUNT ON

	----Get Sport Bettype Matrix------
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM bodb02.dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID IN (1, 2, 3, 4, 5, 9, 14)
		AND BetType NOT BETWEEN 801 AND 899
	
	DECLARE @refno BIGINT

	Declare @Data TABLE (
		username		NVARCHAR(50),
		bettype			INT,
		transid			BIGINT, 
		betid			BIGINT,
		refno			NVARCHAR(50), 
		matchcode		NVARCHAR(50),
		race			NVARCHAR(20),
		eventdate		SMALLDATETIME,
		virtualrate		FLOAT,
		isShowOTExRate	BIT,
		sdiscount		SMALLMONEY,
		adiscount		SMALLMONEY,
		discount		SMALLMONEY,
		homeid			INT, 
		awayid			INT, 
		settleTime		DATETIME,
		hdp1			SMALLMONEY, 
		hdp2			SMALLMONEY, 
		odds			MONEY,
		finalodds		MONEY,
		finalodds2		MONEY,
		OddsType		TINYINT,
		status			NVARCHAR(50),
		comstatus		NVARCHAR(50),
		stake			MONEY,
		actual_stake	MONEY,
		transdate		DATETIME,
		betteam			NVARCHAR(50),
		spositiontaking SMALLMONEY,
		mpositiontaking SMALLMONEY,
		apositiontaking SMALLMONEY,
		spositiontaking2 SMALLMONEY,
		mpositiontaking2 SMALLMONEY,
		apositiontaking2 SMALLMONEY,
		liveindicator	 BIT,
		modds			MONEY,
		custid			INT,
		livehomescore	INT,
		liveawayscore	INT,
		finalhomescore	INT,
		finalawayscore	INT,
		leagueid		INT,
		sporttype		SMALLINT,
		ip				NVARCHAR(15),
		betfrom			NVARCHAR (1),
		matchid			INT,
		isNeutral		BIT,
		winlost			MONEY,
		commission		MONEY,
		scomm			MONEY,
		acomm			MONEY,
		comm			MONEY,
		awinlost		MONEY,
		mwinlost		MONEY,
		swinlost		MONEY,
		showtime		NVARCHAR(50),
		winlostdate		SMALLDATETIME,
		BetCheck		NVARCHAR(50),
		transdesc		NVARCHAR(300),
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

	DECLARE @WinlostDate	SMALLDATETIME, 
			@MoveBetsDay	SMALLDATETIME, 
			@BalanceUpDay	SMALLDATETIME, 
			@bettype		INT
	DECLARE @tmp TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME) 

	INSERT INTO @tmp(BalanceUpDay, MoveBetsDay)
	EXEC Age_SelBalanceUpDay

	SELECT @MoveBetsDay = MoveBetsDay, @BalanceUpDay = BalanceUpDay FROM @tmp

	-- FROM translog
	SELECT TOP 1 
		@WinlostDate 	= bt.winlostdate
		, @bettype 		= bt.gameID 
		, @refno 		= bt.translogid
	FROM dbo.translog AS bt WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp ON bt.gameID = sp.bettype
	WHERE bt.translogid = @transid 
		AND statusID 	= 0

	-- FROM bettrans
	IF @WinlostDate IS NULL
	BEGIN
		SELECT TOP 1 
			@WinlostDate	= bt.winlostdate
			, @bettype 		= bt.bettype 
			, @refno 		= bt.refno
		FROM dbo.bettrans AS bt WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON bt.bettype = sp.bettype
		WHERE bt.transid 	= @transid 
	END

	-- FROM bettrans14
	IF @WinlostDate IS NULL
	BEGIN
		SELECT TOP 1 
			@WinlostDate 	= bt.winlostdate
			, @bettype 		= bt.bettype 
			, @refno 		= bt.refno
		FROM dbo.bettrans14 AS bt WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON bt.bettype = sp.bettype
		WHERE bt.transid 	= @transid 
	END

	-- FROM bettrans_bk
	IF @WinlostDate IS NULL
	BEGIN
		SELECT TOP 1 
			@WinlostDate 	= bt.winlostdate
			, @bettype 		= bt.bettype 
			, @refno 		= bt.refno
		FROM DBARC.bodb_archive.dbo.bettrans_bk AS bt WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON bt.bettype = sp.bettype
		WHERE bt.transid 	= @transid 
	END
	
	IF(@WinlostDate IS NULL) GOTO OutputResult;

	-- Bettrans
	IF @WinlostDate > @MoveBetsDay
	BEGIN
		IF EXISTS (SELECT TOP 1 1 FROM @SportBettype WHERE eventtype = 1 AND bettype = @bettype)
		BEGIN
			-- Sportsbook
			INSERT INTO @Data
			SELECT 
				b.username,
				b.bettype,
				b.transid,
				ISNULL(b.BetID, 0) AS BetID,
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
				ISNULL(b.oddsspread, 0) AS OddsSpread
			FROM 
				dbo.bettrans AS b WITH (NOLOCK) 
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid --phuong.nguyen, remove left join match_remark
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE s.EventType = 1 AND b.transid = @TransID
			
			UNION ALL -- translog metric gaming
			SELECT 
				b.username,
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
				NULL AS settleTime,
				0 AS hdp1,
				0 AS hdp2,
				b.odds,
				0 finalodds,
				0 finalodds2,
				CASE WHEN b.gameid IN (801,803,804,805,806) THEN CONVERT(TINYINT, ISNULL(b.custom1, 0)) ELSE 0 END AS OddsType,
				b.status,
				'' AS comstatus,
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
				b.betfrom,
				b.eventID AS matchid,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
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
				CASE WHEN b.gameID BETWEEN 801 AND 899 THEN b.transdesc ELSE '' END AS transdesc,
				0 AS OddsSpread
			FROM 
				dbo.translog AS b WITH (NOLOCK) 
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.eventId = m.matchid --phuong.nguyen, remove left join match_remark
				INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
			WHERE b.translogid = @TransID
				AND s.Bettype 	BETWEEN 801 AND 899
				AND b.statusid	= 0

			UPDATE betList
			SET betList.Odds	= originBetList.Odds
				,betList.Stake	= originBetList.Stake
				,betList.comm	= CASE WHEN betList.Bettype = 902 THEN ISNULL(commBetList.awinlost,0) ELSE betList.comm END
				,betList.BetID	= originBetList.Bettype
			FROM @Data AS betList
				INNER JOIN dbo.bettrans AS originBetList WITH(NOLOCK) ON betList.RefNO = originBetList.TransID
				LEFT JOIN @Data AS commBetList ON betList.RefNO = commBetList.RefNO AND commBetList.Bettype = 903
			WHERE betList.Sporttype = 1 AND betList.Bettype IN (901, 902)
		END

		-- Mix Parlay
		IF @bettype = 9
		BEGIN
			INSERT INTO @Data
			SELECT
				b.username,
				9 bettype,
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
			FROM dbo.bettrans AS b WITH (NOLOCK)
			WHERE matchid = 9
				AND bettype = 9
				AND b.transid = @TransID
		END

		-- Combination Mix Parlay
		IF @bettype = 29
			INSERT INTO @Data
			SELECT 
				b.username,
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
			FROM dbo.bettrans b WITH(NOLOCK)
			WHERE	matchid = 29
				AND bettype = 29  
				AND b.transid = @TransID

		-- P2P
		IF @bettype = 1000
			INSERT INTO @Data
			SELECT 
				b.username,
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
			FROM dbo.bettrans AS b WITH (NOLOCK)
			WHERE matchid = 1000
				AND bettype = 1000
				AND b.transid = @TransID

		-- Outright
		IF @bettype = 10
			INSERT INTO @Data
			SELECT 
				b.username,
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
				b.ip ,
				b.betfrom,
				b.matchid,
				CONVERT(BIT,0) AS IsNeutral,
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
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON odds.leagueid = l.leagueid
			WHERE b.bettype = 10 AND b.transid = @TransID

		-- HR
		ELSE IF EXISTS (SELECT TOP 1 1 FROM  @SportBettype s  WHERE ProductID = 2 AND Bettype = @Bettype)
			INSERT INTO @Data
			SELECT 
				b.username,
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
				b.ip ,
				b.betfrom,
				b.matchid,
				CONVERT(BIT,0) AS IsNeutral,
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
			FROM	dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.outright AS odds WITH (NOLOCK) ON b.matchid = odds.orid
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON odds.leagueid = l.leagueid
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
			WHERE s.ProductID = 2 AND b.transid = @TransID
			ORDER BY b.transid
		
		-- Virtual HR
		IF EXISTS(SELECT TOP 1 1 FROM @SportBettype s WHERE s.ProductID = 5 AND s.EventType = 3 AND s.bettype = @bettype)
			INSERT INTO @Data
			SELECT 
				b.username,
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
				CASE WHEN b.bettype = 1233 THEN bm.mpositiontaking ELSE b.mpositiontaking END ,     
				CASE WHEN b.bettype = 1233 THEN bm.apositiontaking ELSE b.apositiontaking END,   
				CASE WHEN b.bettype = 1233 THEN bm.spositiontaking2 ELSE 0 END ,     
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
				dbo.bettrans AS b WITH (NOLOCK) 
				INNER JOIN dbo.VSOutright o WITH (NOLOCK) ON b.oddsid = o.Orid
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
					FROM dbo.bettransm AS t WITH (NOLOCK)
						INNER JOIN dbo.bettransm AS f WITH (NOLOCK) ON t.refno = f.refno
					WHERE t.bettype = 1231 AND f.bettype = 1232 
					) bm ON b.refno = bm.refno  
			WHERE	s.ProductID = 5 
				AND s.EventType = 3 
				AND b.transid = @TransID
		
		/*IF EXISTS (SELECT TOP 1 1 FROM  @SportBettype s  WHERE ProductID = 12 AND Bettype = @Bettype)
		BEGIN
			INSERT INTO @Data  
			SELECT
				b.username, 
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
				255 AS sporttype,   
				b.ip,  
				b.betfrom,  
				b.matchid,
				CONVERT(BIT,0) AS IsNeutral,  
				(b.winlost-b.actual_stake)  winlost,  
				b.playercomm AS commission,  
				(b.scomm - b.acomm) AS scomm,  
				(b.acomm - b.comm) AS acomm,  
				(b.comm - b.playercomm) AS comm,  
				b.awinlost,  
				b.mwinlost,  
				b.swinlost,  
				'' AS showtime,
				b.winlostdate ,
				b.BetCheck,
				'' AS transdesc        
			FROM dbo.bettrans b WITH (NOLOCK)     
			INNER JOIN @SportBettype s ON s.Bettype = b.bettype
			WHERE     
				s.ProductID = 12
				AND b.refno = @refno
				
			UNION ALL	-- translog
			SELECT 
				cu.username,
				b.gameid bettype,   
				0 AS transid, 
				0 AS betid,
				b.translogid ,
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
				0 hdp1,
				0 hdp2,
				b.odds,   
				0 finalodds,
				0 finalodds2,
				0 AS OddsType,  
				b.status,  
				0 AS comstatus, 
				b.stake,  
				b.actual_stake,    
				b.transdate,   
				b.GameID3rd betteam,   
				b.spositiontaking,  
				b.mpositiontaking,   
				b.apositiontaking, 
				0 spositiontaking2,
				0 mpositiontaking2,
				0 apositiontaking2,   
				0 liveindicator,   
				0 modds,   
				b.custid,
				0 livehomescore, 
				0 liveawayscore,
				0 AS finalhomescore, 
				0 AS finalawayscore,  
				0 AS leagueid,  
				255 AS sporttype, 
				b.ip,
				b.betfrom,
				NULL matchid,
				CONVERT(BIT,0) AS IsNeutral,
				(-b.actual_stake)  winlost,
				0 AS commission,
				0,
				0,
				0,
				0,
				0,
				0,
				'' AS showtime,
				b.winlostdate,
				b.GameID3rd AS BetCheck,
				'' AS transdesc  	 
			FROM dbo.translog b WITH (NOLOCK)
				LEFT JOIN dbo.CustInfo cu WITH (NOLOCK) ON b.CustID = cu.CustID
			INNER JOIN @SportBettype s ON s.Bettype = b.gameID
			WHERE	s.ProductID = 12
				AND b.statusID = 0
				AND b.translogid = @refno
		END*/
	END

	-- Bettrans14
	ELSE IF @WinlostDate <= @MoveBetsDay AND @WinlostDate >= @BalanceUpDay
	BEGIN
		IF EXISTS (SELECT TOP 1 1 FROM @SportBettype WHERE eventtype = 1 AND bettype = @bettype )
			INSERT INTO @Data
			SELECT 
				b.username,
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
				ISNULL(b.oddsspread, 0) AS OddsSpread
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE s.EventType = 1 AND b.transid = @TransID

		UPDATE betList
		SET betList.Odds	= originBetList.Odds
			,betList.Stake	= originBetList.Stake
			,betList.comm	= CASE WHEN betList.Bettype = 902 THEN ISNULL(commBetList.awinlost,0) ELSE betList.comm END
			,betList.BetID	= originBetList.Bettype
		FROM @Data AS betList
			INNER JOIN dbo.bettrans14 AS originBetList WITH(NOLOCK) ON betList.RefNO = originBetList.TransID
			LEFT JOIN @Data AS commBetList ON betList.RefNO = commBetList.RefNO AND commBetList.Bettype = 903
		WHERE betList.Sporttype = 1 AND betList.Bettype IN (901, 902)

		-- Mix Parlay
		IF @bettype = 9
			INSERT INTO @Data
			SELECT 
				b.username,
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
			WHERE	matchid = 9
				AND bettype = 9
				AND b.transid = @TransID

		-- Combination Mix Parlay
		IF @bettype = 29
			INSERT INTO @Data
			SELECT 
				b.username,
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
			FROM dbo.bettrans14 AS b WITH(NOLOCK)
			WHERE matchid = 29
				AND bettype = 29
				AND b.transid = @TransID

		-- P2P
		IF @bettype = 1000
			INSERT INTO @Data
			SELECT 
				b.username,
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
			WHERE matchid = 1000
				AND bettype = 1000
				AND b.transid = @TransID

		-- Outright
		IF @bettype = 10
			INSERT INTO @Data
			SELECT 
				b.username,
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
				b.ip ,
				b.betfrom,
				b.matchid,
				CONVERT(BIT,0) AS IsNeutral,
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
				AND b.transid = @TransID

		-- HR
		IF @bettype IN (31,32,33,41,42,43)
			INSERT INTO @Data
			SELECT 
				b.username,
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
				INNER JOIN dbo.outright14 AS odds WITH (NOLOCK) ON b.matchid = odds.orid
				INNER JOIN dbo.league l WITH (NOLOCK) ON odds.leagueid = l.leagueid
				INNER JOIN @SportBettype s ON s.BetType = b.BetType
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
					FROM dbo.bettransm14 AS t WITH (NOLOCK)
						INNER JOIN dbo.bettransm14 AS f WITH (NOLOCK) ON t.refno = f.refno 
					WHERE t.bettype IN (31,41) AND f.bettype IN (32,42)
				) bm ON b.transid = bm.refno 
			WHERE s.ProductID = 2 AND b.transid = @TransID
			ORDER BY b.transid
		
		-- Virtual HR
		IF EXISTS(SELECT TOP 1 1 FROM @SportBettype s WHERE s.ProductID = 5 AND s.EventType = 3 AND s.bettype = @bettype)
			INSERT INTO @Data
			SELECT 
				b.username,
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
					FROM dbo.bettransm14 AS t WITH (NOLOCK)  
						INNER JOIN dbo.bettransm14 AS f WITH (NOLOCK) ON t.refno = f.refno
					WHERE t.bettype = 1231 AND f.bettype = 1232 
					) bm ON b.refno = bm.refno  
			WHERE	s.ProductID = 5 AND
				s.EventType = 3 AND 
				b.transid = @TransID

		/*IF EXISTS (SELECT TOP 1 1 FROM  @SportBettype s  WHERE ProductID = 12 AND Bettype = @Bettype)
		BEGIN
			INSERT INTO @Data  
			SELECT
				b.username, 
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
				255 AS sporttype,   
				b.ip,  
				b.betfrom,  
				b.matchid,
				CONVERT(BIT,0) AS IsNeutral,  
				(b.winlost-b.actual_stake)  winlost,  
				b.playercomm AS commission,  
				(b.scomm - b.acomm) AS scomm,  
				(b.acomm - b.comm) AS acomm,  
				(b.comm - b.playercomm) AS comm,  
				b.awinlost,  
				b.mwinlost,  
				b.swinlost,  
				'' AS showtime,
				b.winlostdate ,
				b.BetCheck,
				'' AS transdesc        
			FROM dbo.bettrans14 b WITH (NOLOCK)     
			INNER JOIN @SportBettype s ON s.Bettype = b.bettype
			WHERE     
				s.ProductID = 12
				AND b.refno = @refno
		END*/
	END

	--bettrans_bk
	ELSE IF @WinlostDate < @BalanceUpDay
	BEGIN
		--Sportbooks
		IF EXISTS (SELECT TOP 1 1 FROM @SportBettype WHERE eventtype = 1 AND bettype = @bettype )
		INSERT INTO @Data
		SELECT 
			c.username,
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
			ISNULL(b.oddsspread, 0) AS OddsSpread
		FROM 
			DBARC.bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK) 
			INNER JOIN DBARC.bodb_archive.dbo.match_BK AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN dbo.custInfo AS c WITH (NOLOCK) ON c.custid = b.custid
			INNER JOIN @SportBettype s ON s.BetType = b.BetType 
		WHERE s.EventType = 1 AND b.transid = @TransID

		UPDATE betList
		SET betList.Odds	= originBetList.Odds
			,betList.Stake	= originBetList.Stake
			,betList.comm	= CASE WHEN betList.Bettype = 902 THEN ISNULL(commBetList.awinlost,0) ELSE betList.comm END
			,betList.BetID	= originBetList.Bettype
		FROM @Data AS betList
			INNER JOIN DBARC.bodb_archive.dbo.bettrans_bk AS originBetList WITH(NOLOCK) ON betList.RefNO = originBetList.TransID
			LEFT JOIN @Data AS commBetList ON betList.RefNO = commBetList.RefNO AND commBetList.Bettype = 903
		WHERE betList.Sporttype = 1 AND betList.Bettype IN (901, 902)

		-- Mix Parlay
		IF @bettype = 9
		BEGIN
			INSERT INTO @Data
			SELECT 
				c.username,
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
				INNER JOIN dbo.custInfo AS c WITH (NOLOCK) ON c.custid = b.custid
			WHERE matchid = 9
				AND bettype = 9  
				AND b.transid = @TransID
		END

		-- Combination Mix Parlay
		IF @bettype = 29
		BEGIN
			INSERT INTO @Data
			SELECT 
				c.username,
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
				INNER JOIN dbo.custInfo c WITH (NOLOCK) ON c.custid = b.custid
			WHERE matchid = 29
				AND bettype = 29  
				AND b.transid = @TransID
		END

		-- P2P
		IF @bettype = 1000
			INSERT INTO @Data
			SELECT 
				c.username,
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
				INNER JOIN dbo.custInfo AS c WITH (NOLOCK) ON c.custid = b.custid
			WHERE matchid = 1000
				AND bettype = 1000
				AND b.transid = @TransID

		-- Outright
		IF @bettype = 10
			INSERT INTO @Data
			SELECT 
				c.username,
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
				b.ip ,
				b.betfrom,
				b.matchid,
				CONVERT(BIT,0) AS IsNeutral,
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
				INNER JOIN dbo.custInfo c WITH (NOLOCK) ON c.custid = b.custid
			WHERE b.bettype = 10 AND b.transid = @TransID

		-- HR
		IF @bettype IN (31,32,33,41,42,43)
			INSERT INTO @Data
			SELECT 		 
				c.username,
				b.bettype,
				b.transid,   
				ISNULL(b.BetID,0) AS BetID,
				b.refno,
				odds.matchcode, 
				odds.groupmatch AS race,
				odds.eventdate AS eventdate,
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
				b.ip ,
				b.betfrom,
				b.matchid,
				CONVERT(BIT,0) AS IsNeutral,
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
				INNER JOIN dbo.custInfo c WITH (NOLOCK) ON c.custid = b.custid
				INNER JOIN @SportBettype s ON s.BetType = b.BetType 
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
			WHERE s.ProductID = 2 AND b.transid = @TransID
			ORDER BY b.transid 
		
		-- Virtual HR
		IF EXISTS(SELECT TOP 1 1 FROM @SportBettype s WHERE s.ProductID = 5 AND s.EventType = 3 AND s.bettype = @bettype)
			INSERT INTO @Data
			SELECT 
				c.username,
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
				INNER JOIN dbo.custInfo c WITH (NOLOCK) ON c.custid = b.custid
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
					FROM DBARC.bodb_archive.dbo.bettransm t WITH (NOLOCK)  
						INNER JOIN DBARC.bodb_archive.dbo.bettransm f WITH (NOLOCK) ON t.refno = f.refno   
					WHERE t.bettype = 1231 AND f.bettype = 1232 
					) bm ON b.refno = bm.refno  
			WHERE	s.ProductID = 5 AND
					s.EventType = 3 AND 
					b.transid = @TransID

		/*IF EXISTS (SELECT TOP 1 1 FROM  @SportBettype s  WHERE ProductID = 12 AND Bettype = @Bettype)
		BEGIN
			INSERT INTO @Data  
			SELECT
				cu.username, 
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
				255 AS sporttype,   
				b.ip,  
				b.betfrom,  
				b.matchid,
				CONVERT(BIT,0) AS IsNeutral,  
				(b.winlost-b.actual_stake)  winlost,  
				b.playercomm AS commission,  
				(b.scomm - b.acomm) AS scomm,  
				(b.acomm - b.comm) AS acomm,  
				(b.comm - b.playercomm) AS comm,  
				b.awinlost,  
				b.mwinlost,  
				b.swinlost,  
				'' AS showtime,
				b.winlostdate ,
				b.BetCheck,
			 '' AS transdesc        
			FROM DBARC.bodb_archive.dbo.bettrans_bk b WITH (NOLOCK)     
			INNER JOIN @SportBettype s ON s.Bettype = b.bettype
			INNER JOIN dbo.custInfo cu WITH (NOLOCK) ON cu.custid = b.custid
			WHERE     
				s.ProductID = 12
				AND b.refno = @refno
		END*/

	END
	
	DELETE @Data WHERE sporttype = 1 AND bettype = 903

	OutputResult:
	SELECT * FROM @Data
	ORDER BY transid

	IF EXISTS (	SELECT TOP 1 1 
				FROM @SportBettype sp 
					INNER JOIN @Data d ON d.bettype = sp.bettype 
				WHERE ProductID IN (4,12) AND sp.bettype = @bettype )
	BEGIN
		IF @WinlostDate > @MoveBetsDay
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
				INNER JOIN @SportBettype sp ON BG.bettype = sp.bettype AND sp.Productid IN (4)
				INNER JOIN @Data B1 ON (BG.refno = B1.refno AND BG.bettype = B1.bettype AND sp.Productid IN (4))
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
			FROM dbo.bettransg BG WITH (NOLOCK)
				INNER JOIN @SportBettype sp ON BG.bettype = sp.bettype AND sp.Productid IN (12)
				INNER JOIN @Data B2 ON (BG.refno = B2.transid AND BG.bettype = B2.bettype AND sp.Productid IN (12))

		ELSE IF @WinlostDate <= @MoveBetsDay AND @WinlostDate >= @BalanceUpDay
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
			FROM dbo.bettransg14 BG WITH (NOLOCK)
				INNER JOIN @SportBettype sp ON BG.bettype = sp.bettype AND sp.Productid IN (4)
				INNER JOIN @Data B1 ON (BG.refno = B1.refno AND BG.bettype = B1.bettype AND sp.Productid IN (4))
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
			FROM dbo.bettransg14 BG WITH (NOLOCK)
				INNER JOIN @SportBettype sp ON BG.bettype = sp.bettype AND sp.Productid IN (12)
				INNER JOIN @Data B2 ON (BG.refno = B2.transid AND BG.bettype = B2.bettype AND sp.Productid IN (12))
		ELSE	
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
			FROM DBARC.bodb_archive.dbo.bettransg BG WITH (NOLOCK)
				INNER JOIN @SportBettype sp ON BG.bettype = sp.bettype AND sp.Productid IN (4)
				INNER JOIN @Data B1 ON (BG.refno = B1.refno AND BG.bettype = B1.bettype AND sp.Productid IN (4))
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
			FROM DBARC.bodb_archive.dbo.bettransg BG WITH (NOLOCK)
				INNER JOIN @SportBettype sp ON BG.bettype = sp.bettype AND sp.Productid IN (12)
				INNER JOIN @Data B2 ON (BG.refno = B2.transid AND BG.bettype = B2.bettype AND sp.Productid IN (12))
	END

	SELECT * FROM @DetailData
END





GO
GRANT EXECUTE ON [dbo].[Acc_BetsSelBetList_ByTransID_Advance] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Acc_BetsSelBetList_ByTransID_Advance] TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BetsSelBetList_ByTransID_Advance] TO [vnteam]