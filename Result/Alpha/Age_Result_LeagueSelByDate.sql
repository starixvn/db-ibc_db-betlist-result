/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp, wsv_alpv" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_Result_LeagueSelByDate]
	@EventDate		DATETIME,
	@MoveBetsDay	DATETIME,
	@SportType		SMALLINT	= 0,
	@IsShowAll		BIT			= 1
AS

/*
	Created:
	Task: Alpha Result Report - Load League dropdownlist
	DB: DBAGE.bodb02
	Original: LeagueSelForResult

	Revisions: 
		- 20100524@Jamie: Only show Tote HR
		- 20101207@Simon: Show All League or only show Live belong to @IsShowAll
		- 20110304@Lukas: Get more sporttype 152, 153
		- 20110908@Sophia: Add Condition Where : (mr.ishtcal=1 OR mr.calculate=1)
		- 20111003@Sophia: Edit condition OR to show the row which have eventstatus IN ('running', 'closed')
		- 20130301@Elodie: Add Virtual HR product
		- 20130805@Lukas: Hide live casino game
		- 20131121@Kathy: Add Virtual Greyhounds (182), Virtual Motor Racing (184) [Redmine:#7234]
		- 20140404@Dom: Add Virtual Speedway (183), Virtual Cycling Racing (185) 
		- 20150414@Sophia: Support Betradar
		- 20150416@Sophia: Condition of showing Running match different between Sporting solution and BetRadar
		- 20150810@Sophia: Hardcode to exclude ResultDetail of bettype 216, 217 for a temporary time [#40991]
		- 20151014@Sophia: Show internal match [#45531]
		- 20160829@Kos: Include ResourceID '08' to support PH All In One phase 2b [#Redmine: 62882]
		- 20161021@Kos: Exclude Fast Market result [#Redmine: 56589]
		- 20170405@Kos: Support Basketball AIO [#Redmine: 73033]
		- 20170802@Kos: Change Sporttype data type to SMALLINT [Redmine: #73545]
		- 20171012@Kos: Support PH AIO Phase 3 [Redmine: #82403]
		- 20180205@Kos: Don't support Racing anymore [#Redmine: 86086]
		- 20180320@Kos: Exclude Fast Market 2 [Redmine: #90708]
		- 20180410@Kos: Support Betradar Virtual Basketball [Redmine: #90616]
		- 20180907@Kos: Support E-Sports phase 2 [Redmine: #101047]
		- 20190805@Kos: Support PH AIO 4b [Redmine: #115235]
					- Change for "Next Goal" [Redmine: #115235]
		- 20191014@Kos: Support Badminton AIO phase 2 [Redmine: #120381]
		- 20191204@Kos: Show Instant Calculation Result for Corner Bettypes [Redmine: #124682]
		- 20200515@Kos: Support PH AIO phase 5.1 [Redmine: #132770]
		- 20200625@Kos: Integrate archive process for table VSRaceInfo [Redmine: #135963]
		- 20201006@Razor: Support Time Machine Over/Under [Redmine: #141998]
		- 20210223@Kos: Support Cricket AIO [Redmine: #148962]
		- 20210414@Razor: Support Time Machine HDP [Redmine: #152749]
		- 20210630@Razor: Support Beach Volleyball [Redmine: #156540]
		- 20210813@Razor: Support Bitcoin [Redmine: #159041]
		- 20210823@Razor: Support Cricket AIO 1.2 [Redmine: #160409]
		- 20211117@Razor: Support In-house Replication [Redmine: #164321]
		- 20220310@Razor: Support Cricket AIO 2 [Redmine: #166334]
		- 20220510@Razor: Remove In-house Replication [Redmine: #171699]
		- 20220711@Razor: Support Volleyball AIO [Redmine: #173861]
		- 20231127@Kos: Hide Saba Virtual Sports leagues [Redmine: #197469]
		- 20231127@Razor: Hide Redcat88 league of Esports [Redmine: #198337]
		- 20231219@Razor: Support Bandy sport using ResultDetailOS [Redmine: #198022]
		- 20240403@Razor: Only hide Saba Soccer, Saba Basketball, Saba Futsal, Saba Soccer Pingoal, Saba Basketball Pingoal, Saba E-Sports PinGoal [Redmine: #203378]
				- Show Saba Ice Hockey, Criket, Tennis
*/

