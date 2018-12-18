/*<info serverAlias="DB042-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_Monitor_BetlistSel_Ag_OU]
	@CustId			INT,
	@TransId		BIGINT	= 0,
	@LimitRowCount	INT		= 20
AS

/*
	Created: Johnson@20110628
	Task: Last Bets (over/under bettypes)
	DB: DB042.bodb02
	Revision:
		- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
		- 20150826@Kos: Add column OddsSpread to support Myanmar Odds
		- 20160623@Percy: Remove WITH recompile [RedmineID: #58288]
		- 20180802@Patrick: indexes revolution [RedmineID: #98757]
		- 20181218@Kos: Support E-Sports phase 2b [#Redmine: 106456]
	
	Parameter's Explanation:
		- @CustId : agent's ID
		- @TransId: lastest transid
		- @LimitRowCount: max record return
*/

BEGIN
	SET NOCOUNT ON

	SELECT TOP(@LimitRowCount)
		b.matchid,
		b.Username,
		b.bettype,
		b.transid,
		b.refno,
		b.transdate,
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
		b.ip,
		b.oddstype,
		ISNULL(b.oddsspread, 0) AS OddsSpread,
		ISNULL(b.ExtraInfo, '') AS ExtraInfo
	FROM dbo.bettrans AS b WITH (NOLOCK)
	WHERE b.recommend = @CustId
		AND b.statusID IN (0, 1)
		AND b.transid > @TransId
		AND b.bettype IN (3, 8, 302, 304)
	ORDER BY b.transid DESC
END


GO
GRANT EXECUTE ON [dbo].[Age_Monitor_BetlistSel_Ag_OU] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Monitor_BetlistSel_Ag_OU] TO [bodbDownlineNetView]
GO
