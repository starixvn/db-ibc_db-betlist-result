USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Age_CoreBetList_Mem_SelBetTicket]    Script Date: 5/11/2015 10:31:30 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Age_CoreBetList_BetTicket_SelBettrans]
(
	@tempCust		[dbo].[TVP_TicketSportBettype]	READONLY
	, @TransStatus	[dbo].[TVP_BetTicketStatus]		READONLY
)
AS

/*
	Created: Bobby.Nguyen
	Task: Re-factor core bet list
	DB: DBAGE.bodb02
	Original: 

	Revisions:
		- 20150504@Bobby: Create new SP - Re-factor bet list
		- 20150827@Kos: Add column OddsSpread to support Myanmar Odds
		- 20150831@Kos: Support Colossus Bet
		- 20150910@Bobby: Enhance performence for SP core. Apply TVP for input parameters
		- 20151022@Kos: Return [bettransm].[betcheck] to support view CB ticket detail
		- 20151214@Kos: Support Cockfighting (#Redmine: 48850)
		- 20160111@Kos: Support RNG Casino Single Wallet [Redmine: #48958]
		- 20160125@Kos: Fix performance issue with today RNG Casino Single Wallet ticket [#Redmine: 51388]
		- 20160125@Kos: Support PH All In One 1.2 [Redmine: #50897]
		- 20160125@Kos: Fix Colossus Bet result issue
		- 20160217@Kos: Support AllBet [Redmine: #50864]
		- 20160404@Kos: Support Macau Games [Redmine: #54925]
		- 20160411@Kos: Support Combo Parlay [Redmine: #55282]
		- 20160812@Kos: Support NG2
		- 20161101@Kos: Support Fishing World [#Redmine: 65934]
		- 20170301@Kos: Support KickOffTime for Virtual Soccer and Virtual Tennis [#Redmine: 71906]

	Param's Explanation:

	Dependences:
		- Age_CoreBetList_BetTicket_SelMainInfo
*/

