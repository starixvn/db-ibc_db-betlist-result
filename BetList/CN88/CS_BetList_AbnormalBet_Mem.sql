/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[CS_BetList_AbnormalBet_Mem]
	@CustId				INT,
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@MoveBetsDay		SMALLDATETIME,
	@SportTypeGroups	VARCHAR(MAX)	= '0',
	@BetTypeGroup		SMALLINT		= 0,
	@LiveIndicator		TINYINT			= 2
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
		- 20190821@Kos: Support multiple sport filter [Redmine: 109230]
*/

BEGIN
	SET NOCOUNT ON;

	EXEC CS_BetList_Settled_Mem
		@CustId = @CustId,
		@FromDate = @FromDate,
		@ToDate = @ToDate,
		@MoveBetsDay = @MoveBetsDay,
		@SportTypeGroups = @SportTypeGroups,
		@BetTypeGroup = @BetTypeGroup,
		@LiveIndicator = @LiveIndicator,
		@StatusIdList = '102',
		@AbnormalBets = 1
END
GO



GRANT EXECUTE ON [dbo].[CS_BetList_AbnormalBet_Mem] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[CS_BetList_AbnormalBet_Mem] TO [bodbDownlineNetView] AS [dbo]
GO
