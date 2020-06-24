/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Result_LeagueSelByDate]
	@EventDate		DATETIME,
	@MoveBetsDay	DATETIME,
	@SportType		SMALLINT	= 0,
	@IsShowAll		BIT			= 1 -- 1: Show All; 0: is NOT show Test
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
*/

BEGIN
	SET NOCOUNT ON

	SELECT @IsShowAll = CASE @IsShowAll WHEN 1 THEN NULL ELSE 0 END

	IF @EventDate > @MoveBetsDay
	BEGIN
		IF @SportType NOT IN (181, 182, 183, 184, 185, 193)
		BEGIN
			SELECT DISTINCT
				l.leaguename,
				l.leagueid,
				@EventDate,
				m.sporttype
			FROM (
					SELECT DISTINCT m.leagueid,
						m.sporttype
					FROM dbo.match AS m WITH (NOLOCK)
						LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid + 1 = mr.matchid + 1
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
											AND ResourceID NOT LIKE '486%'
											AND ResourceID NOT LIKE '487%')
										OR @SportType IN (2, 5))
							) AS r ON m.matchid + 1 = r.MatchID + 1
						LEFT JOIN (
								SELECT DISTINCT MatchID
								FROM dbo.ResultDetailES WITH (NOLOCK)
								WHERE SettlementStatusID > 0 AND @SportType = 43
							) AS e ON m.matchid + 1 = e.MatchID + 1
						LEFT JOIN (
								SELECT DISTINCT MatchID
								FROM dbo.ResultDetailOS WITH (NOLOCK)
								WHERE SettlementStatusID > 0 AND @SportType = 9
							) AS o ON o.MatchID + 1 = m.matchid + 1
					WHERE m.eventdate = @EventDate
						AND m.sporttype NOT IN (162, 201)
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
			WHERE l.isTest = ISNULL(@IsShowAll, l.isTest)
			ORDER BY m.sporttype ASC,
				l.leaguename ASC
		END
		ELSE IF @SportType = 193
		BEGIN
			SELECT DISTINCT
				l.leaguename,
				l.leagueid,
				@EventDate,
				@SportType
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
							AND (m.eventstatus NOT IN ('closed', 'running')
								OR (ISNULL(r.MatchID, 0) <> 0 AND m.eventstatus = 'running'))
					) o ON l.leagueid = o.leagueid 
			WHERE l.sporttype = @SportType
				AND l.isTest = ISNULL(@IsShowAll, l.isTest)
		END
		ELSE IF @SportType IN (181, 182, 184, 183, 185)
		BEGIN
			SELECT DISTINCT
				l.leaguename,
				l.leagueid,
				@EventDate,
				@SportType
			FROM dbo.League AS l WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON l.leagueid = r.LeagueID
				INNER JOIN (
						SELECT DISTINCT EventID
						FROM dbo.VSOutright WITH (NOLOCK)
						WHERE EventDate = @EventDate
					) o ON r.EventID = o.EventID
			WHERE r.EventStatus ='completed'
				AND r.sporttype = @SportType
				AND l.isTest = ISNULL(@IsShowAll, l.isTest)
		END
	END
	ELSE
	BEGIN
		IF @SportType NOT IN (181, 182, 183, 184, 185, 193)
		BEGIN
			SELECT DISTINCT
				l.leaguename,
				l.leagueid,
				@EventDate,
				m.sporttype
			FROM (
					SELECT DISTINCT m.leagueid,
						m.sporttype
					FROM dbo.match14 AS m WITH (NOLOCK)
						LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
						LEFT JOIN (
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
											AND ResourceID NOT LIKE '486%'
											AND ResourceID NOT LIKE '487%')
										OR @SportType IN (2, 5))
							) AS r ON m.matchid = r.MatchID
						LEFT JOIN (
								SELECT DISTINCT MatchID
								FROM dbo.ResultDetailES14 WITH (NOLOCK)
								WHERE SettlementStatusID > 0 AND @SportType = 43
							) AS e ON m.matchid + 1 = e.MatchID + 1
						LEFT JOIN (
								SELECT DISTINCT MatchID
								FROM dbo.ResultDetailOS14 WITH (NOLOCK)
								WHERE SettlementStatusID > 0 AND @SportType = 9
							) AS o ON o.MatchID + 1 = m.matchid + 1
					WHERE m.eventdate = @EventDate
						AND m.sporttype NOT IN (162, 201)
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
			WHERE l.isTest = ISNULL(@IsShowAll, l.isTest)
			ORDER BY m.sporttype ASC,
				l.leaguename ASC
		END
		ELSE IF @SportType = 193
		BEGIN
			SELECT DISTINCT
				l.leaguename,
				l.leagueid,
				@EventDate,
				@SportType
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
				AND l.isTest = ISNULL(@IsShowAll, l.isTest)
		END
		ELSE IF @SportType IN (181, 182, 184, 183, 185)
		BEGIN
			SELECT DISTINCT
				l.leaguename,
				l.leagueid,
				@EventDate,
				@SportType
			FROM dbo.League AS l WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo14 AS r WITH (NOLOCK) ON l.leagueid = r.LeagueID
				INNER JOIN dbo.VSOutright14 AS o WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.EventDate = @EventDate
				AND r.EventStatus ='completed'
				AND r.sporttype = @SportType
				AND l.isTest = ISNULL(@IsShowAll, l.isTest)
		END
	END
END
GO



GRANT	EXECUTE	ON	Lrf_Result_LeagueSelByDate	TO	bodbLicenseeNet
GO
