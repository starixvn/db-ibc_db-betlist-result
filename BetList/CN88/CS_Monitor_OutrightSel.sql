/*<info serverAlias="DB042-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[CS_Monitor_OutrightSel]
	@IsShowAll	BIT = 0
AS

/*
	Created: Kos@20190405
	Task: CN88 Wager Monitoring - Get outright running
	DB: DB042.bodb02
	Revision:
		- 20190405@Kos: Create new [Redmine: 111245]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @IsTest BIT

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	;WITH CTE_Sports AS (
		SELECT DISTINCT SportTypeGroup, SportType
		FROM dbo.CS_SportBettypeMatrix WITH (NOLOCK)
		WHERE IsTest <= @IsTest
			AND ProductID = 1
			AND Bettype NOT IN (9, 29)
	)
	SELECT
		l.sporttype,
		m.oddsstatus AS Status,
		m.orid AS MatchId,
		m.leagueid,
		m.matchcode,
		m.teamid AS HomeId,
		ISNULL(m.groupmatch, '') AS Race,
		s.SportTypeGroup
	FROM dbo.outright AS m WITH (NOLOCK)
		INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
		INNER JOIN CTE_Sports AS s ON s.SportType = l.sporttype
	WHERE m.oddsstatus NOT IN ('completed', 'internal', 'closed')
		AND m.eventdate >= CONVERT(VARCHAR(10), DATEADD(dd, -1, CURRENT_TIMESTAMP), 120)
		AND l.isTest <= @IsShowAll
END



GO
GRANT EXECUTE ON [dbo].[CS_Monitor_OutrightSel] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[CS_Monitor_OutrightSel] TO [bodbDownlineNetView] AS [dbo]
GO
