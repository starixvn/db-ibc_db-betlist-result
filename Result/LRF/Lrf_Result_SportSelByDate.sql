/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Result_SportSelByDate]
	@EventDate		DATETIME,
	@MoveBetsDay	DATETIME,
	@LicenseeId		INT
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
*/

BEGIN
	SET NOCOUNT ON

	SELECT DISTINCT ProductID
	INTO #LicenseeProduct
	FROM bodb_licensee.dbo.LicenseeProduct3rd WITH (NOLOCK)
	WHERE LicenseeID = @LicenseeId

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
							'192', '193', '206', '207', '208', '209', '210', '211', '212', '213', '214', '215', '488', '489', '490', '376')
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
						AND ResourceID NOT LIKE '228%'
						AND ResourceID NOT LIKE '229%'
						AND ResourceID NOT LIKE '486%'
						AND ResourceID NOT LIKE '487%'
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
				) AS o ON o.MatchID = m.matchid AND m.sporttype IN (6, 8, 9, 45, 58)
			LEFT JOIN (
					SELECT DISTINCT MatchID
					FROM dbo.ResultDetailOS WITH (NOLOCK)
					WHERE SettlementStatusID > 0
						AND ResourceID NOT IN ('00', '9442', '9443')
						AND ResourceID NOT LIKE '9410%'
						AND ResourceID NOT LIKE '9411%'
						AND ResourceID NOT LIKE '9422%'
						AND ResourceID NOT LIKE '9423%'
						AND ResourceID NOT LIKE '9428%'
						AND ResourceID NOT LIKE '9429%'
						AND ResourceID NOT LIKE '9434%'
						AND ResourceID NOT LIKE '9435%'
						AND ResourceID NOT LIKE '9454%'
						AND ResourceID NOT LIKE '9455%'
						AND ResourceID NOT LIKE '9460%'
						AND ResourceID NOT LIKE '9461%'
						AND ResourceID NOT LIKE '9484%'
						AND ResourceID NOT LIKE '9485%'
						AND ResourceID NOT LIKE '9490%'
						AND ResourceID NOT LIKE '9491%'
						AND ResourceID NOT LIKE '9410%'		-- phase 2
						AND ResourceID NOT LIKE '9411%'
						AND ResourceID NOT LIKE '9428%'
						AND ResourceID NOT LIKE '9429%'
						AND ResourceID NOT LIKE '9708%'
						AND ResourceID NOT LIKE '9709%'
						AND ResourceID NOT LIKE '9454%'
						AND ResourceID NOT LIKE '9455%'
						AND ResourceID NOT LIKE '9460%'
						AND ResourceID NOT LIKE '9461%'
						AND ResourceID NOT LIKE '9484%'
						AND ResourceID NOT LIKE '9485%'
						AND ResourceID NOT LIKE '9680%'
						AND ResourceID NOT LIKE '9690%'
						AND ResourceID NOT LIKE '9662%'
						AND ResourceID NOT LIKE '9663%'
						AND ResourceID NOT LIKE '9676%'
						AND ResourceID NOT LIKE '9686%'
						AND ResourceID NOT LIKE '9668%'
						AND ResourceID NOT LIKE '9671%'
						AND ResourceID NOT LIKE '9650%'
						AND ResourceID NOT LIKE '9651%'
						AND ResourceID NOT LIKE '9672%'
						AND ResourceID NOT LIKE '9675%'
						AND ResourceID NOT LIKE '9656%'
						AND ResourceID NOT LIKE '9657%'
						AND ResourceID NOT LIKE '9636%'
						AND ResourceID NOT LIKE '9637%'
						AND ResourceID NOT LIKE '9616%'
						AND ResourceID NOT LIKE '9617%'
						AND ResourceID NOT LIKE '9624%'
						AND ResourceID NOT LIKE '9625%'
						AND ResourceID NOT LIKE '9630%'
						AND ResourceID NOT LIKE '9631%'
						AND ResourceID NOT LIKE '9730%'
						AND ResourceID NOT LIKE '9731%'
						AND ResourceID NOT LIKE '9736%'
						AND ResourceID NOT LIKE '9737%'
				) AS c ON c.MatchID = m.matchid AND m.sporttype = 50
		WHERE m.eventdate = @EventDate
			AND m.sporttype <> 162
			AND (m.sporttype <> 50 OR ISNULL(ChildMatchType, 0) <> 200)		-- exclude Cricket child match
			AND m.IsDeleted = 0
			AND (m.eventstatus NOT IN ('internal', 'closed', 'running')
				OR (mr.IsPending = 1 AND m.eventstatus IN ('running', 'closed'))
				OR (m.eventstatus = 'running'
					AND (mr.IsHTCal = 1
						OR ISNULL(ss.MatchID, 0) <> 0		-- Sportting Solution, BAIO show running Match but settled least one type
						OR ISNULL(br.MatchID, 0) <> 0		-- BetRadar show running Match but settled least one type
						OR ISNULL(b.MatchID, 0) <> 0		-- BetRadar Virtual Basketball show running Match but settled least one type
						OR ISNULL(e.MatchID, 0) <> 0		-- E-Sports show running Match but settled least one type
						OR ISNULL(o.MatchID, 0) <> 0		-- Badminton show running Match but settled least one type
						OR ISNULL(c.MatchID, 0) <> 0)))		-- Cricket show running Match but settled least one type
			AND EXISTS ( SELECT 1
						FROM dbo.League AS l WITH (NOLOCK)
						WHERE l.leagueid = m.leagueid
							AND (l.LeagueGroupID IS NULL
								OR (l.LeagueGroupID NOT IN (SELECT LeagueGroupID FROM dbo.f_SabaVirtualSports())
									AND l.LeagueGroupID <> 215)			-- Redcat88 of Esports
								OR m.sporttype NOT IN (1, 2, 43)))

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
			WHERE l.sporttype IN (181, 182, 183, 184, 185)
				AND r.EventStatus = 'completed'
		END

		-- Bitcoin
		IF EXISTS (SELECT TOP(1) 1 FROM #LicenseeProduct WHERE ProductID = 69)
		BEGIN
			INSERT INTO @Sport
			SELECT DISTINCT SportType
			FROM dbo.Match3rd WITH (NOLOCK)
			WHERE SportType IN (175)
				AND EventDate = @EventDate
				AND EventStatus = 'completed'
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
							'192', '193', '206', '207', '208', '209', '210', '211', '212', '213', '214', '215', '488', '489', '490', '376')
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
						AND ResourceID NOT LIKE '228%'
						AND ResourceID NOT LIKE '229%'
						AND ResourceID NOT LIKE '486%'
						AND ResourceID NOT LIKE '487%'
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
				) AS o ON o.MatchID = m.matchid AND m.sporttype IN (6, 8, 9, 45, 58)
			LEFT JOIN (
					SELECT DISTINCT MatchID
					FROM dbo.ResultDetailOS14 WITH (NOLOCK)
					WHERE SettlementStatusID > 0
						AND ResourceID NOT IN ('00', '9442', '9443')
						AND ResourceID NOT LIKE '9410%'
						AND ResourceID NOT LIKE '9411%'
						AND ResourceID NOT LIKE '9422%'
						AND ResourceID NOT LIKE '9423%'
						AND ResourceID NOT LIKE '9428%'
						AND ResourceID NOT LIKE '9429%'
						AND ResourceID NOT LIKE '9434%'
						AND ResourceID NOT LIKE '9435%'
						AND ResourceID NOT LIKE '9454%'
						AND ResourceID NOT LIKE '9455%'
						AND ResourceID NOT LIKE '9460%'
						AND ResourceID NOT LIKE '9461%'
						AND ResourceID NOT LIKE '9484%'
						AND ResourceID NOT LIKE '9485%'
						AND ResourceID NOT LIKE '9490%'
						AND ResourceID NOT LIKE '9491%'
						AND ResourceID NOT LIKE '9410%'		-- phase 2
						AND ResourceID NOT LIKE '9411%'
						AND ResourceID NOT LIKE '9428%'
						AND ResourceID NOT LIKE '9429%'
						AND ResourceID NOT LIKE '9708%'
						AND ResourceID NOT LIKE '9709%'
						AND ResourceID NOT LIKE '9454%'
						AND ResourceID NOT LIKE '9455%'
						AND ResourceID NOT LIKE '9460%'
						AND ResourceID NOT LIKE '9461%'
						AND ResourceID NOT LIKE '9484%'
						AND ResourceID NOT LIKE '9485%'
						AND ResourceID NOT LIKE '9680%'
						AND ResourceID NOT LIKE '9690%'
						AND ResourceID NOT LIKE '9662%'
						AND ResourceID NOT LIKE '9663%'
						AND ResourceID NOT LIKE '9676%'
						AND ResourceID NOT LIKE '9686%'
						AND ResourceID NOT LIKE '9668%'
						AND ResourceID NOT LIKE '9671%'
						AND ResourceID NOT LIKE '9650%'
						AND ResourceID NOT LIKE '9651%'
						AND ResourceID NOT LIKE '9672%'
						AND ResourceID NOT LIKE '9675%'
						AND ResourceID NOT LIKE '9656%'
						AND ResourceID NOT LIKE '9657%'
						AND ResourceID NOT LIKE '9636%'
						AND ResourceID NOT LIKE '9637%'
						AND ResourceID NOT LIKE '9616%'
						AND ResourceID NOT LIKE '9617%'
						AND ResourceID NOT LIKE '9624%'
						AND ResourceID NOT LIKE '9625%'
						AND ResourceID NOT LIKE '9630%'
						AND ResourceID NOT LIKE '9631%'
						AND ResourceID NOT LIKE '9730%'
						AND ResourceID NOT LIKE '9731%'
						AND ResourceID NOT LIKE '9736%'
						AND ResourceID NOT LIKE '9737%'
				) AS c ON c.MatchID = m.matchid AND m.sporttype = 50
		WHERE m.eventdate = @EventDate
			AND m.sporttype <> 162
			AND (m.sporttype <> 50 OR ISNULL(ChildMatchType, 0) <> 200)		-- exclude Cricket child match
			AND (m.eventstatus NOT IN ('internal', 'closed', 'running')
				OR (mr.IsPending = 1 AND m.eventstatus IN ('running', 'closed'))
				OR (m.eventstatus = 'running'
					AND (mr.IsHTCal = 1
						OR ISNULL(ss.MatchID, 0) <> 0		-- Sportting Solution, BAIO show running Match but settled least one type
						OR ISNULL(br.MatchID, 0) <> 0		-- BetRadar show running Match but settled least one type
						OR ISNULL(b.MatchID, 0) <> 0		-- BetRadar Virtual Basketball show running Match but settled least one type
						OR ISNULL(e.MatchID, 0) <> 0		-- E-Sports show running Match but settled least one type
						OR ISNULL(o.MatchID, 0) <> 0		-- Badminton show running Match but settled least one type
						OR ISNULL(c.MatchID, 0) <> 0)))		-- Cricket show running Match but settled least one type
			AND EXISTS ( SELECT 1
						FROM dbo.League AS l WITH (NOLOCK)
						WHERE l.leagueid = m.leagueid
							AND (l.LeagueGroupID IS NULL
								OR (l.LeagueGroupID NOT IN (SELECT LeagueGroupID FROM dbo.f_SabaVirtualSports())
									AND l.LeagueGroupID <> 215)				-- Redcat88 of Esports
								OR m.sporttype NOT IN (1, 2, 43)))

		-- Virtual Sports
		IF EXISTS (SELECT TOP(1) 1 FROM #LicenseeProduct WHERE ProductID = 5)
		BEGIN
			INSERT INTO @Sport
			SELECT DISTINCT l.sporttype
			FROM dbo.VSOutright14 AS o WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo14 AS r WITH (NOLOCK) ON o.EventID = r.EventID
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON r.LeagueID = l.leagueid
			WHERE l.sporttype IN (181, 182, 183, 184, 185)
				AND r.EventStatus = 'completed'
				AND o.EventDate = @EventDate
		END

		-- Bitcoin
		IF EXISTS (SELECT TOP(1) 1 FROM #LicenseeProduct WHERE ProductID = 69)
		BEGIN
			INSERT INTO @Sport
			SELECT DISTINCT SportType
			FROM dbo.Match3rd14 WITH (NOLOCK)
			WHERE SportType IN (175)
				AND EventDate = @EventDate
				AND EventStatus = 'completed'
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
