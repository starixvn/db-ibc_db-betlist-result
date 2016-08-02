USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Acc_BetList_SelBettype].[Test_ColossusBets_Translog]    Script Date: 1/10/2017 8:47:51 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Acc_BetList_SelBettype].[Test_ColossusBets_Translog]
AS
BEGIN
	-- Arrange
	DECLARE @Data TABLE (
		TypeId			INT,
		Typenamee		NVARCHAR(50)
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

	DECLARE @CustId		INT,
		@BetType		INT,
		@WinLostDate	SMALLDATETIME

	SELECT TOP 1
		@CustId = b.custid,
		@BetType = b.gameID,
		@WinLostDate = b.winlostdate
	FROM bodb02.dbo.translog AS b WITH (NOLOCK)
		INNER JOIN bodb02.dbo.SportBettypeMatrix AS s WITH (NOLOCK) ON b.gameID = s.BetType
	WHERE s.ProductID = 15
		AND b.statusID IN (0, 1)
		AND b.winlostdate > @MoveBetsDay

	IF @BetType IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Acc_BetList_SelBettype] 
							@CustId = ' + CONVERT(VARCHAR, @CustId) + ',
							@FromDate = ''' + CONVERT(VARCHAR, @WinLostDate, 23) + ''',
							@ToDate = ''' + CONVERT(VARCHAR, @WinLostDate, 23) + ''',
							@MoveBetsDay = ''' + CONVERT(VARCHAR, @MoveBetsDay, 23) + ''',
							@BalanceUpDay = ''' + CONVERT(VARCHAR, @BalanceUpDay, 23) + ''''

		INSERT @Data
		EXEC tSQLt.ResultSetFilter 1, @Command

		DECLARE @Expected INT

		SELECT @Expected = COUNT(*)
		FROM @Data
		WHERE TypeId = @BetType

		-- Assert
		EXEC tSQLt.AssertEquals 1, @Expected, @Command
	END
	ELSE
	BEGIN
		EXEC tSQLt.Fail 'No available test data'
	END
END;
