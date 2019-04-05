/*<info serverAlias="DB042-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[CS_Monitor_MatchSel]
	@IsShowAll	BIT = 0
AS

/*
	Created: Kos@20190405
	Task: CN88 Wager Monitoring - Get match running
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
		m.sporttype,
		m.eventstatus AS Status,
		m.matchid,
		m.leagueid,
		m.matchcode,
		m.homeid,
		m.awayid,
		m.showtime,
		m.IsNeutral,
		m.betstatus,
		ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
		s.SportTypeGroup
	FROM dbo.match AS m WITH (NOLOCK)
		INNER JOIN CTE_Sports AS s ON s.SportType = m.sporttype
	WHERE m.eventstatus NOT IN ('completed', 'internal', 'closed')
		AND EXISTS (SELECT 1 FROM dbo.League WITH (NOLOCK) WHERE leagueid = m.leagueid AND isTest <= @IsShowAll)
	ORDER BY m.leagueid ASC,
		m.eventdate ASC
END




GO
GRANT EXECUTE ON [dbo].[CS_Monitor_MatchSel] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[CS_Monitor_MatchSel] TO [bodbDownlineNetView]
GO
