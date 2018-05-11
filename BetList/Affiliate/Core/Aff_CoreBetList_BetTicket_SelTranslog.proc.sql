USE [bodb02]
GO
ALTER PROCEDURE [dbo].[Aff_CoreBetList_BetTicket_SelTranslog]
(
	@tempCust		[dbo].[TVP_TicketSportBettype]	READONLY
	, @TransStatus 	[dbo].[TVP_BetTicketStatus]		READONLY
)
AS

/*
	Created: Bobby.Nguyen
	Task: Re-factor core bet list
	DB: DBEXT.bodb02
	Original: DBAGE.bodb02.dbo.Age_CoreBetList_BetTicket_SelTranslog

	Revisions:
		- 20160308@Bobby: Implement LIC core bet list for Affiliate site
		- 20180511@Kos: Support Keno 6 new Mini Games [#Redmine: 93759]
					- Don't support Cockfighting anymore

	Param's Explanation:
	
	Dependences:
		- Aff_CoreBetList_BetTicket_SelMainInfo
*/

BEGIN
	SET NOCOUNT ON;

	/*
		- Keno			: ProductId = 8
		- Gold Deluxe	: ProductId = 12
		- Colossus Bet	: ProductId = 15
	*/
	SELECT
		b.translogid AS transid
		, b.translogid AS refno
		, b.custid
		, b.UserName
		, CASE
			WHEN c.ProductID = 8 THEN 202
			WHEN c.ProductID = 12 THEN 255
			WHEN c.ProductID = 15 THEN 204
			ELSE 0
		END	AS Sporttype
		, b.GameId AS bettype
		, 0 AS betid
		, '' AS betteam
		, 0 AS hdp1
		, 0 AS hdp2
		, 0 AS OddsType
		, 0 AS oddsid
		, b.odds
		, 0 AS modds
		, b.Stake
		, b.actual_stake 
		, b.Status
		, b.transdate
		, b.winlostdate
		, 0 AS Winlost
		, 0 AS awinlost
		, 0 AS mwinlost
		, 0 AS swinlost
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
		, 0 AS Livehomescore
		, 0 AS Liveawayscore
		, 0 AS finalhomescore
		, 0 AS finalawayscore
		, 0 AS hthomescore
		, 0 AS htawayscore
		, b.ip
		, 0 AS LeagueID
		, CASE
			WHEN c.ProductID = 12 THEN 255
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
			WHEN c.ProductID = 8 THEN ISNULL(b.custom2, '')
			WHEN c.ProductID = 12 AND b.gameid IN (1701, 1702) THEN b.Gameid3rd
			WHEN c.ProductID = 15 THEN b.Tranid3rd
			ELSE ''
		END AS betcheck
		, 0	AS comstatus
		, CASE
			WHEN c.ProductID IN (8, 15) THEN b.transdesc
			ELSE ''
		END AS transdesc
		, 0 AS OddsSpread
	FROM dbo.translog AS b WITH (NOLOCK)
		INNER JOIN @tempCust AS c ON b.translogid = c.transid
	WHERE c.WhTicket = 0
		AND c.EventType = 0
		AND b.statusID IN (0, 1)

	/*
		- SportsBook	: ProductId = 1 -> Metric Gaming bettype(801-899)
	*/
	UNION ALL
	SELECT
		b.translogid AS transid
		, b.translogid AS refno
		, b.custid
		, b.username
		, m.sporttype
		, b.gameid AS bettype
		, 0 AS betid
		, '' AS betteam
		, 0 AS hdp1
		, 0 AS hdp2
		, CASE
			WHEN b.gameid BETWEEN 801 AND 899 THEN CONVERT(TINYINT, ISNULL(b.custom1, 0))
			ELSE 0
		END AS OddsType
		, 0 AS oddsid
		, b.odds
		, 0 AS modds
		, b.stake
		, b.actual_stake
		, b.status
		, b.transdate
		, b.winlostdate
		, 0 AS winlost
		, 0 AS awinlost
		, 0 AS mwinlost
		, 0 AS swinlost
		, 0 AS PlayerComm
		, 0 AS comm
		, 0 AS acomm
		, 0 AS scomm
		, b.apositiontaking
		, b.mpositiontaking
		, b.spositiontaking
		, b.TPositiontaking
		, b.discount
		, b.adiscount
		, b.sdiscount
		, 0 AS Liveindicator
		, 0 AS Livehomescore
		, 0 AS Liveawayscore
		, m.finalhomescore
		, m.finalawayscore
		, m.hthomescore
		, m.htawayscore
		, b.ip
		, m.leagueid
		, m.MatchID
		, m.MatchCode
		, '' AS Race
		, m.eventdate
		, m.HomeID
		, m.AwayID
		, m.Betstatus
		, ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
		,'' AS Placing
		, ISNULL(m.showtime,'') AS showtime
		, '' AS betcheck
		, 0 AS comstatus
		,b.transdesc
		, 0 AS OddsSpread
	FROM dbo.translog AS b WITH (NOLOCK)
		INNER JOIN @tempCust AS c ON b.translogid = c.transid
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.eventid = m.matchid
	WHERE c.WhTicket = 0
		AND c.EventType = 1
		AND b.statusID IN (0, 1)

	RETURN;
END

GO
GRANT EXECUTE ON [dbo].[Aff_CoreBetList_BetTicket_SelTranslog] TO [bodbAdminNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Aff_CoreBetList_BetTicket_SelTranslog] TO [bodbDownlineNet] AS [dbo]
GO
