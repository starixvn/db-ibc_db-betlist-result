USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Lrf_BetList_MatchWL_Bettype].[Test_VirtualSports_BetTrans14]    Script Date: 11/30/2017 5:21:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Lrf_BetList_MatchWL_Bettype].[Test_VirtualSports_BetTrans14]
AS
BEGIN
	SET NOCOUNT ON

	-- Arrange
	DECLARE @Data TABLE (
		RowNum				INT,
		SportType			INT,
		Username			NVARCHAR(50),
		Nickname			VARCHAR(50),
		CustId				INT,
		BetType				INT,
		LeagueId			INT,
		TransId				BIGINT,
		MatchCode			VARCHAR(50),
		HomeId				INT,
		AwayId				INT,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
		Status				NVARCHAR(50),
		Stake				MONEY,
		WinLost				MONEY,
		LicenseeWL			MONEY,
		Comm				MONEY,
		PlayerComm			MONEY,
		TransDate			DATETIME,
		WinLostDate			DATETIME,
		BetTeam				VARCHAR(50),
		LiveIndicator		INT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		MatchId				INT,
		BetStatus			NVARCHAR(50),
		IsNeutral			BIT,
		OddsType			INT,
		BetId				BIGINT,
		Currency			SMALLINT,
		RefNo				BIGINT,
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(300),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		StakeUSD			MONEY,
		WinLostUSD			MONEY,
		LicenseeWLUSD		MONEY,
		CommUSD				MONEY,
		PlayerCommUSD		MONEY,
		OriginalStakeUSD	MONEY,
		StakeEUR			MONEY,
		WinLostEUR			MONEY,
		LicenseeWLEUR		MONEY,
		CommEUR				MONEY,
		PlayerCommEUR		MONEY,
		OriginalStakeEUR	MONEY,
		StakeGBP			MONEY,
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

	DECLARE @LicenseeId	INT		= 26,	-- Athena000
		@UserId			INT		= 68,
		@TransId		BIGINT,
		@BetType		INT,
		@MatchId		INT,
		@WinLostDate	SMALLDATETIME

	DECLARE @Temp TABLE (Currency INT, CurrencyName VARCHAR(100), IsActive BIT, AgentId INT)

	INSERT INTO @Temp
	EXEC bodb02.dbo.Lrf_SelCurrencyByLicenseeUser
		@LicenseeID = @LicenseeId,
		@UserID = @UserId

	DECLARE @AgentList VARCHAR(MAX)

	SELECT @AgentList = (
		SELECT AgentId, Currency FROM @Temp
		WHERE IsActive = 1
		FOR XML RAW('Agent'), ROOT('ROOT')
	)

	SELECT TOP(1)
		@TransId = b.transid,
		@BetType = b.bettype,
		@MatchId = m.matchid,
		@WinLostDate = b.winlostdate
	FROM bodb02.dbo.bettrans14 AS b WITH (NOLOCK)
		INNER JOIN bodb02.dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
		INNER JOIN bodb02.dbo.SportBettypeMatrix AS s WITH (NOLOCK) ON b.bettype = s.BetType
	WHERE b.bettype BETWEEN 1201 AND 1299
		AND b.currency IN (SELECT DISTINCT Currency FROM @Temp)
		AND b.recommend IN (SELECT DISTINCT AgentId FROM @Temp)
		AND b.statusID IN (111, 112, 113)
		AND b.winlostdate BETWEEN @BalanceUpDay AND @WinLostDate

	IF @TransId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Lrf_BetList_MatchWL_Bettype] 
							@AgentList = ''' + CONVERT(VARCHAR(MAX), @AgentList) + ''',
							@Bettype = ' + CONVERT(VARCHAR(5), @BetType) + ',
							@MatchId = ' + CONVERT(VARCHAR(10), @MatchId) + ',
							@ShowVS = 1,
							@Date = ''' + CONVERT(VARCHAR(10), @WinLostDate, 23) + ''''

		INSERT @Data
		EXEC tSQLt.ResultSetFilter 
			@ResultsetNo = 1,
			@Command = @Command;

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
