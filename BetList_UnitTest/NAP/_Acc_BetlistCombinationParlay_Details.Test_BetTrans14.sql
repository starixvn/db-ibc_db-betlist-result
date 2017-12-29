USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Acc_BetlistCombinationParlay_Details].[Test_BetTrans14]    Script Date: 8/2/2016 1:50:08 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Acc_BetlistCombinationParlay_Details].[Test_BetTrans14]
AS
BEGIN
	SET NOCOUNT ON

	-- Arrange
	DECLARE @Data TABLE (
		WinLostDate	SMALLDATETIME,
		TransId		BIGINT,
		Serial		BIGINT,
		StatusId	INT,
		Status		NVARCHAR(50),
		Modds		MONEY,
		Stake		MONEY,
		WinLost		MONEY,
		PlayComm	MONEY
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

	DECLARE @TransId		BIGINT,
		@RefNo				BIGINT,
		@CustID				INT,
		@Stake				MONEY,
		@OutstandingStake	MONEY

	SELECT TOP(1)
		@TransId = b.transid,
		@RefNo = b.refno,
		@CustID = b.custid,
		@Stake = b.stake
	FROM bodb02.dbo.bettrans14 AS b WITH (NOLOCK)
	WHERE b.bettype = 29
		AND b.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay

	IF @TransId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Acc_BetlistCombinationParlay_Details] 
							@RefNo = ' + CONVERT(VARCHAR(20), @RefNo) + ',
							@CustId = ' + CONVERT(VARCHAR(10), @CustID) + ',
							@MoveBetDay = ''' + CONVERT(VARCHAR(10), @MoveBetsDay, 23) + ''',
							@BalanceUpDay = ''' + CONVERT(VARCHAR(10), @BalanceUpDay, 23) + ''''

		INSERT @Data
		EXEC tSQLt.ResultSetFilter
			@ResultsetNo = 1,
			@Command = @Command;

		EXEC bodb02.dbo.[Acc_BetlistCombinationParlay_Details] 
			@RefNo = @RefNo,
			@CustId = @CustID,
			@MoveBetDay = @MoveBetsDay,
			@BalanceUpDay = @BalanceUpDay,
			@Outstanding = @OutstandingStake OUTPUT

		DECLARE @SettledStake MONEY
		DECLARE @SumStake MONEY

		SELECT @SettledStake = SUM(Stake)
		FROM @Data

		SET @SumStake = @SettledStake + @OutstandingStake

		-- Assert
		EXEC tSQLt.AssertEquals
			@Expected = @Stake,
			@Actual = @SumStake,
			@Message = @Command
	END
	ELSE
	BEGIN
		EXEC tSQLt.Fail @Message0 = 'No available test data'
	END
END;

GO
