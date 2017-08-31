USE bodb02
GO

ALTER PROCEDURE [dbo].[Acc_BetList_CheckBet]
	@TransId BIGINT
AS

/*
	Created by: 20160510@Kos
	Task: NAP Report - Bet List of Check Bet report
	DB: DBAGE.bodb02
	Original: Acc_BetsSelBetList_ByTransID_Advance
	
	Revisions:
		- 20160725@Kos: Use inline function for SportBettypeMatrix
		- 20160919@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20170301@Kos: Support KickOffTime for Virtual Soccer and Virtual Tennis [#Redmine: 71906]
		- 20170404@Kos: Support CashOut [#Redmine: 71963]
		- 20170623@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20170831@Kos: Support Lucky 3 [#Redmine: 75277]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	-- Support Sportsbook, Horse Racing, Number Game, Virtual Sports, Lucky 3, Betradar Virtual Sports only
	-- Don't support BetTrade
	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID IN (1, 2, 3, 5, 26, 27)
		AND BetType NOT BETWEEN 901 AND 920

	DECLARE @Data TABLE (
		Username		NVARCHAR(50),
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
		MOdds			MONEY,
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
		TransDesc		NVARCHAR(300),
		OddsSpread		MONEY,
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000)
	)

	DECLARE @BetType INT

	SELECT TOP(1) @BetType = bt.bettype
	FROM dbo.bettrans AS bt WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp ON bt.bettype = sp.Bettype
	WHERE bt.transid = @TransId

	-- Sportsbook, Number Game, Virtual Sports, Lucky 3, Betradar Virtual Sports (EventType = 1)
	IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE EventType = 1 AND Bettype = @BetType)
	BEGIN
		INSERT INTO @Data
		SELECT
			b.username,
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
			0 AS spositiontaking2,
			0 AS mpositiontaking2,
			0 AS apositiontaking2,
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
			CASE
				WHEN s.ProductID = 1 THEN ISNULL(b.betdaqid, -1)
				ELSE -1
			END AS BetdaqId,
			CASE
				WHEN s.ProductID = 1 THEN ISNULL(b.ExtraInfo, '')
				ELSE ''
			END AS ExtraInfo
		FROM
			dbo.bettrans AS b WITH (NOLOCK) 
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
		WHERE s.EventType = 1 AND b.transid = @TransId
	END

	-- Mix Parlay, System Parlay (Sportsbook), Mix Parlay (Betradar Virtual Sports)
	IF @BetType IN (9, 29, 2799)
	BEGIN
		INSERT INTO @Data
		SELECT
			b.username,
			b.bettype,
			CASE
				WHEN b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
				ELSE b.transid
			END AS transid,
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
			-1 AS BetdaqId,
			'' AS ExtraInfo
		FROM dbo.bettrans AS b WITH (NOLOCK)
		WHERE b.matchid = @BetType
			AND b.bettype = @BetType
			AND b.transid = @TransId
	END

	-- Outright
	IF @BetType = 10
	BEGIN
		INSERT INTO @Data
		SELECT 
			b.username,
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
			-1 AS BetdaqId,
			'' AS ExtraInfo
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.outright AS odds WITH (NOLOCK) ON b.matchid = odds.orid
			INNER JOIN dbo.league AS l WITH (NOLOCK) ON odds.leagueid = l.leagueid
		WHERE b.bettype = 10 AND b.transid = @TransId
	END

	-- Horse Racing
	IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID = 2 AND Bettype = @Bettype)
	BEGIN
		INSERT INTO @Data
		SELECT 
			b.username,
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
			CONVERT(BIT, 0) AS IsNeutral,
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
			-1 AS BetdaqId,
			'' AS ExtraInfo
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.outright AS odds WITH (NOLOCK) ON b.matchid = odds.orid
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
				FROM dbo.bettransm AS t WITH (NOLOCK)
					INNER JOIN dbo.bettransm AS f WITH (NOLOCK) ON t.refno = f.refno 
				WHERE t.bettype IN (31, 41) AND f.bettype IN (32, 42)
			) bm ON b.transid = bm.refno
		WHERE s.ProductID = 2 AND b.transid = @TransId
	END

	-- Virtual Horse Racing
	IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID = 5 AND EventType = 3 AND Bettype = @BetType)
	BEGIN
		INSERT INTO @Data
		SELECT
			b.username,
			b.bettype,
			b.transid,
			'' AS BetID,
			b.refno,
			o.RacerNum AS matchcode,
			b.oddsid AS Race,
			'' AS eventdate,
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
			0 AS LiveIndicator,
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
			(b.winlost - b.actual_stake) AS WinLost,
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
			-1 AS BetdaqId,
			'' AS ExtraInfo
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON b.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			INNER JOIN @SportBettype AS s ON s.BetType = b.BetType
			LEFT JOIN (
				SELECT
					t.refno,
					t.apositiontaking,
					t.mpositiontaking,
					t.spositiontaking,
					f.apositiontaking AS apositiontaking2,
					f.mpositiontaking AS mpositiontaking2,
					f.spositiontaking AS spositiontaking2
				FROM dbo.bettransm AS t WITH (NOLOCK)
					INNER JOIN dbo.bettransm AS f WITH (NOLOCK) ON t.refno = f.refno
				WHERE t.bettype = 1231 AND f.bettype = 1232
				) bm ON b.refno = bm.refno
		WHERE s.ProductID = 5
			AND s.EventType = 3
			AND b.transid = @TransId
	END

	SELECT b.*,
		ex.currency
	FROM @Data AS b
		LEFT JOIN dbo.custInfo AS ci WITH (NOLOCK) ON b.CustId = ci.custid
		LEFT JOIN dbo.Exchange AS ex WITH (NOLOCK) ON ci.currency = ex.exchangeid
END




GO
GRANT EXECUTE ON [dbo].[Acc_BetList_CheckBet] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Acc_BetList_CheckBet] TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BetList_CheckBet] TO [vnteam]
GO
