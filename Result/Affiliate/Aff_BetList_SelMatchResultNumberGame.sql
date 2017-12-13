USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Aff_User_BetListResult_SelMatchNumberGame]    Script Date: 10/17/2014 1:35:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Aff_BetList_SelMatchResultNumberGame    Script Date: 12/5/2013 3:56:31 PM ******/

ALTER PROCEDURE [dbo].[Aff_BetList_SelMatchResultNumberGame]  
    @MatchId 	INT
AS 
/*
Created:20141017@Bobby.Nguyen
Task: Get Betlist Parlay by TransID
DB: DBEXT/bodb02
Orgiginal: dbo.Age_BetList_SelMatchResultNumberGame

Revisions:    
	- 20141017@Bobby.Nguyen: Initial SP
	- 20141229@Bobby.Nguyen: add more IsRefund column
	
*/  
BEGIN
	SET NOCOUNT ON  
	 
	IF EXISTS(SELECT 1 FROM dbo.bingoBall WITH(NOLOCK) WHERE matchid = @matchid)  
	BEGIN   
		SELECT	b.matchid,   
				b.Seq,   
				b.number,
				b.updatetime,
				m.kickofftime, 
				m.leagueid,  
				m.eventdate,
				case when m.betstatus like 'Refund FT%' then 'Refund FT' 
					 when m.betstatus like 'Refund HT%' then 'Refund HT'
					 when m.betstatus like 'Refund%' then 'Refund' 
					else m.eventstatus end as eventstatus,
				m.matchcode
				,ISNULL(mr.refund,0) IsRefund
		FROM dbo.bingoBall b WITH(NOLOCK) 
			INNER JOIN dbo.[match] m WITH(NOLOCK) 
			ON b.matchid = m.matchid
			LEFT OUTER JOIN dbo.match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
		WHERE b.matchid = @matchid
		ORDER BY b.Seq
	END
	ELSE IF EXISTS(SELECT 1 FROM dbo.bingoBall14 WITH(NOLOCK) WHERE matchid = @matchid)   
	BEGIN  
		SELECT	b.matchid,   
				b.Seq,   
				b.number,
				b.updatetime,
				m.kickofftime, 
				m.leagueid,  
				m.eventdate,
				case when m.betstatus like 'Refund FT%' then 'Refund FT' 
					 when m.betstatus like 'Refund HT%' then 'Refund HT'
					 when m.betstatus like 'Refund%' then 'Refund' 
					else m.eventstatus end as eventstatus,
				m.matchcode
				,ISNULL(mr.refund,0) IsRefund
		FROM dbo.bingoBall14 b WITH(NOLOCK) 
			INNER JOIN dbo.[match14] m WITH(NOLOCK) 
			ON b.matchid=m.matchid
			LEFT OUTER JOIN dbo.match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
		WHERE b.matchid = @matchid
		ORDER BY b.Seq
	END  
	ELSE  
	BEGIN  
		SELECT	b.matchid,   
				b.Seq,   
				b.number,
				b.updatetime,
				m.kickofftime,
				m.leagueid,  
				m.eventdate,
				case when m.betstatus like 'Refund FT%' then 'Refund FT' 
					 when m.betstatus like 'Refund HT%' then 'Refund HT'
					 when m.betstatus like 'Refund%' then 'Refund' 
					else m.eventstatus end as eventstatus,
				m.matchcode
				,ISNULL(mr.refund,0) IsRefund
		FROM DBARC.bodb_archive.dbo.bingoBall_bk b WITH(NOLOCK) 
			INNER JOIN DBARC.bodb_archive.dbo.match_bk m WITH(NOLOCK)  
			ON b.matchid = m.matchid
			LEFT OUTER JOIN dbo.match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
		WHERE m.matchid = @matchid 
		ORDER BY b.Seq 
	END  
END
GO

GRANT EXECUTE ON [dbo].[Aff_BetList_SelMatchResultNumberGame] TO [bodbAdminNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Aff_BetList_SelMatchResultNumberGame] TO [bodbDownlineNet] AS [dbo]
GO  
