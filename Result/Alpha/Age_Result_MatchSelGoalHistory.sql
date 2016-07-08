ALTER PROCEDURE [dbo].[Age_Result_MatchSelGoalHistory]
	@MatchID int
AS
SET NOCOUNT ON

SELECT isnull(GoalRecord,'') as GoalRecord,leagueid,homeid,awayid,isNeutral 
FROM match (nolock)
WHERE matchid=@MatchID
GO
GRANT EXECUTE ON [dbo].[Age_Result_MatchSelGoalHistory] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Result_MatchSelGoalHistory] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Result_MatchSelGoalHistory] TO [vnteam]
GO

