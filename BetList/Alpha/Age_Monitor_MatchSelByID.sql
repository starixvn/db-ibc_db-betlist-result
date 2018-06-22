ALTER PROCEDURE [dbo].[Age_Monitor_MatchSelByID]
	@MatchId	INT 
AS

/*
	Created:  20180622@Sophia
	Task: Last bets Monitoring - get match info by MatchId [Redmind: #97219]
	DB: DBAGE.bodb02

	Revision:		
	
	Parameter's Explanation:
		
*/

BEGIN
	SET NOCOUNT ON
	
	SELECT
		sporttype,
		eventstatus AS Status,
		matchid,
		leagueid,
		matchcode,
		homeid,
		awayid,
		'' AS Race,
		showtime,
		IsNeutral,
		betstatus
	FROM dbo.match WITH (NOLOCK)
	WHERE matchid = @MatchId
END
 
 
 
GO
GRANT EXECUTE ON [dbo].[Age_Monitor_MatchSelByID] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Monitor_MatchSelByID] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Monitor_MatchSelByID] TO [vnteam]
GO