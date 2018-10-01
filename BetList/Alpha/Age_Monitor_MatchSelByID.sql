/*<info serverAlias="DB042-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_Monitor_MatchSelByID]
	@MatchId INT
AS

/*
	Created: 20180622@Sophia
	Task: Last bets Monitoring - get match info by MatchId [Redmind: #97219]
	DB: DB042.bodb02

	Revision:
		- 20181002@Kos: Support 2 new status Result Pending and Under Settlement [#Redmine: 101949]
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
	WHERE m.matchid = @MatchId
END



GO
GRANT EXECUTE ON [dbo].[Age_Monitor_MatchSelByID] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Monitor_MatchSelByID] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Monitor_MatchSelByID] TO [vnteam]
GO