BEGIN
	SET NOCOUNT ON;

	/*
		- Mix & System Parlay	: ProductId = 1
		- Casino				: ProductId = 6
		- Bingo					: ProductId = 7
		- Keno					: ProductId = 8
		- P2P					: ProductId = 9
		- Gold Deluxe			: ProductId = 12
		- Cockfighting			: ProductId = 19
		- AllBet				: ProductId = 21
		- Macau Games			: ProductId = 22
		- NG2					: ProductId = 23
		- Fishing World			: ProductId = 24
	*/
	SELECT
		CASE WHEN (b.bettype = 29 AND ISNULL(b.betid, 0) > 0) THEN b.betid
			ELSE b.transid
		END AS transid
		, b.refno
		, b.custid
		, b.Username
		, CASE
			WHEN c.ProductID = 6 AND b.bettype = 71 THEN 251
			WHEN c.ProductID = 6 AND b.bettype <> 71 THEN b.matchid
			WHEN c.ProductID = 7 THEN 252
			WHEN c.ProductID = 8 THEN 202
			WHEN c.ProductID = 9 THEN 253 
			WHEN c.ProductID = 12 THEN 255
			WHEN c.ProductId = 19 THEN 206
			WHEN c.ProductId = 21 THEN 211
			WHEN c.ProductId = 22 THEN 212
			WHEN c.ProductId = 23 AND b.bettype BETWEEN 2501 AND 2539 THEN 213
			WHEN c.ProductId = 23 AND b.bettype BETWEEN 2541 AND 2579 THEN 214
			WHEN c.ProductId = 23 AND b.bettype BETWEEN 2581 AND 2619 THEN 215
			WHEN c.ProductId = 23 AND b.bettype BETWEEN 2621 AND 2659 THEN 216
			WHEN c.ProductId = 23 AND b.bettype BETWEEN 2681 AND 2699 THEN 218
			WHEN c.ProductId = 24 THEN 219
			ELSE 0
		END AS Sporttype
		, b.bettype
		, ISNULL(b.BetID, 0)
		, CASE WHEN c.ProductID = 1 THEN b.Betteam
				WHEN c.ProductID = 8 THEN fnc.ChoiceId
				ELSE ''
			END AS Betteam 
		, CASE WHEN c.ProductID IN (1, 23) THEN b.hdp1
				ELSE 0
			END AS hdp1
		, CASE WHEN c.ProductID IN (1, 23) THEN b.hdp2
				ELSE 0
			END AS hdp2
		, CASE WHEN c.ProductID IN (8, 19) THEN b.OddsType
			ELSE 0
		END AS OddsType
		, b.oddsid
		, CASE WHEN c.ProductID IN (1, 8, 12, 19, 23) THEN b.Odds
				ELSE 0
			END AS Odds
		, CASE WHEN c.ProductID IN (1) THEN b.modds 
				ELSE 0
			END AS modds
		, b.Stake
		, b.actual_stake
		, b.Status
		, b.Transdate
		, b.winlostdate
		, CASE WHEN b.bettype IN (23102, 23002, 23202) THEN 0 
				ELSE (b.winlost - b.actual_stake) 
			END AS winlost
		, b.awinlost
		, b.mwinlost
		, b.swinlost
		, b.PlayerComm
		, (b.comm - b.playercomm)	AS comm
		, (b.acomm - b.comm)		AS acomm
		, (b.scomm - b.acomm)		AS scomm
		, b.APositiontaking
		, b.MPositiontaking
		, b.SPositiontaking
		, b.TPositiontaking
		, b.discount
		, b.adiscount
		, b.sdiscount
		, CASE
			WHEN c.ProductID = 1 THEN b.Liveindicator
			ELSE 0
		END AS Liveindicator
		, CASE
			WHEN c.ProductID IN (1, 23) THEN b.Livehomescore
			ELSE 0
		END AS Livehomescore
		, CASE
			WHEN c.ProductID = 1 THEN b.Liveawayscore
			ELSE 0
		END AS Liveawayscore
		, 0 AS finalhomescore
		, 0 AS finalawayscore
		, 0 AS hthomescore
		, 0 AS htawayscore
		, b.IP
		, 0 AS LeagueID
		,CASE
			WHEN c.ProductID = 8 THEN fnc.GameId
			WHEN c.ProductID = 12 THEN 255
			WHEN c.ProductID IN (19, 23) THEN b.betdaqid
			ELSE 0
		END AS MatchID
		, '' AS MatchCode
		, '' AS Race
		, b.winlostdate AS eventdate
		, 0 AS HomeID
		, 0 AS AwayID
		, '' AS Betstatus
		, CONVERT(BIT, 0) AS IsNeutral
		, '' AS Placing
		, '' AS showtime
		, CASE 
			WHEN c.ProductID IN ( 9, 12 ) AND b.bettype IN ( 1000, 1701, 1702 ) THEN b.betcheck
			WHEN c.ProductID = 19 THEN b.betcheck
			WHEN b.bettype = 29 THEN ISNULL(b.betcheck, '')
			ELSE ''
		END	AS betcheck
		, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' 
		END AS comstatus
		, CASE
			WHEN c.ProductID = 6 AND b.bettype <> 71 THEN b.transdesc
			WHEN c.ProductId IN (19, 22, 23, 24) THEN b.transdesc
			ELSE ''
		END AS transdesc
		, 0 AS OddsSpread
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN @tempCust AS c ON b.transid = c.transid
--			AND b.custid = c.custid
		OUTER APPLY [dbo].[f_ParseTransDesc](b.transdesc, b.bettype) fnc
	WHERE	c.WhTicket = 1
		AND c.EventType = 0
		AND c.ProductID <> 15	-- not Colossus Bet

	/*
		RNG Casino today running tickets (WhTicket = 4)
		- RNG Casino Single Wallet	: ProductId = 6 AND bettype <> 71
		- Macau Games				: ProductId = 22
		- Fishing World				: ProductId = 24
	*/
	UNION ALL
	SELECT
		b.transid
		, b.refno
		, b.custid
		, b.Username
		, CASE
			WHEN c.ProductID = 6 THEN b.matchid
			WHEN c.ProductID = 22 THEN 212
			WHEN c.ProductID = 24 THEN 219
		END AS Sporttype
		, b.bettype
		, ISNULL(b.BetID, 0)
		, '' AS Betteam
		, 0 AS hdp1
		, 0 AS hdp2
		, 0 AS OddsType
		, 0 AS oddsid
		, 0 AS Odds
		, 0 AS modds
		, SUM(brng.stake) AS Stake
		, SUM(brng.actual_stake) AS actual_stake 
		, 'Running' AS Status
		, b.Transdate
		, b.winlostdate
		, 0 AS winlost
		, 0 AS awinlost
		, 0 AS mwinlost
		, 0 AS swinlost
		, 0 AS PlayerComm
		, 0 AS comm
		, 0 AS acomm
		, 0 AS scomm
		, AVG(brng.APositiontaking)
		, AVG(brng.MPositiontaking)
		, AVG(brng.SPositiontaking)
		, AVG(brng.TPositiontaking)
		, AVG(brng.discount)
		, AVG(brng.adiscount)
		, AVG(brng.sdiscount)
		, 0 AS Liveindicator
		, 0 AS Livehomescore
		, 0 AS Liveawayscore
		, 0 AS finalhomescore
		, 0 AS finalawayscore
		, 0 AS hthomescore
		, 0 AS htawayscore
		, b.ip
		, 0 AS LeagueID
		, 0 AS MatchID
		, '' AS MatchCode
		, '' AS Race
		, b.winlostdate AS eventdate
		, 0 AS HomeID
		, 0 AS AwayID
		, '' AS Betstatus
		, CONVERT(BIT,0) AS IsNeutral
		, '' AS Placing
		, '' AS showtime
		, '' AS betcheck
		, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END	AS comstatus
		, CASE
			WHEN c.ProductId IN (6, 22, 24) THEN b.transdesc
			ELSE ''
		END AS transdesc
		, 0 AS OddsSpread
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN @tempCust AS c ON b.transid = c.transid
		INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = b.transid
	WHERE c.WhTicket = 4
		AND EXISTS(SELECT TOP 1 1 FROM @TransStatus WHERE StatusId IN (0, 1))
		AND brng.statusID IN (0, 1)
	GROUP BY
		b.transid,
		ISNULL(b.BetID, 0),
		b.Bettype,
		b.refno,
		b.transdate,
		b.winlostdate,
		b.custid,
		b.Username,
		b.IP,
		b.transdesc,
		b.comstatus,
		b.matchid,
		c.ProductID

	/*
		RNG Casino today settled tickets (WhTicket = 4)
		- RNG Casino Single Wallet	: ProductId = 6 AND bettype <> 71
		- Macau Games				: ProductId = 22
		- Fishing World				: ProductId = 24
	*/
	UNION ALL
	SELECT
		b.transid
		, b.refno
		, b.custid
		, b.Username
		, CASE
			WHEN c.ProductID = 6 THEN b.matchid
			WHEN c.ProductID = 22 THEN 212
			WHEN c.ProductID = 24 THEN 219
		END AS Sporttype
		, b.bettype
		, ISNULL(b.BetID, 0)
		, '' AS Betteam 
		, 0 AS hdp1
		, 0 AS hdp2
		, 0 AS OddsType
		, 0 AS oddsid
		, 0 AS Odds
		, 0 AS modds
		, SUM(brng.stake) AS Stake
		, SUM(brng.actual_stake) AS actual_stake 
		, CASE 
			WHEN SUM(brng.winlost - brng.actual_stake) = 0 THEN 'Draw'
			WHEN SUM(brng.winlost - brng.actual_stake) > 0 THEN 'Won'
			WHEN SUM(brng.winlost - brng.actual_stake) < 0 THEN 'Lose'
		END AS Status
		, b.Transdate
		, b.winlostdate
		, SUM(brng.winlost - brng.actual_stake) AS winlost
		, SUM(brng.awinlost) AS awinlost
		, SUM(brng.mwinlost) AS mwinlost
		, SUM(brng.swinlost) AS swinlost
		, SUM(brng.playercomm) AS PlayerComm
		, SUM(brng.comm - brng.playercomm) AS comm
		, SUM(brng.acomm - brng.comm) AS acomm 
		, SUM(brng.scomm - brng.acomm) AS scomm
		, AVG(brng.APositiontaking)
		, AVG(brng.MPositiontaking)
		, AVG(brng.SPositiontaking)
		, AVG(brng.TPositiontaking)
		, AVG(brng.discount)
		, AVG(brng.adiscount)
		, AVG(brng.sdiscount)
		, 0 AS Liveindicator
		, 0 AS Livehomescore
		, 0 AS Liveawayscore
		, 0 AS finalhomescore
		, 0 AS finalawayscore
		, 0 AS hthomescore
		, 0 AS htawayscore
		, b.ip
		, 0 AS LeagueID
		, 0 AS MatchID
		, '' AS MatchCode
		, '' AS Race
		, b.winlostdate AS eventdate
		, 0 AS HomeID
		, 0 AS AwayID
		, '' AS Betstatus
		, CONVERT(BIT,0) AS IsNeutral
		, '' AS Placing
		, '' AS showtime
		, '' AS betcheck
		, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END	AS comstatus
		, CASE
			WHEN c.ProductId IN (6, 22, 24) THEN b.transdesc
			ELSE ''
		END AS transdesc
		, 0 AS OddsSpread
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN @tempCust AS c ON b.transid = c.transid
		INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = b.transid
	WHERE c.WhTicket = 4
		AND EXISTS(SELECT TOP 1 1 FROM @TransStatus WHERE StatusId IN (111, 112, 113))
		AND brng.statusID NOT IN (0, 1)
	GROUP BY
		b.transid,
		ISNULL(b.BetID, 0),
		b.Bettype,
		b.refno,
		b.transdate,
		b.winlostdate,
		b.custid,
		b.Username,
		b.IP,
		b.transdesc,
		b.comstatus,
		b.matchid,
		c.ProductID

	/*
		Live Casino today running tickets (WhTicket = 5)
		- AllBet	: ProductId = 21
	*/
	UNION ALL
	SELECT
		b.transid
		, b.refno
		, b.custid
		, b.Username
		, CASE
				WHEN c.ProductID = 21 THEN 211
				ELSE 0
			END AS Sporttype
		, b.bettype
		, ISNULL(b.BetID, 0)
		, '' AS Betteam
		, 0 AS hdp1
		, 0 AS hdp2
		, 0 AS OddsType
		, 0 AS oddsid
		, 0 AS Odds
		, 0 AS modds
		, SUM(blc.stake) AS Stake
		, SUM(blc.actual_stake) AS actual_stake 
		, 'Running' AS Status
		, b.Transdate
		, b.winlostdate
		, 0 AS winlost
		, 0 AS awinlost
		, 0 AS mwinlost
		, 0 AS swinlost
		, 0 AS PlayerComm
		, 0 AS comm
		, 0 AS acomm
		, 0 AS scomm
		, AVG(blc.APositiontaking)
		, AVG(blc.MPositiontaking)
		, AVG(blc.SPositiontaking)
		, AVG(blc.TPositiontaking)
		, AVG(blc.discount)
		, AVG(blc.adiscount)
		, AVG(blc.sdiscount)
		, 0 AS Liveindicator
		, 0 AS Livehomescore
		, 0 AS Liveawayscore
		, 0 AS finalhomescore
		, 0 AS finalawayscore
		, 0 AS hthomescore
		, 0 AS htawayscore
		, b.IP
		, 0 AS LeagueID
		, 0 AS MatchID
		, '' AS MatchCode
		, '' AS Race
		, b.winlostdate AS eventdate
		, 0 AS HomeID
		, 0 AS AwayID
		, '' AS Betstatus
		, CONVERT(BIT, 0) AS IsNeutral
		, '' AS Placing
		, '' AS showtime
		, '' AS betcheck
		, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
		, '' AS transdesc
		, 0 AS OddsSpread
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN @tempCust AS c ON b.transid = c.transid
		INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = b.transid
	WHERE c.WhTicket = 5
		AND EXISTS(SELECT TOP 1 1 FROM @TransStatus WHERE StatusId IN (0, 1))
		AND blc.statusID IN (0, 1)
	GROUP BY
		b.transid,
		ISNULL(b.BetID, 0),
		b.Bettype,
		b.refno,
		b.transdate,
		b.winlostdate,
		b.custid,
		b.Username,
		b.IP,
		b.transdesc,
		b.comstatus,
		b.matchid,
		c.ProductID

	/*
		Live Casino today settled tickets (WhTicket = 5)
		- AllBet	: ProductId = 21
	*/
	UNION ALL
	SELECT
		b.transid
		, b.refno
		, b.custid
		, b.Username
		, CASE
			WHEN c.ProductID = 21 THEN 211
			ELSE 0
		END AS Sporttype
		, b.bettype
		, ISNULL(b.BetID, 0)
		, '' AS Betteam 
		, 0 AS hdp1
		, 0 AS hdp2
		, 0 AS OddsType
		, 0 AS oddsid
		, 0 AS Odds
		, 0 AS modds
		, SUM(blc.stake) AS Stake
		, SUM(blc.actual_stake) AS actual_stake 
		, CASE 
			WHEN SUM(blc.winlost - blc.actual_stake) = 0 THEN 'Draw'
			WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
			WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
		END AS Status
		, b.Transdate
		, b.winlostdate
		, SUM(blc.winlost - blc.actual_stake) AS winlost
		, SUM(blc.awinlost) AS awinlost
		, SUM(blc.mwinlost) AS mwinlost
		, SUM(blc.swinlost) AS swinlost
		, SUM(blc.playercomm) AS PlayerComm
		, SUM(blc.comm - blc.playercomm) AS comm
		, SUM(blc.acomm - blc.comm) AS acomm 
		, SUM(blc.scomm - blc.acomm) AS scomm
		, AVG(blc.APositiontaking)
		, AVG(blc.MPositiontaking)
		, AVG(blc.SPositiontaking)
		, AVG(blc.TPositiontaking)
		, AVG(blc.discount)
		, AVG(blc.adiscount)
		, AVG(blc.sdiscount)
		, 0 AS Liveindicator
		, 0 AS Livehomescore
		, 0 AS Liveawayscore
		, 0 AS finalhomescore
		, 0 AS finalawayscore
		, 0 AS hthomescore
		, 0 AS htawayscore
		, b.IP
		, 0 AS LeagueID
		, 0 AS MatchID
		, '' AS MatchCode
		, '' AS Race
		, b.winlostdate AS eventdate
		, 0 AS HomeID
		, 0 AS AwayID
		, '' AS Betstatus
		, CONVERT(BIT, 0) AS IsNeutral
		, '' AS Placing
		, '' AS showtime
		, '' AS betcheck
		, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END	AS comstatus
		, '' AS transdesc
		, 0 AS OddsSpread
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN @tempCust AS c ON b.transid = c.transid
		INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = b.transid
	WHERE c.WhTicket = 5
		AND EXISTS(SELECT TOP 1 1 FROM @TransStatus WHERE StatusId IN (111, 112, 113))
		AND blc.statusID NOT IN (0, 1)
	GROUP BY
		b.transid,
		ISNULL(b.BetID, 0),
		b.Bettype,
		b.refno,
		b.transdate,
		b.winlostdate,
		b.custid,
		b.Username,
		b.IP,
		b.transdesc,
		b.comstatus,
		b.matchid,
		c.ProductID

	/*
	- Colossus Bet	: ProductId = 15
	*/
	UNION ALL
	SELECT
		b.transid
		, b.refno
		, b.custid
		, b.Username
		, 204 AS Sporttype
		, b.bettype
		, ISNULL(b.BetID, 0)
		, '' AS Betteam
		, 0 AS hdp1
		, 0 AS hdp2
		, 0 AS OddsType
		, b.oddsid
		, 0 AS Odds
		, 0 AS modds
		, b.Stake
		, b.actual_stake
		, b.Status
		, b.Transdate
		, b.winlostdate
		, (b.winlost - b.actual_stake) AS winlost
		, b.awinlost
		, b.mwinlost
		, b.swinlost
		, b.PlayerComm
		, (b.comm - b.playercomm)	AS comm
		, (b.acomm - b.comm)		AS acomm
		, (b.scomm - b.acomm)		AS scomm
		, b.APositiontaking
		, b.MPositiontaking
		, b.SPositiontaking
		, b.TPositiontaking
		, b.discount
		, b.adiscount
		, b.sdiscount
		, 0 AS Liveindicator
		, 0 AS Livehomescore
		, 0 AS Liveawayscore
		, 0 AS finalhomescore
		, 0 AS finalawayscore
		, 0 AS hthomescore
		, 0 AS htawayscore
		, b.IP
		, 0 AS LeagueID
		, 0 AS MatchID
		, '' AS MatchCode
		, '' AS Race
		, b.winlostdate AS eventdate
		, 0 AS HomeID
		, 0 AS AwayID
		, '' AS Betstatus
		, CONVERT(BIT, 0) AS IsNeutral
		, '' AS Placing
		, '' AS showtime
		, ISNULL(bm.betcheck, '') AS BetCheck
		, CASE WHEN b.comstatus = '1' THEN '1' 
				ELSE '0' 
		END		AS comstatus
		, '' AS transdesc
		, 0 AS OddsSpread
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN @tempCust c ON b.transid = c.transid
--				AND b.custid = c.custid
		LEFT JOIN dbo.bettransm AS bm WITH (NOLOCK) ON bm.refno = b.refno AND bm.bettype = 18001
	WHERE c.WhTicket = 1
		AND c.EventType = 0
		AND c.ProductID = 15

	/* 
	- SB	: ProductID = 1
	- NG	: ProductID = 3
	- LC	: ProductID = 4
	- VS	: ProductID = 5
	*/
	UNION ALL
	SELECT
		b.transid
		, b.refno
		, b.custid
		, b.username
		, m.Sporttype
		, b.Bettype
		, ISNULL(b.betid, 0)
		, b.betteam
		, CASE
			WHEN c.ProductID IN (4) THEN 0
			ELSE b.hdp1
		END AS hdp1
		, CASE
			WHEN c.ProductID IN (3, 4) THEN 0
			ELSE b.hdp2
		END AS hdp2
		, b.oddstype
		, b.oddsid
		, b.odds 
		, b.modds
		, b.stake 
		, b.actual_stake
		, CASE
			WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
			ELSE b.status 
		END AS status
		, b.transdate
		, b.winlostdate
		, (b.winlost-actual_stake) AS winlost
		, b.awinlost
		, b.mwinlost
		, b.swinlost
		, b.PlayerComm
		, (b.comm - b.playercomm)	AS comm
		, (b.acomm - b.comm)		AS acomm
		, (b.scomm - b.acomm)		AS scomm
		, b.APositiontaking
		, b.MPositiontaking
		, b.SPositiontaking
		, b.TPositiontaking
		, b.discount
		, b.adiscount
		, b.sdiscount
		, b.Liveindicator
		, b.Livehomescore
		, b.Liveawayscore
		, m.finalhomescore
		, m.finalawayscore
		, m.hthomescore
		, m.htawayscore
		, b.ip
		, m.leagueid
		, m.matchid
		, m.matchcode
		, '' AS Race
		, m.eventdate
		, m.homeid
		, m.awayid
		, m.betstatus
		, ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
		, '' AS Placing
		, CASE
			WHEN c.ProductId = 5 THEN CONVERT(NVARCHAR(50), m.kickofftime)
			ELSE ISNULL(m.showtime, '')
		END AS ShowTime
		, CASE
			WHEN (c.ProductId = 1 AND b.bettype IN (216,217)) THEN b.betcheck
			ELSE '' 
		END AS betcheck
		, CASE WHEN b.comstatus = '1' THEN '1' 
			ELSE '0' 
		END AS comstatus
		, ISNULL(b.transdesc, '') AS transdesc
		, ISNULL(b.oddsspread, 0) AS OddsSpread
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
		INNER JOIN @tempCust c ON b.transid = c.transid
