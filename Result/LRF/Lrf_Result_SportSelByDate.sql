/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Result_SportSelByDate]
	@EventDate		DATETIME,
	@MoveBetsDay	DATETIME,
	@LicenseeId		INT,
	@IsShowAll		BIT			= 0		-- 1: Show all; 0: NOT show test league
AS

/*
	Created: 20101201@Jacob
	Task: LRF Result Report - Load Sport dropdownlist
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
		- 20191206@Kos: Show Instant Calculation Result for Corner Bettypes [Redmine: #124682]
		- 20200515@Kos: Support PH AIO phase 5.1 [Redmine: #132770]
		- 20200623@Kos: Integrate archive process for table VSRaceInfo [Redmine: #136285]
		- 20200929@Kos: Support Virtual Greyhounds and Virtual Motosports [Redmine: #136285]
		- 20201006@Razor: Support Time Machine Over/Under [Redmine: #141998]
		- 20210223@Kos: Support Cricket AIO [Redmine: #150386]
		- 20210420@Kos: Support Time Machine Over/Under [Redmine: #153302]
		- 20210630@Kos: Support Beach Volleyball [Redmine: #157296]
		- 20211227@Kos: Exclude league and match which IsDeleted = 1 [RedmineID: #163733]
		- 20220315@Kos: Support Cricket phase 2 [Redmine: #168034]
		- 20220428@Kos: Support Bitcoin [Redmine: #160160]
		- 20220722@Kos: Support Volleyball AIO [Redmine: #175143]
		- 20231127@Kos: Hide Saba Virtual Sports leagues [Redmine: #197440]
		- 20231221@Kos: Hide Redcat88 matches [Redmine: #198539]
		- 20231226@Kos: Switch to use ResultDetailOS for Bandy [Redmine: #198714]
		- 20240315@Kos: Only hide Saba Soccer, Saba Basketball, Saba Futsal, Saba Soccer Pingoal, Saba Basketball Pingoal, Saba E-Sports PinGoal [Redmine: #201283]
					- Support Saba Ice Hockey
		- 20240717@Kos: Support Baseball AIO [Redmine: #207510]
		- 20240917@Kos: Hotfix - missing child products of Virtual Sports [Redmine: #210867]
		- 20240920@Kos: Support Baseball AIO phase 2 [Redmine: #209584]
		- 20241002@Kos: Hotfix - not show league test in PRO [Redmine: #211744]
					- Add new param @IsShowAll BIT
		- 20241002@Kos: Support BetRadar Horse Racing [Redmine: #210808]
		- 20241028@Kos: Support Betby Virtual Sports 6 [Redmine: #212446]
		- 20241216@Kos: Support Virtual Sports 5 [Redmine: 207582]
		- 20250402@Kos: Support Virtual Sports 7 [Redmine: 219083]
		- 20250904@Kelvin: Basketball - Offer 32 new bettypes [Redmine: 235299]
		- 20251008@Kelvin: Virtual Sports 6 - Betby - Add new eSoccer sport and new bet types [Redmine: #240929]
*/

