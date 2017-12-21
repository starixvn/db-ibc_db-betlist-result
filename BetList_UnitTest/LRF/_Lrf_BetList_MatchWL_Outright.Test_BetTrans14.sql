USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Lrf_BetList_MatchWL_Outright].[Test_BetTrans14]    Script Date: 12/1/2017 10:06:43 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Lrf_BetList_MatchWL_Outright].[Test_BetTrans14]
AS
BEGIN
	SET NOCOUNT ON

	-- Arrange
	DECLARE @Data TABLE (
		RowNum			INT,
		SportType		INT,
		Username		NVARCHAR(50),
		Nickname		VARCHAR(50),
		CustId			INT,
		BetType			SMALLINT,
		TransId			BIGINT,
		MatchCode		VARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		Status			NVARCHAR(50),
		Stake			MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		TransDate		DATETIME,
		BetTeam			NVARCHAR(50),
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LeagueId		INT,
		MatchId			INT, 
		Ip				VARCHAR(30),
		IsNeutral		BIT,
		WinLostDate		DATETIME,
		Currency		SMALLINT,
		IsBA			INT,
		StakeUSD		MONEY,
		WinLostUSD		MONEY,
		LicenseeWLUSD	MONEY,
		CommUSD			MONEY,
		PlayerCommUSD	MONEY,
		StakeEUR		MONEY,
		WinLostEUR		MONEY,
		LicenseeWLEUR	MONEY,
		CommEUR			MONEY,
		PlayerCommEUR	MONEY,
		StakeGBP		MONEY,
		WinLostGBP		MONEY,
		LicenseeWLGBP	MONEY,
		CommGBP			MONEY,
		PlayerCommGBP	MONEY
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
		@WinLostDate = b.winlostdate
	FROM bodb02.dbo.bettrans14 AS b WITH (NOLOCK)
	WHERE b.bettype = 10
		AND b.currency IN (SELECT DISTINCT Currency FROM @Temp)
		AND b.recommend IN (SELECT DISTINCT AgentId FROM @Temp)
		AND b.ruben = 1
		AND b.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay

	IF @TransId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Lrf_BetList_MatchWL_Outright] 
							@AgentList = ''' + CONVERT(VARCHAR(MAX), @AgentList) + ''',
							@ShowSB = 1,
							@ShowBA = 1,
							@FromDate = ''' + CONVERT(VARCHAR(10), @WinLostDate, 23) + ''',
							@ToDate = ''' + CONVERT(VARCHAR(10), @WinLostDate, 23) + ''',
							@MoveBetsDay = ''' + CONVERT(VARCHAR(10), @MoveBetsDay, 23) + ''''

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
