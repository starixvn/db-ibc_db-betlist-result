/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[CS_BetList_Statement_Mem]
	@CustId			INT,
	@Date			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@SportTypeGroup	TINYINT			= 0
AS

/*
	Created: Kos@20190227
	Task: Win Loss Bet List of CN88 Member range bettrans and bettrans14
	DB: DBAGE.bodb02

	Param's Explanation:
		- @LiveIndicator: 
			- 0: Non-Live, Mix Live & Non-Live (System Parlay bettype 29)
			- 1: Live
			- 2: All (Live, Non-Live, Mix Live & Non-Live)
			
	Revisions:
		- 20190227@Kos: Create new [Redmine: 109230]
*/

BEGIN
	SET NOCOUNT ON;

	EXEC CS_BetList_Settled_Mem
		@CustId = @CustId,
		@FromDate = @Date,
		@ToDate = @Date,
		@MoveBetsDay = @MoveBetsDay,
		@SportTypeGroup = @SportTypeGroup,
		@BetTypeGroup = 0,
		@LiveIndicator = 2,
		@StatusIdList = '101,102,103,111,112,113',
		@AbnormalBets = 2
END
GO





GRANT EXECUTE ON [dbo].[CS_BetList_Statement_Mem] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[CS_BetList_Statement_Mem] TO [bodbDownlineNetView] AS [dbo]
GO
