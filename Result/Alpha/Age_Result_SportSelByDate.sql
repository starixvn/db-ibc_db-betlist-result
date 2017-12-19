ALTER PROCEDURE [dbo].[Age_Result_SportSelByDate]
	@EventDate		DATETIME,
	@MoveBetsDay	DATETIME,
	@IsShowAll		BIT			= 0
AS

/*
	Created:
	Task:
	DB: DBAGE.bodb02
	Original:
	Revision:
		- 20110307@Lukas: Get more sporttype 152, 153
		- 20110908@Sophia: Add Condition Where : OR (eventstatus = 'running' AND (mr.ishtcal=1 OR mr.calculate=1))
		- 20111003@Sophia: Edit condition OR to show the row which have eventstatus IN ('running','closed')
		- 20130712@Kathy: Hide sporttype in the "Sport" dropdown list since these sports have not launched yet.
		- 20130805@Lukas: hide live casino game
		- 20131121@Kathy: Add Virtual Greyhounds (182), Virtual Motor Racing (184) [Redmine:#7234]
		- 20140404@Dom: Add Virtual Speedway (183), Virtual Cycling Racing (185)
		- 20150414@Sophia: Support BetRadar
		- 20150416@Sophia: Condition of showing Running match different between Sporting solution and BetRadar
		- 20150810@Sophia: Hardcode to exclude ResultDetail of bettype 216, 217 for a temporary time [#40991]
		- 20151014@Sophia: Show internal match [#45531]
		- 201600829@Kos: Include ResourceID '08' to support PH All In One phase 2b [#Redmine: 62882]
		- 20161021@Kos: Exclude Fast Market result [#Redmine: 56589]
		- 20170405@Kos: Support Basketball AIO [#Redmine: 73033]
		- 20171012@Kos: Support PH AIO Phase 3 [#Redmine: 82403]
		- 20171219@Kos: Enhance performance [#Redmine: 88410]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @ToDate DATETIME
 
	SELECT @ToDate = DATEADD(s, -1, DATEADD(d, 1, @EventDate))

	SELECT DISTINCT
		s.SportType,
		s.SportName
	FROM dbo.Sports AS s WITH (NOLOCK)
		INNER JOIN
			(	SELECT matchid, eventdate, eventstatus, sporttype, leagueid
				FROM dbo.match WITH (NOLOCK)
				UNION ALL
				SELECT matchid, eventdate, eventstatus, sporttype, leagueid
				FROM dbo.match14 WITH (NOLOCK)
			) AS m ON m.sporttype = s.sporttype
		LEFT JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
		INNER JOIN dbo.league AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
		LEFT JOIN
			(	SELECT DISTINCT MatchID
				FROM dbo.ResultDetail WITH (NOLOCK)
				WHERE SettlementStatusID > 0
				UNION ALL
				SELECT DISTINCT MatchID
				FROM dbo.ResultDetail14 WITH (NOLOCK)
				WHERE SettlementStatusID > 0
			) AS SS ON m.matchid = SS.MatchId AND m.sporttype IN (2, 5)
		LEFT JOIN
			(	SELECT DISTINCT MatchID
				FROM dbo.ResultDetail WITH (NOLOCK)
				WHERE SettlementStatusID > 0
					AND (ResourceID NOT IN ('00', '01', '08', '14F', '14L', '127F', '127L')
						OR (ResourceID = '08'
							AND (HomeValue LIKE '%a%' OR HomeValue LIKE '%h%')))
					AND ResourceID NOT LIKE '217%'
					AND ResourceID NOT LIKE '216%'
					AND ResourceID NOT LIKE '221%'
					AND ResourceID NOT LIKE '222%'
					AND ResourceID NOT LIKE '223%'
					AND ResourceID NOT LIKE '224%'
					AND ResourceID NOT LIKE '225%'
				UNION ALL
				SELECT DISTINCT MatchID
				FROM dbo.ResultDetail14 WITH (NOLOCK)
				WHERE SettlementStatusID > 0
					AND (ResourceID NOT IN ('00', '01', '08', '14F', '14L', '127F', '127L')
						OR (ResourceID = '08'
							AND (HomeValue LIKE '%a%' OR HomeValue LIKE '%h%')))
					AND ResourceID NOT LIKE '217%'
					AND ResourceID NOT LIKE '216%'
					AND ResourceID NOT LIKE '221%'
					AND ResourceID NOT LIKE '222%'
					AND ResourceID NOT LIKE '223%'
					AND ResourceID NOT LIKE '224%'
					AND ResourceID NOT LIKE '225%'
			) AS BR ON m.matchid = BR.MatchID AND m.sporttype = 1
	WHERE m.eventdate >= @EventDate
		AND m.eventdate <= @ToDate
		AND ( m.eventstatus NOT IN ('closed', 'running')
			OR ( mr.IsPending = 1 AND m.eventstatus IN ('running', 'closed') )
			OR ( mr.IsHTCal = 1 AND m.eventstatus = 'running')
			OR ( ISNULL(SS.MatchID, 0) <> 0 AND m.eventstatus = 'running')	-- condition for Sportting Solution, BAIO show running Match but settled least one type
			OR ( ISNULL(BR.MatchID, 0) <> 0 AND m.eventstatus = 'running')	-- condition for BetRadar show running Match but settled least one type
		)
		AND s.sporttype NOT IN (201, 162)
		AND l.isTest = CASE WHEN @IsShowAll = 1 THEN l.isTest ELSE @IsShowAll END

	UNION ALL

	SELECT
		s.SportType,
		s.SportName
	FROM (
		SELECT ROW_NUMBER() OVER (PARTITION BY l.sporttype ORDER BY l.leagueid) AS RowNumber, l.sporttype, l.leagueid, l.isTest
		FROM dbo.League AS l WITH (NOLOCK)
			INNER JOIN
			(	SELECT DISTINCT leagueid
				FROM dbo.outright WITH (NOLOCK)
				WHERE eventdate >= @EventDate AND eventdate <= @ToDate
					AND oddsstatus = 'completed'
				UNION ALL
				SELECT DISTINCT leagueid
				FROM dbo.outright14 WITH (NOLOCK)
				WHERE eventdate >= @EventDate AND eventdate <= @ToDate
					AND oddsstatus = 'completed'
			) o ON o.leagueid = l.leagueid
		WHERE l.sporttype BETWEEN 151 AND 153 ) AS t
		INNER JOIN dbo.Sports AS s WITH (NOLOCK) ON t.sporttype = s.sporttype
	WHERE t.RowNumber < 2
		AND t.isTest = CASE WHEN @IsShowAll = 1 THEN t.isTest ELSE @IsShowAll END

	UNION ALL

	SELECT
		s.SportType,
		s.SportName
	FROM (
			SELECT ROW_NUMBER() OVER (PARTITION BY l.sporttype ORDER BY l.leagueid) AS RowNumber, l.sporttype, l.leagueid, l.isTest
			FROM (
					SELECT DISTINCT EventID
					FROM dbo.VSOutright WITH (NOLOCK)
					WHERE EventDate >= @EventDate AND EventDate <= @ToDate
					UNION ALL
					SELECT DISTINCT EventID
					FROM dbo.VSOutright14 AS o WITH (NOLOCK)
					WHERE EventDate >= @EventDate AND EventDate <= @ToDate
				) o
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON o.EventID = r.EventID
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON r.LeagueID = l.leagueid
			WHERE l.sporttype IN (181, 182, 183, 184, 185)
				AND r.eventstatus = 'completed'
		) AS t
		INNER JOIN dbo.Sports AS s WITH (NOLOCK) ON t.sporttype = s.sporttype
	WHERE t.RowNumber < 2
		AND t.isTest = CASE WHEN @IsShowAll = 1 THEN t.isTest ELSE @IsShowAll END 
	ORDER BY s.SportType,
		s.SportName
END



 
GO
GRANT EXECUTE ON [dbo].[Age_Result_SportSelByDate] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_Result_SportSelByDate] TO [bodbDownlineNetView] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Result_SportSelByDate] TO [vnteam] AS [dbo]
GO
