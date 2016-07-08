ALTER PROCEDURE [dbo].[Age_Result_SportSelByDate]  
 @EventDate DATETIME,
 @isshowall BIT = 0
AS  
/*  
Created:  
Task:  
DB: DB053.bodb02  
Original:  
Revision:  
 - 20110307@Lukas: get more sporttype 152,153  
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
 
*/  
  
SET NOCOUNT ON  
DECLARE @toDate  DATETIME,  
  @matchcode VARCHAR(10) --HRDummy  
 
SELECT @toDate = DATEADD(s,-1, DATEADD(d, 1, @EventDate))  

SELECT DISTINCT sports.sporttype, sportname   
FROM sports WITH (nolock) 
		INNER JOIN (  SELECT matchid, eventdate, eventstatus, sporttype, leagueid
						FROM match (nolock)  
						UNION ALL  
						SELECT matchid, eventdate, eventstatus, sporttype, leagueid
						FROM match14 (nolock)  
					) match ON match.sporttype = sports.sporttype  
	
		LEFT JOIN match_remark mr ON match.matchid = mr.matchid         
		INNER JOIN league l with(nolock) on l.leagueid = match.leagueid
		LEFT JOIN ( SELECT DISTINCT MatchID FROM dbo.ResultDetail R WITH (NOLOCK) WHERE SettlementStatusID > 0
					UNION ALL  
					SELECT DISTINCT MatchID FROM dbo.ResultDetail14 R WITH (NOLOCK) WHERE SettlementStatusID > 0
					) SS
				ON match.Matchid = SS.MatchId AND Match.sporttype = 5
		LEFT JOIN ( SELECT DISTINCT MatchID FROM dbo.ResultDetail R WITH (NOLOCK) WHERE SettlementStatusID > 0 AND ResourceID NOT IN ('00','01','08') AND ( R.ResourceID NOT LIKE '217%' AND R.ResourceID NOT LIKE '216%')
					UNION ALL  
					SELECT DISTINCT MatchID FROM dbo.ResultDetail14 R WITH (NOLOCK) WHERE SettlementStatusID > 0 AND ResourceID NOT IN ('00','01','08') AND ( R.ResourceID NOT LIKE '217%' AND R.ResourceID NOT LIKE '216%')
					) BR
				ON match.Matchid = BR.MatchId AND Match.sporttype = 1
WHERE   
		match.eventdate >= @EventDate  
		AND match.eventdate <= @toDate  
		AND ( match.eventstatus NOT IN ('closed','running')  
			OR ( mr.IsPending=1 AND match.eventstatus IN ('running','closed') )  
			OR ( mr.IsHTCal = 1 AND match.eventstatus ='running')  
			OR ( ISNULL(SS.MatchID,0) <> 0 AND match.eventstatus = 'running')  --- condition for Sportting Solution show running Match but settled least one type
			OR ( ISNULL(BR.MatchID,0) <> 0 AND match.eventstatus = 'running')  --- condition for BetRadar show running Match but settled least one type
		)  
		AND sports.sporttype NOT IN (201,162)
		AND l.isTest= CASE WHEN @isshowall = 1 THEN l.isTest ELSE @isshowall END 
   
UNION ALL  
  
SELECT s.sporttype, s.sportname  
FROM (  
		SELECT ROW_NUMBER() OVER (PARTITION BY sporttype ORDER BY l.leagueid) AS RowNumber, l.sporttype, l.leagueid, l.isTest
		FROM league l with (nolock)   
		INNER JOIN  
			( SELECT leagueid, oddsstatus, eventdate FROM outright WITH (nolock)  
				WHERE eventdate >= @EventDate and eventdate <= @toDate  
				UNION ALL  
				SELECT leagueid, oddsstatus, eventdate FROM outright14 WITH (nolock)   
				WHERE eventdate >= @EventDate and eventdate <= @toDate  
				) o ON o.leagueid = l.leagueid   
		WHERE l.sporttype BETWEEN 151 AND 153 AND o.oddsstatus='completed'  
		) t 
		INNER JOIN sports s WITH(NOLOCK) ON t.sporttype = s.sporttype  
WHERE t.RowNumber < 2  
	AND t.isTest= CASE WHEN @isshowall = 1 THEN t.isTest ELSE @isshowall END 
 
UNION ALL  
  
SELECT s.sporttype, s.sportname  
FROM (  
		SELECT ROW_NUMBER() OVER (PARTITION BY sporttype ORDER BY l.leagueid) AS RowNumber, l.sporttype, l.leagueid , l.isTest
		FROM league l with (nolock)   
			INNER JOIN  
			( SELECT leagueid, r.eventstatus, eventdate 
			  FROM VSOutright o WITH (nolock) 
				INNER JOIN VSRaceInfo r WITH (NOLOCK) ON o.EventID = r.EventID  
			  WHERE eventdate >= @EventDate 
				and eventdate <= @toDate  

			  UNION ALL  
			  SELECT leagueid, r.eventstatus, eventdate 
			  FROM VSOutright14 o WITH (nolock) 
				INNER JOIN VSRaceInfo r WITH (NOLOCK) ON o.EventID = r.EventID  
			  WHERE eventdate >= @EventDate 
				and eventdate <= @toDate  
			) o ON o.leagueid = l.leagueid   
		WHERE l.sporttype IN ( 181, 182, 183, 185, 184)
			AND o.eventstatus='completed'  
		) t 
		INNER JOIN sports s WITH(NOLOCK) ON t.sporttype = s.sporttype  
WHERE t.RowNumber < 2  
	AND t.isTest= CASE WHEN @isshowall = 1 THEN t.isTest ELSE @isshowall END 
order by sports.sporttype, sports.sportname


 
GO
GRANT EXECUTE ON [dbo].[Age_Result_SportSelByDate] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_Result_SportSelByDate] TO [bodbDownlineNetView] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Result_SportSelByDate] TO [vnteam] AS [dbo]