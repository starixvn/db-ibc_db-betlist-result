ALTER PROCEDURE [dbo].[Age_Result_MatchSelResultDetail]
(	
	@MatchId INT
)
AS
/*
Created: 20141016@Sophia
Task: 	Get ResultDetail of a match
DB:  DBAGE/bodb02
Revisions: 
	- 20141218@Sophia: Not to use Betstatus to get REFUND status of Tennis anymore
	- 20150324@Sophia: Support to get BetRadar
	- 20150810@Sophia: Hardcode to exclude ResultDetail of bettype 216, 217 for a temporary time [#40991]

*/
BEGIN 
	SET NOCOUNT ON 	 

	DECLARE @Sporttype TINYINT
		
	IF EXISTS (SELECT 1 FROM dbo.match WITH (NOLOCK) WHERE matchid = @matchid)
	BEGIN 		
		SELECT 
			m.sporttype, 
			m.betstatus, 
			m.leagueid,
			m.matchid,		 
			m.matchcode,
			m.eventdate, 
			CASE WHEN m.sporttype = 162 THEN m.kickofftime ELSE m.globalshowtime END as kickofftime,
			m.homeID,
			m.awayID,
			m.hthomescore,
			m.htawayscore, 
			m.finalhomescore,
			m.finalawayscore,
			CASE m.Sporttype WHEN 5 THEN CASE ISNULL(R.SettlementStatusID,0)	 
										WHEN 1 THEN 'Refund' 
										WHEN 2 THEN 'Refund HT'
										WHEN 3 THEN 'Refund FT'
									ELSE m.eventstatus END 
								ELSE 
									CASE  WHEN m.betstatus like 'Refund FT%' THEN 'Refund FT' 
											WHEN m.betstatus like 'Refund HT%' THEN 'Refund HT'
											WHEN m.betstatus like 'Refund%' THEN 'Refund' 
									ELSE m.eventstatus END 
						END AS eventstatus, 
			m.showtime,
			isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
			m.goalrecord,
			ISNULL(m.homeid2,0) as homeid2,   
			ISNULL(mr.IsHTCal,0) as IsHTCal,
			ISNULL(mr.calculate,0) as calculate	,
			ISNULL(mr.IsPending,0) as IsPending	
		FROM  dbo.Match m WITH (NOLOCK)
			LEFT JOIN dbo.match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail R WITH (NOLOCK) ON R.matchID = M.MatchID AND R.ResourceId = '00'
		WHERE m.MatchId = @matchid

		------------------------------------- 
		SELECT @Sporttype = Sporttype FROM dbo.Match m WITH (NOLOCK) WHERE MatchId = @matchid 	
		
		SELECT	MatchId
				,R.ResourceId
				,HomeValue
				,AwayValue
				,ResultStatusID
				,SettlementStatusID
				,OtherInfo
		FROM	dbo.ResultDetail R WITH (NOLOCK)
		WHERE	MatchID = @MatchId
				AND SettlementStatusID > 0
				AND ((@Sporttype = 1 AND R.ResourceId NOT IN ( '00', '01', '08') AND ( R.ResourceID NOT LIKE '217%' AND R.ResourceID NOT LIKE '216%'))
						OR @Sporttype = 5
						)
		ORDER BY  MatchID, R.ResourceId 
	END 
	ELSE 
	BEGIN 		
		
		SELECT 
			m.sporttype, 
			m.betstatus, 
			m.leagueid,
			m.matchid,		 
			m.matchcode,
			m.eventdate, 
			CASE WHEN m.sporttype = 162 THEN m.kickofftime ELSE m.globalshowtime END as kickofftime,
			m.homeID,
			m.awayID,
			m.hthomescore,
			m.htawayscore, 
			m.finalhomescore,
			m.finalawayscore,
			CASE m.Sporttype WHEN 5 THEN CASE ISNULL(R.SettlementStatusID,0)	 
										WHEN 1 THEN 'Refund' 
										WHEN 2 THEN 'Refund HT'
										WHEN 3 THEN 'Refund FT'
									ELSE m.eventstatus END 
								ELSE 
									CASE  WHEN m.betstatus like 'Refund FT%' THEN 'Refund FT' 
											WHEN m.betstatus like 'Refund HT%' THEN 'Refund HT'
											WHEN m.betstatus like 'Refund%' THEN 'Refund' 
									ELSE m.eventstatus END 
						END AS eventstatus, 
			m.showtime,
			isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
			m.goalrecord,
			ISNULL(m.homeid2,0) as homeid2, 
			ISNULL(mr.IsHTCal,0) as IsHTCal,
			ISNULL(mr.calculate,0) as calculate	,
			ISNULL(mr.IsPending,0) as IsPending	
		FROM  dbo.Match14 m WITH (NOLOCK)
			LEFT JOIn dbo.match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail14 R WITH (NOLOCK) ON R.matchID = M.MatchID AND R.ResourceId = '00'
		WHERE m.MatchId = @matchid	

		-----------------------------------
		SELECT @Sporttype = Sporttype FROM dbo.Match14 m WITH (NOLOCK) WHERE MatchId = @matchid 

		SELECT	MatchId
				,R.ResourceId
				,HomeValue
				,AwayValue
				,ResultStatusID
				,SettlementStatusID
				,OtherInfo
		FROM	dbo.ResultDetail14 R WITH (NOLOCK)
		WHERE	MatchID = @MatchId
				AND SettlementStatusID > 0
				AND ((@Sporttype = 1 AND R.ResourceId NOT IN ( '00', '01', '08') AND ( R.ResourceID NOT LIKE '217%' AND R.ResourceID NOT LIKE '216%'))
						OR @Sporttype = 5
						)
		ORDER BY  MatchID, R.ResourceId 
	END
END

GO 
GRANT EXECUTE ON [dbo].[Age_Result_MatchSelResultDetail] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Result_MatchSelResultDetail] TO [bodbDownlineNetView] AS [dbo]
GO