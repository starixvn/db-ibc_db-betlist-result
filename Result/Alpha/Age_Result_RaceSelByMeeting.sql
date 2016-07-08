
ALTER PROCEDURE [dbo].[Age_Result_RaceSelByMeeting]
	@FromDate DATETIME,
	@LeagueID INT = 0,
	@sporttype SMALLINT = 0,
	@isShowAll bit = 1 -- 1: Show All; 0: is NOT show Test	
AS
/*	Created:[]
	Date:[]
	DB: DB052.BODB02 

	Revisions:
		- 20091104@Jamie: Show the results of FOdds HR 
		- 20091201@Jamie: Get HR Results History (archive)
		- 20100127@Jamie: Remove order by kickofftime 
		- 20100524@Jamie: Only show Tote HR 
		- 20101229@Simon: Show All League or only show Live belong to @isShowAll.  
		- 20110304@Lukas: include Greyhound, Harness racing sports (152,153) - add param @sporttype
		- 20130808@Kathy: Amend to show refund game for horse racing				
*/
BEGIN
	SET NOCOUNT ON 
	
	SELECT @isShowAll = CASE @isShowAll WHEN 1 THEN NULL ELSE 0 END
	
	SELECT  o.leagueid meetingid, o.eventdate, o.kickofftime, 
			l.lcolor,
			CAST(o.groupmatch AS INT) AS racename, 
			case when o.placing = 0 then 5 else isnull(placing,5) end place, 
			o.matchcode horseNo, 
			o.teamid Horseid , 
			o.odds,
			o.placeodds,
			o.oddsstatus status,
			o.IsFavor,
			o.IsSCR,
			o.FOddsStatus
			
	FROM 
		(	SELECT	leagueid, teamid, eventdate, kickofftime, groupmatch, matchcode, placing, oddsstatus, odds, placeodds, IsFavor, IsSCR, FOddsStatus FROM outright o with (nolock)
			UNION ALL
			SELECT	leagueid, teamid, eventdate, kickofftime, groupmatch, matchcode, placing, oddsstatus, odds, placeodds, IsFavor, IsSCR, 'completed' FOddsStatus FROM outright14 o with (nolock)
			UNION ALL
			SELECT	leagueid, teamid, eventdate, kickofftime, groupmatch, matchcode, placing, oddsstatus, odds, placeodds, IsFavor, IsSCR, 'completed' FOddsStatus FROM DB06.bodb_Archive.dbo.outright_bk o with (nolock)
		 ) o 
		INNER JOIN league l WITH (NOLOCK) ON o.leagueid = l.leagueid 
	WHERE	o.eventdate = @FromDate 
			 and l.sporttype = case when @sporttype = 0 then l.sporttype else @sporttype end 
			and o.leagueid = case when @leagueid =0 then o.leagueid 
							 else @leagueid end 
			AND (o.oddsstatus = 'completed' OR o.oddsstatus = 'refund' OR o.Foddsstatus = 'completed' )  
			and l.isTest = isnull(@isShowAll, l.isTest)
	ORDER BY o.oddsstatus, o.leagueid, CAST(o.groupmatch AS INT), o.placing
END 


GO
GRANT EXECUTE ON [dbo].[Age_Result_RaceSelByMeeting] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Result_RaceSelByMeeting] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Result_RaceSelByMeeting] TO [vnteam]