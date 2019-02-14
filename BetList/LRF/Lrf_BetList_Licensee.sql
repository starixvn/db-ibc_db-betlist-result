/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_Licensee]
	@AgentList		VARCHAR(MAX),
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@SportType		TINYINT			= 0,
	@BetType		SMALLINT		= 0,
	@LeagueId		INT				= 0,
	@MatchId		INT				= 0,
	@BaseCurrency	VARCHAR(10)		= '',
	@StatusIdList	VARCHAR(50)		= '',
	@LiveIndicator	TINYINT			= 3,
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 1,
	@Sort			NVARCHAR(50)	= N'Transid ASC',
	@Product		VARCHAR(10)		= '',
	@TotalRows		INT				= 0 OUTPUT,
	@SumStake		MONEY			= 0 OUTPUT,
	@SumWinLost		MONEY			= 0 OUTPUT,
	@SumLicenseeWL	MONEY			= 0 OUTPUT,
	@SumComm		MONEY			= 0 OUTPUT,
	@SumPlayerComm	MONEY			= 0 OUTPUT
AS

/*
	Created: Kos@20180613
	Task: Betting Ticket Center - Multiple Customer Bet List
	DB: DBEXT.bodb02
	Parameter's Explanation:
		- @Status: '111,112,113,101,102,103'
		- @Platform:
			- 0 - All: All
			- 1 - Asia: d (mobile), g (MG Download only)
			- 2 - China: a (dep-Singbet), z (dep2-SingBet)
			- 3 - Euro: e (Europe), u (dep-Euro), y (dep2-Euro)
			- 4 - WAP: m (dep-wap)
			- 5 - Smart Site: s (smartphone), l (dep-smart)
			- 6 - Tablet: r (dep2-tablet)
			 -7 - New Asia: x (dep2-Asia)
		- @LiveIndicator:
			- 0 : Non-live
			- 1 : Live
			- 2 : Mix Non Live & Live
			- 3 : All

	Revisions:
		- 20180711@Kos: Created [#Redmine: 80941]
		- 20190117@Kos: Fix outright tickets of specific sporttype [#Redmine: 105805]
		- 20190214@Kos: Betting Ticket Center phase 3b [Redmine: #108221]
					- Change input param from @ProductList to @Product
					- Remove input param @ShowBA
*/

BEGIN
	SET NOCOUNT ON

	IF @Product IN ('SB', 'BA')
	BEGIN
		EXEC Lrf_BetList_Licensee_Sportsbook
			@AgentList = @AgentList,
			@FromDate = @FromDate,
			@ToDate = @ToDate,
			@MoveBetsDay = @MoveBetsDay,
			@SportType = @SportType,
			@BetType = @BetType,
			@LeagueId = @LeagueId,
			@MatchId = @MatchId,
			@BaseCurrency = @BaseCurrency,
			@StatusIdList = @StatusIdList,
			@LiveIndicator = @LiveIndicator,
			@PageSize = @PageSize,
			@PageIndex = @PageIndex,
			@Sort = @Sort,
			@Product = @Product,
			@TotalRows = @TotalRows OUTPUT,
			@SumStake = @SumStake OUTPUT,
			@SumWinLost = @SumWinLost OUTPUT,
			@SumLicenseeWL = @SumLicenseeWL OUTPUT,
			@SumComm = @SumComm OUTPUT,
			@SumPlayerComm = @SumPlayerComm OUTPUT
	END
	ELSE
	BEGIN
		EXEC dbo.Lrf_BetList_Licensee_Others
			@AgentList = @AgentList,
			@FromDate = @FromDate,
			@ToDate = @ToDate,
			@MoveBetsDay = @MoveBetsDay,
			@SportType = @SportType,
			@BetType = @BetType,
			@BaseCurrency = @BaseCurrency,
			@StatusIdList = @StatusIdList,
			@LiveIndicator = @LiveIndicator,
			@PageSize = @PageSize,
			@PageIndex = @PageIndex,
			@Sort = @Sort,
			@Product = @Product,
			@TotalRows = @TotalRows OUTPUT,
			@SumStake = @SumStake OUTPUT,
			@SumWinLost = @SumWinLost OUTPUT,
			@SumLicenseeWL = @SumLicenseeWL OUTPUT,
			@SumComm = @SumComm OUTPUT,
			@SumPlayerComm = @SumPlayerComm OUTPUT
	END
END








GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_Licensee] TO [bodbLicenseeNet]
GO
