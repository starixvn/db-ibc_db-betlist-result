ALTER PROCEDURE [dbo].[Age_Monitor_MatchSel]
	@MatchId	INT	= 0
AS

/*
	Created: Johnson@20110628
	Task: Monitor lastest bets list- get match running
	DB: DBAGE.bodb02

	Revision:
		- 20120301@Jamie: Retrieve showtime for LiveCasino
		- 20170817@Kos: Return IsNeutral [#Redmine: 66992]
		- 20180622@Sophia: Add Betstatus [#Redmine: 97219]
	
	Parameter's Explanation:
		- @@Matchid: lastest match's ID running get 
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
	WHERE eventstatus <> 'completed'
		AND matchid >= @MatchId
END

 
 
 
GO
GRANT EXECUTE ON [dbo].[Age_Monitor_MatchSel] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Monitor_MatchSel] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Monitor_MatchSel] TO [vnteam]
GO