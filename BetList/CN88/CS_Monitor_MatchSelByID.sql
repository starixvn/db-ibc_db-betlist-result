/*<info serverAlias="DB042-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[CS_Monitor_MatchSelByID]
	@MatchId INT
AS

/*
	Created: Kos@20190405
	Task: CN88 Wager Monitoring - Get match info by Match ID
	DB: DB042.bodb02

	Revision:
		- 20190405@Kos: Create new [Redmine: 111245]
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		sporttype,
		eventstatus AS Status,
		matchid,
		leagueid,
		matchcode,
		homeid,
		awayid,
		showtime,
		IsNeutral,
		betstatus,
		ISNULL(SettlementStatus, 0) AS SettlementStatus
	FROM dbo.match WITH (NOLOCK)
	WHERE matchid = @MatchId
END



GO
GRANT EXECUTE ON [dbo].[CS_Monitor_MatchSelByID] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[CS_Monitor_MatchSelByID] TO [bodbDownlineNetView]
GO
