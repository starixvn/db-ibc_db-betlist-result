ALTER PROCEDURE [dbo].[Age_Monitor_MatchSel]
	@matchid	INT	= 0	
 AS

/*	
	Created	: Johnson
	Task: Monitor lastest bets list- get match running
	Date: 28/06/2011
	DB: DB053.BODB02

	Revision:
		- 20120301@Jamie: Retrieve showtime for LiveCasino 
	
	Parameter's Explanation:		
		- @matchid: lastest match's ID running get 
*/ 

 BEGIN
	SET NOCOUNT ON
	
	SELECT 
		sporttype AS sporttype,
		eventstatus AS status,
		matchid,
		leagueid,
		matchcode,
		homeid,
		awayid,
		'' AS race,
		showtime
	FROM MATCH WITH(NOLOCK)
	WHERE eventstatus <> 'completed' 
		AND matchid >=@matchid
 END
 
 
 
GO
GRANT EXECUTE ON [dbo].[Age_Monitor_MatchSel] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Monitor_MatchSel] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Monitor_MatchSel] TO [vnteam]