BEGIN
	SET NOCOUNT ON

	/* Get list ResourceID excluded */
	------------------------------------------------------------------------------------------------------------------
	DROP TABLE IF EXISTS #tmpExcludeResourceID

	CREATE TABLE #tmpExcludeResourceID (
		SportType INT,
		ResourceID VARCHAR(20),
		PRIMARY KEY (SportType, ResourceID)
	)

	INSERT INTO #tmpExcludeResourceID (SportType, ResourceID)
	SELECT SportType, ResourceID
	FROM dbo.f_ExcludeResourceID()
	------------------------------------------------------------------------------------------------------------------

	SELECT DISTINCT ProductID
	INTO #LicenseeProduct
	FROM bodb_licensee.dbo.LicenseeProduct3rd WITH (NOLOCK)
	WHERE LicenseeID = @LicenseeId

	INSERT INTO #LicenseeProduct(ProductID)
	SELECT g.ProductId
	FROM dbo.Lrf_f_GroupProduct() AS g
	WHERE EXISTS (SELECT 1 FROM #LicenseeProduct WHERE ProductID = g.GroupProductId)
		AND NOT EXISTS (SELECT 1 FROM #LicenseeProduct WHERE ProductID = g.ProductId)

	DECLARE @Sport AS TABLE (SportType INT)

	IF @EventDate > @MoveBetsDay
	BEGIN
		-- Sportsbook, Number Game, Virtual Sports
		INSERT INTO @Sport(SportType)
		SELECT DISTINCT m.sporttype
		FROM dbo.match AS m WITH (NOLOCK)
			LEFT JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			OUTER APPLY (
					SELECT TOP 1 r.MatchID
					FROM dbo.ResultDetail r WITH (NOLOCK)
					WHERE SettlementStatusID > 0
						AND m.matchid = r.MatchID
						AND 1 = CASE WHEN m.sporttype = 1 
											AND (ResourceID NOT IN ('08', '09')
												OR HomeValue LIKE '%a%'
												OR HomeValue LIKE '%h%')
											AND NOT EXISTS (SELECT 1 FROM #tmpExcludeResourceID t WHERE t.SportType = m.sporttype AND r.ResourceID LIKE t.ResourceID) THEN 1
									WHEN m.sporttype = 2
										AND NOT EXISTS (SELECT 1 FROM #tmpExcludeResourceID t WHERE t.SportType = m.sporttype AND r.ResourceID LIKE t.ResourceID) THEN 1
									WHEN m.sporttype = 5 THEN 1
									ELSE 0
								END
				) s
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
			OUTER APPLY (
					SELECT TOP 1 r.MatchID
					FROM dbo.ResultDetailOS r WITH (NOLOCK)
					WHERE SettlementStatusID > 0
						AND m.matchid = r.MatchID
						AND 1 = CASE WHEN m.sporttype IN (6, 8, 9, 45, 58) THEN 1
									 WHEN m.sporttype = 50
										AND NOT EXISTS (SELECT 1 FROM #tmpExcludeResourceID t WHERE t.SportType = m.sporttype AND r.ResourceID LIKE t.ResourceID) THEN 1
									ELSE 0
								END
				) AS o
		WHERE m.eventdate = @EventDate
			AND m.sporttype <> 162
			AND (m.sporttype NOT IN (8, 50) OR ISNULL(ChildMatchType, 0) <> 200)		-- exclude Baseball, Cricket child match
			AND m.IsDeleted = 0
			AND (m.eventstatus NOT IN ('internal', 'closed', 'running')
				OR (mr.IsPending = 1 AND m.eventstatus IN ('running', 'closed'))
				OR (m.eventstatus = 'running'
					AND (mr.IsHTCal = 1
						OR ISNULL(s.MatchID, 0) <> 0		-- Sportting Solution, BAIO, BetRadar show running Match but settled least one type
						OR ISNULL(b.MatchID, 0) <> 0		-- BetRadar Virtual Basketball show running Match but settled least one type
						OR ISNULL(e.MatchID, 0) <> 0		-- E-Sports show running Match but settled least one type
						OR ISNULL(o.MatchID, 0) <> 0		-- Badminton, Cricket show running Match but settled least one type
				)))
			AND EXISTS ( SELECT 1
						FROM dbo.League AS l WITH (NOLOCK)
						WHERE l.leagueid = m.leagueid
							AND @IsShowAll IN (1, l.isTest)
							AND (l.LeagueGroupID IS NULL
								OR (l.LeagueGroupID NOT IN (SELECT LeagueGroupID FROM dbo.f_SabaVirtualSports())
									AND l.LeagueGroupID <> 215)			-- Redcat88 of Esports
								OR m.sporttype NOT IN (1, 2, 43)))

		-- Virtual Sports
		IF EXISTS (SELECT TOP(1) 1 FROM #LicenseeProduct WHERE ProductID = 5)
		BEGIN
			INSERT INTO @Sport(SportType)
			SELECT DISTINCT r.sporttype
			FROM (
					SELECT DISTINCT EventID
					FROM dbo.VSOutright WITH (NOLOCK)
					WHERE EventDate = @EventDate
				) AS o
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON o.EventID = r.EventID
				INNER JOIN dbo.League3rd AS l WITH (NOLOCK) ON l.League3rdId = r.LeagueID
			WHERE r.sporttype IN (125, 126, 127, 177, 198)
				AND r.EventStatus = 'completed'
				AND @IsShowAll IN (1, l.IsTest)
		END

		-- Bitcoin, Virtual Sports 6, Virtual Sports 5
		IF EXISTS (SELECT TOP(1) 1 FROM #LicenseeProduct WHERE ProductID IN (69, 71, 88))
		BEGIN
			INSERT INTO @Sport(SportType)
			SELECT DISTINCT m.SportType
			FROM dbo.Match3rd AS m WITH (NOLOCK)
				INNER JOIN dbo.League3rd AS l WITH (NOLOCK) ON l.League3rdId = m.League3rdId
				LEFT JOIN dbo.ResultDetail3rd AS r WITH (NOLOCK)
					ON r.MatchID = m.Match3rdId
					AND m.SportType IN (116, 134)
					AND r.SettlementStatusID > 0
			WHERE m.EventDate = @EventDate
				AND @IsShowAll IN (1, l.IsTest)
				AND 1 = CASE
							WHEN m.SportType IN (116, 134, 147, 175) AND m.EventStatus = 'completed' THEN 1
							WHEN m.SportType IN (116, 134)
								AND m.EventStatus IN ('Running', 'Ended')
								AND ISNULL(r.MatchID, 0) <> 0 THEN 1
							WHEN m.SportType = 147
								AND EventStatus IN ('Suspend', 'Running')
								AND (hthomescore IS NOT NULL OR htawayscore IS NOT NULL) THEN 1
							ELSE 0
						END
		END
	END
	ELSE
	BEGIN
		-- Sportsbook, Number Game, Virtual Sports
		INSERT INTO @Sport(SportType)
		SELECT DISTINCT m.sporttype
		FROM dbo.match14 AS m WITH (NOLOCK)
			LEFT JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			OUTER APPLY (
					SELECT TOP 1 r.MatchID
					FROM dbo.ResultDetail14 r WITH (NOLOCK)
					WHERE SettlementStatusID > 0
						AND m.matchid = r.MatchID
						AND 1 = CASE WHEN m.sporttype = 1 
											AND (ResourceID NOT IN ('08', '09')
												OR HomeValue LIKE '%a%'
												OR HomeValue LIKE '%h%')
											AND NOT EXISTS (SELECT 1 FROM #tmpExcludeResourceID t WHERE t.SportType = m.sporttype AND r.ResourceID LIKE t.ResourceID) THEN 1
									WHEN m.sporttype = 2
										AND NOT EXISTS (SELECT 1 FROM #tmpExcludeResourceID t WHERE t.SportType = m.sporttype AND r.ResourceID LIKE t.ResourceID) THEN 1
									WHEN m.sporttype = 5 THEN 1
									ELSE 0
								END
				) s
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
			OUTER APPLY (
					SELECT TOP 1 r.MatchID
					FROM dbo.ResultDetailOS14 r WITH (NOLOCK)
					WHERE SettlementStatusID > 0
						AND m.matchid = r.MatchID
						AND 1 = CASE WHEN m.sporttype IN (6, 8, 9, 45, 58) THEN 1
									 WHEN m.sporttype = 50
										AND NOT EXISTS (SELECT 1 FROM #tmpExcludeResourceID t WHERE t.SportType = m.sporttype AND r.ResourceID LIKE t.ResourceID) THEN 1
									ELSE 0
								END
				) AS o
		WHERE m.eventdate = @EventDate
			AND m.sporttype <> 162
			AND (m.sporttype NOT IN (8, 50) OR ISNULL(ChildMatchType, 0) <> 200)		-- exclude Baseball, Cricket child match
			AND (m.eventstatus NOT IN ('internal', 'closed', 'running')
				OR (mr.IsPending = 1 AND m.eventstatus IN ('running', 'closed'))
				OR (m.eventstatus = 'running'
					AND (mr.IsHTCal = 1
						OR ISNULL(s.MatchID, 0) <> 0		-- Sportting Solution, BAIO, BetRadar show running Match but settled least one type
						OR ISNULL(b.MatchID, 0) <> 0		-- BetRadar Virtual Basketball show running Match but settled least one type
						OR ISNULL(e.MatchID, 0) <> 0		-- E-Sports show running Match but settled least one type
						OR ISNULL(o.MatchID, 0) <> 0		-- Badminton, Cricket show running Match but settled least one type
				)))
			AND EXISTS ( SELECT 1
						FROM dbo.League AS l WITH (NOLOCK)
						WHERE l.leagueid = m.leagueid
							AND @IsShowAll IN (1, l.isTest)
							AND (l.LeagueGroupID IS NULL
								OR (l.LeagueGroupID NOT IN (SELECT LeagueGroupID FROM dbo.f_SabaVirtualSports())
									AND l.LeagueGroupID <> 215)				-- Redcat88 of Esports
								OR m.sporttype NOT IN (1, 2, 43)))

		-- Virtual Sports
		IF EXISTS (SELECT TOP(1) 1 FROM #LicenseeProduct WHERE ProductID = 5)
		BEGIN
			INSERT INTO @Sport(SportType)
			SELECT DISTINCT r.sporttype
			FROM dbo.VSOutright14 AS o WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo14 AS r WITH (NOLOCK) ON o.EventID = r.EventID
				INNER JOIN dbo.League3rd AS l WITH (NOLOCK) ON l.League3rdId = r.LeagueID
			WHERE r.sporttype IN (125, 126, 127, 177, 198)
				AND r.EventStatus = 'completed'
				AND o.EventDate = @EventDate
				AND @IsShowAll IN (1, l.IsTest)
		END

		-- Bitcoin, Virtual Sports 6, Virtual Sports 5
		IF EXISTS (SELECT TOP(1) 1 FROM #LicenseeProduct WHERE ProductID IN (69, 71, 88))
		BEGIN
			INSERT INTO @Sport(SportType)
			SELECT DISTINCT m.SportType
			FROM dbo.Match3rd14 AS m WITH (NOLOCK)
				INNER JOIN dbo.League3rd AS l WITH (NOLOCK) ON l.League3rdId = m.League3rdId
				LEFT JOIN dbo.ResultDetail3rd14 AS r WITH (NOLOCK)
					ON r.MatchID = m.Match3rdId
					AND m.SportType IN (116, 134)
					AND r.SettlementStatusID > 0
			WHERE m.EventDate = @EventDate
				AND @IsShowAll IN (1, l.IsTest)
				AND 1 = CASE
							WHEN m.SportType IN (116, 134, 147, 175) AND m.EventStatus = 'completed' THEN 1
							WHEN m.SportType IN (116, 134)
								AND m.EventStatus IN ('Running', 'Ended')
								AND ISNULL(r.MatchID, 0) <> 0 THEN 1
							ELSE 0
						END
		END
	END

	DELETE @Sport
	WHERE SportType NOT IN (SELECT DISTINCT s.SportType
							FROM dbo.SportBettypeMatrix AS s WITH (NOLOCK)
							WHERE s.ProductID = 1
								OR (s.ProductID = 3
									AND EXISTS (SELECT TOP(1) 1 FROM #LicenseeProduct WHERE ProductID = 2))
								OR EXISTS (SELECT TOP(1) 1 FROM #LicenseeProduct WHERE ProductID = s.ProductID))

	SELECT DISTINCT SportType,
		SportName
	FROM dbo.Sports WITH (NOLOCK)
	WHERE SportType IN (SELECT SportType FROM @Sport)
	ORDER BY SportType ASC,
		SportName ASC

	DROP TABLE #LicenseeProduct
END
GO