--			AND b.custid = c.custid
	WHERE c.WhTicket = 1
		AND c.EventType = 1

	/* 
	- SB outright	: ProductID = 1
	- HR tickets	: ProductID = 2
	*/
	UNION ALL
	SELECT
		b.transid
		, b.refno
		, b.custid
		, b.username
		, l.sporttype
		, b.bettype
		, ISNULL(b.BetID,0)
		, '' AS Betteam
		, 0 AS hdp1 
		, 0 AS hdp2 
		, 0 AS OddsType
		, b.oddsid
		, b.Odds
		, b.modds
		, b.Stake 
		, b.actual_stake
		, b.status
		, b.transdate
		, b.winlostdate
		, (b.winlost - actual_stake) AS winlost
		, b.awinlost
		, b.mwinlost
		, b.swinlost
		, b.PlayerComm
		, (b.comm - b.playercomm) AS comm
		, (b.acomm - b.comm) AS acomm
		, (b.scomm - b.acomm) AS scomm
		, b.APositiontaking
		, b.MPositiontaking
		, b.SPositiontaking
		, b.TPositiontaking
		, b.discount
		, b.adiscount
		, b.sdiscount
		, 0 AS LiveIndicator
		, b.LiveHomescore
		, b.LiveAwayscore
		, 0 AS finalhomescore
		, 0 AS finalawayscore
		, 0 AS hthomescore
		, 0 AS htawayscore
		, b.IP
		, m.LeagueID
		, m.OrId AS MatchID
		, m.MatchCode
		, m.GroupMatch AS Race
		, m.eventdate
		, m.TeamID AS HomeID
		, 0 AS AwayID
		, '' AS Betstatus
		, CONVERT(BIT,0) AS IsNeutral
		, '' AS Placing
		, '' AS showtime
		, '' AS betcheck
		, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
		, '' AS transdesc
		, 0 AS OddsSpread
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.Outright AS m WITH (NOLOCK) ON b.matchid = m.orid
		INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
		INNER JOIN @tempCust AS c ON b.transid = c.transid
