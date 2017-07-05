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
	, @TransStatus 	[dbo].[TVP_BetTicketStatus]		READONLY
)
AS

/*
	Created: Bobby.Nguyen
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

	Param's Explanation:
	
	Dependences:
		- Age_CoreBetList_BetTicket_SelMainInfo
*/

BEGIN
	SET NOCOUNT ON;

	/*
		- Keno			: ProductId = 8
		- Gold Deluxe	: ProductId = 12
		- Colossus Bet	: ProductId = 15
		- Cockfighting	: ProductId = 19
		- Lottery		: ProductId = 28
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
			WHEN c.ProductId = 19 THEN 206
			WHEN c.ProductID = 28 THEN 220
			ELSE 0
		END AS Sporttype
		, b.GameId AS bettype
		, 0 AS betid
		, CASE
			WHEN c.ProductID = 8 THEN fnc.ChoiceId
			ELSE ''
		END AS betteam
		, 0 AS hdp1
		, 0 AS hdp2
		, CASE
			WHEN c.ProductId = 19 THEN CONVERT(TINYINT, ISNULL(b.custom1, 0))
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
			WHEN c.ProductID = 8 THEN fnc.GameId
			WHEN c.ProductID = 12 THEN 255
			WHEN c.ProductID = 19 THEN b.Gameid3rd
			ELSE 0
		END AS MatchID
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
			WHEN c.ProductID IN (12) AND b.gameid IN ( 1701,1702 ) THEN b.Gameid3rd
			WHEN c.ProductID = 15 THEN b.Tranid3rd
			WHEN c.ProductID = 19 THEN b.custom2
			ELSE ''
		END AS betcheck
		, 0 AS comstatus
		, CASE
			WHEN c.ProductID IN (15, 19, 28) THEN b.transdesc
			ELSE ''
		END AS transdesc
		, 0 AS OddsSpread
	FROM dbo.translog AS b WITH (NOLOCK)
		INNER JOIN @tempCust AS c ON b.translogid = c.transid
--			AND b.custid	= c.custid
		OUTER APPLY [dbo].[f_ParseTransDesc](b.transdesc, b.gameid) AS fnc
	WHERE c.WhTicket = 0
		AND c.EventType = 0
		AND b.StatusID IN (0, 1)

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
		, b.tpositiontaking
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
		,b.transdesc
		, 0 AS OddsSpread
	FROM dbo.translog AS b WITH (NOLOCK)
		INNER JOIN @tempCust AS c ON b.translogid = c.transid
--			AND b.custid	= c.custid
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.eventid = m.matchid
	WHERE c.WhTicket = 0
		AND c.EventType = 1
		AND b.statusID IN (0,1)

	RETURN;
END


GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_BetTicket_SelTranslog] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_BetTicket_SelTranslog] TO [bodbDownlineNetView]
GO
