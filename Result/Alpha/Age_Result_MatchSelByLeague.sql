/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_Result_MatchSelByLeague]
	@FromDate		DATETIME,
	@MoveBetsDay	DATETIME,
	@LeagueId		INT,
	@SportType		SMALLINT	= 0,
	@IsShowAll		BIT			= 1,	-- 1: Show All; 0: is NOT show Test
	@CustId			INT			= 0
AS

/*
	Task: Alpha Result Report - Load match list
	DB: DBAGE.bodb02
	Original: MatchSelResultByLeague
	Revisions:
		- 20101207@Simon: Show All League or only show Live belong to @isShowAll
		- 20110401@Henry: Not show BetDaq's match in result page
		- 20110907@Sophia: Add column IsPending for PENDing Status
		- 20111003@Sophia: Add column IsPending PENDing Status.
						- Edit condition OR to show the rows which have eventstatus IN ('running','closed')
		- 20120907@Sophia: Get homeid2 (it contains bettype of Live Casino)
		- 20130712@Kathy: Amend the result page to sort Virtual Soccer matches by kick off time
		- 20130805@Lukas: Hide Live Casino Game
		- 20131010@Kathy: Turn to use GlobalShowTime for display the Kick-off-Time [redmine:#6076]
		- 20141008@Sophia: Get result detail of Tennis sport, add param @MoveBetsDay
		- 20141218@Sophia: Not to use Betstatus to get REFUND status of Tennis anymore
		- 20140407@Sophia: Support BetRadar and revise code
		- 20150416@Sophia: Condition of showing Running match different between Sporting solution and BetRadar 
						  (Remark: because of the rush deadline, so we will merge code of Sporting solution and Bet radar later since they use the ResultDetail table also)
		- 20150810@Sophia: Hardcode to exclude ResultDetail of bettype 216, 217 for a temporary time [#40991]
		- 20151014@Sophia: Show internal match [#45531]
		- 20160526@Francis: Revise SP to avoid bad parameter sniffing on LeagueID using optimize for
		- 20161021@Kos: Exclude Fast Market result [#Redmine: 56589]
		- 20170117@Kos: Support new result status Abandoned 1H/2H [#Redmine: 70410]
		- 20170405@Kos: Support Basketball AIO [#Redmine: 73033]
		- 20170616@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20171012@Kos: Support PH AIO Phase 3 [Redmine: #82403]
		- 20180320@Kos: Exclude Fast Market 2 [Redmine: #90708]
		- 20180410@Kos: Support Betradar Virtual Basketball [Redmine: #90616]
		- 20181003@Kos: Support new status Result Pending and Under Settlement [#Redmine: 101949]
					- Move eventstatus data transform to web (no change for Tennis)
		- 20181122@Kos: Support E-Sports phase 2 [Redmine: #101047]
		- 20190805@Kos: Support PH AIO 4b [Redmine: #115235]
					- Change for "Next Goal" [Redmine: #115235]
		- 20191014@Kos: Support Badminton AIO phase 2 [Redmine: #120381]
		- 20191204@Kos: Show Instant Calculation Result for Corner Bettypes [Redmine: #124682]
		- 20200515@Kos: Support PH AIO phase 5.1 [Redmine: #132770]
		- 20201006@Razor: Support Time Machine Over/Under [Redmine: #141998]
*/

