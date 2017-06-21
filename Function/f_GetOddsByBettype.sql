ALTER FUNCTION [dbo].[f_GetOddsByBettype]
(	
	@Odds		SMALLMONEY,
	@bettype	INT,
	@OddsType	TINYINT = 1
)
RETURNS SMALLMONEY
/*	Created: Amy
	Date: 2011-04-08
	Task: Get the odds value added by bettype 
	DB: DBTRANS.BODB02,DB053.BODB02,DB052.BODB02, DB06.BODB02,DB06.BODB_Archive 

	Revisions: 		
		- 20110803@Johnson: Add more bettype for number game.
		- 20110826@Lukas: Exclude Next Combo (89)
		- 20111202@Sophia: add new bettype 124, 125
		- 20120703@Sophia: Exclude Number Group (90)
	Param's Explanation:
		+ Input: @Odds 
		+ Input: @bettype and @oddsType: get the added values of odds (Dec and American odds)		
*/
AS
BEGIN
	DECLARE	@OddsValue SMALLMONEY
	IF (@bettype IN (1,2,3,7,12,8,20,124,125) OR @bettype BETWEEN 81 AND 88 OR @bettype BETWEEN 91 AND 120) AND @OddsType = 1 
		SELECT @OddsValue = @Odds + 1
	ELSE IF (@bettype IN (1,2,3,7,12,8,20,124,125) OR @bettype BETWEEN 81 AND 88 OR @bettype BETWEEN 91 AND 120) AND @OddsType=5 
		SELECT @OddsValue = @Odds * 100 	
	ELSE 
		SELECT @OddsValue = @Odds 

	RETURN @OddsValue 
END

GO
GRANT VIEW DEFINITION ON [dbo].[f_GetOddsByBettype] TO [vnteam]
