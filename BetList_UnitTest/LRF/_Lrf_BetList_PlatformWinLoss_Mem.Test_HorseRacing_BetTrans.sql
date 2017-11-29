USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Lrf_BetList_PlatformWinLoss_Mem].[Test_HorseRacing_BetTrans]    Script Date: 1/12/2017 1:51:55 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Lrf_BetList_PlatformWinLoss_Mem].[Test_HorseRacing_BetTrans]
AS
BEGIN
	SET NOCOUNT ON

	-- Arrange
	DECLARE @Data TABLE (
		RowNum				INT,
		SportType			INT,
		TransId				BIGINT,
		BetId				BIGINT,
		BetType				INT,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Modds				MONEY,
		OddsType			TINYINT,
		Odds				MONEY,
		Stake				MONEY,
		Actual_Stake		MONEY,
		BetTeam				NVARCHAR(20),
		Status				NVARCHAR(10),
		RefNo				BIGINT,
		TransDate			DATETIME,
		WinLostDate			DATETIME,
		WinLost				MONEY,
		LicenseeWL			MONEY,
		Comm				MONEY,
		PlayerComm			MONEY,
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		Ip					NVARCHAR(15),
		LeagueId			INT,
		MatchId				INT,
		MatchCode			NVARCHAR(50),
		Race				NVARCHAR(20),
		HomeId				INT,
		AwayId				INT,
		BetStatus			NVARCHAR(50),
		IsNeutral			BIT,
		VirtualRate			FLOAT,
		IsShowOTExRate		BIT,
		Currency			INT,
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(300),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		StakeMYR			MONEY,
		Actual_StakeMYR		MONEY,
		WinLostMYR			MONEY,
		LicenseeWLMYR		MONEY,
		CommMYR				MONEY,
		PlayerCommMYR		MONEY,
		OriginalStakeMYR	MONEY,
		StakeUSD			MONEY,
		Actual_StakeUSD		MONEY,
		WinLostUSD			MONEY,
		LicenseeWLUSD		MONEY,
		CommUSD				MONEY,
		PlayerCommUSD		MONEY,
		OriginalStakeUSD	MONEY,
		StakeEUR			MONEY,
		Actual_StakeEUR		MONEY,
		WinLostEUR			MONEY,
		LicenseeWLEUR		MONEY,
		CommEUR				MONEY,
		PlayerCommEUR		MONEY,
		OriginalStakeEUR	MONEY,
		StakeGBP			MONEY,
		Actual_StakeGBP		MONEY,
		WinLostGBP			MONEY,
		LicenseeWLGBP		MONEY,
		CommGBP				MONEY,
		PlayerCommGBP		MONEY,
		OriginalStakeGBP	MONEY
	)

	DECLARE @tmp TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME) 

	INSERT INTO @tmp(BalanceUpDay, MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	DECLARE @MoveBetsDay SMALLDATETIME,
		@BalanceUpDay SMALLDATETIME

	SELECT @MoveBetsDay = MoveBetsDay, 
		@BalanceUpDay = BalanceUpDay
	FROM @tmp

	IF @BalanceUpDay IS NULL
		SET @BalanceUpDay = @MoveBetsDay

	DECLARE @LicenseeId	INT		= 1,	-- 12Bet
		@UserId			INT		= 68,
		@CustId			INT,
		@TransId		BIGINT,
		@PlatformType	TINYINT,
		@WinLostDate	SMALLDATETIME

	DECLARE @Temp TABLE (Currency INT, CurrencyName VARCHAR(100), IsActive BIT, AgentId INT)

	INSERT INTO @Temp
	EXEC dbo.Lrf_SelCurrencyByLicenseeUser
		@LicenseeId = @LicenseeId,
		@UserId = @UserId

	DECLARE @AgentList VARCHAR(MAX)

	SELECT @AgentList = (
		SELECT AgentId, Currency FROM @Temp
		WHERE IsActive = 1
		FOR XML RAW('Agent'), ROOT('ROOT')
	)

	SELECT TOP(1)
		@TransId = b.transid,
		@CustId = b.custid,
		@PlatformType = CASE 
							WHEN b.betfrom IN ('d', 'g') THEN 1
							WHEN b.betfrom IN ('a', 'z') THEN 2
							WHEN b.betfrom IN ('e', 'u', 'y') THEN 3
							WHEN b.betfrom = 'm' THEN 4
							WHEN b.betfrom IN ('s', 'l') THEN 5
							WHEN b.betfrom = 'r' THEN 6
							WHEN b.betfrom = 'x' THEN 7
							ELSE 0
						END,
		@WinLostDate = b.winlostdate
	FROM bodb02.dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON b.custid = c.custid
		INNER JOIN bodb02.dbo.SportBettypeMatrix AS s WITH (NOLOCK) ON b.bettype = s.BetType
	WHERE s.ProductID = 2
		AND b.currency IN (SELECT Currency FROM @Temp)
		AND b.recommend IN (SELECT AgentId FROM @Temp)
		AND b.statusID IN (111, 112, 113)

	IF @TransId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Lrf_BetList_PlatformWinLoss_Mem] 
							@AgentList = ''' + CONVERT(VARCHAR(MAX), @AgentList) + ''',
							@CustID = ' + CONVERT(VARCHAR(10), @CustId) + ',
							@ShowRB = 1,
							@PlatformType = ' + CONVERT(VARCHAR(2), @PlatformType) + ',
							@FromDate = ''' + CONVERT(VARCHAR, @WinLostDate, 23) + ''',
							@ToDate = ''' + CONVERT(VARCHAR, @WinLostDate, 23) + ''',
							@MoveBetsDay = ''' + CONVERT(VARCHAR, @MoveBetsDay, 23) + ''',
							@BalanceUpDay = ''' + CONVERT(VARCHAR, @BalanceUpDay, 23) + ''''

		INSERT @Data
		EXEC tSQLt.ResultSetFilter
			@ResultsetNo = 1,
			@Command = @Command

		DECLARE @Actual INT

		SELECT @Actual = COUNT(*)
		FROM @Data
		WHERE TransId = @TransId

		-- Assert
		EXEC tSQLt.AssertEquals
			@Expected = 1,
			@Actual = @Actual,
			@Message = @Command
	END
	ELSE
	BEGIN
		EXEC tSQLt.Fail @Message0 = 'No available test data'
	END
END;

GO
