USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_Result_SportSelByDate]    Script Date: 12/02/2014 10:07:48 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_Result_SportSelByDate]
	@EventDate		DATETIME,
	@MoveBetsDay	DATETIME,
	@LicenseeId		INT
AS

/*
	Created: 20101201@Jacob
	Task:
	DB: DBEXT.bodb02
	Original: Age_Result_SportSelByDate
	Revisions:
		- 20101201@Jacob: Copy source code from Age_Result_SportSelByDate
		- 20110803@Henry: get more sporttype 152, 153
		- 20110908@Sophia: Add Condition Where : OR (eventstatus = 'running' AND (mr.ishtcal=1 OR mr.calculate=1)) 
		- 20111004@Henry:  Edit condition OR to show the row which have mr.IsPending=1  AND (m.eventstatus = 'running' OR m.eventstatus = 'closed') 
		- 20111025@Henry: Edit condition OR to show the rows which have eventstatus IN ('running','closed') 
		- 20120321@Henry: Fix bug to not show Casino
		- 20120815@Jim: add live casino
		- 20120906@Jim: add virtual sport
		- 20130722@Jim: add Virtual Horse Racing (Sporttype=181)
		- 20130916@Jim: add Virtual Tennis (sporttype=186)
		- 20140117@Florent: add new sport 154
		- 20140506@Hannah: support 183 - Virtual Speedway, 185 - Virtual Cycling
		- 20150414@Sophia: Support BetRadar
		- 20150416@Sophia: Condition of showing Running match different between Sporting solution and BetRadar
		- 20150810@Sophia: Hardcode to exclude ResultDetail of bettype 216, 217 for a temporary time [#40991]
		- 20160829@Kos: Include ResourceID '08' to support PH All In One phase 2b [#Redmine: 62882]
		- 20161026@Kos: Separate bettrans and bettrans14 range, exclude Fast Market result [#Redmine: 56589]

	Sample test case:
		exec Lrf_Result_SportSelByDate @EventDate='2013-10-06 00:00:00',@licenseeid=1
*/

