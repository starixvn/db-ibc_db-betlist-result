/*<info serverAlias="DBARC-bodb_Archive" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[CS_BetList_CancelledBet_Mem_Old]
	@CustId				INT,
	@HeadlineId			INT				= 0,
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@SportTypeGroups	VARCHAR(MAX)	= '0',
	@BetTypeGroup		SMALLINT		= 0,
	@LiveIndicator		TINYINT			= 2
AS

/*
	Created: Kos@20190227
	Task: Win Loss Bet List of CN88 Member range bk
	DB: DBARC.bodb_Archive

	Param's Explanation:
		- @LiveIndicator: 
			- 0: Non-Live, Mix Live & Non-Live (System Parlay bettype 29)
			- 1: Live
			- 2: All (Live, Non-Live, Mix Live & Non-Live)

	Revisions:
		- 20190227@Kos: Create new [Redmine: 109230]
		- 20190821@Kos: Support multiple sport filter [Redmine: 109230]
		- 20190920@Kos: Support Move Super, add new param @HeadlineId [Redmine: #118962]
*/

BEGIN
	SET NOCOUNT ON;

	EXEC CS_BetList_Settled_Mem_Old
		@CustId = @CustId,
		@HeadlineId = @HeadlineId,
		@FromDate = @FromDate,
		@ToDate = @ToDate,
		@SportTypeGroups = @SportTypeGroups,
		@BetTypeGroup = @BetTypeGroup,
		@LiveIndicator = @LiveIndicator,
		@StatusIdList = '101,102,103',
		@AbnormalBets = 0
END
GO




GRANT EXECUTE ON [dbo].[CS_BetList_CancelledBet_Mem_Old] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[CS_BetList_CancelledBet_Mem_Old] TO [bodbDownlineNetView] AS [dbo]
GO
