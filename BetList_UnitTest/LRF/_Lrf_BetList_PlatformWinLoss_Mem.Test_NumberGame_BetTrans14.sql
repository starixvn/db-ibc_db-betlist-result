USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Lrf_BetList_PlatformWinLoss_Mem].[Test_NumberGame_BetTrans14]    Script Date: 1/12/2017 2:07:37 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Lrf_BetList_PlatformWinLoss_Mem].[Test_NumberGame_BetTrans14]
AS
BEGIN
	-- Arrange
	DECLARE @Data TABLE (
		RowNum			INT,
		SportType		INT,
		TransId			BIGINT,
		BetId			BIGINT,
		BetType			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Modds			MONEY,
		OddsType		TINYINT,
		Odds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		BetTeam			NVARCHAR(20),
		Status			NVARCHAR(10),
		RefNo			BIGINT,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		WinLost			MONEY,
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
		VirtualRate		FLOAT,
		IsShowOTExRate	BIT,
		Currency		INT,
		ShowTime		NVARCHAR(50),
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(300),
		StakeMYR		MONEY,
		Actual_StakeMYR	MONEY,
		WinLostMYR		MONEY,
		LicenseeWLMYR	MONEY,
		CommMYR			MONEY,
		PlayerCommMYR	MONEY,
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
		@CustId			INT,
		@TransId		BIGINT,
		@CurrencyId		INT,
		@BetFrom		NVARCHAR(1),
		@PlatformType	TINYINT,
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
		@CurrencyId = b.currency,
		@BetFrom = b.betfrom,
		@PlatformType = CASE 
							WHEN b.betfrom = 'd' THEN 1
							WHEN b.betfrom = 'a' THEN 2
							WHEN b.betfrom IN ('e','u') THEN 3
							WHEN b.betfrom = 'm' THEN 4
							WHEN b.betfrom IN ('s','l') THEN 5
							ELSE 1
						END,
		@WinLostDate = b.winlostdate
	FROM bodb02.dbo.bettrans14 AS b WITH (NOLOCK)
		INNER JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON b.custid = c.custid
		INNER JOIN bodb02.dbo.SportBettypeMatrix AS s WITH (NOLOCK) ON b.bettype = s.BetType
	WHERE s.ProductID = 3
		AND b.currency IN (SELECT CurrencyId FROM #Currency)
		AND b.recommend IN (SELECT CustId FROM @TempAg)
		AND b.statusID IN (111, 112, 113)
		AND b.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay

	DROP TABLE #Currency

	IF @TransId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Lrf_BetList_PlatformWinLoss_Mem] 
							@LicenseeID = ' + CONVERT(VARCHAR, @LicenseeId) + ',
							@UserID = ' + CONVERT(VARCHAR, @UserId) + ',
							@CustID = ' + CONVERT(VARCHAR, @CustId) + ',
							@CurrencyId = ' + CONVERT(VARCHAR, @CurrencyId) + ',
							@ShowNG = 1,
							@PlatformType = ' + CONVERT(VARCHAR, @PlatformType) + ',
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

