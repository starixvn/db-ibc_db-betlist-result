/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp, wsv_alpv" viewers="" isFunction="0" isNested="0"></info>*/
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
	- 20211117@Razor: Support In-house Replication [Redmine: #164321]
	- 20220510@Razor: Remove In-house Replication [Redmine: #171699]
*/
BEGIN
	SET NOCOUNT ON 

	SELECT @isShowAll = CASE @isShowAll WHEN 1 THEN NULL ELSE 0 END

	SELECT DISTINCT 
		league.sporttype, outright.leagueid, outright.eventdate, outright.teamid, 
		outright.status
	FROM
		(SELECT leagueid, eventdate, teamid, status
		FROM dbo.outright AS o1 WITH (nolock)
		WHERE oddsstatus = 'completed' 
			AND [status] IN ('WON','REFUND')
			AND eventdate >= @FromDate 
			AND eventdate <= @ToDate
		UNION ALL
		SELECT leagueid, eventdate, teamid, status
		FROM dbo.outright14 AS o14 WITH (nolock)
		WHERE oddsstatus = 'completed' 
			AND [status] IN ('WON','REFUND')
			AND eventdate >= @FromDate 
			AND eventdate <= @ToDate
		) AS outright 
		INNER JOIN dbo.league WITH (nolock) ON outright.leagueid = league.leagueid
	WHERE league.sporttype NOT IN (151,152,153)
		AND league.isTest = ISNULL(@isShowAll, league.isTest)
	ORDER BY outright.leagueid,outright.eventdate, outright.teamid
END
GO
