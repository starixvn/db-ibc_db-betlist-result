USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Age_CoreBetList_Mem_SelBetTicket]    Script Date: 5/11/2015 10:31:30 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Age_CoreBetList_BetTicket_SelTranslog]
(
	@tempCust		[dbo].[TVP_TicketSportBettype]	READONLY
	, @TransStatus	[dbo].[TVP_BetTicketStatus]		READONLY
)
AS

/*
	Created: Bobby
	Task: Re-factor core bet list
	DB: DBAGE.bodb02
	Original:

	Revisions:
		- 20150504@Bobby: Create new SP
		- 20150827@Kos: Add column OddsSpread to support Myanmar Odds
		- 20150831@Kos: Support Colossus Bet
		- 20150907@Bobby: Enhance performance for SP core
		- 20151022@Kos: Return [translog].[tranid3rd] to support view ticket detail
		- 20151023@Bobby: Hotfix#46203 - Agent PT always show 0 in case of ticket running
		- 20151214@Kos: Support Cockfighting (#Redmine: 48850)
		- 20160111@Kos: Add @TransStatus param
		- 20170705@Kos: Support Keno Lottery [#Redmine: 77929]
		- 20170718@Kos: Don't parse transdesc for Keno anymore [#Redmine: 80082]
		- 20171031@Kos: Support Bullfighting [#Redmine: 84961]
		- 20180202@Kos: Don't support Cockfighting [#Redmine: 86086]
		- 20180323@Kos: Return BetdaqId to support ONERnG Jackpot [#Redmine: 88652]
		- 20180510@Kos: Support Keno 6 new Mini Games [#Redmine: 93759]

	Param's Explanation:

	Dependences:
		- Age_CoreBetList_BetTicket_SelMainInfo
*/

