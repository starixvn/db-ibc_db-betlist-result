/*<info serverAlias="DBBOF-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_Monitor_MatchSel]
	@MatchId INT = 0
AS

/*
	Created: Johnson@20110628
	Task: Monitor lastest bets list- get match running
	DB: DBBOF.bodb02

	Revision:
		- 20120301@Jamie: Retrieve showtime for LiveCasino
		- 20170817@Kos: Return IsNeutral [#Redmine: 66992]
		- 20180622@Sophia: Add Betstatus [#Redmine: 97219]
		- 20181002@Kos: Support 2 new status Result Pending and Under Settlement [#Redmine: 101949]
		- 20190506@Kos: Show match KO time for single ticket [Redmine: #112092]
		- 20231115@Kos: Get Sportsbook matches only [Redmine: #196745]
		- 20231129@Razor: Support Project 777 - return LeagueGroupId [Redmine: #194591]

	Parameter's Explanation:
		- @MatchId: Latest running match ID
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
		ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
		m.GlobalShowTime AS EventDate,
		l.LeagueGroupId
	FROM dbo.match AS m WITH (NOLOCK)
	LEFT JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
	WHERE m.eventstatus <> 'completed'
		ANd m.sporttype <= 99
		AND m.matchid >= @MatchId
END
GO