BEGIN
	SET NOCOUNT ON

	SELECT DISTINCT ProductID
	INTO #LicenseeProduct
	FROM bodb_licensee.dbo.LicenseeProduct3rd WITH (NOLOCK)
	WHERE licenseeID = @LicenseeId

	DECLARE @Sport AS TABLE (SportType INT)

	IF @EventDate > @MoveBetsDay
	BEGIN
		-- Sportsbook, Number Game, Live Casino, Virtual Sports
		INSERT INTO @Sport
		SELECT DISTINCT m.sporttype
		FROM dbo.match AS m WITH (NOLOCK)
			LEFT JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN (
					SELECT DISTINCT MatchID
					FROM dbo.ResultDetail WITH (NOLOCK)
					WHERE SettlementStatusID > 0
				) AS ss ON m.matchid = ss.MatchID AND m.sporttype = 5
			LEFT JOIN (
					SELECT DISTINCT MatchID
					FROM dbo.ResultDetail WITH (NOLOCK)
					WHERE SettlementStatusID > 0
						AND ResourceID NOT IN ('00', '01', '08')
						AND ResourceID NOT LIKE '217%'
						AND ResourceID NOT LIKE '216%'
						AND ResourceID NOT LIKE '221%'
						AND ResourceID NOT LIKE '222%'
						AND ResourceID NOT LIKE '223%'
						AND ResourceID NOT LIKE '224%'
						AND ResourceID NOT LIKE '225%'
				) AS br ON m.matchid = br.MatchID AND m.sporttype = 1
		WHERE eventdate = @EventDate
			AND (m.eventstatus NOT IN ('internal', 'closed', 'running')
				OR (mr.IsPending = 1 AND m.eventstatus IN ('running', 'closed'))
				OR (mr.IsHTCal = 1 AND m.eventstatus ='running')
				OR (ISNULL(ss.MatchID, 0) <> 0 AND m.eventstatus = 'running')	-- condition for Sportting Solution show running Match but settled least one type
				OR (ISNULL(br.MatchID, 0) <> 0 AND m.eventstatus = 'running'))  -- condition for BetRadar show running Match but settled least one type

		-- Horse Racing
		IF EXISTS (SELECT TOP 1 1 FROM #LicenseeProduct WHERE ProductID = 1)
		BEGIN
			INSERT INTO @Sport
			SELECT DISTINCT l.sporttype
			FROM dbo.league AS l WITH (NOLOCK)
				INNER JOIN (
						SELECT DISTINCT leagueid
						FROM dbo.outright WITH (NOLOCK)
						WHERE eventdate = @EventDate AND oddsstatus = 'completed'
					) AS o ON o.leagueid = l.leagueid
			WHERE l.sporttype = 151
		END

		-- Virtual Sports
		IF EXISTS (SELECT TOP 1 1 FROM #LicenseeProduct WHERE ProductID = 5)
		BEGIN
			INSERT INTO @Sport
			SELECT DISTINCT l.sporttype
			FROM dbo.league AS l WITH (NOLOCK)
				INNER JOIN (
					SELECT DISTINCT vsr.LeagueID
					FROM dbo.VSOutright AS vso WITH (NOLOCK)
						INNER JOIN dbo.VSRaceInfo AS vsr WITH (NOLOCK) ON vso.EventID = vsr.EventID
					WHERE vso.eventdate = @EventDate AND vsr.eventstatus = 'completed'
					) AS o ON o.leagueid = l.leagueid
			WHERE l.sporttype IN (181, 183, 185)
		END
	END
	ELSE
	BEGIN
		-- Sportsbook, Number Game, Live Casino, Virtual Sports
		INSERT INTO @Sport
		SELECT DISTINCT m.sporttype
		FROM dbo.match14 AS m WITH (NOLOCK)
			LEFT JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN (
					SELECT DISTINCT MatchID
					FROM dbo.ResultDetail14 WITH (NOLOCK)
					WHERE SettlementStatusID > 0
				) AS ss ON m.matchid = ss.MatchID AND m.sporttype = 5
			LEFT JOIN (
					SELECT DISTINCT MatchID
					FROM dbo.ResultDetail14 WITH (NOLOCK)
					WHERE SettlementStatusID > 0
						AND ResourceID NOT IN ('00', '01', '08')
						AND ResourceID NOT LIKE '217%'
						AND ResourceID NOT LIKE '216%'
						AND ResourceID NOT LIKE '221%'
						AND ResourceID NOT LIKE '222%'
						AND ResourceID NOT LIKE '223%'
						AND ResourceID NOT LIKE '224%'
						AND ResourceID NOT LIKE '225%'
				) AS br ON m.matchid = br.MatchID AND m.sporttype = 1
		WHERE eventdate = @EventDate
			AND (m.eventstatus NOT IN ('internal', 'closed', 'running')
				OR (mr.IsPending = 1 AND m.eventstatus IN ('running', 'closed'))
				OR (mr.IsHTCal = 1 AND m.eventstatus ='running')
				OR (ISNULL(ss.MatchID, 0) <> 0 AND m.eventstatus = 'running')	-- condition for Sportting Solution show running Match but settled least one type
				OR (ISNULL(br.MatchID, 0) <> 0 AND m.eventstatus = 'running'))	-- condition for BetRadar show running Match but settled least one type

		-- Horse Racing
		IF EXISTS (SELECT TOP 1 1 FROM #LicenseeProduct WHERE ProductID = 1)
		BEGIN
			INSERT INTO @Sport
			SELECT DISTINCT l.sporttype
			FROM dbo.league AS l WITH (NOLOCK)
				INNER JOIN (
						SELECT DISTINCT leagueid
						FROM dbo.outright14 WITH (NOLOCK)
						WHERE eventdate = @EventDate AND oddsstatus = 'completed'
					) AS o ON o.leagueid = l.leagueid
			WHERE l.sporttype = 151
		END

		-- Virtual Sports
		IF EXISTS (SELECT TOP 1 1 FROM #LicenseeProduct WHERE ProductID = 5)
		BEGIN
			INSERT INTO @Sport
			SELECT DISTINCT l.sporttype
			FROM dbo.league AS l WITH (NOLOCK)
				INNER JOIN (
					SELECT DISTINCT vsr.LeagueID
					FROM dbo.VSOutright14 AS vso WITH (NOLOCK)
						INNER JOIN dbo.VSRaceInfo AS vsr WITH (NOLOCK) ON vso.EventID = vsr.EventID
					WHERE vso.eventdate = @EventDate AND vsr.eventstatus = 'completed'
					) AS o ON o.leagueid = l.leagueid
			WHERE l.sporttype IN (181, 183, 185)
		END
	END

	SELECT DISTINCT SportType,
		SportName
	FROM dbo.Sports WITH (NOLOCK)
	WHERE SportType IN (SELECT SportType FROM @Sport)
		AND (SportType <> 161 OR EXISTS (SELECT TOP 1 1 FROM #LicenseeProduct WHERE ProductID = 2))
		AND (SportType <> 162 OR EXISTS (SELECT TOP 1 1 FROM #LicenseeProduct WHERE ProductID = 4))
	ORDER BY SportType,
		SportName

	DROP TABLE #LicenseeProduct
END



GO
GRANT EXECUTE ON [dbo].Lrf_Result_SportSelByDate TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].Lrf_Result_SportSelByDate TO [vnteam]
GO