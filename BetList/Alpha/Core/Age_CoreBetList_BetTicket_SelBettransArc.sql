USE [bodb_archive]
GO
/****** Object:  StoredProcedure [dbo].[Age_CoreBetList_Mem_SelBetTicket]    Script Date: 5/11/2015 10:31:30 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Age_CoreBetList_BetTicket_SelBettransArc]
(
	@tempCust	TVP_TicketSportBettype READONLY
)
AS

/*
	Created: Bobby.Nguyen
	Task : Re-factor core betlist and apply GD product
	DB: DBARC.bodb_archive
	Original: 

	Revisions:
		- 20150504@Bobby: Create new SP
		- 20150827@Kos: Add column OddsSpread to support Myanmar Odds
		- 20150831@Bobby: Bug#42652 - Update for joining with outright_bk and VSOutright_bk
		- 20150831@Kos: Support Colossus Bet
		- 20151022@Kos: Return [bettransm].[betcheck] to support view CB ticket detail
		- 20151118@Kos: Remove index hint to enhance performance (#47704)
		- 20151214@Kos: Support Cockfighting (#Redmine: 48850)
		- 20160107@Kos: Support RNG Casino Single Wallet [Redmine: #48958]
		- 20160125@Kos: Support PH All In One 1.2 [Redmine: #50897]
		- 20160125@Kos: Fix Colossus Bet result issue
		- 20160217@Kos: Support AllBet [Redmine: #50864]
		- 20160401@Kos: Support Voidbridge [#Redmine: 54643]

	Param's Explanation:
	
	Dependences:
		- Age_CoreBetList_BetTicket_SelMainInfo
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @custInfo TABLE
	(
		CustId		INT
		, Username	NVARCHAR(30)
	);

	INSERT INTO @custInfo
	SELECT c.CustId,
		c.Username
	FROM bodb02.dbo.custinfo c WITH (NOLOCK)
		INNER JOIN @tempCust t ON c.custid = t.custid
	GROUP BY c.custid, c.username
	
	/*
		- Mix & System Parlay	: ProductId = 1
		- Casino				: ProductId = 6
		- Bingo					: ProductId = 7
		- Keno					: ProductId = 8
		- P2P					: ProductId = 9
		- Gold Deluxe			: ProductId = 12
		- Cockfighting			: ProductId = 19
		- AllBet				: ProductId = 21
		- Voidbridge			: ProductId = 22
	*/
	SELECT
		CASE WHEN (b.bettype = 29 AND ISNULL(b.betid, 0) > 0) THEN b.betid
			ELSE b.transid
		END AS transid
		, b.refno
		, b.custid
		, ci.username
		, CASE
			WHEN c.ProductID = 6 AND b.bettype = 71 THEN 251
			WHEN c.ProductID = 6 AND b.bettype <> 71 THEN b.matchid
			WHEN c.ProductID = 7 THEN 252
			WHEN c.ProductID = 8 THEN 202
			WHEN c.ProductID = 9 THEN 253 
			WHEN c.ProductID = 12 THEN 255
			WHEN c.ProductID = 19 THEN 206
			WHEN c.ProductID = 21 THEN 211
			WHEN c.ProductID = 22 THEN 212
			ELSE 0
		END AS Sporttype
		, b.bettype
		, ISNULL(b.BetID, 0)
		, CASE
			WHEN c.ProductID = 1 THEN b.Betteam
			WHEN c.ProductID = 8 THEN fnc.ChoiceId
			ELSE ''
		END AS Betteam
		, CASE
			WHEN c.ProductID = 1 THEN b.hdp1
			ELSE 0
		END AS hdp1
		, CASE
			WHEN c.ProductID = 1 THEN b.hdp2
			ELSE 0
		END AS hdp2
		, CASE
			WHEN c.ProductID IN (8, 19) THEN b.OddsType
			ELSE 0
		END AS OddsType
		, b.oddsid
		, CASE
			WHEN c.ProductID IN ( 1, 8, 12, 19 ) THEN b.Odds
			ELSE 0
		END AS Odds
		, CASE
			WHEN c.ProductID IN ( 1 ) THEN b.modds 
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
			WHEN c.ProductID = 1 THEN b.Livehomescore
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
		, CASE
			WHEN c.ProductID = 8 THEN fnc.GameId
			WHEN c.ProductID = 12 THEN 255
			WHEN c.ProductID = 19 THEN b.betdaqid
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
			ELSE ''
		END	AS betcheck
		, CASE WHEN b.comstatus = '1' THEN '1' 
				ELSE '0' 
			END AS comstatus
		, CASE
			WHEN c.ProductID = 6 AND b.bettype <> 71 THEN b.transdesc
			WHEN c.ProductId IN (19, 22) THEN b.transdesc
			ELSE ''
		END AS transdesc
		, 0 AS OddsSpread
	FROM dbo.bettrans_bk AS b WITH (NOLOCK) --, INDEX=IX_custid)
		INNER JOIN @tempCust AS c ON b.transid = c.transid
		--	AND b.custid = c.custid
		INNER JOIN @custInfo AS ci
		--ON b.custid = ci.custid
		ON c.custid = ci.custid
		OUTER APPLY [dbo].[f_ParseTransDesc](b.transdesc, b.bettype) fnc
	WHERE	c.WhTicket = 3
		AND c.EventType = 0
		AND c.ProductID <> 15	-- not Colossus Bet

	/*
	- Colossus Bet : ProductId = 15
	*/
	UNION ALL
	SELECT
		b.transid
		, b.refno
		, b.custid
		, ci.username
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
	FROM dbo.bettrans_bk AS b WITH (NOLOCK) --, INDEX=IX_custid)
		INNER JOIN @tempCust AS c ON b.transid = c.transid
		--	AND b.custid = c.custid
		INNER JOIN @custInfo AS ci
		--ON b.custid = ci.custid
		ON c.custid   = ci.custid
		LEFT JOIN dbo.bettransm AS bm WITH (NOLOCK) ON bm.refno = b.refno AND bm.bettype = 18001
	WHERE	c.WhTicket = 3
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
		, ci.username
		, m.Sporttype
		, b.Bettype
		, ISNULL(b.BetID,0)
		, b.betteam
		, CASE
			WHEN c.ProductID IN (4) THEN 0
			ELSE b.hdp1
		END AS hdp1
		, CASE
			WHEN c.ProductID IN (3, 4) THEN 0
			ELSE b.hdp2
		END AS hdp2
		, b.OddsType 
		, b.oddsid
		, b.odds 
		, b.modds
		, b.stake 
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
		, b.Liveindicator
		, b.Livehomescore
		, b.Liveawayscore
		, m.finalhomescore
		, m.finalawayscore
		, m.hthomescore
		, m.htawayscore
		, b.IP
		, m.LeagueID
		, m.MatchID
		, m.MatchCode
		, '' AS Race
		, m.eventdate
		, m.HomeID
		, m.AwayID
		, m.Betstatus
		, ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
		, '' AS Placing
		, ISNULL(m.showtime,'') AS showtime
		, CASE 
			WHEN (c.ProductId = 1 AND b.bettype IN (216,217)) THEN b.betcheck 
			ELSE '' 
		END AS betcheck
		, CASE
			WHEN b.comstatus = '1' THEN '1' 
			ELSE '0' 
		END AS comstatus
		, ISNULL(b.transdesc, '') AS transdesc
		, ISNULL(b.oddsspread, 0) AS OddsSpread
	FROM dbo.bettrans_bk AS b WITH (NOLOCK) --, INDEX=IX_custid)
		INNER JOIN dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
		INNER JOIN @tempCust c ON b.transid = c.transid
		--	AND b.custid = c.custid
		INNER JOIN @custInfo ci
		--ON b.custid = ci.custid
		ON c.custid = ci.custid
	WHERE c.WhTicket = 3
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
		, ci.username
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
	FROM dbo.bettrans_bk AS b WITH (NOLOCK) --, INDEX=IX_custid)
		INNER JOIN dbo.Outright_bk AS m WITH (NOLOCK) ON b.matchid = m.orid
		INNER JOIN bodb02.dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
		INNER JOIN @tempCust c ON b.transid = c.transid
		--	AND b.custid = c.custid
		INNER JOIN @custInfo ci
		--ON b.custid = ci.custid
		ON c.custid = ci.custid
	WHERE c.WhTicket = 3
		AND c.EventType = 2

	/*
	- VS ticket	: ProductID = 5
	*/
	UNION ALL
	SELECT
		b.transid
		, b.refno
		, b.custid
		, ci.username 
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
	FROM dbo.bettrans_bk AS b WITH (NOLOCK) --, INDEX=IX_custid)
		INNER JOIN dbo.VSOutright_bk o WITH (NOLOCK) ON b.oddsid = o.Orid
		INNER JOIN bodb02.dbo.VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
		INNER JOIN @tempCust c ON b.transid = c.transid
		--	AND b.custid = c.custid
		INNER JOIN @custInfo ci
		--ON b.custid = ci.custid
		ON c.custid = ci.custid
	WHERE c.WhTicket = 3
		AND c.EventType = 3

	RETURN
END





GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_BetTicket_SelBettransArc] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_BetTicket_SelBettransArc] TO [bodbDownlineNetView]
GO