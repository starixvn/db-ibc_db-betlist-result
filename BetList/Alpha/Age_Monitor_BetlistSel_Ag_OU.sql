/*<info serverAlias="DBBOF-bodb02" executers="bodbDownlineNet, wsv_alp,bodbDownlineNetView, wsv_alpv" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_Monitor_BetlistSel_Ag_OU]
	@CustId			INT,
	@TransId		BIGINT	= 0,
	@LimitRowCount	INT		= 20
AS

/*
	Created: Johnson@20110628
	Task: Last Bets (Over/Under bettypes)
	DB: DBBOF.bodb02
	Revision:
		- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
		- 20150826@Kos: Add column OddsSpread to support Myanmar Odds
		- 20160623@Percy: Remove WITH recompile [RedmineID: #58288]
		- 20180802@Patrick: indexes revolution [RedmineID: #98757]
		- 20181218@Kos: Support E-Sports phase 2b [#Redmine: 106456]
		- 20190722@Kos: Support new status Pending [#Redmine: 113142]
		- 20191028@Kos: Show Running status for Marked tickets [Redmine: 122391]
		- 20210208@Kos: Support Cricket AIO [Redmine: 148963]
		- 20231019@Razor: Return Device Type info [Redmine: #192667]

	Parameter's Explanation:
		- @CustId : agent's ID
		- @TransId: latest transid
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
		ISNULL(b.ExtraInfo, '') AS ExtraInfo,
		b.DeviceType
	FROM dbo.bettrans AS b WITH (NOLOCK)
	WHERE b.recommend = @CustId
		AND b.statusID IN (0, 1)
		AND b.transid > @TransId
		AND b.bettype IN (3, 8, 302, 304, 9604)
	ORDER BY b.transid DESC
END
GO
