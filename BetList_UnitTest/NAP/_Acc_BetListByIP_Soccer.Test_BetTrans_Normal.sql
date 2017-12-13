USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Acc_BetListByIP_Soccer].[Test_BetTrans_Normal]    Script Date: 1/12/2017 1:45:20 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Acc_BetListByIP_Soccer].[Test_BetTrans_Normal]
AS
BEGIN
	SET NOCOUNT ON

	-- Arrange
	DECLARE @Data TABLE (
		FinalHomeScore	INT,
		FinalAwayScore	INT,
		OddsId			INT,
		LeagueId		INT,
		MatchId			INT,
		BetType			SMALLINT,
		TransId			BIGINT,
		BetId			BIGINT,
		RefNo			BIGINT,
		MatchCode		NVARCHAR(50),
		Race			NVARCHAR(50), 
		EventDate		DATETIME,
		VirtualRate		FLOAT,
		IsShowOTExRate	BIT,
		SDiscount		DECIMAL(9, 8),
		ADiscount		DECIMAL(9, 8),
		Discount		DECIMAL(9, 8),
		HomeId			INT,
		AwayId			INT,
		SettleTime		DATETIME,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		FinalOdds		MONEY,
		FinalOdds2		MONEY,
		MOdds			MONEY,
		OddsType		INT, 
		Status			NVARCHAR(50),
		ComStatus		NVARCHAR(20),
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
		LiveHomeScore	INT,
		LiveAwayScore	INT,
		LiveIndicator	BIT,
		WinLost			MONEY, 
		Commission		MONEY, 
		SComm			MONEY,
		AComm			MONEY,
		Comm			MONEY,
		AWinLost		MONEY,
		MWinLost		MONEY,
		SWinLost		MONEY,
		Creator			VARCHAR(50),
		Username		NVARCHAR(50),
		HtHomeScore		INT,
		HtAwayScore		INT,
		Ip				NVARCHAR(15),
		BetFrom			NVARCHAR(1),
		SportType		INT,
		IsNeutral		BIT,
		ShowTime		NVARCHAR(50),
		WinLostDate		SMALLDATETIME,
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(300),
		OddsSpread		SMALLMONEY,
		OriginalBetType	INT,
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000)
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
		@Ip				VARCHAR(15),
		@WinLostDate	DATETIME

	SELECT TOP(1)
		@TransId = b.transid,
		@CustId = b.custid,
		@Ip = b.ip,
		@WinLostDate = b.winlostdate
	FROM bodb02.dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
		INNER JOIN bodb02.dbo.league AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
		INNER JOIN bodb02.dbo.custInfo AS c WITH (NOLOCK) ON c.custid = b.creator
		INNER JOIN bodb02.dbo.sports AS s WITH (NOLOCK) ON l.sporttype = s.sporttype 
	WHERE m.sporttype = 1

	IF @TransId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Acc_BetListByIP_Soccer]
							@CustId = ' + CONVERT(VARCHAR(10), @CustId) + ',
							@Ip = ''' + @Ip + ''',
							@FromDate = ''' + CONVERT(VARCHAR(10), @WinLostDate, 23) + ''''

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
