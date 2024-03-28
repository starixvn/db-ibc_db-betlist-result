/*<info serverAlias="DBARC-bodb_Archive" executers="wsv_alp, wsv_alpv" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_CoreBetList_BetTicket_SelBettransArc]
(
	@tempCust	TVP_TicketSportBettype READONLY
)
AS

/*
	Created: Bobby
	Task: Re-factor core betlist and apply GD product
	DB: DBARC.bodb_Archive
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
		- 20160401@Kos: Support Macau Games [#Redmine: 54643]
		- 20160411@Kos: Support Combo Parlay [Redmine: #55282]
		- 20160812@Kos: Support NG2
		- 20161101@Kos: Support Fishing World [#Redmine: 65934]
		- 20170301@Kos: Support KickOffTime for Virtual Soccer and Virtual Tennis [#Redmine: 71906]
		- 20170620@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20170705@Kos: Support Keno Lottery [#Redmine: 77929]
		- 20170718@Kos: Don't parse transdesc for Keno anymore [#Redmine: 80082]
		- 20170829@Kos: Support Lucky 3 [#Redmine: 75277]
		- 20171031@Kos: Support Bullfighting [#Redmine: 84961]
		- 20180202@Kos: Don't support Cockfighting [#Redmine: 86086]
		- 20180323@Kos: Support ONERnG Jackpot [#Redmine: 88652]
		- 20180418@Kos: Support Pragmatic Casino [#Redmine: 92160]
		- 20180510@Kos: Support Keno 6 new Mini Games [#Redmine: 93759]
		- 20180515@Kos: Add Match No for Bullfighting [#Redmine: 84961]
		- 20180711@Kos: Support Poker Games [#Redmine: 97565]
		- 20181006@Kos: Support 2 new status Result Pending and Under Settlement [#Redmine: 101949]
		- 20181123@Kos: Support Gold Deluxe - SicBo & BidMe [#Redmine: 101690]
		- 20181218@Kos: Support E-Sports phase 2b [#Redmine: 106456]
		- 20190506@Kos: Show match KO time for single ticket [Redmine: #112092]
		- 20190524@Kos: Support BetBuilder [Redmine: #106905]
		- 20190611@Kos: Support Card Club [Redmine: #107645]
		- 20190829@Kos: Don't support inactive products anymore [Redmine: #119100]

	Param's Explanation:

	Dependences:
		- Age_CoreBetList_BetTicket_SelMainInfoArc
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @CustInfo TABLE (
		CustId		INT,
		Username	NVARCHAR(30)
	);

	INSERT INTO @CustInfo
	SELECT c.custid,
		c.username
	FROM bodb02.dbo.custinfo AS c WITH (NOLOCK)
		INNER JOIN @tempCust AS t ON c.custid = t.custid
	GROUP BY c.custid,
		c.username

	/*
		- Mix & System Parlay	: ProductId = 1
		- Casino				: ProductId = 6
		- Keno					: ProductId = 8
		- Gold Deluxe			: ProductId = 12
		- AllBet				: ProductId = 21
		- Macau Games			: ProductId = 22
		- NG2					: ProductId = 23
		- Fishing World			: ProductId = 24
		- Mix Parlay			: ProductId = 27
		- Lottery				: ProductId = 28
		- Pragmatic Casino		: ProductId = 32
		- Card Club				: ProductId = 34
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
			WHEN c.ProductID = 8 THEN 202
			WHEN c.ProductID = 12 THEN 255
			WHEN c.ProductID = 21 THEN 211
			WHEN c.ProductID = 22 THEN 212
			WHEN c.ProductId = 23 AND b.bettype BETWEEN 2501 AND 2539 THEN 213
			WHEN c.ProductId = 23 AND b.bettype BETWEEN 2541 AND 2579 THEN 214
			WHEN c.ProductId = 23 AND b.bettype BETWEEN 2581 AND 2619 THEN 215
			WHEN c.ProductId = 23 AND b.bettype BETWEEN 2621 AND 2659 THEN 216
			WHEN c.ProductId = 23 AND b.bettype BETWEEN 2681 AND 2699 THEN 218
			WHEN c.ProductId = 24 THEN 219
			WHEN c.ProductId = 28 THEN 220
			WHEN c.ProductId = 32 THEN 248
			WHEN c.ProductId = 34 THEN b.matchid
			ELSE 0
		END AS Sporttype
		, b.bettype
		, ISNULL(b.betid, 0)
		, CASE
			WHEN c.ProductID IN (1, 27) THEN b.Betteam
			ELSE ''
		END AS Betteam
		, CASE
			WHEN c.ProductID IN (1, 23, 27) THEN b.hdp1
			ELSE 0
		END AS hdp1
		, CASE
			WHEN c.ProductID IN (1, 23, 27) THEN b.hdp2
			ELSE 0
		END AS hdp2
		, CASE
			WHEN c.ProductID IN (8) THEN b.OddsType
			ELSE 0
		END AS OddsType
		, b.oddsid
		, CASE
			WHEN c.ProductID IN (1, 6, 8, 12, 23, 27, 28) THEN b.Odds
			ELSE 0
		END AS Odds
		, CASE
			WHEN c.ProductID IN (1, 27) THEN b.modds
			ELSE 0
		END AS modds
		, b.stake
		, b.actual_stake
		, b.status
		, 0 AS SettlementStatus
		, b.Transdate
		, b.winlostdate
		, (b.winlost - b.actual_stake) AS WinLost
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
		, b.ip
		, 0 AS LeagueID
		, CASE
			WHEN c.ProductID = 12 THEN 255
			WHEN c.ProductID = 23 THEN b.betdaqid
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
			WHEN c.ProductID IN (1, 12, 27) THEN ISNULL(b.betcheck, '')
			WHEN c.ProductID = 8 THEN ISNULL(b.comstatus, '')
			ELSE ''
		END	AS betcheck
		, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS ComStatus
		, CASE
			WHEN c.ProductID = 6 AND b.bettype <> 71 THEN b.transdesc
			WHEN c.ProductId IN (8, 22, 23, 24, 28, 32, 34) THEN b.transdesc
			ELSE ''
		END AS transdesc
		, CASE
			WHEN c.ProductID = 6 AND b.bettype <> 71 THEN ISNULL(b.oddsspread, 0)
			ELSE 0
		END AS OddsSpread
		, -1 AS BetdaqId
		, '' AS ExtraInfo
	FROM dbo.bettrans_bk AS b WITH (NOLOCK)
		INNER JOIN @tempCust AS c ON b.transid = c.transid
		INNER JOIN @custInfo AS ci ON c.custid = ci.custid
	WHERE c.WhTicket = 3
		AND c.EventType = 0

	/*
	- Sportsbook				: ProductID = 1
	- Number Game				: ProductID = 3
	- Virtual Sports			: ProductID = 5
	- Betradar Virtual Sports	: ProductID = 27
	*/
	UNION ALL
	SELECT
		b.transid
		, b.refno
		, b.custid
		, ci.username
		, m.sporttype
		, b.bettype
		, ISNULL(b.betid, 0)
		, b.betteam
		, b.hdp1
		, CASE
			WHEN c.ProductID IN (3) THEN 0
			ELSE b.hdp2
		END AS hdp2
		, b.OddsType
		, b.oddsid
		, b.odds
		, b.modds
		, b.stake
		, b.actual_stake
		, b.status
		, 0 AS SettlementStatus
		, b.transdate
		, b.winlostdate
		, (b.winlost - b.actual_stake) AS WinLost
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
		, CASE
			WHEN c.ProductID IN (1, 3, 5, 27) THEN b.discount
			ELSE 0
		END AS ADiscount
		, CASE
			WHEN c.ProductID IN (1, 3, 5, 27) THEN b.adiscount
			ELSE 0
		END AS MDiscount
		, CASE
			WHEN c.ProductID IN (1, 3, 5, 27) THEN b.sdiscount
			ELSE 0
		END AS SDiscount
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
		, CASE
			WHEN c.ProductID = 1 THEN m.globalshowtime
			ELSE m.eventdate
		END AS EventDate
		, m.HomeID
		, m.AwayID
		, m.Betstatus
		, ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral
		, '' AS Placing
		, CASE
			WHEN c.ProductId IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
			ELSE ISNULL(m.showtime, '')
		END AS ShowTime
		, CASE 
			WHEN c.ProductId = 1 THEN b.betcheck
			ELSE ''
		END AS betcheck
		, CASE
			WHEN b.comstatus = '1' THEN '1' 
			ELSE '0' 
		END AS comstatus
		, CASE
			WHEN c.ProductID IN (1, 27) THEN ISNULL(b.transdesc, '')
			ELSE ''
		END AS TransDesc
		, CASE
			WHEN c.ProductID = 1 THEN ISNULL(b.oddsspread, 0)
			ELSE 0
		END AS OddsSpread
		, -1 AS BetdaqId
		, CASE
			WHEN c.ProductId = 1 THEN ISNULL(b.ExtraInfo, '')
			ELSE ''
		END AS ExtraInfo
	FROM dbo.bettrans_bk AS b WITH (NOLOCK)
		INNER JOIN dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
		INNER JOIN @tempCust AS c ON b.transid = c.transid
		INNER JOIN @custInfo AS ci ON c.custid = ci.custid
	WHERE c.WhTicket = 3
		AND c.EventType = 1

	/* 
		- Sportsbook outright	: ProductID = 1
	*/
	UNION ALL
	SELECT
		b.transid
		, b.refno
		, b.custid
		, ci.username
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
		, b.Stake
		, b.actual_stake
		, b.status
		, 0 AS SettlementStatus
		, b.transdate
		, b.winlostdate
		, (b.winlost - b.actual_stake) AS WinLost
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
	FROM dbo.bettrans_bk AS b WITH (NOLOCK)
		INNER JOIN dbo.outright_bk AS m WITH (NOLOCK) ON b.matchid = m.orid
		INNER JOIN bodb02.dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
		INNER JOIN @tempCust AS c ON b.transid = c.transid
		INNER JOIN @custInfo AS ci ON c.custid = ci.custid
	WHERE c.WhTicket = 3
		AND c.EventType = 2

	/*
	- Virtual Sports 	: ProductID = 5
	*/
	UNION ALL
	SELECT
		b.transid
		, b.refno
		, b.custid
		, ci.username
		, r.Sporttype
		, b.Bettype
		, ISNULL(b.betid, 0)
		, '' AS betteam
		, b.hdp1
		, b.hdp2
		, 0 AS OddsType
		, b.oddsid
		, b.odds
		, b.modds
		, b.stake
		, b.actual_stake
		, b.status
		, 0 AS SettlementStatus
		, b.transdate
		, b.winlostdate
		, (b.winlost - b.actual_stake) AS WinLost
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
		, b.Livehomescore
		, b.Liveawayscore
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
	FROM dbo.bettrans_bk AS b WITH (NOLOCK)
		INNER JOIN dbo.VSOutright_bk AS o WITH (NOLOCK) ON b.oddsid = o.Orid
		INNER JOIN bodb02.dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
		INNER JOIN @tempCust AS c ON b.transid = c.transid
		INNER JOIN @custInfo AS ci ON c.custid = ci.custid
	WHERE c.WhTicket = 3
		AND c.EventType = 3

	/*
		WhTicket = 8
		- ONERnG Jackpot	: ProductID = 6
	*/
	UNION ALL
	SELECT
		b.transid
		, b.refno
		, b.custid
		, b.username
		, b.productID AS SportType
		, b.gameID AS BetType
		, 0 AS BetId
		, '' AS BetTeam
		, 0 AS Hdp1
		, 0 AS Hdp2
		, 0 AS OddsType
		, 0 AS OddsId
		, b.odds
		, 0 AS MOdds
		, b.stake
		, b.actual_stake
		, b.status
		, 0 AS SettlementStatus
		, b.transdate
		, b.winlostdate
		, (b.winlost - b.actual_stake) AS WinLost
		, b.awinlost
		, b.mwinlost
		, b.swinlost
		, b.playercomm
		, (b.comm - b.playercomm) AS Comm
		, (b.acomm - b.comm) AS AComm
		, (b.scomm - b.acomm) AS SComm
		, b.apositiontaking
		, b.mpositiontaking
		, b.spositiontaking
		, b.tpositiontaking
		, b.discount AS ADiscount
		, b.adiscount AS MDiscount
		, b.sdiscount AS SDiscount
		, 0 AS LiveIndicator
		, 0 AS LiveHomeScore
		, 0 AS LiveAwayScore
		, 0 AS FinalHomeScore
		, 0 AS FinalAwayScore
		, 0 AS HtHomeScore
		, 0 AS HtAwayScore
		, b.ip
		, 0 AS LeagueId
		, 0 AS MatchId
		, '' AS MatchCode
		, '' AS Race
		, '' AS EventDate
		, 0 AS HomeId
		, 0 AS AwayId
		, '' AS BetStatus
		, 0 AS IsNeutral
		, '' AS Placing
		, '' AS ShowTime
		, b.TranId3rd AS BetCheck
		, '0' AS comstatus
		, ISNULL(b.transdesc, '') AS TransDesc
		, 0 AS OddsSpread
		, ISNULL(b.RefNo2, -1) AS BetdaqId
		, '' AS ExtraInfo
	FROM dbo.bettransRnG_bk AS b WITH (NOLOCK)
		INNER JOIN @tempCust AS c ON b.transid = c.transid
	WHERE c.WhTicket = 8

	RETURN
END

