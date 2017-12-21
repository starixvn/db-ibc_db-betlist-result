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
	SET NOCOUNT ON

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

	DECLARE @LicenseeId		INT		= 26,	-- Athena000
		@UserId				INT		= 68,
		@TransId			BIGINT,
		@RefNo				BIGINT,
		@CustID				INT,
		@Stake				MONEY,
		@OutstandingStake	MONEY

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

	SELECT TOP(1)
		@TransId = b.transid,
		@RefNo = b.refno,
		@CustID = b.custid,
		@Stake = b.stake
	FROM bodb02.dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN bodb02.dbo.bettransm AS bm WITH (NOLOCK) ON b.refno = bm.refno
		INNER JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON bm.matchid = m.matchid
	WHERE b.bettype = 29
		AND b.currency IN (SELECT Currency FROM @Temp)
		AND b.recommend IN (SELECT AgentId FROM @Temp)

	IF @TransId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Lrf_BetList_SelCombinationParlayDetail] 
							@AgentList = ''' + CONVERT(VARCHAR(MAX), @AgentList) + ''',
							@RefNo = ' + CONVERT(VARCHAR(20), @RefNo) + ',
							@MoveBetsDay = ''' + CONVERT(VARCHAR(10), @MoveBetsDay, 23) + ''',
							@BalanceUpDay = ''' + CONVERT(VARCHAR(10), @BalanceUpDay, 23) + ''''

		INSERT @Data
		EXEC tSQLt.ResultSetFilter
			@ResultsetNo = 1,
			@Command = @Command

		EXEC bodb02.dbo.[Lrf_BetList_SelCombinationParlayDetail] 
			@AgentList = @AgentList,
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
