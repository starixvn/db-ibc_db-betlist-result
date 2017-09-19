ALTER PROCEDURE Lrf_LeagueMatchSelRunning
	@SportType	SMALLINT = 1
AS

/*
	Created: 20130418@Scott
	Task: Get league, match running for Last Bets Monitoring
	DB: DBEXT.bodb02
	Revisions:
		- 20170919@Kos: Change Sporttype data type to SMALLINT [Redmine: #73545]
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		m.sporttype,
		m.leagueid,
		m.matchid,
		m.homeid,
		m.awayid
	FROM dbo.league AS l WITH (NOLOCK)
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON l.leagueid = m.leagueid
	WHERE m.sporttype =  @SportType
		AND m.eventstatus ='running'
		AND m.matchcode NOT LIKE '%hedge%'

	UNION ALL

	SELECT
		l.sporttype,
		o.leagueid,
		o.orid,
		o.teamid,
		0
	FROM dbo.outright AS o WITH (NOLOCK)
		INNER JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
	WHERE l.sporttype = @SportType AND o.oddsstatus = 'running'
END


GO
GRANT EXECUTE ON [dbo].[Lrf_LeagueMatchSelRunning] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_LeagueMatchSelRunning] TO [vnteam] AS [dbo]
GO
