/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Monitor_BetlistSel_Ag_OU]
	@custid			INT, 
	@transid		BIGINT	= 0,
	@LimitRowCount	INT		= 20 
AS

/*	
	Created	: Johnson
	Task: Monitor lastest bets list( all bettypes and bettype over/under)
	Date: 28/06/2011
	DB: DBAGE.BODB02
	Revision:
		- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
		- 20150826@Kos: Add column OddsSpread to support Myanmar Odds
		- 20160623@Percy: Remove WITH recompile [RedmineID: #58288]
		- 20180802@Patrick: indexes revolution [RedmineID: #98757]
	
	Parameter's Explanation:
		- @custid : agent's ID
		- @transid: lastest transid 
		- @LimitRowCount: max record return.
*/ 

BEGIN
	SET NOCOUNT ON

	SELECT TOP(@LimitRowCount)
		0 AS sporttype,
		b.matchid,
		0 AS leagueid,
		b.Username,
		b.bettype,
		b.transid,
		b.refno,
		b.transdate,
		'' AS matchcode,
		0 AS homeid,
		0 AS awayid,
		'' AS race,
		b.betid,
		b.livehomescore,
		b.liveawayscore,
		b.liveindicator,
		b.hdp1,
		b.hdp2,
		b.odds,
		b.stake,
		CASE 
			WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
			ELSE b.status 
		END AS status,
		b.betteam,
		b.IP,
		CONVERT(BIT, 0) AS isNeutral,
		b.oddstype,
		ISNULL(b.oddsspread, 0) AS OddsSpread
	FROM dbo.bettrans AS b WITH(NOLOCK)
	WHERE b.recommend = @custid 
		AND b.statusID IN (0,1)
		AND b.transid > @transid
		AND b.bettype IN (3, 8, 302, 304)
	ORDER BY b.transid DESC
END

GO
GRANT EXECUTE ON [dbo].[Age_Monitor_BetlistSel_Ag_OU] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Monitor_BetlistSel_Ag_OU] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Monitor_BetlistSel_Ag_OU] TO [vnteam] 
GO
