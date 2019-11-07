/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

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
		- 20111004@Henry: Edit condition OR to show the row which have mr.IsPending=1  AND (m.eventstatus = 'running' OR m.eventstatus = 'closed')
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
		- 20170418@Kos: Support Basketball AIO [#Redmine: 73033]
		- 20171103@Kos: Support PH AIO 3 [#Redmine: 83970]
		- 20180103@Kos: Don't support Live Casino anymore [#Redmine: 85965]
		- 20180320@Kos: Exclude Fast Market 2 result [#Redmine: 90879]
		- 20180412@Kos: Support Betradar Virtual Basketball [Redmine: #90616]
		- 20180806@Kos: Don't support Racing anymore [#Redmine: 99378]
		- 20181018@Kos: Support E-Sports 2 [#Redmine: 100721]
		- 20190814@Kos: Support PH AIO phase 4b [Redmine: #118300]
					- Change for "Next Goal" [Redmine: #115235]
		- 20191107@Kos: Support Badminton AIO phase 2 [Redmine: #120336]

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
		-- Sportsbook, Number Game, Virtual Sports
		INSERT INTO @Sport
		SELECT DISTINCT m.sporttype
		FROM dbo.match AS m WITH (NOLOCK)
			LEFT JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN (
					SELECT DISTINCT MatchID
					FROM dbo.ResultDetail WITH (NOLOCK)
					WHERE SettlementStatusID > 0
				) AS ss ON m.matchid = ss.MatchID AND m.sporttype IN (2, 5)
			LEFT JOIN (
					SELECT DISTINCT MatchID
					FROM dbo.ResultDetail WITH (NOLOCK)
					WHERE SettlementStatusID > 0
						AND (ResourceID NOT IN ('08', '09')
							OR HomeValue LIKE '%a%'
							OR HomeValue LIKE '%h%')
						AND ResourceID NOT IN ('00', '01', '04', '05', '14F', '14L', '127F', '127L', '135', '168', '173', '174', '175', '176', 
							'192', '193', '206', '207', '208', '209', '210', '211', '212', '213', '214', '215')
						AND ResourceID NOT LIKE '160%'
						AND ResourceID NOT LIKE '164%'
						AND ResourceID NOT LIKE '169%'
						AND ResourceID NOT LIKE '180%'
						AND ResourceID NOT LIKE '216%'
						AND ResourceID NOT LIKE '217%'
						AND ResourceID NOT LIKE '221%'
						AND ResourceID NOT LIKE '222%'
						AND ResourceID NOT LIKE '223%'
						AND ResourceID NOT LIKE '224%'
						AND ResourceID NOT LIKE '225%'
						AND ResourceID NOT LIKE '226%'
						AND ResourceID NOT LIKE '227%'
				) AS br ON m.matchid = br.MatchID AND m.sporttype = 1
			LEFT JOIN (
					SELECT DISTINCT MatchID
					FROM dbo.ResultDetail3rd WITH (NOLOCK)
					WHERE SettlementStatusID > 0
				) AS b ON m.matchid = b.MatchID AND m.sporttype = 193
			LEFT JOIN (
					SELECT DISTINCT MatchID
					FROM dbo.ResultDetailES WITH (NOLOCK)
					WHERE SettlementStatusID > 0
				) AS e ON m.matchid = e.MatchID AND m.sporttype = 43
			LEFT JOIN (
					SELECT DISTINCT MatchID
					FROM dbo.ResultDetailOS WITH (NOLOCK)
					WHERE SettlementStatusID > 0
				) AS o ON o.MatchID = m.matchid AND m.sporttype = 9
		WHERE m.eventdate = @EventDate
			AND m.sporttype <> 162
			AND (m.eventstatus NOT IN ('internal', 'closed', 'running')
				OR (mr.IsPending = 1 AND m.eventstatus IN ('running', 'closed'))
				OR (m.eventstatus = 'running'
					AND (mr.IsHTCal = 1
						OR ISNULL(ss.MatchID, 0) <> 0		-- Sportting Solution, BAIO show running Match but settled least one type
						OR ISNULL(br.MatchID, 0) <> 0		-- BetRadar show running Match but settled least one type
						OR ISNULL(b.MatchID, 0) <> 0		-- BetRadar Virtual Basketball show running Match but settled least one type
						OR ISNULL(e.MatchID, 0) <> 0		-- E-Sports show running Match but settled least one type
						OR ISNULL(o.MatchID, 0) <> 0)))		-- Badminton show running Match but settled least one type

		-- Virtual Sports
		IF EXISTS (SELECT TOP(1) 1 FROM #LicenseeProduct WHERE ProductID = 5)
		BEGIN
			INSERT INTO @Sport
			SELECT DISTINCT l.sporttype
			FROM (
					SELECT DISTINCT EventID
					FROM dbo.VSOutright WITH (NOLOCK)
					WHERE EventDate = @EventDate
				) AS o
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON o.EventID = r.EventID
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON r.LeagueID = l.leagueid
			WHERE l.sporttype IN (181, 183, 185)
				AND r.EventStatus = 'completed'
		END
	END
	ELSE
	BEGIN
		-- Sportsbook, Number Game, Virtual Sports
		INSERT INTO @Sport
		SELECT DISTINCT m.sporttype
		FROM dbo.match14 AS m WITH (NOLOCK)
			LEFT JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN (
					SELECT DISTINCT MatchID
					FROM dbo.ResultDetail14 WITH (NOLOCK)
					WHERE SettlementStatusID > 0
				) AS ss ON m.matchid = ss.MatchID AND m.sporttype IN (2, 5)
			LEFT JOIN (
					SELECT DISTINCT MatchID
					FROM dbo.ResultDetail14 WITH (NOLOCK)
					WHERE SettlementStatusID > 0
						AND (ResourceID NOT IN ('08', '09')
							OR HomeValue LIKE '%a%'
							OR HomeValue LIKE '%h%')
						AND ResourceID NOT IN ('00', '01', '04', '05', '14F', '14L', '127F', '127L', '135', '168', '173', '174', '175', '176', 
							'192', '193', '206', '207', '208', '209', '210', '211', '212', '213', '214', '215')
						AND ResourceID NOT LIKE '160%'
						AND ResourceID NOT LIKE '164%'
						AND ResourceID NOT LIKE '169%'
						AND ResourceID NOT LIKE '180%'
						AND ResourceID NOT LIKE '216%'
						AND ResourceID NOT LIKE '217%'
						AND ResourceID NOT LIKE '221%'
						AND ResourceID NOT LIKE '222%'
						AND ResourceID NOT LIKE '223%'
						AND ResourceID NOT LIKE '224%'
						AND ResourceID NOT LIKE '225%'
						AND ResourceID NOT LIKE '226%'
						AND ResourceID NOT LIKE '227%'
				) AS br ON m.matchid = br.MatchID AND m.sporttype = 1
			LEFT JOIN (
					SELECT DISTINCT MatchID
					FROM dbo.ResultDetail3rd14 WITH (NOLOCK)
					WHERE SettlementStatusID > 0
				) AS b ON m.matchid = b.MatchID AND m.sporttype = 193
			LEFT JOIN (
					SELECT DISTINCT MatchID
					FROM dbo.ResultDetailES14 WITH (NOLOCK)
					WHERE SettlementStatusID > 0
				) AS e ON m.matchid = e.MatchID AND m.sporttype = 43
			LEFT JOIN (
					SELECT DISTINCT MatchID
					FROM dbo.ResultDetailOS14 WITH (NOLOCK)
					WHERE SettlementStatusID > 0
				) AS o ON o.MatchID = m.matchid AND m.sporttype = 9
		WHERE m.eventdate = @EventDate
			AND m.sporttype <> 162
			AND (m.eventstatus NOT IN ('internal', 'closed', 'running')
				OR (mr.IsPending = 1 AND m.eventstatus IN ('running', 'closed'))
				OR (m.eventstatus = 'running'
					AND (mr.IsHTCal = 1
						OR ISNULL(ss.MatchID, 0) <> 0		-- Sportting Solution, BAIO show running Match but settled least one type
						OR ISNULL(br.MatchID, 0) <> 0		-- BetRadar show running Match but settled least one type
						OR ISNULL(b.MatchID, 0) <> 0		-- BetRadar Virtual Basketball show running Match but settled least one type
						OR ISNULL(e.MatchID, 0) <> 0		-- E-Sports show running Match but settled least one type
						OR ISNULL(o.MatchID, 0) <> 0)))		-- Badminton show running Match but settled least one type

		-- Virtual Sports
		IF EXISTS (SELECT TOP(1) 1 FROM #LicenseeProduct WHERE ProductID = 5)
		BEGIN
			INSERT INTO @Sport
			SELECT DISTINCT l.sporttype
			FROM (
					SELECT DISTINCT EventID
					FROM dbo.VSOutright14 WITH (NOLOCK)
					WHERE EventDate = @EventDate
				) AS o
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON o.EventID = r.EventID
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON r.LeagueID = l.leagueid
			WHERE l.sporttype IN (181, 183, 185)
				AND r.EventStatus = 'completed'
		END
	END

	SELECT DISTINCT SportType,
		SportName
	FROM dbo.Sports WITH (NOLOCK)
	WHERE SportType IN (SELECT SportType FROM @Sport)
		AND (SportType <> 161 OR EXISTS (SELECT TOP(1) 1 FROM #LicenseeProduct WHERE ProductID = 2))
	ORDER BY SportType ASC,
		SportName ASC

	DROP TABLE #LicenseeProduct
END
GO



GRANT EXECUTE ON [dbo].Lrf_Result_SportSelByDate TO [bodbLicenseeNet]
GO
