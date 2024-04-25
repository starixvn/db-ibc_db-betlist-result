/*<info serverAlias="DBBOF-bodb02" executers="wsv_lap" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Monitor_MatchSel]
AS

/*
	Created: Henry@20111011
	Task: Monitor lastest bets list - get match running
	DB: DBBOF.bodb02

	Revision:
		- 20181008@Kos: Migrate to DB042 [RedmineID: #99464]
		- 20190509@Kos: Show match KO time for single ticket [Redmine: #112731]
					- Return additional column EventDate DATETIME
		- 20240425@Kos: Return LeagueGroupId to support Jollysports [Redmine: #203258]
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		m.sporttype,
		m.eventstatus AS Status,
		m.matchid,
		m.leagueid,
		l.LeagueGroupId,
		m.matchcode,
		m.homeid,
		m.awayid,
		'' AS Race,
		m.GlobalShowTime AS EventDate
	FROM dbo.match AS m WITH (NOLOCK)
		LEFT JOIN dbo.league AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
	WHERE m.eventstatus <> 'completed'
END
GO
