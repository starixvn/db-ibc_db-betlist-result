USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Lrf_BetList_MatchWL_Parlay].[Test_Sportsbook_BetTrans14_SystemParlay]    Script Date: 12/1/2017 10:10:51 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Lrf_BetList_MatchWL_Parlay].[Test_Sportsbook_BetTrans14_SystemParlay]
AS
BEGIN
	SET NOCOUNT ON

	-- Arrange
	DECLARE @Data TABLE (
		RowNum			INT,
		Username		NVARCHAR(50),
		Nickname		VARCHAR(50),
		CustId			INT,
		BetType			SMALLINT,
		RefNo			NVARCHAR(50),
		TransId			BIGINT,
		BetId			BIGINT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		Modds			MONEY,
		Status			NVARCHAR(50),
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		BetTeam			NVARCHAR(25),
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				VARCHAR(30),
		IsNeutral		BIT,
		Currency		SMALLINT,
		IsBA			INT,
		AWinLost		MONEY,
		BetCheck		NVARCHAR(50),
		BetStatus		NVARCHAR(50),
		MatchCode		VARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		LeagueId		INT,
		MatchId			INT,
		SportType		INT,
		StakeUSD		MONEY,
		Actual_StakeUSD	MONEY,
		WinLostUSD		MONEY,
		LicenseeWLUSD	MONEY,
		CommUSD			MONEY,
		PlayerCommUSD	MONEY,
		StakeEUR		MONEY,
		Actual_StakeEUR	MONEY,
		WinLostEUR		MONEY,
		LicenseeWLEUR	MONEY,
		CommEUR			MONEY,
		PlayerCommEUR	MONEY,
		StakeGBP		MONEY,
		Actual_StakeGBP	MONEY,
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

	DECLARE @LicenseeId	INT		= 1,	-- 12Bet
		@UserId			INT		= 68,
		@TransId		BIGINT,
		@BetType		INT,
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

	SELECT CurrencyId, LicenseeId
	INTO #Currency
	FROM bodb02.dbo.Lrf_f_GetCurrencybyUser(@LicenseeId, @UserId, 1)

	DECLARE @TempAg AS TABLE (CustId INT)

	INSERT INTO @TempAg
	SELECT DISTINCT lc.CustID
	FROM bodb_Licensee.dbo.f_SelLicenseeCust(0) AS lc
		INNER JOIN #Currency AS c ON lc.LicenseeID = c.LicenseeId AND lc.Currency = c.CurrencyId

	SELECT TOP(1)
		@TransId = b.transid,
		@BetType = b.bettype,
		@WinLostDate = b.winlostdate
	FROM bodb02.dbo.bettrans14 AS b WITH (NOLOCK)
	WHERE b.bettype = 29
		AND b.currency IN (SELECT CurrencyId FROM #Currency)
		AND b.recommend IN (SELECT CustId FROM @TempAg)
		AND b.statusID IN (111, 112, 113)
		AND b.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay

	DROP TABLE #Currency

	IF @TransId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Lrf_BetList_MatchWL_Parlay] 
							@AgentList = ''' + CONVERT(VARCHAR(MAX), @AgentList) + ''', 
							@Bettype = ' + CONVERT(VARCHAR(5), @BetType) + ',
							@ShowSB = 1,
							@ShowBA = 1,
							@FromDate = ''' + CONVERT(VARCHAR, @WinLostDate, 23) + ''',
							@ToDate = ''' + CONVERT(VARCHAR, @WinLostDate, 23) + ''',
							@MoveBetsDay = ''' + CONVERT(VARCHAR, @MoveBetsDay, 23) + ''''

		INSERT @Data
		EXEC tSQLt.ResultSetFilter 1, @Command

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
