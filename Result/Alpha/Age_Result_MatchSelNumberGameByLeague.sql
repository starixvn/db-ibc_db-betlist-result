ALTER PROCEDURE [dbo].[Age_Result_MatchSelNumberGameByLeague]
 @FromDate DATETIME,
 @ToDate DATETIME = NULL,
 @LeagueID INT,
 @Language NVARCHAR(2) = 'E',
 @isShowAll bit = 1 -- 1: Show All; 0: is NOT show Test	
AS
/*
Created: 20100908@Jacob  
Task: Get Number Game result by league  
DB: DB052.bodb02  
Original: Age_Result_LeagueSelByDate  
  
Revisions:   
 20101207@Viet: change the condition to select never-open-game as well.  
 20101217@Viet: change the condition back (remove never-open-game) for agentsite to use.
 20101229@Simon: Show All League or only show Live belong to @isShowAll.  
 20110901@Jamie: Get Refund Result
 20151014@Sophia: Show internal match [#45531]
*/  
  
SET NOCOUNT ON  

SELECT @isShowAll = CASE @isShowAll WHEN 1 THEN NULL ELSE 0 END

IF @ToDate IS NULL
BEGIN
	SELECT @ToDate = DATEADD(s,-1, DATEADD(d, 1, @FromDate))  
END  
SELECT   
	m.betstatus,   
	m.leagueid,  
	m.matchid,
	m.matchcode,  
	m.eventdate,   
	m.kickofftime,
	m.homeid,
	CASE WHEN m.betstatus LIKE 'Refund FT%' THEN 'Refund FT'   
		 WHEN m.betstatus LIKE 'Refund HT%' THEN 'Refund HT'  
		 WHEN m.betstatus LIKE 'Refund%' THEN 'Refund'   
		 ELSE m.eventstatus END AS eventstatus,
	CASE WHEN m.betstatus LIKE 'Refund' THEN 1   
		 ELSE 0 END AS IsRefund,
	b.seq,
	b.number
FROM  
   (SELECT sporttype, betstatus, matchid, matchcode, leagueid, eventdate, eventstatus, kickofftime, homeid  
	FROM MATCH (NOLOCK)  
    WHERE	eventdate BETWEEN  @FromDate  AND  @ToDate 
			AND sporttype=161
			AND (@LeagueID = 0 OR leagueid = @LeagueID)
	UNION ALL  
	SELECT sporttype, betstatus, matchid, matchcode, leagueid, eventdate, eventstatus, kickofftime ,homeid   
	FROM match14 (NOLOCK)  
	WHERE	eventdate BETWEEN  @FromDate  AND  @ToDate 
			AND sporttype=161
			AND (@LeagueID = 0 OR leagueid = @LeagueID)
    )AS m 
	LEFT JOIN (SELECT matchid, seq, number FROM bingoball(NOLOCK)
				UNION ALL
				SELECT matchid, seq, number FROM bingoball14(NOLOCK)
				) AS B ON B.matchid = m.matchid
	LEFT OUTER JOIN match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid  
	INNER JOIN league with (nolock) on m.leagueid = league.leagueid
WHERE (m.eventstatus NOT IN ('running') OR (m.eventstatus = 'running' AND mr.ishtcal=1))
		and league.isTest = isnull(@isShowAll, league.isTest)
GO

GRANT EXECUTE ON [dbo].[Age_Result_MatchSelNumberGameByLeague] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Result_MatchSelNumberGameByLeague] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Result_MatchSelNumberGameByLeague] TO [vnteam]
GO


