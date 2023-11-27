/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_Result_SportSelByDate]
	@EventDate		SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@IsShowAll		BIT			= 0
AS

/*
	Created:
	Task: Alpha Result Report - Load Sport dropdownlist
	DB: DBAGE.bodb02

	Revision:
		- 20110307@Lukas: Get more sporttype 152, 153
		- 20110908@Sophia: Add Condition Where : OR (eventstatus = 'running' AND (mr.ishtcal=1 OR mr.calculate=1))
		- 20111003@Sophia: Edit condition OR to show the row which have eventstatus IN ('running','closed')
		- 20130712@Kathy: Hide sporttype in the "Sport" dropdown list since these sports have not launched yet
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
		- 20171012@Kos: Support PH AIO Phase 3 [Redmine: #82403]
		- 20171219@Sophia: Enhance performance [Redmine: #88410]
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
		- 20220310@Razor: Support Cricket AIO 2 [Redmine: #166334]
		- 20220310@Razor: Support In-house Replication [Redmine: #164321]
		- 20220510@Razor: Remove In-house Replication [Redmine: #171699]
		- 20220711@Razor: Support Volleyball AIO [Redmine: #173861]
		- 20231127@Kos: Hide Saba Virtual Sports leagues [Redmine: #197469]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @MatchDate DATETIME

	SELECT @MatchDate = @EventDate

	IF @EventDate > @MoveBetsDay
	BEGIN
		SELECT DISTINCT
			s.SportType,
			s.SportName
		FROM dbo.Sports AS s WITH (NOLOCK)
			INNER JOIN (
					-- #1. From Match Table
					SELECT m.sporttype
					FROM dbo.match AS m WITH (NOLOCK)
					WHERE m.EventDate = @MatchDate
						AND m.sporttype NOT IN (201, 162)
						AND (m.sporttype <> 50 OR ISNULL(ChildMatchType, 0) <> 200)		-- exclude Cricket child match
						AND (
								m.eventstatus NOT IN ('closed', 'running')
								OR EXISTS (	SELECT 1
											FROM dbo.match_remark AS mr WITH (NOLOCK)
											WHERE m.matchid = mr.matchid
												AND (
														( mr.IsPending = 1 AND m.eventstatus IN ('running', 'closed') )
														OR ( mr.IsHTCal = 1 AND m.eventstatus = 'running')
													)
										)
								OR EXISTS (	SELECT 1
											FROM dbo.ResultDetail AS SS WITH (NOLOCK)
											WHERE SS.SettlementStatusID > 0
												AND m.matchid = SS.MatchId
												AND m.sporttype IN (2, 5)		-- Basketball, Tennis
												AND ( ISNULL(SS.MatchID, 0) <> 0 AND m.eventstatus = 'running')
											)
								OR EXISTS (	SELECT 1
											FROM dbo.ResultDetail AS BR WITH (NOLOCK)
											WHERE BR.SettlementStatusID > 0
												AND (BR.ResourceID NOT IN ('08', '09')
													OR BR.HomeValue LIKE '%a%'
													OR BR.HomeValue LIKE '%h%')
												AND BR.ResourceID NOT IN ('00', '01', '04', '05', '14F', '14L', '127F', '127L', '135', '168', '173', '174', '175', '176', 
													'192', '193', '206', '207', '208', '209', '210', '211', '212', '213', '214', '215', '488', '489', '490', '376')
												AND BR.ResourceID NOT LIKE '160%'
												AND BR.ResourceID NOT LIKE '164%'
												AND BR.ResourceID NOT LIKE '169%'
												AND BR.ResourceID NOT LIKE '180%'
												AND BR.ResourceID NOT LIKE '216%'
												AND BR.ResourceID NOT LIKE '217%'
												AND BR.ResourceID NOT LIKE '221%'
												AND BR.ResourceID NOT LIKE '222%'
												AND BR.ResourceID NOT LIKE '223%'
												AND BR.ResourceID NOT LIKE '224%'
												AND BR.ResourceID NOT LIKE '225%'
												AND BR.ResourceID NOT LIKE '226%'
												AND BR.ResourceID NOT LIKE '227%'
												AND BR.ResourceID NOT LIKE '228%'
												AND BR.ResourceID NOT LIKE '229%'
												AND BR.ResourceID NOT LIKE '486%'
												AND BR.ResourceID NOT LIKE '487%'
												AND ( ISNULL(BR.MatchID, 0) <> 0 AND m.eventstatus = 'running')
												AND m.matchid = BR.MatchId
											)
								OR EXISTS (	SELECT 1
											FROM dbo.ResultDetailOS AS o WITH (NOLOCK)
											WHERE o.SettlementStatusID > 0
												AND m.matchid = o.MatchId
												AND (m.sporttype IN (6, 9, 45)		-- Volleyball, Badminton, Beach Volleyball
													OR (m.sporttype = 50	-- Cricket
														AND o.ResourceID IN ('H1', 'H2', 'A1', 'A2', '9400', '9401', '9442', '9443', '9446', '9447', '9450', '9449', '9452', '9453', '94511', '96151')))
												AND ( ISNULL(o.MatchID, 0) <> 0 AND m.eventstatus = 'running')
											)
								OR EXISTS (	SELECT 1
											FROM dbo.ResultDetailES AS e WITH (NOLOCK)
											WHERE e.SettlementStatusID > 0
												AND m.matchid = e.MatchId
												AND m.sporttype = 43		-- E-Sports
												AND ( ISNULL(e.MatchID, 0) <> 0 AND m.eventstatus = 'running')
											)
								OR EXISTS (	SELECT 1
											FROM dbo.ResultDetail3rd AS r WITH (NOLOCK)
											WHERE r.SettlementStatusID > 0
												AND m.matchid = r.MatchID
												AND m.sporttype = 193 )
							)
						AND EXISTS ( SELECT 1
									FROM dbo.League AS l WITH (NOLOCK)
									WHERE l.leagueid = m.leagueid
										AND l.isTest = CASE WHEN @IsShowAll = 1 THEN l.isTest ELSE @IsShowAll END
										AND (l.LeagueGroupID IS NULL
											OR l.LeagueGroupID NOT IN (SELECT LeagueGroupID FROM dbo.f_SabaVirtualSports()))
									)

					UNION ALL

					-- #2. From outright table
					SELECT l.sporttype
					FROM dbo.League AS l WITH (NOLOCK)
					WHERE EXISTS (	SELECT 1
									FROM dbo.VSOutright AS o WITH (NOLOCK)
										INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON o.EventID = r.EventID
									WHERE o.EventDate = @EventDate
										AND r.EventStatus = 'completed'
										AND r.LeagueID = l.leagueid
									)
						AND l.sporttype IN (181, 182, 183, 185, 184)
						AND l.isTest = CASE WHEN @IsShowAll = 1 THEN l.isTest ELSE @IsShowAll END

					UNION ALL
					
					-- #3. From Match3rd table
					SELECT m.SportType
					FROM dbo.Match3rd AS m WITH (NOLOCK)
					WHERE m.EventDate = @MatchDate
						AND m.EventStatus IN ('completed')
			) AS t
			ON s.SportType = t.sporttype
		ORDER BY s.SportType ASC,
			s.SportName ASC
	END
	ELSE
	BEGIN
		SELECT DISTINCT
			s.SportType,
			s.SportName
		FROM dbo.Sports AS s WITH (NOLOCK)
			INNER JOIN (
					-- #1. From Match Table
					SELECT m.sporttype
					FROM dbo.match14 AS m WITH (NOLOCK)
					WHERE m.EventDate = @MatchDate
						AND m.sporttype NOT IN (201, 162)
						AND (m.sporttype <> 50 OR ISNULL(ChildMatchType, 0) <> 200)		-- exclude Cricket child match
						AND (
							m.eventstatus NOT IN ('closed', 'running')
							OR EXISTS (	SELECT 1
										FROM dbo.match_remark AS mr WITH (NOLOCK) 
										WHERE m.matchid = mr.matchid
											AND (
													( mr.IsPending = 1 AND m.eventstatus IN ('running', 'closed') )
													OR ( mr.IsHTCal = 1 AND m.eventstatus = 'running')
												)
										)
							OR EXISTS (	SELECT 1
										FROM dbo.ResultDetail14 AS SS WITH (NOLOCK)
										WHERE SS.SettlementStatusID > 0
											AND m.matchid = SS.MatchId
											AND m.sporttype IN (2, 5)		-- Basketball, Tennis
											AND ( ISNULL(SS.MatchID, 0) <> 0 AND m.eventstatus = 'running')
										)
							OR EXISTS (	SELECT 1
										FROM dbo.ResultDetail14 AS BR WITH (NOLOCK)
										WHERE BR.SettlementStatusID > 0
												AND (BR.ResourceID NOT IN ('08', '09')
													OR BR.HomeValue LIKE '%a%'
													OR BR.HomeValue LIKE '%h%')
												AND BR.ResourceID NOT IN ('00', '01', '04', '05', '14F', '14L', '127F', '127L', '135', '168', '173', '174', '175', '176', 
													'192', '193', '206', '207', '208', '209', '210', '211', '212', '213', '214', '215', '488', '489', '490', '376')
												AND BR.ResourceID NOT LIKE '160%'
												AND BR.ResourceID NOT LIKE '164%'
												AND BR.ResourceID NOT LIKE '169%'
												AND BR.ResourceID NOT LIKE '180%'
												AND BR.ResourceID NOT LIKE '216%'
												AND BR.ResourceID NOT LIKE '217%'
												AND BR.ResourceID NOT LIKE '221%'
												AND BR.ResourceID NOT LIKE '222%'
												AND BR.ResourceID NOT LIKE '223%'
												AND BR.ResourceID NOT LIKE '224%'
												AND BR.ResourceID NOT LIKE '225%'
												AND BR.ResourceID NOT LIKE '226%'
												AND BR.ResourceID NOT LIKE '227%'
												AND BR.ResourceID NOT LIKE '228%'
												AND BR.ResourceID NOT LIKE '229%'
												AND BR.ResourceID NOT LIKE '486%'
												AND BR.ResourceID NOT LIKE '487%'
											AND ( ISNULL(BR.MatchID, 0) <> 0 AND m.eventstatus = 'running')
											AND m.matchid = BR.MatchId
										)
							OR EXISTS (	SELECT 1
											FROM dbo.ResultDetailOS14 AS o WITH (NOLOCK)
											WHERE o.SettlementStatusID > 0
												AND m.matchid = o.MatchId
												AND (m.sporttype IN (6, 9, 45)		-- Volleyball, Badminton, Beach Volleyball
													OR (m.sporttype = 50	-- Cricket
														AND o.ResourceID IN ('H1', 'H2', 'A1', 'A2', '9400', '9401', '9442', '9443', '9446', '9447', '9450', '9449', '9452', '9453', '94511', '96151')))
												AND ( ISNULL(o.MatchID, 0) <> 0 AND m.eventstatus = 'running')
											)
							OR EXISTS (	SELECT 1
										FROM dbo.ResultDetailES14 AS e WITH (NOLOCK)
										WHERE e.SettlementStatusID > 0
											AND m.matchid = e.MatchId
											AND m.sporttype = 43		-- E-Sports
											AND ( ISNULL(e.MatchID, 0) <> 0 AND m.eventstatus = 'running')
										)
							OR EXISTS (	SELECT 1
										FROM dbo.ResultDetail3rd14 AS r WITH (NOLOCK)
										WHERE r.SettlementStatusID > 0
											AND m.matchid = r.MatchID
											AND m.sporttype = 193 )
						)
						AND EXISTS ( 	SELECT 1
										FROM dbo.League AS l WITH (NOLOCK)
										WHERE l.leagueid = m.leagueid
											AND l.isTest = CASE WHEN @IsShowAll = 1 THEN l.isTest ELSE @IsShowAll END
											AND (l.LeagueGroupID IS NULL
												OR l.LeagueGroupID NOT IN (SELECT LeagueGroupID FROM dbo.f_SabaVirtualSports()))
									)

					UNION ALL

					-- #2. From outright table
					SELECT l.sporttype
					FROM dbo.League AS l WITH (NOLOCK)
					WHERE EXISTS (	SELECT 1
									FROM dbo.VSOutright14 AS o WITH (NOLOCK)
										INNER JOIN dbo.VSRaceInfo14 AS r WITH (NOLOCK) ON o.EventID = r.EventID
									WHERE o.EventDate = @EventDate
										AND r.EventStatus = 'completed'
										AND r.LeagueID = l.leagueid
									)
						AND l.sporttype IN (181, 182, 183, 185, 184)
						AND l.isTest = CASE WHEN @IsShowAll = 1 THEN l.isTest ELSE @IsShowAll END

					UNION ALL

					-- #3. From Match3rd table
					SELECT m.SportType
					FROM dbo.Match3rd14 AS m WITH (NOLOCK)
					WHERE m.EventDate = @MatchDate
						AND m.EventStatus IN ('completed')
			) t
			ON s.SportType = t.sporttype
		ORDER BY s.SportType ASC,
			s.SportName ASC
	END
END
GO
