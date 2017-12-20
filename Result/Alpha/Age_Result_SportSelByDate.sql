ALTER PROCEDURE [dbo].[Age_Result_SportSelByDate]
	@EventDate		SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@IsShowAll		BIT			= 0
AS

/*
	Created:
	Task:
	DB: DBAGE.bodb02
	Original:
	Revision:
		- 20110307@Lukas: Get more sporttype 152, 153
		- 20110908@Sophia: Add Condition Where : OR (eventstatus = 'running' AND (mr.ishtcal=1 OR mr.calculate=1))
		- 20111003@Sophia: Edit condition OR to show the row which have eventstatus IN ('running','closed')
		- 20130712@Kathy: Hide sporttype in the "Sport" dropdown list since these sports have not launched yet.
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
*/

BEGIN
	SET NOCOUNT ON
	 
	DECLARE @MatchDate DATETIME
	SELECT @MatchDate = @EventDate

	IF @EventDate > @MoveBetsDay
	BEGIN 	
			SELECT DISTINCT s.SportType, s.SportName 
			FROM dbo.Sports s WITH (NOLOCK)
			INNER JOIN ( 
	 
					--- #1. From Match Table 
					SELECT	m.sporttype
					FROM	dbo.match m WITH (NOLOCK)
					WHERE   m.EventDate = @MatchDate	
							AND m.sporttype NOT IN (201, 162)	
							AND (  
									m.eventstatus NOT IN ('closed', 'running')
									OR EXISTS (	SELECT	1
												FROM	dbo.match_remark AS mr WITH (NOLOCK) 
												WHERE	m.matchid = mr.matchid
														AND (
																( mr.IsPending = 1 AND m.eventstatus IN ('running', 'closed') )
																OR ( mr.IsHTCal = 1 AND m.eventstatus = 'running')
															)
											   )
									OR EXISTS (	SELECT 1
												FROM dbo.ResultDetail SS WITH (NOLOCK)
												WHERE SettlementStatusID > 0
													AND m.matchid = SS.MatchId AND m.sporttype IN (2, 5)
													AND ( ISNULL(SS.MatchID, 0) <> 0 AND m.eventstatus = 'running')
												)
									OR EXISTS (	SELECT 1
												FROM dbo.ResultDetail BR WITH (NOLOCK)
												WHERE SettlementStatusID > 0
													AND (ResourceID NOT IN ('00', '01', '08', '14F', '14L', '127F', '127L')
														OR (ResourceID = '08'
															AND (HomeValue LIKE '%a%' OR HomeValue LIKE '%h%')))
													AND ResourceID NOT LIKE '217%'
													AND ResourceID NOT LIKE '216%'
													AND ResourceID NOT LIKE '221%'
													AND ResourceID NOT LIKE '222%'
													AND ResourceID NOT LIKE '223%'
													AND ResourceID NOT LIKE '224%'
													AND ResourceID NOT LIKE '225%'	
													AND ( ISNULL(BR.MatchID, 0) <> 0 AND m.eventstatus = 'running')
													AND m.matchid = BR.MatchId
												)
								)	
							AND EXISTS ( 	SELECT 1
											FROM dbo.League l WITH (NOLOCK)
											WHERE l.leagueid = m.leagueid
												  AND l.isTest = CASE WHEN @IsShowAll = 1 THEN l.isTest ELSE @IsShowAll END 

										)
		
					UNION ALL

					 --- #2. From outright table  
					SELECT l.sporttype
					FROM dbo.league AS l WITH (NOLOCK)
					WHERE EXISTS (	SELECT 1
									FROM dbo.outright o WITH (NOLOCK)
									WHERE o.eventdate = @EventDate 
										AND o.oddsstatus = 'completed'	
										AND o.leagueid =  l.leagueid				
									)  
						AND l.sporttype BETWEEN 151 AND 153 
						AND l.isTest = CASE WHEN @IsShowAll = 1 THEN l.isTest ELSE @IsShowAll END 

					UNION ALL

					--- #3. From outright table 

					SELECT l.sporttype
					FROM dbo.league AS l WITH (NOLOCK)
					WHERE EXISTS (	SELECT 1
									FROM dbo.VSOutright AS o WITH (NOLOCK)
										INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON o.EventID = r.EventID
									WHERE o.EventDate = @EventDate 
										AND r.eventstatus = 'completed'	
										AND r.leagueid = l.leagueid
									)
						AND l.sporttype IN (181, 182, 183, 185, 184)
						AND l.isTest = CASE WHEN @IsShowAll = 1 THEN l.isTest ELSE @IsShowAll END 
			 
			  ) t
			  ON s.Sporttype = t.Sporttype
		ORDER BY s.SportType, s.SportName
		
	END 
	ELSE 
	BEGIN 
			SELECT DISTINCT s.SportType, s.SportName 
			FROM dbo.Sports s WITH (NOLOCK)
			INNER JOIN ( 	 
					--- #1. From Match Table 
					SELECT	m.sporttype
					FROM	dbo.match14 m WITH (NOLOCK)
					WHERE   m.EventDate = @MatchDate	
							AND m.sporttype NOT IN (201, 162)	
							AND (  
									m.eventstatus NOT IN ('closed', 'running')
									OR EXISTS (	SELECT	1
												FROM	dbo.match_remark AS mr WITH (NOLOCK) 
												WHERE	m.matchid = mr.matchid
														AND (
																( mr.IsPending = 1 AND m.eventstatus IN ('running', 'closed') )
																OR ( mr.IsHTCal = 1 AND m.eventstatus = 'running')
															)
											   )
									OR EXISTS (	SELECT 1
												FROM dbo.ResultDetail14 SS WITH (NOLOCK)
												WHERE SettlementStatusID > 0
													AND m.matchid = SS.MatchId AND m.sporttype IN (2, 5)
													AND ( ISNULL(SS.MatchID, 0) <> 0 AND m.eventstatus = 'running')
												)
									OR EXISTS (	SELECT 1
												FROM dbo.ResultDetail14 BR WITH (NOLOCK)
												WHERE SettlementStatusID > 0
													AND (ResourceID NOT IN ('00', '01', '08', '14F', '14L', '127F', '127L')
														OR (ResourceID = '08'
															AND (HomeValue LIKE '%a%' OR HomeValue LIKE '%h%')))
													AND ResourceID NOT LIKE '217%'
													AND ResourceID NOT LIKE '216%'
													AND ResourceID NOT LIKE '221%'
													AND ResourceID NOT LIKE '222%'
													AND ResourceID NOT LIKE '223%'
													AND ResourceID NOT LIKE '224%'
													AND ResourceID NOT LIKE '225%'	
													AND ( ISNULL(BR.MatchID, 0) <> 0 AND m.eventstatus = 'running')
													AND m.matchid = BR.MatchId
												)
								)	
							AND EXISTS ( 	SELECT 1
											FROM dbo.League l WITH (NOLOCK)
											WHERE l.leagueid = m.leagueid
												  AND l.isTest = CASE WHEN @IsShowAll = 1 THEN l.isTest ELSE @IsShowAll END 

										)
		
					UNION ALL

					 --- #2. From outright table  
					SELECT l.sporttype
					FROM dbo.league AS l WITH (NOLOCK)
					WHERE EXISTS (	SELECT 1
									FROM dbo.outright14 o WITH (NOLOCK)
									WHERE o.eventdate = @EventDate 
										AND o.oddsstatus = 'completed'	
										AND o.leagueid =  l.leagueid				
									)  
						AND l.sporttype BETWEEN 151 AND 153 
						AND l.isTest = CASE WHEN @IsShowAll = 1 THEN l.isTest ELSE @IsShowAll END 

					UNION ALL

					--- #3. From outright table 

					SELECT l.sporttype
					FROM dbo.league AS l WITH (NOLOCK)
					WHERE EXISTS (	SELECT 1
									FROM dbo.VSOutright14 AS o WITH (NOLOCK)
										INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON o.EventID = r.EventID
									WHERE o.EventDate = @EventDate 
										AND r.eventstatus = 'completed'	
										AND r.leagueid = l.leagueid
									)
						AND l.sporttype IN (181, 182, 183, 185, 184)
						AND l.isTest = CASE WHEN @IsShowAll = 1 THEN l.isTest ELSE @IsShowAll END 
			 
			  ) t
			  ON s.Sporttype = t.Sporttype
			  ORDER BY s.SportType, s.SportName
	END
	
	
END
 
GO
GRANT EXECUTE ON [dbo].[Age_Result_SportSelByDate] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_Result_SportSelByDate] TO [bodbDownlineNetView] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Result_SportSelByDate] TO [vnteam] AS [dbo]
GO
 