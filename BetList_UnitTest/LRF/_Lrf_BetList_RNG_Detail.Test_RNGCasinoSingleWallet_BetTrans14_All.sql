USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Lrf_BetList_RNG_Detail].[Test_RNGCasinoSingleWallet_BetTrans14_All]    Script Date: 6/27/2017 4:35:52 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Lrf_BetList_RNG_Detail].[Test_RNGCasinoSingleWallet_BetTrans14_All]
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
		LicenseeWLUSD		MONEY,
		LicenseeWLEUR		MONEY,
		LicenseeWLMYR		MONEY,
		LicenseeWLGBP		MONEY,
		CommUSD			MONEY,
		CommEUR			MONEY,
		CommMYR			MONEY,
		CommGBP			MONEY,
		PlayerCommUSD	MONEY,
		PlayerCommEUR	MONEY,
		PlayerCommMYR	MONEY,
		PlayerCommGBP	MONEY
	)

	DECLARE @LicenseeId	INT		= 26,	-- Athena000
		@UserId			INT		= 68,
		@TransId		BIGINT,
		@RefNo			BIGINT,
		@CustID			INT,
		@TransType		TINYINT = 0

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
		@RefNo = b.transid,
		@CustID = b.custid,
		@TransId = brng.transid
	FROM bodb02.dbo.bettrans14 AS b WITH (NOLOCK)
		INNER JOIN bodb02.dbo.bettransRnG14 AS brng WITH (NOLOCK) ON brng.refno = b.transid
		INNER JOIN bodb02.dbo.SportBettypeMatrix AS s WITH (NOLOCK) ON b.bettype = s.BetType
	WHERE s.ProductID = 6
		AND b.currency IN (SELECT Currency FROM @Temp)
		AND b.recommend IN (SELECT AgentId FROM @Temp)

	IF @TransId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Lrf_BetList_RNG_Detail]
							@AgentList = ''' + CONVERT(VARCHAR(MAX), @AgentList) + ''',
							@RefNo = ' + CONVERT(VARCHAR(20), @RefNo) + ',
							@CustId = ' + CONVERT(VARCHAR(10), @CustID) + ',
							@TransType = ' + CONVERT(VARCHAR(1), @TransType) + ''

		INSERT @Data
		EXEC tSQLt.ResultSetFilter
			@ResultsetNo = 1,
			@Command = @Command

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
