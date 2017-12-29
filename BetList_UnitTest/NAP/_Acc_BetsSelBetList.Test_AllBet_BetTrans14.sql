USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Acc_BetsSelBetList].[Test_ColossusBets_BetTrans14]    Script Date: 1/10/2017 9:26:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Acc_BetsSelBetList].[Test_AllBet_BetTrans14]
AS
BEGIN
	SET NOCOUNT ON

	-- Arrange
	DECLARE @Data TABLE (
		BetType			INT,
		TransId			BIGINT,
		BetId			BIGINT,
		RefNo			NVARCHAR(50),
		MatchCode		NVARCHAR(50),
		Race			NVARCHAR(20),
		EventDate		SMALLDATETIME,
		VirtualRate		FLOAT,
		IsShowOTExRate	BIT,
		SDiscount		SMALLMONEY,
		ADiscount		SMALLMONEY,
		Discount		SMALLMONEY,
		HomeId			INT,
		AwayId			INT,
		SettleTime		DATETIME,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		FinalOdds		MONEY,
		FinalOdds2		MONEY,
		OddsType		TINYINT,
		Status			NVARCHAR(50),
		ComStatus		NVARCHAR(50),
		Stake			MONEY,
		Actual_Stake	MONEY,
		TransDate		DATETIME,
		BetTeam			NVARCHAR(50),
		SPositionTaking SMALLMONEY,
		MPositionTaking SMALLMONEY,
		APositionTaking SMALLMONEY,
		SPositionTaking2 SMALLMONEY,
		MPositionTaking2 SMALLMONEY,
		APositionTaking2 SMALLMONEY,
		LiveIndicator	 BIT,
		Modds			MONEY,
		CustId			INT,
		LiveHomeScore	INT,
		LiveAwayScore	INT,
		FinalHomeScore	INT,
		FinalAwayScore	INT,
		LeagueId		INT,
		SportType		SMALLINT,
		Ip				NVARCHAR(15),
		BetFrom			NVARCHAR(1),
		MatchId			INT,
		IsNeutral		BIT,
		AllowDelete		BIT,
		WinLost			MONEY,
		Commission		MONEY,
		SComm			MONEY,
		AComm			MONEY,
		Comm			MONEY,
		AWinLost		MONEY,
		MWinLost		MONEY,
		SWinLost		MONEY,
		ShowTime		NVARCHAR(50),
		WinLostDate		SMALLDATETIME,
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(300),
		OddsSpread		SMALLMONEY,
		OriginalBetType	INT,
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000),
		Currency		NVARCHAR(50)
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
		@CustId			INT,
		@WinLostDate	DATETIME,
		@BetType		SMALLINT

	SELECT TOP(1)
		@TransId = b.transid,
		@WinLostDate = b.winlostdate,
		@CustId = b.custid,
		@BetType = b.bettype
	FROM bodb02.dbo.bettrans14 AS b WITH (NOLOCK)
	WHERE b.bettype BETWEEN 2401 AND 2405
		AND b.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay

	IF @TransId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Acc_BetsSelBetList] 
							@CustID = ' + CONVERT(VARCHAR(10), @CustId, 11) + ',
							@Bettype = ' + CONVERT(VARCHAR(5), @BetType, 6) + ',
							@MoveBetsDay = ''' + CONVERT(VARCHAR(10), @MoveBetsDay, 23) + ''',
							@FromDate = ''' + CONVERT(VARCHAR(10), @WinLostDate, 23) + ''',
							@ToDate = ''' + CONVERT(VARCHAR(10), @WinLostDate, 23) + ''''

		INSERT @Data
		EXEC tSQLt.ResultSetFilter 
			@ResultsetNo = 1,
			@Command = @Command;

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
