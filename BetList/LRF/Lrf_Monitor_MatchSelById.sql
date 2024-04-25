/*<info serverAlias="DBBOF-bodb02" executers="wsv_lap" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Monitor_MatchSelById]
	@MatchId INT
AS

/*
	Created: 20220606@Kos
	Task: LAP - Last Bets Monitoring - Get running match info by ID
	DB: DBBOF.bodb02

	Revision:
		- 20220606@Kos: Created [RedmineID: #173737]
		- 20240425@Kos: Return LeagueGroupId to support Jollysports [Redmine: #203258]
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		m.sporttype,
		m.eventstatus AS Status,
		m.matchid,
		l.LeagueGroupId,
		m.leagueid,
		m.matchcode,
		m.homeid,
		m.awayid,
		'' AS Race,
		m.GlobalShowTime AS EventDate
	FROM dbo.match AS m WITH (NOLOCK)
		LEFT JOIN dbo.league AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
	WHERE matchid = @MatchId
END
GO
