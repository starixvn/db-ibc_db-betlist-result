/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Result_MatchSelByLeague]
	@FromDate		DATETIME,
	@MoveBetsDay	DATETIME,
	@LeagueId		INT,
	@SportType		SMALLINT	= 0,
	@IsShowAll		BIT			= 1		-- 1: Show All; 0: is NOT show Test
AS

/*
	Created: 20101201@Jacob
	Task: LRF Result Report - Load match list
	DB: DBEXT.bodb02
	Original: Age_Result_MatchSelByLeague

	Revisions:
		- 20101201@Jacob: Copy source code from Age_Result_MatchSelByLeague
		- 20110401@Henry: Not show BetDaq's match in result page
		- 20110907@Sophia: Add column IsHTCal, calculate for Pending Result. And edit Condition Where (mr.ishtcal=1 OR mr.calculate=1)
		- 20110930@Henry: Add column IsPending. Edit condition OR to show the row which have mr.IsPending = 1 AND (m.eventstatus = 'running' OR m.eventstatus = 'closed')
		- 20111025@Henry: Edit condition OR to show the rows which have eventstatus IN ('running', 'closed')
		- 20120910@Henry: return homeid2
		- 20131017@Jim: Remove ticket running
		- 20131017@Jim: Turn to use GlobalShowTime for display the Kick-off-Time
		- 20141021@Jim : support to show Sporting Solution data detail
		- 20140407@Sophia: Support BetRadar and revise code
		- 20150416@Sophia: Condition of showing Running match different between Sporting solution and BetRadar
		- 20150810@Sophia: Hardcode to exclude ResultDetail of bettype 216, 217 for a temporary time [#40991]
		- 20160624@Francis: Revise SP to avoid bad parameter sniffing on LeagueID using optimize for
		- 20160829@Kos: Include ResourceID '08' to support PH All In One phase 2b [#Redmine: 62882]
		- 20161021@Kos: Separate bettrans and bettrans14 range, exclude Fast Market result [#Redmine: 56589]
		- 20170117@Kos: Support new result status Abandoned 1H/2H [#Redmine: 70410]
		- 20170418@Kos: Support Basketball AIO [#Redmine: 73033]
		- 20170531@Kos: Prevent data duplication during Move Bet process [#Redmine: 77065]
		- 20170623@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20170919@Kos: Change Sporttype data type to SMALLINT [Redmine: #73545]
		- 20170418@Kos: Support Basketball AIO [#Redmine: 73033]
		- 20171106@Kos: Support PH AIO 3 [#Redmine: 83970]
		- 20180103@Kos: Don't support Live Casino anymore [#Redmine: 85965]
		- 20180320@Kos: Exclude Fast Market 2 result [#Redmine: 90879]
		- 20180412@Kos: Support Betradar Virtual Basketball [Redmine: #90616]
		- 20181015@Kos: Support 2 new statuses Result Pending and Under Settlement [#Redmine: 102428]
					- Move eventstatus data transform to web (no change for Tennis)
		- 20181018@Kos: Support E-Sports 2 [#Redmine: 100721]
		- 20190814@Kos: Support PH AIO phase 4b [Redmine: #118300]
					- Change for "Next Goal" [Redmine: #115235]
		- 20191107@Kos: Support Badminton AIO phase 2 [Redmine: #120336]
		- 20191206@Kos: Show Instant Calculation Result for Corner Bettypes [Redmine: #124682]
		- 20200515@Kos: Support PH AIO phase 5.1 [Redmine: #132770]
		- 20201006@Razor: Support Time Machine Over/Under [Redmine: #141998]
		- 20210223@Kos: Support Cricket AIO [Redmine: #150386]
		- 20210420@Kos: Support Time Machine Over/Under [Redmine: #153302]
		- 20210630@Kos: Support Beach Volleyball [Redmine: #157296]
		- 20211227@Kos: Exclude league and match which IsDeleted = 1 [RedmineID: #163733]
		- 20220315@Kos: Support Cricket phase 2 [Redmine: #168034]
		- 20220325@Kos: Extend OtherInfo length [Redmine: #168034]
		- 20220609@Kos: Remove IsDeleted for League and Team [Redmine: #171991]
		- 20220623@Kos: Support more map for E-Sports [Redmine: #174251]
		- 20220722@Kos: Support Volleyball AIO [Redmine: #175143]
		- 20230321@Kos: Change Display HT Score for some Special League of Soccer [Redmine: #181331]
		- 20231127@Kos: Hide Saba Virtual Sports leagues [Redmine: #197440]
		- 20231221@Kos: Hide Redcat88 matches [Redmine: #198539]
*/

