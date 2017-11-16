USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Acc_BetlistCombinationParlay_ByTransID].[Test_BetTrans]    Script Date: 8/2/2016 1:45:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Acc_BetlistCombinationParlay_ByTransID].[Test_BetTrans]
AS
BEGIN
	SET NOCOUNT ON

	-- Arrange
	DECLARE @Data TABLE (
		TransId			BIGINT,
		TransDate		DATETIME,
		RefNo			BIGINT,
		WinLostDate		SMALLDATETIME,
		Odds			MONEY,
		Modds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		PlayComm		MONEY,
		Status			NVARCHAR(50),
		ComStatus		NVARCHAR(20),
		BetTeam			VARCHAR(20),
		IP				VARCHAR(40),
		SPositionTaking	SMALLMONEY,
		MPositionTaking	SMALLMONEY,
		APositionTaking	SMALLMONEY,
		SWinLost		MONEY,
		MWinLost		MONEY,
		AWinLost		MONEY,
		SDiscount		SMALLMONEY,
		ADiscount		SMALLMONEY,
		Discount		SMALLMONEY,
		SComm			MONEY,
		AComm			MONEY,
		Comm			MONEY,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		BetCheck		NVARCHAR(50)
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

	DECLARE @TransId	BIGINT,
		@CustId			INT

	SELECT TOP(1)
		@TransId = b.transid,
		@CustId = b.custid
	FROM bodb02.dbo.bettrans AS b WITH (NOLOCK)
	WHERE b.bettype = 29

	IF @TransId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Acc_BetlistCombinationParlay_ByTransID] 
							@TransId = ' + CONVERT(VARCHAR(20), @TransId) + ',
							@CustId = ' + CONVERT(VARCHAR(10), @CustId) + ',
							@MoveBetDay = ''' + CONVERT(VARCHAR, @MoveBetsDay, 23) + ''',
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

GO
