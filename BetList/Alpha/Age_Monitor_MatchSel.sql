/*<info serverAlias="DB042-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_Monitor_MatchSel]
	@MatchId INT = 0
AS

/*
	Created: Johnson@20110628
	Task: Monitor lastest bets list- get match running
	DB: DB042.bodb02

	Revision:
		- 20120301@Jamie: Retrieve showtime for LiveCasino
		- 20170817@Kos: Return IsNeutral [#Redmine: 66992]
		- 20180622@Sophia: Add Betstatus [#Redmine: 97219]
		- 20181002@Kos: Support 2 new status Result Pending and Under Settlement [#Redmine: 101949]

	Parameter's Explanation:
		- @MatchId: Lastest running match ID
*/

BEGIN
	SET NOCOUNT ON
	
	SELECT
		m.sporttype,
		m.eventstatus AS Status,
		m.matchid,
		m.leagueid,
		m.matchcode,
		m.homeid,
		m.awayid,
		'' AS Race,
		m.showtime,
		m.IsNeutral,
		m.betstatus,
		ISNULL(m.SettlementStatus, 0) AS SettlementStatus
	FROM dbo.match AS m WITH (NOLOCK)
	WHERE m.eventstatus <> 'completed'
		AND m.matchid >= @MatchId
END




GO
GRANT EXECUTE ON [dbo].[Age_Monitor_MatchSel] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Monitor_MatchSel] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Monitor_MatchSel] TO [vnteam]
GO