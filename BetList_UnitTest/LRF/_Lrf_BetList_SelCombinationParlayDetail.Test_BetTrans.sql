USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Lrf_BetList_SelCombinationParlayDetail].[Test_BetTrans]    Script Date: 1/11/2017 1:10:52 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Lrf_BetList_SelCombinationParlayDetail].[Test_BetTrans]
AS
BEGIN
	-- Arrange
	DECLARE @Data TABLE (
		[Order]			INT,
		WinLostDate		SMALLDATETIME,
		TransId			BIGINT,
		Serial			BIGINT,
		StatusId		INT,
		Status			NVARCHAR(50),
		Modds			MONEY,
		Stake			MONEY,
		StakeUSD		MONEY,
		StakeEUR		MONEY,
		StakeMYR		MONEY,
		StakeGBP		MONEY,
		WinLost			MONEY,
		WinLostUSD		MONEY,
		WinLostEUR		MONEY,
		WinLostMYR		MONEY,
		WinLostGBP		MONEY,
		Comm			MONEY,
		CommUSD			MONEY,
		CommEUR			MONEY,
		CommMYR			MONEY,
		CommGBP			MONEY,
		PlayComm		MONEY,
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

	DECLARE @LicenseeId		INT		= 1,	-- 12Bet
		@UserId				INT		= 68,
		@TransId			BIGINT,
		@RefNo				BIGINT,
		@CustID				INT,
		@Stake				MONEY,
		@OutstandingStake	MONEY

	SELECT CurrencyId, LicenseeId
	INTO #Currency
	FROM bodb02.dbo.Lrf_f_GetCurrencybyUser(@LicenseeId, @UserId, 1)

	DECLARE @TempAg AS TABLE (CustId INT)

	INSERT INTO @TempAg
	SELECT DISTINCT CustId
	FROM bodb_Licensee.dbo.f_SelLicenseeCust(0) AS lc
		INNER JOIN #Currency AS c ON lc.LicenseeID = c.LicenseeId AND lc.Currency = c.CurrencyId

	SELECT TOP 1
		@TransId = b.transid,
		@RefNo = b.refno,
		@CustID = b.custid,
		@Stake = b.stake
	FROM bodb02.dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN bodb02.dbo.bettransm AS bm WITH (NOLOCK) ON b.refno = bm.refno
		INNER JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON bm.matchid = m.matchid
	WHERE b.bettype = 29
		AND b.currency IN (SELECT CurrencyId FROM #Currency)
		AND b.recommend IN (SELECT CustId FROM @TempAg)

	IF @TransId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Lrf_BetList_SelCombinationParlayDetail] 
							@LicenseeID = ' + CONVERT(VARCHAR, @LicenseeId) + ',
							@UserID = ' + CONVERT(VARCHAR, @UserId) + ',
							@RefNo = ' + CONVERT(VARCHAR, @RefNo) + ',
							@MoveBetsDay = ''' + CONVERT(VARCHAR, @MoveBetsDay, 23) + ''',
							@BalanceUpDay = ''' + CONVERT(VARCHAR, @BalanceUpDay, 23) + ''''

		INSERT @Data
		EXEC tSQLt.ResultSetFilter 1, @Command;

		EXEC bodb02.dbo.[Lrf_BetList_SelCombinationParlayDetail] 
			@LicenseeID = @LicenseeId,
			@UserID = @UserId,
			@RefNo = @RefNo,
			@MoveBetsDay = @MoveBetsDay,
			@BalanceUpDay = @BalanceUpDay,
			@Outstanding = @OutstandingStake OUTPUT

		DECLARE @SettledStake MONEY
		DECLARE @SumStake MONEY

		SELECT @SettledStake = SUM(Stake)
		FROM @Data

		SET @SumStake = @SettledStake + @OutstandingStake

		-- Assert
		EXEC tSQLt.AssertEquals @Stake, @SumStake, @Command
	END
	ELSE
	BEGIN
		EXEC tSQLt.Fail 'No available test data'
	END

END;

GO
