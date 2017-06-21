ALTER FUNCTION [dbo].[f_ShowOddsByBettype]
(	@bettype	INT,
	@OddsType	TINYINT = 1
)
RETURNS TINYINT
/*	Created: Jamie
	Date: 2009-10-03
	Task: Get the odds value added by bettype 
	DB: DBTRANS.BODB02,DB053.BODB02,DB052.BODB02, DB06.BODB02,DB06.BODB_Archive 

	Revisions: 
		- 20101202@Qui : Add show oddstype for number game
		- 20110408@Amy: Modify to show American odds (oddstype=5)	
		- 20110803@Johnson: Add more bettype for number game
		- 20110826@Lukas: Exclude Next Combo (89)
		- 20111202@Sophia: add new bettype 124, 125
		- 20120703@Sophia: Exclude Number Group (90)
	Param's Explanation:
		+ Input: @bettype and @oddsType: show the added values of odds 
		+ Input @bettype and default @OddsType = 1 to indicate the odds type whether shown or not 

*/
AS
BEGIN
	DECLARE	@ShowOdds TINYINT
	IF @bettype IN (1,2,3,7,12,8,20,124,125) OR @bettype BETWEEN 81 AND 88 OR @bettype BETWEEN 91 AND 120  
		SELECT @ShowOdds = @OddsType	
	ELSE 
		SELECT @ShowOdds = 0 
	RETURN @ShowOdds 
END



GO
GRANT VIEW DEFINITION ON [dbo].[f_ShowOddsByBettype] TO [vnteam]
