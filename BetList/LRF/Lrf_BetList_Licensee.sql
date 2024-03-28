/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_Licensee]
	@AgentList			VARCHAR(MAX),
	@Username			VARCHAR(50)		= '',
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@MoveBetsDay		SMALLDATETIME,
	@Product			VARCHAR(100)	= '',
	@SportType			TINYINT			= 0,
	@BetType			SMALLINT		= 0,
	@LeagueId			INT				= 0,
	@MatchId			INT				= 0,
	@LeagueGroupIds		VARCHAR(200)	= '',
	@BaseCurrency		VARCHAR(12),
	@ConvertToBaseCur	BIT				= 0,	-- Convert to base currency or not
	@StatusIdList		VARCHAR(50)		= '',
	@LiveIndicator		VARCHAR(10)		= '0,1,2',
	@PlatformType		VARCHAR(100)	= 'All',
	@CustomerClass		VARCHAR(MAX)	= 'All',
	@FullCustomerClass	VARCHAR(MAX)	= 'All',
	@OddsGroup			VARCHAR(100)	= 'All',
	@Ip					VARCHAR(45)		= '',
	@PageSize			INT				= 1000,
	@PageIndex			INT				= 1,
	@Sort				NVARCHAR(50)	= N'TransDate ASC',
	@TotalRows			INT				= 0 OUTPUT,
	@SumStake			MONEY			= 0 OUTPUT,
	@SumWinLost			MONEY			= 0 OUTPUT,
	@SumLicenseeWL		MONEY			= 0 OUTPUT,
	@SumComm			MONEY			= 0 OUTPUT,
	@SumPlayerComm		MONEY			= 0 OUTPUT
AS

/*
	Created: Kos@20180613
	Task: Betting Ticket Center - Multiple Customer Bet List
	DB: DBEXT.bodb02
	Parameter's Explanation:
		- @StatusIdList:
			- 101: Reject
			- 102: Void (not include Abnormal Bets)
			- 103: Refund
			- 111: Draw
			- 112: Won
			- 113: Lose
			- 99: Abnormal Bets
		- @LiveIndicator:
			- 0 : Non-live
			- 1 : Live
			- 2 : Mix Non Live & Live

	Revisions:
		- 20180711@Kos: Created [#Redmine: 80941]
		- 20190117@Kos: Fix outright tickets of specific sporttype [#Redmine: 105805]
		- 20190214@Kos: Betting Ticket Center phase 3b [Redmine: #108221]
					- Change input param from @ProductList to @Product
					- Remove input param @ShowBA
		- 20190313@Kos: Change param @LiveIndicator from TINYINT to VARCHAR(10) [Redmine: #108717]
					- Add new param @Username, @ConvertToBaseCur
		- 20200207@Kos: Support sort by trans time [Redmine: #126886]
		- 20211104@Kos: Merge Sports Lottery into Sportsbook [RedmineID: #163191]
		- 20211220@Kos: Support new Cash Out [Redmine: #165160]
		- 20220128@Kos: Support search by IP [RedmineID: #166079]
		- 20230922@Kos: Support crypto currency [Redmine: 177481]
		- 20230316@Kos: Support Saba Sports [Redmine: 183841]
					- Add new input params @LeagueGroupIds, @PlatformType, @CustomerClass, @OddsGroup
		- 20240207@Kos: Hotfix - No data when filtering player has Risk Level Uncategorized [RedmineID: #200913]
					- Add new input param @FullCustomerClass VARCHAR(MAX)
*/

BEGIN
	SET NOCOUNT ON

	IF ',' + @Product + ',' LIKE '%,SB,%' OR @Product IN ('BA', 'CO')
	BEGIN
		EXEC Lrf_BetList_Licensee_Sportsbook
			@AgentList = @AgentList,
			@Username = @Username,
			@FromDate = @FromDate,
			@ToDate = @ToDate,
			@MoveBetsDay = @MoveBetsDay,
			@Product = @Product,
			@SportType = @SportType,
			@BetType = @BetType,
			@LeagueId = @LeagueId,
			@MatchId = @MatchId,
			@LeagueGroupIds = @LeagueGroupIds,
			@BaseCurrency = @BaseCurrency,
			@ConvertToBaseCur = @ConvertToBaseCur,
			@StatusIdList = @StatusIdList,
			@LiveIndicator = @LiveIndicator,
			@PlatformType = @PlatformType,
			@CustomerClass = @CustomerClass,
			@FullCustomerClass = @FullCustomerClass,
			@OddsGroup = @OddsGroup,
			@Ip = @Ip,
			@PageSize = @PageSize,
			@PageIndex = @PageIndex,
			@Sort = @Sort,
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
			@Username = @Username,
			@FromDate = @FromDate,
			@ToDate = @ToDate,
			@MoveBetsDay = @MoveBetsDay,
			@Product = @Product,
			@SportType = @SportType,
			@BetType = @BetType,
			@BaseCurrency = @BaseCurrency,
			@ConvertToBaseCur = @ConvertToBaseCur,
			@StatusIdList = @StatusIdList,
			@LiveIndicator = @LiveIndicator,
			@PlatformType = @PlatformType,
			@CustomerClass = @CustomerClass,
			@FullCustomerClass = @FullCustomerClass,
			@OddsGroup = @OddsGroup,
			@Ip = @Ip,
			@PageSize = @PageSize,
			@PageIndex = @PageIndex,
			@Sort = @Sort,
			@TotalRows = @TotalRows OUTPUT,
			@SumStake = @SumStake OUTPUT,
			@SumWinLost = @SumWinLost OUTPUT,
			@SumLicenseeWL = @SumLicenseeWL OUTPUT,
			@SumComm = @SumComm OUTPUT,
			@SumPlayerComm = @SumPlayerComm OUTPUT
	END
END
GO
