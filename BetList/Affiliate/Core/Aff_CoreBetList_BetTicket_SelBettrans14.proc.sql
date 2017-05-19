USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Age_CoreBetList_Mem_SelBetTicket]    Script Date: 5/11/2015 10:31:30 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Aff_CoreBetList_BetTicket_SelBettrans14]
(
	@tempCust		[dbo].[TVP_TicketSportBettype]	READONLY
	, @TransStatus	[dbo].[TVP_BetTicketStatus]		READONLY
)
AS

/*
	Created: Bobby.Nguyen
	Task: Re-factor core betlist and apply GD product
	DB: DBEXT.bodb02
	Original:

	Revisions:
		- 20160308@Bobby: Implement LIC core bet list for Affiliate site
		- 20160415@Bobby: Update changes for combo parlay [#Redmine: 56136]
		- 20170302@Kos: Support KickOffTime for Virtual Soccer and Virtual Tennis [#Redmine: 71906]
					  - Don't support P2P and Bingo in bettrans and bettrans14 anymore
		- 20170519@Kos: Support CashOut [#Redmine: 71963]

	Param's Explanation:
	
	Dependences:
		- Aff_CoreBetList_BetTicket_SelMainInfo
*/

BEGIN
	SET NOCOUNT ON;
	
	/*
		- Mix & System Parlay	: ProductID = 1
		- Casino				: ProductID = 6
		- Keno					: ProductId = 8
		- AG Casino				: ProductId = 11
		- Gold Deluxe			: ProductID = 12
		- Cockfighting			: ProductID = 19
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
			WHEN c.ProductID = 8 THEN 202
			WHEN c.ProductID = 11 THEN 250
			WHEN c.ProductID = 12 THEN 255
			WHEN c.ProductID = 19 THEN 206
			ELSE 0
		END AS Sporttype
		, b.bettype
		, ISNULL(b.BetID, 0)
		, CASE 
			WHEN c.ProductID = 1 THEN b.Betteam
			WHEN c.ProductID = 8 THEN fnc.ChoiceId
			ELSE '' 
		END						AS Betteam
		, CASE 
			WHEN c.ProductID = 1 THEN b.hdp1 
			ELSE 0
		END						AS hdp1
		, CASE 
			WHEN c.ProductID = 1 THEN b.hdp2
			ELSE 0 
		END						AS hdp2
		, CASE 
			WHEN c.ProductID IN (8, 19) THEN b.OddsType
			ELSE 0
		END		AS OddsType
		, b.oddsid
		, CASE
			WHEN c.ProductID IN ( 1, 8, 12, 19 ) THEN b.Odds 
			ELSE 0 
		END						AS Odds
		, CASE WHEN c.ProductID IN ( 1 )
					THEN b.modds 
				ELSE 0 
			END						AS modds
		, b.Stake
		, b.actual_stake 
		, b.Status
		, b.Transdate
		, b.winlostdate
		, CASE WHEN b.bettype IN (23102, 23002, 23202) THEN 0
				ELSE (b.winlost - b.actual_stake)
			END	AS winlost
		, b.awinlost
		, b.mwinlost
		, b.swinlost
		, b.playercomm
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
		, CASE WHEN c.ProductID = 1
				THEN b.Liveindicator
			ELSE 0
		END		AS Liveindicator
		, CASE WHEN c.ProductID = 1 
				THEN b.Livehomescore
			ELSE 0
		END		AS Livehomescore
		, CASE WHEN c.ProductID = 1 
				THEN b.Liveawayscore
			ELSE 0
		END AS Liveawayscore
		, 0 AS finalhomescore
		, 0 AS finalawayscore
		, 0 AS hthomescore
		, 0 AS htawayscore
		, b.ip
		, 0 AS LeagueID
		,CASE
			WHEN c.ProductID = 8 THEN fnc.GameId
			WHEN c.ProductID = 12 THEN 255
			WHEN c.ProductID = 19 THEN b.betdaqid
			ELSE 0
		END		AS MatchID
		, '' AS MatchCode
		, '' AS Race
		, b.winlostdate AS eventdate
		, 0 AS HomeID
		, 0 AS AwayID
		, '' AS Betstatus
		, CONVERT(BIT,0) AS IsNeutral
		, '' AS Placing
		, '' 	AS showtime
		, CASE 
			WHEN c.ProductID = 12 AND b.bettype IN (1701, 1702) THEN b.betcheck
			WHEN c.ProductID = 19 THEN b.betcheck 
			WHEN b.bettype = 29 THEN ISNULL(b.betcheck, '')
			ELSE ''
		END	AS betcheck
		, CASE WHEN b.comstatus = '1' THEN '1'
				ELSE '0' 
		END		AS comstatus
		, CASE
			WHEN c.ProductId = 19 THEN b.transdesc
			WHEN c.ProductID = 6 AND b.bettype <> 71 THEN b.transdesc
			ELSE ''
		END AS transdesc
		, 0 AS OddsSpread
		, -1 AS BetdaqId
		, '' AS ExtraInfo
		, 0 AS OriginalBetType
	FROM dbo.bettrans14 AS b WITH (NOLOCK)
		INNER JOIN @tempCust AS c ON b.transid = c.transid
		OUTER APPLY [dbo].[f_ParseTransDesc](b.transdesc, b.bettype) fnc
	WHERE c.EventType = 0
		AND c.WhTicket = 2
		AND c.ProductID <> 15	-- not Colossus Bet

	/*
	- Colossus Bet : ProductID = 15
	*/
	UNION ALL
	SELECT
		b.transid
		, b.refno
		, b.custid
		, b.Username
		, 204 AS Sporttype
		, b.bettype
		, ISNULL(b.betid, 0)
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
		, (b.winlost - b.actual_stake)	AS winlost
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
		, ISNULL(bm.betcheck, '') AS BetCheck
		, CASE WHEN b.comstatus = '1' THEN '1' 
				ELSE '0' 
		END		AS comstatus
		, '' AS transdesc
		, 0 AS OddsSpread
		, -1 AS BetdaqId
		, '' AS ExtraInfo
		, 0 AS OriginalBetType
	FROM dbo.bettrans14 AS b WITH (NOLOCK)
		INNER JOIN @tempCust AS c ON b.transid = c.transid
		LEFT JOIN dbo.bettransm14 AS bm WITH (NOLOCK) ON bm.refno = b.refno AND bm.bettype = 18001
	WHERE c.EventType = 0
		AND c.WhTicket = 2
		AND c.ProductID = 15

	/*
	- Sportsbook		: ProductID = 1
	- Number Game		: ProductID = 3
	- Live Casino		: ProductID = 4
	- Virtual Sports	: ProductID = 5
	*/
	UNION ALL
	SELECT
		b.transid
		, b.refno
		, b.custid
		, b.username
		, m.sporttype
		, b.bettype
		, ISNULL(b.betid, 0)
		, b.betteam
		, CASE WHEN c.ProductID IN (4) THEN 0
				ELSE b.hdp1
		END		AS hdp1
		, CASE WHEN c.ProductID IN (3, 4) THEN 0
				ELSE b.hdp2
		END		AS hdp2
		, b.oddstype
		, b.oddsid
		, b.odds
		, b.modds
		, b.stake
		, b.actual_stake
		, CASE WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
			ELSE b.status 
		END AS status
		, b.transdate
		, b.winlostdate
		, (b.winlost - actual_stake) AS winlost
		, b.awinlost
		, b.mwinlost
		, b.swinlost
		, b.playercomm
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
		, b.liveindicator
		, b.livehomescore
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
		, m.HomeID
		, m.AwayID
		, m.Betstatus
		, ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
		, '' AS Placing
		, CASE
			WHEN c.ProductId = 5 THEN CONVERT(NVARCHAR(50), m.kickofftime)
			ELSE ISNULL(m.showtime, '')
		END AS ShowTime
		, CASE WHEN (c.ProductId = 1 AND b.bettype IN (154, 155, 156, 216, 217, 1311, 1312, 1316, 1317, 1318, 1324))
				THEN b.betcheck
				ELSE '' 
			END	AS betcheck
		, CASE WHEN b.comstatus = '1'
				THEN '1'
			ELSE '0'
		END AS comstatus
		, ISNULL(b.transdesc, '') AS transdesc
		, ISNULL(b.oddsspread, 0) AS OddsSpread
		, CASE
			WHEN c.ProductID = 1 THEN ISNULL(b.betdaqid, -1)
			ELSE -1
		END AS BetdaqId
		, CASE
			WHEN c.ProductID = 1 THEN ISNULL(b.ExtraInfo, '')
			ELSE ''
		END AS ExtraInfo
		, 0 AS OriginalBetType
	FROM dbo.bettrans14 AS b WITH (NOLOCK)
		INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
		INNER JOIN @tempCust AS c ON b.transid = c.transid
	WHERE c.EventType = 1 AND c.WhTicket	= 2

	/* 
	- SB outright	: ProductID = 1
	- HR			: ProductID = 2
	*/
	UNION ALL
	SELECT
		b.transid
		, b.refno
		, b.custid
		, b.username
		, l.sporttype
		, b.bettype
		, ISNULL(b.betid, 0)
		, '' AS Betteam
		, 0 AS hdp1
		, 0 AS hdp2
		, 0 AS OddsType
		, b.oddsid
		, b.Odds
		, b.modds
		, b.stake
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
		, b.ip
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
		, -1 AS BetdaqId
		, '' AS ExtraInfo
		, 0 AS OriginalBetType
	FROM dbo.bettrans14 AS b WITH (NOLOCK)
		INNER JOIN dbo.outright14 AS m WITH (NOLOCK) ON b.matchid = m.orid
		INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
		INNER JOIN @tempCust AS c ON b.transid = c.transid
	WHERE c.EventType = 2 AND c.WhTicket = 2

	/*
	- Virtual Sports	: ProductID = 5
	*/
	UNION ALL
	SELECT
		b.transid
		, b.refno
		, b.custid
		, b.username
		, r.SportType
		, b.bettype
		, ISNULL(b.betid, 0)
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
		, 0 AS Liveindicator
		, b.livehomescore
		, b.liveawayscore
		, 0 AS finalhomescore
		, 0 AS finalawayscore
		, 0 AS hthomescore
		, 0 AS htawayscore
		, b.ip
		, r.LeagueID
		, b.MatchID
		, CONVERT(NVARCHAR(50), o.RacerNum) AS MatchCode
		, CONVERT(NVARCHAR(50), b.oddsid) AS Race
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
		, -1 AS BetdaqId
		, '' AS ExtraInfo
		, 0 AS OriginalBetType
	FROM dbo.bettrans14 AS b WITH (NOLOCK)
		INNER JOIN dbo.VSOutright14 AS o WITH (NOLOCK) ON b.oddsid = o.Orid
		INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
		INNER JOIN @tempCust AS c ON b.transid = c.transid
	WHERE c.EventType = 3 AND c.WhTicket = 2

	RETURN;
END
GO