BEGIN
	SET NOCOUNT ON

	SELECT @IsShowAll = CASE @IsShowAll WHEN 1 THEN NULL ELSE 0 END

	DECLARE @EventDate DATE

	SELECT @EventDate = @FromDate

	DECLARE @Site VARCHAR(50)

	IF @CustId <> 0
	BEGIN
		SELECT @Site = site
		FROM dbo.customer WITH (NOLOCK)
		WHERE custid = @CustId
	END

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
		SettlementStatus	TINYINT)

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
			m.globalshowtime AS kickofftime,
			m.homeid,
			m.awayid,
			m.hthomescore,
			m.htawayscore,
			m.finalhomescore,
			m.finalawayscore,
			m.eventstatus,
			m.showtime,
			m.homeid2,
			ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
			m.goalrecord,
			ISNULL(mr.IsHTCal, 0) AS IsHTCal,
			ISNULL(mr.calculate, 0) AS calculate,
			ISNULL(m.SettlementStatus, 0) AS SettlementStatus
		FROM
			dbo.league AS l WITH (NOLOCK)
			INNER JOIN
				( SELECT sporttype, betstatus, matchid, matchcode, homeid, awayid, leagueid, eventdate, eventstatus,
					GlobalShowTime, kickofftime, hthomescore, htawayscore, finalhomescore, finalawayscore, showtime,
					isneutral, goalrecord, homeid2, SettlementStatus
				FROM dbo.match WITH (NOLOCK)
				UNION ALL
				SELECT sporttype, betstatus, matchid, matchcode, homeid, awayid, leagueid, eventdate, eventstatus,
					GlobalShowTime, kickofftime, hthomescore, htawayscore, finalhomescore, finalawayscore, showtime,
					isneutral, goalrecord, homeid2, 0 AS SettlementStatus
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
								AND ResourceID NOT LIKE '486%'
								AND ResourceID NOT LIKE '487%')
							OR @SportType = 2)
					UNION ALL
					SELECT DISTINCT MatchID
					FROM dbo.ResultDetailOS WITH (NOLOCK)
					WHERE SettlementStatusID > 0 AND @SportType = 9
					UNION ALL
					SELECT DISTINCT MatchID
					FROM dbo.ResultDetailOS14 WITH (NOLOCK)
					WHERE SettlementStatusID > 0 AND @SportType = 9
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
					FROM dbo.ResultDetail3rd WITH (NOLOCK)
					WHERE SettlementStatusID > 0 AND @SportType = 193
					UNION ALL
					SELECT DISTINCT MatchID
					FROM dbo.ResultDetail3rd14 WITH (NOLOCK)
					WHERE SettlementStatusID > 0 AND @SportType = 193
				) r ON m.matchid = r.MatchId
		WHERE
			(l.leagueid = @LeagueId OR @LeagueId = 0)
			AND m.eventdate = @EventDate
			AND (m.eventstatus NOT IN ('closed', 'running')
				OR ( mr.IsPending = 1 AND m.eventstatus IN ('running', 'closed') )
				OR ( mr.IsHTCal = 1 AND m.eventstatus = 'running')
				OR ( ISNULL(r.MatchID, 0) <> 0 AND m.eventstatus = 'running'))
			AND m.sporttype NOT IN (201, 162)
			AND m.sporttype = CASE WHEN @SportType = 0 THEN m.sporttype ELSE @SportType END
			AND m.matchcode NOT LIKE '%hedge%'
			AND m.matchcode NOT LIKE '%betdaq%'
			AND (ISNULL(@Site, '') = '789y'
				OR (m.matchcode NOT LIKE '%(LR)%' AND ISNULL(@Site, '') <> '789y'))
			AND l.isTest = ISNULL(@IsShowAll, l.isTest)
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
				m.GlobalShowTime AS kickofftime,
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
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				m.goalrecord,
				ISNULL(mr.IsHTCal, 0) AS IsHTCal,
				ISNULL(mr.calculate, 0) AS calculate,
				ISNULL(m.SettlementStatus, 0) AS SettlementStatus
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
							AND (ISNULL(@Site, '') = '789y'
								OR (m.matchcode NOT LIKE '%(LR)%' AND ISNULL(@Site, '') <> '789y'))
					) AS m ON m.leagueid = l.leagueid
				LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
				LEFT JOIN dbo.ResultDetail AS r WITH (NOLOCK)
					ON m.matchid = r.MatchID AND r.ResourceId = '00'
			WHERE
				(l.leagueid = @LeagueId OR @LeagueId = 0)
				AND ( m.eventstatus NOT IN ('closed')
					OR ( mr.IsPending = 1
						AND m.eventstatus IN ('running', 'closed')))
				AND l.isTest = ISNULL(@IsShowAll, l.isTest)
			--ORDER BY m.eventdate , m.sporttype , m.leagueid
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
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				m.goalrecord,
				ISNULL(mr.IsHTCal, 0) AS IsHTCal,
				ISNULL(mr.calculate, 0) AS calculate,
				0 AS SettlementStatus
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
							) r ON r.MatchId = m.MatchId
						WHERE m.EventDate = @EventDate
							AND m.sporttype = 5
							AND m.matchcode NOT LIKE '%hedge%'
							AND m.matchcode NOT LIKE '%betdaq%'
							AND (ISNULL(@Site, '') = '789y'
								OR (m.matchcode NOT LIKE '%(LR)%' AND ISNULL(@Site, '') <> '789y'))
					) AS m ON m.leagueid = l.leagueid
				LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
				LEFT JOIN dbo.ResultDetail14 AS r WITH (NOLOCK)
					ON m.matchid = r.MatchID AND r.ResourceId = '00'
			WHERE
				(l.leagueid = @LeagueId OR @LeagueId = 0)
				AND ( m.eventstatus NOT IN ('closed')
					OR ( mr.IsPending = 1
						AND m.eventstatus IN ('running', 'closed')))
				AND l.isTest = ISNULL(@IsShowAll, l.isTest)
			--ORDER BY m.eventdate , m.sporttype , m.leagueid
			OPTION (OPTIMIZE FOR (@LeagueId = 0))
		END
	END

	-- Get data
	SELECT *
	FROM (SELECT DISTINCT * FROM #Match) AS m
	ORDER BY
		CASE WHEN SportType BETWEEN 180 AND 196 THEN KickOffTime END,
		CASE WHEN SportType NOT BETWEEN 180 AND 196 THEN EventDate END,
		CASE WHEN SportType NOT BETWEEN 180 AND 196 THEN SportType END,
		CASE WHEN SportType NOT BETWEEN 180 AND 196 THEN LeagueId END

	-- Get result detail
	DECLARE @Detail TABLE (
		MatchId				INT,
		ResourceId			VARCHAR(20),
		HomeValue			VARCHAR(50),
		AwayValue			VARCHAR(50),
		ResultStatusId		TINYINT,
		SettlementStatusId	TINYINT,
		OtherInfo			VARCHAR(50)
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
						AND ResourceID NOT LIKE '486%'
						AND ResourceID NOT LIKE '487%')
					OR (@SportType = 5
						AND SettlementStatusID > 0)
					OR (@SportType = 2
						AND (LEN(ResourceID) = 2
							OR SettlementStatusID > 0)))
			ORDER BY MatchID ASC,
				ResourceId ASC
		END
		ELSE IF @SportType = 9		-- Badminton
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
				AND (LEN(ResourceID) IN (2, 4) OR SettlementStatusID > 0)
			ORDER BY MatchID ASC,
				ResourceId ASC
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
				AND (LEN(ResourceID) = 2 OR SettlementStatusID > 0)
			ORDER BY MatchID ASC,
				ResourceId ASC
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
			ORDER BY MatchID ASC,
				ResourceId ASC
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
						AND ResourceID NOT LIKE '486%'
						AND ResourceID NOT LIKE '487%')
					OR (@SportType = 5
						AND SettlementStatusID > 0)
					OR (@SportType = 2
						AND (LEN(ResourceID) = 2
							OR SettlementStatusID > 0)))
			ORDER BY MatchID ASC,
				ResourceId ASC
		END
		ELSE IF @SportType = 9		-- Badminton
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
				AND (LEN(ResourceID) IN (2, 4) OR SettlementStatusID > 0)
			ORDER BY MatchID ASC,
				ResourceId ASC
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
				AND (LEN(ResourceID) = 2 OR SettlementStatusID > 0)
			ORDER BY MatchID ASC,
				ResourceId ASC
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
			ORDER BY MatchID ASC,
				ResourceId ASC
		END
	END

	SELECT * FROM @Detail

	DROP TABLE #Match
END




GO
GRANT EXECUTE ON [dbo].[Age_Result_MatchSelByLeague] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_Result_MatchSelByLeague] TO [bodbDownlineNetView] AS [dbo]
GO