BEGIN 
	SET NOCOUNT ON 

	SELECT @IsShowAll = CASE @IsShowAll WHEN 1 THEN NULL ELSE 0 END

	DECLARE @EventDate	DATE

	SELECT @EventDate = @FromDate

	CREATE TABLE #Match (
		SportType			SMALLINT,
		BetStatus			NVARCHAR(50),
		LeagueId			INT,
		MatchId				INT,
		Lcolor				NVARCHAR(50),
		MatchCode			NVARCHAR(50),
		EventDate			DATETIME,
		KickOffTime			DATETIME,
		HomeId				INT,
		AwayId				INT,
		HtHomeScore			INT,
		HtAwayScore			INT,
		FinalHomeScore		INT,
		FinalAwayScore		INT,
		EventStatus			NVARCHAR(50),
		ShowTime			NVARCHAR(50),
		HomeId2				INT,
		IsNeutral			BIT,
		GoalRecord			VARCHAR(50),
		IsHTCal				BIT,
		Calculate			BIT,
		SettlementStatus	TINYINT,
		NoHTScore			BIT)

	IF @SportType <> 5
	BEGIN
		INSERT INTO #Match
		SELECT
			l.sporttype,
			m.betstatus,
			m.leagueid,
			m.matchid,
			l.lcolor,
			m.matchcode,
			m.eventdate,
			CASE
				WHEN m.sporttype NOT IN (161, 180, 186) THEN m.GlobalShowTime
				ELSE m.kickofftime
			END kickofftime,
			m.homeid,
			m.awayid,
			m.hthomescore,
			m.htawayscore,
			m.finalhomescore,
			m.finalawayscore,
			m.eventstatus,
			m.showtime,
			ISNULL(m.homeid2, 0) AS homeid2,	-- contains bettype of Live Casino 
			ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
			m.GoalRecord,
			ISNULL(mr.IsHTCal, 0) AS IsHTCal,
			ISNULL(mr.calculate, 0) AS calculate,
			ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
			ISNULL(mr.NoHTScore, 0) AS NoHTScore
		FROM dbo.League AS l WITH (NOLOCK)
			INNER JOIN
				(SELECT sporttype, betstatus,matchid, matchcode, homeid, awayid, leagueid, eventdate, eventstatus,
					GlobalShowTime, kickofftime, hthomescore, htawayscore, finalhomescore, finalawayscore, showtime,
					isneutral, goalrecord, homeid2, SettlementStatus, ChildMatchType
				FROM dbo.match WITH (NOLOCK)
				WHERE IsDeleted = 0
				UNION ALL
				SELECT sporttype, betstatus,matchid, matchcode, homeid, awayid, leagueid, eventdate, eventstatus,
					globalshowtime, kickofftime, hthomescore, htawayscore, finalhomescore, finalawayscore, showtime,
					isneutral, goalrecord, homeid2, 0 AS SettlementStatus, ChildMatchType
				FROM dbo.match14 WITH (NOLOCK)
				) AS m on m.leagueid = l.leagueid
			LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN (
				SELECT DISTINCT MatchID
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
						OR @SportType = 2)
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
						OR @SportType = 2)
				UNION ALL
				SELECT DISTINCT MatchID
				FROM dbo.ResultDetailES WITH (NOLOCK)
				WHERE SettlementStatusID > 0 AND @SportType = 43
				UNION ALL
				SELECT DISTINCT MatchID
				FROM dbo.ResultDetailES14 WITH (NOLOCK)
				WHERE SettlementStatusID > 0 AND @SportType = 43
				UNION ALL
				SELECT DISTINCT MatchID
				FROM dbo.ResultDetailOS WITH (NOLOCK)
				WHERE SettlementStatusID > 0
					AND (@SportType IN (6, 9, 45)
						OR (@SportType = 50
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
							AND ResourceID NOT LIKE '9737%'))
				UNION ALL
				SELECT DISTINCT MatchID
				FROM dbo.ResultDetailOS14 WITH (NOLOCK)
				WHERE SettlementStatusID > 0
					AND (@SportType IN (6, 9, 45)
						OR (@SportType = 50
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
							AND ResourceID NOT LIKE '9737%'))
				UNION ALL
				SELECT DISTINCT MatchID
				FROM dbo.ResultDetail3rd WITH (NOLOCK)
				WHERE SettlementStatusID > 0 AND @SportType = 193
				UNION ALL
				SELECT DISTINCT MatchID
				FROM dbo.ResultDetail3rd14 WITH (NOLOCK)
				WHERE SettlementStatusID > 0 AND @SportType = 193
				) AS R ON m.matchid = R.MatchID
		WHERE
			(l.leagueid = @LeagueId OR @LeagueId = 0)
			AND m.eventdate = @EventDate
			AND (m.eventstatus NOT IN ('internal', 'closed', 'running')
				OR (mr.IsPending = 1 AND m.eventstatus IN ('running', 'closed'))
				OR (mr.IsHTCal = 1 AND m.eventstatus = 'running')
				OR (ISNULL(R.MatchID, 0) <> 0 AND m.eventstatus = 'running'))
			AND m.sporttype NOT IN (162, 201)
			AND (m.sporttype <> 50 OR ISNULL(ChildMatchType, 0) <> 200)		-- exclude Cricket child match
			AND m.sporttype = CASE WHEN @SportType = 0 THEN m.sporttype ELSE @SportType END
			AND m.matchcode NOT LIKE '%hedge%'
			AND m.matchcode NOT LIKE '%betdaq%'
			AND m.matchcode NOT LIKE '%(LR)%'
			AND l.isTest = ISNULL(@IsShowAll, l.isTest)
			AND (l.LeagueGroupID IS NULL
				OR (l.LeagueGroupID NOT IN (SELECT LeagueGroupID FROM dbo.f_SabaVirtualSports())
					AND l.LeagueGroupID <> 215))		-- Redcat88 of Esports
		OPTION (OPTIMIZE FOR (@LeagueId = 0))
	END
	ELSE IF @SportType IN (0, 5)
	BEGIN
		IF @EventDate > @MoveBetsDay
		BEGIN
			INSERT INTO #Match
			SELECT
				l.sporttype,
				m.betstatus,
				m.leagueid,
				m.matchid,
				l.lcolor,
				m.matchcode,
				m.eventdate,
				m.globalshowtime AS kickofftime,
				m.homeid,
				m.awayid,
				m.hthomescore,
				m.htawayscore,
				m.finalhomescore,
				m.finalawayscore,
				CASE ISNULL(r.SettlementStatusID, 0)
					WHEN 1 THEN 'Refund'
					WHEN 2 THEN 'Refund HT'
					WHEN 3 THEN 'Refund FT'
					ELSE m.eventstatus
				END AS eventstatus,
				m.showtime,
				m.homeid2,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				m.goalrecord,
				ISNULL(mr.IsHTCal, 0) AS IsHTCal,
				ISNULL(mr.calculate, 0) AS calculate,
				ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
				ISNULL(mr.NoHTScore, 0) AS NoHTScore
			FROM dbo.league AS l WITH (NOLOCK)
				INNER JOIN (
					SELECT m.sporttype
						,m.betstatus
						,m.matchid
						,m.matchcode
						,m.homeid
						,m.awayid
						,m.leagueid
						,m.eventdate
						,m.eventstatus
						,m.GlobalShowTime
						,m.kickofftime
						,m.hthomescore
						,m.htawayscore
						,m.finalhomescore
						,m.finalawayscore
						,m.showtime
						,m.IsNeutral
						,m.GoalRecord
						,m.homeid2
						,m.SettlementStatus
					FROM dbo.match AS m WITH (NOLOCK)
						INNER JOIN (
								SELECT DISTINCT MatchID
								FROM dbo.ResultDetail WITH (NOLOCK)
								WHERE SettlementStatusId > 0
							) r ON r.MatchID = m.matchid
					WHERE m.eventdate = @EventDate
						AND m.sporttype = 5
						AND m.matchcode NOT LIKE '%hedge%'
						AND m.matchcode NOT LIKE '%betdaq%'
						AND m.matchcode NOT LIKE '%(LR)%'
						AND m.IsDeleted = 0
					) AS m ON m.leagueid = l.leagueid
				LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
				LEFT JOIN dbo.ResultDetail AS r WITH (NOLOCK)
					ON m.matchid = r.MatchID AND r.ResourceId = '00'
			WHERE
				(l.leagueid = @LeagueId OR @LeagueId = 0)
				AND (l.LeagueGroupID IS NULL
					OR (l.LeagueGroupID NOT IN (SELECT LeagueGroupID FROM dbo.f_SabaVirtualSports())
						AND l.LeagueGroupID <> 215))		-- Redcat88 of Esports
				AND ( m.eventstatus NOT IN ('internal', 'closed')
					OR ( mr.IsPending = 1 AND m.eventstatus IN ('running', 'closed')))
				AND l.isTest = ISNULL(@IsShowAll, l.isTest)
			OPTION (OPTIMIZE FOR (@LeagueId = 0))
		END
	ELSE
		BEGIN
			INSERT INTO #Match
			SELECT
				l.sporttype,
				m.betstatus,
				m.leagueid,
				m.matchid,
				l.lcolor,
				m.matchcode,
				m.eventdate,
				m.globalshowtime AS kickofftime,
				m.homeid,
				m.awayid,
				m.hthomescore,
				m.htawayscore,
				m.finalhomescore,
				m.finalawayscore,
				CASE ISNULL(r.SettlementStatusID, 0)
					WHEN 1 THEN 'Refund'
					WHEN 2 THEN 'Refund HT'
					WHEN 3 THEN 'Refund FT'
					ELSE m.eventstatus
				END AS eventstatus,
				m.showtime,
				m.homeid2,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				m.GoalRecord,
				ISNULL(mr.IsHTCal, 0) AS IsHTCal,
				ISNULL(mr.calculate, 0) AS calculate,
				0 AS SettlementStatus,
				ISNULL(mr.NoHTScore, 0) AS NoHTScore
			FROM dbo.League AS l WITH (NOLOCK)
				INNER JOIN (
					SELECT m.sporttype
						,m.betstatus
						,m.matchid
						,m.matchcode
						,m.homeid
						,m.awayid
						,m.leagueid
						,m.eventdate
						,m.eventstatus
						,m.globalshowtime
						,m.kickofftime
						,m.hthomescore
						,m.htawayscore
						,m.finalhomescore
						,m.finalawayscore
						,m.showtime
						,m.IsNeutral
						,m.GoalRecord
						,m.homeid2
					FROM dbo.match14 AS m WITH (NOLOCK)
						INNER JOIN (
							SELECT DISTINCT MatchID
							FROM dbo.ResultDetail14 WITH (NOLOCK)
							WHERE SettlementStatusId > 0
						) AS r ON r.MatchID = m.matchid
					WHERE m.eventdate = @EventDate
						AND m.sporttype = 5
						AND m.matchcode NOT LIKE '%hedge%'
						AND m.matchcode NOT LIKE '%betdaq%'
						AND m.matchcode NOT LIKE '%(LR)%'
					) AS m ON m.leagueid = l.leagueid
				LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
				LEFT JOIN dbo.ResultDetail14 AS r WITH (NOLOCK)
					ON m.matchid = r.MatchID AND r.ResourceId = '00'
			WHERE
				(l.leagueid = @LeagueId OR @LeagueId = 0)
				AND (l.LeagueGroupID IS NULL
					OR (l.LeagueGroupID NOT IN (SELECT LeagueGroupID FROM dbo.f_SabaVirtualSports())
						AND l.LeagueGroupID <> 215))		-- Redcat88 of Esports
				AND ( m.eventstatus NOT IN ('internal', 'closed')
					OR ( mr.IsPending = 1 AND m.eventstatus IN ('running', 'closed')))
				AND l.isTest = ISNULL(@IsShowAll, l.isTest)
			OPTION (OPTIMIZE FOR (@LeagueId = 0))
		END
	END

	-- Get data
	SELECT *
	FROM (SELECT DISTINCT * FROM #Match) AS m
	ORDER BY
		CASE WHEN m.SportType BETWEEN 180 AND 196 THEN m.KickOffTime END,
		CASE WHEN m.SportType NOT BETWEEN 180 AND 196 THEN m.EventDate END,
		CASE WHEN m.SportType NOT BETWEEN 180 AND 196 THEN m.SportType END,
		CASE WHEN m.SportType NOT BETWEEN 180 AND 196 THEN m.LeagueId END

	-- Get result detail
	DECLARE @Detail TABLE (
		MatchId				INT,
		ResourceId			VARCHAR(20),
		HomeValue			VARCHAR(50),
		AwayValue			VARCHAR(50),
		ResultStatusId		TINYINT,
		SettlementStatusId	TINYINT,
		OtherInfo			VARCHAR(2000)
	)

	IF @EventDate > @MoveBetsDay
	BEGIN
		IF @SportType IN (1, 2, 5)
		BEGIN
			INSERT INTO @Detail
			SELECT
				MatchId,
				ResourceId,
				HomeValue,
				AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetail WITH (NOLOCK)
			WHERE MatchID IN (SELECT MatchId FROM #Match)
				AND ( (@SportType = 1
						AND SettlementStatusID > 0
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
					OR (@SportType = 5
						AND SettlementStatusID > 0)
					OR (@SportType = 2
						AND (LEN(ResourceID) = 2
							OR SettlementStatusID > 0)))
		END
		ELSE IF @SportType IN (6, 9, 45, 50)		-- Volleyball, Badminton, Cricket, Beach Volleyball
		BEGIN
			INSERT INTO @Detail
			SELECT
				MatchId,
				ResourceId,
				HomeValue,
				AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetailOS WITH (NOLOCK)
			WHERE MatchID IN (SELECT MatchId FROM #Match)
				AND (LEN(ResourceID) = 2
					OR (LEN(ResourceID) = 4 AND @SportType IN (6, 9))
					OR (SettlementStatusID > 0
						AND (@SportType IN (6, 9, 45)
							OR (@SportType = 50
								AND ResourceID NOT IN ('00')
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
								AND ResourceID NOT LIKE '9491%'))))
		END
		ELSE IF @SportType = 43		-- E-Sports
		BEGIN
			INSERT INTO @Detail
			SELECT
				MatchId,
				ResourceId,
				HomeValue,
				AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetailES WITH (NOLOCK)
			WHERE MatchID IN (SELECT MatchId FROM #Match)
				AND (LEN(ResourceID) IN (2, 3) OR SettlementStatusID > 0)
		END
		ELSE IF @SportType = 193
		BEGIN
			INSERT INTO @Detail
			SELECT
				MatchId,
				ResourceId,
				Custom1 AS HomeValue,
				Custom2 AS AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetail3rd WITH (NOLOCK)
			WHERE MatchID IN (SELECT MatchId FROM #Match)
				AND SettlementStatusID > 0
		END
	END
	ELSE
	BEGIN
		IF @SportType IN (1, 2, 5)
		BEGIN
			INSERT INTO @Detail
			SELECT
				MatchId,
				ResourceId,
				HomeValue,
				AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetail14 WITH (NOLOCK)
			WHERE MatchID IN (SELECT MatchId FROM #Match)
				AND ( (@SportType = 1
						AND SettlementStatusID > 0
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
					OR (@SportType = 5
						AND SettlementStatusID > 0)
					OR (@SportType = 2
						AND (LEN(ResourceID) = 2
							OR SettlementStatusID > 0)))
		END
		ELSE IF @SportType IN (6, 9, 45, 50)		-- Volleyball, Badminton, Cricket, Beach Volleyball
		BEGIN
			INSERT INTO @Detail
			SELECT
				MatchId,
				ResourceId,
				HomeValue,
				AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetailOS14 WITH (NOLOCK)
			WHERE MatchID IN (SELECT MatchId FROM #Match)
				AND (LEN(ResourceID) = 2
					OR (LEN(ResourceID) = 4 AND @SportType IN (6, 9))
					OR (SettlementStatusID > 0
						AND (@SportType IN (6, 9, 45)
							OR (@SportType = 50
								AND ResourceID NOT IN ('00')
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
								AND ResourceID NOT LIKE '9491%'))))
		END
		ELSE IF @SportType = 43		-- E-Sports
		BEGIN
			INSERT INTO @Detail
			SELECT
				MatchId,
				ResourceId,
				HomeValue,
				AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetailES14 WITH (NOLOCK)
			WHERE MatchID IN (SELECT MatchId FROM #Match)
				AND (LEN(ResourceID) IN (2, 3) OR SettlementStatusID > 0)
		END
		ELSE IF @SportType = 193
		BEGIN
			INSERT INTO @Detail
			SELECT
				MatchId,
				ResourceId,
				Custom1 AS HomeValue,
				Custom2 AS AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetail3rd14 WITH (NOLOCK)
			WHERE MatchID IN (SELECT MatchId FROM #Match)
				AND SettlementStatusID > 0
		END
	END

	SELECT * FROM @Detail
	ORDER BY MatchId ASC,
		ResourceId ASC

	DROP TABLE #Match
END
GO
