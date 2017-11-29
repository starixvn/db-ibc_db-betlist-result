USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Lrf_BetList_MatchWL_Racing].[Test_BetTrans]    Script Date: 12/1/2017 10:12:34 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Lrf_BetList_MatchWL_Racing].[Test_BetTrans]
AS
BEGIN
	SET NOCOUNT ON

	-- Arrange
	DECLARE @Data TABLE (
		RowNum			INT,
		SportType		SMALLINT,
		Username		NVARCHAR(50),
		NickName		NVARCHAR(50),
		CustId			INT,
		BetType			SMALLINT,
		Transid			BIGINT,
		Race			VARCHAR(50),
		MatchCode		VARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Modds			MONEY,
		Odds			MONEY,
		Status			NVARCHAR(50),
		Stake			MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		Discount		MONEY,
		TransDate		DATETIME,
		BetTeam			NVARCHAR(25),
		APositionTaking	SMALLMONEY,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LeagueId		INT,
		MatchId			INT,
		Ip				VARCHAR(30),
		BetStatus		VARCHAR(50),
		IsNeutral		BIT,
		WinLostDate		DATETIME,
		Currency		SMALLINT,
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

	DECLARE @LicenseeId	INT		= 1,	-- 12Bet
		@UserId			INT		= 68,
		@TransId		BIGINT,
		@BetType		INT,
		@LeagueId		INT,
		@RaceNo			VARCHAR(50),
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
		@LeagueId = l.leagueid,
		@RaceNo = m.groupmatch,
		@WinLostDate = b.winlostdate
	FROM bodb02.dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN bodb02.dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
		INNER JOIN bodb02.dbo.League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
		INNER JOIN bodb02.dbo.customer AS c WITH (NOLOCK) ON c.custid = b.custid
	WHERE b.bettype = 10
		AND b.currency IN (SELECT CurrencyId FROM #Currency)
		AND b.recommend IN (SELECT CustId FROM @TempAg)
		AND b.ruben = 1
		AND m.groupmatch IS NOT NULL

	DROP TABLE #Currency

	IF @TransId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Lrf_BetList_MatchWL_Racing] 
							@AgentList = ''' + CONVERT(VARCHAR(MAX), @AgentList) + ''', 
							@Bettype = ' + CONVERT(VARCHAR(5), @BetType) + ',
							@LeagueId = ' + CONVERT(VARCHAR(10), @LeagueId) + ',
							@RaceNo = ''' + CONVERT(VARCHAR(50), @RaceNo) + ''',
							@FromDate = ''' + CONVERT(VARCHAR, @WinLostDate, 23) + ''',
							@ToDate = ''' + CONVERT(VARCHAR, @WinLostDate, 23) + ''',
							@MoveBetsDay = ''' + CONVERT(VARCHAR, @MoveBetsDay, 23) + ''''

							PRINT @Command

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
