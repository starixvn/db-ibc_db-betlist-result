USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Lrf_BetList_SelWinLossByDate_Mem].[Test_MicrogamingLiveCasino_BetTrans14]    Script Date: 2/13/2017 10:38:18 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Lrf_BetList_SelWinLossByDate_Mem].[Test_MicrogamingLiveCasino_BetTrans14]
AS
BEGIN
	-- Arrange
	DECLARE @Data TABLE (
		RowNum			INT,
		SportType		SMALLINT,
		Username		NVARCHAR(20),
		TransId			BIGINT,
		BetId			BIGINT,
		BetType			SMALLINT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		OddsType		TINYINT,
		Odds			MONEY,
		Modds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		BetTeam			NVARCHAR(20),
		Status			NVARCHAR(10),
		RefNo			BIGINT,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		WinLost			MONEY,
		BetEffective	MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				NVARCHAR(15),
		LeagueId		INT,
		MatchId			INT,
		MatchCode		NVARCHAR(50),
		Race			NVARCHAR(20),
		HomeId			INT,
		AwayId			INT,
		BetStatus		NVARCHAR(50),
		IsNeutral		BIT,
		Currency		SMALLINT,
		ShowTime		NVARCHAR(50), -- table - shoe - hand of Live Casino
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(300),
		StakeUSD		MONEY,
		Actual_StakeUSD	MONEY,
		WinLostUSD		MONEY,
		BetEffectiveUSD	MONEY,
		LicenseeWLUSD	MONEY,
		CommUSD			MONEY,
		PlayerCommUSD	MONEY,
		StakeEUR		MONEY,
		Actual_StakeEUR	MONEY,
		WinLostEUR		MONEY,
		BetEffectiveEUR	MONEY,
		LicenseeWLEUR	MONEY,
		CommEUR			MONEY,
		PlayerCommEUR	MONEY,
		StakeGBP		MONEY,
		Actual_StakeGBP	MONEY,
		WinLostGBP		MONEY,
		BetEffectiveGBP	MONEY,
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
		@CustId			INT,
		@TransId		BIGINT,
		@BetType		INT,
		@WinLostDate	SMALLDATETIME

	SELECT CurrencyId, LicenseeId
	INTO #Currency
	FROM bodb02.dbo.Lrf_f_GetCurrencybyUser(@LicenseeId, @UserId, 1)

	DECLARE @TempAg AS TABLE (CustId INT)

	INSERT INTO @TempAg
	SELECT DISTINCT CustID
	FROM OPENQUERY(DBLIC, 'SELECT * FROM bodb_licensee.dbo.f_SelLicenseeCust(0)') lc
		INNER JOIN #currency AS c ON lc.LicenseeID = c.LicenseeID AND lc.Currency = c.CurrencyID

	SELECT TOP 1
		@TransId = b.transid,
		@CustId = b.custid,
		@BetType = b.bettype,
		@WinLostDate = b.winlostdate
	FROM bodb02.dbo.bettrans14 AS b WITH (NOLOCK)
		INNER JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON b.custid = c.custid
		INNER JOIN bodb02.dbo.SportBettypeMatrix AS s WITH (NOLOCK) ON b.bettype = s.BetType
	WHERE s.ProductID = 13
		AND b.currency IN (SELECT CurrencyId FROM #Currency)
		AND b.recommend IN (SELECT CustId FROM @TempAg)
		AND b.statusID IN (111, 112, 113)
		AND b.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay

	DROP TABLE #Currency

	IF @TransId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Lrf_BetList_SelWinLossByDate_Mem] 
							@LicenseeID = ' + CONVERT(VARCHAR, @LicenseeId) + ',
							@UserID = ' + CONVERT(VARCHAR, @UserId) + ',
							@CustID = ' + CONVERT(VARCHAR, @CustId) + ',
							@ShowMGCLC = 1,
							@FromDate = ''' + CONVERT(VARCHAR, @WinLostDate, 23) + ''',
							@ToDate = ''' + CONVERT(VARCHAR, @WinLostDate, 23) + ''',
							@MoveBetsDay = ''' + CONVERT(VARCHAR, @MoveBetsDay, 23) + ''',
							@BalanceUpDay = ''' + CONVERT(VARCHAR, @BalanceUpDay, 23) + ''''

		INSERT @Data
		EXEC tSQLt.ResultSetFilter 1, @Command

		DECLARE @Expected INT

		SELECT @Expected = COUNT(*)
		FROM @Data
		WHERE TransId = @TransId

		-- Assert
		EXEC tSQLt.AssertEquals 1, @Expected, @Command
	END
	ELSE
	BEGIN
		EXEC tSQLt.Fail 'No available test data'
	END
END;

