ALTER PROCEDURE [dbo].[Age_BetList_SelMatchResultNumberGame]  
	@MatchID INT
AS 
/*  
Created: 20100908@Jacob: Show the results for number game
Task: Get Result for number game 
DB: DBAGE/bodb02  
  
Revisions:      
	- 20110721@Johnson: get column kickofftime, leagueid
	- 20110831@Johnson: correct event status when refund ticket
	- 20130121@Dan: change linked server DB06 to DBARC
*/  
  
SET NOCOUNT ON  
 
IF EXISTS(SELECT 1 FROM bingoBall WITH(NOLOCK) WHERE matchid = @matchid)  
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
			m.matchcode,
			m.leagueid
	FROM bingoBall b WITH(NOLOCK) INNER JOIN [match] m WITH(NOLOCK) ON b.matchid=m.matchid
	WHERE b.matchid = @matchid
	ORDER BY b.Seq
END
ELSE IF EXISTS(SELECT 1 FROM bingoBall14 WITH(NOLOCK) WHERE matchid = @matchid)   
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
			m.matchcode,
			m.leagueid
	FROM bingoBall14 b WITH(NOLOCK) INNER JOIN [match14] m WITH(NOLOCK) ON b.matchid=m.matchid
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
			m.matchcode,
			m.leagueid
	FROM DBARC.bodb_archive.dbo.bingoBall_bk b WITH(NOLOCK) INNER JOIN DB06.bodb_archive.dbo.match_bk m WITH(NOLOCK)  ON b.matchid=m.matchid
	WHERE m.matchid = @matchid 
	ORDER BY b.Seq 
END  
  
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResultNumberGame] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResultNumberGame] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResultNumberGame] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelMatchResultNumberGame] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResultNumberGame] TO [bodbExtAccNet]