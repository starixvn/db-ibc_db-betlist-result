
ALTER PROCEDURE [dbo].[Age_Result_Outright]
	@FromDate DATETIME,
	@ToDate DATETIME,
	@isShowAll bit = 1 -- 1: Show All; 0: is NOT show Test	
AS 

/*
Created:
Task: Get Result Outright (exclude Horse Racing)
DB: DB05.bodb02

Revisions:    
	- 20080618@HiepVo: CREATE NEW
	- 20101229@Simon: Show All League or only show Live belong to @isShowAll.  
	- 20110304@Lukas: exclude Greyhound & Harness racing sports (152,153)
	- 20110628@Jamie: Adding REFUND result for Outright 
*/
SET NOCOUNT ON 

SELECT @isShowAll = CASE @isShowAll WHEN 1 THEN NULL ELSE 0 END

SELECT DISTINCT 
		league.sporttype, outright.leagueid, outright.eventdate, outright.teamid, 
		outright.status
	FROM         
		(SELECT leagueid, eventdate, teamid, status
		 FROM dbo.outright AS o1 with (nolock)
		 where oddsstatus = 'completed' and [status] IN ('WON','REFUND')
			and eventdate >= @FromDate and eventdate <= @ToDate
		 UNION ALL
		 SELECT leagueid, eventdate, teamid, status
		 FROM dbo.outright14 AS o14 with (nolock)
		 where oddsstatus = 'completed' and [status] IN ('WON','REFUND')
			and eventdate >= @FromDate and eventdate <= @ToDate
		) AS outright 
		 INNER JOIN dbo.league with (nolock) on outright.leagueid = league.leagueid
	WHERE league.sporttype not in (151,152,153)
		and league.isTest = isnull(@isShowAll, league.isTest)
	ORDER BY outright.leagueid,outright.eventdate, outright.teamid
	
	
GO
GRANT EXECUTE ON [dbo].[Age_Result_Outright] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Result_Outright] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Result_Outright] TO vnteam