/*<info serverAlias="DB042-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_Monitor_OutrightSel]
AS

/*
	Created: Henry@20111011
	Task: Monitor lastest bets list - get outright running
	DB: DB042.bodb02
	Original: Age_Monitor_OutrightSel
	Revision:
		- 20181008@Kos: Migrate to DB042 [RedmineID: #99464]

	Parameter's Explanation:
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		l.sporttype,
		m.oddsstatus AS Status,
		m.orid AS MatchId,
		m.leagueid,
		m.matchcode,
		m.teamid AS HomeId,
		0 AS AwayId,
		ISNULL(m.groupmatch, '') AS Race
	FROM dbo.outright AS m WITH (NOLOCK)
		INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
	WHERE m.oddsstatus <> 'completed' 
		AND m.eventdate >= CONVERT(VARCHAR(10), DATEADD(dd, -1, CURRENT_TIMESTAMP), 120)
END



GO
GRANT EXECUTE ON [dbo].[Lrf_Monitor_OutrightSel] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Monitor_OutrightSel] TO [vnteam]
GO