BEGIN
	SET NOCOUNT ON

	SELECT @IsShowAll = CASE @IsShowAll WHEN 1 THEN NULL ELSE 0 END

	DECLARE @ToDate DATETIME

	SELECT @ToDate = DATEADD(s, -1, DATEADD(d, 1, @EventDate))

	IF @SportType NOT IN (175, 181, 182, 184, 183, 185, 193)
	BEGIN
		SELECT DISTINCT
			l.leaguename,
			l.leagueid,
			m.eventdate,
			m.sporttype
		FROM dbo.League AS l WITH (NOLOCK)
			INNER JOIN
			(
				SELECT matchid, leagueid, eventdate, eventstatus, sporttype, ChildMatchType
				FROM dbo.match WITH (NOLOCK)
				UNION ALL
				SELECT matchid, leagueid, eventdate, eventstatus, sporttype, ChildMatchType
				FROM dbo.match14 WITH (NOLOCK)
			) AS m ON m.leagueid = l.leagueid
			LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN
				(	SELECT DISTINCT MatchID
					FROM dbo.ResultDetail WITH (NOLOCK)
					WHERE SettlementStatusID > 0
						AND ((@SportType = 1
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
								AND ResourceID NOT LIKE '487%')
							OR @SportType IN (2, 5) )
					UNION ALL
					SELECT DISTINCT MatchID
					FROM dbo.ResultDetail14 WITH (NOLOCK)
					WHERE SettlementStatusID > 0 
						AND ((@SportType = 1
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
								AND ResourceID NOT LIKE '487%')
							OR @SportType IN (2, 5))
				) AS R ON m.Matchid = R.MatchId
			LEFT JOIN
				(	SELECT DISTINCT MatchID
					FROM dbo.ResultDetailES WITH (NOLOCK)
					WHERE SettlementStatusID > 0 AND @SportType = 43
					UNION ALL
					SELECT DISTINCT MatchID
					FROM dbo.ResultDetailES14 WITH (NOLOCK)
					WHERE SettlementStatusID > 0 AND @SportType = 43
				) AS e ON m.Matchid = e.MatchId
			LEFT JOIN
				(	SELECT DISTINCT MatchID
					FROM dbo.ResultDetailOS WITH (NOLOCK)
					WHERE SettlementStatusID > 0
						AND (@SportType IN (6, 9, 45, 58)	-- Volleyball, Badminton, Beach Volleyball, Bandy
							OR (@SportType = 50
								AND ResourceID IN ('H1', 'H2', 'A1', 'A2', '9400', '9401', '9442', '9443', '9446', '9447', '9450', '9449', '9452', '9453', '94511', '96151')))
					UNION ALL
					SELECT DISTINCT MatchID
					FROM dbo.ResultDetailOS14 WITH (NOLOCK)
					WHERE SettlementStatusID > 0
						AND (@SportType IN (6, 9, 45, 58)	-- Volleyball, Badminton, Beach Volleyball, Bandy
							OR (@SportType = 50
								AND ResourceID IN ('H1', 'H2', 'A1', 'A2', '9400', '9401', '9442', '9443', '9446', '9447', '9450', '9449', '9452', '9453', '94511', '96151')))
				) AS o ON o.MatchID = m.matchid
		WHERE
			m.eventdate >= @EventDate
			AND m.eventdate <= @ToDate
			AND (m.eventstatus NOT IN ('closed', 'running')
				OR (mr.IsPending = 1 AND m.eventstatus IN ('running', 'closed'))
				OR (mr.IsHTCal = 1 AND m.eventstatus ='running')
				OR (ISNULL(R.MatchID, 0) <> 0 AND m.eventstatus = 'running')
				OR (ISNULL(e.MatchID, 0) <> 0 AND m.eventstatus = 'running')
				OR (ISNULL(o.MatchID, 0) <> 0 AND m.eventstatus = 'running'))
			AND m.sporttype NOT IN (201, 162)
			AND (m.sporttype <> 50 OR ISNULL(ChildMatchType, 0) <> 200)		-- exclude Cricket child match
			AND m.sporttype = CASE WHEN @SportType = 0 THEN m.sporttype ELSE @SportType END
			AND l.isTest = ISNULL(@IsShowAll, l.isTest)
			AND (l.LeagueGroupID IS NULL
				OR (l.LeagueGroupID NOT IN (SELECT LeagueGroupID FROM dbo.f_SabaVirtualSports())
					AND l.LeagueGroupID <> 215)-- Redcat88 of Esports
				OR l.sporttype NOT IN (1, 2, 43))
		ORDER BY m.sporttype ASC,
			l.leaguename ASC
	END
	ELSE IF @SportType IN (181, 182, 184, 183, 185)
	BEGIN
		IF @EventDate > @MoveBetsDay
		BEGIN
			SELECT DISTINCT
				l.leaguename,
				l.leagueid,
				o.EventDate,
				r.sporttype
			FROM dbo.League AS l WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON l.leagueid = r.LeagueID
				INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.EventDate >= @EventDate AND o.EventDate <= @ToDate
				AND r.EventStatus ='completed'
				AND l.isTest = ISNULL(@IsShowAll, l.isTest)
				AND r.SportType = @SportType
		END
		ELSE
		BEGIN
			SELECT DISTINCT
				l.leaguename,
				l.leagueid,
				o.EventDate,
				r.sporttype
			FROM dbo.League AS l WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo14 AS r WITH (NOLOCK) ON l.leagueid = r.LeagueID
				INNER JOIN dbo.VSOutright14 AS o WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.EventDate >= @EventDate AND o.EventDate <= @ToDate
				AND r.EventStatus ='completed'
				AND l.isTest = ISNULL(@IsShowAll, l.isTest)
				AND r.SportType = @SportType
		END
	END
	ELSE IF @SportType = 193
	BEGIN
		SELECT DISTINCT
			l.leaguename,
			l.leagueid,
			m.eventdate,
			m.sporttype
		FROM dbo.League AS l WITH (NOLOCK)
			INNER JOIN
			(
				SELECT matchid, leagueid, eventdate, eventstatus, sporttype
				FROM dbo.match WITH (NOLOCK)
				UNION ALL
				SELECT matchid, leagueid, eventdate, eventstatus, sporttype
				FROM dbo.match14 WITH (NOLOCK)
			) AS m ON m.leagueid = l.leagueid
			LEFT JOIN
				(	SELECT DISTINCT MatchID
					FROM dbo.ResultDetail3rd WITH (NOLOCK)
					WHERE SettlementStatusID > 0
					UNION ALL
					SELECT DISTINCT MatchID
					FROM dbo.ResultDetail3rd14 WITH (NOLOCK)
					WHERE SettlementStatusID > 0
				) R ON m.Matchid = R.MatchId
		WHERE
			m.eventdate >= @EventDate
			AND m.eventdate <= @ToDate
			AND (m.eventstatus NOT IN ('closed', 'running')
				OR (ISNULL(R.MatchID, 0) <> 0 AND m.eventstatus = 'running'))
			AND m.sporttype = CASE WHEN @SportType = 0 THEN m.sporttype ELSE @SportType END
			AND l.isTest = ISNULL(@IsShowAll, l.isTest)
		ORDER BY m.sporttype ASC,
			l.leaguename ASC
	END
	ELSE IF @SportType  = 175 --Bitcoin
	BEGIN
		SELECT DISTINCT
			l.leaguename AS leaguename,
			l.league3rdid AS leagueid,
			m.eventdate,
			m.sporttype
		FROM dbo.League3rd AS l WITH (NOLOCK)
			INNER JOIN
			(
				SELECT match3rdid, league3rdid, eventdate, eventstatus, sporttype
				FROM dbo.match3rd WITH (NOLOCK)
				UNION ALL
				SELECT match3rdid, league3rdid, eventdate, eventstatus, sporttype
				FROM dbo.match3rd14 WITH (NOLOCK)
			) AS m ON m.league3rdid = l.league3rdid
		WHERE
			m.eventdate = @EventDate
			AND m.eventstatus IN ('completed')
			AND m.sporttype = CASE WHEN @SportType = 0 THEN m.sporttype ELSE @SportType END
		ORDER BY m.sporttype ASC,
			l.leaguename ASC
	END
END
GO