--			AND b.custid = c.custid
	WHERE c.WhTicket = 1
		AND c.EventType = 2

	/*
	- VS ticket	: ProductID = 5
	*/
	UNION ALL
	SELECT
		b.transid
		, b.refno
		, b.custid
		, b.username
		, r.Sporttype
		, b.Bettype
		, ISNULL(b.BetID,0)
		, '' AS betteam
		, b.hdp1
		, b.hdp2
		, 0 AS OddsType
		, b.oddsid
		, b.odds
		, b.modds
		, b.Stake 
		, b.actual_stake
		, b.status
		, b.transdate
		, b.winlostdate
		, (b.winlost-actual_stake) AS winlost
		, b.awinlost
		, b.mwinlost
		, b.swinlost
		, b.PlayerComm
		, (b.comm - b.playercomm)	AS comm
		, (b.acomm - b.comm)		AS acomm
		, (b.scomm - b.acomm)		AS scomm
		, b.APositiontaking
		, b.MPositiontaking
		, b.SPositiontaking
		, b.TPositiontaking
		, b.discount
		, b.adiscount
		, b.sdiscount
		, 0 AS Liveindicator
		, b.Livehomescore
		, b.Liveawayscore
		, 0 AS finalhomescore
		, 0 AS finalawayscore
		, 0 AS hthomescore
		, 0 AS htawayscore
		, b.IP
		, r.LeagueID
		, b.MatchID
		, CONVERT(NVARCHAR(50), o.RacerNum) AS MatchCode
		, CONVERT(NVARCHAR(50), b.oddsid) 	AS Race
		, o.eventdate
		, o.RacerID AS homeID
		, 0 AS awayID
		, '' AS Betstatus
		, CONVERT(BIT,0) AS IsNeutral
		, o.Placing
		, CONVERT(VARCHAR(20), r.EventTime, 113) AS showtime
		, '' AS betcheck
		, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
		, '' AS transdesc
		, 0 AS OddsSpread
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON b.oddsid = o.Orid
		INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
		INNER JOIN @tempCust AS c ON b.transid = c.transid
--			AND b.custid = c.custid
	WHERE c.WhTicket = 1
		AND c.EventType = 3

	RETURN;
END




GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_BetTicket_SelBettrans] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_BetTicket_SelBettrans] TO [bodbDownlineNetView]
GO
