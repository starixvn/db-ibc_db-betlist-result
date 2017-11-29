USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Lrf_BetList_SelWinLossByBetType].[Test_NumberGame_BetTrans]    Script Date: 1/12/2017 1:15:58 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Lrf_BetList_SelWinLossByBetType].[Test_NumberGame_BetTrans]
AS
BEGIN
	SET NOCOUNT ON

	-- Arrange
	DECLARE @Data TABLE (
		RowNum				INT,
		TransId				BIGINT,
		RefNo				BIGINT,
		BetId				BIGINT,
		CustId				INT,
		Username			NVARCHAR(50),
		SportType			INT,
		BetType				INT,
		Currency			SMALLINT,
		LeagueId			INT,
		MatchId				INT,
		MatchCode			VARCHAR(50),
		IsNeutral			BIT,
		HomeId				INT,
		AwayId				INT,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		BetTeam				NVARCHAR(10),
		Odds				MONEY,
		OddsType			TINYINT,
		Modds				MONEY,
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		ShowTime			NVARCHAR(50),
		Status				NVARCHAR(10),
		BetStatus			NVARCHAR(50),
		TransDate			DATETIME,
		WinLostDate			DATETIME,
		Stake				MONEY,
		Actual_Stake		MONEY,
		WinLost				MONEY,
		LicenseeWL			MONEY,
		Comm				MONEY,
		PlayerComm			MONEY,
		Race				VARCHAR(20),
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(300),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		Nickname			NVARCHAR(50),
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
	FROM bodb02.dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON b.custid = c.custid
		INNER JOIN bodb02.dbo.SportBettypeMatrix AS s WITH (NOLOCK) ON b.bettype = s.BetType
	WHERE s.ProductID = 3
		AND b.currency IN (SELECT CurrencyId FROM #Currency)
		AND b.recommend IN (SELECT CustId FROM @TempAg)
		AND b.statusID NOT IN (0, 1, 101, 102, 103)

	DROP TABLE #Currency

	IF @TransId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Lrf_BetList_SelWinLossByBetType] 
							@AgentList = ''' + CONVERT(VARCHAR(MAX), @AgentList) + ''',
							@Bettype = ' + CONVERT(VARCHAR(5), @BetType) + ',
							@FromDate = ''' + CONVERT(VARCHAR, @WinLostDate, 23) + ''',
							@ToDate = ''' + CONVERT(VARCHAR, @WinLostDate, 23) + ''',
							@MoveBetsDay = ''' + CONVERT(VARCHAR, @MoveBetsDay, 23) + ''',
							@BalanceUpDay = ''' + CONVERT(VARCHAR, @BalanceUpDay, 23) + ''''

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
