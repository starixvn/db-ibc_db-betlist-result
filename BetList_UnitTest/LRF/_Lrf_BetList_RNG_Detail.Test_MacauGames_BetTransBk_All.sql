USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Lrf_BetList_RNG_Detail].[Test_MacauGames_BetTransBk_All]    Script Date: 2/13/2017 1:39:21 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Lrf_BetList_RNG_Detail].[Test_MacauGames_BetTransBk_All]
AS
BEGIN
	SET NOCOUNT ON

	-- Arrange
	DECLARE @Data TABLE (
		TransId			BIGINT,
		SportType		SMALLINT,
		BetType			SMALLINT,
		TransDate		DATETIME,
		WinLostDate		SMALLDATETIME,
		Status			VARCHAR(10),
		StatusId		TINYINT,
		Odds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		LicenseeWL 		MONEY,
		Comm			MONEY,
		PlayComm		MONEY,
		IP				NVARCHAR(15),
		TransDesc		NVARCHAR(1000),
		BetCheck		NVARCHAR(50),
		MatchCode		VARCHAR(50),
		Currency		NVARCHAR(50),
		StakeUSD		MONEY,
		StakeEUR		MONEY,
		StakeMYR		MONEY,
		StakeGBP		MONEY,
		WinLostUSD		MONEY,
		WinLostEUR		MONEY,
		WinLostMYR		MONEY,
		WinLostGBP		MONEY,
		LicenseeWLUSD	MONEY,
		LicenseeWLEUR	MONEY,
		LicenseeWLMYR	MONEY,
		LicenseeWLGBP	MONEY,
		CommUSD			MONEY,
		CommEUR			MONEY,
		CommMYR			MONEY,
		CommGBP			MONEY,
		PlayerCommUSD	MONEY,
		PlayerCommEUR	MONEY,
		PlayerCommMYR	MONEY,
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
		@RefNo			BIGINT,
		@CustID			INT,
		@TransType		TINYINT = 0

	SELECT CurrencyId, LicenseeId
	INTO #Currency
	FROM bodb02.dbo.Lrf_f_GetCurrencybyUser(@LicenseeId, @UserId, 1)

	DECLARE @TempAg AS TABLE (CustId INT)

	INSERT INTO @TempAg
	SELECT DISTINCT lc.CustID
	FROM bodb_Licensee.dbo.f_SelLicenseeCust(0) AS lc
		INNER JOIN #Currency AS c ON lc.LicenseeID = c.LicenseeId AND lc.Currency = c.CurrencyId

	SELECT TOP(1)
		@RefNo = b.transid,
		@CustID = b.custid,
		@TransId = brng.transid
	FROM DBARC.bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
		INNER JOIN DBARC.bodb_Archive.dbo.bettransRnG_bk AS brng WITH (NOLOCK) ON brng.refno = b.transid
		INNER JOIN bodb02.dbo.SportBettypeMatrix AS s WITH (NOLOCK) ON b.bettype = s.BetType
	WHERE s.ProductID = 22
		AND b.currency IN (SELECT CurrencyId FROM #Currency)
		AND b.recommend IN (SELECT CustId FROM @TempAg)

	IF @TransId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Lrf_BetList_RNG_Detail]
							@LicenseeID = ' + CONVERT(VARCHAR, @LicenseeId) + ',
							@UserID = ' + CONVERT(VARCHAR, @UserId) + ',
							@RefNo = ' + CONVERT(VARCHAR, @RefNo) + ',
							@CustId = ' + CONVERT(VARCHAR, @CustID) + ',
							@TransType = ' + CONVERT(VARCHAR, @TransType) + ',
							@MoveBetsDay = ''' + CONVERT(VARCHAR, @MoveBetsDay, 23) + ''',
							@BalanceUpDay = ''' + CONVERT(VARCHAR, @BalanceUpDay, 23) + ''''

		INSERT @Data
		EXEC tSQLt.ResultSetFilter 1, @Command;

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

GO
