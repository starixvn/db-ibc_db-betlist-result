ALTER PROCEDURE [dbo].[Acc_BetList_SelMatchResultSS]  
@matchid INT,   
@resourceid VARCHAR(2)  
AS  
/*
	Created: Elodie
	Date: 20101024
	Task: Get a detailed result of set in a tennis's match for sporting solutions product
	DB: DB053.bodb02  
    
	Revisions:  	
			
	Parameter's explanation:  
		- @resourceid: a set of tennis's match (Ex: 01, 02, 03, ...)
  
 */  
SET NOCOUNT ON  
  
DECLARE @resultkey VARCHAR(50)  
SELECT @resultkey = 'set'+ @resourceid + 'summary'  

IF EXISTS (SELECT 1 FROM SS_GameState WITH(NOLOCK) WHERE matchid = @matchid)  
BEGIN  
	SELECT ISNULL(resultvalue,'') as resultvalue  
	FROM SS_GameState WITH(NOLOCK)  
	WHERE matchid = @matchid AND resultkey = @resultkey  
END  
ELSE IF EXISTS(SELECT 1 FROM SS_GameState14 WITH(NOLOCK) WHERE matchid = @matchid)  
BEGIN  
	SELECT ISNULL(resultvalue,'') as resultvalue  
	FROM SS_GameState14 WITH(NOLOCK)  
	WHERE matchid = @matchid AND resultkey = @resultkey  
END  
--ELSE IF EXISTS(SELECT 1 FROM DB06.bodb_Archive.dbo.SS_GameState_bk WITH(NOLOCK) WHERE matchid = @matchid)  
--BEGIN  
--	SELECT ISNULL(resultvalue,'') as resultvalue  
--	FROM DB06.bodb_Archive.dbo.SS_GameState_bk WITH(NOLOCK)  
--	WHERE matchid = @matchid AND resultkey = @resultkey  
--END  
 
GO
GRANT EXECUTE ON [dbo].[Acc_BetList_SelMatchResultSS] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Acc_BetList_SelMatchResultSS] TO [bodbExtAccNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BetList_SelMatchResultSS] TO [vnteam]