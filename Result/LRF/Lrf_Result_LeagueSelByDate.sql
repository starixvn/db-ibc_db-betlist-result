/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Result_LeagueSelByDate]
	@EventDate		DATETIME,
	@MoveBetsDay	DATETIME,
	@SportType		SMALLINT	= 0,
	@IsShowAll		BIT			= 0 -- 1: Show All; 0: is NOT show Test
AS

/*
	Created: 20101201@Jacob
	Task: LRF Result Report - Load League dropdownlist
	DB: DBEXT.bodb02
	Original: Age_Result_LeagueSelByDate

	Revisions:
		- 20101201@Jacob: Copy source code from Age_Result_LeagueSelByDate
		- 20110308@Henry: Get more sporttype 152, 153
		- 20110908@Sophia: Add Condition Where : (ishtcal=1 OR calculate=1)
		- 20111004@Henry: Edit condition OR to show the row which have mr.IsPending=1 AND (match.eventstatus = 'running' OR match.eventstatus = 'closed')
		- 20111025@Henry: Edit condition OR to show the rows which have eventstatus IN ('running','closed')
		- 20130916@Jim: Offer Virtual Tennis
		- 20150414@Sophia: Support BetRadar
		- 20150416@Sophia: Condition of showing Running match different between Sporting solution and BetRadar
		- 20150810@Sophia: Hardcode to exclude ResultDetail of bettype 216, 217 for a temporary time [#40991]
		- 20160829@Kos: Include ResourceID '08' to support PH All In One phase 2b [#Redmine: 62882]
		- 20161021@Kos: Separate bettrans and bettrans14 range, exclude Fast Market result [#Redmine: 56589]
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
		- 20201006@Razor: Support Time Machine Over/Under [Redmine: #141998]
		- 20210223@Kos: Support Cricket AIO [Redmine: #150386]
		- 20210420@Kos: Support Time Machine Over/Under [Redmine: #153302]
		- 20210630@Kos: Support Beach Volleyball [Redmine: #157296]
		- 20211227@Kos: Exclude league and match which IsDeleted = 1 [RedmineID: #163733]
		- 20220315@Kos: Support Cricket phase 2 [Redmine: #168034]
		- 20220428@Kos: Support Bitcoin [Redmine: #160160]
		- 20220607@Kos: Hotfix - Virtual Basketball [Redmine: #173815]
		- 20220609@Kos: Remove IsDeleted for League and Team [Redmine: #171991]
		- 20220722@Kos: Support Volleyball AIO [Redmine: #175143]
		- 20231127@Kos: Hide Saba Virtual Sports leagues [Redmine: #197440]
		- 20231221@Kos: Hide Redcat88 matches [Redmine: #198539]
		- 20231226@Kos: Switch to use ResultDetailOS for Bandy [Redmine: #198714]
		- 20240315@Kos: Only hide Saba Soccer, Saba Basketball, Saba Futsal, Saba Soccer Pingoal, Saba Basketball Pingoal, Saba E-Sports PinGoal [Redmine: #201283]
					- Support Saba Ice Hockey
		- 20240429@Kos: Return LeagueGroupId to support Jollysports [Redmine: #203258]
		- 20240717@Kos: Support Baseball AIO [Redmine: #207510]
		- 20240906@Kos: Support Baseball AIO phase 2 [Redmine: #209584]
		- 20240919@Kos: Support BetRadar Horse Racing [Redmine: #210808]
		- 20241028@Kos: Support Betby Virtual Sports 6 [Redmine: #212446]
		- 20241216@Kos: Support Virtual Sports 5 [Redmine: 207582]
		- 20250402@Kos: Support Virtual Sports 7 [Redmine: 219083]
		- 20250905@Kelvin: Basketball - Offer 32 new bettypes [Redmine: #235299]
		- 20251008@Kelvin: Virtual Sports 6 - Betby - Add new eSoccer sport and new bet types [Redmine: #240929]
		- 20251008@Kelvin: Virtual Sports 6 - Betby - Add new E-Volleyball sport and new bet types [Redmine: #241527]
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
	IF @EventDate > @MoveBetsDay
	BEGIN
		IF @SportType NOT IN (114, 116, 125, 126, 127, 134, 147, 175, 177, 193, 198)
		BEGIN
			SELECT DISTINCT
				l.leaguename,
				l.leagueid,
				l.LeagueGroupID,
				@EventDate AS EventDate,
				m.sporttype
			FROM (
					SELECT DISTINCT m.leagueid,
						m.sporttype
					FROM dbo.match AS m WITH (NOLOCK)
						LEFT JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid + 1 = mr.matchid + 1
						LEFT JOIN (
								SELECT DISTINCT MatchID
								FROM dbo.ResultDetail r WITH (NOLOCK) 
								WHERE SettlementStatusID > 0
									AND (
											(@SportType = 1
												AND (ResourceID NOT IN ('08', '09')
													OR HomeValue LIKE '%a%'
													OR HomeValue LIKE '%h%')
												AND NOT EXISTS (SELECT 1 FROM #tmpExcludeResourceID t WHERE t.SportType = @SportType AND r.ResourceID LIKE t.ResourceID)
											)
											OR (@SportType = 2
												AND NOT EXISTS (SELECT 1 FROM #tmpExcludeResourceID t WHERE t.SportType = @SportType AND r.ResourceID LIKE t.ResourceID)
												)
											OR @SportType = 5
										)
							) AS r ON m.matchid + 1 = r.MatchID + 1
						LEFT JOIN (
								SELECT DISTINCT MatchID
								FROM dbo.ResultDetailES WITH (NOLOCK)
								WHERE SettlementStatusID > 0 AND @SportType = 43
							) AS e ON m.matchid + 1 = e.MatchID + 1
						LEFT JOIN (
								SELECT DISTINCT MatchID
								FROM dbo.ResultDetailOS r WITH (NOLOCK)
								WHERE SettlementStatusID > 0
									AND (
											@SportType IN (6, 8, 9, 45, 58)
											OR (@SportType = 50
												AND NOT EXISTS (SELECT 1 FROM #tmpExcludeResourceID t WHERE t.SportType = @SportType AND r.ResourceID LIKE t.ResourceID)
												)
										)
							) AS o ON o.MatchID + 1 = m.matchid + 1
					WHERE m.eventdate = @EventDate
						AND m.sporttype NOT IN (162, 201)
						AND (m.sporttype NOT IN (8, 50) OR ISNULL(ChildMatchType, 0) <> 200)		-- exclude Baseball, Cricket child match
						AND m.sporttype = CASE WHEN @SportType = 0 THEN m.sporttype ELSE @SportType END
						AND m.IsDeleted = 0
						AND (m.eventstatus NOT IN ('internal', 'closed', 'running')
							OR (mr.IsPending = 1 AND m.eventstatus IN ('running', 'closed') )
							OR (m.eventstatus = 'running'
								AND (mr.IsHTCal = 1
									OR ISNULL(r.MatchID, 0) <> 0
									OR ISNULL(e.MatchID, 0) <> 0
									OR ISNULL(o.MatchID, 0) <> 0)))
				) AS m
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
			WHERE @IsShowAll IN (1, l.isTest)
				AND (l.LeagueGroupID IS NULL
					OR (l.LeagueGroupID NOT IN (SELECT LeagueGroupID FROM dbo.f_SabaVirtualSports())
						AND l.LeagueGroupID <> 215)				-- Redcat88 of Esports
					OR m.sporttype NOT IN (1, 2, 43))
			ORDER BY m.sporttype ASC,
				l.leaguename ASC
		END
		ELSE IF @SportType IN (114, 116, 134, 147, 175)	-- Bitcoin, Virtual Sports 6, VS5
		BEGIN
			SELECT DISTINCT
				l.LeagueName,
				l.League3rdId AS LeagueId,
				0 AS LeagueGroupID,
				m.EventDate,
				m.SportType
			FROM dbo.League3rd AS l WITH (NOLOCK)
				INNER JOIN dbo.Match3rd AS m WITH (NOLOCK) ON m.League3rdId = l.League3rdId
				LEFT JOIN dbo.ResultDetail3rd AS r WITH (NOLOCK)
					ON r.MatchID = m.Match3rdId
					AND m.SportType IN (114, 116, 134)
					AND r.SettlementStatusID > 0
			WHERE m.EventDate = @EventDate
				AND l.sporttype = @SportType
				AND 1 = CASE
							WHEN m.EventStatus = 'completed' THEN 1
							WHEN m.SportType IN (114, 116, 134)
								AND m.EventStatus IN ('Running', 'Ended')
								AND ISNULL(r.MatchID, 0) <> 0 THEN 1
							WHEN m.SportType = 147
								AND m.EventStatus IN ('Suspend', 'Running')
								AND (m.hthomescore IS NOT NULL OR m.htawayscore IS NOT NULL) THEN 1
							ELSE 0
						END
			ORDER BY m.SportType ASC,
				l.LeagueName ASC
		END
		ELSE IF @SportType = 193
		BEGIN
			SELECT DISTINCT
				l.leaguename,
				l.leagueid,
				0 AS LeagueGroupID,
				@EventDate AS EventDate,
				@SportType AS SportType
			FROM dbo.League AS l WITH (NOLOCK)
				INNER JOIN (
						SELECT DISTINCT leagueid
						FROM dbo.match AS m WITH (NOLOCK)
							LEFT JOIN (
								SELECT DISTINCT MatchID
								FROM dbo.ResultDetail3rd WITH (NOLOCK) 
								WHERE SettlementStatusID > 0
							) AS r ON m.matchid + 1 = r.MatchID + 1
						WHERE m.eventdate = @EventDate
							AND m.sporttype = 193
							AND m.IsDeleted = 0
							AND (m.eventstatus NOT IN ('closed', 'running')
								OR (ISNULL(r.MatchID, 0) <> 0 AND m.eventstatus = 'running'))
					) o ON l.leagueid = o.leagueid 
			WHERE l.sporttype = @SportType
				AND @IsShowAll IN (1, l.isTest)
		END
		ELSE IF @SportType IN (125, 126, 127, 177, 198)
		BEGIN
			SELECT DISTINCT
				l.LeagueName,
				r.LeagueID,
				0 AS LeagueGroupID,
				@EventDate AS EventDate,
				@SportType AS SportType
			FROM dbo.League3rd AS l WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.LeagueID = l.League3rdId
				INNER JOIN (
						SELECT DISTINCT EventID
						FROM dbo.VSOutright WITH (NOLOCK)
						WHERE EventDate = @EventDate
					) o ON r.EventID = o.EventID
			WHERE r.EventStatus = 'completed'
				AND r.sporttype = @SportType
				AND @IsShowAll IN (1, l.IsTest)
		END
	END
	ELSE
	BEGIN
		IF @SportType NOT IN (114, 116, 125, 126, 127, 134, 147, 175, 177, 193, 198)
		BEGIN
			SELECT DISTINCT
				l.leaguename,
				l.leagueid,
				l.LeagueGroupID,
				@EventDate AS EventDate,
				m.sporttype
			FROM (
					SELECT DISTINCT m.leagueid,
						m.sporttype
					FROM dbo.match14 AS m WITH (NOLOCK)
						LEFT JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
						LEFT JOIN (
								SELECT DISTINCT MatchID
								FROM dbo.ResultDetail14 r WITH (NOLOCK) 
								WHERE SettlementStatusID > 0
									AND (
											(@SportType = 1
												AND (ResourceID NOT IN ('08', '09')
													OR HomeValue LIKE '%a%'
													OR HomeValue LIKE '%h%')
												AND NOT EXISTS (SELECT 1 FROM #tmpExcludeResourceID t WHERE t.SportType = @SportType AND r.ResourceID LIKE t.ResourceID)
											)
											OR (@SportType = 2
												AND NOT EXISTS (SELECT 1 FROM #tmpExcludeResourceID t WHERE t.SportType = @SportType AND r.ResourceID LIKE t.ResourceID)
												)
											OR @SportType = 5
										)
							) AS r ON m.matchid = r.MatchID
						LEFT JOIN (
								SELECT DISTINCT MatchID
								FROM dbo.ResultDetailES14 WITH (NOLOCK)
								WHERE SettlementStatusID > 0 AND @SportType = 43
							) AS e ON m.matchid + 1 = e.MatchID + 1
						LEFT JOIN (
								SELECT DISTINCT MatchID
								FROM dbo.ResultDetailOS14 r WITH (NOLOCK)
								WHERE SettlementStatusID > 0
									AND (
											@SportType IN (6, 8, 9, 45, 58)
											OR (@SportType = 50
												AND NOT EXISTS (SELECT 1 FROM #tmpExcludeResourceID t WHERE t.SportType = @SportType AND r.ResourceID LIKE t.ResourceID)
												)
										)
							) AS o ON o.MatchID + 1 = m.matchid + 1
					WHERE m.eventdate = @EventDate
						AND m.sporttype NOT IN (162, 201)
						AND (m.sporttype NOT IN (8, 50) OR ISNULL(ChildMatchType, 0) <> 200)		-- exclude Baseball, Cricket child match
						AND m.sporttype = CASE WHEN @SportType = 0 THEN m.sporttype ELSE @SportType END
						AND (m.eventstatus NOT IN ('internal', 'closed', 'running')
							OR (mr.IsPending = 1 AND m.eventstatus IN ('running', 'closed') )
							OR (m.eventstatus = 'running'
								AND (mr.IsHTCal = 1
									OR ISNULL(r.MatchID, 0) <> 0
									OR ISNULL(e.MatchID, 0) <> 0
									OR ISNULL(o.MatchID, 0) <> 0)))
				) AS m
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
			WHERE @IsShowAll IN (1, l.isTest)
				AND (l.LeagueGroupID IS NULL
					OR (l.LeagueGroupID NOT IN (SELECT LeagueGroupID FROM dbo.f_SabaVirtualSports())
						AND l.LeagueGroupID <> 215)			-- Redcat88 of Esports
					OR m.sporttype NOT IN (1, 2, 43))
			ORDER BY m.sporttype ASC,
				l.leaguename ASC
		END
		ELSE IF @SportType IN (114, 116, 134, 147, 175)	-- Bitcoin, Virtual Sports 6, VS5
		BEGIN
			SELECT DISTINCT
				l.LeagueName,
				l.League3rdId AS LeagueId,
				0 AS LeagueGroupID,
				m.EventDate,
				m.SportType
			FROM dbo.League3rd AS l WITH (NOLOCK)
				INNER JOIN dbo.Match3rd14 AS m WITH (NOLOCK) ON m.League3rdId = l.League3rdId
				LEFT JOIN dbo.ResultDetail3rd14 AS r WITH (NOLOCK)
					ON r.MatchID = m.Match3rdId
					AND m.SportType IN (114, 116, 134)
					AND r.SettlementStatusID > 0
			WHERE m.EventDate = @EventDate
				AND l.sporttype = @SportType
				AND 1 = CASE
							WHEN m.EventStatus = 'completed' THEN 1
							WHEN m.SportType IN (114, 116, 134)
								AND m.EventStatus IN ('Running', 'Ended')
								AND ISNULL(r.MatchID, 0) <> 0 THEN 1
							ELSE 0
						END
			ORDER BY m.SportType ASC,
				l.LeagueName ASC
		END
		ELSE IF @SportType = 193
		BEGIN
			SELECT DISTINCT
				l.leaguename,
				l.leagueid,
				0 AS LeagueGroupID,
				@EventDate AS EventDate,
				@SportType AS SportType
			FROM dbo.League AS l WITH (NOLOCK)
				INNER JOIN (
						SELECT DISTINCT leagueid
						FROM dbo.match14 AS m WITH (NOLOCK)
							LEFT JOIN (
								SELECT DISTINCT MatchID
								FROM dbo.ResultDetail3rd14 WITH (NOLOCK) 
								WHERE SettlementStatusID > 0
							) AS r ON m.matchid + 1 = r.MatchID + 1
						WHERE m.eventdate = @EventDate
							AND m.sporttype = 193
							AND (m.eventstatus NOT IN ('closed', 'running')
								OR (ISNULL(r.MatchID, 0) <> 0 AND m.eventstatus = 'running'))
					) o ON l.leagueid = o.leagueid 
			WHERE l.sporttype = @SportType
				AND @IsShowAll IN (1, l.isTest)
		END
		ELSE IF @SportType IN (125, 126, 127, 177, 198)
		BEGIN
			SELECT DISTINCT
				l.LeagueName,
				r.LeagueID,
				0 AS LeagueGroupID,
				@EventDate AS EventDate,
				@SportType AS SportType
			FROM dbo.League3rd AS l WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo14 AS r WITH (NOLOCK) ON r.LeagueID = l.League3rdId
				INNER JOIN dbo.VSOutright14 AS o WITH (NOLOCK) ON o.EventID = r.EventID
			WHERE o.EventDate = @EventDate
				AND r.EventStatus = 'completed'
				AND r.sporttype = @SportType
				AND @IsShowAll IN (1, l.IsTest)
		END
	END
END
GO
