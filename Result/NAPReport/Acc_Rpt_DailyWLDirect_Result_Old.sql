USE [bodb_dwrs]
GO
/****** Object:  StoredProcedure [dbo].[Acc_Rpt_DailyWLDirect_Result_Old]    Script Date: 02/14/2017 03:34:33 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Acc_Rpt_DailyWLDirect_Result_Old]
	@MatchID int,
	@Bettype int,
	@TraderName nvarchar(100) OUTPUT
AS
/*
Created: Dom.Cao
Task: show popup of match information
DB: DBDW2/BODB_DWRS
Original: Acc_BetList_SelMatchResult_Old

Revisions:    
 - 20141023@Sophia: Get data from ResultDetail table (support Sporting solution) - (RedmineID :#23671)
 - 20150415@Sophia: Support BetRadar
 - 20151215@Tom: Change data type of parameter @Sporttype from TINYINT to SMALLINT
			Change DB06 to alias server DBACC (RedmineID :#48078)
*/
SET NOCOUNT ON

DECLARE @Sporttype SMALLINT

	SELECT 
		m.betstatus, 
		m.hthomescore,
		m.htawayscore,
		datediff(minute,kickofftime,CURRENT_TIMESTAMP) playtime,
		m.LeagueID,
		m.homeID,
		m.awayID,
		m.matchcode,
		m.kickofftime,
		m.eventdate,
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

		isnull(mr.refund,0) IsRefund, 
		isnull(mr.calrefund,0) IsCalRefund,
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,		
		ISNULL(mr.IsPending,0) as IsPending
	FROM DBACC.bodb_archive.dbo.match_bk m WITH(NOLOCK)
	LEFT OUTER JOIN bodb02.dbo.match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
	LEFT JOIN DBARC.bodb_archive.dbo.ResultDetail_bk R WITH (NOLOCK) ON R.matchID = M.MatchID AND R.ResourceId = '00'
	WHERE m.matchid = @matchid
	
	SELECT @TraderName = c.username
	FROM  DBARC.bodb_archive.dbo.Dot_Admin_Assignment_Operator_bk o WITH (NOLOCK)
		INNER JOIN bodb02.dbo.customer c with(nolock) on o.OperatorID = c.custid
	WHERE matchid = @MatchID 
		AND @Bettype = CASE WHEN bettype IN (1,5) AND OperatorType = 1 THEN 1
							WHEN bettype = 1 AND OperatorType = 2 THEN 7
							WHEN bettype = 2 AND OperatorType = 1 THEN 3
							WHEN bettype = 2 AND OperatorType = 2 THEN 8
							WHEN bettype = 3 AND OperatorType = 1 THEN 5
							WHEN bettype = 3 AND OperatorType = 2 THEN 15
							WHEN bettype = 4 AND OperatorType = 1 THEN 2
							WHEN bettype = 4 AND OperatorType = 2 THEN 12
							END


		SELECT @Sporttype = Sporttype FROM DBARC.bodb_archive.dbo.match_bk m WITH (NOLOCK) WHERE MatchId = @matchid

	--- Get detail 
		SELECT	D.MatchId,
				D.ResourceId,
				D.HomeValue,
				D.AwayValue,
				D.ResultStatusID,
				D.SettlementStatusID,
				D.OtherInfo
		FROM	DBARC.bodb_archive.dbo.ResultDetail_bk D WITH (NOLOCK)			
		WHERE	D.MatchId = @MatchId AND D.SettlementStatusID > 0				
				AND ((@Sporttype = 1 AND D.ResourceId NOT IN ( '00', '01', '08'))
						OR @Sporttype = 5
						)
		ORDER BY  D.MatchID, D.ResourceId