BEGIN
	SET NOCOUNT ON;

	/*
		EventType = 0
		- Keno			: ProductId = 8
		- Gold Deluxe	: ProductId = 12
		- Colossus Bet	: ProductId = 15
		- Lottery		: ProductId = 28
	*/
	SELECT
		b.translogid AS TransId
		, b.translogid AS RefNo
		, b.custid
		, b.Username
		, CASE
			WHEN c.ProductID = 8 THEN 202
			WHEN c.ProductID = 12 THEN 255
			WHEN c.ProductID = 15 THEN 204
			WHEN c.ProductID = 28 THEN 220
			ELSE 0
		END AS Sporttype
		, b.gameID AS BetType
		, 0 AS BetId
		, '' AS betteam
		, 0 AS Hdp1
		, 0 AS Hdp2
		, 0 AS OddsType
		, 0 AS OddsId
		, b.odds
		, 0 AS MOdds
		, b.stake
		, b.actual_stake
		, b.status
		, b.transdate
		, b.winlostdate
		, 0 AS Winlost
		, 0 AS AWinLost
		, 0 AS MWinLost
		, 0 AS SWinLost
		, 0 AS PlayerComm
		, 0 AS comm
		, 0 AS acomm
		, 0 AS scomm
		, b.APositiontaking
		, b.MPositiontaking
		, b.SPositiontaking
		, b.TPositiontaking
		, b.discount AS adiscount
		, b.adiscount AS mdiscount
		, b.sdiscount AS sdiscount
		, 0 AS Liveindicator
		, 0 AS LiveHomeScore
		, 0 AS LiveAwayScore
		, 0 AS FinalHomeScore
		, 0 AS FinalAwayScore
		, 0 AS HtHomeScore
		, 0 AS HtAwayScore
		, b.ip
		, 0 AS LeagueID
		, CASE
			WHEN c.ProductID = 12 THEN 255
			ELSE 0
		END AS MatchId
		, '' AS MatchCode
		, '' AS Race
		, b.winlostdate AS eventdate
		, 0 AS HomeID
		, 0 AS AwayID
		, '' AS Betstatus
		, CONVERT(BIT,0) AS IsNeutral
		, '' AS Placing
		, '' AS showtime
		, CASE 
			WHEN c.ProductID = 12 AND b.gameid IN (1701, 1702) THEN b.Gameid3rd
			WHEN c.ProductID = 15 THEN b.Tranid3rd
			WHEN c.ProductID = 8 THEN ISNULL(b.custom2, '')
			ELSE ''
		END AS BetCheck
		, 0 AS comstatus
		, CASE
			WHEN c.ProductID IN (8, 15, 28) THEN b.transdesc
			ELSE ''
		END AS TransDesc
		, 0 AS OddsSpread
		, -1 AS BetdaqId
	FROM dbo.translog AS b WITH (NOLOCK)
		INNER JOIN @tempCust AS c ON b.translogid = c.transid
	WHERE c.WhTicket = 0
		AND c.EventType = 0
		AND b.statusID IN (0, 1)

	/*
		EventType = 1
		- SportsBook	: ProductId = 1 -> Metric Gaming bettype(801-899)
	*/
	UNION ALL
	SELECT
		b.translogid AS TransId
		, b.translogid AS RefNo
		, b.custid
		, b.Username
		, m.sporttype
		, b.gameID AS BetType
		, 0 AS BetId
		, '' AS betteam
		, 0 AS Hdp1
		, 0 AS Hdp2
		, CASE
			WHEN b.gameid BETWEEN 801 AND 899 THEN CONVERT(TINYINT, ISNULL(b.custom1, 0))
			ELSE 0
		END AS OddsType
		, 0 AS OddsId
		, b.odds
		, 0 AS MOdds
		, b.stake
		, b.actual_stake
		, b.status
		, b.transdate
		, b.winlostdate
		, 0 AS WinLost
		, 0 AS AWinLost
		, 0 AS MWinLost
		, 0 AS SWinLost
		, 0 AS PlayerComm
		, 0 AS comm
		, 0 AS acomm
		, 0 AS scomm
		, b.apositiontaking
		, b.mpositiontaking
		, b.spositiontaking
		, b.tpositiontaking
		, b.discount
		, b.adiscount
		, b.sdiscount
		, 0 AS Liveindicator
		, 0 AS LiveHomeScore
		, 0 AS LiveAwayScore
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
		, ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral
		,'' AS Placing
		, ISNULL(m.showtime,'') AS showtime
		, '' AS betcheck
		, 0 AS comstatus
		, b.transdesc
		, 0 AS OddsSpread
		, -1 AS BetdaqId
	FROM dbo.translog AS b WITH (NOLOCK)
		INNER JOIN @tempCust AS c ON b.translogid = c.transid
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.eventid = m.matchid
	WHERE c.WhTicket = 0
		AND c.EventType = 1
		AND b.statusID IN (0, 1)

	/*
		EventType = 5
		- Bullfighting	: ProductId = 30
	*/
	UNION ALL
	SELECT
		b.translogid AS TransId
		, b.translogid AS RefNo
		, b.custid
		, b.Username
		, m.SportType
		, b.gameID AS BetType
		, 0 AS BetId
		, CASE
			WHEN c.ProductID = 30 THEN b.custom3
			ELSE ''
		END AS BetTeam
		, 0 AS Hdp1
		, 0 AS Hdp2
		, CASE
			WHEN c.ProductID = 30 THEN CONVERT(TINYINT, ISNULL(b.custom1, 0))
			ELSE 0
		END AS OddsType
		, 0 AS OddsId
		, b.odds
		, 0 AS MOdds
		, b.stake
		, b.actual_stake
		, b.status
		, b.transdate
		, b.winlostdate
		, 0 AS WinLost
		, 0 AS AWinLost
		, 0 AS MWinLost
		, 0 AS SWinLost
		, 0 AS PlayerComm
		, 0 AS comm
		, 0 AS acomm
		, 0 AS scomm
		, b.apositiontaking
		, b.mpositiontaking
		, b.spositiontaking
		, b.tpositiontaking
		, b.discount
		, b.adiscount
		, b.sdiscount
		, b.liveindicator
		, 0 AS LiveHomeScore
		, 0 AS LiveAwayScore
		, 0 AS FinalHomeScore
		, 0 AS FinalAwayScore
		, 0 AS HtHomeScore
		, 0 AS HtAwayScore
		, b.ip
		, m.League3rdId AS LeagueId
		, m.Match3rdId AS MatchId
		, m.MatchNo AS MatchCode
		, '' AS Race
		, m.EventDate
		, m.HomeId
		, m.AwayId
		, '' AS BetStatus
		, 0 AS IsNeutral
		, '' AS Placing
		, '' AS ShowTime
		, CASE
			WHEN c.ProductID = 30 THEN ISNULL(b.Tranid3rd, '')
			ELSE ''
		END AS BetCheck
		, 0 AS comstatus
		, CASE
			WHEN c.ProductID = 30 THEN ISNULL(b.transdesc, '')
			ELSE ''
		END AS TransDesc
		, 0 AS OddsSpread
		, -1 AS BetdaqId
	FROM dbo.translog AS b WITH (NOLOCK)
		INNER JOIN @tempCust AS c ON b.translogid = c.transid
		INNER JOIN dbo.Match3rd AS m WITH (NOLOCK) ON b.eventid = m.Match3rdId
	WHERE c.WhTicket = 0
		AND c.EventType = 5
		AND b.statusID IN (0, 1)

	RETURN;
END


GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_BetTicket_SelTranslog] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_BetTicket_SelTranslog] TO [bodbDownlineNetView]
GO
